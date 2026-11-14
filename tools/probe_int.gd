extends SceneTree
## Debug: list intercepted passes with the passer's own estimate.
func _init() -> void:
	var sim := MatchSim.new()
	sim.init_match(MatchSetup.exhibition(3), load("res://data/tuning/default_tuning.tres"))
	var last := {}
	var n := [0]
	sim.event.connect(func(kind: StringName, data: Dictionary) -> void:
		if kind == &"kick":
			var p: SimPlayer = sim.players[int(data["player"])]
			var ag: AIAgent = sim.teams[p.team].ai.agents[p.id]
			var opp := []
			for id in sim.teams[1 - p.team].player_ids:
				var o: SimPlayer = sim.players[id]
				opp.append([id, o.pos, o.vel])
			last.clear()
			last.merge({"t": sim.tick, "p": p.id, "label": ag.decision_label, "from": sim.ball.pos, "target": sim.ball.kick_target, "recv": int(data["receiver"]),
				"pp": (ag.options[0]["p"] if ag.options.size() > 0 else -1.0), "opp": opp, "vel": sim.ball.vel, "press": SimQuery.pressure(sim, p),
				"recv_pos": sim.players[int(data["receiver"])].pos if int(data["receiver"]) >= 0 else Vector2.ZERO})
		elif kind == &"possession" and not last.is_empty():
			var q: SimPlayer = sim.players[int(data["player"])]
			var kp: SimPlayer = sim.players[int(last["p"])]
			if q.team != kp.team and n[0] < 14 and str(last["label"]).begins_with("pass"):
				n[0] += 1
				var seg: Vector2 = (last["target"] as Vector2) - (last["from"] as Vector2)
				var qpos0 := Vector2.ZERO
				var qvel0 := Vector2.ZERO
				for e: Array in last["opp"]:
					if e[0] == q.id:
						qpos0 = e[1]
						qvel0 = e[2]
				var rel := qpos0 - (last["from"] as Vector2)
				var dirn := seg.normalized()
				var aim_err := rad_to_deg((last["vel"] as Vector2).angle_to(seg))
				print("%.1fs %s by #%d p_est=%.2f dist=%.1fm aim_err=%.1f° press=%.2f | interceptor %s#%d was along=%.1f perp=%.1f vel=%.1f | took %.2fs at dist %.1f of %.1f | recv dist to target %.1f" % [
					sim.tick / 60.0, last["label"], kp.number, last["pp"], seg.length(), aim_err, last["press"], SimPlayer.ROLE_NAMES[q.role], q.number,
					rel.dot(dirn), absf(rel.cross(dirn)), qvel0.length(), (sim.tick - int(last["t"])) / 60.0, (q.pos - (last["from"] as Vector2)).length(), seg.length(),
					((last["recv_pos"] as Vector2) - (last["target"] as Vector2)).length()])
			last.clear())
	while sim.state != MatchSim.State.FULL_TIME and n[0] < 14:
		sim.step()
	sim.dispose()
	quit()
