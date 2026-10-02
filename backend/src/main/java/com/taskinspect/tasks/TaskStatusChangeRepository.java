package com.taskinspect.tasks;

import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;

public interface TaskStatusChangeRepository extends JpaRepository<TaskStatusChange, UUID> {

    @EntityGraph(attributePaths = "changedBy")
    List<TaskStatusChange> findAllByTaskIdOrderByChangedAtAscIdAsc(UUID taskId);

    /** The task's latest change into the given status, e.g. its publish (OPEN). */
    Optional<TaskStatusChange> findFirstByTaskIdAndToStatusOrderByChangedAtDescIdDesc(UUID taskId, TaskStatus toStatus);

}
