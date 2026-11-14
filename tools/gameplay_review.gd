extends SceneTree
## Independent gameplay boundary checks at 3d08f8b. Desired contracts, not scripted AI outcomes.
## Use the strict Python audit wrapper to catch errors as well as the verdict.

var tn: GameTuning


func _init() -> void:
	tn = load("res://data/tuning/default_tuning.tres")
	var selected := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--case="):
			selected = arg.trim_prefix("--case=")
	var ok := false
	match selected:
		"transition_trace":
			_transition_trace()
			quit(0)
			return
		"carry_recovery": ok = _carry_recovery()
		"urgent_pressure": ok = _urgent_pressure()
		_:
			printerr("Unknown gameplay review case: ", selected)
			quit(2)
			return
	print("GAMEPLAY_REVIEW_DONE ", JSON.stringify({"case": selected, "ok": ok}))
	quit(0 if ok else 1)


func _new_sim() -> MatchSim:
	var sim := MatchSim.new()
	sim.init_match(MatchSetup.exhibition(211), tn)
	for p in sim.players:
		p.pos = Vector2(-40 * sim.teams[p.team].dir, -28 + p.role * 2)
		p.vel = Vector2.ZERO
	ScenarioLib._start(sim, null, Vector2.ZERO)
	sim.tick = 300
	return sim


func _carry_recovery() -> bool:
	var sim := _new_sim()
	var p := sim.players[6]
	p.pos = Vector2.ZERO
	p.stun = tn.tackle_stun
	p.vel = Vector2(tn.recover_speed, 0)
	p.cmd.move = Vector2.RIGHT
	p.cmd.sprint = true
	sim.ball.owner = p.id
	var predicted_speed := SimQuery.carry_speed(p, true, tn)
	# Isolate one actual movement step: the ball-owner and recovery branches are unchanged.
	sim._move_players()
	var executed_speed := p.vel.x
	var ok := absf(predicted_speed - executed_speed) < 0.001
	print("carry_recovery predicted=", predicted_speed, " executed=", executed_speed,
		" can_act=", p.can_act(), " recover_speed=", tn.recover_speed)
	sim.dispose()
	return ok


func _urgent_pressure() -> bool:
	var sim := _new_sim()
	var p := sim.players[6]
	p.pos = Vector2.ZERO
	p.has_ball_time = 1.0
	sim.ball.owner = p.id
	sim.ball.pos = Vector2(0.5, 0)
	var ai := sim.teams[0].ai
	ai.now = sim.tick * MatchSim.DT
	var ag: AIAgent = ai.agents[p.id]
	ag.next_decision = ai.now + 0.1
	ag.commit_until = ai.now + 0.3
	ag.move_dir = Vector2.DOWN
	ag.options.clear()
	# Negative control: normal pressure must retain the scheduled decision.
	OnBallAI.drive(ai, p, ag)
	var normal_held := ag.options.is_empty() and is_equal_approx(ag.next_decision, ai.now + 0.1)
	# Opponent enters physical reach after the previous decision. No future input is used.
	sim.players[20].pos = sim.ball.pos
	var pressure_eta := SimQuery.opp_arrival(sim, sim.ball.pos, 1, 0.0)
	OnBallAI.drive(ai, p, ag)
	var reconsidered := not ag.options.is_empty()
	print("urgent_pressure normal_held=", normal_held, " eta=", pressure_eta,
		" reconsidered=", reconsidered, " remaining_deadline=", ag.next_decision - ai.now)
	sim.dispose()
	return normal_held and pressure_eta < 0.4 and reconsidered


func _transition_trace() -> void:
	var sim := MatchSim.new()
	sim.init_match(ScenarioLib.make_setup("high_loss", 0, 11), tn)
	ScenarioLib.apply(sim, "high_loss", 0)
	var obs := {}
	for tick_ in 421:
		ScenarioLib.observe(sim, "high_loss", obs)
		if tick_ % 30 == 0:
			var ai := sim.teams[0].ai
			var rows := []
			for id in sim.teams[0].player_ids:
				var p := sim.players[id]
				if p.is_keeper(): continue
				var ag: AIAgent = ai.agents[id]
				rows.append({"id": id, "x": snappedf(p.pos.x, 0.1), "vx": snappedf(p.vel.x, 0.1),
					"duty": AIAgent.DUTY_NAMES[ag.duty], "sprint": p.cmd.sprint,
					"anchor_x": snappedf(ag.anchor.x, 0.1), "target_x": snappedf(ag.target.x, 0.1),
					"distance_target": snappedf(p.pos.distance_to(ag.target), 0.1)})
			print("TRANSITION ", JSON.stringify({"t": tick_ / 60.0, "ball_x": snappedf(sim.ball.pos.x, 0.1),
				"owner": sim.ball.owner, "phase": TeamAI.PHASE_NAMES[ai.phase], "players": rows}))
		sim.step()
		ScenarioLib.post_step(sim, "high_loss", obs)
	print("TRANSITION_VERDICT ", ScenarioLib.judge(sim, "high_loss", 0, obs))
	sim.dispose()
