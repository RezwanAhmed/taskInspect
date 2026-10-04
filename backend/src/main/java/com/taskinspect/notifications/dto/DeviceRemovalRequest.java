package com.taskinspect.notifications.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record DeviceRemovalRequest(@NotBlank @Size(max = 512) String token) {
}
