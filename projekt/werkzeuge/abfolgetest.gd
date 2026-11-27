extends SceneTree
## G2 (27.11., Paul): feste Abfolgen der Bosse headless, in der Bossarena – je Boss ein Lauf:
##
##   godot --headless --path . --fixed-fps 60 -s werkzeuge/abfolgetest.gd -- scharf|gunner|plasma|sonde
##
## Brakk steht im Platz und hält durch (Leben aufgefüllt), der Boss greift an. Nach PHASE1_SEK fällt der Boss auf 45 %
## (Phase 2), nach weiteren PHASE2_SEK endet der Lauf. Geprüft: die Schritte kommen in Tabellenreihenfolge (Log),
## die Eröffnung der Phase 2 kommt zuerst, gekoppelte Angriffe folgen ohne Fenster, Fenster und Bewegung wie in der Tabelle.

const ARTEN := {"scharf": "scharfschuetze", "gunner": "technogunner", "plasma": "plasmawerfer", "sonde": "sonde"}
const PHASE1_SEK := 45.0
const PHASE2_SEK := 45.0
const SOLL := 9               # dazu: Technogunner +3

var spiel: Node
var o: Order24
var h: NemesisHerausforderer
var warte := 10
var schritt := 0
var fehler: Array[String] = []
var geprueft := 0
var art := "scharf"
var t0 := 0.0
var p2_ab := 0          # Index in abfolge_log, ab dem Phase 2 gilt
var frei_sek := 0.0     # G2-4: so lange lief er frei (kein Angriff, keine Aktion) …
var versuche := 0       # … und so oft setzte er dabei zu Sprung/Tumble an (sein Takt wurde neu gesetzt)
var _takt_vorher := 0.0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		art = str(args[0])
	OS.set_environment("TD_KARTE_NAME", Werte.ORDER24_KARTE_NAME)
	Werte.lade_karte(Werte.ORDER24_KARTE_NAME)
	BrakkBossarena.laeuft = true
	BrakkBossarena.wahl = {"boss": str(ARTEN[art]), "stufe": 6, "ringe": "keins", "frei": [["laser", 1], ["markierung", 1], ["feuerteam", 1]],
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
	if geprueft < _soll():
		fehler.append("nur %d von %d Prüfungen gelaufen" % [geprueft, _soll()])
	paused = false
	if fehler.is_empty():
		print("TEST ABFOLGE %s OK (%d Prüfungen)" % [art, geprueft])
	else:
		print("TEST ABFOLGE %s FEHLER (%d): %s" % [art, fehler.size(), "; ".join(PackedStringArray(fehler))])
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
	_pruefe_bodenfeuer()
	if schritt >= 1 and h.zustand == "duell" and h.typ != null:   # G2-4: Takt in freier Zeit messen
		if not h.greift_an() and h._aktion.is_empty() and not h.typ.steht():
			frei_sek += 1.0 / 60.0
		if h._aktion_in > _takt_vorher + 0.3:
			versuche += 1
		_takt_vorher = h._aktion_in
	match schritt:
		0:
			if h.zustand == "duell" and h.einzug.is_empty() and h.kampfplatz.zu():
				h._vergeltung_in = 9999.0   # die Abfolge pur (Vergeltung ersetzt sonst Schritte)
				t0 = o.zeit
				schritt = 1
			elif o.zeit > 40.0:
				pruefe(false, "kein Duell nach 40 s")
				return _fertig()
		1:
			if o.zeit - t0 >= PHASE1_SEK:
				_pruefe_folge(h.abfolge_log.slice(0), h.typ.abfolge(false), "P1")
				p2_ab = h.abfolge_log.size()
				h.einheit.leben = h.einheit.max_leben * 0.45
				t0 = o.zeit
				schritt = 2
		2:
			if h.zustand != "duell":
				pruefe(false, "Duell endete vorzeitig")
				return _fertig()
			if h.einheit.leben < h.einheit.max_leben * 0.3:
				h.einheit.leben = h.einheit.max_leben * 0.45   # Phase 2 halten
			if o.zeit - t0 >= (PHASE2_SEK + 30.0 if art == "sonde" else PHASE2_SEK):   # Sonde 7: der Verstärkungsruf dauert bis zu 25 s
				var p2: Array = h.abfolge_log.slice(p2_ab)
				var vorn: Array = h.typ.eroeffnung(true)
				if art in ["scharf", "sonde"]:
					pruefe(not p2.is_empty() and int(p2[0]["i"]) == -1 and str(p2[0]["art"]) == ("zielmarkierung" if art == "scharf" else "heil"), "P2: zuerst die Eröffnung (%s)" % (str(p2[0]["art"]) if not p2.is_empty() else "–"))
				else:
					pruefe(vorn.is_empty(), "P2: keine Eröffnung")
				_pruefe_folge(p2.filter(func(x: Dictionary) -> bool: return int(x["i"]) >= 0), h.typ.abfolge(true), "P2")
				_pruefe_fenster()
				_pruefe_druck()
				if art == "plasma":
					_pruefe_plasma()
				if art == "gunner":
					_pruefe_gunner()
				return _fertig()
	return false


## Die Folge der Schritte (ohne gekoppelte): jeder nächste Index ist der nächste der Tabelle, übersprungen werden nur
## Schritte, die gerade nicht gingen – höchstens 25 % der Übergänge dürfen springen.
func _pruefe_folge(log: Array, tabelle: Array, phase: String) -> void:
	var folge := log.filter(func(x: Dictionary) -> bool: return not bool(x.get("dann", false)) and int(x["i"]) >= 0)
	var texte := PackedStringArray(log.map(func(x: Dictionary) -> String: return ("→" if bool(x.get("dann", false)) else "") + "%d:%s" % [int(x["i"]), str(x["art"])]))
	print("FOLGE %s %s" % [phase, " ".join(texte)])
	var n := tabelle.size()
	var gut := 0
	var spruenge := 0
	for j in range(1, folge.size()):
		var d := posmod(int(folge[j]["i"]) - int(folge[j - 1]["i"]), n)
		var legitim := d > 1
		for m in range(1, d):   # übersprungen: nur Schritte, die grundsätzlich nicht gehen (z. B. noch ohne Sprint-Salve)
			var st: Dictionary = tabelle[(int(folge[j - 1]["i"]) + m) % n]
			var arten: Array = st["wahl"] if st.has("wahl") else [st["a"]]
			legitim = legitim and not arten.any(func(a: String) -> bool: return h.typ.kann(a, h.einheit.position.distance_to(spiel.kommandant.position) / Werte.ZELLE))
		if d == 1 or legitim:
			gut += 1
		else:
			spruenge += 1
	pruefe(folge.size() >= 3 and spruenge <= maxi(1, (folge.size() - 1) / 4), "%s: %d Schritte in Tabellenreihenfolge, %d Sprünge" % [phase, gut, spruenge])
	var passt := true
	for x: Dictionary in folge:
		var st: Dictionary = tabelle[int(x["i"])]
		var arten: Array = st["wahl"] if st.has("wahl") else [st["a"]]
		passt = passt and arten.has(str(x["art"]))
	pruefe(passt, "%s: jeder Angriff gehört zu seinem Schritt" % phase)
	var gekoppelt := log.filter(func(x: Dictionary) -> bool: return bool(x.get("dann", false)))
	if tabelle.any(func(st: Dictionary) -> bool: return st.has("dann")):
		print("GEKOPPELT %s: %d" % [phase, gekoppelt.size()])


var boden_geprueft := ""   # Ergebnis der ersten vollen Bodenfeuer-Prüfung ("" = noch keine)


## G2-3: Sobald ein Bodenfeuer voll ausgebreitet ist: alle Bodenfelder im Platz brennen, kein Wall (Krone) ist dabei.
func _pruefe_bodenfeuer() -> void:
	if boden_geprueft != "" or h == null or h.bodenfeuer.is_empty():
		return
	if float(h.bodenfeuer["t"]) < Werte.BOSS_DRUCK_BODEN_AUSBREITUNG + Werte.BOSS_DRUCK_BODEN_WARNUNG + 0.05:
		return
	var kp := h.kampfplatz
	var hb := BrakkKampfplatz._halb()
	var boden := 0
	var brennt := 0
	var kronen_brennen := 0
	for y in range(kp.mitte.y - hb.y, kp.mitte.y + hb.y):
		for x in range(kp.mitte.x - hb.x, kp.mitte.x + hb.x):
			var z := Vector2i(x, y)
			if o.karte.inhalt(z) == Karte.WALL:
				if h.brennt(z):
					kronen_brennen += 1
			elif kp.im_innern(z):
				boden += 1
				if h.brennt(z):
					brennt += 1
	boden_geprueft = "Boden %d/%d brennt, Wälle/Kronen brennend %d, Schaden am Boden %.2f" % [brennt, boden, kronen_brennen, h.bodenfeuer_schaden]
	pruefe(boden > 20 and brennt == boden and kronen_brennen == 0 and h.bodenfeuer_schaden > 0.0, "Anker-Zwang: " + boden_geprueft)


## G2-3: Fenster in der Druckphase kurz, danach die Belohnung; gezählt; Bodenfeuer nur beim Scharfschützen und Sonde 7.
func _pruefe_druck() -> void:
	var kurz: Array = []
	var lang: Array = []
	for e: Dictionary in h.protokoll:
		if str(e.get("was", "")) == "angriff" and bool(e.get("druck", false)):
			(lang if bool(e.get("druck_ende", false)) else kurz).append(snappedf(float(e["fenster"]), 0.01))
	pruefe(not lang.is_empty() and kurz.all(func(f: float) -> bool: return f <= 0.5) and lang.all(func(f: float) -> bool: return f >= 2.0 and f <= 2.5),
		"Druck: Fenster %s, danach Belohnung %s" % [str(kurz), str(lang)])
	pruefe(int(h.zaehlung.get("druckphasen", 0)) >= 1, "Druckphasen gezählt: %d" % int(h.zaehlung.get("druckphasen", 0)))
	var feuer := h.protokoll.filter(func(e: Dictionary) -> bool: return str(e.get("was", "")) == "bodenfeuer").size()
	if art in ["scharf", "sonde"]:
		if boden_geprueft == "":
			pruefe(false, "Anker-Zwang: kein volles Bodenfeuer (%d begonnen)" % feuer)
	else:
		pruefe(feuer == 0, "kein Bodenfeuer beim %s" % art)


## G2-4: Technogunner – Sprint-Salven (1,2 s, drei Schüsse, deutlich schneller als sein Lauf), 5er-Salven im 0,08-s-Takt,
## Sprung/Tumble im 1-s-Takt; im Fenster steht er still.
func _pruefe_gunner() -> void:
	var ende := h.protokoll.filter(func(e: Dictionary) -> bool: return str(e.get("was", "")) == "sprint_ende")
	var weit := h.protokoll.filter(func(e: Dictionary) -> bool: return str(e.get("was", "")) == "sprint")
	var ok := not ende.is_empty() and ende.all(func(e: Dictionary) -> bool: return int(e["schuesse"]) == Werte.BOSS_GUNNER_SPRINT_SCHUESSE and absf(float(e["dauer"]) - Werte.BOSS_GUNNER_SPRINT_SEK) < 0.05)
	pruefe(ok, "Sprint-Salven: %d, je %s Schüsse, Weite %s Felder" % [ende.size(), str(ende.map(func(e: Dictionary) -> int: return int(e["schuesse"]))), str(weit.map(func(e: Dictionary) -> float: return snappedf(float(e["weit"]), 0.1)))])
	var schuesse := h.protokoll.filter(func(e: Dictionary) -> bool: return str(e.get("was", "")) == "salve5_schuss").map(func(e: Dictionary) -> float: return float(e["bei"]))
	var abstaende: Array = []
	for j in range(1, schuesse.size()):
		var d: float = schuesse[j] - schuesse[j - 1]
		if d < 0.3:
			abstaende.append(snappedf(d, 0.01))
	pruefe(not abstaende.is_empty() and abstaende.all(func(d: float) -> bool: return d <= 0.1), "5er-Salve im Takt %s s (Soll %.2f)" % [str(abstaende.slice(0, 8)), Werte.BOSS_GUNNER_SALVE5_TAKT])
	# 27.11. (Paul: „Nur Prüfung korrigieren“): nicht die Zahl in 90 s – die hängt daran, wie lange er angreift (meist 60–75 s) –,
	# sondern der Takt in freier Zeit: mindestens 0,8 Ansätze je Sekunde (1-s-Takt, ±25 % Zufall)
	var je_sek := float(versuche) / maxf(0.1, frei_sek)
	pruefe(is_equal_approx(h.typ.takt(4.0), Werte.BOSS_GUNNER_AKTION_TAKT) and frei_sek >= 3.0 and je_sek >= 0.8,
		"Sprung/Tumble im %.1f-s-Takt: %d Ansätze in %.1f s freier Zeit (%.2f je s), gezählt %d" % [h.typ.takt(4.0), versuche, frei_sek, je_sek, h.zaehler["sprung"] + h.zaehler["tumble"]])


## Fenster aus dem Protokoll: nach Schritten der Abfolge so lang wie in der Tabelle (± 0,05 s), gekoppelte ohne Fenster.
func _pruefe_fenster() -> void:
	var falsch := 0
	var gezaehlt := 0
	for e: Dictionary in h.protokoll:
		if str(e.get("was", "")) == "angriff" and e.has("dann"):
			gezaehlt += 1
			if float(e["fenster"]) > 0.0:
				falsch += 1
	pruefe(falsch == 0, "gekoppelte Angriffe ohne Fenster dazwischen (%d)" % gezaehlt)


func _soll() -> int:
	return SOLL + (3 if art == "gunner" else 0) + (1 if art == "plasma" else 0)


## G2-5: Plasmawerfer – der Sturmschild hält nur im Ansturm und nur von vorn; beim Aufprall zersprang er.
func _pruefe_plasma() -> void:
	var p := h.typ as NemesisBossPlasma
	var k: Kommandant = spiel.kommandant
	var zu := (k.position - h.einheit.position).normalized()
	var alt := h.angriff
	h.angriff = {"art": "sturm", "teil": "anlauf"}
	p.schild_richtung = zu
	var vorn := p.vor_treffer(100.0)
	p.schild_richtung = zu.orthogonal()
	var seite := p.vor_treffer(100.0)
	p.schild_richtung = -zu
	var hinten := p.vor_treffer(100.0)
	p.schild_richtung = zu
	h.angriff = {"art": "sturm", "teil": "fenster"}
	var fenster := p.vor_treffer(100.0)
	h.angriff = {"art": "moerser", "teil": "ansage"}
	var anders := p.vor_treffer(100.0)
	h.angriff = alt
	pruefe(is_equal_approx(vorn, 25.0) and seite == 100.0 and hinten == 100.0 and fenster == 100.0 and anders == 100.0 and p.schild_zersprungen >= 1,
		"Sturmschild: vorn %.0f, Seite %.0f, hinten %.0f, im Fenster %.0f, beim Mörser %.0f; %d× zersprungen" % [vorn, seite, hinten, fenster, anders, p.schild_zersprungen])
