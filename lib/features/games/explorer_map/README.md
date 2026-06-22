# SA Provinces Explorer

Social Sciences · engine `explorerMap` · subject colour **green**.

## What it is
A scaffolded geography game on a **code-drawn** map of South Africa (ocean,
landmass, graticule, compass — no copyrighted assets). Three modes build from
recognition to recall, gated so harder modes unlock after easier ones:

1. **Learn** — free exploration; tap each province to discover its name, capital
   and a fun fact. Discovering all provinces completes the mode.
2. **Easy (recognition)** — a province lights up on the map → pick its name from
   four options.
3. **Hard (recall)** — given a province name or capital → tap the correct
   province on the map. A **hint** dims the non-answers.

## How it integrates
`ProvinceExplorer` shows a **mode hub**, then builds an `ExplorerMapSession`
(`GameSessionState`) per chosen mode (`config.extras['mode']`). XP/coins flow
through `finishSession`. Unlock progress persists offline via
`SharedPreferences` (`explorer_easy_unlocked` / `explorer_hard_unlocked`).
Routed by `AppConstants.engineExplorerMap`.

> Note: `totalQuestions` is overridden to the generated question count — this
> fixes the old mismatch where the screen blanked out and never finished.

## Difficulty mapping
Mode itself is the difficulty axis (Learn → Easy → Hard). Easy/Hard draw 8
provinces per run; Learn covers all 9.

## Adding content
Edit `ExplorerMapConfig.saProvinces` in `explorer_map_config.dart`: each
`ProvincePin` has `name`, `capital`, `emoji`, `color`, a fractional map
`position`, and `facts`. Questions for Easy/Hard are generated from this list,
so adding a province automatically extends all three modes.
