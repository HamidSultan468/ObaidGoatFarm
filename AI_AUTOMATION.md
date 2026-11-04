# AI Integration (Phase 11, AI half)

**Status: built (2026-11-04); not yet verified with a real API key.**

## The non-negotiable rule

AI output never becomes a record by itself. It is stored as a **draft**; a person reviews, can correct it, and approves. Approval runs the same validated services as manual entry. Manual entry keeps working if AI is not set up or fails.

## What exists

- **Provider settings** (`backend/src/modules/ai/`, Settings → AI assistant): Anthropic API keys per workspace, encrypted (only a 4-character hint is shown), model (`claude-opus-5-5` default; Sonnet/Haiku 5.5 available), priority order for failover, monthly request limit, connection test, monthly usage (requests, failures, tokens).
- **Drafts from text:** English, Urdu or Roman Urdu ("2 bakriyan 90 hazar me bechi") → income, expense, animal health, or animal weight draft.
- **Drafts from receipts:** a photo or PDF in Documents → expense (or income) draft.
- **How a call works:** official `@anthropic-ai/sdk`, structured JSON output (schema in `extraction.ts`), effort `low`, server-side refusal fallback. The workspace's accounts, animals, land and contacts are given to the model so it can choose real ids; the backend then re-checks every id and account type and drops anything invalid with a warning.
- **AI Assistant screen:** create drafts, review/edit/approve/reject, see approved and rejected history.

## Verified so far

- Real requests to Anthropic with an invalid key: rejection handled, failover to the next provider, usage logged, monthly limit respected.
- The full approval path with test drafts (ledger posting, double/concurrent approval, corrections, tenant isolation).

## Not yet built / verified

- Successful extraction with a real key (add one in Settings → AI assistant, then try the AI Assistant).
- Voice notes (need speech-to-text), other AI vendors (adapter point: `providers/`), AI summaries and suggestions.
