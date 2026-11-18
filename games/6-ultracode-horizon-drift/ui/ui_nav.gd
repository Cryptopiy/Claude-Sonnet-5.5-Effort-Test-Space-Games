class_name UINav
extends RefCounted
## Navigation target helpers shared by the HUD (T key), the system map and the markers.

static func set_target(body_index: int, announce: bool = true) -> void:
	if Universe.system == null:
		return
	if body_index >= Universe.system.bodies.size():
		body_index = -1
	Game.nav_target = body_index
	Events.nav_target_changed.emit(body_index)
	if announce:
		if body_index >= 0:
			var b: BodyDef = Universe.system.bodies[body_index]
			Events.notify.emit("Navigation target: %s" % b.name, "info")
		else:
			Events.notify.emit("Navigation target cleared", "info")

## T key: -1 -> nearest-first cycle through every body -> -1
static func cycle() -> void:
	var sys := Universe.system
	if sys == null or sys.bodies.is_empty():
		return
	var order: Array = []
	for b in sys.bodies:
		order.append(b.index)
	# sort by distance from the camera/ship so the first press selects the closest body
	var origin := Game.ship.global_position if Game.ship != null else Vector3.ZERO
	if Game.mode == Game.Mode.FOOT and Game.player != null:
		origin = Game.player.global_position
	order.sort_custom(func(a: int, b: int) -> bool:
		var da := (Frame.to_local(Universe.body_pos(a)) - origin).length()
		var db := (Frame.to_local(Universe.body_pos(b)) - origin).length()
		return da < db)
	var cur := order.find(Game.nav_target)
	var next := cur + 1
	if next >= order.size():
		set_target(-1)
	else:
		set_target(order[next])
