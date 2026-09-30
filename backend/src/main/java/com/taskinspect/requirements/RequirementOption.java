package com.taskinspect.requirements;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.FetchType;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.Table;
import java.util.UUID;

/** One choice of a dropdown or multiple-selection requirement. */
@Entity
@Table(name = "requirement_options")
public class RequirementOption {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "requirement_id", nullable = false)
    private Requirement requirement;

    @Column(nullable = false, length = 200)
    private String label;

    @Column(nullable = false)
    private int position;

    protected RequirementOption() {
        // for JPA
    }

    RequirementOption(Requirement requirement, String label, int position) {
        this.requirement = requirement;
        this.label = label;
        this.position = position;
    }

    public UUID getId() {
        return id;
    }

    public String getLabel() {
        return label;
    }

    public int getPosition() {
        return position;
    }

}
