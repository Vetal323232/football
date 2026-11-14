class_name PlayerCommand
extends RefCounted
## What a controller (human or AI) asks a player to do this tick.
## Both use exactly this interface, so mechanics are shared.

var move := Vector2.ZERO      ## desired velocity direction, length 0..1
var sprint := false
var face := Vector2.ZERO      ## optional facing override (zero = follow movement)
var tackle := false           ## edge: start a tackle this tick
var kick: KickRequest = null  ## edge: kick as soon as the ball is playable
var dive := Vector2.ZERO      ## goalkeeper: start a dive toward this point (zero = none)


func clear() -> void:
	move = Vector2.ZERO
	sprint = false
	face = Vector2.ZERO
	tackle = false
	kick = null
	dive = Vector2.ZERO
