class_name StarDef
extends RefCounted
## The star of a system. The star sits at the system origin (absolute position 0,0,0).

var name: String = ""
var spectral_class: String = "G"   # O B A F G K M
var color: Color = Color(1.0, 0.92, 0.72)        # visible surface colour
var light_color: Color = Color(1.0, 0.95, 0.85)  # colour of the light it casts (less saturated)
var temperature: float = 5800.0    # Kelvin
var radius: float = 48000.0        # metres (visual radius; big for gameplay)
var light_energy: float = 1.25     # DirectionalLight3D energy at "planet distance" (tune per class)
var corona_scale: float = 6.0      # corona sprite size in star radii
