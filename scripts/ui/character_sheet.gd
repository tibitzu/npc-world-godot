class_name CharacterSheet
extends PanelContainer
## The character sheet (C, as in the HTML game): a large sheet for any resident the town knows,
## picked from the list down its left side (or with Left and Right). It shows what they're doing
## and where, their health, their weapon, how well they defend themselves, their six abilities
## (what each score does for them, and any potion working on one), their needs, and what they
## carry. Take control of them (or let go) from its top corner.

var resident: Resident = null
var player: PlayerController

var _list: VBoxContainer
var _picks := {}                   # Resident -> Button
var _page: VBoxContainer
var _shown := ""
var _tick := 0.0

const INK := Color(0.95, 0.93, 0.86)
const DIM := Color(0.75, 0.73, 0.68)
const SOFT := Color(0.85, 0.83, 0.78)
const UP := Color(0.6, 0.82, 1.0)      # a potion's boost
const HI := Color(0.62, 0.9, 0.55)     # a strong score
const LO := Color(1.0, 0.55, 0.48)     # a weak one


## A thin bar: a fraction of it filled with a colour.
class Bar extends Control:
	var frac := 0.0
	var colour := Color.WHITE

	func _init(f: float, c: Color, h := 8.0) -> void:
		frac = clampf(f, 0.0, 1.0)
		colour = c
		custom_minimum_size = Vector2(0, h)
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var r := size.y * 0.5
		draw_style_box(_box(Color(1, 1, 1, 0.1), r), Rect2(Vector2.ZERO, size))
		if frac > 0.0:
			draw_style_box(_box(colour, r), Rect2(Vector2.ZERO, Vector2(maxf(size.y, size.x * frac), size.y)))

	static func _box(c: Color, r: float) -> StyleBoxFlat:
		var sb := StyleBoxFlat.new()
		sb.bg_color = c
		sb.set_corner_radius_all(int(r))
		return sb


func _ready() -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.07, 0.09, 1.0)
	sb.border_color = Color(0.95, 0.93, 0.86, 0.2)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(16)
	add_theme_stylebox_override("panel", sb)
	anchor_left = 0.5
	anchor_right = 0.5
	anchor_top = 0.0
	anchor_bottom = 1.0
	offset_left = -470.0
	offset_right = 470.0
	offset_top = 64.0
	offset_bottom = -44.0
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	add_child(row)
	_list = VBoxContainer.new()
	_list.custom_minimum_size = Vector2(170, 0)
	_list.add_theme_constant_override("separation", 4)
	row.add_child(_list)
	_list.add_child(_label("RESIDENTS", 11, DIM))
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	row.add_child(scroll)
	_page = VBoxContainer.new()
	_page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_page.add_theme_constant_override("separation", 10)
	scroll.add_child(_page)
	visible = false


## Open on someone (or whoever was shown last, or the first resident).
func open(r: Resident = null) -> void:
	_fill_list()
	if r == null or not r.known:
		r = resident if resident and is_instance_valid(resident) and resident.known else null
	if r == null:
		for o in _picks:
			if (o as Resident).known:
				r = o
				break
	if r == null:
		return
	resident = r
	_shown = ""
	visible = true
	Game.sheet_open = true
	_rebuild()


func close() -> void:
	visible = false
	Game.sheet_open = false


## The next (or previous) resident the town knows.
func cycle(step: int) -> void:
	var all: Array = _picks.keys().filter(func(o: Resident) -> bool: return o.known)
	if all.is_empty():
		return
	var i := all.find(resident)
	resident = all[posmod(i + step, all.size())]
	_shown = ""
	_rebuild()


func _fill_list() -> void:
	if not _picks.is_empty():
		return
	for o in get_tree().get_nodes_in_group("residents"):
		var r := o as Resident
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.toggle_mode = true
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_size_override("font_size", 13)
		b.add_theme_color_override("font_color", Look.html_colour(r.def.colour).lightened(0.3))
		b.add_theme_color_override("font_pressed_color", Look.html_colour(r.def.colour).lightened(0.5))
		b.pressed.connect(func() -> void:
			resident = r
			_shown = ""
			_rebuild())
		_list.add_child(b)
		_picks[r] = b


func _process(delta: float) -> void:
	if not visible:
		return
	if resident == null or not is_instance_valid(resident):
		close()
		return
	_tick -= delta
	if _tick <= 0.0:
		_tick = 0.25
		_rebuild()


func _input(event: InputEvent) -> void:
	if not visible or Game.typing or not (event is InputEventKey) or not event.pressed:
		return
	var k := (event as InputEventKey).keycode
	if k == KEY_LEFT or k == KEY_RIGHT:
		cycle(-1 if k == KEY_LEFT else 1)
		get_viewport().set_input_as_handled()


static func _label(text: String, size: int, colour: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", colour)
	return l


func _wrapped(text: String, size: int, colour: Color) -> Label:
	var l := _label(text, size, colour)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


# a card: a box with a small heading, holding whatever is added to what it returns
func _card(parent: Control, title: String) -> VBoxContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, 0.045)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(12)
	p.add_theme_stylebox_override("panel", sb)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	p.add_child(v)
	v.add_child(_label(title.to_upper(), 11, DIM))
	return v


func _big(text: String, small := "", size := 30) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	var a := _label(text, size, INK)
	h.add_child(a)
	if small != "":
		var b := _label(small, 13, DIM)
		b.size_flags_vertical = Control.SIZE_SHRINK_END
		h.add_child(b)
	return h


func _row() -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	_page.add_child(h)
	return h


# where they are, in words
func _where(r: Resident) -> String:
	if r.position.y < Monster.LAIR_TOP:
		return "down in the Black Warrens"
	for b in get_tree().get_nodes_in_group("buildings"):
		var bld := b as Building
		if bld.def and bld.is_inside(r.position):
			return "in " + bld.def.display_name
	var c := Vector2.ZERO
	var half := 10.0
	var sq := get_tree().get_first_node_in_group("town_square") as TownSquare
	if sq:
		c = sq.centre
		half = sq.size * 0.5
	var o := Hex.offset(Vector3(c.x, 0, c.y), r.position)
	if absf(o.x) < half and absf(o.z) < half:
		return "on the town square"
	return "%d m %s, %d m %s of the square" % [absi(roundi(o.x)), "east" if o.x >= 0 else "west",
		absi(roundi(o.z)), "south" if o.z >= 0 else "north"]


func _rebuild() -> void:
	var r := resident
	if r == null:
		return
	var w := r.weapon()
	var key := "%s|%d|%d|%s|%s|%s|%s|%s|%s|%d|%d|%s|%s" % [r.name, roundi(r.hp), roundi(r.hp_max()), r.status(), _where(r),
		[roundi(r.needs.fatigue), roundi(r.needs.happiness), roundi(r.needs.hunger), roundi(r.needs.thirst)],
		r.bag.items, r.equip, r.pack, r.purse(), Abilities.boost_minutes(r), w.dmg, r.controlled]
	for o in _picks:
		var res := o as Resident
		key += "|%s%s%s" % [res.known, res.dead, res.controlled]
	if key == _shown:
		return
	_shown = key
	# the list
	for o in _picks:
		var res := o as Resident
		var b := _picks[o] as Button
		b.visible = res.known
		b.set_pressed_no_signal(res == r)
		b.text = "%s\n%s" % [res.def.display_name, "Dead" if res.dead else ("Played by you" if res.controlled else res.def.profession)]
		b.modulate.a = 0.55 if res.dead else 1.0
	for c in _page.get_children():
		c.queue_free()

	# who they are, and taking control
	var head := HBoxContainer.new()
	_page.add_child(head)
	var who := VBoxContainer.new()
	who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	who.add_theme_constant_override("separation", 0)
	head.add_child(who)
	var role := r.def.role if r.def.role.begins_with(r.def.profession) else "%s · %s" % [r.def.profession, r.def.role]
	who.add_child(_label(role.to_upper(), 11, Look.html_colour(r.def.colour).lightened(0.35)))
	who.add_child(_label(r.def.display_name, 28, INK))
	var hours := "Sleeps %s–%s" % [Game.clock_text(r.def.sleep_hour), Game.clock_text(r.def.wake_hour)]
	if r.def.job != "":
		hours += " · works %s–%s" % [Game.clock_text(r.def.work_from), Game.clock_text(r.def.work_to)]
	who.add_child(_wrapped("%s, %s\n%s" % [r.status(), _where(r), hours], 13, SOFT))
	var acts := VBoxContainer.new()
	acts.alignment = BoxContainer.ALIGNMENT_BEGIN
	head.add_child(acts)
	var btn := Button.new()
	btn.focus_mode = Control.FOCUS_NONE
	btn.custom_minimum_size = Vector2(170, 34)
	for st in ["normal", "hover", "pressed", "disabled"]:
		var bs := StyleBoxFlat.new()
		bs.bg_color = Color(1, 1, 1, {"normal": 0.08, "hover": 0.16, "pressed": 0.22, "disabled": 0.04}[st])
		bs.border_color = Color(Look.html_colour(r.def.colour), 0.6 if st != "disabled" else 0.2)
		bs.set_border_width_all(1)
		bs.set_corner_radius_all(6)
		bs.set_content_margin_all(6)
		btn.add_theme_stylebox_override(st, bs)
	if r.dead:
		btn.text = "Dead until a new game"
		btn.disabled = true
	elif r.controlled:
		btn.text = "Let go of %s" % r.def.display_name
		btn.pressed.connect(func() -> void: player.let_go())
	else:
		btn.text = "Take control"
		btn.pressed.connect(func() -> void:
			player.possess(r)
			close())
	acts.add_child(btn)

	# health, weapon, defence
	var row := _row()
	var hp := _card(row, "Health")
	hp.add_child(_big(str(roundi(r.hp)), "/ %d" % roundi(r.hp_max())))
	hp.add_child(Bar.new(r.hp / r.hp_max(), Color(1.0, 0.42, 0.35) if r.hp <= r.hp_max() * 0.25 else Color(0.94, 0.54, 0.48)))
	var con_add := Abilities.HP_PER_CON * r.ability_mod("con")
	hp.add_child(_wrapped("%d base, %s from Constitution" % [roundi(r.def.hp_max), Abilities.signed(con_add)], 12, DIM))

	var wc := _card(row, "Weapon" + (" · in hand" if r.equip.hand != "" else ""))
	wc.add_child(_big(String(w.name), "", 22))
	var dmg_line := "%d–%d damage a blow (base %d–%d, %s from %s" % [w.dmg.x, w.dmg.y, w.base.x, w.base.y,
		Abilities.signed(w.mod), Abilities.NAMES[w.ab]]
	if r.might_left() > 0.0:
		dmg_line += ", +%d from the elixir" % int(Items.info("elixir").might)
	wc.add_child(_wrapped(dmg_line + ")", 12, SOFT))
	wc.add_child(_wrapped("One every %.2f s · reach %.1f m%s" % [w.cd, w.reach, " (bolts of light)" if w.get("ranged", false) else ""], 12, DIM))

	var dc := _card(row, "Defence")
	dc.add_child(_big(str(roundi(Abilities.dodge(r.ability("agi")) * 100.0)), "% dodge"))
	var notes := "From Agility. Mends %.2f health a second out of danger (Wisdom), faster in bed." % [0.4 * Abilities.mending(r.ability("wis"))]
	if r.equip.ring != "":
		notes += " Ring of protection: 2 off every blow."
	if r.equip.back == "cloak":
		notes += " Cloak of shadows: goblins see them from half as far."
	dc.add_child(_wrapped(notes, 12, DIM))

	# abilities
	var ac := _card(_page, "Abilities")
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	ac.add_child(grid)
	for k in Abilities.KEYS:
		grid.add_child(_ability_tile(r, k))

	# needs, and what they carry
	row = _row()
	var nc := _card(row, "Needs")
	for d in [["fatigue", "Fatigue", Look.html_hex(0xb9a6f0)], ["happiness", "Happiness", Look.html_hex(0xf2c86b)],
			["hunger", "Hunger", Look.html_hex(0xe59a6a)], ["thirst", "Thirst", Look.html_hex(0x7fc4e8)]]:
		var v: float = r.needs[d[0]]
		var line := HBoxContainer.new()
		var n := _label(d[1], 12, SOFT)
		n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(n)
		line.add_child(_label("%d/100" % roundi(v), 12, DIM))
		nc.add_child(line)
		nc.add_child(Bar.new(v / 100.0, d[2] if v >= 15.0 else LO, 6.0))
	var cc := _card(row, "Carrying")
	cc.add_child(_label("%d gold · %d silver" % [r.bag.gold, r.bag.silver], 14, Color(1.0, 0.85, 0.45)))
	var pack: Array[String] = []
	for kind in ["logs", "parcels"]:
		if r.pack.get(kind, 0) > 0:
			pack.append("%d %s" % [r.pack[kind], kind if r.pack[kind] > 1 else kind.trim_suffix("s")])
	cc.add_child(_label("Pack: " + (", ".join(pack) if not pack.is_empty() else "empty"), 12, SOFT))
	var worn: Array[String] = []
	for slot in ["hand", "ring", "back"]:
		if r.equip[slot] != "":
			worn.append(Items.title(r.equip[slot]))
	if not worn.is_empty():
		cc.add_child(_wrapped("Wearing or wielding: " + ", ".join(worn), 12, SOFT))
	var counts := {}
	for k in r.bag.items:
		counts[k] = counts.get(k, 0) + 1
	if counts.is_empty():
		cc.add_child(_wrapped("Nothing in the bag. The chests in the goblins' lair hold treasure, and Tilda sells potions.", 12, DIM))
	else:
		var things: Array[String] = []
		for k in Items.ALL:
			if counts.has(k):
				things.append(Items.title(k) + (" ×%d" % counts[k] if counts[k] > 1 else ""))
		var l := _wrapped(", ".join(things), 12, SOFT)
		cc.add_child(l)

	_page.add_child(_label("C or Esc to close · Left and Right for the next resident · I for the inventory while playing", 11, DIM))


func _ability_tile(r: Resident, k: String) -> Control:
	var v := r.ability(k)
	var m := Abilities.mod(v)
	var up := r.boost_of(k)
	var tint := UP if up > 0 else (HI if m >= 2 else (LO if m < 0 else INK))
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, 0.04)
	sb.border_color = Color(tint, 0.35)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(10)
	p.add_theme_stylebox_override("panel", sb)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.custom_minimum_size = Vector2(190, 0)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	p.add_child(col)
	col.add_child(_label(String(Abilities.NAMES[k]).to_upper(), 11, DIM))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	col.add_child(h)
	h.add_child(_label(str(v), 26, tint))
	var ml := _label(Abilities.signed(m), 15, SOFT)
	ml.size_flags_vertical = Control.SIZE_SHRINK_END
	h.add_child(ml)
	if up > 0:
		var bl := _label("+%d potion, %s left" % [up, Abilities.duration(r.boost_left(k))], 11, UP)
		bl.size_flags_vertical = Control.SIZE_SHRINK_END
		h.add_child(bl)
	col.add_child(_wrapped(Abilities.effect(k, v), 12, DIM))
	p.tooltip_text = "%s %d (%d of their own%s), modifier %s" % [Abilities.NAMES[k], v, v - up,
		", +%d from a potion" % up if up > 0 else "", Abilities.signed(m)]
	return p
