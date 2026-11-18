extends RefCounted
## HYPERDRIVE + WarpEffect safety test (module M5):  Game.try_hyperdrive / galaxy-map engage / tunnel / arrival / "screen never stuck".
##   --test=res://tests/bh_hyper.gd -- --autostart --preset=space:1:400 [--out=.previews/hy] [--times=0.4,0.9,1.4,1.9,2.4,3.0] [--watchdog=1] [--back=1]
## 1. refusal reasons (same system / no warp cells / already charging), warp-cell cost bookkeeping
## 2. jump 1 is started like the player does it: open the galaxy map (M), select a star, press WARP (GalaxyMap._engage) -> map closes, tunnel plays,
##    screenshots at the given times; arrival checks (system, ship placed, overlay released, input enabled, longest frame hitch while the system is built)
## 3. jump 2 (back to the home system) straight through Game.try_hyperdrive
## 4. --watchdog=1: play_out() with nobody calling play_in() (a dead warp coroutine): the screen must be released by the watchdog on its own
## 5. (default off) --back=0 skips jump 2

func _arg(name: String, default: String) -> String:
	for a in OS.get_cmdline_user_args():
		var s := String(a)
		if s.begins_with("--" + name + "="):
			return s.substr(name.length() + 3)
	return default

var _worst_gap_ms := 0
var _last_ms := 0

func _tick() -> void:
	var now := Time.get_ticks_msec()
	if _last_ms > 0:
		_worst_gap_ms = maxi(_worst_gap_ms, now - _last_ms)
	_last_ms = now

func _save(game: Node, out: String, tag: String) -> void:
	var img: Image = game.get_viewport().get_texture().get_image()
	var full := ProjectSettings.globalize_path("res://%s_%s.png" % [out, tag])
	DirAccess.make_dir_recursive_absolute(full.get_base_dir())
	img.save_png(full)

func _overlay_clear(fx: Object) -> bool:
	var rect: ColorRect = fx.get("_rect")
	return not bool(fx.call("is_playing")) and (rect == null or not rect.visible)

## play a warp that was started with `start` (a Callable) and take screenshots at `times` seconds after the call; returns when Game.warping is false again
func _play(game: Node, out: String, tag: String, times: PackedStringArray, start: Callable) -> void:
	var t0 := Time.get_ticks_msec()
	start.call()
	var n := 0
	var peak_cover := 0.0
	_last_ms = 0
	_worst_gap_ms = 0
	while (game.warping or n < times.size()) and (Time.get_ticks_msec() - t0) < 60000:
		await game.get_tree().process_frame
		_tick()
		var el := (Time.get_ticks_msec() - t0) / 1000.0
		peak_cover = maxf(peak_cover, float(game.warp_fx.get("_progress")))
		if n < times.size() and el >= float(times[n]):
			_save(game, out, "%s_%d_%s" % [tag, n, times[n]])
			print("[bh_hyper] %s t=%.2f shot %d  warping=%s system=%d progress=%.2f flash=%.2f" % [tag, el, n, str(game.warping), Universe.current_id, float(game.warp_fx.get("_progress")), float(game.warp_fx.get("_flash"))])
			n += 1
	print("[bh_hyper] %s finished after %.1f s, peak tunnel cover %.2f, longest frame gap %d ms" % [tag, (Time.get_ticks_msec() - t0) / 1000.0, peak_cover, _worst_gap_ms])

func run(game: Node) -> void:
	var out := _arg("out", ".previews/hy")
	var times: PackedStringArray = _arg("times", "0.4,0.9,1.4,1.9,2.4,3.0,3.6,4.4").split(",", false)
	var fx = game.warp_fx
	for i in 8:
		await game.get_tree().process_frame
	var home := Universe.current_id
	var tgt: int = (Universe.nearest_stars(home, 1)[0] as GalaxyStar).id
	var cost: int = game.hyperdrive_cost(tgt)
	print("[bh_hyper] home=%d target=%d cost=%d warp_cells=%d mode=%d can_hyperdrive=%s" % [home, tgt, cost, game.warp_cells, game.mode, str(game.ship.can_hyperdrive())])
	# ---- 1. refusals ------------------------------------------------------------------------------------------------------------------
	var r1: String = game.try_hyperdrive(home)
	print(("PASS" if r1 != "" else "FAIL"), " refusal: same system -> '%s'" % r1)
	game.warp_cells = maxi(cost - 1, 0)
	var r2: String = game.try_hyperdrive(tgt)
	print(("PASS" if r2 != "" and game.warp_cells == maxi(cost - 1, 0) and not game.warping else "FAIL"), " refusal: not enough warp cells -> '%s' (cells untouched: %d)" % [r2, game.warp_cells])
	# ---- 2. jump 1 through the galaxy map ---------------------------------------------------------------------------------------------
	game.warp_cells = cost + 1
	game.toggle_overlay("map")
	for i in 6:
		await game.get_tree().process_frame
	var gm = game.galaxy_map
	print("[bh_hyper] galaxy map open: visible=%s overlay_open=%s" % [str(gm.visible), str(game.overlay_open)])
	gm.set("_selected", tgt)
	await _play(game, out, "jump1", times, func(): gm.call("_engage"))
	print(("PASS" if Universe.current_id == tgt else "FAIL"), " jump1: arrived in system %d (%s) wanted %d" % [Universe.current_id, Universe.system.name, tgt])
	print(("PASS" if game.warp_cells == 1 else "FAIL"), " jump1: warp cells paid: %d left (cost %d)" % [game.warp_cells, cost])
	print(("PASS" if not gm.visible and not game.overlay_open else "FAIL"), " jump1: galaxy map was closed by the warp (visible=%s)" % str(gm.visible))
	print(("PASS" if _overlay_clear(fx) else "FAIL"), " jump1: overlay released (playing=%s rect_visible=%s)" % [str(fx.call("is_playing")), str((fx.get("_rect") as ColorRect).visible)])
	print(("PASS" if game.mode == game.Mode.SHIP and not game.warping and game.input_enabled() else "FAIL"), " jump1: ship mode, input enabled (mode=%d warping=%s)" % [game.mode, str(game.warping)])
	var arr_body: BodyDef = Universe.system.bodies[Universe.system.arrival_body]
	var d_arr: float = Universe.body_pos(Universe.system.arrival_body).distance_to(Frame.to_abs(game.ship.global_position))
	print(("PASS" if d_arr < arr_body.capture_radius * 3.0 else "FAIL"), " jump1: arrived %.0f km from '%s' (capture radius %.0f km)" % [d_arr / 1000.0, arr_body.name, arr_body.capture_radius / 1000.0])
	print(("PASS" if _worst_gap_ms < 6000 else "FAIL"), " jump1: longest frame gap during the jump %d ms (system build hitch hidden under the tunnel)" % _worst_gap_ms)
	_save(game, out, "jump1_arrived")
	# ---- 3. jump 2 straight through Game.try_hyperdrive, "already charging" refusal while it runs ------------------------------------------
	if _arg("back", "1") == "1":
		for i in 30:
			await game.get_tree().process_frame
		game.warp_cells = game.hyperdrive_cost(home) + 2
		var cells_before: int = game.warp_cells
		var ret: Array = [""]
		var refused: Array = [""]
		await _play(game, out, "jump2", PackedStringArray(["0.5", "1.5", "2.5"]), func():
			ret[0] = game.try_hyperdrive(home)
			refused[0] = game.try_hyperdrive(tgt))
		print(("PASS" if ret[0] == "" else "FAIL"), " jump2: try_hyperdrive returned '%s'" % ret[0])
		print(("PASS" if refused[0] != "" else "FAIL"), " jump2: second call while charging refused -> '%s'" % refused[0])
		print(("PASS" if Universe.current_id == home and game.warp_cells == cells_before - game.hyperdrive_cost(tgt) else "FAIL"), " jump2: back in system %d, cells %d -> %d" % [Universe.current_id, cells_before, game.warp_cells])
		print(("PASS" if _overlay_clear(fx) and not game.warping else "FAIL"), " jump2: overlay released, not warping")
	# ---- 4. watchdog -------------------------------------------------------------------------------------------------------------------------
	if _arg("watchdog", "0") == "1":
		print("[bh_hyper] watchdog test: play_out() without play_in() and without Game.warping (a WARNING line from WarpEffect is EXPECTED here)")
		var rc0: int = int(fx.get("reveal_count"))
		fx.call("play_out", "hyperdrive")        # not awaited: starts the tunnel, nobody ever reveals it
		var t0 := Time.get_ticks_msec()
		var covered := false
		var revealed := false
		while (Time.get_ticks_msec() - t0) < 14000:
			await game.get_tree().process_frame
			var rect: ColorRect = fx.get("_rect")
			if not covered and float(fx.get("_progress")) > 0.99:
				covered = true
				_save(game, out, "watchdog_covered")
				print("[bh_hyper] covered at %.1f s" % ((Time.get_ticks_msec() - t0) / 1000.0))
			if covered and not rect.visible:
				revealed = true
				print("[bh_hyper] watchdog released the screen at %.1f s" % ((Time.get_ticks_msec() - t0) / 1000.0))
				break
		print(("PASS" if covered and revealed and int(fx.get("reveal_count")) == rc0 + 1 and _overlay_clear(fx) else "FAIL"), " watchdog: a covered, orphaned overlay is released automatically (rescues %d)" % int(fx.get("reveal_count")))
	print(("PASS" if game.state == game.State.PLAYING else "FAIL"), " bh_hyper done: state playing")
