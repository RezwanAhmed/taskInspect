package com.taskinspect.tasks;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.jayway.jsonpath.JsonPath;
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

/** The manager of a main task passes it on in sub-tasks (task 7A.6b). Runs without a test transaction. */
@Import(TestcontainersConfiguration.class)
@SpringBootTest
@AutoConfigureMockMvc
class SubTaskTests {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private JwtService jwtService;

    @Autowired
    private TaskRepository taskRepository;

    @Autowired
    private RequirementRepository requirementRepository;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private RoleRepository roleRepository;

    @Autowired
    private OrganizationRepository organizationRepository;

    private User admin;
    private User manager;
    private User otherManager;
    private User worker;
    private Task mainTask;

    @BeforeEach
    void setUp() {
        admin = save("admin@example.com", "Ada Admin", RoleName.ADMINISTRATOR);
        manager = save("manager@example.com", "Mia Manager", RoleName.MANAGER);
        otherManager = save("manager2@example.com", "Max Manager", RoleName.MANAGER);
        worker = save("worker@example.com", "Wendy Worker", RoleName.WORKER);
        worker.joinTeamOf(manager);
        worker = userRepository.save(worker);
        mainTask = assigned(new Task(admin, "Inspect building B", null, TaskPriority.HIGH, due(), null), manager);
    }

    @AfterEach
    void tearDown() {
        taskRepository.deleteAll();
        userRepository.deleteAll();
    }

    @Test
    void managerAddsASubTaskAndPassesItToAWorker() throws Exception {
        String body = addSubTask(manager, mainTask.getId())
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.status").value("DRAFT"))
                .andExpect(jsonPath("$.parentTaskId").value(mainTask.getId().toString()))
                .andExpect(jsonPath("$.createdBy.id").value(manager.getId().toString()))
                .andExpect(jsonPath("$.reviewer.id").value(manager.getId().toString()))
                .andReturn().getResponse().getContentAsString();
        UUID subTaskId = UUID.fromString(JsonPath.read(body, "$.id"));
        Task subTask = taskRepository.findById(subTaskId).orElseThrow();
        assertThat(subTask.getParentTaskId()).isEqualTo(mainTask.getId());
        requirementRepository.save(new Requirement(subTask, "Is the fire extinguisher available?", null,
                RequirementType.YES_NO, true, 0, null, null));

        mockMvc.perform(as(manager, post("/api/tasks/{id}/assign", subTaskId))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"assigneeId\": \"" + worker.getId() + "\"}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("ASSIGNED"));
        mockMvc.perform(as(worker, get("/api/tasks/{id}", subTaskId)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.parentTaskId").value(mainTask.getId().toString()));
        // The main task itself stays hidden from the worker.
        mockMvc.perform(as(worker, get("/api/tasks/{id}", mainTask.getId()))).andExpect(status().isNotFound());
    }

    @Test
    void subTasksAreListedOldestFirst() throws Exception {
        addSubTask(manager, mainTask.getId()).andExpect(status().isCreated());
        addSubTask(manager, mainTask.getId()).andExpect(status().isCreated());
        Task otherMainTask = assigned(new Task(admin, "Inspect building C", null, TaskPriority.LOW, due(), null), manager);
        addSubTask(manager, otherMainTask.getId()).andExpect(status().isCreated());

        mockMvc.perform(as(admin, get("/api/tasks/{id}/sub-tasks", mainTask.getId())))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.length()").value(2))
                .andExpect(jsonPath("$[0].parentTaskId").value(mainTask.getId().toString()));
        mockMvc.perform(as(worker, get("/api/tasks/{id}/sub-tasks", mainTask.getId()))).andExpect(status().isForbidden());
    }

    @Test
    void onlyTheAssignedManagerAddsSubTasks() throws Exception {
        addSubTask(otherManager, mainTask.getId()).andExpect(status().isForbidden());
        addSubTask(admin, mainTask.getId()).andExpect(status().isForbidden());
        addSubTask(worker, mainTask.getId()).andExpect(status().isForbidden());

        Task draftMainTask = taskRepository.save(new Task(admin, "Not assigned yet", null, TaskPriority.LOW, due(), null));
        addSubTask(manager, draftMainTask.getId()).andExpect(status().isForbidden());
    }

    @Test
    void onlyMainTasksGetSubTasksAndOnlyWhileOpen() throws Exception {
        Task managersOwn = assigned(new Task(manager, "Kitchen", null, TaskPriority.LOW, due(), null), worker);
        addSubTask(manager, managersOwn.getId())
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.code").value("NOT_A_MAIN_TASK"));

        Task cancelled = taskRepository.findById(mainTask.getId()).orElseThrow();
        new TaskStateMachine().apply(cancelled, TaskAction.CANCEL);
        taskRepository.saveAndFlush(cancelled);
        addSubTask(manager, mainTask.getId())
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.code").value("MAIN_TASK_CLOSED"));

        Task submitted = assigned(new Task(admin, "Inspect building C", null, TaskPriority.LOW, due(), null), manager);
        new TaskStateMachine().apply(submitted, TaskAction.START);
        new TaskStateMachine().apply(submitted, TaskAction.SUBMIT);
        taskRepository.saveAndFlush(submitted);
        addSubTask(manager, submitted.getId())
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.code").value("MAIN_TASK_CLOSED"));
    }

    private Task assigned(Task task, User assignee) {
        new TaskStateMachine().apply(task, TaskAction.ASSIGN);
        task.assignTo(assignee);
        return taskRepository.saveAndFlush(task);
    }

    private ResultActions addSubTask(User user, UUID mainTaskId) throws Exception {
        return mockMvc.perform(as(user, post("/api/tasks/{id}/sub-tasks", mainTaskId))
                .contentType(MediaType.APPLICATION_JSON)
                .content("{\"title\": \"Floor 1\", \"priority\": \"HIGH\", \"dueDate\": \"2026-12-01T09:00:00Z\"}"));
    }

    private static Instant due() {
        return Instant.parse("2026-12-01T09:00:00Z");
    }

    private MockHttpServletRequestBuilder as(User user, MockHttpServletRequestBuilder request) {
        return request.header("Authorization", "Bearer " + jwtService.issueAccessToken(user).value());
    }

    private User save(String email, String name, RoleName... roles) {
        return userRepository.save(new User(organizationRepository.getDefault(), email, "hash", name,
                Arrays.stream(roles).map(r -> roleRepository.findByName(r).orElseThrow()).collect(Collectors.toSet())));
    }

}
