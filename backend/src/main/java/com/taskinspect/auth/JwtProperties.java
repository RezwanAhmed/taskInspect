package com.taskinspect.auth;

import java.nio.charset.StandardCharsets;
import java.time.Duration;
import org.springframework.boot.context.properties.ConfigurationProperties;

/**
 * JWT settings: the signing secret ({@code JWT_SECRET}), the issuer and how
 * long an access token is valid ({@code JWT_ACCESS_TOKEN_TTL}, default 15m).
 */
@ConfigurationProperties(prefix = "taskinspect.jwt")
public record JwtProperties(String secret, String issuer, Duration accessTokenTtl) {

    /** HS256 needs a key of at least 256 bits. */
    static final int MIN_SECRET_BYTES = 32;

    public JwtProperties {
        if (secret == null || secret.getBytes(StandardCharsets.UTF_8).length < MIN_SECRET_BYTES) {
            throw new IllegalStateException(
                    "JWT_SECRET must be set and at least " + MIN_SECRET_BYTES + " characters long");
        }
    }

}
