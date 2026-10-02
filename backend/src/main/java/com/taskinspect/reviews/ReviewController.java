package com.taskinspect.reviews;

import com.taskinspect.common.config.OpenApiConfig;
import com.taskinspect.common.security.CurrentUser;
import com.taskinspect.common.security.Roles;
import com.taskinspect.reviews.dto.ApproveRequest;
import com.taskinspect.reviews.dto.CorrectionRequest;
import com.taskinspect.reviews.dto.RejectRequest;
import com.taskinspect.reviews.dto.ReviewResponse;
import com.taskinspect.tasks.dto.TaskResponse;
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
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/tasks/{id}")
@Tag(name = "Review")
@SecurityRequirement(name = OpenApiConfig.BEARER_AUTH)
public class ReviewController {

    private static final String WHO = "The task's reviewer (a manager; an administrator for a main task), never its "
            + "worker - except a personal task a manager assigned to themself. ";

    private final ReviewService reviewService;

    public ReviewController(ReviewService reviewService) {
        this.reviewService = reviewService;
    }

    @PostMapping("/approve")
    @PreAuthorize(Roles.ADMIN_OR_MANAGER)
    @Operation(summary = "Approve a submitted task", description = WHO + "SUBMITTED → APPROVED (final). "
            + "Optional body: {\"comment\": \"...\"}.")
    public TaskResponse approve(@AuthenticationPrincipal Jwt jwt, @PathVariable UUID id,
            @Valid @RequestBody(required = false) ApproveRequest request) {
        return TaskResponse.from(reviewService.approve(CurrentUser.from(jwt), id,
                request == null ? null : request.comment()));
    }

    @PostMapping("/reject")
    @PreAuthorize(Roles.ADMIN_OR_MANAGER)
    @Operation(summary = "Reject a submitted task", description = WHO + "SUBMITTED → REJECTED with a reason; the "
            + "worker can change every answer and photo, then submits again.")
    public TaskResponse reject(@AuthenticationPrincipal Jwt jwt, @PathVariable UUID id,
            @Valid @RequestBody RejectRequest request) {
        return TaskResponse.from(reviewService.reject(CurrentUser.from(jwt), id, request.reason()));
    }

    @PostMapping("/request-correction")
    @PreAuthorize(Roles.ADMIN_OR_MANAGER)
    @Operation(summary = "Request a correction", description = WHO + "SUBMITTED → CORRECTION_REQUESTED. At least "
            + "one requirement of the task is marked, each with a comment; only those go back to the worker.")
    public TaskResponse requestCorrection(@AuthenticationPrincipal Jwt jwt, @PathVariable UUID id,
            @Valid @RequestBody CorrectionRequest request) {
        return TaskResponse.from(reviewService.requestCorrection(CurrentUser.from(jwt), id, request));
    }

    @GetMapping("/reviews")
    @Operation(summary = "List a task's reviews", description = "Oldest first; anyone who can see the task.")
    public List<ReviewResponse> list(@AuthenticationPrincipal Jwt jwt, @PathVariable UUID id) {
        return reviewService.list(CurrentUser.from(jwt), id).stream().map(ReviewResponse::from).toList();
    }

}
