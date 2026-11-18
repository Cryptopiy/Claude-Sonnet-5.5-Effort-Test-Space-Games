extends Node
## DEBUG / TEST HARNESS driven by command-line *user args* (everything after `--`). Harmless in normal play (no args = does nothing).
##
##   Godot --path <proj> [engine args] -- --autostart --preset=air:1:800 --shot=.previews/a.png@6 --shot=.previews/b.png@12 --quit-at=14
##
## --autostart                      skip the main menu and start a game immediately
## --preset=<name>[:a[:b]]          landed[:body] | foot[:body] | air:body:alt_m | space:body:dist_km | bh:dist_km | star:dist_km | freecam:body:alt_m
## --system=<id>                    galaxy star id to load (default 0 = home system "Aurelia"; 1 = Kepler's Rest)
## --sun=<deg>                      sun elevation (degrees) at the spawn point for landed/foot/air presets (rising); default 14
## --shot=<path>@<seconds>          save a screenshot of the main viewport at <seconds> after start (repeatable). Relative path = inside the project
## --quit-at=<seconds>              quit after this many seconds
## --keys="<t>:press:<action>;<t>:release:<action>;<t>:tap:<action>"   scripted input (Input.action_press/release), t in seconds after start
## --mouse="<t>:<dx>,<dy>"          inject a relative mouse motion (pixels) at time t (repeatable via ';')
## --log-tel=<seconds>              print telemetry (frame, positions, game.tel, fps) every N seconds
## --freecam                        add a free-fly debug camera (WASD + mouse, Shift fast, Q/E down/up) instead of using the ship camera
## --test=res://tests/foo.gd        run a test script: `extends RefCounted; func run(game: Node) -> void:` (may await). Quit afterwards unless --keep
## --timescale=<x>                  Engine.time_scale

var _args: Dictionary = {}
var _shots: Array = []      # [path, seconds]
var _keys: Array = []       # [t, kind, action]
var _mouse: Array = []      # [t, Vector2]
var _t0_ms := 0
var _started := false
var _quit_at := -1.0
var _tel_every := -1.0
var _tel_next := 0.0
var _opts: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var raw := OS.get_cmdline_user_args()
	for a in raw:
		var s := String(a)
		if not s.begins_with("--"):
			continue
		s = s.substr(2)
		var eq := s.find("=")
		var k := s if eq < 0 else s.substr(0, eq)
		var v := "" if eq < 0 else s.substr(eq + 1)
		if k == "shot":
			var at := v.rfind("@")
			var path := v if at < 0 else v.substr(0, at)
			var sec := 5.0 if at < 0 else float(v.substr(at + 1))
			_shots.append([path, sec])
		else:
			_args[k] = v
	if _args.has("keys"):
		for item in String(_args["keys"]).split(";", false):
			var p := item.split(":")
			if p.size() >= 3:
				_keys.append([float(p[0]), p[1], p[2]])
		_keys.sort_custom(func(x, y): return x[0] < y[0])
	if _args.has("mouse"):
		for item in String(_args["mouse"]).split(";", false):
			var p2 := item.split(":")
			if p2.size() >= 2:
				var xy := p2[1].split(",")
				_mouse.append([float(p2[0]), Vector2(float(xy[0]), float(xy[1]))])
	if _args.has("quit-at"):
		_quit_at = float(_args["quit-at"])
	if _args.has("log-tel"):
		_tel_every = float(_args["log-tel"])
	if _args.has("timescale"):
		Engine.time_scale = float(_args["timescale"])
	_shots.sort_custom(func(x, y): return x[1] < y[1])
	if _args.has("autostart") or _args.has("preset") or _args.has("test") or _args.has("freecam"):
		_boot.call_deferred()

func _boot() -> void:
	# wait for scenes/main.gd to register itself
	for i in 30:
		if Game.world != null:
			break
		await get_tree().process_frame
	_opts = _parse_preset(String(_args.get("preset", "landed")))
	if _args.has("system"):
		_opts["system"] = int(_args["system"])
	if _args.has("sun"):
		_opts["sun"] = float(_args["sun"])
	if _opts.get("preset", "") == "freecam":
		_args["freecam"] = ""
	_t0_ms = Time.get_ticks_msec()
	await Game.start_game(_opts)
	_t0_ms = Time.get_ticks_msec()
	_started = true
	if _args.has("freecam"):
		_spawn_freecam()
	print("[DebugCLI] started preset=", _opts, " anchor=", Frame.anchor)
	if _args.has("test"):
		var scr = load(String(_args["test"]))
		if scr == null:
			printerr("[DebugCLI] cannot load test script ", _args["test"])
			get_tree().quit(2)
			return
		var t = scr.new()
		await t.run(Game)
		print("[DebugCLI] test finished")
		if not _args.has("keep"):
			get_tree().quit()

func _parse_preset(s: String) -> Dictionary:
	var p := s.split(":")
	var o: Dictionary = {"preset": p[0]}
	match p[0]:
		"landed", "foot":
			if p.size() > 1: o["body"] = int(p[1])
		"air", "freecam":
			if p.size() > 1: o["body"] = int(p[1])
			if p.size() > 2: o["alt"] = float(p[2])
		"space":
			if p.size() > 1: o["body"] = int(p[1])
			if p.size() > 2: o["dist_km"] = float(p[2])
		"bh", "star":
			if p.size() > 1: o["dist_km"] = float(p[1])
	return o

func _spawn_freecam() -> void:
	var fc := DebugFreeCam.new()
	fc.name = "DebugFreeCam"
	Game.local_root.add_child(fc)
	Game.freecam = fc
	var b: BodyDef = Universe.system.bodies[int(_opts.get("body", Universe.system.start_body))]
	if Frame.anchor >= 0:
		var pl := Frame.anchor_node()
		var dir := PoiSites.start_dir(b)
		var h: float = pl.call("height_at", dir) if pl != null and pl.has_method("height_at") else 0.0
		var alt := float(_opts.get("alt", 200.0))
		fc.global_position = dir * (b.radius + h + alt)
		fc.look_at(dir * (b.radius + h) + dir.cross(Vector3.UP).normalized() * 200.0, dir)
	else:
		fc.global_position = Vector3(0, 0, 0)
	Frame.set_focus(fc)
	fc.call("activate")

func _process(_dt: float) -> void:
	if not _started:
		return
	var t := (Time.get_ticks_msec() - _t0_ms) / 1000.0
	while not _keys.is_empty() and _keys[0][0] <= t:
		var k: Array = _keys.pop_front()
		match k[1]:
			"press": Input.action_press(k[2])
			"release": Input.action_release(k[2])
			"tap":
				Input.action_press(k[2])
				get_tree().create_timer(0.12).timeout.connect(func(): Input.action_release(k[2]))
	while not _mouse.is_empty() and _mouse[0][0] <= t:
		var m: Array = _mouse.pop_front()
		var ev := InputEventMouseMotion.new()
		ev.relative = m[1]
		ev.position = get_viewport().get_visible_rect().size * 0.5
		Input.parse_input_event(ev)
	while not _shots.is_empty() and _shots[0][1] <= t:
		var sh: Array = _shots.pop_front()
		_save_shot(String(sh[0]))
	if _tel_every > 0.0 and t >= _tel_next:
		_tel_next = t + _tel_every
		_print_tel(t)
	if _quit_at >= 0.0 and t >= _quit_at:
		print("[DebugCLI] quit-at reached")
		get_tree().quit()

func _save_shot(path: String) -> void:
	var img := get_viewport().get_texture().get_image()
	var full := path
	if not (path.begins_with("/") or path.contains(":")):
		full = ProjectSettings.globalize_path("res://" + path)
	DirAccess.make_dir_recursive_absolute(full.get_base_dir())
	var err := img.save_png(full)
	print("[DebugCLI] screenshot ", full, " err=", err, " size=", img.get_size())

func _print_tel(t: float) -> void:
	var focus := Frame.focus
	var fp := focus.global_position if focus != null and is_instance_valid(focus) else Vector3.ZERO
	print("[TEL] t=%.1f fps=%d anchor=%d mode=%d focus_local=(%.1f, %.1f, %.1f) |r|=%.1f tel=%s" % [t, Engine.get_frames_per_second(), Frame.anchor, Game.mode, fp.x, fp.y, fp.z, fp.length(), str(Game.tel)])
