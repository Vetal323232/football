class_name Attr
extends RefCounted
## Player attribute helpers. Stored attributes are integers 1..99.

const KEYS: Array[String] = ["pace", "passing", "shooting", "control", "defending", "stamina", "goalkeeping"]


static func norm(v: float) -> float:
	## Maps 25..99 to 0..1 so that squad players already feel competent.
	return clampf((v - 25.0) / 74.0, 0.0, 1.0)


## Overall rating: role-weighted mean of attributes (documented in DESIGN.md).
static func overall(attrs: Dictionary, position: String) -> int:
	var w := weights(position)
	var s := 0.0
	var ws := 0.0
	for k: String in w:
		s += float(attrs.get(k, 40)) * float(w[k])
		ws += float(w[k])
	return int(round(s / maxf(ws, 0.001)))


static func weights(position: String) -> Dictionary:
	match position:
		"GK":
			return {"goalkeeping": 6.0, "passing": 0.6, "control": 0.4, "pace": 0.4, "stamina": 0.3}
		"DF":
			return {"defending": 3.5, "pace": 1.6, "passing": 1.2, "control": 1.0, "stamina": 1.2, "shooting": 0.3}
		"MF":
			return {"passing": 3.0, "control": 2.4, "stamina": 1.6, "defending": 1.2, "pace": 1.2, "shooting": 1.0}
		_:
			return {"shooting": 3.2, "pace": 2.2, "control": 2.2, "passing": 1.2, "stamina": 0.8, "defending": 0.2}


static func position_of_role(role: int) -> String:
	if role == SimPlayer.Role.GK:
		return "GK"
	if role <= SimPlayer.Role.RB:
		return "DF"
	if role <= SimPlayer.Role.RCM:
		return "MF"
	return "FW"
