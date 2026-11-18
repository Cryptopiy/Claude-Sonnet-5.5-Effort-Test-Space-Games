class_name PlayerVitals
extends RefCounted
## Exosuit vitals + environmental hazards for the on-foot player (module M4).
##   health      0..1   damaged when protection is gone while a hazard is active (or by liquids)
##   protection  0..1   hazard shield, drains with hazard level, recharged by Sodium / near the ship / when safe
##   jetpack     0..1   fuel, drained by thrust, refilled on the ground
##   stamina     0..1   sprint endurance
## Temperature comes from the body definition (temp_day_c / temp_night_c) blended by the sun elevation at the player's position.

const HAZARD_THRESHOLD := 0.04
const PROTECTION_DRAIN := 0.016        # per second at hazard level 1.0
const DAMAGE_RATE := 0.022             # health per second with no protection (+ level * DAMAGE_LEVEL)
const DAMAGE_LEVEL := 0.05
const SODIUM_PER_USE := 2
const SODIUM_RESTORE := 0.22

var health: float = 1.0
var protection: float = 1.0
var jetpack: float = 1.0
var stamina: float = 1.0
var temp_c: float = 20.0           # ambient temperature at the player
var body_temp_c: float = 20.0      # smoothed copy shown on the HUD
var hazard: String = ""            # "" | "Extreme heat" | "Extreme cold" | "Toxic atmosphere" | "Radiation" | "Lava" | "Acid"
var hazard_level: float = 0.0      # 0..1
var exhausted: bool = false
var dead: bool = false

var _since_damage: float = 10.0
var _sodium_cd: float = 0.0
var _warn_cd: float = 0.0
var _flash_cd: float = 0.0
var _last_hazard: String = ""
var _jet_recharge_delay: float = 0.0
var _sprint_recharge_delay: float = 0.0

func reset(full_health: float = 1.0) -> void:
	health = full_health
	protection = 1.0
	jetpack = 1.0
	stamina = 1.0
	hazard = ""
	hazard_level = 0.0
	exhausted = false
	dead = false
	_since_damage = 10.0
	_last_hazard = ""

## ambient temperature (deg C) for a body at a given sun elevation (sine of the elevation angle)
static func ambient_temp(def: BodyDef, sun_sin: float) -> float:
	if def == null:
		return 20.0
	var d := smoothstep(-0.10, 0.28, sun_sin)
	return lerpf(def.temp_night_c, def.temp_day_c, d)

## Compute hazard type and level (0..1) from temperature / toxicity / radiation / liquids
func evaluate_hazard(def: BodyDef, sun_sin: float, liquid: String, liquid_depth: float) -> void:
	temp_c = ambient_temp(def, sun_sin)
	var best := 0.0
	var label := ""
	if def != null:
		var heat := clampf((temp_c - 42.0) / 45.0, 0.0, 1.0)
		var cold := clampf((-8.0 - temp_c) / 65.0, 0.0, 1.0)
		var tox: float = def.toxicity if def.has_atmosphere else 0.0
		var rad: float = def.radiation
		if heat > best: best = heat; label = "Extreme heat"
		if cold > best: best = cold; label = "Extreme cold"
		if tox > best: best = tox; label = "Toxic atmosphere"
		if rad > best: best = rad; label = "Radiation"
	if liquid_depth > 0.12 and (liquid == "lava" or liquid == "acid"):
		var l := clampf(0.55 + liquid_depth * 0.3, 0.0, 1.0)
		if liquid == "acid": l = clampf(0.4 + liquid_depth * 0.2, 0.0, 0.8)
		if l > best:
			best = l
			label = "Lava" if liquid == "lava" else "Acid"
	if best < HAZARD_THRESHOLD:
		best = 0.0
		label = ""
	hazard_level = best
	hazard = label

## advance one frame. near_ship: standing next to the landed ship (life support). Returns true when the player died this frame.
func update(dt: float, near_ship: bool, liquid: String, liquid_depth: float, sprinting: bool, thrusting: bool, grounded: bool) -> bool:
	_since_damage += dt
	_sodium_cd = maxf(0.0, _sodium_cd - dt)
	_warn_cd = maxf(0.0, _warn_cd - dt)
	_flash_cd = maxf(0.0, _flash_cd - dt)
	body_temp_c = lerpf(body_temp_c, temp_c, clampf(dt * 0.6, 0.0, 1.0))
	# ---- hazard drain ------------------------------------------------------------------------------------------------------
	var lvl := hazard_level
	var in_burning_liquid := liquid_depth > 0.12 and (liquid == "lava" or liquid == "acid")
	if near_ship and not in_burning_liquid:
		lvl = 0.0                                   # life support next to the ship; it cannot help while you are wading through lava
	if in_burning_liquid:
		# lava / acid eats the exosuit shield much faster than any ambient hazard (lava: ~7 s from full, acid: ~14 s)
		protection = maxf(0.0, protection - (0.14 if liquid == "lava" else 0.07) * dt)
	if lvl > 0.0:
		protection = maxf(0.0, protection - lvl * PROTECTION_DRAIN * dt)
		if hazard != _last_hazard and _warn_cd <= 0.0:
			Events.notify.emit("Warning: %s - exosuit protection draining" % hazard.to_lower(), "warn")
			_warn_cd = 25.0
		# Sodium auto-refill
		if protection < 0.32 and _sodium_cd <= 0.0 and int(Game.inventory.get("sodium", 0)) > 0:
			var used := Game.consume_resource("sodium", SODIUM_PER_USE)
			if used > 0:
				protection = minf(1.0, protection + SODIUM_RESTORE * float(used) / float(SODIUM_PER_USE))
				_sodium_cd = 0.8
				Events.notify.emit("Sodium recharged exosuit protection (%d%%)" % int(protection * 100.0), "info")
		if protection <= 0.0:
			var dmg := (DAMAGE_RATE + lvl * DAMAGE_LEVEL) * dt
			if liquid == "lava" and liquid_depth > 0.12:
				dmg += 0.18 * dt
			damage(dmg)
			if _flash_cd <= 0.0:
				Events.screen_flash.emit(Color(1.0, 0.12, 0.05, 0.22), 0.35)
				_flash_cd = 1.6
	else:
		# safe: shield recovers slowly (life support next to the ship is much faster)
		var rate := 0.25 if near_ship else 0.05
		protection = minf(1.0, protection + rate * dt)
	_last_hazard = hazard
	# ---- health regen --------------------------------------------------------------------------------------------------------
	if protection > 0.05 and _since_damage > 4.0 and health < 1.0:
		health = minf(1.0, health + (0.10 if near_ship else 0.03) * dt)
	# ---- jetpack fuel -------------------------------------------------------------------------------------------------------
	if thrusting:
		_jet_recharge_delay = 0.6
	else:
		_jet_recharge_delay = maxf(0.0, _jet_recharge_delay - dt)
		if grounded:
			if _jet_recharge_delay <= 0.0:
				jetpack = minf(1.0, jetpack + 0.30 * dt)
		else:
			jetpack = minf(1.0, jetpack + 0.03 * dt)
	# ---- stamina -----------------------------------------------------------------------------------------------------------
	if sprinting:
		stamina = maxf(0.0, stamina - 0.05 * dt)           # ~20 s of continuous sprint
		_sprint_recharge_delay = 0.5
		if stamina <= 0.0:
			exhausted = true
	else:
		_sprint_recharge_delay = maxf(0.0, _sprint_recharge_delay - dt)
		if _sprint_recharge_delay <= 0.0:
			stamina = minf(1.0, stamina + 0.30 * dt)
		if exhausted and stamina >= 0.25:
			exhausted = false
	if health <= 0.0 and not dead:
		dead = true
		return true
	return false

func damage(amount: float) -> void:
	if amount <= 0.0:
		return
	health = maxf(0.0, health - amount)
	_since_damage = 0.0

func write_tel(tel: Dictionary) -> void:
	tel["health"] = health
	tel["protection"] = protection
	tel["jetpack"] = jetpack
	tel["stamina"] = stamina
	tel["temp_c"] = body_temp_c
	tel["hazard"] = hazard
	tel["hazard_level"] = hazard_level
