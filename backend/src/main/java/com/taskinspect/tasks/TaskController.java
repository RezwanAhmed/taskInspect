package com.taskinspect.tasks;

import com.taskinspect.common.config.OpenApiConfig;
import com.taskinspect.common.security.CurrentUser;
import com.taskinspect.common.security.Roles;
import com.taskinspect.common.web.PageResponse;
import com.taskinspect.tasks.dto.AssignTaskRequest;
import com.taskinspect.tasks.dto.CreateTaskRequest;
import com.taskinspect.tasks.dto.PublishTaskRequest;
import com.taskinspect.tasks.dto.TaskResponse;
import com.taskinspect.tasks.dto.TaskTile;
import com.taskinspect.tasks.dto.UpdateTaskRequest;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import java.net.URI;
import java.time.Instant;
import java.util.List;
import java.util.UUID;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Sort;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/tasks")
@Tag(name = "Tasks")
@SecurityRequirement(name = OpenApiConfig.BEARER_AUTH)
public class TaskController {

    private final TaskService taskService;
    private final TaskAssignmentService assignmentService;

    public TaskController(TaskService taskService, TaskAssignmentService assignmentService) {
        this.taskService = taskService;
        this.assignmentService = assignmentService;
    }

    @GetMapping
    @Operation(summary = "List tasks", description = "Tasks the caller may see, sorted by due date. "
            + "Optional filters: status, priority, dueFrom / dueBefore (ISO-8601 instants).")
    public PageResponse<TaskResponse> list(@AuthenticationPrincipal Jwt jwt,
            @RequestParam(required = false) TaskStatus status,
            @RequestParam(required = false) TaskPriority priority,
            @RequestParam(required = false) Instant dueFrom,
            @RequestParam(required = false) Instant dueBefore,
            @RequestParam(defaultValue = "0") @Min(0) int page,
            @RequestParam(defaultValue = "20") @Min(1) @Max(100) int size) {
        PageRequest pageable = PageRequest.of(page, size, Sort.by("dueDate", "createdAt"));
        TaskService.TaskFilter filter = new TaskService.TaskFilter(status, priority, dueFrom, dueBefore);
        return PageResponse.of(taskService.list(CurrentUser.from(jwt), filter, pageable), TaskResponse::from);
    }

    @GetMapping("/team")
    @Operation(summary = "List my team's tasks", description = "The tasks of the caller's team members (not the "
            + "caller's own) as tiles: no description, requirements, answers or evidence. Cancelled tasks are left "
            + "out; empty for a caller without a team. Optional filter: status.")
    public PageResponse<TaskTile> listTeam(@AuthenticationPrincipal Jwt jwt,
            @RequestParam(required = false) TaskStatus status,
            @RequestParam(defaultValue = "0") @Min(0) int page,
            @RequestParam(defaultValue = "20") @Min(1) @Max(100) int size) {
        PageRequest pageable = PageRequest.of(page, size, Sort.by("dueDate", "createdAt"));
        return PageResponse.of(taskService.listTeam(CurrentUser.from(jwt), status, pageable), TaskTile::from);
    }

    @GetMapping("/{id}")
    @Operation(summary = "Get a task")
    public TaskResponse get(@AuthenticationPrincipal Jwt jwt, @PathVariable UUID id) {
        return TaskResponse.from(taskService.get(CurrentUser.from(jwt), id));
    }

    @PutMapping("/{id}")
    @PreAuthorize(Roles.ADMIN_OR_MANAGER)
    @Operation(summary = "Edit a task", description = "Only the manager (or administrator) who created the task, "
            + "and only while it is DRAFT, OPEN or ASSIGNED. Send the `version` you last received; if the task changed "
            + "since, the answer is 409 VERSION_CONFLICT.")
    public TaskResponse update(@AuthenticationPrincipal Jwt jwt, @PathVariable UUID id,
            @Valid @RequestBody UpdateTaskRequest request) {
        return TaskResponse.from(taskService.update(CurrentUser.from(jwt), id, request));
    }

    @PostMapping("/{id}/assign")
    @PreAuthorize(Roles.ADMIN_OR_MANAGER)
    @Operation(summary = "Assign a task to a worker", description = "DRAFT → ASSIGNED. Only the manager who "
            + "created the task; it needs at least one requirement, the assignee must be an active worker, "
            + "and the reviewer cannot be the assignee (except a personal task assigned to yourself). "
            + "An administrator's main task is assigned to an active manager instead, without requirements.")
    public TaskResponse assign(@AuthenticationPrincipal Jwt jwt, @PathVariable UUID id,
            @Valid @RequestBody AssignTaskRequest request) {
        return TaskResponse.from(assignmentService.assign(CurrentUser.from(jwt), id, request.assigneeId()));
    }

    @PostMapping("/{id}/publish")
    @PreAuthorize(Roles.MANAGER)
    @Operation(summary = "Publish a task as an open task", description = "DRAFT → OPEN, without an assignee. "
            + "Only the manager who created the task; it needs at least one requirement. `scope` says who may "
            + "take it: TEAM (the manager's team; 409 TEAM_HAS_NO_MEMBERS when it has no active worker) or "
            + "EVERYONE (every worker of the organization).")
    public TaskResponse publish(@AuthenticationPrincipal Jwt jwt, @PathVariable UUID id,
            @Valid @RequestBody PublishTaskRequest request) {
        return TaskResponse.from(assignmentService.publish(CurrentUser.from(jwt), id, request.scope()));
    }

    @PostMapping("/{id}/sub-tasks")
    @PreAuthorize(Roles.MANAGER)
    @Operation(summary = "Add a sub-task to a main task", description = "Only the manager the main task is "
            + "assigned to, while it is ASSIGNED, IN_PROGRESS, REJECTED or CORRECTION_REQUESTED (409 "
            + "MAIN_TASK_CLOSED otherwise; 409 NOT_A_MAIN_TASK for other tasks). The sub-task starts as DRAFT and "
            + "is assigned or published like any task; without `reviewerId` the manager reviews it.")
    public ResponseEntity<TaskResponse> createSubTask(@AuthenticationPrincipal Jwt jwt, @PathVariable UUID id,
            @Valid @RequestBody CreateTaskRequest request) {
        Task task = taskService.createSubTask(CurrentUser.from(jwt), id, request);
        return ResponseEntity.created(URI.create("/api/tasks/" + task.getId())).body(TaskResponse.from(task));
    }

    @GetMapping("/{id}/sub-tasks")
    @PreAuthorize(Roles.ADMIN_OR_MANAGER)
    @Operation(summary = "List a main task's sub-tasks", description = "Oldest first; empty for other tasks.")
    public List<TaskResponse> listSubTasks(@AuthenticationPrincipal Jwt jwt, @PathVariable UUID id) {
        return taskService.listSubTasks(CurrentUser.from(jwt), id).stream().map(TaskResponse::from).toList();
    }

    @PostMapping("/{id}/reissue")
    @PreAuthorize(Roles.MANAGER)
    @Operation(summary = "Register a task again for the same worker", description = "Only the manager who created "
            + "the task, once work has started (IN_PROGRESS, SUBMITTED, REJECTED, CORRECTION_REQUESTED or APPROVED; "
            + "409 TASK_NOT_REISSUABLE otherwise and for main tasks). The new task copies the details and "
            + "requirements, links to the original (`reissuedFromId`) and starts as ASSIGNED to the same worker, "
            + "so it can still be edited before the worker starts.")
    public ResponseEntity<TaskResponse> reissue(@AuthenticationPrincipal Jwt jwt, @PathVariable UUID id) {
        Task task = assignmentService.reissue(CurrentUser.from(jwt), id);
        return ResponseEntity.created(URI.create("/api/tasks/" + task.getId())).body(TaskResponse.from(task));
    }

    @PostMapping("/{id}/take")
    @PreAuthorize(Roles.WORKER)
    @Operation(summary = "Take an open task", description = "OPEN → ASSIGNED; the caller becomes the task's worker. "
            + "Only a worker the task is open to (its scope EVERYONE, or TEAM and the worker is in the publishing "
            + "manager's team); 404 otherwise. The first worker wins: the others get 409 TASK_ALREADY_TAKEN. "
            + "Taking a task the caller already took returns it unchanged.")
    public TaskResponse take(@AuthenticationPrincipal Jwt jwt, @PathVariable UUID id) {
        return TaskResponse.from(assignmentService.take(CurrentUser.from(jwt), id));
    }

    @PostMapping("/{id}/start")
    @PreAuthorize(Roles.WORKER_OR_MANAGER)
    @Operation(summary = "Start working on a task", description = "The assigned worker only (for a main task: "
            + "the assigned manager). ASSIGNED → IN_PROGRESS; also used to work on the task again after a reject "
            + "or a correction request.")
    public TaskResponse start(@AuthenticationPrincipal Jwt jwt, @PathVariable UUID id) {
        return TaskResponse.from(taskService.start(CurrentUser.from(jwt), id));
    }

    @PostMapping
    @PreAuthorize(Roles.ADMIN_OR_MANAGER)
    @Operation(summary = "Create a draft task", description = "Managers and administrators. The task starts as "
            + "DRAFT; without `reviewerId` the creator reviews it. An administrator's task is a main task for a "
            + "manager; its reviewer must be an administrator.")
    public ResponseEntity<TaskResponse> create(@AuthenticationPrincipal Jwt jwt,
            @Valid @RequestBody CreateTaskRequest request) {
        Task task = taskService.create(CurrentUser.from(jwt), request);
        return ResponseEntity.created(URI.create("/api/tasks/" + task.getId())).body(TaskResponse.from(task));
    }

}
