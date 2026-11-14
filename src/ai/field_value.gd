class_name FieldValue
extends RefCounted
## Positional value model in team-local coordinates (x grows toward the opponent goal).
## Values are rough "probability this possession ends in a goal" units so that
## passes, dribbles, holding and shooting can be compared on one scale.


static func sigmoid(x: float) -> float:
	return 1.0 / (1.0 + exp(-x))


## Chance of scoring with an unopposed shot from this spot.
static func xg_pos(lp: Vector2) -> float:
	var gx := Pitch.HALF_L - lp.x
	if gx < 0.3:
		gx = 0.3
	var d := sqrt(gx * gx + lp.y * lp.y)
	var a1 := atan2(Pitch.GOAL_HALF_W - lp.y, gx)
	var a2 := atan2(-Pitch.GOAL_HALF_W - lp.y, gx)
	var ang := absf(a1 - a2)
	return clampf(1.15 * exp(-d / 8.5) * (0.3 + 0.7 * minf(1.0, ang / 0.62)), 0.0, 0.75)


static func value(lp: Vector2, tn: GameTuning) -> float:
	var sx := clampf((lp.x + Pitch.HALF_L) / Pitch.LENGTH, 0.0, 1.0)
	var central := 1.0 - 0.25 * absf(lp.y) / Pitch.HALF_W
	var gd := Vector2(Pitch.HALF_L - lp.x, lp.y).length()
	return tn.value_base + tn.value_progress * pow(sx, 1.6) * central + tn.value_xg * xg_pos(lp) + tn.value_goal_pull * exp(-gd / 20.0)


## Cost of losing the ball here = what the opponent gains by having it here.
static func loss_cost(lp: Vector2, tn: GameTuning) -> float:
	return (value(-lp, tn) + 0.004) * tn.loss_cost_scale


## Shot quality for a concrete shooter and defensive situation.
static func xg_shot(sim: MatchSim, p: SimPlayer) -> float:
	var tm: SimTeam = sim.teams[p.team]
	var lp := tm.to_local(sim.ball.pos)
	var base := xg_pos(lp)
	if base < 0.004:
		return 0.0
	var goal := Vector2(Pitch.HALF_L * tm.dir, 0.0)
	var to_goal := goal - sim.ball.pos
	var dist := to_goal.length()
	var dir := to_goal / maxf(dist, 0.01)
	var f := 1.0
	var keeper_off := 1.0
	for id in sim.teams[1 - p.team].player_ids:
		var o: SimPlayer = sim.players[id]
		var rel := o.pos - sim.ball.pos
		var along := rel.dot(dir)
		var perp := absf(rel.cross(dir))
		if o.is_keeper():
			# Keeper far from the shot line leaves the goal open.
			if along < 0.0 or perp > 1.5 + along * 0.08:
				keeper_off = 1.7
			elif along < 3.0:
				f *= 0.6
			continue
		if along > 0.3 and along < minf(dist, 14.0):
			var cone := 0.5 + along * 0.14
			if perp < cone:
				f *= 0.5 if along < 4.0 else 0.72
	f *= keeper_off
	f *= 0.7 + 0.6 * p.shooting
	f *= 1.0 - 0.3 * minf(SimQuery.pressure(sim, p), 1.0)
	return clampf(base * f, 0.0, 0.9)
