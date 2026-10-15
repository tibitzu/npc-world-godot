class_name TileGrid
extends RefCounted
## Per-tile data for the whole map: flags, kind and colour.
##
## A million tiles live in packed arrays (no object per tile). The colours
## also go into a texture with one texel per tile, which the ground shader
## reads for both the smooth ground and the hex tiles (V).

const F_BLOCK := 1
const F_ROAD := 2              # paved: the town square
const F_INSIDE := 4
const F_NOTREE := 8

const MOSS: Array[int] = [0x6f9a5c, 0x7aa565, 0x668f55, 0x82ab6a]

var flags := PackedByteArray()
var kinds := PackedByteArray()
var kind_names: Array[String] = ["moss", "road", "path", "tree", "tavern", "well", "lamp"]
var colours := PackedByteArray()        # RGBA8, texel (c, r) for tile r * COLS + c
var texture: ImageTexture

var _dirty := false


func _init() -> void:
	flags.resize(Hex.COUNT)
	kinds.resize(Hex.COUNT)
	colours.resize(Hex.COUNT * 4)
	_paint_base()
	texture = ImageTexture.create_from_image(_make_image())


# open moss everywhere; the town square and buildings recolour their own tiles
func _paint_base() -> void:
	for i in Hex.COUNT:
		_put_colour(i, MOSS[int(Hex.hash01(i) * MOSS.size())], 0.09)


func _put_colour(i: int, hex: int, jitter := 0.0) -> void:
	var r := float(hex >> 16 & 255) / 255.0
	var g := float(hex >> 8 & 255) / 255.0
	var b := float(hex & 255) / 255.0
	if jitter > 0.0:
		var k := 1.0 + (Hex.hash01(i * 7 + 3) - 0.5) * jitter
		r = minf(1.0, r * k)
		g = minf(1.0, g * k)
		b = minf(1.0, b * k)
	var o := i * 4
	colours[o] = int(r * 255.0)
	colours[o + 1] = int(g * 255.0)
	colours[o + 2] = int(b * 255.0)
	colours[o + 3] = 255


## Recolour one tile; call flush() once after a batch of changes.
func set_colour(i: int, hex: int, jitter := 0.0) -> void:
	_put_colour(i, hex, jitter)
	_dirty = true


func flush() -> void:
	if _dirty:
		texture.update(_make_image())
		_dirty = false


func has_flag(i: int, f: int) -> bool:
	return flags[i] & f != 0


func set_flag(i: int, f: int, on := true) -> void:
	flags[i] = (flags[i] | f) if on else (flags[i] & ~f)


func kind(i: int) -> String:
	return kind_names[kinds[i]]


func set_kind(i: int, k: String) -> void:
	var id := kind_names.find(k)
	if id < 0:
		kind_names.append(k)
		id = kind_names.size() - 1
	kinds[i] = id


func _make_image() -> Image:
	var img := Image.create_from_data(Hex.COLS, Hex.ROWS, false, Image.FORMAT_RGBA8, colours)
	img.generate_mipmaps()
	return img
