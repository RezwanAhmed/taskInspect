package com.taskinspect.responses;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
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
import com.taskinspect.users.OrganizationRepository;
import com.taskinspect.users.RoleName;
import com.taskinspect.users.RoleRepository;
import com.taskinspect.users.User;
import com.taskinspect.users.UserRepository;
import java.time.Instant;
import java.util.Arrays;
import java.util.List;
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
class ResponseApiTests {

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
    private Task task;
    private Requirement yesNo;
    private Requirement number;
    private Requirement text;
    private Requirement dropdown;
    private Requirement multi;
    private Requirement photo;

    @BeforeEach
    void setUp() {
        manager = save("manager@example.com", "Mia Manager", RoleName.MANAGER);
        worker = save("worker@example.com", "Wendy Worker", RoleName.WORKER);
        Task created = taskRepository.save(new Task(manager, "Kitchen", null, TaskPriority.HIGH,
                Instant.parse("2026-10-02T09:00:00Z"), null));
        yesNo = requirement(created, "Fire extinguisher available?", RequirementType.YES_NO, 0, null, null);
        number = requirement(created, "Fridge temperature", RequirementType.NUMBER, 1, "°C", null);
        text = requirement(created, "Notes", RequirementType.TEXT, 2, null, null);
        dropdown = requirement(created, "Floor", RequirementType.DROPDOWN, 3, null, List.of("Clean", "Dirty"));
        multi = requirement(created, "Problems", RequirementType.MULTIPLE_SELECTION, 4, null,
                List.of("Leak", "Smell", "Noise"));
        photo = requirement(created, "Photo of fridge", RequirementType.PHOTO, 5, null, null);
        TaskFixtures.assign(created, worker);
        stateMachine.apply(created, TaskAction.ASSIGN);
        stateMachine.apply(created, TaskAction.START);
        task = taskRepository.save(created);
        dropdown = requirementRepository.findWithOptionsById(dropdown.getId()).orElseThrow();
        multi = requirementRepository.findWithOptionsById(multi.getId()).orElseThrow();
    }

    @AfterEach
    void tearDown() {
        taskRepository.deleteAll();
        userRepository.deleteAll();
    }

    @Test
    void workerAnswersEachTypeAndManagerReadsTheAnswers() throws Exception {
        answer(yesNo, "{\"booleanValue\": true, \"comment\": \"Checked the label\"}")
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.booleanValue").value(true))
                .andExpect(jsonPath("$.comment").value("Checked the label"));
        answer(number, "{\"numberValue\": 3.5}").andExpect(status().isOk())
                .andExpect(jsonPath("$.numberValue").value(3.5));
        answer(text, "{\"textValue\": \" All good \"}").andExpect(status().isOk())
                .andExpect(jsonPath("$.textValue").value("All good"));
        answer(dropdown, "{\"selectedOptionIds\": [\"" + option(dropdown, 1) + "\"]}").andExpect(status().isOk());
        answer(multi, "{\"selectedOptionIds\": [\"" + option(multi, 0) + "\", \"" + option(multi, 2) + "\"]}")
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.selectedOptionIds.length()").value(2));

        mockMvc.perform(as(manager, get("/api/tasks/{id}/responses", task.getId())))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.length()").value(5));
    }

    @Test
    void answeringAgainReplacesTheAnswer() throws Exception {
        answer(number, "{\"numberValue\": 3.5}").andExpect(status().isOk());
        answer(number, "{\"numberValue\": 4}").andExpect(status().isOk());

        mockMvc.perform(as(worker, get("/api/tasks/{id}/responses", task.getId())))
                .andExpect(jsonPath("$.length()").value(1))
                .andExpect(jsonPath("$[0].numberValue").value(4));
    }

    @Test
    void wrongValueForTheTypeIsRejected() throws Exception {
        answer(yesNo, "{\"textValue\": \"yes\"}")
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("INVALID_RESPONSE"));
        answer(number, "{\"numberValue\": 3, \"booleanValue\": true}")
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("INVALID_RESPONSE"));
        answer(dropdown, "{\"selectedOptionIds\": [\"" + option(dropdown, 0) + "\", \"" + option(dropdown, 1) + "\"]}")
                .andExpect(status().isBadRequest());
        answer(multi, "{\"selectedOptionIds\": [\"" + option(dropdown, 0) + "\"]}")
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("INVALID_RESPONSE"));
        answer(photo, "{\"textValue\": \"here\"}")
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("USE_EVIDENCE_UPLOAD"));
    }

    @Test
    void onlyTheAssignedWorkerAnswersWhileInProgress() throws Exception {
        User other = save("worker2@example.com", "Will Worker", RoleName.WORKER);
        mockMvc.perform(as(other, put("/api/tasks/{t}/requirements/{r}/response", task.getId(), yesNo.getId()))
                        .contentType(MediaType.APPLICATION_JSON).content("{\"booleanValue\": true}"))
                .andExpect(status().isNotFound());
        mockMvc.perform(as(manager, put("/api/tasks/{t}/requirements/{r}/response", task.getId(), yesNo.getId()))
                        .contentType(MediaType.APPLICATION_JSON).content("{\"booleanValue\": true}"))
                .andExpect(status().isForbidden());

        stateMachine.apply(task, TaskAction.SUBMIT);
        task = taskRepository.save(task);

        answer(yesNo, "{\"booleanValue\": false}")
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.code").value("RESPONSES_LOCKED"));
    }

    private ResultActions answer(Requirement requirement, String json) throws Exception {
        return mockMvc.perform(as(worker, put("/api/tasks/{t}/requirements/{r}/response", task.getId(),
                        requirement.getId()))
                .contentType(MediaType.APPLICATION_JSON).content(json));
    }

    private static String option(Requirement requirement, int index) {
        return requirement.getOptions().get(index).getId().toString();
    }

    private Requirement requirement(Task owner, String title, RequirementType type, int position, String unit,
            List<String> options) {
        return requirementRepository.save(new Requirement(owner, title, null, type, true, position, unit, options));
    }

    private MockHttpServletRequestBuilder as(User user, MockHttpServletRequestBuilder request) {
        return request.header("Authorization", "Bearer " + jwtService.issueAccessToken(user).value());
    }

    private User save(String email, String name, RoleName... roles) {
        return userRepository.save(new User(organizationRepository.getDefault(), email, "hash", name,
                Arrays.stream(roles).map(r -> roleRepository.findByName(r).orElseThrow()).collect(Collectors.toSet())));
    }

}
