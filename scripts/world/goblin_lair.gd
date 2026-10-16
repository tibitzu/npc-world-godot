class_name GoblinLair
extends Node3D
## The goblins' lair (as in the HTML game's dungeons): a warren of rooms and winding tunnels 3 m
## under the hills just north of their camp, reached by a stone stair inside a small gatehouse.
## Torches on the walls, bones and rubble about, barrels and chests in the side rooms, and at
## the far end a great hall with pillars, braziers and an altar, where the band's chief holds
## court. A dozen goblins walk the tunnels.
##
## The layout comes from a fixed seed, so it's the same every game. It's built the way the HTML
## game builds its dungeons: rooms first, a winding maze through the gaps, one doorway between
## every pair of neighbouring areas (and a few more for loops), then the dead ends filled in.
##
## Underground everything is real: floors and walls are solid, and it has its own navigation
## mesh (which also covers the open ground above it, so it fits the hole it leaves in the
## world's). The ground has a hole over the stairwell; while you're playing someone down here
## the ground over the whole lair is left out, so the camera can see in.

const N := 21                       # 21 x 21 cells...
const C := 1.6                      # ...of 1.6 m: about 34 m across
const FLOOR_Y := -3.0
const WALL_TOP := -0.8              # walls stop well short of the ground (nobody up top trips on them)
const STAIR := 6.0                  # the stair's length, climbing south to the surface
const STEPS := 15
const APRON := 1.0                  # ground in front of the gatehouse that belongs to the lair's mesh
const SEED := 4_1013
const NAME := "The Black Warrens"
const GOBLINS := 12

## The entrance (the top of the stair), world x, and z of the lair's south wall.
@export var entry_x := 46.0
@export var south_z := -44.0

var x0: float
var z0: float
var x1: float
var z1: float
var ex: float                       # the entrance's x (the stair's middle)
var grid := PackedByteArray()       # 1: open floor, 0: rock
var rooms: Array[Rect2i] = []       # in cells; rooms[0] is the great hall
var under := false                  # the resident being played is down here

var _rng := RandomNumberGenerator.new()
var _rock: StaticBody3D             # floor and walls (left out of clicks from above ground)
var _lights: Array[Light3D] = []    # lit only while someone's down here
var _roof: Node3D
var _ground_mat: ShaderMaterial
var _monsters: Array[Monster] = []

var _stone: StandardMaterial3D
var _dark: StandardMaterial3D
var _wood: StandardMaterial3D
var _iron: StandardMaterial3D
var _flame: StandardMaterial3D
var _coal: StandardMaterial3D


func _ready() -> void:
	add_to_group("goblin_lair")
	_rng.seed = SEED
	var size := N * C
	ex = entry_x
	var exi := (N / 2) | 1
	x0 = ex - (exi + 0.5) * C
	x1 = x0 + size
	z1 = south_z
	z0 = z1 - size
	_stone = Gear.mat(0x5a5660, 0.95)
	_dark = Gear.mat(0x3d3a43, 1.0)
	_wood = Gear.mat(0x6b4a33, 0.9)
	_iron = Gear.mat(0x4a4d55, 0.45, 0.6)
	_flame = Gear.mat(0xff9a3d, 1.0)
	_flame.emission_enabled = true
	_flame.emission = Look.html_hex(0xff6a1f)
	_flame.emission_energy_multiplier = 2.0
	_coal = Gear.mat(0xff7a2a, 1.0)
	_coal.emission_enabled = true
	_coal.emission = Look.html_hex(0xff4a10)
	_coal.emission_energy_multiplier = 1.6
	_rock = StaticBody3D.new()
	_rock.name = "Rock"
	_rock.collision_layer = 1
	_rock.collision_mask = 0
	add_child(_rock)
	_layout(exi)
	_build_rock()
	_build_torches()
	_furnish()
	_build_stair()
	_build_gatehouse()
	_build_ceiling()
	_bake_nav()
	var nav := get_tree().get_first_node_in_group("world_nav") as WorldNav
	if nav:
		nav.carve(nav_rect())
	var ground := get_node_or_null("../Ground") as MeshInstance3D
	if ground:
		_ground_mat = ground.material_override as ShaderMaterial
		_ground_mat.set_shader_parameter("hole", stairwell())
		_ground_mat.set_shader_parameter("cutaway", Vector4(x0, z0, x1, z1 + STAIR))
	_populate.call_deferred()


## The area (world x, z) this lair's own navigation mesh covers: the lair and its stair, and the
## ground over them.
func nav_rect() -> Rect2:
	return Rect2(x0, z0, x1 - x0, z1 + STAIR + APRON - z0)


## The open stairwell (x0, z0, x1, z1), where the ground has a hole.
func stairwell() -> Vector4:
	return Vector4(ex - C * 0.5 - 0.15, z1, ex + C * 0.5 + 0.15, z1 + STAIR)


## The lair's floor and walls (a click from above ground goes through them, to the grass).
func rock_body() -> RID:
	return _rock.get_rid()


## Is a point down in the lair (or on its stair)?
func holds(p: Vector3) -> bool:
	return p.y < -1.0 and p.x > x0 - 1.0 and p.x < x1 + 1.0 and p.z > z0 - 1.0 and p.z < z1 + STAIR


func _at(i: int, j: int) -> int:
	return j * N + i


func _cell_pos(i: int, j: int) -> Vector3:
	return Vector3(x0 + (i + 0.5) * C, FLOOR_Y, z0 + (j + 0.5) * C)


# ---- the layout ----

func _r() -> float:
	return _rng.randf()


func _layout(exi: int) -> void:
	grid.resize(N * N)
	grid.fill(0)
	var reg := PackedInt32Array()
	reg.resize(N * N)
	reg.fill(-1)
	var regions := 0
	# rooms: the great hall first, toward the back; then up to five more
	for t in 400:
		if rooms.size() >= 6:
			break
		var w := 9 if t == 0 else 3 + 2 * int(_r() * 3)
		var h := 7 if t == 0 else 3 + 2 * int(_r() * 3)
		var x := 1 + 2 * int(_r() * ((N - 2 - w) / 2 + 1))
		var y := 1 + 2 * int(_r() * (((N - 2 - h) / 2 if t > 0 else 2) + 1))
		var clash := false
		for rm in rooms:
			if x < rm.position.x + rm.size.x + 1 and x + w + 1 > rm.position.x and y < rm.position.y + rm.size.y + 1 and y + h + 1 > rm.position.y:
				clash = true
				break
		if clash:
			continue
		var id := regions
		regions += 1
		rooms.append(Rect2i(x, y, w, h))
		for j in range(y, y + h):
			for i in range(x, x + w):
				grid[_at(i, j)] = 1
				reg[_at(i, j)] = id
	# a winding maze through everything else
	for y in range(1, N - 1, 2):
		for x in range(1, N - 1, 2):
			if grid[_at(x, y)]:
				continue
			var id := regions
			regions += 1
			var stack: Array[Vector2i] = [Vector2i(x, y)]
			grid[_at(x, y)] = 1
			reg[_at(x, y)] = id
			while not stack.is_empty():
				var c: Vector2i = stack.back()
				var dirs: Array[Vector2i] = []
				for d in [Vector2i(2, 0), Vector2i(-2, 0), Vector2i(0, 2), Vector2i(0, -2)]:
					var n: Vector2i = c + d
					if n.x > 0 and n.y > 0 and n.x < N - 1 and n.y < N - 1 and not grid[_at(n.x, n.y)]:
						dirs.append(d)
				if dirs.is_empty():
					stack.pop_back()
					continue
				var d: Vector2i = dirs[int(_r() * dirs.size())]
				for k in [d / 2, d]:
					var m: Vector2i = c + k
					grid[_at(m.x, m.y)] = 1
					reg[_at(m.x, m.y)] = id
				stack.append(c + d)
	# doorways: every wall cell between two different areas is a candidate; join areas until all
	# are one, and open a few more for loops
	var parent := PackedInt32Array()
	parent.resize(regions)
	for i in regions:
		parent[i] = i
	var conns: Array = []
	for y in range(1, N - 1):
		for x in range(1, N - 1):
			if grid[_at(x, y)]:
				continue
			for pr in [[_at(x - 1, y), _at(x + 1, y)], [_at(x, y - 1), _at(x, y + 1)]]:
				if grid[pr[0]] and grid[pr[1]] and reg[pr[0]] != reg[pr[1]]:
					conns.append([_at(x, y), reg[pr[0]], reg[pr[1]]])
	for i in range(conns.size() - 1, 0, -1):
		var j := int(_r() * (i + 1))
		var tmp = conns[i]
		conns[i] = conns[j]
		conns[j] = tmp
	for c in conns:
		var ra := _find(parent, c[1])
		var rb := _find(parent, c[2])
		if ra != rb:
			parent[ra] = rb
			grid[c[0]] = 1
		elif _r() < 0.06:
			grid[c[0]] = 1
	# the way in, through the middle of the south wall
	grid[_at(exi, N - 1)] = 1
	grid[_at(exi, N - 2)] = 1
	# dead ends filled back in
	var changed := true
	while changed:
		changed = false
		for y in range(1, N - 1):
			for x in range(1, N - 1):
				var i := _at(x, y)
				if not grid[i]:
					continue
				var open := grid[_at(x - 1, y)] + grid[_at(x + 1, y)] + grid[_at(x, y - 1)] + grid[_at(x, y + 1)]
				if open <= 1:
					grid[i] = 0
					changed = true


static func _find(parent: PackedInt32Array, a: int) -> int:
	while parent[a] != a:
		parent[a] = parent[parent[a]]
		a = parent[a]
	return a


# ---- building it ----

# floors (flagstones) and walls, in 3 x 3 blocks (so no mesh has too many torches near it), and
# the colliders: one slab of floor, and each row's runs of wall as one box
func _build_rock() -> void:
	var floor_mat := StandardMaterial3D.new()
	floor_mat.vertex_color_use_as_albedo = true
	floor_mat.roughness = 1.0
	floor_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var B := 7
	for bj in range(0, N, B):
		for bi in range(0, N, B):
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			for j in range(bj, mini(N, bj + B)):
				for i in range(bi, mini(N, bi + B)):
					var c := _cell_pos(i, j)
					var cx := c.x - C * 0.5
					var cz := c.z - C * 0.5
					if grid[_at(i, j)]:
						_flat(st, cx, cz, C, C, FLOOR_Y, Color(0.17, 0.16, 0.19))
						for a in 2:
							for b in 2:
								var v := 0.27 + _r() * 0.09
								_flat(st, cx + a * C * 0.5 + 0.03, cz + b * C * 0.5 + 0.03, C * 0.5 - 0.06, C * 0.5 - 0.06,
									FLOOR_Y + 0.004, Color(v, v - 0.015, v + 0.03))
					else:
						var v := 0.3 + _r() * 0.07
						var col := Color(v, v - 0.01, v + 0.04)
						_flat(st, cx, cz, C, C, WALL_TOP, col.darkened(0.25))
						# sides facing open floor
						if i > 0 and grid[_at(i - 1, j)]:
							_side(st, Vector3(cx, 0, cz), Vector3(cx, 0, cz + C), Vector3.LEFT, col)
						if i < N - 1 and grid[_at(i + 1, j)]:
							_side(st, Vector3(cx + C, 0, cz + C), Vector3(cx + C, 0, cz), Vector3.RIGHT, col)
						if j > 0 and grid[_at(i, j - 1)]:
							_side(st, Vector3(cx + C, 0, cz), Vector3(cx, 0, cz), Vector3.FORWARD, col)
						if j < N - 1 and grid[_at(i, j + 1)]:
							_side(st, Vector3(cx, 0, cz + C), Vector3(cx + C, 0, cz + C), Vector3.BACK, col)
			var mi := MeshInstance3D.new()
			mi.mesh = st.commit()
			mi.material_override = floor_mat
			add_child(mi)
	var slab := CollisionShape3D.new()
	var sb := BoxShape3D.new()
	sb.size = Vector3(x1 - x0, 0.2, z1 - z0)
	slab.shape = sb
	slab.position = Vector3((x0 + x1) * 0.5, FLOOR_Y - 0.1, (z0 + z1) * 0.5)
	_rock.add_child(slab)
	for j in N:
		var i := 0
		while i < N:
			if grid[_at(i, j)]:
				i += 1
				continue
			var k := i
			while k + 1 < N and not grid[_at(k + 1, j)]:
				k += 1
			var cs := CollisionShape3D.new()
			var bx := BoxShape3D.new()
			bx.size = Vector3((k - i + 1) * C, WALL_TOP - FLOOR_Y, C)
			cs.shape = bx
			cs.position = Vector3(x0 + (i + k + 1) * C * 0.5, (FLOOR_Y + WALL_TOP) * 0.5, z0 + (j + 0.5) * C)
			_rock.add_child(cs)
			i = k + 1


func _flat(st: SurfaceTool, x: float, z: float, w: float, d: float, y: float, col: Color) -> void:
	st.set_color(col)
	st.set_normal(Vector3.UP)
	for v in [Vector3(x, y, z), Vector3(x + w, y, z), Vector3(x + w, y, z + d), Vector3(x, y, z), Vector3(x + w, y, z + d), Vector3(x, y, z + d)]:
		st.add_vertex(v)


func _side(st: SurfaceTool, a: Vector3, b: Vector3, n: Vector3, col: Color) -> void:
	st.set_normal(n)
	var lo := FLOOR_Y
	var hi := WALL_TOP
	var pts := [Vector3(a.x, lo, a.z), Vector3(b.x, lo, b.z), Vector3(b.x, hi, b.z), Vector3(a.x, hi, a.z)]
	var shade := [col.darkened(0.35), col.darkened(0.35), col, col]
	for k in [0, 1, 2, 0, 2, 3]:
		st.set_color(shade[k])
		st.add_vertex(pts[k])


# torches in iron brackets on the walls, spaced out
func _build_torches() -> void:
	var spots: Array[Vector4i] = []
	for j in range(1, N - 1):
		for i in range(1, N - 1):
			if not grid[_at(i, j)]:
				continue
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				if grid[_at(i + d.x, j + d.y)] or _r() > 0.12:
					continue
				var crowded := false
				for t in spots:
					if absi(t.x - i) + absi(t.y - j) < 6:
						crowded = true
						break
				if not crowded:
					spots.append(Vector4i(i, j, d.x, d.y))
	for t in spots:
		var c := _cell_pos(t.x, t.y)
		var p := c + Vector3(t.z, 0, t.w) * (C * 0.5 - 0.06)
		Gear._put(self, Gear._box(Vector3(0.08, 0.3, 0.08)), _iron, p + Vector3.UP * 1.35)
		var f := Gear._put(self, Gear._cyl(0.0, 0.07, 0.2, 7), _flame, p + Vector3.UP * 1.6)
		f.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_light(c + Vector3(t.z, 0, t.w) * (C * 0.5 - 0.3) + Vector3.UP * 1.7, 1.2, 6.0)


func _light(at: Vector3, energy: float, reach: float) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.light_color = Look.html_hex(0xffa860)
	l.light_energy = energy
	l.omni_range = reach
	l.omni_attenuation = 1.4
	l.position = at
	l.visible = false
	add_child(l)
	_lights.append(l)
	return l


func _solid(at: Vector3, r: float, h: float) -> void:
	var cs := CollisionShape3D.new()
	var sh := CylinderShape3D.new()
	sh.radius = r
	sh.height = h
	cs.shape = sh
	cs.position = at + Vector3.UP * h * 0.5
	_rock.add_child(cs)


func _furnish() -> void:
	for ri in rooms.size():
		var rm := rooms[ri]
		var rx0 := x0 + rm.position.x * C
		var rz0 := z0 + rm.position.y * C
		var rw := rm.size.x * C
		var rh := rm.size.y * C
		var mx := rx0 + rw * 0.5
		var mz := rz0 + rh * 0.5
		var spot := func() -> Vector3:
			return Vector3(rx0 + 0.8 + _r() * (rw - 1.6), FLOOR_Y, rz0 + 0.8 + _r() * (rh - 1.6))
		if ri == 0:
			# the great hall: two rows of pillars, the altar at the north end with braziers either
			# side, the band's treasure chest in front of it, and bones
			for a in [1, 2, 3]:
				for s in [-1, 1]:
					_pillar(Vector3(mx + s * (rw * 0.5 - 2.2), FLOOR_Y, rz0 + a * rh / 4.0))
			Gear._put(self, Gear._box(Vector3(1.8, 0.9, 0.9)), _dark, Vector3(mx, FLOOR_Y + 0.45, rz0 + 1.1))
			var red := Gear.mat(0x7a1f22, 1.0)
			Gear._put(self, Gear._box(Vector3(1.9, 0.02, 0.5)), red, Vector3(mx, FLOOR_Y + 0.91, rz0 + 1.1))
			Gear._put(self, Gear._box(Vector3(0.5, 0.6, 0.02)), red, Vector3(mx, FLOOR_Y + 0.6, rz0 + 1.56))
			for s in [-0.5, 0.5]:
				_solid(Vector3(mx + s, FLOOR_Y, rz0 + 1.1), 0.5, 0.9)
			for s in [-1, 1]:
				_brazier(Vector3(mx + s * 1.6, FLOOR_Y, rz0 + 1.2), true)
			_chest(Vector3(mx, FLOOR_Y, rz0 + 2.3), 0.0, true)
			for k in 4:
				_bones(spot.call())
			var sign := Label3D.new()
			sign.text = "THE CHIEF'S HALL"
			sign.font_size = 40
			sign.pixel_size = 0.006
			sign.modulate = Color(0.85, 0.7, 0.4)
			sign.position = Vector3(mx, FLOOR_Y + 2.0, rz0 + 0.05)
			add_child(sign)
			continue
		var kind := _r()
		if kind < 0.4:
			for k in 1 + int(_r() * 2):
				_chest(spot.call(), int(_r() * 4) * PI / 2.0, false)
		elif kind < 0.7:
			for k in 2 + int(_r() * 3):
				_barrel(spot.call())
		if rm.size.x >= 5 and rm.size.y >= 5 and _r() < 0.6:
			for a in [-1, 1]:
				for b in [-1, 1]:
					_pillar(Vector3(mx + a * (rw * 0.5 - 1.3), FLOOR_Y, mz + b * (rh * 0.5 - 1.3)))
		for k in 1 + int(_r() * 3):
			_bones(spot.call())
		for k in 1 + int(_r() * 2):
			_rubble(spot.call())
		if _r() < 0.5:
			_brazier(Vector3(mx, FLOOR_Y, mz), false)


func _pillar(p: Vector3) -> void:
	Gear._put(self, Gear._cyl(0.26, 0.3, WALL_TOP - FLOOR_Y, 12), _stone, p + Vector3.UP * (WALL_TOP - FLOOR_Y) * 0.5)
	Gear._put(self, Gear._box(Vector3(0.7, 0.16, 0.7)), _dark, p + Vector3.UP * 0.08)
	_solid(p, 0.32, WALL_TOP - FLOOR_Y)


func _brazier(p: Vector3, lit: bool) -> void:
	Gear._put(self, Gear._cyl(0.06, 0.1, 0.75, 8), _iron, p + Vector3.UP * 0.375)
	Gear._put(self, Gear._cyl(0.28, 0.16, 0.2, 12), _iron, p + Vector3.UP * 0.82)
	var c := Gear._put(self, Gear._dome(0.2), _coal, p + Vector3.UP * 0.86)
	c.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_solid(p, 0.28, 0.9)
	if lit:
		_light(p + Vector3.UP * 1.3, 1.6, 7.0)


func _chest(p: Vector3, turn: float, big: bool) -> void:
	var s := 1.4 if big else 1.0
	var g := Node3D.new()
	g.position = p
	g.rotation.y = turn
	add_child(g)
	var gold := Gear.mat(0xd8b25a, 0.35, 0.6)
	Gear._put(g, Gear._box(Vector3(0.7, 0.42, 0.45) * s), _wood, Vector3(0, 0.21 * s, 0))
	Gear._put(g, Gear._cyl(0.225 * s, 0.225 * s, 0.7 * s, 10), _wood, Vector3(0, 0.42 * s, 0), Vector3(0, 0, PI / 2), Vector3(1, 1, 1))
	for o in [-0.25, 0.25]:
		Gear._put(g, Gear._box(Vector3(0.05, 0.44, 0.47) * s), gold if big else _iron, Vector3(o * s, 0.22 * s, 0))
	Gear._put(g, Gear._box(Vector3(0.08, 0.1, 0.03)), gold, Vector3(0, 0.38 * s, 0.24 * s))
	_solid(p, 0.35 * s, 0.6 * s)


func _barrel(p: Vector3) -> void:
	Gear._put(self, Gear._cyl(0.22, 0.24, 0.6, 12), Gear.mat(0x3e2a1d), p + Vector3.UP * 0.3)
	for y in [0.12, 0.48]:
		Gear._put(self, Gear._cyl(0.235, 0.235, 0.04, 12), _iron, p + Vector3.UP * y)
	_solid(p, 0.24, 0.6)


func _bones(p: Vector3) -> void:
	var bone := Gear.mat(0xe6dfcc, 0.9)
	Gear._put(self, Gear._ball(0.1), bone, p + Vector3.UP * 0.09)
	for k in 3:
		Gear._put(self, Gear._cyl(0.022, 0.022, 0.32, 6), bone, p + Vector3((_r() - 0.5) * 0.4, 0.03, (_r() - 0.5) * 0.4),
			Vector3(0, _r() * TAU, PI / 2))


func _rubble(p: Vector3) -> void:
	for k in 3:
		var r := 0.08 + _r() * 0.14
		Gear._put(self, Gear._ball(r), _dark, p + Vector3((_r() - 0.5) * 0.5, r * 0.6, (_r() - 0.5) * 0.5), Vector3(_r(), _r(), _r()) * 3.0)


# the way in: a stair climbing south from the gap in the south wall up to the surface, walled on
# both sides all the way up
func _build_stair() -> void:
	var stair := StaticBody3D.new()
	stair.name = "Stair"
	stair.collision_layer = 1
	stair.collision_mask = 0
	add_child(stair)
	var run := STAIR / STEPS
	var rise := (0.0 - FLOOR_Y) / STEPS
	for k in STEPS:
		var top := FLOOR_Y + (k + 1) * rise
		var at := Vector3(ex, (FLOOR_Y + top) * 0.5, z1 + (k + 0.5) * run)
		var size := Vector3(C, top - FLOOR_Y, run + 0.01)
		Gear._put(self, Gear._box(size), _stone if k % 2 else _dark, at)
		var cs := CollisionShape3D.new()
		var bx := BoxShape3D.new()
		bx.size = Vector3(C, top - FLOOR_Y, run)
		cs.shape = bx
		cs.position = at
		stair.add_child(cs)
	for s in [-1, 1]:
		# the stairwell's sides: rock below, the gatehouse's walls above, one solid wall
		var x: float = ex + s * (C * 0.5 + 0.15)
		Gear._put(self, Gear._box(Vector3(0.3, -FLOOR_Y, STAIR)), _dark, Vector3(x, FLOOR_Y * 0.5, z1 + STAIR * 0.5))
		var cs := CollisionShape3D.new()
		var bx := BoxShape3D.new()
		bx.size = Vector3(0.3, 2.4 - FLOOR_Y, STAIR + 0.3)
		cs.shape = bx
		cs.position = Vector3(x, (2.4 + FLOOR_Y) * 0.5, z1 + STAIR * 0.5 - 0.15)
		_rock.add_child(cs)
		# halfway torches
		var tz := z1 + STAIR * (0.3 if s < 0 else 0.7)
		var ty := FLOOR_Y + (-FLOOR_Y) * (0.3 if s < 0 else 0.7) + 1.3
		var tx: float = ex + s * (C * 0.5 - 0.04)
		Gear._put(self, Gear._box(Vector3(0.08, 0.3, 0.08)), _iron, Vector3(tx, ty, tz))
		var f := Gear._put(self, Gear._cyl(0.0, 0.07, 0.2, 7), _flame, Vector3(tx, ty + 0.25, tz))
		f.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# a warm light halfway down, always lit, so the steps show from the top
	var sl := OmniLight3D.new()
	sl.light_color = Look.html_hex(0xffa860)
	sl.light_energy = 1.1
	sl.omni_range = 7.0
	sl.omni_attenuation = 1.6
	sl.position = Vector3(ex, FLOOR_Y * 0.55 + 1.0, z1 + STAIR * 0.45)
	add_child(sl)


# on the surface only a small stone gatehouse shows over the stairwell: walls along both sides
# and across the far end, a pitched slate roof, and an open arch at the south end with the name
# over it and a brazier either side
func _build_gatehouse() -> void:
	var wh := 2.4
	var zc := (z1 - 0.3 + z1 + STAIR) * 0.5
	var lenz := STAIR + 0.3
	for s in [-1, 1]:
		var x: float = ex + s * (C * 0.5 + 0.15)
		Gear._put(self, Gear._box(Vector3(0.3, wh, lenz)), _stone, Vector3(x, wh * 0.5, zc))
		var slit := Gear._put(self, Gear._box(Vector3(0.32, 0.5, 0.1)), _flame, Vector3(x, 1.5, z1 + STAIR * 0.45))
		slit.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	Gear._put(self, Gear._box(Vector3(C + 0.6, wh, 0.3)), _stone, Vector3(ex, wh * 0.5, z1 - 0.15))
	var far := CollisionShape3D.new()
	var fb := BoxShape3D.new()
	fb.size = Vector3(C + 0.6, wh, 0.3)
	far.shape = fb
	far.position = Vector3(ex, wh * 0.5, z1 - 0.15)
	_rock.add_child(far)
	# the roof (left out while you're down below, so you can see in)
	_roof = Node3D.new()
	add_child(_roof)
	var half := C * 0.5 + 0.45
	var rise := 0.75
	var slope := Vector2(half, rise).length()
	var ang := atan2(rise, half)
	var slate := Gear.mat(0x34313a, 0.8)
	for s in [-1, 1]:
		Gear._put(_roof, Gear._box(Vector3(slope + 0.05, 0.1, lenz + 0.4)), slate,
			Vector3(ex + s * half * 0.5, wh + rise * 0.5 + 0.05, zc), Vector3(0, 0, -s * ang))
	Gear._put(_roof, Gear._box(Vector3(0.12, 0.12, lenz + 0.45)), _dark, Vector3(ex, wh + rise + 0.08, zc))
	# the arch: two piers, a lintel with the name, braziers and a couple of flagstones
	var mouth := z1 + STAIR
	for s in [-1, 1]:
		var px: float = ex + s * (C * 0.5 + 0.35)
		Gear._put(self, Gear._box(Vector3(0.5, 2.5, 0.6)), _dark, Vector3(px, 1.25, mouth + 0.1))
		_solid(Vector3(px, 0, mouth + 0.1), 0.3, 2.5)
		_brazier(Vector3(ex + s * 2.1, 0.0, mouth + 0.9), false)
	Gear._put(self, Gear._box(Vector3(C + 1.4, 0.45, 0.7)), _dark, Vector3(ex, 2.7, mouth + 0.1))
	var sign := Label3D.new()
	sign.text = NAME
	sign.font_size = 48
	sign.pixel_size = 0.005
	sign.modulate = Look.html_hex(0xd8b25a)
	sign.position = Vector3(ex, 2.7, mouth + 0.47)
	add_child(sign)
	for k in 2:
		Gear._put(self, Gear._box(Vector3(C + 0.4, 0.05, 0.4)), _stone, Vector3(ex, 0.025, mouth + 0.45 + k * 0.4))
	var glow := OmniLight3D.new()
	glow.light_color = Look.html_hex(0xff8a3d)
	glow.light_energy = 1.0
	glow.omni_range = 5.0
	glow.position = Vector3(ex, 1.2, mouth + 1.0)
	add_child(glow)


# Something over the lair that casts shadow but isn't drawn: the sun doesn't shine down here.
func _build_ceiling() -> void:
	var lid := Gear._put(self, Gear._box(Vector3(x1 - x0 + 0.4, 0.2, z1 - z0 + 0.4)), _dark,
		Vector3((x0 + x1) * 0.5, -0.25, (z0 + z1) * 0.5))
	lid.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY


func _bake_nav() -> void:
	var nm := WorldNav.new_nav_mesh()
	var area := nav_rect().grow(WorldNav.BORDER)
	nm.filter_baking_aabb = AABB(Vector3(area.position.x, WorldNav.BAKE_Y0 + FLOOR_Y, area.position.y),
		Vector3(area.size.x, 6.5, area.size.y))
	nm.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nm.geometry_collision_mask = 1
	nm.geometry_source_geometry_mode = NavigationMesh.SOURCE_GEOMETRY_ROOT_NODE_CHILDREN
	var data := NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(nm, data, self)
	# the open ground over it all, except the stairwell
	var g := area.grow(1.0)
	var w := stairwell()
	for r in [Rect2(g.position.x, g.position.y, w.x - g.position.x, g.size.y),
			Rect2(w.z, g.position.y, g.end.x - w.z, g.size.y),
			Rect2(w.x, g.position.y, w.z - w.x, w.y - g.position.y),
			Rect2(w.x, w.w, w.z - w.x, g.end.y - w.w)]:
		var rr := r as Rect2
		var a := Vector3(rr.position.x, 0, rr.position.y)
		var b := Vector3(rr.end.x, 0, rr.position.y)
		var c := Vector3(rr.end.x, 0, rr.end.y)
		var d := Vector3(rr.position.x, 0, rr.end.y)
		data.add_faces(PackedVector3Array([a, b, c, a, c, d]), Transform3D.IDENTITY)
	NavigationServer3D.bake_from_source_geometry_data(nm, data)
	var region := NavigationRegion3D.new()
	region.name = "Nav"
	region.navigation_mesh = nm
	region.position.y = -WorldNav.NAV_SINK
	add_child(region)


# ---- the goblins ----

func _populate() -> void:
	var halls := rooms.slice(1)
	if halls.is_empty():
		halls = rooms
	for k in GOBLINS:
		var rm: Rect2i = halls[k % halls.size()]
		var g := Monster.new()
		g.in_lair = true
		g.beat = _beat(rm)
		g.camp = g.beat[0]
		get_parent().add_child.call_deferred(g)
		g.position = g.beat[0]
		_monsters.append(g)
	# the chief paces in front of his altar
	var hall := rooms[0]
	var mx := x0 + (hall.position.x + hall.size.x * 0.5) * C
	var hz := z0 + hall.position.y * C + 3.4
	var chief := Monster.new()
	chief.in_lair = true
	chief.chief = true
	var pace: Array[Vector3] = [Vector3(mx - 2.2, FLOOR_Y, hz), Vector3(mx + 2.2, FLOOR_Y, hz)]
	chief.beat = pace
	chief.camp = chief.beat[0]
	get_parent().add_child.call_deferred(chief)
	chief.position = chief.beat[0]
	_monsters.append(chief)


# a few spots for a goblin to walk between: in its own room, and in the tunnels nearby
func _beat(rm: Rect2i) -> Array[Vector3]:
	var out: Array[Vector3] = []
	out.append(_cell_pos(rm.position.x + int(_r() * rm.size.x), rm.position.y + int(_r() * rm.size.y)))
	var tries := 0
	while out.size() < 4 and tries < 200:
		tries += 1
		var i := 1 + int(_r() * (N - 2))
		var j := 1 + int(_r() * (N - 2))
		if not grid[_at(i, j)] or j >= N - 2:
			continue
		var p := _cell_pos(i, j)
		if Hex.distance(p, out[0]) < 14.0:
			out.append(p)
	return out


func _process(_delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player") as PlayerController
	var ctrl := player.controlled if player else null
	var now := ctrl != null and holds(ctrl.position)
	if now == under:
		return
	under = now
	if _ground_mat:
		_ground_mat.set_shader_parameter("cut_on", under)
	for l in _lights:
		l.visible = under
	for c in _roof.find_children("*", "GeometryInstance3D", true, false):
		(c as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY if under \
			else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
