package com.taskinspect.responses;

import com.taskinspect.requirements.Requirement;
import com.taskinspect.tasks.Task;
import com.taskinspect.users.User;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.FetchType;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.Table;
import java.math.BigDecimal;
import java.time.Instant;
import java.util.List;
import java.util.UUID;
import org.hibernate.annotations.CreationTimestamp;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.annotations.UpdateTimestamp;
import org.hibernate.type.SqlTypes;

/**
 * The worker's answer to one requirement. Only the value that fits the
 * requirement's type is set; the others are {@code null}.
 */
@Entity
@Table(name = "task_responses")
public class Response {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "task_id", nullable = false, updatable = false)
    private Task task;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "requirement_id", nullable = false, updatable = false, unique = true)
    private Requirement requirement;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "responded_by", nullable = false)
    private User respondedBy;

    @Column(name = "boolean_value")
    private Boolean booleanValue;

    @Column(name = "text_value", columnDefinition = "text")
    private String textValue;

    @Column(name = "number_value", precision = 19, scale = 4)
    private BigDecimal numberValue;

    @JdbcTypeCode(SqlTypes.ARRAY)
    @Column(name = "selected_option_ids", columnDefinition = "uuid[]")
    private List<UUID> selectedOptionIds;

    @Column(columnDefinition = "text")
    private String comment;

    @CreationTimestamp
    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @UpdateTimestamp
    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

    protected Response() {
        // for JPA
    }

    Response(Task task, Requirement requirement) {
        this.task = task;
        this.requirement = requirement;
    }

    /** Replaces the answer. */
    void answer(User by, Boolean booleanValue, String textValue, BigDecimal numberValue,
            List<UUID> selectedOptionIds, String comment) {
        this.respondedBy = by;
        this.booleanValue = booleanValue;
        this.textValue = textValue;
        this.numberValue = numberValue;
        this.selectedOptionIds = selectedOptionIds;
        this.comment = comment;
    }

    public UUID getId() {
        return id;
    }

    public Requirement getRequirement() {
        return requirement;
    }

    public User getRespondedBy() {
        return respondedBy;
    }

    public Boolean getBooleanValue() {
        return booleanValue;
    }

    public String getTextValue() {
        return textValue;
    }

    public BigDecimal getNumberValue() {
        return numberValue;
    }

    public List<UUID> getSelectedOptionIds() {
        return selectedOptionIds == null ? List.of() : List.copyOf(selectedOptionIds);
    }

    public String getComment() {
        return comment;
    }

    public Instant getCreatedAt() {
        return createdAt;
    }

    public Instant getUpdatedAt() {
        return updatedAt;
    }

}
