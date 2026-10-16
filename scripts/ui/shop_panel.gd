class_name ShopPanel
extends PanelContainer
## Trading with Tilda at the general store's counter (F there while she's at the till): what she
## has on her shelves, at its value, and what she'll give for the things you carry, at half. It
## closes when you walk away from the counter or she leaves the till.

var resident: Resident = null

var _head: VBoxContainer
var _buy: VBoxContainer
var _sell: VBoxContainer
var _note: Label
var _shown := ""
var _tick := 0.0


func _ready() -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.09, 0.08, 0.07, 0.9)
	sb.border_color = Color(1.0, 0.85, 0.55, 0.3)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(14)
	add_theme_stylebox_override("panel", sb)
	anchor_left = 0.5
	anchor_right = 0.5
	anchor_top = 0.5
	anchor_bottom = 0.5
	offset_left = -320.0
	offset_right = 320.0
	offset_top = -230.0
	offset_bottom = 190.0
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	add_child(v)
	_head = VBoxContainer.new()
	v.add_child(_head)
	var cols := HBoxContainer.new()
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cols.add_theme_constant_override("separation", 14)
	v.add_child(cols)
	_buy = _column(cols, "BUY")
	_sell = _column(cols, "SELL")
	_note = InventoryPanel._label("", 12, Color(1, 0.87, 0.6))
	v.add_child(_note)
	visible = false


func _column(parent: Control, title: String) -> VBoxContainer:
	var c := VBoxContainer.new()
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(c)
	c.add_child(InventoryPanel._label(title, 11, Color(0.75, 0.73, 0.68)))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	c.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 2)
	scroll.add_child(list)
	return list


func open(r: Resident) -> void:
	resident = r
	_note.text = "\"%s\"" % Conversations.fill("Welcome in, {n}! What can I get you?", r)
	_shown = ""
	visible = true
	_rebuild()


func close() -> void:
	resident = null
	visible = false


func _process(delta: float) -> void:
	if not visible:
		return
	var r := resident
	if r == null or not is_instance_valid(r) or not r.controlled or r.dead or not ShopJob.trading() or not ShopJob.at_counter(r):
		close()
		return
	_tick -= delta
	if _tick <= 0.0:
		_tick = 0.3
		_rebuild()


func _rebuild() -> void:
	var r := resident
	var key := "%s|%d|%s|%d|%s" % [r.bag.items, r.purse(), Items.stock(), Items.till(), r.equip]
	if key == _shown:
		return
	_shown = key
	for c in _head.get_children():
		c.queue_free()
	for list in [_buy, _sell]:
		for c in (list as Node).get_children():
			c.queue_free()
	var top := HBoxContainer.new()
	_head.add_child(top)
	var t := InventoryPanel._label("Tilda's general store", 17, Color(0.95, 0.93, 0.86))
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(t)
	top.add_child(InventoryPanel._label("Esc to close", 11, Color(0.75, 0.73, 0.68)))
	_head.add_child(InventoryPanel._label("%s has %s · Tilda's till: %s" % [r.def.display_name, Items.money(r.purse()), Items.money(Items.till())],
		13, Color(1.0, 0.85, 0.45)))
	var stock := Items.stock()
	for k in Items.ALL:
		if stock.get(k, 0) <= 0:
			continue
		var p := Items.buy_price(k)
		var b := _row("%s ×%d · %s" % [Items.title(k), stock[k], Items.money(p)], k, Items.describe(k), r.purse() >= p)
		b.pressed.connect(func() -> void:
			if Items.buy(r, k):
				_note.text = "%s bought the %s for %s." % [r.def.display_name, Items.title(k).to_lower(), Items.money(p)]
			else:
				_note.text = "%s can't afford that." % r.def.display_name)
		_buy.add_child(b)
	var any := false
	for k in Items.ALL:
		if r.spare(k) <= 0:
			continue
		any = true
		var p := Items.sell_price(k)
		var b := _row("%s%s · %s" % [Items.title(k), " ×%d" % r.spare(k) if r.spare(k) > 1 else "", Items.money(p)], k,
			Items.describe(k), Items.till() >= p)
		b.pressed.connect(func() -> void:
			if Items.sell(r, k):
				_note.text = "%s sold the %s for %s." % [r.def.display_name, Items.title(k).to_lower(), Items.money(p)]
			else:
				_note.text = "Tilda hasn't the coin for that.")
		_sell.add_child(b)
	if not any:
		var l := InventoryPanel._label("Nothing to sell (what you wear or wield stays on).", 12, Color(0.75, 0.73, 0.68))
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_sell.add_child(l)


func _row(text: String, k: String, tip: String, can: bool) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.text = text
	b.tooltip_text = tip
	b.disabled = not can
	b.add_theme_font_size_override("font_size", 12)
	b.add_theme_color_override("font_color", Items.TYPE_COLOURS.get(Items.info(k).type, Color.WHITE))
	return b
