package com.taskinspect.users;

import java.util.Optional;
import java.util.UUID;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;

public interface UserRepository extends JpaRepository<User, UUID> {

    /** Finds a user by email; pass an email normalized with {@link User#normalizeEmail}. */
    Optional<User> findByEmail(String email);

    boolean existsByEmail(String email);

    boolean existsByRolesName(RoleName roleName);

    // The finders below return users for API responses: their team manager is loaded with them
    // (LOAD: the other attributes keep their own fetch type).

    @EntityGraph(attributePaths = "teamManager", type = EntityGraph.EntityGraphType.LOAD)
    Page<User> findAllByOrganizationId(UUID organizationId, Pageable pageable);

    @EntityGraph(attributePaths = "teamManager", type = EntityGraph.EntityGraphType.LOAD)
    Page<User> findAllByOrganizationIdAndRolesName(UUID organizationId, RoleName roleName, Pageable pageable);

    @EntityGraph(attributePaths = "teamManager", type = EntityGraph.EntityGraphType.LOAD)
    Optional<User> findByIdAndOrganizationId(UUID id, UUID organizationId);

    @EntityGraph(attributePaths = "teamManager", type = EntityGraph.EntityGraphType.LOAD)
    Page<User> findAllByOrganizationIdAndTeamManagerId(UUID organizationId, UUID teamManagerId, Pageable pageable);

}
