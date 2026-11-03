# Accounting Module (Phase 05 — Financial Management)

**Status: not started.** This document records the planned scope so Phase 05 has a clear starting brief; it is not a spec for anything built yet. See [IMPLEMENTATION_STATUS.md](IMPLEMENTATION_STATUS.md) for current state and [DATA_MODEL.md](DATA_MODEL.md) for the minimal ledger stub that already exists (`Account`, `JournalEntry`, `JournalLine`).

## What exists today

A minimal double-entry skeleton only, built to back the dashboard's honest zero-state KPI cards:
- `Account` (chart of accounts, typed `ASSET`/`LIABILITY`/`EQUITY`/`INCOME`/`EXPENSE`)
- `JournalEntry` (a postable, reversible unit)
- `JournalLine` (signed `Decimal` amount against one account; a valid entry's lines sum to exactly zero)

No endpoints exist to create accounts or post entries yet. No UI exists for any of this yet.

## Planned scope (from CLAUDE.md §Phase 05)

- Income, expenses, transfers, receipts, invoices, payments
- Personal, household, shared, and business account types
- Customer and supplier ledgers
- Cashbooks, bank accounts, account statements
- Profit/loss, cash flow, reconciliation, and financial reports
- Recurring transactions, budgets, approvals, reminders
- QR-based receipt verification (shown in the reference dashboard mockup)
- Immutable posted records — corrections via reversal only, enforced the same way the schema already supports (`JournalEntry.reversalOfId`)

## Design constraints carried over from the foundation

- All amounts go through `backend/src/common/money/money.ts` — never raw `number`/`Float`.
- Every posting endpoint needs: input validation, a workspace-scoped permission check, audit logging, and a test that proves an unbalanced entry is rejected (see [TESTING_QA.md](TESTING_QA.md)'s acceptance criteria pattern).
- A workspace-creation flow must exist before this module is meaningfully usable — currently a tracked gap (see [IMPLEMENTATION_STATUS.md](IMPLEMENTATION_STATUS.md)).
