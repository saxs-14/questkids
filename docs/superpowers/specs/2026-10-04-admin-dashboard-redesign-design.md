# Admin Dashboard Visual Redesign — Design

**Date:** 2026-10-04
**Status:** Design validated in Figma, pending written-spec review

## Problem

`lib/features/dashboard/screens/admin_dashboard.dart` (4 tabs: Overview, Users, Safety,
Operations) works functionally but looks like a bare Material scaffold — plain white
cards, default `AppBar`, no visual identity. The admin using it wanted it to look like a
"powerful gaming admin" command center instead.

## Goal

Redesign the **visual presentation** of all 4 existing admin tabs in a dark "command
center" style, using the real data shapes the dashboard already surfaces (stat counts,
user rows, AI safety reports, static operational readouts). No new admin capability is
added — every control and data source that exists today still exists, just restyled.

## Non-goals

- No new backend functionality. The Operations tab's four sections (Content,
  Gamification, Security, System Health) stay static readouts — turning them into live
  controls was explicitly ruled out of scope for this pass.
- No change to `AdminService`, Firestore queries, or any security rule.
- No change to role-change/disable logic on the Users tab, or to the Resolve action on
  Safety reports — their behavior is unchanged, only their visual container changes.
- No 3D/Unity-style graphics — this is a 2D dark SaaS-console treatment, not a game HUD.

## Visual direction

"Premium Dark" command-center style, chosen over two alternatives (Neon Arcade, Tactical
HUD) during brainstorming — built on QuestKids' own brand purple rather than generic
neon, so it reads as a premium console rather than an arcade cabinet.

### Color tokens (validated in Figma as a variable collection)

| Token | Hex | Use |
|---|---|---|
| `bg/page` | `#0F0D18` | Screen background |
| `bg/card-top` / `bg/card-bottom` | `#211C33` / `#191625` | Card gradient fill |
| `border/glow` | `#8C6EFF` (35% opacity on cards) | Card borders |
| `text/primary` | `#FFFFFF` | Headings, primary values |
| `text/accent` | `#B7A6FF` | Eyebrow labels, section labels |
| `text/secondary` | `#9B93B5` | Body/secondary text |
| `brand/primary` | `#5C35F5` | Primary buttons (e.g. Resolve) |
| `status/online` | `#4ADE80` | "All systems operational" status dot |

Layout: 1280px reference width, 40px side padding, consistent "QUESTKIDS ADMIN" eyebrow +
page title header pattern repeated on every tab.

## Per-tab design

### Overview
Top bar with eyebrow label + "Platform Overview" title + green "All systems operational"
status pill. 6-card stat grid (Users, Parents, Children, Admins, Activities, AI Reports)
— same counts `AdminService.getOverviewCounts()` already provides — each card a dark
gradient fill with a purple-glow border. An "Admin Responsibilities" bullet card below,
replacing the old plain text block.

### Users
"User Management" header, subtitle, a styled search bar (visual only — wraps the
existing search behavior), and user rows (avatar circle, name + email, color-coded role
badge: admin/parent/learner each a distinct accent at reduced fill opacity) sourced from
`AdminService.watchUsers()`. Existing role-change/disable actions remain, restyled to
match (not redesigned in Figma at the interaction level — implementation maps them onto
the new row component).

### Safety
"Child Safety & AI Review" header. Each AI report from `watchAiReports()` becomes a card
with a severity-colored left accent (amber/red) and flag icon, title + detail text, and a
"Resolve" button in brand purple — same action as today, restyled container.

### Operations
"Platform Operations" header with subtitle clarifying these are status readouts, not live
controls. The four existing static sections (Content, Gamification, Security, System
Health) become individual dark cards with an accent-colored section label and bullet
list — same copy as today, reformatted from plain text blocks into the card system used
elsewhere.

## Figma reference

File: `z1g8doKhAyTdO2M5XjRW3V` ("QuestKids Admin Console"),
https://www.figma.com/design/z1g8doKhAyTdO2M5XjRW3V

All 4 screens built and screenshot-validated with no visual defects (Overview required
two fixes during construction — a default-white autolayout fill hiding text, and a
mis-set autolayout sizing axis collapsing the stat grid — both fixed and re-verified;
Users, Safety, and Operations were clean on first render).

## Implementation approach (high level — detail goes in the implementation plan)

- Add dark theme tokens as `AdminTheme` constants (or extend `AppColors`/`AppTheme`)
  matching the Figma variable collection above, scoped to the admin dashboard only —
  this redesign does not change the Learner/Parent/Teacher theme.
- Introduce shared widgets: `_AdminStatCard`, `_AdminSectionHeader`, `_AdminUserRow`,
  `_AdminReportCard`, `_AdminOperationsCard` — each a thin visual wrapper around existing
  data, not a new data source.
- Existing `StreamBuilder`/`FutureBuilder` wiring to `AdminService` is preserved
  unchanged; only the `itemBuilder`/child widgets change.
- `flutter analyze` and `flutter test` must stay green; no new engine or rules changes
  are touched by this work, so Definition of Done items 5–6 (catalog invariants, rules
  emulator validation) don't apply here.

## Open questions for spec review

None outstanding — all four tabs are built, visually approved in direction during
brainstorming, and screenshot-verified. This spec documents what was approved so the
follow-up implementation plan (via `writing-plans`) has a fixed reference.
