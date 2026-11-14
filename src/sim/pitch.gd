class_name Pitch
extends RefCounted
## Pitch geometry (metres). Simulation plane: x along the length, y across the width.
## Presentation maps sim (x, y, height) to world (x, height, y).

const LENGTH := 105.0
const WIDTH := 68.0
const HALF_L := 52.5
const HALF_W := 34.0
const GOAL_HALF_W := 3.66
const GOAL_H := 2.44
const POST_R := 0.06
const BALL_R := 0.11
const PEN_DEPTH := 16.5
const PEN_HALF_W := 20.16
const SIX_DEPTH := 5.5
const SIX_HALF_W := 9.16
const PEN_SPOT := 11.0
const CIRCLE_R := 9.15
const NET_DEPTH := 2.0


static func in_pen_area(pos: Vector2, goal_sign: float) -> bool:
	## goal_sign: +1 for the goal at x = +HALF_L, -1 for the goal at x = -HALF_L.
	var lx := pos.x * goal_sign
	return lx > HALF_L - PEN_DEPTH and lx <= HALF_L + 0.5 and absf(pos.y) < PEN_HALF_W


static func clamp_inside(pos: Vector2, margin: float) -> Vector2:
	return Vector2(clampf(pos.x, -HALF_L + margin, HALF_L - margin), clampf(pos.y, -HALF_W + margin, HALF_W - margin))
