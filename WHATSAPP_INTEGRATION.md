# WhatsApp Integration (Phase 11, WhatsApp half)

**Status: not started.**

## Planned scope (from CLAUDE.md §Phase 11)

- Official WhatsApp Business messaging integration (not an unofficial/reverse-engineered client — "official" is explicit in CLAUDE.md)
- Authorized users can submit voice and text commands via WhatsApp
- Commands convert into reviewable record drafts — never post directly
- Confirmation required for any consequential action
- Manual application functionality remains available if WhatsApp is unavailable

## The non-negotiable rule

Same as [AI_AUTOMATION.md](AI_AUTOMATION.md): a WhatsApp-submitted command becomes a **draft** record requiring human verification before it's saved as real data (CLAUDE.md §6 Phase 06, §11, Global Rule 8). This applies with no exceptions — including for the Super Admin Owner.

## Notes for when this phase starts

- Requires a registered WhatsApp Business Platform account (Meta) and phone number — an external dependency/business decision for the project owner, not something to set up unilaterally.
- "Authorized users" implies a mapping from a WhatsApp phone number to a platform `User` — needs a verification/linking flow before any command from that number is trusted.
- Voice commands likely route through the same AI transcription pipeline as [AI_AUTOMATION.md](AI_AUTOMATION.md), rather than a separate implementation.
