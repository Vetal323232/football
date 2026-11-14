# Open Pitch — unified implementation request for Claude Code

This is the single current execution request. Task status and acceptance live in
[AI_WORK_PLAN.md](AI_WORK_PLAN.md); architecture navigation in [PROJECT_MAP.md](PROJECT_MAP.md).
The approved player-career extension is [PLAYER_CAREER_SPEC.md](PLAYER_CAREER_SPEC.md).
Earlier audits and the original BRIEF remain evidence/background, not competing work orders.

## Goal and scope

Deliver enjoyable offline keyboard football in Godot 4.5.1/GDScript, GL Compatibility, Windows target,
free/original assets. The user prioritizes thoughtful AI, responsive control and clear simple 3D. Use dynamic
short matches with believable decisions. Keep quick match and the existing club career; add the approved
career as one footballer with gradual development, earned minutes, meaningful offers/loans and national play.
Communicate in Russian; code/technical docs in English; Russian UI through translated keys.

This request includes the previously unimplemented audit repairs. Do not replace that queue with the new
mode or declare old work complete because a newer brief exists. Godot stays; there is no Rust rewrite.
Do not implement every brainstorm item at once. The queue distinguishes required increments and backlog.

## Join or resume without losing context

The published handoff branch is `codex/deep-audit-claude-brief` in `Vetal323232/football`.
The latest independent review incorporates Claude's implementation through bbe7dbb; see the Active handoff
and SESSION2_REVIEW_2026-11-14.md. SAVE01/CAREER01 are reopened; keep their existing repairs. Earlier
consolidation references 87501a5/7265450 and gameplay a47746e are historical references,
not instructions to reset a newer branch. Inspect actual branch, HEAD, status, relevant commits and local
instructions first. Preserve the user's and other contributors' uncommitted work.

If already working on a branch with implementation changes, continue that branch and integrate this brief
without replacing its code. Otherwise create a working branch from the current published handoff. Do not
merge/reset the default branch merely to discover instructions. Never force-push over a colleague.

Load only the context needed for the next increment:

1. CLAUDE.md and the **Active handoff** at the top of PROGRESS.md.
2. The queue index in AI_WORK_PLAN.md, then the current task's section and acceptance checks.
3. The relevant rows of PROJECT_MAP.md and actual implementation/caller files.
4. The particular audit finding or PLAYER_CAREER_SPEC section cited by that task.

Use `rg -n '^## ' docs/AI_WORK_PLAN.md` to locate a section. Do not preload every audit log, all design files,
all brainstorm ideas or the entire research history on each resume. Historical raw evidence is immutable.
Read the broader specification when a cross-system decision needs it, then record the decision briefly.

If the handoff says a task was partly implemented, inspect those changes and rerun its named checks before
continuing. A reported token/context limit means resume the next unfinished action, not restart the project,
repeat completed research or discard uncommitted implementation. Mark DONE only from actual acceptance evidence.

## One queue and small complete increments

AI_WORK_PLAN.md is the **only authoritative task/status queue**. PROGRESS.md is a short resume pointer and
current evidence record; the map navigates ownership; PLAYER_CAREER_SPEC defines product/data contracts.
IMPROVEMENT_IDEAS.md is the idea register. Do not create another independent TODO/roadmap or duplicate statuses.

Start with the first ready task, retaining all IDs:

- Foundation: QA01, RULE01/02, SAVE01, MEM01, SUB01, INPUT01/02/03, CAREER01.
- Tactical repair: AI01/02/05/03/04; preserve production AI and compare unchanged scenario predicates.
- First improvement slice: V01 readability and the T01 give-and-go/third-man experiment.
- Player career: PC00–PC09, in dependency order, with a runnable tested checkpoint after each increment.
- Further selected match improvements: B01 first touch, B04 shot preparation, T07 styles, T08 rotations, P01 drills.
- PLAY01 is actual Windows/human acceptance, repeated for changed modes. Its unavailable environment must be
  recorded, but it does not block independent automated work or authorize a claim of full release acceptance.

For each task: reproduce/establish baseline, inspect callers, implement one causal change, run meaningful
acceptance and affected neighbours, inspect behaviour, update the queue/handoff, commit a coherent increment.
Continue ready authorized work while the session permits; do not stop after merely writing a plan.
A dependency-blocked feature stays open. An unrelated manual gate must not paralyze the whole queue.

Do not consume the whole context on a giant rewrite. At a task boundary or when context becomes tight,
reserve enough capacity to write a useful checkpoint and preserve the work. Record the exact next action
before stopping. No tool can guarantee this account's next Claude session or token quota; repository state
must be sufficient for another session/colleague to resume.

## Non-negotiable implementation contracts

- MatchSim owns ball/motion/rules; controllers write PlayerCommand. Keep fixed 60 Hz, pure RefCounted sim,
  sim.rng determinism, shared human/AI mechanics and existing physical prediction. No visual/mission logic in sim.
- TEAM control keeps intended-receiver handoff. PLAYER_LOCKED binds a stable career UID, never a reused slot:
  passing cannot transfer control; bench/subbed-out means zero active humans, entry rebinds the avatar.
- Club, player career and national fixtures share world player identities and the match engine. A country
  callup never changes club ownership or club tables. Route results by explicit competition/fixture context.
- Apply fixture results, training, development, fees and offers once. Existing _develop and a new avatar
  progression system cannot double-award a match. Separate abilities, form, coach trust and reputation.
- Preserve legacy club saves, isolate the player save slot, validate nested data before normalization and
  test migrations/recovery. Loans separate owner from current registration without duplicating active squads.
- A player's role and minutes matter to assessment. Reward useful measured football, not action spam; expose
  uncertainty in result-only simulations. Training/bench opportunities must provide a viable development path.
- Extend existing TeamAI duties/anchors/passer memory and CareerState/Schedule/SaveManager. Avoid a second
  coordinator, parallel simulation or copied league/transfer logic. Add focused helpers only with clear ownership.
- All speculative paths in PLAYER_CAREER_SPEC/map are proposed, not existing files or completed features.
  Implement real behaviour and tests before enabling menu actions. Keep unfinished surfaces honestly disabled.
- Career tuning is data-driven. Normal starts develop over seasons; one season/reload/drill loop cannot turn
  a young prospect into a 90-rated player. Actual ability gains must influence shared physical execution.
- No request should weaken defenders, hardcode successful diagnostics, alter seed lists to inflate scores,
  suppress errors or present a duty flag as a successful attacking combination. Observe computed candidates;
  never rerun the planner for logging and change RNG. Distinguish legacy and stricter new predicates.

## Checks and evidence

Use Godot 4.5.1; check the binary version rather than assuming the PATH binary is correct.
The historical baseline is 300 core checks (two old tautologies), 67/72 legacy episodes, 123/144 extended
known episodes, five failing review regressions, and 11/37 strict audit subprocess cases passing.
These are not new successes, and different denominators cannot be added together. Full details are in
DEEP_AUDIT_2026-11-14.md; inspect only relevant cases until a final cross-system gate is needed.

Existing commands from the project root:

```bash
godot --version
godot --headless --import
godot --headless -s tests/run_tests.gd
godot --headless -s tools/review_regressions.gd
python3 tools/run_deep_audit.py --godot godot --out /tmp/openpitch-audit
godot --headless -s tools/run_scenarios.gd
godot --headless -s tools/run_scenarios.gd -- --seeds=44,55,66,77,88,99
godot --headless -s tools/run_match.gd -- --seeds=1,2,3,4,5,6,7,8 --duration=360
godot --headless -s tools/fuzz_human.gd -- --seeds=4,5,6,7,8,9,10,11,12,13,14,15 --duration=30
godot --headless -s tools/career_journey.gd -- --played=3 --duration=60
```

Select targeted review/edge cases with their documented `--case=NAME`. Until QA01, scenario/screenshot
exit codes are unreliable; require completed verdicts and real artifacts. The strict Python audit also
rejects script errors/absent completion markers. Keep expected unresolved failures visible by ID.
Future player-career tests/journey named in the spec must be created and validated during PC tasks; they
are not runnable baseline commands. Never report future test counts as passed.

After meaningful tactical changes use the original/extended matrices plus newly reserved seeds and
arrangements, selected traces and comparable full matches. Preserve shot quality, recovery and input response;
heuristic xG and pass accuracy alone do not prove good football. Run new career controls incrementally and
finish with multi-season/migration/loan/national journeys. Avoid duplicate long reruns without a new concern.
Use matched actual screenshots/motion; software MovieMaker rate is not hardware FPS. A Windows export is
not Windows execution. Refer to PLAYTEST.md for human checks, including player-locked play.

## Checkpoint and final delivery

Keep the top Active handoff in PROGRESS.md short (roughly 40 lines): branch and implementation revision,
active/next task, acceptance completed/open, changed files, exact commands with real exit/results, evidence
paths, unresolved failures and **one concrete next action**. Before a context stop, preserve a focused commit
or clearly labelled WIP plus exact dirty files; do not mark unverified WIP DONE or discard another person's work.
Use the existing checkpoint fields; archive expanded narrative below the current block instead of growing
another progress file. Update map paths after real ownership changes, not to pretend planned modules exist.

Colleague communication uses committed repository records. At handoff state what changed and why, exact
tested revision, task acceptance still open, evidence and failed approaches worth avoiding. Separate implemented,
self-tested, independently reviewed and human-unverified claims. Read the delta since the last reviewed SHA
and affected callers, then expand context only as needed; a summary never replaces inspecting changed code.
Do not claim a live connection or automatic notification to the other agent. Quality and enjoyable human
gameplay outrank throughput; keep large art/Blender work deferred until gameplay review supports it.

Publish coherent increments on the accessible working branch. If permission/network blocks publishing,
preserve commits/patch/bundle and give exact restoration steps; report the real blocker. Do not merge the
default branch without a request. Do not claim an automatic next session has been scheduled.
Final Russian delivery states actual completed IDs/features, checks, open tasks, branch/build links and
Windows/human limitations. A partial session is a checkpoint; it does not complete the approved full scope.
