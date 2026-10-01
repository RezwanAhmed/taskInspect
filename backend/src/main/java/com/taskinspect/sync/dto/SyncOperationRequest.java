package com.taskinspect.sync.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import java.util.Map;
import java.util.UUID;

/**
 * One operation from the app's sync queue (docs/architecture.md, "Sync
 * Queue"). {@code id} is created on the device and makes the push safe to
 * send again. {@code payload} is the body the matching API call takes.
 */
public record SyncOperationRequest(
        @NotNull UUID id,
        @NotBlank String entityType,
        @NotNull UUID entityId,
        @NotNull UUID taskId,
        @NotBlank String operation,
        Map<String, Object> payload) {
}
