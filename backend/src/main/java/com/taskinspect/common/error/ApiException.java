package com.taskinspect.common.error;

import java.util.List;
import org.springframework.http.HttpStatus;

/**
 * A business error with an HTTP status and a stable error code. Services
 * throw it (or a subclass); {@link GlobalExceptionHandler} turns it into an
 * {@link ErrorResponse}.
 */
public class ApiException extends RuntimeException {

    private final HttpStatus status;
    private final String code;
    private final List<ErrorResponse.FieldError> errors;

    public ApiException(HttpStatus status, String code, String message) {
        this(status, code, message, List.of());
    }

    /** With details, e.g. which requirements are missing ({@code field} = requirement ID). */
    public ApiException(HttpStatus status, String code, String message, List<ErrorResponse.FieldError> errors) {
        super(message);
        this.status = status;
        this.code = code;
        this.errors = List.copyOf(errors);
    }

    public HttpStatus getStatus() {
        return status;
    }

    public String getCode() {
        return code;
    }

    public List<ErrorResponse.FieldError> getErrors() {
        return errors;
    }

}
