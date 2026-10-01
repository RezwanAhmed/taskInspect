package com.taskinspect.users;

import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

public interface OrganizationRepository extends JpaRepository<Organization, UUID> {

    /** The single organization of the first release. */
    default Organization getDefault() {
        return findById(Organization.DEFAULT_ID)
                .orElseThrow(() -> new IllegalStateException("Default organization is missing"));
    }

}
