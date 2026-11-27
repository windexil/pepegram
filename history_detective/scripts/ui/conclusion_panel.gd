extends VBoxContainer
## ConclusionPanel — зерттеу сұрағына дәлелді қорытынды: бір нұсқаны таңдау
## және оны қолдайтын дәлелдерді (дереккөздер + хронология оқиғалары) белгілеу.

const UI = preload("res://scripts/ui/ui_kit.gd")

signal changed

var episode: Dictionary = {}
var ratings: Dictionary = {}
var selected_option: String = ""
var evidence: Dictionary = {}     # {id: true}
var _option_order: Array = []


func setup(ep: Dictionary, player_ratings: Dictionary) -> void:
	episode = ep
	ratings = player_ratings
	add_theme_constant_override("separation", 12)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_option_order = (ep["conclusion"]["options"] as Array).duplicate()
	_option_order.shuffle()
	_build()


func _build() -> void:
	UI.clear(self)
	var q := UI.panel(UI.C_DESK, UI.C_ACCENT, 14, 6, 2)
	var qv := UI.vbox(4)
	q.add_child(qv)
	qv.add_child(UI.label("ЗЕРТТЕУ СҰРАҒЫ", 13, UI.C_ACCENT))
	qv.add_child(UI.label(str(episode["research_question"]), 19, UI.C_TEXT))
	add_child(q)

	add_child(UI.label("1. Қорытындыны таңда:", 17, UI.C_ACCENT))
	var group := ButtonGroup.new()
	for opt in _option_order:
		var p := UI.panel(UI.C_PANEL, UI.C_PANEL_LIGHT, 10, 6, 1)
		var cb := CheckBox.new()
		cb.button_group = group
		cb.focus_mode = Control.FOCUS_NONE
		cb.text = str(opt["text"])
		cb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		cb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cb.custom_minimum_size = Vector2(600, 0)
		cb.button_pressed = (selected_option == str(opt["id"]))
		cb.toggled.connect(_on_option.bind(str(opt["id"])))
		p.add_child(cb)
		add_child(p)

	add_child(UI.label("2. Қорытындыны қолдайтын дәлелдерді белгіле (тек сенімді деп санағандарыңды):", 17, UI.C_ACCENT))
	var ev_box := UI.panel(UI.C_PANEL, UI.C_PANEL_LIGHT, 12, 6, 1)
	var ev := UI.vbox(4)
	ev_box.add_child(ev)
	ev.add_child(UI.label("Дереккөздер (жақшада — сенің сенімділік бағаң):", 14, UI.C_MUTED))
	for card in episode["cards"]:
		var cid: String = str(card["id"])
		var r: int = int(ratings.get(cid, 0))
		var cb := CheckBox.new()
		cb.focus_mode = Control.FOCUS_NONE
		cb.text = "%s  (%d/5 — %s)" % [str(card["title"]), r, DataRepo.scale_name(r)]
		cb.button_pressed = evidence.has(cid)
		cb.toggled.connect(_on_evidence.bind(cid))
		if r > 0 and r <= 2:
			cb.add_theme_color_override("font_color", UI.C_RED.lightened(0.35))
		ev.add_child(cb)
	ev.add_child(UI.label("Хронологиядағы расталған оқиғалар:", 14, UI.C_MUTED))
	for it in episode["chronology"]:
		if not bool(it.get("evidence", false)):
			continue
		var iid: String = str(it["id"])
		var cb2 := CheckBox.new()
		cb2.focus_mode = Control.FOCUS_NONE
		cb2.text = str(it.get("evidence_label", it["text"]))
		cb2.button_pressed = evidence.has(iid)
		cb2.toggled.connect(_on_evidence.bind(iid))
		ev.add_child(cb2)
	add_child(ev_box)
	add_child(UI.label("Ескерту: өзің 1–2 деп бағалаған дереккөзге сүйену «өзіндік қайшылық» ретінде есептеледі.", 13, UI.C_MUTED))


func _on_option(pressed: bool, option_id: String) -> void:
	if pressed:
		selected_option = option_id
		changed.emit()


func _on_evidence(pressed: bool, id: String) -> void:
	if pressed:
		evidence[id] = true
	else:
		evidence.erase(id)
	changed.emit()


func is_ready() -> bool:
	return selected_option != "" and not evidence.is_empty()


func get_selected() -> Dictionary:
	for opt in episode["conclusion"]["options"]:
		if str(opt["id"]) == selected_option:
			return opt
	return {}


func get_evidence() -> Array:
	return evidence.keys()
