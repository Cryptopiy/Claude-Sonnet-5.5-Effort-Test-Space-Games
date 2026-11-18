class_name WarpEffect
extends Control
## WARP / HYPERSPACE / BLACK-HOLE TRANSITION overlay (module M5).
## Contract used by Game.warp_to_system():  `await play_out(kind)` returns when the screen is fully covered (the world can be swapped);
## `await play_in(kind)` returns when the arrival effect is finished.   kind = "hyperdrive" | "blackhole".
##   hyperdrive : blue-white star streaks flying outwards through a glowing tunnel, ends in a white flash; arrival = flash dissolving to space
##   blackhole  : red/orange vortex that spirals into a white-hot core, ends in a warm white-out; arrival = "white hole" flash
## Extra API: last_kind (String), is_playing() -> bool, show_progress(p: float) (manual drive for the galaxy map's "charging" animation).
## SAFETY: the screen must never stay covered.  A watchdog (see _watchdog) reveals the world again when the overlay has been fully opaque for too
## long without anybody calling play_in() (a crashed warp coroutine, a warp that was refused after play_out, ...).

const COVER_TIME_HYPER := 2.0
const COVER_TIME_BH := 2.4
const REVEAL_TIME_HYPER := 1.7
const REVEAL_TIME_BH := 1.9
const WATCHDOG_IDLE_S := 12.0        # fully covered, nothing animating and Game still says "warping": the arrival never came -> reveal
const WATCHDOG_ORPHAN_S := 1.5       # fully covered and Game is NOT warping at all (nobody owns the overlay) -> reveal
const WATCHDOG_DEAD_S := 30.0        # last resort: even after revealing, Game.warping is still stuck -> release it so the player is not frozen

var last_kind: String = ""
var _rect: ColorRect
var _mat: ShaderMaterial
var _tween: Tween
var _progress := 0.0
var _flash := 0.0
var _speed := 0.3
var _phase := 0.0
var _swirl := 0.0
var _playing := false
var _kind := "hyperdrive"
var _idle_cover_t := 0.0             # seconds (frame-time clamped) the overlay has been opaque with no tween running
var _stuck_t := 0.0                  # seconds Game.warping has stayed true although the overlay was already released
var _manual := false                 # driven by show_progress()
var reveal_count := 0                # how often the watchdog had to rescue the screen (tests read this)

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect = ColorRect.new()
	_rect.color = Color(0, 0, 0, 1)
	_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mat = ShaderMaterial.new()
	_mat.shader = load("res://shaders/warp_tunnel.gdshader") as Shader
	_rect.material = _mat
	_rect.visible = false
	add_child(_rect)
	set_process(true)

func is_playing() -> bool:
	return _playing

func _apply_kind(kind: String) -> void:
	_kind = kind
	last_kind = kind
	if kind == "blackhole":
		_swirl = 1.0
		_mat.set_shader_parameter("col_a", Color(1.0, 0.62, 0.25))
		_mat.set_shader_parameter("col_b", Color(0.85, 0.12, 0.02))
		_mat.set_shader_parameter("col_c", Color(1.0, 0.78, 0.45))
		_mat.set_shader_parameter("flash_col", Color(1.0, 0.88, 0.72))
		_mat.set_shader_parameter("seed", 3.7)
	else:
		_swirl = 0.0
		_mat.set_shader_parameter("col_a", Color(0.78, 0.9, 1.0))
		_mat.set_shader_parameter("col_b", Color(0.10, 0.24, 0.95))
		_mat.set_shader_parameter("col_c", Color(0.8, 0.93, 1.0))
		_mat.set_shader_parameter("flash_col", Color(0.92, 0.96, 1.0))
		_mat.set_shader_parameter("seed", 1.3)
	_mat.set_shader_parameter("swirl", _swirl)

func _push() -> void:
	_mat.set_shader_parameter("progress", _progress)
	_mat.set_shader_parameter("flash", _flash)
	_mat.set_shader_parameter("phase", _phase)
	_mat.set_shader_parameter("streak_len", 0.18 + 0.85 * _speed)
	_rect.visible = _progress > 0.001 or _flash > 0.001

func _process(dt: float) -> void:
	_watchdog(dt)
	if not _rect.visible and not _playing:
		return
	_phase += dt * (0.5 + 5.5 * _speed)
	_push()

func _tween_running() -> bool:
	return _tween != null and _tween.is_valid() and _tween.is_running()

## Dead-man switch: the overlay is an opaque full-screen rect, so a warp that dies half-way would leave the game black / white forever.
func _watchdog(dt: float) -> void:
	var real_dt := minf(dt / maxf(Engine.time_scale, 0.001), 0.25)   # real seconds, a long blocking load counts as one slow frame only
	var covered := _rect.visible and (_progress > 0.98 or _flash > 0.98)
	if covered and not _tween_running():
		_idle_cover_t += real_dt
		var limit := WATCHDOG_IDLE_S if bool(Game.warping) else WATCHDOG_ORPHAN_S
		if _manual:
			limit = 30.0
		if _idle_cover_t > limit:
			_rescue()
	else:
		_idle_cover_t = 0.0
	if bool(Game.warping) and not _playing and not _rect.visible and reveal_count > 0:
		_stuck_t += real_dt
		if _stuck_t > WATCHDOG_DEAD_S:
			_stuck_t = 0.0
			push_warning("WarpEffect: Game.warping stayed true after a rescue - releasing it")
			Game.warping = false
	else:
		_stuck_t = 0.0

## fade the world back in (does not touch Game: the caller's coroutine may still be alive, e.g. a very slow system build)
func _rescue() -> void:
	reveal_count += 1
	push_warning("WarpEffect: overlay was stuck (progress %.2f flash %.2f, warping=%s) - revealing the world" % [_progress, _flash, str(Game.warping)])
	_idle_cover_t = 0.0
	_playing = true
	_kill_tween()
	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.tween_method(_set_flash, _flash, 0.0, 0.5)
	_tween.tween_method(_set_progress, _progress, 0.0, 0.9)
	_tween.tween_method(_set_speed, _speed, 0.15, 0.9)
	_tween.chain().tween_callback(_finish_reveal)

func _finish_reveal() -> void:
	_progress = 0.0
	_flash = 0.0
	_speed = 0.3
	_playing = false
	_manual = false
	_push()
	Audio.set_loop("warp_tunnel", false, 0.0)

func _kill_tween() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null

func _set_progress(v: float) -> void:
	_progress = v

func _set_flash(v: float) -> void:
	_flash = v

func _set_speed(v: float) -> void:
	_speed = v

## manual drive (e.g. a charging animation): 0 = nothing, 1 = tunnel fully formed
func show_progress(p: float, kind: String = "hyperdrive") -> void:
	_manual = p > 0.0
	if not _playing:
		_apply_kind(kind)
	_progress = clampf(p, 0.0, 1.0)
	_speed = 0.2 + 0.5 * _progress
	_push()

# ---------------------------------------------------------------------------------------------------------------------
func play_out(kind: String) -> void:
	_manual = false
	_idle_cover_t = 0.0
	_kill_tween()
	_apply_kind(kind)
	_playing = true
	var dur := COVER_TIME_BH if kind == "blackhole" else COVER_TIME_HYPER
	_flash = 0.0
	_progress = maxf(_progress, 0.0)
	_speed = 0.25
	Audio.sfx("warp_charge")
	Audio.set_loop("warp_tunnel", true, 0.9)
	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.tween_method(_set_progress, _progress, 1.0, dur).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_method(_set_speed, 0.25, 1.0, dur * 0.85).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_tween.tween_method(_set_flash, 0.0, 1.0, dur * 0.22).set_delay(dur * 0.78).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await _tween.finished
	_progress = 1.0
	_flash = 1.0
	_push()
	Audio.sfx("warp_jump")

func play_in(kind: String) -> void:
	_manual = false
	_idle_cover_t = 0.0
	_kill_tween()
	_apply_kind(kind)
	_playing = true
	var dur := REVEAL_TIME_BH if kind == "blackhole" else REVEAL_TIME_HYPER
	_progress = 1.0
	_flash = 1.0
	_speed = 1.0
	_push()
	await get_tree().process_frame            # let the freshly built world render at least one frame under the flash
	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.tween_method(_set_flash, 1.0, 0.0, dur * 0.38).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.tween_method(_set_progress, 1.0, 0.0, dur).set_delay(dur * 0.12).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_method(_set_speed, 1.0, 0.15, dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await _tween.finished
	_progress = 0.0
	_flash = 0.0
	_speed = 0.3
	_playing = false
	_push()
	Audio.set_loop("warp_tunnel", false, 0.0)
