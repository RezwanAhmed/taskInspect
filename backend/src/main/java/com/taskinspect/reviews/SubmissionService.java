package com.taskinspect.reviews;

import com.taskinspect.common.error.ApiException;
import com.taskinspect.common.error.ErrorResponse;
import com.taskinspect.common.security.CurrentUser;
import com.taskinspect.evidence.Evidence;
import com.taskinspect.evidence.EvidenceRepository;
import com.taskinspect.evidence.EvidenceStatus;
import com.taskinspect.requirements.Requirement;
import com.taskinspect.requirements.RequirementRepository;
import com.taskinspect.requirements.RequirementType;
import com.taskinspect.responses.Response;
import com.taskinspect.responses.ResponseRepository;
import com.taskinspect.tasks.Task;
import com.taskinspect.tasks.TaskAction;
import com.taskinspect.tasks.TaskRepository;
import com.taskinspect.tasks.TaskService;
import com.taskinspect.tasks.TaskStateMachine;
import com.taskinspect.tasks.TaskTransitionService;
import com.taskinspect.users.UserService;
import java.util.List;
import java.util.Set;
import java.util.UUID;
import java.util.stream.Collectors;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Submits a task for review (IN_PROGRESS -> SUBMITTED, see
 * docs/architecture.md "Task Lifecycle"). Only the assigned worker, and only
 * when every required requirement is answered: a response for questions,
 * at least one uploaded file for PHOTO and DOCUMENT requirements. No file
 * may still be waiting for its upload, so a reviewer never sees evidence
 * the server doesn't have.
 */
@Service
public class SubmissionService {

    public static final String REQUIREMENTS_MISSING = "REQUIREMENTS_MISSING";
    public static final String EVIDENCE_NOT_UPLOADED = "EVIDENCE_NOT_UPLOADED";

    private final TaskService taskService;
    private final TaskStateMachine stateMachine;
    private final TaskTransitionService transitions;
    private final TaskRepository taskRepository;
    private final RequirementRepository requirementRepository;
    private final ResponseRepository responseRepository;
    private final EvidenceRepository evidenceRepository;
    private final UserService userService;
    private final ReviewRepository reviewRepository;

    public SubmissionService(TaskService taskService, TaskStateMachine stateMachine,
            TaskTransitionService transitions, TaskRepository taskRepository,
            RequirementRepository requirementRepository, ResponseRepository responseRepository,
            EvidenceRepository evidenceRepository, UserService userService, ReviewRepository reviewRepository) {
        this.taskService = taskService;
        this.stateMachine = stateMachine;
        this.transitions = transitions;
        this.taskRepository = taskRepository;
        this.requirementRepository = requirementRepository;
        this.responseRepository = responseRepository;
        this.evidenceRepository = evidenceRepository;
        this.userService = userService;
        this.reviewRepository = reviewRepository;
    }

    @Transactional
    public Task submit(CurrentUser caller, UUID taskId) {
        taskService.lockForUpdate(taskId);
        Task task = taskService.requireAssignee(caller, taskId);
        // The status first (409 TASK_INVALID_TRANSITION etc.), then what is missing.
        stateMachine.next(task.getStatus(), TaskAction.SUBMIT);

        List<Evidence> evidence = evidenceRepository.findAllByTaskIdOrderByCreatedAtAsc(task.getId());
        long waiting = evidence.stream().filter(e -> e.getStatus() != EvidenceStatus.UPLOADED).count();
        if (waiting > 0) {
            throw new ApiException(HttpStatus.CONFLICT, EVIDENCE_NOT_UPLOADED,
                    waiting + (waiting == 1 ? " file is" : " files are") + " not uploaded yet");
        }

        Set<UUID> answered = responseRepository.findAllByTaskId(task.getId()).stream()
                .map(Response::getRequirement).map(Requirement::getId).collect(Collectors.toSet());
        Set<UUID> withFiles = evidence.stream()
                .map(Evidence::getRequirement).map(Requirement::getId).collect(Collectors.toSet());
        List<ErrorResponse.FieldError> missing = requirementRepository.findAllByTaskIdOrderByPosition(task.getId())
                .stream()
                .filter(Requirement::isRequired)
                .filter(r -> !(isEvidence(r.getType()) ? withFiles : answered).contains(r.getId()))
                .map(r -> new ErrorResponse.FieldError(r.getId().toString(), r.getTitle() + ": " + needs(r.getType())))
                .toList();
        if (!missing.isEmpty()) {
            throw new ApiException(HttpStatus.CONFLICT, REQUIREMENTS_MISSING,
                    "Complete every required requirement before submitting (" + missing.size() + " missing)",
                    missing);
        }

        // After a reject or a correction request the history shows the resubmit.
        String reason = reviewRepository.existsByTaskId(task.getId()) ? "Resubmitted" : null;
        transitions.apply(task, TaskAction.SUBMIT, userService.requireCaller(caller), reason);
        return taskRepository.saveAndFlush(task);
    }

    private static boolean isEvidence(RequirementType type) {
        return type == RequirementType.PHOTO || type == RequirementType.DOCUMENT;
    }

    private static String needs(RequirementType type) {
        return switch (type) {
            case PHOTO -> "a photo is required";
            case DOCUMENT -> "a document is required";
            default -> "an answer is required";
        };
    }

}
