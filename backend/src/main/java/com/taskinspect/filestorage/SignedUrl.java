package com.taskinspect.filestorage;

import java.time.Instant;
import java.util.Map;

/** A time-limited URL plus the method and headers the client must use with it. */
public record SignedUrl(String url, String method, Map<String, String> headers, Instant expiresAt) {
}
