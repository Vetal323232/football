# Assets and licenses

Open Pitch 0.1 ships **no third-party art, audio, fonts or data**. Everything is original and generated
from code at runtime, so there is nothing to download and no attribution requirement.

| Asset | Source | Author | License |
| --- | --- | --- | --- |
| Player models and animation | Built from Godot primitive meshes in `src/view/player_rig.gd`, animated procedurally | this project | project license |
| Pitch, markings, goals, nets, stadium, crowd, boards | Procedural meshes and shaders in `src/view/pitch_view.gd` | this project | project license |
| Ball | Procedural sphere + shader in `src/view/ball_view.gd` | this project | project license |
| Sound effects (kick, pass, bounce, post, whistle, tackle, crowd, cheer, UI) | Synthesised at startup in `src/core/sfx.gd` (sine/noise with envelopes) | this project | project license |
| UI font | Godot's built-in default project font (Open Sans, bundled with the engine) | Steve Matteson / Google | SIL Open Font License 1.1 (as distributed with Godot) |
| Club names, player names, league | Invented for this project (`data/league.json`); names are random combinations of common given names and invented surnames | this project | project license |

Engine: Godot Engine 4.5.1-stable, MIT license, <https://godotengine.org/license>. The exported game must
keep Godot's license notice available (it is included in the engine binary's third-party notices).

No real clubs, players, competitions, logos or kits are used.
