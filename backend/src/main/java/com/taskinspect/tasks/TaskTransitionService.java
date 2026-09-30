package com.taskinspect.tasks;

import com.taskinspect.audit.AuditAction;
import com.taskinspect.audit.AuditService;
import com.taskinspect.users.User;
import java.util.Map;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Changes a task's status and records the change in the status history and
 * the audit log in the same transaction, so no status change can go
 * unrecorded.
 */
@Service
public class TaskTransitionService {

    private static final Map<TaskAction, AuditAction> AUDIT_ACTIONS = Map.of(
            TaskAction.ASSIGN, AuditAction.TASK_ASSIGNED,
            TaskAction.START, AuditAction.TASK_STARTED,
            TaskAction.SUBMIT, AuditAction.TASK_SUBMITTED,
            TaskAction.APPROVE, AuditAction.TASK_APPROVED,
            TaskAction.REJECT, AuditAction.TASK_REJECTED,
            TaskAction.REQUEST_CORRECTION, AuditAction.TASK_CORRECTION_REQUESTED,
            TaskAction.CANCEL, AuditAction.TASK_CANCELLED);

    private final TaskStateMachine stateMachine;
    private final TaskStatusChangeRepository historyRepository;
    private final AuditService auditService;

    public TaskTransitionService(TaskStateMachine stateMachine, TaskStatusChangeRepository historyRepository,
            AuditService auditService) {
        this.stateMachine = stateMachine;
        this.historyRepository = historyRepository;
        this.auditService = auditService;
    }

    /** Records that a new task was created as DRAFT. */
    @Transactional
    public void recordCreated(Task task, User by) {
        historyRepository.save(new TaskStatusChange(task, null, task.getStatus(), by, null));
        audit(AuditAction.TASK_CREATED, task, by, "title: " + task.getTitle());
    }

    /** Records that a task's details were edited. */
    @Transactional
    public void recordUpdated(Task task, User by) {
        audit(AuditAction.TASK_UPDATED, task, by, "title: " + task.getTitle());
    }

    /**
     * Applies the action through the state machine (409 if not allowed) and
     * records the change.
     */
    @Transactional
    public void apply(Task task, TaskAction action, User by, String reason) {
        TaskStatus from = task.getStatus();
        stateMachine.apply(task, action);
        historyRepository.save(new TaskStatusChange(task, from, task.getStatus(), by, reason));
        String details = from + " -> " + task.getStatus() + (reason == null ? "" : "; reason: " + reason);
        audit(AUDIT_ACTIONS.get(action), task, by, details);
    }

    private void audit(AuditAction action, Task task, User by, String details) {
        auditService.record(new AuditService.Entry(action, task.getOrganization().getId(), by.getId(), "TASK",
                task.getId(), details));
    }

}
