# Open Pitch

Offline 3D association football for Windows: 11v11 matches against AI with keyboard control and a
club career (one league of eight original fictional clubs). Built with **Godot 4.5.1** and GDScript.
No backend, no network access at runtime, zero-budget original assets.

Version 0.1.0 — see `PROGRESS.md` for the honest status and known defects.

## Install and run

1. Download **Godot 4.5.1-stable (standard, not .NET)** for Windows from <https://godotengine.org/download/archive/4.5.1-stable/>.
2. Unpack it, start `Godot_v4.5.1-stable_win64.exe`, choose **Import**, select this folder's `project.godot`.
3. Press **F5** (Run Project).

From a terminal (same on Windows / Linux, adjust the executable name):

```
Godot_v4.5.1-stable_win64.exe --path . --import        # first time: imports the project
Godot_v4.5.1-stable_win64.exe --path .                 # run the game
```

The renderer is `gl_compatibility` (OpenGL 3.3), chosen so the game runs on modest and integrated GPUs.

## Controls

| Key | Action |
| --- | --- |
| WASD / arrows | Move (relative to the camera) |
| Shift | Sprint (uses stamina) |
| J | Short pass (aim with the direction keys) |
| K (hold, release) | Shot — longer hold = harder and higher |
| L | Through ball |
| I | Lofted pass / cross |
| E | Switch player (press again to cycle) |
| Q | Tackle (needs reach and timing; a miss costs recovery time) |
| Esc | Pause / back |
| F1 | Controls help |
| F3 | AI diagnostics overlay (Tab: select player; F4: speed in AI-vs-AI) |

Menus: arrows / W S to move, Left / Right to change a value, Enter to confirm, Esc to go back.
Bindings use physical key positions, so they work with a Russian keyboard layout.

## Modes

- **Быстрый матч** — pick two clubs, your side, difficulty and length.
- **Карьера** — choose a club, set the line-up, play or simulate your fixture, other fixtures are
  simulated, table, calendar, transfers (buy / sell), player development, seasons, autosave.
- **Смотреть матч ИИ** — AI vs AI with the same engine.
- **Диагностика ИИ** — eight reproducible AI scenarios with the F3 overlay and a verdict.

Saves and settings live in Godot's user folder (`%APPDATA%\Godot\app_userdata\Open Pitch\` on Windows):
`saves/career.json` (+ `.bak` backup of the previous save) and `settings.json`.

## Checks

```
godot --headless --import                              # 1. import / parser check
godot --headless -s tests/run_tests.gd                 # 2. logic + match-engine checks (exit code 1 on failure)
godot --headless -s tools/run_scenarios.gd             # 2. AI validation scenarios
godot --headless -s tools/run_match.gd -- --seeds=1,2,3,4 --duration=360
godot --headless -s tools/fuzz_human.gd
godot --headless -s tools/career_journey.gd
```

Visual checks (3): run the game, or on Linux without a display `tools/shot.sh <scene> <out.png> [args]`.
Useful game arguments after `--`: `--autoplay`, `--seed=N`, `--speed=N`, `--duration=SEC`, `--debug`,
`--scenario=NAME --variant=0..2`, `--perf` (prints frame-time statistics after 600 frames and quits).

Manual playtest script: `docs/PLAYTEST.md`.

## Windows export

1. In the editor: *Editor → Manage Export Templates → Download and Install* (4.5.1).
2. `Godot_v4.5.1-stable_win64.exe --headless --path . --export-release "Windows Desktop" build/windows/OpenPitch.exe`

The preset (`export_presets.cfg`) embeds the data pack, so the result is a single `OpenPitch.exe`.

## Repository map

```
project.godot, export_presets.cfg
scenes/        main_menu, match, career_hub, diagnostic
src/sim/       deterministic match simulation (ball, players, rules, restarts, offside)
src/ai/        team coordinator, on-ball decisions, goalkeeper, pass/kick planning, scenarios, metrics
src/input/     human controller + pass assistance
src/view/      3D presentation (pitch, player rig, ball, camera, F3 overlay)
src/ui/        HUD, menus, career screens
src/career/    league data, schedule, career state, save manager
src/core/      autoloads: Game (settings, input map, scene flow), Sfx (synthesised audio)
data/          tuning resource, league definition
locale/        UI strings (ru, en)
tests/, tools/ automated checks and headless tools
docs/          BRIEF, DESIGN, AI_VALIDATION, PLAYTEST, project map, review and work plan
```

## Development navigation

- [Project map](docs/PROJECT_MAP.md): files, ownership and football decision paths.
- [Reproduced code review](docs/CODE_REVIEW_2026-11-14.md): evidence, confirmed defects and verification limits.
- [Ordered work plan](docs/AI_WORK_PLAN.md): exact tasks, reproductions, dependencies and acceptance criteria.
