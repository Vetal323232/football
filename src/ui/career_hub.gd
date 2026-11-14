extends Control
## Career screens: entry (continue / new), club selection, hub, lineup, table,
## fixtures, transfers, round results and season summary. Keyboard driven.

const SLOT_NAMES: Array[String] = ["ВР", "ЛЗ", "ЦЗ", "ЦЗ", "ПЗ", "ОП", "ЦП", "ЦП", "ЛН", "ЦН", "ПН"]
const POS_NAMES := {"GK": "ВР", "DF": "ЗЩ", "MF": "ПЗ", "FW": "НП"}

var cs: CareerState
var _stack: Array[Callable] = []
var _body: Control
var _message := ""
var _pick_slot := -1
var _focus_hint := ""


func _ready() -> void:
	theme = UIKit.theme()
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.05, 0.07, 0.1)
	add_child(bg)
	_body = Control.new()
	_body.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_body)
	cs = Game.career
	if cs != null:
		_absorb_match_result()
		_stack = [_hub]
		if _just_played:
			_stack.append(_round_results)
		_show()
	else:
		_stack = [_entry]
		_show()
	var want: String = Game.cli.get("career_screen", "")
	if want != "":
		if cs == null:
			cs = CareerState.create("smk", 2024)
			Game.career = cs
			_stack = [_hub]
		match want:
			"lineup": _open(_lineup)
			"table": _open(_table)
			"transfers": _open(_transfers_buy)
			"fixtures": _open(_fixtures)
			"new": _open(_new_career)
			_: _show()


var _just_played := false


## Apply the result of the match that was just played, exactly once.
func _absorb_match_result() -> void:
	var res: Dictionary = Game.last_result
	Game.last_result = {}
	if res.is_empty() or not res.get("completed", false) or str(res.get("fixture_id", "")) == "":
		return
	var goals: Array = res["goals"]
	if cs.apply_result(res["fixture_id"], int(goals[0]), int(goals[1]), res.get("participants", [])):
		cs.complete_round()
		_just_played = true
		_autosave()


func _autosave() -> void:
	var err := SaveManager.save(cs)
	if err != "":
		_message = tr("SAVE_FAILED") + ": " + err


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if _stack.size() > 1:
			_back()
		get_viewport().set_input_as_handled()


func _open(screen: Callable) -> void:
	_stack.append(screen)
	_show()


func _back() -> void:
	if _stack.size() > 1:
		_stack.pop_back()
	_show()


func _show() -> void:
	for c in _body.get_children():
		c.queue_free()
	_stack.back().call()


func _frame(title: String, wide := false) -> VBoxContainer:
	var panel := UIKit.panel(30)
	_body.add_child(UIKit.centered(panel))
	var v := UIKit.vbox(8)
	if wide:
		v.custom_minimum_size = Vector2(1100, 0)
	panel.add_child(v)
	var t := UIKit.label(title, 38, UIKit.ACCENT)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	if _message != "":
		var m := UIKit.label(_message, 20, Color(1.0, 0.75, 0.4))
		m.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		m.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		m.custom_minimum_size = Vector2(600, 0)
		v.add_child(m)
		_message = ""
	return v


func _scroll(v: VBoxContainer, height := 520.0) -> VBoxContainer:
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(0, height)
	sc.follow_focus = true
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(sc)
	var inner := UIKit.vbox(4)
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(inner)
	return inner


func _row_button(text: String, cb: Callable) -> Button:
	var b := UIKit.button(text, cb, 1000)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_font_size_override("font_size", 19)
	return b


static func money(v: int) -> String:
	if absi(v) >= 1000000:
		return "%.2f млн" % (v / 1000000.0)
	return "%d тыс" % int(v / 1000.0)


# -------------------------------------------------------------------- entry

func _entry() -> void:
	var v := _frame(tr("MENU_CAREER"))
	var has := SaveManager.exists()
	var first: Button = null
	if has:
		first = UIKit.button(tr("CAREER_CONTINUE"), func() -> void:
			var res := SaveManager.load_career()
			if res["career"] == null:
				_message = tr("SAVE_CORRUPT_NONE") + " (" + str(res["error"]) + ")"
				_show()
				return
			cs = res["career"]
			Game.career = cs
			if res["recovered"]:
				_message = tr("SAVE_RECOVERED")
			_stack = [_hub]
			_show())
		v.add_child(first)
	var nb := UIKit.button(tr("CAREER_NEW"), func() -> void: _open(_new_career))
	v.add_child(nb)
	if has:
		v.add_child(UIKit.label(tr("CAREER_NEW_WARNING"), 16, UIKit.MUTED))
	v.add_child(UIKit.button(tr("BACK"), func() -> void: Game.goto(Game.SCENE_MENU)))
	(first if first != null else nb).grab_focus()


func _new_career() -> void:
	var v := _frame(tr("CAREER_PICK_CLUB"))
	var first: Button = null
	for cd: Dictionary in LeagueData.clubs():
		var id: String = cd["id"]
		var b := UIKit.button("%s   —   %s %d,  %s %s" % [cd["name"], tr("CLUB_LEVEL"), int(cd["level"]), tr("BUDGET"), money(int(cd["budget"]))], func() -> void:
			cs = CareerState.create(id, int(Time.get_unix_time_from_system()) % 1000000)
			Game.career = cs
			_autosave()
			_stack = [_hub]
			_show(), 640)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		v.add_child(b)
		if first == null:
			first = b
	v.add_child(UIKit.button(tr("BACK"), _back, 640))
	first.grab_focus()


# ---------------------------------------------------------------------- hub

func _hub() -> void:
	var u := cs.user()
	var v := _frame(u["name"])
	var info := UIKit.label("%s %d   •   %s %d/%d   •   %s: %s   •   %s: %d" % [
		tr("SEASON"), int(cs.data["season"]), tr("ROUND"), mini(int(cs.data["round"]) + 1, CareerState.ROUNDS), CareerState.ROUNDS,
		tr("BUDGET"), money(int(u["budget"])), tr("TABLE_POS"), cs.position_of(cs.data["user_club"])], 20, UIKit.MUTED)
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(info)
	v.add_child(UIKit.spacer(6))
	var first: Button = null
	if cs.data["season_over"]:
		var st := cs.standings()
		var l := UIKit.label("%s: %s.  %s: %d" % [tr("SEASON_CHAMPION"), st[0]["name"], tr("SEASON_YOUR_POS"), cs.position_of(cs.data["user_club"])], 26)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(l)
		first = UIKit.button(tr("SEASON_NEXT"), func() -> void:
			cs.start_next_season()
			_autosave()
			_show(), 520)
		v.add_child(first)
	else:
		var f := cs.user_fixture()
		var home: Dictionary = cs.club(f["home"])
		var away: Dictionary = cs.club(f["away"])
		var nl := UIKit.label("%s:  %s  —  %s" % [tr("NEXT_MATCH"), home["name"], away["name"]], 28)
		nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(nl)
		var sl := UIKit.label("%s: %.0f  —  %.0f" % [tr("TEAM_STRENGTH"), cs.team_strength(f["home"]), cs.team_strength(f["away"])], 18, UIKit.MUTED)
		sl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(sl)
		first = UIKit.button(tr("PLAY_MATCH"), func() -> void:
			if cs.lineup_valid(cs.data["user_club"], u["lineup"]) != "":
				_message = tr("LINEUP_INVALID")
				_show()
				return
			_autosave()
			var setup := cs.match_setup_for(f, int(cs.data["seed"]) + int(cs.data["season"]) * 1000 + int(cs.data["round"]))
			setup.difficulty = int(Game.settings["difficulty"])
			setup.duration = float(Game.settings["match_minutes"]) * 60.0
			Game.start_match(setup, Game.SCENE_CAREER), 520)
		v.add_child(first)
		v.add_child(UIKit.button(tr("SIM_MATCH"), func() -> void:
			cs.complete_round(true)
			_autosave()
			_open(_round_results), 520))
	v.add_child(UIKit.button(tr("LINEUP"), func() -> void: _open(_lineup), 520))
	v.add_child(UIKit.button(tr("TABLE"), func() -> void: _open(_table), 520))
	v.add_child(UIKit.button(tr("FIXTURES"), func() -> void: _open(_fixtures), 520))
	v.add_child(UIKit.button(tr("TRANSFERS"), func() -> void: _open(_transfers_buy), 520))
	v.add_child(UIKit.button(tr("SAVE_AND_EXIT"), func() -> void:
		_autosave()
		Game.career = null
		Game.goto(Game.SCENE_MENU), 520))
	first.grab_focus()


func _round_results() -> void:
	var v := _frame("%s %d" % [tr("ROUND_RESULTS"), int(cs.data["round"])])
	for fid: String in cs.data["last_round_results"]:
		var f := cs.fixture(fid)
		var mine: bool = f["home"] == cs.data["user_club"] or f["away"] == cs.data["user_club"]
		var l := UIKit.label("%s   %d : %d   %s" % [cs.club(f["home"])["name"], int(f["hg"]), int(f["ag"]), cs.club(f["away"])["name"]], 26, UIKit.ACCENT if mine else UIKit.TEXT)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(l)
	v.add_child(UIKit.spacer(8))
	var b := UIKit.button(tr("TABLE"), func() -> void:
		_stack.pop_back()
		_open(_table))
	v.add_child(b)
	var c := UIKit.button(tr("CONTINUE"), _back)
	v.add_child(c)
	c.grab_focus()


# -------------------------------------------------------------------- table

func _table() -> void:
	var v := _frame(tr("TABLE"), true)
	var grid := GridContainer.new()
	grid.columns = 10
	grid.add_theme_constant_override("h_separation", 26)
	grid.add_theme_constant_override("v_separation", 6)
	for h: String in ["#", tr("T_CLUB"), tr("T_P"), tr("T_W"), tr("T_D"), tr("T_L"), tr("T_GF"), tr("T_GA"), tr("T_GD"), tr("T_PTS")]:
		grid.add_child(UIKit.label(h, 20, UIKit.MUTED))
	var st := cs.standings()
	for i in st.size():
		var r: Dictionary = st[i]
		var col := UIKit.ACCENT if r["club"] == cs.data["user_club"] else UIKit.TEXT
		var name_l := UIKit.label(str(r["name"]), 22, col)
		name_l.custom_minimum_size = Vector2(300, 0)
		grid.add_child(UIKit.label(str(i + 1), 22, col))
		grid.add_child(name_l)
		for k: String in ["p", "w", "d", "l", "gf", "ga"]:
			grid.add_child(UIKit.label(str(r[k]), 22, col))
		grid.add_child(UIKit.label("%+d" % int(r["gd"]), 22, col))
		grid.add_child(UIKit.label(str(r["pts"]), 22, col))
	v.add_child(grid)
	v.add_child(UIKit.label(tr("TABLE_NOTE"), 15, UIKit.MUTED))
	var b := UIKit.button(tr("BACK"), _back)
	v.add_child(b)
	b.grab_focus()


func _fixtures() -> void:
	var v := _frame(tr("FIXTURES"), true)
	var inner := _scroll(v, 560)
	var focus_target: Control = null
	for r in CareerState.ROUNDS:
		var head := Button.new()
		head.text = "%s %d" % [tr("ROUND"), r + 1]
		head.alignment = HORIZONTAL_ALIGNMENT_LEFT
		head.focus_mode = Control.FOCUS_ALL
		head.add_theme_color_override("font_color", UIKit.ACCENT)
		inner.add_child(head)
		if r == mini(int(cs.data["round"]), CareerState.ROUNDS - 1):
			focus_target = head
		for f: Dictionary in cs.round_fixtures(r):
			var mine: bool = f["home"] == cs.data["user_club"] or f["away"] == cs.data["user_club"]
			var score := "%d : %d" % [int(f["hg"]), int(f["ag"])] if f["played"] else "—"
			inner.add_child(UIKit.label("      %s   %s   %s" % [cs.club(f["home"])["name"], score, cs.club(f["away"])["name"]], 19, UIKit.ACCENT if mine else UIKit.TEXT))
	var b := UIKit.button(tr("BACK"), _back)
	v.add_child(b)
	if focus_target != null:
		focus_target.grab_focus.call_deferred()
	else:
		b.grab_focus()


# ------------------------------------------------------------------- lineup

func _player_line(p: Dictionary) -> String:
	var a: Dictionary = p["attrs"]
	return "%s %2d  %-24s %s %d   %s %d   СК %d ПА %d УД %d КО %d ЗА %d ВЫ %d%s" % [
		POS_NAMES[p["pos"]], int(p["number"]), p["name"], tr("AGE"), int(p["age"]), tr("OVR"), Attr.overall(a, p["pos"]),
		int(a["pace"]), int(a["passing"]), int(a["shooting"]), int(a["control"]), int(a["defending"]), int(a["stamina"]),
		("  ВР %d" % int(a["goalkeeping"])) if p["pos"] == "GK" else ""]


func _lineup() -> void:
	var v := _frame(tr("LINEUP"), true)
	var u := cs.user()
	var hint := tr("LINEUP_HINT") if _pick_slot < 0 else "%s: %s" % [tr("LINEUP_PICK_FOR"), SLOT_NAMES[_pick_slot]]
	v.add_child(UIKit.label(hint, 18, UIKit.MUTED))
	var inner := _scroll(v, 520)
	var first: Button = null
	var lineup: Array = u["lineup"]
	if _pick_slot < 0:
		for slot in 11:
			var p := cs.player(lineup[slot])
			var b := _row_button("%s │ %s" % [SLOT_NAMES[slot], _player_line(p)], func() -> void:
				_pick_slot = slot
				_show())
			inner.add_child(b)
			if first == null:
				first = b
		inner.add_child(UIKit.label(tr("LINEUP_BENCH"), 18, UIKit.MUTED))
		for pid: String in u["squad"]:
			if not lineup.has(pid):
				inner.add_child(UIKit.label("        " + _player_line(cs.player(pid)), 18, UIKit.MUTED))
		v.add_child(UIKit.button(tr("LINEUP_AUTO"), func() -> void:
			if cs.auto_lineup(cs.data["user_club"]):
				_autosave()
			else:
				_message = tr("LINEUP_INVALID")
			_show()))
		v.add_child(UIKit.button(tr("BACK"), _back))
	else:
		var squad := cs.squad_of(cs.data["user_club"])
		var want := LeagueData.SLOT_POS[_pick_slot]
		squad.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			var sa := int(a["pos"] == want) * 100 + Attr.overall(a["attrs"], want)
			var sb := int(b["pos"] == want) * 100 + Attr.overall(b["attrs"], want)
			return sa > sb)
		for p: Dictionary in squad:
			var pid: String = p["id"]
			var tag := "●" if lineup.has(pid) else " "
			var b := _row_button("%s %s" % [tag, _player_line(p)], func() -> void:
				var nl := lineup.duplicate()
				var other := nl.find(pid)
				if other >= 0:
					nl[other] = nl[_pick_slot]
				nl[_pick_slot] = pid
				var err := cs.lineup_valid(cs.data["user_club"], nl)
				if err != "":
					_message = tr(err)
				else:
					cs.set_lineup(cs.data["user_club"], nl)
					_autosave()
				_pick_slot = -1
				_show())
			inner.add_child(b)
			if first == null:
				first = b
		v.add_child(UIKit.button(tr("BACK"), func() -> void:
			_pick_slot = -1
			_show()))
	first.grab_focus()


# ---------------------------------------------------------------- transfers

func _transfers_buy() -> void:
	var v := _frame(tr("TRANSFERS_BUY"), true)
	v.add_child(UIKit.label("%s: %s    %s: %d/%d" % [tr("BUDGET"), money(int(cs.user()["budget"])), tr("SQUAD_SIZE"), (cs.user()["squad"] as Array).size(), CareerState.MAX_SQUAD], 20, UIKit.MUTED))
	var inner := _scroll(v, 470)
	var first: Button = null
	var list: Array = (cs.data["transfer_list"] as Array).duplicate()
	list.sort_custom(func(a: String, b: String) -> bool: return cs.price(a) > cs.price(b))
	for pid: String in list:
		var p := cs.player(pid)
		var b := _row_button("%s   │ %s │ %s" % [_player_line(p), cs.club(p["club"])["short"], money(cs.price(pid))], func() -> void:
			var err := cs.buy(pid)
			_message = tr("TR_BOUGHT") + ": " + str(p["name"]) if err == "" else tr(err)
			if err == "":
				_autosave()
			_show())
		inner.add_child(b)
		if first == null:
			first = b
	var sb := UIKit.button(tr("TRANSFERS_SELL"), func() -> void:
		_stack.pop_back()
		_open(_transfers_sell))
	v.add_child(sb)
	v.add_child(UIKit.button(tr("BACK"), _back))
	(first if first != null else sb).grab_focus()


func _transfers_sell() -> void:
	var v := _frame(tr("TRANSFERS_SELL"), true)
	v.add_child(UIKit.label("%s: %s    %s: %d (%s %d)" % [tr("BUDGET"), money(int(cs.user()["budget"])), tr("SQUAD_SIZE"), (cs.user()["squad"] as Array).size(), tr("MIN"), CareerState.MIN_SQUAD], 20, UIKit.MUTED))
	var inner := _scroll(v, 470)
	var first: Button = null
	for p: Dictionary in cs.squad_of(cs.data["user_club"]):
		var pid: String = p["id"]
		var b := _row_button("%s   │ %s" % [_player_line(p), money(int(cs.price(pid) * CareerState.SELL_FACTOR))], func() -> void:
			var err := cs.sell(pid)
			_message = tr("TR_SOLD") + ": " + str(p["name"]) if err == "" else tr(err)
			if err == "":
				_autosave()
			_show())
		inner.add_child(b)
		if first == null:
			first = b
	var bb := UIKit.button(tr("TRANSFERS_BUY"), func() -> void:
		_stack.pop_back()
		_open(_transfers_buy))
	v.add_child(bb)
	v.add_child(UIKit.button(tr("BACK"), _back))
	(first if first != null else bb).grab_focus()
