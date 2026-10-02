package com.taskinspect.evidence;

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
import java.time.Instant;
import java.util.Set;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.CsvSource;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.data.jpa.test.autoconfigure.DataJpaTest;
import org.springframework.boot.jpa.test.autoconfigure.TestEntityManager;
import org.springframework.context.annotation.Import;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.jdbc.core.JdbcTemplate;

/** Evidence files on PostgreSQL (task 9.2a). */
@DataJpaTest
@Import(TestcontainersConfiguration.class)
class EvidenceRepositoryTests {

    @Autowired
    private EvidenceRepository evidenceRepository;

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
    private Requirement photo;

    @BeforeEach
    void setUp() {
        worker = userRepository.save(new User(organizationRepository.getDefault(), "worker@example.com", "hash",
                "Wendy", Set.of(roleRepository.findByName(RoleName.WORKER).orElseThrow())));
        task = taskRepository.save(new Task(worker, "Kitchen", null, TaskPriority.HIGH, Instant.now(), null));
        photo = requirementRepository.save(new Requirement(task, "Photo of the fridge", null, RequirementType.PHOTO,
                true, 0, null, null));
        // Written now, so the SQL inserts of the tests see the task.
        entityManager.flush();
    }

    @Test
    void aNewFileWaitsForItsUploadAndIsMarkedUploaded() {
        Evidence evidence = evidenceRepository.save(evidence("tasks/a/1.jpg", "image/jpeg", 2048));
        entityManager.flush();
        entityManager.clear();

        Evidence stored = evidenceRepository.findById(evidence.getId()).orElseThrow();
        assertThat(stored.getStatus()).isEqualTo(EvidenceStatus.PENDING);
        assertThat(stored.getSizeBytes()).isEqualTo(2048);

        stored.markUploaded(Instant.parse("2026-10-02T10:00:00Z"));
        entityManager.flush();
        assertThat(jdbcTemplate.queryForObject("select status from evidence where id = ?", String.class,
                evidence.getId())).isEqualTo("UPLOADED");
        assertThat(jdbcTemplate.queryForObject("select uploaded_at is not null from evidence where id = ?",
                Boolean.class, evidence.getId())).isTrue();
    }

    @Test
    void filesOfATaskComeOldestFirst() {
        UUID newer = insert("tasks/a/2.png", "2026-10-02T10:05:00Z");
        UUID older = insert("tasks/a/1.png", "2026-10-02T10:00:00Z");

        assertThat(evidenceRepository.findAllByTaskIdOrderByCreatedAtAsc(task.getId()))
                .extracting(Evidence::getId)
                .containsExactly(older, newer);
    }

    /** One case per run: a refused insert ends PostgreSQL's transaction. */
    @ParameterizedTest
    @CsvSource({
            "tasks/a/2.gif, image/gif, 10, PENDING, ck_evidence_content_type",
            "tasks/a/3.png, image/png, 0, PENDING, ck_evidence_size",
            "tasks/a/4.png, image/png, 10, DELETED, ck_evidence_status",
            "tasks/a/1.png, image/png, 10, PENDING, uk_evidence_storage_key"})
    void databaseRejectsOtherFileTypesEmptyFilesUnknownStatusesAndReusedKeys(String storageKey, String contentType,
            long size, String status, String constraint) {
        insert("tasks/a/1.png", "2026-10-02T10:00:00Z");

        assertThatThrownBy(() -> jdbcTemplate.update("""
                insert into evidence (id, task_id, requirement_id, uploaded_by, file_name, content_type, size_bytes,
                                      storage_key, status)
                values (?, ?, ?, ?, 'file', ?, ?, ?, ?)""",
                UUID.randomUUID(), task.getId(), photo.getId(), worker.getId(), contentType, size, storageKey, status))
                .isInstanceOf(DataIntegrityViolationException.class)
                .hasMessageContaining(constraint);
    }

    @Test
    void deletingTheRequirementDeletesItsFiles() {
        insert("tasks/a/1.png", "2026-10-02T10:00:00Z");

        jdbcTemplate.update("delete from task_requirements where id = ?", photo.getId());

        assertThat(jdbcTemplate.queryForObject("select count(*) from evidence", Integer.class)).isZero();
    }

    @Test
    void deletingTheTaskDeletesItsFiles() {
        insert("tasks/a/1.png", "2026-10-02T10:00:00Z");

        jdbcTemplate.update("delete from tasks where id = ?", task.getId());

        assertThat(jdbcTemplate.queryForObject("select count(*) from evidence", Integer.class)).isZero();
    }

    private Evidence evidence(String storageKey, String contentType, long size) {
        return new Evidence(UUID.randomUUID(), task, photo, worker, "fridge.jpg", contentType, size, storageKey);
    }

    private UUID insert(String storageKey, String createdAt) {
        UUID id = UUID.randomUUID();
        jdbcTemplate.update("""
                insert into evidence (id, task_id, requirement_id, uploaded_by, file_name, content_type, size_bytes,
                                      storage_key, created_at)
                values (?, ?, ?, ?, 'photo.png', 'image/png', 10, ?, ?::timestamptz)""",
                id, task.getId(), photo.getId(), worker.getId(), storageKey, createdAt);
        return id;
    }

}
