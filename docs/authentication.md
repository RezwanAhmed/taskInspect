# TaskInspect — Authentication

How users sign in, how their tokens work and how the app keeps them
signed in while offline. Why it is built this way:
[ADR-0003](decisions/0003-jwt-authentication.md). Who may call which
endpoint: [architecture.md — API Permissions](architecture.md#api-permissions).

## Overview

| Token | What | Lifetime | Stored |
|-------|------|----------|--------|
| Access token | Signed JWT sent with every request | 15 minutes (`JWT_ACCESS_TOKEN_TTL`) | Only on the device |
| Refresh token | Random value, exchanged for new tokens | 30 days (`REFRESH_TOKEN_TTL`) | On the device; on the server only as a SHA-256 hash |

```
App                                   Backend
 |-- POST /api/auth/login ------------->|  check password (BCrypt)
 |<-- access token + refresh token -----|  store hash of the refresh token
 |-- GET /api/tasks  (Bearer access) -->|  verify signature, issuer, expiry
 |      ... access token expires ...    |
 |-- POST /api/auth/refresh ----------->|  revoke old refresh token,
 |<-- new access + new refresh token ---|  issue new ones (rotation)
 |-- POST /api/auth/logout ------------>|  revoke the refresh token
```

## Signing In

`POST /api/auth/login` with `{"email", "password"}`:

- The email is trimmed and lower-cased; emails are unique.
- Passwords are checked with **BCrypt** (cost 12). For an unknown email
  the server still checks a dummy hash, so the answer takes as long as
  for a real user, and the error is the same: `401 INVALID_CREDENTIALS`
  ("Email or password is incorrect") — the API does not reveal which
  emails exist.
- A deactivated account gets `403 ACCOUNT_DISABLED`, even with the right
  password.
- Successful and failed logins are written to the audit log (failed ones
  even though the request ends in an error).

The answer contains both tokens with their expiry times and the user
(`id`, `email`, `fullName`, `roles`). `GET /api/auth/me` returns what
the current access token says: `id`, `email`, `roles` and
`tokenExpiresAt`.

## The Access Token

- A JWT signed with **HMAC-SHA256**; the key is `JWT_SECRET` (at least
  32 characters — the backend refuses to start otherwise; never
  committed, see `.env.example`).
- Claims: `iss` (`taskinspect`), `sub` (user ID), `iat`, `exp`, `email`,
  `roles`.
- Every request except login, refresh, logout, health check, API docs
  and signed file URLs needs `Authorization: Bearer <token>`. The backend
  is stateless: it checks the signature, the issuer and the expiry, and
  nothing else is stored per session.
- Rejected tokens answer `401 INVALID_TOKEN`: expired, tampered, signed
  with another key, from another issuer, or unsigned (`alg: none`). No
  token at all answers `401 UNAUTHORIZED`.
- Roles come only from the server-signed token; a client cannot add
  roles. A token of a user who has been deleted cannot change anything
  (`401`).

## Refresh Tokens

`POST /api/auth/refresh` with `{"refreshToken"}` returns new tokens:

- **Rotation**: each refresh token works once. The old one is revoked and
  points to its replacement.
- **Reuse detection**: presenting a refresh token that was already used
  revokes *every* refresh token of that user (it was probably stolen) and
  is written to the audit log (`REFRESH_TOKEN_REUSED`); the user must
  sign in again on all devices.
- Unknown or expired refresh tokens answer `401 INVALID_REFRESH_TOKEN`.
- The token's database row is locked during the refresh, so two requests
  with the same token cannot both succeed.
- A deactivated account's refresh revokes all its refresh tokens and
  answers `403 ACCOUNT_DISABLED`.

`POST /api/auth/logout` with `{"refreshToken"}` revokes that token
(unknown or already revoked tokens are ignored). The access token
itself cannot be revoked; it simply expires.

## Roles

| Role | Can (summary) |
|------|---------------|
| `ADMINISTRATOR` | Create users, form teams, create main tasks for managers, see everything |
| `MANAGER` | Create, assign, publish and review tasks; manage their team's work |
| `WORKER` | Take, execute and submit tasks assigned or open to them |

A user can have several roles (e.g. a manager who is also a worker uses
the app alone). Roles are checked on every endpoint (`@PreAuthorize`),
ownership ("is this the assigned worker?") in the services. Details:
[architecture.md](architecture.md#reviewers-and-account-types).

## Accounts

- **First administrator**: on startup, if no administrator exists, the
  backend creates one from `ADMIN_EMAIL` / `ADMIN_PASSWORD` (at least 12
  characters) and `ADMIN_FULL_NAME`. Without them it only logs a
  warning. If the email belongs to a non-administrator, startup fails.
- **Other users** are created by an administrator
  (`POST /api/users`, password at least 8 characters).
- **Deactivation**: a deactivated user cannot sign in or refresh, and the
  sync tells the app. There is no API for it yet (it is set in the
  database). An access token issued before stays valid until it expires
  (at most 15 minutes) — an open question for the owner whether every
  request should check this.

## In the Mobile App

- Tokens and the user's profile are kept in secure storage (Android
  Keystore / iOS Keychain via `flutter_secure_storage`), never in plain
  preferences or logs. The saved profile lets the app start offline.
- A Dio interceptor adds the access token to every call. It refreshes
  the token shortly before it expires; if the server still answers
  `401`, it refreshes once and sends the request again.
- Overlapping refreshes share one request, and a lock shared between
  isolates keeps the app and the background sync from using the same
  refresh token twice (which would sign the user out everywhere).
- If the server refuses the refresh token, the app returns to the login
  screen. **Unsent offline work is kept**: the local data stays marked
  with its owner; the same user gets it back after signing in again,
  another account is asked first and never sees it.
- Without a connection the refresh simply fails and the saved session
  is kept, so a worker offline for a day stays signed in.
- Signing out (after a warning when changes are not synced yet) removes
  the tokens and the local data from the device and asks the server to
  revoke the refresh token - best effort: offline, the token simply
  expires.

## Settings

| Variable | Default | Meaning |
|----------|---------|---------|
| `JWT_SECRET` | — (required) | HMAC key, at least 32 characters |
| `JWT_ACCESS_TOKEN_TTL` | `15m` | Access token lifetime |
| `REFRESH_TOKEN_TTL` | `30d` | Refresh token lifetime |
| `ADMIN_EMAIL`, `ADMIN_PASSWORD` | — | First administrator (see "Accounts") |
| `ADMIN_FULL_NAME` | `Administrator` | The first administrator's name |

## Tests

Login, refresh (rotation, reuse, expiry), logout, every invalid-token
case and the role matrix of every endpoint are covered by backend tests
(`auth/*Tests`, `common/security/AuthorizationMatrixTests`); see
[testing.md](testing.md).
