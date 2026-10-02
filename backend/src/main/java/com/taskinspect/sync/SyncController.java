package com.taskinspect.sync;

import com.taskinspect.common.config.OpenApiConfig;
import com.taskinspect.common.security.CurrentUser;
import com.taskinspect.sync.dto.SyncPullResponse;
import com.taskinspect.sync.dto.SyncPushRequest;
import com.taskinspect.sync.dto.SyncPushResponse;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import java.time.Instant;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/sync")
@Tag(name = "Sync")
@SecurityRequirement(name = OpenApiConfig.BEARER_AUTH)
public class SyncController {

    private final SyncService syncService;
    private final SyncPullService syncPullService;

    public SyncController(SyncService syncService, SyncPullService syncPullService) {
        this.syncService = syncService;
        this.syncPullService = syncPullService;
    }

    @PostMapping("/push")
    @Operation(summary = "Send changes made on the device",
            description = "Operations from the app's sync queue, in the order they were made (max 100). Each one "
                    + "is checked like the matching API call and gets its own result: APPLIED, REJECTED (with "
                    + "the error code) or SKIPPED (an earlier change of the same task was rejected). Safe to "
                    + "send again: operations applied before are not applied twice. Supported: TaskResponse "
                    + "UPDATE, Evidence CREATE / DELETE, Task START / SUBMIT (workers; START / SUBMIT also the "
                    + "manager of a main task), Task CREATE / UPDATE (managers: drafts made offline; CREATE "
                    + "uses the task ID the app gave it).")
    public SyncPushResponse push(@AuthenticationPrincipal Jwt jwt, @Valid @RequestBody SyncPushRequest request) {
        return new SyncPushResponse(syncService.push(CurrentUser.from(jwt), request.operations()));
    }

    @GetMapping("/pull")
    @Operation(summary = "Get what changed on the server",
            description = "Without `since` (first pull, after sign in): every task the user may see, with its "
                    + "requirements. With `since` = the `cursor` of the last pull: only the tasks changed since "
                    + "then (changes from shortly before are sent again, so none is missed). `taskIds` lists every "
                    + "task the user may see now, so the app can remove the others. Tiles (team members' tasks, "
                    + "without requirements) come the same way in `tileIds` / `tiles`. `teamVersion` changes when "
                    + "the user's team changes; then the app pulls again without `since`.")
    public SyncPullResponse pull(@AuthenticationPrincipal Jwt jwt, @RequestParam(required = false) Instant since) {
        return syncPullService.pull(CurrentUser.from(jwt), since);
    }

}
