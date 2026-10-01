package com.taskinspect.tasks;

import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.domain.Specification;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.JpaSpecificationExecutor;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;

/**
 * Tasks; combine {@link TaskSpecifications} for filtered, paged lists. The
 * creator, reviewer and assignee are loaded together with the task, because the API
 * returns them after the transaction has ended.
 */
public interface TaskRepository extends JpaRepository<Task, UUID>, JpaSpecificationExecutor<Task> {

    @EntityGraph(attributePaths = {"createdBy", "reviewer", "assignee"})
    Optional<Task> findByIdAndOrganizationId(UUID id, UUID organizationId);

    @Override
    @EntityGraph(attributePaths = {"createdBy", "reviewer", "assignee"})
    Page<Task> findAll(Specification<Task> spec, Pageable pageable);

    @Override
    @EntityGraph(attributePaths = {"createdBy", "reviewer", "assignee"})
    List<Task> findAll(Specification<Task> spec);

    /**
     * Sets {@code updatedAt} without a new version, e.g. when a requirement
     * changed, so the sync pull sends the task again but the manager can
     * still save the task with the version they have.
     */
    @Modifying(flushAutomatically = true)
    @Query("update Task t set t.updatedAt = :at where t.id = :id")
    void markChanged(UUID id, Instant at);

}
