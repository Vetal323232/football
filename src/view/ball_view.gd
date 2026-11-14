extends Node3D
## Visual ball with rolling rotation and a blob shadow that makes height readable.

var _mesh: MeshInstance3D
var _blob: MeshInstance3D
var _prev := Vector3.ZERO
var _cur := Vector3.ZERO


func _ready() -> void:
	_mesh = MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = Pitch.BALL_R
	s.height = Pitch.BALL_R * 2.0
	s.radial_segments = 16
	s.rings = 8
	_mesh.mesh = s
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
varying vec3 n;
void vertex() { n = normalize(VERTEX); }
void fragment() {
	float t = 1.618034;
	float m = 0.0;
	vec3 nn = normalize(n);
	m = max(m, abs(dot(nn, normalize(vec3(0.0, 1.0, t)))));
	m = max(m, abs(dot(nn, normalize(vec3(0.0, -1.0, t)))));
	m = max(m, abs(dot(nn, normalize(vec3(1.0, t, 0.0)))));
	m = max(m, abs(dot(nn, normalize(vec3(-1.0, t, 0.0)))));
	m = max(m, abs(dot(nn, normalize(vec3(t, 0.0, 1.0)))));
	m = max(m, abs(dot(nn, normalize(vec3(t, 0.0, -1.0)))));
	ALBEDO = mix(vec3(0.97), vec3(0.08), step(0.9, m));
	ROUGHNESS = 0.5;
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	_mesh.material_override = m
	add_child(_mesh)
	_blob = MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(0.5, 0.5)
	_blob.mesh = pm
	var bs := Shader.new()
	bs.code = """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never;
uniform float strength = 0.5;
void fragment() {
	float d = length(UV - vec2(0.5)) * 2.0;
	ALBEDO = vec3(0.0);
	ALPHA = smoothstep(1.0, 0.3, d) * strength;
}
"""
	var bm := ShaderMaterial.new()
	bm.shader = bs
	_blob.material_override = bm
	_blob.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_blob)
	top_level = true


func tick(ball: SimBall) -> void:
	_prev = _cur
	_cur = Vector3(ball.pos.x, ball.h + Pitch.BALL_R, ball.pos.y)


func snap(ball: SimBall) -> void:
	_cur = Vector3(ball.pos.x, ball.h + Pitch.BALL_R, ball.pos.y)
	_prev = _cur


func animate(frac: float) -> Vector3:
	var p := _prev.lerp(_cur, frac)
	if _prev.distance_to(_cur) > 4.0:
		p = _cur
	var moved := p - _mesh.global_position
	_mesh.global_position = p
	var flat := Vector3(moved.x, 0.0, moved.z)
	if flat.length() > 0.0005:
		var axis := Vector3.UP.cross(flat.normalized())
		_mesh.global_rotate(axis.normalized(), flat.length() / Pitch.BALL_R)
	var h := p.y - Pitch.BALL_R
	_blob.global_position = Vector3(p.x, 0.02, p.z)
	var sc := 1.0 + clampf(h, 0.0, 12.0) * 0.12
	_blob.scale = Vector3(sc, 1.0, sc)
	(_blob.material_override as ShaderMaterial).set_shader_parameter("strength", clampf(0.55 - h * 0.03, 0.2, 0.55))
	return p
