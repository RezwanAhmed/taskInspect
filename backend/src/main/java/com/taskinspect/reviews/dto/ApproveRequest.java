package com.taskinspect.reviews.dto;

import jakarta.validation.constraints.Size;

/** Approving needs no body; an optional comment for the worker. */
public record ApproveRequest(@Size(max = 2000) String comment) {
}
