package com.taskinspect.notifications;

import com.taskinspect.common.config.OpenApiConfig;
import com.taskinspect.common.security.CurrentUser;
import com.taskinspect.notifications.dto.DeviceRegistrationRequest;
import com.taskinspect.notifications.dto.DeviceRemovalRequest;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/devices")
@Tag(name = "Devices")
@SecurityRequirement(name = OpenApiConfig.BEARER_AUTH)
public class DeviceController {

    private final NotificationService notificationService;

    public DeviceController(NotificationService notificationService) {
        this.notificationService = notificationService;
    }

    @PutMapping
    @ResponseStatus(HttpStatus.NO_CONTENT)
    @Operation(summary = "Register this device for push notifications",
            description = "Stores the device's Firebase Cloud Messaging token for the caller. Safe to repeat "
                    + "(after every login and token refresh). A token registered by another user before is "
                    + "moved to the caller, so that user gets no more notifications on this device.")
    public void register(@AuthenticationPrincipal Jwt jwt, @Valid @RequestBody DeviceRegistrationRequest request) {
        notificationService.registerDevice(CurrentUser.from(jwt).id(), request.token(), request.platform());
    }

    @DeleteMapping
    @ResponseStatus(HttpStatus.NO_CONTENT)
    @Operation(summary = "Stop push notifications on this device",
            description = "Removes the caller's token (called before logout). Always returns 204; an unknown "
                    + "token or one that belongs to another user is left alone.")
    public void unregister(@AuthenticationPrincipal Jwt jwt, @Valid @RequestBody DeviceRemovalRequest request) {
        notificationService.unregisterDevice(CurrentUser.from(jwt).id(), request.token());
    }

}
