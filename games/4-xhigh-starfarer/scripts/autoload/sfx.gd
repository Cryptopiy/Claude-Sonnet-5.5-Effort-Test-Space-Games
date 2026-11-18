extends Node
## Fully procedural audio: every sound is synthesised at start-up into AudioStreamWAV buffers (no audio files).

const RATE := 22050
var _streams := {}
var _loops := {}            # name -> AudioStreamPlayer
var _pool: Array = []
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.seed = 7
	_build()
	for i in 10:
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_pool.append(p)
	for n in ["engine", "wind", "jet", "pulse", "rumble", "music", "atmo_roar"]:
		var p := AudioStreamPlayer.new()
		p.stream = _streams[n]
		p.volume_db = -80.0
		p.autoplay = false
		add_child(p)
		_loops[n] = p
	set_loop("music", -22.0, 1.0)


func _wav(samples: PackedFloat32Array, loop := false) -> AudioStreamWAV:
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	var b := PackedByteArray()
	b.resize(samples.size() * 2)
	for i in samples.size():
		b.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
	w.data = b
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = samples.size()
	return w


func _noise(n: int, cutoff: float, passes := 1) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		out[i] = _rng.randf_range(-1.0, 1.0)
	var a := clampf(cutoff / float(RATE) * TAU, 0.001, 1.0)
	for p in passes:
		var y := out[n - 1]
		for i in n:
			y += a * (out[i] - y)
			out[i] = y
	# normalise
	var m := 0.0001
	for i in n:
		m = maxf(m, absf(out[i]))
	for i in n:
		out[i] /= m
	return out


func _highpass(src: PackedFloat32Array, cutoff: float) -> PackedFloat32Array:
	var lp := PackedFloat32Array(src)
	var a := clampf(cutoff / float(RATE) * TAU, 0.001, 1.0)
	var y := 0.0
	for i in lp.size():
		y += a * (src[i] - y)
		lp[i] = src[i] - y
	return lp


func _build() -> void:
	# ---- loops (durations chosen so integer-cycle sines loop seamlessly)
	var n := RATE * 2
	var eng := _noise(n, 380.0, 2)
	var s := PackedFloat32Array()
	s.resize(n)
	for i in n:
		var t := float(i) / RATE
		var v := 0.34 * sin(TAU * 55.0 * t) + 0.22 * sin(TAU * 82.5 * t + 1.0) + 0.16 * sin(TAU * 110.0 * t + 2.0) + 0.08 * sin(TAU * 165.0 * t)
		v *= 0.75 + 0.25 * sin(TAU * 7.0 * t)
		s[i] = v * 0.7 + eng[i] * 0.45
	_streams["engine"] = _wav(s, true)

	n = RATE * 3
	var wind := _noise(n, 700.0, 3)
	for i in n:
		var t := float(i) / (RATE * 3.0)
		wind[i] *= 0.6 + 0.4 * sin(TAU * 2.0 * t) * sin(TAU * 3.0 * t + 1.0)
	_streams["wind"] = _wav(wind, true)

	n = RATE
	var jet := _highpass(_noise(n, 5000.0, 1), 900.0)
	for i in n:
		jet[i] *= 0.9
	_streams["jet"] = _wav(jet, true)

	n = RATE * 2
	var pl := _noise(n, 1500.0, 2)
	for i in n:
		var t := float(i) / RATE
		pl[i] = pl[i] * 0.7 + 0.35 * sin(TAU * 120.0 * t) * (0.7 + 0.3 * sin(TAU * 3.0 * t))
	_streams["pulse"] = _wav(pl, true)

	n = RATE * 2
	var rb := _noise(n, 90.0, 3)
	for i in n:
		var t := float(i) / RATE
		rb[i] = rb[i] * 0.6 + 0.5 * sin(TAU * 34.0 * t) + 0.3 * sin(TAU * 51.0 * t)
	_streams["rumble"] = _wav(rb, true)

	n = RATE * 2
	var ar := _noise(n, 2400.0, 2)
	for i in n:
		ar[i] *= 0.9
	_streams["atmo_roar"] = _wav(ar, true)

	# ambient music: slow detuned chord pad, 24 s loop
	n = RATE * 24
	var mus := PackedFloat32Array()
	mus.resize(n)
	var notes := [110.0, 164.8125, 220.0, 277.1875, 329.625, 440.0, 138.5938]
	for i in n:
		var t := float(i) / RATE
		var v := 0.0
		for k in notes.size():
			var f: float = notes[k]
			var lfo := 0.5 + 0.5 * sin(TAU * (float(k + 1) / 24.0) * t + k)
			v += sin(TAU * f * t) * lfo * (0.16 / (1.0 + k * 0.25))
			v += sin(TAU * (f * 1.004) * t + 0.3) * lfo * 0.05
		mus[i] = v * 0.7
	_streams["music"] = _wav(mus, true)

	# ---- one shots
	_streams["step"] = _wav(_env(_noise(int(RATE * 0.13), 1400.0, 2), 0.004, 0.12, 0.8))
	_streams["step_snow"] = _wav(_env(_highpass(_noise(int(RATE * 0.16), 3000.0, 1), 700.0), 0.01, 0.15, 0.55))
	_streams["thud"] = _wav(_env(_mix(_noise(int(RATE * 0.5), 160.0, 3), _sine(int(RATE * 0.5), 48.0, 0.9)), 0.003, 0.5, 1.0))
	_streams["chime"] = _wav(_env(_mix(_sine(int(RATE * 0.7), 880.0, 0.5), _sine(int(RATE * 0.7), 1320.0, 0.35)), 0.005, 0.7, 0.8))
	_streams["beep"] = _wav(_env(_sine(int(RATE * 0.12), 940.0, 0.6), 0.004, 0.12, 0.7))
	_streams["warn"] = _wav(_env(_mix(_sine(int(RATE * 0.4), 520.0, 0.5), _sine(int(RATE * 0.4), 390.0, 0.5)), 0.01, 0.4, 0.8))
	_streams["click"] = _wav(_env(_noise(int(RATE * 0.03), 3500.0, 1), 0.001, 0.03, 0.6))
	_streams["zap"] = _wav(_env(_sweep(int(RATE * 0.25), 1400.0, 300.0, 0.6), 0.004, 0.25, 0.7))
	_streams["warp"] = _wav(_env(_mix(_noise(int(RATE * 3.0), 1800.0, 1), _sweep(int(RATE * 3.0), 60.0, 900.0, 0.6)), 0.3, 3.0, 0.9))
	_streams["boom"] = _wav(_env(_mix(_noise(int(RATE * 1.2), 260.0, 3), _sine(int(RATE * 1.2), 40.0, 0.9)), 0.004, 1.2, 1.0))
	_streams["gear"] = _wav(_env(_mix(_noise(int(RATE * 0.7), 500.0, 2), _sine(int(RATE * 0.7), 95.0, 0.6)), 0.05, 0.7, 0.8))
	_streams["scan"] = _wav(_env(_sweep(int(RATE * 1.2), 200.0, 1800.0, 0.5), 0.05, 1.2, 0.7))
	_streams["select"] = _wav(_env(_mix(_sine(int(RATE * 0.18), 660.0, 0.5), _sine(int(RATE * 0.18), 990.0, 0.35)), 0.003, 0.18, 0.7))


func _sine(n: int, f: float, amp: float) -> PackedFloat32Array:
	var o := PackedFloat32Array()
	o.resize(n)
	for i in n:
		o[i] = sin(TAU * f * float(i) / RATE) * amp
	return o


func _sweep(n: int, f0: float, f1: float, amp: float) -> PackedFloat32Array:
	var o := PackedFloat32Array()
	o.resize(n)
	var ph := 0.0
	for i in n:
		var f := lerpf(f0, f1, float(i) / n)
		ph += TAU * f / RATE
		o[i] = sin(ph) * amp
	return o


func _mix(a: PackedFloat32Array, b: PackedFloat32Array) -> PackedFloat32Array:
	var n := maxi(a.size(), b.size())
	var o := PackedFloat32Array()
	o.resize(n)
	for i in n:
		o[i] = (a[i] if i < a.size() else 0.0) * 0.6 + (b[i] if i < b.size() else 0.0) * 0.6
	return o


func _env(src: PackedFloat32Array, attack: float, length: float, gain: float) -> PackedFloat32Array:
	var o := PackedFloat32Array(src)
	var n := o.size()
	for i in n:
		var t := float(i) / RATE
		var e := minf(t / maxf(attack, 0.0001), 1.0) * pow(maxf(1.0 - t / length, 0.0), 2.0)
		o[i] = src[i] * e * gain
	return o


func play(sound: String, volume_db := 0.0, pitch := 1.0) -> void:
	if not _streams.has(sound):
		return
	for p: AudioStreamPlayer in _pool:
		if not p.playing:
			p.stream = _streams[sound]
			p.volume_db = volume_db + linear_to_db(Game.master_volume)
			p.pitch_scale = pitch
			p.play()
			return


func set_loop(name_: String, volume_db: float, pitch := 1.0) -> void:
	var p: AudioStreamPlayer = _loops.get(name_)
	if p == null:
		return
	var v := volume_db + linear_to_db(Game.master_volume)
	if volume_db <= -60.0:
		if p.playing:
			p.stop()
		return
	p.volume_db = v
	p.pitch_scale = clampf(pitch, 0.1, 4.0)
	if not p.playing:
		p.play()
