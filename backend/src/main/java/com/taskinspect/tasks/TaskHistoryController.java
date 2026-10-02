package com.taskinspect.tasks;

import com.taskinspect.common.config.OpenApiConfig;
import com.taskinspect.common.security.CurrentUser;
import com.taskinspect.tasks.dto.TaskHistoryEntry;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import java.util.List;
import java.util.UUID;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RestController;

@RestController
@Tag(name = "Tasks")
@SecurityRequirement(name = OpenApiConfig.BEARER_AUTH)
public class TaskHistoryController {

    private final TaskHistoryService historyService;

    public TaskHistoryController(TaskHistoryService historyService) {
        this.historyService = historyService;
    }

    @GetMapping("/api/tasks/{id}/history")
    @Operation(summary = "A task's history", description = "Every status change, oldest first, with who did it, "
            + "when and the reason (e.g. of a reject). Anyone who can see the task.")
    public List<TaskHistoryEntry> history(@AuthenticationPrincipal Jwt jwt, @PathVariable UUID id) {
        return historyService.history(CurrentUser.from(jwt), id);
    }

}
