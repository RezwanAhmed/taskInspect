package com.taskinspect.evidence;

import com.taskinspect.common.error.ApiException;
import com.taskinspect.common.security.CurrentUser;
import com.taskinspect.evidence.dto.RegisterEvidenceRequest;
import com.taskinspect.filestorage.FileStorage;
import com.taskinspect.filestorage.SignedUrl;
import com.taskinspect.requirements.Requirement;
import com.taskinspect.requirements.RequirementService;
import com.taskinspect.requirements.RequirementType;
import com.taskinspect.tasks.Task;
import com.taskinspect.tasks.TaskService;
import com.taskinspect.tasks.TaskStatus;
import com.taskinspect.users.UserService;
import java.time.Clock;
import java.time.Duration;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.OptionalLong;
import java.util.Set;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.transaction.support.TransactionSynchronization;
import org.springframework.transaction.support.TransactionSynchronizationManager;

/**
 * Evidence metadata. Only the assigned worker adds or removes evidence, and
 * only while the task is IN_PROGRESS; anyone who can see the task can list
 * it. File types and sizes are checked before anything is uploaded.
 */
@Service
public class EvidenceService {

    static final String INVALID_EVIDENCE_TYPE = "INVALID_EVIDENCE_TYPE";
    static final String FILE_TOO_LARGE = "FILE_TOO_LARGE";
    static final String EVIDENCE_LOCKED = "EVIDENCE_LOCKED";
    static final String EVIDENCE_ID_CONFLICT = "EVIDENCE_ID_CONFLICT";
    static final String EVIDENCE_NOT_FOUND = "EVIDENCE_NOT_FOUND";
    static final String EVIDENCE_ALREADY_UPLOADED = "EVIDENCE_ALREADY_UPLOADED";
    static final String UPLOAD_INCOMPLETE = "UPLOAD_INCOMPLETE";
    static final String EVIDENCE_NOT_UPLOADED = "EVIDENCE_NOT_UPLOADED";

    /** How long upload and download URLs work. */
    static final Duration URL_VALIDITY = Duration.ofMinutes(10);

    /** Photos: JPEG or PNG, at most 10 MB (photos are compressed on the device). */
    static final long MAX_PHOTO_BYTES = 10L * 1024 * 1024;

    /** PDF documents: at most 20 MB. */
    static final long MAX_DOCUMENT_BYTES = 20L * 1024 * 1024;

    private static final Map<RequirementType, Set<String>> ALLOWED_TYPES = Map.of(
            RequirementType.PHOTO, Set.of("image/jpeg", "image/png"),
            RequirementType.DOCUMENT, Set.of("application/pdf"));

    private static final Map<String, String> EXTENSIONS = Map.of(
            "image/jpeg", "jpg", "image/png", "png", "application/pdf", "pdf");

    private final EvidenceRepository evidenceRepository;
    private final TaskService taskService;
    private final RequirementService requirementService;
    private final UserService userService;
    private final FileStorage fileStorage;
    private final Clock clock;

    public EvidenceService(EvidenceRepository evidenceRepository, TaskService taskService,
            RequirementService requirementService, UserService userService, FileStorage fileStorage, Clock clock) {
        this.evidenceRepository = evidenceRepository;
        this.taskService = taskService;
        this.requirementService = requirementService;
        this.userService = userService;
        this.fileStorage = fileStorage;
        this.clock = clock;
    }

    @Transactional(readOnly = true)
    public List<Evidence> list(CurrentUser caller, UUID taskId) {
        Task task = taskService.get(caller, taskId);
        return evidenceRepository.findAllByTaskIdOrderByCreatedAtAsc(task.getId());
    }

    /**
     * Registers a file for a PHOTO or DOCUMENT requirement. Returns the
     * existing evidence when the same ID was registered before (a repeated
     * request), and whether it was newly created.
     */
    @Transactional
    public Registration register(CurrentUser caller, UUID taskId, UUID requirementId,
            RegisterEvidenceRequest request) {
        Task task = requireLockedWritable(caller, taskId);
        Requirement requirement = requirementService.getForTask(task.getId(), requirementId);

        Optional<Evidence> existing = evidenceRepository.findById(request.id());
        if (existing.isPresent()) {
            Evidence evidence = existing.get();
            if (!evidence.getRequirement().getId().equals(requirement.getId())) {
                throw new ApiException(HttpStatus.CONFLICT, EVIDENCE_ID_CONFLICT,
                        "This evidence ID is already used for another requirement");
            }
            return new Registration(evidence, false);
        }

        String contentType = request.contentType().trim().toLowerCase();
        Set<String> allowed = ALLOWED_TYPES.get(requirement.getType());
        if (allowed == null) {
            throw new ApiException(HttpStatus.BAD_REQUEST, INVALID_EVIDENCE_TYPE,
                    requirement.getType() + " requirements have no evidence files");
        }
        if (!allowed.contains(contentType)) {
            throw new ApiException(HttpStatus.BAD_REQUEST, INVALID_EVIDENCE_TYPE,
                    requirement.getType() + " evidence must be one of " + allowed);
        }
        long max = requirement.getType() == RequirementType.PHOTO ? MAX_PHOTO_BYTES : MAX_DOCUMENT_BYTES;
        if (request.sizeBytes() > max) {
            throw new ApiException(HttpStatus.BAD_REQUEST, FILE_TOO_LARGE,
                    "The file is larger than " + (max / 1024 / 1024) + " MB");
        }

        String storageKey = "tasks/" + task.getId() + "/" + request.id() + "." + EXTENSIONS.get(contentType);
        Evidence evidence = evidenceRepository.saveAndFlush(new Evidence(request.id(), task, requirement,
                userService.requireCaller(caller), request.fileName().trim(), contentType, request.sizeBytes(),
                storageKey));
        return new Registration(evidence, true);
    }

    /** A signed URL for uploading the registered file (pre-signed S3 URL in production). */
    @Transactional(readOnly = true)
    public SignedUrl uploadUrl(CurrentUser caller, UUID taskId, UUID evidenceId) {
        Evidence evidence = find(requireWritable(caller, taskId), evidenceId);
        if (evidence.getStatus() == EvidenceStatus.UPLOADED) {
            throw new ApiException(HttpStatus.CONFLICT, EVIDENCE_ALREADY_UPLOADED, "The file is already uploaded");
        }
        return fileStorage.uploadUrl(evidence.getStorageKey(), evidence.getContentType(), evidence.getSizeBytes(),
                URL_VALIDITY);
    }

    /**
     * Marks the evidence as uploaded after checking that the stored file has
     * the registered size. Calling it again after success is harmless.
     */
    @Transactional
    public Evidence complete(CurrentUser caller, UUID taskId, UUID evidenceId) {
        Evidence evidence = find(requireLockedWritable(caller, taskId), evidenceId);
        if (evidence.getStatus() == EvidenceStatus.UPLOADED) {
            return evidence;
        }
        OptionalLong stored = fileStorage.size(evidence.getStorageKey());
        if (stored.isEmpty() || stored.getAsLong() != evidence.getSizeBytes()) {
            throw new ApiException(HttpStatus.CONFLICT, UPLOAD_INCOMPLETE, stored.isEmpty()
                    ? "The file has not been uploaded yet"
                    : "The uploaded file has " + stored.getAsLong() + " bytes, registered " + evidence.getSizeBytes());
        }
        evidence.markUploaded(clock.instant());
        return evidence;
    }

    /** A signed URL for viewing an uploaded file; for anyone who can see the task. */
    @Transactional(readOnly = true)
    public SignedUrl downloadUrl(CurrentUser caller, UUID taskId, UUID evidenceId) {
        Evidence evidence = find(taskService.get(caller, taskId), evidenceId);
        if (evidence.getStatus() != EvidenceStatus.UPLOADED) {
            throw new ApiException(HttpStatus.CONFLICT, EVIDENCE_NOT_UPLOADED, "The file has not been uploaded yet");
        }
        return fileStorage.downloadUrl(evidence.getStorageKey(), URL_VALIDITY);
    }

    /** Removes evidence from the task; the stored file is deleted once the change is committed. */
    @Transactional
    public void delete(CurrentUser caller, UUID taskId, UUID evidenceId) {
        Evidence evidence = find(requireLockedWritable(caller, taskId), evidenceId);
        evidenceRepository.delete(evidence);
        String key = evidence.getStorageKey();
        TransactionSynchronizationManager.registerSynchronization(new TransactionSynchronization() {
            @Override
            public void afterCommit() {
                fileStorage.delete(key);
            }
        });
    }

    private Evidence find(Task task, UUID evidenceId) {
        return evidenceRepository.findById(evidenceId)
                .filter(e -> e.getTask().getId().equals(task.getId()))
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, EVIDENCE_NOT_FOUND, "Evidence not found"));
    }

    /**
     * Like {@link #requireWritable}, for changes: waits for a submit of the
     * task running at the same time (then the evidence is locked). Not for
     * read-only transactions (a row lock needs a writable one).
     */
    private Task requireLockedWritable(CurrentUser caller, UUID taskId) {
        taskService.lockForUpdate(taskId);
        return requireWritable(caller, taskId);
    }

    private Task requireWritable(CurrentUser caller, UUID taskId) {
        Task task = taskService.requireAssignee(caller, taskId);
        if (task.getStatus() != TaskStatus.IN_PROGRESS) {
            throw new ApiException(HttpStatus.CONFLICT, EVIDENCE_LOCKED,
                    "Evidence can only be changed while the task is IN_PROGRESS (status " + task.getStatus() + ")");
        }
        return task;
    }

    /** The registered evidence and whether this request created it. */
    public record Registration(Evidence evidence, boolean created) {
    }

}
