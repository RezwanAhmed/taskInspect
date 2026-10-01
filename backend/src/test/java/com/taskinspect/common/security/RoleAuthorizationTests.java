package com.taskinspect.common.security;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.content;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.taskinspect.TestcontainersConfiguration;
import com.taskinspect.auth.JwtService;
import com.taskinspect.users.OrganizationRepository;
import com.taskinspect.users.RoleName;
import com.taskinspect.users.RoleRepository;
import com.taskinspect.users.User;
import com.taskinspect.users.UserRepository;
import java.nio.charset.StandardCharsets;
import java.util.Arrays;
import java.util.Base64;
import java.util.stream.Collectors;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.context.annotation.Import;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.ResultActions;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

@Import({TestcontainersConfiguration.class, RoleAuthorizationTests.TestController.class})
@SpringBootTest
@AutoConfigureMockMvc
@Transactional
class RoleAuthorizationTests {

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

    @Test
    void administratorCanUseAdminEndpoint() throws Exception {
        call("/api/test/admin", RoleName.ADMINISTRATOR).andExpect(status().isOk());
    }

    @Test
    void workerCannotUseAdminEndpoint() throws Exception {
        call("/api/test/admin", RoleName.WORKER)
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.code").value("FORBIDDEN"));
    }

    @Test
    void managerCannotUseAdminEndpoint() throws Exception {
        call("/api/test/admin", RoleName.MANAGER).andExpect(status().isForbidden());
    }

    @Test
    void managerAndAdministratorCanUseManagerEndpoint() throws Exception {
        call("/api/test/manager", RoleName.MANAGER).andExpect(status().isOk());
        call("/api/test/manager", RoleName.ADMINISTRATOR).andExpect(status().isOk());
    }

    @Test
    void workerCannotApproveEvenWithAHandCraftedRequest() throws Exception {
        call("/api/test/manager", RoleName.WORKER)
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.code").value("FORBIDDEN"));
    }

    @Test
    void soloUserWithManagerAndWorkerRolesCanUseBoth() throws Exception {
        call("/api/test/manager", RoleName.MANAGER, RoleName.WORKER).andExpect(status().isOk());
        call("/api/test/worker", RoleName.MANAGER, RoleName.WORKER).andExpect(status().isOk());
    }

    @Test
    void currentUserIsReadFromTheToken() throws Exception {
        call("/api/test/whoami", RoleName.WORKER)
                .andExpect(status().isOk())
                .andExpect(content().string("user-worker@example.com [WORKER]"));
    }

    @Test
    void rolesAddedToATokenByTheClientAreRejected() throws Exception {
        String token = tokenFor("forger@example.com", RoleName.WORKER);
        String[] parts = token.split("\\.");
        String payload = new String(Base64.getUrlDecoder().decode(parts[1]), StandardCharsets.UTF_8)
                .replace("[\"WORKER\"]", "[\"ADMINISTRATOR\"]");
        String forged = parts[0] + "." + Base64.getUrlEncoder().withoutPadding()
                .encodeToString(payload.getBytes(StandardCharsets.UTF_8)) + "." + parts[2];

        mockMvc.perform(get("/api/test/admin").header("Authorization", "Bearer " + forged))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.code").value("INVALID_TOKEN"));
    }

    private ResultActions call(String url, RoleName... roles) throws Exception {
        String email = "user-" + Arrays.stream(roles).map(r -> r.name().toLowerCase()).collect(Collectors.joining("-"))
                + "@example.com";
        return mockMvc.perform(get(url).header("Authorization", "Bearer " + tokenFor(email, roles)));
    }

    private String tokenFor(String email, RoleName... roles) {
        User user = userRepository.save(new User(organizationRepository.getDefault(), email, "hash", "Test",
                Arrays.stream(roles).map(r -> roleRepository.findByName(r).orElseThrow()).collect(Collectors.toSet())));
        return jwtService.issueAccessToken(user).value();
    }

    @RestController
    static class TestController {

        @GetMapping("/api/test/admin")
        @PreAuthorize(Roles.ADMIN)
        String admin() {
            return "admin";
        }

        @GetMapping("/api/test/manager")
        @PreAuthorize(Roles.ADMIN_OR_MANAGER)
        String manager() {
            return "manager";
        }

        @GetMapping("/api/test/worker")
        @PreAuthorize(Roles.WORKER)
        String worker() {
            return "worker";
        }

        @GetMapping("/api/test/whoami")
        String whoami(@AuthenticationPrincipal Jwt jwt) {
            CurrentUser user = CurrentUser.from(jwt);
            return user.email() + " " + user.roles();
        }

    }

}
