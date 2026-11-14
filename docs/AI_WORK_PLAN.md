# AI and correctness work plan

Evidence baseline: gameplay commit a47746e, Godot 4.5.1, 2026-11-14.
Read [PROJECT_MAP.md](PROJECT_MAP.md) and [CODE_REVIEW_2026-11-14.md](CODE_REVIEW_2026-11-14.md).
The extended findings and saved logs are in [DEEP_AUDIT_2026-11-14.md](DEEP_AUDIT_2026-11-14.md).
The complete implementation request is [CLAUDE_MASTER_PROMPT_EN.md](CLAUDE_MASTER_PROMPT_EN.md).

## Operating contract

- Work on one task per coherent change set. Start with the first ready task in the queue below.
- Reproduce its failure before implementation. Add or retain a behavioural regression.
- Fix the cause, run the task's checks, and inspect actual episodes when the task affects AI.
- Record commands, results, seed/configuration and remaining limitations in PROGRESS.md and AI_VALIDATION.md.
- Mark a task DONE only when its own acceptance criteria pass. Then continue to the next ready task.
- Preserve unrelated working systems. Use the shared simulation and production AI for validation.
- Logging must observe already computed decisions; do not call decision functions again just for output.
- Changed success predicates require a separately labelled baseline. Keep the legacy diagnostic result comparable.
- Treat heuristic xG and aggregate pass accuracy as diagnostics; also inspect decisions and physical outcomes.
- Update this queue when work is completed or blocked. Do not expand the feature set before these quality gates.

## Queue

| Order | ID | Status | Dependency | Result |
| --- | --- | --- | --- | --- |
| 1 | QA01 | READY | None | Failing checks produce failing commands; assertions actually assert. |
| 2 | RULE01 | TODO | QA01 | Offside is enforced before a flagged first-time kick. |
| 3 | RULE02 | TODO | QA01, RULE01 | Keeper foot control preserves a back-pass restriction. |
| 4 | SAVE01 | TODO | QA01 | Nested invalid saves recover safely; no script errors during validation. |
| 5 | MEM01 | TODO | QA01 | Repeated matches release simulation ownership cycles. |
| 6 | SUB01 | TODO | QA01 | Fresh substitutes do not inherit outgoing action/recovery state. |
| 7 | INPUT01 | TODO | QA01 | Forward intent cannot select a receiver behind the aim. |
| 8 | INPUT02 | TODO | QA01 | Initial human handoff follows the selected eligible receiver. |
| 9 | INPUT03 | TODO | QA01 | Releasing a charged shot in pause does not fire on resume. |
| 10 | CAREER01 | TODO | QA01, SAVE01 | Auto-lineup handles negative candidate scores and invalid roster shapes. |
| 11 | AI01 | TODO | QA01 | Runner notifications trigger at the intended time, once. |
| 12 | AI02 | TODO | AI01 | Dribble utility evaluates the movement that will actually execute. |
| 13 | AI05 | TODO | AI01, AI02 | Defensive recovery holds beyond the original scenario seeds. |
| 14 | AI03 | TODO | RULE01, AI01, AI02 | Numerical advantages lead to useful chances without weakening defence. |
| 15 | AI04 | TODO | AI01, AI02, INPUT02 | Safe runs behind are served and received; unsafe alternatives are rejected. |
| 16 | V01 | PROPOSED SLICE | QA01; independent presentation work can start earlier | Ball, camera and stadium are readable in motion. |
| 17 | T01 | PROPOSED SLICE | AI03, AI04, INPUT02 | Give-and-go/third-man experiment extends existing support logic. |
| 18 | PLAY01 | MANUAL / UNVERIFIED | Runnable Windows build; final behaviour revision | Human control, visual motion and hardware performance have actual evidence. |

TODO tasks become ready when dependencies are complete. Independent correctness fixes can be advanced if a
higher task is genuinely blocked; record why. All five new review regressions currently fail by design on the
reviewed gameplay code. Their failure is an existing defect, not a regression introduced by the map.
The extended queue prioritizes save/lifecycle/input correctness before tactical tuning so later evidence
rests on reliable state. All new tasks remain open; this handoff implemented no gameplay fixes.

## QA01 — Make validation commands trustworthy

Files: tools/run_scenarios.gd; tools/shot.sh; tests/run_tests.gd.
Evidence: full scenario runner reports 67/72 but exits 0; two unit assertions contain "or true";
the screenshot wrapper exits 0 when Xvfb is missing and no image was produced.

Implement:

1. Return nonzero when any required scenario verdict fails, the case filter is unknown, or zero cases run.
2. Preserve the screenshot command's real failure status. Check dependencies and validate the output artifact.
   Filtering engine logs must not hide a failed process or missing PNG.
3. Replace the two tautologies with real lineup/budget invariants, accounting for deliberate budget mutations
   in test setup. Do not preserve the number 300 by counting assertions that cannot fail.
4. Keep the existing scenario contracts unchanged in this task so its effect is measurable.

Acceptance:

- Existing full scenario command exits 1 while the five known overload episodes still fail.
- A passing selection such as --only=blocked_lane exits 0.
- An invalid --only name exits nonzero and reports the mistake.
- A screenshot run with a deliberately missing dependency fails; a successful run requires an actual image.
- Real lineup and transfer checks pass, and a targeted intentional violation makes the appropriate check fail.
- Explain that this task can be DONE while the correctly reported AI failures remain open.

## RULE01 — Validate a first-time touch before replacing its history

Files: src/sim/match_sim.gd, _try_kick / _register_touch; tests/run_tests.gd.
Reproduce:

    godot --headless -s tools/review_regressions.gd -- --case=offside_first_touch

Observed: a genuinely flagged player shoots; no offside is counted.
Root cause: ball.kicker is replaced before the legality check, hiding the prior teammate's kick.

Implement the touch/legality ordering so the previous kick and offside snapshot remain available until the
new player's involvement is judged. Preserve correct restart and back-pass bookkeeping.

Acceptance:

- The review case passes: one offside, defending free kick, zero shot execution.
- An onside first-time shot still executes.
- Normal offside on receipt still works, including after switching ends.
- Throw-in/corner/goal-kick exemptions and restart double-touch behaviour do not regress.
- The same incident cannot add multiple whistles, shots or goals.

## AI01 — Consume runner events at the intended tick

Files: src/ai/on_ball_ai.gd, drive; src/ai/team_ai.gd, _drive_runner / on_restart; src/ai/ai_agent.gd if needed.
Reproduce:

    godot --headless -s tools/review_regressions.gd -- --case=run_trigger

Observed: event tick 312 breaks a commitment at tick 300 despite no urgent pressure.
The comparison run_started_tick >= sim.tick - 1 treats future events as already active.

Acceptance:

- A future event preserves the active movement decision and decision deadline.
- A due event can prompt one appropriate reevaluation.
- The same event is not repeatedly consumed on successive ticks.
- Restarting and new events do not reuse stale notifications.
- Existing immediate-pressure behaviour remains deliberate and tested.
- Record decision frequency around a runner event in a real run_behind episode.

## AI02 — Align dribble forecasts with executed movement

Files: src/ai/on_ball_ai.gd, decide; src/sim/sim_query.gd; src/sim/match_sim.gd, _move_players;
src/sim/sim_player.gd and game_tuning.gd where appropriate.

Evidence: candidate ETA assumes top_speed * dribble_speed_ratio, but a non-sprint command actually uses an
additional jog_ratio multiplier. Sprint is chosen after estimating the candidate.

Implement consistent candidates/estimates for jog and sprint, taking current velocity, acceleration, stamina,
recovery state and dribbling into account. Share a small physical helper where it removes inconsistent copies;
avoid creating a parallel movement engine.

Acceptance:

- Isolated straight six-metre predictions agree with actual command execution within 0.15 seconds over
  documented pace/stamina/jog/sprint cases. Document and justify a separate bound for turning cases.
- The scored action is the action that executes; the model does not use sprint speed for jogging.
- Human/AI physical execution limits remain shared.
- Run all legacy scenarios and report the new baseline before changing utility weights.
- Any changed decisions are traced to the model correction rather than an unrelated bundle of tuning changes.

## AI03 — Exploit 3v2 without sacrificing football quality

Files: on_ball_ai.gd (decide / _next_option); team_ai.gd (_plan_attack, _counter_chance,
_update_engage, _drive_runner); kick_planner.gd and field_value.gd only as evidence warrants.

Reproduce:

    godot --headless -s tools/probe_scn.gd -- --name=attack_3v2 --variant=0 --seed=11 --secs=10 --duties
    godot --headless -s tools/run_scenarios.gd -- --only=attack_3v2 --seeds=11,22,33

Baseline: 4/9. In seed 11 the winger repeatedly prefers outward dribbles and reaches the corner without a shot.
PROGRESS.md records an already reverted break-mode experiment; investigate its failure before retrying it.

Work:

1. Trace the striker's release and the receiver's subsequent choices, including available central options,
   arriving defenders, sprint choice and supporting runs.
2. Assess advantage from the current situation. A useful overload may exist without a recent possession change.
3. Make support, carrying direction and release timing preserve useful access to goal. Evaluate the next
   football action rather than rewarding forward x displacement alone.
4. Keep outnumbered defenders capable: contain when appropriate, press with real cover, protect passing lanes.

Acceptance:

- At least 7/9 legacy episodes pass, with recorded shot locations, angle/obstruction context, elapsed time
  and outcomes. Forced speculative shots alone do not satisfy the quality gate.
- Run the extended matrix using all variants and seeds 44,55,66,77,88,99 (baseline 5/18 for 3v2).
  These seeds are now known validation data. Reserve additional seeds and geometry variations before
  tuning and report individual failures; do not tune only the original nine.
- Add or retain cases for a blocked centre, unavailable runner, and a sensible recycle under pressure.
- Remaining legacy scenario invariants do not regress.
- Rerun the same eight six-minute 11v11 matches and compare shots, possession location, losses, spacing,
  deadlocks and conflicts. Inspect selected traces as well as totals.

## AI04 — Validate and complete the run-behind combination

Files: src/ai/scenario_lib.gd (observe / judge); team_ai.gd (_drive_runner); on_ball_ai.gd;
kick_planner.gd (plan_through / ground_margin).

Baseline: run_behind is 9/9 on an intent flag; through/lofted delivery occurs in 1/9.
A run_state label alone does not prove that a useful run took place.

Implement separate observable criteria for:

1. An actual well-timed movement offering a reachable, onside option.
2. A safe opportunity being recognized and served by the correct team.
3. The intended runner receiving/continuing the pass or producing a useful attacking outcome.
4. A deliberately blocked or offside alternative being rejected.

Acceptance:

- A label-only run with no corresponding movement fails the movement check.
- A safe combination with no delivery fails the combination check.
- An unrelated opponent lob cannot count as serving the designated runner.
- Controlled safe-lane and blocked-lane counterexamples produce the appropriate different choices.
- Record receipt, not just kick type. Preserve uncertainty of physical execution.
- Publish both the legacy result and the newly defined stricter results; do not present them as the same metric.
- Recheck offside, human assistance, overloads and full-match behaviour after timing changes.

## INPUT01 — Keep pass assistance in the intended half-plane

File: src/input/human_controller.gd, assist_pass.
Reproduce:

    godot --headless -s tools/review_regressions.gd -- --case=forward_pass

Observed: fallback cone 1.75 radians admits a receiver behind the aimed direction.

Acceptance:

- No assisted receiver lies behind a deliberate input aim.
- With only backward candidates, the space-pass fallback follows the aim.
- A valid forward or lateral candidate can still be selected as specified.
- Verify near-90-degree cases, both teams, both halves, and keyboard camera conversion.
- Passing assistance still leaves outcome to the common physical simulation.

## MEM01 — Release match ownership cycles

Files: src/sim/match_sim.gd; src/sim/sim_team.gd; src/ai/team_ai.gd; src/input/human_controller.gd;
src/view/match_view.gd, _exit_tree; relevant headless runner/report owners.
Reproduce:

    godot --headless -s tools/review_regressions.gd -- --case=lifetime

Observed: 12/12 released matches remain alive via RefCounted cycles.

Acceptance:

- Zero of the twelve weak references remain alive after the documented cleanup.
- Exercise both AI-only and human-controlled matches and repeated scene restart/exit.
- If using explicit teardown, implement an idempotent MatchSim.dispose entry point and call it from real
  owners, including match_view and headless tools. The review probe supports this method.
- Break all relevant cycles, including AI-to-team and event/report ownership, rather than merely one pointer.
- Rerun repeated matches and inspect object/resource counts and exit warnings.
- Do not suppress the warnings to satisfy the criterion.

## SAVE01 — Reject invalid game state before loading it

Files: src/career/career_state.gd, validate / normalize; src/career/save_manager.gd, _read / load_career.
Reproduce:

    godot --headless -s tools/review_regressions.gd -- --case=save_integrity

Observed: round=999 passes validation and prevents use of a good backup.

Acceptance:

- Invalid round/season state is rejected; a valid backup is recovered.
- Nested types, mandatory player/fixture fields, lineup validity, fixture references, and numeric ranges
  are validated before typed iteration or normalization can crash.
- Include malformed but syntactically valid JSON cases and a valid round-trip control.
- If both copies are invalid, report the existing understandable failure without returning a broken career.
- Keep test saves isolated from user://saves.
- All 30 `tools/audit_save_case.gd` cases pass under the strict Python wrapper, including the valid control,
  all nested-type cases and semantic mutations. Add both-invalid and missing-backup cases.
- Run the normal multi-season stress control and preserve IDs, integer state and ownership. Fractional
  JSON growth values have an explicit 1e-5 round-trip tolerance in the audit; do not confuse formatting with corruption.

## RULE02 — Preserve the back-pass history through keeper foot control

Files: src/sim/match_sim.gd, _register_touch / _give_possession / _may_handle / _free_ball_contacts.
Reproduce:

    godot --headless -s tools/deep_audit.gd -- --case=backpass_feet

Observed: handling changes from forbidden to allowed after the goalkeeper receives a teammate's pass
with his feet. No intervening player touched the ball. This violates the existing DESIGN.md contract.

Acceptance:

- Foot control alone keeps handling forbidden, including after losing close control and meeting the ball again.
- Legitimate opponent touches and legal keeper catches/distributions still behave as specified.
- Keep direct back-pass, restart no-second-touch and offside-history checks passing.
- Do not add an unrelated discipline/foul system to fix the history flag.

## SUB01 — Separate player identity from outgoing transient state

Files: src/sim/match_sim.gd, substitute / _apply_identity; src/sim/sim_player.gd; src/ai/ai_agent.gd;
src/ai/team_ai.gd; src/view/match_view.gd / player_rig.gd as identity refresh requires.
Reproduce:

    godot --headless -s tools/deep_audit.gd -- --case=substitution_state

Acceptance:

- Fresh identity has no outgoing stun, tackle/dive recovery, queued kick, stale command or individual distance.
- Position/formation slot and required orientation remain valid; appropriate AI decisions are refreshed.
- Old and new stable IDs remain in match participation for correct career development; no double counting.
- Preserve five-sub limit, bench membership, possession/keeper-hand restrictions and full-time rejection.
- Verify human-controlled and AI slots, goalkeepers, scene refresh and a substitute near an in-flight ball.

## INPUT02 — Respect the selected receiver at human handoff

Files: src/input/human_controller.gd, update; src/ai/team_ai.gd, _ball_claims; scenario_lib human_support.
Reproduce:

    godot --headless -s tools/deep_audit.gd -- --case=pass_handoff

Baseline: intended #9, next-tick control #7 at seed 44; seeds 11/55 correctly control #9.
Acceptance:

- All three production scenario reproductions pass without changing their geometry/seed or scripted input.
- Valid user-selected outfield receiver wins the initial handoff over a different AI intercept assignment.
- Invalid/unavailable receiver, goalkeeper distribution, opponent interception and later ownership have explicit fallbacks.
- Control is stable; no per-tick flicker or multiple human-controlled players. Repeat both teams and halves.

## INPUT03 — Cancel/resynchronize input around pause and focus loss

Files: src/view/match_view.gd, set_paused / _unhandled_input / _sample_input; HumanController charge state.
Reproduce:

    godot --headless -s tools/deep_audit.gd -- --case=pause_shot

Acceptance:

- Hold K, pause, release K, resume: no shot until a new deliberate gameplay action.
- Holding through resume follows a documented consistent policy without resurrecting a stale release.
- Normal charge/release, input edges, pause-menu buttons and losing/regaining window focus behave correctly.
- Simulation clock/AI/cooldowns remain frozen in pause; no queued pass/tackle leaks out of menus.

## CAREER01 — Make lineup selection robust

Files: src/career/league_data.gd, auto_lineup; CareerState._repair_lineup and lineup_valid; relevant UI errors.
Reproduce under `run_deep_audit.py` so runtime errors cannot be mistaken for success:

    godot --headless -s tools/deep_audit.gd -- --case=keeper_only_lineup

Acceptance:

- The 16-GK adversarial roster produces 11 unique slot assignments without runtime errors; out-of-position
  selection is already allowed. A negative score must not prevent choosing the best available candidate.
- Empty/short/missing-keeper/malformed rosters are rejected or repaired through an explicit safe contract,
  without partially mutating career state or returning an apparently valid broken team.
- Standard lineup generation, transfers, keeper protection and normal career stress still pass.
- Label this robustness case honestly; the audit did not demonstrate an ordinary UI route to the 16-GK roster.

## AI05 — Diagnose and repair recovery on the extended matrix

Files: src/ai/team_ai.gd, _update_side / _plan_defend / _update_engage / _drive_press / _drive_mark;
scenario_lib.observe/judge for evidence only unless a counterexample proves a predicate defect.
Reproduce:

    godot --headless -s tools/run_scenarios.gd -- --only=high_loss --seeds=44,55,66,77,88,99
    godot --headless -s tools/probe_scn.gd -- --name=high_loss --variant=1 --seed=44 --secs=8 --duties
    godot --headless -s tools/probe_scn.gd -- --name=wing_defence --variant=2 --seed=88 --secs=8 --duties

Baseline high_loss 14/18, wing_defence 17/18. Root cause is not yet established.
Acceptance:

- Explain each failing episode with time-series positions, phase/duty changes, available cover and threats.
- Distinguish legitimate end-of-episode geometry from sustained central abandonment; prove predicate changes
  with a counterexample, keeping legacy/new metrics separately labelled.
- Eliminate the identified assignment/recovery defect on the four high_loss and one wing episode while
  preserving effective delay/containment, no swarming, and all original defensive scenario verdicts.
- Recheck fresh seeds, possession changes, both halves, press/cover commitments and full-match chances conceded.

## V01 / T01 — Limited improvement slice

Detailed hypotheses and extension points: [IMPROVEMENT_IDEAS.md](IMPROVEMENT_IDEAS.md).

V01: compare camera/ball/stadium/radar readability at 720p and 1080p, both halves and near/far touchlines.
Preserve physical ball size/collisions; visual emphasis and settings must not change simulation results.
Use matched snapshots and moving evidence, then human feedback. Keep a wider tactical view available.

T01: extend the existing passer memory, support duties and next-option evaluation with one give-and-go /
third-man experiment. Open return lane, tracked passer and blocked return require distinct useful choices.
No compulsory ping-pong or scripted success. Recheck input handoff, offside, overloads, recovery and match
variety. Keep only an evidenced improvement; a well-documented rejected experiment is an honest result.

## PLAY01 — Windows and human gameplay acceptance

Use docs/PLAYTEST.md on the actual Windows executable. Record machine/build version, keyboard layout,
settings and observations. Check movement, pass direction, switching, shot charging, tackle timing, teammate
support, difficulty, animation in motion, camera, sound, pause/substitution and career continuation.

Measure FPS on the real hardware. Verify the Windows executable itself rather than running its package with
a Linux engine. Convert observed problems into reproduced tasks before marking this item complete.

## Starting request for Claude Code

Use [CLAUDE_MASTER_PROMPT_EN.md](CLAUDE_MASTER_PROMPT_EN.md). It defines the full read order, baseline,
architecture, scope, work sequence, commands, evidence rules and release gates. Start with QA01 and
continue through ready tasks. Preserve regressions and report remaining failures honestly.
