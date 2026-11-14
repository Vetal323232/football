class_name LeagueData
extends RefCounted
## Static league definition (original fictional clubs) and squad generation.

const PATH := "res://data/league.json"
## Squad template: position group and the formation slots it can fill.
const SQUAD_POSITIONS: Array[String] = ["GK", "GK", "DF", "DF", "DF", "DF", "DF", "DF", "DF", "MF", "MF", "MF", "MF", "MF", "MF", "FW", "FW", "FW", "FW", "FW"]
const SLOT_POS: Array[String] = ["GK", "DF", "DF", "DF", "DF", "MF", "MF", "MF", "FW", "FW", "FW"]

static var _data: Dictionary = {}


static func data() -> Dictionary:
	if _data.is_empty():
		var f := FileAccess.open(PATH, FileAccess.READ)
		_data = JSON.parse_string(f.get_as_text())
	return _data


static func clubs() -> Array:
	return data()["clubs"]


static func club(id: String) -> Dictionary:
	for c: Dictionary in clubs():
		if c["id"] == id:
			return c
	return {}


## Deterministic squad of 20 for a club. Returns Array of player dictionaries.
static func generate_squad(club_def: Dictionary, rng: RandomNumberGenerator, used_names: Dictionary) -> Array:
	var out := []
	var level := float(club_def["level"])
	var d := data()
	var numbers := [1, 12, 2, 3, 4, 5, 13, 14, 15, 6, 8, 10, 16, 17, 18, 7, 9, 11, 19, 20]
	for i in SQUAD_POSITIONS.size():
		var pos := SQUAD_POSITIONS[i]
		var pname := ""
		for attempt in 50:
			pname = "%s %s" % [d["first_names"][rng.randi() % d["first_names"].size()], d["last_names"][rng.randi() % d["last_names"].size()]]
			if not used_names.has(pname):
				break
		used_names[pname] = true
		var starter := (pos == "GK" and i == 0) or (pos == "DF" and i < 6) or (pos == "MF" and i < 12) or (pos == "FW" and i < 18)
		var lvl := level + (2.0 if starter else -5.0) + rng.randf_range(-4.0, 4.0)
		var age := int(clampf(rng.randfn(25.5, 4.0), 17.0, 35.0))
		if age < 21:
			lvl -= 4.0
		out.append({
			"id": "%s_%02d" % [club_def["id"], i + 1],
			"name": pname, "age": age, "pos": pos, "number": numbers[i],
			"attrs": make_attrs(pos, lvl, rng),
			"club": club_def["id"], "listed": false, "apps": 0, "growth": {},
		})
	return out


static func make_attrs(pos: String, lvl: float, rng: RandomNumberGenerator) -> Dictionary:
	var prof := {}
	match pos:
		"GK":
			prof = {"pace": -18, "passing": -12, "shooting": -35, "control": -14, "defending": -25, "stamina": -8, "goalkeeping": 4}
		"DF":
			prof = {"pace": -1, "passing": -6, "shooting": -18, "control": -6, "defending": 6, "stamina": 1, "goalkeeping": -60}
		"MF":
			prof = {"pace": -2, "passing": 6, "shooting": -5, "control": 4, "defending": -6, "stamina": 4, "goalkeeping": -60}
		_:
			prof = {"pace": 5, "passing": -3, "shooting": 7, "control": 4, "defending": -22, "stamina": -1, "goalkeeping": -60}
	var a := {}
	for k: String in Attr.KEYS:
		a[k] = int(clampf(lvl + float(prof[k]) + rng.randf_range(-5.0, 5.0), 8.0, 97.0))
	return a


## Price in currency units from rating and age (documented in DESIGN.md).
static func player_value(p: Dictionary) -> int:
	var ovr := float(Attr.overall(p["attrs"], p["pos"]))
	var base := 30000.0 * pow(1.14, ovr - 50.0)
	var age := float(p["age"])
	var age_f := 1.0
	if age <= 23.0:
		age_f = 1.25 + (23.0 - age) * 0.05
	elif age >= 29.0:
		age_f = maxf(0.25, 1.0 - (age - 28.0) * 0.12)
	return int(round(base * age_f / 10000.0)) * 10000


static func color(hex: String) -> Color:
	return Color.html(hex)


## Best eleven in formation slot order from a list of player dicts (ids kept).
static func auto_lineup(squad: Array) -> Array:
	var pool := squad.duplicate()
	var lineup := []
	for slot in SLOT_POS.size():
		var want := SLOT_POS[slot]
		var best: Dictionary = {}
		var best_v := -1.0
		for p: Dictionary in pool:
			var v := float(Attr.overall(p["attrs"], want))
			if p["pos"] != want:
				v -= 12.0 if want != "GK" and p["pos"] != "GK" else 60.0
			v *= 0.6 + 0.4 * float(p.get("fitness", 1.0))
			if v > best_v:
				best_v = v
				best = p
		pool.erase(best)
		lineup.append(best["id"])
	return lineup


## Build a MatchSetup team dictionary from a club record and its players.
static func team_setup(club_rec: Dictionary, players: Dictionary, lineup: Array) -> Dictionary:
	var start := []
	for slot in lineup.size():
		start.append(_match_player(players[lineup[slot]]))
	var bench := []
	for pid: String in club_rec["squad"]:
		if not lineup.has(pid):
			bench.append(_match_player(players[pid]))
	bench.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["ovr"]) > int(b["ovr"]))
	return MatchSetup.make_team(club_rec["id"], club_rec["name"], club_rec["short"], color(club_rec["kit"]), color(club_rec["kit2"]), start, bench.slice(0, 7))


static func _match_player(p: Dictionary) -> Dictionary:
	return {"id": p["id"], "name": p["name"], "number": p["number"], "attrs": p["attrs"], "pos": p["pos"],
		"ovr": Attr.overall(p["attrs"], p["pos"]), "fitness": float(p.get("fitness", 1.0))}


## Exhibition squads: deterministic, independent from any career save.
static func exhibition_setup(home_id: String, away_id: String, seed_: int) -> MatchSetup:
	var s := MatchSetup.new()
	s.seed = seed_
	var used := {}
	var ids := [home_id, away_id]
	for i in 2:
		var cd := club(ids[i])
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(cd["id"]) & 0x7fffffff
		var squad := generate_squad(cd, rng, used)
		var players := {}
		var rec := {"id": cd["id"], "name": cd["name"], "short": cd["short"], "kit": cd["kit"], "kit2": cd["kit2"], "squad": []}
		for p: Dictionary in squad:
			players[p["id"]] = p
			rec["squad"].append(p["id"])
		s.teams[i] = team_setup(rec, players, auto_lineup(squad))
	return s
