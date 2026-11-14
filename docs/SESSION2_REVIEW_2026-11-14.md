# Independent review of Claude session 2

Reviewed implementation: `bbe7dbb03990c1480bbdb94268b2575ca179891b`, branch
`claude/new-session-yr8bm1`. Godot `4.5.1.stable.official.f62fdbde1`, Linux headless.
Reviewer additions change diagnostics/documentation only, not runtime behaviour or tuning.
This is a bounded review, not proof of absence of bugs or human gameplay acceptance.

## Disposition

The ten implementation commits deliver substantial real repairs. Independently reproduced:
421 core checks, five review regressions, the existing 42 strict audit cases, deterministic/career
controls, fuzz, and eight full matches. The old tautologies now detect deliberate faults.
Retain the implementation. Reopen SAVE01 and CAREER01 for the boundary cases below; do not revert
accepted unrelated repairs. AI01 event timing is repaired, but the resulting tactical regressions
must be addressed through AI02/AI03 and neighbour checks before tactical acceptance.

## Confirmed remaining defects

All five cases are in `tools/session2_review.gd`, selected with `-- --case=NAME`. They deliberately
exit 1 on this revision. The strict driver catches script errors as well as exit codes.
The save cases use isolated `user://session2_boundary_*` directories, create a valid backup, and
replace only their test primary. They never modify the normal career slot.

| Case | Reproduction / observed result | Owner and correction |
| --- | --- | --- |
| `missing_history` | Delete root `history`. Validation returns `[]`; normalization does not restore it; real load returns a career with `recovered=false`. Completing the season raises a missing-key error in `_award_prizes` (career_state.gd:294). | SAVE01. Reject the missing mandatory field before load, or explicitly migrate/default it before returning a usable career. Test through season completion. |
| `extra_attribute` | Add `attrs.unexpected={bad:true}`. Validation checks only `Attr.KEYS`, but normalize iterates every key. Real load raises an `int` constructor error at career_state.gd:704 and still returns a career without backup recovery. | SAVE01. Align validation/normalization iteration domains. Reject malformed unknown entries or explicitly discard them under a documented compatibility policy; no runtime error may count as a successful read. |
| `fitness_type` | Set a player's optional `fitness` to a dictionary. Validation accepts; load does not recover; `match_setup_for` raises a `float` constructor error in league_data.gd:142. | SAVE01. Validate every consumed optional field when present, including finite fitness in its physical range. Preserve legal defaults for old saves. |
| `duplicate_pair` | Replace fixture 1's home/away with fixture 0's pair, retaining unique IDs, rounds and total count. Validation accepts; after one completed round the duplicated home club has P=2 while another club missed its fixture. | SAVE01. Check per-round team participation and directed home/away pair multiplicity, not only IDs and total count. Preserve legitimate partially completed current-round saves. |
| `legal_low_keeper` | In a legal generated squad, set all keeper attributes to 1 and outfield attributes to 99 (all within schema). Two keepers exist and the current lineup is legal. Auto-lineup picks an outfielder for goal due to a finite penalty; CareerState refuses the result and returns false. | CAREER01. Treat an actual GK in the goal slot as eligibility, then score eligible candidates. Preserve all-or-nothing behaviour for genuinely impossible squads. |

These are not five newly introduced regressions: they are residual contracts not covered by the original
passing checks. The auto-lineup case and corrupted saves are adversarial boundary data, not demonstrated
ordinary UI paths. Distinguish severity from reachability. Four save cases form one validation follow-up.

## Independently reproduced checks

| Check | Result at bbe7dbb |
| --- | --- |
| Import / class registration | Exit 0, no script errors |
| Core tests | 421 checks, 0 failed, exit 0 |
| Deliberate `--violate=budget` / `--violate=lineup` | Each produces exactly one failed assertion, exit 1 |
| Original review regressions | 5/5, exit 0; 0/12 released simulations remain alive |
| Existing strict audit set | 42/42, exit 0, including after AI01 (Claude had not rerun it after AI01) |
| Expanded strict driver, including the five new boundary cases | **42/47**, exit 1; three new cases log script errors |
| Legacy scenarios (11,22,33) | 67/72, exit 1; five 3v2 failures remain |
| Extended known scenarios (44,55,66,77,88,99) | 122/144, exit 1 |
| Fresh review seeds (107,131,167,199) | 85/96, exit 1; historical gameplay a47746e gives 89/96 with identical predicates |
| Eight six-minute 70-vs-70 matches (1..8) | Home 4W, 1D, 3L; goals 11:11; 10.9 shots/match; 0 stalls/conflicts |
| Random human input (4..15, 30 s) | FUZZ OK; not human playtesting |
| Career journey (`--played=3 --duration=60`) | JOURNEY OK through rollover |
| Runner-event diagnostic | Nine episodes; 2.75 decisions on average, max 4 in 0.5 s after an event |
| Unknown scenario / missing screenshot dependency | Exit 2 as required |
| Main-menu and match scene smoke (`--headless --quit-after 120`) | Exit 0, no script errors; match shutdown has an audio-resource warning |

The expanded denominator adds five cases; it does not erase the genuine 42 passing controls. Do not add
these counts to the unit/scenario counts to claim an overall intelligence or correctness percentage.

## Tactical comparison

No scenario geometry, seed list, utility weight or predicate was changed in this review.

| Scenario | Known seeds: a47746e → bbe7dbb (/18) | Fresh review seeds: a47746e → bbe7dbb (/12) |
| --- | --- | --- |
| buildup_pressure | 16 → 16 | 11 → 11 |
| blocked_lane | 18 → 15 | 12 → 10 |
| attack_3v2 | 5 → 5 | 10 → 8 |
| wing_defence | 17 → 17 | 10 → 10 |
| high_loss | 14 → 15 | 10 → 10 |
| run_behind (legacy intent predicate only) | 18 → 18 | 12 → 12 |
| shot_rebound | 18 → 18 | 12 → 12 |
| human_support | 17 → 18 | 12 → 12 |

Fresh-seed failures are now known validation data, not a permanently hidden holdout. Reserve a new
unseen set and geometry changes before the next tactical tuning iteration.

Blocked-lane failures: known v2 seeds 77/88/99; fresh v0/107 and v2/199. At v2/77 the carrier
dribbles until tackled at 2.25 s without passing. New-seed failures explicitly include a first ground pass
into the blocked lane. Inspect predicted vs executed movement and decision/commitment deadlines; do not
assume the jog/sprint mismatch is the sole cause. `urgent` currently bypasses commitment but not the
`now < next_decision` part of the early return in OnBallAI.drive; establish an explicit tested policy.

3v2 changed which episodes fail: fresh v0/107, v0/131, v2/131 and v2/167 fail now; old v2/199 improves.
Defensive failures: wing v0/107 swarming and v2/131 central abandonment; high-loss v1/107 recovery and
v2/107 press/delay assignment. Existing AI05/AI03/AI04 remain the proper owners; do not create another queue.

The eight full matches have 22 goals versus the historical 13 and 10.9 versus 8.6 shots per match.
That is encouraging but insufficient to establish improved play feel. All 16 team-match offside counts are
zero; the ball remains in the middle third 57–65% of samples. Through-ball receipt and safe movement remain
AI04 work. Human Windows control, real-time animation, audio and GPU performance are still unverified.

## Lifecycle residual and limitations

Simulation teardown regressions pass without match-cycle warnings. A direct match-scene shutdown still
logs an `AudioStreamWAV` and an `AudioStreamPlaybackWAV` leak (verbose evidence retained); no MatchSim
or TeamAI appears in that verbose leak list. Keep this as a lower-priority audio teardown residual under
MEM01; do not claim every ObjectDB warning was eliminated or conflate it with the repaired simulation cycle.
No new rendered screenshot/video or Windows export/execution was produced in this review. The screenshot
wrapper's missing-dependency branch was rechecked; its positive render path was inspected, not independently
rendered again. The older Windows binary predates the implementation fixes.

## Resume and colleague handoff

Use `PROGRESS.md` Active handoff and the existing queue. First close SAVE01 boundary coverage, then
CAREER01 eligibility, then AI02. Preserve accepted implementation commits; no engine/graphics rewrite.

```bash
godot --version  # must be 4.5.1
python3 tools/run_deep_audit.py --godot godot --out /tmp/openpitch-review --group review
godot --headless -s tools/session2_review.gd -- --case=missing_history
```

Evidence: `docs/evidence/session2-review-2026-11-14/manifest.json`, root logs and expanded/summary.json.
The baseline holdout run used the historical local audit checkout whose runtime is identical to a47746e;
it retains the old incorrect exit 0 and lifetime warnings. Its behavioural verdict is 89/96, not a pass.
