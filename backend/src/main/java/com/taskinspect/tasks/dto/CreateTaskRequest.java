package com.taskinspect.tasks.dto;

import com.taskinspect.tasks.TaskPriority;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import java.time.Instant;
import java.util.UUID;

/**
 * A new draft task. {@code reviewerId} is optional; without it the creator
 * reviews the task.
 */
public record CreateTaskRequest(
        @NotBlank @Size(max = 200) String title,
        @Size(max = 5000) String description,
        @NotNull TaskPriority priority,
        @NotNull Instant dueDate,
        UUID reviewerId) {
}
