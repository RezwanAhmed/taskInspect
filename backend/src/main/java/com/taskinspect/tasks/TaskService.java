package com.taskinspect.tasks;

import static com.taskinspect.tasks.TaskSpecifications.dueBefore;
import static com.taskinspect.tasks.TaskSpecifications.dueFrom;
import static com.taskinspect.tasks.TaskSpecifications.hasPriority;
import static com.taskinspect.tasks.TaskSpecifications.hasStatus;
import static com.taskinspect.tasks.TaskSpecifications.inOrganization;

import com.taskinspect.common.error.ApiException;
import com.taskinspect.common.security.CurrentUser;
import com.taskinspect.tasks.dto.CreateTaskRequest;
import com.taskinspect.users.RoleName;
import com.taskinspect.users.User;
import com.taskinspect.users.UserService;
import java.time.Instant;
import java.util.UUID;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.domain.Specification;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class TaskService {

    static final String INVALID_REVIEWER = "INVALID_REVIEWER";
    static final String TASK_NOT_FOUND = "TASK_NOT_FOUND";

    private final TaskRepository taskRepository;
    private final UserService userService;

    public TaskService(TaskRepository taskRepository, UserService userService) {
        this.taskRepository = taskRepository;
        this.userService = userService;
    }

    /**
     * Creates a draft task in the creator's organization. The reviewer must be
     * an active manager of the same organization; by default it is the creator.
     */
    @Transactional
    public Task create(CurrentUser caller, CreateTaskRequest request) {
        User creator = userService.requireCaller(caller);
        User reviewer = request.reviewerId() == null ? null
                : userService.requireActiveWithRole(request.reviewerId(), creator.getOrganization().getId(),
                        RoleName.MANAGER, INVALID_REVIEWER, "The reviewer must be an active manager");
        String description = request.description() == null || request.description().isBlank()
                ? null : request.description().trim();
        return taskRepository.save(new Task(creator, request.title().trim(), description, request.priority(),
                request.dueDate(), reviewer));
    }


    /**
     * Tasks the caller may see, filtered and paged. Administrators and
     * managers see every task of their organization. Workers see only the
     * tasks assigned to them (assignments are added in task 3.9, so for now
     * they see none).
     */
    @Transactional(readOnly = true)
    public Page<Task> list(CurrentUser caller, TaskFilter filter, Pageable pageable) {
        User user = userService.requireCaller(caller);
        Specification<Task> visible = canSeeAllTasks(user)
                ? inOrganization(user.getOrganization().getId())
                : (task, query, cb) -> cb.disjunction();
        return taskRepository.findAll(Specification.allOf(visible, hasStatus(filter.status()),
                hasPriority(filter.priority()), dueFrom(filter.dueFrom()), dueBefore(filter.dueBefore())), pageable);
    }

    /** One task the caller may see; 404 for tasks that don't exist or aren't visible. */
    @Transactional(readOnly = true)
    public Task get(CurrentUser caller, UUID id) {
        User user = userService.requireCaller(caller);
        return taskRepository.findByIdAndOrganizationId(id, user.getOrganization().getId())
                .filter(task -> canSeeAllTasks(user))
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, TASK_NOT_FOUND, "Task not found"));
    }

    private static boolean canSeeAllTasks(User user) {
        return user.hasRole(RoleName.ADMINISTRATOR) || user.hasRole(RoleName.MANAGER);
    }

    /** Optional filters for the task list; {@code null} means "any". */
    public record TaskFilter(TaskStatus status, TaskPriority priority, Instant dueFrom, Instant dueBefore) {
    }

}
