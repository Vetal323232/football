# Bug-fix phase: gameplay review at 3d08f8b

This is the detailed repair brief referenced by CLAUDE_MASTER_PROMPT_EN.md, not another task queue.
Use AI_WORK_PLAN.md for status and order. Preserve Claude session-3 repairs and all colleague WIP.
The user explicitly requested tests and a bug-fix prompt before the next feature brainstorm.

## Establish the exact baseline

Implementation reviewed: `3d08f8b150aeadef10081d69a0fce0f050f991c0`; Godot
`4.5.1.stable.official.f62fdbde1`, Linux headless. The review changes tools/docs only.
Read PROGRESS.md Active handoff, then the active queue section and affected owners in PROJECT_MAP.md.
Read GAMEPLAY_REVIEW_2026-11-14.md for evidence, not all historical logs on every resume.

Current checks: core 442/0 failed; original regressions 5/5; pre-existing strict cases 47/47.
Two new gameplay boundary checks expand the strict gate to **47/49, exit 1**. These expose residual
contracts, not a recurrence of fixed save defects. SAVE01 and CAREER01 remain accepted.

```bash
godot --version
python3 tools/run_deep_audit.py --godot godot --out /tmp/openpitch-gameplay --group gameplay
godot --headless -s tools/gameplay_review.gd -- --case=carry_recovery
godot --headless -s tools/gameplay_review.gd -- --case=urgent_pressure
```

## Repair AI02 boundary coverage first

1. `SimQuery.carry_speed` reports 1.488 m/s for a stunned carrier while the real recovery movement
   branch executes 1.6 m/s. It applies the dribble ratio in a branch where `_move_players` does not.
   Make the physical helper agree with execution. Cover jog/sprint and stun/tackle/dive recovery boundaries.
   Distinguish current capped movement from a hypothetical six-metre carry: possession can be lost during
   recovery, and timers can expire before arrival. Do not keep a stunned player in possession to satisfy a test.
   Retain the 54 normal straight-run controls and turning cases. Avoid a second physical integrator.
2. `OnBallAI.drive` computes `urgent=true` at pressure ETA=0 but still returns when `now < next_decision`.
   The independent control shows normal pressure correctly keeps its deadline; a newly arrived opponent
   in reach does not cause reconsideration and the stale command continues for 0.1 s.
   Implement and document a bounded urgent-entry policy. Sudden danger may interrupt ordinary scheduling,
   but sustained danger must not trigger planning every 60-Hz tick. Test entry, continued pressure, relief,
   renewed pressure, settle behaviour, runner events and decision count; retain the normal-pressure control.

These are bounded implementation defects. They do not alone explain the user's entire difficulty complaint
or prove why every failed scenario occurred. Keep causal fixes separate from utility/defender retuning.

## AI05: fix defensive recovery/engagement, preserve competent attacks

Confirmed baseline: high_loss 6/9 legacy, 11/18 known extended, 8/12 previous review, 7/12 fresh.
Wing defence: 8/9, 17/18, 12/12, 11/12 respectively. Trace evidence:

```bash
godot --headless -s tools/gameplay_review.gd -- --case=transition_trace
godot --headless -s tools/probe_scn.gd -- --name=high_loss --variant=0 --seed=11 --secs=7 --duties
```

The observed high_loss v0/11 switches from DEF_TRANS to ORG_DEF after the fixed four-second window.
At t=5–7 s several zone/protect players jog about 5 m/s while their anchors remain 7–15 m behind them;
only four outfield players are goal-side at the end. Code ties sprint partly to phase and distance thresholds.
Investigate threat/recovery-based urgency, moving cover/anchor targets and presser engagement together.
This is evidence of one contributing mechanism, not proof that changing a single timer fixes defence.
Do not slow attackers, boost defenders' physical stats or globally force every player to sprint/press.
Preserve central cover, stamina costs, delayed containment when outnumbered and escape options for humans.

## AI03 / AI04: attacking quality must generalize

3v2 at this revision: 4/9 legacy, 13/18 known extended, 9/12 previous review, **1/12 fresh seeds
211/257/313/373**. The latter were selected before running this review; now they are known validation data.
Use existing AI03 acceptance and trace each failed episode's actual choices. Do not force speculative shots
or weaken opponents to satisfy the timer. Select new seeds AND geometric negative controls before tuning.

Run-behind's legacy label predicate still passes most episodes without establishing receipt. Complete AI04's
movement, own-team delivery, onside receipt/continuation and blocked/offside rejection controls. Report the
legacy and strict contracts separately. Do not count an unrelated opponent lob as a successful combination.

## Evidence discipline and completion

- Matrices: 11/22/33, 44/55/66/77/88/99, 107/131/167/199 and 211/257/313/373; every variant 0..2.
- Original reported matrix totals match, but some per-scenario rows differ from the saved independent logs.
  Eight-match report independently gives 3W/3D/2L, 7:8, 15.1 shots/match (Claude reported 2W/4D/2L, 7:9,
  15.2). Record engine/build/platform/setup and actual per-episode outputs. The discrepancy is unresolved;
  do not assume nondeterminism or falsified results without reproducing the cause.
- Run original/expanded strict checks, relevant core/input/fuzz/career controls and matched full matches
  after changes. Inspect failures and selected traces, not only totals. Test actual physics, not helper vs itself.
- Keep known audio teardown and substitute appearance residuals visible; do not claim Windows execution,
  human acceptance or new visuals from headless checks. The user's manual feedback is real but build-unpinned.
- Update the current validation table, queue status, map when ownership changes, and PROGRESS.md checkpoint
  with exact revision, real commands, evidence, remaining acceptance and one concrete next step. Publish a
  coherent increment; if interrupted preserve WIP rather than restarting or marking it complete.

After the repair phase, use HUMAN_GAMEPLAY_SPEC.md for the approved small control/readability slice.
The idea register contains additional proposals; it is not permission for an all-at-once rewrite.
