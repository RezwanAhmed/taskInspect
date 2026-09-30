package com.taskinspect.tasks;

import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.JpaSpecificationExecutor;

/** Tasks; combine {@link TaskSpecifications} for filtered, paged lists. */
public interface TaskRepository extends JpaRepository<Task, UUID>, JpaSpecificationExecutor<Task> {

    Optional<Task> findByIdAndOrganizationId(UUID id, UUID organizationId);

}
