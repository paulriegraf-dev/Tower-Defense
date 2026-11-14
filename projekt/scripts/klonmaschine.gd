class_name Klonmaschine
extends Node2D
## Klonmaschine des Kommandanten: steht bis zum Rundenende auf einem Feld. Wer hindurchgeht, wird einmal geklont
## (mit seinem aktuellen Leben) – eigene Truppen wie Gegner. Klone werden nicht noch einmal geklont.

var spiel: Node
var karte: Karte
var zelle := Karte.KEINE
var _geklont := {}
var _zeit := 0.0


func _process(delta: float) -> void:
	_zeit += delta
	queue_redraw()
	if not spiel.im_kampf():
		return
	for g in spiel.gegner.duplicate():
		if is_instance_valid(g) and not g.klon and not g._tot and not g._auf_wall and not _geklont.has(g.get_instance_id()) and karte.zelle_bei(g.position) == zelle:
			_geklont[g.get_instance_id()] = true
			spiel.klone_gegner(g)
			spiel.effekte.flaeche(karte.mitte(zelle), Werte.ZELLE * 0.7, Color("c9a6ff"))
	for e in spiel.einheiten.duplicate():
		if is_instance_valid(e) and not (e is Kommandant) and not e.klon and e.am_boden() and not _geklont.has(e.get_instance_id()) and karte.zelle_bei(e.position) == zelle:
			_geklont[e.get_instance_id()] = true
			spiel.klone_einheit(e)
			spiel.effekte.flaeche(karte.mitte(zelle), Werte.ZELLE * 0.7, Color("c9a6ff"))


func _draw() -> void:
	# kenntlicher Generator: dunkler Sockel, zwei Säulen, violetter Kern, pulsierender Ring
	var m := Vector2.ZERO
	var puls := 0.5 + 0.5 * sin(_zeit * 4.0)
	draw_circle(m + Vector2(0, 8), 26.0, Color(0.79, 0.65, 1.0, 0.12 + 0.1 * puls))
	draw_rect(Rect2(m + Vector2(-24, 2), Vector2(48, 20)), Color("2a2038"))
	draw_rect(Rect2(m + Vector2(-22, 4), Vector2(44, 16)), Color("4a3b63"))
	for x in [-20.0, 14.0]:
		draw_rect(Rect2(m + Vector2(x, -18), Vector2(6, 24)), Color("2a2038"))
		draw_rect(Rect2(m + Vector2(x + 1, -16), Vector2(4, 20)), Color("8c96a8"))
	draw_circle(m + Vector2(0, -4), 9.0 + 2.0 * puls, Color(0.79, 0.65, 1.0, 0.85))
	draw_circle(m + Vector2(0, -4), 4.0, Color.WHITE)
	draw_line(m + Vector2(-14, -12), m + Vector2(-4, -6), Color(0.85, 0.75, 1.0, 0.7 * puls), 2.0)
	draw_line(m + Vector2(14, -12), m + Vector2(4, -6), Color(0.85, 0.75, 1.0, 0.7 * puls), 2.0)
	draw_arc(m + Vector2(0, 10), 30.0, 0.0, TAU, 40, Color(0.79, 0.65, 1.0, 0.5 + 0.4 * puls), 2.0)
