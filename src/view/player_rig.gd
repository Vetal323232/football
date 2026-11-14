class_name PlayerRig
extends Node3D
## Simple original humanoid built from primitives with procedural animation.
## Purely visual: reads a SimPlayer every frame and never affects gameplay.
## Local frame: feet at the origin, facing -Z.

const HIP_Y := 0.9

var player: SimPlayer
var _body: Node3D
var _spine: Node3D
var _hip: Array[Node3D] = []
var _knee: Array[Node3D] = []
var _shoulder: Array[Node3D] = []
var _elbow: Array[Node3D] = []
var _marker: MeshInstance3D
var _marker_top: MeshInstance3D
var _label: Label3D
var _phase := 0.0
var _prev_pos := Vector2.ZERO
var _cur_pos := Vector2.ZERO
var _yaw := 0.0
var _speed_s := 0.0
var _pose := {}
var celebrate := false


func setup(p: SimPlayer, shirt: Color, shorts: Color, socks: Color) -> void:
	player = p
	var h := hash(p.uid)
	var skins: Array[Color] = [Color(0.96, 0.8, 0.68), Color(0.87, 0.68, 0.52), Color(0.72, 0.52, 0.38), Color(0.5, 0.34, 0.24), Color(0.36, 0.24, 0.17)]
	var hairs: Array[Color] = [Color(0.1, 0.08, 0.06), Color(0.3, 0.2, 0.1), Color(0.75, 0.6, 0.3), Color(0.15, 0.15, 0.15), Color(0.5, 0.25, 0.1)]
	var skin := skins[absi(h) % skins.size()]
	var hair := hairs[absi(h / 7) % hairs.size()]
	var m_shirt := _mat(shirt)
	var m_shorts := _mat(shorts)
	var m_socks := _mat(socks)
	var m_skin := _mat(skin)
	var m_boot := _mat(Color(0.08, 0.08, 0.1))
	var m_hair := _mat(hair)

	_body = Node3D.new()
	add_child(_body)
	_spine = Node3D.new()
	_spine.position = Vector3(0, HIP_Y, 0)
	_body.add_child(_spine)
	var torso := _capsule(0.17, 0.6, m_shirt)
	torso.position = Vector3(0, 0.32, 0)
	torso.scale = Vector3(1.15, 1.0, 0.72)
	_spine.add_child(torso)
	var shorts_m := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.185
	cyl.bottom_radius = 0.2
	cyl.height = 0.26
	cyl.radial_segments = 10
	shorts_m.mesh = cyl
	shorts_m.material_override = m_shorts
	shorts_m.position = Vector3(0, -0.02, 0)
	shorts_m.scale = Vector3(1.0, 1.0, 0.75)
	_spine.add_child(shorts_m)
	var neck := _capsule(0.05, 0.14, m_skin)
	neck.position = Vector3(0, 0.66, 0)
	_spine.add_child(neck)
	var head := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = 0.115
	sph.height = 0.25
	sph.radial_segments = 12
	sph.rings = 6
	head.mesh = sph
	head.material_override = m_skin
	head.position = Vector3(0, 0.8, 0)
	_spine.add_child(head)
	var hair_m := MeshInstance3D.new()
	var hs := SphereMesh.new()
	hs.radius = 0.12
	hs.height = 0.16
	hs.radial_segments = 12
	hs.rings = 4
	hair_m.mesh = hs
	hair_m.material_override = m_hair
	hair_m.position = Vector3(0, 0.86, 0.015)
	_spine.add_child(hair_m)

	for side: float in [-1.0, 1.0]:
		var hip := Node3D.new()
		hip.position = Vector3(side * 0.1, HIP_Y, 0)
		_body.add_child(hip)
		var thigh := _capsule(0.078, 0.46, m_skin)
		thigh.position = Vector3(0, -0.22, 0)
		hip.add_child(thigh)
		var knee := Node3D.new()
		knee.position = Vector3(0, -0.44, 0)
		hip.add_child(knee)
		var shin := _capsule(0.062, 0.44, m_socks)
		shin.position = Vector3(0, -0.21, 0)
		knee.add_child(shin)
		var foot := MeshInstance3D.new()
		var fb := BoxMesh.new()
		fb.size = Vector3(0.1, 0.07, 0.26)
		foot.mesh = fb
		foot.material_override = m_boot
		foot.position = Vector3(0, -0.42, -0.07)
		knee.add_child(foot)
		_hip.append(hip)
		_knee.append(knee)

		var sh := Node3D.new()
		sh.position = Vector3(side * 0.24, 0.55, 0)
		_spine.add_child(sh)
		var upper := _capsule(0.052, 0.3, m_shirt)
		upper.position = Vector3(0, -0.13, 0)
		sh.add_child(upper)
		var el := Node3D.new()
		el.position = Vector3(0, -0.27, 0)
		sh.add_child(el)
		var fore := _capsule(0.042, 0.28, m_skin)
		fore.position = Vector3(0, -0.13, 0)
		el.add_child(fore)
		_shoulder.append(sh)
		_elbow.append(el)

	_label = Label3D.new()
	_label.text = str(p.number)
	_label.font_size = 64
	_label.pixel_size = 0.0042
	_label.position = Vector3(0, 0.36, 0.135)
	_label.modulate = shorts if shorts.get_luminance() > 0.5 or shirt.get_luminance() < 0.5 else Color(0.05, 0.05, 0.05)
	_label.outline_size = 0
	_spine.add_child(_label)

	_marker = MeshInstance3D.new()
	var tor := TorusMesh.new()
	tor.inner_radius = 0.52
	tor.outer_radius = 0.66
	tor.rings = 24
	tor.ring_segments = 4
	_marker.mesh = tor
	_marker.scale = Vector3(1, 0.08, 1)
	_marker.position = Vector3(0, 0.03, 0)
	var mm := StandardMaterial3D.new()
	mm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mm.albedo_color = Color(1.0, 0.95, 0.1)
	_marker.material_override = mm
	_marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_marker.visible = false
	add_child(_marker)
	_marker_top = MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.16
	cone.bottom_radius = 0.0
	cone.height = 0.26
	cone.radial_segments = 4
	_marker_top.mesh = cone
	_marker_top.material_override = mm
	_marker_top.position = Vector3(0, 2.2, 0)
	_marker_top.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_marker_top.visible = false
	add_child(_marker_top)

	_prev_pos = p.pos
	_cur_pos = p.pos
	_yaw = _yaw_of(p.facing)


func refresh_identity() -> void:
	_label.text = str(player.number)


static func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.9
	return m


static func _capsule(radius: float, height: float, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var c := CapsuleMesh.new()
	c.radius = radius
	c.height = height
	c.radial_segments = 8
	c.rings = 3
	mi.mesh = c
	mi.material_override = mat
	return mi


static func _yaw_of(f: Vector2) -> float:
	return atan2(-f.x, -f.y)


## Called once per simulation tick.
func tick() -> void:
	_prev_pos = _cur_pos
	_cur_pos = player.pos


## Called every rendered frame. `frac` is the physics interpolation fraction.
func animate(delta: float, frac: float) -> void:
	var p := player
	var pos2 := _prev_pos.lerp(_cur_pos, frac)
	if _prev_pos.distance_to(_cur_pos) > 3.0:
		pos2 = _cur_pos
	position = Vector3(pos2.x, 0.0, pos2.y)
	_yaw = lerp_angle(_yaw, _yaw_of(p.facing), clampf(delta * 16.0, 0.0, 1.0))
	rotation.y = _yaw
	_marker.visible = p.is_human
	_marker_top.visible = p.is_human
	if p.is_human:
		_marker.rotation.y += delta * 2.0
		_marker_top.position.y = 2.2 + 0.06 * sin(Time.get_ticks_msec() * 0.006)

	var speed := p.vel.length()
	_speed_s = lerpf(_speed_s, speed, clampf(delta * 10.0, 0.0, 1.0))
	var sf := clampf(_speed_s / 8.5, 0.0, 1.0)
	var cycle := lerpf(1.5, 3.7, sf)
	_phase = fmod(_phase + TAU * _speed_s * delta / cycle, TAU)
	# Moving backwards relative to facing: play the cycle in reverse.
	var fwd := p.facing.dot(p.vel.normalized()) if speed > 0.5 else 1.0
	var s := sin(_phase) * (1.0 if fwd > -0.3 else -1.0)
	var c := cos(_phase)

	var amp := lerpf(0.0, 0.95, minf(1.0, sf * 1.4)) if _speed_s > 0.3 else 0.0
	var idle := sin(Time.get_ticks_msec() * 0.002 + p.id) * 0.03
	var tgt := {
		"body_y": 0.035 * absf(c) * sf, "body_pitch": -(0.04 + 0.2 * sf) if _speed_s > 0.3 else 0.0, "body_roll": 0.0,
		"hip0": amp * s, "hip1": -amp * s,
		"knee0": -(0.12 + (0.3 + 1.2 * sf) * maxf(0.0, c)) if amp > 0.0 else -0.05,
		"knee1": -(0.12 + (0.3 + 1.2 * sf) * maxf(0.0, -c)) if amp > 0.0 else -0.05,
		"sh0": -amp * 0.8 * s + idle, "sh1": amp * 0.8 * s - idle,
		"el0": 0.25 + 1.0 * sf, "el1": 0.25 + 1.0 * sf, "sh_roll": 0.08, "spine_pitch": 0.0,
	}
	var quick := false
	var holding := false
	match p.anim:
		&"kick":
			var u := 1.0 - p.anim_t / 0.35
			var swing := sin(clampf(u, 0.0, 1.0) * PI)
			tgt["hip1"] = 0.25 + 1.1 * swing
			tgt["knee1"] = -0.5 * (1.0 - swing)
			tgt["hip0"] = -0.25
			tgt["sh0"] = 0.6 * swing
			tgt["sh1"] = -0.5 * swing
			tgt["body_pitch"] = 0.12 * swing
			quick = true
		&"throw":
			tgt["sh0"] = 2.9
			tgt["sh1"] = 2.9
			tgt["el0"] = 0.3
			tgt["el1"] = 0.3
			quick = true
		&"tackle":
			tgt["body_y"] = -0.42
			tgt["body_pitch"] = 0.75
			tgt["hip1"] = 1.45
			tgt["knee1"] = -0.05
			tgt["hip0"] = 0.9
			tgt["knee0"] = -1.5
			tgt["sh0"] = -0.6
			tgt["sh1"] = -0.9
			quick = true
		&"stumble":
			tgt["body_pitch"] = -0.55
			tgt["knee0"] = -0.8
			tgt["knee1"] = -0.4
			tgt["sh0"] = 0.9
			tgt["sh1"] = 0.7
		&"dive":
			var right := Vector2(-p.facing.y, p.facing.x)
			var side := signf(p.dive_dir.dot(right)) if p.dive_dir.length() > 0.1 else 1.0
			var airborne := p.dive_t > 0.0
			tgt["body_roll"] = -side * 1.35
			tgt["body_y"] = 0.25 if airborne else -0.55
			tgt["sh0"] = 2.9
			tgt["sh1"] = 2.9
			tgt["el0"] = 0.1
			tgt["el1"] = 0.1
			tgt["hip0"] = 0.2
			tgt["hip1"] = -0.2
			quick = true
	if p.tackle_recover > 0.0 and p.anim != &"tackle":
		tgt["body_pitch"] = -0.35
		tgt["knee0"] = -0.7
		tgt["knee1"] = -0.7
	if _is_holding():
		holding = true
		tgt["sh0"] = 1.15
		tgt["sh1"] = 1.15
		tgt["el0"] = 0.9
		tgt["el1"] = 0.9
	if celebrate:
		var j := absf(sin(Time.get_ticks_msec() * 0.008 + p.id))
		tgt["sh0"] = 2.7
		tgt["sh1"] = 2.7
		tgt["el0"] = 0.2
		tgt["el1"] = 0.2
		tgt["body_y"] = 0.12 * j

	var k := clampf(delta * (26.0 if quick else 14.0), 0.0, 1.0)
	for key: String in tgt:
		_pose[key] = lerpf(float(_pose.get(key, tgt[key])), float(tgt[key]), k)
	_body.position.y = _pose["body_y"]
	_body.rotation.x = _pose["body_pitch"]
	_body.rotation.z = _pose["body_roll"]
	_hip[0].rotation.x = _pose["hip0"]
	_hip[1].rotation.x = _pose["hip1"]
	_knee[0].rotation.x = _pose["knee0"]
	_knee[1].rotation.x = _pose["knee1"]
	_shoulder[0].rotation.x = _pose["sh0"]
	_shoulder[1].rotation.x = _pose["sh1"]
	_shoulder[0].rotation.z = -_pose["sh_roll"]
	_shoulder[1].rotation.z = _pose["sh_roll"]
	_elbow[0].rotation.x = _pose["el0"]
	_elbow[1].rotation.x = _pose["el1"]
	if holding:
		pass


var holding_ball := false


func _is_holding() -> bool:
	return holding_ball
