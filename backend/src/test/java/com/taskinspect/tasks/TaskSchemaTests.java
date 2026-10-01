package com.taskinspect.tasks;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import com.taskinspect.TestcontainersConfiguration;
import com.taskinspect.users.Organization;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.data.jpa.test.autoconfigure.DataJpaTest;
import org.springframework.context.annotation.Import;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.jdbc.core.JdbcTemplate;

/**
 * Checks the tasks migration. The JPA mapping is checked by Hibernate
 * ({@code ddl-auto=validate}) when the test context starts.
 */
@DataJpaTest
@Import(TestcontainersConfiguration.class)
class TaskSchemaTests {

    private static final String INSERT_TASK = """
            insert into tasks (organization_id, title, priority, status, due_date, created_by, reviewer_id)
            values (?, ?, ?, ?, now() + interval '1 day', ?, ?)""";

    @Autowired
    private JdbcTemplate jdbcTemplate;

    private UUID managerId;

    @BeforeEach
    void setUp() {
        managerId = jdbcTemplate.queryForObject("""
                insert into users (organization_id, email, password_hash, full_name)
                values (?, 'manager@example.com', 'hash', 'Manager') returning id""", UUID.class,
                Organization.DEFAULT_ID);
    }

    @Test
    void newTaskStartsAsDraftWithVersionZero() {
        UUID id = jdbcTemplate.queryForObject("""
                insert into tasks (organization_id, title, priority, due_date, created_by, reviewer_id)
                values (?, 'Kitchen check', 'HIGH', now() + interval '1 day', ?, ?) returning id""", UUID.class,
                Organization.DEFAULT_ID, managerId, managerId);

        assertThat(jdbcTemplate.queryForObject("select status from tasks where id = ?", String.class, id))
                .isEqualTo("DRAFT");
        assertThat(jdbcTemplate.queryForObject("select version from tasks where id = ?", Long.class, id))
                .isZero();
    }

    @Test
    void unknownStatusIsRejected() {
        assertThatThrownBy(() -> insert("Task", "HIGH", "DONE"))
                .isInstanceOf(DataIntegrityViolationException.class);
    }

    @Test
    void unknownPriorityIsRejected() {
        assertThatThrownBy(() -> insert("Task", "CRITICAL", "DRAFT"))
                .isInstanceOf(DataIntegrityViolationException.class);
    }

    @Test
    void blankTitleIsRejected() {
        assertThatThrownBy(() -> insert("   ", "LOW", "DRAFT"))
                .isInstanceOf(DataIntegrityViolationException.class);
    }

    @Test
    void reviewerMustBeAnExistingUser() {
        assertThatThrownBy(() -> jdbcTemplate.update(INSERT_TASK, Organization.DEFAULT_ID, "Task", "LOW", "DRAFT",
                managerId, UUID.fromString("00000000-0000-0000-0000-00000000beef")))
                .isInstanceOf(DataIntegrityViolationException.class);
    }

    @Test
    void finalStatesAreApprovedAndCancelled() {
        assertThat(TaskStatus.APPROVED.isFinal()).isTrue();
        assertThat(TaskStatus.CANCELLED.isFinal()).isTrue();
        assertThat(TaskStatus.REJECTED.isFinal()).isFalse();
        assertThat(TaskStatus.CORRECTION_REQUESTED.isFinal()).isFalse();
    }

    private void insert(String title, String priority, String status) {
        jdbcTemplate.update(INSERT_TASK, Organization.DEFAULT_ID, title, priority, status, managerId, managerId);
    }

}
