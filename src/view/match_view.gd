extends Node3D
## Match scene root: owns the MatchSim, steps it at the fixed physics rate,
## feeds it sampled input and mirrors its state into visuals, audio and HUD.
## No gameplay logic lives here.

@onready var cam: Camera3D = $Camera
@onready var players_root: Node3D = $Players
@onready var ball_view: Node3D = $Ball
@onready var hud: CanvasLayer = $HUD
@onready var debug: Control = $DebugLayer/Debug
@onready var menus: CanvasLayer = $Menus
@onready var sun: DirectionalLight3D = $Sun

var sim: MatchSim
var rigs: Array[PlayerRig] = []
var paused := false
var finished := false
var speed := 1
var _edges := InputFrame.new()
var _celebrate_team := -1
var _frame_ms: Array[float] = []
var _scn_ticks := 0
var _scn_obs := {}
var _scn_done := false


func _ready() -> void:
	var setup := Game.pending_setup
	if setup == null:
		setup = Game.quick_setup(0)
	if Game.cli.has("autoplay"):
		setup.human_team = -1
	if Game.cli.has("seed"):
		setup.seed = int(Game.cli["seed"])
	if Game.cli.has("speed"):
		speed = int(Game.cli["speed"])
	sun.shadow_enabled = bool(Game.settings["shadows"])
	if Game.cli.has("scenario"):
		setup = ScenarioLib.make_setup(str(Game.cli["scenario"]), int(Game.cli.get("variant", "0")), int(Game.cli.get("seed", "11")))
		if Game.cli.has("autoplay"):
			setup.human_team = -1
	sim = MatchSim.new()
	sim.event.connect(_on_event)
	sim.init_match(setup, Game.tuning)
	if setup.scenario != "":
		ScenarioLib.apply(sim, setup.scenario, setup.variant)
		_scn_ticks = int(float(ScenarioLib.DURATION[setup.scenario]) * 60.0)
		debug.visible = true
		hud.call("show_banner", "%s\n%s %d, seed %d" % [ScenarioLib.TITLES[setup.scenario], tr("DIAG_VARIANT"), setup.variant + 1, setup.seed], 2.5)
	_build_rigs()
	hud.call("bind", sim)
	debug.set("sim", sim)
	debug.set("cam", cam)
	menus.call("bind", self)
	if Game.cli.has("warp"):
		var n := int(float(Game.cli["warp"]) * 60.0)
		for i in n:
			sim.step()
	for r in rigs:
		r.tick()
		r.tick()
	ball_view.call("snap", sim.ball)
	cam.call("snap_to", Vector3(sim.ball.pos.x, 0, sim.ball.pos.y))
	debug.visible = Game.cli.has("debug") or setup.scenario != ""
	Sfx.crowd(true)


func _exit_tree() -> void:
	Sfx.crowd(false)


func _build_rigs() -> void:
	var a := sim.teams[0]
	var b := sim.teams[1]
	var shirt := [a.kit, b.kit]
	var shorts := [a.kit2, b.kit2]
	var diff := Vector3(a.kit.r - b.kit.r, a.kit.g - b.kit.g, a.kit.b - b.kit.b).length()
	if diff < 0.45:
		shirt[1] = b.kit2
		shorts[1] = b.kit
		b.kit = shirt[1]
	for p in sim.players:
		var rig := PlayerRig.new()
		players_root.add_child(rig)
		if p.is_keeper():
			rig.setup(p, sim.teams[p.team].keeper_kit, Color(0.1, 0.1, 0.12), sim.teams[p.team].keeper_kit.darkened(0.2))
		else:
			rig.setup(p, shirt[p.team], shorts[p.team], shirt[p.team].darkened(0.15))
		rigs.append(rig)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_echo():
		return
	if event.is_action_pressed("pause"):
		if not finished:
			set_paused(not paused)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("debug_ai"):
		debug.visible = not debug.visible
	elif event.is_action_pressed("help"):
		hud.call("toggle_help")
	elif event.is_action_pressed("debug_select"):
		debug.call("cycle_selection")
	elif event.is_action_pressed("debug_speed") and sim.human == null:
		speed = 1 if speed >= 8 else speed * 2
	if paused or finished:
		return
	# Deliberate actions are edge-triggered: one press = one action.
	if event.is_action_pressed("pass"):
		_edges.pass_pressed = true
	elif event.is_action_pressed("through"):
		_edges.through_pressed = true
	elif event.is_action_pressed("lob"):
		_edges.lob_pressed = true
	elif event.is_action_pressed("tackle"):
		_edges.tackle_pressed = true
	elif event.is_action_pressed("switch_player"):
		_edges.switch_pressed = true
	elif event.is_action_released("shoot"):
		_edges.shot_released = true


func set_paused(p: bool) -> void:
	paused = p
	menus.call("show_pause", p)
	if p:
		_edges.clear_edges()


func _sample_input() -> void:
	var f: InputFrame = sim.human.input
	var ix := Input.get_axis("move_left", "move_right")
	var iy := Input.get_axis("move_down", "move_up")
	var right := cam.global_transform.basis.x
	var fwd := -cam.global_transform.basis.z
	right.y = 0.0
	fwd.y = 0.0
	var w := right.normalized() * ix + fwd.normalized() * iy
	f.move = Vector2(w.x, w.z).limit_length(1.0)
	f.sprint = Input.is_action_pressed("sprint")
	f.shot_held = Input.is_action_pressed("shoot")
	f.pass_pressed = _edges.pass_pressed
	f.through_pressed = _edges.through_pressed
	f.lob_pressed = _edges.lob_pressed
	f.tackle_pressed = _edges.tackle_pressed
	f.switch_pressed = _edges.switch_pressed
	f.shot_released = _edges.shot_released
	_edges.clear_edges()


func _physics_process(_delta: float) -> void:
	if paused or finished:
		return
	for i in speed:
		if sim.human != null:
			_sample_input()
		if _scn_ticks > 0 and not _scn_done:
			ScenarioLib.observe(sim, sim.setup.scenario, _scn_obs)
			if sim.setup.scenario == "shot_rebound" or (sim.setup.scenario == "human_support" and Game.cli.has("scripted")):
				ScenarioLib.drive_inputs(sim, sim.setup.scenario, _scn_obs)
			if int(_scn_obs.get("ticks", 0)) >= _scn_ticks:
				_scenario_finished()
		sim.step()
		for r in rigs:
			r.tick()
		ball_view.call("tick", sim.ball)
		if sim.state == MatchSim.State.FULL_TIME:
			_finish()
			break


func _process(delta: float) -> void:
	var frac := Engine.get_physics_interpolation_fraction() if not paused and not finished else 1.0
	if speed > 1:
		frac = 1.0
	var anim_dt := 0.0 if paused else delta * speed
	for r in rigs:
		r.holding_ball = sim.ball.held_by == r.player.id
		r.celebrate = _celebrate_team == r.player.team and sim.state == MatchSim.State.GOAL
		r.animate(anim_dt, frac)
	var bp: Vector3 = ball_view.call("animate", frac)
	var ctrl := Vector3.ZERO
	if sim.human != null and sim.human.controlled >= 0:
		var cp: SimPlayer = sim.players[sim.human.controlled]
		ctrl = Vector3(cp.pos.x, 0, cp.pos.y)
	cam.call("follow", bp, ctrl, delta)
	if Game.cli.has("perf"):
		_frame_ms.append(delta * 1000.0)
		if _frame_ms.size() == 600:
			_frame_ms.sort()
			print("PERF frames=600 avg=%.2fms median=%.2fms p95=%.2fms p99=%.2fms -> avg %.0f FPS" % [
				_avg(_frame_ms), _frame_ms[300], _frame_ms[570], _frame_ms[594], 1000.0 / _avg(_frame_ms)])
			get_tree().quit()


func _avg(a: Array[float]) -> float:
	var s := 0.0
	for v in a:
		s += v
	return s / maxf(1.0, a.size())


func _on_event(kind: StringName, data: Dictionary) -> void:
	match kind:
		&"kick":
			var k := int(data["kind"])
			var hard := k == KickRequest.Kind.SHOT or k == KickRequest.Kind.CLEAR or k == KickRequest.Kind.LOB
			Sfx.play("kick" if hard else "pass", clampf(float(data["speed"]) / 22.0, 0.4, 1.2), randf_range(0.92, 1.08))
		&"bounce":
			Sfx.play("bounce", clampf(float(data["speed"]) / 10.0, 0.2, 1.0))
		&"post":
			Sfx.play("post")
			Sfx.play("ooh")
		&"tackle":
			Sfx.play("tackle", 0.8)
		&"save":
			Sfx.play("ooh", 0.9)
			Sfx.play("bounce", 0.8, 0.8)
		&"whistle":
			var r := str(data.get("reason", ""))
			Sfx.play("whistle_long" if r == "half_time" or r == "full_time" else "whistle", 0.8)
		&"goal":
			Sfx.play("cheer", 1.0)
			_celebrate_team = int(data["team"])
			var sc := int(data["scorer"])
			var who := sim.players[sc].pname if sc >= 0 else ""
			var og := (" (%s)" % tr("OWN_GOAL")) if data["own_goal"] else ""
			hud.call("show_banner", "%s  %s\n%s%s  %d'" % [tr("GOAL"), sim.teams[int(data["team"])].tname, who, og, int(data["minute"])], 3.0)
		&"offside":
			hud.call("show_banner", tr("OFFSIDE"), 1.6)
		&"half_time":
			hud.call("show_banner", tr("HALF_TIME"), 2.5)
		&"restart":
			_celebrate_team = -1
			var t := int(data["type"])
			if t == MatchSim.Restart.KICKOFF and sim.tick < 5:
				Sfx.play("whistle", 0.8)
		&"restart_ready":
			if int(data["type"]) == MatchSim.Restart.KICKOFF:
				Sfx.play("whistle", 0.8)
		&"substitution":
			rigs[int(data["player"])].refresh_identity()


func _finish() -> void:
	finished = true
	hud.call("show_banner", tr("FULL_TIME"), 2.0)
	var stats := []
	for tm in sim.teams:
		var d := tm.stats.to_dict()
		d["name"] = tm.tname
		stats.append(d)
	var tot := float(maxi(1, sim.teams[0].stats.possession_ticks + sim.teams[1].stats.possession_ticks))
	stats[0]["possession"] = int(round(100.0 * sim.teams[0].stats.possession_ticks / tot))
	stats[1]["possession"] = 100 - int(stats[0]["possession"])
	Game.last_result = {
		"completed": true,
		"fixture_id": sim.setup.fixture_id,
		"goals": [sim.teams[0].score, sim.teams[1].score],
		"stats": stats,
		"participants": sim.participants.keys(),
		"human_team": sim.setup.human_team,
	}
	menus.call("show_result")


func _scenario_finished() -> void:
	_scn_done = true
	var v := ScenarioLib.judge(sim, sim.setup.scenario, sim.setup.variant, _scn_obs)
	var ok: bool = v["ok"] and (v["fail"] as PackedStringArray).is_empty()
	var text := "%s: %s\n%s" % [tr("DIAG_RESULT"), tr("DIAG_OK") if ok else tr("DIAG_FAIL"), "\n".join(v["notes"])]
	if not ok:
		text += "\n!! " + "; ".join(v["fail"])
	menus.call("show_scenario_result", text)
	paused = true


func next_scenario_run(delta_variant: int) -> void:
	var s := ScenarioLib.make_setup(sim.setup.scenario, posmod(sim.setup.variant + delta_variant, 3), sim.setup.seed + (1 if delta_variant == 0 else 0))
	Game.start_match(s, Game.return_scene)


func restart_match() -> void:
	var s := sim.setup
	s.seed += 1
	Game.start_match(s, Game.return_scene)


func leave_match() -> void:
	Game.goto(Game.return_scene)
