# Teacher Dashboard Consolidation — Design

**Date:** 2026-08-20
**Status:** Approved

## Problem

The Teacher Dashboard (`lib/features/dashboard/screens/teacher_dashboard.dart`) currently
splits teacher functionality across 5 bottom-nav destinations: Home, Class, Activities,
Analytics, Profile. The user wants a simpler, more "admin panel"-style experience: fewer
nav destinations, everything reachable from one page.

## Goal

Consolidate Class, Activities, and Analytics into collapsible sections on the Home tab.
Bottom nav shrinks to **Home + Profile** only. No underlying capability is removed —
teachers can still add learners, assign activities, and view class analytics, just from
one page instead of three separate tabs.

## Non-goals

- No change to `firestore.rules` or any Firestore query scoping. Teachers remain scoped
  to `linkedTeacherUids` exactly as today — this is a navigation/layout change only.
- No change to the Learner or Parent dashboards.
- No change to the internal logic of `_ClassTab`, `_ActivitiesTab`, or
  `ClassAnalyticsScreen` — they are relocated, not rewritten.

## Design

### Navigation

`_TeacherDashboardState.build()`'s `destinations` list shrinks from 5 entries to 2:

```dart
destinations: const [
  ResponsiveDestination(icon: Icons.home_outlined, activeIcon: Icons.home, label: 'Home'),
  ResponsiveDestination(icon: Icons.person_outline, activeIcon: Icons.person, label: 'Profile'),
],
```

The body's children list shrinks from `[_HomeTab, _ClassTab, _ActivitiesTab,
ClassAnalyticsScreen, _ProfileTab]` to `[_HomeTab, _ProfileTab]`. `_selectedIndex` stays
an `int` (0/1) for minimal diff against `ResponsiveScaffold`'s existing API.

The existing AppBar quick actions (Add Learner icon, Create Activity icon) stay on the
Home tab's AppBar unchanged — they already trigger `_showAddLearnerDialog` /
`_showCreateActivitySheet`, which remain valid since the sections they affect are still
present, just lower on the same page.

### New widget: `_CollapsibleSection`

A small reusable wrapper around Flutter's `ExpansionTile`, styled to match the existing
card look (`AppColors`, `AppTextStyles`, rounded corners, existing spacing rhythm used by
`_StatsGrid` and friends). Signature:

```dart
_CollapsibleSection({
  required String title,
  required IconData icon,
  Widget? trailing,       // e.g. a count badge
  required Widget child,
  bool initiallyExpanded = false,
})
```

### `_HomeTab` layout (top to bottom)

1. Existing header (date, "Class Overview", learner count badge) — unchanged.
2. Existing `_StatsGrid` — unchanged.
3. Existing "Recent Class Activity" — unchanged.
4. **New:** `_CollapsibleSection(title: 'Learners', icon: Icons.group, ...)` wrapping the
   existing `_ClassTab`'s body content (learner list/grid). `_ClassTab` itself becomes a
   plain content widget (no longer a full "tab" concept) — same widget, just mounted here
   instead of as an `IndexedStack` child.
5. **New:** `_CollapsibleSection(title: 'Activities', icon: Icons.assignment, ...)`
   wrapping `_ActivitiesTab`'s existing content the same way.
6. **New:** `_CollapsibleSection(title: 'Analytics', icon: Icons.analytics, ...)` wrapping
   `ClassAnalyticsScreen`'s existing content the same way (it already has no Scaffold/AppBar
   of its own, so it drops in directly).

All three sections start collapsed (`initiallyExpanded: false`) so the page opens compact;
each expands independently on tap.

### Data flow / security

Unchanged. Each section keeps whatever `StreamBuilder`/Firestore query it already used —
same `teacherUid`, same `firestore.rules`. This is a pure UI relocation.

### Error handling

Each section's existing loading/empty/error UI stays local to that section — one section
erroring (e.g. Analytics failing to load class data) doesn't block the others from
rendering, since they remain independent widgets/streams, just co-located on one page
instead of separate `IndexedStack` entries.

### Testing

No existing test file references `TeacherDashboard`, `ClassAnalyticsScreen`, `_ClassTab`,
or `_ActivitiesTab` (`grep -rl` across `test/` returns nothing), so there is no existing
coverage to update. Verification is: `flutter analyze` (0 new issues), `flutter test`
(324/324 still green — this change touches no code any existing test exercises), and a
manual click-through confirming Home renders all three sections collapsed, each expands
correctly, and the Add Learner / Create Activity actions still work.
