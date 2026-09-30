package com.taskinspect;

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.core.env.Environment;
import org.springframework.test.context.ActiveProfiles;

class ConfigurationTests {

    @Nested
    @SpringBootTest(properties = "SERVER_PORT=9191")
    class Defaults {

        @Autowired
        private Environment environment;

        @Test
        void devProfileIsActiveByDefault() {
            assertThat(environment.getActiveProfiles()).containsExactly("dev");
        }

        @Test
        void serverPortComesFromEnvironmentVariable() {
            assertThat(environment.getProperty("server.port")).isEqualTo("9191");
        }

    }

    @Nested
    @SpringBootTest
    @ActiveProfiles("prod")
    class Production {

        @Autowired
        private Environment environment;

        @Test
        void prodProfileHidesErrorDetails() {
            assertThat(environment.getProperty("server.error.include-message")).isEqualTo("never");
            assertThat(environment.getProperty("server.error.include-stacktrace")).isEqualTo("never");
        }

    }

}
