package com.taskinspect.reviews;

import jakarta.persistence.Column;
import jakarta.persistence.Embeddable;
import java.util.UUID;

/** A requirement a correction request sends back, with the reviewer's comment. */
@Embeddable
public class MarkedRequirement {

    @Column(name = "requirement_id", nullable = false)
    private UUID requirementId;

    @Column(nullable = false, columnDefinition = "text")
    private String comment;

    protected MarkedRequirement() {
        // for JPA
    }

    public MarkedRequirement(UUID requirementId, String comment) {
        this.requirementId = requirementId;
        this.comment = comment;
    }

    public UUID getRequirementId() {
        return requirementId;
    }

    public String getComment() {
        return comment;
    }

}
