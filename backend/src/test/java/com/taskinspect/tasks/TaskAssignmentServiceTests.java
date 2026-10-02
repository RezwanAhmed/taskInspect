package com.taskinspect.tasks;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.taskinspect.common.error.ApiException;
import com.taskinspect.common.error.ErrorCode;
import com.taskinspect.common.security.CurrentUser;
import com.taskinspect.requirements.RequirementService;
import com.taskinspect.users.Organization;
import com.taskinspect.users.RoleName;
import com.taskinspect.users.User;
import com.taskinspect.users.UserRepository;
import com.taskinspect.users.UserService;
import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpStatus;

/** Unit tests of the assign, publish, take and register-again rules (task 9.1d). */
class TaskAssignmentServiceTests {

    private final TaskService taskService = mock(TaskService.class);
    private final TaskRepository taskRepository = mock(TaskRepository.class);
    private final TaskAssignmentRepository assignmentRepository = mock(TaskAssignmentRepository.class);
    private final TaskStateMachine stateMachine = new TaskStateMachine();
    private final TaskTransitionService transitions = mock(TaskTransitionService.class);
    private final RequirementService requirementService = mock(RequirementService.class);
    private final UserService userService = mock(UserService.class);
    private final UserRepository userRepository = mock(UserRepository.class);
    private final TaskStatusChangeRepository historyRepository = mock(TaskStatusChangeRepository.class);
    private final TaskAssignmentService service = new TaskAssignmentService(taskService, taskRepository,
            assignmentRepository, stateMachine, transitions, requirementService, userService, userRepository,
            historyRepository);

    private final Organization organization = organization();
    private final User manager = user(RoleName.MANAGER);
    private final User worker = user(RoleName.WORKER);

    @Test
    void theCreatorAssignsADraftToAnActiveWorker() {
        Task task = editableDraft(manager, null, 1);
        activeWorker(worker);

        service.assign(caller(manager), task.getId(), worker.getId());

        assertThat(task.getAssignee()).isSameAs(worker);
        verify(transitions).apply(task, TaskAction.ASSIGN, manager, null);
        verify(assignmentRepository).save(any(TaskAssignment.class));
        verify(taskRepository).saveAndFlush(task);
    }

    @Test
    void aTaskNeedsARequirementBeforeItIsAssigned() {
        Task task = editableDraft(manager, null, 0);
        activeWorker(worker);

        assertRefused(() -> service.assign(caller(manager), task.getId(), worker.getId()), HttpStatus.CONFLICT,
                TaskAssignmentService.TASK_HAS_NO_REQUIREMENTS);
    }

    @Test
    void theReviewerCannotBeTheWorker() {
        Task task = editableDraft(manager, worker, 1);
        activeWorker(worker);

        assertRefused(() -> service.assign(caller(manager), task.getId(), worker.getId()), HttpStatus.BAD_REQUEST,
                TaskAssignmentService.REVIEWER_IS_ASSIGNEE);
    }

    @Test
    void aManagerAssignsAPersonalTaskToThemself() {
        User soloManager = user(RoleName.MANAGER, RoleName.WORKER);
        Task task = editableDraft(soloManager, null, 1);
        activeWorker(soloManager);

        service.assign(caller(soloManager), task.getId(), soloManager.getId());

        verify(transitions).apply(task, TaskAction.ASSIGN, soloManager, null);
    }

    @Test
    void aMainTaskGoesToAManagerAndNeedsNoRequirement() {
        User admin = user(RoleName.ADMINISTRATOR);
        Task mainTask = editableDraft(admin, null, 0);
        activeWithRole(manager, RoleName.MANAGER);

        service.assign(caller(admin), mainTask.getId(), manager.getId());

        assertThat(mainTask.getAssignee()).isSameAs(manager);
        verify(requirementService, never()).count(any());
    }

    @Test
    void theStatusIsCheckedFirst() {
        Task task = editableDraft(manager, null, 1);
        stateMachine.apply(task, TaskAction.ASSIGN);

        assertRefused(() -> service.assign(caller(manager), task.getId(), worker.getId()), HttpStatus.CONFLICT,
                TaskStateMachine.TASK_INVALID_TRANSITION);
        verify(userService, never()).requireActiveWithRole(any(), any(), any(), any(), any());
    }

    @Test
    void publishingOpensTheTaskWithItsScopeInTheHistory() {
        Task task = editableDraft(manager, null, 1);
        when(userRepository.countByTeamManagerIdAndActiveTrue(manager.getId())).thenReturn(2L);

        service.publish(caller(manager), task.getId(), OpenScope.TEAM);

        assertThat(task.getOpenScope()).isEqualTo(OpenScope.TEAM);
        verify(transitions).apply(task, TaskAction.PUBLISH, manager, "open to: TEAM");
    }

    @Test
    void aTeamWithoutActiveWorkersCannotGetTheTask() {
        Task task = editableDraft(manager, null, 1);

        assertRefused(() -> service.publish(caller(manager), task.getId(), OpenScope.TEAM), HttpStatus.CONFLICT,
                TaskAssignmentService.TEAM_HAS_NO_MEMBERS);
    }

    @Test
    void mainTasksAndTasksWithoutRequirementsAreNotPublished() {
        Task mainTask = editableDraft(user(RoleName.ADMINISTRATOR), null, 1);
        Task empty = editableDraft(manager, null, 0);

        assertRefused(() -> service.publish(caller(mainTask.getCreatedBy()), mainTask.getId(), OpenScope.EVERYONE),
                HttpStatus.CONFLICT, TaskAssignmentService.MAIN_TASK_NOT_PUBLISHABLE);
        assertRefused(() -> service.publish(caller(manager), empty.getId(), OpenScope.EVERYONE),
                HttpStatus.CONFLICT, TaskAssignmentService.TASK_HAS_NO_REQUIREMENTS);
    }

    @Test
    void aWorkerTakesAnOpenTask() {
        Task task = open(OpenScope.EVERYONE);

        service.take(caller(worker), task.getId());

        assertThat(task.getAssignee()).isSameAs(worker);
        verify(taskService).lockForUpdate(task.getId());
        verify(transitions).apply(task, TaskAction.TAKE, worker, null);
        verify(assignmentRepository).save(any(TaskAssignment.class));
    }

    @Test
    void aTeamTaskIsHiddenFromWorkersOfOtherTeams() {
        Task task = open(OpenScope.TEAM);
        User otherManager = user(RoleName.MANAGER);
        when(worker.getTeamManager()).thenReturn(otherManager);

        assertRefused(() -> service.take(caller(worker), task.getId()), HttpStatus.NOT_FOUND,
                TaskService.TASK_NOT_FOUND);
    }

    @Test
    void aTeamTaskIsTakenByAWorkerOfThePublishersTeam() {
        Task task = open(OpenScope.TEAM);
        when(worker.getTeamManager()).thenReturn(manager);

        service.take(caller(worker), task.getId());

        assertThat(task.getAssignee()).isSameAs(worker);
    }

    @Test
    void theReviewerCannotTakeTheTask() {
        Task task = open(OpenScope.EVERYONE, worker);

        assertRefused(() -> service.take(caller(worker), task.getId()), HttpStatus.BAD_REQUEST,
                TaskAssignmentService.REVIEWER_IS_ASSIGNEE);
    }

    @Test
    void aTaskTakenByAnotherWorkerAnswersAlreadyTaken() {
        Task task = takenFromOpen(user(RoleName.WORKER));

        assertRefused(() -> service.take(caller(worker), task.getId()), HttpStatus.CONFLICT,
                TaskAssignmentService.TASK_ALREADY_TAKEN);
    }

    @Test
    void takingAgainAfterALostAnswerChangesNothing() {
        Task task = takenFromOpen(worker);

        assertThat(service.take(caller(worker), task.getId())).isSameAs(task);
        verify(transitions, never()).apply(any(), any(), any(), any());
    }

    @Test
    void aTaskThatWasNeverOpenIsNotFound() {
        Task task = assignedTo(user(RoleName.WORKER));
        when(taskRepository.findByIdAndOrganizationId(task.getId(), organization.getId())).thenReturn(Optional.of(task));
        when(userService.requireCaller(caller(worker))).thenReturn(worker);

        assertRefused(() -> service.take(caller(worker), task.getId()), HttpStatus.NOT_FOUND,
                TaskService.TASK_NOT_FOUND);
    }

    @Test
    void onlyTheCreatorRegistersATaskAgainOnceWorkHasStarted() {
        Task started = assignedTo(worker);
        stateMachine.apply(started, TaskAction.START);
        Task assigned = assignedTo(worker);
        User otherManager = user(RoleName.MANAGER);
        when(taskService.get(caller(otherManager), started.getId())).thenReturn(started);
        when(taskService.get(caller(manager), assigned.getId())).thenReturn(assigned);

        assertRefused(() -> service.reissue(caller(otherManager), started.getId()), HttpStatus.FORBIDDEN,
                ErrorCode.FORBIDDEN);
        assertRefused(() -> service.reissue(caller(manager), assigned.getId()), HttpStatus.CONFLICT,
                TaskAssignmentService.TASK_NOT_REISSUABLE);
    }

    @Test
    void registeringAgainCopiesTheTaskForTheSameWorker() {
        User formerReviewer = user(RoleName.MANAGER);
        when(formerReviewer.isActive()).thenReturn(false);
        Task original = draft(manager, formerReviewer);
        TaskFixtures.assign(original, worker);
        stateMachine.apply(original, TaskAction.ASSIGN);
        stateMachine.apply(original, TaskAction.START);
        when(taskService.get(caller(manager), original.getId())).thenReturn(original);
        when(userService.requireCaller(caller(manager))).thenReturn(manager);
        activeWorker(worker);
        when(taskRepository.saveAndFlush(any())).thenAnswer(invocation -> invocation.getArgument(0));

        Task copy = service.reissue(caller(manager), original.getId());

        assertThat(copy.getId()).isNotEqualTo(original.getId());
        assertThat(copy.getReissuedFromId()).isEqualTo(original.getId());
        assertThat(copy.getAssignee()).isSameAs(worker);
        assertThat(copy.getReviewer()).as("an inactive reviewer is replaced by the caller").isSameAs(manager);
        verify(requirementService).copyAll(original, copy);
        verify(transitions).recordCreated(copy, manager);
        verify(transitions).apply(copy, TaskAction.ASSIGN, manager, "registered again from " + original.getId());
    }

    private Task draft(User creator, User reviewer) {
        return new Task(creator, "Kitchen", null, TaskPriority.HIGH, Instant.now(), reviewer);
    }

    /** A task of the manager assigned to the worker, without the API. */
    private Task assignedTo(User assignee) {
        Task task = draft(manager, null);
        TaskFixtures.assign(task, assignee);
        stateMachine.apply(task, TaskAction.ASSIGN);
        return task;
    }

    /** A draft the creator may edit, with the given number of requirements. */
    private Task editableDraft(User creator, User reviewer, long requirements) {
        Task task = draft(creator, reviewer);
        when(taskService.requireEditable(caller(creator), task.getId())).thenReturn(task);
        when(userService.requireCaller(caller(creator))).thenReturn(creator);
        when(requirementService.count(task.getId())).thenReturn(requirements);
        return task;
    }

    private Task open(OpenScope scope) {
        return open(scope, null);
    }

    /** A task the manager published to the scope, found by the worker. */
    private Task open(OpenScope scope, User reviewer) {
        Task task = draft(manager, reviewer);
        stateMachine.apply(task, TaskAction.PUBLISH);
        task.openTo(scope);
        when(taskRepository.findByIdAndOrganizationId(task.getId(), organization.getId())).thenReturn(Optional.of(task));
        when(userService.requireCaller(caller(worker))).thenReturn(worker);
        return task;
    }

    /** A task published to everyone and then taken by the given worker. */
    private Task takenFromOpen(User takenBy) {
        Task task = open(OpenScope.EVERYONE);
        TaskFixtures.assign(task, takenBy);
        stateMachine.apply(task, TaskAction.TAKE);
        when(historyRepository.findFirstByTaskIdAndToStatusOrderByChangedAtDescIdDesc(task.getId(), TaskStatus.OPEN))
                .thenReturn(Optional.of(new TaskStatusChange(task, TaskStatus.DRAFT, TaskStatus.OPEN, manager,
                        "open to: EVERYONE")));
        return task;
    }

    private void activeWorker(User user) {
        activeWithRole(user, RoleName.WORKER);
    }

    private void activeWithRole(User user, RoleName role) {
        // IDs read first: calling a mock inside the matchers below confuses Mockito.
        UUID userId = user.getId();
        UUID organizationId = organization.getId();
        when(userService.requireActiveWithRole(eq(userId), eq(organizationId), eq(role), anyString(), anyString()))
                .thenReturn(user);
    }

    private void assertRefused(Runnable action, HttpStatus status, String code) {
        assertThatThrownBy(action::run)
                .isInstanceOf(ApiException.class)
                .extracting("status", "code")
                .containsExactly(status, code);
        verify(transitions, never()).apply(any(), any(), any(), any());
        verify(assignmentRepository, never()).save(any());
    }

    private static CurrentUser caller(User user) {
        return new CurrentUser(user.getId(), "user@example.com", List.of());
    }

    private static Organization organization() {
        Organization organization = mock(Organization.class);
        when(organization.getId()).thenReturn(UUID.randomUUID());
        return organization;
    }

    private User user(RoleName... roles) {
        User user = mock(User.class);
        when(user.getId()).thenReturn(UUID.randomUUID());
        when(user.getOrganization()).thenReturn(organization);
        when(user.isActive()).thenReturn(true);
        for (RoleName role : roles) {
            when(user.hasRole(role)).thenReturn(true);
        }
        return user;
    }

}
