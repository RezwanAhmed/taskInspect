package com.taskinspect.reviews.dto;

import com.taskinspect.reviews.Review;
import com.taskinspect.reviews.ReviewResult;
import com.taskinspect.tasks.dto.TaskResponse.UserRef;
import java.time.Instant;
import java.util.List;
import java.util.UUID;

/** A review as returned by the API. */
public record ReviewResponse(
        UUID id,
        ReviewResult result,
        String reason,
        UserRef reviewer,
        List<MarkedRequirementResponse> requirements,
        Instant createdAt) {

    public static ReviewResponse from(Review review) {
        return new ReviewResponse(review.getId(), review.getResult(), review.getReason(),
                UserRef.from(review.getReviewer()),
                review.getMarkedRequirements().stream()
                        .map(m -> new MarkedRequirementResponse(m.getRequirementId(), m.getComment()))
                        .toList(),
                review.getCreatedAt());
    }

    public record MarkedRequirementResponse(UUID requirementId, String comment) {
    }

}
