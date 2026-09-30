package com.taskinspect.tasks;

import com.taskinspect.common.config.OpenApiConfig;
import com.taskinspect.common.security.CurrentUser;
import com.taskinspect.common.security.Roles;
import com.taskinspect.common.web.PageResponse;
import com.taskinspect.tasks.dto.CreateTaskRequest;
import com.taskinspect.tasks.dto.TaskResponse;
import com.taskinspect.tasks.dto.UpdateTaskRequest;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import java.net.URI;
import java.time.Instant;
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

    public TaskController(TaskService taskService) {
        this.taskService = taskService;
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

    @GetMapping("/{id}")
    @Operation(summary = "Get a task")
    public TaskResponse get(@AuthenticationPrincipal Jwt jwt, @PathVariable UUID id) {
        return TaskResponse.from(taskService.get(CurrentUser.from(jwt), id));
    }

    @PutMapping("/{id}")
    @PreAuthorize(Roles.MANAGER)
    @Operation(summary = "Edit a task", description = "Only the manager who created the task, and only "
            + "while it is DRAFT or ASSIGNED. Send the `version` you last received; if the task changed "
            + "since, the answer is 409 VERSION_CONFLICT.")
    public TaskResponse update(@AuthenticationPrincipal Jwt jwt, @PathVariable UUID id,
            @Valid @RequestBody UpdateTaskRequest request) {
        return TaskResponse.from(taskService.update(CurrentUser.from(jwt), id, request));
    }

    @PostMapping
    @PreAuthorize(Roles.MANAGER)
    @Operation(summary = "Create a draft task", description = "Managers only. The task starts as DRAFT; "
            + "without `reviewerId` the creator reviews it.")
    public ResponseEntity<TaskResponse> create(@AuthenticationPrincipal Jwt jwt,
            @Valid @RequestBody CreateTaskRequest request) {
        Task task = taskService.create(CurrentUser.from(jwt), request);
        return ResponseEntity.created(URI.create("/api/tasks/" + task.getId())).body(TaskResponse.from(task));
    }

}
