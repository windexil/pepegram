extends Control
## ScatterChart — екі параметрді салыстыру диаграммасы (4 квадрант).
## Әр нүкте — бір эпизодтық әрекет; үзік сызықтар — бейімделу шектері.

const UI = preload("res://scripts/ui/ui_kit.gd")

var title: String = ""
var x_label: String = ""
var y_label: String = ""
var x_max: float = 1.0
var y_max: float = 1.0
var x_threshold: float = 0.5
var y_threshold: float = 0.5
var y_threshold2: float = -1.0
var quadrant_labels: Array = ["", "", "", ""]  # [жоғары-сол, жоғары-оң, төмен-сол, төмен-оң]
var points: Array = []      # [{x, y, label, current}]


func configure(p: Dictionary) -> void:
	for k in p.keys():
		set(k, p[k])
	custom_minimum_size = Vector2(420, 300)
	queue_redraw()


func _draw() -> void:
	var font: Font = get_theme_default_font()
	var pad_l: float = 46.0
	var pad_b: float = 40.0
	var pad_t: float = 30.0
	var pad_r: float = 12.0
	var w: float = size.x - pad_l - pad_r
	var h: float = size.y - pad_t - pad_b
	var origin := Vector2(pad_l, pad_t + h)
	draw_rect(Rect2(Vector2.ZERO, size), UI.C_DESK)
	draw_string(font, Vector2(8, 20), title, HORIZONTAL_ALIGNMENT_LEFT, size.x - 16, 15, UI.C_ACCENT)
	draw_rect(Rect2(pad_l, pad_t, w, h), UI.C_PANEL)

	# Квадрант шектері
	var tx: float = pad_l + w * clampf(x_threshold / x_max, 0.0, 1.0)
	var ty: float = pad_t + h * (1.0 - clampf(y_threshold / y_max, 0.0, 1.0))
	draw_dashed_line(Vector2(tx, pad_t), Vector2(tx, pad_t + h), UI.C_MUTED, 1.5, 6.0)
	draw_dashed_line(Vector2(pad_l, ty), Vector2(pad_l + w, ty), UI.C_MUTED, 1.5, 6.0)
	if y_threshold2 >= 0.0:
		var ty2: float = pad_t + h * (1.0 - clampf(y_threshold2 / y_max, 0.0, 1.0))
		draw_dashed_line(Vector2(pad_l, ty2), Vector2(pad_l + w, ty2), UI.C_MUTED.darkened(0.3), 1.0, 4.0)

	var qcol: Color = UI.C_MUTED.darkened(0.15)
	draw_string(font, Vector2(pad_l + 6, pad_t + 16), str(quadrant_labels[0]), HORIZONTAL_ALIGNMENT_LEFT, tx - pad_l - 8, 12, qcol)
	draw_string(font, Vector2(tx + 6, pad_t + 16), str(quadrant_labels[1]), HORIZONTAL_ALIGNMENT_LEFT, pad_l + w - tx - 8, 12, qcol)
	draw_string(font, Vector2(pad_l + 6, pad_t + h - 8), str(quadrant_labels[2]), HORIZONTAL_ALIGNMENT_LEFT, tx - pad_l - 8, 12, qcol)
	draw_string(font, Vector2(tx + 6, pad_t + h - 8), str(quadrant_labels[3]), HORIZONTAL_ALIGNMENT_LEFT, pad_l + w - tx - 8, 12, qcol)

	# Осьтер
	draw_line(origin, Vector2(pad_l + w, origin.y), UI.C_TEXT, 1.5)
	draw_line(origin, Vector2(pad_l, pad_t), UI.C_TEXT, 1.5)
	draw_string(font, Vector2(pad_l, size.y - 8), x_label, HORIZONTAL_ALIGNMENT_CENTER, w, 13, UI.C_TEXT)
	draw_string(font, Vector2(4, pad_t - 4), y_label, HORIZONTAL_ALIGNMENT_LEFT, pad_l + w, 12, UI.C_TEXT)
	draw_string(font, Vector2(pad_l - 4, origin.y + 16), "0", HORIZONTAL_ALIGNMENT_LEFT, 20, 12, UI.C_MUTED)
	draw_string(font, Vector2(pad_l + w - 40, origin.y + 16), _fmt(x_max), HORIZONTAL_ALIGNMENT_RIGHT, 40, 12, UI.C_MUTED)
	draw_string(font, Vector2(4, pad_t + 12), _fmt(y_max), HORIZONTAL_ALIGNMENT_LEFT, 40, 12, UI.C_MUTED)

	# Нүктелер
	for p in points:
		var px: float = pad_l + w * clampf(float(p["x"]) / x_max, 0.0, 1.0)
		var py: float = pad_t + h * (1.0 - clampf(float(p["y"]) / y_max, 0.0, 1.0))
		var is_cur: bool = bool(p.get("current", false))
		var col: Color = UI.C_ACCENT if is_cur else UI.C_BLUE.lightened(0.2)
		draw_circle(Vector2(px, py), 8.0 if is_cur else 6.0, col)
		draw_string(font, Vector2(px + 9, py - 6), str(p.get("label", "")), HORIZONTAL_ALIGNMENT_LEFT, 80, 12, UI.C_TEXT)


func _fmt(v: float) -> String:
	if is_equal_approx(v, 1.0):
		return "100%"
	return "%.1f" % v
