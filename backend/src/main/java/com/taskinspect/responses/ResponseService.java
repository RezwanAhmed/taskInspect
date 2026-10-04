package com.taskinspect.responses;

import com.taskinspect.common.error.ApiException;
import com.taskinspect.common.security.CurrentUser;
import com.taskinspect.requirements.Requirement;
import com.taskinspect.requirements.RequirementOption;
import com.taskinspect.requirements.RequirementService;
import com.taskinspect.reviews.CorrectionScope;
import com.taskinspect.responses.dto.SaveResponseRequest;
import com.taskinspect.tasks.Task;
import com.taskinspect.tasks.TaskService;
import com.taskinspect.tasks.TaskStatus;
import com.taskinspect.users.UserService;
import java.util.HashSet;
import java.util.List;
import java.util.Set;
import java.util.UUID;
import java.util.stream.Collectors;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * The worker's answers. Only the assigned worker answers, and only while the
 * task is IN_PROGRESS; anyone who can see the task can read the answers.
 */
@Service
public class ResponseService {

    static final String INVALID_RESPONSE = "INVALID_RESPONSE";
    static final String USE_EVIDENCE_UPLOAD = "USE_EVIDENCE_UPLOAD";
    static final String RESPONSES_LOCKED = "RESPONSES_LOCKED";

    private final ResponseRepository responseRepository;
    private final TaskService taskService;
    private final RequirementService requirementService;
    private final UserService userService;
    private final CorrectionScope correctionScope;

    public ResponseService(ResponseRepository responseRepository, TaskService taskService,
            RequirementService requirementService, UserService userService, CorrectionScope correctionScope) {
        this.responseRepository = responseRepository;
        this.taskService = taskService;
        this.requirementService = requirementService;
        this.userService = userService;
        this.correctionScope = correctionScope;
    }

    @Transactional(readOnly = true)
    public List<Response> list(CurrentUser caller, UUID taskId) {
        Task task = taskService.get(caller, taskId);
        return responseRepository.findAllByTaskId(task.getId());
    }

    /** Saves (or replaces) the answer to one requirement. Sending the same answer again is harmless. */
    @Transactional
    public Response save(CurrentUser caller, UUID taskId, UUID requirementId, SaveResponseRequest request) {
        // Waits for a submit of the task running at the same time (then the answers are locked).
        taskService.lockForUpdate(taskId);
        Task task = taskService.requireAssignee(caller, taskId);
        if (task.getStatus() != TaskStatus.IN_PROGRESS) {
            throw new ApiException(HttpStatus.CONFLICT, RESPONSES_LOCKED,
                    "Answers can only be changed while the task is IN_PROGRESS (status " + task.getStatus() + ")");
        }
        Requirement requirement = requirementService.getForTask(task.getId(), requirementId);
        // While correcting, only the requirements the reviewer marked.
        correctionScope.requireChangeable(task, requirement.getId());
        validate(requirement, request);

        Response response = responseRepository.findByRequirementId(requirement.getId())
                .orElseGet(() -> new Response(task, requirement));
        response.answer(userService.requireCaller(caller), request.booleanValue(), clean(request.textValue()),
                request.numberValue(), request.selectedOptionIds() == null || request.selectedOptionIds().isEmpty()
                        ? null : List.copyOf(request.selectedOptionIds()),
                clean(request.comment()));
        return responseRepository.saveAndFlush(response);
    }

    /** Checks that the answer fits the requirement type (package-private for the unit tests). */
    static void validate(Requirement requirement, SaveResponseRequest request) {
        boolean hasBoolean = request.booleanValue() != null;
        boolean hasText = request.textValue() != null && !request.textValue().isBlank();
        boolean hasNumber = request.numberValue() != null;
        List<UUID> selected = request.selectedOptionIds() == null ? List.of() : request.selectedOptionIds();
        boolean hasSelection = !selected.isEmpty();

        switch (requirement.getType()) {
            case CHECKBOX, YES_NO -> expectOnly(hasBoolean, !hasText && !hasNumber && !hasSelection,
                    "booleanValue (true or false)");
            case TEXT, COMMENT -> expectOnly(hasText, !hasBoolean && !hasNumber && !hasSelection, "textValue");
            case NUMBER -> expectOnly(hasNumber, !hasBoolean && !hasText && !hasSelection, "numberValue");
            case DROPDOWN -> {
                expectOnly(selected.size() == 1, !hasBoolean && !hasText && !hasNumber,
                        "exactly one selectedOptionIds entry");
                checkOptions(requirement, selected);
            }
            case MULTIPLE_SELECTION -> {
                expectOnly(hasSelection, !hasBoolean && !hasText && !hasNumber,
                        "one or more selectedOptionIds");
                checkOptions(requirement, selected);
            }
            case PHOTO, DOCUMENT -> throw new ApiException(HttpStatus.BAD_REQUEST, USE_EVIDENCE_UPLOAD,
                    requirement.getType() + " requirements are answered by uploading evidence");
        }
    }

    private static void expectOnly(boolean hasExpected, boolean noOthers, String expected) {
        if (!hasExpected || !noOthers) {
            throw new ApiException(HttpStatus.BAD_REQUEST, INVALID_RESPONSE,
                    "This requirement is answered with " + expected + " only");
        }
    }

    private static void checkOptions(Requirement requirement, List<UUID> selected) {
        Set<UUID> allowed = requirement.getOptions().stream().map(RequirementOption::getId)
                .collect(Collectors.toSet());
        if (!allowed.containsAll(selected) || new HashSet<>(selected).size() != selected.size()) {
            throw new ApiException(HttpStatus.BAD_REQUEST, INVALID_RESPONSE,
                    "selectedOptionIds must be different options of this requirement");
        }
    }

    private static String clean(String value) {
        return value == null || value.isBlank() ? null : value.trim();
    }

}
