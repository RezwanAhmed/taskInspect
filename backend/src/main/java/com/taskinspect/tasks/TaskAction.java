package com.taskinspect.tasks;

/** Actions that change a task's status. Each one is a separate API call. */
public enum TaskAction {

    ASSIGN,
    START,
    SUBMIT,
    APPROVE,
    REJECT,
    REQUEST_CORRECTION,
    CANCEL

}
