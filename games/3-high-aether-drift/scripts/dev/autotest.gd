extends Node
## Scripted playthroughs used for verification: godot --path . -- auto:<scenario>
## Scenarios drive the real game through Main.fake_input and save screenshots into .shots/.

var main: Node
var scenario: String = "start"


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("auto:"):
			scenario = a.substr(5)
	_run.call_deferred()


func shot(sname: String, frames: int = 10) -> void:
	for i in frames:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://.shots/%s.png" % sname)
	print("shot ", sname)


func wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout


func press(k: int) -> void:
	main.just[k] = true
	await get_tree().process_frame
	await get_tree().process_frame


func status(tag: String) -> void:
	var s: Ship = main.ship
	var inf: Dictionary = main.uni.info
	print("  env atm=%.3f day=%.2f lit=%.2f sunE=%.2f amb=%s fog=%.5f sky_atm=%s" % [inf.get("atm",-1), inf.get("day",-1), inf.get("lit",-1), main.uni.sun.light_energy, str(main.uni.env.ambient_light_color), main.uni.env.fog_density, str(main.uni.sky_mat.get_shader_parameter("atm"))])
	print("[%s] mode=%d ship_state=%d alt=%.1f speed=%.1f hull=%.0f pos_len=%.1f sys=%s" % [tag, main.mode, s.state, s.altitude, s.speed, s.hull, s.global_position.length(), main.uni.system.name])


func tele_ship(body_name: String, local_pos: Vector3, look_local: Vector3) -> void:
	var s: Ship = main.ship
	if s.state == Ship.State.LANDED:
		s.take_off(main.uni)
	var b: PlanetBody = main.uni.bodies[main.uni.system.body_index(body_name)]
	var w := b.to_global(local_pos)
	main.uni.set_origin_at_world(w)
	s.global_position = Vector3.ZERO
	var up := (b.global_basis * local_pos.normalized())
	var fwd := (b.global_basis * look_local).normalized()
	s.global_basis = Basis.looking_at(fwd, up)
	s.velocity = Vector3.ZERO
	s.vg = Vector3.ZERO
	s.throttle = 0.0
	s.lift_assist = 0.0


func _run() -> void:
	await get_tree().process_frame
	print("autotest: ", scenario)
	var uni: Universe = main.uni
	if scenario == "menu":
		await wait(2.0)
		await shot("t_menu", 3)
		main.menus._show_controls(main.menus.main_panel)
		await shot("t_controls", 3)
		get_tree().quit()
		return
	main._start_game()
	match scenario:
		"start":
			await wait(1.0)
			await shot("t_start", 5)
		"foot":
			await wait(1.0)
			await press(KEY_E)
			status("exit")
			await wait(0.3)
			main.fake_input = {"move": Vector2(0, 1)}
			await wait(3.0)
			await shot("t_foot_walk", 3)
			main.fake_input = {"move": Vector2(0, 1), "sprint": true, "jump_held": true}
			await wait(1.5)
			print("pitch ", main.player.pitch, " camrot ", main.camera.rotation, " pos ", main.player.position.length(), " alt ", main.player.position.length() - main.player.planet.ground_radius(main.player.position.normalized()), " look_pool ", main.player.look_pool)
			await shot("t_foot_jet", 3)
			main.fake_input = {}
			await press(KEY_Q)
			await wait(0.6)
			await shot("t_foot_scan", 3)
			main.player.set_third_person(true)
			await wait(0.5)
			await shot("t_foot_third", 3)
			main.player.set_third_person(false)
			# walk back to the ship
			var pl: PlanetBody = main.player.planet
			main.player.spawn_at(pl, main.ship.position + main.ship.basis.x * 7.0, -main.ship.basis.z)
			await wait(0.5)
			await press(KEY_E)
			await wait(0.3)
			status("reenter")
			await shot("t_foot_back", 3)
		"takeoff":
			await wait(0.5)
			main.fake_input = {"takeoff": true}
			await wait(1.0)
			status("takeoff")
			main.fake_input = {"thrust": 1.0, "vert": 1.0}
			await wait(4.0)
			await shot("t_takeoff", 3)
			status("climb")
		"space":
			tele_ship("Verdance", Vector3(0.3, 1, 0.2).normalized() * 12000.0, Vector3(0, -1, 0))
			await wait(1.5)
			await shot("t_space_planet", 5)
			await press(KEY_SPACE)
			await wait(3.0)
			status("pulse")
			await shot("t_pulse", 3)
			tele_ship("Verdance", Vector3(0.3, 1, 0.2).normalized() * 1e5, Vector3(0, -1, 0))
			await wait(1.0)
			await shot("t_space_far", 5)
		"land":
			var b: PlanetBody = uni.bodies[uni.system.start_planet]
			var sd := b.data.site_dir
			var t1 := sd.cross(Vector3.RIGHT).normalized()
			var h := b.data.terrain.site_h
			# hover 120 m up over the site, then descend with F
			tele_ship(b.data.name, sd * (b.data.radius + h + 120.0) + t1 * 130.0, t1)
			await wait(1.0)
			await shot("t_land_approach", 3)
			status("hover")
			main.fake_input = {"vert": -1.0}
			for i in 40:
				await wait(0.5)
				if main.ship.state == Ship.State.LANDED:
					break
			status("landed?")
			await shot("t_landed", 3)
		"entry":
			var b2: PlanetBody = uni.bodies[uni.system.start_planet]
			var sd2 := b2.data.site_dir
			tele_ship(b2.data.name, sd2 * (b2.data.radius + 3500.0), -sd2)
			await wait(0.3)
			main.fake_input = {"thrust": 1.0, "boost": true}
			for i in 6:
				await wait(1.0)
				status("entry%d" % i)
				if i == 3:
					await shot("t_entry", 2)
		"bh":
			var bh: BlackHole = uni.bh
			var rel := Vector3(1, 0.1, 0.4).normalized() * 380000.0
			if main.ship.state == Ship.State.LANDED:
				main.ship.take_off(uni)
			uni.set_origin_at_world(bh.global_position + rel)
			main.ship.global_position = Vector3.ZERO
			main.ship.global_basis = Basis.looking_at(-rel.normalized(), Vector3.UP)
			main.ship.velocity = Vector3.ZERO
			await wait(1.0)
			await shot("t_bh_far", 4)
			rel = rel.normalized() * 110000.0
			uni.set_origin_at_world(bh.global_position + rel - main.ship.global_position)
			main.ship.global_position = Vector3.ZERO
			await wait(1.0)
			await shot("t_bh_mid", 4)
			for i in 90:
				await wait(0.5)
				if i % 4 == 0:
					status("bh%d" % i)
				if i == 4:
					await shot("t_bh_close", 2)
				if not main.trans.is_empty() and i % 2 == 0:
					await shot("t_bh_trans%d" % i, 1)
				if main.current_id != 0:
					break
			await wait(3.0)
			status("after")
			await shot("t_bh_after", 5)
		"skydbg":
			tele_ship("Verdance", Vector3(0.3, 1, 0.2).normalized() * 12000.0, Vector3(0, 0.3, 1))
			await wait(1.0)
			var variants := {
				"base": func(): pass,
				"nodust": func(): main.dust.visible = false; main.dust.set_process(false),
				"nohud": func(): main.hud.set_visible_hud(false),
				"noatmo": func(): for b in uni.bodies: if b.atmo_mesh: b.atmo_mesh.visible = false,
				"noclouds": func(): for b in uni.bodies: if b.cloud_mesh: b.cloud_mesh.visible = false,
				"nofog": func(): uni.env.fog_enabled = false,
				"noglow": func(): uni.env.glow_enabled = false,
			}
			for k in variants:
				variants[k].call()
				await get_tree().process_frame
				await get_tree().process_frame
				await RenderingServer.frame_post_draw
				var img := get_viewport().get_texture().get_image()
				var c := img.get_pixel(120, 120)
				print("variant ", k, " px=", c)
				main.dust.visible = true if k == "nodust" else main.dust.visible
		"ui":
			await wait(0.5)
			tele_ship("Verdance", Vector3(0.3, 1, 0.2).normalized() * 1e5, Vector3(0, -1, 0))
			await wait(0.5)
			main._open_map()
			await wait(0.5)
			main.map.selected = 7
			await shot("t_map_galaxy", 5)
			main.map._toggle_mode()
			await shot("t_map_system", 5)
			main.map.mode = 0
			main._close_map()
			main._pause()
			await shot("t_pause", 5)
			main._resume()
		"perf":
			var b3: PlanetBody = uni.bodies[uni.system.start_planet]
			var sd3 := b3.data.site_dir
			var t13 := sd3.cross(Vector3.RIGHT).normalized()
			tele_ship(b3.data.name, sd3 * (b3.data.radius + b3.data.terrain.site_h + 150.0) + t13 * 130.0, t13)
			main.fake_input = {"thrust": 1.0, "boost": false}
			for i in 14:
				await wait(1.0)
				var lod: TerrainLod = b3.lod
				print("perf t=%d fps=%d patches=%d lvl=%d cells=%d alt=%.0f speed=%.0f" % [i, Engine.get_frames_per_second(), lod.patch_count, lod.max_level_used, b3.props.cells.size(), main.ship.altitude, main.ship.speed])
			await shot("t_perf_low", 3)
		"mine":
			await wait(1.0)
			await press(KEY_E)
			await wait(1.5)
			var pl2: PlanetBody = main.player.planet
			var pf: PropField = pl2.props
			print("site_res: ", pf.site_res.size())
			var r: Dictionary = pf.site_res[0]
			var rp: Vector3 = r["pos"]
			var up2 := rp.normalized()
			var t2 := up2.cross(Vector3.RIGHT).normalized()
			var from_p := rp + t2 * 7.0
			from_p = from_p.normalized() * (pl2.data.radius + pl2.data.terrain.ground(from_p.normalized()) + 0.3)
			main.player.spawn_at(pl2, from_p, (rp - from_p))
			main.player.pitch = -0.08
			await wait(0.5)
			main.fake_input = {"fire": true}
			await wait(0.8)
			await shot("t_mine_beam", 2)
			await wait(1.5)
			main.fake_input = {}
			print("inventory: ", main.player.inventory, " cells ", main.player.power_cells)
			# monolith / supply interaction
			await wait(0.5)
			for n in pf.poi_nodes:
				print("poi ", n.get_meta("poi", "?"), " ", n.position.length())
			if pf.poi_nodes.size() > 0:
				var n0: Node3D = pf.poi_nodes[0]
				var np: Vector3 = n0.position
				var sp2 := np + np.cross(Vector3.RIGHT).normalized() * 4.0
				main.player.spawn_at(pl2, sp2.normalized() * (pl2.data.radius + pl2.data.terrain.ground(sp2.normalized()) + 0.3), (np - sp2))
				await wait(0.5)
				print("interact: ", main.player.interact_info)
				await press(KEY_E)
				await wait(0.3)
				print("units: ", main.units, " cells ", main.player.power_cells)
		"warp":
			tele_ship("Verdance", Vector3(0.3, 1, 0.2).normalized() * 1e5, Vector3(0, -1, 0))
			await wait(0.5)
			main._on_warp_requested(7)
			for i in 20:
				await wait(0.5)
			status("warped")
			await shot("t_warp_arrived", 5)
		_:
			pass
	print("autotest done")
	get_tree().quit()
