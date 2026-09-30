package com.taskinspect.tasks;

import com.taskinspect.common.security.CurrentUser;
import com.taskinspect.tasks.dto.CreateTaskRequest;
import com.taskinspect.users.RoleName;
import com.taskinspect.users.User;
import com.taskinspect.users.UserService;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class TaskService {

    static final String INVALID_REVIEWER = "INVALID_REVIEWER";

    private final TaskRepository taskRepository;
    private final UserService userService;

    public TaskService(TaskRepository taskRepository, UserService userService) {
        this.taskRepository = taskRepository;
        this.userService = userService;
    }

    /**
     * Creates a draft task in the creator's organization. The reviewer must be
     * an active manager of the same organization; by default it is the creator.
     */
    @Transactional
    public Task create(CurrentUser caller, CreateTaskRequest request) {
        User creator = userService.requireCaller(caller);
        User reviewer = request.reviewerId() == null ? null
                : userService.requireActiveWithRole(request.reviewerId(), creator.getOrganization().getId(),
                        RoleName.MANAGER, INVALID_REVIEWER, "The reviewer must be an active manager");
        String description = request.description() == null || request.description().isBlank()
                ? null : request.description().trim();
        return taskRepository.save(new Task(creator, request.title().trim(), description, request.priority(),
                request.dueDate(), reviewer));
    }

}
