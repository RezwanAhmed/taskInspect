package com.taskinspect.notifications;

import java.util.Collection;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.transaction.annotation.Transactional;

public interface DeviceTokenRepository extends JpaRepository<DeviceToken, UUID> {

    /**
     * Stores the token for the user, or moves an existing token to this user
     * (another user logged in on the device). One statement, so two requests
     * with the same token at once cannot both insert it.
     */
    @Transactional
    @Modifying
    @Query(value = """
            insert into device_tokens (user_id, token, platform)
            values (:userId, :token, :platform)
            on conflict (token) do update
            set user_id = excluded.user_id, platform = excluded.platform, updated_at = now()
            """, nativeQuery = true)
    void register(@Param("userId") UUID userId, @Param("token") String token, @Param("platform") String platform);

    @Transactional
    @Modifying
    @Query("delete from DeviceToken d where d.token = :token and d.userId = :userId")
    int deleteForUser(@Param("token") String token, @Param("userId") UUID userId);

    @Transactional
    @Modifying
    @Query("delete from DeviceToken d where d.token in :tokens")
    int deleteTokens(@Param("tokens") Collection<String> tokens);

    @Query("select d.token from DeviceToken d where d.userId in :userIds")
    List<String> findTokensOfUsers(@Param("userIds") Collection<UUID> userIds);

    Optional<DeviceToken> findByToken(String token);

}
