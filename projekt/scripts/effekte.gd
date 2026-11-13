class_name Effekte
extends Node2D
## Kurzlebige Schusslinien und geworfene Geschosse.

var _linien: Array = []   # [von, nach, farbe, restzeit]
var _wuerfe: Array = []   # [von, nach, vergangen, dauer, bei_einschlag]
var _wolken: Array = []   # [mitte, radius, restzeit, dauer]
var _spuren: Array = []   # [punkt, restzeit, dauer] – Spur eines Fahnenträgers
var _strahlen: Array = []  # [von, nach, farbe, restzeit, breite]
var _braende: Array = []   # [mitte, radius, restzeit] – Brandfeld eines Plasmawerfers
var _gele: Array = []      # [mitte, radius, restzeit] – Plasmagel
var _warnungen: Array = []  # [mitte, restzeit] – hier landet gleich ein Wurf


func linie(von: Vector2, nach: Vector2, farbe: Color) -> void:
	_linien.append([von, nach, farbe, 0.08])


## Geschoss im Bogen; `bei_einschlag` wird aufgerufen, wenn es landet.
func wurf(von: Vector2, nach: Vector2, dauer: float, bei_einschlag: Callable) -> void:
	_wuerfe.append([von, nach, 0.0, dauer, bei_einschlag])


## Rauchwolke: Truppen darin können nicht schießen.
func rauch(mitte: Vector2, radius: float, dauer: float) -> void:
	_wolken.append([mitte, radius, dauer, dauer])


## Löst die nächste Rauchwolke im Umkreis auf. Gibt ihre Mitte zurück (oder null).
func blase_rauch_weg(von: Vector2, weite: float) -> Variant:
	var beste := -1
	for i in _wolken.size():
		var d: float = (_wolken[i][0] as Vector2).distance_to(von)
		if d <= weite and (beste < 0 or d < (_wolken[beste][0] as Vector2).distance_to(von)):
			beste = i
	if beste < 0:
		return null
	var mitte: Vector2 = _wolken[beste][0]
	_wolken.remove_at(beste)
	return mitte


var schilde: Array = []    # [mitte, anteil 0..1, aktiv] – vom Spiel jedes Bild gesetzt


func _zeichne_schilde() -> void:
	var t := Time.get_ticks_msec() / 1000.0
	for s in schilde:
		var m: Vector2 = s[0]
		var r := Werte.ZELLE * 0.46
		if not s[2]:
			draw_arc(m, r, 0.0, TAU, 20, Color(0.5, 0.9, 1.0, 0.25), 2.0)
			continue
		var puls := 0.75 + 0.25 * sin(t * 4.0)
		draw_circle(m, r, Color(0.35, 0.85, 1.0, 0.22 * puls))
		draw_arc(m, r, 0.0, TAU, 28, Color(0.6, 0.95, 1.0, 0.9), 3.0)
		draw_arc(m, r - 6.0, t * 1.5, t * 1.5 + TAU * float(s[1]), 28, Color(1, 1, 1, 0.85), 2.0)


func im_rauch(punkt: Vector2) -> bool:
	for w in _wolken:
		if (w[0] as Vector2).distance_to(punkt) <= w[1]:
			return true
	return false


## Warnkreis am Landepunkt eines Wurfs.
func warnung(mitte: Vector2, dauer: float) -> void:
	_warnungen.append([mitte, dauer])


func leeren() -> void:
	_warnungen.clear()
	_linien.clear()
	_wuerfe.clear()
	_wolken.clear()
	_spuren.clear()
	_strahlen.clear()
	_braende.clear()
	_gele.clear()


func _process(delta: float) -> void:
	for w in _warnungen:
		w[1] -= delta
	_warnungen = _warnungen.filter(func(w): return w[1] > 0.0)
	for l in _linien:
		l[3] -= delta
	_linien = _linien.filter(func(l): return l[3] > 0.0)
	for s in _spuren:
		s[1] -= delta
	_spuren = _spuren.filter(func(s): return s[1] > 0.0)
	for s in _strahlen:
		s[3] -= delta
	_strahlen = _strahlen.filter(func(s): return s[3] > 0.0)
	for b in _braende:
		b[2] -= delta
	_braende = _braende.filter(func(b): return b[2] > 0.0)
	for b in _gele:
		b[2] -= delta
	_gele = _gele.filter(func(b): return b[2] > 0.0)
	for w in _wolken:
		w[2] -= delta
	_wolken = _wolken.filter(func(w): return w[2] > 0.0)
	var gelandet: Array = []
	for w in _wuerfe:
		w[2] += delta
		if w[2] >= w[3]:
			gelandet.append(w)
	for w in gelandet:
		_wuerfe.erase(w)
		linie(w[1] + Vector2(-14, 0), w[1] + Vector2(14, 0), Color("ffd9a0"))
		(w[4] as Callable).call()
	queue_redraw()


## Ein Stück Spur hinter einem Fahnenträger (verblasst über `dauer` Sekunden).
func spur(punkt: Vector2, dauer: float) -> void:
	_spuren.append([punkt, dauer, dauer])


func strahl(von: Vector2, nach: Vector2, farbe: Color, breite: float) -> void:
	_strahlen.append([von, nach, farbe, 0.09, breite])


func brand(mitte: Vector2, radius: float, dauer: float) -> void:
	_braende.append([mitte, radius, dauer])


func gel(mitte: Vector2, radius: float, dauer: float) -> void:
	_gele.append([mitte, radius, dauer])


func _draw() -> void:
	_zeichne_schilde()
	for w in _warnungen:
		var m: Vector2 = w[0]
		var puls := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 90.0)
		draw_arc(m, Werte.ZELLE * 0.55, 0.0, TAU, 28, Color(1.0, 0.25, 0.3, 0.55 + 0.4 * puls), 3.0)
		draw_arc(m, Werte.ZELLE * 0.3, 0.0, TAU, 20, Color(1.0, 0.25, 0.3, 0.35 + 0.3 * puls), 2.0)
		draw_line(m + Vector2(-8, -8), m + Vector2(8, 8), Color(1.0, 0.3, 0.3, 0.9), 3.0)
		draw_line(m + Vector2(8, -8), m + Vector2(-8, 8), Color(1.0, 0.3, 0.3, 0.9), 3.0)
	for b in _braende:
		# flackerndes Brandfeld aus kleinen Quadraten
		var deckung: float = clampf(b[2] / 0.6, 0.0, 1.0)
		for i in 14:
			var w: float = TAU * i / 14.0 + float(b[2]) * 2.0
			var r: float = b[1] * (0.25 + 0.7 * fposmod(sin(i * 12.9898 + floorf(b[2] * 8.0)) * 43758.5453, 1.0))
			draw_rect(Rect2(b[0] + Vector2(cos(w), sin(w)) * r - Vector2(6, 6), Vector2(12, 12)), Color(1.0, 0.45 + 0.3 * fposmod(i * 0.37, 1.0), 0.1, 0.55 * deckung))
	for b in _gele:
		var deckung: float = clampf(b[2] / 0.6, 0.0, 1.0)
		draw_circle(b[0], b[1], Color(0.35, 1.0, 0.6, 0.16 * deckung))
		draw_arc(b[0], b[1], 0.0, TAU, 32, Color(0.5, 1.0, 0.7, 0.6 * deckung), 2.0)
	for s in _strahlen:
		draw_line(s[0], s[1], Color(s[2], 0.35), s[4] + 4.0)
		draw_line(s[0], s[1], s[2], s[4])
	for s in _spuren:
		var anteil := clampf(s[1] / s[2], 0.0, 1.0)
		draw_rect(Rect2(s[0] + Vector2(-10, 6), Vector2(20, 8)), Color(1.0, 0.35, 0.82, 0.38 * anteil))
		draw_rect(Rect2(s[0] + Vector2(-4, 8), Vector2(8, 4)), Color(1.0, 0.8, 0.95, 0.5 * anteil))
	for w in _wolken:
		# grob gerasterte Wolke, die zum Ende hin ausdünnt
		var staerke := clampf(w[2] / 1.0, 0.0, 1.0) * 0.55
		var r: float = w[1]
		var schritt := 16.0
		var y := -r
		while y < r:
			var x := -r
			while x < r:
				if Vector2(x + 8, y + 8).length() <= r:
					var hell := 0.75 + 0.15 * sin((x * 0.13) + (y * 0.21))
					draw_rect(Rect2((w[0] as Vector2) + Vector2(x, y), Vector2(schritt, schritt)), Color(hell, hell, hell + 0.03, staerke))
				x += schritt
			y += schritt
	for l in _linien:
		draw_line(l[0], l[1], l[2], 2.0)
		draw_rect(Rect2(l[1] - Vector2(3, 3), Vector2(6, 6)), l[2])
	for w in _wuerfe:
		var t: float = w[2] / w[3]
		var boden: Vector2 = (w[0] as Vector2).lerp(w[1], t)
		var hoehe := sin(t * PI) * 90.0
		draw_rect(Rect2(boden - Vector2(5, 2), Vector2(10, 4)), Color(0, 0, 0, 0.35))          # Schatten
		draw_rect(Rect2(boden - Vector2(6, 6 + hoehe), Vector2(12, 12)), Color("3a2a1c"))
		draw_rect(Rect2(boden - Vector2(4, 4 + hoehe), Vector2(8, 8)), Color("b98a4a"))
