package com.taskinspect.filestorage;

import static org.assertj.core.api.Assertions.assertThat;

import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.time.Duration;
import java.util.OptionalLong;
import org.junit.jupiter.api.BeforeAll;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.condition.EnabledIfEnvironmentVariable;
import org.testcontainers.containers.MinIOContainer;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;
import software.amazon.awssdk.auth.credentials.AwsBasicCredentials;
import software.amazon.awssdk.auth.credentials.StaticCredentialsProvider;
import software.amazon.awssdk.regions.Region;
import software.amazon.awssdk.services.s3.S3Client;

/**
 * The S3 storage against MinIO, an S3-compatible server: pre-signed upload
 * and download, size, delete. Runs only with S3_TESTS=true: the laptop's
 * Docker can't pull the MinIO image over SSH yet (WORKLOG, Phase 8).
 */
@EnabledIfEnvironmentVariable(named = "S3_TESTS", matches = "true")
@Testcontainers
class S3FileStorageTests {

    @Container
    static final MinIOContainer MINIO = new MinIOContainer("minio/minio:RELEASE.2024-01-16T16-07-38Z");

    private static S3FileStorage storage;
    private final HttpClient http = HttpClient.newHttpClient();

    @BeforeAll
    static void createBucket() {
        try (S3Client admin = S3Client.builder()
                .region(Region.US_EAST_1)
                .endpointOverride(URI.create(MINIO.getS3URL()))
                .forcePathStyle(true)
                .credentialsProvider(StaticCredentialsProvider.create(
                        AwsBasicCredentials.create(MINIO.getUserName(), MINIO.getPassword())))
                .build()) {
            admin.createBucket(bucket -> bucket.bucket("evidence"));
        }
        storage = new S3FileStorage(new S3FileStorageProperties("evidence", "us-east-1", MINIO.getS3URL(), true,
                MINIO.getUserName(), MINIO.getPassword()));
    }

    @Test
    void uploadsWithTheSignedUrlThenDownloadsAndDeletes() throws Exception {
        byte[] photo = "fake jpeg bytes".getBytes();
        SignedUrl upload = storage.uploadUrl("tasks/t1/e1.jpg", "image/jpeg", photo.length, Duration.ofMinutes(5));
        assertThat(upload.method()).isEqualTo("PUT");
        assertThat(upload.headers()).containsEntry("Content-Type", "image/jpeg");

        HttpResponse<String> put = http.send(HttpRequest.newBuilder(URI.create(upload.url()))
                .header("Content-Type", "image/jpeg")
                .PUT(HttpRequest.BodyPublishers.ofByteArray(photo)).build(), HttpResponse.BodyHandlers.ofString());
        HttpResponse<String> tooBig = http.send(HttpRequest.newBuilder(URI.create(upload.url()))
                .header("Content-Type", "image/jpeg")
                .PUT(HttpRequest.BodyPublishers.ofByteArray(new byte[photo.length + 10])).build(),
                HttpResponse.BodyHandlers.ofString());
        assertThat(tooBig.statusCode()).isEqualTo(403);
        assertThat(put.statusCode()).isEqualTo(200);
        assertThat(storage.size("tasks/t1/e1.jpg")).isEqualTo(OptionalLong.of(photo.length));

        SignedUrl download = storage.downloadUrl("tasks/t1/e1.jpg", Duration.ofMinutes(5));
        HttpResponse<byte[]> get = http.send(HttpRequest.newBuilder(URI.create(download.url())).GET().build(),
                HttpResponse.BodyHandlers.ofByteArray());
        assertThat(get.statusCode()).isEqualTo(200);
        assertThat(get.body()).isEqualTo(photo);

        storage.delete("tasks/t1/e1.jpg");
        assertThat(storage.size("tasks/t1/e1.jpg")).isEmpty();
    }

    @Test
    void anUploadWithAnotherContentTypeIsRefused() throws Exception {
        SignedUrl upload = storage.uploadUrl("tasks/t1/e2.jpg", "image/jpeg", 3, Duration.ofMinutes(5));

        HttpResponse<String> put = http.send(HttpRequest.newBuilder(URI.create(upload.url()))
                .header("Content-Type", "application/pdf")
                .PUT(HttpRequest.BodyPublishers.ofByteArray(new byte[3])).build(), HttpResponse.BodyHandlers.ofString());

        assertThat(put.statusCode()).isEqualTo(403);
        assertThat(storage.size("tasks/t1/e2.jpg")).isEmpty();
    }

    @Test
    void aMissingFileHasNoSize() {
        assertThat(storage.size("tasks/none")).isEmpty();
    }

}
