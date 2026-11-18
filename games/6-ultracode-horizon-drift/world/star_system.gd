class_name StarSystem
extends Node3D
## Builds the node tree of one star system: the star, every body (Planet / GasGiant / BlackHole) and the extras (station, freighter, asteroids).
## Positions are NOT set here: autoload/frame.gd places every body each frame (child transforms of this node are identity).

var def: SystemDef
var star: Node3D

func build(sys: SystemDef) -> void:
	def = sys
	star = StarVisual.new()
	star.name = "Star"
	star.setup(sys.star)
	add_child(star)
	Universe.star_node = star
	var nodes: Array = []
	for b in sys.bodies:
		var n: Node3D
		match b.kind:
			BodyDef.Kind.GAS_GIANT:
				n = GasGiant.new()
				n.setup(b, sys)
			BodyDef.Kind.BLACK_HOLE:
				n = BlackHole.new()
				n.setup(b, sys)
			_:
				n = Planet.new()
				n.setup(b, sys)
		n.name = b.name.validate_node_name()
		add_child(n)
		nodes.append(n)
	Universe.body_nodes = nodes
	var extras := SystemExtras.new()
	extras.name = "Extras"
	add_child(extras)
	extras.build(sys)
