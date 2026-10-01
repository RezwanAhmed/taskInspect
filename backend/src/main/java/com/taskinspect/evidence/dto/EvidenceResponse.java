package com.taskinspect.evidence.dto;

import com.taskinspect.evidence.Evidence;
import com.taskinspect.evidence.EvidenceStatus;
import java.time.Instant;
import java.util.UUID;

public record EvidenceResponse(
        UUID id,
        UUID requirementId,
        String fileName,
        String contentType,
        long sizeBytes,
        EvidenceStatus status,
        Instant createdAt,
        Instant uploadedAt) {

    public static EvidenceResponse from(Evidence evidence) {
        return new EvidenceResponse(evidence.getId(), evidence.getRequirement().getId(), evidence.getFileName(),
                evidence.getContentType(), evidence.getSizeBytes(), evidence.getStatus(), evidence.getCreatedAt(),
                evidence.getUploadedAt());
    }

}
