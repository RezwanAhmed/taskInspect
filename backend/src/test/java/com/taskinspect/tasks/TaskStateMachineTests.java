package com.taskinspect.tasks;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.mock;

import com.taskinspect.common.error.ApiException;
import com.taskinspect.users.User;
import java.time.Instant;
import java.util.Map;
import java.util.Set;
import java.util.stream.Stream;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.Arguments;
import org.junit.jupiter.params.provider.MethodSource;
import org.springframework.http.HttpStatus;

class TaskStateMachineTests {

    /** Every allowed change, exactly as in docs/architecture.md. Anything else must be rejected. */
    private static final Map<String, TaskStatus> ALLOWED = Map.ofEntries(
            Map.entry("DRAFT+ASSIGN", TaskStatus.ASSIGNED),
            Map.entry("ASSIGNED+START", TaskStatus.IN_PROGRESS),
            Map.entry("IN_PROGRESS+SUBMIT", TaskStatus.SUBMITTED),
            Map.entry("SUBMITTED+APPROVE", TaskStatus.APPROVED),
            Map.entry("SUBMITTED+REJECT", TaskStatus.REJECTED),
            Map.entry("SUBMITTED+REQUEST_CORRECTION", TaskStatus.CORRECTION_REQUESTED),
            Map.entry("REJECTED+START", TaskStatus.IN_PROGRESS),
            Map.entry("CORRECTION_REQUESTED+START", TaskStatus.IN_PROGRESS),
            Map.entry("DRAFT+CANCEL", TaskStatus.CANCELLED),
            Map.entry("ASSIGNED+CANCEL", TaskStatus.CANCELLED),
            Map.entry("IN_PROGRESS+CANCEL", TaskStatus.CANCELLED),
            Map.entry("REJECTED+CANCEL", TaskStatus.CANCELLED),
            Map.entry("CORRECTION_REQUESTED+CANCEL", TaskStatus.CANCELLED));

    private final TaskStateMachine stateMachine = new TaskStateMachine();

    static Stream<Arguments> everyStatusAndAction() {
        return Stream.of(TaskStatus.values())
                .flatMap(status -> Stream.of(TaskAction.values()).map(action -> Arguments.of(status, action)));
    }

    @ParameterizedTest(name = "{0} + {1}")
    @MethodSource("everyStatusAndAction")
    void onlyTheDocumentedTransitionsAreAllowed(TaskStatus status, TaskAction action) {
        TaskStatus expected = ALLOWED.get(status + "+" + action);

        if (expected != null) {
            assertThat(stateMachine.next(status, action)).isEqualTo(expected);
        } else {
            assertThatThrownBy(() -> stateMachine.next(status, action))
                    .isInstanceOfSatisfying(ApiException.class,
                            ex -> assertThat(ex.getStatus()).isEqualTo(HttpStatus.CONFLICT));
        }
    }

    @Test
    void workerCannotJumpFromSubmittedToApprovedWithoutReview() {
        assertThatThrownBy(() -> stateMachine.next(TaskStatus.IN_PROGRESS, TaskAction.APPROVE))
                .isInstanceOfSatisfying(ApiException.class, ex -> {
                    assertThat(ex.getCode()).isEqualTo(TaskStateMachine.TASK_INVALID_TRANSITION);
                    assertThat(ex.getMessage()).isEqualTo("Cannot approve a task in status IN_PROGRESS");
                });
    }

    @Test
    void finalStatesGiveSpecificCodes() {
        assertThatThrownBy(() -> stateMachine.next(TaskStatus.APPROVED, TaskAction.CANCEL))
                .isInstanceOfSatisfying(ApiException.class,
                        ex -> assertThat(ex.getCode()).isEqualTo(TaskStateMachine.TASK_ALREADY_APPROVED));
        assertThatThrownBy(() -> stateMachine.next(TaskStatus.CANCELLED, TaskAction.START))
                .isInstanceOfSatisfying(ApiException.class,
                        ex -> assertThat(ex.getCode()).isEqualTo(TaskStateMachine.TASK_ALREADY_CANCELLED));
    }

    @Test
    void applyChangesTheTaskStatus() {
        Task task = new Task(mock(User.class), "Task", null, TaskPriority.LOW, Instant.now(), null);

        stateMachine.apply(task, TaskAction.ASSIGN);

        assertThat(task.getStatus()).isEqualTo(TaskStatus.ASSIGNED);
    }

    @Test
    void allowedActionsMatchTheTransitions() {
        assertThat(stateMachine.allowedActions(TaskStatus.SUBMITTED))
                .containsExactlyInAnyOrder(TaskAction.APPROVE, TaskAction.REJECT, TaskAction.REQUEST_CORRECTION);
        assertThat(stateMachine.allowedActions(TaskStatus.REJECTED))
                .containsExactlyInAnyOrder(TaskAction.START, TaskAction.CANCEL);
        assertThat(stateMachine.allowedActions(TaskStatus.APPROVED)).isEmpty();
        assertThat(stateMachine.allowedActions(TaskStatus.CANCELLED)).isEqualTo(Set.of());
    }

}
