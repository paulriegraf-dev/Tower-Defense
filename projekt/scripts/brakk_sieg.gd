class_name BrakkSieg
extends Control
## 19.11. (Paul): Sieg im Brakk-Mode – die Übersicht nach dem Kameraflug: Stufe, Spielzeit, Leben · Titel für den Spielstil ·
## Ringe mit Stufe · Balken Brakk / Truppen / Türme und Brakks Schaden je Quelle · drei Höhepunkte. Zwei Knöpfe: Nochmal,
## Hauptmenü. `male_bericht` zeichnet denselben Bericht auch im Profil (letzter Sieg zum Nachschauen).
## Gezeichnet im UI-Raster 640×360 wie die übrige Oberfläche, eingepasst in die sicheren Ränder.

const Stil := preload("res://scripts/ui/ui_stil.gd")
const TAFEL := Rect2(120, 34, 400, 292)
const KNOPF_NOCHMAL := Rect2(196, 298, 116, 20)
const KNOPF_MENUE := Rect2(328, 298, 116, 20)

var spiel: Node
var bericht: Dictionary = {}
var _t := 0.0
var _maus := Vector2(-100, -100)


func _ready() -> void:
	size = Vector2(640, 360)
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(delta: float) -> void:
	_t += delta
	SichererRand.einpassen(self, Stil.UI_SKALA)
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_maus = (event as InputEventMouseMotion).position
	elif event is InputEventMouseButton and event.pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var p := (event as InputEventMouseButton).position
		if KNOPF_NOCHMAL.has_point(p):
			spiel._neustart()
		elif KNOPF_MENUE.has_point(p):
			spiel._zum_menue()


func _draw() -> void:
	var a := clampf(_t * 3.0, 0.0, 1.0)
	draw_rect(Rect2(-40, -40, 720, 440), Color(0.02, 0.03, 0.05, 0.55 * a))
	Stil.platte(self, TAFEL, 4.0, Color(0.05, 0.06, 0.09, 0.94), Stil.GOLD)
	var af := str(bericht.get("anfuehrer", "brakk"))   # 20.11.: der Anführer steht mit drauf (Brakk wie bisher)
	Stil.schreibe_mittig(self, Vector2(TAFEL.get_center().x, TAFEL.position.y + 16.0), "SIEG" + ("" if af == "brakk" else " · " + Anfuehrer.name(af).to_upper()), Stil.GROSS, Stil.GOLD)
	male_bericht(self, Rect2(TAFEL.position + Vector2(10, 28), TAFEL.size - Vector2(20, 64)), bericht)
	for k: Array in [[KNOPF_NOCHMAL, "Nochmal"], [KNOPF_MENUE, "Hauptmenü"]]:
		var r: Rect2 = k[0]
		var an := r.has_point(_maus)
		Stil.platte(self, r, 2.0, Stil.METALL if an else Stil.METALL_DUNKEL, Stil.LEUCHT if an else Stil.RAHMEN)
		Stil.schreibe_mittig(self, r.get_center(), str(k[1]), Stil.NORMAL, Stil.LEUCHT if an else Stil.TEXT)


static func _zeit(sek: float) -> String:
	var s := roundi(sek)
	return "%d:%02d" % [s / 60, s % 60]


## Den Bericht in `r` zeichnen (UI-Raster). Zwei Spalten: links Kennzahlen, Titel, Ringe, Höhepunkte – rechts die Balken.
static func male_bericht(ci: CanvasItem, r: Rect2, b: Dictionary, kompakt: bool = false) -> void:
	if b.is_empty():
		Stil.schreibe(ci, r.position + Vector2(4, 8), "Noch kein Sieg im Brakk-Mode.", Stil.NORMAL, Stil.TEXT_BLASS)
		return
	var links := r.position.x
	var af := str(b.get("anfuehrer", "brakk"))   # 20.11.: Quellen und Namen je Anführer
	var mitte := r.position.x + r.size.x * 0.5
	var y := r.position.y + 6.0
	# Kennzahlen als drei Kacheln
	var kacheln := [["STUFE", str(int(b.get("stufe", 1))), Stil.GOLD], ["SPIELZEIT", _zeit(float(b.get("sekunden", 0.0))), Stil.LEUCHT],
		["LEBEN", "%d/%d" % [int(b.get("leben", 0)), int(b.get("max_leben", 0))], Color("ff6b6b")]]
	var kb := (r.size.x - 8.0) / 3.0
	for i in kacheln.size():
		var kr := Rect2(roundf(links + i * (kb + 4.0)), y - 4.0, roundf(kb), 26.0)
		Stil.platte(ci, kr, 2.0, Stil.METALL_TIEF, Stil.RAHMEN)
		Stil.schreibe_mittig(ci, Vector2(kr.get_center().x, kr.position.y + 10.0), kacheln[i][1], Stil.GROSS, kacheln[i][2])
		Stil.schreibe_mittig(ci, Vector2(kr.get_center().x, kr.position.y + 21.0), kacheln[i][0], Stil.KLEIN, Stil.TEXT_BLASS)
	y += 32.0
	# Titel
	Stil.schreibe(ci, Vector2(links, y), "Spielstil:", Stil.KLEIN, Stil.TEXT_BLASS)
	Stil.schreibe(ci, Vector2(links + 44.0, y), str(b.get("titel", "?")), Stil.GROSS, Stil.GOLD)
	y += 11.0
	Stil.schreibe(ci, Vector2(links, y), str(b.get("titel_grund", "")), Stil.KLEIN, Stil.TEXT_BLASS)
	y += 14.0
	# Ringe
	Stil.schreibe(ci, Vector2(links, y), "Ringe", Stil.KLEIN, Stil.LEUCHT)
	var rx := links + 34.0
	for e: Array in b.get("ringe", []):
		var ring := str(e[0])
		var farbe: Color = Einheit.ABZEICHEN.get(ring, Stil.GOLD)
		var text := "%s %d" % [str(BrakkFortschritt.RINGE.get(ring, {}).get("name", ring)).trim_suffix("ring"), int(e[1])]
		Stil.schreibe(ci, Vector2(rx, y), text, Stil.KLEIN, farbe)
		rx += Stil.breite(text, Stil.KLEIN) + 8.0
	if (b.get("ringe", []) as Array).is_empty():
		Stil.schreibe(ci, Vector2(rx, y), "keine", Stil.KLEIN, Stil.TEXT_BLASS)
	y += 14.0
	# Höhepunkte
	Stil.schreibe(ci, Vector2(links, y), "Höhepunkte", Stil.KLEIN, Stil.LEUCHT)
	y += 11.0
	for h: Array in b.get("hoehepunkte", []):
		Stil.schreibe(ci, Vector2(links + 4.0, y), str(h[0]), Stil.KLEIN, Stil.TEXT_BLASS)
		Stil.schreibe(ci, Vector2(mitte - 10.0 - Stil.breite(str(h[1]), Stil.NORMAL), y), str(h[1]), Stil.NORMAL, Stil.TEXT)
		y += 12.0
	# rechts: Anteile und Quellen
	var bx := mitte + 4.0
	var bw := r.end.x - bx
	var by := r.position.y + 38.0
	var an: Dictionary = b.get("anteile", {})
	var gesamt := maxf(1.0, float(an.get("brakk", 0.0)) + float(an.get("truppen", 0.0)) + float(an.get("tuerme", 0.0)))
	Stil.schreibe(ci, Vector2(bx, by), "Schaden der Partie", Stil.KLEIN, Stil.LEUCHT)
	by += 11.0
	for z: Array in [[Anfuehrer.name(af), "brakk", Stil.GOLD], ["Truppen", "truppen", Stil.LEUCHT], ["Türme", "tuerme", Color("bfa3ff")]]:
		var v := float(an.get(z[1], 0.0))
		Stil.schreibe(ci, Vector2(bx, by), str(z[0]), Stil.KLEIN, Stil.TEXT)
		var anteil := "%d %%" % roundi(100.0 * v / gesamt)
		Stil.schreibe(ci, Vector2(bx + bw - Stil.breite(anteil, Stil.KLEIN), by), anteil, Stil.KLEIN, z[2])
		ci.draw_rect(Rect2(bx + 40.0, by - 2.0, bw - 64.0, 5.0), Color(1, 1, 1, 0.06))
		ci.draw_rect(Rect2(bx + 40.0, by - 2.0, (bw - 64.0) * v / gesamt, 5.0), Color(z[2], 0.75))
		by += 11.0
	by += 4.0
	Stil.schreibe(ci, Vector2(bx, by), "Brakks Schaden je Quelle" if af == "brakk" else "Schaden je Quelle · " + Anfuehrer.name(af), Stil.KLEIN, Stil.LEUCHT)
	by += 11.0
	var q: Dictionary = b.get("quellen", {})
	var brakk := 0.0
	var spitze := 1.0
	for k: String in q:
		brakk += float(q[k])
		spitze = maxf(spitze, float(q[k]))
	var gezeigt := 0
	var reihe: Array = BrakkFortschritt.quellen(af).duplicate()
	if kompakt:
		reihe.sort_custom(func(a: String, c: String) -> bool: return float(q.get(a, 0.0)) > float(q.get(c, 0.0)))   # nur die größten
	for k: String in reihe:
		var v := float(q.get(k, 0.0))
		if v <= 0.0 or (kompakt and gezeigt >= 3):
			continue
		gezeigt += 1
		Stil.schreibe(ci, Vector2(bx, by), str(BrakkFortschritt.QUELLEN[k]), Stil.KLEIN, Stil.TEXT)
		var anteil := "%d %%" % roundi(100.0 * v / maxf(1.0, brakk))
		Stil.schreibe(ci, Vector2(bx + bw - Stil.breite(anteil, Stil.KLEIN), by), anteil, Stil.KLEIN, Stil.GOLD)
		ci.draw_rect(Rect2(bx + 64.0, by - 2.0, bw - 88.0, 4.0), Color(1, 1, 1, 0.06))
		ci.draw_rect(Rect2(bx + 64.0, by - 2.0, (bw - 88.0) * v / spitze, 4.0), Color(Stil.GOLD, 0.6))
		by += 10.0
