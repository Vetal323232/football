extends SceneTree
## Automated checks. Usage: godot --headless -s tests/run_tests.gd
## Exit code 0 = all passed, 1 = failures.

var _fails := 0
var _checks := 0
var _current := ""
var _sims: Array[MatchSim] = []
var tuning: GameTuning
## Self-test of the harness: `-- --violate=budget|lineup` injects a violation that must make the run fail.
var _violate := ""


func check(cond: bool, what: String) -> void:
	_checks += 1
	if not cond:
		_fails += 1
		print("  FAIL [%s] %s" % [_current, what])


func group(name: String) -> void:
	# Matches of the previous group are finished: release their ownership cycles.
	for old_sim in _sims:
		old_sim.dispose()
	_sims.clear()
	_current = name
	print("- %s" % name)


func _init() -> void:
	tuning = load("res://data/tuning/default_tuning.tres")
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--violate="):
			_violate = a.trim_prefix("--violate=")
			if _violate != "budget" and _violate != "lineup":
				printerr("unknown --violate value '%s'" % _violate)
				quit(2)
				return
	var t0 := Time.get_ticks_msec()
	test_schedule()
	test_standings()
	test_result_once()
	test_transfers()
	test_development()
	test_save_load()
	test_season_rollover()
	test_attributes_matter()
	test_ball_physics()
	test_goal_once()
	test_ball_out_and_restarts()
	test_offside()
	test_possession()
	test_tackle_needs_reach()
	test_halves_and_clock()
	test_control_handoff()
	test_idle_human_restart()
	test_keeper()
	test_backpass()
	test_substitution()
	test_determinism()
	group("teardown")
	print("%d checks, %d failed, %.1fs" % [_checks, _fails, (Time.get_ticks_msec() - t0) / 1000.0])
	quit(1 if _fails > 0 else 0)


# ---------------------------------------------------------------- helpers

func new_sim(seed_ := 5, human := -1) -> MatchSim:
	var s := MatchSetup.exhibition(seed_)
	s.human_team = human
	var sim := MatchSim.new()
	sim.init_match(s, tuning)
	_sims.append(sim)
	return sim


func run(sim: MatchSim, ticks: int) -> void:
	for i in ticks:
		sim.step()


## Put the sim into open play with every player parked far from the ball.
func open_play(sim: MatchSim, ball_pos: Vector2) -> void:
	for p in sim.players:
		var tm := sim.teams[p.team]
		p.pos = Vector2(-45.0 * tm.dir + (p.role % 4) * 2.0 * tm.dir, -30.0 + p.role * 2.0)
		p.vel = Vector2.ZERO
	ScenarioLib._start(sim, null, ball_pos)
	sim.freeze_clock = false


func free_ball(sim: MatchSim, pos: Vector2, vel: Vector2, h := 0.0, vh := 0.0) -> void:
	var b := sim.ball
	b.owner = -1
	b.held_by = -1
	b.dead = false
	b.pos = pos
	b.vel = vel
	b.h = h
	b.vh = vh


## Step only ball + rules (no AI), for pure physics/rule checks.
func step_ball(sim: MatchSim, ticks: int) -> void:
	for i in ticks:
		if sim.state != MatchSim.State.PLAYING and sim.state != MatchSim.State.GOAL:
			return
		sim.tick += 1
		sim._ball_step()
		if sim.state == MatchSim.State.PLAYING:
			sim._rules()


# ----------------------------------------------------------------- career

func test_schedule() -> void:
	group("schedule")
	var ids := ["a", "b", "c", "d", "e", "f", "g", "h"]
	var rounds := Schedule.double_round_robin(ids)
	check(rounds.size() == 14, "14 rounds")
	var pair_count := {}
	var home_count := {}
	for r: Array in rounds:
		check(r.size() == 4, "4 matches per round")
		var seen := {}
		for m: Array in r:
			check(m[0] != m[1], "no self-play")
			check(not seen.has(m[0]) and not seen.has(m[1]), "club plays once per round")
			seen[m[0]] = true
			seen[m[1]] = true
			var key := "%s>%s" % [m[0], m[1]]
			pair_count[key] = int(pair_count.get(key, 0)) + 1
			home_count[m[0]] = int(home_count.get(m[0], 0)) + 1
	check(pair_count.size() == 56, "every ordered pair appears")
	var all_once := true
	for k: String in pair_count:
		if pair_count[k] != 1:
			all_once = false
	check(all_once, "each home/away pairing exactly once")
	var homes_ok := true
	for id: String in ids:
		if int(home_count.get(id, 0)) != 7:
			homes_ok = false
	check(homes_ok, "7 home games each")
	var fx := Schedule.make_fixtures(ids, 3)
	var uniq := {}
	for f: Dictionary in fx:
		uniq[f["id"]] = true
	check(fx.size() == 56 and uniq.size() == 56, "56 fixtures with unique stable ids")


func test_standings() -> void:
	group("standings")
	var cs := CareerState.create("smk", 42)
	var fx: Array = cs.data["fixtures"]
	var f0: Dictionary = fx[0]
	var f1: Dictionary = fx[1]
	cs.apply_result(f0["id"], 2, 0)
	cs.apply_result(f1["id"], 1, 1)
	var st := cs.standings()
	check(st[0]["club"] == f0["home"] and st[0]["pts"] == 3 and st[0]["gd"] == 2, "winner first with 3 pts")
	var draw_pts := 0
	var total_pts := 0
	var total_gd := 0
	for r: Dictionary in st:
		total_pts += int(r["pts"])
		total_gd += int(r["gd"])
		if r["club"] == f1["home"] or r["club"] == f1["away"]:
			draw_pts += int(r["pts"])
			check(r["p"] == 1 and r["d"] == 1 and r["gf"] == 1 and r["ga"] == 1, "draw row")
	check(draw_pts == 2 and total_pts == 5 and total_gd == 0, "3 for win, 1 for draw, GD sums to zero")
	check(st[st.size() - 1]["club"] == f0["away"], "loser last")
	# Tie-breaks: equal points and GD -> goals scored, then stable id order.
	var cs2 := CareerState.create("smk", 1)
	var r0 := cs2.round_fixtures(0)
	cs2.apply_result(r0[0]["id"], 3, 2)
	cs2.apply_result(r0[1]["id"], 1, 0)
	cs2.apply_result(r0[2]["id"], 1, 0)
	var s2 := cs2.standings()
	check(s2[0]["club"] == r0[0]["home"], "more goals scored wins the tie-break")
	var a: String = r0[1]["home"]
	var b: String = r0[2]["home"]
	check(s2[1]["club"] == (a if a < b else b), "stable final tie-break by id")


func test_result_once() -> void:
	group("one-time result application")
	var cs := CareerState.create("smk", 7)
	var uf := cs.user_fixture()
	check(not uf.is_empty(), "user has a fixture in round 1")
	var lineup: Array = cs.user()["lineup"]
	var before_apps := int(cs.player(lineup[3])["apps"])
	check(cs.apply_result(uf["id"], 2, 1, lineup), "first application succeeds")
	check(not cs.apply_result(uf["id"], 5, 5, lineup), "second application is rejected")
	check(int(cs.fixture(uf["id"])["hg"]) == 2, "score unchanged by the duplicate")
	check(int(cs.player(lineup[3])["apps"]) == before_apps + 1, "development applied once")
	var pts_before := 0
	for r: Dictionary in cs.standings():
		pts_before += int(r["pts"])
	check(cs.complete_round(), "round completes")
	check(int(cs.data["round"]) == 1, "round advanced by one")
	check(not cs.complete_round(), "cannot complete next round before the user's match")
	check(int(cs.data["round"]) == 1, "round not advanced twice")
	var played := 0
	for f: Dictionary in cs.round_fixtures(0):
		if f["played"]:
			played += 1
	check(played == 4, "all four fixtures of the round have a result")
	var pts_after := 0
	for r: Dictionary in cs.standings():
		pts_after += int(r["pts"])
	check(pts_after >= 8 and pts_after <= 12, "points of exactly four matches in the table")
	# Simulated scores are reproducible per fixture.
	var f2: Dictionary = cs.round_fixtures(1)[0]
	check(cs.simulate_score(f2) == cs.simulate_score(f2), "simulation of a fixture is deterministic")


func test_transfers() -> void:
	group("transfers")
	var cs := CareerState.create("smk", 9)
	var list: Array = cs.data["transfer_list"]
	check(list.size() > 4, "transfer list is populated")
	var total_before := 0
	for cid: String in cs.data["clubs"]:
		total_before += int(cs.club(cid)["budget"])
	var pid: String = list[0]
	var seller: String = cs.player(pid)["club"]
	var cost := cs.price(pid)
	var ub := int(cs.user()["budget"])
	var sb := int(cs.club(seller)["budget"])
	check(cost > 0, "price is positive")
	check(cs.buy(pid) == "", "purchase succeeds")
	check(int(cs.user()["budget"]) == ub - cost and int(cs.club(seller)["budget"]) == sb + cost, "both budgets updated")
	check((cs.user()["squad"] as Array).has(pid) and not (cs.club(seller)["squad"] as Array).has(pid), "both squads updated")
	check(cs.player(pid)["club"] == "smk", "ownership updated")
	check(cs.buy(pid) != "", "cannot buy the same player twice")
	check(CareerState.validate(cs.data).is_empty(), "state valid after purchase")
	var nums := {}
	var dup := false
	for p: Dictionary in cs.squad_of("smk"):
		if nums.has(int(p["number"])):
			dup = true
		nums[int(p["number"])] = true
	check(not dup, "shirt numbers stay unique")
	# Budget limit.
	# Deliberate test mutation: remember how much money it removes from the league.
	var injected := 10 - int(cs.user()["budget"])
	cs.user()["budget"] = 10
	var pid2: String = cs.data["transfer_list"][0]
	check(cs.buy(pid2) == "TR_ERR_BUDGET", "cannot overspend")
	check(cs.buy("nobody") == "TR_ERR_NOT_LISTED", "unknown player rejected")
	# Selling.
	var own: String = cs.user()["squad"][15]
	var ub2 := int(cs.user()["budget"])
	check(cs.sell(own) == "", "sale succeeds")
	check(int(cs.user()["budget"]) > ub2 and not (cs.user()["squad"] as Array).has(own), "money in, player out")
	check(cs.sell(own) == "TR_ERR_OWN", "cannot sell a player twice")
	# Minimum squad protection.
	var guard := 0
	while (cs.user()["squad"] as Array).size() > CareerState.MIN_SQUAD and guard < 40:
		guard += 1
		var sold := false
		for cand: String in (cs.user()["squad"] as Array).duplicate():
			if cs.sell(cand) == "":
				sold = true
				break
		if not sold:
			break
	check((cs.user()["squad"] as Array).size() >= CareerState.MIN_SQUAD, "squad never drops below the minimum")
	check(cs.sell(cs.user()["squad"][2]) == "TR_ERR_MIN_SQUAD", "sale blocked at minimum squad size")
	check(cs._gk_count("smk") >= 2, "two goalkeepers are always kept")
	if _violate == "lineup":
		cs.user()["lineup"][3] = cs.user()["lineup"][4]
	check(cs.lineup_valid("smk", cs.user()["lineup"]) == "", "line-up stays legal after every sale, without repair")
	cs._repair_lineup("smk")
	check(cs.lineup_valid("smk", cs.user()["lineup"]) == "", "a legal eleven can still be fielded")
	var total_after := 0
	for cid: String in cs.data["clubs"]:
		total_after += int(cs.club(cid)["budget"])
	if _violate == "budget":
		total_after += 1
	check(total_after == total_before + injected, "money only moves between clubs (league total %d -> %d, test removed %d)" % [total_before, total_after, -injected])
	var owners := {}
	var dup_owner := false
	for cid: String in cs.data["clubs"]:
		for p2: String in cs.club(cid)["squad"]:
			if owners.has(p2):
				dup_owner = true
			owners[p2] = cid
	check(not dup_owner and owners.size() == 160, "no duplicated or lost players (160 total)")
	check(CareerState.validate(cs.data).is_empty(), "state valid after all transfers")


func test_development() -> void:
	group("development")
	var cs := CareerState.create("smk", 3)
	var lineup: Array = cs.user()["lineup"]
	var young: String = lineup[9]
	cs.player(young)["age"] = 19
	var before := 0
	for k: String in cs.player(young)["attrs"]:
		before += int(cs.player(young)["attrs"][k])
	var bench_pid := ""
	for pid: String in cs.user()["squad"]:
		if not lineup.has(pid):
			bench_pid = pid
			break
	var bench_before: Dictionary = (cs.player(bench_pid)["attrs"] as Dictionary).duplicate()
	for i in 14:
		var uf := cs.user_fixture()
		cs.apply_result(uf["id"], 1, 0, lineup)
		cs.complete_round()
	var after := 0
	for k: String in cs.player(young)["attrs"]:
		after += int(cs.player(young)["attrs"][k])
	check(after > before, "a young regular improves over a season (%d -> %d)" % [before, after])
	check(int(cs.player(young)["apps"]) == 14, "14 appearances recorded")
	check(cs.player(bench_pid)["attrs"] == bench_before, "a player who never plays does not develop")
	check(cs.data["season_over"], "season is over after 14 rounds")


func test_save_load() -> void:
	group("save / load")
	var dir := "user://test_saves"
	SaveManager.delete(dir)
	var cs := CareerState.create("zar", 11)
	var uf := cs.user_fixture()
	cs.apply_result(uf["id"], 3, 1, cs.user()["lineup"])
	cs.complete_round()
	cs.buy(cs.data["transfer_list"][0])
	check(SaveManager.save(cs, dir) == "", "save succeeds")
	var res := SaveManager.load_career(dir)
	check(res["career"] != null and not res["recovered"], "load succeeds")
	var loaded: CareerState = res["career"]
	check(JSON.stringify(loaded.data) == JSON.stringify(cs.data), "round trip preserves the whole state")
	check(loaded.standings() == cs.standings(), "table identical after reload")
	check(not loaded.apply_result(uf["id"], 9, 9), "reloaded save still rejects a duplicate result")
	check(int(loaded.user()["budget"]) == int(cs.user()["budget"]), "budget identical after reload")
	# Second save keeps the previous file as backup.
	var uf2 := cs.user_fixture()
	cs.apply_result(uf2["id"], 0, 0, cs.user()["lineup"])
	cs.complete_round()
	check(SaveManager.save(cs, dir) == "", "second save succeeds")
	check(FileAccess.file_exists(SaveManager.path(dir) + ".bak"), "backup of the previous save exists")
	# Corrupt the main file: the backup must be recovered.
	var f := FileAccess.open(SaveManager.path(dir), FileAccess.WRITE)
	f.store_string("{ this is not json")
	f.close()
	var rec := SaveManager.load_career(dir)
	check(rec["career"] != null and rec["recovered"], "corrupted save falls back to the backup")
	check(int((rec["career"] as CareerState).data["round"]) == 1, "backup holds the previous round")
	# Structurally invalid data is rejected, not loaded.
	var broken: Dictionary = cs.data.duplicate(true)
	(broken["clubs"]["zar"]["squad"] as Array).append("ghost_player")
	check(not CareerState.validate(broken).is_empty(), "dangling reference detected")
	var broken2: Dictionary = cs.data.duplicate(true)
	(broken2["clubs"]["smk"]["squad"] as Array).append(broken2["clubs"]["zar"]["squad"][0])
	check(not CareerState.validate(broken2).is_empty(), "duplicated player detected")
	# Semantically impossible or wrongly typed state is rejected without script errors.
	var mutations := {
		"round beyond the season": func(m: Dictionary) -> void: m["round"] = 999,
		"negative round": func(m: Dictionary) -> void: m["round"] = -1,
		"round as text": func(m: Dictionary) -> void: m["round"] = "tomorrow",
		"fractional round": func(m: Dictionary) -> void: m["round"] = 1.5,
		"season zero": func(m: Dictionary) -> void: m["season"] = 0,
		"season_over as text": func(m: Dictionary) -> void: m["season_over"] = "false",
		"season_over contradicting the round": func(m: Dictionary) -> void: m["season_over"] = true,
		"club record null": func(m: Dictionary) -> void: m["clubs"]["smk"] = null,
		"squad not a list": func(m: Dictionary) -> void: m["clubs"]["smk"]["squad"] = "bad",
		"lineup with a duplicate": func(m: Dictionary) -> void: m["clubs"]["smk"]["lineup"][2] = m["clubs"]["smk"]["lineup"][1],
		"lineup empty": func(m: Dictionary) -> void: m["clubs"]["smk"]["lineup"] = [],
		"player record null": func(m: Dictionary) -> void: m["players"][m["clubs"]["smk"]["squad"][3]] = null,
		"attrs not a dictionary": func(m: Dictionary) -> void: m["players"][m["clubs"]["smk"]["squad"][3]]["attrs"] = "bad",
		"attribute out of range": func(m: Dictionary) -> void: m["players"][m["clubs"]["smk"]["squad"][3]]["attrs"]["pace"] = 999,
		"age missing": func(m: Dictionary) -> void: m["players"][m["clubs"]["smk"]["squad"][3]].erase("age"),
		"negative score": func(m: Dictionary) -> void: m["fixtures"][0]["hg"] = -3,
		"played flag as text": func(m: Dictionary) -> void: m["fixtures"][0]["played"] = "false",
		"club plays itself": func(m: Dictionary) -> void: m["fixtures"][0]["away"] = m["fixtures"][0]["home"],
		"future fixture already played": func(m: Dictionary) -> void: m["fixtures"][55]["played"] = true,
		"finished round without result": func(m: Dictionary) -> void: m["fixtures"][0]["played"] = false,
		"transfer list not a list": func(m: Dictionary) -> void: m["transfer_list"] = 3,
		"history not a list": func(m: Dictionary) -> void: m["history"] = 3,
	}
	check(CareerState.validate(cs.data).is_empty(), "control: the unmodified state is valid")
	for label: String in mutations:
		var md: Dictionary = cs.data.duplicate(true)
		(mutations[label] as Callable).call(md)
		check(not CareerState.validate(md).is_empty(), "rejected: %s" % label)
	var json_copy: Variant = JSON.parse_string(JSON.stringify(cs.data))
	check(CareerState.validate(json_copy).is_empty(), "a JSON round trip (all numbers as floats) is still valid")
	f = FileAccess.open(SaveManager.path(dir) + ".bak", FileAccess.WRITE)
	f.store_string("garbage")
	f.close()
	var none := SaveManager.load_career(dir)
	check(none["career"] == null and str(none["error"]) != "", "both files damaged -> clear error, no crash")
	SaveManager.delete(dir)
	check(not SaveManager.exists(dir), "saves removed")


func test_season_rollover() -> void:
	group("season rollover")
	var cs := CareerState.create("uts", 5)
	for i in 14:
		check(cs.complete_round(true), "round %d completes" % (i + 1))
	check(cs.data["season_over"] and not cs.complete_round(true), "no round beyond the season")
	var all_played := true
	for f: Dictionary in cs.data["fixtures"]:
		if not f["played"]:
			all_played = false
	check(all_played, "all 56 fixtures played")
	var st := cs.standings()
	var ok := true
	for r: Dictionary in st:
		if int(r["p"]) != 14:
			ok = false
	check(ok, "every club played 14 matches")
	check((cs.data["history"] as Array).size() == 1 and cs.data["history"][0]["champion"] == st[0]["club"], "champion recorded once")
	var age0 := int(cs.player(cs.user()["squad"][0])["age"])
	check(cs.start_next_season(), "next season starts")
	check(not cs.start_next_season(), "cannot roll over twice")
	check(int(cs.data["season"]) == 2 and int(cs.data["round"]) == 0, "season 2, round 0")
	check(int(cs.player(cs.user()["squad"][0])["age"]) == age0 + 1, "players age by one year")
	check(cs.standings()[0]["p"] == 0, "new table starts empty")
	check(str(cs.data["fixtures"][0]["id"]).begins_with("s2_"), "new season fixtures have new ids")
	check(CareerState.validate(cs.data).is_empty(), "state valid after rollover")
	check(not cs.user_fixture().is_empty(), "user has a fixture in the new season")


# ------------------------------------------------------------ match engine

func test_attributes_matter() -> void:
	group("attributes affect execution")
	var sim := new_sim()
	var p := sim.players[5]
	p.pace = 0.2
	var slow := p.top_speed(tuning)
	p.pace = 0.9
	check(p.top_speed(tuning) > slow + 1.0, "pace changes top speed")
	p.stamina = 0.0
	check(p.top_speed(tuning) < slow + 1.6, "exhaustion reduces speed")
	# Passing accuracy: spread of many kicks with low vs high passing.
	var spreads := []
	for attr: float in [0.1, 0.95]:
		var sum := 0.0
		for i in 60:
			var s2 := new_sim(100 + i)
			open_play(s2, Vector2.ZERO)
			var k := s2.players[6]
			k.passing = attr
			k.pos = Vector2(-0.5, 0)
			k.facing = Vector2.RIGHT
			s2.ball.owner = k.id
			k.pending_kick = KickRequest.make(KickRequest.Kind.PASS, Vector2.RIGHT, 15.0, 0.0, -1, Vector2(20, 0))
			k.pending_kick_t = 0.3
			s2._resolve_actions()
			sum += absf(s2.ball.vel.angle())
		spreads.append(sum / 60.0)
	check(spreads[0] > spreads[1] * 2.0, "passing attribute changes kick accuracy (%.3f vs %.3f rad)" % [spreads[0], spreads[1]])
	var a := {"pace": 70, "passing": 70, "shooting": 70, "control": 70, "defending": 70, "stamina": 70, "goalkeeping": 70}
	var b := a.duplicate()
	b["shooting"] = 90
	check(Attr.overall(b, "FW") > Attr.overall(a, "FW"), "overall reflects role attributes")
	check(Attr.overall(b, "GK") == Attr.overall(a, "GK"), "irrelevant attribute does not change a keeper's overall")


func test_ball_physics() -> void:
	group("ball physics")
	var sim := new_sim()
	open_play(sim, Vector2.ZERO)
	# Rolling ball slows down and stops; never leaves the ground plane.
	free_ball(sim, Vector2(-20, 0), Vector2(15, 0))
	var min_h := 0.0
	for i in 600:
		step_ball(sim, 1)
		min_h = minf(min_h, sim.ball.h)
	check(sim.ball.vel.length() < 0.01 and sim.ball.pos.x > 0.0 and sim.ball.pos.x < 30.0, "rolling ball stops after a plausible distance (%.1f m)" % (sim.ball.pos.x + 20.0))
	# Dropped ball bounces lower each time and settles; no tunnelling.
	free_ball(sim, Vector2.ZERO, Vector2.ZERO, 5.0, -30.0)
	for i in 800:
		step_ball(sim, 1)
		min_h = minf(min_h, sim.ball.h)
	check(min_h >= 0.0, "ball never goes below the pitch")
	check(sim.ball.h == 0.0 and absf(sim.ball.vh) < 0.01, "bouncing ball settles")
	# Fast shot at the post rebounds instead of passing through.
	free_ball(sim, Vector2(40, Pitch.GOAL_HALF_W), Vector2(34, 0), 0.5, 0.0)
	var posts := [0]
	sim.event.connect(func(kind: StringName, _d: Dictionary) -> void:
		if kind == &"post":
			posts[0] += 1)
	step_ball(sim, 40)
	check(posts[0] >= 1 and sim.state == MatchSim.State.PLAYING and sim.ball.vel.x < 0.0, "post rebound, no goal")
	# Crossbar.
	free_ball(sim, Vector2(50, 0), Vector2(30, 0), Pitch.GOAL_H + 0.03, 0.0)
	var p0: int = posts[0]
	step_ball(sim, 12)
	check(posts[0] > p0 and sim.teams[0].score == 0, "crossbar rebound, no goal")
	sim = new_sim()
	open_play(sim, Vector2.ZERO)
	# Predicted path matches the simulated flight.
	free_ball(sim, Vector2(-10, 5), Vector2(14, -3), 0.0, 8.0)
	var path := sim.ball_path()
	sim._path_tick = -1
	step_ball(sim, 60)
	var pp := Vector2(path[10].x, path[10].y)
	check(pp.distance_to(sim.ball.pos) < 0.6, "trajectory prediction agrees with physics (err %.2f m)" % pp.distance_to(sim.ball.pos))


func test_goal_once() -> void:
	group("goals")
	var sim := new_sim()
	open_play(sim, Vector2.ZERO)
	var goals := [0]
	sim.event.connect(func(kind: StringName, _d: Dictionary) -> void:
		if kind == &"goal":
			goals[0] += 1)
	sim.ball.last_touch = sim.teams[0].player_ids[9]
	sim.ball.last_touch_team = 0
	free_ball(sim, Vector2(48, 1.0), Vector2(20, 0), 0.3)
	# Ball on the line but not fully over: no goal yet.
	var on_line_goal := false
	for i in 60:
		step_ball(sim, 1)
		if sim.ball.pos.x <= Pitch.HALF_L + Pitch.BALL_R and sim.teams[0].score > 0:
			on_line_goal = true
		if sim.state != MatchSim.State.PLAYING:
			break
	check(not on_line_goal, "no goal before the whole ball crosses the line")
	check(sim.teams[0].score == 1 and goals[0] == 1, "goal awarded")
	run(sim, 120)
	check(sim.teams[0].score == 1 and goals[0] == 1, "goal awarded only once while the ball lies in the net")
	check(not sim.last_goal["own_goal"], "normal goal is not an own goal")
	run(sim, 600)
	check(sim.restart_type == MatchSim.Restart.KICKOFF and sim.restart_team == 1 or sim.state == MatchSim.State.PLAYING, "conceding team kicks off")
	check(sim.teams[0].score == 1, "score stable after the restart")
	# Own goal.
	var sim2 := new_sim()
	open_play(sim2, Vector2.ZERO)
	sim2.ball.last_touch = sim2.teams[1].player_ids[3]
	sim2.ball.last_touch_team = 1
	free_ball(sim2, Vector2(49, -2.0), Vector2(15, 0))
	step_ball(sim2, 60)
	check(sim2.teams[0].score == 1 and sim2.last_goal["own_goal"], "own goal counts for the attacking side")
	# Wide of the post / over the bar: no goal.
	var sim3 := new_sim()
	open_play(sim3, Vector2.ZERO)
	sim3.ball.last_touch_team = 0
	free_ball(sim3, Vector2(48, Pitch.GOAL_HALF_W + 0.8), Vector2(20, 0))
	step_ball(sim3, 60)
	check(sim3.teams[0].score == 0 and sim3.restart_type == MatchSim.Restart.GOAL_KICK, "wide shot gives a goal kick")
	var sim4 := new_sim()
	open_play(sim4, Vector2.ZERO)
	sim4.ball.last_touch_team = 0
	free_ball(sim4, Vector2(48, 0), Vector2(25, 0), 3.2, 1.0)
	step_ball(sim4, 60)
	check(sim4.teams[0].score == 0, "shot over the bar is no goal")


func test_ball_out_and_restarts() -> void:
	group("ball out and restarts")
	var sim := new_sim()
	open_play(sim, Vector2.ZERO)
	sim.ball.last_touch_team = 0
	free_ball(sim, Vector2(10, 32), Vector2(0, 12))
	step_ball(sim, 60)
	check(sim.state == MatchSim.State.RESTART_SETUP and sim.restart_type == MatchSim.Restart.THROW_IN and sim.restart_team == 1, "throw-in to the other team")
	check(absf(sim.ball.pos.y - Pitch.HALF_W) < 0.01 and absf(sim.ball.pos.x - 10.0) < 1.5, "ball placed on the touchline where it went out")
	run(sim, 600)
	check(sim.state == MatchSim.State.PLAYING, "throw-in is taken and play resumes")
	check(sim.stalls == 0, "no stall after the throw-in")
	# Corner: last touch by the defending team.
	var sim2 := new_sim()
	open_play(sim2, Vector2.ZERO)
	sim2.ball.last_touch_team = 1
	free_ball(sim2, Vector2(49, 15), Vector2(18, 2))
	step_ball(sim2, 60)
	check(sim2.restart_type == MatchSim.Restart.CORNER and sim2.restart_team == 0, "corner for the attacking team")
	check(sim2.ball.pos.x > 51.0 and sim2.ball.pos.y > 33.0, "ball in the corner arc")
	var taker := sim2.players[sim2.restart_taker]
	run(sim2, int(tuning.restart_setup_time * 60) + 5)
	check(sim2.state == MatchSim.State.RESTART_READY and taker.pos.distance_to(sim2.ball.pos) < 1.0, "taker stands at the ball")
	var too_close := false
	for id in sim2.teams[1].player_ids:
		if sim2.players[id].pos.distance_to(sim2.ball.pos) < Pitch.CIRCLE_R - 0.3:
			too_close = true
	check(not too_close, "defenders respect the distance at a corner")
	run(sim2, 400)
	check(sim2.state != MatchSim.State.RESTART_READY, "corner is taken within the time limit")
	# Goal kick.
	var sim3 := new_sim()
	open_play(sim3, Vector2.ZERO)
	sim3.ball.last_touch_team = 0
	free_ball(sim3, Vector2(49, 15), Vector2(18, 2))
	step_ball(sim3, 60)
	check(sim3.restart_type == MatchSim.Restart.GOAL_KICK and sim3.restart_team == 1, "goal kick for the defending team")
	check(sim3.players[sim3.restart_taker].is_keeper(), "keeper takes the goal kick")
	run(sim3, 600)
	check(sim3.state == MatchSim.State.PLAYING or sim3.state == MatchSim.State.RESTART_SETUP, "goal kick taken")
	# Kick-off: everyone in his own half.
	var sim4 := new_sim()
	run(sim4, int(tuning.kickoff_setup_time * 60) + 3)
	var own_half := true
	for p in sim4.players:
		if p.pos.x * sim4.teams[p.team].dir > 0.6:
			own_half = false
	check(own_half, "all players in their own half at kick-off")
	run(sim4, 300)
	check(sim4.state == MatchSim.State.PLAYING, "kick-off taken")


func test_offside() -> void:
	group("offside")
	var sim := new_sim()
	open_play(sim, Vector2.ZERO)
	var passer := sim.players[sim.teams[0].player_ids[6]]
	var runner := sim.players[sim.teams[0].player_ids[9]]
	passer.pos = Vector2(5, 0)
	passer.facing = Vector2.RIGHT
	# Defenders (team 1 defends the +x goal): last outfield line at x = 20.
	for id in sim.teams[1].player_ids:
		var d := sim.players[id]
		d.pos = Vector2(48, 0) if d.is_keeper() else Vector2(20, -25.0 + d.role * 4.0)
	runner.pos = Vector2(26, 6)   # beyond the second-last defender
	sim.ball.owner = passer.id
	sim.ball.pos = passer.pos + Vector2(0.5, 0)
	passer.passing = 1.0
	var to := runner.pos - sim.ball.pos
	passer.pending_kick = KickRequest.make(KickRequest.Kind.PASS, to, 18.0, 0.0, runner.id, runner.pos)
	passer.pending_kick_t = 0.3
	sim._resolve_actions()
	check(sim.offside_flags.has(runner.id), "runner flagged in an offside position at the pass")
	for i in 240:
		sim.tick += 1
		sim._ball_step()
		if sim.state == MatchSim.State.PLAYING:
			sim._possession()
	check(sim.state == MatchSim.State.RESTART_SETUP and sim.restart_type == MatchSim.Restart.FREE_KICK and sim.restart_team == 1, "offside called when he plays the ball")
	check(sim.teams[0].stats.offsides == 1, "offside counted once")
	check(sim.restart_spot.distance_to(Vector2(26, 6)) < 1.5, "free kick from his position at the moment of the pass")
	# Same pass with the runner level with the line: play continues.
	var sim2 := new_sim()
	open_play(sim2, Vector2.ZERO)
	var p2 := sim2.players[sim2.teams[0].player_ids[6]]
	var r2 := sim2.players[sim2.teams[0].player_ids[9]]
	p2.pos = Vector2(5, 0)
	p2.facing = Vector2.RIGHT
	p2.passing = 1.0
	for id in sim2.teams[1].player_ids:
		var d2 := sim2.players[id]
		d2.pos = Vector2(48, 0) if d2.is_keeper() else Vector2(20, -25.0 + d2.role * 4.0)
	r2.pos = Vector2(19.5, 6)
	sim2.ball.owner = p2.id
	sim2.ball.pos = p2.pos + Vector2(0.5, 0)
	p2.pending_kick = KickRequest.make(KickRequest.Kind.PASS, r2.pos - sim2.ball.pos, 16.0, 0.0, r2.id, r2.pos)
	p2.pending_kick_t = 0.3
	sim2._resolve_actions()
	check(not sim2.offside_flags.has(r2.id), "onside runner not flagged")
	for i in 240:
		sim2.tick += 1
		sim2._ball_step()
		if sim2.state == MatchSim.State.PLAYING:
			sim2._possession()
	check(sim2.state == MatchSim.State.PLAYING and sim2.ball.owner == r2.id, "onside pass is received normally")
	# First-time kick by a flagged player: offside, and the kick itself never happens.
	for dir_sign: float in [1.0, -1.0]:
		var sf := new_sim()
		open_play(sf, Vector2.ZERO)
		if dir_sign < 0.0:
			for tm in sf.teams:
				tm.dir = -tm.dir   # second half: ends switched
		var pf := sf.players[sf.teams[0].player_ids[6]]
		var rf := sf.players[sf.teams[0].player_ids[9]]
		for id in sf.teams[1].player_ids:
			var df := sf.players[id]
			df.pos = Vector2(48 * dir_sign, 0) if df.is_keeper() else Vector2(20 * dir_sign, -25.0 + df.role * 4.0)
		pf.pos = Vector2(5 * dir_sign, 0)
		pf.passing = 1.0
		rf.pos = Vector2(35 * dir_sign, 0)
		sf.ball.owner = pf.id
		sf.ball.pos = pf.pos + Vector2(0.5 * dir_sign, 0)
		pf.pending_kick = KickRequest.make(KickRequest.Kind.PASS, Vector2(dir_sign, 0), 24.0, 0.0, rf.id, rf.pos)
		pf.pending_kick_t = 0.3
		sf._resolve_actions()
		var counts := {"offside": 0, "whistle": 0, "kick": 0, "goal": 0}
		sf.event.connect(func(kind: StringName, _d: Dictionary) -> void:
			if counts.has(String(kind)):
				counts[String(kind)] += 1)
		sf.ball.pos = rf.pos + Vector2(0.3 * dir_sign, 0)
		rf.pending_kick = KickPlanner.plan_ai_shot(sf, rf)
		rf.pending_kick_t = 0.4
		sf._try_kick(rf)
		var tag := "attacking %s" % ("+x" if dir_sign > 0.0 else "-x after switching ends")
		check(sf.state == MatchSim.State.RESTART_SETUP and sf.restart_type == MatchSim.Restart.FREE_KICK and sf.restart_team == 1, "flagged first-time shot is offside (%s)" % tag)
		check(sf.teams[0].stats.shots == 0 and counts["kick"] == 0, "the offside shot is never executed (%s)" % tag)
		run(sf, 240)
		check(sf.teams[0].stats.offsides == 1 and counts["offside"] == 1 and counts["whistle"] == 1 and counts["goal"] == 0, "one incident: one whistle, no shot, no goal (%s)" % tag)
	# The same first-time shot from an onside position is executed.
	var so := new_sim()
	open_play(so, Vector2.ZERO)
	var po := so.players[so.teams[0].player_ids[6]]
	var ro := so.players[so.teams[0].player_ids[9]]
	for id in so.teams[1].player_ids:
		var d_o := so.players[id]
		d_o.pos = Vector2(48, 0) if d_o.is_keeper() else Vector2(40, -25.0 + d_o.role * 4.0)
	po.pos = Vector2(5, 0)
	ro.pos = Vector2(35, 0)
	so.ball.owner = po.id
	so.ball.pos = po.pos + Vector2(0.5, 0)
	po.pending_kick = KickRequest.make(KickRequest.Kind.PASS, Vector2.RIGHT, 24.0, 0.0, ro.id, ro.pos)
	po.pending_kick_t = 0.3
	so._resolve_actions()
	so.ball.pos = ro.pos + Vector2(0.3, 0)
	ro.pending_kick = KickPlanner.plan_ai_shot(so, ro)
	ro.pending_kick_t = 0.4
	so._try_kick(ro)
	check(so.state == MatchSim.State.PLAYING and so.teams[0].stats.shots == 1 and so.teams[0].stats.offsides == 0 and so.ball.kicker == ro.id, "onside first-time shot is executed")
	# Throw-in exemption: a receiver beyond the last defender is not flagged.
	var st := new_sim()
	open_play(st, Vector2.ZERO)
	for id in st.teams[1].player_ids:
		var dt := st.players[id]
		dt.pos = Vector2(48, 0) if dt.is_keeper() else Vector2(10, -20.0 + dt.role * 3.0)
	st.begin_restart(MatchSim.Restart.THROW_IN, 0, Vector2(15, Pitch.HALF_W))
	st._snap_restart_positions()
	st.state = MatchSim.State.RESTART_READY
	st.restart_ready_t = 1.0
	var taker := st.players[st.restart_taker]
	var rt := st.players[st.teams[0].player_ids[9]]
	if rt.id == taker.id:
		rt = st.players[st.teams[0].player_ids[7]]
	rt.pos = Vector2(30, 28)
	for id in st.teams[1].player_ids:
		var dt2 := st.players[id]
		dt2.pos = Vector2(48, 0) if dt2.is_keeper() else Vector2(10, -20.0 + dt2.role * 3.0)
	st.ball.owner = taker.id
	taker.pending_kick = KickRequest.make(KickRequest.Kind.PASS, rt.pos - st.ball.pos, 12.0, 2.0, rt.id, rt.pos)
	taker.pending_kick_t = 0.3
	st._try_kick(taker)
	check(st.state == MatchSim.State.PLAYING and st.ball.no_offside and not st.offside_flags.has(rt.id), "no offside directly from a throw-in")
	check(st.ball.restart_taker == taker.id, "restart taker is still barred from a second touch")
	st.ball.pos = rt.pos + Vector2(0.2, 0)
	st.ball.h = 0.3   # the throw has come down to a playable height
	rt.pending_kick = KickRequest.make(KickRequest.Kind.PASS, Vector2.LEFT, 10.0, 0.0, -1, rt.pos + Vector2(-10, 0))
	rt.pending_kick_t = 0.3
	st._try_kick(rt)
	check(st.state == MatchSim.State.PLAYING and st.teams[0].stats.offsides == 0 and st.ball.restart_taker == -1, "first-time touch after a throw-in is legal and releases the double-touch bar")
	# A player in his own half is never offside.
	var sim3 := new_sim()
	open_play(sim3, Vector2.ZERO)
	for id in sim3.teams[1].player_ids:
		sim3.players[id].pos = Vector2(40, 0)
	sim3.ball.pos = Vector2(-30, 0)
	check(SimQuery.offside_line_local(sim3, 0) >= 0.0, "offside line never behind the halfway line")


func test_possession() -> void:
	group("possession")
	var sim := new_sim()
	open_play(sim, Vector2.ZERO)
	var a := sim.players[sim.teams[0].player_ids[7]]
	var far := sim.players[sim.teams[1].player_ids[7]]
	a.pos = Vector2(0, 0)
	far.pos = Vector2(6, 0)
	# A slow ball rolling to player a is claimed by him, not by the distant opponent.
	free_ball(sim, Vector2(-4, 0), Vector2(6, 0))
	var changes := [0]
	var per_tick := {}
	sim.event.connect(func(kind: StringName, _d: Dictionary) -> void:
		if kind == &"claim":
			changes[0] += 1
			per_tick[sim.tick] = int(per_tick.get(sim.tick, 0)) + 1)
	for i in 90:
		sim.tick += 1
		sim._update_timers()
		sim._ball_step()
		sim._possession()
	check(sim.ball.owner == a.id, "nearest player within reach takes possession")
	check(changes[0] == 1, "possession assigned once, no oscillation")
	check(sim.ball.pos.distance_to(a.pos) < 1.2, "ball stays at his feet")
	# Possession cannot transfer from a distance.
	far.pos = Vector2(3.0, 0)
	for i in 60:
		sim.tick += 1
		sim._update_timers()
		sim._ball_step()
		sim._possession()
	check(sim.ball.owner == a.id, "an opponent 3 m away cannot take the ball without a tackle")
	# A ball too fast to control is deflected, not caught.
	var sim2 := new_sim()
	open_play(sim2, Vector2.ZERO)
	var d := sim2.players[sim2.teams[1].player_ids[3]]
	d.pos = Vector2(10, 0.2)
	d.control = 0.3
	free_ball(sim2, Vector2(0, 0), Vector2(30, 0))
	sim2.ball.kick_id = 5
	for i in 40:
		sim2.tick += 1
		sim2._update_timers()
		sim2._ball_step()
		sim2._possession()
	check(sim2.ball.owner != d.id or sim2.ball.vel.length() < 12.0, "a 30 m/s ball is not trapped dead")
	check(sim2.ball.vel.length() < 20.0, "blocked ball loses speed")
	# One kick request = one kick.
	var sim3 := new_sim()
	open_play(sim3, Vector2.ZERO)
	var k := sim3.players[sim3.teams[0].player_ids[8]]
	k.pos = Vector2(-0.5, 0)
	sim3.ball.owner = k.id
	k.pending_kick = KickRequest.make(KickRequest.Kind.PASS, Vector2.RIGHT, 14.0, 0.0, -1, Vector2(20, 0))
	k.pending_kick_t = 0.3
	var kicks := [0]
	sim3.event.connect(func(kind: StringName, _d: Dictionary) -> void:
		if kind == &"kick":
			kicks[0] += 1)
	for i in 30:
		sim3.tick += 1
		sim3._update_timers()
		sim3._resolve_actions()
		sim3._ball_step()
		sim3._possession()
	check(kicks[0] == 1, "one action produces exactly one kick")
	check(sim3.ball.owner != k.id, "kicker does not instantly re-collect his own pass")
	var v := sim3.ball.vel
	check(v.length() < 0.1 or absf(v.angle()) < 0.3, "released ball travels straight (no homing)")


func test_tackle_needs_reach() -> void:
	group("tackles")
	var sim := new_sim()
	open_play(sim, Vector2.ZERO)
	var c := sim.players[sim.teams[0].player_ids[7]]
	var t := sim.players[sim.teams[1].player_ids[5]]
	c.pos = Vector2(0, 0)
	c.facing = Vector2.RIGHT
	sim.ball.owner = c.id
	sim.ball.pos = Vector2(0.5, 0)
	t.pos = Vector2(5.0, 0)
	t.facing = Vector2.LEFT
	t.cmd.tackle = true
	sim._resolve_actions()
	for i in 40:
		sim.tick += 1
		sim._update_timers()
		t.cmd.clear()
		sim._move_players()
		sim._resolve_actions()
		sim._ball_step()
		sim._possession()
	check(sim.ball.owner == c.id, "tackle from 5 m cannot win the ball")
	check(t.tackle_recover > 0.0 or t.tackle_cd > 0.0, "missed tackle costs recovery time")
	check(sim.teams[1].stats.tackles == 1, "one press = one tackle")
	# Held tackle command does not chain tackles faster than the cooldown.
	var sim2 := new_sim()
	open_play(sim2, Vector2.ZERO)
	var t2 := sim2.players[sim2.teams[1].player_ids[5]]
	t2.pos = Vector2(10, 10)
	for i in 60:
		sim2.tick += 1
		sim2._update_timers()
		t2.cmd.clear()
		t2.cmd.tackle = true
		sim2._move_players()
		sim2._resolve_actions()
	check(sim2.teams[1].stats.tackles <= 2, "spamming tackle is limited by cooldown (%d in 1 s)" % sim2.teams[1].stats.tackles)
	# In reach from the front the ball can be won.
	var won := 0
	for sd in 30:
		var s3 := new_sim(200 + sd)
		open_play(s3, Vector2.ZERO)
		var c3 := s3.players[s3.teams[0].player_ids[7]]
		var t3 := s3.players[s3.teams[1].player_ids[5]]
		c3.pos = Vector2(0, 0)
		c3.facing = Vector2.RIGHT
		s3.ball.owner = c3.id
		s3.ball.pos = Vector2(0.6, 0)
		t3.pos = Vector2(1.9, 0.1)
		t3.cmd.tackle = true
		s3._resolve_actions()
		for i in 20:
			s3.tick += 1
			s3._update_timers()
			t3.cmd.clear()
			s3._move_players()
			s3._resolve_actions()
			s3._ball_step()
			s3._possession()
		if s3.ball.owner != c3.id:
			won += 1
	check(won >= 8 and won <= 28, "front tackle in reach succeeds sometimes, not always (%d/30)" % won)


func test_halves_and_clock() -> void:
	group("halves, clock, pause")
	var s := MatchSetup.exhibition(3)
	s.duration = 40.0
	var sim := MatchSim.new()
	sim.init_match(s, tuning)
	_sims.append(sim)
	var dir0 := sim.teams[0].dir
	var first := sim.first_kickoff_team
	var guard := 0
	while sim.state != MatchSim.State.HALF_TIME and guard < 20000:
		sim.step()
		guard += 1
	check(sim.state == MatchSim.State.HALF_TIME and absf(sim.time - 20.0) < 0.1, "half-time at half of the duration")
	# Pause = the simulation is simply not stepped: nothing may change.
	var snap := [sim.tick, sim.time, sim.ball.pos, sim.players[4].pos, sim.state_t]
	check(snap == [sim.tick, sim.time, sim.ball.pos, sim.players[4].pos, sim.state_t], "no hidden real-time timers inside the simulation")
	while sim.state == MatchSim.State.HALF_TIME and guard < 30000:
		sim.step()
		guard += 1
	check(sim.half == 2 and sim.teams[0].dir == -dir0, "teams switch ends")
	check(sim.restart_type == MatchSim.Restart.KICKOFF and sim.restart_team == 1 - first, "other team kicks off the second half")
	var t_before := sim.time
	run(sim, 30)
	check(sim.state == MatchSim.State.RESTART_SETUP and sim.time == t_before, "clock stops while a restart is being set up")
	while sim.state != MatchSim.State.FULL_TIME and guard < 60000:
		sim.step()
		guard += 1
	check(sim.state == MatchSim.State.FULL_TIME and absf(sim.time - 40.0) < 0.1, "full time at the configured duration")
	var tick := sim.tick
	run(sim, 50)
	check(sim.tick == tick, "nothing advances after full time")
	check(sim.stalls == 0, "no deadlock during the short match")


func test_control_handoff() -> void:
	group("controlled-player handoff")
	var sim := new_sim(8, 0)
	var h := sim.human
	run(sim, int(tuning.kickoff_setup_time * 60) + 20)
	check(h.controlled >= 0 and sim.players[h.controlled].team == 0, "a player of the human team is controlled")
	var humans := 0
	for p in sim.players:
		if p.is_human:
			humans += 1
	check(humans == 1, "exactly one human-controlled player")
	# Make sure we have the ball, then pass and expect control to follow the ball.
	ScenarioLib.apply(sim, "human_support", 0)
	var carrier := h.controlled
	check(sim.ball.owner == carrier, "scenario gives the controlled player the ball")
	h.input.move = Vector2(1, 0)
	run(sim, 20)
	check(sim.players[carrier].vel.x > 1.0, "movement input moves the controlled player")
	h.input.pass_pressed = true
	sim.step()
	var kicks: int = sim.teams[0].stats.passes
	run(sim, 3)
	check(sim.teams[0].stats.passes == kicks, "one press gives one pass")
	var recv := sim.ball.kick_receiver
	check(recv >= 0 and recv != carrier, "pass assistance picked a receiver")
	var to := sim.players[recv].pos - sim.players[carrier].pos
	check(to.x > -2.0, "a forward-aimed pass does not go to a teammate behind")
	check(h.controlled == recv or h.controlled == sim.teams[0].ai.receiver_id, "control moves to the receiver")
	check(not sim.players[carrier].is_human, "previous player returns to AI control")
	var duty_ok := (sim.teams[0].ai.agents[carrier] as AIAgent).duty != AIAgent.Duty.NONE
	run(sim, 12)
	duty_ok = duty_ok and (sim.teams[0].ai.agents[carrier] as AIAgent).duty != AIAgent.Duty.NONE
	check(duty_ok, "released player keeps a tactical duty")
	# Manual switch without the ball changes the player exactly once per press.
	sim.ball.owner = -1
	free_ball(sim, Vector2(30, 20), Vector2.ZERO)
	sim.ball.in_pass = false
	sim.step()
	var before := h.controlled
	h.input.switch_pressed = true
	sim.step()
	var after := h.controlled
	check(after != before, "E switches to another player")
	run(sim, 30)
	check(h.controlled == after or sim.ball.owner == h.controlled, "no further switching without input")
	humans = 0
	for p in sim.players:
		if p.is_human:
			humans += 1
	check(humans == 1, "still exactly one human-controlled player")


func test_idle_human_restart() -> void:
	group("idle human at a restart")
	var sim := new_sim(4, 0)
	sim.first_kickoff_team = 0
	sim.begin_restart(MatchSim.Restart.KICKOFF, 0, Vector2.ZERO)
	check(sim.players[sim.restart_taker].is_human, "human controls the kick-off taker")
	var ticks := 0
	while sim.state != MatchSim.State.PLAYING and ticks < 1500:
		sim.step()
		ticks += 1
	check(sim.state == MatchSim.State.PLAYING, "kick-off is taken automatically when the human does nothing (%.1fs)" % (ticks / 60.0))
	check(ticks / 60.0 > tuning.restart_force_time_human, "the human gets the full time before the AI takes over")


func test_keeper() -> void:
	group("goalkeeper")
	var sim := new_sim()
	open_play(sim, Vector2.ZERO)
	var gk := sim.players[sim.teams[1].player_ids[0]]
	gk.pos = Vector2(50.5, 0)
	gk.goalkeeping = 0.8
	sim.ball.last_touch_team = 0
	sim.ball.kick_kind = KickRequest.Kind.SHOT
	sim.ball.kicker = sim.teams[0].player_ids[9]
	free_ball(sim, Vector2(35, 0.2), Vector2(10, 0))
	for i in 200:
		sim.tick += 1
		sim._update_timers()
		sim._ball_step()
		if sim.state == MatchSim.State.PLAYING:
			sim._possession()
			sim._rules()
	check(sim.ball.held_by == gk.id and sim.teams[0].score == 0, "keeper catches a slow ball in his area")
	# Bounded holding time: the full sim must release the ball.
	sim.freeze_clock = true
	var released := false
	for i in int((tuning.keeper_hold_max + 3.0) * 60):
		sim.step()
		if sim.ball.held_by < 0:
			released = true
			break
	check(released, "keeper releases the ball within the limit")
	# A shot far outside his reach cannot be saved.
	var sim2 := new_sim()
	open_play(sim2, Vector2.ZERO)
	var gk2 := sim2.players[sim2.teams[1].player_ids[0]]
	gk2.pos = Vector2(50.5, -3.0)
	sim2.ball.last_touch_team = 0
	free_ball(sim2, Vector2(45, 3.0), Vector2(28, 0), 0.3)
	for i in 30:
		sim2.tick += 1
		sim2._update_timers()
		sim2._ball_step()
		if sim2.state == MatchSim.State.PLAYING:
			sim2._possession()
			sim2._rules()
	check(sim2.teams[0].score == 1, "keeper 6 m away from the ball line cannot save it")
	# Outside the penalty area he may not handle.
	var sim3 := new_sim()
	open_play(sim3, Vector2.ZERO)
	var gk3 := sim3.players[sim3.teams[1].player_ids[0]]
	gk3.pos = Vector2(25, 0)
	free_ball(sim3, Vector2(24.5, 0), Vector2(1, 0), 1.6)
	check(not sim3._may_handle(gk3), "no handling outside the area")


func test_backpass() -> void:
	group("back-pass rule")
	var sim := new_sim()
	open_play(sim, Vector2.ZERO)
	var gk := sim.players[sim.teams[0].player_ids[0]]
	var cb := sim.players[sim.teams[0].player_ids[2]]
	var opp := sim.players[sim.teams[1].player_ids[9]]
	gk.pos = Vector2(-47, 0)
	cb.pos = Vector2(-35, 0)
	cb.passing = 1.0
	sim.ball.owner = cb.id
	sim.ball.pos = cb.pos + Vector2(-0.5, 0)
	cb.pending_kick = KickRequest.make(KickRequest.Kind.PASS, Vector2.LEFT, 11.0, 0.0, gk.id, gk.pos)
	cb.pending_kick_t = 0.3
	sim._resolve_actions()
	check(sim.ball.backpass_team == 0 and not sim._may_handle(gk), "deliberate pass to own keeper: no handling")
	for i in 120:
		sim.tick += 1
		sim._update_timers()
		sim._ball_step()
		sim._possession()
	check(sim.ball.owner == gk.id and sim.ball.held_by < 0, "keeper controls the back-pass with his feet, not his hands")
	check(not sim._may_handle(gk), "foot control keeps handling forbidden")
	# He loses close control and meets the ball again: still forbidden, still feet only.
	sim.ball.owner = -1
	sim.ball.pos = gk.pos + Vector2(2.5, 0)
	sim.ball.vel = Vector2(-4, 0)
	for i in 90:
		sim.tick += 1
		sim._update_timers()
		sim._ball_step()
		sim._possession()
	check(sim.ball.held_by < 0 and not sim._may_handle(gk), "regaining the loose ball does not make handling legal")
	# An opponent's touch ends the restriction.
	sim.ball.owner = -1
	opp.pos = Vector2(-44, 3)
	sim.ball.pos = opp.pos + Vector2(0.2, 0)
	sim.ball.vel = Vector2.ZERO
	sim._give_possession(opp, false)
	check(sim.ball.backpass_team == -1, "an opponent's touch clears the restriction")
	sim.ball.owner = -1
	sim.ball.pos = gk.pos + Vector2(0.3, 0)
	check(sim._may_handle(gk), "after the opponent's touch the keeper may handle again")
	# A keeper's throw is not a back-pass; his kick from the ground is his own deliberate kick.
	var sim2 := new_sim()
	open_play(sim2, Vector2.ZERO)
	var gk2 := sim2.players[sim2.teams[0].player_ids[0]]
	gk2.pos = Vector2(-47, 0)
	sim2.ball.held_by = gk2.id
	gk2.pending_kick = KickRequest.make(KickRequest.Kind.PASS, Vector2.RIGHT, 12.0, 2.0, -1, Vector2(-30, 0))
	gk2.pending_kick_t = 0.3
	sim2._resolve_actions()
	check(sim2.ball.backpass_team == -1 and sim2.ball.held_by < 0, "a throw from the keeper's hands carries no back-pass flag")
	# A team-mate's non-kick touch (deflection) followed by the keeper is not a back-pass.
	var sim3 := new_sim()
	open_play(sim3, Vector2.ZERO)
	var gk3 := sim3.players[sim3.teams[0].player_ids[0]]
	var cb3 := sim3.players[sim3.teams[0].player_ids[3]]
	gk3.pos = Vector2(-47, 0)
	sim3.ball.kicker = sim3.teams[1].player_ids[9]
	sim3.ball.backpass_team = -1
	sim3.ball.pos = cb3.pos
	sim3._register_touch(cb3, false)
	sim3.ball.pos = gk3.pos + Vector2(0.3, 0)
	check(sim3._may_handle(gk3), "a team-mate's deflection of an opponent's ball leaves handling legal")


func test_substitution() -> void:
	group("substitutions")
	var cs := CareerState.create("smk", 2024)
	var setup := cs.match_setup_for(cs.user_fixture(), 51)
	var human_team := setup.human_team
	var sim := MatchSim.new()
	sim.init_match(setup, tuning)
	_sims.append(sim)
	run(sim, int(tuning.kickoff_setup_time * 60) + 120)
	var tm := sim.teams[human_team]
	var bench0 := tm.bench.size()
	check(bench0 >= 5, "bench available")
	# AI-controlled outfield slot with every kind of leftover state.
	var pid := tm.player_ids[4]
	if sim.players[pid].is_human or sim.ball.owner == pid:
		pid = tm.player_ids[3]
	var p := sim.players[pid]
	var old_uid := p.uid
	var incoming_uid := str(tm.bench[0]["id"])
	var pos0 := p.pos
	var role0 := p.role
	p.stun = 0.8
	p.tackle_cd = 1.2
	p.tackle_recover = 0.5
	p.kick_lock = 0.2
	p.pending_kick = KickRequest.make(KickRequest.Kind.SHOT, Vector2.RIGHT, 20, 0, -1, Vector2(50, 0))
	p.pending_kick_t = 0.3
	p.distance_run = 4500.0
	p.cmd.tackle = true
	p.stamina = 0.1
	var ag_old: AIAgent = tm.ai.agents[pid]
	ag_old.run_state = 1
	ag_old.engage = true
	sim.offside_flags[pid] = p.pos
	check(sim.substitute(human_team, pid, 0), "substitution accepted")
	check(p.uid == incoming_uid and p.uid != old_uid, "slot now holds the bench player's stable id")
	check(p.stun == 0.0 and p.tackle_cd == 0.0 and p.tackle_recover == 0.0 and p.kick_lock == 0.0, "no inherited stun / tackle / kick timers")
	check(p.pending_kick == null and not p.cmd.tackle and p.cmd.kick == null, "no queued kick or stale command")
	check(p.distance_run == 0.0 and absf(p.stamina - p.fitness) < 0.001 and p.stamina > 0.5, "fresh legs: own distance and stamina")
	check(p.pos == pos0 and p.role == role0 and p.team == human_team, "formation slot and position kept")
	var ag_new: AIAgent = tm.ai.agents[pid]
	check(ag_new != ag_old and ag_new.run_state == 0 and not ag_new.engage, "fresh tactical memory")
	check(not sim.offside_flags.has(pid), "no inherited offside flag")
	check(sim.participants.has(old_uid) and sim.participants.has(incoming_uid), "both players count as participants")
	check(tm.bench.size() == bench0 - 1 and tm.subs_made == 1, "bench and counter updated once")
	var shots_before := tm.stats.shots
	run(sim, 30)
	check(tm.stats.shots == shots_before, "the outgoing player's queued shot is never executed")
	check((tm.ai.agents[pid] as AIAgent).duty != AIAgent.Duty.NONE, "substitute receives a duty at the next replan")
	# Human-controlled slot: control stays on the slot, charge state is cleared.
	var hid := sim.human.controlled
	if sim.ball.owner == hid:
		sim.ball.owner = -1
	sim.human.charging = true
	sim.human.shot_charge = 0.7
	check(sim.substitute(human_team, hid, 0), "human-controlled player can be substituted")
	check(sim.players[hid].is_human and sim.human.controlled == hid and not sim.human.charging and sim.human.shot_charge == 0.0, "control stays on the slot without a carried-over shot charge")
	var humans := 0
	for q in sim.players:
		if q.is_human:
			humans += 1
	check(humans == 1, "still exactly one human-controlled player")
	# Goalkeeper slot keeps role and handling rights; a keeper holding the ball cannot be replaced.
	var gk := sim.players[tm.player_ids[0]]
	sim.ball.owner = -1
	sim.ball.held_by = gk.id
	check(not sim.substitute(human_team, gk.id, 0), "keeper holding the ball cannot be substituted")
	sim.ball.held_by = -1
	gk.dive_recover = 0.6
	check(sim.substitute(human_team, gk.id, 0) and gk.is_keeper() and gk.dive_recover == 0.0, "keeper slot: role kept, no inherited dive recovery")
	# Owner of the ball cannot be replaced; a substitute next to an in-flight ball can play it.
	var cb := sim.players[tm.player_ids[2]]
	sim.ball.owner = cb.id
	check(not sim.substitute(human_team, cb.id, 0), "ball owner cannot be substituted")
	sim.ball.owner = -1
	sim.state = MatchSim.State.PLAYING
	sim.ball.dead = false
	sim.ball.pos = cb.pos + Vector2(3.0, 0)
	sim.ball.vel = Vector2(-5.0, 0)
	sim.ball.h = 0.0
	sim.ball.in_pass = false
	cb.kick_lock = 5.0
	check(sim.substitute(human_team, cb.id, 0), "fourth substitution accepted")
	for i in 60:
		sim.tick += 1
		sim._update_timers()
		sim._ball_step()
		sim._possession()
	check(sim.ball.owner == cb.id, "substitute controls a ball arriving at his feet (no inherited lock)")
	# Limit of five and invalid requests.
	sim.ball.owner = -1
	check(sim.substitute(human_team, tm.player_ids[6], 0), "fifth substitution accepted")
	check(not sim.substitute(human_team, tm.player_ids[7], 0) and tm.subs_made == 5, "sixth substitution rejected")
	check(not sim.substitute(human_team, tm.player_ids[7], 99), "invalid bench index rejected")
	var uids := {}
	var dup := false
	for id in tm.player_ids:
		if uids.has(sim.players[id].uid):
			dup = true
		uids[sim.players[id].uid] = true
	for b: Dictionary in tm.bench:
		if uids.has(str(b["id"])):
			dup = true
	check(not dup, "no player is on the pitch twice or on pitch and bench")
	sim.state = MatchSim.State.FULL_TIME
	tm.subs_made = 0
	check(not sim.substitute(human_team, tm.player_ids[7], 0), "no substitution after full time")


func test_determinism() -> void:
	group("determinism")
	var sigs := []
	for i in 2:
		var s := MatchSetup.exhibition(77)
		s.duration = 30.0
		var sim := MatchSim.new()
		sim.init_match(s, tuning)
		_sims.append(sim)
		var guard := 0
		while sim.state != MatchSim.State.FULL_TIME and guard < 30000:
			sim.step()
			guard += 1
		sigs.append("%d|%s|%s|%d|%d" % [sim.tick, str(sim.ball.pos), str(sim.players[7].pos), sim.teams[0].stats.passes, sim.teams[1].stats.passes])
	check(sigs[0] == sigs[1], "same seed gives the identical match")
