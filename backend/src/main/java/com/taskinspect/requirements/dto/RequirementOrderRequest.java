package com.taskinspect.requirements.dto;

import jakarta.validation.constraints.NotNull;
import java.util.List;
import java.util.UUID;

/** The new order of a task's requirements: each requirement's ID exactly once. */
public record RequirementOrderRequest(@NotNull List<@NotNull UUID> requirementIds) {
}
