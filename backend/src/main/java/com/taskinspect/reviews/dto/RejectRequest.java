package com.taskinspect.reviews.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

/** Why the whole task goes back to the worker. */
public record RejectRequest(@NotBlank @Size(max = 2000) String reason) {
}
