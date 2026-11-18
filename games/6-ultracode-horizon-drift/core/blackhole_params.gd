class_name BlackHoleParams
extends RefCounted
## Tunable black-hole numbers. Owned by the BLACK HOLE module (M5): adjust freely, keep the names.
## Universe reads these to build the BodyDef; world/blackhole/* reads them for visuals + mechanics.
## All lengths in metres, mu in m^3/s^2, accelerations in m/s^2.
##
## MECHANICS OVERVIEW (see world/blackhole/README.md):
##   pull        a(r) = MU / r^2 toward the singularity (applied via ship.external_accel)
##   WARN        r < 300 km : level 1 "caution"  (HUD + rumble)
##   DANGER      r < 120 km : level 2 "danger"   (pulse drive locked, camera shake, control authority begins to fade)
##   NO RETURN   r <  22 km : level 3            (pull ~ 124 m/s^2 ~ the ship's full-boost thrust; capture field takes over: escape impossible)
##   HORIZON     r < RS*1.05: level 4            (spaghettification, white-out, Game.warp_to_system(bh_dest_system, "blackhole"))

const RS := 2000.0                  # Schwarzschild / event-horizon radius (the black disc)
const MU := 6.0e10                  # accel = MU / r^2  -> 150 m/s^2 at r = 20 km  (about the ship's max thrust)
const DISC_INNER := 6000.0          # accretion disc inner edge (3 RS)
const DISC_OUTER := 34000.0         # accretion disc outer edge
const INFLUENCE := 420000.0         # radius of the "gravity well": lensing quad + warnings + pull start
const WARN_RADIUS := 300000.0       # first HUD warning
const DANGER_RADIUS := 120000.0     # pulse drive disabled, strong shake
const POINT_OF_NO_RETURN := 22000.0 # beyond this the pull exceeds ship thrust: escape impossible
const SPAWN_DISTANCE := 140000.0    # where a ship arriving through a singularity appears (moving away)

# ---- mechanics tuning (M5 internal) ------------------------------------------------------------------------------------------
const HORIZON_TRIGGER := 1.05       # x RS: crossing this radius triggers the transition to the other system
const REFERENCE_THRUST := 150.0     # m/s^2: assumed full-boost thrust of the ship; PONR is where MU/r^2 reaches ~this
const HYSTERESIS := 1.04            # leaving a warning level needs r > level_radius * HYSTERESIS (no flicker)
const AUTH_AT_DANGER := 1.0         # control_authority at DANGER_RADIUS
const AUTH_AT_PONR := 0.8           # ... at POINT_OF_NO_RETURN (thrust 150*0.8 = 120 m/s^2 < pull 124 m/s^2)
const AUTH_AT_HORIZON := 0.12       # ... at the horizon (the ship is a passenger by then)
const CAPTURE_RATE := 2.6           # 1/s: strength of the "capture field" (drives the velocity toward the free-fall field) inside the PONR
const DISC_DRAG := 0.35             # 1/s: plasma drag on tangential velocity inside the PONR (orbits decay, nothing circles forever)
const ARRIVAL_ENTRY_SPEED := 500.0  # m/s: ejection speed after leaving a singularity (Game uses the same number)
const ARRIVAL_EJECT_TIME := 8.0     # s: the ejection speed (ARRIVAL_ENTRY_SPEED) coasts down to 0 over this time (the flight assist would eat it in ~2 s)
const ARRIVAL_GRACE := 28.0         # s: after arriving the pull of the destination hole fades in slowly so the ejected ship can fly away
const SAFE_BRAKE := 60.0            # m/s^2: braking assumed by the inbound speed limit (v_cap = 300 + sqrt(2 * SAFE_BRAKE * (r - 1.3 * PONR)))
const INTERDICT_GAIN := 3.5         # 1/s: how hard the well pulls an over-fast inbound ship down to the limit
const SHAKE_MAX := 1.0              # extra_shake at the horizon
