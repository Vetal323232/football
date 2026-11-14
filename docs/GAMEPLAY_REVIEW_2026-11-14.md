# Gameplay review, repair handoff and subsequent brainstorm

Implementation reviewed: `3d08f8b150aeadef10081d69a0fce0f050f991c0`.
Engine `4.5.1.stable.official.f62fdbde1`, Linux headless. Review branch adds diagnostics/docs/evidence only.
Order of work: verify published revision and prior controls, add boundary probes and run match/scenario
tests, prepare CLAUDE_BUGFIX_PROMPT_EN.md, then brainstorm and specify the human-gameplay improvement slice.
No runtime repair or feature is implemented by this review.

## Evidence and results

| Check | Independently observed result |
| --- | --- |
| Import | Exit 0, no script errors |
| Core tests | 442 checks, 0 failed; reused the saved independent run from the immediately preceding check of the exact same implementation SHA |
| Original regressions | 5/5; same exact-revision saved run retained |
| Existing strict audit | All 47 cases still pass, including all five session-2 boundary cases |
| Expanded strict audit | **47/49**, exit 1: the two added gameplay cases fail without script errors |
| Legacy scenarios, seeds 11/22/33 | **63/72**, exit 1; same exact-revision independent log retained |
| Known extended, seeds 44/55/66/77/88/99 | **129/144**, exit 1 |
| Previous review seeds 107/131/167/199 | **88/96**, exit 1 |
| Fresh seeds chosen before this review: 211/257/313/373 | **78/96**, exit 1; 3v2 only **1/12** |
| Eight six-minute 70v70 matches, seeds 1..8 | 3 home wins / 3 draws / 2 away wins; goals **7:8**; **15.1 shots/match**; 0 reported stalls/conflicts |
| Four three-minute 84v62 matches on fresh seeds | Stronger home team 3 wins/1 loss, 8:3 |
| Four three-minute 62v84 matches on the same seeds | Stronger away team 4 wins, 5:1 |
| Input fuzz, seeds 4..15, 30 s | FUZZ OK; not human gameplay acceptance |
| Career journey, 3 real-engine matches of 60 s | JOURNEY OK through season rollover |
| Selected cross-process repeats | Seed 5 twice: identical reported metrics, 2:2; seed 4 repeat: 1:0, agrees with independent batch |

Strength controls total seven wins/one loss for the stronger team, goals 13:4, with no reported stalls/conflicts.
They use a different duration and seed set from Claude's 24:5 result and must not be compared as equal samples.
Do not add overlapping test/scenario counts or present a percentage as overall intelligence or fun.

## New bounded findings

### AI02: recovery speed forecast does not match its execution branch

`tools/gameplay_review.gd --case=carry_recovery`: helper reports **1.488 m/s**, actual `_move_players`
executes **1.6 m/s** for a stunned player starting at the recovery cap. `carry_speed` applies the dribble
ratio after its recovery cap; `_move_players` applies that ratio only in the normal actionable branch.
The normal 54-case accuracy claim remains true for its tested domain, but does not cover recovery.
Possession may be lost during stun, so do not extrapolate this isolated first-step control into a viable
six-metre carry. Extend state-aware validity/timer coverage as described in the repair prompt.

### AI02: sudden-pressure flag cannot interrupt an active ordinary decision deadline

`tools/gameplay_review.gd --case=urgent_pressure`: normal-pressure negative control holds its deadline.
An opponent is then placed within physical reach (ETA=0). `urgent=true` bypasses commitment but not the
`now < next_decision` disjunct, so no reconsideration occurs and 0.1 s remains on the stale command.
The implementation's documented sudden-pressure trigger is therefore incomplete. Bound urgent-entry
replanning rather than allowing sustained pressure to recompute every tick. This is not proof that all
losses or the user's entire control complaint stem from this one delay.

Neither finding is a save-validation relapse or a newly claimed crash. Both are reproducible residual
model/scheduling contracts under AI02. The strict driver includes them; SAVE01/CAREER01 remain accepted.

## Tactical robustness

All variants 0..2, unchanged scenario predicates:

| Scenario | Legacy /9 | Known extended /18 | Previous review /12 | Fresh review /12 |
| --- | --- | --- | --- | --- |
| buildup_pressure | 9 | 16 | 11 | 11 |
| blocked_lane | 9 | 18 | 12 | 12 |
| attack_3v2 | 4 | 13 | 9 | **1** |
| wing_defence | 8 | 17 | 12 | 11 |
| high_loss | 6 | 11 | 8 | 7 |
| run_behind (legacy intent only) | 9 | 18 | 12 | 12 |
| shot_rebound | 9 | 18 | 12 | 12 |
| human_support | 9 | 18 | 12 | 12 |
| Total | 63/72 | 129/144 | 88/96 | 78/96 |

The fresh 3v2 sample demonstrates poor robustness, not proof of intentional overfitting; it is a small
sample of one scenario family. Every fresh failure and its command is retained. These seeds are now
known validation data; choose another predeclared set and geometry controls before future tuning.
AI03 and AI04 remain open: merely seeing a runner label does not establish a served/received safe run.

### AI05 recovery trace

`gameplay_review.gd --case=transition_trace` observes production high_loss v0/11 at 0.5-second intervals.
The phase changes from defensive transition to organized defence after the fixed four-second window.
At t=5–7 s several zone/protect players jog around 5 m/s even while their moving anchors remain 7–15 m
behind them. At t=7 s the ball is x=-16.8 and only four outfield players are goal-side.
The code links recovery sprint to transition phase and distance; investigate threat-based persistence and
anchor motion together with presser/cover engagement. The trace supports a contributing mechanism, not a
one-line universal fix. Full-match tackle attempts are 0–6 per team; more tackles alone is not the goal.

### Evidence discrepancy, not yet a demonstrated determinism bug

Claude's session-3 table says extended buildup=18/18 and review buildup=12/12, run_behind=11/12.
Saved independent results are 16/18, 11/12 and 12/12 respectively. The grand totals happen to agree.
Its eight-match summary is 2W/4D/2L, 7:9, 15.2 shots/match; this review is 3W/3D/2L, 7:8, 15.1.
Seed 4 repeats as 1:0 here, matching the independent batch; seed 5 repeats as 2:2 in two processes.
In-process deterministic pairs also pass. Do not claim global nondeterminism, a cross-match leak, or
fabrication from these differences. Require exact engine/build/platform/setup and per-episode evidence
when reconciling reports; annotate rather than silently replacing old measurements.

## User-observed playability versus implementation bugs

The user reports that direct keyboard steering cannot comfortably compete with precise bot interception;
flight destinations are unclear and a held approach/defending action is desired. Build, seed, difficulty
and hardware of that played session were not pinned, so the observation is not a measured win-rate claim
for 3d08f8b. It is nevertheless real negative human feedback: PLAY01 is OPEN, not "no one has ever played".

Source confirms the design gap at this revision: AI predicts about four seconds of flight, chasers refresh
every four ticks, HumanController directly maps movement and Q only requests a tackle, while ball_view
has a current shadow but no landing predictor. These are absent assistance/readability features, not
evidence that WASD is unbound or every bot has guaranteed interception. Physical-key OS behaviour remains
unverified; existing synthetic camera/input tests pass.

After the bug brief, the brainstorm selected held containment, receiving/loose-ball help, clear flight/control
cues and bounded AI ball-reading uncertainty. See HUMAN_GAMEPLAY_SPEC.md and IMPROVEMENT_IDEAS.md.
Additional commands, shielding, drill/replay feedback and calibration remain ranked proposals; no giant rewrite.

## Limitations and handoff

No new Windows export/execution, human session, real-time visual/audio review or GPU benchmark was performed.
Known audio teardown and substitute skin/hair residuals remain. The older Windows build predates these repairs.
Runtime code and tuning are unchanged by the review; no newly proposed assist is already available.

Use CLAUDE_MASTER_PROMPT_EN.md as the single entry point, AI_WORK_PLAN.md as the single queue, the bug
brief for the repair phase and HUMAN_GAMEPLAY_SPEC.md for the next feature slice. Preserve colleague work.
First executable step: reproduce `--group gameplay`, close AI02 residuals, then continue the tactical repairs.
Record exact implementation SHA, acceptance/evidence and one next action in PROGRESS.md before stopping.

Evidence root: `docs/evidence/gameplay-review-2026-11-14/`; manifest records engine, source hashes, commands
and file checksums. Logs copied from the preceding exact-revision check are explicitly labelled in the manifest.
