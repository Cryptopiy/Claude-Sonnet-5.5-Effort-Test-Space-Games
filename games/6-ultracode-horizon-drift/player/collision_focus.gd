extends Node
## Re-asserts the player's terrain collision focus AFTER every other module has run this frame (module M4).
## Why: Planet.set_collision_focus() is "last caller wins" and the parked ship calls it every frame (priority 0), which used to drag the
## collision patch back to the ship while the player was walking away from it. This node runs at priority 60 (after gameplay at 0 and
## before Frame at 100 / Planet at 150, which consumes the focus), so the walking player always wins while he is active.

var player: CharacterBody3D

func _ready() -> void:
	process_priority = 60

func _process(_dt: float) -> void:
	if player == null or not is_instance_valid(player) or not bool(player.get("active")):
		return
	var planet := Frame.anchor_node() as Planet
	if planet != null:
		planet.set_collision_focus(player.global_position, 80.0)
