package com.taskinspect.auth;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.taskinspect.audit.AuditAction;
import com.taskinspect.audit.AuditService;
import com.taskinspect.auth.dto.LoginResponse;
import com.taskinspect.common.error.ApiException;
import com.taskinspect.users.Organization;
import com.taskinspect.users.Role;
import com.taskinspect.users.RoleName;
import com.taskinspect.users.User;
import com.taskinspect.users.UserRepository;
import java.time.Instant;
import java.util.Optional;
import java.util.Set;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpStatus;
import org.springframework.security.crypto.password.PasswordEncoder;

/** Unit tests of the login and refresh rules (task 9.1e). */
class AuthServiceTests {

    private static final String DUMMY_HASH = "dummy-hash";
    private static final AccessToken ACCESS = new AccessToken("access", Instant.parse("2026-10-02T10:15:00Z"));
    private static final IssuedRefreshToken REFRESH = new IssuedRefreshToken("refresh",
            Instant.parse("2026-11-01T10:00:00Z"));

    private final UserRepository userRepository = mock(UserRepository.class);
    private final PasswordEncoder passwordEncoder = mock(PasswordEncoder.class);
    private final JwtService jwtService = mock(JwtService.class);
    private final RefreshTokenService refreshTokenService = mock(RefreshTokenService.class);
    private final AuditService auditService = mock(AuditService.class);
    private final AuthService service = newService();

    private final UUID organizationId = UUID.randomUUID();
    private final User wendy = user(true);

    @Test
    void aCorrectLoginGivesTokensAndIsAudited() {
        when(passwordEncoder.matches("secret", "wendy-hash")).thenReturn(true);
        when(refreshTokenService.issue(wendy)).thenReturn(REFRESH);
        when(jwtService.issueAccessToken(wendy)).thenReturn(ACCESS);

        LoginResponse response = service.login("  Wendy@Example.COM ", "secret");

        assertThat(response.accessToken()).isEqualTo("access");
        assertThat(response.tokenType()).isEqualTo("Bearer");
        assertThat(response.refreshToken()).isEqualTo("refresh");
        assertThat(response.user().roles()).containsExactly("MANAGER", "WORKER");
        verify(auditService).record(new AuditService.Entry(AuditAction.LOGIN_SUCCEEDED, organizationId,
                wendy.getId(), "USER", wendy.getId(), null));
    }

    @Test
    void anUnknownEmailIsCheckedAgainstADummyHashAndGetsTheSameError() {
        assertRefused(() -> service.login("nobody@example.com", "secret"), HttpStatus.UNAUTHORIZED,
                AuthService.INVALID_CREDENTIALS);

        verify(passwordEncoder).matches("secret", DUMMY_HASH);
        verify(auditService).recordAlways(new AuditService.Entry(AuditAction.LOGIN_FAILED, null, null, "USER", null,
                "email: nobody@example.com; wrong email or password"));
    }

    @Test
    void aWrongPasswordIsRefusedAndAudited() {
        when(passwordEncoder.matches("wrong", "wendy-hash")).thenReturn(false);

        assertRefused(() -> service.login("wendy@example.com", "wrong"), HttpStatus.UNAUTHORIZED,
                AuthService.INVALID_CREDENTIALS);

        verify(passwordEncoder).matches("wrong", "wendy-hash");
        verify(auditService).recordAlways(new AuditService.Entry(AuditAction.LOGIN_FAILED, organizationId,
                wendy.getId(), "USER", wendy.getId(), "email: wendy@example.com; wrong email or password"));
    }

    @Test
    void aDeactivatedAccountCannotLogInEvenWithTheRightPassword() {
        when(wendy.isActive()).thenReturn(false);
        when(passwordEncoder.matches("secret", "wendy-hash")).thenReturn(true);

        assertRefused(() -> service.login("wendy@example.com", "secret"), HttpStatus.FORBIDDEN,
                AuthService.ACCOUNT_DISABLED);

        verify(auditService).recordAlways(new AuditService.Entry(AuditAction.LOGIN_FAILED, organizationId,
                wendy.getId(), "USER", wendy.getId(), "email: wendy@example.com; account deactivated"));
    }

    @Test
    void aFailingAuditDoesNotChangeTheAnswer() {
        doThrow(new IllegalStateException("database down")).when(auditService).recordAlways(any());
        when(passwordEncoder.matches("wrong", "wendy-hash")).thenReturn(false);

        assertRefused(() -> service.login("wendy@example.com", "wrong"), HttpStatus.UNAUTHORIZED,
                AuthService.INVALID_CREDENTIALS);
    }

    @Test
    void refreshingGivesNewTokens() {
        when(refreshTokenService.rotate("old")).thenReturn(new RefreshTokenService.Rotation(wendy, REFRESH));
        when(jwtService.issueAccessToken(wendy)).thenReturn(ACCESS);

        LoginResponse response = service.refresh("old");

        assertThat(response.accessToken()).isEqualTo("access");
        assertThat(response.refreshToken()).isEqualTo("refresh");
        verify(refreshTokenService, never()).revokeAll(any());
    }

    @Test
    void refreshingForADeactivatedAccountRevokesAllItsTokens() {
        when(wendy.isActive()).thenReturn(false);
        when(refreshTokenService.rotate("old")).thenReturn(new RefreshTokenService.Rotation(wendy, REFRESH));

        assertThatThrownBy(() -> service.refresh("old"))
                .isInstanceOf(ApiException.class)
                .extracting("status", "code")
                .containsExactly(HttpStatus.FORBIDDEN, AuthService.ACCOUNT_DISABLED);
        verify(refreshTokenService).revokeAll(wendy);
        verify(jwtService, never()).issueAccessToken(any());
    }

    private AuthService newService() {
        // The service hashes a dummy password once, when it is created.
        when(passwordEncoder.encode(any())).thenReturn(DUMMY_HASH);
        return new AuthService(userRepository, passwordEncoder, jwtService, refreshTokenService, auditService);
    }

    private void assertRefused(Runnable action, HttpStatus status, String code) {
        assertThatThrownBy(action::run)
                .isInstanceOf(ApiException.class)
                .extracting("status", "code")
                .containsExactly(status, code);
        verify(refreshTokenService, never()).issue(any());
        verify(jwtService, never()).issueAccessToken(any());
    }

    private User user(boolean active) {
        Organization organization = mock(Organization.class);
        when(organization.getId()).thenReturn(organizationId);
        User user = mock(User.class);
        when(user.getId()).thenReturn(UUID.randomUUID());
        when(user.getOrganization()).thenReturn(organization);
        when(user.getEmail()).thenReturn("wendy@example.com");
        when(user.getFullName()).thenReturn("Wendy Worker");
        when(user.getPasswordHash()).thenReturn("wendy-hash");
        when(user.isActive()).thenReturn(active);
        Set<Role> roles = Set.of(role(RoleName.WORKER), role(RoleName.MANAGER));
        when(user.getRoles()).thenReturn(roles);
        when(userRepository.findByEmail("wendy@example.com")).thenReturn(Optional.of(user));
        return user;
    }

    private static Role role(RoleName name) {
        Role role = mock(Role.class);
        when(role.getName()).thenReturn(name);
        return role;
    }

}
