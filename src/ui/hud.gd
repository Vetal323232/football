extends CanvasLayer
## Match HUD: scoreboard, clock, banners, controlled player info, radar, help.

var sim: MatchSim
var _score: Label
var _clock: Label
var _banner: Label
var _banner_t := 0.0
var _player: Label
var _stamina: ProgressBar
var _charge: ProgressBar
var _help: PanelContainer
var _help_t := 7.0
var _radar: Control
var _hint: Label
var _team_a: ColorRect
var _team_b: ColorRect


func _ready() -> void:
	layer = 5
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UIKit.theme()
	add_child(root)

	var top := PanelContainer.new()
	top.add_theme_stylebox_override("panel", UIKit.box(UIKit.BG, 10, 10))
	top.position = Vector2(24, 20)
	root.add_child(top)
	var row := UIKit.hbox(12)
	top.add_child(row)
	_team_a = ColorRect.new()
	_team_a.custom_minimum_size = Vector2(10, 30)
	row.add_child(_team_a)
	_score = UIKit.label("", 28)
	row.add_child(_score)
	_team_b = ColorRect.new()
	_team_b.custom_minimum_size = Vector2(10, 30)
	row.add_child(_team_b)
	_clock = UIKit.label("00:00", 28, UIKit.ACCENT)
	_clock.custom_minimum_size = Vector2(150, 0)
	row.add_child(_clock)

	_banner = UIKit.label("", 46, Color.WHITE)
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.add_theme_color_override("font_outline_color", Color.BLACK)
	_banner.add_theme_constant_override("outline_size", 12)
	UIKit.place(_banner, 0.5, 0.0, 0.5, 0.0, -600, 170, 600, 320)
	root.add_child(_banner)

	_hint = UIKit.label("", 24, UIKit.ACCENT)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIKit.place(_hint, 0.5, 0.0, 0.5, 0.0, -600, 84, 600, 120)
	_hint.add_theme_color_override("font_outline_color", Color.BLACK)
	_hint.add_theme_constant_override("outline_size", 6)
	root.add_child(_hint)

	var bl := PanelContainer.new()
	bl.add_theme_stylebox_override("panel", UIKit.box(UIKit.BG, 10, 12))
	UIKit.place(bl, 0.0, 1.0, 0.0, 1.0, 24, -118, 324, -22)
	root.add_child(bl)
	var bv := UIKit.vbox(6)
	bl.add_child(bv)
	_player = UIKit.label("", 22)
	bv.add_child(_player)
	_stamina = _bar(Color(0.25, 0.8, 0.35))
	bv.add_child(_stamina)
	_charge = _bar(UIKit.ACCENT)
	bv.add_child(_charge)

	_radar = Control.new()
	UIKit.place(_radar, 0.5, 1.0, 0.5, 1.0, -150, -216, 150, -20)
	_radar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_radar.draw.connect(_draw_radar)
	root.add_child(_radar)

	_help = PanelContainer.new()
	_help.add_theme_stylebox_override("panel", UIKit.box(UIKit.BG, 10, 14))
	UIKit.place(_help, 1.0, 0.0, 1.0, 0.0, -430, 20, -24, 300)
	root.add_child(_help)
	var hl := UIKit.label(tr("CONTROLS_TEXT"), 18)
	_help.add_child(hl)


func _bar(c: Color) -> ProgressBar:
	var b := ProgressBar.new()
	b.min_value = 0.0
	b.max_value = 1.0
	b.show_percentage = false
	b.custom_minimum_size = Vector2(270, 12)
	b.add_theme_stylebox_override("background", UIKit.box(Color(0, 0, 0, 0.5), 4, 0))
	b.add_theme_stylebox_override("fill", UIKit.box(c, 4, 0))
	return b


func bind(sim_: MatchSim) -> void:
	sim = sim_
	_team_a.color = sim.teams[0].kit
	_team_b.color = sim.teams[1].kit
	_help.visible = sim.human != null
	if sim.human == null:
		_player.get_parent().get_parent().visible = false


func show_banner(text: String, seconds := 2.5) -> void:
	_banner.text = text
	_banner_t = seconds


func toggle_help() -> void:
	_help.visible = not _help.visible
	_help_t = 0.0


func _process(delta: float) -> void:
	if sim == null:
		return
	_score.text = "%s  %d : %d  %s" % [sim.teams[0].short_name, sim.teams[0].score, sim.teams[1].score, sim.teams[1].short_name]
	var m := sim.time / sim.duration * 90.0
	_clock.text = "%02d:%02d  %s" % [int(m), int(fmod(m, 1.0) * 60.0), tr("HUD_HALF_1") if sim.half == 1 else tr("HUD_HALF_2")]
	if _banner_t > 0.0:
		_banner_t -= delta
		_banner.modulate.a = clampf(_banner_t * 2.0, 0.0, 1.0)
		if _banner_t <= 0.0:
			_banner.text = ""
	if _help_t > 0.0:
		_help_t -= delta
		if _help_t <= 0.0:
			_help.visible = false
	_hint.text = ""
	if sim.human != null and sim.human.controlled >= 0:
		var p: SimPlayer = sim.players[sim.human.controlled]
		_player.text = "%d  %s" % [p.number, p.pname]
		_stamina.value = p.stamina
		_charge.value = sim.human.shot_charge
		_charge.visible = sim.human.charging
		if sim.state == MatchSim.State.RESTART_READY and sim.restart_taker == p.id:
			_hint.text = tr("HINT_RESTART")
	_radar.queue_redraw()


func _draw_radar() -> void:
	if sim == null:
		return
	var sz := _radar.size
	var sc := sz.x / (Pitch.LENGTH + 4.0)
	var o := sz * 0.5
	_radar.draw_rect(Rect2(Vector2.ZERO, sz), Color(0.05, 0.2, 0.08, 0.72))
	var half := Vector2(Pitch.HALF_L, Pitch.HALF_W) * sc
	_radar.draw_rect(Rect2(o - half, half * 2.0), Color(1, 1, 1, 0.6), false, 1.0)
	_radar.draw_line(o + Vector2(0, -half.y), o + Vector2(0, half.y), Color(1, 1, 1, 0.5))
	for p in sim.players:
		var tm := sim.teams[p.team]
		var c := tm.keeper_kit if p.is_keeper() else tm.kit
		var pos := o + p.pos * sc
		_radar.draw_circle(pos, 4.2 if p.is_human else 3.3, c)
		if p.is_human:
			_radar.draw_arc(pos, 6.5, 0, TAU, 12, UIKit.ACCENT, 1.5)
	_radar.draw_circle(o + sim.ball.pos * sc, 2.6, Color.WHITE)
