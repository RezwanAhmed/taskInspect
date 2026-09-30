package com.taskinspect.audit;

import com.taskinspect.common.logging.RequestIdFilter;
import java.util.UUID;
import org.slf4j.MDC;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

/**
 * Writes the audit log. {@link #record} joins the caller's transaction, so
 * an action that is rolled back leaves no audit entry. {@link #recordAlways}
 * commits on its own, for events that end in an error (e.g. a failed login)
 * but must still be recorded.
 */
@Service
public class AuditService {

    private final AuditLogRepository repository;

    public AuditService(AuditLogRepository repository) {
        this.repository = repository;
    }

    @Transactional
    public void record(Entry entry) {
        save(entry);
    }

    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void recordAlways(Entry entry) {
        save(entry);
    }

    private void save(Entry entry) {
        repository.save(new AuditLog(entry.organizationId(), entry.actorId(), entry.action(), entry.entityType(),
                entry.entityId(), entry.details(), MDC.get(RequestIdFilter.MDC_KEY)));
    }

    /** What happened, who did it and to what. Any field except {@code action} may be {@code null}. */
    public record Entry(AuditAction action, UUID organizationId, UUID actorId, String entityType, UUID entityId,
            String details) {
    }

}
