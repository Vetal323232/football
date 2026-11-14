# Open Pitch — design

## 1. Layers and ownership

```
InputMap ──> match_view (samples input once per physics tick) ──> InputFrame
                                                                    │
HumanController ── PlayerCommand ──┐                                │
TeamAI (x2)     ── PlayerCommand ──┼──> MatchSim.step()  (60 Hz, deterministic, no nodes)
                                   │        ├─ player movement (accel / decel / stamina / body separation)
                                   │        ├─ actions (kick, tackle, keeper dive)
                                   │        ├─ ball physics (the only place the ball moves)
                                   │        ├─ possession (claim, first touch, dribble control, keeper hands)
                                   │        └─ rules (goal, out, offside, restarts, halves)
                                   └── events ──> match_view ──> rigs, ball view, camera, HUD, Sfx
```

- **Simulation** (`src/sim`, `src/ai`, `src/input`): plain `RefCounted` objects. Sim plane is (x along the pitch,
  y across); ball height is separate. The view maps (x, y, h) to world (x, h, y).
- **Presentation** (`src/view`, `src/ui`): reads sim state, interpolates between ticks, never writes gameplay state.
  Player rigs are separate from collision and AI.
- **Pause** = the match scene stops calling `MatchSim.step()`. Every match timer (clock, cooldowns, AI
  commitments, restart limits) is counted in sim ticks, so nothing advances while paused.
- **Determinism**: all randomness comes from `sim.rng` seeded by `MatchSetup.seed`; same seed and inputs give the
  same match (checked by a test).
- Career and exhibition use the same `MatchSim`; headless tools use it without any scene.

### Authority over the ball
| Situation | Who moves the ball |
| --- | --- |
| Free ball (pass, shot, loose) | `BallState.advance()` only: gravity, air drag, rolling deceleration, bounce. No homing after release. |
| At a player's feet | `_dribble_control`: bounded acceleration toward a point in front of the owner. If the ball gets farther than `lose_reach` it becomes loose. |
| Kick | One impulse set in `_try_kick`, with execution error from attributes, pressure, speed and body angle. The kicker cannot touch it again for `kick_lock_time`. |
| Keeper's hands | Glued to the keeper until he releases; bounded by `keeper_hold_max`. |
| Restart | Ball is `dead` (no physics) until the taker's kick. |

Possession changes only by physical contact: a free ball within claim reach (closest eligible player wins, one
change per `owner_lock_time`), a challenger who is clearly closer to a loose touch, or a tackle that reaches
the ball. A ball faster than the player's trap limit is deflected, not controlled.

## 2. Controls
`HumanController` converts `InputFrame` into the same `PlayerCommand` the AI uses.
- Movement is the raw direction; momentum comes from the shared movement model.
- Deliberate actions are edge-triggered in `match_view._unhandled_input`, so one press = one action.
- **Pass assistance** chooses a receiver inside a cone around the aimed direction (score = angle, distance, lane
  openness, offside), then `KickPlanner` computes the kick. It never guarantees completion and never widens the
  cone behind the player when he aims forward. With nobody in the cone the ball is played into space.
- **Shot**: charge sets speed and height (full charge from close range goes over), lateral input picks the side
  of the goal, error depends on the shooting attribute, pressure, speed and body angle.
- **Switching**: automatic only inside our own possession (new ball owner / intended receiver). `E` ranks
  players by time to the ball, goal-side position and input direction; repeated presses cycle the top four.
- A released player keeps his `AIAgent` (duty, targets), so a switch never erases tactical context.

## 3. Football AI

### What a team and a player can observe
Positions, velocities and attributes of all players, the ball state, the predicted free-ball path (same physics
as the live ball), last kick metadata (kicker, intended receiver, target), score/phase of play. No access to
future human input. Side changes are perceived after `TeamTactics.reaction_time`; defenders read an opponent's
pass only after the same delay; keepers react to shots after `keeper_react_*`.

### Team phases
`BUILD_UP`, `PROGRESSION`, `CHANCE_CREATION` (by ball zone), `ATTACK_TRANSITION` (first seconds after winning the
ball when few opponents are goal-side), `ORGANIZED_DEFENCE`, `DEFENSIVE_TRANSITION` (first seconds after a loss),
`SET_PIECE`.

### Responsibilities (TeamAI, replanned at 10 Hz per team, staggered, and immediately on kick / possession change)
Every player has a home position from the 4-3-3 shape (`AIShape`) that shifts with the ball, then one duty:

| In possession | Out of possession |
| --- | --- |
| CARRIER / RECEIVER (ball) | PRESS — exactly one primary presser |
| SUPPORT — close option outside cover shadows | COVER — one player behind the presser on the ball–goal line |
| OUTLET — deeper safe option | MARK — zone owner picks up the threat in his zone (hand-off by zone) |
| RUNNER — holds a few metres onside, runs behind when the carrier can feed him, returns if not used | ZONE / PROTECT — hold shape; DM protects the centre |
| WIDTH — stretches the pitch (wingers also make runs) | CHASE — best-placed player for a loose ball / interception |
| FINISHER — near post, far post, edge of the box | |
| REST — rest defence; at least three outfield players stay behind the ball, others compensate when a full-back joins | |

Conflicts are avoided by construction: presser, cover, receiver and chaser are chosen centrally (one each) with
hysteresis (`press_switch_margin`, `press_min_commit`); off-ball targets are picked in sequence and each
candidate is penalised for being near targets already taken (`crowd_radius`).

Off-ball positions are found by scoring a few candidate spots near the anchor: openness of the passing lane from
the ball, free space, positional value, distance band to the carrier, crowding, distance from the anchor, and the
offside line. A new spot must beat the current one by `position_switch_margin`.

### Decisions on the ball (`OnBallAI`)
Candidates: ground pass to each teammate, through ball ahead of runners, lofted pass, cross into the box,
eight dribble directions, hold, shot, clearance. All are compared on one expected-value scale:

`EV = P(success) × value(after) − (1 − P) × cost_of_losing_the_ball_there (+ small terms)`

- `FieldValue.value` rises with progression and with shot quality near the goal; `loss_cost` is the opponent's
  value at that spot, so risk is expensive near our own goal. A backward pass wins when forward options are closed.
- Pass success comes from interception margins: ball travel time along the path versus each opponent's feasible
  arrival time (acceleration model + reaction), an opponent standing in the lane, the receiver coming to the ball,
  and his space on arrival. Lofted balls can be blocked while still low.
- Shots use xG from distance/angle, blockers, keeper position, pressure and the shooting attribute; a shot is
  taken when its value beats the alternatives (no shooting just because the ball is available).
- Third-player bonus: the best passes are re-scored by the receiver's own best forward option.
- Dead-end detection: team `impatience` grows when the ball has not progressed for a few seconds and raises
  the value of progressive options and shots; it resets on progress.
- Stability: decisions every `onball_decision_time`, dribble direction commitment, a settle time after the first
  touch (skipped under imminent pressure), and replanning triggers (pressure, a teammate starting a run).

### Defending
Primary presser = lowest time to the ball with penalties for not being goal-side, for centre-backs far from goal,
for the striker deep in our half and for low stamina. He **contains** (holds a goal-side distance) or **engages**
depending on triggers: loose touch, receiver just got the ball, facing own goal, near the touchline, danger zone,
cover set, counter-press with support. Tackles are attempted only inside physical reach after a short reaction.
Markers stay goal-side and ball-side of their threat, track runs behind, and do not follow a player who stands
offside. In defensive transition the nearest player delays or counter-presses (only with support) while the rest
sprint back to their anchors.

### Goalkeeper (`KeeperAI`)
Positions on the ball–goal line; comes for balls he reaches first inside his area; narrows the angle in a
one-on-one and smothers a loose touch; after his reaction delay moves or dives to the predicted crossing point
(a dive has finite speed and reach; saves at full stretch are probabilistic, hard shots are parried, not caught).
With the ball he waits briefly, then throws/passes to a safe teammate or kicks long before the hold limit.
Back-passes may not be handled.

### Fairness and difficulty
Both teams and the human's teammates run the same code and physical limits. Difficulty (`TeamTactics.for_difficulty`)
changes only reaction time, decision noise, execution error and pressing intensity. Nothing reads future input,
changes attributes during a match or steers the score.

### Cost
Team replans are staggered (team 0 / team 1 on different ticks), position searches refresh per player every
`position_refresh_time`, chase targets every 4 ticks. Measured: a full 6-minute 11v11 match simulates headless in
about 15 s on the development container (≈25× real time, ≈0.65 ms per tick including both AIs).

## 4. Rules implemented
Two halves with change of ends, kick-off, goals (whole ball over the line inside the frame; posts and crossbar
are solid), own goals, throw-ins, corners, goal kicks, offside (position judged at the teammate's kick, punished
when the flagged player plays the ball; not from throw-ins, corners, goal kicks), indirect free kick for offside,
keeper handling limited to his area and not from back-passes, restart distance for opponents, no second touch
by the restart taker, bounded restart and keeper-hold times.

**Deferred** (documented, not implemented): fouls and cards, penalties, direct free kicks and walls, injuries,
stoppage time, extra time, replays, mid-match saving, drop balls. A tackle from behind is simply unlikely to
succeed. Offside "interfering without touching" is not judged.

## 5. Career
- League of eight fictional clubs, 20 players each (2 GK, 7 DF, 6 MF, 5 FW), generated deterministically.
- Double round-robin (circle method), 14 rounds. The table is always computed from played fixtures:
  3 points for a win, 1 for a draw; tie-breaks goal difference, goals scored, club id.
- The user's fixture is played with `MatchSim` (or simulated on request); other fixtures use a Poisson model on
  line-up strength, seeded per fixture id.
- **Overall rating** = weighted mean of attributes by position (`Attr.weights`):
  GK: goalkeeping 6, passing 0.6, control 0.4, pace 0.4, stamina 0.3;
  DF: defending 3.5, pace 1.6, passing 1.2, stamina 1.2, control 1.0, shooting 0.3;
  MF: passing 3.0, control 2.4, stamina 1.6, defending 1.2, pace 1.2, shooting 1.0;
  FW: shooting 3.2, pace 2.2, control 2.2, passing 1.2, stamina 0.8, defending 0.2.
- **Price** = 30 000 × 1.14^(overall − 50) × age factor (≤23: 1.25 + 0.05 per year under 23; ≥29: −12 % per year
  after 28, floor 0.25), rounded to 10 000. Selling returns 85 %.
- Transfers move the player, both squads and both budgets in one function; guarded against unknown / own /
  unaffordable players, full squads, squads below 16 players or two goalkeepers.
- Development: each appearance adds fractional growth to two random position-relevant attributes; the rate falls
  with age; over 30 pace and stamina decline at season end. Attributes feed `SimPlayer` directly (speed, kick
  error, trap limit, tackle chance, stamina drain, keeper reach/reaction), so they change match execution.
- Exactly-once: a fixture has a `played` flag; `apply_result` refuses a second application; rounds advance only
  in `complete_round`; the match scene hands the result over once (`Game.last_result` is cleared on read).
  Leaving a career match early does not count it.
- Saves: `user://saves/career.json`, schema version 1, written to a temp file, re-read and validated, previous
  save kept as `.bak`, then renamed. Loading validates references (players ↔ squads ↔ clubs ↔ fixtures); a damaged
  file falls back to the backup with a message; if both are damaged the player is told to start a new career.
  Autosave happens after every round, transfer and line-up change (between matches only).

## 6. Assumptions and trade-offs
- Custom kinematic simulation instead of Godot physics: deterministic, fast headless runs, one ball authority.
- Players are discs with soft separation; no aerial duels or headers as separate mechanics (a high ball is
  deflected by a body, then controlled on the ground).
- UI screens are built in code on small `.tscn` roots (no editor was available in the build environment);
  the match scene itself is a normal editable scene.
- Player models are procedural primitives with procedural animation — coherent rather than detailed.
- One formation (4-3-3); width, line height, pressing and pass risk are parameters of `TeamTactics`.
