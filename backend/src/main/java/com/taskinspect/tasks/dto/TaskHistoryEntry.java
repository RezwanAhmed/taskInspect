package com.taskinspect.tasks.dto;

import com.taskinspect.tasks.TaskStatus;
import com.taskinspect.tasks.dto.TaskResponse.UserRef;
import java.time.Instant;

/**
 * One step of a task's history timeline.
 *
 * @param event  what happened
 * @param reason e.g. why the task was rejected
 */
public record TaskHistoryEntry(
        TaskHistoryEvent event,
        TaskStatus fromStatus,
        TaskStatus toStatus,
        UserRef by,
        Instant at,
        String reason) {
}
