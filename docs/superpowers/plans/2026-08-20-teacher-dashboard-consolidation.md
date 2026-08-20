# Teacher Dashboard Consolidation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Consolidate the Teacher Dashboard's Class, Activities, and Analytics tabs into three collapsible sections on one Home page, shrinking the bottom nav from 5 destinations to 2 (Home, Profile).

**Architecture:** `_TeacherDashboardState` keeps its existing `ResponsiveScaffold` + `IndexedStack` structure but with only `[_HomeTab, _ProfileTab]` as children. `_HomeTab` gains three new `_CollapsibleSection` widgets (built on `ExpansionTile`) that embed the *existing* `_ClassTab`, `_ActivitiesTab`, and `ClassAnalyticsScreen` widgets unchanged in their business logic — only their internal scroll physics change, since they now render inside an outer scrollable instead of filling a full tab page.

**Tech Stack:** Flutter/Dart, `cloud_firestore` (unchanged queries), Flutter's built-in `ExpansionTile`.

## Global Constraints

- No change to `firestore.rules` or any Firestore query — this is UI-only (per spec's Non-goals).
- No change to `_ClassTab`, `_ActivitiesTab`, `ClassAnalyticsScreen`'s data-fetching logic — only scroll-physics wrapper properties, per spec.
- `flutter analyze` must stay at 0 issues (CLAUDE.md Definition of Done §9.1).
- `flutter test` must stay green, 324/324 (CLAUDE.md §9.2) — no test in this repo references these widgets, so none need updating, but the full suite must still pass.
- Commit style: `type(scope): summary`, matching existing repo history (CLAUDE.md §8).

---

## Task 1: Add shrinkWrap-safe embedding support to `_ClassTab` and `_ActivitiesTab`

**Files:**
- Modify: `lib/features/dashboard/screens/teacher_dashboard.dart:761-769` (`_ClassTab`'s `ListView.separated`)
- Modify: `lib/features/dashboard/screens/teacher_dashboard.dart:1304-1312` (`_ActivitiesTab`'s `ListView.separated`)

**Interfaces:**
- Consumes: nothing new.
- Produces: `_ClassTab` and `_ActivitiesTab` remain unchanged widgets (same constructor: `{required String teacherUid}`), now safe to nest inside an outer `SingleChildScrollView` without throwing `RenderBox was not laid out` (a `ListView` with no `shrinkWrap` demands unbounded height from its parent, which an outer scrollable's `Column` cannot provide).

- [ ] **Step 1: Fix `_ClassTab`'s `ListView.separated`**

In `lib/features/dashboard/screens/teacher_dashboard.dart`, find (around line 761):

```dart
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
              itemCount: learners.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, i) => _LearnerCard(
                learner: learners[i],
                onTap: () => _showLearnerDetail(context, learners[i]),
              ),
            );
```

Replace with:

```dart
            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(0, 0, 0, 4),
              itemCount: learners.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, i) => _LearnerCard(
                learner: learners[i],
                onTap: () => _showLearnerDetail(context, learners[i]),
              ),
            );
```

(Padding changed from `fromLTRB(20, 20, 20, 100)` to `fromLTRB(0, 0, 0, 4)` because the 20px horizontal/top padding and 100px FAB-clearance bottom padding no longer apply — the new `_CollapsibleSection` wrapper in Task 4 supplies its own `childrenPadding`, and there is no FAB anymore, per Task 3.)

- [ ] **Step 2: Fix `_ActivitiesTab`'s `ListView.separated`**

In the same file, find (around line 1304):

```dart
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (_, i) {
            final d = docs[i].data() as Map<String, dynamic>;
            return _ActivityTile(data: d, docId: docs[i].id);
          },
        );
```

Replace with:

```dart
        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(0, 0, 0, 4),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (_, i) {
            final d = docs[i].data() as Map<String, dynamic>;
            return _ActivityTile(data: d, docId: docs[i].id);
          },
        );
```

- [ ] **Step 3: Verify no analyzer issues**

Run: `flutter analyze lib/features/dashboard/screens/teacher_dashboard.dart`
Expected: `No issues found!`

- [ ] **Step 4: Commit**

```bash
git add lib/features/dashboard/screens/teacher_dashboard.dart
git commit -m "refactor(teacher): make _ClassTab/_ActivitiesTab lists embeddable in a scrollable parent"
```

---

## Task 2: Make `ClassAnalyticsScreen` embeddable without breaking its existing full-screen usage

**Files:**
- Modify: `lib/features/teacher/screens/class_analytics_screen.dart:19-25` (constructor)
- Modify: `lib/features/teacher/screens/class_analytics_screen.dart:133-137` (the `RefreshIndicator`/`SingleChildScrollView`)

**Interfaces:**
- Consumes: nothing new.
- Produces: `ClassAnalyticsScreen({required String teacherUid, bool embedded = false})`. Existing callers (`teacher_dashboard.dart`'s "Grade Report" Quick Action, which does `Navigator.push(... ClassAnalyticsScreen(teacherUid: teacherUid))`) are unaffected since `embedded` defaults to `false` and that call site isn't touched. Task 4 will pass `embedded: true` when mounting it inside the new Analytics section.

- [ ] **Step 1: Add the `embedded` constructor parameter**

In `lib/features/teacher/screens/class_analytics_screen.dart`, find:

```dart
class ClassAnalyticsScreen extends StatefulWidget {
  final String teacherUid;
  const ClassAnalyticsScreen({super.key, required this.teacherUid});

  @override
  State<ClassAnalyticsScreen> createState() => _ClassAnalyticsScreenState();
}
```

Replace with:

```dart
class ClassAnalyticsScreen extends StatefulWidget {
  final String teacherUid;
  // When true, this screen is mounted inside another scrollable (the
  // Teacher Dashboard's collapsible Analytics section) rather than filling
  // a full page on its own -- its own SingleChildScrollView/RefreshIndicator
  // must not compete for scroll gestures or demand unbounded height from a
  // parent that can't give it. Defaults to false so the existing full-screen
  // "Grade Report" Quick Action (Navigator.push) is unaffected.
  final bool embedded;
  const ClassAnalyticsScreen(
      {super.key, required this.teacherUid, this.embedded = false});

  @override
  State<ClassAnalyticsScreen> createState() => _ClassAnalyticsScreenState();
}
```

- [ ] **Step 2: Make the scroll view conditional on `embedded`**

In the same file, find (around line 133):

```dart
    return RefreshIndicator(
      onRefresh: _load,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
```

Replace with:

```dart
    final content = SingleChildScrollView(
      shrinkWrap: widget.embedded,
      physics: widget.embedded
          ? const NeverScrollableScrollPhysics()
          : const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
```

Then find the matching closing of that widget tree (around line 188-191):

```dart
        ]),
      ),
    );
  }
}
```

Replace with:

```dart
        ]),
    );

    return widget.embedded
        ? content
        : RefreshIndicator(onRefresh: _load, child: content);
  }
}
```

(Pull-to-refresh only makes sense when this screen owns real scroll gesture space, i.e. the non-embedded full-screen case. When embedded, the page-level scroll on `_HomeTab` handles scrolling instead, and the section still refreshes on first expand via `initState`'s existing `_load()` call.)

- [ ] **Step 3: Verify no analyzer issues**

Run: `flutter analyze lib/features/teacher/screens/class_analytics_screen.dart`
Expected: `No issues found!`

- [ ] **Step 4: Commit**

```bash
git add lib/features/teacher/screens/class_analytics_screen.dart
git commit -m "refactor(teacher): add embedded mode to ClassAnalyticsScreen for dashboard consolidation"
```

---

## Task 3: Shrink the Teacher Dashboard's bottom nav to Home + Profile

**Files:**
- Modify: `lib/features/dashboard/screens/teacher_dashboard.dart:65-174` (`_TeacherDashboardState.build()`)
- Modify: `lib/features/dashboard/screens/teacher_dashboard.dart:176-315` (`_showAddLearnerDialog`/`_showCreateActivitySheet` — move out of the class as top-level functions)

**Interfaces:**
- Consumes: `_ClassTab`, `_ActivitiesTab`, `ClassAnalyticsScreen(embedded: true)` from Tasks 1-2 (used in Task 4, not here — this task only removes them from the `IndexedStack`).
- Produces: top-level functions `_showAddLearnerDialog(BuildContext context, String teacherUid)` and `_showCreateActivitySheet(BuildContext context, String teacherUid)` (same signatures as before, just no longer instance methods), callable from `_HomeTab` in Task 4.

- [ ] **Step 1: Shrink `destinations` to 2 entries**

Find (around line 68):

```dart
      destinations: const [
        ResponsiveDestination(
            icon: Icons.home_outlined, activeIcon: Icons.home, label: 'Home'),
        ResponsiveDestination(
            icon: Icons.group_outlined,
            activeIcon: Icons.group,
            label: 'Class'),
        ResponsiveDestination(
            icon: Icons.assignment_outlined,
            activeIcon: Icons.assignment,
            label: 'Activities'),
        ResponsiveDestination(
            icon: Icons.analytics_outlined,
            activeIcon: Icons.analytics,
            label: 'Analytics'),
        ResponsiveDestination(
            icon: Icons.person_outline,
            activeIcon: Icons.person,
            label: 'Profile'),
      ],
```

Replace with:

```dart
      destinations: const [
        ResponsiveDestination(
            icon: Icons.home_outlined, activeIcon: Icons.home, label: 'Home'),
        ResponsiveDestination(
            icon: Icons.person_outline,
            activeIcon: Icons.person,
            label: 'Profile'),
      ],
```

- [ ] **Step 2: Fix the CircleAvatar's tap target (was index 4, now index 1)**

Find (around line 117):

```dart
              onTap: () => setState(() => _selectedIndex = 4),
```

Replace with:

```dart
              onTap: () => setState(() => _selectedIndex = 1),
```

- [ ] **Step 3: Remove the now-dead FAB block**

Find (around line 137-155):

```dart
      floatingActionButton: _selectedIndex == 1
          ? FloatingActionButton.extended(
              heroTag: 'fab_class',
              onPressed: () => _showAddLearnerDialog(context, uid),
              backgroundColor: _kPrimary,
              icon: const Icon(Icons.person_add, color: Colors.white),
              label: const Text('Add Learner',
                  style: TextStyle(color: Colors.white)),
            )
          : _selectedIndex == 2
              ? FloatingActionButton.extended(
                  heroTag: 'fab_activity',
                  onPressed: () => _showCreateActivitySheet(context, uid),
                  backgroundColor: _kPrimary,
                  icon: const Icon(Icons.add, color: Colors.white),
                  label: const Text('Create Activity',
                      style: TextStyle(color: Colors.white)),
                )
              : null,
```

Delete this entire block (both the `floatingActionButton:` property and its value). The `Add Learner`/`Create Activity` actions move to the new collapsible sections' headers in Task 4, called directly rather than via a tab-indexed FAB.

- [ ] **Step 4: Shrink the `IndexedStack` children to 2**

Find (around line 156-172, adjusting for the FAB block removed in Step 3):

```dart
      body: Column(
        children: [
          const OfflineBanner(),
          Expanded(
            child: IndexedStack(
              index: _selectedIndex,
              children: [
                _HomeTab(teacherUid: uid),
                _ClassTab(teacherUid: uid),
                _ActivitiesTab(teacherUid: uid),
                ClassAnalyticsScreen(teacherUid: uid),
                const _ProfileTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
```

Replace with:

```dart
      body: Column(
        children: [
          const OfflineBanner(),
          Expanded(
            child: IndexedStack(
              index: _selectedIndex,
              children: [
                _HomeTab(teacherUid: uid),
                const _ProfileTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
```

- [ ] **Step 5: Move `_showAddLearnerDialog` out of `_TeacherDashboardState` as a top-level function**

Find the method inside the class (starts around line 176, right after the `build()` method's closing brace):

```dart
  void _showAddLearnerDialog(BuildContext context, String teacherUid) {
    final codeCtrl = TextEditingController();
```

...through its closing (ends right before `void _showCreateActivitySheet`):

```dart
      },
    );
  }

  void _showCreateActivitySheet(BuildContext context, String teacherUid) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => _CreateActivitySheet(teacherUid: teacherUid),
    );
  }
}
```

Cut both methods out of the class entirely (the class now ends right after `build()`'s closing `}` from Step 4 — add a `}` there to close `_TeacherDashboardState`), and paste them back in as top-level functions immediately after the class, replacing every `_db` reference with `FirebaseFirestore.instance` (there is exactly one, in the "Link Learner" button's `onPressed`):

```dart
void _showAddLearnerDialog(BuildContext context, String teacherUid) {
  final codeCtrl = TextEditingController();

  showDialog(
    context: context,
    builder: (ctx) {
      bool loading = false;
      String? error;

      return StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _kPrimary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.link, color: _kPrimary),
              ),
              const SizedBox(width: 12),
              const Text('Add Learner'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Ask the learner for their 6-character class link code.',
                style: AppTextStyles.bodyMedium
                    .copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: codeCtrl,
                maxLength: 6,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  labelText: 'Link Code (e.g. AB12CD)',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  prefixIcon:
                      const Icon(Icons.vpn_key_outlined, color: _kPrimary),
                  errorText: error,
                ),
                onChanged: (_) => setS(() => error = null),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: _kPrimary),
              onPressed: loading
                  ? null
                  : () async {
                      final code = codeCtrl.text.trim().toUpperCase();
                      if (code.length != 6) {
                        setS(() => error = 'Enter exactly 6 characters');
                        return;
                      }
                      setS(() => loading = true);
                      try {
                        final q = await FirebaseFirestore.instance
                            .collection('users')
                            .where('childLinkCode', isEqualTo: code)
                            .limit(1)
                            .get();
                        if (q.docs.isEmpty) {
                          setS(() {
                            error = 'No learner found with this code';
                            loading = false;
                          });
                          return;
                        }
                        final learnerUid = q.docs.first.id;
                        final batch = FirebaseFirestore.instance.batch();
                        batch.update(
                          FirebaseFirestore.instance
                              .collection('users')
                              .doc(learnerUid),
                          {
                            'linkedTeacherUids':
                                FieldValue.arrayUnion([teacherUid])
                          },
                        );
                        batch.update(
                          FirebaseFirestore.instance
                              .collection('users')
                              .doc(teacherUid),
                          {
                            'linkedChildrenUids':
                                FieldValue.arrayUnion([learnerUid])
                          },
                        );
                        await batch.commit();
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Learner linked successfully!'),
                              backgroundColor: AppColors.success,
                            ),
                          );
                        }
                      } catch (e) {
                        setS(() {
                          error = 'Error: ${e.toString()}';
                          loading = false;
                        });
                      }
                    },
              child: loading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2),
                    )
                  : const Text('Link Learner'),
            ),
          ],
        ),
      );
    },
  );
}

void _showCreateActivitySheet(BuildContext context, String teacherUid) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (ctx) => _CreateActivitySheet(teacherUid: teacherUid),
  );
}
```

(The `_db` field declared at the top of `_TeacherDashboardState` — `final _db = FirebaseFirestore.instance;` — now has no remaining callers inside the class. Remove that field declaration too.)

- [ ] **Step 6: Verify no analyzer issues**

Run: `flutter analyze lib/features/dashboard/screens/teacher_dashboard.dart`
Expected: `No issues found!`

- [ ] **Step 7: Commit**

```bash
git add lib/features/dashboard/screens/teacher_dashboard.dart
git commit -m "refactor(teacher): shrink bottom nav to Home + Profile"
```

---

## Task 4: Add the three collapsible sections to `_HomeTab`

**Files:**
- Modify: `lib/features/dashboard/screens/teacher_dashboard.dart` (`_HomeTab.build()`, around the "Recent Class Activity" section and the class's closing brace)

**Interfaces:**
- Consumes: `_ClassTab`, `_ActivitiesTab` (unchanged constructors, embeddable per Task 1), `ClassAnalyticsScreen(teacherUid: ..., embedded: true)` (per Task 2), `_showAddLearnerDialog`/`_showCreateActivitySheet` (top-level functions per Task 3).
- Produces: new private widget `_CollapsibleSection` (below), used only within this file.

- [ ] **Step 1: Insert the three sections after "Recent Class Activity" and before "Quick Actions" in `_HomeTab.build()`**

Find (around line 533, right after the `Recent Class Activity` StreamBuilder's closing and before the `Quick Actions` heading):

```dart
              const SizedBox(height: 28),
              Row(
                children: [
                  const Text('⚡', style: TextStyle(fontSize: 18)),
                  const SizedBox(width: 8),
                  Text('Quick Actions', style: AppTextStyles.h3),
                ],
              ),
```

Replace with:

```dart
              const SizedBox(height: 28),
              _CollapsibleSection(
                title: 'Learners',
                icon: Icons.group_outlined,
                onAdd: () => _showAddLearnerDialog(context, teacherUid),
                addTooltip: 'Add learner',
                child: _ClassTab(teacherUid: teacherUid),
              ),
              _CollapsibleSection(
                title: 'Activities',
                icon: Icons.assignment_outlined,
                onAdd: () => _showCreateActivitySheet(context, teacherUid),
                addTooltip: 'Create activity',
                child: _ActivitiesTab(teacherUid: teacherUid),
              ),
              _CollapsibleSection(
                title: 'Analytics',
                icon: Icons.analytics_outlined,
                child: ClassAnalyticsScreen(
                    teacherUid: teacherUid, embedded: true),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Text('⚡', style: TextStyle(fontSize: 18)),
                  const SizedBox(width: 8),
                  Text('Quick Actions', style: AppTextStyles.h3),
                ],
              ),
```

- [ ] **Step 2: Add the `_CollapsibleSection` widget**

Add this new class immediately after the closing `}` of `_HomeTab` (right before the `// Stats grid` section comment, around line 588):

```dart
// ─────────────────────────────────────────────────────────────────────────────
// Collapsible section (Learners / Activities / Analytics on the Home tab)
// ─────────────────────────────────────────────────────────────────────────────
class _CollapsibleSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  final VoidCallback? onAdd;
  final String? addTooltip;

  const _CollapsibleSection({
    required this.title,
    required this.icon,
    required this.child,
    this.onAdd,
    this.addTooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF1E1E2E)
            : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        leading: Icon(icon, color: _kPrimary),
        title: Text(title, style: AppTextStyles.h4),
        trailing: onAdd != null
            ? IconButton(
                icon: const Icon(Icons.add_circle_outline, color: _kPrimary),
                tooltip: addTooltip,
                onPressed: onAdd,
              )
            : null,
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [child],
      ),
    );
  }
}
```

- [ ] **Step 3: Verify no analyzer issues**

Run: `flutter analyze lib/features/dashboard/screens/teacher_dashboard.dart`
Expected: `No issues found!`

- [ ] **Step 4: Commit**

```bash
git add lib/features/dashboard/screens/teacher_dashboard.dart
git commit -m "feat(teacher): consolidate Class/Activities/Analytics into collapsible Home sections"
```

---

## Task 5: Full verification and live deploy check

**Files:** none (verification only)

**Interfaces:** none

- [ ] **Step 1: Full analyze**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 2: Full test suite**

Run: `flutter test`
Expected: `All tests passed!` (324/324 — no test in this repo references `TeacherDashboard`/`ClassAnalyticsScreen`/`_ClassTab`/`_ActivitiesTab`, confirmed via `grep -rl` during design; this run only guards against an unrelated regression).

- [ ] **Step 3: Push and deploy**

```bash
git push origin main
```

Vercel auto-deploys on push to `main` (confirmed working earlier this session). Wait for the new deployment to show `Ready`:

```bash
npx vercel list questkids
```

- [ ] **Step 4: Live click-through against the deployed build**

Using a headless-browser script against `https://questkids-two.vercel.app` (the pattern already established this session in `C:\Users\mamag\.claude\jobs\c247f3b8\tmp\qk_*.js`, driving Chromium via the `playwright` package already available at `C:/Users/mamag/AppData/Roaming/npm/node_modules/n8n/node_modules/playwright`):

1. Log in as a test teacher account (credentials kept out of this repo — see local notes, or register a fresh throwaway account through the normal sign-up flow).
2. Screenshot the Home tab — confirm only two bottom-nav destinations (Home, Profile) appear, and three collapsed sections (Learners, Activities, Analytics) are visible below Recent Class Activity.
3. Tap each section's title row — confirm it expands and its content renders without a Flutter red error screen or console `pageerror`.
4. Tap the Learners section's add-icon — confirm the "Add Learner" dialog opens (same dialog as before).
5. Tap the Activities section's add-icon — confirm the "Create Activity" bottom sheet opens.
6. Confirm no `pageerror` / `console.error` entries appear beyond the already-known benign Google-sign-out network noise documented earlier this session.

- [ ] **Step 5: Report results to the user**

Summarize what changed, link the live URL, and note any issue found in Step 4 that needs a follow-up fix.
