package com.taskinspect.requirements;

import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;

public interface RequirementRepository extends JpaRepository<Requirement, UUID> {

    @EntityGraph(attributePaths = "options")
    List<Requirement> findAllByTaskIdOrderByPosition(UUID taskId);

    long countByTaskId(UUID taskId);

    @EntityGraph(attributePaths = {"options", "task"})
    Optional<Requirement> findWithOptionsById(UUID id);

}
