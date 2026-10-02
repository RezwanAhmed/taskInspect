package com.taskinspect.responses;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import com.taskinspect.TestcontainersConfiguration;
import com.taskinspect.requirements.Requirement;
import com.taskinspect.requirements.RequirementRepository;
import com.taskinspect.requirements.RequirementType;
import com.taskinspect.tasks.Task;
import com.taskinspect.tasks.TaskPriority;
import com.taskinspect.tasks.TaskRepository;
import com.taskinspect.users.OrganizationRepository;
import com.taskinspect.users.RoleName;
import com.taskinspect.users.RoleRepository;
import com.taskinspect.users.User;
import com.taskinspect.users.UserRepository;
import java.math.BigDecimal;
import java.time.Instant;
import java.util.List;
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

/** The worker's answers on PostgreSQL (task 9.2a). */
@DataJpaTest
@Import(TestcontainersConfiguration.class)
class ResponseRepositoryTests {

    @Autowired
    private ResponseRepository responseRepository;

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

    private User worker;
    private Task task;
    private Requirement count;
    private Requirement floor;

    @BeforeEach
    void setUp() {
        worker = userRepository.save(new User(organizationRepository.getDefault(), "worker@example.com", "hash",
                "Wendy", Set.of(roleRepository.findByName(RoleName.WORKER).orElseThrow())));
        task = taskRepository.save(new Task(worker, "Kitchen", null, TaskPriority.HIGH, Instant.now(), null));
        count = requirementRepository.save(new Requirement(task, "Temperature", null, RequirementType.NUMBER, true,
                0, "°C", null));
        floor = requirementRepository.save(new Requirement(task, "Floor", null, RequirementType.MULTIPLE_SELECTION,
                true, 1, null, List.of("Dry", "Clean", "Damaged")));
    }

    @Test
    void everyKindOfAnswerIsStoredAndReadBack() {
        List<UUID> selected = List.of(floor.getOptions().get(2).getId(), floor.getOptions().get(0).getId());
        save(count, null, null, new BigDecimal("4.5"), null, "Measured twice");
        save(floor, null, null, null, selected, null);
        entityManager.flush();
        entityManager.clear();

        Response temperature = responseRepository.findByRequirementId(count.getId()).orElseThrow();
        assertThat(temperature.getNumberValue()).isEqualByComparingTo("4.5");
        assertThat(temperature.getComment()).isEqualTo("Measured twice");
        assertThat(temperature.getRespondedBy().getId()).isEqualTo(worker.getId());
        assertThat(temperature.getCreatedAt()).isNotNull();
        assertThat(responseRepository.findByRequirementId(floor.getId()).orElseThrow().getSelectedOptionIds())
                .as("the order of the selection is kept")
                .containsExactlyElementsOf(selected);
        assertThat(responseRepository.findAllByTaskId(task.getId())).hasSize(2);
    }

    @Test
    void numbersKeepFourDecimals() {
        save(count, null, null, new BigDecimal("-12.3456"), null, null);
        entityManager.flush();
        entityManager.clear();

        assertThat(responseRepository.findByRequirementId(count.getId()).orElseThrow().getNumberValue())
                .isEqualByComparingTo("-12.3456");
    }

    @Test
    void aRequirementHasOnlyOneAnswer() {
        save(count, null, null, BigDecimal.ONE, null, null);
        entityManager.flush();

        assertThatThrownBy(() -> jdbcTemplate.update("""
                insert into task_responses (task_id, requirement_id, responded_by, number_value)
                values (?, ?, ?, 2)""", task.getId(), count.getId(), worker.getId()))
                .isInstanceOf(DataIntegrityViolationException.class)
                .hasMessageContaining("uk_task_responses_requirement");
    }

    @Test
    void deletingARequirementOrTheTaskDeletesItsAnswers() {
        save(count, null, null, BigDecimal.ONE, null, null);
        save(floor, null, null, null, List.of(floor.getOptions().get(0).getId()), null);
        entityManager.flush();

        jdbcTemplate.update("delete from task_requirements where id = ?", count.getId());
        assertThat(rows()).isEqualTo(1);

        jdbcTemplate.update("delete from tasks where id = ?", task.getId());
        assertThat(rows()).isZero();
    }

    private void save(Requirement requirement, Boolean booleanValue, String text, BigDecimal number,
            List<UUID> selected, String comment) {
        Response response = new Response(task, requirement);
        response.answer(worker, booleanValue, text, number, selected, comment);
        responseRepository.save(response);
    }

    private Integer rows() {
        return jdbcTemplate.queryForObject("select count(*) from task_responses", Integer.class);
    }

}
