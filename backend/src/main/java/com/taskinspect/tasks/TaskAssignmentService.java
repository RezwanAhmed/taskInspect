package com.taskinspect.tasks;

import com.taskinspect.common.error.ApiException;
import com.taskinspect.common.security.CurrentUser;
import com.taskinspect.requirements.RequirementService;
import com.taskinspect.users.RoleName;
import com.taskinspect.users.User;
import com.taskinspect.users.UserService;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/** Assigns draft tasks to workers (DRAFT → ASSIGNED). */
@Service
public class TaskAssignmentService {

    static final String INVALID_ASSIGNEE = "INVALID_ASSIGNEE";
    static final String TASK_HAS_NO_REQUIREMENTS = "TASK_HAS_NO_REQUIREMENTS";
    static final String REVIEWER_IS_ASSIGNEE = "REVIEWER_IS_ASSIGNEE";

    private final TaskService taskService;
    private final TaskRepository taskRepository;
    private final TaskAssignmentRepository assignmentRepository;
    private final TaskStateMachine stateMachine;
    private final TaskTransitionService transitions;
    private final RequirementService requirementService;
    private final UserService userService;

    public TaskAssignmentService(TaskService taskService, TaskRepository taskRepository,
            TaskAssignmentRepository assignmentRepository, TaskStateMachine stateMachine,
            TaskTransitionService transitions, RequirementService requirementService, UserService userService) {
        this.taskService = taskService;
        this.taskRepository = taskRepository;
        this.assignmentRepository = assignmentRepository;
        this.stateMachine = stateMachine;
        this.transitions = transitions;
        this.requirementService = requirementService;
        this.userService = userService;
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
        if (requirementService.count(task.getId()) == 0) {
            throw new ApiException(HttpStatus.CONFLICT, TASK_HAS_NO_REQUIREMENTS,
                    "Add at least one requirement before assigning the task");
        }
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

}
