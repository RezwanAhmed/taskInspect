package com.taskinspect.common.security;

/**
 * Role checks for {@code @PreAuthorize}, e.g.
 * {@code @PreAuthorize(Roles.ADMIN_OR_MANAGER)}. Roles come from the access
 * token; the backend checks them on every endpoint, never trusting the app.
 */
public final class Roles {

    public static final String ADMIN = "hasRole('ADMINISTRATOR')";
    public static final String MANAGER = "hasRole('MANAGER')";
    public static final String WORKER = "hasRole('WORKER')";
    public static final String ADMIN_OR_MANAGER = "hasAnyRole('ADMINISTRATOR', 'MANAGER')";
    /** Workers, and managers working on a main task (Phase 7A); the services check the assignee. */
    public static final String WORKER_OR_MANAGER = "hasAnyRole('WORKER', 'MANAGER')";

    private Roles() {
    }

}
