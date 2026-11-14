extends Node3D
## Builds the pitch, markings, goals and a simple stadium from primitives.

const LINE_W := 0.12
const LINE_Y := 0.012

var _white: StandardMaterial3D


func _ready() -> void:
	_white = StandardMaterial3D.new()
	_white.albedo_color = Color(0.93, 0.95, 0.93)
	_white.roughness = 1.0
	_build_ground()
	_build_lines()
	for s: float in [-1.0, 1.0]:
		_build_goal(s)
	_build_stadium()


func _build_ground() -> void:
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(Pitch.LENGTH + 30.0, Pitch.WIDTH + 30.0)
	mi.mesh = pm
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
varying vec3 wpos;
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	float stripe = step(0.5, fract((wpos.x + 52.5) / 17.5));
	vec3 col = mix(vec3(0.085, 0.235, 0.075), vec3(0.105, 0.275, 0.09), stripe);
	float cross_stripe = step(0.5, fract((wpos.z + 34.0) / 8.5));
	col *= mix(0.97, 1.03, cross_stripe);
	if (abs(wpos.x) > 52.5 || abs(wpos.z) > 34.0) { col = vec3(0.08, 0.2, 0.07); }
	ALBEDO = col;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	# Surround (running track / concrete).
	var outer := MeshInstance3D.new()
	var om := PlaneMesh.new()
	om.size = Vector2(260.0, 220.0)
	outer.mesh = om
	outer.position.y = -0.03
	var omat := StandardMaterial3D.new()
	omat.albedo_color = Color(0.3, 0.3, 0.32)
	omat.roughness = 1.0
	outer.material_override = omat
	outer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(outer)


func _build_lines() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var hl := Pitch.HALF_L
	var hw := Pitch.HALF_W
	_rect(st, -hl, -hw, hl, hw)
	_seg(st, Vector2(0, -hw), Vector2(0, hw))
	_arc(st, Vector2.ZERO, Pitch.CIRCLE_R, 0.0, TAU, 48)
	_dot(st, Vector2.ZERO, 0.22)
	for s: float in [-1.0, 1.0]:
		_rect(st, s * hl, -Pitch.PEN_HALF_W, s * (hl - Pitch.PEN_DEPTH), Pitch.PEN_HALF_W)
		_rect(st, s * hl, -Pitch.SIX_HALF_W, s * (hl - Pitch.SIX_DEPTH), Pitch.SIX_HALF_W)
		var spot := Vector2(s * (hl - Pitch.PEN_SPOT), 0.0)
		_dot(st, spot, 0.2)
		# Penalty arc: the part of the circle outside the area.
		var a := acos((Pitch.PEN_DEPTH - Pitch.PEN_SPOT) / Pitch.CIRCLE_R)
		var mid := PI if s > 0.0 else 0.0
		_arc(st, spot, Pitch.CIRCLE_R, mid - a, mid + a, 16)
		for ys: float in [-1.0, 1.0]:
			var corner := Vector2(s * hl, ys * hw)
			var a0 := atan2(-ys, -s)
			_arc(st, corner, 1.0, a0 - PI / 4.0, a0 + PI / 4.0, 6)
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = _white
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


func _quad(st: SurfaceTool, a: Vector2, b: Vector2, c: Vector2, d: Vector2) -> void:
	var y := LINE_Y
	var pts := [Vector3(a.x, y, a.y), Vector3(b.x, y, b.y), Vector3(c.x, y, c.y), Vector3(d.x, y, d.y)]
	for i: int in [0, 1, 2, 0, 2, 3]:
		st.set_normal(Vector3.UP)
		st.add_vertex(pts[i])
	for i: int in [0, 2, 1, 0, 3, 2]:
		st.set_normal(Vector3.UP)
		st.add_vertex(pts[i])


func _seg(st: SurfaceTool, a: Vector2, b: Vector2) -> void:
	var dir := (b - a).normalized()
	var n := Vector2(-dir.y, dir.x) * LINE_W * 0.5
	var e := dir * LINE_W * 0.5
	_quad(st, a - n - e, a + n - e, b + n + e, b - n + e)


func _rect(st: SurfaceTool, x0: float, y0: float, x1: float, y1: float) -> void:
	_seg(st, Vector2(x0, y0), Vector2(x1, y0))
	_seg(st, Vector2(x1, y0), Vector2(x1, y1))
	_seg(st, Vector2(x1, y1), Vector2(x0, y1))
	_seg(st, Vector2(x0, y1), Vector2(x0, y0))


func _arc(st: SurfaceTool, c: Vector2, r: float, a0: float, a1: float, n: int) -> void:
	for i in n:
		var t0 := lerpf(a0, a1, float(i) / n)
		var t1 := lerpf(a0, a1, float(i + 1) / n)
		_seg(st, c + Vector2(cos(t0), sin(t0)) * r, c + Vector2(cos(t1), sin(t1)) * r)


func _dot(st: SurfaceTool, c: Vector2, r: float) -> void:
	_quad(st, c + Vector2(-r, -r), c + Vector2(r, -r), c + Vector2(r, r), c + Vector2(-r, r))


func _cyl(a: Vector3, b: Vector3, r: float, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = r
	c.bottom_radius = r
	c.height = a.distance_to(b)
	c.radial_segments = 8
	mi.mesh = c
	mi.material_override = mat
	mi.position = (a + b) * 0.5
	var up := (b - a).normalized()
	if absf(up.dot(Vector3.UP)) < 0.999:
		var axis := Vector3.UP.cross(up).normalized()
		mi.basis = Basis(axis, Vector3.UP.angle_to(up))
	add_child(mi)
	return mi


func _build_goal(s: float) -> void:
	var gx := s * Pitch.HALF_L
	var hw := Pitch.GOAL_HALF_W
	var h := Pitch.GOAL_H
	var depth := Pitch.NET_DEPTH
	var post_mat := StandardMaterial3D.new()
	post_mat.albedo_color = Color(0.97, 0.97, 0.97)
	for ys: float in [-1.0, 1.0]:
		_cyl(Vector3(gx, 0, ys * hw), Vector3(gx, h, ys * hw), Pitch.POST_R, post_mat)
		_cyl(Vector3(gx + s * depth, 0, ys * hw), Vector3(gx + s * depth, h * 0.75, ys * hw), 0.03, post_mat)
		_cyl(Vector3(gx, h, ys * hw), Vector3(gx + s * depth, h * 0.75, ys * hw), 0.03, post_mat)
	_cyl(Vector3(gx, h, -hw - 0.06), Vector3(gx, h, hw + 0.06), Pitch.POST_R, post_mat)
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode cull_disabled, unshaded;
void fragment() {
	vec2 g = fract(UV * vec2(34.0, 14.0));
	float l = max(step(0.88, g.x), step(0.88, g.y));
	ALBEDO = vec3(0.95);
	ALPHA = l;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
}
"""
	var net := ShaderMaterial.new()
	net.shader = sh
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var bx := gx + s * depth
	var bh := h * 0.75
	# back, top, two sides
	_net_quad(st, Vector3(bx, 0, -hw), Vector3(bx, 0, hw), Vector3(bx, bh, hw), Vector3(bx, bh, -hw))
	_net_quad(st, Vector3(gx, h, -hw), Vector3(gx, h, hw), Vector3(bx, bh, hw), Vector3(bx, bh, -hw))
	for ys: float in [-1.0, 1.0]:
		_net_quad(st, Vector3(gx, 0, ys * hw), Vector3(bx, 0, ys * hw), Vector3(bx, bh, ys * hw), Vector3(gx, h, ys * hw))
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = net
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


func _net_quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	var pts := [a, b, c, d]
	var uvs := [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
	for i: int in [0, 1, 2, 0, 2, 3]:
		st.set_uv(uvs[i])
		st.add_vertex(pts[i])


func _build_stadium() -> void:
	var crowd_sh := Shader.new()
	crowd_sh.code = """
shader_type spatial;
uniform vec3 tint = vec3(1.0);
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
void fragment() {
	vec2 cell = floor(UV * vec2(220.0, 26.0));
	float r = hash(cell);
	vec3 seat = vec3(0.16, 0.18, 0.24);
	vec3 person = vec3(hash(cell + 1.3), hash(cell + 7.7), hash(cell + 3.1)) * 0.7 + 0.2;
	vec2 f = fract(UV * vec2(220.0, 26.0));
	float body = step(0.2, f.x) * step(f.x, 0.8) * step(0.15, f.y);
	vec3 col = mix(seat, person * tint, step(0.22, r) * body);
	ALBEDO = col;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
"""
	var wall := StandardMaterial3D.new()
	wall.albedo_color = Color(0.2, 0.21, 0.25)
	var roof := StandardMaterial3D.new()
	roof.albedo_color = Color(0.75, 0.77, 0.8)
	# Far-side stand and two end stands (the near side stays open for the camera).
	_stand(Vector3(0, 0, -Pitch.HALF_W - 9.0), 0.0, Pitch.LENGTH + 34.0, crowd_sh, wall, roof)
	_stand(Vector3(-Pitch.HALF_L - 10.0, 0, 0), PI * 0.5, Pitch.WIDTH + 14.0, crowd_sh, wall, roof)
	_stand(Vector3(Pitch.HALF_L + 10.0, 0, 0), -PI * 0.5, Pitch.WIDTH + 14.0, crowd_sh, wall, roof)
	# Advertising boards with original fictional colour panels.
	var colors: Array[Color] = [Color(0.85, 0.15, 0.15), Color(0.1, 0.35, 0.8), Color(0.95, 0.75, 0.1), Color(0.1, 0.6, 0.35), Color(0.9, 0.9, 0.9), Color(0.5, 0.2, 0.7)]
	var n := 14
	for i in n:
		var w := (Pitch.LENGTH + 6.0) / n
		_board(Vector3(-Pitch.HALF_L - 3.0 + w * (i + 0.5), 0.45, -Pitch.HALF_W - 4.0), Vector3(w - 0.15, 0.9, 0.15), colors[i % colors.size()])
	for s: float in [-1.0, 1.0]:
		for i in 6:
			if i == 2 or i == 3:
				continue  # keep the area behind the goal clear
			var w2 := (Pitch.WIDTH + 4.0) / 6.0
			_board(Vector3(s * (Pitch.HALF_L + 4.5), 0.45, -Pitch.HALF_W - 2.0 + w2 * (i + 0.5)), Vector3(0.15, 0.9, w2 - 0.15), colors[(i + 2) % colors.size()])
	# Floodlight masts.
	var pole := StandardMaterial3D.new()
	pole.albedo_color = Color(0.5, 0.5, 0.52)
	var lamp := StandardMaterial3D.new()
	lamp.albedo_color = Color(1, 1, 0.9)
	lamp.emission_enabled = true
	lamp.emission = Color(1, 1, 0.85)
	lamp.emission_energy_multiplier = 2.0
	for sx: float in [-1.0, 1.0]:
		var base := Vector3(sx * (Pitch.HALF_L + 14.0), 0, -Pitch.HALF_W - 22.0)
		_cyl(base, base + Vector3(0, 34, 0), 0.4, pole)
		var head := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(6, 3, 0.6)
		head.mesh = bm
		head.material_override = lamp
		head.position = base + Vector3(0, 35, 0)
		head.rotation.y = -sx * 0.5
		add_child(head)
	# Corner flags.
	var flag_mat := StandardMaterial3D.new()
	flag_mat.albedo_color = Color(0.95, 0.85, 0.1)
	for sx2: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			var c := Vector3(sx2 * Pitch.HALF_L, 0, sz * Pitch.HALF_W)
			_cyl(c, c + Vector3(0, 1.5, 0), 0.02, _white)
			var fm := MeshInstance3D.new()
			var fb := BoxMesh.new()
			fb.size = Vector3(0.35, 0.25, 0.02)
			fm.mesh = fb
			fm.material_override = flag_mat
			fm.position = c + Vector3(-sx2 * 0.18, 1.38, 0)
			add_child(fm)


func _board(pos: Vector3, size: Vector3, col: Color) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = 0.8
	mi.material_override = m
	mi.position = pos
	add_child(mi)


func _stand(base: Vector3, yaw: float, length: float, crowd_sh: Shader, wall: Material, roof: Material) -> void:
	var root := Node3D.new()
	root.position = base
	root.rotation.y = yaw
	add_child(root)
	var depth := 24.0
	var rise := 13.0
	var slope := atan2(rise, depth)
	var tier := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(length, sqrt(depth * depth + rise * rise))
	tier.mesh = pm
	var cm := ShaderMaterial.new()
	cm.shader = crowd_sh
	tier.material_override = cm
	tier.rotation.x = slope
	tier.position = Vector3(0, 1.5 + rise * 0.5, -depth * 0.5)
	root.add_child(tier)
	var front := MeshInstance3D.new()
	var fb := BoxMesh.new()
	fb.size = Vector3(length, 1.5, 0.4)
	front.mesh = fb
	front.material_override = wall
	front.position = Vector3(0, 0.75, 0)
	root.add_child(front)
	var back := MeshInstance3D.new()
	var bb := BoxMesh.new()
	bb.size = Vector3(length, rise + 8.0, 1.0)
	back.mesh = bb
	back.material_override = wall
	back.position = Vector3(0, (rise + 8.0) * 0.5, -depth - 0.5)
	root.add_child(back)
	var top := MeshInstance3D.new()
	var tb := BoxMesh.new()
	tb.size = Vector3(length, 0.5, depth * 0.75)
	top.mesh = tb
	top.material_override = roof
	top.position = Vector3(0, rise + 8.0, -depth + depth * 0.375)
	root.add_child(top)
