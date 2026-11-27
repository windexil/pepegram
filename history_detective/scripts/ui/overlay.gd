extends ColorRect
## Overlay — модальді «іс қағазы» терезесі (кері байланыс, брифинг, нұсқаулық).

const UI = preload("res://scripts/ui/ui_kit.gd")

signal closed

var _on_close: Callable = Callable()


func setup(title: String, bbcode: String, button_text: String, on_close: Callable, cancel_text: String = "") -> void:
	_on_close = on_close
	color = Color(0, 0, 0, 0.7)
	UI.full_rect(self)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var center := CenterContainer.new()
	UI.full_rect(center)
	add_child(center)
	var p := UI.panel(UI.C_DESK, UI.C_ACCENT, 22, 10, 2)
	p.custom_minimum_size = Vector2(800, 0)
	center.add_child(p)
	var v := UI.vbox(12)
	p.add_child(v)
	v.add_child(UI.label(title, 24, UI.C_ACCENT))
	var body := UI.rich(bbcode, 17)
	var sc := UI.scroll(body)
	sc.custom_minimum_size = Vector2(756, 400)
	v.add_child(sc)
	var row := UI.hbox()
	row.add_child(UI.spacer())
	if cancel_text != "":
		var cancel := UI.button(cancel_text, false, 160)
		cancel.pressed.connect(queue_free)
		row.add_child(cancel)
	var btn := UI.button(button_text, true, 180)
	row.add_child(btn)
	v.add_child(row)
	btn.pressed.connect(_close)


func _close() -> void:
	closed.emit()
	if _on_close.is_valid():
		_on_close.call()
	queue_free()


## Мәтін емес, дайын Control көрсететін нұсқа (мысалы, карточканы қайта қарау).
func setup_content(title: String, content: Control, button_text: String) -> void:
	color = Color(0, 0, 0, 0.7)
	UI.full_rect(self)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var center := CenterContainer.new()
	UI.full_rect(center)
	add_child(center)
	var p := UI.panel(UI.C_DESK, UI.C_ACCENT, 18, 10, 2)
	p.custom_minimum_size = Vector2(820, 0)
	center.add_child(p)
	var v := UI.vbox(10)
	p.add_child(v)
	v.add_child(UI.label(title, 20, UI.C_ACCENT))
	var sc := UI.scroll(content)
	sc.custom_minimum_size = Vector2(780, 470)
	v.add_child(sc)
	var row := UI.hbox()
	row.add_child(UI.spacer())
	var btn := UI.button(button_text, true, 160)
	btn.pressed.connect(_close)
	row.add_child(btn)
	v.add_child(row)
