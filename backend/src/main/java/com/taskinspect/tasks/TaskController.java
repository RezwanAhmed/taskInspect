package com.taskinspect.tasks;

import com.taskinspect.common.config.OpenApiConfig;
import com.taskinspect.common.security.CurrentUser;
import com.taskinspect.common.security.Roles;
import com.taskinspect.tasks.dto.CreateTaskRequest;
import com.taskinspect.tasks.dto.TaskResponse;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import java.net.URI;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
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
