# AI validation

All numbers below come from actual headless runs of the production AI on 2026-11-14 with Godot 4.5.1
(`data/tuning/default_tuning.tres` as committed). Nothing here was judged by a human watching the game at
full frame rate — see "Needs human playtesting".

## How to reproduce
```
godot --headless -s tools/run_scenarios.gd                              # all scenarios, variants 0..2, seeds 11,22,33
godot --headless -s tools/run_scenarios.gd -- --only=attack_3v2 --seeds=11,22,33,44
godot --headless -s tools/probe_scn.gd -- --name=attack_3v2 --variant=0 --seed=11 --secs=10 --duties   # trace one episode
godot --headless -s tools/run_match.gd -- --seeds=1,2,3,4,5,6,7,8 --duration=360
godot --headless -s tools/snapshot.gd -- --seed=4 --from=60 --step=2 --frames=6 --out=/tmp/s.png --log  # top-down frames
```
In the game: main menu → **Диагностика ИИ** (or `-- --scenario=NAME --variant=N --seed=S`), F3 overlay is on.

A scenario only arranges players, ball and possession (`ScenarioLib.apply`); after that the normal `TeamAI`,
`OnBallAI` and `KeeperAI` play. Two inputs are injected by the harness and are not AI behaviour: the forced shot
in `shot_rebound` (to create the rebound situation) and the scripted "human" keys in `human_support`.
Variants change pressure distance / opponent placement / ball position; the seed adds ±1 m jitter and drives all
random execution error.

## Scenarios: conditions, criteria, results

| Scenario (name) | Setup | Success conditions | Failure invariants | Result (9 episodes) |
| --- | --- | --- | --- | --- |
| Build-up under pressure (`buildup_pressure`) | A's centre-back has the ball 18 m from his goal; B's front three start 4.5 / 6.5 / 9 m away | A keeps the ball out of trouble and completes ≥1 pass or advances 10 m | ball lost in own third; ≥4 teammates within 7 m of the ball | **9/9** — 1–6 completed passes, ball ends 5–26 m into the other half |
| Blocked passing lane (`blocked_lane`) | Midfielder on the ball, striker straight ahead; an opponent stands in the lane (v0, v2) or 13 m off it (v1) | First pass is not played into the blocked lane and is not intercepted; with the lane open the striker may be used | ground pass into the blocker; first pass intercepted | **9/9** — lane blocked: pass goes to the other midfielder; lane open: pass to the striker in 3/3 (decision adapts) |
| 3v2 attack (`attack_3v2`) | Striker runs at two centre-backs with both wingers, everyone else 25+ m behind | A shot within 10 s; attackers in different lanes (min lateral gap ≥ 6 m) | no shot; shared lane; offside | **4/9** — lanes always separate (9–14 m), but in 5 episodes no shot in 10 s (see defects) |
| Opponent on the wing (`wing_defence`) | B winger with the ball on A's left flank, 18–30 m from the goal line | While B has the ball: exactly one presser ≥85 % of samples, cover ≥75 %, ≥2 defenders central ≥85 % | ≥3 defenders within 5 m of the ball >10 % of samples | **9/9** |
| Loss high up (`high_loss`) | A in attacking shape around B's box, ball given to a B centre-back; A's AI still believes it attacks | One presser/delayer ≥70 % of samples, ≥5 outfield players goal-side after 7 s (or ball still high), no goal conceded | swarm >15 % | **9/9** — 7–9 players goal-side, no shot conceded |
| Run behind (`run_behind`) | Midfielder with time on the ball near halfway, back line of B flat | A forward makes a run behind; offside calls are counted | nobody runs | **9/9** runs made, 0 offside calls; a through/lofted ball was actually played in only 1/9 (see defects) |
| Shot and rebound (`shot_rebound`) | Striker 15–20 m out, forced shot after 0.2 s | Keeper moves, ball is dealt with within 6 s (goal, catch, claim, restart), no stall | loose ball never collected | **9/9** — keeper moved 1.9–5.4 m; outcomes: 3 goals, 2 restarts, 4 claimed/loose-then-claimed |
| Human-controlled teammate (`human_support`) | Human midfielder carries for 1.2 s, passes forward, later presses E | ≥2 usable pass options (same evaluation as the AI), control follows the pass, AI never overrides human movement, players keep duties | any tick where the human's command is overwritten | **9/9** — 4–5 options ≥60 %, hand-off to receiver, 0 overridden ticks |

Total: **67 / 72** episodes without a violated invariant.

Defects found by the scenarios and fixed during this session (each remains covered by its scenario):
- Centre-back under tight pressure chipped the ball straight into the presser (lofted-pass block model only
  looked 2.5 m ahead) → block check now uses the ball's height along the launch path. Build-up v0 went 0/3 → 3/3.
- A presser standing next to the passer took the ball the instant it was struck → a freshly kicked ball can be
  blocked only from in front. Mid-third interceptions fell from 13–21 to 6–23 per match with completion 83–92 %.
- Defenders reacted to opponent passes on the same tick → they now need `reaction_time` before a new interceptor is assigned.
- Position value near the box was higher than the value of shooting, so the AI never shot → goal value scale added.

## Full matches (AI vs AI, 11v11, 6 minutes, difficulty 1, both teams level 70, seeds 1–8)

| Metric | Result |
| --- | --- |
| Scores | 2-0, 1-1, 1-0, 2-0, 0-1, 0-1, 0-2, 0-2 (13 goals, 1.6 per match) |
| Shots per match (both teams) | 8.6 (per team 0–9); average shot distance 13–19 m; no shot from beyond 28 m |
| Pass completion | 83–92 % |
| Possession | 43–57 % |
| Ball swarm (≥6 outfield players within 7 m of the ball) | 1.3–3.9 % of samples; average 2.8–3.1 players near the ball, max 7–9 (set pieces) |
| Closest teammates (average minimum gap) | 5.4–5.9 m |
| Team shape (outfield) | width ≈ 43–46 m, depth ≈ 35–37 m |
| Deadlocks (free ball not collected for 6 s) | 0 |
| Conflicting assignments (two pressers or two covers) | 0 |
| A→B→A→B pass loops | 2–5 per match |
| Restarts | all taken; longest wait 3.1 s; keeper holds ≤ 1.5 s |
| Ball location (thirds, from team 0's view) | middle third 52–71 % — too much, see defects |
| Attribute effect: level 84 vs 62 over the same 8 seeds | 7 wins, 1 draw, 0 losses, goals 15:3 |

Simulation speed: 18–28× real time headless (about 0.65 ms per 60 Hz tick including both team AIs).

## Remaining defects (most important first)
1. **Too little penetration.** The ball spends 52–71 % of the time in the middle third; shots (≈4 per team in six
   minutes) and goals (1.6 per match) are on the low side for a short match. Most possessions end with an
   intercepted pass or a tackle in midfield.
2. **3v2 and other overloads are not exploited well** (`attack_3v2` 4/9). Typical failure: the striker releases
   the ball wide early, the winger carries it toward the corner at jogging pace instead of driving at goal, and
   the move ends in a cross or a tackle after the defence has recovered. Reproduce:
   `tools/probe_scn.gd -- --name=attack_3v2 --variant=0 --seed=11 --secs=10 --duties`.
3. **Runs behind are rarely rewarded** (through ball in 1 of 9 `run_behind` episodes). Runners time their runs
   and stay onside, but the passer's estimate usually prefers a safer option; offside is almost never called
   (0–1 per match), which also means the offside line is rarely tested.
4. **Crosses are low-percentage** (most are lost) and there is no separate heading mechanic.
5. **Few corners and throw-ins** (0–3 per match) because passes are accurate and keepers parry sideways into play.
6. The last defender sometimes steps out to press a ball carrier in an outnumbered situation instead of delaying.
7. Goalkeepers do not come off their line for crosses beyond what the generic "first to the ball" rule gives.

## Needs human playtesting (not verified here)
- Control feel: acceleration, turning with the ball, pass assistance choices, shot charge curve, tackle timing.
- Whether teammates' movement feels helpful to a human and whether «Лёгкая / Средняя / Высокая» are well spaced.
- Animation quality in motion (only still frames were inspected), camera comfort, audio balance.
- Frame rate on real hardware. In the build container only a software rasteriser (llvmpipe) was available:
  about 15 FPS at 1600×900 in a match, which says nothing about a GPU.
See `docs/PLAYTEST.md` for a short script.
