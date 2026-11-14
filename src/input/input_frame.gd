class_name InputFrame
extends RefCounted
## One fixed-step sample of the human player's intent, already converted to
## pitch-plane directions. Produced by the view layer (or by tests).

var move := Vector2.ZERO       ## sim-plane direction, length 0..1
var sprint := false
var pass_pressed := false
var through_pressed := false
var lob_pressed := false
var shot_held := false
var shot_released := false
var tackle_pressed := false
var switch_pressed := false


func clear_edges() -> void:
	pass_pressed = false
	through_pressed = false
	lob_pressed = false
	shot_released = false
	tackle_pressed = false
	switch_pressed = false
