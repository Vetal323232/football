# Manual playtest (about 10 minutes)

Things that automated checks cannot judge: control feel, animation, camera, fun.
Please note anything that feels wrong next to the step number.

1. Start the game. Main menu → **Быстрый матч** → start with defaults. Menus must be fully usable with arrows/Enter/Esc.
2. Kick-off: you control the striker (yellow ring + arrow). Press **J** with no direction: short pass to a nearby teammate; control should jump to the receiver.
3. Run with WASD in all eight directions, then with **Shift**. Check: the player turns smoothly, diagonal speed is not faster, the ball stays near his feet, stamina bar drains only while sprinting.
4. Sprint and turn back sharply: the ball should swing wide and can be lost — that is intended, but it must not feel random.
5. Hold a direction and press **J**: the pass must go to a teammate in that direction (never to one behind you when you aim forward).
6. **L** toward a forward who is running: the ball goes into space ahead of him. **I**: lofted ball; watch the ball shadow for height.
7. Near the box hold **K** ~0.3 s and release: low driven shot. Hold ~0.8 s: high/over the bar. Aim with A/D (or the keys that point along the goal line).
8. Lose the ball. Press **E**: you should get a defender who can actually reach the play. Press **E** again quickly: next candidate.
9. Run at the ball carrier and press **Q** once from ~1.5 m in front: sometimes you win it; from behind or from too far you miss and stumble.
10. Let the ball go out for a throw-in, a corner and a goal kick: play must resume by itself; when you take it, the hint line appears.
11. Press **F3**: role/duty labels, target lines, orange press line, yellow cover line, pass options of the ball carrier. **Tab** selects another player.
12. **Esc**: pause — everything on the pitch must freeze, including the clock. Resume.
13. Play to full time: result screen with statistics → **Продолжить** returns to the menu.
14. Career: **Карьера → Новая карьера**, pick a club, open **Состав**, swap two players, **Трансферы** buy one player, play the fixture, check **Таблица**, exit, start the game again and **Продолжить карьеру**: round, table and budget must be the same.

Questions for you: Is passing responsive? Does the AI teammate movement give you options? Are opponents too easy / too hard on «Средняя»? Is the camera height comfortable? Any animation that looks broken?

## Windows acceptance record after the audit fixes

Record commit/build, Windows version, CPU/GPU, resolution/DPI, keyboard layout, difficulty and match length.
Start the actual exported EXE from a fresh extraction; do not substitute the editor or Linux pack loading.
Keep observed FPS/frame-pacing evidence separate from MovieMaker output or accelerated headless speed.

Add these focused regressions to the ordinary checklist:

1. Aim a pass forward with a nearby teammate behind you: assistance must follow intent, not turn backward.
2. Pass to a clearly selected teammate while a different teammate is closer to the ball path: confirm the
   initial control ring follows the intended receiver; later interceptions/claims may legitimately change play.
3. Charge K, pause, release K in the menu, resume: no ghost shot. Repeat holding through resume and with
   window focus lost; a fresh deliberate charge/release must still work.
4. Replace a tired/recovering player: fresh substitute can act normally, is correctly named/numbered and
   does not inherit an old shot/tackle. Verify five-sub limit and career participation after full time.
5. Play two short matches, one controlling each side, with at least one full half-time transition. Check
   camera-relative movement, aim, offside-facing directions, radar and control markers in both halves.
6. Complete a career match, quit, relaunch EXE, continue: same fixture/round, lineup, budget and table.

Rate 1–5 and give one concrete episode for any score below 4: movement/turning, pass intent, shot response,
switching predictability, useful teammate options, opponent pressure/fairness, ball visibility, camera and fun.
For tactical complaints note the mode, seed if visible, game minute, ball area and action; a short clip helps.
Do not demand a long written report from the player before fixing a reproducible fault.

Keep PLAY01 open until these checks have observations from an actual person on Windows. Automated tests,
synthetic input, screenshots and the audit's three sampled motion frames cannot close this gate.

## Player-career checks when the PC tasks enable them

This mode is planned in the current handoff, not playable yet. Add observations at its runnable checkpoints;
do not report these future checks as already performed. Prepare representative saves where needed so the
tester does not have to play ten seasons to exercise a transfer or a national return.

1. Create a supported outfield player, choose a plausible first club, inspect strengths/weaknesses and the
   next fixture. Club and player career entries/saves must be unambiguous.
2. Play locked to the avatar. Pass, lose possession, change half and take an off-ball position: control must
   stay with that identity. A pass request may be declined for a football reason; useful openings should be noticed.
3. Start as a substitute, skip to entry, then play. After being substituted out, inputs must not control the
   new identity in that slot. Continue to full time without being forced to watch the bench interval.
4. Check a good midfielder/defender performance without a goal. Read feedback and selection reasons; judge
   whether they match what happened and give an understandable next objective.
5. Advance a training week, save, reload and revisit the result. Attribute/experience/appearance rewards and
   trust changes must not repeat. Bench training and automated drills must leave a viable route forward.
6. From prepared saves, stay/renew, accept a move, take/return from a loan and reject an expired offer.
   Check role, rivals, money, next playable action and continuity of the avatar/history.
7. Enter a U21/senior fixture, finish and return to club. Club ownership, table and contract remain correct;
   caps and national results are separate. Check camera, both halves and workload/readiness continuity.
8. Inspect the career timeline/season summary. Its milestones must match actual recorded events. Test the
   whole keyboard route at 720p and the real machine's normal resolution, with sound and focus loss/resume.

Record brief actual observations: input/control, off-ball opportunities, ratings fairness, development pace,
clarity of club choices and desire to play the next match. A working menu or an automated twenty-season run
alone cannot establish that the career is enjoyable.
