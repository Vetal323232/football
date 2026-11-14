extends Control
## Main menu, quick-match setup, settings and controls screens (keyboard driven).

var _stack: Array[Callable] = []
var _body: Control
var _home := 0
var _away := 1
var _side := 0


func _ready() -> void:
	theme = UIKit.theme()
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.04, 0.09, 0.07)
	add_child(bg)
	var stripes := Control.new()
	stripes.set_anchors_preset(Control.PRESET_FULL_RECT)
	stripes.draw.connect(func() -> void:
		var w := stripes.size.x / 12.0
		for i in 12:
			if i % 2 == 0:
				stripes.draw_rect(Rect2(i * w, 0, w, stripes.size.y), Color(0.06, 0.14, 0.09)))
	add_child(stripes)
	_body = Control.new()
	_body.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_body)
	if Game.cli.has("menu") and Game.cli["menu"] == "quick":
		_open(_quick)
	elif Game.cli.has("menu") and Game.cli["menu"] == "settings":
		_open(_settings)
	else:
		_open(_main)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and _stack.size() > 1:
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


func _frame(title: String) -> VBoxContainer:
	var panel := UIKit.panel(36)
	_body.add_child(UIKit.centered(panel))
	var v := UIKit.vbox(12)
	panel.add_child(v)
	var t := UIKit.label(title, 46, UIKit.ACCENT)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	v.add_child(UIKit.spacer(6))
	return v


func _main() -> void:
	var v := _frame("OPEN PITCH")
	var sub := UIKit.label(tr("MENU_SUBTITLE"), 20, UIKit.MUTED)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sub)
	v.add_child(UIKit.spacer(8))
	var first := UIKit.button(tr("MENU_QUICK"), func() -> void: _open(_quick))
	v.add_child(first)
	v.add_child(UIKit.button(tr("MENU_CAREER"), func() -> void: Game.goto(Game.SCENE_CAREER)))
	v.add_child(UIKit.button(tr("MENU_WATCH"), func() -> void:
		var s := LeagueData.exhibition_setup(LeagueData.clubs()[_home]["id"], LeagueData.clubs()[_away]["id"], randi() % 100000)
		s.human_team = -1
		s.difficulty = 2
		s.duration = float(Game.settings["match_minutes"]) * 60.0
		Game.start_match(s, Game.SCENE_MENU)))
	v.add_child(UIKit.button(tr("MENU_DIAG"), func() -> void: Game.goto(Game.SCENE_DIAG)))
	v.add_child(UIKit.button(tr("MENU_SETTINGS"), func() -> void: _open(_settings)))
	v.add_child(UIKit.button(tr("MENU_CONTROLS"), func() -> void: _open(_controls)))
	v.add_child(UIKit.button(tr("MENU_QUIT"), func() -> void: get_tree().quit()))
	var ver := UIKit.label("v%s" % ProjectSettings.get_setting("application/config/version"), 14, UIKit.MUTED)
	ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(ver)
	first.grab_focus()


func _quick() -> void:
	var v := _frame(tr("MENU_QUICK"))
	var names := []
	for c: Dictionary in LeagueData.clubs():
		names.append("%s (%d)" % [c["name"], int(c["level"])])
	var first := UIKit.option_row(tr("QUICK_HOME"), names, _home, func(i: int) -> void: _home = i)
	v.add_child(first)
	v.add_child(UIKit.option_row(tr("QUICK_AWAY"), names, _away, func(i: int) -> void: _away = i))
	v.add_child(UIKit.option_row(tr("QUICK_SIDE"), [tr("QUICK_SIDE_HOME"), tr("QUICK_SIDE_AWAY")], _side, func(i: int) -> void: _side = i))
	v.add_child(_difficulty_row())
	v.add_child(_minutes_row())
	v.add_child(UIKit.spacer(8))
	v.add_child(UIKit.button(tr("QUICK_START"), func() -> void:
		if _home == _away:
			_away = (_home + 1) % LeagueData.clubs().size()
		var s := LeagueData.exhibition_setup(LeagueData.clubs()[_home]["id"], LeagueData.clubs()[_away]["id"], randi() % 100000)
		s.human_team = _side
		s.difficulty = int(Game.settings["difficulty"])
		s.duration = float(Game.settings["match_minutes"]) * 60.0
		Game.save_settings()
		Game.start_match(s, Game.SCENE_MENU), 520))
	v.add_child(UIKit.button(tr("BACK"), _back, 520))
	first.grab_focus()


func _difficulty_row() -> Button:
	return UIKit.option_row(tr("SET_DIFFICULTY"), [tr("DIFF_EASY"), tr("DIFF_NORMAL"), tr("DIFF_HARD")], int(Game.settings["difficulty"]),
		func(i: int) -> void: Game.settings["difficulty"] = i)


func _minutes_row() -> Button:
	var mins := [2, 4, 6, 8, 10, 12]
	return UIKit.option_row(tr("SET_MINUTES"), mins, maxi(0, mins.find(int(Game.settings["match_minutes"]))),
		func(i: int) -> void: Game.settings["match_minutes"] = mins[i])


func _settings() -> void:
	var v := _frame(tr("MENU_SETTINGS"))
	var vols := [0, 10, 20, 30, 40, 50, 60, 70, 80, 90, 100]
	var mk_vol := func(key: String, title: String) -> Button:
		return UIKit.option_row(title, vols, clampi(int(round(float(Game.settings[key]) * 10.0)), 0, 10), func(i: int) -> void:
			Game.settings[key] = vols[i] / 100.0
			Game.apply_settings()
			Sfx.play("pass"))
	var first: Button = mk_vol.call("master_volume", tr("SET_MASTER"))
	v.add_child(first)
	v.add_child(mk_vol.call("sfx_volume", tr("SET_SFX")))
	v.add_child(mk_vol.call("crowd_volume", tr("SET_CROWD")))
	var onoff := [tr("OFF"), tr("ON")]
	v.add_child(UIKit.option_row(tr("SET_FULLSCREEN"), onoff, int(bool(Game.settings["fullscreen"])), func(i: int) -> void:
		Game.settings["fullscreen"] = i == 1
		Game.apply_settings()))
	v.add_child(UIKit.option_row(tr("SET_VSYNC"), onoff, int(bool(Game.settings["vsync"])), func(i: int) -> void:
		Game.settings["vsync"] = i == 1
		Game.apply_settings()))
	v.add_child(UIKit.option_row(tr("SET_SHADOWS"), onoff, int(bool(Game.settings["shadows"])), func(i: int) -> void:
		Game.settings["shadows"] = i == 1))
	v.add_child(_difficulty_row())
	v.add_child(_minutes_row())
	v.add_child(UIKit.spacer(8))
	v.add_child(UIKit.button(tr("BACK"), func() -> void:
		Game.save_settings()
		_back(), 520))
	first.grab_focus()


func _controls() -> void:
	var v := _frame(tr("MENU_CONTROLS"))
	v.add_child(UIKit.label(tr("CONTROLS_TEXT"), 24))
	v.add_child(UIKit.label(tr("CONTROLS_MENU_NOTE"), 18, UIKit.MUTED))
	v.add_child(UIKit.spacer(8))
	var b := UIKit.button(tr("BACK"), _back)
	v.add_child(b)
	b.grab_focus()
