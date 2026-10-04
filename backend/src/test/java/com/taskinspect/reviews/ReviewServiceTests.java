package com.taskinspect.reviews;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.taskinspect.common.error.ApiException;
import com.taskinspect.common.error.ErrorCode;
import com.taskinspect.common.security.CurrentUser;
import com.taskinspect.requirements.RequirementService;
import com.taskinspect.reviews.dto.CorrectionRequest;
import com.taskinspect.tasks.Task;
import com.taskinspect.tasks.TaskAction;
import com.taskinspect.tasks.TaskFixtures;
import com.taskinspect.tasks.TaskPriority;
import com.taskinspect.tasks.TaskRepository;
import com.taskinspect.tasks.TaskService;
import com.taskinspect.tasks.TaskStateMachine;
import com.taskinspect.tasks.TaskTransitionService;
import com.taskinspect.users.User;
import com.taskinspect.users.UserService;
import java.time.Instant;
import java.util.Arrays;
import java.util.List;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.http.HttpStatus;

/** Unit tests of the review rules: who may review, and what is recorded (task 9.1c). */
class ReviewServiceTests {

    private final TaskService taskService = mock(TaskService.class);
    private final TaskStateMachine stateMachine = new TaskStateMachine();
    private final TaskTransitionService transitions = mock(TaskTransitionService.class);
    private final TaskRepository taskRepository = mock(TaskRepository.class);
    private final RequirementService requirementService = mock(RequirementService.class);
    private final ReviewRepository reviewRepository = mock(ReviewRepository.class);
    private final UserService userService = mock(UserService.class);
    private final ReviewService service = new ReviewService(taskService, stateMachine, transitions, taskRepository,
            requirementService, reviewRepository, userService);

    private final User manager = user();
    private final User worker = user();
    private final CurrentUser managerCaller = caller(manager);
    private final CurrentUser workerCaller = caller(worker);

    @Test
    void theReviewerApprovesAndTheReviewIsSaved() {
        Task task = submitted(manager, worker);

        service.approve(managerCaller, task.getId(), "  Well done ");

        verify(taskService).lockForUpdate(task.getId());
        verify(transitions).apply(task, TaskAction.APPROVE, manager, "Well done");
        Review review = savedReview();
        assertThat(review.getResult()).isEqualTo(ReviewResult.APPROVED);
        assertThat(review.getReviewer()).isSameAs(manager);
        assertThat(review.getReason()).isEqualTo("Well done");
        verify(taskRepository).saveAndFlush(task);
    }

    @Test
    void aBlankReasonIsStoredAsNone() {
        Task task = submitted(manager, worker);

        service.reject(managerCaller, task.getId(), "   ");

        verify(transitions).apply(task, TaskAction.REJECT, manager, null);
        assertThat(savedReview().getResult()).isEqualTo(ReviewResult.REJECTED);
    }

    @Test
    void onlyTheTasksReviewerMayReview() {
        User otherManager = user();
        Task task = submitted(manager, worker);
        visibleTo(otherManager, task);

        assertRefused(() -> service.approve(caller(otherManager), task.getId(), null), HttpStatus.FORBIDDEN,
                ReviewService.NOT_TASK_REVIEWER);
    }

    @Test
    void theWorkerCannotReviewTheirOwnWork() {
        Task task = taskOf(manager, worker, worker, TaskAction.ASSIGN, TaskAction.START, TaskAction.SUBMIT);
        visibleTo(worker, task);

        assertRefused(() -> service.approve(workerCaller, task.getId(), null), HttpStatus.FORBIDDEN,
                ReviewService.REVIEWER_IS_ASSIGNEE);
    }

    @Test
    void aManagerReviewsTheirOwnPersonalTask() {
        Task task = submitted(manager, manager);

        service.approve(managerCaller, task.getId(), null);

        verify(transitions).apply(task, TaskAction.APPROVE, manager, null);
    }

    @Test
    void theStatusIsCheckedBeforeTheMarkedRequirements() {
        Task task = taskOf(manager, manager, worker, TaskAction.ASSIGN, TaskAction.START);
        visibleTo(manager, task);
        UUID requirement = UUID.randomUUID();

        assertRefused(() -> service.requestCorrection(managerCaller, task.getId(),
                        correction(null, requirement, requirement)),
                HttpStatus.CONFLICT, TaskStateMachine.TASK_INVALID_TRANSITION);
        verify(requirementService, never()).getForTask(any(), any());
    }

    @Test
    void aRequirementCanBeMarkedOnlyOnce() {
        Task task = submitted(manager, worker);
        UUID requirement = UUID.randomUUID();

        assertRefused(() -> service.requestCorrection(managerCaller, task.getId(),
                correction(null, requirement, requirement)), HttpStatus.BAD_REQUEST, ErrorCode.VALIDATION_ERROR);
    }

    @Test
    void markedRequirementsMustBelongToTheTask() {
        Task task = submitted(manager, worker);
        UUID foreign = UUID.randomUUID();
        when(requirementService.getForTask(task.getId(), foreign))
                .thenThrow(new ApiException(HttpStatus.NOT_FOUND, "REQUIREMENT_NOT_FOUND", "Requirement not found"));

        assertRefused(() -> service.requestCorrection(managerCaller, task.getId(), correction(null, foreign)),
                HttpStatus.NOT_FOUND, "REQUIREMENT_NOT_FOUND");
    }

    @Test
    void theHistoryShowsHowManyRequirementsGoBack() {
        Task task = submitted(manager, worker);
        UUID first = UUID.randomUUID();
        UUID second = UUID.randomUUID();

        service.requestCorrection(managerCaller, task.getId(), correction("Too dark", first));
        service.requestCorrection(managerCaller, task.getId(), correction(null, first, second));

        verify(transitions).apply(task, TaskAction.REQUEST_CORRECTION, manager, "Too dark (1 requirement to correct)");
        verify(transitions).apply(task, TaskAction.REQUEST_CORRECTION, manager, "2 requirements to correct");
    }

    @Test
    void markedCommentsAreTrimmedAndSavedWithTheReview() {
        Task task = submitted(manager, worker);
        UUID requirement = UUID.randomUUID();

        service.requestCorrection(managerCaller, task.getId(), correction(null, requirement));

        Review review = savedReview();
        assertThat(review.getResult()).isEqualTo(ReviewResult.CORRECTION_REQUESTED);
        assertThat(review.getMarkedRequirements()).singleElement().satisfies(marked -> {
            assertThat(marked.getRequirementId()).isEqualTo(requirement);
            assertThat(marked.getComment()).isEqualTo("Fix this");
        });
    }

    /** A submitted task the creator reviews, seen by the creator. */
    private Task submitted(User creator, User assignee) {
        Task task = taskOf(creator, creator, assignee, TaskAction.ASSIGN, TaskAction.START, TaskAction.SUBMIT);
        visibleTo(creator, task);
        return task;
    }

    private Task taskOf(User creator, User reviewer, User assignee, TaskAction... actions) {
        Task task = new Task(creator, "Kitchen", null, TaskPriority.HIGH, Instant.now(), reviewer);
        TaskFixtures.assign(task, assignee);
        for (TaskAction action : actions) {
            stateMachine.apply(task, action);
        }
        when(taskRepository.saveAndFlush(task)).thenReturn(task);
        return task;
    }

    /** The user can open the task and calls the service. */
    private void visibleTo(User user, Task task) {
        when(taskService.get(caller(user), task.getId())).thenReturn(task);
        when(userService.requireCaller(caller(user))).thenReturn(user);
    }

    private Review savedReview() {
        ArgumentCaptor<Review> review = ArgumentCaptor.forClass(Review.class);
        verify(reviewRepository).save(review.capture());
        return review.getValue();
    }

    private static CorrectionRequest correction(String reason, UUID... requirements) {
        return new CorrectionRequest(reason, Arrays.stream(requirements)
                .map(id -> new CorrectionRequest.Item(id, " Fix this ")).toList());
    }

    private void assertRefused(Runnable action, HttpStatus status, String code) {
        assertThatThrownBy(action::run)
                .isInstanceOf(ApiException.class)
                .extracting("status", "code")
                .containsExactly(status, code);
        verify(transitions, never()).apply(any(), any(), any(), any());
        verify(reviewRepository, never()).save(any());
    }

    private static User user() {
        User user = mock(User.class);
        when(user.getId()).thenReturn(UUID.randomUUID());
        return user;
    }

    private static CurrentUser caller(User user) {
        return new CurrentUser(user.getId(), "user@example.com", List.of("MANAGER"));
    }

}
