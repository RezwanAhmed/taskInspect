package com.taskinspect.auth.dto;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

/**
 * Tokens returned by login and refresh. The client sends
 * {@code accessToken} as {@code Authorization: Bearer <token>} until
 * {@code expiresAt}, then calls {@code POST /api/auth/refresh} with
 * {@code refreshToken} to get a new pair. Each refresh token works once.
 */
public record LoginResponse(
        String accessToken,
        String tokenType,
        Instant expiresAt,
        String refreshToken,
        Instant refreshTokenExpiresAt,
        UserSummary user) {

    public record UserSummary(UUID id, String email, String fullName, List<String> roles) {
    }

}
