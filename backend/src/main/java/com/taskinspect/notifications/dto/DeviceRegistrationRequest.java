package com.taskinspect.notifications.dto;

import com.taskinspect.notifications.DevicePlatform;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

public record DeviceRegistrationRequest(@NotBlank @Size(max = 512) String token, @NotNull DevicePlatform platform) {
}
