class_name Schedule
extends RefCounted
## Double round-robin fixture generation (circle method).


## Returns Array of rounds; each round is an Array of [home_id, away_id].
static func double_round_robin(ids: Array) -> Array:
	var n := ids.size()
	assert(n % 2 == 0)
	var arr := ids.duplicate()
	var first_half := []
	for r in n - 1:
		var round_ := []
		for i in n / 2:
			var a: String = arr[i]
			var b: String = arr[n - 1 - i]
			# Alternate home advantage so nobody has long home/away streaks.
			if (r + i) % 2 == 0:
				round_.append([a, b])
			else:
				round_.append([b, a])
		first_half.append(round_)
		# Rotate all but the first element.
		var last: String = arr.pop_back()
		arr.insert(1, last)
	var rounds := first_half.duplicate(true)
	for r in first_half:
		var mirrored := []
		for m: Array in r:
			mirrored.append([m[1], m[0]])
		rounds.append(mirrored)
	return rounds


static func make_fixtures(ids: Array, season: int) -> Array:
	var out := []
	var rounds := double_round_robin(ids)
	for r in rounds.size():
		for m in rounds[r].size():
			out.append({"id": "s%d_r%02d_m%d" % [season, r + 1, m + 1], "season": season, "round": r,
				"home": rounds[r][m][0], "away": rounds[r][m][1], "played": false, "hg": 0, "ag": 0})
	return out
