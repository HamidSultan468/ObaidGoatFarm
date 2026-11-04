# Acceptance Criteria

## Definition of Done

Restated from CLAUDE.md: a feature is complete only when **all** of the following are true — not just the functional implementation.

1. **Functional implementation** — the feature works as specified, for the intended user-facing behavior.
2. **Input validation** — every input is validated server-side (never trust client-side validation alone).
3. **Permission checks** — enforced server-side (`WorkspaceGuard`/`RolesGuard`/`@Roles()` or their future equivalents), never assumed from the UI hiding a control.
4. **Error handling** — failure paths are handled explicitly, not left to crash or silently fail.
5. **Audit logging** — present for any mutating action on tenant-scoped or financially-significant data.
6. **Automated tests** — written *and actually run*, passing. A test that exists but hasn't been executed does not count.
7. **Documentation** — the relevant doc (API_CONTRACTS.md, DATA_MODEL.md, FEATURES.md, the module's own doc) reflects the change.
8. **Verified acceptance criteria** — the specific criteria below for that feature are checked off against real, observed behavior (a running app, a passing test run, an inspected database row) — not assumed.

A feature failing any one of these is not done — it's in progress, and should be marked 🟡 in [IMPLEMENTATION_STATUS.md](IMPLEMENTATION_STATUS.md), not ✅.

## Acceptance criteria — built features

### Authentication (register / login / refresh / logout / me)
- [ ] A new user can register with a valid email and a password ≥12 characters; a duplicate email is rejected with 409.
- [ ] A registered user can log in with correct credentials and receives an access token + refresh token.
- [ ] An incorrect password or unknown email returns 401 with no indication of which was wrong.
- [ ] A refresh token can be exchanged for a new access/refresh pair exactly once; reusing a spent refresh token is rejected.
- [ ] Logging out revokes the refresh token server-side; it can no longer be used to refresh.
- [ ] `GET /auth/me` returns the current profile for a valid access token and 401 for an invalid/expired one.
- [ ] *(blocked — needs a live database to actually execute these checks; currently verified only by type-check/code review)*

### Dashboard shell
- [x] Logging in navigates to the dashboard shell matching the approved reference layout. *(verified via widget test for the unauthenticated case, and a live Chrome run for the login screen itself; authenticated-state rendering not yet exercised against a real login)*
- [x] All 12 sidebar destinations navigate to a real route (either the Dashboard or an honest "not built yet" screen) — no dead taps.
- [x] KPI cards render a `$0.00` zero state, never fabricated numbers.
- [x] Global search returns matching sidebar destinations and workspaces as you type, and tapping a result navigates/selects correctly. *(verified via `flutter analyze` + code review; not yet exercised live against real workspace data)*
- [x] The sidebar collapses into a drawer below 900px width, reachable via a menu button — verified live via a resized Chrome window screenshot.
- [ ] Logout from the top bar menu actually clears the session and returns to the login screen. *(not yet exercised against a live backend)*

### Multi-factor authentication (TOTP)
- [ ] Starting MFA setup returns a secret + otpauth URL; scanning the QR code (rendered from the URL) in a real authenticator app and submitting its code enables MFA.
- [ ] Once enabled, logging in with correct credentials returns `{ mfaRequired: true, mfaToken }` instead of session tokens.
- [ ] Submitting a valid code with that token to `/auth/mfa/login` returns real session tokens; an invalid code is rejected with 401.
- [ ] Disabling MFA requires a currently-valid code — an active session alone is not sufficient.
- [ ] A challenge token cannot be used as a bearer token on any other authenticated route.
- [ ] *(blocked — needs a live database; currently verified only by type-check/code review)*

### Super Admin Console
- [ ] A user with `globalRole: USER` gets 403 on every `/admin/*` route.
- [ ] A user with `globalRole: ADMIN` can list workspaces/users but gets 403 on any mutation.
- [ ] A `SUPER_ADMIN_OWNER` without MFA enabled gets 403 on every mutation; with MFA enabled, mutations succeed.
- [ ] The Super Admin Owner account itself cannot be deactivated or have its role reassigned via these endpoints.
- [ ] A user cannot deactivate their own account or change their own platform role via these endpoints.
- [ ] The Admin Console sidebar entry and `/admin` route are both inaccessible (hidden, and server-redirected if navigated to directly) for non-admin users.
- [ ] *(blocked — needs a live database; currently verified only by type-check/code review)*

### Session management
- [ ] `GET /auth/sessions` lists only the caller's own active sessions, never another user's.
- [ ] `DELETE /auth/sessions/:id` on a session belonging to someone else returns 404, not the other user's data.
- [ ] Revoking the session currently in use causes the next token refresh to fail (forcing re-login).
- [ ] *(blocked — needs a live database; currently verified only by type-check/code review)*

### Localization
- [x] Switching the language in Settings changes the app's locale immediately, without restarting.
- [x] Urdu text renders with `TextDirection.rtl` — verified by an automated widget test (`app/test/l10n_test.dart`).
- [x] The login screen, including the MFA challenge step, renders fully in the selected language.

### Money / financial arithmetic
- [x] `0.1 + 0.2` through `Money` equals exactly `0.30`, proving no floating-point error — verified by an automated test that also asserts native JS float arithmetic *would* have failed.
- [x] A set of journal lines that nets to zero is detected as balanced; a set that doesn't is detected as unbalanced — verified by automated test.

### Accounting engine (Phase 05)
- [x] `assertBalanced` rejects a single-line entry, an empty entry, and an unbalanced multi-line entry; accepts a balanced one, including amounts that would fail under native float arithmetic — verified by automated test (6/6).
- [ ] Creating a workspace seeds its default chart of accounts automatically, with no manual setup step.
- [ ] Recording income posts a two-line entry (debit cash/bank, credit income) that nets to zero; the income account's and cash account's balances both update correctly.
- [ ] A posted entry cannot be edited or deleted — only reversed, producing a new entry with every line's sign flipped, linked via `reversalOfId`.
- [ ] Reversing an already-reversed entry, or a `PENDING_APPROVAL`/`REJECTED` entry, is rejected.
- [ ] An entry whose debit total meets a workspace's `approvalThreshold` is created `PENDING_APPROVAL`, excluded from balances/reports until approved, and only an OWNER/ADMIN can approve or reject it.
- [ ] A contact's ledger shows exactly the posted entries tagged to them, in order, with a correct running total.
- [ ] An account statement's running balance matches the account's own balance endpoint at the final row.
- [ ] `GET /receipts/verify/:code` works with no `Authorization` header and returns only the documented fields — never an internal id or unrelated workspace data; an unknown or unposted code returns 404.
- [ ] The dashboard's KPI cards and Recent Transactions reflect a transaction within seconds of it being recorded (via the `refresh()`/`invalidate` chain in `AccountingController`).
- [ ] *(all of the above blocked on a live database — currently verified only by type-check, the pure `assertBalanced` unit tests, and `flutter analyze`/widget tests)*

### Reporting & Analytics (Phase 12)
- [x] `GET /workspaces/:id/analytics` returns only the report ids the caller's role may open — verified live for OWNER (8), STAFF (2), and a non-member (403 on any report).
- [x] Financial-summary totals match the existing Profit & Loss endpoint exactly, and the monthly trend sums to the same total income — verified live.
- [x] Balance sheet balances (assets = liabilities + equity + retained earnings, difference exactly 0) and trial balance is balanced — verified live.
- [x] CSV export has a UTF-8 BOM and the exact totals; Excel export opens as a valid workbook with the correct sheet/values (checked with Python `openpyxl`, not just a byte count); PDF export is a real, readable PDF (checked with `pymupdf`) — verified live.
- [x] A STAFF-role caller is refused export of a financial report (403); every export is recorded in the audit log — verified live.
- [x] The Flutter report picker only ever offers reports the `/analytics` list returned (never a hardcoded menu) — verified by widget test (`reports_screen_test.dart`) with a scripted repository returning a restricted list.
- [x] Changing the date filter triggers a live refetch with the new range, reflected in the on-screen table — verified live in a real browser (network log showed the new `from` param and a fresh `200`).

### Offline Mode & Synchronization (Phase 13)
- [x] A write (income/expense/transfer/animal weight/health) that succeeds online behaves exactly as before — nothing queued — verified by widget test.
- [x] A write made while offline is queued (encrypted) and reported to the user as queued, not silently lost or silently failed — verified by widget test.
- [x] A write the server actively rejects (validation) is surfaced to the user immediately and never queued for retry — verified by widget test.
- [x] Reconnecting automatically retries every queued item in creation order, reusing the *same* idempotency key per item (never a new one) — verified by widget test (`outbox_controller_test.dart`, 9/9).
- [x] Retrying the same request twice with the same `Idempotency-Key` posts exactly once; a different body with the same key is rejected `422`; 5 simultaneous submissions with one key post exactly once — verified live.
- [x] Editing an `Animal`/`LandParcel` with a stale `If-Match` is refused `412` and the record is unchanged; a current `If-Match` succeeds — verified live.
- [x] A queued item can be manually retried or discarded from the sync-status panel — verified by widget test.

### Security & QA (Phase 14)
- [x] A member of one workspace cannot read or write another workspace's data on any module, using a real second account's token (not a guessed id) — verified live across every `:workspaceId`-scoped route (28 read + 4 write checks).
- [x] A blocked cross-tenant write genuinely never happened (checked by reading the data back), not just rejected with the right status code — verified live.
- [x] The MFA challenge token issued on `{mfaRequired: true}` cannot be used as a normal bearer token anywhere — verified live (this was failing before DECISIONS.md D041's fix, confirmed failing first, then confirmed fixed).
- [x] Starting the backend outside development with `CORS_ORIGIN` unset refuses to boot rather than defaulting to allow-all — verified by unit test (`env.validation.spec.ts`).
- [x] A malformed, tampered, or missing bearer token is rejected `401`; a spent refresh token cannot refresh again; a logged-out refresh token cannot refresh — verified live.
- [x] Repeated login attempts are eventually rate-limited (`429`) — verified live.
- [x] A SQL-injection- or script-tag-shaped input string is stored and returned as inert literal text, never executed or interpreted — verified live.
- [x] An over-length field is rejected `400`, not silently truncated; an unexpected extra field is rejected, not silently dropped or accepted — verified live.
- [x] Every icon-only button has a screen-reader label (tooltip) — verified by code audit across the whole `lib/` tree; the two gaps found were fixed.
- [x] Every text/background color pair actually used for text meets WCAG AA contrast, or the gap is explicitly documented with why it wasn't changed — verified by computing contrast ratios for the full `AppColors` palette (see DECISIONS.md D040).

## Template for new features

When adding a feature, add a subsection here with concrete, checkable criteria (not vague goals) before considering it ready to mark ✅ elsewhere. Example shape:

```
### <Feature name>
- [ ] <Specific, observable behavior a reviewer could check>
- [ ] <Edge case / failure path>
- [ ] <Permission boundary, if applicable>
```
