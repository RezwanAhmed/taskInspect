package com.taskinspect.tasks.dto;

import com.taskinspect.tasks.Task;
import com.taskinspect.tasks.TaskPriority;
import com.taskinspect.tasks.TaskStatus;
import com.taskinspect.users.User;
import java.time.Instant;
import java.util.UUID;

/** A task as returned by the API. {@code version} is used to detect stale updates. */
public record TaskResponse(
        UUID id,
        String title,
        String description,
        TaskPriority priority,
        TaskStatus status,
        Instant dueDate,
        UserRef createdBy,
        UserRef reviewer,
        UserRef assignee,
        long version,
        Instant createdAt,
        Instant updatedAt) {

    public static TaskResponse from(Task task) {
        return new TaskResponse(task.getId(), task.getTitle(), task.getDescription(), task.getPriority(),
                task.getStatus(), task.getDueDate(), UserRef.from(task.getCreatedBy()),
                UserRef.from(task.getReviewer()), UserRef.from(task.getAssignee()), task.getVersion(),
                task.getCreatedAt(), task.getUpdatedAt());
    }

    /** A short reference to a user. */
    public record UserRef(UUID id, String fullName) {

        public static UserRef from(User user) {
            return user == null ? null : new UserRef(user.getId(), user.getFullName());
        }

    }

}
