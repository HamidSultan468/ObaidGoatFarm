# Development Workflow

How work proceeds on this repository, per CLAUDE.md §5.

## Phase-by-phase execution

Work follows CLAUDE.md's 15 phases in order; a phase is not considered complete until its features meet the [Definition of Done](ACCEPTANCE_CRITERIA.md). The current phase and what's done within it is tracked in [IMPLEMENTATION_STATUS.md](IMPLEMENTATION_STATUS.md) — that file is updated after every meaningful milestone, not just at phase boundaries.

## Before changing code

1. Read [IMPLEMENTATION_STATUS.md](IMPLEMENTATION_STATUS.md) to see what already exists and what's verified.
2. Read [DECISIONS.md](DECISIONS.md) for the reasoning behind the current architecture — don't replace working architecture without a documented reason (CLAUDE.md §G16).
3. Inspect the actual code before modifying it — don't assume from documentation alone, since docs can lag.

## While changing code

- Keep changes scoped to one module/concern at a time where possible, matching the modular architecture in [ARCHITECTURE.md](ARCHITECTURE.md).
- Validate input, check permissions, handle errors, and add audit logging for any new mutating endpoint — see [SECURITY.md](SECURITY.md) for the existing patterns (`ValidationPipe`, guards, `AuditInterceptor`) to reuse rather than reinvent.
- Never use floating-point arithmetic for money — go through `backend/src/common/money/money.ts`.
- Never fabricate data to make a UI look finished. An unbuilt section states plainly that it isn't built yet (see `NotYetAvailableCard` / `ModulePlaceholderScreen` in the Flutter app) rather than showing invented numbers or a non-functional button.

## After changing code

Run the relevant verification before considering work done:

```bash
# Backend
cd backend
npx tsc --noEmit     # type-check
npm test             # unit tests
npx prisma generate  # if schema.prisma changed

# Flutter
cd app
flutter analyze
flutter test
```

For UI changes, actually run the app (`flutter run -d windows` or `-d chrome`) and exercise the feature — static checks verify correctness, not that a feature works as intended.

Then update:
- [IMPLEMENTATION_STATUS.md](IMPLEMENTATION_STATUS.md) with verified (not assumed) progress.
- [DECISIONS.md](DECISIONS.md) if a non-obvious technical choice was made.
- The relevant module document (e.g. [API_CONTRACTS.md](API_CONTRACTS.md), [DATA_MODEL.md](DATA_MODEL.md)) if the change affects it.

## Git

- Commits happen only when explicitly requested.
- Commit messages describe *why*, not just *what* — the diff already shows what changed.
- No destructive git operations (force-push, hard reset, history rewrite) without explicit confirmation.

## When blocked

Per CLAUDE.md §5: proceed autonomously through anything resolvable from the code, the task, or sensible defaults. Stop and ask only for a genuine external dependency (e.g. a missing service credential), a business decision only the project owner can make, or before a destructive/hard-to-reverse action. [IMPLEMENTATION_STATUS.md](IMPLEMENTATION_STATUS.md)'s "Blockers" section is where open items like this are tracked.
