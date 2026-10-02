package com.taskinspect.tasks;

/** The states of the task lifecycle (see docs/architecture.md, "Task Lifecycle"). */
public enum TaskStatus {

    DRAFT,
    /** Published without an assignee; a worker who may take it does so (Phase 7A). */
    OPEN,
    ASSIGNED,
    IN_PROGRESS,
    SUBMITTED,
    APPROVED,
    REJECTED,
    CORRECTION_REQUESTED,
    CANCELLED;

    /** Approved and cancelled tasks can no longer be changed. */
    public boolean isFinal() {
        return this == APPROVED || this == CANCELLED;
    }

}
