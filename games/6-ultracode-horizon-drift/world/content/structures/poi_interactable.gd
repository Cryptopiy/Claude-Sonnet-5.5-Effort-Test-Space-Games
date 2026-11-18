class_name PoiInteractable
extends Node3D
## Interaction point (module M7a). Contract with the player (M4): group "interactable", get_prompt(), can_interact(player), interact(player).
## The node's global_position is the point the player measures distance to (~4 m).

var prompt: String = "Interact"
var on_use: Callable = Callable()
var usable: Callable = Callable()      # () -> bool ; when invalid the point is always usable
var prompt_fn: Callable = Callable()   # () -> String ; overrides `prompt` when valid

func _ready() -> void:
	add_to_group("interactable")

func get_prompt() -> String:
	if prompt_fn.is_valid():
		return String(prompt_fn.call())
	return prompt

func can_interact(player: Node) -> bool:
	if usable.is_valid():
		return bool(usable.call())
	return true

func interact(player: Node) -> void:
	if on_use.is_valid():
		on_use.call(player)
