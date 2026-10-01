package com.taskinspect.filestorage;

import java.nio.file.Path;
import org.springframework.boot.context.properties.ConfigurationProperties;

/** Folder of the local file storage ({@code STORAGE_LOCAL_DIR}, default {@code ./data/evidence}). */
@ConfigurationProperties(prefix = "taskinspect.storage.local")
public record LocalFileStorageProperties(Path directory) {
}
