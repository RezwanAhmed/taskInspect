package com.taskinspect.sync;

import com.taskinspect.common.error.ApiException;
import com.taskinspect.common.error.ErrorCode;
import com.taskinspect.common.security.CurrentUser;
import com.taskinspect.evidence.EvidenceService;
import com.taskinspect.evidence.dto.RegisterEvidenceRequest;
import com.taskinspect.responses.ResponseService;
import com.taskinspect.reviews.SubmissionService;
import com.taskinspect.responses.dto.SaveResponseRequest;
import com.taskinspect.sync.dto.SyncOperationRequest;
import com.taskinspect.sync.dto.SyncOperationResult;
import com.taskinspect.tasks.TaskService;
import com.taskinspect.users.RoleName;
import jakarta.validation.ConstraintViolation;
import jakarta.validation.Validator;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.Set;
import java.util.UUID;
import java.util.stream.Collectors;
import org.springframework.dao.OptimisticLockingFailureException;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.TransactionDefinition;
import org.springframework.transaction.support.TransactionTemplate;
import tools.jackson.core.JacksonException;
import tools.jackson.databind.ObjectMapper;

/**
 * Applies operations from the app's sync queue (POST /api/sync/push).
 *
 * <p>Each operation runs in its own transaction through the same services
 * and rules as the normal API call, and is recorded in {@code sync_records}
 * together with its change. An operation that was applied before is not
 * applied again. Once an operation of a task is rejected, the later ones of
 * that task are skipped, so for example a submit never overtakes the answers
 * it depends on; other tasks go on.
 */
@Service
public class SyncService {

    static final String UNSUPPORTED_OPERATION = "UNSUPPORTED_OPERATION";
    static final String INVALID_PAYLOAD = "INVALID_PAYLOAD";
    static final String EARLIER_OPERATION_REJECTED = "EARLIER_OPERATION_REJECTED";
    static final String OPERATION_ID_CONFLICT = "OPERATION_ID_CONFLICT";

    private final SyncRecordRepository syncRecordRepository;
    private final TaskService taskService;
    private final ResponseService responseService;
    private final EvidenceService evidenceService;
    private final SubmissionService submissionService;
    private final ObjectMapper objectMapper;
    private final Validator validator;
    private final TransactionTemplate transactions;

    public SyncService(SyncRecordRepository syncRecordRepository, TaskService taskService,
            ResponseService responseService, EvidenceService evidenceService, SubmissionService submissionService,
            ObjectMapper objectMapper, Validator validator, PlatformTransactionManager transactionManager) {
        this.syncRecordRepository = syncRecordRepository;
        this.taskService = taskService;
        this.responseService = responseService;
        this.evidenceService = evidenceService;
        this.submissionService = submissionService;
        this.objectMapper = objectMapper;
        this.validator = validator;
        this.transactions = new TransactionTemplate(transactionManager);
        this.transactions.setPropagationBehavior(TransactionDefinition.PROPAGATION_REQUIRES_NEW);
    }

    /** Applies the operations in order and returns one result per operation. */
    public List<SyncOperationResult> push(CurrentUser caller, List<SyncOperationRequest> operations) {
        Set<UUID> rejectedTasks = new HashSet<>();
        List<SyncOperationResult> results = new ArrayList<>();
        for (SyncOperationRequest operation : operations) {
            if (rejectedTasks.contains(operation.taskId())) {
                results.add(SyncOperationResult.skipped(operation.id(), EARLIER_OPERATION_REJECTED,
                        "An earlier change of this task was rejected"));
                continue;
            }
            SyncOperationResult result = pushOne(caller, operation);
            if (result.status() == SyncOperationResult.Status.REJECTED) {
                rejectedTasks.add(operation.taskId());
            }
            results.add(result);
        }
        return results;
    }

    /**
     * Business errors reject only this operation. Anything else (for example
     * the database being down) fails the whole request, so the app retries
     * later; operations applied before that are already recorded.
     */
    private SyncOperationResult pushOne(CurrentUser caller, SyncOperationRequest operation) {
        try {
            transactions.executeWithoutResult(status -> {
                Optional<SyncRecord> earlier = syncRecordRepository.findById(operation.id());
                if (earlier.isPresent()) {
                    if (!earlier.get().getUserId().equals(caller.id())) {
                        throw new ApiException(HttpStatus.CONFLICT, OPERATION_ID_CONFLICT,
                                "This operation ID is already used");
                    }
                    return;
                }
                apply(caller, operation);
                syncRecordRepository.save(new SyncRecord(operation.id(), caller.id(), operation.taskId(),
                        operation.entityType(), operation.entityId(), operation.operation()));
            });
            return SyncOperationResult.applied(operation.id());
        } catch (ApiException ex) {
            return SyncOperationResult.rejected(operation.id(), ex.getCode(), ex.getMessage());
        } catch (OptimisticLockingFailureException ex) {
            return SyncOperationResult.rejected(operation.id(), ErrorCode.VERSION_CONFLICT,
                    "This item was changed by someone else");
        }
    }

    private void apply(CurrentUser caller, SyncOperationRequest operation) {
        // The same role check as the matching API endpoints.
        if (!caller.hasRole(RoleName.WORKER.name())) {
            throw new ApiException(HttpStatus.FORBIDDEN, ErrorCode.FORBIDDEN, "Only workers can do this");
        }
        UUID taskId = operation.taskId();
        switch (operation.entityType() + " " + operation.operation()) {
            case "TaskResponse UPDATE" -> responseService.save(caller, taskId, operation.entityId(),
                    payload(operation, SaveResponseRequest.class));
            case "Evidence CREATE" -> {
                RegisterEvidenceRequest request = payload(operation, RegisterEvidenceRequest.class);
                if (!operation.entityId().equals(request.id())) {
                    throw invalidPayload("The evidence ID must match entityId");
                }
                evidenceService.register(caller, taskId, uuid(operation.payload(), "requirementId"), request);
            }
            case "Evidence DELETE" -> evidenceService.delete(caller, taskId, operation.entityId());
            case "Task START" -> start(caller, operation);
            case "Task SUBMIT" -> submit(caller, operation);
            default -> throw new ApiException(HttpStatus.BAD_REQUEST, UNSUPPORTED_OPERATION,
                    operation.operation() + " of " + operation.entityType() + " can't be synchronized");
        }
    }

    /** Refused when the task changed on the server after the device last loaded it. */
    private void start(CurrentUser caller, SyncOperationRequest operation) {
        if (!operation.entityId().equals(operation.taskId())) {
            throw invalidPayload("entityId must be the task ID");
        }
        Object version = operation.payload() == null ? null : operation.payload().get("version");
        if (version != null && !(version instanceof Number)) {
            throw invalidPayload("version must be a number");
        }
        if (version instanceof Number number
                && number.longValue() != taskService.get(caller, operation.taskId()).getVersion()) {
            throw new ApiException(HttpStatus.CONFLICT, ErrorCode.VERSION_CONFLICT,
                    "The task was changed on the server. Reload it and try again.");
        }
        taskService.start(caller, operation.taskId());
    }

    /**
     * No version check: the device's version is older after its own START
     * was applied; the state machine and the requirement checks decide.
     */
    private void submit(CurrentUser caller, SyncOperationRequest operation) {
        if (!operation.entityId().equals(operation.taskId())) {
            throw invalidPayload("entityId must be the task ID");
        }
        submissionService.submit(caller, operation.taskId());
    }

    private <T> T payload(SyncOperationRequest operation, Class<T> type) {
        T value;
        try {
            value = objectMapper.convertValue(operation.payload() == null ? Map.of() : operation.payload(), type);
        } catch (IllegalArgumentException | JacksonException ex) {
            throw invalidPayload("The payload doesn't match " + operation.operation() + " of "
                    + operation.entityType());
        }
        Set<ConstraintViolation<T>> violations = validator.validate(value);
        if (!violations.isEmpty()) {
            throw new ApiException(HttpStatus.BAD_REQUEST, ErrorCode.VALIDATION_ERROR, violations.stream()
                    .map(v -> v.getPropertyPath() + ": " + v.getMessage())
                    .sorted()
                    .collect(Collectors.joining("; ")));
        }
        return value;
    }

    private static UUID uuid(Map<String, Object> payload, String field) {
        Object value = payload == null ? null : payload.get(field);
        try {
            return UUID.fromString(String.valueOf(value));
        } catch (IllegalArgumentException ex) {
            throw invalidPayload(field + " must be a UUID");
        }
    }

    private static ApiException invalidPayload(String message) {
        return new ApiException(HttpStatus.BAD_REQUEST, INVALID_PAYLOAD, message);
    }

}
