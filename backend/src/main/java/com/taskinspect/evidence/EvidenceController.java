package com.taskinspect.evidence;

import com.taskinspect.common.config.OpenApiConfig;
import com.taskinspect.common.security.CurrentUser;
import com.taskinspect.common.security.Roles;
import com.taskinspect.evidence.dto.EvidenceResponse;
import com.taskinspect.evidence.dto.RegisterEvidenceRequest;
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
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/tasks/{taskId}")
@Tag(name = "Evidence")
@SecurityRequirement(name = OpenApiConfig.BEARER_AUTH)
public class EvidenceController {

    private final EvidenceService evidenceService;

    public EvidenceController(EvidenceService evidenceService) {
        this.evidenceService = evidenceService;
    }

    @GetMapping("/evidence")
    @Operation(summary = "List a task's evidence files")
    public List<EvidenceResponse> list(@AuthenticationPrincipal Jwt jwt, @PathVariable UUID taskId) {
        return evidenceService.list(CurrentUser.from(jwt), taskId).stream().map(EvidenceResponse::from).toList();
    }

    @PostMapping("/requirements/{requirementId}/evidence")
    @PreAuthorize(Roles.WORKER)
    @Operation(summary = "Register an evidence file before uploading it",
            description = "The assigned worker, while IN_PROGRESS. PHOTO: image/jpeg or image/png, max 10 MB; "
                    + "DOCUMENT: application/pdf, max 20 MB. The ID is created on the device; sending the same "
                    + "request again returns 200 with the existing evidence.")
    public ResponseEntity<EvidenceResponse> register(@AuthenticationPrincipal Jwt jwt, @PathVariable UUID taskId,
            @PathVariable UUID requirementId, @Valid @RequestBody RegisterEvidenceRequest request) {
        EvidenceService.Registration registration =
                evidenceService.register(CurrentUser.from(jwt), taskId, requirementId, request);
        EvidenceResponse body = EvidenceResponse.from(registration.evidence());
        return registration.created()
                ? ResponseEntity.created(URI.create("/api/tasks/" + taskId + "/evidence/" + body.id())).body(body)
                : ResponseEntity.ok(body);
    }

    @DeleteMapping("/evidence/{evidenceId}")
    @PreAuthorize(Roles.WORKER)
    @ResponseStatus(HttpStatus.NO_CONTENT)
    @Operation(summary = "Remove an evidence file", description = "The assigned worker, while IN_PROGRESS.")
    public void delete(@AuthenticationPrincipal Jwt jwt, @PathVariable UUID taskId, @PathVariable UUID evidenceId) {
        evidenceService.delete(CurrentUser.from(jwt), taskId, evidenceId);
    }

}
