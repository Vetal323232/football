extends SceneTree
## Reproducible extended audit. Expectations describe desired behaviour.
## Run through run_deep_audit.py: GDScript runtime errors can otherwise exit 0.
## Does not modify gameplay. All save files use an isolated audit directory.

const CASES := ["determinism", "career_stress", "substitution_state", "backpass_feet", "pause_shot", "pass_handoff", "keeper_only_lineup"]
var failed := 0
var checks := 0
var tuning: GameTuning


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	tuning = load("res://data/tuning/default_tuning.tres")
	var selected := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--case="):
			selected = arg.trim_prefix("--case=")
	if selected != "" and not CASES.has(selected):
		printerr("Unknown audit case: ", selected)
		quit(2)
		return
	for name: String in CASES:
		if selected == "" or selected == name:
			call("_" + name)
	print("DEEP_AUDIT_DONE checks=%d failed=%d" % [checks, failed])
	quit(1 if failed else 0)


func _check(ok: bool, name: String, detail: String) -> void:
	checks += 1
	if not ok:
		failed += 1
	print("%s %s | %s" % ["PASS" if ok else "FAIL", name, detail])


func _release(sim: MatchSim) -> void:
	if sim.has_method("dispose"):
		sim.call("dispose")


func _snapshot(sim: MatchSim) -> Array:
	var a := [sim.tick, sim.time, sim.state, sim.state_t, sim.half, sim.rng.state,
		sim.ball.pos, sim.ball.vel, sim.ball.h, sim.ball.vh, sim.ball.owner, sim.ball.held_by,
		sim.ball.kicker, sim.ball.kick_tick, sim.poss_team, sim.restart_type, sim.restart_team,
		sim.teams[0].score, sim.teams[1].score, sim.teams[0].stats.shots, sim.teams[1].stats.shots]
	for p in sim.players:
		a.append([p.pos, p.vel, p.facing, p.stamina, p.kick_lock, p.stun, p.tackle_t, p.dive_t,
			p.pending_kick_t, p.has_ball_time, p.cmd.move, p.cmd.sprint])
	for tm in sim.teams:
		for id in tm.player_ids:
			var ag: AIAgent = tm.ai.agents[id]
			a.append([ag.duty, ag.next_decision, ag.commit_until, ag.run_state])
	if sim.human != null:
		a.append([sim.human.controlled, sim.human.charging, sim.human.shot_charge])
	return a


func _valid_state(sim: MatchSim) -> bool:
	if not sim.ball.pos.is_finite() or not sim.ball.vel.is_finite() or not is_finite(sim.ball.h) or not is_finite(sim.ball.vh):
		return false
	if sim.ball.owner < -1 or sim.ball.owner >= 22 or sim.ball.held_by < -1 or sim.ball.held_by >= 22:
		return false
	if sim.ball.owner >= 0 and sim.ball.held_by >= 0:
		return false
	for p in sim.players:
		if not p.pos.is_finite() or not p.vel.is_finite() or not p.facing.is_finite() or not is_finite(p.stamina) or p.stamina < 0.0 or p.stamina > 1.0:
			return false
	return true


func _script_input(sim: MatchSim, tick_: int, seed_: int) -> void:
	if sim.human == null:
		return
	var f := sim.human.input
	f.move = Vector2.from_angle(float((tick_ / 25 + seed_) % 8) * PI / 4.0)
	f.sprint = tick_ % 160 < 90
	f.pass_pressed = tick_ % 197 == 50
	f.through_pressed = tick_ % 233 == 90
	f.lob_pressed = tick_ % 277 == 120
	f.shot_held = tick_ % 100 < 15
	f.tackle_pressed = tick_ % 89 == 40
	f.switch_pressed = tick_ % 173 == 70


func _determinism() -> void:
	for seed_ in [101, 202, 303, 404, 505, 606, 707, 808]:
		var a := MatchSim.new()
		var b := MatchSim.new()
		var sa := MatchSetup.exhibition(seed_)
		var sb := MatchSetup.exhibition(seed_)
		sa.human_team = 0 if seed_ % 2 == 0 else -1
		sb.human_team = sa.human_team
		a.init_match(sa, tuning)
		b.init_match(sb, tuning)
		var same := true
		var compared := 0
		for tick_ in 600:
			_script_input(a, tick_, seed_)
			_script_input(b, tick_, seed_)
			a.step()
			b.step()
			compared += 1
			if _snapshot(a) != _snapshot(b) or not _valid_state(a) or not _valid_state(b):
				same = false
				break
		_check(same, "determinism/%d" % seed_, "paired ticks=%d human_team=%d (state, RNG, physics, AI/input timers, finite values)" % [compared, sa.human_team])
		_release(a)
		_release(b)


func _budget(cs: CareerState) -> int:
	var total := 0
	for cid: String in cs.data["clubs"]:
		total += int(cs.club(cid)["budget"])
	return total


func _same_json(a: Variant, b: Variant) -> bool:
	# Godot's default JSON formatting rounds fractional growth. Integer fields,
	# container shape, IDs and all other values must remain exact.
	if a is Dictionary and b is Dictionary:
		if a.size() != b.size():
			return false
		for k: Variant in a:
			if not b.has(k) or not _same_json(a[k], b[k]):
				return false
		return true
	if a is Array and b is Array:
		if a.size() != b.size():
			return false
		for i in a.size():
			if not _same_json(a[i], b[i]):
				return false
		return true
	if a is float and b is float:
		return absf(a - b) <= 0.00001
	return a == b


func _career_errors(cs: CareerState) -> Array:
	var errors := CareerState.validate(cs.data)
	var owners := {}
	for cid: String in cs.data["clubs"]:
		var c := cs.club(cid)
		if (c["squad"] as Array).size() < CareerState.MIN_SQUAD or (c["squad"] as Array).size() > CareerState.MAX_SQUAD:
			errors.append("squad bounds " + cid)
		if cs.lineup_valid(cid, c["lineup"]) != "":
			errors.append("lineup " + cid)
		for pid: String in c["squad"]:
			if owners.has(pid):
				errors.append("duplicate ownership " + pid)
			owners[pid] = cid
			for k: String in Attr.KEYS:
				if not cs.player(pid)["attrs"].has(k) or int(cs.player(pid)["attrs"][k]) < 1 or int(cs.player(pid)["attrs"][k]) > 99:
					errors.append("attribute range " + pid)
	if owners.size() != 160:
		errors.append("player conservation")
	var gf := 0
	var ga := 0
	var played := 0
	for row: Dictionary in cs.standings():
		gf += int(row["gf"])
		ga += int(row["ga"])
		played += int(row["p"])
		if int(row["p"]) != int(row["w"]) + int(row["d"]) + int(row["l"]) or int(row["pts"]) != int(row["w"]) * 3 + int(row["d"]):
			errors.append("table arithmetic")
	var fixtures_played := 0
	for f: Dictionary in cs.data["fixtures"]:
		if f["played"]:
			fixtures_played += 1
	if gf != ga or played != fixtures_played * 2:
		errors.append("table conservation")
	return errors


func _career_stress() -> void:
	var dir := "user://deep_audit_career"
	for seed_ in [101, 202, 303, 404, 505, 606, 707, 808]:
		var cs := CareerState.create("smk", seed_)
		var errors := []
		var transactions := 0
		for season_ in 3:
			for round_ in CareerState.ROUNDS:
				var before := _budget(cs)
				for pid: String in (cs.data["transfer_list"] as Array).duplicate():
					if cs.buy(pid) == "":
						transactions += 1
						break
				for pid: String in (cs.user()["squad"] as Array).duplicate():
					if not (cs.user()["lineup"] as Array).has(pid) and cs.sell(pid) == "":
						transactions += 1
						break
				if before != _budget(cs):
					errors.append("transfer money conservation")
				if not cs.complete_round(true):
					errors.append("round advance")
				errors.append_array(_career_errors(cs))
			SaveManager.delete(dir)
			var save_error := SaveManager.save(cs, dir)
			var loaded: CareerState = SaveManager.load_career(dir).get("career")
			if save_error != "" or loaded == null or not _same_json(loaded.data, cs.data):
				errors.append("save roundtrip")
			if not cs.start_next_season():
				errors.append("season rollover")
			errors.append_array(_career_errors(cs))
		_check(errors.is_empty(), "career_stress/%d" % seed_, "3 seasons, 42 rounds, %d transfers, errors=%s" % [transactions, errors])
	SaveManager.delete(dir)


func _substitution_state() -> void:
	var cs := CareerState.create("smk", 2024)
	var sim := MatchSim.new()
	sim.init_match(cs.match_setup_for(cs.user_fixture(), 51), tuning)
	sim.state = MatchSim.State.PLAYING
	sim.ball.owner = -1
	sim.ball.held_by = -1
	var p: SimPlayer = sim.players[8]
	var old_uid := p.uid
	p.stun = 0.8
	p.tackle_cd = 1.2
	p.pending_kick = KickRequest.make(KickRequest.Kind.SHOT, Vector2.RIGHT, 20, 0, -1, Vector2(50, 0))
	p.pending_kick_t = 0.3
	p.distance_run = 4500.0
	var replaced := sim.substitute(0, p.id, 0)
	_check(replaced and p.uid != old_uid and p.stun == 0.0 and p.tackle_cd == 0.0 and p.pending_kick == null and p.distance_run == 0.0,
		"substitution_state", "sub=%s changed_uid=%s stun=%.2f cooldown=%.2f pending=%s distance=%.0f" % [replaced, old_uid != p.uid, p.stun, p.tackle_cd, p.pending_kick != null, p.distance_run])
	_release(sim)


func _backpass_feet() -> void:
	var sim := MatchSim.new()
	sim.init_match(MatchSetup.exhibition(51), tuning)
	sim.state = MatchSim.State.PLAYING
	sim.ball.dead = false
	var p: SimPlayer = sim.players[0]
	p.pos = Vector2(-48, 0)
	sim.ball.pos = p.pos
	sim.ball.kicker = 1
	sim.ball.backpass_team = 0
	var before := sim._may_handle(p)
	sim._give_possession(p, false)
	_check(not before and not sim._may_handle(p), "backpass_feet", "may_handle before=%s after_foot_control=%s backpass_team=%d" % [before, sim._may_handle(p), sim.ball.backpass_team])
	_release(sim)


func _pause_shot() -> void:
	var game = root.get_node("Game")
	game.pending_setup = MatchSetup.exhibition(51)
	game.pending_setup.human_team = 0
	var view = load("res://scenes/match.tscn").instantiate()
	root.add_child(view)
	view.set_physics_process(false)
	view.set_process(false)
	var sim: MatchSim = view.sim
	sim.state = MatchSim.State.PLAYING
	sim.ball.dead = false
	sim.ball.owner = 9
	sim.human._set_controlled(9)
	sim.ball.pos = sim.players[9].pos
	sim.human.charging = true
	sim.human.shot_charge = 0.75
	view.set_paused(true)
	Input.action_release("shoot")
	view.set_paused(false)
	view._sample_input()
	sim.players[9].cmd.clear()
	sim.human.update()
	_check(sim.players[9].cmd.kick == null, "pause_shot", "shot emitted immediately after resume=%s" % [sim.players[9].cmd.kick != null])
	view.free()


func _pass_handoff() -> void:
	for seed_ in [11, 44, 55]:
		var sim := MatchSim.new()
		sim.init_match(ScenarioLib.make_setup("human_support", 0, seed_), tuning)
		ScenarioLib.apply(sim, "human_support", 0)
		var obs := {}
		var receiver := -1
		var kick_tick := -1
		for i in 150:
			ScenarioLib.observe(sim, "human_support", obs)
			ScenarioLib.drive_inputs(sim, "human_support", obs)
			sim.step()
			ScenarioLib.post_step(sim, "human_support", obs)
			if sim.ball.kicker == int(obs.get("pass_from", -1)) and obs.has("pass_from") and sim.ball.kick_tick == sim.tick:
				receiver = sim.ball.kick_receiver
				kick_tick = sim.tick
				ScenarioLib.drive_inputs(sim, "human_support", obs)
				sim.step()
				break
		_check(receiver >= 0 and sim.human.controlled == receiver,
			"pass_handoff/%d" % seed_, "kick_tick=%d intended=%d controlled_next_tick=%d" % [kick_tick, receiver, sim.human.controlled])
		_release(sim)


func _keeper_only_lineup() -> void:
	# Adversarial roster robustness, not a demonstrated ordinary UI journey.
	var cs := CareerState.create("smk", 2024)
	var squad := []
	for pid: String in cs.data["players"]:
		if cs.player(pid)["pos"] == "GK":
			squad.append(cs.player(pid))
	var lineup := LeagueData.auto_lineup(squad)
	_check(lineup.size() == 11, "keeper_only_lineup", "16 real goalkeeper records, result size=%d; negative scores must still allow a best candidate" % lineup.size())
