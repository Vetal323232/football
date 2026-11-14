class_name CareerState
extends RefCounted
## Club career: one league, fixtures, standings, transfers, development.
## All state lives in `data` (plain JSON-compatible Dictionary) with stable IDs.
## Every mutation is guarded so that results, money and development are applied
## exactly once (fixtures carry a `played` flag; the table is always derived).

const SCHEMA := 1
const MIN_SQUAD := 16
const MAX_SQUAD := 26
const SELL_FACTOR := 0.85
const ROUNDS := 14

var data := {}


static func create(user_club: String, seed_: int) -> CareerState:
	var cs := CareerState.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_
	var clubs := {}
	var players := {}
	var used := {}
	var ids := []
	for cd: Dictionary in LeagueData.clubs():
		var squad := LeagueData.generate_squad(cd, rng, used)
		var pids := []
		for p: Dictionary in squad:
			players[p["id"]] = p
			pids.append(p["id"])
		clubs[cd["id"]] = {"id": cd["id"], "name": cd["name"], "short": cd["short"], "kit": cd["kit"], "kit2": cd["kit2"],
			"budget": int(cd["budget"]), "squad": pids, "lineup": LeagueData.auto_lineup(squad)}
		ids.append(cd["id"])
	cs.data = {
		"schema": SCHEMA, "season": 1, "round": 0, "user_club": user_club, "seed": seed_,
		"clubs": clubs, "players": players, "fixtures": Schedule.make_fixtures(ids, 1),
		"transfer_list": [], "history": [], "season_over": false, "last_round_results": [],
	}
	cs._refresh_transfer_list()
	return cs


# ------------------------------------------------------------------ queries

func club(id: String) -> Dictionary:
	return data["clubs"][id]


func user() -> Dictionary:
	return data["clubs"][data["user_club"]]


func player(pid: String) -> Dictionary:
	return data["players"][pid]


func squad_of(club_id: String) -> Array:
	var out := []
	for pid: String in club(club_id)["squad"]:
		out.append(data["players"][pid])
	return out


func ovr(pid: String) -> int:
	var p: Dictionary = data["players"][pid]
	return Attr.overall(p["attrs"], p["pos"])


func team_strength(club_id: String) -> float:
	var s := 0.0
	var lineup: Array = club(club_id)["lineup"]
	for i in lineup.size():
		var p: Dictionary = data["players"][lineup[i]]
		s += float(Attr.overall(p["attrs"], LeagueData.SLOT_POS[i]))
	return s / maxf(1.0, lineup.size())


func round_fixtures(round_: int) -> Array:
	var out := []
	for f: Dictionary in data["fixtures"]:
		if int(f["round"]) == round_:
			out.append(f)
	return out


func fixture(id: String) -> Dictionary:
	for f: Dictionary in data["fixtures"]:
		if f["id"] == id:
			return f
	return {}


func user_fixture() -> Dictionary:
	if data["season_over"]:
		return {}
	for f: Dictionary in round_fixtures(int(data["round"])):
		if f["home"] == data["user_club"] or f["away"] == data["user_club"]:
			return f
	return {}


## League table derived from played fixtures: 3 points for a win, 1 for a draw.
## Tie-breaks: goal difference, goals scored, then club id (stable).
func standings() -> Array:
	var rows := {}
	for id: String in data["clubs"]:
		rows[id] = {"club": id, "name": data["clubs"][id]["name"], "p": 0, "w": 0, "d": 0, "l": 0, "gf": 0, "ga": 0, "gd": 0, "pts": 0}
	for f: Dictionary in data["fixtures"]:
		if not f["played"]:
			continue
		var h: Dictionary = rows[f["home"]]
		var a: Dictionary = rows[f["away"]]
		var hg := int(f["hg"])
		var ag := int(f["ag"])
		h["p"] += 1
		a["p"] += 1
		h["gf"] += hg
		h["ga"] += ag
		a["gf"] += ag
		a["ga"] += hg
		if hg > ag:
			h["w"] += 1
			a["l"] += 1
			h["pts"] += 3
		elif hg < ag:
			a["w"] += 1
			h["l"] += 1
			a["pts"] += 3
		else:
			h["d"] += 1
			a["d"] += 1
			h["pts"] += 1
			a["pts"] += 1
	var out := rows.values()
	for r: Dictionary in out:
		r["gd"] = int(r["gf"]) - int(r["ga"])
	out.sort_custom(func(x: Dictionary, y: Dictionary) -> bool:
		if x["pts"] != y["pts"]:
			return int(x["pts"]) > int(y["pts"])
		if x["gd"] != y["gd"]:
			return int(x["gd"]) > int(y["gd"])
		if x["gf"] != y["gf"]:
			return int(x["gf"]) > int(y["gf"])
		return str(x["club"]) < str(y["club"]))
	return out


func position_of(club_id: String) -> int:
	var st := standings()
	for i in st.size():
		if st[i]["club"] == club_id:
			return i + 1
	return 0


# ------------------------------------------------------------------- lineup

func lineup_valid(club_id: String, lineup: Array) -> String:
	var c := club(club_id)
	if lineup.size() != 11:
		return "LINEUP_ERR_COUNT"
	var seen := {}
	for pid: String in lineup:
		if seen.has(pid) or not (c["squad"] as Array).has(pid):
			return "LINEUP_ERR_PLAYER"
		seen[pid] = true
	if data["players"][lineup[0]]["pos"] != "GK":
		return "LINEUP_ERR_GK"
	return ""


func set_lineup(club_id: String, lineup: Array) -> bool:
	if lineup_valid(club_id, lineup) != "":
		return false
	club(club_id)["lineup"] = lineup.duplicate()
	return true


func auto_lineup(club_id: String) -> void:
	club(club_id)["lineup"] = LeagueData.auto_lineup(squad_of(club_id))


func _repair_lineup(club_id: String) -> void:
	if lineup_valid(club_id, club(club_id)["lineup"]) != "":
		auto_lineup(club_id)


func match_setup_for(f: Dictionary, seed_: int) -> MatchSetup:
	var s := MatchSetup.new()
	s.seed = seed_
	s.fixture_id = f["id"]
	var ids := [f["home"], f["away"]]
	for i in 2:
		_repair_lineup(ids[i])
		s.teams[i] = LeagueData.team_setup(club(ids[i]), data["players"], club(ids[i])["lineup"])
	s.human_team = 0 if f["home"] == data["user_club"] else 1
	return s


# ------------------------------------------------------------------- rounds

func _fixture_rng(f: Dictionary, salt: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%d|%s|%d" % [int(data["seed"]), f["id"], salt])
	return rng


static func _poisson(lambda: float, rng: RandomNumberGenerator) -> int:
	var l := exp(-lambda)
	var k := 0
	var p := 1.0
	while true:
		p *= rng.randf()
		if p <= l or k > 9:
			break
		k += 1
	return k


## Quick result model for fixtures that are not played on the pitch.
func simulate_score(f: Dictionary) -> Array:
	var rng := _fixture_rng(f, 1)
	var diff := team_strength(f["home"]) - team_strength(f["away"])
	var lh := 1.45 * exp(diff / 11.0)
	var la := 1.15 * exp(-diff / 11.0)
	return [_poisson(clampf(lh, 0.2, 4.5), rng), _poisson(clampf(la, 0.2, 4.5), rng)]


## Record one fixture result. Returns false (and changes nothing) if already played.
func apply_result(fixture_id: String, hg: int, ag: int, participants: Array = []) -> bool:
	var f := fixture(fixture_id)
	if f.is_empty() or f["played"] or int(f["season"]) != int(data["season"]):
		return false
	f["played"] = true
	f["hg"] = hg
	f["ag"] = ag
	for side: String in ["home", "away"]:
		var cid: String = f[side]
		var took_part := []
		if not participants.is_empty():
			for pid: String in participants:
				if data["players"].has(pid) and data["players"][pid]["club"] == cid:
					took_part.append(pid)
		if took_part.is_empty():
			took_part = (club(cid)["lineup"] as Array).duplicate()
		var rng := _fixture_rng(f, 2 if side == "home" else 3)
		for pid: String in took_part:
			_develop(data["players"][pid], rng)
	return true


## Finish the current round: the user's fixture must already be played (or is
## simulated when `sim_user` is true); all other fixtures are simulated once.
func complete_round(sim_user := false) -> bool:
	if data["season_over"]:
		return false
	var r := int(data["round"])
	var uf := user_fixture()
	if not uf.is_empty() and not uf["played"]:
		if not sim_user:
			return false
		var sc := simulate_score(uf)
		apply_result(uf["id"], sc[0], sc[1])
	var results := []
	for f: Dictionary in round_fixtures(r):
		if not f["played"]:
			_repair_lineup(f["home"])
			_repair_lineup(f["away"])
			var s := simulate_score(f)
			apply_result(f["id"], s[0], s[1])
		results.append(f["id"])
	data["last_round_results"] = results
	data["round"] = r + 1
	if int(data["round"]) >= ROUNDS:
		data["season_over"] = true
		_award_prizes()
	_refresh_transfer_list()
	return true


func _award_prizes() -> void:
	var st := standings()
	for i in st.size():
		club(st[i]["club"])["budget"] = int(club(st[i]["club"])["budget"]) + (st.size() - i) * 350000
	data["history"].append({"season": int(data["season"]), "champion": st[0]["club"], "user_pos": position_of(data["user_club"])})


func start_next_season() -> bool:
	if not data["season_over"]:
		return false
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%d|season|%d" % [int(data["seed"]), int(data["season"])])
	for pid: String in data["players"]:
		var p: Dictionary = data["players"][pid]
		p["age"] = int(p["age"]) + 1
		if int(p["age"]) >= 31:
			for k: String in ["pace", "stamina"]:
				p["attrs"][k] = maxi(20, int(p["attrs"][k]) - rng.randi_range(1, 2))
		p["apps"] = 0
	data["season"] = int(data["season"]) + 1
	data["round"] = 0
	data["season_over"] = false
	data["last_round_results"] = []
	var ids: Array = data["clubs"].keys()
	ids.sort()
	# Rotate the order so the calendar differs between seasons.
	for i in int(data["season"]) % ids.size():
		ids.append(ids.pop_front())
	data["fixtures"] = Schedule.make_fixtures(ids, int(data["season"]))
	for id: String in data["clubs"]:
		if id != data["user_club"]:
			auto_lineup(id)
	_refresh_transfer_list()
	return true


# -------------------------------------------------------------- development

## Match participation grows position-relevant attributes; young players faster.
func _develop(p: Dictionary, rng: RandomNumberGenerator) -> void:
	p["apps"] = int(p.get("apps", 0)) + 1
	var age := float(p["age"])
	var rate := clampf((30.0 - age) * 0.09, 0.0, 1.0) + 0.08
	var w := Attr.weights(p["pos"])
	var keys := w.keys()
	var growth: Dictionary = p.get("growth", {})
	for i in 2:
		var k: String = keys[rng.randi() % keys.size()]
		var cur := int(p["attrs"][k])
		var gain := rate * rng.randf_range(0.5, 1.5) * (1.0 - float(cur) / 105.0)
		growth[k] = float(growth.get(k, 0.0)) + gain
		if float(growth[k]) >= 1.0 and cur < 99:
			growth[k] = float(growth[k]) - 1.0
			p["attrs"][k] = cur + 1
	p["growth"] = growth


# ---------------------------------------------------------------- transfers

func _gk_count(club_id: String) -> int:
	var n := 0
	for p: Dictionary in squad_of(club_id):
		if p["pos"] == "GK":
			n += 1
	return n


func can_release(club_id: String, pid: String) -> bool:
	var c := club(club_id)
	if (c["squad"] as Array).size() <= MIN_SQUAD:
		return false
	if data["players"][pid]["pos"] == "GK" and _gk_count(club_id) <= 2:
		return false
	return true


func price(pid: String) -> int:
	return LeagueData.player_value(data["players"][pid])


func _refresh_transfer_list() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%d|tl|%d|%d" % [int(data["seed"]), int(data["season"]), int(data["round"])])
	var list := []
	for cid: String in data["clubs"]:
		if cid == data["user_club"]:
			continue
		var c := club(cid)
		var cands := []
		for pid: String in c["squad"]:
			if not (c["lineup"] as Array).has(pid) and can_release(cid, pid):
				cands.append(pid)
		cands.sort()
		for i in mini(3, cands.size()):
			var pick: String = cands[rng.randi() % cands.size()]
			if not list.has(pick):
				list.append(pick)
	# Occasionally a starter is available too.
	for cid: String in data["clubs"]:
		if cid != data["user_club"] and rng.randf() < 0.35:
			var lu: Array = club(cid)["lineup"]
			var pid2: String = lu[1 + rng.randi() % 10]
			if can_release(cid, pid2) and not list.has(pid2):
				list.append(pid2)
	data["transfer_list"] = list


## Returns "" on success or an error key.
func buy(pid: String) -> String:
	if not data["players"].has(pid) or not (data["transfer_list"] as Array).has(pid):
		return "TR_ERR_NOT_LISTED"
	var p := player(pid)
	var seller_id: String = p["club"]
	if seller_id == data["user_club"]:
		return "TR_ERR_OWN"
	var cost := price(pid)
	if cost <= 0:
		return "TR_ERR_AMOUNT"
	var u := user()
	if int(u["budget"]) < cost:
		return "TR_ERR_BUDGET"
	if (u["squad"] as Array).size() >= MAX_SQUAD:
		return "TR_ERR_SQUAD_FULL"
	if not can_release(seller_id, pid):
		return "TR_ERR_SELLER"
	_move_player(pid, seller_id, data["user_club"], cost)
	return ""


func sell(pid: String) -> String:
	var u := user()
	if not (u["squad"] as Array).has(pid):
		return "TR_ERR_OWN"
	if not can_release(data["user_club"], pid):
		return "TR_ERR_MIN_SQUAD"
	var cost := int(float(price(pid)) * SELL_FACTOR)
	if cost <= 0:
		return "TR_ERR_AMOUNT"
	# Buyer: the richest club that can afford him and has room.
	var buyer := ""
	var best := -1
	var ids: Array = data["clubs"].keys()
	ids.sort()
	for cid: String in ids:
		if cid == data["user_club"]:
			continue
		var c := club(cid)
		if int(c["budget"]) >= cost and (c["squad"] as Array).size() < MAX_SQUAD and int(c["budget"]) > best:
			best = int(c["budget"])
			buyer = cid
	if buyer == "":
		return "TR_ERR_NO_BUYER"
	_move_player(pid, data["user_club"], buyer, cost)
	return ""


func _move_player(pid: String, from_id: String, to_id: String, cost: int) -> void:
	var from := club(from_id)
	var to := club(to_id)
	(from["squad"] as Array).erase(pid)
	(to["squad"] as Array).append(pid)
	from["budget"] = int(from["budget"]) + cost
	to["budget"] = int(to["budget"]) - cost
	var p := player(pid)
	p["club"] = to_id
	# Unique shirt number in the new squad.
	var used := {}
	for other: String in to["squad"]:
		if other != pid:
			used[int(player(other)["number"])] = true
	var num := int(p["number"])
	while used.has(num):
		num = num % 99 + 1
	p["number"] = num
	(data["transfer_list"] as Array).erase(pid)
	if (from["lineup"] as Array).has(pid):
		auto_lineup(from_id)
	if to_id != data["user_club"]:
		auto_lineup(to_id)


# --------------------------------------------------------------- validation

## Structural validation used after loading and in tests. Returns error strings.
static func validate(d: Variant) -> Array:
	var errs := []
	if not (d is Dictionary):
		return ["not a dictionary"]
	var dd: Dictionary = d
	for k: String in ["schema", "season", "round", "user_club", "seed", "clubs", "players", "fixtures", "transfer_list", "season_over"]:
		if not dd.has(k):
			errs.append("missing key %s" % k)
	if not errs.is_empty():
		return errs
	if int(dd["schema"]) != SCHEMA:
		return ["unsupported schema %s" % str(dd["schema"])]
	if not (dd["clubs"] is Dictionary) or not (dd["players"] is Dictionary) or not (dd["fixtures"] is Array):
		return ["wrong container types"]
	if not (dd["clubs"] as Dictionary).has(dd["user_club"]):
		errs.append("user club missing")
	var owner := {}
	for cid: String in dd["clubs"]:
		var c: Dictionary = dd["clubs"][cid]
		if not c.has("squad") or not c.has("lineup") or not c.has("budget"):
			errs.append("club %s incomplete" % cid)
			continue
		if float(c["budget"]) < 0:
			errs.append("club %s negative budget" % cid)
		if (c["squad"] as Array).size() < 11:
			errs.append("club %s cannot field a team" % cid)
		for pid: String in c["squad"]:
			if owner.has(pid):
				errs.append("player %s in two squads" % pid)
			owner[pid] = cid
			if not (dd["players"] as Dictionary).has(pid):
				errs.append("squad references missing player %s" % pid)
			elif dd["players"][pid].get("club", "") != cid:
				errs.append("player %s club mismatch" % pid)
		for pid: String in c["lineup"]:
			if not (c["squad"] as Array).has(pid):
				errs.append("lineup of %s references %s outside squad" % [cid, pid])
	for pid: String in dd["players"]:
		var p: Dictionary = dd["players"][pid]
		if not owner.has(pid):
			errs.append("player %s has no squad" % pid)
		if not p.has("attrs") or not p.has("pos") or not p.has("name"):
			errs.append("player %s incomplete" % pid)
	var fids := {}
	for f: Dictionary in dd["fixtures"]:
		if fids.has(f.get("id", "")):
			errs.append("duplicate fixture %s" % str(f.get("id", "")))
		fids[f.get("id", "")] = true
		if not (dd["clubs"] as Dictionary).has(f.get("home", "")) or not (dd["clubs"] as Dictionary).has(f.get("away", "")):
			errs.append("fixture %s references unknown club" % str(f.get("id", "")))
	for pid: String in dd["transfer_list"]:
		if not (dd["players"] as Dictionary).has(pid):
			errs.append("transfer list references missing player %s" % pid)
	return errs


## JSON turns every number into float: restore integer fields after loading.
static func normalize(d: Dictionary) -> void:
	for k: String in ["schema", "season", "round", "seed"]:
		d[k] = int(d[k])
	for cid: String in d["clubs"]:
		d["clubs"][cid]["budget"] = int(d["clubs"][cid]["budget"])
	for pid: String in d["players"]:
		var p: Dictionary = d["players"][pid]
		p["age"] = int(p["age"])
		p["number"] = int(p["number"])
		p["apps"] = int(p.get("apps", 0))
		for k: String in p["attrs"]:
			p["attrs"][k] = int(p["attrs"][k])
	for f: Dictionary in d["fixtures"]:
		f["season"] = int(f["season"])
		f["round"] = int(f["round"])
		f["hg"] = int(f["hg"])
		f["ag"] = int(f["ag"])
	for h: Dictionary in d.get("history", []):
		h["season"] = int(h["season"])
		h["user_pos"] = int(h["user_pos"])
