package com.taskinspect.filestorage;

import java.net.URI;
import java.time.Duration;
import java.util.Map;
import java.util.OptionalLong;
import org.springframework.beans.factory.DisposableBean;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.stereotype.Component;
import software.amazon.awssdk.auth.credentials.AwsBasicCredentials;
import software.amazon.awssdk.auth.credentials.AwsCredentialsProvider;
import software.amazon.awssdk.auth.credentials.DefaultCredentialsProvider;
import software.amazon.awssdk.auth.credentials.StaticCredentialsProvider;
import software.amazon.awssdk.regions.Region;
import software.amazon.awssdk.services.s3.S3Client;
import software.amazon.awssdk.services.s3.S3Configuration;
import software.amazon.awssdk.services.s3.model.S3Exception;
import software.amazon.awssdk.services.s3.presigner.S3Presigner;

/**
 * Evidence files in AWS S3 (ADR-0005, Phase 8): the app uploads with a
 * pre-signed PUT URL and downloads with a pre-signed GET URL, so files never
 * pass through the API. The upload URL is signed for the file's content type
 * and exact length (the registered size), so S3 refuses any other upload.
 */
@Component
@ConditionalOnProperty(name = "taskinspect.storage.type", havingValue = "s3")
@EnableConfigurationProperties(S3FileStorageProperties.class)
public class S3FileStorage implements FileStorage, DisposableBean {

    private final S3Client s3;
    private final S3Presigner presigner;
    private final String bucket;

    public S3FileStorage(S3FileStorageProperties properties) {
        if (properties.bucket() == null || properties.bucket().isBlank()) {
            throw new IllegalStateException("S3_BUCKET must be set when STORAGE_TYPE=s3");
        }
        boolean hasKey = properties.accessKey() != null && !properties.accessKey().isBlank();
        boolean hasSecret = properties.secretKey() != null && !properties.secretKey().isBlank();
        if (hasKey != hasSecret) {
            throw new IllegalStateException("Set both S3_ACCESS_KEY and S3_SECRET_KEY, or neither (AWS credentials)");
        }
        this.bucket = properties.bucket();
        Region region = Region.of(properties.region());
        AwsCredentialsProvider credentials = !hasKey
                ? DefaultCredentialsProvider.builder().build()
                : StaticCredentialsProvider.create(
                        AwsBasicCredentials.create(properties.accessKey(), properties.secretKey()));
        S3Configuration config = S3Configuration.builder().pathStyleAccessEnabled(properties.pathStyle()).build();
        URI endpoint = properties.endpoint() == null || properties.endpoint().isBlank()
                ? null : URI.create(properties.endpoint());

        var client = S3Client.builder().region(region).credentialsProvider(credentials).serviceConfiguration(config);
        var signer = S3Presigner.builder().region(region).credentialsProvider(credentials).serviceConfiguration(config);
        if (endpoint != null) {
            client.endpointOverride(endpoint);
            signer.endpointOverride(endpoint);
        }
        this.s3 = client.build();
        this.presigner = signer.build();
    }

    @Override
    public SignedUrl uploadUrl(String key, String contentType, long maxBytes, Duration validFor) {
        var presigned = presigner.presignPutObject(request -> request
                .signatureDuration(validFor)
                .putObjectRequest(put -> put.bucket(bucket).key(key).contentType(contentType).contentLength(maxBytes)));
        return new SignedUrl(presigned.url().toString(), "PUT",
                Map.of("Content-Type", contentType, "Content-Length", Long.toString(maxBytes)), presigned.expiration());
    }

    @Override
    public SignedUrl downloadUrl(String key, Duration validFor) {
        var presigned = presigner.presignGetObject(request -> request
                .signatureDuration(validFor)
                .getObjectRequest(get -> get.bucket(bucket).key(key)));
        return new SignedUrl(presigned.url().toString(), "GET", Map.of(), presigned.expiration());
    }

    @Override
    public OptionalLong size(String key) {
        try {
            return OptionalLong.of(s3.headObject(head -> head.bucket(bucket).key(key)).contentLength());
        } catch (S3Exception ex) {
            if (ex.statusCode() == 404) {
                return OptionalLong.empty();
            }
            throw ex;
        }
    }

    @Override
    public void delete(String key) {
        s3.deleteObject(delete -> delete.bucket(bucket).key(key));
    }

    @Override
    public void destroy() {
        presigner.close();
        s3.close();
    }

}
