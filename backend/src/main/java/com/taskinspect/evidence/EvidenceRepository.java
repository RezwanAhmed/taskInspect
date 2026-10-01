package com.taskinspect.evidence;

import java.util.List;
import java.util.UUID;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;

public interface EvidenceRepository extends JpaRepository<Evidence, UUID> {

    @EntityGraph(attributePaths = {"requirement", "uploadedBy"})
    List<Evidence> findAllByTaskIdOrderByCreatedAtAsc(UUID taskId);

}
