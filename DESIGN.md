# Design System

Source of truth for the implementation: `app/lib/core/theme/app_colors.dart` and `app_theme.dart`. This document explains the design language; those files are authoritative for exact values. Derived from the approved reference mockup (`Tangent Smart Manager Dashboard.png`), named "Modern Blue" in that mockup's own settings panel.

## Color palette

| Token | Light | Dark | Use |
|---|---|---|---|
| `sidebarNavy` | `#101C3A` | — | Sidebar background |
| `sidebarNavyActive` | `#1E3A6D` | — | Active sidebar item |
| `primaryBlue` | `#2F6FED` | — | Primary actions, links, focus states |
| `incomeGreen` | `#22A559` | — | Income KPI, positive values |
| `expenseRed` | `#E5484D` | — | Expense KPI, destructive actions, errors |
| `profitBlue` | `#3B82F6` | — | Profit KPI |
| `balancePurple` | `#8B5CF6` | — | Bank balance KPI |
| `surface` | `#F4F6FB` | `#0B1326` | Page background |
| `card` | `#FFFFFF` | `#151F38` | Card/panel background |
| `border` | `#E3E8F0` | `#26304D` | Dividers, card outlines |
| `textPrimary` | `#111827` | `#F3F4F6` | Primary text |
| `textSecondary` | `#6B7280` | `#9CA3AF` | Secondary/muted text |

Both a light and dark theme exist (`AppTheme.light()` / `AppTheme.dark()`), selected automatically by system preference (`themeMode: ThemeMode.system`) — matching the reference mockup's "Light Mode" toggle intent, though a manual in-app toggle isn't built yet (tracked in [FEATURES.md](FEATURES.md)).

## Typography

Material 3 default type scale, weighted toward bold headings (`FontWeight.w700` for headlines/titles) to match the reference mockup's confident, data-dense style. No custom font is bundled yet — the platform default (Roboto/San Francisco/Segoe depending on OS) is used.

## Layout

- **Sidebar**: fixed 248px width, dark navy, icon + label navigation items, active item highlighted with a lighter navy pill.
- **Top bar**: 72px height, search field, notification bell, user avatar menu.
- **Content grid**: KPI cards in a responsive grid (4 columns ≥900px wide, 2 columns below that — see `DashboardScreen`'s `LayoutBuilder` usage). Cards use 16px corner radius, no elevation (flat, bordered style) to match the mockup's clean card aesthetic.
- **Spacing**: 24px page padding, 16px gaps between cards — kept as literal values in the widgets for now; promoting these to named spacing tokens is a reasonable follow-up once more screens exist and the pattern repeats enough to be worth abstracting.

## Iconography

Material Symbols (rounded variant, e.g. `Icons.dashboard_rounded`) throughout, matching the reference mockup's rounded icon style.

## Honest-state design pattern

Two widgets enforce CLAUDE.md's "no mock functionality" rule at the design level, used instead of fabricating data or leaving a dead control:
- `NotYetAvailableCard` — for a dashboard section whose backend module doesn't exist yet; states which phase will build it.
- `ModulePlaceholderScreen` — for a sidebar destination whose module doesn't exist yet; the navigation is real, the screen says plainly what's missing.

Any new screen for an unbuilt feature should use one of these rather than a static mock or an unresponsive button.
