extends VBoxContainer
## ReliabilityPanel — әр дереккөзге сенімділік шкаласы (1–5) және
## негізгі ерекшелік / бұрмалану түрін таңдау.

const UI = preload("res://scripts/ui/ui_kit.gd")

signal changed

var cards: Array = []
var ratings: Dictionary = {}     # {card_id: 1..5}
var tags: Dictionary = {}        # {card_id: tag_id}
var source_support: bool = false
var result: Dictionary = {}
var _tag_ids: Array = []


func setup(p_cards: Array, p_source_support: bool) -> void:
	cards = p_cards
	source_support = p_source_support
	add_theme_constant_override("separation", 12)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tag_ids = []
	for t in DataRepo.tags:
		_tag_ids.append(str(t["id"]))
	_render()


func _render() -> void:
	UI.clear(self)
	if source_support:
		add_child(_comparison_table())
	for card in cards:
		add_child(_card_block(card))


## Бейімделу көмекшісі: дереккөздерді автор мүддесі, жанр және уақыт арақашықтығы бойынша қатар салыстыру.
func _comparison_table() -> Control:
	var p := UI.panel(UI.C_DESK, UI.C_BLUE, 12, 6, 2)
	var v := UI.vbox(6)
	p.add_child(v)
	v.add_child(UI.label("Салыстыру көмекшісі (бейімделу): автор мүддесі мен жанрды қатар қара", 16, UI.C_BLUE.lightened(0.35)))
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 6)
	for h in ["Дереккөз", "Жанры", "Автор мүддесі", "Уақыт арақашықтығы"]:
		grid.add_child(UI.label(h, 14, UI.C_ACCENT))
	for c in cards:
		grid.add_child(UI.label(str(c["format"]), 13, UI.C_TEXT))
		grid.add_child(UI.label(str(c["genre"]), 13, UI.C_MUTED))
		grid.add_child(UI.label(str(c.get("author_interest", "—")), 13, UI.C_MUTED))
		grid.add_child(UI.label(str(c.get("time_distance", "—")), 13, UI.C_MUTED))
	v.add_child(grid)
	v.add_child(UI.label("Сұрақтар: Автор нені дәлелдеуге мүдделі? Ол куәгер ме? Оқиғадан қанша уақыт өткен соң жазды? Мәтінді басқа дереккөз растай ма?", 13, UI.C_TEXT))
	return p


func _card_block(card: Dictionary) -> Control:
	var cid: String = str(card["id"])
	var per: Dictionary = (result.get("per_card", {}) as Dictionary).get(cid, {})
	var border: Color = UI.C_PANEL_LIGHT
	if not per.is_empty():
		border = UI.C_GREEN if (int(per["diff"]) <= 1 and bool(per["tag_ok"])) else UI.C_RED
	var p := UI.panel(UI.C_PANEL, border, 14, 8, 2)
	var v := UI.vbox(8)
	p.add_child(v)

	var head := UI.hbox(8)
	head.add_child(UI.badge(str(card["format"]), UI.C_PAPER_DARK, UI.C_INK, 12))
	head.add_child(UI.label(str(card["title"]), 17, UI.C_TEXT))
	v.add_child(head)
	v.add_child(UI.label("%s · %s" % [str(card["date_label"]), str(card["author"])], 13, UI.C_MUTED))

	# Сенімділік шкаласы 1..5
	var scale_row := UI.hbox(6)
	scale_row.add_child(UI.label("Сенімділік:", 15, UI.C_TEXT, false))
	var group := ButtonGroup.new()
	var current: int = int(ratings.get(cid, 0))
	for val in range(1, 6):
		var b := Button.new()
		b.text = str(val)
		b.toggle_mode = true
		b.button_group = group
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(46, 34)
		var col: Color = UI.SCALE_COLORS[val - 1]
		b.add_theme_stylebox_override("normal", UI.style(col.darkened(0.55), 6, col, 1, 6))
		b.add_theme_stylebox_override("hover", UI.style(col.darkened(0.3), 6, col, 1, 6))
		b.add_theme_stylebox_override("pressed", UI.style(col, 6, Color.WHITE, 2, 6))
		b.add_theme_color_override("font_pressed_color", UI.C_INK)
		b.button_pressed = (val == current)
		b.pressed.connect(_on_rate.bind(cid, val))
		scale_row.add_child(b)
	var meaning: String = DataRepo.scale_name(current) if current > 0 else "таңдалмады"
	scale_row.add_child(UI.label("  → " + meaning, 14, UI.C_ACCENT, false))
	v.add_child(scale_row)

	# Ерекшелік / бұрмалану түрі
	var tag_row := UI.hbox(8)
	tag_row.add_child(UI.label("Негізгі ерекшелігі:", 15, UI.C_TEXT, false))
	var opt := OptionButton.new()
	opt.focus_mode = Control.FOCUS_NONE
	opt.add_item("— белгіні таңда —", 0)
	for i in range(DataRepo.tags.size()):
		opt.add_item(str(DataRepo.tags[i]["name"]), i + 1)
	var sel_tag: String = str(tags.get(cid, ""))
	opt.selected = _tag_ids.find(sel_tag) + 1 if sel_tag != "" else 0
	opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	opt.item_selected.connect(_on_tag.bind(cid))
	tag_row.add_child(opt)
	v.add_child(tag_row)
	if sel_tag != "":
		for t in DataRepo.tags:
			if str(t["id"]) == sel_tag:
				v.add_child(UI.label(str(t["desc"]), 13, UI.C_MUTED))

	# Тексерістен кейінгі педагогикалық кері байланыс
	if not per.is_empty():
		var fb: String = ""
		if int(per["diff"]) == 0:
			fb += "[color=%s]✔ Шкала дәл: %d/5.[/color] " % [UI.hex(UI.C_GREEN.lightened(0.3)), int(per["correct"])]
		elif int(per["diff"]) == 1:
			fb += "[color=%s]≈ Шкала жақын: сенің бағаң %d, сарапшы бағасы %d.[/color] " % [UI.hex(UI.C_ACCENT), int(per["given"]), int(per["correct"])]
		else:
			fb += "[color=%s]✖ Шкала алыс: сенің бағаң %d, сарапшы бағасы %d.[/color] " % [UI.hex(UI.C_RED.lightened(0.3)), int(per["given"]), int(per["correct"])]
		if bool(per["tag_ok"]):
			fb += "[color=%s]✔ Белгі дұрыс.[/color]" % UI.hex(UI.C_GREEN.lightened(0.3))
		else:
			var ok_names: Array = []
			for t_id in card["tags_ok"]:
				ok_names.append(DataRepo.tag_name(str(t_id)))
			fb += "[color=%s]✖ Белгі қате. Дұрысы: %s.[/color]" % [UI.hex(UI.C_RED.lightened(0.3)), " / ".join(PackedStringArray(ok_names))]
		fb += "\n[i]%s[/i]" % str(card["reliability_explain"])
		v.add_child(UI.rich(fb, 14))
	return p


func _on_rate(cid: String, val: int) -> void:
	ratings[cid] = val
	result = {}
	_render.call_deferred()
	changed.emit()


func _on_tag(index: int, cid: String) -> void:
	if index <= 0:
		tags.erase(cid)
	else:
		tags[cid] = _tag_ids[index - 1]
	result = {}
	_render.call_deferred()
	changed.emit()


func is_complete() -> bool:
	for c in cards:
		var cid: String = str(c["id"])
		if not ratings.has(cid) or not tags.has(cid):
			return false
	return true


func show_result(p_result: Dictionary) -> void:
	result = p_result
	_render()
