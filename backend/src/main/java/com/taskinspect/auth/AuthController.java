package com.taskinspect.auth;

import com.taskinspect.auth.dto.CurrentUserResponse;
import com.taskinspect.auth.dto.LoginRequest;
import com.taskinspect.auth.dto.LoginResponse;
import com.taskinspect.auth.dto.RefreshRequest;
import com.taskinspect.common.config.OpenApiConfig;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import java.util.Objects;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/auth")
@Tag(name = "Authentication")
public class AuthController {

    private final AuthService authService;
    private final RefreshTokenService refreshTokenService;

    public AuthController(AuthService authService, RefreshTokenService refreshTokenService) {
        this.authService = authService;
        this.refreshTokenService = refreshTokenService;
    }

    @PostMapping("/login")
    @Operation(summary = "Log in with email and password",
            description = "Returns a short-lived access token to send as `Authorization: Bearer <token>`.")
    public LoginResponse login(@Valid @RequestBody LoginRequest request) {
        return authService.login(request.email(), request.password());
    }

    @PostMapping("/refresh")
    @Operation(summary = "Get new tokens with a refresh token",
            description = "Returns a new access token and a new refresh token. "
                    + "The refresh token that was sent can not be used again.")
    public LoginResponse refresh(@Valid @RequestBody RefreshRequest request) {
        return authService.refresh(request.refreshToken());
    }

    @PostMapping("/logout")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    @Operation(summary = "Log out",
            description = "Revokes the refresh token, so it can no longer be used. Works without an access "
                    + "token and always returns 204, whether or not the token was known. The current access "
                    + "token stays valid until it expires (at most 15 minutes); the app deletes it.")
    public void logout(@Valid @RequestBody RefreshRequest request) {
        refreshTokenService.revoke(request.refreshToken());
    }

    @GetMapping("/me")
    @Operation(summary = "Who am I?", description = "Returns the user the access token belongs to.")
    @SecurityRequirement(name = OpenApiConfig.BEARER_AUTH)
    public CurrentUserResponse me(@AuthenticationPrincipal Jwt jwt) {
        // The decoder only accepts tokens issued by this server, which always have a subject.
        return new CurrentUserResponse(UUID.fromString(Objects.requireNonNull(jwt.getSubject())),
                jwt.getClaimAsString(JwtService.CLAIM_EMAIL),
                jwt.getClaimAsStringList(JwtService.CLAIM_ROLES),
                jwt.getExpiresAt());
    }

}
