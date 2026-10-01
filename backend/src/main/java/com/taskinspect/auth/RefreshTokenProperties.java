package com.taskinspect.auth;

import java.time.Duration;
import org.springframework.boot.context.properties.ConfigurationProperties;

/** How long a refresh token is valid ({@code REFRESH_TOKEN_TTL}, default 30 days). */
@ConfigurationProperties(prefix = "taskinspect.refresh-token")
public record RefreshTokenProperties(Duration ttl) {
}
