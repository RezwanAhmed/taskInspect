package com.taskinspect.reviews;

import com.taskinspect.common.error.ApiException;
import com.taskinspect.tasks.Task;
import com.taskinspect.tasks.TaskStatus;
import java.util.Optional;
import java.util.Set;
import java.util.UUID;
import java.util.stream.Collectors;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Component;

/**
 * Which requirements the worker may change while correcting a task
 * (docs/architecture.md "Rules"): after a request for correction only the
 * marked ones, after a reject (or before any review) all of them.
 */
@Component
public class CorrectionScope {

    public static final String REQUIREMENT_NOT_MARKED = "REQUIREMENT_NOT_MARKED";

    private final ReviewRepository reviewRepository;

    public CorrectionScope(ReviewRepository reviewRepository) {
        this.reviewRepository = reviewRepository;
    }

    /**
     * The requirements marked for correction while the worker corrects the
     * task; empty when every requirement may be changed.
     */
    public Optional<Set<UUID>> markedRequirements(Task task) {
        if (task.getStatus() != TaskStatus.IN_PROGRESS) {
            return Optional.empty();
        }
        return reviewRepository.findFirstByTaskIdOrderByCreatedAtDescIdDesc(task.getId())
                .filter(review -> review.getResult() == ReviewResult.CORRECTION_REQUESTED)
                .map(review -> review.getMarkedRequirements().stream()
                        .map(MarkedRequirement::getRequirementId)
                        .collect(Collectors.toSet()));
    }

    /** 409 REQUIREMENT_NOT_MARKED when the task is being corrected and the requirement was not marked. */
    public void requireChangeable(Task task, UUID requirementId) {
        if (markedRequirements(task).map(marked -> !marked.contains(requirementId)).orElse(false)) {
            throw new ApiException(HttpStatus.CONFLICT, REQUIREMENT_NOT_MARKED,
                    "Only the requirements marked for correction can be changed");
        }
    }

}
