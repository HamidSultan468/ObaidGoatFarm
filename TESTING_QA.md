# Testing & QA

Testing strategy and current, actual coverage — not aspirational. See [IMPLEMENTATION_STATUS.md](IMPLEMENTATION_STATUS.md) for the most up-to-date verified state.

## Strategy by layer

| Layer | Tooling | Approach |
|---|---|---|
| Backend unit tests | Vitest | Pure business logic (e.g. `Money` arithmetic) — no database or network required, fast, run on every change |
| Backend integration tests | Vitest + a real PostgreSQL instance | Auth flow, guards, audit logging against a real database — **not yet possible in this environment** (no PostgreSQL available — see IMPLEMENTATION_STATUS.md blockers) |
| Backend type safety | `tsc --noEmit` | Whole-project type-check, run after any backend change |
| Flutter static analysis | `flutter analyze` | Lint + type-check, zero-tolerance (must be clean) |
| Flutter widget tests | `flutter_test` | Component/screen behavior with provider overrides for dependencies that touch platform channels (see `TokenStorage` abstraction, which exists specifically so `ApiClient` is testable without a real secure-storage plugin) |
| Flutter integration/E2E | `integration_test` package (not yet set up) | Full user flows against a running backend — planned for Phase 14 |
| Manual UI verification | Running the actual app | Per CLAUDE.md: UI changes are tested by actually running the feature in a browser/app, not just passing static checks |

## Current coverage (verified, as of the last IMPLEMENTATION_STATUS.md update)

- Backend: 9/9 unit tests passing (`Money`). Whole-project type-check clean.
- Flutter: 1/1 widget test passing (app boots to login screen with no session). `flutter analyze`: 0 issues.
- **Not yet covered**: any code path that requires a live database (all of the auth module's actual behavior — register/login/refresh/logout/me — is type-checked but not integration-tested), any real login flow in the Flutter app against a running backend.

## What "done" requires (per CLAUDE.md §5/§7)

A feature is not reported complete until the relevant tests above have actually been run and passed — not merely written. See [ACCEPTANCE_CRITERIA.md](ACCEPTANCE_CRITERIA.md) for the full Definition of Done.

## Security-specific testing (Phase 14, not yet started)

Planned, not yet performed:
- Tenant isolation: verify a user cannot access another workspace's data even with a guessed/forged `workspaceId`.
- Auth: verify expired/revoked/malformed tokens are rejected, refresh rotation actually invalidates the old token, rate limiting actually throttles.
- Financial integrity: verify an unbalanced journal entry is rejected, a posted entry cannot be mutated, reversal produces a correct net-zero result.
- File upload security, backup/restore integrity (once those modules exist).

## Known gaps

- No CI pipeline yet — tests are run manually.
- No test database/fixture strategy defined yet (needed once Phase 05+ introduces data-heavy flows).
- No load/performance testing yet.
