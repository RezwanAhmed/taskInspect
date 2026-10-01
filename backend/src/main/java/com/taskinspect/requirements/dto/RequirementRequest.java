package com.taskinspect.requirements.dto;

import com.taskinspect.requirements.RequirementType;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import java.util.List;

/**
 * A requirement to add or the new content of an existing one. {@code unit}
 * is only for NUMBER; {@code options} (at least two) only for DROPDOWN and
 * MULTIPLE_SELECTION.
 */
public record RequirementRequest(
        @NotBlank @Size(max = 300) String title,
        @Size(max = 5000) String description,
        @NotNull RequirementType type,
        Boolean required,
        @Size(max = 30) String unit,
        @Size(max = 50) List<@NotBlank @Size(max = 200) String> options) {
}
