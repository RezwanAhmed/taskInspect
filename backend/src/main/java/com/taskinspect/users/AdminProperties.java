package com.taskinspect.users;

import org.springframework.boot.context.properties.ConfigurationProperties;

/**
 * The first administrator account, taken from the {@code ADMIN_EMAIL},
 * {@code ADMIN_PASSWORD} and {@code ADMIN_FULL_NAME} environment variables.
 */
@ConfigurationProperties(prefix = "taskinspect.admin")
public record AdminProperties(String email, String password, String fullName) {

    boolean isConfigured() {
        return email != null && !email.isBlank() && password != null && !password.isBlank();
    }

}
