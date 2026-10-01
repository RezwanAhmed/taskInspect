package com.taskinspect.sync.dto;

import java.util.List;

/** One result per pushed operation, in the same order. */
public record SyncPushResponse(List<SyncOperationResult> results) {
}
