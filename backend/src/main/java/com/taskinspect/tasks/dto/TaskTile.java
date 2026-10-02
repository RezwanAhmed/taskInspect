package com.taskinspect.tasks.dto;

import com.taskinspect.tasks.Task;
import com.taskinspect.tasks.TaskPriority;
import com.taskinspect.tasks.TaskStatus;
import com.taskinspect.tasks.dto.TaskResponse.UserRef;
import java.time.Instant;
import java.util.UUID;

/**
 * A team member's task as a worker sees it: who works on what and how far
 * it is, without the description, requirements, answers or evidence.
 * {@code updatedAt} lets the app see that a tile changed.
 */
public record TaskTile(
        UUID id,
        String title,
        TaskPriority priority,
        TaskStatus status,
        Instant dueDate,
        UserRef assignee,
        Instant updatedAt) {

    public static TaskTile from(Task task) {
        return new TaskTile(task.getId(), task.getTitle(), task.getPriority(), task.getStatus(), task.getDueDate(),
                UserRef.from(task.getAssignee()), task.getUpdatedAt());
    }

}
