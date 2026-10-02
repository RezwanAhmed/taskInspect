package com.taskinspect.notifications;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import com.taskinspect.TestcontainersConfiguration;
import com.taskinspect.users.OrganizationRepository;
import com.taskinspect.users.RoleName;
import com.taskinspect.users.RoleRepository;
import com.taskinspect.users.User;
import com.taskinspect.users.UserRepository;
import java.util.List;
import java.util.Set;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.data.jpa.test.autoconfigure.DataJpaTest;
import org.springframework.boot.jpa.test.autoconfigure.TestEntityManager;
import org.springframework.context.annotation.Import;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.jdbc.core.JdbcTemplate;

/** Device tokens on PostgreSQL (task 9.2b). */
@DataJpaTest
@Import(TestcontainersConfiguration.class)
class DeviceTokenRepositoryTests {

    @Autowired
    private DeviceTokenRepository repository;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private RoleRepository roleRepository;

    @Autowired
    private OrganizationRepository organizationRepository;

    @Autowired
    private TestEntityManager entityManager;

    @Autowired
    private JdbcTemplate jdbcTemplate;

    private User wendy;
    private User walter;

    @BeforeEach
    void setUp() {
        wendy = save("wendy@example.com");
        walter = save("walter@example.com");
        // Written now, so the native and SQL statements of the tests see the users.
        entityManager.flush();
    }

    @Test
    void registeringATokenAgainMovesItToTheNewUserInOneRow() {
        repository.register(wendy.getId(), "shared-phone", "ANDROID");
        repository.register(walter.getId(), "shared-phone", "IOS");
        entityManager.clear();

        DeviceToken token = repository.findByToken("shared-phone").orElseThrow();
        assertThat(token.getUserId()).isEqualTo(walter.getId());
        assertThat(token.getPlatform()).isEqualTo(DevicePlatform.IOS);
        assertThat(repository.count()).isEqualTo(1);
    }

    @Test
    void tokensAreFoundForTheGivenUsersOnly() {
        repository.register(wendy.getId(), "phone", "ANDROID");
        repository.register(wendy.getId(), "tablet", "IOS");
        repository.register(walter.getId(), "other", "ANDROID");

        assertThat(repository.findTokensOfUsers(List.of(wendy.getId()))).containsExactlyInAnyOrder("phone", "tablet");
        assertThat(repository.findTokensOfUsers(List.of(wendy.getId(), walter.getId()))).hasSize(3);
    }

    @Test
    void aUserDeletesOnlyTheirOwnTokenAndInvalidTokensAreDeletedTogether() {
        repository.register(wendy.getId(), "phone", "ANDROID");
        repository.register(wendy.getId(), "tablet", "IOS");
        repository.register(walter.getId(), "other", "ANDROID");

        assertThat(repository.deleteForUser("other", wendy.getId())).isZero();
        assertThat(repository.deleteForUser("phone", wendy.getId())).isEqualTo(1);
        assertThat(repository.deleteTokens(List.of("tablet", "other", "unknown"))).isEqualTo(2);
        assertThat(repository.count()).isZero();
    }

    @Test
    void databaseRejectsUnknownPlatforms() {
        assertThatThrownBy(() -> repository.register(wendy.getId(), "phone", "WINDOWS"))
                .isInstanceOf(DataIntegrityViolationException.class)
                .hasMessageContaining("ck_device_tokens_platform");
    }

    @Test
    void deletingAUserDeletesTheirTokens() {
        repository.register(wendy.getId(), "phone", "ANDROID");

        jdbcTemplate.update("delete from users where id = ?", wendy.getId());

        assertThat(jdbcTemplate.queryForObject("select count(*) from device_tokens", Integer.class)).isZero();
    }

    private User save(String email) {
        return userRepository.save(new User(organizationRepository.getDefault(), email, "hash", "Worker",
                Set.of(roleRepository.findByName(RoleName.WORKER).orElseThrow())));
    }

}
