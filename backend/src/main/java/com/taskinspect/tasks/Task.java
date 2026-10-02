package com.taskinspect.tasks;

import com.taskinspect.users.Organization;
import com.taskinspect.users.RoleName;
import com.taskinspect.users.User;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.FetchType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.PostLoad;
import jakarta.persistence.PostPersist;
import jakarta.persistence.Table;
import jakarta.persistence.Transient;
import jakarta.persistence.Version;
import java.time.Instant;
import java.util.UUID;
import org.hibernate.annotations.CreationTimestamp;
import org.hibernate.annotations.UpdateTimestamp;
import org.springframework.data.domain.Persistable;

/**
 * A task that a manager creates and a worker completes. New tasks start as
 * {@link TaskStatus#DRAFT}; the status only changes through the task state
 * machine.
 */
@Entity
@Table(name = "tasks")
public class Task implements Persistable<UUID> {

    /**
     * Set when the task is made: a task created offline brings the ID the
     * app gave it (docs/architecture.md, "What Works Offline").
     */
    @Id
    private UUID id;

    /** Until it is first saved; tells Spring Data to insert it although it has an ID. */
    @Transient
    private boolean isNew = true;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "organization_id", nullable = false)
    private Organization organization;

    @Column(nullable = false, length = 200)
    private String title;

    @Column(columnDefinition = "text")
    private String description;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    private TaskPriority priority;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 30)
    private TaskStatus status = TaskStatus.DRAFT;

    @Column(name = "due_date", nullable = false)
    private Instant dueDate;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "created_by", nullable = false, updatable = false)
    private User createdBy;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "reviewer_id", nullable = false)
    private User reviewer;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "assignee_id")
    private User assignee;

    @Enumerated(EnumType.STRING)
    @Column(name = "open_scope", length = 20)
    private OpenScope openScope;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "parent_task_id", updatable = false)
    private Task parentTask;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "reissued_from_id", updatable = false)
    private Task reissuedFrom;

    @Version
    @Column(nullable = false)
    private long version;

    @CreationTimestamp
    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @UpdateTimestamp
    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

    protected Task() {
        // for JPA
    }

    /** Creates a draft task. The reviewer defaults to the creator when none is given. */
    public Task(User createdBy, String title, String description, TaskPriority priority, Instant dueDate,
            User reviewer) {
        this(UUID.randomUUID(), createdBy, title, description, priority, dueDate, reviewer);
    }

    /** Creates a draft task with the ID a device gave it (created offline). */
    public Task(UUID id, User createdBy, String title, String description, TaskPriority priority, Instant dueDate,
            User reviewer) {
        this.id = id;
        this.organization = createdBy.getOrganization();
        this.createdBy = createdBy;
        this.title = title;
        this.description = description;
        this.priority = priority;
        this.dueDate = dueDate;
        this.reviewer = reviewer != null ? reviewer : createdBy;
    }

    /** Changes the details a manager can edit; the reviewer defaults to the creator. */
    public void updateDetails(String title, String description, TaskPriority priority, Instant dueDate,
            User reviewer) {
        this.title = title;
        this.description = description;
        this.priority = priority;
        this.dueDate = dueDate;
        this.reviewer = reviewer != null ? reviewer : createdBy;
    }

    void assignTo(User worker) {
        this.assignee = worker;
    }

    /** Makes a new task a sub-task of a main task; set once, before it is first saved. */
    void makeSubTaskOf(Task mainTask) {
        this.parentTask = mainTask;
    }

    /** Links a new task to the task it was registered again from; set once, before it is first saved. */
    void reissueOf(Task original) {
        this.reissuedFrom = original;
    }

    /** Sets who may take the task once it is published (OPEN). */
    void openTo(OpenScope scope) {
        this.openScope = scope;
    }

    /** Only the task state machine changes the status. Leaving OPEN clears who may take it. */
    void changeStatus(TaskStatus newStatus) {
        this.status = newStatus;
        if (newStatus != TaskStatus.OPEN) {
            this.openScope = null;
        }
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

    public Organization getOrganization() {
        return organization;
    }

    public String getTitle() {
        return title;
    }

    public String getDescription() {
        return description;
    }

    public TaskPriority getPriority() {
        return priority;
    }

    public TaskStatus getStatus() {
        return status;
    }

    public Instant getDueDate() {
        return dueDate;
    }

    public User getCreatedBy() {
        return createdBy;
    }

    public User getReviewer() {
        return reviewer;
    }

    /** The worker the task is assigned to, or {@code null} before it is assigned. */
    public User getAssignee() {
        return assignee;
    }

    /**
     * A main task: created by an administrator and assigned to a manager, who
     * passes it on in sub-tasks (docs/architecture.md, "Tasks for Managers
     * and Sub-tasks").
     */
    public boolean isMainTask() {
        return createdBy.hasRole(RoleName.ADMINISTRATOR);
    }

    /** The main task of a sub-task; {@code null} for every other task. */
    public UUID getParentTaskId() {
        return parentTask == null ? null : parentTask.getId();
    }

    /** The task this one was registered again from; {@code null} for every other task. */
    public UUID getReissuedFromId() {
        return reissuedFrom == null ? null : reissuedFrom.getId();
    }

    /** Who may take the task while it is OPEN; {@code null} in every other status. */
    public OpenScope getOpenScope() {
        return openScope;
    }

    public long getVersion() {
        return version;
    }

    public Instant getCreatedAt() {
        return createdAt;
    }

    public Instant getUpdatedAt() {
        return updatedAt;
    }

}
