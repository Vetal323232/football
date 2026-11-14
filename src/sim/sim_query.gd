class_name SimQuery
extends RefCounted
## Shared geometric / kinematic queries. Everything here uses only the current
## observable state (positions, velocities, attributes) - never future input.


## Estimated time for a player to get within `reach` of `point`, accelerating
## from his current velocity. `react` is added as a fixed delay.
static func time_to_reach(p: SimPlayer, point: Vector2, tn: GameTuning, react := 0.0, reach := 0.7) -> float:
	var to := point - p.pos
	var dist := to.length()
	var d := dist - reach
	if d <= 0.0:
		return react
	var dir := to / dist
	var vmax := p.top_speed(tn)
	var v0 := clampf(p.vel.dot(dir), -vmax, vmax)
	var a := p.accel(tn)
	if v0 < 0.0:
		# Has to brake first.
		var tb := -v0 / tn.decel
		d += 0.5 * -v0 * tb
		react += tb
		v0 = 0.0
	var t_acc := (vmax - v0) / a
	var d_acc := v0 * t_acc + 0.5 * a * t_acc * t_acc
	if d_acc >= d:
		return react + (-v0 + sqrt(v0 * v0 + 2.0 * a * d)) / a
	return react + t_acc + (d - d_acc) / vmax


## Top speed a player actually reaches while carrying the ball with the given gait.
## Mirrors MatchSim._move_players: sprint needs stamina, jogging applies jog_ratio,
## and the ball always costs dribble_speed_ratio.
static func carry_speed(p: SimPlayer, sprint: bool, tn: GameTuning) -> float:
	var top := p.top_speed(tn)
	if not (sprint and p.stamina > 0.03):
		top *= tn.jog_ratio
	if not p.can_act():
		top = minf(top, tn.recover_speed)
	return top * tn.dribble_speed_ratio


## Time for the ball carrier to cover `dist` metres in direction `dir` with the given gait,
## from his current velocity, using the same acceleration / braking limits as the movement
## step. Exact for straight runs; a turn is approximated by braking the sideways component.
static func carry_time(p: SimPlayer, dir: Vector2, dist: float, sprint: bool, tn: GameTuning) -> float:
	var vmax := carry_speed(p, sprint, tn)
	if vmax <= 0.01:
		return INF
	var t := 0.0
	var d := dist
	var v0 := p.vel.dot(dir)
	var side := (p.vel - dir * v0).length()
	# Sideways speed has to be shed while turning; it delays the forward build-up.
	t += 0.5 * side / tn.decel
	if v0 < 0.0:
		var tb := -v0 / tn.decel
		d += 0.5 * -v0 * tb
		t += tb
		v0 = 0.0
	if v0 > vmax:
		# Faster than this gait allows (e.g. easing from a sprint): slows down on the way.
		var td := (v0 - vmax) / tn.decel
		var dd := v0 * td - 0.5 * tn.decel * td * td
		if dd >= d:
			return t + (v0 - sqrt(maxf(0.0, v0 * v0 - 2.0 * tn.decel * d))) / tn.decel
		return t + td + (d - dd) / vmax
	var a := p.accel(tn)
	var t_acc := (vmax - v0) / a
	var d_acc := v0 * t_acc + 0.5 * a * t_acc * t_acc
	if d_acc >= d:
		return t + (-v0 + sqrt(v0 * v0 + 2.0 * a * d)) / a
	return t + t_acc + (d - d_acc) / vmax


## 0 = free, 1 = one opponent on top of him, can exceed 1 with several.
static func pressure(sim: MatchSim, p: SimPlayer) -> float:
	return pressure_at(sim, p.pos, 1 - p.team)


static func pressure_at(sim: MatchSim, pos: Vector2, opp_team: int) -> float:
	var s := 0.0
	for id in sim.teams[opp_team].player_ids:
		var o: SimPlayer = sim.players[id]
		var d := o.pos.distance_to(pos)
		if d < 7.0:
			var closing := maxf(0.0, o.vel.dot((pos - o.pos) / maxf(d, 0.01))) / 8.0
			s += clampf(1.0 - (d - 1.0) / 6.0, 0.0, 1.0) * (0.75 + 0.5 * closing)
	return s


static func nearest_opponent_dist(sim: MatchSim, pos: Vector2, opp_team: int) -> float:
	var best := INF
	for id in sim.teams[opp_team].player_ids:
		var d: float = sim.players[id].pos.distance_squared_to(pos)
		if d < best:
			best = d
	return sqrt(best)


## Earliest time any opponent can arrive at pos.
static func opp_arrival(sim: MatchSim, pos: Vector2, opp_team: int, react: float) -> float:
	var best := INF
	for id in sim.teams[opp_team].player_ids:
		var o: SimPlayer = sim.players[id]
		var reach := 1.3 if o.is_keeper() else 0.8
		var t := time_to_reach(o, pos, sim.tn, react, reach)
		if t < best:
			best = t
	return best


## Local x of the offside line for an attacking team (second-last defender or ball or halfway).
static func offside_line_local(sim: MatchSim, attacking_team: int) -> float:
	var tm: SimTeam = sim.teams[attacking_team]
	var first := -INF
	var second := -INF
	for id in sim.teams[1 - attacking_team].player_ids:
		var lx: float = sim.players[id].pos.x * tm.dir
		if lx > first:
			second = first
			first = lx
		elif lx > second:
			second = lx
	return maxf(maxf(second, sim.ball.pos.x * tm.dir), 0.0)


static func is_offside_pos(sim: MatchSim, p: SimPlayer, margin := 0.0) -> bool:
	var tm: SimTeam = sim.teams[p.team]
	return p.pos.x * tm.dir > offside_line_local(sim, p.team) + margin


static func nearest_player_to(sim: MatchSim, pos: Vector2, team: int, exclude := -1, skip_keeper := false) -> SimPlayer:
	var best: SimPlayer = null
	var bd := INF
	for id in sim.teams[team].player_ids:
		if id == exclude:
			continue
		var o: SimPlayer = sim.players[id]
		if skip_keeper and o.is_keeper():
			continue
		var d := o.pos.distance_squared_to(pos)
		if d < bd:
			bd = d
			best = o
	return best
