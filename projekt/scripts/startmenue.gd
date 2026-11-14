class_name Startmenue extends CanvasLayer
## Startmenü: normales Spiel, Sandbox oder Phantom-Modus (dort weiter: Angreifer oder Verteidiger, dann das Phantom).
## Bedient wird es nur mit der Maus.

signal gewaehlt(sandbox: bool)
signal phantom_gewaehlt(art: String, pfad: String)

var _box: VBoxContainer


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
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 14)
	mitte.add_child(_box)
	_zeige_haupt()


func _leere(titel: String, gross: int = 36) -> void:
	for k in _box.get_children():
		_box.remove_child(k)
		k.queue_free()
	var l := Label.new()
	l.text = titel
	l.add_theme_font_size_override("font_size", gross)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_box.add_child(l)


func _knopf(text: String, hinweis: String, aktion: Callable, breite: float = 380.0) -> void:
	var v := VBoxContainer.new()
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(breite, 54)
	b.add_theme_font_size_override("font_size", 20)
	b.pressed.connect(aktion)
	v.add_child(b)
	if hinweis != "":
		var l := Label.new()
		l.text = hinweis
		l.modulate = Color(1, 1, 1, 0.65)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(l)
	_box.add_child(v)


func _zurueck(aktion: Callable) -> void:
	var b := Button.new()
	b.text = "← Zurück"
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 40)
	b.add_theme_font_size_override("font_size", 16)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(aktion)
	_box.add_child(b)


func _zeige_haupt() -> void:
	_leere("Tower Defense")
	_knopf("Normales Spiel", "", func(): gewaehlt.emit(false))
	_knopf("Sandbox", "", func(): gewaehlt.emit(true))
	_knopf("Phantom-Modus", "", _zeige_phantom_modus)


func _zeige_phantom_modus() -> void:
	_leere("Phantom-Modus")
	_knopf("Angreifer", "Seitenwechsel: Du greifst den aufgezeichneten Bau eines Spielers an – mit festem Budget je Runde.", _zeige_phantome.bind("verteidigung"))
	_knopf("Verteidiger", "Normales Spiel, aber die 20 Wellen stammen von einem Angreifer aus dem Phantom-Modus.", _zeige_phantome.bind("angriff"))
	_zurueck(_zeige_haupt)


## Liste der Phantome einer Art; ein Klick startet den Modus damit.
func zeige_phantome(art: String) -> void:
	_zeige_phantome(art)


func _zeige_phantome(art: String) -> void:
	var funde := Phantom.liste(art)
	_leere("Welchen Bau greifst du an?" if art == "verteidigung" else "Gegen wessen Angriff verteidigst du?", 26)
	if funde.is_empty():
		var leer := Label.new()
		leer.text = "Noch kein Phantom im Ordner „Phantom Dateien“." if art == "verteidigung" else "Noch kein Angriff gespeichert. Spiele zuerst einmal als Angreifer."
		leer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_box.add_child(leer)
	for f: Dictionary in funde.slice(0, 8):
		var b := Button.new()
		b.text = f["titel"]
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(560, 44)
		b.add_theme_font_size_override("font_size", 17)
		b.pressed.connect(func(): phantom_gewaehlt.emit(art, f["pfad"]))
		_box.add_child(b)
	_zurueck(_zeige_phantom_modus)
