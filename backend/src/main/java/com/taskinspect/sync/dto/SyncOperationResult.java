package com.taskinspect.sync.dto;

import com.fasterxml.jackson.annotation.JsonInclude;
import java.util.UUID;

/**
 * What happened to one pushed operation. {@code code} and {@code message}
 * say why it was rejected or skipped; they are omitted when it was applied.
 */
@JsonInclude(JsonInclude.Include.NON_NULL)
public record SyncOperationResult(UUID id, Status status, String code, String message) {

    public enum Status {
        /** Applied now, or already applied by an earlier push. */
        APPLIED,
        /** Refused by the server's rules; the same request would fail again. */
        REJECTED,
        /** Not tried, because an earlier operation of the same task was rejected. */
        SKIPPED
    }

    public static SyncOperationResult applied(UUID id) {
        return new SyncOperationResult(id, Status.APPLIED, null, null);
    }

    public static SyncOperationResult rejected(UUID id, String code, String message) {
        return new SyncOperationResult(id, Status.REJECTED, code, message);
    }

    public static SyncOperationResult skipped(UUID id, String code, String message) {
        return new SyncOperationResult(id, Status.SKIPPED, code, message);
    }

}
