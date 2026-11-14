# Extended gameplay and robustness audit

Audit date: 2026-11-14. Engine: **Godot 4.5.1.stable.official.f62fdbde1**, Linux x86-64.
Gameplay baseline: **a47746eba365d3a3a1ffc6693069dc2cab484505**.
Starting review branch: `codex/project-map-ai-plan`, commit `8283045`.
This delivery changes documentation and audit tools, **not gameplay implementation or tuning**.

Read this alongside [the original code review](CODE_REVIEW_2026-11-14.md),
[the project map](PROJECT_MAP.md), [the execution queue](AI_WORK_PLAN.md), and
[the Claude master prompt](CLAUDE_MASTER_PROMPT_EN.md).

## What the evidence says

There is a functioning shared simulation, team coordination, career loop and deterministic input path.
The current prototype has reproducible rules, input, lifecycle and save-validation defects. Its tactical
quality does not generalize as well as the original nine episodes per scenario suggest. Passing automated
checks must not be presented as acceptance of fun, responsiveness or a Windows release.

| Check | Actual result | Interpretation |
| --- | --- | --- |
| Fresh import and core suite | Import exit 0; 300 checks, 0 failed, 6.4 s | Core baseline reproduced. Two old assertions are tautologies (QA01). |
| Original scenario matrix, earlier review | 67/72 | Five failures in 3v2; unchanged gameplay code. |
| New scenario seeds 44,55,66,77,88,99 | **123/144**, runner still exits 0 | 21 failing episodes across five scenarios. These seeds are now known validation data. |
| New random-input matches | **12/12**, seeds 4–15, duration 30 s each | Finished, one human-controlled player, no reported stalls. Input robustness, not human feel. |
| Paired deterministic runs | **8/8**, 600 ticks per pair | Four AI-only and four scripted-human pairs; compared physics, RNG, AI/input timers and finite state every tick. Same engine/platform only. |
| Career stress | **8/8**, 3 completed seasons each | 336 rounds, 1,344 fixtures and 672 successful transfers; ownership, budgets, lineups, table arithmetic, attributes and save/load invariants held. |
| Save corruption matrix | **9/30 checks pass** | One valid control and 8 correctly recovered corruptions; **21 corruptions mishandled**, including 8 script-error cases. One validation defect family, not 21 unrelated bugs. |
| New control/rule/state regressions | Substitution, back-pass and pause fail; handoff fails seed 44, passes 11/55 | Concrete production code paths, reproducible below. |
| Adversarial auto-lineup | Runtime error with 16 generated goalkeeper records | Robustness gap; ordinary UI reachability has not been demonstrated. |
| Strength 84 vs 62, home then away | 12 matches, 180 s each: stronger side 9 wins, 3 draws, 13:0 | Attribute advantage survives changing sides. Small sample; not a calibrated difficulty claim. |
| Visual inspection | Seven actual 3D/UI captures; six-second rendered match, three sampled motion frames inspected | Readability observations below; no real keyboard playtest, audio judgment or Windows execution. |

The extended runner reports **11/37 subprocess cases passing, exit 1**. This denominator includes grouped
determinism/career cases; do not add it to the 300 core assertions or the 144 scenario episodes.
It requires completion markers and rejects GDScript runtime errors even when the process returns zero.
Known ObjectDB/resource lifetime warnings remain in the logs and are tracked by MEM01.

## New scenario results

Each row is three variants × six seeds. Success predicates are the unchanged legacy predicates.

| Scenario | New result | Failure detail |
| --- | --- | --- |
| `buildup_pressure` | 16/18 | v1 seeds 44,66 lose the ball in their own third. |
| `blocked_lane` | 18/18 | Legacy first-action predicate passes. |
| `attack_3v2` | **5/18** | 13 moves produce no shot in the episode window. v0: 1/6; v1: 1/6; v2: 3/6. |
| `wing_defence` | 17/18 | v2 seed 88: single presser 79%, central cover condition 64%. |
| `high_loss` | **14/18** | v1 seeds 44,77; v2 seeds 44,66. Missing recovery behind the ball and/or clear delaying role. |
| `run_behind` | 18/18 legacy | Through/lofted delivery only 2/18; the legacy verdict still accepts an intent flag alone (AI04). |
| `shot_rebound` | 18/18 | Legacy resolution predicate passes. |
| `human_support` | 17/18 | v0 seed 44: control goes to #7 although the pass is addressed to #9. |

Across the original and extended matrices the unchanged legacy score is **190/216**. This is a diagnostic
summary, not a percentage of "intelligent football". In particular, the run-behind predicate remains weak.
Future tuning needs newly reserved seeds and arrangements; the six seeds in this audit are no longer unseen.

## Newly reproduced findings

### SUB01 — A substitute inherits the outgoing player's action state

**Confirmed, P1.** `src/sim/match_sim.gd`, `substitute` and `_apply_identity`; per-player state in
`src/sim/sim_player.gd`. The same SimPlayer slot gets a new identity but only stamina is reset.

Observed after a successful replacement: new UID, old `stun=0.8`, `tackle_cd=1.2`, a pending shot, and
`distance_run=4500`. In real play, replacing a recovering or queued-action player can burden the fresh
substitute or execute an action the substitute never requested. The probe deliberately arranges these
reachable states; it does not claim every ordinary substitution has all of them simultaneously.

    godot --headless -s tools/deep_audit.gd -- --case=substitution_state

Reset outgoing-player action/recovery/input and AI memory deliberately. Preserve the formation slot,
legitimate team assignments and both identities in participation history. Specify whether distance is
per identity or per slot; new-player individual statistics must not inherit it silently.

### RULE02 — A goalkeeper's foot control erases the back-pass restriction

**Confirmed against DESIGN.md's existing back-pass contract, P1.** `match_sim.gd`, `_register_touch`,
`_give_possession`, `_may_handle`. A defender's deliberate pass has `backpass_team=0`.
Before the goalkeeper receives it with his feet, handling is forbidden. `_register_touch` clears the flag
because keeper ID differs from kicker ID. Handling then becomes permitted without an intervening player.

    godot --headless -s tools/deep_audit.gd -- --case=backpass_feet

Preserve the relevant touch history through the goalkeeper's own control. Add a subsequent physical
loose-ball contact case and legal opponent-touch/keeper-distribution counterexamples. Do not expand this
into a complete foul/discipline system; those mechanics remain deferred by the original brief.

### INPUT02 — Automatic handoff overrides the selected pass receiver

**Confirmed, P1.** `src/input/human_controller.gd`, `update`; `src/ai/team_ai.gd`, `_ball_claims`.
At seed 44, human_support variant 0, tick 71: #6 passes to #9. At tick 72 control switches to #7.
HumanController prefers `tm.ai.receiver_id` over `ball.kick_receiver`; the team planner may choose a
different interceptor. That is reasonable AI coordination but violates the documented human handoff.
The same check passes seeds 11 and 55, giving positive controls.

    godot --headless -s tools/deep_audit.gd -- --case=pass_handoff

Preserve the user's selected eligible receiver during the initial handoff. Define a deliberate fallback
for unavailable/invalid receivers, interception, own goalkeeper and later possession. Avoid per-tick
control flicker. Keep the physical interception outcome uncertain.

### INPUT03 — Releasing a charged shot while paused fires it on resume

**Confirmed, P1.** `src/view/match_view.gd`, `set_paused`/`_sample_input`;
`human_controller.gd`, shot-charge state. Pausing clears view input edges but preserves `charging`.
If K is released in the pause menu, the next update sees `not shot_held` and creates a shot.

    godot --headless -s tools/deep_audit.gd -- --case=pause_shot

Cancel or explicitly resynchronize the pending charge on pause/focus loss. Test release in pause,
holding through resume, normal charge/release, and pause-menu actions. No stale kick should be emitted
without a new deliberate gameplay action. The current probe exercises the real match scene methods.

### CAREER01 — Auto-lineup assumes a nonnegative candidate exists

**Confirmed robustness error, P2; ordinary UI reachability unverified.** `league_data.gd`, `auto_lineup`.
The initial candidate score is -1. A goalkeeper placed in an outfield slot can score lower after the
60-point penalty. With a pool of 16 real generated goalkeeper records, no candidate beats -1;
`best["id"]` raises a runtime error and the returned lineup is empty.

    godot --headless -s tools/deep_audit.gd -- --case=keeper_only_lineup

Use a valid fallback search or a clean, surfaced roster rejection. Add insufficient-player and missing-GK
cases. The hard gate is absence of script errors/partial mutation, not forcing an impossible legal lineup.

### AI05 — Defensive recovery is fragile outside the original seeds

**Observed tactical failures, P1; root cause not established.** New high_loss cases have as few as one
outfield player goal-side at episode end; wing_defence v2/88 abandons the centre by its existing metric.
Trace phase transitions, attacker progress, assignment lifetimes, runner/mark recovery and available
cover. A final-frame count can also overstate a transient failure: validate the time series before changing
behaviour or rewriting the predicate. Keep genuinely useful delaying/containment choices.

    godot --headless -s tools/probe_scn.gd -- --name=high_loss --variant=1 --seed=44 --secs=8 --duties
    godot --headless -s tools/probe_scn.gd -- --name=wing_defence --variant=2 --seed=88 --secs=8 --duties

## Save matrix

The valid backup is created twice before overwriting only the isolated primary. Every invalid case should
recover that backup without script errors. A valid primary should load without recovery.
`round_string` currently coerces an invalid value into a number instead of rejecting it. Wrong nested
types can reach typed loops or normalization; errors do not reliably prevent a broken career being returned.
The [raw summary](evidence/deep-audit-2026-11-14/extended/summary.json) and individual logs retain every result.

| `valid` | PASS | false | expected behaviour |
| `broken_json` | PASS | true | expected behaviour |
| `root_array` | PASS | true | expected behaviour |
| `missing_schema` | PASS | true | expected behaviour |
| `unsupported_schema` | PASS | true | expected behaviour |
| `wrong_players_container` | PASS | true | expected behaviour |
| `negative_budget` | PASS | true | expected behaviour |
| `missing_player` | PASS | true | expected behaviour |
| `duplicate_fixture` | PASS | true | expected behaviour |
| `round_high` | FAIL | false | invalid primary accepted |
| `round_negative` | FAIL | false | invalid primary accepted |
| `round_string` | FAIL | false | invalid primary accepted |
| `season_zero` | FAIL | false | invalid primary accepted |
| `season_over_type` | FAIL | false | invalid primary accepted |
| `lineup_duplicate` | FAIL | false | invalid primary accepted |
| `lineup_empty` | FAIL | false | invalid primary accepted |
| `lineup_no_keeper` | FAIL | false | invalid primary accepted |
| `squad_type` | FAIL | false | script error |
| `club_null` | FAIL | false | script error |
| `player_null` | FAIL | false | script error |
| `attrs_type` | FAIL | false | script error |
| `attr_missing` | FAIL | false | invalid primary accepted |
| `attr_range` | FAIL | false | invalid primary accepted |
| `age_missing` | FAIL | false | script error |
| `fixture_score_negative` | FAIL | false | invalid primary accepted |
| `fixture_season_missing` | FAIL | false | script error |
| `fixture_played_type` | FAIL | false | invalid primary accepted |
| `fixture_self_match` | FAIL | false | invalid primary accepted |
| `transfer_list_type` | FAIL | false | script error |
| `history_type` | FAIL | false | script error |

The eight normal career stress checks initially compared serialized text exactly. That detects harmless
rounding of fractional development growth in Godot JSON. The final check compares structure/IDs/integer
state exactly and allows at most 1e-5 absolute difference for float-to-float values. With that documented
round-trip contract, all eight careers pass. No gameplay bug was filed for formatting differences.

## Visual review and boundaries

Actual OpenGL captures used Mesa llvmpipe, without a hardware GPU. A rootless virtual X server was used;
the old `tools/shot.sh` wrapper was bypassed because its missing-dependency/error handling is already QA01.
Scenes were captured at 1280×720; the short movie was 960×540, fixed 30 output frames/s, 180 frames.
Only three extracted motion frames were visually inspected; this is not an exhaustive animation review.
MovieMaker output frame rate is not measured gameplay performance.
Capture method reference: [Godot 4.5 MovieMaker documentation](https://docs.godotengine.org/en/4.5/tutorials/animation/creating_movies.html).

Observed product-quality issues, **not crash defects**:

- Small ball and players make possession/first touch hard to read at the broadcast distance.
- Highly saturated, high-frequency stadium seats compete with the pitch; ad boards add more visual noise.
- The bottom-centre radar overlaps the playing area. Offer scale/opacity/placement controls before adding HUD detail.
- Lineup and transfer screens fit the inspected 720p viewport and use scrollable lists. Dense inline attributes
  make comparing players harder than a focused comparison panel would. No clipping defect is claimed here.
- Menus have a consistent palette and visible focus. That does not establish full keyboard navigation coverage.

Reference captures: [match](evidence/deep-audit-2026-11-14/match.png),
[diagnostic](evidence/deep-audit-2026-11-14/diagnostic.png),
[lineup](evidence/deep-audit-2026-11-14/lineup.png),
[transfers](evidence/deep-audit-2026-11-14/transfers.png).

Still unverified: actual Windows EXE startup/export compatibility, real hardware frame pacing, human input
latency and enjoyment, full audio output, long interactive sessions, every resolution/DPI/keyboard layout,
cross-platform determinism, and all possible rule edge cases. Exhaustive testing of a stateful football game
is not a finite deliverable. The named suites provide a repeatable baseline and explicit remaining gates.

## Reproduce and continue

From the repository root, with the exact engine version:

```bash
godot --version
godot --headless --import
godot --headless -s tests/run_tests.gd
godot --headless -s tools/review_regressions.gd
python3 tools/run_deep_audit.py --godot godot --out /tmp/openpitch-audit
godot --headless -s tools/run_scenarios.gd -- --seeds=44,55,66,77,88,99
godot --headless -s tools/fuzz_human.gd -- --seeds=4,5,6,7,8,9,10,11,12,13,14,15 --duration=30
godot --headless -s tools/run_match.gd -- --seeds=11,22,33,44,55,66 --duration=180 --levels=84,62
godot --headless -s tools/run_match.gd -- --seeds=11,22,33,44,55,66 --duration=180 --levels=62,84
```

The two regression commands should fail on this baseline. The scenario command misleadingly exits 0:
inspect its TOTAL and episode verdicts until QA01 is fixed. On Windows use Python 3 and the console Godot
executable for captured logs; choose a writable temporary audit directory. Never corrupt normal player saves.
Do not mix 180-second and 360-second match averages without labeling their duration.

Continue with the ordered tasks in [AI_WORK_PLAN.md](AI_WORK_PLAN.md), then the limited improvement slice
in [IMPROVEMENT_IDEAS.md](IMPROVEMENT_IDEAS.md). Record new evidence rather than editing historical logs.
