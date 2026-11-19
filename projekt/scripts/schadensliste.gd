extends Control
## Schadensliste: [Tab] (oder der Knopf oben rechts) schaltet sie an und aus. Sie zeigt, wer in dieser Runde wie viel Schaden gemacht hat –
## je Fabrik (alle ihre Truppen zusammen), je Turmart und je Batterie. Balken im Verhältnis zum Spitzenreiter.

const Stil := preload("res://scripts/ui/ui_stil.gd")

var spiel: Node
var per_knopf := false   # Liste an/aus ([Tab] oder Knopf oben rechts)
var _blaetter := {}

const ZEILE := 22.0
const BREITE := 280.0
const BALKEN_MAX := 110.0   # so lang wird der Balken des Spitzenreiters – Verhältnis, nicht volle Breite


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	scale = Vector2(Stil.UI_SKALA, Stil.UI_SKALA)   # UI-Raster 640×360 wie die übrige Oberfläche


var _tab_vorher := false

func _process(_delta: float) -> void:
	# [Tab] schaltet um (16.11.): einmal drücken = an, nochmal = aus – wie der Knopf oben rechts
	var tab := Input.is_physical_key_pressed(KEY_TAB)
	if tab and not _tab_vorher:
		per_knopf = not per_knopf
	_tab_vorher = tab
	var an: bool = per_knopf and spiel._menue == null
	if an != visible:
		visible = an
	if visible:
		queue_redraw()


func _draw() -> void:
	if spiel.brakk_modus and spiel.kommandant != null and spiel.kommandant.fortschritt != null:
		_male_brakk()   # 19.11.
		return
	var eintraege: Array = []
	for q: String in spiel.runde_stats:
		var e: Dictionary = spiel.runde_stats[q]
		if float(e.get("schaden", 0.0)) > 0.0:
			eintraege.append(e)
	eintraege.sort_custom(func(a, b): return float(a["schaden"]) > float(b["schaden"]))
	var n := maxi(eintraege.size(), 1)
	var hoehe := 28.0 + n * ZEILE + 5.0
	var o := Vector2(20, (Werte.KARTE_OBEN + 64) / 2.0)
	Stil.platte(self, Rect2(o, Vector2(BREITE, hoehe)))
	var gesamt := 0.0
	for e: Dictionary in eintraege:
		gesamt += float(e["schaden"])
	Stil.schreibe(self, o + Vector2(8, 11), "Schaden in Runde %d" % maxi(spiel.runde_stats_welle, 1), Stil.GROSS, Stil.LEUCHT)
	var rechts := "gesamt %d · [Tab] schließt" % roundi(gesamt)
	Stil.schreibe(self, o + Vector2(BREITE - 8.0 - Stil.breite(rechts, Stil.KLEIN), 11), rechts, Stil.KLEIN, Stil.TEXT_BLASS)
	if eintraege.is_empty():
		Stil.schreibe(self, o + Vector2(8, 35), "Noch kein Schaden in dieser Runde.", Stil.NORMAL, Stil.TEXT_BLASS)
		return
	var spitze := float(eintraege[0]["schaden"])
	for i in eintraege.size():
		var e: Dictionary = eintraege[i]
		var y := o.y + 24.0 + i * ZEILE
		var farbe: Color = Stil.GOLD if i == 0 else Stil.LEUCHT
		_bild(e, Vector2(o.x + 6, y + 1))
		Stil.schreibe(self, Vector2(o.x + 30, y + 6), str(e.get("name", "?")), Stil.NORMAL, Stil.TEXT)
		Stil.schreibe(self, Vector2(o.x + 30, y + 15), "%d Kills" % int(e.get("kills", 0)), Stil.KLEIN, Stil.TEXT_BLASS)
		var wert := float(e["schaden"])
		var bx := o.x + 158.0
		var zahl := str(roundi(wert))
		Stil.schreibe(self, Vector2(bx - 6.0 - Stil.breite(zahl, Stil.NORMAL), y + 11), zahl, Stil.NORMAL, Stil.GOLD if i == 0 else Stil.TEXT)
		var laenge := maxf(2.0, BALKEN_MAX * 0.85 * wert / maxf(spitze, 1.0))   # Spitzenreiter bei 85 %: es geht ums Verhältnis
		draw_rect(Rect2(bx, y + 6, BALKEN_MAX, 8), Color(1, 1, 1, 0.06))
		draw_rect(Rect2(bx, y + 6, laenge, 8), Color(farbe, 0.65))
		draw_rect(Rect2(bx, y + 6, laenge, 2), farbe)


## Kleines Bild der Quelle: erstes Bild aus dem Animationsblatt, sonst ein Farbfeld (Türme).
func _bild(e: Dictionary, ecke: Vector2) -> void:
	if e.has("blatt"):
		var pfad: String = e["blatt"]
		if not _blaetter.has(pfad):
			_blaetter[pfad] = load(pfad)
		var k: int = int(e.get("zelle", 48))
		draw_texture_rect_region(_blaetter[pfad], Rect2(ecke + Vector2(-2, -2), Vector2(20, 20)), Rect2(0, 0, k, k))
	else:
		var farbe := Color(str(e.get("farbe", "7fe0ff")))
		draw_rect(Rect2(ecke + Vector2(2, 2), Vector2(14, 14)), Color("2a2038"))
		draw_rect(Rect2(ecke + Vector2(5, 5), Vector2(8, 8)), farbe)


## 19.11. (Paul): [Tab] im Brakk-Mode – oben groß Brakk mit seinem Anteil am Schaden der Runde und Balken je Quelle,
## darunter Truppen und Türme deutlich kleiner.
const BRAKK_ZEILE := 13.0

func _male_brakk() -> void:
	var f: BrakkFortschritt = spiel.kommandant.fortschritt
	var runde := maxi(spiel.runde_stats_welle, 1)
	var quellen: Dictionary = f.schaden_runden.get(str(runde), {})
	var brakk := 0.0
	var andere: Array = []
	var gesamt := 0.0
	for q: String in spiel.runde_stats:
		var e: Dictionary = spiel.runde_stats[q]
		var s := float(e.get("schaden", 0.0))
		gesamt += s
		if q == "fabrik:-1,-1":
			brakk += s
		elif s > 0.0:
			andere.append(e)
	andere.sort_custom(func(a, b): return float(a["schaden"]) > float(b["schaden"]))
	var liste: Array = []
	for q: String in BrakkFortschritt.QUELLEN:
		if float(quellen.get(q, 0.0)) > 0.0:
			liste.append([q, float(quellen[q])])
	var hoehe := 30.0 + 22.0 + maxi(liste.size(), 1) * 11.0 + 10.0 + andere.size() * BRAKK_ZEILE + 6.0
	var o := Vector2(20, (Werte.KARTE_OBEN + 64) / 2.0)
	Stil.platte(self, Rect2(o, Vector2(BREITE, hoehe)))
	Stil.schreibe(self, o + Vector2(8, 11), "Schaden in Runde %d" % runde, Stil.GROSS, Stil.LEUCHT)
	var rechts := "gesamt %d · [Tab] schließt" % roundi(gesamt)
	Stil.schreibe(self, o + Vector2(BREITE - 8.0 - Stil.breite(rechts, Stil.KLEIN), 11), rechts, Stil.KLEIN, Stil.TEXT_BLASS)
	# Brakk groß
	var y := o.y + 26.0
	Stil.schreibe(self, Vector2(o.x + 8, y + 10), "Brakk", Stil.GROSS, Stil.GOLD)
	var anteil := "%d %% · %d" % [roundi(100.0 * brakk / maxf(1.0, gesamt)), roundi(brakk)]
	Stil.schreibe(self, Vector2(o.x + BREITE - 8.0 - Stil.breite(anteil, Stil.GROSS), y + 10), anteil, Stil.GROSS, Stil.GOLD)
	draw_rect(Rect2(o.x + 60, y + 6, 120, 8), Color(1, 1, 1, 0.06))
	draw_rect(Rect2(o.x + 60, y + 6, 120.0 * brakk / maxf(1.0, gesamt), 8), Color(Stil.GOLD, 0.75))
	y += 22.0
	if liste.is_empty():
		Stil.schreibe(self, Vector2(o.x + 14, y + 5), "Noch kein Schaden von Brakk.", Stil.KLEIN, Stil.TEXT_BLASS)
	var spitze := 1.0
	for e: Array in liste:
		spitze = maxf(spitze, float(e[1]))
	for i in liste.size():
		var e: Array = liste[i]
		var yy := y + i * 11.0
		Stil.schreibe(self, Vector2(o.x + 14, yy + 5), str(BrakkFortschritt.QUELLEN[e[0]]), Stil.KLEIN, Stil.TEXT)
		var zahl := "%d (%d %%)" % [roundi(float(e[1])), roundi(100.0 * float(e[1]) / maxf(1.0, brakk))]
		Stil.schreibe(self, Vector2(o.x + 196.0 - Stil.breite(zahl, Stil.KLEIN), yy + 5), zahl, Stil.KLEIN, Stil.TEXT_BLASS)
		draw_rect(Rect2(o.x + 202, yy + 2, 70, 6), Color(1, 1, 1, 0.06))
		draw_rect(Rect2(o.x + 202, yy + 2, 70.0 * float(e[1]) / spitze, 6), Color(Stil.GOLD, 0.6))
	y += maxi(liste.size(), 1) * 11.0 + 6.0
	draw_rect(Rect2(o.x + 8, y, BREITE - 16.0, 1), Color(1, 1, 1, 0.12))
	y += 4.0
	# Truppen und Türme klein
	var spitze2 := 1.0
	for e: Dictionary in andere:
		spitze2 = maxf(spitze2, float(e["schaden"]))
	for i in andere.size():
		var e: Dictionary = andere[i]
		var yy := y + i * BRAKK_ZEILE
		Stil.schreibe(self, Vector2(o.x + 14, yy + 6), "%s · %d Kills" % [str(e.get("name", "?")), int(e.get("kills", 0))], Stil.KLEIN, Stil.TEXT_BLASS)
		var zahl := str(roundi(float(e["schaden"])))
		Stil.schreibe(self, Vector2(o.x + 196.0 - Stil.breite(zahl, Stil.KLEIN), yy + 6), zahl, Stil.KLEIN, Stil.TEXT_BLASS)
		draw_rect(Rect2(o.x + 202, yy + 4, 70.0 * float(e["schaden"]) / spitze2, 4), Color(Stil.LEUCHT, 0.5))
