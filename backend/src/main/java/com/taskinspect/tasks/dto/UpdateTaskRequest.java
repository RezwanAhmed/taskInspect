package com.taskinspect.tasks.dto;

import com.taskinspect.tasks.TaskPriority;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.PositiveOrZero;
import jakarta.validation.constraints.Size;
import java.time.Instant;
import java.util.UUID;

/**
 * New details of a task (all fields are replaced). {@code version} must be
 * the version the client last saw, so changes made meanwhile by someone
 * else are not overwritten.
 */
public record UpdateTaskRequest(
        @NotBlank @Size(max = 200) String title,
        @Size(max = 5000) String description,
        @NotNull TaskPriority priority,
        @NotNull Instant dueDate,
        UUID reviewerId,
        @NotNull @PositiveOrZero Long version) {
}
