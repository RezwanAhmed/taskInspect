package com.taskinspect.common.error;

import com.fasterxml.jackson.annotation.JsonInclude;
import java.time.Instant;
import java.util.List;

/**
 * The single JSON shape used for every error returned by the API.
 *
 * @param timestamp when the error happened (UTC)
 * @param status    HTTP status code
 * @param code      stable, machine-readable error code, e.g. {@code TASK_INVALID_TRANSITION}
 * @param message   human-readable description, safe to show to users
 * @param errors    field errors for {@code VALIDATION_ERROR}; omitted otherwise
 */
@JsonInclude(JsonInclude.Include.NON_EMPTY)
public record ErrorResponse(
        Instant timestamp,
        int status,
        String code,
        String message,
        List<FieldError> errors) {

    public ErrorResponse(int status, String code, String message) {
        this(Instant.now(), status, code, message, List.of());
    }

    public ErrorResponse(int status, String code, String message, List<FieldError> errors) {
        this(Instant.now(), status, code, message, errors);
    }

    /** One invalid request field. */
    public record FieldError(String field, String message) {
    }

}
