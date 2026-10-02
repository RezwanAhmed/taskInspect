package com.taskinspect.filestorage;

import org.springframework.boot.context.properties.ConfigurationProperties;

/**
 * The S3 bucket for evidence files ({@code STORAGE_TYPE=s3}). In AWS the
 * credentials come from the environment (IAM role or the default provider
 * chain); {@code endpoint}, {@code pathStyle} and the access keys are for
 * S3-compatible services such as MinIO (local runs and tests).
 */
@ConfigurationProperties(prefix = "taskinspect.storage.s3")
public record S3FileStorageProperties(String bucket, String region, String endpoint, boolean pathStyle,
        String accessKey, String secretKey) {
}
