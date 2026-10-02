package com.taskinspect.auth;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import com.taskinspect.TestcontainersConfiguration;
import com.taskinspect.users.OrganizationRepository;
import com.taskinspect.users.RoleName;
import com.taskinspect.users.RoleRepository;
import com.taskinspect.users.User;
import com.taskinspect.users.UserRepository;
import java.time.Instant;
import java.util.Set;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.data.jpa.test.autoconfigure.DataJpaTest;
import org.springframework.boot.jpa.test.autoconfigure.TestEntityManager;
import org.springframework.context.annotation.Import;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.jdbc.core.JdbcTemplate;

/** Refresh tokens on PostgreSQL (task 9.2b). */
@DataJpaTest
@Import(TestcontainersConfiguration.class)
class RefreshTokenRepositoryTests {

    private static final Instant NOW = Instant.parse("2026-10-02T10:00:00Z");
    private static final Instant LATER = NOW.plusSeconds(86_400);

    @Autowired
    private RefreshTokenRepository repository;

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
        // Written now, so the SQL statements of the tests see the users.
        entityManager.flush();
    }

    @Test
    void aTokenIsFoundByItsHash() {
        RefreshToken token = repository.save(new RefreshToken(wendy, "a".repeat(64), NOW, LATER));
        entityManager.flush();
        entityManager.clear();

        RefreshToken found = repository.findByTokenHash("a".repeat(64)).orElseThrow();
        assertThat(found.getId()).isEqualTo(token.getId());
        assertThat(found.getExpiresAt()).isEqualTo(LATER);
        assertThat(repository.findByTokenHash("b".repeat(64))).isEmpty();
    }

    @Test
    void revokingAllTouchesOnlyTheActiveTokensOfThatUser() {
        RefreshToken active = repository.save(new RefreshToken(wendy, "a".repeat(64), NOW, LATER));
        RefreshToken revoked = repository.save(new RefreshToken(wendy, "b".repeat(64), NOW, LATER));
        revoked.revoke(NOW.minusSeconds(60), null);
        RefreshToken other = repository.save(new RefreshToken(walter, "c".repeat(64), NOW, LATER));
        entityManager.flush();

        assertThat(repository.revokeAllForUser(wendy.getId(), NOW)).isEqualTo(1);
        entityManager.clear();

        assertThat(repository.findById(active.getId()).orElseThrow().getRevokedAt()).isEqualTo(NOW);
        assertThat(repository.findById(revoked.getId()).orElseThrow().getRevokedAt())
                .as("an already revoked token keeps its time").isEqualTo(NOW.minusSeconds(60));
        assertThat(repository.findById(other.getId()).orElseThrow().getRevokedAt()).isNull();
    }

    @Test
    void aRotatedTokenPointsToItsReplacement() {
        RefreshToken old = repository.save(new RefreshToken(wendy, "a".repeat(64), NOW, LATER));
        RefreshToken next = repository.save(new RefreshToken(wendy, "b".repeat(64), NOW, LATER));
        old.revoke(NOW, next.getId());
        entityManager.flush();
        entityManager.clear();

        assertThat(repository.findById(old.getId()).orElseThrow().getReplacedBy()).isEqualTo(next.getId());
    }

    @Test
    void databaseRejectsAReplacementThatDoesNotExist() {
        RefreshToken old = repository.save(new RefreshToken(wendy, "a".repeat(64), NOW, LATER));
        entityManager.flush();

        assertThatThrownBy(() -> jdbcTemplate.update("update refresh_tokens set replaced_by = ? where id = ?",
                UUID.randomUUID(), old.getId()))
                .isInstanceOf(DataIntegrityViolationException.class)
                .hasMessageContaining("fk_refresh_tokens_replaced_by");
    }

    @Test
    void aHashIsStoredOnlyOnce() {
        repository.save(new RefreshToken(wendy, "a".repeat(64), NOW, LATER));
        entityManager.flush();

        assertThatThrownBy(() -> jdbcTemplate.update("""
                insert into refresh_tokens (user_id, token_hash, expires_at) values (?, ?, now())""",
                walter.getId(), "a".repeat(64)))
                .isInstanceOf(DataIntegrityViolationException.class)
                .hasMessageContaining("uk_refresh_tokens_token_hash");
    }

    @Test
    void deletingAUserDeletesTheirTokens() {
        repository.save(new RefreshToken(wendy, "a".repeat(64), NOW, LATER));
        entityManager.flush();

        jdbcTemplate.update("delete from users where id = ?", wendy.getId());

        assertThat(jdbcTemplate.queryForObject("select count(*) from refresh_tokens", Integer.class)).isZero();
    }

    private User save(String email) {
        return userRepository.save(new User(organizationRepository.getDefault(), email, "hash", "Worker",
                Set.of(roleRepository.findByName(RoleName.WORKER).orElseThrow())));
    }

}
