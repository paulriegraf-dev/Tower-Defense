class_name Nachschlag
extends Control
## Nachschlagekarte [H]: bekannte Erdwall-Formationen als kleine Skizzen mit Stärke und Schwäche.
## Nur zum Ansehen und Ideen holen – gebaut wird weiter von Hand.

const PLAENE: Dictionary = preload("res://werkzeuge/plaene.gd").PLAENE

## Plan -> [Name, wofür gut, wofür anfällig]
const TEXTE := {
	"1-schlauch": ["Langer Schlauch", "Längster Weg, wächst Wand für Wand.", "Sprenger, Checkpoints tief im Gang, keine Türme."],
	"2-kamm": ["Kamm", "Langer Weg, weite Sicht, Türme an den Zahnwurzeln.", "Teuer, halb gebaut wenig wert."],
	"3-zitadelle": ["Zitadelle", "Ein Wallstück: alle sehen alles. Fabriken im Kern, Tor als Ausgang.", "Kurzer Weg, dünne Arme für Sprenger."],
	"4-inseln": ["Inseln", "Viel Feuerkraft, kurze Fußwege.", "Keine Wegführung, erst mit Türmen stark."],
	"5-doppelriegel": ["Doppelriegel", "Sprengsicher, viele Turmplätze, billig.", "Kürzester Weg, nah an der Schleuder."],
	"6-gestaffelt": ["Gestaffelte Linien", "Billig und schnell gebaut.", "Die Linien verdecken sich die Sicht."],
	"7-kamm-mit-kern": ["Kamm mit Kern", "Langer Weg und geschützte Fabriken mit Tor.", "Dünne Zähne für Sprenger."],
	"8-riegel-und-schlauch": ["Riegel und Schlauch", "Türme vorn, langer Weg dahinter.", "Sprenger, Checkpoints tief im Gang."],
	"9-dicker-schlauch": ["Dicker Schlauch", "Sprengsicher, sehr viele Turmplätze.", "Teuer, erst fertig stark."],
}

const GRUND := Color(0.07, 0.06, 0.1, 0.94)
const KARTE_BODEN := Color("3f7a3a")
const ZONE := Color("6b6258")
const WALL := Color("a9713f")
const STELLUNG := Color("c9c4d2")
const TURM := Color("6b3fa0")
const TOR := Color("1b1722")
const FABRIK := Color("8f6bd0")
const CHECKPOINT := Color("ff5fb0")
const BASIS := Color("5ad0ff")


func _ready() -> void:
	size = Vector2(1280, 720)
	mouse_filter = Control.MOUSE_FILTER_STOP   # solange die Karte offen ist, wird nicht versehentlich gebaut
	visible = false


func umschalten() -> void:
	visible = not visible
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		visible = false


func _draw() -> void:
	var schrift := ThemeDB.fallback_font
	draw_rect(Rect2(Vector2.ZERO, size), GRUND)
	draw_string(schrift, Vector2(40, 46), "Formationen", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color("ffe9a8"))
	draw_string(schrift, Vector2(210, 44), "Ideen zum Nachbauen – keine Vorschrift. Checkpoints liegen jedes Mal anders.   [H] oder Klick schließt",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("a79fb3"))
	_legende(schrift)
	var namen := PLAENE.keys()
	for i in namen.size():
		var ecke := Vector2(40 + (i % 3) * 405, 96 + int(i / 3.0) * 204)
		_karte(schrift, ecke, namen[i])


func _karte(schrift: Font, ecke: Vector2, plan_name: String) -> void:
	var texte: Array = TEXTE.get(plan_name, [plan_name, "", ""])
	var plan: Array = PLAENE[plan_name]
	var k := 9.0   # Kantenlänge eines Feldes in der Skizze
	draw_rect(Rect2(ecke, Vector2(20 * k, 10 * k)), KARTE_BODEN)
	draw_rect(Rect2(ecke, Vector2(Werte.ZONE_SPALTEN * k, 10 * k)), ZONE)
	for y in plan.size():
		for x in (plan[y] as String).length():
			var c: String = plan[y][x]
			var feld := Rect2(ecke + Vector2(x, y) * k, Vector2(k, k))
			var innen := feld.grow(-2.0)
			match c:
				"#":
					draw_rect(feld, WALL)
				"S":
					draw_rect(feld, WALL)
					draw_rect(innen, STELLUNG)
				"T":
					draw_rect(feld, WALL)
					draw_rect(innen, TURM)
				"O":
					draw_rect(feld, WALL)
					draw_rect(innen, TOR)
				"F":
					draw_rect(feld.grow(-1.0), FABRIK)
				"1", "2":
					draw_circle(feld.get_center(), 3.0, CHECKPOINT)
	draw_circle(ecke + (Vector2(Werte.BASIS_ZELLE) + Vector2(0.5, 0.5)) * k, 3.5, BASIS)
	var tx := ecke.x + 20 * k + 12
	var breite := 405.0 - 20 * k - 30
	draw_string(schrift, Vector2(tx, ecke.y + 16), texte[0], HORIZONTAL_ALIGNMENT_LEFT, breite, 17, Color("ffe9a8"))
	draw_multiline_string(schrift, Vector2(tx, ecke.y + 38), "+ " + texte[1], HORIZONTAL_ALIGNMENT_LEFT, breite, 13, 3, Color("b9e6c4"))
	draw_multiline_string(schrift, Vector2(tx, ecke.y + 100), "– " + texte[2], HORIZONTAL_ALIGNMENT_LEFT, breite, 13, 3, Color("f0b3a6"))


func _legende(schrift: Font) -> void:
	var eintraege := [[WALL, "Erdwall"], [STELLUNG, "Stellung"], [TURM, "Turm"], [TOR, "Tor"], [FABRIK, "Fabrik"], [CHECKPOINT, "Checkpoint"], [BASIS, "Basis"]]
	var x := 40.0
	for e: Array in eintraege:
		draw_rect(Rect2(x, 62, 12, 12), WALL if e[0] in [STELLUNG, TURM, TOR] else e[0])
		if e[0] in [STELLUNG, TURM, TOR]:
			draw_rect(Rect2(x + 2, 64, 8, 8), e[0])
		draw_string(schrift, Vector2(x + 18, 73), e[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("d8cfe6"))
		x += 30 + schrift.get_string_size(e[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x + 14
