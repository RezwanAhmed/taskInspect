package com.taskinspect.sync;

import com.taskinspect.common.config.OpenApiConfig;
import com.taskinspect.common.security.CurrentUser;
import com.taskinspect.sync.dto.SyncPushRequest;
import com.taskinspect.sync.dto.SyncPushResponse;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/sync")
@Tag(name = "Sync")
@SecurityRequirement(name = OpenApiConfig.BEARER_AUTH)
public class SyncController {

    private final SyncService syncService;

    public SyncController(SyncService syncService) {
        this.syncService = syncService;
    }

    @PostMapping("/push")
    @Operation(summary = "Send changes made on the device",
            description = "Operations from the app's sync queue, in the order they were made (max 100). Each one "
                    + "is checked like the matching API call and gets its own result: APPLIED, REJECTED (with "
                    + "the error code) or SKIPPED (an earlier change of the same task was rejected). Safe to "
                    + "send again: operations applied before are not applied twice. Supported: TaskResponse "
                    + "UPDATE, Evidence CREATE / DELETE, Task START.")
    public SyncPushResponse push(@AuthenticationPrincipal Jwt jwt, @Valid @RequestBody SyncPushRequest request) {
        return new SyncPushResponse(syncService.push(CurrentUser.from(jwt), request.operations()));
    }

}
