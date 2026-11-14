# Open Pitch — project rules

Offline 3D football (Godot 4.5.1, GDScript, `gl_compatibility` renderer). Keep quick match and club career;
the approved scope adds a gradual career as one footballer with transfers/loans and national play.
Read the **Active handoff** at the top of `PROGRESS.md` before resuming. Runtime design: `docs/DESIGN.md`.

## Navigation and current work

- Single current implementation request: `docs/CLAUDE_MASTER_PROMPT_EN.md`.
- Single authoritative task/status queue: `docs/AI_WORK_PLAN.md` (existing path/IDs retained).
- Load its index and active task, relevant `docs/PROJECT_MAP.md` rows and actual callers. Do not preload
  every report/log on each session. `docs/PLAYER_CAREER_SPEC.md` defines PC00–PC09; read the cited sections.
- The original `docs/BRIEF.md` is historical foundation/scope background; the current request and player
  specification extend it. The idea register is backlog except for entries explicitly in the queue.
- Evidence and confirmed findings: `docs/CODE_REVIEW_2026-11-14.md` (baseline gameplay commit `a47746e`).
- Extended audit, saved logs and new defects: `docs/DEEP_AUDIT_2026-11-14.md`; ranked ideas: `docs/IMPROVEMENT_IDEAS.md`.
- Start with the first ready task in that queue; reproduce it, implement it, verify it, then update status.
- Context/token limits require a resumable checkpoint in PROGRESS.md: exact branch/revision, dirty files,
  completed/open acceptance, commands/results/evidence and one concrete next action. Preserve colleague work;
  resume the unfinished task rather than resetting the queue. One active task; no competing TODO/progress files.
- `tools/review_regressions.gd` contains five desired-behaviour checks (one still failing: AI01).
  Keep their expectations; document remaining failures while completing unrelated tasks.
- Behavioural success and process exit status must both be checked. Never treat an exit code alone as AI quality.
- `tools/run_deep_audit.py` runs isolated corruption/state/determinism/career checks and catches script errors.
  Baseline was 11/37; now 42/42. Any new failure is a defect, not an optional green-check exclusion.
- Owners of a `MatchSim` must call `dispose()` when done (ownership cycles; see MEM01).

## Rules

- Talk to the user in Russian. Code identifiers and technical docs in English. Game UI in Russian via `tr()` keys in `locale/strings.csv`.
- Priority: match correctness/control and AI, then the approved player-career loop alongside compatible club
  career, then the selected additional match improvements. See queue dependencies; manual Windows gates
  stay open when unavailable but do not block independent automated work. No Rust/engine rewrite.
- Simulation (`src/sim`, `src/ai`, `src/input`) is pure `RefCounted` code, fixed step 60 Hz, deterministic per seed. No scene nodes, no `randf()` (use `sim.rng`), no wall-clock time. Presentation (`src/view`, `src/ui`) only reads sim state.
- One authority for the ball: `MatchSim`. Controllers (TeamAI, HumanController) only write `PlayerCommand`. AI and human share all mechanics.
- Match tuning lives in `data/tuning/default_tuning.tres` (`GameTuning`); PC00 introduces named career tuning.
  Keep rates/thresholds in those resources, not scattered through behaviour code.
- Do not weaken a check to make it pass; fix the cause. Diagnostic scenarios must use the production AI (no scripted outcomes).
- Career state is plain JSON-compatible data with stable IDs; results are applied once (fixture `played` flag), the table is always derived.
- TEAM handoff and PLAYER_LOCKED control have different invariants. Locked control follows a career UID;
  bench/subbed-out means zero active humans. Club/national squads reference one player record. National
  play cannot mutate club ownership/tables; growth, training, fees and offers have once-only award owners.
- Keep legacy club saves recoverable and the player slot separate. Abilities, form, trust and reputation
  are distinct; planned new modules/commands are not implemented or tested merely because docs name them.
- After changing `locale/strings.csv` or adding `class_name` scripts run the import command.
- Record AI evidence in `docs/AI_VALIDATION.md`, asset provenance in `ASSETS.md`, status in `PROGRESS.md`.

## Verified commands (Linux container; `godot` = Godot 4.5.1 stable)
```
godot --headless --import                                   # import / parse check (also rebuilds translations)
godot --headless -s tests/run_tests.gd                      # 410 automated checks, exit code 1 on failure (-- --violate=budget|lineup self-test must fail)
godot --headless -s tools/review_regressions.gd             # desired-behaviour checks; 1 of 5 still fails (run_trigger, AI01)
python3 tools/run_deep_audit.py --godot godot --out /tmp/openpitch-audit  # extended checks; 42/42, exit 0
godot --headless -s tools/run_scenarios.gd                  # AI validation scenarios; exit 1 while any episode fails (currently 67/72), 2 on bad --only
godot --headless -s tools/run_scenarios.gd -- --seeds=44,55,66,77,88,99 # extended known seeds: 123/144
godot --headless -s tools/run_match.gd -- --seeds=1,2,3     # full AI-vs-AI matches with metrics
godot --headless -s tools/fuzz_human.gd                     # random-input robustness of human control
godot --headless -s tools/career_journey.gd                 # career end-to-end through the real match engine
godot --headless -s tools/snapshot.gd -- --seed=1 --from=20 --frames=6 --out=/tmp/s.png --log   # top-down frames
tools/shot.sh res://scenes/match.tscn /tmp/m.png --after=3 --warp=40 --autoplay   # 3D screenshot via Xvfb
godot --headless --export-release "Windows Desktop" build/windows/OpenPitch.exe   # needs export templates
```
On Windows use the editor executable instead of `godot` (e.g. `Godot_v4.5.1-stable_win64.exe`).
