package com.taskinspect.notifications;

import java.util.Map;

/**
 * A push notification: the text shown to the user and the data the app
 * reads when it is tapped (for example {@code taskId} to open the task).
 */
public record PushMessage(String title, String body, Map<String, String> data) {

    public PushMessage {
        data = data == null ? Map.of() : Map.copyOf(data);
    }

}
