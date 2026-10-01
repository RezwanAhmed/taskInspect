package com.taskinspect.auth;

import com.taskinspect.audit.AuditAction;
import com.taskinspect.audit.AuditService;
import com.taskinspect.auth.dto.LoginResponse;
import com.taskinspect.common.error.ApiException;
import com.taskinspect.users.Role;
import com.taskinspect.users.User;
import com.taskinspect.users.UserRepository;
import java.util.Optional;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class AuthService {

    static final String INVALID_CREDENTIALS = "INVALID_CREDENTIALS";
    static final String ACCOUNT_DISABLED = "ACCOUNT_DISABLED";

    private static final Logger log = LoggerFactory.getLogger(AuthService.class);

    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;
    private final JwtService jwtService;
    private final RefreshTokenService refreshTokenService;
    private final AuditService auditService;
    private final String dummyHash;

    public AuthService(UserRepository userRepository, PasswordEncoder passwordEncoder, JwtService jwtService,
            RefreshTokenService refreshTokenService, AuditService auditService) {
        this.userRepository = userRepository;
        this.passwordEncoder = passwordEncoder;
        this.jwtService = jwtService;
        this.refreshTokenService = refreshTokenService;
        this.auditService = auditService;
        // Checked when the email is unknown, so the response takes as long as for a real user
        this.dummyHash = passwordEncoder.encode("dummy-password-for-unknown-users");
    }

    /**
     * Checks the email and password and returns an access token. Unknown
     * emails and wrong passwords give the same error, so the response does
     * not reveal which emails are registered.
     */
    @Transactional
    public LoginResponse login(String email, String password) {
        Optional<User> found = userRepository.findByEmail(User.normalizeEmail(email));
        boolean passwordMatches = passwordEncoder.matches(password,
                found.map(User::getPasswordHash).orElse(dummyHash));
        if (found.isEmpty() || !passwordMatches) {
            auditLoginFailed(found.orElse(null), User.normalizeEmail(email), "wrong email or password");
            throw new ApiException(HttpStatus.UNAUTHORIZED, INVALID_CREDENTIALS, "Email or password is incorrect");
        }
        User user = found.get();
        if (!user.isActive()) {
            auditLoginFailed(user, user.getEmail(), "account deactivated");
        }
        requireActive(user);
        auditService.record(new AuditService.Entry(AuditAction.LOGIN_SUCCEEDED, user.getOrganization().getId(),
                user.getId(), "USER", user.getId(), null));
        return tokens(user, refreshTokenService.issue(user));
    }

    /**
     * Exchanges a refresh token for a new access token and a new refresh
     * token. The old refresh token can no longer be used.
     */
    @Transactional(noRollbackFor = ApiException.class)
    public LoginResponse refresh(String refreshToken) {
        RefreshTokenService.Rotation rotation = refreshTokenService.rotate(refreshToken);
        User user = rotation.user();
        if (!user.isActive()) {
            refreshTokenService.revokeAll(user);
        }
        requireActive(user);
        return tokens(user, rotation.refreshToken());
    }

    /**
     * Failed logins are kept even though the request ends in an error. If the
     * audit entry cannot be written, the login still gets its normal answer.
     */
    private void auditLoginFailed(User user, String email, String why) {
        try {
            auditService.recordAlways(new AuditService.Entry(AuditAction.LOGIN_FAILED,
                    user == null ? null : user.getOrganization().getId(), user == null ? null : user.getId(),
                    "USER", user == null ? null : user.getId(), "email: " + email + "; " + why));
        } catch (RuntimeException ex) {
            log.warn("Could not write audit entry for failed login of {}", email, ex);
        }
    }

    private static void requireActive(User user) {
        if (!user.isActive()) {
            throw new ApiException(HttpStatus.FORBIDDEN, ACCOUNT_DISABLED, "This account has been deactivated");
        }
    }

    private LoginResponse tokens(User user, IssuedRefreshToken refreshToken) {
        AccessToken accessToken = jwtService.issueAccessToken(user);
        return new LoginResponse(accessToken.value(), "Bearer", accessToken.expiresAt(),
                refreshToken.value(), refreshToken.expiresAt(), new LoginResponse.UserSummary(
                        user.getId(), user.getEmail(), user.getFullName(),
                        user.getRoles().stream().map(Role::getName).map(Enum::name).sorted().toList()));
    }

}
