extends RefCounted
## Camera framing check (one run, few shots): chase cam while hovering + landed on the pad, cockpit cam eye-point variants.
##   godot ... -- --autostart --preset=air:1:150 --test=res://tests/ship_cam.gd [--cp=0,0,0;0,0.12,0.35]
## Saves .previews/sc_*.png

var game: Node
var ship: Ship

func _wait(sec: float) -> void:
	var t := 0.0
	while t < sec:
		await game.get_tree().process_frame
		t += game.get_process_delta_time()

func _shot(tag: String) -> void:
	await game.get_tree().process_frame
	await game.get_tree().process_frame
	var img := game.get_viewport().get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path("res://.previews/sc_%s.png" % tag))
	print("[sc] shot ", tag)

func run(g: Node) -> void:
	game = g
	ship = g.ship
	var variants: Array = [Vector3(0, 0, 0), Vector3(0, 0.12, 0.35), Vector3(0, 0.22, 0.8), Vector3(0, 0.3, 0.35)]
	for a in OS.get_cmdline_user_args():
		var s := String(a)
		if s.begins_with("--cp="):
			variants = []
			for item in s.substr(5).split(";"):
				var c := item.split(",")
				variants.append(Vector3(float(c[0]), float(c[1]), float(c[2])))
	await _wait(3.0)
	await _shot("chase_air")
	ship.rig.toggle()
	for i in variants.size():
		ship.rig.cockpit_eye = variants[i]
		await _wait(0.5)
		await _shot("cockpit_%d" % i)
	ship.rig.toggle()
	# landed on the start pad: chase cam
	var def := Frame.anchor_def()
	ship.place_landed(PoiSites.start_dir(def), 0.0)
	await _wait(2.0)
	await _shot("chase_landed")
	print("PASS cam")
