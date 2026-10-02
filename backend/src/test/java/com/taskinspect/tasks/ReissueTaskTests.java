package com.taskinspect.tasks;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.jayway.jsonpath.JsonPath;
import com.taskinspect.TestcontainersConfiguration;
import com.taskinspect.auth.JwtService;
import com.taskinspect.requirements.Requirement;
import com.taskinspect.requirements.RequirementOption;
import com.taskinspect.requirements.RequirementRepository;
import com.taskinspect.requirements.RequirementType;
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
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.ResultActions;
import org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder;
import org.springframework.transaction.support.TransactionTemplate;

/** Registering a new task for the same worker from an existing one (task 7A.7). Runs without a test transaction. */
@Import(TestcontainersConfiguration.class)
@SpringBootTest
@AutoConfigureMockMvc
class ReissueTaskTests {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private JwtService jwtService;

    @Autowired
    private TaskRepository taskRepository;

    @Autowired
    private RequirementRepository requirementRepository;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private RoleRepository roleRepository;

    @Autowired
    private OrganizationRepository organizationRepository;

    @Autowired
    private TransactionTemplate transactionTemplate;

    private User manager;
    private User otherManager;
    private User worker;

    @BeforeEach
    void setUp() {
        manager = save("manager@example.com", "Mia Manager", RoleName.MANAGER);
        otherManager = save("manager2@example.com", "Max Manager", RoleName.MANAGER);
        worker = save("worker@example.com", "Wendy Worker", RoleName.WORKER);
    }

    @AfterEach
    void tearDown() {
        taskRepository.deleteAll();
        userRepository.deleteAll();
    }

    @Test
    void managerRegistersAnApprovedTaskAgainForTheSameWorker() throws Exception {
        Task original = taskIn(TaskStatus.APPROVED);

        String body = reissue(manager, original)
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.status").value("ASSIGNED"))
                .andExpect(jsonPath("$.title").value("Kitchen"))
                .andExpect(jsonPath("$.assignee.id").value(worker.getId().toString()))
                .andExpect(jsonPath("$.reviewer.id").value(manager.getId().toString()))
                .andExpect(jsonPath("$.reissuedFromId").value(original.getId().toString()))
                .andReturn().getResponse().getContentAsString();
        UUID copyId = UUID.fromString(JsonPath.read(body, "$.id"));

        List<String> copied = transactionTemplate.execute(status -> requirementRepository
                .findAllByTaskIdOrderByPosition(copyId).stream()
                .map(r -> r.getTitle() + "/" + r.getType() + "/"
                        + r.getOptions().stream().map(RequirementOption::getLabel).collect(Collectors.joining(",")))
                .toList());
        assertThat(copied).containsExactly("Is the fire extinguisher available?/YES_NO/",
                "Floor type/DROPDOWN/Tiles,Wood");
        // The original stays as it was, and the worker sees both.
        assertThat(taskRepository.findById(original.getId()).orElseThrow().getStatus()).isEqualTo(TaskStatus.APPROVED);
        mockMvc.perform(as(worker, get("/api/tasks")))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.content.length()").value(2));
        mockMvc.perform(as(manager, get("/api/tasks/{id}/history", copyId)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.length()").value(2))
                .andExpect(jsonPath("$[1].event").value("ASSIGNED"));
    }

    @Test
    void onlyOnceWorkHasStarted() throws Exception {
        reissue(manager, taskIn(TaskStatus.ASSIGNED))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.code").value("TASK_NOT_REISSUABLE"));
        reissue(manager, taskIn(TaskStatus.CANCELLED))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.code").value("TASK_NOT_REISSUABLE"));
        reissue(manager, taskIn(TaskStatus.IN_PROGRESS)).andExpect(status().isCreated());
        reissue(manager, taskIn(TaskStatus.REJECTED)).andExpect(status().isCreated());
    }

    @Test
    void onlyTheCreatingManager() throws Exception {
        Task original = taskIn(TaskStatus.SUBMITTED);

        reissue(otherManager, original).andExpect(status().isForbidden());
        reissue(worker, original).andExpect(status().isForbidden());
    }

    @Test
    void workerMustStillBeActiveAndAnInactiveReviewerIsReplaced() throws Exception {
        Task original = taskIn(TaskStatus.APPROVED);
        Task otherReviewer = taskRepository.findById(original.getId()).orElseThrow();
        otherReviewer.updateDetails("Kitchen", null, TaskPriority.HIGH, otherReviewer.getDueDate(), otherManager);
        taskRepository.saveAndFlush(otherReviewer);
        otherManager.deactivate();
        userRepository.save(otherManager);

        reissue(manager, original)
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.reviewer.id").value(manager.getId().toString()));

        worker.deactivate();
        userRepository.save(worker);
        reissue(manager, original)
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("INVALID_ASSIGNEE"));
    }

    @Test
    void mainTasksAreNotRegisteredAgain() throws Exception {
        // Only a user who is both administrator and manager creates a main task and passes the role check.
        User both = save("both@example.com", "Bo Both", RoleName.ADMINISTRATOR, RoleName.MANAGER);
        Task mainTask = new Task(both, "Inspect building B", null, TaskPriority.HIGH,
                Instant.parse("2026-12-01T09:00:00Z"), null);
        TaskStateMachine stateMachine = new TaskStateMachine();
        stateMachine.apply(mainTask, TaskAction.ASSIGN);
        mainTask.assignTo(manager);
        stateMachine.apply(mainTask, TaskAction.START);
        mainTask = taskRepository.saveAndFlush(mainTask);

        reissue(both, mainTask)
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.code").value("TASK_NOT_REISSUABLE"));
    }

    /** A task of the manager, assigned to the worker, with two requirements, moved to the given status. */
    private Task taskIn(TaskStatus target) {
        Task task = taskRepository.save(new Task(manager, "Kitchen", null, TaskPriority.HIGH,
                Instant.parse("2026-12-01T09:00:00Z"), null));
        requirementRepository.save(new Requirement(task, "Is the fire extinguisher available?", null,
                RequirementType.YES_NO, true, 0, null, null));
        requirementRepository.save(new Requirement(task, "Floor type", null, RequirementType.DROPDOWN, false, 1, null,
                List.of("Tiles", "Wood")));
        TaskStateMachine stateMachine = new TaskStateMachine();
        stateMachine.apply(task, TaskAction.ASSIGN);
        task.assignTo(worker);
        List<TaskAction> path = switch (target) {
            case ASSIGNED -> List.of();
            case CANCELLED -> List.of(TaskAction.CANCEL);
            case IN_PROGRESS -> List.of(TaskAction.START);
            case SUBMITTED -> List.of(TaskAction.START, TaskAction.SUBMIT);
            case REJECTED -> List.of(TaskAction.START, TaskAction.SUBMIT, TaskAction.REJECT);
            case APPROVED -> List.of(TaskAction.START, TaskAction.SUBMIT, TaskAction.APPROVE);
            default -> throw new IllegalArgumentException(target.name());
        };
        path.forEach(action -> stateMachine.apply(task, action));
        return taskRepository.saveAndFlush(task);
    }

    private ResultActions reissue(User user, Task original) throws Exception {
        return mockMvc.perform(as(user, post("/api/tasks/{id}/reissue", original.getId())));
    }

    private MockHttpServletRequestBuilder as(User user, MockHttpServletRequestBuilder request) {
        return request.header("Authorization", "Bearer " + jwtService.issueAccessToken(user).value());
    }

    private User save(String email, String name, RoleName... roles) {
        return userRepository.save(new User(organizationRepository.getDefault(), email, "hash", name,
                Arrays.stream(roles).map(r -> roleRepository.findByName(r).orElseThrow()).collect(Collectors.toSet())));
    }

}
