class_name EngineAudio
extends Node
## Tiny procedural soundscape (no audio assets): engine hum + noise, wind on planets, deep rumble near a black hole.

var player: AudioStreamPlayer
var gen: AudioStreamGenerator
var playback: AudioStreamGeneratorPlayback
var ph1: float = 0.0
var ph2: float = 0.0
var ph3: float = 0.0
var noise_lp: float = 0.0
var wind_lp: float = 0.0
var rate: float = 22050.0

var engine_power: float = 0.0  # 0..2
var wind: float = 0.0  # 0..1
var rumble: float = 0.0  # 0..1
var master: float = 0.0


func _ready() -> void:
	gen = AudioStreamGenerator.new()
	gen.mix_rate = rate
	gen.buffer_length = 0.12
	player = AudioStreamPlayer.new()
	player.stream = gen
	player.volume_db = -6.0
	add_child(player)
	player.play()
	playback = player.get_stream_playback() as AudioStreamGeneratorPlayback


func _process(_dt: float) -> void:
	if playback == null:
		return
	var n := playback.get_frames_available()
	var f1 := 46.0 + engine_power * 55.0
	var f3 := 24.0
	for i in n:
		var white := randf() * 2.0 - 1.0
		noise_lp = lerpf(noise_lp, white, 0.12)
		wind_lp = lerpf(wind_lp, white, 0.015)
		ph1 = fmod(ph1 + f1 / rate, 1.0)
		ph2 = fmod(ph2 + f1 * 1.505 / rate, 1.0)
		ph3 = fmod(ph3 + f3 / rate, 1.0)
		var saw := (ph1 * 2.0 - 1.0) * 0.5 + sin(ph2 * TAU) * 0.3
		var s := (saw * 0.22 + noise_lp * 0.3) * engine_power * 0.5
		s += wind_lp * wind * 2.2
		s += sin(ph3 * TAU) * rumble * 0.6 + noise_lp * rumble * 0.25
		s *= master
		playback.push_frame(Vector2(s, s))
