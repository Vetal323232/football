class_name KickRequest
extends RefCounted

enum Kind { PASS, THROUGH, LOB, SHOT, CLEAR }

var kind := Kind.PASS
var dir := Vector2.RIGHT
var speed := 10.0
var vh := 0.0
var receiver := -1
var target := Vector2.ZERO


static func make(kind_: int, dir_: Vector2, speed_: float, vh_: float, receiver_: int, target_: Vector2) -> KickRequest:
	var k := KickRequest.new()
	k.kind = kind_
	k.dir = dir_.normalized() if dir_.length_squared() > 0.0 else Vector2.RIGHT
	k.speed = speed_
	k.vh = vh_
	k.receiver = receiver_
	k.target = target_
	return k
