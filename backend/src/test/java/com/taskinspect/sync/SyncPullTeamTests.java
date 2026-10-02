package com.taskinspect.sync;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.jayway.jsonpath.JsonPath;
import com.taskinspect.TestcontainersConfiguration;
import com.taskinspect.auth.JwtService;
import com.taskinspect.tasks.Task;
import com.taskinspect.tasks.TaskPriority;
import com.taskinspect.tasks.TaskRepository;
import com.taskinspect.tasks.TaskAction;
import com.taskinspect.tasks.TaskFixtures;
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
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder;

/** The sync pull sends the team's tiles and a team version (task 7A.8). Runs without a test transaction. */
@Import(TestcontainersConfiguration.class)
@SpringBootTest
@AutoConfigureMockMvc
class SyncPullTeamTests {

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
    private User worker;
    private User teamMate;
    private Task mine;
    private Task teamMatesTask;

    @BeforeEach
    void setUp() {
        manager = save("manager@example.com", "Mia Manager", RoleName.MANAGER);
        worker = inTeam(save("worker@example.com", "Wendy Worker", RoleName.WORKER));
        teamMate = inTeam(save("worker2@example.com", "Tom Teammate", RoleName.WORKER));
        mine = assigned("Mine", worker);
        teamMatesTask = assigned("Tom's", teamMate);
    }

    @AfterEach
    void tearDown() {
        taskRepository.deleteAll();
        userRepository.deleteAll();
    }

    @Test
    void teamMembersTasksComeAsTilesNotAsTasks() throws Exception {
        mockMvc.perform(as(worker, get("/api/sync/pull")))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.taskIds.length()").value(1))
                .andExpect(jsonPath("$.taskIds[0]").value(mine.getId().toString()))
                .andExpect(jsonPath("$.tileIds.length()").value(1))
                .andExpect(jsonPath("$.tileIds[0]").value(teamMatesTask.getId().toString()))
                .andExpect(jsonPath("$.tiles[0].title").value("Tom's"))
                .andExpect(jsonPath("$.tiles[0].requirements").doesNotExist());
        // Managers have no team: no tiles.
        mockMvc.perform(as(manager, get("/api/sync/pull")))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.tileIds.length()").value(0))
                .andExpect(jsonPath("$.teamVersion").value("none"));
    }

    @Test
    void unchangedTilesAreOnlyListed() throws Exception {
        String first = pull(worker, null);
        String cursor = JsonPath.read(first, "$.cursor");

        String later = mockMvc.perform(as(worker, get("/api/sync/pull").param("since",
                        Instant.parse(cursor).plusSeconds(120).toString())))
                .andExpect(status().isOk())
                .andReturn().getResponse().getContentAsString();
        assertThat((Integer) JsonPath.read(later, "$.tileIds.length()")).isEqualTo(1);
        assertThat((Integer) JsonPath.read(later, "$.tiles.length()")).isZero();
    }

    @Test
    void teamVersionChangesWithTheTeam() throws Exception {
        String before = JsonPath.read(pull(worker, null), "$.teamVersion");
        assertThat((String) JsonPath.read(pull(worker, null), "$.teamVersion")).isEqualTo(before);
        assertThat((String) JsonPath.read(pull(teamMate, null), "$.teamVersion")).isEqualTo(before);

        User newcomer = inTeam(save("worker3@example.com", "Nia Newcomer", RoleName.WORKER));
        String afterJoin = JsonPath.read(pull(worker, null), "$.teamVersion");
        assertThat(afterJoin).isNotEqualTo(before);

        manager.deactivate();
        userRepository.save(manager);
        String afterDeactivation = JsonPath.read(pull(worker, null), "$.teamVersion");
        assertThat(afterDeactivation).isNotEqualTo(afterJoin);
        assertThat((Integer) JsonPath.read(pull(worker, null), "$.tileIds.length()")).isZero();

        newcomer.joinTeamOf(null);
        userRepository.save(newcomer);
        assertThat((String) JsonPath.read(pull(newcomer, null), "$.teamVersion")).isEqualTo("none");
    }

    private String pull(User user, String since) throws Exception {
        MockHttpServletRequestBuilder request = get("/api/sync/pull");
        if (since != null) {
            request.param("since", since);
        }
        return mockMvc.perform(as(user, request)).andExpect(status().isOk())
                .andReturn().getResponse().getContentAsString();
    }

    private Task assigned(String title, User assignee) {
        Task task = new Task(manager, title, null, TaskPriority.HIGH, Instant.parse("2026-12-01T09:00:00Z"), null);
        TaskFixtures.assign(task, assignee);
        new TaskStateMachine().apply(task, TaskAction.ASSIGN);
        return taskRepository.saveAndFlush(task);
    }

    private User inTeam(User member) {
        member.joinTeamOf(manager);
        return userRepository.save(member);
    }

    private MockHttpServletRequestBuilder as(User user, MockHttpServletRequestBuilder request) {
        return request.header("Authorization", "Bearer " + jwtService.issueAccessToken(user).value());
    }

    private User save(String email, String name, RoleName... roles) {
        return userRepository.save(new User(organizationRepository.getDefault(), email, "hash", name,
                Arrays.stream(roles).map(r -> roleRepository.findByName(r).orElseThrow()).collect(Collectors.toSet())));
    }

}
