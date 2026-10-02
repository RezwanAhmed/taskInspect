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

/** Assigns draft tasks to workers (DRAFT → ASSIGNED) or publishes them as open tasks (DRAFT → OPEN). */
@Service
public class TaskAssignmentService {

    static final String INVALID_ASSIGNEE = "INVALID_ASSIGNEE";
    static final String TASK_HAS_NO_REQUIREMENTS = "TASK_HAS_NO_REQUIREMENTS";
    static final String REVIEWER_IS_ASSIGNEE = "REVIEWER_IS_ASSIGNEE";
    static final String TEAM_HAS_NO_MEMBERS = "TEAM_HAS_NO_MEMBERS";

    private final TaskService taskService;
    private final TaskRepository taskRepository;
    private final TaskAssignmentRepository assignmentRepository;
    private final TaskStateMachine stateMachine;
    private final TaskTransitionService transitions;
    private final RequirementService requirementService;
    private final UserService userService;
    private final UserRepository userRepository;

    public TaskAssignmentService(TaskService taskService, TaskRepository taskRepository,
            TaskAssignmentRepository assignmentRepository, TaskStateMachine stateMachine,
            TaskTransitionService transitions, RequirementService requirementService, UserService userService,
            UserRepository userRepository) {
        this.taskService = taskService;
        this.taskRepository = taskRepository;
        this.assignmentRepository = assignmentRepository;
        this.stateMachine = stateMachine;
        this.transitions = transitions;
        this.requirementService = requirementService;
        this.userService = userService;
        this.userRepository = userRepository;
    }

    /**
     * Assigns a task to a worker. Only the manager who created the task can
     * assign it; it needs at least one requirement; the assignee must be an
     * active worker of the organization; and the reviewer cannot be the
     * assignee — except for a personal task that the creator assigns to
     * themself (solo use, where the same person reviews).
     */
    @Transactional
    public Task assign(CurrentUser caller, UUID taskId, UUID assigneeId) {
        Task task = taskService.requireEditable(caller, taskId);
        stateMachine.next(task.getStatus(), TaskAction.ASSIGN);
        requireRequirements(task, "assigning");
        User assignee = userService.requireActiveWithRole(assigneeId, task.getOrganization().getId(),
                RoleName.WORKER, INVALID_ASSIGNEE, "The assignee must be an active worker");
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
        requireRequirements(task, "publishing");
        if (scope == OpenScope.TEAM && userRepository.countByTeamManagerIdAndActiveTrue(caller.id()) == 0) {
            throw new ApiException(HttpStatus.CONFLICT, TEAM_HAS_NO_MEMBERS,
                    "Your team has no active workers; publish the task to everyone instead");
        }

        transitions.apply(task, TaskAction.PUBLISH, userService.requireCaller(caller), "open to: " + scope);
        task.openTo(scope);
        return taskRepository.saveAndFlush(task);
    }

    private void requireRequirements(Task task, String action) {
        if (requirementService.count(task.getId()) == 0) {
            throw new ApiException(HttpStatus.CONFLICT, TASK_HAS_NO_REQUIREMENTS,
                    "Add at least one requirement before " + action + " the task");
        }
    }

}
