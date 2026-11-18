class_name AudioRecipes
extends RefCounted
## Catalog + dispatcher of every procedurally generated sound. `build(name)` synthesises one sound and returns the dictionary produced by
## AudioDSP.pack: {buf, right, sr, loop}. `META` holds the default mix settings per sound (bus, level, cooldown, pitch variation).

# Mix defaults. bus: SFX | UI | Engine | Ambience.  db: level offset applied at play time.  cd: minimum seconds between two plays of the same name.
# pv: random pitch variation (+-fraction).  vol3d: unit_size for 3D playback.  Missing keys fall back to DEFAULT_META.
const DEFAULT_META := {"bus": "SFX", "db": 0.0, "cd": 0.04, "pv": 0.0, "unit": 12.0}

const META := {
	# ---- UI -------------------------------------------------------------------------------------------------------------------
	"ui_click": {"bus": "UI", "db": -5.0, "cd": 0.03, "pv": 0.02},
	"ui_hover": {"bus": "UI", "db": -12.0, "cd": 0.05, "pv": 0.03},
	"ui_open": {"bus": "UI", "db": -5.0, "cd": 0.15},
	"ui_back": {"bus": "UI", "db": -6.0, "cd": 0.15},
	"ui_error": {"bus": "UI", "db": -6.0},
	"ui_warp_confirm": {"bus": "UI", "db": -5.0, "cd": 1.0},
	"ui_start": {"bus": "UI", "db": -2.0, "cd": 3.0},
	"notify": {"bus": "UI", "db": -7.0, "cd": 0.15},
	"notify_good": {"bus": "UI", "db": -7.0, "cd": 0.15},
	"notify_warn": {"bus": "UI", "db": -6.0, "cd": 0.2},
	"notify_danger": {"bus": "UI", "db": -4.0, "cd": 0.3},
	"pickup": {"bus": "UI", "db": -6.0, "pv": 0.03},
	"resource_collect": {"bus": "UI", "db": -4.0, "cd": 0.06, "pv": 0.02},
	"discover": {"bus": "UI", "db": -6.0, "cd": 1.0},
	"interact": {"bus": "UI", "db": -8.0},
	# ---- ship -----------------------------------------------------------------------------------------------------------------
	"gear_down": {"db": -4.0, "cd": 0.8, "unit": 25.0},
	"gear_up": {"db": -4.0, "cd": 0.8, "unit": 25.0},
	"landed": {"db": -2.0, "cd": 1.0, "unit": 40.0},
	"crash": {"db": -4.0, "cd": 0.8, "unit": 80.0},          # measured +0.7 dBFS on the SFX bus at 0 dB: hero sounds are kept <= -3 dBFS before the limiter
	"takeoff": {"db": -3.0, "cd": 2.0, "unit": 60.0},
	"atmo_enter": {"db": -5.0, "cd": 3.0},
	"atmo_leave": {"db": -6.0, "cd": 3.0},
	"pulse_on": {"db": -3.0, "cd": 1.0},
	"pulse_off": {"db": -4.0, "cd": 0.8},
	"airlock": {"db": -4.0, "cd": 1.0, "unit": 20.0},
	"door": {"db": -6.0, "cd": 0.5, "unit": 20.0},
	"warn_beep": {"bus": "UI", "db": -7.0, "cd": 0.2},
	"scan_ping": {"db": -4.0, "cd": 0.5, "unit": 60.0},
	"warp_charge": {"db": -3.0, "cd": 3.0},
	"warp_jump": {"db": -4.5, "cd": 2.0},                    # measured -1.2 dBFS at -2 dB
	"warp_arrive": {"db": -3.0, "cd": 2.0},
	"blackhole_enter": {"db": -4.0, "cd": 6.0},              # measured -1.1 dBFS at -1 dB
	# ---- body -----------------------------------------------------------------------------------------------------------------
	"jump": {"db": -8.0, "cd": 0.2, "pv": 0.04},
	"land_foot": {"db": -3.0, "cd": 0.15, "pv": 0.05},       # 99% of its energy is < 150 Hz: lifted so the thud survives small speakers (player scales it by impact)
	"jetpack_puff": {"db": -8.0, "cd": 0.15, "pv": 0.05},
	"hurt": {"db": -4.0, "cd": 0.3, "pv": 0.03},
	"death": {"db": -2.0, "cd": 2.0},
	# ---- ambience one-shots -----------------------------------------------------------------------------------------------------
	"bird_0": {"db": -14.0, "unit": 30.0},
	"bird_1": {"db": -14.0, "unit": 30.0},
	"bird_2": {"db": -14.0, "unit": 30.0},
	"frog_0": {"db": -14.0, "unit": 25.0},
	"frog_1": {"db": -14.0, "unit": 25.0},
	"ice_creak": {"db": -12.0, "unit": 40.0},
	"geiger_tick": {"db": -12.0, "cd": 0.0, "pv": 0.05},
	"spore_pop": {"db": -14.0, "unit": 20.0, "pv": 0.12},
	"crystal_chime": {"db": -16.0, "unit": 40.0, "pv": 0.0},
	"wind_gust": {"db": -12.0, "unit": 200.0},
	"thunder_far": {"db": -10.0, "unit": 400.0},
	# ---- continuous loops (played through LoopVoice) ---------------------------------------------------------------------------
	"eng_rumble": {"bus": "Engine", "db": -4.0},
	"eng_roar": {"bus": "Engine", "db": -9.0},
	"eng_whine": {"bus": "Engine", "db": -14.0},
	"eng_boost": {"bus": "Engine", "db": -9.0},
	"eng_pulse": {"bus": "Engine", "db": -6.0},
	"eng_wind": {"bus": "Engine", "db": -8.0},
	"jetpack": {"bus": "SFX", "db": -8.0},
	"mining_beam": {"bus": "SFX", "db": -9.0},
	"alarm": {"bus": "UI", "db": -9.0},
	"blackhole_rumble": {"bus": "Engine", "db": -3.0},
	"warp_tunnel": {"bus": "Engine", "db": -9.0},
	"amb_wind_low": {"bus": "Ambience", "db": 2.0},
	"amb_wind_mid": {"bus": "Ambience", "db": -1.0},
	"amb_howl": {"bus": "Ambience", "db": -4.0},
	"amb_rustle": {"bus": "Ambience", "db": -6.0},
	"amb_crickets": {"bus": "Ambience", "db": -8.0},
	"amb_space": {"bus": "Ambience", "db": -2.0},
	"amb_suit": {"bus": "Ambience", "db": -5.0},
	"amb_rumble": {"bus": "Ambience", "db": 1.0},
	"amb_crackle": {"bus": "Ambience", "db": -4.0},
	"amb_bubbles": {"bus": "Ambience", "db": -5.0},
	"amb_waves": {"bus": "Ambience", "db": 0.0},
	"amb_crystal": {"bus": "Ambience", "db": -4.0},
	"amb_toxic": {"bus": "Ambience", "db": -3.0},
	"amb_hum": {"bus": "Ambience", "db": -5.0},
	"amb_rain": {"bus": "Ambience", "db": -3.0},
}

## footstep loudness trim per surface (dB), derived from the RMS of each surface's synthesised steps (tests/audio_analyze.py)
const STEP_TRIM_DB := {"rock": 5.0, "grass": 1.5, "metal": 2.0, "snow": 0.5, "ash": 0.5, "splash": 0.0, "sand": -0.5, "mud": -0.5}

## friendly aliases other modules may use (resolved by `resolve`)
const ALIASES := {
	"ui_select": "ui_click", "ui_confirm": "ui_click", "click": "ui_click", "ui_hover_tick": "ui_hover", "hover": "ui_hover",
	"ui_close": "ui_back", "back": "ui_back", "ui_open_panel": "ui_open", "open": "ui_open",
	"warn": "warn_beep", "warning": "warn_beep", "alert": "warn_beep", "success": "notify_good", "info": "notify",
	"collect": "resource_collect", "mine_collect": "resource_collect", "scan": "scan_ping", "ping": "scan_ping",
	"land": "landed", "touchdown": "landed", "liftoff": "takeoff", "gear": "gear_down", "hyperdrive": "warp_jump",
	"warp": "warp_jump", "warp_start": "warp_charge", "blackhole": "blackhole_enter", "step": "land_foot", "footstep_land": "land_foot",
	"jetpack_start": "jetpack_puff", "damage": "hurt", "pain": "hurt", "die": "death", "enter_ship": "airlock", "exit_ship": "airlock",
	"nav_set": "interact", "ui_nav": "interact", "pulse": "pulse_on", "pulse_engage": "pulse_on", "pulse_disengage": "pulse_off",
}

## variant groups: sfx("bird") picks one of bird_0..2 etc.
const VARIANTS := {"bird": 3, "frog": 2}

# ---------------------------------------------------------------------------------------------------------------------------------
# build order (important first: UI + menu ambience, then ship, then the rest, then biome ambiences)
# ---------------------------------------------------------------------------------------------------------------------------------
static func build_order() -> PackedStringArray:
	var o := PackedStringArray()
	for n in ["ui_click", "ui_hover", "ui_open", "ui_back", "ui_error", "notify", "notify_good", "notify_warn", "notify_danger",
			"amb_space", "ui_start", "ui_warp_confirm", "interact", "pickup", "resource_collect", "warn_beep",
			"eng_rumble", "eng_roar", "eng_whine", "eng_boost", "eng_pulse", "eng_wind", "alarm",
			"gear_down", "gear_up", "landed", "takeoff", "pulse_on", "pulse_off", "scan_ping", "airlock", "door", "discover",
			"crash", "atmo_enter", "atmo_leave", "warp_charge", "warp_jump", "warp_arrive", "warp_tunnel", "blackhole_enter", "blackhole_rumble"]:
		o.append(n)
	for s in RecipesWorld.SURFACES:
		for v in 4:
			o.append("step_%s_%d" % [s, v])
	for n2 in ["jump", "land_foot", "jetpack_puff", "jetpack", "mining_beam", "hurt", "death", "amb_suit",
			"amb_wind_low", "amb_wind_mid", "amb_howl", "amb_rustle", "amb_crickets", "amb_rumble", "amb_crackle", "amb_bubbles",
			"amb_waves", "amb_crystal", "amb_toxic", "amb_hum", "amb_rain",
			"bird_0", "bird_1", "bird_2", "frog_0", "frog_1", "ice_creak", "geiger_tick", "spore_pop", "crystal_chime", "wind_gust", "thunder_far"]:
		o.append(n2)
	return o

static func meta(sound: String) -> Dictionary:
	var base: String = sound
	if sound.begins_with("step_"):
		# per-surface loudness equalisation (RMS of the synthesised steps differs by up to 8 dB: rock is a low thud, sand/snow are hissy)
		var parts: PackedStringArray = sound.split("_")
		var surf: String = parts[1] if parts.size() > 1 else ""
		return {"bus": "SFX", "db": -8.0 + float(STEP_TRIM_DB.get(surf, 0.0)), "cd": 0.0, "pv": 0.05, "unit": 12.0}
	var m: Dictionary = META.get(base, {})
	var out: Dictionary = DEFAULT_META.duplicate()
	for k in m:
		out[k] = m[k]
	return out

## map aliases / variant groups to a concrete sound name ("" if unknown)
static func resolve(sound_name: String, rng: RandomNumberGenerator = null) -> String:
	var n: String = sound_name
	if ALIASES.has(n):
		n = ALIASES[n]
	if VARIANTS.has(n):
		var k: int = int(VARIANTS[n])
		var v: int = (rng.randi() % k) if rng != null else 0
		n = "%s_%d" % [n, v]
	if META.has(n) or n.begins_with("step_"):
		return n
	return ""

# ---------------------------------------------------------------------------------------------------------------------------------
# synthesis entry point
# ---------------------------------------------------------------------------------------------------------------------------------
static func build(sound: String) -> Dictionary:
	var seed: int = sound.hash() & 0x7FFFFFFF
	if sound.begins_with("step_"):
		var p := sound.split("_")
		if p.size() >= 3:
			return RecipesWorld.step(p[1], int(p[2]), seed)
	if sound.begins_with("bird_"):
		return RecipesWorld.bird(int(sound.substr(5)), seed)
	if sound.begins_with("frog_"):
		return RecipesWorld.frog(int(sound.substr(5)), seed)
	match sound:
		# UI
		"ui_click": return RecipesUI.ui_click(seed)
		"ui_hover": return RecipesUI.ui_hover(seed)
		"ui_open": return RecipesUI.ui_open(seed)
		"ui_back": return RecipesUI.ui_back(seed)
		"ui_error": return RecipesUI.ui_error(seed)
		"ui_warp_confirm": return RecipesUI.ui_warp_confirm(seed)
		"ui_start": return RecipesUI.ui_start(seed)
		"notify": return RecipesUI.notify(seed)
		"notify_good": return RecipesUI.notify_good(seed)
		"notify_warn": return RecipesUI.notify_warn(seed)
		"notify_danger": return RecipesUI.notify_danger(seed)
		"pickup": return RecipesUI.pickup(seed)
		"resource_collect": return RecipesUI.resource_collect(seed)
		"discover": return RecipesUI.discover(seed)
		"interact": return RecipesUI.interact(seed)
		# ship
		"gear_down": return RecipesShip.gear_down(seed)
		"gear_up": return RecipesShip.gear_up(seed)
		"landed": return RecipesShip.landed(seed)
		"crash": return RecipesShip.crash(seed)
		"takeoff": return RecipesShip.takeoff(seed)
		"atmo_enter": return RecipesShip.atmo_enter(seed)
		"atmo_leave": return RecipesShip.atmo_leave(seed)
		"pulse_on": return RecipesShip.pulse_on(seed)
		"pulse_off": return RecipesShip.pulse_off(seed)
		"airlock": return RecipesShip.airlock(seed)
		"door": return RecipesShip.door(seed)
		"warn_beep": return RecipesShip.warn_beep(seed)
		"scan_ping": return RecipesShip.scan_ping(seed)
		"warp_charge": return RecipesShip.warp_charge(seed)
		"warp_jump": return RecipesShip.warp_jump(seed)
		"warp_arrive": return RecipesShip.warp_arrive(seed)
		"warp_tunnel": return RecipesShip.warp_tunnel(seed)
		"blackhole_enter": return RecipesShip.blackhole_enter(seed)
		"blackhole_rumble": return RecipesShip.blackhole_rumble(seed)
		"alarm": return RecipesShip.alarm(seed)
		# engine layers
		"eng_rumble": return RecipesEngine.eng_rumble(seed)
		"eng_roar": return RecipesEngine.eng_roar(seed)
		"eng_whine": return RecipesEngine.eng_whine(seed)
		"eng_boost": return RecipesEngine.eng_boost(seed)
		"eng_pulse": return RecipesEngine.eng_pulse(seed)
		"eng_wind": return RecipesEngine.eng_wind(seed)
		"jetpack": return RecipesEngine.jetpack(seed)
		"mining_beam": return RecipesEngine.mining_beam(seed)
		# body
		"jump": return RecipesWorld.jump(seed)
		"land_foot": return RecipesWorld.land_foot(seed)
		"jetpack_puff": return RecipesWorld.jetpack_puff(seed)
		"hurt": return RecipesWorld.hurt(seed)
		"death": return RecipesWorld.death(seed)
		# ambience one-shots
		"ice_creak": return RecipesWorld.ice_creak(seed)
		"geiger_tick": return RecipesWorld.geiger_tick(seed)
		"spore_pop": return RecipesWorld.spore_pop(seed)
		"crystal_chime": return RecipesWorld.crystal_chime(seed)
		"wind_gust": return RecipesWorld.wind_gust(seed)
		"thunder_far": return RecipesWorld.thunder_far(seed)
		# ambience loops
		"amb_wind_low": return RecipesWorld.amb_wind_low(seed)
		"amb_wind_mid": return RecipesWorld.amb_wind_mid(seed)
		"amb_howl": return RecipesWorld.amb_howl(seed)
		"amb_rustle": return RecipesWorld.amb_rustle(seed)
		"amb_crickets": return RecipesWorld.amb_crickets(seed)
		"amb_space": return RecipesWorld.amb_space(seed)
		"amb_suit": return RecipesWorld.amb_suit(seed)
		"amb_rumble": return RecipesWorld.amb_rumble(seed)
		"amb_crackle": return RecipesWorld.amb_crackle(seed)
		"amb_bubbles": return RecipesWorld.amb_bubbles(seed)
		"amb_waves": return RecipesWorld.amb_waves(seed)
		"amb_crystal": return RecipesWorld.amb_crystal(seed)
		"amb_toxic": return RecipesWorld.amb_toxic(seed)
		"amb_hum": return RecipesWorld.amb_hum(seed)
		"amb_rain": return RecipesWorld.amb_rain(seed)
	return {}
