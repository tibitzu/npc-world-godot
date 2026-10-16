class_name InventoryPanel
extends PanelContainer
## What the resident you're playing carries (I): their coins, what's in their hand and what
## they're wearing, and everything in their bag. Click a thing to use it: wield or put away a
## weapon, put on or take off a ring or a cloak, drink a potion (see Items).

var resident: Resident = null

var _body: VBoxContainer
var _list: VBoxContainer
var _note: Label
var _tick := 0.0
var _shown := ""


func _ready() -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.07, 0.09, 0.86)
	sb.border_color = Color(0.95, 0.93, 0.86, 0.18)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(12)
	add_theme_stylebox_override("panel", sb)
	anchor_left = 0.0
	anchor_right = 0.0
	anchor_top = 0.0
	anchor_bottom = 1.0
	offset_left = 16.0
	offset_right = 376.0
	offset_top = 166.0
	offset_bottom = -264.0
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	add_child(v)
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 3)
	v.add_child(_body)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 2)
	scroll.add_child(_list)
	_note = _label("", 12, Color(1, 0.87, 0.6))
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_note)
	visible = false


func open(r: Resident) -> void:
	if resident and is_instance_valid(resident) and resident.bagged.is_connected(_rebuild):
		resident.bagged.disconnect(_rebuild)
	resident = r
	r.bagged.connect(_rebuild)
	_note.text = ""
	visible = true
	_rebuild()


func close() -> void:
	if resident and is_instance_valid(resident) and resident.bagged.is_connected(_rebuild):
		resident.bagged.disconnect(_rebuild)
	resident = null
	visible = false


func _process(delta: float) -> void:
	if not visible:
		return
	_tick -= delta
	if _tick <= 0.0:
		_tick = 0.25
		_rebuild()                     # health and the elixir tick down


static func _label(text: String, size: int, colour: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", colour)
	return l


func _rebuild() -> void:
	var r := resident
	if r == null or not is_instance_valid(r):
		return
	var w := r.weapon()
	var key := "%s|%s|%s|%d|%d|%d" % [r.bag.items, r.equip, w.dmg, r.purse(), int(r.hp), ceili(r.might_left())]
	if key == _shown:
		return
	_shown = key
	for c in _body.get_children():
		c.queue_free()
	for c in _list.get_children():
		c.queue_free()
	var head := HBoxContainer.new()
	_body.add_child(head)
	var t := _label("%s's things" % r.def.display_name, 16, Color(0.95, 0.93, 0.86))
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	head.add_child(_label("I to close", 11, Color(0.75, 0.73, 0.68)))
	_body.add_child(_label("%d gold · %d silver" % [r.bag.gold, r.bag.silver], 14, Color(1.0, 0.85, 0.45)))
	var hand := "%s %d–%d, reach %.1f m" % [w.name, w.dmg.x, w.dmg.y, w.reach]
	if r.might_left() > 0.0:
		hand += " (elixir)"
	_body.add_child(_label("In hand: " + hand, 12, Color(0.85, 0.83, 0.78)))
	var worn: Array[String] = []
	for slot in ["ring", "back"]:
		if r.equip[slot] != "":
			worn.append(Items.title(r.equip[slot]))
	_body.add_child(_label("Wearing: " + (", ".join(worn) if not worn.is_empty() else "nothing special"), 12, Color(0.85, 0.83, 0.78)))
	_body.add_child(_label("Health %d / %d" % [int(r.hp), int(r.def.hp_max)], 12, Color(0.85, 0.83, 0.78)))
	# the bag, one line per kind of thing
	var counts := {}
	for k in r.bag.items:
		counts[k] = counts.get(k, 0) + 1
	if counts.is_empty():
		_list.add_child(_label("Nothing in the bag yet. The chests in the goblins' lair hold treasure, and Tilda sells potions.", 12, Color(0.75, 0.73, 0.68)))
		(_list.get_child(0) as Label).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for k in Items.ALL:
		if not counts.has(k):
			continue
		var it := Items.info(k)
		var on := false
		for slot in r.equip:
			on = on or r.equip[slot] == k
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.text = "%s%s%s · %s" % [it.name, " ×%d" % counts[k] if counts[k] > 1 else "", " (on)" if on else "", Items.describe(k)]
		b.add_theme_font_size_override("font_size", 12)
		b.add_theme_color_override("font_color", Items.TYPE_COLOURS.get(it.type, Color.WHITE))
		b.tooltip_text = "Click to use" if it.type != "gem" else "Sell it to Tilda at the general store"
		b.pressed.connect(func() -> void:
			var msg := r.use_item(k)
			if msg != "":
				_note.text = msg
				var p := get_tree().get_first_node_in_group("player") as PlayerController
				if p:
					p.touch())
		_list.add_child(b)
