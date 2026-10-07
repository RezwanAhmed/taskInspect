package com.taskinspect.notifications;

import com.google.firebase.messaging.FirebaseMessaging;
import com.google.firebase.messaging.FirebaseMessagingException;
import com.google.firebase.messaging.Message;
import com.google.firebase.messaging.MessagingErrorCode;
import com.google.firebase.messaging.Notification;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Component;

/**
 * Push sender backed by Firebase Cloud Messaging ({@code PUSH_TYPE=fcm},
 * task 8.4/8.7). A token Firebase no longer recognizes (app removed, token
 * replaced) is reported as {@link PushResult#INVALID_TOKEN} so
 * {@link NotificationService} deletes it; any other failure is logged and
 * the token is kept.
 */
@Component
@ConditionalOnProperty(name = "taskinspect.push.type", havingValue = "fcm")
public class FcmPushSender implements PushSender {

    private static final Logger log = LoggerFactory.getLogger(FcmPushSender.class);

    private final FirebaseMessaging messaging;

    public FcmPushSender(FirebaseMessaging messaging) {
        this.messaging = messaging;
    }

    @Override
    public PushResult send(String token, PushMessage message) {
        Message fcmMessage = Message.builder()
                .setToken(token)
                .setNotification(Notification.builder()
                        .setTitle(message.title())
                        .setBody(message.body())
                        .build())
                .putAllData(message.data())
                .build();
        try {
            messaging.send(fcmMessage);
            return PushResult.SENT;
        } catch (FirebaseMessagingException e) {
            if (e.getMessagingErrorCode() == MessagingErrorCode.UNREGISTERED) {
                return PushResult.INVALID_TOKEN;
            }
            log.warn("Push notification could not be sent: {}", e.toString());
            return PushResult.FAILED;
        }
    }

}
