class_name Schatten
extends Node2D
## Neue Grafik (16.11.): weiche Schatten unter Truppen, Gegnern und Türmen – auf den Boden gezeichnet (Kind der Karte),
## damit sie in HD-2D auf dem Gelände liegen und die Figuren „stehen“. Gerastert wie Pixelkunst, leicht nach rechts unten versetzt
## (Licht von links oben wie das Richtungslicht der HD-Ansicht).

var spiel: Node
const FARBE := Color(0.0, 0.03, 0.02, 0.3)
## Lesbarkeit (16.11.): der Schatten trägt einen Hauch Teamfarbe – Gegner warm (kupfern-rot), eigene Truppen kühl (blau)
const FARBE_GEGNER := Color(0.22, 0.04, 0.0, 0.34)
const FARBE_TRUPPE := Color(0.0, 0.05, 0.22, 0.34)
const VERSATZ := Vector2(4, 2)


func _process(_delta: float) -> void:
	visible = Werte.grafik_neu
	if visible:
		queue_redraw()


func _draw() -> void:
	var oben: Vector2 = (get_parent() as Node2D).position   # die Karte liegt unter der oberen Leiste
	for e in spiel.einheiten:
		if not is_instance_valid(e) or not e.visible or not e.am_boden():
			continue
		_fleck((e as Node2D).position - oben, 13.0, FARBE_TRUPPE)
	for g in spiel.gegner:
		if not is_instance_valid(g) or not g.visible:
			continue
		var gr := 22.0 if g.typ == "belagerung" else (16.0 if g.typ == "sphaere" else 12.0)
		_fleck((g as Node2D).position - oben, gr * (1.0 - 0.4 * g.sprung_hoch), FARBE_GEGNER)   # 22.11.: im Sprung schrumpft der Schatten am Boden
	for t in spiel.turmbilder.values():
		if is_instance_valid(t):
			_fleck((t as Node2D).position - oben + Vector2(0, -4), 24.0, FARBE)


## flache Ellipse aus zwei Stufen (Kern dunkler), Breite 2·r, Höhe r
func _fleck(p: Vector2, r: float, farbe: Color) -> void:
	var m := p + VERSATZ
	draw_set_transform(m, 0.0, Vector2(1.0, 0.45))
	draw_circle(Vector2.ZERO, r, farbe, true, -1.0, false)
	draw_circle(Vector2.ZERO, r * 0.62, farbe, true, -1.0, false)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
