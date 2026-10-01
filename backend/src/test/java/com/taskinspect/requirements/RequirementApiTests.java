package com.taskinspect.requirements;

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
import com.taskinspect.tasks.Task;
import com.taskinspect.tasks.TaskAction;
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
class RequirementApiTests {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private JwtService jwtService;

    @Autowired
    private TaskRepository taskRepository;

    @Autowired
    private TaskStateMachine stateMachine;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private RoleRepository roleRepository;

    @Autowired
    private OrganizationRepository organizationRepository;

    private User manager;
    private User otherManager;
    private User worker;
    private Task task;

    @BeforeEach
    void setUp() {
        manager = save("manager@example.com", "Mia Manager", RoleName.MANAGER);
        otherManager = save("manager2@example.com", "Max Manager", RoleName.MANAGER);
        worker = save("worker@example.com", "Wendy Worker", RoleName.WORKER);
        task = taskRepository.save(new Task(manager, "Daily kitchen safety inspection", null, TaskPriority.HIGH,
                Instant.parse("2026-10-02T09:00:00Z"), null));
    }

    @AfterEach
    void tearDown() {
        taskRepository.deleteAll();
        userRepository.deleteAll();
    }

    @Test
    void managerBuildsAChecklistOfDifferentTypes() throws Exception {
        add("""
                {"title": "Is the fire extinguisher available?", "type": "YES_NO"}""")
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.position").value(0))
                .andExpect(jsonPath("$.required").value(true));
        add("""
                {"title": "Record refrigerator temperature", "type": "NUMBER", "unit": "°C"}""")
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.unit").value("°C"));
        add("""
                {"title": "Floor condition", "type": "DROPDOWN", "required": false,
                 "options": ["Clean", " Needs cleaning ", "Damaged"]}""")
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.options[1].label").value("Needs cleaning"));

        mockMvc.perform(as(otherManager, get("/api/tasks/{id}/requirements", task.getId())))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.length()").value(3))
                .andExpect(jsonPath("$[0].type").value("YES_NO"))
                .andExpect(jsonPath("$[1].type").value("NUMBER"))
                .andExpect(jsonPath("$[2].required").value(false))
                .andExpect(jsonPath("$[2].options.length()").value(3));
    }

    @Test
    void updatesARequirement() throws Exception {
        String id = idOf(add("""
                {"title": "Floor", "type": "DROPDOWN", "options": ["A", "B"]}"""));

        mockMvc.perform(as(manager, put("/api/tasks/{t}/requirements/{r}", task.getId(), id))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"title": "Take a photo of the floor", "type": "PHOTO"}"""))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.type").value("PHOTO"))
                .andExpect(jsonPath("$.options.length()").value(0));
    }

    @Test
    void deletingARequirementRenumbersTheOthers() throws Exception {
        add("{\"title\": \"First\", \"type\": \"CHECKBOX\"}");
        String second = idOf(add("{\"title\": \"Second\", \"type\": \"TEXT\"}"));
        add("{\"title\": \"Third\", \"type\": \"COMMENT\"}");

        mockMvc.perform(as(manager, delete("/api/tasks/{t}/requirements/{r}", task.getId(), second)))
                .andExpect(status().isNoContent());

        mockMvc.perform(as(manager, get("/api/tasks/{id}/requirements", task.getId())))
                .andExpect(jsonPath("$.length()").value(2))
                .andExpect(jsonPath("$[1].title").value("Third"))
                .andExpect(jsonPath("$[1].position").value(1));
    }

    @Test
    void changingRequirementsMarksTheTaskChangedButKeepsItsVersion() throws Exception {
        Task before = taskRepository.findById(task.getId()).orElseThrow();

        String id = idOf(add("{\"title\": \"First\", \"type\": \"CHECKBOX\"}"));
        Task afterAdd = taskRepository.findById(task.getId()).orElseThrow();
        mockMvc.perform(as(manager, delete("/api/tasks/{t}/requirements/{r}", task.getId(), id)))
                .andExpect(status().isNoContent());
        Task afterDelete = taskRepository.findById(task.getId()).orElseThrow();

        assertThat(afterAdd.getUpdatedAt()).isAfter(before.getUpdatedAt());
        assertThat(afterDelete.getUpdatedAt()).isAfterOrEqualTo(afterAdd.getUpdatedAt());
        assertThat(afterDelete.getVersion()).isEqualTo(before.getVersion());
    }

    @Test
    void invalidCombinationsAreRejected() throws Exception {
        add("{\"title\": \"Pick one\", \"type\": \"DROPDOWN\", \"options\": [\"Only one\"]}")
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("INVALID_REQUIREMENT"));
        add("{\"title\": \"Ok?\", \"type\": \"YES_NO\", \"options\": [\"A\", \"B\"]}")
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("INVALID_REQUIREMENT"));
        add("{\"title\": \"Notes\", \"type\": \"TEXT\", \"unit\": \"kg\"}")
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("INVALID_REQUIREMENT"));
        add("{\"title\": \"\", \"type\": null}")
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("VALIDATION_ERROR"));
    }

    @Test
    void onlyTheCreatorCanChangeRequirementsBeforeWorkStarts() throws Exception {
        String body = "{\"title\": \"Ok?\", \"type\": \"YES_NO\"}";
        mockMvc.perform(as(otherManager, post("/api/tasks/{id}/requirements", task.getId()))
                        .contentType(MediaType.APPLICATION_JSON).content(body))
                .andExpect(status().isForbidden());
        mockMvc.perform(as(worker, post("/api/tasks/{id}/requirements", task.getId()))
                        .contentType(MediaType.APPLICATION_JSON).content(body))
                .andExpect(status().isForbidden());

        stateMachine.apply(task, TaskAction.ASSIGN);
        stateMachine.apply(task, TaskAction.START);
        taskRepository.save(task);

        add(body).andExpect(status().isConflict()).andExpect(jsonPath("$.code").value("TASK_NOT_EDITABLE"));
    }

    @Test
    void unknownRequirementIsNotFound() throws Exception {
        mockMvc.perform(as(manager, delete("/api/tasks/{t}/requirements/{r}", task.getId(),
                        "00000000-0000-0000-0000-00000000abcd")))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.code").value("REQUIREMENT_NOT_FOUND"));
    }

    private ResultActions add(String json) throws Exception {
        return mockMvc.perform(as(manager, post("/api/tasks/{id}/requirements", task.getId()))
                .contentType(MediaType.APPLICATION_JSON).content(json));
    }

    private static String idOf(ResultActions result) throws Exception {
        return JsonPath.read(result.andReturn().getResponse().getContentAsString(), "$.id");
    }

    private MockHttpServletRequestBuilder as(User user, MockHttpServletRequestBuilder request) {
        return request.header("Authorization", "Bearer " + jwtService.issueAccessToken(user).value());
    }

    private User save(String email, String name, RoleName... roles) {
        return userRepository.save(new User(organizationRepository.getDefault(), email, "hash", name,
                Arrays.stream(roles).map(r -> roleRepository.findByName(r).orElseThrow()).collect(Collectors.toSet())));
    }

}
