class_name AudioDSP
extends RefCounted
## Tiny offline DSP toolkit used by AudioRecipes to synthesise every game sound in code (no audio files).
## All buffers are mono PackedFloat32Array (-1..1). Packed arrays are passed by reference, so most helpers work in place AND return the
## array for chaining. Nothing here touches the scene tree or audio devices, so it is safe to run on a worker thread.

const F_LP := 0
const F_HP := 1
const F_BP := 2
const F_NOTCH := 3

# note frequencies (Hz) used by the melodic sounds
const A3 := 220.0
const E4 := 329.63
const A4 := 440.0
const C5 := 523.25
const E5 := 659.25
const G5 := 783.99
const A5 := 880.0
const B5 := 987.77
const C6 := 1046.5
const E6 := 1318.5
const G6 := 1568.0
const A6 := 1760.0
const B6 := 1975.5

# ---------------------------------------------------------------------------------------------------------------------------------
# buffers / noise
# ---------------------------------------------------------------------------------------------------------------------------------
static func make(n: int) -> PackedFloat32Array:
	var a := PackedFloat32Array()
	a.resize(maxi(n, 1))
	return a

static func secs(t: float, sr: int) -> int:
	return maxi(int(round(t * float(sr))), 1)

## uniform white noise, deterministic for a given seed (xorshift32)
static func noise(n: int, seed: int) -> PackedFloat32Array:
	var a := make(n)
	var s: int = ((seed * 2654435761) + 12345) & 0xFFFFFFFF
	if s == 0:
		s = 0x9E3779B9
	for i in n:
		s ^= (s << 13) & 0xFFFFFFFF
		s ^= s >> 17
		s ^= (s << 5) & 0xFFFFFFFF
		a[i] = float(s) * 4.656612873e-10 - 1.0
	return a

## approx. pink noise (-3 dB/oct), roughly unit level
static func pink(n: int, seed: int) -> PackedFloat32Array:
	var a := noise(n, seed)
	var b0 := 0.0
	var b1 := 0.0
	var b2 := 0.0
	for i in n:
		var w: float = a[i]
		b0 = 0.99765 * b0 + w * 0.0990460
		b1 = 0.96300 * b1 + w * 0.2965164
		b2 = 0.57000 * b2 + w * 1.0526913
		a[i] = (b0 + b1 + b2 + w * 0.1848) * 0.35
	return a

## brown-ish noise (-6 dB/oct), normalised to ~unit peak
static func brown(n: int, seed: int) -> PackedFloat32Array:
	var a := noise(n, seed)
	var y := 0.0
	for i in n:
		y = y * 0.985 + a[i] * 0.12
		a[i] = y
	return normalize(a, 1.0)

## slowly varying random curve 0..1 (smoothed noise, `rate_hz` = typical change rate) – used for gusts / flutter
static func wander(n: int, sr: int, rate_hz: float, seed: int) -> PackedFloat32Array:
	var a := noise(n, seed)
	lp1(a, rate_hz, float(sr))
	lp1(a, rate_hz, float(sr))
	var pk := 0.0001
	for i in n:
		pk = maxf(pk, absf(a[i]))
	var k := 0.5 / pk
	for i in n:
		a[i] = clampf(0.5 + a[i] * k, 0.0, 1.0)
	return a

# ---------------------------------------------------------------------------------------------------------------------------------
# filters
# ---------------------------------------------------------------------------------------------------------------------------------
static func lp1(a: PackedFloat32Array, cutoff: float, sr: float) -> PackedFloat32Array:
	var c: float = 1.0 - exp(-TAU * minf(cutoff, sr * 0.45) / sr)
	var y := 0.0
	for i in a.size():
		y += c * (a[i] - y)
		a[i] = y
	return a

static func hp1(a: PackedFloat32Array, cutoff: float, sr: float) -> PackedFloat32Array:
	var c: float = 1.0 - exp(-TAU * minf(cutoff, sr * 0.45) / sr)
	var y := 0.0
	for i in a.size():
		y += c * (a[i] - y)
		a[i] = a[i] - y
	return a

## RBJ biquad (LP / HP / BP(constant peak gain) / notch), in place
static func biquad(a: PackedFloat32Array, kind: int, freq: float, q: float, sr: float) -> PackedFloat32Array:
	var f: float = clampf(freq, 8.0, sr * 0.45)
	var w0: float = TAU * f / sr
	var cw: float = cos(w0)
	var alpha: float = sin(w0) / (2.0 * maxf(q, 0.05))
	var b0: float
	var b1: float
	var b2: float
	match kind:
		F_LP:
			b0 = (1.0 - cw) * 0.5
			b1 = 1.0 - cw
			b2 = b0
		F_HP:
			b0 = (1.0 + cw) * 0.5
			b1 = -(1.0 + cw)
			b2 = b0
		F_BP:
			b0 = alpha
			b1 = 0.0
			b2 = -alpha
		_:
			b0 = 1.0
			b1 = -2.0 * cw
			b2 = 1.0
	var a0: float = 1.0 + alpha
	var a1: float = (-2.0 * cw) / a0
	var a2: float = (1.0 - alpha) / a0
	b0 /= a0
	b1 /= a0
	b2 /= a0
	var x1 := 0.0
	var x2 := 0.0
	var y1 := 0.0
	var y2 := 0.0
	for i in a.size():
		var x: float = a[i]
		var y: float = b0 * x + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
		x2 = x1
		x1 = x
		y2 = y1
		y1 = y
		a[i] = y
	return a

## band-pass noise helper: HP then LP (2nd order each) – a broad band, unlike the resonant BP biquad
static func band(a: PackedFloat32Array, lo: float, hi: float, sr: float) -> PackedFloat32Array:
	biquad(a, F_HP, lo, 0.707, sr)
	biquad(a, F_LP, hi, 0.707, sr)
	return a

## Time-varying state-variable filter (TPT). cutoffs[i] = cutoff in Hz at sample i. mode: F_LP / F_BP / F_HP. Returns a NEW buffer.
static func svf(a: PackedFloat32Array, cutoffs: PackedFloat32Array, q: float, mode: int, sr: float) -> PackedFloat32Array:
	var n: int = a.size()
	var out := make(n)
	var k: float = 1.0 / maxf(q, 0.05)
	var ic1 := 0.0
	var ic2 := 0.0
	var lim: float = sr * 0.45
	for i in n:
		var g: float = tan(PI * minf(cutoffs[i], lim) / sr)
		var a1: float = 1.0 / (1.0 + g * (g + k))
		var a2: float = g * a1
		var a3: float = g * a2
		var v0: float = a[i]
		var v3: float = v0 - ic2
		var v1: float = a1 * ic1 + a2 * v3
		var v2: float = ic2 + a2 * ic1 + a3 * v3
		ic1 = 2.0 * v1 - ic1
		ic2 = 2.0 * v2 - ic2
		if mode == F_LP:
			out[i] = v2
		elif mode == F_BP:
			out[i] = v1 * k      # normalised so the peak gain is ~1
		else:
			out[i] = v0 - k * v1 - v2
	return out

# ---------------------------------------------------------------------------------------------------------------------------------
# curves / envelopes
# ---------------------------------------------------------------------------------------------------------------------------------
## exponential ramp a -> b over n samples (a,b > 0)
static func ramp_exp(n: int, a: float, b: float) -> PackedFloat32Array:
	var o := make(n)
	var k: float = log(b / a) / float(maxi(n - 1, 1))
	for i in n:
		o[i] = a * exp(k * float(i))
	return o

static func ramp_lin(n: int, a: float, b: float) -> PackedFloat32Array:
	var o := make(n)
	var d: float = (b - a) / float(maxi(n - 1, 1))
	for i in n:
		o[i] = a + d * float(i)
	return o

## percussive envelope applied in place: linear attack, exponential decay (time constant tau, seconds), starting at sample `start`
static func env_perc(a: PackedFloat32Array, sr: int, attack: float, tau: float, start: int = 0) -> PackedFloat32Array:
	var na: int = maxi(int(attack * sr), 1)
	var k: float = 1.0 / maxf(tau * sr, 1.0)
	for i in range(start, a.size()):
		var j: int = i - start
		var e: float = exp(-float(j) * k)
		if j < na:
			e *= float(j) / float(na)
		a[i] *= e
	return a

## smooth swell: raised-cosine rise over `up` seconds, hold, raised-cosine fall over `down` seconds (end aligned to the buffer end)
static func env_swell(a: PackedFloat32Array, sr: int, up: float, down: float) -> PackedFloat32Array:
	var n: int = a.size()
	var nu: int = maxi(int(up * sr), 1)
	var nd: int = maxi(int(down * sr), 1)
	for i in n:
		var e := 1.0
		if i < nu:
			e = 0.5 - 0.5 * cos(PI * float(i) / float(nu))
		var r: int = n - 1 - i
		if r < nd:
			e *= 0.5 - 0.5 * cos(PI * float(r) / float(nd))
		a[i] *= e
	return a

## multiply by a per-sample curve (same length or shorter)
static func mul(a: PackedFloat32Array, c: PackedFloat32Array) -> PackedFloat32Array:
	var m: int = mini(a.size(), c.size())
	for i in m:
		a[i] *= c[i]
	return a

static func scale(a: PackedFloat32Array, g: float) -> PackedFloat32Array:
	for i in a.size():
		a[i] *= g
	return a

## fade first/last samples (click protection)
static func fade_edges(a: PackedFloat32Array, sr: int, fade_in: float = 0.0015, fade_out: float = 0.004) -> PackedFloat32Array:
	var n: int = a.size()
	var ni: int = mini(int(fade_in * sr), n / 2)
	var no: int = mini(int(fade_out * sr), n / 2)
	for i in ni:
		a[i] *= float(i) / float(ni)
	for i in no:
		a[n - 1 - i] *= float(i) / float(no)
	return a

# ---------------------------------------------------------------------------------------------------------------------------------
# mixing / levels
# ---------------------------------------------------------------------------------------------------------------------------------
## dst += src * gain, with src starting at sample `offset` of dst (extends nothing: clipped to dst length)
static func mix(dst: PackedFloat32Array, src: PackedFloat32Array, gain: float = 1.0, offset: int = 0) -> PackedFloat32Array:
	var n: int = mini(src.size(), dst.size() - offset)
	for i in n:
		dst[offset + i] += src[i] * gain
	return dst

## circular mix (for seamless loops): src wraps around the end of dst
static func mix_wrap(dst: PackedFloat32Array, src: PackedFloat32Array, gain: float, offset: int) -> PackedFloat32Array:
	var n: int = dst.size()
	for i in src.size():
		dst[(offset + i) % n] += src[i] * gain
	return dst

static func peak(a: PackedFloat32Array) -> float:
	var p := 0.0
	for i in a.size():
		p = maxf(p, absf(a[i]))
	return p

static func rms(a: PackedFloat32Array) -> float:
	var s := 0.0
	for i in a.size():
		s += a[i] * a[i]
	return sqrt(s / float(maxi(a.size(), 1)))

static func normalize(a: PackedFloat32Array, target_peak: float = 0.8) -> PackedFloat32Array:
	var p: float = peak(a)
	if p > 0.000001:
		var g: float = target_peak / p
		for i in a.size():
			a[i] *= g
	return a

static func remove_dc(a: PackedFloat32Array) -> PackedFloat32Array:
	var m := 0.0
	for i in a.size():
		m += a[i]
	m /= float(maxi(a.size(), 1))
	for i in a.size():
		a[i] -= m
	return a

## tanh waveshaper (drive >= 1)
static func saturate(a: PackedFloat32Array, drive: float) -> PackedFloat32Array:
	var nrm: float = 1.0 / tanh(drive)
	for i in a.size():
		a[i] = tanh(a[i] * drive) * nrm
	return a

## reverse in place
static func reverse(a: PackedFloat32Array) -> PackedFloat32Array:
	var n: int = a.size()
	for i in n / 2:
		var t: float = a[i]
		a[i] = a[n - 1 - i]
		a[n - 1 - i] = t
	return a

static func concat(a: PackedFloat32Array, b: PackedFloat32Array) -> PackedFloat32Array:
	var o := a.duplicate()
	o.append_array(b)
	return o

## Makes a noise-like buffer loop seamlessly: the last `xf` samples are cross-faded (equal power) into the first `xf`; returns a buffer
## that is `xf` samples shorter. Use `correlated = true` for tonal material (linear fade keeps amplitude constant for in-phase signals).
static func loopify(a: PackedFloat32Array, xf: int, correlated: bool = false) -> PackedFloat32Array:
	var n: int = a.size()
	xf = clampi(xf, 8, n / 2)
	var m: int = n - xf
	var o := make(m)
	for i in m:
		o[i] = a[i]
	for i in xf:
		var t: float = float(i) / float(xf)
		var wa: float
		var wb: float
		if correlated:
			wa = t
			wb = 1.0 - t
		else:
			wa = sin(t * PI * 0.5)
			wb = cos(t * PI * 0.5)
		# o[i] fades from the tail (a[m+i]) to the head (a[i])
		o[i] = a[i] * wa + a[m + i] * wb
	return o

## snap a frequency so that an integer number of cycles fits in `seconds` (needed for seamless tonal loops)
static func snap(freq: float, seconds: float) -> float:
	return maxf(round(freq * seconds), 1.0) / seconds

# ---------------------------------------------------------------------------------------------------------------------------------
# oscillators / tones
# ---------------------------------------------------------------------------------------------------------------------------------
## add a sine whose frequency glides exponentially f0 -> f1 over `dur`; amplitude envelope = linear attack * exp(-t/tau) (tau <= 0: none), starts at t0
static func add_sweep(dst: PackedFloat32Array, sr: int, t0: float, dur: float, f0: float, f1: float, amp: float, tau: float = 0.0, attack: float = 0.003, harmonics: PackedFloat32Array = PackedFloat32Array(), release: float = 0.005) -> void:
	var s0: int = int(t0 * sr)
	var n: int = mini(int(dur * sr), dst.size() - s0)
	if n <= 0:
		return
	var ph := 0.0
	var kf: float = log(f1 / f0) / maxf(float(n - 1), 1.0)
	var na: int = maxi(int(attack * sr), 1)
	var ktau: float = 1.0 / maxf(tau * sr, 1.0)
	var nh: int = harmonics.size()
	var nr: int = maxi(int(release * sr), 1)
	var inv_sr: float = TAU / float(sr)
	for i in n:
		var f: float = f0 * exp(kf * float(i))
		ph += f * inv_sr
		var e := 1.0
		if tau > 0.0:
			e = exp(-float(i) * ktau)
		if i < na:
			e *= float(i) / float(na)
		if i > n - nr:
			e *= float(n - i) / float(nr)
		var v: float = sin(ph)
		for h in nh:
			v += harmonics[h] * sin(ph * float(h + 2))
		dst[s0 + i] += v * amp * e

## add a pure/harmonic tone with constant frequency and (attack, hold-less) exponential decay
static func add_tone(dst: PackedFloat32Array, sr: int, t0: float, dur: float, freq: float, amp: float, tau: float, attack: float = 0.004, harmonics: PackedFloat32Array = PackedFloat32Array()) -> void:
	add_sweep(dst, sr, t0, dur, freq, freq, amp, tau, attack, harmonics)

## bell / chime note: inharmonic-ish partial stack with decaying amplitudes. kind: 0 soft (sine+octave), 1 bell, 2 glass, 3 pluck (more highs, fast decay)
static func add_note(dst: PackedFloat32Array, sr: int, t0: float, freq: float, amp: float, tau: float, kind: int = 1) -> void:
	var ratios: Array
	var amps: Array
	var taus: Array
	match kind:
		0:
			ratios = [1.0, 2.0, 3.0]
			amps = [1.0, 0.25, 0.06]
			taus = [1.0, 0.6, 0.4]
		2:
			ratios = [1.0, 2.76, 5.40, 8.93]
			amps = [1.0, 0.30, 0.12, 0.04]
			taus = [1.0, 0.5, 0.3, 0.18]
		3:
			ratios = [1.0, 2.0, 3.0, 4.0, 5.0]
			amps = [1.0, 0.55, 0.3, 0.15, 0.07]
			taus = [1.0, 0.55, 0.4, 0.3, 0.2]
		_:
			ratios = [1.0, 2.0, 3.0, 4.2, 5.4]
			amps = [1.0, 0.45, 0.2, 0.09, 0.04]
			taus = [1.0, 0.7, 0.5, 0.35, 0.25]
	for p in ratios.size():
		var f: float = freq * float(ratios[p])
		if f > sr * 0.45:
			continue
		var tp: float = tau * float(taus[p])
		add_tone(dst, sr, t0, tp * 6.5, f, amp * float(amps[p]), tp, 0.003)

## add a burst of noise with exponential decay (optionally filtered), starting at t0
static func add_burst(dst: PackedFloat32Array, sr: int, t0: float, dur: float, amp: float, tau: float, seed: int, hp: float = 0.0, lp: float = 0.0, attack: float = 0.0005) -> void:
	var s0: int = int(t0 * sr)
	var n: int = mini(int(dur * sr), dst.size() - s0)
	if n <= 2:
		return
	var nz := noise(n, seed)
	if hp > 0.0:
		hp1(nz, hp, float(sr))
	if lp > 0.0:
		lp1(nz, lp, float(sr))
	env_perc(nz, sr, attack, tau)
	for i in n:
		dst[s0 + i] += nz[i] * amp

## sine / saw-ish periodic oscillator with a per-sample frequency curve; shape 0 sine, 1 saw (naive), 2 square (naive), 3 triangle
static func osc(freqs: PackedFloat32Array, sr: int, shape: int = 0, phase0: float = 0.0) -> PackedFloat32Array:
	var n: int = freqs.size()
	var o := make(n)
	var ph: float = phase0
	var inv: float = 1.0 / float(sr)
	for i in n:
		ph += freqs[i] * inv
		ph -= floorf(ph)
		match shape:
			0:
				o[i] = sin(ph * TAU)
			1:
				o[i] = 2.0 * ph - 1.0
			2:
				o[i] = 1.0 if ph < 0.5 else -1.0
			_:
				o[i] = 4.0 * absf(ph - 0.5) - 1.0
	return o

## constant-frequency tone with N partials (amps[k] for harmonic k+1); integer-cycle friendly when freq is snapped
static func harmonic_tone(n: int, sr: int, freq: float, amps: PackedFloat32Array, phase_seed: float = 0.0) -> PackedFloat32Array:
	var o := make(n)
	var inv: float = TAU * freq / float(sr)
	for h in amps.size():
		var f: float = freq * float(h + 1)
		if f > sr * 0.45 or absf(amps[h]) < 0.0001:
			continue
		var ph0: float = phase_seed * float(h + 1) * 1.7
		var w: float = inv * float(h + 1)
		var am: float = amps[h]
		for i in n:
			o[i] += am * sin(w * float(i) + ph0)
	return o

# ---------------------------------------------------------------------------------------------------------------------------------
# space: echo / reverb
# ---------------------------------------------------------------------------------------------------------------------------------
## feedback echo taps (delays in seconds, gains) – returns a longer buffer
static func echo(a: PackedFloat32Array, sr: int, delays: Array, gains: Array, tail: float = 0.0) -> PackedFloat32Array:
	var maxd := 0.0
	for d in delays:
		maxd = maxf(maxd, float(d))
	var o := make(a.size() + int((maxd + tail) * sr))
	for i in a.size():
		o[i] = a[i]
	for k in delays.size():
		var off: int = int(float(delays[k]) * sr)
		var g: float = float(gains[k])
		for i in a.size():
			o[i + off] += a[i] * g
	return o

## small Schroeder reverb: 4 combs + 2 all-passes. `rt60` seconds of decay, `wet` 0..1 mix. Output is `tail` seconds longer than the input.
static func reverb(a: PackedFloat32Array, sr: int, rt60: float = 0.9, wet: float = 0.25, tail: float = 0.8) -> PackedFloat32Array:
	var n_in: int = a.size()
	var n: int = n_in + int(tail * sr)
	var inp := make(n)
	for i in n_in:
		inp[i] = a[i]
	var wetbuf := make(n)
	var combs: Array = [0.0297, 0.0371, 0.0411, 0.0437]
	for c in combs:
		var d: int = int(float(c) * sr)
		var g: float = pow(10.0, -3.0 * float(c) / maxf(rt60, 0.05))
		var line := make(d)
		var idx := 0
		var damp := 0.0
		for i in n:
			var y: float = line[idx]
			damp = damp * 0.35 + y * 0.65       # damping in the loop = darker tail
			line[idx] = inp[i] + damp * g
			idx += 1
			if idx >= d:
				idx = 0
			wetbuf[i] += y * 0.25
	# two series all-passes to smear the echoes
	for ap in [0.0050, 0.0017]:
		var d2: int = int(float(ap) * sr)
		var line2 := make(d2)
		var idx2 := 0
		for i in n:
			var buf_out: float = line2[idx2]
			var x: float = wetbuf[i]
			var y2: float = -x + buf_out
			line2[idx2] = x + buf_out * 0.5
			wetbuf[i] = y2
			idx2 += 1
			if idx2 >= d2:
				idx2 = 0
	var o := make(n)
	for i in n:
		o[i] = inp[i] * (1.0 - wet * 0.5) + wetbuf[i] * wet * 1.6
	return o

# ---------------------------------------------------------------------------------------------------------------------------------
# conversion
# ---------------------------------------------------------------------------------------------------------------------------------
## finish a recipe: DC removal (loops), peak normalisation (shared gain for both channels), click-safe edges (one-shots).
## Returns the dictionary the SoundBank stores: {buf, right (may be empty), sr, loop}
static func pack(a: PackedFloat32Array, sr: int, peak_target: float = 0.8, loop: bool = false, right: PackedFloat32Array = PackedFloat32Array()) -> Dictionary:
	var stereo: bool = right.size() == a.size()
	if loop:
		remove_dc(a)
		if stereo:
			remove_dc(right)
	var p: float = peak(a)
	if stereo:
		p = maxf(p, peak(right))
	var g: float = peak_target / p if p > 0.000001 else 1.0
	scale(a, g)
	if stereo:
		scale(right, g)
	if not loop:
		fade_edges(a, sr)
		if stereo:
			fade_edges(right, sr)
	return {"buf": a, "right": right if stereo else PackedFloat32Array(), "sr": sr, "loop": loop}

## 16-bit little endian PCM bytes (mono; or interleaved stereo when `right` is given)
static func pcm16(left: PackedFloat32Array, right: PackedFloat32Array = PackedFloat32Array()) -> PackedByteArray:
	var n: int = left.size()
	var stereo: bool = right.size() == n and n > 0
	var bytes := PackedByteArray()
	bytes.resize(n * (4 if stereo else 2))
	if stereo:
		for i in n:
			bytes.encode_s16(i * 4, int(clampf(left[i], -1.0, 1.0) * 32767.0))
			bytes.encode_s16(i * 4 + 2, int(clampf(right[i], -1.0, 1.0) * 32767.0))
	else:
		for i in n:
			bytes.encode_s16(i * 2, int(clampf(left[i], -1.0, 1.0) * 32767.0))
	return bytes

static func to_stream(left: PackedFloat32Array, sr: int, loop: bool = false, right: PackedFloat32Array = PackedFloat32Array()) -> AudioStreamWAV:
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = sr
	s.stereo = right.size() == left.size() and left.size() > 0
	s.data = pcm16(left, right)
	if loop:
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_begin = 0
		s.loop_end = left.size()
	else:
		s.loop_mode = AudioStreamWAV.LOOP_DISABLED
	return s

# ---------------------------------------------------------------------------------------------------------------------------------
# analysis (used by tests)
# ---------------------------------------------------------------------------------------------------------------------------------
## magnitude spectrum of a window (length must be a power of two); returns n/2 bins
static func fft_mag(win: PackedFloat32Array) -> PackedFloat32Array:
	var n: int = win.size()
	var re := PackedFloat64Array()
	var im := PackedFloat64Array()
	re.resize(n)
	im.resize(n)
	for i in n:
		var hann: float = 0.5 - 0.5 * cos(TAU * float(i) / float(n - 1))
		re[i] = win[i] * hann
	# bit reversal
	var j := 0
	for i in range(1, n):
		var bit: int = n >> 1
		while j & bit:
			j ^= bit
			bit >>= 1
		j ^= bit
		if i < j:
			var t: float = re[i]
			re[i] = re[j]
			re[j] = t
	var span := 2
	while span <= n:
		var ang: float = -TAU / float(span)
		var wr: float = cos(ang)
		var wi: float = sin(ang)
		var i := 0
		while i < n:
			var cr := 1.0
			var ci := 0.0
			for k in span / 2:
				var ur: float = re[i + k]
				var ui: float = im[i + k]
				var vr: float = re[i + k + span / 2] * cr - im[i + k + span / 2] * ci
				var vi: float = re[i + k + span / 2] * ci + im[i + k + span / 2] * cr
				re[i + k] = ur + vr
				im[i + k] = ui + vi
				re[i + k + span / 2] = ur - vr
				im[i + k + span / 2] = ui - vi
				var ncr: float = cr * wr - ci * wi
				ci = cr * wi + ci * wr
				cr = ncr
			i += span
		span <<= 1
	var m := PackedFloat32Array()
	m.resize(n / 2)
	for i in n / 2:
		m[i] = sqrt(re[i] * re[i] + im[i] * im[i]) / float(n)
	return m
