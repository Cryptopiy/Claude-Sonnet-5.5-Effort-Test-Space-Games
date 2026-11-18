class_name AudioSoundBank
extends RefCounted
## Builds every procedural sound on a low-priority background thread (priority order from AudioRecipes.build_order) and hands out the
## finished AudioStreamWAV resources. Thread-safe: `get_stream` returns null until a sound is ready (callers just skip it for now).

var _streams: Dictionary = {}      # name -> AudioStreamWAV
var _stats: Dictionary = {}        # name -> {dur, peak, rms, ms, sr, loop, stereo}
var _mutex := Mutex.new()
var _queue: Array = []
var _thread: Thread = null
var _abort := false
var _started := false
var build_ms_total := 0
var _t0 := 0

func start_background() -> void:
	if _started:
		return
	_started = true
	_queue = Array(AudioRecipes.build_order())
	_t0 = Time.get_ticks_msec()
	_thread = Thread.new()
	_thread.start(_run, Thread.PRIORITY_LOW)

## synchronous build of everything (tests / tools). Safe to call when no thread is running.
func build_all_blocking(names: PackedStringArray = PackedStringArray()) -> void:
	var list: PackedStringArray = names if names.size() > 0 else AudioRecipes.build_order()
	for n in list:
		if not has_sound(n):
			_build_one(n)

func _run() -> void:
	while not _abort:
		var next := ""
		_mutex.lock()
		if _queue.size() > 0:
			next = _queue.pop_front()
		_mutex.unlock()
		if next == "":
			break
		if not has_sound(next):
			_build_one(next)
	build_ms_total = Time.get_ticks_msec() - _t0

func _build_one(sound: String) -> void:
	var t0 := Time.get_ticks_msec()
	var d: Dictionary = AudioRecipes.build(sound)
	if d.is_empty():
		return
	var buf: PackedFloat32Array = d["buf"]
	var right: PackedFloat32Array = d["right"]
	var sr: int = d["sr"]
	var loop: bool = d["loop"]
	var st := AudioDSP.to_stream(buf, sr, loop, right)
	var info := {
		"dur": float(buf.size()) / float(sr), "peak": AudioDSP.peak(buf), "rms": AudioDSP.rms(buf), "sr": sr, "loop": loop,
		"stereo": right.size() == buf.size(), "ms": Time.get_ticks_msec() - t0,
	}
	_mutex.lock()
	_streams[sound] = st
	_stats[sound] = info
	_mutex.unlock()

## move sounds to the front of the build queue (e.g. when entering a biome)
func prioritize(names: Array) -> void:
	_mutex.lock()
	for i in range(names.size() - 1, -1, -1):
		var n: String = names[i]
		var idx: int = _queue.find(n)
		if idx > 0:
			_queue.remove_at(idx)
			_queue.push_front(n)
	_mutex.unlock()

func has_sound(sound: String) -> bool:
	_mutex.lock()
	var h := _streams.has(sound)
	_mutex.unlock()
	return h

func get_stream(sound: String) -> AudioStreamWAV:
	_mutex.lock()
	var s: AudioStreamWAV = _streams.get(sound, null)
	_mutex.unlock()
	return s

func stats_of(sound: String) -> Dictionary:
	_mutex.lock()
	var d: Dictionary = _stats.get(sound, {})
	_mutex.unlock()
	return d

func ready_count() -> int:
	_mutex.lock()
	var n := _streams.size()
	_mutex.unlock()
	return n

func pending_count() -> int:
	_mutex.lock()
	var n := _queue.size()
	_mutex.unlock()
	return n

func is_started() -> bool:
	return _started

func is_complete() -> bool:
	return _started and pending_count() == 0 and (_thread == null or not _thread.is_alive())

## stop the worker (call from the owner's _exit_tree)
func shutdown() -> void:
	_abort = true
	if _thread != null:
		if _thread.is_started():
			_thread.wait_to_finish()
		_thread = null
