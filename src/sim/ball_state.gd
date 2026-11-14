class_name BallState
extends RefCounted
## Minimal kinematic ball state with free-flight / rolling integration.
## Used by the live ball and by trajectory prediction (same physics for both).

var pos := Vector2.ZERO
var h := 0.0
var vel := Vector2.ZERO
var vh := 0.0


func copy_from(o: BallState) -> void:
	pos = o.pos
	h = o.h
	vel = o.vel
	vh = o.vh


func advance(dt: float, tn: GameTuning) -> void:
	if h > 0.0 or vh > 0.0:
		var sp3 := sqrt(vel.length_squared() + vh * vh)
		var drag := tn.air_drag * sp3
		vel -= vel * (drag * dt)
		vh -= (tn.gravity + vh * drag) * dt
		pos += vel * dt
		h += vh * dt
		if h <= 0.0:
			h = 0.0
			if vh < -tn.bounce_min:
				vh = -vh * tn.bounce_restitution
				vel *= tn.bounce_friction
			else:
				vh = 0.0
	else:
		var sp := vel.length()
		if sp > 0.0:
			var ns := maxf(0.0, sp - tn.roll_decel * dt)
			vel *= ns / sp
		pos += vel * dt


## Time for a rolling ball launched at v0 to cover distance d (INF if it stops short).
static func roll_time(v0: float, d: float, decel: float) -> float:
	var disc := v0 * v0 - 2.0 * decel * d
	if disc < 0.0:
		return INF
	return (v0 - sqrt(disc)) / decel


## Launch speed so a rolling ball arrives at distance d with speed v_arrive.
static func roll_speed_for(d: float, v_arrive: float, decel: float) -> float:
	return sqrt(v_arrive * v_arrive + 2.0 * decel * d)
