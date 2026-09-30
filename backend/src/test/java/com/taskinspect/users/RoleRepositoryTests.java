package com.taskinspect.users;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import com.taskinspect.TestcontainersConfiguration;
import java.util.List;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.data.jpa.test.autoconfigure.DataJpaTest;
import org.springframework.context.annotation.Import;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.jdbc.core.JdbcTemplate;

@DataJpaTest
@Import(TestcontainersConfiguration.class)
class RoleRepositoryTests {

    @Autowired
    private RoleRepository roleRepository;

    @Autowired
    private JdbcTemplate jdbcTemplate;

    @Test
    void migrationCreatesTheThreeRoles() {
        List<RoleName> names = roleRepository.findAll().stream().map(Role::getName).toList();

        assertThat(names).containsExactlyInAnyOrder(RoleName.ADMINISTRATOR, RoleName.MANAGER, RoleName.WORKER);
    }

    @Test
    void findsRoleByName() {
        Role manager = roleRepository.findByName(RoleName.MANAGER).orElseThrow();

        assertThat(manager.getId()).isNotNull();
        assertThat(manager.getDescription()).isNotBlank();
        assertThat(manager.getCreatedAt()).isNotNull();
    }

    @Test
    void databaseRejectsUnknownRoleNames() {
        assertThatThrownBy(() -> jdbcTemplate.update(
                "insert into roles (name, description) values ('SUPERUSER', 'not allowed')"))
                .isInstanceOf(DataIntegrityViolationException.class);
    }

    @Test
    void databaseRejectsDuplicateRoleNames() {
        assertThatThrownBy(() -> jdbcTemplate.update(
                "insert into roles (name, description) values ('WORKER', 'duplicate')"))
                .isInstanceOf(DataIntegrityViolationException.class);
    }

}
