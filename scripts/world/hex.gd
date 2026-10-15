class_name Hex
## The world's hex grid and its wrap, ported from the HTML game.
##
## 1000 x 1000 pointy-top hex tiles, odd rows shifted half a tile east.
## The map wraps both ways: east runs into west and south into north,
## so every distance and position goes through the helpers here.

const S := 0.42                          # hex circumradius (m)
const SQ3 := 1.7320508075688772
const COLS := 1000
const ROWS := 1000
const DX := S * SQ3                      # column spacing
const DZ := S * 1.5                      # row spacing
const OFF_X := (COLS - 0.5) * DX / 2.0
const OFF_Z := (ROWS - 1) * DZ / 2.0
const WRAP := COLS * DX                  # x repeats every WRAP m (about 727 m)
const WRAP_Z := ROWS * DZ                # z repeats every WRAP_Z m (630 m)
const COUNT := COLS * ROWS


## A world x folded back into [-WRAP/2, WRAP/2).
static func wrap_x(x: float) -> float:
	return fposmod(x + WRAP * 0.5, WRAP) - WRAP * 0.5


static func wrap_z(z: float) -> float:
	return fposmod(z + WRAP_Z * 0.5, WRAP_Z) - WRAP_Z * 0.5


## Shortest east-west difference, across the seam if that is nearer.
static func wrap_dx(dx: float) -> float:
	return dx - roundf(dx / WRAP) * WRAP


static func wrap_dz(dz: float) -> float:
	return dz - roundf(dz / WRAP_Z) * WRAP_Z


## The copy of x closest to ref (for drawing something near the camera).
static func near_copy_x(x: float, ref: float) -> float:
	return x + roundf((ref - x) / WRAP) * WRAP


static func near_copy_z(z: float, ref: float) -> float:
	return z + roundf((ref - z) / WRAP_Z) * WRAP_Z


## Shortest offset from a to b on the wrapped plane (y is ignored).
static func offset(a: Vector3, b: Vector3) -> Vector3:
	return Vector3(wrap_dx(b.x - a.x), 0.0, wrap_dz(b.z - a.z))


static func distance(a: Vector3, b: Vector3) -> float:
	return offset(a, b).length()


static func col_of(i: int) -> int:
	return i % COLS


static func row_of(i: int) -> int:
	return i / COLS


static func index(c: int, r: int) -> int:
	return posmod(r, ROWS) * COLS + posmod(c, COLS)


static func tile_x(i: int) -> float:
	return DX * (i % COLS + ((i / COLS) & 1) * 0.5) - OFF_X


static func tile_z(i: int) -> float:
	return DZ * (i / COLS) - OFF_Z


static func tile_pos(i: int) -> Vector3:
	return Vector3(tile_x(i), 0.0, tile_z(i))


## Index of the tile under a world point (any copy of the world).
static func tile_at(x: float, z: float) -> int:
	x = wrap_x(x)
	z = wrap_z(z)
	var r0 := roundi((z + OFF_Z) / DZ)
	var best := -1
	var bd := INF
	for r in range(r0 - 1, r0 + 2):
		if r < 0 or r >= ROWS:
			continue
		var c0 := roundi((x + OFF_X) / DX - (r & 1) * 0.5)
		for c in range(c0 - 1, c0 + 2):
			if c < 0 or c >= COLS:
				continue
			var i := r * COLS + c
			var d := pow(tile_x(i) - x, 2) + pow(tile_z(i) - z, 2)
			if d < bd:
				bd = d
				best = i
	return best


## The six neighbours of a tile, wrapping at the seams.
static func neighbours(i: int) -> PackedInt32Array:
	var c := i % COLS
	var r := i / COLS
	var odd := r & 1
	var out := PackedInt32Array()
	out.append(index(c - 1, r))
	out.append(index(c + 1, r))
	for dr in [-1, 1]:
		out.append(index(c - 1 + odd, r + dr))
		out.append(index(c + odd, r + dr))
	return out


# ---- the HTML game's hash, bit for bit, so tile colours match ----

const _M := 0xFFFFFFFF


static func _imul(a: int, b: int) -> int:
	return (a * (b & 0xFFFF) + (((a * (b >> 16)) & 0xFFFF) << 16)) & _M


## A fixed pseudo-random number in [0, 1) for any integer.
static func hash01(i: int) -> float:
	var h := _imul((i ^ 0x9e3779b9) & _M, 0x85ebca6b)
	h ^= h >> 13
	h = _imul(h, 0xc2b2ae35)
	h ^= h >> 16
	return float(h) / 4294967296.0
