package com.taskinspect.sync;

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

@DataJpaTest
@Import(TestcontainersConfiguration.class)
class SyncRecordRepositoryTests {

    @Autowired
    private SyncRecordRepository syncRecordRepository;

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

    @BeforeEach
    void setUp() {
        User manager = userRepository.save(new User(organizationRepository.getDefault(), "manager@example.com",
                "hash", "Mia", Set.of(roleRepository.findByName(RoleName.MANAGER).orElseThrow())));
        worker = userRepository.save(new User(organizationRepository.getDefault(), "worker@example.com",
                "hash", "Wendy", Set.of(roleRepository.findByName(RoleName.WORKER).orElseThrow())));
        task = taskRepository.save(new Task(manager, "Kitchen check", null, TaskPriority.HIGH, Instant.now(), null));
    }

    @Test
    void storesAnAppliedOperationUnderTheDevicesId() {
        UUID operationId = UUID.randomUUID();
        UUID requirementId = UUID.randomUUID();
        syncRecordRepository.save(new SyncRecord(operationId, worker.getId(), task.getId(), "TaskResponse",
                requirementId, "UPDATE"));
        entityManager.flush();
        entityManager.clear();

        SyncRecord record = syncRecordRepository.findById(operationId).orElseThrow();

        assertThat(record.getUserId()).isEqualTo(worker.getId());
        assertThat(record.getTaskId()).isEqualTo(task.getId());
        assertThat(record.getEntityType()).isEqualTo("TaskResponse");
        assertThat(record.getEntityId()).isEqualTo(requirementId);
        assertThat(record.getOperation()).isEqualTo("UPDATE");
        assertThat(record.getAppliedAt()).isNotNull();
        assertThat(syncRecordRepository.existsById(UUID.randomUUID())).isFalse();
    }

    @Test
    void recordsAreDeletedWithTheirTask() {
        syncRecordRepository.save(new SyncRecord(UUID.randomUUID(), worker.getId(), task.getId(), "Task",
                task.getId(), "START"));
        entityManager.flush();

        jdbcTemplate.update("delete from tasks where id = ?", task.getId());

        assertThat(jdbcTemplate.queryForObject("select count(*) from sync_records", Integer.class)).isZero();
    }

    @Test
    void databaseRejectsUnknownEntityTypes() {
        assertThatThrownBy(() -> jdbcTemplate.update("""
                insert into sync_records (id, user_id, task_id, entity_type, entity_id, operation)
                values (?, ?, ?, 'Video', ?, 'CREATE')""", UUID.randomUUID(), worker.getId(), task.getId(),
                UUID.randomUUID())).isInstanceOf(DataIntegrityViolationException.class);
    }

    @Test
    void databaseRejectsUnknownOperations() {
        assertThatThrownBy(() -> jdbcTemplate.update("""
                insert into sync_records (id, user_id, task_id, entity_type, entity_id, operation)
                values (?, ?, ?, 'Task', ?, 'APPROVE')""", UUID.randomUUID(), worker.getId(), task.getId(),
                task.getId())).isInstanceOf(DataIntegrityViolationException.class);
    }

}
