package com.taskinspect.reviews;

import com.taskinspect.common.error.ApiException;
import com.taskinspect.common.error.ErrorCode;
import com.taskinspect.common.security.CurrentUser;
import com.taskinspect.requirements.RequirementService;
import com.taskinspect.reviews.dto.CorrectionRequest;
import com.taskinspect.tasks.Task;
import com.taskinspect.tasks.TaskAction;
import com.taskinspect.tasks.TaskRepository;
import com.taskinspect.tasks.TaskService;
import com.taskinspect.tasks.TaskStateMachine;
import com.taskinspect.tasks.TaskTransitionService;
import com.taskinspect.users.User;
import com.taskinspect.users.UserService;
import java.util.HashSet;
import java.util.List;
import java.util.Set;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Reviews submitted tasks (docs/architecture.md "Task Lifecycle"): approve,
 * reject (the whole task goes back, with a reason) or request correction
 * (only the marked requirements go back, each with a comment). Only the
 * task's reviewer, and never the assigned worker - except a personal task
 * a manager assigned to themself (solo account). The status change, its
 * history and audit entry and the review record are saved together.
 */
@Service
public class ReviewService {

    public static final String NOT_TASK_REVIEWER = "NOT_TASK_REVIEWER";
    public static final String REVIEWER_IS_ASSIGNEE = "REVIEWER_IS_ASSIGNEE";

    private final TaskService taskService;
    private final TaskStateMachine stateMachine;
    private final TaskTransitionService transitions;
    private final TaskRepository taskRepository;
    private final RequirementService requirementService;
    private final ReviewRepository reviewRepository;
    private final UserService userService;

    public ReviewService(TaskService taskService, TaskStateMachine stateMachine, TaskTransitionService transitions,
            TaskRepository taskRepository, RequirementService requirementService, ReviewRepository reviewRepository,
            UserService userService) {
        this.taskService = taskService;
        this.stateMachine = stateMachine;
        this.transitions = transitions;
        this.taskRepository = taskRepository;
        this.requirementService = requirementService;
        this.reviewRepository = reviewRepository;
        this.userService = userService;
    }

    @Transactional
    public Task approve(CurrentUser caller, UUID taskId, String comment) {
        return review(caller, taskId, TaskAction.APPROVE, ReviewResult.APPROVED, clean(comment), List.of());
    }

    @Transactional
    public Task reject(CurrentUser caller, UUID taskId, String reason) {
        return review(caller, taskId, TaskAction.REJECT, ReviewResult.REJECTED, clean(reason), List.of());
    }

    @Transactional
    public Task requestCorrection(CurrentUser caller, UUID taskId, CorrectionRequest request) {
        List<MarkedRequirement> marked = request.requirements().stream()
                .map(item -> new MarkedRequirement(item.requirementId(), item.comment().trim()))
                .toList();
        return review(caller, taskId, TaskAction.REQUEST_CORRECTION, ReviewResult.CORRECTION_REQUESTED,
                clean(request.reason()), marked);
    }

    /** The task's reviews, oldest first; for anyone who can see the task. */
    @Transactional(readOnly = true)
    public List<Review> list(CurrentUser caller, UUID taskId) {
        Task task = taskService.get(caller, taskId);
        return reviewRepository.findAllByTaskIdOrderByCreatedAtAscIdAsc(task.getId());
    }

    private Task review(CurrentUser caller, UUID taskId, TaskAction action, ReviewResult result, String reason,
            List<MarkedRequirement> marked) {
        // Waits for a change of the task running at the same time, then sees its result.
        taskService.lockForUpdate(taskId);
        Task task = taskService.get(caller, taskId);
        User reviewer = userService.requireCaller(caller);
        if (!task.getReviewer().getId().equals(reviewer.getId())) {
            throw new ApiException(HttpStatus.FORBIDDEN, NOT_TASK_REVIEWER, "Only the task's reviewer can review it");
        }
        boolean reviewsOwnWork = task.getAssignee() != null && task.getAssignee().getId().equals(reviewer.getId());
        if (reviewsOwnWork && !task.getCreatedBy().getId().equals(reviewer.getId())) {
            throw new ApiException(HttpStatus.FORBIDDEN, REVIEWER_IS_ASSIGNEE,
                    "The worker of a task cannot review it (except their own personal task)");
        }
        // The status next (409), then the marked requirements.
        stateMachine.next(task.getStatus(), action);
        Set<UUID> seen = new HashSet<>();
        for (MarkedRequirement item : marked) {
            if (!seen.add(item.getRequirementId())) {
                throw new ApiException(HttpStatus.BAD_REQUEST, ErrorCode.VALIDATION_ERROR,
                        "Each requirement can be marked only once");
            }
            requirementService.getForTask(task.getId(), item.getRequirementId());
        }
        transitions.apply(task, action, reviewer, historyReason(reason, marked));
        reviewRepository.save(new Review(task, reviewer, result, reason, marked));
        return taskRepository.saveAndFlush(task);
    }

    /** What the status history shows: the reason, and how many requirements were marked. */
    private static String historyReason(String reason, List<MarkedRequirement> marked) {
        if (marked.isEmpty()) {
            return reason;
        }
        String count = marked.size() + (marked.size() == 1 ? " requirement" : " requirements") + " to correct";
        return reason == null ? count : reason + " (" + count + ")";
    }

    private static String clean(String value) {
        return value == null || value.isBlank() ? null : value.trim();
    }

}
