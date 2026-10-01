package com.taskinspect.tasks;

/** The states of the task lifecycle (see docs/architecture.md, "Task Lifecycle"). */
public enum TaskStatus {

    DRAFT,
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
