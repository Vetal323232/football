# Player career: agreed product and integration specification

Status: **authorized design, not implemented**. Added 2026-11-14 after the gameplay audit.
Task status and execution order live only in [AI_WORK_PLAN.md](AI_WORK_PLAN.md), tasks PC00–PC09.
Start/resume through [CLAUDE_MASTER_PROMPT_EN.md](CLAUDE_MASTER_PROMPT_EN.md) and the top of
[PROGRESS.md](../PROGRESS.md). Existing correctness tasks remain prerequisites, not completed work.

## 1. Experience and scope

The user wants dynamic short matches with believable football decisions, plus an unhurried career as one
footballer: earn minutes, choose a style, gradually improve, receive better club offers, compete for a
national-team place and build a history across seasons. Keep the existing club career and quick match.
Use the same offline Godot 4.5.1/GDScript match engine, keyboard controls and free/original assets.
There is no authorized Rust rewrite. Optimize measured bottlenecks only.

An ordinary young player should be useful immediately in one area while having clear weaknesses.
Example: a quick winger with inconsistent first touch and limited stamina; a passer who struggles in duels.
All outfield roles must be represented in assessment and development. Goalkeeper player control is a later
feature: do not offer a playable goalkeeper career until its actual controls and mechanics exist.

Completion includes a real multi-season loop and national-team selection/fixtures; a player editor and
an experience bar alone do not complete this specification. Implement the loop in the PC task increments.
Story events can use concise Russian messages and existing match scenes; cinematic production is unnecessary.

## 2. Mode and identity contract (PC00, PC01)

- Keep TEAM control as the default for current exhibition/club matches. Add an explicit PLAYER_LOCKED
  mode to MatchSetup with a stable controlled-player UID; do not infer mode from scene names or slot numbers.
- The avatar remains the same person after passing, half-time, team formation changes, loans, transfers and
  national selection. `SimPlayer.id` is a reusable match slot; `SimPlayer.uid` is the career identity.
- In PLAYER_LOCKED mode, disable automatic receiver/owner handoff and team-switch cycling. INPUT02 still
  applies to TEAM mode. E may become a mode-specific pass request, with correct translated help.
- A pass request is an input to ordinary tactical evaluation, with a bounded lifetime/cooldown. It neither
  guarantees a pass nor bypasses interception/offside/physical constraints. Partners must recognize genuinely
  available options; repeated requests must not force reckless passes or farm rating/experience.
- Keep the same physical commands and limits as AI. TeamAI controls all other players and supplies useful
  support. Optional held positional assistance must be explicit, cancel immediately on manual input, and
  must not silently override deliberate movement.
- While the avatar is on the pitch, exactly one human-controlled player exists and its UID is the avatar.
  While the avatar is on the bench, omitted, substituted out or retired, zero on-field human players is
  correct. Retain the old exactly-one assertion unchanged for ordinary TEAM-mode input fuzzing.
- Handle a substitute replacing the avatar's slot: stop controlling that slot before its new identity can
  receive human input. Bind an entering avatar by UID after substitution. No career identity is reassigned.
- Other players take their own restarts. An off-field avatar does not steal the kicker or goalkeeper.
- Bench time can be simulated to the actual entry point; after substitution out, simulate to full time.
  Offer a clear continue action; do not require watching the whole bench interval in real time.
- An early match exit keeps the fixture unplayed and does not bank partial rewards. Mid-match career saving
  remains deferred. Pause/focus input policy is shared with the corrected INPUT03 behaviour.
- Provide a player-follow camera with sufficient view of the next passing/defending decision, a visible avatar
  marker and an accessible wider view. Avoid camera snaps when another player receives the ball.

## 3. One world, separate human career state (PC00, PC05)

Extend the existing CareerState/world, fixture guards, Schedule, LeagueData and SaveManager. Do not build
a second football simulator, duplicate standings engine or separate copy of the avatar for every mode.

Introduce explicit mode/versioned fields and a namespaced player-career profile. A suggested data contract:

| Entity | Required meaning |
| --- | --- |
| Mode | `club` or `player`; old saves without it migrate explicitly to `club`. |
| Avatar | Stable player UID, date of birth or documented age basis, football nationality, preferred position, dominant foot, style and development choices. |
| Abilities | Persistent bounded attributes with one source of truth in the world player record. |
| Condition | Short-term stamina is match state; readiness/fitness persists on a documented recovery schedule. |
| Form | Recent performance estimate with minutes/sample confidence; distinct from permanent abilities. |
| Coach trust | Scoped to the current club/coach and national coach, with reasons and bounded changes. |
| Reputation | Persistent evidence of performance, adjusted for competition and role; distinct from form/trust. |
| Contract | Owning club, term, agreed wage, promised role and relevant clauses. |
| Registration/loan | Where the player currently plays, parent owner, borrower and return date; one active club squad membership. |
| Competition | Stable ID, kind (league/cup/U21/senior international), dates and participant references. |
| Match record | Globally unique fixture ID, source (`played`/`simulated`), result and per-UID participation/facts. |
| Reward ledger | Durable keys for fixture applications, training weeks, transfer acceptance and national callups. |
| History | Debuts, appearances, contracts, transfers, tournaments and other events derived from committed outcomes. |

The current `player.club`/squad relationship can remain the active registration link. A loan's owning club
must then be stored separately in the contract. Normal transfers have the same owner and registration.
Do not put a loaned player in both clubs' active squads or pay a transfer fee to the borrower by accident.

Club membership and national selection are different relationships: the national squad references the
same player record. It never changes `player.club`, career employment, club budget or the club fixture.
Do not temporarily overwrite `user_club` to play for the country; route through an explicit fixture context.

Preserve `user://saves/career.json` as the existing club slot. A suitable separate player slot is
`user://saves/player/career.json`, using the existing isolated-directory mechanism and its own backup.
Player saves must not appear as club saves just because their root containers look similar.
Validate before normalization, version and test migrations, keep known-good originals recoverable, and
reject unsupported future schemas. Migration must preserve IDs, results, budgets and valid lineups.

## 4. Match evidence and fair assessment (PC02)

Record neutral football facts at the common simulation boundary; assess career consequences outside MatchSim.
Keep goals, passes, interceptions, turnovers, relevant positional observations, entry/exit and participation
intervals by UID. A substitution must split the outgoing and incoming identities' statistics correctly.
Detach any event collectors during teardown; respect MEM01 and deterministic RNG.

Distinguish simulation seconds, active-play seconds and nominal football minutes. A six-minute match
represents a full fixture; pause/bench time must not create played minutes or training rewards. Record the
chosen conversion explicitly. Rating expectations account for a ten-minute cameo, role and opportunities.

Evaluate forwards, midfielders and defenders appropriately. A midfielder can excel without a goal;
protecting a passing lane can be useful without a tackle. Reward measured useful actions, not key presses,
distance spam, repeated harmless five-metre passes or calling for the ball. Do not claim a decoy run
created a chance unless an actual observable criterion supports that claim.

Separate the four outputs: abilities, form, coach trust and reputation. Display concise reasons and one
actionable improvement. A single mistake must not erase months of established trust. Confidence in a short
cameo is lower than in several full appearances; avoid blindly extrapolating tiny samples per 90 minutes.

For result-only simulated fixtures, label the absence of detailed event facts. Use documented background
training/participation estimates rather than fabricated first-touch, tackle or off-ball observations.

## 5. Gradual development and training (PC03)

Choose an initial age around 16–18, an outfield role and a flexible specialization. The style is a starting
preference/strength profile, not a permanent class that traps the user after creation. Dominant-foot effects
must correspond to implemented mechanics; until then describe the selection as cosmetic, not a hidden bonus.

Use game-calendar training weeks, a small number of focus slots, practical exposure and bounded development
choices. Training can be automated after learning a drill; repeat mini-games must not be compulsory for a
viable career. Bench players retain a slower development route through training/reserve opportunities.
No real-time login, waiting, payment or energy purchase is needed. Pausing/offline time does not age the save.

Initial balancing hypotheses, to be tested rather than claimed as established results:

- A normal young start is roughly 55–62 overall in a suitably weaker environment.
- With regular minutes and sensible training, target about 2–4 overall points per completed season;
  low-minute seasons grow more slowly but do not strand the player. Growth varies with age and focus.
- Developing an already high attribute costs more; exceptional seasons can differ within a documented cap.
- Reaching elite level is a multi-season pursuit. A legal normal-start career must not reach 90 overall in
  its first season by repeating drills, short passes, reloads or changing match length.
- Show smaller milestones between attribute gains: debut, longer appearances, first start, sustained form,
  a scout watching, a new training competency. Character improvement must affect shared match execution.

Put all rates, caps, confidence windows and costs in named career tuning data. Run fixed-seed comparisons
before finalizing values. Publish the growth distribution, including bench, average, excellent and aging
players. Do not promise exactly the same growth or a transfer every year.

One award owner decides development for the avatar. The existing CareerState._develop and the new career
pipeline must not both award full growth/apps for the same fixture. Calendar training and match awards have
different ledger keys; reloading, returning through menus and duplicate result events repeat neither.

## 6. Trust, competition and minutes (PC04)

Select lineups by role fit, ability, recent form, condition, trust and tactical needs, including actual
competition for the avatar's position. Use a rolling body of evidence and understandable reasons.
Maintain gradual roles: prospect, rotation, regular starter, key player. Larger clubs have stronger rivals.

Translate useful performances into opportunities; also allow reduced minutes, a recovery path and a loan.
Small improvements in role/minutes should appear sooner than large permanent attribute gains. Generate
objectives appropriate to position, opponent, match state and time available. No forced hat-trick for a
short cameo or mandatory forward-style goal quota for a centre-back.

The coach can choose the actual minute of entry/exit based on condition and the game. User and AI substitutes
obey the same legal limits. Trust belongs to a particular coach/context; a new club or coach can reassess it,
but must not arbitrarily erase abilities/history. The user can inspect competing players and selection reasons.

## 7. A bounded living world (PC05)

Eight clubs in one league give a limited ladder. Extend new player-career worlds in a bounded, data-driven
way: a reasonable first complete target is three fictional leagues of eight clubs and eight represented
nations. These counts are tuning/content targets, not a new hardcoded engine assumption. Preserve legacy
one-league club saves and their fixtures. Real licensed squads are not required.

Offer different club quality, resources and tactical styles. Reuse league scheduling/table logic per
competition. A date-based coordinator advances fixtures and training consistently across leagues, cups,
international windows and season rollovers; it must not call a single-league complete_round for every context.
Budget sums change only through declared transfers, wages, prizes or other documented transactions.

Generate legal club and national/youth position pools. Only supported football nationalities are selectable.
Age players at one documented calendar boundary; develop competitors and introduce replacement youth as
players retire. Avoid an aging world with no eligible U21 players, goalkeepers or affordable employers.
New cohorts have unique IDs; retired identities remain resolvable for history and are never recycled as a
different young player. Account for created/retired cohorts rather than asserting a permanently fixed world count.
The avatar may retire deliberately; do not silently retire an active save on an arbitrary birthday.
Provide a terminal career summary for a voluntary end and ordinary recovery options after a bad season.

## 8. Agent, offers, contracts and loans (PC06)

Club interest uses role need, sustained performance, minutes, age, abilities, competition strength, reputation,
affordability and tactical fit. Progress can be shown as observation, agent contact and a concrete offer.
One excellent match may attract attention without guaranteeing an elite contract.

For every offer show wage/term, expected role, positional rivals, club style and development environment.
The user can stay, request a move, accept a sensible step up, or choose an ambitious move with a bench/loan
risk. Make plausible opportunities available to ordinary developing players; disappointment must not leave
the save without a valid next action. Honor the possibility of becoming a legend at the current club.

Contract objectives guide negotiation; arbitrary action checklists must not invalidate an otherwise legal
renewal or strand the career. Revalidate money, squad room, dates and both parties at acceptance. Offer IDs
and accepted transaction keys prevent double payment or duplicated players on reload/click/retry.
Transfer windows, contract expiry, renewals and loan returns use calendar dates. Expired/stale offers fail
cleanly. Model owner versus borrower, wages and any fee explicitly; reuse existing atomic roster/budget
operations rather than implementing a second transfer path. Moving clubs preserves player UID/abilities/history.

## 9. Youth and senior national career (PC07)

National coaches select eligible players by position, form, level of play, actual competition and tactical
fit. A weaker nation's accessible place and a strong nation's crowded position need different evidence;
do not use one universal overall threshold or make elite-club employment compulsory.

Include U21 opportunities when age-eligible, first senior callup, substitute appearances, competition for
starts, qualification and a finals tournament. Keep U21 age rules simple, explicit and based on the same
calendar as club age. Prevent simultaneous youth/senior assignments for conflicting fixtures.
Provide valid squads and fallbacks for withdrawals; never invent a clone of the avatar to fill a roster.

Use one player record, readiness model and workload history across club/country. International windows
must not schedule impossible overlapping appearances. Record national caps/results separately from club
tables, budgets, apps and contract ownership. Explain selection and non-selection using real candidates.
Refresh valid callups each window; one omission neither ends the career nor permanently blocks selection.

## 10. Interface, events and history (PC08)

A useful weekly hub includes the next playable fixture, current role/selection reasons, condition,
training focus, recent feedback, development trend, agent interest, offers and national status.
Enabled actions must work through a full next-match/save/reload cycle; hide or explicitly disable unfinished
features rather than presenting dead buttons. Reuse UIKit, Russian localization and keyboard navigation.

Stories come from committed events: debut, first start, an emerging competitor, a coach/tactic change,
return from loan, facing a former club, national debut and tournament achievements. Record only systems
that exist; do not generate an injury, manager change or captain appointment with no corresponding state.
Show a timeline and seasonal/career totals. Lifestyle/sponsors can remain optional backlog; football
consequences and the on-field loop take priority over shopping/cutscenes.

## 11. Acceptance and delivery (PC09, PLAY01)

Build tests incrementally inside each PC task, then a bounded multi-season integration journey. Suggested
future files: `tests/player_career_tests.gd`, `tools/player_career_journey.gd`. They do not exist in this
handoff; do not report their commands as executed or counts as passed before implementation.

Required controls include:

- TEAM mode still follows its corrected receiver logic; PLAYER_LOCKED mode always follows UID while active.
- Bench/omitted/subbed-out states have zero on-field human players; entry binds the correct slot and
  return from a country fixture preserves the club. Test both halves, possession changes and restart takers.
- Deliberate movement is respected; open pass requests can be considered and covered/offside requests rejected.
- A useful midfielder/defender can rate well without scoring; tiny cameos and repeated safe passes do not
  dominate rating/XP. Feedback cites actual measured facts, including uncertainty for simulated appearances.
- Abilities/form/trust/reputation change independently with bounded effects and visible reasons.
- Duplicate application, save/reload, menu return and simulated weeks do not duplicate rewards or transactions.
- Stay/renew, move, loan, loan return, contract expiry and rejected/stale offers all leave a legal state.
- U21/senior eligibility, position competition, national return and non-overlapping schedules work without
  changing club ownership, club standings or duplicating the player. Caps and club apps remain distinct.
- Several fixed seeds complete at least ten automated seasons, with one twenty-season world-aging run;
  inspect growth distributions, club/national roster validity, accounts, fixture uniqueness and calendar bounds.
- Old valid club saves load/migrate without losing progress; corrupt primary/backup combinations fail or recover
  cleanly; player and club slots cannot overwrite each other. Match state is finite and lifecycle cleanup holds.
- Quick match, old club career, legacy scenarios, input fuzz and original audit regressions remain tested.

Automated journey evidence cannot close human enjoyment or Windows execution. Extend PLAY01 with an actual
single-player match, a bench entry, a substitution out, a career week/renewal and a national-team return.
Do not call the career complete until PC00–PC09 acceptance is met; label partial vertical slices honestly.

## 12. Research provenance and adaptation

These are documented inspirations, not claims that our game implements them or that closed-source
internals were inspected. Keep the version distinctions. Our detailed contracts above are custom design.

| Source | Documented mechanic and useful lesson |
| --- | --- |
| [FIFA 22 career deep dive](https://www.ea.com/ea-originals/news/pitch-notes-fifa-22-career-mode-deep-dive) | Bench entry, manager trust, position/context-based objectives and national selection; use meaningful minutes and feedback. |
| [FC 26 career deep dive](https://www.ea.com/games/ea-sports-fc/fc-26/news/pitch-notes-fc26-career-mode-deep-dive) | Archetypes/specializations and a link between training choices and match-event XP; adapt into gradual specialization. |
| [FC 24 career deep dive](https://www.ea.com/games/ea-sports-fc/pitch-notes/news/fc-24-career-deep-dive) | Agent recommendations, club targets, wage expectations and contract objectives; use explainable offers without arbitrary renewal dead ends. |
| [PES 2009 published Become a Legend guide](https://www.piggyback.com/en/wp-content/uploads/sites/7/2020/04/PES09_E_SamplePages.pdf) | Individual club/international career and a pass request that teammates may decline; preserve independent football decisions. |
| [New Star Soccer developer listing](https://play.google.com/store/apps/details?id=com.newstargames.newstarsoccer) | Skills and relationships with coach/teammates/sponsors; keep decisions tied to football consequences. |
| [NBA 2K26 MyPLAYER developer report](https://newsroom.2k.com/news/nbar-2k26-myplayer-builder-delivers-all-new-animation-glossary-scouting-reports-and-build-by-badges-for-increased-customization) | Specialization and a scouting report showing strengths/weaknesses; make the development path understandable. |
| [MLB The Show 25 RTTS manual](https://mlb25.manual.theshow.com/en/rtts.html) | Amateur stages and performance-earned development choices; use worthwhile early milestones and player agency. |

Refresh only a source whose current detail affects an implementation decision. Do not spend every resumed
session repeating the research or loading all source pages instead of executing the next ready task.
