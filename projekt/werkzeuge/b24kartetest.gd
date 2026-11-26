extends SceneTree
## E (26.11., Paul): Befehl 24 auf der eigenen großen Karte (befehl24_gross, ORDER24_KARTE), headless:
##
##   godot --headless --path . --fixed-fps 60 -s werkzeuge/b24kartetest.gd            (große Karte, alle Prüfungen)
##   godot --headless --path . --fixed-fps 60 -s werkzeuge/b24kartetest.gd -- alt     (nur Tempo auf szenario_order24, 28×14)
##
## Tempo: 60 s Spielzeit im Schnelllauf, gemessen als Bilder je echter Sekunde (headless: Rechenzeit, nicht die Grafik).
## Schreibt nur user://nemesis_b24test.json. Am Ende „TEST B24 OK“ oder die Fehler.

var spiel: Node
var o: Order24
var warte := 10
var schritt := 0
var fehler: Array[String] = []
var geprueft := 0
var alt := false
var vorstoss := false   # -- vorstoss: misst, wann der Vorstoß-Trupp das Myriaden-HQ erreicht
var t_start := 0
var bilder := 0


func _initialize() -> void:
	alt = OS.get_cmdline_user_args().has("alt")
	vorstoss = OS.get_cmdline_user_args().has("vorstoss")
	Nemesis.datei = "user://nemesis_b24test.json"
	Nemesis.zuruecksetzen()
	var name := "szenario_order24" if alt else Werte.ORDER24_KARTE_NAME
	OS.set_environment("TD_KARTE_NAME", name)
	Werte.lade_karte(name)
	var r: Dictionary = (Werte.KARTE_REGELN.get("order24", {}) as Dictionary).duplicate()
	r["brakk_schaden"] = 0
	r["geheim_ab"] = 0
	r["herausforderer"] = false
	Order24.test_werte = r
	var main_skript: GDScript = load("res://scripts/main.gd")
	main_skript.set("naechster_start", "normal")
	spiel = load("res://main.tscn").instantiate()
	root.add_child(spiel)
	spiel.protokoll_an = false


func pruefe(ok: bool, text: String) -> void:
	geprueft += 1
	print("%s %s" % ["OK  " if ok else "FEHL", text])
	if not ok:
		fehler.append(text)


func _fertig() -> bool:
	Nemesis.zuruecksetzen()
	if fehler.is_empty():
		print("TEST B24 OK (%d Prüfungen)" % geprueft)
	else:
		print("TEST B24 FEHLER (%d): %s" % [fehler.size(), "; ".join(PackedStringArray(fehler))])
	quit(0 if fehler.is_empty() else 1)
	return true


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
	var k: Kommandant = spiel.kommandant
	k.leben = k.max_leben
	if vorstoss:
		return _e6_vorstoss()
	match schritt:
		0:
			if not alt:
				_e1_aufbau()
				_e2_gebiete()
				_e3_formationen()
				_e4_zufluchten()
				_e7_kampfplatz()
			Engine.time_scale = 4.0   # Schnelllauf
			t_start = Time.get_ticks_msec()
			zwanzig_ab = o.zeit
			bilder = 0
			schritt = 1
		1:
			bilder += 1
			if not alt:
				_e4_zwanzig()
			if o.zeit >= 62.0:
				var echt := (Time.get_ticks_msec() - t_start) / 1000.0
				Engine.time_scale = 1.0
				print("TEMPO %s: %d Bilder in %.1f s echter Zeit = %.0f Bilder/s (60 s Spielzeit, %d Truppen)" % ["28×14" if alt else "%d×%d" % [Werte.SPALTEN, Werte.ZEILEN], bilder, echt, bilder / maxf(0.01, echt), o._truppen().size()])
				pruefe(o.laeuft and not o.vorbei, "60 s Befehl 24 ohne Abbruch")
				return _fertig()
	return false


# ------------------------------------------------------------------ E1: Größe und Lage

func _e1_aufbau() -> void:
	var karte: Karte = o.karte
	pruefe(Werte.SPALTEN == Werte.ORDER24_KARTE.x and Werte.ZEILEN == Werte.ORDER24_KARTE.y and bool(o.w("gebiete")), "E1: Befehl 24 auf %d×%d (Regel gebiete)" % [Werte.SPALTEN, Werte.ZEILEN])
	pruefe(karte.basis.x >= Werte.SPALTEN - 3 and Werte.START_ZELLE.x == 0, "E1: Myriaden im Westen (%s), Technoclan-HQ im Osten (%s)" % [str(Werte.START_ZELLE), str(karte.basis)])
	var aussen := o.fabrik_hp.keys()
	var ohne_weg := aussen.filter(func(z: Vector2i) -> bool: return karte.einheiten_weg(karte.freier_nachbar(z), Werte.ANGRIFFS_ZELLE + Vector2i(2, 0)).is_empty())
	pruefe(not aussen.is_empty() and ohne_weg.is_empty(), "E1: von jedem der %d Lager ein Weg zum Myriaden-HQ (ohne: %s)" % [aussen.size(), str(ohne_weg)])
	var waelle := karte.feld.keys().filter(func(z: Vector2i) -> bool: return karte.inhalt(z) == Karte.WALL)
	var drausen := waelle.filter(func(z: Vector2i) -> bool: return not karte.in_karte(z))
	pruefe(waelle.size() > 20 and drausen.is_empty(), "E1: Formation auf der Karte (%d Wälle)" % waelle.size())


# ------------------------------------------------------------------ E2: Gebiete

func _e2_gebiete() -> void:
	var karte: Karte = o.karte
	var lager := {}
	for z: Vector2i in o.fabrik_hp:
		var g := BrakkGebiete.gebiet(z)
		lager[g] = int(lager.get(g, 0)) + 1
	pruefe(int(lager.get("guertel", 0)) == 2 and int(lager.get("aussen_oben", 0)) == 1 and int(lager.get("aussen_unten", 0)) == 1, "E2: Lager je Gebiet %s (Soll Gürtel 2, Außenposten je 1)" % str(lager))
	var stell_falsch: Array = []
	for z: Vector2i in o.fabrik_hp:
		var n := 0
		for dy in range(-3, 4):
			for dx in range(-3, 4):
				if karte.ausbau.get(z + Vector2i(dx, dy), -1) == Karte.STELLUNG:
					n += 1
		var soll := BrakkGebiete.stellungen(BrakkGebiete.gebiet(z))
		if n < soll or o.truppen_limit(z) != soll + BrakkGebiete.streife(BrakkGebiete.gebiet(z)):
			stell_falsch.append([z, BrakkGebiete.gebiet(z), n])
	pruefe(stell_falsch.is_empty(), "E2: Stellungen und Streife je Lager wie im Gebiet (Gürtel 4+2, Außenposten 3+1; falsch: %s)" % str(stell_falsch))
	var tuerme := {}
	for z: Vector2i in karte.ausbau:
		if karte.ausbau[z] == Karte.TURM:
			var g := BrakkGebiete.gebiet(z)
			tuerme[g] = int(tuerme.get(g, 0)) + 1
	pruefe(not tuerme.has("niemandsland") and not tuerme.has("myriaden") and int(tuerme.get("guertel", 0)) >= 6 and int(tuerme.get("aussen_oben", 0)) >= 1 and int(tuerme.get("aussen_unten", 0)) >= 1,
		"E2: Türme je Gebiet %s (Formtürme im Gürtel, je ein Geschützturm in den Außenposten, Niemandsland frei)" % str(tuerme))
	var heil := 0
	for z: Vector2i in karte.turm_art:
		if karte.turm_art[z] == "heil" and karte.ausbau.get(z, -1) == Karte.TURM and BrakkGebiete.gebiet(z) == "guertel":
			heil += 1
	pruefe(heil >= int(o.w("heiltuerme")), "E2: %d Heilturm im Gürtel (Soll %d; wird zuerst gesetzt)" % [heil, int(o.w("heiltuerme"))])
	var innen: Array = spiel.fabriken.keys().filter(func(z: Vector2i) -> bool: return BrakkGebiete.gebiet(z) == "schild" and not o.fabrik_hp.has(z) and str(spiel.fabriken[z]["typ"]) != "pilot")
	pruefe(innen.size() >= 3, "E2: %d Innenfabriken im Schild" % innen.size())
	o.gebiet_zaehlen("kills", 1.0)
	var g0 := BrakkGebiete.gebiet(karte.zelle_bei(spiel.kommandant.position))
	pruefe(o.gebiet_zahlen.has(g0) and o.bericht(true).has("gebiete"), "E2: Kills je Gebiet im Bericht (Brakk steht in „%s“)" % g0)


# ------------------------------------------------------------------ E3: Formationen _b24

func _e3_formationen() -> void:
	var karte: Karte = o.karte
	var dateien := Werte.ALARM_FORMATIONEN.filter(func(f: String) -> bool: return FileAccess.file_exists(BrakkGebiete.ORDNER_B24 + f + "_b24.json"))
	var passend := dateien.filter(func(f: String) -> bool: return (BrakkGebiete.plan_laden(f) as Array).size() == Werte.ZEILEN and str(BrakkGebiete.plan_laden(f)[0]).length() == Werte.SPALTEN)
	pruefe(dateien.size() == Werte.ALARM_FORMATIONEN.size() and passend.size() == dateien.size(), "E3: %d _b24-Dateien, alle %d×%d" % [dateien.size(), Werte.SPALTEN, Werte.ZEILEN])
	var zahl := {}
	for z: Vector2i in karte.feld:
		if karte.inhalt(z) == Karte.WALL:
			var g := BrakkGebiete.gebiet(z)
			zahl[g] = int(zahl.get(g, 0)) + 1
	pruefe(int(zahl.get("niemandsland", 0)) >= 3 and int(zahl.get("niemandsland", 0)) <= 12 and int(zahl.get("aussen_oben", 0)) >= 4 and int(zahl.get("aussen_unten", 0)) >= 4 and int(zahl.get("guertel", 0)) > 20,
		"E3: Wälle je Gebiet %s (Niemandsland Trümmer, Außenposten T-Stück + Lager, Gürtel Formation)" % str(zahl))
	var p1 := BrakkGebiete.plan_b24("2-kamm")
	var p2 := BrakkGebiete.plan_b24("2-kamm")
	pruefe(p1 == p2 and p1 != BrakkGebiete.plan_b24("3-zitadelle"), "E3: Trümmer aus einem Hash – je Formation immer gleich")


# ------------------------------------------------------------------ E4: Zufluchten

func _brakk_auf(z: Vector2i) -> void:
	var k: Kommandant = spiel.kommandant
	k.oben = false
	spiel.ego.hoehe = 0.0
	spiel.ego._setze_fuss(o.karte.mitte(z))


func _e4_zufluchten() -> void:
	var zf := o.zuflucht
	var karte: Karte = o.karte
	var k: Kommandant = spiel.kommandant
	var bg: BrakkGeschosse = spiel.brakk_geschosse
	var namen := zf.orte.map(func(x: Dictionary) -> String: return str(x["name"]))
	namen.sort()
	var fels := karte.gelaende.keys().filter(func(z: Vector2i) -> bool: return karte.ist_fels(z)).size()
	pruefe(namen == ["absatz_oben", "absatz_unten", "hoehle"] and fels >= 20, "E4: drei Zufluchten %s, %d Felsen" % [str(namen), fels])
	var depots := zf.orte.all(func(x: Dictionary) -> bool: return o.medkits.any(func(m: Dictionary) -> bool: return str(m.get("zuflucht", "")) == str(x["name"])) and o.ladungen_boden.any(func(l: Dictionary) -> bool: return str(l.get("zuflucht", "")) == str(x["name"])))
	var eingaenge := zf.orte.all(func(x: Dictionary) -> bool: return (x["eingang"] as Vector2i) != Karte.KEINE and not karte.einheiten_weg(x["eingang"] as Vector2i, Werte.ANGRIFFS_ZELLE + Vector2i(2, 0)).is_empty())
	pruefe(depots and eingaenge, "E4: je Ort Medkit und Sprengladung, Eingang erreichbar")
	var keine_bauten := zf.orte.all(func(x: Dictionary) -> bool: return (x["felder"] as Array).all(func(z: Vector2i) -> bool: return karte.ist_frei(z)))
	pruefe(keine_bauten, "E4: in den Zufluchten steht nichts")
	# Türme und Stellungen zielen nicht hinein, Bodentruppen schon
	var ort: Dictionary = zf.orte.filter(func(x: Dictionary) -> bool: return str(x["name"]) == "absatz_oben")[0]
	_brakk_auf((ort["felder"] as Array)[0])
	var turm := karte.ausbau.keys().filter(func(z: Vector2i) -> bool: return karte.ausbau[z] == Karte.TURM)[0] as Vector2i
	var stellung := karte.ausbau.keys().filter(func(z: Vector2i) -> bool: return karte.ausbau[z] == Karte.STELLUNG)[0] as Vector2i
	bg.leeren()
	bg.turm(turm, karte.mitte(turm), "lanze", 10.0, 30.0 * Werte.ZELLE, 0.3 * Werte.ZELLE, 1, "test")
	bg.schiesse("laser", karte.mitte(stellung), 1.5, 10.0, "technogunner", "test")
	bg.scharf(null, karte.mitte(stellung), 1.5, 30.0 * Werte.ZELLE, 10.0, "test")
	var gesperrt := bg.gluehen.is_empty() and bg.geschosse.is_empty() and bg.zielstrahlen.is_empty()
	bg.schiesse("laser", karte.mitte(karte.freier_nachbar(stellung)), 0.5, 10.0, "technogunner", "test")
	pruefe(gesperrt and bg.geschosse.size() == 1 and zf.hud_zeile().begins_with("Zuflucht"), "E4: in der Zuflucht schießen Turm und Stellung nicht, Bodentruppen schon; HUD „%s“" % zf.hud_zeile())
	bg.leeren()
	# 20 s im Spiel: kein Turmstrahl, keine Stellung zielt auf ihn
	merk_turm = 0
	merk_ort = ort
	# Camping: Warnung bei 25 s, Rücklauf draußen, Umformen bei 40 s
	zf.weiter(Werte.ZUFLUCHT_WARNUNG_SEK - 0.1, k)
	var vor_warnung := bool(ort["gewarnt"])
	zf.weiter(0.2, k)
	var warnung := bool(ort["gewarnt"])
	_brakk_auf(ort["eingang"] as Vector2i + Vector2i(-2, 0))
	var uhr := float(ort["uhr"])
	zf.weiter(4.0, k)
	var ruecklauf := uhr - float(ort["uhr"])
	pruefe(not vor_warnung and warnung and absf(ruecklauf - 4.0 * Werte.ZUFLUCHT_RUECKLAUF) < 0.01, "E4: Warnung bei %.0f s, draußen läuft die Uhr halb so schnell zurück (%.1f s in 4 s)" % [Werte.ZUFLUCHT_WARNUNG_SEK, ruecklauf])
	# Medkit- und Ladungstakt
	var mk: Dictionary = o.medkits.filter(func(m: Dictionary) -> bool: return str(m.get("zuflucht", "")) == str(ort["name"]))[0]
	mk["da"] = false
	var ld: Dictionary = o.ladungen_boden.filter(func(l: Dictionary) -> bool: return str(l.get("zuflucht", "")) == str(ort["name"]))[0]
	o._ladung_weg(ld)
	zf.weiter(o.wf("medkit_takt") - 1.0, k)
	var mk_frueh := bool(mk["da"])
	zf.weiter(1.5, k)
	var mk_da := bool(mk["da"])
	zf.weiter(Werte.ZUFLUCHT_LADUNG_SEK - o.wf("medkit_takt") + 0.5, k)
	var ld_da := o.ladungen_boden.any(func(l: Dictionary) -> bool: return str(l.get("zuflucht", "")) == str(ort["name"]))
	pruefe(not mk_frueh and mk_da and ld_da, "E4: Medkit nach %d s, Sprengladung nach %d s wieder da" % [int(o.w("medkit_takt")), int(Werte.ZUFLUCHT_LADUNG_SEK)])
	_brakk_auf((ort["felder"] as Array)[1])
	ort["uhr"] = Werte.ZUFLUCHT_VERLUST_SEK - 0.1
	var fabriken_vor := o.fabrik_hp.size()
	zf.weiter(0.2, k)
	for i in 40:
		zf.weiter(0.1, k)
	var lager: Variant = ort.get("fabrik", null)
	var turm_da := (zf.umbau(ort)[1][1] as Array)[0] as Vector2i
	var stell := zf.umbau(ort).filter(func(t: Array) -> bool: return t[0] == "stellung").filter(func(t: Array) -> bool: return karte.ausbau.get((t[1] as Array)[0], -1) == Karte.STELLUNG).size()
	pruefe(bool(ort["verloren"]) and not zf.protokoll.filter(func(x: Dictionary) -> bool: return str(x["was"]) == "zuflucht_verloren").is_empty() and o.fabrik_hp.size() == fabriken_vor + 1 and lager != null and o.routen.has(lager)
		and karte.ausbau.get(turm_da, -1) == Karte.TURM and stell == 2,
		"E4: nach %.0f s ein Lager – Fabrik, Geschützturm, %d Stellungen" % [Werte.ZUFLUCHT_VERLUST_SEK, stell])
	var weg := not o.medkits.any(func(m: Dictionary) -> bool: return str(m.get("zuflucht", "")) == str(ort["name"])) and not o.ladungen_boden.any(func(l: Dictionary) -> bool: return str(l.get("zuflucht", "")) == str(ort["name"]))
	pruefe(weg and zf.ort_bei((ort["felder"] as Array)[0]).is_empty() and not zf.brakk_drin(), "E4: Zuflucht-Flag aus, Depot und Kasten weg, Brakk zum Eingang geschoben")
	_brakk_auf(Werte.ANGRIFFS_ZELLE + Vector2i(3, 0))


var merk_turm := 0
var merk_ort := {}


## E4: 20 s Spielzeit steht Brakk im unteren Felsabsatz – kein Turm glüht für ihn, keine Stellung zielt auf ihn.
var zwanzig_ab := 0.0
var zwanzig := [0, 0, false]   # Bilder mit Turm- oder Stellungsschuss, Bilder drin, schon geprüft

func _e4_zwanzig() -> void:
	if bool(zwanzig[2]) or o.zuflucht == null:
		return
	var bg: BrakkGeschosse = spiel.brakk_geschosse
	var orte := o.zuflucht.orte.filter(func(x: Dictionary) -> bool: return str(x["name"]) == "absatz_unten" and not bool(x["verloren"]))
	if orte.is_empty():
		return
	var ort: Dictionary = orte[0]
	ort["uhr"] = 0.0   # hier geht es nur ums Zielen, nicht ums Umformen
	if o.zeit - zwanzig_ab < 20.0:
		_brakk_auf((ort["felder"] as Array)[1])
		if o.brakk_in_zuflucht():
			zwanzig[1] = int(zwanzig[1]) + 1
		var aus_wall := bg.geschosse.any(func(g: Dictionary) -> bool: return o.karte.inhalt(o.karte.zelle_bei(g["von"] as Vector2)) == Karte.WALL and not g.has("lenk")) \
			or bg.zielstrahlen.any(func(s: Dictionary) -> bool: return o.karte.inhalt(o.karte.zelle_bei(s["von"] as Vector2)) == Karte.WALL)
		if not bg.gluehen.is_empty() or aus_wall:
			zwanzig[0] = int(zwanzig[0]) + 1
		return
	zwanzig[2] = true
	pruefe(int(zwanzig[0]) == 0 and int(zwanzig[1]) > 20 * 50, "E4: 20 s im Felsabsatz – %d Bilder drin, %d mit Turm- oder Stellungsschuss" % [int(zwanzig[1]), int(zwanzig[0])])
	_brakk_auf(Werte.ANGRIFFS_ZELLE + Vector2i(3, 0))


## E6: Ab vorstoss_start marschiert ein Jagdtrupp auf das Myriaden-HQ – kommt er auf der großen Karte vor 10:30 an?
## Die Uhr springt auf 470 s; Brakk steht unverwundbar abseits im Schild-Gebiet, damit niemand aufgehalten wird.
var v_an := -1.0

func _e6_vorstoss() -> bool:
	var k: Kommandant = spiel.kommandant
	k.unverwundbar = 9.0
	if schritt == 0:
		o.zeit = 470.0
		schritt = 1
		print("     Karte %s, Vorstoß ab %.0f s" % [str(Werte.ORDER24_KARTE), o.wf("vorstoss_start")])
		return false
	k.oben = false
	spiel.ego._setze_fuss(o.karte.mitte(o._freies_feld_bei(o.karte.mitte(Vector2i(Werte.SPALTEN - 8, 1)), Vector2i(Werte.SPALTEN - 8, 1))))
	if v_an < 0.0 and o.vorstoss_anteil > 0.0:
		v_an = o.zeit
		pruefe(v_an <= 630.0, "E6: der Vorstoß-Trupp erreicht das Myriaden-HQ bei %d:%02d (Soll vor 10:30)" % [int(v_an) / 60, int(v_an) % 60])
		return _fertig()
	if o.zeit > 700.0 or o.vorbei:
		pruefe(false, "E6: bis 11:40 kein Vorstoß-Trupp am Myriaden-HQ")
		return _fertig()
	return false


# ------------------------------------------------------------------ E7: Kampfplatz

func _e7_kampfplatz() -> void:
	var kp := o.herausforderer.kampfplatz
	var zf := o.zuflucht
	var brakk := Vector2i(24, Werte.ZEILEN / 2)   # Brakk im Gürtel
	var m := kp.mitte_suchen(brakk)
	pruefe(m != Karte.KEINE and BrakkGebiete.gebiet(m) == "niemandsland", "E7: Brakk im Gürtel – Mitte des Platzes im Niemandsland (%s)" % str(m))
	kp.aufbauen(brakk)
	var hoehle: Dictionary = zf.orte.filter(func(x: Dictionary) -> bool: return str(x["name"]) == "hoehle")[0]
	_brakk_auf((hoehle["felder"] as Array)[1])
	var ruht := zf.ruht(hoehle) and not zf.brakk_drin() and zf.hud_zeile() == ""
	var uhr := float(hoehle["uhr"])
	zf.weiter(5.0, spiel.kommandant)
	pruefe(kp.aktiv() and ruht and float(hoehle["uhr"]) == uhr, "E7: die Höhle liegt im Platz und ruht (kein Schutz, keine Uhr), die Felsen bleiben")
	kp.aufloesen(null, "sofort")
	pruefe(kp.zustand == "aus" and not zf.ruht(hoehle) and zf.brakk_drin(), "E7: nach dem Duell ist sie wieder eine Zuflucht")
	_brakk_auf(Werte.ANGRIFFS_ZELLE + Vector2i(3, 0))
