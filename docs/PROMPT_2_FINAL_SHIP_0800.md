# CLAUDE CODE PROMPT 2 — Final Ship for Google, 08:00 Deadline
# Run this AFTER Prompt 1 has completed, ideally 05:00–06:30, from the repo root.
# Copy everything below this line into Claude Code.

---

You are doing the FINAL pass on **QuestKids** before it is presented/submitted to Google at 08:00 today. Read `CLAUDE.md` first. Absolute rule: **stability over features**. From this point you may only fix, verify, and package — no new features, no refactors, no dependency changes. If anything you find would take more than 20 minutes to fix safely, document it in `docs/KNOWN_ISSUES.md` instead of fixing it.

## STEP 1 — Integrity audit (read-only, report before touching anything)

Produce a single PASS/FAIL table for:
1. `flutter analyze` — 0 errors.
2. `flutter test` — all green (catalog invariants test included).
3. Secret scan — no `PRIVATE KEY`, `client_secret`, `serviceAccountKey`, `.env` in tracked files.
4. `functions/` compiles (`npm run build`).
5. Catalog invariants — no engine family over 40%, every entry has `learningObjective` + `mechanicReason`, `runnerCollector` ≥ 5 entries.
6. AI compliance — Questy bubbles labelled AI, report action present, first-open AI notice present.
7. POPIA consent — learner registration blocked without guardian consent fields.
8. Android manifest — AD_ID permission removed in the merged manifest.
9. `pubspec.yaml` version is `2.0.0+2` or higher.
10. App boots to login on `flutter run -d chrome` with zero console exceptions.

Fix only FAILs, smallest possible change, one commit each: `fix(final): <item>`.

## STEP 2 — Demo data seed

Create `scripts/seed_demo.md` documenting (and where scripts already exist, wiring) a demo state: 1 learner "Naledi, Grade 4" with a 3-day streak, some XP and 2 badges; 1 linked parent; 1 teacher with a small class; missions populated for today. The 08:00 demo must never open on an empty dashboard. If seeding must be manual, write exact click-by-click steps.

## STEP 3 — Release artefacts

1. `flutter build appbundle --release` (fallback `--no-shrink` if R8 OOMs; record which shipped).
2. `flutter build web --release`.
3. Record output paths + file sizes in the final summary.

## STEP 4 — Write `PITCH_NOTES.md` at repo root (one page, plain language)

- **What it is:** CAPS-aligned gamified learning for SA Grades 1–7, offline-capable, three roles (learner/parent/teacher), AI tutor.
- **What makes it different:** intrinsic integration — each curriculum topic maps to a game mechanic that embodies the skill (9 engines: merge, sequence, map, circuit, budget, duel, tug-of-war, runner, adventure), not one quiz reskinned 126 times; SA context throughout; parent-verified progress.
- **Trust & safety posture (be accurate, not inflated):** AI tutor proxied server-side with safety filters, quotas and in-app reporting; role-based security rules with custom claims; no advertising-ID collection; guardian consent captured at registration (POPIA); leaderboards pseudonymous. Note honestly: App Check enforcement and git-history purge scheduled immediately post-demo.
- **Traction/status:** version, platforms, what is live vs deferred (pull from `docs/DEFERRED.md`).
- **Ask:** one sentence the presenter can adapt (e.g. Play "Teacher Approved" review guidance / partnership / feedback).

## STEP 5 — Play-listing readiness checklist

Append to `PITCH_NOTES.md` a checklist of what Google Play submission still needs (do NOT fabricate any of it): privacy policy URL, Data safety form answers, Families/target-audience declaration, content rating questionnaire, 512px icon + feature graphic + ≥4 phone screenshots, short & full description. Mark each ✅ present / ⬜ needed.

## STEP 6 — Final summary

Print: commits made this session, the PASS table from Step 1 re-run, artefact paths, top 3 known issues, and the exact 10-step demo script from `docs/DEMO_CHECKLIST.md` so the presenter can rehearse it once before 08:00.

Do not push, deploy, or tag unless the human explicitly says so.
