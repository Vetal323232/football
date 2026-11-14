class_name HumanController
extends RefCounted
## Turns InputFrame samples into PlayerCommand for the controlled player.
## Uses the same KickPlanner as the AI; assistance only chooses the receiver and
## the launch parameters - the ball then flies by physics and can be intercepted.

var sim: MatchSim
var team: int
var controlled := -1
var input := InputFrame.new()
var shot_charge := 0.0
var charging := false
var _last_switch_tick := -1000
var _switch_cycle: Array[int] = []
var last_assist_target := Vector2.ZERO
var last_assist_receiver := -1


func _init(sim_: MatchSim, team_: int) -> void:
	sim = sim_
	team = team_


func dispose() -> void:
	sim = null


func on_restart() -> void:
	charging = false
	shot_charge = 0.0
	if sim.restart_team == team and not sim.players[sim.restart_taker].is_keeper():
		_set_controlled(sim.restart_taker)
	elif controlled < 0:
		_set_controlled(sim.teams[team].player_ids[SimPlayer.Role.ST])


func _set_controlled(id: int) -> void:
	if id == controlled:
		return
	if controlled >= 0:
		sim.players[controlled].is_human = false
	controlled = id
	sim.players[id].is_human = true
	charging = false
	shot_charge = 0.0
	sim.emit(&"control", {"player": id})


func update() -> void:
	var b := sim.ball
	var tm: SimTeam = sim.teams[team]
	if controlled < 0:
		_set_controlled(tm.player_ids[SimPlayer.Role.ST])
	# Automatic handoff only follows the ball inside our own team.
	if b.owner >= 0 and tm.player_ids.has(b.owner) and b.owner != controlled and not sim.players[b.owner].is_keeper():
		_set_controlled(b.owner)
	elif b.in_pass and b.kicker >= 0 and sim.players[b.kicker].team == team and b.kick_tick == sim.tick - 1:
		var r := tm.ai.receiver_id
		if r < 0:
			r = b.kick_receiver
		if r >= 0 and r != controlled and tm.player_ids.has(r) and not sim.players[r].is_keeper():
			_set_controlled(r)
	var p: SimPlayer = sim.players[controlled]
	var has_ball := b.owner == p.id
	if input.switch_pressed and not has_ball and sim.state == MatchSim.State.PLAYING:
		_manual_switch()
		p = sim.players[controlled]
		has_ball = false

	var taker := sim.state == MatchSim.State.RESTART_READY and sim.restart_taker == p.id
	p.cmd.move = input.move.limit_length(1.0)
	p.cmd.sprint = input.sprint
	if sim.state != MatchSim.State.PLAYING and not taker:
		input.clear_edges()
		return
	if taker and input.move.length() > 0.2:
		p.cmd.face = input.move

	var can_play := has_ball or taker or (b.is_free() and p.pos.distance_to(b.pos) < 6.0)
	if input.tackle_pressed and not has_ball and not taker:
		p.cmd.tackle = true
	if can_play:
		if input.pass_pressed:
			p.cmd.kick = assist_pass(p, KickRequest.Kind.PASS)
		elif input.through_pressed:
			p.cmd.kick = assist_pass(p, KickRequest.Kind.THROUGH)
		elif input.lob_pressed:
			p.cmd.kick = assist_pass(p, KickRequest.Kind.LOB)
	# Shot: hold to charge, release to shoot.
	if input.shot_held and (has_ball or taker or charging or can_play):
		if not charging:
			charging = true
			shot_charge = 0.0
		shot_charge = minf(1.0, shot_charge + MatchSim.DT / sim.tn.shot_charge_time)
	if charging and (input.shot_released or not input.shot_held):
		charging = false
		if can_play:
			p.cmd.kick = _shot(p, shot_charge)
		shot_charge = 0.0
	input.clear_edges()


func _aim(p: SimPlayer) -> Vector2:
	return input.move.normalized() if input.move.length() > 0.25 else p.facing


## Choose a receiver in the aimed direction and plan the kick.
func assist_pass(p: SimPlayer, kind: int) -> KickRequest:
	var tm: SimTeam = sim.teams[team]
	var aim := _aim(p)
	var from := sim.ball.pos
	var throw_in := sim.state == MatchSim.State.RESTART_READY and sim.restart_type == MatchSim.Restart.THROW_IN
	var line := SimQuery.offside_line_local(sim, team)
	var best: SimPlayer = null
	var best_s := -INF
	for cone: float in [1.15, 1.75]:
		for id in tm.player_ids:
			if id == p.id:
				continue
			var m: SimPlayer = sim.players[id]
			var to := m.pos + m.vel * 0.3 - from
			var d := to.length()
			if d < 3.0:
				continue
			var ang := absf(aim.angle_to(to))
			if ang > cone:
				continue
			var s := -ang * 1.7
			match kind:
				KickRequest.Kind.PASS:
					if d > 42.0:
						continue
					s -= absf(d - 13.0) * 0.022
				KickRequest.Kind.THROUGH:
					if d > 50.0 or m.is_keeper():
						continue
					s -= absf(d - 20.0) * 0.012
					s += clampf(m.vel.dot(Vector2(tm.dir, 0.0)) / 8.0, -0.3, 0.6) * 0.5
					s += clampf((m.pos.x - p.pos.x) * tm.dir / 30.0, -0.5, 0.5) * 0.4
				_:
					if d < 14.0 or m.is_keeper():
						continue
					s -= absf(d - 32.0) * 0.008
			if throw_in and d > 24.0:
				continue
			var v0 := clampf(BallState.roll_speed_for(d, sim.tn.pass_arrive_speed, sim.tn.roll_decel), 8.0, sim.tn.pass_speed_max)
			if kind != KickRequest.Kind.LOB:
				var mg := KickPlanner.ground_margin(sim, from, m.pos, v0, 1 - team, sim.tn.intercept_react, 4)
				s += clampf(mg, -0.6, 0.4) * 0.6
			if m.pos.x * tm.dir > line + 0.2 and not sim.ball.dead:
				s -= 0.5
			if s > best_s:
				best_s = s
				best = m
		if best != null:
			break
	if best == null:
		# Nobody in that direction: play the ball into space where the player aims.
		last_assist_receiver = -1
		var tgt := Pitch.clamp_inside(from + aim * 16.0, 1.0)
		last_assist_target = tgt
		if kind == KickRequest.Kind.LOB:
			return KickPlanner._lob_launch(sim, from, Pitch.clamp_inside(from + aim * 30.0, 1.0), 1.9, KickRequest.Kind.LOB, -1)
		return KickRequest.make(kind, aim, 14.0, 0.0, -1, tgt)
	var plan := {}
	match kind:
		KickRequest.Kind.PASS:
			plan = KickPlanner.plan_ground(sim, p, best, sim.tn.throw_speed_max if throw_in else -1.0)
		KickRequest.Kind.THROUGH:
			plan = KickPlanner.plan_through(sim, p, best, aim)
			if plan.is_empty():
				plan = KickPlanner.plan_ground(sim, p, best)
		_:
			plan = KickPlanner.plan_lob(sim, p, best)
	last_assist_receiver = best.id
	last_assist_target = plan["target"]
	return plan["req"]


func _shot(p: SimPlayer, charge: float) -> KickRequest:
	var tm: SimTeam = sim.teams[team]
	var goal_x := Pitch.HALF_L * tm.dir
	var d := absf(goal_x - sim.ball.pos.x)
	var aim := _aim(p)
	if d > 45.0 or aim.x * tm.dir < -0.3:
		# Far from goal or aiming away: a plain driven kick where the player aims.
		var spd := lerpf(sim.tn.shot_speed_min, sim.tn.shot_speed_base, charge)
		return KickRequest.make(KickRequest.Kind.SHOT, aim, spd, lerpf(1.0, 9.0, charge), -1, sim.ball.pos + aim * 30.0)
	var aim_y := clampf(input.move.y, -1.0, 1.0) * (Pitch.GOAL_HALF_W - 0.6) if input.move.length() > 0.25 else clampf(sim.ball.pos.y * 0.15, -1.5, 1.5)
	# More charge = harder and higher; a full charge from close range flies over.
	var aim_h := lerpf(0.25, 2.2, pow(charge, 1.5)) + maxf(0.0, charge - 0.8) * 5.0
	return KickPlanner.plan_shot(sim, p, aim_y, aim_h, 0.25 + 0.75 * charge)


## E: pick the most useful defender/attacker for the current situation.
func _manual_switch() -> void:
	var tm: SimTeam = sim.teams[team]
	var b := sim.ball
	var goal := Vector2(-Pitch.HALF_L * tm.dir, 0.0)
	var focus := b.pos + b.vel * 0.4
	if sim.tick - _last_switch_tick > 90 or _switch_cycle.is_empty():
		var scored: Array = []
		for id in tm.player_ids:
			var m: SimPlayer = sim.players[id]
			if m.is_keeper():
				continue
			var t := SimQuery.time_to_reach(m, focus, sim.tn, 0.0, 1.0)
			var s := -t
			# Prefer players between the ball and our goal, and those in the direction of play.
			if m.pos.distance_to(goal) < focus.distance_to(goal):
				s += 0.5
			if input.move.length() > 0.3 and (m.pos - sim.players[controlled].pos).normalized().dot(input.move.normalized()) > 0.3:
				s += 0.25
			scored.append([s, id])
		scored.sort_custom(func(a: Array, c: Array) -> bool: return a[0] > c[0])
		_switch_cycle = []
		for e: Array in scored.slice(0, 4):
			_switch_cycle.append(e[1])
	_last_switch_tick = sim.tick
	var idx := _switch_cycle.find(controlled)
	var next := _switch_cycle[(idx + 1) % _switch_cycle.size()] if idx >= 0 else _switch_cycle[0]
	_set_controlled(next)
