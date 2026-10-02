package com.taskinspect.notifications;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatCode;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyCollection;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;

import com.taskinspect.tasks.TaskAction;
import com.taskinspect.tasks.TaskStatusChanged;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.CsvSource;
import org.junit.jupiter.params.provider.EnumSource;
import org.mockito.ArgumentCaptor;

/** Unit tests of who gets which task notification (task 9.1b). */
class TaskNotificationListenerTests {

    private static final UUID TASK = UUID.randomUUID();
    private static final UUID MANAGER = UUID.randomUUID();
    private static final UUID WORKER = UUID.randomUUID();

    private final NotificationService notificationService = mock(NotificationService.class);
    private final TaskNotificationListener listener = new TaskNotificationListener(notificationService);

    @ParameterizedTest
    @CsvSource({
            "ASSIGN, MANAGER, WORKER, New task assigned",
            "SUBMIT, WORKER, MANAGER, Task submitted for review",
            "APPROVE, MANAGER, WORKER, Task approved",
            "REJECT, MANAGER, WORKER, Task rejected",
            "REQUEST_CORRECTION, MANAGER, WORKER, Correction requested"})
    void eachWorkflowStepNotifiesTheOtherSide(TaskAction action, String actor, String recipient, String title) {
        listener.onStatusChanged(event(action, user(actor), WORKER, MANAGER));

        ArgumentCaptor<PushMessage> message = ArgumentCaptor.forClass(PushMessage.class);
        verify(notificationService).notifyUsers(eq(List.of(user(recipient))), message.capture());
        assertThat(message.getValue().title()).isEqualTo(title);
        assertThat(message.getValue().body()).isEqualTo("Kitchen");
        assertThat(message.getValue().data()).isEqualTo(Map.of("taskId", TASK.toString(), "action", action.name()));
    }

    @ParameterizedTest
    @EnumSource(value = TaskAction.class, names = {"PUBLISH", "TAKE", "START", "CANCEL"})
    void otherActionsNotifyNobody(TaskAction action) {
        listener.onStatusChanged(event(action, MANAGER, WORKER, MANAGER));

        verifyNoInteractions(notificationService);
    }

    @ParameterizedTest
    @EnumSource(value = TaskAction.class, names = {"ASSIGN", "SUBMIT", "APPROVE", "REJECT", "REQUEST_CORRECTION"})
    void nobodyIsNotifiedOfTheirOwnAction(TaskAction action) {
        listener.onStatusChanged(event(action, WORKER, WORKER, WORKER));

        verifyNoInteractions(notificationService);
    }

    @Test
    void aTaskWithoutWorkerNotifiesNobody() {
        listener.onStatusChanged(event(TaskAction.APPROVE, MANAGER, null, MANAGER));

        verifyNoInteractions(notificationService);
    }

    @Test
    void aFailureWhileSendingIsOnlyLogged() {
        doThrow(new IllegalStateException("database down")).when(notificationService)
                .notifyUsers(anyCollection(), any());

        assertThatCode(() -> listener.onStatusChanged(event(TaskAction.ASSIGN, MANAGER, WORKER, MANAGER)))
                .doesNotThrowAnyException();
    }

    private static TaskStatusChanged event(TaskAction action, UUID actor, UUID assignee, UUID reviewer) {
        return new TaskStatusChanged(TASK, "Kitchen", action, actor, assignee, reviewer);
    }

    private static UUID user(String name) {
        return name.equals("MANAGER") ? MANAGER : WORKER;
    }

}
