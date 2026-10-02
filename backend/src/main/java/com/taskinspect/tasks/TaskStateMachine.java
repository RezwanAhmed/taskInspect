package com.taskinspect.tasks;

import static com.taskinspect.tasks.TaskStatus.APPROVED;
import static com.taskinspect.tasks.TaskStatus.ASSIGNED;
import static com.taskinspect.tasks.TaskStatus.CANCELLED;
import static com.taskinspect.tasks.TaskStatus.CORRECTION_REQUESTED;
import static com.taskinspect.tasks.TaskStatus.DRAFT;
import static com.taskinspect.tasks.TaskStatus.IN_PROGRESS;
import static com.taskinspect.tasks.TaskStatus.OPEN;
import static com.taskinspect.tasks.TaskStatus.REJECTED;
import static com.taskinspect.tasks.TaskStatus.SUBMITTED;

import com.taskinspect.common.error.ApiException;
import java.util.Collections;
import java.util.EnumMap;
import java.util.Map;
import java.util.Set;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Component;

/**
 * The single place that decides which status changes are allowed (see
 * docs/architecture.md, "Task Lifecycle"). Who may perform an action is
 * checked by the services; this class only checks the order of states.
 */
@Component
public class TaskStateMachine {

    public static final String TASK_INVALID_TRANSITION = "TASK_INVALID_TRANSITION";
    public static final String TASK_ALREADY_APPROVED = "TASK_ALREADY_APPROVED";
    public static final String TASK_ALREADY_CANCELLED = "TASK_ALREADY_CANCELLED";

    private static final Map<TaskStatus, Map<TaskAction, TaskStatus>> TRANSITIONS = new EnumMap<>(TaskStatus.class);

    static {
        allow(DRAFT, TaskAction.ASSIGN, ASSIGNED);
        allow(DRAFT, TaskAction.PUBLISH, OPEN);
        allow(OPEN, TaskAction.TAKE, ASSIGNED);
        allow(ASSIGNED, TaskAction.START, IN_PROGRESS);
        allow(IN_PROGRESS, TaskAction.SUBMIT, SUBMITTED);
        allow(SUBMITTED, TaskAction.APPROVE, APPROVED);
        allow(SUBMITTED, TaskAction.REJECT, REJECTED);
        allow(SUBMITTED, TaskAction.REQUEST_CORRECTION, CORRECTION_REQUESTED);
        allow(REJECTED, TaskAction.START, IN_PROGRESS);
        allow(CORRECTION_REQUESTED, TaskAction.START, IN_PROGRESS);
        for (TaskStatus status : Set.of(DRAFT, OPEN, ASSIGNED, IN_PROGRESS, REJECTED, CORRECTION_REQUESTED)) {
            allow(status, TaskAction.CANCEL, CANCELLED);
        }
    }

    private static void allow(TaskStatus from, TaskAction action, TaskStatus to) {
        TRANSITIONS.computeIfAbsent(from, status -> new EnumMap<>(TaskAction.class)).put(action, to);
    }

    /**
     * Returns the status the task moves to.
     *
     * @throws ApiException 409 when the action is not allowed in the current status
     */
    public TaskStatus next(TaskStatus current, TaskAction action) {
        if (current == APPROVED) {
            throw conflict(TASK_ALREADY_APPROVED, "Task has already been approved");
        }
        if (current == CANCELLED) {
            throw conflict(TASK_ALREADY_CANCELLED, "Task has been cancelled");
        }
        TaskStatus next = TRANSITIONS.getOrDefault(current, Map.of()).get(action);
        if (next == null) {
            throw conflict(TASK_INVALID_TRANSITION,
                    "Cannot " + action.name().toLowerCase().replace('_', ' ') + " a task in status " + current);
        }
        return next;
    }

    /** Moves the task to its next status, or throws if the action is not allowed. */
    public void apply(Task task, TaskAction action) {
        task.changeStatus(next(task.getStatus(), action));
    }

    /** The actions allowed in a status, so the app can offer only valid buttons. */
    public Set<TaskAction> allowedActions(TaskStatus status) {
        Map<TaskAction, TaskStatus> actions = TRANSITIONS.get(status);
        return actions == null ? Set.of() : Collections.unmodifiableSet(actions.keySet());
    }

    private static ApiException conflict(String code, String message) {
        return new ApiException(HttpStatus.CONFLICT, code, message);
    }

}
