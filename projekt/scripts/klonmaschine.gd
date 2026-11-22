class_name Klonmaschine
extends Node2D
## Klonmaschine des Kommandanten: steht bis zum Rundenende auf einem Feld. Wer hindurchgeht, wird einmal geklont
## (mit seinem aktuellen Leben) – eigene Truppen wie Gegner. Klone werden nicht noch einmal geklont.

var spiel: Node
var karte: Karte
var zelle := Karte.KEINE
var _geklont := {}
var _zeit := 0.0


func _physics_process(_takt: float) -> void:
	var delta := Werte.SIM_SCHRITT   # 9a: feste Schrittweite, unabhaengig von Tempo und Bildrate
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
	if Werte.grafik_hd:
		return   # HD-2D: Bodenplatte und Laserfeld stehen in 3D (hd_ansicht.gd)
	# 16.11.: Bodenplatte mit lila Rand, aus der ein Laserfeld emporsteigt
	var puls := 0.5 + 0.5 * sin(_zeit * 4.0)
	draw_rect(Rect2(Vector2(-26, 10), Vector2(52, 16)), Color("2a2038"))
	draw_rect(Rect2(Vector2(-24, 12), Vector2(48, 2)), Color("c9a6ff"))
	draw_rect(Rect2(Vector2(-24, 22), Vector2(48, 2)), Color("c9a6ff"))
	for i in 8:
		var x := -21.0 + i * 6.0
		var hoch := 40.0 + 8.0 * sin(_zeit * 3.0 + i)
		for s in 10:
			var a := (1.0 - s / 10.0) * (0.35 + 0.25 * puls)
			draw_rect(Rect2(Vector2(x, 12 - (s + 1) * hoch / 10.0), Vector2(2, hoch / 10.0)), Color(0.79, 0.55, 1.0, a))
	var band := fmod(_zeit * 0.6, 1.0)
	draw_rect(Rect2(Vector2(-24, 12 - band * 44.0), Vector2(48, 2)), Color(0.9, 0.8, 1.0, 0.7 * (1.0 - band)))
