package com.taskinspect.tasks;

import static com.taskinspect.tasks.TaskSpecifications.assignedTo;
import static com.taskinspect.tasks.TaskSpecifications.assignedToTeamOf;
import static com.taskinspect.tasks.TaskSpecifications.dueBefore;
import static com.taskinspect.tasks.TaskSpecifications.dueFrom;
import static com.taskinspect.tasks.TaskSpecifications.hasPriority;
import static com.taskinspect.tasks.TaskSpecifications.hasStatus;
import static com.taskinspect.tasks.TaskSpecifications.inOrganization;
import static com.taskinspect.tasks.TaskSpecifications.notAssignedTo;
import static com.taskinspect.tasks.TaskSpecifications.notInStatus;
import static com.taskinspect.tasks.TaskSpecifications.openFor;

import com.taskinspect.common.error.ApiException;
import com.taskinspect.common.error.ErrorCode;
import com.taskinspect.common.security.CurrentUser;
import com.taskinspect.tasks.dto.CreateTaskRequest;
import com.taskinspect.tasks.dto.UpdateTaskRequest;
import java.util.EnumSet;
import java.util.List;
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
    private static final Set<TaskStatus> EDITABLE = EnumSet.of(TaskStatus.DRAFT, TaskStatus.OPEN, TaskStatus.ASSIGNED);

    private final TaskRepository taskRepository;
    private final UserService userService;
    private final TaskTransitionService transitions;

    public TaskService(TaskRepository taskRepository, UserService userService, TaskTransitionService transitions) {
        this.taskRepository = taskRepository;
        this.userService = userService;
        this.transitions = transitions;
    }

    /**
     * Creates a draft task in the creator's organization. The reviewer must be
     * an active manager of the same organization; by default it is the creator.
     */
    @Transactional
    public Task create(CurrentUser caller, CreateTaskRequest request) {
        User creator = userService.requireCaller(caller);
        Task task = taskRepository.save(new Task(creator, request.title().trim(), clean(request.description()),
                request.priority(), request.dueDate(), reviewer(request.reviewerId(), creator)));
        transitions.recordCreated(task, creator);
        return task;
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
        Task saved = taskRepository.saveAndFlush(task);
        transitions.recordUpdated(saved, saved.getCreatedBy());
        return saved;
    }

    /**
     * The assigned worker starts the task (ASSIGNED → IN_PROGRESS), or starts
     * working on it again after a reject or a correction request.
     */
    @Transactional
    public Task start(CurrentUser caller, UUID id) {
        Task task = requireAssignee(caller, id);
        transitions.apply(task, TaskAction.START, userService.requireCaller(caller), null);
        return taskRepository.saveAndFlush(task);
    }

    /** Something of the task changed (e.g. a requirement); see {@link TaskRepository#markChanged}. */
    @Transactional
    public void markChanged(UUID id) {
        taskRepository.markChanged(id, Instant.now());
    }

    /**
     * Locks the task's row for the rest of the transaction, so a submit and
     * a change of its answers or evidence never run at the same time (one
     * waits for the other and then sees its result). Call it first in the
     * transaction, before the task is loaded, so the checks see the latest
     * state. Unknown IDs are ignored (the checks that follow answer 404).
     */
    @Transactional
    public void lockForUpdate(UUID id) {
        taskRepository.findForUpdate(id);
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
     * managers see every task of their organization; workers see the tasks
     * assigned to them and the open tasks they may take.
     */
    @Transactional(readOnly = true)
    public Page<Task> list(CurrentUser caller, TaskFilter filter, Pageable pageable) {
        Specification<Task> visible = visibleTo(userService.requireCaller(caller));
        return taskRepository.findAll(Specification.allOf(visible, hasStatus(filter.status()),
                hasPriority(filter.priority()), dueFrom(filter.dueFrom()), dueBefore(filter.dueBefore())), pageable);
    }

    /** Every task the caller may see (same rules as {@link #list}), e.g. for the sync pull. */
    @Transactional(readOnly = true)
    public List<Task> listVisible(CurrentUser caller) {
        return taskRepository.findAll(visibleTo(userService.requireCaller(caller)));
    }

    private static Specification<Task> visibleTo(User user) {
        if (canSeeAllTasks(user)) {
            return inOrganization(user.getOrganization().getId());
        }
        Specification<Task> mine = assignedTo(user.getId());
        return Specification.allOf(inOrganization(user.getOrganization().getId()),
                user.hasRole(RoleName.WORKER) ? mine.or(openFor(activeTeamManagerId(user))) : mine);
    }

    /**
     * The tasks of the caller's team members (not the caller's own), shown
     * to them as tiles (docs/architecture.md, "What a Worker Sees").
     * Cancelled tasks are left out; tasks of deactivated members stay (the
     * work still exists). A caller without a team, or whose team manager
     * was deactivated, gets none.
     */
    @Transactional(readOnly = true)
    public Page<Task> listTeam(CurrentUser caller, TaskStatus status, Pageable pageable) {
        User user = userService.requireCaller(caller);
        User teamManager = user.getTeamManager();
        if (teamManager == null || !teamManager.isActive()) {
            return Page.empty(pageable);
        }
        return taskRepository.findAll(Specification.allOf(inOrganization(user.getOrganization().getId()),
                assignedToTeamOf(teamManager.getId()), notAssignedTo(user.getId()),
                notInStatus(TaskStatus.CANCELLED), hasStatus(status)), pageable);
    }

    /** One task the caller may see; 404 for tasks that don't exist or aren't visible. */
    @Transactional(readOnly = true)
    public Task get(CurrentUser caller, UUID id) {
        User user = userService.requireCaller(caller);
        return taskRepository.findByIdAndOrganizationId(id, user.getOrganization().getId())
                .filter(task -> canSeeAllTasks(user) || isAssignee(task, user)
                        || task.getStatus() == TaskStatus.OPEN && mayTake(task.getOpenScope(), task.getCreatedBy(), user))
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, TASK_NOT_FOUND, "Task not found"));
    }

    /**
     * Whether a task open to {@code scope}, published by {@code publisher},
     * is open to the user: a worker, and the scope is everyone or the
     * worker's team (docs/architecture.md, "Open Tasks"). Same rule as
     * {@link TaskSpecifications#openFor}.
     */
    static boolean mayTake(OpenScope scope, User publisher, User user) {
        if (!user.hasRole(RoleName.WORKER)) {
            return false;
        }
        return scope == OpenScope.EVERYONE
                || scope == OpenScope.TEAM && publisher.getId().equals(activeTeamManagerId(user));
    }

    /** The worker's team manager, or {@code null} without a team or when that manager was deactivated (as in {@link #listTeam}). */
    private static UUID activeTeamManagerId(User user) {
        User teamManager = user.getTeamManager();
        return teamManager == null || !teamManager.isActive() ? null : teamManager.getId();
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
