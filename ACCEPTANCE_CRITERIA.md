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
- [x] Logging in navigates to the dashboard shell matching the approved reference layout. *(verified via widget test for the unauthenticated case only — authenticated-state rendering not yet exercised against a real login)*
- [x] All 12 sidebar destinations navigate to a real route (either the Dashboard or an honest "not built yet" screen) — no dead taps.
- [x] KPI cards render a `$0.00` zero state, never fabricated numbers.
- [ ] Logout from the top bar menu actually clears the session and returns to the login screen. *(not yet exercised against a live backend)*

### Money / financial arithmetic
- [x] `0.1 + 0.2` through `Money` equals exactly `0.30`, proving no floating-point error — verified by an automated test that also asserts native JS float arithmetic *would* have failed.
- [x] A set of journal lines that nets to zero is detected as balanced; a set that doesn't is detected as unbalanced — verified by automated test.

## Template for new features

When adding a feature, add a subsection here with concrete, checkable criteria (not vague goals) before considering it ready to mark ✅ elsewhere. Example shape:

```
### <Feature name>
- [ ] <Specific, observable behavior a reviewer could check>
- [ ] <Edge case / failure path>
- [ ] <Permission boundary, if applicable>
```
