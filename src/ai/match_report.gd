class_name MatchReport
extends RefCounted
## Diagnostics collected from real simulated episodes: used by headless runners
## and AI validation. Metrics supplement observation, they do not replace it.

var sim: MatchSim
var verbose := false
var samples := 0
var crowd_sum := 0.0
var crowd_max := 0
var swarm_ticks := 0          ## ticks with >= 6 outfield players within 7 m of the ball
var width_sum := [0.0, 0.0]
var depth_sum := [0.0, 0.0]
var third_ticks := [0, 0, 0]
var kicks_by_kind := {}
var decisions := {}
var pass_chain: Array[int] = []
var ping_pong := 0            ## A->B->A->B sequences
var restarts := {}
var max_restart_wait := 0.0
var max_keeper_hold := 0.0
var goals: Array = []
var events_log: Array[String] = []
var long_shots := 0
var shot_dist_sum := 0.0
var shots := 0
var min_pair_sum := 0.0
var loss_causes := {}
var _last_cause := ""
var _last_kick_label := ""


func attach(sim_: MatchSim, verbose_ := false) -> void:
	sim = sim_
	verbose = verbose_
	sim.event.connect(_on_event)


func detach() -> void:
	if sim != null and sim.event.is_connected(_on_event):
		sim.event.disconnect(_on_event)
	sim = null


func _on_event(kind: StringName, data: Dictionary) -> void:
	match kind:
		&"kick":
			var k := int(data["kind"])
			kicks_by_kind[k] = int(kicks_by_kind.get(k, 0)) + 1
			_last_cause = ["pass", "through", "lob", "shot", "clear"][k]
			var p: SimPlayer = sim.players[int(data["player"])]
			if k == KickRequest.Kind.SHOT:
				var tm := sim.teams[p.team]
				var d := p.pos.distance_to(Vector2(Pitch.HALF_L * tm.dir, 0.0))
				shots += 1
				shot_dist_sum += d
				if d > 28.0:
					long_shots += 1
				_log("%s SHOT by %s #%d from %.0fm" % [_clock(), tm.short_name, p.number, d])
				pass_chain.clear()
			elif k != KickRequest.Kind.CLEAR:
				pass_chain.append(p.id)
				if pass_chain.size() > 4:
					pass_chain.pop_front()
				if pass_chain.size() == 4 and pass_chain[0] == pass_chain[2] and pass_chain[1] == pass_chain[3]:
					ping_pong += 1
			var ag: AIAgent = sim.teams[p.team].ai.agents[p.id]
			var lbl := ag.decision_label.split(">")[0].split(" ")[0]
			if lbl != "":
				decisions[lbl] = int(decisions.get(lbl, 0)) + 1
		&"possession":
			pass_chain.clear()
			var np: SimPlayer = sim.players[int(data["player"])]
			var loser := sim.teams[1 - np.team]
			var lx := np.pos.x * loser.dir
			var zone := "own3" if lx < -17.5 else ("mid3" if lx < 17.5 else "att3")
			var key := "%s:%s" % [zone, _last_cause if _last_cause != "" else "?"]
			loss_causes[key] = int(loss_causes.get(key, 0)) + 1
			_last_cause = ""
		&"tackle":
			if data["won"]:
				_last_cause = "tackle"
		&"deflect":
			if _last_cause == "":
				_last_cause = "deflect"
		&"save":
			_last_cause = "save"
		&"goal":
			var sc := int(data["scorer"])
			goals.append(data.duplicate())
			_log("%s GOAL %s (%s)%s" % [_clock(), sim.teams[int(data["team"])].short_name, sim.players[sc].pname if sc >= 0 else "?", " OG" if data["own_goal"] else ""])
		&"restart":
			var n: String = MatchSim.RESTART_NAMES[int(data["type"])]
			restarts[n] = int(restarts.get(n, 0)) + 1
			_log("%s restart %s -> %s" % [_clock(), n, sim.teams[int(data["team"])].short_name])
		&"offside":
			_log("%s OFFSIDE #%d" % [_clock(), sim.players[int(data["player"])].number])
		&"save":
			_log("%s save (%s)" % [_clock(), "catch" if data["catch"] else "parry"])
		&"stall":
			_log("%s STALL: free ball not collected" % _clock())


func _clock() -> String:
	return "%5.1fs" % sim.time


func _log(s: String) -> void:
	events_log.append(s)
	if verbose:
		print(s)


func sample() -> void:
	if sim.state == MatchSim.State.RESTART_READY:
		max_restart_wait = maxf(max_restart_wait, sim.restart_ready_t)
	if sim.ball.held_by >= 0:
		max_keeper_hold = maxf(max_keeper_hold, sim.ball.held_time)
	if sim.state != MatchSim.State.PLAYING or sim.tick % 6 != 0:
		return
	samples += 1
	var near := 0
	for p in sim.players:
		if not p.is_keeper() and p.pos.distance_to(sim.ball.pos) < 7.0:
			near += 1
	crowd_sum += near
	crowd_max = maxi(crowd_max, near)
	if near >= 6:
		swarm_ticks += 1
	var bx := sim.ball.pos.x
	third_ticks[0 if bx < -17.5 else (1 if bx < 17.5 else 2)] += 1
	for ti in 2:
		var minx := INF
		var maxx := -INF
		var miny := INF
		var maxy := -INF
		var ids := sim.teams[ti].player_ids
		var min_pair := INF
		for id in ids:
			var p: SimPlayer = sim.players[id]
			if p.is_keeper():
				continue
			minx = minf(minx, p.pos.x)
			maxx = maxf(maxx, p.pos.x)
			miny = minf(miny, p.pos.y)
			maxy = maxf(maxy, p.pos.y)
			for id2 in ids:
				if id2 > id and not sim.players[id2].is_keeper():
					min_pair = minf(min_pair, p.pos.distance_to(sim.players[id2].pos))
		width_sum[ti] += maxy - miny
		depth_sum[ti] += maxx - minx
		min_pair_sum += min_pair


func summary() -> String:
	var out := PackedStringArray()
	var tot := float(maxi(1, sim.teams[0].stats.possession_ticks + sim.teams[1].stats.possession_ticks))
	for ti in 2:
		var tm := sim.teams[ti]
		var st := tm.stats
		out.append("  %s: poss %2.0f%% | pass %d/%d (%2.0f%%) | shots %d (on %d, xG %.2f) | goals %d | int %d | tackles %d/%d | turnovers %d | offs %d | corners %d | throws %d | gk %d | saves %d" % [
			tm.short_name, 100.0 * st.possession_ticks / tot, st.passes_completed, st.passes, 100.0 * st.passes_completed / maxf(1.0, st.passes),
			st.shots, st.shots_on_target, st.xg, st.goals, st.interceptions, st.tackles_won, st.tackles, st.turnovers, st.offsides, st.corners, st.throw_ins, st.goal_kicks, st.saves])
		var ph := PackedStringArray()
		var ptot := 0
		for v in tm.ai.phase_ticks:
			ptot += v
		for i in tm.ai.phase_ticks.size():
			ph.append("%s %2.0f%%" % [TeamAI.PHASE_NAMES[i], 100.0 * tm.ai.phase_ticks[i] / float(maxi(1, ptot))])
		out.append("     phases: %s | conflicts %d | width %.0fm depth %.0fm" % [", ".join(ph), tm.ai.conflicts, width_sum[ti] / maxf(1, samples), depth_sum[ti] / maxf(1, samples)])
	var s := float(maxi(1, samples))
	out.append("  ball crowd avg %.2f max %d | swarm %.1f%% | min teammate gap avg %.1fm | thirds %2.0f/%2.0f/%2.0f%% | ping-pong %d | stalls %d" % [
		crowd_sum / s, crowd_max, 100.0 * swarm_ticks / s, min_pair_sum / (2.0 * s), 100.0 * third_ticks[0] / s, 100.0 * third_ticks[1] / s, 100.0 * third_ticks[2] / s, ping_pong, sim.stalls])
	out.append("  shots avg dist %.1fm, long(>28m) %d | restarts %s | max restart wait %.1fs | max keeper hold %.1fs" % [shot_dist_sum / maxf(1, shots), long_shots, str(restarts), max_restart_wait, max_keeper_hold])
	var lc := loss_causes.keys()
	lc.sort()
	var lcs := PackedStringArray()
	for k2: String in lc:
		lcs.append("%s %d" % [k2, loss_causes[k2]])
	out.append("  possession losses (zone of losing team : cause): %s" % ", ".join(lcs))
	out.append("  kicks: %s | decisions T0 %s | T1 %s" % [str(decisions), str(sim.teams[0].ai.decision_counts), str(sim.teams[1].ai.decision_counts)])
	return "\n".join(out)
