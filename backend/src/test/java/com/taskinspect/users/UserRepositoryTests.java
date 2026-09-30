package com.taskinspect.users;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import com.taskinspect.TestcontainersConfiguration;
import java.util.Set;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.data.jpa.test.autoconfigure.DataJpaTest;
import org.springframework.boot.jpa.test.autoconfigure.TestEntityManager;
import org.springframework.context.annotation.Import;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;

@DataJpaTest
@Import(TestcontainersConfiguration.class)
class UserRepositoryTests {

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private RoleRepository roleRepository;

    @Autowired
    private OrganizationRepository organizationRepository;

    @Autowired
    private TestEntityManager entityManager;

    private Organization organization;
    private Role manager;
    private Role worker;

    @BeforeEach
    void setUp() {
        organization = organizationRepository.getDefault();
        manager = roleRepository.findByName(RoleName.MANAGER).orElseThrow();
        worker = roleRepository.findByName(RoleName.WORKER).orElseThrow();
    }

    @Test
    void savesAndFindsUserByEmailWithRoles() {
        userRepository.save(new User(organization, "Solo@Example.com", "hash", "Solo User", Set.of(manager, worker)));
        entityManager.flush();
        entityManager.clear();

        User found = userRepository.findByEmail("solo@example.com").orElseThrow();

        assertThat(found.getId()).isNotNull();
        assertThat(found.getEmail()).isEqualTo("solo@example.com");
        assertThat(found.getFullName()).isEqualTo("Solo User");
        assertThat(found.isActive()).isTrue();
        assertThat(found.hasRole(RoleName.MANAGER)).isTrue();
        assertThat(found.hasRole(RoleName.WORKER)).isTrue();
        assertThat(found.hasRole(RoleName.ADMINISTRATOR)).isFalse();
        assertThat(found.getOrganization().getId()).isEqualTo(Organization.DEFAULT_ID);
        assertThat(found.getCreatedAt()).isNotNull();
        assertThat(found.getUpdatedAt()).isNotNull();
    }

    @Test
    void existsByEmail() {
        userRepository.save(new User(organization, "worker@example.com", "hash", "Worker", Set.of(worker)));

        assertThat(userRepository.existsByEmail("worker@example.com")).isTrue();
        assertThat(userRepository.existsByEmail("nobody@example.com")).isFalse();
    }

    @Test
    void rejectsDuplicateEmailRegardlessOfCase() {
        userRepository.saveAndFlush(new User(organization, "worker@example.com", "hash", "Worker", Set.of(worker)));

        assertThatThrownBy(() -> userRepository.saveAndFlush(
                new User(organization, "WORKER@example.com", "hash", "Other", Set.of(worker))))
                .isInstanceOf(DataIntegrityViolationException.class);
    }

    @Test
    void findsUsersOfAnOrganizationPageByPage() {
        for (int i = 1; i <= 3; i++) {
            userRepository.save(new User(organization, "user" + i + "@example.com", "hash", "User " + i, Set.of(worker)));
        }

        Page<User> page = userRepository.findAllByOrganizationId(Organization.DEFAULT_ID, PageRequest.of(0, 2));

        assertThat(page.getTotalElements()).isEqualTo(3);
        assertThat(page.getContent()).hasSize(2);
    }

    @Test
    void deactivatedUserIsStoredAsInactive() {
        User user = userRepository.save(new User(organization, "gone@example.com", "hash", "Gone", Set.of(worker)));
        user.deactivate();
        entityManager.flush();
        entityManager.clear();

        assertThat(userRepository.findByEmail("gone@example.com").orElseThrow().isActive()).isFalse();
    }

}
