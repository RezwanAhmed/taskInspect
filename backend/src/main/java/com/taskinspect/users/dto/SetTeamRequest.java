package com.taskinspect.users.dto;

import com.fasterxml.jackson.annotation.JsonProperty;
import java.util.UUID;

/**
 * The manager whose team the worker joins; {@code null} takes them out of
 * their team. The field must be sent (also as null), so a mistyped body
 * can't remove a worker from their team by accident.
 */
public record SetTeamRequest(@JsonProperty(required = true) UUID managerId) {
}
