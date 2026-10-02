package com.taskinspect.common.security;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
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
import com.taskinspect.tasks.TaskStatus;
import com.taskinspect.users.OrganizationRepository;
import com.taskinspect.users.RoleName;
import com.taskinspect.users.RoleRepository;
import com.taskinspect.users.User;
import com.taskinspect.users.UserRepository;
import java.time.Instant;
import java.util.Arrays;
import java.util.Map;
import java.util.function.BiFunction;
import java.util.function.Function;
import java.util.stream.Collectors;
import java.util.stream.Stream;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.Arguments;
import org.junit.jupiter.params.provider.MethodSource;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.context.annotation.Import;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder;

/**
 * Calls every endpoint as every kind of user and checks the answer against
 * the "API Permissions" table in docs/architecture.md.
 */
@Import(TestcontainersConfiguration.class)
@SpringBootTest
@AutoConfigureMockMvc
class AuthorizationMatrixTests {

    enum Actor { ANONYMOUS, ADMIN, CREATOR, OTHER_MANAGER, ASSIGNED_WORKER, OTHER_WORKER }

    /** Builds the request for one endpoint, given the fixture (task in the right status, etc.). */
    record Endpoint(String name, TaskStatus taskStatus, BiFunction<Fixture, Actor, MockHttpServletRequestBuilder> request) {

        @Override
        public String toString() {
            return name;
        }

    }

    record Fixture(Map<Actor, User> users, Task task, Requirement requirement) {
    }

    private static final Endpoint LIST_USERS = new Endpoint("GET /api/users", null, (f, a) -> get("/api/users"));
    private static final Endpoint LIST_TEAMS = new Endpoint("GET /api/teams", null, (f, a) -> get("/api/teams"));
    private static final Endpoint LIST_TEAM_TASKS = new Endpoint("GET /api/tasks/team", null,
            (f, a) -> get("/api/tasks/team"));
    private static final Endpoint CREATE_USER = new Endpoint("POST /api/users", null, (f, a) -> post("/api/users")
            .contentType(MediaType.APPLICATION_JSON).content("""
                    {"email": "new-%s@example.com", "fullName": "New", "password": "password-123",
                     "roles": ["WORKER"]}""".formatted(a.name().toLowerCase())));
    private static final Endpoint GET_WORKER = new Endpoint("GET /api/users/{assignedWorker}", null,
            (f, a) -> get("/api/users/{id}", f.users().get(Actor.ASSIGNED_WORKER).getId()));
    private static final Endpoint SET_TEAM = new Endpoint("PUT /api/users/{assignedWorker}/team", null,
            (f, a) -> put("/api/users/{id}/team", f.users().get(Actor.ASSIGNED_WORKER).getId())
                    .contentType(MediaType.APPLICATION_JSON)
                    .content("{\"managerId\": \"" + f.users().get(Actor.CREATOR).getId() + "\"}"));
    private static final Endpoint CREATE_TASK = new Endpoint("POST /api/tasks", null, (f, a) -> post("/api/tasks")
            .contentType(MediaType.APPLICATION_JSON)
            .content("{\"title\": \"T\", \"priority\": \"LOW\", \"dueDate\": \"2026-12-01T09:00:00Z\"}"));
    private static final Endpoint GET_TASK = new Endpoint("GET /api/tasks/{id}", TaskStatus.ASSIGNED,
            (f, a) -> get("/api/tasks/{id}", f.task().getId()));
    private static final Endpoint EDIT_TASK = new Endpoint("PUT /api/tasks/{id}", TaskStatus.DRAFT,
            (f, a) -> put("/api/tasks/{id}", f.task().getId()).contentType(MediaType.APPLICATION_JSON)
                    .content("{\"title\": \"T2\", \"priority\": \"LOW\", \"dueDate\": \"2026-12-01T09:00:00Z\", "
                            + "\"version\": " + f.task().getVersion() + "}"));
    private static final Endpoint ADD_REQUIREMENT = new Endpoint("POST /api/tasks/{id}/requirements",
            TaskStatus.DRAFT, (f, a) -> post("/api/tasks/{id}/requirements", f.task().getId())
                    .contentType(MediaType.APPLICATION_JSON).content("{\"title\": \"Ok?\", \"type\": \"YES_NO\"}"));
    private static final Endpoint ASSIGN = new Endpoint("POST /api/tasks/{id}/assign", TaskStatus.DRAFT,
            (f, a) -> post("/api/tasks/{id}/assign", f.task().getId()).contentType(MediaType.APPLICATION_JSON)
                    .content("{\"assigneeId\": \"" + f.users().get(Actor.ASSIGNED_WORKER).getId() + "\"}"));
    private static final Endpoint START = new Endpoint("POST /api/tasks/{id}/start", TaskStatus.ASSIGNED,
            (f, a) -> post("/api/tasks/{id}/start", f.task().getId()));
    private static final Endpoint ANSWER = new Endpoint("PUT .../response", TaskStatus.IN_PROGRESS,
            (f, a) -> put("/api/tasks/{t}/requirements/{r}/response", f.task().getId(), f.requirement().getId())
                    .contentType(MediaType.APPLICATION_JSON).content("{\"booleanValue\": true}"));
    // The fixture's required requirement is unanswered: the assigned worker gets 409 REQUIREMENTS_MISSING,
    // which shows the call was allowed.
    private static final Endpoint SUBMIT = new Endpoint("POST /api/tasks/{id}/submit", TaskStatus.IN_PROGRESS,
            (f, a) -> post("/api/tasks/{id}/submit", f.task().getId()));
    private static final Endpoint APPROVE = new Endpoint("POST /api/tasks/{id}/approve", TaskStatus.SUBMITTED,
            (f, a) -> post("/api/tasks/{id}/approve", f.task().getId()));
    private static final Endpoint REJECT = new Endpoint("POST /api/tasks/{id}/reject", TaskStatus.SUBMITTED,
            (f, a) -> post("/api/tasks/{id}/reject", f.task().getId()).contentType(MediaType.APPLICATION_JSON)
                    .content("{\"reason\": \"Wrong room\"}"));
    private static final Endpoint REQUEST_CORRECTION = new Endpoint("POST /api/tasks/{id}/request-correction",
            TaskStatus.SUBMITTED, (f, a) -> post("/api/tasks/{id}/request-correction", f.task().getId())
                    .contentType(MediaType.APPLICATION_JSON)
                    .content("{\"requirements\": [{\"requirementId\": \"" + f.requirement().getId()
                            + "\", \"comment\": \"Fix\"}]}"));
    private static final Endpoint HISTORY = new Endpoint("GET /api/tasks/{id}/history", TaskStatus.SUBMITTED,
            (f, a) -> get("/api/tasks/{id}/history", f.task().getId()));
    private static final Endpoint LIST_REVIEWS = new Endpoint("GET /api/tasks/{id}/reviews", TaskStatus.SUBMITTED,
            (f, a) -> get("/api/tasks/{id}/reviews", f.task().getId()));
    private static final Endpoint LIST_RESPONSES = new Endpoint("GET /api/tasks/{id}/responses",
            TaskStatus.IN_PROGRESS, (f, a) -> get("/api/tasks/{id}/responses", f.task().getId()));

    static Stream<Arguments> matrix() {
        return Stream.of(
                row(LIST_USERS, 401, 200, 200, 200, 403, 403),
                row(CREATE_USER, 401, 201, 403, 403, 403, 403),
                row(GET_WORKER, 401, 200, 200, 200, 200, 403),
                row(SET_TEAM, 401, 200, 403, 403, 403, 403),
                row(LIST_TEAMS, 401, 200, 200, 200, 200, 200),
                row(LIST_TEAM_TASKS, 401, 200, 200, 200, 200, 200),
                row(CREATE_TASK, 401, 201, 201, 201, 403, 403),
                row(GET_TASK, 401, 200, 200, 200, 200, 404),
                row(EDIT_TASK, 401, 403, 200, 403, 403, 403),
                row(ADD_REQUIREMENT, 401, 403, 201, 403, 403, 403),
                row(ASSIGN, 401, 403, 200, 403, 403, 403),
                row(START, 401, 403, 403, 403, 200, 404),
                row(ANSWER, 401, 403, 403, 403, 200, 404),
                row(SUBMIT, 401, 403, 403, 403, 409, 404),
                row(APPROVE, 401, 403, 200, 403, 403, 403),
                row(REJECT, 401, 403, 200, 403, 403, 403),
                row(REQUEST_CORRECTION, 401, 403, 200, 403, 403, 403),
                row(LIST_REVIEWS, 401, 200, 200, 200, 200, 404),
                row(HISTORY, 401, 200, 200, 200, 200, 404),
                row(LIST_RESPONSES, 401, 200, 200, 200, 200, 404))
                .flatMap(Function.identity());
    }

    /** Expected status per actor, in the order of {@link Actor}. */
    private static Stream<Arguments> row(Endpoint endpoint, int... expected) {
        return Arrays.stream(Actor.values()).map(actor -> Arguments.of(endpoint, actor, expected[actor.ordinal()]));
    }

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

    private Map<Actor, User> users;

    @BeforeEach
    void setUp() {
        users = Map.of(
                Actor.ADMIN, save("admin@example.com", RoleName.ADMINISTRATOR),
                Actor.CREATOR, save("creator@example.com", RoleName.MANAGER),
                Actor.OTHER_MANAGER, save("manager2@example.com", RoleName.MANAGER),
                Actor.ASSIGNED_WORKER, save("worker@example.com", RoleName.WORKER),
                Actor.OTHER_WORKER, save("worker2@example.com", RoleName.WORKER));
    }

    @AfterEach
    void tearDown() {
        taskRepository.deleteAll();
        userRepository.deleteAll();
    }

    @ParameterizedTest(name = "{0} as {1} -> {2}")
    @MethodSource("matrix")
    void endpointAnswersAsDocumented(Endpoint endpoint, Actor actor, int expectedStatus) throws Exception {
        Fixture fixture = fixture(endpoint.taskStatus());
        MockHttpServletRequestBuilder request = endpoint.request().apply(fixture, actor);
        if (actor != Actor.ANONYMOUS) {
            request.header("Authorization", "Bearer " + jwtService.issueAccessToken(users.get(actor)).value());
        }

        mockMvc.perform(request).andExpect(status().is(expectedStatus));
    }

    /** A task of the creator in the given status (with one requirement), or none. */
    private Fixture fixture(TaskStatus wanted) {
        if (wanted == null) {
            return new Fixture(users, null, null);
        }
        Task task = taskRepository.save(new Task(users.get(Actor.CREATOR), "Kitchen", null, TaskPriority.HIGH,
                Instant.parse("2026-12-01T09:00:00Z"), null));
        Requirement requirement = requirementRepository.save(new Requirement(task, "Ok?", null,
                RequirementType.YES_NO, true, 0, null, null));
        if (wanted != TaskStatus.DRAFT) {
            TaskFixtures.assign(task, users.get(Actor.ASSIGNED_WORKER));
            stateMachine.apply(task, TaskAction.ASSIGN);
        }
        if (wanted == TaskStatus.IN_PROGRESS || wanted == TaskStatus.SUBMITTED) {
            stateMachine.apply(task, TaskAction.START);
        }
        if (wanted == TaskStatus.SUBMITTED) {
            stateMachine.apply(task, TaskAction.SUBMIT);
        }
        return new Fixture(users, taskRepository.save(task), requirement);
    }

    private User save(String email, RoleName... roles) {
        return userRepository.save(new User(organizationRepository.getDefault(), email, "hash", email,
                Arrays.stream(roles).map(r -> roleRepository.findByName(r).orElseThrow()).collect(Collectors.toSet())));
    }

}
