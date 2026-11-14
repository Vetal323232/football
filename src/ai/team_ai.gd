class_name TeamAI
extends RefCounted
## Team coordinator. Decides the team phase, hands out non-conflicting duties
## (presser, cover, support, runner, ...) and drives every non-human player
## through PlayerCommand. See docs/DESIGN.md for the full description.

enum Phase { BUILD_UP, PROGRESSION, CHANCE_CREATION, ATTACK_TRANSITION, ORGANIZED_DEFENCE, DEFENSIVE_TRANSITION, SET_PIECE }
const PHASE_NAMES: Array[String] = ["BUILD_UP", "PROGRESSION", "CHANCE", "ATT_TRANS", "ORG_DEF", "DEF_TRANS", "SET_PIECE"]
const D := AIAgent.Duty
const R := SimPlayer.Role

var sim: MatchSim
var team: SimTeam
var tn: GameTuning
var tac: TeamTactics
var agents := {}
var keeper_id := -1
var now := 0.0

var phase := Phase.SET_PIECE
var attacking := false
var _pending_side := false
var _side_change_at := 0.0
var won_ball_t := -100.0
var lost_ball_t := -100.0
var focus := Vector2.ZERO
var carrier_id := -1
var receiver_id := -1
var chaser_id := -1
var presser_id := -1
var cover_id := -1
var off_line := 0.0
var our_eta := 0.0
var opp_eta := 0.0
var impatience := 0.0
var _progress_x := -100.0
var _progress_t := 0.0
var counter_on := false
var run_started_tick := -100

# Diagnostics.
var conflicts := 0
var decision_counts := {}
var phase_ticks: Array[int] = [0, 0, 0, 0, 0, 0, 0]
var _last_kick_id := -1
var _last_poss_tick := -1


func _init(sim_: MatchSim, team_: SimTeam) -> void:
	sim = sim_
	team = team_
	tn = sim.tn
	tac = team.tactics
	for id in team.player_ids:
		agents[id] = AIAgent.new()
		if sim.players[id].is_keeper():
			keeper_id = id


func opp_index() -> int:
	return 1 - team.index


func local(p: Vector2) -> Vector2:
	return p * team.dir


func world(p: Vector2) -> Vector2:
	return p * team.dir


func own_goal() -> Vector2:
	return Vector2(-Pitch.HALF_L * team.dir, 0.0)


func on_restart() -> void:
	attacking = sim.restart_team == team.index
	_pending_side = attacking
	presser_id = -1
	cover_id = -1
	impatience = 0.0
	_progress_x = -100.0
	_progress_t = sim.tick * MatchSim.DT
	for id in agents:
		var ag: AIAgent = agents[id]
		ag.run_state = 0
		ag.engage = false
		ag.next_decision = 0.0
		ag.commit_until = 0.0
		ag.in_reach_since = -1.0
		ag.next_refresh = 0.0
		ag.target_score = -INF


# ------------------------------------------------------------------ restarts

func pick_restart_taker(type: int, spot: Vector2) -> int:
	var ls := local(spot)
	var ids := team.player_ids
	match type:
		MatchSim.Restart.KICKOFF:
			return ids[R.ST]
		MatchSim.Restart.GOAL_KICK:
			return ids[R.GK]
		MatchSim.Restart.CORNER:
			return ids[R.LW] if ls.y < 0.0 else ids[R.RW]
		MatchSim.Restart.THROW_IN:
			if ls.x < 5.0:
				return ids[R.LB] if ls.y < 0.0 else ids[R.RB]
			var a: SimPlayer = sim.players[ids[R.LB] if ls.y < 0.0 else ids[R.RB]]
			var b: SimPlayer = sim.players[ids[R.LW] if ls.y < 0.0 else ids[R.RW]]
			return a.id if a.pos.distance_to(spot) < b.pos.distance_to(spot) + 6.0 else b.id
	# Free kick.
	if ls.x < -Pitch.HALF_L + Pitch.PEN_DEPTH + 2.0 and absf(ls.y) < Pitch.PEN_HALF_W:
		return ids[R.GK]
	var best := ids[R.DM]
	var bd := INF
	for role: int in [R.LB, R.LCB, R.RCB, R.RB, R.DM, R.LCM, R.RCM]:
		var d: float = sim.players[ids[role]].pos.distance_to(spot)
		if d < bd:
			bd = d
			best = ids[role]
	return best


func restart_positions(type: int, taking_team: int, spot: Vector2, taker: int) -> Dictionary:
	var out := {}
	var taking := taking_team == team.index
	var ls := local(spot)
	var opp_line := SimQuery.offside_line_local(sim, team.index)
	for id in team.player_ids:
		var p: SimPlayer = sim.players[id]
		var lp := Vector2.ZERO
		match type:
			MatchSim.Restart.KICKOFF:
				lp = AIShape.kickoff_pos(p.role, taking)
			MatchSim.Restart.CORNER:
				lp = AIShape.corner_attack_pos(p.role, signf(ls.y)) if taking else AIShape.corner_defend_pos(p.role, signf(ls.y))
			MatchSim.Restart.GOAL_KICK:
				if taking:
					lp = AIShape.goal_kick_pos(p.role)
				else:
					lp = AIShape.defend_anchor(p.role, Vector2(20.0, 0.0), tac)
			_:
				if taking:
					lp = AIShape.attack_anchor(p.role, ls, tac, 60.0 if type == MatchSim.Restart.THROW_IN else minf(opp_line, ls.x + 30.0))
					if p.role == R.GK:
						lp = Vector2(clampf(ls.x - 40.0, -49.0, -36.0), 0.0)
				else:
					lp = AIShape.defend_anchor(p.role, ls, tac)
		out[id] = world(lp)
	if taking and (type == MatchSim.Restart.THROW_IN or type == MatchSim.Restart.FREE_KICK):
		# Guarantee one short option next to the taker.
		var near: SimPlayer = null
		var bd := INF
		for id in team.player_ids:
			if id == taker or sim.players[id].is_keeper():
				continue
			var d: float = (out[id] as Vector2).distance_to(spot)
			if d < bd:
				bd = d
				near = sim.players[id]
		if near != null and bd > 11.0:
			var inward := Vector2(0.35, -signf(ls.y) if absf(ls.y) > 20.0 else 0.6).normalized()
			out[near.id] = Pitch.clamp_inside(world(ls + inward * 8.5), 1.5)
	return out


# -------------------------------------------------------------------- update

func update() -> void:
	now = sim.tick * MatchSim.DT
	if sim.state == MatchSim.State.RESTART_SETUP:
		return
	var dirty := false
	if sim.ball.kick_id != _last_kick_id or sim.poss_change_tick != _last_poss_tick:
		_last_kick_id = sim.ball.kick_id
		_last_poss_tick = sim.poss_change_tick
		dirty = true
	if dirty or (sim.tick + team.index * 3) % tn.team_update_ticks == 0:
		_replan()
	phase_ticks[phase] += 1
	for id in team.player_ids:
		var p: SimPlayer = sim.players[id]
		if p.is_human:
			# An idle human taker must not block the match: after the limit the AI takes the restart.
			if sim.state == MatchSim.State.RESTART_READY and id == sim.restart_taker and sim.restart_ready_t > tn.restart_force_time_human:
				OnBallAI.drive_restart(self, p, agents[id])
			continue
		_drive(p, agents[id])


func _replan() -> void:
	off_line = SimQuery.offside_line_local(sim, team.index)
	carrier_id = -1
	receiver_id = -1
	chaser_id = -1
	_ball_claims()
	_update_side()
	if attacking:
		_plan_attack()
	else:
		_plan_defend()
	(agents[keeper_id] as AIAgent).set_duty(D.GK, now, "keeper")
	if sim.ball.owner == keeper_id or sim.ball.held_by == keeper_id:
		carrier_id = keeper_id
	_count_conflicts()


func _update_side() -> void:
	var b := sim.ball
	var raw := attacking
	if b.dead:
		raw = sim.restart_team == team.index
		attacking = raw
		_pending_side = raw
		return
	if b.held_by >= 0:
		raw = sim.players[b.held_by].team == team.index
	elif b.owner >= 0:
		raw = sim.players[b.owner].team == team.index
	elif b.in_pass and b.kicker >= 0:
		raw = sim.players[b.kicker].team == team.index
		# A pass that the opponent will clearly reach first is as good as lost.
		if raw and opp_eta < our_eta - 0.6:
			raw = false
		elif not raw and our_eta < opp_eta - 0.6:
			raw = true
	else:
		if attacking:
			raw = our_eta <= opp_eta + 0.25
		else:
			raw = our_eta < opp_eta - 0.25
	if raw == attacking:
		_pending_side = raw
		return
	if _pending_side != raw:
		_pending_side = raw
		_side_change_at = now + tac.reaction_time
	if now >= _side_change_at:
		attacking = raw
		if attacking:
			won_ball_t = now
			_progress_x = -100.0
			_progress_t = now
			impatience = 0.0
			counter_on = _counter_chance()
		else:
			lost_ball_t = now
			counter_on = false
		for id in agents:
			(agents[id] as AIAgent).next_refresh = 0.0


func _counter_chance() -> bool:
	# Few opponents between the ball and their goal, and we have runners.
	var bl := local(sim.ball.pos)
	if bl.x < -35.0:
		return false
	var behind := 0
	for id in sim.teams[opp_index()].player_ids:
		var o: SimPlayer = sim.players[id]
		if not o.is_keeper() and local(o.pos).x > bl.x + 2.0:
			behind += 1
	var ours := 0
	for id in team.player_ids:
		if local(sim.players[id].pos).x > bl.x - 8.0:
			ours += 1
	return behind <= 5 and ours >= 2 and ours + 1 >= behind


## Earliest feasible interception of the predicted ball path. Returns (x, y, t).
func intercept(p: SimPlayer, path: PackedVector3Array) -> Vector3:
	var maxh := 1.0
	if p.is_keeper() and Pitch.in_pen_area(p.pos, -team.dir if p.team == team.index else team.dir):
		maxh = 2.3
	var n := path.size()
	var last_ok := 0
	for i in n:
		var pt := path[i]
		if absf(pt.x) > Pitch.HALF_L + 0.3 or absf(pt.y) > Pitch.HALF_W + 0.3:
			break
		last_ok = i
		if pt.z > maxh:
			continue
		var t := float(i) * 0.1
		if SimQuery.time_to_reach(p, Vector2(pt.x, pt.y), tn, 0.08, 0.7) <= t:
			return Vector3(pt.x, pt.y, t)
	var lp := path[last_ok]
	var tt := SimQuery.time_to_reach(p, Vector2(lp.x, lp.y), tn, 0.08, 0.7)
	if last_ok < n - 1:
		tt += 5.0  # ball leaves the pitch before he can get there
	return Vector3(lp.x, lp.y, maxf(tt, float(last_ok) * 0.1))


func _ball_claims() -> void:
	var b := sim.ball
	our_eta = 0.0
	opp_eta = 0.0
	if not b.is_free():
		return
	var path := sim.ball_path()
	var best_id := -1
	var best := Vector3(0, 0, INF)
	var intended := Vector3(0, 0, INF)
	for id in team.player_ids:
		var p: SimPlayer = sim.players[id]
		if b.restart_taker == id or (b.in_pass and b.kicker == id and now - b.kick_tick * MatchSim.DT < 0.8):
			continue
		if p.is_keeper() and not _keeper_may_chase(p, path):
			continue
		var r := intercept(p, path)
		(agents[id] as AIAgent).intercept = Vector2(r.x, r.y)
		(agents[id] as AIAgent).intercept_t = r.z
		if id == b.kick_receiver:
			intended = r
		if r.z < best.z:
			best = r
			best_id = id
	our_eta = best.z
	opp_eta = INF
	for id in sim.teams[opp_index()].player_ids:
		var o: SimPlayer = sim.players[id]
		if b.restart_taker == id or (b.in_pass and b.kicker == id):
			continue
		var r2 := intercept(o, path)
		if r2.z < opp_eta:
			opp_eta = r2.z
	if best_id < 0:
		return
	var ours_pass := b.in_pass and b.kicker >= 0 and sim.players[b.kicker].team == team.index
	if ours_pass:
		receiver_id = best_id
		if b.kick_receiver >= 0 and team.player_ids.has(b.kick_receiver) and intended.z <= best.z + 0.5:
			receiver_id = b.kick_receiver
	else:
		var theirs_pass := b.in_pass and b.kicker >= 0
		if theirs_pass:
			# Defenders need a reaction time to read an opponent's pass.
			if now - b.kick_tick * MatchSim.DT >= tac.reaction_time and (our_eta < opp_eta - 0.05 or our_eta < 0.6):
				chaser_id = best_id
		else:
			chaser_id = best_id


func _keeper_may_chase(p: SimPlayer, path: PackedVector3Array) -> bool:
	# The keeper only goes for balls he can meet inside (or just outside) his area.
	var r := intercept(p, path)
	var lp := local(Vector2(r.x, r.y))
	return lp.x < -Pitch.HALF_L + Pitch.PEN_DEPTH + 1.5 and absf(lp.y) < Pitch.PEN_HALF_W


# -------------------------------------------------------------------- attack

func _plan_attack() -> void:
	var b := sim.ball
	if b.held_by >= 0 and team.player_ids.has(b.held_by):
		carrier_id = b.held_by
		focus = sim.players[b.held_by].pos
	elif b.owner >= 0 and team.player_ids.has(b.owner):
		carrier_id = b.owner
		focus = sim.players[b.owner].pos
	elif receiver_id >= 0:
		focus = (agents[receiver_id] as AIAgent).intercept
	elif chaser_id >= 0:
		focus = (agents[chaser_id] as AIAgent).intercept
	else:
		focus = b.pos
	var fl := local(focus)

	if sim.state != MatchSim.State.PLAYING:
		phase = Phase.SET_PIECE
	elif counter_on and now - won_ball_t < 6.0:
		phase = Phase.ATTACK_TRANSITION
	elif fl.x < -17.5:
		phase = Phase.BUILD_UP
	elif fl.x < 17.5:
		phase = Phase.PROGRESSION
	else:
		phase = Phase.CHANCE_CREATION

	# Stagnation -> impatience (dead-end detection).
	if fl.x > _progress_x + 4.0:
		_progress_x = fl.x
		_progress_t = now
	impatience = clampf((now - _progress_t - 2.0) / 5.0, 0.0, 1.0)

	var bs := signf(fl.y) if absf(fl.y) > 4.0 else 0.0
	var carrier_role := -1
	var cid := carrier_id if carrier_id >= 0 else receiver_id
	if cid >= 0:
		carrier_role = sim.players[cid].role
	var final_third := fl.x > 17.5
	var wide_ball := absf(fl.y) > 13.0
	var taken: Array[Vector2] = [focus]
	var order: Array[int] = [R.ST, R.LW, R.RW, R.LCM, R.RCM, R.DM, R.LB, R.RB, R.LCB, R.RCB]
	var rest_count := 0
	for role in order:
		var id := team.player_ids[role]
		var p: SimPlayer = sim.players[id]
		var ag: AIAgent = agents[id]
		ag.anchor = world(AIShape.attack_anchor(role, fl, tac, off_line))
		ag.mark_id = -1
		if id == carrier_id:
			ag.set_duty(D.CARRIER, now, "has ball")
			continue
		if id == receiver_id:
			ag.set_duty(D.RECEIVER, now, "pass incoming")
			continue
		if id == chaser_id:
			ag.set_duty(D.CHASE, now, "nearest to loose ball")
			continue
		var s := AIShape.side_of(role)
		var on_ball_side := bs != 0.0 and s == bs
		var duty := D.SHAPE
		var why := ""
		match role:
			R.ST:
				if final_third and wide_ball:
					duty = D.FINISHER
					why = "near post"
				elif carrier_role == R.LCM or carrier_role == R.RCM or carrier_role == R.DM:
					duty = D.RUNNER
					why = "run behind (mid has ball)"
				elif fl.x < -5.0 and phase != Phase.ATTACK_TRANSITION:
					duty = D.SUPPORT
					why = "drop to link"
				else:
					duty = D.RUNNER
					why = "stretch depth"
			R.LW, R.RW:
				if final_third and not on_ball_side and (wide_ball or carrier_role == R.ST):
					duty = D.FINISHER
					why = "far post"
				elif phase == Phase.ATTACK_TRANSITION or (carrier_role == R.ST and fl.x > -5.0):
					duty = D.RUNNER
					why = "run off the striker"
				else:
					duty = D.WIDTH
					why = "hold width"
			R.LCM, R.RCM:
				if final_third and not on_ball_side and wide_ball:
					duty = D.FINISHER
					why = "edge of box"
				else:
					duty = D.SUPPORT
					why = "close support" if on_ball_side or bs == 0.0 else "far support"
			R.DM:
				duty = D.OUTLET
				why = "outlet behind ball"
			R.LB, R.RB:
				if on_ball_side or bs == 0.0:
					duty = D.SUPPORT if fl.x > -17.5 else D.OUTLET
					why = "wide support"
				else:
					duty = D.REST
					why = "rest defence (far side)"
			R.LCB, R.RCB:
				if fl.x - local(p.pos).x < 28.0:
					duty = D.OUTLET
					why = "deep outlet"
				else:
					duty = D.REST
					why = "rest defence"
		if duty == D.REST or (duty == D.OUTLET and role != R.LB and role != R.RB):
			rest_count += 1
		ag.set_duty(duty, now, why)

	# Rest defence: at least three outfield players stay behind the ball.
	if rest_count < 3 and sim.state == MatchSim.State.PLAYING:
		for role: int in [R.LB, R.RB, R.DM, R.LCM, R.RCM]:
			if rest_count >= 3:
				break
			var id2 := team.player_ids[role]
			var ag2: AIAgent = agents[id2]
			if ag2.duty == D.SUPPORT or ag2.duty == D.WIDTH:
				if bs != 0.0 and AIShape.side_of(role) == bs and (role == R.LB or role == R.RB):
					continue
				ag2.set_duty(D.REST, now, "compensate rest defence")
				ag2.anchor = world(Vector2(clampf(fl.x - 16.0, -38.0, 5.0), AIShape.side_of(role) * 8.0))
				rest_count += 1

	# Targets.
	for role in order:
		var id3 := team.player_ids[role]
		var ag3: AIAgent = agents[id3]
		var p3: SimPlayer = sim.players[id3]
		if ag3.duty == D.CARRIER or ag3.duty == D.RECEIVER or ag3.duty == D.CHASE:
			taken.append(p3.pos)
			continue
		if now >= ag3.next_refresh:
			ag3.next_refresh = now + tn.position_refresh_time + 0.02 * float(role)
			_refresh_attack_target(p3, ag3, fl, bs, taken)
		taken.append(ag3.target)
		ag3.sprint = (phase == Phase.ATTACK_TRANSITION and ag3.duty != D.REST and ag3.duty != D.OUTLET) \
			or (ag3.duty == D.FINISHER and p3.pos.distance_to(ag3.target) > 3.0)
		ag3.face_ball = false


func _finisher_spot(role: int, bs: float) -> Vector2:
	var b := bs if bs != 0.0 else 1.0
	match role:
		R.ST:
			return Vector2(46.5, b * 3.2)
		R.LW, R.RW:
			return Vector2(45.5, -b * 4.8)
	return Vector2(35.0, -b * 5.0)


func _refresh_attack_target(p: SimPlayer, ag: AIAgent, fl: Vector2, bs: float, taken: Array[Vector2]) -> void:
	var al := local(ag.anchor)
	var cands: Array[Vector2] = []
	var onside_x := maxf(off_line - 0.8, fl.x)
	match ag.duty:
		D.REST, D.SHAPE:
			ag.target = ag.anchor
			ag.target_score = 0.0
			return
		D.FINISHER:
			var z := _finisher_spot(p.role, bs)
			cands = [z, z + Vector2(-2.5, 0), z + Vector2(0, 2.5), z + Vector2(0, -2.5), z + Vector2(-2.5, 2.5), z + Vector2(-2.5, -2.5)]
		D.RUNNER:
			var hx := clampf(minf(off_line - 4.5, 46.0), fl.x + 5.0, 47.0)
			hx = minf(hx, onside_x)
			for dy: float in [0.0, -5.0, 5.0, -10.0, 10.0]:
				cands.append(Vector2(hx, clampf(al.y + dy, -24.0, 24.0)))
		D.SUPPORT:
			cands = [al]
			for dist: float in [9.0, 13.0]:
				for deg: float in [35.0, -35.0, 80.0, -80.0, 125.0, -125.0]:
					var c := fl + Vector2(dist, 0.0).rotated(deg_to_rad(deg))
					if c.distance_to(al) < 15.0:
						cands.append(c)
		D.OUTLET:
			cands = [al, al + Vector2(0, 5), al + Vector2(0, -5), al + Vector2(-4, 0), al + Vector2(4, 4), al + Vector2(4, -4)]
		_:
			cands = [al, al + Vector2(5, 0), al + Vector2(-5, 0), al + Vector2(0, -4.0 * signf(al.y)), al + Vector2(5, -4.0 * signf(al.y))]
	var cur_l := local(ag.target)
	var best := al
	var best_s := -INF
	var cur_s := -INF
	var have_cur := ag.target_score > -INF
	if have_cur:
		cands.append(cur_l)
	for i in cands.size():
		var c := cands[i]
		c.x = clampf(c.x, -Pitch.HALF_L + 3.0, Pitch.HALF_L - 2.5)
		c.y = clampf(c.y, -Pitch.HALF_W + 2.0, Pitch.HALF_W - 2.0)
		if ag.duty != D.OUTLET:
			c.x = minf(c.x, onside_x)
		var sc := _score_spot(p, ag, c, fl, al, taken)
		if have_cur and i == cands.size() - 1:
			cur_s = sc
		if sc > best_s:
			best_s = sc
			best = c
	if have_cur and best_s < cur_s + tn.position_switch_margin:
		best = cur_l
		best.x = clampf(best.x, -Pitch.HALF_L + 3.0, Pitch.HALF_L - 2.5)
		if ag.duty != D.OUTLET:
			best.x = minf(best.x, onside_x)
		best_s = cur_s
	ag.target = world(best)
	ag.target_score = best_s


func _score_spot(p: SimPlayer, ag: AIAgent, c: Vector2, fl: Vector2, al: Vector2, taken: Array[Vector2]) -> float:
	var cw := world(c)
	var fw := world(fl)
	var d := c.distance_to(fl)
	var v0 := clampf(BallState.roll_speed_for(d, tn.pass_arrive_speed, tn.roll_decel), 8.0, tn.pass_speed_max)
	var m := KickPlanner.ground_margin(sim, fw, cw, v0, opp_index(), tn.intercept_react, 4, null, 0.85)
	var lane := FieldValue.sigmoid((m - 0.1) / 0.25)
	var space := minf(SimQuery.nearest_opponent_dist(sim, cw, opp_index()), 8.0) / 8.0
	var val := FieldValue.value(c, tn)
	var crowd := 0.0
	for t in taken:
		var dt := t.distance_to(cw)
		if dt < tn.crowd_radius:
			crowd += 1.0 - dt / tn.crowd_radius
	var anchor_d := c.distance_to(al)
	var travel := p.pos.distance_to(cw)
	var s := 0.0
	match ag.duty:
		D.SUPPORT:
			s = 0.55 * lane + 0.2 * space + 2.5 * val + 0.012 * clampf(c.x - fl.x, -10.0, 12.0)
			if d < tn.support_dist_min:
				s -= 0.08 * (tn.support_dist_min - d)
			elif d > tn.support_dist_max:
				s -= 0.03 * (d - tn.support_dist_max)
			s -= 0.012 * anchor_d
		D.OUTLET:
			s = 0.65 * lane + 0.25 * space - 0.02 * anchor_d
			if c.x > fl.x - 3.0:
				s -= 0.25
		D.WIDTH:
			s = 0.3 * lane + 0.3 * space + 3.0 * val - 0.03 * anchor_d
		D.FINISHER:
			s = 0.3 * lane + 0.45 * minf(space * 2.0, 1.0) + 1.6 * FieldValue.xg_pos(c) - 0.04 * anchor_d
		D.RUNNER:
			s = 0.35 * lane + 0.5 * space + 0.9 * FieldValue.xg_pos(c + Vector2(12.0, 0.0)) - 0.015 * anchor_d
	s -= 0.6 * crowd
	s -= 0.004 * travel
	return s


# ------------------------------------------------------------------- defence

func _plan_defend() -> void:
	var b := sim.ball
	var opp: SimTeam = sim.teams[opp_index()]
	var carrier: SimPlayer = null
	if b.owner >= 0 and opp.player_ids.has(b.owner):
		carrier = sim.players[b.owner]
	elif b.held_by >= 0:
		carrier = sim.players[b.held_by]
	var press_point := b.pos
	if carrier != null:
		press_point = carrier.pos + carrier.vel * 0.35
	elif b.in_pass and b.kicker >= 0 and opp.player_ids.has(b.kicker):
		press_point = b.kick_target
		if b.kick_receiver >= 0:
			carrier = sim.players[b.kick_receiver]
	focus = b.pos if carrier == null or b.in_pass else carrier.pos
	var bl := local(focus)
	if b.in_pass:
		bl = bl.lerp(local(press_point), 0.5)
	if sim.state != MatchSim.State.PLAYING:
		phase = Phase.SET_PIECE
	elif now - lost_ball_t < 4.0:
		phase = Phase.DEFENSIVE_TRANSITION
	else:
		phase = Phase.ORGANIZED_DEFENCE
	var transition := phase == Phase.DEFENSIVE_TRANSITION
	var goal := own_goal()
	var pp_goal_dist := press_point.distance_to(goal)
	var keeper_has := b.held_by >= 0

	for id in team.player_ids:
		var ag: AIAgent = agents[id]
		ag.anchor = world(AIShape.defend_anchor(sim.players[id].role, bl, tac))

	# --- primary presser -------------------------------------------------
	var new_presser := -1
	if chaser_id >= 0:
		new_presser = chaser_id
	elif not keeper_has and sim.state == MatchSim.State.PLAYING:
		var best_cost := INF
		var human_cost := INF
		var human_id := -1
		for id in team.player_ids:
			var p: SimPlayer = sim.players[id]
			if p.is_keeper():
				continue
			var cost := SimQuery.time_to_reach(p, press_point, tn, 0.0, 1.5)
			if p.is_human:
				human_cost = cost
				human_id = id
				continue
			var goal_side := p.pos.distance_to(goal) < pp_goal_dist + 1.0
			if not goal_side:
				cost += 0.35
			if (p.role == R.LCB or p.role == R.RCB) and pp_goal_dist > 30.0:
				cost += 0.8
			if p.role == R.ST and local(press_point).x < -10.0:
				cost += 1.0
			if p.stamina < 0.25:
				cost += 0.3
			if id == presser_id:
				cost -= tn.press_switch_margin
				if now - (agents[id] as AIAgent).duty_since < tn.press_min_commit:
					cost -= 0.5
			if cost < best_cost:
				best_cost = cost
				new_presser = id
		if human_id >= 0 and human_cost <= best_cost + 0.5:
			new_presser = human_id
	presser_id = new_presser

	# --- cover defender --------------------------------------------------
	var to_goal := (goal - press_point)
	var tg_len := maxf(to_goal.length(), 0.01)
	var cover_d := tn.cover_dist if pp_goal_dist > 24.0 else 3.2
	var cover_point := press_point + to_goal / tg_len * minf(cover_d, tg_len * 0.6)
	cover_point.y *= 0.92
	var new_cover := -1
	if presser_id >= 0 and not keeper_has and sim.state == MatchSim.State.PLAYING:
		var bc := INF
		for id in team.player_ids:
			var p: SimPlayer = sim.players[id]
			if id == presser_id or p.is_keeper() or p.is_human or p.role == R.ST:
				continue
			var c := p.pos.distance_to(cover_point) + (agents[id] as AIAgent).anchor.distance_to(cover_point) * 0.5
			if id == cover_id:
				c -= 3.0
			if c < bc:
				bc = c
				new_cover = id
	cover_id = new_cover

	# --- marking: zone owners pick up threats in their area ------------------
	var def_line := AIShape.defence_line_x(bl, tac)
	var threats: Array[SimPlayer] = []
	for id in opp.player_ids:
		var o: SimPlayer = sim.players[id]
		if o.is_keeper() or (carrier != null and o.id == carrier.id):
			continue
		if local(o.pos).x < def_line + 24.0:
			threats.append(o)
	threats.sort_custom(func(a: SimPlayer, c: SimPlayer) -> bool: return a.pos.distance_squared_to(goal) < c.pos.distance_squared_to(goal))
	var marked_by := {}
	var used := {}
	for o in threats:
		var best_id := -1
		var best_c := 11.0
		for id in team.player_ids:
			if used.has(id) or id == presser_id or id == cover_id:
				continue
			var p: SimPlayer = sim.players[id]
			if p.is_keeper() or p.is_human or p.role == R.ST:
				continue
			var ag: AIAgent = agents[id]
			var c := ag.anchor.distance_to(o.pos)
			if ag.mark_id == o.id:
				c -= 4.0
			if c < best_c:
				best_c = c
				best_id = id
		if best_id >= 0:
			used[best_id] = true
			marked_by[best_id] = o.id

	# --- duties and targets -------------------------------------------------
	for id in team.player_ids:
		var p: SimPlayer = sim.players[id]
		var ag: AIAgent = agents[id]
		if p.is_keeper():
			continue
		ag.face_ball = true
		var far := p.pos.distance_to(ag.anchor)
		ag.sprint = transition and far > 7.0
		if id == chaser_id:
			ag.set_duty(D.CHASE, now, "can win loose ball / intercept")
			ag.mark_id = -1
		elif id == presser_id:
			ag.set_duty(D.PRESS, now, "nearest goal-side to ball")
			ag.mark_id = -1
			_update_engage(p, ag, carrier, pp_goal_dist, transition)
		elif id == cover_id:
			ag.set_duty(D.COVER, now, "cover behind presser")
			ag.mark_id = -1
			ag.target = cover_point
			ag.sprint = p.pos.distance_to(cover_point) > 8.0
		elif marked_by.has(id):
			ag.mark_id = marked_by[id]
			ag.set_duty(D.MARK, now, "mark %d in zone" % sim.players[ag.mark_id].number)
		else:
			ag.mark_id = -1
			if p.role == R.DM:
				ag.set_duty(D.PROTECT, now, "protect centre")
			else:
				ag.set_duty(D.ZONE, now, "hold zone")
			ag.target = ag.anchor


func _update_engage(p: SimPlayer, ag: AIAgent, carrier: SimPlayer, goal_dist: float, transition: bool) -> void:
	if carrier == null or sim.ball.owner != carrier.id:
		ag.engage = true
		return
	if now < ag.engage_until:
		return
	var opp: SimTeam = sim.teams[opp_index()]
	var score := tac.pressing * 0.9
	var why := ""
	if carrier.pos.distance_to(sim.ball.pos) > 0.9:
		score += 0.6
		why = "loose touch"
	if carrier.has_ball_time < 0.6:
		score += 0.35
		why += " just received"
	if carrier.facing.dot(Vector2(opp.dir, 0.0)) < -0.2:
		score += 0.35
		why += " facing own goal"
	if absf(carrier.pos.y) > Pitch.HALF_W - 6.0:
		score += 0.3
		why += " touchline"
	if goal_dist < 27.0:
		score += 0.8
		why += " danger zone"
	if cover_id >= 0 and sim.players[cover_id].pos.distance_to(carrier.pos) < 11.0:
		score += 0.3
		why += " cover set"
	if transition:
		# Counter-press only with support nearby, otherwise delay.
		var near := 0
		for id in team.player_ids:
			if id != p.id and sim.players[id].pos.distance_to(carrier.pos) < 11.0:
				near += 1
		score += 0.4 if near >= 2 else -0.5
		why += " counterpress" if near >= 2 else " delay"
	if local(carrier.pos).x > lerpf(5.0, 35.0, tac.pressing) and score < 1.3:
		score -= 0.5
	var was := ag.engage
	ag.engage = score >= 1.0
	if ag.engage != was:
		ag.engage_until = now + 0.5
	ag.reason = ("engage:" if ag.engage else "contain:") + why


func _count_conflicts() -> void:
	var press := 0
	var cover := 0
	for id in agents:
		var ag: AIAgent = agents[id]
		if ag.duty == D.PRESS:
			press += 1
		elif ag.duty == D.COVER:
			cover += 1
	if press > 1 or cover > 1:
		conflicts += 1


# --------------------------------------------------------------------- drive

func _drive(p: SimPlayer, ag: AIAgent) -> void:
	var b := sim.ball
	if p.is_keeper():
		KeeperAI.drive(self, p, ag)
		return
	if sim.state == MatchSim.State.RESTART_READY:
		if p.id == sim.restart_taker:
			OnBallAI.drive_restart(self, p, ag)
			return
		_go(p, ag.target if ag.duty != D.NONE else ag.anchor, false)
		p.cmd.face = b.pos - p.pos
		return
	if b.owner == p.id:
		OnBallAI.drive(self, p, ag)
		return
	match ag.duty:
		D.CARRIER:
			# Ball just left his feet: stay with it until the next replan.
			_go(p, b.pos, true)
		D.RECEIVER, D.CHASE:
			_drive_chase(p, ag)
		D.PRESS:
			_drive_press(p, ag)
		D.MARK:
			_drive_mark(p, ag)
		D.RUNNER, D.WIDTH:
			_drive_runner(p, ag)
		_:
			var d := p.pos.distance_to(ag.target)
			_go(p, ag.target, ag.sprint or d > 16.0)
			if ag.face_ball and d < 3.0:
				p.cmd.face = b.pos - p.pos
	# Opportunistic tackle by any defender the carrier runs into.
	if not attacking and ag.duty != D.PRESS and b.owner >= 0 and sim.players[b.owner].team != team.index:
		_maybe_tackle(p, ag, false)


func _go(p: SimPlayer, target: Vector2, sprint: bool, slow_radius := 2.5) -> void:
	var to := target - p.pos
	var d := to.length()
	if d < 0.35:
		p.cmd.move = Vector2.ZERO
		return
	p.cmd.move = to / d * clampf(d / slow_radius, 0.3, 1.0)
	p.cmd.sprint = sprint and d > 3.5 and p.stamina > 0.15


func _drive_chase(p: SimPlayer, ag: AIAgent) -> void:
	var b := sim.ball
	if not b.is_free():
		_go(p, b.pos, true)
		return
	if (sim.tick + p.id) % 4 == 0:
		var r := intercept(p, sim.ball_path())
		ag.intercept = Vector2(r.x, r.y)
		ag.intercept_t = r.z
	var tgt := ag.intercept
	var d_ball := p.pos.distance_to(b.pos)
	if d_ball < 2.2 and b.h < 1.0:
		tgt = b.pos + b.vel * 0.1
	# One-touch finish: a receiver in a scoring position shoots first time.
	if attacking and b.in_pass and d_ball < 4.0 and b.vel.length() > 2.0:
		var lp := local(p.pos)
		if lp.x > 34.0 and FieldValue.xg_pos(lp) > 0.09 and d_ball / maxf(b.vel.length(), 1.0) < 0.3:
			p.cmd.kick = KickPlanner.plan_ai_shot(sim, p)
			ag.decision_label = "first-time shot"
	# Do not sprint through a ball that is arriving at his feet anyway.
	var d := p.pos.distance_to(tgt)
	if d < 0.5 and b.vel.length() > 3.0:
		p.cmd.move = Vector2.ZERO
		p.cmd.face = b.pos - p.pos
		return
	_go(p, tgt, true, 1.2)


func _drive_press(p: SimPlayer, ag: AIAgent) -> void:
	var b := sim.ball
	var goal := own_goal()
	var carrier: SimPlayer = null
	if b.owner >= 0 and sim.players[b.owner].team != team.index:
		carrier = sim.players[b.owner]
	if carrier == null:
		if b.is_free() and not b.in_pass:
			_drive_chase(p, ag)
			return
		# Pass in flight: close down the receiving point from the goal side.
		var rp := b.kick_target if b.in_pass else b.pos
		var gd := (goal - rp).normalized()
		_go(p, rp + gd * 1.6, true)
		return
	var d := p.pos.distance_to(b.pos)
	var lead := carrier.pos + carrier.vel * clampf(d / 9.0, 0.0, 0.7)
	var goal_dir := (goal - lead).normalized()
	var my_goal_d := p.pos.distance_to(goal)
	var goal_side := my_goal_d < carrier.pos.distance_to(goal) + 0.3
	if not goal_side:
		# Recovery run: get back between the ball and the goal.
		_go(p, lead + goal_dir * 2.2, true)
		_maybe_tackle(p, ag, true)
		return
	if ag.engage:
		_go(p, b.pos + carrier.vel * 0.12, d > 2.5, 0.8)
		_maybe_tackle(p, ag, true)
	else:
		var hold := lead + goal_dir * tn.contain_dist
		_go(p, hold, p.pos.distance_to(hold) > 4.0, 1.5)
		p.cmd.face = b.pos - p.pos
		_maybe_tackle(p, ag, false)


## Tackle only when the ball is physically within reach, after a short reaction.
func _maybe_tackle(p: SimPlayer, ag: AIAgent, committed: bool) -> void:
	var b := sim.ball
	if b.owner < 0 or b.h > 0.5 or not p.can_act() or p.tackle_cd > 0.0:
		ag.in_reach_since = -1.0
		return
	var carrier: SimPlayer = sim.players[b.owner]
	var to_ball := b.pos - p.pos
	var d := to_ball.length()
	var reach := tn.tackle_reach + 0.45
	if d > reach:
		ag.in_reach_since = -1.0
		return
	# From behind the chance is poor: only try when the ball is exposed.
	var exposed := carrier.pos.distance_to(b.pos) > 0.85
	var away := carrier.pos - p.pos
	var behind := away.length() > 0.01 and carrier.facing.dot(away.normalized()) > 0.45
	if behind and not exposed:
		return
	if not committed and not exposed and d > 1.1:
		return
	if ag.in_reach_since < 0.0:
		ag.in_reach_since = now
	if now - ag.in_reach_since >= tac.reaction_time * 0.6 and now >= ag.tackle_ready:
		p.cmd.tackle = true
		ag.tackle_ready = now + 1.0
		ag.in_reach_since = -1.0


func _drive_mark(p: SimPlayer, ag: AIAgent) -> void:
	if ag.mark_id < 0:
		_go(p, ag.anchor, false)
		return
	var b := sim.ball
	var t: SimPlayer = sim.players[ag.mark_id]
	var goal := own_goal()
	var gd := (goal - t.pos)
	var gl := maxf(gd.length(), 0.01)
	var d_ball := b.pos.distance_to(t.pos)
	var off := clampf(1.0 + d_ball * 0.07, 1.3, 4.0)
	var ball_side := (b.pos - t.pos).normalized() * 0.6
	var mp := t.pos + gd / gl * minf(off, gl * 0.5) + ball_side + t.vel * 0.35
	var is_back := p.role <= R.RB
	var tight := tn.mark_tightness_def if (is_back or gl < 30.0) else tn.mark_tightness_mid
	var tl := local(t.pos)
	var line := -SimQuery.offside_line_local(sim, opp_index())  # their offside line in our local frame
	var running_behind := t.vel.dot(Vector2(-team.dir, 0.0)) > 3.0
	if tl.x < line - 1.5 and not running_behind:
		# Threat stands offside: hold the line instead of following him.
		_go(p, ag.anchor, false)
		p.cmd.face = b.pos - p.pos
		return
	var tgt := ag.anchor.lerp(mp, tight)
	if running_behind and is_back:
		tgt = mp
	var d := p.pos.distance_to(tgt)
	_go(p, tgt, ag.sprint or d > 5.0 or (running_behind and d > 1.5))
	if d < 3.0:
		p.cmd.face = b.pos - p.pos


func _drive_runner(p: SimPlayer, ag: AIAgent) -> void:
	var b := sim.ball
	var lp := local(p.pos)
	var offside := lp.x > off_line + 0.2 and lp.x > local(b.pos).x
	match ag.run_state:
		0:
			_go(p, ag.target, false)
			var carrier: SimPlayer = sim.players[carrier_id] if carrier_id >= 0 else null
			if carrier == null or carrier.id == p.id or now < ag.run_cooldown or sim.state != MatchSim.State.PLAYING:
				return
			var d := carrier.pos.distance_to(p.pos)
			var can_feed := carrier.has_ball_time > 0.15 and SimQuery.pressure(sim, carrier) < 1.1 \
				and carrier.facing.dot(Vector2(team.dir, 0.0)) > -0.3
			if can_feed and d > 8.0 and d < 42.0 and off_line < Pitch.HALF_L - 13.0 and local(carrier.pos).x > -32.0 \
					and p.pos.distance_to(ag.target) < 6.0:
				ag.run_state = 1
				run_started_tick = sim.tick + 12   # carrier re-evaluates once the runner is up to speed
				ag.run_until = now + 2.6
				ag.offside_since = -1.0
				var ty := clampf(lp.y * 0.55, -14.0, 14.0)
				ag.run_target = world(Vector2(minf(off_line + 17.0, Pitch.HALF_L - 6.0), ty))
				ag.reason = "run in behind"
		1:
			_go(p, ag.run_target, true)
			if offside:
				if ag.offside_since < 0.0:
					ag.offside_since = now
			else:
				ag.offside_since = -1.0
			var pass_to_me := b.in_pass and b.kick_receiver == p.id
			var stale := ag.offside_since >= 0.0 and now - ag.offside_since > 0.45
			if not pass_to_me and (now > ag.run_until or stale or carrier_id < 0 or p.pos.distance_to(ag.run_target) < 2.0):
				ag.run_state = 2
				ag.run_cooldown = now + 2.2
				ag.reason = "run not used: come back onside"
		2:
			_go(p, ag.target, offside)
			if not offside and (p.pos.distance_to(ag.target) < 3.0 or now > ag.run_cooldown):
				ag.run_state = 0
