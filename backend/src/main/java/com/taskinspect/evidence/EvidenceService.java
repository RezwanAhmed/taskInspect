package com.taskinspect.evidence;

import com.taskinspect.common.error.ApiException;
import com.taskinspect.common.security.CurrentUser;
import com.taskinspect.evidence.dto.RegisterEvidenceRequest;
import com.taskinspect.requirements.Requirement;
import com.taskinspect.requirements.RequirementService;
import com.taskinspect.requirements.RequirementType;
import com.taskinspect.tasks.Task;
import com.taskinspect.tasks.TaskService;
import com.taskinspect.tasks.TaskStatus;
import com.taskinspect.users.UserService;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.Set;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

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

    public EvidenceService(EvidenceRepository evidenceRepository, TaskService taskService,
            RequirementService requirementService, UserService userService) {
        this.evidenceRepository = evidenceRepository;
        this.taskService = taskService;
        this.requirementService = requirementService;
        this.userService = userService;
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
        Task task = requireWritable(caller, taskId);
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

    /** Removes evidence from the task (the stored file follows with file storage, task 5.17b). */
    @Transactional
    public void delete(CurrentUser caller, UUID taskId, UUID evidenceId) {
        Task task = requireWritable(caller, taskId);
        Evidence evidence = evidenceRepository.findById(evidenceId)
                .filter(e -> e.getTask().getId().equals(task.getId()))
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, EVIDENCE_NOT_FOUND, "Evidence not found"));
        evidenceRepository.delete(evidence);
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
