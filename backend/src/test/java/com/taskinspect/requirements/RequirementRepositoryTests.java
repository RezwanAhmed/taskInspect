package com.taskinspect.requirements;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import com.taskinspect.TestcontainersConfiguration;
import com.taskinspect.tasks.Task;
import com.taskinspect.tasks.TaskPriority;
import com.taskinspect.tasks.TaskRepository;
import com.taskinspect.users.OrganizationRepository;
import com.taskinspect.users.RoleName;
import com.taskinspect.users.RoleRepository;
import com.taskinspect.users.User;
import com.taskinspect.users.UserRepository;
import java.time.Instant;
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

@DataJpaTest
@Import(TestcontainersConfiguration.class)
class RequirementRepositoryTests {

    @Autowired
    private RequirementRepository requirementRepository;

    @Autowired
    private TaskRepository taskRepository;

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

    private Task task;

    @BeforeEach
    void setUp() {
        User manager = userRepository.save(new User(organizationRepository.getDefault(), "manager@example.com",
                "hash", "Mia", Set.of(roleRepository.findByName(RoleName.MANAGER).orElseThrow())));
        task = taskRepository.save(new Task(manager, "Kitchen check", null, TaskPriority.HIGH, Instant.now(), null));
    }

    @Test
    void savesRequirementsInOrderWithUnitAndOptions() {
        requirementRepository.save(new Requirement(task, "Record refrigerator temperature", null,
                RequirementType.NUMBER, true, 1, "°C", null));
        requirementRepository.save(new Requirement(task, "Is the fire extinguisher available?", null,
                RequirementType.YES_NO, true, 0, null, null));
        requirementRepository.save(new Requirement(task, "Floor condition", "Pick one", RequirementType.DROPDOWN,
                false, 2, null, List.of("Clean", "Needs cleaning", "Damaged")));
        entityManager.flush();
        entityManager.clear();

        List<Requirement> requirements = requirementRepository.findAllByTaskIdOrderByPosition(task.getId());

        assertThat(requirements).extracting(Requirement::getType)
                .containsExactly(RequirementType.YES_NO, RequirementType.NUMBER, RequirementType.DROPDOWN);
        assertThat(requirements.get(1).getUnit()).isEqualTo("°C");
        assertThat(requirements.get(2).isRequired()).isFalse();
        assertThat(requirements.get(2).getOptions()).extracting(RequirementOption::getLabel)
                .containsExactly("Clean", "Needs cleaning", "Damaged");
        assertThat(requirementRepository.countByTaskId(task.getId())).isEqualTo(3);
    }

    @Test
    void unitAndOptionsAreDroppedForTypesThatDontUseThem() {
        Requirement requirement = new Requirement(task, "Take a photo of the kitchen", null, RequirementType.PHOTO,
                true, 0, "kg", List.of("ignored"));

        assertThat(requirement.getUnit()).isNull();
        assertThat(requirement.getOptions()).isEmpty();
    }

    @Test
    void changingTheTypeReplacesTheOptions() {
        Requirement requirement = requirementRepository.save(new Requirement(task, "Floor", null,
                RequirementType.MULTIPLE_SELECTION, true, 0, null, List.of("A", "B")));
        entityManager.flush();

        requirement.update("Floor ok?", null, RequirementType.YES_NO, true, null, null);
        entityManager.flush();

        assertThat(jdbcTemplate.queryForObject("select count(*) from requirement_options", Integer.class)).isZero();
    }

    @Test
    void deletingATaskDeletesItsRequirementsAndOptions() {
        requirementRepository.save(new Requirement(task, "Floor", null, RequirementType.DROPDOWN, true, 0, null,
                List.of("A", "B")));
        entityManager.flush();

        jdbcTemplate.update("delete from tasks where id = ?", task.getId());

        assertThat(jdbcTemplate.queryForObject("select count(*) from task_requirements", Integer.class)).isZero();
        assertThat(jdbcTemplate.queryForObject("select count(*) from requirement_options", Integer.class)).isZero();
    }

    @Test
    void databaseRejectsUnknownTypes() {
        assertThatThrownBy(() -> jdbcTemplate.update("""
                insert into task_requirements (task_id, title, type, position) values (?, 'x', 'VIDEO', 0)""",
                task.getId())).isInstanceOf(DataIntegrityViolationException.class);
    }

    @Test
    void databaseRejectsUnitsOnNonNumbers() {
        assertThatThrownBy(() -> jdbcTemplate.update("""
                insert into task_requirements (task_id, title, type, position, unit) values (?, 'x', 'TEXT', 0, 'kg')""",
                task.getId())).isInstanceOf(DataIntegrityViolationException.class);
    }

}
