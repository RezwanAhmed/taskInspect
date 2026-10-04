package com.taskinspect.notifications;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.taskinspect.TestcontainersConfiguration;
import com.taskinspect.auth.JwtService;
import com.taskinspect.users.OrganizationRepository;
import com.taskinspect.users.RoleName;
import com.taskinspect.users.RoleRepository;
import com.taskinspect.users.User;
import com.taskinspect.users.UserRepository;
import java.util.List;
import java.util.Map;
import java.util.Set;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.context.annotation.Import;
import org.springframework.http.MediaType;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.ResultActions;
import org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder;

@Import(TestcontainersConfiguration.class)
@SpringBootTest
@AutoConfigureMockMvc
class DeviceNotificationTests {

    private static final PushMessage MESSAGE = new PushMessage("Task assigned", "Check pump 3",
            Map.of("taskId", "00000000-0000-0000-0000-000000000001"));

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private JwtService jwtService;

    @Autowired
    private NotificationService notificationService;

    @Autowired
    private DeviceTokenRepository deviceTokenRepository;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private RoleRepository roleRepository;

    @Autowired
    private OrganizationRepository organizationRepository;

    @MockitoBean
    private PushSender pushSender;

    private User worker;
    private User otherWorker;

    @BeforeEach
    void setUp() {
        worker = save("worker@example.com");
        otherWorker = save("other@example.com");
        when(pushSender.send(any(), any())).thenReturn(PushResult.SENT);
    }

    @AfterEach
    void tearDown() {
        deviceTokenRepository.deleteAll();
        userRepository.deleteAll();
    }

    @Test
    void registeringStoresTheTokenForTheCaller() throws Exception {
        register(worker, "token-a", "ANDROID").andExpect(status().isNoContent());

        DeviceToken stored = deviceTokenRepository.findByToken("token-a").orElseThrow();
        assertThat(stored.getUserId()).isEqualTo(worker.getId());
        assertThat(stored.getPlatform()).isEqualTo(DevicePlatform.ANDROID);
    }

    @Test
    void registeringAgainKeepsOneRowAndUpdatesThePlatform() throws Exception {
        register(worker, "token-a", "ANDROID").andExpect(status().isNoContent());
        register(worker, "token-a", "IOS").andExpect(status().isNoContent());

        assertThat(deviceTokenRepository.count()).isEqualTo(1);
        assertThat(deviceTokenRepository.findByToken("token-a").orElseThrow().getPlatform())
                .isEqualTo(DevicePlatform.IOS);
    }

    @Test
    void aTokenMovesToTheUserWhoLogsInOnTheDevice() throws Exception {
        register(worker, "shared-device", "ANDROID").andExpect(status().isNoContent());
        register(otherWorker, "shared-device", "ANDROID").andExpect(status().isNoContent());

        assertThat(deviceTokenRepository.findByToken("shared-device").orElseThrow().getUserId())
                .isEqualTo(otherWorker.getId());

        notificationService.notifyUsers(List.of(worker.getId()), MESSAGE);
        verify(pushSender, never()).send(any(), any());
    }

    @Test
    void unregisteringRemovesOnlyTheCallersToken() throws Exception {
        register(worker, "token-a", "ANDROID").andExpect(status().isNoContent());
        register(otherWorker, "token-b", "ANDROID").andExpect(status().isNoContent());

        unregister(worker, "token-b").andExpect(status().isNoContent());
        unregister(worker, "token-a").andExpect(status().isNoContent());
        unregister(worker, "never-registered").andExpect(status().isNoContent());

        assertThat(deviceTokenRepository.findByToken("token-a")).isEmpty();
        assertThat(deviceTokenRepository.findByToken("token-b")).isPresent();
    }

    @Test
    void devicesNeedALogin() throws Exception {
        mockMvc.perform(put("/api/devices").contentType(MediaType.APPLICATION_JSON)
                        .content("{\"token\": \"token-a\", \"platform\": \"ANDROID\"}"))
                .andExpect(status().isUnauthorized());
        mockMvc.perform(delete("/api/devices").contentType(MediaType.APPLICATION_JSON)
                        .content("{\"token\": \"token-a\"}"))
                .andExpect(status().isUnauthorized());
    }

    @Test
    void registrationIsValidated() throws Exception {
        register(worker, "", "ANDROID")
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("VALIDATION_ERROR"));
        register(worker, "x".repeat(513), "ANDROID")
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("VALIDATION_ERROR"));
        mockMvc.perform(as(worker, put("/api/devices")).contentType(MediaType.APPLICATION_JSON)
                        .content("{\"token\": \"token-a\"}"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("VALIDATION_ERROR"));
        register(worker, "token-a", "WINDOWS").andExpect(status().isBadRequest());

        assertThat(deviceTokenRepository.count()).isZero();
    }

    @Test
    void notifyingSendsToEveryDeviceOfTheUsersOnly() throws Exception {
        register(worker, "phone", "ANDROID").andExpect(status().isNoContent());
        register(worker, "tablet", "IOS").andExpect(status().isNoContent());
        register(otherWorker, "other-phone", "ANDROID").andExpect(status().isNoContent());

        notificationService.notifyUsers(List.of(worker.getId()), MESSAGE);

        verify(pushSender).send("phone", MESSAGE);
        verify(pushSender).send("tablet", MESSAGE);
        verify(pushSender, never()).send(eq("other-phone"), any());
    }

    @Test
    void invalidTokensAreDeletedAndFailuresDoNotStopTheOthers() throws Exception {
        register(worker, "gone", "ANDROID").andExpect(status().isNoContent());
        register(worker, "broken", "ANDROID").andExpect(status().isNoContent());
        register(worker, "offline", "ANDROID").andExpect(status().isNoContent());
        register(worker, "fine", "IOS").andExpect(status().isNoContent());
        when(pushSender.send(eq("gone"), any())).thenReturn(PushResult.INVALID_TOKEN);
        when(pushSender.send(eq("broken"), any())).thenThrow(new IllegalStateException("push service down"));
        when(pushSender.send(eq("offline"), any())).thenReturn(PushResult.FAILED);

        notificationService.notifyUsers(List.of(worker.getId()), MESSAGE);

        verify(pushSender).send("fine", MESSAGE);
        assertThat(deviceTokenRepository.findByToken("gone")).isEmpty();
        assertThat(deviceTokenRepository.findByToken("broken")).isPresent();
        assertThat(deviceTokenRepository.findByToken("offline")).isPresent();
        assertThat(deviceTokenRepository.findByToken("fine")).isPresent();
    }

    @Test
    void notifyingNobodySendsNothing() {
        notificationService.notifyUsers(List.of(), MESSAGE);

        verify(pushSender, never()).send(any(), any());
    }

    private ResultActions register(User user, String token, String platform)
            throws Exception {
        return mockMvc.perform(as(user, put("/api/devices")).contentType(MediaType.APPLICATION_JSON)
                .content("{\"token\": \"" + token + "\", \"platform\": \"" + platform + "\"}"));
    }

    private ResultActions unregister(User user, String token) throws Exception {
        return mockMvc.perform(as(user, delete("/api/devices")).contentType(MediaType.APPLICATION_JSON)
                .content("{\"token\": \"" + token + "\"}"));
    }

    private MockHttpServletRequestBuilder as(User user, MockHttpServletRequestBuilder request) {
        return request.header("Authorization", "Bearer " + jwtService.issueAccessToken(user).value());
    }

    private User save(String email) {
        return userRepository.save(new User(organizationRepository.getDefault(), email, "not-used", "Worker",
                Set.of(roleRepository.findByName(RoleName.WORKER).orElseThrow())));
    }

}
