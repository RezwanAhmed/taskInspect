package com.taskinspect.users;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import com.taskinspect.TestcontainersConfiguration;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.data.jpa.test.autoconfigure.DataJpaTest;
import org.springframework.context.annotation.Import;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.jdbc.core.JdbcTemplate;

/**
 * Checks the users migration. The JPA mapping itself is checked by Hibernate
 * ({@code ddl-auto=validate}) when the test context starts.
 */
@DataJpaTest
@Import(TestcontainersConfiguration.class)
class UserSchemaTests {

    private static final String INSERT_USER =
            "insert into users (organization_id, email, password_hash, full_name) values (?, ?, 'hash', 'Test User')";

    @Autowired
    private JdbcTemplate jdbcTemplate;

    @Test
    void defaultOrganizationExists() {
        String name = jdbcTemplate.queryForObject(
                "select name from organizations where id = ?", String.class, Organization.DEFAULT_ID);

        assertThat(name).isEqualTo("Default organization");
    }

    @Test
    void emailMustBeUnique() {
        jdbcTemplate.update(INSERT_USER, Organization.DEFAULT_ID, "worker@example.com");

        assertThatThrownBy(() -> jdbcTemplate.update(INSERT_USER, Organization.DEFAULT_ID, "worker@example.com"))
                .isInstanceOf(DataIntegrityViolationException.class);
    }

    @Test
    void emailMustBeLowerCase() {
        assertThatThrownBy(() -> jdbcTemplate.update(INSERT_USER, Organization.DEFAULT_ID, "Worker@Example.com"))
                .isInstanceOf(DataIntegrityViolationException.class);
    }

    @Test
    void userMustBelongToAnExistingOrganization() {
        assertThatThrownBy(() -> jdbcTemplate.update(
                INSERT_USER, UUID.fromString("00000000-0000-0000-0000-00000000ffff"), "a@example.com"))
                .isInstanceOf(DataIntegrityViolationException.class);
    }

    @Test
    void normalizeEmailTrimsAndLowerCases() {
        assertThat(User.normalizeEmail("  Manager@Example.COM ")).isEqualTo("manager@example.com");
    }

}
