# ADR-0003: JWT Authentication

- **Status:** Accepted
- **Date:** 2026-09-30

## Context

Every API call must be tied to a user and checked against that user's
role — a worker must not be able to approve a task even with a
hand-crafted request. The backend should be stateless so it can be
restarted or run as several copies without losing sessions.

The mobile app works offline for long periods (see ADR-0004). A worker
who loses the connection for a day must not be logged out and lose
unsent work, but a stolen or lost phone must be possible to cut off.

## Decision

Use **JWT access tokens** together with **refresh tokens** stored in
the database.

- **Login** (`POST /api/auth/login`) checks the password (hashed with
  BCrypt) and returns a short-lived access token and a long-lived
  refresh token.
- **Access token** — a signed JWT (HMAC-SHA256, secret from an
  environment variable) containing the user ID, roles and expiry; valid
  for about 15 minutes. A JWT filter validates it on every request, so
  the server needs no session storage.
- **Refresh token** — a random value valid for about 30 days, stored in
  the `refresh_tokens` table **only as a hash**. `POST /api/auth/refresh`
  returns a new access token and a new refresh token and revokes the old
  one (rotation). Reusing a revoked refresh token revokes all of that
  user's refresh tokens.
- **Logout** (`POST /api/auth/logout`) revokes the refresh token.
  Deactivating a user revokes all their refresh tokens, so they are cut
  off within one access-token lifetime.
- **Authorization** — roles in the token are checked on every endpoint,
  and ownership ("is this the assigned worker?") is checked in the
  services (see [architecture.md](../architecture.md#task-lifecycle)).
- **Mobile storage** — both tokens are kept in secure storage (Android
  Keystore / iOS Keychain), never in plain preferences or logs.

## Alternatives Considered

| Option | Pros | Cons |
|--------|------|------|
| **JWT + refresh tokens** (chosen) | Stateless requests; works for any number of backend copies; refresh tokens allow long offline periods and can still be revoked; standard and well supported by Spring Security. | An access token stays valid until it expires (kept short); needs a refresh flow in the app. |
| Server-side sessions (cookies) | Easy to revoke instantly; simple in the browser. | Session storage needed on the server (or Redis) for several copies; cookies are awkward for mobile apps. |
| Long-lived JWT only (no refresh) | Simplest to build. | A stolen token works until it expires and cannot be revoked. |
| External identity provider (Keycloak, Auth0, AWS Cognito) | Ready-made login features (MFA, password reset). | Extra service to run or pay for; hides the authentication logic that this project should demonstrate; can be adopted later. |

## Consequences

- Any backend instance can serve any request; nothing is lost on
  restart.
- The app refreshes the access token automatically (Dio interceptor,
  task 4.16); if the refresh token has expired, the user is asked to
  sign in again and queued offline work is kept (see the offline sync
  section of `architecture.md`).
- Secrets (JWT signing key, database password) come from environment
  variables and are never committed.
- If more services ever need to validate tokens, signing can move from
  a shared secret to a public / private key pair (RS256) without
  changing the app.
