# API Contracts

Base URL (dev): `http://localhost:3000`. All request/response bodies are JSON. Authenticated requests send `Authorization: Bearer <accessToken>`.

Error responses always have the shape:
```json
{ "statusCode": 400, "code": "BadRequestException", "message": "...", "correlationId": "uuid", "details": ["optional per-field validation errors"] }
```

## Auth (`/auth`) — implemented

All endpoints below are public (no bearer token required) except `GET /auth/me`.

### `GET /auth/me`
Requires `Authorization: Bearer <accessToken>`. Returns the caller's current profile (lets a client restore its session on app start without re-prompting for credentials):
```json
{ "id": "uuid", "email": "...", "fullName": "...", "globalRole": "USER", "preferredLanguage": "en" }
```
`401` if the access token is missing/expired/invalid.

### `POST /auth/register`
Request:
```json
{ "email": "owner@example.com", "password": "at-least-12-chars", "fullName": "Obaid Khan", "preferredLanguage": "en" }
```
Response `201`:
```json
{ "id": "uuid", "email": "owner@example.com", "fullName": "Obaid Khan", "globalRole": "USER", "preferredLanguage": "en" }
```
`409` if the email is already registered.

### `POST /auth/login`
Request:
```json
{ "email": "owner@example.com", "password": "..." }
```
Optional header: `X-Device-Id: <client-generated-device-id>` — associates the issued refresh token with a device for later session management.

Response `200`:
```json
{
  "accessToken": "jwt",
  "refreshToken": "opaque-hex-string",
  "profile": { "id": "uuid", "email": "...", "fullName": "...", "globalRole": "USER", "preferredLanguage": "en" }
}
```
`401` on invalid credentials or inactive account.

### `POST /auth/refresh`
Request:
```json
{ "refreshToken": "opaque-hex-string" }
```
Response `200`: new `{ accessToken, refreshToken }` pair. The submitted refresh token is revoked on use (rotation) — reusing it will `401`.

### `POST /auth/logout`
Request:
```json
{ "refreshToken": "opaque-hex-string" }
```
Response `204`. Revokes the given refresh token.

## Workspaces (`/workspaces`) — implemented

All endpoints below require `Authorization: Bearer <accessToken>`.

### `POST /workspaces`
Creates a workspace; the caller becomes its `OWNER`. Request:
```json
{ "name": "Obaid Goat Farm", "slug": "obaid-goat-farm" }
```
`slug` is optional — auto-generated from `name` (lowercased, hyphenated, de-duplicated) when omitted. Response `201`: the created `Workspace`.

### `GET /workspaces`
Lists workspaces the caller is an active member of. Response `200`: `Workspace[]`.

### `GET /workspaces/:workspaceId`
Requires active membership in that workspace (`WorkspaceGuard`). Response `200`: the `Workspace`. `403` if the caller isn't a member, `404` if it doesn't exist or is inactive.

### `POST /workspaces/:workspaceId/members`
Requires the caller to hold `OWNER` or `ADMIN` in that workspace. Request:
```json
{ "email": "staff@example.com", "role": "STAFF" }
```
`role` must be one of `ADMIN`/`MANAGER`/`STAFF`/`VIEWER` (not `OWNER` — ownership isn't granted via a plain invite). Response `201`: the created `WorkspaceMembership`. `404` if no account exists yet for that email (they must register first — there is no pending-invite-for-unregistered-user flow yet). `409` if already a member.

## Health (`/health`) — implemented

### `GET /health`
Public. Response `200` if the database is reachable:
```json
{ "status": "ok", "database": "connected", "timestamp": "2026-11-03T..." }
```
`503` if the database is unreachable.

## Not yet implemented

Every other endpoint implied by CLAUDE.md's phases (workspaces, accounting, goat farm, land, documents, notifications, backup, AI, WhatsApp, reports, admin console) does not exist yet. This file will be extended module-by-module as each is built — see [IMPLEMENTATION_STATUS.md](IMPLEMENTATION_STATUS.md) for current progress.
