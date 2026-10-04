package com.taskinspect.tasks;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

import com.taskinspect.audit.AuditAction;
import com.taskinspect.audit.AuditService;
import com.taskinspect.common.error.ApiException;
import com.taskinspect.users.Organization;
import com.taskinspect.users.User;
import java.time.Instant;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.context.ApplicationEventPublisher;

/** Unit tests: each status change is recorded in history and audit log, and published (task 9.1b). */
class TaskTransitionServiceTests {

    private final TaskStatusChangeRepository historyRepository = mock(TaskStatusChangeRepository.class);
    private final AuditService auditService = mock(AuditService.class);
    private final ApplicationEventPublisher events = mock(ApplicationEventPublisher.class);
    private final TaskTransitionService transitions = new TaskTransitionService(new TaskStateMachine(),
            historyRepository, auditService, events);

    private final UUID organizationId = UUID.randomUUID();
    private final User manager = user();
    private final User worker = user();
    private final Task task = new Task(manager, "Kitchen", null, TaskPriority.HIGH, Instant.now(), null);

    @Test
    void anActionChangesTheStatusAndIsRecordedAndPublished() {
        task.assignTo(worker);

        transitions.apply(task, TaskAction.ASSIGN, manager, "urgent");

        assertThat(task.getStatus()).isEqualTo(TaskStatus.ASSIGNED);
        ArgumentCaptor<TaskStatusChange> change = ArgumentCaptor.forClass(TaskStatusChange.class);
        verify(historyRepository).save(change.capture());
        assertThat(change.getValue().getFromStatus()).isEqualTo(TaskStatus.DRAFT);
        assertThat(change.getValue().getToStatus()).isEqualTo(TaskStatus.ASSIGNED);
        assertThat(change.getValue().getChangedBy()).isSameAs(manager);
        assertThat(change.getValue().getReason()).isEqualTo("urgent");
        verify(auditService).record(new AuditService.Entry(AuditAction.TASK_ASSIGNED, organizationId,
                manager.getId(), "TASK", task.getId(), "DRAFT -> ASSIGNED; reason: urgent"));
        verify(events).publishEvent(new TaskStatusChanged(task.getId(), "Kitchen", TaskAction.ASSIGN,
                manager.getId(), worker.getId(), manager.getId()));
    }

    @Test
    void withoutReasonTheAuditDetailsShowOnlyTheChange() {
        transitions.apply(task, TaskAction.PUBLISH, manager, null);

        verify(auditService).record(new AuditService.Entry(AuditAction.TASK_PUBLISHED, organizationId,
                manager.getId(), "TASK", task.getId(), "DRAFT -> OPEN"));
        verify(events).publishEvent(new TaskStatusChanged(task.getId(), "Kitchen", TaskAction.PUBLISH,
                manager.getId(), null, manager.getId()));
    }

    @Test
    void aRefusedActionChangesNothingAndRecordsNothing() {
        assertThatThrownBy(() -> transitions.apply(task, TaskAction.APPROVE, manager, null))
                .isInstanceOf(ApiException.class);

        assertThat(task.getStatus()).isEqualTo(TaskStatus.DRAFT);
        verifyNoInteractions(historyRepository, auditService, events);
    }

    @Test
    void creatingIsRecordedButNotPublished() {
        transitions.recordCreated(task, manager);

        ArgumentCaptor<TaskStatusChange> change = ArgumentCaptor.forClass(TaskStatusChange.class);
        verify(historyRepository).save(change.capture());
        assertThat(change.getValue().getFromStatus()).isNull();
        assertThat(change.getValue().getToStatus()).isEqualTo(TaskStatus.DRAFT);
        verify(auditService).record(new AuditService.Entry(AuditAction.TASK_CREATED, organizationId,
                manager.getId(), "TASK", task.getId(), "title: Kitchen"));
        verifyNoInteractions(events);
    }

    @Test
    void anEditIsOnlyAudited() {
        transitions.recordUpdated(task, manager);

        verify(auditService).record(new AuditService.Entry(AuditAction.TASK_UPDATED, organizationId,
                manager.getId(), "TASK", task.getId(), "title: Kitchen"));
        verifyNoInteractions(historyRepository, events);
    }

    private User user() {
        Organization organization = mock(Organization.class);
        when(organization.getId()).thenReturn(organizationId);
        User user = mock(User.class);
        when(user.getId()).thenReturn(UUID.randomUUID());
        when(user.getOrganization()).thenReturn(organization);
        return user;
    }

}
