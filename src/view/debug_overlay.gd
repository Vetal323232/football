extends Control
## F3 AI diagnostics drawn over the 3D view: roles, duties, targets, pressing
## assignments, team phases, and for the selected player the candidate options
## (pass lanes with success estimate and expected value) with decision reasons.
## Tab cycles the selected player; by default it follows the ball carrier.

var sim: MatchSim
var cam: Camera3D
var selected := -1
var follow_ball := true
var _font: Font


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = ThemeDB.fallback_font
	visible = false


func cycle_selection() -> void:
	follow_ball = false
	selected = (selected + 1) % sim.players.size()
	if selected == 0:
		follow_ball = true


func _process(_d: float) -> void:
	if visible:
		queue_redraw()


func _w(p: Vector2, h := 0.05) -> Vector2:
	return cam.unproject_position(Vector3(p.x, h, p.y))


func _line3(a: Vector2, b: Vector2, c: Color, w := 1.5) -> void:
	var a3 := Vector3(a.x, 0.05, a.y)
	var b3 := Vector3(b.x, 0.05, b.y)
	if cam.is_position_behind(a3) or cam.is_position_behind(b3):
		return
	draw_line(cam.unproject_position(a3), cam.unproject_position(b3), c, w, true)


func _draw() -> void:
	if sim == null or cam == null:
		return
	var b := sim.ball
	if follow_ball:
		if b.owner >= 0:
			selected = b.owner
		elif sim.human != null and selected < 0:
			selected = sim.human.controlled
	# Team header.
	var y := 100.0
	for tm in sim.teams:
		var ai: TeamAI = tm.ai
		var txt := "%s: %s %s  press=%s cover=%s  impatience %.2f  offside line %.1f  conflicts %d" % [
			tm.short_name, "ATT" if ai.attacking else "DEF", TeamAI.PHASE_NAMES[ai.phase],
			_num(ai.presser_id), _num(ai.cover_id), ai.impatience, ai.off_line, ai.conflicts]
		draw_string_outline(_font, Vector2(28, y), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, 4, Color.BLACK)
		draw_string(_font, Vector2(28, y), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, tm.kit.lightened(0.5))
		y += 22.0
	var st := "tick %d  state %s  poss T%d loose=%s  ball h=%.1f v=%.1f  owner=%s" % [sim.tick, MatchSim.State.keys()[sim.state], sim.poss_team, str(sim.loose), b.h, b.vel.length(), _num(b.owner)]
	draw_string_outline(_font, Vector2(28, y), st, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, 4, Color.BLACK)
	draw_string(_font, Vector2(28, y), st, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)

	# Ball path prediction.
	if b.is_free():
		var path := sim.ball_path()
		for i in range(1, path.size()):
			_line3(Vector2(path[i - 1].x, path[i - 1].y), Vector2(path[i].x, path[i].y), Color(1, 1, 1, 0.5), 1.0)

	for p in sim.players:
		var tm := sim.teams[p.team]
		var ag: AIAgent = tm.ai.agents[p.id]
		var col := tm.kit.lightened(0.35)
		if cam.is_position_behind(Vector3(p.pos.x, 0, p.pos.y)):
			continue
		if not p.is_human and ag.duty != AIAgent.Duty.CARRIER:
			_line3(p.pos, ag.target if ag.run_state != 1 else ag.run_target, Color(col, 0.55), 1.0)
		if ag.duty == AIAgent.Duty.PRESS:
			_line3(p.pos, b.pos, Color(1.0, 0.45, 0.0), 3.0)
		elif ag.duty == AIAgent.Duty.COVER:
			_line3(p.pos, ag.target, Color(1.0, 0.95, 0.2), 2.5)
		elif ag.duty == AIAgent.Duty.MARK and ag.mark_id >= 0:
			_line3(p.pos, sim.players[ag.mark_id].pos, Color(0.8, 0.8, 0.8, 0.7), 1.5)
		var sp := _w(p.pos, 2.1)
		var tag := "%s %s" % [SimPlayer.ROLE_NAMES[p.role], "HUMAN" if p.is_human else AIAgent.DUTY_NAMES[ag.duty]]
		draw_string_outline(_font, sp + Vector2(-30, 0), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, 4, Color.BLACK)
		draw_string(_font, sp + Vector2(-30, 0), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, col)
		if p.id == selected:
			draw_arc(_w(p.pos), 16.0, 0, TAU, 20, Color.WHITE, 2.0)

	# Selected player detail.
	if selected < 0 or selected >= sim.players.size():
		return
	var sp2: SimPlayer = sim.players[selected]
	var tm2 := sim.teams[sp2.team]
	var ag2: AIAgent = tm2.ai.agents[sp2.id]
	var lines := PackedStringArray()
	lines.append("#%d %s (%s)  duty %s — %s" % [sp2.number, sp2.pname, SimPlayer.ROLE_NAMES[sp2.role], AIAgent.DUTY_NAMES[ag2.duty], ag2.reason])
	lines.append("stamina %.2f  speed %.1f  run_state %d  engage %s  decision: %s" % [sp2.stamina, sp2.vel.length(), ag2.run_state, str(ag2.engage), ag2.decision_label])
	if b.owner == sp2.id or b.held_by == sp2.id:
		for o: Dictionary in ag2.options:
			lines.append("   %-16s EV %.4f   p %.2f" % [o["label"], o["ev"], o["p"]])
			var pcol := Color(1, 0.2, 0.2).lerp(Color(0.2, 1, 0.3), clampf(float(o["p"]), 0.0, 1.0))
			if o.has("req") or str(o["label"]).begins_with("dribble"):
				_line3(b.pos, o["target"], Color(pcol, 0.9), 2.5 if o == ag2.options[0] else 1.2)
				var tp := _w(o["target"])
				draw_string_outline(_font, tp, "%s %.0f%%" % [o["label"], float(o["p"]) * 100.0], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, 3, Color.BLACK)
				draw_string(_font, tp, "%s %.0f%%" % [o["label"], float(o["p"]) * 100.0], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, pcol)
	var py := size.y - 250.0
	draw_rect(Rect2(20, py - 22, 560, 22.0 * lines.size() + 12), Color(0, 0, 0, 0.6))
	for l in lines:
		draw_string(_font, Vector2(28, py), l, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color.WHITE)
		py += 22.0


func _num(id: int) -> String:
	return "-" if id < 0 else "#%d" % sim.players[id].number
