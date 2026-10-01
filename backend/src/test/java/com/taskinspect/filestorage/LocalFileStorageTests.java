package com.taskinspect.filestorage;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import java.io.ByteArrayInputStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;

class LocalFileStorageTests {

    private static final Instant NOW = Instant.parse("2026-10-01T10:00:00Z");

    @TempDir
    Path folder;

    private final String key = "tasks/" + UUID.randomUUID() + "/" + UUID.randomUUID() + ".jpg";

    private LocalFileStorage storage(Instant now) {
        return new LocalFileStorage(new LocalFileStorageProperties(folder), Clock.fixed(now, ZoneOffset.UTC));
    }

    @Test
    void signaturesAreCheckedAndExpire() {
        LocalFileStorage storage = storage(NOW);
        long expires = NOW.plus(Duration.ofMinutes(10)).getEpochSecond();
        // uploadUrl needs a current HTTP request for its base URL, so sign directly
        String signature = storage.sign("PUT", key, "image/jpeg", 100, expires);

        assertThat(storage.verify("PUT", key, "image/jpeg", 100, expires, signature)).isTrue();
        assertThat(storage.verify("PUT", key, "image/png", 100, expires, signature)).isFalse();
        assertThat(storage.verify("PUT", key, "image/jpeg", 101, expires, signature)).isFalse();
        assertThat(storage.verify("GET", key, "image/jpeg", 100, expires, signature)).isFalse();
        assertThat(storage.verify("PUT", key, "image/jpeg", 100, expires + 1, signature)).isFalse();
        assertThat(storage.verify("PUT", key, "image/jpeg", 100, expires, null)).isFalse();
        assertThat(storage.verify("PUT", "../" + key, "image/jpeg", 100, expires, signature)).isFalse();
    }

    @Test
    void writesOnlyCompleteFilesWithinTheLimit() throws Exception {
        LocalFileStorage storage = storage(NOW);

        assertThat(storage.write(key, new ByteArrayInputStream(new byte[6]), 5)).isFalse();
        assertThat(storage.size(key)).isEmpty();
        try (var files = Files.walk(folder)) {
            assertThat(files.filter(Files::isRegularFile)).isEmpty();
        }

        assertThat(storage.write(key, new ByteArrayInputStream(new byte[5]), 5)).isTrue();
        assertThat(storage.size(key)).hasValue(5);

        storage.delete(key);
        assertThat(storage.size(key)).isEmpty();
    }

    @Test
    void rejectsKeysOutsideTheStorageFolder() {
        LocalFileStorage storage = storage(NOW);
        assertThatThrownBy(() -> storage.size("../secret.jpg")).isInstanceOf(IllegalArgumentException.class);
        assertThatThrownBy(() -> storage.delete("tasks/x/y.exe")).isInstanceOf(IllegalArgumentException.class);
    }

}
