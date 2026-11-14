class_name UIKit
extends RefCounted
## Small helpers so every screen shares one look and keyboard behaviour.

const ACCENT := Color(0.98, 0.8, 0.15)
const BG := Color(0.07, 0.09, 0.12, 0.92)
const BG_SOFT := Color(0.12, 0.15, 0.2, 0.9)
const TEXT := Color(0.94, 0.95, 0.97)
const MUTED := Color(0.65, 0.69, 0.75)

static var _theme: Theme


static func theme() -> Theme:
	if _theme != null:
		return _theme
	var t := Theme.new()
	t.default_font_size = 22
	var normal := _box(Color(0.16, 0.2, 0.27), 8)
	var hover := _box(Color(0.22, 0.28, 0.37), 8)
	var focus := _box(Color(0.25, 0.32, 0.42), 8)
	focus.border_color = ACCENT
	focus.set_border_width_all(3)
	var pressed := _box(Color(0.1, 0.13, 0.18), 8)
	var disabled := _box(Color(0.12, 0.13, 0.15), 8)
	for sb: StyleBoxFlat in [normal, hover, focus, pressed, disabled]:
		sb.content_margin_left = 22
		sb.content_margin_right = 22
		sb.content_margin_top = 10
		sb.content_margin_bottom = 10
	t.set_stylebox("normal", "Button", normal)
	t.set_stylebox("hover", "Button", hover)
	t.set_stylebox("focus", "Button", focus)
	t.set_stylebox("pressed", "Button", pressed)
	t.set_stylebox("disabled", "Button", disabled)
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_focus_color", "Button", Color.WHITE)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_disabled_color", "Button", Color(0.45, 0.47, 0.5))
	t.set_color("font_color", "Label", TEXT)
	t.set_stylebox("panel", "PanelContainer", _box(BG, 12))
	t.set_stylebox("panel", "Panel", _box(BG, 12))
	_theme = t
	return t


static func _box(c: Color, radius: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = c
	sb.set_corner_radius_all(radius)
	return sb


static func box(c: Color, radius := 10, margin := 14) -> StyleBoxFlat:
	var sb := _box(c, radius)
	sb.set_content_margin_all(margin)
	return sb


static func label(text: String, size := 22, color := TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


static func button(text: String, on_press: Callable, min_width := 320.0) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(min_width, 0)
	b.focus_mode = Control.FOCUS_ALL
	b.pressed.connect(func() -> void:
		Sfx.play("ui_ok")
		on_press.call())
	b.focus_entered.connect(func() -> void: Sfx.play("ui_move", 0.6))
	return b


static func panel(margin := 26) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", box(BG, 14, margin))
	return p


static func vbox(sep := 10) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	return v


static func hbox(sep := 10) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	return h


static func centered(child: Control) -> CenterContainer:
	var c := CenterContainer.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.add_child(child)
	return c


## Anchor a control to a rectangle of its parent: anchors (0..1) plus pixel offsets.
static func place(c: Control, ax0: float, ay0: float, ax1: float, ay1: float, ox0: float, oy0: float, ox1: float, oy1: float) -> void:
	c.set_anchor(SIDE_RIGHT, ax1)
	c.set_anchor(SIDE_BOTTOM, ay1)
	c.set_anchor(SIDE_LEFT, ax0)
	c.set_anchor(SIDE_TOP, ay0)
	c.set_offset(SIDE_LEFT, ox0)
	c.set_offset(SIDE_TOP, oy0)
	c.set_offset(SIDE_RIGHT, ox1)
	c.set_offset(SIDE_BOTTOM, oy1)


static func spacer(h := 12.0) -> Control:
	var s := Control.new()
	s.custom_minimum_size = Vector2(0, h)
	return s


## Left/Right selector row: label + "< value >". Returns the row; value changes call on_change(index).
static func option_row(title: String, values: Array, index: int, on_change: Callable) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_ALL
	b.custom_minimum_size = Vector2(520, 0)
	b.set_meta("values", values)
	b.set_meta("index", index)
	b.set_meta("title", title)
	var refresh := func() -> void:
		b.text = "%s:  ◄ %s ►" % [title, str(values[int(b.get_meta("index"))])]
	refresh.call()
	var step := func(d: int) -> void:
		var i := posmod(int(b.get_meta("index")) + d, values.size())
		b.set_meta("index", i)
		refresh.call()
		Sfx.play("ui_move", 0.6)
		on_change.call(i)
	b.pressed.connect(func() -> void: step.call(1))
	b.gui_input.connect(func(ev: InputEvent) -> void:
		if ev.is_action_pressed("ui_left"):
			step.call(-1)
			b.accept_event()
		elif ev.is_action_pressed("ui_right"):
			step.call(1)
			b.accept_event())
	b.focus_entered.connect(func() -> void: Sfx.play("ui_move", 0.6))
	return b


static func controls_text() -> String:
	return tr_s("CONTROLS_TEXT")


static func tr_s(key: String) -> String:
	return TranslationServer.translate(key)
