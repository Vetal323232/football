class_name AIAgent
extends RefCounted
## Per-player tactical memory kept by the team coordinator. Survives changes of
## human control, so a player's responsibilities are never wiped by a switch.

enum Duty { NONE, GK, CARRIER, RECEIVER, CHASE, SUPPORT, OUTLET, RUNNER, WIDTH, FINISHER, REST, SHAPE, PRESS, COVER, MARK, ZONE, PROTECT, RESTART }
const DUTY_NAMES: Array[String] = ["-", "GK", "CARRY", "RECV", "CHASE", "SUPPORT", "OUTLET", "RUNNER", "WIDTH", "FINISH", "REST", "SHAPE", "PRESS", "COVER", "MARK", "ZONE", "PROTECT", "RESTART"]

var duty := Duty.NONE
var duty_since := 0.0
var anchor := Vector2.ZERO        ## world
var target := Vector2.ZERO        ## world
var target_score := -INF
var next_refresh := 0.0
var sprint := false
var face_ball := false
var mark_id := -1
var reason := ""

# Pressing.
var engage := false
var engage_until := 0.0
var tackle_ready := 0.0
var in_reach_since := -1.0

# Runs behind the line.
var run_state := 0                ## 0 hold, 1 run, 2 return
var run_until := 0.0
var run_cooldown := 0.0
var run_target := Vector2.ZERO
var offside_since := -1.0

# On-ball decision.
var next_decision := 0.0
var commit_until := 0.0
var move_dir := Vector2.ZERO
var move_sprint := false
var decision_label := ""
var options: Array = []           ## debug: [{label, ev, target, p}]
var last_passer := -1
var last_pass_time := -10.0

# Goalkeeper.
var save_kick_id := -1
var react_until := 0.0
var release_at := 0.0

# Ball chase.
var intercept := Vector2.ZERO
var intercept_t := 0.0


func set_duty(d: int, now: float, why: String) -> void:
	if d != duty:
		duty = d
		duty_since = now
		target_score = -INF
		next_refresh = 0.0
	reason = why
