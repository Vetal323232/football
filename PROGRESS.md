# Progress

Last update: 2026-11-14 (session 1). Engine: Godot 4.5.1-stable, renderer `gl_compatibility`.
Built and checked in a Linux container (no GPU, no Windows): headless runs + software-rendered screenshots.

## Milestones

| Milestone | Status | Evidence |
| --- | --- | --- |
| A. Environment + controllable foundation | Done (headless + screenshots); control *feel* unverified by a human | project imports with no script errors; tests "possession", "controlled-player handoff", "tackles", "ball physics" |
| B. Tactical interactions in diagnostic scenes | Done with known defects | `tools/run_scenarios.gd`: 67/72 episodes clean; F3 overlay screenshot-checked |
| C. Coordinated 11v11 | Done with known defects | 8 AI-vs-AI matches: 0 deadlocks, 0 assignment conflicts, swarm ≤ 3.9 %; too much midfield play |
| D. Complete playable match | Done | menu → match → result → menu flow renders; rules covered by tests ("goals", "ball out and restarts", "offside", "halves, clock, pause") |
| E. Career integration | Done | `tools/career_journey.gd`: play fixture on the real engine, apply once, save, reload identical, continue; tests for schedule/table/transfers/development/saves |
| F. Release 0.1 | Partly | full season + rollover verified headless; `OpenPitch.exe` exported (97 MB) but **never run on Windows**; exported pack verified by running it with the Linux engine |

Not done / not verified: any interactive play by a human, FPS on a GPU, the Windows executable itself.

## Exact commands (all were run in this session)
```
godot --headless --import
godot --headless -s tests/run_tests.gd            -> 300 checks, 0 failed
godot --headless -s tools/run_scenarios.gd        -> TOTAL 67/72
godot --headless -s tools/run_match.gd -- --seeds=1,2,3,4,5,6,7,8 --duration=360
godot --headless -s tools/fuzz_human.gd           -> FUZZ OK
godot --headless -s tools/career_journey.gd       -> JOURNEY OK
godot --headless --export-release "Windows Desktop" build/windows/OpenPitch.exe
tools/shot.sh res://scenes/match.tscn out.png --after=3 --warp=40 --autoplay
```

## Current tuning (data/tuning/default_tuning.tres = defaults in src/sim/game_tuning.gd)
Key values changed during tuning: `pass_arrive_speed 10`, `settle_time 0.2`, `pass_error_bad/good 0.06/0.01`,
`value_progress 0.15`, `value_goal_pull 0.12`, `loss_cost_scale 0.5`, `goal_value 3.3`, `progress_bonus 0.04`,
`impatience_gain 0.03`, `shot_min_xg 0.025`, `through_arrive_speed 8`, `dribble_margin_bias 0.15`,
`carry_bonus 0.015`, `mark_tightness_def/mid 0.65/0.3`, `stamina_drain 0.04`; defensive line in `AIShape.defence_line_x`
(gap factor 0.42, max line −24…−8 by `line_height`).

## Known defects
AI (details and reproduction in `docs/AI_VALIDATION.md`):
1. Too much play in the middle third; about 4 shots per team per 6-minute match.
2. Overloads (3v2) often end without a shot: ball goes wide early, winger drifts to the corner.
3. Through balls behind the line are rarely played; offside almost never occurs.
4. Crosses mostly fail; no heading mechanic. Few corners / throw-ins.
5. Last defender may step out instead of delaying when outnumbered.

Game:
- No fouls, cards, penalties, free-kick walls, injuries, stoppage time (deferred by design, see DESIGN.md §4).
- Human cannot control the goalkeeper; goal kicks and keeper distribution are always AI.
- Shirt numbers on the player models are small and hard to read from the broadcast camera.
- Quick-match squads are regenerated from a fixed seed and are independent of any career save.
- AI clubs never buy from each other or from the user's transfer list on their own initiative (they only
  buy when the user sells and sell when the user buys).
- No mid-match save; leaving a career match early leaves the fixture unplayed.
- UI strings in the career line-up for attribute abbreviations (СК, ПА, УД, КО, ЗА, ВЫ, ВР) are inline, not in the CSV.

Environment:
- `git push` was rejected (HTTP 403: the Claude GitHub App has no write access to `Vetal323232/football`).
  Commits exist only in the session container until access is granted.

## Next executable task
1. Human playtest with `docs/PLAYTEST.md`; collect notes on control feel and difficulty.
2. AI iteration on defect 2: in `OnBallAI.decide` make a carrier with a numerical advantage ahead drive at the
   last line (use `TeamAI._counter_chance`-style count of goal-side defenders to raise forward dribble value and
   sprint), and in `TeamAI._update_engage` make an outnumbered last defender contain instead of stepping out.
   Check with `tools/run_scenarios.gd -- --only=attack_3v2` (target ≥7/9) and re-run the 8 full matches.
3. Then defect 1/3: evaluate through balls against the runner's speed 0.3 s ahead, and widen attacking anchors
   when the opponent block is compact.
4. Run `OpenPitch.exe` on Windows, measure FPS with `-- --autoplay --perf`.
