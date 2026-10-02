package com.taskinspect.common.security;

import java.util.List;
import java.util.Objects;
import java.util.UUID;
import org.springframework.security.oauth2.jwt.Jwt;

/**
 * The authenticated user of the current request, read from the access
 * token. Services use it for ownership checks such as "is this the
 * assigned worker?".
 */
public record CurrentUser(UUID id, String email, List<String> roles) {

    public CurrentUser {
        roles = roles == null ? List.of() : List.copyOf(roles);
    }

    public static CurrentUser from(Jwt jwt) {
        List<String> roles = jwt.getClaimAsStringList("roles");
        // The decoder only accepts tokens issued by this server, which always have a subject.
        return new CurrentUser(UUID.fromString(Objects.requireNonNull(jwt.getSubject())), jwt.getClaimAsString("email"),
                roles);
    }

    public boolean hasRole(String role) {
        return roles.contains(role);
    }

}
