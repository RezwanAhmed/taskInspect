package com.taskinspect.reviews;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.jayway.jsonpath.JsonPath;
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
import java.net.URI;
import java.time.Instant;
import java.util.Arrays;
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
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.ResultActions;
import org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder;

/** POST /api/tasks/{id}/submit and Task SUBMIT through the sync push (task 7.1). */
@Import(TestcontainersConfiguration.class)
@SpringBootTest
@AutoConfigureMockMvc
class SubmitTaskTests {

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

    private User manager;
    private User worker;
    private User otherWorker;
    private Task task;
    private Requirement yesNo;
    private Requirement photo;
    private Requirement optionalText;

    @BeforeEach
    void setUp() {
        manager = save("manager@example.com", "Mia Manager", RoleName.MANAGER);
        worker = save("worker@example.com", "Wendy Worker", RoleName.WORKER);
        otherWorker = save("worker2@example.com", "Will Worker", RoleName.WORKER);
        Task created = taskRepository.save(new Task(manager, "Kitchen", null, TaskPriority.HIGH,
                Instant.parse("2026-12-01T09:00:00Z"), null));
        yesNo = requirementRepository.save(new Requirement(created, "Clean?", null, RequirementType.YES_NO, true, 0,
                null, null));
        photo = requirementRepository.save(new Requirement(created, "Photo of the fridge", null, RequirementType.PHOTO,
                true, 1, null, null));
        optionalText = requirementRepository.save(new Requirement(created, "Notes", null, RequirementType.TEXT, false,
                2, null, null));
        TaskFixtures.assign(created, worker);
        stateMachine.apply(created, TaskAction.ASSIGN);
        stateMachine.apply(created, TaskAction.START);
        task = taskRepository.save(created);
    }

    @AfterEach
    void tearDown() {
        taskRepository.deleteAll();
        userRepository.deleteAll();
    }

    @Test
    void completeTaskIsSubmittedAndItsAnswersAreLocked() throws Exception {
        answer(yesNo, "{\"booleanValue\": true}").andExpect(status().isOk());
        uploadPhoto();

        submit(worker)
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("SUBMITTED"));

        answer(yesNo, "{\"booleanValue\": false}")
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.code").value("RESPONSES_LOCKED"));
    }

    @Test
    void missingRequiredAnswersAndPhotosAreListed() throws Exception {
        submit(worker)
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.code").value("REQUIREMENTS_MISSING"))
                .andExpect(jsonPath("$.errors.length()").value(2))
                .andExpect(jsonPath("$.errors[0].field").value(yesNo.getId().toString()))
                .andExpect(jsonPath("$.errors[0].message").value("Clean?: an answer is required"))
                .andExpect(jsonPath("$.errors[1].field").value(photo.getId().toString()))
                .andExpect(jsonPath("$.errors[1].message").value("Photo of the fridge: a photo is required"));

        answer(yesNo, "{\"booleanValue\": false}").andExpect(status().isOk());
        submit(worker)
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.errors.length()").value(1))
                .andExpect(jsonPath("$.errors[0].field").value(photo.getId().toString()));
    }

    @Test
    void aFileStillWaitingForItsUploadBlocksTheSubmit() throws Exception {
        answer(yesNo, "{\"booleanValue\": true}").andExpect(status().isOk());
        uploadPhoto();
        register(UUID.randomUUID(), 3).andExpect(status().isCreated());

        submit(worker)
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.code").value("EVIDENCE_NOT_UPLOADED"))
                .andExpect(jsonPath("$.message").value("1 file is not uploaded yet"));
    }

    @Test
    void onlyAnInProgressTaskOfTheAssignedWorkerCanBeSubmitted() throws Exception {
        answer(yesNo, "{\"booleanValue\": true}").andExpect(status().isOk());
        uploadPhoto();

        submit(otherWorker).andExpect(status().isNotFound());
        submit(manager).andExpect(status().isForbidden());

        submit(worker).andExpect(status().isOk());
        submit(worker)
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.code").value("TASK_INVALID_TRANSITION"));
    }

    @Test
    void aCancelledTaskCannotBeSubmitted() throws Exception {
        answer(yesNo, "{\"booleanValue\": true}").andExpect(status().isOk());
        uploadPhoto();
        stateMachine.apply(task, TaskAction.CANCEL);
        task = taskRepository.save(task);

        submit(worker)
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.code").value("TASK_ALREADY_CANCELLED"));
    }

    @Test
    void afterARejectTheWorkerStartsAgainAndResubmits() throws Exception {
        answer(yesNo, "{\"booleanValue\": true}").andExpect(status().isOk());
        uploadPhoto();
        submit(worker).andExpect(status().isOk());
        task = taskRepository.findById(task.getId()).orElseThrow();
        stateMachine.apply(task, TaskAction.REJECT);
        task = taskRepository.save(task);

        submit(worker)
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.code").value("TASK_INVALID_TRANSITION"));
        mockMvc.perform(as(worker, post("/api/tasks/{id}/start", task.getId()))).andExpect(status().isOk());
        submit(worker).andExpect(status().isOk()).andExpect(jsonPath("$.status").value("SUBMITTED"));
    }

    @Test
    void submitWorksThroughTheSyncPushAndIsAppliedOnce() throws Exception {
        answer(yesNo, "{\"booleanValue\": true}").andExpect(status().isOk());
        uploadPhoto();
        String operation = """
                {"id": "%s", "entityType": "Task", "entityId": "%s", "taskId": "%s", "operation": "SUBMIT",
                 "payload": {"version": 0}}""".formatted(UUID.randomUUID(), task.getId(), task.getId());

        push(operation)
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.results[0].status").value("APPLIED"));
        push(operation)
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.results[0].status").value("APPLIED"));

        mockMvc.perform(as(worker, get("/api/tasks/{id}", task.getId())))
                .andExpect(jsonPath("$.status").value("SUBMITTED"));
    }

    @Test
    void anIncompleteSubmitThroughTheSyncPushIsRejectedWithTheReason() throws Exception {
        push("""
                {"id": "%s", "entityType": "Task", "entityId": "%s", "taskId": "%s", "operation": "SUBMIT"}"""
                .formatted(UUID.randomUUID(), task.getId(), task.getId()))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.results[0].status").value("REJECTED"))
                .andExpect(jsonPath("$.results[0].code").value("REQUIREMENTS_MISSING"));
    }

    private void uploadPhoto() throws Exception {
        UUID id = UUID.randomUUID();
        byte[] file = {1, 2, 3, 4};
        register(id, file.length).andExpect(status().isCreated());
        String upload = mockMvc.perform(as(worker, post("/api/tasks/{t}/evidence/{e}/upload-url", task.getId(), id)))
                .andExpect(status().isOk())
                .andReturn().getResponse().getContentAsString();
        mockMvc.perform(put(URI.create(JsonPath.read(upload, "$.url"))).contentType("image/jpeg").content(file))
                .andExpect(status().isOk());
        mockMvc.perform(as(worker, post("/api/tasks/{t}/evidence/{e}/complete", task.getId(), id)))
                .andExpect(status().isOk());
    }

    private ResultActions register(UUID id, long size) throws Exception {
        return mockMvc.perform(as(worker, post("/api/tasks/{t}/requirements/{r}/evidence", task.getId(),
                        photo.getId()))
                .contentType(MediaType.APPLICATION_JSON)
                .content("""
                        {"id": "%s", "fileName": "fridge.jpg", "contentType": "image/jpeg", "sizeBytes": %d}"""
                        .formatted(id, size)));
    }

    private ResultActions answer(Requirement requirement, String body) throws Exception {
        return mockMvc.perform(as(worker, put("/api/tasks/{t}/requirements/{r}/response", task.getId(),
                        requirement.getId()))
                .contentType(MediaType.APPLICATION_JSON)
                .content(body));
    }

    private ResultActions submit(User user) throws Exception {
        return mockMvc.perform(as(user, post("/api/tasks/{id}/submit", task.getId())));
    }

    private ResultActions push(String operation) throws Exception {
        return mockMvc.perform(as(worker, post("/api/sync/push")).contentType(MediaType.APPLICATION_JSON)
                .content("{\"operations\": [" + operation + "]}"));
    }

    private MockHttpServletRequestBuilder as(User user, MockHttpServletRequestBuilder request) {
        return request.header("Authorization", "Bearer " + jwtService.issueAccessToken(user).value());
    }

    private User save(String email, String name, RoleName... roles) {
        return userRepository.save(new User(organizationRepository.getDefault(), email, "hash", name,
                Arrays.stream(roles).map(r -> roleRepository.findByName(r).orElseThrow()).collect(Collectors.toSet())));
    }

}
