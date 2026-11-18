class_name RecipesWorld
extends RefCounted
## On-foot sounds (footsteps per surface, jump / landing / jetpack puff), creature & ambience one-shots, and the planet ambience loops.

const D = preload("res://audio/synth/audio_dsp.gd")
const SR := 22050
const SR_LO := 11025

# =================================================================================================================================
# suit / body
# =================================================================================================================================
static func jump(seed: int) -> Dictionary:
	var sr := SR
	var n := D.secs(0.45, sr)
	var a := D.make(n)
	var nz := D.noise(n, seed)
	var b := D.svf(nz, D.ramp_exp(n, 400.0, 1700.0), 0.9, D.F_BP, float(sr))
	D.env_swell(b, sr, 0.05, 0.22)
	D.mix(a, b, 0.4)
	D.add_sweep(a, sr, 0.0, 0.2, 130.0, 70.0, 0.4, 0.045, 0.002)
	D.add_burst(a, sr, 0.0, 0.2, 0.08, 0.08, seed + 1, 2500.0, 0.0, 0.01)
	return D.pack(a, sr, 0.6)

static func land_foot(seed: int) -> Dictionary:
	var sr := SR
	var a := D.make(D.secs(0.45, sr))
	D.add_sweep(a, sr, 0.0, 0.3, 95.0, 45.0, 0.9, 0.07, 0.001)
	D.add_burst(a, sr, 0.0, 0.2, 0.5, 0.04, seed, 0.0, 1500.0, 0.0008)
	D.add_burst(a, sr, 0.0, 0.15, 0.15, 0.03, seed + 1, 1800.0, 0.0, 0.001)
	D.add_tone(a, sr, 0.0, 0.25, 420.0, 0.05, 0.06, 0.001)
	return D.pack(a, sr, 0.75)

static func jetpack_puff(seed: int) -> Dictionary:
	var sr := SR
	var n := D.secs(0.5, sr)
	var a := D.noise(n, seed)
	D.band(a, 200.0, 6000.0, float(sr))
	D.env_perc(a, sr, 0.02, 0.12)
	var low := D.noise(n, seed + 1)
	D.lp1(low, 220.0, float(sr))
	D.env_perc(low, sr, 0.01, 0.15)
	D.mix(a, low, 0.7)
	return D.pack(a, sr, 0.55)

static func hurt(seed: int) -> Dictionary:
	var sr := SR
	var a := D.make(D.secs(0.5, sr))
	D.add_sweep(a, sr, 0.0, 0.25, 110.0, 55.0, 0.8, 0.08, 0.001)
	D.add_burst(a, sr, 0.0, 0.15, 0.5, 0.03, seed, 300.0, 3000.0, 0.0005)
	var odd := PackedFloat32Array([0.0, 0.4, 0.0, 0.2])
	D.add_sweep(a, sr, 0.03, 0.2, 330.0, 280.0, 0.3, 0.07, 0.002, odd)
	D.lp1(a, 3000.0, float(sr))
	return D.pack(a, sr, 0.7)

static func death(seed: int) -> Dictionary:
	var sr := SR
	var n := D.secs(2.2, sr)
	var a := D.make(n)
	D.add_sweep(a, sr, 0.0, 2.0, 220.0, 38.0, 0.7, 0.8, 0.005, PackedFloat32Array([0.3]))
	var nz := D.noise(n, seed)
	var st := D.svf(nz, D.ramp_exp(n, 6000.0, 300.0), 1.0, D.F_BP, float(sr))
	D.env_perc(st, sr, 0.005, 0.6)
	D.mix(a, st, 0.5)
	D.add_sweep(a, sr, 0.0, 0.5, 70.0, 35.0, 0.9, 0.15, 0.001)
	return D.pack(a, sr, 0.8)

# =================================================================================================================================
# footsteps
# =================================================================================================================================
const SURFACES := ["grass", "sand", "rock", "snow", "metal", "ash", "mud", "splash"]

## surface aliases -> canonical sample set
static func surface_alias(s: String) -> String:
	match s:
		"grass", "sand", "rock", "snow", "metal", "ash", "mud", "splash":
			return s
		"dirt", "soil", "leaves", "forest", "moss", "plant", "flora", "fern":
			return "grass"
		"dust", "regolith", "moon", "powder", "dune":
			return "ash" if s != "dune" else "sand"
		"gravel", "stone", "basalt", "lava", "sandstone", "wood", "crystal", "rubble":
			return "rock"
		"ice", "frost", "frozen":
			return "snow"
		"pad", "structure", "concrete", "ship", "hull", "floor", "deck":
			return "metal"
		"fungus", "swamp", "bog", "acid", "slime", "spore":
			return "mud"
		"water", "shallow", "ocean", "wade":
			return "splash"
	return "rock"

static func step(surface: String, variant: int, seed: int) -> Dictionary:
	var sr := SR
	var rng := RandomNumberGenerator.new()
	rng.seed = seed + variant * 7919
	var a := D.make(D.secs(0.34, sr))
	var j: float = 1.0 + rng.randf_range(-0.08, 0.08)
	match surface:
		"grass":
			var nz := D.noise(a.size(), seed + variant)
			D.band(nz, 900.0 * j, 4500.0 * j, float(sr))
			D.env_perc(nz, sr, 0.008, 0.05)
			D.mix(a, nz, 0.55)
			D.add_burst(a, sr, 0.0, 0.25, 0.1, 0.08, seed + variant + 50, 5000.0, 0.0, 0.01)
			D.add_sweep(a, sr, 0.0, 0.15, 110.0 * j, 70.0, 0.4, 0.035, 0.002)
		"sand":
			D.add_burst(a, sr, 0.0, 0.3, 0.6, 0.09, seed + variant, 300.0, 2600.0 * j, 0.015)
			for k in 10:
				D.add_burst(a, sr, rng.randf_range(0.0, 0.14), 0.02, rng.randf_range(0.03, 0.09), 0.004, seed + variant * 31 + k, 3000.0, 0.0, 0.0003)
			D.add_sweep(a, sr, 0.0, 0.15, 90.0, 60.0, 0.25, 0.04, 0.003)
		"rock":
			D.add_burst(a, sr, 0.0, 0.05, 0.6, 0.008, seed + variant, 1500.0, 0.0, 0.0003)
			D.add_sweep(a, sr, 0.0, 0.15, 520.0 * j, 400.0 * j, 0.3, 0.022, 0.001)
			D.add_tone(a, sr, 0.0, 0.1, 900.0 * j, 0.14, 0.015, 0.001)
			D.add_sweep(a, sr, 0.0, 0.12, 100.0, 60.0, 0.32, 0.04, 0.001)
			D.add_burst(a, sr, 0.0, 0.15, 0.14, 0.04, seed + variant + 9, 2000.0, 6000.0, 0.001)
		"snow":
			for k in 18:
				var t: float = pow(rng.randf(), 1.5) * 0.17
				D.add_burst(a, sr, t, 0.04, rng.randf_range(0.12, 0.35), rng.randf_range(0.006, 0.014), seed + variant * 17 + k, 1800.0, 0.0, 0.0005)
			D.add_sweep(a, sr, 0.0, 0.15, 90.0, 60.0, 0.3, 0.05, 0.003)
			D.add_burst(a, sr, 0.0, 0.2, 0.2, 0.08, seed + variant + 3, 0.0, 600.0, 0.008)
		"metal":
			D.add_sweep(a, sr, 0.0, 0.15, 120.0, 70.0, 0.4, 0.04, 0.001)
			var fr: Array = [610.0, 1180.0, 2090.0, 3320.0, 4710.0]
			var am: Array = [0.2, 0.25, 0.18, 0.1, 0.06]
			var tc: Array = [0.12, 0.09, 0.07, 0.05, 0.04]
			for k in fr.size():
				D.add_tone(a, sr, 0.0, 0.34, float(fr[k]) * j * rng.randf_range(0.99, 1.01), float(am[k]), float(tc[k]), 0.001)
			D.add_burst(a, sr, 0.0, 0.05, 0.2, 0.01, seed + variant, 2000.0, 0.0, 0.0003)
		"ash":
			var nz2 := D.noise(a.size(), seed + variant)
			D.band(nz2, 150.0, 1800.0 * j, float(sr))
			D.env_perc(nz2, sr, 0.02, 0.07)
			D.mix(a, nz2, 0.7)
			for k in 4:
				D.add_burst(a, sr, rng.randf_range(0.0, 0.12), 0.02, 0.05, 0.004, seed + variant * 13 + k, 2500.0, 0.0, 0.0003)
			D.add_sweep(a, sr, 0.0, 0.15, 80.0, 55.0, 0.3, 0.04, 0.003)
		"mud":
			D.add_sweep(a, sr, 0.0, 0.12, 140.0 * j, 320.0 * j, 0.32, 0.06, 0.004)
			var nz3 := D.noise(a.size(), seed + variant)
			D.lp1(nz3, 700.0, float(sr))
			D.env_perc(nz3, sr, 0.01, 0.09)
			D.mix(a, nz3, 0.55)
			D.add_burst(a, sr, 0.03, 0.06, 0.25, 0.01, seed + variant + 4, 1000.0, 2200.0, 0.001)
			D.add_sweep(a, sr, 0.1, 0.1, 200.0, 450.0, 0.12, 0.03, 0.003)
		_:
			# splash / wading
			var nz4 := D.noise(a.size(), seed + variant)
			D.band(nz4, 400.0, 3000.0 * j, float(sr))
			D.env_perc(nz4, sr, 0.015, 0.08)
			D.mix(a, nz4, 0.6)
			for k in 7:
				var tt: float = rng.randf_range(0.03, 0.26)
				D.add_sweep(a, sr, tt, 0.05, rng.randf_range(500.0, 900.0), rng.randf_range(1200.0, 2000.0), 0.12, 0.012, 0.002)
			D.add_sweep(a, sr, 0.0, 0.15, 100.0, 60.0, 0.25, 0.04, 0.003)
	return D.pack(a, sr, 0.7)

# =================================================================================================================================
# creatures & ambience one-shots
# =================================================================================================================================
static func bird(variant: int, seed: int) -> Dictionary:
	var sr := 32000
	var a := D.make(D.secs(0.6, sr))
	match variant:
		0:   # tweet-tweet
			D.add_sweep(a, sr, 0.0, 0.09, 3200.0, 4600.0, 0.5, 0.05, 0.004)
			D.add_sweep(a, sr, 0.12, 0.10, 4700.0, 3300.0, 0.5, 0.06, 0.004)
			D.add_sweep(a, sr, 0.27, 0.08, 3300.0, 4300.0, 0.4, 0.04, 0.004)
		1:   # trill
			for k in 9:
				var f: float = 3600.0 if k % 2 == 0 else 4300.0
				D.add_sweep(a, sr, 0.04 * float(k), 0.035, f, f * 1.05, 0.45, 0.02, 0.003)
		_:   # falling whistle
			D.add_sweep(a, sr, 0.0, 0.34, 4200.0, 2500.0, 0.5, 0.2, 0.01, PackedFloat32Array([0.12]))
			D.add_sweep(a, sr, 0.36, 0.14, 3000.0, 3600.0, 0.35, 0.08, 0.005)
	D.add_burst(a, sr, 0.0, 0.5, 0.01, 0.1, seed, 4000.0, 0.0, 0.01)
	return D.pack(a, sr, 0.5)

static func frog(variant: int, seed: int) -> Dictionary:
	var sr := SR
	var n := D.secs(0.55, sr)
	var a := D.make(n)
	var base: float = 190.0 if variant == 0 else 150.0
	var pulses: int = 5 if variant == 0 else 3
	for k in pulses:
		var t: float = 0.0 + 0.055 * float(k)
		D.add_sweep(a, sr, t, 0.05, base, base * 0.85, 0.5, 0.03, 0.004, PackedFloat32Array([0.7, 0.5, 0.3, 0.2]))
	D.lp1(a, 1800.0, float(sr))
	var r := D.reverb(a, sr, 0.5, 0.12, 0.15)
	return D.pack(r, sr, 0.5)

static func ice_creak(seed: int) -> Dictionary:
	var sr := SR
	var n := D.secs(1.5, sr)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var f := D.make(n)
	for i in n:
		var t: float = float(i) / float(sr)
		f[i] = 170.0 + 40.0 * sin(TAU * 0.9 * t) + 30.0 * sin(TAU * 2.3 * t + 1.0)
	var s := D.osc(f, sr, 1)
	D.biquad(s, D.F_BP, 420.0, 4.0, float(sr))
	var fl := D.wander(n, sr, 28.0, seed + 1)
	for i in n:
		s[i] *= fl[i] * fl[i] * 2.0
	D.env_swell(s, sr, 0.35, 0.7)
	return D.pack(s, sr, 0.5)

static func geiger_tick(seed: int) -> Dictionary:
	var sr := 32000
	var a := D.make(D.secs(0.07, sr))
	D.add_burst(a, sr, 0.0, 0.03, 0.8, 0.002, seed, 1800.0, 0.0, 0.0001)
	D.add_tone(a, sr, 0.0, 0.03, 3100.0, 0.3, 0.003, 0.0002)
	return D.pack(a, sr, 0.5)

static func spore_pop(seed: int) -> Dictionary:
	var sr := SR
	var a := D.make(D.secs(0.25, sr))
	D.add_sweep(a, sr, 0.0, 0.08, 380.0, 950.0, 0.55, 0.03, 0.002)
	D.add_burst(a, sr, 0.0, 0.1, 0.25, 0.015, seed, 600.0, 3500.0, 0.001)
	D.add_sweep(a, sr, 0.09, 0.08, 520.0, 1200.0, 0.15, 0.025, 0.002)
	return D.pack(a, sr, 0.5)

static func crystal_chime(seed: int) -> Dictionary:
	var sr := SR
	var a := D.make(D.secs(3.0, sr))
	D.add_note(a, sr, 0.0, 1568.0, 0.4, 0.9, 2)
	D.add_note(a, sr, 0.0, 2349.0, 0.15, 0.7, 2)
	var r := D.reverb(a, sr, 1.5, 0.3, 0.8)
	return D.pack(r, sr, 0.5)

static func wind_gust(seed: int) -> Dictionary:
	var sr := SR_LO
	var n := D.secs(4.0, sr)
	var nz := D.pink(n, seed)
	var b := D.svf(nz, D.ramp_exp(n, 300.0, 1100.0), 0.7, D.F_BP, float(sr))
	D.env_swell(b, sr, 1.5, 2.0)
	return D.pack(b, sr, 0.6)

static func thunder_far(seed: int) -> Dictionary:
	var sr := SR_LO
	var n := D.secs(4.5, sr)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var a := D.brown(n, seed)
	D.lp1(a, 180.0, float(sr))
	var env := D.make(n)
	for k in 5:
		var t: float = 0.05 + float(k) * 0.4 + rng.randf_range(0.0, 0.2)
		var s0: int = int(t * sr)
		var amp: float = rng.randf_range(0.5, 1.0) * (1.0 - float(k) * 0.12)
		for i in range(s0, n):
			env[i] += amp * exp(-float(i - s0) / (0.5 * sr))
	for i in n:
		a[i] *= env[i]
	return D.pack(a, sr, 0.7)

# =================================================================================================================================
# ambience loops (seamless, stereo where useful)
# =================================================================================================================================
## helper: generate a stereo pair from a function(channel) -> PackedFloat32Array (already looped)
static func _stereo(sr: int, left: PackedFloat32Array, right: PackedFloat32Array, peak: float) -> Dictionary:
	return D.pack(left, sr, peak, true, right)

static func amb_wind_low(seed: int) -> Dictionary:
	var sr := SR_LO
	var T := 8.0
	var xf := D.secs(1.0, sr)
	var tot := D.secs(T, sr) + xf
	var ch: Array = []
	for c in 2:
		var nz := D.pink(tot, seed + c * 31)
		D.lp1(nz, 420.0, float(sr))
		D.hp1(nz, 35.0, float(sr))
		var g := D.wander(tot, sr, 0.35, seed + 5 + c)
		for i in tot:
			nz[i] *= 0.3 + 0.7 * g[i]
		ch.append(D.loopify(nz, xf))
	return _stereo(sr, ch[0], ch[1], 0.7)

static func amb_wind_mid(seed: int) -> Dictionary:
	var sr := SR_LO
	var T := 8.0
	var xf := D.secs(1.0, sr)
	var tot := D.secs(T, sr) + xf
	var ch: Array = []
	for c in 2:
		var nz := D.pink(tot, seed + c * 29)
		D.band(nz, 450.0, 2400.0, float(sr))
		var g := D.wander(tot, sr, 0.5, seed + 7 + c)
		var fl := D.wander(tot, sr, 4.0, seed + 9 + c)
		for i in tot:
			nz[i] *= (0.25 + 0.75 * g[i]) * (0.85 + 0.3 * fl[i])
		ch.append(D.loopify(nz, xf))
	return _stereo(sr, ch[0], ch[1], 0.6)

static func amb_howl(seed: int) -> Dictionary:
	var sr := SR_LO
	var T := 8.0
	var xf := D.secs(1.0, sr)
	var tot := D.secs(T, sr) + xf
	var ch: Array = []
	for c in 2:
		var nz := D.noise(tot, seed + c * 13)
		var w1 := D.wander(tot, sr, 0.25, seed + 3 + c)
		var w2 := D.wander(tot, sr, 1.2, seed + 6 + c)
		var cut := D.make(tot)
		for i in tot:
			cut[i] = 650.0 + 600.0 * w1[i] + 120.0 * w2[i]
		var f1 := D.svf(nz, cut, 22.0, D.F_BP, float(sr))
		var cut2 := D.make(tot)
		for i in tot:
			cut2[i] = cut[i] * 1.52
		var f2 := D.svf(nz, cut2, 18.0, D.F_BP, float(sr))
		var g := D.wander(tot, sr, 0.3, seed + 11 + c)
		for i in tot:
			f1[i] = (f1[i] + 0.5 * f2[i]) * (0.15 + 0.85 * g[i] * g[i])
		ch.append(D.loopify(f1, xf))
	return _stereo(sr, ch[0], ch[1], 0.5)

static func amb_rustle(seed: int) -> Dictionary:
	var sr := SR
	var T := 6.0
	var xf := D.secs(0.8, sr)
	var tot := D.secs(T, sr) + xf
	var ch: Array = []
	for c in 2:
		var nz := D.pink(tot, seed + c * 23)
		D.hp1(nz, 2200.0, float(sr))
		D.lp1(nz, 9000.0, float(sr))
		var fl := D.wander(tot, sr, 14.0, seed + 2 + c)
		var g := D.wander(tot, sr, 0.4, seed + 4 + c)
		for i in tot:
			nz[i] *= fl[i] * fl[i] * 2.0 * (0.3 + 0.7 * g[i])
		ch.append(D.loopify(nz, xf))
	return _stereo(sr, ch[0], ch[1], 0.5)

static func amb_crickets(seed: int) -> Dictionary:
	var sr := SR
	var T := 4.0
	var n := D.secs(T, sr)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var ch: Array = []
	for c in 2:
		var a := D.make(n)
		for v in 4:
			var fc: float = rng.randf_range(4100.0, 5300.0)
			var period: float = [0.5, 0.8, 1.0, 2.0][v]
			var rate: float = 26.0 + rng.randf_range(0.0, 8.0)
			var pulses: int = 4 + (v % 2)
			var amp: float = rng.randf_range(0.5, 1.0)
			var off: float = rng.randf_range(0.0, period)
			var count: int = int(T / period)
			for k in count:
				for p in pulses:
					var pt: float = off + float(k) * period + float(p) / rate
					var pl := D.make(D.secs(0.02, sr))
					for i in pl.size():
						var e: float = sin(PI * float(i) / float(pl.size()))
						pl[i] = sin(TAU * fc * float(i) / float(sr)) * e * e
					D.mix_wrap(a, pl, amp * 0.5, int(pt * sr))
		ch.append(a)
	return _stereo(sr, ch[0], ch[1], 0.35)

static func amb_space(seed: int) -> Dictionary:
	var sr := 11025
	var T := 16.0
	var n := D.secs(T, sr)
	var ch: Array = []
	var freqs := [55.0, 82.5, 110.0, 164.5, 220.0, 329.0, 440.0]
	var amps := [0.5, 0.35, 0.3, 0.14, 0.12, 0.05, 0.03]
	for c in 2:
		var a := D.make(n)
		for p in freqs.size():
			var f: float = D.snap(float(freqs[p]) * (1.0 + 0.0009 * float(c) * float(p + 1)), T)
			var f_b: float = f + 2.0 / T
			var lfo: float = float(p + 1) / T
			var ph: float = float(p) * 1.9 + float(c) * 0.7
			var am: float = float(amps[p])
			for i in n:
				var t: float = float(i) / float(sr)
				var env: float = 0.65 + 0.35 * sin(TAU * lfo * t + ph)
				a[i] += am * env * (sin(TAU * f * t + ph) + 0.8 * sin(TAU * f_b * t + ph * 2.0))
		ch.append(a)
	return _stereo(sr, ch[0], ch[1], 0.55)

static func amb_suit(seed: int) -> Dictionary:
	var sr := SR_LO
	var T := 4.0
	var n := D.secs(T, sr)
	var a := D.make(n)
	var f: float = D.snap(118.0, T)
	for i in n:
		var t: float = float(i) / float(sr)
		a[i] = 0.12 * sin(TAU * f * t) + 0.05 * sin(TAU * f * 2.0 * t + 1.0) + 0.02 * sin(TAU * f * 3.0 * t)
	var br := D.noise(n, seed)
	D.band(br, 600.0, 3500.0, float(sr))
	for i in n:
		var t2: float = float(i) / float(n)
		var e: float = 0.0
		if t2 < 0.45:
			e = sin(PI * t2 / 0.45)
		elif t2 > 0.5 and t2 < 0.95:
			e = sin(PI * (t2 - 0.5) / 0.45)
		br[i] *= e * e
	D.mix(a, br, 0.3)
	return D.pack(a, sr, 0.5, true)

static func amb_rumble(seed: int) -> Dictionary:
	var sr := 11025
	var T := 8.0
	var xf := D.secs(1.0, sr)
	var tot := D.secs(T, sr) + xf
	var br := D.brown(tot, seed)
	D.lp1(br, 70.0, float(sr))
	var g := D.wander(tot, sr, 0.5, seed + 1)
	for i in tot:
		br[i] *= 0.4 + 0.9 * g[i] * g[i]
	var lo := D.loopify(br, xf)
	D.normalize(lo, 0.6)
	var f1: float = D.snap(31.0, T)
	var f2: float = D.snap(47.0, T)
	for i in lo.size():
		var t: float = float(i) / float(sr)
		lo[i] += 0.3 * sin(TAU * f1 * t) * (0.7 + 0.3 * sin(TAU * t / T * 3.0)) + 0.18 * sin(TAU * f2 * t + 1.0)
	return D.pack(lo, sr, 0.7, true)

static func amb_crackle(seed: int) -> Dictionary:
	var sr := SR
	var T := 6.0
	var n := D.secs(T, sr)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var ch: Array = []
	for c in 2:
		var a := D.make(n)
		for k in 55:
			var t: float = rng.randf_range(0.0, T)
			var len_s: float = rng.randf_range(0.006, 0.025)
			var bn := D.noise(D.secs(len_s, sr), seed + c * 1000 + k)
			D.biquad(bn, D.F_BP, rng.randf_range(1500.0, 5000.0), 1.5, float(sr))
			D.env_perc(bn, sr, 0.0005, len_s * 0.35)
			D.mix_wrap(a, bn, rng.randf_range(0.3, 1.0), int(t * sr))
		for k in 7:
			var t2: float = rng.randf_range(0.0, T)
			var bl := D.make(D.secs(0.15, sr))
			var f0: float = rng.randf_range(90.0, 160.0)
			D.add_sweep(bl, sr, 0.0, 0.14, f0, f0 * 2.2, 0.5, 0.05, 0.004)
			D.mix_wrap(a, bl, 0.5, int(t2 * sr))
		var bed := D.noise(n, seed + 77 + c)
		D.lp1(bed, 1400.0, float(sr))
		D.mix(a, bed, 0.05)
		ch.append(a)
	return _stereo(sr, ch[0], ch[1], 0.55)

static func amb_bubbles(seed: int) -> Dictionary:
	var sr := SR
	var T := 6.0
	var n := D.secs(T, sr)
	var xf := D.secs(0.6, sr)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var ch: Array = [D.make(n), D.make(n)]
	for k in 34:
		var t: float = rng.randf_range(0.0, T)
		var f0: float = rng.randf_range(260.0, 1100.0)
		var bl := D.make(D.secs(0.09, sr))
		D.add_sweep(bl, sr, 0.0, 0.08, f0, f0 * rng.randf_range(1.3, 1.9), 0.6, rng.randf_range(0.012, 0.03), 0.002)
		var pan: float = rng.randf()
		D.mix_wrap(ch[0], bl, (1.0 - pan) * rng.randf_range(0.3, 0.9), int(t * sr))
		D.mix_wrap(ch[1], bl, pan * rng.randf_range(0.3, 0.9), int(t * sr))
	for c in 2:
		var tot := n + xf
		var br := D.brown(tot, seed + 5 + c)
		D.lp1(br, 180.0, float(sr))
		var g := D.wander(tot, sr, 0.7, seed + 8 + c)
		for i in tot:
			br[i] *= 0.3 + 0.7 * g[i]
		var lo := D.loopify(br, xf)
		D.normalize(lo, 0.25)
		D.mix(ch[c], lo, 1.0)
	return _stereo(sr, ch[0], ch[1], 0.55)

static func amb_waves(seed: int) -> Dictionary:
	var sr := SR_LO
	var T := 12.0
	var n := D.secs(T, sr)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var ch: Array = []
	for c in 2:
		var a := D.make(n)
		for k in 5:
			var t: float = float(k) * T / 5.0 + rng.randf_range(-0.5, 0.5) + float(c) * 0.4
			var dur := 5.0
			var ln := D.secs(dur, sr)
			var sw := D.noise(ln, seed + c * 100 + k)
			D.band(sw, 250.0, 1500.0, float(sr))
			var foam := D.noise(ln, seed + c * 100 + k + 50)
			D.band(foam, 1800.0, 4800.0, float(sr))
			var amp: float = rng.randf_range(0.6, 1.0)
			for i in ln:
				var tt: float = float(i) / float(sr)
				var e_sw: float = exp(-pow((tt - 1.7) / 0.9, 2.0)) if tt < 1.7 else exp(-(tt - 1.7) / 1.3)
				sw[i] *= e_sw
				foam[i] *= clampf((tt - 1.2) / 0.4, 0.0, 1.0) * exp(-maxf(tt - 1.6, 0.0) / 0.9) * 0.55
			D.mix_wrap(a, sw, amp, int(t * sr))
			D.mix_wrap(a, foam, amp, int(t * sr))
		ch.append(a)
	return _stereo(sr, ch[0], ch[1], 0.6)

static func amb_crystal(seed: int) -> Dictionary:
	var sr := SR
	var T := 12.0
	var n := D.secs(T, sr)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var ch: Array = [D.make(n), D.make(n)]
	var scale := [1318.5, 1568.0, 1760.0, 1975.5, 2349.0, 2093.0]
	for k in 15:
		var t: float = rng.randf_range(0.0, T)
		var nt := D.make(D.secs(3.0, sr))
		D.add_note(nt, sr, 0.0, float(scale[rng.randi() % scale.size()]), rng.randf_range(0.15, 0.4), rng.randf_range(0.5, 1.1), 2)
		var pan: float = rng.randf()
		D.mix_wrap(ch[0], nt, 1.0 - pan, int(t * sr))
		D.mix_wrap(ch[1], nt, pan, int(t * sr))
	# shimmering pad (integer cycles)
	for c in 2:
		for p in 5:
			var f: float = D.snap(660.0 * (1.0 + 0.5 * float(p)) + float(c) * 0.5 * float(p), T)
			var lfo: float = D.snap(0.2 + 0.1 * float(p), T)
			for i in n:
				var t3: float = float(i) / float(sr)
				ch[c][i] += 0.025 * (0.5 + 0.5 * sin(TAU * lfo * t3 + float(p))) * sin(TAU * f * t3 + float(p) * 2.0)
	return _stereo(sr, ch[0], ch[1], 0.5)

static func amb_toxic(seed: int) -> Dictionary:
	var sr := SR_LO
	var T := 8.0
	var n := D.secs(T, sr)
	var xf := D.secs(1.0, sr)
	var ch: Array = []
	for c in 2:
		var a := D.make(n)
		var fc: float = D.snap(68.0 + float(c) * 0.5, T)
		var fm: float = D.snap(68.0 * 2.01, T)
		var lfo: float = 1.0 / T
		var fh: float = D.snap(1900.0, T)
		for i in n:
			var t: float = float(i) / float(sr)
			var idx: float = 1.8 + 1.4 * sin(TAU * lfo * t * 2.0 + float(c))
			a[i] = 0.5 * sin(TAU * fc * t + idx * sin(TAU * fm * t))
			a[i] += 0.012 * sin(TAU * fh * t + 3.0 * sin(TAU * 0.5 * t))
		var tot := n + xf
		var hz := D.pink(tot, seed + c)
		D.band(hz, 500.0, 2200.0, float(sr))
		var g := D.wander(tot, sr, 0.5, seed + 3 + c)
		for i in tot:
			hz[i] *= 0.08 * g[i]
		var lo := D.loopify(hz, xf)
		D.mix(a, lo, 1.0)
		ch.append(a)
	return _stereo(sr, ch[0], ch[1], 0.55)

static func amb_hum(seed: int) -> Dictionary:
	var sr := SR_LO
	var T := 6.0
	var n := D.secs(T, sr)
	var xf := D.secs(0.6, sr)
	var a := D.make(n)
	var f: float = D.snap(50.0, T)
	for i in n:
		var t: float = float(i) / float(sr)
		a[i] = 0.4 * sin(TAU * f * t) + 0.25 * sin(TAU * f * 2.0 * t + 0.5) + 0.12 * sin(TAU * f * 3.0 * t + 1.0) + 0.05 * sin(TAU * f * 6.0 * t)
		a[i] *= 0.9 + 0.1 * sin(TAU * 7.0 / T * t)
	var tot := n + xf
	var nz := D.noise(tot, seed)
	D.biquad(nz, D.F_BP, 2600.0, 3.0, float(sr))
	var fl := D.wander(tot, sr, 6.0, seed + 1)
	for i in tot:
		nz[i] *= fl[i] * fl[i] * 0.4
	D.mix(a, D.loopify(nz, xf), 1.0)
	return D.pack(a, sr, 0.5, true)

static func amb_rain(seed: int) -> Dictionary:
	var sr := SR
	var T := 6.0
	var n := D.secs(T, sr)
	var xf := D.secs(0.6, sr)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var ch: Array = []
	for c in 2:
		var tot := n + xf
		var nz := D.pink(tot, seed + c * 3)
		D.band(nz, 1400.0, 9000.0, float(sr))
		var lowb := D.pink(tot, seed + c * 3 + 1)
		D.lp1(lowb, 700.0, float(sr))
		var fl := D.wander(tot, sr, 30.0, seed + 5 + c)
		for i in tot:
			nz[i] = nz[i] * (0.65 + 0.7 * fl[i]) * 0.8 + lowb[i] * 0.12
		var lo := D.loopify(nz, xf)
		for k in 260:
			var t: float = rng.randf_range(0.0, T)
			var dr := D.noise(D.secs(0.006, sr), seed + c * 5000 + k)
			D.biquad(dr, D.F_BP, rng.randf_range(2500.0, 6500.0), 2.0, float(sr))
			D.env_perc(dr, sr, 0.0003, 0.0018)
			D.mix_wrap(lo, dr, rng.randf_range(0.15, 0.7), int(t * sr))
		ch.append(lo)
	return _stereo(sr, ch[0], ch[1], 0.5)
