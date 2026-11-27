extends Control
## Басты мәзір: ойынға кіру, нұсқаулық, аналитика, прогресті тазалау.

const UI = preload("res://scripts/ui/ui_kit.gd")


func _ready() -> void:
	theme = UI.build_theme()
	UI.background(self)
	_build()


func _build() -> void:
	var center := CenterContainer.new()
	UI.full_rect(center)
	add_child(center)
	var v := UI.vbox(14)
	v.custom_minimum_size = Vector2(640, 0)
	center.add_child(v)

	v.add_child(UI.label("%s · %s" % [str(DataRepo.meta.get("case", "КЕЙС 07")), str(DataRepo.meta.get("direction", ""))], 15, UI.C_MUTED))
	var title := UI.label("HISTORY DETECTIVE", 52, UI.C_ACCENT)
	v.add_child(title)
	v.add_child(UI.label("Тарихи дерек зерттеушісі", 26, UI.C_TEXT))
	v.add_child(UI.label("Құжаттарды зертте, дереккөздерді салыстыр, хронологияны қалпына келтір, сенімділігін бағала және тек дәлелге сүйеніп қорытынды жаса.", 16, UI.C_MUTED))

	if DataRepo.load_error != "":
		v.add_child(UI.label("ҚАТЕ: " + DataRepo.load_error, 16, UI.C_RED))

	var progress := UI.label("Ашылған істер: %d/%d   ·   Шешілген істер: %d/%d" % [
		GameState.unlocked_count(), DataRepo.episode_count(), GameState.passed_count(), DataRepo.episode_count()], 15, UI.C_TEXT)
	v.add_child(progress)

	var b_play := UI.button("Тергеуді бастау", true, 320)
	b_play.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/episode_select.tscn"))
	v.add_child(b_play)
	var b_how := UI.button("Қалай ойнау керек?", false, 320)
	b_how.pressed.connect(_show_how_to)
	v.add_child(b_how)
	var b_an := UI.button("Аналитика және бейімделу", false, 320)
	b_an.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/analytics.tscn"))
	v.add_child(b_an)
	var b_reset := UI.button("Прогресті тазалау", false, 320)
	b_reset.pressed.connect(_confirm_reset)
	v.add_child(b_reset)
	var b_quit := UI.button("Шығу", false, 320)
	b_quit.pressed.connect(func(): get_tree().quit())
	v.add_child(b_quit)

	v.add_child(UI.label("Автор / орындаушы: %s" % str(DataRepo.meta.get("author", "")), 14, UI.C_MUTED))
	v.add_child(UI.label(str(DataRepo.meta.get("disclaimer", "")), 12, UI.C_MUTED.darkened(0.2)))


func _show_how_to() -> void:
	var bb: String = """[b]Сен — тарихи дерек детективісің.[/b] Әр іс — бір тарихи эпизод және 3 дереккөз карточкасы.

[color=#d4aa3a][b]1. Зерттеу[/b][/color] — 3 карточканы аш, деректемелерін (автор, уақыт, шығу тегі, жанр) оқы. Мәтіндегі маңызды немесе күдікті сөйлемдерді басып белгіле. «Салыстыру» режимінде екі карточканы қатар қара.
[color=#d4aa3a][b]2. Хронология[/b][/color] — оқиғалар мен дереккөздерді ▲/▼ арқылы уақыт тәртібімен реттеп, уақыттық сәйкессіздігі (анахронизмі) бар элементтерді «⚠» деп белгіле.
[color=#d4aa3a][b]3. Сенімділік[/b][/color] — әр дереккөзге 1–5 шкаласы бойынша баға қой және негізгі ерекшелігін таңда: расталған дерек, біржақтылық, анахронизм, жанама куәлік, естелік бұрмалануы, манипуляция.
[color=#d4aa3a][b]4. Қорытынды[/b][/color] — зерттеу сұрағына жауап таңда және оны қолдайтын СЕНІМДІ дәлелдерді белгіле. Жүйе қорытындының дәлелділігін тексереді.

[b]Ұпай[/b]: табылған белгілер (100) + хронология (300) + сенімділік (300) + дәлелділік (300) + уақыт бонусы. Кеңес алу ұпайды азайтады. Қиындық коэффициенті: 1.0 → 1.25 → 1.5.
[b]Өту шарты[/b]: дұрыс қорытынды және кемінде 45 % нәтиже. Үш істі шешсең — «Бас детектив» атағын аласың.
[b]Бейімделу[/b]: ойын сенің қателеріңді талдап, келесі іске кеңес деңгейін, уақыт маркерлерін және салыстыру көмекшісін автоматты түрде баптайды. Аналитика экранында оның себебі көрсетіледі."""
	UI.show_overlay(self, "Қалай ойнау керек?", bb, "Түсінікті")


func _confirm_reset() -> void:
	UI.show_overlay(self, "Прогресті тазалау", "Барлық статистика, бейімделу профилі және ашылған істер өшіріледі.\n\n[color=#b5432f]Абай бол: бұл әрекетті қайтару мүмкін емес.[/color]", "Иә, тазалау", _do_reset, "Бас тарту")


func _do_reset() -> void:
	GameState.reset_progress()
	get_tree().reload_current_scene()
