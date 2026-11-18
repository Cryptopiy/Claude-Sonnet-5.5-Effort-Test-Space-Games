class_name Stealth
extends RefCounted
## Test helper: the real window is shrunk + minimised (user is recording video, nothing may show up),
## all rendering happens in an off-screen SubViewport that we can screenshot.

static func hide_window() -> void:
	Engine.get_main_loop().root.transparent_bg = true


static func make_viewport(host: Node, size := Vector2i(1280, 720)) -> SubViewport:
	hide_window()
	var vp := SubViewport.new()
	vp.size = size
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.msaa_3d = Viewport.MSAA_2X
	host.add_child(vp)
	return vp


static func shot(vp: SubViewport, path: String) -> void:
	vp.get_texture().get_image().save_png(path)
