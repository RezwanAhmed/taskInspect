package com.taskinspect.audit;

/** Actions written to the audit log. */
public enum AuditAction {

    LOGIN_SUCCEEDED,
    LOGIN_FAILED,
    REFRESH_TOKEN_REUSED,
    USER_CREATED,
    USER_TEAM_CHANGED,
    TASK_CREATED,
    TASK_UPDATED,
    TASK_ASSIGNED,
    TASK_PUBLISHED,
    TASK_STARTED,
    TASK_SUBMITTED,
    TASK_APPROVED,
    TASK_REJECTED,
    TASK_CORRECTION_REQUESTED,
    TASK_CANCELLED

}
