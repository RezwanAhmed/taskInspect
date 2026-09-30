package com.taskinspect.common.error;

import org.springframework.http.HttpStatus;

/**
 * A business error with an HTTP status and a stable error code. Services
 * throw it (or a subclass); {@link GlobalExceptionHandler} turns it into an
 * {@link ErrorResponse}.
 */
public class ApiException extends RuntimeException {

    private final HttpStatus status;
    private final String code;

    public ApiException(HttpStatus status, String code, String message) {
        super(message);
        this.status = status;
        this.code = code;
    }

    public HttpStatus getStatus() {
        return status;
    }

    public String getCode() {
        return code;
    }

}
