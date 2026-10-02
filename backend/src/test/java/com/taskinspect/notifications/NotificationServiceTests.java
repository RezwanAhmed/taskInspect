package com.taskinspect.notifications;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyCollection;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

import java.util.List;
import java.util.Map;
import java.util.UUID;
import org.junit.jupiter.api.Test;

/** Unit tests of sending to devices and cleaning up invalid tokens (task 9.1b). */
class NotificationServiceTests {

    private static final UUID USER = UUID.randomUUID();
    private static final PushMessage MESSAGE = new PushMessage("Task approved", "Kitchen", Map.of());

    private final DeviceTokenRepository repository = mock(DeviceTokenRepository.class);
    private final PushSender sender = mock(PushSender.class);
    private final NotificationService service = new NotificationService(repository, sender);

    @Test
    void registeringStoresThePlatformName() {
        service.registerDevice(USER, "phone", DevicePlatform.IOS);

        verify(repository).register(USER, "phone", "IOS");
    }

    @Test
    void unregisteringDeletesOnlyTheCallersToken() {
        service.unregisterDevice(USER, "phone");

        verify(repository).deleteForUser("phone", USER);
    }

    @Test
    void noUsersMeansNoLookup() {
        service.notifyUsers(List.of(), MESSAGE);

        verifyNoInteractions(repository, sender);
    }

    @Test
    void everyDeviceGetsTheMessageAndNothingIsDeletedWhenAllAreValid() {
        when(repository.findTokensOfUsers(List.of(USER))).thenReturn(List.of("phone", "tablet"));
        when(sender.send(any(), any())).thenReturn(PushResult.SENT);

        service.notifyUsers(List.of(USER), MESSAGE);

        verify(sender).send("phone", MESSAGE);
        verify(sender).send("tablet", MESSAGE);
        verify(repository, never()).deleteTokens(anyCollection());
    }

    @Test
    void onlyInvalidTokensAreDeletedInOneCallAndFailuresDoNotStopTheRest() {
        when(repository.findTokensOfUsers(List.of(USER))).thenReturn(List.of("gone", "broken", "offline", "old"));
        when(sender.send("gone", MESSAGE)).thenReturn(PushResult.INVALID_TOKEN);
        when(sender.send("broken", MESSAGE)).thenThrow(new IllegalStateException("push service down"));
        when(sender.send("offline", MESSAGE)).thenReturn(PushResult.FAILED);
        when(sender.send("old", MESSAGE)).thenReturn(PushResult.INVALID_TOKEN);

        service.notifyUsers(List.of(USER), MESSAGE);

        verify(sender).send("old", MESSAGE);
        verify(repository).deleteTokens(List.of("gone", "old"));
    }

}
