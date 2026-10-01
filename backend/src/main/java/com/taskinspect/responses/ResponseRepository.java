package com.taskinspect.responses;

import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;

public interface ResponseRepository extends JpaRepository<Response, UUID> {

    Optional<Response> findByRequirementId(UUID requirementId);

    @EntityGraph(attributePaths = {"requirement", "respondedBy"})
    List<Response> findAllByTaskId(UUID taskId);

}
