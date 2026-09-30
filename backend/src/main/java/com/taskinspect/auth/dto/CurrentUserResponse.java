package com.taskinspect.auth.dto;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

/** Who the access token belongs to, and until when it is valid. */
public record CurrentUserResponse(UUID id, String email, List<String> roles, Instant tokenExpiresAt) {
}
