extends SceneTree
## Headless AI validation: runs every diagnostic scenario with several variants and seeds.
## Usage: godot --headless -s tools/run_scenarios.gd -- [--only=name] [--seeds=1,2,3] [--verbose]


func _init() -> void:
	var seeds := [11, 22, 33]
	var only := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--seeds="):
			seeds = []
			for s in a.trim_prefix("--seeds=").split(","):
				seeds.append(int(s))
		elif a.begins_with("--only="):
			only = a.trim_prefix("--only=")
	var tuning: GameTuning = load("res://data/tuning/default_tuning.tres")
	var total := 0
	var passed := 0
	for name in ScenarioLib.NAMES:
		if only != "" and only != name:
			continue
		var s_ok := 0
		var s_n := 0
		print("=== %s — %s" % [name, ScenarioLib.TITLES[name]])
		for variant in 3:
			for sd: int in seeds:
				var setup := ScenarioLib.make_setup(name, variant, sd)
				var sim := MatchSim.new()
				sim.init_match(setup, tuning)
				ScenarioLib.apply(sim, name, variant)
				var obs := {}
				var n := int(float(ScenarioLib.DURATION[name]) * 60.0)
				for i in n:
					ScenarioLib.observe(sim, name, obs)
					ScenarioLib.drive_inputs(sim, name, obs)
					sim.step()
					ScenarioLib.post_step(sim, name, obs)
				var v := ScenarioLib.judge(sim, name, variant, obs)
				s_n += 1
				total += 1
				if v["ok"] and (v["fail"] as PackedStringArray).is_empty():
					s_ok += 1
					passed += 1
				print("  v%d seed %d: %s | %s%s" % [variant, sd, "OK  " if v["ok"] and (v["fail"] as PackedStringArray).is_empty() else "FAIL", "; ".join(v["notes"]),
					("  !! " + "; ".join(v["fail"])) if not (v["fail"] as PackedStringArray).is_empty() else ""])
		print("  -> %d/%d episodes without violated invariants" % [s_ok, s_n])
	print("TOTAL %d/%d" % [passed, total])
	quit()
