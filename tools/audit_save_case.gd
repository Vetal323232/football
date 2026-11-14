extends SceneTree
## One mutation per subprocess; never touches the player's normal save.
## The Python runner detects runtime errors even if Godot exits with code zero.

const CASES := ["valid", "broken_json", "root_array", "missing_schema", "unsupported_schema",
	"wrong_players_container", "negative_budget", "missing_player", "duplicate_fixture",
	"round_high", "round_negative", "round_string", "season_zero", "season_over_type",
	"lineup_duplicate", "lineup_empty", "lineup_no_keeper", "squad_type", "club_null",
	"player_null", "attrs_type", "attr_missing", "attr_range", "age_missing",
	"fixture_score_negative", "fixture_season_missing", "fixture_played_type", "fixture_self_match",
	"transfer_list_type", "history_type", "both_invalid", "missing_backup"]


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var selected := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--case="):
			selected = arg.trim_prefix("--case=")
	if not CASES.has(selected):
		printerr("Unknown save case: ", selected)
		quit(2)
		return
	var cs := CareerState.create("smk", 2024)
	var d: Variant = cs.data.duplicate(true)
	var club: Dictionary = d["clubs"]["smk"]
	var pid: String = club["lineup"][1]
	var dir := "user://deep_audit_save_" + selected
	SaveManager.delete(dir)
	if SaveManager.save(cs, dir) != "" or SaveManager.save(cs, dir) != "":
		printerr("Cannot create isolated control save")
		quit(2)
		return
	match selected:
		"root_array": d = []
		"missing_schema": d.erase("schema")
		"unsupported_schema": d["schema"] = 999
		"wrong_players_container": d["players"] = []
		"negative_budget": club["budget"] = -1
		"missing_player": d["players"].erase(pid)
		"duplicate_fixture": d["fixtures"].append(d["fixtures"][0].duplicate(true))
		"round_high": d["round"] = 999
		"round_negative": d["round"] = -1
		"round_string": d["round"] = "tomorrow"
		"season_zero": d["season"] = 0
		"season_over_type": d["season_over"] = "false"
		"lineup_duplicate": club["lineup"][2] = club["lineup"][1]
		"lineup_empty": club["lineup"] = []
		"lineup_no_keeper":
			for candidate: String in club["squad"]:
				if d["players"][candidate]["pos"] != "GK" and not (club["lineup"] as Array).has(candidate):
					club["lineup"][0] = candidate
					break
		"squad_type": club["squad"] = "bad"
		"club_null": d["clubs"]["smk"] = null
		"player_null": d["players"][pid] = null
		"attrs_type": d["players"][pid]["attrs"] = "bad"
		"attr_missing": d["players"][pid]["attrs"].erase("pace")
		"attr_range": d["players"][pid]["attrs"]["pace"] = 999
		"age_missing": d["players"][pid].erase("age")
		"fixture_score_negative": d["fixtures"][0]["hg"] = -3
		"fixture_season_missing": d["fixtures"][0].erase("season")
		"fixture_played_type": d["fixtures"][0]["played"] = "false"
		"fixture_self_match": d["fixtures"][0]["away"] = d["fixtures"][0]["home"]
		"transfer_list_type": d["transfer_list"] = 3
		"history_type": d["history"] = 3
		"both_invalid", "missing_backup": d["round"] = 999
	var f := FileAccess.open(SaveManager.path(dir), FileAccess.WRITE)
	f.store_string("{broken" if selected == "broken_json" else JSON.stringify(d))
	f.close()
	if selected == "both_invalid":
		var fb := FileAccess.open(SaveManager.path(dir) + ".bak", FileAccess.WRITE)
		fb.store_string(JSON.stringify(d))
		fb.close()
	elif selected == "missing_backup":
		DirAccess.remove_absolute(SaveManager.path(dir) + ".bak")
	var result := SaveManager.load_career(dir)
	var loaded: CareerState = result.get("career")
	var equal_to_backup := loaded != null and JSON.stringify(loaded.data) == JSON.stringify(cs.data)
	var should_recover := selected != "valid"
	var ok := equal_to_backup and bool(result["recovered"]) == should_recover
	if selected == "both_invalid" or selected == "missing_backup":
		# Nothing usable: no career object, no "recovered" claim, an understandable error.
		ok = loaded == null and not bool(result["recovered"]) and str(result["error"]) != ""
	print("SAVE_CASE_DONE " + JSON.stringify({"case": selected, "ok": ok, "recovered": result["recovered"], "backup_equal": equal_to_backup, "error": result["error"]}))
	SaveManager.delete(dir)
	quit(0 if ok else 1)
