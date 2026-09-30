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
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.ResultActions;

/** Runs without a test transaction, like real requests. */
@Import(TestcontainersConfiguration.class)
@SpringBootTest
@AutoConfigureMockMvc
class StartTaskTests {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private JwtService jwtService;

    @Autowired
    private TaskRepository taskRepository;

    @Autowired
    private TaskStateMachine stateMachine;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private RoleRepository roleRepository;

    @Autowired
    private OrganizationRepository organizationRepository;

    private User manager;
    private User worker;
    private User otherWorker;
    private Task task;

    @BeforeEach
    void setUp() {
        manager = save("manager@example.com", "Mia Manager", RoleName.MANAGER);
        worker = save("worker@example.com", "Wendy Worker", RoleName.WORKER);
        otherWorker = save("worker2@example.com", "Will Worker", RoleName.WORKER);
        task = new Task(manager, "Kitchen", null, TaskPriority.HIGH, Instant.parse("2026-10-02T09:00:00Z"), null);
        task.assignTo(worker);
        stateMachine.apply(task, TaskAction.ASSIGN);
        task = taskRepository.save(task);
    }

    @AfterEach
    void tearDown() {
        taskRepository.deleteAll();
        userRepository.deleteAll();
    }

    @Test
    void assignedWorkerStartsTheTask() throws Exception {
        start(worker)
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("IN_PROGRESS"))
                .andExpect(jsonPath("$.version").value(1));
    }

    @Test
    void startingTwiceIsRejected() throws Exception {
        start(worker).andExpect(status().isOk());

        start(worker)
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.code").value("TASK_INVALID_TRANSITION"));
    }

    @Test
    void otherWorkersAndManagersCannotStartIt() throws Exception {
        start(otherWorker).andExpect(status().isNotFound());
        start(manager).andExpect(status().isForbidden());
    }

    @Test
    void workerStartsAgainAfterACorrectionRequest() throws Exception {
        stateMachine.apply(task, TaskAction.START);
        stateMachine.apply(task, TaskAction.SUBMIT);
        stateMachine.apply(task, TaskAction.REQUEST_CORRECTION);
        task = taskRepository.save(task);

        start(worker).andExpect(status().isOk()).andExpect(jsonPath("$.status").value("IN_PROGRESS"));
    }

    @Test
    void cancelledTaskCannotBeStarted() throws Exception {
        stateMachine.apply(task, TaskAction.CANCEL);
        task = taskRepository.save(task);

        start(worker)
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.code").value("TASK_ALREADY_CANCELLED"));
    }

    private ResultActions start(User user) throws Exception {
        return mockMvc.perform(post("/api/tasks/{id}/start", task.getId())
                .header("Authorization", "Bearer " + jwtService.issueAccessToken(user).value()));
    }

    private User save(String email, String name, RoleName... roles) {
        return userRepository.save(new User(organizationRepository.getDefault(), email, "hash", name,
                Arrays.stream(roles).map(r -> roleRepository.findByName(r).orElseThrow()).collect(Collectors.toSet())));
    }

}
