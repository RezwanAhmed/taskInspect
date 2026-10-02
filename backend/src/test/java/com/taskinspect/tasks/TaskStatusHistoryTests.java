package com.taskinspect.tasks;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.tuple;
import static org.hamcrest.Matchers.contains;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.jayway.jsonpath.JsonPath;
import com.taskinspect.TestcontainersConfiguration;
import com.taskinspect.auth.JwtService;
import com.taskinspect.users.OrganizationRepository;
import com.taskinspect.users.RoleName;
import com.taskinspect.users.RoleRepository;
import com.taskinspect.users.User;
import com.taskinspect.users.UserRepository;
import java.util.Arrays;
import java.util.List;
import java.util.UUID;
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
import org.springframework.test.web.servlet.request.MockMvcRequestBuilders;

/** Drives a task through the API and checks that every status change is recorded. */
@Import(TestcontainersConfiguration.class)
@SpringBootTest
@AutoConfigureMockMvc
class TaskStatusHistoryTests {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private JwtService jwtService;

    @Autowired
    private TaskRepository taskRepository;

    @Autowired
    private TaskStatusChangeRepository historyRepository;

    @Autowired
    private TaskTransitionService transitions;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private RoleRepository roleRepository;

    @Autowired
    private OrganizationRepository organizationRepository;

    private User manager;
    private User worker;

    @BeforeEach
    void setUp() {
        manager = save("manager@example.com", "Mia Manager", RoleName.MANAGER);
        worker = save("worker@example.com", "Wendy Worker", RoleName.WORKER);
    }

    @AfterEach
    void tearDown() {
        taskRepository.deleteAll();
        userRepository.deleteAll();
    }

    @Test
    void createAssignAndStartAreRecordedInOrder() throws Exception {
        String taskId = JsonPath.read(post(manager, "/api/tasks", """
                {"title": "Kitchen", "priority": "HIGH", "dueDate": "2026-10-02T09:00:00Z"}""")
                .andExpect(status().isCreated()).andReturn().getResponse().getContentAsString(), "$.id");
        post(manager, "/api/tasks/" + taskId + "/requirements", "{\"title\": \"Ok?\", \"type\": \"YES_NO\"}")
                .andExpect(status().isCreated());
        post(manager, "/api/tasks/" + taskId + "/assign", "{\"assigneeId\": \"" + worker.getId() + "\"}")
                .andExpect(status().isOk());
        post(worker, "/api/tasks/" + taskId + "/start", "").andExpect(status().isOk());

        List<TaskStatusChange> history = historyRepository.findAllByTaskIdOrderByChangedAtAscIdAsc(UUID.fromString(taskId));

        assertThat(history)
                .extracting(TaskStatusChange::getFromStatus, TaskStatusChange::getToStatus,
                        change -> change.getChangedBy().getId())
                .containsExactly(
                        tuple(null, TaskStatus.DRAFT, manager.getId()),
                        tuple(TaskStatus.DRAFT, TaskStatus.ASSIGNED, manager.getId()),
                        tuple(TaskStatus.ASSIGNED, TaskStatus.IN_PROGRESS, worker.getId()));
        assertThat(history).allSatisfy(change -> assertThat(change.getChangedAt()).isNotNull());
    }

    @Test
    void theHistoryTimelineShowsEveryStepWithWhoAndWhy() throws Exception {
        String taskId = JsonPath.read(post(manager, "/api/tasks", """
                {"title": "Kitchen", "priority": "HIGH", "dueDate": "2026-10-02T09:00:00Z"}""")
                .andExpect(status().isCreated()).andReturn().getResponse().getContentAsString(), "$.id");
        String requirementId = JsonPath.read(post(manager, "/api/tasks/" + taskId + "/requirements",
                "{\"title\": \"Ok?\", \"type\": \"YES_NO\"}").andExpect(status().isCreated())
                .andReturn().getResponse().getContentAsString(), "$.id");
        post(manager, "/api/tasks/" + taskId + "/assign", "{\"assigneeId\": \"" + worker.getId() + "\"}")
                .andExpect(status().isOk());
        post(worker, "/api/tasks/" + taskId + "/start", "").andExpect(status().isOk());
        mockMvc.perform(MockMvcRequestBuilders.put("/api/tasks/" + taskId + "/requirements/" + requirementId
                        + "/response")
                        .header("Authorization", "Bearer " + jwtService.issueAccessToken(worker).value())
                        .contentType(MediaType.APPLICATION_JSON).content("{\"booleanValue\": true}"))
                .andExpect(status().isOk());
        post(worker, "/api/tasks/" + taskId + "/submit", "").andExpect(status().isOk());
        post(manager, "/api/tasks/" + taskId + "/reject", "{\"reason\": \"Wrong kitchen\"}")
                .andExpect(status().isOk());
        post(worker, "/api/tasks/" + taskId + "/start", "").andExpect(status().isOk());
        post(worker, "/api/tasks/" + taskId + "/submit", "").andExpect(status().isOk());
        post(manager, "/api/tasks/" + taskId + "/approve", "").andExpect(status().isOk());

        mockMvc.perform(MockMvcRequestBuilders.get("/api/tasks/" + taskId + "/history")
                        .header("Authorization", "Bearer " + jwtService.issueAccessToken(worker).value()))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[*].event").value(contains("CREATED", "ASSIGNED",
                        "STARTED", "SUBMITTED", "REJECTED", "RESTARTED", "RESUBMITTED", "APPROVED")))
                .andExpect(jsonPath("$[0].by.fullName").value("Mia Manager"))
                .andExpect(jsonPath("$[2].by.fullName").value("Wendy Worker"))
                .andExpect(jsonPath("$[4].reason").value("Wrong kitchen"))
                .andExpect(jsonPath("$[4].fromStatus").value("SUBMITTED"))
                .andExpect(jsonPath("$[4].toStatus").value("REJECTED"))
                .andExpect(jsonPath("$[7].at").isNotEmpty());
    }

    @Test
    void aCorrectionCycleAndACancellationAreNamedInTheTimeline() throws Exception {
        String taskId = JsonPath.read(post(manager, "/api/tasks", """
                {"title": "Kitchen", "priority": "HIGH", "dueDate": "2026-10-02T09:00:00Z"}""")
                .andReturn().getResponse().getContentAsString(), "$.id");
        String requirementId = JsonPath.read(post(manager, "/api/tasks/" + taskId + "/requirements",
                "{\"title\": \"Ok?\", \"type\": \"YES_NO\"}").andReturn().getResponse().getContentAsString(),
                "$.id");
        post(manager, "/api/tasks/" + taskId + "/assign", "{\"assigneeId\": \"" + worker.getId() + "\"}")
                .andExpect(status().isOk());
        post(worker, "/api/tasks/" + taskId + "/start", "").andExpect(status().isOk());
        mockMvc.perform(MockMvcRequestBuilders.put("/api/tasks/" + taskId + "/requirements/" + requirementId
                        + "/response")
                        .header("Authorization", "Bearer " + jwtService.issueAccessToken(worker).value())
                        .contentType(MediaType.APPLICATION_JSON).content("{\"booleanValue\": true}"))
                .andExpect(status().isOk());
        post(worker, "/api/tasks/" + taskId + "/submit", "").andExpect(status().isOk());
        post(manager, "/api/tasks/" + taskId + "/request-correction", "{\"requirements\": [{\"requirementId\": \""
                + requirementId + "\", \"comment\": \"Check again\"}]}").andExpect(status().isOk());
        post(worker, "/api/tasks/" + taskId + "/start", "").andExpect(status().isOk());
        Task task = taskRepository.findById(UUID.fromString(taskId)).orElseThrow();
        transitions.apply(task, TaskAction.CANCEL, manager, "No longer needed");
        taskRepository.save(task);

        mockMvc.perform(MockMvcRequestBuilders.get("/api/tasks/" + taskId + "/history")
                        .header("Authorization", "Bearer " + jwtService.issueAccessToken(manager).value()))
                .andExpect(jsonPath("$[*].event").value(contains("CREATED", "ASSIGNED", "STARTED", "SUBMITTED",
                        "CORRECTION_REQUESTED", "RESTARTED", "CANCELLED")))
                .andExpect(jsonPath("$[4].reason").value("1 requirement to correct"))
                .andExpect(jsonPath("$[6].reason").value("No longer needed"))
                .andExpect(jsonPath("$[6].by.fullName").value("Mia Manager"));
    }

    @Test
    void rejectedActionsAreNotRecorded() throws Exception {
        String taskId = JsonPath.read(post(manager, "/api/tasks", """
                {"title": "Kitchen", "priority": "HIGH", "dueDate": "2026-10-02T09:00:00Z"}""")
                .andReturn().getResponse().getContentAsString(), "$.id");

        post(manager, "/api/tasks/" + taskId + "/assign", "{\"assigneeId\": \"" + worker.getId() + "\"}")
                .andExpect(status().isConflict());

        assertThat(historyRepository.findAllByTaskIdOrderByChangedAtAscIdAsc(UUID.fromString(taskId))).hasSize(1);
    }

    private ResultActions post(User user, String url, String json) throws Exception {
        MockHttpServletRequestBuilder request = MockMvcRequestBuilders.post(url)
                .header("Authorization", "Bearer " + jwtService.issueAccessToken(user).value());
        if (!json.isEmpty()) {
            request = request.contentType(MediaType.APPLICATION_JSON).content(json);
        }
        return mockMvc.perform(request);
    }

    private User save(String email, String name, RoleName... roles) {
        return userRepository.save(new User(organizationRepository.getDefault(), email, "hash", name,
                Arrays.stream(roles).map(r -> roleRepository.findByName(r).orElseThrow()).collect(Collectors.toSet())));
    }

}
