# Documents & Record Management (Phase 08)

**Status: not started.**

## Planned scope (from CLAUDE.md §Phase 08)

- Organized, module-specific data folders (goat farm documents separate from land documents, separate from financial receipts, etc.)
- Multiple images/documents per record
- Document scanning and OCR extraction
- Voice-to-record draft creation
- Ready-made and custom templates (see [TEMPLATES.md](TEMPLATES.md))
- Universal "Add New" functionality (a single entry point that routes to the right record type)
- Record history, search, filtering, exports
- Private, access-controlled file storage

## Notes for when this phase starts

- File storage backend (local disk vs. S3-compatible object storage vs. the cloud providers in [BACKUP_STORAGE.md](BACKUP_STORAGE.md)) needs a decision — not yet made.
- OCR and voice-to-draft likely depend on the AI provider integration in [AI_AUTOMATION.md](AI_AUTOMATION.md) (Phase 11); per CLAUDE.md, any AI-extracted data is a *draft* requiring human review before it can be saved as a real record — never auto-posted, same rule as WhatsApp imports.
- Access control here follows the same `WorkspaceGuard`/`RolesGuard` pattern already established for every other tenant-scoped resource — see [SECURITY.md](SECURITY.md).
