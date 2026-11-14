class_name SimTeam
extends RefCounted

var index := 0
var club_id := ""
var tname := ""
var short_name := ""
var kit := Color.WHITE
var kit2 := Color.BLACK
var keeper_kit := Color.YELLOW
var dir := 1.0            ## +1 attacks toward +x, -1 toward -x
var score := 0
var tactics: TeamTactics
var ai: TeamAI
var human := false
var player_ids: Array[int] = []
var bench: Array = []      ## Array of player dictionaries (not on the pitch)
var subs_made := 0
var stats := MatchStats.new()


func to_local(p: Vector2) -> Vector2:
	return p * dir


func to_world(p: Vector2) -> Vector2:
	return p * dir
