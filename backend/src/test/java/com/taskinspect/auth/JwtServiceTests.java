package com.taskinspect.auth;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import com.taskinspect.users.Role;
import com.taskinspect.users.RoleName;
import com.taskinspect.users.User;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.Set;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.security.oauth2.jwt.JwtException;

class JwtServiceTests {

    private static final String SECRET = "unit-test-secret-that-is-long-enough-1234";
    private static final UUID USER_ID = UUID.fromString("5b0e3c4a-8a9e-4a8e-9a55-1f2d3c4b5a69");

    private User user;

    @BeforeEach
    void setUp() {
        Role manager = mock(Role.class);
        when(manager.getName()).thenReturn(RoleName.MANAGER);
        Role worker = mock(Role.class);
        when(worker.getName()).thenReturn(RoleName.WORKER);
        user = mock(User.class);
        when(user.getId()).thenReturn(USER_ID);
        when(user.getEmail()).thenReturn("solo@example.com");
        when(user.getRoles()).thenReturn(Set.of(manager, worker));
    }

    @Test
    void issuedTokenIsValidAndCarriesUserClaims() {
        JwtService service = service(SECRET, "taskinspect", Clock.systemUTC());

        AccessToken token = service.issueAccessToken(user);
        Jwt jwt = service.validate(token.value());

        assertThat(jwt.getSubject()).isEqualTo(USER_ID.toString());
        assertThat(jwt.getClaimAsString(JwtService.CLAIM_EMAIL)).isEqualTo("solo@example.com");
        assertThat(jwt.getClaimAsStringList(JwtService.CLAIM_ROLES)).containsExactly("MANAGER", "WORKER");
        assertThat(jwt.getClaimAsString("iss")).isEqualTo("taskinspect");
        assertThat(Duration.between(jwt.getIssuedAt(), jwt.getExpiresAt())).isEqualTo(Duration.ofMinutes(15));
        assertThat(token.expiresAt()).isEqualTo(jwt.getExpiresAt());
    }

    @Test
    void tamperedTokenIsRejected() {
        JwtService service = service(SECRET, "taskinspect", Clock.systemUTC());
        String token = service.issueAccessToken(user).value();
        String[] parts = token.split("\\.");
        String tampered = parts[0] + "." + parts[1] + "x." + parts[2];

        assertThatThrownBy(() -> service.validate(tampered)).isInstanceOf(JwtException.class);
    }

    @Test
    void tokenSignedWithAnotherSecretIsRejected() {
        String token = service("another-secret-that-is-also-long-enough-99", "taskinspect", Clock.systemUTC())
                .issueAccessToken(user).value();

        assertThatThrownBy(() -> service(SECRET, "taskinspect", Clock.systemUTC()).validate(token))
                .isInstanceOf(JwtException.class);
    }

    @Test
    void expiredTokenIsRejected() {
        Clock anHourAgo = Clock.fixed(Instant.now().minus(Duration.ofHours(1)), ZoneOffset.UTC);
        String token = service(SECRET, "taskinspect", anHourAgo).issueAccessToken(user).value();

        assertThatThrownBy(() -> service(SECRET, "taskinspect", Clock.systemUTC()).validate(token))
                .isInstanceOf(JwtException.class)
                .hasMessageContaining("expired");
    }

    @Test
    void tokenFromAnotherIssuerIsRejected() {
        String token = service(SECRET, "someone-else", Clock.systemUTC()).issueAccessToken(user).value();

        assertThatThrownBy(() -> service(SECRET, "taskinspect", Clock.systemUTC()).validate(token))
                .isInstanceOf(JwtException.class);
    }

    @Test
    void shortSecretIsRefused() {
        assertThatThrownBy(() -> new JwtProperties("too-short", "taskinspect", Duration.ofMinutes(15)))
                .isInstanceOf(IllegalStateException.class)
                .hasMessageContaining("at least 32 characters");
    }

    private static JwtService service(String secret, String issuer, Clock clock) {
        JwtProperties properties = new JwtProperties(secret, issuer, Duration.ofMinutes(15));
        JwtConfig config = new JwtConfig();
        return new JwtService(config.jwtEncoder(properties), config.jwtDecoder(properties), properties, clock);
    }

}
