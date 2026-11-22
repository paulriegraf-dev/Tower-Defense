extends SceneTree
## 22.11. (Paul): Nemesis-System in Befehl 24 – Teil 1+2 headless prüfen.
##
##   godot --headless --path . --fixed-fps 60 -s werkzeuge/nemesistest.gd
##
## Brakk nimmt keinen Schaden (brakk_schaden 0); Treffer auf Brakk und Zeitablauf stellt der Test direkt (Nemesis-Aufrufe).
## Geprüft: die Drei vom Appell bilden den ersten Elitetrupp (eine je Truppenart) · jede der sieben Beförderungsbedingungen
## gibt eine Feldbeförderung mit passendem Beinamen · die Garantie greift zur zweiten Elitewelle · eine kampfunfähige Elite
## wird geborgen (Sprengladung fällt) und kommt in der nächsten Elitewelle mit Narbe und −15 % Leben zurück · Deckel von drei
## Feldbeförderungen · Rang +1 am Laufende. Am Ende „TEST NEMESIS OK“ oder die Fehler.
## Schreibt wie das Spiel in user:// – vorher sichern.

var spiel: Node
var o: Order24
var n: Nemesis
var warte := 10
var schritt := 0
var fehler: Array[String] = []
var merk := {}


func _initialize() -> void:
	Nemesis.datei = "user://nemesis_test.json"   # 22.11.: Tests schreiben nie in die echte Liste der Meistgesuchten
	Nemesis.zuruecksetzen()
	OS.set_environment("TD_KARTE_NAME", "szenario_order24")
	Werte.lade_karte("szenario_order24")
	var r: Dictionary = (Werte.KARTE_REGELN.get("order24", {}) as Dictionary).duplicate()
	r["karte"] = "3-zitadelle"
	r["brakk_schaden"] = 0
	r["ueberleben_sek"] = 0
	r["geheim_ab"] = 0
	r["welle_takt"] = 9999   # Wellen nur, wenn der Test sie auslöst
	r["elite_jede"] = 1
	r["flucht_sek"] = 0      # gleich Jagdphase (sonst hieße jeder Volltreffer „Frühaufsteher“)
	r["jagd_start"] = 0
	Order24.test_werte = r
	var main_skript: GDScript = load("res://scripts/main.gd")
	main_skript.set("naechster_start", "normal")
	spiel = load("res://main.tscn").instantiate()
	root.add_child(spiel)
	spiel.protokoll_an = false


func pruefe(ok: bool, text: String) -> void:
	print("%s %s" % ["OK  " if ok else "FEHL", text])
	if not ok:
		fehler.append(text)


## Freie Truppe nahe Brakk, vor ihm (in Blickrichtung, nicht im Hinterhalt), `felder` entfernt.
func truppe(typ: String, stufe: int, felder: float = 4.0, seitlich: float = 0.0) -> Einheit:
	var k: Kommandant = spiel.kommandant
	var von: Vector2i = o.fabrik_hp.keys()[0]
	var e := o._neue_truppe(typ, von, stufe)
	var blick := Vector2(-sin(spiel.ego.gier), -cos(spiel.ego.gier)) if spiel.ego != null else Vector2.RIGHT
	e.position = k.position + blick * felder * Werte.ZELLE + blick.orthogonal() * seitlich * Werte.ZELLE
	e._punkte.clear()
	return e


func beiname(e: Einheit) -> String:
	return str(n.person_von(e).get("beiname", ""))


## Bedingung prüfen: vorher Zähler zurück (sonst greift der Deckel von drei), danach Beiname vergleichen.
func bedingung(e: Einheit, soll: String, text: String) -> void:
	var p := n.person_von(e)
	pruefe(Nemesis.benannt(p) and beiname(e) == soll, "%s → %s (%s)" % [text, Nemesis.voller_name(p), "Beiname soll „%s“" % soll])
	n.feld_n = 0


func altern(e: Einheit) -> void:
	var b: Dictionary = n._begegnung.get(e.get_instance_id(), {})
	if not b.is_empty():
		b["zuletzt"] = o.zeit - Werte.NEMESIS_BEGEGNUNG_RUHE - 0.5
	n._physics_process(0.0)


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
	k.leben = k.max_leben
	match schritt:
		0:
			_appell()
			schritt += 1
		1:
			_bedingungen()
			schritt += 1
		2:
			_garantie()
			schritt += 1
		3:
			_bergung_start()
			schritt += 1
		4:
			_bergung_beam()
			schritt += 1
		5:
			_bergung_zurueck()
			schritt += 1
		6:
			_deckel_und_laufende()
			schritt += 1
		7:
			_bildschirme()
			schritt += 1
		8:
			_ausschalten_und_wiedersehen()
			schritt += 1
		9:
			_gewohnheiten_abschauen()
			schritt += 1
		10:
			_gewohnheiten_bergen()
			schritt += 1
		11:
			_gewohnheiten_feld()
			schritt += 1
		12:
			_lernen_zehn()
			schritt += 1
		13:
			_lernen_verhalten()
			schritt += 1
		14:
			_lernen_trupp()
			schritt += 1
		15:
			_ueber_laeufe()
			schritt += 1
		_:
			for f: String in fehler:
				print("FEHLER: " + f)
			print("TEST NEMESIS OK" if fehler.is_empty() else "TEST NEMESIS FEHLER (%d)" % fehler.size())
			Nemesis.zuruecksetzen()   # Testdatei weg
			return true
	return false


## Die Drei vom Appell sind benannt (Rang 1) und bilden den ersten Elitetrupp, je eine Truppenart.
func _appell() -> void:
	var namen := n.benannte().map(func(p: Dictionary) -> String: return Nemesis.voller_name(p))
	pruefe(namen.size() == 3, "Drei vom Appell benannt: %s" % ", ".join(PackedStringArray(namen)))
	o._jagdwelle()
	var t: Dictionary = o.trupps[o.trupps.size() - 1]
	var arten: Array[String] = []
	var personen := 0
	for e: Variant in t["mitglieder"]:
		var p := n.person_von(e as Einheit)
		if bool(p.get("appell", false)):
			personen += 1
		arten.append(Nemesis.art_von(e as Einheit))
	arten.sort()
	pruefe(personen == 3 and arten == ["plasmawerfer", "scharfschuetze", "technogunner"], "Erster Elitetrupp = die Drei vom Appell, eine je Art (%s)" % ", ".join(arten))
	merk["appell_trupp"] = t["mitglieder"]


func _bedingungen() -> void:
	var k: Kommandant = spiel.kommandant
	# 1) zwei Begegnungen überlebt
	var a := truppe("technogunner", 1)
	for i in 2:
		n.schuss(a)
		altern(a)
	bedingung(a, "der Wiedergänger", "Zwei Begegnungen überlebt")
	# 2) mehr als 25 % in einer Begegnung (vor Brakk, 4 Felder, keine besondere Lage)
	var b := truppe("technogunner", 1)
	n.brakk_getroffen(b.get_instance_id(), k.max_leben * 0.3)
	bedingung(b, "Volltreffer", "Mehr als 25 % Leben in einer Begegnung")
	# 3) als Letzte ihres Jagdtrupps entkommen
	var c1 := truppe("technogunner", 1, 4.0, 1.0)
	var c2 := truppe("technogunner", 1, 4.0, -1.0)
	o._neuer_trupp([c1, c2], "jagd")
	n.schuss(c1)
	n.schuss(c2)
	c2.nimm_schaden(99999.0)   # fällt (namenlos: stirbt wie bisher)
	altern(c1)
	bedingung(c1, "der Rest", "Letzte ihres Trupps entkommen")
	# 4) unterbrochen: am Med-Kit, beim Sabotieren, beim Setzen einer Sprengladung
	var d1 := truppe("technogunner", 1)
	n.medkit()
	n.brakk_getroffen(d1.get_instance_id(), 1.0)
	bedingung(d1, "der Sanitäter", "Am Med-Kit erwischt")
	n._medkit_zeit = -99.0
	var d2 := truppe("technogunner", 1)
	o.sabo = {"zelle": o.fabrik_hp.keys()[0], "t": 0.0, "leben": k.leben}
	n.brakk_getroffen(d2.get_instance_id(), 1.0)
	o.sabo = {}
	bedingung(d2, "der Hausmeister", "Beim Sabotieren erwischt")
	var d3 := truppe("technogunner", 1)
	n.ladung()
	n.brakk_getroffen(d3.get_instance_id(), 1.0)
	bedingung(d3, "der Entschärfer", "Beim Setzen einer Sprengladung erwischt")
	n._ladung_zeit = -99.0
	# 5) Sprengladung überlebt (Elite-Truppe ohne Datensatz: zäh genug)
	var wall := Karte.KEINE
	for z: Vector2i in o.karte.ausbau.keys():
		if o.karte.inhalt(z) == Karte.WALL and not o._im_schild(o.karte.mitte(z)) and int(o.karte.ausbau.get(z, Karte.FREI)) == Karte.FREI:
			wall = z
			break
	if wall == Karte.KEINE:
		for y in Werte.ZEILEN:
			for x in range(Werte.ZONE_SPALTEN, Werte.SPALTEN):
				var z := Vector2i(x, y)
				if wall == Karte.KEINE and o.karte.inhalt(z) == Karte.WALL and not o._im_schild(o.karte.mitte(z)):
					wall = z
	var s := truppe("technogunner", 4)
	s.position = o.karte.mitte(wall) + Vector2(Werte.ZELLE * 0.9, 0)
	o.sprengen(wall)
	bedingung(s, "Taubes Ohr", "Sprengladung überlebt (Wall %s, Leben %d/%d)" % [str(wall), roundi(s.leben), roundi(s.max_leben)])
	# 6) für einen Trupp aufgedeckt, der dann trifft
	var f1 := truppe("technogunner", 1, 6.0, 2.0)
	var f2 := truppe("technogunner", 1, 4.0, -2.0)
	o._neuer_trupp([f1, f2], "streife")
	var nr := o.trupps.size() - 1
	n.sichtung(f1, nr)
	n.brakk_getroffen(f2.get_instance_id(), 1.0)
	bedingung(f1, "Spürnase", "Für den Trupp aufgedeckt, der dann traf")
	# 7) letzter Treffer: Beförderung mit Rang 2 und „Brakks Bezwinger“
	var g := truppe("technogunner", 1)
	n.brakk_erledigt(g.get_instance_id())
	var pg := n.person_von(g)
	pruefe(int(pg.get("rang", 0)) == 2 and beiname(g) == "Brakkbrecher" and str(pg.get("titel", "")) == "Brakks Bezwinger", "Letzter Treffer → %s (Rang %d, „%s“)" % [Nemesis.voller_name(pg), int(pg.get("rang", 0)), str(pg.get("titel", ""))])
	n.erledigt_von = {}
	# Lage-Beinamen: aus dem Hinterhalt und von einem Wall herab
	var h := truppe("technogunner", 1, -4.0)
	n.brakk_getroffen(h.get_instance_id(), k.max_leben * 0.3)
	bedingung(h, "der Geduldige", "Volltreffer aus dem Hinterhalt (hinter Brakk)")
	pruefe(n.befoerderungen.size() >= 9, "Feldbeförderungen gezählt: %d" % n.befoerderungen.size())
	merk["beispiel"] = a


## Garantie: keine Feldbeförderung bis zur zweiten Elitewelle → die Einheit mit dem meisten Schaden an Brakk.
func _garantie() -> void:
	n.feld_n = 0
	n.elitewellen = Werte.NEMESIS_GARANTIE_WELLE - 1
	var wenig := truppe("technogunner", 1, 5.0, 1.5)
	var viel := truppe("technogunner", 1, 5.0, -1.5)
	n.brakk_getroffen(wenig.get_instance_id(), 3.0)
	n.brakk_getroffen(viel.get_instance_id(), 9.0)
	o._jagdwelle()
	pruefe(beiname(viel) == "der Fleißige" and not Nemesis.benannt(n.person_von(wenig)), "Garantie zur %d. Elitewelle → %s" % [Werte.NEMESIS_GARANTIE_WELLE, Nemesis.voller_name(n.person_von(viel))])


## Eine Elite vom Appell wird kampfunfähig geschossen …
func _bergung_start() -> void:
	var opfer: Einheit = null
	for e: Variant in merk["appell_trupp"]:
		if is_instance_valid(e) and str(n.person_von(e as Einheit).get("name", "")) == "Kord":
			opfer = e as Einheit
	if opfer == null:
		pruefe(false, "Kord aus dem Appell nicht im Feld")
		return
	merk["kord"] = n.person_von(opfer)
	merk["kord_leben"] = opfer.max_leben
	var ladungen := o.ladungen_boden.size()
	opfer.nimm_schaden(999999.0)
	pruefe(is_instance_valid(opfer) and opfer.kampfunfaehig and opfer.leben <= 0.0, "Kord fällt nicht, sondern ist kampfunfähig")
	pruefe(o.ladungen_boden.size() == ladungen + 1, "Sprengladung fällt trotzdem")
	merk["opfer"] = opfer
	for kf: Dictionary in n.kampfunfaehig:
		kf["bis"] = o.zeit - 0.1   # Bergung sofort fällig


## … nach der Frist geborgen (Beam) …
func _bergung_beam() -> void:
	if not merk.has("opfer"):
		return
	n._physics_process(0.0)
	var p: Dictionary = merk["kord"]
	pruefe(n.einheit_von(p) == null and int(p["bergungen"]) == 1 and int(p["narbe"]) == 1, "Kord geborgen (Bergung 1, Narbe 1)")


## … und ist bei der nächsten Elitewelle wieder da – mit Narbe und −15 % Leben.
func _bergung_zurueck() -> void:
	if not merk.has("kord"):
		return
	var p: Dictionary = merk["kord"]
	o._jagdwelle()
	var e := n.einheit_von(p)
	pruefe(e != null, "Kord kommt in der nächsten Elitewelle zurück")
	if e != null:
		var c: Color = e.get_meta("nemesis_umriss", Color.WHITE)
		pruefe(absf(e.max_leben / float(merk["kord_leben"]) - Werte.NEMESIS_VERTRIEBEN_LEBEN) < 0.01, "… mit %d %% Leben (soll %d %%)" % [roundi(100.0 * e.max_leben / float(merk["kord_leben"])), roundi(100.0 * Werte.NEMESIS_VERTRIEBEN_LEBEN)])
		pruefe(c.v < Werte.NEMESIS_UMRISS.v, "… und dunklerem Umriss (Narbe)")


## Deckel: höchstens drei Feldbeförderungen je Lauf; am Laufende Rang +1 für den Lauf ohne Bergung.
func _deckel_und_laufende() -> void:
	n.feld_n = 0
	var zahl := 0
	for i in 5:
		var e := truppe("technogunner", 1, 4.0, float(i) - 2.0)
		n.medkit()
		n.brakk_getroffen(e.get_instance_id(), 1.0)
		if Nemesis.benannt(n.person_von(e)):
			zahl += 1
	pruefe(zahl == Werte.NEMESIS_FELD_MAX, "Deckel: %d von 5 Bedingungen befördert (soll %d)" % [zahl, Werte.NEMESIS_FELD_MAX])
	var vex: Dictionary = {}
	for p: Dictionary in n.personen:
		if str(p["name"]) == "Vex":
			vex = p
	var vorher := int(vex.get("rang", 0))
	n.lauf_ende()
	pruefe(int(vex.get("rang", 0)) == vorher + 1, "Laufende: Vex ohne Bergung → Rang %d → %d" % [vorher, int(vex.get("rang", 0))])
	var kord: Dictionary = merk.get("kord", {})
	pruefe(int(kord.get("rang", 0)) == 1, "Laufende: Kord (geborgen, kaum Schaden) bleibt Rang 1")
	pruefe(n.personen.all(func(p: Dictionary) -> bool: return Nemesis.benannt(p)), "Laufende: Namenlose fallen aus der Liste (%d Benannte)" % n.personen.size())


## 22.11. (Teil 7): Daten für Deathscreen, Siegbild und die Tafel „Meistgesuchte“.
func _bildschirme() -> void:
	n.erledigt_von = {}
	var ohne: Dictionary = o.bericht(false).get("nemesis_tod", {"x": 1})
	pruefe(ohne.is_empty(), "Deathscreen: ohne Soldaten (Turm, Batterie) kein „Erledigt von“ – bisheriger Schluss")
	var z := truppe("scharfschuetze", 1, -5.0)
	n.brakk_erledigt(z.get_instance_id())
	var b := o.bericht(false)
	var t: Dictionary = b.get("nemesis_tod", {})
	print("     Deathscreen: Erledigt von %s · %s · Rang %d · %d. Begegnung · %s · %s · „%s“ · %s" % [t.get("name", "?"), t.get("art", "?"), int(t.get("rang", 0)), int(t.get("begegnung", 0)), t.get("bilanz", "?"), t.get("womit", "?"), t.get("zeile", "?"), t.get("grund", "")])
	pruefe(bool(t.get("namenlos", false)) and str(t.get("name", "")).begins_with("Hauptgefreiter") and str(t.get("womit", "")).begins_with("aus dem Hinterhalt") \
		and (Nemesis.TOD_ZEILEN["befoerdert"] as Array).has(t.get("zeile", "")) and str(t.get("bilanz", "")) == "Stand 1 : 0 für ihn", "Deathscreen: namenloser Scharfschütze wird befördert (Name, Lage, Zeile, Bilanz)")
	var liste: Array = b.get("nemesis", [])
	var arten := {}
	for zeile: Array in liste:
		arten[str(zeile[1])] = int(arten.get(str(zeile[1]), 0)) + 1
	pruefe(int(arten.get("befoerdert", 0)) == n.befoerderungen.size() and int(arten.get("vertrieben", 0)) >= 1, "Siegbild-Liste: %d befördert, %d vertrieben" % [int(arten.get("befoerdert", 0)), int(arten.get("vertrieben", 0))])
	# benannter Schütze: kein „wird befördert“, Bilanz zählt weiter
	n.erledigt_von = {}
	var wer: Einheit = null
	var er_vorher := 0
	for p: Dictionary in n.personen:
		if Nemesis.benannt(p) and Nemesis.lebt(n.einheit_von(p)) and wer == null:
			wer = n.einheit_von(p)
			er_vorher = int((p["bilanz"] as Dictionary)["er"])
	if wer != null:
		var nm := str(n.person_von(wer)["name"])
		n.brakk_erledigt(wer.get_instance_id())
		var tv: Dictionary = n.tod_bericht()
		pruefe(not bool(tv.get("namenlos", true)) and str(tv.get("name", "")).contains(nm) and str(tv.get("bilanz", "")).begins_with("Stand %d" % (er_vorher + 1)), "Deathscreen: Benannter – %s, %s" % [tv.get("name", "?"), tv.get("bilanz", "?")])
	pruefe(not Nemesis.meistgesuchte().is_empty(), "Meistgesuchte: nach dem Laufende in der Datei (%d)" % Nemesis.meistgesuchte().size())


## 22.11. (Teil 6): Wiedersehen beim ersten Treffer im Lauf; endgültig ausschalten mit [E] (nur Benannte), Ring als Beute.
func _ausschalten_und_wiedersehen() -> void:
	var k: Kommandant = spiel.kommandant
	# Wiedersehen: Benannter mit Bergung in der Bilanz → Zeile „hinten“
	var p := n.neue_person("technogunner", 1, "Ziv", "Wiederholungstäter")
	(p["bilanz"] as Dictionary)["brakk"] = 2
	var e := truppe("technogunner", 4, 1.0)
	n.einkleiden(e, p)
	n.wiedersehen = {}
	n.von_brakk(e)
	pruefe(str(n.wiedersehen.get("lage", "")) == "hinten" and (Nemesis.WIEDERSEHEN["hinten"] as Array).has(n.wiedersehen.get("zeile", "")), "Wiedersehen: erster Treffer im Lauf – „%s“ (%s)" % [n.wiedersehen.get("zeile", "?"), n.wiedersehen.get("stand", "?")])
	n.wiedersehen = {}
	n.von_brakk(e)
	pruefe(n.wiedersehen.is_empty(), "Wiedersehen: nur einmal je Lauf")
	# Endgültig ausschalten: kampfunfähig, Brakk steht daneben, [E] halten
	e.position = k.position + Vector2(Werte.ZELLE * 0.5, 0)
	e.nimm_schaden(999999.0)
	var ringe := k.fortschritt.ringe.size() if k.fortschritt != null else 0
	var stufen := 0
	if k.fortschritt != null:
		for r: String in k.fortschritt.ringe:
			stufen += k.fortschritt.ring_stufe(r)
	var budget := int(spiel.budget)
	pruefe(n.ausschalten_taste(true), "Ausschalten: [E] neben dem kampfunfähigen Ziv greift")
	var t := 0.0
	while t < Werte.NEMESIS_HALTEN - 0.2:
		n._halten_weiter(0.1)
		t += 0.1
	pruefe(n.personen.has(p) and n.kampfunfaehig.size() > 0, "Ausschalten: nach %.1f s noch nicht (Halten %.1f s), Bergung wartet" % [t, Werte.NEMESIS_HALTEN])
	for i in 4:
		n._halten_weiter(0.1)
	var stufen2 := 0
	if k.fortschritt != null:
		for r: String in k.fortschritt.ringe:
			stufen2 += k.fortschritt.ring_stufe(r)
	pruefe(not n.personen.has(p) and n.ausgeschaltet.has(p), "Ausschalten: Ziv ist endgültig weg (Liste, Chronik: „%s“)" % str(((p["chronik"] as Array).back() as Dictionary).get("text", "")))
	pruefe(stufen2 > stufen or int(spiel.budget) > budget, "Ausschalten: Ring als Beute (Ringe %d → %d, Stufen %d → %d)" % [ringe, k.fortschritt.ringe.size() if k.fortschritt != null else 0, stufen, stufen2])
	# Namenlose kann man so nicht ausschalten
	var q := n.neue_person("plasmawerfer")
	var e2 := truppe("plasmawerfer", 4, 0.5)
	n.einkleiden(e2, q)
	e2.position = k.position + Vector2(0, Werte.ZELLE * 0.4)
	e2.nimm_schaden(999999.0)
	pruefe(e2.kampfunfaehig and not n.ausschalten_taste(true), "Ausschalten: Namenlose nicht (nur Bergung)")
	var hoch := n.neue_person("scharfschuetze", 3, "Hoch", "Test")
	pruefe(absf(n.halte_zeit(hoch) - Werte.NEMESIS_HALTEN_HOCH) < 0.01, "Ausschalten: ab Rang 3 %.1f s halten" % n.halte_zeit(hoch))
	n.personen.erase(hoch)
	pruefe(n.lauf_liste().any(func(z: Array) -> bool: return str(z[1]) == "ausgeschaltet"), "Siegbild-Liste: Ausgeschaltete stehen drin")


## 22.11. (Teil 6): user://nemesis.json – alte/fehlende Felder, Ziehen zum Laufbeginn, Verdrängen bei 7, Zurücksetzen.
func _ueber_laeufe() -> void:
	# alte Datei ohne Versionsnummer, mit fehlenden Feldern und Kommazahlen
	var alt := {"personen": [
		{"id": 3.0, "name": "Alt", "rang": 2.0, "art": "scharfschuetze"},
		{"id": 4, "name": "Kaputt", "rang": "zwei", "bilanz": "nix", "art": "panzer"},
		{"id": 5, "name": "Bezwinger", "rang": 1, "art": "technogunner", "zuletzt_erledigt": true, "bilanz": {"er": 1, "brakk": 0}},
		{"id": 6, "name": "Hart", "rang": 1, "art": "technogunner", "letzter_schaden": 400.0, "bilanz": {"er": 0, "brakk": 1}},
		{"id": 7, "name": "Schwach", "rang": 1, "art": "plasmawerfer", "bilanz": {"er": 0, "brakk": 3}},
		{"id": 8, "name": "Mittel", "rang": 2, "art": "plasmawerfer", "bilanz": {"er": 1, "brakk": 1}},
		{"name": ""}, 17,
	]}
	var f := FileAccess.open(Nemesis.datei, FileAccess.WRITE)
	f.store_string(JSON.stringify(alt))
	f.close()
	var m := Nemesis.new()
	m.o24 = o
	m.spiel = spiel
	m.laden()
	var namen := m.personen.map(func(p: Dictionary) -> String: return str(p["name"]))
	pruefe(m.personen.size() == 6 and m.erster_lauf, "Laden: alte Datei ohne Version (ohne die zwei unbrauchbaren) – %d Einträge (%s), gilt noch als erster Lauf" % [m.personen.size(), ", ".join(PackedStringArray(namen))])
	var kaputt: Dictionary = m.personen.filter(func(p: Dictionary) -> bool: return str(p["name"]) == "Kaputt")[0]
	pruefe(int(kaputt["rang"]) == 1 and str(kaputt["art"]) == "technogunner" and int((kaputt["bilanz"] as Dictionary)["er"]) == 0 and str(kaputt["beiname"]) == "",
		"Laden: kaputte Felder bekommen ihren Standard (Rang 1, Technogunner, Bilanz 0:0)")
	pruefe(m._naechste_id == 9, "Laden: neue Nummern ab %d" % m._naechste_id)
	# Ziehen zum Laufbeginn
	for p: Dictionary in m.personen:
		p["lauf"] = m._neuer_lauf(false)
	m._lauf_trupp_ziehen()
	var gezogen := m.personen.filter(func(p: Dictionary) -> bool: return bool((p["lauf"] as Dictionary)["erlaubt"]))
	var gn := gezogen.map(func(p: Dictionary) -> String: return str(p["name"]))
	var arten := {}
	for p: Dictionary in gezogen:
		arten[str(p["art"])] = true
	pruefe(gezogen.size() == Werte.NEMESIS_LAUF_TRUPP and gn.has("Bezwinger") and gn.has("Hart"), "Laufbeginn: %s – wer Brakk zuletzt erledigte und wer am härtesten traf, ist dabei" % ", ".join(PackedStringArray(gn)))
	pruefe(arten.size() >= 2, "Laufbeginn: möglichst verschiedene Truppenarten (%d)" % arten.size())
	# Verdrängen: 7 Benannte → der mit der schlechtesten Bilanz (Schwach, 0:3) wird versetzt; Neue sind geschützt
	var neu := m.neue_person("technogunner", 1, "Frisch", "Neuling")
	(neu["lauf"] as Dictionary)["neu"] = true
	m._verdraengen()
	var vn := m.versetzt.map(func(p: Dictionary) -> String: return str(p["name"]))
	pruefe(m.personen.size() == Werte.NEMESIS_LISTE_MAX and vn == ["Schwach"] and m.personen.has(neu), "Verdrängen: 7 → %d, versetzt: %s (schlechteste Bilanz), der Neue bleibt" % [m.personen.size(), ", ".join(PackedStringArray(vn))])
	# speichern, wieder laden: kein Appell mehr, Felder bleiben
	m.speichern()
	var m2 := Nemesis.new()
	m2.laden()
	pruefe(not m2.erster_lauf and m2.personen.size() == Werte.NEMESIS_LISTE_MAX and int(Nemesis._datei_lesen().get("version", 0)) == Nemesis.VERSION, "Speichern: Version %s, %d Benannte, Appell vergeben" % [str(Nemesis._datei_lesen().get("version", "?")), m2.personen.size()])
	pruefe(Nemesis.meistgesuchte().size() == Werte.NEMESIS_LISTE_MAX, "Tafel liest die Liste (%d)" % Nemesis.meistgesuchte().size())
	Nemesis.zuruecksetzen()
	pruefe(Nemesis.meistgesuchte().is_empty() and not FileAccess.file_exists(Nemesis.datei), "Zurücksetzen: Liste gelöscht")
	m.free()
	m2.free()


# ------------------------------------------------------------------ 22.11. (Teil 4): abgeschaute Angewohnheiten

## Zählen; kampfunfähig am Med-Kit → kommt mit „Med-Kit-Dieb“ zurück; knapp vertrieben beim Sabotieren → „Fabrikwache“.
func _gewohnheiten_abschauen() -> void:
	var g := n.gewohnheiten
	var vor := int(g.zaehler_lauf.get("klon", 0))
	o.brakk_gewohnheit("klon")
	pruefe(int(g.zaehler_lauf.get("klon", 0)) == vor + 1 and g.aktuell() == "klon", "Zähler: Klonmaschine gezählt, gerade in Gebrauch")
	g._zuletzt.clear()
	var p := n.neue_person("plasmawerfer", 3, "Abschau", "Lehrling")
	var e := truppe("plasmawerfer", 4, 2.0)
	n.einkleiden(e, p)
	merk["lehrling"] = p
	n.medkit()   # Brakk heilt gerade am Med-Kit …
	e.nimm_schaden(999999.0)   # … und schießt ihn dabei kampfunfähig
	pruefe(str(p["angewohnheit"]) == "medkit", "Abschauen: kampfunfähig geschossen, während Brakk heilt → %s" % NemesisGewohnheiten.name_von(str(p["angewohnheit"])))
	for kf: Dictionary in n.kampfunfaehig:
		kf["bis"] = o.zeit - 0.1
	g._zuletzt.clear()
	# knapp vertrieben, während Brakk sabotiert
	var q := n.neue_person("technogunner", 1, "Knapp", "Davon")
	var e2 := truppe("technogunner", 4, 3.0, 1.0)
	n.einkleiden(e2, q)
	n.schuss(e2)
	e2.leben = e2.max_leben * 0.2
	o.sabo = {"zelle": o.fabrik_hp.keys()[0], "t": 0.0, "leben": spiel.kommandant.leben}
	altern(e2)
	o.sabo = {}
	pruefe(str(q["angewohnheit"]) == "sabotage", "Abschauen: knapp vertrieben (20 %% Leben), während Brakk sabotiert → %s" % NemesisGewohnheiten.name_von(str(q["angewohnheit"])))


## Der Lehrling wird geborgen und ist in der nächsten Elitewelle wieder da – mit der abgeschauten Angewohnheit.
func _gewohnheiten_bergen() -> void:
	n._physics_process(0.0)
	var p: Dictionary = merk["lehrling"]
	pruefe(n.einheit_von(p) == null, "Lehrling geborgen")
	o._jagdwelle()
	var e := n.einheit_von(p)
	pruefe(e != null and n.gewohnheiten.hat(e, "medkit"), "Nächste Elitewelle: der Lehrling ist zurück – als Med-Kit-Dieb (gelernt von dir)")
	merk["lehrling_e"] = e


## Die Verhalten im Feld, die Laufende-Regel und das Lexikon.
func _gewohnheiten_feld() -> void:
	var g := n.gewohnheiten
	var k: Kommandant = spiel.kommandant
	# Med-Kit-Dieb: läuft zum Med-Kit und nimmt es weg
	var dieb: Einheit = merk.get("lehrling_e", null)
	if dieb != null and not o.medkits.is_empty():
		var m: Dictionary = o.medkits[0]
		m["da"] = true
		pruefe(g.marschziel(dieb) != Karte.KEINE, "Med-Kit-Dieb: sein Ziel ist das Med-Kit")
		dieb.position = o.karte.mitte(m["zelle"] as Vector2i)
		g.weiter(0.1)
		pruefe(not bool(m["da"]), "Med-Kit-Dieb: Med-Kit weggenommen")
	# Frontschild: von vorn 25 %, von hinten voll
	var fp := n.neue_person("technogunner", 1, "Schild", "Wand")
	fp["angewohnheit"] = "fern"
	var fe := truppe("technogunner", 4, 3.0)
	n.einkleiden(fe, fp)
	fe._sprite.flip_h = k.position.x < fe.position.x
	var vorn := g.schild_faktor(fe)
	fe._sprite.flip_h = not fe._sprite.flip_h
	var hinten := g.schild_faktor(fe)
	pruefe(absf(vorn - 0.25) < 0.01 and hinten == 1.0 and fe.get_node_or_null("Frontschild") != null, "Frontschild: von vorn %d %%, von hinten %d %% (Schild sichtbar)" % [roundi(vorn * 100.0), roundi(hinten * 100.0)])
	# Mauerkletterer: darf auf den Wall, auch nah an Brakk; +1,5 Reichweite oben
	var kp := n.neue_person("scharfschuetze", 1, "Kletter", "Affe")
	kp["angewohnheit"] = "klettern"
	var ke := truppe("scharfschuetze", 4, 1.5)
	n.einkleiden(ke, kp)
	o._neuer_trupp([ke], "jagd")
	pruefe(o.darf_in_stellung(ke) and absf(float(ke.get_meta("wall_reichweite", 0.0)) - 1.5) < 0.01, "Mauerkletterer: darf als Jäger nah an Brakk auf den Wall, oben +1,5 Reichweite")
	# Doppelgänger: kommt mit einem flackernden Doppelgänger (halbes Leben)
	var dp := n.neue_person("technogunner", 4, "Zwilling", "Echo")
	dp["angewohnheit"] = "klon"
	var de := truppe("technogunner", 4, 4.0)
	n.einkleiden(de, dp)
	var d := g.doppelgaenger(de, dp, o.fabrik_hp.keys()[0])
	pruefe(d != null and absf(d.max_leben - de.max_leben * 0.5) < 0.5 and n.person_von(d).is_empty() and bool(d.get_meta("nemesis_doppel", false)), "Doppelgänger: halbes Leben, kein Name, flackert")
	# Fallensteller: legt an Brakks Lieblingsdeckung eine piepende Falle
	var sp := n.neue_person("plasmawerfer", 1, "Falle", "Pieps")
	sp["angewohnheit"] = "sprengen"
	var se := truppe("plasmawerfer", 4, 2.0)
	n.einkleiden(se, sp)
	var lieblings := o.karte.zelle_bei(k.position)
	g.deckung = {lieblings: 12.0}
	se.position = o.karte.mitte(lieblings) + Vector2(Werte.ZELLE * 0.5, 0)
	var bg: BrakkGeschosse = spiel.brakk_geschosse
	var vorher := bg.wuerfe.size()
	g.weiter(0.1)
	var falle := bg.wuerfe.size() > vorher and bool((bg.wuerfe.back() as Dictionary).get("falle", false))
	pruefe(falle and absf(float((bg.wuerfe.back() as Dictionary)["flug"]) - Werte.NEMESIS_FALLE_ZUENDER) < 0.01, "Fallensteller: Falle an der Lieblingsdeckung (3 s Zünder)")
	bg.leeren()
	# Doppelblitz gegen Tumble: Brakk tumblet beim ersten Blitz – der verzögerte Schuss trifft trotzdem, ein normaler nicht
	var tp := n.neue_person("technogunner", 1, "Blitz", "Zweimal")
	tp["angewohnheit"] = "tumble"
	var te := truppe("technogunner", 4, 4.0)
	n.einkleiden(te, tp)
	var ne := truppe("technogunner", 4, 4.0, 2.0)
	merk["uhr"] = 0.0
	merk["treffer"] = 0
	merk["erster"] = -1.0
	merk["tumble_ab"] = 99.0   # Tumble-Fenster [tumble_ab, tumble_ab + 0,25 s]
	var bp := k.position
	bg.ziel_fn = func() -> Dictionary:
		var t := float(merk["uhr"])
		return {"pos": bp, "sprung": 0.0, "fuss": 0.0, "durchlass": t >= float(merk["tumble_ab"]) and t < float(merk["tumble_ab"]) + Werte.BRAKK_TUMBLE_DURCHLASS, "v": Vector2.ZERO}
	bg.treffer_fn = func(_m: float, _t: String) -> void:
		merk["treffer"] = int(merk["treffer"]) + 1
		if float(merk["erster"]) < 0.0:
			merk["erster"] = float(merk["uhr"])
	var schiessen := func(wer: Einheit) -> void:
		merk["treffer"] = 0
		merk["erster"] = -1.0
		merk["uhr"] = 0.0
		wer._auf_brakk({"flaeche": false, "muendung": wer.position, "start": wer.position}, 10.0)
		while float(merk["uhr"]) < 2.0:
			bg.weiter(1.0 / 60.0)
			merk["uhr"] = float(merk["uhr"]) + 1.0 / 60.0
	# wann schlägt ein normaler Schuss ein? Brakk tumblet im letzten Moment: 0,1 s davor
	schiessen.call(ne)
	var einschlag := float(merk["erster"])
	merk["tumble_ab"] = einschlag - 0.1
	var quote: Array[int] = []
	for wer: Einheit in [te, ne]:
		var mit := 0
		for i in 10:
			schiessen.call(wer)
			if int(merk["treffer"]) > 0:
				mit += 1
		quote.append(mit)
	bg.ziel_fn = Callable()
	bg.treffer_fn = Callable()
	print("     Doppelblitz: Brakk tumblet 0,1 s vor dem gewohnten Einschlag (%.2f s) – Doppelblitz trifft %d/10, normaler Schuss %d/10" % [einschlag, quote[0], quote[1]])
	pruefe(quote[0] >= 8 and quote[1] <= 2, "Doppelblitz: der Schuss fällt nach dem Tumble-Fenster")
	# Laufende: wer keine hat, übernimmt Brakks häufigste – wenn überdurchschnittlich oft
	var leer := n.neue_person("technogunner", 1, "Leer", "Ohne")
	var alt_z := g.zaehler.duplicate()
	g.zaehler = {"klettern": 1, "sprengen": 1, "tumble": 6, "klon": 0, "sabotage": 1, "medkit": 1, "fern": 0}
	g.lauf_ende()
	pruefe(str(leer["angewohnheit"]) == "tumble", "Laufende: ohne Angewohnheit übernimmt er Brakks häufigste (%s)" % NemesisGewohnheiten.name_von(str(leer["angewohnheit"])))
	leer["angewohnheit"] = ""
	g.zaehler = {"klettern": 2, "sprengen": 2, "tumble": 2, "klon": 2, "sabotage": 2, "medkit": 2, "fern": 2}
	g.lauf_ende()
	pruefe(str(leer["angewohnheit"]) == "", "Laufende: nichts überdurchschnittlich – keine Übernahme")
	g.zaehler = alt_z
	# Rang 4: zwei Angewohnheiten
	var r4 := n.neue_person("scharfschuetze", 4, "Alt", "Hase")
	r4["angewohnheit"] = "klettern"
	g._zuletzt = {"medkit": o.zeit}
	g.abschauen(r4, "Test")
	pruefe(NemesisGewohnheiten.von_person(r4) == ["klettern", "medkit"], "Rang 4: zwei Angewohnheiten (%s)" % ", ".join(PackedStringArray(NemesisGewohnheiten.von_person(r4))))
	# Lexikon: gesehene mit Konter, der Rest „???“
	var karte := NemesisGewohnheiten.lexikon_karte(g.gesehen)
	var titel := (karte["abschnitte"] as Array).map(func(a: Array) -> String: return str(a[0]))
	pruefe(titel.has("Med-Kit-Dieb") and titel.has("Frontschild") and titel.has("???") == (g.gesehen.size() < 7), "Lexikon: %s" % ", ".join(PackedStringArray(titel)))
	for x: Variant in [leer, r4, dp, kp, fp, sp, tp]:
		n.personen.erase(x)


# ------------------------------------------------------------------ 22.11. (Teil 5): Lernen

## Zehn gestellte Begegnungen: die Flanke bringt Schaden an Brakk, alles andere kostet – die Werte verschieben sich dorthin.
func _lernen_zehn() -> void:
	var l := n.lernen
	var k: Kommandant = spiel.kommandant
	var p := n.neue_person("technogunner", 1, "Lern", "Begierig")
	var e := truppe("technogunner", 4, 4.0)
	n.einkleiden(e, p)
	var gewaehlt := {}
	for i in 10:
		var t := l.waehlen(p)
		gewaehlt[t] = int(gewaehlt.get(t, 0)) + 1
		var b := {"taktik": t, "an_brakk": k.max_leben * 0.15 if t == "flanke" else k.max_leben * 0.02, "erlitten": e.max_leben * (0.1 if t == "flanke" else 0.6)}
		l.begegnung_ende(e, p, b)
	var d := NemesisLernen.werte(p)
	var q: Dictionary = d["q"]
	var txt := PackedStringArray()
	for t: String in Werte.NEMESIS_TAKTIKEN:
		txt.append("%s %.1f (%d×)" % [t, float(q[t]), int((d["n"] as Dictionary)[t])])
	print("     Taktikwerte nach 10 Begegnungen: %s" % ", ".join(txt))
	pruefe(NemesisLernen.beste(p) == "flanke" and int(gewaehlt.get("flanke", 0)) >= 5, "Lernen: nach zehn Begegnungen bevorzugt er die erfolgreiche Taktik (Flanke %d von 10)" % int(gewaehlt.get("flanke", 0)))
	pruefe(int(gewaehlt.size()) == 4, "Lernen: UCB probiert zuerst jede Taktik einmal")
	n.speichern()
	var gesp: Dictionary = {}
	for x: Variant in (Nemesis._datei_lesen().get("personen", []) as Array):
		if str((x as Dictionary).get("name", "")) == "Lern":
			gesp = x
	pruefe(not gesp.is_empty() and (gesp.get("taktik", {}) as Dictionary).has("q"), "Lernen: die Werte gehören zur Person und werden gespeichert")
	merk["lern_e"] = e


## Erkennbares Verhalten je Taktik.
func _lernen_verhalten() -> void:
	var l := n.lernen
	var k: Kommandant = spiel.kommandant
	o.bekannt = o.karte.zelle_bei(k.position)
	var bp := o.karte.mitte(o.bekannt)
	var e: Einheit = merk["lern_e"]
	var id := e.get_instance_id()
	e.position = bp + Vector2(5.0 * Werte.ZELLE, 0)
	# Flanke: Ziel liegt seitlich, nicht auf der Linie zu Brakk
	l._taktik[id] = {"t": "flanke", "seite": 1.0, "fertig": false}
	var fz := l.marschziel(e)
	var quer := absf((o.karte.mitte(fz) - bp).normalized().dot((e.position - bp).normalized())) if fz != Karte.KEINE else 1.0
	pruefe(fz != Karte.KEINE and quer < 0.75 and l.drueckt(e), "Flanke: läuft im Bogen über einen Punkt seitlich von Brakk (schießt im Gehen)")
	# Hinterhalt: wartet an Med-Kit, Ringterminal oder Fabrik
	l._taktik[id] = {"t": "hinterhalt", "seite": 1.0, "fertig": false}
	e.position = bp + Vector2(12.0 * Werte.ZELLE, 0)
	var hz := l.marschziel(e)
	pruefe(hz != Karte.KEINE and hz == o._erreichbar_nahe(l.hinterhalt_ort(e), o.karte.zelle_bei(e.position)) and not l.drueckt(e), "Hinterhalt: geht an seinen Wartepunkt (%s)" % str(l.hinterhalt_ort(e)))
	# Sperrfeuer: zu nah → weicht zurück
	l._taktik[id] = {"t": "sperrfeuer", "seite": 1.0, "fertig": false}
	e.position = bp + Vector2(1.0 * Werte.ZELLE, 0)
	var sz := l.marschziel(e)
	pruefe(sz != Karte.KEINE and o.karte.mitte(sz).distance_to(bp) > e.position.distance_to(bp) and l.drueckt(e), "Sperrfeuer: zu nah – weicht zurück und schießt dabei")
	e.position = bp + Vector2(e.reichweite_jetzt() * Werte.ZELLE, 0)
	pruefe(l.marschziel(e) == o.karte.zelle_bei(e.position), "Sperrfeuer: am Rand der Reichweite bleibt er stehen")
	# direkt: rückt im Gehen schießend nach
	l._taktik[id] = {"t": "direkt", "seite": 1.0, "fertig": false}
	pruefe(l.marschziel(e) == Karte.KEINE and l.drueckt(e), "Direkt: geht mit dem Trupp drauf, schießt im Gehen")
	# Aufenthaltskarte: an den häufigsten Orten suchen, Kill-Felder meiden; einfache Truppen wie bisher
	var mitte := o.bekannt
	var gefahr := mitte + Vector2i(2, 0)
	var lieb := mitte + Vector2i(-2, 1)
	for z: Vector2i in [gefahr, lieb]:
		if not o.karte.ist_begehbar(z):
			pass
	l.aufenthalt = {gefahr: 40.0, lieb: 25.0, mitte: 5.0}
	l.kill_orte = {gefahr: 3}
	l._such.clear()
	o._neuer_trupp([e], "suche")
	var t: Dictionary = o.trupps.back()
	t["zuletzt"] = mitte
	var sz2 := l.suchziel(e, t)
	pruefe(sz2 != Karte.KEINE and Vector2(sz2 - gefahr).length() > 1.5, "Suche: Elite sucht an Brakks häufigen Orten und meidet sein Kill-Feld (Ziel %s)" % str(sz2))
	var einfach := truppe("technogunner", 1, 6.0)
	pruefe(l.suchziel(einfach, t) == Karte.KEINE, "Suche: einfache Truppen suchen wie bisher")


## Zusammenspiel der Fähigkeiten und Antwort auf den Spielstil.
func _lernen_trupp() -> void:
	var fa := n.faehigkeiten
	var l := n.lernen
	var k: Kommandant = spiel.kommandant
	var mp := n.neue_person("scharfschuetze", 1, "Auge", "Zuerst")
	mp["faehigkeit"] = "markierung"
	var me := truppe("scharfschuetze", 4, 5.0, 1.0)
	n.einkleiden(me, mp)
	var sp := n.neue_person("technogunner", 1, "Sturm", "Danach")
	sp["faehigkeit"] = "sturmlauf"
	var se := truppe("technogunner", 4, 5.0, -1.0)
	n.einkleiden(se, sp)
	o._neuer_trupp([me, se], "jagd")
	var nr := o.trupps.size() - 1
	var z := {"pos": k.position, "v": Vector2.ZERO}
	fa._eroeffnet.erase(nr)
	fa._wartet.erase(se.get_instance_id())
	var vorher := fa.darf_jetzt(se, "sturmlauf", z)
	fa._eroeffnet[nr] = fa._zeit
	var nachher := fa.darf_jetzt(se, "sturmlauf", z)
	pruefe(not vorher and nachher, "Zusammenspiel: Sturmlauf erst nach der Markierung im Trupp")
	var weg := (k.position - se.position).normalized() * 2.0 * Werte.ZELLE
	pruefe(fa.darf_jetzt(se, "sperrbrand", {"pos": k.position, "v": weg}) and not fa.darf_jetzt(se, "sperrbrand", {"pos": k.position, "v": -weg}), "Zusammenspiel: Sperrbrand nur auf Brakks Rückweg")
	# Spielstil: Saboteur → Fabrikwache mit Ansage
	var alt_sab := o.sabotage.duplicate()
	o.sabotage["fabriken"] = 3
	l.stil = ""
	l.stil_pruefen()
	var ansage: Variant = l.protokoll.filter(func(x: Dictionary) -> bool: return str(x.get("was", "")) == "ansage").back() if not l.protokoll.is_empty() else {}
	pruefe(l.stil == "Saboteur" and l.wache_id > 0 and str((ansage as Dictionary).get("text", "")).contains("übernimmt die Fabrik"), "Spielstil Saboteur: %s" % str((ansage as Dictionary).get("text", "?")))
	var wache := instance_from_id(l.wache_id) as Einheit
	if wache != null:
		pruefe(l.marschziel(wache) != Karte.KEINE, "Spielstil Saboteur: die Wache geht zur gefährdetsten Fabrik")
	# Berserker: einer vorn, zwei dahinter
	o.sabotage = alt_sab
	o.sabotage["fabriken"] = 0
	o.sabotage["sabotiert"] = 0
	o.sabotage["waelle"] = 0
	o.deckung_sek = 0.0
	l.stil_pruefen()
	pruefe(l.stil == "Berserker", "Spielstil Berserker erkannt")
	l.wache_id = -1
	o.bekannt = o.karte.zelle_bei(k.position)
	var bz := l.marschziel(se)
	var hinter := bz != Karte.KEINE and o.karte.mitte(bz).distance_to(k.position) > me.position.distance_to(k.position)
	pruefe(hinter, "Spielstil Berserker: der zweite geht hinter dem ersten (Ziel %s)" % str(bz))
	o.sabotage = alt_sab
	l.stil = ""
