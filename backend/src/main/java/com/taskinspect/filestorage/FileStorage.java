package com.taskinspect.filestorage;

import java.time.Duration;
import java.util.OptionalLong;

/**
 * Where evidence files are kept (ADR-0005). Files never pass through the
 * API's business endpoints: the app uploads to and downloads from
 * short-lived signed URLs. The local implementation stores files on disk
 * for development and tests; {@link S3FileStorage} uses AWS S3.
 */
public interface FileStorage {

    /** A URL that accepts one PUT of the file (exactly this content type, at most {@code maxBytes}). */
    SignedUrl uploadUrl(String key, String contentType, long maxBytes, Duration validFor);

    /** A URL that returns the file. */
    SignedUrl downloadUrl(String key, Duration validFor);

    /** Size of the stored file, or empty if it is not (yet) stored. */
    OptionalLong size(String key);

    /** Deletes the file if it exists. */
    void delete(String key);

}
