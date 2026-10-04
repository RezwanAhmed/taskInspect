-- V20: push notification device tokens (Phase 8, spec section 21).
--
-- One row per app installation: the Firebase Cloud Messaging registration
-- token and the user who is logged in on that device. A token belongs to
-- one user at a time; when another user logs in on the same device the
-- row moves to that user, so the first user gets no more notifications
-- there. Tokens that FCM reports as no longer valid are deleted.

CREATE TABLE device_tokens (
    id         UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id    UUID         NOT NULL,
    token      VARCHAR(512) NOT NULL,
    platform   VARCHAR(10)  NOT NULL,
    created_at TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ  NOT NULL DEFAULT now(),
    CONSTRAINT uk_device_tokens_token UNIQUE (token),
    CONSTRAINT fk_device_tokens_user FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE,
    CONSTRAINT ck_device_tokens_platform CHECK (platform IN ('ANDROID', 'IOS'))
);

CREATE INDEX ix_device_tokens_user_id ON device_tokens (user_id);
