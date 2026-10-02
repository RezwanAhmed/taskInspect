package com.taskinspect.tasks;

import java.time.Instant;
import java.util.UUID;
import org.springframework.data.jpa.domain.Specification;

/**
 * Reusable filters for task lists. A filter whose value is not given matches
 * every task, so optional filters can simply be combined with
 * {@link Specification#allOf}.
 */
public final class TaskSpecifications {

    private TaskSpecifications() {
    }

    public static Specification<Task> inOrganization(UUID organizationId) {
        return (task, query, cb) -> cb.equal(task.get("organization").get("id"), organizationId);
    }

    public static Specification<Task> assignedTo(UUID userId) {
        return (task, query, cb) -> cb.equal(task.get("assignee").get("id"), userId);
    }

    /** Tasks assigned to a member of the manager's team. */
    public static Specification<Task> assignedToTeamOf(UUID teamManagerId) {
        return (task, query, cb) -> cb.equal(task.get("assignee").get("teamManager").get("id"), teamManagerId);
    }

    /**
     * Open tasks a worker may take: those open to everyone, and those open to
     * the team of {@code teamManagerId} (the manager who published them).
     * Without a team ({@code null}) only the ones open to everyone.
     */
    public static Specification<Task> openFor(UUID teamManagerId) {
        return (task, query, cb) -> cb.and(cb.equal(task.get("status"), TaskStatus.OPEN), teamManagerId == null
                ? cb.equal(task.get("openScope"), OpenScope.EVERYONE)
                : cb.or(cb.equal(task.get("openScope"), OpenScope.EVERYONE),
                        cb.and(cb.equal(task.get("openScope"), OpenScope.TEAM),
                                cb.equal(task.get("createdBy").get("id"), teamManagerId))));
    }

    public static Specification<Task> notAssignedTo(UUID userId) {
        return (task, query, cb) -> cb.notEqual(task.get("assignee").get("id"), userId);
    }

    public static Specification<Task> notInStatus(TaskStatus status) {
        return (task, query, cb) -> cb.notEqual(task.get("status"), status);
    }

    public static Specification<Task> hasStatus(TaskStatus status) {
        return status == null ? Specification.unrestricted() : (task, query, cb) -> cb.equal(task.get("status"), status);
    }

    public static Specification<Task> hasPriority(TaskPriority priority) {
        return priority == null ? Specification.unrestricted() : (task, query, cb) -> cb.equal(task.get("priority"), priority);
    }

    public static Specification<Task> dueFrom(Instant from) {
        return from == null ? Specification.unrestricted() : (task, query, cb) -> cb.greaterThanOrEqualTo(task.get("dueDate"), from);
    }

    public static Specification<Task> dueBefore(Instant before) {
        return before == null ? Specification.unrestricted() : (task, query, cb) -> cb.lessThan(task.get("dueDate"), before);
    }

}
