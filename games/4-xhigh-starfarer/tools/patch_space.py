import re
base = r"W:\YouTube\Sonnet 5.5 Effort Test\4. Xhigh Effort"


def rw(path, fn):
    p = base + "\\" + path
    s = open(p, encoding="utf-8").read()
    s2 = fn(s)
    open(p, "w", encoding="utf-8").write(s2)


def world(s):
    s = s.replace("var home_planet: Body\n", "var home_planet: Body\nvar stations: Array = []\nvar belt: AsteroidBelt\n", 1)
    s = s.replace("	bodies.clear()\n	star = null\n	bh = null\n", "	bodies.clear()\n	stations.clear()\n	belt = null\n	star = null\n	bh = null\n", 1)
    build_add = '''	# orbital station around the first planet with an atmosphere, asteroid belt between the middle planets
	for b: Body in bodies:
		if b.is_landable() and b.data.atmo_height > 0.0 and b.data.parent_idx < 0:
			var st := Station.new()
			st.name = "Station"
			bodies_root.add_child(st)
			st.build(b, 9000.0, "%s ORBITAL STATION" % b.display_name.to_upper())
			stations.append(st)
			break
	var outer: Array = []
	for d: PlanetData in sysgen.planets:
		if d.parent_idx < 0:
			outer.append(d.orbit_radius)
	outer.sort()
	if outer.size() >= 4:
		var mid: int = outer.size() / 2
		belt = AsteroidBelt.new()
		belt.name = "Belt"
		bodies_root.add_child(belt)
		belt.build(star, (float(outer[mid - 1]) + float(outer[mid])) * 0.5, star_info.seed + 5)
	# sky orientation: the galaxy as seen from this star'''
    s = s.replace("	# sky orientation: the galaxy as seen from this star", build_add, 1)
    s = s.replace("	if bh:\n		bh.update_state(t)\n	system_built.emit()", "	for st in stations:\n		st.update_state(t)\n	if belt:\n		belt.update_state(t)\n	if bh:\n		bh.update_state(t)\n	system_built.emit()", 1)
    s = s.replace("	if bh:\n		bh.update_state(t)\n	var inp := _gather_input()", "	for st in stations:\n		st.update_state(t)\n	if belt:\n		belt.update_state(t)\n	if bh:\n		bh.update_state(t)\n	var inp := _gather_input()", 1)
    s = s.replace("	if bh:\n		bh.place(origin)\n	ship.global_transform", "	for st in stations:\n		st.place(origin)\n	if belt:\n		belt.place(origin)\n	if bh:\n		bh.place(origin)\n	ship.global_transform", 1)
    s = s.replace("	if bh:\n		list.append([cur.dist(bh.apos), bh])\n	list.append([cur.dist(star.apos), star])", "	if bh:\n		list.append([cur.dist(bh.apos), bh])\n	for st in stations:\n		list.append([cur.dist(st.apos), st])\n	list.append([cur.dist(star.apos), star])", 1)
    s = s.replace("	_bh_forces(dt)\n	if on_foot:", "	_bh_forces(dt)\n	_space_hazards(dt)\n	if on_foot:", 1)
    hz = '''func _space_hazards(dt: float) -> void:
	if ship.frame != null or on_foot:
		return
	var p := ship.abs_pos()
	if belt != null:
		var c := belt.collide(p, 8.0)
		if c.w > 0.0:
			var n := Vector3(c.x, c.y, c.z)
			ship.apos.add_in_place(n * c.w)
			var vn := ship.vel.dot(n)
			if vn < 0.0:
				var rel := ship.rel_vel.dot(n)
				ship.vel -= n * vn * 1.4
				if absf(rel) > 8.0:
					ship._damage(absf(rel) * 0.12)
					ship.shake = 0.8
					Sfx.play("thud", 2.0, 0.7)
					Game.msg("Asteroid impact! %d%% hull" % int(ship.hull), "warn")
	for st in stations:
		var d: float = p.dist(st.apos)
		st.service_cd = maxf(st.service_cd - dt, 0.0)
		if d < 260.0 and (ship.hull < 99.5 or ship.shield < 99.5):
			ship.hull = minf(ship.hull + dt * 25.0, 100.0)
			ship.shield = minf(ship.shield + dt * 40.0, 100.0)
			if st.service_cd <= 0.0:
				Game.msg("Station beacon: repairing hull and recharging shields", "good")
				st.service_cd = 12.0
	var ds := p.dist(star.apos) - star.radius
	if ds < star.radius * 0.8:
		ship._damage(dt * 12.0)
		ship.shake = 0.5
		var away := Vector3(p.x - star.apos.x, p.y - star.apos.y, p.z - star.apos.z).normalized()
		ship.vel += away * 400.0 * dt
		if ds < star.radius * 0.05:
			ship.apos.add_in_place(away * 50.0)
		if frame_count % 120 == 0:
			Game.msg("WARNING: extreme stellar heat - pull away!", "bad")


func _enter_black_hole() -> void:'''
    s = s.replace("func _enter_black_hole() -> void:", hz, 1)
    s = s.replace("	env.adjustment_saturation = 1.08\n	env.adjustment_contrast = 1.05", "	env.adjustment_saturation = 1.0\n	env.adjustment_contrast = 1.03")
    return s


def hud(s):
    return s.replace("	if not w.on_foot:\n		add_body.call(w.star,", "	for st in w.stations:\n		if not w.on_foot or st == w.ship.target_body:\n			add_body.call(st, Color(0.5, 1.0, 0.8), st.display_name, false)\n	if not w.on_foot:\n		add_body.call(w.star,", 1)


def biomes(s):
    return s.replace('"low": _c(0.16, 0.46, 0.15), "mid": _c(0.26, 0.54, 0.18)', '"low": _c(0.13, 0.37, 0.12), "mid": _c(0.24, 0.45, 0.15)').replace('"acc": _c(0.55, 0.62, 0.20)', '"acc": _c(0.44, 0.48, 0.15)')


rw("scripts/world/world.gd", world)
rw("scripts/ui/hud.gd", hud)
rw("scripts/core/biomes.gd", biomes)
print("patched")
