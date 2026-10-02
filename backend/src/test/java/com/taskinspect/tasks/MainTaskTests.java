package com.taskinspect.tasks;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
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

/** An administrator creates a main task and assigns it to a manager (task 7A.6a). */
@Import(TestcontainersConfiguration.class)
@SpringBootTest
@AutoConfigureMockMvc
class MainTaskTests {

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
    private User otherAdmin;
    private User manager;
    private User worker;

    @BeforeEach
    void setUp() {
        admin = save("admin@example.com", "Ada Admin", RoleName.ADMINISTRATOR);
        otherAdmin = save("admin2@example.com", "Abe Admin", RoleName.ADMINISTRATOR);
        manager = save("manager@example.com", "Mia Manager", RoleName.MANAGER);
        worker = save("worker@example.com", "Wendy Worker", RoleName.WORKER);
    }

    @AfterEach
    void tearDown() {
        taskRepository.deleteAll();
        userRepository.deleteAll();
    }

    @Test
    void adminAssignsAMainTaskToAManagerWithoutRequirements() throws Exception {
        String id = create(admin, null).andExpect(status().isCreated())
                .andExpect(jsonPath("$.status").value("DRAFT"))
                .andExpect(jsonPath("$.reviewer.id").value(admin.getId().toString()))
                .andReturn().getResponse().getContentAsString();
        String taskId = JsonPath.read(id, "$.id");

        assign(admin, taskId, worker)
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("INVALID_ASSIGNEE"));
        assign(admin, taskId, manager)
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("ASSIGNED"))
                .andExpect(jsonPath("$.assignee.id").value(manager.getId().toString()));
        mockMvc.perform(as(manager, get("/api/tasks/{id}", taskId)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.assignee.id").value(manager.getId().toString()));
    }

    @Test
    void mainTaskReviewerIsAnAdministrator() throws Exception {
        create(admin, manager)
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("INVALID_REVIEWER"));
        create(admin, otherAdmin)
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.reviewer.id").value(otherAdmin.getId().toString()));
    }

    @Test
    void managerTasksStillGoToWorkersOnly() throws Exception {
        String body = create(manager, null).andExpect(status().isCreated())
                .andReturn().getResponse().getContentAsString();
        String taskId = JsonPath.read(body, "$.id");

        // A manager's task is not a main task: it needs a requirement first and goes to a worker.
        assign(manager, taskId, worker)
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.code").value("TASK_HAS_NO_REQUIREMENTS"));
        create(worker, null).andExpect(status().isForbidden());
    }

    @Test
    void onlyTheCreatingAdministratorAssignsTheMainTask() throws Exception {
        String body = create(admin, null).andExpect(status().isCreated())
                .andReturn().getResponse().getContentAsString();
        String taskId = JsonPath.read(body, "$.id");

        assign(otherAdmin, taskId, manager).andExpect(status().isForbidden());
        assign(manager, taskId, manager).andExpect(status().isForbidden());
    }

    @Test
    void mainTaskReviewerStaysAnAdministratorWhenEdited() throws Exception {
        String body = create(admin, null).andExpect(status().isCreated())
                .andReturn().getResponse().getContentAsString();
        String taskId = JsonPath.read(body, "$.id");

        edit(admin, taskId, manager)
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("INVALID_REVIEWER"));
        edit(admin, taskId, otherAdmin)
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.reviewer.id").value(otherAdmin.getId().toString()));
    }

    @Test
    void mainTaskCannotBePublished() throws Exception {
        // Only a user who is both administrator and manager gets past the role check of publish.
        User both = save("both@example.com", "Bo Both", RoleName.ADMINISTRATOR, RoleName.MANAGER);
        String body = create(both, null).andExpect(status().isCreated())
                .andReturn().getResponse().getContentAsString();
        String taskId = JsonPath.read(body, "$.id");

        mockMvc.perform(as(both, post("/api/tasks/{id}/publish", taskId))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"scope\": \"EVERYONE\"}"))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.code").value("MAIN_TASK_NOT_PUBLISHABLE"));
        mockMvc.perform(as(admin, post("/api/tasks/{id}/publish", taskId))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"scope\": \"EVERYONE\"}"))
                .andExpect(status().isForbidden());
    }

    private ResultActions edit(User user, String taskId, User reviewer) throws Exception {
        return mockMvc.perform(as(user, put("/api/tasks/{id}", taskId))
                .contentType(MediaType.APPLICATION_JSON)
                .content("{\"title\": \"Inspect building C\", \"priority\": \"LOW\", "
                        + "\"dueDate\": \"2026-12-01T09:00:00Z\", \"reviewerId\": \"" + reviewer.getId()
                        + "\", \"version\": 0}"));
    }

    private ResultActions create(User user, User reviewer) throws Exception {
        String reviewerField = reviewer == null ? "" : ", \"reviewerId\": \"" + reviewer.getId() + "\"";
        return mockMvc.perform(as(user, post("/api/tasks"))
                .contentType(MediaType.APPLICATION_JSON)
                .content("{\"title\": \"Inspect building B\", \"priority\": \"HIGH\", "
                        + "\"dueDate\": \"2026-12-01T09:00:00Z\"" + reviewerField + "}"));
    }

    private ResultActions assign(User user, String taskId, User assignee) throws Exception {
        return mockMvc.perform(as(user, post("/api/tasks/{id}/assign", taskId))
                .contentType(MediaType.APPLICATION_JSON)
                .content("{\"assigneeId\": \"" + assignee.getId() + "\"}"));
    }

    private MockHttpServletRequestBuilder as(User user, MockHttpServletRequestBuilder request) {
        return request.header("Authorization", "Bearer " + jwtService.issueAccessToken(user).value());
    }

    private User save(String email, String name, RoleName... roles) {
        return userRepository.save(new User(organizationRepository.getDefault(), email, "hash", name,
                Arrays.stream(roles).map(r -> roleRepository.findByName(r).orElseThrow()).collect(Collectors.toSet())));
    }

}
