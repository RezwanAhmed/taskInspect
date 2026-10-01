package com.taskinspect.auth;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.jayway.jsonpath.JsonPath;
import com.taskinspect.TestcontainersConfiguration;
import com.taskinspect.users.OrganizationRepository;
import com.taskinspect.users.RoleName;
import com.taskinspect.users.RoleRepository;
import com.taskinspect.users.User;
import com.taskinspect.users.UserRepository;
import java.util.Set;
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

/** Runs without a test transaction, so every request commits like in production. */
@Import(TestcontainersConfiguration.class)
@SpringBootTest
@AutoConfigureMockMvc
class RefreshTokenTests {

    private static final String PASSWORD = "worker-password-123";

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private RoleRepository roleRepository;

    @Autowired
    private OrganizationRepository organizationRepository;

    @Autowired
    private PasswordEncoder passwordEncoder;

    @Autowired
    private JwtService jwtService;

    @Autowired
    private JdbcTemplate jdbcTemplate;

    private User worker;

    @BeforeEach
    void setUp() {
        worker = userRepository.save(new User(organizationRepository.getDefault(), "worker@example.com",
                passwordEncoder.encode(PASSWORD), "Wendy Worker",
                Set.of(roleRepository.findByName(RoleName.WORKER).orElseThrow())));
    }

    @AfterEach
    void tearDown() {
        userRepository.deleteAll();
    }

    @Test
    void loginReturnsRefreshTokenThatIsStoredOnlyAsHash() throws Exception {
        String refreshToken = loginRefreshToken();

        assertThat(refreshToken).hasSizeGreaterThanOrEqualTo(43);
        Integer rawStored = jdbcTemplate.queryForObject(
                "select count(*) from refresh_tokens where token_hash = ?", Integer.class, refreshToken);
        Integer hashStored = jdbcTemplate.queryForObject(
                "select count(*) from refresh_tokens where token_hash = ?", Integer.class,
                RefreshTokenService.hash(refreshToken));
        assertThat(rawStored).isZero();
        assertThat(hashStored).isEqualTo(1);
    }

    @Test
    void refreshReturnsNewValidTokensAndRotatesTheRefreshToken() throws Exception {
        String first = loginRefreshToken();

        String body = refresh(first)
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.tokenType").value("Bearer"))
                .andExpect(jsonPath("$.user.email").value("worker@example.com"))
                .andReturn().getResponse().getContentAsString();

        String second = JsonPath.read(body, "$.refreshToken");
        assertThat(second).isNotEqualTo(first);
        assertThat(jwtService.validate(JsonPath.read(body, "$.accessToken")).getSubject())
                .isEqualTo(worker.getId().toString());
        refresh(second).andExpect(status().isOk());
    }

    @Test
    void reusingARefreshTokenRevokesAllTokensOfTheUser() throws Exception {
        String first = loginRefreshToken();
        String second = JsonPath.read(refresh(first).andReturn().getResponse().getContentAsString(), "$.refreshToken");

        refresh(first)
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.code").value("INVALID_REFRESH_TOKEN"));
        refresh(second)
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.code").value("INVALID_REFRESH_TOKEN"));
    }

    @Test
    void expiredRefreshTokenIsRejected() throws Exception {
        String token = loginRefreshToken();
        jdbcTemplate.update("update refresh_tokens set expires_at = now() - interval '1 minute'");

        refresh(token)
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.code").value("INVALID_REFRESH_TOKEN"));
    }

    @Test
    void unknownRefreshTokenIsRejected() throws Exception {
        refresh("this-token-was-never-issued-by-the-server")
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.code").value("INVALID_REFRESH_TOKEN"));
    }

    @Test
    void deactivatedUserCannotRefresh() throws Exception {
        String token = loginRefreshToken();
        jdbcTemplate.update("update users set active = false where id = ?", worker.getId());

        refresh(token)
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.code").value("ACCOUNT_DISABLED"));
        Integer active = jdbcTemplate.queryForObject(
                "select count(*) from refresh_tokens where user_id = ? and revoked_at is null", Integer.class,
                worker.getId());
        assertThat(active).isZero();
    }

    private String loginRefreshToken() throws Exception {
        String body = mockMvc.perform(post("/api/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"email\": \"worker@example.com\", \"password\": \"" + PASSWORD + "\"}"))
                .andExpect(status().isOk())
                .andReturn().getResponse().getContentAsString();
        return JsonPath.read(body, "$.refreshToken");
    }

    private ResultActions refresh(String refreshToken) throws Exception {
        return mockMvc.perform(post("/api/auth/refresh")
                .contentType(MediaType.APPLICATION_JSON)
                .content("{\"refreshToken\": \"" + refreshToken + "\"}"));
    }

}
