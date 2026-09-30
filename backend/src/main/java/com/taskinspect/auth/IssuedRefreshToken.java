package com.taskinspect.auth;

import java.time.Instant;

/** A newly created refresh token. The value is shown to the client once and never stored. */
public record IssuedRefreshToken(String value, Instant expiresAt) {
}
