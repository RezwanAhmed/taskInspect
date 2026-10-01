package com.taskinspect.sync;

import com.taskinspect.common.security.CurrentUser;
import com.taskinspect.requirements.RequirementService;
import com.taskinspect.requirements.dto.RequirementResponse;
import com.taskinspect.reviews.ReviewRepository;
import com.taskinspect.reviews.dto.ReviewResponse;
import com.taskinspect.sync.dto.SyncPullResponse;
import com.taskinspect.tasks.Task;
import com.taskinspect.tasks.TaskService;
import com.taskinspect.tasks.dto.TaskResponse;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.util.List;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * GET /api/sync/pull: the tasks that changed on the server since the app's
 * last pull (docs/architecture.md, "Sync Cycle"), with the same visibility
 * rules as the task list.
 */
@Service
public class SyncPullService {

    /**
     * Changes from shortly before the cursor are sent again, so a change that
     * was committed while the previous pull ran is never missed. The app
     * simply stores them once more.
     */
    static final Duration OVERLAP = Duration.ofMinutes(1);

    private final TaskService taskService;
    private final RequirementService requirementService;
    private final ReviewRepository reviewRepository;
    private final Clock clock;

    public SyncPullService(TaskService taskService, RequirementService requirementService,
            ReviewRepository reviewRepository, Clock clock) {
        this.taskService = taskService;
        this.requirementService = requirementService;
        this.reviewRepository = reviewRepository;
        this.clock = clock;
    }

    /** Everything when {@code since} is {@code null} (first pull or after sign in). */
    @Transactional(readOnly = true)
    public SyncPullResponse pull(CurrentUser caller, Instant since) {
        Instant cursor = clock.instant();
        List<Task> visible = taskService.listVisible(caller);
        Instant from = since == null ? null : since.minus(OVERLAP);
        List<SyncPullResponse.PulledTask> changed = visible.stream()
                .filter(task -> from == null || !task.getUpdatedAt().isBefore(from))
                .map(task -> new SyncPullResponse.PulledTask(TaskResponse.from(task),
                        requirementService.listForTask(task.getId()).stream().map(RequirementResponse::from).toList(),
                        reviewRepository.findFirstByTaskIdOrderByCreatedAtDescIdDesc(task.getId())
                                .map(ReviewResponse::from).orElse(null)))
                .toList();
        return new SyncPullResponse(cursor, visible.stream().map(Task::getId).toList(), changed);
    }

}
