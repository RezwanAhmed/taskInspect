package com.taskinspect.tasks;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
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

@Import(TestcontainersConfiguration.class)
@SpringBootTest
@AutoConfigureMockMvc
class UpdateTaskTests {

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
    private User otherManager;
    private User worker;
    private Task task;

    @BeforeEach
    void setUp() {
        manager = save("manager@example.com", "Mia Manager", RoleName.MANAGER);
        otherManager = save("manager2@example.com", "Max Manager", RoleName.MANAGER);
        worker = save("worker@example.com", "Wendy Worker", RoleName.WORKER);
        task = taskRepository.save(new Task(manager, "Kitchen", "Old description", TaskPriority.LOW,
                Instant.parse("2026-10-02T09:00:00Z"), null));
    }

    @AfterEach
    void tearDown() {
        taskRepository.deleteAll();
        userRepository.deleteAll();
    }

    @Test
    void creatorEditsDraftTask() throws Exception {
        update(manager, body("Kitchen and storage", "HIGH", otherManager.getId().toString(), 0))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.title").value("Kitchen and storage"))
                .andExpect(jsonPath("$.priority").value("HIGH"))
                .andExpect(jsonPath("$.dueDate").value("2026-10-03T09:00:00Z"))
                .andExpect(jsonPath("$.reviewer.fullName").value("Max Manager"))
                .andExpect(jsonPath("$.description").doesNotExist())
                .andExpect(jsonPath("$.version").value(1));
    }

    @Test
    void staleVersionIsRejected() throws Exception {
        update(manager, body("First edit", "HIGH", null, 0)).andExpect(status().isOk());

        update(manager, body("Edit based on old data", "LOW", null, 0))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.code").value("VERSION_CONFLICT"));
    }

    @Test
    void onlyTheCreatorCanEdit() throws Exception {
        update(otherManager, body("Changed", "HIGH", null, 0))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.code").value("FORBIDDEN"));
        update(worker, body("Changed", "HIGH", null, 0)).andExpect(status().isForbidden());
    }

    @Test
    void taskCannotBeEditedAfterWorkStarts() throws Exception {
        stateMachine.apply(task, TaskAction.ASSIGN);
        stateMachine.apply(task, TaskAction.START);
        task = taskRepository.save(task);

        update(manager, body("Too late", "HIGH", null, task.getVersion()))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.code").value("TASK_NOT_EDITABLE"));
    }

    @Test
    void invalidReviewerAndBodyAreRejected() throws Exception {
        update(manager, body("Kitchen", "HIGH", worker.getId().toString(), 0))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("INVALID_REVIEWER"));
        update(manager, "{\"title\": \"\"}")
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("VALIDATION_ERROR"));
    }

    private static String body(String title, String priority, String reviewerId, long version) {
        return """
                {"title": "%s", "description": "  ", "priority": "%s", "dueDate": "2026-10-03T09:00:00Z",
                 "reviewerId": %s, "version": %d}""".formatted(title, priority,
                reviewerId == null ? "null" : "\"" + reviewerId + "\"", version);
    }

    private ResultActions update(User user, String json) throws Exception {
        return mockMvc.perform(put("/api/tasks/{id}", task.getId())
                .header("Authorization", "Bearer " + jwtService.issueAccessToken(user).value())
                .contentType(MediaType.APPLICATION_JSON)
                .content(json));
    }

    private User save(String email, String name, RoleName... roles) {
        return userRepository.save(new User(organizationRepository.getDefault(), email, "hash", name,
                Arrays.stream(roles).map(r -> roleRepository.findByName(r).orElseThrow()).collect(Collectors.toSet())));
    }

}
