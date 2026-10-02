package com.taskinspect.teams;

import com.taskinspect.common.config.OpenApiConfig;
import com.taskinspect.common.security.CurrentUser;
import com.taskinspect.teams.dto.TeamSummary;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import java.util.List;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/teams")
@Tag(name = "Teams")
@SecurityRequirement(name = OpenApiConfig.BEARER_AUTH)
public class TeamController {

    private final TeamService teamService;

    public TeamController(TeamService teamService) {
        this.teamService = teamService;
    }

    @GetMapping
    @Operation(summary = "List teams", description = "Every manager's team in numbers: active members and tasks "
            + "not approved or cancelled yet. `myTeam` marks the caller's own team.")
    public List<TeamSummary> list(@AuthenticationPrincipal Jwt jwt) {
        return teamService.list(CurrentUser.from(jwt));
    }

}
