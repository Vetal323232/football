class_name MatchSim
extends RefCounted
## Deterministic fixed-step football match simulation (no scene nodes).
## Owns the ball, the players, the rules and the match flow. Controllers
## (TeamAI, HumanController) only write PlayerCommand objects.

signal event(kind: StringName, data: Dictionary)

enum State { RESTART_SETUP, RESTART_READY, PLAYING, GOAL, HALF_TIME, FULL_TIME }
enum Restart { KICKOFF, THROW_IN, CORNER, GOAL_KICK, FREE_KICK }

const DT := 1.0 / 60.0
const RESTART_NAMES: Array[String] = ["kickoff", "throw_in", "corner", "goal_kick", "free_kick"]

var tn: GameTuning
var rng := RandomNumberGenerator.new()
var players: Array[SimPlayer] = []
var teams: Array[SimTeam] = []
var ball := SimBall.new()
var state := State.RESTART_SETUP
var state_t := 0.0
var tick := 0
var time := 0.0
var duration := 360.0
var half := 1
var first_kickoff_team := 0
var human: HumanController = null
var setup: MatchSetup
var disposed := false
var freeze_clock := false      ## diagnostics: scenarios do not run the match clock

var restart_type := Restart.KICKOFF
var restart_team := 0
var restart_spot := Vector2.ZERO
var restart_taker := -1
var restart_positions := {}
var restart_ready_t := 0.0

var poss_team := -1
var poss_player := -1
var loose := true
var poss_change_tick := 0
var pending_pass := {}
var offside_flags := {}
var offside_team := -1
var last_goal := {}
var participants := {}        ## uid -> true for everyone who was on the pitch
var stall_time := 0.0
var stalls := 0
var _prev_ball_pos := Vector2.ZERO
var _path := PackedVector3Array()
var _path_tick := -1


func init_match(setup_: MatchSetup, tuning: GameTuning) -> void:
	setup = setup_
	tn = tuning
	rng.seed = setup.seed
	duration = setup.duration
	first_kickoff_team = int(rng.randi() % 2)
	for ti in 2:
		var td: Dictionary = setup.teams[ti]
		var tm := SimTeam.new()
		tm.index = ti
		tm.club_id = td.get("club_id", "")
		tm.tname = td.get("name", "Team")
		tm.short_name = td.get("short", "TM")
		tm.kit = td.get("kit", Color.WHITE)
		tm.kit2 = td.get("kit2", Color.BLACK)
		tm.keeper_kit = Color(0.95, 0.8, 0.1) if ti == 0 else Color(0.2, 0.85, 0.4)
		tm.dir = 1.0 if ti == 0 else -1.0
		tm.human = setup.human_team == ti
		var tac: TeamTactics = td.get("tactics")
		if tac == null:
			tac = TeamTactics.for_difficulty(2 if tm.human else setup.difficulty)
		tm.tactics = tac
		tm.bench = (td.get("bench", []) as Array).duplicate()
		teams.append(tm)
		var plist: Array = td["players"]
		for slot in 11:
			var p := SimPlayer.new()
			p.id = players.size()
			p.team = ti
			p.role = slot
			_apply_identity(p, plist[slot])
			tm.player_ids.append(p.id)
			players.append(p)
	for tm in teams:
		tm.ai = TeamAI.new(self, tm)
	if setup.human_team >= 0:
		human = HumanController.new(self, setup.human_team)
	begin_restart(Restart.KICKOFF, first_kickoff_team, Vector2.ZERO)
	_snap_restart_positions()


func _apply_identity(p: SimPlayer, d: Dictionary) -> void:
	p.uid = str(d.get("id", ""))
	p.pname = str(d.get("name", "Player"))
	p.number = int(d.get("number", p.role + 1))
	var a: Dictionary = d.get("attrs", {})
	p.pace = Attr.norm(float(a.get("pace", 60)))
	p.passing = Attr.norm(float(a.get("passing", 60)))
	p.shooting = Attr.norm(float(a.get("shooting", 60)))
	p.control = Attr.norm(float(a.get("control", 60)))
	p.defending = Attr.norm(float(a.get("defending", 60)))
	p.stamina_attr = Attr.norm(float(a.get("stamina", 60)))
	p.goalkeeping = Attr.norm(float(a.get("goalkeeping", 10)))
	p.fitness = float(d.get("fitness", 1.0))
	participants[p.uid] = true


## Replace a player on the pitch with a bench player. Returns false if not allowed.
func substitute(team: int, player_id: int, bench_index: int) -> bool:
	var tm := teams[team]
	if tm.subs_made >= 5 or bench_index < 0 or bench_index >= tm.bench.size():
		return false
	if state == State.FULL_TIME or not tm.player_ids.has(player_id):
		return false
	var p := players[player_id]
	if ball.owner == p.id or ball.held_by == p.id:
		return false
	var incoming: Dictionary = tm.bench[bench_index]
	tm.bench.remove_at(bench_index)
	_apply_identity(p, incoming)
	# The newcomer takes over the slot (position, role, control) but none of the
	# outgoing player's transient state.
	p.reset_transient()
	p.stamina = p.fitness
	offside_flags.erase(p.id)
	if tm.ai != null:
		tm.ai.on_substitution(p.id)
	if human != null and human.controlled == p.id:
		human.reset_actions()
	tm.subs_made += 1
	event.emit(&"substitution", {"team": team, "player": p.id})
	return true


## Release the ownership cycles of a finished match (sim <-> team AI <-> team,
## sim <-> human controller, event listeners that captured the sim). Idempotent.
## Every owner calls this when it lets go of a match: match_view on exit, headless tools after a run.
## A disposed sim keeps its plain state readable (score, stats, players) but cannot be stepped.
func dispose() -> void:
	if disposed:
		return
	disposed = true
	for c: Dictionary in event.get_connections():
		event.disconnect(c["callable"])
	for tm in teams:
		if tm.ai != null:
			tm.ai.dispose()
			tm.ai = null
	if human != null:
		human.dispose()
		human = null


func emit(kind: StringName, data := {}) -> void:
	event.emit(kind, data)


func is_live() -> bool:
	return state == State.PLAYING


func display_minute() -> int:
	return int(floor(time / duration * 90.0))


func team_of(pid: int) -> SimTeam:
	return teams[players[pid].team]


# ----------------------------------------------------------------- main step

func step() -> void:
	if state == State.FULL_TIME or disposed:
		return
	tick += 1
	match state:
		State.GOAL:
			state_t -= DT
			if state_t <= 0.0:
				begin_restart(Restart.KICKOFF, 1 - int(last_goal["team"]), Vector2.ZERO)
		State.HALF_TIME:
			state_t -= DT
			if state_t <= 0.0:
				half = 2
				for tm in teams:
					tm.dir = -tm.dir
				begin_restart(Restart.KICKOFF, 1 - first_kickoff_team, Vector2.ZERO)
				_snap_restart_positions()
		State.RESTART_SETUP:
			state_t -= DT
			if state_t <= 0.0:
				_snap_restart_positions()
				state = State.RESTART_READY
				restart_ready_t = 0.0
				ball.owner = restart_taker
				emit(&"restart_ready", {"type": restart_type, "team": restart_team})
		State.RESTART_READY:
			restart_ready_t += DT

	for p in players:
		p.cmd.clear()
	if state == State.PLAYING or state == State.RESTART_READY or state == State.RESTART_SETUP:
		for tm in teams:
			tm.ai.update()
		if human != null:
			human.update()

	_update_timers()
	_move_players()
	_resolve_actions()
	_ball_step()
	if state == State.PLAYING:
		_possession()
	if state == State.PLAYING:
		_rules()
	if state == State.PLAYING or state == State.RESTART_READY:
		if not freeze_clock:
			time += DT
		if poss_team >= 0 and state == State.PLAYING:
			teams[poss_team].stats.possession_ticks += 1


func _update_timers() -> void:
	for p in players:
		p.kick_lock = maxf(0.0, p.kick_lock - DT)
		p.stun = maxf(0.0, p.stun - DT)
		p.tackle_cd = maxf(0.0, p.tackle_cd - DT)
		p.tackle_recover = maxf(0.0, p.tackle_recover - DT)
		p.dive_recover = maxf(0.0, p.dive_recover - DT)
		p.anim_t = maxf(0.0, p.anim_t - DT)
		if p.anim_t <= 0.0:
			p.anim = &""
	ball.owner_lock = maxf(0.0, ball.owner_lock - DT)


# ------------------------------------------------------------ player movement

func _move_players() -> void:
	var setup_phase := state == State.RESTART_SETUP
	var frozen := state == State.GOAL or state == State.HALF_TIME
	for p in players:
		var desired := Vector2.ZERO
		var rate := tn.decel
		if setup_phase:
			var tgt: Vector2 = restart_positions.get(p.id, p.pos)
			var to := tgt - p.pos
			var d := to.length()
			if d > 0.15:
				desired = to / d * minf(9.0, d * 3.0 + 1.0)
			rate = 18.0
		elif frozen:
			desired = Vector2.ZERO
		elif state == State.RESTART_READY and (p.id == restart_taker or restart_type == Restart.KICKOFF):
			desired = Vector2.ZERO
			if p.cmd.face.length_squared() > 0.01:
				p.facing = _turn(p.facing, p.cmd.face.normalized(), tn.turn_rate * DT)
		elif p.dive_t > 0.0:
			p.dive_t -= DT
			desired = p.dive_dir
			rate = 60.0
			if p.dive_t <= 0.0:
				p.dive_recover = tn.keeper_dive_recover
		elif p.tackle_t > 0.0:
			desired = p.tackle_dir * maxf(tn.tackle_lunge_speed, p.vel.length() * 0.9)
			rate = 40.0
		else:
			var top := p.top_speed(tn)
			var maxs := top
			if not p.can_act():
				maxs = tn.recover_speed
			else:
				var sprinting := p.cmd.sprint and p.stamina > 0.03
				if not sprinting:
					maxs = top * tn.jog_ratio
				if ball.owner == p.id:
					maxs *= tn.dribble_speed_ratio
			desired = p.cmd.move.limit_length(1.0) * maxs
			var cur_sp := p.vel.length()
			var speeding := desired.length() > cur_sp and p.vel.dot(desired) >= 0.0
			if speeding:
				rate = p.accel(tn)
				# Blend: redirecting sideways while speeding up uses a stronger rate.
				if cur_sp > 1.0:
					var align := p.vel.dot(desired) / (cur_sp * desired.length())
					rate = lerpf(tn.decel, rate, clampf(align, 0.0, 1.0))
			# Stamina.
			if p.cmd.sprint and cur_sp > top * tn.jog_ratio * 1.03:
				p.stamina = maxf(0.0, p.stamina - tn.stamina_drain * (1.35 - 0.7 * p.stamina_attr) * DT)
			elif cur_sp < 2.0:
				p.stamina = minf(p.fitness, p.stamina + tn.stamina_recover_idle * DT)
			else:
				p.stamina = minf(p.fitness, p.stamina + tn.stamina_recover_jog * DT)
		p.vel = p.vel.move_toward(desired, rate * DT)
		var step_v := p.vel * DT
		p.pos += step_v
		var moved := step_v.length()
		p.distance_run += moved
		if not setup_phase:
			p.fitness = maxf(0.55, p.fitness - moved * 0.001 * tn.fitness_loss_per_km * (1.4 - 0.8 * p.stamina_attr))
		p.pos.x = clampf(p.pos.x, -Pitch.HALF_L - 3.0, Pitch.HALF_L + 3.0)
		p.pos.y = clampf(p.pos.y, -Pitch.HALF_W - 3.0, Pitch.HALF_W + 3.0)
		# Facing.
		if p.dive_t > 0.0 or p.tackle_t > 0.0:
			pass
		elif p.cmd.face.length_squared() > 0.01:
			p.facing = _turn(p.facing, p.cmd.face.normalized(), tn.turn_rate * DT)
		elif p.vel.length() > 0.6:
			p.facing = _turn(p.facing, p.vel.normalized(), tn.turn_rate * DT)

	# Soft body separation.
	var n := players.size()
	var min_d := tn.player_radius * 2.0
	for i in n:
		var a := players[i]
		for j in range(i + 1, n):
			var b := players[j]
			var dv := b.pos - a.pos
			var d2 := dv.length_squared()
			if d2 < min_d * min_d and d2 > 0.0001:
				var d := sqrt(d2)
				var push := dv / d * ((min_d - d) * 0.5)
				a.pos -= push
				b.pos += push

	if state == State.RESTART_READY:
		_enforce_restart_distance()


static func _turn(from: Vector2, to: Vector2, max_angle: float) -> Vector2:
	var ang := from.angle_to(to)
	if absf(ang) <= max_angle:
		return to
	return from.rotated(signf(ang) * max_angle)


func _enforce_restart_distance() -> void:
	var radius := 2.2 if restart_type == Restart.THROW_IN else Pitch.CIRCLE_R
	for id in teams[1 - restart_team].player_ids:
		var p := players[id]
		var dv := p.pos - ball.pos
		var d := dv.length()
		if d < radius:
			if d < 0.01:
				dv = Vector2(-signf(ball.pos.x + 0.001), 0.0)
				d = 1.0
			p.pos = ball.pos + dv / d * radius
			p.pos = Pitch.clamp_inside(p.pos, 0.3)
			p.vel = Vector2.ZERO


# ------------------------------------------------------------------- actions

func _resolve_actions() -> void:
	for p in players:
		# Goalkeeper dive.
		if p.cmd.dive.length_squared() > 0.0001 and p.is_keeper() and p.can_act() and state == State.PLAYING and ball.held_by != p.id:
			var dv := p.cmd.dive - p.pos
			if dv.length() > 0.3:
				p.dive_t = tn.keeper_dive_time
				p.dive_dir = dv.normalized() * (tn.keeper_dive_speed_base + tn.keeper_dive_speed_attr * p.goalkeeping)
				p.set_anim(&"dive", tn.keeper_dive_time + tn.keeper_dive_recover)
		# Tackle start.
		if p.cmd.tackle and p.can_act() and p.tackle_cd <= 0.0 and state == State.PLAYING and ball.owner != p.id and ball.held_by != p.id:
			p.tackle_t = tn.tackle_window
			p.tackle_cd = tn.tackle_cooldown
			p.tackle_done = false
			var to_ball := ball.pos - p.pos
			if to_ball.length() < 2.6 and to_ball.length() > 0.05:
				p.tackle_dir = to_ball.normalized()
			elif p.cmd.move.length() > 0.2:
				p.tackle_dir = p.cmd.move.normalized()
			else:
				p.tackle_dir = p.facing
			p.facing = p.tackle_dir
			p.set_anim(&"tackle", tn.tackle_window + 0.3)
			teams[p.team].stats.tackles += 1
		if p.tackle_t > 0.0:
			p.tackle_t -= DT
			if not p.tackle_done and state == State.PLAYING:
				_tackle_contact(p)
			if p.tackle_t <= 0.0:
				p.tackle_recover = tn.tackle_recover_hit if p.tackle_done else tn.tackle_recover_miss
		# Kick requests.
		if p.cmd.kick != null:
			p.pending_kick = p.cmd.kick
			p.pending_kick_t = 0.4
		if p.pending_kick != null:
			_try_kick(p)


func _tackle_contact(p: SimPlayer) -> void:
	if ball.held_by >= 0 or ball.dead or ball.h > 0.6:
		return
	var foot := p.pos + p.tackle_dir * 0.6
	if foot.distance_to(ball.pos) > tn.tackle_reach:
		return
	if ball.owner >= 0:
		var o := players[ball.owner]
		if o.team == p.team:
			return
		p.tackle_done = true
		var chance := tn.tackle_base_chance + 0.35 * (p.defending - 0.5) - 0.3 * (o.control - 0.5)
		var away := (o.pos - p.pos)
		if away.length() > 0.01 and o.facing.dot(away.normalized()) > 0.45:
			chance *= tn.tackle_behind_mult
		if o.pos.distance_to(ball.pos) > 0.95:
			chance += 0.15
		var won := rng.randf() < clampf(chance, 0.05, 0.95)
		if won:
			ball.owner = -1
			ball.owner_lock = 0.0
			o.stun = tn.tackle_stun
			o.set_anim(&"stumble", tn.tackle_stun)
			ball.vel = (p.tackle_dir * 2.6 + p.vel * 0.3).rotated(rng.randf_range(-0.5, 0.5))
			ball.kick_kind = -1
			ball.in_pass = false
			loose = true
			teams[p.team].stats.tackles_won += 1
			_register_touch(p, false)
			emit(&"tackle", {"player": p.id, "won": true})
		else:
			p.tackle_done = false
			p.tackle_t = minf(p.tackle_t, 0.0)
			p.tackle_recover = tn.tackle_recover_miss
			emit(&"tackle", {"player": p.id, "won": false})
	elif ball.is_free() and p.kick_lock <= 0.0 and ball.restart_taker != p.id:
		p.tackle_done = true
		ball.vel = p.tackle_dir * 8.0
		ball.kick_kind = -1
		ball.in_pass = false
		loose = true
		if _register_touch(p, false):
			return
		emit(&"tackle", {"player": p.id, "won": true})


func _try_kick(p: SimPlayer) -> void:
	p.pending_kick_t -= DT
	if p.pending_kick_t < 0.0:
		p.pending_kick = null
		return
	if p.stun > 0.0 or p.tackle_t > 0.0 or p.tackle_recover > 0.0 or p.dive_t > 0.0:
		return
	var k := p.pending_kick
	var from_hands := ball.held_by == p.id
	var dead_ball := state == State.RESTART_READY and restart_taker == p.id
	var owned := ball.owner == p.id and state == State.PLAYING
	var first_time := false
	if not (from_hands or dead_ball or owned):
		if state != State.PLAYING or not ball.is_free() or not p.can_touch_ball() or ball.restart_taker == p.id:
			return
		if ball.h > 1.0 or p.pos.distance_to(ball.pos) > tn.kick_reach:
			return
		first_time = true
	if dead_ball and restart_ready_t < 0.25:
		return
	p.pending_kick = null
	# Judge this involvement against the PREVIOUS kick before any kick metadata is replaced:
	# a flagged player who meets the ball first time is offside, his kick never happens.
	if not dead_ball and _offside_involvement(p):
		return

	var is_shot := k.kind == KickRequest.Kind.SHOT
	var attr := p.shooting if is_shot else p.passing
	var sigma := lerpf(tn.shot_error_bad, tn.shot_error_good, attr) if is_shot else lerpf(tn.pass_error_bad, tn.pass_error_good, attr)
	if k.kind == KickRequest.Kind.LOB or k.kind == KickRequest.Kind.CLEAR:
		sigma *= tn.loft_error_mult
	if dead_ball or from_hands:
		sigma *= 0.6
	else:
		sigma *= 1.0 + 0.35 * minf(SimQuery.pressure(self, p), 1.5)
		sigma *= 1.0 + 0.35 * p.vel.length() / p.top_speed(tn)
		sigma *= 1.0 + 0.5 * absf(p.facing.angle_to(k.dir)) / PI
		if first_time:
			sigma *= tn.first_time_error_mult
	if not p.is_human:
		sigma *= teams[p.team].tactics.execution_error_mult
	var dir := k.dir.rotated(rng.randfn(0.0, sigma))
	var spd := k.speed * (1.0 + rng.randfn(0.0, 0.03 + 0.05 * (1.0 - attr)))
	var vh := k.vh * (1.0 + rng.randfn(0.0, sigma * 2.0))
	if is_shot:
		vh += rng.randfn(0.0, sigma * 14.0)
		spd = minf(spd, tn.shot_speed_base + tn.shot_speed_attr * p.shooting)
	else:
		spd = minf(spd, tn.pass_speed_max + (6.0 if k.kind == KickRequest.Kind.CLEAR else 0.0))
	vh = maxf(vh, 0.0)

	var thrown := false
	if dead_ball and restart_type == Restart.THROW_IN:
		thrown = true
		spd = minf(spd, tn.throw_speed_max)
		ball.h = 1.9
		vh = clampf(vh, 1.2, 6.5)
	elif from_hands:
		if k.kind == KickRequest.Kind.PASS and spd <= 17.0:
			thrown = true
			ball.h = 1.3
			vh = maxf(vh, 1.5)
		else:
			ball.h = 0.4

	ball.pos = ball.pos if not from_hands else p.pos + dir * 0.5
	ball.vel = dir * spd
	ball.vh = vh
	ball.owner = -1
	ball.held_by = -1
	ball.dead = false
	ball.owner_lock = 0.0
	ball.kick_id += 1
	ball.kick_kind = k.kind
	ball.kicker = p.id
	ball.kick_receiver = k.receiver
	ball.kick_target = k.target
	ball.kick_tick = tick
	ball.in_pass = true
	ball.backpass_team = -1 if thrown else p.team
	loose = false
	p.kick_lock = tn.kick_lock_time
	p.facing = k.dir
	p.vel *= 0.75
	p.has_ball_time = 0.0
	p.set_anim(&"throw" if thrown else &"kick", 0.35)

	if dead_ball:
		state = State.PLAYING
		ball.restart_taker = p.id
		ball.no_offside = restart_type == Restart.THROW_IN or restart_type == Restart.CORNER or restart_type == Restart.GOAL_KICK
		emit(&"restart_taken", {"type": restart_type, "team": restart_team})

	if _register_touch(p, true):
		return
	# Offside snapshot at the moment of the pass.
	offside_flags.clear()
	offside_team = p.team
	if not ball.no_offside:
		var line := SimQuery.offside_line_local(self, p.team)
		var tm := teams[p.team]
		for id in tm.player_ids:
			if id == p.id:
				continue
			var q := players[id]
			if q.pos.x * tm.dir > line + 0.25:
				offside_flags[id] = q.pos
	# Stats.
	var st := teams[p.team].stats
	pending_pass = {}
	if is_shot:
		st.shots += 1
		st.xg += FieldValue.xg_pos(teams[p.team].to_local(p.pos))
		if _shot_on_target():
			st.shots_on_target += 1
	elif k.kind != KickRequest.Kind.CLEAR:
		st.passes += 1
		pending_pass = {"team": p.team, "kicker": p.id}
	emit(&"kick", {"player": p.id, "kind": k.kind, "speed": spd, "receiver": k.receiver})


func _shot_on_target() -> bool:
	var b := BallState.new()
	b.copy_from(ball)
	for i in 90:
		b.advance(1.0 / 30.0, tn)
		if absf(b.pos.x) >= Pitch.HALF_L:
			return absf(b.pos.y) < Pitch.GOAL_HALF_W and b.h < Pitch.GOAL_H
		if b.vel.length() < 0.5:
			return false
	return false


## Offside is punished when a player flagged at a teammate's kick becomes involved.
## Must be evaluated while `ball.kicker` still names that earlier kick. Returns true
## if play was stopped (the restart clears the snapshot, so it cannot fire twice).
func _offside_involvement(p: SimPlayer) -> bool:
	if not offside_flags.has(p.id) or p.team != offside_team or ball.kicker == p.id:
		return false
	var spot: Vector2 = offside_flags[p.id]
	teams[p.team].stats.offsides += 1
	emit(&"offside", {"player": p.id})
	emit(&"whistle", {"reason": "offside"})
	begin_restart(Restart.FREE_KICK, 1 - p.team, Pitch.clamp_inside(spot, 1.0))
	return true


## Bookkeeping for any ball touch. Returns true if play was stopped (offside).
func _register_touch(p: SimPlayer, deliberate: bool) -> bool:
	if _offside_involvement(p):
		return true
	if deliberate and (p.team != offside_team or ball.kicker != p.id):
		offside_flags.clear()
	if ball.restart_taker >= 0 and ball.restart_taker != p.id:
		ball.restart_taker = -1
		ball.no_offside = false
	# The back-pass restriction ends when another player touches the ball. The receiving
	# keeper's own foot control does not lift it, however often he loses and regains the ball.
	if ball.kicker != p.id and not (p.is_keeper() and p.team == ball.backpass_team):
		ball.backpass_team = -1
	ball.last_touch = p.id
	ball.last_touch_team = p.team
	return false


# ---------------------------------------------------------------------- ball

func _ball_step() -> void:
	_prev_ball_pos = ball.pos
	if ball.dead:
		ball.vel = Vector2.ZERO
		ball.vh = 0.0
		return
	if ball.held_by >= 0:
		var k := players[ball.held_by]
		ball.pos = k.pos + k.facing * 0.35
		ball.h = 1.1
		ball.vel = k.vel
		ball.vh = 0.0
		return
	if state == State.GOAL:
		ball.advance(DT, tn)
		var side := signf(ball.pos.x)
		ball.vel *= 0.9
		ball.pos.x = side * clampf(absf(ball.pos.x), Pitch.HALF_L + Pitch.BALL_R, Pitch.HALF_L + Pitch.NET_DEPTH - 0.2)
		ball.pos.y = clampf(ball.pos.y, -Pitch.GOAL_HALF_W + 0.2, Pitch.GOAL_HALF_W - 0.2)
		ball.h = minf(ball.h, Pitch.GOAL_H - 0.2)
		return
	if ball.owner >= 0:
		ball.pos += ball.vel * DT
		ball.h = maxf(0.0, ball.h - 5.0 * DT)
		ball.vh = 0.0
		return
	var sp := ball.vel.length()
	var steps := 1
	if absf(ball.pos.x) > Pitch.HALF_L - 3.0:
		steps = clampi(int(ceil(sp * DT / 0.09)), 1, 8)
	var sdt := DT / float(steps)
	for i in steps:
		var was_air := ball.h > 0.02
		var vh0 := ball.vh
		ball.advance(sdt, tn)
		if was_air and ball.h <= 0.0 and vh0 < -3.0:
			emit(&"bounce", {"speed": -vh0})
		if absf(ball.pos.x) > Pitch.HALF_L - 0.5:
			_goal_frame_collision()


func _goal_frame_collision() -> void:
	var side := signf(ball.pos.x)
	var rsum := Pitch.BALL_R + Pitch.POST_R
	# Posts (vertical cylinders).
	if ball.h < Pitch.GOAL_H + Pitch.POST_R:
		for ys: float in [-1.0, 1.0]:
			var post := Vector2(side * Pitch.HALF_L, ys * Pitch.GOAL_HALF_W)
			var dv := ball.pos - post
			var d := dv.length()
			if d < rsum and d > 0.0001:
				var nrm := dv / d
				ball.pos = post + nrm * rsum
				var vn := ball.vel.dot(nrm)
				if vn < 0.0:
					ball.vel -= nrm * vn * (1.0 + tn.post_restitution)
					ball.kick_kind = -1
					ball.in_pass = false
					emit(&"post", {})
	# Crossbar (horizontal cylinder along y), collision in the (x, h) plane.
	if absf(ball.pos.y) <= Pitch.GOAL_HALF_W:
		var c := Vector2(side * Pitch.HALF_L, Pitch.GOAL_H)
		var bp := Vector2(ball.pos.x, ball.h)
		var dv2 := bp - c
		var d2 := dv2.length()
		if d2 < rsum and d2 > 0.0001:
			var n2 := dv2 / d2
			bp = c + n2 * rsum
			ball.pos.x = bp.x
			ball.h = maxf(0.0, bp.y)
			var v2 := Vector2(ball.vel.x, ball.vh)
			var vn2 := v2.dot(n2)
			if vn2 < 0.0:
				v2 -= n2 * vn2 * (1.0 + tn.post_restitution)
				ball.vel.x = v2.x
				ball.vh = v2.y
				ball.kick_kind = -1
				ball.in_pass = false
				emit(&"post", {})


## Predicted free-ball path: one Vector3(x, y, height) per 0.1 s, about 4 s ahead.
func ball_path() -> PackedVector3Array:
	if _path_tick == tick:
		return _path
	_path_tick = tick
	_path = PackedVector3Array()
	var b := BallState.new()
	b.copy_from(ball)
	_path.append(Vector3(b.pos.x, b.pos.y, b.h))
	if not ball.is_free():
		return _path
	for i in 40:
		b.advance(0.05, tn)
		b.advance(0.05, tn)
		_path.append(Vector3(b.pos.x, b.pos.y, b.h))
		if b.h <= 0.0 and b.vel.length_squared() < 0.01:
			break
	return _path


# ---------------------------------------------------------------- possession

func _possession() -> void:
	if ball.dead:
		return
	if ball.held_by >= 0:
		ball.held_time += DT
		if ball.held_time > tn.keeper_hold_max + 2.0:
			# Safety net: the keeper must release the ball.
			var kp := players[ball.held_by]
			var d := Vector2(teams[kp.team].dir, 0.0)
			kp.pending_kick = KickRequest.make(KickRequest.Kind.CLEAR, d, 26.0, 11.0, -1, kp.pos + d * 45.0)
			kp.pending_kick_t = 0.2
		return
	if ball.owner >= 0:
		var o := players[ball.owner]
		var dist := o.pos.distance_to(ball.pos)
		if not o.can_touch_ball() or o.tackle_t > 0.0 or dist > tn.lose_reach:
			ball.owner = -1
			ball.kick_kind = -1
			ball.in_pass = false
			loose = true
		else:
			# A challenger can nick a ball that is closer to him than to the carrier.
			if ball.owner_lock <= 0.0:
				for id in teams[1 - o.team].player_ids:
					var q := players[id]
					if not q.can_touch_ball() or q.tackle_t > 0.0:
						continue
					var dq := q.pos.distance_to(ball.pos)
					if dq < 0.5 and dist > dq + 0.3:
						_give_possession(q, true)
						return
			_dribble_control(o)
			o.has_ball_time += DT
			return
	_free_ball_contacts()


func _dribble_control(o: SimPlayer) -> void:
	var want := o.cmd.move
	var dirv := want.normalized() if want.length() > 0.15 else o.facing
	var sp := o.vel.length()
	var lead := tn.dribble_lead + tn.dribble_lead_sprint * clampf((sp - 4.5) / 4.0, 0.0, 1.0)
	var tgt := o.pos + dirv * lead
	var desired := o.vel + (tgt - ball.pos) * tn.dribble_gain
	desired = desired.limit_length(sp + 7.0)
	var acc := tn.dribble_accel_base + tn.dribble_accel_attr * o.control
	ball.vel = ball.vel.move_toward(desired, acc * DT)


func _may_handle(p: SimPlayer) -> bool:
	if not p.is_keeper() or ball.backpass_team == p.team:
		return false
	return Pitch.in_pen_area(ball.pos, -teams[p.team].dir) and Pitch.in_pen_area(p.pos, -teams[p.team].dir)


func _free_ball_contacts() -> void:
	var best: SimPlayer = null
	var best_d := INF
	var best_hands := false
	var fresh_kick := ball.in_pass and tick - ball.kick_tick < 8 and ball.kicker >= 0
	var kick_team := players[ball.kicker].team if ball.kicker >= 0 else -1
	for p in players:
		if not p.can_touch_ball() and not (p.is_keeper() and p.dive_t > 0.0):
			continue
		if p.kick_lock > 0.0 or ball.restart_taker == p.id:
			continue
		var d := p.pos.distance_to(ball.pos)
		if d > 2.0:
			continue
		# A freshly struck ball can only be blocked from in front, not grabbed from beside/behind.
		if fresh_kick and p.team != kick_team and ball.vel.dot(p.pos - ball.pos) <= 0.0:
			continue
		var hands := _may_handle(p)
		var ok := false
		if hands:
			var r := tn.keeper_dive_reach if p.dive_t > 0.0 else tn.keeper_reach
			ok = d < r and ball.h < tn.keeper_reach_height
		elif p.tackle_t <= 0.0:
			if ball.h <= tn.claim_height:
				ok = d < tn.claim_reach + tn.claim_reach_attr * p.control
			elif ball.h < 1.95:
				ok = d < 0.5
		if ok and d < best_d:
			best = p
			best_d = d
			best_hands = hands
	if best == null:
		return
	if best_hands:
		_keeper_contact(best, best_d)
		return
	var p := best
	var rel := ball.vel - p.vel
	var rel3 := sqrt(rel.length_squared() + ball.vh * ball.vh * 0.6)
	var limit := tn.trap_speed_base + tn.trap_speed_attr * p.control
	var high := ball.h > tn.claim_height
	if rel3 > limit or high:
		if best_d > tn.body_block_radius + 0.25 and not high:
			return
		if high and rel3 < 4.0:
			return
		# Deflection off the body: the ball stays loose.
		var keep := rng.randf_range(0.22, 0.45)
		ball.vel = ball.vel.rotated(rng.randf_range(-0.9, 0.9)) * keep + p.vel * 0.4
		ball.vh = absf(ball.vh) * 0.3 + rng.randf_range(0.0, 2.0)
		if high:
			ball.vh = minf(ball.vh, 0.5)
		p.kick_lock = 0.22
		ball.kick_kind = -1
		ball.in_pass = false
		_resolve_pass_stat(p)
		loose = true
		if _register_touch(p, false):
			return
		emit(&"deflect", {"player": p.id})
		return
	# Controlled first touch; quality depends on relative speed and control.
	var q := rel3 / limit
	var keep2 := lerpf(0.08, 0.42, q) * (1.25 - 0.5 * p.control)
	ball.vel = p.vel + rel.rotated(rng.randfn(0.0, 0.3 * q)) * keep2
	ball.vh = minf(ball.vh, 0.0)
	_give_possession(p, false)


func _give_possession(p: SimPlayer, stolen: bool) -> void:
	_resolve_pass_stat(p)
	if _register_touch(p, true):
		return
	var prev_team := poss_team
	ball.owner = p.id
	ball.owner_lock = 0.3 if stolen else tn.owner_lock_time
	ball.kick_kind = -1
	ball.in_pass = false
	loose = false
	p.has_ball_time = 0.0
	if prev_team != p.team:
		if prev_team >= 0:
			teams[prev_team].stats.turnovers += 1
		poss_change_tick = tick
		emit(&"possession", {"team": p.team, "player": p.id})
	poss_team = p.team
	poss_player = p.id
	emit(&"claim", {"player": p.id})


func _resolve_pass_stat(p: SimPlayer) -> void:
	if pending_pass.is_empty():
		return
	if p.team == int(pending_pass["team"]):
		if p.id != int(pending_pass["kicker"]):
			teams[p.team].stats.passes_completed += 1
	else:
		teams[p.team].stats.interceptions += 1
	pending_pass = {}


func _keeper_contact(p: SimPlayer, d: float) -> void:
	var sp3 := sqrt(ball.vel.length_squared() + ball.vh * ball.vh)
	var reach := tn.keeper_dive_reach if p.dive_t > 0.0 else tn.keeper_reach
	var stretch := d > 0.6
	var from_shot := ball.kick_kind == KickRequest.Kind.SHOT and ball.kicker >= 0 and players[ball.kicker].team != p.team
	if stretch and sp3 > 11.0:
		if ball.save_roll_kick == ball.kick_id:
			return
		ball.save_roll_kick = ball.kick_id
		var p_save := 0.6 + 0.38 * p.goalkeeping - 0.013 * (sp3 - 18.0) - 0.3 * (d - 0.6) / maxf(reach - 0.6, 0.1)
		if rng.randf() > clampf(p_save, 0.05, 0.98):
			return
	var limit := tn.keeper_catch_speed_base + tn.keeper_catch_speed_attr * p.goalkeeping
	if stretch:
		limit *= 0.7
	_resolve_pass_stat(p)
	if sp3 <= limit:
		if _register_touch(p, true):
			return
		ball.held_by = p.id
		ball.owner = -1
		ball.held_time = 0.0
		ball.vel = Vector2.ZERO
		ball.vh = 0.0
		ball.kick_kind = -1
		ball.in_pass = false
		loose = false
		if poss_team != p.team:
			if poss_team >= 0:
				teams[poss_team].stats.turnovers += 1
			poss_change_tick = tick
			emit(&"possession", {"team": p.team, "player": p.id})
		poss_team = p.team
		poss_player = p.id
		if from_shot:
			teams[p.team].stats.saves += 1
		emit(&"save", {"player": p.id, "catch": true})
	else:
		var goal_sign := -teams[p.team].dir
		var side := signf(ball.pos.y - p.pos.y)
		if side == 0.0:
			side = 1.0 if rng.randf() < 0.5 else -1.0
		var out_dir := Vector2(-goal_sign * rng.randf_range(0.35, 0.9), side * rng.randf_range(0.5, 1.0)).normalized()
		ball.vel = out_dir * sp3 * rng.randf_range(0.3, 0.45)
		ball.vh = rng.randf_range(1.0, 4.0)
		ball.kick_kind = -1
		ball.in_pass = false
		loose = true
		p.kick_lock = 0.35
		if _register_touch(p, false):
			return
		if from_shot:
			teams[p.team].stats.saves += 1
		emit(&"save", {"player": p.id, "catch": false})


# --------------------------------------------------------------------- rules

func _rules() -> void:
	# Goal line.
	if absf(ball.pos.x) > Pitch.HALF_L + Pitch.BALL_R:
		var side := signf(ball.pos.x)
		var y_cross := ball.pos.y
		var dx := ball.pos.x - _prev_ball_pos.x
		if absf(dx) > 0.0001:
			var t := clampf((side * (Pitch.HALF_L + Pitch.BALL_R) - _prev_ball_pos.x) / dx, 0.0, 1.0)
			y_cross = lerpf(_prev_ball_pos.y, ball.pos.y, t)
		var attacking := 0 if teams[0].dir == side else 1
		var defending := 1 - attacking
		if absf(y_cross) < Pitch.GOAL_HALF_W and ball.h < Pitch.GOAL_H:
			_award_goal(attacking)
		else:
			emit(&"whistle", {"reason": "out"})
			var ys := signf(ball.pos.y) if ball.pos.y != 0.0 else 1.0
			if ball.last_touch_team == defending:
				teams[attacking].stats.corners += 1
				begin_restart(Restart.CORNER, attacking, Vector2(side * (Pitch.HALF_L - 0.3), ys * (Pitch.HALF_W - 0.3)))
			else:
				teams[defending].stats.goal_kicks += 1
				begin_restart(Restart.GOAL_KICK, defending, Vector2(side * (Pitch.HALF_L - Pitch.SIX_DEPTH), ys * 5.0))
		return
	# Touchline.
	if absf(ball.pos.y) > Pitch.HALF_W + Pitch.BALL_R:
		var team := 1 - ball.last_touch_team if ball.last_touch_team >= 0 else 0
		teams[team].stats.throw_ins += 1
		emit(&"whistle", {"reason": "out"})
		var x := clampf(ball.pos.x, -Pitch.HALF_L + 1.0, Pitch.HALF_L - 1.0)
		begin_restart(Restart.THROW_IN, team, Vector2(x, signf(ball.pos.y) * Pitch.HALF_W))
		return
	# Deadlock metric: a slow free ball that nobody collects.
	if ball.is_free() and ball.vel.length() < 0.5 and ball.h <= 0.0:
		stall_time += DT
		if stall_time > 6.0:
			stall_time = 0.0
			stalls += 1
			emit(&"stall", {})
	else:
		stall_time = 0.0
	# Halves.
	if freeze_clock:
		return
	if half == 1 and time >= duration * 0.5:
		state = State.HALF_TIME
		state_t = tn.half_time_pause
		_stop_play()
		emit(&"whistle", {"reason": "half_time"})
		emit(&"half_time", {})
	elif half == 2 and time >= duration:
		state = State.FULL_TIME
		_stop_play()
		emit(&"whistle", {"reason": "full_time"})
		emit(&"full_time", {})


func _stop_play() -> void:
	ball.owner = -1
	ball.held_by = -1
	ball.in_pass = false
	pending_pass = {}
	offside_flags.clear()
	for p in players:
		p.pending_kick = null


func _award_goal(team: int) -> void:
	var scorer := ball.last_touch
	var own_goal := scorer >= 0 and players[scorer].team != team
	teams[team].score += 1
	teams[team].stats.goals += 1
	last_goal = {"team": team, "scorer": scorer, "own_goal": own_goal, "minute": display_minute() + 1}
	state = State.GOAL
	state_t = tn.goal_pause
	_stop_play()
	emit(&"goal", last_goal)


func begin_restart(type: int, team: int, spot: Vector2) -> void:
	restart_type = type
	restart_team = team
	restart_spot = spot
	state = State.RESTART_SETUP
	state_t = tn.kickoff_setup_time if type == Restart.KICKOFF else tn.restart_setup_time
	ball.owner = -1
	ball.held_by = -1
	ball.dead = true
	ball.pos = spot
	ball.h = 0.0
	ball.vel = Vector2.ZERO
	ball.vh = 0.0
	ball.in_pass = false
	ball.kick_kind = -1
	ball.restart_taker = -1
	ball.no_offside = false
	ball.backpass_team = -1
	offside_flags.clear()
	pending_pass = {}
	if poss_team != team:
		poss_change_tick = tick
	poss_team = team
	poss_player = -1
	loose = false
	for p in players:
		p.stun = 0.0
		p.tackle_t = 0.0
		p.tackle_recover = 0.0
		p.dive_t = 0.0
		p.dive_recover = 0.0
		p.pending_kick = null
		p.kick_lock = 0.0
	restart_taker = teams[team].ai.pick_restart_taker(type, spot)
	restart_positions = {}
	for tm in teams:
		restart_positions.merge(tm.ai.restart_positions(type, team, spot, restart_taker))
	var inward := Vector2.ZERO
	match type:
		Restart.THROW_IN:
			inward = Vector2(0.0, -signf(spot.y))
		Restart.CORNER:
			inward = Vector2(-signf(spot.x), -signf(spot.y)).normalized()
		_:
			inward = Vector2(teams[team].dir, 0.0)
	restart_positions[restart_taker] = spot - inward * 0.45
	players[restart_taker].cmd.face = inward
	for tm in teams:
		tm.ai.on_restart()
	if human != null:
		human.on_restart()
	emit(&"restart", {"type": type, "team": team})


func _snap_restart_positions() -> void:
	for p in players:
		if restart_positions.has(p.id):
			var tgt: Vector2 = restart_positions[p.id]
			if p.pos.distance_to(tgt) > 0.6:
				p.pos = tgt
			p.vel = Vector2.ZERO
	var tk := players[restart_taker]
	var to_ball := ball.pos - tk.pos
	if to_ball.length() > 0.01:
		tk.facing = to_ball.normalized()
