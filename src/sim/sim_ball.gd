class_name SimBall
extends BallState
## The single authoritative match ball.

var owner := -1            ## player id controlling the ball at his feet
var held_by := -1          ## goalkeeper id holding the ball in his hands
var dead := false          ## placed for a restart: no physics
var owner_lock := 0.0      ## time during which possession cannot change by proximity
var last_touch := -1
var last_touch_team := -1
var kick_id := 0
var kick_kind := -1        ## KickRequest.Kind of the last deliberate kick, -1 after deflection/claim
var kicker := -1
var kick_receiver := -1
var kick_target := Vector2.ZERO
var kick_tick := 0
var in_pass := false       ## a deliberate kick is travelling, nobody has touched it yet
var restart_taker := -1    ## may not touch the ball again until someone else does
var no_offside := false    ## ball came directly from throw-in / corner / goal kick
var backpass_team := -1    ## deliberate kick by this team: its keeper may not handle
var save_roll_kick := -1   ## kick id for which the keeper save roll was already made
var held_time := 0.0


func is_free() -> bool:
	return owner < 0 and held_by < 0 and not dead


func speed() -> float:
	return vel.length()
