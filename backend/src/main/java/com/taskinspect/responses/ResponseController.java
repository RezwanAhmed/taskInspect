package com.taskinspect.responses;

import com.taskinspect.common.config.OpenApiConfig;
import com.taskinspect.common.security.CurrentUser;
import com.taskinspect.common.security.Roles;
import com.taskinspect.responses.dto.ResponseView;
import com.taskinspect.responses.dto.SaveResponseRequest;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import java.util.List;
import java.util.UUID;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/tasks/{taskId}")
@Tag(name = "Responses")
@SecurityRequirement(name = OpenApiConfig.BEARER_AUTH)
public class ResponseController {

    private final ResponseService responseService;

    public ResponseController(ResponseService responseService) {
        this.responseService = responseService;
    }

    @GetMapping("/responses")
    @Operation(summary = "List the answers of a task")
    public List<ResponseView> list(@AuthenticationPrincipal Jwt jwt, @PathVariable UUID taskId) {
        return responseService.list(CurrentUser.from(jwt), taskId).stream().map(ResponseView::from).toList();
    }

    @PutMapping("/requirements/{requirementId}/response")
    @PreAuthorize(Roles.WORKER)
    @Operation(summary = "Answer a requirement", description = "The assigned worker, while the task is "
            + "IN_PROGRESS. Creates or replaces the answer, so it is safe to send again.")
    public ResponseView save(@AuthenticationPrincipal Jwt jwt, @PathVariable UUID taskId,
            @PathVariable UUID requirementId, @Valid @RequestBody SaveResponseRequest request) {
        return ResponseView.from(responseService.save(CurrentUser.from(jwt), taskId, requirementId, request));
    }

}
