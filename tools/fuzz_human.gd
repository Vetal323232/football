extends SceneTree
## Robustness check: a full match where the "human" side is driven by seeded
## pseudo-random keyboard-like input (move, sprint, pass, through, lob, shot,
## tackle, switch). Verifies the engine survives arbitrary input without
## deadlocks and that exactly one player is human-controlled at all times.
## Usage: godot --headless -s tools/fuzz_human.gd -- [--seeds=1,2] [--duration=120]


func _init() -> void:
	var seeds := [1, 2, 3]
	var duration := 120.0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--seeds="):
			seeds = []
			for s in a.trim_prefix("--seeds=").split(","):
				seeds.append(int(s))
		elif a.begins_with("--duration="): duration = float(a.trim_prefix("--duration="))
	var tuning: GameTuning = load("res://data/tuning/default_tuning.tres")
	var ok := true
	for sd: int in seeds:
		var setup := MatchSetup.exhibition(sd)
		setup.human_team = sd % 2
		setup.duration = duration
		var sim := MatchSim.new()
		var report := MatchReport.new()
		report.attach(sim)
		sim.init_match(setup, tuning)
		var rng := RandomNumberGenerator.new()
		rng.seed = sd * 977
		var f := sim.human.input
		var bad_humans := 0
		var switches := [0]
		sim.event.connect(func(kind: StringName, _d: Dictionary) -> void:
			if kind == &"control":
				switches[0] += 1)
		var hold := 0
		var guard := 0
		while sim.state != MatchSim.State.FULL_TIME and guard < 400000:
			guard += 1
			if hold <= 0:
				hold = rng.randi_range(5, 50)
				f.move = Vector2.from_angle(rng.randf() * TAU) * (1.0 if rng.randf() < 0.85 else 0.0)
				# Bias toward attacking the right goal for our side so shots happen.
				if rng.randf() < 0.5:
					f.move = Vector2(sim.teams[setup.human_team].dir, rng.randf_range(-0.6, 0.6)).normalized()
				f.sprint = rng.randf() < 0.4
				f.shot_held = rng.randf() < 0.12
			hold -= 1
			var r := rng.randf()
			if r < 0.012: f.pass_pressed = true
			elif r < 0.017: f.through_pressed = true
			elif r < 0.021: f.lob_pressed = true
			elif r < 0.03: f.tackle_pressed = true
			elif r < 0.036: f.switch_pressed = true
			if f.shot_held and rng.randf() < 0.05:
				f.shot_held = false
				f.shot_released = true
			sim.step()
			report.sample()
			var humans := 0
			for p in sim.players:
				if p.is_human:
					humans += 1
			if humans != 1:
				bad_humans += 1
		var st := sim.teams[setup.human_team].stats
		print("seed %d (human = team %d): %d-%d | human side: passes %d/%d, shots %d, tackles %d/%d | control changes %d | ticks with !=1 human %d | stalls %d | max restart wait %.1fs | finished %s" % [
			sd, setup.human_team, sim.teams[0].score, sim.teams[1].score, st.passes_completed, st.passes, st.shots, st.tackles_won, st.tackles, switches[0], bad_humans, sim.stalls, report.max_restart_wait, str(sim.state == MatchSim.State.FULL_TIME)])
		var finished := sim.state == MatchSim.State.FULL_TIME
		var stalls := sim.stalls
		report.detach()
		sim.dispose()
		if bad_humans > 0 or stalls > 0 or not finished or report.max_restart_wait > tuning.restart_force_time_human + 1.0:
			ok = false
	print("FUZZ %s" % ("OK" if ok else "FAILED"))
	quit(0 if ok else 1)
