package com.taskinspect.common.security;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.taskinspect.TestcontainersConfiguration;
import com.taskinspect.auth.JwtService;
import com.taskinspect.requirements.Requirement;
import com.taskinspect.requirements.RequirementRepository;
import com.taskinspect.requirements.RequirementType;
import com.taskinspect.tasks.OpenScope;
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
import java.util.UUID;
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
import org.springframework.jdbc.core.JdbcTemplate;
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
    record Endpoint(String name, TaskStatus taskStatus, boolean withFiles,
            BiFunction<Fixture, Actor, MockHttpServletRequestBuilder> request) {

        Endpoint(String name, TaskStatus taskStatus,
                BiFunction<Fixture, Actor, MockHttpServletRequestBuilder> request) {
            this(name, taskStatus, false, request);
        }

        @Override
        public String toString() {
            return name;
        }

    }

    /**
     * Users, and a task with a required YES_NO requirement. For evidence endpoints ({@code withFiles}) the task
     * also gets a PHOTO requirement with one pending and one uploaded file.
     */
    record Fixture(Map<Actor, User> users, Task task, Requirement requirement, Requirement photo,
            UUID pendingEvidence, UUID uploadedEvidence) {
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

    // Task endpoints added since Phase 7 (task 9.3a).
    private static final Endpoint LIST_TASKS = new Endpoint("GET /api/tasks", TaskStatus.ASSIGNED,
            (f, a) -> get("/api/tasks"));
    private static final Endpoint PUBLISH = new Endpoint("POST /api/tasks/{id}/publish", TaskStatus.DRAFT,
            (f, a) -> post("/api/tasks/{id}/publish", f.task().getId()).contentType(MediaType.APPLICATION_JSON)
                    .content("{\"scope\": \"EVERYONE\"}"));
    private static final Endpoint TAKE = new Endpoint("POST /api/tasks/{id}/take", TaskStatus.OPEN,
            (f, a) -> post("/api/tasks/{id}/take", f.task().getId()));
    private static final Endpoint REISSUE = new Endpoint("POST /api/tasks/{id}/reissue", TaskStatus.IN_PROGRESS,
            (f, a) -> post("/api/tasks/{id}/reissue", f.task().getId()));
    // The fixture's task is not a main task: a manager allowed past the role check gets 409 NOT_A_MAIN_TASK.
    private static final Endpoint ADD_SUB_TASK = new Endpoint("POST /api/tasks/{id}/sub-tasks",
            TaskStatus.ASSIGNED, (f, a) -> post("/api/tasks/{id}/sub-tasks", f.task().getId())
                    .contentType(MediaType.APPLICATION_JSON)
                    .content("{\"title\": \"T\", \"priority\": \"LOW\", \"dueDate\": \"2026-12-01T09:00:00Z\"}"));
    private static final Endpoint LIST_SUB_TASKS = new Endpoint("GET /api/tasks/{id}/sub-tasks", TaskStatus.ASSIGNED,
            (f, a) -> get("/api/tasks/{id}/sub-tasks", f.task().getId()));
    private static final Endpoint LIST_REQUIREMENTS = new Endpoint("GET /api/tasks/{id}/requirements",
            TaskStatus.ASSIGNED, (f, a) -> get("/api/tasks/{id}/requirements", f.task().getId()));
    private static final Endpoint EDIT_REQUIREMENT = new Endpoint("PUT /api/tasks/{id}/requirements/{rid}",
            TaskStatus.DRAFT, (f, a) -> put("/api/tasks/{t}/requirements/{r}", f.task().getId(),
                    f.requirement().getId()).contentType(MediaType.APPLICATION_JSON)
                    .content("{\"title\": \"Clean?\", \"type\": \"YES_NO\"}"));
    private static final Endpoint DELETE_REQUIREMENT = new Endpoint("DELETE /api/tasks/{id}/requirements/{rid}",
            TaskStatus.DRAFT, (f, a) -> delete("/api/tasks/{t}/requirements/{r}", f.task().getId(),
                    f.requirement().getId()));
    private static final Endpoint ORDER_REQUIREMENTS = new Endpoint("PUT /api/tasks/{id}/requirements/order",
            TaskStatus.DRAFT, (f, a) -> put("/api/tasks/{id}/requirements/order", f.task().getId())
                    .contentType(MediaType.APPLICATION_JSON)
                    .content("{\"requirementIds\": [\"" + f.requirement().getId() + "\"]}"));

    // Evidence, devices, sync, files and /me (task 9.3b).
    private static final Endpoint ME = new Endpoint("GET /api/auth/me", null, (f, a) -> get("/api/auth/me"));
    private static final Endpoint REGISTER_DEVICE = new Endpoint("PUT /api/devices", null,
            (f, a) -> put("/api/devices").contentType(MediaType.APPLICATION_JSON)
                    .content("{\"token\": \"phone-" + a.name() + "\", \"platform\": \"ANDROID\"}"));
    private static final Endpoint REMOVE_DEVICE = new Endpoint("DELETE /api/devices", null,
            (f, a) -> delete("/api/devices").contentType(MediaType.APPLICATION_JSON)
                    .content("{\"token\": \"phone-" + a.name() + "\"}"));
    private static final Endpoint SYNC_PULL = new Endpoint("GET /api/sync/pull", TaskStatus.ASSIGNED,
            (f, a) -> get("/api/sync/pull"));
    // The push itself answers 200 for any logged-in user; each operation is checked on its own (SyncPushTests).
    private static final Endpoint SYNC_PUSH = new Endpoint("POST /api/sync/push", TaskStatus.ASSIGNED,
            (f, a) -> post("/api/sync/push").contentType(MediaType.APPLICATION_JSON).content("""
                    {"operations": [{"id": "%s", "entityType": "Task", "entityId": "%s", "taskId": "%s",
                     "operation": "START", "payload": {"version": %d}}]}""".formatted(UUID.randomUUID(),
                    f.task().getId(), f.task().getId(), f.task().getVersion())));
    private static final Endpoint UNSIGNED_FILE_UPLOAD = new Endpoint("PUT /api/files/... without signature",
            null, (f, a) -> put("/api/files/tasks/x/photo.jpg").contentType(MediaType.IMAGE_JPEG)
                    .content(new byte[] {1}));
    private static final Endpoint UNSIGNED_FILE_DOWNLOAD = new Endpoint("GET /api/files/... without signature",
            null, (f, a) -> get("/api/files/tasks/x/photo.jpg"));
    private static final Endpoint LIST_EVIDENCE = new Endpoint("GET /api/tasks/{id}/evidence",
            TaskStatus.IN_PROGRESS, true, (f, a) -> get("/api/tasks/{id}/evidence", f.task().getId()));
    private static final Endpoint REGISTER_EVIDENCE = new Endpoint("POST .../requirements/{photo}/evidence",
            TaskStatus.IN_PROGRESS, true, (f, a) -> post("/api/tasks/{t}/requirements/{r}/evidence", f.task().getId(),
                    f.photo().getId()).contentType(MediaType.APPLICATION_JSON).content("""
                    {"id": "%s", "fileName": "fridge.jpg", "contentType": "image/jpeg", "sizeBytes": 1000}"""
                    .formatted(UUID.randomUUID())));
    private static final Endpoint UPLOAD_URL = new Endpoint("POST .../evidence/{pending}/upload-url",
            TaskStatus.IN_PROGRESS, true, (f, a) -> post("/api/tasks/{t}/evidence/{e}/upload-url", f.task().getId(),
                    f.pendingEvidence()));
    // Completing a file that is already uploaded answers 200 (safe to send again).
    private static final Endpoint COMPLETE_UPLOAD = new Endpoint("POST .../evidence/{uploaded}/complete",
            TaskStatus.IN_PROGRESS, true, (f, a) -> post("/api/tasks/{t}/evidence/{e}/complete", f.task().getId(),
                    f.uploadedEvidence()));
    private static final Endpoint DOWNLOAD_URL = new Endpoint("GET .../evidence/{uploaded}/download-url",
            TaskStatus.IN_PROGRESS, true, (f, a) -> get("/api/tasks/{t}/evidence/{e}/download-url", f.task().getId(),
                    f.uploadedEvidence()));
    private static final Endpoint DELETE_EVIDENCE = new Endpoint("DELETE .../evidence/{pending}",
            TaskStatus.IN_PROGRESS, true, (f, a) -> delete("/api/tasks/{t}/evidence/{e}", f.task().getId(),
                    f.pendingEvidence()));

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
                row(LIST_RESPONSES, 401, 200, 200, 200, 200, 404),
                row(LIST_TASKS, 401, 200, 200, 200, 200, 200),
                row(PUBLISH, 401, 403, 200, 403, 403, 403),
                row(TAKE, 401, 403, 403, 403, 200, 200),
                row(REISSUE, 401, 403, 201, 403, 403, 403),
                row(ADD_SUB_TASK, 401, 403, 409, 409, 403, 403),
                row(LIST_SUB_TASKS, 401, 200, 200, 200, 403, 403),
                row(LIST_REQUIREMENTS, 401, 200, 200, 200, 200, 404),
                row(EDIT_REQUIREMENT, 401, 403, 200, 403, 403, 403),
                row(DELETE_REQUIREMENT, 401, 403, 204, 403, 403, 403),
                row(ORDER_REQUIREMENTS, 401, 403, 200, 403, 403, 403),
                row(ME, 401, 200, 200, 200, 200, 200),
                row(REGISTER_DEVICE, 401, 204, 204, 204, 204, 204),
                row(REMOVE_DEVICE, 401, 204, 204, 204, 204, 204),
                row(SYNC_PULL, 401, 200, 200, 200, 200, 200),
                row(SYNC_PUSH, 401, 200, 200, 200, 200, 200),
                row(UNSIGNED_FILE_UPLOAD, 403, 403, 403, 403, 403, 403),
                row(UNSIGNED_FILE_DOWNLOAD, 403, 403, 403, 403, 403, 403),
                row(LIST_EVIDENCE, 401, 200, 200, 200, 200, 404),
                row(REGISTER_EVIDENCE, 401, 403, 403, 403, 201, 404),
                row(UPLOAD_URL, 401, 403, 403, 403, 200, 404),
                row(COMPLETE_UPLOAD, 401, 403, 403, 403, 200, 404),
                row(DOWNLOAD_URL, 401, 200, 200, 200, 200, 404),
                row(DELETE_EVIDENCE, 401, 403, 403, 403, 204, 404))
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

    @Autowired
    private JdbcTemplate jdbcTemplate;

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
        Fixture fixture = fixture(endpoint.taskStatus(), endpoint.withFiles());
        MockHttpServletRequestBuilder request = endpoint.request().apply(fixture, actor);
        if (actor != Actor.ANONYMOUS) {
            request.header("Authorization", "Bearer " + jwtService.issueAccessToken(users.get(actor)).value());
        }

        mockMvc.perform(request).andExpect(status().is(expectedStatus));
    }

    /** A task of the creator in the given status (with one requirement, and files if asked), or none. */
    private Fixture fixture(TaskStatus wanted, boolean withFiles) {
        if (wanted == null) {
            return new Fixture(users, null, null, null, null, null);
        }
        Task task = taskRepository.save(new Task(users.get(Actor.CREATOR), "Kitchen", null, TaskPriority.HIGH,
                Instant.parse("2026-12-01T09:00:00Z"), null));
        Requirement requirement = requirementRepository.save(new Requirement(task, "Ok?", null,
                RequirementType.YES_NO, true, 0, null, null));
        if (wanted == TaskStatus.OPEN) {
            stateMachine.apply(task, TaskAction.PUBLISH);
            TaskFixtures.openTo(task, OpenScope.EVERYONE);
            return new Fixture(users, taskRepository.save(task), requirement, null, null, null);
        }
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
        task = taskRepository.save(task);
        if (!withFiles) {
            return new Fixture(users, task, requirement, null, null, null);
        }
        Requirement photo = requirementRepository.save(new Requirement(task, "Photo", null, RequirementType.PHOTO,
                false, 1, null, null));
        return new Fixture(users, task, requirement, photo, evidence(task, photo, "PENDING"),
                evidence(task, photo, "UPLOADED"));
    }

    /** An evidence row of the photo requirement, saved without the API. */
    private UUID evidence(Task task, Requirement photo, String status) {
        UUID id = UUID.randomUUID();
        jdbcTemplate.update("""
                insert into evidence (id, task_id, requirement_id, uploaded_by, file_name, content_type, size_bytes,
                                      storage_key, status)
                values (?, ?, ?, ?, 'photo.jpg', 'image/jpeg', 1000, ?, ?)""", id, task.getId(), photo.getId(),
                users.get(Actor.ASSIGNED_WORKER).getId(), "tasks/" + task.getId() + "/" + id + ".jpg", status);
        return id;
    }

    private User save(String email, RoleName... roles) {
        return userRepository.save(new User(organizationRepository.getDefault(), email, "hash", email,
                Arrays.stream(roles).map(r -> roleRepository.findByName(r).orElseThrow()).collect(Collectors.toSet())));
    }

}
