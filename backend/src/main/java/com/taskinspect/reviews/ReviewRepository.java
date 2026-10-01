package com.taskinspect.reviews;

import java.util.List;
import java.util.UUID;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;

public interface ReviewRepository extends JpaRepository<Review, UUID> {

    @EntityGraph(attributePaths = {"reviewer", "markedRequirements"})
    List<Review> findAllByTaskIdOrderByCreatedAtAscIdAsc(UUID taskId);

}
