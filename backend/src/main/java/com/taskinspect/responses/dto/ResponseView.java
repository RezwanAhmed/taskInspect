package com.taskinspect.responses.dto;

import com.taskinspect.responses.Response;
import java.math.BigDecimal;
import java.time.Instant;
import java.util.List;
import java.util.UUID;

/** A saved answer as returned by the API. */
public record ResponseView(
        UUID id,
        UUID requirementId,
        Boolean booleanValue,
        String textValue,
        BigDecimal numberValue,
        List<UUID> selectedOptionIds,
        String comment,
        UUID respondedBy,
        Instant updatedAt) {

    public static ResponseView from(Response response) {
        return new ResponseView(response.getId(), response.getRequirement().getId(), response.getBooleanValue(),
                response.getTextValue(), response.getNumberValue(), response.getSelectedOptionIds(),
                response.getComment(), response.getRespondedBy().getId(), response.getUpdatedAt());
    }

}
