package com.taskinspect.tasks;

import java.util.Optional;
import java.util.UUID;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.domain.Specification;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.JpaSpecificationExecutor;

/**
 * Tasks; combine {@link TaskSpecifications} for filtered, paged lists. The
 * creator and reviewer are loaded together with the task, because the API
 * returns them after the transaction has ended.
 */
public interface TaskRepository extends JpaRepository<Task, UUID>, JpaSpecificationExecutor<Task> {

    @EntityGraph(attributePaths = {"createdBy", "reviewer"})
    Optional<Task> findByIdAndOrganizationId(UUID id, UUID organizationId);

    @Override
    @EntityGraph(attributePaths = {"createdBy", "reviewer"})
    Page<Task> findAll(Specification<Task> spec, Pageable pageable);

}
