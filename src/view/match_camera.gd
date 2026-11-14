extends Camera3D
## Elevated touchline (broadcast) camera. Follows the ball smoothly along the
## pitch and looks slightly ahead; no shake or effects that hide the play.

@export var height := 33.0
@export var distance := 42.0
@export var follow_x := 0.82
@export var smooth := 3.2
@export var base_fov := 27.0

var _focus := Vector3.ZERO


func _ready() -> void:
	if Game.cli.has("fov"):
		base_fov = float(Game.cli["fov"])
	if Game.cli.has("camh"):
		height = float(Game.cli["camh"])
	if Game.cli.has("camd"):
		distance = float(Game.cli["camd"])
	fov = base_fov
	far = 400.0
	near = 0.5
	_apply()


func snap_to(ball: Vector3) -> void:
	_focus = _target(ball, Vector3.ZERO)
	_apply()


func _target(ball: Vector3, controlled: Vector3) -> Vector3:
	var p := ball
	if controlled != Vector3.ZERO:
		p = ball.lerp(controlled, 0.25)
	var limit := Pitch.HALF_L - 20.0
	return Vector3(clampf(p.x * follow_x, -limit, limit), 0.0, clampf(p.z * 0.45, -12.0, 12.0))


func follow(ball: Vector3, controlled: Vector3, delta: float) -> void:
	var t := _target(ball, controlled)
	_focus = _focus.lerp(t, clampf(delta * smooth, 0.0, 1.0))
	_apply()


func _apply() -> void:
	var cam_pos := Vector3(_focus.x, height, Pitch.HALF_W + distance + _focus.z * 0.5)
	global_position = cam_pos
	look_at(Vector3(_focus.x, 0.0, _focus.z - 2.0), Vector3.UP)
