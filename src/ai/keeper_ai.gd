class_name KeeperAI
extends RefCounted
## Goalkeeper behaviour: positioning on the ball-goal line, coming out for
## reachable balls, reacting to shots after a reaction delay with feasible
## movement / dives, and distributing within a bounded time.


static func drive(ai: TeamAI, p: SimPlayer, ag: AIAgent) -> void:
	var sim := ai.sim
	var tn := ai.tn
	var b := sim.ball
	var now := ai.now
	var goal := ai.own_goal()
	var out_dir := Vector2(ai.team.dir, 0.0)
	ag.duty = AIAgent.Duty.GK

	if sim.state == MatchSim.State.RESTART_READY:
		if p.id == sim.restart_taker:
			OnBallAI.drive_restart(ai, p, ag)
		else:
			ai._go(p, ag.anchor if ag.anchor != Vector2.ZERO else goal + out_dir * 3.0, false)
		return

	# --- ball in hands: distribute ------------------------------------------
	if b.held_by == p.id:
		p.cmd.move = Vector2.ZERO
		p.cmd.face = out_dir
		if ag.release_at < now - 10.0 or ag.release_at == 0.0:
			ag.release_at = now + 1.6
		if b.held_time < 1.2:
			ag.reason = "holding: let team spread"
			return
		if sim.tick % 6 == 0:
			var c := OnBallAI.decide(ai, p, ag, false, 9.0)
			var forced := b.held_time > tn.keeper_hold_max - 1.0
			if c.get("req") != null and (float(c.get("p", 0.0)) > 0.8 or forced):
				p.cmd.kick = c["req"]
				ag.reason = "distribute: %s" % c["label"]
				ag.release_at = 0.0
			elif forced:
				p.cmd.kick = KickPlanner.plan_clear(sim, p)
				ag.reason = "no safe option: long kick"
				ag.release_at = 0.0
		return
	ag.release_at = 0.0

	# --- ball at feet (back-pass): play it like an outfielder, safety first -----
	if b.owner == p.id:
		var t_press := SimQuery.opp_arrival(sim, b.pos, ai.opp_index(), 0.0)
		if t_press < 0.9:
			p.cmd.kick = KickPlanner.plan_clear(sim, p)
			ag.reason = "pressed: clear"
			return
		if p.has_ball_time > 0.3 and sim.tick % 6 == 0:
			var c2 := OnBallAI.decide(ai, p, ag, true, t_press)
			if c2.get("req") != null and float(c2.get("p", 0.0)) > 0.75:
				p.cmd.kick = c2["req"]
			elif p.has_ball_time > 2.0:
				p.cmd.kick = KickPlanner.plan_clear(sim, p)
		return

	var gl := ai.local(goal)
	var free := b.is_free()

	# --- shot / ball heading for the goal -----------------------------------------
	if free:
		var path := sim.ball_path()
		var cross := _goal_line_crossing(ai, path)
		if cross.z >= 0.0 and absf(cross.y) < Pitch.GOAL_HALF_W + 1.2:
			if ag.save_kick_id != b.kick_id:
				ag.save_kick_id = b.kick_id
				ag.react_until = maxf(now, b.kick_tick * MatchSim.DT + lerpf(tn.keeper_react_bad, tn.keeper_react_good, p.goalkeeping) * (ai.tac.reaction_time / 0.25))
			if now < ag.react_until:
				ag.reason = "shot: reacting"
				p.cmd.face = b.pos - p.pos
				return
			# Meet the ball on the keeper's own depth line.
			var meet := _path_at_depth(ai, path, ai.local(p.pos).x)
			if meet.z < 0.0:
				meet = cross
			var meet_w := ai.world(Vector2(meet.x, meet.y))
			var lateral := meet_w.distance_to(p.pos)
			var t_left := meet.z
			var walk_t := SimQuery.time_to_reach(p, meet_w, tn, 0.0, tn.keeper_reach * 0.7)
			ag.reason = "save: move to line"
			if walk_t > t_left and lateral > tn.keeper_reach * 0.7 and t_left < 0.75 and p.can_act():
				p.cmd.dive = meet_w
				ag.reason = "save: dive"
			else:
				ai._go(p, meet_w, true, 0.6)
				p.cmd.face = b.pos - p.pos
			return
		# Come for a ball he reaches first inside his area.
		var r := ai.intercept(p, path)
		var rl := ai.local(Vector2(r.x, r.y))
		var in_area := rl.x < -Pitch.HALF_L + Pitch.PEN_DEPTH - 0.5 and absf(rl.y) < Pitch.PEN_HALF_W - 0.5
		if in_area and r.z < ai.opp_eta - 0.15 and (r.z < ai.our_eta + 0.4 or ai.opp_eta < ai.our_eta + 1.0):
			ag.reason = "come out: first to ball"
			var tgt := Vector2(r.x, r.y)
			if p.pos.distance_to(b.pos) < 2.5:
				tgt = b.pos
			ai._go(p, tgt, true, 0.8)
			return

	# --- one-on-one: narrow the angle, smother a loose touch ----------------
	var bl := ai.local(b.pos)
	var ball_goal_d := b.pos.distance_to(goal)
	if b.owner >= 0 and sim.players[b.owner].team != ai.team.index and ball_goal_d < 22.0:
		var carrier: SimPlayer = sim.players[b.owner]
		var cover := false
		for id in ai.team.player_ids:
			if id == p.id:
				continue
			var d: SimPlayer = sim.players[id]
			if d.pos.distance_to(carrier.pos) < 3.0 and d.pos.distance_to(goal) < ball_goal_d:
				cover = true
				break
		var kd := p.pos.distance_to(b.pos)
		if kd < 2.4 and carrier.pos.distance_to(b.pos) > 0.75 and p.can_act() and Pitch.in_pen_area(b.pos, -ai.team.dir):
			p.cmd.dive = b.pos
			ag.reason = "smother"
			return
		if not cover and absf(bl.y) < 16.0:
			var dist_out := clampf(ball_goal_d - 4.0, 2.0, 9.0)
			ai._go(p, goal + (b.pos - goal).normalized() * dist_out, true, 1.0)
			p.cmd.face = b.pos - p.pos
			ag.reason = "1v1: narrow angle"
			return

	# --- default positioning --------------------------------------------------
	var r_out := clampf(ball_goal_d * 0.11, 1.2, 5.0)
	if bl.x > 5.0 and ai.attacking:
		r_out = clampf(8.0 + (bl.x - 5.0) * 0.2, 8.0, 15.0)
	var dirb := (b.pos - goal)
	if dirb.length() < 0.5:
		dirb = out_dir
	var pos := goal + dirb.normalized() * r_out
	var pl := ai.local(pos)
	pl.x = maxf(pl.x, -Pitch.HALF_L + 0.8)
	pl.y = clampf(pl.y, -Pitch.GOAL_HALF_W - 0.5, Pitch.GOAL_HALF_W + 0.5) if r_out < 6.0 else pl.y
	ai._go(p, ai.world(pl), p.pos.distance_to(ai.world(pl)) > 6.0, 1.5)
	p.cmd.face = b.pos - p.pos
	ag.reason = "position on ball-goal line"
	ag.target = ai.world(pl)


## Where the predicted path crosses our own goal line: (local x, local y, time) or z = -1.
static func _goal_line_crossing(ai: TeamAI, path: PackedVector3Array) -> Vector3:
	return _path_at_depth(ai, path, -Pitch.HALF_L, true)


## First point where the path reaches local depth x (moving toward our goal).
static func _path_at_depth(ai: TeamAI, path: PackedVector3Array, depth: float, as_cross := false) -> Vector3:
	var dir := ai.team.dir
	var n := path.size()
	if n < 2:
		return Vector3(0, 0, -1)
	var prev_x := path[0].x * dir
	if prev_x <= depth:
		return Vector3(0, 0, -1)
	for i in range(1, n):
		var x := path[i].x * dir
		if x <= depth:
			var f := (prev_x - depth) / maxf(prev_x - x, 0.0001)
			var y := lerpf(path[i - 1].y, path[i].y, f) * dir
			var h := lerpf(path[i - 1].z, path[i].z, f)
			var t := (float(i - 1) + f) * 0.1
			if as_cross and h > Pitch.GOAL_H + 0.6:
				return Vector3(0, 0, -1)
			return Vector3(depth, y, t)
		prev_x = x
	return Vector3(0, 0, -1)
