extends Control
## Schadensliste: solange [Tab] gedrückt ist, zeigt sie, wer in dieser Runde wie viel Schaden gemacht hat –
## je Fabrik (alle ihre Truppen zusammen), je Turmart und je Batterie. Balken im Verhältnis zum Spitzenreiter.

var spiel: Node
var _blaetter := {}
var _schrift: Font

const GRUND := Color(0.06, 0.08, 0.13, 0.92)
const RAND := Color("7cc8f5")
const BALKEN := Color("3d97dd")
const BALKEN_HELL := Color("7cc8f5")
const TEXT := Color("eef6ff")
const BLASS := Color("a9d4f7")
const ZEILE := 40.0
const BREITE := 560.0
const BALKEN_MAX := 220.0   # so lang wird der Balken des Spitzenreiters – Verhältnis, nicht volle Breite


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_schrift = ThemeDB.fallback_font


func _process(_delta: float) -> void:
	var an: bool = Input.is_physical_key_pressed(KEY_TAB) and spiel._menue == null
	if an != visible:
		visible = an
	if visible:
		queue_redraw()


func _draw() -> void:
	var eintraege: Array = []
	for q: String in spiel.runde_stats:
		var e: Dictionary = spiel.runde_stats[q]
		if float(e.get("schaden", 0.0)) > 0.0:
			eintraege.append(e)
	eintraege.sort_custom(func(a, b): return float(a["schaden"]) > float(b["schaden"]))
	var n := maxi(eintraege.size(), 1)
	var hoehe := 56.0 + n * ZEILE + 10.0
	var o := Vector2(40, Werte.KARTE_OBEN + 64)
	var kasten := StyleBoxFlat.new()
	kasten.bg_color = GRUND
	kasten.border_color = RAND
	kasten.set_border_width_all(2)
	kasten.set_corner_radius_all(10)
	draw_style_box(kasten, Rect2(o, Vector2(BREITE, hoehe)))
	var gesamt := 0.0
	for e: Dictionary in eintraege:
		gesamt += float(e["schaden"])
	draw_string(_schrift, o + Vector2(16, 28), "Schaden in Runde %d" % maxi(spiel.runde_stats_welle, 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("ffe9a8"))
	draw_string(_schrift, o + Vector2(BREITE - 316, 28), "gesamt %d · Tab loslassen schließt" % roundi(gesamt), HORIZONTAL_ALIGNMENT_RIGHT, 300, 12, BLASS)
	if eintraege.is_empty():
		draw_string(_schrift, o + Vector2(16, 70), "Noch kein Schaden in dieser Runde.", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, BLASS)
		return
	var spitze := float(eintraege[0]["schaden"])
	for i in eintraege.size():
		var e: Dictionary = eintraege[i]
		var y := o.y + 46.0 + i * ZEILE
		_bild(e, Vector2(o.x + 16, y))
		draw_string(_schrift, Vector2(o.x + 60, y + 14), str(e.get("name", "?")), HORIZONTAL_ALIGNMENT_LEFT, 250, 13, TEXT)
		draw_string(_schrift, Vector2(o.x + 60, y + 31), "%d Kills" % int(e.get("kills", 0)), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, BLASS)
		var wert := float(e["schaden"])
		var bx := o.x + 316.0
		draw_string(_schrift, Vector2(bx - 78, y + 23), str(roundi(wert)), HORIZONTAL_ALIGNMENT_RIGHT, 70, 14, TEXT)
		var laenge := maxf(3.0, BALKEN_MAX * 0.85 * wert / maxf(spitze, 1.0))   # Spitzenreiter bei 85 %: es geht ums Verhältnis
		draw_rect(Rect2(bx, y + 10, BALKEN_MAX, 16), Color(1, 1, 1, 0.06))
		draw_rect(Rect2(bx, y + 10, laenge, 16), BALKEN)
		draw_rect(Rect2(bx, y + 10, laenge, 4), BALKEN_HELL)


## Kleines Bild der Quelle: erstes Bild aus dem Animationsblatt, sonst ein Farbfeld (Türme).
func _bild(e: Dictionary, ecke: Vector2) -> void:
	if e.has("blatt"):
		var pfad: String = e["blatt"]
		if not _blaetter.has(pfad):
			_blaetter[pfad] = load(pfad)
		var k: int = int(e.get("zelle", 48))
		draw_texture_rect_region(_blaetter[pfad], Rect2(ecke + Vector2(-4, -4), Vector2(40, 40)), Rect2(0, 0, k, k))
	else:
		var farbe := Color(str(e.get("farbe", "7fe0ff")))
		draw_rect(Rect2(ecke + Vector2(4, 4), Vector2(28, 28)), Color("2a2038"))
		draw_rect(Rect2(ecke + Vector2(10, 10), Vector2(16, 16)), farbe)
