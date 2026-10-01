package com.taskinspect.users;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.taskinspect.TestcontainersConfiguration;
import com.taskinspect.auth.JwtService;
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

/** Teams (task 7A.3): a worker belongs to one manager's team, set by an administrator. */
@Import(TestcontainersConfiguration.class)
@SpringBootTest
@AutoConfigureMockMvc
class UserTeamTests {

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

    private User admin;
    private User manager;
    private User otherManager;
    private User worker;

    @BeforeEach
    void setUp() {
        admin = save("admin@example.com", "Ada Admin", RoleName.ADMINISTRATOR);
        manager = save("manager@example.com", "Mia Manager", RoleName.MANAGER);
        otherManager = save("manager2@example.com", "Max Manager", RoleName.MANAGER);
        worker = save("worker@example.com", "Wendy Worker", RoleName.WORKER);
    }

    @AfterEach
    void tearDown() {
        userRepository.deleteAll();
    }

    @Test
    void anAdministratorPutsAWorkerIntoATeamAndMovesThemToAnother() throws Exception {
        setTeam(admin, worker, manager)
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.teamManager.id").value(manager.getId().toString()))
                .andExpect(jsonPath("$.teamManager.fullName").value("Mia Manager"));
        mockMvc.perform(as(manager, get("/api/users").param("teamManagerId", manager.getId().toString())))
                .andExpect(jsonPath("$.content.length()").value(1))
                .andExpect(jsonPath("$.content[0].email").value("worker@example.com"));

        setTeam(admin, worker, otherManager)
                .andExpect(jsonPath("$.teamManager.id").value(otherManager.getId().toString()));
        mockMvc.perform(as(manager, get("/api/users").param("teamManagerId", manager.getId().toString())))
                .andExpect(jsonPath("$.content.length()").value(0));
    }

    @Test
    void noManagerTakesTheWorkerOutOfTheirTeam() throws Exception {
        setTeam(admin, worker, manager).andExpect(status().isOk());

        mockMvc.perform(as(admin, put("/api/users/{id}/team", worker.getId()))
                        .contentType(MediaType.APPLICATION_JSON).content("{\"managerId\": null}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.teamManager").doesNotExist());
    }

    @Test
    void onlyWorkersJoinTeamsAndOnlyManagersLeadThem() throws Exception {
        setTeam(admin, manager, otherManager)
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("NOT_A_WORKER"));
        setTeam(admin, worker, admin)
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("INVALID_TEAM_MANAGER"));
    }

    @Test
    void aSoloManagerWorkerCannotBeTheirOwnTeamManager() throws Exception {
        User solo = save("solo@example.com", "Sam Solo", RoleName.MANAGER, RoleName.WORKER);

        setTeam(admin, solo, solo)
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("INVALID_TEAM_MANAGER"));
    }

    @Test
    void onlyAdministratorsSetTeams() throws Exception {
        setTeam(manager, worker, manager).andExpect(status().isForbidden());
        setTeam(worker, worker, manager).andExpect(status().isForbidden());
    }

    @Test
    void aMissingManagerFieldIsAnErrorNotARemoval() throws Exception {
        setTeam(admin, worker, manager).andExpect(status().isOk());

        mockMvc.perform(as(admin, put("/api/users/{id}/team", worker.getId()))
                        .contentType(MediaType.APPLICATION_JSON).content("{\"manager_id\": null}"))
                .andExpect(status().isBadRequest());
        mockMvc.perform(as(admin, get("/api/users/{id}", worker.getId())))
                .andExpect(jsonPath("$.teamManager.id").value(manager.getId().toString()));
    }

    @Test
    void anInactiveManagerCannotLeadATeamAndAnUnknownUserIsNotFound() throws Exception {
        manager.deactivate();
        userRepository.save(manager);

        setTeam(admin, worker, manager)
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("INVALID_TEAM_MANAGER"));
        mockMvc.perform(as(admin, put("/api/users/{id}/team", java.util.UUID.randomUUID()))
                        .contentType(MediaType.APPLICATION_JSON).content("{\"managerId\": null}"))
                .andExpect(status().isNotFound());
    }

    @Test
    void aSoloManagerWorkerCanJoinAnotherManagersTeam() throws Exception {
        User solo = save("solo2@example.com", "Sol Solo", RoleName.MANAGER, RoleName.WORKER);

        setTeam(admin, solo, manager)
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.teamManager.fullName").value("Mia Manager"));
    }

    private ResultActions setTeam(User caller, User user, User teamManager) throws Exception {
        return mockMvc.perform(as(caller, put("/api/users/{id}/team", user.getId()))
                .contentType(MediaType.APPLICATION_JSON)
                .content("{\"managerId\": \"" + teamManager.getId() + "\"}"));
    }

    private MockHttpServletRequestBuilder as(User user, MockHttpServletRequestBuilder request) {
        return request.header("Authorization", "Bearer " + jwtService.issueAccessToken(user).value());
    }

    private User save(String email, String name, RoleName... roles) {
        return userRepository.save(new User(organizationRepository.getDefault(), email, "hash", name,
                Arrays.stream(roles).map(r -> roleRepository.findByName(r).orElseThrow()).collect(Collectors.toSet())));
    }

}
