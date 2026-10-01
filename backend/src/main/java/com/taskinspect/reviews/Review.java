package com.taskinspect.reviews;

import com.taskinspect.tasks.Task;
import com.taskinspect.users.User;
import jakarta.persistence.CollectionTable;
import jakarta.persistence.Column;
import jakarta.persistence.ElementCollection;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.FetchType;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.Table;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;
import org.hibernate.annotations.CreationTimestamp;

/** One review of a submitted task: the result, the reason and the marked requirements. */
@Entity
@Table(name = "task_reviews")
public class Review {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "task_id", nullable = false, updatable = false)
    private Task task;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "reviewer_id", nullable = false, updatable = false)
    private User reviewer;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 30, updatable = false)
    private ReviewResult result;

    @Column(columnDefinition = "text", updatable = false)
    private String reason;

    @ElementCollection
    @CollectionTable(name = "task_review_items", joinColumns = @JoinColumn(name = "review_id"))
    private List<MarkedRequirement> markedRequirements = new ArrayList<>();

    @CreationTimestamp
    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    protected Review() {
        // for JPA
    }

    Review(Task task, User reviewer, ReviewResult result, String reason, List<MarkedRequirement> markedRequirements) {
        this.task = task;
        this.reviewer = reviewer;
        this.result = result;
        this.reason = reason;
        this.markedRequirements = new ArrayList<>(markedRequirements);
    }

    public UUID getId() {
        return id;
    }

    public Task getTask() {
        return task;
    }

    public User getReviewer() {
        return reviewer;
    }

    public ReviewResult getResult() {
        return result;
    }

    public String getReason() {
        return reason;
    }

    public List<MarkedRequirement> getMarkedRequirements() {
        return List.copyOf(markedRequirements);
    }

    public Instant getCreatedAt() {
        return createdAt;
    }

}
