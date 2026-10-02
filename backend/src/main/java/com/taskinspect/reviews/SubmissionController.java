package com.taskinspect.reviews;

import com.taskinspect.common.config.OpenApiConfig;
import com.taskinspect.common.security.CurrentUser;
import com.taskinspect.common.security.Roles;
import com.taskinspect.tasks.dto.TaskResponse;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import java.util.UUID;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/tasks/{id}")
@Tag(name = "Review")
@SecurityRequirement(name = OpenApiConfig.BEARER_AUTH)
public class SubmissionController {

    private final SubmissionService submissionService;

    public SubmissionController(SubmissionService submissionService) {
        this.submissionService = submissionService;
    }

    @PostMapping("/submit")
    @PreAuthorize(Roles.WORKER_OR_MANAGER)
    @Operation(summary = "Submit a task for review", description = "The assigned worker only. IN_PROGRESS → "
            + "SUBMITTED. Every required requirement needs an answer (or an uploaded file for PHOTO / DOCUMENT), "
            + "and no file may still be waiting for its upload: 409 REQUIREMENTS_MISSING (the missing "
            + "requirements are listed in errors, field = requirement ID) or 409 EVIDENCE_NOT_UPLOADED. "
            + "A main task is submitted by its manager once it has sub-tasks and every one that is not "
            + "cancelled is approved: 409 NO_SUB_TASKS or 409 SUB_TASKS_NOT_APPROVED (listed in errors, "
            + "field = sub-task ID).")
    public TaskResponse submit(@AuthenticationPrincipal Jwt jwt, @PathVariable UUID id) {
        return TaskResponse.from(submissionService.submit(CurrentUser.from(jwt), id));
    }

}
