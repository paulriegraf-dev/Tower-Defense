class_name Startmenue extends CanvasLayer
## Übergangsmenü: normales Spiel oder Sandbox (5000 Budget, Erdwälle & Co. schon in Runde 1).

signal gewaehlt(sandbox: bool)


func _init() -> void:
	layer = 100
	var grund := ColorRect.new()
	grund.color = Color(0.05, 0.07, 0.1, 0.94)
	grund.set_anchors_preset(Control.PRESET_FULL_RECT)
	grund.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(grund)
	var mitte := CenterContainer.new()
	mitte.set_anchors_preset(Control.PRESET_FULL_RECT)
	grund.add_child(mitte)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	mitte.add_child(box)
	var titel := Label.new()
	titel.text = "Tower Defense"
	titel.add_theme_font_size_override("font_size", 36)
	titel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(titel)
	box.add_child(_knopf("Normales Spiel  [1]", "Start mit 120 Budget, Erdwälle ab Runde 2.", false))
	box.add_child(_knopf("Sandbox  [2]", "Gleiches Spiel, aber unendlich Budget, alle Bauwerke ab Runde 1, Runde und Gegner einstellbar.", true))


func _knopf(text: String, hinweis: String, sandbox: bool) -> Control:
	var v := VBoxContainer.new()
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(380, 54)
	b.add_theme_font_size_override("font_size", 20)
	b.pressed.connect(func(): gewaehlt.emit(sandbox))
	v.add_child(b)
	var l := Label.new()
	l.text = hinweis
	l.modulate = Color(1, 1, 1, 0.65)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(l)
	return v


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_1 or event.keycode == KEY_KP_1:
			get_viewport().set_input_as_handled()
			gewaehlt.emit(false)
		elif event.keycode == KEY_2 or event.keycode == KEY_KP_2:
			get_viewport().set_input_as_handled()
			gewaehlt.emit(true)
