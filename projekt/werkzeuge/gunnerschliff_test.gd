extends SceneTree
## I (27.11., Paul): Bossarena, Technogunner – Umbau (Prompt I), headless in der Bossarena:
##
##   godot --headless --path . --fixed-fps 60 -s werkzeuge/gunnerschliff_test.gd -- anker
##
## Teile (einer je Lauf):
##   anker – 1: Jagdanker aus 13 Feldern trifft und zieht heran, aus 4 Feldern wird der Schritt zum Sturmring, aus über
##           14 Feldern läuft er erst an (höchstens 1,5 s) und wirft dann.
##   sturm – 2: Sturmring: Ansage 0,8 s, erster Ring 0,5 s nach dem Schlag, dann je 1,0 s (Bodenring 0,3 s vorher), drei Ringe
##           mit Weite 7; aus über 10 Feldern kommt erst der Jagdanker.
##   salve – 3: 4er-Salve: Geschosse entlang der angesagten Linie (≤ 0,5°), höchstens zwei Treffer, die zweite Salve in
##           Folge kommt nach einem Seitschritt aus einem anderen Winkel.
##   minigun – 4: Reichweite 8: Brakk hält 9 Felder Abstand – kein Schaden; steht er auf 6 Feldern – Schaden; Ring sichtbar.
##   krone – 5: auf eine Rand-Krone, oben höchstens 6 s bzw. zwei Angriffe, herunter mit dem Sturmring (Absprung).

var spiel: Node
var o: Order24
var h: NemesisHerausforderer
var g: NemesisBossGunner
var warte := 10
var schritt := 0
var fehler: Array[String] = []
var geprueft := 0
var teil := "anker"
var soll := 1
var _p := {"phase": "start", "t": 0.0}
var _brakk := Vector2.ZERO


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		teil = str(args[0])
	soll = {"anker": 3, "sturm": 3, "salve": 3, "minigun": 2, "krone": 2}.get(teil, 1)
	OS.set_environment("TD_KARTE_NAME", Werte.ORDER24_KARTE_NAME)
	Werte.lade_karte(Werte.ORDER24_KARTE_NAME)
	BrakkBossarena.laeuft = true
	BrakkBossarena.wahl = {"boss": "technogunner", "stufe": 8, "ringe": "standard", "frei": [["laser", 1], ["markierung", 1], ["feuerteam", 1]],
		"ladungen": 0, "phase2": false}
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
		print("TEST GUNNERSCHLIFF %s OK (%d Prüfungen)" % [teil, geprueft])
	else:
		print("TEST GUNNERSCHLIFF %s FEHLER (%d): %s" % [teil, fehler.size(), "; ".join(PackedStringArray(fehler))])
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
		k.unverwundbar = 0.0
	if schritt == 0:
		if h.zustand == "duell" and h.einzug.is_empty() and h.kampfplatz.zu():
			h._vergeltung_in = 9999.0
			g = h.typ as NemesisBossGunner
			schritt = 1
		elif o.zeit > 40.0:
			pruefe(false, "kein Duell nach 40 s")
			return _fertig()
		return false
	_p["t"] = float(_p["t"]) + 1.0 / 60.0
	match teil:
		"anker":
			return _teil_anker()
		"sturm":
			return _teil_sturm()
		"salve":
			return _teil_salve()
		"minigun":
			return _teil_minigun()
		"krone":
			return _teil_krone()
	pruefe(false, "unbekannter Teil " + teil)
	return _fertig()


func _brakk_setzen_px(p: Vector2) -> void:
	var k: Kommandant = spiel.kommandant
	k.oben = false
	spiel.ego._setze_fuss(p)
	spiel.ego.hoehe = 0.0
	k.position = p


func _boss_setzen(z: Vector2i) -> void:
	h.einheit.position = o.karte.mitte(z)
	h.einheit.zustand = Einheit.Zustand.BODEN
	h.einheit.set_meta("hebt_ab", 0.0)
	h._aktion = {}
	h._weg.clear()


func _eintraege(was: String) -> Array:
	return h.protokoll.filter(func(e: Dictionary) -> bool: return str(e.get("was", "")) == was)


## Boss und Brakk aufstellen (relativ zur Platzmitte); Brakk bleibt dort stehen.
func _stelle(boss: Vector2i, brakk: Vector2i) -> void:
	var kp := h.kampfplatz
	h.angriff = {}
	_boss_setzen(kp.mitte + boss)
	_brakk = o.karte.mitte(kp.mitte + brakk)
	_brakk_setzen_px(_brakk)
	h._bis_angriff = 999.0
	h._aktion_in = 999.0


## 1: Jagdanker.
func _teil_anker() -> bool:
	if _brakk != Vector2.ZERO:
		_brakk_setzen_px(_brakk)
	h._bis_angriff = 999.0
	h._aktion_in = 999.0
	match str(_p["phase"]):
		"start":
			_stelle(Vector2i(-6, 0), Vector2i(7, 0))
			_p["treffer"] = g.anker_treffer
			_p["weit"] = h.einheit.position.distance_to(_brakk) / Werte.ZELLE
			h.beginne_angriff("anker")
			_p["phase"] = "13"
			_brakk = Vector2.ZERO   # Brakk steht still, der Zug darf ihn bewegen
			_p["t"] = 0.0
		"13":
			if float(_p["t"]) > 4.0 or str(h.angriff.get("teil", "")) == "fenster" or (g.anker_treffer > int(_p["treffer"]) and h.angriff.is_empty()):
				var nah := h.einheit.position.distance_to(spiel.kommandant.position) / Werte.ZELLE
				pruefe(g.anker_treffer > int(_p["treffer"]) and nah < Werte.BOSS_GUNNER_ANKER_NAH + 0.6, "Jagdanker aus %.1f Feldern trifft, Brakk auf %.1f Felder herangezogen" % [float(_p["weit"]), nah])
				# aus 4 Feldern: der Schritt wird zum Sturmring
				var e := g.ersatz("anker", 4.0)
				pruefe(str(e[0]) == NemesisBossGunner.NAH_ERSATZ and str(g.ersatz("anker", 6.0)[0]) == "anker", "aus 4 Feldern wird der Jagdanker zu „%s“, aus 6 bleibt er" % str(e[0]))
				h.angriff = {}
				h.gebunden_rest = 0.0
				_stelle(Vector2i(-7, -4), Vector2i(6, 4))
				_p["weit"] = h.einheit.position.distance_to(_brakk) / Werte.ZELLE
				_p["lauf_vor"] = _eintraege("anker_lauf").size()
				_p["treffer"] = g.anker_treffer
				h.beginne_angriff("anker")
				_p["phase"] = "16"
				_p["t"] = 0.0
		"16":
			if str(h.angriff.get("teil", "")) == "ansage" and not _p.has("ansage_t"):
				_p["ansage_t"] = float(_p["t"])
			if g.anker_treffer > int(_p["treffer"]) or float(_p["t"]) > 5.0:
				var lief := _eintraege("anker_lauf").size() > int(_p["lauf_vor"])
				pruefe(float(_p["weit"]) > Werte.BOSS_GUNNER_ANKER_WEITE and lief and float(_p.get("ansage_t", 99.0)) <= Werte.BOSS_GUNNER_ANKER_ANLAUF + 0.05 and g.anker_treffer > int(_p["treffer"]),
					"aus %.1f Feldern läuft er erst an (Wurf-Ansage nach %.2f s), dann trifft der Anker" % [float(_p["weit"]), float(_p.get("ansage_t", -1.0))])
				return _fertig()
	return false


## 2: Sturmring – Zeiten aus dem Protokoll.
func _teil_sturm() -> bool:
	h._bis_angriff = 999.0
	h._aktion_in = 999.0
	match str(_p["phase"]):
		"start":
			_stelle(Vector2i(-5, 0), Vector2i(1, 0))
			_brakk = Vector2.ZERO
			_p["ab"] = h.protokoll.size()
			h.beginne_angriff("sturmring")
			_p["phase"] = "lauf"
			_p["t"] = 0.0
		"lauf":
			if str(h.angriff.get("teil", "")) == "fenster" or float(_p["t"]) > 10.0:
				var l: Array = h.protokoll.slice(int(_p["ab"]))
				var bei := func(was: String) -> Array: return l.filter(func(e: Dictionary) -> bool: return str(e.get("was", "")) == was).map(func(e: Dictionary) -> float: return float(e["bei"]))
				var ansage: Array = bei.call("sturmring_ansage")
				var schlag: Array = bei.call("sturmring_schlag")
				var ringe: Array = bei.call("schussring")
				var boden: Array = bei.call("bodenring")
				var ok := ansage.size() == 1 and schlag.size() == 1 and ringe.size() == Werte.BOSS_GUNNER_RING_ZAHL and boden.size() == Werte.BOSS_GUNNER_RING_ZAHL
				var texte := ""
				if ok:
					var a0: float = ansage[0]
					var s0: float = schlag[0]
					ok = absf(s0 - a0 - Werte.BOSS_GUNNER_STURM_ANSAGE) < 0.05 and absf(float(ringe[0]) - s0 - Werte.BOSS_GUNNER_RING_ERSTER) < 0.05
					for i in range(1, ringe.size()):
						ok = ok and absf(float(ringe[i]) - float(ringe[i - 1]) - Werte.BOSS_GUNNER_RING_TAKT) < 0.05
					for i in ringe.size():
						ok = ok and absf(float(ringe[i]) - float(boden[i]) - Werte.BOSS_GUNNER_RING_ANSAGE) < 0.05
					texte = "Ansage %.2f s, erster Ring +%.2f, Takt %s, Bodenring vorher %s" % [s0 - a0, float(ringe[0]) - s0,
						str(range(1, ringe.size()).map(func(i: int) -> float: return snappedf(float(ringe[i]) - float(ringe[i - 1]), 0.01))),
						str(range(ringe.size()).map(func(i: int) -> float: return snappedf(float(ringe[i]) - float(boden[i]), 0.01)))]
				pruefe(ok, "Sturmring-Zeiten: " + texte)
				pruefe(is_equal_approx(Werte.BOSS_GUNNER_RING_WEITE, 7.0) and str(g.ersatz("sturmring", 11.0)[0]) == "anker" and str(g.ersatz("sturmring", 11.0)[1]) == "sturmring" and str(g.ersatz("sturmring", 8.0)[0]) == "sturmring",
					"Ringweite %.0f; aus 11 Feldern erst der Jagdanker, dann der Sturmring" % Werte.BOSS_GUNNER_RING_WEITE)
				var ringtreffer: Dictionary = (h.zaehlung["treffer"] as Dictionary).get("ring", {"n": 0})
				pruefe(int((h.zaehlung["treffer"] as Dictionary).get("sturm", {"n": 0})["n"]) + int(ringtreffer["n"]) >= 1, "stehen bleiben kostet: %s" % str(h.zaehlung["treffer"]))
				return _fertig()
	return false


## 3: 4er-Salve – zweimal hintereinander auf den stehenden Brakk.
func _teil_salve() -> bool:
	var bg: BrakkGeschosse = spiel.brakk_geschosse
	h._bis_angriff = 999.0
	h._aktion_in = 999.0
	for gs: Dictionary in bg.geschosse:
		if str(gs.get("zaehl", "")) == "salve4" and not gs.has("_gesehen"):
			gs["_gesehen"] = true
			var linien := _eintraege("salve4_linie")
			var r0: Vector2 = linien.back()["dir"] if not linien.is_empty() else Vector2.ZERO
			_p["winkel_max"] = maxf(float(_p.get("winkel_max", 0.0)), rad_to_deg(absf((gs["r"] as Vector2).angle_to(r0))))
			_p["schuesse"] = int(_p.get("schuesse", 0)) + 1
	match str(_p["phase"]):
		"start":
			_stelle(Vector2i(-5, -2), Vector2i(3, 1))
			_p["treffer_vor"] = bg.getroffen
			h._letzte.clear()
			h.beginne_angriff("salve4")
			_p["phase"] = "eins"
			_p["t"] = 0.0
		"eins":
			if float(_p["t"]) >= 1.6:
				_p["treffer_1"] = bg.getroffen - int(_p["treffer_vor"])
				_p["treffer_vor"] = bg.getroffen
				h.angriff = {}
				h.beginne_angriff("salve4")   # direkt danach: Seitschritt, neue Linie
				_p["phase"] = "zwei"
				_p["t"] = 0.0
		"zwei":
			if float(_p["t"]) >= 2.0:
				var treffer_2: int = bg.getroffen - int(_p["treffer_vor"])
				var linien := _eintraege("salve4_linie")
				var seit := _eintraege("salve4_seit").size()
				pruefe(int(_p.get("schuesse", 0)) == 2 * Werte.BOSS_GUNNER_SALVE4_ZAHL and float(_p.get("winkel_max", 99.0)) <= 0.5,
					"4er-Salve entlang der Linie: %d Schüsse, größte Abweichung %.3f°" % [int(_p.get("schuesse", 0)), float(_p.get("winkel_max", 99.0))])
				pruefe(int(_p["treffer_1"]) >= 1 and int(_p["treffer_1"]) <= Werte.BOSS_GUNNER_SALVE4_MAX and treffer_2 <= Werte.BOSS_GUNNER_SALVE4_MAX,
					"stehen bleiben: %d und %d Treffer (höchstens %d je Salve)" % [int(_p["treffer_1"]), treffer_2, Werte.BOSS_GUNNER_SALVE4_MAX])
				var ok := linien.size() >= 2 and seit >= 1
				var winkel := 0.0
				var versatz := 0.0
				if ok:
					winkel = rad_to_deg(absf((linien[-1]["dir"] as Vector2).angle_to(linien[-2]["dir"] as Vector2)))
					versatz = (linien[-1]["von"] as Vector2).distance_to(linien[-2]["von"] as Vector2) / Werte.ZELLE
				pruefe(ok and winkel >= 5.0 and versatz >= 1.5, "zweite Salve: Seitschritt %.1f Felder, neuer Winkel %.1f°" % [versatz, winkel])
				return _fertig()
	return false


## 4: Minigun – außerhalb der Reichweite kein Schaden.
func _teil_minigun() -> bool:
	h._bis_angriff = 999.0
	h._aktion_in = 999.0
	match str(_p["phase"]):
		"start":
			_stelle(Vector2i(-6, 0), Vector2i(3, 0))
			g.minigun_schaden = 0.0
			h.beginne_angriff("minigun")
			_p["phase"] = "draussen"
			_p["t"] = 0.0
		"draussen":
			h.einheit.position = o.karte.mitte(h.kampfplatz.mitte + Vector2i(-6, 0))   # der Boss steht (sonst schöbe die Lichtwand Brakk hinein)
			_brakk_setzen_px(h.einheit.position + Vector2.RIGHT * 9.0 * Werte.ZELLE)   # Brakk hält 9 Felder Abstand
			if float(_p["t"]) >= 0.2 and not _p.has("ring"):
				_p["ring"] = g._rw != null and is_instance_valid(g._rw) and g._rw.visible
			if str(h.angriff.get("teil", "")) == "fenster" or float(_p["t"]) > 5.0:
				pruefe(g.minigun_schaden == 0.0 and bool(_p.get("ring", false)), "Minigun: Brakk auf 9 Feldern – Schaden %.2f (Ring sichtbar %s)" % [g.minigun_schaden, str(_p.get("ring", false))])
				_stelle(Vector2i(-6, 0), Vector2i(0, 0))
				h.beginne_angriff("minigun")
				_p["phase"] = "drinnen"
				_p["t"] = 0.0
		"drinnen":
			if str(h.angriff.get("teil", "")) == "fenster" or float(_p["t"]) > 5.0:
				pruefe(g.minigun_schaden > 0.1 and g.minigun_drin_zeit > 1.0, "Minigun: Brakk auf 6 Feldern – Schaden %.2f, %.1f s im Feuer" % [g.minigun_schaden, g.minigun_drin_zeit])
				return _fertig()
	return false


## 5: Krone – Deckel und Abgang.
func _teil_krone() -> bool:
	match str(_p["phase"]):
		"start":
			_stelle(Vector2i(-5, -3), Vector2i(2, 1))
			_brakk = o.karte.mitte(h.kampfplatz.mitte + Vector2i(2, 1))
			if not h._auf_den_wall(spiel.kommandant):
				pruefe(false, "keine Krone erreichbar")
				return _fertig()
			_p["ab"] = h.protokoll.size()
			_p["phase"] = "oben"
			_p["t"] = 0.0
		"oben":
			h._aktion_in = 999.0
			if h._aktion.is_empty() and h.einheit.zustand == Einheit.Zustand.AUF_POSTEN and h._bis_angriff > 0.6:
				h._bis_angriff = 0.6   # er greift von oben an (Abfolge)
			var l: Array = h.protokoll.slice(int(_p["ab"]))
			var herab := l.filter(func(e: Dictionary) -> bool: return str(e.get("was", "")) == "krone_absprung")
			if not herab.is_empty() and str(h.angriff.get("phase", "")) in ["sturm_lauf", "sturm_ansage", "sturm_ringe"]:
				var e: Dictionary = herab[0]
				e["angriffe"] = h._krone_angriffe
				pruefe(float(e["oben"]) <= Werte.BOSS_GUNNER_KRONE_MAX + 0.05 and int(e["angriffe"]) <= Werte.BOSS_GUNNER_KRONE_ANGRIFFE + 1, "oben %.1f s mit %d Angriffen (Deckel %.0f s oder %d), dann herunter" % [float(e["oben"]), int(e["angriffe"]), Werte.BOSS_GUNNER_KRONE_MAX, Werte.BOSS_GUNNER_KRONE_ANGRIFFE])
				pruefe(h.einheit.zustand == Einheit.Zustand.BODEN and g.kronen >= 1, "der Abgang ist der Sturmring (Phase %s), Kronen gezählt %d" % [str(h.angriff.get("phase", "")), g.kronen])
				return _fertig()
			if float(_p["t"]) > 12.0:
				pruefe(false, "nicht herunter nach 12 s (oben %s, oben_t %.1f, krone_angriffe %d, aktion %s, angriff %s, boden %s, protokoll %s)" % [str(h.einheit.zustand == Einheit.Zustand.AUF_POSTEN), g._oben_t, h._krone_angriffe, str(h._aktion.get("art", "")), str(h.angriff.get("art", "")), str(h.boden), str(h.protokoll.slice(int(_p["ab"])).map(func(e: Dictionary) -> String: return str(e.get("was", ""))))])
				return _fertig()
	return false
