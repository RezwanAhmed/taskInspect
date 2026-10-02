package com.taskinspect.notifications;

import java.util.ArrayList;
import java.util.Collection;
import java.util.List;
import java.util.UUID;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;

/**
 * Registers the devices of logged-in users and sends push notifications to
 * every device of the given users (spec section 21: backend -> notification
 * service -> FCM -> app). Sending never fails the caller: a device that
 * cannot be reached is logged and skipped, and tokens the push service
 * reports as invalid are deleted.
 */
@Service
public class NotificationService {

    private static final Logger log = LoggerFactory.getLogger(NotificationService.class);

    private final DeviceTokenRepository deviceTokenRepository;
    private final PushSender pushSender;

    public NotificationService(DeviceTokenRepository deviceTokenRepository, PushSender pushSender) {
        this.deviceTokenRepository = deviceTokenRepository;
        this.pushSender = pushSender;
    }

    /** Registers this device for the user; a token used by another user before moves to this user. */
    public void registerDevice(UUID userId, String token, DevicePlatform platform) {
        deviceTokenRepository.register(userId, token, platform.name());
    }

    /** Removes the device from the user (logout). Unknown tokens and other users' tokens are ignored. */
    public void unregisterDevice(UUID userId, String token) {
        deviceTokenRepository.deleteForUser(token, userId);
    }

    /** Sends the message to every registered device of these users. */
    public void notifyUsers(Collection<UUID> userIds, PushMessage message) {
        if (userIds.isEmpty()) {
            return;
        }
        List<String> invalid = new ArrayList<>();
        for (String token : deviceTokenRepository.findTokensOfUsers(userIds)) {
            PushResult result;
            try {
                result = pushSender.send(token, message);
            } catch (RuntimeException e) {
                log.warn("Push notification could not be sent: {}", e.toString());
                result = PushResult.FAILED;
            }
            if (result == PushResult.INVALID_TOKEN) {
                invalid.add(token);
            }
        }
        if (!invalid.isEmpty()) {
            deviceTokenRepository.deleteTokens(invalid);
        }
    }

}
