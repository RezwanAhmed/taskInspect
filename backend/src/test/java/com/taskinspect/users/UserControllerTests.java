package com.taskinspect.users;

import static org.assertj.core.api.Assertions.assertThat;
import static org.hamcrest.Matchers.startsWith;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.header;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.taskinspect.TestcontainersConfiguration;
import com.taskinspect.auth.JwtService;
import java.util.Arrays;
import java.util.stream.Collectors;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.context.annotation.Import;
import org.springframework.http.MediaType;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder;
import org.springframework.transaction.annotation.Transactional;

@Import(TestcontainersConfiguration.class)
@SpringBootTest
@AutoConfigureMockMvc
@Transactional
class UserControllerTests {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private JwtService jwtService;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private RoleRepository roleRepository;

    @Autowired
    private OrganizationRepository organizationRepository;

    @Autowired
    private PasswordEncoder passwordEncoder;

    private User admin;
    private User manager;
    private User worker;
    private User otherWorker;

    @BeforeEach
    void setUp() {
        admin = save("admin@example.com", "Ada Admin", RoleName.ADMINISTRATOR);
        manager = save("manager@example.com", "Mia Manager", RoleName.MANAGER);
        worker = save("worker@example.com", "Wendy Worker", RoleName.WORKER);
        otherWorker = save("worker2@example.com", "Will Worker", RoleName.WORKER);
    }

    @Test
    void managerListsWorkersPageByPage() throws Exception {
        mockMvc.perform(as(manager, get("/api/users").param("role", "WORKER").param("size", "1")))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.content.length()").value(1))
                .andExpect(jsonPath("$.content[0].email").value("worker@example.com"))
                .andExpect(jsonPath("$.content[0].passwordHash").doesNotExist())
                .andExpect(jsonPath("$.totalElements").value(2))
                .andExpect(jsonPath("$.totalPages").value(2));
    }

    @Test
    void workerCannotListUsers() throws Exception {
        mockMvc.perform(as(worker, get("/api/users")))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.code").value("FORBIDDEN"));
    }

    @Test
    void listWithoutTokenIsUnauthorized() throws Exception {
        mockMvc.perform(get("/api/users")).andExpect(status().isUnauthorized());
    }

    @Test
    void invalidPagingAndRoleAreRejected() throws Exception {
        mockMvc.perform(as(manager, get("/api/users").param("size", "500")))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("VALIDATION_ERROR"));
        mockMvc.perform(as(manager, get("/api/users").param("role", "BOSS")))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("INVALID_PARAMETER"));
    }

    @Test
    void administratorGetsAnyUser() throws Exception {
        mockMvc.perform(as(admin, get("/api/users/{id}", worker.getId())))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.fullName").value("Wendy Worker"))
                .andExpect(jsonPath("$.roles[0]").value("WORKER"))
                .andExpect(jsonPath("$.active").value(true));
    }

    @Test
    void workerGetsOnlyThemself() throws Exception {
        mockMvc.perform(as(worker, get("/api/users/{id}", worker.getId()))).andExpect(status().isOk());
        mockMvc.perform(as(worker, get("/api/users/{id}", otherWorker.getId())))
                .andExpect(status().isForbidden());
    }

    @Test
    void unknownUserIsNotFound() throws Exception {
        mockMvc.perform(as(admin, get("/api/users/{id}", "00000000-0000-0000-0000-00000000abcd")))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.code").value("USER_NOT_FOUND"));
        mockMvc.perform(as(admin, get("/api/users/{id}", "not-a-uuid")))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("INVALID_PARAMETER"));
    }

    @Test
    void administratorCreatesUserWithHashedPassword() throws Exception {
        mockMvc.perform(as(admin, post("/api/users")).contentType(MediaType.APPLICATION_JSON).content("""
                        {"email": "New.Worker@Example.com", "fullName": " Nora New ",
                         "password": "first-password", "roles": ["WORKER"]}"""))
                .andExpect(status().isCreated())
                .andExpect(header().string("Location", startsWith("/api/users/")))
                .andExpect(jsonPath("$.email").value("new.worker@example.com"))
                .andExpect(jsonPath("$.fullName").value("Nora New"))
                .andExpect(jsonPath("$.roles[0]").value("WORKER"));

        User created = userRepository.findByEmail("new.worker@example.com").orElseThrow();
        assertThat(created.getPasswordHash()).isNotEqualTo("first-password");
        assertThat(passwordEncoder.matches("first-password", created.getPasswordHash())).isTrue();
    }

    @Test
    void managerCannotCreateUsers() throws Exception {
        mockMvc.perform(as(manager, post("/api/users")).contentType(MediaType.APPLICATION_JSON).content("""
                        {"email": "x@example.com", "fullName": "X", "password": "password-123", "roles": ["WORKER"]}"""))
                .andExpect(status().isForbidden());
    }

    @Test
    void duplicateEmailIsRejected() throws Exception {
        mockMvc.perform(as(admin, post("/api/users")).contentType(MediaType.APPLICATION_JSON).content("""
                        {"email": "WORKER@example.com", "fullName": "Copy", "password": "password-123",
                         "roles": ["WORKER"]}"""))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.code").value("EMAIL_ALREADY_USED"));
    }

    @Test
    void invalidNewUserIsRejected() throws Exception {
        mockMvc.perform(as(admin, post("/api/users")).contentType(MediaType.APPLICATION_JSON).content("""
                        {"email": "not-an-email", "fullName": "", "password": "short", "roles": []}"""))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("VALIDATION_ERROR"))
                .andExpect(jsonPath("$.errors.length()").value(4));
    }

    private MockHttpServletRequestBuilder as(User user, MockHttpServletRequestBuilder request) {
        return request.header("Authorization", "Bearer " + jwtService.issueAccessToken(user).value());
    }

    private User save(String email, String name, RoleName... roles) {
        return userRepository.save(new User(organizationRepository.getDefault(), email, "hash", name,
                Arrays.stream(roles).map(r -> roleRepository.findByName(r).orElseThrow()).collect(Collectors.toSet())));
    }

}
