class_name Fabrikmenue
extends PanelContainer
## Tafel an der angeklickten Fabrik: Truppe wählen (Stufe 0) und die nächste Ausbaustufe kaufen.
## Tasten: Q / W / E = Truppe (Stufe 0) oder Fähigkeit (Stufe 3), U = Upgrade, Esc schließt.

var spiel: Node
var zelle := Karte.KEINE

var _inhalt: VBoxContainer
var _stand := ""      # woraus die Tafel zuletzt gebaut wurde – neu bauen nur, wenn sich etwas ändert
var _truppen_knoepfe: Array[Button] = []
var _upgrade_knopf: Button


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	var kasten := StyleBoxFlat.new()
	kasten.bg_color = Color(0.1, 0.08, 0.14, 0.96)
	kasten.border_color = Color("7fe0ff")
	kasten.set_border_width_all(2)
	kasten.set_content_margin_all(10)
	add_theme_stylebox_override("panel", kasten)
	_inhalt = VBoxContainer.new()
	_inhalt.add_theme_constant_override("separation", 6)
	add_child(_inhalt)


func oeffne(z: Vector2i) -> void:
	if not spiel.fabriken.has(z):
		return
	zelle = z
	_stand = ""
	visible = true
	_baue()


func schliesse() -> void:
	visible = false
	zelle = Karte.KEINE


func taste(code: int) -> void:
	if not visible:
		return
	var index := [KEY_Q, KEY_W, KEY_E].find(code)
	if index >= 0 and index < _truppen_knoepfe.size() and not _truppen_knoepfe[index].disabled:
		_truppen_knoepfe[index].pressed.emit()
	elif code == KEY_U and _upgrade_knopf != null and not _upgrade_knopf.disabled:
		_upgrade_knopf.pressed.emit()


func _process(_delta: float) -> void:
	if not visible:
		return
	if not spiel.fabriken.has(zelle):
		schliesse()
		return
	_baue()


func _baue() -> void:
	var f: Dictionary = spiel.fabriken[zelle]
	var stufe := int(f.get("stufe", 0))
	var bauphase: bool = spiel.phase == 0
	var preise: Array[int] = Werte.KOSTEN_BATTERIE_STUFE if f["typ"] == "pilot" else Werte.KOSTEN_STUFE
	var naechste := stufe < preise.size()
	var kann_zahlen: bool = naechste and spiel.budget >= preise[stufe]
	var stand := "%s|%d|%s|%s|%s" % [f["typ"], stufe, bauphase, kann_zahlen, spiel.schilde.size()]
	if stand == _stand:
		_setze_ort()
		return
	_stand = stand
	for kind in _inhalt.get_children():
		_inhalt.remove_child(kind)
		kind.queue_free()
	_truppen_knoepfe = []
	_upgrade_knopf = null
	var d: Dictionary = Werte.EINHEITEN[f["typ"]]

	if f["typ"] == "pilot":
		_baue_batterie(stufe, bauphase, naechste, kann_zahlen)
		reset_size()
		_setze_ort()
		return

	_zeile("%s-Fabrik · Stufe %d" % [d["name"], stufe], 17, Color("ffe9a8"))
	_zeile("hält %d Truppen" % spiel.truppen_limit(zelle), 13, Color("a79fb3"))

	if stufe == 0:
		# Truppe wählen
		var reihe := HBoxContainer.new()
		reihe.add_theme_constant_override("separation", 6)
		_inhalt.add_child(reihe)
		for i in Werte.FABRIK_EINHEITEN.size():
			var typ: String = Werte.FABRIK_EINHEITEN[i]
			var b := _knopf(str(Werte.EINHEITEN[typ]["name"]))
			b.disabled = typ == f["typ"]
			b.pressed.connect(spiel.stelle_um.bind(zelle, typ))
			reihe.add_child(b)
			_truppen_knoepfe.append(b)
		if not bauphase:
			_zeile("In der Welle gilt das Umstellen für die nächste Truppe.", 12, Color("a79fb3"))

	# nächste Stufe
	if stufe < 2:
		var titel := "Spezialisieren" if stufe == 0 else "Stufe 2"
		_upgrade_knopf = _knopf("%s  –  %d" % [titel, Werte.KOSTEN_STUFE[stufe]])
		_upgrade_knopf.disabled = not bauphase or not kann_zahlen
		_upgrade_knopf.pressed.connect(spiel.werte_auf.bind(zelle))
		_inhalt.add_child(_upgrade_knopf)
		var wirkung := "Bleibt bei %s und hält drei statt zwei Truppen. Umstellen geht danach nicht mehr." % d["name"]
		if stufe == 1:
			wirkung = Werte.STUFE_2[f["typ"]]["text"]
		_zeile(wirkung, 12, Color("d8cfe6"))
	elif stufe == 2:
		# Stufe 3: eine Fähigkeit wählen
		_zeile("Stufe 3 – eine Fähigkeit wählen (%d):" % Werte.KOSTEN_STUFE[2], 13, Color("ffe9a8"))
		var wahl: Dictionary = Werte.STUFE_3[f["typ"]]
		var i := 0
		for kennung: String in wahl:
			var w: Dictionary = wahl[kennung]
			var b := _knopf(str(w["name"]))
			b.disabled = not bauphase or not kann_zahlen
			b.pressed.connect(spiel.werte_auf.bind(zelle, kennung))
			_inhalt.add_child(b)
			_truppen_knoepfe.append(b)
			_zeile(w["text"], 12, Color("d8cfe6"))
			_zeile("+ %s    – %s" % [w["stark"], w["schwach"]], 11, Color("a79fb3"))
			i += 1
	else:
		var w3: Dictionary = Werte.STUFE_3[f["typ"]][str(f.get("faehigkeit", ""))]
		_zeile(w3["name"], 14, Color("7fe0ff"))
		_zeile(w3["text"], 12, Color("d8cfe6"))
		_zeile("+ %s    – %s" % [w3["stark"], w3["schwach"]], 11, Color("a79fb3"))
	if naechste and not bauphase:
		_zeile("Ausbauen geht nur zwischen den Wellen.", 12, Color("a79fb3"))
	reset_size()
	_setze_ort()


## Batterie mit Pilotenfabrik: feste Stufen statt Truppenwahl.
func _baue_batterie(stufe: int, bauphase: bool, naechste: bool, kann_zahlen: bool) -> void:
	_zeile("Batterie mit Pilotenfabrik · Stufe %d" % stufe, 17, Color("ffe9a8"))
	_zeile("hält %d Piloten, %d bemannen die Batterie" % [spiel.truppen_limit(zelle), int(Werte.BATTERIE["plaetze"])], 13, Color("a79fb3"))
	for i in stufe:
		_zeile("✓ " + Werte.BATTERIE_STUFEN[i]["name"], 13, Color("7fe0ff"))
	if naechste:
		var s: Dictionary = Werte.BATTERIE_STUFEN[stufe]
		_upgrade_knopf = _knopf("Stufe %d: %s  –  %d" % [stufe + 1, s["name"], Werte.KOSTEN_BATTERIE_STUFE[stufe]])
		_upgrade_knopf.disabled = not bauphase or not kann_zahlen
		_upgrade_knopf.pressed.connect(spiel.werte_auf.bind(zelle))
		_inhalt.add_child(_upgrade_knopf)
		_zeile(s["text"], 12, Color("d8cfe6"))
		if not bauphase:
			_zeile("Ausbauen geht nur zwischen den Wellen.", 12, Color("a79fb3"))
	else:
		var b := _knopf("Schildfeld %s" % ("versetzen" if spiel.schilde.has(spiel.karte.paar[zelle]) else "wählen"))
		b.disabled = not bauphase
		b.pressed.connect(spiel.waehle_schildfeld.bind(zelle))
		_inhalt.add_child(b)
		_truppen_knoepfe.append(b)
		_zeile("Der Schild steht nur, solange die Batterie voll bemannt und nicht ausgefallen ist.", 12, Color("d8cfe6"))


## Neben die Fabrik setzen, ohne aus dem Bild zu ragen.
func _setze_ort() -> void:
	var feld := Vector2(zelle) * Werte.ZELLE + Vector2(0, Werte.KARTE_OBEN)
	var ort := feld + Vector2(Werte.ZELLE + 8, -8)
	if ort.x + size.x > 1272.0:
		ort.x = feld.x - size.x - 8
	ort.y = clampf(ort.y, Werte.KARTE_OBEN + 4.0, 676.0 - size.y)
	position = ort


func _zeile(text: String, groesse: int, farbe: Color) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", groesse)
	l.add_theme_color_override("font_color", farbe)
	l.custom_minimum_size.x = 340
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_inhalt.add_child(l)


func _knopf(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 14)
	return b
