package com.taskinspect.notifications;

/** What happened to one push notification sent to one device. */
public enum PushResult {
    /** Handed to the push service. */
    SENT,
    /** The push service no longer knows the token (app removed, token replaced); it is deleted. */
    INVALID_TOKEN,
    /** Could not be sent this time (network, service error); the token is kept. */
    FAILED
}
