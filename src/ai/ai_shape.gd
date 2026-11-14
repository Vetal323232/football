class_name AIShape
extends RefCounted
## 4-3-3 formation geometry in team-local coordinates (x toward the opponent goal,
## y > 0 is the right flank). Returns home ("anchor") positions that shift with
## the ball; the coordinator then adjusts them per duty.

const R := SimPlayer.Role


static func side_of(role: int) -> float:
	match role:
		R.LB, R.LCB, R.LCM, R.LW:
			return -1.0
		R.RB, R.RCB, R.RCM, R.RW:
			return 1.0
	return 0.0


## Attacking shape around focus f (ball / expected reception point).
static func attack_anchor(role: int, f: Vector2, tac: TeamTactics, off_line: float) -> Vector2:
	var w := lerpf(0.78, 1.0, tac.width)
	var s := side_of(role)
	var ball_side := signf(f.y) == s and absf(f.y) > 5.0
	var a := Vector2.ZERO
	match role:
		R.GK:
			a = Vector2(clampf(f.x - 40.0, -50.0, -34.0), f.y * 0.1)
		R.LCB, R.RCB:
			a = Vector2(clampf(f.x - 19.0, -40.0, 4.0), s * 10.0 + f.y * 0.25)
		R.LB, R.RB:
			var x := f.x - 3.0 if ball_side else f.x - 13.0
			if f.x < -17.0:
				x = f.x + 4.0 if ball_side else f.x - 2.0
			a = Vector2(clampf(x, -38.0, 32.0), s * 28.0 * w)
			if not ball_side and absf(f.y) > 12.0:
				a.y = s * 20.0 * w
		R.DM:
			a = Vector2(clampf(f.x - 9.0, -34.0, 20.0), clampf(f.y * 0.45, -12.0, 12.0))
		R.LCM, R.RCM:
			a = Vector2(clampf(f.x + (7.0 if ball_side else 4.0), -26.0, 36.0), s * 10.0 + f.y * 0.35)
		R.LW, R.RW:
			a = Vector2(clampf(f.x + 17.0, -8.0, 45.0), s * 27.0 * w)
			if not ball_side and f.x > 15.0 and absf(f.y) > 8.0:
				a.y = s * 15.0
		R.ST:
			a = Vector2(clampf(f.x + 22.0, 2.0, 46.0), clampf(f.y * 0.3, -9.0, 9.0))
	if role >= R.LCM:
		a.x = minf(a.x, maxf(off_line - 1.0, f.x))
	a.y = clampf(a.y, -Pitch.HALF_W + 2.5, Pitch.HALF_W - 2.5)
	return a


static func defence_line_x(b: Vector2, tac: TeamTactics) -> float:
	var gap := clampf((b.x + Pitch.HALF_L) * 0.42, 5.0, 24.0)
	var max_line := lerpf(-24.0, -8.0, tac.line_height)
	return clampf(b.x - gap, -Pitch.HALF_L + 6.5, max_line)


## Defensive block relative to ball position b.
static func defend_anchor(role: int, b: Vector2, tac: TeamTactics) -> Vector2:
	var s := side_of(role)
	var dx := defence_line_x(b, tac)
	var shift := b.y * 0.55
	var a := Vector2.ZERO
	match role:
		R.GK:
			a = Vector2(-Pitch.HALF_L + 3.0, 0.0)
		R.LCB, R.RCB:
			a = Vector2(dx, s * 5.5 + shift * 0.8)
		R.LB, R.RB:
			a = Vector2(dx + 0.5, s * 16.5 + shift)
		R.DM:
			a = Vector2(dx + 7.5, clampf(shift * 0.7, -12.0, 12.0))
		R.LCM, R.RCM:
			a = Vector2(dx + 12.0, s * 10.0 + shift)
		R.LW, R.RW:
			var far := signf(b.y) != s and absf(b.y) > 8.0
			a = Vector2(dx + (19.0 if far else 14.0), s * 21.0 + shift * 0.8)
		R.ST:
			a = Vector2(clampf(dx + 30.0, -20.0, 20.0), clampf(shift * 0.4, -10.0, 10.0))
	a.x = clampf(a.x, -Pitch.HALF_L + 2.0, Pitch.HALF_L - 2.0)
	a.y = clampf(a.y, -Pitch.HALF_W + 2.0, Pitch.HALF_W - 2.0)
	return a


static func kickoff_pos(role: int, taking: bool) -> Vector2:
	match role:
		R.GK:
			return Vector2(-47.0, 0.0)
		R.LB:
			return Vector2(-27.0, -22.0)
		R.LCB:
			return Vector2(-31.0, -8.0)
		R.RCB:
			return Vector2(-31.0, 8.0)
		R.RB:
			return Vector2(-27.0, 22.0)
		R.DM:
			return Vector2(-19.0, 0.0)
		R.LCM:
			return Vector2(-11.0, -11.0) if not taking else Vector2(-7.0, -7.0)
		R.RCM:
			return Vector2(-11.0, 11.0) if not taking else Vector2(-6.0, 5.0)
		R.LW:
			return Vector2(-2.0, -24.0)
		R.RW:
			return Vector2(-2.0, 24.0)
	return Vector2(-0.5, 0.0) if taking else Vector2(-10.5, 0.0)


## Attacking positions for a corner taken from the side with local y sign cs.
static func corner_attack_pos(role: int, cs: float) -> Vector2:
	match role:
		R.GK:
			return Vector2(-40.0, 0.0)
		R.LCB:
			return Vector2(45.5, cs * 3.5)        # near post
		R.RCB:
			return Vector2(44.5, -cs * 4.5)       # far post
		R.ST:
			return Vector2(42.0, 0.0)             # penalty spot
		R.LCM:
			return Vector2(34.0, cs * 6.0)        # edge of the box
		R.RCM:
			return Vector2(30.0, -cs * 8.0)
		R.DM:
			return Vector2(8.0, 0.0)              # rest defence
		R.LB:
			return Vector2(2.0, -14.0)
		R.RB:
			return Vector2(2.0, 14.0)
		R.LW, R.RW:
			return Vector2(43.0, cs * 24.0) if side_of(role) == cs else Vector2(41.0, -cs * 9.0)
	return Vector2.ZERO


## Defending positions for a corner taken from the side with (our) local y sign cs.
static func corner_defend_pos(role: int, cs: float) -> Vector2:
	match role:
		R.GK:
			return Vector2(-51.6, -cs * 0.8)
		R.LB:
			return Vector2(-48.0, cs * 6.0)
		R.LCB:
			return Vector2(-47.0, cs * 2.0)
		R.RCB:
			return Vector2(-47.0, -cs * 2.5)
		R.RB:
			return Vector2(-48.0, -cs * 6.5)
		R.DM:
			return Vector2(-43.0, 0.0)
		R.LCM:
			return Vector2(-41.0, cs * 7.0)
		R.RCM:
			return Vector2(-39.0, -cs * 7.0)
		R.LW:
			return Vector2(-44.0, cs * 13.0)
		R.RW:
			return Vector2(-33.0, -cs * 4.0)
	return Vector2(-18.0, 0.0)


static func goal_kick_pos(role: int) -> Vector2:
	match role:
		R.GK:
			return Vector2(-47.0, 0.0)
		R.LCB:
			return Vector2(-37.0, -15.0)
		R.RCB:
			return Vector2(-37.0, 15.0)
		R.LB:
			return Vector2(-29.0, -29.0)
		R.RB:
			return Vector2(-29.0, 29.0)
		R.DM:
			return Vector2(-27.0, 0.0)
		R.LCM:
			return Vector2(-13.0, -12.0)
		R.RCM:
			return Vector2(-13.0, 12.0)
		R.LW:
			return Vector2(4.0, -27.0)
		R.RW:
			return Vector2(4.0, 27.0)
	return Vector2(10.0, 0.0)
