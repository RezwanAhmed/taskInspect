package com.taskinspect.tasks;

import java.util.UUID;

/**
 * Published when an action changed a task's status (task 8.6). It carries
 * only IDs and the title, so listeners that run after the commit don't
 * touch the task's entities.
 */
public record TaskStatusChanged(UUID taskId, String title, TaskAction action, UUID actorId, UUID assigneeId,
        UUID reviewerId) {
}
