# Immutable extended-audit evidence

Gameplay source: a47746eba365d3a3a1ffc6693069dc2cab484505. Godot 4.5.1 stable, Linux x86-64, 2026-11-14.
The review parent is 8283045. Audit tools/docs are added on top; gameplay/tuning are unchanged.
These are baseline failures, not fixed results. Never overwrite these historical logs with a later run.

| Files | Evidence |
| --- | --- |
| import.log, core_tests.log | Fresh import and 300 original checks (two historical tautologies remain). |
| scenario_holdouts.log | 8 scenarios × 3 variants × seeds 44,55,66,77,88,99: 123/144, exit 0 despite failures. |
| fuzz_holdouts.log | Seeds 4–15, full accelerated 30-second matches: 12/12 FUZZ OK. |
| strong_home.log, strong_away.log | Seeds 11,22,33,44,55,66; 180 s; 84/62 and 62/84. Stronger side totals 9W/3D, 13:0. |
| extended_runner.log, extended/summary.json | Strict audit wrapper, 37 subprocess cases, 11 pass, exit 1. |
| extended/save_*.log | One valid control + 29 mutations. 9/30 checks pass; 8 invalid cases generate script errors. |
| extended/edge_*.log | Paired determinism/finite state, normal career stress and desired-behaviour edge regressions. |
| review_regressions.log | Original five targeted regressions: 5/5 fail, expected exit 1. |
| invalid_edge_case.log, invalid_save_case.log | Unknown selections rejected with exit 2, rather than zero executed checks being treated as success. |
| handoff_probe.log | Production human_support seeds 11,44,55; seed 44 passes to #9 then controls #7. Permanent regression is deep_audit --case=pass_handoff. |
| render_*.log | Real GL scene capture/movie process output. Mesa llvmpipe; fixed-frame movie rate is not hardware FPS. |
| match.png, diagnostic.png, lineup.png, transfers.png | Four of seven actual 1280×720 captures, preserved for visual comparisons. |

The handoff trace was an exploratory external script; its reproducible behavioural replacement is versioned
in tools/deep_audit.gd. Other recorded commands are reproduced in DEEP_AUDIT_2026-11-14.md and the master prompt.
Absolute workspace paths in historical engine backtraces are incidental; use the repository-relative scripts.

Eight deterministic groups compare 600 paired ticks each (four AI-only, four human-input). Eight career groups
complete three seasons each: 336 rounds, 1,344 fixtures, 672 transfers. These are grouped checks, not 37 equally
sized assertions. ObjectDB/resource warnings are retained; MEM01 remains open. A runtime error plus exit zero
still fails the strict wrapper. See the audit for false-alarm analysis of JSON fractional rounding.

No Windows runtime, human playtest, real GPU benchmark or complete audio review is evidenced here.
`manifest.json` records evidence SHA-256 digests and the exact audit-tool Git blob hashes.
