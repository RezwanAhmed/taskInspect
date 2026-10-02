package com.taskinspect.tasks.dto;

/** What happened in one step of a task's history. */
public enum TaskHistoryEvent {
    CREATED,
    /** Published as an open task (Phase 7A). */
    PUBLISHED,
    ASSIGNED,
    /** A worker took an open task (Phase 7A). */
    TAKEN,
    STARTED,
    /** Working on the task again after a reject or a correction request. */
    RESTARTED,
    SUBMITTED,
    RESUBMITTED,
    APPROVED,
    REJECTED,
    CORRECTION_REQUESTED,
    CANCELLED
}
