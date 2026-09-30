package com.taskinspect;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.jayway.jsonpath.JsonPath;
import com.taskinspect.audit.AuditAction;
import com.taskinspect.audit.AuditLog;
import com.taskinspect.audit.AuditLogRepository;
import com.taskinspect.tasks.TaskStatus;
import com.taskinspect.tasks.TaskStatusChange;
import com.taskinspect.tasks.TaskStatusChangeRepository;
import java.util.List;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.context.annotation.Import;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.ResultActions;
import org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder;

/**
 * The task flow of Phase 3 end to end, only through the HTTP API with real
 * logins: the first administrator (created on startup) creates a manager
 * and a worker; the manager creates a task with requirements and assigns
 * it; the worker finds it, starts it and answers every requirement; the
 * manager reads the answers. Review and submission follow in Phase 7.
 */
@Import(TestcontainersConfiguration.class)
@SpringBootTest(properties = {
        "ADMIN_EMAIL=admin@flow.test",
        "ADMIN_PASSWORD=flow-admin-password",
        "ADMIN_FULL_NAME=Flow Admin"
})
@AutoConfigureMockMvc
class TaskFlowIntegrationTests {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private TaskStatusChangeRepository historyRepository;

    @Autowired
    private AuditLogRepository auditLogRepository;

    @Test
    void managerCreatesAndAssignsTaskAndWorkerCompletesIt() throws Exception {
        // Administrator creates the team
        String admin = login("admin@flow.test", "flow-admin-password");
        call(admin, post("/api/users"), """
                {"email": "mia@flow.test", "fullName": "Mia Manager", "password": "mia-password",
                 "roles": ["MANAGER"]}""").andExpect(status().isCreated());
        String workerId = read(call(admin, post("/api/users"), """
                {"email": "wendy@flow.test", "fullName": "Wendy Worker", "password": "wendy-password",
                 "roles": ["WORKER"]}""").andExpect(status().isCreated()), "$.id");

        // Manager creates the task and its checklist
        String manager = login("mia@flow.test", "mia-password");
        String taskId = read(call(manager, post("/api/tasks"), """
                {"title": "Daily kitchen safety inspection", "description": "Before opening",
                 "priority": "HIGH", "dueDate": "2026-12-01T08:00:00Z"}""")
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.status").value("DRAFT")), "$.id");
        String base = "/api/tasks/" + taskId;
        String gas = read(call(manager, post(base + "/requirements"),
                "{\"title\": \"Is the gas connection safe?\", \"type\": \"YES_NO\"}"), "$.id");
        String fridge = read(call(manager, post(base + "/requirements"),
                "{\"title\": \"Record refrigerator temperature\", \"type\": \"NUMBER\", \"unit\": \"°C\"}"), "$.id");
        String floorBody = call(manager, post(base + "/requirements"), """
                {"title": "Floor condition", "type": "DROPDOWN", "options": ["Clean", "Needs cleaning"]}""")
                .andReturn().getResponse().getContentAsString();
        String floor = JsonPath.read(floorBody, "$.id");
        String clean = JsonPath.read(floorBody, "$.options[0].id");
        String notes = read(call(manager, post(base + "/requirements"),
                "{\"title\": \"Notes\", \"type\": \"TEXT\", \"required\": false}"), "$.id");

        call(manager, post(base + "/assign"), "{\"assigneeId\": \"" + workerId + "\"}")
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("ASSIGNED"))
                .andExpect(jsonPath("$.assignee.fullName").value("Wendy Worker"));

        // Worker finds the task, starts it and answers the checklist
        String worker = login("wendy@flow.test", "wendy-password");
        call(worker, get("/api/tasks").param("status", "ASSIGNED"), null)
                .andExpect(jsonPath("$.totalElements").value(1))
                .andExpect(jsonPath("$.content[0].id").value(taskId));
        call(worker, get(base + "/requirements"), null).andExpect(jsonPath("$.length()").value(4));
        call(worker, post(base + "/start"), null).andExpect(jsonPath("$.status").value("IN_PROGRESS"));
        answer(worker, base, gas, "{\"booleanValue\": true}");
        answer(worker, base, fridge, "{\"numberValue\": 3.5, \"comment\": \"Door seal OK\"}");
        answer(worker, base, floor, "{\"selectedOptionIds\": [\"" + clean + "\"]}");
        answer(worker, base, notes, "{\"textValue\": \"All good\"}");

        // Manager sees the answers
        call(manager, get(base + "/responses"), null)
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.length()").value(4));
        call(manager, get(base), null)
                .andExpect(jsonPath("$.status").value("IN_PROGRESS"))
                .andExpect(jsonPath("$.version").value(2));

        // Every status change and key action was recorded
        List<TaskStatusChange> history = historyRepository.findAllByTaskIdOrderByChangedAtAscIdAsc(
                UUID.fromString(taskId));
        assertThat(history).extracting(TaskStatusChange::getToStatus)
                .containsExactly(TaskStatus.DRAFT, TaskStatus.ASSIGNED, TaskStatus.IN_PROGRESS);
        assertThat(auditLogRepository.findAllByEntityIdOrderByCreatedAtAscIdAsc(UUID.fromString(taskId)))
                .extracting(AuditLog::getAction)
                .containsExactly(AuditAction.TASK_CREATED, AuditAction.TASK_ASSIGNED, AuditAction.TASK_STARTED);
        assertThat(auditLogRepository.findAllByActionOrderByCreatedAtAsc(AuditAction.USER_CREATED)).hasSize(3);
        assertThat(auditLogRepository.findAllByActionOrderByCreatedAtAsc(AuditAction.LOGIN_SUCCEEDED)).hasSize(3);
    }

    private String login(String email, String password) throws Exception {
        return read(mockMvc.perform(post("/api/auth/login").contentType(MediaType.APPLICATION_JSON)
                        .content("{\"email\": \"" + email + "\", \"password\": \"" + password + "\"}"))
                .andExpect(status().isOk()), "$.accessToken");
    }

    private void answer(String token, String base, String requirementId, String json) throws Exception {
        call(token, put(base + "/requirements/" + requirementId + "/response"), json).andExpect(status().isOk());
    }

    private ResultActions call(String token, MockHttpServletRequestBuilder request, String json) throws Exception {
        request.header("Authorization", "Bearer " + token);
        if (json != null) {
            request.contentType(MediaType.APPLICATION_JSON).content(json);
        }
        return mockMvc.perform(request);
    }

    private static String read(ResultActions result, String path) throws Exception {
        return JsonPath.read(result.andReturn().getResponse().getContentAsString(), path);
    }

}
