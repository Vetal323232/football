extends SceneTree
## End-to-end career check through the real match engine (headless):
## play the user's fixture on the pitch (AI controls both sides), apply the result,
## advance rounds, save, reload from disk, continue, finish the season, roll over.
## Usage: godot --headless -s tools/career_journey.gd -- [--played=3] [--duration=60]


func _init() -> void:
	var played := 3
	var duration := 60.0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--played="): played = int(a.trim_prefix("--played="))
		elif a.begins_with("--duration="): duration = float(a.trim_prefix("--duration="))
	var tuning: GameTuning = load("res://data/tuning/default_tuning.tres")
	var dir := "user://journey_saves"
	SaveManager.delete(dir)
	var cs := CareerState.create("zar", 2025)
	var ok := true
	print("career created: user club %s, budget %d, squad %d" % [cs.user()["name"], cs.user()["budget"], (cs.user()["squad"] as Array).size()])
	# Transfer before the first match: buy the best listed forward we can afford, sell a reserve.
	var bought := ""
	var list: Array = (cs.data["transfer_list"] as Array).duplicate()
	list.sort_custom(func(a: String, b: String) -> bool: return cs.ovr(a) > cs.ovr(b))
	for pid: String in list:
		if cs.player(pid)["pos"] == "FW" and cs.buy(pid) == "":
			bought = pid
			break
	if bought != "":
		var lu: Array = cs.user()["lineup"].duplicate()
		lu[9] = bought
		cs.set_lineup("zar", lu)
		print("bought %s (ovr %d) for %d and put him at striker; budget now %d" % [cs.player(bought)["name"], cs.ovr(bought), cs.price(bought), cs.user()["budget"]])
	for r in played:
		var f := cs.user_fixture()
		var setup := cs.match_setup_for(f, 500 + r)
		setup.human_team = -1
		setup.duration = duration
		var in_match := false
		for pd: Dictionary in setup.teams[0 if f["home"] == "zar" else 1]["players"]:
			if pd["id"] == bought:
				in_match = true
		var sim := MatchSim.new()
		sim.init_match(setup, tuning)
		var guard := 0
		while sim.state != MatchSim.State.FULL_TIME and guard < 200000:
			sim.step()
			guard += 1
		var apps_before := int(cs.player(cs.user()["lineup"][5])["apps"])
		var first := cs.apply_result(f["id"], sim.teams[0].score, sim.teams[1].score, sim.participants.keys())
		var dup := cs.apply_result(f["id"], sim.teams[0].score, sim.teams[1].score, sim.participants.keys())
		cs.complete_round()
		var err := SaveManager.save(cs, dir)
		# "Close the game": drop the object and reload from disk.
		var res := SaveManager.load_career(dir)
		var same := res["career"] != null and JSON.stringify((res["career"] as CareerState).data) == JSON.stringify(cs.data)
		cs = res["career"]
		print("round %d: %s %d-%d %s | bought player on pitch: %s | applied %s, duplicate rejected %s | apps %d->%d | save '%s' reload identical %s | round now %d, position %d" % [
			r + 1, cs.club(f["home"])["short"], int(f["hg"]) if false else sim.teams[0].score, sim.teams[1].score, cs.club(f["away"])["short"], str(in_match), str(first), str(not dup),
			apps_before, int(cs.player(cs.user()["lineup"][5])["apps"]), err, str(same), int(cs.data["round"]), cs.position_of("zar")])
		ok = ok and first and not dup and same and err == "" and (bought == "" or in_match)
	while not cs.data["season_over"]:
		cs.complete_round(true)
	SaveManager.save(cs, dir)
	var st := cs.standings()
	print("season 1 final table:")
	for i in st.size():
		print("  %d. %-18s P%d W%d D%d L%d  %d:%d (%+d)  %d pts" % [i + 1, st[i]["name"], st[i]["p"], st[i]["w"], st[i]["d"], st[i]["l"], st[i]["gf"], st[i]["ga"], st[i]["gd"], st[i]["pts"]])
	var games := 0
	for row: Dictionary in st:
		games += int(row["p"])
	ok = ok and games == 112
	cs.start_next_season()
	SaveManager.save(cs, dir)
	var again: CareerState = SaveManager.load_career(dir)["career"]
	print("rollover: season %d round %d, fixtures %d, first id %s, validation errors %d, history %s" % [again.data["season"], again.data["round"], (again.data["fixtures"] as Array).size(), again.data["fixtures"][0]["id"], CareerState.validate(again.data).size(), str(again.data["history"])])
	again.complete_round(true)
	ok = ok and int(again.data["round"]) == 1 and CareerState.validate(again.data).is_empty()
	SaveManager.delete(dir)
	print("JOURNEY %s" % ("OK" if ok else "FAILED"))
	quit(0 if ok else 1)
