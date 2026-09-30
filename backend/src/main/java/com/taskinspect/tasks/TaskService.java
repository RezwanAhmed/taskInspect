package com.taskinspect.tasks;

import static com.taskinspect.tasks.TaskSpecifications.assignedTo;
import static com.taskinspect.tasks.TaskSpecifications.dueBefore;
import static com.taskinspect.tasks.TaskSpecifications.dueFrom;
import static com.taskinspect.tasks.TaskSpecifications.hasPriority;
import static com.taskinspect.tasks.TaskSpecifications.hasStatus;
import static com.taskinspect.tasks.TaskSpecifications.inOrganization;

import com.taskinspect.common.error.ApiException;
import com.taskinspect.common.error.ErrorCode;
import com.taskinspect.common.security.CurrentUser;
import com.taskinspect.tasks.dto.CreateTaskRequest;
import com.taskinspect.tasks.dto.UpdateTaskRequest;
import java.util.EnumSet;
import java.util.Set;
import com.taskinspect.users.RoleName;
import com.taskinspect.users.User;
import com.taskinspect.users.UserService;
import java.time.Instant;
import java.util.UUID;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.domain.Specification;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class TaskService {

    static final String INVALID_REVIEWER = "INVALID_REVIEWER";
    static final String TASK_NOT_FOUND = "TASK_NOT_FOUND";
    static final String TASK_NOT_EDITABLE = "TASK_NOT_EDITABLE";

    /** A task's details can change only until the worker starts it. */
    private static final Set<TaskStatus> EDITABLE = EnumSet.of(TaskStatus.DRAFT, TaskStatus.ASSIGNED);

    private final TaskRepository taskRepository;
    private final UserService userService;
    private final TaskStateMachine stateMachine;

    public TaskService(TaskRepository taskRepository, UserService userService, TaskStateMachine stateMachine) {
        this.taskRepository = taskRepository;
        this.userService = userService;
        this.stateMachine = stateMachine;
    }

    /**
     * Creates a draft task in the creator's organization. The reviewer must be
     * an active manager of the same organization; by default it is the creator.
     */
    @Transactional
    public Task create(CurrentUser caller, CreateTaskRequest request) {
        User creator = userService.requireCaller(caller);
        return taskRepository.save(new Task(creator, request.title().trim(), clean(request.description()),
                request.priority(), request.dueDate(), reviewer(request.reviewerId(), creator)));
    }

    /**
     * Replaces a task's details. Only the manager who created the task can
     * edit it, only before work starts, and only if nobody changed it since
     * the client loaded it.
     */
    @Transactional
    public Task update(CurrentUser caller, UUID id, UpdateTaskRequest request) {
        Task task = requireEditable(caller, id);
        if (task.getVersion() != request.version()) {
            throw new ApiException(HttpStatus.CONFLICT, ErrorCode.VERSION_CONFLICT,
                    "This task was changed by someone else. Reload it and try again.");
        }
        task.updateDetails(request.title().trim(), clean(request.description()), request.priority(),
                request.dueDate(), reviewer(request.reviewerId(), task.getCreatedBy()));
        return taskRepository.saveAndFlush(task);
    }

    /**
     * The assigned worker starts the task (ASSIGNED → IN_PROGRESS), or starts
     * working on it again after a reject or a correction request.
     */
    @Transactional
    public Task start(CurrentUser caller, UUID id) {
        Task task = requireAssignee(caller, id);
        stateMachine.apply(task, TaskAction.START);
        return taskRepository.saveAndFlush(task);
    }

    /** A task the caller works on: only its assigned worker gets it. */
    @Transactional(readOnly = true)
    public Task requireAssignee(CurrentUser caller, UUID id) {
        Task task = get(caller, id);
        if (task.getAssignee() == null || !task.getAssignee().getId().equals(caller.id())) {
            throw new ApiException(HttpStatus.FORBIDDEN, ErrorCode.FORBIDDEN,
                    "Only the worker the task is assigned to can do this");
        }
        return task;
    }

    /**
     * A task the caller may change (details or requirements): only the
     * manager who created it, and only before work starts.
     */
    @Transactional(readOnly = true)
    public Task requireEditable(CurrentUser caller, UUID id) {
        Task task = get(caller, id);
        if (!task.getCreatedBy().getId().equals(caller.id())) {
            throw new ApiException(HttpStatus.FORBIDDEN, ErrorCode.FORBIDDEN,
                    "Only the manager who created the task can edit it");
        }
        if (!EDITABLE.contains(task.getStatus())) {
            throw new ApiException(HttpStatus.CONFLICT, TASK_NOT_EDITABLE,
                    "A task can only be edited before work starts (status " + task.getStatus() + ")");
        }
        return task;
    }

    private User reviewer(UUID reviewerId, User creator) {
        return reviewerId == null ? null
                : userService.requireActiveWithRole(reviewerId, creator.getOrganization().getId(),
                        RoleName.MANAGER, INVALID_REVIEWER, "The reviewer must be an active manager");
    }

    private static String clean(String description) {
        return description == null || description.isBlank() ? null : description.trim();
    }


    /**
     * Tasks the caller may see, filtered and paged. Administrators and
     * managers see every task of their organization; workers see only the
     * tasks assigned to them.
     */
    @Transactional(readOnly = true)
    public Page<Task> list(CurrentUser caller, TaskFilter filter, Pageable pageable) {
        User user = userService.requireCaller(caller);
        Specification<Task> visible = canSeeAllTasks(user)
                ? inOrganization(user.getOrganization().getId())
                : Specification.allOf(inOrganization(user.getOrganization().getId()), assignedTo(user.getId()));
        return taskRepository.findAll(Specification.allOf(visible, hasStatus(filter.status()),
                hasPriority(filter.priority()), dueFrom(filter.dueFrom()), dueBefore(filter.dueBefore())), pageable);
    }

    /** One task the caller may see; 404 for tasks that don't exist or aren't visible. */
    @Transactional(readOnly = true)
    public Task get(CurrentUser caller, UUID id) {
        User user = userService.requireCaller(caller);
        return taskRepository.findByIdAndOrganizationId(id, user.getOrganization().getId())
                .filter(task -> canSeeAllTasks(user) || isAssignee(task, user))
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, TASK_NOT_FOUND, "Task not found"));
    }

    private static boolean isAssignee(Task task, User user) {
        return task.getAssignee() != null && task.getAssignee().getId().equals(user.getId());
    }

    private static boolean canSeeAllTasks(User user) {
        return user.hasRole(RoleName.ADMINISTRATOR) || user.hasRole(RoleName.MANAGER);
    }

    /** Optional filters for the task list; {@code null} means "any". */
    public record TaskFilter(TaskStatus status, TaskPriority priority, Instant dueFrom, Instant dueBefore) {
    }

}
