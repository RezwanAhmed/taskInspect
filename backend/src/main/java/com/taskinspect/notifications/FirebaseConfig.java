package com.taskinspect.notifications;

import com.google.auth.oauth2.GoogleCredentials;
import com.google.firebase.FirebaseApp;
import com.google.firebase.FirebaseOptions;
import com.google.firebase.messaging.FirebaseMessaging;
import java.io.IOException;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

/**
 * Firebase Admin SDK setup for {@link FcmPushSender} ({@code PUSH_TYPE=fcm},
 * task 8.4). Credentials come from the standard Google convention: the
 * {@code GOOGLE_APPLICATION_CREDENTIALS} environment variable pointing at a
 * service account key file locally, or the attached service account with no
 * file at all once this runs on Google Cloud (ADR-0006).
 */
@Configuration
@ConditionalOnProperty(name = "taskinspect.push.type", havingValue = "fcm")
public class FirebaseConfig {

    @Bean
    public FirebaseMessaging firebaseMessaging() throws IOException {
        FirebaseOptions options = FirebaseOptions.builder()
                .setCredentials(GoogleCredentials.getApplicationDefault())
                .build();
        FirebaseApp app = FirebaseApp.getApps().isEmpty() ? FirebaseApp.initializeApp(options) : FirebaseApp.getInstance();
        return FirebaseMessaging.getInstance(app);
    }

}
