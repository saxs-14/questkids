# Grammar Hero Run

English · engine `runnerCollector` · subject colour **pink**.

## What it is
An endless runner. The hero runs in one of three lanes; part-of-speech words
scroll in on pills. Each round names a target ("Collect the **NOUNS**!"); collect
matches, skip the rest. QuestBot cheers correct grabs and gently encourages
misses; clearing collections advances the round and fires confetti.

## Controls & fixes applied
- **Movement:** swipe **up/down** to change lanes (primary). On-screen Up/Down
  buttons and the arrow keys are accessibility fallbacks (≥ 48 dp targets).
- **Hero orientation:** the sprite is flipped to face the incoming words.
- **No overlapping words:** the session spawns at most one word per lane and
  enforces a minimum horizontal gap (`_laneGap`), so words never stack.
- Word pills are deliberately a single neutral style — colour never reveals the
  part of speech, so the learner must read and decide.

## How it integrates
`GrammarHeroRun` → `RunnerCollectorSession` (`GameSessionState`) →
`RunnerCollectorEngine`. XP/coins via `finishSession`. Routed by
`AppConstants.engineRunnerCollector`.

## Difficulty
Levels rotate the target part of speech and increase `scrollSpeed`
(`RunnerCollectorConfig.grammarHero`): Nouns → Verbs → Adjectives → Pronouns →
Mixed. Add adverbs/pronouns for higher grades by extending the level list.

## Adding content
Edit the `GrammarLevel` entries in `runner_collector_config.dart`: each level has
CAPS-aligned `nouns`, `verbs`, `adjectives`, `pronouns` lists, a `targetPOS`, a
`missionLabel`, and `scrollSpeed`. The spawn manager mixes ~50 % target words so
learners can always progress (`RunnerCollectorEngine.randomWord`).
