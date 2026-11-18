extends Node
## Game root: builds the world, HUD, menus and screen effects, and runs the high level state machine.

enum State { MENU, PLAYING, PAUSED, MAP, TRANSIT }

var world: SpaceWorld
var pc: PlayerController
var hud: Hud
var menus: Menus
var fx: ScreenFx
var galaxy_map: Node = null
var state: int = State.MENU
var _menu_orbit_t: float = 0.0
var _tween: Tween
var started_once: bool = false
var dust: SpaceDust
var weather: WeatherFx
var sfx_mgr: SfxManager
var fauna: FaunaManager

func _ready() -> void:
	randomize()
	Game.apply_settings()
	DetailTex.ensure()
	world = SpaceWorld.new()
	add_child(world)
	world.load_system(SystemGen.home_system())
	Game.current_system_index = Galaxy.HOME_INDEX
	pc = PlayerController.new()
	pc.setup(world, world)
	# --- UI layers
	dust = SpaceDust.new()
	add_child(dust)
	weather = WeatherFx.new()
	add_child(weather)
	weather.setup(world)
	fauna = FaunaManager.new()
	add_child(fauna)
	fauna.setup(world)
	var fx_layer := CanvasLayer.new()
	fx_layer.layer = 2
	add_child(fx_layer)
	fx = ScreenFx.new()
	fx_layer.add_child(fx)
	var hud_layer := CanvasLayer.new()
	hud_layer.layer = 10
	add_child(hud_layer)
	hud = Hud.new()
	hud_layer.add_child(hud)
	hud.setup(world, pc)
	var menu_layer := CanvasLayer.new()
	menu_layer.layer = 30
	add_child(menu_layer)
	menus = Menus.new()
	menu_layer.add_child(menus)
	menus.start_game.connect(_on_start_game)
	menus.resume_game.connect(_resume)
	menus.quit_to_menu.connect(_enter_menu)
	menus.quit_game.connect(func() -> void: get_tree().quit())
	menus.open_map.connect(_open_map)
	var map_layer := CanvasLayer.new()
	map_layer.layer = 40
	add_child(map_layer)
	galaxy_map = GalaxyMap.new()
	map_layer.add_child(galaxy_map)
	galaxy_map.closed.connect(close_map)
	galaxy_map.jump_requested.connect(hyperdrive_jump)
	Game.paused_changed.connect(func(_p: bool) -> void: pass)
	world.bh_captured.connect(_on_bh_captured)
	sfx_mgr = SfxManager.new()
	add_child(sfx_mgr)
	sfx_mgr.setup(world, pc, weather)
	_enter_menu()
	_apply_launch_options()

## Command-line options after `--` (used for the automated checks of the exported build): --autostart, --autoquit=SECONDS, --selftest
func _apply_launch_options() -> void:
	var ua: PackedStringArray = OS.get_cmdline_user_args()
	if ua.has("--selftest"):
		_selftest()
		return
	if ua.has("--autostart"):
		get_tree().create_timer(1.0).timeout.connect(_on_start_game)
	for a in ua:
		if a.begins_with("--autoquit="):
			get_tree().create_timer(maxf(float(a.substr(11)), 1.0)).timeout.connect(func() -> void: get_tree().quit())

## Checks that everything the game loads by path at run time is really inside the package (models, manifest, shaders), then quits.
func _selftest() -> void:
	var man: Dictionary = Models.manifest()
	var missing: PackedStringArray = PackedStringArray()
	for k in man.keys():
		if not Models.has_model(String(k)):
			missing.append(String(k))
	for r in ["res://scenes/main.tscn", "res://shaders/terrain.gdshader", "res://shaders/atmosphere.gdshader", "res://shaders/black_hole.gdshader", "res://shaders/sky.gdshader", "res://shaders/starfield.gdshaderinc"]:
		if not ResourceLoader.exists(r):
			missing.append(r)
	print("SELFTEST manifest_entries=%d missing=%d %s" % [man.size(), missing.size(), ", ".join(missing)])
	print("SELFTEST OK" if (man.size() >= 60 and missing.is_empty()) else "SELFTEST FAIL")
	get_tree().quit()

# ----------------------------------------------------------------------------------------- state changes
func _enter_menu() -> void:
	state = State.MENU
	world.paused = false
	Game.in_game = false
	Game.capture_mouse(false)
	hud.visible = false
	pc.cinematic = true
	pc.controls_on = false
	pc.mode = PlayerController.Mode.SHIP
	pc.astro.set_active(false)
	pc.ship.set_pilot_inside(true)
	pc.ship.menu_cam = true
	pc.ship.state = Ship.State.FLYING
	pc.ship.gear_target = 0.0
	pc.ship.pulse_on = false
	pc.ship.auto_pulse = false
	pc.ship.landing_assist = false
	pc.ship._set_collider(false)
	if world.frame_idx >= 0:
		world.frame_idx = -1
		world.viewer_pos = Vector3.ZERO
	var eden: BodyData = world.sys.find_body("Eden")
	pc.spawn_flying_near(eden.index, 15500.0)
	var to_planet: Vector3 = -pc.ship.basis.z
	pc.ship.basis = Basis.looking_at(to_planet.cross(Vector3.UP).normalized(), Vector3.UP)
	pc.ship.cam_basis = pc.ship.basis
	pc.ship.menu_cam = true
	pc.ship.gear = 0.0
	pc.ship.menu_orbit_t = 0.6
	# sit just off the day side limb with the star behind
	menus.show_page(Menus.Page.MAIN)
	if _tween != null:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(fx, "fade", 0.0, 0.9).from(1.0 if started_once else 0.0)

func _on_start_game() -> void:
	if state != State.MENU:
		return
	if _tween != null:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(fx, "fade", 1.0, 0.55)
	_tween.tween_callback(_begin_play)
	_tween.tween_property(fx, "fade", 0.0, 1.1)

func _begin_play() -> void:
	started_once = true
	state = State.PLAYING
	menus.show_page(Menus.Page.NONE)
	pc.cinematic = false
	pc.controls_on = true
	pc.ship.menu_cam = false
	pc.ship.cam_mode = 0
	var eden: BodyData = world.sys.find_body("Eden")
	pc.spawn_flying_near(eden.index, 56000.0)
	pc.ship.target_idx = eden.index
	Game.play_sfx("chime", -6.0)
	pc.ship.shield = 100.0
	pc.protection = 100.0
	pc.health = 100.0
	Game.in_game = true
	hud.visible = true
	hud.help_t = 26.0
	Game.capture_mouse(true)
	Game.notify("Welcome, Wayfarer. Eden is targeted: press Z for auto-pulse, or steer with the mouse and hold W.", 7.0)

func _pause() -> void:
	if state != State.PLAYING:
		return
	state = State.PAUSED
	world.paused = true
	Game.set_paused(true)
	Game.capture_mouse(false)
	menus.show_page(Menus.Page.PAUSE)

func _resume() -> void:
	if state == State.PAUSED:
		state = State.PLAYING
		world.paused = false
		Game.set_paused(false)
		menus.show_page(Menus.Page.NONE)
		Game.capture_mouse(true)

func _open_map() -> void:
	if state != State.PLAYING and state != State.PAUSED:
		return
	if galaxy_map == null or not is_instance_valid(galaxy_map):
		Game.notify("Galaxy map is not available yet", 2.0, "warn")
		return
	state = State.MAP
	world.paused = true
	menus.show_page(Menus.Page.NONE)
	hud.visible = false
	galaxy_map.call("open", world, pc)
	Game.capture_mouse(false)

func close_map() -> void:
	if state == State.MAP:
		hud.visible = true
		state = State.PLAYING
		world.paused = false
		Game.capture_mouse(true)

# ----------------------------------------------------------------------------------------- loop
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		match state:
			State.PLAYING:
				_pause()
			State.PAUSED:
				if menus.page == Menus.Page.PAUSE:
					_resume()
				elif menus.page == Menus.Page.CONTROLS or menus.page == Menus.Page.SETTINGS:
					menus.show_page(Menus.Page.PAUSE)
			State.MENU:
				if menus.page == Menus.Page.CONTROLS or menus.page == Menus.Page.SETTINGS:
					menus.show_page(Menus.Page.MAIN)
			State.MAP:
				if galaxy_map != null:
					galaxy_map.call("close_map")
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("map") and state == State.PLAYING:
		_open_map()
		get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	hud.show_fps = Game.show_fps
	dust.update_dust(world, pc)
	weather.update_weather(delta, world.camera, pc)
	if state == State.PLAYING:
		fauna.update_fauna(delta, pc)
	pc.weather_mul = weather.weather_mul
	_update_fx(delta)

func _update_fx(delta: float) -> void:
	var ship: Ship = pc.ship
	var heat: float = ship.heat if state == State.PLAYING else 0.0
	fx.heat = lerpf(fx.heat, heat, 1.0 - exp(-6.0 * delta))
	if state == State.PLAYING and pc.mode == PlayerController.Mode.SHIP:
		fx.speed_lines = lerpf(fx.speed_lines, clampf((ship.pulse_speed - 800.0) / 8000.0, 0.0, 1.0) * 0.8, 1.0 - exp(-5.0 * delta))
	else:
		fx.speed_lines = lerpf(fx.speed_lines, 0.0, 1.0 - exp(-5.0 * delta))
	# underwater tint
	var under: float = 0.0
	if world.frame_idx >= 0:
		var pl: Planet = world.planets[world.frame_idx]
		if pl.gen != null and pl.gen.has_sea:
			var sea_r: float = pl.data.radius + pl.gen.sea_h
			if world.camera.global_position.length() < sea_r:
				under = 1.0
				var kind: String = String(pl.data.profile.get("ocean", {}).get("kind", "water"))
				fx.mat.set_shader_parameter("under_color", Color(0.05, 0.25, 0.35) if kind == "water" else Color(0.15, 0.35, 0.05))
	fx.under = lerpf(fx.under, under, 1.0 - exp(-8.0 * delta))
	# black hole proximity: the image is pulled toward the centre, twisted, darkened and reddened as the pull grows
	var bh_target: float = 0.0
	var swirl_target: float = 0.0
	if state == State.PLAYING and not world.bh_info.is_empty():
		var d_h: float = float(world.bh_info.get("dist", 1e9))
		bh_target = clampf((14000.0 - d_h) / 12000.0, 0.0, 1.0)
		swirl_target = clampf((8000.0 - d_h) / 7000.0, 0.0, 1.0) * 1.2
	fx.bh = lerpf(fx.bh, bh_target, 1.0 - exp(-3.0 * delta))
	fx.bh_swirl = lerpf(fx.bh_swirl, swirl_target, 1.0 - exp(-2.0 * delta))
	# impact flashes
	if ship.last_impact > 0.0:
		fx.hit(clampf(ship.last_impact / 30.0, 0.15, 0.8))
		ship.last_impact = 0.0

# ----------------------------------------------------------------------------------------- transport
func _on_bh_captured() -> void:
	if state == State.TRANSIT:
		return
	state = State.TRANSIT
	pc.controls_on = false
	Game.stats["bh_jumps"] = int(Game.stats["bh_jumps"]) + 1
	var dest: int = world.sys.bh_dest_index
	if _tween != null:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(fx, "flash", 1.0, 0.5)
	_tween.tween_callback(_transport.bind(dest, "bh"))

func hyperdrive_jump(dest: int) -> void:
	if state != State.PLAYING and state != State.MAP:
		return
	state = State.TRANSIT
	world.paused = false
	pc.controls_on = false
	Game.stats["warps"] = int(Game.stats["warps"]) + 1
	if _tween != null:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(fx, "warp", 1.0, 1.3)
	_tween.tween_property(fx, "flash", 1.0, 0.35)
	_tween.tween_callback(_transport.bind(dest, "warp"))

func _transport(dest: int, kind: String) -> void:
	Engine.time_scale = 1.0
	fauna.clear_all()
	var old_name: String = world.sys.name
	var sys2: SystemData = SystemGen.generate(dest)
	world.load_system(sys2)
	Game.current_system_index = dest
	pc.arrive_in_system(sys2, kind)
	fx.bh = 0.0
	fx.bh_swirl = 0.0
	if _tween != null:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(fx, "flash", 0.0, 2.2)
	_tween.parallel().tween_property(fx, "warp", 0.0, 2.6).from(1.0)
	_tween.tween_callback(_finish_transport.bind(kind, sys2, old_name))

func _finish_transport(kind: String, sys2: SystemData, _old_name: String) -> void:
	state = State.PLAYING
	pc.controls_on = true
	Game.capture_mouse(true)
	if kind == "bh":
		Game.discover("bh_" + sys2.name, "Black hole transit complete: %s system (class %s star), 7,000 light-years closer to the galactic core" % [sys2.name, sys2.star_class])
		Game.notify("You emerged from a white hole in the %s system. There is no way back through the hole - use the galaxy map (M) to travel." % sys2.name, 7.0, "good")
	else:
		Game.discover("warp_" + sys2.name, "Hyperdrive jump complete: %s system (class %s star)" % [sys2.name, sys2.star_class])
		Game.notify("Arrived in the %s system" % sys2.name, 4.0, "good")
