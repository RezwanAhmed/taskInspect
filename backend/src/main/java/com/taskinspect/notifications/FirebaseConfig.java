package com.taskinspect.notifications;

import com.google.auth.oauth2.GoogleCredentials;
import com.google.firebase.FirebaseApp;
import com.google.firebase.FirebaseOptions;
import com.google.firebase.messaging.FirebaseMessaging;
import java.io.FileInputStream;
import java.io.IOException;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

/**
 * Firebase Admin SDK setup for {@link FcmPushSender} ({@code PUSH_TYPE=fcm},
 * task 8.4). Credentials: a service account key file at
 * {@code GOOGLE_APPLICATION_CREDENTIALS} locally, or the attached service
 * account with no file at all once this runs on Google Cloud (ADR-0006).
 *
 * <p>Read as a Spring property, not through
 * {@code GoogleCredentials.getApplicationDefault()}'s own environment-variable
 * lookup: that reads the real OS environment via {@code System.getenv()},
 * but locally this project's {@code .env} file is loaded through Spring's
 * own config import (every other setting works the same way, through a
 * {@code ${...}} placeholder) - the Google library never sees it that way.
 * In Docker/the cloud this is set as a real environment variable, which
 * Spring's placeholder resolution picks up too, so the same code path
 * covers both; {@link GoogleCredentials#getApplicationDefault()} is only
 * the fallback for the no-file, attached-service-account case.
 */
@Configuration
@ConditionalOnProperty(name = "taskinspect.push.type", havingValue = "fcm")
public class FirebaseConfig {

    @Bean
    public FirebaseMessaging firebaseMessaging(
            @Value("${GOOGLE_APPLICATION_CREDENTIALS:}") String credentialsPath) throws IOException {
        GoogleCredentials credentials = credentialsPath.isBlank()
                ? GoogleCredentials.getApplicationDefault()
                : GoogleCredentials.fromStream(new FileInputStream(credentialsPath));
        FirebaseOptions options = FirebaseOptions.builder().setCredentials(credentials).build();
        FirebaseApp app = FirebaseApp.getApps().isEmpty() ? FirebaseApp.initializeApp(options) : FirebaseApp.getInstance();
        return FirebaseMessaging.getInstance(app);
    }

}
