package com.taskinspect.auth;

import java.time.Instant;

/** A signed access token and the moment it stops being valid. */
public record AccessToken(String value, Instant expiresAt) {
}
