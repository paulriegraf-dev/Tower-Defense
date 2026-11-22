class_name Lexikon
extends Control
## Übersicht [I] (16.11.2026, neuer Stil nach dem Vorbild von Bloons TD 6): Kartenraster links, Reiter unten
## (Gegner, Truppen, Bauten, Regeln), rechts die Tafel zur gewählten Karte mit laufender Figur. Truppen, Türme und
## Batterie haben einen anklickbaren Ausbaupfad: jede Stufe zeigt, wie die Einheit dann aussieht, was sie bewirkt,
## was sie kostet, Stärken (grün) und Schwächen (rot). Zahlen kommen aus werte.gd und stimmen deshalb immer.
## Gezeichnet im UI-Raster (640×360, zweifach skaliert) mit ui_stil.gd. Alte Fassung: _vor_uebersicht/lexikon.gd.

const Stil := preload("res://scripts/ui/ui_stil.gd")
## 20.11. (Paul, Nachtrag): oben zwei große Reiter „Normalmodus“ und „Brakk-Mode“ mit eigener Leuchtfarbe, unten ihre
## Unterreiter. Geöffnet wird der Modus der laufenden Partie. Je Unterreiter eine Liste in _daten (gleiche Reihenfolge).
const REITER := ["Gegner", "Truppen", "Bauten", "Regeln", "Anführer", "Brakk", "Irrtürmer", "Sonde 7", "Ringe"]
const MODI := [[0, 1, 2, 3, 4], [5, 6, 7, 8]]
const MODUS_NAME := ["Normalmodus", "Brakk-Mode"]
const MODUS_FARBE := [Color("7fe0ff"), Color("ff9a3d")]
const MODUS_R := [Rect2(108, 11, 92, 20), Rect2(204, 11, 92, 20)]
const RAHMEN_R := Rect2(8, 8, 624, 344)
const GITTER := Rect2(14, 36, 312, 282)
const SPALTEN := 4
const TAFEL_R := Rect2(332, 36, 294, 310)
const SCHLIESSEN := Rect2(604, 13, 20, 17)
const KNOTEN := 34.0          # Kantenlänge eines Knotens im Ausbaupfad
const KNOTEN_SCHRITT := 44.0
const GUT := Color("8dff8a")
const SCHLECHT := Color("ff8a7a")

var _reiter := 0
var _wahl: Array[int] = [0, 0, 0, 0, 0, 0, 0, 0, 0]   # 20.11. (Nachtrag): neun Unterreiter
var _modus := 0                # 0 = Normalmodus, 1 = Brakk-Mode
var _letzter := [0, 5]         # zuletzt gewählter Unterreiter je Modus
var _knoten := {}             # Name des Eintrags -> gewählter Knoten im Ausbaupfad
var _maus := Vector2(-100, -100)
var _zeit := 0.0
var _daten: Array = []        # je Reiter eine Liste von Einträgen
var _bilder := {}
var _textfeld: Textfeld
var _scroll := 0.0
var _text_hoehe := 0.0


## Textbereich der Tafel: schneidet ab, das Mausrad scrollt.
class Textfeld extends Control:
	var malen: Callable
	func _draw() -> void:
		if malen.is_valid():
			malen.call(self)


func _ready() -> void:
	size = Vector2(640, 360)
	scale = Vector2(Stil.UI_SKALA, Stil.UI_SKALA)
	mouse_filter = Control.MOUSE_FILTER_STOP   # solange die Übersicht offen ist, wird nicht versehentlich gebaut
	process_mode = Node.PROCESS_MODE_ALWAYS   # 19.11.: läuft weiter, während das Spiel steht
	visibility_changed.connect(_sichtbar_geaendert)
	visible = false
	_textfeld = Textfeld.new()
	_textfeld.clip_contents = true
	_textfeld.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_textfeld.malen = _male_text
	add_child(_textfeld)
	_baue_daten()


func umschalten() -> void:
	visible = not visible
	queue_redraw()


## 19.11. (Paul): Solange die Übersicht offen ist, steht die Zeit (alle Modi, auch der Bauzeit-Countdown).
var _pausiert_von_mir := false

func _sichtbar_geaendert() -> void:
	if visible:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE   # Ego-Sicht: Maus frei, solange die Übersicht offen ist (danach fängt die Ego-Sicht sie wieder)
		# 20.11. (Nachtrag): neu aufbauen (Freischaltungen) und den Modus der laufenden Partie öffnen
		_baue_daten()
		var sp := get_tree().current_scene
		_waehle_modus(1 if sp != null and bool(sp.get("brakk_modus")) else 0)
	if visible and not get_tree().paused:
		get_tree().paused = true
		_pausiert_von_mir = true
	elif not visible and _pausiert_von_mir:
		_pausiert_von_mir = false
		get_tree().paused = false


func _process(delta: float) -> void:
	if visible:
		_zeit += delta
		var r := _text_recht()
		_textfeld.position = r.position
		_textfeld.size = r.size
		queue_redraw()
		_textfeld.queue_redraw()


# ------------------------------------------------------------------ Eingabe

## 19.11. (Paul): Esc, [I] und Rechtsklick schließen die Übersicht. Hier statt in main.gd, weil das Spiel steht, solange
## sie offen ist (main bekommt dann keine Tasten), und weil in der Ego-Sicht die Maus gefangen ist.
func _input(event: InputEvent) -> void:
	if not visible:
		return
	var zu := false
	if event is InputEventKey and event.pressed and not event.echo:
		zu = (event as InputEventKey).keycode in [KEY_ESCAPE, KEY_I]
	elif event is InputEventMouseButton and event.pressed:
		zu = (event as InputEventMouseButton).button_index == MOUSE_BUTTON_RIGHT
	if zu:
		visible = false
		get_viewport().set_input_as_handled()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_maus = event.position
		## 18.11.: Ziehen mit gedrückter Taste scrollt den Text – am Handy (Finger) und Touchpad ohne Mausrad.
		var mm := event as InputEventMouseMotion
		if mm.button_mask & MOUSE_BUTTON_MASK_LEFT and TAFEL_R.has_point(mm.position):
			_scroll -= mm.relative.y
	elif event is InputEventMouseButton and event.pressed:
		var p: Vector2 = event.position
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN or event.button_index == MOUSE_BUTTON_WHEEL_UP:
			if TAFEL_R.has_point(p):
				_scroll += 14.0 if event.button_index == MOUSE_BUTTON_WHEEL_DOWN else -14.0
			return
		if event.button_index == MOUSE_BUTTON_RIGHT:
			visible = false
			return
		if event.button_index != MOUSE_BUTTON_LEFT:
			return
		if SCHLIESSEN.has_point(p):
			visible = false
			return
		for m in 2:
			if (MODUS_R[m] as Rect2).has_point(p):
				_waehle_modus(m)   # 20.11. (Nachtrag)
				return
		for i: int in MODI[_modus]:
			if _reiter_recht(i).has_point(p):
				_reiter = i
				_letzter[_modus] = i
				_scroll = 0.0
				return
		var liste: Array = _daten[_reiter]
		for i in liste.size():
			if _karten_recht(i).has_point(p):
				_wahl[_reiter] = i
				_scroll = 0.0
				return
		var e: Dictionary = liste[_wahl[_reiter]]
		var rechtecke := _knoten_rechtecke(e)
		for i in rechtecke.size():
			if (rechtecke[i] as Rect2).grow(2.0).has_point(p):
				_knoten[e["name"]] = i
				_scroll = 0.0
				return


# ------------------------------------------------------------------ Lage

func _karten_recht(i: int) -> Rect2:
	var n := (_daten[_reiter] as Array).size()
	var reihen := maxi(4, ceili(n / float(SPALTEN)))
	var w := (GITTER.size.x - 4.0 * (SPALTEN - 1)) / SPALTEN
	var h := floorf((GITTER.size.y - 4.0 * (reihen - 1)) / reihen)
	return Rect2(GITTER.position + Vector2((i % SPALTEN) * (w + 4.0), int(i / float(SPALTEN)) * (h + 4.0)), Vector2(w, h))


## Unterreiter unten – nur die des gewählten Modus, gleichmäßig auf die Breite des Rasters verteilt.
func _reiter_recht(i: int) -> Rect2:
	var liste: Array = MODI[_modus]
	var n := liste.size()
	var w := (GITTER.size.x - 4.0 * float(n - 1)) / float(n)
	return Rect2(GITTER.position.x + float(liste.find(i)) * (w + 4.0), 324.0, w, 22.0)


## 20.11. (Nachtrag): Modus wechseln – der zuletzt gewählte Unterreiter dieses Modus.
func _waehle_modus(m: int) -> void:
	_modus = m
	_reiter = int(_letzter[m])
	_scroll = 0.0


## Knoten des Ausbaupfads: erst die Stufen in einer Reihe, dann die Wahl auf Stufe 3 nebeneinander.
func _knoten_rechtecke(e: Dictionary) -> Array:
	var pfad: Array = e.get("pfad", [])
	var liste: Array = []
	var x := TAFEL_R.position.x + 10.0
	var y := TAFEL_R.position.y + 104.0
	var war_zweig := false
	for k: Dictionary in pfad:
		if k.get("zweig", false) and not war_zweig:
			x += 8.0   # Abstand vor der Gabelung
			war_zweig = true
		liste.append(Rect2(Vector2(x, y), Vector2(KNOTEN, KNOTEN)))
		x += KNOTEN_SCHRITT
	return liste


func _text_recht() -> Rect2:
	if _daten.is_empty():
		return Rect2()
	var e: Dictionary = _daten[_reiter][_wahl[_reiter]]
	var oben := TAFEL_R.position.y + (156.0 if e.has("pfad") else 96.0)
	return Rect2(TAFEL_R.position.x + 8.0, oben, TAFEL_R.size.x - 14.0, TAFEL_R.end.y - oben - 6.0)


# ------------------------------------------------------------------ Zeichnen

func _draw() -> void:
	draw_rect(Rect2(Vector2(-8, -8), size + Vector2(16, 16)), Color(0.02, 0.03, 0.05, 0.72))
	var mf: Color = MODUS_FARBE[_modus]
	Stil.platte(self, RAHMEN_R, 4.0, Stil.METALL_TIEF, mf.darkened(0.35))   # 20.11. (Nachtrag): Rahmen in der Farbe des Modus
	# Kopf
	Stil.symbol(self, "buch", Vector2(23, 21), 1.5, mf)
	Stil.schreibe(self, Vector2(34, 21), "Übersicht", Stil.GROSS, Stil.TEXT)
	for m in 2:
		# 20.11. (Nachtrag): zwei große Reiter oben, je mit eigener Leuchtfarbe
		var r: Rect2 = MODUS_R[m]
		var an := m == _modus
		var farbe: Color = MODUS_FARBE[m]
		var drueber := r.has_point(_maus)
		Stil.platte(self, r, 3.0, Color(farbe, 0.22) if an else Stil.METALL_DUNKEL, farbe if an else (farbe.darkened(0.3) if drueber else Stil.RAHMEN))
		if an:
			draw_rect(Rect2(r.position + Vector2(3, r.size.y - 3.0), Vector2(r.size.x - 6.0, 2)), farbe)
		Stil.schreibe_mittig(self, r.get_center(), MODUS_NAME[m], Stil.NORMAL, farbe if an or drueber else Stil.TEXT_BLASS)
	var tipp := "Karte anklicken · Mausrad scrollt · [I] schließt"
	Stil.schreibe(self, Vector2(SCHLIESSEN.position.x - 8.0 - Stil.breite(tipp, Stil.KLEIN), 21), tipp, Stil.KLEIN, Stil.TEXT_BLASS)
	var zu_an := SCHLIESSEN.has_point(_maus)
	Stil.platte(self, SCHLIESSEN, 2.0, Stil.METALL_DUNKEL, Stil.LEUCHT if zu_an else Stil.RAHMEN)
	var m := SCHLIESSEN.get_center().floor()
	for i in range(-3, 4):
		for d: Vector2 in [Vector2(1, 1), Vector2(1, -1)]:
			draw_rect(Rect2(m + d * float(i) - Vector2(1, 1), Vector2(2, 2)), Stil.LEUCHT if zu_an else Stil.TEXT)
	# Karten, Reiter, Tafel
	var liste: Array = _daten[_reiter]
	for i in liste.size():
		_zeichne_karte(_karten_recht(i), liste[i], i == _wahl[_reiter])
	for i: int in MODI[_modus]:
		_zeichne_reiter(i)
	_zeichne_tafel(liste[_wahl[_reiter]])


func _zeichne_karte(r: Rect2, e: Dictionary, gewaehlt: bool) -> void:
	var drueber := r.has_point(_maus)
	Stil.platte(self, r, 3.0, Stil.METALL if gewaehlt else Stil.METALL_DUNKEL, Stil.LEUCHT if gewaehlt else (Stil.RAHMEN_HELL if drueber else Stil.RAHMEN))
	var bildbox := Vector2(r.size.x - 10.0, r.size.y - 18.0)
	_male_bild(self, e["bild"], Vector2(r.get_center().x, r.position.y + 4.0 + bildbox.y), bildbox, drueber, true)
	Stil.schreibe_mittig(self, Vector2(r.get_center().x, r.end.y - 7.0), e["name"], Stil.KLEIN, Stil.TEXT if gewaehlt or drueber else Stil.TEXT_BLASS)
	if e.has("kachel_oben"):
		Stil.schreibe_mittig(self, Vector2(r.get_center().x, r.position.y + 8.0), str(e["kachel_oben"]), Stil.KLEIN, e.get("marke_farbe", Stil.TEXT_BLASS) if gewaehlt or drueber else Stil.TEXT_BLASS)


func _zeichne_reiter(i: int) -> void:
	var r := _reiter_recht(i)
	var an := i == _reiter
	var drueber := r.has_point(_maus)
	var mf: Color = MODUS_FARBE[_modus]
	Stil.platte(self, r, 3.0, Stil.METALL if an else Stil.METALL_DUNKEL, mf if an else (Stil.RAHMEN_HELL if drueber else Stil.RAHMEN))
	var name := str(REITER[i])
	var af := {6: "irrtuermer", 7: "sonde7"}.get(i, "") as String
	if af != "" and not Anfuehrer.frei(af):
		name = "?"   # 20.11. (Nachtrag): gesperrter Held
	Stil.schreibe_mittig(self, r.get_center(), name, Stil.NORMAL, mf if an else (Stil.TEXT if drueber else Stil.TEXT_BLASS))


func _gewaehlter_knoten(e: Dictionary) -> int:
	return clampi(int(_knoten.get(e["name"], 0)), 0, maxi(0, (e.get("pfad", []) as Array).size() - 1))


func _zeichne_tafel(e: Dictionary) -> void:
	Stil.platte(self, TAFEL_R, 4.0, Stil.METALL_DUNKEL, Stil.RAHMEN)
	var o := TAFEL_R.position
	var pfad: Array = e.get("pfad", [])
	var k := _gewaehlter_knoten(e)
	var bild: Dictionary = (pfad[k] as Dictionary)["bild"] if not pfad.is_empty() else e["bild"]
	# Sockel mit der laufenden Figur
	var sockel := Rect2(o + Vector2(6, 6), Vector2(84, 84))
	Stil.platte(self, sockel, 3.0, Stil.METALL_TIEF, Stil.RAHMEN)
	var boden := Vector2(sockel.get_center().x, sockel.end.y - 12.0)
	_ellipse(boden + Vector2(0, 1), Vector2(28, 6), Color(0, 0, 0, 0.45))
	_ellipse(boden, Vector2(26, 5), Color(Stil.LEUCHT, 0.18))
	_male_bild(self, bild, boden + Vector2(0, 2), Vector2(76, 74), true, false)
	# Name, Untertitel, Marke
	var x := o.x + 98.0
	Stil.schreibe(self, Vector2(x, o.y + 13.0), e["name"], Stil.GROSS, Stil.TEXT)
	var marke: String = e.get("marke", "")
	if marke != "":
		Stil.schreibe(self, Vector2(TAFEL_R.end.x - 8.0 - Stil.breite(marke, Stil.KLEIN), o.y + 29.0), marke, Stil.KLEIN, e.get("marke_farbe", Stil.GOLD))
	Stil.schreibe(self, Vector2(x, o.y + 29.0), e["unter"], Stil.KLEIN, Stil.TEXT_BLASS)
	# Werte als kleine Felder (bei einer Stufe mit eigenen Werten diese; Geändertes leuchtet grün)
	var werte: Array = e.get("werte", [])
	var vorher: Array = werte
	if not pfad.is_empty() and (pfad[k] as Dictionary).has("werte"):
		werte = (pfad[k] as Dictionary)["werte"]
	for i in mini(werte.size(), 6):
		var anders := i < vorher.size() and str(vorher[i][1]) != str(werte[i][1])
		var feld := Rect2(Vector2(x + (i % 3) * 64.0, o.y + 40.0 + int(i / 3.0) * 25.0), Vector2(61, 22))
		Stil.platte(self, feld, 2.0, Stil.METALL_TIEF, Stil.RAHMEN)
		Stil.schreibe(self, feld.position + Vector2(4, 6), str(werte[i][0]), Stil.KLEIN, Stil.TEXT_BLASS)
		Stil.schreibe(self, feld.position + Vector2(4, 15), str(werte[i][1]), Stil.NORMAL, GUT if anders else Stil.TEXT)
	if not pfad.is_empty():
		_zeichne_pfad(e, pfad, k)


func _zeichne_pfad(e: Dictionary, pfad: Array, gewaehlt: int) -> void:
	var rechtecke := _knoten_rechtecke(e)
	Stil.schreibe(self, Vector2(TAFEL_R.position.x + 10.0, TAFEL_R.position.y + 96.0), "Ausbau – Stufe anklicken", Stil.KLEIN, Stil.TEXT_BLASS)
	var letzter_gerader := 0
	for i in pfad.size():
		if not (pfad[i] as Dictionary).get("zweig", false):
			letzter_gerader = i
	var linie := Stil.RAHMEN_HELL
	for i in range(1, pfad.size()):
		var a: Rect2 = rechtecke[i - 1]
		var b: Rect2 = rechtecke[i]
		if (pfad[i] as Dictionary).get("zweig", false):
			# Gabelung: von der letzten Stufe eine Leiste unter allen Fähigkeiten entlang
			var q: Rect2 = rechtecke[letzter_gerader]
			var gy := q.end.y + 3.0
			draw_rect(Rect2(Vector2(q.end.x, q.get_center().y - 1.0), Vector2(5.0, 2.0)), linie)
			draw_rect(Rect2(Vector2(q.end.x + 4.0, q.get_center().y - 1.0), Vector2(2.0, gy - q.get_center().y + 1.0)), linie)
			draw_rect(Rect2(Vector2(q.end.x + 4.0, gy), Vector2(b.get_center().x - q.end.x - 4.0, 2.0)), linie)
			draw_rect(Rect2(Vector2(b.get_center().x - 1.0, b.end.y), Vector2(2.0, gy - b.end.y)), linie)
		else:
			draw_rect(Rect2(Vector2(a.end.x, a.get_center().y - 1.0), Vector2(b.position.x - a.end.x, 2.0)), linie)
	for i in pfad.size():
		var k: Dictionary = pfad[i]
		var r: Rect2 = rechtecke[i]
		var an := i == gewaehlt
		var drueber := r.grow(2.0).has_point(_maus)
		Stil.platte(self, r, 3.0, Stil.METALL if an else Stil.METALL_TIEF, Stil.LEUCHT if an else (Stil.RAHMEN_HELL if drueber else Stil.RAHMEN))
		_male_bild(self, k["bild"], Vector2(r.get_center().x, r.end.y - 2.0), r.size - Vector2(4, 4), false, true)
		Stil.schreibe_mittig(self, Vector2(r.get_center().x, r.end.y + 10.0), k["kurz"], Stil.KLEIN, Stil.LEUCHT if an else Stil.TEXT_BLASS)


## Text der Tafel: bei einem Ausbaupfad der Text der gewählten Stufe, sonst die Abschnitte des Eintrags.
func _male_text(ci: Control) -> void:
	if _daten.is_empty():
		return
	var e: Dictionary = _daten[_reiter][_wahl[_reiter]]
	var abschnitte: Array = e.get("abschnitte", [])
	var pfad: Array = e.get("pfad", [])
	if not pfad.is_empty():
		abschnitte = (pfad[_gewaehlter_knoten(e)] as Dictionary)["abschnitte"]
	var w := ci.size.x - 6.0
	# erst messen, dann mit Scroll zeichnen
	var hoehe := 0.0
	for a: Array in abschnitte:
		hoehe += 12.0
		for zeile: String in a[2]:
			hoehe += Stil.absatz_groesse(_ohne_marke(zeile), w - 9.0, Stil.KLEIN).y + 1.0
		hoehe += 4.0
	_text_hoehe = hoehe
	_scroll = clampf(_scroll, 0.0, maxf(0.0, hoehe - ci.size.y))
	var y := -_scroll
	for a: Array in abschnitte:
		Stil.schreibe(ci, Vector2(0, y + 5.0), a[0], Stil.NORMAL, a[1])
		y += 12.0
		for zeile: String in a[2]:
			var farbe := Stil.TEXT
			var marke := "·"
			if zeile.begins_with("+ "):
				farbe = GUT
				marke = "+"
			elif zeile.begins_with("– "):
				farbe = SCHLECHT
				marke = "–"
			var text := _ohne_marke(zeile)
			var zh := Stil.absatz_groesse("A", 100.0, Stil.KLEIN).y
			if marke == "·":
				ci.draw_rect(Rect2(Vector2(2, y + zh * 0.5 - 1.0), Vector2(2, 2)), Stil.TEXT_BLASS)
			else:
				Stil.schreibe(ci, Vector2(1, y + zh * 0.5), marke, Stil.KLEIN, farbe)
			Stil.absatz(ci, Vector2(9, y), text, w - 9.0, Stil.KLEIN, farbe)
			y += Stil.absatz_groesse(text, w - 9.0, Stil.KLEIN).y + 1.0
		y += 4.0
	# Laufleiste, wenn der Text nicht ganz passt
	if hoehe > ci.size.y:
		var lang := maxf(10.0, ci.size.y * ci.size.y / hoehe)
		var pos := (ci.size.y - lang) * (_scroll / (hoehe - ci.size.y))
		ci.draw_rect(Rect2(Vector2(ci.size.x - 2.0, 0), Vector2(2, ci.size.y)), Stil.METALL)
		ci.draw_rect(Rect2(Vector2(ci.size.x - 2.0, pos), Vector2(2, lang)), Stil.LEUCHT)


static func _ohne_marke(zeile: String) -> String:
	if zeile.begins_with("+ ") or zeile.begins_with("– "):
		return zeile.substr(2)
	return zeile


## Bild mit den Füßen auf `fuss`, eingepasst in `box`, pixelgenau (ganze Bildschirmpixel je Bildpunkt).
## bild: {"tex", "zelle", "reihe", "n", "ursprung", "spiegeln", "farbe", "karte_reihe"} oder {"symbol", "farbe"}.
## Karten zeigen das Standbild (Zeile karte_reihe), unter der Maus und auf der Tafel läuft die Animation.
func _male_bild(ci: CanvasItem, b: Dictionary, fuss: Vector2, box: Vector2, bewegt: bool, karte: bool) -> void:
	if b.has("glyphe"):
		# 19.11.: Fähigkeitssymbol aus der Ego-Sicht (EgoModus.GLYPHEN)
		var gb: Array = EgoModus.GLYPHEN[b["glyphe"]]
		var gpx := clampf(floorf(minf(box.x, box.y) * 0.6 / 8.0), 1.0, 4.0)
		var go := (fuss - Vector2(0, box.y / 2.0) - Vector2((gb[0] as String).length(), gb.size()) * gpx / 2.0).round()
		for gy in gb.size():
			var gz: String = gb[gy]
			for gx in gz.length():
				if gz[gx] != ".":
					ci.draw_rect(Rect2(go + Vector2(gx, gy) * gpx, Vector2(gpx, gpx)), b.get("farbe", Stil.LEUCHT) if gz[gx] == "#" else Stil.GOLD)
		return
	if b.has("symbol"):
		var px := clampf(floorf(minf(box.x, box.y) * 0.5 / 7.0), 1.0, 3.0)
		Stil.symbol(ci, b["symbol"], fuss - Vector2(0, box.y / 2.0), px, b.get("farbe", Stil.GOLD))
		return
	var tex: Texture2D = b.get("tex")
	if tex == null:
		return
	var zelle: Vector2 = b["zelle"]
	var sk := Stil.skala()
	var rand: float = b.get("rand", 1.0)   # Figurenblätter haben viel leeren Rand: so viel der Zelle ist Figur
	var bp := maxf(1.0, floorf(minf(box.x / (zelle.x * rand), box.y / (zelle.y * rand)) * sk))
	bp = minf(bp, float(b.get("max_bp", 3 if karte else 5)))   # nicht zu grob: Karten höchstens 3, Tafel 5 Bildschirmpixel je Bildpunkt
	while bp > 1.0 and (zelle.y * bp / sk > box.y * 1.1 or zelle.x * bp / sk > box.x * 1.25):
		bp -= 1.0   # große Figuren (Brakk, Belagerungsturm) nicht über den Rand ragen lassen
	var g := zelle * bp / sk
	var reihe: int = int(b.get("karte_reihe", 0)) if karte and not bewegt else int(b["reihe"])
	var n := int(b.get("n", 1)) if bewegt or not b.has("karte_reihe") else 1
	if not bewegt:
		n = 1
	var bild := int(_zeit * 8.0) % n if n > 1 else 0
	var ursprung: Vector2 = b.get("ursprung", Vector2.ZERO)
	var quelle := Rect2(ursprung + Vector2(bild * zelle.x, reihe * zelle.y), zelle)
	var o := ((fuss - Vector2(g.x / 2.0, g.y)) * sk).round() / sk
	var ziel := Rect2(o, g)
	if b.get("spiegeln", false):
		ziel = Rect2(o, Vector2(-g.x, g.y))   # Godot spiegelt negative Breiten an Ort und Stelle
	ci.draw_texture_rect_region(tex, ziel, quelle, b.get("farbe", Color.WHITE))


func _ellipse(mitte: Vector2, halb: Vector2, farbe: Color) -> void:
	var punkte := PackedVector2Array()
	for i in 20:
		var w := TAU * i / 20.0
		punkte.append(mitte + Vector2(cos(w), sin(w)) * halb)
	draw_colored_polygon(punkte, farbe)


# ------------------------------------------------------------------ Bilder

func _lade(pfad: String) -> Texture2D:
	if not _bilder.has(pfad):
		_bilder[pfad] = load(pfad) if ResourceLoader.exists(pfad) else null
	return _bilder[pfad]


## Figur aus einem Animationsblatt (Zeilen Stehen / Laufen / Angriff), in der neuen Grafik deren Blatt.
func _figur(d: Dictionary, reihe: int = 1, spiegeln: bool = false) -> Dictionary:
	var g := Werte.grafik_daten(d)
	var z := float(g["zelle"])
	return {"tex": _lade(str(g["blatt"])), "zelle": Vector2(z, z), "reihe": reihe, "n": int((g["bilder"] as Array)[reihe]), "spiegeln": spiegeln, "rand": 0.75}


## Einzelbild (oder ein Feld aus einem Blatt ohne Animation).
func _einzel(pfad: String, zelle: Vector2, ursprung: Vector2 = Vector2.ZERO) -> Dictionary:
	return {"tex": _lade(pfad), "zelle": zelle, "reihe": 0, "n": 1, "ursprung": ursprung}


## Truppe auf einer Stufe (ab Stufe 2 mit eigenem Blatt in der neuen Grafik).
func _truppen_bild(id: String, stufe: int, faehigkeit: String = "") -> Dictionary:
	var d: Dictionary = (Werte.EINHEITEN[id] as Dictionary).duplicate()
	if faehigkeit != "":
		d["faehigkeit"] = faehigkeit
	var g := Werte.grafik_einheit(d, id, stufe)
	if str(g["blatt"]) == str(d["blatt"]):
		return _figur(Werte.EINHEITEN[id])
	var z := float(g["zelle"])
	return {"tex": _lade(str(g["blatt"])), "zelle": Vector2(z, z), "reihe": 1, "n": int((g["bilder"] as Array)[1]), "rand": 0.75}


func _turm_bild(art: String, stufe: int, faehigkeit: String = "") -> Dictionary:
	var n := Werte.NEU + "tuerme/"
	match art:
		"geschuetz":
			if stufe <= 1:
				return {"tex": _lade(n + "gef_frames.png"), "zelle": Vector2(68, 68), "reihe": 0, "n": 9, "karte_reihe": 0}
			var r := 0 if stufe == 2 else (1 if faehigkeit == "doppelschuss" else 2)
			return _einzel(n + "gef_stufen.png", Vector2(68, 68), Vector2(0, r * 68))
		"lanze":
			var name := "lanze"
			if stufe == 2:
				name = "lan_s2"
			elif stufe >= 3:
				name = "lan_doppel" if faehigkeit == "doppelstrahl" else "lan_durchschlag"
			return _einzel(n + name + ".png", Vector2(64, 64))
		"truppen":   # 20.11. (Nachtrag): Platzhalter aus Code
			if ResourceLoader.exists(n + "truppen.png"):
				return _einzel(n + "truppen.png", Vector2(64, 64))   # 21.11. (Paul): PixelLab-Bild
			return {"tex": Platzhalter.truppenturm(stufe), "zelle": Vector2(Platzhalter.TT_GROESSE), "reihe": 0, "n": 1}
		"pliplop":   # 20.11. (Paul): Platzhalter aus Code, Aufsatz je Pfad
			var ring := str(Werte.PLIPLOP_TURM.get(faehigkeit, {}).get("ring", ""))
			return {"tex": Platzhalter.pliplop(ring), "zelle": Vector2(Platzhalter.PP_ZELLE, Platzhalter.PP_ZELLE), "reihe": 0, "n": 1}
	return _einzel(n + art + ".png", Vector2(64, 64))


func _batterie_bild(stufe: int) -> Dictionary:
	return {"tex": _lade(Werte.NEU + "batterie/bat_%d.png" % stufe), "zelle": Vector2(48, 48), "reihe": 1, "n": 9, "karte_reihe": 0, "rand": 0.8}


func _wurf_bild() -> Dictionary:
	var b := _figur(Werte.SCHLEUDER, 0)
	b["farbe"] = Werte.WURF_FARBE
	return b


# ------------------------------------------------------------------ Inhalt

static func _z(v: float) -> String:
	if is_equal_approx(v, roundf(v)):
		return str(int(roundf(v)))
	return ("%.1f" % v).replace(".", ",")


## Panzerung (17.11.) in Worten.
func _panzer_text(id: String) -> String:
	return "Gepanzert (Plakette am Fuß): Jeder Treffer macht %s weniger Schaden, höchstens die Hälfte geht verloren. Schwere Treffer (Scharfschütze, Lanze, Batterie) merken das kaum, Laser und Brandfeld gar nicht." % _z(Werte.GEGNER[id]["panzerung"])


func _gegner(id: String, ab: String, tut: Array, hilft: Array) -> Dictionary:
	var d: Dictionary = Werte.GEGNER[id]
	var w: Array = [["Leben", _z(d["leben"])], ["Tempo", _z(d["tempo"])]]
	if d["reichweite"] > 0.0:
		w.append(["Reichweite", _z(d["reichweite"])])
	if d["schaden"] > 0.0:
		w.append(["Schaden", _z(d["schaden"])])
	if d["schaden"] > 0.0 or id == "rauch":
		w.append(["Wurf alle" if id == "rauch" else "Angriff alle", _z(d["abklingzeit"]) + " s"])
	if float(d.get("panzerung", 0.0)) > 0.0:
		w.append(["Panzerung", "−" + _z(d["panzerung"]) + "/Treffer"])
	w.append(["Prämie", str(d["praemie"])])
	if w.size() > 6:
		# höchstens 6 Felder: Schaden und Takt zusammen
		for i in w.size() - 1:
			if w[i][0] == "Schaden" and w[i + 1][0] == "Angriff alle":
				w[i] = ["Schaden/Takt", "%s/%s" % [w[i][1], w[i + 1][1]]]
				w.remove_at(i + 1)
				break
	# Myr-Drohne: Beine laufen in Zeile 0. Sprenger und Drohne schauen im Blatt nach links – gespiegelt wie die anderen.
	return {"name": d["name"], "unter": d["art"], "marke": ab, "marke_farbe": Stil.KUPFER,
		"bild": _figur(d, 0 if id == "enterer" else 1, id in ["sprenger", "enterer"]),
		"werte": w, "abschnitte": [["Was er macht", Stil.KUPFER, tut], ["Dagegen hilft", GUT, hilft]]}


## Werte einer Truppe als Felder; `d` kann schon mit Stufe 2 verrechnet sein.
func _truppen_werte(d: Dictionary) -> Array:
	var w: Array = [["Leben", _z(d["leben"])], ["Tempo", _z(d["tempo"])], ["Reichweite", _z(d["reichweite"])],
		["Schaden", ("%d × " % (d["schuss_bilder"] as Array).size() if (d.get("schuss_bilder", []) as Array).size() > 1 else "") + _z(d["schaden"])], ["Angriff alle", _z(d["abklingzeit"]) + " s"]]
	if d.has("flaeche"):
		w.append(["Fläche", _z(d["flaeche"])])
	return w


## Werte einer Truppe mit Stufe-3-Fähigkeit (17.11.): echte Zahlen statt der Stufe-2-Werte.
## Höchstens 6 Felder – bei Bedarf ersetzt ein Fähigkeitswert das Tempo.
func _faehigkeit_werte(id: String, f: String) -> Array:
	var W := Werte
	var d: Dictionary = W.einheit_daten(id, 3, f)
	var w := _truppen_werte(d)
	var abk := float(d["abklingzeit"])
	var dmg := float(d["schaden"])
	var mehr := (d.get("schuss_bilder", []) as Array).size()
	var vor := "%d × " % mehr if mehr > 1 else ""
	match f:
		"feuerteam":
			w[4] = ["Angriff alle", "%s–%s s" % [_z2(abk), _z2(abk * W.FEUERTEAM_HOECHST)]]
		"minigun":
			w[3] = ["Schaden", _z(dmg * W.MINIGUN_SCHADEN_FAKTOR)]
			w[4] = ["Angriff alle", "%s–%s s" % [_z2(W.MINIGUN_ABKLING), _z2(W.MINIGUN_ABKLING * W.MINIGUN_SCHNELLSTE)]]
		"bollwerk":
			w.append(["Stellung", "keine"])
		"laser":
			var dps := dmg / abk
			w[3] = ["Schaden/s", "%s–%s" % [_z(dps), _z(dps * W.LASER_HOECHST)]]
			w[4] = ["Angriff", "Dauerstrahl"]
		"durchschuss":
			w.append(["Trifft", "ganze Linie"])
		"markierung":
			w[2] = ["Reichweite", "ganze Karte"]
			w[3] = ["Schaden", vor + _z(dmg * W.MARKIERUNG_EIGENER_SCHADEN)]
			w[4] = ["Angriff alle", _z2(abk * W.MARKIERUNG_ABKLING) + " s"]
			w.append(["Markiert", "+%d %% · %s s" % [roundi((W.MARKIERUNG_FAKTOR - 1.0) * 100.0), _z(W.MARKIERUNG_SEK)]])
		"abpraller":
			w[1] = ["Sprünge", "%d × %d %%" % [W.ABPRALLER_SPRUENGE, roundi(W.ABPRALLER_SCHADEN * 100.0)]]
		"brandfeld":
			w[1] = ["Nachbrand", "%s s · %d %%/s" % [_z(W.BRANDFELD_SEK), roundi(W.BRANDFELD_SCHADEN * 100.0)]]
		"plasmagel":
			w[3] = ["Schaden", vor + _z(dmg * W.PLASMAGEL_SCHADEN)]
			w[1] = ["Bremst", "%d %% · %s s" % [roundi(W.PLASMAGEL_TEMPO * 100.0), _z(W.PLASMAGEL_SEK)]]
	return w


static func _z2(v: float) -> String:
	if is_equal_approx(v, roundf(v * 10.0) / 10.0):
		return _z(v)
	return ("%.2f" % v).replace(".", ",")



## Stufe 2 auf die Grundwerte anwenden (plus / mal aus Werte.STUFE_2).
static func _mit_stufe_2(d: Dictionary, s2: Dictionary) -> Dictionary:
	var n := d.duplicate()
	for k: String in (s2.get("plus", {}) as Dictionary):
		n[k] = float(n.get(k, 0.0)) + float(s2["plus"][k])
	for k: String in (s2.get("mal", {}) as Dictionary):
		n[k] = float(n.get(k, 0.0)) * float(s2["mal"][k])
	return n


## Truppe mit Ausbaupfad: Grund › Stufe 1 (Fabrik legt sich fest) › Stufe 2 › eine von drei Fähigkeiten.
func _truppe(id: String, unter: String, tut: Array, stellung: Array) -> Dictionary:
	var W := Werte
	var d: Dictionary = W.EINHEITEN[id]
	var w := _truppen_werte(d)
	var grund := _truppen_bild(id, 1)
	var oben := stellung.duplicate()
	oben.append("Oben in der Stellung nimmt sie %d %% weniger Schaden (Deckung)." % roundi(W.STELLUNG_DECKUNG * 100.0))
	var pfad: Array = [
		{"kurz": "Grund", "bild": grund, "abschnitte": [["Was sie macht", Stil.LEUCHT, tut], ["In der Stellung", Stil.TEXT_BLASS, oben]]},
		{"kurz": "St. 1", "bild": grund, "abschnitte": [["Stufe 1 · %d Budget" % W.KOSTEN_STUFE[0], Stil.GOLD, [
			"Die Fabrik legt sich auf diese Truppe fest und hält dafür eine mehr am Leben (%d statt %d)." % [W.MAX_JE_FABRIK + 1, W.MAX_JE_FABRIK],
			"Danach lässt sich die Truppe dieser Fabrik nicht mehr wechseln."]]]},
	]
	if W.STUFE_2.has(id):
		var s2: Dictionary = W.STUFE_2[id]
		var w2 := _truppen_werte(Werte.einheit_daten(id, 2))
		pfad.append({"kurz": "St. 2", "bild": _truppen_bild(id, 2), "werte": w2, "abschnitte": [["Stufe 2 · %d Budget" % W.KOSTEN_STUFE[1], Stil.GOLD, [str(s2["text"]) + "."]]]})
		for f: String in (W.STUFE_3[id] as Dictionary):
			var s3: Dictionary = W.STUFE_3[id][f]
			pfad.append({"kurz": str(s3["name"]).split(" ")[0], "zweig": true, "bild": _truppen_bild(id, 3, f), "werte": _faehigkeit_werte(id, f), "abschnitte": [
				["Stufe 3 · %s · %d Budget" % [s3["name"], W.KOSTEN_STUFE[2]], Stil.GOLD, [s3["text"]]],
				["Stärken und Schwächen", Stil.TEXT_BLASS, ["+ " + str(s3["stark"]), "– " + str(s3["schwach"])]],
				["Hinweis", Stil.TEXT_BLASS, ["Eine Fabrik wählt genau eine der drei Fähigkeiten."]]]})
	return {"name": d["name"], "unter": unter, "marke": "aus der Fabrik", "marke_farbe": Stil.LEUCHT, "bild": grund, "werte": w, "pfad": pfad}


## Formturm mit Ausbaupfad: Grund › Stufe 2 › eine von zwei Fähigkeiten.
## 20.11. (Paul): MG-Stellung – Ausbau am Nest, die Truppe ist nur Besatzung.
func _mg_karte() -> Dictionary:
	var W := Werte
	var bild := {"tex": Platzhalter.mg_aufsatz(), "zelle": Vector2(28, 16), "reihe": 0, "n": 1}
	if ResourceLoader.exists(Werte.NEU + "tuerme/mg_nest.png"):
		bild = _einzel(Werte.NEU + "tuerme/mg_nest.png", Vector2(64, 64))   # 21.11. (Paul): PixelLab-Bild
	var n: Dictionary = W.MG_NEST
	var pfad: Array = [{"kurz": "Nest", "bild": bild, "abschnitte": [["Was sie macht", Stil.LEUCHT, [
		"Nur mit der Anführerin Sonde 7: Jede Stellung ist ein MG-Nest. Eine Truppe aus einer Fabrik muss hinauf, darf sie aber wieder verlassen.",
		"Die Werte hängen am Nest, nicht an der Truppe: Jede Truppe darin schießt gleich. Billige, nicht ausgebaute Truppen reichen.",
		"Nest: %s Schaden alle %s s, Reichweite %s (Wachposten und Anhöhe zählen dazu)." % [_z(n["schaden"]), _z(n["abklingzeit"]), _z(n["reichweite"])],
		"Klick auf die Stellung öffnet den Ausbau. Stufe 1 und 2 je eine von zwei Richtungen, Stufe 3 eine Sonderform, die aus beiden folgt."]]]}]
	for i in 2:
		var zeilen: Array = []
		for k: String in W.MG_AUSBAU[i]:
			var e: Dictionary = W.MG_AUSBAU[i][k]
			zeilen.append("%s: %s (+ %s · – %s)" % [e["name"], e["text"], e["stark"], e["schwach"]])
		pfad.append({"kurz": "St. %d" % (i + 1), "bild": bild, "abschnitte": [["Stufe %d · %d Budget · eine von zwei" % [i + 1, W.KOSTEN_MG_STUFE[i]], Stil.GOLD, zeilen]]})
	for kombi: String in W.MG_SONDER:
		var zeilen: Array = []
		for k: String in W.MG_SONDER[kombi]:
			var e: Dictionary = W.MG_SONDER[kombi][k]
			zeilen.append("%s: %s (+ %s · – %s)" % [e["name"], e["text"], e["stark"], e["schwach"]])
		var teile := kombi.split("+")
		var titel := "%s + %s" % [W.MG_AUSBAU[0][teile[0]]["name"], W.MG_AUSBAU[1][teile[1]]["name"]]
		pfad.append({"kurz": titel.replace(" + ", "+"), "zweig": true, "bild": bild, "abschnitte": [["Stufe 3 nach %s · %d Budget" % [titel, W.KOSTEN_MG_STUFE[2]], Stil.GOLD, zeilen]]})
	return {"name": "MG-Stellung", "unter": "Stellung mit eigenem Ausbau (Sonde 7)", "marke": "%d · [3]" % W.KOSTEN_MG_STELLUNG, "bild": bild,
		"werte": [["Schaden", _z(n["schaden"])], ["Angriff alle", _z(n["abklingzeit"]) + " s"], ["Reichweite", _z(n["reichweite"])], ["Stufen", "%d / %d / %d" % [W.KOSTEN_MG_STUFE[0], W.KOSTEN_MG_STUFE[1], W.KOSTEN_MG_STUFE[2]]]],
		"pfad": pfad}


## 20.11. (Paul): PliPlop 3cK – Turm ohne Formvorschrift, drei Pfade ab Stufe 2.
func _pliplop_karte() -> Dictionary:
	var W := Werte
	var d: Dictionary = W.TURMARTEN["pliplop"]
	var pr: Array[int] = W.kosten_pliplop_stufen()
	var pfad: Array = [{"kurz": "Grund", "bild": _turm_bild("pliplop", 1), "abschnitte": [["Was er macht", Stil.LEUCHT, [d["text"],
		"Stufe 2 wählt den Pfad (%d), Stufe 3 und 4 verstärken ihn (%d / %d)." % [pr[0], pr[1], pr[2]],
		"Wird nicht von Stützen getragen: Sprenger legen ihn nicht still."]]]}]
	for name: String in W.PLIPLOP_TURM:
		var p: Dictionary = W.PLIPLOP_TURM[name]
		var zeilen: Array = [p["text"]]
		for i in 3:
			zeilen.append("Stufe %d: %s" % [i + 2, p["stufen"][i]["text"]])
		pfad.append({"kurz": p["name"], "zweig": true, "bild": _turm_bild("pliplop", 2, name), "abschnitte": [["Pfad %s" % p["name"], Stil.GOLD, zeilen],
			["Stärken und Schwächen", Stil.TEXT_BLASS, ["+ " + str(p["stark"]), "– " + str(p["schwach"])]]]})
	return {"name": d["name"], "unter": "Turm auf einem einzelnen Erdwall (Irrtürmer)", "marke": "%d · [4]" % W.KOSTEN_PLIPLOP, "bild": _turm_bild("pliplop", 1),
		"werte": [["Preis", str(W.KOSTEN_PLIPLOP)], ["Form", "Einzelwall"], ["Reichweite", _z(d["reichweite"])], ["Schaden", _z(d["schaden"])], ["Angriff alle", _z(d["abklingzeit"]) + " s"]],
		"pfad": pfad}


func _turmkarte(art: String, extra: Array) -> Dictionary:
	var W := Werte
	var d: Dictionary = W.TURMARTEN[art]
	var w: Array = [["Preis", str(W.KOSTEN_TURM)], ["Form", d["form"]], ["Stützen", str(d["nachbarn"])], ["Reichweite", _z(d["reichweite"])]]
	if float(d["schaden"]) > 0.0:
		w.append(["Schaden", _z(d["schaden"])])
		w.append(["Angriff alle", _z(d["abklingzeit"]) + " s"])
	var regeln: Array = [d["text"]]
	regeln.append_array(extra)
	var unter: String = "Turm auf " + {"Ecke": "einer Ecke", "Kreuzung": "einer Kreuzung", "T-Stück": "einem T-Stück", "Lange Ecke": "einer langen Ecke", "Klammer": "einer Klammer", "Treppe": "einer Treppe"}.get(d["form"], d["form"])
	var pfad: Array = [
		{"kurz": "Grund", "bild": _turm_bild(art, 1), "abschnitte": [["Was er macht", Stil.LEUCHT, regeln], ["Für alle Türme", Stil.TEXT_BLASS, [
			"Welcher Turm entsteht, entscheidet die Form der Erdwälle drumherum: T-Stück = Geschütz, Kreuzung = Funk, lange Ecke = Frost, Klammer = Lanze, Treppe = Heilung. Die Bauvorschau nennt den Turm.",
			"Seine Stützen dürfen keinen anderen Turm stützen; Stellungen darauf sind erlaubt.",
			"Schießt ohne Truppe und auch im Rauch, Sicht wie aus einer Stellung. Sein Erdwall hält Sprengern stand.",
			"Myr-Drohnen können ihn bis zum Rundenende lahmlegen."]]]},
		{"kurz": "St. 2", "bild": _turm_bild(art, 2), "abschnitte": [["Stufe 2 · %d Budget" % W.KOSTEN_TURM_STUFE[0], Stil.GOLD, [W.TURM_STUFE_2[art]["text"]]]]},
	]
	for f: String in (W.TURM_STUFE_3[art] as Dictionary):
		var s3: Dictionary = W.TURM_STUFE_3[art][f]
		pfad.append({"kurz": str(s3["name"]).split(" ")[0], "zweig": true, "bild": _turm_bild(art, 3, f), "abschnitte": [
			["Stufe 3 · %s · %d Budget" % [s3["name"], W.KOSTEN_TURM_STUFE[1]], Stil.GOLD, [s3["text"]]],
			["Stärken und Schwächen", Stil.TEXT_BLASS, ["+ " + str(s3["stark"]), "– " + str(s3["schwach"])]]]})
	return {"name": d["name"], "unter": unter, "marke": "%d · [4]" % W.KOSTEN_TURM, "bild": _turm_bild(art, 1), "werte": w, "pfad": pfad}


func _batteriekarte() -> Dictionary:
	var W := Werte
	var b: Dictionary = W.BATTERIE
	var w: Array = [["Preis", "%d, +%s %%" % [W.KOSTEN_BATTERIE, _z(W.KOSTEN_BATTERIE_PROZENT)]], ["Reichweite", _z(b["reichweite"])], ["Schaden", _z(b["schaden"])],
		["Angriff alle", _z(b["abklingzeit"]) + " s"], ["Fläche", _z(b["flaeche"])], ["Plätze", "%d Piloten" % b["plaetze"]]]
	var pfad: Array = [{"kurz": "Grund", "bild": _batterie_bild(0), "abschnitte": [["Was sie macht", Stil.LEUCHT, [
		"Zwei Felder: Batterie und angebaute Pilotenfabrik ([T] dreht sie beim Bauen).",
		"Feuert nur, solange alle %d Plätze mit Piloten besetzt sind – weit, über Erdwälle hinweg und mit Flächenschaden." % b["plaetze"],
		"Ausgebaut wird über die Pilotenfabrik."]]]}]
	for i in W.BATTERIE_STUFEN.size():
		var s: Dictionary = W.BATTERIE_STUFEN[i]
		var zeilen: Array = [s["text"]]
		if i == 2:
			zeilen.append("So viel hält er aus: 1 Feld %d, 2 Felder %d, 3 Felder %d, 5 Felder %d." % [
				roundi(W.schild_leben(1)), roundi(W.schild_leben(2)), roundi(W.schild_leben(3)), roundi(W.schild_leben(5))])
			zeilen.append("+ Engstellen dicht machen, Zeit für Stellungen und Türme gewinnen")
			zeilen.append("– Weite Schilde brechen schnell; fällt einer der Erdwälle, ist der Schild weg")
		pfad.append({"kurz": "St. %d" % (i + 1), "bild": _batterie_bild(i + 1), "abschnitte": [["Stufe %d · %s · %d Budget" % [i + 1, s["name"], W.KOSTEN_BATTERIE_STUFE[i]], Stil.GOLD, zeilen]]})
	return {"name": "Batterie", "unter": "Railgun mit Pilotenfabrik", "marke": "%d · [5]" % W.KOSTEN_BATTERIE, "bild": _batterie_bild(0), "werte": w, "pfad": pfad}


func _baue_daten() -> void:
	var W := Werte
	var schleuder: Dictionary = W.SCHLEUDER
	var laser: Dictionary = W.LASER
	var TITEL := Stil.KUPFER
	var gegner: Array = [
		_gegner("hund", "ab Runde 1", [
			"Schneller Nahkämpfer, kommt im Rudel.",
			"Beißt Bodentruppen in Reichweite. An Truppen in Stellungen kommt er nicht heran."], [
			"Stellungen am Weg, Bodentruppen zum Abfangen dahinter.",
			"Plasmawerfer gegen dichte Rudel."]),
		_gegner("sphaere", "ab Runde 3", [
			"Fernkämpfer, schießt im Laufen.",
			"Ziele der Reihe nach: Truppen in Stellungen, dann Fabriken und Batterien, dann Bodentruppen.",
			"An Truppen macht sie %s Schaden, an Gebäuden %s." % [_z(W.GEGNER["sphaere"]["schaden_einheit"]), _z(W.GEGNER["sphaere"]["schaden"])],
			"Solange sie schießt, läuft sie nur langsam weiter (%d %% Tempo)." % roundi(W.FERNKAMPF_GEFECHT_TEMPO * 100),
			"Schießt sich ein: Jeder Sphärentreffer auf ein Feld lässt alle Sphären, die darauf schießen, schneller feuern – bis +%d %% Schaden. Nach %s Sekunden ohne Treffer kühlt das Feld ab." % [roundi(W.EINSCHUSS_MAX * 100), _z(W.EINSCHUSS_SEK)],
			"Zerschossene Fabriken und Batterien fallen bis zum Rundenende aus."], [
			"Scharfschützen: mehr Reichweite als die Sphäre.",
			"Bedrängte Stellung räumen lassen oder nachbesetzen: Das Einschießen gilt dem Feld.",
			"Fabriken nicht direkt an den Weg stellen.",
			"Der Reservepilot der Batterie repariert Ausgefallenes."]),
		_gegner("fahne", "ab Runde 6", [
			"Macht die anderen in seinem Trupp 30 % schneller – er selbst läuft ohne Bonus und fällt dadurch zurück.",
			"Hinterlässt für %s Sekunden eine Spur: Gegner darauf sind ebenfalls 30 %% schneller." % _z(W.FAHNE_SPUR_SEK),
			"Kämpft nicht, nimmt Checkpoints aber doppelt so schnell ein."], [
			"Ihn zuerst ausschalten: Der Trupp fällt auf sein normales Tempo zurück.",
			"Plasmagel bremst den Sturm, Zielmarkierung trifft ihn überall."]),
		_gegner("sprenger", "ab Runde 8", [
			"Sprengt den Erdwall, dessen Wegfall eine große Abkürzung bringt – frühestens nach %d Schritten Anmarsch." % W.SPRENGER_MIN_WEG,
			"Dicke Riegel aus blanken Erdwällen fallen bis zu 4 Felder tief. Linien in Sprengrichtung, Stellungen und Tore verlieren nur das getroffene Feld.",
			"Ohne lohnenden Erdwall sprengt er eine Fabrik (%s s Ausfall) und trifft Bodentruppen daneben." % _z(W.SPRENGER_FABRIK_SEK),
			"Am Ziel zündet er %s Sekunden lang und steht dabei still (Ring über dem Warnzeichen). Fällt er vorher, gibt es keine Sprengung." % _z(W.SPRENGER_ZUENDZEIT),
			"Das Ziel blinkt erst in der Welle. Der Sprenger trägt ein Warnzeichen."], [
			"Vor dem Ziel abfangen – er hält wenig aus. Spätestens beim Zünden ist er ein stehendes Ziel.",
			"Erdwälle mit Turm halten stand, gepanzerte überstehen eine Sprengung."]),
		_gegner("rauch", "ab Runde 11", [
			"Wirft Rauch auf die dichteste Gruppe von Stellungen; ohne Stellungen auf einen Truppenhaufen.",
			"Truppen im Rauch schießen %s Sekunden nicht. Türme schießen weiter." % _z(W.RAUCH_SEK),
			"In den Rauch hinein kann geschossen werden – blind ist nur, wer selbst darin steht."], [
			"Türme, verteilte Stellungen, vorrückende Bodentruppen.",
			"Scharfschützen ab Stufe 2 (Klarsicht) schießen auch im Rauch; ein markiertes Ziel treffen alle.",
			"Batterie mit Schwerer Ladung bläst den Rauch weg."]),
		_gegner("belagerung", "ab Runde 13", [
			_panzer_text("belagerung"),
			"Dockt am ersten erreichbaren Erdwall nach der Zone an, an dem Stellungen oder Türme in der Nähe sind (höchstens %d Wallschritte)." % W.ANDOCK_NAH,
			"Dann springt alle %s Sekunden eine Myr-Drohne auf den Wall – bis zu %d zugleich, höchstens %s Sekunden lang." % [_z(W.ENTERER_ABSTAND), W.ENTERER_GLEICHZEITIG, _z(W.BELAGERUNG_SEK)],
			"Dockt er an, wirft die Wurf-Schleuder sofort auf die andere Seite."], [
			"Unterwegs zerstören: langsam, aber sehr zäh.",
			"Laserstrahl und Zielmarkierung gegen zähe Einzelziele."]),
		_gegner("schild", "ab Runde 9", [
			_panzer_text("schild"),
			"Trägt einen großen Schild nach vorn: Alles von vorn macht nur %d %% Schaden – auch Batterie, Plasma und Lanze." % roundi(W.SCHILD_FRONT_FAKTOR * 100),
			"Fläche und Strahlen von vorn fängt er auch für die ab, die direkt hinter ihm gehen.",
			"Er zieht das Feuer auf sich: Truppen, Türme und Batterien nehmen ihn zuerst ins Visier, egal welche Zielwahl.",
			"Er geht %s Sekunden vor dem Rest seines Trupps los. Von der Seite und von hinten trifft alles voll." % _z(W.SCHILD_VORLAUF_SEK),
			"Mit Battlesphären im Trupp bleibt er knapp vor ihnen (%s Felder) und passt sein Tempo an, statt davonzulaufen." % _z(W.SCHILD_VORSPRUNG)], [
			"Stellungen und Türme seitlich am Gang oder hinter einer Kurve.",
			"Lanze in einer Klammer am Ende eines Gangs trifft ihn, sobald er abbiegt."]),
		_gegner("sani", "ab Runde 14", [
			"Kämpft nicht. Alle %s Sekunden heilt er die Gegner im Umkreis von %s Feldern um %s Leben." % [_z(W.GEGNER["sani"]["abklingzeit"]), _z(W.GEGNER["sani"]["reichweite"]), _z(W.GEGNER["sani"]["heilung"])],
			"Gebündelte Trupps werden mit ihm deutlich zäher."], [
			"Zielwahl „Stärkste“ hilft nicht – er hat wenig Leben. Lieber gezielt: Scharfschützen mit Zielmarkierung, Schwere Munition.",
			"Flächenschaden auf den ganzen Trupp."]),
		_gegner("schwarm", "ab Runde 12", [
			_panzer_text("schwarm"),
			"Langsam und zäh. Fällt er, zerfällt er in %d Myr-Drohnen, die am Boden weiterkämpfen." % int(W.GEGNER["schwarm"]["zerfall"])], [
			"Flächenschaden, Doppelschuss, Frost – alles, was viele kleine Ziele trifft.",
			"Nicht erst kurz vor dem Ziel fallen lassen: die Drohnen sind schnell."]),
		_gegner("enterer", "ab Runde 12", [
			"Kommt aus dem Belagerungsturm und läuft oben auf zusammenhängenden Erdwällen – oder aus einem gefallenen Schwarmgeist, dann kämpft sie am Boden.",
			"Greift Truppen in Stellungen im Nahkampf an und legt Türme bis zum Rundenende lahm.",
			"Findet sie kein Ziel, springt sie ab und läuft zur Basis."], [
			"Getrennte Wallstücke: Sie kommt nur über verbundene Erdwälle.",
			"Der Reservepilot macht lahme Türme wieder flott."]),
		{"name": "Stein-Schleuder", "unter": "steht in der Zone", "marke": "ab Runde 5", "marke_farbe": Stil.KUPFER, "bild": _figur(schleuder, 0),
			"werte": [["Reichweite", _z(schleuder["reichweite"])], ["auf Truppe", _z(schleuder["schaden_einheit"])], ["auf Fabrik", _z(schleuder["schaden_fabrik"])], ["Wurf alle", _z(schleuder["abklingzeit"]) + " s"]],
			"abschnitte": [["Was sie macht", TITEL, [
				"Steht unter dem Schild der Zone und wirft Steine auf Truppen in Stellungen und auf Fabriken im pinken Kreis.",
				"Ohne solche Ziele trifft sie Haufen ab %d Bodentruppen." % W.HAUFEN_MIN,
				"Ab Runde %d gibt es eine zweite, und beide wechseln den Platz: vor jeder Runde und alle %s Sekunden." % [W.SPRENGER_AB_WELLE, _z(W.SCHLEUDER_UMZUG_SEK)],
				"Zerschossene Fabriken und Batterien fallen bis zum Rundenende aus."]],
				["Dagegen hilft", GUT, ["Wichtiges außerhalb des Kreises bauen.", "Truppen nicht auf einem Haufen stehen lassen."]]]},
		{"name": "Wurf-Schleuder", "unter": "steht in der Zone", "marke": "ab Runde 10", "marke_farbe": Stil.KUPFER, "bild": _wurf_bild(),
			"werte": [["Wurfweite", _z(W.WURF["reichweite"])], ["je Wurf", "%d Gegner" % W.WURF["rudel"]], ["Wurf alle", _z(W.WURF["abklingzeit"]) + " s"]],
			"abschnitte": [["Was sie macht", TITEL, [
				"Wirft Trupps zu vier über die Erdwälle – je nach Runde Hunde, Fahnenträger, Sprenger oder Rauchwerfer.",
				"Landepunkt: hinter der Wallgruppe mit dem größten Umweg, gern nahe an einem Checkpoint.",
				"Die Vorschau nennt nur, was geworfen wird. Der Landekreis erscheint erst in der Welle.",
				"Ohne echte Mauer wirft sie weiter (%s Felder). Sehr dicke Mauern bekommen ein Rudel Hunde zusätzlich." % _z(W.WURF["tasche_weit"]),
				"In einen rundum geschlossenen Kern wirft sie nicht.",
				"Ab Runde 14 gibt es eine zweite."]],
				["Dagegen hilft", GUT, ["Bodentruppen auch hinter der Mauer haben.", "Checkpoints hinter Erdwällen nicht ungeschützt lassen."]]]},
		{"name": "Laser", "unter": "verteidigt die Zone", "marke": "Runde %d" % W.LETZTE_RUNDE, "marke_farbe": Stil.KUPFER, "bild": _figur(laser, 0),
			"werte": [["Leben", _z(laser["leben"])], ["Reichweite", _z(laser["reichweite"])], ["Schaden", _z(laser["schaden"])], ["Angriff alle", _z(laser["abklingzeit"]) + " s"]],
			"abschnitte": [["Was er macht", TITEL, [
				"Drei Laser verteidigen die Zone in der letzten Runde.",
				"Sie schießen flach und nur auf Bodentruppen. Erdwälle geben Deckung."]],
				["Dagegen hilft", GUT, ["Im Schutz der eigenen Erdwälle anmarschieren."]]]},
	]

	var truppen: Array = [
		_truppe("technogunner", "Allrounder", [
			"Schnelle Schussfolge, mittlere Reichweite.",
			"Gut am Boden zum Abfangen und in Stellungen."],
			["+%s Reichweite. Schießt über die Erdwälle des eigenen Wallstücks." % _z(W.stellung_bonus(W.EINHEITEN["technogunner"]))]),
		_truppe("scharfschuetze", "weit und genau", [
			"Größte Reichweite und hoher Schaden auf ein Ziel, aber langsame Schussfolge.",
			"Hält wenig aus – gehört in eine Stellung."],
			["+%s Reichweite. Schießt nur über Erdwälle, die mit seinem verbunden sind; fremde Wallstücke versperren die Sicht." % _z(W.stellung_bonus(W.EINHEITEN["scharfschuetze"]))]),
		_truppe("plasmawerfer", "Flächenschaden", [
			"Trifft alle Gegner im Umkreis des Ziels.",
			"Stark gegen Rudel, langsam gegen einzelne zähe Gegner."],
			["Kein Reichweitenbonus – von oben nur der Schuss über die eigenen Erdwälle."]),
	]
	var kd: Dictionary = W.KOMMANDANT
	truppen.append({"name": "Kommandant Brakk", "unter": "Held, einmal pro Partie", "marke": "%d · [8]" % W.KOSTEN_KOMMANDANT, "bild": _figur(kd),
		"werte": [["Leben", _z(kd["leben"])], ["Tempo", _z(kd["tempo"])], ["Reichweite", _z(kd["reichweite"])], ["Schaden", "2 × " + _z(kd["schaden"])], ["Angriff alle", _z(kd["abklingzeit"]) + " s"]],
		# 18.11. (Paul): zwei Reiter – das normale Spiel und der Brakk-Mode (Ego-Sicht)
		"pfad": [
			{"kurz": "Spiel", "bild": _figur(kd), "abschnitte": [["Im normalen Spiel", Stil.LEUCHT, [
				"[8] und Klick auf ein freies Feld stellt ihn auf (zwischen den Wellen), einmal pro Partie. Er handelt selbst und schießt auf den vordersten Gegner; anklicken = mit [W][A][S][D] steuern.",
				"[Q] Sammeln: Bodentruppen im Umkreis von %s Feldern folgen ihm. Nochmal [Q] = Losschlagen auf das Feld unter der Maus: %s s schneller und rascher feuernd." % [_z(kd["sammel_radius"]), _z(kd["sturm_sek"])],
				"[E] Klettern: auf einen angrenzenden Erdwall und wieder herunter. Oben +%s Reichweite und Sicht über sein Wallstück." % _z(kd["wall_bonus"]),
				"[R] Klonmaschine, einmal pro Runde: Wer hindurchgeht, wird einmal geklont – auch Gegner. Klone geben keine Prämie.",
				"Holt verlorene Checkpoints %s-mal so schnell zurück. Fällt er, steht er zur nächsten Runde wieder da." % _z(kd["cp_faktor"])]]]},
			{"kurz": "Brakk", "bild": _figur(kd), "abschnitte": [
				["Brakk-Mode (Startmenü)", Stil.LEUCHT, [
				"Du bist Brakk in der Ego-Sicht: [W][A][S][D] + Maus, Klick schießt, Leertaste springt (in der Luft nochmal: Doppelsprung von einer Lichtplattform, vom Wall: Absprung mit Druckwelle).",
				"Zwei Pistolen im Wechsel. Jede überhitzt bei Dauerfeuer (Bögen am Fadenkreuz) und ist dann kurz gesperrt.",
				"Runden laufen von selbst: Countdown in der Bauphase, [Enter] startet früher. Keine Fabrik nötig, jede Runde 5 Erdwälle gratis.",
				"Viele Gegner, Schleudern werfen auch auf Brakk: roter Landekreis – mit [Shift] ausweichen. Der rote Bogen am Rand zeigt, woher Treffer kommen.",
				"Bauen mit [1]–[7] (5 Felder Reichweite), [F] baut aus. Der Schild der Gegnerzone fängt Schüsse ab."]],
				["Fähigkeiten (frei mit der Stufe)", Stil.GOLD, [
				"[E] Lichttreppe auf den Wall im Blick (bis 5 Felder, steht 8 s) – oben auf dem Wall [E] Lichtbrücke zum nächsten Wall.",
				"St. 2 [Shift] Tumble · St. 3 [Q] Lichtanker (werfen, nochmal [Q] zieht dich hin, dazwischen schwingen) · St. 4 Rechtsklick halten: Ladestrahl (lässt die Hitze ab).",
				"St. 6 [X] Lichtsäule (zielen, Linksklick setzt; Art je aktivem Ring) · St. 7 [R] Klonmaschine (lädt durch 30 Kills) · St. 8 [V] Zeitlupe.",
				"Stufen: Erfahrung aus eigenen Kills und Wellen; jede Stufe +5 % Schaden, +30 Leben."]],
				["Ringe (Lichtterminal: [F] an der Basis)", Stil.GOLD, [
				"Kaufen und auf Stufe 2 und 3 ausbauen. Ein Finger je Ring, frei ab Stufe 1, 3, 5, 7, 9.",
				"Neun Ringe, je einer für jede Stufe-3-Fähigkeit: Durchschlag, Glutstrahl, Ziel (Scharfschützen) · Takt, Wirbel, Wall (Technogunner) · Sprung, Brand, Gel (Plasmawerfer). Brakks Ringeffekt wächst mit der Ringstufe.",
				"[C] in der Bauphase: Ringfeld (2×2 Felder, höchstens 4 Fabriken) – Vorschau, [C] oder Linksklick setzt. Fabriken darin bauen die Truppe des Rings auf seiner Stufe.",
				"Alle getragenen Ringe wirken zusammen auf Brakks Schüsse. Das Mausrad wählt den aktiven Ring – er bestimmt Lichtsäule, Ladestrahl, die Farben und welches Feld [C] setzt. Fabriken haben hier keine Ausbauten und werden nur um 10 % teurer statt 25 %."]]]},
		]})
	var pilot: Dictionary = W.EINHEITEN["pilot"]
	truppen.append({"name": "Pilot", "unter": "bemannt Batterien", "marke": "Pilotenfabrik", "marke_farbe": Stil.LEUCHT, "bild": _figur(pilot),
		"werte": [["Leben", _z(pilot["leben"])], ["Tempo", _z(pilot["tempo"])]],
		"abschnitte": [["Was er macht", Stil.LEUCHT, [
			"Kämpft nicht. Kommt aus der Pilotenfabrik, die an jeder Batterie hängt.",
			"Bemannt die nächste Batterie mit freiem Platz und wartet sonst an der Fabrik.",
			"Reservepilot (Batterie Stufe 1): rückt nach, wenn einer fehlt, und repariert sonst ausgefallene Fabriken, Batterien und lahme Türme in %s Sekunden." % _z(W.REPARATUR_SEK)]]]})

	var ui := Werte.NEU + "ui/"
	var bauten: Array = [
		{"name": "Fabrik", "unter": "baut Truppen", "marke": "%d · [1]" % W.KOSTEN_FABRIK, "bild": _einzel(Werte.NEU + "gebaeude/fabrik_grund.png", Vector2(64, 64)),
			"werte": [["Preis", str(W.KOSTEN_FABRIK)], ["jede weitere", "+%s %%" % _z(W.KOSTEN_FABRIK_PROZENT)], ["Truppen", str(W.MAX_JE_FABRIK)], ["Leben", _z(W.LEBEN_FABRIK)]],
			"abschnitte": [["Was sie macht", Stil.LEUCHT, [
				"Hält bis zu %d Truppen am Leben. Welche Truppe, wählst du im Fenster der Fabrik; ein Wechsel gilt für die nächste Truppe." % W.MAX_JE_FABRIK,
				"Steht am Boden und versperrt den Weg wie ein Erdwall, aber nicht die Sicht.",
				"Truppen brauchen einen Ausgang: ein freies Feld oder ein Tor direkt an der Fabrik. Ohne Ausgang (rotes Kreuz) besetzen sie nur Stellungen, die direkt anliegen – nicht über Eck.",
				"Sphären, Schleudern und Sprenger können sie ausfallen lassen. Nahkämpfer greifen sie nicht an."]],
				["Ausbau", Stil.GOLD, [
				"Stufe 1 (%d): legt sich auf ihre Truppe fest, dafür eine Truppe mehr." % W.KOSTEN_STUFE[0],
				"Stufe 2 (%d) und Stufe 3 (%d): siehe Reiter Truppen – dort mit Bild je Stufe." % [W.KOSTEN_STUFE[1], W.KOSTEN_STUFE[2]]]]]},
		{"name": "Erdwall", "unter": "lenkt den Gegnerweg", "marke": "%d · [2]" % W.KOSTEN_WALL, "bild": _einzel(ui + "bau_wall.png", Vector2(32, 32)),
			"werte": [["Preis", str(W.KOSTEN_WALL)], ["Leben", _z(W.LEBEN_WALL)], ["ab Runde", str(W.WAELLE_AB_WELLE)]],
			"abschnitte": [["Was er macht", Stil.LEUCHT, [
				"Gegner nehmen den kürzesten freien Weg zur Basis – Erdwälle machen ihn länger.",
				"Nur wenn gar kein Weg mehr frei ist, reißen sie Erdwälle ein.",
				"Maustaste halten zieht eine ganze Reihe. Während der Welle kann kein Erdwall nachgebaut werden.",
				"Grundlage für Stellung, Turm, Tor und Wallpanzer – und Halt für den Energieschild der Batterie."]]]},
		{"name": "Stellung", "unter": "Ausbau eines Erdwalls", "marke": "%d · [3]" % W.KOSTEN_STELLUNG, "bild": _einzel(ui + "bau_stellung.png", Vector2(32, 32)),
			"werte": [["Preis", str(W.KOSTEN_STELLUNG)], ["Platz", "1 Truppe"]],
			"abschnitte": [["Was sie macht", Stil.LEUCHT, [
				"Eine Truppe steht oben und schießt über die Erdwälle ihres Wallstücks. Fremde Wallstücke versperren die Sicht.",
				"Mehr Reichweite von oben: Technogunner +%s, Scharfschütze +%s, Plasmawerfer +%s." % [_z(W.stellung_bonus(W.EINHEITEN["technogunner"])), _z(W.stellung_bonus(W.EINHEITEN["scharfschuetze"])), _z(W.stellung_bonus(W.EINHEITEN["plasmawerfer"]))],
				"Kein Schuss durch die Lücke zwischen Erdwällen, die sich nur an den Ecken berühren.",
				"Wachposten: Auf einem einzelnen Erdwall ohne Nachbarwälle reicht jede Truppe +%s Felder weiter." % _z(W.WACHPOSTEN_BONUS),
				"Nahkämpfer am Boden kommen nicht heran. Gefährlich sind Sphären, Schleudern, Rauch und Myr-Drohnen.",
				"Darf auch in der Welle gebaut werden, solange kein Gegner in der Nähe ist."]]]},
		_mg_karte(),   # 20.11. (Paul): MG-Stellung (Sonde 7)
		_turmkarte("geschuetz", ["Das ist der bisherige Turm."]),
		_turmkarte("frost", ["Braucht eine lange Ecke: Der Turm steht im Knick, beide Arme sind mindestens 2 Erdwälle lang.",
			"Bremst ganze Trupps – gut gegen Fahnensturm und schnelle Rudel."]),
		_turmkarte("funk", ["Zählt alle Stellungen im Umkreis, nicht nur eine – je mehr Stellungen drumherum, desto mehr lohnt er."]),
		_turmkarte("lanze", ["Braucht eine Klammer: drei Erdwälle in einer Linie, an beiden Enden biegt die Mauer zur selben Seite ab (⊐). Der Turm steht in der Mitte.",
			"Am stärksten an langen, geraden Gängen, in denen die Gegner hintereinander laufen."]),
		_pliplop_karte(),   # 20.11. (Paul): PliPlop 3cK (Irrtürmer)
		_turmkarte("truppen", ["Nur mit dem Anführer Irrtürmer: ein Erdwall mit genau zwei Nachbarwällen, auf den keine andere Turmform passt. Die Besatzung schießt aus dem Turm und rückt nur aus, wenn ein Gegner einen Checkpoint im Umkreis von 4 Feldern betritt. Die Punkte am Turm zeigen, wie viele Werkschutz-Truppen gerade im Turm sind."]),   # 20.11. (Nachtrag)
		_turmkarte("heil", ["Braucht eine Treppe: drei Erdwälle schräg hintereinander, der Turm in der Mitte. Andere Erdwälle daneben stören nicht, solange keine andere Turmform passt.",
			"Truppen sind knapp: Wer überlebt, muss nicht nachgebaut werden."]),
		{"name": "Schildgenerator", "unter": "Großbau in einer Zitadelle", "marke": "%d · [4]" % W.KOSTEN_GENERATOR, "bild": _einzel(Werte.NEU + "tuerme/schild.png", Vector2(64, 64)),
			"werte": [["Preis", str(W.KOSTEN_GENERATOR)], ["Felder", "1"], ["Zitadelle", "%d–%d Felder" % [W.HOF_MIN, W.HOF_MAX]], ["Schutz", "%d %%" % roundi(W.KUPPEL_SCHUTZ * 100)]],
			"abschnitte": [["Was er macht", Stil.LEUCHT, [
				"Eine Zitadelle sind freie Felder, die rundum von Erdwällen eingeschlossen sind (ein Tor zählt mit, Ecken sind egal). Mit [4] auf ein freies Feld darin gesetzt entsteht der Generator.",
				"Stufe I: bis 2×2 Felder innen (8 Erdwälle). Stufe II: bis 4×4 (16). Stufe III: bis 6×6 (24), erst ab Welle %d." % W.ZITADELLE_III_AB_WELLE,
				"Ausbauen: Ring eine Kachel weiter nach außen ziehen und den alten abreißen – der Generator bleibt, die Kuppel wächst mit.",
				"Seine Kuppel deckt den ganzen Ring und ein Feld darüber hinaus. Truppen darunter nehmen %d %% weniger Schaden." % roundi(W.KUPPEL_SCHUTZ * 100),
				"Steine der Schleuder prallen an der Kuppel ab; Schleudern und Rauchwerfer suchen sich Ziele außerhalb.",
				"Bricht der Ring auf (Sprenger), erlischt die Kuppel, bis er wieder geschlossen ist. Pro Zitadelle ein Generator."]],
				["Dagegen spricht", SCHLECHT, ["– Teuer, und die Zitadelle bindet Platz und Erdwälle, die sonst den Weg verlängern."]]]},
		{"name": "Wallpanzer", "unter": "Ausbau eines Erdwalls", "marke": "%d · [7]" % W.KOSTEN_PANZER, "bild": _einzel(ui + "bau_panzer.png", Vector2(32, 32)),
			"werte": [["Preis", str(W.KOSTEN_PANZER)]],
			"abschnitte": [["Was er macht", Stil.LEUCHT, [
				"Stahlplatten auf dem Erdwall: Die erste Sprengung reißt nur den Wallpanzer weg, erst ein zweiter Sprenger bringt den Erdwall zu Fall.",
				"Eine Sprengung in die Tiefe hört an einem gepanzerten Erdwall auf.",
				"Lässt sich mit Stellung, Turm und Tor kombinieren."]]]},
		{"name": "Tor", "unter": "Ausbau eines Erdwalls", "marke": "%d · [6]" % W.KOSTEN_TOR, "bild": _einzel(ui + "bau_tor.png", Vector2(32, 32)),
			"werte": [["Preis", str(W.KOSTEN_TOR)]],
			"abschnitte": [["Was es macht", Stil.LEUCHT, [
				"Durchgang nur für eigene Truppen. Für Gegner bleibt es ein Erdwall.",
				"Direkt an einer Fabrik ist es ihr Ausgang.",
				"Deine Truppen kommen so schneller zum Abfangen und zu den Checkpoints.",
				"Zusammen mit Erdwällen lassen sich Fabriken einschließen (Zitadelle)."]]]},
		_batteriekarte(),
	]

	var regeln: Array = [
		{"name": "Budget", "unter": "woher das Geld kommt", "marke": "Regeln", "marke_farbe": Stil.TEXT_BLASS, "bild": {"symbol": "muenze", "farbe": Stil.GOLD},
			"werte": [["Start", str(W.START_BUDGET)], ["Leben", str(W.START_LEBEN)], ["Abriss", "%d %% zurück" % int(W.ERSTATTUNG * 100)], ["Zinsen max.", "+%d" % (W.ZINS_STUFEN * W.ZINS_JE_SCHRITT)]],
			"abschnitte": [
				["Nach jeder Runde", Stil.GOLD, [
					"Rundenbonus: %d + %d × Rundennummer (nach Runde 5 also %d)." % [W.BONUS_JE_WELLE, W.BONUS_ZUWACHS, W.wellen_bonus(5)],
					"Checkpoints: +%d je Checkpoint, der dir am Rundenende gehört." % W.BONUS_JE_CHECKPOINT,
					"Zinsen: je volle %d übriges Budget +%d, höchstens +%d (ab %d Budget)." % [W.ZINS_SCHRITT, W.ZINS_JE_SCHRITT, W.ZINS_STUFEN * W.ZINS_JE_SCHRITT, W.ZINS_STUFEN * W.ZINS_SCHRITT]]],
				["Während der Runde", Stil.GOLD, [
					"Jeder besiegte Gegner bringt sofort seine Prämie (steht auf seiner Karte). Klone geben nichts."]],
				["Ausgaben", Stil.LEUCHT, [
					"Jede weitere Fabrik kostet %s %% mehr als die vorige." % _z(W.KOSTEN_FABRIK_PROZENT),
					"Abriss (Rechtsklick): Was du in dieser Bauphase gebaut hast, gibt es voll zurück, Älteres zu %d %%." % int(W.ERSTATTUNG * 100),
					"Runde 1: nur Fabriken. Erdwälle gibt es ab Runde %d – die ersten %d davon gratis." % [W.WAELLE_AB_WELLE, W.STARTPAKET_WAELLE]]],
				["Tipp", Stil.TEXT_BLASS, ["+ Bis %d Budget lohnt Sparen – darüber wachsen die Zinsen nicht mehr." % (W.ZINS_STUFEN * W.ZINS_SCHRITT)]]]},
		{"name": "Verhalten", "unter": "so entscheiden deine Truppen selbst", "marke": "Regeln", "marke_farbe": Stil.TEXT_BLASS, "bild": _figur(W.EINHEITEN["technogunner"]),
			"werte": [["je Fabrik", "%d (St. 1: %d)" % [W.MAX_JE_FABRIK, W.MAX_JE_FABRIK + 1]], ["Nachbau", _z(W.PRODUKTION_SEK) + " s"], ["Endkampf", "%d je Fabrik" % W.MAX_JE_FABRIK_ENDKAMPF]],
			"abschnitte": [
				["Nachschub", Stil.LEUCHT, [
					"Jede Fabrik hält ihre Truppen am Leben: Fällt eine, baut sie nach %s Sekunden eine neue – kostenlos." % _z(W.PRODUKTION_SEK),
					"Freie Stellungen werden immer aufgefüllt, solange der Weg dorthin frei ist.",
					"Welche Stellungen eine Fabrik besetzt, legst du mit dem Zuweisungspfeil fest: Fabrik anklicken, Maustaste halten und auf eine Stellung ziehen."]],
				["Im Kampf", Stil.LEUCHT, [
					"In der Stellung schießen sie über die Erdwälle ihres Wallstücks, am Boden fangen sie Gegner am Boden ab.",
					"Geschossen wird nur auf Gegner in Reichweite und Sicht. Wen sie zuerst nehmen, stellst du im Fenster der Fabrik ein (Zielwahl).",
					"Durchgebrochene Gegner werden nicht verfolgt – um die kümmern sich Stellungen und Türme weiter hinten.",
					"Rundenende: Kommt nichts mehr nach, verlassen Truppen ohne Ziel ihre Stellung und jagen die letzten Gegner."]],
				["Checkpoints", Stil.LEUCHT, ["Je verlorenem Checkpoint geht eine Bodentruppe hin und holt ihn zurück."]],
				["Tipp", Stil.TEXT_BLASS, ["Klick auf eine Truppe zeigt ihre Reichweite und was sie darin nicht treffen kann."]]]},
		{"name": "Checkpoints", "unter": "zwei Fahnen auf dem Gegnerweg", "marke": "ab Runde %d" % W.CHECKPOINTS_AB_WELLE, "marke_farbe": Stil.KUPFER, "bild": _einzel(Werte.NEU + "gebaeude/checkpoint.png", Vector2(48, 48)),
			"werte": [["Einnahme", _z(W.EINNAHME_SEK) + " s"], ["Zurück", _z(W.RUECKEROBERUNG_SEK) + " s"], ["Bonus", "+%d" % W.BONUS_JE_CHECKPOINT]],
			"abschnitte": [["Regeln", Stil.LEUCHT, [
				"Sie liegen in jeder Partie etwas anders – deine Basis auch. Der Gegnerweg führt schon ab Runde 1 der Reihe nach durch beide; einnehmen können die Gegner sie erst ab Runde %d." % W.CHECKPOINTS_AB_WELLE,
				"Gegner bleiben darauf stehen, bis sie ihn eingenommen haben. Danach gehört er dem Gegner, und die nächste Welle startet dort.",
				"Zurückholen: Je verlorenem Checkpoint geht eine Bodentruppe hin und hält ihn – nur solange die Welle läuft und kurz danach.",
				"Jeder Checkpoint, der am Rundenende dir gehört, bringt +%d Budget." % W.BONUS_JE_CHECKPOINT]]]},
		{"name": "Zone und HQ", "unter": "die drei linken Spalten", "marke": "Runde %d" % W.LETZTE_RUNDE, "marke_farbe": Stil.KUPFER, "bild": _einzel(Werte.NEU + "gebaeude/myr_hq_gross.png", Vector2(128, 128)),
			"werte": [["HQ-Leben", _z(W.hq_leben())], ["Abstand", "%d Felder" % W.ZONE_ABSTAND]],
			"abschnitte": [["Regeln", Stil.LEUCHT, [
				"In der Zone kann nicht gebaut werden. Ein Schild schützt alles darin bis zur letzten Runde.",
				"Eigene Truppen halten Abstand zur Zone, damit die Gegner herauskommen.",
				"Runde %d hat zwei Teile: Erst wehrt ihr die Welle ganz normal ab. Dann fällt der Schild und es kommt der Gegenangriff: Das HQ muss fallen. Gegner kommen ohne Ende, je Fabrik bleibt nur eine Truppe in Stellung, und jede Fabrik hat bis zu %d aktive Truppen." % [W.LETZTE_RUNDE, W.MAX_JE_FABRIK_ENDKAMPF],
				"Ausgefallene Gebäude laufen dort nach einiger Zeit wieder an.",
				"Während des Gegenangriffs darfst du weiterbauen und ausbauen – nur keine neuen Erdwälle."]]]},
		# 18.11. (Etappe 2): Gelände mit Wirkung auf eigenen Karten aus dem Szenario-Editor
		{"name": "Gelände", "unter": "auf eigenen Karten", "marke": "Szenario", "marke_farbe": Stil.LEUCHT, "bild": _einzel(Werte.NEU + "kulisse/felsen.png", Vector2(96, 64)),
			"werte": [["Anhöhe", "+%s Reichweite" % _z(W.ANHOEHE_BONUS)], ["Sumpf", "%d %% Tempo" % roundi(W.SUMPF_TEMPO * 100.0)], ["Erzader", "+%d je Runde" % W.ERZ_BONUS]],
			"abschnitte": [["Gesperrt", Stil.TEXT_BLASS, [
				"Fels und Wasser: für niemanden begehbar, nicht bebaubar, Gegner reißen sie nie ein. Fels versperrt die Sicht, Wasser nicht."]],
				["Mit Wirkung (begehbar)", Stil.LEUCHT, [
				"Anhöhe: +%s Reichweite für Truppen, Stellungen und Türme darauf – auch für Gegner, nicht für Batterien." % _z(W.ANHOEHE_BONUS),
				"Sumpf: Gegner und Truppen laufen mit %d %% Tempo, zusammen mit Frost nie unter %d %%. Nicht bebaubar." % [roundi(W.SUMPF_TEMPO * 100.0), roundi(W.SUMPF_MIN_TEMPO * 100.0)],
				"Brücke: Weg über Wasser, nicht bebaubar – niemand kann sie zumauern.",
				"Ruine: Truppen darauf nehmen %d %% weniger Schaden von Sphären, Schleudern und Lasern. Nur Erdwälle, die kosten dort %d." % [roundi(W.RUINE_DECKUNG * 100.0), W.RUINE_KOSTEN_WALL],
				"Wald: versperrt die Sicht wie Fels (hineinschießen geht). Truppen im Wald sieht eine Battlesphäre erst aus %s Feldern. Nicht bebaubar." % _z(W.WALD_SICHT),
				"Erzader: Eine Fabrik oder ein Turm darauf bringt +%d Budget je Runde." % W.ERZ_BONUS,
				"Eis: Gegner und Truppen laufen mit %d %% Tempo. Bebaubar." % roundi(W.EIS_TEMPO * 100.0),
				"Minenfeld: Der erste Gegner darauf nimmt einmal %d Schaden, zur nächsten Runde liegt die Mine wieder. Nicht bebaubar." % roundi(W.MINE_SCHADEN)]]]},
	]

	# 20.11. (Nachtrag): Normalmodus (Gegner, Truppen, Bauten, Regeln, Anführer) und Brakk-Mode (Brakk, Irrtürmer, Sonde 7, Ringe)
	var brakk_karten := _held_karten("brakk")
	if Profil.rogue_frei():
		brakk_karten.append(NemesisGewohnheiten.lexikon_karte(Nemesis.gesehen_gesamt()))   # 22.11. (Paul, Nemesis Teil 4): Angewohnheiten und Konter, sobald gesehen
	_daten = [gegner, truppen, bauten, regeln, _anfuehrer_karten(), brakk_karten, _held_karten("irrtuermer"), _held_karten("sonde7"), _ring_karten()]
	for i in _wahl.size():
		_wahl[i] = clampi(_wahl[i], 0, maxi(0, (_daten[i] as Array).size() - 1))


## 19.11.: Reiter Regeln – je Anführer eine Karte mit Perks und Nachteilen (Texte aus anfuehrer.gd).
const ANFUEHRER_SYMBOL := {"brakk": "brakk", "irrtuermer": "turm", "sonde7": "stellung", "paul": "muenze"}

func _anfuehrer_karten() -> Array:
	var karten: Array = []
	for a: Dictionary in Anfuehrer.LISTE:
		var id := str(a["id"])
		var frei := Anfuehrer.frei(id)
		var abschnitte: Array = [["Perks", Stil.LEUCHT, a["perks"]], ["Nachteile", Stil.WARN, a["nachteile"]]]
		if id == "paul":
			abschnitte.append(["Aufträge (ab Runde %d)" % Auftraege.AB_RUNDE, Stil.GOLD, Auftraege.uebersicht()])   # 20.11.
		if not frei:
			abschnitte.append(["Freischalten", Stil.GOLD, [Anfuehrer.freischalt_text(id)]])
		karten.append({"name": "Anführer " + str(a["name"]), "unter": str(a["kurz"]), "marke": "Anführer" if frei else "gesperrt",
			"marke_farbe": Stil.LEUCHT if frei else Stil.TEXT_BLASS, "bild": {"symbol": str(ANFUEHRER_SYMBOL.get(id, "brakk")), "farbe": a["farbe"]},
			"werte": [["Rangliste", "ja" if bool(a["rangliste"]) else "nein"], ["Figur [8]", "Brakk" if id == "brakk" else "folgt"]],
			"abschnitte": abschnitte})
	return karten


# ------------------------------------------------------------------ Brakk-Mode: Fähigkeiten und Ringe (19.11.)

## Eine Karte im Reiter „Brakk“: ab welcher Stufe, Taste am PC, Knopf am Handy, was sie tut. Zahlen aus den Tabellen.
func _faehigkeit(name: String, unter: String, bild: Dictionary, ab: int, pc: String, handy: String, werte: Array, abschnitte: Array) -> Dictionary:
	# 19.11. (Paul): am PC nur die Taste, am Handy nur der Knopf
	var w: Array = [["ab Stufe", str(ab)], ["Knopf", handy] if Touch.noetig() else ["Taste", pc]]
	w.append_array(werte)
	return {"name": name, "unter": unter, "marke": "ab St. %d" % ab if ab > 1 else "von Anfang an", "marke_farbe": Stil.GOLD if ab > 1 else Stil.LEUCHT,
		"bild": bild, "werte": w, "abschnitte": abschnitte}


static func _liste(werte: Array) -> String:
	var t: Array[String] = []
	for v: Variant in werte:
		t.append(str(v))
	return ", ".join(t)


func _brakk_karten() -> Array:
	var E := EgoModus
	var B := BrakkFortschritt
	var kd: Dictionary = Werte.KOMMANDANT
	var ab: Dictionary = B.AB
	return [
		_faehigkeit("Pistolen", "zwei im Wechsel", _figur(kd, 2), 1, "Linksklick", "Fadenkreuz", [["Schaden", _z(E.SCHUSS_SCHADEN)], ["alle", _z2(E.SCHUSS_TAKT) + " s"], ["je Stufe", "+%d %%" % roundi(B.SCHADEN_JE_STUFE * 100.0)]], [
			["Wie sie schießen", Stil.LEUCHT, [
				"Links und rechts feuern abwechselnd. Grundschaden %s je Schuss, mal Stufenfaktor (×%s auf Stufe 1, je Stufe +%d %%) und den getragenen Ringen." % [_z(E.SCHUSS_SCHADEN), _z2(B.SCHADEN_START), roundi(B.SCHADEN_JE_STUFE * 100.0)],
				"Bei Dauerfeuer heizt jede Pistole auf (Bögen am Fadenkreuz). Ist eine überhitzt, ist sie kurz gesperrt und die andere schießt weiter.",
				"Am Handy: Liegt das Fadenkreuz auf einem Gegner, schießt Brakk von selbst – ohne Hitze. Zielen musst du.",
				"Das Werte-Fenster neben der Lebensleiste zeigt Schaden je Schuss, Schüsse je Sekunde, Schaden je Sekunde und woher jeder Bonus kommt; [Tab] zeigt Brakks Schaden je Quelle."]]]),
		_faehigkeit("Sprung", "Doppelsprung · Absprung", {"glyphe": "treppe", "farbe": Stil.LEUCHT}, 1, "Leertaste", "Sprung", [["Doppel ab", "St. %d" % int(ab["doppelsprung"])], ["Druckwelle", _z(E.DRUCK_SCHADEN)]], [
			["Springen", Stil.LEUCHT, [
				"Leertaste springt. Ab Stufe %d: in der Luft nochmal = Doppelsprung von einer Lichtplattform in der Farbe des aktiven Rings, einmal je Sprung." % int(ab["doppelsprung"]),
				"Wer in der Luft höher als die Mauerkrone ist, landet beim Hinüberfliegen oben auf dem Wall."]],
			["Absprung vom Wall", Stil.GOLD, [
				"Oben auf dem Wall zweimal springen: Brakk fliegt in Laufrichtung (sonst Blickrichtung) hinunter und schlägt mit einer Druckwelle ein – %s × Fähigkeitsschaden im Umkreis von %s Feldern." % [_z(E.DRUCK_SCHADEN), _z(E.DRUCK_RADIUS)]]]]),
		_faehigkeit("Lichttreppe", "auf den Wall · Lichtbrücke", {"glyphe": "treppe", "farbe": Stil.LEUCHT}, 1, "E", "Treppe", [["Weite", _z(E.TREPPE_WEITE) + " Felder"], ["steht", _z(E.TREPPE_HALTEN) + " s"], ["Brücke", _z(E.BRUECKE_ABKLING) + " s"]], [
			["Hinauf", Stil.LEUCHT, [
				"[E] mit Blick auf einen Erdwall (bis %s Felder): eine Lichttreppe baut sich auf, hinlaufen = hinauf. Aus der Ferne gesetzt wird sie bis zu %d Felder länger. Oben: mehr Reichweite." % [_z(E.TREPPE_WEITE), E.TREPPE_LAENGER]]],
			["Oben auf dem Wall", Stil.GOLD, [
				"[E] mit Blick auf einen anderen Wall (bis %s Felder): Lichtbrücke hinüber, %s s begehbar, %s s Cooldown. Am Fadenkreuz steht, was [E] gerade tut." % [_z(E.BRUECKE_WEITE), _z(E.BRUECKE_HALTEN), _z(E.BRUECKE_ABKLING)],
				"Sonst führt [E] eine Treppe hinunter – oder zweimal springen für den Absprung."]]]),
		_faehigkeit("Tumble", "Hechtrolle", {"glyphe": "tumble", "farbe": Stil.LEUCHT}, int(ab["tumble"]), "Shift", "Rolle", [["Weite", _z(E.TUMBLE_FELDER) + " Felder"], ["Cooldown", _z(E.TUMBLE_ABKLING) + " s"]], [
			["Ausweichen", Stil.LEUCHT, [
				"Rolle in Laufrichtung (ohne Taste nach vorn), %s Felder, kurz unverwundbar – gegen Steine der Schleudern (roter Landekreis)." % _z(E.TUMBLE_FELDER),
				"Danach läuft Brakk %s s lang %s-mal so schnell (Nachschwung)." % [_z(E.SCHWUNG_SEK), _z(E.SCHWUNG_MAL)]]],
			["Tumble-Schuss", Stil.GOLD, [
				"Der erste Schuss nach der Rolle (innerhalb %s s) macht ×%s Schaden, gegen große Gegner (%s) ×%s – mit goldenem Strahl." % [_z(B.TUMBLE_SCHUSS["fenster"]), _z(B.TUMBLE_SCHUSS["mal"]), _gross_namen(), _z(B.TUMBLE_SCHUSS["mal_gross"])],
				"Tötet er einen großen Gegner, ist die Rolle sofort wieder bereit."]]]),
		_faehigkeit("Lichtanker", "werfen, ziehen, schwingen", {"glyphe": "anker", "farbe": Stil.LEUCHT}, int(ab["anker"]), "Q", "Anker", [["Weite", _z(E.ANKER_WEITE) + " Felder"], ["hängt", _z(E.HAKEN_HALTEN) + " s"], ["Cooldown", _z(E.ANKER_ABKLING) + " s"]], [
			["Zwei Stufen", Stil.LEUCHT, [
				"Erstes [Q]: der Haken fliegt an Mauerkrone oder Boden unter dem Fadenkreuz (bis %s Felder) und hängt %s s – das Seil hält Brakk wie eine Leine." % [_z(E.ANKER_WEITE), _z(E.HAKEN_HALTEN)],
				"Zweites [Q]: Brakk wird hingezogen, an einer Mauer landet er oben.",
				"Dazwischen: laufen und springen = um den Haken schwingen. In der Luft nochmal springen löst das Seil – Brakk schnellt mit dem Schwung weiter.",
				"Der Cooldown läuft ab dem Lösen."]]]),
		_faehigkeit("Ladestrahl", "geladener Durchschuss", {"glyphe": "lanze", "farbe": Stil.LEUCHT}, int(ab["lanze"]), "RMB halten", "Strahl", [["Schaden", _z(E.LANZE_SCHADEN)], ["+ max. Leben", "%d %%" % roundi(float(B.LANZE_ANTEIL["normal"]) * 100.0)], ["Cooldown", _z(E.LANZE_ABKLING) + " s"]], [
			["Laden und loslassen", Stil.LEUCHT, [
				"Rechtsklick halten lädt (%s s), loslassen feuert einen Strahl durch alle Gegner auf der Linie (bis %s Felder). Er lässt die Hitze der Pistolen ab – je heißer, desto stärker. Am Handy ohne Hitze: fest ×%s." % [_z(E.LANZE_LADEN), _z(E.LANZE_WEITE), _z(E.LANZE_TOUCH)]]],
			["Fürs späte Spiel", Stil.GOLD, [
				"Zusätzlich nimmt er jedem getroffenen Gegner %d %% seines maximalen Lebens, großen Gegnern (%s) %d %% – so bleibt er auch gegen zähe Gegner in späten Runden stark." % [roundi(float(B.LANZE_ANTEIL["normal"]) * 100.0), _gross_namen(), roundi(float(B.LANZE_ANTEIL["gross"]) * 100.0)]]],
			["Ringe", Stil.GOLD, [
				"Ein reiner Schadensschuss: Von den Ringen wirken nur der Glutstrahlring (mehr Schaden) und der Gelring (Bonus gegen Gebremste) – und nur, wenn er der aktive Ring ist."]]]),
		_faehigkeit("Lichtsäule", "Einschlag von oben", {"glyphe": "saeule", "farbe": Stil.LEUCHT}, int(ab["saeule"]), "X + Klick", "Säule", [["Schaden", _z(E.SAEULE_SCHADEN)], ["Weite", _z(E.SAEULE_WEITE) + " Felder"], ["Cooldown", _z(E.SAEULE_ABKLING) + " s"]], [
			["Zielen und setzen", Stil.LEUCHT, [
				"[X] zielt (Marke am Boden), Linksklick setzt, Rechtsklick bricht ab. Nach %s s schlägt die Säule ein: %s × Fähigkeitsschaden im Umkreis von %s Feldern." % [_z(E.SAEULE_VORLAUF), _z(E.SAEULE_SCHADEN), _z(E.SAEULE_RADIUS)],
				"Die Art hängt vom aktiven Ring ab."]],
			["Ringe (aktiver Ring)", Stil.GOLD, _brakk_ring_zeilen("saeule")]]),   # 20.11. (Nachtrag): aus dem Reiter Ringe hierher
		_faehigkeit("Klonmaschine", "Ultimative", {"glyphe": "ulti", "farbe": Stil.GOLD}, int(ab["ulti"]), "R", "Klon", [["lädt durch", "%d Kills" % B.ULTI_KILLS]], [
			["Klonen", Stil.LEUCHT, [
				"Lädt durch %d eigene Kills. [R] setzt die Klonmaschine auf das Feld im Blick: Wer hindurchgeht, wird einmal geklont – auch Gegner. Danach eine ganze Runde Pause." % B.ULTI_KILLS]]]),
		_faehigkeit("Zeitlupe", "die Welt wird langsam", {"glyphe": "zeitlupe", "farbe": Stil.LEUCHT}, int(ab["zeitlupe"]), "V", "Zeitlupe", [["Dauer", _z(E.ZEITLUPE_SEK) + " s"], ["Tempo", "×" + _z(E.ZEITLUPE_TEMPO)], ["Cooldown", _z(E.ZEITLUPE_ABKLING) + " s"]], [
			["Langsam", Stil.LEUCHT, [
				"%s s lang läuft alles außer Brakk mit %d %% Tempo – Brakk selbst bleibt schnell." % [_z(E.ZEITLUPE_SEK), roundi(E.ZEITLUPE_TEMPO * 100.0)]]],
			["Ringe (aktiver Ring)", Stil.GOLD, _brakk_ring_zeilen("zeitlupe")]]),   # 20.11. (Nachtrag)
		_faehigkeit("Ringe an der Hand", "Finger · Lichtterminal", {"tex": RingBilder.bild("laser", Einheit.ABZEICHEN.get("laser", Stil.GOLD)), "zelle": Vector2(16, 16), "reihe": 0, "n": 1}, 1, "F · C", "Ringe · Feld", [["Preise", _liste(B.RING_PREISE).replace(", ", "/")]], [
			["Kaufen", Stil.LEUCHT, [
				"[F] an der Basis in der Bauphase öffnet das Lichtterminal. Ring kaufen und auf Stufe 2 und 3 ausbauen. Ein Finger je Ring, frei ab Stufe %s." % _liste(B.FINGER_AB),
				"Alle getragenen Ringe wirken zusammen auf Brakks Schüsse. Das Mausrad wählt den aktiven Ring: er bestimmt Lichtsäule, Ladestrahl, Zeitlupe, die Farben und das Feld."]],
			["Ringfeld [C]", Stil.GOLD, [
				"In der Bauphase setzt [C] das Feld des aktiven Rings: 2×2 Felder, höchstens 4 Fabriken. Fabriken darin bauen die Truppe des Rings auf seiner Stufe."]]]),
	]


## 20.11. (Nachtrag): Brakks Ring-Wirkung an Lichtsäule bzw. Zeitlupe (früher im Reiter Ringe) – je Ring eine Zeile.
func _brakk_ring_zeilen(spell: String) -> Array:
	var zeilen: Array = []
	for r: String in BrakkFortschritt.RINGE:
		var d: Dictionary = BrakkFortschritt.RINGE[r]
		var text := str(d.get("saeule", "normaler Einschlag")) if spell == "saeule" else BrakkFortschritt.zeitlupe_text(r)
		zeilen.append("%s: %s" % [str(d["name"]), text])
	return zeilen


## Namen der großen Gegner (Werte.GEGNER "gross").
static func _gross_namen() -> String:
	var n: Array[String] = []
	for id: String in Werte.GEGNER:
		if bool((Werte.GEGNER[id] as Dictionary).get("gross", false)):
			n.append(str(Werte.GEGNER[id]["name"]))
	return ", ".join(n)


## 20.11. (Paul, Nachtrag): Reiter „Ringe“ – nur Allgemeines (Lichtterminal, Stufen, Preise, Ringfeld [C], Truppe im Feld,
## Färbung des Grundschusses). Was ein Ring an den Fähigkeiten eines Helden ändert, steht auf dessen Seite.
func _ring_karten() -> Array:
	var B := BrakkFortschritt
	var karten: Array = [
		{"name": "Ringe", "unter": "Lichtterminal · Ringfeld", "marke": "alle Helden", "marke_farbe": Stil.GOLD,
			"bild": {"tex": RingBilder.bild("laser", Einheit.ABZEICHEN.get("laser", Stil.GOLD)), "zelle": Vector2(16, 16), "reihe": 0, "n": 1},
			"werte": [["Kauf", str(B.RING_PREISE[0])], ["St. 2", "+%d" % B.RING_PREISE[1]], ["St. 3", "+%d" % B.RING_PREISE[2]], ["Feld", "%d×%d" % [B.FELD_GROESSE, B.FELD_GROESSE]]],
			"abschnitte": [
				["Kaufen und ausbauen", Stil.LEUCHT, [
					"[F] an der Basis in der Bauphase öffnet das Lichtterminal: Ring kaufen (%d) und auf Stufe 2 (+%d) und 3 (+%d) ausbauen. Verkaufen gibt %d %% zurück, in derselben Bauphase alles." % [B.RING_PREISE[0], B.RING_PREISE[1], B.RING_PREISE[2], roundi(B.RING_ZURUECK * 100.0)],
					"Wie viele Ringe ein Held trägt, steht auf seiner Seite."]],
				["Grundschuss", Stil.GOLD, [
					"Alle getragenen Ringe färben den Grundschuss des Helden – jeder auf seiner Stufe (siehe die Karte des Rings).",
					"Das Mausrad wählt den aktiven Ring: er bestimmt, was die Fähigkeiten des Helden zusätzlich tun (Abschnitt „Ringe“ je Fähigkeit)."]],
				["Ringfeld [C]", Stil.LEUCHT, [
					"In der Bauphase setzt [C] das Feld des aktiven Rings: %d×%d Felder, höchstens 4 Fabriken. Fabriken darin bauen die Truppe des Rings auf seiner Stufe, im Kampf liegt das Feld fest." % [B.FELD_GROESSE, B.FELD_GROESSE]]]]},
	]
	for r: String in B.RINGE:
		var d: Dictionary = B.RINGE[r]
		var stufen: Array = d["brakk_stufen"]
		var truppe: String = d["truppe"]
		var tname := str(Werte.EINHEITEN[truppe]["name"])
		var f3 := str(((Werte.STUFE_3[truppe] as Dictionary).get(r, {}) as Dictionary).get("name", r))
		var farbe: Color = Einheit.ABZEICHEN.get(r, Stil.GOLD)
		var schuss: Array = []
		for i in 3:
			schuss.append("St. %d: %s" % [i + 1, str(stufen[i]["text"])])
		var s3: Dictionary = (Werte.STUFE_3[truppe] as Dictionary).get(r, {})
		karten.append({"name": str(d["name"]).trim_suffix("ring"), "unter": str(d["name"]), "marke": tname, "marke_farbe": farbe,
			"kachel_oben": tname,
			"bild": {"tex": RingBilder.bild(r, farbe), "zelle": Vector2(16, 16), "reihe": 0, "n": 1},
			"werte": [["Kauf", str(B.RING_PREISE[0])], ["St. 2", "+%d" % B.RING_PREISE[1]], ["St. 3", "+%d" % B.RING_PREISE[2]], ["Truppe", tname]],
			"abschnitte": [
				["Grundschuss", Stil.LEUCHT, schuss],
				["Truppe im Ringfeld", Stil.GOLD, ["Fabriken im Feld bauen %s auf der Ringstufe, auf Stufe 3 mit %s." % [tname, f3]]],
				["Wann stark", Stil.LEUCHT, ["Stark: %s" % str(s3.get("stark", "–")), "Schwach: %s" % str(s3.get("schwach", "–"))]],
			]})
	return karten


## 20.11. (Nachtrag): Abschnitt „Ringe“ einer Fähigkeit – aus Werte.RING_SPELLS erzeugt (aktiver Ring, Werte auf Stufe 1).
func _ring_spell_abschnitt(af: String, spell: String) -> Array:
	var zeilen: Array = []
	var ohne: Array[String] = []
	for r: String in BrakkFortschritt.RINGE:
		var e := Werte.ring_spell(af, spell, r)
		var name := str(BrakkFortschritt.RINGE[r]["name"])
		if e.is_empty():
			ohne.append(name.trim_suffix("ring"))
		else:
			zeilen.append("%s: %s" % [name, Werte.ring_spell_text(e, 1)])
	if zeilen.is_empty():
		return ["Ringe", Stil.GOLD, ["Kein Ring ändert diese Fähigkeit."]]
	zeilen.append("Werte auf Ringstufe 1, je Stufe darüber +%d %%." % roundi(Werte.RING_SPELL_JE_STUFE * 100.0))
	if not ohne.is_empty():
		zeilen.append("Keine Wirkung: " + ", ".join(ohne) + ".")
	return ["Ringe (aktiver Ring)", Stil.GOLD, zeilen]


## Taste einer Aktion beim Anführer (für die Karten).
static func _taste(af: String, was: String) -> String:
	var tasten: Dictionary = Werte.ANFUEHRER_EGO[af]["tasten"]
	for t: String in tasten:
		if str(tasten[t]) == was:
			return str(Werte.EGO_TASTEN_NAME.get(t, t))
	return "–"


## Fähigkeitskarte eines Helden (wie bei Brakk): ab Stufe aus Werte.ANFUEHRER_EGO[…]["ab"], dazu der Ring-Abschnitt.
func _held_faehigkeit(af: String, was: String, name: String, unter: String, werte: Array, abschnitte: Array, mit_ringen: bool = true) -> Dictionary:
	var ab := int(BrakkFortschritt.ab_tabelle(af).get(was, 1))
	var a := Anfuehrer.eintrag(af)
	var liste := abschnitte.duplicate()
	if mit_ringen:
		liste.append(_ring_spell_abschnitt(af, was))
	var k := _faehigkeit(name, unter, {"glyphe": was if EgoModus.GLYPHEN.has(was) else "treppe", "farbe": a["farbe"]}, ab, _taste(af, was), "–", werte, liste)
	return k


## 20.11. (Nachtrag): Seite eines Helden im Brakk-Mode – erst eine Karte mit Kit, Tasten und Titeln, dann seine Fähigkeiten.
## Gesperrt: nur ein Fragezeichen mit dem Erfolg, der ihn freischaltet.
func _held_karten(af: String) -> Array:
	var a := Anfuehrer.eintrag(af)
	if not Anfuehrer.frei(af):
		return [{"name": "?", "unter": "noch gesperrt", "marke": "gesperrt", "marke_farbe": Stil.TEXT_BLASS,
			"bild": {"symbol": "buch", "farbe": Stil.TEXT_BLASS}, "werte": [],
			"abschnitte": [["Freischalten", Stil.GOLD, [Anfuehrer.freischalt_text(af) + " (im Normalmodus)."]]]}]
	var karten: Array = [_held_uebersicht(af)]
	match af:
		"brakk":
			karten.append_array(_brakk_karten())
		"irrtuermer":
			karten.append_array(_irrtuermer_karten())
		"sonde7":
			karten.append_array(_sonde_karten())
	return karten


func _held_uebersicht(af: String) -> Dictionary:
	var a := Anfuehrer.eintrag(af)
	var d: Dictionary = Werte.ANFUEHRER_EGO[af]
	var tasten: Array[String] = []
	for t: String in Werte.EGO_TASTEN:
		var was := str((d["tasten"] as Dictionary).get(t, ""))
		if was != "":
			var ab := int(BrakkFortschritt.ab_tabelle(af).get(was, 1))
			tasten.append("%s: %s%s" % [str(Werte.EGO_TASTEN_NAME.get(t, t)), str(Werte.EGO_AKTIONEN.get(was, was)), (" (ab Stufe %d)" % ab) if ab > 1 else ""])
	var titel: Array[String] = []
	for r: Array in BrakkFortschritt.TITEL_JE.get(af, BrakkFortschritt.TITEL):
		titel.append("%s – %s" % [str(r[0]), str(r[3])])
	return {"name": str(a["name"]), "unter": "im Brakk-Mode", "marke": "Held", "marke_farbe": a["farbe"],
		"bild": {"symbol": str(ANFUEHRER_SYMBOL.get(af, "brakk")), "farbe": a["farbe"]},
		"werte": [["Leben", "%d %%" % roundi(float(d["leben"]) * 100.0)], ["Tempo", "%d %%" % roundi(float(d["tempo"]) * 100.0)]],
		"abschnitte": [["Kit", Stil.LEUCHT, d["kit"]], ["Tasten", Stil.GOLD, tasten], ["Spielstil-Titel", Stil.LEUCHT, titel]]}


# ------------------------------------------------------------------ Brakk-Mode: Anführer (20.11.)

## 20.11.: Pfad des PliPlop mit diesem Ring – aus Werte.PLIPLOP_PFADE erzeugt.
static func _pfad_text(ring: String) -> String:
	var p: Dictionary = Werte.PLIPLOP_PFADE.get(ring, Werte.PLIPLOP_PFADE[""])
	var art := ""
	match str(p["art"]):
		"einzel":
			art = "ein Ziel bis %s Felder" % _z(p["weite"])
		"mehr":
			art = "%d Ziele bis %s Felder" % [int(p.get("ziele", 2)), _z(p["weite"])]
		"welle":
			art = "alle im Umkreis von %s Feldern um ihn" % _z(p["weite"])
		"flaeche":
			art = "Einschlag mit %s Feldern Radius, bis %s Felder" % [_z(p.get("radius", 0.6)), _z(p["weite"])]
		"linie":
			art = "durch alle in einer Linie, %s Felder" % _z(p["weite"])
		"sprung":
			art = "springt auf %d weitere" % int(p.get("spruenge", 2))
	var zusatz: Array[String] = []
	if p.has("bremse"):
		zusatz.append("bremst %s s" % _z(p["bremse"]))
	if bool(p.get("brand", false)):
		zusatz.append("legt ein Brandfeld")
	if p.has("schutz"):
		zusatz.append("PliPlop nimmt %d %% weniger Schaden" % roundi(float(p["schutz"]) * 100.0))
	return "%s: %s, %s Schaden alle %s s%s." % [str(p["name"]), art, _z(p["schaden"]), _z2(p["takt"]), (", " + ", ".join(zusatz)) if not zusatz.is_empty() else ""]


static func _verbund_text() -> String:
	var v: Dictionary = Werte.IRRTUERMER["verbund"]
	return "Treffen die Effekte der beiden aktiven Ringe (Irrtürmer und PliPlop) denselben Gegner innerhalb von %s s, nimmt er +%d %% Schaden." % [_z(v["fenster"]), roundi((float(v["bonus"]) - 1.0) * 100.0)]


func _irrtuermer_karten() -> Array:
	var I: Dictionary = Werte.IRRTUERMER
	var b: Dictionary = I["bolzen"]
	var h: Dictionary = I["hack"]
	var u: Dictionary = I["ueberladen"]
	var au: Dictionary = I["aufsatz"]
	var pp: Dictionary = I["pliplop"]
	var pfade: Array = []
	for r: String in BrakkFortschritt.RINGE:
		pfade.append("%s → %s" % [str(BrakkFortschritt.RINGE[r]["name"]), _pfad_text(r)])
	pfade.push_front("ohne Ring → " + _pfad_text(""))
	pfade.append("Je Ringstufe des aktiven Rings +%d %% Schaden; dazu wirken alle Ringe des PliPlop-Satzes (wie beim Grundschuss)." % roundi(Werte.PLIPLOP_JE_STUFE * 100.0))
	var A := "irrtuermer"
	return [
		_held_faehigkeit(A, "prellbolzen", "Prellbolzen", "Grundangriff", [["Schaden", _z(b["schaden"])], ["alle", _z2(b["takt"]) + " s"], ["Abpraller", str(b["abpraller"])]], [
			["Bolzen", Stil.LEUCHT, ["Fliegt durchs Fadenkreuz, prallt bis zu %d× von Mauern ab und platzt am Gegner (Fläche %s Felder)." % [int(b["abpraller"]), _z(b["flaeche"])],
				"Platzt er höchstens %s Feld vom PliPlop entfernt, stößt er Nahkämpfer im Umkreis von %s Feldern %s Felder weg." % [_z(b["stoss_naehe"]), _z(b["stoss_radius"]), _z(b["stoss"])]]],
			["Ringe", Stil.GOLD, ["Alle Ringe des Irrtürmer-Satzes färben ihn (Grundschuss, siehe Reiter Ringe); derselbe Ring mehrfach wirkt mehrfach."]]], false),
		_held_faehigkeit(A, "tumble", "Rolle", "Hechtrolle wie Brakk", [], [["Ausweichen", Stil.LEUCHT, ["Rolle in Laufrichtung, kurz unverwundbar."]]], false),
		_held_faehigkeit(A, "hierher", "Hierher!", "PliPlop schicken", [], [["Befehl", Stil.LEUCHT, ["Der PliPlop rollt zum Fadenkreuz und bleibt dort; nochmal: er folgt wieder. Die Ring-Wirkung gilt, solange er dort steht."]]]),
		_held_faehigkeit(A, "hack", "Hack", "Rechtsklick halten", [["Weite", _z(h["weite"]) + " Felder"], ["Tempo", "%d %%" % roundi(float(h["tempo"]) * 100.0)]], [
			["Fremder Schuss", Stil.LEUCHT, ["Strahl auf Formturm, Batterie oder PliPlop: solange gehalten, schießt du dessen Schuss aus der Hand, der Turm feuert weiter. Kein Cooldown, beim Halten langsamer.",
				"Funkturm: kein eigener Schuss, aber deine Bolzen fliegen schneller. Heilturm: heilt dich und den PliPlop.",
				"Die Treffereffekte deiner Ringe (Markierung, Bremse, Brand, Sprung) wirken auch auf Hack-Treffer."]]]),
		_held_faehigkeit(A, "ueberladen", "Überladen", "Turm oder PliPlop", [["Dauer", _z(u["sek"]) + " s"], ["Cooldown", _z(u["abkling"]) + " s"], ["Takt", "×" + _z(u["mal"])]], [
			["Doppelt so schnell", Stil.LEUCHT, ["PliPlop oder der gehackte Turm feuert %s s lang %s-mal so schnell. Nicht während des Aufsatzes." % [_z(u["sek"]), _z(u["mal"])]]]]),
		_held_faehigkeit(A, "ringtausch", "Ringtausch", "aktive Ringe tauschen", [], [
			["Tausch", Stil.LEUCHT, ["Der aktive Ring des Irrtürmers und der aktive Ring des PliPlop tauschen die Plätze (mit Stufe) – der Pfad des PliPlop wechselt mit. Es zählt der Ring des Irrtürmers vor dem Tausch."]]]),
		_held_faehigkeit(A, "aufsatz", "Aufsatz", "PliPlop am Arm", [["Dauer", _z(au["sek"]) + " s"], ["Tempo", "%d %%" % roundi(float(au["tempo"]) * 100.0)], ["danach leer", _z(au["leer"]) + " s"]], [
			["Einmal je Runde", Stil.LEUCHT, ["Der PliPlop dockt am Arm an, %s s feuerst du seinen Pfad im Takt der Hand, %d %% langsamer. Danach ist er %s s leer. Währenddessen kein Hack, kein Überladen." % [_z(au["sek"]), roundi((1.0 - float(au["tempo"])) * 100.0), _z(au["leer"])]]]]),
		_held_faehigkeit(A, "treppe", "Lichttreppe", "auf den Wall", [], [["Hinauf", Stil.LEUCHT, ["Wie bei Brakk: [E] mit Blick auf einen Erdwall baut eine Treppe hinauf."]]], false),
		_ego_karte(A, "PliPlop 3cK", "rollender Begleitturm", [["Leben", "%d %%" % roundi(float(pp["leben"]) * 100.0)], ["Abstand", _z(pp["abstand"]) + " Felder"], ["zurück", _z(pp["respawn"]) + " s"]], [
			["Gefährte", Stil.LEUCHT, ["Ab Runde 1 dabei, rollt von selbst hinter dir her. Fällt er, ist er nach %s s neben dir wieder da; fällst du, fällt er mit." % _z(pp["respawn"])]],
			["Zwei Ringsätze", Stil.GOLD, ["Irrtürmer und PliPlop tragen je bis zu %d Ringe, derselbe Ring auch mehrfach (wirkt mehrfach). Preise wie bei Brakk. Kauf im Terminal: „für Irrtürmer“ oder „für PliPlop“." % BrakkFortschritt.SATZ_MAX]],
			["Pfad je Ring (aktiver Ring des PliPlop)", Stil.LEUCHT, pfade]]),
		_ego_karte(A, "Verbund", "Ring-Signatur", [["Fenster", _z(I["verbund"]["fenster"]) + " s"], ["Bonus", "+%d %%" % roundi((float(I["verbund"]["bonus"]) - 1.0) * 100.0)]], [
			["Eine Regel", Stil.LEUCHT, [_verbund_text(), "Eigenes Treffer-Bild (zwei Ringe in den Farben beider), eigene Zeile im Werte-Fenster und im Schaden nach Quelle."]]]),
	]


func _ego_karte(wer: String, name: String, unter: String, werte: Array, abschnitte: Array) -> Dictionary:
	var a := Anfuehrer.eintrag(wer)
	return {"name": name, "unter": unter, "marke": str(a["name"]), "marke_farbe": a["farbe"],
		"bild": {"symbol": str(ANFUEHRER_SYMBOL.get(wer, "brakk")), "farbe": a["farbe"]}, "werte": werte, "abschnitte": abschnitte}


func _sonde_karten() -> Array:
	var S: Dictionary = Werte.SONDE7
	var sw: Dictionary = S["schweben"]
	var ha: Dictionary = S["hand"]
	var dl: Dictionary = S["doppellaser"]
	var sr: Dictionary = S["schrot"]
	var sg: Dictionary = S["sondengewehr"]
	var ls: Dictionary = S["luftschlag"]
	var hz: Dictionary = S["hitze"]
	var A := "sonde7"
	return [
		_held_faehigkeit(A, "hand_links", "Hand", "Farblaser · Energiebündel", [["Laser", _z(ha["laser_schaden"]) + " / " + _z2(ha["laser_takt"]) + " s"], ["Bündel", _z(ha["buendel_schaden"])], ["Hitze", _z(hz["sek"]) + " s"]], [
			["Links: Farblaser", Stil.LEUCHT, ["Dauerstrahl in der Farbe des aktiven Rings. Nach %s s Dauerfeuer (ab Stufe %d: %s s) überhitzt er, dann %s s Pause; ohne Feuern kühlt er doppelt so schnell ab. Hitzebalken an der Waffe." % [_z(hz["sek"]), int(hz["spaet_ab"]), _z(hz["sek_spaet"]), _z(hz["pause"])]]],
			["Rechts: Energiebündel", Stil.GOLD, ["Langsames Geschoss, platzt in kleiner Fläche (%s Felder) und trägt den Effekt aller getragenen Ringe (Grundschuss, siehe Reiter Ringe)." % _z(ha["buendel_flaeche"])]]], false),
		_held_faehigkeit(A, "schweben", "Düsen", "Schweben", [["Akku", _z(sw["akku"]) + " s"], ["lädt", _z(sw["laden"]) + " s"], ["Höhe", _z(sw["hoehe"]) + " Felder"]], [
			["Schweben", Stil.LEUCHT, ["Leertaste halten: steigen und schweben, loslassen: sinken, zweimal tippen: fallen lassen. Der Akku hält %s s und lädt am Boden in %s s." % [_z(sw["akku"]), _z(sw["laden"])],
				"In der Luft sehen dich alle Fernkämpfer, Nahkämpfer erreichen dich nicht."]]], false),
		_held_faehigkeit(A, "schub", "Schub", "Dash", [["Weite", _z(S["schub"]["felder"]) + " Felder"], ["Cooldown", _z(S["schub"]["abkling"]) + " s"]], [
			["Dash", Stil.LEUCHT, ["Kurzer Dash in Blickrichtung, auch in der Luft, kostet Akku."]]]),
		_held_faehigkeit(A, "doppellaser", "Doppel-Lasergewehr", "rufen", [["Magazin", str(dl["magazin"])], ["Cooldown", _z(dl["abkling"]) + " s"], ["Erfassen", _liste(dl["erfassen"]).replace(", ", "/")]], [
			["Links", Stil.LEUCHT, ["Dauerfeuer (%s Schaden), überhitzt wie der Farblaser." % _z(dl["schaden"])]],
			["Rechts: Zielerfassung", Stil.GOLD, ["Erfasst %s Gegner (ab Stufe %s) für %s s; jeder Schuss geht reihum an das nächste erfasste Ziel (×%s)." % [_liste(dl["erfassen"]).replace(", ", "/"), _liste(dl["erfassen_ab"]).replace(", ", "/"), _z(dl["erfassen_sek"]), _z(dl["erfassung_mal"])]]]]),
		_held_faehigkeit(A, "teleport", "Teleport", "Blink", [["Weite", _z(S["teleport"]["weite"]) + " Felder"], ["Cooldown", _z(S["teleport"]["abkling"]) + " s"]], [
			["Blink", Stil.LEUCHT, ["Zum Fadenkreuz, durch Wände, bis %s Felder. Nicht während des Luftschlags." % _z(S["teleport"]["weite"])]]]),
		_held_faehigkeit(A, "schrot", "Schrotflinte", "rufen", [["Magazin", str(sr["magazin"])], ["Cooldown", _z(sr["abkling"]) + " s"], ["Kugeln", str(sr["kugeln"])]], [
			["Links", Stil.LEUCHT, ["Ein Schuss: %d Kugeln à %s Schaden, breit und kurz (%s Felder)." % [int(sr["kugeln"]), _z(sr["schaden"]), _z(sr["weite"])]]],
			["Rechts", Stil.GOLD, ["Das ganze Magazin auf einmal – der Rückstoß wirft dich eine Mauerhöhe nach hinten oben, ohne Akku. Danach %s s Nachladen." % _z(sr["nachladen"])]]]),
		_held_faehigkeit(A, "sondengewehr", "Sondengewehr", "rufen", [["Magazin", str(sg["magazin"])], ["Cooldown", _z(sg["abkling"]) + " s"], ["Schaden", _z(sg["schaden"])]], [
			["Links", Stil.LEUCHT, ["Halten lädt (%s s), loslassen: Durchschlag durch alle Gegner in einer Linie (%s Felder)." % [_z(sg["laden"]), _z(sg["weite"])]]],
			["Rechts: Sondenblick", Stil.GOLD, ["%s s lang Gegner im Umkreis von %s Feldern durch Wände sichtbar; so gesehene nehmen von Truppen +%d %% Schaden." % [_z(sg["blick_sek"]), _z(sg["blick_weite"]), roundi((float(sg["blick_bonus"]) - 1.0) * 100.0)]]]]),
		_held_faehigkeit(A, "luftschlag", "Luftschlag", "einmal je Runde", [["Granaten", str(ls["magazin"])], ["Dauer", _z(ls["sek"]) + " s"], ["Schaden", _z(ls["schaden"])]], [
			["Von oben", Stil.LEUCHT, ["%s s schweben ohne Akku (steigt auf %s Felder), Granatwerfer mit %d Granaten: %s Schaden im Umkreis von %s Feldern. Kein Teleport währenddessen." % [_z(ls["sek"]), _z(ls["hoehe"]), int(ls["magazin"]), _z(ls["schaden"]), _z(ls["radius"])]]]]),
	]
