package com.taskinspect.filestorage;

import com.taskinspect.common.error.ApiException;
import io.swagger.v3.oas.annotations.Hidden;
import jakarta.servlet.http.HttpServletRequest;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.core.io.FileSystemResource;
import org.springframework.core.io.Resource;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.MediaTypeFactory;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

/**
 * Serves the signed URLs of {@link LocalFileStorage}. No login: the
 * signature in the URL is the permission, like an S3 pre-signed URL.
 */
@RestController
@Hidden
@ConditionalOnProperty(name = "taskinspect.storage.type", havingValue = "local", matchIfMissing = true)
public class LocalFileController {

    static final String INVALID_SIGNATURE = "INVALID_SIGNATURE";
    static final String FILE_TOO_LARGE = "FILE_TOO_LARGE";
    static final String FILE_NOT_FOUND = "FILE_NOT_FOUND";

    private final LocalFileStorage storage;

    public LocalFileController(LocalFileStorage storage) {
        this.storage = storage;
    }

    @PutMapping("/api/files/{*key}")
    public ResponseEntity<Void> upload(@PathVariable String key,
            @RequestParam(defaultValue = "0") long expires, @RequestParam(defaultValue = "0") long maxBytes,
            @RequestParam(required = false) String signature,
            @RequestHeader(name = "Content-Type", required = false) String contentType,
            HttpServletRequest request) throws IOException {
        String path = stripSlash(key);
        if (!storage.verify("PUT", path, mediaType(contentType), maxBytes, expires, signature)) {
            throw invalidSignature();
        }
        if (request.getContentLengthLong() > maxBytes || !storage.write(path, request.getInputStream(), maxBytes)) {
            throw new ApiException(HttpStatus.CONTENT_TOO_LARGE, FILE_TOO_LARGE,
                    "The file is larger than registered");
        }
        return ResponseEntity.ok().build();
    }

    @GetMapping("/api/files/{*key}")
    public ResponseEntity<Resource> download(@PathVariable String key,
            @RequestParam(defaultValue = "0") long expires, @RequestParam(required = false) String signature) throws IOException {
        String path = stripSlash(key);
        if (!storage.verify("GET", path, "", 0, expires, signature)) {
            throw invalidSignature();
        }
        Path file = storage.file(path);
        if (file == null) {
            throw new ApiException(HttpStatus.NOT_FOUND, FILE_NOT_FOUND, "File not found");
        }
        MediaType type = MediaTypeFactory.getMediaType(String.valueOf(file.getFileName()))
                .orElse(MediaType.APPLICATION_OCTET_STREAM);
        return ResponseEntity.ok().contentType(type).contentLength(Files.size(file))
                .body(new FileSystemResource(file));
    }

    /** "image/jpeg" from "image/jpeg; charset=UTF-8" (some clients add parameters). */
    private static String mediaType(String contentType) {
        if (contentType == null) {
            return "";
        }
        int semicolon = contentType.indexOf(';');
        return (semicolon < 0 ? contentType : contentType.substring(0, semicolon)).trim().toLowerCase();
    }

    private static String stripSlash(String key) {
        return key.startsWith("/") ? key.substring(1) : key;
    }

    private static ApiException invalidSignature() {
        return new ApiException(HttpStatus.FORBIDDEN, INVALID_SIGNATURE, "The link is invalid or has expired");
    }

}
