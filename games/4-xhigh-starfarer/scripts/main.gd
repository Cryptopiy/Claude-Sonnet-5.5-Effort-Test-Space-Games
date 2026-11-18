extends Node
## Bootstrap: builds the world, HUD, menus and galaxy map and wires the game states.
## In stealth (test) mode everything renders into an off-screen SubViewport.

var holder: Node
var vp: SubViewport
var world: World
var hud: Hud
var menus: Menus
var gmap: GalaxyMap
var props: PropManager
var started := false
var paused_by_menu := false


func _ready() -> void:
	if Game.stealth:
		# test mode: invisible 8x8 transparent window (minimising would stop Godot from drawing at all)
		get_viewport().transparent_bg = true
		vp = SubViewport.new()
		vp.size = Vector2i(int(Game.args.get("w", 1280)), int(Game.args.get("h", 720)))
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		vp.msaa_3d = Viewport.MSAA_2X
		add_child(vp)
		holder = vp
	else:
		holder = self
	world = World.new()
	world.name = "World"
	holder.add_child(world)
	world.build_system(Galaxy.HOME_ID)
	props = PropManager.new()
	props.name = "Props"
	world.add_child(props)
	props.setup(world)
	world.props_mgr = props
	world.extras.append(props)
	hud = Hud.new()
	holder.add_child(hud)
	menus = Menus.new()
	holder.add_child(menus)
	gmap = GalaxyMap.new()
	holder.add_child(gmap)
	menus.start_new_game.connect(_on_start)
	menus.resume_game.connect(resume)
	menus.back_to_menu.connect(to_menu)
	menus.quit_game.connect(func(): get_tree().quit())
	gmap.jump_requested.connect(_on_jump)
	gmap.closed.connect(_on_map_closed)
	Game.state_changed.connect(_on_state)
	to_menu()
	if Game.args.has("scn"):
		var drv := TestDriver.new()
		drv.name = "TestDriver"
		add_child(drv)
		drv.setup(self)


func to_menu() -> void:
	get_tree().paused = false
	world.spawn_in_orbit(world.home_planet, 12000.0)
	world.cam_mode = World.CamMode.MENU
	world.ship.disabled = true
	Game.set_state(Game.State.MENU)
	menus.show_main()
	started = false


func _on_start(ground: bool) -> void:
	get_tree().paused = false
	menus.show_none()
	if ground:
		world.spawn_on_surface(world.home_planet)
	else:
		world.spawn_in_orbit(world.home_planet, 9000.0)
		world.ship.throttle = 0.0
	Game.set_state(Game.State.PLAYING)
	started = true
	hud.show_banner("VERDANT" if ground else "VERDANT ORBIT", "Press F1 for the controls")
	if ground:
		Game.msg("Welcome, explorer. Your ship is parked beside you.", "good")
		Game.msg("Walk, look around, mine glowing crystals — then [E] to board the ship.", "info")
	else:
		Game.msg("You are in low orbit above Verdant. [L] landing gear to descend.", "info")
	Sfx.play("select")


func pause() -> void:
	if Game.state != Game.State.PLAYING:
		return
	Game.set_state(Game.State.PAUSED)
	get_tree().paused = true
	menus.show_pause()


func resume() -> void:
	get_tree().paused = false
	menus.show_none()
	Game.set_state(Game.State.PLAYING)


func open_map() -> void:
	if Game.state != Game.State.PLAYING:
		return
	Game.set_state(Game.State.MAP)
	get_tree().paused = true
	gmap.open(world)
	Sfx.play("select")


func _on_map_closed() -> void:
	get_tree().paused = false
	Game.set_state(Game.State.PLAYING)


func _on_jump(id: int) -> void:
	gmap.visible = false
	get_tree().paused = false
	Game.set_state(Game.State.PLAYING)
	world.jump_to_star(id)


func _on_state(s: int) -> void:
	if Game.stealth:
		return
	if s == Game.State.PLAYING or s == Game.State.WARP:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	else:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if Game.state == Game.State.PLAYING:
			pause()
		elif Game.state == Game.State.PAUSED:
			if menus.controls_panel.visible:
				menus.hide_controls()
			elif menus.settings_panel.visible:
				menus.hide_settings()
			else:
				resume()
	elif event.is_action_pressed("controls"):
		if Game.state == Game.State.PLAYING:
			pause()
			menus.show_controls(menus.pause_panel)
		elif Game.state == Game.State.PAUSED and menus.controls_panel.visible:
			menus.hide_controls()
		elif Game.state == Game.State.MENU:
			if menus.controls_panel.visible:
				menus.hide_controls()
			else:
				menus.show_controls(menus.main_panel)
	elif event.is_action_pressed("map"):
		if Game.state == Game.State.PLAYING and not world.warp_active:
			open_map()
	elif event.is_action_pressed("hud") and Game.state == Game.State.PLAYING:
		Game.show_hud = not Game.show_hud
	elif event.is_action_pressed("inventory") and Game.state == Game.State.PLAYING:
		hud.show_inventory = not hud.show_inventory
	elif event.is_action_pressed("shot"):
		var img := (vp.get_texture() if vp else get_viewport().get_texture()).get_image()
		var path := "user://screenshot_%d.png" % Time.get_unix_time_from_system()
		img.save_png(path)
		Game.msg("Screenshot saved: %s" % ProjectSettings.globalize_path(path), "info")


func _process(dt: float) -> void:
	world.step(minf(dt, 0.1))
	hud.update_hud(world, dt)
