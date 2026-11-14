extends CanvasLayer
## Pause menu (with substitutions) and the full-time result screen.

var view: Node
var _root: Control
var _pause: Control
var _result: Control
var _subs: Control


func _ready() -> void:
	layer = 20
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.theme = UIKit.theme()
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)


func bind(view_: Node) -> void:
	view = view_


func _clear(c: Control) -> void:
	if c != null and is_instance_valid(c):
		c.queue_free()


func _dim() -> ColorRect:
	var d := ColorRect.new()
	d.color = Color(0, 0, 0, 0.55)
	d.set_anchors_preset(Control.PRESET_FULL_RECT)
	return d


func show_pause(on: bool) -> void:
	_clear(_pause)
	_clear(_subs)
	_pause = null
	if not on:
		return
	var sim: MatchSim = view.get("sim")
	_pause = _dim()
	_root.add_child(_pause)
	var panel := UIKit.panel()
	_pause.add_child(UIKit.centered(panel))
	var v := UIKit.vbox(10)
	panel.add_child(v)
	var t := UIKit.label(tr("PAUSE_TITLE"), 40, UIKit.ACCENT)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var first := UIKit.button(tr("PAUSE_RESUME"), func() -> void: view.call("set_paused", false))
	v.add_child(first)
	if sim.human != null:
		var tm := sim.teams[sim.human.team]
		var sb := UIKit.button("%s (%d/5)" % [tr("PAUSE_SUBS"), tm.subs_made], func() -> void: _show_subs())
		sb.disabled = tm.bench.is_empty() or tm.subs_made >= 5
		v.add_child(sb)
	if sim.setup.fixture_id == "":
		v.add_child(UIKit.button(tr("PAUSE_RESTART"), func() -> void: view.call("restart_match")))
	v.add_child(UIKit.button(tr("PAUSE_QUIT"), func() -> void: view.call("leave_match")))
	v.add_child(UIKit.spacer(8))
	v.add_child(UIKit.label(tr("CONTROLS_TEXT"), 17, UIKit.MUTED))
	if sim.setup.fixture_id != "":
		v.add_child(UIKit.label(tr("PAUSE_QUIT_NOTE"), 16, UIKit.MUTED))
	first.grab_focus()


func _show_subs() -> void:
	var sim: MatchSim = view.get("sim")
	var tm := sim.teams[sim.human.team]
	_clear(_subs)
	_subs = _dim()
	_root.add_child(_subs)
	var panel := UIKit.panel()
	_subs.add_child(UIKit.centered(panel))
	var v := UIKit.vbox(6)
	panel.add_child(v)
	v.add_child(UIKit.label(tr("SUBS_PICK_OUT"), 28, UIKit.ACCENT))
	var first: Button = null
	for id in tm.player_ids:
		var p: SimPlayer = sim.players[id]
		var b := UIKit.button("%-3s  %2d  %s   %s %d%%" % [SimPlayer.ROLE_NAMES[p.role], p.number, p.pname, tr("STAMINA"), int(p.fitness * 100.0)],
			func() -> void: _show_bench(id), 520)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_size_override("font_size", 18)
		v.add_child(b)
		if first == null:
			first = b
	v.add_child(UIKit.button(tr("BACK"), func() -> void: show_pause(true), 520))
	first.grab_focus()


func _show_bench(out_id: int) -> void:
	var sim: MatchSim = view.get("sim")
	var tm := sim.teams[sim.human.team]
	_clear(_subs)
	_subs = _dim()
	_root.add_child(_subs)
	var panel := UIKit.panel()
	_subs.add_child(UIKit.centered(panel))
	var v := UIKit.vbox(6)
	panel.add_child(v)
	v.add_child(UIKit.label("%s: %s" % [tr("SUBS_PICK_IN"), sim.players[out_id].pname], 26, UIKit.ACCENT))
	var first: Button = null
	for i in tm.bench.size():
		var d: Dictionary = tm.bench[i]
		var b := UIKit.button("%s  %2d  %s   %s %d" % [str(d.get("pos", "")), int(d.get("number", 0)), str(d.get("name", "")), tr("OVR"), int(d.get("ovr", 0))],
			func() -> void:
				sim.substitute(tm.index, out_id, i)
				show_pause(true), 520)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_size_override("font_size", 18)
		v.add_child(b)
		if first == null:
			first = b
	var back := UIKit.button(tr("BACK"), func() -> void: _show_subs(), 520)
	v.add_child(back)
	(first if first != null else back).grab_focus()


func show_result() -> void:
	_clear(_pause)
	var sim: MatchSim = view.get("sim")
	_result = _dim()
	_root.add_child(_result)
	var panel := UIKit.panel(34)
	_result.add_child(UIKit.centered(panel))
	var v := UIKit.vbox(8)
	panel.add_child(v)
	var t := UIKit.label(tr("FULL_TIME"), 30, UIKit.ACCENT)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var sc := UIKit.label("%s   %d : %d   %s" % [sim.teams[0].tname, sim.teams[0].score, sim.teams[1].score, sim.teams[1].tname], 44)
	sc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sc)
	v.add_child(UIKit.spacer(6))
	var res: Dictionary = Game.last_result
	var st: Array = res["stats"]
	var rows := [
		["STAT_POSSESSION", "%d%%" % st[0]["possession"], "%d%%" % st[1]["possession"]],
		["STAT_SHOTS", str(st[0]["shots"]), str(st[1]["shots"])],
		["STAT_ON_TARGET", str(st[0]["shots_on_target"]), str(st[1]["shots_on_target"])],
		["STAT_XG", "%.2f" % st[0]["xg"], "%.2f" % st[1]["xg"]],
		["STAT_PASSES", "%d/%d" % [st[0]["passes_completed"], st[0]["passes"]], "%d/%d" % [st[1]["passes_completed"], st[1]["passes"]]],
		["STAT_INTERCEPTIONS", str(st[0]["interceptions"]), str(st[1]["interceptions"])],
		["STAT_TACKLES", "%d/%d" % [st[0]["tackles_won"], st[0]["tackles"]], "%d/%d" % [st[1]["tackles_won"], st[1]["tackles"]]],
		["STAT_CORNERS", str(st[0]["corners"]), str(st[1]["corners"])],
		["STAT_OFFSIDES", str(st[0]["offsides"]), str(st[1]["offsides"])],
	]
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 40)
	grid.add_theme_constant_override("v_separation", 4)
	for r: Array in rows:
		var a := UIKit.label(r[1], 22)
		a.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		a.custom_minimum_size = Vector2(140, 0)
		grid.add_child(a)
		var m := UIKit.label(tr(r[0]), 20, UIKit.MUTED)
		m.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		m.custom_minimum_size = Vector2(240, 0)
		grid.add_child(m)
		var b := UIKit.label(r[2], 22)
		b.custom_minimum_size = Vector2(140, 0)
		grid.add_child(b)
	v.add_child(grid)
	v.add_child(UIKit.spacer(10))
	var cont := UIKit.button(tr("CONTINUE"), func() -> void: view.call("leave_match"))
	v.add_child(cont)
	if sim.setup.fixture_id == "":
		v.add_child(UIKit.button(tr("RESULT_REMATCH"), func() -> void: view.call("restart_match")))
	cont.grab_focus()


func show_scenario_result(text: String) -> void:
	_clear(_result)
	_result = Control.new()
	_result.set_anchors_preset(Control.PRESET_FULL_RECT)
	_result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_result)
	var panel := UIKit.panel(20)
	UIKit.place(panel, 0.5, 1.0, 0.5, 1.0, -520, -330, 520, -230)
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_result.add_child(panel)
	var v := UIKit.vbox(8)
	panel.add_child(v)
	var l := UIKit.label(text, 18)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(1000, 0)
	v.add_child(l)
	var h := UIKit.hbox(10)
	v.add_child(h)
	var again := UIKit.button(tr("DIAG_NEXT_SEED"), func() -> void: view.call("next_scenario_run", 0), 240)
	h.add_child(again)
	h.add_child(UIKit.button(tr("DIAG_NEXT_VARIANT"), func() -> void: view.call("next_scenario_run", 1), 240))
	h.add_child(UIKit.button(tr("BACK"), func() -> void: view.call("leave_match"), 200))
	again.grab_focus()
