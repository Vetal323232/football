class_name MatchStats
extends RefCounted

var possession_ticks := 0
var passes := 0
var passes_completed := 0
var interceptions := 0
var shots := 0
var shots_on_target := 0
var goals := 0
var tackles := 0
var tackles_won := 0
var turnovers := 0
var offsides := 0
var corners := 0
var throw_ins := 0
var goal_kicks := 0
var saves := 0
var xg := 0.0


func to_dict() -> Dictionary:
	return {
		"passes": passes, "passes_completed": passes_completed, "interceptions": interceptions,
		"shots": shots, "shots_on_target": shots_on_target, "goals": goals, "tackles": tackles,
		"tackles_won": tackles_won, "turnovers": turnovers, "offsides": offsides, "corners": corners,
		"throw_ins": throw_ins, "goal_kicks": goal_kicks, "saves": saves, "xg": snappedf(xg, 0.01),
		"possession_ticks": possession_ticks,
	}
