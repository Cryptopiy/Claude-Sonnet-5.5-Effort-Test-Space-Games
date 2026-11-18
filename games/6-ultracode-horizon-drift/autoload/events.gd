extends Node
## Global signal bus. Emit from gameplay modules, listen from UI/audio/effects. Add new signals only at the END of a section.

# --- messaging / HUD ---------------------------------------------------------------------------------------------------
signal hint(text: String, seconds: float)                   # transient centre-bottom hint ("Press F to enter ship")
signal notify(text: String, kind: String)                   # toast: kind = "info" | "good" | "warn" | "danger" | "discover"
signal location_changed(text: String)                       # e.g. "VERDANT  -  Lush world"  (HUD top-left)
signal screen_flash(color: Color, duration: float)          # full-screen flash (damage, warp)
signal poi_discovered(poi_name: String)

# --- game / mode flow --------------------------------------------------------------------------------------------------
signal game_started()
signal game_paused(paused: bool)
signal returned_to_menu()
signal mode_changed(mode: int)                              # Game.Mode.SHIP / FOOT / WARP
signal player_entered_ship()
signal player_exited_ship()
signal system_loaded(system_id: int)

# --- ship --------------------------------------------------------------------------------------------------------------
signal ship_landed(body_index: int)
signal ship_took_off()
signal ship_crashed(severity: float)                        # 0..1
signal atmosphere_entered(body_index: int)
signal atmosphere_left(body_index: int)
signal pulse_changed(active: bool)
signal gear_changed(deployed: bool)

# --- on foot / world ---------------------------------------------------------------------------------------------------
signal resource_collected(resource_id: String, amount: int)
signal inventory_changed()
signal vitals_changed()
signal scan_pulse(local_origin: Vector3)                    # scanner ping fired
signal player_died()

# --- navigation / warp / black hole -------------------------------------------------------------------------------------
signal nav_target_changed(body_index: int)
signal warp_started(system_id: int, kind: String)           # kind = "hyperdrive" | "blackhole"
signal warp_finished(system_id: int)
signal blackhole_warning(level: int, distance: float)       # level 0 = clear, 1 = caution, 2 = danger, 3 = point of no return, 4 = horizon
signal blackhole_entered()
