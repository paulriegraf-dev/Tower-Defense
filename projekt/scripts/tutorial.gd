class_name Tutorial
extends CanvasLayer
## Tutorial (15.11.) im Stil von Terrain-Conquester: Sonde 7 meldet sich im Hologramm-Funkfenster und erklärt
## in einer echten Partie je Schritt EINEN Handgriff mit kurzem Warum. Ring und Pfeil zeigen auf die Kachel oder
## den Knopf, dann wartet das Tutorial, bis der Spieler es getan hat. Nur reine Hinweise haben „Weiter“,
## Handgriffe lassen sich überspringen. „Tutorial beenden“ geht jederzeit; danach läuft die Partie normal weiter.
## Beim Start des normalen Spiels fragt Sonde 7 zuerst, ob man das Tutorial möchte.

const BAU := 0                    # main.gd Phase.BAU
const KAMPF := 1                  # main.gd Phase.KAMPF
const TIPP_TEMPO := 55.0          # Zeichen je Sekunde
const HOLO := Color("6ee6ff")
const HOLO_TEXT := Color("c8f4ff")
const GRUND := Color(0.03, 0.10, 0.16, 0.9)
const SONDE := "res://assets/sprites/tutorial/sonde7.png"
const Stil := preload("res://scripts/ui/ui_stil.gd")
# Lichter im 96er-Porträt (wie in Terrain-Conquester): leuchten, solange Sonde 7 spricht
const LICHTER := [[35, 40, 6, Color("6cecfe")], [49, 50, 6, Color("ff4a5e")], [18, 43, 4, Color("ff4a5e")]]
# Feste Karte fürs Tutorial, damit die gezeigten Felder immer passen
const TUT_CHECKPOINTS := [[7, 3], [13, 6]]
const TUT_BASIS := Vector2i(18, 5)

var spiel: Node
var _schritte: Array = []
var _index := -1
var _gezeigt := 0.0
var _zeit := 0.0
var _merk: Dictionary = {}
var _frage := true                # zuerst: Tutorial ja oder nein?
var _aus := false

var _wurzel: Control
var _zeichner: Control
var _box: PanelContainer
var _bild: TextureRect
var _lichter: Control
var _name: Label
var _text: Label
var _hinweis: Label
var _fortschritt: Label
var _btn_weiter: Button
var _btn_skip: Button
var _btn_ende: Button
var _btn_nein: Button


func _ready() -> void:
	layer = 30
	_wurzel = Control.new()
	_wurzel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_wurzel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_wurzel)
	_zeichner = Control.new()
	_zeichner.set_anchors_preset(Control.PRESET_FULL_RECT)
	_zeichner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_zeichner.draw.connect(_zeichne_ziel)
	_wurzel.add_child(_zeichner)

	_hinweis = Label.new()
	_schrift(_hinweis, 18)
	_hinweis.add_theme_color_override("font_color", Color("ffe9a8"))
	_hinweis.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_hinweis.add_theme_constant_override("outline_size", 4)
	_wurzel.add_child(_hinweis)

	_box = PanelContainer.new()
	var stil := StyleBoxFlat.new()
	stil.bg_color = GRUND
	stil.border_color = HOLO
	stil.set_border_width_all(2)
	stil.set_corner_radius_all(6)
	stil.set_content_margin_all(10)
	stil.shadow_color = Color(0.43, 0.9, 1.0, 0.35)
	stil.shadow_size = 8
	_box.add_theme_stylebox_override("panel", stil)
	_box.custom_minimum_size = Vector2(640, 0)
	_box.mouse_filter = Control.MOUSE_FILTER_STOP
	_box.gui_input.connect(_box_klick)
	_wurzel.add_child(_box)

	var reihe := HBoxContainer.new()
	reihe.add_theme_constant_override("separation", 12)
	_box.add_child(reihe)
	_bild = TextureRect.new()
	_bild.texture = load(SONDE)
	_bild.custom_minimum_size = Vector2(96, 96)
	_bild.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_bild.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_bild.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_bild.mouse_filter = Control.MOUSE_FILTER_IGNORE
	reihe.add_child(_bild)
	_lichter = Control.new()
	_lichter.set_anchors_preset(Control.PRESET_FULL_RECT)
	_lichter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lichter.draw.connect(_zeichne_lichter)
	_bild.add_child(_lichter)

	var rechts := VBoxContainer.new()
	rechts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rechts.add_theme_constant_override("separation", 4)
	reihe.add_child(rechts)
	_name = Label.new()
	_name.text = "SONDE 7 · LEITSTELLE"
	_schrift(_name, 17)
	_name.add_theme_color_override("font_color", Color("9be9ff"))
	rechts.add_child(_name)
	_text = Label.new()
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size = Vector2(500, 66)
	_schrift(_text, 19)
	_text.add_theme_color_override("font_color", HOLO_TEXT)
	_text.add_theme_color_override("font_shadow_color", Color(0.43, 0.9, 1.0, 0.45))
	_text.add_theme_constant_override("shadow_offset_x", 0)
	_text.add_theme_constant_override("shadow_offset_y", 0)
	_text.add_theme_constant_override("shadow_outline_size", 4)
	rechts.add_child(_text)
	var knoepfe := HBoxContainer.new()
	knoepfe.add_theme_constant_override("separation", 8)
	rechts.add_child(knoepfe)
	_fortschritt = Label.new()
	_schrift(_fortschritt, 17)
	_fortschritt.add_theme_color_override("font_color", Color("7f98a6"))
	_fortschritt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	knoepfe.add_child(_fortschritt)
	_btn_ende = _knopf(knoepfe, "Tutorial beenden", false)
	_btn_ende.pressed.connect(beenden)
	_btn_nein = _knopf(knoepfe, "Direkt spielen", false)
	_btn_nein.pressed.connect(beenden)
	_btn_skip = _knopf(knoepfe, "Überspringen", false)
	_btn_skip.pressed.connect(_weiter)
	_btn_weiter = _knopf(knoepfe, "Weiter ▸", true)
	_btn_weiter.pressed.connect(_weiter)

	_schritte = _baue_schritte()
	_zeige_frage()


## Pixelschrift (VT323) für ein Label/einen Knopf. `einheiten` = Größe im 1280×720-Raum; auf dem 25er-Raster scharf.
## Pixelschrift VT323 für Labels und Knöpfe. Immer die geglättete Fassung: Godot streckt Labels mit dem Fenster
## (z. B. ×1,5 bei 1080p), ungeglättet verlören die Buchstaben dabei Pixel („S“ wird zu „B“).
func _schrift(c: Control, einheiten: int) -> void:
	c.add_theme_font_override("font", Stil.schrift_fuer(1))   # 1 liegt nie im 25er-Raster: geglättete Fassung
	c.add_theme_font_size_override("font_size", einheiten)


func _knopf(eltern: Control, text: String, hell: bool) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	_schrift(b, 18)
	var s := StyleBoxFlat.new()
	s.bg_color = HOLO if hell else Color(0.43, 0.9, 1.0, 0.08)
	s.border_color = HOLO
	s.set_border_width_all(1)
	s.set_corner_radius_all(4)
	s.set_content_margin_all(5)
	s.content_margin_left = 10
	s.content_margin_right = 10
	b.add_theme_stylebox_override("normal", s)
	var h := s.duplicate() as StyleBoxFlat
	h.bg_color = HOLO.lightened(0.2) if hell else Color(0.43, 0.9, 1.0, 0.22)
	b.add_theme_stylebox_override("hover", h)
	b.add_theme_stylebox_override("pressed", h)
	b.add_theme_color_override("font_color", Color("08130f") if hell else HOLO_TEXT)
	b.add_theme_color_override("font_hover_color", Color("08130f") if hell else Color.WHITE)
	eltern.add_child(b)
	return b


# ------------------------------------------------------------------ Ablauf

func _zeige_frage() -> void:
	_frage = true
	_setze_text("Kommandant, hier Sonde 7 von der Leitstelle. Die Myriaden rücken an. Soll ich dir in einer echten Partie Schritt für Schritt zeigen, wie du dich verteidigst? Danach spielst du einfach weiter.")
	_fortschritt.text = ""
	_hinweis.text = ""
	_btn_weiter.text = "Tutorial starten ▸"
	_btn_weiter.visible = true
	_btn_nein.visible = true
	_btn_skip.visible = false
	_btn_ende.visible = false


func _starte() -> void:
	_frage = false
	_btn_weiter.text = "Weiter ▸"
	_btn_nein.visible = false
	_btn_ende.visible = true
	# feste Karte: Checkpoints und Basis stehen immer gleich, damit die gezeigten Felder passen
	spiel.setze_checkpoints(TUT_CHECKPOINTS)
	spiel._protokoll["checkpoints"] = TUT_CHECKPOINTS.duplicate(true)
	spiel.setze_basis(TUT_BASIS)
	spiel._protokoll["tutorial"] = true
	_naechster()


func _weiter() -> void:
	if _frage:
		_starte()
		return
	_naechster()


func _naechster() -> void:
	if _index >= _schritte.size() - 1:
		Profil.setze_einstellung("tutorial_fertig", true)   # 19.11.: bis zum Ende durchgespielt (Erfolg „Ausbilder“)
		beenden()
		return
	_index += 1
	_merk = {}
	var s: Dictionary = _schritte[_index]
	if s.has("start"):
		(s["start"] as Callable).call()
	_setze_text(str(s["text"]))
	var handgriff := s.has("fertig")
	_btn_weiter.visible = not handgriff
	_btn_skip.visible = false   # nur, wenn der Handgriff gerade nicht geht (siehe "kann" in _process)
	# Statt „Schritt 3 / 33“ nur das Thema: Orientierung, ohne mit der Gesamtlänge abzuschrecken (21.11.)
	for k in range(_index, -1, -1):
		if (_schritte[k] as Dictionary).has("thema"):
			_fortschritt.text = str(_schritte[k]["thema"])
			break


func beenden() -> void:
	if _aus:
		return
	_aus = true
	if spiel != null and not _frage:
		spiel.melde("Tutorial beendet – die Partie läuft normal weiter. [I] Übersicht und [H] Formationen helfen jederzeit.", 6.0)
	if spiel != null:
		spiel.tutorial = null
	queue_free()


## Darf die Welle gerade nicht starten? (vor der Antwort auf die Frage und bei Schritten mit "sperre")
func sperrt_welle() -> bool:
	if _aus:
		return false
	if _frage:
		return true
	# Streng Schritt für Schritt (15.11.): Die Welle startet nur in den Schritten, die genau das verlangen.
	return not (_index >= 0 and _index < _schritte.size() and bool((_schritte[_index] as Dictionary).get("welle", false)))


func _setze_text(t: String) -> void:
	_text.text = t
	_text.visible_characters = 0
	_gezeigt = 0.0


func _box_klick(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		_gezeigt = INF   # Text sofort ganz zeigen


func _process(delta: float) -> void:
	if _aus:
		return
	var echt := delta / maxf(Engine.time_scale, 0.01)   # Tippen und Blinken laufen unabhängig vom Spieltempo
	_zeit += echt
	if _gezeigt < INF:
		_gezeigt += TIPP_TEMPO * echt
	_text.visible_characters = -1 if _gezeigt >= _text.text.length() else int(_gezeigt)
	if not _frage and _index >= 0:
		var s: Dictionary = _schritte[_index]
		if s.has("fertig") and (s["fertig"] as Callable).call():
			_naechster()
			return
		_btn_skip.visible = s.has("kann") and not (s["kann"] as Callable).call()
		var h: Variant = s.get("hinweis", "")
		_hinweis.text = (h as Callable).call() if h is Callable else str(h)
	_lege_box()
	_zeichner.queue_redraw()
	_lichter.queue_redraw()
	# Hologramm-Flackern
	_bild.modulate = Color(0.75, 0.95, 1.15, 0.82 if fmod(_zeit, 3.2) < 3.05 else 0.6)


## Fenster unten mittig – liegt das Ziel unten, rutscht es nach oben.
func _lege_box() -> void:
	_box.reset_size()
	var groesse := _box.size
	var y := 620.0 - groesse.y - 10.0   # über der Konsole (neue Oberfläche, 16.11.)
	var ziel := _ziel_rect()
	if ziel.size != Vector2.ZERO and ziel.end.y > y - 30.0:
		y = 92.0   # unter den Inseln oben
	_box.position = Vector2((1280.0 - groesse.x) / 2.0, y)
	_hinweis.position = _box.position + (Vector2(12, groesse.y + 4) if y < 100.0 else Vector2(12, -22))
	_hinweis.visible = _hinweis.text != ""


func _ziel_rect() -> Rect2:
	if _frage or _index < 0:
		return Rect2()
	var s: Dictionary = _schritte[_index]
	if not s.has("ziel"):
		return Rect2()
	var r: Variant = (s["ziel"] as Callable).call()
	return r if r is Rect2 else Rect2()


func _zeichne_ziel() -> void:
	var r := _ziel_rect()
	if r.size == Vector2.ZERO:
		return
	var puls := 0.5 + 0.5 * sin(_zeit * 5.0)
	var aussen := r.grow(4.0 + 4.0 * puls)
	_zeichner.draw_rect(aussen, Color(HOLO, 0.25 + 0.35 * puls), false, 3.0)
	_zeichner.draw_rect(r.grow(2.0), Color(HOLO, 0.9), false, 2.0)
	# Pfeil: über dem Ziel, oder darunter, wenn oben kein Platz ist
	var oben := r.position.y > 90.0
	var spitze := Vector2(r.get_center().x, (r.position.y - 6.0 - 6.0 * puls) if oben else (r.end.y + 6.0 + 6.0 * puls))
	var d := -1.0 if oben else 1.0
	var pfeil := PackedVector2Array([spitze, spitze + Vector2(-11, 16 * d), spitze + Vector2(11, 16 * d)])
	_zeichner.draw_colored_polygon(pfeil, HOLO)
	_zeichner.draw_polyline(PackedVector2Array([pfeil[0], pfeil[1], pfeil[2], pfeil[0]]), Color(0, 0, 0, 0.6), 1.5)


func _zeichne_lichter() -> void:
	var spricht := _gezeigt < _text.text.length()
	var f := _bild.size.x / 96.0
	for l: Array in LICHTER:
		var staerke := (0.35 + 0.65 * absf(sin(_zeit * 11.0 + float(l[0])))) if spricht else 0.25
		var c: Color = l[3]
		_lichter.draw_circle(Vector2(float(l[0]), float(l[1])) * f, float(l[2]) * f * 1.6, Color(c, 0.22 * staerke))
		_lichter.draw_circle(Vector2(float(l[0]), float(l[1])) * f, float(l[2]) * f * 0.8, Color(c, 0.55 * staerke))


# ------------------------------------------------------------------ Hilfen für die Schritte

func _feld(z: Vector2i, r: float = 0.5) -> Rect2:
	var m: Vector2 = spiel.welt_zu_bild(spiel.karte.mitte(z))   # HD-2D: über die 3D-Kamera
	var h := r * Werte.ZELLE
	return Rect2(m - Vector2(h, h), Vector2(h, h) * 2.0)


## Knöpfe oben rechts (18.11.): 0 = Schadensliste [Tab], 1 = Formationen [H], 2 = Übersicht [I].
func _oben(i: int) -> Rect2:
	var hud = spiel.get("_hud")
	if hud == null or i >= (hud._oben_rechts as Array).size():
		return Rect2()
	var b: Control = hud._oben_rechts[i]
	return b.get_global_rect() if b.is_visible_in_tree() else Rect2()


## Die Turmformen über der Bauleiste (nur sichtbar, solange das Turm-Werkzeug gewählt ist).
func _formen_rect() -> Rect2:
	var hud = spiel.get("_hud")
	if hud == null or hud._formen == null or not (hud._formen as Control).is_visible_in_tree():
		return _knopf_von(Karte.TURM)
	return (hud._formen as Control).get_global_rect()


func _knopf_von(typ: int) -> Rect2:
	var b: Button = spiel._knoepfe.get(typ)
	return b.get_global_rect() if b != null else Rect2()


func _anzahl_waelle() -> int:
	var n := 0
	for z: Vector2i in spiel.karte.feld:
		if spiel.karte.feld[z] == Karte.WALL:
			n += 1
	return n


func _hat_ausbau(typ: int) -> bool:
	return spiel.karte.ausbau.values().has(typ)


func _erster_ausbau(typ: int) -> Vector2i:
	for z: Vector2i in spiel.karte.ausbau:
		if spiel.karte.ausbau[z] == typ:
			return z
	return Karte.KEINE


func _erste_fabrik() -> Vector2i:
	for z: Vector2i in spiel.fabriken:
		if str(spiel.fabriken[z].get("typ", "")) != "pilot":
			return z
	return Karte.KEINE


func _anzahl_fabriken() -> int:
	var n := 0
	for z: Vector2i in spiel.fabriken:
		if str(spiel.fabriken[z].get("typ", "")) != "pilot":
			n += 1
	return n


func _zweite_fabrik() -> Vector2i:
	var erste := _erste_fabrik()
	for z: Vector2i in spiel.fabriken:
		if z != erste and str(spiel.fabriken[z].get("typ", "")) != "pilot":
			return z
	return Karte.KEINE


func _blanker_wall() -> Vector2i:
	for z: Vector2i in spiel.karte.feld:
		if spiel.karte.feld[z] == Karte.WALL and not spiel.karte.ausbau.has(z):
			return z
	return Karte.KEINE


func _menue_offen(turm: bool = false) -> bool:
	var m: Fabrikmenue = spiel._fabrikmenue
	if not m.visible:
		return false
	return (spiel.karte.ausbau.get(m.zelle, Karte.FREI) == Karte.TURM) == turm


## Ein Wegfeld der Gegner etwa in Kartenmitte (für Erdwälle und den Turm).
func _wegfeld() -> Vector2i:
	if _merk.has("weg"):
		return _merk["weg"]
	var bestes := Vector2i(10, 4)
	var beste := 999
	for z: Vector2i in spiel.karte.pfad:
		if z.x < Werte.ZONE_SPALTEN + 2 or spiel.karte.checkpoints.has(z):
			continue
		var d := absi(z.x - 10)
		if d < beste:
			beste = d
			bestes = z
	_merk["weg"] = bestes
	return bestes


## Freies Feld zwei Felder neben dem Gegnerweg, nahe der Kartenmitte: dort steht die erste Fabrik gut.
func _fabrikplatz() -> Vector2i:
	if _merk.has("fabrik"):
		return _merk["fabrik"]
	var weg: Array = spiel.karte.pfad
	var bestes := Vector2i(10, 7)
	var beste := INF
	for y in Werte.ZEILEN:
		for x in range(Werte.ZONE_SPALTEN + 4, Werte.SPALTEN - 2):
			var z := Vector2i(x, y)
			if spiel.bau_hindernis(z, Karte.FABRIK) != "":
				continue
			var nah := 99
			for w: Vector2i in weg:
				nah = mini(nah, maxi(absi(w.x - z.x), absi(w.y - z.y)))
			if nah != 2:
				continue
			var wert := absf(x - 11.0) + 0.3 * absf(y - 5.0)
			if wert < beste:
				beste = wert
				bestes = z
	_merk["fabrik"] = bestes
	return bestes


# ------------------------------------------------------------------ Die Schritte

func _baue_schritte() -> Array:
	var p: Node = spiel
	return [
		# --- Spielprinzip
		{"thema": "Spielprinzip", "text": "So läuft es: Links liegt die Zone der Myriaden, geschützt von ihrem Schild. Von dort ziehen ihre Trupps zu deiner Basis rechts. Jeder Gegner, der sie erreicht, kostet dich ein Leben – du hast 15.",
			"ziel": func(): return _feld(p.karte.basis, 0.6)},
		{"text": "Die gepunktete Linie zeigt den Weg der nächsten Welle: immer der kürzeste, und immer erst über Checkpoint 1, dann über Checkpoint 2. Wie dieser Weg verläuft, bestimmst gleich du.",
			"ziel": func(): return _feld(p.karte.checkpoints[0], 0.6)},
		{"text": "20 Runden musst du halten. In Runde 20 drehst du den Spieß um: Dann greifen deine Truppen das HQ der Myriaden an, während deren Wellen ohne Ende weiterlaufen.",
			},
		# --- Fabrik und Truppen
		{"thema": "Fabriken und Truppen", "text": "Deine Truppen kommen aus Fabriken – Türme allein reichen hier nicht. Wähle unten die Fabrik.",
			"hinweis": "Taste 1 · oder Klick unten auf „Fabrik“",
			"ziel": func(): return _knopf_von(Karte.FABRIK),
			"fertig": func(): return p.werkzeug == Karte.FABRIK or not p.fabriken.is_empty()},
		{"text": "Setz sie auf das markierte Feld, nah am Weg der Gegner. Fabriken versperren auch den Weg – die Gegner gehen außen herum.",
			"hinweis": "Linksklick aufs Feld · Rechtsklick bricht ab",
			"ziel": func(): return _feld(_fabrikplatz()) if p.werkzeug == Karte.FABRIK else _knopf_von(Karte.FABRIK),
			"fertig": func(): return not p.fabriken.is_empty()},
		{"text": "Eine Fabrik hält 2 Truppen und ersetzt Gefallene laufend. Klick sie an – dort wählst du, was sie baut.",
			"hinweis": "Linksklick auf deine Fabrik",
			"ziel": func(): return _feld(_erste_fabrik()) if _erste_fabrik() != Karte.KEINE else Rect2(),
			"fertig": func(): return _menue_offen()},
		{"text": "Drei Truppen: Technogunner (robust, schnell), Scharfschütze (große Reichweite, langsamer Schuss) und Plasmawerfer (Flächenschaden auf kurze Distanz). Solange die Fabrik nicht ausgebaut ist, kannst du jederzeit umstellen.",
			"ziel": func(): return (p._fabrikmenue as Control).get_global_rect() if _menue_offen() else Rect2()},
		{"text": "Eine Fabrik allein hält nicht lange. Bau eine zweite – jede weitere kostet 25 % mehr als die vorige, der Preis steht unten am Knopf.",
			"hinweis": "Taste 1 · Fabrik, dann aufs markierte Feld",
			"ziel": func(): return _feld(_fabrikplatz()) if p.werkzeug == Karte.FABRIK else _knopf_von(Karte.FABRIK),
			"kann": func(): return p.budget >= p.kosten(Karte.FABRIK),
			"fertig": func(): return _anzahl_fabriken() >= 2},
		{"text": "Mischen lohnt sich: Klick die neue Fabrik an und stell sie auf Scharfschütze. Er trifft von weit hinten – am besten später aus einer Stellung.",
			"hinweis": "Linksklick auf die neue Fabrik · „Scharfschütze“",
			"ziel": func(): return (p._fabrikmenue as Control).get_global_rect() if _menue_offen() else (_feld(_zweite_fabrik()) if _zweite_fabrik() != Karte.KEINE else Rect2()),
			"kann": func(): return _zweite_fabrik() != Karte.KEINE,
			"fertig": func():
				for z: Vector2i in p.fabriken:
					if str(p.fabriken[z].get("typ", "")) != "technogunner" and str(p.fabriken[z].get("typ", "")) != "pilot":
						return true
				return false},
		# --- Erste Welle
		{"thema": "Die erste Welle", "text": "Bereit. Starte jetzt die erste Welle. Deine Truppen laufen den Gegnern selbst entgegen und kämpfen, sobald sie sie sehen.",
			"hinweis": "Leertaste · oder Klick auf „Start“",
			"ziel": func(): return (p._btn_start as Control).get_global_rect(),
			"fertig": func(): return p.phase == KAMPF, "welle": true},
		{"text": "Mit [F] schaltest du das Tempo auf ×2 oder ×3. Oben siehst du Budget und Leben. Nach jeder Welle gibt es Geld – dazu Zinsen: je 100 Budget, das du übrig lässt, 10 mehr (bis 50). Sparen lohnt sich also.",
			"hinweis": "Taste F · Tempo",
			"fertig": func(): return p.phase == BAU and p.welle >= 2},
		# --- Erdwälle und Stellungen
		{"thema": "Erdwälle und Stellungen", "text": "Ab Runde 2 formst du das Gelände: Erdwälle lenken den Weg. Je länger der Weg, desto länger stehen die Gegner unter Beschuss. Die ersten 8 Erdwälle sind gratis – setz 3 auf oder neben die Linie.",
			"hinweis": func(): return "Taste 2 · Erdwall – Erdwälle: %d / 3" % mini(_anzahl_waelle(), 3),
			"ziel": func(): return _feld(_wegfeld(), 1.5) if p.werkzeug == Karte.WALL else _knopf_von(Karte.WALL),
			"start": func(): _merk["w0"] = _anzahl_waelle(),
			"fertig": func(): return _anzahl_waelle() >= int(_merk.get("w0", 0)) + 3},
		{"text": "Sieh auf die Linie: Der Weg hat sich geändert. Sperrst du ihn ganz zu, reißen die Gegner den Wall ein, der ihnen im Weg steht – also lieber lange Umwege bauen als Mauern.",
			},
		{"text": "Auf einem Erdwall baust du eine Stellung. Eine Truppe steigt hinauf, sieht über Wälle hinweg und hat mehr Reichweite. Bau eine Stellung auf einen deiner Erdwälle.",
			"hinweis": "Taste 3 · Stellung, dann Klick auf einen Erdwall",
			"ziel": func(): return (_feld(_blanker_wall()) if _blanker_wall() != Karte.KEINE else Rect2()) if p.werkzeug == Karte.STELLUNG else _knopf_von(Karte.STELLUNG),
			"fertig": func(): return _hat_ausbau(Karte.STELLUNG)},
		{"text": "Stellungen werden automatisch besetzt und aufgefüllt, wenn dort jemand fällt – aber nur, wenn der Weg dorthin frei ist. Du kannst sie sogar während einer Welle bauen. Starte Welle 2.",
			"hinweis": "Leertaste · Start",
			"ziel": func(): return (p._btn_start as Control).get_global_rect(),
			"fertig": func(): return p.phase == KAMPF, "welle": true},
		{"text": "Klick während der Welle auf eine Truppe: Dann siehst du ihre Reichweite – und dunkel, wohin sie nicht schießen kann, weil Wälle die Sicht versperren.",
			"hinweis": "Linksklick auf eine Truppe",
			"fertig": func(): return p.phase == BAU and p.welle >= 3},
		# --- Formtürme
		# 18.11. (Paul): Die Turmformen zeigt das Turm-Werkzeug [4], nicht die Formationen [H].
		{"thema": "Türme", "text": "Türme entstehen aus der Form deiner Erdwälle. Welche Form welchen Turm trägt, siehst du, sobald du das Turm-Werkzeug wählst. Drück 4.",
			"hinweis": "Taste 4 · Turm",
			"ziel": func(): return _knopf_von(Karte.TURM),
			"fertig": func(): return p.werkzeug == Karte.TURM},
		{"text": "T-Stück = Geschütz, Kreuzung = Funkturm, lange Ecke = Frost, Klammer = Lanze, Treppe = Heilturm. Klickst du eine Form an, hängt sie als Vorlage an der Maus. Alle Erdwälle der Form sind Stützen: Fällt einer, schweigt der Turm. Leg das Werkzeug mit Rechtsklick wieder ab.",
			"hinweis": "Rechtsklick · Werkzeug ablegen",
			"ziel": func(): return _formen_rect(),
			"fertig": func(): return p.werkzeug == Karte.FREI},
		{"text": "Ganze Aufstellungen für die Karte – lange Schläuche, Kämme, Zitadellen – zeigt dir die Formationen-Karte oben rechts. Öffne sie.",
			"hinweis": "Taste H · Formationen",
			"ziel": func(): return _oben(1),
			"fertig": func(): return p._nachschlag.visible},
		{"text": "Links wählst du eine Formation, rechts siehst du sie auf deiner Karte – mit Stärken und Schwächen. Schließ sie wieder mit H.",
			"hinweis": "Taste H · schließen",
			"fertig": func(): return not p._nachschlag.visible},
		{"text": "Bau einen Turm: Setz Erdwälle zu einem T – ein Wall mit drei Nachbarn – und dann den Turm auf den mittleren. Komische Wallformen sind hier ausdrücklich erwünscht.",
			"hinweis": "Taste 2 · Erdwälle, dann Taste 4 · Turm auf den Wall in der Mitte",
			"ziel": func(): return _feld(_wegfeld(), 1.5),
			"kann": func(): return p.budget >= Werte.KOSTEN_TURM,
			"fertig": func(): return _hat_ausbau(Karte.TURM)},
		{"text": "Klick deinen Turm an. Dort siehst du seine Werte über die ganze Partie und baust ihn aus: Stufe 2 fest, auf Stufe 3 wählst du eine von zwei Fähigkeiten.",
			"hinweis": "Linksklick auf den Turm",
			"ziel": func(): return _feld(_erster_ausbau(Karte.TURM)) if _hat_ausbau(Karte.TURM) else Rect2(),
			"fertig": func(): return _menue_offen(true)},
		# --- Upgrades
		{"thema": "Upgrades", "text": "Auch Fabriken wachsen: Stufe 1 legt sie auf eine Truppe fest und gibt eine dritte. Stufe 2 bringt ein Wertepaket, Stufe 3 eine Fähigkeit zur Wahl, die verändert, wie die Truppe kämpft. Bau deine Fabrik auf Stufe 1 aus.",
			"hinweis": "Fabrik anklicken · Knopf „Stufe 1“",
			"ziel": func(): return (p._fabrikmenue as Control).get_global_rect() if _menue_offen() else (_feld(_erste_fabrik()) if _erste_fabrik() != Karte.KEINE else Rect2()),
			"kann": func(): return p.budget >= Werte.KOSTEN_STUFE[0],
			"fertig": func():
				for z: Vector2i in p.fabriken:
					if int(p.fabriken[z].get("stufe", 0)) >= 1:
						return true
				return false},
		{"text": "Im Fabrikmenü stellst du auch die Zielwahl ein: Erste, Letzte oder Stärkste. Und zieh mit der Maus von der Fabrik auf eine Stellung, um sie fest für diese Fabrik zu reservieren."},
		# --- Weitere Bauwerke
		{"thema": "Weitere Bauwerke", "text": "Weitere Bauwerke: Das Tor [6] lässt nur deine Truppen durch die Mauer. Die Panzerung [7] schützt einen Erdwall vor der ersten Sprengung – die Myriaden haben Sprenger.",
			"ziel": func(): return _knopf_von(Karte.TOR)},
		{"text": "Die Batterie [5] feuert weit und über Wälle auf Gruppen – aber nur, wenn ihre drei Piloten an Bord sind. Die kommen aus der angebauten Pilotenfabrik. Ihr Menü hat eigene Stufen, bis hin zu einem Energieschild auf dem Weg.",
			"ziel": func(): return _knopf_von(Karte.BATTERIE)},
		{"text": "Und dann ist da Kommandant Brakk [8]: einmal pro Partie, du steuerst ihn mit W A S D. Q sammelt Truppen und schlägt los, E klettert auf einen Wall, R stellt die Klonmaschine auf.",
			"ziel": func(): return _knopf_von(Karte.KOMMANDANT)},
		# --- Checkpoints und Gegner
		{"thema": "Checkpoints und Gegner", "text": "Ab Runde 5 nehmen die Gegner die Checkpoints ein, wenn sie dort stehen bleiben. Ein verlorener Checkpoint ist gefährlich: Die nächste Welle startet dort! Eine deiner Truppen geht ihn zurückholen, sobald es ruhig ist.",
			"ziel": func(): return _feld(p.karte.checkpoints[1], 0.6)},
		{"text": "Oben steht immer, was als Nächstes kommt. Bevor eine neue Gegnerart auftaucht, kündige ich sie an. Alles über Gegner, Truppen und Bauten steht in der Übersicht. Öffne sie.",
			"hinweis": "Taste I · Übersicht",
			"ziel": func(): return _oben(2),
			"fertig": func(): return p._lexikon.visible},
		{"text": "Hier findest du jederzeit alle Werte und was gegen wen hilft. Schließ die Übersicht wieder mit I.",
			"hinweis": "Taste I · schließen",
			"fertig": func(): return not p._lexikon.visible},
		{"text": "Drück [Tab] oder den Knopf oben rechts: Die Schadensliste zeigt, welche Fabrik, welcher Turm und welche Batterie wie viel geleistet hat. Nochmal [Tab] schließt sie. Ein Klick auf einen Turm oder eine Batterie zeigt ihre Werte über die ganze Partie.",
			"ziel": func(): return _oben(0)},
		# --- Abschluss
		{"thema": "Abschluss", "text": "Das war's. Abreißen geht mit Rechtsklick – was du in derselben Bauphase gebaut hast, gibt es voll zurück. Den Rest lernst du im Gefecht. Viel Erfolg, Kommandant. Sonde 7 Ende."},
	]
