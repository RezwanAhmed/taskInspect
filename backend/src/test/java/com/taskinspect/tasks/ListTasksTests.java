package com.taskinspect.tasks;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
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
import org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder;

/**
 * Runs without a test transaction, like a real request, so data that is
 * not loaded before the transaction ends would make these tests fail.
 */
@Import(TestcontainersConfiguration.class)
@SpringBootTest
@AutoConfigureMockMvc
class ListTasksTests {

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
    private User admin;
    private User worker;
    private Task kitchen;

    @BeforeEach
    void setUp() {
        manager = save("manager@example.com", "Mia Manager", RoleName.MANAGER);
        otherManager = save("manager2@example.com", "Max Manager", RoleName.MANAGER);
        admin = save("admin@example.com", "Ada Admin", RoleName.ADMINISTRATOR);
        worker = save("worker@example.com", "Wendy Worker", RoleName.WORKER);
        kitchen = task(manager, "Kitchen", TaskPriority.HIGH, "2026-10-02T09:00:00Z");
        task(manager, "Fire exits", TaskPriority.LOW, "2026-10-01T09:00:00Z");
        task(otherManager, "Warehouse", TaskPriority.HIGH, "2026-10-05T09:00:00Z");
        stateMachine.apply(kitchen, TaskAction.ASSIGN);
        kitchen = taskRepository.save(kitchen);
    }

    @AfterEach
    void tearDown() {
        taskRepository.deleteAll();
        userRepository.deleteAll();
    }

    @Test
    void managerSeesAllTasksOfTheOrganizationSortedByDueDate() throws Exception {
        mockMvc.perform(as(manager, get("/api/tasks")))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.totalElements").value(3))
                .andExpect(jsonPath("$.content[0].title").value("Fire exits"))
                .andExpect(jsonPath("$.content[1].title").value("Kitchen"))
                .andExpect(jsonPath("$.content[2].title").value("Warehouse"));
    }

    @Test
    void filtersByStatusPriorityAndDueDate() throws Exception {
        mockMvc.perform(as(manager, get("/api/tasks").param("status", "ASSIGNED")))
                .andExpect(jsonPath("$.totalElements").value(1))
                .andExpect(jsonPath("$.content[0].title").value("Kitchen"));
        mockMvc.perform(as(manager, get("/api/tasks").param("priority", "HIGH")))
                .andExpect(jsonPath("$.totalElements").value(2));
        mockMvc.perform(as(manager, get("/api/tasks")
                        .param("dueFrom", "2026-10-02T00:00:00Z").param("dueBefore", "2026-10-03T00:00:00Z")))
                .andExpect(jsonPath("$.totalElements").value(1))
                .andExpect(jsonPath("$.content[0].title").value("Kitchen"));
    }

    @Test
    void pagesThroughTasks() throws Exception {
        mockMvc.perform(as(manager, get("/api/tasks").param("page", "1").param("size", "2")))
                .andExpect(jsonPath("$.content.length()").value(1))
                .andExpect(jsonPath("$.content[0].title").value("Warehouse"))
                .andExpect(jsonPath("$.page").value(1))
                .andExpect(jsonPath("$.totalPages").value(2));
    }

    @Test
    void administratorSeesAllTasks() throws Exception {
        mockMvc.perform(as(admin, get("/api/tasks"))).andExpect(jsonPath("$.totalElements").value(3));
    }

    @Test
    void workerSeesNoUnassignedTasks() throws Exception {
        mockMvc.perform(as(worker, get("/api/tasks")))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.totalElements").value(0));
        mockMvc.perform(as(worker, get("/api/tasks/{id}", kitchen.getId())))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.code").value("TASK_NOT_FOUND"));
    }

    @Test
    void getsOneTask() throws Exception {
        mockMvc.perform(as(otherManager, get("/api/tasks/{id}", kitchen.getId())))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.title").value("Kitchen"))
                .andExpect(jsonPath("$.status").value("ASSIGNED"))
                .andExpect(jsonPath("$.createdBy.fullName").value("Mia Manager"));
    }

    @Test
    void unknownTaskAndBadFiltersAreRejected() throws Exception {
        mockMvc.perform(as(manager, get("/api/tasks/{id}", "00000000-0000-0000-0000-00000000abcd")))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.code").value("TASK_NOT_FOUND"));
        mockMvc.perform(as(manager, get("/api/tasks").param("status", "DONE")))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("INVALID_PARAMETER"));
        mockMvc.perform(as(manager, get("/api/tasks").param("dueFrom", "yesterday")))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("INVALID_PARAMETER"));
    }

    private MockHttpServletRequestBuilder as(User user, MockHttpServletRequestBuilder request) {
        return request.header("Authorization", "Bearer " + jwtService.issueAccessToken(user).value());
    }

    private Task task(User creator, String title, TaskPriority priority, String dueDate) {
        return taskRepository.save(new Task(creator, title, null, priority, Instant.parse(dueDate), null));
    }

    private User save(String email, String name, RoleName... roles) {
        return userRepository.save(new User(organizationRepository.getDefault(), email, "hash", name,
                Arrays.stream(roles).map(r -> roleRepository.findByName(r).orElseThrow()).collect(Collectors.toSet())));
    }

}
