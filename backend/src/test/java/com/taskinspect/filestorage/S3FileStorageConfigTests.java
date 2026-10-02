package com.taskinspect.filestorage;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import java.net.URLDecoder;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import org.junit.jupiter.api.Test;

/** S3 storage settings and signing; no server needed (URLs are signed locally). */
class S3FileStorageConfigTests {

    private static S3FileStorageProperties properties(String bucket, String accessKey, String secretKey) {
        return new S3FileStorageProperties(bucket, "eu-central-1", "http://localhost:9000", true, accessKey, secretKey);
    }

    @Test
    void theUploadUrlIsSignedForContentTypeAndExactLength() {
        S3FileStorage storage = new S3FileStorage(properties("evidence", "key", "secret"));

        SignedUrl upload = storage.uploadUrl("tasks/t1/e1.jpg", "image/jpeg", 1234, Duration.ofMinutes(5));

        String url = URLDecoder.decode(upload.url(), StandardCharsets.UTF_8);
        assertThat(url).startsWith("http://localhost:9000/evidence/tasks/t1/e1.jpg?");
        assertThat(url).contains("X-Amz-SignedHeaders=content-length;content-type;host").contains("X-Amz-Expires=300");
        assertThat(upload.method()).isEqualTo("PUT");
        assertThat(upload.headers()).containsEntry("Content-Type", "image/jpeg").containsEntry("Content-Length", "1234");
        assertThat(storage.downloadUrl("tasks/t1/e1.jpg", Duration.ofMinutes(5)).method()).isEqualTo("GET");
        storage.destroy();
    }

    @Test
    void aBucketIsRequiredAndKeysComeInPairs() {
        assertThatThrownBy(() -> new S3FileStorage(properties(" ", null, null)))
                .isInstanceOf(IllegalStateException.class).hasMessageContaining("S3_BUCKET");
        assertThatThrownBy(() -> new S3FileStorage(properties("evidence", "key", "")))
                .isInstanceOf(IllegalStateException.class).hasMessageContaining("S3_SECRET_KEY");
        assertThatThrownBy(() -> new S3FileStorage(properties("evidence", null, "secret")))
                .isInstanceOf(IllegalStateException.class).hasMessageContaining("S3_ACCESS_KEY");
    }

}
