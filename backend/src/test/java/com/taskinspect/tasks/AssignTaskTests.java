package com.taskinspect.tasks;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
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

/** Runs without a test transaction, like real requests. */
@Import(TestcontainersConfiguration.class)
@SpringBootTest
@AutoConfigureMockMvc
class AssignTaskTests {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private JwtService jwtService;

    @Autowired
    private TaskRepository taskRepository;

    @Autowired
    private TaskAssignmentRepository assignmentRepository;

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
    private User otherWorker;
    private Task task;

    @BeforeEach
    void setUp() {
        manager = save("manager@example.com", "Mia Manager", RoleName.MANAGER);
        otherManager = save("manager2@example.com", "Max Manager", RoleName.MANAGER, RoleName.WORKER);
        worker = save("worker@example.com", "Wendy Worker", RoleName.WORKER);
        otherWorker = save("worker2@example.com", "Will Worker", RoleName.WORKER);
        task = taskWithRequirement(manager, null);
    }

    @AfterEach
    void tearDown() {
        taskRepository.deleteAll();
        userRepository.deleteAll();
    }

    @Test
    void managerAssignsTaskAndWorkerCanSeeIt() throws Exception {
        assign(manager, task, worker)
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("ASSIGNED"))
                .andExpect(jsonPath("$.assignee.id").value(worker.getId().toString()))
                .andExpect(jsonPath("$.assignee.fullName").value("Wendy Worker"));

        mockMvc.perform(as(worker, get("/api/tasks")))
                .andExpect(jsonPath("$.totalElements").value(1))
                .andExpect(jsonPath("$.content[0].title").value("Kitchen"));
        mockMvc.perform(as(worker, get("/api/tasks/{id}", task.getId()))).andExpect(status().isOk());
        mockMvc.perform(as(otherWorker, get("/api/tasks"))).andExpect(jsonPath("$.totalElements").value(0));
        mockMvc.perform(as(otherWorker, get("/api/tasks/{id}", task.getId()))).andExpect(status().isNotFound());

        var history = assignmentRepository.findAllByTaskIdOrderByAssignedAt(task.getId());
        assertThat(history).hasSize(1);
        assertThat(history.get(0).getAssignedAt()).isNotNull();
    }

    @Test
    void taskNeedsARequirement() throws Exception {
        Task empty = taskRepository.save(new Task(manager, "Empty", null, TaskPriority.LOW, Instant.now(), null));

        assign(manager, empty, worker)
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.code").value("TASK_HAS_NO_REQUIREMENTS"));
    }

    @Test
    void assigneeMustBeAnActiveWorker() throws Exception {
        assign(manager, task, manager)
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("INVALID_ASSIGNEE"));
        worker.deactivate();
        userRepository.save(worker);
        assign(manager, task, worker)
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("INVALID_ASSIGNEE"));
    }

    @Test
    void reviewerCannotBeTheAssignee() throws Exception {
        Task reviewedByOther = taskWithRequirement(manager, otherManager);

        assign(manager, reviewedByOther, otherManager)
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("REVIEWER_IS_ASSIGNEE"));
    }

    @Test
    void soloUserCanAssignAPersonalTaskToThemself() throws Exception {
        Task personal = taskWithRequirement(otherManager, null);

        assign(otherManager, personal, otherManager)
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.assignee.id").value(otherManager.getId().toString()))
                .andExpect(jsonPath("$.reviewer.id").value(otherManager.getId().toString()));
    }

    @Test
    void onlyTheCreatorAssignsAndOnlyOnce() throws Exception {
        assign(otherManager, task, worker).andExpect(status().isForbidden());
        assign(worker, task, worker).andExpect(status().isForbidden());

        assign(manager, task, worker).andExpect(status().isOk());
        assign(manager, task, otherWorker)
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.code").value("TASK_INVALID_TRANSITION"));
    }

    private ResultActions assign(User user, Task target, User assignee) throws Exception {
        return mockMvc.perform(as(user, post("/api/tasks/{id}/assign", target.getId()))
                .contentType(MediaType.APPLICATION_JSON)
                .content("{\"assigneeId\": \"" + assignee.getId() + "\"}"));
    }

    private Task taskWithRequirement(User creator, User reviewer) {
        Task created = taskRepository.save(new Task(creator, "Kitchen", null, TaskPriority.HIGH,
                Instant.parse("2026-10-02T09:00:00Z"), reviewer));
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
