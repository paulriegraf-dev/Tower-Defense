extends Control
## Sandbox-Leiste (nur im Sandbox-Modus, nur in der Bauphase): Runde wählen, Gegner der nächsten Welle und
## Truppen je Fabrik einstellen, Basis versetzen, Checkpoint-Route. 16.11.: im Stil der neuen Oberfläche
## (Metall, VT323, kleine Gegnerbilder), gezeichnet im UI-Raster (zweifach skaliert). Umschalt + −/+ = 5er-Schritte.
## Alte Fassung: _vor_sandbox/sandboxleiste.gd.

const Stil := preload("res://scripts/ui/ui_stil.gd")
const TYPEN := ["hund", "sphaere", "fahne", "sprenger", "rauch", "belagerung", "schild", "sani", "schwarm"]
const W := 150.0
const ZEILE := 12.0
const GOLD_HELL := Color("ffe9a8")

var spiel: Node
var _offen := true
var _maus := Vector2(-100, -100)
var _knoepfe: Array = []        # [Rechteck, Aktion]
var _figuren := {}
var _route := true              # Checkpoint-Route ab Runde 1 (main.gd stellt sie beim Start der Sandbox an)


func _ready() -> void:
	scale = Vector2(Stil.UI_SKALA, Stil.UI_SKALA)
	mouse_filter = Control.MOUSE_FILTER_STOP


func _process(_delta: float) -> void:
	visible = spiel.sandbox and spiel.phase == 0
	if not visible:
		return
	_maus = get_local_mouse_position()
	var h := 16.0 if not _offen else 16.0 + (TYPEN.size() + 2) * ZEILE + 60.0
	size = Vector2(W, h)
	position = Vector2((640.0 - 6.0 - W) * Stil.UI_SKALA, 32.0 * Stil.UI_SKALA)   # unter den Knöpfen oben rechts
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		for k: Array in _knoepfe:
			if (k[0] as Rect2).has_point(event.position):
				(k[1] as Callable).call()
				accept_event()
				return
		accept_event()


func _schritt(d: int) -> int:
	return d * (5 if Input.is_key_pressed(KEY_SHIFT) else 1)


func _draw() -> void:
	_knoepfe = []
	Stil.platte(self, Rect2(Vector2.ZERO, size), 4.0, Stil.METALL_DUNKEL, GOLD_HELL.darkened(0.25))
	# Kopf: Titel, auf-/zuklappen
	var kopf := Rect2(4, 3, W - 8.0, 11)
	Stil.schreibe(self, Vector2(8, 8.5), "Sandbox", Stil.NORMAL, GOLD_HELL)
	_dreieck(Vector2(W - 12.0, 8.5), _offen)
	_knoepfe.append([kopf, func(): _offen = not _offen])
	if not _offen:
		return
	var y := 18.0
	var w: Dictionary = spiel.naechste_welle()
	var anzahl := {}
	for g: Dictionary in w["gruppen"]:
		anzahl[g["typ"]] = g["anzahl"]
	_zeile(y, "", "Runde", str(spiel.welle), false, func(d: int): spiel.sandbox_springe(spiel.welle + _schritt(d)))
	y += ZEILE
	self.draw_rect(Rect2(6, y + 1.0, W - 12.0, 1), Stil.RAHMEN)
	y += 3.0
	for typ: String in TYPEN:
		_zeile(y, typ, Werte.GEGNER[typ]["name"], str(int(anzahl.get(typ, 0))), spiel.sandbox_gegner.has(typ), func(d: int): spiel.sandbox_aendere_gegner(typ, _schritt(d)))
		y += ZEILE
	self.draw_rect(Rect2(6, y + 1.0, W - 12.0, 1), Stil.RAHMEN)
	y += 3.0
	_zeile(y, "", "Truppen je Fabrik", str(spiel.truppen_limit(Karte.KEINE)), false, func(d: int): spiel.sandbox_truppen = clampi(spiel.sandbox_truppen + _schritt(d), -2, 9))
	y += ZEILE + 3.0
	# Basis
	Stil.schreibe(self, Vector2(8, y + 5.0), "Basis", Stil.KLEIN, Stil.TEXT_BLASS)
	y += 10.0
	var x := 6.0
	for wahl: Array in [["fest", "fest"], ["rechts", "rechts"], ["ueberall", "überall"], ["klick", "setzen"]]:
		var bw := Stil.breite(wahl[1], Stil.KLEIN) + 6.0
		var r := Rect2(x, y, bw, 10)
		var an: bool = spiel.basis_art == wahl[0]
		_chip(r, wahl[1], an)
		_knoepfe.append([r, func(): spiel.sandbox_basis(wahl[0])])
		x += bw + 3.0
	y += 13.0
	# Checkpoint-Route
	var route := _route
	var rr := Rect2(6, y, W - 12.0, 10)
	_chip(rr, ("[x] " if route else "[ ] ") + "Checkpoint-Route ab Runde 1", route)
	_knoepfe.append([rr, func():
		_route = not _route
		spiel.sandbox_cp_route(_route)])
	y += 13.0
	var wr := Rect2(6, y, W - 12.0, 11)
	_chip(wr, "Welle wie im Spiel", spiel.sandbox_gegner.is_empty())
	_knoepfe.append([wr, func(): spiel.sandbox_gegner = {}])


func _zeile(y: float, typ: String, text: String, wert: String, geaendert: bool, aendere: Callable) -> void:
	var x := 8.0
	if typ != "":
		_figur(typ, Vector2(x + 4.0, y + ZEILE - 1.0))
		x += 11.0
	Stil.schreibe(self, Vector2(x, y + ZEILE / 2.0), text, Stil.KLEIN, Stil.TEXT)
	var minus := Rect2(W - 50.0, y + 1.0, 10, ZEILE - 2.0)
	var plus := Rect2(W - 16.0, y + 1.0, 10, ZEILE - 2.0)
	for k: Array in [[minus, "−", -1], [plus, "+", 1]]:
		var r: Rect2 = k[0]
		var drueber := r.has_point(_maus)
		Stil.platte(self, r, 1.5, Stil.METALL_TIEF, Stil.LEUCHT if drueber else Stil.RAHMEN)
		Stil.schreibe_mittig(self, r.get_center(), k[1], Stil.KLEIN, Stil.LEUCHT if drueber else Stil.TEXT)
		_knoepfe.append([r, aendere.bind(k[2])])
	Stil.schreibe_mittig(self, Vector2(W - 28.0, y + ZEILE / 2.0), wert, Stil.KLEIN, GOLD_HELL if geaendert else Stil.TEXT)


func _chip(r: Rect2, text: String, an: bool) -> void:
	var drueber := r.has_point(_maus)
	Stil.platte(self, r, 1.5, Color(GOLD_HELL, 0.15) if an else Stil.METALL_TIEF, GOLD_HELL if an else (Stil.LEUCHT if drueber else Stil.RAHMEN))
	Stil.schreibe(self, Vector2(r.position.x + 3.0, r.get_center().y), text, Stil.KLEIN, GOLD_HELL if an else Stil.TEXT)


func _dreieck(m: Vector2, offen: bool) -> void:
	var p := PackedVector2Array([m + Vector2(-3, -1.5), m + Vector2(3, -1.5), m + Vector2(0, 2)]) if offen else PackedVector2Array([m + Vector2(-1.5, -3), m + Vector2(2, 0), m + Vector2(-1.5, 3)])
	draw_colored_polygon(p, GOLD_HELL)


## Kleine Gegnerfigur (Standbild), Füße auf `fuss`, ca. 10 UI-Pixel hoch.
func _figur(typ: String, fuss: Vector2) -> void:
	if not _figuren.has(typ):
		var g := Werte.grafik_daten(Werte.GEGNER[typ])
		_figuren[typ] = {"tex": load(str(g["blatt"])), "zelle": float(g["zelle"])}
	var f: Dictionary = _figuren[typ]
	var z: float = f["zelle"]
	var sk := Stil.skala()
	var g2 := Vector2(z, z) / sk   # 1 Bildpunkt = 1 Bildschirmpixel
	var o := ((fuss - Vector2(g2.x / 2.0, g2.y * 0.9)) * sk).round() / sk
	var ziel := Rect2(o, g2)
	if typ in ["sprenger", "enterer"]:
		ziel = Rect2(o, Vector2(-g2.x, g2.y))
	draw_texture_rect_region(f["tex"], ziel, Rect2(0, 0, z, z))
