extends Node
# Debug: why is the ship dark in deep space?
var main: Node

func _ready() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	_run()

func _wait(sec: float) -> void:
	var t0 := Time.get_ticks_msec()
	while float(Time.get_ticks_msec() - t0) / 1000.0 < sec:
		await get_tree().process_frame

func _shot(nm: String) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_tree().root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://scratch/ui/" + nm + ".png"))

func _run() -> void:
	await _wait(2.0)
	main._on_start_game()
	await _wait(3.0)
	var w: SpaceWorld = main.world
	var dl: DirectionalLight3D = w.deep_light
	print("deep_light visible=", dl.visible, " energy=", dl.light_energy, " mask=", dl.light_cull_mask, " shadow=", dl.shadow_enabled, " color=", dl.light_color)
	print("light -Z dir=", -dl.global_transform.basis.z, " sun_dir_view=", w.sun_dir_view)
	print("ship fwd=", -main.pc.ship.global_transform.basis.z, " frame=", w.frame_idx)
	print("ambient=", w.env.ambient_light_color, " e=", w.env.ambient_light_energy)
	var ship: Ship = main.pc.ship
	var cnt := 0
	var layers := {}
	var stack: Array = [ship.model]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is VisualInstance3D:
			cnt += 1
			layers[(n as VisualInstance3D).layers] = true
		for c in n.get_children():
			stack.append(c)
	print("ship visual instances=", cnt, " layer values=", layers.keys())
	# try switching shadow off
	dl.shadow_enabled = false
	await _wait(0.5)
	await _shot("light_noshadow")
	dl.shadow_enabled = true
	await _wait(0.5)
	await _shot("light_shadow")
	get_tree().quit()
