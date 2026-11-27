extends SceneTree
## 26.11. (Paul): Befehl 24 – der Herausforderer (Boss zu Minute 9 und 14), headless.
##
##   godot --headless --path . --fixed-fps 60 -s werkzeuge/herausforderertest.gd
##
## Ohne Zusatz setzt der Test die Zeitpunkte selbst. Mit `-- zeiten` gelten die echten (540 s und 840 s): Der Test stellt
## die Überlebens-Uhr kurz davor. Mit `-- sonde` tritt beim zweiten Mal sicher Sonde 7 an und erledigt Brakk (sonst nie –
## die Ziehung ist im Test aus). Schreibt nur user://nemesis_herausforderer_test.json.
## Am Ende „TEST HERAUSFORDERER OK“ oder die Fehler.

var spiel: Node
var o: Order24
var n: Nemesis
var warte := 10
var schritt := 0
var fehler: Array[String] = []
var merk := {}
var echte_zeiten := false
var sonde_modus := false   # -- sonde: Sonde 7 erledigt Brakk (26.11.: niemand wird dafür befördert)


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
	sonde_modus = OS.get_cmdline_user_args().has("sonde")
	r["herausforderer"] = echte_zeiten   # sonst löst der Test ihn selbst aus
	if echte_zeiten:
		r["welle_takt"] = 60
	Order24.test_werte = r
	var main_skript: GDScript = load("res://scripts/main.gd")
	main_skript.set("naechster_start", "normal")
	spiel = load("res://main.tscn").instantiate()
	root.add_child(spiel)
	spiel.protokoll_an = false


const SOLL_PRUEFUNGEN := 115   # F1: +3, F2: +4
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
		var tafel: Variant = spiel.ego.anzeige.get("_briefing") if spiel.ego != null else null
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
	var soll := SOLL_ECHT if echte_zeiten else SOLL_PRUEFUNGEN + (1 if sonde_modus else 0)
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
				_c1_vorher()
				_weiter()
		3:
			var kp := o.herausforderer.kampfplatz
			if not merk.has("c1"):
				if o.zeit > float(merk["auftritt_um"]) + 0.8:
					_punkt2_auftritt()
					_c1_gemerkt()
					merk["c1"] = 0
					merk["t"] = o.zeit
			elif int(merk["c1"]) == 0:
				if kp.zu() and o.herausforderer.einzug.is_empty() and kp._plan.is_empty():
					_c1_platz()
					merk["c1"] = 1
					merk["t"] = o.zeit
				elif _seit() > 16.0:
					pruefe(false, "C1: Kampfplatz nach 16 s nicht fertig (Lichtwand %.2f, Einzug %s)" % [kp.licht, str(o.herausforderer.einzug.get("teil", "–"))])
					return _fertig()
			elif int(merk["c1"]) == 1:
				if _f1_einfrieren_laeuft():
					merk["c1"] = 2
					merk["t"] = o.zeit
			elif int(merk["c1"]) == 2:
				if _seit() > 0.1:
					pruefe(not o.herausforderer.sperrt() and o._naechste_welle >= o.zeit + Werte.HERAUSFORDERER_SCHONFRIST - 0.5,
						"F1: Lichtwand fällt – Fahrplan läuft, nächste Welle frühestens in %.1f s (Schonfrist %.0f s)" % [o._naechste_welle - o.zeit, Werte.HERAUSFORDERER_SCHONFRIST])
					# weiter wie vor F1: das Duell läuft ohne Platz, seine Uhr neu (Punkt 2 prüft die 90 s), keine Welle
					o.herausforderer.seit = 0.0
					o._naechste_welle = o.zeit + 9999.0
					merk["plan"] = o.plan_zeit()
					merk["wellen"] = o.wellen
					merk["c1"] = 3
			elif kp.zustand == "aus":
				_c1_aufgeloest()
				_weiter()
			elif _seit() > 15.0:
				pruefe(false, "C1: Kampfplatz nach 15 s nicht aufgelöst")
				return _fertig()
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
	var p2 := n.herausforderer_waehlen(p)
	pruefe(p2 != p and str(p2.get("art", "")) != str(p["art"]) and int(p["rang"]) == rang, "C1 Rotation: zu Minute 14 ein anderer, andere Art (%s → %s)" % [str(p["art"]), str(p2.get("art", "–"))])
	# C1: über 20 zufällige Besetzungen ist die zweite Art nie die erste – auch ohne passenden Benannten
	var arten := ["technogunner", "scharfschuetze", "plasmawerfer"]
	var gleich := 0
	var befoerdert := 0
	for i in 20:
		n.personen = []
		var nur := str(arten[i % 3]) if i % 4 == 0 else ""   # jede vierte Besetzung: alle Benannten gleicher Art
		for j in randi_range(2, 5):
			var q := n.neue_person(nur if nur != "" else str(arten.pick_random()), randi_range(1, 4), "T%d" % j, "der Rest")
			q["bilanz"] = {"er": randi_range(0, 5), "brakk": randi_range(0, 3)}
		var erst := n.herausforderer_waehlen()
		var zweit := n.herausforderer_waehlen(erst)
		if zweit.is_empty() or str(zweit["art"]) == str(erst["art"]):
			gleich += 1
		if not zweit.is_empty() and int(zweit["rang"]) == 2 and str(zweit.get("tat", "")) == "garantie":
			befoerdert += 1
	pruefe(gleich == 0 and befoerdert >= 5, "C1: 20 Läufe – zweite Art nie gleich der ersten (%d gleich, %d befördert mangels Benannter)" % [gleich, befoerdert])
	n.personen = alte.duplicate()
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
	# C1: Sonde 7 zu Minute 14 – etwa SONDE_BOSS_CHANCE von 200 Ziehungen, zu Minute 9 nie
	var h := o.herausforderer
	var alt_naechste := h.naechste
	h.naechste = 1
	var sonde := 0
	for i in 200:
		if h.sonde_zieht():
			sonde += 1
	h.naechste = 0
	var vorn := 0
	for i in 200:
		if h.sonde_zieht():
			vorn += 1
	h.naechste = alt_naechste
	pruefe(sonde >= 50 and sonde <= 90 and vorn == 0, "C1: Sonde 7 zu Minute 14 in %d von 200 Ziehungen (Soll ~70), zu Minute 9 in %d" % [sonde, vorn])


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
	h.typ = NemesisBoss.new(h)   # C2: hier das Gerüst (Salve, Kugel, Sturm); die Bosstypen prüft bosstest.gd
	pruefe(bool(a.get("einzug", false)) and float(a.get("abstand", 0.0)) >= 6.0 and float(a.get("abstand", 99.0)) <= 30.0, "C1: beamt %.1f Felder entfernt vor dem Kampfplatz herein und kommt von außen" % float(a.get("abstand", 0.0)))
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


# ------------------------------------------------------------------ C1: Kampfplatz

## Vor dem Räumen (bei der Ansage): die ganze Karte merken – nach dem Duell muss der Bereich wieder genau so aussehen.
func _c1_vorher() -> void:
	merk["feld_vorher"] = o.karte.feld.duplicate()
	merk["ausbau_vorher"] = o.karte.ausbau.duplicate()
	merk["fabriken_vorher"] = spiel.fabriken.duplicate()
	merk["fabrik_hp_vorher"] = o.fabrik_hp.duplicate()


## Während des Duells: der Bereich wurde 1 s nach der Ansage gemerkt und geräumt.
func _c1_gemerkt() -> void:
	var kp := o.herausforderer.kampfplatz
	pruefe(kp.aktiv() and absf(float((kp.protokoll[0] as Dictionary)["bei"]) - (float(merk["auftritt_um"]) - 9.0)) < 0.2, "C1: 1 s nach der Ansage gemerkt und geräumt: %d Felder (Mitte %s, Brakk %s)" % [kp.gespeichert.size(), str(kp.mitte), str((kp.protokoll[0] as Dictionary).get("brakk", "–"))])
	var falsch := 0
	var fabriken := 0
	for e: Dictionary in kp.gespeichert:
		var z: Vector2i = e["z"]
		if e["fabrik"] != null:
			fabriken += 1
		if spiel.fabriken.has(z) or o.fabrik_hp.has(z) or (o.karte.feld.has(z) and not BrakkKampfplatz.fallplan().has(z - kp.mitte)):
			falsch += 1
	pruefe(falsch == 0 and not kp.gespeichert.is_empty(), "C1: nichts Gemerktes steht mehr im Bereich (%d Felder, davon %d Fabriken; %d falsch)" % [kp.gespeichert.size(), fabriken, falsch])


func _c1_platz() -> void:
	var h := o.herausforderer
	var kp := h.kampfplatz
	var karte: Karte = o.karte
	var k: Kommandant = spiel.kommandant
	var bg: BrakkGeschosse = spiel.brakk_geschosse
	var fehlt := 0
	for r: Vector2i in BrakkKampfplatz.fallplan():
		if karte.inhalt(kp.mitte + r) != Karte.WALL:
			fehlt += 1
	pruefe(fehlt == 0 and kp.gesetzt.size() >= 30, "C1: alle Wälle des Platzes stehen (%d selbst gesetzt, %d Felder ohne Wall)" % [kp.gesetzt.size(), fehlt])
	var luecken := 0
	for s: String in BrakkKampfplatz.SEITEN:
		for r: Vector2i in BrakkKampfplatz.luecke(s):
			if not kp.gesetzt.has(kp.mitte + r):
				luecken += 1
	pruefe(luecken == 4 * Werte.KAMPFPLATZ_LUECKE and BrakkKampfplatz.luecke("oben").size() == 2, "C1: vier Lücken zu je 2 Feldern bleiben ohne Wall")
	var drin := h.protokoll.filter(func(x: Dictionary) -> bool: return str(x["was"]) == "drin")
	var wie := h.protokoll.filter(func(x: Dictionary) -> bool: return str(x["was"]).begins_with("einzug_"))
	pruefe(not drin.is_empty() and bool(drin[0]["innen"]) and kp.innen_px(h.einheit.position), "C1: der Herausforderer ist drin (%s)" % (str(wie[0]["was"]) if not wie.is_empty() else "–"))
	var gesprengt := kp.protokoll.filter(func(x: Dictionary) -> bool: return str(x["was"]) == "gesprengt")
	if not gesprengt.is_empty():
		pruefe(karte.inhalt(gesprengt[0]["z"] as Vector2i) == Karte.WALL and kp.gesetzt.has(gesprengt[0]["z"] as Vector2i), "C1: gesprengter Randwall ist ersetzt")
	else:
		pruefe(not wie.is_empty() and str(wie[0]["was"]) == "einzug_sprung", "C1: er ist über den Randwall gesprungen")
	pruefe(kp.zu() and kp.innen_px(kp._fuss()), "C1: Lichtwand zu, Brakk steht drin")
	# Schüsse von draußen: Technogunner, Scharfschütze, Turm
	h._bis_angriff = 999.0
	h.angriff = {}
	bg.leeren()
	var aussen := Vector2(kp.rechteck.position.x - 3.0 * Werte.ZELLE, k.position.y)
	var vorher := bg.getroffen
	bg.schiesse("laser", aussen, 0.5, 50.0, "technogunner", "test", 0.0)
	bg.scharf(null, aussen, 0.5, 30.0 * Werte.ZELLE, 50.0, "test")
	bg.turm(karte.zelle_bei(aussen), aussen, "lanze", 50.0, 30.0 * Werte.ZELLE, 0.3 * Werte.ZELLE, 1, "test")
	var turm_ende: Vector2 = (bg.gluehen.back() as Dictionary)["ende"] if not bg.gluehen.is_empty() else k.position
	for i in 150:
		bg.weiter(Werte.SPIELTEMPO / 60.0)
	pruefe(bg.getroffen == vorher and not kp.rechteck.grow(-2.0).has_point(turm_ende), "C1: Schüsse und Turmstrahl von draußen enden an der Lichtwand (%d Treffer)" % (bg.getroffen - vorher))
	bg.leeren()
	# Brakk kommt nicht hinaus: zu Fuß nicht durch die Lücke, und wer doch draußen landet, steht wieder drin
	var ego: EgoModus = spiel.ego
	var lz := kp.mitte + BrakkKampfplatz.luecke("links")[0]
	k.oben = false
	ego.hoehe = 0.0
	ego._setze_fuss(karte.mitte(lz))
	var da := ego._fuss2d()
	ego._schritt(Vector2(-1.0 * Werte.ZELLE, 0.0))
	pruefe(ego._fuss2d() == da, "C1: zu Fuß nicht durch die Lichtwand")
	kp._process(0.016)
	k.position = aussen
	kp._process(0.016)
	pruefe(kp.innen_px(kp._fuss()), "C1: wer draußen landet, steht wieder drin")
	ego._setze_fuss(karte.mitte(lz + Vector2i(1, 0)))   # vor der Lücke: geradeaus hindurch hielte nur die Lichtwand
	var schuss := ego._strahl_bis(ego._zu3d(ego._fuss2d(), 1.0), Vector3(-1, 0, 0), 30.0)
	pruefe(schuss < 2.0, "C1: Brakks Schüsse enden an der Lichtwand (%.2f Felder durch die Lücke)" % schuss)
	# eine Truppe, die sich hineindrängt, steht wieder draußen
	var t := o._neue_truppe("technogunner", spiel.fabriken.keys()[0], 1)
	t.position = karte.mitte(kp._frei_innen(kp.mitte + Vector2i(3, 0)))
	kp.schritt(0.016)
	pruefe(not kp.rechteck.has_point(t.position), "C1: Truppen im Platz stehen wieder draußen")
	# Mitte verschoben, wenn der Schild in der Nähe ist
	var s := karte.zelle_bei(o.schild_mitten[0])
	var r := (Vector2(karte.zelle_bei(k.position) - s)).normalized()
	var start := s + Vector2i(roundi(r.x * 9.0), roundi(r.y * 9.0))
	var m := kp.mitte_suchen(start)
	pruefe(not kp.platz_ok(start) and m != start and (m == Karte.KEINE or kp.platz_ok(m)), "C1: über dem Schild verschoben: %s → %s" % [str(start), str(m)])
	_c1_bewegung()
	merk["bereich"] = kp._bereich(kp.mitte)
	_f1_einfrieren_start()


## F1 (26.11., Paul): 120 s Duell hinter der Lichtwand – der Fahrplan steht, auch nach HERAUSFORDERER_PAUSE_MAX.
func _f1_einfrieren_start() -> void:
	var h := o.herausforderer
	o.vorstoss_anteil = 0.4
	o._naechste_welle = o.zeit + 10.0   # ohne Pause käme in 10 s eine Welle
	merk["f1"] = {"wellen": o.wellen, "anteil": o.vorstoss_anteil, "plan": o.plan_zeit(), "t": o.zeit, "pilot": o._pilot_ab}
	h.seit = 0.0


func _f1_einfrieren_laeuft() -> bool:
	var h := o.herausforderer
	_f2_q_e()   # F2: in den ersten Sekunden des 120-s-Duells
	h._bis_angriff = 999.0
	h._vergeltung_in = 999.0
	h.angriff = {}
	var f: Dictionary = merk["f1"]
	if o.zeit - float(f["t"]) < 120.0:
		return false
	pruefe(h.zustand == "duell" and h.seit > Werte.HERAUSFORDERER_PAUSE_MAX and h.sperrt() and h.kampfplatz.zu() and o.haelt_feuer(o.brakk_ziel),
		"F1: nach %.0f s Duell hinter der Lichtwand ruht der Fahrplan noch (ohne Lichtwand nur %.0f s)" % [h.seit, Werte.HERAUSFORDERER_PAUSE_MAX])
	pruefe(o.wellen == int(f["wellen"]) and is_equal_approx(o.vorstoss_anteil, float(f["anteil"])) and absf(o.plan_zeit() - float(f["plan"])) < 0.1 and o._pilot_ab - float(f["pilot"]) > 119.0,
		"F1: 120 s Duell – Wellen %d → %d, Einnahme %.2f → %.2f, Fahrplan %.1f → %.1f s, Pilot wartet mit" % [int(f["wellen"]), o.wellen, float(f["anteil"]), o.vorstoss_anteil, float(f["plan"]), o.plan_zeit()])
	merk["brakk_im_platz"] = h.kampfplatz._fuss()
	h.kampfplatz.aufloesen()   # wie am Ende des Duells (ohne liegenden Herausforderer: gleich zurück); die übrigen Prüfungen laufen ohne Platz
	return true


## C1.3: 12 s Bewegung im Platz (ohne Angriffe): er bleibt drin und steigt auf die festen Wälle innen.
func _c1_bewegung() -> void:
	var h := o.herausforderer
	var kp := h.kampfplatz
	var k: Kommandant = spiel.kommandant
	k.position = o.karte.mitte(kp._frei_innen(kp.mitte + Vector2i(4, 0)))
	k.oben = false
	h.einheit.position = o.karte.mitte(kp._frei_innen(kp.mitte + Vector2i(-3, -1)))
	h.einheit.zustand = Einheit.Zustand.BODEN
	h._aktion = {}
	h._weg.clear()
	h.kennwerte["wall"] = true
	h._wall_abkling = 0.0
	h._wall_rest = 0.0
	h.zaehler = {"sprung": 0, "tumble": 0, "ausweichen": 0, "wall": 0}
	var raus := 0
	var kronen := {}
	var rand := 0
	for i in 720:
		h._bis_angriff = 999.0
		h.angriff = {}
		h._vergeltung_in = 999.0
		h.schritt(1.0 / 60.0)
		if not kp.innen_px(h.einheit.position):
			raus += 1
		if h.einheit.zustand == Einheit.Zustand.AUF_POSTEN and h._aktion.is_empty():
			var z := o.karte.zelle_bei(h.einheit.position)
			if kp.ist_krone(z):
				kronen[z] = true
			elif not kp.im_innern(z):
				rand += 1
	pruefe(raus == 0 and rand == 0, "C1: 12 s Bewegung – immer im Platz (%d Bilder draußen), oben nur auf dem Randring" % raus)
	pruefe(int(h.zaehler["wall"]) >= 1 and not kronen.is_empty(), "F2: er steigt auf die Kronen des Randrings (%d-mal, Kronen %s)" % [int(h.zaehler["wall"]), str(kronen.keys())])
	pruefe(is_equal_approx(Werte.HERAUSFORDERER_VERGELTUNG_ABKLING, 20.0), "C1: Vergeltung alle 20 s")
	h.kennwerte["wall"] = false


## Nach dem Duell: Brakk am Myriaden-HQ, und im Bereich steht wieder alles wie vor dem Räumen.
func _c1_aufgeloest() -> void:
	var kp := o.herausforderer.kampfplatz
	var karte: Karte = o.karte
	var b: Rect2i = merk["bereich"]
	var feld_v: Dictionary = merk["feld_vorher"]
	var ausbau_v: Dictionary = merk["ausbau_vorher"]
	var fab_v: Dictionary = merk["fabriken_vorher"]
	var hp_v: Dictionary = merk["fabrik_hp_vorher"]
	var anders: Array = []
	for y in range(b.position.y, b.end.y):
		for x in range(b.position.x, b.end.x):
			var z := Vector2i(x, y)
			if feld_v.get(z, -1) != karte.feld.get(z, -1) or ausbau_v.get(z, -1) != karte.ausbau.get(z, -1) \
					or fab_v.has(z) != spiel.fabriken.has(z) or (fab_v.has(z) and fab_v[z] != spiel.fabriken[z]) or hp_v.get(z, -1.0) != o.fabrik_hp.get(z, -1.0):
				anders.append(z)
	var waelle := feld_v.keys().filter(func(z: Vector2i) -> bool: return b.has_point(z)).size()
	pruefe(anders.is_empty() and waelle > 0, "C1: nach %.1f s steht im Bereich alles wie vorher (%d Gebäude; abweichend: %s)" % [_seit(), waelle, str(anders.slice(0, 6))])
	var vorher: Vector2 = merk["brakk_im_platz"]
	var fz := karte.zelle_bei(kp._fuss())
	pruefe(kp._fuss().distance_to(vorher) < 3.0 * Werte.ZELLE and karte.ist_begehbar(fz) and karte.inhalt(fz) != Karte.WALL,
		"F1: Brakk bleibt im Platz stehen (%.1f Felder vom Duell-Ort – fiel dort Gemerktes zurück, steht er daneben; nicht am Myriaden-HQ)" % (kp._fuss().distance_to(vorher) / Werte.ZELLE))
	pruefe(kp.zustand == "aus" and o.lichtwand_schnitt(kp.rechteck.get_center(), kp.rechteck.position - Vector2(50, 50)) == Vector2.INF, "C1: Lichtwand aus, Kampfplatz weg")


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
		o.beutewerk._beute_pflegen(k)
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
	o.beutewerk._beute_pflegen(k)
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
	h.sonde_erzwingen = sonde_modus   # 26.11.: die Ziehung fest – sonst wackelt der zweite Auftritt
	h.sonde_aus = not sonde_modus
	o._naechste_welle = o.zeit + 500.0


func _punkt7_zweiter() -> void:
	merk["rang"] = int((merk["person"] as Dictionary)["rang"])
	merk["befoerderungen"] = n.befoerderungen.size()
	merk["personen"] = n.personen.size()


func _punkt7_brakk_faellt() -> void:
	var h := o.herausforderer
	var erster: Dictionary = merk["person"]
	if sonde_modus:
		pruefe(h.ist_sonde() and int(erster["rang"]) == int(merk["rang"]), "Sonde 7 tritt selbst an (erzwungen)")
	else:
		pruefe(h.person != erster and str(h.person["art"]) != str(erster["art"]) and int(erster["rang"]) == int(merk["rang"]), "C1: der Geborgene kommt nicht wieder – %s statt %s" % [str(h.person["art"]), str(erster["art"])])
	merk["person"] = h.person
	var p: Dictionary = h.person
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
	var tod := n.tod_bericht()
	if sonde_modus:
		pruefe(o.vorbei and str((h.ergebnisse.back() as Array)[1]) == "gesiegt" and chronik == "[]" and int(p["rang"]) == 4, "Brakk fällt: Sonde 7 hat gesiegt – kein Rang, keine Chronik")
		pruefe(bool(tod.get("duell", false)) and str(tod.get("name", "")) == "Sonde 7" and str(tod.get("art", "")) == Nemesis.TITEL_KOMMANDANTIN \
			and (Nemesis.TOD_ZEILEN.get("sonde", []) as Array).has(str(tod.get("zeile", ""))) and str(tod.get("bilanz", "")) == "Stand 1 : 0 für sie", \
			"Deathscreen: im Duell erledigt von %s (%s, „%s“)" % [str(tod.get("name", "–")), str(tod.get("art", "–")), str(tod.get("zeile", "–"))])
		var neue := n.personen.filter(func(x: Dictionary) -> bool: return str(x.get("tat", "")) == "letzter_treffer" or str(x.get("beiname", "")) == "Brakkbrecher")
		pruefe(n.befoerderungen.size() == int(merk["befoerderungen"]) and n.personen.size() == int(merk["personen"]) and neue.is_empty() and bool(n.erledigt_von.get("sonde", false)),
			"für ihren Treffer niemand befördert (Beförderungen %d → %d, Benannte %d → %d)" % [int(merk["befoerderungen"]), n.befoerderungen.size(), int(merk["personen"]), n.personen.size()])
	else:
		pruefe(o.vorbei and str((h.ergebnisse.back() as Array)[1]) == "gesiegt" and chronik.contains("hat Brakk im Duell geschlagen"), "Brakk fällt: er hat gesiegt, steht so in der Chronik")
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
				h.sonde_aus = true   # 26.11.: zu 14:00 sonst zufällig Sonde 7 (gleiche Art wie ein Technogunner zuvor)
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
				_brakk_weg_vom_boss()   # 27.11.: sonst hebt er den Ring sofort auf (Jagdanker oder Sturm brachten ihn direkt an den Boss)
				h.einheit.nimm_schaden(9999999.0)
				_weiter()
		3:
			# F1 (26.11., Paul): erst wenn die Lichtwand fällt (nach der Bergung), dann die Schonfrist – danach Wellen
			if not merk.has("frei_um") and h.zustand == "ruhe" and not h.sperrt():
				merk["frei_um"] = o.zeit
				o._naechste_welle = minf(o._naechste_welle, o.zeit + 1.0)
			if merk.has("frei_um") and o.zeit - float(merk["frei_um"]) > Werte.HERAUSFORDERER_SCHONFRIST + 2.0:
				pruefe(h.zustand == "ruhe" and o.beute_boden.size() >= 1 and o.wellen > int(merk["wellen"]), "vertrieben: Ring liegt, nach Lichtwand und Schonfrist laufen die Wellen wieder")
				o.zeit = 827.0
				_weiter()
			elif _seit() > 40.0:
				pruefe(false, "vertrieben: Lichtwand nach 40 s noch zu")
				return _fertig()
		4:
			if h.zustand == "duell":
				pruefe(absf(float(_eintrag("ansage", 1)["bei"]) - 830.0) < 0.2 and absf(float(_eintrag("auftritt", 1)["bei"]) - 840.0) < 0.2, "zweites Mal: Ansage %.1f s, Auftritt %.1f s" % [float(_eintrag("ansage", 1)["bei"]), float(_eintrag("auftritt", 1)["bei"])])
				pruefe(h.person != merk["p"] and str(h.person["art"]) != str((merk["p"] as Dictionary)["art"]), "C1: zweites Mal ein anderer, andere Art (%s nach %s)" % [str(h.person["art"]), str((merk["p"] as Dictionary)["art"])])
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
	# H-7 (27.11., Paul): die Säule steht BOSS_SAEULE_SEK s mit BOSS_SAEULE_JE_SEK je Sekunde (vorher ein Einschlag mit einem Treffer)
	var soll_saeule := Werte.BOSS_SAEULE_SEK * Werte.BOSS_SAEULE_JE_SEK
	var saeule_vor := h.saeule_schaden
	_angriff_ausfuehren("saeule", Werte.BOSS_SAEULE_ANSAGE + Werte.BOSS_SAEULE_SEK + 0.4)
	t = h.saeule_schaden - saeule_vor   # nur die Säule (danach greift er weiter an)
	var s_ans := h.protokoll.filter(func(x: Dictionary) -> bool: return str(x["was"]) == "angriff" and str(x["art"]) == "saeule")
	var s_vor := float(s_ans.back()["angesagt"]) if not s_ans.is_empty() else 0.0
	pruefe(absf(t - soll_saeule) < 0.08 and s_vor >= 1.45, "Lichtsäule: stehend %.2f Treffer (Soll %.2f), Vorschau %.2f s wie bei Brakk" % [t, soll_saeule, s_vor])
	h._saeule_weg()
	_stelle(6.0)
	h._saeule_weg()
	h.beginne_angriff("saeule")
	var warnt := h.saeule_ueber_brakk()
	(spiel.kommandant as Kommandant).position += Vector2(0, 2.2 * Z)
	pruefe(warnt and not h.saeule_ueber_brakk(), "Warnzeile nur, solange Brakk im Kreis steht")
	h.angriff = {}
	h._marke_weg()
	_stelle(6.0)
	h._saeule_weg()
	var saeule_vor2 := h.saeule_schaden
	_angriff_ausfuehren("saeule", Werte.BOSS_SAEULE_ANSAGE + Werte.BOSS_SAEULE_SEK + 0.4, Vector2(0, 2.2 * Z), 0.7)
	t = h.saeule_schaden - saeule_vor2   # nur die Säule
	h._saeule_weg()
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
	# H-7 (27.11., Paul): die Vergeltung ist immer die Lichtsäule (die meistgenutzte Quelle – hier der Ladestrahl – zählt nicht mehr)
	var v := h.protokoll.filter(func(x: Dictionary) -> bool: return str(x["was"]) == "vergeltung")
	pruefe(not v.is_empty() and str(v.back()["art"]) == "saeule" and not t.is_empty() and str(t[0]["titel"]) == "Vergeltung: Lichtsäule", "Ansage „Vergeltung: Lichtsäule“")
	pruefe((h.einheit.get_meta("nemesis_umriss") as Color).is_equal_approx(NemesisHerausforderer.VERGELTUNG_UMRISS), "lila Umriss")
	pruefe(Hangar.karten_zeilen_alle(h.person).any(func(z: Array) -> bool: return str(z[0]) == "Vergeltung" and str(z[1]).ends_with("Lichtsäule")), "ab jetzt in der Karte")


func _punkt6_takt_aus() -> void:
	var h := o.herausforderer
	pruefe(h.stehende_saeule.is_empty() and not (h.einheit.get_meta("nemesis_umriss") as Color).is_equal_approx(NemesisHerausforderer.VERGELTUNG_UMRISS), "Säule erloschen, Umriss wie vorher")
	var rest := Werte.HERAUSFORDERER_VERGELTUNG_ABKLING - (o.zeit - float(merk["v_ab"]) - 0.5)
	pruefe(absf(h._vergeltung_in - rest) < 0.7, "die nächste erst 20 s nach Beginn (noch %.1f s)" % h._vergeltung_in)








# ------------------------------------------------------------------ F2: Kampfplatz innen neutral, Rand interaktiv

func _f2_zielen(wand: Vector2i, stand: Vector2i, hoch: float) -> void:
	var ego: EgoModus = spiel.ego
	var k: Kommandant = spiel.kommandant
	k.oben = false
	k.posten_zelle = Karte.KEINE
	ego.hoehe = 0.0
	ego._setze_fuss(o.karte.mitte(stand))
	ego._kamera()
	spiel.hd.kamera.look_at(ego._zu3d(o.karte.mitte(wand), hoch), Vector3.UP)


## F2 (26.11., Paul): innen keine festen Wälle; [Q] Lichtanker und [E] Lichttreppe greifen an den Rand-Wällen;
## Sprengladungen nicht. Läuft Bild für Bild in den ersten 8 s des 120-s-Duells (F1).
func _f2_q_e() -> void:
	var kp := o.herausforderer.kampfplatz
	var ego: EgoModus = spiel.ego
	var k: Kommandant = spiel.kommandant
	var h := BrakkKampfplatz._halb()
	var q_wand: Vector2i = kp.mitte + Vector2i(h.x - 1, 2)
	var e_wand: Vector2i = kp.mitte + Vector2i(h.x - 1, -3)
	var t := o.zeit - float((merk["f1"] as Dictionary)["t"])
	match int(merk.get("f2", 0)):
		0:
			var innen := 0
			for y in range(-h.y, h.y):
				for x in range(-h.x, h.x):
					var z: Vector2i = kp.mitte + Vector2i(x, y)
					if kp.im_innern(z) and o.karte.inhalt(z) == Karte.WALL:
						innen += 1
			pruefe(innen == 0 and Werte.KAMPFPLATZ_INNEN.is_empty() and kp.ist_krone(q_wand) and kp.ist_krone(e_wand), "F2: innen keine Wälle (%d), nur der Randring" % innen)
			o.ladungen = 1
			var grund := o.ladung_setzen(q_wand)
			pruefe(grund != "" and o.ladungen == 1 and o.zuender.is_empty(), "F2: Rand-Wall nicht sprengbar („%s“)" % grund)
			k.fortschritt.alle_frei = true
			_f2_zielen(q_wand, kp._frei_innen(kp.mitte + Vector2i(h.x - 4, 2)), spiel.hd.H * 0.95)
			ego.lichtwerk._anker_rest = 0.0
			ego.lichtwerk._anker_start()
			merk["f2"] = 1
		1:
			if t > 0.6:
				ego.lichtwerk._anker_start()   # zweites [Q]: zieht hinauf
				merk["f2"] = 2
		2:
			if t > 3.5:
				pruefe(k.oben and k.posten_zelle == q_wand, "F2: [Q] Lichtanker zieht Brakk auf die Krone eines Rand-Walls (%s, oben %s)" % [str(k.posten_zelle), str(k.oben)])
				_f2_zielen(e_wand, kp._frei_innen(kp.mitte + Vector2i(h.x - 4, -3)), spiel.hd.H * 0.5)
				k.e_rest = 0.0
				ego.lichtwerk._versuche_klettern(false)   # [E]: Treppe an den Rand-Wall
				merk["f2"] = 3
		3:
			if t > 4.0:
				if ego.lichtwerk._treppe_fuss2d != Vector2.INF:
					ego._setze_fuss(ego.lichtwerk._treppe_fuss2d)
				ego.lichtwerk._versuche_klettern(false)   # [E] am Fuß der Treppe: hinauf
				merk["f2"] = 4
		4:
			if t > 7.0:
				pruefe(k.oben and k.posten_zelle == e_wand, "F2: [E] Lichttreppe an einen Rand-Wall, Brakk steht oben (%s)" % str(k.posten_zelle))
				_f2_zielen(e_wand, kp._frei_innen(kp.mitte), 0.5)   # wieder hinunter, mitten in den Platz
				merk["f2"] = 5


## 27.11.: Brakk auf das freie Feld im Kampfplatz, das am weitesten vom Herausforderer weg liegt (der Ring soll liegen bleiben).
func _brakk_weg_vom_boss() -> void:
	var h := o.herausforderer
	var kp := h.kampfplatz
	if not kp.aktiv() or h.einheit == null or not is_instance_valid(h.einheit):
		return
	var hb := BrakkKampfplatz._halb()
	var beste := Vector2.INF
	var weit := -1.0
	for y in range(kp.mitte.y - hb.y, kp.mitte.y + hb.y):
		for x in range(kp.mitte.x - hb.x, kp.mitte.x + hb.x):
			var z := Vector2i(x, y)
			if kp.im_innern(z) and o.karte.ist_begehbar(z) and o.karte.ist_frei(z):
				var p := o.karte.mitte(z)
				var d := p.distance_to(h.einheit.position)
				if d > weit:
					weit = d
					beste = p
	if beste != Vector2.INF:
		var k: Kommandant = spiel.kommandant
		k.oben = false
		spiel.ego._setze_fuss(beste)
		spiel.ego.hoehe = 0.0
		k.position = beste
