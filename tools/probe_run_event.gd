extends SceneTree
## AI01 evidence: on-ball decision frequency around runner events in real run_behind episodes.
## Counts completed decisions (TeamAI.decision_counts, already computed by the AI; nothing is re-run).
## Usage: godot --headless -s tools/probe_run_event.gd -- [--seeds=11,22,33]
func _init() -> void:
	var seeds := [11, 22, 33]
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--seeds="):
			seeds = []
			for s in a.trim_prefix("--seeds=").split(","):
				seeds.append(int(s))
	var tuning: GameTuning = load("res://data/tuning/default_tuning.tres")
	var events := 0
	var before := 0
	var after := 0
	var worst := 0
	for variant in 3:
		for sd: int in seeds:
			var sim := MatchSim.new()
			sim.init_match(ScenarioLib.make_setup("run_behind", variant, sd), tuning)
			ScenarioLib.apply(sim, "run_behind", variant)
			var ai: TeamAI = sim.teams[0].ai
			var per_tick: Array[int] = []
			var starts: Array[int] = []
			var prev_total := 0
			var prev_run := {}
			for t in 420:
				sim.step()
				var total := 0
				for k: String in ai.decision_counts:
					total += int(ai.decision_counts[k])
				per_tick.append(total - prev_total)
				prev_total = total
				for id in sim.teams[0].player_ids:
					var rs: int = (ai.agents[id] as AIAgent).run_state
					if rs == 1 and int(prev_run.get(id, 0)) != 1:
						starts.append(t)
					prev_run[id] = rs
			for st: int in starts:
				if st < 30 or st > 420 - 31:
					continue
				var b := 0
				var a2 := 0
				for i in range(st - 30, st):
					b += per_tick[i]
				for i in range(st, st + 30):
					a2 += per_tick[i]
				events += 1
				before += b
				after += a2
				worst = maxi(worst, a2)
			sim.dispose()
	print("RUN_EVENT episodes=%d runner_events=%d | decisions in the 0.5 s before: avg %.2f | in the 0.5 s after: avg %.2f, max %d (one decision per %.2f s is the normal cadence => about %.1f per 0.5 s)" % [
		3 * seeds.size(), events, float(before) / maxf(1.0, events), float(after) / maxf(1.0, events), worst, tuning.onball_decision_time, 0.5 / tuning.onball_decision_time])
	quit()
