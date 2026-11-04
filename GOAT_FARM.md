# Goat Farm Management (Phase 06)

**Status: core built and verified live (2026-11-04).** See [IMPLEMENTATION_STATUS.md](IMPLEMENTATION_STATUS.md) for the verification record.

## What exists

- **Animals** (`backend/src/modules/farm/animals/`): profile, pedigree (sire must be male, dam female, same workspace, never self), ownership, dietary restrictions, lifecycle (ACTIVE → SOLD/DECEASED, one-way, history kept) separate from health status.
- **Health & vet records** with medicine, dosage, veterinarian and next-due date; **weights** as exact decimals.
- **Breeding** (`farm/breeding/`): mating (natural/AI; farm buck or outside sire) → pregnant / not pregnant / aborted → kidding. Expected kidding = mating + 150 days by default (`gestation.util.ts`). A doe can have only one open record. Kidding registers live kids as new animals in one transaction.
- **Overview & schedule** (`farm/overview/`): herd counts, pregnant count, health follow-ups due within 30 days (overdue flagged; resolved once a newer record of the same type exists), expected kiddings.
- **Finances**: farm money never lives in this module. Purchases, sales, feed and vet costs are ordinary income/expense entries tagged with `animalId`; each animal's page shows income/expense/net from those entries.
- **Flutter**: `app/lib/features/goat_farm/` (Goat Farm screen with Herd/Breeding/Schedule tabs, animal detail, dialogs) and the dashboard Goat Farm card.
- **Permissions**: any member reads; OWNER/ADMIN/MANAGER/STAFF record; OWNER/ADMIN/MANAGER mark exits and delete health records. All writes are audit-logged.

## Not yet built

- Full profile editing in the UI (API supports it).
- Feed inventory and rations (costs are tracked via tagged expenses).
- Automatic reminders/push notifications — the schedule exists; delivery is Phase 09 ([NOTIFICATIONS.md](NOTIFICATIONS.md)).
- Ready-made record templates ([TEMPLATES.md](TEMPLATES.md)) and WhatsApp commands ([WHATSAPP_INTEGRATION.md](WHATSAPP_INTEGRATION.md)) — any imported record must stay a draft until a human verifies it.
- Urdu strings for the Goat Farm screens.
