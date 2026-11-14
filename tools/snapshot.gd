extends SceneTree
## Headless top-down snapshots of a simulated match (no renderer required).
## Usage: godot --headless -s tools/snapshot.gd -- --seed=1 --from=20 --step=1.0 --frames=8 --out=/path/out.png [--log]
## Team 0 red, team 1 blue, keepers yellow/green, ball white. Thin line = AI target, thick = velocity.

const S := 6.0   # pixels per metre
const W := int(110 * S)
const H := int(74 * S)


func _init() -> void:
	var sd := 1
	var from := 10.0
	var step := 1.0
	var frames := 8
	var out := "snapshot.png"
	var do_log := false
	var cols := 2
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--seed="): sd = int(a.trim_prefix("--seed="))
		elif a.begins_with("--from="): from = float(a.trim_prefix("--from="))
		elif a.begins_with("--step="): step = float(a.trim_prefix("--step="))
		elif a.begins_with("--frames="): frames = int(a.trim_prefix("--frames="))
		elif a.begins_with("--out="): out = a.trim_prefix("--out=")
		elif a.begins_with("--cols="): cols = int(a.trim_prefix("--cols="))
		elif a == "--log": do_log = true
	var tuning: GameTuning = load("res://data/tuning/default_tuning.tres")
	var setup := MatchSetup.exhibition(sd)
	var sim := MatchSim.new()
	var report := MatchReport.new()
	report.attach(sim, false)
	sim.init_match(setup, tuning)
	if do_log:
		sim.event.connect(func(kind: StringName, data: Dictionary) -> void:
			if sim.tick * MatchSim.DT < from:
				return
			if kind == &"kick":
				var p: SimPlayer = sim.players[int(data["player"])]
				var ag: AIAgent = sim.teams[p.team].ai.agents[p.id]
				print("%6.2f kick T%d #%d %s at (%.0f,%.0f) spd %.0f  opts: %s" % [sim.tick * MatchSim.DT, p.team, p.number, ag.decision_label, p.pos.x, p.pos.y, data["speed"], _opts(ag)])
			elif kind == &"claim" or kind == &"tackle" or kind == &"deflect" or kind == &"save" or kind == &"restart" or kind == &"goal" or kind == &"offside":
				print("%6.2f %s %s" % [sim.tick * MatchSim.DT, kind, str(data)]))
	var rows := int(ceil(frames / float(cols)))
	var sheet := Image.create(W * cols, H * rows, false, Image.FORMAT_RGB8)
	var next_t := from
	var done := 0
	while done < frames and sim.state != MatchSim.State.FULL_TIME:
		sim.step()
		if sim.tick * MatchSim.DT >= next_t:
			var img := _draw(sim)
			sheet.blit_rect(img, Rect2i(0, 0, W, H), Vector2i((done % cols) * W, (done / cols) * H))
			if do_log:
				print("--- frame %d t=%.1f state=%d phases %s/%s ball(%.1f,%.1f,h%.1f) owner=%d" % [done, sim.tick * MatchSim.DT, sim.state, TeamAI.PHASE_NAMES[sim.teams[0].ai.phase], TeamAI.PHASE_NAMES[sim.teams[1].ai.phase], sim.ball.pos.x, sim.ball.pos.y, sim.ball.h, sim.ball.owner])
				for p in sim.players:
					var ag: AIAgent = sim.teams[p.team].ai.agents[p.id]
					print("   T%d #%-2d %-3s %-7s (%5.1f,%5.1f) v%.1f st%.2f -> (%5.1f,%5.1f) %s | %s" % [p.team, p.number, SimPlayer.ROLE_NAMES[p.role], AIAgent.DUTY_NAMES[ag.duty], p.pos.x, p.pos.y, p.vel.length(), p.stamina, ag.target.x, ag.target.y, ag.reason, ag.decision_label if sim.ball.owner == p.id else ""])
			done += 1
			next_t += step
	sheet.save_png(out)
	print("saved ", out)
	quit()


func _opts(ag: AIAgent) -> String:
	var s := PackedStringArray()
	for o: Dictionary in ag.options.slice(0, 4):
		s.append("%s %.3f(p%.2f)" % [o["label"], o["ev"], o["p"]])
	return ", ".join(s)


func _px(p: Vector2) -> Vector2i:
	return Vector2i(int((p.x + 55.0) * S), int((p.y + 37.0) * S))


func _line(img: Image, a: Vector2, b: Vector2, c: Color, thick := 1) -> void:
	var pa := Vector2(_px(a))
	var pb := Vector2(_px(b))
	var n := int(maxf(absf(pb.x - pa.x), absf(pb.y - pa.y))) + 1
	for i in n + 1:
		var q := pa.lerp(pb, i / float(n))
		for dx in thick:
			for dy in thick:
				var x := int(q.x) + dx
				var y := int(q.y) + dy
				if x >= 0 and y >= 0 and x < W and y < H:
					img.set_pixel(x, y, c)


func _disc(img: Image, p: Vector2, r: int, c: Color) -> void:
	var o := _px(p)
	for dx in range(-r, r + 1):
		for dy in range(-r, r + 1):
			if dx * dx + dy * dy <= r * r:
				var x := o.x + dx
				var y := o.y + dy
				if x >= 0 and y >= 0 and x < W and y < H:
					img.set_pixel(x, y, c)


func _rect(img: Image, a: Vector2, b: Vector2, c: Color) -> void:
	_line(img, a, Vector2(b.x, a.y), c)
	_line(img, Vector2(b.x, a.y), b, c)
	_line(img, b, Vector2(a.x, b.y), c)
	_line(img, Vector2(a.x, b.y), a, c)


func _draw(sim: MatchSim) -> Image:
	var img := Image.create(W, H, false, Image.FORMAT_RGB8)
	img.fill(Color(0.13, 0.4, 0.16))
	var wh := Color(0.85, 0.9, 0.85)
	_rect(img, Vector2(-52.5, -34), Vector2(52.5, 34), wh)
	_line(img, Vector2(0, -34), Vector2(0, 34), wh)
	for s: float in [-1.0, 1.0]:
		_rect(img, Vector2(s * 52.5, -20.16), Vector2(s * 36.0, 20.16), wh)
		_rect(img, Vector2(s * 52.5, -9.16), Vector2(s * 47.0, 9.16), wh)
		_rect(img, Vector2(s * 52.5, -3.66), Vector2(s * 54.5, 3.66), Color.WHITE)
	for p in sim.players:
		var tm := sim.teams[p.team]
		var ag: AIAgent = tm.ai.agents[p.id]
		var col := Color(0.95, 0.2, 0.2) if p.team == 0 else Color(0.3, 0.5, 1.0)
		if p.is_keeper():
			col = Color(1, 0.9, 0.1) if p.team == 0 else Color(0.2, 1, 0.5)
		if ag.duty != AIAgent.Duty.NONE and ag.target != Vector2.ZERO:
			_line(img, p.pos, ag.target, col.darkened(0.35))
		_line(img, p.pos, p.pos + p.vel * 0.6, Color.WHITE, 2)
		_disc(img, p.pos, 5, col)
		# duty marker colour dot
		var dc := Color.BLACK
		match ag.duty:
			AIAgent.Duty.PRESS: dc = Color(1, 0.5, 0)
			AIAgent.Duty.COVER: dc = Color(1, 1, 0)
			AIAgent.Duty.MARK: dc = Color(0.6, 0.6, 0.6)
			AIAgent.Duty.RUNNER: dc = Color(1, 0, 1)
			AIAgent.Duty.SUPPORT: dc = Color(0, 1, 1)
			AIAgent.Duty.CARRIER, AIAgent.Duty.RECEIVER, AIAgent.Duty.CHASE: dc = Color.WHITE
		_disc(img, p.pos, 2, dc)
	_disc(img, sim.ball.pos, 4, Color.BLACK)
	_disc(img, sim.ball.pos, 3, Color.WHITE)
	_line(img, sim.ball.pos, sim.ball.pos + sim.ball.vel * 0.5, Color(1, 1, 0.3))
	return img
