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
import java.util.UUID;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/auth")
@Tag(name = "Authentication")
public class AuthController {

    private final AuthService authService;

    public AuthController(AuthService authService) {
        this.authService = authService;
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

    @GetMapping("/me")
    @Operation(summary = "Who am I?", description = "Returns the user the access token belongs to.")
    @SecurityRequirement(name = OpenApiConfig.BEARER_AUTH)
    public CurrentUserResponse me(@AuthenticationPrincipal Jwt jwt) {
        return new CurrentUserResponse(UUID.fromString(jwt.getSubject()),
                jwt.getClaimAsString(JwtService.CLAIM_EMAIL),
                jwt.getClaimAsStringList(JwtService.CLAIM_ROLES),
                jwt.getExpiresAt());
    }

}
