extends SceneTree
## Independent session-2 boundary regressions. No normal user saves are touched.
## Exit 0 only if the desired contract holds; unresolved defects deliberately exit 1.

func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var selected := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--case="):
			selected = arg.trim_prefix("--case=")
	var cs := CareerState.create("smk", 2024)
	var pid: String = cs.user()["lineup"][1]
	var ok := false
	match selected:
		"missing_history":
			cs.data.erase("history")
			var errors := CareerState.validate(cs.data)
			# Either reject the record, or normalize it to a usable legacy state.
			if errors.is_empty():
				CareerState.normalize(cs.data)
				ok = cs.data.get("history") is Array
				if not ok:
					_load_mutated(cs, selected)
					for i in CareerState.ROUNDS:
						cs.complete_round(true)
			else:
				ok = true
			print("missing_history errors=", errors, " usable_history=", cs.data.get("history") is Array)
		"extra_attribute":
			cs.player(pid)["attrs"]["unexpected"] = {"bad": true}
			var errors := CareerState.validate(cs.data)
			ok = not errors.is_empty()
			print("extra_attribute errors=", errors)
			if errors.is_empty():
				# normalize iterates EVERY attribute, unlike validate (only Attr.KEYS).
				_load_mutated(cs, selected)
		"fitness_type":
			cs.player(pid)["fitness"] = {"bad": true}
			var errors := CareerState.validate(cs.data)
			ok = not errors.is_empty()
			print("fitness_type errors=", errors)
			if errors.is_empty():
				_load_mutated(cs, selected)
				cs.match_setup_for(cs.user_fixture(), 11)
		"duplicate_pair":
			var f: Dictionary = cs.data["fixtures"][0]
			var other: Dictionary = cs.data["fixtures"][1]
			# Retain unique fixture ID and total count; duplicate one pairing in the same round.
			other["home"] = f["home"]
			other["away"] = f["away"]
			var errors := CareerState.validate(cs.data)
			ok = not errors.is_empty()
			print("duplicate_pair errors=", errors, " home=", f["home"], " away=", f["away"])
			if errors.is_empty():
				_load_mutated(cs, selected)
				cs.complete_round(true)
				for row: Dictionary in cs.standings():
					if row["club"] == f["home"]:
						print("duplicate_pair played_after_one_round=", row["p"])
		"legal_low_keeper":
			var keepers := []
			for p: Dictionary in cs.squad_of("smk"):
				var value := 1 if p["pos"] == "GK" else 99
				for key: String in Attr.KEYS:
					p["attrs"][key] = value
				if p["pos"] == "GK":
					keepers.append(p["id"])
			var before: Array = cs.user()["lineup"].duplicate()
			var legal_before := cs.lineup_valid("smk", before) == ""
			var changed := cs.auto_lineup("smk")
			ok = legal_before and changed and cs.lineup_valid("smk", cs.user()["lineup"]) == ""
			print("legal_low_keeper legal_before=", legal_before, " result=", changed, " keeper_count=", keepers.size(), " unchanged=", before == cs.user()["lineup"])
		_:
			printerr("Unknown session2 review case: ", selected)
			quit(2)
			return
	print("SESSION2_CASE_DONE ", JSON.stringify({"case": selected, "ok": ok}))
	quit(0 if ok else 1)


func _load_mutated(cs: CareerState, selected: String) -> void:
	var dir := "user://session2_boundary_" + selected
	var control := CareerState.create("smk", 2024)
	SaveManager.delete(dir)
	SaveManager.save(control, dir)
	SaveManager.save(control, dir)
	var file := FileAccess.open(SaveManager.path(dir), FileAccess.WRITE)
	file.store_string(JSON.stringify(cs.data))
	file.close()
	var result := SaveManager.load_career(dir)
	print("actual_load recovered=", result["recovered"], " error=", result["error"], " career_present=", result.get("career") != null)
	SaveManager.delete(dir)
