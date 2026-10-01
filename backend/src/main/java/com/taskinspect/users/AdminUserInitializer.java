package com.taskinspect.users;

import com.taskinspect.audit.AuditAction;
import com.taskinspect.audit.AuditService;
import java.util.Set;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

/**
 * Creates the first administrator when the application starts, so a new
 * installation can be logged into. Does nothing once an administrator
 * exists. The password is only ever stored as a BCrypt hash.
 */
@Component
@EnableConfigurationProperties(AdminProperties.class)
public class AdminUserInitializer implements ApplicationRunner {

    static final int MIN_PASSWORD_LENGTH = 12;

    private static final Logger log = LoggerFactory.getLogger(AdminUserInitializer.class);

    private final AdminProperties properties;
    private final UserRepository userRepository;
    private final RoleRepository roleRepository;
    private final OrganizationRepository organizationRepository;
    private final PasswordEncoder passwordEncoder;
    private final AuditService auditService;

    public AdminUserInitializer(AdminProperties properties, UserRepository userRepository,
            RoleRepository roleRepository, OrganizationRepository organizationRepository,
            PasswordEncoder passwordEncoder, AuditService auditService) {
        this.properties = properties;
        this.userRepository = userRepository;
        this.roleRepository = roleRepository;
        this.organizationRepository = organizationRepository;
        this.passwordEncoder = passwordEncoder;
        this.auditService = auditService;
    }

    @Override
    @Transactional
    public void run(ApplicationArguments args) {
        if (userRepository.existsByRolesName(RoleName.ADMINISTRATOR)) {
            return;
        }
        if (!properties.isConfigured()) {
            log.warn("No administrator exists. Set ADMIN_EMAIL and ADMIN_PASSWORD to create one on startup.");
            return;
        }
        if (properties.password().length() < MIN_PASSWORD_LENGTH) {
            throw new IllegalStateException(
                    "ADMIN_PASSWORD must be at least " + MIN_PASSWORD_LENGTH + " characters long");
        }
        String email = User.normalizeEmail(properties.email());
        if (userRepository.existsByEmail(email)) {
            throw new IllegalStateException("ADMIN_EMAIL belongs to an existing user who is not an administrator");
        }

        Role administrator = roleRepository.findByName(RoleName.ADMINISTRATOR)
                .orElseThrow(() -> new IllegalStateException("ADMINISTRATOR role is missing"));
        User admin = userRepository.save(new User(organizationRepository.getDefault(), email,
                passwordEncoder.encode(properties.password()), properties.fullName(), Set.of(administrator)));
        auditService.record(new AuditService.Entry(AuditAction.USER_CREATED, admin.getOrganization().getId(), null,
                "USER", admin.getId(), "first administrator created on startup"));
        log.info("Created administrator {}", email);
    }

}
