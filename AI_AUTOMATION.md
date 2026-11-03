# AI Integration (Phase 11, AI half)

**Status: not started.** The dashboard reference mockup shows an "AI Assistant" sidebar entry and a "Voice Command" quick action; both exist in the current Flutter app only as honest placeholders.

## Planned scope (from CLAUDE.md §Phase 11)

- Support for multiple AI provider configurations (not locked to a single vendor)
- Encrypted, securely managed API credentials
- AI-powered categorization, summaries, suggestions, OCR assistance
- Provider selection, usage quotas, usage monitoring, failover between providers
- Manual application functionality must keep working if AI services fail — AI is an enhancement, never a dependency for core features

## The non-negotiable rule

Per CLAUDE.md §3/§11/Global Rule 8: **AI-generated data never posts automatically.** Any AI output that would create or modify a record (a categorized expense, an OCR-extracted receipt, a suggested journal entry) is a draft requiring explicit human review and confirmation before it becomes a real record — the same rule that applies to [WHATSAPP_INTEGRATION.md](WHATSAPP_INTEGRATION.md) imports.

## Notes for when this phase starts

- Provider credentials belong in an encrypted-at-rest table, never in plain config or logs — consistent with [SECURITY.md](SECURITY.md)'s existing handling of refresh tokens (hashed) and passwords (bcrypt).
- A provider-agnostic interface (similar to the adapter pattern planned for [BACKUP_STORAGE.md](BACKUP_STORAGE.md)) keeps the system from being locked into one AI vendor's API shape.
- "Failover between providers" implies the design should treat providers as a prioritized list, not a single configured endpoint.
