# Goat Farm Management (Phase 06)

**Status: not started.** This document records planned scope so Phase 06 has a clear starting brief. See [IMPLEMENTATION_STATUS.md](IMPLEMENTATION_STATUS.md) for current state.

## What exists today

A minimal `Animal` stub only (`id`, `workspaceId`, `tagNumber`, `healthStatus`), built solely so the dashboard's "Total Goats" widget can query a real (currently zero) count instead of showing fabricated data. No profile detail, no endpoints beyond the raw table, no UI.

## Planned scope (from CLAUDE.md §Phase 06)

- A separate profile per animal, with a unique identification number
- Multiple photographs and document attachments per animal
- Breed, age, gender, weight, ownership, and pedigree details
- Health and veterinary records
- Medication, vaccination, and deworming schedules
- Breeding, mating, pregnancy, and expected kidding records
- Birth, offspring, complications, and growth tracking
- Feed management and dietary restrictions
- Veterinarian schedules and automatic reminders
- Ready-made templates for every record type (see [TEMPLATES.md](TEMPLATES.md))
- Manual entry and authorized WhatsApp commands (see [WHATSAPP_INTEGRATION.md](WHATSAPP_INTEGRATION.md)) — with mandatory human verification before any imported record is saved, per CLAUDE.md's rule that AI/WhatsApp imports never auto-post

## Notes for when this phase starts

- Photo/document attachments depend on [DOCUMENTS_MEDIA.md](DOCUMENTS_MEDIA.md) (Phase 08) being usable, or at least a minimal file-storage path existing.
- Reminders (vaccination, vet schedules) depend on [NOTIFICATIONS.md](NOTIFICATIONS.md) (Phase 09).
- This is the project's namesake module — worth prioritizing once Phase 05's core ledger exists, since farm expenses/income should post against the real accounting engine rather than existing in isolation.
