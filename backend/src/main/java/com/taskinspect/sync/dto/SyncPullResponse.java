package com.taskinspect.sync.dto;

import com.taskinspect.requirements.dto.RequirementResponse;
import com.taskinspect.reviews.dto.ReviewResponse;
import com.taskinspect.tasks.dto.TaskResponse;
import com.taskinspect.tasks.dto.TaskTile;
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
 * @param tileIds every tile (team member's task) the user may see now; the app removes the others
 * @param tiles   the tiles that changed (all of them on the first pull), without requirements
 * @param teamVersion changes whenever the user's team changes; when it differs from the last pull,
 *                the app pulls again without {@code since}
 */
public record SyncPullResponse(Instant cursor, List<UUID> taskIds, List<PulledTask> tasks, List<UUID> tileIds,
        List<TaskTile> tiles, String teamVersion) {

    /**
     * @param latestReview the task's latest review ({@code null} if none): the reason of a reject, or the
     *                     requirements marked for correction with their comments
     */
    public record PulledTask(TaskResponse task, List<RequirementResponse> requirements, ReviewResponse latestReview) {
    }

}
