class_name MatchSetup
extends RefCounted
## Everything needed to start a match. Used by quick match, career and diagnostics.

var seed := 1
var duration := 360.0
var human_team := -1          ## -1 = AI vs AI
var difficulty := 1
var teams: Array = [{}, {}]   ## see make_team()
var fixture_id := ""          ## career fixture this match belongs to ("" for exhibition)


## players: Array of 11 Dictionaries in formation slot order:
## {id, name, number, attrs:{pace,passing,shooting,control,defending,stamina,goalkeeping}}
static func make_team(club_id: String, tname: String, short_name: String, kit: Color, kit2: Color, players: Array, bench: Array = []) -> Dictionary:
	return {"club_id": club_id, "name": tname, "short": short_name, "kit": kit, "kit2": kit2, "players": players, "bench": bench, "tactics": null}


static func generic_player(slot: int, team_tag: String, level: float, rng: RandomNumberGenerator) -> Dictionary:
	var role := slot
	var pos := Attr.position_of_role(role)
	var a := {}
	for k in Attr.KEYS:
		a[k] = int(clampf(level + rng.randf_range(-6.0, 6.0), 30.0, 95.0))
	match pos:
		"GK":
			a["goalkeeping"] = int(clampf(level + 6.0, 30, 95))
			a["shooting"] = 30
			a["defending"] = 35
		"DF":
			a["defending"] = int(clampf(level + 7.0, 30, 95))
			a["shooting"] = int(level - 14.0)
			a["goalkeeping"] = 10
		"MF":
			a["passing"] = int(clampf(level + 6.0, 30, 95))
			a["goalkeeping"] = 10
		_:
			a["shooting"] = int(clampf(level + 7.0, 30, 95))
			a["defending"] = int(level - 16.0)
			a["goalkeeping"] = 10
	return {"id": "%s_%d" % [team_tag, slot], "name": "%s %d" % [SimPlayer.ROLE_NAMES[role], slot + 1], "number": slot + 1, "attrs": a}


static func exhibition(seed_: int, level_home := 70.0, level_away := 70.0) -> MatchSetup:
	var s := MatchSetup.new()
	s.seed = seed_
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_ * 7919 + 13
	var hp: Array = []
	var ap: Array = []
	for i in 11:
		hp.append(generic_player(i, "H", level_home, rng))
		ap.append(generic_player(i, "A", level_away, rng))
	s.teams[0] = make_team("home", "Хозяева", "ХОЗ", Color(0.85, 0.12, 0.12), Color(1, 1, 1), hp)
	s.teams[1] = make_team("away", "Гости", "ГОС", Color(0.15, 0.3, 0.85), Color(0.95, 0.9, 0.2), ap)
	return s
