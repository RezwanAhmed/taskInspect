package com.taskinspect.auth;

import com.taskinspect.audit.AuditAction;
import com.taskinspect.audit.AuditService;
import com.taskinspect.common.error.ApiException;
import com.taskinspect.users.User;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.security.SecureRandom;
import java.time.Clock;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.Base64;
import java.util.HexFormat;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Creates, rotates and revokes refresh tokens (see ADR-0003). A token is
 * 256 random bits; only its SHA-256 hash is stored.
 */
@Service
@EnableConfigurationProperties(RefreshTokenProperties.class)
public class RefreshTokenService {

    static final String INVALID_REFRESH_TOKEN = "INVALID_REFRESH_TOKEN";

    private static final Logger log = LoggerFactory.getLogger(RefreshTokenService.class);
    private static final SecureRandom RANDOM = new SecureRandom();

    private final RefreshTokenRepository repository;
    private final RefreshTokenProperties properties;
    private final Clock clock;
    private final AuditService auditService;

    public RefreshTokenService(RefreshTokenRepository repository, RefreshTokenProperties properties, Clock clock,
            AuditService auditService) {
        this.repository = repository;
        this.properties = properties;
        this.clock = clock;
        this.auditService = auditService;
    }

    @Transactional
    public IssuedRefreshToken issue(User user) {
        return create(user, now()).issued();
    }

    /**
     * Exchanges a valid refresh token for a new one and returns the user it
     * belongs to. The old token is revoked. Presenting an already revoked
     * token revokes every token of that user, because it was probably
     * stolen; that revocation is kept even though an error is returned.
     */
    @Transactional(noRollbackFor = ApiException.class)
    public Rotation rotate(String rawToken) {
        Instant now = now();
        RefreshToken current = repository.findByTokenHash(hash(rawToken)).orElseThrow(RefreshTokenService::invalid);
        User user = current.getUser();
        if (current.isRevoked()) {
            repository.revokeAllForUser(user.getId(), now);
            auditService.record(new AuditService.Entry(AuditAction.REFRESH_TOKEN_REUSED,
                    user.getOrganization().getId(), user.getId(), "USER", user.getId(),
                    "revoked refresh token used again; all refresh tokens of the user revoked"));
            log.warn("Revoked refresh token reused for user {}; all refresh tokens of the user revoked", user.getId());
            throw invalid();
        }
        if (current.isExpired(now)) {
            throw invalid();
        }
        Created next = create(user, now);
        current.revoke(now, next.entity().getId());
        return new Rotation(user, next.issued());
    }

    /** Revokes one token (logout). Unknown or already revoked tokens are ignored. */
    @Transactional
    public void revoke(String rawToken) {
        repository.findByTokenHash(hash(rawToken))
                .filter(token -> !token.isRevoked())
                .ifPresent(token -> token.revoke(now(), null));
    }

    @Transactional
    public void revokeAll(User user) {
        repository.revokeAllForUser(user.getId(), now());
    }

    private Created create(User user, Instant now) {
        byte[] bytes = new byte[32];
        RANDOM.nextBytes(bytes);
        String value = Base64.getUrlEncoder().withoutPadding().encodeToString(bytes);
        Instant expiresAt = now.plus(properties.ttl());
        RefreshToken entity = repository.save(new RefreshToken(user, hash(value), now, expiresAt));
        return new Created(entity, new IssuedRefreshToken(value, expiresAt));
    }

    private Instant now() {
        return clock.instant().truncatedTo(ChronoUnit.SECONDS);
    }

    static String hash(String rawToken) {
        try {
            byte[] digest = MessageDigest.getInstance("SHA-256").digest(rawToken.getBytes(StandardCharsets.UTF_8));
            return HexFormat.of().formatHex(digest);
        } catch (NoSuchAlgorithmException e) {
            throw new IllegalStateException("SHA-256 is not available", e);
        }
    }

    private static ApiException invalid() {
        return new ApiException(HttpStatus.UNAUTHORIZED, INVALID_REFRESH_TOKEN,
                "Refresh token is invalid or expired. Please sign in again.");
    }

    /** The user a refresh token belonged to and the token that replaces it. */
    public record Rotation(User user, IssuedRefreshToken refreshToken) {
    }

    private record Created(RefreshToken entity, IssuedRefreshToken issued) {
    }

}
