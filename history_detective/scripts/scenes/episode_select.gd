extends Control
## Істерді (эпизодтарды) таңдау: 3 «іс папкасы», құлып, үздік нәтиже,
## күрделілік және келесі іске қолданылатын бейімделу профилі.

const UI = preload("res://scripts/ui/ui_kit.gd")
const AdaptiveEngine = preload("res://scripts/core/adaptive_engine.gd")


func _ready() -> void:
	theme = UI.build_theme()
	UI.background(self)
	_build()


func _build() -> void:
	var margin := MarginContainer.new()
	UI.full_rect(margin)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	add_child(margin)
	var root := UI.vbox(16)
	margin.add_child(root)

	var head := UI.hbox(12)
	head.add_child(UI.label("ІС ПАПКАЛАРЫ", 30, UI.C_ACCENT, false))
	head.add_child(UI.spacer())
	var back := UI.button("← Мәзір")
	back.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/main_menu.tscn"))
	head.add_child(back)
	root.add_child(head)
	root.add_child(UI.label("Әр іс алдыңғысынан күрделірек: бұрмалаулар жасырынырақ, уақыт маркерлері жанама, куәліктер қайшылықты.", 15, UI.C_MUTED))

	var row := UI.hbox(18)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(row)
	for ep in DataRepo.episodes:
		row.add_child(_folder(ep))

	# Бейімделу профилі
	var prof: Dictionary = GameState.get_profile()
	var pp := UI.panel(UI.C_DESK, UI.C_BLUE, 12, 6, 1)
	var pv := UI.vbox(4)
	pp.add_child(pv)
	pv.add_child(UI.label("Келесі іске қолданылатын бейімделу профилі:", 15, UI.C_BLUE.lightened(0.35)))
	pv.add_child(UI.label(" · ".join(PackedStringArray(AdaptiveEngine.describe(prof))), 14, UI.C_TEXT))
	root.add_child(pp)

	if GameState.all_passed():
		root.add_child(UI.label("★ Барлық істер шешілді! Сен — «Бас детектив». Нәтижені жақсарту үшін кез келген істі қайта ойнай аласың.", 17, UI.C_ACCENT))


func _folder(ep: Dictionary) -> Control:
	var idx: int = int(ep["index"])
	var unlocked: bool = GameState.is_unlocked(idx)
	var passed: bool = GameState.is_passed(str(ep["id"]))
	var p := UI.panel(UI.C_PAPER if unlocked else UI.C_PANEL, UI.C_PAPER_DARK.darkened(0.3), 18, 4, 2)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := UI.vbox(8)
	p.add_child(v)
	var ink: Color = UI.C_INK if unlocked else UI.C_MUTED
	var top := UI.hbox(6)
	top.add_child(UI.badge("ДЕҢГЕЙ %d · %s" % [idx, str(ep["difficulty_name"]).to_upper()], UI.C_INK_SOFT if unlocked else UI.C_PANEL_LIGHT, UI.C_PAPER, 12))
	top.add_child(UI.spacer())
	if passed:
		top.add_child(UI.badge("ШЕШІЛДІ", UI.C_GREEN, Color.WHITE, 12))
	elif not unlocked:
		top.add_child(UI.badge("ҚҰЛЫПТАЛҒАН", UI.C_PANEL_LIGHT, UI.C_MUTED, 12))
	v.add_child(top)
	v.add_child(UI.label(str(ep["title"]), 22, ink))
	v.add_child(UI.label(str(ep["period"]), 16, UI.C_RED if unlocked else UI.C_MUTED))
	v.add_child(UI.label(str(ep["research_question"]) if unlocked else "Алдыңғы істі шешкен соң ашылады.", 15, ink))
	v.add_child(UI.label("Күрделілік: " + str(ep["complexity_note"]), 13, UI.C_INK_SOFT if unlocked else UI.C_MUTED))
	v.add_child(UI.label("Коэффициент ×%.2f · мақсатты уақыт %s" % [float(ep["multiplier"]), UI.format_time(float(ep["target_time_sec"]))], 13, UI.C_INK_SOFT if unlocked else UI.C_MUTED))
	v.add_child(UI.spacer(false))
	var best: Dictionary = GameState.best_for(str(ep["id"]))
	if not best.is_empty():
		v.add_child(UI.label("Үздік нәтиже: %d / %d  %s" % [int(best["score"]), int(best["max"]), UI.stars_text(int(best["stars"]))], 16, UI.C_INK))
	var btn := UI.button("Істі ашу" if unlocked else "Құлыпталған", unlocked)
	btn.disabled = not unlocked
	btn.pressed.connect(_open.bind(str(ep["id"])))
	v.add_child(btn)
	return p


func _open(episode_id: String) -> void:
	GameState.current_episode_id = episode_id
	get_tree().change_scene_to_file("res://scenes/investigation.tscn")
