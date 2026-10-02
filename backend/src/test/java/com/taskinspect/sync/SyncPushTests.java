package com.taskinspect.sync;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
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
import com.taskinspect.tasks.TaskStatus;
import com.taskinspect.tasks.TaskStatusChangeRepository;
import com.taskinspect.users.OrganizationRepository;
import com.taskinspect.users.RoleName;
import com.taskinspect.users.RoleRepository;
import com.taskinspect.users.User;
import com.taskinspect.users.UserRepository;
import java.time.Instant;
import java.util.Arrays;
import java.util.List;
import java.util.UUID;
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
class SyncPushTests {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private JwtService jwtService;

    @Autowired
    private TaskRepository taskRepository;

    @Autowired
    private TaskStateMachine stateMachine;

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

    @Autowired
    private JdbcTemplate jdbcTemplate;

    private User manager;
    private User worker;
    private Task task;
    private Requirement yesNo;
    private Requirement photo;

    @BeforeEach
    void setUp() {
        manager = save("manager@example.com", "Mia Manager", RoleName.MANAGER);
        worker = save("worker@example.com", "Wendy Worker", RoleName.WORKER);
        task = assignedTask("Kitchen");
        yesNo = requirementRepository.findAllByTaskIdOrderByPosition(task.getId()).get(0);
        photo = requirementRepository.findAllByTaskIdOrderByPosition(task.getId()).get(1);
    }

    @AfterEach
    void tearDown() {
        taskRepository.deleteAll();
        userRepository.deleteAll();
    }

    @Test
    void startsTheTaskAndSavesAnswerAndEvidenceInOrder() throws Exception {
        UUID evidenceId = UUID.randomUUID();
        push(worker, start(task), answer(task, yesNo, "{\"booleanValue\": true, \"comment\": \"All fine\"}"),
                evidence(task, photo, evidenceId))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.results.length()").value(3))
                .andExpect(jsonPath("$.results[*].status").value(org.hamcrest.Matchers.everyItem(
                        org.hamcrest.Matchers.is("APPLIED"))))
                .andExpect(jsonPath("$.results[0].code").doesNotExist());

        assertThat(taskRepository.findById(task.getId()).orElseThrow().getStatus()).isEqualTo(TaskStatus.IN_PROGRESS);
        mockMvc.perform(as(manager, get("/api/tasks/{t}/responses", task.getId())))
                .andExpect(jsonPath("$[0].booleanValue").value(true))
                .andExpect(jsonPath("$[0].comment").value("All fine"));
        mockMvc.perform(as(manager, get("/api/tasks/{t}/evidence", task.getId())))
                .andExpect(jsonPath("$[0].id").value(evidenceId.toString()));
        assertThat(count("sync_records")).isEqualTo(3);
    }

    @Test
    void sendingTheSamePushAgainAppliesNothingTwice() throws Exception {
        String[] operations = {start(task), answer(task, yesNo, "{\"booleanValue\": false}"),
                evidence(task, photo, UUID.randomUUID())};
        push(worker, operations).andExpect(status().isOk());

        // E.g. the answer to the first push was lost: the app sends it again.
        push(worker, operations)
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.results[*].status").value(org.hamcrest.Matchers.everyItem(
                        org.hamcrest.Matchers.is("APPLIED"))));

        assertThat(count("sync_records")).isEqualTo(3);
        assertThat(count("evidence")).isEqualTo(1);
        assertThat(count("task_status_history where task_id = '" + task.getId() + "' and to_status = 'IN_PROGRESS'"))
                .isEqualTo(1);
    }

    @Test
    void aRejectedOperationSkipsTheLaterOnesOfItsTaskOnly() throws Exception {
        Task other = assignedTask("Warehouse");
        Requirement otherYesNo = requirementRepository.findAllByTaskIdOrderByPosition(other.getId()).get(0);

        // The task isn't started yet, so the answer is refused.
        push(worker, answer(task, yesNo, "{\"booleanValue\": true}"), start(task), start(other),
                answer(other, otherYesNo, "{\"booleanValue\": true}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.results[0].status").value("REJECTED"))
                .andExpect(jsonPath("$.results[0].code").value("RESPONSES_LOCKED"))
                .andExpect(jsonPath("$.results[0].message").isNotEmpty())
                .andExpect(jsonPath("$.results[1].status").value("SKIPPED"))
                .andExpect(jsonPath("$.results[1].code").value("EARLIER_OPERATION_REJECTED"))
                .andExpect(jsonPath("$.results[2].status").value("APPLIED"))
                .andExpect(jsonPath("$.results[3].status").value("APPLIED"));

        assertThat(taskRepository.findById(task.getId()).orElseThrow().getStatus()).isEqualTo(TaskStatus.ASSIGNED);
        // Refused or skipped operations are not recorded, so they can be sent again later.
        assertThat(count("sync_records")).isEqualTo(2);
    }

    @Test
    void aRejectedOperationCanBeSentAgainLater() throws Exception {
        String answer = answer(task, yesNo, "{\"booleanValue\": true}");
        push(worker, answer).andExpect(jsonPath("$.results[0].status").value("REJECTED"));

        push(worker, start(task), answer)
                .andExpect(jsonPath("$.results[1].status").value("APPLIED"));
    }

    @Test
    void startBasedOnAnOldVersionOfTheTaskIsRejected() throws Exception {
        push(worker, operation(task.getId(), "Task", task.getId(), "START",
                "{\"version\": " + (task.getVersion() - 1) + "}"))
                .andExpect(jsonPath("$.results[0].status").value("REJECTED"))
                .andExpect(jsonPath("$.results[0].code").value("VERSION_CONFLICT"));

        assertThat(taskRepository.findById(task.getId()).orElseThrow().getStatus()).isEqualTo(TaskStatus.ASSIGNED);
    }

    @Test
    void invalidAnswersAndUnknownOperationsAreRejected() throws Exception {
        Task other = assignedTask("Warehouse");
        push(worker, start(task), answer(task, yesNo, "{\"textValue\": \"yes\"}"),
                operation(other.getId(), "Task", other.getId(), "APPROVE", "{}"))
                .andExpect(jsonPath("$.results[1].status").value("REJECTED"))
                .andExpect(jsonPath("$.results[1].code").value("INVALID_RESPONSE"))
                .andExpect(jsonPath("$.results[2].status").value("REJECTED"))
                .andExpect(jsonPath("$.results[2].code").value("UNSUPPORTED_OPERATION"));
    }

    @Test
    void evidenceWithAPayloadThatDoesNotMatchIsRejected() throws Exception {
        push(worker, start(task), operation(task.getId(), "Evidence", UUID.randomUUID(), "CREATE",
                "{\"requirementId\": \"%s\", \"id\": \"%s\", \"fileName\": \"a.jpg\", \"contentType\": \"image/jpeg\", "
                        .formatted(photo.getId(), UUID.randomUUID()) + "\"sizeBytes\": 1000}"))
                .andExpect(jsonPath("$.results[1].code").value("INVALID_PAYLOAD"));
        push(worker, operation(task.getId(), "Evidence", UUID.randomUUID(), "CREATE", "{\"sizeBytes\": -1}"))
                .andExpect(jsonPath("$.results[0].code").value("VALIDATION_ERROR"));
    }

    @Test
    void onlyTheAssignedWorkerCanSyncChangesOfATask() throws Exception {
        User otherWorker = save("other@example.com", "Otto Worker", RoleName.WORKER);

        push(otherWorker, start(task)).andExpect(jsonPath("$.results[0].status").value("REJECTED"));
        push(manager, start(task)).andExpect(jsonPath("$.results[0].code").value("FORBIDDEN"));

        assertThat(taskRepository.findById(task.getId()).orElseThrow().getStatus()).isEqualTo(TaskStatus.ASSIGNED);
    }

    @Test
    void aManagerSyncsStartAndSubmitOfTheirMainTaskOnly() throws Exception {
        User admin = save("admin@example.com", "Ada Admin", RoleName.ADMINISTRATOR);
        Task mainTask = new Task(admin, "Inspect building B", null, TaskPriority.HIGH,
                Instant.parse("2026-12-01T09:00:00Z"), null);
        TaskFixtures.assign(mainTask, manager);
        stateMachine.apply(mainTask, TaskAction.ASSIGN);
        mainTask = taskRepository.saveAndFlush(mainTask);
        Task floor = new Task(manager, "Floor 1", null, TaskPriority.HIGH, Instant.parse("2026-12-01T09:00:00Z"), null);
        TaskFixtures.makeSubTaskOf(floor, mainTask);
        TaskFixtures.assign(floor, worker);
        for (TaskAction action : List.of(TaskAction.ASSIGN, TaskAction.START, TaskAction.SUBMIT, TaskAction.APPROVE)) {
            stateMachine.apply(floor, action);
        }
        taskRepository.saveAndFlush(floor);

        push(manager, start(mainTask)).andExpect(jsonPath("$.results[0].status").value("APPLIED"));
        push(manager, operation(mainTask.getId(), "Task", mainTask.getId(), "SUBMIT", "{}"))
                .andExpect(jsonPath("$.results[0].status").value("APPLIED"));
        assertThat(taskRepository.findById(mainTask.getId()).orElseThrow().getStatus()).isEqualTo(TaskStatus.SUBMITTED);
        // Answers stay worker-only.
        push(manager, answer(task, yesNo, "{\"booleanValue\": true}")).andExpect(jsonPath("$.results[0].code").value("FORBIDDEN"));
    }

    @Test
    void aManagerCreatesAndEditsADraftMadeOffline() throws Exception {
        UUID id = UUID.randomUUID();
        String create = operation(id, "Task", id, "CREATE",
                "{\"title\": \"Boiler room\", \"priority\": \"HIGH\", \"dueDate\": \"2026-12-01T09:00:00Z\"}");

        push(manager, create).andExpect(jsonPath("$.results[0].status").value("APPLIED"));
        push(manager, create).andExpect(jsonPath("$.results[0].status").value("APPLIED"));
        // Sent again as a new operation (e.g. the app lost the answer): still one task.
        push(manager, operation(id, "Task", id, "CREATE",
                "{\"title\": \"Boiler room\", \"priority\": \"HIGH\", \"dueDate\": \"2026-12-01T09:00:00Z\"}"))
                .andExpect(jsonPath("$.results[0].status").value("APPLIED"));
        assertThat(historyRepository.findAllByTaskIdOrderByChangedAtAscIdAsc(id)).hasSize(1);
        Task draft = taskRepository.findById(id).orElseThrow();
        assertThat(draft.getStatus()).isEqualTo(TaskStatus.DRAFT);
        assertThat(draft.getTitle()).isEqualTo("Boiler room");
        assertThat(taskRepository.count()).isEqualTo(2);

        push(manager, operation(id, "Task", id, "UPDATE", "{\"title\": \"Boiler room 2\", \"priority\": \"LOW\", "
                + "\"dueDate\": \"2026-12-02T09:00:00Z\", \"version\": 0}"))
                .andExpect(jsonPath("$.results[0].status").value("APPLIED"));
        assertThat(taskRepository.findById(id).orElseThrow().getTitle()).isEqualTo("Boiler room 2");
        push(manager, operation(id, "Task", id, "UPDATE", "{\"title\": \"Old\", \"priority\": \"LOW\", "
                + "\"dueDate\": \"2026-12-02T09:00:00Z\", \"version\": 0}"))
                .andExpect(jsonPath("$.results[0].code").value("VERSION_CONFLICT"));
    }

    @Test
    void draftsFromTheAppAreManagersWorkAndIdsCannotBeTaken() throws Exception {
        UUID id = UUID.randomUUID();
        String body = "{\"title\": \"Boiler room\", \"priority\": \"HIGH\", \"dueDate\": \"2026-12-01T09:00:00Z\"}";

        push(worker, operation(id, "Task", id, "CREATE", body)).andExpect(jsonPath("$.results[0].code").value("FORBIDDEN"));
        push(manager, operation(task.getId(), "Task", task.getId(), "CREATE", body))
                .andExpect(jsonPath("$.results[0].status").value("APPLIED"));
        User otherManager = save("manager2@example.com", "Max Manager", RoleName.MANAGER);
        push(otherManager, operation(task.getId(), "Task", task.getId(), "CREATE", body))
                .andExpect(jsonPath("$.results[0].code").value("TASK_ID_CONFLICT"));
        push(manager, operation(id, "Task", UUID.randomUUID(), "CREATE", body))
                .andExpect(jsonPath("$.results[0].code").value("INVALID_PAYLOAD"));
        push(manager, operation(id, "Task", id, "CREATE", "{\"priority\": \"HIGH\"}"))
                .andExpect(jsonPath("$.results[0].code").value("VALIDATION_ERROR"));
    }

    @Test
    void aManagerEditsRequirementsOffline() throws Exception {
        UUID id = UUID.randomUUID();
        String body = "{\"title\": \"Fridge temperature\", \"type\": \"NUMBER\", \"unit\": \"°C\"}";

        push(manager, operation(task.getId(), "Requirement", id, "CREATE", body))
                .andExpect(jsonPath("$.results[0].status").value("APPLIED"));
        push(manager, operation(task.getId(), "Requirement", id, "CREATE", body))
                .andExpect(jsonPath("$.results[0].status").value("APPLIED"));
        assertThat(requirementRepository.findAllByTaskIdOrderByPosition(task.getId()))
                .extracting(Requirement::getId).containsExactly(yesNo.getId(), photo.getId(), id);

        push(manager, operation(task.getId(), "Requirement", id, "UPDATE",
                "{\"title\": \"Freezer temperature\", \"type\": \"NUMBER\", \"unit\": \"°C\"}"))
                .andExpect(jsonPath("$.results[0].status").value("APPLIED"));
        push(manager, operation(task.getId(), "RequirementOrder", task.getId(), "UPDATE",
                "{\"requirementIds\": [\"%s\", \"%s\", \"%s\"]}".formatted(id, photo.getId(), yesNo.getId())))
                .andExpect(jsonPath("$.results[0].status").value("APPLIED"));
        assertThat(requirementRepository.findAllByTaskIdOrderByPosition(task.getId()))
                .extracting(Requirement::getTitle).first().isEqualTo("Freezer temperature");

        push(manager, operation(task.getId(), "Requirement", photo.getId(), "DELETE", "{}"))
                .andExpect(jsonPath("$.results[0].status").value("APPLIED"));
        assertThat(requirementRepository.findAllByTaskIdOrderByPosition(task.getId()))
                .extracting(Requirement::getId).containsExactly(id, yesNo.getId());
    }

    @Test
    void requirementChangesAreManagersWorkAndOrdersMustBeComplete() throws Exception {
        UUID id = UUID.randomUUID();
        push(worker, operation(task.getId(), "Requirement", id, "CREATE", "{\"title\": \"A\", \"type\": \"TEXT\"}"))
                .andExpect(jsonPath("$.results[0].code").value("FORBIDDEN"));
        push(manager, operation(task.getId(), "RequirementOrder", task.getId(), "UPDATE",
                "{\"requirementIds\": [\"%s\"]}".formatted(yesNo.getId())))
                .andExpect(jsonPath("$.results[0].code").value("INVALID_ORDER"));

        // The ID of another task's requirement can't be taken.
        Task other = assignedTask("Hall");
        Requirement othersRequirement = requirementRepository.findAllByTaskIdOrderByPosition(other.getId()).get(0);
        push(manager, operation(task.getId(), "Requirement", othersRequirement.getId(), "CREATE",
                "{\"title\": \"A\", \"type\": \"TEXT\"}"))
                .andExpect(jsonPath("$.results[0].code").value("REQUIREMENT_ID_CONFLICT"));
        // Deleting one the server never got counts as done, so later changes go on.
        push(manager, operation(task.getId(), "Requirement", UUID.randomUUID(), "DELETE", "{}"))
                .andExpect(jsonPath("$.results[0].status").value("APPLIED"));

        mockMvc.perform(as(manager, put("/api/tasks/{id}/requirements/order", task.getId()))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"requirementIds\": [\"%s\", \"%s\"]}".formatted(photo.getId(), yesNo.getId())))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[0].id").value(photo.getId().toString()))
                .andExpect(jsonPath("$[1].position").value(1));
        mockMvc.perform(as(worker, put("/api/tasks/{id}/requirements/order", task.getId()))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"requirementIds\": []}"))
                .andExpect(status().isForbidden());
    }

    @Test
    void anOperationIdOfAnotherUserIsRefused() throws Exception {
        String operation = start(task);
        push(worker, operation).andExpect(jsonPath("$.results[0].status").value("APPLIED"));
        User otherWorker = save("other@example.com", "Otto Worker", RoleName.WORKER);

        push(otherWorker, operation).andExpect(jsonPath("$.results[0].code").value("OPERATION_ID_CONFLICT"));
    }

    @Test
    void malformedPushesAndMissingLoginsAreRefused() throws Exception {
        mockMvc.perform(as(worker, post("/api/sync/push")).contentType(MediaType.APPLICATION_JSON)
                        .content("{\"operations\": [{\"entityType\": \"Task\"}]}"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("VALIDATION_ERROR"));
        mockMvc.perform(as(worker, post("/api/sync/push")).contentType(MediaType.APPLICATION_JSON)
                        .content("{\"operations\": []}"))
                .andExpect(status().isBadRequest());
        mockMvc.perform(post("/api/sync/push").contentType(MediaType.APPLICATION_JSON)
                        .content("{\"operations\": [" + start(task) + "]}"))
                .andExpect(status().isUnauthorized());
    }

    private ResultActions push(User user, String... operations) throws Exception {
        return mockMvc.perform(as(user, post("/api/sync/push")).contentType(MediaType.APPLICATION_JSON)
                .content("{\"operations\": [" + String.join(", ", operations) + "]}"));
    }

    private String start(Task target) {
        return operation(target.getId(), "Task", target.getId(), "START", "{\"version\": " + target.getVersion() + "}");
    }

    private String answer(Task target, Requirement requirement, String payload) {
        return operation(target.getId(), "TaskResponse", requirement.getId(), "UPDATE", payload);
    }

    private String evidence(Task target, Requirement requirement, UUID id) {
        return operation(target.getId(), "Evidence", id, "CREATE", """
                {"requirementId": "%s", "id": "%s", "fileName": "fridge.jpg", "contentType": "image/jpeg",
                 "sizeBytes": 245000}""".formatted(requirement.getId(), id));
    }

    private static String operation(UUID taskId, String entityType, UUID entityId, String operation, String payload) {
        return """
                {"id": "%s", "entityType": "%s", "entityId": "%s", "taskId": "%s", "operation": "%s",
                 "payload": %s}""".formatted(UUID.randomUUID(), entityType, entityId, taskId, operation, payload);
    }

    /** An ASSIGNED task of the manager for the worker, with a YES_NO and a PHOTO requirement. */
    private Task assignedTask(String title) {
        Task created = taskRepository.save(new Task(manager, title, null, TaskPriority.HIGH,
                Instant.parse("2026-12-01T09:00:00Z"), null));
        requirementRepository.save(new Requirement(created, "Ok?", null, RequirementType.YES_NO, true, 0, null, null));
        requirementRepository.save(new Requirement(created, "Photo", null, RequirementType.PHOTO, true, 1, null,
                null));
        TaskFixtures.assign(created, worker);
        stateMachine.apply(created, TaskAction.ASSIGN);
        return taskRepository.save(created);
    }

    private int count(String tableAndCondition) {
        return jdbcTemplate.queryForObject("select count(*) from " + tableAndCondition, Integer.class);
    }

    private MockHttpServletRequestBuilder as(User user, MockHttpServletRequestBuilder request) {
        return request.header("Authorization", "Bearer " + jwtService.issueAccessToken(user).value());
    }

    private User save(String email, String name, RoleName... roles) {
        return userRepository.save(new User(organizationRepository.getDefault(), email, "hash", name,
                Arrays.stream(roles).map(r -> roleRepository.findByName(r).orElseThrow()).collect(Collectors.toSet())));
    }

}
