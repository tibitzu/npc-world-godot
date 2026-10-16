class_name Gear
extends RefCounted
## What residents wear and carry by default, as in the HTML game: a hat, trousers, shoes, a few
## extras (Tilda's apron, the guards' tabards and bracers, Brann's beard) and the tool of their
## trade in their right hand. Each resident's outfit is in their NpcDef (hat, tool, trousers,
## shoes, extras, plume).
##
## Everything is built in the body's own space (before its 1.5x scale), from the HTML game's
## shapes, with the head 7 cm lower than there.

const HEAD_DROP := 0.07

const HATS := ["strawhat", "couriercap", "tophat", "beanie", "headscarf", "guardhelm", "wizhat"]
const TOOLS := ["trowel", "lanternpole", "fellingaxe", "guardspear", "cudgel", "wizstaff"]
## What each tool does as a weapon: damage per hit (low, high), reach (m) and seconds between blows.
const WEAPONS := {
	"": {"name": "Fists", "dmg": Vector2i(2, 4), "reach": 1.5, "cd": 0.6},
	"trowel": {"name": "Trowel", "dmg": Vector2i(2, 4), "reach": 1.6, "cd": 0.8},
	"lanternpole": {"name": "Lantern pole", "dmg": Vector2i(2, 5), "reach": 2.1, "cd": 1.0},
	"fellingaxe": {"name": "Felling axe", "dmg": Vector2i(5, 9), "reach": 1.8, "cd": 1.2},
	"guardspear": {"name": "Spear", "dmg": Vector2i(5, 9), "reach": 2.5, "cd": 1.0},
	"cudgel": {"name": "Cudgel", "dmg": Vector2i(3, 6), "reach": 1.6, "cd": 0.9},
	# the wizard's staff throws bolts of light (ranged: a bolt flies to whatever it's aimed at)
	"wizstaff": {"name": "Oak staff", "dmg": Vector2i(5, 9), "reach": 8.0, "cd": 1.2, "ranged": true},
}
const SHOE_COLOURS := {"clogs": 0xb08a4a, "runshoes": 0xe6e2da, "buckleshoes": 0x24222b, "workboots": 0x5a3a22, "guardboots": 0x2a1d14}


static func mat(hex: int, rough := 0.85, metal := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Look.html_hex(hex)
	m.roughness = rough
	m.metallic = metal
	return m


static func _put(parent: Node3D, mesh: Mesh, m: Material, at: Vector3, rot := Vector3.ZERO, sc := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	mi.position = at
	mi.rotation = rot
	mi.scale = sc
	parent.add_child(mi)
	return mi


static func _cyl(top: float, bottom: float, h: float, seg := 16) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = h
	c.radial_segments = seg
	c.rings = 1
	return c


static func _box(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b


static func _dome(r: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r
	s.is_hemisphere = true
	s.radial_segments = 16
	s.rings = 6
	return s


static func _ball(r: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = 2.0 * r
	s.radial_segments = 10
	s.rings = 6
	return s


## Dress a resident (call once their body exists): hat, extras, trousers and shoes.
static func dress(body: Node3D, def: NpcDef) -> void:
	var g := Node3D.new()
	g.name = "Gear"
	body.add_child(g)
	_hat(g, def.hat, def.plume)
	var steel := mat(0xc3cbd4, 0.3, 0.7)
	for e in def.extras:
		match e:
			"beard":
				_put(g, _box(Vector3(0.2, 0.12, 0.08)), mat(0x6b3f22, 1.0), Vector3(0, 0.745 - HEAD_DROP, 0.115))
			"beard_white":
				# a long white beard, down to the chest
				_put(g, _cyl(0.1, 0.02, 0.32, 8), mat(0xeeeae2, 1.0), Vector3(0, 0.63 - HEAD_DROP, 0.12), Vector3(0.12, 0, 0), Vector3(1, 1, 0.6))
			"robe":
				# a long starry robe to the ankles
				_put(g, _cyl(0.16, 0.27, 0.6, 14), mat(0x34407a, 1.0), Vector3(0, 0.33, 0))
				var star := mat(0xd8b25a, 0.4, 0.5)
				for i in 6:
					var a := i * 2.39
					var yy := 0.12 + fmod(i * 0.083, 0.42)
					var rr := 0.27 - (yy - 0.03) / 0.6 * 0.11 + 0.005
					_put(g, _box(Vector3(0.03, 0.03, 0.01)), star, Vector3(sin(a) * rr, yy, cos(a) * rr), Vector3(0, a, 0.78))
			"apron":
				_put(g, _box(Vector3(0.21, 0.3, 0.02)), mat(0xe8b85a, 1.0), Vector3(0, 0.38, 0.155), Vector3(-0.08, 0, 0))
				_put(g, _box(Vector3(0.24, 0.025, 0.31)), mat(0xe8b85a, 1.0), Vector3(0, 0.52, 0.0))
			"tabard":
				_put(g, _box(Vector3(0.2, 0.3, 0.02)), mat(0xd8b25a, 0.6, 0.3), Vector3(0, 0.47, 0.15), Vector3(-0.07, 0, 0))
			"bracers":
				for arm in ["ArmL", "ArmR"]:
					var a := body.get_node(arm) as Node3D
					_put(a, _cyl(0.05, 0.046, 0.13, 8), mat(0x6b4a2e, 0.9), Vector3(0, -0.2, 0))
	# trousers and shoes
	var legs := mat(def.trousers, 0.9) if def.trousers != 0 else null
	var shoe_hex: int = SHOE_COLOURS.get(def.shoes, -1)
	for leg in ["LegL", "LegR"]:
		var l := body.get_node(leg) as Node3D
		if legs:
			(l.get_node("Mesh") as MeshInstance3D).material_override = legs
		if shoe_hex >= 0:
			var tall := def.shoes.ends_with("boots")
			_put(l, _box(Vector3(0.1, 0.1 if tall else 0.06, 0.16)), mat(shoe_hex, 0.8), Vector3(0, -0.25 if not tall else -0.23, 0.025))


static func _hat(g: Node3D, k: String, plume: Color) -> void:
	var y := -HEAD_DROP
	match k:
		"strawhat":
			var m := mat(0xe9cf8a, 1.0)
			_put(g, _cyl(0.27, 0.27, 0.02, 20), m, Vector3(0, 0.97 + y, 0))
			_put(g, _cyl(0.11, 0.14, 0.11), m, Vector3(0, 1.03 + y, 0))
			_put(g, _cyl(0.142, 0.142, 0.025), mat(0xc23b2f, 1.0), Vector3(0, 0.99 + y, 0))
		"couriercap":
			var m := mat(0x2c5b86, 0.9)
			_put(g, _dome(0.158), m, Vector3(0, 0.89 + y, 0))
			_put(g, _box(Vector3(0.17, 0.015, 0.13)), m, Vector3(0, 0.9 + y, 0.16))
		"tophat":
			var m := mat(0x24222b, 0.7)
			_put(g, _cyl(0.2, 0.2, 0.02, 18), m, Vector3(0, 0.98 + y, 0))
			_put(g, _cyl(0.11, 0.11, 0.25), m, Vector3(0, 1.11 + y, 0))
			_put(g, _cyl(0.112, 0.112, 0.035), mat(0x5b3f6b, 0.9), Vector3(0, 1.02 + y, 0))
		"beanie":
			_put(g, _dome(0.162), mat(0xb8352b, 1.0), Vector3(0, 0.9 + y, 0), Vector3.ZERO, Vector3(1, 1.15, 1))
			_put(g, _cyl(0.165, 0.165, 0.06, 18), mat(0x8e2820, 1.0), Vector3(0, 0.92 + y, 0))
			_put(g, _ball(0.05), mat(0xf1ebdf, 1.0), Vector3(0, 1.1 + y, 0))
		"headscarf":
			var m := mat(0xd39b3a, 1.0)
			_put(g, _dome(0.163), m, Vector3(0, 0.87 + y, 0), Vector3.ZERO, Vector3(1, 0.9, 1))
			_put(g, _ball(0.045), m, Vector3(0, 0.92 + y, -0.16))
		"guardhelm":
			var m := mat(0xc3cbd4, 0.3, 0.7)
			_put(g, _dome(0.165), m, Vector3(0, 0.88 + y, 0))
			_put(g, _cyl(0.2, 0.2, 0.02, 18), m, Vector3(0, 0.89 + y, 0))
			_put(g, _box(Vector3(0.025, 0.11, 0.02)), m, Vector3(0, 0.86 + y, 0.16))
			var pm := StandardMaterial3D.new()
			pm.albedo_color = plume
			pm.roughness = 1.0
			_put(g, _box(Vector3(0.04, 0.12, 0.26)), pm, Vector3(0, 1.08 + y, 0))
		"wizhat":
			# a tall violet cone with a wide brim, a gold band and stars
			var m := mat(0x4a2f7a, 0.9)
			var gold := mat(0xd8b25a, 0.4, 0.5)
			_put(g, _cyl(0.27, 0.27, 0.02, 20), m, Vector3(0, 0.95 + y, 0))
			_put(g, _cyl(0.0, 0.15, 0.5, 16), m, Vector3(0, 1.21 + y, -0.02), Vector3(-0.12, 0, 0))
			_put(g, _cyl(0.152, 0.152, 0.04, 16), gold, Vector3(0, 0.98 + y, 0))
			for i in 4:
				var a := i * 1.7
				_put(g, _box(Vector3(0.035, 0.035, 0.01)), gold, Vector3(sin(a) * 0.1, 1.08 + y + i * 0.055, cos(a) * 0.1), Vector3(0, a, 0.78))


## The tool of their trade, held in the right hand (built under `hand`, the arm's own space).
static func tool_in(hand: Node3D, k: String) -> void:
	var w := Node3D.new()
	w.position = Vector3(0, -0.28, 0.04)
	w.rotation.x = 0.5
	hand.add_child(w)
	var wood := mat(0x7a5233)
	var steel := mat(0xc3cbd4, 0.3, 0.7)
	match k:
		"trowel":
			w.rotation.x = 0.6
			_put(w, _cyl(0.016, 0.016, 0.1, 6), wood, Vector3.ZERO)
			_put(w, _box(Vector3(0.055, 0.12, 0.008)), steel, Vector3(0, 0.11, 0))
		"lanternpole":
			w.rotation.x = 0.15
			_put(w, _cyl(0.013, 0.013, 1.0, 6), wood, Vector3(0, 0.35, 0))
			_put(w, _box(Vector3(0.012, 0.012, 0.09)), mat(0x3a2a20), Vector3(0, 0.84, 0.04))
			var lamp := StandardMaterial3D.new()
			lamp.albedo_color = Look.html_hex(0xffd18a)
			lamp.emission_enabled = true
			lamp.emission = Look.html_hex(0xffb84d)
			lamp.emission_energy_multiplier = 1.5
			_put(w, _box(Vector3(0.07, 0.09, 0.07)), lamp, Vector3(0, 0.78, 0.08))
		"fellingaxe":
			w.rotation.x = 0.55
			_put(w, _cyl(0.016, 0.02, 0.6, 6), wood, Vector3(0, 0.2, 0))
			_put(w, _box(Vector3(0.03, 0.1, 0.15)), steel, Vector3(0, 0.45, 0.06))
		"guardspear":
			w.rotation.x = 0.05
			_put(w, _cyl(0.014, 0.014, 1.3, 6), wood, Vector3(0, 0.3, 0))
			_put(w, _cyl(0.0, 0.03, 0.13, 6), steel, Vector3(0, 1.0, 0))
		"cudgel":
			w.rotation.x = 0.6
			_put(w, _cyl(0.045, 0.022, 0.42, 7), wood, Vector3(0, 0.18, 0))
		"wizstaff":
			w.rotation.x = 0.1
			_put(w, _cyl(0.018, 0.024, 1.5, 6), wood, Vector3(0, 0.42, 0))
			_put(w, _cyl(0.07, 0.07, 0.02, 12), mat(0xd8b25a, 0.4, 0.6), Vector3(0, 1.18, 0))
			var orb := mat(0xb8b0ff, 0.3)
			orb.emission_enabled = true
			orb.emission = Look.html_hex(0x8f86ff)
			orb.emission_energy_multiplier = 2.0
			var o := _put(w, _ball(0.05), orb, Vector3(0, 1.22, 0))
			o.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# weapons found in the goblins' lair or bought at the store
		"dagger":
			w.rotation.x = 0.7
			_put(w, _cyl(0.018, 0.018, 0.1, 6), mat(0x3a2a20), Vector3.ZERO)
			_put(w, _box(Vector3(0.08, 0.02, 0.02)), mat(0xb08a3a, 0.4, 0.6), Vector3(0, 0.06, 0))
			_put(w, _box(Vector3(0.035, 0.2, 0.008)), steel, Vector3(0, 0.17, 0))
		"shortsword":
			w.rotation.x = 0.6
			_put(w, _cyl(0.018, 0.018, 0.13, 6), mat(0x3a2a20), Vector3.ZERO)
			_put(w, _box(Vector3(0.14, 0.025, 0.03)), mat(0xb08a3a, 0.4, 0.6), Vector3(0, 0.075, 0))
			_put(w, _box(Vector3(0.045, 0.48, 0.01)), steel, Vector3(0, 0.33, 0))
		"mace":
			w.rotation.x = 0.6
			_put(w, _cyl(0.018, 0.02, 0.45, 6), wood, Vector3(0, 0.15, 0))
			_put(w, _ball(0.06), steel, Vector3(0, 0.4, 0))
			for f in 4:
				_put(w, _box(Vector3(0.14, 0.05, 0.015)), steel, Vector3(0, 0.4, 0), Vector3(0, f * PI / 4.0, 0))
		"waraxe":
			w.rotation.x = 0.55
			_put(w, _cyl(0.018, 0.022, 0.7, 6), wood, Vector3(0, 0.22, 0))
			_put(w, _box(Vector3(0.03, 0.2, 0.2)), steel, Vector3(0, 0.5, 0.08))
			_put(w, _box(Vector3(0.03, 0.06, 0.08)), steel, Vector3(0, 0.5, -0.06))
