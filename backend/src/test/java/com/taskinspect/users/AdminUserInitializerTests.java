package com.taskinspect.users;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import com.taskinspect.TestcontainersConfiguration;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.context.annotation.Import;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.transaction.annotation.Transactional;

@Import(TestcontainersConfiguration.class)
@SpringBootTest(properties = {
        "ADMIN_EMAIL=Admin@Example.com",
        "ADMIN_PASSWORD=initial-admin-password",
        "ADMIN_FULL_NAME=First Admin"
})
@Transactional
class AdminUserInitializerTests {

    @Autowired
    private AdminUserInitializer initializer;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private RoleRepository roleRepository;

    @Autowired
    private OrganizationRepository organizationRepository;

    @Autowired
    private PasswordEncoder passwordEncoder;

    @Test
    void createsAdministratorOnStartupWithHashedPassword() {
        User admin = userRepository.findByEmail("admin@example.com").orElseThrow();

        assertThat(admin.hasRole(RoleName.ADMINISTRATOR)).isTrue();
        assertThat(admin.getFullName()).isEqualTo("First Admin");
        assertThat(admin.getPasswordHash()).isNotEqualTo("initial-admin-password");
        assertThat(passwordEncoder.matches("initial-admin-password", admin.getPasswordHash())).isTrue();
    }

    @Test
    void runningAgainDoesNotCreateASecondAdministrator() throws Exception {
        long before = userRepository.count();

        initializer.run(null);

        assertThat(userRepository.count()).isEqualTo(before);
    }

    @Test
    void skipsWhenNotConfigured() {
        userRepository.deleteAll();
        userRepository.flush();

        newInitializer(new AdminProperties("", "", "Administrator")).run(null);

        assertThat(userRepository.existsByRolesName(RoleName.ADMINISTRATOR)).isFalse();
    }

    @Test
    void rejectsShortPassword() {
        userRepository.deleteAll();
        userRepository.flush();

        assertThatThrownBy(() -> newInitializer(new AdminProperties("a@example.com", "short", "A")).run(null))
                .isInstanceOf(IllegalStateException.class)
                .hasMessageContaining("at least 12 characters");
    }

    private AdminUserInitializer newInitializer(AdminProperties properties) {
        return new AdminUserInitializer(properties, userRepository, roleRepository, organizationRepository,
                passwordEncoder);
    }

}
