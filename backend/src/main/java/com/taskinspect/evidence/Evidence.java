package com.taskinspect.evidence;

import com.taskinspect.requirements.Requirement;
import com.taskinspect.tasks.Task;
import com.taskinspect.users.User;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.FetchType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.Table;
import java.time.Instant;
import java.util.UUID;
import org.hibernate.annotations.CreationTimestamp;

/** Metadata of an evidence file (photo or PDF); the file is in file storage. */
@Entity
@Table(name = "evidence")
public class Evidence {

    /** Created on the device. */
    @Id
    private UUID id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "task_id", nullable = false, updatable = false)
    private Task task;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "requirement_id", nullable = false, updatable = false)
    private Requirement requirement;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "uploaded_by", nullable = false, updatable = false)
    private User uploadedBy;

    @Column(name = "file_name", nullable = false, updatable = false)
    private String fileName;

    @Column(name = "content_type", nullable = false, updatable = false, length = 100)
    private String contentType;

    @Column(name = "size_bytes", nullable = false, updatable = false)
    private long sizeBytes;

    @Column(name = "storage_key", nullable = false, updatable = false, unique = true, length = 300)
    private String storageKey;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    private EvidenceStatus status = EvidenceStatus.PENDING;

    @CreationTimestamp
    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @Column(name = "uploaded_at")
    private Instant uploadedAt;

    protected Evidence() {
        // for JPA
    }

    Evidence(UUID id, Task task, Requirement requirement, User uploadedBy, String fileName, String contentType,
            long sizeBytes, String storageKey) {
        this.id = id;
        this.task = task;
        this.requirement = requirement;
        this.uploadedBy = uploadedBy;
        this.fileName = fileName;
        this.contentType = contentType;
        this.sizeBytes = sizeBytes;
        this.storageKey = storageKey;
    }

    void markUploaded(Instant at) {
        this.status = EvidenceStatus.UPLOADED;
        this.uploadedAt = at;
    }

    public UUID getId() {
        return id;
    }

    public Task getTask() {
        return task;
    }

    public Requirement getRequirement() {
        return requirement;
    }

    public User getUploadedBy() {
        return uploadedBy;
    }

    public String getFileName() {
        return fileName;
    }

    public String getContentType() {
        return contentType;
    }

    public long getSizeBytes() {
        return sizeBytes;
    }

    public String getStorageKey() {
        return storageKey;
    }

    public EvidenceStatus getStatus() {
        return status;
    }

    public Instant getCreatedAt() {
        return createdAt;
    }

    public Instant getUploadedAt() {
        return uploadedAt;
    }

}
