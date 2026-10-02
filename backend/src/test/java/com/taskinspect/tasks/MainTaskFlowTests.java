package com.taskinspect.tasks;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.taskinspect.TestcontainersConfiguration;
import com.taskinspect.auth.JwtService;
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

/**
 * The manager starts and submits a main task once its sub-tasks are
 * approved; the administrator reviews it (task 7A.6c). Runs without a test
 * transaction.
 */
@Import(TestcontainersConfiguration.class)
@SpringBootTest
@AutoConfigureMockMvc
class MainTaskFlowTests {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private JwtService jwtService;

    @Autowired
    private TaskRepository taskRepository;

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
        Task task = new Task(admin, "Inspect building B", null, TaskPriority.HIGH, due(), null);
        new TaskStateMachine().apply(task, TaskAction.ASSIGN);
        task.assignTo(manager);
        mainTask = taskRepository.saveAndFlush(task);
    }

    @AfterEach
    void tearDown() {
        taskRepository.deleteAll();
        userRepository.deleteAll();
    }

    @Test
    void managerSubmitsOnceEverySubTaskIsApprovedAndTheAdministratorReviews() throws Exception {
        action(otherManager, "start").andExpect(status().isForbidden());
        action(manager, "start").andExpect(status().isOk()).andExpect(jsonPath("$.status").value("IN_PROGRESS"));

        action(manager, "submit")
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.code").value("NO_SUB_TASKS"));

        Task floor1 = subTask("Floor 1", TaskStatus.SUBMITTED);
        subTask("Floor 2", TaskStatus.CANCELLED);
        action(manager, "submit")
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.code").value("SUB_TASKS_NOT_APPROVED"))
                .andExpect(jsonPath("$.errors.length()").value(1))
                .andExpect(jsonPath("$.errors[0].field").value(floor1.getId().toString()));

        approveDirectly(floor1);
        action(manager, "submit").andExpect(status().isOk()).andExpect(jsonPath("$.status").value("SUBMITTED"));

        action(manager, "approve").andExpect(status().isForbidden());
        action(otherManager, "approve").andExpect(status().isForbidden());
        mockMvc.perform(as(admin, post("/api/tasks/{id}/reject", mainTask.getId()))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"reason\": \"Floor 3 is missing\"}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("REJECTED"));

        action(manager, "start").andExpect(status().isOk());
        action(manager, "submit").andExpect(status().isOk());
        action(admin, "approve").andExpect(status().isOk()).andExpect(jsonPath("$.status").value("APPROVED"));
    }

    @Test
    void managersStillCannotStartOrSubmitOtherTasks() throws Exception {
        Task workersTask = new Task(manager, "Kitchen", null, TaskPriority.LOW, due(), null);
        new TaskStateMachine().apply(workersTask, TaskAction.ASSIGN);
        workersTask.assignTo(worker);
        workersTask = taskRepository.saveAndFlush(workersTask);

        mockMvc.perform(as(manager, post("/api/tasks/{id}/start", workersTask.getId()))).andExpect(status().isForbidden());
        mockMvc.perform(as(manager, post("/api/tasks/{id}/submit", workersTask.getId()))).andExpect(status().isForbidden());
        action(admin, "start").andExpect(status().isForbidden());
    }

    private Task subTask(String title, TaskStatus target) {
        Task task = new Task(manager, title, null, TaskPriority.HIGH, due(), null);
        task.makeSubTaskOf(mainTask);
        TaskStateMachine stateMachine = new TaskStateMachine();
        stateMachine.apply(task, TaskAction.ASSIGN);
        task.assignTo(worker);
        if (target == TaskStatus.CANCELLED) {
            stateMachine.apply(task, TaskAction.CANCEL);
        } else {
            stateMachine.apply(task, TaskAction.START);
            stateMachine.apply(task, TaskAction.SUBMIT);
        }
        return taskRepository.saveAndFlush(task);
    }

    private void approveDirectly(Task task) {
        Task stored = taskRepository.findById(task.getId()).orElseThrow();
        new TaskStateMachine().apply(stored, TaskAction.APPROVE);
        taskRepository.saveAndFlush(stored);
    }

    private ResultActions action(User user, String name) throws Exception {
        return mockMvc.perform(as(user, post("/api/tasks/{id}/" + name, mainTask.getId())));
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
