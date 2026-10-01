package com.taskinspect.sync;

import static org.hamcrest.Matchers.containsInAnyOrder;
import static org.hamcrest.Matchers.notNullValue;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.taskinspect.TestcontainersConfiguration;
import com.taskinspect.auth.JwtService;
import com.taskinspect.requirements.Requirement;
import com.taskinspect.requirements.RequirementRepository;
import com.taskinspect.requirements.RequirementType;
import com.taskinspect.tasks.Task;
import com.taskinspect.tasks.TaskAction;
import com.taskinspect.tasks.TaskFixtures;
import com.taskinspect.tasks.TaskPriority;
import com.taskinspect.tasks.TaskRepository;
import com.taskinspect.tasks.TaskStateMachine;
import com.taskinspect.users.OrganizationRepository;
import com.taskinspect.users.RoleName;
import com.taskinspect.users.RoleRepository;
import com.taskinspect.users.User;
import com.taskinspect.users.UserRepository;
import java.sql.Timestamp;
import java.time.Duration;
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
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.ResultActions;
import org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder;

/** Runs without a test transaction, like real requests. */
@Import(TestcontainersConfiguration.class)
@SpringBootTest
@AutoConfigureMockMvc
class SyncPullTests {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private JwtService jwtService;

    @Autowired
    private TaskRepository taskRepository;

    @Autowired
    private TaskStateMachine stateMachine;

    @Autowired
    private RequirementRepository requirementRepository;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private RoleRepository roleRepository;

    @Autowired
    private OrganizationRepository organizationRepository;

    @Autowired
    private JdbcTemplate jdbcTemplate;

    private User manager;
    private User worker;
    private User otherWorker;
    private Task kitchen;
    private Task warehouse;
    private Task draft;

    @BeforeEach
    void setUp() {
        manager = save("manager@example.com", "Mia Manager", RoleName.MANAGER);
        worker = save("worker@example.com", "Wendy Worker", RoleName.WORKER);
        otherWorker = save("other@example.com", "Otto Worker", RoleName.WORKER);
        kitchen = assignedTask("Kitchen", worker);
        warehouse = assignedTask("Warehouse", worker);
        draft = taskRepository.save(new Task(manager, "Draft", null, TaskPriority.LOW,
                Instant.parse("2026-12-01T09:00:00Z"), null));
    }

    @AfterEach
    void tearDown() {
        taskRepository.deleteAll();
        userRepository.deleteAll();
    }

    @Test
    void theFirstPullSendsEveryTaskTheWorkerMaySeeWithItsRequirements() throws Exception {
        pull(worker, null)
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.cursor").value(notNullValue()))
                .andExpect(jsonPath("$.taskIds", containsInAnyOrder(kitchen.getId().toString(),
                        warehouse.getId().toString())))
                .andExpect(jsonPath("$.tasks.length()").value(2))
                .andExpect(jsonPath("$.tasks[?(@.task.title == 'Kitchen')].requirements[0].title").value("Ok?"))
                .andExpect(jsonPath("$.tasks[?(@.task.title == 'Kitchen')].task.status").value("ASSIGNED"));
    }

    @Test
    void aLaterPullSendsOnlyTheTasksThatChanged() throws Exception {
        makeOld(kitchen, warehouse);
        Instant lastPull = Instant.now().minus(Duration.ofMinutes(10));

        pull(worker, lastPull)
                .andExpect(jsonPath("$.taskIds.length()").value(2))
                .andExpect(jsonPath("$.tasks.length()").value(0));

        // The manager adds a requirement to the kitchen task.
        mockMvc.perform(as(manager, post("/api/tasks/{id}/requirements", kitchen.getId()))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"title\": \"Fridge temperature\", \"type\": \"NUMBER\", \"unit\": \"°C\"}"))
                .andExpect(status().isCreated());

        pull(worker, lastPull)
                .andExpect(jsonPath("$.tasks.length()").value(1))
                .andExpect(jsonPath("$.tasks[0].task.id").value(kitchen.getId().toString()))
                .andExpect(jsonPath("$.tasks[0].requirements.length()").value(2))
                .andExpect(jsonPath("$.tasks[0].requirements[1].unit").value("°C"));
    }

    @Test
    void changesFromJustBeforeTheCursorAreSentAgain() throws Exception {
        // Changed 30 s before the last pull's cursor, e.g. committed while that pull ran.
        Instant lastPull = Instant.now();
        jdbcTemplate.update("update tasks set updated_at = ? where id = ?",
                Timestamp.from(lastPull.minusSeconds(30)), kitchen.getId());
        makeOld(warehouse);

        pull(worker, lastPull)
                .andExpect(jsonPath("$.tasks.length()").value(1))
                .andExpect(jsonPath("$.tasks[0].task.id").value(kitchen.getId().toString()));
    }

    @Test
    void aTaskGivenToAnotherWorkerDisappearsFromTaskIds() throws Exception {
        jdbcTemplate.update("update tasks set assignee_id = ? where id = ?", otherWorker.getId(), warehouse.getId());

        pull(worker, Instant.now())
                .andExpect(jsonPath("$.taskIds", containsInAnyOrder(kitchen.getId().toString())));
    }

    @Test
    void managersGetEveryTaskOfTheirOrganization() throws Exception {
        pull(manager, null)
                .andExpect(jsonPath("$.taskIds", containsInAnyOrder(kitchen.getId().toString(),
                        warehouse.getId().toString(), draft.getId().toString())));
    }

    @Test
    void anInvalidCursorOrAMissingLoginIsRefused() throws Exception {
        mockMvc.perform(as(worker, get("/api/sync/pull").param("since", "yesterday")))
                .andExpect(status().isBadRequest());
        mockMvc.perform(get("/api/sync/pull")).andExpect(status().isUnauthorized());
    }

    private ResultActions pull(User user, Instant since) throws Exception {
        MockHttpServletRequestBuilder request = get("/api/sync/pull");
        if (since != null) {
            request.param("since", since.toString());
        }
        return mockMvc.perform(as(user, request));
    }

    private void makeOld(Task... tasks) {
        for (Task task : tasks) {
            jdbcTemplate.update("update tasks set updated_at = now() - interval '1 hour' where id = ?", task.getId());
        }
    }

    /** An ASSIGNED task of the manager for the worker, with one YES_NO requirement. */
    private Task assignedTask(String title, User assignee) {
        Task created = taskRepository.save(new Task(manager, title, null, TaskPriority.HIGH,
                Instant.parse("2026-12-01T09:00:00Z"), null));
        requirementRepository.save(new Requirement(created, "Ok?", null, RequirementType.YES_NO, true, 0, null, null));
        TaskFixtures.assign(created, assignee);
        stateMachine.apply(created, TaskAction.ASSIGN);
        return taskRepository.save(created);
    }

    private MockHttpServletRequestBuilder as(User user, MockHttpServletRequestBuilder request) {
        return request.header("Authorization", "Bearer " + jwtService.issueAccessToken(user).value());
    }

    private User save(String email, String name, RoleName... roles) {
        return userRepository.save(new User(organizationRepository.getDefault(), email, "hash", name,
                Arrays.stream(roles).map(r -> roleRepository.findByName(r).orElseThrow()).collect(Collectors.toSet())));
    }

}
