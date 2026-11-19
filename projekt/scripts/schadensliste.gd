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


## 19.11. (Paul): [Tab] im Brakk-Mode – dezent am linken Rand, damit man es offen lassen mag: Brakk mit seinem Anteil
## am Schaden der Runde und Balken je Quelle (die stärksten vier), darunter klein die stärksten drei Truppen und Türme.
const B_BREITE := 120.0
const B_ZEILE := 8.0
const B_QUELLEN := 4
const B_ANDERE := 3


## Text auf eine Breite kürzen (mit „…“).
func _kurz(text: String, weite: float) -> String:
	if Stil.breite(text, Stil.KLEIN) <= weite:
		return text
	while text.length() > 2 and Stil.breite(text + "…", Stil.KLEIN) > weite:
		text = text.substr(0, text.length() - 1)
	return text.strip_edges() + "…"


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
	andere = andere.slice(0, B_ANDERE)
	var liste: Array = []
	for q: String in BrakkFortschritt.QUELLEN:
		if float(quellen.get(q, 0.0)) > 0.0:
			liste.append([q, float(quellen[q])])
	liste.sort_custom(func(a, b): return float(a[1]) > float(b[1]))
	liste = liste.slice(0, B_QUELLEN)
	var hoehe := 9.0 + 12.0 + maxi(liste.size(), 1) * B_ZEILE + (5.0 + andere.size() * B_ZEILE if not andere.is_empty() else 0.0) + 4.0
	var o := Vector2(6.0, 46.0)   # links unter der Statusleiste; die Bauliste der Ego-Sicht rückt darunter
	draw_rect(Rect2(o, Vector2(B_BREITE, hoehe)), Color(0.04, 0.05, 0.08, 0.66))
	draw_rect(Rect2(o, Vector2(B_BREITE, hoehe)), Color(1, 1, 1, 0.12), false, 0.5)
	draw_rect(Rect2(o, Vector2(1.0, hoehe)), Color(Stil.GOLD, 0.8))
	var rechts := o.x + B_BREITE - 5.0
	Stil.schreibe(self, o + Vector2(6, 6), "Runde %d" % runde, Stil.KLEIN, Stil.TEXT_BLASS)
	var summe := "gesamt %d" % roundi(gesamt)
	Stil.schreibe(self, Vector2(rechts - Stil.breite(summe, Stil.KLEIN), o.y + 6), summe, Stil.KLEIN, Stil.TEXT_BLASS)
	# Brakk
	var y := o.y + 11.0
	Stil.schreibe(self, Vector2(o.x + 6, y + 5), "Brakk", Stil.NORMAL, Stil.GOLD)
	var anteil := "%d %%" % roundi(100.0 * brakk / maxf(1.0, gesamt))
	Stil.schreibe(self, Vector2(rechts - Stil.breite(anteil, Stil.NORMAL), y + 5), anteil, Stil.NORMAL, Stil.GOLD)
	draw_rect(Rect2(o.x + 36, y + 3, 52, 4), Color(1, 1, 1, 0.07))
	draw_rect(Rect2(o.x + 36, y + 3, 52.0 * brakk / maxf(1.0, gesamt), 4), Color(Stil.GOLD, 0.75))
	y += 12.0
	if liste.is_empty():
		Stil.schreibe(self, Vector2(o.x + 10, y + 4), "noch kein Schaden", Stil.KLEIN, Stil.TEXT_BLASS)
	for i in liste.size():
		var e: Array = liste[i]
		var yy := y + i * B_ZEILE
		Stil.schreibe(self, Vector2(o.x + 10, yy + 4), _kurz(str(BrakkFortschritt.QUELLEN[e[0]]), 50.0), Stil.KLEIN, Stil.TEXT)
		draw_rect(Rect2(o.x + 62, yy + 2, 30, 3), Color(1, 1, 1, 0.07))
		draw_rect(Rect2(o.x + 62, yy + 2, 30.0 * float(e[1]) / maxf(1.0, brakk), 3), Color(Stil.GOLD, 0.6))
		var zahl := "%d %%" % roundi(100.0 * float(e[1]) / maxf(1.0, brakk))
		Stil.schreibe(self, Vector2(rechts - Stil.breite(zahl, Stil.KLEIN), yy + 4), zahl, Stil.KLEIN, Stil.TEXT_BLASS)
	y += maxi(liste.size(), 1) * B_ZEILE
	if andere.is_empty():
		return
	y += 2.0
	draw_rect(Rect2(o.x + 6, y, B_BREITE - 11.0, 0.5), Color(1, 1, 1, 0.14))
	y += 3.0
	for i in andere.size():
		var e: Dictionary = andere[i]
		var yy := y + i * B_ZEILE
		var zahl := "%d %%" % roundi(100.0 * float(e["schaden"]) / maxf(1.0, gesamt))
		Stil.schreibe(self, Vector2(o.x + 10, yy + 4), _kurz(str(e.get("name", "?")), B_BREITE - 42.0), Stil.KLEIN, Stil.TEXT_BLASS)
		Stil.schreibe(self, Vector2(rechts - Stil.breite(zahl, Stil.KLEIN), yy + 4), zahl, Stil.KLEIN, Stil.TEXT_BLASS)
