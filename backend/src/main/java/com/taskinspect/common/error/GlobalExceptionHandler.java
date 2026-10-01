package com.taskinspect.common.error;

import java.util.List;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.dao.OptimisticLockingFailureException;
import org.springframework.http.converter.HttpMessageNotReadableException;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.security.core.AuthenticationException;
import org.springframework.security.oauth2.server.resource.InvalidBearerTokenException;
import org.springframework.web.HttpMediaTypeNotSupportedException;
import org.springframework.web.HttpRequestMethodNotSupportedException;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.method.annotation.HandlerMethodValidationException;
import org.springframework.web.method.annotation.MethodArgumentTypeMismatchException;
import org.springframework.web.servlet.resource.NoResourceFoundException;

/**
 * Turns every exception thrown by a controller into the same
 * {@link ErrorResponse} JSON shape. Unexpected errors are logged with their
 * stack trace but never exposed to the client.
 */
@RestControllerAdvice
public class GlobalExceptionHandler {

    private static final Logger log = LoggerFactory.getLogger(GlobalExceptionHandler.class);

    @ExceptionHandler(ApiException.class)
    ResponseEntity<ErrorResponse> handleApiException(ApiException ex) {
        return respond(ex.getStatus(),
                new ErrorResponse(ex.getStatus().value(), ex.getCode(), ex.getMessage(), ex.getErrors()));
    }

    @ExceptionHandler(AuthenticationException.class)
    ResponseEntity<ErrorResponse> handleUnauthenticated(AuthenticationException ex) {
        HttpStatus status = HttpStatus.UNAUTHORIZED;
        return respond(status, new ErrorResponse(status.value(), ErrorCode.UNAUTHORIZED,
                "Authentication is required"));
    }

    @ExceptionHandler(InvalidBearerTokenException.class)
    ResponseEntity<ErrorResponse> handleInvalidToken(InvalidBearerTokenException ex) {
        HttpStatus status = HttpStatus.UNAUTHORIZED;
        return respond(status, new ErrorResponse(status.value(), ErrorCode.INVALID_TOKEN,
                "Access token is invalid or expired"));
    }

    @ExceptionHandler(AccessDeniedException.class)
    ResponseEntity<ErrorResponse> handleAccessDenied(AccessDeniedException ex) {
        HttpStatus status = HttpStatus.FORBIDDEN;
        return respond(status, new ErrorResponse(status.value(), ErrorCode.FORBIDDEN,
                "You are not allowed to do this"));
    }

    @ExceptionHandler(MethodArgumentNotValidException.class)
    ResponseEntity<ErrorResponse> handleValidation(MethodArgumentNotValidException ex) {
        List<ErrorResponse.FieldError> errors = ex.getBindingResult().getFieldErrors().stream()
                .map(error -> new ErrorResponse.FieldError(error.getField(), error.getDefaultMessage()))
                .toList();
        HttpStatus status = HttpStatus.BAD_REQUEST;
        return respond(status, new ErrorResponse(status.value(), ErrorCode.VALIDATION_ERROR,
                "Request validation failed", errors));
    }

    /** Two requests changed the same record at the same time; the later one must reload. */
    @ExceptionHandler(OptimisticLockingFailureException.class)
    ResponseEntity<ErrorResponse> handleConcurrentUpdate(OptimisticLockingFailureException ex) {
        HttpStatus status = HttpStatus.CONFLICT;
        return respond(status, new ErrorResponse(status.value(), ErrorCode.VERSION_CONFLICT,
                "This item was changed by someone else. Reload it and try again."));
    }

    @ExceptionHandler(HandlerMethodValidationException.class)
    ResponseEntity<ErrorResponse> handleParameterValidation(HandlerMethodValidationException ex) {
        List<ErrorResponse.FieldError> errors = ex.getParameterValidationResults().stream()
                .flatMap(result -> result.getResolvableErrors().stream()
                        .map(error -> new ErrorResponse.FieldError(
                                result.getMethodParameter().getParameterName(), error.getDefaultMessage())))
                .toList();
        HttpStatus status = HttpStatus.BAD_REQUEST;
        return respond(status, new ErrorResponse(status.value(), ErrorCode.VALIDATION_ERROR,
                "Request validation failed", errors));
    }

    @ExceptionHandler(MethodArgumentTypeMismatchException.class)
    ResponseEntity<ErrorResponse> handleTypeMismatch(MethodArgumentTypeMismatchException ex) {
        HttpStatus status = HttpStatus.BAD_REQUEST;
        return respond(status, new ErrorResponse(status.value(), ErrorCode.INVALID_PARAMETER,
                "Invalid value for parameter '" + ex.getName() + "'"));
    }

    @ExceptionHandler(HttpMessageNotReadableException.class)
    ResponseEntity<ErrorResponse> handleMalformed(HttpMessageNotReadableException ex) {
        HttpStatus status = HttpStatus.BAD_REQUEST;
        return respond(status, new ErrorResponse(status.value(), ErrorCode.MALFORMED_REQUEST,
                "Request body is missing or not valid JSON"));
    }

    @ExceptionHandler(NoResourceFoundException.class)
    ResponseEntity<ErrorResponse> handleNotFound(NoResourceFoundException ex) {
        HttpStatus status = HttpStatus.NOT_FOUND;
        return respond(status, new ErrorResponse(status.value(), ErrorCode.NOT_FOUND,
                "No endpoint " + ex.getHttpMethod() + " /" + ex.getResourcePath()));
    }

    @ExceptionHandler(HttpRequestMethodNotSupportedException.class)
    ResponseEntity<ErrorResponse> handleMethodNotAllowed(HttpRequestMethodNotSupportedException ex) {
        HttpStatus status = HttpStatus.METHOD_NOT_ALLOWED;
        return respond(status, new ErrorResponse(status.value(), ErrorCode.METHOD_NOT_ALLOWED,
                "Method " + ex.getMethod() + " is not supported for this endpoint"));
    }

    @ExceptionHandler(HttpMediaTypeNotSupportedException.class)
    ResponseEntity<ErrorResponse> handleUnsupportedMediaType(HttpMediaTypeNotSupportedException ex) {
        HttpStatus status = HttpStatus.UNSUPPORTED_MEDIA_TYPE;
        return respond(status, new ErrorResponse(status.value(), ErrorCode.UNSUPPORTED_MEDIA_TYPE,
                "Content type " + ex.getContentType() + " is not supported"));
    }

    @ExceptionHandler(Exception.class)
    ResponseEntity<ErrorResponse> handleUnexpected(Exception ex) {
        log.error("Unexpected error", ex);
        HttpStatus status = HttpStatus.INTERNAL_SERVER_ERROR;
        return respond(status, new ErrorResponse(status.value(), ErrorCode.INTERNAL_ERROR,
                "An unexpected error occurred"));
    }

    private static ResponseEntity<ErrorResponse> respond(HttpStatus status, ErrorResponse body) {
        return ResponseEntity.status(status).body(body);
    }

}
