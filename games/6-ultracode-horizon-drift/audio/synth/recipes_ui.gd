class_name RecipesUI
extends RefCounted
## UI, notification and discovery sounds. Each recipe returns AudioDSP.pack(...) = {buf, right, sr, loop}.

const D = preload("res://audio/synth/audio_dsp.gd")
const SR_HI := 44100
const SR := 22050

static func ui_click(seed: int) -> Dictionary:
	var sr := SR_HI
	var a := D.make(D.secs(0.11, sr))
	D.add_sweep(a, sr, 0.0, 0.11, 2700.0, 1800.0, 0.55, 0.014, 0.0008)
	D.add_sweep(a, sr, 0.0, 0.11, 900.0, 640.0, 0.30, 0.018, 0.0008)
	D.add_burst(a, sr, 0.0, 0.02, 0.35, 0.003, seed, 3000.0, 0.0, 0.0002)
	return D.pack(a, sr, 0.6)

static func ui_hover(seed: int) -> Dictionary:
	var sr := SR_HI
	var a := D.make(D.secs(0.06, sr))
	D.add_sweep(a, sr, 0.0, 0.06, 3500.0, 3000.0, 0.5, 0.010, 0.001)
	D.add_burst(a, sr, 0.0, 0.01, 0.12, 0.002, seed, 4000.0, 0.0, 0.0002)
	return D.pack(a, sr, 0.3)

static func ui_open(seed: int) -> Dictionary:
	var sr := SR
	var n := D.secs(0.36, sr)
	var a := D.make(n)
	D.add_sweep(a, sr, 0.0, 0.32, 480.0, 960.0, 0.45, 0.0, 0.03)
	D.add_sweep(a, sr, 0.02, 0.30, 720.0, 1440.0, 0.22, 0.0, 0.03)
	var nz := D.noise(n, seed)
	var air := D.svf(nz, D.ramp_exp(n, 600.0, 5200.0), 1.5, D.F_BP, float(sr))
	D.mix(a, air, 0.35)
	D.env_swell(a, sr, 0.03, 0.2)
	return D.pack(a, sr, 0.55)

static func ui_back(seed: int) -> Dictionary:
	var sr := SR
	var n := D.secs(0.28, sr)
	var a := D.make(n)
	D.add_sweep(a, sr, 0.0, 0.25, 900.0, 450.0, 0.45, 0.0, 0.012)
	D.add_sweep(a, sr, 0.0, 0.25, 1350.0, 675.0, 0.15, 0.0, 0.012)
	var nz := D.noise(n, seed)
	var air := D.svf(nz, D.ramp_exp(n, 4200.0, 700.0), 1.2, D.F_BP, float(sr))
	D.mix(a, air, 0.2)
	D.env_swell(a, sr, 0.012, 0.16)
	return D.pack(a, sr, 0.5)

static func ui_error(seed: int) -> Dictionary:
	var sr := SR
	var a := D.make(D.secs(0.3, sr))
	var odd := PackedFloat32Array([0.0, 0.33, 0.0, 0.2])
	D.add_sweep(a, sr, 0.0, 0.11, 200.0, 190.0, 0.5, 0.0, 0.004, odd)
	D.add_sweep(a, sr, 0.14, 0.14, 170.0, 160.0, 0.5, 0.0, 0.004, odd)
	D.lp1(a, 1400.0, float(sr))
	return D.pack(a, sr, 0.5)

static func ui_warp_confirm(seed: int) -> Dictionary:
	var sr := SR
	var n := D.secs(2.2, sr)
	var a := D.make(n)
	# rising chord (A major, bell timbre)
	var notes := [220.0, 277.18, 329.63, 440.0, 554.37, 659.25]
	for i in notes.size():
		D.add_note(a, sr, 0.06 * float(i), float(notes[i]), 0.33, 0.55, 1)
	# sub swell
	var sub := D.make(n)
	D.add_sweep(sub, sr, 0.0, 1.2, 50.0, 62.0, 0.6, 0.0, 0.3)
	D.env_swell(sub, sr, 0.5, 0.6)
	D.mix(a, sub, 0.9)
	# upward air sweep
	var nz := D.noise(D.secs(1.0, sr), seed)
	var air := D.svf(nz, D.ramp_exp(nz.size(), 300.0, 9000.0), 1.1, D.F_BP, float(sr))
	D.env_swell(air, sr, 0.9, 0.08)
	D.mix(a, air, 0.35)
	var r := D.reverb(a, sr, 0.9, 0.3, 0.5)
	return D.pack(r, sr, 0.75)

static func notify(seed: int) -> Dictionary:
	var sr := SR
	var a := D.make(D.secs(1.1, sr))
	D.add_note(a, sr, 0.0, D.A5, 0.45, 0.2, 2)
	D.add_note(a, sr, 0.11, D.E6, 0.5, 0.26, 2)
	var r := D.reverb(a, sr, 0.7, 0.2, 0.4)
	return D.pack(r, sr, 0.55)

static func notify_good(seed: int) -> Dictionary:
	var sr := SR
	var a := D.make(D.secs(1.1, sr))
	D.add_note(a, sr, 0.0, D.C6, 0.4, 0.16, 3)
	D.add_note(a, sr, 0.075, D.E6, 0.4, 0.16, 3)
	D.add_note(a, sr, 0.15, D.G6, 0.45, 0.28, 3)
	var r := D.reverb(a, sr, 0.7, 0.2, 0.35)
	return D.pack(r, sr, 0.55)

static func notify_warn(seed: int) -> Dictionary:
	var sr := SR
	var a := D.make(D.secs(0.5, sr))
	var odd := PackedFloat32Array([0.0, 0.3, 0.0, 0.15])
	D.add_sweep(a, sr, 0.0, 0.13, 440.0, 440.0, 0.5, 0.0, 0.005, odd)
	D.add_sweep(a, sr, 0.16, 0.2, 349.0, 349.0, 0.5, 0.05, 0.005, odd)
	D.lp1(a, 2400.0, float(sr))
	return D.pack(a, sr, 0.5)

static func notify_danger(seed: int) -> Dictionary:
	var sr := SR
	var a := D.make(D.secs(0.6, sr))
	var odd := PackedFloat32Array([0.0, 0.4, 0.0, 0.25, 0.0, 0.15])
	for i in 3:
		D.add_sweep(a, sr, 0.19 * float(i), 0.11, 740.0, 740.0, 0.5, 0.0, 0.003, odd)
	D.lp1(a, 3600.0, float(sr))
	return D.pack(a, sr, 0.55)

static func pickup(seed: int) -> Dictionary:
	var sr := SR
	var a := D.make(D.secs(0.4, sr))
	D.add_note(a, sr, 0.0, D.C6, 0.4, 0.07, 3)
	D.add_note(a, sr, 0.055, D.E6, 0.4, 0.07, 3)
	D.add_note(a, sr, 0.11, D.G6, 0.4, 0.11, 3)
	return D.pack(a, sr, 0.5)

static func resource_collect(seed: int) -> Dictionary:
	var sr := SR
	var a := D.make(D.secs(0.7, sr))
	D.add_sweep(a, sr, 0.0, 0.04, 1200.0, 2300.0, 0.3, 0.02, 0.001)
	D.add_note(a, sr, 0.03, 2093.0, 0.5, 0.12, 2)
	D.add_note(a, sr, 0.03, 3136.0, 0.25, 0.09, 0)
	D.add_burst(a, sr, 0.0, 0.03, 0.2, 0.004, seed, 2500.0, 0.0, 0.0003)
	var r := D.reverb(a, sr, 0.5, 0.15, 0.2)
	return D.pack(r, sr, 0.55)

static func discover(seed: int) -> Dictionary:
	var sr := SR
	var a := D.make(D.secs(2.4, sr))
	var notes := [659.25, 830.6, 987.77, 1318.5, 1661.2]
	for i in notes.size():
		D.add_note(a, sr, 0.13 * float(i), float(notes[i]), 0.32, 0.55, 2)
	# warm pad underneath
	var pad := D.make(a.size())
	D.add_sweep(pad, sr, 0.0, 2.0, 329.63, 329.63, 0.25, 0.0, 0.3)
	D.add_sweep(pad, sr, 0.0, 2.0, 493.88, 493.88, 0.18, 0.0, 0.3)
	D.add_sweep(pad, sr, 0.0, 2.0, 659.25, 659.25, 0.1, 0.0, 0.3)
	D.env_swell(pad, sr, 0.5, 1.2)
	D.mix(a, pad, 1.0)
	# shimmering air
	var nz := D.noise(D.secs(1.8, sr), seed)
	D.biquad(nz, D.F_BP, 6500.0, 1.5, float(sr))
	D.env_swell(nz, sr, 0.5, 1.1)
	D.mix(a, nz, 0.12)
	var r := D.reverb(a, sr, 1.6, 0.35, 1.2)
	return D.pack(r, sr, 0.6)

static func interact(seed: int) -> Dictionary:
	var sr := SR
	var a := D.make(D.secs(0.28, sr))
	D.add_note(a, sr, 0.0, 880.0, 0.4, 0.035, 0)
	D.add_note(a, sr, 0.07, 1318.5, 0.4, 0.07, 0)
	return D.pack(a, sr, 0.45)

static func ui_start(seed: int) -> Dictionary:
	# title / game-start sting: deep swell + bright open chord
	var sr := SR
	var n := D.secs(3.4, sr)
	var a := D.make(n)
	var sub := D.make(n)
	D.add_sweep(sub, sr, 0.0, 2.6, 55.0, 55.0, 0.5, 0.0, 0.5)
	D.add_sweep(sub, sr, 0.0, 2.6, 82.4, 82.4, 0.3, 0.0, 0.5)
	D.env_swell(sub, sr, 1.2, 1.3)
	D.mix(a, sub, 1.0)
	var chord := [220.0, 329.63, 440.0, 659.25, 880.0]
	for i in chord.size():
		D.add_note(a, sr, 0.9 + 0.08 * float(i), float(chord[i]), 0.28, 1.0, 1)
	var nz := D.noise(D.secs(1.2, sr), seed)
	var air := D.svf(nz, D.ramp_exp(nz.size(), 400.0, 7000.0), 1.0, D.F_BP, float(sr))
	D.env_swell(air, sr, 1.0, 0.15)
	D.mix(a, air, 0.3, D.secs(0.2, sr))
	var r := D.reverb(a, sr, 1.8, 0.35, 0.8)
	return D.pack(r, sr, 0.7)
