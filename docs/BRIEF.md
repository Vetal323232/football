# Claude Code implementation brief: Open Pitch

## 1. Deliverable and priorities

Build a standalone Windows 3D association football game inspired by the match gameplay and club career experience of EA Sports FC. Working title: Open Pitch. Use Godot 4 with GDScript, pinning a compatible stable engine version after inspecting the environment.

The first complete release must include offline 11v11 matches against AI, keyboard control with active-player switching, and a functional club career connected to those matches. All runtime features must work offline without a backend or external API.

Communicate with me in Russian. Use English for code identifiers and technical project documentation. The game UI should be Russian, with strings separated from gameplay logic.

My overriding priority is the quality of the football gameplay and the intelligence of both teams. Players must make understandable football decisions and create meaningful choices for the human player. Simple, coherent visuals are acceptable; visibly broken animation, unreadable action, and unresponsive controls are not.

Priority order:

1. Responsive controls, consistent ball behaviour, and satisfying football interactions.
2. Intelligent teammates, opponents, off-ball movement, defending, and goalkeepers.
3. A reliable complete 11v11 match with its essential rules.
4. Club career, transfers, player development, and persistent saves.
5. Additional presentation, formations, and modes.

Spend implementation and iteration effort according to this order. Career expansion is gated on the match and AI validation criteria below.

Budget for the engine, models, animations, audio, tools, and other assets: zero. Use original fictional clubs and players and appropriately licensed free assets.

## 2. Execution and continuity

Inspect existing CLAUDE.md, AGENTS.md, README, repository contents, and available tools before editing. Preserve useful existing work. Create a Godot project if the repository is empty.

Check the OS, Godot executable, engine version, renderer availability, and execution environment. Support the actual Windows or WSL setup rather than assuming paths or commands. Use available installation methods for missing free dependencies. If something requires my intervention, identify the precise blocker and continue work that does not depend on it.

Make a short implementation plan with observable acceptance criteria, then implement it. The deliverable is runnable code and a playable game.

Resolve routine technical choices independently within this brief. Record important assumptions and tradeoffs. Ask only when missing information materially changes the product or blocks progress.

Work in small, verifiable increments. Run the relevant checks, fix the failures, and advance when the current milestone meets its criteria. Do not request approval for every file or routine milestone.

Use this improvement loop throughout development:

1. Define the player-visible behaviour and a reproducible situation.
2. Implement the smallest coherent solution.
3. Run it and inspect actual behaviour using the best available tools.
4. Identify the most consequential gameplay or correctness defect.
5. Fix the cause and rerun the relevant scenario plus affected regression checks.

Do not weaken a meaningful check simply to obtain a passing result. If a check is wrong, explain and document the correction.

Keep a concise CLAUDE.md with essential project rules and verified run/check commands. Store the detailed implementation brief and design separately, avoiding unnecessary duplication in always-loaded instructions.

Maintain PROGRESS.md with completed milestones, known defects, current tuning, exact commands, and the next executable task. On continuation, read it and inspect the repository before resuming. Preserve working features across sessions. If a session ends early, leave a runnable checkpoint and an accurate handoff.

## 3. Engineering foundations

Use readable typed GDScript where appropriate. Separate responsibilities into manageable scenes and systems: match flow, players, ball, input, camera, team coordination, individual decisions, goalkeeping, rules, career, persistence, and UI.

Keep main scenes editable and understandable in Godot. Avoid a giant script that constructs and controls the entire game, and avoid speculative frameworks that do not support a current requirement.

Separate simulation from presentation. Use a consistent fixed-step simulation for physics and gameplay time. Pausing must stop match progression, AI decisions, and match-related timers.

Expose player attributes, movement tuning, ball properties, passing/shooting parameters, and AI weights through editable resources or configuration. Important tuning should not require rewriting behaviour code.

Use stable IDs for clubs, players, fixtures, seasons, and completed results. Career and exhibition matches must share the actual match engine.

Choose implementation details based on observed behaviour and maintainability. The architectural suggestions in this brief are starting points, not reasons to retain a demonstrably inferior implementation.

## 4. Keyboard controls and game feel

Initial InputMap bindings:

| Input | Action |
| --- | --- |
| WASD or arrow keys | Movement relative to the camera projected onto the pitch |
| Shift | Sprint, consuming stamina |
| J | Short pass |
| K, hold and release | Charge and execute a shot |
| L | Through ball |
| I | Lofted pass or cross |
| E | Switch the controlled player |
| Q | Attempt a tackle |
| Esc | Pause/back |
| F3 | Toggle AI diagnostics |

Menus must support keyboard navigation. Display the controls in the game.

Movement should have acceleration, deceleration, and reasonable momentum while remaining responsive. Normalize diagonal movement and keep the visible body aligned with its physical movement.

Passing assistance should respect directional input, available teammates, and viable trajectories. A forward-directed pass must not inexplicably target a teammate behind the player. Choosing an intended receiver must not guarantee successful completion.

Player switching should select a useful player considering the ball, the threat, and the direction of play. Control handoff must preserve team responsibilities. Do not repeatedly switch players without user intent or let AI movement fight the human's input.

Shot outcome should reflect charge, direction, location, angle, movement, and player ability. Poor decisions should have understandable consequences.

Tackles require reach and appropriate timing, with a recovery period. Separate deliberate actions from held input so one button press cannot trigger repeated impulses or tackles.

## 5. Ball physics and possession

Give the ball one authoritative physical state. Avoid competing transform updates and velocity/force controllers.

Passes and shots launch the ball along a calculated trajectory. A free ball must not home toward a receiver after release.

Use controlled touches or bounded influence within physical reach for dribbling. The ball should allow mistakes, contested touches, and loss of possession.

Interceptions and tackles must depend on actual reach, timing, and movement. Possession cannot transfer from a distance, and players cannot teleport or receive hidden speed boosts.

Handle fast balls, posts, rebounds, and multiple contenders. Prevent tunnelling through the pitch, multiple kicks from one action, and possession oscillation several times in one physics step.

Assign clear authority over movement and ball contact during normal play, kicks, catches, and restarts.

## 6. Football AI: the core feature

Before implementation, briefly describe:

- What each team and player can observe.
- How team phases and responsibilities are assigned.
- Which actions a player compares.
- How space, pressure, interception risk, and progression are evaluated.
- How conflicting assignments and unstable decisions are prevented.

A practical baseline is a team coordinator, individual states, and utility scoring of candidate actions. Use a different implementation if it produces clearer, more reliable football without unnecessary complexity.

### Team structure and phases

Distinguish controlled possession, progression, chance creation, organized defence, defensive transition, attacking transition, and set pieces.

Players have home positions and role-specific responsibilities. Their positions should adapt to the ball, possession, pitch region, teammates, and threats.

Coordinate assignments that would conflict if chosen independently: primary presser, covering defender, short-pass support, forward runner, and central protection.

Maintain meaningful width, depth, and spacing. Teammates should not choose the same destination, block each other's routes, or all chase the ball.

Start with a well-functioning 4-3-3 whose defenders, midfielders, and attackers have genuinely different responsibilities. Expose width, defensive line height, pressing intensity, and passing risk as parameters. Add formations after validating the baseline.

### Decisions on the ball

Compare useful options: short pass, progressive pass, through ball, switch of play, dribble into space, hold possession, and shoot.

Evaluate:

- Receiver reachability and likely receiving position.
- Ball travel time versus opponents' feasible interception times.
- Pressure on both passer and receiver.
- Space, progression, and the receiver's options after receiving.
- Shooting angle, distance, blockers, and goalkeeper position.
- Loss-of-possession risk, available cover, stamina, and player attributes.

A backward pass can be the best decision under pressure. Forward direction alone must not dominate the score.

Players should recognize when a shot is worthwhile. Do not shoot indiscriminately whenever the ball is available.

Detect recurring dead-end possession patterns and seek a different way out. Avoid both constant forced attacks and endless risk-free exchanges without purpose.

### Off-ball attacking movement

Teammates must actively create passing options by:

- Leaving a defender's cover shadow to open a passing lane.
- Offering close support.
- Providing a deeper outlet.
- Timing runs behind the defensive line.
- Stretching the defence through width.
- Occupying distinct finishing zones.

Make movements complementary. When one player comes short, another can create depth or width instead of following into the same space.

Where the situation permits, a receiver should have a useful next action, including a third-player combination. Runs must account for offside and remain useful as the situation changes.

When a defender joins the attack, others compensate. Maintain defensive cover against a counterattack.

### Defending and pressing

Assign a primary presser based on reach, approach angle, and available cover. A supporting defender protects a dangerous continuation; remaining players retain useful defensive structure.

Shift toward the ball while protecting central space and tracking dangerous runs. Do not abandon the middle simply because the ball reaches the wing.

Use sensible handoffs of marking responsibility. Following one opponent should not tear the entire formation apart.

Pressing should respond to opportunities: a poor touch, a receiver facing away from the attack, proximity to the touchline, or supporting teammates. Avoid futile tackles from outside physical reach.

Predict feasible interceptions from the ball's trajectory and the defender's travel time. Separate the intent to intercept from guaranteed execution.

### Transitions

After losing possession, an appropriate nearby player may delay the attack while others recover and protect dangerous routes. Choose counterpressing when support and distance justify it.

After winning possession, recognize an advantageous counterattack and support it with distinct runs. If the opportunity is poor, retain the ball and reorganize.

Prevent collective hesitation, every player rushing at the ball, or a full reset that forgets existing threats and responsibilities.

### Goalkeepers

Position relative to the ball, goal, and immediate threat. Evaluate holding position, coming out, intercepting, catching, or parrying.

Respect reaction time, acceleration, reach, and rebounds. Saves must follow feasible movement.

After securing possession, choose a reachable teammate or a safe clearance and restart within a bounded time. Prevent indefinitely holding the ball.

### Stability, fairness, and responsiveness

Use reaction delays, minimum commitment times, and explicit replanning triggers. Do not alternate targets, movement directions, or roles every few frames.

Define how team instructions, individual decisions, animation, and physics interact. Reassigning control must not erase the player's tactical context.

Both sides use shared mechanics and fair physical limits. AI teammates should support the human-controlled player through the same coordinated logic used by the opposition.

AI must not read future input, silently change player abilities during an episode, or manipulate outcomes to force a score. Adjust difficulty through decision quality, execution error, and reaction time.

Update higher-level decisions at measured, appropriate frequencies and stagger expensive work. Preserve immediate responses to important events and smooth physics movement.

## 7. AI validation and tuning

Create reproducible diagnostic scenes with recorded seeds and configurable initial conditions. Small-sided setups are diagnostic tools; the final main match remains 11v11.

Use the production AI in these scenes. Do not script the expected sequence specially for a test.

F3 should expose roles, current intentions, target positions, pressing assignments, candidate passing lanes, and the reasons for important decisions. Limit detailed overlays to a selected player when needed for readability.

Validate at least these situations:

| Scenario | Expected observable behaviour |
| --- | --- |
| Build-up under pressure | Teammates create distinct passing options; the ball carrier can find a viable outlet when one exists. |
| A passing lane becomes blocked | The player accounts for interception risk and considers a reachable alternative. |
| A 3v2 attack | Attackers occupy different lanes, force defensive choices, and evaluate pass-versus-shot timing. |
| Opponent possession on the wing | One defender presses while others cover the continuation and protect central danger. |
| Loss of possession high up the pitch | Players divide delaying, recovery, and protection responsibilities. |
| A run behind the defence | The runner times the movement, the passer assesses the opportunity, and defenders respond to the threat. |
| Shot and rebound | The goalkeeper acts within reach; outfield players react to the loose ball. |
| A teammate is human-controlled | AI teammates offer useful options, including after active-player switches. |

For each scenario, define observable success conditions and failure invariants before tuning. Record seed, setup, run command, outcome, and remaining defects.

Change pressure, opponent placement, and initial conditions. Good decisions should adapt for understandable reasons. Do not enforce one identical action sequence across materially different situations.

Run several full AI-versus-AI matches using different seeds. Investigate deadlocks, crowds around the ball, aimless shots, repetitive passes, absent support, broken marking, and restart failures.

Track useful diagnostics: possession, attempted/completed passes, interceptions, shots, turnovers, repeated action cycles, and conflicting assignments. Use metrics alongside observation; high numbers alone do not establish good football.

For a meaningful AI defect, keep a reproducible regression case. Tune using more than the exact setup that first failed.

Completion requires evidence from actual episodes, fixes to significant failures, and a clear account of what still needs human playtesting. Class names and plausible-looking code are not evidence of intelligent behaviour.

## 8. Complete match requirements

Implement:

- Two teams of eleven, including goalkeepers.
- A smooth elevated touchline/broadcast camera.
- Kick-off and restart after a goal.
- Score, clock, two halves, and switching ends.
- Throw-ins, corners, and goal kicks.
- Basic offside: evaluate position at the relevant teammate touch and actual involvement.
- Match completion, result screen, pause, restart, and return to menu.

Award a goal once, only after the entire ball crosses the goal line within the goal mouth. Handle own goals, posts, and the crossbar consistently.

Restarts may use simple animations but must restore valid player positions, ball state, ownership, and match flow.

Use a configurable default duration, such as six real minutes. Explicitly document any deferred rules. Fouls, cards, elaborate free-kick routines, and replays can follow after the core release.

Keep tactical reasoning consistent with the implemented offside and restart rules.

## 9. Simple, coherent presentation

Create a clean, readable style: pitch and markings, goals, a simple stadium, contrasting team kits, distinct goalkeepers, shadows, and a clear controlled-player marker.

Visible players should have a head, torso, arms, and legs with sensible proportions. If appropriate free models are unavailable, build coherent simple models and basic procedural animations. Capsules are acceptable in diagnostic scenes.

Provide idle, run, sprint, and key action states. Prevent inverted joints, detached limbs, scale jumps, persistent clipping into the ground, and visual movement disconnected from physical movement.

Frame the useful area of play, ball, and controlled player. Keep camera motion smooth and avoid effects that obscure passing or timing.

Separate visual rigs from collision and AI so presentation improvements do not destabilize gameplay.

Use only free assets whose terms you have checked. Record source, author, license, and required attribution in ASSETS.md and credits. Runtime play must not depend on downloading assets.

## 10. Functional club career

Add career after the gameplay validation gates pass.

Initial scope:

- One fictional league of eight clubs.
- Usable full squads with starters, substitutes, and goalkeepers.
- Club selection and a new-career flow.
- Starting-lineup selection and basic substitutions.
- A double round-robin schedule.
- A table with played, won, drawn, lost, goals for/against, goal difference, and points.
- Playing the user's fixture through the common match engine.
- Simulation of other fixtures in the round.
- A simple transfer list with buying and selling.
- Club budgets and understandable player prices.
- Attribute development through match participation.
- Season completion and progression to the next season.
- Local save and load.

Use three points for a win and one for a draw. Break ties using goal difference, goals scored, then a stable additional ordering.

Attributes must affect real match execution: pace, passing, shooting, control, defending, stamina, and goalkeeping. Document the overall-rating formula if used.

Transfers must update ownership, both squads, and both budgets consistently. Prevent duplicated players, invalid amounts, and squads that cannot field a legal team.

Apply each match result, simulated fixture, and development award exactly once. Returning to menus or reloading must not duplicate points, money, or progression.

Save under user:// with an explicit schema version and stable references. Use temporary-file replacement, a previous-save backup, and validation of references and data. Provide an understandable recovery path for corrupted saves.

Between-match saving is required. Mid-match saving can be deferred.

## 11. Interface, performance, and audio

Provide the main menu, quick match, career, pause, results, and necessary club screens. Every enabled control must perform its stated action.

Keep keyboard focus and gameplay input separate while a menu is open. Prefer physical key bindings where appropriate so movement remains usable with a non-English keyboard layout.

Use a consistent, simple Russian UI. Keep strings localizable. Include basic volume and display settings where needed for usability.

Add restrained ball-contact, whistle, goal, and UI sounds using suitable free assets or original simple sounds.

Target smooth 11v11 play, aiming for 60 FPS on the actual target machine at sensible settings. Profile and report measured results; this is an engineering target, not an assumed achievement.

Choose a compatible renderer and moderate visual settings based on the environment. Optimize demonstrated bottlenecks while retaining tactical behaviour. Avoid running expensive global searches independently for every player on every physics tick.

## 12. Milestones and release gates

### A. Environment and controllable football foundation

Create a runnable Godot project, pitch, goals, camera, controlled player, ball, and keyboard movement/passing/shooting.

Acceptance: the project imports and launches, controls respond correctly, ball interactions are stable, and control/possession handoff works in a repeatable setup.

### B. Tactical interactions in diagnostic scenes

Add teammates, opponents, and a goalkeeper. Implement support, action selection, pressing with cover, and transitions. Provide F3 diagnostics.

Acceptance: the relevant Section 7 episodes demonstrate the intended behaviour under varied conditions, with recorded results and significant failures fixed.

### C. Coordinated 11v11

Scale up using the same production systems. Validate formation, role differences, human-controlled team support, and AI-versus-AI matches.

Acceptance: full-team episodes retain structure and useful support without ball swarms, conflicting assignments, persistent indecision, or deadlocks. Record the tested configuration.

### D. A complete playable match

Implement the rules, halves, result flow, menus, and coherent presentation.

Acceptance: an entire match runs from menu to result and back without manual repair. Inspect the actual visual result and control feel when tools permit.

### E. Career integration

Connect the league, fixtures, transfers, development, and saves to the validated match engine.

Acceptance: play a fixture, advance a round, apply other results, save, close the game, reload, and continue without duplicating or losing state. Verify transfers and development affect subsequent matches.

### F. Release 0.1

Exercise the full user journey over multiple career rounds, season completion, and rollover. Resolve blocking defects and produce a Windows build when the necessary export templates are available.

Acceptance: report the exact build/run/check commands, actual evidence, known limitations, and outstanding manual checks.

Advance sequentially. A small-sided diagnostic match is a milestone, not the final 11v11 release. Do not count the overall project as complete while required milestones remain.

## 13. Verification and evidence

Add meaningful automated checks for schedule generation, standings, one-time result application, transfers, development, and save/load round trips.

For the match engine, check goal deduplication, ownership changes, ball-out events, restarts, pause, switching ends, and controlled-player handoff.

Use commands supported by the installed Godot version for import, project validation, scenario execution, and export. Capture the actual commands and outcomes.

Distinguish:

1. Import/parser/build checks.
2. Headless simulation and logic checks.
3. Visual inspection and interactive control testing.

Headless success does not prove animation quality or enjoyable controls. Use visual/interactive tools when available. Otherwise mark those criteria as unverified and provide a short reproducible manual playtest.

For each milestone, compare the implemented behaviour against this brief and make a separate defect-finding pass. Prioritize defects affecting football decisions, responsiveness, physical consistency, and progression integrity.

When an issue is found, reproduce it, fix its cause, and rerun the relevant scenario. Inspect the changed behaviour rather than assuming a successful edit fixed the problem.

Report evidence honestly. Do not invent successful runs, FPS figures, builds, screenshots, license checks, or human assessments of fun.

## 14. Repository deliverables and first action

Maintain:

- The runnable Godot project, main scene, source, resources, and game data.
- Diagnostic scenes and meaningful automated checks.
- README with exact installation, run, controls, checks, and Windows export instructions.
- Concise CLAUDE.md with essential rules and verified commands.
- The detailed brief in a dedicated project document.
- DESIGN.md describing simulation ownership and AI decisions.
- AI_VALIDATION.md containing scenario conditions, seeds, actual results, and known weaknesses.
- ASSETS.md recording asset provenance and licenses.
- PROGRESS.md containing current status, blockers, and the next concrete action.

End each work session with:

1. What I can launch and play now.
2. Which milestones are actually complete.
3. What you ran and what the evidence showed.
4. Remaining defects, especially in AI behaviour.
5. Exact instructions to launch or resume.

Start now: inspect the repository and environment, write the short plan, and implement Milestone A. Continue through the milestones in order as session capacity allows. Keep the playable project and progress record accurate throughout. Make implementation decisions in service of responsive, coherent football with intelligent team behaviour.


