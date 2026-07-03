# QuestKids

QuestKids is a gamified learning platform for South African primary school
learners (Grades 1–7), aligned to the CAPS curriculum. Learners play
curriculum-mapped games and earn XP/coins/badges, chatting with **Questy**
(a Gemini-powered AI tutor) along the way; parents and teachers get
analytics dashboards to track progress.

**Repository:** [saxs-14/questkids](https://github.com/saxs-14/questkids)

## What's here

- **126 CAPS-mapped games** across 9 purpose-built engines (`tugOfWar`,
  `adventureJourney`, `runnerCollector`, `explorerMap`, `multiplesMerge`,
  `sequenceBuilder`, `circuitBuilder`, `budgetBuilder`,
  `numberCountingDuel`) — each engine is matched to how a topic is actually
  learned (fluency drills, ordering/sequencing, map exploration, systems and
  connections, budgeting, narrative word problems), not a single quiz
  reskinned 126 times.
- **Three roles** — Learner, Parent (POPIA "competent person," QR-linked to
  their child), and Teacher (class analytics, mission assignment).
- **Questy**, an AI tutor scoped to primary-school content, proxied through
  Cloud Functions so no AI key ever ships in the client.
- **Offline-first** gameplay via a local SQLite queue that syncs to
  Firestore when connectivity returns.

## Architecture

```text
lib/
├── core/           # constants (game catalog, engine registry), services, theme
├── data/           # models + one repository per Firestore collection
├── features/       # auth, dashboard, games, ai_tutor, quests, rewards, parent, teacher, ...
functions/src/      # Cloud Functions (TypeScript): Gemini proxy, leaderboards, missions, admin
firestore.rules     # Firestore security rules
storage.rules       # Storage security rules
android/ ios/ web/  # platform shells
```

Each game follows a strict, layered engine pattern —
`GameRouter → <Engine>Game (widget) → <Engine>Session (state) → <Engine>Engine (pure Dart rules)`
— documented in full in [`CLAUDE.md`](CLAUDE.md).

| Layer | Tech |
|---|---|
| App | Flutter (Dart ≥3.4), Material 3 |
| State | Provider |
| Navigation | Classic `Navigator` named routes |
| Backend | Firebase: Auth, Firestore, Storage, Messaging, Analytics, Cloud Functions |
| AI | Gemini, via a Cloud Functions proxy only |
| Offline | sqflite / sqflite_common_ffi |
| Charts | fl_chart |

## Quickstart

```bash
git clone https://github.com/saxs-14/questkids.git
cd questkids
flutter pub get
cd functions && npm install && cd ..
flutter run -d chrome
```

See [`docs/SETUP.md`](docs/SETUP.md) for the full local dev flow and
[`docs/DEPLOYMENT.md`](docs/DEPLOYMENT.md) for releasing.

## Documentation

- [`CLAUDE.md`](CLAUDE.md) — architecture, conventions, and hard rules (the
  source of truth for this repo)
- [`docs/SETUP.md`](docs/SETUP.md) — quickstart
- [`docs/ENVIRONMENT_SETUP.md`](docs/ENVIRONMENT_SETUP.md) — full local dev setup
- [`docs/DEPLOYMENT.md`](docs/DEPLOYMENT.md) — release process
- [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) — data model and Cloud Functions reference
- [`docs/SECURITY.md`](docs/SECURITY.md) — security model (roles, rules, AI proxy, POPIA)
- [`docs/DEFERRED.md`](docs/DEFERRED.md) — known gaps and what finishing them looks like
