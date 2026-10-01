package com.taskinspect.reviews;

import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;

public interface ReviewRepository extends JpaRepository<Review, UUID> {

    @EntityGraph(attributePaths = {"reviewer", "markedRequirements"})
    List<Review> findAllByTaskIdOrderByCreatedAtAscIdAsc(UUID taskId);

    /**
     * The task's latest review. The marked requirements are loaded when
     * used (inside the transaction): fetching a collection with "first"
     * would make Hibernate load every review of the task.
     */
    @EntityGraph(attributePaths = "reviewer")
    Optional<Review> findFirstByTaskIdOrderByCreatedAtDescIdDesc(UUID taskId);

    boolean existsByTaskId(UUID taskId);

}
