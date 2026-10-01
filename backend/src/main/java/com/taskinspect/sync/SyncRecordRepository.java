package com.taskinspect.sync;

import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

public interface SyncRecordRepository extends JpaRepository<SyncRecord, UUID> {
}
