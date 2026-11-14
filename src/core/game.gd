extends Node
## Global app state: settings, input bindings, scene flow and the pending match.

const SETTINGS_PATH := "user://settings.json"
const SCENE_MENU := "res://scenes/main_menu.tscn"
const SCENE_MATCH := "res://scenes/match.tscn"
const SCENE_CAREER := "res://scenes/career_hub.tscn"
const SCENE_DIAG := "res://scenes/diagnostic.tscn"

var settings := {
	"master_volume": 0.8,
	"sfx_volume": 0.9,
	"crowd_volume": 0.6,
	"fullscreen": false,
	"vsync": true,
	"shadows": true,
	"match_minutes": 6,
	"difficulty": 1,
}

var tuning: GameTuning
var pending_setup: MatchSetup = null
var last_result := {}            ## filled by the match scene when a match ends
var career = null                ## CareerState while a career is loaded
var return_scene := SCENE_MENU
var cli := {}                    ## parsed "--key=value" user arguments


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	tuning = load("res://data/tuning/default_tuning.tres")
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--"):
			var kv := a.trim_prefix("--").split("=", true, 1)
			cli[kv[0]] = kv[1] if kv.size() > 1 else "1"
	_register_input()
	load_settings()
	apply_settings()
	TranslationServer.set_locale("ru")
	if cli.has("screenshot"):
		_screenshot_later.call_deferred()


func _register_input() -> void:
	# Physical key codes: the layout position matters, not the printed letter,
	# so WASD works on a Russian keyboard layout too.
	var binds := {
		"move_left": [KEY_A, KEY_LEFT], "move_right": [KEY_D, KEY_RIGHT],
		"move_up": [KEY_W, KEY_UP], "move_down": [KEY_S, KEY_DOWN],
		"sprint": [KEY_SHIFT], "pass": [KEY_J], "shoot": [KEY_K], "through": [KEY_L],
		"lob": [KEY_I], "switch_player": [KEY_E], "tackle": [KEY_Q],
		"pause": [KEY_ESCAPE], "debug_ai": [KEY_F3], "help": [KEY_F1],
		"debug_select": [KEY_TAB], "debug_speed": [KEY_F4],
	}
	for action: String in binds:
		if not InputMap.has_action(action):
			InputMap.add_action(action, 0.3)
		for code: int in binds[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = code as Key
			InputMap.action_add_event(action, ev)


func load_settings() -> void:
	if not FileAccess.file_exists(SETTINGS_PATH):
		return
	var f := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	if f == null:
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if parsed is Dictionary:
		for k: String in settings:
			if (parsed as Dictionary).has(k) and typeof(parsed[k]) == typeof(settings[k]) or ((parsed as Dictionary).has(k) and parsed[k] is float and settings[k] is int):
				settings[k] = int(parsed[k]) if settings[k] is int else parsed[k]


func save_settings() -> void:
	var f := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(settings, "  "))


func apply_settings() -> void:
	if DisplayServer.get_name() != "headless":
		var want := DisplayServer.WINDOW_MODE_FULLSCREEN if settings["fullscreen"] else DisplayServer.WINDOW_MODE_WINDOWED
		if DisplayServer.window_get_mode() != want and not cli.has("screenshot"):
			DisplayServer.window_set_mode(want)
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if settings["vsync"] else DisplayServer.VSYNC_DISABLED)
	AudioServer.set_bus_volume_db(0, linear_to_db(clampf(float(settings["master_volume"]), 0.0001, 1.0)))
	Sfx.apply_volumes()


func goto(scene: String) -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file.call_deferred(scene)


func start_match(setup: MatchSetup, back_to: String) -> void:
	pending_setup = setup
	return_scene = back_to
	last_result = {}
	goto(SCENE_MATCH)


func quick_setup(human_team: int, seed_: int = -1) -> MatchSetup:
	var sd := seed_ if seed_ >= 0 else int(Time.get_unix_time_from_system()) % 1000000
	var s := MatchSetup.exhibition(sd)
	s.human_team = human_team
	s.difficulty = int(settings["difficulty"])
	s.duration = float(settings["match_minutes"]) * 60.0
	return s


# --- tooling: "-- --screenshot=out.png --after=3.0" captures the window and quits.
func _screenshot_later() -> void:
	var after := float(cli.get("after", "2.0"))
	await get_tree().create_timer(after, true, false, true).timeout
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(str(cli["screenshot"]))
	print("screenshot saved: ", cli["screenshot"], " fps=", Engine.get_frames_per_second())
	get_tree().quit()
