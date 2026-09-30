package com.taskinspect.auth.dto;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

/**
 * Result of a successful login. The client sends {@code accessToken} as
 * {@code Authorization: Bearer <token>} until {@code expiresAt}.
 */
public record LoginResponse(
        String accessToken,
        String tokenType,
        Instant expiresAt,
        UserSummary user) {

    public record UserSummary(UUID id, String email, String fullName, List<String> roles) {
    }

}
