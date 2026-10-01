package com.taskinspect.tasks;

import static com.taskinspect.tasks.TaskSpecifications.dueBefore;
import static com.taskinspect.tasks.TaskSpecifications.dueFrom;
import static com.taskinspect.tasks.TaskSpecifications.hasPriority;
import static com.taskinspect.tasks.TaskSpecifications.hasStatus;
import static com.taskinspect.tasks.TaskSpecifications.inOrganization;
import static org.assertj.core.api.Assertions.assertThat;

import com.taskinspect.TestcontainersConfiguration;
import com.taskinspect.users.Organization;
import com.taskinspect.users.OrganizationRepository;
import com.taskinspect.users.RoleName;
import com.taskinspect.users.RoleRepository;
import com.taskinspect.users.User;
import com.taskinspect.users.UserRepository;
import java.time.Duration;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.Set;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.data.jpa.test.autoconfigure.DataJpaTest;
import org.springframework.boot.jpa.test.autoconfigure.TestEntityManager;
import org.springframework.context.annotation.Import;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Sort;
import org.springframework.data.jpa.domain.Specification;

@DataJpaTest
@Import(TestcontainersConfiguration.class)
class TaskRepositoryTests {

    private static final Instant NOW = Instant.now().truncatedTo(ChronoUnit.SECONDS);

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

    private User manager;
    private User reviewer;

    @BeforeEach
    void setUp() {
        Organization organization = organizationRepository.getDefault();
        manager = userRepository.save(new User(organization, "manager@example.com", "hash", "Mia Manager",
                Set.of(roleRepository.findByName(RoleName.MANAGER).orElseThrow())));
        reviewer = userRepository.save(new User(organization, "reviewer@example.com", "hash", "Rita Reviewer",
                Set.of(roleRepository.findByName(RoleName.MANAGER).orElseThrow())));
    }

    @Test
    void savesAndLoadsATask() {
        Task saved = taskRepository.save(new Task(manager, "Daily kitchen check", "Check the fridge",
                TaskPriority.HIGH, NOW.plus(Duration.ofDays(1)), reviewer));
        entityManager.flush();
        entityManager.clear();

        Task found = taskRepository.findByIdAndOrganizationId(saved.getId(), Organization.DEFAULT_ID).orElseThrow();

        assertThat(found.getTitle()).isEqualTo("Daily kitchen check");
        assertThat(found.getDescription()).isEqualTo("Check the fridge");
        assertThat(found.getPriority()).isEqualTo(TaskPriority.HIGH);
        assertThat(found.getStatus()).isEqualTo(TaskStatus.DRAFT);
        assertThat(found.getDueDate()).isEqualTo(NOW.plus(Duration.ofDays(1)));
        assertThat(found.getCreatedBy().getId()).isEqualTo(manager.getId());
        assertThat(found.getReviewer().getId()).isEqualTo(reviewer.getId());
        assertThat(found.getCreatedAt()).isNotNull();
        assertThat(found.getVersion()).isZero();
    }

    @Test
    void reviewerDefaultsToTheCreator() {
        Task task = taskRepository.save(new Task(manager, "Solo checklist", null, TaskPriority.LOW,
                NOW.plus(Duration.ofDays(1)), null));

        assertThat(task.getReviewer().getId()).isEqualTo(manager.getId());
    }

    @Test
    void taskOfAnotherOrganizationIsNotFound() {
        Task task = taskRepository.save(new Task(manager, "Task", null, TaskPriority.LOW, NOW, null));

        assertThat(taskRepository.findByIdAndOrganizationId(task.getId(), UUID.randomUUID())).isEmpty();
    }

    @Test
    void versionIncreasesOnEveryUpdate() {
        Task task = taskRepository.saveAndFlush(new Task(manager, "Task", null, TaskPriority.LOW, NOW, null));

        task.changeStatus(TaskStatus.ASSIGNED);
        taskRepository.saveAndFlush(task);

        assertThat(task.getVersion()).isEqualTo(1);
    }

    @Test
    void filtersByStatusPriorityAndDueDateWithPaging() {
        Task overdueHigh = save("Overdue high", TaskPriority.HIGH, NOW.minus(Duration.ofDays(1)));
        save("Tomorrow high", TaskPriority.HIGH, NOW.plus(Duration.ofDays(1)));
        save("Tomorrow low", TaskPriority.LOW, NOW.plus(Duration.ofDays(1)));
        overdueHigh.changeStatus(TaskStatus.ASSIGNED);
        entityManager.flush();

        Page<Task> high = taskRepository.findAll(
                Specification.allOf(inOrganization(Organization.DEFAULT_ID), hasPriority(TaskPriority.HIGH)),
                PageRequest.of(0, 1, Sort.by("dueDate")));
        Page<Task> assigned = taskRepository.findAll(
                Specification.allOf(inOrganization(Organization.DEFAULT_ID), hasStatus(TaskStatus.ASSIGNED)),
                PageRequest.of(0, 10));
        Page<Task> dueTomorrow = taskRepository.findAll(
                Specification.allOf(inOrganization(Organization.DEFAULT_ID), dueFrom(NOW),
                        dueBefore(NOW.plus(Duration.ofDays(2))), hasStatus(null)),
                PageRequest.of(0, 10));

        assertThat(high.getTotalElements()).isEqualTo(2);
        assertThat(high.getContent()).extracting(Task::getTitle).containsExactly("Overdue high");
        assertThat(assigned.getContent()).extracting(Task::getTitle).containsExactly("Overdue high");
        assertThat(dueTomorrow.getContent()).extracting(Task::getTitle)
                .containsExactlyInAnyOrder("Tomorrow high", "Tomorrow low");
    }

    private Task save(String title, TaskPriority priority, Instant dueDate) {
        return taskRepository.save(new Task(manager, title, null, priority, dueDate, null));
    }

}
