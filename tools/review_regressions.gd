extends SceneTree
## Targeted regressions from the 2026-11-14 code review.
## Assertions describe desired behaviour. On baseline a47746e all five cases FAIL.
## Usage: godot --headless -s tools/review_regressions.gd -- [--case=NAME]
## Case names: offside_first_touch, run_trigger, forward_pass, lifetime, save_integrity.

const CASES: Array[String] = [
	"offside_first_touch", "run_trigger", "forward_pass", "lifetime", "save_integrity",
]
var checks := 0
var failed := 0
var tuning: GameTuning


func _init() -> void:
	call_deferred("_run_checks")


func _run_checks() -> void:
	tuning = load("res://data/tuning/default_tuning.tres")
	var selected := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--case="):
			selected = arg.trim_prefix("--case=")
	if selected != "" and not CASES.has(selected):
		printerr("Unknown review case: ", selected)
		quit(2)
		return
	for name in CASES:
		if selected == "" or selected == name:
			call("_check_" + name)
	print("REVIEW REGRESSIONS: %d checks, %d failed" % [checks, failed])
	quit(1 if failed > 0 else 0)


func _check(ok: bool, name: String, details: String) -> void:
	checks += 1
	if not ok:
		failed += 1
	print("%s %s | %s" % ["PASS" if ok else "FAIL", name, details])


func _dispose_if_supported(sim: MatchSim) -> void:
	# Supports either weak back-references or a future explicit teardown API.
	if sim.has_method("dispose"):
		sim.call("dispose")


func _check_offside_first_touch() -> void:
	var sim := MatchSim.new()
	sim.init_match(MatchSetup.exhibition(27), tuning)
	sim.state = MatchSim.State.PLAYING
	sim.ball.dead = false
	sim.freeze_clock = true
	var passer: SimPlayer = sim.players[6]
	var runner: SimPlayer = sim.players[9]
	for p in sim.players:
		p.pos = Vector2(-30, -25) if p.team == 0 else Vector2(20, 20)
		p.vel = Vector2.ZERO
	sim.players[11].pos = Vector2(51, 0)
	passer.pos = Vector2.ZERO
	runner.pos = Vector2(35, 0)
	sim.ball.pos = Vector2(0.5, 0)
	sim.ball.owner = passer.id
	sim.poss_team = 0
	passer.pending_kick = KickRequest.make(KickRequest.Kind.PASS, Vector2.RIGHT, 24, 0, runner.id, runner.pos)
	passer.pending_kick_t = 0.4
	sim._try_kick(passer)
	var flagged := sim.offside_flags.has(runner.id)
	# Arrange contact with the in-flight ball without erasing its kick history.
	sim.ball.pos = runner.pos + Vector2(0.3, 0)
	runner.pending_kick = KickPlanner.plan_ai_shot(sim, runner)
	runner.pending_kick_t = 0.4
	sim._try_kick(runner)
	var ok := flagged and sim.state == MatchSim.State.RESTART_SETUP \
		and sim.restart_type == MatchSim.Restart.FREE_KICK and sim.restart_team == 1 \
		and sim.teams[0].stats.offsides == 1 and sim.teams[0].stats.shots == 0
	_check(ok, "offside_first_touch", "initially_flagged=%s state=%s offsides=%d shots=%d" % [
		flagged, MatchSim.State.keys()[sim.state], sim.teams[0].stats.offsides, sim.teams[0].stats.shots])
	_dispose_if_supported(sim)


func _check_run_trigger() -> void:
	var sim := MatchSim.new()
	sim.init_match(ScenarioLib.make_setup("attack_3v2", 0, 11), tuning)
	ScenarioLib.apply(sim, "attack_3v2", 0)
	sim.tick = 300
	var ai: TeamAI = sim.teams[0].ai
	ai.now = 5.0
	ai._replan()
	var carrier: SimPlayer = sim.players[9]
	carrier.has_ball_time = 2.0
	var agent: AIAgent = ai.agents[carrier.id]
	agent.next_decision = 5.15
	agent.commit_until = 5.4
	agent.move_dir = Vector2.UP
	agent.move_sprint = false
	agent.options.clear()
	ai.run_started_tick = 312
	var pressure_eta := SimQuery.opp_arrival(sim, sim.ball.pos, 1, 0.0)
	OnBallAI.drive(ai, carrier, agent)
	var ok := pressure_eta > 0.4 and carrier.cmd.kick == null \
		and carrier.cmd.move.is_equal_approx(Vector2.UP) and is_equal_approx(agent.next_decision, 5.15)
	_check(ok, "run_trigger", "now_tick=300 future_event=312 pressure_eta=%.2f command=%s kick=%s" % [
		pressure_eta, carrier.cmd.move, carrier.cmd.kick != null])
	_dispose_if_supported(sim)


func _check_forward_pass() -> void:
	var setup := MatchSetup.exhibition(9)
	setup.human_team = 0
	var sim := MatchSim.new()
	sim.init_match(setup, tuning)
	sim.state = MatchSim.State.PLAYING
	var passer: SimPlayer = sim.players[9]
	passer.pos = Vector2.ZERO
	passer.facing = Vector2.RIGHT
	sim.ball.pos = Vector2(0.5, 0)
	sim.ball.owner = passer.id
	for id in sim.teams[0].player_ids:
		if id != passer.id:
			sim.players[id].pos = Vector2(-35, -25)
	sim.players[10].pos = Vector2(-1, 10)
	for id in sim.teams[1].player_ids:
		sim.players[id].pos = Vector2(40, 30)
	sim.human.input.move = Vector2.RIGHT
	var req := sim.human.assist_pass(passer, KickRequest.Kind.PASS)
	var ok := req.receiver == -1 and req.dir.dot(Vector2.RIGHT) >= 0.0
	_check(ok, "forward_pass", "receiver=%d target=%s direction=%s" % [req.receiver, req.target, req.dir])
	_dispose_if_supported(sim)


func _check_lifetime() -> void:
	var refs: Array[WeakRef] = []
	for i in 12:
		var setup := MatchSetup.exhibition(100 + i)
		setup.human_team = 0 if i % 2 == 0 else -1
		var sim := MatchSim.new()
		sim.init_match(setup, tuning)
		refs.append(weakref(sim))
		_dispose_if_supported(sim)
		sim = null
	var retained := 0
	for ref in refs:
		if ref.get_ref() != null:
			retained += 1
	_check(retained == 0, "lifetime", "released_match_sims_still_alive=%d/12" % retained)


func _check_save_integrity() -> void:
	var cs := CareerState.create("smk", 2024)
	var broken: Dictionary = cs.data.duplicate(true)
	broken["round"] = 999
	var errors := CareerState.validate(broken)
	var directory := "user://review_regression_saves"
	SaveManager.delete(directory)
	var write_error := SaveManager.save(cs, directory)
	if write_error == "":
		write_error = SaveManager.save(cs, directory)
	var file := FileAccess.open(SaveManager.path(directory), FileAccess.WRITE)
	if file == null or write_error != "":
		_check(false, "save_integrity", "probe setup could not create isolated saves")
		SaveManager.delete(directory)
		return
	file.store_string(JSON.stringify(broken))
	file.close()
	var result := SaveManager.load_career(directory)
	var loaded: CareerState = result.get("career")
	var loaded_round := int(loaded.data["round"]) if loaded != null else -1
	var ok := not errors.is_empty() and bool(result["recovered"]) and loaded != null and loaded_round == 0
	_check(ok, "save_integrity", "validation_errors=%d recovered=%s loaded_round=%d" % [
		errors.size(), result["recovered"], loaded_round])
	SaveManager.delete(directory)
