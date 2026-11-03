# Start Here

For anyone — human or AI assistant — picking up this project fresh.

## Read these first, in order

1. [CLAUDE.md](CLAUDE.md) — the governing development standard for this repository. Non-negotiable (language policy, financial accuracy, security, execution discipline).
2. [IMPLEMENTATION_STATUS.md](IMPLEMENTATION_STATUS.md) — what is actually built and verified *right now*, and any current blockers. This is the single most important file to check before assuming anything is done.
3. [DECISIONS.md](DECISIONS.md) — why the stack and major design choices are what they are. Don't replace working architecture without reading the reasoning here first.
4. [README.md](README.md) — how to actually run the backend and the Flutter app.

## If resuming development

- Check [IMPLEMENTATION_STATUS.md](IMPLEMENTATION_STATUS.md)'s "Blockers" section first — it names anything that needs a human decision or external setup (e.g. a database connection) before work can continue on certain fronts.
- Follow [WORKFLOW.md](WORKFLOW.md) for the verify-before-done discipline (type-check, tests, actually running the app) expected on every change.
- Update [IMPLEMENTATION_STATUS.md](IMPLEMENTATION_STATUS.md) after any verified milestone — don't let it go stale.

## Project identity

This repository is internally named "Obaid Goat Farm" (the folder/workspace name) but the product itself is branded **Tangent Smart Manager** (see the reference dashboard image and the Flutter app's title) — a general-purpose financial and business management platform for which the goat farm is one module among several, not the whole product. Both names refer to the same project.

## Original scope prompt

The full 15-phase master development workflow that defines this project's complete intended scope is preserved in CLAUDE.md's accompanying instructions (provided at project kickoff). [REQUIREMENTS.md](REQUIREMENTS.md) and [FEATURES.md](FEATURES.md) restate that scope as checkable, status-tracked items — prefer those for day-to-day reference since they stay current with actual progress.
