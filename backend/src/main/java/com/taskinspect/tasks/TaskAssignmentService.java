package com.taskinspect.tasks;

import com.taskinspect.common.error.ApiException;
import com.taskinspect.common.security.CurrentUser;
import com.taskinspect.requirements.RequirementService;
import com.taskinspect.users.RoleName;
import com.taskinspect.users.User;
import com.taskinspect.users.UserRepository;
import com.taskinspect.users.UserService;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Assigns draft tasks to workers (DRAFT → ASSIGNED), publishes them as open
 * tasks (DRAFT → OPEN), and lets a worker take an open task (OPEN → ASSIGNED).
 */
@Service
public class TaskAssignmentService {

    static final String INVALID_ASSIGNEE = "INVALID_ASSIGNEE";
    static final String TASK_HAS_NO_REQUIREMENTS = "TASK_HAS_NO_REQUIREMENTS";
    static final String REVIEWER_IS_ASSIGNEE = "REVIEWER_IS_ASSIGNEE";
    static final String TEAM_HAS_NO_MEMBERS = "TEAM_HAS_NO_MEMBERS";
    static final String TASK_ALREADY_TAKEN = "TASK_ALREADY_TAKEN";
    static final String MAIN_TASK_NOT_PUBLISHABLE = "MAIN_TASK_NOT_PUBLISHABLE";

    /** History reason of a publish, followed by the scope; {@link #take} reads the scope back after it was cleared. */
    private static final String OPEN_TO = "open to: ";

    private final TaskService taskService;
    private final TaskRepository taskRepository;
    private final TaskAssignmentRepository assignmentRepository;
    private final TaskStateMachine stateMachine;
    private final TaskTransitionService transitions;
    private final RequirementService requirementService;
    private final UserService userService;
    private final UserRepository userRepository;
    private final TaskStatusChangeRepository historyRepository;

    public TaskAssignmentService(TaskService taskService, TaskRepository taskRepository,
            TaskAssignmentRepository assignmentRepository, TaskStateMachine stateMachine,
            TaskTransitionService transitions, RequirementService requirementService, UserService userService,
            UserRepository userRepository, TaskStatusChangeRepository historyRepository) {
        this.taskService = taskService;
        this.taskRepository = taskRepository;
        this.assignmentRepository = assignmentRepository;
        this.stateMachine = stateMachine;
        this.transitions = transitions;
        this.requirementService = requirementService;
        this.userService = userService;
        this.userRepository = userRepository;
        this.historyRepository = historyRepository;
    }

    /**
     * Assigns a task to a worker. Only the manager who created the task can
     * assign it; it needs at least one requirement; the assignee must be an
     * active worker of the organization; and the reviewer cannot be the
     * assignee — except for a personal task that the creator assigns to
     * themself (solo use, where the same person reviews). An administrator's
     * main task goes to an active manager instead and needs no requirement.
     */
    @Transactional
    public Task assign(CurrentUser caller, UUID taskId, UUID assigneeId) {
        Task task = taskService.requireEditable(caller, taskId);
        stateMachine.next(task.getStatus(), TaskAction.ASSIGN);
        User assignee;
        if (task.isMainTask()) {
            // The manager passes it on in sub-tasks; the main task has no answers of its own.
            assignee = userService.requireActiveWithRole(assigneeId, task.getOrganization().getId(),
                    RoleName.MANAGER, INVALID_ASSIGNEE, "A main task is assigned to an active manager");
        } else {
            requireRequirements(task, "assigning");
            assignee = userService.requireActiveWithRole(assigneeId, task.getOrganization().getId(),
                    RoleName.WORKER, INVALID_ASSIGNEE, "The assignee must be an active worker");
        }
        boolean personalTask = assignee.getId().equals(task.getCreatedBy().getId());
        if (assignee.getId().equals(task.getReviewer().getId()) && !personalTask) {
            throw new ApiException(HttpStatus.BAD_REQUEST, REVIEWER_IS_ASSIGNEE,
                    "The reviewer cannot also be the worker; choose another reviewer or worker");
        }

        User assigner = userService.requireCaller(caller);
        task.assignTo(assignee);
        transitions.apply(task, TaskAction.ASSIGN, assigner, null);
        assignmentRepository.save(new TaskAssignment(task, assignee, assigner));
        return taskRepository.saveAndFlush(task);
    }

    /**
     * Publishes a draft task without an assignee (DRAFT → OPEN), for a worker
     * to take (task 7A.5c). Only the manager who created the task; it needs at
     * least one requirement; {@code TEAM} needs at least one active member in
     * the caller's team, otherwise nobody could take it.
     */
    @Transactional
    public Task publish(CurrentUser caller, UUID taskId, OpenScope scope) {
        Task task = taskService.requireEditable(caller, taskId);
        stateMachine.next(task.getStatus(), TaskAction.PUBLISH);
        if (task.isMainTask()) {
            throw new ApiException(HttpStatus.CONFLICT, MAIN_TASK_NOT_PUBLISHABLE,
                    "A main task is assigned to a manager, not published");
        }
        requireRequirements(task, "publishing");
        if (scope == OpenScope.TEAM && userRepository.countByTeamManagerIdAndActiveTrue(caller.id()) == 0) {
            throw new ApiException(HttpStatus.CONFLICT, TEAM_HAS_NO_MEMBERS,
                    "Your team has no active workers; publish the task to everyone instead");
        }

        transitions.apply(task, TaskAction.PUBLISH, userService.requireCaller(caller), OPEN_TO + scope);
        task.openTo(scope);
        return taskRepository.saveAndFlush(task);
    }

    /**
     * A worker takes an open task (OPEN → ASSIGNED); from then on it is their
     * task. The task's row is locked first, so when two workers take it at
     * the same time the second one waits and then gets
     * {@code 409 TASK_ALREADY_TAKEN}. Taking it again after a lost answer
     * returns the task unchanged. Tasks the caller may not take (now, or
     * when it was open) answer 404, like any task they cannot see.
     */
    @Transactional
    public Task take(CurrentUser caller, UUID taskId) {
        taskService.lockForUpdate(taskId);
        User worker = userService.requireCaller(caller);
        Task task = taskRepository.findByIdAndOrganizationId(taskId, worker.getOrganization().getId())
                .orElseThrow(TaskAssignmentService::taskNotFound);
        if (task.getStatus() != TaskStatus.OPEN) {
            OpenScope wasOpenTo = scopeWhenPublished(task);
            if (wasOpenTo == null || task.getAssignee() == null) {
                throw taskNotFound();
            }
            if (task.getAssignee().getId().equals(worker.getId())) {
                return task;
            }
            if (!TaskService.mayTake(wasOpenTo, task.getCreatedBy(), worker)) {
                throw taskNotFound();
            }
            throw new ApiException(HttpStatus.CONFLICT, TASK_ALREADY_TAKEN, "Another worker has already taken this task");
        }
        if (!TaskService.mayTake(task.getOpenScope(), task.getCreatedBy(), worker)) {
            throw taskNotFound();
        }
        if (worker.getId().equals(task.getReviewer().getId()) && !worker.getId().equals(task.getCreatedBy().getId())) {
            throw new ApiException(HttpStatus.BAD_REQUEST, REVIEWER_IS_ASSIGNEE,
                    "You are this task's reviewer, so you cannot also be its worker");
        }

        task.assignTo(worker);
        transitions.apply(task, TaskAction.TAKE, worker, null);
        assignmentRepository.save(new TaskAssignment(task, worker, worker));
        return taskRepository.saveAndFlush(task);
    }

    /** Who the task was open to when it was published; {@code null} if it never was. */
    private OpenScope scopeWhenPublished(Task task) {
        return historyRepository.findFirstByTaskIdAndToStatusOrderByChangedAtDescIdDesc(task.getId(), TaskStatus.OPEN)
                .map(TaskStatusChange::getReason)
                .filter(reason -> reason != null && reason.startsWith(OPEN_TO))
                .map(reason -> OpenScope.valueOf(reason.substring(OPEN_TO.length())))
                .orElse(null);
    }

    private static ApiException taskNotFound() {
        return new ApiException(HttpStatus.NOT_FOUND, TaskService.TASK_NOT_FOUND, "Task not found");
    }

    private void requireRequirements(Task task, String action) {
        if (requirementService.count(task.getId()) == 0) {
            throw new ApiException(HttpStatus.CONFLICT, TASK_HAS_NO_REQUIREMENTS,
                    "Add at least one requirement before " + action + " the task");
        }
    }

}
