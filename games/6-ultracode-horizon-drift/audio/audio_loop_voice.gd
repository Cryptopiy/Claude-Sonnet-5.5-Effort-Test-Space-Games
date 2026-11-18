class_name AudioLoopVoice
extends RefCounted
## One continuously playing looped layer (engine rumble, wind bed, alarm ...). The owner sets `target` (linear gain 0..1+) and
## `target_pitch`; `update(dt)` smooths both, starts the player lazily (the stream may still be building) and stops it when silent.
## Cheap per frame: no allocations; the AudioStreamPlayer properties are only written when they changed audibly (0.05 dB / 0.2 % pitch),
## and a still-unbuilt stream is polled at 4 Hz instead of taking the bank mutex every frame.

const DB_EPS := 0.05
const PITCH_EPS := 0.002
const POLL_S := 0.25

var sound: String
var player: AudioStreamPlayer
var base_db: float = 0.0
var gain: float = 0.0
var target: float = 0.0
var pitch: float = 1.0
var target_pitch: float = 1.0
var attack: float = 5.0        # smoothing rates (1/s)
var release: float = 2.5
var playing: bool = false
var _bank: AudioSoundBank
var _applied_db: float = -1000.0
var _applied_pitch: float = -1.0
var _poll_left: float = 0.0

func _init(owner_node: Node, bank: AudioSoundBank, sound_name: String) -> void:
	sound = sound_name
	_bank = bank
	var meta: Dictionary = AudioRecipes.meta(sound_name)
	base_db = float(meta["db"])
	player = AudioStreamPlayer.new()
	player.name = "Loop_" + sound_name
	player.bus = String(meta["bus"])
	owner_node.add_child(player)

func is_audible() -> bool:
	return playing and gain > 0.002

func update(dt: float) -> void:
	var k: float = attack if target > gain else release
	gain += (target - gain) * (1.0 - exp(-k * dt))
	pitch += (target_pitch - pitch) * (1.0 - exp(-7.0 * dt))
	if target <= 0.0005 and gain < 0.004:
		gain = 0.0
		if playing:
			player.stop()
			playing = false
			_applied_db = -1000.0
		return
	if player.stream == null:
		_poll_left -= dt
		if _poll_left > 0.0:
			return
		_poll_left = POLL_S
		var st: AudioStreamWAV = _bank.get_stream(sound)
		if st == null:
			return       # still being synthesised
		player.stream = st
	if not playing:
		var len_s: float = player.stream.get_length()
		player.play(randf() * len_s)
		playing = true
		_applied_db = -1000.0
		_applied_pitch = -1.0
	var db: float = base_db + linear_to_db(maxf(gain, 0.00001))
	if absf(db - _applied_db) > DB_EPS:
		_applied_db = db
		player.volume_db = db
	var p: float = clampf(pitch, 0.05, 4.0)
	if absf(p - _applied_pitch) > PITCH_EPS * p:
		_applied_pitch = p
		player.pitch_scale = p

func stop_now() -> void:
	target = 0.0
	gain = 0.0
	if playing:
		player.stop()
		playing = false
		_applied_db = -1000.0
