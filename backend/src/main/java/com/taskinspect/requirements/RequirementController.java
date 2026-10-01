package com.taskinspect.requirements;

import com.taskinspect.common.config.OpenApiConfig;
import com.taskinspect.common.security.CurrentUser;
import com.taskinspect.common.security.Roles;
import com.taskinspect.requirements.dto.RequirementRequest;
import com.taskinspect.requirements.dto.RequirementResponse;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import java.net.URI;
import java.util.List;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/tasks/{taskId}/requirements")
@Tag(name = "Requirements")
@SecurityRequirement(name = OpenApiConfig.BEARER_AUTH)
public class RequirementController {

    private final RequirementService requirementService;

    public RequirementController(RequirementService requirementService) {
        this.requirementService = requirementService;
    }

    @GetMapping
    @Operation(summary = "List a task's requirements", description = "In the order the worker completes them.")
    public List<RequirementResponse> list(@AuthenticationPrincipal Jwt jwt, @PathVariable UUID taskId) {
        return requirementService.list(CurrentUser.from(jwt), taskId).stream().map(RequirementResponse::from)
                .toList();
    }

    @PostMapping
    @PreAuthorize(Roles.MANAGER)
    @Operation(summary = "Add a requirement", description = "Added at the end. Only the manager who created "
            + "the task, while it is DRAFT or ASSIGNED.")
    public ResponseEntity<RequirementResponse> create(@AuthenticationPrincipal Jwt jwt, @PathVariable UUID taskId,
            @Valid @RequestBody RequirementRequest request) {
        Requirement requirement = requirementService.create(CurrentUser.from(jwt), taskId, request);
        return ResponseEntity.created(URI.create("/api/tasks/" + taskId + "/requirements/" + requirement.getId()))
                .body(RequirementResponse.from(requirement));
    }

    @PutMapping("/{requirementId}")
    @PreAuthorize(Roles.MANAGER)
    @Operation(summary = "Change a requirement")
    public RequirementResponse update(@AuthenticationPrincipal Jwt jwt, @PathVariable UUID taskId,
            @PathVariable UUID requirementId, @Valid @RequestBody RequirementRequest request) {
        return RequirementResponse.from(
                requirementService.update(CurrentUser.from(jwt), taskId, requirementId, request));
    }

    @DeleteMapping("/{requirementId}")
    @PreAuthorize(Roles.MANAGER)
    @ResponseStatus(HttpStatus.NO_CONTENT)
    @Operation(summary = "Delete a requirement")
    public void delete(@AuthenticationPrincipal Jwt jwt, @PathVariable UUID taskId,
            @PathVariable UUID requirementId) {
        requirementService.delete(CurrentUser.from(jwt), taskId, requirementId);
    }

}
