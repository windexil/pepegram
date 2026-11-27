extends Control
## Investigation — эпизод контроллері (негізгі ойын циклі).
## Кезеңдер: 1) Зерттеу және салыстыру → 2) Хронология → 3) Сенімділік →
## 4) Дәлелді қорытынды → тексеру → нәтиже экраны.

const UI = preload("res://scripts/ui/ui_kit.gd")
const Score = preload("res://scripts/core/score_calculator.gd")
const AdaptiveEngine = preload("res://scripts/core/adaptive_engine.gd")
const SourceCardView = preload("res://scripts/ui/source_card_view.gd")
const ChronologyBoard = preload("res://scripts/ui/chronology_board.gd")
const ReliabilityPanel = preload("res://scripts/ui/reliability_panel.gd")
const ConclusionPanel = preload("res://scripts/ui/conclusion_panel.gd")

enum Stage { INVESTIGATE, CHRONOLOGY, RELIABILITY, CONCLUSION }

const STAGE_KEYS := ["investigate", "chronology", "reliability", "conclusion"]
const STAGE_NAMES := ["1. Зерттеу", "2. Хронология", "3. Сенімділік", "4. Қорытынды"]
const STAGE_TASKS := [
	"Үш карточканы аш. Деректемелерін оқы, маңызды не күдікті сөйлемдерді басып белгіле. Карточкаларды «Салыстыру» режимінде қатар қара.",
	"Оқиғалар мен дереккөздерді ▲/▼ арқылы ертеден кейінге қарай ретте. Мазмұны өз уақытына сәйкес келмейтін элементті «⚠ Сәйкессіздік» деп белгіле.",
	"Әр дереккөзге сенімділік деңгейін (1–5) қой және оның негізгі ерекшелігін / бұрмалану түрін таңда.",
	"Зерттеу сұрағына қорытынды таңда және оны тек сенімді дәлелдермен негізде.",
]
## Кеңес деңгейі ≥ 2 болғанда автоматты көрсетілетін әдістемелік бағдар.
const STAGE_GUIDE := [
	"Бағдар: «5 сұрақ» әдісі — Кім жазды? Қашан? Қайда сақталды? Не үшін жазды? Басқа дерек растай ма? Атаулар мен даталарды дәуірмен салыстыр.",
	"Бағдар: алдымен нақты даталары бар «анкер» оқиғаларды қой, қалғанын «бұрын/кейін», «кеше», «келесі жылы» деген сөздер бойынша орналастыр.",
	"Бағдар: біржақты дерек ≠ жалған дерек. Автор мүддесі, куәгер болғаны, уақыт арақашықтығы және анахронизм бар-жоғын бөлек бағала.",
	"Бағдар: қорытынды кем дегенде екі тәуелсіз сенімді дерекке сүйенуі керек. 1–2 деп бағалаған дереккөзді дәлел етпе.",
]

var ep: Dictionary = {}
var profile: Dictionary = {}
var stage: int = Stage.INVESTIGATE
var hint_level: int = 1

# Зерттеу кезеңінің күйі
var marks: Dictionary = {}          # {card_id: {fragment_index: true}}
var visited: Dictionary = {}
var current_card: String = ""
var compare_mode: bool = false
var compare_left: int = 0
var compare_right: int = 1
var compare_noted: bool = false
var clues_done: bool = false

# Кейінгі кезеңдер
var chrono_board: ChronologyBoard
var chrono_checks: int = 0
var rel_panel: ReliabilityPanel
var rel_checked: bool = false
var concl_panel: ConclusionPanel
var hint_index: Dictionary = {}
var revealed_hints: Array = []
var finished: bool = false

# UI сілтемелері
var _stage_labels: Array = []
var _timer_label: Label
var _score_label: Label
var _stage_title: Label
var _stage_task: Label
var _content: VBoxContainer
var _actions: HBoxContainer
var _status: Label
var _notebook: RichTextLabel
var _hint_btn: Button
var _hint_text: RichTextLabel
var _guide_label: Label
var _progress: ProgressBar
var _last_sec: int = -1


func _ready() -> void:
	theme = UI.build_theme()
	UI.background(self)
	ep = DataRepo.get_episode(GameState.current_episode_id)
	if ep.is_empty():
		get_tree().change_scene_to_file.call_deferred("res://scenes/episode_select.tscn")
		return
	profile = GameState.get_profile()
	hint_level = int(profile.get("hint_level", 1))
	for c in ep["cards"]:
		marks[str(c["id"])] = {}
	current_card = str(ep["cards"][0]["id"])
	Stats.begin_episode(ep, profile)
	Stats.points_changed.connect(_on_points_changed)
	_build_layout()
	_enter_stage(Stage.INVESTIGATE)
	_show_briefing()


func _process(_delta: float) -> void:
	if finished or _timer_label == null:
		return
	var sec: int = int(Stats.elapsed_sec())
	if sec == _last_sec:
		return
	_last_sec = sec
	var target: float = float(Stats.record.get("target_time_sec", ep["target_time_sec"]))
	_timer_label.text = "⏱ %s / %s" % [UI.format_time(sec), UI.format_time(target)]
	_timer_label.add_theme_color_override("font_color", UI.C_RED.lightened(0.2) if sec > target else UI.C_TEXT)


# =====================================================================
# Макет
# =====================================================================

func _build_layout() -> void:
	var margin := MarginContainer.new()
	UI.full_rect(margin)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	add_child(margin)
	var root := UI.vbox(10)
	margin.add_child(root)

	# --- Жоғарғы панель ---
	var top := UI.panel(UI.C_DESK, UI.C_PANEL_LIGHT, 10, 6, 1)
	var tb := UI.hbox(14)
	top.add_child(tb)
	var title_box := UI.vbox(0)
	title_box.add_child(UI.label(str(ep["title"]), 19, UI.C_ACCENT, false))
	title_box.add_child(UI.label("%s · деңгей %d · ×%.2f" % [str(ep["period"]), int(ep["difficulty"]), float(ep["multiplier"])], 13, UI.C_MUTED, false))
	tb.add_child(title_box)
	tb.add_child(UI.spacer())
	for i in range(4):
		var l := UI.label(STAGE_NAMES[i], 15, UI.C_MUTED, false)
		_stage_labels.append(l)
		tb.add_child(l)
		if i < 3:
			tb.add_child(UI.label("›", 15, UI.C_MUTED, false))
	tb.add_child(UI.spacer())
	_timer_label = UI.label("⏱ 00:00", 16, UI.C_TEXT, false)
	tb.add_child(_timer_label)
	_score_label = UI.label("Ұпай: 0", 16, UI.C_ACCENT, false)
	tb.add_child(_score_label)
	var menu := UI.button("Мәзір")
	menu.pressed.connect(_confirm_exit)
	tb.add_child(menu)
	root.add_child(top)

	# --- Негізгі бөлік ---
	var body := UI.hbox(12)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(body)

	var main := UI.vbox(8)
	main.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(main)
	_stage_title = UI.label("", 22, UI.C_ACCENT)
	main.add_child(_stage_title)
	_stage_task = UI.label("", 15, UI.C_MUTED)
	main.add_child(_stage_task)
	_content = UI.vbox(8)
	_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main.add_child(_content)
	var bottom := UI.panel(UI.C_DESK, UI.C_PANEL_LIGHT, 8, 6, 1)
	var bb := UI.hbox(10)
	bottom.add_child(bb)
	_status = UI.label("", 14, UI.C_MUTED)
	bb.add_child(_status)
	_actions = UI.hbox(8)
	bb.add_child(_actions)
	main.add_child(bottom)

	# --- Бүйір панель: детектив дәптері, кеңес, бейімделу ---
	var side_panel := UI.panel(UI.C_DESK, UI.C_PANEL_LIGHT, 12, 6, 1)
	side_panel.custom_minimum_size = Vector2(300, 0)
	var sv := UI.vbox(8)
	side_panel.add_child(sv)
	sv.add_child(UI.label("ДЕТЕКТИВ ДӘПТЕРІ", 15, UI.C_ACCENT))
	_notebook = UI.rich("", 13)
	var nb_scroll := UI.scroll(_notebook)
	nb_scroll.custom_minimum_size = Vector2(0, 150)
	sv.add_child(nb_scroll)
	sv.add_child(HSeparator.new())
	sv.add_child(UI.label("Бейімделу профилі:", 13, UI.C_BLUE.lightened(0.35)))
	sv.add_child(UI.label("• " + "\n• ".join(PackedStringArray(AdaptiveEngine.describe(profile))), 12, UI.C_TEXT))
	sv.add_child(HSeparator.new())
	_guide_label = UI.label("", 13, UI.C_BLUE.lightened(0.4))
	sv.add_child(_guide_label)
	_hint_btn = UI.button("Кеңес алу (−%d)" % Score.hint_penalty(hint_level))
	_hint_btn.pressed.connect(_on_hint)
	sv.add_child(_hint_btn)
	_hint_text = UI.rich("", 13)
	var hint_scroll := UI.scroll(_hint_text)
	sv.add_child(hint_scroll)
	sv.add_child(UI.label("Іс барысы:", 13, UI.C_MUTED))
	_progress = ProgressBar.new()
	_progress.min_value = 0
	_progress.max_value = 4
	_progress.show_percentage = false
	_progress.custom_minimum_size = Vector2(0, 12)
	sv.add_child(_progress)
	body.add_child(side_panel)
	_refresh_notebook()


func _enter_stage(s: int) -> void:
	stage = s
	Stats.enter_stage(STAGE_KEYS[s])
	for i in range(_stage_labels.size()):
		var l: Label = _stage_labels[i]
		var col: Color = UI.C_MUTED
		if i < s:
			col = UI.C_GREEN.lightened(0.3)
		elif i == s:
			col = UI.C_ACCENT
		l.add_theme_color_override("font_color", col)
	_stage_title.text = STAGE_NAMES[s]
	_stage_task.text = STAGE_TASKS[s]
	_guide_label.text = STAGE_GUIDE[s] if hint_level >= 2 else ""
	_guide_label.visible = hint_level >= 2
	_progress.value = s
	_update_hint_button()
	match s:
		Stage.INVESTIGATE:
			_build_investigate()
		Stage.CHRONOLOGY:
			_build_chronology()
		Stage.RELIABILITY:
			_build_reliability()
		Stage.CONCLUSION:
			_build_conclusion()


func _set_actions(buttons: Array) -> void:
	UI.clear(_actions)
	for b in buttons:
		_actions.add_child(b)


func _card_quick_row() -> Control:
	var row := UI.hbox(6)
	row.add_child(UI.label("Карточкаларды қайта қарау:", 13, UI.C_MUTED, false))
	for c in ep["cards"]:
		var b := UI.button(str(c["format"]))
		b.add_theme_font_size_override("font_size", 13)
		b.pressed.connect(_peek_card.bind(str(c["id"])))
		row.add_child(b)
	return row


func _peek_card(cid: String) -> void:
	var view := SourceCardView.new()
	view.setup(DataRepo.get_card(ep, cid), marks[cid], bool(profile.get("chrono_support", false)), clues_done)
	UI.show_content_overlay(self, "Дереккөз карточкасы", view, "Жабу")


# =====================================================================
# 1-кезең: Зерттеу және салыстыру
# =====================================================================

func _build_investigate() -> void:
	UI.clear(_content)
	var cards: Array = ep["cards"]
	if compare_mode:
		_mark_visited(str(cards[compare_left]["id"]))
		_mark_visited(str(cards[compare_right]["id"]))
	else:
		_mark_visited(current_card)
	var row := UI.hbox(12)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content.add_child(row)

	var left := UI.vbox(8)
	left.custom_minimum_size = Vector2(230, 0)
	row.add_child(left)
	var mode := UI.hbox(4)
	var b_single := UI.button("Бір карточка", not compare_mode)
	b_single.pressed.connect(_set_compare.bind(false))
	var b_cmp := UI.button("Салыстыру", compare_mode)
	b_cmp.pressed.connect(_set_compare.bind(true))
	mode.add_child(b_single)
	mode.add_child(b_cmp)
	left.add_child(mode)

	for i in range(cards.size()):
		var c: Dictionary = cards[i]
		var cid: String = str(c["id"])
		var p := UI.panel(UI.C_PAPER if (cid == current_card and not compare_mode) else UI.C_PANEL, UI.C_ACCENT if cid == current_card else UI.C_PANEL_LIGHT, 8, 4, 1)
		var bv := UI.vbox(2)
		p.add_child(bv)
		var ink: Color = UI.C_INK if (cid == current_card and not compare_mode) else UI.C_TEXT
		bv.add_child(UI.label(str(c["format"]), 12, UI.C_RED if ink == UI.C_INK else UI.C_MUTED))
		bv.add_child(UI.label(str(c["title"]), 14, ink))
		var status: String = "✔ қаралды" if visited.has(cid) else "• жаңа"
		var m: int = (marks[cid] as Dictionary).size()
		bv.add_child(UI.label("%s · белгі: %d" % [status, m], 12, UI.C_GREEN.lightened(0.2) if visited.has(cid) else UI.C_ACCENT))
		var open := UI.button("Ашу")
		open.pressed.connect(_open_card.bind(cid))
		bv.add_child(open)
		left.add_child(p)

	if compare_mode:
		left.add_child(UI.label("Салыстыру: сол және оң жақ", 13, UI.C_MUTED))
		left.add_child(_compare_selector(true))
		left.add_child(_compare_selector(false))
		if bool(profile.get("require_compare", false)):
			left.add_child(UI.label("Бейімделу: салыстыру режимі міндетті.", 12, UI.C_BLUE.lightened(0.35)))

	var view_area := UI.hbox(10)
	view_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	view_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_child(view_area)
	if compare_mode:
		view_area.add_child(_card_scroll(str(cards[compare_left]["id"])))
		view_area.add_child(_card_scroll(str(cards[compare_right]["id"])))
		if not compare_noted and compare_left != compare_right:
			compare_noted = true
			Stats.note_compare_used()
	else:
		view_area.add_child(_card_scroll(current_card))

	var b_next := UI.button("Зерттеуді аяқтау →", true)
	var need_compare: bool = bool(profile.get("require_compare", false)) and not compare_noted
	b_next.disabled = visited.size() < cards.size() or need_compare
	b_next.pressed.connect(_finish_investigation)
	_set_actions([b_next])
	if visited.size() < cards.size():
		_status.text = "Қаралған карточкалар: %d/%d. Барлығын ашу керек." % [visited.size(), cards.size()]
	elif need_compare:
		_status.text = "Бейімделу талабы: кемінде бір рет «Салыстыру» режимін қолдан."
	else:
		_status.text = "Барлық карточка қаралды. Белгіленген сөйлемдер: %d." % _total_marks()


func _card_scroll(cid: String) -> Control:
	var view := SourceCardView.new()
	view.setup(DataRepo.get_card(ep, cid), marks[cid], bool(profile.get("chrono_support", false)), false)
	view.fragment_toggled.connect(_on_fragment_toggled)
	return UI.scroll(view)


func _compare_selector(is_left: bool) -> Control:
	var opt := OptionButton.new()
	opt.focus_mode = Control.FOCUS_NONE
	for c in ep["cards"]:
		opt.add_item(str(c["format"]))
	opt.selected = compare_left if is_left else compare_right
	opt.item_selected.connect(_on_compare_pick.bind(is_left))
	return opt


func _on_compare_pick(index: int, is_left: bool) -> void:
	if is_left:
		compare_left = index
	else:
		compare_right = index
	_build_investigate.call_deferred()


func _set_compare(value: bool) -> void:
	compare_mode = value
	if value and compare_left == compare_right:
		compare_right = (compare_left + 1) % (ep["cards"] as Array).size()
	_build_investigate.call_deferred()


func _mark_visited(cid: String) -> void:
	if not visited.has(cid):
		visited[cid] = true
		Stats.note_card_opened()


func _open_card(cid: String) -> void:
	current_card = cid
	if compare_mode:
		compare_left = _card_index(cid)
		if compare_right == compare_left:
			compare_right = (compare_left + 1) % (ep["cards"] as Array).size()
	_build_investigate.call_deferred()


func _card_index(cid: String) -> int:
	var cards: Array = ep["cards"]
	for i in range(cards.size()):
		if str(cards[i]["id"]) == cid:
			return i
	return 0


func _on_fragment_toggled(_cid: String, _index: int, _marked: bool) -> void:
	_refresh_notebook()
	_status.text = "Белгіленген сөйлемдер: %d." % _total_marks()


func _total_marks() -> int:
	var n: int = 0
	for cid in marks.keys():
		n += (marks[cid] as Dictionary).size()
	return n


func _refresh_notebook() -> void:
	var bb: String = ""
	for c in ep["cards"]:
		var cid: String = str(c["id"])
		var m: Dictionary = marks[cid]
		if m.is_empty():
			continue
		bb += "[color=%s][b]%s[/b][/color]\n" % [UI.hex(UI.C_ACCENT), str(c["format"])]
		var frags: Array = c["fragments"]
		var keys: Array = m.keys()
		keys.sort()
		for idx in keys:
			var t: String = str(frags[int(idx)]["t"])
			if t.length() > 70:
				t = t.substr(0, 68) + "…"
			bb += "• «%s»\n" % t
	if bb == "":
		bb = "[i]Әзірге белгі жоқ. Карточкадағы күдікті не маңызды сөйлемді бас.[/i]"
	_notebook.text = bb


func _finish_investigation() -> void:
	var found: int = 0
	var false_marks: int = 0
	var found_lines: String = ""
	var missed_lines: String = ""
	var false_lines: String = ""
	for c in ep["cards"]:
		var cid: String = str(c["id"])
		var frags: Array = c["fragments"]
		for i in range(frags.size()):
			var f: Dictionary = frags[i]
			var marked: bool = (marks[cid] as Dictionary).has(i)
			var is_clue: bool = bool(f.get("clue", false))
			var short: String = str(f["t"])
			if is_clue and marked:
				found += 1
				found_lines += "[color=%s]✔[/color] «%s»\n   [i]%s[/i]\n" % [UI.hex(UI.C_GREEN.lightened(0.3)), short, str(f.get("note", ""))]
			elif is_clue:
				missed_lines += "[color=%s]○[/color] «%s»\n   [i]%s[/i]\n" % [UI.hex(UI.C_ACCENT), short, str(f.get("note", ""))]
			elif marked:
				false_marks += 1
				false_lines += "[color=%s]✖[/color] «%s» — бейтарап сөйлем, тексеру үшін маңызы аз.\n" % [UI.hex(UI.C_RED.lightened(0.3)), short]
	var total: int = DataRepo.clue_total(ep)
	var res: Dictionary = Score.clue_score(found, false_marks, total, DataRepo.neutral_total(ep))
	Stats.record_clues(res)
	clues_done = true
	var bb: String = "Табылған маңызды белгілер: [b]%d/%d[/b] · Артық белгілер: [b]%d[/b] · Ұпай: [b]%d/100[/b]\n\n" % [found, total, false_marks, int(res["points"])]
	bb += "[color=#4f8f5c]Жасыл[/color] белгі — дерекке сенімділік беретін айғақ, [color=#b5432f]қызыл[/color] белгі — бұрмалау белгісі. Екеуі де детектив үшін маңызды.\n\n"
	if found_lines != "":
		bb += "[b]Сен тапқан айғақтар:[/b]\n" + found_lines + "\n"
	if missed_lines != "":
		bb += "[b]Назардан тыс қалғандар (енді хронология мен бағалауда ескер):[/b]\n" + missed_lines + "\n"
	if false_lines != "":
		bb += "[b]Артық белгілер:[/b]\n" + false_lines
	UI.show_overlay(self, "Зерттеу қорытындысы", bb, "Хронологияға өту →", _enter_stage.bind(Stage.CHRONOLOGY))


# =====================================================================
# 2-кезең: Хронология
# =====================================================================

func _build_chronology() -> void:
	UI.clear(_content)
	_content.add_child(_card_quick_row())
	chrono_board = ChronologyBoard.new()
	chrono_board.setup(ep["chronology"], bool(profile.get("chrono_support", false)), bool(profile.get("anchor_items", false)))
	chrono_board.changed.connect(_on_chrono_changed)
	_content.add_child(UI.scroll(chrono_board))
	_update_chrono_actions()
	_status.text = "Ең ерте оқиға — жоғарыда, ең кейінгісі — төменде."


func _update_chrono_actions() -> void:
	var b_check := UI.button("Тексеру" if chrono_checks == 0 else "Қайта тексеру", chrono_checks == 0)
	b_check.disabled = chrono_checks >= 3
	b_check.pressed.connect(_check_chronology)
	var buttons: Array = [b_check]
	if chrono_checks >= 2:
		var b_show := UI.button("Дұрыс ретті көрсету")
		b_show.pressed.connect(_reveal_chronology)
		buttons.append(b_show)
	var b_next := UI.button("Жалғастыру →", chrono_checks > 0)
	b_next.disabled = chrono_checks == 0
	b_next.pressed.connect(_enter_stage.bind(Stage.RELIABILITY))
	buttons.append(b_next)
	_set_actions(buttons)


func _on_chrono_changed() -> void:
	if chrono_checks > 0:
		_status.text = "Өзгеріс енгізілді. Қайта тексеруге болады (тек алғашқы тексеріс ұпайға есептеледі)."


func _check_chronology() -> void:
	var res: Dictionary = Score.chronology_score(chrono_board.get_order(), DataRepo.correct_chronology_order(ep),
		chrono_board.get_flags(), DataRepo.anomaly_ids(ep))
	chrono_checks += 1
	Stats.record_chronology(res)
	chrono_board.show_result(res)
	_update_chrono_actions()
	var n: int = int(res["items"])
	var bb: String = ""
	if chrono_checks == 1:
		bb += "[b]Бағаланатын (алғашқы) тексеріс.[/b] Ұпай: [b]%d/300[/b]\n\n" % int(res["points"])
	else:
		bb += "Қайта тексеріс №%d (ұпайға әсер етпейді, оқу үшін).\n\n" % chrono_checks
	bb += "Орнында тұрған элементтер: [b]%d/%d[/b] · Жалпы ауытқу: [b]%d[/b] позиция\n" % [n - int(res["errors"]), n, int(res["deviation"])]
	bb += "Уақыттық сәйкессіздіктер: табылды [b]%d[/b], байқалмады [b]%d[/b], қате белгі [b]%d[/b]\n\n" % [
		(res["anomaly_hits"] as Array).size(), (res["anomaly_missed"] as Array).size(), (res["anomaly_false"] as Array).size()]
	if bool(res["perfect"]):
		bb += "[color=#4f8f5c][b]Мінсіз! Уақыт осі толық қалпына келтірілді.[/b][/color]\n"
	else:
		bb += "Қызыл жиектелген элементтердің астында дұрыс орны мен [b]неліктен[/b] сол жерде тұратыны жазылған. Түзетіп, қайта тексер — бұл түсінуге көмектеседі.\n"
		for mid in res["misplaced"]:
			var it: Dictionary = DataRepo.get_chrono_item(ep, str(mid))
			bb += "• %s → [i]%s[/i]\n" % [str(it["text"]), str(it.get("explain", ""))]
		for aid in res["anomaly_missed"]:
			var it2: Dictionary = DataRepo.get_chrono_item(ep, str(aid))
			bb += "[color=#d4aa3a]⚠ Байқалмаған сәйкессіздік:[/color] %s\n" % str(it2.get("anomaly_note", ""))
	UI.show_overlay(self, "Хронология тексерісі", bb, "Тақтаға оралу")
	_status.text = "Тексеріс: %d/3. Жалғастыруға болады." % chrono_checks


func _reveal_chronology() -> void:
	chrono_board.reveal_correct()
	_status.text = "Дұрыс рет көрсетілді. Әр элементтің түсіндірмесін оқып шық."


# =====================================================================
# 3-кезең: Сенімділік
# =====================================================================

func _build_reliability() -> void:
	UI.clear(_content)
	_content.add_child(_card_quick_row())
	rel_panel = ReliabilityPanel.new()
	rel_panel.setup(ep["cards"], bool(profile.get("source_support", false)))
	rel_panel.changed.connect(_update_rel_actions)
	_content.add_child(UI.scroll(rel_panel))
	_update_rel_actions()


func _update_rel_actions() -> void:
	var b_check := UI.button("Тексеру", not rel_checked)
	b_check.disabled = not rel_panel.is_complete()
	b_check.pressed.connect(_check_reliability)
	var b_next := UI.button("Қорытындыға өту →", rel_checked)
	b_next.disabled = not rel_checked
	b_next.pressed.connect(_enter_stage.bind(Stage.CONCLUSION))
	_set_actions([b_check, b_next])
	if not rel_panel.is_complete():
		_status.text = "Әр карточкаға шкала мен белгіні таңда (%d/%d)." % [_rel_done_count(), (ep["cards"] as Array).size()]
	elif not rel_checked:
		_status.text = "Барлық бағалар қойылды. Тексеруге болады."


func _rel_done_count() -> int:
	var n: int = 0
	for c in ep["cards"]:
		var cid: String = str(c["id"])
		if rel_panel.ratings.has(cid) and rel_panel.tags.has(cid):
			n += 1
	return n


func _check_reliability() -> void:
	var res: Dictionary = Score.reliability_score(rel_panel.ratings, rel_panel.tags, ep["cards"])
	if not rel_checked:
		Stats.record_reliability(res)
	rel_checked = true
	rel_panel.show_result(res)
	_update_rel_actions()
	_status.text = "Сенімділік дәлдігі: %s · шкала %s · белгі %s · ұпай %d/300" % [
		UI.pct(float(res["accuracy"])), UI.pct(float(res["scale_accuracy"])), UI.pct(float(res["tag_accuracy"])), int(res["points"])]


# =====================================================================
# 4-кезең: Дәлелді қорытынды
# =====================================================================

func _build_conclusion() -> void:
	UI.clear(_content)
	_content.add_child(_card_quick_row())
	concl_panel = ConclusionPanel.new()
	concl_panel.setup(ep, rel_panel.ratings if rel_panel != null else {})
	concl_panel.changed.connect(_update_concl_actions)
	_content.add_child(UI.scroll(concl_panel))
	_update_concl_actions()


func _update_concl_actions() -> void:
	var b := UI.button("Қорытындыны тапсыру", true)
	b.disabled = not concl_panel.is_ready()
	b.pressed.connect(_submit_conclusion)
	_set_actions([b])
	_status.text = "Нұсқа: %s · дәлелдер: %d" % ["таңдалды" if concl_panel.selected_option != "" else "таңдалмады", concl_panel.get_evidence().size()]


func _submit_conclusion() -> void:
	var opt: Dictionary = concl_panel.get_selected()
	var evidence: Array = concl_panel.get_evidence()
	var res: Dictionary = Score.conclusion_score(bool(opt.get("correct", false)), evidence, ep["conclusion"], rel_panel.ratings)
	Stats.record_conclusion(res)
	var record: Dictionary = Stats.finish_episode()
	finished = true
	var ok_col: String = UI.hex(UI.C_GREEN.lightened(0.3))
	var bad_col: String = UI.hex(UI.C_RED.lightened(0.3))
	var bb: String = "[b]%s[/b]\n\n" % str(opt.get("feedback", ""))
	bb += "Дәлелділік баллы: [b]%d/100[/b]\n" % int(res["quality"])
	bb += "Міндетті дәлелдер: %d/%d\n" % [int(res["required_hits"]), int(res["required_total"])]
	for mid in res["missing"]:
		bb += "[color=%s]○ Қолданылмаған маңызды дәлел:[/color] %s\n" % [UI.hex(UI.C_ACCENT), DataRepo.evidence_label(ep, str(mid))]
	for fid in res["forbidden_used"]:
		bb += "[color=%s]✖ Сенімсіз дереккөзге сүйендің (−30):[/color] %s\n" % [bad_col, DataRepo.evidence_label(ep, str(fid))]
	for iid in res["inconsistent"]:
		bb += "[color=%s]✖ Өзіндік қайшылық (−10):[/color] өзің ≤2 деп бағалаған «%s» дереккөзін дәлел еттің.\n" % [bad_col, DataRepo.evidence_label(ep, str(iid))]
	if (res["forbidden_used"] as Array).is_empty() and (res["missing"] as Array).is_empty():
		bb += "[color=%s]✔ Дәлелдер жиыны таза әрі толық.[/color]\n" % ok_col
	bb += "\n[i]%s[/i]\n\n" % str(ep["conclusion"]["explain"])
	bb += "Іс %s. Жалпы ұпай: [b]%d/%d[/b] %s" % ["ШЕШІЛДІ" if bool(record["passed"]) else "ШЕШІЛМЕДІ", int(record["score"]), int(record["max_score"]), UI.stars_text(int(record["stars"]))]
	UI.show_overlay(self, "Қорытынды тексерісі", bb, "Нәтижелерге өту →", _go_results)


func _go_results() -> void:
	get_tree().change_scene_to_file("res://scenes/results.tscn")


# =====================================================================
# Кеңестер, брифинг, шығу
# =====================================================================

func _available_hints() -> int:
	return mini(3, 1 + hint_level)


func _update_hint_button() -> void:
	if _hint_btn == null:
		return
	var key: String = STAGE_KEYS[stage]
	var used: int = int(hint_index.get(key, 0))
	var left: int = _available_hints() - used
	_hint_btn.disabled = left <= 0
	_hint_btn.text = "Кеңес алу (−%d) · қалды: %d" % [Score.hint_penalty(hint_level), maxi(left, 0)]


func _on_hint() -> void:
	var key: String = STAGE_KEYS[stage]
	var used: int = int(hint_index.get(key, 0))
	var hints: Array = ep["hints"].get(key, [])
	if used >= _available_hints() or used >= hints.size():
		return
	var penalty: int = Stats.use_hint(key)
	hint_index[key] = used + 1
	revealed_hints.append("[color=%s]%s · кеңес %d (−%d):[/color] %s" % [UI.hex(UI.C_ACCENT), STAGE_NAMES[stage], used + 1, penalty, str(hints[used])])
	_hint_text.text = "\n\n".join(PackedStringArray(revealed_hints))
	_update_hint_button()


func _on_points_changed(points: int) -> void:
	if _score_label != null:
		_score_label.text = "Ұпай: %d" % points


func _show_briefing() -> void:
	var bb: String = "[b]%s[/b]\n\n" % str(ep["briefing"])
	bb += "[color=%s][b]Зерттеу сұрағы:[/b][/color] %s\n\n" % [UI.hex(UI.C_ACCENT), str(ep["research_question"])]
	bb += "[b]Күрделілік:[/b] %s\n" % str(ep["complexity_note"])
	bb += "[b]Мақсатты уақыт:[/b] %s · [b]коэффициент:[/b] ×%.2f\n\n" % [UI.format_time(float(Stats.record["target_time_sec"])), float(ep["multiplier"])]
	bb += "[color=%s][b]Саған бейімделген баптаулар:[/b][/color]\n" % UI.hex(UI.C_BLUE.lightened(0.35))
	for line in AdaptiveEngine.describe(profile):
		bb += "• %s\n" % str(line)
	bb += "\n[i]%s[/i]" % str(DataRepo.meta.get("disclaimer", ""))
	UI.show_overlay(self, "Жаңа іс: " + str(ep["title"]), bb, "Тергеуді бастау")


func _confirm_exit() -> void:
	UI.show_overlay(self, "Істен шығу", "Іс аяқталмаған. Шықсаң, бұл әрекеттің нәтижесі сақталмайды.",
		"Мәзірге шығу", _exit_to_select, "Жалғастыру")


func _exit_to_select() -> void:
	get_tree().change_scene_to_file("res://scenes/episode_select.tscn")
