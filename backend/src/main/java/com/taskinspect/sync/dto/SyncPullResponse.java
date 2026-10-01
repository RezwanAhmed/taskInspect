package com.taskinspect.sync.dto;

import com.taskinspect.requirements.dto.RequirementResponse;
import com.taskinspect.reviews.dto.ReviewResponse;
import com.taskinspect.tasks.dto.TaskResponse;
import java.time.Instant;
import java.util.List;
import java.util.UUID;

/**
 * What changed on the server since the last pull.
 *
 * @param cursor  send it as {@code since} in the next pull
 * @param taskIds every task the user may see now; the app removes the others
 * @param tasks   the tasks that changed (all of them on the first pull), with their requirements and
 *                latest review
 */
public record SyncPullResponse(Instant cursor, List<UUID> taskIds, List<PulledTask> tasks) {

    /**
     * @param latestReview the task's latest review ({@code null} if none): the reason of a reject, or the
     *                     requirements marked for correction with their comments
     */
    public record PulledTask(TaskResponse task, List<RequirementResponse> requirements, ReviewResponse latestReview) {
    }

}
