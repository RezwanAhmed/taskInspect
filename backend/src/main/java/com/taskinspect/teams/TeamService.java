package com.taskinspect.teams;

import com.taskinspect.common.security.CurrentUser;
import com.taskinspect.tasks.TaskRepository;
import com.taskinspect.teams.dto.TeamSummary;
import com.taskinspect.users.RoleName;
import com.taskinspect.users.User;
import com.taskinspect.users.UserRepository;
import com.taskinspect.users.UserService;
import java.util.Comparator;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.stream.Collectors;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/** The teams of an organization in numbers (one team per active manager). */
@Service
public class TeamService {

    private final UserService userService;
    private final UserRepository userRepository;
    private final TaskRepository taskRepository;

    public TeamService(UserService userService, UserRepository userRepository, TaskRepository taskRepository) {
        this.userService = userService;
        this.userRepository = userRepository;
        this.taskRepository = taskRepository;
    }

    /**
     * Every team of the caller's organization, sorted by the manager's name.
     * A deactivated manager's team is not listed (their workers have no team
     * until an administrator moves them).
     */
    @Transactional(readOnly = true)
    public List<TeamSummary> list(CurrentUser caller) {
        User user = userService.requireCaller(caller);
        UUID organizationId = user.getOrganization().getId();
        UUID myTeam = user.getTeamManager() != null ? user.getTeamManager().getId() : user.getId();
        Map<UUID, Long> members = countsPerTeam(userRepository.countActiveMembersPerTeam(organizationId));
        Map<UUID, Long> tasks = countsPerTeam(taskRepository.countUnfinishedTasksPerTeam(organizationId));
        return userRepository.findAllByOrganizationIdAndRolesNameAndActiveTrue(organizationId, RoleName.MANAGER)
                .stream()
                .sorted(Comparator.comparing(User::getFullName).thenComparing(User::getId))
                .map(manager -> new TeamSummary(manager.getId(), manager.getFullName(),
                        members.getOrDefault(manager.getId(), 0L), tasks.getOrDefault(manager.getId(), 0L),
                        manager.getId().equals(myTeam)))
                .toList();
    }

    private static Map<UUID, Long> countsPerTeam(List<Object[]> rows) {
        return rows.stream().collect(Collectors.toMap(row -> (UUID) row[0], row -> (Long) row[1]));
    }

}
