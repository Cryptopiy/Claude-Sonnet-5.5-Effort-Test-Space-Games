extends Node
## Entry scene: builds the permanent scene tree and hands it to Game. The 3D system / ship / player are created later by Game.start_game().
##   Main
##    |- World (Node3D)         all 3D content
##    |   |- Local (Node3D)     parent of frame objects (ship, player ...)
##    |   |- SkyController      environment, sun light, starfield  (M2)
##    |   |- WeatherFX, FaunaManager
##    |   `- System (StarSystem) added by Game.load_system()
##    |- UI (CanvasLayer 10)    Hud, MainMenu, PauseMenu, GalaxyMap, ControlsPanel, SystemMap, InventoryPanel
##    `- Overlay (CanvasLayer 20) WarpEffect (full-screen transitions)

func _ready() -> void:
	var world := Node3D.new()
	world.name = "World"
	add_child(world)
	var local := Node3D.new()
	local.name = "Local"
	world.add_child(local)
	var ui := CanvasLayer.new()
	ui.name = "UI"
	ui.layer = 10
	add_child(ui)
	var overlay := CanvasLayer.new()
	overlay.name = "Overlay"
	overlay.layer = 20
	add_child(overlay)
	Game.register_main(self, world, local, ui, overlay)

	var sky := SkyController.new()
	sky.name = "SkyController"
	world.add_child(sky)
	Game.sky = sky
	var weather := WeatherFX.new()
	weather.name = "WeatherFX"
	world.add_child(weather)
	Game.weather = weather
	var fauna := FaunaManager.new()
	fauna.name = "FaunaManager"
	world.add_child(fauna)
	Game.fauna = fauna

	Game.hud = _add_ui(ui, Hud.new(), "Hud", false)
	Game.system_map = _add_ui(ui, SystemMap.new(), "SystemMap", true)
	Game.inventory_panel = _add_ui(ui, InventoryPanel.new(), "InventoryPanel", true)
	Game.galaxy_map = _add_ui(ui, GalaxyMap.new(), "GalaxyMap", true)
	Game.controls_panel = _add_ui(ui, ControlsPanel.new(), "ControlsPanel", true)
	Game.pause_menu = _add_ui(ui, PauseMenu.new(), "PauseMenu", true)
	Game.main_menu = _add_ui(ui, MainMenu.new(), "MainMenu", false)
	Game.main_menu.visible = true
	Game.hud.visible = false
	Game.system_map.visible = false
	Game.inventory_panel.visible = false
	Game.galaxy_map.visible = false
	Game.controls_panel.visible = false
	Game.pause_menu.visible = false
	var fx := WarpEffect.new()
	fx.name = "WarpEffect"
	fx.process_mode = Node.PROCESS_MODE_ALWAYS
	overlay.add_child(fx)
	Game.warp_fx = fx

func _add_ui(parent: Node, c: Control, nm: String, always: bool) -> Control:
	c.name = nm
	if always:
		c.process_mode = Node.PROCESS_MODE_ALWAYS
	parent.add_child(c)
	return c
