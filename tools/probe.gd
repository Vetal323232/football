extends SceneTree
## Debug probe: run a match to time T and dump the full option table of the ball carrier.
func _init() -> void:
	var sd := 1
	var at := 10.0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--seed="): sd = int(a.trim_prefix("--seed="))
		elif a.begins_with("--at="): at = float(a.trim_prefix("--at="))
	var sim := MatchSim.new()
	sim.init_match(MatchSetup.exhibition(sd), load("res://data/tuning/default_tuning.tres"))
	var minx := -99.0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--minx="): minx = float(a.trim_prefix("--minx="))
	while sim.tick * MatchSim.DT < at or sim.ball.owner < 0 or sim.ball.pos.x * sim.teams[sim.players[sim.ball.owner].team].dir < minx:
		sim.step()
	var p: SimPlayer = sim.players[sim.ball.owner]
	var ai: TeamAI = sim.teams[p.team].ai
	var ag: AIAgent = ai.agents[p.id]
	print("t=%.2f carrier T%d #%d %s at %s local %s phase %s impatience %.2f offline %.1f" % [sim.tick * MatchSim.DT, p.team, p.number, SimPlayer.ROLE_NAMES[p.role], p.pos, ai.local(p.pos), TeamAI.PHASE_NAMES[ai.phase], ai.impatience, ai.off_line])
	var tp := SimQuery.opp_arrival(sim, sim.ball.pos, 1 - p.team, 0.0)
	OnBallAI.decide(ai, p, ag, false, tp)
	print("t_press %.2f v_here %.4f loss_here %.4f" % [tp, FieldValue.value(ai.local(p.pos), sim.tn), FieldValue.loss_cost(ai.local(p.pos), sim.tn)])
	# full table: re-run with all options kept
	for id in ai.team.player_ids:
		if id == p.id: continue
		var m: SimPlayer = sim.players[id]
		var g := KickPlanner.plan_ground(sim, p, m)
		var tl := ai.local(g["target"])
		print("  #%-2d %-3s local(%5.1f,%5.1f) duty %-7s ground p=%.2f margin=%.2f space=%.2f V=%.4f" % [m.number, SimPlayer.ROLE_NAMES[m.role], ai.local(m.pos).x, ai.local(m.pos).y, AIAgent.DUTY_NAMES[(ai.agents[id] as AIAgent).duty], g["p"], g["margin"], g["space"], FieldValue.value(tl, sim.tn)])
	for id in ai.team.player_ids:
		var m: SimPlayer = sim.players[id]
		if m.role < SimPlayer.Role.LCM or id == p.id: continue
		var th := KickPlanner.plan_through(sim, p, m)
		if th.is_empty():
			print("  through #%d: none" % m.number)
		else:
			print("  through #%d: p=%.2f margin=%.2f space=%.2f target local %s t=%.2f spd=%.1f vel=%s" % [m.number, th["p"], th["margin"], th["space"], ai.local(th["target"]), th["t"], (th["req"] as KickRequest).speed, ai.local(m.vel)])
	print("xg_shot %.3f xg_pos %.3f" % [FieldValue.xg_shot(sim, p), FieldValue.xg_pos(ai.local(sim.ball.pos))])
	for q in sim.players:
		if q.team != p.team:
			print("    opp #%-2d %-3s local(%5.1f,%5.1f) %s" % [q.number, SimPlayer.ROLE_NAMES[q.role], ai.local(q.pos).x, ai.local(q.pos).y, AIAgent.DUTY_NAMES[(sim.teams[q.team].ai.agents[q.id] as AIAgent).duty]])
	for o: Dictionary in ag.options:
		print("  OPT %-14s ev=%.4f p=%.2f" % [o["label"], o["ev"], o["p"]])
	quit()
