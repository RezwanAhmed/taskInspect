package com.taskinspect.auth;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.nimbusds.jose.jwk.source.ImmutableSecret;
import com.taskinspect.TestcontainersConfiguration;
import com.taskinspect.users.OrganizationRepository;
import com.taskinspect.users.RoleName;
import com.taskinspect.users.RoleRepository;
import com.taskinspect.users.User;
import com.taskinspect.users.UserRepository;
import java.nio.charset.StandardCharsets;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.time.ZoneOffset;
import java.time.temporal.ChronoUnit;
import java.util.Base64;
import java.util.List;
import java.util.Set;
import javax.crypto.spec.SecretKeySpec;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.context.annotation.Import;
import org.springframework.http.MediaType;
import org.springframework.security.oauth2.jose.jws.MacAlgorithm;
import org.springframework.security.oauth2.jwt.JwsHeader;
import org.springframework.security.oauth2.jwt.JwtClaimsSet;
import org.springframework.security.oauth2.jwt.JwtDecoder;
import org.springframework.security.oauth2.jwt.JwtEncoder;
import org.springframework.security.oauth2.jwt.JwtEncoderParameters;
import org.springframework.security.oauth2.jwt.NimbusJwtEncoder;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.transaction.annotation.Transactional;

@Import(TestcontainersConfiguration.class)
@SpringBootTest
@AutoConfigureMockMvc
@Transactional
class JwtAuthenticationTests {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private JwtService jwtService;

    @Autowired
    private JwtEncoder jwtEncoder;

    @Autowired
    private JwtDecoder jwtDecoder;

    @Autowired
    private JwtProperties jwtProperties;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private RoleRepository roleRepository;

    @Autowired
    private OrganizationRepository organizationRepository;

    private User manager;

    @BeforeEach
    void setUp() {
        manager = userRepository.save(new User(organizationRepository.getDefault(), "manager@example.com", "hash",
                "Mia Manager", Set.of(roleRepository.findByName(RoleName.MANAGER).orElseThrow())));
    }

    @Test
    void validTokenAuthenticatesTheRequest() throws Exception {
        String token = jwtService.issueAccessToken(manager).value();

        mockMvc.perform(get("/api/auth/me").header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.id").value(manager.getId().toString()))
                .andExpect(jsonPath("$.email").value("manager@example.com"))
                .andExpect(jsonPath("$.roles[0]").value("MANAGER"))
                .andExpect(jsonPath("$.tokenExpiresAt").isString());
    }

    @Test
    void missingTokenIsRejected() throws Exception {
        mockMvc.perform(get("/api/auth/me"))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.code").value("UNAUTHORIZED"));
    }

    @Test
    void malformedTokenIsRejected() throws Exception {
        mockMvc.perform(get("/api/auth/me").header("Authorization", "Bearer not-a-real-token"))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.code").value("INVALID_TOKEN"));
    }

    @Test
    void tamperedTokenIsRejected() throws Exception {
        String token = jwtService.issueAccessToken(manager).value();
        String tampered = token.substring(0, token.length() - 4) + "AAAA";

        mockMvc.perform(get("/api/auth/me").header("Authorization", "Bearer " + tampered))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.code").value("INVALID_TOKEN"));
    }

    @Test
    void aTokenSignedWithAnotherKeyIsRejected() throws Exception {
        JwtEncoder otherEncoder = new NimbusJwtEncoder(new ImmutableSecret<>(new SecretKeySpec(
                "another-secret-of-at-least-32-bytes!".getBytes(StandardCharsets.UTF_8), "HmacSHA256")));

        expectInvalid(encode(otherEncoder, jwtProperties.issuer()));
    }

    @Test
    void aTokenFromAnotherIssuerIsRejected() throws Exception {
        expectInvalid(encode(jwtEncoder, "someone-else"));
    }

    @Test
    void anUnsignedTokenIsRejected() throws Exception {
        Base64.Encoder base64 = Base64.getUrlEncoder().withoutPadding();
        long now = Instant.now().getEpochSecond();
        String header = base64.encodeToString("{\"alg\":\"none\"}".getBytes(StandardCharsets.UTF_8));
        String payload = base64.encodeToString("""
                {"iss": "%s", "sub": "%s", "iat": %d, "exp": %d, "roles": ["ADMINISTRATOR"]}"""
                .formatted(jwtProperties.issuer(), manager.getId(), now, now + 600).getBytes(StandardCharsets.UTF_8));

        expectInvalid(header + "." + payload + ".");
    }

    @Test
    void aTokenOfAUserWhoNoLongerExistsCannotChangeAnything() throws Exception {
        String token = jwtService.issueAccessToken(manager).value();
        userRepository.delete(manager);
        userRepository.flush();

        mockMvc.perform(post("/api/tasks").header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"title\": \"T\", \"priority\": \"LOW\", \"dueDate\": \"2026-12-01T09:00:00Z\"}"))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.code").value("UNAUTHORIZED"));
    }

    @Test
    void expiredTokenIsRejected() throws Exception {
        Clock twoHoursAgo = Clock.fixed(Instant.now().minus(Duration.ofHours(2)), ZoneOffset.UTC);
        String expired = new JwtService(jwtEncoder, jwtDecoder, jwtProperties, twoHoursAgo)
                .issueAccessToken(manager).value();

        mockMvc.perform(get("/api/auth/me").header("Authorization", "Bearer " + expired))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.code").value("INVALID_TOKEN"))
                .andExpect(jsonPath("$.message").value("Access token is invalid or expired"));
    }

    /** A token like the server's, with the given issuer, signed by the given encoder. */
    private String encode(JwtEncoder encoder, String issuer) {
        Instant now = Instant.now().truncatedTo(ChronoUnit.SECONDS);
        JwtClaimsSet claims = JwtClaimsSet.builder()
                .issuer(issuer)
                .subject(manager.getId().toString())
                .issuedAt(now)
                .expiresAt(now.plus(Duration.ofMinutes(10)))
                .claim(JwtService.CLAIM_EMAIL, manager.getEmail())
                .claim(JwtService.CLAIM_ROLES, List.of("MANAGER"))
                .build();
        return encoder.encode(JwtEncoderParameters.from(JwsHeader.with(MacAlgorithm.HS256).build(), claims))
                .getTokenValue();
    }

    private void expectInvalid(String token) throws Exception {
        mockMvc.perform(get("/api/auth/me").header("Authorization", "Bearer " + token))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.code").value("INVALID_TOKEN"));
    }

}
