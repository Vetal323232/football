class_name OnBallAI
extends RefCounted
## Decision of the player on the ball: compares passes, through balls, lofted
## passes, dribbling directions, holding, shooting and clearing on one
## expected-value scale (see FieldValue). Stores the considered options in the
## agent for the F3 overlay.

const DRIBBLE_ANGLES: Array[float] = [0.0, 0.6, -0.6, 1.25, -1.25, 2.1, -2.1, PI]


static func drive(ai: TeamAI, p: SimPlayer, ag: AIAgent) -> void:
	var sim := ai.sim
	var tn := ai.tn
	var now := ai.now
	var opp := ai.opp_index()
	var t_press := SimQuery.opp_arrival(sim, sim.ball.pos, opp, 0.0)
	# Replan triggers: decision timer, commitment over, or sudden pressure.
	var urgent := t_press < 0.4
	var opportunity := ai.take_run_event()
	if (now < ag.next_decision or (now < ag.commit_until and not urgent)) and not opportunity:
		p.cmd.move = ag.move_dir
		p.cmd.sprint = ag.move_sprint
		return
	ag.next_decision = now + tn.onball_decision_time
	# First touch: settle the ball before choosing, unless pressed.
	var settle := tn.settle_time * (1.35 - 0.6 * p.control)
	if p.has_ball_time < settle and t_press > 0.55:
		if ag.move_dir == Vector2.ZERO:
			ag.move_dir = Vector2(ai.team.dir, 0.0) * 0.4
		p.cmd.move = ag.move_dir.limit_length(0.5)
		return
	var choice := decide(ai, p, ag, false, t_press)
	_apply(ai, p, ag, choice, t_press)


static func drive_restart(ai: TeamAI, p: SimPlayer, ag: AIAgent) -> void:
	var sim := ai.sim
	p.cmd.move = Vector2.ZERO
	if sim.restart_ready_t < ai.tn.restart_ai_delay:
		return
	if sim.tick % 6 != 0:
		return
	var choice := decide(ai, p, ag, true, 9.0)
	var force := sim.restart_ready_t > ai.tn.restart_force_time_ai
	if choice.get("req") != null and (float(choice.get("p", 0.0)) > 0.72 or force):
		p.cmd.kick = choice["req"]
		ag.decision_label = str(choice["label"])
		_note_pass(ai, p, choice)
	elif force:
		p.cmd.kick = KickPlanner.plan_clear(sim, p)
		ag.decision_label = "forced long ball"


static func _apply(ai: TeamAI, p: SimPlayer, ag: AIAgent, c: Dictionary, t_press: float) -> void:
	var now := ai.now
	ag.decision_label = str(c.get("label", ""))
	var kind_lbl := ag.decision_label.split(">")[0].split(" ")[0]
	ai.decision_counts[kind_lbl] = int(ai.decision_counts.get(kind_lbl, 0)) + 1
	var req: KickRequest = c.get("req")
	if req != null:
		p.cmd.kick = req
		p.cmd.move = ag.move_dir * 0.5
		ag.next_decision = now + 0.3
		ag.commit_until = 0.0
		_note_pass(ai, p, c)
		return
	ag.move_dir = c.get("move", Vector2.ZERO)
	ag.move_sprint = bool(c.get("sprint", false))
	ag.commit_until = now + (ai.tn.dribble_commit_time if t_press > 0.8 else 0.2)
	p.cmd.move = ag.move_dir
	p.cmd.sprint = ag.move_sprint


static func _note_pass(ai: TeamAI, p: SimPlayer, c: Dictionary) -> void:
	var req: KickRequest = c.get("req")
	if req != null and req.receiver >= 0 and ai.agents.has(req.receiver):
		var ra: AIAgent = ai.agents[req.receiver]
		ra.last_passer = p.id
		ra.last_pass_time = ai.now


static func decide(ai: TeamAI, p: SimPlayer, ag: AIAgent, restart: bool, t_press: float) -> Dictionary:
	var sim := ai.sim
	var tn := ai.tn
	var tm := ai.team
	var tac := ai.tac
	var opp := ai.opp_index()
	var now := ai.now
	var lp := ai.local(sim.ball.pos)
	var v_here := FieldValue.value(lp, tn)
	var counter := ai.phase == TeamAI.Phase.ATTACK_TRANSITION
	var risk := lerpf(1.35, 0.7, tac.pass_risk) * (0.75 if counter else 1.0)
	var loss_here := FieldValue.loss_cost(lp, tn) * risk
	var imp := ai.impatience
	var noise := tac.decision_noise
	var opts: Array = []
	var from_hands := sim.ball.held_by == p.id
	var is_throw := restart and sim.restart_type == MatchSim.Restart.THROW_IN
	var no_offside := restart and (sim.restart_type != MatchSim.Restart.FREE_KICK and sim.restart_type != MatchSim.Restart.KICKOFF)

	# ---- passes ----------------------------------------------------------
	var pass_opts: Array = []
	for id in tm.player_ids:
		if id == p.id:
			continue
		var m: SimPlayer = sim.players[id]
		var ml := ai.local(m.pos)
		if not no_offside and ml.x > ai.off_line + 0.15 and ml.x > lp.x:
			continue
		var d := m.pos.distance_to(sim.ball.pos)
		if restart and sim.restart_type == MatchSim.Restart.KICKOFF and ml.x > -1.0:
			continue
		var plans: Array = []
		if d >= 4.0 and d <= (17.0 if is_throw else 40.0):
			var g := KickPlanner.plan_ground(sim, p, m, 14.0 if (is_throw or from_hands) else -1.0)
			g["label"] = "pass>%d" % m.number
			plans.append(g)
		if not is_throw and not from_hands and d >= 8.0 and d <= 48.0 and ml.x > lp.x - 3.0 \
				and (m.vel.dot(Vector2(tm.dir, 0.0)) > 2.0 or (m.role >= SimPlayer.Role.LCM and ml.x > lp.x + 4.0)) and not m.is_keeper():
			var th := KickPlanner.plan_through(sim, p, m)
			if not th.is_empty():
				th["label"] = "through>%d" % m.number
				plans.append(th)
		if d >= 20.0 and d <= (24.0 if is_throw else 58.0) and not m.is_keeper():
			if plans.is_empty() or float(plans[0]["p"]) < 0.7:
				var lb := KickPlanner.plan_lob(sim, p, m)
				lb["label"] = "lob>%d" % m.number
				plans.append(lb)
		for pl: Dictionary in plans:
			var tl := ai.local(pl["target"])
			var pp: float = pl["p"]
			var space_f := clampf(float(pl["space"]), 0.0, 1.4) / 1.4
			var v_recv := FieldValue.value(tl, tn) * (0.5 + 0.5 * space_f)
			var loss := FieldValue.loss_cost(lp.lerp(tl, 0.6), tn) * risk
			var ev := pp * v_recv - (1.0 - pp) * loss
			# Do not bounce the ball straight back to the previous passer without a reason.
			if ag.last_passer == id and now - ag.last_pass_time < 2.5 and t_press > 0.9:
				ev -= 0.006
			var prog := clampf((tl.x - lp.x) / 15.0, -0.5, 1.5)
			ev += (imp * tn.impatience_gain + tn.progress_bonus * lerpf(0.5, 1.5, tac.pass_risk)) * prog * pp
			if counter:
				ev += 0.004 * clampf((tl.x - lp.x) / 15.0, 0.0, 1.5) * pp
			if m.is_keeper():
				ev -= 0.004
			ev += sim.rng.randfn(0.0, noise)
			pl["ev"] = ev
			pl["recv"] = id
			pass_opts.append(pl)
	# Third-player bonus for the most promising passes: does the receiver have a next option?
	pass_opts.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["ev"]) > float(b["ev"]))
	for i in mini(3, pass_opts.size()):
		var pl2: Dictionary = pass_opts[i]
		pl2["ev"] = float(pl2["ev"]) + float(pl2["p"]) * 0.3 * _next_option(ai, p, int(pl2["recv"]), pl2["target"])
	for pl3: Dictionary in pass_opts:
		opts.append({"label": pl3["label"], "ev": pl3["ev"], "p": pl3["p"], "target": pl3["target"], "req": pl3["req"]})

	# ---- crosses into the box ------------------------------------------------
	var corner := restart and sim.restart_type == MatchSim.Restart.CORNER
	if (lp.x > 20.0 and absf(lp.y) > 9.0 and not from_hands and (not restart or corner)) or corner:
		for id in tm.player_ids:
			if id == p.id:
				continue
			var m2: SimPlayer = sim.players[id]
			var ml2 := ai.local(m2.pos)
			if ml2.x < 27.0 or absf(ml2.y) > 17.0 or m2.is_keeper():
				continue
			if not corner and ml2.x > ai.off_line + 0.15 and ml2.x > lp.x:
				continue
			var ct := Vector2(clampf(ml2.x + 6.0, 39.5, 47.0), clampf(ml2.y * 0.65, -7.5, 7.5))
			var cp := KickPlanner.plan_lob(sim, p, m2, ai.world(ct), true)
			var cpp: float = cp["p"]
			var ev_x := cpp * FieldValue.xg_pos(ct) * 0.55 * tn.goal_value - (1.0 - cpp) * FieldValue.loss_cost(ct, tn) * risk
			ev_x += sim.rng.randfn(0.0, noise)
			opts.append({"label": "cross>%d" % m2.number, "ev": ev_x, "p": cpp, "target": cp["target"], "req": cp["req"]})

	if restart:
		return _pick(ag, opts)

	# ---- shot --------------------------------------------------------------
	if lp.x > 14.0 and not from_hands:
		var xg := FieldValue.xg_shot(sim, p) * tn.xg_scale
		var min_xg := tn.shot_min_xg * (1.0 - 0.5 * imp)
		if xg >= min_xg:
			var ev_s := xg * tn.goal_value - (1.0 - xg) * 0.012 + imp * 0.02 + sim.rng.randfn(0.0, noise)
			# Under imminent pressure in a shooting position a shot beats losing the ball.
			if t_press < 0.5:
				ev_s += 0.015
			opts.append({"label": "shoot xg=%.2f" % xg, "ev": ev_s, "p": xg, "target": Vector2(Pitch.HALF_L * tm.dir, 0.0), "req": KickPlanner.plan_ai_shot(sim, p)})

	if from_hands:
		return _pick(ag, opts)

	# ---- dribble -----------------------------------------------------------
	var fwd := Vector2(tm.dir, 0.0)
	var to_goal := (Vector2(Pitch.HALF_L * tm.dir, 0.0) - p.pos).normalized()
	var base_dir := (fwd * 0.5 + to_goal * 0.5).normalized() if lp.x > 10.0 else fwd
	var run_speed := p.top_speed(tn) * tn.dribble_speed_ratio
	for ang in DRIBBLE_ANGLES:
		var dir := base_dir.rotated(ang)
		var q := p.pos + dir * 6.0
		if absf(q.x) > Pitch.HALF_L - 1.5 or absf(q.y) > Pitch.HALF_W - 1.5:
			continue
		var t_me := 6.0 / run_speed + 0.15
		var m_far := SimQuery.opp_arrival(sim, q, opp, 0.15) - t_me
		var m_mid := SimQuery.opp_arrival(sim, p.pos + dir * 3.0, opp, 0.15) - t_me * 0.5
		var mm := minf(m_far, m_mid + 0.15)
		var pd := FieldValue.sigmoid((mm + tn.dribble_margin_bias) / 0.3) * (0.72 + 0.28 * p.control)
		var ql := ai.local(q)
		var ev_d := pd * FieldValue.value(ql, tn) - (1.0 - pd) * loss_here
		ev_d += (imp * tn.impatience_gain * 0.5 + tn.progress_bonus * 0.4) * clampf((ql.x - lp.x) / 6.0, -1.0, 1.0) * pd
		# Open grass ahead: carry the ball and commit a defender before releasing it.
		if absf(ang) < 0.7 and SimQuery.nearest_opponent_dist(sim, q, opp) > 7.0:
			ev_d += tn.carry_bonus
		if ag.move_dir.length() > 0.5 and ag.move_dir.normalized().dot(dir) > 0.9:
			ev_d += 0.002
		ev_d += sim.rng.randfn(0.0, noise)
		var sprint := (mm > 0.4 and absf(ang) < 1.0 and p.stamina > 0.3) or (counter and mm > 0.2)
		opts.append({"label": "dribble %d°" % int(rad_to_deg(ang)), "ev": ev_d, "p": pd, "target": q, "move": dir, "sprint": sprint})

	# ---- hold / shield -----------------------------------------------------
	var p_hold := clampf((t_press - 0.25) / 1.1, 0.0, 1.0)
	var ev_h := p_hold * v_here - (1.0 - p_hold) * loss_here - tn.hold_decay * minf(p.has_ball_time, 4.0) * 0.25 - imp * 0.004
	opts.append({"label": "hold", "ev": ev_h, "p": p_hold, "target": p.pos, "move": fwd * 0.25, "sprint": false})

	# ---- clearance ---------------------------------------------------------
	if lp.x < -22.0 and t_press < 0.7:
		var cl := KickPlanner.plan_clear(sim, p)
		var cl_l := ai.local(cl.target)
		var ev_c := 0.3 * FieldValue.value(cl_l, tn) - 0.7 * FieldValue.loss_cost(cl_l, tn) * risk
		opts.append({"label": "clear", "ev": ev_c, "p": 0.3, "target": cl.target, "req": cl})

	return _pick(ag, opts)


static func _pick(ag: AIAgent, opts: Array) -> Dictionary:
	if opts.is_empty():
		ag.options = []
		return {}
	opts.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["ev"]) > float(b["ev"]))
	ag.options = opts.slice(0, 10)
	return opts[0]


## Value the receiver could add with his own next pass (third-player combinations).
static func _next_option(ai: TeamAI, passer: SimPlayer, recv_id: int, target: Vector2) -> float:
	var sim := ai.sim
	var tn := ai.tn
	var tl := ai.local(target)
	var v_t := FieldValue.value(tl, tn)
	var best := 0.0
	for id in ai.team.player_ids:
		if id == recv_id or id == passer.id:
			continue
		var k: SimPlayer = sim.players[id]
		if k.is_keeper():
			continue
		var kl := ai.local(k.pos)
		if kl.x < tl.x + 3.0 or kl.x > ai.off_line + 0.2:
			continue
		var d := k.pos.distance_to(target)
		if d < 5.0 or d > 32.0:
			continue
		var gain := FieldValue.value(kl, tn) - v_t
		if gain <= best:
			continue
		var v0 := clampf(BallState.roll_speed_for(d, tn.pass_arrive_speed, tn.roll_decel), 8.0, tn.pass_speed_max)
		var m := KickPlanner.ground_margin(sim, target, k.pos, v0, ai.opp_index(), tn.intercept_react, 3)
		var g := gain * FieldValue.sigmoid((m - 0.1) / 0.25)
		if g > best:
			best = g
	return best
