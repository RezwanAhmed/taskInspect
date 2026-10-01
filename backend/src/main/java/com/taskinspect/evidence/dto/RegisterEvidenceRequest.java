package com.taskinspect.evidence.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;
import jakarta.validation.constraints.Size;
import java.util.UUID;

/**
 * Registers an evidence file before it is uploaded. {@code id} is created on
 * the device, so sending the same request again is harmless.
 */
public record RegisterEvidenceRequest(
        @NotNull UUID id,
        @NotBlank @Size(max = 255) String fileName,
        @NotBlank @Size(max = 100) String contentType,
        @NotNull @Positive Long sizeBytes) {
}
