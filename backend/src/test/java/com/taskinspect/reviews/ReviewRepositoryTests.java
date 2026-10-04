package com.taskinspect.reviews;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.assertj.core.api.Assertions.tuple;

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

/** Reviews and their marked requirements on PostgreSQL (task 9.2a). */
@DataJpaTest
@Import(TestcontainersConfiguration.class)
class ReviewRepositoryTests {

    @Autowired
    private ReviewRepository reviewRepository;

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

    private User manager;
    private Task task;
    private Requirement photo;
    private Requirement question;

    @BeforeEach
    void setUp() {
        manager = userRepository.save(new User(organizationRepository.getDefault(), "manager@example.com", "hash",
                "Mia", Set.of(roleRepository.findByName(RoleName.MANAGER).orElseThrow())));
        task = taskRepository.save(new Task(manager, "Kitchen", null, TaskPriority.HIGH, Instant.now(), null));
        photo = requirementRepository.save(new Requirement(task, "Photo", null, RequirementType.PHOTO, true, 0,
                null, null));
        question = requirementRepository.save(new Requirement(task, "Clean?", null, RequirementType.YES_NO, true, 1,
                null, null));
        // Written now, so the SQL inserts of the tests see the task.
        entityManager.flush();
    }

    @Test
    void aCorrectionRequestIsStoredWithItsMarkedRequirements() {
        Review saved = reviewRepository.save(new Review(task, manager, ReviewResult.CORRECTION_REQUESTED, "Redo",
                List.of(new MarkedRequirement(photo.getId(), "Too dark"),
                        new MarkedRequirement(question.getId(), "Check again"))));
        entityManager.flush();
        entityManager.clear();

        Review review = reviewRepository.findById(saved.getId()).orElseThrow();
        assertThat(review.getResult()).isEqualTo(ReviewResult.CORRECTION_REQUESTED);
        assertThat(review.getReason()).isEqualTo("Redo");
        assertThat(review.getMarkedRequirements())
                .extracting(MarkedRequirement::getRequirementId, MarkedRequirement::getComment)
                .containsExactlyInAnyOrder(
                        tuple(photo.getId(), "Too dark"),
                        tuple(question.getId(), "Check again"));
        assertThat(reviewRepository.existsByTaskId(task.getId())).isTrue();
    }

    @Test
    void reviewsComeOldestFirstAndTheLatestIsFoundWithTheIdBreakingATie() {
        UUID first = insert("00000000-0000-0000-0000-000000000003", "REJECTED", "2026-10-02T10:00:00Z");
        UUID tieLow = insert("00000000-0000-0000-0000-000000000001", "CORRECTION_REQUESTED", "2026-10-02T11:00:00Z");
        UUID tieHigh = insert("00000000-0000-0000-0000-000000000002", "APPROVED", "2026-10-02T11:00:00Z");

        assertThat(reviewRepository.findAllByTaskIdOrderByCreatedAtAscIdAsc(task.getId()))
                .extracting(Review::getId)
                .containsExactly(first, tieLow, tieHigh);
        assertThat(reviewRepository.findFirstByTaskIdOrderByCreatedAtDescIdDesc(task.getId()).orElseThrow().getId())
                .isEqualTo(tieHigh);
    }

    @Test
    void aTaskWithoutReviewsHasNone() {
        assertThat(reviewRepository.existsByTaskId(task.getId())).isFalse();
        assertThat(reviewRepository.findFirstByTaskIdOrderByCreatedAtDescIdDesc(task.getId())).isEmpty();
    }

    @Test
    void databaseRejectsUnknownResults() {
        assertThatThrownBy(() -> insert(UUID.randomUUID().toString(), "PENDING", "2026-10-02T10:00:00Z"))
                .isInstanceOf(DataIntegrityViolationException.class)
                .hasMessageContaining("ck_task_reviews_result");
    }

    @Test
    void deletingARequirementRemovesItsMarkAndDeletingTheTaskRemovesTheReviews() {
        reviewRepository.save(new Review(task, manager, ReviewResult.CORRECTION_REQUESTED, null,
                List.of(new MarkedRequirement(photo.getId(), "Too dark"),
                        new MarkedRequirement(question.getId(), "Check again"))));
        entityManager.flush();

        jdbcTemplate.update("delete from task_requirements where id = ?", photo.getId());
        assertThat(count("task_review_items")).isEqualTo(1);

        jdbcTemplate.update("delete from tasks where id = ?", task.getId());
        assertThat(count("task_reviews")).isZero();
        assertThat(count("task_review_items")).isZero();
    }

    private UUID insert(String id, String result, String createdAt) {
        jdbcTemplate.update("""
                insert into task_reviews (id, task_id, reviewer_id, result, created_at)
                values (?::uuid, ?, ?, ?, ?::timestamptz)""", id, task.getId(), manager.getId(), result, createdAt);
        return UUID.fromString(id);
    }

    private Integer count(String table) {
        return jdbcTemplate.queryForObject("select count(*) from " + table, Integer.class);
    }

}
