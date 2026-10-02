package com.taskinspect.notifications;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.after;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.timeout;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.taskinspect.TestcontainersConfiguration;
import com.taskinspect.auth.JwtService;
import com.taskinspect.requirements.Requirement;
import com.taskinspect.requirements.RequirementRepository;
import com.taskinspect.requirements.RequirementType;
import com.taskinspect.tasks.Task;
import com.taskinspect.tasks.TaskAction;
import com.taskinspect.tasks.TaskFixtures;
import com.taskinspect.tasks.TaskPriority;
import com.taskinspect.tasks.TaskRepository;
import com.taskinspect.tasks.TaskStateMachine;
import com.taskinspect.users.OrganizationRepository;
import com.taskinspect.users.RoleName;
import com.taskinspect.users.RoleRepository;
import com.taskinspect.users.User;
import com.taskinspect.users.UserRepository;
import java.time.Instant;
import java.util.Arrays;
import java.util.Map;
import java.util.stream.Collectors;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.context.annotation.Import;
import org.springframework.http.MediaType;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.ResultActions;
import org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder;

/** Push notifications on assign / submit / approve / reject / correction request (task 8.6). */
@Import(TestcontainersConfiguration.class)
@SpringBootTest
@AutoConfigureMockMvc
class TaskNotificationTests {

    /** Notifications are sent on another thread after the commit. */
    private static final int WAIT_MS = 5000;
    private static final int QUIET_MS = 500;

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private JwtService jwtService;

    @Autowired
    private TaskRepository taskRepository;

    @Autowired
    private TaskStateMachine stateMachine;

    @Autowired
    private RequirementRepository requirementRepository;

    @Autowired
    private DeviceTokenRepository deviceTokenRepository;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private RoleRepository roleRepository;

    @Autowired
    private OrganizationRepository organizationRepository;

    @MockitoBean
    private PushSender pushSender;

    private User manager;
    private User worker;
    private Task lastTask;

    @BeforeEach
    void setUp() {
        manager = save("manager@example.com", "Mia Manager", RoleName.MANAGER);
        worker = save("worker@example.com", "Wendy Worker", RoleName.WORKER, RoleName.MANAGER);
        deviceTokenRepository.register(manager.getId(), "manager-phone", "ANDROID");
        deviceTokenRepository.register(worker.getId(), "worker-phone", "IOS");
        when(pushSender.send(any(), any())).thenReturn(PushResult.SENT);
    }

    @AfterEach
    void tearDown() {
        deviceTokenRepository.deleteAll();
        taskRepository.deleteAll();
        userRepository.deleteAll();
    }

    @Test
    void assigningNotifiesTheWorkerWithTheTaskToOpen() throws Exception {
        Task task = draftWithRequirement(manager);

        perform(manager, "assign", "{\"assigneeId\": \"" + worker.getId() + "\"}").andExpect(status().isOk());

        PushMessage message = sentTo("worker-phone");
        assertThat(message.title()).isEqualTo("New task assigned");
        assertThat(message.body()).isEqualTo("Kitchen");
        assertThat(message.data()).isEqualTo(Map.of("taskId", task.getId().toString(), "action", "ASSIGN"));
        verify(pushSender, never()).send(eq("manager-phone"), any());
    }

    @Test
    void submittingNotifiesTheReviewer() throws Exception {
        Task task = inStatus(manager, worker, TaskAction.START);

        perform(worker, task, "submit", null).andExpect(status().isOk());

        assertThat(sentTo("manager-phone").title()).isEqualTo("Task submitted for review");
        verify(pushSender, never()).send(eq("worker-phone"), any());
    }

    @Test
    void approvingNotifiesTheWorker() throws Exception {
        Task task = inStatus(manager, worker, TaskAction.SUBMIT);

        perform(manager, task, "approve", null).andExpect(status().isOk());

        assertThat(sentTo("worker-phone").title()).isEqualTo("Task approved");
    }

    @Test
    void rejectingNotifiesTheWorker() throws Exception {
        Task task = inStatus(manager, worker, TaskAction.SUBMIT);

        perform(manager, task, "reject", "{\"reason\": \"Wrong kitchen\"}").andExpect(status().isOk());

        assertThat(sentTo("worker-phone").title()).isEqualTo("Task rejected");
    }

    @Test
    void requestingACorrectionNotifiesTheWorker() throws Exception {
        Task task = inStatus(manager, worker, TaskAction.SUBMIT);
        Requirement photo = requirementRepository.save(new Requirement(task, "Photo of the fridge", null,
                RequirementType.PHOTO, true, 0, null, null));

        perform(manager, task, "request-correction", "{\"requirements\": [{\"requirementId\": \""
                + photo.getId() + "\", \"comment\": \"Too dark\"}]}").andExpect(status().isOk());

        PushMessage message = sentTo("worker-phone");
        assertThat(message.title()).isEqualTo("Correction requested");
        assertThat(message.data()).containsEntry("action", "REQUEST_CORRECTION");
    }

    @Test
    void nobodyIsNotifiedOfTheirOwnActionOnAPersonalTask() throws Exception {
        draftWithRequirement(worker);

        perform(worker, "assign", "{\"assigneeId\": \"" + worker.getId() + "\"}").andExpect(status().isOk());
        perform(worker, inStatus(worker, worker, TaskAction.START), "submit", null).andExpect(status().isOk());
        perform(worker, inStatus(worker, worker, TaskAction.SUBMIT), "approve", null).andExpect(status().isOk());

        verify(pushSender, after(QUIET_MS).never()).send(any(), any());
    }

    @Test
    void aRefusedActionSendsNothing() throws Exception {
        Task task = inStatus(manager, worker, TaskAction.SUBMIT);

        perform(manager, task, "reject", "{\"reason\": \" \"}").andExpect(status().isBadRequest());
        perform(worker, task, "submit", null).andExpect(status().isConflict());

        verify(pushSender, after(QUIET_MS).never()).send(any(), any());
    }

    @Test
    void aFailingPushServiceDoesNotFailTheAction() throws Exception {
        Task task = inStatus(manager, worker, TaskAction.SUBMIT);
        when(pushSender.send(any(), any())).thenThrow(new IllegalStateException("push service down"));

        perform(manager, task, "approve", null).andExpect(status().isOk());

        verify(pushSender, timeout(WAIT_MS)).send(eq("worker-phone"), any());
        assertThat(deviceTokenRepository.findByToken("worker-phone")).isPresent();
    }

    private PushMessage sentTo(String token) {
        ArgumentCaptor<PushMessage> captor = ArgumentCaptor.forClass(PushMessage.class);
        verify(pushSender, timeout(WAIT_MS)).send(eq(token), captor.capture());
        return captor.getValue();
    }

    private Task draftWithRequirement(User creator) {
        lastTask = taskRepository.save(new Task(creator, "Kitchen", null, TaskPriority.HIGH,
                Instant.parse("2026-12-01T09:00:00Z"), null));
        requirementRepository.save(new Requirement(lastTask, "Clean?", null, RequirementType.YES_NO, false, 0,
                null, null));
        return lastTask;
    }

    /** A task of the creator, assigned to the worker and moved on up to {@code last}, without the API. */
    private Task inStatus(User creator, User assignee, TaskAction last) {
        Task created = taskRepository.save(new Task(creator, "Kitchen", null, TaskPriority.HIGH,
                Instant.parse("2026-12-01T09:00:00Z"), null));
        TaskFixtures.assign(created, assignee);
        for (TaskAction action : new TaskAction[] {TaskAction.ASSIGN, TaskAction.START, TaskAction.SUBMIT}) {
            stateMachine.apply(created, action);
            if (action == last) {
                break;
            }
        }
        return taskRepository.save(created);
    }

    private ResultActions perform(User user, String action, String body) throws Exception {
        return perform(user, lastTask, action, body);
    }

    private ResultActions perform(User user, Task task, String action, String body) throws Exception {
        MockHttpServletRequestBuilder request = as(user, post("/api/tasks/{id}/" + action, task.getId()));
        if (body != null) {
            request.contentType(MediaType.APPLICATION_JSON).content(body);
        }
        return mockMvc.perform(request);
    }

    private MockHttpServletRequestBuilder as(User user, MockHttpServletRequestBuilder request) {
        return request.header("Authorization", "Bearer " + jwtService.issueAccessToken(user).value());
    }

    private User save(String email, String name, RoleName... roles) {
        return userRepository.save(new User(organizationRepository.getDefault(), email, "hash", name,
                Arrays.stream(roles).map(r -> roleRepository.findByName(r).orElseThrow()).collect(Collectors.toSet())));
    }

}
