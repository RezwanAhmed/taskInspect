package com.taskinspect.requirements;

import com.taskinspect.common.error.ApiException;
import com.taskinspect.common.security.CurrentUser;
import com.taskinspect.requirements.dto.RequirementRequest;
import com.taskinspect.tasks.Task;
import com.taskinspect.tasks.TaskService;
import java.util.List;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Requirements of a task. Anyone who can see the task can read them; only
 * the manager who created the task can change them, before work starts.
 */
@Service
public class RequirementService {

    static final String REQUIREMENT_NOT_FOUND = "REQUIREMENT_NOT_FOUND";
    static final String INVALID_REQUIREMENT = "INVALID_REQUIREMENT";

    private final RequirementRepository requirementRepository;
    private final TaskService taskService;

    public RequirementService(RequirementRepository requirementRepository, TaskService taskService) {
        this.requirementRepository = requirementRepository;
        this.taskService = taskService;
    }

    @Transactional(readOnly = true)
    public List<Requirement> list(CurrentUser caller, UUID taskId) {
        Task task = taskService.get(caller, taskId);
        return requirementRepository.findAllByTaskIdOrderByPosition(task.getId());
    }

    /**
     * A requirement of the given task with its options, for other modules
     * that have already checked the caller's access to the task.
     */
    @Transactional(readOnly = true)
    public Requirement getForTask(UUID taskId, UUID requirementId) {
        return requirementRepository.findWithOptionsById(requirementId)
                .filter(requirement -> requirement.getTask().getId().equals(taskId))
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, REQUIREMENT_NOT_FOUND,
                        "Requirement not found"));
    }

    /** How many requirements a task has, e.g. to check that it can be assigned. */
    @Transactional(readOnly = true)
    public long count(UUID taskId) {
        return requirementRepository.countByTaskId(taskId);
    }

    /** Adds a requirement at the end of the task's list. */
    @Transactional
    public Requirement create(CurrentUser caller, UUID taskId, RequirementRequest request) {
        Task task = taskService.requireEditable(caller, taskId);
        validate(request);
        int position = (int) requirementRepository.countByTaskId(task.getId());
        return requirementRepository.save(new Requirement(task, request.title().trim(),
                clean(request.description()), request.type(), isRequired(request), position, clean(request.unit()),
                trimmed(request.options())));
    }

    @Transactional
    public Requirement update(CurrentUser caller, UUID taskId, UUID requirementId, RequirementRequest request) {
        Task task = taskService.requireEditable(caller, taskId);
        validate(request);
        Requirement requirement = find(task, requirementId);
        requirement.update(request.title().trim(), clean(request.description()), request.type(),
                isRequired(request), clean(request.unit()), trimmed(request.options()));
        return requirementRepository.saveAndFlush(requirement);
    }

    /** Deletes a requirement and closes the gap in the positions of the others. */
    @Transactional
    public void delete(CurrentUser caller, UUID taskId, UUID requirementId) {
        Task task = taskService.requireEditable(caller, taskId);
        requirementRepository.delete(find(task, requirementId));
        requirementRepository.flush();
        List<Requirement> remaining = requirementRepository.findAllByTaskIdOrderByPosition(task.getId());
        for (int i = 0; i < remaining.size(); i++) {
            remaining.get(i).moveTo(i);
        }
    }

    private Requirement find(Task task, UUID requirementId) {
        return requirementRepository.findById(requirementId)
                .filter(requirement -> requirement.getTask().getId().equals(task.getId()))
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, REQUIREMENT_NOT_FOUND,
                        "Requirement not found"));
    }

    private static void validate(RequirementRequest request) {
        List<String> options = request.options() == null ? List.of() : request.options();
        if (request.type().hasOptions() && options.size() < 2) {
            throw invalid(request.type() + " needs at least two options");
        }
        if (!request.type().hasOptions() && !options.isEmpty()) {
            throw invalid(request.type() + " has no options");
        }
        if (request.type() != RequirementType.NUMBER && request.unit() != null && !request.unit().isBlank()) {
            throw invalid("Only NUMBER requirements have a unit");
        }
    }

    private static ApiException invalid(String message) {
        return new ApiException(HttpStatus.BAD_REQUEST, INVALID_REQUIREMENT, message);
    }

    private static boolean isRequired(RequirementRequest request) {
        return request.required() == null || request.required();
    }

    private static String clean(String value) {
        return value == null || value.isBlank() ? null : value.trim();
    }

    private static List<String> trimmed(List<String> options) {
        return options == null ? List.of() : options.stream().map(String::trim).toList();
    }

}
