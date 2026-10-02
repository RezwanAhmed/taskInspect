package com.taskinspect.users;

import com.taskinspect.common.config.OpenApiConfig;
import com.taskinspect.common.security.CurrentUser;
import com.taskinspect.common.security.Roles;
import com.taskinspect.common.web.PageResponse;
import com.taskinspect.users.dto.CreateUserRequest;
import com.taskinspect.users.dto.SetTeamRequest;
import com.taskinspect.users.dto.UserResponse;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import java.net.URI;
import java.util.UUID;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Sort;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/users")
@Tag(name = "Users")
@SecurityRequirement(name = OpenApiConfig.BEARER_AUTH)
public class UserController {

    private final UserService userService;

    public UserController(UserService userService) {
        this.userService = userService;
    }

    @GetMapping
    @PreAuthorize(Roles.ADMIN_OR_MANAGER)
    @Operation(summary = "List users", description = "Administrators and managers. Filter by role, "
            + "e.g. `?role=WORKER` to choose who to assign a task to, or `?teamManagerId=...` for a manager's team "
            + "(then `role` is not used).")
    public PageResponse<UserResponse> list(@AuthenticationPrincipal Jwt jwt,
            @RequestParam(required = false) RoleName role,
            @RequestParam(required = false) UUID teamManagerId,
            @RequestParam(defaultValue = "0") @Min(0) int page,
            @RequestParam(defaultValue = "20") @Min(1) @Max(100) int size) {
        PageRequest pageable = PageRequest.of(page, size, Sort.by("fullName", "email"));
        CurrentUser caller = CurrentUser.from(jwt);
        return PageResponse.of(teamManagerId != null
                ? userService.listTeam(caller, teamManagerId, pageable)
                : userService.list(caller, role, pageable), UserResponse::from);
    }

    @PutMapping("/{id}/team")
    @PreAuthorize(Roles.ADMIN)
    @Operation(summary = "Set a worker's team", description = "Administrators only. {\"managerId\": \"...\"} puts "
            + "the worker into that manager's team (a worker is in one team); {\"managerId\": null} takes them out.")
    public UserResponse setTeam(@AuthenticationPrincipal Jwt jwt, @PathVariable UUID id,
            @RequestBody SetTeamRequest request) {
        return UserResponse.from(userService.setTeam(CurrentUser.from(jwt), id, request.managerId()));
    }

    @GetMapping("/{id}")
    @Operation(summary = "Get a user", description = "Administrators and managers see any user of their "
            + "organization; other users only themselves.")
    public UserResponse get(@AuthenticationPrincipal Jwt jwt, @PathVariable UUID id) {
        return UserResponse.from(userService.get(CurrentUser.from(jwt), id));
    }

    @PostMapping
    @PreAuthorize(Roles.ADMIN)
    @Operation(summary = "Create a user", description = "Administrators only. The password is stored as a "
            + "BCrypt hash.")
    public ResponseEntity<UserResponse> create(@AuthenticationPrincipal Jwt jwt,
            @Valid @RequestBody CreateUserRequest request) {
        User user = userService.create(CurrentUser.from(jwt), request);
        return ResponseEntity.created(URI.create("/api/users/" + user.getId())).body(UserResponse.from(user));
    }

}
