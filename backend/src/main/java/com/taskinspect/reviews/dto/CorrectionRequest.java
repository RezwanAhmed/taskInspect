package com.taskinspect.reviews.dto;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import java.util.List;
import java.util.UUID;

/** The requirements to fix, each with a comment, and an optional general note. */
public record CorrectionRequest(
        @Size(max = 2000) String reason,
        @NotEmpty @Size(max = 200) List<@NotNull @Valid Item> requirements) {

    public record Item(@NotNull UUID requirementId, @NotBlank @Size(max = 2000) String comment) {
    }

}
