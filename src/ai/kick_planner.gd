class_name KickPlanner
extends RefCounted
## Builds concrete kicks (direction, speed, loft) and estimates their success.
## Shared by the AI and by the human pass assistance, so both obey the same rules.
## Plans are Dictionaries: {req, p, t, target, space, margin}.


## Worst-case interception margin (seconds) along a rolling pass. Positive = ball wins.
## If `recv` is given, the receiver is assumed to come toward the ball: points he
## reaches before an opponent are his, so a marker standing behind him is no threat.
static func ground_margin(sim: MatchSim, from: Vector2, to: Vector2, v0: float, opp_team: int, react: float, samples := 6, recv: SimPlayer = null, end_frac := 1.0) -> float:
	var seg := to - from
	var d := seg.length()
	if d < 0.5:
		return 1.0
	var dir := seg / d
	var worst := 3.0
	var decel := sim.tn.roll_decel
	var tn := sim.tn
	# Receiver arrival per sample (only when a receiver is known).
	var t_recv := PackedFloat32Array()
	var t_ball := PackedFloat32Array()
	t_recv.resize(samples + 1)
	t_ball.resize(samples + 1)
	for i in range(1, samples + 1):
		var s := d * end_frac * float(i) / float(samples)
		var tb := BallState.roll_time(v0, s, decel)
		t_ball[i] = 6.0 if tb == INF else tb
		t_recv[i] = SimQuery.time_to_reach(recv, from + dir * s, tn, 0.05, 0.6) if recv != null else INF
	for id in sim.teams[opp_team].player_ids:
		var o: SimPlayer = sim.players[id]
		var rel := o.pos - from
		var along := rel.dot(dir)
		var perp := absf(rel.cross(dir))
		if along < -2.5 or along > d + 5.0 or perp > 4.0 + d * 0.5:
			continue
		var reach := 1.35 if o.is_keeper() else 0.9
		if perp < reach - 0.15 and along > 0.3 and along < d * end_frac - 0.5:
			if recv == null or SimQuery.time_to_reach(recv, from + dir * along, tn, 0.05, 0.6) > BallState.roll_time(v0, along, decel):
				return -1.0  # standing in the lane: the ball rolls into his feet
		for i in range(1, samples + 1):
			var s := d * end_frac * float(i) / float(samples)
			var t_o := SimQuery.time_to_reach(o, from + dir * s, tn, react, reach)
			var m := t_o - t_ball[i]
			if recv != null and t_recv[i] <= t_ball[i] + 0.05:
				# Receiver can be on this spot when the ball comes: opponent must beat him too.
				m = maxf(m, t_o - t_recv[i] - 0.1)
			if m < worst:
				worst = m
	return worst


static func _accuracy(d: float, passing: float) -> float:
	return clampf(1.0 - (d / 70.0) * (0.8 - 0.55 * passing), 0.45, 1.0)


static func _p_from_margin(m: float, tn: GameTuning) -> float:
	return FieldValue.sigmoid((m - tn.pass_margin_bias) / tn.pass_margin_soft)


static func plan_ground(sim: MatchSim, passer: SimPlayer, recv: SimPlayer, max_speed := -1.0) -> Dictionary:
	var tn := sim.tn
	var from := sim.ball.pos
	var vmax := tn.pass_speed_max if max_speed < 0.0 else max_speed
	var tgt := recv.pos + recv.vel * 0.3
	var v0 := 10.0
	var t := 1.0
	for i in 2:
		var d := from.distance_to(tgt)
		v0 = clampf(BallState.roll_speed_for(d, tn.pass_arrive_speed, tn.roll_decel), 8.0, vmax)
		t = BallState.roll_time(v0, d, tn.roll_decel)
		if t == INF:
			t = 4.0
		tgt = Pitch.clamp_inside(recv.pos + recv.vel * minf(t, 1.3) * 0.85, 0.8)
	var react := tn.intercept_react
	var margin := ground_margin(sim, from, tgt, v0, 1 - passer.team, react, 6, recv)
	var t_recv := SimQuery.time_to_reach(recv, tgt, tn, 0.1, 0.6)
	var late := maxf(0.0, t_recv - t - 0.35)
	var space := SimQuery.opp_arrival(sim, tgt, 1 - passer.team, react) - maxf(t, t_recv)
	var dist := from.distance_to(tgt)
	var p := _p_from_margin(margin, tn) * _accuracy(dist, passer.passing) * clampf(1.0 - late, 0.0, 1.0)
	var req := KickRequest.make(KickRequest.Kind.PASS, tgt - from, v0, 0.0, recv.id, tgt)
	return {"req": req, "p": p, "t": t, "target": tgt, "space": space, "margin": margin}


## Pass into space ahead of a runner. bias_dir (world) optionally steers the run line.
static func plan_through(sim: MatchSim, passer: SimPlayer, recv: SimPlayer, bias_dir := Vector2.ZERO) -> Dictionary:
	var tn := sim.tn
	var tm: SimTeam = sim.teams[passer.team]
	var from := sim.ball.pos
	var attack := Vector2(tm.dir, 0.0)
	var to_goal := (Vector2(Pitch.HALF_L * tm.dir, 0.0) - recv.pos).normalized()
	var run_dir := (attack * 0.6 + to_goal * 0.4).normalized()
	if recv.vel.length() > 2.5 and recv.vel.dot(attack) > 0.0:
		run_dir = (recv.vel.normalized() * 0.7 + run_dir * 0.3).normalized()
	if bias_dir.length_squared() > 0.01:
		run_dir = (run_dir + bias_dir.normalized() * 0.6).normalized()
	var react := tn.intercept_react
	var best := {}
	var best_m := -INF
	for lead: float in [5.0, 8.0, 11.0, 15.0, 20.0, 26.0]:
		var tgt := recv.pos + recv.vel * 0.2 + run_dir * lead
		if absf(tgt.x) > Pitch.HALF_L - 3.0 or absf(tgt.y) > Pitch.HALF_W - 1.5:
			continue
		var d := from.distance_to(tgt)
		if d < 6.0:
			continue
		var v0 := clampf(BallState.roll_speed_for(d, tn.through_arrive_speed, tn.roll_decel), 9.0, tn.pass_speed_max)
		var t := BallState.roll_time(v0, d, tn.roll_decel)
		if t == INF:
			continue
		var t_recv := SimQuery.time_to_reach(recv, tgt, tn, 0.15, 0.5)
		var timing := t + 0.8 - t_recv
		var path_m := ground_margin(sim, from, tgt, v0, 1 - passer.team, react)
		var arrive_m := SimQuery.opp_arrival(sim, tgt, 1 - passer.team, react) - maxf(t, t_recv)
		var m := minf(minf(path_m, arrive_m), timing)
		if m > best_m + 0.05 or (m > best_m - 0.05 and m > 0.3):
			best_m = maxf(m, best_m)
			var p := _p_from_margin(m, tn) * _accuracy(d, passer.passing) * 0.92
			best = {"req": KickRequest.make(KickRequest.Kind.THROUGH, tgt - from, v0, 0.0, recv.id, tgt),
				"p": p, "t": t, "target": tgt, "space": arrive_m, "margin": m}
	return best


static func _lob_launch(sim: MatchSim, from: Vector2, tgt: Vector2, flight: float, kind: int, recv_id: int) -> KickRequest:
	var tn := sim.tn
	var d := from.distance_to(tgt)
	var vx := d / flight
	var vh := 0.5 * tn.gravity * flight
	# One numeric correction pass for air drag.
	var b := BallState.new()
	b.pos = Vector2.ZERO
	b.vel = Vector2(vx, 0.0)
	b.vh = vh
	b.h = 0.01
	for i in 150:
		b.advance(1.0 / 30.0, tn)
		if b.h <= 0.0:
			break
	if b.pos.x > 1.0:
		vx *= clampf(d / b.pos.x, 0.8, 1.35)
	return KickRequest.make(kind, tgt - from, vx, vh, recv_id, tgt)


static func plan_lob(sim: MatchSim, passer: SimPlayer, recv: SimPlayer, target_override := Vector2.INF, cross := false) -> Dictionary:
	var tn := sim.tn
	var from := sim.ball.pos
	var tgt := target_override
	if tgt == Vector2.INF:
		tgt = recv.pos + recv.vel.limit_length(5.0) * 0.9
	tgt = Pitch.clamp_inside(tgt, 1.5)
	var d := from.distance_to(tgt)
	var flight := clampf(0.55 + d / 21.0, 0.85, 2.9)
	if cross:
		flight = clampf(0.35 + d / 25.0, 0.65, 1.7)
	var req := _lob_launch(sim, from, tgt, flight, KickRequest.Kind.LOB, recv.id)
	var react := tn.intercept_react
	var t_recv := SimQuery.time_to_reach(recv, tgt, tn, 0.15, 0.6)
	var opp_t := SimQuery.opp_arrival(sim, tgt, 1 - passer.team, react)
	var space := opp_t - maxf(flight, t_recv)
	var m := space + 0.2
	# A defender in front of the kicker can block the ball while it is still low.
	var dir := (tgt - from).normalized()
	for id in sim.teams[1 - passer.team].player_ids:
		var o: SimPlayer = sim.players[id]
		var rel := o.pos - from
		var along := rel.dot(dir) - o.vel.dot(dir) * 0.15
		if along > 0.0 and along < 9.0 and absf(rel.cross(dir)) < 1.1 + along * 0.08:
			var ta := along / maxf(req.speed, 1.0)
			var h_at := req.vh * ta - 0.5 * tn.gravity * ta * ta
			if h_at < 2.1:
				m -= 1.2
	var late := maxf(0.0, t_recv - flight - 0.3)
	var p := _p_from_margin(m, tn) * _accuracy(d, passer.passing) * 0.86 * clampf(1.0 - late, 0.0, 1.0)
	return {"req": req, "p": p, "t": flight, "target": tgt, "space": space, "margin": m}


## Shot at a point in the goal mouth. aim_y / aim_h in metres on the goal plane.
static func plan_shot(sim: MatchSim, p: SimPlayer, aim_y: float, aim_h: float, power: float) -> KickRequest:
	var tn := sim.tn
	var tm: SimTeam = sim.teams[p.team]
	var from := sim.ball.pos
	var tgt := Vector2(Pitch.HALF_L * tm.dir, aim_y)
	var d := maxf(from.distance_to(tgt), 0.5)
	var vmax := tn.shot_speed_base + tn.shot_speed_attr * p.shooting
	var spd := lerpf(tn.shot_speed_min, vmax, clampf(power, 0.0, 1.0))
	var t := d / spd * 1.06
	var vh := (aim_h + 0.5 * tn.gravity * t * t) / t
	return KickRequest.make(KickRequest.Kind.SHOT, tgt - from, spd, vh, -1, tgt)


## AI shot: pick the corner farther from the goalkeeper.
static func plan_ai_shot(sim: MatchSim, p: SimPlayer) -> KickRequest:
	var tm: SimTeam = sim.teams[p.team]
	var keeper: SimPlayer = sim.players[sim.teams[1 - p.team].player_ids[0]]
	var goal_x := Pitch.HALF_L * tm.dir
	# Where the keeper covers on the goal line as seen from the ball.
	var from := sim.ball.pos
	var ky := keeper.pos.y
	var denom := keeper.pos.x - from.x
	if absf(denom) > 0.5 and signf(denom) == signf(goal_x - from.x):
		ky = from.y + (keeper.pos.y - from.y) * (goal_x - from.x) / denom
	var aim_y := -2.7 if ky > 0.0 else 2.7
	if absf(ky) < 0.5:
		aim_y = 2.7 if from.y < 0.0 else -2.7
	var d := from.distance_to(Vector2(goal_x, 0.0))
	var aim_h := 0.5 if d < 14.0 else 1.1
	return plan_shot(sim, p, aim_y, aim_h, 0.95 if d > 12.0 else 0.8)


static func plan_clear(sim: MatchSim, p: SimPlayer) -> KickRequest:
	var tm: SimTeam = sim.teams[p.team]
	var side := signf(p.pos.y) if absf(p.pos.y) > 3.0 else (1.0 if p.facing.y >= 0.0 else -1.0)
	var dir := Vector2(tm.dir, side * 0.45).normalized()
	var tgt := Pitch.clamp_inside(sim.ball.pos + dir * 45.0, 3.0)
	return _lob_launch(sim, sim.ball.pos, tgt, 2.4, KickRequest.Kind.CLEAR, -1)
