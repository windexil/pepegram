extends Control
## Results — эпизод нәтижесі: ұпай құрылымы, жұлдыздар, өту/өтпеу, қателер,
## уақыт, келесі іске арналған бейімделу шешімі және оның негіздемесі.

const UI = preload("res://scripts/ui/ui_kit.gd")
const AdaptiveEngine = preload("res://scripts/core/adaptive_engine.gd")


func _ready() -> void:
	theme = UI.build_theme()
	UI.background(self)
	var rec: Dictionary = GameState.last_record
	if rec.is_empty():
		get_tree().change_scene_to_file.call_deferred("res://scenes/episode_select.tscn")
		return
	_build(rec)


func _build(rec: Dictionary) -> void:
	var margin := MarginContainer.new()
	UI.full_rect(margin)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	add_child(margin)
	var content := UI.vbox(14)
	margin.add_child(UI.scroll(content))

	var passed: bool = bool(rec["passed"])
	var head := UI.hbox(16)
	var t := UI.vbox(2)
	t.add_child(UI.label("ІС ҚОРЫТЫНДЫСЫ", 14, UI.C_MUTED))
	t.add_child(UI.label(str(rec["episode_title"]), 28, UI.C_ACCENT))
	head.add_child(t)
	head.add_child(UI.spacer())
	head.add_child(UI.badge("ІС ШЕШІЛДІ" if passed else "ІС ШЕШІЛМЕДІ", UI.C_GREEN if passed else UI.C_RED, Color.WHITE, 22))
	content.add_child(head)

	var score_row := UI.hbox(24)
	score_row.add_child(UI.label("%d / %d" % [int(rec["score"]), int(rec["max_score"])], 40, UI.C_TEXT, false))
	score_row.add_child(UI.label(UI.stars_text(int(rec["stars"])), 40, UI.C_ACCENT, false))
	score_row.add_child(UI.label("%s · уақыт %s (мақсат %s)" % [UI.pct(float(rec["percent"])), UI.format_time(float(rec["time_sec"])), UI.format_time(float(rec["target_time_sec"]))], 18, UI.C_MUTED, false))
	content.add_child(score_row)
	if not passed:
		var why: String = "Өту шарты: қорытынды дұрыс болуы және нәтиже кемінде 45 % болуы керек. "
		why += "Қорытынды дұрыс емес." if not bool(rec["conclusion_correct"]) else "Нәтиже 45 %-дан төмен."
		content.add_child(UI.label(why + " Істі қайта ойнап көр — кеңестер мен бейімделу көмектеседі.", 15, UI.C_RED.lightened(0.35)))

	var cols := UI.hbox(16)
	content.add_child(cols)
	cols.add_child(_breakdown(rec))
	cols.add_child(_stats(rec))

	# Бейімделу шешімі
	var prof: Dictionary = GameState.get_profile()
	var ap := UI.panel(UI.C_DESK, UI.C_BLUE, 14, 6, 2)
	var av := UI.vbox(6)
	ap.add_child(av)
	av.add_child(UI.label("Келесі іске бейімделу шешімі (екі параметрді салыстыру негізінде)", 17, UI.C_BLUE.lightened(0.35)))
	for line in prof.get("rationale", []):
		av.add_child(UI.label(str(line), 14, UI.C_TEXT))
	av.add_child(UI.label("Қолданылатын баптаулар: " + " · ".join(PackedStringArray(AdaptiveEngine.describe(prof))), 14, UI.C_ACCENT))
	content.add_child(ap)

	if GameState.all_passed():
		var win := UI.panel(UI.C_ACCENT.darkened(0.5), UI.C_ACCENT, 16, 6, 2)
		win.add_child(UI.label("★ БАС ДЕТЕКТИВ ★  Үш тарихи іс те шешілді! Сен дереккөзді сыни бағалап, дәлелге сүйеніп қорытынды жасай алатыныңды көрсеттің.", 18, UI.C_TEXT))
		content.add_child(win)

	var btns := UI.hbox(10)
	var next_ep: Dictionary = DataRepo.get_episode_by_index(int(rec["episode_index"]) + 1)
	if passed and not next_ep.is_empty():
		var b_next := UI.button("Келесі іс →", true)
		b_next.pressed.connect(_play.bind(str(next_ep["id"])))
		btns.add_child(b_next)
	var b_retry := UI.button("Қайта ойнау", not passed)
	b_retry.pressed.connect(_play.bind(str(rec["episode_id"])))
	btns.add_child(b_retry)
	var b_an := UI.button("Аналитика")
	b_an.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/analytics.tscn"))
	btns.add_child(b_an)
	var b_sel := UI.button("Іс папкалары")
	b_sel.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/episode_select.tscn"))
	btns.add_child(b_sel)
	content.add_child(btns)


func _breakdown(rec: Dictionary) -> Control:
	var parts: Dictionary = rec["parts"]
	var p := UI.panel(UI.C_PANEL, UI.C_PANEL_LIGHT, 14, 6, 1)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := UI.vbox(6)
	p.add_child(v)
	v.add_child(UI.label("Ұпай құрылымы", 17, UI.C_ACCENT))
	var g := GridContainer.new()
	g.columns = 3
	g.add_theme_constant_override("h_separation", 18)
	var rows: Array = [
		["Зерттеу: табылған белгілер", parts["clue"], 100],
		["Хронология", parts["chrono"], 300],
		["Сенімділік бағасы", parts["rel"], 300],
		["Қорытындының дәлелділігі", parts["concl"], 300],
		["Уақыт бонусы", parts["time_bonus"], 100],
		["Кеңес айыппұлы", -int(parts["hint_penalty"]), 0],
	]
	for r in rows:
		g.add_child(UI.label(str(r[0]), 15, UI.C_TEXT, false))
		g.add_child(UI.label(str(int(r[1])), 15, UI.C_ACCENT, false))
		g.add_child(UI.label("/ %d" % int(r[2]) if int(r[2]) > 0 else "", 15, UI.C_MUTED, false))
	v.add_child(g)
	v.add_child(UI.label("Жиынтық × қиындық коэффициенті ×%.2f (+ бейімделу бонусы) = %d" % [
		float(DataRepo.get_episode(str(rec["episode_id"])).get("multiplier", 1.0)), int(rec["score"])], 14, UI.C_MUTED))
	return p


func _stats(rec: Dictionary) -> Control:
	var p := UI.panel(UI.C_PANEL, UI.C_PANEL_LIGHT, 14, 6, 1)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := UI.vbox(6)
	p.add_child(v)
	v.add_child(UI.label("Әрекеттер статистикасы", 17, UI.C_ACCENT))
	var lines: Array = [
		"Қателердің жалпы саны: %d" % int(rec["total_errors"]),
		"Белгілер: %d/%d табылды, %d артық" % [int(rec["clue_found"]), int(rec["clue_total"]), int(rec["clue_false"])],
		"Хронология: %d/%d элемент орнында емес, ауытқу %d, тексеріс %d рет" % [int(rec["chrono_errors"]), int(rec["chrono_items"]), int(rec["chrono_deviation"]), int(rec["chrono_attempts"])],
		"Сәйкессіздіктер: %d табылды, %d байқалмады, %d қате белгі" % [int(rec["anomaly_hits"]), int(rec["anomaly_missed"]), int(rec["anomaly_false"])],
		"Сенімділік дәлдігі: %s (шкала %s, белгі %s)" % [UI.pct(float(rec["reliability_accuracy"])), UI.pct(float(rec["reliability_scale_accuracy"])), UI.pct(float(rec["reliability_tag_accuracy"]))],
		"Дәлелділік баллы: %d/100 · қорытынды %s" % [int(rec["evidence_score"]), "дұрыс" if bool(rec["conclusion_correct"]) else "қате"],
		"Кеңестер: %d · салыстыру режимі: %d рет" % [int(rec["hints_used"]), int(rec["compare_used"])],
	]
	for l in lines:
		v.add_child(UI.label("• " + str(l), 14, UI.C_TEXT))
	var st: Dictionary = rec.get("stage_times", {})
	if not st.is_empty():
		var s: String = "Кезеңдер уақыты: "
		var names: Dictionary = {"investigate": "зерттеу", "chronology": "хронология", "reliability": "сенімділік", "conclusion": "қорытынды"}
		var parts_txt: Array = []
		for k in ["investigate", "chronology", "reliability", "conclusion"]:
			if st.has(k):
				parts_txt.append("%s %s" % [names[k], UI.format_time(float(st[k]))])
		v.add_child(UI.label(s + ", ".join(PackedStringArray(parts_txt)), 13, UI.C_MUTED))
	return p


func _play(episode_id: String) -> void:
	GameState.current_episode_id = episode_id
	get_tree().change_scene_to_file("res://scenes/investigation.tscn")
