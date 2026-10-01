package com.taskinspect.teams;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.taskinspect.TestcontainersConfiguration;
import com.taskinspect.auth.JwtService;
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
import java.util.UUID;
import java.util.stream.Collectors;
import org.hamcrest.Matchers;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.context.annotation.Import;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder;

/** What a worker sees of their team and of other teams (task 7A.4). */
@Import(TestcontainersConfiguration.class)
@SpringBootTest
@AutoConfigureMockMvc
class TeamVisibilityTests {

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

    @Autowired
    private JdbcTemplate jdbcTemplate;

    private static final UUID OTHER_ORGANIZATION = UUID.fromString("00000000-0000-0000-0000-0000000000a2");

    private User mia;
    private User max;
    private User wendy;
    private User will;
    private User otto;
    private Task wendysTask;
    private Task willsTask;
    private Task willsApprovedTask;
    private Task ottosTask;
    private Task formersTask;

    @BeforeEach
    void setUp() {
        mia = save("mia@example.com", "Mia Manager", null, RoleName.MANAGER);
        max = save("max@example.com", "Max Manager", null, RoleName.MANAGER);
        wendy = save("wendy@example.com", "Wendy Worker", mia, RoleName.WORKER);
        will = save("will@example.com", "Will Worker", mia, RoleName.WORKER);
        otto = save("otto@example.com", "Otto Other", max, RoleName.WORKER);
        User former = save("former@example.com", "Fred Former", mia, RoleName.WORKER);

        wendysTask = task(mia, "Wendy's kitchen", wendy, TaskAction.ASSIGN);
        willsTask = task(mia, "Will's hallway", will, TaskAction.ASSIGN, TaskAction.START);
        willsApprovedTask = task(mia, "Will's roof", will, TaskAction.ASSIGN, TaskAction.START, TaskAction.SUBMIT,
                TaskAction.APPROVE);
        task(mia, "Will's cancelled shed", will, TaskAction.ASSIGN, TaskAction.CANCEL);
        ottosTask = task(max, "Otto's garden", otto, TaskAction.ASSIGN);
        formersTask = task(mia, "Fred's attic", former, TaskAction.ASSIGN);
        former.deactivate();
        userRepository.save(former);
    }

    @AfterEach
    void tearDown() {
        taskRepository.deleteAll();
        userRepository.deleteAll();
        jdbcTemplate.update("delete from organizations where id = ?", OTHER_ORGANIZATION);
    }

    @Test
    void aWorkerSeesTheTasksOfTheirTeamMembersAsTiles() throws Exception {
        mockMvc.perform(as(wendy, get("/api/tasks/team")))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.content.length()").value(3))
                .andExpect(jsonPath("$.content[*].id").value(Matchers.containsInAnyOrder(
                        willsTask.getId().toString(), willsApprovedTask.getId().toString(),
                        formersTask.getId().toString())))
                .andExpect(jsonPath("$.content[0].assignee.fullName").exists())
                .andExpect(jsonPath("$.content[0].title").exists())
                .andExpect(jsonPath("$.content[0].description").doesNotExist())
                .andExpect(jsonPath("$.content[0].createdBy").doesNotExist());
    }

    @Test
    void theTeamTilesCanBeFilteredByStatus() throws Exception {
        mockMvc.perform(as(wendy, get("/api/tasks/team").param("status", "IN_PROGRESS")))
                .andExpect(jsonPath("$.content.length()").value(1))
                .andExpect(jsonPath("$.content[0].id").value(willsTask.getId().toString()));
    }

    @Test
    void aTeamMembersTaskStaysHiddenInFull() throws Exception {
        mockMvc.perform(as(wendy, get("/api/tasks/{id}", willsTask.getId()))).andExpect(status().isNotFound());
        mockMvc.perform(as(wendy, get("/api/tasks")))
                .andExpect(jsonPath("$.content.length()").value(1))
                .andExpect(jsonPath("$.content[0].id").value(wendysTask.getId().toString()));
    }

    @Test
    void aWorkerWithoutATeamSeesNoTeamTasks() throws Exception {
        User loner = save("loner@example.com", "Lou Loner", null, RoleName.WORKER);

        mockMvc.perform(as(loner, get("/api/tasks/team")))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.content.length()").value(0));
        mockMvc.perform(as(otto, get("/api/tasks/team")))
                .andExpect(jsonPath("$.content.length()").value(0));
        mockMvc.perform(as(mia, get("/api/tasks/team")))
                .andExpect(jsonPath("$.content.length()").value(0));
    }

    @Test
    void aDeactivatedManagersTeamIsNoTeam() throws Exception {
        max.deactivate();
        userRepository.save(max);

        mockMvc.perform(as(otto, get("/api/tasks/team"))).andExpect(jsonPath("$.content.length()").value(0));
        mockMvc.perform(as(otto, get("/api/teams")))
                .andExpect(jsonPath("$.length()").value(1))
                .andExpect(jsonPath("$[0].managerName").value("Mia Manager"))
                .andExpect(jsonPath("$[0].myTeam").value(false));
    }

    @Test
    void anotherOrganizationsTeamsAndTasksStayHidden() throws Exception {
        jdbcTemplate.update("insert into organizations (id, name) values (?, 'Other Org')", OTHER_ORGANIZATION);
        User stranger = saveIn(OTHER_ORGANIZATION, "olga@example.com", "Olga Outsider", null, RoleName.MANAGER);
        User strangersWorker = saveIn(OTHER_ORGANIZATION, "oscar@example.com", "Oscar Outsider", stranger,
                RoleName.WORKER);
        task(stranger, "Their office", strangersWorker, TaskAction.ASSIGN);
        // A worker of the other organization put into Mia's team must not leak either way.
        User crossWorker = saveIn(OTHER_ORGANIZATION, "cross@example.com", "Cora Cross", mia, RoleName.WORKER);
        task(stranger, "Their cellar", crossWorker, TaskAction.ASSIGN);

        mockMvc.perform(as(wendy, get("/api/teams")))
                .andExpect(jsonPath("$.length()").value(2))
                .andExpect(jsonPath("$[1].memberCount").value(2))
                .andExpect(jsonPath("$[1].unfinishedTaskCount").value(3));
        mockMvc.perform(as(wendy, get("/api/tasks/team")))
                .andExpect(jsonPath("$.content.length()").value(3));
        mockMvc.perform(as(strangersWorker, get("/api/teams")))
                .andExpect(jsonPath("$.length()").value(1))
                .andExpect(jsonPath("$[0].managerName").value("Olga Outsider"))
                .andExpect(jsonPath("$[0].unfinishedTaskCount").value(1));
    }

    @Test
    void otherTeamsAreShownOnlyAsNumbers() throws Exception {
        mockMvc.perform(as(wendy, get("/api/teams")))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.length()").value(2))
                .andExpect(jsonPath("$[0].managerName").value("Max Manager"))
                .andExpect(jsonPath("$[0].memberCount").value(1))
                .andExpect(jsonPath("$[0].unfinishedTaskCount").value(1))
                .andExpect(jsonPath("$[0].myTeam").value(false))
                .andExpect(jsonPath("$[1].managerId").value(mia.getId().toString()))
                .andExpect(jsonPath("$[1].memberCount").value(2))
                .andExpect(jsonPath("$[1].unfinishedTaskCount").value(3))
                .andExpect(jsonPath("$[1].myTeam").value(true));
        mockMvc.perform(as(save("ada@example.com", "Ada Admin", null, RoleName.ADMINISTRATOR), get("/api/teams")))
                .andExpect(jsonPath("$[*].myTeam").value(Matchers.everyItem(Matchers.is(false))));
        mockMvc.perform(as(max, get("/api/teams")))
                .andExpect(jsonPath("$[0].myTeam").value(true))
                .andExpect(jsonPath("$[1].myTeam").value(false));
        mockMvc.perform(get("/api/teams")).andExpect(status().isUnauthorized());
    }

    private Task task(User creator, String title, User worker, TaskAction... actions) {
        Task task = new Task(creator, title, "Details", TaskPriority.MEDIUM, Instant.parse("2026-12-01T09:00:00Z"),
                null);
        TaskFixtures.assign(task, worker);
        for (TaskAction action : actions) {
            stateMachine.apply(task, action);
        }
        return taskRepository.save(task);
    }

    private MockHttpServletRequestBuilder as(User user, MockHttpServletRequestBuilder request) {
        return request.header("Authorization", "Bearer " + jwtService.issueAccessToken(user).value());
    }

    private User save(String email, String name, User teamManager, RoleName... roles) {
        return saveIn(organizationRepository.getDefault().getId(), email, name, teamManager, roles);
    }

    private User saveIn(UUID organizationId, String email, String name, User teamManager, RoleName... roles) {
        User user = new User(organizationRepository.findById(organizationId).orElseThrow(), email, "hash", name,
                Arrays.stream(roles).map(r -> roleRepository.findByName(r).orElseThrow()).collect(Collectors.toSet()));
        user.joinTeamOf(teamManager);
        return userRepository.save(user);
    }

}
