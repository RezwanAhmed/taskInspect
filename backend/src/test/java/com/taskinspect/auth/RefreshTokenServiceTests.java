package com.taskinspect.auth;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

import com.taskinspect.audit.AuditAction;
import com.taskinspect.audit.AuditService;
import com.taskinspect.common.error.ApiException;
import com.taskinspect.users.Organization;
import com.taskinspect.users.User;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.Optional;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.http.HttpStatus;
import org.springframework.test.util.ReflectionTestUtils;

/** Unit tests of issuing, rotating and revoking refresh tokens (task 9.1e). */
class RefreshTokenServiceTests {

    /** Token times are stored to the second. */
    private static final Instant NOW = Instant.parse("2026-10-02T10:00:00Z");

    private final RefreshTokenRepository repository = mock(RefreshTokenRepository.class);
    private final AuditService auditService = mock(AuditService.class);
    private final RefreshTokenService service = new RefreshTokenService(repository,
            new RefreshTokenProperties(Duration.ofDays(30)), Clock.fixed(NOW.plusMillis(750), ZoneOffset.UTC),
            auditService);

    private final User user = user();

    RefreshTokenServiceTests() {
        when(repository.save(any(RefreshToken.class))).thenAnswer(invocation -> {
            RefreshToken saved = invocation.getArgument(0);
            ReflectionTestUtils.setField(saved, "id", UUID.randomUUID());
            return saved;
        });
    }

    @Test
    void anIssuedTokenIsStoredOnlyAsItsHash() {
        IssuedRefreshToken issued = service.issue(user);

        assertThat(issued.expiresAt()).isEqualTo(NOW.plus(Duration.ofDays(30)));
        ArgumentCaptor<RefreshToken> stored = ArgumentCaptor.forClass(RefreshToken.class);
        verify(repository).save(stored.capture());
        assertThat(ReflectionTestUtils.getField(stored.getValue(), "tokenHash"))
                .isEqualTo(RefreshTokenService.hash(issued.value()))
                .isNotEqualTo(issued.value());
        assertThat(stored.getValue().getExpiresAt()).isEqualTo(issued.expiresAt());
    }

    @Test
    void tokensAreRandom() {
        assertThat(service.issue(user).value()).isNotEqualTo(service.issue(user).value());
    }

    @Test
    void rotatingRevokesTheOldTokenAndPointsToItsReplacement() {
        RefreshToken current = stored("old", NOW.plusSeconds(60));

        RefreshTokenService.Rotation rotation = service.rotate("old");

        assertThat(rotation.user()).isSameAs(user);
        assertThat(rotation.refreshToken().value()).isNotEqualTo("old");
        assertThat(current.getRevokedAt()).isEqualTo(NOW);
        ArgumentCaptor<RefreshToken> replacement = ArgumentCaptor.forClass(RefreshToken.class);
        verify(repository).save(replacement.capture());
        assertThat(current.getReplacedBy()).isEqualTo(replacement.getValue().getId());
    }

    @Test
    void unknownAndExpiredTokensAreRefused() {
        RefreshToken expired = stored("expired", NOW);

        assertInvalid("unknown");
        assertInvalid("expired");
        assertThat(expired.getRevokedAt()).isNull();
        verify(repository, never()).save(any());
    }

    @Test
    void reusingARevokedTokenRevokesEveryTokenOfTheUser() {
        RefreshToken revoked = stored("stolen", NOW.plusSeconds(60));
        revoked.revoke(NOW.minusSeconds(5), null);

        assertInvalid("stolen");

        verify(repository).revokeAllForUser(user.getId(), NOW);
        ArgumentCaptor<AuditService.Entry> entry = ArgumentCaptor.forClass(AuditService.Entry.class);
        verify(auditService).record(entry.capture());
        assertThat(entry.getValue().action()).isEqualTo(AuditAction.REFRESH_TOKEN_REUSED);
        verify(repository, never()).save(any());
    }

    @Test
    void logoutRevokesTheTokenOnceAndIgnoresUnknownOnes() {
        RefreshToken token = stored("current", NOW.plusSeconds(60));
        RefreshToken revoked = stored("revoked", NOW.plusSeconds(60));
        revoked.revoke(NOW.minusSeconds(5), null);

        service.revoke("current");
        service.revoke("revoked");
        service.revoke("unknown");

        assertThat(token.getRevokedAt()).isEqualTo(NOW);
        assertThat(revoked.getRevokedAt()).isEqualTo(NOW.minusSeconds(5));
        verifyNoInteractions(auditService);
    }

    @Test
    void theHashIsHexSha256() {
        assertThat(RefreshTokenService.hash("abc"))
                .isEqualTo("ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad");
    }

    private RefreshToken stored(String rawToken, Instant expiresAt) {
        RefreshToken token = new RefreshToken(user, RefreshTokenService.hash(rawToken), NOW.minusSeconds(3600),
                expiresAt);
        when(repository.findByTokenHash(RefreshTokenService.hash(rawToken))).thenReturn(Optional.of(token));
        return token;
    }

    private void assertInvalid(String rawToken) {
        assertThatThrownBy(() -> service.rotate(rawToken))
                .isInstanceOf(ApiException.class)
                .extracting("status", "code")
                .containsExactly(HttpStatus.UNAUTHORIZED, RefreshTokenService.INVALID_REFRESH_TOKEN);
    }

    private static User user() {
        Organization organization = mock(Organization.class);
        when(organization.getId()).thenReturn(UUID.randomUUID());
        User user = mock(User.class);
        when(user.getId()).thenReturn(UUID.randomUUID());
        when(user.getOrganization()).thenReturn(organization);
        return user;
    }

}
