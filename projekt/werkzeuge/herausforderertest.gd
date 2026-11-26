extends SceneTree
## 26.11. (Paul): Befehl 24 – der Herausforderer (Boss zu Minute 9 und 14), headless.
##
##   godot --headless --path . --fixed-fps 60 -s werkzeuge/herausforderertest.gd
##
## Ohne Zusatz setzt der Test die Zeitpunkte selbst. Mit `-- zeiten` gelten die echten (540 s und 840 s): Der Test stellt
## die Überlebens-Uhr kurz davor. Schreibt nur user://nemesis_herausforderer_test.json.
## Am Ende „TEST HERAUSFORDERER OK“ oder die Fehler.

var spiel: Node
var o: Order24
var n: Nemesis
var warte := 10
var schritt := 0
var fehler: Array[String] = []
var merk := {}
var echte_zeiten := false


func _initialize() -> void:
	Nemesis.datei = "user://nemesis_herausforderer_test.json"
	Nemesis.zuruecksetzen()
	OS.set_environment("TD_KARTE_NAME", "szenario_order24")
	Werte.lade_karte("szenario_order24")
	var r: Dictionary = (Werte.KARTE_REGELN.get("order24", {}) as Dictionary).duplicate()
	r["karte"] = "3-zitadelle"
	r["brakk_schaden"] = 0
	r["geheim_ab"] = 0
	r["welle_takt"] = 9999
	r["elite_jede"] = 0
	r["flucht_sek"] = 0
	r["jagd_start"] = 0
	r["vorstoss"] = false
	echte_zeiten = OS.get_cmdline_user_args().has("zeiten")
	r["herausforderer"] = echte_zeiten   # sonst löst der Test ihn selbst aus
	if echte_zeiten:
		r["welle_takt"] = 60
	Order24.test_werte = r
	var main_skript: GDScript = load("res://scripts/main.gd")
	main_skript.set("naechster_start", "normal")
	spiel = load("res://main.tscn").instantiate()
	root.add_child(spiel)
	spiel.protokoll_an = false


const SOLL_PRUEFUNGEN := 87
const SOLL_ECHT := 6
var geprueft := 0


func pruefe(ok: bool, text: String) -> void:
	geprueft += 1
	print("%s %s" % ["OK  " if ok else "FEHL", text])
	if not ok:
		fehler.append(text)


func _weiter() -> void:
	schritt += 1
	merk["t"] = o.zeit
	merk["wand"] = Time.get_ticks_msec()


## Nach dem Laufende steht die Überlebens-Uhr – dann zählt die Wanduhr.
func _seit_wand() -> float:
	return (Time.get_ticks_msec() - int(merk.get("wand", 0))) / 1000.0


func _seit() -> float:
	return o.zeit - float(merk.get("t", o.zeit))


func _tafeln(art: String) -> Array:
	return o.tafeln.protokoll.filter(func(t: Dictionary) -> bool: return str(t["art"]) == art)


func _process(_delta: float) -> bool:
	if warte > 0:
		warte -= 1
		return false
	o = spiel.order24
	if o == null:
		return false
	if not o.laeuft:
		o.verrat_ueberspringen = true
		var tafel: Variant = spiel.ego.get("_briefing") if spiel.ego != null else null
		if tafel != null and (tafel as Control).visible:
			(tafel as Control).visible = false
		return false
	n = o.nemesis
	var k: Kommandant = spiel.kommandant
	if k != null and bool(merk.get("heilen", true)):
		k.leben = k.max_leben
	var weiter := _schritte_echt() if echte_zeiten else _schritte()
	if o.vorbei and not bool(merk.get("ende_erwartet", false)):
		pruefe(false, "Lauf vorzeitig vorbei (Schritt %d)" % schritt)
		return _fertig()
	return weiter


func _fertig() -> bool:
	Nemesis.zuruecksetzen()
	# Skriptfehler brechen eine Prüfung still ab: jede erwartete muss gelaufen sein
	var soll := SOLL_ECHT if echte_zeiten else SOLL_PRUEFUNGEN
	if geprueft < soll:
		fehler.append("nur %d von %d Prüfungen gelaufen" % [geprueft, soll])
	if fehler.is_empty():
		print("TEST HERAUSFORDERER OK")
	else:
		print("TEST HERAUSFORDERER FEHLER (%d): %s" % [fehler.size(), "; ".join(PackedStringArray(fehler))])
	quit(0 if fehler.is_empty() else 1)
	return true


func _schritte() -> bool:
	match schritt:
		0:
			if o.zeit > 2.0:
				_punkt1()
				_weiter()
		1:
			_punkt2_start()
			_weiter()
		2:
			if _seit() > 1.5:
				_punkt2_ansage()
				_weiter()
		3:
			if o.zeit > float(merk["auftritt_um"]) + 0.8:
				_punkt2_auftritt()
				_weiter()
		4:
			if _seit() > 5.0:
				_punkt2_pause()
				_weiter()
		5:
			if _seit() > 2.0:
				_punkt2_ende()
				_weiter()
		6:
			_punkt3()
			_weiter()
		7:
			_punkt4_start()
			_weiter()
		8:
			if _seit() > 9.0:
				_punkt4_ende()
				_weiter()
		9:
			_punkt5_start()
			_weiter()
		10:
			_punkt5_laeuft()
			if _seit() > 30.0:
				_punkt5_wut()
				_weiter()
		11:
			_punkt5_laeuft()
			if _seit() > 20.0:
				_punkt5_ende()
				_weiter()
		12:
			if not merk.has("p6"):
				merk["p6"] = 0
				_punkt6_wahl_und_waffen()
				_punkt6_ringe()
				merk["t"] = o.zeit
			elif int(merk["p6"]) == 0:
				spiel.kommandant.position = merk["brakk"]
				o.herausforderer._bis_angriff = 999.0
				o.herausforderer.seit = 0.0
				if _seit() > 5.0:
					_punkt6_takt_start()
					merk["p6"] = 1
					merk["t"] = o.zeit
			elif int(merk["p6"]) == 1:
				o.herausforderer._bis_angriff = 999.0
				o.herausforderer.angriff = {}
				if _seit() > 1.5:
					_punkt6_takt_an()
					merk["p6"] = 2
			elif int(merk["p6"]) == 2:
				o.herausforderer._bis_angriff = 999.0
				o.herausforderer.angriff = {}
				o.herausforderer.seit = 0.0
				if _seit() > 11.5:
					_punkt6_takt_aus()
					_punkt7_niederlage_vorbereiten()
					_weiter()
		13:
			if _seit() > 0.3 and not merk.has("tempo7"):
				merk["tempo7"] = Engine.time_scale
			if _seit() > 1.6:
				_punkt7_besiegt()
				_weiter()
		14:
			if _seit() > 3.5:
				_punkt7_weiter()
				_weiter()
		15:
			if _seit() > 1.5:
				_punkt7_zweiter()
				_weiter()
		16:
			if o.herausforderer.zustand == "duell" and _seit() > 1.0:
				_punkt7_brakk_faellt()
				_weiter()
			elif _seit() > 20.0:
				pruefe(false, "zweiter Herausforderer kam nicht")
				return _fertig()
		17:
			if _seit_wand() > 1.5:
				_punkt7_bericht()
				return _fertig()
		_:
			return _fertig()
	return false


# ------------------------------------------------------------------ Punkt 1: wer antritt

func _punkt1() -> void:
	var a := {"beiname": "der Rest", "rang": 2, "bilanz": {"er": 5, "brakk": 0}}
	var b := {"beiname": "Brakkbrecher", "rang": 1, "bilanz": {"er": 1, "brakk": 1}}
	var c := {"beiname": "der Rest", "rang": 3, "bilanz": {"er": 2, "brakk": 0}}
	pruefe(Nemesis.bester_herausforderer([a, b, c]) == c, "bevorzugt (Brakkbrecher oder Rang 3), darunter die beste Bilanz")
	pruefe(Nemesis.bester_herausforderer([a, b]) == b, "Brakkbrecher geht vor der besseren Bilanz")
	pruefe(Nemesis.bester_herausforderer([a, {"beiname": "x", "rang": 1, "bilanz": {"er": 0, "brakk": 3}}]) == a, "sonst die beste Bilanz")
	var alte := n.personen.duplicate()
	var p := n.herausforderer_waehlen()
	pruefe(not p.is_empty() and Nemesis.hat_titel(p, Nemesis.TITEL_HERAUSFORDERER), "gewählt mit Titel: %s" % Nemesis.name_mit_titel(p))
	var rang := int(p["rang"])
	var gewohnt := NemesisGewohnheiten.von_person(p).size()
	var p2 := n.herausforderer_waehlen(p)
	pruefe(p2 == p and int(p["rang"]) == mini(4, rang + 1) and NemesisGewohnheiten.von_person(p).size() == gewohnt + 1, "geborgen: er kommt wieder, Rang %d → %d, eine Angewohnheit mehr" % [rang, int(p["rang"])])
	n.personen.erase(p)
	n.ausgeschaltet.append(p)
	var p3 := n.herausforderer_waehlen(p)
	var traeger := (n.personen + n.ausgeschaltet).filter(func(q: Dictionary) -> bool: return Nemesis.hat_titel(q, Nemesis.TITEL_HERAUSFORDERER))
	pruefe(p3 != p and not p3.is_empty() and traeger.size() == 1 and traeger[0] == p3, "ausgeschaltet: der nächste, und nur er trägt den Titel (%s)" % Nemesis.voller_name(p3))
	n.personen = []
	var e := o._neue_truppe("plasmawerfer", o.fabrik_hp.keys()[0], 2)
	n._lauf_von(e)["schaden"] = 123.0
	var p4 := n.herausforderer_waehlen()
	pruefe(int(p4.get("rang", 0)) == 2 and n.einheit_von(p4) == e, "niemand benannt: die Truppe mit dem meisten Schaden wird Rang 2 (%s)" % Nemesis.voller_name(p4))
	n.personen = alte


# ------------------------------------------------------------------ Punkt 2: Auftritt und Pause

func _punkt2_start() -> void:
	o.tafeln.leeren()
	o.tafeln.protokoll.clear()
	o._jagdwelle()   # ein Jagdtrupp ist unterwegs
	merk["jaeger"] = (o.trupps.back()["mitglieder"] as Array).duplicate()
	o.herausforderer.zeiten = [o.zeit + 11.0, o.zeit + 400.0]
	o.herausforderer.naechste = 0
	merk["auftritt_um"] = o.zeit + 11.0


func _punkt2_ansage() -> void:
	var h := o.herausforderer
	pruefe(h.zustand == "angesagt" and o.phase_text() == "Herausforderung", "10 s vorher angesagt, Phasenzeile „%s“" % o.phase_text())
	pruefe(str(spiel.get("_meldung")).contains("Da kommt einer allein"), "Sonde 7: „Da kommt einer allein. Er will dich.“")
	pruefe(absf(float((h.protokoll[0] as Dictionary)["bei"]) - (float(merk["auftritt_um"]) - 10.0)) < 0.2, "Ansage 10 s vorher")


func _punkt2_auftritt() -> void:
	var h := o.herausforderer
	var a: Dictionary = {}
	for x: Dictionary in h.protokoll:
		if str(x["was"]) == "auftritt":
			a = x
	pruefe(h.zustand == "duell" and h.einheit != null and h.einheit.halt and h.einheit.has_meta("herausforderer"), "er ist da: %s" % str(a.get("name", "–")))
	pruefe(float(a.get("abstand", 0.0)) >= 6.0 and float(a.get("abstand", 99.0)) <= 18.0, "kommt %.1f Felder vor Brakk an (Soll 10–12, sonst weiterer Ring)" % float(a.get("abstand", 0.0)))
	pruefe(_tafeln("herausforderer").size() == 1 and Nemesis.hat_titel(h.person, Nemesis.TITEL_HERAUSFORDERER), "Banner mit Titel")
	var jaeger: Array = (merk["jaeger"] as Array).filter(func(x: Variant) -> bool: return Nemesis.lebt(x) and x != h.einheit and (x as Einheit).zustand == Einheit.Zustand.BODEN)
	pruefe(not jaeger.is_empty() and jaeger.all(func(x: Variant) -> bool: return o.marschziel(x as Einheit) == o._erreichbar_nahe((x as Einheit).fabrik_zelle, o.karte.zelle_bei((x as Einheit).position))), "%d Jäger ziehen sich zu ihren Fabriken zurück" % jaeger.size())
	pruefe(o.haelt_feuer(o.brakk_ziel), "Bodentruppen halten das Feuer")
	merk["plan"] = o.plan_zeit()
	merk["takt"] = o.welle_takt_jetzt()
	o._naechste_welle = o.zeit + 2.0   # eine Welle wäre gleich fällig
	merk["wellen"] = o.wellen


func _punkt2_pause() -> void:
	pruefe(o.wellen == int(merk["wellen"]), "keine neue Welle, solange er steht")
	pruefe(absf(o.plan_zeit() - float(merk["plan"])) < 0.1 and o.plan_pause > 4.0, "Fahrplan steht (%.1f s), Überlebens-Uhr läuft weiter (%.1f s)" % [o.plan_zeit(), o.zeit])
	o.herausforderer.seit = Werte.HERAUSFORDERER_PAUSE_MAX - 0.5   # kurz vor 90 s
	merk["plan"] = o.plan_zeit()


func _punkt2_ende() -> void:
	var h := o.herausforderer
	pruefe(h.zustand == "duell" and not h.sperrt() and not o.haelt_feuer(o.brakk_ziel), "nach 90 s kommen die Jagdtrupps zurück, er bleibt")
	pruefe(o.plan_zeit() - float(merk["plan"]) > 1.0, "der Fahrplan läuft weiter")


# ------------------------------------------------------------------ Punkt 3: Leben, Schaden, Tempo

func _punkt3() -> void:
	var h := o.herausforderer
	var k: Kommandant = spiel.kommandant
	var e := h.einheit
	pruefe(absf(e.max_leben - Werte.HERAUSFORDERER_LEBEN_MAL * k.max_leben) < 0.5, "Leben 6 × Brakks Maximum (%.0f bei %.0f)" % [e.max_leben, k.max_leben])
	pruefe(absf(h.tempo() - 3.15) < 0.001, "Tempo %.2f Felder je Sekunde (Brakk 3,0 × 1,05)" % h.tempo())
	merk["heilen"] = false
	k.leben = k.max_leben
	k.unverwundbar = 0.0
	if k.fortschritt != null:
		k.fortschritt.ringe.clear()
	var treffer := 0
	var erster := 0.0
	# auch beim Sabotieren und nah am HQ bleibt jeder Treffer gleich
	o.sabo = {"t": 0.0, "zelle": o.fabrik_hp.keys()[0]}
	while treffer < 5 and k.leben > 0.0:
		var vor := k.leben
		spiel.brakk_geschosse._treffe_brakk(h.schaden(), "herausforderer", h.quelle(), e.position, false)
		treffer += 1
		if treffer == 1:
			erster = vor - k.leben
	o.sabo = {}
	pruefe(absf(erster - Werte.HERAUSFORDERER_TREFFER_ANTEIL * k.max_leben) < 0.6, "ein Treffer nimmt %.0f von %.0f (18,2 %%), auch beim Sabotieren" % [erster, k.max_leben])
	pruefe(k.leben > 0.0 and k.leben < k.max_leben * 0.12, "nach 5 Treffern lebt Brakk knapp (%.0f) – der 6. fällt ihn" % k.leben)
	k.leben = k.max_leben
	merk["heilen"] = true
	var ziel: Gegner = null
	o._ziele_pflegen()
	for g: Variant in o._ziele.values():
		if (g as Order24.TechnoZiel).einheit == e:
			ziel = g
	pruefe(ziel != null and o.ist_herausforderer_ziel(ziel), "der Ladestrahl behandelt ihn wie einen großen Gegner (5 %)")


# ------------------------------------------------------------------ Punkt 4: er spielt wie Brakk

func _punkt4_start() -> void:
	var l := n.lernen
	l.treffer_abstaende = [6.0, 5.0, 6.0, 7.0, 6.0, 6.0, 9.0]
	l.bewegungen = {"sprung": 0, "tumble": 0, "links": 0, "rechts": 0, "zurueck": 0, "vor": 0}
	for i in 6:
		l.bewegung("tumble", Vector2(-1, 0))
	l.bewegung("tumble", Vector2(1, 0))
	for i in 3:
		l.bewegung("sprung")
	var w := l.kennwerte()
	pruefe(absf(float(w["abstand"]) - 6.0) < 0.01 and str(w["seite"]) == "links" and str(w["selten"]) == "rechts", "Kennwerte: 6 Felder, weicht nach links, selten rechts (%s)" % str(w))
	var h := o.herausforderer
	h.kennwerte = w
	h.kennwerte["takt"] = 2.0
	h.kennwerte["wall"] = false
	h.zaehler = {"sprung": 0, "tumble": 0, "ausweichen": 0, "wall": 0}
	h._aktion_in = 1.0
	h.angriff = {}
	h._bis_angriff = 999.0
	h._vergeltung_in = 999.0
	h.person["duell"] = {"abstand": 6.0, "je_min": 8.0, "seite": "links", "wall": false}
	var k: Kommandant = spiel.kommandant
	var mitte := _freie_flaeche()
	k.position = o.karte.mitte(mitte)
	k.oben = false
	h.einheit.position = o.karte.mitte(mitte + Vector2i(10, 0))
	h._weg.clear()
	merk["brakk"] = k.position
	merk["start"] = h.einheit.position.distance_to(k.position) / Werte.ZELLE


## Eine freie Fläche für die Bewegungs- und Kampfprüfungen: Wälle im Rechteck abtragen (nur in diesem Testlauf). Die
## Karte ist je Lauf anders – findet sich kein großes Rechteck ohne Gebäude, genügt ein schmaleres.
func _freie_flaeche() -> Vector2i:
	var karte: Karte = o.karte
	for halb: int in [4, 3, 2]:
		for y in range(0, 60):
			for x in range(0, 90):
				var c := Vector2i(x, y)
				var ok := true
				for dy in range(-halb, halb + 1):
					for dx in range(-3, 13):
						var z := c + Vector2i(dx, dy)
						if not karte.in_karte(z) or not (karte.inhalt(z) == Karte.WALL or (karte.ist_frei(z) and karte.ist_begehbar(z))):
							ok = false
							break
					if not ok:
						break
				if not ok:
					continue
				for dy in range(-halb, halb + 1):
					for dx in range(-3, 13):
						var z := c + Vector2i(dx, dy)
						if karte.inhalt(z) == Karte.WALL:
							karte.fest.erase(z)
							karte.entferne(z)
				print("     Prüffläche um %s (Breite %d)" % [str(c), 2 * halb + 1])
				return c
	pruefe(false, "keine freie Prüffläche auf dieser Karte")
	return Vector2i(5, 5)


func _punkt4_ende() -> void:
	spiel.kommandant.position = merk["brakk"]
	var h := o.herausforderer
	var k: Kommandant = spiel.kommandant
	var d := h.einheit.position.distance_to(k.position) / Werte.ZELLE
	pruefe(d > 2.5 and d < 10.0 and o.karte.sicht_frei(h.einheit.position, k.position), "hält etwa den Lieblingsabstand mit Sicht: %.1f Felder (vorher %.1f, Soll 6)" % [d, float(merk["start"])])
	pruefe(int(h.zaehler["sprung"]) + int(h.zaehler["tumble"]) >= 2, "springt und tumbelt (%d Sprünge, %d Tumble in 9 s)" % [int(h.zaehler["sprung"]), int(h.zaehler["tumble"])])
	# Ladestrahl: Brakk lädt und zielt auf ihn
	h._aktion = {}
	h.angriff = {}
	h._bis_angriff = 999.0
	h._wall_rest = 0.0
	h.einheit.zustand = Einheit.Zustand.BODEN
	h._ausweich_rest = 0.0
	var zu := (h.einheit.position - k.position).normalized()
	spiel.ego.gier = atan2(-zu.x, -zu.y)
	spiel.ego._lanze = 0.5
	var vorher := h.einheit.position
	h.schritt(0.02)
	var ziel: Vector2 = h._aktion.get("nach", vorher)
	var rechts := Vector2(zu.y, -zu.x)   # seine rechte Seite (er schaut zu Brakk)
	pruefe(int(h.zaehler["ausweichen"]) == 1 and str(h._aktion.get("art", "")) == "tumble", "weicht dem Ladestrahl mit einem Tumble aus")
	print("     Ausweichrichtung: %.2f (positiv = seine rechte Seite)" % (ziel - vorher).normalized().dot(rechts))
	pruefe(ziel.distance_to(vorher) > Werte.ZELLE * 0.9, "… ein ganzes Stück zur Seite")
	spiel.ego._lanze = -1.0
	var zeilen := {}
	for z: Array in Hangar.karten_zeilen(h.person):
		zeilen[z[0]] = z[1]
	pruefe(str(zeilen.get("Spielt wie du", "")).contains("6 Felder") and str(zeilen.get("Spielt wie du", "")).contains("nach links"), "Karte: %s" % str(zeilen.get("Spielt wie du", "")))


# ------------------------------------------------------------------ Punkt 5: die drei Angriffe

func _punkt5_start() -> void:
	var letzte: Array = []
	var dreimal := 0
	var kommt := {}
	for i in 3000:
		var a := NemesisHerausforderer.waehle_angriff(randf_range(1.0, 13.0), letzte)
		if letzte.size() >= 2 and letzte[-1] == a and letzte[-2] == a:
			dreimal += 1
		letzte.append(a)
		kommt[a] = true
	pruefe(dreimal == 0 and kommt.size() == 3, "3000 Wahlen: alle drei Angriffe, nie derselbe dreimal in Folge")
	var bg: BrakkGeschosse = spiel.brakk_geschosse
	for art: String in ["hf_salve", "hf_kugel"]:
		var flug := 8.0 / (float((Werte.BRAKK_GESCHOSS[art] as Dictionary)["tempo"]) * bg._tempo_mal(art) * Werte.SPIELTEMPO)   # echte Sekunden
		pruefe(flug >= 0.9, "%s: aus 8 Feldern %.2f s unterwegs" % [art, flug])
	pruefe(minf(Werte.HERAUSFORDERER_SALVE_ANSAGE, minf(Werte.HERAUSFORDERER_KUGEL_ANSAGE, Werte.HERAUSFORDERER_STURM_ANSAGE)) >= 0.5, "jede Ankündigung mindestens 0,5 s")
	var h := o.herausforderer
	var k: Kommandant = spiel.kommandant
	k.position = merk["brakk"]
	h.einheit.zustand = Einheit.Zustand.BODEN
	h.einheit.position = k.position + Vector2(8.0 * Werte.ZELLE, 0.0)
	h.einheit.leben = h.einheit.max_leben
	h.kennwerte["takt"] = 6.0
	h.kennwerte["wall"] = false
	h.angriff = {}
	h._aktion = {}
	h._wall_rest = 0.0
	h._vergeltung_in = 999.0   # Punkt 5 prüft nur die drei eigenen Angriffe
	h._bis_angriff = 0.5
	h.protokoll.clear()
	h.seit = 0.0   # die Trupps bleiben weg – gezählt werden ohnehin nur seine Treffer
	merk["treffer"] = _sein_schaden()
	merk["je_angriff"] = []
	merk["schaden0"] = _sein_schaden()
	merk["zahl"] = 0


## Brakk steht still und wird jedes Bild geheilt; gezählt wird, wie oft er je Angriff getroffen wird.
func _punkt5_laeuft() -> void:
	var h := o.herausforderer
	var k: Kommandant = spiel.kommandant
	k.position = merk["brakk"]
	k.unverwundbar = 0.0
	if not bool(merk.get("klein", false)):
		h.einheit.leben = h.einheit.max_leben   # in der ersten Hälfte bleibt er über 50 %
	var zahl := h.protokoll.filter(func(x: Dictionary) -> bool: return str(x["was"]) == "fenster_ende").size()
	if zahl > int(merk["zahl"]):
		(merk["je_angriff"] as Array).append(roundi((_sein_schaden() - float(merk["treffer"])) / h.schaden()))
		merk["treffer"] = _sein_schaden()
		merk["zahl"] = zahl


## Was seine Treffer Brakk bisher genommen haben.
func _sein_schaden() -> float:
	var s := 0.0
	for q: String in o.schaden_an_brakk:
		if q.begins_with("herausforderer"):
			s += float(o.schaden_an_brakk[q])
	return s

func _angriffe() -> Array:
	return o.herausforderer.protokoll.filter(func(x: Dictionary) -> bool: return str(x["was"]) == "angriff")


func _punkt5_wut() -> void:
	var a := _angriffe()
	var arten := PackedStringArray(a.map(func(x: Dictionary) -> String: return str(x["art"])))
	pruefe(a.size() >= 5, "%d Angriffe in 30 s: %s" % [a.size(), ", ".join(arten)])
	var ansagen := a.map(func(x: Dictionary) -> float: return float(x["angesagt"]))
	pruefe(not ansagen.is_empty() and ansagen.min() >= 0.5, "gemessene Ankündigungen: %.2f bis %.2f s" % [ansagen.min() if not ansagen.is_empty() else 0.0, ansagen.max() if not ansagen.is_empty() else 0.0])
	var fenster := a.map(func(x: Dictionary) -> float: return float(x["fenster"]))
	var gemessen := o.herausforderer.protokoll.filter(func(x: Dictionary) -> bool: return str(x["was"]) == "fenster_ende").map(func(x: Dictionary) -> float: return float(x["dauer"]))
	print("     Fenster-Zeiten (s): %s" % ", ".join(PackedStringArray(gemessen.map(func(v: float) -> String: return "%.2f" % v))))
	pruefe(not fenster.is_empty() and fenster.min() >= 1.0 and fenster.max() <= 1.5 and not gemessen.is_empty() and gemessen.min() >= 0.99 and gemessen.max() <= 1.55, "Fenster 1,0–1,5 s")
	pruefe(not o.herausforderer.wut, "noch nicht unter halbem Leben")
	merk["vorher"] = a.size()
	merk["klein"] = true
	o.herausforderer.einheit.leben = o.herausforderer.einheit.max_leben * 0.4


func _punkt5_ende() -> void:
	var h := o.herausforderer
	var a := _angriffe()
	var spaet := a.slice(int(merk["vorher"]) + 1)   # der laufende Angriff beim Wechsel zählt nicht
	var fenster := spaet.map(func(x: Dictionary) -> float: return float(x["fenster"]))
	pruefe(h.wut and not fenster.is_empty() and fenster.max() <= 1.5 * 0.7 + 0.001 and fenster.min() >= 0.7 - 0.001, "ab 50 %% kürzere Fenster (%.2f bis %.2f s)" % [fenster.min() if not fenster.is_empty() else 0.0, fenster.max() if not fenster.is_empty() else 0.0])
	var arten: Array = a.map(func(x: Dictionary) -> String: return str(x["art"]))
	var dreimal := false
	for i in range(2, arten.size()):
		dreimal = dreimal or (arten[i] == arten[i - 1] and arten[i] == arten[i - 2])
	pruefe(not dreimal, "im Duell nie derselbe dreimal")
	var treffer := roundi((_sein_schaden() - float(merk["schaden0"])) / h.schaden())
	pruefe(treffer >= a.size() / 2 and treffer <= a.size(), "höchstens ein Treffer je Angriff: %d Treffer bei %d Angriffen auf den Stehenden" % [treffer, a.size()])
	_salve_nah()


## Aus nächster Nähe liegen alle drei Bahnen auf Brakk – trotzdem zählt nur ein Treffer.
func _salve_nah() -> void:
	var h := o.herausforderer
	var k: Kommandant = spiel.kommandant
	var bg: BrakkGeschosse = spiel.brakk_geschosse
	bg.leeren()
	k.unverwundbar = 0.0
	k.position = h.einheit.position + Vector2(0.8 * Werte.ZELLE, 0.0)
	var vorher := _sein_schaden()
	h._feuere_salve(Vector2.RIGHT, 0.8 * Werte.ZELLE)
	for i in 60:
		bg.weiter(1.0 / 60.0)
	var treffer := roundi((_sein_schaden() - vorher) / h.schaden())
	pruefe(treffer == 1, "Salve aus 0,8 Feldern: %d Treffer" % treffer)


# ------------------------------------------------------------------ Punkt 7: das Ende

func _punkt7_niederlage_vorbereiten() -> void:
	var h := o.herausforderer
	o.tafeln.leeren()
	o.tafeln.protokoll.clear()
	o.beute_boden.clear()
	var k: Kommandant = spiel.kommandant
	k.fortschritt.ringe.clear()
	k.fortschritt.ring_stufen.clear()
	h.seit = 5.0
	merk["er"] = h.einheit
	merk["person"] = h.person
	merk["tempo_vorher"] = Engine.time_scale
	merk.erase("tempo7")
	h.einheit.nimm_schaden(9999999.0)


func _punkt7_besiegt() -> void:
	var h := o.herausforderer
	pruefe(h.zustand == "ruhe" and not h.ergebnisse.is_empty() and str((h.ergebnisse.back() as Array)[1]) == "vertrieben", "Herausforderer vertrieben")
	pruefe(float(merk.get("tempo7", 9.0)) < float(merk["tempo_vorher"]) * 0.6 and absf(Engine.time_scale - float(merk["tempo_vorher"])) < 0.01, "Zeitlupe beim Ende (%.2f), danach wieder %.2f" % [float(merk.get("tempo7", 9.0)), Engine.time_scale])
	var t := _tafeln("herausforderer")
	pruefe(not t.is_empty() and str(t.back()["titel"]) == "Herausforderer vertrieben" and _tafeln("vertrieben").is_empty(), "Banner „Herausforderer vertrieben“ (keine zweite Tafel)")
	var b: Dictionary = o.beute_boden[0] if not o.beute_boden.is_empty() else {}
	pruefe(o.beute_boden.size() == 1 and str(b.get("ring", "")) != "" and not bool(b.get("stufe", true)), "ein Ring einer neuen Art fällt sofort: %s" % str(b.get("ring", "–")))
	var k: Kommandant = spiel.kommandant
	if not b.is_empty():
		var vorher: int = spiel.budget
		k.position = b["pos"]
		o._beute_pflegen(k)
		pruefe(k.fortschritt.ring_stufe(str(b["ring"])) == 1 and o.beute_boden.is_empty(), "aufgehoben: neuer Ring, Stufe 1")
		k.fortschritt.verkaufe(str(b["ring"]), spiel)
		pruefe(spiel.budget == vorher, "kein Gold beim Verkaufen (%d → %d)" % [vorher, spiel.budget])
	# alle fünf Finger belegt: dann ist es eine Stufe
	var f := k.fortschritt
	f.ringe.clear()
	f.ring_stufen.clear()
	for r: String in BrakkFortschritt.RINGE.keys().slice(0, 5):
		f.ringe.append(r)
		f.ring_stufen[r] = 1
	o.beute_legen_herausforderer((merk["brakk"] as Vector2) + Vector2(3.0 * Werte.ZELLE, 0))
	var s: Dictionary = o.beute_boden.back()
	pruefe(bool(s["stufe"]) and f.ringe.has(str(s["ring"])), "5 Ringe an 5 Fingern: eine Stufe für %s" % str(s["ring"]))
	k.position = s["pos"]
	o._beute_pflegen(k)
	pruefe(f.ring_stufe(str(s["ring"])) == 2 and f.ringe.size() == 5, "aufgehoben: jetzt Stufe 2")
	merk["plan"] = o.plan_zeit()
	merk["wellen"] = o.wellen
	merk["rest"] = o._naechste_welle - o.zeit
	o._naechste_welle = o.zeit + 2.0


func _punkt7_weiter() -> void:
	pruefe(o.wellen == int(merk["wellen"]) + 1 and o.plan_zeit() - float(merk["plan"]) > 3.0, "danach kommen wieder Wellen, der Fahrplan läuft")
	var h := o.herausforderer
	h.zeiten = [0.0, o.zeit + 11.0]
	h.naechste = 1
	o._naechste_welle = o.zeit + 500.0


func _punkt7_zweiter() -> void:
	merk["rang"] = int((merk["person"] as Dictionary)["rang"])


func _punkt7_brakk_faellt() -> void:
	var h := o.herausforderer
	var p: Dictionary = merk["person"]
	pruefe(h.person == p and int(p["rang"]) == mini(4, int(merk["rang"]) + 1), "der Geborgene kommt wieder, Rang %d → %d" % [int(merk["rang"]), int(p["rang"])])
	merk["rang"] = int(p["rang"])
	merk["ende_erwartet"] = true
	merk["heilen"] = false
	var k: Kommandant = spiel.kommandant
	k.unverwundbar = 0.0
	k.fortschritt.ringe.clear()
	k.leben = 1.0
	spiel.brakk_geschosse._treffe_brakk(h.schaden(), "herausforderer", h.quelle(), h.einheit.position, false)


func _punkt7_bericht() -> void:
	var h := o.herausforderer
	var p: Dictionary = merk["person"]
	var chronik := str((p["chronik"] as Array).map(func(c: Variant) -> String: return str((c as Dictionary).get("text", ""))))
	pruefe(o.vorbei and str((h.ergebnisse.back() as Array)[1]) == "gesiegt" and chronik.contains("hat Brakk im Duell geschlagen"), "Brakk fällt: er hat gesiegt, steht so in der Chronik")
	var tod := n.tod_bericht()
	pruefe(bool(tod.get("duell", false)) and str(tod.get("name", "")).contains(str(p["name"])), "Deathscreen: im Duell erledigt von %s" % str(tod.get("name", "–")))
	var b := o.bericht(false)
	var z := BrakkSieg.herausforderer_zeilen(b.get("herausforderer", []))
	pruefe(z.size() == 2 and str(z[0][1]) == "vertrieben" and str(z[1][1]) == "hat gesiegt", "Bericht: %s" % " | ".join(PackedStringArray(z.map(func(x: Array) -> String: return "Herausforderer: %s – %s" % [str(x[0]), str(x[1])]))))
	var leer := BrakkSieg.herausforderer_zeilen([])
	pruefe(leer.size() == 1 and str(leer[0][1]) == "nicht gestellt", "ohne Duell: „nicht gestellt“")
	# Hangar: der Träger des Titels steht auf dem Podest, auch wenn ein anderer die bessere Bilanz hat
	var a := {"rang": 1, "bilanz": {"er": 9, "brakk": 0}, "titel": []}
	var c := {"rang": 1, "bilanz": {"er": 0, "brakk": 3}, "titel": [Nemesis.TITEL_HERAUSFORDERER]}
	pruefe(Hangar.herausforderer([a, c]) == c and Hangar.herausforderer([a]) == a, "Hangar: der Herausforderer führt aufs Podest")


# ------------------------------------------------------------------ mit den echten Zeitpunkten (-- zeiten)

func _eintrag(was: String, nr: int) -> Dictionary:
	var l := o.herausforderer.protokoll.filter(func(x: Dictionary) -> bool: return str(x["was"]) == was)
	return l[nr] if nr < l.size() else {}


func _schritte_echt() -> bool:
	var h := o.herausforderer
	match schritt:
		0:
			if o.zeit > 2.0:
				pruefe(h.zeiten == Werte.HERAUSFORDERER_ZEITEN and h.zeiten == [540.0, 840.0], "er tritt bei 9:00 und 14:00 an")
				o.zeit = 527.0
				o._naechste_welle = 600.0
				_weiter()
		1:
			if h.zustand == "duell":
				pruefe(absf(float(_eintrag("ansage", 0)["bei"]) - 530.0) < 0.2 and absf(float(_eintrag("auftritt", 0)["bei"]) - 540.0) < 0.2, "Ansage %.1f s, Auftritt %.1f s" % [float(_eintrag("ansage", 0)["bei"]), float(_eintrag("auftritt", 0)["bei"])])
				merk["p"] = h.person
				merk["rang"] = int(h.person["rang"])
				merk["wellen"] = o.wellen
				o._naechste_welle = o.zeit + 2.0
				_weiter()
			elif _seit() > 30.0:
				pruefe(false, "bei 540 s kam niemand")
				return _fertig()
		2:
			if _seit() > 12.0:
				pruefe(o.wellen == int(merk["wellen"]) and o.plan_pause > 11.0, "12 s Duell ohne Welle, der Fahrplan stand %.1f s" % o.plan_pause)
				h.einheit.nimm_schaden(9999999.0)
				_weiter()
		3:
			if _seit() > 4.0:
				pruefe(h.zustand == "ruhe" and o.beute_boden.size() >= 1 and o.wellen > int(merk["wellen"]), "vertrieben: Ring liegt, die Wellen laufen wieder")
				o.zeit = 827.0
				_weiter()
		4:
			if h.zustand == "duell":
				pruefe(absf(float(_eintrag("ansage", 1)["bei"]) - 830.0) < 0.2 and absf(float(_eintrag("auftritt", 1)["bei"]) - 840.0) < 0.2, "zweites Mal: Ansage %.1f s, Auftritt %.1f s" % [float(_eintrag("ansage", 1)["bei"]), float(_eintrag("auftritt", 1)["bei"])])
				pruefe(h.person == merk["p"] and int(h.person["rang"]) == mini(4, int(merk["rang"]) + 1), "der Geborgene kommt wieder, Rang %d → %d" % [int(merk["rang"]), int(h.person["rang"])])
				_weiter()
			elif _seit() > 30.0:
				pruefe(false, "bei 840 s kam niemand")
				return _fertig()
		_:
			return _fertig()
	return false

# ------------------------------------------------------------------ Punkt 6: Vergeltung

## Brakk auf seinem Platz, der Herausforderer `abstand` Felder daneben, nichts läuft.
func _stelle(abstand: float) -> void:
	var h := o.herausforderer
	var k: Kommandant = spiel.kommandant
	(spiel.brakk_geschosse as BrakkGeschosse).leeren()
	(spiel.brakk_geschosse as BrakkGeschosse).spaeter_liste.clear()
	k.position = merk["brakk"]
	k.unverwundbar = 0.0
	k.oben = false
	h.einheit.zustand = Einheit.Zustand.BODEN
	h.einheit.position = k.position + Vector2(abstand * Werte.ZELLE, 0.0)
	h.angriff = {}
	# der Technoclan baut abgeräumte Wälle nach: die Schusslinie vor jeder Messung frei machen und prüfen
	var von := o.karte.zelle_bei(k.position)
	var nachgebaut := 0
	for dy in range(-3, 4):
		for dx in range(-2, 10):
			var z := von + Vector2i(dx, dy)
			if o.karte.in_karte(z) and o.karte.inhalt(z) == Karte.WALL:
				nachgebaut += 1
				o.karte.fest.erase(z)
				o.karte.entferne(z)
	if nachgebaut > 0:
		print("     %d nachgebaute Wälle in der Prüffläche abgetragen" % nachgebaut)
	h._aktion = {}
	h._wall_rest = 0.0
	h._bis_angriff = 999.0
	h._vergeltung_in = 999.0
	h.seit = 0.0


## Führt einen Angriff Bild für Bild aus. `weg` verschiebt Brakk nach `nach_sek` (Ausweichen). Gibt zurück, wie viele
## Treffer (als Vielfaches eines vollen Treffers) bei Brakk ankamen.
func _angriff_ausfuehren(art: String, sek: float, weg: Vector2 = Vector2.ZERO, nach_sek: float = 99.0) -> float:
	var h := o.herausforderer
	var k: Kommandant = spiel.kommandant
	var bg: BrakkGeschosse = spiel.brakk_geschosse
	var vorher := _sein_schaden()
	h.beginne_angriff(art)
	merk["braende"] = 0.0
	var gegangen := false
	for i in int(sek * 60.0):
		if not gegangen and i / 60.0 >= nach_sek:
			gegangen = true
			k.position += weg
		k.leben = k.max_leben
		k.unverwundbar = 0.0
		h._vergeltung_in = 999.0
		h.schritt(1.0 / 60.0)
		bg.weiter(Werte.SPIELTEMPO / 60.0)
		for br: Dictionary in bg.braende:
			merk["braende"] = maxf(float(merk["braende"]), float(br["rest"]))
	return (_sein_schaden() - vorher) / h.schaden()


func _ring_an(ring: String) -> void:
	var h := o.herausforderer
	h.vergeltung_aus()
	h.vergeltung_an({"art": "ring", "ring": ring, "name": str((BrakkFortschritt.RINGE[ring] as Dictionary)["name"])})


func _letzte_ansage(was: String = "angriff") -> float:
	var l := o.herausforderer.protokoll.filter(func(x: Dictionary) -> bool: return str(x["was"]) == was)
	return float(l.back()["angesagt"]) if not l.is_empty() else 0.0


func _punkt6_wahl_und_waffen() -> void:
	var W := func(q: Dictionary, z: Dictionary) -> String:
		var w := NemesisHerausforderer.waehle_vergeltung(q, z)
		return str(w["art"]) + ("" if str(w["ring"]) == "" else ":" + str(w["ring"]))
	pruefe(W.call({"pistole": 5000.0}, {}) == "pistole", "nur Pistolen genutzt: Pistolen")
	pruefe(W.call({"pistole": 5000.0, "lanze": 300.0, "saeule": 200.0}, {}) == "lanze" and W.call({"pistole": 5000.0, "lanze": 100.0, "saeule": 200.0}, {}) == "saeule", "Ladestrahl und Lichtsäule gehen vor, nach Schaden")
	pruefe(W.call({"pistole": 9000.0, "ring": 900.0, "lanze": 300.0}, {"aktiv_brandfeld": 50.0, "aktiv_laser": 20.0}) == "ring:brandfeld", "Ring vorn: der am längsten aktive")
	pruefe(W.call({"pistole": 9000.0}, {"aktiv_bollwerk": 12.0}) == "ring:bollwerk", "ein Ring ohne eigenen Schaden zählt vor den Pistolen")
	pruefe(W.call({"ring": 900.0, "lanze": 300.0}, {}) == "lanze", "ohne aktive Ringzeit kein Ring")
	var h := o.herausforderer
	h.vergeltung = {"art": "lanze", "ring": "", "name": "Ladestrahl", "rest": 99.0}
	var vorher := h._letzte.duplicate()
	h._letzte.clear()
	var dreimal := false
	var strahlen := 0
	for i in 300:
		var a := h.naechster_angriff(6.0)
		var l: Array = h._letzte
		dreimal = dreimal or (l.size() >= 2 and l[-1] == a and l[-2] == a)
		strahlen += 1 if a == "strahl" else 0
		h._letzte.append(a)
	h._letzte = vorher
	h.vergeltung = {}
	pruefe(not dreimal and strahlen > 150, "mit kopierter Waffe meist sie (%d von 300), nie dreimal in Folge" % strahlen)
	# die drei Waffen: stehend getroffen, mit Ausweichen verfehlt
	var Z := Werte.ZELLE
	_stelle(6.0)
	var t := _angriff_ausfuehren("strahl", 2.2)
	pruefe(absf(t - 1.0) < 0.05 and _letzte_ansage() >= 0.5, "Ladestrahl: stehend %.2f Treffer, Ziellinie %.2f s" % [t, _letzte_ansage()])
	_stelle(6.0)
	t = _angriff_ausfuehren("strahl", 2.2, Vector2(0, 1.2 * Z), 0.4)
	pruefe(t < 0.01, "Ladestrahl: ein Schritt aus der Linie – %.2f Treffer" % t)
	_stelle(6.0)
	t = _angriff_ausfuehren("saeule", 2.8)
	pruefe(absf(t - 1.0) < 0.05 and _letzte_ansage() >= 1.45, "Lichtsäule: stehend %.2f Treffer, Vorschau %.2f s wie bei Brakk" % [t, _letzte_ansage()])
	_stelle(6.0)
	h.beginne_angriff("saeule")
	var warnt := h.saeule_ueber_brakk()
	(spiel.kommandant as Kommandant).position += Vector2(0, 2.2 * Z)
	pruefe(warnt and not h.saeule_ueber_brakk(), "Warnzeile nur, solange Brakk im Kreis steht")
	h.angriff = {}
	h._marke_weg()
	_stelle(6.0)
	t = _angriff_ausfuehren("saeule", 2.8, Vector2(0, 2.2 * Z), 0.7)
	pruefe(t < 0.01, "Lichtsäule: aus dem Kreis – %.2f Treffer" % t)
	_stelle(6.0)
	t = _angriff_ausfuehren("doppel", 3.4)
	pruefe(absf(t - 1.0) < 0.05 and _letzte_ansage() >= 0.5, "Doppelschüsse: stehend zusammen %.2f Treffer, angekündigt %.2f s" % [t, _letzte_ansage()])


func _punkt6_ringe() -> void:
	var h := o.herausforderer
	var k: Kommandant = spiel.kommandant
	var Z := Werte.ZELLE
	# Durchschlagring: eine Mauer zwischen beiden
	var wall := Vector2i(-1, -1)
	for y in range(1, 40):
		for x in range(2, 60):
			var c := Vector2i(x, y)
			if wall.x < 0 and o.karte.in_karte(c) and o.karte.inhalt(c) == Karte.WALL:
				var frei := true
				for dx: int in [-2, -1, 1, 2]:
					var n_ := c + Vector2i(dx, 0)
					frei = frei and o.karte.in_karte(n_) and o.karte.ist_frei(n_)
				if frei:
					wall = c
	var ohne := -1.0
	var mit := -1.0
	if wall.x >= 0:
		for lauf: int in 2:
			_stelle(4.0)
			h.vergeltung_aus()
			if lauf == 1:
				_ring_an("durchschuss")
			h._vergeltung_in = 999.0
			k.position = o.karte.mitte(wall + Vector2i(2, 0))
			h.einheit.position = o.karte.mitte(wall - Vector2i(2, 0))
			var t := _angriff_ausfuehren("salve", 2.4)
			if lauf == 0:
				ohne = t
			else:
				mit = t
	pruefe(wall.x >= 0 and ohne < 0.01 and absf(mit - 1.0) < 0.05, "Mauer: normale Salve %.2f Treffer, mit Durchschlagring %.2f" % [ohne, mit])
	_ring_an("laser")
	h.marke_rest = 0.0
	pruefe(absf(h.treffer_mal(h.schaden()) - 1.3) < 0.001, "Glutstrahlring: Treffer 30 % stärker")
	pruefe(ceili(1.0 / (Werte.HERAUSFORDERER_TREFFER_ANTEIL * 1.3) - 0.0001) == 5 and ceili(1.0 / Werte.HERAUSFORDERER_TREFFER_ANTEIL - 0.0001) == 6, "… dann fällt Brakk beim 5. statt beim 6.")
	_ring_an("markierung")
	h.marke_rest = 0.0
	var erster := h.treffer_mal(h.schaden())
	var zweiter := h.treffer_mal(h.schaden())
	pruefe(absf(erster - 1.0) < 0.001 and absf(zweiter - 1.25) < 0.001 and h.marke_rest > 2.9, "Zielring: erst markiert (×%.2f), der nächste ×%.2f" % [erster, zweiter])
	pruefe(absf(h.treffer_mal(h.schaden() * 0.01) - 1.0) < 0.001, "Brand-Ticks zählen nicht als Treffer")
	h.marke_rest = 0.0
	_stelle(6.0)
	_ring_an("feuerteam")
	h._vergeltung_in = 999.0
	_angriff_ausfuehren("salve", 3.0)
	var fenster := float(o.herausforderer.protokoll.filter(func(x: Dictionary) -> bool: return str(x["was"]) == "angriff").back()["fenster"])
	var voll := Werte.HERAUSFORDERER_FENSTER.y * (Werte.HERAUSFORDERER_WUT_FENSTER if h.wut else 1.0)
	pruefe(fenster <= voll * 0.7 + 0.001, "Taktring: Fenster nur %.2f s (sonst bis %.2f)" % [fenster, voll])
	_stelle(6.0)
	_ring_an("minigun")
	h._vergeltung_in = 999.0
	var zahl := o.herausforderer.protokoll.filter(func(x: Dictionary) -> bool: return str(x["was"]) == "doppelsalve").size()
	var t2 := _angriff_ausfuehren("salve", 4.0)
	var neu := o.herausforderer.protokoll.filter(func(x: Dictionary) -> bool: return str(x["was"]) == "doppelsalve").size() - zahl
	pruefe(neu == 1 and t2 > 1.5 and _letzte_ansage("doppelsalve") >= 0.5 and _letzte_ansage() >= 0.5, "Wirbelring: zwei Salven (%.2f Treffer), beide angekündigt (%.2f / %.2f s)" % [t2, _letzte_ansage("doppelsalve"), _letzte_ansage()])
	h.vergeltung_aus()
	o._ziele_pflegen()
	var ziel: Gegner = null
	for g: Variant in o._ziele.values():
		if (g as Order24.TechnoZiel).einheit == h.einheit:
			ziel = g
	# im Vergleich ohne und mit Ring (ein Frontschild nähme sonst zusätzlich etwas weg)
	var ab := [0.0, 0.0]
	for lauf: int in 2:
		if lauf == 1:
			_ring_an("bollwerk")
		var lp := h.einheit.leben
		if ziel != null:
			o.treffer(ziel as Order24.TechnoZiel, 100.0)
		ab[lauf] = lp - h.einheit.leben
	pruefe(ziel != null and float(ab[0]) > 0.0 and absf(float(ab[1]) / maxf(0.001, float(ab[0])) - 0.8) < 0.01, "Wallring: er nimmt %.0f statt %.0f Schaden" % [float(ab[1]), float(ab[0])])
	_stelle(6.0)
	_ring_an("brandfeld")
	h._vergeltung_in = 999.0
	_angriff_ausfuehren("kugel", 4.5, Vector2(0, 3.0 * Z), 0.5)
	pruefe(float(merk["braende"]) > 1.8, "Brandring: die Kugel hinterlässt Feuer (%.2f)" % float(merk["braende"]))
	_stelle(6.0)
	h.vergeltung_aus()
	_angriff_ausfuehren("kugel", 4.5, Vector2(0, 3.0 * Z), 0.5)
	pruefe(float(merk["braende"]) < 0.01, "… ohne Brandring nicht")
	_stelle(6.0)
	_ring_an("plasmagel")
	h._vergeltung_in = 999.0
	h.gel_rest = 0.0
	_angriff_ausfuehren("salve", 2.2)   # aus 6 Feldern rund 1,7 s bis zum Treffer
	var gebremst := o.brakk_tempo_faktor()
	var rest := h.gel_rest
	for i in 120:
		h._vergeltung_in = 999.0
		h.schritt(1.0 / 60.0)
	pruefe(rest > 0.0 and gebremst <= 0.56 and o.brakk_tempo_faktor() > 0.99, "Gelring: gebremst auf %.2f, danach wieder %.2f" % [gebremst, o.brakk_tempo_faktor()])
	h.vergeltung_aus()
	# Sprungring: das zweite Platzen kommt erst im nächsten Bild – darum läuft diese Prüfung über echte Bilder
	_stelle(6.0)
	_ring_an("abpraller")
	h._vergeltung_in = 999.0
	merk["springt"] = h.protokoll.filter(func(x: Dictionary) -> bool: return str(x["was"]) == "kugel_springt").size()
	h.beginne_angriff("kugel")


func _punkt6_takt_start() -> void:
	var h := o.herausforderer
	var l := h.protokoll.filter(func(x: Dictionary) -> bool: return str(x["was"]) == "kugel_springt")
	pruefe(l.size() == int(merk["springt"]) + 1 and float(l.back()["angesagt"]) >= 0.5, "Sprungring: die Kugel springt weiter, zweiter Kreis %.2f s vorher" % (float(l.back()["angesagt"]) if not l.is_empty() else 0.0))
	_stelle(6.0)
	h.vergeltung_aus()
	h.person["vergeltung"] = ""
	var k: Kommandant = spiel.kommandant
	k.fortschritt.schaden_quellen["lanze"] = 500.0
	k.fortschritt.schaden_quellen.erase("saeule")
	k.fortschritt.schaden_quellen.erase("ring")
	pruefe(Hangar.karten_zeilen_alle(h.person).all(func(z: Array) -> bool: return str(z[0]) != "Vergeltung"), "vor der ersten Nutzung steht sie nicht in der Karte")
	h._vergeltung_in = 0.5
	merk["v_ab"] = o.zeit
	o.tafeln.leeren()
	o.tafeln.protokoll.clear()


func _punkt6_takt_an() -> void:
	var h := o.herausforderer
	var t := _tafeln("vergeltung")
	pruefe(str(h.vergeltung.get("name", "")) == "Ladestrahl" and not t.is_empty() and str(t[0]["titel"]) == "Vergeltung: Ladestrahl", "Ansage „Vergeltung: Ladestrahl“")
	pruefe((h.einheit.get_meta("nemesis_umriss") as Color).is_equal_approx(NemesisHerausforderer.VERGELTUNG_UMRISS), "lila Umriss")
	pruefe(Hangar.karten_zeilen_alle(h.person).any(func(z: Array) -> bool: return str(z[0]) == "Vergeltung" and str(z[1]) == "kopiert Ladestrahl"), "ab jetzt in der Karte")


func _punkt6_takt_aus() -> void:
	var h := o.herausforderer
	pruefe(h.vergeltung.is_empty() and not (h.einheit.get_meta("nemesis_umriss") as Color).is_equal_approx(NemesisHerausforderer.VERGELTUNG_UMRISS), "nach 10 s vorbei, Umriss wie vorher")
	var rest := Werte.HERAUSFORDERER_VERGELTUNG_ABKLING - (o.zeit - float(merk["v_ab"]) - 0.5)
	pruefe(absf(h._vergeltung_in - rest) < 0.7, "die nächste erst 25 s nach Beginn (noch %.1f s)" % h._vergeltung_in)
