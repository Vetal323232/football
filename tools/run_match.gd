extends SceneTree
## Headless AI-vs-AI match runner.
## Usage: godot --headless -s tools/run_match.gd -- --seeds=1,2,3 [--duration=360] [--verbose]


func _init() -> void:
	var seeds := [1]
	var duration := 360.0
	var verbose := false
	var lv_home := 70.0
	var lv_away := 70.0
	var totals := {"hw": 0, "d": 0, "aw": 0, "hg": 0, "ag": 0, "shots": 0, "stalls": 0, "conflicts": 0}
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--seeds="):
			seeds = []
			for s in a.trim_prefix("--seeds=").split(","):
				seeds.append(int(s))
		elif a.begins_with("--duration="):
			duration = float(a.trim_prefix("--duration="))
		elif a.begins_with("--levels="):
			var lv := a.trim_prefix("--levels=").split(",")
			lv_home = float(lv[0])
			lv_away = float(lv[1])
		elif a == "--verbose":
			verbose = true
	var tuning: GameTuning = load("res://data/tuning/default_tuning.tres")
	for sd: int in seeds:
		var setup := MatchSetup.exhibition(sd, lv_home, lv_away)
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
		totals["hw" if sim.teams[0].score > sim.teams[1].score else ("d" if sim.teams[0].score == sim.teams[1].score else "aw")] += 1
		totals["hg"] += sim.teams[0].score
		totals["ag"] += sim.teams[1].score
		totals["shots"] += sim.teams[0].stats.shots + sim.teams[1].stats.shots
		totals["stalls"] += sim.stalls
		totals["conflicts"] += sim.teams[0].ai.conflicts + sim.teams[1].ai.conflicts
	print("TOTAL over %d matches (levels %.0f vs %.0f): home wins %d, draws %d, away wins %d | goals %d:%d | shots/match %.1f | stalls %d | assignment conflicts %d" % [
		seeds.size(), lv_home, lv_away, totals["hw"], totals["d"], totals["aw"], totals["hg"], totals["ag"], float(totals["shots"]) / seeds.size(), totals["stalls"], totals["conflicts"]])
	quit()
