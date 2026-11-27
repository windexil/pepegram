extends PanelContainer
## SourceCardView — дереккөз карточкасы «қағаз» түрінде.
## Мәтіннің әр сөйлемі басылатын: ойыншы күдікті / маңызды фрагменттерді
## белгілейді (дәлел жинау). Маңызды фрагменттер алдын ала көрсетілмейді.

const UI = preload("res://scripts/ui/ui_kit.gd")

signal fragment_toggled(card_id: String, index: int, marked: bool)

var card: Dictionary = {}
var marks: Dictionary = {}          # {fragment_index: true} — контроллермен ортақ сілтеме
var highlight_time: bool = false    # бейімделу: уақыт маркерлерін ерекшелеу
var reveal: bool = false            # тексерістен кейін маңызды фрагменттерді көрсету
var _text: RichTextLabel


func setup(p_card: Dictionary, p_marks: Dictionary, p_highlight_time: bool, p_reveal: bool = false) -> void:
	card = p_card
	marks = p_marks
	highlight_time = p_highlight_time
	reveal = p_reveal
	add_theme_stylebox_override("panel", UI.style(UI.C_PAPER, 4, UI.C_PAPER_DARK.darkened(0.3), 2, 18))
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_build()


func _build() -> void:
	UI.clear(self)
	var v := UI.vbox(8)
	add_child(v)

	var head := UI.hbox(8)
	head.add_child(UI.badge(str(card["format"]).to_upper(), UI.C_INK_SOFT, UI.C_PAPER, 12))
	head.add_child(UI.spacer())
	head.add_child(UI.label(str(card["date_label"]), 14, UI.C_RED, false))
	v.add_child(head)

	v.add_child(UI.label(str(card["title"]), 21, UI.C_INK))

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 4)
	for pair in [["Авторы:", "author"], ["Шығу тегі:", "origin"], ["Жанры:", "genre"], ["Уақыты:", "date_label"]]:
		var k := UI.label(str(pair[0]), 14, UI.C_INK_SOFT, false)
		k.custom_minimum_size = Vector2(92, 0)
		grid.add_child(k)
		grid.add_child(UI.label(str(card[pair[1]]), 14, UI.C_INK))
	v.add_child(grid)

	var det_lines: String = "[b]Тексеруге арналған деректемелер:[/b]\n"
	for d in card.get("details", []):
		det_lines += "  ▪ " + str(d) + "\n"
	v.add_child(UI.rich(det_lines.strip_edges(), 14, UI.C_INK))

	var sep := HSeparator.new()
	sep.add_theme_stylebox_override("separator", UI.style(UI.C_INK_SOFT, 0, Color.TRANSPARENT, 0, 0))
	v.add_child(sep)
	v.add_child(UI.label("Мәтін үзіндісі — маңызды немесе күдікті сөйлемді басып белгіле:", 13, UI.C_INK_SOFT))

	_text = UI.rich("", 18, UI.C_INK)
	_text.meta_underlined = false
	_text.meta_clicked.connect(_on_meta_clicked)
	_text.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	v.add_child(_text)
	_render_text()


func _render_text() -> void:
	var bb: String = ""
	var frags: Array = card.get("fragments", [])
	for i in range(frags.size()):
		var f: Dictionary = frags[i]
		var t: String = str(f["t"])
		var is_tm: bool = highlight_time and bool(f.get("tm", false))
		var seg: String = t
		if is_tm:
			seg = "[color=%s][u]⏱ %s[/u][/color]" % [UI.hex(UI.C_BLUE), t]
		if bool(marks.get(i, false)):
			seg = "[bgcolor=#e8c766]%s[/bgcolor]" % seg
		if reveal and bool(f.get("clue", false)):
			var c: Color = UI.C_GREEN if str(f.get("kind", "")) == "green" else UI.C_RED
			seg = "[color=%s][b]%s[/b][/color]" % [UI.hex(c), seg]
		bb += "[url=%d]%s[/url] " % [i, seg]
	_text.text = bb


func _on_meta_clicked(meta) -> void:
	var idx: int = int(str(meta))
	var now: bool = not bool(marks.get(idx, false))
	if now:
		marks[idx] = true
	else:
		marks.erase(idx)
	_render_text()
	fragment_toggled.emit(str(card["id"]), idx, now)


func set_reveal(value: bool) -> void:
	reveal = value
	_render_text()
