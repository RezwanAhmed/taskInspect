package com.taskinspect.tasks;

import com.taskinspect.users.User;

/** Test helpers for tests outside the tasks package. */
public final class TaskFixtures {

    private TaskFixtures() {
    }

    /** Sets the task's worker without going through the API. */
    public static void assign(Task task, User worker) {
        task.assignTo(worker);
    }

}
