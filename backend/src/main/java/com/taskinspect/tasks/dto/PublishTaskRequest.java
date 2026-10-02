package com.taskinspect.tasks.dto;

import com.taskinspect.tasks.OpenScope;
import jakarta.validation.constraints.NotNull;

public record PublishTaskRequest(@NotNull OpenScope scope) {
}
