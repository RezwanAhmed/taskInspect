package com.taskinspect.tasks;

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
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.context.annotation.Import;
import org.springframework.orm.ObjectOptimisticLockingFailureException;
import org.springframework.transaction.support.TransactionTemplate;

/** Two separate transactions change the same task; the stale one must fail. */
@Import(TestcontainersConfiguration.class)
@SpringBootTest
class TaskOptimisticLockingTests {

    @Autowired
    private TaskRepository taskRepository;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private RoleRepository roleRepository;

    @Autowired
    private OrganizationRepository organizationRepository;

    @Autowired
    private TransactionTemplate transactionTemplate;

    @AfterEach
    void tearDown() {
        taskRepository.deleteAll();
        userRepository.deleteAll();
    }

    @Test
    void staleUpdateIsRejected() {
        User manager = userRepository.save(new User(organizationRepository.getDefault(), "manager@example.com",
                "hash", "Mia", Set.of(roleRepository.findByName(RoleName.MANAGER).orElseThrow())));
        UUID id = taskRepository.save(new Task(manager, "Task", null, TaskPriority.LOW, Instant.now(), null)).getId();

        Task stale = taskRepository.findById(id).orElseThrow();
        transactionTemplate.executeWithoutResult(status -> {
            Task fresh = taskRepository.findById(id).orElseThrow();
            fresh.changeStatus(TaskStatus.ASSIGNED);
        });

        stale.changeStatus(TaskStatus.CANCELLED);
        assertThatThrownBy(() -> taskRepository.saveAndFlush(stale))
                .isInstanceOf(ObjectOptimisticLockingFailureException.class);
    }

}
