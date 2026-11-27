extends SceneTree
## J (27.11., Paul): Bossarena, Plasmawerfer – Feinschliff (Prompt J), headless in der Bossarena:
##
##   godot --headless --path . --fixed-fps 60 -s werkzeuge/plasmaschliff_test.gd -- krone
##
## Teile (einer je Lauf):
##   krone – 1: Brakk auf einer Rand-Krone: Mörserkreise auf Kronenhöhe (einer auf seinem Feld, die übrigen auf Kronen oder am
##           Wallfuß, Spalt ≥ 0,6), der Sturm-Schritt wird zum Wallsprenger und stößt ihn zur Platzmitte (nie zur Lichtwand),
##           der Abpraller kommt als Hochpraller.
##   gel   – 2: Gel 20 s, höchstens 4 (das älteste weicht), nie auf dem Feldstreifen vor dem Wallring (Aufgänge).
##   schnell – 3: Mörser 0,35 s + 1,1 s, Abpraller 0,4 s und 0,2-s-Takt, jeder Abpraller verglüht nach 6 s.
##   glut  – 4: die Mörserkreise glühen 1,5 s nach (Stehen kostet ~10 %/s), das Fenster nach dem Mörser 0,9 s.

var spiel: Node
var o: Order24
var h: NemesisHerausforderer
var g: NemesisBossPlasma
var warte := 10
var schritt := 0
var fehler: Array[String] = []
var geprueft := 0
var teil := "krone"
var soll := 1
var _p := {"phase": "start", "t": 0.0}
var _brakk := Vector2.ZERO


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		teil = str(args[0])
	soll = {"krone": 4, "gel": 2, "schnell": 2, "glut": 2}.get(teil, 1)
	OS.set_environment("TD_KARTE_NAME", Werte.ORDER24_KARTE_NAME)
	Werte.lade_karte(Werte.ORDER24_KARTE_NAME)
	BrakkBossarena.laeuft = true
	BrakkBossarena.wahl = {"boss": "plasmawerfer", "stufe": 8, "ringe": "standard", "frei": [["laser", 1], ["markierung", 1], ["feuerteam", 1]],
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
		print("TEST PLASMASCHLIFF %s OK (%d Prüfungen)" % [teil, geprueft])
	else:
		print("TEST PLASMASCHLIFF %s FEHLER (%d): %s" % [teil, fehler.size(), "; ".join(PackedStringArray(fehler))])
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
			g = h.typ as NemesisBossPlasma
			schritt = 1
		elif o.zeit > 40.0:
			pruefe(false, "kein Duell nach 40 s")
			return _fertig()
		return false
	_p["t"] = float(_p["t"]) + 1.0 / 60.0
	match teil:
		"krone":
			return _teil_krone()
		"gel":
			return _teil_gel()
		"schnell":
			return _teil_schnell()
		"glut":
			return _teil_glut()
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




func _krone_setzen(z: Vector2i) -> void:
	var k: Kommandant = spiel.kommandant
	k.oben = true
	k.posten_zelle = z
	spiel.ego._setze_fuss(o.karte.mitte(z))
	spiel.ego.hoehe = spiel.hd.H
	spiel.ego.steig = 0.0
	k.position = o.karte.mitte(z)


## 1: Brakk auf einer Rand-Krone (an der linken Seite), der Plasmawerfer davor.
func _teil_krone() -> bool:
	var kp := h.kampfplatz
	var krone := kp.mitte + Vector2i(-BrakkKampfplatz._halb().x, -3)   # Randwall links (oberhalb der Lücke)
	h._bis_angriff = 999.0
	h._aktion_in = 999.0
	match str(_p["phase"]):
		"start":
			if o.karte.inhalt(krone) != Karte.WALL:
				pruefe(false, "keine Krone bei %s" % str(krone))
				return _fertig()
			h.angriff = {}
			_boss_setzen(kp.mitte + Vector2i(-1, -1))
			_krone_setzen(krone)
			_p["ab"] = h.protokoll.size()
			h.beginne_angriff("moerser")
			_p["phase"] = "moerser"
			_p["t"] = 0.0
		"moerser":
			_krone_setzen(krone)
			if float(_p["t"]) >= Werte.BOSS_PLASMA_MOERSER_ANSAGE + 0.1:
				var m := h.protokoll.slice(int(_p["ab"])).filter(func(e: Dictionary) -> bool: return str(e.get("was", "")) == "moerser")
				var ok := not m.is_empty()
				var text := "kein Mörser"
				if ok:
					var punkte: Array = m[0]["punkte"]
					var hoehen: Array = m[0]["hoehen"]
					var spalt := 99.0
					for i in punkte.size():
						for j in range(i + 1, punkte.size()):
							spalt = minf(spalt, (punkte[i] as Vector2).distance_to(punkte[j]) / Werte.ZELLE - 2.0 * Werte.BOSS_PLASMA_MOERSER_RADIUS)
					var neben := true
					for i in range(1, punkte.size()):
						var z := o.karte.zelle_bei(punkte[i])
						var hoch: bool = spiel.hd.ist_hoch(z)
						var fuss: bool = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN].any(func(d: Vector2i) -> bool: return spiel.hd.ist_hoch(z + d))
						neben = neben and (hoch or fuss)
					ok = is_equal_approx(float(hoehen[0]), spiel.hd.H) and spalt >= Werte.BOSS_PLASMA_MOERSER_SPALT - 0.01 and neben and punkte.size() >= 3
					text = "%d Kreise, Höhen %s (Krone %.2f), kleinster Spalt %.2f Felder, übrige auf Kronen/Wallfuß %s" % [punkte.size(), str(hoehen.map(func(x: float) -> float: return snappedf(x, 0.01))), spiel.hd.H, spalt, str(neben)]
				pruefe(ok, "Mörser auf die Krone: " + text)
				pruefe(str(g.ersatz("sturm", 5.0)[0]) == "wallsprenger", "auf der Krone wird der Sturm zum Wallsprenger")
				h.angriff = {}
				_p["mitte_vor"] = (spiel.kommandant as Kommandant).position.distance_to(o.karte.mitte(kp.mitte))
				_p["ab"] = h.protokoll.size()
				h.beginne_angriff("wallsprenger")
				_p["phase"] = "wall"
				_p["t"] = 0.0
		"wall":
			if not g._stoss.is_empty() or float(_p["t"]) < Werte.BOSS_PLASMA_WALL_ANSAGE + Werte.BOSS_PLASMA_WALL_FLUG - 0.05:
				if g._stoss.is_empty():
					_krone_setzen(krone)   # er steht still auf der Krone, bis der Wallsprenger platzt
				return false
			if float(_p["t"]) < Werte.BOSS_PLASMA_WALL_ANSAGE + Werte.BOSS_PLASMA_WALL_FLUG + 0.8:
				return false
			var k: Kommandant = spiel.kommandant
			var l := h.protokoll.slice(int(_p["ab"]))
			var w := l.filter(func(e: Dictionary) -> bool: return str(e.get("was", "")) == "wallsprenger")
			var nach := k.position.distance_to(o.karte.mitte(kp.mitte))
			pruefe(not w.is_empty() and bool(w[0]["trifft"]) and not k.oben and nach < float(_p["mitte_vor"]) - 1.0 and kp.im_innern(o.karte.zelle_bei(k.position)),
				"Wallsprenger: trifft %s, Brakk vom Wall %s, zur Mitte %.1f → %.1f Felder, im Platz %s" % [str(not w.is_empty() and bool(w[0]["trifft"])), str(not k.oben),
				float(_p["mitte_vor"]) / Werte.ZELLE, nach / Werte.ZELLE, str(kp.im_innern(o.karte.zelle_bei(k.position)))])
			h.angriff = {}
			_krone_setzen(krone)
			_p["ab"] = h.protokoll.size()
			h.beginne_angriff("abpraller")
			_p["phase"] = "praller"
			_p["t"] = 0.0
		"praller":
			_krone_setzen(krone)
			if float(_p["t"]) >= Werte.BOSS_PLASMA_PRALL_ANSAGE + 0.3:
				var hp := h.protokoll.slice(int(_p["ab"])).filter(func(e: Dictionary) -> bool: return str(e.get("was", "")) == "hochpraller")
				pruefe(hp.size() == 1 and absf(float(hp[0]["h1"]) - (spiel.hd.H + 0.5)) < 0.05, "Abpraller gegen die Krone: %d Hochpraller auf Höhe %.2f" % [hp.size(), float(hp[0]["h1"]) if not hp.is_empty() else -1.0])
				return _fertig()
	return false


## 2: Gel – Dauer, Deckel, Aufgänge frei.
func _teil_gel() -> bool:
	var kp := h.kampfplatz
	var hb := BrakkKampfplatz._halb()
	var orte: Array[Vector2i] = [kp.mitte + Vector2i(-hb.x + 1, 0), kp.mitte + Vector2i(hb.x - 2, -2), kp.mitte + Vector2i(0, -hb.y + 1), kp.mitte + Vector2i(2, hb.y - 2), kp.mitte]
	for z: Vector2i in orte:
		g._gel_legen(o.karte.mitte(z))
	var streifen := 0
	for gl: Dictionary in g.gele:
		var m: Vector2 = gl["mitte"]
		for y in range(kp.mitte.y - hb.y, kp.mitte.y + hb.y):
			for x in range(kp.mitte.x - hb.x, kp.mitte.x + hb.x):
				var z := Vector2i(x, y)
				if not kp.im_innern(z):
					continue
				var am_rand := [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN].any(func(d: Vector2i) -> bool: return not kp.im_innern(z + d))
				if am_rand and o.karte.mitte(z).distance_to(m) < (Werte.BOSS_PLASMA_GEL_RADIUS + 0.5) * Werte.ZELLE:
					streifen += 1
	pruefe(g.gele.size() == Werte.BOSS_PLASMA_GEL_MAX and g.gele.all(func(x: Dictionary) -> bool: return is_equal_approx(float(x["rest"]), Werte.BOSS_PLASMA_GEL_SEK)),
		"5 Gele gelegt: %d liegen (Deckel %d), je %.0f s" % [g.gele.size(), Werte.BOSS_PLASMA_GEL_MAX, Werte.BOSS_PLASMA_GEL_SEK])
	pruefe(streifen == 0, "kein Gel auf dem Streifen vor dem Wallring (%d Randfelder berührt)" % streifen)
	return _fertig()


## 3: schneller – Abpraller-Takt und Lebensdauer (Brakk steht hinter einer Ecke, damit sie lange prallen).
func _teil_schnell() -> bool:
	var bg: BrakkGeschosse = spiel.brakk_geschosse
	h._bis_angriff = 999.0
	h._aktion_in = 999.0
	match str(_p["phase"]):
		"start":
			h.angriff = {}
			_boss_setzen(h.kampfplatz.mitte + Vector2i(-4, 0))
			_brakk = o.karte.mitte(h.kampfplatz.mitte + Vector2i(4, 2))
			_brakk_setzen_px(_brakk)
			(spiel.kommandant as Kommandant).unverwundbar = 99.0   # die Abpraller treffen ihn nicht – sie prallen bis zum Verglühen
			_p["ab"] = h.protokoll.size()
			_p["vergl"] = bg.verglueht
			h.beginne_angriff("abpraller")
			_p["phase"] = "laeuft"
			_p["t"] = 0.0
		"laeuft":
			_brakk_setzen_px(_brakk)
			(spiel.kommandant as Kommandant).unverwundbar = 99.0
			var l := h.protokoll.slice(int(_p["ab"]))
			var schuesse := l.filter(func(e: Dictionary) -> bool: return str(e.get("was", "")) == "abpraller").map(func(e: Dictionary) -> float: return float(e["bei"]))
			if float(_p["t"]) >= Werte.BOSS_PLASMA_PRALL_ANSAGE + Werte.BOSS_PLASMA_PRALL_SEK + 1.5:
				var takt: Array = []
				for i in range(1, schuesse.size()):
					takt.append(snappedf(float(schuesse[i]) - float(schuesse[i - 1]), 0.01))
				pruefe(schuesse.size() == Werte.BOSS_PLASMA_PRALL_ZAHL and takt.all(func(d: float) -> bool: return absf(d - Werte.BOSS_PLASMA_PRALL_TAKT) < 0.03),
					"Abpraller: %d Schüsse im Takt %s (Soll %.1f s), Ansage %.1f s" % [schuesse.size(), str(takt), Werte.BOSS_PLASMA_PRALL_TAKT, Werte.BOSS_PLASMA_PRALL_ANSAGE])
				var reste := bg.geschosse.filter(func(x: Dictionary) -> bool: return str(x.get("art", "")) == "hf_plasma").size()
				pruefe(reste == 0 and bg.verglueht > int(_p["vergl"]), "nach %.1f s fliegt keiner mehr (%d verglüht, %d übrig)" % [Werte.BOSS_PLASMA_PRALL_SEK, bg.verglueht - int(_p["vergl"]), reste])
				(spiel.kommandant as Kommandant).unverwundbar = 0.0
				return _fertig()
	return false


## 4: Nachglühen – Brakk bleibt nach dem Einschlag 1,5 s im Kreis stehen (der Einschlag selbst trifft ihn nicht: unverwundbar
## bis kurz nach dem Einschlag).
func _teil_glut() -> bool:
	var k: Kommandant = spiel.kommandant
	h._bis_angriff = 999.0
	h._aktion_in = 999.0
	match str(_p["phase"]):
		"start":
			h.angriff = {}
			h.schritt_jetzt = {"fenster": Werte.BOSS_PLASMA_FENSTER_MOERSER, "bewegung": 0.6, "i": 0, "art": "moerser"}
			_boss_setzen(h.kampfplatz.mitte + Vector2i(-4, 0))
			_brakk = o.karte.mitte(h.kampfplatz.mitte + Vector2i(2, 0))
			_brakk_setzen_px(_brakk)
			g.glut_schaden = 0.0
			_p["ab"] = h.protokoll.size()
			h.beginne_angriff("moerser")
			_p["phase"] = "laeuft"
			_p["t"] = 0.0
		"laeuft":
			_brakk_setzen_px(_brakk)
			var einschlag := Werte.BOSS_PLASMA_MOERSER_ANSAGE + Werte.BOSS_PLASMA_MOERSER_FLUG
			k.unverwundbar = 0.05 if float(_p["t"]) < einschlag + 0.1 else 0.0
			if float(_p["t"]) >= einschlag + Werte.BOSS_PLASMA_GLUT_SEK + 0.3:
				var soll := Werte.BOSS_PLASMA_GLUT_JE_SEK * (Werte.BOSS_PLASMA_GLUT_SEK - 0.1)
				pruefe(absf(g.glut_schaden - soll) < 0.04 and g.gluten.is_empty(), "Nachglühen: Stehen kostet %.3f Treffer (Soll ~%.3f), danach erloschen" % [g.glut_schaden, soll])
				var f := h.protokoll.slice(int(_p["ab"])).filter(func(e: Dictionary) -> bool: return str(e.get("was", "")) == "angriff" and str(e.get("art", "")) == "moerser")
				pruefe(not f.is_empty() and absf(float(f[0]["fenster"]) - Werte.BOSS_PLASMA_FENSTER_MOERSER) < 0.01, "Fenster nach dem Mörser %.2f s" % (float(f[0]["fenster"]) if not f.is_empty() else -1.0))
				return _fertig()
	return false
