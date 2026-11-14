# Unified implementation queue

This file keeps its existing path so earlier handoffs keep working. It is the **single authoritative queue**
for audit repairs, selected match improvements and the newly authorized player career. Existing IDs are
preserved. [PLAYER_CAREER_SPEC.md](PLAYER_CAREER_SPEC.md) defines PC contracts, not another status list.

Evidence baseline: gameplay commit a47746e, Godot 4.5.1, 2026-11-14.
Read [PROJECT_MAP.md](PROJECT_MAP.md) and [CODE_REVIEW_2026-11-14.md](CODE_REVIEW_2026-11-14.md).
The extended findings and saved logs are in [DEEP_AUDIT_2026-11-14.md](DEEP_AUDIT_2026-11-14.md).
The complete implementation request is [CLAUDE_MASTER_PROMPT_EN.md](CLAUDE_MASTER_PROMPT_EN.md).
Latest review: [GAMEPLAY_REVIEW_2026-11-14.md](GAMEPLAY_REVIEW_2026-11-14.md), implementation 3d08f8b.
Repair detail: [CLAUDE_BUGFIX_PROMPT_EN.md](CLAUDE_BUGFIX_PROMPT_EN.md). Subsequent control slice:
[HUMAN_GAMEPLAY_SPEC.md](HUMAN_GAMEPLAY_SPEC.md). These are task specifications, not additional queues.

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
- Update this queue when work is completed or blocked. Follow the agreed phase order below.
- Use one active task. Read this index and that task's section, rather than loading the entire queue every session.
- On context/token limits, update the Active handoff in PROGRESS.md with verified work and one exact next action.
  Resume the same unfinished increment; do not repeat research or reset accepted work. See the master prompt.

## Queue

| Order | ID | Status | Dependency | Result |
| --- | --- | --- | --- | --- |
| 1 | QA01 | DONE | None | Failing checks produce failing commands; assertions actually assert. |
| 2 | RULE01 | DONE | QA01 | Offside is enforced before a flagged first-time kick. |
| 3 | RULE02 | DONE | QA01, RULE01 | Keeper foot control preserves a back-pass restriction. |
| 4 | SAVE01 | DONE | QA01 | Nested invalid saves recover safely; review boundary cases closed (session 3). |
| 5 | MEM01 | DONE | QA01 | Repeated matches release simulation ownership cycles. |
| 6 | SUB01 | DONE | QA01 | Fresh substitutes do not inherit outgoing action/recovery state. |
| 7 | INPUT01 | DONE | QA01 | Forward intent cannot select a receiver behind the aim. |
| 8 | INPUT02 | DONE | QA01 | Initial human handoff follows the selected eligible receiver. |
| 9 | INPUT03 | DONE | QA01 | Releasing a charged shot in pause does not fire on resume. |
| 10 | CAREER01 | DONE | QA01, SAVE01 | Auto-lineup is all-or-nothing and keeper eligibility precedes rating (session 3). |
| 11 | AI01 | DONE | QA01 | Runner notifications trigger at the intended time, once. |
| 12 | AI02 | REOPENED | AI01 | Normal gait correction retained; recovery cap and sudden-pressure scheduling remain. |
| 13 | AI05 | TODO | AI01, AI02 | Defensive recovery holds beyond the original scenario seeds. |
| 14 | AI03 | TODO | RULE01, AI01, AI02 | Numerical advantages lead to useful chances without weakening defence. |
| 15 | AI04 | TODO | AI01, AI02, INPUT02 | Safe runs behind are served and received; unsafe alternatives are rejected. |
| 16 | V01 | TODO | QA01; independent presentation work can start earlier | Ball, camera and stadium are readable in motion. |
| 17 | INPUT04 | TODO | INPUT03, V01 | Held defensive approach/containment with immediate manual escape. |
| 18 | INPUT05 | TODO | INPUT02, INPUT04 | Bounded receiver/loose-ball approach using the same held action. |
| 19 | AI06 | TODO | AI02, AI05, INPUT04, INPUT05 | Bounded deterministic ball-reading uncertainty and independent difficulty/assist profiles. |
| 20 | T01 | TODO | AI03, AI04, INPUT02 | Give-and-go/third-man experiment extends existing support logic. |
| 21 | B01 | TODO | AI02, INPUT01, INPUT03, INPUT05, V01 | Directional first touch makes receiving useful and responsive. |
| 22 | B04 | TODO | INPUT03, AI02 | Deliberate shot preparation, including a controllable powerful low shot. |
| 23 | PLAY01 | USER FEEDBACK / OPEN | Runnable changed Windows build; control slice | User reports poor playability on an unpinned build; verify improvements on a named revision. |
| 24 | PC00 | TODO | QA01, SAVE01, MEM01, SUB01, CAREER01 | Mode/identity/save contracts and a compatible player-career state foundation. |
| 25 | PC01 | TODO | PC00, RULE01, RULE02, INPUT01, INPUT02, INPUT03, INPUT04, INPUT05 | Stable-UID control, bench entry/exit and off-ball input on the common engine. |
| 26 | PC02 | TODO | PC01 | Per-UID participation, role-aware ratings, form/trust/reputation inputs. |
| 27 | PC03 | TODO | PC02 | Slow bounded development, weekly training and once-only rewards. |
| 28 | PC04 | TODO | PC03 | Coach selection, competition for minutes and an understandable recovery path. |
| 29 | PC05 | TODO | PC00, PC04 | A bounded multi-league world, age cohorts and shared competition calendar. |
| 30 | PC06 | TODO | PC03, PC04, PC05 | Explainable offers, renewals, transfers, loans and legal next-season paths. |
| 31 | PC07 | TODO | PC05, PC06 | U21/senior selection, qualifiers/finals and correct return to club. |
| 32 | PC08 | TODO | PC04, PC06, PC07, V01 | Complete keyboard career hub, actual event history and playable weekly loop. |
| 33 | PC09 | TODO | PC08 | Multi-season, migration, reward, contract and national integration acceptance. |
| 34 | T07 | TODO | AI03, AI05, PC05 | Distinct understandable team styles with measured on-field differences. |
| 35 | T08 | TODO | AI03, AI05, T01 | Coordinated overlaps/inside movements with compensation behind the ball. |
| 36 | P01 | TODO | PC03, PC08 | Three playable production-AI drills with bounded training credit. |

TODO tasks become ready when dependencies are complete. Independent correctness fixes can be advanced if a
higher task is genuinely blocked; record why. SAVE01/CAREER01 and the five original regressions now pass.
At 3d08f8b two gameplay probes reopen AI02; strict gate is 47/49 (old 47 still pass).
Preserve accepted repairs. Three new queued tasks address the user's control/fairness feedback; the rest
of the brainstorm stays backlog. Priority is repair, human-playable match slice, then career expansion.

## Phases and readiness

1. Complete correctness and tactical repair, then V01/INPUT04/INPUT05/AI06. Preserve old checks and the
   production physics. Test the human control slice before making opponent intelligence the only goal.
2. Complete T01/B01/B04 and deliver a named playable checkpoint for PLAY01, then build PC00–PC09 in
   small increments reusing that foundation. The new mode is required scope,
   not merely another optional brainstorm item. Do not stop at a character editor or one match.
3. Apply remaining selected match improvements T07/T08/P01. Implement them once in shared
   mechanics; all relevant modes benefit. PC05 can assign existing TeamTactics values before T07 refinement.
4. PLAY01 is a recurring human/Windows gate at runnable checkpoints and the final changed revision. If that
   environment is unavailable, keep it open and continue independent ready automated work. Never label the
   full release/play feel accepted on that basis. Rerun affected career integration after later mechanics change.

Dependency satisfaction enables a task; this priority order selects among ready tasks. If a higher task is
genuinely blocked, record the reason and take an independent ready task. Preserve completed colleague work.
No session is expected to finish all 36 entries before a token limit; every session must leave a resumable
checkpoint and continue as far as its actual capacity allows.

The remaining ideas in IMPROVEMENT_IDEAS.md stay backlog: in particular B02/B03, T02–T06, T09, B05,
V02/V03, U01/U02, P02, A01 and the parts of C01–C03 not covered by PC contracts. Do not silently promote
all of them to required work, or silently delete them. The idea register explains the overlaps.

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

Status: **DONE** (session 2, 2026-11-14). Results on the implementation branch:
`run_scenarios.gd` full -> TOTAL 67/72, exit 1 (the five `attack_3v2` episodes are still open under AI03);
`--only=blocked_lane` -> 9/9, exit 0; `--only=unknown_case` -> message + exit 2; zero episodes -> exit 2.
`tools/shot.sh`: missing dependency -> exit 2 and no image; missing scene -> exit 3; success requires engine
exit 0, no script error and a PNG signature. `tests/run_tests.gd`: both tautologies replaced by real
invariants (line-up legal after every sale without repair; league money conserved given the test's own
budget mutation) -> 300 checks, 0 failed; `-- --violate=budget` and `-- --violate=lineup` each fail exactly
that check with exit 1. Scenario predicates were not changed. The 3v2 failures are now correctly reported
failures, not a QA01 defect.

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

Status: **DONE** (session 2). `_try_kick` now calls `_offside_involvement(p)` before any kick metadata is
replaced; `_register_touch` uses the same helper. Review case passes (offsides=1, shots=0, defending free kick).
New tests in `test_offside`: flagged first-time shot in both attacking directions (one whistle, no kick, no
goal after 240 further ticks), onside first-time shot executes, throw-in exemption and double-touch bar.
310 core checks pass; legacy scenarios unchanged at 67/72.

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

Status: **DONE** (session 2). `TeamAI.take_run_event()` delivers a scheduled runner event exactly once at or
after its tick, expires it after `RUN_EVENT_MAX_AGE` (20 ticks) and `on_restart` discards it; `OnBallAI.drive`
uses it. Review `run_trigger` passes (all five review regressions now pass). `test_run_event` (11 checks).
Decision frequency in real `run_behind` episodes (`tools/probe_run_event.gd`, 9 episodes, counts existing
decisions only): 0.5 s after a runner event **9.29 avg / 15 max before the fix -> 2.75 avg / 4 max after**
(normal cadence about 3.3). Effects measured with and without this change on otherwise identical code:
8 full matches 13 goals, 8.6 shots/match -> 22 goals, 10.9 shots/match, 0 stalls, 0 conflicts in both.
Scenario matrices with unchanged predicates: legacy 67/72 (same five `attack_3v2`); extended seeds 44..99
**122/144** (baseline 123): `human_support` 17->18 and `high_loss` 14->15 improved, `blocked_lane` 18->15.
The three new `blocked_lane` failures (v2 seeds 77, 88, 99) appear only with this change: at the intended
decision cadence the carrier keeps a dribble commitment while an opponent closes from behind (v2/77: tackled
at 2.25 s without a pass) or passes later/into pressure. They stay open and are assigned to AI02
(forecast vs executed movement and commitment under approaching pressure); reproduce with
`tools/probe_scn.gd -- --name=blocked_lane --variant=2 --seed=77 --secs=5`.

## AI02 — Align dribble forecasts with executed movement

Files: src/ai/on_ball_ai.gd, decide; src/sim/sim_query.gd; src/sim/match_sim.gd, _move_players;
src/sim/sim_player.gd and game_tuning.gd where appropriate.

Evidence: candidate ETA assumes top_speed * dribble_speed_ratio, but a non-sprint command actually uses an
additional jog_ratio multiplier. Sprint is chosen after estimating the candidate.

Independent review at bbe7dbb confirms blocked-lane regressions: v2 seeds 77/88/99, plus v0/107 and v2/199.
At v2/77 the carrier is tackled at 2.25 s without passing; new-seed cases pass into the blocked lane.
Inspect commitment AND decision deadlines under closing pressure (`urgent` does not bypass the
`now < next_decision` term). The speed-model mismatch is evidence, not a proven sole cause.
Review seeds 107/131/167/199 give 85/96 overall versus historical 89/96; they are now known data.

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
- Resolve the five named blocked-lane regressions without changing predicates or weakening defenders;
  trace remaining failures explicitly. Compare all known matrices and reserve new seeds/geometry before tuning.

Status: **REOPENED** after independent gameplay review. Retain the session-3 normal-gait correction below.
Remaining contracts: `tools/gameplay_review.gd --case=carry_recovery` reports helper 1.488 versus real cap
1.6 m/s; `--case=urgent_pressure` holds a stale command with ETA=0 while 0.1 s remains on the ordinary
deadline. See CLAUDE_BUGFIX_PROMPT_EN.md: match recovery branches/validity and implement bounded
urgent-entry reconsideration without planning every tick. Retain normal-pressure and runner-event controls.

Session-3 implementation evidence (normal actionable states; defensive regressions remain AI05):
- Shared helper `SimQuery.carry_speed / carry_time` mirrors `_move_players` (jog_ratio, dribble_speed_ratio,
  stamina gate, recovery cap, current velocity, accel/decel). `OnBallAI.decide` scores a jog and a sprint
  candidate per direction with their real times and commands the gait it scored (`dribble_sprint_min_stamina`,
  `dribble_sprint_control` in GameTuning). The old constant `top_speed * ratio + 0.15 s` estimate and the
  post-hoc sprint rule are gone. No utility weight was changed.
- Forecast vs execution (`test_carry_forecast`): 54 straight 6 m cases (pace 0.15/0.5/0.9, stamina 1.0/0.45/0.1,
  jog/sprint, v0 0/3/5) worst error **0.019 s** (bound 0.15); turning cases worst **0.162 s** (bound 0.35:
  the helper only approximates shedding sideways speed and bringing the ball round). Old estimate was off by
  more than 0.25 s for a jog.
- Named blocked-lane regressions (v2 seeds 77/88/99, v0/107, v2/199): all pass; `blocked_lane` 18/18 extended, 12/12 review seeds.
- New baseline, predicates unchanged (before -> after this task):
  legacy seeds 11/22/33: 67 -> **63/72** (attack_3v2 4/9, wing_defence 9 -> 8, high_loss 9 -> 6);
  extended 44..99: 122 -> **129/144** (blocked_lane 15 -> 18, attack_3v2 5 -> 13, high_loss 15 -> 11, wing 17, buildup 16 -> 18);
  review seeds 107/131/167/199: 85 -> **88/96** (attack_3v2 9/12, high_loss 8/12).
  All seeds are known data now; reserve new seeds before tuning AI05/AI03.
- Full matches seeds 1..8, 360 s, 70v70: 2W/4D/2L, goals 7:9, **15.2 shots/match** (was 10.9), middle third
  43–52 % (was 57–65 %), pass completion 77–94 %, 0 stalls, 0 conflicts; 84v62: 7W/1D/0L, 24:5.
- Open, traced to the correction rather than to tuning: carriers now sprint with the ball when it is safe, so
  counters travel 50 m in the 7 s `high_loss` window and only 4 defenders are goal-side at the end
  (legacy v0/11, v2/11, v2/22). `wing_defence` v2/22: single presser 83 % (< 85 %). Tackle attempts in full
  matches fell to 0–6 per team (were about 15–30). These belong to **AI05** (recovery / engagement),
  not to weaker attackers.

## AI03 — Exploit 3v2 without sacrificing football quality

Files: on_ball_ai.gd (decide / _next_option); team_ai.gd (_plan_attack, _counter_chance,
_update_engage, _drive_runner); kick_planner.gd and field_value.gd only as evidence warrants.

Reproduce:

    godot --headless -s tools/probe_scn.gd -- --name=attack_3v2 --variant=0 --seed=11 --secs=10 --duties
    godot --headless -s tools/run_scenarios.gd -- --only=attack_3v2 --seeds=11,22,33

Baseline: 4/9. In seed 11 the winger repeatedly prefers outward dribbles and reaches the corner without a shot.
PROGRESS.md records an already reverted break-mode experiment; investigate its failure before retrying it.
Current independent 3d08f8b: legacy 4/9, known extended 13/18, previous review 9/12, fresh review
211/257/313/373 only 1/12. These fresh seeds are now known; reserve new seed/geometry controls before tuning.

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

Status: **DONE** (session 2). With a held direction the fallback cone is 1.5 rad (`assist_cone_wide_aimed`),
candidates with a non-positive projection on the aim are rejected, and a planned lead that would point behind
the aim becomes a space pass; without input the old 1.75 rad facing fallback remains. Cone values moved to
`GameTuning`. Review `forward_pass` passes. New `test_pass_assist` (19 checks): both teams x both attack
directions x five aims x three pass kinds x angles 0..180 on both sides, 85-degree lateral still chosen,
95+ never, moving receiver, no-input fallback, and an assisted pass cut out by an opponent.
New `deep_audit.gd --case=camera_input` checks the four keys through the real match camera.

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

Status: **DONE** (session 2). Explicit idempotent `MatchSim.dispose()` disconnects all `event` listeners and
releases TeamAI (`TeamAI.dispose`), SimTeam.ai and HumanController back-references; `MatchReport.detach()`.
Called by real owners: `match_view._exit_tree`, run_match, run_scenarios, fuzz_human, career_journey,
snapshot/probe tools and the test harness (per group). Review `lifetime` 0/12 alive; new
`deep_audit.gd --case=match_lifetime` 0/10 alive (stepped AI/human headless matches with a report, two
scenarios with capturing listeners, four match-scene start/exit cycles). Headless tools now exit without
ObjectDB/resource warnings. Residual, not a match cycle: scene-based SceneTree-script cases still print one
"ObjectDB instances leaked" line for 6 `AudioStreamPlaybackWAV` objects of the Sfx autoload at quit
(verbose list contains no GDScript/match objects); not suppressed.

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

Historical status: reopened at bbe7dbb, closed in session 3 below. Current status **DONE**.
Original session-2 implementation:
`CareerState.validate` rewritten for untrusted data: container/field type,
range and cross-reference is checked before typed access (season/round/season_over consistency, player and
club records, 11-man line-up with keeper, fixture season/round/score/played consistency, lists).
`run_deep_audit.py --group save` -> **32/32** (30 original + `both_invalid`, `missing_backup`), no script errors;
review `save_integrity` passes; 24 validation checks added to `test_save_load` (342 core checks, 0 failed);
`deep_audit.gd --case=career_stress` 8 careers x 3 seasons clean; `career_journey.gd` OK.

Historical remaining acceptance (closed by session 3 below; see SESSION2_REVIEW_2026-11-14.md):
- `missing_history`: reject or explicitly default/migrate the missing field before returning a career;
  finishing a season must not fail after load.
- `extra_attribute`: validation and normalization must cover the same domain; malformed unknown attrs
  cannot raise an int constructor error or bypass backup recovery. Document reject/discard policy.
- `fitness_type`: validate consumed optional fields (fitness finite and physically bounded when present).
- `duplicate_pair`: validate per-round club participation and directed-pair multiplicity; unique IDs and
  fixture count alone are insufficient. Keep legitimate partial current-round state legal.
- Extend isolated backup controls and run the expanded driver (42/47 at that historical checkpoint).
  Preserve original 32 save controls, core checks and career stress. Do not weaken tests to retain DONE.

Session 3 closure of the reopened SAVE01 items (implementation after review at bb03a1a): **DONE**.
- `missing_history`: accepted as a legacy shape; `normalize` defaults missing `history`,
  `last_round_results` and per-player `growth`; `_award_prizes` no longer assumes the key. A loaded legacy
  career finishes its season, rolls over and saves again (test).
- `extra_attribute`: policy = **reject**. The attribute set is closed (`Attr.KEYS`); unknown keys fail
  validation (backup recovery applies) and `normalize` iterates only `Attr.KEYS`. Growth keys likewise.
- `fitness_type`: optional `fitness` must be a finite number in 0..1; normalized to float.
- `duplicate_pair`: every club plays at most once per round and every directed pairing appears once.
- `run_deep_audit.py` (all groups) -> **47/47, exit 0**; core tests 437/0 (14 new checks); journey OK.

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

Status: **DONE** (session 2). `_register_touch` no longer clears `backpass_team` on the receiving keeper's
own touch. `deep_audit.gd --case=backpass_feet` passes; new `test_backpass` (8 checks) covers foot control,
losing and regaining the ball, opponent touch, keeper throw and a team-mate's deflection. 318 core checks pass,
legacy scenarios 67/72, four full matches without stalls/conflicts.

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

Status: **DONE** (session 2). `MatchSim.substitute` now calls `SimPlayer.reset_transient()`, sets stamina from the
incoming player's fitness, drops his slot's offside flag, gives the slot a fresh `AIAgent`
(`TeamAI.on_substitution`, forces a replan) and clears a human's shot charge. `deep_audit.gd
--case=substitution_state` passes; new `test_substitution` (26 checks): AI slot, human slot, keeper slot,
ball owner / keeper-in-hands rejection, arriving ball, five-sub limit, bench membership, both UIDs in
`participants`, full-time rejection. Scene refresh: the existing `substitution` event still updates the shirt
number; known cosmetic limit: the rig keeps the outgoing player's skin/hair colours (set once from the UID).

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

Status: **DONE** (session 2). `HumanController.update` hands control to `ball.kick_receiver` when it is a valid
outfield team-mate; `TeamAI.receiver_id` is only the fallback; later ownership still follows the owner rule.
`deep_audit.gd --case=pass_handoff` 3/3 (seed 44 fixed, geometry/inputs untouched); `human_support` scenario
9/9 on legacy seeds and 18/18 on seeds 44..99; new `test_handoff_receiver` (11 checks: both teams x both
directions, flicker, keeper receiver, space pass, opponent id/interception); fuzz 12 seeds OK.

## INPUT03 — Cancel/resynchronize input around pause and focus loss

Files: src/view/match_view.gd, set_paused / _unhandled_input / _sample_input; HumanController charge state.
Reproduce:

    godot --headless -s tools/deep_audit.gd -- --case=pause_shot

Acceptance:

- Hold K, pause, release K, resume: no shot until a new deliberate gameplay action.
- Holding through resume follows a documented consistent policy without resurrecting a stale release.
- Normal charge/release, input edges, pause-menu buttons and losing/regaining window focus behave correctly.
- Simulation clock/AI/cooldowns remain frozen in pause; no queued pass/tackle leaks out of menus.

Status: **DONE** (session 2). Policy: pausing or resuming cancels any charge and pending edges
(`HumanController.reset_actions`); a shot key still held after resume is ignored until it has been released
once (`shot_blocked`), so neither holding through nor releasing during pause produces a shot; losing window
focus pauses a human match (`match_view._notification`). `deep_audit.gd --case=pause_shot` passes; new
`--case=pause_policy` verifies on the real scene: normal charge/release shoots, sim tick/clock/cooldown frozen
in pause, no shot while held or on release after resume, a fresh press shoots, queued pass/tackle edges do
not leak, focus-out pauses and cancels. Real OS focus events and pause-menu buttons with a physical keyboard
remain part of PLAY01.

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

Historical status: reopened at bbe7dbb, closed in session 3 below. Current status **DONE**.
Original session-2 implementation:
`LeagueData.auto_lineup` contract: exactly 11 unique ids or `[]` (never partial),
malformed/duplicate entries ignored, best candidate chosen with `-INF` start (negative scores allowed), fitness
applied before the position penalty. `CareerState.auto_lineup` / `_repair_lineup` are all-or-nothing and
return bool; the UI shows `LINEUP_INVALID` on refusal. `deep_audit.gd --case=keeper_only_lineup` passes without
script error; `run_deep_audit.py` -> **42/42, exit 0**. New `test_lineup_robustness` (12 checks; the 16-GK
roster is adversarial and has no UI route). Career stress and journey still pass.

Historical remaining acceptance (closed by session 3 below): the low-keeper probe failed with a legal squad,
two actual keepers at attributes 1 and outfield players at 99 (all schema-valid): finite penalties select
an outfielder in goal, so auto_lineup refuses even though a legal eleven exists. Make goalkeeper eligibility
a hard constraint for slot zero, then score eligible candidates; retain out-of-position outfield choices and
all-or-nothing rejection of impossible squads. Recheck existing 16-GK/short/no-GK/transfer controls.
This is an adversarial legal-data robustness case, not a demonstrated ordinary UI path.

Session 3 closure of the reopened CAREER01 item: **DONE**. `LeagueData.auto_lineup` applies eligibility
before rating for the goal: while any goalkeeper is in the pool only goalkeepers are candidates for slot 0.
`session2_review.gd --case=legal_low_keeper` passes; tests cover keepers rated 1 with outfielders rated 99
(legal team accepted, real keeper in goal, second keeper not used outfield).

## AI05 — Diagnose and repair recovery on the extended matrix

Files: src/ai/team_ai.gd, _update_side / _plan_defend / _update_engage / _drive_press / _drive_mark;
scenario_lib.observe/judge for evidence only unless a counterexample proves a predicate defect.
Reproduce:

    godot --headless -s tools/run_scenarios.gd -- --only=high_loss --seeds=44,55,66,77,88,99
    godot --headless -s tools/probe_scn.gd -- --name=high_loss --variant=1 --seed=44 --secs=8 --duties
    godot --headless -s tools/probe_scn.gd -- --name=wing_defence --variant=2 --seed=88 --secs=8 --duties

Current 3d08f8b high_loss: 6/9 legacy, 11/18 extended, 8/12 previous review, 7/12 fresh.
Wing defence: 8/9, 17/18, 12/12, 11/12. `gameplay_review.gd --case=transition_trace` shows v0/11
leaving DEF_TRANS after four seconds while several zone/protect players still jog 7–15 m behind moving
anchors at t=5–7 s. Only four are goal-side at the end. This supports a contributing recovery mechanism,
not a proven universal root cause. Inspect persistence, anchor motion, press/cover and engagement together.
Acceptance:

- Explain each failing episode with time-series positions, phase/duty changes, available cover and threats.
- Distinguish legitimate end-of-episode geometry from sustained central abandonment; prove predicate changes
  with a counterexample, keeping legacy/new metrics separately labelled.
- Eliminate the identified assignment/recovery defect on the four high_loss and one wing episode while
  preserving effective delay/containment, no swarming, and all original defensive scenario verdicts.
- Recheck fresh seeds, possession changes, both halves, press/cover commitments and full-match chances conceded.

## V01 / T01 — First match-improvement slice

V01 scope is now expanded by HUMAN_GAMEPLAY_SPEC.md section 4: landing versus intercept versus current
shadow, controlled player and next-switch preview, visibility/camera/radar. Presentation toggles alone must
leave sim/RNG snapshots identical. Implement before INPUT04 so assisted intention is readable.

Detailed hypotheses and extension points: [IMPROVEMENT_IDEAS.md](IMPROVEMENT_IDEAS.md).

V01: compare camera/ball/stadium/radar readability at 720p and 1080p, both halves and near/far touchlines.
Preserve physical ball size/collisions; visual emphasis and settings must not change simulation results.
Use matched snapshots and moving evidence, then human feedback. Keep a wider tactical view available.

T01: extend the existing passer memory, support duties and next-option evaluation with one give-and-go /
third-man experiment. Open return lane, tracked passer and blocked return require distinct useful choices.
No compulsory ping-pong or scripted success. Recheck input handoff, offside, overloads, recovery and match
variety. Keep only an evidenced improvement; a well-documented rejected experiment is an honest result.

## INPUT04 — Held defensive approach and containment

Contract: HUMAN_GAMEPLAY_SPEC.md sections 1–2. Add one explicit held action (proposed Space), separate
from Q tackle. Move the controlled outfielder into a useful goal-side approach and brake/contain nearby.
Manual input wins immediately; release, pause/focus, switch/substitute identity, possession/restart/full-time
boundaries cancel/rearm safely. Shared physical speed/stamina/contact/cooldown rules apply. No guaranteed
takeaway, teleport or whole-team control rewrite. Manual/Semi-assisted presets have Russian help.
Verify both sides/halves, front/side/behind, moving/lost target and actual motion; assistance-off preserves
the old command path. Initial slice excludes automatic tackling and a full key-rebinding framework.

## INPUT05 — Bounded receiving and loose-ball approach

Contract: HUMAN_GAMEPLAY_SPEC.md section 3. Reuse INPUT04's held action for a reachable free-ball intercept,
plus bounded initial movement help after TEAM receiver handoff in Semi-assisted mode. Manual direction,
kick intent, opponent contact, timeout and identity boundaries cancel appropriately. Do not magnetize the
ball, enlarge contacts, change flight or guarantee receipt. Test rolling/lofted/deflected/unreachable balls,
height limits, manual escape and actual contacts. PC01 later retains stable-UID locked control.

## AI06 — Bounded pursuit perception and independent assistance profiles

Contract: HUMAN_GAMEPLAY_SPEC.md section 5. Introduce deterministic cached ball-reading estimates,
bounded observation/reaction and stable uncertainty, starting with pursuit only. Keep authoritative physics
exact, tactical coordination competent and aids independent from opponent difficulty. No future-input reads,
future collision knowledge, score-based boosts or per-frame random twitching. React to new deflections with
a delay; use named tunables/seeded stream ownership and dispose caches. Measure sensing/update/interception
at each profile, both sides, with easy reception controls and tactical counterchecks. No test-only perception
bypass. Human PLAY01 still determines playability; no player-career mode is claimed implemented.

## PC00 — Player-career state, identity and save foundation

Contract: PLAYER_CAREER_SPEC sections 2–3. Inspect CareerState, SaveManager, Game, MatchSetup and club result
absorption before adding code. Establish explicit mode, stable avatar UID, profile namespace, fixture context
and the result/training/transaction award ownership. Introduce career tuning with an explicit schema/migration.
Use focused pure helpers as needed; proposed module ownership is in PROJECT_MAP.md, not a scaffold checklist.

Acceptance:

- Old valid club saves load/migrate with IDs, played results, budgets and lineups preserved; future/corrupt
  schemas fail/recover cleanly under the corrected SAVE01 contract. Test isolated copies, including backups.
- Club and player slots do not overwrite or misidentify each other. Avatar UID resolves to the world player.
- Quick match and club career defaults remain TEAM mode. Record actual new schema/API/fixture routing decisions
  and add meaningful positive/negative migration/mode tests. Do not mark a planned module as implemented.

## PC01 — Locked control and a real player's match lifecycle

Contract: spec section 2. Files: MatchSetup, HumanController, InputFrame, TeamAI, MatchSim substitution,
match_view, match_camera, HUD and mode-aware result return. Preserve INPUT02 behaviour in TEAM mode.

Acceptance:

- A pass, another owner, half-time or restart never changes the avatar identity in PLAYER_LOCKED mode.
- Zero active humans off-field, exactly one matching UID on-field; substitution in/out cannot control the
  wrong identity in a reused slot. Test both sides/halves and a goalkeeper/other-player restart taker.
- Pass requests use ordinary AI evaluation with open/covered/offside controls; manual movement is respected.
- Bench skip, real entry, playable appearance, exit and full-time return work; quit early does not bank rewards.
- Camera/help/input reflect the mode. Existing TEAM fuzz/handoff tests still pass without weakening invariants.

## PC02 — Participation facts and fair role-aware assessment

Contract: spec section 4. Inspect MatchSim events/participants, MatchStats, MatchReport and result application.
Record neutral per-UID minutes, entries/exits and actual football facts; assess them outside MatchSim.
Separate role rating, recent form, coach trust inputs and reputation evidence. Show reasons and uncertainty.

Acceptance:

- Outgoing/incoming players' minutes/actions stay separate; pause and bench time create no played minutes.
- A useful midfielder/defender can rate well without scoring. Short cameos, idle action spam, repeated safe
  passes and request spam cannot dominate rating; evidence includes positive/negative role examples.
- Match length conversion is explicit, bounded and tested. Result-only simulations do not invent event facts.
- Repeated assessment is deterministic/idempotent and collectors detach without reviving MEM01 ownership cycles.

## PC03 — Slow growth, weekly training and reward integrity

Contract: spec section 5. Reuse Attr and existing CareerState development through one documented award owner;
add named data-driven growth/focus rates and training-week IDs. Abilities must influence shared match mechanics.

Acceptance:

- Fixed-seed average/bench/excellent/aging cohorts show gradual differentiated growth; report distributions
  against the spec's initial balancing hypotheses and justify adjustments. A legal normal start cannot farm
  90 overall in one season via drills, pass loops, reloads or match-length changes.
- Training provides a viable slower route for a reserve, can be automated after learning, and uses calendar
  weeks rather than real-time login. A chosen style leaves room for later development choices.
- Repeated fixture results, menu returns, reloading and training retries award neither extra apps nor duplicate
  XP/attributes. Old _develop and the avatar pipeline cannot both grant full growth for the same appearance.
- Simple growth/condition feedback works; never advertise a dominant-foot/style effect absent from execution.

## PC04 — Coach trust, competition and earned minutes

Contract: spec section 6. Coach selection uses actual rivals, role/tactic fit, form, condition and bounded trust.
Provide prospect/rotation/starter/key roles, contextual objectives, substitution decisions and recovery paths.

Acceptance:

- Sustained useful play can earn more minutes before major attribute growth; one error does not erase a season.
- A ten-minute cameo and a defender's assignment receive appropriate expectations; no mandatory striker quota.
- A weaker club and a crowded elite club produce different plausible roles, with visible reasons and rivals.
- Omitted/bench/subbed-out states remain playable through training, next opportunity or a later loan; no dead
  end. Planned substitutions obey the common limits and preserve PC01 identity/PC02 participation.

## PC05 — Shared multi-league calendar and an aging world

Contract: spec sections 3,7. Extend CareerState, Schedule and LeagueData, with a focused world/calendar helper
if useful. Scope the initial world through data (target three eight-club leagues/eight represented nations).
Preserve old one-league club-calendar behaviour. Store roles/styles using existing TeamTactics until T07.

Acceptance:

- Each competition has valid references, unique fixtures, correct tables and bounded dates. Contextual routing
  cannot apply an international result to a club round or use one global ROUNDS constant for every competition.
- Training, club dates, international windows and season rollover advance once without overlapping player
  appearances. One player record serves club/country; `user_club` is not overwritten by a national match.
- World generation has valid club/U21/senior position and goalkeeper pools; unsupported nations cannot be
  selected. Competitors age/develop and new youth replace retirees over long runs. Avatar retirement is explicit.
- Existing club saves remain playable; financial changes are explained by actual transactions/prizes/wages.

## PC06 — Agent offers, renewal, transfers and loans

Contract: spec section 8. Reuse roster/budget transactions, with clear owner versus active registration.
Interest considers position needs, sustained evidence, league level, affordability and fit. Expose meaningful
stay/step-up/ambitious/loan alternatives; show role, competitors, terms and development environment.

Acceptance:

- Ordinary progress can attract plausible opportunities; one great match need not guarantee an elite contract.
- Stay/renew, accepted move, rejected/expired/stale offer, contract expiry, loan and loan return all leave legal
  squads, stable UID and a valid next career action. No arbitrary checklist strands a good career.
- Revalidate both clubs, money, room and dates at acceptance. Duplicate click/result/reload never duplicates
  ownership, registration, fees/wages or offers. Loan return releases the borrower and restores correct registration.
- Actual agent/contract UI actions are keyboard usable; seed tests cover a failed transaction with no partial mutation.

## PC07 — U21 and senior national career

Contract: spec section 9. Add national selection/eligibility, separate coach trust, positional competition,
callups, qualifiers and a finals competition on the shared calendar and engine. Explanations use real candidates.

Acceptance:

- Weak/strong nation and crowded/open position controls produce explainable selection without one universal
  rating cutoff. U21 aging, omission, withdrawal and later recall leave valid squads and career continuation.
- A club match, a callup, a playable international fixture and return preserve contract/squad/budget ownership.
  Caps/national results and club apps/tables are separate; the avatar is never cloned.
- Club/international and U21/senior assignments do not require simultaneous appearances; workload/readiness
  follow the same person. Qualifiers/finals and squad locks can complete, save/reload and start a later cycle.

## PC08 — Full weekly career loop and truthful history

Contract: spec section 10. Reuse UIKit, Game scene flow, HUD and localization; add a player hub/scene only
where its separate flow is needed. Keep club/player creation and save selection unambiguous.

Acceptance:

- Create, train, inspect role/reasons, enter/skip to appearance, finish, review, save, reload and continue work.
- Agent stay/move/loan and national selection/return are reachable from actual UI actions, not console-only code.
- Enabled actions have complete effects; unfinished goalkeeper/lifestyle systems are not presented as working.
- Timeline/season totals derive from committed facts: debut, first start, transfer/loan and national milestones.
  No imaginary injury/manager/captain event without corresponding mechanics. Test 720p keyboard focus/scroll and
  camera/ball readability; record remaining human-play limitations rather than inventing feedback.

## PC09 — Multi-season player-career integration gate

Contract: spec section 11. Add a bounded journey tool and scoped tests as the preceding tasks mature; the
suggested files in the spec are future outputs, not current executable commands. Simulate routine fixtures
and play selected real-engine matches, explicitly distinguishing their evidence and recorded facts.

Acceptance:

- Several seeds finish at least ten automated seasons; one run ages the world for twenty seasons. Include
  real bench entry, rating/growth, club change, renewal, loan/return, U21/senior match and next-season continuation.
- Verify identity/registration accounting (including declared new/retired cohorts), legal rosters/position pools,
  calendars, finances, fixture/reward uniqueness,
  bounded growth, country/club separation, voluntary retirement and a valid continuation after poor form.
- Legacy migration plus invalid main/backup recovery and isolated slot checks pass; repeated UI results and
  reloading do not duplicate state. Collectors/sims release their ownership and all physical state stays finite.
- Rerun affected original match/club/audit checks, documenting unresolved IDs honestly. Extend PLAY01 for
  actual player-locked Windows play; automated success alone does not close it.
- Publish actual commands/seeds/revision/results and a runnable checkpoint. A partial vertical slice is not DONE.

## B01 — Directional first touch

Idea register B01. Extend shared first-touch/ball-control commands and presentation coherently; account for
arrival speed, body orientation, pressure and ability. Make room for receiving into space/protecting the ball.
Acceptance: manual direction has predictable effect; open/pressured controls differ meaningfully; the ball
never teleports or becomes guaranteed possession. AI/human share execution. Test both halves, passes/rebounds,
control attributes, input response and PC01/PC02/PC03 integration. Keep this separate from AI02 forecast repair.

## B04 — Shot preparation and deliberate height/power

Newly agreed brainstorm direction. Inspect HumanController._shot, KickPlanner, MatchSim, input/help and tuning.
Provide a clear way to prepare/aim a shot and execute a powerful low shot; an intentional lofted attempt remains
possible. Avoid accidentally changing shot type merely because sprint is held; document any binding changes.
Acceptance: weak/strong low shots and deliberate high shots respond predictably to input and shared attributes;
pressure/angle affect physical execution. Charge/pause/restart/input-edge regressions and AI shot planning still
pass. Update UI/help and test player-locked play; animation may not introduce an artificial command delay.

## T07 — Distinct team styles

Idea T07, refining the TeamTactics values/world labels used in PC05. Start with balanced, fast transition and
patient build-up; expose understandable controls where appropriate. Acceptance: matched configurations show
measurable differences in spacing/risk/tempo with useful example traces; no physical stat boosts or weakening
the user's teammates. Club offers accurately describe the actual style. Preserve recovery and chance quality.

## T08 — Coordinated attacking rotations

Newly agreed direction. Extend existing TeamAI anchors/duties/rest defence: winger inside, overlapping full-back,
and a compensating midfielder when the opportunity exists. Acceptance: the rotation creates a useful alternative,
with distinct blocked-run/marked-winger/turnover outcomes; no duplicated lane claims or abandoned central cover.
Do not replace the coordinator or claim its existing full-back/rest-defence mechanism is entirely new.
Check overloads, defence, T01 combinations and actual player-locked off-ball opportunities.

## P01 — Playable training drills

Idea P01. Use ScenarioLib/production AI for a 2v1 decision, a 3v2 counter and escaping pressure. Keep keyboard
play, varied starting arrangements, restart and concise measured feedback. Acceptance: no scripted winning
opponent, open/blocked alternatives require different choices, ordinary mode mechanics remain shared.
Training credit is bounded by PC03's calendar/ledger; replaying a drill cannot farm XP. Automated training stays
viable so the user need not repeat mini-games to continue a slow career. Verify the career UI route and return.

## PLAY01 — Windows and human gameplay acceptance

Status: **USER FEEDBACK / OPEN**. User played an unpinned build and reports frustrating manual pursuit,
unclear flight and overly precise AI. After V01/INPUT04/INPUT05/AI06 deliver a named build and compare
presets with receive/pickup/defend checks. Do not replace human comfort with an AI-only win-rate target.

Use docs/PLAYTEST.md on the actual Windows executable. Record machine/build version, keyboard layout,
settings and observations. Check movement, pass direction, switching, shot charging, tackle timing, teammate
support, difficulty, animation in motion, camera, sound, pause/substitution and career continuation.

Measure FPS on the real hardware. Verify the Windows executable itself rather than running its package with
a Linux engine. Include locked-player control, bench entry/substitution out, career renewal and national return
as those features land. Convert observed problems into reproduced tasks before marking this item complete.

## Starting request for Claude Code

Use [CLAUDE_MASTER_PROMPT_EN.md](CLAUDE_MASTER_PROMPT_EN.md). It defines the full read order, baseline,
architecture, scope, work sequence, commands, evidence rules and release gates. Resume the Active handoff and
continue through ready tasks. Preserve regressions and report remaining failures honestly.
