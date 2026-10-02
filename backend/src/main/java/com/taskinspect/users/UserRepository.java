package com.taskinspect.users;

import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;

public interface UserRepository extends JpaRepository<User, UUID> {

    /** Finds a user by email; pass an email normalized with {@link User#normalizeEmail}. */
    Optional<User> findByEmail(String email);

    boolean existsByEmail(String email);

    boolean existsByRolesName(RoleName roleName);

    /** Per team manager: how many active members the team has. */
    @Query("""
            select u.teamManager.id, count(u) from User u
            where u.organization.id = :organizationId and u.active = true and u.teamManager is not null
            group by u.teamManager.id""")
    List<Object[]> countActiveMembersPerTeam(UUID organizationId);

    /** How many active members a manager's team has. */
    long countByTeamManagerIdAndActiveTrue(UUID teamManagerId);

    List<User> findAllByOrganizationIdAndRolesNameAndActiveTrue(UUID organizationId, RoleName roleName);

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
