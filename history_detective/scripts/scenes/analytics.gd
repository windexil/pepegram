extends Control
## Analytics — оқу аналитикасы: барлық әрекеттер кестесі, екі салыстыру
## диаграммасы (A: хронология қатесі ↔ сенімділік дәлдігі; B: уақыт ↔ сапа),
## салмақталған метрикалар және бейімделу шешімінің логикалық негіздемесі.

const UI = preload("res://scripts/ui/ui_kit.gd")
const AdaptiveEngine = preload("res://scripts/core/adaptive_engine.gd")
const ScatterChart = preload("res://scripts/ui/scatter_chart.gd")

var _export_label: Label


func _ready() -> void:
	theme = UI.build_theme()
	UI.background(self)
	_build()


func _build() -> void:
	var margin := MarginContainer.new()
	UI.full_rect(margin)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	add_child(margin)
	var content := UI.vbox(14)
	margin.add_child(UI.scroll(content))

	var head := UI.hbox(10)
	head.add_child(UI.label("АНАЛИТИКА ЖӘНЕ БЕЙІМДЕЛУ", 28, UI.C_ACCENT, false))
	head.add_child(UI.spacer())
	var b_exp := UI.button("JSON есепті экспорттау")
	b_exp.pressed.connect(_export)
	head.add_child(b_exp)
	var back := UI.button("← Мәзір")
	back.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/main_menu.tscn"))
	head.add_child(back)
	content.add_child(head)
	_export_label = UI.label("", 13, UI.C_MUTED)
	content.add_child(_export_label)

	var hist: Array = GameState.history()
	if hist.is_empty():
		content.add_child(UI.label("Әзірге деректер жоқ. Кем дегенде бір істі аяқтағаннан кейін мұнда нақты сандар, екі параметрді салыстыру диаграммалары және бейімделу шешімі пайда болады.", 17, UI.C_TEXT))
		return

	content.add_child(_history_table(hist))

	# Екі салыстыру диаграммасы
	var charts := UI.hbox(16)
	var pts_a: Array = []
	var pts_b: Array = []
	for i in range(hist.size()):
		var m: Dictionary = AdaptiveEngine.metrics_of(hist[i])
		var lbl: String = "#%d %s" % [i + 1, str(hist[i]["episode_id"])]
		var cur: bool = i == hist.size() - 1
		pts_a.append({"x": m["chrono_error_rate"], "y": m["reliability_accuracy"], "label": lbl, "current": cur})
		pts_b.append({"x": minf(float(m["time_ratio"]), 2.0), "y": m["quality"], "label": lbl, "current": cur})
	var ca := ScatterChart.new()
	ca.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ca.configure({
		"title": "A. Хронология қатесі ↔ Сенімділік дәлдігі",
		"x_label": "Хронология қатесінің үлесі →",
		"y_label": "Сенімділік дәлдігі ↑",
		"x_max": 1.0, "y_max": 1.0,
		"x_threshold": AdaptiveEngine.CHRONO_ERR_HIGH,
		"y_threshold": AdaptiveEngine.REL_ACC_HIGH,
		"y_threshold2": AdaptiveEngine.REL_ACC_LOW,
		"quadrant_labels": ["Сарапшы", "Уақыт осі әлсіз", "Дереккөз талдауы әлсіз", "Екеуі де әлсіз"],
		"points": pts_a,
	})
	charts.add_child(ca)
	var cb := ScatterChart.new()
	cb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cb.configure({
		"title": "B. Эпизод уақыты ↔ Қорытынды сапасы",
		"x_label": "Уақыт / мақсатты уақыт →",
		"y_label": "Дәлелділік ↑",
		"x_max": 2.0, "y_max": 1.0,
		"x_threshold": 1.0,
		"y_threshold": AdaptiveEngine.QUALITY_HIGH,
		"y_threshold2": AdaptiveEngine.QUALITY_LOW,
		"quadrant_labels": ["Жылдам әрі сапалы", "Баяу, бірақ сапалы", "Асығыс / импульсивті", "Қиналып жүр"],
		"points": pts_b,
	})
	charts.add_child(cb)
	content.add_child(charts)

	# Салмақталған метрикалар және шешім
	var wm: Dictionary = AdaptiveEngine.weighted_metrics(hist)
	var prof: Dictionary = GameState.get_profile()
	var p := UI.panel(UI.C_DESK, UI.C_BLUE, 14, 6, 2)
	var v := UI.vbox(6)
	p.add_child(v)
	v.add_child(UI.label("Бейімделу шешімінің негіздемесі", 18, UI.C_BLUE.lightened(0.35)))
	v.add_child(UI.label("Салмақталған метрикалар (соңғы іс ×0.6 + алдыңғылардың орташасы ×0.4; барлығы %d әрекет):" % hist.size(), 14, UI.C_MUTED))
	v.add_child(UI.label("Хронология қатесі: %s · Сенімділік дәлдігі: %s · Уақыт қатынасы: %.2f · Қорытынды сапасы: %s" % [
		UI.pct(float(wm["chrono_error_rate"])), UI.pct(float(wm["reliability_accuracy"])), float(wm["time_ratio"]), UI.pct(float(wm["quality"]))], 15, UI.C_TEXT))
	for line in prof.get("rationale", []):
		v.add_child(UI.label(str(line), 14, UI.C_TEXT))
	v.add_child(UI.label("Белсенді баптаулар: " + " · ".join(PackedStringArray(AdaptiveEngine.describe(prof))), 14, UI.C_ACCENT))
	content.add_child(p)

	# Трендтер (бірінші ↔ соңғы әрекет)
	if hist.size() >= 2:
		var first: Dictionary = AdaptiveEngine.metrics_of(hist[0])
		var last: Dictionary = AdaptiveEngine.metrics_of(hist[hist.size() - 1])
		var tr: String = "Динамика (1-әрекет → соңғы): хронология қатесі %s → %s; сенімділік дәлдігі %s → %s; сапа %s → %s." % [
			UI.pct(float(first["chrono_error_rate"])), UI.pct(float(last["chrono_error_rate"])),
			UI.pct(float(first["reliability_accuracy"])), UI.pct(float(last["reliability_accuracy"])),
			UI.pct(float(first["quality"])), UI.pct(float(last["quality"]))]
		content.add_child(UI.label(tr, 15, UI.C_TEXT))


func _history_table(hist: Array) -> Control:
	var p := UI.panel(UI.C_PANEL, UI.C_PANEL_LIGHT, 12, 6, 1)
	var v := UI.vbox(6)
	p.add_child(v)
	v.add_child(UI.label("Әрекеттер журналы (user://history_detective_save.json)", 16, UI.C_ACCENT))
	var g := GridContainer.new()
	g.columns = 10
	g.add_theme_constant_override("h_separation", 14)
	g.add_theme_constant_override("v_separation", 4)
	for h in ["#", "Іс", "Уақыт", "Хрон. қате", "Ауытқу", "Сенім. дәлдігі", "Дәлелділік", "Қателер", "Кеңес", "Ұпай"]:
		g.add_child(UI.label(h, 13, UI.C_ACCENT, false))
	var start: int = maxi(0, hist.size() - 12)
	for i in range(start, hist.size()):
		var r: Dictionary = hist[i]
		var cells: Array = [
			str(i + 1),
			str(r["episode_id"]) + ("" if bool(r.get("passed", false)) else " ✖"),
			UI.format_time(float(r["time_sec"])),
			"%d/%d" % [int(r["chrono_errors"]), int(r["chrono_items"])],
			str(int(r["chrono_deviation"])),
			UI.pct(float(r["reliability_accuracy"])),
			"%d/100" % int(r["evidence_score"]),
			str(int(r["total_errors"])),
			str(int(r["hints_used"])),
			"%d/%d %s" % [int(r["score"]), int(r["max_score"]), UI.stars_text(int(r["stars"]))],
		]
		for c in cells:
			g.add_child(UI.label(str(c), 13, UI.C_TEXT, false))
	v.add_child(g)
	if hist.size() > 12:
		v.add_child(UI.label("Соңғы 12 әрекет көрсетілген. Толық журнал JSON экспортында.", 12, UI.C_MUTED))
	return p


func _export() -> void:
	var path: String = GameState.export_report()
	_export_label.text = ("Есеп сақталды: " + path) if path != "" else "Экспорт сәтсіз аяқталды."
