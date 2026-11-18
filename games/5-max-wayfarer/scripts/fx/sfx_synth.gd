class_name SfxSynth
extends RefCounted
## Procedural sound synthesis (no audio files are shipped): every effect is generated at start-up into AudioStreamWAV.

const SR: int = 22050
static var _rng := RandomNumberGenerator.new()

static func _stream(s: PackedFloat32Array, looped: bool) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(s.size() * 2)
	for i in s.size():
		bytes.encode_s16(i * 2, int(clampf(s[i], -1.0, 1.0) * 30000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = SR
	w.stereo = false
	w.data = bytes
	if looped:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = s.size()
	return w

static func _noise(n: int) -> PackedFloat32Array:
	var a := PackedFloat32Array()
	a.resize(n)
	for i in n:
		a[i] = _rng.randf() * 2.0 - 1.0
	return a

static func _lp(x: PackedFloat32Array, alpha: float) -> PackedFloat32Array:
	var y := PackedFloat32Array()
	y.resize(x.size())
	var s: float = 0.0
	for i in x.size():
		s += alpha * (x[i] - s)
		y[i] = s
	return y

static func _saw(p: float) -> float:
	return 2.0 * (p - floorf(p + 0.5))

## make a buffer loop seamlessly: crossfade the tail into the head
static func _make_loop(x: PackedFloat32Array, fade: int) -> PackedFloat32Array:
	var n: int = x.size() - fade
	var y := PackedFloat32Array()
	y.resize(n)
	for i in n:
		y[i] = x[i]
	for i in fade:
		var k: float = float(i) / float(fade)
		y[i] = x[n + i] * (1.0 - k) + x[i] * k
	return y

static func _norm(x: PackedFloat32Array, peak: float) -> PackedFloat32Array:
	var m: float = 0.0001
	for v in x:
		m = maxf(m, absf(v))
	var g: float = peak / m
	for i in x.size():
		x[i] *= g
	return x

# --------------------------------------------------------------------------------------------- loops
static func engine_loop() -> AudioStreamWAV:
	var n: int = SR * 2
	var nz: PackedFloat32Array = _lp(_noise(n), 0.08)
	var y := PackedFloat32Array()
	y.resize(n)
	for i in n:
		var t: float = float(i) / SR
		var v: float = 0.34 * _saw(55.0 * t) + 0.28 * sin(TAU * 27.5 * t) + 0.16 * sin(TAU * 110.0 * t + 0.6 * sin(TAU * 2.0 * t)) + 0.5 * nz[i]
		y[i] = tanh(v * 1.4) * 0.55
	return _stream(_norm(y, 0.7), true)

static func pulse_loop() -> AudioStreamWAV:
	var n: int = SR
	var nz: PackedFloat32Array = _lp(_noise(n), 0.2)
	var y := PackedFloat32Array()
	y.resize(n)
	for i in n:
		var t: float = float(i) / SR
		var lfo: float = 0.75 + 0.25 * sin(TAU * 8.0 * t)
		var v: float = 0.4 * sin(TAU * 180.0 * t) + 0.25 * sin(TAU * 361.0 * t) + 0.15 * sin(TAU * 541.0 * t) + 0.35 * nz[i]
		y[i] = v * lfo
	return _stream(_norm(y, 0.6), true)

static func wind_loop() -> AudioStreamWAV:
	var n: int = SR * 5
	var raw: PackedFloat32Array = _lp(_noise(n + SR), 0.06)
	var y := PackedFloat32Array()
	y.resize(n + SR)
	for i in n + SR:
		var t: float = float(i) / SR
		y[i] = raw[i] * (0.65 + 0.35 * sin(TAU * 0.4 * t) * sin(TAU * 0.27 * t + 1.0))
	return _stream(_norm(_make_loop(y, SR), 0.6), true)

static func rain_loop() -> AudioStreamWAV:
	var n: int = SR * 3
	var a: PackedFloat32Array = _noise(n + SR)
	var b: PackedFloat32Array = _lp(a, 0.25)
	var y := PackedFloat32Array()
	y.resize(n + SR)
	for i in n + SR:
		y[i] = (a[i] - b[i]) * 0.6
	return _stream(_norm(_make_loop(y, SR), 0.5), true)

static func rumble_loop() -> AudioStreamWAV:
	var n: int = SR * 4
	var nz: PackedFloat32Array = _lp(_noise(n), 0.015)
	var y := PackedFloat32Array()
	y.resize(n)
	for i in n:
		var t: float = float(i) / SR
		y[i] = 0.5 * sin(TAU * 29.0 * t) + 0.3 * sin(TAU * 43.0 * t + 1.0) + 0.2 * sin(TAU * 61.0 * t) + 2.5 * nz[i]
	return _stream(_norm(y, 0.8), true)

static func alarm_loop() -> AudioStreamWAV:
	var n: int = int(SR * 1.2)
	var y := PackedFloat32Array()
	y.resize(n)
	var ph: float = 0.0
	for i in n:
		var t: float = float(i) / float(SR)
		var f: float = 620.0 + 380.0 * (0.5 + 0.5 * sin(TAU * t / 1.2 - PI * 0.5))
		ph += f / SR
		var sq: float = 1.0 if fposmod(ph, 1.0) < 0.5 else -1.0
		y[i] = (sq * 0.5 + sin(TAU * ph) * 0.5) * 0.5
	return _stream(y, true)

static func jet_loop() -> AudioStreamWAV:
	var n: int = SR * 2
	var a: PackedFloat32Array = _noise(n)
	var l1: PackedFloat32Array = _lp(a, 0.35)
	var l2: PackedFloat32Array = _lp(a, 0.05)
	var y := PackedFloat32Array()
	y.resize(n)
	for i in n:
		var t: float = float(i) / SR
		y[i] = (l1[i] - l2[i]) * 1.4 + 0.25 * sin(TAU * 86.0 * t) + 0.5 * l2[i]
	return _stream(_norm(y, 0.55), true)

# --------------------------------------------------------------------------------------------- one-shots
static func footstep(kind: int) -> AudioStreamWAV:
	var n: int = int(SR * 0.16)
	var nz: PackedFloat32Array = _noise(n)
	var alpha: float = [0.18, 0.5, 0.1, 0.3][kind % 4]       # grass / sand / snow / rock
	nz = _lp(nz, alpha)
	var y := PackedFloat32Array()
	y.resize(n)
	for i in n:
		var t: float = float(i) / SR
		var env: float = exp(-t * (38.0 if kind != 3 else 55.0))
		y[i] = (nz[i] * 1.6 + 0.5 * sin(TAU * 95.0 * t) * exp(-t * 50.0)) * env
	return _stream(_norm(y, 0.7), false)

static func thud() -> AudioStreamWAV:
	var n: int = int(SR * 0.6)
	var nz: PackedFloat32Array = _lp(_noise(n), 0.1)
	var y := PackedFloat32Array()
	y.resize(n)
	for i in n:
		var t: float = float(i) / SR
		y[i] = sin(TAU * 52.0 * t) * exp(-t * 7.0) + nz[i] * 1.5 * exp(-t * 11.0)
	return _stream(_norm(y, 0.9), false)

static func servo() -> AudioStreamWAV:
	var n: int = int(SR * 0.9)
	var y := PackedFloat32Array()
	y.resize(n)
	var ph: float = 0.0
	for i in n:
		var t: float = float(i) / SR
		var f: float = 260.0 + 160.0 * t + 14.0 * sin(TAU * 18.0 * t)
		ph += f / SR
		y[i] = (sin(TAU * ph) * 0.4 + _saw(ph * 0.5) * 0.15) * clampf(t * 12.0, 0.0, 1.0) * clampf((0.9 - t) * 8.0, 0.0, 1.0)
	return _stream(_norm(y, 0.5), false)

static func click(f: float = 1700.0, dur: float = 0.06) -> AudioStreamWAV:
	var n: int = int(SR * dur)
	var y := PackedFloat32Array()
	y.resize(n)
	for i in n:
		var t: float = float(i) / SR
		y[i] = sin(TAU * f * t) * exp(-t * (dur * 600.0))
	return _stream(_norm(y, 0.5), false)

static func beep() -> AudioStreamWAV:
	var n: int = int(SR * 0.36)
	var y := PackedFloat32Array()
	y.resize(n)
	for i in n:
		var t: float = float(i) / SR
		var on: float = 1.0 if (t < 0.14 or (t > 0.2 and t < 0.34)) else 0.0
		y[i] = (1.0 if fposmod(880.0 * t, 1.0) < 0.5 else -1.0) * 0.3 * on
	return _stream(y, false)

static func sweep_up(dur: float, f0: float, f1: float, noisy: float) -> AudioStreamWAV:
	var n: int = int(SR * dur)
	var nz: PackedFloat32Array = _lp(_noise(n), 0.25)
	var y := PackedFloat32Array()
	y.resize(n)
	var ph: float = 0.0
	for i in n:
		var t: float = float(i) / float(n)
		var f: float = f0 * pow(f1 / f0, t * t)
		ph += f / SR
		var env: float = sin(PI * clampf(t, 0.0, 1.0)) * (0.4 + 0.6 * t)
		y[i] = (sin(TAU * ph) * 0.5 + nz[i] * noisy) * env
	return _stream(_norm(y, 0.7), false)

static func ping() -> AudioStreamWAV:
	var n: int = int(SR * 1.4)
	var y := PackedFloat32Array()
	y.resize(n)
	for i in n:
		var t: float = float(i) / SR
		var f: float = 1900.0 - 700.0 * minf(t * 3.0, 1.0)
		var v: float = sin(TAU * f * t) * exp(-t * 3.2) + 0.4 * sin(TAU * f * 2.0 * t) * exp(-t * 5.0)
		var echo: float = 0.0
		if t > 0.22:
			echo = 0.35 * sin(TAU * (1900.0 - 700.0 * minf((t - 0.22) * 3.0, 1.0)) * (t - 0.22)) * exp(-(t - 0.22) * 4.0)
		y[i] = v + echo
	return _stream(_norm(y, 0.6), false)

static func chime() -> AudioStreamWAV:
	var n: int = int(SR * 2.0)
	var y := PackedFloat32Array()
	y.resize(n)
	var freqs := [523.25, 659.25, 783.99, 1046.5]
	for i in n:
		var t: float = float(i) / SR
		var v: float = 0.0
		for k in freqs.size():
			var st: float = 0.12 * k
			if t > st:
				v += sin(TAU * float(freqs[k]) * (t - st)) * exp(-(t - st) * 2.2) * 0.3
		y[i] = v
	return _stream(_norm(y, 0.6), false)

static func pickup() -> AudioStreamWAV:
	var n: int = int(SR * 0.4)
	var y := PackedFloat32Array()
	y.resize(n)
	var freqs := [659.25, 880.0, 1174.7]
	for i in n:
		var t: float = float(i) / SR
		var v: float = 0.0
		for k in freqs.size():
			var st: float = 0.07 * k
			if t > st:
				v += sin(TAU * float(freqs[k]) * (t - st)) * exp(-(t - st) * 9.0) * 0.4
		y[i] = v
	return _stream(_norm(y, 0.6), false)

static func boom() -> AudioStreamWAV:
	var n: int = int(SR * 1.6)
	var nz: PackedFloat32Array = _lp(_noise(n), 0.08)
	var y := PackedFloat32Array()
	y.resize(n)
	for i in n:
		var t: float = float(i) / SR
		y[i] = nz[i] * 3.0 * exp(-t * 2.6) + sin(TAU * 38.0 * t) * exp(-t * 2.0)
	return _stream(_norm(y, 0.9), false)

static func build_all() -> Dictionary:
	_rng.seed = 424242
	var d: Dictionary = {}
	d["engine"] = engine_loop()
	d["pulse"] = pulse_loop()
	d["wind"] = wind_loop()
	d["rain"] = rain_loop()
	d["rumble"] = rumble_loop()
	d["alarm"] = alarm_loop()
	d["jet"] = jet_loop()
	for k in 4:
		d["step%d" % k] = footstep(k)
	d["thud"] = thud()
	d["servo"] = servo()
	d["click"] = click()
	d["hover"] = click(2400.0, 0.03)
	d["beep"] = beep()
	d["pulse_on"] = sweep_up(1.1, 140.0, 1000.0, 0.5)
	d["warp"] = sweep_up(1.8, 90.0, 1500.0, 0.8)
	d["ping"] = ping()
	d["chime"] = chime()
	d["pickup"] = pickup()
	d["boom"] = boom()
	return d
