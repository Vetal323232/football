# Gameplay improvement brainstorm

Current scope is tracked in [AI_WORK_PLAN.md](AI_WORK_PLAN.md), the single queue; this file is the idea
register and design rationale, not a second status list. The 2026-11-14 consolidation adds the agreed
[player career](PLAYER_CAREER_SPEC.md) and the selected additional match directions below. None is
implemented by this documentation change. Earlier estimates remain hypotheses.

These are design hypotheses grounded in the inspected prototype, not implemented features or proven
improvements. First repair the queue's correctness defects. Preserve useful existing TeamAI duties,
offside-aware runs, shared physical execution, action utilities and career data instead of rebuilding them.

User priorities: enjoyable keyboard football against thoughtful AI; simple coherent 3D; offline Windows;
zero asset budget; meaningful club career after the match itself works well. No licensed FC content is needed.

## Ranked candidates

Impact is a qualitative estimate for this user's goal, 1–5. Effort S/M/L is relative scope, not a time promise.
Risk describes what could get worse. A feature is accepted by observable behaviour and human feedback,
not by a larger number of classes, options, animations or tests.

| ID | Idea and player benefit | Impact / effort | Existing extension points | Main risk and useful check |
| --- | --- | --- | --- | --- |
| T01 | **Give-and-go with a third-man option.** Passer moves after release; receiver can return or use the space opened by the defender. | 5 / M | team_ai `_plan_attack`, AIAgent passer memory, on_ball `_next_option` | Avoid forced ping-pong. Open wall pass succeeds; tracked passer or blocked return produces another sensible action. |
| T02 | **Score/time-aware plans.** Trailing late increases supported risk; leading late retains safe outlets without abandoning attacks. | 4 / M | TeamTactics, team_ai `_update_side`, on_ball utilities, match clock | Avoid universal time wasting. Same geometry with different score/time changes selected risk while retaining legal options. |
| T03 | **Pressing traps and cover shadows.** Closest defender curves his approach to close the central pass; partner protects the exit. | 5 / L | `_plan_defend`, `_drive_press`, `_drive_mark`, SimQuery | Existing press/cover already exist: extend geometry, do not add duplicate coordinators. Opponent can escape by a genuine switch; no swarm. |
| T04 | **Distinct player preferences.** A fast winger, passer and finisher favor actions supported by their attributes and local pressure. | 4 / M | Attr, OnBallAI, AIAgent | Do not secretly change speed or grant knowledge. Controlled attribute swaps produce interpretable choices without making specialist roles mandatory. |
| T05 | **Optional call-for-run command.** Human can ask an eligible teammate to threaten space; AI still checks timing, offside and recovery. | 4 / M | InputFrame, HumanController, TeamAI runner state, bindings | Keyboard overload and suicidal runs. One configurable action, clear receiver cue, blocked/offside requests safely withheld. |
| T06 | **Coordinated second-ball roles.** One pursues a rebound, one attacks the next zone, one protects against the counter. | 4 / M | `_ball_claims`, attack/defence duties, shot_rebound | Generic interception exists: improve complementary duties. Rebound variants retain spacing and defensive security. |
| T07 | **Explainable tactical presets.** Balanced, fast transition and patient build-up change a small set of existing instructions. | 4 / M | TeamTactics and menu settings | Cosmetic toggles. Measure width, risk, tempo and recovery differences; no attribute boosts or difficulty cheating. |
| B01 | **Directional first touch.** Receive into available space or protect under pressure; turning and control affect the outcome. | 5 / L | `_free_ball_contacts`, `_give_possession`, shared commands, PlayerRig | Unresponsive control. No teleporting ball; matched AI/human mechanics, recoverable mistakes, real keyboard testing required. |
| B02 | **Cutback recognition.** Wide player recognizes a safe low backward pass to a late central arrival instead of blindly crossing. | 5 / M | OnBallAI pass candidates, `_finisher_spot`, KickPlanner | Overfitting 3v2 to always cut back. Closed lane/absent runner forces another choice; low pass uses existing physics. |
| B03 | **Basic aerial contests and headers.** Timing, reach and positioning make crosses useful. | 3 / L | MatchSim contacts, KickRequest, PlayerRig, KeeperAI | Large mechanics/animation/rules expansion. Defer until ground football, GK handling and camera are accepted. |
| V01 | **Readable ball/camera/stadium.** Reduce seat contrast, improve ball visibility, offer a closer broadcast preset and radar placement. | 5 / S–M | match_camera, ball_view, pitch_view, hud, settings | Cosmetic scale changing physics or hiding options. Presentation-only ball emphasis; compare 720p/1080p, near/far touchlines, both halves. |
| V02 | **Movement and contact cues.** Tune procedural stride to travel speed, show a clear first-touch and kick follow-through. | 4 / M | player_rig animation, match events | Sliding or delayed input. Pose follows the already executed action; animation never blocks physics or determines ball ownership. |
| V03 | **Optional aim/receiver aid.** Briefly emphasize the selected receiver and control destination in an accessibility mode. | 3 / S | HumanController last assist fields, HUD/rig markers | Too much HUD clutter. Mark known intent only; do not reveal every opponent decision or guarantee completion. |
| U01 | **Better switching cues.** Show who E would select and preserve the intended receiver after a pass. | 5 / S–M | `_manual_switch`, HUD, PlayerRig | The handoff bug itself is INPUT02; a preview is an optional enhancement after the fix. No input lag or flicker. |
| U02 | **Focused squad comparison.** Selected player versus replacement: position, key attributes, current stamina and long-term fitness separately. | 3 / S–M | career_hub, match_menus, UIKit, translations | Confusing two condition metrics. Current fitness label is not a confirmed calculation bug; verify terminology and scroll/focus at 720p. |
| P01 | **Three playable training drills.** 2v1 decision, 3v2 counter and escaping pressure with a restart button and brief feedback. | 4 / M | ScenarioLib, diagnostic_menu, MatchSetup | Scripted opponents flattering the user. Use production AI, varied starts, keyboard control and no guaranteed solution. |
| P02 | **Last-eight-seconds diagnostic replay.** Replay recorded seed/input/events to examine a bad pass or tactical lapse. | 4 / L | MatchSim determinism, InputFrame, match_view, debug overlay | Memory cycles and schema scope. Start as a developer replay, bounded buffers, no promise of mid-match career saves. |
| C01 | **Meaningful match-to-match condition.** Rotation and recovery make a deep squad useful; AI makes sensible substitutions. | 4 / L | CareerState, match participants, SimPlayer fitness/stamina, match_menus | Save migration, fatigue spirals and unfair AI freshness. Define recovery, preserve old saves, test full seasons and both teams. |
| C02 | **Role-based recruitment and limited AI transfers.** Clubs fill actual positional needs with affordable players. | 3 / L | CareerState buy/sell, LeagueData lineup and budgets | Runaway economy/invalid squads. No fictional money; role quotas, bounded transactions, long-season invariants. |
| C03 | **Small development choices.** Pick one training focus per player and show why attributes changed. | 3 / M | `_develop`, Attr, career_hub | Grind and min-max exploitation. Bounded deterministic growth, clear tradeoff, no paid systems. |
| A01 | **Clearer audio mix.** Crowd ducks for important contacts; optional directional cues help locate a pass or rebound. | 3 / S–M | Sfx, match_view event handling, volume settings | Actual audio has not been reviewed. Test on speakers/headphones; avoid repetitive cues, revealing hidden AI intent or changing simulation timing. |
| B04 | **Prepare and control the shot.** Position/body angle matter and the user can deliberately hit a powerful low shot. | 5 / M | HumanController._shot, KickPlanner.plan_shot, shared execution/input/help | Confusing height/power or accidental sprint modifiers. Preserve charge/pause response; compare low/high attempts and attributes. |
| T08 | **Coordinated attacking rotations.** Winger inside, full-back outside, midfielder compensates to create useful alternative lanes. | 5 / M–L | TeamAI attack anchors/duties and existing rest-defence compensation | Vacated centre and duplicated runs. Blocked/marked/turnover controls must preserve cover. |
| T09 | **Limited opponent adaptation.** Repeated successful attacks on one side lead to a delayed adjustment that opens space elsewhere. | 4 / L | TeamTactics, bounded match-observation memory | Omniscience and rubber-banding. Use past evidence only, bounded delayed changes, no physical boosts; keep backlog until baseline/style evidence exists. |
| B05 | **Body feint and change of direction.** Draw a defender one way, then exploit momentum with a shared physical move. | 4 / L | Existing acceleration/turning, InputFrame, MatchSim, PlayerRig | Unresponsive steering or human-only tricks. Basic inertia already exists; a new feint needs real mechanics and fair AI access. |

## Current scope and overlaps

Follow the queue phases: existing audit repairs, V01/T01, PC00–PC09 player career, then selected shared
match improvements B01/B04/T07/T08/P01. Manual Windows gates recur at runnable checkpoints. This ordering
extends the earlier two-item proposal; it does not mark any work complete or erase the remaining ideas.

The subsequent ten-direction discussion maps as follows, so an idea is not implemented twice under a new name:

| Discussion direction | Owner / scope |
| --- | --- |
| Partners create space through complementary rotations | T08, after the first combination/defence repairs |
| Give-and-go with multiple continuations | T01, extending existing passer/support memory |
| Draw a defender and change direction | AI02 corrects prediction; existing inertia remains; new feint B05 stays backlog |
| Meaningful first touch | B01, shared by team/player modes |
| Shot preparation and strong low shot | B04, shared controls/physical execution |
| Recognizable opponent/club styles | T07; PC05/PC06 use actual existing tactics for world/offer fit |
| Cautious adaptation to repeated attacks | T09, later backlog with fairness controls |
| A few useful teammate commands | PC01 includes pass request; extra run/press commands T05 stay backlog |
| Career built around playing style | Required PC03 development / PC06 offers; C02 full AI transfer market remains backlog |
| Playable training situations | P01, with PC03 once-only weekly credit and automatic training option |

C01 condition/workload, C03 focused training and the player-specific part of C02 are now partly covered by
the PC contracts. This does not authorize a second growth engine, a full autonomous transfer economy or
all lifestyle ideas. The remaining table entries stay backlog until explicitly queued. None requires paid
assets, a network service, runtime LLMs or an engine rewrite for the agreed initial scope.

## Concrete football contracts

These distinguish thoughtful AI from movement labels:

- **2v1/3v2:** carrier threatens a defender; support stays in a reachable complementary lane. Drawn defender
  opens a pass, defender holding shape leaves a dribble/shot, blocked centre permits a useful wide option.
  Do not force a shot because the episode timer is ending.
- **Run behind:** actual onside acceleration, a physically reachable pass during a safe window, arrival to
  the intended runner and a useful continuation. Closed lane or offside runner is a negative control.
- **Defending outnumbered:** delay the carrier while covering the dangerous receiver; arriving help allows
  pressure. Diving at the ball without cover should be a plausible mistake, not the universal policy.
- **Transition after loss:** nearest useful player delays; other players protect central lanes and recover.
  Judge the whole time series, opponent chances and cover, not one duty label or a single final frame.
- **Human teammate support:** offer an outlet, depth and a different lane; respond to the controlled player's
  movement. AI must never overwrite that player's command or steal the intended handoff.
- **Variety:** the same team can shoot, drive, play a wall pass or recycle according to the situation.
  Randomness should vary imperfect execution and close choices, not replace tactical reasoning.

## How to decide whether an idea helped

Use a fixed before/after seed matrix and newly reserved arrangements, with identical difficulty, attributes,
duration and engine. Record mechanism-level evidence: candidate scores, timing, actual path and receipt,
danger created, options rejected and why. Observe already computed decisions; debug logging must not
consume RNG or rerun the planner.

Pair aggregate match metrics with traces and actual play. More shots can mean worse shot selection; high
pass completion can mean sterile recycling. The current xG estimate is a heuristic, not real calibrated xG.
Keep defensive security, turnover costs, spacing, finite state and input response as counter-metrics.

For V01, compare unchanged gameplay with matched snapshots and moving play. Ask the Windows tester whether
they can track the ball, identify the controlled player, read a passing option and see the next defender.
Performance and subjective control quality require a real machine and person.

## Deliberately later

Online multiplayer, real club licensing, card packs, a full financial ecosystem, cinematic story modes,
reinforcement learning and runtime LLM decision-making are outside this improvement slice. They multiply
scope without resolving the observed keyboard, prediction and team-choice problems. Keep deferred rules
(fouls/cards/penalties) explicit in DESIGN.md until separately scoped.
