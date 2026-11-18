class_name RecipesShip
extends RefCounted
## Ship / vehicle / warp / black hole sounds: one-shots and the continuous engine layers. Each recipe returns AudioDSP.pack(...).

const D = preload("res://audio/synth/audio_dsp.gd")
const SR := 22050
const SR_LO := 16000

# ---------------------------------------------------------------------------------------------------------------------------------
# helpers
# ---------------------------------------------------------------------------------------------------------------------------------
## a gentle servo/motor whirr of length n samples: saw through a low-pass, with motor ripple (AM)
static func _servo(n: int, sr: int, f0: float, f1: float, ripple_hz: float, lp: float) -> PackedFloat32Array:
	var s := D.osc(D.ramp_lin(n, f0, f1), sr, 1)
	D.biquad(s, D.F_LP, lp, 0.9, float(sr))
	var w: float = TAU * ripple_hz / float(sr)
	for i in n:
		s[i] *= 0.78 + 0.22 * sin(w * float(i))
	return s

static func _clunk(a: PackedFloat32Array, sr: int, t: float, amp: float, seed: int, f0: float = 120.0) -> void:
	D.add_sweep(a, sr, t, 0.3, f0, f0 * 0.5, amp, 0.06, 0.001)
	D.add_burst(a, sr, t, 0.14, amp * 0.55, 0.02, seed, 0.0, 1600.0, 0.0005)
	D.add_tone(a, sr, t, 0.4, 610.0, amp * 0.13, 0.09, 0.001)
	D.add_tone(a, sr, t, 0.3, 1480.0, amp * 0.08, 0.06, 0.001)

# ---------------------------------------------------------------------------------------------------------------------------------
# gear / landing / crash / launch
# ---------------------------------------------------------------------------------------------------------------------------------
static func gear_down(seed: int) -> Dictionary:
	var sr := SR
	var a := D.make(D.secs(1.9, sr))
	var servo := _servo(D.secs(1.05, sr), sr, 190.0, 238.0, 26.0, 900.0)
	D.env_swell(servo, sr, 0.08, 0.15)
	D.mix(a, servo, 0.5, D.secs(0.05, sr))
	var hiss := D.noise(D.secs(1.0, sr), seed)
	D.band(hiss, 2500.0, 7000.0, float(sr))
	D.env_swell(hiss, sr, 0.1, 0.6)
	D.mix(a, hiss, 0.12, D.secs(0.05, sr))
	_clunk(a, sr, 1.1, 0.9, seed + 1)
	_clunk(a, sr, 1.28, 0.5, seed + 2, 150.0)
	return D.pack(a, sr, 0.8)

static func gear_up(seed: int) -> Dictionary:
	var sr := SR
	var a := D.make(D.secs(1.8, sr))
	D.add_burst(a, sr, 0.0, 0.08, 0.5, 0.012, seed, 1200.0, 0.0, 0.0005)
	D.add_tone(a, sr, 0.0, 0.3, 880.0, 0.1, 0.06, 0.001)
	var servo := _servo(D.secs(1.0, sr), sr, 240.0, 190.0, 26.0, 900.0)
	D.env_swell(servo, sr, 0.08, 0.15)
	D.mix(a, servo, 0.5, D.secs(0.12, sr))
	var hiss := D.noise(D.secs(0.9, sr), seed + 3)
	D.band(hiss, 2500.0, 7000.0, float(sr))
	D.env_swell(hiss, sr, 0.1, 0.5)
	D.mix(a, hiss, 0.1, D.secs(0.12, sr))
	_clunk(a, sr, 1.22, 0.85, seed + 4, 100.0)
	return D.pack(a, sr, 0.8)

static func landed(seed: int) -> Dictionary:
	var sr := SR
	var a := D.make(D.secs(2.2, sr))
	D.add_sweep(a, sr, 0.0, 0.6, 85.0, 38.0, 1.0, 0.14, 0.001)
	D.add_burst(a, sr, 0.0, 0.35, 0.6, 0.06, seed, 0.0, 700.0, 0.001)
	D.add_burst(a, sr, 0.0, 0.3, 0.3, 0.05, seed + 1, 300.0, 2500.0, 0.001)
	D.add_tone(a, sr, 0.0, 1.0, 220.0, 0.1, 0.15, 0.001)
	D.add_tone(a, sr, 0.0, 1.0, 433.0, 0.07, 0.12, 0.001)
	# hydraulic release
	var hiss := D.noise(D.secs(1.5, sr), seed + 2)
	D.band(hiss, 2500.0, 8500.0, float(sr))
	D.env_perc(hiss, sr, 0.05, 0.5)
	D.mix(a, hiss, 0.16, D.secs(0.12, sr))
	# engine spooling down
	D.add_sweep(a, sr, 0.15, 1.2, 700.0, 220.0, 0.06, 0.5, 0.05)
	return D.pack(a, sr, 0.85)

static func crash(seed: int) -> Dictionary:
	var sr := SR
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var a := D.make(D.secs(3.4, sr))
	D.add_sweep(a, sr, 0.0, 1.8, 62.0, 26.0, 1.0, 0.5, 0.001)
	var wh := D.noise(D.secs(1.4, sr), seed)
	var wh2 := D.svf(wh, D.ramp_exp(wh.size(), 6000.0, 200.0), 0.8, D.F_LP, float(sr))
	D.env_perc(wh2, sr, 0.001, 0.35)
	D.mix(a, wh2, 0.9)
	# metal crunch: rapid bursts with ringing resonances
	for k in 9:
		var t: float = rng.randf_range(0.0, 0.55)
		var f: float = rng.randf_range(300.0, 3200.0)
		D.add_burst(a, sr, t, 0.2, rng.randf_range(0.25, 0.6), rng.randf_range(0.015, 0.05), seed + 10 + k, 700.0, 0.0, 0.0005)
		D.add_tone(a, sr, t, 0.5, f, rng.randf_range(0.05, 0.14), rng.randf_range(0.05, 0.16), 0.001)
	# debris rattle: sparse clicks thinning out
	for k in 55:
		var t2: float = 0.3 + 2.8 * pow(rng.randf(), 1.7)
		D.add_burst(a, sr, t2, 0.06, rng.randf_range(0.05, 0.3), rng.randf_range(0.004, 0.02), seed + 100 + k, 1500.0, 7000.0, 0.0003)
	# spark hiss
	var sp := D.noise(D.secs(1.5, sr), seed + 5)
	D.hp1(sp, 4500.0, float(sr))
	D.env_perc(sp, sr, 0.005, 0.45)
	D.mix(a, sp, 0.22, D.secs(0.05, sr))
	D.saturate(a, 1.8)
	return D.pack(a, sr, 0.92)

static func takeoff(seed: int) -> Dictionary:
	var sr := SR
	var n := D.secs(3.4, sr)
	var a := D.make(n)
	var rum := D.brown(n, seed)
	var rum2 := D.svf(rum, D.ramp_exp(n, 90.0, 700.0), 0.9, D.F_LP, float(sr))
	D.env_swell(rum2, sr, 0.35, 1.0)
	D.mix(a, rum2, 0.9)
	var whine := D.make(n)
	D.add_sweep(whine, sr, 0.0, 3.0, 140.0, 820.0, 0.2, 0.0, 0.4, PackedFloat32Array([0.5, 0.25]))
	D.env_swell(whine, sr, 0.5, 1.0)
	D.mix(a, whine, 1.0)
	var roar := D.noise(n, seed + 1)
	D.band(roar, 300.0, 3000.0, float(sr))
	D.env_swell(roar, sr, 0.7, 1.2)
	D.mix(a, roar, 0.25)
	D.add_sweep(a, sr, 0.0, 0.5, 90.0, 45.0, 0.7, 0.12, 0.001)
	D.add_burst(a, sr, 0.0, 0.4, 0.5, 0.1, seed + 2, 0.0, 600.0, 0.002)
	return D.pack(a, sr, 0.8)

static func atmo_enter(seed: int) -> Dictionary:
	# heat-shield roar building up and rolling off: noise through a sweeping resonant filter + crackle
	var sr := SR
	var n := D.secs(3.6, sr)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var nz := D.noise(n, seed)
	var cut := D.ramp_exp(n, 200.0, 1500.0)
	var body := D.svf(nz, cut, 0.9, D.F_BP, float(sr))
	D.env_swell(body, sr, 1.2, 1.8)
	var low := D.brown(n, seed + 1)
	D.lp1(low, 160.0, float(sr))
	D.env_swell(low, sr, 1.0, 1.6)
	var a := D.make(n)
	D.mix(a, body, 0.8)
	D.mix(a, low, 1.2)
	for k in 70:
		var t: float = rng.randf_range(0.8, 3.0)
		D.add_burst(a, sr, t, 0.05, rng.randf_range(0.05, 0.18), rng.randf_range(0.004, 0.012), seed + 30 + k, 1800.0, 6500.0, 0.0003)
	return D.pack(a, sr, 0.75)

static func atmo_leave(seed: int) -> Dictionary:
	var sr := SR
	var n := D.secs(2.4, sr)
	var nz := D.noise(n, seed)
	var a := D.svf(nz, D.ramp_exp(n, 1800.0, 150.0), 0.8, D.F_BP, float(sr))
	D.env_perc(a, sr, 0.1, 0.8)
	var low := D.brown(n, seed + 1)
	D.lp1(low, 120.0, float(sr))
	D.env_perc(low, sr, 0.05, 0.7)
	D.mix(a, low, 0.9)
	return D.pack(a, sr, 0.6)

# ---------------------------------------------------------------------------------------------------------------------------------
# pulse drive / doors / airlock
# ---------------------------------------------------------------------------------------------------------------------------------
static func pulse_on(seed: int) -> Dictionary:
	var sr := SR
	var n := D.secs(2.6, sr)
	var a := D.make(n)
	# charge: two rising tones with growing tremolo
	var nc := D.secs(1.1, sr)
	var ch := D.make(nc)
	D.add_sweep(ch, sr, 0.0, 1.1, 160.0, 1500.0, 0.35, 0.0, 0.05, PackedFloat32Array([0.3]), 0.003)
	D.add_sweep(ch, sr, 0.0, 1.1, 240.0, 2250.0, 0.15, 0.0, 0.05, PackedFloat32Array(), 0.003)
	var trem := D.ramp_exp(nc, 8.0, 60.0)
	var ph := 0.0
	for i in nc:
		ph += trem[i] / float(sr)
		var g: float = float(i) / float(nc)
		ch[i] *= (0.65 + 0.35 * sin(ph * TAU)) * (0.2 + 0.8 * g)
	D.mix(a, ch, 1.0)
	var sh := D.noise(nc, seed)
	D.hp1(sh, 3000.0, float(sr))
	D.env_swell(sh, sr, 1.0, 0.02)
	D.mix(a, sh, 0.08)
	# release: boom + whoosh
	var t0 := 1.1
	D.add_sweep(a, sr, t0, 1.4, 75.0, 30.0, 0.95, 0.28, 0.002)
	var wn := D.noise(D.secs(1.0, sr), seed + 1)
	var wh := D.svf(wn, D.ramp_exp(wn.size(), 5000.0, 280.0), 0.9, D.F_BP, float(sr))
	D.env_perc(wh, sr, 0.005, 0.26)
	D.mix(a, wh, 0.55, D.secs(t0, sr))
	D.add_note(a, sr, t0, 440.0, 0.12, 0.4, 0)
	D.add_note(a, sr, t0, 660.0, 0.08, 0.35, 0)
	return D.pack(a, sr, 0.85)

static func pulse_off(seed: int) -> Dictionary:
	var sr := SR
	var n := D.secs(1.6, sr)
	var a := D.make(n)
	D.add_sweep(a, sr, 0.0, 0.6, 100.0, 40.0, 0.65, 0.12, 0.001)
	D.add_sweep(a, sr, 0.0, 1.2, 1100.0, 90.0, 0.3, 0.35, 0.004, PackedFloat32Array([0.25]))
	var nz := D.noise(D.secs(1.2, sr), seed)
	var wh := D.svf(nz, D.ramp_exp(nz.size(), 2500.0, 200.0), 0.9, D.F_BP, float(sr))
	D.env_perc(wh, sr, 0.004, 0.3)
	D.mix(a, wh, 0.35)
	return D.pack(a, sr, 0.75)

static func airlock(seed: int) -> Dictionary:
	var sr := SR
	var a := D.make(D.secs(2.4, sr))
	D.add_burst(a, sr, 0.0, 0.06, 0.6, 0.01, seed, 900.0, 0.0, 0.0004)
	D.add_tone(a, sr, 0.0, 0.3, 1250.0, 0.12, 0.03, 0.001)
	D.add_burst(a, sr, 0.12, 0.05, 0.35, 0.008, seed + 1, 900.0, 0.0, 0.0004)
	var hiss := D.noise(D.secs(1.7, sr), seed + 2)
	D.biquad(hiss, D.F_BP, 5500.0, 0.9, float(sr))
	D.env_perc(hiss, sr, 0.05, 0.55)
	D.mix(a, hiss, 1.1, D.secs(0.2, sr))
	var low := D.noise(D.secs(1.5, sr), seed + 3)
	D.lp1(low, 700.0, float(sr))
	D.env_perc(low, sr, 0.08, 0.45)
	D.mix(a, low, 0.18, D.secs(0.2, sr))
	var servo := _servo(D.secs(0.8, sr), sr, 150.0, 110.0, 18.0, 700.0)
	D.env_swell(servo, sr, 0.1, 0.2)
	D.mix(a, servo, 0.22, D.secs(1.0, sr))
	_clunk(a, sr, 1.85, 0.6, seed + 4, 100.0)
	return D.pack(a, sr, 0.8)

static func door(seed: int) -> Dictionary:
	var sr := SR
	var a := D.make(D.secs(1.0, sr))
	var nz := D.noise(D.secs(0.7, sr), seed)
	var sl := D.svf(nz, D.ramp_exp(nz.size(), 500.0, 2400.0), 0.8, D.F_BP, float(sr))
	D.env_swell(sl, sr, 0.1, 0.3)
	D.mix(a, sl, 0.35)
	var servo := _servo(D.secs(0.65, sr), sr, 160.0, 175.0, 20.0, 800.0)
	D.env_swell(servo, sr, 0.08, 0.15)
	D.mix(a, servo, 0.22)
	D.add_burst(a, sr, 0.7, 0.08, 0.5, 0.01, seed + 1, 1500.0, 0.0, 0.0004)
	D.add_sweep(a, sr, 0.7, 0.2, 130.0, 80.0, 0.4, 0.04, 0.001)
	return D.pack(a, sr, 0.7)

# ---------------------------------------------------------------------------------------------------------------------------------
# warp / black hole
# ---------------------------------------------------------------------------------------------------------------------------------
static func warp_charge(seed: int) -> Dictionary:
	var sr := SR
	var T := 2.4
	var n := D.secs(T, sr)
	var a := D.make(n)
	var f := D.ramp_exp(n, 50.0, 200.0)
	var saws := D.osc(f, sr, 1)
	var f2 := D.ramp_exp(n, 50.0 * 1.006, 200.0 * 1.006)
	var s2 := D.osc(f2, sr, 1, 0.31)
	var f3 := D.ramp_exp(n, 50.0 * 0.994, 200.0 * 0.994)
	var s3 := D.osc(f3, sr, 1, 0.62)
	D.mix(saws, s2, 1.0)
	D.mix(saws, s3, 1.0)
	var st := D.svf(saws, D.ramp_exp(n, 120.0, 7000.0), 2.5, D.F_LP, float(sr))
	D.mix(a, st, 0.28)
	D.add_sweep(a, sr, 0.0, T, 220.0, 2400.0, 0.1, 0.0, 0.2, PackedFloat32Array([0.4]), 0.02)
	var nz := D.noise(n, seed)
	D.band(nz, 1500.0, 9000.0, float(sr))
	for i in n:
		var g: float = float(i) / float(n)
		nz[i] *= g * g
	D.mix(a, nz, 0.2)
	D.add_sweep(a, sr, 0.0, T, 45.0, 95.0, 0.35, 0.0, 0.4)
	# overall build-up
	for i in n:
		var g2: float = float(i) / float(n)
		a[i] *= 0.15 + 0.85 * pow(g2, 1.3)
	return D.pack(a, sr, 0.8)

static func warp_jump(seed: int) -> Dictionary:
	var sr := SR
	var n := D.secs(3.0, sr)
	var a := D.make(n)
	# suck-in
	var pre := D.noise(D.secs(0.3, sr), seed)
	var pw := D.svf(pre, D.ramp_exp(pre.size(), 400.0, 7000.0), 1.0, D.F_BP, float(sr))
	for i in pw.size():
		var g: float = float(i) / float(pw.size())
		pw[i] *= g * g
	D.mix(a, pw, 0.5)
	D.add_sweep(a, sr, 0.0, 0.3, 300.0, 3000.0, 0.22, 0.0, 0.05, PackedFloat32Array(), 0.01)
	var t0 := 0.3
	# boom
	D.add_sweep(a, sr, t0, 2.2, 90.0, 24.0, 1.0, 0.55, 0.002)
	var ex := D.noise(D.secs(1.6, sr), seed + 1)
	var ex2 := D.svf(ex, D.ramp_exp(ex.size(), 7000.0, 250.0), 0.8, D.F_LP, float(sr))
	D.env_perc(ex2, sr, 0.002, 0.38)
	D.mix(a, ex2, 0.95, D.secs(t0, sr))
	D.add_burst(a, sr, t0, 0.8, 0.25, 0.15, seed + 2, 3000.0, 0.0, 0.001)
	# shimmer + rumble tail
	D.add_note(a, sr, t0 + 0.05, 880.0, 0.12, 0.8, 0)
	D.add_note(a, sr, t0 + 0.05, 1320.0, 0.08, 0.7, 0)
	D.add_note(a, sr, t0 + 0.05, 1760.0, 0.06, 0.6, 0)
	var rum := D.brown(D.secs(2.4, sr), seed + 3)
	D.lp1(rum, 200.0, float(sr))
	D.env_perc(rum, sr, 0.01, 0.9)
	D.mix(a, rum, 0.8, D.secs(t0, sr))
	D.saturate(a, 1.6)
	return D.pack(a, sr, 0.9)

static func warp_arrive(seed: int) -> Dictionary:
	var sr := SR
	var n := D.secs(2.4, sr)
	var a := D.make(n)
	var nz := D.noise(n, seed)
	var wh := D.svf(nz, D.ramp_exp(n, 7000.0, 250.0), 0.9, D.F_BP, float(sr))
	D.env_perc(wh, sr, 0.05, 0.55)
	D.mix(a, wh, 0.55)
	D.add_sweep(a, sr, 0.1, 1.6, 70.0, 30.0, 0.5, 0.3, 0.01)
	D.add_note(a, sr, 0.15, 660.0, 0.1, 0.6, 0)
	D.add_note(a, sr, 0.15, 990.0, 0.07, 0.5, 0)
	return D.pack(a, sr, 0.75)

static func warp_tunnel(seed: int) -> Dictionary:
	# 4 s seamless stereo rush: filtered noise with slow sweeps + low hum + shimmer
	var sr := SR
	var T := 4.0
	var xf := D.secs(0.5, sr)
	var n := D.secs(T, sr)
	var chans: Array = []
	for c in 2:
		var tot := n + xf
		var nz := D.noise(tot, seed + c * 17)
		var cut := D.make(tot)
		var w: float = TAU / T
		for i in tot:
			var t: float = float(i) / float(sr)
			cut[i] = 900.0 + 520.0 * sin(w * 2.0 * t + float(c) * 1.3)
		var body := D.svf(nz, cut, 0.9, D.F_BP, float(sr))
		var hi := D.noise(tot, seed + 40 + c)
		D.hp1(hi, 4000.0, float(sr))
		for i in tot:
			var t2: float = float(i) / float(sr)
			hi[i] *= 0.5 + 0.5 * sin(w * t2 + float(c) * 2.0)
		D.mix(body, hi, 0.18)
		var lo := D.loopify(body, xf)
		# periodic tonal parts (exact integer cycles in T)
		var f1: float = D.snap(62.0, T)
		var f2: float = D.snap(93.0, T)
		var f3: float = D.snap(1500.0, T)
		var vib: float = 5.0
		for i in n:
			var t3: float = float(i) / float(sr)
			var v: float = 0.34 * sin(TAU * f1 * t3 + float(c) * 0.7) + 0.15 * sin(TAU * f2 * t3)
			v += 0.035 * sin(TAU * f3 * t3 + 3.0 * sin(TAU * vib * t3))
			lo[i] = lo[i] * 0.9 + v
		chans.append(lo)
	return D.pack(chans[0], sr, 0.75, true, chans[1])

static func blackhole_enter(seed: int) -> Dictionary:
	var sr := SR
	var n := D.secs(6.0, sr)
	var a := D.make(n)
	# sub drop
	D.add_sweep(a, sr, 0.0, 5.4, 90.0, 16.0, 0.9, 0.0, 0.3)
	# falling saw cluster, filter closing
	var f := D.ramp_exp(D.secs(5.0, sr), 420.0, 38.0)
	var s1 := D.osc(f, sr, 1)
	var s2 := D.osc(D.ramp_exp(f.size(), 420.0 * 1.012, 38.0 * 1.012), sr, 1, 0.4)
	var s3 := D.osc(D.ramp_exp(f.size(), 420.0 * 0.988, 38.0 * 0.988), sr, 1, 0.7)
	D.mix(s1, s2, 1.0)
	D.mix(s1, s3, 1.0)
	var pad := D.svf(s1, D.ramp_exp(f.size(), 3000.0, 80.0), 1.5, D.F_LP, float(sr))
	D.env_swell(pad, sr, 0.4, 1.2)
	D.mix(a, pad, 0.3)
	# reversed-cymbal swell
	var nz := D.noise(D.secs(2.7, sr), seed)
	D.band(nz, 800.0, 9000.0, float(sr))
	for i in nz.size():
		var g: float = float(i) / float(nz.size())
		nz[i] *= g * g * g
	D.mix(a, nz, 0.4)
	# the tear
	var t0 := 2.7
	D.add_burst(a, sr, t0, 1.2, 0.8, 0.28, seed + 1, 0.0, 5000.0, 0.002)
	D.add_sweep(a, sr, t0, 3.0, 60.0, 20.0, 1.0, 0.7, 0.003)
	D.add_tone(a, sr, 0.6, 5.0, 311.0, 0.05, 2.0, 1.2)
	D.add_tone(a, sr, 0.6, 5.0, 330.0, 0.05, 2.0, 1.2)
	D.saturate(a, 1.35)
	D.env_swell(a, sr, 0.05, 1.6)
	return D.pack(a, sr, 0.85)

static func blackhole_rumble(seed: int) -> Dictionary:
	var sr := SR_LO
	var T := 6.0
	var xf := D.secs(0.8, sr)
	var n := D.secs(T, sr)
	var tot := n + xf
	var br := D.brown(tot, seed)
	D.lp1(br, 90.0, float(sr))
	var gust := D.wander(tot, sr, 0.35, seed + 1)
	for i in tot:
		br[i] *= 0.4 + 0.6 * gust[i]
	var lo := D.loopify(br, xf)
	D.normalize(lo, 0.55)
	var f1: float = D.snap(27.0, T)
	var f2: float = D.snap(41.0, T)
	var f3: float = D.snap(54.5, T)
	var f4: float = D.snap(110.0, T)
	for i in n:
		var t: float = float(i) / float(sr)
		var trem: float = 0.75 + 0.25 * sin(TAU * t / T * 2.0)
		var v: float = 0.5 * sin(TAU * f1 * t) + 0.3 * sin(TAU * f2 * t + 1.1) + 0.2 * sin(TAU * f3 * t + 2.0)
		v *= trem
		# eerie detuned choir
		var sw: float = 0.5 + 0.5 * sin(TAU * t / T)
		v += 0.06 * sw * (sin(TAU * f4 * t) + sin(TAU * (f4 + 1.0 / T) * t + 1.0) + sin(TAU * f4 * 1.5 * t + 2.0))
		# slow groan
		v += 0.1 * sin(TAU * (62.0 * t + 8.0 * T / TAU * (1.0 - cos(TAU * t / T))))
		lo[i] = lo[i] + v
	return D.pack(lo, sr, 0.8, true)

static func alarm(seed: int) -> Dictionary:
	# 1.6 s klaxon loop: two alternating tones, twice
	var sr := SR
	var a := D.make(D.secs(1.6, sr))
	var odd := PackedFloat32Array([0.0, 0.4, 0.0, 0.25, 0.0, 0.15, 0.0, 0.1])
	for k in 4:
		var f: float = 780.0 if k % 2 == 0 else 620.0
		D.add_sweep(a, sr, 0.4 * float(k), 0.36, f, f, 0.5, 0.0, 0.01, odd, 0.02)
	D.lp1(a, 3800.0, float(sr))
	return D.pack(a, sr, 0.7, true)

static func warn_beep(seed: int) -> Dictionary:
	var sr := SR
	var a := D.make(D.secs(0.42, sr))
	var odd := PackedFloat32Array([0.0, 0.33, 0.0, 0.2, 0.0, 0.14])
	D.add_sweep(a, sr, 0.0, 0.12, 880.0, 880.0, 0.5, 0.0, 0.004, odd)
	D.add_sweep(a, sr, 0.18, 0.12, 880.0, 880.0, 0.5, 0.0, 0.004, odd)
	D.lp1(a, 3600.0, float(sr))
	return D.pack(a, sr, 0.6)

static func scan_ping(seed: int) -> Dictionary:
	var sr := SR
	var n := D.secs(2.8, sr)
	var a := D.make(n)
	# expanding sweep
	var nz := D.noise(D.secs(0.5, sr), seed)
	var sw := D.svf(nz, D.ramp_exp(nz.size(), 300.0, 3500.0), 3.0, D.F_BP, float(sr))
	D.env_swell(sw, sr, 0.25, 0.2)
	D.mix(a, sw, 0.3)
	D.add_sweep(a, sr, 0.0, 0.4, 250.0, 1200.0, 0.12, 0.0, 0.05, PackedFloat32Array(), 0.1)
	# the ping itself (only the ping gets echoes, the sweep stays single)
	var ping := D.make(n)
	var t0 := 0.32
	D.add_sweep(ping, sr, t0, 1.6, 1500.0, 1470.0, 0.55, 0.45, 0.003)
	D.add_tone(ping, sr, t0, 1.2, 2960.0, 0.15, 0.25, 0.003)
	D.add_sweep(ping, sr, t0, 0.5, 90.0, 60.0, 0.4, 0.12, 0.002)
	var e := D.echo(ping, sr, [0.3, 0.62, 0.98], [0.42, 0.22, 0.1], 0.2)
	for i in a.size():
		e[i] += a[i]
	var r := D.reverb(e, sr, 1.0, 0.2, 0.4)
	return D.pack(r, sr, 0.7)
