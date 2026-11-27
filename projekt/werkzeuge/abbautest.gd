extends SceneTree
## 22.11.: Brakk-Mode – Abbauen und Zurücknehmen ([Z], Menü-Knopf, [Entf]) headless prüfen.
##
##   godot --headless --path . --fixed-fps 60 -s werkzeuge/abbautest.gd
##
##   1. Fabrik bauen, [Z]: Budget wie vorher, Fabrik weg, Stapel leer
##   2. Stapel: fünf Wälle, [Z] nimmt der Reihe nach zurück; sechster Schritt reicht nicht mehr zurück (Maximum 5)
##   3. Fabrik bauen, Welle läuft (phase KAMPF): Abbauen und [Z] werden abgelehnt (Bauwerk bleibt, Budget gleich)
##   4. Wellenstart leert den Stapel; nach der Welle: Abbauen mit Erstattung nach erstattung() (nicht voll)
##   5. Ringfeld: Fabriken im Feld zählen live (4 → 3 nach dem Abbauen), Ausstoß der abgebauten Fabrik ist weg
##   6. Menü-Knopf: Fabrikmenü öffnet im Brakk-Mode, zweiter Druck baut ab (erster fragt nur)
##   7. Befehl 24 / Normalspiel-Regeln: brakk_abbau_grund() ist leer in der Bauphase, nicht leer in der Welle
## Am Ende „TEST ABBAU OK“ oder die Fehler. Schreibt ins Profil (user://) – vorher sichern.

var spiel: Node
var ego: EgoModus
var warte := 20
var t0 := 0
var fehler: Array[String] = []


func _initialize() -> void:
	BrakkTutorial.erzwingen = false
	Werte.setze_anfuehrer("brakk")
	if Werte.karte_name != "paulland" or not Werte.karte_gross:
		Werte.karte_name = "paulland"
		Werte.setze_karte(true)
		Werte.speichere_einstellungen()
	var main_skript: GDScript = load("res://scripts/main.gd")
	main_skript.set("naechster_start", "brakk")
	spiel = load("res://main.tscn").instantiate()
	root.add_child(spiel)
	spiel.protokoll_an = false
	t0 = Time.get_ticks_msec()


func pruefe(ok: bool, text: String) -> void:
	print("%s %s" % ["OK  " if ok else "FEHL", text])
	if not ok:
		fehler.append(text)


func _process(_delta: float) -> bool:
	if warte > 0:
		warte -= 1
		return false
	if ego == null:
		ego = spiel.ego
		if ego == null:
			if Time.get_ticks_msec() - t0 > 20000:
				pruefe(false, "keine Ego-Sicht")
				_ende()
			return false
		warte = 10
		return false
	_pruefe_alles()
	_ende()
	return false


func _ende() -> void:
	print("TEST ABBAU OK" if fehler.is_empty() else "TEST ABBAU FEHLER: %s" % ", ".join(fehler))
	quit(0 if fehler.is_empty() else 1)


func _frei(typ: int, ab: int = 0) -> Vector2i:
	var b: Vector2i = spiel.karte.zelle_bei(spiel.kommandant.position)
	var n := 0
	for r in range(2, 12):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				var z := b + Vector2i(dx, dy)
				if maxi(absi(dx), absi(dy)) == r and z.x >= Werte.ZONE_SPALTEN and spiel.bau_hindernis(z, typ) == "":
					if n >= ab:
						return z
					n += 1
	return Karte.KEINE


func _pruefe_alles() -> void:
	var k: Karte = spiel.karte
	spiel.budget = 5000
	# 1. Fabrik bauen, [Z]
	var b0: int = spiel.budget
	var z := _frei(Karte.FABRIK)
	pruefe(z != Karte.KEINE and spiel.baue(z, Karte.FABRIK), "Fabrik gebaut")
	pruefe(spiel.budget < b0 and spiel.fabriken.has(z), "Fabrik kostet und steht")
	pruefe(spiel.nimm_bau_zurueck(), "[Z] nimmt zurück")
	pruefe(spiel.budget == b0 and not spiel.fabriken.has(z) and k.inhalt(z) == Karte.FREI, "Budget wie vorher, Fabrik weg")
	pruefe(spiel._bau_stapel.is_empty(), "Stapel leer")
	# 2. Stapel mit fünf Schritten
	var felder: Array[Vector2i] = []
	for i in 7:
		var w := _frei(Karte.WALL, i * 3)
		if w != Karte.KEINE and spiel.baue(w, Karte.WALL):
			felder.append(w)
	pruefe(felder.size() == 7, "7 Wälle gebaut")
	pruefe(spiel._bau_stapel.size() == spiel.BAU_STAPEL_MAX, "Stapel hält höchstens %d Schritte (%d)" % [spiel.BAU_STAPEL_MAX, spiel._bau_stapel.size()])
	for i in 5:
		spiel.nimm_bau_zurueck()
	pruefe(k.inhalt(felder[6]) == Karte.FREI and k.inhalt(felder[2]) == Karte.FREI, "fünf Schritte zurück: die letzten 5 Wälle sind weg")
	pruefe(k.inhalt(felder[1]) == Karte.WALL and k.inhalt(felder[0]) == Karte.WALL, "der sechste und siebte Schritt zurück gehen nicht mehr")
	pruefe(not spiel.nimm_bau_zurueck(), "leerer Stapel: nichts zum Zurücknehmen")
	for f: Vector2i in [felder[0], felder[1]]:
		spiel.reisse_ab(f)
	# 3. in der Welle gesperrt
	var z2 := _frei(Karte.FABRIK)
	spiel.baue(z2, Karte.FABRIK)
	var b1: int = spiel.budget
	spiel.phase = 1
	pruefe(spiel.brakk_abbau_grund() != "", "Welle: Abbauen gesperrt (%s)" % spiel.brakk_abbau_grund())
	pruefe(not spiel.brakk_abbauen(z2) and not spiel.nimm_bau_zurueck(), "Welle: Abbauen und [Z] abgelehnt")
	pruefe(spiel.fabriken.has(z2) and spiel.budget == b1, "Welle: Fabrik bleibt, Budget gleich")
	# 4. nach dem Wellenstart: normale Erstattung
	spiel._bezahlt.clear()
	spiel._bau_stapel.clear()
	spiel.phase = 0
	var soll: int = spiel.erstattung(z2)
	var b2: int = spiel.budget
	pruefe(spiel.brakk_abbau_grund() == "", "Bauphase: Abbauen erlaubt")
	pruefe(spiel.brakk_abbauen(z2) and spiel.budget - b2 == soll, "Abbauen erstattet nach erstattung() (+%d, erwartet +%d)" % [spiel.budget - b2, soll])
	pruefe(not spiel.fabriken.has(z2) and k.inhalt(z2) == Karte.FREI, "Fabrik nach dem Abbauen weg")
	# 5. Ringfeld: Zähler live
	var f: BrakkFortschritt = spiel.kommandant.fortschritt
	var zs: Array[Vector2i] = []
	var ecke := _frei(Karte.FABRIK, 20)
	if f != null and ecke != Karte.KEINE:
		if not f.ringe.has("laser"):
			f.ringe.append("laser")
		f.setze_feld("laser", ecke)
		for dx in 2:
			for dy in 2:
				var c := ecke + Vector2i(dx, dy)
				if spiel.baue(c, Karte.FABRIK, true):
					zs.append(c)
		pruefe(ego.ringwerk._feld_fabriken(ecke).size() == zs.size() and zs.size() >= 2, "Ringfeld: %d Fabriken im Feld" % zs.size())
		var vorher := zs.size()
		spiel.brakk_abbauen(zs[0])
		pruefe(ego.ringwerk._feld_fabriken(ecke).size() == vorher - 1, "Ringfeld: nach dem Abbauen %d/4 (vorher %d)" % [ego.ringwerk._feld_fabriken(ecke).size(), vorher])
		pruefe(not spiel.fabriken.has(zs[0]), "abgebaute Fabrik liefert nichts mehr (nicht in spiel.fabriken)")
		for c: Vector2i in zs:
			spiel.reisse_ab(c)
		f.felder.erase("laser")
	# 6. Menü-Knopf
	var z3 := _frei(Karte.FABRIK)
	spiel.baue(z3, Karte.FABRIK)
	spiel._oeffne_fabrikmenue(z3)
	pruefe(spiel._fabrikmenue.visible and spiel._fabrikmenue.zelle == z3, "Brakk-Mode: Fabrikmenü öffnet")
	spiel._fabrikmenue._abbau_druck()
	pruefe(spiel.fabriken.has(z3), "Menü: erster Druck fragt nur")
	spiel._fabrikmenue._abbau_druck()
	pruefe(not spiel.fabriken.has(z3), "Menü: zweiter Druck baut ab")
