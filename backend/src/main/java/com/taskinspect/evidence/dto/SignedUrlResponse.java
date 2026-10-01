package com.taskinspect.evidence.dto;

import com.taskinspect.filestorage.SignedUrl;
import java.time.Instant;
import java.util.Map;

/** Where to upload or download a file: send {@code method} to {@code url} with {@code headers}. */
public record SignedUrlResponse(String url, String method, Map<String, String> headers, Instant expiresAt) {

    public static SignedUrlResponse from(SignedUrl signed) {
        return new SignedUrlResponse(signed.url(), signed.method(), signed.headers(), signed.expiresAt());
    }

}
