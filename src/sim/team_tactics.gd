class_name TeamTactics
extends Resource
## Team instructions (0..1 each) plus AI skill settings.
## Difficulty only changes decision quality, execution error and reaction time.

@export_range(0.0, 1.0) var width := 0.6
@export_range(0.0, 1.0) var line_height := 0.5
@export_range(0.0, 1.0) var pressing := 0.5
@export_range(0.0, 1.0) var pass_risk := 0.5

@export_group("AI skill")
@export var reaction_time := 0.25
@export var decision_noise := 0.004
@export var execution_error_mult := 1.0


static func for_difficulty(level: int) -> TeamTactics:
	var t := TeamTactics.new()
	match level:
		0:
			t.reaction_time = 0.42
			t.decision_noise = 0.012
			t.execution_error_mult = 1.5
			t.pressing = 0.35
		1:
			t.reaction_time = 0.28
			t.decision_noise = 0.005
			t.execution_error_mult = 1.15
		_:
			t.reaction_time = 0.2
			t.decision_noise = 0.002
			t.execution_error_mult = 1.0
			t.pressing = 0.6
	return t
