class_name DetailTex
extends RefCounted
## Procedurally generated seamless detail textures shared by terrain and water shaders (no image files needed).

static var nrm: ImageTexture = null
static var hgt: ImageTexture = null
static var wave: ImageTexture = null
static var _ready: bool = false

static func ensure() -> void:
	if _ready:
		return
	_ready = true
	var n1 := FastNoiseLite.new()
	n1.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n1.seed = 4242
	n1.frequency = 0.012
	n1.fractal_type = FastNoiseLite.FRACTAL_FBM
	n1.fractal_octaves = 5
	var img1: Image = n1.get_seamless_image(512, 512, false, false, 0.2, true)
	var n2 := FastNoiseLite.new()
	n2.noise_type = FastNoiseLite.TYPE_CELLULAR
	n2.seed = 99
	n2.frequency = 0.035
	n2.cellular_return_type = FastNoiseLite.RETURN_DISTANCE
	n2.fractal_type = FastNoiseLite.FRACTAL_NONE
	var img2: Image = n2.get_seamless_image(512, 512, false, false, 0.2, true)
	var a: PackedByteArray = img1.get_data()
	var b: PackedByteArray = img2.get_data()
	var out := PackedByteArray()
	out.resize(a.size())
	for i in a.size():
		out[i] = (int(a[i]) * 3 + int(b[i]) * 2) / 5
	var h := Image.create_from_data(512, 512, false, Image.FORMAT_L8, out)
	var hn := h.duplicate() as Image
	hn.convert(Image.FORMAT_RGBA8)
	hn.bump_map_to_normal_map(5.0)
	hn.generate_mipmaps()
	nrm = ImageTexture.create_from_image(hn)
	h.generate_mipmaps()
	hgt = ImageTexture.create_from_image(h)
	# water waves
	var n3 := FastNoiseLite.new()
	n3.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n3.seed = 77
	n3.frequency = 0.02
	n3.fractal_type = FastNoiseLite.FRACTAL_FBM
	n3.fractal_octaves = 4
	var wimg: Image = n3.get_seamless_image(256, 256, false, false, 0.2, true)
	wimg.convert(Image.FORMAT_RGBA8)
	wimg.bump_map_to_normal_map(7.0)
	wimg.generate_mipmaps()
	wave = ImageTexture.create_from_image(wimg)
