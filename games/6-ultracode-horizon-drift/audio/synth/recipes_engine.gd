class_name RecipesEngine
extends RefCounted
## Continuous layers: ship engine (rumble / roar / whine / boost / pulse / air rush), jetpack, mining beam. All loops are seamless
## (tonal parts use integer cycles per loop, noise parts are cross-faded with AudioDSP.loopify).

const D = preload("res://audio/synth/audio_dsp.gd")
const SR := 22050
const SR_LO := 16000

## low engine rumble: brown noise + sub harmonics of a 42 Hz "firing rate" with a slow throb
static func eng_rumble(seed: int) -> Dictionary:
	var sr := SR_LO
	var T := 3.0
	var xf := D.secs(0.5, sr)
	var n := D.secs(T, sr)
	var tot := n + xf
	var nz := D.brown(tot, seed)
	D.lp1(nz, 240.0, float(sr))
	var gust := D.wander(tot, sr, 1.5, seed + 1)
	for i in tot:
		nz[i] *= 0.65 + 0.35 * gust[i]
	var lo := D.loopify(nz, xf)
	D.normalize(lo, 0.6)
	var f0: float = D.snap(52.0, T)
	var throb: float = D.snap(4.0, T)
	for i in n:
		var t: float = float(i) / float(sr)
		var v: float = 0.5 * sin(TAU * f0 * t) + 0.42 * sin(TAU * f0 * 2.0 * t + 0.8) + 0.3 * sin(TAU * f0 * 3.0 * t + 1.9) + 0.18 * sin(TAU * f0 * 4.0 * t + 0.3)
		v *= 0.82 + 0.18 * sin(TAU * throb * t)
		lo[i] = lo[i] * 0.75 + v * 0.55
	return D.pack(lo, sr, 0.8, true)

## mid roar: band-limited pink noise with flutter (combustion / exhaust)
static func eng_roar(seed: int) -> Dictionary:
	var sr := SR
	var T := 3.0
	var xf := D.secs(0.5, sr)
	var n := D.secs(T, sr)
	var tot := n + xf
	var nz := D.pink(tot, seed)
	D.band(nz, 220.0, 2400.0, float(sr))
	var fl := D.wander(tot, sr, 9.0, seed + 1)
	var sl := D.wander(tot, sr, 0.6, seed + 2)
	for i in tot:
		nz[i] *= (0.7 + 0.3 * fl[i]) * (0.75 + 0.25 * sl[i])
	return D.pack(D.loopify(nz, xf), sr, 0.8, true)

## harmonic whine / turbine tone (exactly periodic)
static func eng_whine(seed: int) -> Dictionary:
	var sr := SR
	var T := 2.0
	var n := D.secs(T, sr)
	var f: float = D.snap(420.0, T)
	var a := D.harmonic_tone(n, sr, f, PackedFloat32Array([1.0, 0.3, 0.12, 0.05]), 0.0)
	var f2: float = D.snap(420.5, T)
	var b := D.harmonic_tone(n, sr, f2, PackedFloat32Array([0.6, 0.2, 0.1]), 1.1)
	D.mix(a, b, 1.0)
	var fl: float = D.snap(31.0, T)
	for i in n:
		a[i] *= 0.92 + 0.08 * sin(TAU * fl * float(i) / float(sr))
	return D.pack(a, sr, 0.7, true)

## boost scream: high band noise chopped at 80 Hz + buzzy tone
static func eng_boost(seed: int) -> Dictionary:
	var sr := SR
	var T := 2.0
	var xf := D.secs(0.4, sr)
	var n := D.secs(T, sr)
	var tot := n + xf
	var nz := D.noise(tot, seed)
	D.band(nz, 1800.0, 8500.0, float(sr))
	var am: float = D.snap(80.0, T)
	for i in tot:
		var t: float = float(i) / float(sr)
		nz[i] *= 0.7 + 0.3 * sin(TAU * am * t)
	var lo := D.loopify(nz, xf)
	D.normalize(lo, 0.5)
	var f: float = D.snap(360.0, T)
	var tone := D.harmonic_tone(n, sr, f, PackedFloat32Array([1.0, 0.5, 0.33, 0.25, 0.2]), 0.4)
	for i in n:
		lo[i] = lo[i] + tone[i] * 0.22
	return D.pack(lo, sr, 0.7, true)

## pulse-drive cruise hum: deep tones, throb, shimmering noise and a breathing whoosh
static func eng_pulse(seed: int) -> Dictionary:
	var sr := SR
	var T := 4.0
	var xf := D.secs(0.6, sr)
	var n := D.secs(T, sr)
	var tot := n + xf
	var nz := D.noise(tot, seed)
	var cut := D.make(tot)
	for i in tot:
		var t: float = float(i) / float(sr)
		cut[i] = 1800.0 + 900.0 * sin(TAU * 0.5 * t)
	var sh := D.svf(nz, cut, 4.0, D.F_BP, float(sr))
	var wh := D.noise(tot, seed + 1)
	D.lp1(wh, 1400.0, float(sr))
	for i in tot:
		var t2: float = float(i) / float(sr)
		wh[i] *= 0.5 + 0.5 * sin(TAU * 0.5 * t2)
		sh[i] = sh[i] * 0.18 + wh[i] * 0.5
	var lo := D.loopify(sh, xf)
	var f1: float = D.snap(55.0, T)
	var f2: float = D.snap(82.5, T)
	var f3: float = D.snap(110.0, T)
	var f4: float = D.snap(440.0, T)
	for i in n:
		var t3: float = float(i) / float(sr)
		var v: float = 0.45 * sin(TAU * f1 * t3) + 0.25 * sin(TAU * f2 * t3 + 0.5) + 0.2 * sin(TAU * f3 * t3 + 1.0)
		v *= 0.8 + 0.2 * sin(TAU * 4.0 * t3)
		v += 0.04 * sin(TAU * f4 * t3 + 2.0 * sin(TAU * 2.0 * t3))
		lo[i] += v
	return D.pack(lo, sr, 0.8, true)

## wind rushing past the hull
static func eng_wind(seed: int) -> Dictionary:
	var sr := SR
	var T := 3.0
	var xf := D.secs(0.5, sr)
	var n := D.secs(T, sr)
	var tot := n + xf
	var nz := D.pink(tot, seed)
	var cut := D.make(tot)
	for i in tot:
		var t: float = float(i) / float(sr)
		cut[i] = 900.0 + 450.0 * sin(TAU * t / T)
	var b := D.svf(nz, cut, 0.6, D.F_BP, float(sr))
	var g := D.wander(tot, sr, 2.0, seed + 1)
	for i in tot:
		b[i] *= 0.7 + 0.3 * g[i]
	return D.pack(D.loopify(b, xf), sr, 0.75, true)

## jetpack thrust: wide hissing roar with low body and flutter
static func jetpack(seed: int) -> Dictionary:
	var sr := SR
	var T := 1.6
	var xf := D.secs(0.3, sr)
	var n := D.secs(T, sr)
	var tot := n + xf
	var nz := D.noise(tot, seed)
	var cut := D.make(tot)
	var wn := D.wander(tot, sr, 5.0, seed + 1)
	for i in tot:
		cut[i] = 1300.0 + 800.0 * wn[i]
	var hiss := D.svf(nz, cut, 0.7, D.F_BP, float(sr))
	var low := D.brown(tot, seed + 2)
	D.lp1(low, 260.0, float(sr))
	var fl := D.wander(tot, sr, 14.0, seed + 3)
	for i in tot:
		hiss[i] = (hiss[i] * 0.8 + low[i] * 1.2) * (0.75 + 0.25 * fl[i])
	return D.pack(D.loopify(hiss, xf), sr, 0.7, true)

## mining beam: electric hum with warble, buzz and sizzle
static func mining_beam(seed: int) -> Dictionary:
	var sr := SR
	var T := 2.0
	var xf := D.secs(0.3, sr)
	var n := D.secs(T, sr)
	var f: float = D.snap(110.0, T)
	var warble: float = D.snap(6.0, T)
	var tone := D.make(n)
	for i in n:
		var t: float = float(i) / float(sr)
		var ph: float = TAU * f * t + 0.8 * sin(TAU * warble * t)
		tone[i] = 0.5 * sin(ph) + 0.28 * sin(2.0 * ph + 0.3) + 0.16 * sin(3.0 * ph + 1.0) + 0.1 * sin(5.0 * ph)
	D.biquad(tone, D.F_LP, 1800.0, 0.8, float(sr))
	var tot := n + xf
	var nz := D.noise(tot, seed)
	D.band(nz, 2500.0, 9000.0, float(sr))
	var am: float = D.snap(120.0, T)
	var wn := D.wander(tot, sr, 25.0, seed + 1)
	for i in tot:
		var t2: float = float(i) / float(sr)
		nz[i] *= (0.5 + 0.5 * sin(TAU * am * t2)) * (0.35 + 0.65 * wn[i])
	var sz := D.loopify(nz, xf)
	for i in n:
		tone[i] = tone[i] + sz[i] * 0.3
	return D.pack(tone, sr, 0.7, true)
