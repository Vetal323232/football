class_name GameTuning
extends Resource
## All gameplay tuning in one editable resource (data/tuning/default_tuning.tres).
## Behaviour code reads values from here; nothing here is changed during a match.

@export_group("Match")
@export var match_seconds := 360.0
@export var goal_pause := 3.0
@export var half_time_pause := 3.0
@export var restart_setup_time := 2.2
@export var kickoff_setup_time := 3.2
@export var restart_ai_delay := 1.0
@export var restart_force_time_ai := 3.0
@export var restart_force_time_human := 8.0
@export var keeper_hold_max := 5.0

@export_group("Player movement")
@export var sprint_speed_min := 6.6
@export var sprint_speed_max := 8.8
@export var jog_ratio := 0.7
@export var accel_base := 8.5
@export var accel_attr := 4.0
@export var decel := 15.0
@export var turn_rate := 11.0
@export var dribble_speed_ratio := 0.93
@export var recover_speed := 1.6
@export var player_radius := 0.38
@export var stamina_drain := 0.04
@export var stamina_recover_jog := 0.022
@export var stamina_recover_idle := 0.06
@export var fitness_loss_per_km := 0.035

@export_group("Ball physics")
@export var gravity := 9.81
@export var air_drag := 0.011
@export var roll_decel := 3.0
@export var bounce_restitution := 0.58
@export var bounce_friction := 0.82
@export var bounce_min := 1.2
@export var post_restitution := 0.55

@export_group("Possession")
@export var claim_reach := 0.75
@export var claim_reach_attr := 0.2
@export var claim_height := 1.1
@export var body_block_radius := 0.42
@export var trap_speed_base := 13.0
@export var trap_speed_attr := 10.0
@export var dribble_lead := 0.55
@export var dribble_lead_sprint := 0.5
@export var dribble_gain := 9.0
@export var dribble_accel_base := 34.0
@export var dribble_accel_attr := 30.0
@export var lose_reach := 1.7
@export var owner_lock_time := 0.15
@export var kick_reach := 1.05
@export var kick_lock_time := 0.32

@export_group("Kicking")
@export var pass_arrive_speed := 10.0
@export var pass_speed_max := 24.0
@export var shot_speed_min := 17.0
@export var shot_speed_base := 26.0
@export var shot_speed_attr := 6.0
@export var pass_error_bad := 0.06
@export var pass_error_good := 0.01
@export var shot_error_bad := 0.085
@export var shot_error_good := 0.022
@export var loft_error_mult := 1.5
@export var first_time_error_mult := 1.6
@export var throw_speed_max := 15.0
@export var shot_charge_time := 0.85

@export_group("Tackling")
@export var tackle_window := 0.26
@export var tackle_reach := 1.0
@export var tackle_lunge_speed := 5.8
@export var tackle_recover_hit := 0.35
@export var tackle_recover_miss := 0.85
@export var tackle_cooldown := 0.9
@export var tackle_base_chance := 0.6
@export var tackle_behind_mult := 0.4
@export var tackle_stun := 0.55

@export_group("Goalkeeper")
@export var keeper_reach := 0.9
@export var keeper_dive_reach := 1.5
@export var keeper_reach_height := 2.55
@export var keeper_dive_speed_base := 5.2
@export var keeper_dive_speed_attr := 2.6
@export var keeper_dive_time := 0.55
@export var keeper_dive_recover := 0.9
@export var keeper_catch_speed_base := 15.0
@export var keeper_catch_speed_attr := 11.0
@export var keeper_react_bad := 0.34
@export var keeper_react_good := 0.16

@export_group("AI timing")
@export var team_update_ticks := 6
@export var onball_decision_time := 0.15
@export var settle_time := 0.2
@export var dribble_commit_time := 0.4
@export var press_switch_margin := 0.45
@export var press_min_commit := 1.0
@export var position_refresh_time := 0.3
@export var position_switch_margin := 0.06

@export_group("AI evaluation")
@export var value_base := 0.004
@export var value_progress := 0.15
@export var value_xg := 0.9
@export var value_goal_pull := 0.12
@export var loss_cost_scale := 0.5
@export var intercept_react := 0.22
@export var pass_margin_bias := 0.12
@export var pass_margin_soft := 0.2
@export var hold_decay := 0.012
@export var dribble_margin_bias := 0.15
@export var carry_bonus := 0.015
@export var impatience_gain := 0.03
@export var shot_min_xg := 0.025
@export var goal_value := 2.6
@export var progress_bonus := 0.04
@export var through_arrive_speed := 8.0
@export var xg_scale := 1.0
@export var support_dist_min := 7.0
@export var support_dist_max := 15.0
@export var crowd_radius := 9.0
@export var press_trigger_dist := 16.0
@export var contain_dist := 2.4
@export var cover_dist := 6.0
@export var mark_tightness_def := 0.65
@export var mark_tightness_mid := 0.3
