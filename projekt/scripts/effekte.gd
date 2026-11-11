class_name Effekte
extends Node2D
## Kurzlebige Schusslinien und geworfene Geschosse.

var _linien: Array = []   # [von, nach, farbe, restzeit]
var _wuerfe: Array = []   # [von, nach, vergangen, dauer, bei_einschlag]
var _wolken: Array = []   # [mitte, radius, restzeit, dauer]


func linie(von: Vector2, nach: Vector2, farbe: Color) -> void:
	_linien.append([von, nach, farbe, 0.08])


## Geschoss im Bogen; `bei_einschlag` wird aufgerufen, wenn es landet.
func wurf(von: Vector2, nach: Vector2, dauer: float, bei_einschlag: Callable) -> void:
	_wuerfe.append([von, nach, 0.0, dauer, bei_einschlag])


## Rauchwolke: Truppen darin können nicht schießen.
func rauch(mitte: Vector2, radius: float, dauer: float) -> void:
	_wolken.append([mitte, radius, dauer, dauer])


func im_rauch(punkt: Vector2) -> bool:
	for w in _wolken:
		if (w[0] as Vector2).distance_to(punkt) <= w[1]:
			return true
	return false


func leeren() -> void:
	_linien.clear()
	_wuerfe.clear()
	_wolken.clear()


func _process(delta: float) -> void:
	for l in _linien:
		l[3] -= delta
	_linien = _linien.filter(func(l): return l[3] > 0.0)
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


func _draw() -> void:
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
