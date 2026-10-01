package com.taskinspect.users;

import com.taskinspect.audit.AuditAction;
import com.taskinspect.audit.AuditService;
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
    static final String NOT_A_WORKER = "NOT_A_WORKER";
    static final String INVALID_TEAM_MANAGER = "INVALID_TEAM_MANAGER";

    private final UserRepository userRepository;
    private final RoleRepository roleRepository;
    private final PasswordEncoder passwordEncoder;
    private final AuditService auditService;

    public UserService(UserRepository userRepository, RoleRepository roleRepository,
            PasswordEncoder passwordEncoder, AuditService auditService) {
        this.userRepository = userRepository;
        this.roleRepository = roleRepository;
        this.passwordEncoder = passwordEncoder;
        this.auditService = auditService;
    }

    @Transactional(readOnly = true)
    public Page<User> list(CurrentUser caller, RoleName role, Pageable pageable) {
        UUID organizationId = organizationOf(caller);
        return role == null
                ? userRepository.findAllByOrganizationId(organizationId, pageable)
                : userRepository.findAllByOrganizationIdAndRolesName(organizationId, role, pageable);
    }

    /** The workers in a manager's team. */
    @Transactional(readOnly = true)
    public Page<User> listTeam(CurrentUser caller, UUID teamManagerId, Pageable pageable) {
        return userRepository.findAllByOrganizationIdAndTeamManagerId(organizationOf(caller), teamManagerId, pageable);
    }

    /**
     * Puts a worker into an active manager's team of the same organization,
     * or takes them out of their team ({@code managerId} null). A worker is
     * in at most one team (docs/architecture.md "Teams").
     */
    @Transactional
    public User setTeam(CurrentUser caller, UUID userId, UUID managerId) {
        User admin = requireCaller(caller);
        UUID organizationId = admin.getOrganization().getId();
        User worker = userRepository.findByIdAndOrganizationId(userId, organizationId)
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, USER_NOT_FOUND, "User not found"));
        if (!worker.hasRole(RoleName.WORKER)) {
            throw new ApiException(HttpStatus.BAD_REQUEST, NOT_A_WORKER, "Only workers are put into a team");
        }
        User manager = managerId == null ? null : requireActiveWithRole(managerId, organizationId, RoleName.MANAGER,
                INVALID_TEAM_MANAGER, "The team manager must be an active manager of the organization");
        if (manager != null && manager.getId().equals(worker.getId())) {
            throw new ApiException(HttpStatus.BAD_REQUEST, INVALID_TEAM_MANAGER, "A worker can't be their own manager");
        }
        worker.joinTeamOf(manager);
        auditService.record(new AuditService.Entry(AuditAction.USER_TEAM_CHANGED, organizationId, admin.getId(),
                "USER", worker.getId(), manager == null ? "no team" : "team of " + manager.getId()));
        return userRepository.saveAndFlush(worker);
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
        User user = userRepository.save(new User(creator.getOrganization(), email,
                passwordEncoder.encode(request.password()), request.fullName().trim(), roles));
        auditService.record(new AuditService.Entry(AuditAction.USER_CREATED, creator.getOrganization().getId(),
                creator.getId(), "USER", user.getId(), "email: " + email + ", roles: " + request.roles()));
        return user;
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
