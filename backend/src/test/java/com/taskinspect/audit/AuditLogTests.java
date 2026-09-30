package com.taskinspect.audit;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.tuple;
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
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.ResultActions;
import org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder;
import org.springframework.test.web.servlet.request.MockMvcRequestBuilders;

/** Runs without a test transaction, so only committed audit entries are seen. */
@Import(TestcontainersConfiguration.class)
@SpringBootTest
@AutoConfigureMockMvc
class AuditLogTests {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private JwtService jwtService;

    @Autowired
    private AuditLogRepository auditLogRepository;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private RoleRepository roleRepository;

    @Autowired
    private OrganizationRepository organizationRepository;

    @Autowired
    private PasswordEncoder passwordEncoder;

    @Autowired
    private JdbcTemplate jdbcTemplate;

    private User admin;
    private User manager;
    private User worker;

    @BeforeEach
    void setUp() {
        admin = save("admin@example.com", "Ada Admin", "admin-password-1", RoleName.ADMINISTRATOR);
        manager = save("manager@example.com", "Mia Manager", "manager-password-1", RoleName.MANAGER);
        worker = save("worker@example.com", "Wendy Worker", "worker-password-1", RoleName.WORKER);
    }

    @AfterEach
    void tearDown() {
        jdbcTemplate.update("delete from audit_logs");
        jdbcTemplate.update("delete from tasks");
        userRepository.deleteAll();
    }

    @Test
    void taskLifecycleIsAuditedWithActorAndRequestId() throws Exception {
        String taskId = JsonPath.read(post(manager, "/api/tasks", """
                {"title": "Kitchen", "priority": "HIGH", "dueDate": "2026-10-02T09:00:00Z"}""", "audit-req-1")
                .andExpect(status().isCreated()).andReturn().getResponse().getContentAsString(), "$.id");
        post(manager, "/api/tasks/" + taskId + "/requirements", "{\"title\": \"Ok?\", \"type\": \"YES_NO\"}", null);
        post(manager, "/api/tasks/" + taskId + "/assign", "{\"assigneeId\": \"" + worker.getId() + "\"}", null)
                .andExpect(status().isOk());
        post(worker, "/api/tasks/" + taskId + "/start", null, null).andExpect(status().isOk());

        List<AuditLog> entries = auditLogRepository.findAllByEntityIdOrderByCreatedAtAscIdAsc(UUID.fromString(taskId));

        assertThat(entries).extracting(AuditLog::getAction, AuditLog::getActorId)
                .containsExactly(
                        tuple(AuditAction.TASK_CREATED, manager.getId()),
                        tuple(AuditAction.TASK_ASSIGNED, manager.getId()),
                        tuple(AuditAction.TASK_STARTED, worker.getId()));
        assertThat(entries.get(0).getRequestId()).isEqualTo("audit-req-1");
        assertThat(entries.get(1).getDetails()).isEqualTo("DRAFT -> ASSIGNED");
        assertThat(entries).allSatisfy(entry -> assertThat(entry.getOrganizationId()).isNotNull());
    }

    @Test
    void successfulAndFailedLoginsAreAudited() throws Exception {
        login("manager@example.com", "manager-password-1").andExpect(status().isOk());
        login("manager@example.com", "wrong-password").andExpect(status().isUnauthorized());
        login("nobody@example.com", "whatever-password").andExpect(status().isUnauthorized());

        assertThat(auditLogRepository.findAllByActionOrderByCreatedAtAsc(AuditAction.LOGIN_SUCCEEDED))
                .extracting(AuditLog::getActorId).containsExactly(manager.getId());
        assertThat(auditLogRepository.findAllByActionOrderByCreatedAtAsc(AuditAction.LOGIN_FAILED))
                .extracting(AuditLog::getActorId, AuditLog::getDetails)
                .containsExactly(
                        tuple(manager.getId(), "email: manager@example.com; wrong email or password"),
                        tuple(null, "email: nobody@example.com; wrong email or password"));
    }

    @Test
    void createdUsersAreAuditedWithoutPasswords() throws Exception {
        post(admin, "/api/users", """
                {"email": "new@example.com", "fullName": "New", "password": "secret-password-9",
                 "roles": ["WORKER"]}""", null).andExpect(status().isCreated());

        List<AuditLog> created = auditLogRepository.findAllByActionOrderByCreatedAtAsc(AuditAction.USER_CREATED);
        assertThat(created).hasSize(1);
        assertThat(created.get(0).getActorId()).isEqualTo(admin.getId());
        assertThat(created.get(0).getDetails()).contains("new@example.com").doesNotContain("secret-password-9");
    }

    private ResultActions login(String email, String password) throws Exception {
        return mockMvc.perform(MockMvcRequestBuilders.post("/api/auth/login")
                .contentType(MediaType.APPLICATION_JSON)
                .content("{\"email\": \"" + email + "\", \"password\": \"" + password + "\"}"));
    }

    private ResultActions post(User user, String url, String json, String requestId) throws Exception {
        MockHttpServletRequestBuilder request = MockMvcRequestBuilders.post(url)
                .header("Authorization", "Bearer " + jwtService.issueAccessToken(user).value());
        if (requestId != null) {
            request = request.header("X-Request-Id", requestId);
        }
        if (json != null) {
            request = request.contentType(MediaType.APPLICATION_JSON).content(json);
        }
        return mockMvc.perform(request);
    }

    private User save(String email, String name, String password, RoleName... roles) {
        return userRepository.save(new User(organizationRepository.getDefault(), email,
                passwordEncoder.encode(password), name,
                Arrays.stream(roles).map(r -> roleRepository.findByName(r).orElseThrow()).collect(Collectors.toSet())));
    }

}
