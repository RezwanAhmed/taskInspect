package com.taskinspect.common.security;

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.Test;
import org.springframework.security.crypto.password.PasswordEncoder;

class PasswordConfigTests {

    private final PasswordEncoder encoder = new PasswordConfig().passwordEncoder();

    @Test
    void hashesWithBcryptAndVerifies() {
        String hash = encoder.encode("correct horse battery staple");

        assertThat(hash).startsWith("$2a$12$").doesNotContain("correct horse");
        assertThat(encoder.matches("correct horse battery staple", hash)).isTrue();
        assertThat(encoder.matches("wrong password", hash)).isFalse();
    }

    @Test
    void samePasswordGivesDifferentHashes() {
        assertThat(encoder.encode("secret-password")).isNotEqualTo(encoder.encode("secret-password"));
    }

}
