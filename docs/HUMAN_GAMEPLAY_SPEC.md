# Human-playable keyboard football: next improvement slice

This specification follows the bug-fix phase; it does not replace AI_WORK_PLAN.md.
User feedback: manually steering to the ball feels impractical against precise AI interception; the flight
is difficult to read, and a held defensive approach button would help. The played build/seed is unknown.
Treat that as observed dissatisfaction and a design requirement, not proof every latest bot is unbeatable.

Goal: the user chooses a football intention while assistance handles bounded precision movement.
Keep common speed, acceleration, collision, stamina, ball contacts and tackle outcomes. No guaranteed wins.
Start with the small V01 / INPUT04 / INPUT05 / AI06 slice before player-career expansion or detailed art.
Nothing in this document is already implemented. Candidate paths below are navigation, not scaffolding demands.

## 1. A small explicit control contract

| Situation | Proposed default action | Behaviour |
| --- | --- | --- |
| Ordinary movement | WASD / arrows | Existing camera-relative steering, diagonal normalization and Shift sprint remain. |
| Opponent owns the ball | Hold Space | Controlled outfielder approaches from a useful goal-side angle, brakes near the opponent and contains. Q remains an explicit tackle. |
| Loose ball / incoming pass | Hold Space | Controlled outfielder approaches a physically reachable intercept point and brakes for contact. Assistance stops on collection. |
| Manual correction | WASD while Space is held | Manual direction takes priority in that simulation sample; assistance can resume when direction is released and Space is still held. No blended steering that fights the player. |
| Your controlled player owns the ball | Space | No automatic dribble/shot/pass in the first slice. Existing attack controls retain their meaning. |
| Pause / focus loss / scene exit / control or identity change | Existing events | Clear assisted intent and require release/re-press to rearm held assistance, avoiding a stale pursuit of another target. |

Space is a proposal because it is currently unbound. Verify binding conflicts/help before enabling it.
Keep Q edge-triggered. Do not turn it into an undocumented press/hold/double-tap combination.
Add Manual and Semi-assisted presets; Semi-assisted is the proposed default for this keyboard-first game.
Manual preserves the previous command path. Store the preset in settings with sane legacy defaults and
translated Russian help. Assistance strength and opponent difficulty are independent settings.
Full automatic tackling is a later optional experiment after containment/manual tackling are playable.

## 2. INPUT04 — held defensive approach

Owners: InputFrame, Game input/settings, match_view sampling/reset, HumanController command production;
reuse SimQuery and existing interception/approach geometry. Extract a small shared read-only helper only
when needed; never let TeamAI overwrite human commands or invoke a whole second planner for one player.

- Assist only the currently controlled eligible outfielder. Target current opponent possession; use stable
  target selection and release rules. Do not steal team control to a different defender or chase a goalkeeper
  holding the ball in his hands. Set movement/facing/sprint intent, not position, speed or ball ownership.
- Approach the opponent with a safe offset, then slow down; choose cover/containment rather than always
  diving into the ball. Re-evaluate target loss, pass, throw/restart, halftime and goal boundaries.
- Shift requests normal sprint; brake automatically at close range. Assistance cannot bypass stamina,
  recovery, turning limits or collisions. Q uses the same physical tackle as ordinary control/AI.
- No automatic tackle/pass/shot merely from holding Space in the initial version. Future assisted tackling
  requires explicit user setting, physical reach/cooldown and the common success calculation.

Acceptance: both teams/halves, side/front/behind approaches, moving target, target lost, own possession,
keeper hands, restart/full time, pause/focus, switch/substitute identity and manual escape. Holding the action
must not guarantee a win or drag the player through bodies. Manual input wins immediately; turning assistance
off preserves the old sampled commands. Observe actual motion in a scene, not only generated command flags.

## 3. INPUT05 — receiving and loose-ball approach

- Extend the same held action for loose balls/incoming passes; do not add another key or autopilot engine.
  Estimate a reachable contact point, accounting for height and time; the landing marker alone is not enough.
- Preserve intended-receiver handoff in TEAM mode. Add optional short initial movement assistance after
  that handoff in Semi-assisted mode; its named duration and maximum correction must be bounded/tunable.
  Manual steering, a deliberate kick, an opponent touch or expiration cancels it. Holding Space may continue
  explicit pursuit; no indefinite movement when the user is not requesting it.
- The pass can still be intercepted, miscontrolled or missed. Do not enlarge contact radii, magnetize the
  ball, freeze defenders, alter pass velocity or grant a reception through an unreachable height.
- PLAYER_LOCKED integration later binds UID: these helpers cannot switch to a teammate. Bench/off-pitch
  means no human movement. Add policy explicitly during PC01; do not pretend that mode already exists.

Acceptance: rolling pass, diagonal/cross-field pass, lofted ball, bounce, deflection, unreachable ball,
interception by another player, manual direction away, both halves and release/cancel. Record reach/receipt
rates over matched varied episodes with assist on/off; improvements need actual contacts and human feedback.

## 4. V01 — readable ball, destination and control

Extend existing V01/V03/U01 ideas rather than duplicate them under a new UI system:

- Strong controlled-player indicator and a stable preview of the next manual-switch candidate. Preview
  must match the actual next E action; query candidate selection without consuming RNG or changing control.
- Optional landing cue for airborne balls, based on current flight and first ground contact, not final rest.
  Refresh on deflection; hide on possession/dead play/invalid prediction. If the finite horizon has no landing,
  indicate uncertainty or hide the cue; do not invent an endpoint. Use a directional cue for off-screen targets.
- Distinguish the ball's current shadow, predicted landing and assisted intercept target. Avoid three competing
  bright markers: emphasize the cue relevant to the current action and offer a simple aid toggle.
- Improve visual contrast/camera/radar at 720p and 1080p. A slightly enlarged rendered ball is optional;
  collider size and all physics stay unchanged. This is gameplay readability, not the later Blender art phase.

Acceptance: high/low flight, bounce, deflection, penalty-area congestion, near/far sidelines and both halves.
Matched motion/screens show readable cues; toggling presentation aids alone leaves sim/RNG snapshots identical.
Do not infer hardware FPS from software rendering or video capture rate.

## 5. AI06 — bounded perception and comprehensible difficulty

Existing AI uses a physical forecast about four seconds ahead, with chasers recalculating every four ticks.
Current difficulty adds reaction/error in some decisions, but pursuit does not have a general uncertain
perception model. Good positioning can remain strong while precise individual pursuit is made more human.

- Keep authoritative physics exact. Give AI a cached estimate derived from observable ball state and bounded
  reaction/update cadence; the ball's actual path, collisions and human input remain untouched.
- Start with ball-pursuit perception only. Do not build a full vision/head-turn/neural system or rewrite all
  team tactics. Reuse predictors on perceived snapshots; preserve legal-height/reach checks.
- Difficulty tunes observation delay and bounded stable uncertainty, not hidden physical boosts or score-based
  rubber-banding. Sample uncertainty per observation/event, not fresh frame noise that causes twitching.
  Keep separate named tunables for field players/GK if required and document their initial hypotheses.
- A deflection/rebound requires a new observation/reaction; the AI cannot instantly know an unseen future
  collision or the human's pending command. Accurate anticipation from current motion is still legitimate.
- Use deterministic seeded randomness. Prefer an isolated named perception stream derived from match seed
  so logging/visual aids do not consume execution RNG; document stream ownership and dispose caches safely.
- Define profiles explicitly. Do not make human-side AI teammates suddenly inept to create apparent fairness.
  Assist settings are independent; identical AI profiles/attributes receive identical information rules.

Acceptance: matched grounded/aerial/rebound/deflection cases at each difficulty, side swaps, determinism,
human pass/shot controls and competent team shape. Show observation/update times and interception errors;
do not merely lower win rate. Test that human future input and HUD toggles cannot change AI sensing.
Straight easy receptions should remain competent; occasional late corrections should be legible, not random.
Run tactical matrices as counterchecks, but do not secretly disable perception only inside diagnostics.
If retaining an exact-information diagnostic mode, label it separately from real gameplay-profile evidence.

## 6. Real acceptance checkpoint before expanding scope

Deliver a new Windows build identified by commit, with settings/help and a short reproducible test route.
Use PLAYTEST.md to record picking up a loose ball, receiving a pass, containing/tackling and escaping assisted
movement. Compare Manual/Semi-assisted at the same difficulty and let the user describe concrete failures.
Track outcome rates as observations; do not require an arbitrary win quota or declare success from AI-only play.
The user should be able to identify whom they control, where the ball is going and why an attempted action
succeeded or failed. Human feedback is still required to accept control feel. Unavailable Windows testing
does not block independent bug fixes, but no one may call the control slice accepted without that evidence.

## Design references, not copied implementation promises

- EA FC 26 accessibility documents next-player indicators, pass/shot visuals, assist settings and camera choices:
  https://www.ea.com/able/resources/ea-sports-fc/fc-26
- KONAMI documents Smart Assist Match-up movement with directional correction:
  https://www.konami.com/efootball/en-us/page/overview

These support the general assisted-intention approach. Our Space binding, cancellation rules, error model
and staged scope are project-specific proposals. No paid assets, runtime LLMs or engine rewrite are needed.
