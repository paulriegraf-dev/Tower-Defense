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
const KNOPF_WEITER := Rect2(240, 332, 160, 20)   # 20.11. (Paul): nach dem Classic-Sieg – weiter in Befehl 24

var spiel: Node
var bericht: Dictionary = {}
var _t := 0.0
var _maus := Vector2(-100, -100)
var _tod_gesehen := false   # 22.11. (Nemesis, Teil 7): erst der Deathscreen „Erledigt von …“, dann der Bericht


## 22.11.: Deathscreen zeigen? (Befehl 24: Brakk fiel durch einen Soldaten – sonst gleich der Bericht wie bisher)
func _tod_seite() -> bool:
	return not _tod_gesehen and not (bericht.get("nemesis_tod", {}) as Dictionary).is_empty()


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
		if _tod_seite():
			if KNOPF_NOCHMAL.has_point(p):
				_tod_gesehen = true   # „Zum Bericht“
				_t = 0.4
			elif KNOPF_MENUE.has_point(p):
				spiel._neustart()
			return
		if bool(bericht.get("weiter", false)) and KNOPF_WEITER.has_point(p):
			spiel.befehl24_weiterspielen()
		elif KNOPF_NOCHMAL.has_point(p):
			spiel._neustart()
		elif KNOPF_MENUE.has_point(p):
			spiel._zum_menue()


func _draw() -> void:
	var a := clampf(_t * 3.0, 0.0, 1.0)
	draw_rect(Rect2(-40, -40, 720, 440), Color(0.02, 0.03, 0.05, 0.55 * a))
	if _tod_seite():
		_male_tod(bericht["nemesis_tod"] as Dictionary)
		return
	Stil.platte(self, TAFEL, 4.0, Color(0.05, 0.06, 0.09, 0.94), Stil.GOLD)
	var af := str(bericht.get("anfuehrer", "brakk"))   # 20.11.: der Anführer steht mit drauf (Brakk wie bisher)
	Stil.schreibe_mittig(self, Vector2(TAFEL.get_center().x, TAFEL.position.y + 16.0), str(bericht.get("kopf", "SIEG")) + ("" if af == "brakk" else " · " + Anfuehrer.name(af).to_upper()), Stil.GROSS, Stil.GOLD)   # 20.11.: Kopf aus dem Bericht (Befehl 24: Überstanden / Gefallen)
	male_bericht(self, Rect2(TAFEL.position + Vector2(10, 28), TAFEL.size - Vector2(20, 64)), bericht)
	var knoepfe: Array = [[KNOPF_NOCHMAL, "Nochmal"], [KNOPF_MENUE, "Hauptmenü"]]
	if bool(bericht.get("weiter", false)):
		knoepfe.append([KNOPF_WEITER, "Weiterspielen …?"])   # 20.11. (Paul)
	for k: Array in knoepfe:
		var r: Rect2 = k[0]
		var an := r.has_point(_maus)
		Stil.platte(self, r, 2.0, Stil.METALL if an else Stil.METALL_DUNKEL, Stil.LEUCHT if an else Stil.RAHMEN)
		Stil.schreibe_mittig(self, r.get_center(), str(k[1]), Stil.NORMAL, Stil.LEUCHT if an else Stil.TEXT)


## 22.11. (Paul, Nemesis Teil 7): Deathscreen – groß „Erledigt von <Dienstgrad Name ‚Beiname‘>“ mit Truppenart, Rang, die
## wievielte Begegnung, Bilanz, womit er Brakk erwischt hat, und einer Zeile von ihm (Hologramm). War er namenlos:
## „… wird befördert zu <Name>“ mit der Tat als Begründung.
func _male_tod(d: Dictionary) -> void:
	const ROT_TOD := Color("ff5a6e")
	Stil.platte(self, TAFEL, 4.0, Color(0.06, 0.04, 0.06, 0.95), ROT_TOD)
	var mx := TAFEL.get_center().x
	var y := TAFEL.position.y + 16.0
	Stil.schreibe_mittig(self, Vector2(mx, y), str(bericht.get("kopf", "GEFALLEN")), Stil.NORMAL, Stil.TEXT_BLASS)
	y += 22.0
	var namenlos := bool(d.get("namenlos", false))
	Stil.schreibe_mittig(self, Vector2(mx, y), "Erledigt von einem namenlosen %s …" % str(d.get("art_dativ", d.get("art", ""))) if namenlos else "ERLEDIGT VON", Stil.NORMAL if namenlos else Stil.GROSS, ROT_TOD)
	y += 14.0 if namenlos else 22.0
	if namenlos:
		Stil.schreibe_mittig(self, Vector2(mx, y), "… der dafür befördert wird – ab jetzt heißt er", Stil.KLEIN, Stil.TEXT_BLASS)
		y += 18.0
	# der Name groß (zweifach, wenn er passt)
	var name_text := str(d.get("name", "?"))
	var groesse := Stil.GROSS
	for g: int in [Stil.GROSS * 2, roundi(Stil.GROSS * 1.5)]:
		if Stil.breite(name_text, g) <= TAFEL.size.x - 24.0:
			groesse = g
			break
	var flackern := 0.85 + 0.15 * sin(_t * 9.0)
	y += float(groesse - Stil.GROSS) * 0.4
	Stil.schreibe_mittig(self, Vector2(mx, y), name_text, groesse, Color(Stil.GOLD, flackern))
	y += float(groesse) * 0.6 + 8.0
	if namenlos:
		Stil.schreibe_mittig(self, Vector2(mx, y), str(d.get("grund", "")), Stil.KLEIN, Stil.TEXT)
		y += 12.0
	elif str(d.get("aufstieg", "")) != "":
		Stil.schreibe_mittig(self, Vector2(mx, y), "%s · „Brakks Bezwinger“" % str(d["aufstieg"]), Stil.KLEIN, Stil.GOLD)
		y += 12.0
	# Kacheln: Truppenart, Rang, Begegnung, Bilanz
	var kacheln := [["TRUPPENART", str(d.get("art", "")), Stil.TEXT], ["RANG", "%d · %s" % [int(d.get("rang", 0)), str(d.get("dienstgrad", ""))], Stil.GOLD],
		["BEGEGNUNG", "%d." % int(d.get("begegnung", 1)), Stil.LEUCHT], ["BILANZ", str(d.get("bilanz", "")).trim_prefix("Stand "), ROT_TOD]]
	var kb := (TAFEL.size.x - 20.0 - 3.0 * 4.0) / 4.0
	for i in kacheln.size():
		var kr := Rect2(roundf(TAFEL.position.x + 10.0 + i * (kb + 4.0)), y, roundf(kb), 28.0)
		Stil.platte(self, kr, 2.0, Stil.METALL_TIEF, Stil.RAHMEN)
		Stil.schreibe_mittig(self, Vector2(kr.get_center().x, kr.position.y + 11.0), str(kacheln[i][1]), Stil.NORMAL, kacheln[i][2])
		Stil.schreibe_mittig(self, Vector2(kr.get_center().x, kr.position.y + 22.0), str(kacheln[i][0]), Stil.KLEIN, Stil.TEXT_BLASS)
	y += 40.0
	Stil.schreibe(self, Vector2(TAFEL.position.x + 14.0, y), "Erwischt:", Stil.KLEIN, Stil.TEXT_BLASS)
	Stil.schreibe(self, Vector2(TAFEL.position.x + 58.0, y), str(d.get("womit", "")), Stil.NORMAL, Stil.TEXT)
	y += 12.0
	Stil.schreibe(self, Vector2(TAFEL.position.x + 14.0, y), "Bilanz:", Stil.KLEIN, Stil.TEXT_BLASS)
	Stil.schreibe(self, Vector2(TAFEL.position.x + 58.0, y), str(d.get("bilanz", "")), Stil.NORMAL, Stil.TEXT)
	y += 16.0
	# seine Zeile im Hologramm (cyan, Rasterzeilen, leichtes Flackern)
	var holo := Rect2(TAFEL.position.x + 24.0, y, TAFEL.size.x - 48.0, 40.0)
	var a := clampf((_t - 0.6) * 2.0, 0.0, 1.0)
	draw_rect(holo, Color(0.3, 0.85, 1.0, 0.07 * a))
	draw_rect(holo, Color(0.5, 0.9, 1.0, 0.5 * a), false, 1.0)
	var zy := holo.position.y + 2.0
	while zy < holo.end.y:
		draw_line(Vector2(holo.position.x, zy), Vector2(holo.end.x, zy), Color(0.5, 0.9, 1.0, 0.05 * a), 1.0)
		zy += 3.0
	Stil.absatz(self, holo.position + Vector2(8, 8), "„%s“" % str(d.get("zeile", "")), holo.size.x - 16.0, Stil.NORMAL, Color(Stil.LEUCHT, a * (0.9 + 0.1 * sin(_t * 23.0))))
	for k: Array in [[KNOPF_NOCHMAL, "Zum Bericht"], [KNOPF_MENUE, "Nochmal"]]:
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
	var ohne := bool(b.get("ohne_anteile", false))   # 20.11. (Paul): Befehl 24 – keine Anteile (Truppen und Türme sind dort der Gegner)
	if not ohne:
		Stil.schreibe(ci, Vector2(bx, by), "Schaden der Partie", Stil.KLEIN, Stil.LEUCHT)
		by += 11.0
	for z: Array in ([] if ohne else [[Anfuehrer.name(af), "brakk", Stil.GOLD], ["Truppen", "truppen", Stil.LEUCHT], ["Türme", "tuerme", Color("bfa3ff")]]):
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
	# 22.11. (Paul, Nemesis Teil 7): Befehl 24 – Feldbeförderungen dieses Laufs, vertriebene und ausgeschaltete Benannte
	var nem: Array = b.get("nemesis", [])
	if not nem.is_empty():
		by += 6.0
		Stil.schreibe(ci, Vector2(bx, by), "Eliten dieses Laufs", Stil.KLEIN, Stil.LEUCHT)
		by += 11.0
		const MARKE := {"befoerdert": ["Befördert", Color("ffb84d")], "vertrieben": ["Vertrieben", Color("7fe0ff")], "ausgeschaltet": ["Ausgeschaltet", Color("ff5a6e")], "versetzt": ["Versetzt", Color("8b95a3")]}
		var gezeigt_n := 0
		for zeile: Array in nem:
			if by > r.end.y - 4.0 or (kompakt and gezeigt_n >= 3):
				Stil.schreibe(ci, Vector2(bx, by), "+ %d weitere" % (nem.size() - gezeigt_n), Stil.KLEIN, Stil.TEXT_BLASS)
				break
			var m: Array = MARKE.get(str(zeile[1]), ["", Stil.TEXT])
			Stil.schreibe(ci, Vector2(bx, by), str(m[0]), Stil.KLEIN, m[1] as Color)
			var nm := str(zeile[0]) + ("" if str(zeile[2]) == "" or str(zeile[1]) == "befoerdert" else " · " + str(zeile[2]))
			if Stil.breite(nm, Stil.KLEIN) > bw - 50.0:
				while nm.length() > 4 and Stil.breite(nm + "…", Stil.KLEIN) > bw - 50.0:
					nm = nm.left(-1)
				nm += "…"
			Stil.schreibe(ci, Vector2(bx + 48.0, by), nm, Stil.KLEIN, Stil.TEXT)
			by += 10.0
			gezeigt_n += 1
