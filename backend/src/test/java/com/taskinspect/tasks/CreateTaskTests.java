package com.taskinspect.tasks;

import static org.assertj.core.api.Assertions.assertThat;
import static org.hamcrest.Matchers.startsWith;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.header;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.jayway.jsonpath.JsonPath;
import com.taskinspect.TestcontainersConfiguration;
import com.taskinspect.auth.JwtService;
import com.taskinspect.users.OrganizationRepository;
import com.taskinspect.users.RoleName;
import com.taskinspect.users.RoleRepository;
import com.taskinspect.users.User;
import com.taskinspect.users.UserRepository;
import java.util.Arrays;
import java.util.UUID;
import java.util.stream.Collectors;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.context.annotation.Import;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.ResultActions;
import org.springframework.transaction.annotation.Transactional;

@Import(TestcontainersConfiguration.class)
@SpringBootTest
@AutoConfigureMockMvc
@Transactional
class CreateTaskTests {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private JwtService jwtService;

    @Autowired
    private TaskRepository taskRepository;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private RoleRepository roleRepository;

    @Autowired
    private OrganizationRepository organizationRepository;

    private User manager;
    private User otherManager;
    private User worker;

    @BeforeEach
    void setUp() {
        manager = save("manager@example.com", "Mia Manager", RoleName.MANAGER);
        otherManager = save("manager2@example.com", "Max Manager", RoleName.MANAGER);
        worker = save("worker@example.com", "Wendy Worker", RoleName.WORKER);
    }

    @Test
    void managerCreatesDraftTaskReviewedByThemselfByDefault() throws Exception {
        String body = create(manager, """
                {"title": " Daily kitchen check ", "description": "Check fridge and floor",
                 "priority": "HIGH", "dueDate": "2026-12-01T09:00:00Z"}""")
                .andExpect(status().isCreated())
                .andExpect(header().string("Location", startsWith("/api/tasks/")))
                .andExpect(jsonPath("$.title").value("Daily kitchen check"))
                .andExpect(jsonPath("$.status").value("DRAFT"))
                .andExpect(jsonPath("$.priority").value("HIGH"))
                .andExpect(jsonPath("$.dueDate").value("2026-12-01T09:00:00Z"))
                .andExpect(jsonPath("$.createdBy.fullName").value("Mia Manager"))
                .andExpect(jsonPath("$.reviewer.id").value(manager.getId().toString()))
                .andExpect(jsonPath("$.version").value(0))
                .andReturn().getResponse().getContentAsString();

        Task saved = taskRepository.findById(UUID.fromString(JsonPath.read(body, "$.id"))).orElseThrow();
        assertThat(saved.getOrganization().getId()).isEqualTo(manager.getOrganization().getId());
        assertThat(saved.getDescription()).isEqualTo("Check fridge and floor");
    }

    @Test
    void anotherManagerCanBeTheReviewer() throws Exception {
        create(manager, """
                {"title": "Audit", "priority": "LOW", "dueDate": "2026-12-01T09:00:00Z",
                 "reviewerId": "%s"}""".formatted(otherManager.getId()))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.reviewer.fullName").value("Max Manager"));
    }

    @Test
    void reviewerMustBeAManager() throws Exception {
        create(manager, """
                {"title": "Audit", "priority": "LOW", "dueDate": "2026-12-01T09:00:00Z",
                 "reviewerId": "%s"}""".formatted(worker.getId()))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("INVALID_REVIEWER"));
        create(manager, """
                {"title": "Audit", "priority": "LOW", "dueDate": "2026-12-01T09:00:00Z",
                 "reviewerId": "00000000-0000-0000-0000-00000000dead"}""")
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("INVALID_REVIEWER"));
    }

    @Test
    void workerCannotCreateTasks() throws Exception {
        create(worker, """
                {"title": "Audit", "priority": "LOW", "dueDate": "2026-12-01T09:00:00Z"}""")
                .andExpect(status().isForbidden());
    }

    @Test
    void invalidTaskIsRejected() throws Exception {
        create(manager, """
                {"title": "", "priority": null, "dueDate": null}""")
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("VALIDATION_ERROR"))
                .andExpect(jsonPath("$.errors.length()").value(3));
        create(manager, """
                {"title": "Audit", "priority": "CRITICAL", "dueDate": "2026-12-01T09:00:00Z"}""")
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("MALFORMED_REQUEST"));
    }

    @Test
    void createWithoutTokenIsUnauthorized() throws Exception {
        mockMvc.perform(post("/api/tasks").contentType(MediaType.APPLICATION_JSON).content("{}"))
                .andExpect(status().isUnauthorized());
    }

    private ResultActions create(User user, String json) throws Exception {
        return mockMvc.perform(post("/api/tasks")
                .header("Authorization", "Bearer " + jwtService.issueAccessToken(user).value())
                .contentType(MediaType.APPLICATION_JSON)
                .content(json));
    }

    private User save(String email, String name, RoleName... roles) {
        return userRepository.save(new User(organizationRepository.getDefault(), email, "hash", name,
                Arrays.stream(roles).map(r -> roleRepository.findByName(r).orElseThrow()).collect(Collectors.toSet())));
    }

}
