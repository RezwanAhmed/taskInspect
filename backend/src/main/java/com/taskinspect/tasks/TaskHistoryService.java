package com.taskinspect.tasks;

import com.taskinspect.common.security.CurrentUser;
import com.taskinspect.tasks.dto.TaskHistoryEntry;
import com.taskinspect.tasks.dto.TaskHistoryEvent;
import com.taskinspect.tasks.dto.TaskResponse.UserRef;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * A task's history timeline (spec "Task History": created, assigned,
 * started, submitted, rejected, resubmitted, approved, with time and user),
 * built from the status history every transition records.
 */
@Service
public class TaskHistoryService {

    private final TaskService taskService;
    private final TaskStatusChangeRepository historyRepository;

    public TaskHistoryService(TaskService taskService, TaskStatusChangeRepository historyRepository) {
        this.taskService = taskService;
        this.historyRepository = historyRepository;
    }

    /** Oldest first; for anyone who can see the task. */
    @Transactional(readOnly = true)
    public List<TaskHistoryEntry> history(CurrentUser caller, UUID taskId) {
        Task task = taskService.get(caller, taskId);
        List<TaskHistoryEntry> entries = new ArrayList<>();
        boolean submittedBefore = false;
        for (TaskStatusChange change : historyRepository.findAllByTaskIdOrderByChangedAtAscIdAsc(task.getId())) {
            TaskHistoryEvent event = event(change, submittedBefore);
            submittedBefore |= change.getToStatus() == TaskStatus.SUBMITTED;
            entries.add(new TaskHistoryEntry(event, change.getFromStatus(), change.getToStatus(),
                    UserRef.from(change.getChangedBy()), change.getChangedAt(), change.getReason()));
        }
        return entries;
    }

    private static TaskHistoryEvent event(TaskStatusChange change, boolean submittedBefore) {
        if (change.getFromStatus() == null) {
            return TaskHistoryEvent.CREATED;
        }
        return switch (change.getToStatus()) {
            case DRAFT -> TaskHistoryEvent.CREATED;
            case OPEN -> TaskHistoryEvent.PUBLISHED;
            case ASSIGNED -> TaskHistoryEvent.ASSIGNED;
            case IN_PROGRESS -> change.getFromStatus() == TaskStatus.ASSIGNED
                    ? TaskHistoryEvent.STARTED : TaskHistoryEvent.RESTARTED;
            case SUBMITTED -> submittedBefore ? TaskHistoryEvent.RESUBMITTED : TaskHistoryEvent.SUBMITTED;
            case APPROVED -> TaskHistoryEvent.APPROVED;
            case REJECTED -> TaskHistoryEvent.REJECTED;
            case CORRECTION_REQUESTED -> TaskHistoryEvent.CORRECTION_REQUESTED;
            case CANCELLED -> TaskHistoryEvent.CANCELLED;
        };
    }

}
