package com.taskinspect.requirements;

import com.taskinspect.common.error.ApiException;
import com.taskinspect.common.security.CurrentUser;
import com.taskinspect.requirements.dto.RequirementRequest;
import com.taskinspect.tasks.Task;
import com.taskinspect.tasks.TaskService;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;
import java.util.stream.Collectors;
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
    static final String REQUIREMENT_ID_CONFLICT = "REQUIREMENT_ID_CONFLICT";
    static final String INVALID_ORDER = "INVALID_ORDER";

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

    /** The requirements of a task, for callers that have already checked access to it. */
    @Transactional(readOnly = true)
    public List<Requirement> listForTask(UUID taskId) {
        return requirementRepository.findAllByTaskIdOrderByPosition(taskId);
    }

    /** Copies every requirement (with its options) of one task to another, in the same order. */
    @Transactional
    public void copyAll(Task from, Task to) {
        for (Requirement requirement : requirementRepository.findAllByTaskIdOrderByPosition(from.getId())) {
            requirementRepository.save(new Requirement(to, requirement.getTitle(), requirement.getDescription(),
                    requirement.getType(), requirement.isRequired(), requirement.getPosition(), requirement.getUnit(),
                    requirement.getOptions().stream().map(RequirementOption::getLabel).toList()));
        }
    }

    /** How many requirements a task has, e.g. to check that it can be assigned. */
    @Transactional(readOnly = true)
    public long count(UUID taskId) {
        return requirementRepository.countByTaskId(taskId);
    }

    /** Adds a requirement at the end of the task's list. */
    @Transactional
    public Requirement create(CurrentUser caller, UUID taskId, RequirementRequest request) {
        return create(caller, taskId, UUID.randomUUID(), request);
    }

    /**
     * Adds a requirement with the ID the app gave it offline (sync push
     * "Requirement CREATE"). Sending it again returns the one already made;
     * an ID used for another task's requirement is refused.
     */
    @Transactional
    public Requirement createWithId(CurrentUser caller, UUID taskId, UUID id, RequirementRequest request) {
        Task task = taskService.requireEditable(caller, taskId);
        Optional<Requirement> existing = requirementRepository.findById(id);
        if (existing.isPresent()) {
            if (!existing.get().getTask().getId().equals(task.getId())) {
                throw new ApiException(HttpStatus.CONFLICT, REQUIREMENT_ID_CONFLICT,
                        "This requirement ID is already used");
            }
            return existing.get();
        }
        return create(caller, taskId, id, request);
    }

    private Requirement create(CurrentUser caller, UUID taskId, UUID id, RequirementRequest request) {
        Task task = taskService.requireEditable(caller, taskId);
        validate(request);
        int position = (int) requirementRepository.countByTaskId(task.getId());
        Requirement requirement = requirementRepository.save(new Requirement(id, task, request.title().trim(),
                clean(request.description()), request.type(), isRequired(request), position, clean(request.unit()),
                trimmed(request.options())));
        taskService.markChanged(task.getId());
        return requirement;
    }

    @Transactional
    public Requirement update(CurrentUser caller, UUID taskId, UUID requirementId, RequirementRequest request) {
        Task task = taskService.requireEditable(caller, taskId);
        validate(request);
        Requirement requirement = find(task, requirementId);
        requirement.update(request.title().trim(), clean(request.description()), request.type(),
                isRequired(request), clean(request.unit()), trimmed(request.options()));
        Requirement saved = requirementRepository.saveAndFlush(requirement);
        taskService.markChanged(task.getId());
        return saved;
    }

    /** Deletes a requirement and closes the gap in the positions of the others. */
    @Transactional
    public void delete(CurrentUser caller, UUID taskId, UUID requirementId) {
        Task task = taskService.requireEditable(caller, taskId);
        remove(task, find(task, requirementId));
    }

    /**
     * Like {@link #delete}, but a requirement the task doesn't have counts as
     * deleted already (sync push "Requirement DELETE": nothing to undo, and
     * the task's later changes must not wait for it).
     */
    @Transactional
    public void deleteIfPresent(CurrentUser caller, UUID taskId, UUID requirementId) {
        Task task = taskService.requireEditable(caller, taskId);
        Optional<Requirement> requirement = requirementRepository.findById(requirementId)
                .filter(found -> found.getTask().getId().equals(task.getId()));
        if (requirement.isPresent()) {
            remove(task, requirement.get());
        }
    }

    private void remove(Task task, Requirement requirement) {
        requirementRepository.delete(requirement);
        requirementRepository.flush();
        List<Requirement> remaining = requirementRepository.findAllByTaskIdOrderByPosition(task.getId());
        for (int i = 0; i < remaining.size(); i++) {
            remaining.get(i).moveTo(i);
        }
        taskService.markChanged(task.getId());
    }

    /**
     * Puts the task's requirements in the given order: [requirementIds] must
     * name each of them exactly once (400 INVALID_ORDER otherwise).
     */
    @Transactional
    public List<Requirement> reorder(CurrentUser caller, UUID taskId, List<UUID> requirementIds) {
        Task task = taskService.requireEditable(caller, taskId);
        List<Requirement> requirements = requirementRepository.findAllByTaskIdOrderByPosition(task.getId());
        Map<UUID, Requirement> byId = requirements.stream()
                .collect(Collectors.toMap(Requirement::getId, requirement -> requirement));
        if (requirementIds.size() != requirements.size() || !byId.keySet().equals(new HashSet<>(requirementIds))) {
            throw new ApiException(HttpStatus.BAD_REQUEST, INVALID_ORDER,
                    "The order must list each requirement of the task exactly once");
        }
        for (int i = 0; i < requirementIds.size(); i++) {
            byId.get(requirementIds.get(i)).moveTo(i);
        }
        requirementRepository.flush();
        taskService.markChanged(task.getId());
        return requirementRepository.findAllByTaskIdOrderByPosition(task.getId());
    }

    private Requirement find(Task task, UUID requirementId) {
        return requirementRepository.findById(requirementId)
                .filter(requirement -> requirement.getTask().getId().equals(task.getId()))
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, REQUIREMENT_NOT_FOUND,
                        "Requirement not found"));
    }

    /** Checks the settings that depend on the type (package-private for the unit tests). */
    static void validate(RequirementRequest request) {
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
