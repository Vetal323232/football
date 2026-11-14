extends Node
## Original procedurally synthesised sound effects (no external audio assets).

const RATE := 22050

var _streams := {}
var _players: Array[AudioStreamPlayer] = []
var _crowd: AudioStreamPlayer
var _next := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_bus("SFX")
	_ensure_bus("Crowd")
	_streams["kick"] = _make(0.12, func(t: float, n: float) -> float:
		return (sin(TAU * (150.0 - 500.0 * t) * t) * 0.9 + n * 0.35) * exp(-t * 38.0))
	_streams["pass"] = _make(0.09, func(t: float, n: float) -> float:
		return (sin(TAU * (190.0 - 600.0 * t) * t) * 0.6 + n * 0.2) * exp(-t * 48.0))
	_streams["bounce"] = _make(0.08, func(t: float, n: float) -> float:
		return (sin(TAU * 110.0 * t) * 0.6 + n * 0.15) * exp(-t * 55.0))
	_streams["post"] = _make(0.5, func(t: float, n: float) -> float:
		return (sin(TAU * 830.0 * t) + 0.5 * sin(TAU * 1370.0 * t) + 0.3 * sin(TAU * 2210.0 * t)) * 0.4 * exp(-t * 9.0) + n * 0.3 * exp(-t * 80.0))
	_streams["whistle"] = _make(0.45, func(t: float, n: float) -> float:
		var env := minf(1.0, t * 60.0) * minf(1.0, (0.45 - t) * 30.0)
		return sin(TAU * (2850.0 + 90.0 * sin(TAU * 38.0 * t)) * t) * 0.35 * env + n * 0.04 * env)
	_streams["whistle_long"] = _make(1.3, func(t: float, n: float) -> float:
		var seg := fmod(t, 0.45)
		var env := minf(1.0, seg * 60.0) * (1.0 if t > 0.9 else minf(1.0, (0.38 - seg) * 30.0))
		env = clampf(env, 0.0, 1.0) * minf(1.0, (1.3 - t) * 20.0)
		return sin(TAU * (2850.0 + 90.0 * sin(TAU * 38.0 * t)) * t) * 0.35 * env)
	_streams["ui_move"] = _make(0.05, func(t: float, _n: float) -> float:
		return sin(TAU * 660.0 * t) * 0.25 * exp(-t * 60.0))
	_streams["ui_ok"] = _make(0.12, func(t: float, _n: float) -> float:
		return (sin(TAU * 520.0 * t) + sin(TAU * 780.0 * t)) * 0.18 * exp(-t * 22.0))
	_streams["tackle"] = _make(0.14, func(t: float, n: float) -> float:
		return n * 0.5 * exp(-t * 26.0) + sin(TAU * 90.0 * t) * 0.4 * exp(-t * 30.0))
	_streams["cheer"] = _make_noise(3.2, func(t: float) -> float:
		return minf(1.0, t * 3.5) * exp(-maxf(0.0, t - 0.9) * 1.25), 0.55)
	_streams["ooh"] = _make_noise(1.2, func(t: float) -> float:
		return minf(1.0, t * 6.0) * exp(-t * 2.8), 0.3)
	var crowd: AudioStreamWAV = _make_noise(4.0, func(t: float) -> float:
		return 0.75 + 0.25 * sin(TAU * t / 4.0) * sin(TAU * t / 2.0), 0.16)
	crowd.loop_mode = AudioStreamWAV.LOOP_FORWARD
	crowd.loop_end = int(4.0 * RATE)
	_streams["crowd"] = crowd
	for i in 8:
		var p := AudioStreamPlayer.new()
		p.bus = &"SFX"
		add_child(p)
		_players.append(p)
	_crowd = AudioStreamPlayer.new()
	_crowd.bus = &"Crowd"
	_crowd.stream = crowd
	add_child(_crowd)


func _exit_tree() -> void:
	# Stop playback so no stream playback objects outlive the audio server at shutdown.
	for p in _players:
		p.stop()
		p.stream = null
	_crowd.stop()
	_crowd.stream = null
	_streams.clear()


func _ensure_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) < 0:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count - 1, bus_name)


func apply_volumes() -> void:
	var s: Dictionary = Game.settings
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), linear_to_db(clampf(float(s["sfx_volume"]), 0.0001, 1.0)))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Crowd"), linear_to_db(clampf(float(s["crowd_volume"]), 0.0001, 1.0)))


func play(sound: String, volume := 1.0, pitch := 1.0) -> void:
	if not _streams.has(sound):
		return
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = _streams[sound]
	p.volume_db = linear_to_db(clampf(volume, 0.001, 2.0))
	p.pitch_scale = pitch
	p.play()


func crowd(on: bool) -> void:
	if on and not _crowd.playing:
		_crowd.play()
	elif not on:
		_crowd.stop()


func _make(length: float, f: Callable) -> AudioStreamWAV:
	var n := int(length * RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	for i in n:
		var t := float(i) / RATE
		var v: float = clampf(f.call(t, rng.randf_range(-1.0, 1.0)), -1.0, 1.0)
		data.encode_s16(i * 2, int(v * 32000.0))
	return _wav(data)


## Band-limited noise with an envelope: sounds like a crowd.
func _make_noise(length: float, env: Callable, gain: float) -> AudioStreamWAV:
	var n := int(length * RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 777
	var lp := 0.0
	var lp2 := 0.0
	var hp := 0.0
	for i in n:
		var t := float(i) / RATE
		var w := rng.randf_range(-1.0, 1.0)
		lp += (w - lp) * 0.16
		lp2 += (lp - lp2) * 0.3
		hp += (lp2 - hp) * 0.01
		var v: float = clampf((lp2 - hp) * 4.0 * gain * float(env.call(t)), -1.0, 1.0)
		data.encode_s16(i * 2, int(v * 32000.0))
	return _wav(data)


func _wav(data: PackedByteArray) -> AudioStreamWAV:
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.stereo = false
	s.data = data
	return s
