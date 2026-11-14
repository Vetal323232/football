# Code review and reproduced baseline — 2026-11-14

Reviewed gameplay commit: a47746eba365d3a3a1ffc6693069dc2cab484505.
Source branch: claude/new-session-yr8bm1. Engine: Godot 4.5.1-stable, f62fdbde1, Linux.

This is a source review and reproducible automated validation checkpoint. It does not establish that all possible
bugs have been found, that the Windows executable works, or that the controls feel good to a person.
Navigation: [PROJECT_MAP.md](PROJECT_MAP.md). Actionable work: [AI_WORK_PLAN.md](AI_WORK_PLAN.md).

## Repeated checks

The commands below were actually run on the reviewed gameplay code. The Godot executable was the official
4.5.1 Linux binary; substitute its full path when it is not named godot.

| Check | Actual result |
| --- | --- |
| godot --headless --import | Completed |
| godot --headless -s tests/run_tests.gd | 300 checks, 0 failed; two assertions are always true |
| godot --headless -s tools/run_scenarios.gd | 67/72; attack_3v2 4/9; process exit 0 despite failed verdicts |
| tools/run_match.gd, seeds 1..8, duration 360, levels 70/70 | Scores 2-0, 1-1, 1-0, 2-0, 0-1, 0-1, 0-2, 0-2; 8.6 shots/match, 0 reported stalls and assignment conflicts |
| Same eight seeds, levels 84/62 | 7 wins, 1 draw; goals 15:3; 9.0 shots/match; no reported stalls/conflicts |
| tools/fuzz_human.gd | Three matches completed; FUZZ OK |
| tools/career_journey.gd | JOURNEY OK, including season rollover |
| Headless menu, match, diagnostic, career-lineup and transfer-screen startup | No script error during startup |
| Additional scene-flow probe | Real 40-second match -> result screen -> career round 1 -> lineup/table/fixtures/transfers -> autosave -> main menu; UI_JOURNEY_OK |
| tools/review_regressions.gd | Five desired-behaviour checks, all five fail on the baseline; exit 1 |

The additional scene-flow probe invoked actual screen methods and the real simulation. It was not a visual or
keyboard usability assessment. ObjectDB/resource leak warnings appeared at process exit; see MEM01.

## Confirmed findings

### RULE01 — An offside player can execute a first-time shot without the whistle

Location: src/sim/match_sim.gd, _try_kick and _register_touch.

_try_kick changes ball.kicker to the new player before checking _register_touch. The old offside flag is then
bypassed because _register_touch checks ball.kicker != p.id; the subsequent snapshot clears the old flags.

Reproduction: first create an actual flagged offside position with a pass, arrange the receiving contact, and
request a first-time shot before assigning possession.

Observed: initially_flagged=true, state=PLAYING, offsides=0, shots=1.
Desired: defending free kick, one offside, no shot execution.
Command: godot --headless -s tools/review_regressions.gd -- --case=offside_first_touch

### AI01 — A future runner event bypasses the carrier's current commitment

Location: src/ai/on_ball_ai.gd, drive; src/ai/team_ai.gd, _drive_runner.

_drive_runner schedules run_started_tick = sim.tick + 12. drive tests run_started_tick >= sim.tick - 1, so a
future timestamp is treated as an active opportunity immediately and throughout the intervening ticks.

Observed: tick 300, scheduled event 312, pressure ETA 2.60 seconds, decision deadline 5.15, commitment until 5.4:
the existing movement command was replaced before the event was due.
Command: godot --headless -s tools/review_regressions.gd -- --case=run_trigger

### AI02 — Dribble prediction and execution use different speeds

Location: src/ai/on_ball_ai.gd, decide (dribble candidates); src/sim/match_sim.gd, _move_players.

The dribble ETA uses top_speed * dribble_speed_ratio before choosing the sprint flag. If sprint=false, execution
also multiplies speed by jog_ratio (0.7). Candidate scoring therefore assumes a faster journey than the selected
command executes. Direction, acceleration and stamina also need consistent treatment.

This inconsistency is confirmed by code inspection and the production trace. The trace had the winger jogging
at roughly 5.23 m/s while evaluating candidates using sprint-based speed. Its contribution to the overload
failure is a tuning hypothesis to validate; it is not proven to be the sole cause.

### AI03 — The 3v2 failure is reproducible in the production AI

Command:

    godot --headless -s tools/probe_scn.gd -- --name=attack_3v2 --variant=0 --seed=11 --secs=10 --duties

Observed: striker passes to the right winger at 1.12 s; winger receives at 2.27 s; carrier repeatedly prefers the
outward 34-degree dribble and advances from approximately (17, 15) to (47, 24), with no shot in the ten-second
episode. At 2.5 s its chosen outward option had EV 0.10144, versus 0.04820 for the more goalward 0-degree option.
The episode remained in PROGRESSION/CHANCE rather than ATTACK_TRANSITION.

The documented previous break-mode tuning attempt already regressed other scenarios and was reverted.
Do not blindly repeat it or solve the metric by forcing low-value shots.

### AI04 — The run-behind success predicate measures intent, not a completed combination

Location: src/ai/scenario_lib.gd, observe and judge.

run_seen becomes true when any agent has run_state == 1. A safe through ball, useful actual run geometry,
onside receipt, and resulting advantage are not required for an OK verdict.

The reported 9/9 therefore means the current intent predicate passed. Through/lofted delivery occurred in only
1/9 episodes. The original validation document states this limitation; the review does not treat the count as
fabricated. Strengthen the behavioural contract and report its new baseline separately.

### INPUT01 — Forward pass assistance can choose a player behind the aim

Location: src/input/human_controller.gd, assist_pass.

The fallback cone is 1.75 radians, wider than 90 degrees. With rightward input and the only nearby receiver at
(-1, 10), the selected pass direction was (-0.14834, 0.988936), i.e. behind the intended aim.
Desired: no receiver behind the aim; when no eligible receiver exists, use the forward space fallback.
Command: godot --headless -s tools/review_regressions.gd -- --case=forward_pass

### MEM01 — Finished/discarded simulations remain alive through reference cycles

Locations: MatchSim -> SimTeam -> TeamAI -> MatchSim, TeamAI -> SimTeam, and HumanController -> MatchSim.
src/view/match_view.gd, _exit_tree, currently only stops crowd audio.

Observed: after releasing the owner references, 12 of 12 newly created match simulations remained reachable
through WeakRef. Half had a human controller, half were AI-only. Exit warnings corroborate the retained objects.
Command: godot --headless -s tools/review_regressions.gd -- --case=lifetime

Use an explicit, exercised lifecycle teardown or safe weak back-references, covering all ownership cycles.

### SAVE01 — Semantically invalid JSON saves are accepted instead of recovering the backup

Location: src/career/career_state.gd, validate/normalize; src/career/save_manager.gd, _read/load_career.

Observed: changing an otherwise valid save to round=999 returned zero validation errors. Even with a valid
backup present, loading reported recovered=false and returned round 999.
Desired: reject the invalid main state and recover the valid backup.
Command: godot --headless -s tools/review_regressions.gd -- --case=save_integrity

The validator also needs a deliberate audit of nested types, required keys, valid lineup/fixture structure and
numeric ranges. Those additional malformed-state cases are not all reproduced by this single probe.

### QA01 — Validation tools can look successful while checks fail

- tools/run_scenarios.gd always calls quit() without a failure code. Confirmed: 67/72 and exit 0.
- tests/run_tests.gd has two assertions ending in "or true" (lineup and money conservation). They cannot fail.
  The other passing checks should be assessed individually; this does not invalidate every assertion.
- tools/shot.sh ends its pipeline with "|| true". With Xvfb absent, it returned 0 and produced no screenshot.
- run_behind's weak success predicate is tracked separately under AI04.

## Limits and unresolved questions

This section describes the first review environment. The subsequent [extended audit](DEEP_AUDIT_2026-11-14.md)
adds actual software-rendered visual inspection, new seed matrices and deeper corruption/state probes;
use its boundaries for the current checkpoint. The original evidence below remains historical.

- The Windows executable has not been run by this review.
- No GPU, display server, visual animation review, audio review or real keyboard playtest was available.
- The substitutions screen displays fitness (its translated label says "fitness"), while the HUD bar displays
  short-term stamina. That distinction was inspected and is not filed here as a confirmed calculation defect.
- Zero reported conflicts means the implemented presser/cover conflict counter stayed at zero. It does not prove
  every possible tactical assignment was useful or non-conflicting.
- New shot/xG targets must not rely on treating FieldValue's uncalibrated heuristic as ground truth.

## Outcome

The code implements a real shared football simulation and team-coordination system. The core reported
headless numbers were reproduced. The remaining work includes concrete correctness bugs, a weak validation
contract, and tactical quality issues. Follow AI_WORK_PLAN.md; record new evidence rather than promoting
the current baseline to "gameplay accepted".
