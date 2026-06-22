# Water Cycle Adventure (Sequence Builder)

Natural Sciences · engine `sequenceBuilder` · subject colour **teal**.

## What it is
A guided, visual drag-to-order game. Recognition-before-recall:

1. **Learn** — an animated water-cycle scene plays while the four stages are
   shown in order with friendly labels and descriptions.
2. **Order** — the stages are shuffled into a tray; drag (or tap) them into the
   correct sequence **Evaporation → Condensation → Precipitation → Collection**.
   Each correct placement reveals the next part of the animated scene (vapour
   rises → clouds form → rain falls → water flows back). Wrong placements bump
   gently — no penalty (it's a learning loop).

The scene (`water_cycle_scene.dart`) is original `CustomPaint` art — sun, sea,
vapour, clouds, rain, river — so it's crisp and offline-friendly.

## How it integrates
`SequenceBuilderGame` → `SequenceBuilderSession` (`GameSessionState`) →
`SequenceBuilderEngine`. XP/coins via `finishSession` (each completed ordering
is one scored round; `totalQuestions` = `rounds`). Routed by
`AppConstants.engineSequenceBuilder`. Catalog entry `sci_g4_water` points here.

## Difficulty mapping
`rounds` (default 3) controls how many orderings per session. The engine is
content-agnostic, so difficulty scales with the number/complexity of stages.

## Adding content
Add a sequence in `SequenceBuilderConfig.forGame` (`sequence_builder_config.dart`)
— list the `SequenceStage`s **in correct order** (`id`, `label`, `emoji`,
`description`) and set a `sceneType`. To give a new topic its own animated
backdrop, add a scene widget and branch on `sceneType` in the game; otherwise the
ordering mechanic works with labels/emojis alone.
