extends SceneTree
## 25.11. (Paul): Prüft das Balance-Paket für Befehl 24 headless.
##
##   godot --headless --path . --fixed-fps 60 -s werkzeuge/balance24test.gd -- [Formation]
##
## Werte (Erfahrung, Stufe 3 ab 12:30), kein Laser-Scharfschütze, Fabrik treffbar mit Lebensbalken, Fabrik-Leben mit
## 15 s Dauerfeuer (nach der echten Uhr, dauert deshalb so lange), Ring als Beute, Benannte ausschalten, Lager nach
## Sabotage, Sprengfalle und Elite-Ton. Brakk nimmt keinen Schaden. Am Ende „TEST BALANCE24 OK“ oder die Fehler.
## Schreibt wie das Spiel in user:// – vorher sichern.

var spiel: Node
var o: Order24
var warte := 10
var bild := 0
var schritt := 0
var fehler: Array[String] = []
var fz := Karte.KEINE       # Prüffabrik
var stand := Vector2.ZERO    # Brakks Platz davor
var zu := Vector2.ZERO       # Richtung zur Fabrik
var weit := 0
var t0 := 0
var schuesse := 0
var takt_vorher := 0.0


func _initialize() -> void:
	Nemesis.datei = "user://nemesis_test.json"
	Nemesis.zuruecksetzen()
	var a := OS.get_cmdline_user_args()
	OS.set_environment("TD_KARTE_NAME", "szenario_order24")
	Werte.lade_karte("szenario_order24")
	var r: Dictionary = (Werte.KARTE_REGELN.get("order24", {}) as Dictionary).duplicate()
	r["karte"] = a[0] if a.size() > 0 else "3-zitadelle"
	r["brakk_schaden"] = 0
	r["geheim_ab"] = 0
	r["flucht_sek"] = 5000
	r["jagd_start"] = 5000
	r["vorstoss"] = false
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


func _weiter() -> void:
	schritt += 1
	bild = 0


func _process(_delta: float) -> bool:
	if warte > 0:
		warte -= 1
		return false
	o = spiel.order24
	if o == null:
		return false
	var ego: EgoModus = spiel.ego
	if not o.laeuft:
		o.verrat_ueberspringen = true
		var tafel: Variant = ego.get("_briefing") if ego != null else null
		if tafel != null and (tafel as Control).visible:
			(tafel as Control).visible = false
		return false
	var k: Kommandant = spiel.kommandant
	k.leben = k.max_leben
	bild += 1
	match schritt:
		0:
			if bild < 90:
				return false
			_werte()
			_laser()
			_weiter()
		1:
			if not _platz():
				pruefe(false, "kein Platz vor einer Fabrik gefunden")
				_ende()
				return false
			# Mauern direkt neben der Fabrik decken ihren Rand zu Recht – für die Randschüsse räumen
			var quer_zelle := Vector2i(roundi(-zu.y), roundi(zu.x))
			for c: Vector2i in [fz + quer_zelle, fz - quer_zelle]:
				if spiel.karte.inhalt(c) == Karte.WALL:
					spiel.karte.fest.erase(c)
					spiel.karte.entferne(c)
			_weiter()
		2:
			_fabrik_treffen(ego, k)
		3:
			_dauerfeuer(ego, k)
		4:
			_balken_weg(k)
		5:
			_beute(ego, k)
			_weiter()
		6:
			_ausschalten(k)
			_weiter()
		7:
			_sabotage(k)
			_weiter()
		8:
			_toene(k)
			_ende()
	return false


func _ende() -> void:
	if fehler.is_empty():
		print("TEST BALANCE24 OK")
	else:
		print("TEST BALANCE24 FEHLER %d: %s" % [fehler.size(), str(fehler)])
	quit(0 if fehler.is_empty() else 1)


# ------------------------------------------------------------------ 1, 2: Werte

func _werte() -> void:
	pruefe(int(Order24.STANDARD["kill_xp_prozent"]) == 88 and int(o.w("kill_xp_prozent")) == 88, "1 Erfahrung: kill_xp_prozent %d" % int(o.w("kill_xp_prozent")))
	pruefe(int(o.w("faehigkeit_ab")) == 750 and int(o.w("stufe2_ab")) == 300, "2 Eskalation: Stufe 3 ab %d s, Stufe 2 ab %d s" % [int(o.w("faehigkeit_ab")), int(o.w("stufe2_ab"))])


# ------------------------------------------------------------------ 3: kein Laser-Scharfschütze

func _laser() -> void:
	var erlaubt := Order24.faehigkeiten_stufe3("scharfschuetze")
	erlaubt.sort()
	pruefe(erlaubt == ["durchschuss", "markierung"], "3 Wellen-Auswahl Scharfschütze: %s" % str(erlaubt))
	pruefe(Order24.faehigkeiten_stufe3("technogunner").size() == 3, "3 andere Truppenarten behalten ihre drei Fähigkeiten")
	# echte Stufe-3-Wellen
	var zeit := o.zeit
	o.zeit = 800.0
	var gezogen := {}
	var vorher: Array = spiel.einheiten.duplicate()
	for i in 24:
		o.wellen = 0   # nie eine Elitewelle
		o._jagdwelle()
	for x: Variant in spiel.einheiten:
		if not vorher.has(x) and (x as Einheit).faehigkeit != "":
			var typ := str(spiel.fabriken.get((x as Einheit).fabrik_zelle, {}).get("typ", ""))
			if typ == "scharfschuetze":
				gezogen[(x as Einheit).faehigkeit] = int(gezogen.get((x as Einheit).faehigkeit, 0)) + 1
	pruefe(not gezogen.is_empty() and not gezogen.has("laser"), "3 Stufe-3-Wellen (24 Stück): Scharfschützen mit %s" % str(gezogen))
	_weg_mit_neuen(vorher)
	# Elite (Stufe 4)
	vorher = spiel.einheiten.duplicate()
	o.wellen = 1
	o._jagdwelle()
	var mit: Array = []
	var elite := 0
	for x: Variant in spiel.einheiten:
		if not vorher.has(x):
			elite += 1
			mit.append((x as Einheit).faehigkeit)
	pruefe(elite > 0 and not mit.has("laser"), "3 Elitewelle: %d Truppen, Fähigkeiten %s" % [elite, str(mit)])
	pruefe(not (NemesisFaehigkeiten.JE_ART["scharfschuetze"] as Array).has("laser"), "3 Benannte: kein Laser im Fähigkeiten-Vorrat %s" % str(NemesisFaehigkeiten.JE_ART["scharfschuetze"]))
	_weg_mit_neuen(vorher)
	o.zeit = zeit
	# geladene Karte (Phantom / Weiterspielen): Fabrik und stehende Truppe mit Laser
	var f := Karte.KEINE
	for z: Vector2i in spiel.fabriken:
		if str(spiel.fabriken[z]["typ"]) == "scharfschuetze":
			f = z
	if f == Karte.KEINE:
		f = spiel.fabriken.keys()[0]
	var merk: Dictionary = (spiel.fabriken[f] as Dictionary).duplicate()
	spiel.fabriken[f]["faehigkeit"] = "laser"
	var e := o._neue_truppe("scharfschuetze", f, 3, "laser")
	o._ohne_laser()
	pruefe(str(spiel.fabriken[f]["faehigkeit"]) == "durchschuss" and e.faehigkeit == "durchschuss" and str(e.daten["faehigkeit"]) == "durchschuss",
		"3 geladene Karte: Laser-Fabrik → %s, stehende Truppe → %s" % [str(spiel.fabriken[f]["faehigkeit"]), e.faehigkeit])
	if merk.has("faehigkeit"):
		spiel.fabriken[f]["faehigkeit"] = merk["faehigkeit"]
	else:
		spiel.fabriken[f].erase("faehigkeit")


func _weg_mit_neuen(vorher: Array) -> void:
	for x: Variant in spiel.einheiten.duplicate():
		if not vorher.has(x):
			(x as Einheit).visible = false


# ------------------------------------------------------------------ 4: Fabrik treffen

## Eine Fabrik draußen mit vier freien Feldern davor (auch kein Mauerblock seitlich davor).
func _platz() -> bool:
	for n: int in [4, 3]:
		for z: Vector2i in o.fabrik_hp:
			for d: Vector2i in [Vector2i(0, 1), Vector2i(0, -1), Vector2i(-1, 0), Vector2i(1, 0)]:
				var ok := true
				for i in range(1, n + 1):
					for q in [-1, 0, 1]:
						var c: Vector2i = z + d * i + Vector2i(d.y, d.x) * q
						if not spiel.karte.in_karte(c) or spiel.karte.inhalt(c) == Karte.FABRIK or (spiel.hd.ist_hoch(c) and (q == 0 or i < n)):
							ok = false
				if ok:
					fz = z
					weit = n
					stand = spiel.karte.mitte(z + d * n)
					zu = (spiel.karte.mitte(z) - stand).normalized()
					return true
	# sonst freiräumen: Fabrik mit Platz im Feld, Wälle davor entfernen
	var z0: Vector2i = o.fabrik_hp.keys()[0]
	for d: Vector2i in [Vector2i(0, 1), Vector2i(0, -1), Vector2i(-1, 0), Vector2i(1, 0)]:
		if spiel.karte.in_karte(z0 + d * 5 + Vector2i(d.y, d.x)) and spiel.karte.in_karte(z0 + d * 5 - Vector2i(d.y, d.x)):
			for i in range(1, 6):
				for q in [-1, 0, 1]:
					var c: Vector2i = z0 + d * i + Vector2i(d.y, d.x) * q
					if spiel.karte.inhalt(c) == Karte.WALL:
						spiel.karte.fest.erase(c)
						spiel.karte.entferne(c)
			fz = z0
			weit = 4
			stand = spiel.karte.mitte(z0 + d * 4)
			zu = (spiel.karte.mitte(z0) - stand).normalized()
			return true
	return false


func _zielen(ego: EgoModus, k: Kommandant, punkt: Vector3) -> void:
	k.position = stand
	k.oben = false
	var d: Vector3 = (punkt - spiel.hd.kamera.global_position).normalized()
	ego.gier = atan2(-d.x, -d.z)
	ego.nick = asin(clampf(d.y, -1.0, 1.0))
	ego._kick = 0.0


func _nur_gebaeude() -> void:
	for e: Variant in spiel.einheiten:
		if is_instance_valid(e) and e != spiel.kommandant:
			(e as Einheit).visible = false
	o._ziele_pflegen()


var _fall := 0
var _treffer := 0
var _hp_vorher := 0.0

func _fabrik_treffen(ego: EgoModus, k: Kommandant) -> void:
	var fuss: Vector3 = ego._zu3d(spiel.karte.mitte(fz) + Vector2(0, 4), 0.0)
	var quer := Vector3(-zu.y, 0, zu.x)
	var fl: Rect2 = ego.fabrik_flaeche(fz)
	var faelle: Array = [
		["Mitte", Vector3(0, fl.end.y * 0.5, 0), true],
		["oberes Drittel", Vector3(0, fl.end.y * 0.82, 0), true],
		["linker Rand", quer * (fl.position.x + 0.07) + Vector3(0, 0.7, 0), true],
		["rechter Rand", quer * (fl.end.x - 0.07) + Vector3(0, 0.7, 0), true],
		["über dem Dach", Vector3(0, fl.end.y + 0.18, 0), false],
		["neben dem Gebäude", quer * (fl.end.x + 0.2) + Vector3(0, 0.6, 0), false],
	]
	var f: Array = faelle[_fall % faelle.size()]
	var lanze := _fall >= faelle.size()
	_zielen(ego, k, fuss + (f[1] as Vector3))
	if bild < 30:
		return
	o.fabrik_hp[fz] = 100000.0
	_nur_gebaeude()
	ego._hitze = [0.0, 0.0]
	ego._gesperrt = [0.0, 0.0]
	var vor := float(o.fabrik_hp[fz])
	if lanze:
		ego._lanze_rest = 0.0
		ego._lanze_feuer()
	else:
		ego._schiess()
	var schaden := vor - float(o.fabrik_hp[fz])
	if (schaden > 0.0) != bool(f[2]):
		var von: Vector3 = spiel.hd.kamera.global_position
		var r: Vector3 = ego._blick()
		var bis: float = ego._strahl_bis(von, r, 12.0, fz)
		var p: Vector3 = von + r * (bis + 0.03)
		var c := Vector2i(floori(p.x), floori(p.z))
		print("     blockiert nach %.2f Feldern bei %s (Fabrik %s): Höhe %.2f, Mauer=%s, Inhalt %d" % [bis, str(c), str(fz), p.y, str(spiel.hd.ist_hoch(c)), spiel.karte.inhalt(c)])
	pruefe((schaden > 0.0) == bool(f[2]), "4 %s auf „%s“ aus %d Feldern: %.1f Schaden (erwartet %s)" % ["Ladestrahl" if lanze else "Grundwaffe", f[0], weit, schaden, "Treffer" if f[2] else "vorbei"])
	_fall += 1
	bild = 0
	if _fall >= faelle.size() * 2:
		o.fabrik_hp[fz] = o.wf("fabrik_leben")
		_weiter()


# ------------------------------------------------------------------ 5: Fabrik-Leben (15 s Dauerfeuer)

func _dauerfeuer(ego: EgoModus, k: Kommandant) -> void:
	_zielen(ego, k, ego._zu3d(spiel.karte.mitte(fz) + Vector2(0, 4), 0.7))
	if bild < 30:
		ego._feuer = false
		return
	if bild == 30:
		_nur_gebaeude()
		ego._hitze = [0.0, 0.0]
		ego._gesperrt = [0.0, 0.0]
		ego._takt = 0.0
	if t0 == 0:
		t0 = Time.get_ticks_msec()
		schuesse = 0
		takt_vorher = 0.0
	_nur_gebaeude()
	ego._feuer = true
	if ego._takt > takt_vorher + 0.2:
		schuesse += 1
	takt_vorher = ego._takt
	var hp := float(o.fabrik_hp.get(fz, 0.0))
	if hp < _hp_vorher - 0.5:
		_treffer += 1
	_hp_vorher = hp
	var sek := (Time.get_ticks_msec() - t0) / 1000.0
	if not o.fabrik_hp.has(fz) or sek > 35.0:   # F4: 1380 Leben
		ego._feuer = false
		pruefe(not o.fabrik_hp.has(fz) and sek > 18.75 and sek < 26.25, "5 Fabrik mit %d Leben fällt nach %.1f s Dauerfeuer (Stufe %d, ohne Ringe): %d Schüsse, davon %d Treffer an der Fabrik" % [int(o.wf("fabrik_leben")), sek, k.fortschritt.stufe, schuesse, _treffer])
		pruefe(int(Order24.STANDARD["fabrik_leben"]) == 1380 and is_equal_approx(Order24.LANZE_FABRIK, 0.10), "5 fabrik_leben 1380 (F4: × 1,5), Ladestrahl weiter mindestens 10 %")
		_weiter()


# ------------------------------------------------------------------ 4: Balken blendet aus

func _balken_weg(k: Kommandant) -> void:
	if bild == 1:
		var z: Vector2i = o.fabrik_hp.keys()[0]
		set_meta("balken", z)
		o.fabrik_treffer(z, 10.0)
		o._3d_pflegen()
		pruefe(o._fabrik_balken.has(z), "4 Lebensbalken über der beschädigten Fabrik")
	var z2: Vector2i = get_meta("balken")
	if bild == 3:
		o.zeit += Order24.FABRIK_BALKEN_SEK + 0.1
		o._3d_pflegen()
		pruefe(not o._fabrik_balken.has(z2), "4 Lebensbalken %.0f s nach dem letzten Treffer weg" % Order24.FABRIK_BALKEN_SEK)
		_weiter()


# ------------------------------------------------------------------ 6: Ring als Beute

func _beute(_ego: EgoModus, k: Kommandant) -> void:
	var f: BrakkFortschritt = k.fortschritt
	# aus dem Dauerfeuer liegt schon eine Beute auf fz
	pruefe(o.beute_boden.size() >= 1 and str(o.beute_boden[0]["ring"]) != "" and f.ring_stufe(str(o.beute_boden[0]["ring"])) == 0, "6 zerstörte Fabrik: Ring „%s“ liegt auf den Trümmern" % str(o.beute_boden[0]["ring"] if not o.beute_boden.is_empty() else "-"))
	o._3d_pflegen()
	pruefe(not o.beute_boden.is_empty() and o.beute_boden[0]["knoten"] != null, "6 Lichtsäule und Ring stehen in der Welt")
	# Aufheben
	var ring := str(o.beute_boden[0]["ring"])
	var budget := int(spiel.budget)
	var n := f.ringe.size()
	k.position = o.beute_boden[0]["pos"]
	o._beute_pflegen(k)
	pruefe(f.ring_stufe(ring) == 1 and f.ringe.size() == n + 1 and int(spiel.budget) == budget and o.beute_boden.is_empty(), "6 aufgehoben: %s Stufe %d, Budget unverändert (%d)" % [ring, f.ring_stufe(ring), int(spiel.budget)])
	# 25.11. (Paul): kein Verkaufserlös – nur selbst bezahlte Stufen kommen zurück
	budget = int(spiel.budget)
	var erloes := f.erstattung(ring, spiel.welle)
	f.verkaufe(ring, spiel)
	pruefe(erloes == 0 and int(spiel.budget) == budget and f.ring_stufe(ring) == 0, "6 Beute-Ring verkauft: Anzeige +%d, Budget %d → %d" % [erloes, budget, int(spiel.budget)])
	f.schenke(ring, spiel)
	spiel.budget += int(BrakkFortschritt.RING_PREISE[1])
	var grund := f.kaufe(ring, spiel)
	var stufe_preis := int(BrakkFortschritt.RING_PREISE[1])
	pruefe(grund == "" and f.erstattung(ring, spiel.welle) == stufe_preis, "6 Beute-Ring aufgewertet: zurück nur die bezahlte Stufe (%d von %d)" % [f.erstattung(ring, spiel.welle), stufe_preis])
	f.verkaufe(ring, spiel)
	f.schenke(ring, spiel)
	# ein gekaufter Ring bringt weiter sein Gold zurück
	var anderer := str(o.beute_arten()[0])
	spiel.budget += int(BrakkFortschritt.RING_PREISE[0])
	f.kaufe(anderer, spiel)
	pruefe(f.erstattung(anderer, spiel.welle) == int(BrakkFortschritt.RING_PREISE[0]), "6 gekaufter Ring unverändert: Erlös %d" % f.erstattung(anderer, spiel.welle))
	f.verkaufe(anderer, spiel)
	# 200 Würfe: immer eine Art, die er nicht trägt
	var nie := true
	for i in 200:
		o.beute_boden.clear()
		o.beute_legen(fz)
		var r := str(o.beute_boden[0]["ring"])
		if r == "" or f.ring_stufe(r) > 0:
			nie = false
	pruefe(nie, "6 200 Würfe: immer eine neue Art, nie eine Stufe")
	# kein Finger frei: bleibt liegen
	while f.ringe.size() < f.finger():
		var frei: Array = o.beute_arten()
		spiel.budget += 175
		f.kaufe(str(frei[0]), spiel)
	o.beute_boden.clear()
	o.beute_legen(fz)
	var liegt := str(o.beute_boden[0]["ring"])
	k.position = o.beute_boden[0]["pos"]
	n = f.ringe.size()
	budget = int(spiel.budget)
	o._beute_pflegen(k)
	pruefe(o.beute_boden.size() == 1 and f.ringe.size() == n and f.ring_stufe(liegt) == 0 and int(spiel.budget) == budget, "6 alle %d Finger belegt: Ring bleibt liegen" % f.finger())
	# dieselbe Art am Terminal gekauft: der liegende Ring wechselt, keine Stufe
	var merk_ringe: Array = f.ringe.duplicate()
	var merk_stufen: Dictionary = f.ring_stufen.duplicate()
	f.ringe.append(liegt)
	f.ring_stufen[liegt] = 1
	k.position = stand
	o._beute_pflegen(k)
	pruefe(o.beute_boden.size() == 1 and str(o.beute_boden[0]["ring"]) != liegt and f.ring_stufe(liegt) == 1, "6 Art vorher gekauft: liegender Ring wechselt zu „%s“, keine Stufe" % str(o.beute_boden[0]["ring"]))
	# alle Arten: Gold
	for r: String in BrakkFortschritt.RINGE:
		f.ring_stufen[r] = 1
	o.beute_boden.clear()
	o.beute_legen(fz)
	budget = int(spiel.budget)
	k.position = o.beute_boden[0]["pos"]
	var leer := str(o.beute_boden[0]["ring"]) == ""
	o._beute_pflegen(k)
	pruefe(leer and int(spiel.budget) == budget + roundi(int(o.wf("praemie_fabrik") * 0.5) * o.wf("gold_faktor")), "6 alle Arten: stattdessen Gold (+%d)" % (int(spiel.budget) - budget))
	f.ringe.assign(merk_ringe)
	f.ring_stufen = merk_stufen
	# Sabotage gibt keinen Ring
	o.beute_boden.clear()
	var z: Vector2i = o.fabrik_hp.keys()[0]
	o.sabotieren(z)
	pruefe(o.beute_boden.is_empty(), "6 Sabotage gibt keinen Ring")
	spiel.repariere(z, true)
	o.lahm.erase(z)
	o.pilot_auftraege.clear()


# ------------------------------------------------------------------ 7: Benannte ausschalten

func _ausschalten(k: Kommandant) -> void:
	var n: Nemesis = o.nemesis
	for rang: int in [1, 4]:
		var p := n.neue_person("technogunner", rang, "Test%d" % rang, "Prüfling")
		pruefe(is_equal_approx(n.halte_zeit(p), 1.0), "7 Rang %d: %.1f s halten" % [rang, n.halte_zeit(p)])
		var e := o._neue_truppe("technogunner", spiel.fabriken.keys()[0], 4)
		n.einkleiden(e, p)
		e.position = k.position + Vector2(Werte.ZELLE * 0.5, 0)
		e.nimm_schaden(999999.0)
		o.ladungen = 0 if rang == 1 else int(o.w("spreng_max"))
		var budget := int(spiel.budget)
		var ringe: Dictionary = k.fortschritt.ring_stufen.duplicate()
		var xp := k.fortschritt.erfahrung
		var hinweis := n.ausschalten_hinweis()
		pruefe(str(hinweis.get("text", "")) == "[E] halten – endgültig ausschalten (40 Gold, Sprengladung)" and hinweis.has("farbe"), "7 Hinweis: „%s“" % str(hinweis.get("text", "")))
		n.ausschalten_taste(true)
		for i in 9:
			n._halten_weiter(0.1)
		var noch := n.personen.has(p)
		for i in 2:
			n._halten_weiter(0.1)
		var voll := int(o.w("spreng_max"))
		pruefe(noch and not n.personen.has(p), "7 Rang %d: nach 0,9 s noch da, nach 1,1 s ausgeschaltet" % rang)
		pruefe(int(spiel.budget) == budget + 40 and k.fortschritt.ring_stufen == ringe and k.fortschritt.erfahrung >= xp + 10, "7 Beute: +%d Gold, +%d Erfahrung, kein Ring" % [int(spiel.budget) - budget, k.fortschritt.erfahrung - xp])
		pruefe(o.ladungen == (1 if rang == 1 else voll), "7 Sprengladungen im Gepäck: %d (höchstens %d)" % [o.ladungen, voll])


# ------------------------------------------------------------------ 8: Lager nach Sabotage

func _sabotage(k: Kommandant) -> void:
	var karte: Karte = spiel.karte
	var z := Karte.KEINE
	var posten: Array[Vector2i] = []
	for c: Vector2i in o.fabrik_hp:
		var liste: Array[Vector2i] = []
		for s: Vector2i in karte.ausbau:
			if karte.ausbau[s] == Karte.STELLUNG and o.lager_von(s) == c:
				liste.append(s)
		if liste.size() > posten.size():
			z = c
			posten = liste
	pruefe(posten.size() >= 2, "8 %s hat %d Stellungen" % [o.lager_name(z), posten.size()])
	k.position = karte.mitte(karte.basis) + Vector2(-100000, 0)   # Brakk weit weg (sonst geht ohnehin niemand hinauf)
	var e := o._neue_truppe("technogunner", z, 1)
	var frei: Vector2i = posten[0]
	karte.posten.clear()
	var von: Vector2i = o._freies_feld_nahe(frei, 1)
	var geht := karte.finde_posten(von, e)
	pruefe(not geht.is_empty() and posten.has(geht["wall"] as Vector2i), "8 vorher: Truppe findet eine Stellung des Lagers (%s)" % str(geht.get("wall", "-")))
	o.sabotieren(z)
	var nach := karte.finde_posten(von, e)
	pruefe(o.stellung_gesperrt(frei) and (nach.is_empty() or o.lager_von(nach["wall"] as Vector2i) != z), "8 sabotiert: in die Stellungen des Lagers rückt niemand nach (nächste: %s)" % str(nach.get("wall", "keine")))
	o._3d_pflegen()
	pruefe(o._rauch3d.has(z), "8 sabotiert: Rauchsäule über der Fabrik")
	var f: Dictionary = spiel.fabriken[z]
	f["timer"] = 7.0
	spiel._physics_process(0.5)
	pruefe(float(f["timer"]) == 0.0, "8 sabotiert: kein Ersatz, der Zyklus steht auf 0")
	spiel.repariere(z, true)
	o._fabriken_pflegen(k, 0.1)
	o._3d_pflegen()
	pruefe(not o.lahm.has(z) and not o.stellung_gesperrt(frei) and not o._rauch3d.has(z), "8 repariert: Stellungen wieder frei, kein Rauch")
	pruefe(float(f["timer"]) < 1.0, "8 repariert: erster Ersatz erst nach einem vollen Zyklus (%d s, Zähler %.2f)" % [int(o.produktion_sek()), float(f["timer"])])
	pruefe(int(o.w("praemie_sabotage")) == 100 and int(o.w("xp_sabotage")) == 12, "8 Prämie bleibt 100 Gold / 12 Erfahrung")
	o.pilot_auftraege.clear()


# ------------------------------------------------------------------ 9: Töne

func _toene(k: Kommandant) -> void:
	Werte.toene = 80
	k.position = stand
	Ton._laeuft.clear()
	Ton._stimmen.clear()
	var klaenge := {}
	spiel.brakk_geschosse.falle(stand + Vector2(2.0 * Werte.ZELLE, 0), Werte.NEMESIS_FALLE_ZUENDER, Werte.NEMESIS_FALLE_RADIUS * Werte.ZELLE, 0.0, "test")
	for i in int((Werte.NEMESIS_FALLE_ZUENDER + 0.5) * 60.0):
		spiel.brakk_geschosse.weiter(1.0 / 60.0)
		for art: String in Ton._laeuft:
			klaenge[art] = int(klaenge.get(art, 0)) + (Ton._laeuft[art] as Array).size()
		Ton._laeuft.clear()
		Ton._stimmen.clear()
	pruefe(not klaenge.has("ui-klick") and int(klaenge.get("tc-arc", 0)) == 1, "9 Sprengfalle: kein Menü-Klick, ein Ton beim Legen (%s)" % str(klaenge))
	# Elite-Ton auch bei voller Stimmengrenze
	for i in Ton.STIMMEN:
		Ton._stimmen.append(Time.get_ticks_msec() / 1000.0 + 5.0)
	o.wellen = 1
	o.zeit = 800.0
	o._jagdwelle()
	pruefe((Ton._laeuft.get(Order24.ELITE_TON, []) as Array).size() == 1 and not Ton._laeuft.has("ui-klick"), "9 Elitetrupp: genau ein Ton (%s), auch wenn das Gefecht alle Stimmen belegt – gehört: %s" % [Order24.ELITE_TON, str(Ton._laeuft.keys())])
