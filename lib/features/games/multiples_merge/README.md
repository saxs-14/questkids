# Multiples Merge (+ Weekly Quiz)

Maths · engine `multiplesMerge` · subject colour **orange**.

## What it is
The everyday game teaches **multiples** through a connect-and-merge loop: drag a
finger (or tap) across adjacent tiles — including diagonals — to link the
multiples of a table **in order** (8 → 16 → 24 …). Valid next tiles **glow** to
scaffold discovery; the glow fades at higher grades to build fluency. Completing
the chain pops the tiles and awards XP.

The **Weekly Quiz** (separate entry point — the quiz icon in the game header) is
the assessment half: strict, timed `a × b = ?` recall, multiple-choice, drawn
only from the tables for the learner's grade.

## How it integrates
- `MultiplesMergeGame` → `MultiplesMergeSession` (`GameSessionState`) →
  `MultiplesMergeEngine` (`GameEngine`). XP/coins flow through the shared
  `finishSession` → `GameRepository`, exactly like every other game.
- Routed from `GameRouter` via `AppConstants.engineMultiplesMerge`.
- Catalog entries `math_g3_tables`, `math_g4_multiplication` point here.
- The Weekly Quiz is `MultiplesQuizSession`/`MultiplesQuizEngine` +
  `MultiplesQuizScreen`, pushed from the game header.

## Difficulty mapping (`multiples_merge_config.dart`)
| Grade | Tables | Grid | Chain | Hints |
|-------|--------|------|-------|-------|
| 1–2 | 2, 5, 10 | 4×4 | 6 | strong |
| 3–4 | 3, 4, 6, 8 | 5×5 | 9 | normal |
| 5–6 | 7, 8, 9, 11, 12 | 5×5 | 12 | off (start hint only) |

## Adding content
Edit `MultiplesMergeConfig.forGrade` — change the `tables`, `gridSize`,
`chainLength`, or `hintLevel` per grade band. The engine generates a guaranteed
solvable round (backtracking self-avoiding path) and plausible distractors
automatically, so no hand-authored grids are needed.
