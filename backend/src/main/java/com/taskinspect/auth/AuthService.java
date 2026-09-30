package com.taskinspect.auth;

import com.taskinspect.auth.dto.LoginResponse;
import com.taskinspect.common.error.ApiException;
import com.taskinspect.users.Role;
import com.taskinspect.users.User;
import com.taskinspect.users.UserRepository;
import java.util.Optional;
import org.springframework.http.HttpStatus;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class AuthService {

    static final String INVALID_CREDENTIALS = "INVALID_CREDENTIALS";
    static final String ACCOUNT_DISABLED = "ACCOUNT_DISABLED";

    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;
    private final JwtService jwtService;
    private final String dummyHash;

    public AuthService(UserRepository userRepository, PasswordEncoder passwordEncoder, JwtService jwtService) {
        this.userRepository = userRepository;
        this.passwordEncoder = passwordEncoder;
        this.jwtService = jwtService;
        // Checked when the email is unknown, so the response takes as long as for a real user
        this.dummyHash = passwordEncoder.encode("dummy-password-for-unknown-users");
    }

    /**
     * Checks the email and password and returns an access token. Unknown
     * emails and wrong passwords give the same error, so the response does
     * not reveal which emails are registered.
     */
    @Transactional(readOnly = true)
    public LoginResponse login(String email, String password) {
        Optional<User> found = userRepository.findByEmail(User.normalizeEmail(email));
        boolean passwordMatches = passwordEncoder.matches(password,
                found.map(User::getPasswordHash).orElse(dummyHash));
        if (found.isEmpty() || !passwordMatches) {
            throw new ApiException(HttpStatus.UNAUTHORIZED, INVALID_CREDENTIALS, "Email or password is incorrect");
        }
        User user = found.get();
        if (!user.isActive()) {
            throw new ApiException(HttpStatus.FORBIDDEN, ACCOUNT_DISABLED, "This account has been deactivated");
        }

        AccessToken token = jwtService.issueAccessToken(user);
        return new LoginResponse(token.value(), "Bearer", token.expiresAt(), new LoginResponse.UserSummary(
                user.getId(), user.getEmail(), user.getFullName(),
                user.getRoles().stream().map(Role::getName).map(Enum::name).sorted().toList()));
    }

}
