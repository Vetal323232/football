# Open Pitch — project rules

Offline 3D football (Godot 4.5.1, GDScript, `gl_compatibility` renderer). Full brief: `docs/BRIEF.md`.
Design: `docs/DESIGN.md`. Status / next task: `PROGRESS.md`. Read `PROGRESS.md` before resuming work.

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
godot --headless -s tools/run_scenarios.gd                  # AI validation scenarios (3 variants x 3 seeds each)
godot --headless -s tools/run_match.gd -- --seeds=1,2,3     # full AI-vs-AI matches with metrics
godot --headless -s tools/fuzz_human.gd                     # random-input robustness of human control
godot --headless -s tools/career_journey.gd                 # career end-to-end through the real match engine
godot --headless -s tools/snapshot.gd -- --seed=1 --from=20 --frames=6 --out=/tmp/s.png --log   # top-down frames
tools/shot.sh res://scenes/match.tscn /tmp/m.png --after=3 --warp=40 --autoplay   # 3D screenshot via Xvfb
godot --headless --export-release "Windows Desktop" build/windows/OpenPitch.exe   # needs export templates
```
On Windows use the editor executable instead of `godot` (e.g. `Godot_v4.5.1-stable_win64.exe`).
