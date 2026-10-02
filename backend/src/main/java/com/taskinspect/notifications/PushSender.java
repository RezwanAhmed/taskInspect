package com.taskinspect.notifications;

/**
 * Sends one push notification to one device. {@link LogPushSender} only
 * logs (development and tests, the default); the Firebase Cloud Messaging
 * sender follows once the Firebase project exists (task 8.4).
 */
public interface PushSender {

    PushResult send(String token, PushMessage message);

}
