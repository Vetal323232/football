extends SceneTree
## Headless AI-vs-AI match runner.
## Usage: godot --headless -s tools/run_match.gd -- --seeds=1,2,3 [--duration=360] [--verbose]


func _init() -> void:
	var seeds := [1]
	var duration := 360.0
	var verbose := false
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--seeds="):
			seeds = []
			for s in a.trim_prefix("--seeds=").split(","):
				seeds.append(int(s))
		elif a.begins_with("--duration="):
			duration = float(a.trim_prefix("--duration="))
		elif a == "--verbose":
			verbose = true
	var tuning: GameTuning = load("res://data/tuning/default_tuning.tres")
	for sd: int in seeds:
		var setup := MatchSetup.exhibition(sd)
		setup.duration = duration
		var sim := MatchSim.new()
		var report := MatchReport.new()
		report.attach(sim, verbose)
		sim.init_match(setup, tuning)
		var t0 := Time.get_ticks_msec()
		var guard := 0
		while sim.state != MatchSim.State.FULL_TIME and guard < 400000:
			sim.step()
			report.sample()
			guard += 1
		var ms := Time.get_ticks_msec() - t0
		print("=== seed %d: %s %d-%d %s | ticks %d | %.1fs wall (%.0fx realtime)" % [sd, sim.teams[0].tname, sim.teams[0].score, sim.teams[1].score, sim.teams[1].tname, sim.tick, ms / 1000.0, sim.tick / 60.0 / maxf(ms / 1000.0, 0.001)])
		print(report.summary())
	quit()
