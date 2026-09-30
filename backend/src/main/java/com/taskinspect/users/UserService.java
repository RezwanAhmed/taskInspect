package com.taskinspect.users;

import com.taskinspect.common.error.ApiException;
import com.taskinspect.common.error.ErrorCode;
import com.taskinspect.common.security.CurrentUser;
import com.taskinspect.users.dto.CreateUserRequest;
import java.util.Set;
import java.util.UUID;
import java.util.stream.Collectors;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.http.HttpStatus;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * User management. Every query is limited to the caller's organization, so
 * organizations stay separate once there is more than one.
 */
@Service
public class UserService {

    static final String USER_NOT_FOUND = "USER_NOT_FOUND";
    static final String EMAIL_ALREADY_USED = "EMAIL_ALREADY_USED";

    private final UserRepository userRepository;
    private final RoleRepository roleRepository;
    private final PasswordEncoder passwordEncoder;

    public UserService(UserRepository userRepository, RoleRepository roleRepository,
            PasswordEncoder passwordEncoder) {
        this.userRepository = userRepository;
        this.roleRepository = roleRepository;
        this.passwordEncoder = passwordEncoder;
    }

    @Transactional(readOnly = true)
    public Page<User> list(CurrentUser caller, RoleName role, Pageable pageable) {
        UUID organizationId = organizationOf(caller);
        return role == null
                ? userRepository.findAllByOrganizationId(organizationId, pageable)
                : userRepository.findAllByOrganizationIdAndRolesName(organizationId, role, pageable);
    }

    /** Administrators and managers can see any user of their organization; others only themselves. */
    @Transactional(readOnly = true)
    public User get(CurrentUser caller, UUID id) {
        boolean canSeeOthers = caller.hasRole(RoleName.ADMINISTRATOR.name()) || caller.hasRole(RoleName.MANAGER.name());
        if (!canSeeOthers && !caller.id().equals(id)) {
            throw new ApiException(HttpStatus.FORBIDDEN, ErrorCode.FORBIDDEN, "You are not allowed to do this");
        }
        return userRepository.findByIdAndOrganizationId(id, organizationOf(caller))
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, USER_NOT_FOUND, "User not found"));
    }

    @Transactional
    public User create(CurrentUser caller, CreateUserRequest request) {
        String email = User.normalizeEmail(request.email());
        if (userRepository.existsByEmail(email)) {
            throw new ApiException(HttpStatus.CONFLICT, EMAIL_ALREADY_USED, "A user with this email already exists");
        }
        Set<Role> roles = request.roles().stream()
                .map(name -> roleRepository.findByName(name).orElseThrow())
                .collect(Collectors.toSet());
        User creator = userRepository.findById(caller.id())
                .orElseThrow(() -> new ApiException(HttpStatus.UNAUTHORIZED, ErrorCode.UNAUTHORIZED, "Unknown user"));
        return userRepository.save(new User(creator.getOrganization(), email,
                passwordEncoder.encode(request.password()), request.fullName().trim(), roles));
    }

    /** The caller's own user record, for other modules (e.g. the creator of a task). */
    @Transactional(readOnly = true)
    public User requireCaller(CurrentUser caller) {
        return userRepository.findById(caller.id())
                .orElseThrow(() -> new ApiException(HttpStatus.UNAUTHORIZED, ErrorCode.UNAUTHORIZED, "Unknown user"));
    }

    /**
     * An active user of the organization who has the given role, or
     * {@code errorCode} (400) if there is none — e.g. to check a chosen reviewer.
     */
    @Transactional(readOnly = true)
    public User requireActiveWithRole(UUID id, UUID organizationId, RoleName role, String errorCode, String message) {
        return userRepository.findByIdAndOrganizationId(id, organizationId)
                .filter(User::isActive)
                .filter(user -> user.hasRole(role))
                .orElseThrow(() -> new ApiException(HttpStatus.BAD_REQUEST, errorCode, message));
    }

    private UUID organizationOf(CurrentUser caller) {
        return userRepository.findById(caller.id())
                .map(user -> user.getOrganization().getId())
                .orElseThrow(() -> new ApiException(HttpStatus.UNAUTHORIZED, ErrorCode.UNAUTHORIZED, "Unknown user"));
    }

}
