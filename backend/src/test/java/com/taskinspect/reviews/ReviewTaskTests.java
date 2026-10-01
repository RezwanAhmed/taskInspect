package com.taskinspect.reviews;

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
import com.taskinspect.tasks.Task;
import com.taskinspect.tasks.TaskAction;
import com.taskinspect.tasks.TaskFixtures;
import com.taskinspect.tasks.TaskPriority;
import com.taskinspect.tasks.TaskRepository;
import com.taskinspect.tasks.TaskStateMachine;
import com.taskinspect.tasks.TaskStatus;
import com.taskinspect.tasks.TaskStatusChange;
import com.taskinspect.tasks.TaskStatusChangeRepository;
import com.taskinspect.users.OrganizationRepository;
import com.taskinspect.users.RoleName;
import com.taskinspect.users.RoleRepository;
import com.taskinspect.users.User;
import com.taskinspect.users.UserRepository;
import java.time.Instant;
import java.util.List;
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

/** Approve, reject and request correction (task 7.2). */
@Import(TestcontainersConfiguration.class)
@SpringBootTest
@AutoConfigureMockMvc
class ReviewTaskTests {

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
    private TaskStatusChangeRepository historyRepository;

    private User manager;
    private User otherManager;
    private User worker;
    private Task task;
    private Requirement photo;

    @BeforeEach
    void setUp() {
        manager = save("manager@example.com", "Mia Manager", RoleName.MANAGER);
        otherManager = save("manager2@example.com", "Max Manager", RoleName.MANAGER);
        worker = save("worker@example.com", "Wendy Worker", RoleName.WORKER);
        task = submittedTask(manager, worker);
        photo = requirementRepository.save(new Requirement(task, "Photo of the fridge", null, RequirementType.PHOTO,
                true, 0, null, null));
    }

    @AfterEach
    void tearDown() {
        taskRepository.deleteAll();
        userRepository.deleteAll();
    }

    @Test
    void reviewerApprovesAndTheTaskIsFinal() throws Exception {
        action(manager, "approve", "{\"comment\": \"Well done\"}")
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("APPROVED"));

        reviews(worker)
                .andExpect(jsonPath("$.length()").value(1))
                .andExpect(jsonPath("$[0].result").value("APPROVED"))
                .andExpect(jsonPath("$[0].reason").value("Well done"))
                .andExpect(jsonPath("$[0].reviewer.fullName").value("Mia Manager"));
        action(manager, "approve", null)
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.code").value("TASK_ALREADY_APPROVED"));
    }

    @Test
    void approvingNeedsNoBody() throws Exception {
        mockMvc.perform(as(manager, post("/api/tasks/{id}/approve", task.getId())))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("APPROVED"));
    }

    @Test
    void rejectNeedsAReasonAndSendsTheTaskBack() throws Exception {
        action(manager, "reject", "{\"reason\": \" \"}")
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("VALIDATION_ERROR"));

        action(manager, "reject", "{\"reason\": \"Wrong kitchen\"}")
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("REJECTED"));

        reviews(manager)
                .andExpect(jsonPath("$[0].result").value("REJECTED"))
                .andExpect(jsonPath("$[0].reason").value("Wrong kitchen"))
                .andExpect(jsonPath("$[0].requirements.length()").value(0));
        List<TaskStatusChange> history = historyRepository.findAllByTaskIdOrderByChangedAtAscIdAsc(task.getId());
        TaskStatusChange last = history.get(history.size() - 1);
        assertThat(last.getFromStatus()).isEqualTo(TaskStatus.SUBMITTED);
        assertThat(last.getToStatus()).isEqualTo(TaskStatus.REJECTED);
        assertThat(last.getReason()).isEqualTo("Wrong kitchen");
    }

    @Test
    void rejectWithoutABodyIsRefused() throws Exception {
        mockMvc.perform(as(manager, post("/api/tasks/{id}/reject", task.getId())))
                .andExpect(status().isBadRequest());
    }

    @Test
    void aReviewerWhoIsNotTheCreatorReviews() throws Exception {
        Task created = taskRepository.save(new Task(manager, "Office", null, TaskPriority.LOW,
                Instant.parse("2026-12-01T09:00:00Z"), otherManager));
        TaskFixtures.assign(created, worker);
        stateMachine.apply(created, TaskAction.ASSIGN);
        stateMachine.apply(created, TaskAction.START);
        stateMachine.apply(created, TaskAction.SUBMIT);
        taskRepository.save(created);

        mockMvc.perform(as(manager, post("/api/tasks/{id}/approve", created.getId())))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.code").value("NOT_TASK_REVIEWER"));
        mockMvc.perform(as(otherManager, post("/api/tasks/{id}/approve", created.getId())))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("APPROVED"));
    }

    @Test
    void anApprovedTaskCannotGetACorrectionRequest() throws Exception {
        action(manager, "approve", null).andExpect(status().isOk());

        action(manager, "request-correction", """
                {"requirements": [{"requirementId": "%s", "comment": "Fix"}]}""".formatted(photo.getId()))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.code").value("TASK_ALREADY_APPROVED"));
    }

    @Test
    void correctionMarksRequirementsEachWithAComment() throws Exception {
        action(manager, "request-correction", """
                {"reason": "Almost", "requirements": [
                  {"requirementId": "%s", "comment": "Please retake the refrigerator photo."}]}"""
                .formatted(photo.getId()))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("CORRECTION_REQUESTED"));

        reviews(worker)
                .andExpect(jsonPath("$[0].result").value("CORRECTION_REQUESTED"))
                .andExpect(jsonPath("$[0].reason").value("Almost"))
                .andExpect(jsonPath("$[0].requirements.length()").value(1))
                .andExpect(jsonPath("$[0].requirements[0].requirementId").value(photo.getId().toString()))
                .andExpect(jsonPath("$[0].requirements[0].comment").value("Please retake the refrigerator photo."));
    }

    @Test
    void aCorrectionNeedsValidMarkedRequirements() throws Exception {
        action(manager, "request-correction", "{\"requirements\": []}")
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("VALIDATION_ERROR"));
        action(manager, "request-correction", """
                {"requirements": [{"requirementId": "%s", "comment": ""}]}""".formatted(photo.getId()))
                .andExpect(status().isBadRequest());
        action(manager, "request-correction", """
                {"requirements": [{"requirementId": "%s", "comment": "a"}, {"requirementId": "%s", "comment": "b"}]}"""
                .formatted(photo.getId(), photo.getId()))
                .andExpect(status().isBadRequest());

        Task other = submittedTask(manager, worker);
        Requirement foreign = requirementRepository.save(new Requirement(other, "Other", null, RequirementType.YES_NO,
                true, 0, null, null));
        action(manager, "request-correction", """
                {"requirements": [{"requirementId": "%s", "comment": "Fix"}]}""".formatted(foreign.getId()))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.code").value("REQUIREMENT_NOT_FOUND"));
        mockMvc.perform(as(manager, get("/api/tasks/{id}", task.getId())))
                .andExpect(jsonPath("$.status").value("SUBMITTED"));
    }

    @Test
    void onlyTheTasksReviewerCanReview() throws Exception {
        action(otherManager, "approve", null)
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.code").value("NOT_TASK_REVIEWER"));
        action(worker, "approve", null).andExpect(status().isForbidden());
        action(worker, "reject", "{\"reason\": \"x\"}").andExpect(status().isForbidden());
        reviews(manager).andExpect(jsonPath("$.length()").value(0));
    }

    @Test
    void aTaskThatIsNotSubmittedCannotBeReviewed() throws Exception {
        Task inProgress = taskRepository.save(new Task(manager, "Hall", null, TaskPriority.LOW,
                Instant.parse("2026-12-01T09:00:00Z"), null));
        TaskFixtures.assign(inProgress, worker);
        stateMachine.apply(inProgress, TaskAction.ASSIGN);
        stateMachine.apply(inProgress, TaskAction.START);
        taskRepository.save(inProgress);

        mockMvc.perform(as(manager, post("/api/tasks/{id}/approve", inProgress.getId())))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.code").value("TASK_INVALID_TRANSITION"));
    }

    @Test
    void soloManagerWhoDidTheirOwnTaskReviewsIt() throws Exception {
        User solo = save("solo@example.com", "Sam Solo", RoleName.MANAGER, RoleName.WORKER);
        Task own = submittedTask(solo, solo);

        mockMvc.perform(as(solo, post("/api/tasks/{id}/approve", own.getId())))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("APPROVED"));
    }

    @Test
    void aWorkerWhoIsAlsoTheReviewerOfSomeoneElsesTaskCannotReviewTheirOwnWork() throws Exception {
        User both = save("both@example.com", "Bo Both", RoleName.MANAGER, RoleName.WORKER);
        Task created = taskRepository.save(new Task(manager, "Storage", null, TaskPriority.LOW,
                Instant.parse("2026-12-01T09:00:00Z"), both));
        TaskFixtures.assign(created, both);
        stateMachine.apply(created, TaskAction.ASSIGN);
        stateMachine.apply(created, TaskAction.START);
        stateMachine.apply(created, TaskAction.SUBMIT);
        taskRepository.save(created);

        mockMvc.perform(as(both, post("/api/tasks/{id}/approve", created.getId())))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.code").value("REVIEWER_IS_ASSIGNEE"));
    }

    private Task submittedTask(User creator, User assignee) {
        Task created = taskRepository.save(new Task(creator, "Kitchen", null, TaskPriority.HIGH,
                Instant.parse("2026-12-01T09:00:00Z"), null));
        TaskFixtures.assign(created, assignee);
        stateMachine.apply(created, TaskAction.ASSIGN);
        stateMachine.apply(created, TaskAction.START);
        stateMachine.apply(created, TaskAction.SUBMIT);
        return taskRepository.save(created);
    }

    private ResultActions action(User user, String action, String body) throws Exception {
        MockHttpServletRequestBuilder request = post("/api/tasks/{id}/" + action, task.getId());
        if (body != null) {
            request.contentType(MediaType.APPLICATION_JSON).content(body);
        }
        return mockMvc.perform(as(user, request));
    }

    private ResultActions reviews(User user) throws Exception {
        return mockMvc.perform(as(user, get("/api/tasks/{id}/reviews", task.getId()))).andExpect(status().isOk());
    }

    private MockHttpServletRequestBuilder as(User user, MockHttpServletRequestBuilder request) {
        return request.header("Authorization", "Bearer " + jwtService.issueAccessToken(user).value());
    }

    private User save(String email, String name, RoleName... roles) {
        return userRepository.save(new User(organizationRepository.getDefault(), email, "hash", name,
                Arrays.stream(roles).map(r -> roleRepository.findByName(r).orElseThrow()).collect(Collectors.toSet())));
    }

}
