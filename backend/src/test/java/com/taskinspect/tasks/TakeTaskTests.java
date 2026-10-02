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
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.ResultActions;
import org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder;

/** Workers see the open tasks they may take and take one (OPEN → ASSIGNED). Runs without a test transaction. */
@Import(TestcontainersConfiguration.class)
@SpringBootTest
@AutoConfigureMockMvc
class TakeTaskTests {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private JwtService jwtService;

    @Autowired
    private TaskRepository taskRepository;

    @Autowired
    private TaskAssignmentRepository assignmentRepository;

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
    private User teamMate;
    private User otherTeamWorker;
    private User loneWorker;

    @BeforeEach
    void setUp() {
        manager = save("manager@example.com", "Mia Manager", RoleName.MANAGER);
        otherManager = save("manager2@example.com", "Max Manager", RoleName.MANAGER);
        worker = inTeam(save("worker@example.com", "Wendy Worker", RoleName.WORKER), manager);
        teamMate = inTeam(save("worker2@example.com", "Tom Teammate", RoleName.WORKER), manager);
        otherTeamWorker = inTeam(save("worker3@example.com", "Olga Other", RoleName.WORKER), otherManager);
        loneWorker = save("worker4@example.com", "Leo Lone", RoleName.WORKER);
    }

    @AfterEach
    void tearDown() {
        taskRepository.deleteAll();
        userRepository.deleteAll();
    }

    @Test
    void workerTakesATeamTask() throws Exception {
        Task task = openTask(manager, OpenScope.TEAM);

        take(worker, task)
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("ASSIGNED"))
                .andExpect(jsonPath("$.assignee.id").value(worker.getId().toString()))
                .andExpect(jsonPath("$.openScope").doesNotExist());

        Task stored = taskRepository.findById(task.getId()).orElseThrow();
        assertThat(stored.getStatus()).isEqualTo(TaskStatus.ASSIGNED);
        assertThat(stored.getOpenScope()).isNull();
        assertThat(assignmentRepository.count()).isEqualTo(1);
        mockMvc.perform(as(worker, get("/api/tasks/{id}/history", task.getId())))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[-1:].event").value("TAKEN"));
        mockMvc.perform(as(worker, post("/api/tasks/{id}/start", task.getId())))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("IN_PROGRESS"));
    }

    @Test
    void firstWorkerWinsAndTakingAgainIsHarmless() throws Exception {
        Task task = openTask(manager, OpenScope.EVERYONE);
        recordPublish(task, OpenScope.EVERYONE);

        take(worker, task).andExpect(status().isOk());
        take(otherTeamWorker, task)
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.code").value("TASK_ALREADY_TAKEN"));
        take(worker, task)
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.assignee.id").value(worker.getId().toString()));
        assertThat(assignmentRepository.count()).isEqualTo(1);
        // The task is no longer open, so the others stop seeing it.
        mockMvc.perform(as(otherTeamWorker, get("/api/tasks/{id}", task.getId()))).andExpect(status().isNotFound());
    }

    @Test
    void teamTasksAreOnlyForTheTeam() throws Exception {
        Task task = openTask(manager, OpenScope.TEAM);

        mockMvc.perform(as(otherTeamWorker, get("/api/tasks/{id}", task.getId()))).andExpect(status().isNotFound());
        mockMvc.perform(as(loneWorker, get("/api/tasks/{id}", task.getId()))).andExpect(status().isNotFound());
        take(otherTeamWorker, task).andExpect(status().isNotFound());
        take(loneWorker, task).andExpect(status().isNotFound());
        take(teamMate, task).andExpect(status().isOk());
    }

    @Test
    void workersListTheOpenTasksTheyMayTakeWithTheirRequirements() throws Exception {
        Task forTeam = openTask(manager, OpenScope.TEAM);
        Task forEveryone = openTask(otherManager, OpenScope.EVERYONE);
        Task otherTeam = openTask(otherManager, OpenScope.TEAM);
        Task draft = taskWithRequirement(manager);

        mockMvc.perform(as(worker, get("/api/tasks")))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.content.length()").value(2))
                .andExpect(jsonPath("$.content[?(@.id == '" + forTeam.getId() + "')]").exists())
                .andExpect(jsonPath("$.content[?(@.id == '" + forEveryone.getId() + "')]").exists());
        mockMvc.perform(as(loneWorker, get("/api/tasks")))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.content.length()").value(1))
                .andExpect(jsonPath("$.content[0].id").value(forEveryone.getId().toString()));
        mockMvc.perform(as(worker, get("/api/tasks/{id}/requirements", forTeam.getId())))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.length()").value(1));
        mockMvc.perform(as(worker, get("/api/tasks/{id}", otherTeam.getId()))).andExpect(status().isNotFound());
        mockMvc.perform(as(worker, get("/api/tasks/{id}", draft.getId()))).andExpect(status().isNotFound());
        mockMvc.perform(as(worker, get("/api/sync/pull")))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.taskIds.length()").value(2));
    }

    @Test
    void workersOutsideTheScopeDoNotLearnThatATakenTaskExists() throws Exception {
        Task task = openTask(manager, OpenScope.TEAM);
        recordPublish(task, OpenScope.TEAM);

        take(worker, task).andExpect(status().isOk());
        take(teamMate, task)
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.code").value("TASK_ALREADY_TAKEN"));
        take(otherTeamWorker, task).andExpect(status().isNotFound());
        take(loneWorker, task).andExpect(status().isNotFound());
    }

    @Test
    void anAssignedTaskThatWasNeverOpenCannotBeTaken() throws Exception {
        Task task = taskWithRequirement(manager);
        new TaskStateMachine().apply(task, TaskAction.ASSIGN);
        task.assignTo(worker);
        taskRepository.saveAndFlush(task);

        take(worker, task).andExpect(status().isNotFound());
        take(teamMate, task).andExpect(status().isNotFound());
    }

    @Test
    void deactivatedTeamManagerClosesTheTeamTasks() throws Exception {
        Task task = openTask(manager, OpenScope.TEAM);
        manager.deactivate();
        userRepository.save(manager);

        mockMvc.perform(as(worker, get("/api/tasks/{id}", task.getId()))).andExpect(status().isNotFound());
        take(worker, task).andExpect(status().isNotFound());
    }

    @Test
    void onlyOpenTasksCanBeTakenAndOnlyByWorkers() throws Exception {
        Task draft = taskWithRequirement(manager);
        Task open = openTask(manager, OpenScope.EVERYONE);

        take(worker, draft).andExpect(status().isNotFound());
        take(manager, open).andExpect(status().isForbidden());

        Task cancelled = taskRepository.findById(open.getId()).orElseThrow();
        new TaskStateMachine().apply(cancelled, TaskAction.CANCEL);
        taskRepository.saveAndFlush(cancelled);
        take(worker, open).andExpect(status().isNotFound());
    }

    private Task openTask(User creator, OpenScope scope) {
        Task task = taskWithRequirement(creator);
        new TaskStateMachine().apply(task, TaskAction.PUBLISH);
        task.openTo(scope);
        return taskRepository.saveAndFlush(task);
    }

    /** The history entry a real publish writes; taking reads the scope back from it once the task is no longer open. */
    private void recordPublish(Task task, OpenScope scope) {
        historyRepository.save(new TaskStatusChange(task, TaskStatus.DRAFT, TaskStatus.OPEN, manager, "open to: " + scope));
    }

    private ResultActions take(User user, Task target) throws Exception {
        return mockMvc.perform(as(user, post("/api/tasks/{id}/take", target.getId())));
    }

    private Task taskWithRequirement(User creator) {
        Task created = taskRepository.save(new Task(creator, "Kitchen", null, TaskPriority.HIGH,
                Instant.parse("2026-10-02T09:00:00Z"), null));
        requirementRepository.save(new Requirement(created, "Is the fire extinguisher available?", null,
                RequirementType.YES_NO, true, 0, null, null));
        return created;
    }

    private User inTeam(User member, User teamManager) {
        member.joinTeamOf(teamManager);
        return userRepository.save(member);
    }

    private MockHttpServletRequestBuilder as(User user, MockHttpServletRequestBuilder request) {
        return request.header("Authorization", "Bearer " + jwtService.issueAccessToken(user).value());
    }

    private User save(String email, String name, RoleName... roles) {
        return userRepository.save(new User(organizationRepository.getDefault(), email, "hash", name,
                Arrays.stream(roles).map(r -> roleRepository.findByName(r).orElseThrow()).collect(Collectors.toSet())));
    }

}
