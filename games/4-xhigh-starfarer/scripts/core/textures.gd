class_name Textures
extends RefCounted
## Procedural textures generated once at startup.

static var _detail: ImageTexture
static var _soft: ImageTexture
static var _noise2d: ImageTexture


## RGB = tangent-ish normal map of a seamless noise, A = height (used as grain).
static func detail_texture() -> ImageTexture:
	if _detail:
		return _detail
	var fn := FastNoiseLite.new()
	fn.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	fn.frequency = 0.012
	fn.fractal_type = FastNoiseLite.FRACTAL_FBM
	fn.fractal_octaves = 5
	fn.fractal_gain = 0.55
	fn.seed = 1337
	var img := fn.get_seamless_image(512, 512, false, false, 0.1, true)
	img.convert(Image.FORMAT_L8)
	var nrm := img.duplicate() as Image
	nrm.convert(Image.FORMAT_RGBA8)
	nrm.bump_map_to_normal_map(5.0)
	# bump_map_to_normal_map keeps RGB normal; write the height into alpha
	var nd := nrm.get_data()
	var hd := img.get_data()
	for i in 512 * 512:
		nd[i * 4 + 3] = hd[i]
	var out := Image.create_from_data(512, 512, false, Image.FORMAT_RGBA8, nd)
	out.generate_mipmaps()
	_detail = ImageTexture.create_from_image(out)
	return _detail


## soft round blob used by particles / glows (white, alpha falloff)
static func soft_dot(size := 64) -> ImageTexture:
	if _soft:
		return _soft
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var c := (size - 1) * 0.5
	for y in size:
		for x in size:
			var d := Vector2(x - c, y - c).length() / c
			var a := clampf(1.0 - d, 0.0, 1.0)
			a = a * a * (3.0 - 2.0 * a)
			img.set_pixel(x, y, Color(1, 1, 1, a))
	_soft = ImageTexture.create_from_image(img)
	return _soft


## seamless tileable gray noise (used by clouds / liquids)
static func noise2d() -> ImageTexture:
	if _noise2d:
		return _noise2d
	var fn := FastNoiseLite.new()
	fn.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	fn.frequency = 0.01
	fn.fractal_type = FastNoiseLite.FRACTAL_FBM
	fn.fractal_octaves = 5
	fn.seed = 99
	var img := fn.get_seamless_image(512, 512, false, false, 0.1, true)
	img.generate_mipmaps()
	_noise2d = ImageTexture.create_from_image(img)
	return _noise2d
