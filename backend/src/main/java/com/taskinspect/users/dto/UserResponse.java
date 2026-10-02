package com.taskinspect.users.dto;

import com.taskinspect.users.Role;
import com.taskinspect.users.User;
import java.time.Instant;
import java.util.List;
import java.util.UUID;

/** A user as returned by the API. Never contains the password hash. */
public record UserResponse(
        UUID id,
        String email,
        String fullName,
        List<String> roles,
        boolean active,
        TeamManagerRef teamManager,
        Instant createdAt) {

    public static UserResponse from(User user) {
        User manager = user.getTeamManager();
        return new UserResponse(user.getId(), user.getEmail(), user.getFullName(),
                user.getRoles().stream().map(Role::getName).map(Enum::name).sorted().toList(),
                user.isActive(), manager == null ? null : new TeamManagerRef(manager.getId(), manager.getFullName()),
                user.getCreatedAt());
    }

    /** The manager whose team the user is in. */
    public record TeamManagerRef(UUID id, String fullName) {
    }

}
