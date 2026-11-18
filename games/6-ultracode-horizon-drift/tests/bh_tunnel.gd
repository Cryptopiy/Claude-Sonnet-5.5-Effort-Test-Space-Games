extends RefCounted
## Renders the warp overlay in fixed states WITHOUT swapping the world (cheap visual iteration on the tunnel shader):
##   --test=res://tests/bh_tunnel.gd -- --autostart --preset=bh:400 [--out=.previews/tn] [--states="hyperdrive:0.35:0;hyperdrive:0.7:0;hyperdrive:1:0;hyperdrive:1:0.6;blackhole:0.35:0;blackhole:0.7:0;blackhole:1:0;blackhole:1:0.6"]
## state = kind:progress:flash

func _arg(name: String, default: String) -> String:
	for a in OS.get_cmdline_user_args():
		var s := String(a)
		if s.begins_with("--" + name + "="):
			return s.substr(name.length() + 3)
	return default

func run(game: Node) -> void:
	var out := _arg("out", ".previews/tn")
	var states := _arg("states", "hyperdrive:0.35:0;hyperdrive:0.7:0;hyperdrive:1:0;hyperdrive:1:0.6;blackhole:0.35:0;blackhole:0.7:0;blackhole:1:0;blackhole:1:0.6").split(";", false)
	var fx = game.warp_fx
	for i in 8:
		await game.get_tree().process_frame
	var n := 0
	for st in states:
		var p := st.split(":")
		fx.call("show_progress", float(p[1]), String(p[0]))
		fx.set("_flash", float(p[2]))
		fx.set("_speed", 0.75)
		fx.call("_push")
		for i in 6:
			await game.get_tree().process_frame
		var img: Image = game.get_viewport().get_texture().get_image()
		var full := ProjectSettings.globalize_path("res://%s_%d_%s_%s_%s.png" % [out, n, p[0], p[1], p[2]])
		DirAccess.make_dir_recursive_absolute(full.get_base_dir())
		img.save_png(full)
		print("[bh_tunnel] saved ", full)
		n += 1
	fx.set("_flash", 0.0)
	fx.call("show_progress", 0.0)
	print("[bh_tunnel] done, overlay visible=", (fx.get("_rect") as ColorRect).visible)
