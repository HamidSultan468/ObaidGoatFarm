# UI/UX Principles

Complements [DESIGN.md](DESIGN.md) (visual system) with behavioral and structural UX guidance for this platform.

## Core principles

1. **Simple experience, enterprise-grade substance** (CLAUDE.md's final objective). A user managing a small goat farm and a user managing multiple business accounts should both find the interface approachable — complexity is handled through progressive disclosure (drill-down screens, scoped modules), not by hiding capability.
2. **Every control does something real.** No disabled-looking fake buttons, no silently-ignored taps. An unbuilt feature says so explicitly (see [DESIGN.md](DESIGN.md)'s honest-state pattern) rather than pretending to work.
3. **Numbers are never invented.** A zero state is shown as zero, not as a plausible-looking fake figure. This is a hard rule, not a style preference — see CLAUDE.md's prohibition on mock data in production modules.
4. **Financial actions are deliberate.** Posting a transaction, reversing an entry, or any other consequential financial action requires explicit confirmation and is never a single accidental tap away (this applies once Phase 05 is built).

## Navigation structure

- **Sidebar** (persistent on desktop/tablet widths): one entry per top-level module — Dashboard, Household Accounts, My Records, Goat Farm, Land Records, Inventory, Customers & Suppliers, Bank & Accounts, Reports & Analytics, AI Assistant, Notifications, Settings. Matches the approved reference design.
- **Top bar**: global search (not yet functional), notifications, account menu (profile, logout).
- On narrow (phone-width) viewports, the sidebar is expected to collapse into a bottom nav or drawer — not yet implemented or tested; current layout has only been verified at desktop width (Windows/web). This is a known gap, tracked in [FEATURES.md](FEATURES.md) (FR-4.7).

## Platform-specific considerations

- **Windows/Web**: primary development/testing targets right now (both runnable on the current dev machine). Mouse/keyboard-first interactions (hover states, right-click where relevant).
- **Android/iOS**: touch-first — tap targets, gesture navigation, platform-appropriate back behavior. Not yet tested on a device or emulator (Android SDK present but `cmdline-tools` missing; iOS needs macOS). Flagged as untested, not assumed to work.
- **Responsive breakpoints**: a single `LayoutBuilder`-based breakpoint (900px) currently distinguishes "wide" from "narrow" layouts in the dashboard. This will likely need refinement (tablet vs. phone vs. desktop, not just wide vs. narrow) as more screens are built.

## Localization & RTL

English is left-to-right; Urdu is right-to-left. Flutter's `Directionality` follows the active locale automatically once Urdu string resources exist (not yet written — see [FEATURES.md](FEATURES.md)). When Urdu is added, every screen needs a visual RTL pass, not just a translation pass — icon mirroring, text alignment, and reading-order assumptions in custom layouts (like the sidebar) all need checking.

## Accessibility

Not yet audited. Material 3's defaults (via `useMaterial3: true`) provide a reasonable baseline (contrast-aware color roles, standard touch target sizing), but no explicit accessibility pass (screen reader labels, focus order, contrast verification against the custom navy/KPI palette) has been done yet.
