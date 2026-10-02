package com.taskinspect.requirements;

import com.taskinspect.tasks.Task;
import jakarta.persistence.CascadeType;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.FetchType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.OneToMany;
import jakarta.persistence.OrderBy;
import jakarta.persistence.PostLoad;
import jakarta.persistence.PostPersist;
import jakarta.persistence.Table;
import jakarta.persistence.Transient;
import java.time.Instant;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.UUID;
import org.hibernate.annotations.CreationTimestamp;
import org.hibernate.annotations.UpdateTimestamp;
import org.springframework.data.domain.Persistable;

/**
 * One item of a task that the worker must complete, e.g. "Is the fire
 * extinguisher available?" (YES_NO) or "Record refrigerator temperature"
 * (NUMBER, unit °C).
 */
@Entity
@Table(name = "task_requirements")
public class Requirement implements Persistable<UUID> {

    /** Set when the requirement is made: one added offline brings the ID the app gave it. */
    @Id
    private UUID id;

    /** Until it is first saved; tells Spring Data to insert it although it has an ID. */
    @Transient
    private boolean isNew = true;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "task_id", nullable = false, updatable = false)
    private Task task;

    @Column(nullable = false, length = 300)
    private String title;

    @Column(columnDefinition = "text")
    private String description;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 30)
    private RequirementType type;

    @Column(nullable = false)
    private boolean required = true;

    @Column(nullable = false)
    private int position;

    @Column(length = 30)
    private String unit;

    @OneToMany(mappedBy = "requirement", cascade = CascadeType.ALL, orphanRemoval = true)
    @OrderBy("position")
    private List<RequirementOption> options = new ArrayList<>();

    @CreationTimestamp
    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @UpdateTimestamp
    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

    protected Requirement() {
        // for JPA
    }

    public Requirement(Task task, String title, String description, RequirementType type, boolean required,
            int position, String unit, List<String> optionLabels) {
        this(UUID.randomUUID(), task, title, description, type, required, position, unit, optionLabels);
    }

    /** A requirement with the ID a device gave it (added offline). */
    public Requirement(UUID id, Task task, String title, String description, RequirementType type, boolean required,
            int position, String unit, List<String> optionLabels) {
        this.id = id;
        this.task = task;
        this.position = position;
        update(title, description, type, required, unit, optionLabels);
    }

    /** Replaces the requirement's content; options are kept only for types that have options. */
    public void update(String title, String description, RequirementType type, boolean required, String unit,
            List<String> optionLabels) {
        this.title = title;
        this.description = description;
        this.type = type;
        this.required = required;
        this.unit = type == RequirementType.NUMBER ? unit : null;
        this.options.clear();
        if (type.hasOptions() && optionLabels != null) {
            for (int i = 0; i < optionLabels.size(); i++) {
                options.add(new RequirementOption(this, optionLabels.get(i), i));
            }
        }
    }

    public void moveTo(int position) {
        this.position = position;
    }

    @Override
    public UUID getId() {
        return id;
    }

    @Override
    public boolean isNew() {
        return isNew;
    }

    @PostLoad
    @PostPersist
    void markStored() {
        this.isNew = false;
    }

    public Task getTask() {
        return task;
    }

    public String getTitle() {
        return title;
    }

    public String getDescription() {
        return description;
    }

    public RequirementType getType() {
        return type;
    }

    public boolean isRequired() {
        return required;
    }

    public int getPosition() {
        return position;
    }

    public String getUnit() {
        return unit;
    }

    public List<RequirementOption> getOptions() {
        return Collections.unmodifiableList(options);
    }

    public Instant getCreatedAt() {
        return createdAt;
    }

    public Instant getUpdatedAt() {
        return updatedAt;
    }

}
