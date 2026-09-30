package com.taskinspect.common.security;

import java.util.List;
import java.util.UUID;
import org.springframework.security.oauth2.jwt.Jwt;

/**
 * The authenticated user of the current request, read from the access
 * token. Services use it for ownership checks such as "is this the
 * assigned worker?".
 */
public record CurrentUser(UUID id, String email, List<String> roles) {

    public static CurrentUser from(Jwt jwt) {
        List<String> roles = jwt.getClaimAsStringList("roles");
        return new CurrentUser(UUID.fromString(jwt.getSubject()), jwt.getClaimAsString("email"),
                roles == null ? List.of() : List.copyOf(roles));
    }

    public boolean hasRole(String role) {
        return roles.contains(role);
    }

}
