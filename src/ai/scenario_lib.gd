class_name ScenarioLib
extends RefCounted
## Reproducible diagnostic situations for AI validation (brief section 7).
## A scenario only arranges the initial state (positions, ball, possession);
## from there the normal production AI plays. Team 0 ("A") attacks toward +x.
## Each scenario has 3 variants that change pressure / placement, plus seeded jitter.

const R := SimPlayer.Role
const NAMES: Array[String] = ["buildup_pressure", "blocked_lane", "attack_3v2", "wing_defence", "high_loss", "run_behind", "shot_rebound", "human_support"]
const TITLES := {
	"buildup_pressure": "Розыгрыш под прессингом",
	"blocked_lane": "Перекрытая линия передачи",
	"attack_3v2": "Атака 3 в 2",
	"wing_defence": "Соперник с мячом на фланге",
	"high_loss": "Потеря мяча высоко",
	"run_behind": "Забегание за спину защите",
	"shot_rebound": "Удар и отскок",
	"human_support": "Партнёр под управлением человека",
}
const DURATION := {
	"buildup_pressure": 9.0, "blocked_lane": 5.0, "attack_3v2": 10.0, "wing_defence": 6.0,
	"high_loss": 7.0, "run_behind": 7.0, "shot_rebound": 6.0, "human_support": 6.0,
}


static func make_setup(scenario: String, variant: int, seed_: int) -> MatchSetup:
	var s := MatchSetup.exhibition(seed_)
	s.scenario = scenario
	s.variant = variant
	s.difficulty = 2
	if scenario == "human_support":
		s.human_team = 0
	return s


static func _pl(sim: MatchSim, team: int, role: int) -> SimPlayer:
	return sim.players[sim.teams[team].player_ids[role]]


static func _put(sim: MatchSim, team: int, role: int, local_pos: Vector2, rng: RandomNumberGenerator, jitter := 1.0) -> SimPlayer:
	var p := _pl(sim, team, role)
	var j := Vector2(rng.randf_range(-jitter, jitter), rng.randf_range(-jitter, jitter))
	p.pos = Pitch.clamp_inside((local_pos + j) * sim.teams[team].dir, 0.5)
	p.vel = Vector2.ZERO
	return p


static func _shape(sim: MatchSim, team: int, attacking: bool, ball_world: Vector2) -> void:
	var tm := sim.teams[team]
	var bl := ball_world * tm.dir
	for id in tm.player_ids:
		var p: SimPlayer = sim.players[id]
		var a := AIShape.attack_anchor(p.role, bl, tm.tactics, bl.x + 24.0) if attacking else AIShape.defend_anchor(p.role, bl, tm.tactics)
		p.pos = a * tm.dir
		p.vel = Vector2.ZERO
		p.facing = Vector2(tm.dir, 0.0)
		p.stamina = 1.0


static func _start(sim: MatchSim, owner: SimPlayer, ball_world := Vector2.INF) -> void:
	var b := sim.ball
	sim.state = MatchSim.State.PLAYING
	sim.freeze_clock = true
	b.dead = false
	b.held_by = -1
	b.vel = Vector2.ZERO
	b.vh = 0.0
	b.h = 0.0
	b.in_pass = false
	b.restart_taker = -1
	b.kick_kind = -1
	sim.offside_flags.clear()
	if owner != null:
		b.owner = owner.id
		b.pos = owner.pos + owner.facing * 0.5
		b.last_touch = owner.id
		b.last_touch_team = owner.team
		sim.poss_team = owner.team
		sim.poss_player = owner.id
		sim.loose = false
	else:
		b.owner = -1
		b.pos = ball_world
		sim.loose = true
	sim.poss_change_tick = sim.tick
	for tm in sim.teams:
		tm.ai.on_restart()
		tm.ai.attacking = owner != null and owner.team == tm.index
		tm.ai._pending_side = tm.ai.attacking
	if sim.human != null:
		sim.human.controlled = -1
		for p in sim.players:
			p.is_human = false


## Arrange the situation. Call right after MatchSim.init_match().
static func apply(sim: MatchSim, scenario: String, variant: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = sim.setup.seed * 31 + variant * 7 + hash(scenario) % 1000
	match scenario:
		"buildup_pressure":
			var ball := Vector2(-34.0, -8.0)
			_shape(sim, 0, true, ball)
			_shape(sim, 1, false, ball)
			var c := _put(sim, 0, R.LCB, ball, rng)
			var dist: float = [4.5, 6.5, 9.0][variant]
			# B's front three step up to press (positions in A's frame -> convert to B local by negating).
			_put(sim, 1, R.ST, -(c.pos + Vector2(dist, 1.0)), rng, 0.5)
			_put(sim, 1, R.RW, -(Vector2(-30.0, -22.0) + Vector2(dist, 0)), rng)
			_put(sim, 1, R.LW, -(Vector2(-33.0, 8.0) + Vector2(dist, 0)), rng)
			_start(sim, c)
		"blocked_lane":
			var ball2 := Vector2(-5.0, -4.0)
			_shape(sim, 0, true, ball2)
			_shape(sim, 1, false, ball2)
			var c2 := _put(sim, 0, R.LCM, ball2, rng, 0.5)
			_put(sim, 0, R.ST, Vector2(13.0, -4.0), rng, 0.5)
			_put(sim, 0, R.LW, Vector2(8.0, -24.0), rng)
			# Blocker: in the lane (0, 2) or well off it (1).
			var by: float = [-4.0, 9.0, -4.0][variant]
			_put(sim, 1, R.DM, -Vector2(4.0, by), rng, 0.3)
			if variant == 2:
				_put(sim, 1, R.RB, -Vector2(16.0, -14.0), rng)  # leaves A's left winger free
			_start(sim, c2)
		"attack_3v2":
			var ball3 := Vector2(8.0, [0.0, -6.0, 5.0][variant])
			_shape(sim, 0, true, Vector2(-15.0, 0.0))
			_shape(sim, 1, false, Vector2(30.0, 0.0) * -1.0)
			# B was caught upfield: only two centre-backs and the keeper are back.
			for role: int in [R.LB, R.RB, R.DM, R.LCM, R.RCM, R.LW, R.RW, R.ST]:
				var p := _pl(sim, 1, role)
				p.pos = Vector2(rng.randf_range(-22.0, -10.0), AIShape.side_of(role) * -14.0 + rng.randf_range(-6.0, 6.0))
			_put(sim, 1, R.LCB, -Vector2(27.0, 5.0), rng)
			_put(sim, 1, R.RCB, -Vector2(27.0, -5.0), rng)
			var c3 := _put(sim, 0, R.ST, ball3, rng, 0.5)
			_put(sim, 0, R.LW, Vector2(9.0, -17.0), rng)
			_put(sim, 0, R.RW, Vector2(9.0, 17.0), rng)
			c3.vel = Vector2(5.0, 0.0)
			_start(sim, c3)
		"wing_defence":
			# B winger has the ball on A's left flank (A defends).
			var ballw := Vector2([-24.0, -30.0, -18.0][variant], -27.0)
			_shape(sim, 0, false, ballw)
			_shape(sim, 1, true, ballw)
			var c4 := _put(sim, 1, R.RW, -ballw, rng, 0.5)
			c4.facing = Vector2(-1.0, 0.0)
			_start(sim, c4)
		"high_loss":
			# A was attacking around B's box and has just lost the ball to a B centre-back.
			var focus := Vector2(30.0, [4.0, -12.0, 0.0][variant])
			_shape(sim, 0, true, focus)
			_shape(sim, 1, false, focus)
			var c5 := _put(sim, 1, R.LCB, -(focus + Vector2(5.0, 1.0)), rng, 0.5)
			c5.facing = Vector2(-1.0, 0.0)
			_start(sim, c5)
			sim.teams[0].ai.attacking = true   # A still thinks it attacks: must notice the loss
			sim.teams[0].ai._pending_side = true
		"run_behind":
			var ball6 := Vector2(-4.0, [6.0, -8.0, 0.0][variant])
			_shape(sim, 0, true, ball6)
			_shape(sim, 1, false, ball6)
			var c6 := _put(sim, 0, R.RCM, ball6, rng, 0.5)
			# Give the carrier time on the ball: nearest B midfielders start a few metres off.
			_put(sim, 1, R.LCM, -(ball6 + Vector2(9.0, 4.0)), rng)
			_put(sim, 1, R.DM, -(ball6 + Vector2(11.0, -3.0)), rng)
			_start(sim, c6)
		"shot_rebound":
			var ball7 := Vector2([35.0, 33.0, 38.0][variant], [2.0, -8.0, 6.0][variant])
			_shape(sim, 0, true, ball7)
			_shape(sim, 1, false, ball7)
			var c7 := _put(sim, 0, R.ST, ball7, rng, 0.3)
			_put(sim, 1, R.LCB, -(ball7 + Vector2(3.0, 5.0)), rng, 0.5)
			_put(sim, 1, R.RCB, -(ball7 + Vector2(3.0, -5.0)), rng, 0.5)
			c7.facing = Vector2(1.0, 0.0)
			_start(sim, c7)
		"human_support":
			var ball8 := Vector2(-8.0, [-5.0, 8.0, 0.0][variant])
			_shape(sim, 0, true, ball8)
			_shape(sim, 1, false, ball8)
			var c8 := _put(sim, 0, R.LCM, ball8, rng, 0.5)
			_start(sim, c8)
			sim.human._set_controlled(c8.id)


## Per-tick observation. `obs` accumulates facts used by judge().
static func observe(sim: MatchSim, scenario: String, obs: Dictionary) -> void:
	var t: int = obs.get("ticks", 0)
	obs["ticks"] = t + 1
	var b := sim.ball
	var a_ai: TeamAI = sim.teams[0].ai
	if not obs.has("init"):
		obs["init"] = true
		obs["start_tick"] = sim.tick
		obs["start_x"] = b.pos.x
		obs["kicks"] = []
		obs["shots0"] = sim.teams[0].stats.shots
		obs["shots1"] = sim.teams[1].stats.shots
		obs["xg0"] = sim.teams[0].stats.xg
		obs["xg1"] = sim.teams[1].stats.xg
		obs["pc0"] = sim.teams[0].stats.passes_completed
		obs["goals0"] = sim.teams[0].score
		obs["goals1"] = sim.teams[1].score
		obs["offs0"] = sim.teams[0].stats.offsides
		obs["samples"] = 0
		obs["press1"] = 0
		obs["cover"] = 0
		obs["central"] = 0
		obs["swarm_def"] = 0
		obs["swarm_att"] = 0
		obs["lane_sep_sum"] = 0.0
		obs["run_seen"] = false
		obs["human_override"] = 0
		obs["none_duty"] = 0
		obs["keeper_start"] = _pl(sim, 1, R.GK).pos
		obs["keeper_moved"] = 0.0
		obs["first_opts"] = -1
		sim.event.connect(func(kind: StringName, data: Dictionary) -> void:
			if kind == &"kick":
				(obs["kicks"] as Array).append({"t": sim.tick - int(obs["start_tick"]), "player": int(data["player"]), "kind": int(data["kind"]), "recv": int(data["receiver"])})
			elif kind == &"possession":
				if not obs.has("first_change"):
					obs["first_change"] = {"t": sim.tick - int(obs["start_tick"]), "team": int(data["team"]), "x": b.pos.x, "player": int(data["player"])}
			elif kind == &"restart":
				if not obs.has("restart"):
					obs["restart"] = {"t": sim.tick - int(obs["start_tick"]), "type": int(data["type"]), "team": int(data["team"])}
			elif kind == &"save" or kind == &"post":
				if not obs.has("rebound_t"):
					obs["rebound_t"] = sim.tick
					obs["rebound_catch"] = bool(data.get("catch", false))
			elif kind == &"claim" or kind == &"goal":
				if obs.has("rebound_t") and not obs.has("resolved_t"):
					obs["resolved_t"] = sim.tick
			elif kind == &"control":
				obs["control_changes"] = int(obs.get("control_changes", 0)) + 1)
	if sim.state != MatchSim.State.PLAYING:
		return
	# Options visible to A's carrier at his first real decision.
	if int(obs["first_opts"]) < 0 and b.owner >= 0 and sim.players[b.owner].team == 0:
		var ag: AIAgent = a_ai.agents[b.owner]
		if ag.options.size() > 0:
			var n := 0
			for o: Dictionary in ag.options:
				if o.has("req") and float(o["p"]) >= 0.6 and not str(o["label"]).begins_with("shoot"):
					n += 1
			obs["first_opts"] = n
	for id in sim.teams[0].player_ids:
		var ag2: AIAgent = a_ai.agents[id]
		if ag2.run_state == 1:
			obs["run_seen"] = true
	obs["keeper_moved"] = maxf(float(obs["keeper_moved"]), _pl(sim, 1, R.GK).pos.distance_to(obs["keeper_start"]))
	if t % 6 != 0:
		return
	# Defensive scenarios are judged only while the opponent actually controls the ball.
	if (scenario == "wing_defence" or scenario == "high_loss") and not (b.owner >= 0 and sim.players[b.owner].team == 1):
		return
	obs["samples"] = int(obs["samples"]) + 1
	var press := 0
	var cover := 0
	var central := 0
	var near_def := 0
	var near_att := 0
	for id in sim.teams[0].player_ids:
		var p: SimPlayer = sim.players[id]
		var ag3: AIAgent = a_ai.agents[id]
		if p.is_keeper():
			continue
		if ag3.duty == AIAgent.Duty.PRESS or ag3.duty == AIAgent.Duty.CHASE:
			press += 1
		elif ag3.duty == AIAgent.Duty.COVER:
			cover += 1
		if ag3.duty == AIAgent.Duty.NONE:
			obs["none_duty"] = int(obs["none_duty"]) + 1
		if p.pos.x < -30.0 and absf(p.pos.y) < 14.0:
			central += 1
		if p.pos.distance_to(b.pos) < 5.0:
			near_def += 1
		if p.pos.distance_to(b.pos) < 7.0:
			near_att += 1
	if press == 1:
		obs["press1"] = int(obs["press1"]) + 1
	if cover >= 1:
		obs["cover"] = int(obs["cover"]) + 1
	if central >= 2:
		obs["central"] = int(obs["central"]) + 1
	if near_def >= 3:
		obs["swarm_def"] = int(obs["swarm_def"]) + 1
	if near_att >= 4:
		obs["swarm_att"] = int(obs["swarm_att"]) + 1
	var ys := [_pl(sim, 0, R.LW).pos.y, _pl(sim, 0, R.ST).pos.y, _pl(sim, 0, R.RW).pos.y]
	ys.sort()
	obs["lane_sep_sum"] = float(obs["lane_sep_sum"]) + minf(ys[1] - ys[0], ys[2] - ys[1])


static func _ratio(obs: Dictionary, key: String) -> float:
	return float(obs[key]) / maxf(1.0, float(obs["samples"]))


## Verdict from the observations: {ok, fail: [invariants violated], notes}.
static func judge(sim: MatchSim, scenario: String, variant: int, obs: Dictionary) -> Dictionary:
	var fail := PackedStringArray()
	var notes := PackedStringArray()
	var kicks: Array = obs["kicks"]
	var fc: Dictionary = obs.get("first_change", {})
	var shots0 := sim.teams[0].stats.shots - int(obs["shots0"])
	var shots1 := sim.teams[1].stats.shots - int(obs["shots1"])
	var goals0 := sim.teams[0].score - int(obs["goals0"])
	var goals1 := sim.teams[1].score - int(obs["goals1"])
	var completed := sim.teams[0].stats.passes_completed - int(obs["pc0"])
	var ok := true
	match scenario:
		"buildup_pressure":
			var lost_own := not fc.is_empty() and int(fc["team"]) == 1 and float(fc["x"]) < -17.5
			var progressed := sim.ball.pos.x > float(obs["start_x"]) + 10.0
			notes.append("pass options p>=0.6 at first decision: %d; completed passes %d; ball x %.0f -> %.0f" % [obs["first_opts"], completed, obs["start_x"], sim.ball.pos.x])
			if lost_own:
				fail.append("lost the ball in own third at t=%.1fs" % (int(fc["t"]) / 60.0))
			if _ratio(obs, "swarm_att") > 0.15:
				fail.append("teammates crowd the ball (%.0f%%)" % (100.0 * _ratio(obs, "swarm_att")))
			ok = not lost_own and (completed >= 1 or progressed)
			if completed < 1 and not progressed:
				fail.append("no completed pass and no progress")
		"blocked_lane":
			var st_id := _pl(sim, 0, R.ST).id
			var first: Dictionary = kicks[0] if kicks.size() > 0 else {}
			var to_st := not first.is_empty() and int(first["recv"]) == st_id and int(first["kind"]) == KickRequest.Kind.PASS
			var intercepted := not fc.is_empty() and int(fc["team"]) == 1 and kicks.size() <= 1
			notes.append("first action: %s" % (("kick kind %d to #%d at %.1fs" % [first["kind"], sim.players[int(first["recv"])].number if int(first["recv"]) >= 0 else 0, int(first["t"]) / 60.0]) if not first.is_empty() else "kept the ball (dribble/hold)"))
			if variant != 1 and to_st:
				fail.append("ground pass straight into the blocked lane")
			if intercepted:
				fail.append("first pass intercepted")
			if variant == 1:
				notes.append("lane open: pass to striker %s" % ("chosen" if to_st else "not chosen"))
			ok = fail.is_empty()
		"attack_3v2":
			var sep := float(obs["lane_sep_sum"]) / maxf(1.0, float(obs["samples"]))
			var xg := sim.teams[0].stats.xg - float(obs["xg0"])
			notes.append("shots %d (xG %.2f), goals %d, passes %d, min lane separation avg %.1fm" % [shots0, xg, goals0, kicks.size() - shots0, sep])
			if shots0 == 0:
				fail.append("no shot within the time limit")
			if sep < 6.0:
				fail.append("attackers share a lane")
			if sim.teams[0].stats.offsides - int(obs["offs0"]) > 0:
				fail.append("attack ended offside")
			ok = shots0 >= 1 and sep >= 6.0
		"wing_defence":
			notes.append("exactly one presser %.0f%%, cover set %.0f%%, >=2 central defenders %.0f%%, 3+ defenders within 5m of ball %.0f%%, shots conceded %d" % [
				100.0 * _ratio(obs, "press1"), 100.0 * _ratio(obs, "cover"), 100.0 * _ratio(obs, "central"), 100.0 * _ratio(obs, "swarm_def"), shots1])
			if _ratio(obs, "press1") < 0.85:
				fail.append("no single clear presser")
			if _ratio(obs, "cover") < 0.75:
				fail.append("no cover behind the presser")
			if _ratio(obs, "central") < 0.85:
				fail.append("centre abandoned")
			if _ratio(obs, "swarm_def") > 0.1:
				fail.append("defenders swarm the ball")
			ok = fail.is_empty()
		"high_loss":
			var behind := 0
			for id in sim.teams[0].player_ids:
				var p: SimPlayer = sim.players[id]
				if not p.is_keeper() and p.pos.x < sim.ball.pos.x + 2.0:
					behind += 1
			var xg1 := sim.teams[1].stats.xg - float(obs["xg1"])
			notes.append("one presser/chaser %.0f%%, players goal-side at end %d, ball x at end %.0f, B shots %d (xG %.2f), swarm %.0f%%" % [
				100.0 * _ratio(obs, "press1"), behind, sim.ball.pos.x, shots1, xg1, 100.0 * _ratio(obs, "swarm_def")])
			if _ratio(obs, "press1") < 0.7:
				fail.append("delaying/pressing role not clearly assigned")
			if behind < 5 and sim.ball.pos.x < 20.0:
				fail.append("too few players recovered behind the ball")
			if _ratio(obs, "swarm_def") > 0.15:
				fail.append("everyone rushes the ball")
			if goals1 > 0:
				fail.append("conceded within seconds of the loss")
			ok = fail.is_empty()
		"run_behind":
			var through := false
			for k: Dictionary in kicks:
				if int(k["kind"]) == KickRequest.Kind.THROUGH or int(k["kind"]) == KickRequest.Kind.LOB:
					through = true
			var offs := sim.teams[0].stats.offsides - int(obs["offs0"])
			notes.append("run made: %s, through/lofted ball played: %s, offside calls %d, ball x %.0f -> %.0f" % [str(obs["run_seen"]), str(through), offs, obs["start_x"], sim.ball.pos.x])
			if not bool(obs["run_seen"]):
				fail.append("nobody ran in behind")
			if offs > 0:
				notes.append("run was caught offside")
			ok = bool(obs["run_seen"])
		"shot_rebound":
			var resolved := goals0 > 0 or obs.has("resolved_t") or obs.has("restart") or sim.ball.held_by >= 0 or sim.ball.owner >= 0
			var how := "goal" if goals0 > 0 else ("keeper holds" if sim.ball.held_by >= 0 else ("restart" if obs.has("restart") else ("claimed by #%d" % sim.players[sim.ball.owner].number if sim.ball.owner >= 0 else "loose")))
			notes.append("shots %d, keeper moved %.1fm, rebound event: %s, outcome: %s, stalls %d" % [shots0, obs["keeper_moved"], str(obs.has("rebound_t")), how, sim.stalls])
			if shots0 == 0:
				fail.append("no shot was taken")
			if not resolved:
				fail.append("loose ball not dealt with")
			if float(obs["keeper_moved"]) < 0.3 and goals0 == 0 and shots0 > 0:
				notes.append("keeper barely moved (shot straight at him or off target)")
			ok = shots0 >= 1 and resolved
		"human_support":
			notes.append("options p>=0.6 offered to the human at pass time: %d; control hand-offs %d; ticks where AI overrode human input %d; players without duty (samples) %d" % [
				obs.get("human_opts", -1), obs.get("control_changes", 0), obs["human_override"], obs["none_duty"]])
			if int(obs.get("human_opts", 0)) < 2:
				fail.append("fewer than two usable passing options")
			if int(obs["human_override"]) > 0:
				fail.append("AI movement fought human input")
			if not bool(obs.get("handoff_ok", false)):
				fail.append("control did not follow the pass to the receiver")
			ok = fail.is_empty()
	return {"ok": ok, "fail": fail, "notes": notes}


## Scripted "human" input for the human_support scenario and the forced shot in
## shot_rebound. This drives only the controlled player, never the AI.
static func drive_inputs(sim: MatchSim, scenario: String, obs: Dictionary) -> void:
	var t := sim.tick - int(obs.get("start_tick", sim.tick))
	if scenario == "shot_rebound" and t == 12:
		var st := _pl(sim, 0, R.ST)
		if sim.ball.owner == st.id:
			st.pending_kick = KickPlanner.plan_ai_shot(sim, st)
			st.pending_kick_t = 0.3
	if scenario != "human_support" or sim.human == null:
		return
	var f := sim.human.input
	f.move = Vector2(0.45, 0.0) if t < 70 else Vector2(1.0, 0.0)
	f.sprint = false
	if t == 70:
		# Count real options just before passing (same evaluation the AI uses).
		var p: SimPlayer = sim.players[sim.human.controlled]
		var n := 0
		for id in sim.teams[0].player_ids:
			if id == p.id or sim.players[id].is_keeper():
				continue
			var m: SimPlayer = sim.players[id]
			if m.pos.distance_to(p.pos) < 30.0 and float(KickPlanner.plan_ground(sim, p, m)["p"]) >= 0.6:
				n += 1
		obs["human_opts"] = n
		f.pass_pressed = true
		obs["pass_from"] = p.id
	if t == 72 and obs.has("pass_from"):
		obs["pass_recv"] = sim.ball.kick_receiver
	if t > 75 and t < 200 and obs.has("pass_recv") and not obs.has("handoff_ok"):
		if sim.human.controlled == int(obs["pass_recv"]) and int(obs["pass_recv"]) >= 0:
			obs["handoff_ok"] = true
	if t == 230:
		f.switch_pressed = true


## After the sim step: verify the AI did not overwrite the human's movement command.
static func post_step(sim: MatchSim, scenario: String, obs: Dictionary) -> void:
	if scenario != "human_support" or sim.human == null or sim.human.controlled < 0:
		return
	var p: SimPlayer = sim.players[sim.human.controlled]
	if sim.state == MatchSim.State.PLAYING and p.cmd.move.distance_to(sim.human.input.move.limit_length(1.0)) > 0.01:
		obs["human_override"] = int(obs["human_override"]) + 1
