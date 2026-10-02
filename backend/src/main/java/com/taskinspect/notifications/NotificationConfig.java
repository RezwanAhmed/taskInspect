package com.taskinspect.notifications;

import org.springframework.context.annotation.Configuration;
import org.springframework.scheduling.annotation.EnableAsync;

/** Runs {@code @Async} listeners (task notifications) on Spring Boot's task executor. */
@Configuration
@EnableAsync
public class NotificationConfig {
}
