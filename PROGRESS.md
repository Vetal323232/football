# Progress

Last update: 2026-11-14 (unified repair/player-career handoff; gameplay baseline `a47746e`). Engine: Godot 4.5.1-stable, renderer `gl_compatibility`.
Built and checked in a Linux container (no GPU, no Windows): headless runs + software-rendered screenshots.

## Active handoff

- **Published handoff branch:** `codex/deep-audit-claude-brief`; this consolidation is based on `87501a5`.
- **Implementation working branch:** retain an existing Claude branch/WIP if present; otherwise branch from
  the current handoff. Do not reset another implementation to this historical baseline.
- **Implementation revision last verified:** `a47746e`. Remote heads checked on 2026-11-14 contained no newer
  gameplay implementation; local/unpublished Claude work may still exist and must be inspected/preserved.
- **Current phase:** foundation repairs. **Active task:** none yet. **Next task:** QA01 (READY).
- **Scope/status authority:** `docs/AI_WORK_PLAN.md`, now 33 entries retaining every old ID. PC00–PC09 are
  required new scope; B01/B04/T07/T08/P01 are the selected follow-on improvements. Other ideas remain backlog.
- **This checkpoint:** documentation integration only; no gameplay fix, new mode, migration or new runtime test
  has been implemented. Historical baselines below remain evidence, not completed task acceptance.
- **Documentation validation:** all 18 earlier IDs retained; 33 unique queue entries with task sections and
  acyclic known dependencies; relative links resolve; gameplay/test/data/evidence files unchanged.
- **Read next:** `docs/CLAUDE_MASTER_PROMPT_EN.md`, the queue index/QA01 section, then tools/run_scenarios.gd,
  tools/shot.sh and the two tautological assertions in tests/run_tests.gd. Load only relevant map/audit rows.
- **Concrete next action:** verify Godot 4.5.1, run `godot --headless -s tools/run_scenarios.gd -- --only=unknown_case`,
  capture the empty selection/exit status, then implement QA01's strict failure/selection/screenshot/assertion gates.
- **Known open runtime evidence:** five review regressions fail; strict extended audit 11/37 subprocess cases
  pass; extended scenarios 123/144 (runner exit misleadingly 0). Preserve failures by ID until actually repaired.
- **Evidence:** `docs/evidence/deep-audit-2026-11-14/`; immutable. Put new results in a separate revision-labelled path.
- **Player career:** `docs/PLAYER_CAREER_SPEC.md`; new module paths/tests in its map are proposed, not current files.
- **External gates:** actual Windows EXE/human gameplay/audio/GPU performance remain PLAY01, unverified.
- **Resume rule:** update this block at each task/context boundary with actual revision, changed/dirty files,
  acceptance done/open, exact checks/results and one next action. Queue is authoritative for DONE/status.
  Preserve a coherent commit or labelled WIP; never restart research or claim the whole scope complete at a quota stop.

Historical audit and original implementation checkpoints follow; they are not alternate current work orders.

## Extended audit checkpoint

- Handoff branch: `codex/deep-audit-claude-brief`, based on `8283045` (`codex/project-map-ai-plan`).
- Historical entry instruction; current selective read/resume order is in the Active handoff above.
- No gameplay source/tuning was changed. All defect IDs remain open. First executable task is still QA01.
- Fresh core run: 300 checks / 0 failed. Extended scenarios: **123/144** (original 67/72 retained separately).
- 3v2 only **5/18** on new seeds. Defensive recovery and one human handoff also fail; details/traces in the audit.
- Eight deterministic pairs pass (AI-only and scripted human); 12 new input-fuzz matches pass.
- Eight careers × three seasons pass normal state/transfer/table/save invariants: 336 rounds, 672 transfers.
- Save matrix: valid control passes; 8/29 invalid primaries recover; 21 mishandled, including 8 script-error cases.
- New regressions reproduce inherited substitute state, keeper back-pass history loss, wrong pass handoff,
  pause ghost shot and adversarial negative-score auto-lineup. See tools/deep_audit.gd.
- `python3 tools/run_deep_audit.py --godot godot --out /tmp/openpitch-audit` -> **11/37 subprocess cases pass**, exit 1.
- Strength test on both sides: 12 three-minute matches, stronger team 9 wins/3 draws, 13:0; no reported stalls/conflicts.
- Actual 3D/UI captures plus a six-second software-rendered movie were produced; seven captures and three motion
  samples were inspected. Ball/player readability and seat contrast need improvement. Windows/human/audio/GPU acceptance remain open.
- Logs and four captures are versioned under `docs/evidence/deep-audit-2026-11-14/`.
- At this earlier checkpoint the proposed slice was V01/T01; the current queue also includes the approved
  player career and selected follow-on match work. Do not use this historical line to remove those tasks.

## Review checkpoint

- Read `docs/PROJECT_MAP.md`, `docs/CODE_REVIEW_2026-11-14.md` and `docs/AI_WORK_PLAN.md` before the next change.
- The review repeated 300 core checks, 67/72 scenario results, all eight equal-strength full matches,
  all eight 84-vs-62 matches (7 wins, 1 draw, 15:3), fuzz input, the career journey and a headless UI journey.
- Five additional behavioural regressions reproduce offside-first-touch bypass, early runner events,
  backward pass assistance, retained match ownership cycles and acceptance of round=999 saves.
- `godot --headless -s tools/review_regressions.gd` currently reports 5 checks / 5 failed and exits 1.
- The old scenario runner exits 0 even at 67/72; two original unit assertions contain `or true`.
- Implementation milestones below are historical implementation status, not acceptance of gameplay quality.
- First task: QA01 in `docs/AI_WORK_PLAN.md`. Gameplay fixes follow its verified checks.

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
- The original session reported a `git push` HTTP 403. The source branch was subsequently published:
  `claude/new-session-yr8bm1` was fetched and reviewed at `a47746e`. The earlier statement that commits
  exist only in the session container is no longer current; this does not establish the old app's write access.

## Tried and reverted
- "Break mode" (bonus + sprint for forward dribbles when attackers >= defenders ahead, last defender delays when
  outnumbered): `attack_3v2` stayed at 4/9 and `wing_defence` / `high_loss` regressed (64/72 total). Reverted.
  The carrier-side bonus alone is not enough; the wide receiver's choice after the first pass is the real problem.

## Next executable task
1. Complete QA01 in `docs/AI_WORK_PLAN.md`: correct failure exit status, screenshot verification and the two tautological assertions.
2. Follow the ordered correctness/AI tasks. Reproduce each issue with the named command before changing it.
3. Keep the legacy scenario result and any stricter behavioural contract separately labelled.
4. Human Windows playtesting remains PLAY01 and `docs/PLAYTEST.md`; it has not been replaced by the headless checks.
