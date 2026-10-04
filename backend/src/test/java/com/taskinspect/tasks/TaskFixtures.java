package com.taskinspect.tasks;

import com.taskinspect.users.User;

/** Test helpers for tests outside the tasks package. */
public final class TaskFixtures {

    private TaskFixtures() {
    }

    /** Makes a new task a sub-task of a main task without going through the API. */
    public static void makeSubTaskOf(Task task, Task mainTask) {
        task.makeSubTaskOf(mainTask);
    }

    /** Sets who may take an open task without going through the API. */
    public static void openTo(Task task, OpenScope scope) {
        task.openTo(scope);
    }

    /** Sets the task's worker without going through the API. */
    public static void assign(Task task, User worker) {
        task.assignTo(worker);
    }

}
