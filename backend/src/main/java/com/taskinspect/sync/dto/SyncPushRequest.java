package com.taskinspect.sync.dto;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import java.util.List;

/** Queued operations in the order they were made on the device. */
public record SyncPushRequest(@NotEmpty @Size(max = 100) List<@Valid @NotNull SyncOperationRequest> operations) {
}
