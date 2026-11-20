class_name ModLeiste
extends Control
## 18.11.: Mod-HUD – frei bestückbare Werkzeugleiste im Stil der Sandbox-Leiste (Metall, VT323, UI-Raster 640×360,
## zweifach skaliert). Wer sie benutzt, setzt `inhalt`: ein Aufruf, der jedes Bild die Einträge neu baut
## (kopf, reiter, abschnitt, chips, schalter, zeile, knopf, text). Klicks gehen an die Aktion des Eintrags.
## Zuerst für den Szenario-Editor; gedacht auch für spätere Modi (Sandbox, Mod-Werkzeuge).
## Dazu `Tafel`: ein Fenster in der Mitte mit Titel, Text und Knöpfen (z. B. Einführung eines Szenarios).

const Stil := preload("res://scripts/ui/ui_stil.gd")
const ZEILE := 12.0
const GOLD_HELL := Color("ffe9a8")

var inhalt: Callable              # inhalt.call(leiste) baut die Einträge
var vor_klick: Callable           # wird vor jeder Aktion gerufen (z. B. Stand für „Rückgängig“ merken)
var breite := 150.0
var links := true                 # links am Rand (sonst rechts)
var oben := 32.0                  # Abstand vom oberen Rand (UI-Pixel)
var farbe := GOLD_HELL            # Titel- und Rahmenfarbe
var _maus := Vector2(-100, -100)
var _knoepfe: Array = []          # [Rechteck, Aktion, Rechtsklick-Aktion]
var _y := 0.0


func _ready() -> void:
	scale = Vector2(Stil.UI_SKALA, Stil.UI_SKALA)
	mouse_filter = Control.MOUSE_FILTER_STOP


func _process(_delta: float) -> void:
	if not visible:
		return
	_maus = get_local_mouse_position()
	position = Vector2((6.0 if links else 640.0 - 6.0 - breite) * Stil.UI_SKALA, oben * Stil.UI_SKALA)
	queue_redraw()


## Liegt der Punkt (Bildschirm) auf der Leiste? Für Eingaben, die sonst an die Karte gingen.
func ueber(bildschirm: Vector2) -> bool:
	return visible and get_global_rect().has_point(bildschirm)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
		for k: Array in _knoepfe:
			if (k[0] as Rect2).has_point(event.position):
				var aktion: Callable = k[1] if event.button_index == MOUSE_BUTTON_LEFT else k[2]
				if aktion.is_valid():
					if vor_klick.is_valid():
						vor_klick.call()
					aktion.call()
				break
		accept_event()
	elif event is InputEventMouseButton:
		accept_event()


func _draw() -> void:
	_knoepfe = []
	var h := maxf(size.y, 20.0)
	Stil.platte(self, Rect2(Vector2.ZERO, Vector2(breite, h)), 4.0, Stil.METALL_DUNKEL, farbe.darkened(0.25))
	_y = 3.0
	if inhalt.is_valid():
		inhalt.call(self)
	size = Vector2(breite, _y + 4.0)


# ------------------------------------------------------------ Einträge

func kopf(text: String) -> void:
	Stil.schreibe(self, Vector2(8, _y + 5.5), text, Stil.NORMAL, farbe)
	_y += 13.0


## Reiter nebeneinander; `aktiv` ist der Schlüssel des gewählten.
func reiter(liste: Array, aktiv: String, aktion: Callable) -> void:
	var x := 5.0
	var bw := (breite - 10.0 - (liste.size() - 1) * 2.0) / liste.size()
	for e: Array in liste:
		var r := Rect2(x, _y, bw, 11)
		var an: bool = e[0] == aktiv
		var drueber := r.has_point(_maus)
		Stil.platte(self, r, 1.5, Color(farbe, 0.18) if an else Stil.METALL_TIEF, farbe if an else (Stil.LEUCHT if drueber else Stil.RAHMEN))
		Stil.schreibe_mittig(self, r.get_center(), str(e[1]), Stil.KLEIN, farbe if an else Stil.TEXT)
		_knoepfe.append([r, aktion.bind(e[0]), Callable()])
		x += bw + 2.0
	_y += 14.0


func trenner() -> void:
	draw_rect(Rect2(6, _y + 1.0, breite - 12.0, 1), Stil.RAHMEN)
	_y += 4.0


func abschnitt(text: String) -> void:
	Stil.schreibe(self, Vector2(8, _y + 5.0), text, Stil.KLEIN, Stil.TEXT_BLASS)
	_y += 10.0


## Mehrzeiliger kleiner Text (Hinweise, Fehlermeldungen).
func text(inhalt_text: String, text_farbe: Color = Stil.TEXT_BLASS) -> void:
	var weite := breite - 14.0
	var g := Stil.absatz_groesse(inhalt_text, weite, Stil.KLEIN)
	Stil.absatz(self, Vector2(7, _y), inhalt_text, weite, Stil.KLEIN, text_farbe)
	_y += g.y + 3.0


## Auswahlknöpfe, die umbrechen. liste = [[Schlüssel, Text], …]; `aktiv` = gewählter Schlüssel (oder Liste davon).
## `rechts` (optional) wird mit dem Schlüssel bei Rechtsklick gerufen.
func chips(liste: Array, aktiv: Variant, aktion: Callable, rechts: Callable = Callable()) -> void:
	var x := 6.0
	for e: Array in liste:
		var bw := Stil.breite(str(e[1]), Stil.KLEIN) + 6.0
		if x + bw > breite - 5.0 and x > 6.0:
			x = 6.0
			_y += 13.0
		var r := Rect2(x, _y, bw, 10)
		var an: bool = (aktiv is Array and (aktiv as Array).has(e[0])) or (not (aktiv is Array) and aktiv == e[0])
		_chip(r, str(e[1]), an)
		_knoepfe.append([r, aktion.bind(e[0]), rechts.bind(e[0]) if rechts.is_valid() else Callable()])
		x += bw + 3.0
	_y += 13.0


func schalter(beschriftung: String, an: bool, aktion: Callable) -> void:
	var r := Rect2(6, _y, breite - 12.0, 10)
	_chip(r, ("[x] " if an else "[ ] ") + beschriftung, an)
	_knoepfe.append([r, aktion, Callable()])
	_y += 13.0


## Zahl mit −/+. aendere(d) bekommt −1 oder +1 (mit Umschalt ×5 – das erledigt der Aufrufer über schritt()).
func zeile(beschriftung: String, wert: String, aendere: Callable, hervor: bool = false) -> void:
	Stil.schreibe(self, Vector2(8, _y + ZEILE / 2.0), beschriftung, Stil.KLEIN, Stil.TEXT)
	var minus := Rect2(breite - 50.0, _y + 1.0, 10, ZEILE - 2.0)
	var plus := Rect2(breite - 16.0, _y + 1.0, 10, ZEILE - 2.0)
	for k: Array in [[minus, "−", -1], [plus, "+", 1]]:
		var r: Rect2 = k[0]
		var drueber := r.has_point(_maus)
		Stil.platte(self, r, 1.5, Stil.METALL_TIEF, Stil.LEUCHT if drueber else Stil.RAHMEN)
		Stil.schreibe_mittig(self, r.get_center(), k[1], Stil.KLEIN, Stil.LEUCHT if drueber else Stil.TEXT)
		_knoepfe.append([r, aendere.bind(k[2]), Callable()])
	Stil.schreibe_mittig(self, Vector2(breite - 28.0, _y + ZEILE / 2.0), wert, Stil.KLEIN, farbe if hervor else Stil.TEXT)
	_y += ZEILE


## Breiter Knopf. Mehrere Knöpfe in einer Reihe: knoepfe([[Text, Aktion, Farbe], …]).
func knopf(beschriftung: String, aktion: Callable, knopf_farbe: Color = Stil.LEUCHT) -> void:
	knoepfe([[beschriftung, aktion, knopf_farbe]])


func knoepfe(liste: Array) -> void:
	var x := 6.0
	var bw := (breite - 12.0 - (liste.size() - 1) * 3.0) / liste.size()
	for e: Array in liste:
		var r := Rect2(x, _y, bw, 12)
		var kf: Color = e[2] if e.size() > 2 else Stil.LEUCHT
		var drueber := r.has_point(_maus)
		Stil.platte(self, r, 2.0, Color(kf, 0.25) if drueber else Stil.METALL_TIEF, kf if drueber else kf.darkened(0.35))
		Stil.schreibe_mittig(self, r.get_center(), str(e[0]), Stil.KLEIN, kf if drueber else Stil.TEXT)
		_knoepfe.append([r, e[1], Callable()])
		x += bw + 3.0
	_y += 15.0


## 20.11. (Schritt 5b): Karte (Kachel) mit Titel, einem Satz und Kurzzeilen; Klick ruft `aktion`. `hervor` = gerade offen.
func kachel(titel: String, satz: String, zeilen: Array, aktion: Callable, hervor: bool = false) -> void:
	var weite := breite - 22.0
	var hs := Stil.absatz_groesse(satz, weite, Stil.KLEIN).y if satz != "" else 0.0
	var h := 14.0 + hs + float(zeilen.size()) * 9.0 + 4.0
	var r := Rect2(6, _y, breite - 12.0, h)
	var drueber := r.has_point(_maus)
	Stil.platte(self, r, 2.0, Color(farbe, 0.16) if drueber or hervor else Stil.METALL_TIEF, farbe if hervor else (Stil.LEUCHT if drueber else Stil.RAHMEN))
	Stil.schreibe(self, Vector2(11, _y + 7.0), titel, Stil.NORMAL, farbe)
	var y := _y + 13.0
	if satz != "":
		Stil.absatz(self, Vector2(11, y), satz, weite, Stil.KLEIN, Stil.TEXT)
		y += hs + 1.0
	for z: Variant in zeilen:
		Stil.schreibe(self, Vector2(11, y + 4.0), "· " + str(z), Stil.KLEIN, Stil.TEXT_BLASS)
		y += 9.0
	_knoepfe.append([r, aktion, Callable()])
	_y += h + 3.0


static func schritt(d: int) -> int:
	return d * (5 if Input.is_key_pressed(KEY_SHIFT) else 1)


func _chip(r: Rect2, beschriftung: String, an: bool) -> void:
	var drueber := r.has_point(_maus)
	Stil.platte(self, r, 1.5, Color(farbe, 0.15) if an else Stil.METALL_TIEF, farbe if an else (Stil.LEUCHT if drueber else Stil.RAHMEN))
	Stil.schreibe(self, Vector2(r.position.x + 3.0, r.get_center().y), beschriftung, Stil.KLEIN, farbe if an else Stil.TEXT)


## Fenster in der Mitte: Titel, Text, Knöpfe ([Text, Aktion] – jede Aktion schließt das Fenster danach).
## Liegt auf einer eigenen Ebene über allem; ein Klick außerhalb tut nichts.
class Tafel extends CanvasLayer:
	var titel := ""
	var inhalt_text := ""
	var knoepfe: Array = []
	var _flaeche: Control
	var _rechtecke: Array = []

	func _init(t: String, text: String, k: Array) -> void:
		layer = 90
		titel = t
		inhalt_text = text
		knoepfe = k
		_flaeche = Control.new()
		_flaeche.size = Vector2(640, 360)
		_flaeche.scale = Vector2(Stil.UI_SKALA, Stil.UI_SKALA)
		_flaeche.mouse_filter = Control.MOUSE_FILTER_STOP
		_flaeche.draw.connect(_male)
		_flaeche.gui_input.connect(_eingabe)
		add_child(_flaeche)

	func _process(_delta: float) -> void:
		_flaeche.queue_redraw()

	func _rahmen() -> Rect2:
		var w := 300.0
		var g := Stil.absatz_groesse(inhalt_text, w - 24.0, Stil.NORMAL)
		var h := minf(g.y + 58.0, 330.0)
		return Rect2(320.0 - w / 2.0, 180.0 - h / 2.0, w, h)

	func _male() -> void:
		var ci := _flaeche
		ci.draw_rect(Rect2(0, 0, 640, 360), Color(0, 0, 0, 0.55))
		var r := _rahmen()
		Stil.platte(ci, r, 5.0, Stil.METALL_DUNKEL, Stil.LEUCHT.darkened(0.2))
		Stil.schreibe(ci, Vector2(r.position.x + 12.0, r.position.y + 13.0), titel, Stil.GROSS, Stil.LEUCHT)
		Stil.absatz(ci, r.position + Vector2(12, 26), inhalt_text, r.size.x - 24.0, Stil.NORMAL, Stil.TEXT)
		_rechtecke = []
		var x := r.end.x - 10.0
		var maus := ci.get_local_mouse_position()
		for i in range(knoepfe.size() - 1, -1, -1):
			var t: String = knoepfe[i][0]
			var bw := Stil.breite(t, Stil.NORMAL) + 16.0
			var kr := Rect2(x - bw, r.end.y - 22.0, bw, 15)
			var drueber := kr.has_point(maus)
			Stil.platte(ci, kr, 2.0, Color(Stil.LEUCHT, 0.25) if drueber else Stil.METALL_TIEF, Stil.LEUCHT if drueber or i == 0 else Stil.RAHMEN)
			Stil.schreibe_mittig(ci, kr.get_center(), t, Stil.NORMAL, Stil.LEUCHT if drueber else Stil.TEXT)
			_rechtecke.push_front([kr, knoepfe[i][1]])
			x -= bw + 6.0

	func _eingabe(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			for k: Array in _rechtecke:
				if (k[0] as Rect2).has_point(event.position):
					queue_free()
					if (k[1] as Callable).is_valid():
						(k[1] as Callable).call()
					return

	func _unhandled_input(event: InputEvent) -> void:
		if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
			get_viewport().set_input_as_handled()   # 18.11.: Esc schließt das Fenster (wie „Abbrechen“)
			queue_free()
			return
		if event is InputEventKey and event.pressed and event.keycode in [KEY_ENTER, KEY_KP_ENTER] and not knoepfe.is_empty():
			get_viewport().set_input_as_handled()
			queue_free()
			if (knoepfe[0][1] as Callable).is_valid():
				(knoepfe[0][1] as Callable).call()
