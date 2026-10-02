package com.taskinspect.reviews;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
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
import com.taskinspect.tasks.TaskStatusChange;
import com.taskinspect.tasks.TaskStatusChangeRepository;
import com.taskinspect.users.OrganizationRepository;
import com.taskinspect.users.RoleName;
import com.taskinspect.users.RoleRepository;
import com.taskinspect.users.User;
import com.taskinspect.users.UserRepository;
import java.net.URI;
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
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.ResultActions;
import org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder;

/** Correction and resubmit (task 7.3): only marked requirements change; reviews reach the app. */
@Import(TestcontainersConfiguration.class)
@SpringBootTest
@AutoConfigureMockMvc
class CorrectionFlowTests {

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
    private TaskStatusChangeRepository historyRepository;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private RoleRepository roleRepository;

    @Autowired
    private OrganizationRepository organizationRepository;

    private User manager;
    private User worker;
    private Task task;
    private Requirement yesNo;
    private Requirement photo;
    private UUID firstPhoto;

    /** The worker answered, uploaded a photo and submitted. */
    @BeforeEach
    void setUp() throws Exception {
        manager = save("manager@example.com", "Mia Manager", RoleName.MANAGER);
        worker = save("worker@example.com", "Wendy Worker", RoleName.WORKER);
        Task created = taskRepository.save(new Task(manager, "Kitchen", null, TaskPriority.HIGH,
                Instant.parse("2026-12-01T09:00:00Z"), null));
        yesNo = requirementRepository.save(new Requirement(created, "Clean?", null, RequirementType.YES_NO, true, 0,
                null, null));
        photo = requirementRepository.save(new Requirement(created, "Photo of the fridge", null, RequirementType.PHOTO,
                true, 1, null, null));
        TaskFixtures.assign(created, worker);
        stateMachine.apply(created, TaskAction.ASSIGN);
        stateMachine.apply(created, TaskAction.START);
        task = taskRepository.save(created);
        answer(yesNo, true).andExpect(status().isOk());
        firstPhoto = uploadPhoto();
        submit().andExpect(status().isOk());
    }

    @AfterEach
    void tearDown() {
        taskRepository.deleteAll();
        userRepository.deleteAll();
    }

    @Test
    void afterACorrectionRequestOnlyTheMarkedRequirementsChangeThenTheTaskIsResubmitted() throws Exception {
        requestPhotoCorrection();
        start().andExpect(status().isOk());

        answer(yesNo, false)
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.code").value("REQUIREMENT_NOT_MARKED"));

        mockMvc.perform(as(worker, delete("/api/tasks/{t}/evidence/{e}", task.getId(), firstPhoto)))
                .andExpect(status().isNoContent());
        uploadPhoto();
        submit().andExpect(status().isOk()).andExpect(jsonPath("$.status").value("SUBMITTED"));

        List<TaskStatusChange> history = historyRepository.findAllByTaskIdOrderByChangedAtAscIdAsc(task.getId());
        assertThat(history.get(history.size() - 1).getReason()).isEqualTo("Resubmitted");
    }

    @Test
    void aSecondCorrectionRequestReplacesTheMarksOfTheFirst() throws Exception {
        requestPhotoCorrection();
        start().andExpect(status().isOk());
        submit().andExpect(status().isOk());
        mockMvc.perform(as(manager, post("/api/tasks/{id}/request-correction", task.getId()))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"requirements\": [{\"requirementId\": \"" + yesNo.getId()
                                + "\", \"comment\": \"Look again\"}]}"))
                .andExpect(status().isOk());
        start().andExpect(status().isOk());

        answer(yesNo, false).andExpect(status().isOk());
        mockMvc.perform(as(worker, delete("/api/tasks/{t}/evidence/{e}", task.getId(), firstPhoto)))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.code").value("REQUIREMENT_NOT_MARKED"));
        mockMvc.perform(as(worker, get("/api/sync/pull")))
                .andExpect(jsonPath("$.tasks[0].latestReview.requirements[0].requirementId")
                        .value(yesNo.getId().toString()));
    }

    @Test
    void aRejectAfterACorrectionMakesEverythingChangeableAgain() throws Exception {
        requestPhotoCorrection();
        start().andExpect(status().isOk());
        submit().andExpect(status().isOk());
        mockMvc.perform(as(manager, post("/api/tasks/{id}/reject", task.getId()))
                        .contentType(MediaType.APPLICATION_JSON).content("{\"reason\": \"Start over\"}"))
                .andExpect(status().isOk());
        start().andExpect(status().isOk());

        answer(yesNo, false).andExpect(status().isOk());
    }

    @Test
    void afterARejectEveryRequirementCanChange() throws Exception {
        mockMvc.perform(as(manager, post("/api/tasks/{id}/reject", task.getId()))
                        .contentType(MediaType.APPLICATION_JSON).content("{\"reason\": \"Wrong kitchen\"}"))
                .andExpect(status().isOk());
        start().andExpect(status().isOk());

        answer(yesNo, false).andExpect(status().isOk());
        mockMvc.perform(as(worker, delete("/api/tasks/{t}/evidence/{e}", task.getId(), firstPhoto)))
                .andExpect(status().isNoContent());
    }

    @Test
    void anUnmarkedRequirementsFileCannotBeRemovedOrAddedWhileCorrecting() throws Exception {
        Requirement document = requirementRepository.save(new Requirement(taskRepository.findById(task.getId())
                .orElseThrow(), "Report", null, RequirementType.DOCUMENT, false, 2, null, null));
        mockMvc.perform(as(manager, post("/api/tasks/{id}/request-correction", task.getId()))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"requirements\": [{\"requirementId\": \"" + yesNo.getId()
                                + "\", \"comment\": \"Look again\"}]}"))
                .andExpect(status().isOk());
        start().andExpect(status().isOk());

        mockMvc.perform(as(worker, delete("/api/tasks/{t}/evidence/{e}", task.getId(), firstPhoto)))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.code").value("REQUIREMENT_NOT_MARKED"));
        register(document, UUID.randomUUID(), "application/pdf", 5)
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.code").value("REQUIREMENT_NOT_MARKED"));
        answer(yesNo, false).andExpect(status().isOk());
    }

    @Test
    void theSyncPullBringsTheLatestReviewAndThePushRespectsTheCorrection() throws Exception {
        requestPhotoCorrection();

        mockMvc.perform(as(worker, get("/api/sync/pull")))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.tasks[0].task.status").value("CORRECTION_REQUESTED"))
                .andExpect(jsonPath("$.tasks[0].latestReview.result").value("CORRECTION_REQUESTED"))
                .andExpect(jsonPath("$.tasks[0].latestReview.reason").value("Almost"))
                .andExpect(jsonPath("$.tasks[0].latestReview.requirements[0].requirementId")
                        .value(photo.getId().toString()))
                .andExpect(jsonPath("$.tasks[0].latestReview.requirements[0].comment")
                        .value("Please retake the refrigerator photo."));

        start().andExpect(status().isOk());
        mockMvc.perform(as(worker, post("/api/sync/push")).contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"operations": [{"id": "%s", "entityType": "TaskResponse", "entityId": "%s",
                                 "taskId": "%s", "operation": "UPDATE", "payload": {"booleanValue": false}}]}"""
                                .formatted(UUID.randomUUID(), yesNo.getId(), task.getId())))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.results[0].status").value("REJECTED"))
                .andExpect(jsonPath("$.results[0].code").value("REQUIREMENT_NOT_MARKED"));
    }

    @Test
    void aTaskWithoutReviewsHasNoLatestReviewInThePull() throws Exception {
        mockMvc.perform(as(worker, get("/api/sync/pull")))
                .andExpect(jsonPath("$.tasks[0].task.status").value("SUBMITTED"))
                .andExpect(jsonPath("$.tasks[0].latestReview").doesNotExist());
    }

    private void requestPhotoCorrection() throws Exception {
        mockMvc.perform(as(manager, post("/api/tasks/{id}/request-correction", task.getId()))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"reason": "Almost", "requirements": [
                                  {"requirementId": "%s", "comment": "Please retake the refrigerator photo."}]}"""
                                .formatted(photo.getId())))
                .andExpect(status().isOk());
    }

    private UUID uploadPhoto() throws Exception {
        UUID id = UUID.randomUUID();
        byte[] file = {1, 2, 3, 4};
        register(photo, id, "image/jpeg", file.length).andExpect(status().isCreated());
        String upload = mockMvc.perform(as(worker, post("/api/tasks/{t}/evidence/{e}/upload-url", task.getId(), id)))
                .andExpect(status().isOk())
                .andReturn().getResponse().getContentAsString();
        mockMvc.perform(put(URI.create(JsonPath.read(upload, "$.url"))).contentType("image/jpeg").content(file))
                .andExpect(status().isOk());
        mockMvc.perform(as(worker, post("/api/tasks/{t}/evidence/{e}/complete", task.getId(), id)))
                .andExpect(status().isOk());
        return id;
    }

    private ResultActions register(Requirement requirement, UUID id, String type, long size) throws Exception {
        return mockMvc.perform(as(worker, post("/api/tasks/{t}/requirements/{r}/evidence", task.getId(),
                        requirement.getId()))
                .contentType(MediaType.APPLICATION_JSON)
                .content("""
                        {"id": "%s", "fileName": "file", "contentType": "%s", "sizeBytes": %d}"""
                        .formatted(id, type, size)));
    }

    private ResultActions answer(Requirement requirement, boolean value) throws Exception {
        return mockMvc.perform(as(worker, put("/api/tasks/{t}/requirements/{r}/response", task.getId(),
                        requirement.getId()))
                .contentType(MediaType.APPLICATION_JSON)
                .content("{\"booleanValue\": " + value + "}"));
    }

    private ResultActions start() throws Exception {
        return mockMvc.perform(as(worker, post("/api/tasks/{id}/start", task.getId())));
    }

    private ResultActions submit() throws Exception {
        return mockMvc.perform(as(worker, post("/api/tasks/{id}/submit", task.getId())));
    }

    private MockHttpServletRequestBuilder as(User user, MockHttpServletRequestBuilder request) {
        return request.header("Authorization", "Bearer " + jwtService.issueAccessToken(user).value());
    }

    private User save(String email, String name, RoleName... roles) {
        return userRepository.save(new User(organizationRepository.getDefault(), email, "hash", name,
                Arrays.stream(roles).map(r -> roleRepository.findByName(r).orElseThrow()).collect(Collectors.toSet())));
    }

}
