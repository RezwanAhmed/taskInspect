package com.taskinspect.tasks;

import com.taskinspect.users.User;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Changes a task's status and records the change in the status history in
 * the same transaction, so no status change can go unrecorded.
 */
@Service
public class TaskTransitionService {

    private final TaskStateMachine stateMachine;
    private final TaskStatusChangeRepository historyRepository;

    public TaskTransitionService(TaskStateMachine stateMachine, TaskStatusChangeRepository historyRepository) {
        this.stateMachine = stateMachine;
        this.historyRepository = historyRepository;
    }

    /** Records that a new task was created as DRAFT. */
    @Transactional
    public void recordCreated(Task task, User by) {
        historyRepository.save(new TaskStatusChange(task, null, task.getStatus(), by, null));
    }

    /**
     * Applies the action through the state machine (409 if not allowed) and
     * records the change.
     */
    @Transactional
    public void apply(Task task, TaskAction action, User by, String reason) {
        TaskStatus from = task.getStatus();
        stateMachine.apply(task, action);
        historyRepository.save(new TaskStatusChange(task, from, task.getStatus(), by, reason));
    }

}
