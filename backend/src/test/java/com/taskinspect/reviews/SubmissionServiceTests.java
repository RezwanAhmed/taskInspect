package com.taskinspect.reviews;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.catchThrowableOfType;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.taskinspect.common.error.ApiException;
import com.taskinspect.common.error.ErrorResponse;
import com.taskinspect.common.security.CurrentUser;
import com.taskinspect.evidence.Evidence;
import com.taskinspect.evidence.EvidenceRepository;
import com.taskinspect.evidence.EvidenceStatus;
import com.taskinspect.requirements.Requirement;
import com.taskinspect.requirements.RequirementRepository;
import com.taskinspect.requirements.RequirementType;
import com.taskinspect.responses.Response;
import com.taskinspect.responses.ResponseRepository;
import com.taskinspect.tasks.Task;
import com.taskinspect.tasks.TaskAction;
import com.taskinspect.tasks.TaskFixtures;
import com.taskinspect.tasks.TaskPriority;
import com.taskinspect.tasks.TaskRepository;
import com.taskinspect.tasks.TaskService;
import com.taskinspect.tasks.TaskStateMachine;
import com.taskinspect.tasks.TaskStatus;
import com.taskinspect.tasks.TaskTransitionService;
import com.taskinspect.users.RoleName;
import com.taskinspect.users.User;
import com.taskinspect.users.UserService;
import java.time.Instant;
import java.util.List;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpStatus;

/** Unit tests of when a task can be submitted (task 9.1c). */
class SubmissionServiceTests {

    private final TaskService taskService = mock(TaskService.class);
    private final TaskStateMachine stateMachine = new TaskStateMachine();
    private final TaskTransitionService transitions = mock(TaskTransitionService.class);
    private final TaskRepository taskRepository = mock(TaskRepository.class);
    private final RequirementRepository requirementRepository = mock(RequirementRepository.class);
    private final ResponseRepository responseRepository = mock(ResponseRepository.class);
    private final EvidenceRepository evidenceRepository = mock(EvidenceRepository.class);
    private final UserService userService = mock(UserService.class);
    private final ReviewRepository reviewRepository = mock(ReviewRepository.class);
    private final SubmissionService service = new SubmissionService(taskService, stateMachine, transitions,
            taskRepository, requirementRepository, responseRepository, evidenceRepository, userService,
            reviewRepository);

    private final User manager = user(false);
    private final User worker = user(false);
    private final CurrentUser caller = new CurrentUser(worker.getId(), "worker@example.com", List.of("WORKER"));

    private final Requirement question = requirement("Clean?", RequirementType.YES_NO, true);
    private final Requirement photo = requirement("Photo of the fridge", RequirementType.PHOTO, true);
    private final Requirement report = requirement("Inspection report", RequirementType.DOCUMENT, true);
    private final Requirement note = requirement("Anything else?", RequirementType.TEXT, false);

    @Test
    void aCompleteTaskIsSubmitted() {
        Task task = inProgress(manager);
        has(task, List.of(question, photo, note), List.of(answer(question)),
                List.of(file(photo, EvidenceStatus.UPLOADED)));

        service.submit(caller, task.getId());

        verify(taskService).lockForUpdate(task.getId());
        verify(transitions).apply(task, TaskAction.SUBMIT, worker, null);
        verify(taskRepository).saveAndFlush(task);
    }

    @Test
    void afterAReviewTheHistoryShowsAResubmit() {
        Task task = inProgress(manager);
        has(task, List.of(question), List.of(answer(question)), List.of());
        when(reviewRepository.existsByTaskId(task.getId())).thenReturn(true);

        service.submit(caller, task.getId());

        verify(transitions).apply(task, TaskAction.SUBMIT, worker, "Resubmitted");
    }

    @Test
    void theStatusIsCheckedFirst() {
        Task task = inProgress(manager);
        stateMachine.apply(task, TaskAction.SUBMIT);

        assertRefused(() -> service.submit(caller, task.getId()), TaskStateMachine.TASK_INVALID_TRANSITION);
        verify(evidenceRepository, never()).findAllByTaskIdOrderByCreatedAtAsc(any());
    }

    @Test
    void filesStillUploadingBlockTheSubmit() {
        Task task = inProgress(manager);
        has(task, List.of(question, photo), List.of(answer(question)),
                List.of(file(photo, EvidenceStatus.UPLOADED), file(photo, EvidenceStatus.PENDING)));

        ApiException error = assertRefused(() -> service.submit(caller, task.getId()),
                SubmissionService.EVIDENCE_NOT_UPLOADED);
        assertThat(error).hasMessage("1 file is not uploaded yet");
    }

    @Test
    void everyMissingRequiredRequirementIsListed() {
        Task task = inProgress(manager);
        // An answer to a PHOTO or DOCUMENT requirement does not count: it needs a file.
        has(task, List.of(question, photo, report, note), List.of(answer(photo)), List.of());

        ApiException error = assertRefused(() -> service.submit(caller, task.getId()),
                SubmissionService.REQUIREMENTS_MISSING);
        assertThat(error.getErrors()).containsExactly(
                new ErrorResponse.FieldError(question.getId().toString(), "Clean?: an answer is required"),
                new ErrorResponse.FieldError(photo.getId().toString(), "Photo of the fridge: a photo is required"),
                new ErrorResponse.FieldError(report.getId().toString(), "Inspection report: a document is required"));
    }

    @Test
    void aMainTaskNeedsSubTasks() {
        Task mainTask = inProgress(user(true));
        subTasks(mainTask, subTask(TaskStatus.CANCELLED));

        assertRefused(() -> service.submit(caller, mainTask.getId()), SubmissionService.NO_SUB_TASKS);
    }

    @Test
    void aMainTaskNeedsEverySubTaskApprovedExceptCancelledOnes() {
        Task mainTask = inProgress(user(true));
        Task open = subTask(TaskStatus.SUBMITTED);
        subTasks(mainTask, subTask(TaskStatus.APPROVED), subTask(TaskStatus.CANCELLED), open);

        ApiException error = assertRefused(() -> service.submit(caller, mainTask.getId()),
                SubmissionService.SUB_TASKS_NOT_APPROVED);
        assertThat(error).hasMessage("1 of 2 sub-tasks are not approved yet");
        assertThat(error.getErrors()).containsExactly(
                new ErrorResponse.FieldError(open.getId().toString(), "Sub-task: SUBMITTED"));
    }

    @Test
    void aMainTaskWithAllSubTasksApprovedIsSubmitted() {
        Task mainTask = inProgress(user(true));
        subTasks(mainTask, subTask(TaskStatus.APPROVED), subTask(TaskStatus.CANCELLED));
        has(mainTask, List.of(), List.of(), List.of());

        service.submit(caller, mainTask.getId());

        verify(transitions).apply(mainTask, TaskAction.SUBMIT, worker, null);
    }

    private Task inProgress(User creator) {
        Task task = new Task(creator, "Kitchen", null, TaskPriority.HIGH, Instant.now(), null);
        TaskFixtures.assign(task, worker);
        stateMachine.apply(task, TaskAction.ASSIGN);
        stateMachine.apply(task, TaskAction.START);
        when(taskService.requireAssignee(caller, task.getId())).thenReturn(task);
        when(userService.requireCaller(caller)).thenReturn(worker);
        when(taskRepository.saveAndFlush(task)).thenReturn(task);
        return task;
    }

    private void has(Task task, List<Requirement> requirements, List<Response> responses, List<Evidence> files) {
        when(requirementRepository.findAllByTaskIdOrderByPosition(task.getId())).thenReturn(requirements);
        when(responseRepository.findAllByTaskId(task.getId())).thenReturn(responses);
        when(evidenceRepository.findAllByTaskIdOrderByCreatedAtAsc(task.getId())).thenReturn(files);
    }

    private void subTasks(Task mainTask, Task... subTasks) {
        when(taskRepository.findAllByParentTaskIdOrderByCreatedAtAscIdAsc(mainTask.getId()))
                .thenReturn(List.of(subTasks));
    }

    private ApiException assertRefused(Runnable action, String code) {
        ApiException error = catchThrowableOfType(ApiException.class, action::run);
        assertThat(error).isNotNull().extracting("status", "code").containsExactly(HttpStatus.CONFLICT, code);
        verify(transitions, never()).apply(any(), any(), any(), any());
        return error;
    }

    private static Requirement requirement(String title, RequirementType type, boolean required) {
        return new Requirement(null, title, null, type, required, 0, null, null);
    }

    private static Response answer(Requirement requirement) {
        Response response = mock(Response.class);
        when(response.getRequirement()).thenReturn(requirement);
        return response;
    }

    private static Evidence file(Requirement requirement, EvidenceStatus status) {
        Evidence evidence = mock(Evidence.class);
        when(evidence.getRequirement()).thenReturn(requirement);
        when(evidence.getStatus()).thenReturn(status);
        return evidence;
    }

    private static Task subTask(TaskStatus status) {
        Task task = mock(Task.class);
        when(task.getId()).thenReturn(UUID.randomUUID());
        when(task.getTitle()).thenReturn("Sub-task");
        when(task.getStatus()).thenReturn(status);
        return task;
    }

    private static User user(boolean administrator) {
        User user = mock(User.class);
        when(user.getId()).thenReturn(UUID.randomUUID());
        when(user.hasRole(RoleName.ADMINISTRATOR)).thenReturn(administrator);
        return user;
    }

}
