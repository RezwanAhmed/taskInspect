package com.taskinspect.sync;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;
import java.util.UUID;
import org.hibernate.annotations.CreationTimestamp;

/**
 * An operation from the app's sync queue that the server has applied. Its ID
 * is created on the device, so a repeated push of the same operation is
 * recognised and not applied twice. It stores only IDs, like the audit log.
 */
@Entity
@Table(name = "sync_records")
public class SyncRecord {

    @Id
    private UUID id;

    @Column(name = "user_id", nullable = false, updatable = false)
    private UUID userId;

    @Column(name = "task_id", nullable = false, updatable = false)
    private UUID taskId;

    @Column(name = "entity_type", nullable = false, length = 30, updatable = false)
    private String entityType;

    @Column(name = "entity_id", nullable = false, updatable = false)
    private UUID entityId;

    @Column(nullable = false, length = 20, updatable = false)
    private String operation;

    @CreationTimestamp
    @Column(name = "applied_at", nullable = false, updatable = false)
    private Instant appliedAt;

    protected SyncRecord() {
        // for JPA
    }

    public SyncRecord(UUID id, UUID userId, UUID taskId, String entityType, UUID entityId, String operation) {
        this.id = id;
        this.userId = userId;
        this.taskId = taskId;
        this.entityType = entityType;
        this.entityId = entityId;
        this.operation = operation;
    }

    public UUID getId() {
        return id;
    }

    public UUID getUserId() {
        return userId;
    }

    public UUID getTaskId() {
        return taskId;
    }

    public String getEntityType() {
        return entityType;
    }

    public UUID getEntityId() {
        return entityId;
    }

    public String getOperation() {
        return operation;
    }

    public Instant getAppliedAt() {
        return appliedAt;
    }

}
