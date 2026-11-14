extends Control
## Chooser for the AI diagnostic scenarios. Each one starts the normal match
## scene with a prepared situation and the F3 overlay switched on.

var _variant := 0
var _seed := 11


func _ready() -> void:
	theme = UIKit.theme()
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.05, 0.07, 0.1)
	add_child(bg)
	var panel := UIKit.panel(30)
	add_child(UIKit.centered(panel))
	var v := UIKit.vbox(8)
	panel.add_child(v)
	var t := UIKit.label(tr("MENU_DIAG"), 40, UIKit.ACCENT)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	v.add_child(UIKit.label(tr("DIAG_HELP"), 17, UIKit.MUTED))
	v.add_child(UIKit.option_row(tr("DIAG_VARIANT"), [1, 2, 3], 0, func(i: int) -> void: _variant = i))
	v.add_child(UIKit.option_row("Seed", [11, 22, 33, 44, 55], 0, func(i: int) -> void: _seed = [11, 22, 33, 44, 55][i]))
	var first: Button = null
	for name in ScenarioLib.NAMES:
		var b := UIKit.button(str(ScenarioLib.TITLES[name]), func() -> void:
			var s := ScenarioLib.make_setup(name, _variant, _seed)
			Game.start_match(s, Game.SCENE_DIAG), 520)
		v.add_child(b)
		if first == null:
			first = b
	v.add_child(UIKit.button(tr("BACK"), func() -> void: Game.goto(Game.SCENE_MENU), 520))
	first.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		Game.goto(Game.SCENE_MENU)
