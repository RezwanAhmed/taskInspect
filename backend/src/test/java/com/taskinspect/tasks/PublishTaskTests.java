package com.taskinspect.tasks;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.taskinspect.TestcontainersConfiguration;
import com.taskinspect.auth.JwtService;
import com.taskinspect.requirements.Requirement;
import com.taskinspect.requirements.RequirementRepository;
import com.taskinspect.requirements.RequirementType;
import com.taskinspect.users.OrganizationRepository;
import com.taskinspect.users.RoleName;
import com.taskinspect.users.RoleRepository;
import com.taskinspect.users.User;
import com.taskinspect.users.UserRepository;
import java.time.Instant;
import java.util.Arrays;
import java.util.stream.Collectors;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.context.annotation.Import;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.ResultActions;
import org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder;

/** Publishing a task as an open task (DRAFT → OPEN). Runs without a test transaction, like real requests. */
@Import(TestcontainersConfiguration.class)
@SpringBootTest
@AutoConfigureMockMvc
class PublishTaskTests {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private JwtService jwtService;

    @Autowired
    private TaskRepository taskRepository;

    @Autowired
    private TaskStatusChangeRepository historyRepository;

    @Autowired
    private RequirementRepository requirementRepository;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private RoleRepository roleRepository;

    @Autowired
    private OrganizationRepository organizationRepository;

    private User manager;
    private User otherManager;
    private User worker;
    private Task task;

    @BeforeEach
    void setUp() {
        manager = save("manager@example.com", "Mia Manager", RoleName.MANAGER);
        otherManager = save("manager2@example.com", "Max Manager", RoleName.MANAGER);
        worker = save("worker@example.com", "Wendy Worker", RoleName.WORKER);
        worker.joinTeamOf(manager);
        worker = userRepository.save(worker);
        task = taskWithRequirement(manager);
    }

    @AfterEach
    void tearDown() {
        taskRepository.deleteAll();
        userRepository.deleteAll();
    }

    @Test
    void managerPublishesToTheTeam() throws Exception {
        publish(manager, task, "TEAM")
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("OPEN"))
                .andExpect(jsonPath("$.openScope").value("TEAM"))
                .andExpect(jsonPath("$.assignee").doesNotExist());

        Task stored = taskRepository.findById(task.getId()).orElseThrow();
        assertThat(stored.getStatus()).isEqualTo(TaskStatus.OPEN);
        assertThat(stored.getOpenScope()).isEqualTo(OpenScope.TEAM);
        assertThat(stored.getAssignee()).isNull();
        var history = historyRepository.findAllByTaskIdOrderByChangedAtAscIdAsc(task.getId());
        assertThat(history).last().satisfies(change -> {
            assertThat(change.getFromStatus()).isEqualTo(TaskStatus.DRAFT);
            assertThat(change.getToStatus()).isEqualTo(TaskStatus.OPEN);
        });
        mockMvc.perform(as(manager, get("/api/tasks/{id}/history", task.getId())))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[-1:].event").value("PUBLISHED"));
    }

    @Test
    void managerWithoutTeamPublishesToEveryoneOnly() throws Exception {
        Task otherTask = taskWithRequirement(otherManager);

        publish(otherManager, otherTask, "TEAM")
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.code").value("TEAM_HAS_NO_MEMBERS"));
        publish(otherManager, otherTask, "EVERYONE")
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.openScope").value("EVERYONE"));
    }

    @Test
    void deactivatedMembersDoNotCountAsATeam() throws Exception {
        worker.deactivate();
        userRepository.save(worker);

        publish(manager, task, "TEAM")
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.code").value("TEAM_HAS_NO_MEMBERS"));
    }

    @Test
    void taskNeedsARequirementAndAScope() throws Exception {
        Task empty = taskRepository.save(new Task(manager, "Empty", null, TaskPriority.LOW, Instant.now(), null));

        publish(manager, empty, "EVERYONE")
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.code").value("TASK_HAS_NO_REQUIREMENTS"));
        mockMvc.perform(as(manager, post("/api/tasks/{id}/publish", task.getId()))
                        .contentType(MediaType.APPLICATION_JSON).content("{}"))
                .andExpect(status().isBadRequest());
        publish(manager, task, "NOBODY").andExpect(status().isBadRequest());
    }

    @Test
    void onlyTheCreatorPublishesAndOnlyFromDraft() throws Exception {
        publish(otherManager, task, "EVERYONE").andExpect(status().isForbidden());
        publish(worker, task, "EVERYONE").andExpect(status().isForbidden());

        publish(manager, task, "EVERYONE").andExpect(status().isOk());
        publish(manager, task, "TEAM")
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.code").value("TASK_INVALID_TRANSITION"));
        mockMvc.perform(as(manager, post("/api/tasks/{id}/assign", task.getId()))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"assigneeId\": \"" + worker.getId() + "\"}"))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.code").value("TASK_INVALID_TRANSITION"));
    }

    @Test
    void openTaskCanStillBeEditedButNotByWorkers() throws Exception {
        publish(manager, task, "TEAM").andExpect(status().isOk());
        long version = taskRepository.findById(task.getId()).orElseThrow().getVersion();

        mockMvc.perform(as(manager, put("/api/tasks/{id}", task.getId()))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"title\": \"Kitchen and hall\", \"priority\": \"HIGH\", "
                                + "\"dueDate\": \"2026-10-03T09:00:00Z\", \"version\": " + version + "}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("OPEN"))
                .andExpect(jsonPath("$.openScope").value("TEAM"));
        mockMvc.perform(as(worker, put("/api/tasks/{id}", task.getId()))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"title\": \"Mine now\", \"priority\": \"LOW\", "
                                + "\"dueDate\": \"2026-10-03T09:00:00Z\", \"version\": " + version + "}"))
                .andExpect(status().isForbidden());
    }

    @Test
    void cancellingAnOpenTaskClearsTheScope() {
        publishDirectly(task, OpenScope.EVERYONE);

        Task stored = taskRepository.findById(task.getId()).orElseThrow();
        new TaskStateMachine().apply(stored, TaskAction.CANCEL);
        Task cancelled = taskRepository.saveAndFlush(stored);

        assertThat(cancelled.getStatus()).isEqualTo(TaskStatus.CANCELLED);
        assertThat(cancelled.getOpenScope()).isNull();
    }

    private void publishDirectly(Task target, OpenScope scope) {
        Task stored = taskRepository.findById(target.getId()).orElseThrow();
        new TaskStateMachine().apply(stored, TaskAction.PUBLISH);
        stored.openTo(scope);
        taskRepository.saveAndFlush(stored);
    }

    private ResultActions publish(User user, Task target, String scope) throws Exception {
        return mockMvc.perform(as(user, post("/api/tasks/{id}/publish", target.getId()))
                .contentType(MediaType.APPLICATION_JSON)
                .content("{\"scope\": \"" + scope + "\"}"));
    }

    private Task taskWithRequirement(User creator) {
        Task created = taskRepository.save(new Task(creator, "Kitchen", null, TaskPriority.HIGH,
                Instant.parse("2026-10-02T09:00:00Z"), null));
        requirementRepository.save(new Requirement(created, "Is the fire extinguisher available?", null,
                RequirementType.YES_NO, true, 0, null, null));
        return created;
    }

    private MockHttpServletRequestBuilder as(User user, MockHttpServletRequestBuilder request) {
        return request.header("Authorization", "Bearer " + jwtService.issueAccessToken(user).value());
    }

    private User save(String email, String name, RoleName... roles) {
        return userRepository.save(new User(organizationRepository.getDefault(), email, "hash", name,
                Arrays.stream(roles).map(r -> roleRepository.findByName(r).orElseThrow()).collect(Collectors.toSet())));
    }

}
