package com.taskinspect.notifications;

import com.taskinspect.tasks.TaskStatusChanged;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Component;
import org.springframework.transaction.event.TransactionalEventListener;

/**
 * Sends the push notifications of a task's workflow (spec section 21):
 * assigned → the worker, submitted → the reviewer, approved / rejected /
 * correction requested → the worker. Nobody is notified of their own
 * action (a personal task, where creator, worker and reviewer are the same
 * person). Runs only after the change is committed, so a rolled-back
 * request sends nothing, and on another thread, so the push service never
 * slows down or fails the request.
 */
@Component
public class TaskNotificationListener {

    private static final Logger log = LoggerFactory.getLogger(TaskNotificationListener.class);

    private final NotificationService notificationService;

    public TaskNotificationListener(NotificationService notificationService) {
        this.notificationService = notificationService;
    }

    @Async
    @TransactionalEventListener
    public void onStatusChanged(TaskStatusChanged event) {
        String title;
        UUID recipient;
        switch (event.action()) {
            case ASSIGN -> {
                title = "New task assigned";
                recipient = event.assigneeId();
            }
            case SUBMIT -> {
                title = "Task submitted for review";
                recipient = event.reviewerId();
            }
            case APPROVE -> {
                title = "Task approved";
                recipient = event.assigneeId();
            }
            case REJECT -> {
                title = "Task rejected";
                recipient = event.assigneeId();
            }
            case REQUEST_CORRECTION -> {
                title = "Correction requested";
                recipient = event.assigneeId();
            }
            default -> {
                return;
            }
        }
        if (recipient == null || recipient.equals(event.actorId())) {
            return;
        }
        // The app opens the task from taskId when the notification is tapped (task 8.7).
        PushMessage message = new PushMessage(title, event.title(),
                Map.of("taskId", event.taskId().toString(), "action", event.action().name()));
        try {
            notificationService.notifyUsers(List.of(recipient), message);
        } catch (RuntimeException e) {
            log.warn("Notification for task {} could not be sent: {}", event.taskId(), e.toString());
        }
    }

}
