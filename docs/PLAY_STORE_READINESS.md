# QuestKids — Google Play Store Readiness Checklist

Audited 2026-10-04 against the actual repo state (not assumptions). Status
per item: ✅ done, ⚠️ partial/needs verification, ❌ missing.

## Compliance (children's app — Google Play Families Policy)

- ✅ **No advertising ID collection** — `AD_ID` permission explicitly removed
  in `AndroidManifest.xml` (`tools:node="remove"`).
- ✅ **AI-generated content labelling** — every QuestBot message is
  identifiable as AI per `CLAUDE.md` §6.6, with a report/flag action wired
  to the `ai_reports` collection (Google Play AI-Generated Content policy
  requirement).
- ✅ **POPIA/parental consent** — `firestore.rules` server-side backstop
  requires `consentGivenBy`/`consentEmail`/`consentAt`/`policyVersion` on
  every learner account creation; verified in this session's own rules audit.
- ✅ **No PII in leaderboards** — display names/avatars only, no surnames,
  emails, or cross-school identifiers (per `CLAUDE.md` §6.5, not
  independently re-verified this pass).
- ❌ **Privacy Policy** — no privacy policy document or hosted URL exists
  anywhere in the repo or docs. This is a **hard requirement** for Play
  Store submission (a working URL must be entered in Play Console) and
  for the Data Safety form. Needs to be written and hosted before
  submission — I can draft the content, but hosting it (a URL) and
  publishing need you.
- ❌ **Data Safety form** — not started. Google requires you to declare
  every data type collected (name, birthdate, email, learning/progress
  data, Gemini chat content) and why. I can draft the answers from what
  the app actually collects, but the form itself is filled in Play Console
  directly.
- ⚠️ **Target audience / content rating questionnaire** — not something I
  can verify from the repo; must be completed in Play Console (declares
  the app targets children, which changes several other requirements —
  ads, analytics, data retention).

## Technical / build readiness

- ⚠️ **Release signing** — `CLAUDE.md` references `android/key.properties`
  and `android/questkids-release.jks`, but **neither exists in this
  checkout** (correctly gitignored if they're real secrets — but I can't
  confirm a release keystore has ever actually been generated on your
  machine vs. just documented as a convention). Confirm this exists and
  that you have a secure backup — **losing the release keystore means you
  can never update the app on Play Store again under the same listing.**
- ✅ `applicationId`: `com.questkids.questkids`, matches `CLAUDE.md`'s
  stated bundle ID (DO-NOT-TOUCH item, unchanged).
- ✅ `compileSdk`/`minSdk`/`targetSdk` inherit from the Flutter SDK's own
  defaults — fine as long as the Flutter version itself is current (Play
  Store periodically raises the minimum `targetSdk` it accepts).
- ⚠️ Current version `2.0.0+2` (pubspec.yaml) — low build number, consistent
  with "not yet shipped," not a problem, just noting it's still pre-launch
  numbering.
- ❌ **Release build never verified in this session** — `CLAUDE.md`'s own
  "R8 / release-build memory" section documents known OOM failures on this
  dev machine during `flutter build appbundle --release`. This needs an
  actual successful release build run before submission, with the
  documented `--no-shrink` fallback ready if R8 OOMs again.

## Store listing assets

- ⚠️ App icon exists (`assets/questkids_logo.png`, compressed earlier this
  session) but Play Store needs specific exported sizes (512×512 icon,
  1024×500 feature graphic, phone + tablet screenshots) — none of these
  are prepared.
- ❌ **Screenshots** — Play Store requires at least 2 phone screenshots
  minimum. None exist in the repo.
- ❌ **Store listing copy** — short description (80 chars), full description
  (4000 chars), haven't been drafted.

## What I can do next without your involvement

- Draft the actual Privacy Policy text and Data Safety form answers from
  what the app genuinely collects (I'd need you to host the policy
  somewhere — GitHub Pages works and is free).
- Draft store listing copy (short + full description).
- Attempt a real `flutter build appbundle --release` to confirm it
  succeeds (or hits the known R8 issue) before you submit anything.

## What only you can do

- Create/confirm the release keystore exists and is backed up safely.
- Complete the Content Rating and Data Safety questionnaires in Play
  Console (I can draft the answers, but Google requires the account owner
  to submit them).
- Take or commission real screenshots and a feature graphic.
- Create the Play Console listing itself and pay the one-time developer
  registration fee if not already done.
