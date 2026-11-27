class_name PartieStart
extends Node
## Aufbau zu Spielbeginn (27.11., Knoten-Umbau Schritt 2 – vorher in main.gd): Startlage aus dem Regelpaket,
## Alarmstart mit Formation aus [H], vorgebaute Szenario-Bauten, Einführungsfenster und der Trupp, der schon
## unterwegs ist. Regeln unverändert; Zugriff auf main.gd über `spiel` (Kindknoten `spiel.partie_start`).
## `setze_kartenmauern` und `_setze_stand` bleiben in main.gd (nutzen Editor, Order 24, Zwischenstand, Brakk).

const KAMPF := 1   # wie main.gd Phase.KAMPF

var spiel: Node


## 20.11. (Schritt 5): Startlage aus dem Regelpaket – beschädigte Mauer der Karte, Checkpoints schon beim Gegner.
func startlage() -> void:
	var anteil := clampf(float(Werte.KARTE_REGELN.get("mauer_leben", 100)) / 100.0, 0.05, 1.0)
	if anteil < 1.0:
		for z: Vector2i in Werte.MAUERN:
			if spiel.karte.inhalt(z) == Karte.WALL:
				spiel.karte.leben[z] = spiel.karte.max_leben(Karte.WALL) * anteil
	if bool(Werte.KARTE_REGELN.get("cp_feind", false)) and not spiel.karte.checkpoints.is_empty():
		spiel.karte.cp_aktiv = true
		for i in spiel.karte.cp_feind.size():
			spiel.karte.cp_feind[i] = true
		spiel.karte.aktualisiere_pfad()
		spiel.karte.queue_redraw()


## 20.11. (Schritt 5b, Alarmstart): Regelpaket "formation" ("" = Zufall unter Werte.ALARM_FORMATIONEN, sonst der Name aus [H]).
## Die Formation wird auf die Karte gelegt (Checkpoints und Basis wie im Plan), dazu "alarm_fabriken" Fabriken (Stufe 1,
## reihum spezialisiert) und "alarm_stellungen" Stellungen auf den Wallfeldern mit der größten Wegabdeckung. Danach sind
## "gesprengt" Erdwälle weg. Alles gehört zur Karte (nicht abreißbar). Nur auf Karten mit 28×14 (Größe der Pläne).
var alarm_formation := ""   # welche Formation liegt (für Anzeige und Prüfung)

func alarmstart() -> void:
	var r: Dictionary = Werte.KARTE_REGELN
	if not r.has("formation") or Werte.SPALTEN != Nachschlag.SP or Werte.ZEILEN != Nachschlag.ZE or spiel.phantom_modus != "":
		return
	var name := str(r["formation"])
	if not Nachschlag.PLAENE_GROSS.has(name):
		name = Zufall.waehle(Werte.ALARM_FORMATIONEN)
	alarm_formation = name
	formation_aufbauen(name, clampi(int(r.get("alarm_fabriken", 6)), 0, 12), clampi(int(r.get("alarm_stellungen", 4)), 0, 12), clampi(int(r.get("gesprengt", 6)), 0, 40))


## 20.11. (Schritt 5b): Formation `name` aus [H] (28×14) mit ihren Checkpoints hinstellen, dazu `anzahl` Fabriken (Stufe 1,
## reihum spezialisiert), `soll` Stellungen mit der größten Wegabdeckung und `weg_damit` gesprengte Erdwälle. Alles gehört
## zur Karte. Alarmstart und Order 24. Gibt die Stellungen zurück.
func formation_aufbauen(name: String, anzahl: int, soll: int, weg_damit: int) -> Array[Vector2i]:
	var plan: Array = (Nachschlag.PLAENE_GROSS[name] as Array).duplicate()
	if Zufall.ganz(2) == 1:
		plan.reverse()   # mal oben, mal unten gespiegelt
	var waelle: Array = []
	var fabrik_felder: Array[Vector2i] = []
	var cps: Array = [Karte.KEINE, Karte.KEINE]
	for y in plan.size():
		var zeile := str(plan[y])
		for x in zeile.length():
			var c := zeile[x]
			var z := Vector2i(x, y)
			if c in ["#", "S", "T", "O"] and spiel.karte.ist_bebaubar(z):
				waelle.append([x, y, "tor" if c == "O" else ""])
			elif c == "F" and spiel.karte.ist_bebaubar(z):
				fabrik_felder.append(z)
			elif c == "1" or c == "2":
				cps[int(c) - 1] = z
	if cps[0] != Karte.KEINE and cps[1] != Karte.KEINE:
		spiel.setze_checkpoints(cps)
	# Fabriken: erst die Felder des Plans, dann freie Felder nah an der Basis
	var belegt := {}
	for w: Array in waelle:
		belegt[Vector2i(int(w[0]), int(w[1]))] = true
	if fabrik_felder.size() < anzahl:
		var frei: Array[Vector2i] = []
		for y in Werte.ZEILEN:
			for x in range(Werte.ZONE_SPALTEN + 4, Werte.SPALTEN):
				var z := Vector2i(x, y)
				if spiel.karte.ist_bebaubar(z) and not belegt.has(z) and not fabrik_felder.has(z) and not spiel.karte.ist_basis(z) and absi(y - spiel.karte.basis.y) > 1:
					frei.append(z)
		frei.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.distance_squared_to(spiel.karte.basis) < b.distance_squared_to(spiel.karte.basis))
		for z: Vector2i in frei:
			if fabrik_felder.size() >= anzahl:
				break
			var nah := false
			for f: Vector2i in fabrik_felder:
				if absi(f.x - z.x) <= 1 and absi(f.y - z.y) <= 1:
					nah = true
			if not nah:
				fabrik_felder.append(z)
	var fabriken_liste: Array = []
	for i in mini(anzahl, fabrik_felder.size()):
		fabriken_liste.append({"x": fabrik_felder[i].x, "y": fabrik_felder[i].y, "einheit": Werte.ALARM_TRUPPEN[i % Werte.ALARM_TRUPPEN.size()], "stufe": 1})
	spiel._setze_stand({"waelle": waelle, "fabriken": fabriken_liste, "batterien": []})
	# Stellungen: Wallfelder, von denen aus die meisten Wegfelder in Reichweite liegen (mindestens 3 Felder auseinander)
	var weg := {}
	for z: Vector2i in spiel.karte.pfad:
		weg[z] = true
	for neben: Array in spiel.karte.neben_pfade:
		for z: Vector2i in neben:
			weg[z] = true
	var kandidaten: Array = []
	for z: Vector2i in spiel.karte.feld:
		if spiel.karte.feld[z] != Karte.WALL or spiel.karte.ausbau.has(z):
			continue
		var n := 0
		for w: Vector2i in weg:
			if Vector2(w - z).length() <= Werte.STELLUNG_ABDECKUNG:
				n += 1
		kandidaten.append([n, z])
	kandidaten.sort_custom(func(a: Array, b: Array) -> bool: return int(a[0]) > int(b[0]))
	var stellungen: Array[Vector2i] = []
	for k: Array in kandidaten:
		if stellungen.size() >= soll:
			break
		var z: Vector2i = k[1]
		var zu_nah := false
		for s: Vector2i in stellungen:
			if Vector2(s - z).length() < 3.0:
				zu_nah = true
		if not zu_nah:
			stellungen.append(z)
			spiel.karte.baue_aus(z, Karte.STELLUNG)
	# Gesprengt: blanke Erdwälle (keine Stellung, kein Tor, keine Turmstütze), bevorzugt am Gegnerweg
	var blank: Array = []
	for z: Vector2i in spiel.karte.feld:
		if spiel.karte.feld[z] == Karte.WALL and not spiel.karte.ausbau.has(z) and not spiel.karte.stuetze_von.has(z):
			var am_weg := 0
			for d: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				if weg.has(z + d):
					am_weg = 1
			blank.append([am_weg * 10 + Zufall.ganz(10), z])
	blank.sort_custom(func(a: Array, b: Array) -> bool: return int(a[0]) > int(b[0]))
	for i in mini(weg_damit, blank.size()):
		spiel.karte.entferne(blank[i][1] as Vector2i)
	for z: Vector2i in spiel.karte.feld:
		spiel.karte.fest[z] = true   # gehört zur Karte: ausbaubar, nicht abreißbar
	spiel.karte.aktualisiere_pfad()
	spiel.karte.queue_redraw()
	print("FORMATION %s · %d Erdwälle · %d Fabriken · Stellungen %s · %d gesprengt" % [name, waelle.size(), fabriken_liste.size(), str(stellungen), mini(weg_damit, blank.size())])
	return stellungen


## 20.11. (Schritt 5b, Alarmstart): Regelpaket "trupp_unterwegs" (Typen) – dieser Trupp steht beim Start schon auf einem
## Drittel des Gegnerwegs und läuft los, sobald die erste Welle beginnt.
func trupp_unterwegs() -> void:
	var typen: Variant = Werte.KARTE_REGELN.get("trupp_unterwegs", [])
	if not (typen is Array) or (typen as Array).is_empty() or spiel.phase != KAMPF or spiel.karte.pfad.size() < 6:
		return
	var i := int(spiel.karte.pfad.size() * 0.3)
	var zelle: Vector2i = spiel.karte.pfad[i]
	var ziel: int = spiel.karte.erstes_ziel()
	for k in range(ziel, spiel.karte.checkpoints.size()):
		var j: int = spiel.karte.pfad.find(spiel.karte.checkpoints[k])
		if j >= 0 and j < i:
			ziel = k + 1   # Checkpoints, die schon hinter ihm liegen, läuft er nicht mehr an
	var trupp: Array = []
	for typ: Variant in (typen as Array):
		if not Werte.GEGNER.has(str(typ)):
			continue
		var g: Gegner = spiel._neuer_gegner(str(typ), zelle, ziel)
		g.trupp = trupp
		trupp.append(g)
	if Werte.ZONE2.size != Vector2i.ZERO:
		for g: Gegner in trupp:
			spiel._zange_route(g)
	spiel.melde("Ein Trupp ist schon durch die Linien – er steht mitten auf dem Weg!", 6.0)


## 18.11.: Szenario mit vorgebauten Türmen/Fabriken (Werte.KARTE_STAND): hinstellen, nicht abreißbar (sonst gäbe der
## Abriss Geld für etwas, das nie bezahlt wurde). Liegt ein zufälliger Checkpoint darauf, wird er neu gewürfelt.
func kartenbauten() -> void:
	if Werte.KARTE_STAND.is_empty():
		return
	spiel._setze_stand(Werte.KARTE_STAND)
	spiel.setze_kartenmauern()
	markiere_kartenbauten()
	for cp: Vector2i in spiel.karte.checkpoints:
		if spiel.karte.feld.has(cp):
			spiel.setze_checkpoints(spiel.karte._zufalls_checkpoints())
			break


## Alle Felder, die das Szenario vorgebaut hat, als „gehört zur Karte“ markieren (auch nach „Fortsetzen“).
func markiere_kartenbauten() -> void:
	var st: Dictionary = Werte.KARTE_STAND
	var felder: Array[Vector2i] = []
	for w: Array in st.get("waelle", []):
		felder.append(Vector2i(int(w[0]), int(w[1])))
	for f: Dictionary in st.get("fabriken", []):
		felder.append(Vector2i(int(f["x"]), int(f["y"])))
	for b: Dictionary in st.get("batterien", []):
		felder.append(Vector2i(int(b["x"]), int(b["y"])))
		felder.append(Vector2i(int(b["px"]), int(b["py"])))
	for z: Vector2i in felder:
		if spiel.karte.inhalt(z) != Karte.FREI:
			spiel.karte.fest[z] = true


## 18.11.: Einführungstext eines Szenarios zu Spielbeginn (Fenster mit „Los“).
func zeige_einfuehrung() -> void:
	var text := str(Werte.KARTE_REGELN.get("einfuehrung", "")).strip_edges()
	if text == "" or DisplayServer.get_name() == "headless":
		return
	if spiel.brakk_modus:
		spiel.melde("%s: %s" % [Werte.KARTE_TITEL, text], 10.0)   # 20.11.: im Brakk-Mode kein zweites Fenster über der Einsatz-Tafel
		return
	spiel.add_child(ModLeiste.Tafel.new(Werte.KARTE_TITEL, text, [["Los geht's", Callable()]]))
