package com.taskinspect.responses.dto;

import jakarta.validation.constraints.Digits;
import jakarta.validation.constraints.Size;
import java.math.BigDecimal;
import java.util.List;
import java.util.UUID;

/**
 * The worker's answer. Send only the field that fits the requirement type:
 * {@code booleanValue} (CHECKBOX, YES_NO), {@code textValue} (TEXT,
 * COMMENT), {@code numberValue} (NUMBER) or {@code selectedOptionIds}
 * (DROPDOWN: one, MULTIPLE_SELECTION: one or more). {@code comment} is an
 * optional note on any requirement.
 */
public record SaveResponseRequest(
        Boolean booleanValue,
        @Size(max = 5000) String textValue,
        @Digits(integer = 15, fraction = 4) BigDecimal numberValue,
        @Size(max = 50) List<UUID> selectedOptionIds,
        @Size(max = 2000) String comment) {
}
