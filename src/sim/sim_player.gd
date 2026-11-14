class_name SimPlayer
extends RefCounted
## One footballer in the simulation. Attributes are normalised 0..1 (see Attr).

enum Role { GK, LB, LCB, RCB, RB, DM, LCM, RCM, LW, ST, RW }
const ROLE_NAMES: Array[String] = ["GK", "LB", "LCB", "RCB", "RB", "DM", "LCM", "RCM", "LW", "ST", "RW"]

var id := 0
var team := 0
var role := Role.GK
var uid := ""
var pname := ""
var number := 0

var pace := 0.5
var passing := 0.5
var shooting := 0.5
var control := 0.5
var defending := 0.5
var stamina_attr := 0.5
var goalkeeping := 0.1

var pos := Vector2.ZERO
var vel := Vector2.ZERO
var facing := Vector2.RIGHT
var stamina := 1.0
var fitness := 1.0
var distance_run := 0.0

var kick_lock := 0.0
var stun := 0.0
var tackle_t := 0.0
var tackle_recover := 0.0
var tackle_cd := 0.0
var tackle_dir := Vector2.RIGHT
var tackle_done := false
var dive_t := 0.0
var dive_recover := 0.0
var dive_dir := Vector2.ZERO
var pending_kick: KickRequest = null
var pending_kick_t := 0.0
var has_ball_time := 0.0

var is_human := false
var cmd := PlayerCommand.new()

## Presentation hints (never read by gameplay).
var anim := &""
var anim_t := 0.0


func is_keeper() -> bool:
	return role == Role.GK


func top_speed(tn: GameTuning) -> float:
	var base := lerpf(tn.sprint_speed_min, tn.sprint_speed_max, pace)
	return base * (0.84 + 0.16 * smoothstep(0.0, 0.5, stamina)) * (0.92 + 0.08 * fitness)


func accel(tn: GameTuning) -> float:
	return tn.accel_base + tn.accel_attr * pace


func can_act() -> bool:
	return stun <= 0.0 and tackle_t <= 0.0 and tackle_recover <= 0.0 and dive_t <= 0.0 and dive_recover <= 0.0


func can_touch_ball() -> bool:
	return kick_lock <= 0.0 and stun <= 0.0 and tackle_recover <= 0.0 and dive_recover <= 0.0


## Clear everything that belongs to the moment rather than to the slot: used when a
## substitute takes over. Position, facing, role and control flag are kept.
func reset_transient() -> void:
	vel = Vector2.ZERO
	distance_run = 0.0
	kick_lock = 0.0
	stun = 0.0
	tackle_t = 0.0
	tackle_recover = 0.0
	tackle_cd = 0.0
	tackle_done = false
	dive_t = 0.0
	dive_recover = 0.0
	dive_dir = Vector2.ZERO
	pending_kick = null
	pending_kick_t = 0.0
	has_ball_time = 0.0
	cmd.clear()
	anim = &""
	anim_t = 0.0


func set_anim(a: StringName, t: float) -> void:
	anim = a
	anim_t = t
