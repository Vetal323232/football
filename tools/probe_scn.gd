extends SceneTree
## Debug: trace one scenario episode (kicks, claims, duties).
func _init() -> void:
	var name := "buildup_pressure"
	var variant := 0
	var sd := 11
	var secs := 3.0
	var duties := false
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--name="): name = a.trim_prefix("--name=")
		elif a.begins_with("--variant="): variant = int(a.trim_prefix("--variant="))
		elif a.begins_with("--seed="): sd = int(a.trim_prefix("--seed="))
		elif a.begins_with("--secs="): secs = float(a.trim_prefix("--secs="))
		elif a == "--duties": duties = true
	var sim := MatchSim.new()
	sim.init_match(ScenarioLib.make_setup(name, variant, sd), load("res://data/tuning/default_tuning.tres"))
	ScenarioLib.apply(sim, name, variant)
	var t0 := sim.tick
	sim.event.connect(func(kind: StringName, data: Dictionary) -> void:
		var t := (sim.tick - t0) / 60.0
		if kind == &"kick":
			var p: SimPlayer = sim.players[int(data["player"])]
			var ag: AIAgent = sim.teams[p.team].ai.agents[p.id]
			var o := PackedStringArray()
			for x: Dictionary in ag.options.slice(0, 10):
				o.append("%s %.3f(p%.2f)" % [x["label"], x["ev"], x["p"]])
			print("%5.2f KICK T%d #%d %s at %s spd %.0f | %s" % [t, p.team, p.number, ag.decision_label, p.pos.snapped(Vector2(0.1, 0.1)), data["speed"], ", ".join(o)])
		elif kind != &"bounce" and kind != &"control":
			var who := ""
			if data.has("player"):
				var q: SimPlayer = sim.players[int(data["player"])]
				who = "T%d #%d %s" % [q.team, q.number, SimPlayer.ROLE_NAMES[q.role]]
			print("%5.2f %s %s %s" % [t, kind, who, str(data)]))
	var obs := {}
	for i in int(secs * 60):
		ScenarioLib.observe(sim, name, obs)
		ScenarioLib.drive_inputs(sim, name, obs)
		sim.step()
		if duties and i % 30 == 0:
			var s := PackedStringArray()
			for tm in sim.teams:
				for id in tm.player_ids:
					var ag: AIAgent = tm.ai.agents[id]
					if ag.duty in [AIAgent.Duty.PRESS, AIAgent.Duty.COVER, AIAgent.Duty.CHASE, AIAgent.Duty.CARRIER, AIAgent.Duty.RECEIVER]:
						s.append("T%d#%d:%s" % [tm.index, sim.players[id].number, AIAgent.DUTY_NAMES[ag.duty]])
			print("   %.1fs ball(%.0f,%.0f) owner=%d att=[%s,%s] %s" % [i / 60.0, sim.ball.pos.x, sim.ball.pos.y, sim.ball.owner, sim.teams[0].ai.attacking, sim.teams[1].ai.attacking, " ".join(s)])
	quit()
