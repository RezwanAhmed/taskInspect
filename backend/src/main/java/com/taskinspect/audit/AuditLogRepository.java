package com.taskinspect.audit;

import java.util.List;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

public interface AuditLogRepository extends JpaRepository<AuditLog, UUID> {

    List<AuditLog> findAllByEntityIdOrderByCreatedAtAscIdAsc(UUID entityId);

    List<AuditLog> findAllByActionOrderByCreatedAtAsc(AuditAction action);

}
