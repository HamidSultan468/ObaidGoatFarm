# Accounting Module (Phase 05 — Financial Management Core)

**Status: ✅ built and verified live against a real PostgreSQL database**, including every Flutter screen named below (Budgets and Recurring Templates as of 2026-11-05). See [IMPLEMENTATION_STATUS.md](IMPLEMENTATION_STATUS.md) for the verification boundary.

## What's built

### The ledger engine (`backend/src/modules/accounting/ledger/`)
- `LedgerService.postEntry()` — the single place every financial record in the platform posts through. Validates that lines balance to exactly zero (`assertBalanced`, pure and unit-tested — 6/6 tests passing, including a proof that `0.10 + 0.20 - 0.30` balances exactly under `Money` where it wouldn't under native floats), then creates an immutable `JournalEntry` + `JournalLine` rows.
- `LedgerService.reverseEntry()` — the only way to correct a posted entry: creates a new entry with every line negated, linked via `reversalOfId`. A posted entry is never edited or deleted (CLAUDE.md §3).
- Approvals: if a workspace sets `approvalThreshold`, an entry whose debit total meets or exceeds it is created `PENDING_APPROVAL` instead of `POSTED`, until `approveEntry`/`rejectEntry` (OWNER/ADMIN only) resolves it.

### Chart of accounts (`accounts/`)
- A default chart of accounts (Cash, Bank, Accounts Receivable, Accounts Payable, Owner's Equity, Sales Income, General Expense) is seeded automatically when a workspace is created (`WorkspacesService.create` → `AccountsService.seedDefaultChartOfAccounts`) — so the first transaction always has somewhere real to post to.
- Custom accounts can be added; system-seeded accounts can be deactivated but not deleted.
- Per-account balance (`GET .../accounts/:id/balance`) and a full chronological statement with running balance (`GET .../accounts/:id/statement`) — the latter is also a "cashbook" when filtered to a CASH/BANK account.

### Transactions (`transactions/`)
Three guided entry points that construct a correct two-line journal entry without the user needing to understand debits/credits directly:
- **Record Income** — debits the cash/bank account, credits an income account; optionally tags a customer `Contact` and issues a QR-verifiable receipt code.
- **Record Expense** — debits an expense account, credits the cash/bank account; optionally tags a supplier `Contact`.
- **Transfer** — moves money between two of the workspace's own accounts.
- A generic **manual entry** endpoint remains for anything these three don't cover (arbitrary multi-line entries), still going through the same balance validation.

### Customer & supplier ledgers (`contacts/`)
A `Contact` (CUSTOMER/SUPPLIER/BOTH) has no parallel bookkeeping of its own — its "ledger" (`GET .../contacts/:id/ledger`) is simply every posted journal entry tagged with that contact, in order, with a running net total.

### Reports (`reports/`)
- **Trial balance** — every account with its posted debit/credit balance; the platform asserts the whole set sums to zero.
- **Profit & Loss** — income minus expense over a date range (defaults to the current calendar month). This is what powers the dashboard's Total Income / Total Expenses / Net Profit KPI cards — real data, not the illustrative numbers from the original reference mockup.
- **Cash flow** — intentionally simplified: net change in CASH/BANK-kind accounts over a period, with total inflows/outflows. A full operating/investing/financing breakdown is not implemented — see "Known simplifications" below.
- **Liquid balance** — sum of all CASH/BANK account balances; powers the dashboard's Bank Balance KPI.

### Budgets (`budgets/`)
A budget is an amount for one account over one period; `GET .../budgets/:id/progress` compares it to actual posted activity on that account within the same period. Flutter: a Budgets tab (Bank & Accounts screen) shows each budget as a progress bar against actual spend, with the bar turning red past 100%.

### Recurring transactions (`recurring/`)
A reusable template (amount, accounts, frequency) with a `run-now` endpoint that posts through the same `LedgerService` and advances `nextRunDate`. **There is no unattended scheduler** — nothing posts automatically yet; see "Known simplifications." Flutter: a Recurring tab (Bank & Accounts screen) lists templates with an active/inactive switch and a manual "Run now" button.

### Bank reconciliation (`accounts/.../lines/:lineId/reconcile`)
Any posted journal line can be flagged (or unflagged) as matched against a real bank statement — `JournalLine.reconciledAt`, set/cleared via `PATCH .../accounts/:accountId/lines/:lineId/reconcile`, OWNER/ADMIN/MANAGER only. This never changes the amount or the entry itself, only the checklist flag. Flutter: the Account Statement sheet shows a checkbox per line and a "X of Y reconciled" count; a failed toggle rolls back to the previous state instead of leaving the UI claiming something the server rejected.

### QR-verified receipts (`receipts/`)
An income entry can request a `verificationCode` (shown in the reference dashboard mockup as "QR Verified Receipt"). `GET /receipts/verify/:code` is **public** (no auth) — anyone holding the printed/scanned receipt can confirm it's genuine, without exposing anything beyond the amount, memo, document number, date, and issuing workspace's name.

## Known simplifications (honest, not hidden)

- **Cash flow** is "net CASH/BANK movement," not a categorized operating/investing/financing statement.
- **Recurring transactions** require an explicit "run now" call — no cron/job-scheduler infrastructure exists in this environment yet to run them unattended.
- **Invoices** are not a first-class document yet — `INVOICE`/`PAYMENT_RECEIVED`/`PAYMENT_MADE` exist as `JournalEntryType` values for future use, but only Income/Expense/Transfer/Manual have dedicated endpoints today.
- **Contact attribution** is entry-level only (one contact per journal entry), not per-line — a split transaction across multiple customers in one entry isn't representable yet.
- **Approval routing** is a single global per-workspace threshold, not configurable per account/category or per approver chain.

## Verification status

- ✅ `assertBalanced` — 6/6 unit tests, DB-free, including the floating-point-failure proof pattern established by `Money`.
- ✅ Whole-backend type-check clean through every file in this module.
- ✅ Flutter: `flutter analyze` 0 issues; widget tests for Budgets/Recurring (4) plus the existing accounting/l10n suites.
- ✅ Verified live against a real PostgreSQL database — every endpoint in this module, including the 2026-11-05 additions (budgets progress math, recurring run-now balance posting and next-run-date advance, reconciliation toggling and its tenant/account-ownership check) — see `backend/scripts/e2e/completeness.e2e.mjs` and IMPLEMENTATION_STATUS.md.
