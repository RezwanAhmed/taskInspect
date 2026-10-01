package com.taskinspect.evidence;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.content;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.header;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.taskinspect.TestcontainersConfiguration;
import com.taskinspect.auth.JwtService;
import com.taskinspect.filestorage.FileStorage;
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
import com.jayway.jsonpath.JsonPath;
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

/** Runs without a test transaction, like real requests. */
@Import(TestcontainersConfiguration.class)
@SpringBootTest
@AutoConfigureMockMvc
class EvidenceApiTests {

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
    private FileStorage fileStorage;

    private User manager;
    private User worker;
    private Task task;
    private Requirement photo;
    private Requirement document;
    private Requirement yesNo;

    @BeforeEach
    void setUp() {
        manager = save("manager@example.com", "Mia Manager", RoleName.MANAGER);
        worker = save("worker@example.com", "Wendy Worker", RoleName.WORKER);
        Task created = taskRepository.save(new Task(manager, "Kitchen", null, TaskPriority.HIGH,
                Instant.parse("2026-12-01T09:00:00Z"), null));
        photo = requirement(created, "Photo of the fridge", RequirementType.PHOTO, 0);
        document = requirement(created, "Service report", RequirementType.DOCUMENT, 1);
        yesNo = requirement(created, "Ok?", RequirementType.YES_NO, 2);
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
    void workerRegistersAPhotoAndTheManagerSeesIt() throws Exception {
        UUID id = UUID.randomUUID();
        register(photo, id, "fridge.jpg", "image/jpeg", 245_000)
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.id").value(id.toString()))
                .andExpect(jsonPath("$.status").value("PENDING"))
                .andExpect(jsonPath("$.sizeBytes").value(245_000));

        mockMvc.perform(as(manager, get("/api/tasks/{t}/evidence", task.getId())))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.length()").value(1))
                .andExpect(jsonPath("$[0].requirementId").value(photo.getId().toString()))
                .andExpect(jsonPath("$[0].fileName").value("fridge.jpg"));
    }

    @Test
    void sendingTheSameRegistrationAgainIsHarmless() throws Exception {
        UUID id = UUID.randomUUID();
        register(photo, id, "fridge.jpg", "image/jpeg", 1000).andExpect(status().isCreated());

        register(photo, id, "fridge.jpg", "image/jpeg", 1000)
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.id").value(id.toString()));

        mockMvc.perform(as(worker, get("/api/tasks/{t}/evidence", task.getId())))
                .andExpect(jsonPath("$.length()").value(1));
    }

    @Test
    void theSameIdCannotBeUsedForAnotherRequirement() throws Exception {
        UUID id = UUID.randomUUID();
        register(photo, id, "fridge.jpg", "image/jpeg", 1000).andExpect(status().isCreated());

        register(document, id, "report.pdf", "application/pdf", 1000)
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.code").value("EVIDENCE_ID_CONFLICT"));
    }

    @Test
    void pdfDocumentsAreAccepted() throws Exception {
        register(document, UUID.randomUUID(), "report.pdf", "application/pdf", 2_000_000)
                .andExpect(status().isCreated());
    }

    @Test
    void wrongTypesAndTooLargeFilesAreRejected() throws Exception {
        register(photo, UUID.randomUUID(), "report.pdf", "application/pdf", 1000)
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("INVALID_EVIDENCE_TYPE"));
        register(document, UUID.randomUUID(), "x.jpg", "image/jpeg", 1000)
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("INVALID_EVIDENCE_TYPE"));
        register(yesNo, UUID.randomUUID(), "x.jpg", "image/jpeg", 1000)
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("INVALID_EVIDENCE_TYPE"));
        register(photo, UUID.randomUUID(), "huge.jpg", "image/jpeg", 11L * 1024 * 1024)
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("FILE_TOO_LARGE"));
        register(photo, null, "", "image/jpeg", 0)
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("VALIDATION_ERROR"));
    }

    @Test
    void onlyTheAssignedWorkerWhileInProgress() throws Exception {
        User other = save("worker2@example.com", "Will Worker", RoleName.WORKER);
        mockMvc.perform(as(other, post("/api/tasks/{t}/requirements/{r}/evidence", task.getId(), photo.getId()))
                        .contentType(MediaType.APPLICATION_JSON).content(body(UUID.randomUUID(), "a.jpg", "image/jpeg", 1)))
                .andExpect(status().isNotFound());
        mockMvc.perform(as(manager, post("/api/tasks/{t}/requirements/{r}/evidence", task.getId(), photo.getId()))
                        .contentType(MediaType.APPLICATION_JSON).content(body(UUID.randomUUID(), "a.jpg", "image/jpeg", 1)))
                .andExpect(status().isForbidden());

        stateMachine.apply(task, TaskAction.SUBMIT);
        task = taskRepository.save(task);

        register(photo, UUID.randomUUID(), "late.jpg", "image/jpeg", 1000)
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.code").value("EVIDENCE_LOCKED"));
    }

    @Test
    void workerRemovesEvidence() throws Exception {
        UUID id = UUID.randomUUID();
        register(photo, id, "fridge.jpg", "image/jpeg", 1000).andExpect(status().isCreated());

        mockMvc.perform(as(worker, delete("/api/tasks/{t}/evidence/{e}", task.getId(), id)))
                .andExpect(status().isNoContent());
        mockMvc.perform(as(worker, delete("/api/tasks/{t}/evidence/{e}", task.getId(), id)))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.code").value("EVIDENCE_NOT_FOUND"));
        mockMvc.perform(as(worker, get("/api/tasks/{t}/evidence", task.getId())))
                .andExpect(jsonPath("$.length()").value(0));
    }

    @Test
    void fileIsUploadedConfirmedAndDownloaded() throws Exception {
        UUID id = UUID.randomUUID();
        byte[] file = "%PDF-1.7 fake report".getBytes();
        register(document, id, "report.pdf", "application/pdf", file.length).andExpect(status().isCreated());

        String upload = mockMvc.perform(as(worker, post("/api/tasks/{t}/evidence/{e}/upload-url", task.getId(), id)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.method").value("PUT"))
                .andExpect(jsonPath("$.headers.Content-Type").value("application/pdf"))
                .andReturn().getResponse().getContentAsString();
        String uploadUrl = JsonPath.read(upload, "$.url");

        mockMvc.perform(as(worker, post("/api/tasks/{t}/evidence/{e}/complete", task.getId(), id)))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.code").value("UPLOAD_INCOMPLETE"));

        // No Authorization header: the signed URL is the permission
        mockMvc.perform(put(URI.create(uploadUrl)).contentType("application/pdf").content(file))
                .andExpect(status().isOk());

        mockMvc.perform(as(worker, post("/api/tasks/{t}/evidence/{e}/complete", task.getId(), id)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("UPLOADED"))
                .andExpect(jsonPath("$.uploadedAt").isNotEmpty());
        mockMvc.perform(as(worker, post("/api/tasks/{t}/evidence/{e}/complete", task.getId(), id)))
                .andExpect(status().isOk());
        mockMvc.perform(as(worker, post("/api/tasks/{t}/evidence/{e}/upload-url", task.getId(), id)))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.code").value("EVIDENCE_ALREADY_UPLOADED"));

        String download = mockMvc.perform(as(manager,
                        get("/api/tasks/{t}/evidence/{e}/download-url", task.getId(), id)))
                .andExpect(status().isOk())
                .andReturn().getResponse().getContentAsString();
        mockMvc.perform(get(URI.create(JsonPath.read(download, "$.url"))))
                .andExpect(status().isOk())
                .andExpect(header().string("Content-Type", "application/pdf"))
                .andExpect(content().bytes(file));
    }

    @Test
    void signedUrlsCannotBeMisused() throws Exception {
        UUID id = UUID.randomUUID();
        register(photo, id, "fridge.jpg", "image/jpeg", 10).andExpect(status().isCreated());
        String upload = mockMvc.perform(as(worker, post("/api/tasks/{t}/evidence/{e}/upload-url", task.getId(), id)))
                .andReturn().getResponse().getContentAsString();
        String uploadUrl = JsonPath.read(upload, "$.url");

        mockMvc.perform(put(URI.create(uploadUrl)).contentType("image/png").content(new byte[10]))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.code").value("INVALID_SIGNATURE"));
        mockMvc.perform(put(URI.create(uploadUrl.replace("maxBytes=10", "maxBytes=99")))
                        .contentType("image/jpeg").content(new byte[10]))
                .andExpect(status().isForbidden());
        mockMvc.perform(put(URI.create(uploadUrl.substring(0, uploadUrl.indexOf('?'))))
                        .contentType("image/jpeg").content(new byte[10]))
                .andExpect(status().isForbidden());
        mockMvc.perform(put(URI.create(uploadUrl)).contentType("image/jpeg").content(new byte[11]))
                .andExpect(status().is(413))
                .andExpect(jsonPath("$.code").value("FILE_TOO_LARGE"));
        // The upload URL does not work for downloading
        mockMvc.perform(get(URI.create(uploadUrl))).andExpect(status().isForbidden());

        mockMvc.perform(as(manager, get("/api/tasks/{t}/evidence/{e}/download-url", task.getId(), id)))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.code").value("EVIDENCE_NOT_UPLOADED"));
    }

    @Test
    void deletingEvidenceDeletesTheStoredFile() throws Exception {
        UUID id = UUID.randomUUID();
        register(photo, id, "fridge.jpg", "image/jpeg", 3).andExpect(status().isCreated());
        String upload = mockMvc.perform(as(worker, post("/api/tasks/{t}/evidence/{e}/upload-url", task.getId(), id)))
                .andReturn().getResponse().getContentAsString();
        mockMvc.perform(put(URI.create(JsonPath.read(upload, "$.url"))).contentType("image/jpeg")
                .content(new byte[] {1, 2, 3})).andExpect(status().isOk());
        String key = "tasks/" + task.getId() + "/" + id + ".jpg";
        assertThat(fileStorage.size(key)).hasValue(3);

        mockMvc.perform(as(worker, delete("/api/tasks/{t}/evidence/{e}", task.getId(), id)))
                .andExpect(status().isNoContent());

        assertThat(fileStorage.size(key)).isEmpty();
    }

    private ResultActions register(Requirement requirement, UUID id, String fileName, String type, long size)
            throws Exception {
        return mockMvc.perform(as(worker, post("/api/tasks/{t}/requirements/{r}/evidence", task.getId(),
                        requirement.getId()))
                .contentType(MediaType.APPLICATION_JSON)
                .content(body(id, fileName, type, size)));
    }

    private static String body(UUID id, String fileName, String type, long size) {
        return """
                {"id": %s, "fileName": "%s", "contentType": "%s", "sizeBytes": %d}""".formatted(
                id == null ? "null" : "\"" + id + "\"", fileName, type, size);
    }

    private Requirement requirement(Task owner, String title, RequirementType type, int position) {
        return requirementRepository.save(new Requirement(owner, title, null, type, true, position, null, null));
    }

    private MockHttpServletRequestBuilder as(User user, MockHttpServletRequestBuilder request) {
        return request.header("Authorization", "Bearer " + jwtService.issueAccessToken(user).value());
    }

    private User save(String email, String name, RoleName... roles) {
        return userRepository.save(new User(organizationRepository.getDefault(), email, "hash", name,
                Arrays.stream(roles).map(r -> roleRepository.findByName(r).orElseThrow()).collect(Collectors.toSet())));
    }

}
