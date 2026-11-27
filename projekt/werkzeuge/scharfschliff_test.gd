extends SceneTree
## H (27.11., Paul): Bossarena, Scharfschütze – Feinschliff (Prompt H), headless in der Bossarena:
##
##   godot --headless --path . --fixed-fps 60 -s werkzeuge/scharfschliff_test.gd -- hoehe
##
## Teile (einer je Lauf):
##   hoehe – 5e: Boss Krone/Boden × Brakk Krone/Boden, je 20 Schüsse: Mündung in seiner Höhe, die Linie schneidet Brakks
##           Trefferzone in Brakks Höhe, kein Schuss endet vorher an einer Wallseite (ohne Sicht fällt er aus).
##   reihe – 1: Reihenwelle rechnerisch je Reihe: Stehen trifft genau einmal; Sprung bei Rotwerden + 0,5 s (senkrecht in der
##           brechenden Reihe oder aus der Reihe davor zum Boss hin darüber) trifft nie; Reihen vom Boss weg bis zum Rand.
##   salve – 2: zehn Salven auf einen gleichmäßig quer laufenden Brakk (3 Felder/s): Geschossrichtung = Linienrichtung
##           (≤ 0,5°), die Vorhersage trifft ≥ 80 % der Wellen; Flugzeit für 8 Felder 0,6 s.
##   klon  – 8: Quote über 200 Ziehungen ~25 %; erzwungen: Maschine, Kopie (35 % seines Lebens, kein Benannter), nach
##           25 s weg; nie zwei Bodeneffekte zugleich (Boss, Reihenwelle, Säule, Klon).
##   tafel – 10: [F2]-Werte-Tafel: BOSS_SNIPER_FENSTER +0,2 – die nächste Salve der Abfolge steht so lange; gespeichert,
##           kopierbar, „Alles Standard“; ein neuer Start von Befehl 24 setzt alles zurück.

var spiel: Node
var o: Order24
var h: NemesisHerausforderer
var warte := 10
var schritt := 0
var fehler: Array[String] = []
var geprueft := 0
var teil := "hoehe"
var soll := 1
var t0 := 0.0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		teil = str(args[0])
	soll = {"hoehe": 5, "reihe": 4, "salve": 3, "klon": 5, "tafel": 5}.get(teil, 1)
	OS.set_environment("TD_KARTE_NAME", Werte.ORDER24_KARTE_NAME)
	Werte.lade_karte(Werte.ORDER24_KARTE_NAME)
	BrakkBossarena.laeuft = true
	BrakkBossarena.wahl = {"boss": "scharfschuetze", "stufe": 8, "ringe": "standard", "frei": [["laser", 1], ["markierung", 1], ["feuerteam", 1]],
		"ladungen": 0, "phase2": false}
	if teil == "klon":
		BrakkBossarena.wahl["klon"] = true
	var main_skript: GDScript = load("res://scripts/main.gd")
	main_skript.set("naechster_start", "normal")
	spiel = load("res://main.tscn").instantiate()
	root.add_child(spiel)


func pruefe(ok: bool, text: String) -> void:
	geprueft += 1
	print("%s %s" % ["OK  " if ok else "FEHL", text])
	if not ok:
		fehler.append(text)


func _fertig() -> bool:
	if geprueft < soll:
		fehler.append("nur %d von %d Prüfungen gelaufen" % [geprueft, soll])
	paused = false
	if fehler.is_empty():
		print("TEST SCHARFSCHLIFF %s OK (%d Prüfungen)" % [teil, geprueft])
	else:
		print("TEST SCHARFSCHLIFF %s FEHLER (%d): %s" % [teil, fehler.size(), "; ".join(PackedStringArray(fehler))])
	quit(0 if fehler.is_empty() else 1)
	return true


func _process(_delta: float) -> bool:
	if warte > 0:
		warte -= 1
		return false
	o = spiel.order24
	if o == null:
		return false
	h = o.herausforderer
	var k: Kommandant = spiel.kommandant
	if k != null:
		k.leben = k.max_leben
	if schritt == 0:
		if h.zustand == "duell" and h.einzug.is_empty() and h.kampfplatz.zu():
			h._vergeltung_in = 9999.0
			if teil != "klon" and h.klon != null:
				h.klon.gezogen = false   # 27.11.: eine zufällige Klonmaschine (25 %) schoss sonst in die Messungen
			t0 = o.zeit
			schritt = 1
		elif o.zeit > 40.0:
			pruefe(false, "kein Duell nach 40 s")
			return _fertig()
		return false
	match teil:
		"hoehe":
			return _teil_hoehe()
		"reihe":
			return _teil_reihe()
		"salve":
			return _teil_salve()
		"klon":
			return _teil_klon()
		"tafel":
			return _teil_tafel()
	pruefe(false, "unbekannter Teil " + teil)
	return _fertig()


## Der Boss steht (ein endloses Fenster) – der Test setzt ihn und Brakk selbst.
func _boss_halten() -> void:
	h.angriff = {"art": "test", "teil": "fenster", "t": 0.0, "um": 9999.0, "angesagt": 0.0}
	h._aktion = {}
	h._weg.clear()


func _rand_waelle() -> Array[Vector2i]:
	var kp := h.kampfplatz
	var aus: Array[Vector2i] = []
	for z: Vector2i in kp.gesetzt:
		if kp.ist_krone(z) and o.karte.inhalt(z) == Karte.WALL:
			aus.append(z)
	return aus


func _innen_frei() -> Array[Vector2i]:
	var kp := h.kampfplatz
	var hb := BrakkKampfplatz._halb()
	var aus: Array[Vector2i] = []
	for y in range(kp.mitte.y - hb.y, kp.mitte.y + hb.y):
		for x in range(kp.mitte.x - hb.x, kp.mitte.x + hb.x):
			var z := Vector2i(x, y)
			if kp.im_innern(z) and o.karte.inhalt(z) != Karte.WALL and o.karte.ist_frei(z):
				aus.append(z)
	return aus


func _brakk_setzen(z: Vector2i, oben: bool) -> void:
	var k: Kommandant = spiel.kommandant
	var ego: EgoModus = spiel.ego
	k.oben = oben
	ego._setze_fuss(o.karte.mitte(z))
	ego.hoehe = spiel.hd.H if oben else 0.0
	k.position = o.karte.mitte(z)


func _boss_setzen(z: Vector2i, oben: bool) -> void:
	h.einheit.position = o.karte.mitte(z)
	h.einheit.zustand = Einheit.Zustand.AUF_POSTEN if oben else Einheit.Zustand.BODEN
	h.einheit.set_meta("hebt_ab", 0.0)


var _hoehe_fall := 0
var _hoehe_erg := {}


## 5e: je Fall 20 Schüsse von zufälligen passenden Feldern (mit Sicht aus der Höhe des Bosses).
func _teil_hoehe() -> bool:
	if _hoehe_fall >= 4:
		var gesamt_ok := true
		for fall: String in _hoehe_erg:
			print("HOEHE %s %s" % [fall, str(_hoehe_erg[fall])])
		var muendung_ok := _hoehe_erg.values().all(func(e: Dictionary) -> bool: return int(e["muendung_falsch"]) == 0)
		pruefe(muendung_ok, "Mündung in der Höhe des Bosses (Krone %.2f, Boden 0,5)" % (spiel.hd.H + 0.5))
		for fall: String in _hoehe_erg:
			var e: Dictionary = _hoehe_erg[fall]
			gesamt_ok = gesamt_ok and int(e["schuesse"]) == 20 and int(e["trifft"]) == 20 and int(e["wand"]) == 0
		for fall: String in _hoehe_erg:
			var e: Dictionary = _hoehe_erg[fall]
			pruefe(int(e["schuesse"]) == 20 and int(e["trifft"]) == 20 and int(e["wand"]) == 0,
				"%s: %d Schüsse, Linie in Brakks Zone %d, an einer Wallseite %d (ohne Sicht übersprungen %d)" % [fall, int(e["schuesse"]), int(e["trifft"]), int(e["wand"]), int(e["ohne_sicht"])])
		return _fertig()
	var boss_oben := _hoehe_fall >= 2
	var brakk_oben := _hoehe_fall % 2 == 1
	var fall := "Boss %s × Brakk %s" % ["Krone" if boss_oben else "Boden", "Krone" if brakk_oben else "Boden"]
	var e: Dictionary = {"schuesse": 0, "trifft": 0, "wand": 0, "ohne_sicht": 0, "muendung_falsch": 0}
	var waelle := _rand_waelle()
	var innen := _innen_frei()
	var bg: BrakkGeschosse = spiel.brakk_geschosse
	var k: Kommandant = spiel.kommandant
	var versuche := 0
	while int(e["schuesse"]) < 20 and versuche < 400:
		versuche += 1
		_boss_halten()
		var zb: Vector2i = (waelle if boss_oben else innen).pick_random()
		var zk: Vector2i = (waelle if brakk_oben else innen).pick_random()
		if zb == zk or o.karte.mitte(zb).distance_to(o.karte.mitte(zk)) < 3.0 * Werte.ZELLE:
			continue
		_boss_setzen(zb, boss_oben)
		_brakk_setzen(zk, brakk_oben)
		if not h.sieht(h.einheit.position, k.position):
			e["ohne_sicht"] = int(e["ohne_sicht"]) + 1
			continue
		var r := (k.position - h.einheit.position).normalized()
		var vor := bg.geschosse.size()
		bg.schiesse("hf_salve", h._muendung(r), h._hoehe_er(), 0.0, "herausforderer", h.quelle(), 1.0, k.position)
		if bg.geschosse.size() == vor:
			continue
		var g: Dictionary = bg.geschosse.back()
		h._an_der_wand_enden(g)
		g["harmlos"] = true
		e["schuesse"] = int(e["schuesse"]) + 1
		var soll_h: float = 0.5 + (spiel.hd.H if boss_oben else 0.0)
		if absf(float(g["h0"]) - soll_h) > 0.01:
			e["muendung_falsch"] = int(e["muendung_falsch"]) + 1
		var von: Vector2 = g["von"]
		var bahn_r: Vector2 = g["r"]
		var p := Geometry2D.get_closest_point_to_segment(k.position, von, von + bahn_r * float(g["lang"]))
		var hoehe: float = bg._hoehe(g, von.distance_to(p))
		var fuss: float = spiel.ego.hoehe
		var in_zone := p.distance_to(k.position) <= float(g["radius"]) + Werte.BRAKK_RUMPF * Werte.ZELLE and hoehe >= fuss and hoehe <= fuss + 1.0
		if in_zone:
			e["trifft"] = int(e["trifft"]) + 1
		if float(g["lang"]) < von.distance_to(k.position) - Werte.BRAKK_RUMPF * Werte.ZELLE:
			e["wand"] = int(e["wand"]) + 1
	_hoehe_erg[fall] = e
	_hoehe_fall += 1
	return false


## 1: Die Reihenwelle rechnerisch (ohne Bild) mit einem gedachten Brakk – Sprung mit Brakks echten Werten (EgoModus).
func _teil_reihe() -> bool:
	_boss_halten()
	var kp := h.kampfplatz
	var ergebnis := {}
	for richtung: Vector2i in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]:
		var von := o.karte.mitte(kp.mitte - richtung * 6)
		var zu := o.karte.mitte(kp.mitte + richtung * 4)
		var plan := NemesisReihenwelle.new(h)
		plan.ohne_bild = true
		plan.planen(von, zu)
		var n := plan.reihen.size()
		var e := {"reihen": n, "dauer": snappedf(plan.dauer(), 0.01), "stehen": [], "hoch": 0, "drueber": 0, "faelle": 0}
		for i in n:
			for variante: String in ["stehen", "hoch", "drueber"]:
				if variante == "drueber" and i + 1 >= n:
					continue   # vor der letzten Reihe liegt die Lichtwand
				for wdh in 6:
					var w := NemesisReihenwelle.new(h)
					w.ohne_bild = true
					w.planen(von, zu)
					var start_reihe: int = i + 1 if variante == "drueber" else i
					var rect: Rect2 = w.reihen[start_reihe]["rect"]
					var innen := rect.grow(-0.08 * Werte.ZELLE)
					var sim := {"pos": innen.position + Vector2(randf() * innen.size.x, randf() * innen.size.y), "h": 0.0, "steig": 0.0, "springt": false, "fertig": false,
						"ab": float(w.reihen[i]["ab"]) + 0.5}
					w.lage_fn = func() -> Dictionary: return {"pos": sim["pos"], "boden": float(sim["h"]) <= Werte.BRAKK_SPRUNG_BODEN}
					var treffer := [0]
					w.treffer_fn = func(_a: float, _p: Vector2) -> void: treffer[0] += 1
					var dt := 1.0 / 60.0
					var zum_boss := -Vector2(w.schritt)
					while not w.fertig():
						if variante != "stehen" and not bool(sim["springt"]) and not bool(sim["fertig"]) and w.t >= float(sim["ab"]):
							sim["springt"] = true
							sim["steig"] = EgoModus.SPRUNG
						if bool(sim["springt"]):
							sim["steig"] = float(sim["steig"]) - EgoModus.SCHWERE * dt
							sim["h"] = float(sim["h"]) + float(sim["steig"]) * dt
							if variante == "drueber":
								sim["pos"] = (sim["pos"] as Vector2) + zum_boss * EgoModus.TEMPO * Werte.ZELLE * dt
							if float(sim["h"]) <= 0.0:
								sim["h"] = 0.0
								sim["springt"] = false
								sim["fertig"] = true
						w.weiter(dt)
					e["faelle"] = int(e["faelle"]) + 1
					match variante:
						"stehen":
							(e["stehen"] as Array).append(treffer[0])
						"hoch":
							e["hoch"] = int(e["hoch"]) + treffer[0]
						"drueber":
							e["drueber"] = int(e["drueber"]) + treffer[0]
		ergebnis[str(richtung)] = e
	var ok_stehen := true
	var ok_sprung := true
	var dauer_ok := true
	for r: String in ergebnis:
		var e: Dictionary = ergebnis[r]
		print("REIHE %s %s" % [r, str({"reihen": e["reihen"], "dauer": e["dauer"], "hoch": e["hoch"], "drueber": e["drueber"], "faelle": e["faelle"]})])
		ok_stehen = ok_stehen and (e["stehen"] as Array).all(func(x: int) -> bool: return x == 1)
		ok_sprung = ok_sprung and int(e["hoch"]) == 0 and int(e["drueber"]) == 0
	var quer: Dictionary = ergebnis[str(Vector2i(1, 0))]
	dauer_ok = float(quer["dauer"]) >= 4.0 and float(quer["dauer"]) <= 6.0
	pruefe(ok_stehen, "Stehen: jede Reihe trifft genau einmal")
	pruefe(ok_sprung, "Sprung bei Rotwerden + 0,5 s (senkrecht oder zum Boss darüber): kein Treffer")
	pruefe(dauer_ok, "Welle quer über den Platz vom Rand: %.2f s (4–6 s)" % float(quer["dauer"]))
	# vom Boss in der Mitte: die Reihen beginnen vor ihm und enden an der Lichtwand
	var w2 := NemesisReihenwelle.new(h)
	w2.ohne_bild = true
	w2.planen(o.karte.mitte(kp.mitte), o.karte.mitte(kp.mitte + Vector2i(0, 3)))
	var erste: Vector2i = (w2.reihen[0]["zellen"] as Array)[0]
	var letzte: Vector2i = (w2.reihen.back()["zellen"] as Array)[0]
	var hb := BrakkKampfplatz._halb()
	pruefe(erste.y == kp.mitte.y + 1 and letzte.y == kp.mitte.y + hb.y - 2, "Boss in der Mitte: Reihen %d bis %d (Rand %d)" % [erste.y - kp.mitte.y, letzte.y - kp.mitte.y, hb.y - 2])
	return _fertig()


var _sv := {"n": 0, "phase": "start", "t": 0.0, "wellen": 0, "treffer_vor": 0, "winkel_max": 0.0, "geschosse": 0, "flug": []}
var _sv_brakk := Vector2.ZERO
var _sv_richtung := 1.0


## 2: Salven auf einen gleichmäßig laufenden Brakk.
func _teil_salve() -> bool:
	var kp := h.kampfplatz
	var k: Kommandant = spiel.kommandant
	var bg: BrakkGeschosse = spiel.brakk_geschosse
	var dt := 1.0 / 60.0
	h._bis_angriff = 999.0
	h._aktion_in = 999.0
	h._vergeltung_in = 9999.0
	k.unverwundbar = 0.0
	# gleichmäßig laufen
	_sv_brakk += Vector2(0, _sv_richtung) * EgoModus.TEMPO * Werte.ZELLE * dt
	_brakk_setzen_px(_sv_brakk)
	# neue Geschosse: Richtung gegen die angesagte Linie
	var letzte := h.protokoll.slice(int(_sv.get("proto_ab", h.protokoll.size()))).filter(func(e: Dictionary) -> bool: return str(e.get("was", "")) == "faecher")   # 27.11.: nur Wellen der Test-Salven
	for g: Dictionary in bg.geschosse:
		if g.has("gruppe") and _sv.has("gruppe_ab") and int(g["gruppe"]) > int(_sv["gruppe_ab"]) and not g.has("_gesehen"):   # 27.11.: nur die Test-Salven
			g["_gesehen"] = true
			_sv["geschosse"] = int(_sv["geschosse"]) + 1
			var best := 180.0
			if not letzte.is_empty():
				for r: Vector2 in letzte.back()["dirs"]:
					best = minf(best, rad_to_deg(absf((g["r"] as Vector2).angle_to(r))))
			_sv["winkel_max"] = maxf(float(_sv["winkel_max"]), best)
			(_sv["flug"] as Array).append(8.0 * Werte.ZELLE / float(g["tempo"]) * (1.0 / Werte.SPIELTEMPO))
	_sv["t"] = float(_sv["t"]) + dt
	match str(_sv["phase"]):
		"start":
			if int(_sv["n"]) >= 10:
				var wellen := letzte.size()
				var quote := float(bg.getroffen - int(_sv["treffer_vor"])) / maxf(1.0, float(wellen))
				var flug: Array = _sv["flug"]
				var flug_mittel: float = flug.reduce(func(a: float, b: float) -> float: return a + b, 0.0) / maxf(1.0, flug.size())
				pruefe(int(_sv["geschosse"]) == wellen * 3 and float(_sv["winkel_max"]) <= 0.5, "Linienrichtung = Geschossrichtung: %d Geschosse, größte Abweichung %.3f°" % [int(_sv["geschosse"]), float(_sv["winkel_max"])])
				pruefe(wellen >= 36 and quote >= 0.8, "Vorhersage: %d von %d Wellen treffen den laufenden Brakk (%.0f %%)" % [bg.getroffen - int(_sv["treffer_vor"]), wellen, quote * 100.0])
				pruefe(absf(flug_mittel - Werte.BOSS_SNIPER_SALVE_FLUG) < 0.02, "Flugzeit für 8 Felder %.2f s (Soll %.2f)" % [flug_mittel, Werte.BOSS_SNIPER_SALVE_FLUG])
				return _fertig()
			if int(_sv["n"]) == 0:
				_sv["treffer_vor"] = bg.getroffen
				(h.typ as NemesisBossScharf)._wellen.clear()   # 27.11.: eine Salve des Bosses von vor dem Test läuft nicht weiter …
				h.angriff = {}
				_sv["gruppe_ab"] = h._salven   # … und ihre Geschosse zählen nicht
				_sv["proto_ab"] = h.protokoll.size()
			_boss_setzen(kp.mitte + Vector2i(-6, 0), false)
			h.angriff = {}
			_sv_richtung = 1.0 if int(_sv["n"]) % 2 == 0 else -1.0
			_sv_brakk = o.karte.mitte(kp.mitte + Vector2i(2, -4 if _sv_richtung > 0.0 else 3))
			_brakk_setzen_px(_sv_brakk)
			_sv["phase"] = "anlauf"
			_sv["t"] = 0.0
		"anlauf":
			if float(_sv["t"]) >= 0.4:
				h.beginne_angriff("salve")
				_sv["phase"] = "salve"
				_sv["t"] = 0.0
		"salve":
			if float(_sv["t"]) >= Werte.BOSS_SNIPER_SALVE_ANSAGE + Werte.BOSS_SNIPER_SALVE_TAKT * 3 + 1.0:
				_sv["n"] = int(_sv["n"]) + 1
				_sv["phase"] = "start"
	return false


func _brakk_setzen_px(p: Vector2) -> void:
	var k: Kommandant = spiel.kommandant
	k.oben = false
	spiel.ego._setze_fuss(p)
	spiel.ego.hoehe = 0.0
	k.position = p


var _kl := {"phase": "warten", "e": null, "leben_ok": false, "benannt": false, "ab": 0.0}


## 8: Klonmaschine.
func _teil_klon() -> bool:
	var k: Kommandant = spiel.kommandant
	k.unverwundbar = 0.0
	var kl := h.klon
	match str(_kl["phase"]):
		"warten":
			var ja := 0
			for i in 200:
				ja += 1 if NemesisKlon.zieht(randf()) else 0
			pruefe(ja >= 36 and ja <= 64, "Quote: %d von 200 Ziehungen (Soll ~50)" % ja)
			_kl["phase"] = "kommt"
		"kommt":
			if kl != null and kl.laeuft():
				var e := kl.e
				_kl["e"] = e
				_kl["ab"] = h.uhr
				_kl["leben_ok"] = absf(e.max_leben - h.einheit.max_leben * Werte.BOSS_KLON_LEBEN) < 1.0
				_kl["benannt"] = h.nem._person_von.has(e.get_instance_id()) or h.nem.einheit_von(h.person) == e
				var ansage := kl.protokoll.filter(func(x: Dictionary) -> bool: return str(x["was"]) == "ansage")
				pruefe(not ansage.is_empty() and float(ansage[0]["bei"]) >= Werte.BOSS_KLON_AB and bool(_kl["leben_ok"]) and not bool(_kl["benannt"]) and kl.protokoll.any(func(x: Dictionary) -> bool: return str(x["was"]) == "klon" and str(x["art"]) == "scharfschuetze"),
					"Klon: Ansage nach %.1f s, Kopie mit %.0f Leben (%.0f %% des Bosses), kein Benannter" % [float(ansage[0]["bei"]) if not ansage.is_empty() else -1.0, e.max_leben, 100.0 * e.max_leben / h.einheit.max_leben])
				_kl["phase"] = "kampf"
			elif h.uhr > 60.0:
				pruefe(false, "kein Klon nach 60 s")
				return _fertig()
		"kampf":
			if kl.zustand == "fertig":
				var weg := kl.protokoll.filter(func(x: Dictionary) -> bool: return str(x["was"]) == "weg")
				var e: Variant = _kl["e"]
				var gone: bool = not is_instance_valid(e) or not (e as Node).is_inside_tree() or not (e as Node2D).visible or (e as Einheit).kampfunfaehig or bool((e as Einheit).get_meta("weggebeamt", false))
				pruefe(not weg.is_empty() and absf(float(weg[0]["nach"]) - Werte.BOSS_KLON_SEK) < 0.2 and str(weg[0]["wie"]) == "zeit",
					"Klon weg nach %.1f s (%s)" % [float(weg[0]["nach"]) if not weg.is_empty() else -1.0, str(weg[0]["wie"]) if not weg.is_empty() else "–"])
				var angriffe := kl.protokoll.filter(func(x: Dictionary) -> bool: return str(x["was"]) == "angriff")
				pruefe(angriffe.size() >= 3 and angriffe.all(func(x: Dictionary) -> bool: return str(x["art"]) in ["salve", "sturm"]), "Klon: %d Angriffe, nur Salve und Sturm (%s)" % [angriffe.size(), str(angriffe.map(func(x: Dictionary) -> String: return str(x["art"])))])
				var ueber := boden_ueberlappungen()
				pruefe(ueber.is_empty(), "nie zwei Bodeneffekte zugleich (%d Einträge, Überlappungen %s)" % [h.boden_log.size(), str(ueber.slice(0, 3))])
				print("KLON gone=%s protokoll=%s" % [str(gone), str(kl.protokoll)])
				return _fertig()
	return false


## Zwei verschiedene Besitzer mit überlappender Bodenmarkierung (die Kombo Säule + Laservisier ist gewollt).
func boden_ueberlappungen() -> Array:
	var aus: Array = []
	var l: Array = h.boden_log
	for i in l.size():
		for j in range(i + 1, l.size()):
			var a: Dictionary = l[i]
			var b: Dictionary = l[j]
			if str(a["wer"]) == str(b["wer"]):
				continue
			var paar := [str(a["wer"]), str(b["wer"])]
			paar.sort()
			if paar == ["kombo", "saeule"]:
				continue
			if minf(float(a["bis"]), float(b["bis"])) - maxf(float(a["von"]), float(b["von"])) > 0.05:
				aus.append("%s %.2f–%.2f / %s %.2f–%.2f" % [a["wer"], a["von"], a["bis"], b["wer"], b["von"], b["bis"]])
	return aus


var _tf := {"phase": "aendern", "ab": 0}


## 10: Werte-Tafel.
func _teil_tafel() -> bool:
	var tafel := o.arena.werte_tafel
	match str(_tf["phase"]):
		"aendern":
			tafel.alles_standard()
			tafel.umschalten()   # auf (baut die Liste)
			var std := float(Werte.boss_standard()["BOSS_SNIPER_FENSTER"])
			tafel.aendern("BOSS_SNIPER_FENSTER", 4)
			var cfg := ConfigFile.new()
			cfg.load(BrakkBosswerte.DATEI)
			pruefe(absf(Werte.BOSS_SNIPER_FENSTER - (std + 0.2)) < 0.001 and absf(float(cfg.get_value("werte", "BOSS_SNIPER_FENSTER", 0.0)) - (std + 0.2)) < 0.001 and o.arena.werte_offen() and o.sperrt_steuerung(),
				"Tafel offen (Brakk gesperrt), BOSS_SNIPER_FENSTER %.2f → %.2f, gespeichert" % [std, Werte.BOSS_SNIPER_FENSTER])
			pruefe(BrakkBosswerte.kopiertext().contains("static var BOSS_SNIPER_FENSTER := %s" % str(snappedf(std + 0.2, 0.001))), "Werte kopieren: %s" % BrakkBosswerte.kopiertext().replace("\n", " | "))
			tafel.umschalten()
			_tf["ab"] = h.protokoll.size()
			_tf["phase"] = "duell"
		"duell":
			for i in range(int(_tf["ab"]), h.protokoll.size()):
				var e: Dictionary = h.protokoll[i]
				if str(e.get("was", "")) == "angriff" and str(e.get("art", "")) == "salve" and not bool(e.get("druck", false)) and not e.has("dann"):
					pruefe(absf(float(e["fenster"]) - Werte.BOSS_SNIPER_FENSTER) < 0.001, "das Duell nutzt ihn sofort: nächste Salve steht %.2f s" % float(e["fenster"]))
					o.arena.werte_tafel.alles_standard()
					var cfg := ConfigFile.new()
					cfg.load(BrakkBosswerte.DATEI)
					pruefe(absf(Werte.BOSS_SNIPER_FENSTER - float(Werte.boss_standard()["BOSS_SNIPER_FENSTER"])) < 0.001 and not cfg.has_section("werte"), "Alles Standard: %.2f, Datei ohne Abweichungen" % Werte.BOSS_SNIPER_FENSTER)
					Werte.boss_setzen("BOSS_REIHE_TAKT", 0.5)
					Werte.boss_zuruecksetzen()   # wie Order24.einrichten im echten Lauf
					pruefe(absf(Werte.BOSS_REIHE_TAKT - 0.35) < 0.001, "neuer Lauf: zurück auf Standard (BOSS_REIHE_TAKT %.2f)" % Werte.BOSS_REIHE_TAKT)
					return _fertig()
			if h.uhr > 70.0:
				pruefe(false, "keine Salve nach der Änderung")
				return _fertig()
	return false
