extends RefCounted
## UIKit — детективтік атмосферадағы интерфейс элементтерін құрастыратын
## static көмекші функциялар (тақта, қағаз карточка, мөр, қалқымалы терезе).

const FONT_PATH := "res://assets/fonts/main.ttf"

const C_BG := Color("17140f")
const C_DESK := Color("241f18")
const C_PANEL := Color("312a20")
const C_PANEL_LIGHT := Color("3e3528")
const C_PAPER := Color("efe4c8")
const C_PAPER_DARK := Color("ddcca4")
const C_INK := Color("2b2118")
const C_INK_SOFT := Color("6a583f")
const C_TEXT := Color("ede3cf")
const C_MUTED := Color("b3a48a")
const C_ACCENT := Color("d4aa3a")
const C_RED := Color("b5432f")
const C_GREEN := Color("4f8f5c")
const C_BLUE := Color("4a7fb0")
const SCALE_COLORS := [Color("b5432f"), Color("c9772f"), Color("c9a227"), Color("7f9a45"), Color("4f8f5c")]


static func style(bg: Color, radius: int = 8, border: Color = Color.TRANSPARENT, border_w: int = 0, margin: int = 12) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(radius)
	if border_w > 0:
		sb.border_color = border
		sb.set_border_width_all(border_w)
	sb.set_content_margin_all(margin)
	return sb


static func build_theme() -> Theme:
	var t := Theme.new()
	t.default_font_size = 17
	if ResourceLoader.exists(FONT_PATH):
		var f = load(FONT_PATH)
		if f is Font:
			t.default_font = f
	# Button
	t.set_stylebox("normal", "Button", style(C_PANEL_LIGHT, 6, C_ACCENT.darkened(0.45), 1, 9))
	t.set_stylebox("hover", "Button", style(C_PANEL_LIGHT.lightened(0.12), 6, C_ACCENT, 1, 9))
	t.set_stylebox("pressed", "Button", style(C_ACCENT.darkened(0.35), 6, C_ACCENT, 2, 9))
	t.set_stylebox("disabled", "Button", style(C_PANEL, 6, C_PANEL_LIGHT, 1, 9))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_color", "Button", C_TEXT)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", Color.WHITE)
	t.set_color("font_hover_pressed_color", "Button", Color.WHITE)
	t.set_color("font_focus_color", "Button", C_TEXT)
	t.set_color("font_disabled_color", "Button", C_MUTED.darkened(0.35))
	# OptionButton
	t.set_stylebox("normal", "OptionButton", style(C_PANEL_LIGHT, 6, C_ACCENT.darkened(0.45), 1, 9))
	t.set_stylebox("hover", "OptionButton", style(C_PANEL_LIGHT.lightened(0.12), 6, C_ACCENT, 1, 9))
	t.set_stylebox("pressed", "OptionButton", style(C_PANEL_LIGHT, 6, C_ACCENT, 1, 9))
	t.set_stylebox("focus", "OptionButton", StyleBoxEmpty.new())
	t.set_color("font_color", "OptionButton", C_TEXT)
	t.set_color("font_hover_color", "OptionButton", Color.WHITE)
	t.set_stylebox("panel", "PopupMenu", style(C_DESK, 4, C_ACCENT.darkened(0.3), 1, 6))
	t.set_color("font_color", "PopupMenu", C_TEXT)
	t.set_color("font_hover_color", "PopupMenu", C_ACCENT)
	# CheckBox
	t.set_color("font_color", "CheckBox", C_TEXT)
	t.set_color("font_hover_color", "CheckBox", Color.WHITE)
	t.set_color("font_pressed_color", "CheckBox", C_ACCENT)
	t.set_color("font_hover_pressed_color", "CheckBox", C_ACCENT)
	t.set_stylebox("focus", "CheckBox", StyleBoxEmpty.new())
	# Label / RichTextLabel / Panel
	t.set_color("font_color", "Label", C_TEXT)
	t.set_color("default_color", "RichTextLabel", C_TEXT)
	t.set_stylebox("panel", "PanelContainer", style(C_PANEL, 8, C_PANEL_LIGHT, 1, 12))
	# ProgressBar
	t.set_stylebox("background", "ProgressBar", style(C_DESK, 4, C_PANEL_LIGHT, 1, 0))
	t.set_stylebox("fill", "ProgressBar", style(C_ACCENT, 4, Color.TRANSPARENT, 0, 0))
	t.set_color("font_color", "ProgressBar", C_INK)
	return t


static func full_rect(c: Control) -> Control:
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return c


static func background(host: Control) -> ColorRect:
	var bg := ColorRect.new()
	bg.color = C_BG
	full_rect(bg)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(bg)
	return bg


static func label(text: String, size: int = 17, color: Color = C_TEXT, wrap: bool = true) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


static func rich(bbcode: String, size: int = 17, color: Color = C_TEXT) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.selection_enabled = false
	r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.add_theme_font_size_override("normal_font_size", size)
	r.add_theme_font_size_override("bold_font_size", size)
	r.add_theme_font_size_override("italics_font_size", size)
	r.add_theme_color_override("default_color", color)
	r.text = bbcode
	return r


static func button(text: String, primary: bool = false, min_width: int = 0) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	if min_width > 0:
		b.custom_minimum_size = Vector2(min_width, 0)
	if primary:
		b.add_theme_stylebox_override("normal", style(C_ACCENT.darkened(0.15), 6, C_ACCENT, 1, 10))
		b.add_theme_stylebox_override("hover", style(C_ACCENT, 6, Color.WHITE, 1, 10))
		b.add_theme_stylebox_override("pressed", style(C_ACCENT.darkened(0.35), 6, C_ACCENT, 1, 10))
		b.add_theme_color_override("font_color", C_INK)
		b.add_theme_color_override("font_hover_color", C_INK)
		b.add_theme_color_override("font_pressed_color", C_INK)
	return b


static func panel(bg: Color = C_PANEL, border: Color = C_PANEL_LIGHT, margin: int = 12, radius: int = 8, border_w: int = 1) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", style(bg, radius, border, border_w, margin))
	return p


static func paper(margin: int = 16) -> PanelContainer:
	return panel(C_PAPER, C_PAPER_DARK.darkened(0.25), margin, 4, 2)


static func vbox(separation: int = 8) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", separation)
	return v


static func hbox(separation: int = 8) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", separation)
	return h


static func spacer(expand_h: bool = true) -> Control:
	var c := Control.new()
	if expand_h:
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	else:
		c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return c


static func badge(text: String, bg: Color, fg: Color = C_INK, size: int = 13) -> PanelContainer:
	var p := panel(bg, bg.darkened(0.3), 4, 4, 1)
	p.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var l := label(text, size, fg, false)
	p.add_child(l)
	return p


static func scroll(child: Control) -> ScrollContainer:
	var s := ScrollContainer.new()
	s.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.size_flags_vertical = Control.SIZE_EXPAND_FILL
	child.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.add_child(child)
	return s


static func clear(node: Node) -> void:
	for c in node.get_children():
		node.remove_child(c)
		c.queue_free()


static func stars_text(stars: int) -> String:
	var s: String = ""
	for i in range(3):
		s += "★" if i < stars else "☆"
	return s


static func format_time(sec: float) -> String:
	var s: int = int(sec)
	return "%02d:%02d" % [s / 60, s % 60]


static func pct(v: float) -> String:
	return "%d%%" % roundi(v * 100.0)


static func hex(c: Color) -> String:
	return "#" + c.to_html(false)


## Қалқымалы «іс қағазы» терезесі: тақырып, BBCode мәтін, жабу батырмасы.
## Іске асыру scripts/ui/overlay.gd ішінде (сигналдар инстанс әдістеріне қосылады).
static func show_overlay(host: Control, title: String, bbcode: String, button_text: String = "Түсіндім", on_close: Callable = Callable(), cancel_text: String = "") -> Control:
	var o = load("res://scripts/ui/overlay.gd").new()
	host.add_child(o)
	o.setup(title, bbcode, button_text, on_close, cancel_text)
	return o


static func show_content_overlay(host: Control, title: String, content: Control, button_text: String = "Жабу") -> Control:
	var o = load("res://scripts/ui/overlay.gd").new()
	host.add_child(o)
	o.setup_content(title, content, button_text)
	return o
