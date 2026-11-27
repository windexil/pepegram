extends VBoxContainer
## ChronologyBoard — хронология тақтасы.
## Оқиғалар мен дереккөздерді ▲/▼ арқылы уақыт тәртібімен реттеу және
## уақыттық сәйкессіздіктерді «⚠» белгісімен көрсету.

const UI = preload("res://scripts/ui/ui_kit.gd")

signal changed

var items_by_id: Dictionary = {}
var order: Array = []            # ағымдағы ойыншы реті (id)
var correct: Array = []          # дұрыс рет (id)
var flags: Dictionary = {}       # {id: true} — «сәйкессіздік» белгісі
var locked: Dictionary = {}      # {id: true} — бекітілген (бейімделу: anchor_items)
var chrono_support: bool = false
var result: Dictionary = {}      # соңғы тексеріс нәтижесі (бояу үшін)
var _rows: VBoxContainer


func setup(items: Array, p_chrono_support: bool, anchor_items: bool) -> void:
	chrono_support = p_chrono_support
	add_theme_constant_override("separation", 8)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for it in items:
		items_by_id[str(it["id"])] = it
		correct.append(str(it["id"]))
	if anchor_items and correct.size() > 2:
		locked[correct[0]] = true
		locked[correct[correct.size() - 1]] = true
	order = _shuffled_order()
	_rows = UI.vbox(6)
	add_child(_rows)
	_render()


## Бекітілген элементтер орнында қалады, қалғаны араластырылады.
## Араластыру ешқашан дұрыс ретті бермейді.
func _shuffled_order() -> Array:
	var free_ids: Array = []
	for id in correct:
		if not locked.has(id):
			free_ids.append(id)
	var res: Array = []
	for attempt in range(20):
		free_ids.shuffle()
		res = []
		var k: int = 0
		for id in correct:
			if locked.has(id):
				res.append(id)
			else:
				res.append(free_ids[k])
				k += 1
		if res != correct:
			break
	return res


func _render() -> void:
	UI.clear(_rows)
	var misplaced: Array = result.get("misplaced", [])
	var checked: bool = not result.is_empty()
	for i in range(order.size()):
		var id: String = str(order[i])
		var it: Dictionary = items_by_id[id]
		var border: Color = UI.C_PANEL_LIGHT
		var bg: Color = UI.C_PANEL
		if checked:
			border = UI.C_RED if misplaced.has(id) else UI.C_GREEN
		if it.has("card_id"):
			bg = UI.C_PANEL.lightened(0.05)
		var row_panel := UI.panel(bg, border, 8, 6, 2 if checked else 1)
		var row := UI.hbox(10)
		row_panel.add_child(row)

		var pos := UI.label("%d." % (i + 1), 20, UI.C_ACCENT, false)
		pos.custom_minimum_size = Vector2(34, 0)
		row.add_child(pos)

		var info := UI.vbox(2)
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var top := UI.hbox(6)
		if it.has("card_id"):
			top.add_child(UI.badge("ДЕРЕККӨЗ", UI.C_PAPER_DARK, UI.C_INK, 11))
		else:
			top.add_child(UI.badge("ОҚИҒА", UI.C_MUTED, UI.C_INK, 11))
		if locked.has(id):
			top.add_child(UI.badge("БЕКІТІЛГЕН", UI.C_BLUE, Color.WHITE, 11))
		top.add_child(UI.label(_date_text(it), 14, _date_color(it)))
		info.add_child(top)
		info.add_child(UI.label(str(it["text"]), 16, UI.C_TEXT))
		if checked and misplaced.has(id):
			info.add_child(UI.label("✖ Дұрыс орны: %d. %s" % [correct.find(id) + 1, str(it.get("explain", ""))], 14, UI.C_RED.lightened(0.35)))
		var hits: Array = result.get("anomaly_hits", [])
		var missed: Array = result.get("anomaly_missed", [])
		var false_f: Array = result.get("anomaly_false", [])
		if checked and (hits.has(id) or missed.has(id)):
			var prefix: String = "✔ Сәйкессіздік дұрыс табылды: " if hits.has(id) else "⚠ Сәйкессіздік байқалмады: "
			info.add_child(UI.label(prefix + str(it.get("anomaly_note", "")), 14, UI.C_ACCENT))
		if checked and false_f.has(id):
			info.add_child(UI.label("✖ Бұл элементте уақыттық сәйкессіздік жоқ — белгі қате қойылды.", 14, UI.C_RED.lightened(0.35)))
		row.add_child(info)

		var flag := CheckBox.new()
		flag.text = "⚠ Сәйкессіздік"
		flag.tooltip_text = "Мәтіндегі уақыт пен мазмұн бір-біріне сәйкес келмесе (анахронизм) белгіле"
		flag.button_pressed = flags.has(id)
		flag.focus_mode = Control.FOCUS_NONE
		flag.toggled.connect(_on_flag.bind(id))
		row.add_child(flag)

		var arrows := UI.vbox(2)
		var up := UI.button("▲")
		up.custom_minimum_size = Vector2(38, 26)
		up.disabled = locked.has(id) or i == 0
		up.pressed.connect(_move.bind(i, -1))
		var down := UI.button("▼")
		down.custom_minimum_size = Vector2(38, 26)
		down.disabled = locked.has(id) or i == order.size() - 1
		down.pressed.connect(_move.bind(i, 1))
		arrows.add_child(up)
		arrows.add_child(down)
		row.add_child(arrows)
		_rows.add_child(row_panel)


func _date_text(it: Dictionary) -> String:
	if bool(it.get("show_date", true)):
		return "Уақыты: " + str(it["date_label"])
	if chrono_support:
		return "⏱ Бағдар: " + str(it["date_label"])
	return "Уақыты: мәтіндегі белгілерден анықта"


func _date_color(it: Dictionary) -> Color:
	if bool(it.get("show_date", true)):
		return UI.C_MUTED
	return UI.C_BLUE.lightened(0.3) if chrono_support else UI.C_MUTED.darkened(0.2)


func _move(index: int, dir: int) -> void:
	var target: int = index + dir
	if target < 0 or target >= order.size():
		return
	# Бекітілген элементтің үстінен секіру
	while target >= 0 and target < order.size() and locked.has(order[target]):
		target += dir
	if target < 0 or target >= order.size():
		return
	var tmp = order[index]
	order[index] = order[target]
	order[target] = tmp
	result = {}
	_render.call_deferred()
	changed.emit()


func _on_flag(pressed: bool, id: String) -> void:
	if pressed:
		flags[id] = true
	else:
		flags.erase(id)
	changed.emit()


func get_order() -> Array:
	return order.duplicate()


func get_flags() -> Array:
	return flags.keys()


func show_result(p_result: Dictionary) -> void:
	result = p_result
	_render()


## Тексерістен кейін дұрыс ретті көрсету (оқу мақсатында).
func reveal_correct() -> void:
	order = correct.duplicate()
	result = {"misplaced": [], "anomaly_hits": [], "anomaly_missed": [], "anomaly_false": []}
	flags = {}
	for id in correct:
		if bool(items_by_id[id].get("anomaly", false)):
			flags[id] = true
	_render()
