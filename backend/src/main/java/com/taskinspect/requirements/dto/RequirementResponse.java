package com.taskinspect.requirements.dto;

import com.taskinspect.requirements.Requirement;
import com.taskinspect.requirements.RequirementType;
import java.util.List;
import java.util.UUID;

public record RequirementResponse(
        UUID id,
        String title,
        String description,
        RequirementType type,
        boolean required,
        int position,
        String unit,
        List<Option> options) {

    public static RequirementResponse from(Requirement requirement) {
        return new RequirementResponse(requirement.getId(), requirement.getTitle(), requirement.getDescription(),
                requirement.getType(), requirement.isRequired(), requirement.getPosition(), requirement.getUnit(),
                requirement.getOptions().stream()
                        .map(option -> new Option(option.getId(), option.getLabel(), option.getPosition()))
                        .toList());
    }

    public record Option(UUID id, String label, int position) {
    }

}
