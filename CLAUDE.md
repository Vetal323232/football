# Open Pitch — project rules

Offline 3D football (Godot 4.5.1, GDScript, `gl_compatibility` renderer). Full brief: `docs/BRIEF.md`.
Design: `docs/DESIGN.md`. Status / next task: `PROGRESS.md`. Read `PROGRESS.md` before resuming work.

## Navigation and current work
- Read `docs/PROJECT_MAP.md` for subsystem ownership, entry points and change-impact paths.
- Evidence and confirmed findings: `docs/CODE_REVIEW_2026-11-14.md` (baseline gameplay commit `a47746e`).
- Ordered tasks, reproduction commands and acceptance criteria: `docs/AI_WORK_PLAN.md`.
- Start with the first ready task in that queue; reproduce it, implement it, verify it, then update status.
- `tools/review_regressions.gd` contains five desired-behaviour checks that currently fail on the baseline.
  Keep their expectations; document remaining failures while completing unrelated tasks.
- Behavioural success and process exit status must both be checked. Never treat an exit code alone as AI quality.

## Rules
- Talk to the user in Russian. Code identifiers and technical docs in English. Game UI in Russian via `tr()` keys in `locale/strings.csv`.
- Priority: (1) control feel + ball, (2) AI quality, (3) complete match, (4) career, (5) extras.
- Simulation (`src/sim`, `src/ai`, `src/input`) is pure `RefCounted` code, fixed step 60 Hz, deterministic per seed. No scene nodes, no `randf()` (use `sim.rng`), no wall-clock time. Presentation (`src/view`, `src/ui`) only reads sim state.
- One authority for the ball: `MatchSim`. Controllers (TeamAI, HumanController) only write `PlayerCommand`. AI and human share all mechanics.
- Tuning lives in `data/tuning/default_tuning.tres` (`GameTuning`), not in behaviour code.
- Do not weaken a check to make it pass; fix the cause. Diagnostic scenarios must use the production AI (no scripted outcomes).
- Career state is plain JSON-compatible data with stable IDs; results are applied once (fixture `played` flag), the table is always derived.
- After changing `locale/strings.csv` or adding `class_name` scripts run the import command.
- Record AI evidence in `docs/AI_VALIDATION.md`, asset provenance in `ASSETS.md`, status in `PROGRESS.md`.

## Verified commands (Linux container; `godot` = Godot 4.5.1 stable)
```
godot --headless --import                                   # import / parse check (also rebuilds translations)
godot --headless -s tests/run_tests.gd                      # 300 automated checks, exit code 1 on failure
godot --headless -s tools/review_regressions.gd             # five baseline defects reproduced; currently exit 1
godot --headless -s tools/run_scenarios.gd                  # AI validation scenarios (3 variants x 3 seeds each)
godot --headless -s tools/run_match.gd -- --seeds=1,2,3     # full AI-vs-AI matches with metrics
godot --headless -s tools/fuzz_human.gd                     # random-input robustness of human control
godot --headless -s tools/career_journey.gd                 # career end-to-end through the real match engine
godot --headless -s tools/snapshot.gd -- --seed=1 --from=20 --frames=6 --out=/tmp/s.png --log   # top-down frames
tools/shot.sh res://scenes/match.tscn /tmp/m.png --after=3 --warp=40 --autoplay   # 3D screenshot via Xvfb
godot --headless --export-release "Windows Desktop" build/windows/OpenPitch.exe   # needs export templates
```
On Windows use the editor executable instead of `godot` (e.g. `Godot_v4.5.1-stable_win64.exe`).
