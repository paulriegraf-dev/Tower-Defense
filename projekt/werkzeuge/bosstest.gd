extends SceneTree
## C2 (26.11., Paul): Befehl 24 – die Bosstypen des Herausforderers, headless, je Art ein Lauf:
##
##   godot --headless --path . --fixed-fps 60 -s werkzeuge/bosstest.gd -- scharf|gunner|plasma
##
## Der Herausforderer tritt im Kampfplatz an (Person der gewünschten Art), dann prüft der Test die Angriffe Bild für Bild:
## Folge ohne Dreifachwiederholung, Ansage vor jedem Treffer, Reichweiten, Phase 2 und die Deckel. Schreibt nur
## user://nemesis_bosstest.json. Am Ende „TEST BOSS <art> OK“ oder die Fehler.

const ARTEN := {"scharf": "scharfschuetze", "gunner": "technogunner", "plasma": "plasmawerfer", "sonde": "technogunner"}
const SOLL := {"scharf": 16, "gunner": 16, "plasma": 14, "sonde": 18}   # so viele Prüfungen muss jede Art schaffen (Skriptfehler brechen still ab)

var spiel: Node
var o: Order24
var h: NemesisHerausforderer
var kp: BrakkKampfplatz
var warte := 10
var schritt := 0
var fehler: Array[String] = []
var geprueft := 0
var art := "scharf"
var t0 := 0.0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		art = str(args[0])
	Nemesis.datei = "user://nemesis_bosstest.json"
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
	r["jagd_start"] = 9999
	r["vorstoss"] = false
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
	if geprueft < int(SOLL.get(art, 0)):
		fehler.append("nur %d von %d Prüfungen gelaufen" % [geprueft, int(SOLL.get(art, 0))])
	Nemesis.zuruecksetzen()
	if fehler.is_empty():
		print("TEST BOSS %s OK (%d Prüfungen)" % [art, geprueft])
	else:
		print("TEST BOSS %s FEHLER (%d): %s" % [art, fehler.size(), "; ".join(PackedStringArray(fehler))])
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
	h = o.herausforderer
	kp = h.kampfplatz
	var k: Kommandant = spiel.kommandant
	match schritt:
		0:
			if o.zeit > 2.0:
				var n := o.nemesis
				n.personen = []
				n.neue_person(str(ARTEN[art]), 3, "Testboss", "der Test")
				if art == "sonde":   # C3: zu Minute 14, sicher Sonde 7
					h.zeiten = [0.0, o.zeit + 11.0]
					h.naechste = 1
					h.sonde_erzwingen = true
				else:
					h.zeiten = [o.zeit + 11.0, o.zeit + 9999.0]
					h.naechste = 0
				t0 = o.zeit
				schritt = 1
		1:
			k.leben = k.max_leben
			if h.zustand == "duell" and h.einzug.is_empty() and kp.zu() and kp._plan.is_empty():
				pruefe(h.typ != null and str(h.person["art"]) == str(ARTEN[art]), "Typ %s für %s" % [h.typ.get_script().get_global_name() if h.typ != null else "–", str(h.person["art"])])
				match art:
					"scharf":
						_scharf()
					"gunner":
						_gunner()
					"plasma":
						_plasma()
					"sonde":
						_sonde()
				return _fertig()
			elif o.zeit - t0 > 40.0:
				pruefe(false, "kein Duell im Kampfplatz nach 40 s")
				return _fertig()
	return false


# ------------------------------------------------------------------ Hilfen

## Brakk und der Boss an feste Felder im Platz (Zeile -1 ist innen frei), nichts läuft.
func _stelle(brakk: Vector2i, boss: Vector2i) -> void:
	var k: Kommandant = spiel.kommandant
	var bg: BrakkGeschosse = spiel.brakk_geschosse
	bg.leeren()
	k.oben = false
	k.unverwundbar = 0.0
	spiel.ego.hoehe = 0.0
	spiel.ego._setze_fuss(o.karte.mitte(_feld(kp.mitte + brakk)))
	h.einheit.zustand = Einheit.Zustand.BODEN
	h.einheit.position = o.karte.mitte(_feld(kp.mitte + boss))
	h.angriff = {}
	h._aktion = {}
	h._weg.clear()
	h._wall_rest = 0.0
	h._wall_abkling = 999.0
	h._bis_angriff = 999.0
	h._vergeltung_in = 999.0


## `sek` Sekunden Bild für Bild: Herausforderer, Geschosse, Kampfplatz. Brakk bleibt stehen (oder `jeder` macht etwas).
## Gibt den Schaden an Brakk in Treffern zurück.
func _lauf(sek: float, jeder: Callable = Callable()) -> float:
	var k: Kommandant = spiel.kommandant
	var bg: BrakkGeschosse = spiel.brakk_geschosse
	var vorher := _sein_schaden()
	for i in int(sek * 60.0):
		k.leben = k.max_leben
		h._vergeltung_in = 999.0
		h.schritt(1.0 / 60.0)
		bg.weiter(Werte.SPIELTEMPO / 60.0)
		kp.schritt(1.0 / 60.0)
		pass
		if jeder.is_valid():
			jeder.call(i)
	return (_sein_schaden() - vorher) / h.schaden()


func _eintraege(was: String) -> Array:
	return h.protokoll.filter(func(x: Dictionary) -> bool: return str(x["was"]) == was)


## Nie dreimal derselbe, über 60 Ziehungen (die Wahl hängt nur an Abstand und den letzten Angriffen).
func _folge(abstand: float, regel: Callable) -> void:
	var alt := h._letzte.duplicate()
	h._letzte.clear()
	var dreimal := 0
	var regel_bruch := 0
	for i in 60:
		var a := h.naechster_angriff(abstand)
		if h._letzte.size() >= 2 and str(h._letzte[-1]) == a and str(h._letzte[-2]) == a:
			dreimal += 1
		if not regel.call(h._letzte, a):
			regel_bruch += 1
		h._letzte.append(a)
	pruefe(dreimal == 0 and regel_bruch == 0, "Folge über 60 Angriffe ohne Dreifachwiederholung (%s …; Regelbrüche %d)" % [" ".join(PackedStringArray(h._letzte.slice(0, 10))), regel_bruch])
	h._letzte = alt


## Jeder Angriff dieses Laufs war mindestens 0,5 s angesagt.
func _ansagen_pruefen() -> void:
	var kurz := _eintraege("angriff").filter(func(x: Dictionary) -> bool: return float(x["angesagt"]) < 0.5)
	pruefe(kurz.is_empty() and not _eintraege("angriff").is_empty(), "%d Angriffe, jeder ≥ 0,5 s angesagt (zu kurz: %d)" % [_eintraege("angriff").size(), kurz.size()])


# ------------------------------------------------------------------ Scharfschütze

func _scharf() -> void:
	var s := h.typ as NemesisBossScharf
	var k: Kommandant = spiel.kommandant
	pruefe(s.abstand(5.0) == Werte.BOSS_SNIPER_ABSTAND_MIN and is_equal_approx(s.abstand(8.0), 10.4), "Abstand ×1,3, mindestens 8 Felder")
	_folge(6.0, func(_letzte: Array, a: String) -> bool: return a != "kugel")   # F5: nach einem Sturm kein erzwungener Laser mehr
	# Salve in vier Wellen: wer stehen bleibt, wird getroffen
	_stelle(Vector2i(5, -1), Vector2i(-3, -1))
	h.beginne_angriff("salve")
	var treffer := _lauf(3.0)
	pruefe(_eintraege("faecher").size() == Werte.BOSS_SNIPER_SALVE_WELLEN and treffer > 0.2, "Salve: %d Fächer, stehen bleiben kostet %.2f Treffer" % [_eintraege("faecher").size(), treffer])
	# Laservisier in Reichweite: zielen (ANVISIERT), dann Strahl
	_stelle(Vector2i(5, -1), Vector2i(-3, -1))
	var anvisiert := [0]
	h.beginne_angriff("laser")
	var laser := _lauf(6.0, func(_i: int) -> void:
		if h.anvisiert != Vector2.INF:
			anvisiert[0] += 1)
	var ziel := _eintraege("laser_ziel")
	pruefe(not ziel.is_empty() and anvisiert[0] >= int(Werte.BOSS_SNIPER_LASER_ZIELEN * 60.0) and laser > 0.8 and laser <= Werte.BOSS_SNIPER_LASER_JE_SEK * Werte.BOSS_SNIPER_LASER_SEK + 0.05,
		"Laservisier: %d Bilder ANVISIERT, Strahl %.2f Treffer in %.2f s (höchstens %.2f)" % [anvisiert[0], laser, float((_eintraege("laser_ende").back() as Dictionary).get("dauer", 0.0)) if not _eintraege("laser_ende").is_empty() else 0.0, Werte.BOSS_SNIPER_LASER_JE_SEK * Werte.BOSS_SNIPER_LASER_SEK])
	# außerhalb der Reichweite: kein Schaden
	_stelle(Vector2i(6, -1), Vector2i(-7, -1))
	h.beginne_angriff("laser")
	h.angriff["phase"] = "strahl"
	h.angriff["angesagt"] = Werte.BOSS_SNIPER_LASER_ZIELEN   # (die Ansage ist hier übersprungen)
	var weit := h.einheit.position.distance_to(k.position) / Werte.ZELLE
	var vorher := s.laser_schaden
	var aussen := _lauf(1.0)
	pruefe(weit > Werte.BOSS_SNIPER_LASER_WEITE and s.laser_schaden == vorher and aussen == 0.0 and h.angriff.get("teil", "") != "typ", "Laser bei %.1f Feldern: 0 Schaden, der Strahl bricht ab" % weit)
	# Anker auf die Krone
	_stelle(Vector2i(5, -1), Vector2i(-3, -1))
	h._wall_abkling = 0.0
	h.kennwerte["wall"] = true
	_lauf(4.0)
	pruefe(not _eintraege("anker").is_empty() and int(h.zaehler["wall"]) >= 1, "mit dem Anker auf die Krone (%d-mal)" % _eintraege("anker").size())
	_scharf_120()
	# Phase 2: Zielmarkierung – genau sechs Stellungen, keine nach
	_stelle(Vector2i(5, -1), Vector2i(-3, -1))
	h.einheit.leben = h.einheit.max_leben * 0.4
	_lauf(0.1)
	pruefe(h.wut and h.naechster_angriff(6.0) == "zielmarkierung", "unter 50 %: als Nächstes die Zielmarkierung")
	h.beginne_angriff("zielmarkierung")
	_lauf(4.5)
	var stellungen := Werte.BOSS_SNIPER_STELLUNGEN.filter(func(r: Vector2i) -> bool: return o.karte.ausbau.get(kp.mitte + r, -1) == Karte.STELLUNG)
	pruefe(s.schuetzen.size() == 6 and stellungen.size() == 6 and _eintraege("stellung").size() == 6, "Zielmarkierung: %d Stellungen mit %d Schützen" % [stellungen.size(), s.schuetzen.size()])
	(s.schuetzen[0]["e"] as Einheit).nimm_schaden(999999.0)
	h._bis_angriff = 999.0
	var vorher_stellung := _eintraege("stellung").size()
	_lauf(6.0, func(_i: int) -> void: h._bis_angriff = 999.0)
	var leben := s.schuetzen.filter(func(x: Dictionary) -> bool: return Nemesis.lebt(x["e"])).size()
	var schuesse := _eintraege("stellung_schuss")
	var kurz := schuesse.filter(func(x: Dictionary) -> bool: return float(x["angesagt"]) < Werte.BOSS_SNIPER_STELLUNG_ANSAGE - 0.05)
	pruefe(leben == 5 and _eintraege("stellung").size() == vorher_stellung and not schuesse.is_empty() and kurz.is_empty(), "einer gefallen: %d stehen, keiner nach; %d Schüsse, alle %.1f s vorher aufgeleuchtet" % [leben, schuesse.size(), Werte.BOSS_SNIPER_STELLUNG_ANSAGE])
	var drauf := Werte.BOSS_SNIPER_STELLUNGEN.any(func(r: Vector2i) -> bool: return o.karte.zelle_bei(h.einheit.position) == kp.mitte + r)
	pruefe(not drauf and h.naechster_angriff(6.0) != "zielmarkierung", "der Boss geht nicht in die Stellungen, die Markierung kommt nur einmal")
	_ansagen_pruefen()
	# Ende: Schützen weg, mit dem Platz verschwinden die Stellungen
	var merk_gesetzt := kp.gesetzt.duplicate()
	h.einheit.nimm_schaden(9999999.0)
	h.weiter(0.0)
	pruefe(s.schuetzen.is_empty() and h.zustand == "ruhe", "vertrieben: die Schützen der Stellungen sind weg")
	for i in 1800:
		kp.schritt(1.0 / 60.0)
		if kp.zustand == "aus":
			break
	var bleiben := Werte.BOSS_SNIPER_STELLUNGEN.filter(func(r: Vector2i) -> bool: return not (merk_gesetzt as Array).has(kp.mitte + r))
	pruefe(kp.zustand == "aus" and bleiben.is_empty(), "die Stellungen gehörten zum Platz und sind mit ihm aufgestiegen")


## F5 (26.11., Paul): 120 s freies Duell (Brakk steht 8 Felder entfernt). Laservisier mindestens 25 % der Angriffe;
## Kronenwechsel nur zwischen zwei Angriffen, von jeder Krone mindestens ein Angriff.
func _scharf_120() -> void:
	_stelle(Vector2i(5, -1), Vector2i(-3, -1))
	h._wall_abkling = 0.0
	h._bis_angriff = 1.0
	h.kennwerte["wall"] = true
	var vorher: Dictionary = h.angriffe_je_art.duplicate()
	var ohne_vorher := h.kronen_ohne_angriff
	var gelesen := [h.protokoll.size()]
	var anker := [0, 0]   # [Kronenwechsel, davon während eines Angriffs]
	var erwartung := [0.0, 0]   # [Summe der Laser-Wahrscheinlichkeiten, Zahl der Wahlen]
	_lauf(120.0, func(_i: int) -> void:
		while gelesen[0] < h.protokoll.size():
			var x: Dictionary = h.protokoll[gelesen[0]]
			if str(x["was"]) == "anker":
				anker[0] += 1
				if not h.angriff.is_empty():
					anker[1] += 1
			elif str(x["was"]) == "wahl":
				var g: Dictionary = (x["gewichte"] as Dictionary).duplicate()
				var l: Array = x["letzte"]
				if g.size() > 1 and l.size() >= 2 and str(l[-1]) == str(l[-2]):
					g.erase(str(l[-1]))   # wie waehle_angriff: nie dreimal derselbe
				var s := 0.0
				for a: String in g:
					s += float(g[a])
				erwartung[0] += float(g.get("laser", 0.0)) / maxf(0.001, s)
				erwartung[1] += 1
			gelesen[0] += 1)
	var je := {}
	var summe := 0
	for a: String in h.angriffe_je_art:
		je[a] = int(h.angriffe_je_art[a]) - int(vorher.get(a, 0))
		summe += int(je[a])
	var laser := float(je.get("laser", 0)) / maxf(1.0, float(summe))
	print("     Angriffe je Art in 120 s: %s" % str(je))
	var erwartet := float(erwartung[0]) / maxf(1.0, float(erwartung[1]))
	pruefe(summe >= 10 and erwartet >= 0.25 and laser >= 0.15, "120-s-Duell: %d Angriffe, Laservisier erwartet %.0f %% (mindestens 25 %%), gezogen %.0f %%" % [summe, erwartet * 100.0, laser * 100.0])
	pruefe(anker[0] >= 2 and anker[1] == 0 and h.kronen_ohne_angriff == ohne_vorher,
		"120-s-Duell: %d Kronenwechsel (alle %.0f s möglich), keiner während eines Angriffs, keine Krone ohne Angriff verlassen" % [anker[0], Werte.BOSS_SNIPER_KRONE_SEK])


func _sein_schaden() -> float:
	var s := 0.0
	for q: String in o.schaden_an_brakk:
		if q.begins_with("herausforderer"):
			s += float(o.schaden_an_brakk[q])
	return s


## Das Feld selbst, wenn es frei ist, sonst das nächste freie im Platz.
func _feld(z: Vector2i) -> Vector2i:
	return z if o.karte.ist_frei(z) and o.karte.ist_begehbar(z) else kp._frei_innen(z)


# ------------------------------------------------------------------ Technogunner

func _gunner() -> void:
	var g := h.typ as NemesisBossGunner
	var k: Kommandant = spiel.kommandant
	var ego: EgoModus = spiel.ego
	pruefe(is_equal_approx(g.abstand(10.0), 8.0) and g.wall_abkling() == INF and is_equal_approx(g.takt(5.0), Werte.HERAUSFORDERER_AKTION_TAKT.x), "Abstand ×0,8, Takt am unteren Ende, nie auf Wälle")
	_folge(5.0, func(_letzte: Array, a: String) -> bool: return a in ["ringsalve", "anker", "minigun"])
	# Ringsalve: stehen bleiben trifft, darüber springen nicht
	_stelle(Vector2i(2, -1), Vector2i(-2, -1))
	h.beginne_angriff("ringsalve")
	var steht := _lauf(Werte.BOSS_GUNNER_RING_TAKT * float(Werte.BOSS_GUNNER_RING_ZAHL - 1) + 1.5)   # G: Ringe alle 2,0 s
	pruefe(_eintraege("schussring").size() == Werte.BOSS_GUNNER_RING_ZAHL and steht >= Werte.BOSS_GUNNER_RING_ANTEIL - 0.01, "Ringsalve: %d Ringe, stehen bleiben kostet %.2f Treffer" % [_eintraege("schussring").size(), steht])
	_stelle(Vector2i(2, -1), Vector2i(-2, -1))
	h.beginne_angriff("ringsalve")
	var springt := _lauf(Werte.BOSS_GUNNER_RING_TAKT * float(Werte.BOSS_GUNNER_RING_ZAHL - 1) + 1.5, func(_i: int) -> void: ego.hoehe = 1.2)
	ego.hoehe = 0.0
	pruefe(springt == 0.0, "Ringsalve: wer darüber springt, bleibt heil (%.2f)" % springt)
	# Ankerwurf: trifft, zieht heran und hält fest; Tumble im Flug reißt das Seil
	_stelle(Vector2i(4, -1), Vector2i(-3, -1))
	var weit := h.einheit.position.distance_to(k.position) / Werte.ZELLE
	h.beginne_angriff("anker")
	var gebunden := [0]
	_lauf(2.0, func(_i: int) -> void:
		if h.gebunden_rest > 0.0:
			gebunden[0] += 1)
	var nah := h.einheit.position.distance_to(k.position) / Werte.ZELLE
	pruefe(g.anker_treffer == 1 and nah < Werte.BOSS_GUNNER_ANKER_NAH + 0.6 and gebunden[0] >= int((Werte.BOSS_GUNNER_ANKER_ZUG + Werte.BOSS_GUNNER_ANKER_STARR) * 60.0) - 2,
		"Ankerwurf: aus %.1f Feldern auf %.1f herangezogen, %d Bilder gebunden" % [weit, nah, gebunden[0]])
	_stelle(Vector2i(4, -1), Vector2i(-3, -1))
	h.beginne_angriff("anker")
	_lauf(Werte.BOSS_GUNNER_ANKER_ANSAGE + 0.05)
	o.brakk_aktion("tumble")
	_lauf(1.5)
	pruefe(g.anker_treffer == 1 and not _eintraege("anker_gerissen").is_empty(), "Ankerwurf: Tumble im Flug reißt das Seil")
	# Minigun: in Reichweite steigt der Schaden, draußen nichts
	_stelle(Vector2i(2, -1), Vector2i(-2, -1))
	var vorher := g.minigun_schaden
	h.beginne_angriff("minigun")
	_lauf(4.0, func(_i: int) -> void: h._bis_angriff = 999.0)
	var drin := g.minigun_schaden - vorher
	pruefe(drin > 0.9 and drin < Werte.BOSS_GUNNER_MINIGUN_JE_SEK * 2.0 * Werte.BOSS_GUNNER_MINIGUN_SEK, "Minigun in Reichweite: %.2f Treffer in 3 s (steigt bis aufs Doppelte)" % drin)
	_stelle(Vector2i(6, -1), Vector2i(-7, -1))
	var draussen := [0.0, g.minigun_schaden]
	h.beginne_angriff("minigun")
	_lauf(4.0, func(_i: int) -> void:
		h._bis_angriff = 999.0
		if h.einheit.position.distance_to(k.position) / Werte.ZELLE > Werte.BOSS_GUNNER_MINIGUN_WEITE:
			draussen[0] += g.minigun_schaden - float(draussen[1])
		draussen[1] = g.minigun_schaden)
	pruefe(draussen[0] == 0.0, "Minigun außerhalb des Rings: 0 Schaden")
	# G (26.11., Paul): wer direkt neben ihm steht und sofort wegläuft, ist vor dem Ende aus dem Ring (er läuft langsamer nach)
	_stelle(Vector2i(-5, 0), Vector2i(-6, 0))
	var flucht := [g.minigun_schaden, 0.0, 0.0]   # [Stand, Sekunde des letzten Treffers, Zeit]
	h.beginne_angriff("minigun")
	_lauf(Werte.BOSS_GUNNER_MINIGUN_ANLAUF + Werte.BOSS_GUNNER_MINIGUN_SEK, func(_i: int) -> void:
		h._bis_angriff = 999.0
		flucht[2] = float(flucht[2]) + 1.0 / 60.0
		var p := k.position + Vector2(EgoModus.TEMPO * Werte.ZELLE / 60.0, 0.0)
		if kp.im_innern(o.karte.zelle_bei(p)):
			spiel.ego._setze_fuss(p)
		if g.minigun_schaden > float(flucht[0]):
			flucht[1] = flucht[2]
		flucht[0] = g.minigun_schaden)
	pruefe(float(flucht[1]) < Werte.BOSS_GUNNER_MINIGUN_ANLAUF + Werte.BOSS_GUNNER_MINIGUN_SEK - 0.5, "Minigun: von direkt daneben weggelaufen – letzter Treffer nach %.1f s (feuert bis %.1f s)" % [float(flucht[1]), Werte.BOSS_GUNNER_MINIGUN_ANLAUF + Werte.BOSS_GUNNER_MINIGUN_SEK])
	# Lichtsäule: vor der dritten nie, danach etwa jede zweite
	var ausweichen := func(n: int) -> int:
		var vor := _eintraege("saeule_ausweichen").size()
		for i in n:
			_stelle(Vector2i(4, -1), Vector2i(-3, -1))
			ego._saeule_ziel = h.einheit.position + Vector2(randf_range(-8.0, 8.0), randf_range(-8.0, 8.0))
			_lauf(0.6)
		ego._saeule_ziel = Vector2.INF
		return _eintraege("saeule_ausweichen").size() - vor
	h.saeulen = 2
	var frueh: int = ausweichen.call(10)
	h.saeulen = 3
	var spaet: int = ausweichen.call(30)
	pruefe(frueh == 0 and spaet >= 8 and spaet <= 22 and g._trick_gesagt, "Lichtsäule: vor der dritten 0 von 10 ausgewichen, danach %d von 30 (Spruch einmal)" % spaet)
	# Phase 2: hinteres Drittel, drei Bunker, 5er-Salven
	_stelle(Vector2i(5, -1), Vector2i(-2, -1))
	h.einheit.leben = h.einheit.max_leben * 0.4
	_lauf(2.0, func(_i: int) -> void: h._bis_angriff = 999.0)
	var west := bool((_eintraege("bunker").back() as Dictionary).get("west", true)) if not _eintraege("bunker").is_empty() else true
	var bunker := Werte.BOSS_GUNNER_BUNKER.filter(func(r: Vector2i) -> bool: return o.karte.inhalt(kp.mitte + (r if west else Vector2i(-1 - r.x, r.y))) == Karte.WALL)
	pruefe(g.phase2 and bunker.size() == 6, "Phase 2: drei Bunker 2×1 im hinteren Drittel (%s, %d Felder)" % ["Westen" if west else "Osten", bunker.size()])
	var raus := [0]
	_lauf(8.0, func(_i: int) -> void:
		h._bis_angriff = 999.0
		if h._aktion.is_empty() and not g.feld_ok(o.karte.zelle_bei(h.einheit.position)):
			raus[0] += 1)
	pruefe(raus[0] == 0 and int(h.zaehler["sprung"]) + int(h.zaehler["tumble"]) >= 2, "Phase 2: 8 s im hinteren Drittel, wechselt die Seite (%d Bilder draußen)" % raus[0])
	pruefe(g.gewichte(5.0, []).has("salve5"), "Phase 2: 5er-Salven dazu")
	h.beginne_angriff("salve5")
	_lauf(1.5)
	pruefe(_eintraege("salve5_schuss").size() == 5, "5er-Salve: %d Schüsse nach 0,5 s Ansage" % _eintraege("salve5_schuss").size())
	_ansagen_pruefen()


# ------------------------------------------------------------------ Plasmawerfer

func _plasma() -> void:
	var p := h.typ as NemesisBossPlasma
	var k: Kommandant = spiel.kommandant
	var ego: EgoModus = spiel.ego
	var bg: BrakkGeschosse = spiel.brakk_geschosse
	pruefe(absf(h.einheit.max_leben - Werte.HERAUSFORDERER_LEBEN_MAL * Werte.BOSS_PLASMA_LEBEN_MAL * k.max_leben) < 1.0 and is_equal_approx(p.takt(2.0), Werte.HERAUSFORDERER_AKTION_TAKT.y) and not p.tumble_ok(),
		"Leben ×1,3 (%.0f), Tempo ×0,85, Takt am oberen Ende, kein Tumble" % h.einheit.max_leben)
	_stelle(Vector2i(4, -1), Vector2i(-3, -1))
	h.tumble("links")
	pruefe(str(h._aktion.get("art", "")) == "lauf" and is_equal_approx(float(h._aktion.get("sek", 0.0)), Werte.BOSS_SEITSCHRITT_SEK), "statt Tumble ein Seitschritt")
	_folge(5.0, func(_letzte: Array, a: String) -> bool: return a in ["moerser", "sturm", "abpraller"])
	# Mörser: einer liegt auf Brakk; stehen bleiben trifft, im Sprung nicht
	_stelle(Vector2i(4, -1), Vector2i(-3, -1))
	h.beginne_angriff("moerser")
	_lauf(Werte.BOSS_PLASMA_MOERSER_ANSAGE + 0.05)
	var kreise := bg.wuerfe.size()
	var steht := _lauf(2.0)
	pruefe(kreise >= Werte.BOSS_PLASMA_MOERSER_ZAHL.x and kreise <= Werte.BOSS_PLASMA_MOERSER_ZAHL.y and absf(steht - Werte.BOSS_PLASMA_MOERSER_ANTEIL) < 0.05, "Mörser: %d Kreise %.1f s vorher, stehen bleiben kostet %.2f Treffer" % [kreise, Werte.BOSS_PLASMA_MOERSER_FLUG, steht])
	_stelle(Vector2i(4, -1), Vector2i(-3, -1))
	h.beginne_angriff("moerser")
	var springt := _lauf(2.6, func(_i: int) -> void: ego.hoehe = 1.2)
	ego.hoehe = 0.0
	pruefe(springt == 0.0, "Mörser: im Sprung kein Treffer")
	# Sturm mit Gel: Gelfläche, kurzes Fenster; im Gel halbes Tempo, zwei Sprünge befreien; höchstens drei
	_stelle(Vector2i(1, -1), Vector2i(-1, -1))
	h.beginne_angriff("sturm")
	_lauf(2.5, func(_i: int) -> void: h._bis_angriff = 999.0)
	var sturm := _eintraege("angriff").filter(func(x: Dictionary) -> bool: return str(x["art"]) == "sturm")
	var fenster := float((sturm.back() as Dictionary)["fenster"]) if not sturm.is_empty() else 9.0
	pruefe(p.gele.size() == 1 and fenster <= Werte.HERAUSFORDERER_FENSTER.y * Werte.BOSS_PLASMA_GEL_FENSTER + 0.01, "Sturm mit Gel: eine Gelfläche, Fenster danach %.2f s" % fenster)
	ego._setze_fuss((p.gele[0] as Dictionary)["mitte"] as Vector2) if not p.gele.is_empty() else null
	_lauf(0.1, func(_i: int) -> void: h._bis_angriff = 999.0)
	var gebremst := o.brakk_tempo_faktor()
	o.brakk_aktion("sprung")
	var nach_einem := p.klebt
	o.brakk_aktion("sprung")
	_lauf(0.1, func(_i: int) -> void: h._bis_angriff = 999.0)
	pruefe(is_equal_approx(gebremst, Werte.BOSS_PLASMA_GEL_TEMPO) and nach_einem and not p.klebt and is_equal_approx(o.brakk_tempo_faktor(), 1.0), "im Gel: Tempo %.2f, nach zwei Sprüngen frei" % gebremst)
	for i in 4:
		p._gel_legen(h.einheit.position + Vector2(float(i) * Werte.ZELLE, 0.0))
	pruefe(p.gele.size() == Werte.BOSS_PLASMA_GEL_MAX, "höchstens %d Gelflächen zugleich (%d)" % [Werte.BOSS_PLASMA_GEL_MAX, p.gele.size()])
	# Abpraller: prallt dreimal ab und bleibt im Platz
	_stelle(Vector2i(4, -1), Vector2i(-3, -1))
	p._plasma_schuss(Vector2(-1.0, 0.15).normalized(), Werte.BOSS_PLASMA_PRALL_MAL, {})
	var g: Dictionary = bg.geschosse.back()
	var prall := [0, 0]
	for i in 900:
		k.unverwundbar = 9.0   # Brakk lässt ihn durch – hier zählt nur das Abprallen
		var vor := int(g["abprall"])
		bg.weiter(Werte.SPIELTEMPO / 60.0)
		if int(g["abprall"]) < vor:
			prall[0] += 1
		var wo: Vector2 = (g["von"] as Vector2) + (g["r"] as Vector2) * float(g["s"])
		if not kp.rechteck.grow(2.0).has_point(wo):
			prall[1] += 1
		if not bg.geschosse.has(g):
			break
	k.unverwundbar = 0.0
	pruefe(prall[0] == Werte.BOSS_PLASMA_PRALL_MAL and prall[1] == 0 and not bg.geschosse.has(g), "Abpraller: %d-mal abgeprallt, nie aus dem Platz" % prall[0])
	_stelle(Vector2i(4, -1), Vector2i(-3, -1))
	var vorher := _eintraege("abpraller").size()
	h.beginne_angriff("abpraller")
	_lauf(2.0)
	pruefe(_eintraege("abpraller").size() - vorher == Werte.BOSS_PLASMA_PRALL_ZAHL, "Abpraller: %d Schüsse nacheinander" % (_eintraege("abpraller").size() - vorher))
	# Phase 2: Brandfächer, höchstens vier Brandfelder
	_stelle(Vector2i(4, -1), Vector2i(-3, -1))
	h.einheit.leben = h.einheit.max_leben * 0.4
	_lauf(0.1)
	pruefe(p.phase2 and p.gewichte(5.0, []).has("brandfaecher"), "Phase 2: Brandfächer dazu")
	var meiste := [0]
	for n in 6:   # F2: ohne die festen Wälle innen fliegen die Geschosse weiter – mehr Fächer, bis die Grenze greift
		h.angriff = {}
		h.einheit.position = o.karte.mitte(_feld(kp.mitte + Vector2i(-3, -1)))
		h.beginne_angriff("brandfaecher")
		_lauf(3.0, func(_i: int) -> void:
			h._bis_angriff = 999.0
			k.unverwundbar = 9.0   # alle Geschosse landen
			meiste[0] = maxi(meiste[0], bg.braende.filter(func(b: Dictionary) -> bool: return bool(b.get("boss", false))).size()))
	k.unverwundbar = 0.0
	pruefe(meiste[0] == Werte.BOSS_PLASMA_BRAND_MAX, "Brandfächer: höchstens %d Brandfelder zugleich (%d)" % [Werte.BOSS_PLASMA_BRAND_MAX, meiste[0]])
	_ansagen_pruefen()


# ------------------------------------------------------------------ Sonde 7 (C3)

func _sonde() -> void:
	var s := h.typ as NemesisBossSonde
	var k: Kommandant = spiel.kommandant
	var bg: BrakkGeschosse = spiel.brakk_geschosse
	var tafel := o.tafeln.protokoll.filter(func(t: Dictionary) -> bool: return str(t["art"]) == "herausforderer")
	pruefe(s != null and h.ist_sonde() and not o.nemesis.personen.has(h.person) and not tafel.is_empty() and str(tafel.back()["titel"]) == "Sonde 7 · Kommandantin"
		, "Sonde 7 tritt selbst an: eigener Datensatz, Banner „Sonde 7 · Kommandantin“ (Zeile „Befehl 24 – ich übernehme selbst.“)")
	pruefe(s.bild != null and not h.einheit._sprite.visible, "Platzhalter-Figur: ihr Bild statt des Truppenblatts")
	# Akku: 6 s Luft, 2 s Boden
	_stelle(Vector2i(4, -1), Vector2i(-3, -1))
	s._akku = 0.0
	s.am_boden = false
	s.akku_protokoll.clear()
	var hoch := [0.0]
	_lauf(17.0, func(_i: int) -> void:
		h._bis_angriff = 999.0
		k.position = o.karte.mitte(_feld(kp.mitte + Vector2i(4, -1)))
		s._schrot_in = 999.0   # hier nur der Akku (während eines Angriffs wartet der Wechsel auf den Boden)
		if not s.am_boden:
			hoch[0] = maxf(hoch[0], float(h.einheit.get_meta("hebt_ab", 0.0))))
	var w := s.akku_protokoll
	var ok := w.size() >= 3 and str(w[0][1]) == "boden" and str(w[1][1]) == "luft" and str(w[2][1]) == "boden" \
		and absf(float(w[1][0]) - float(w[0][0]) - Werte.BOSS_SONDE_BODEN_SEK) < 0.1 and absf(float(w[2][0]) - float(w[1][0]) - Werte.BOSS_SONDE_LUFT_SEK) < 0.1
	pruefe(ok and hoch[0] > Werte.BOSS_SONDE_SCHWEBE * 0.8, "Akku: %s (in der Luft bis %.1f Felder hoch)" % [str(w.map(func(x: Array) -> String: return "%s %.1f" % [str(x[1]), float(x[0])])), hoch[0]])
	# Sturzfeuer: der Kegel liegt auf Brakk zur Ansage; stehen bleiben = ein Treffer, aus dem Kegel = nichts
	_stelle(Vector2i(4, -1), Vector2i(-3, -1))
	s.am_boden = false
	h.beginne_angriff("sturz")
	var eintrag: Dictionary = _eintraege("sturz").back()
	var steht := _lauf(2.5, func(_i: int) -> void: h._bis_angriff = 999.0)
	pruefe((eintrag["mitte"] as Vector2).distance_to(eintrag["brakk"] as Vector2) < 1.0 and absf(steht - 1.0) < 0.05, "Sturzfeuer: Kegel auf Brakk zur Ansage, vier Schüsse zusammen %.2f Treffer" % steht)
	_stelle(Vector2i(4, -1), Vector2i(-3, -1))
	h.beginne_angriff("sturz")
	var weg := o.karte.mitte(_feld(kp.mitte + Vector2i(4, 3)))
	var raus := _lauf(2.5, func(i: int) -> void:
		h._bis_angriff = 999.0
		if i == 20:
			spiel.ego._setze_fuss(weg))
	pruefe(raus == 0.0 and not _eintraege("sturz_rueck").is_empty(), "Sturzfeuer: aus dem Kegel heraus kein Treffer; der Rückstoß trägt sie zurück")
	# MG-Markierung: ANVISIERT, Lenkgeschosse verfallen nach 4 s
	_stelle(Vector2i(4, -1), Vector2i(-3, -1))
	h.beginne_angriff("mg")
	var anvisiert := [0, 0, 0.0]
	_lauf(Werte.BOSS_SONDE_MG_ANSAGE + 3.6, func(_i: int) -> void:
		h._bis_angriff = 999.0
		k.unverwundbar = 9.0   # Brakk lässt sie durch – hier zählt die Lebensdauer
		if h.anvisiert != Vector2.INF:
			anvisiert[0] += 1
		anvisiert[1] = maxi(anvisiert[1], s.lenk.size())
		for g: Dictionary in s.lenk:
			anvisiert[2] = maxf(anvisiert[2], float(g["alter"])))
	var noch := s.lenk.size()
	_lauf(0.6, func(_i: int) -> void:
		h._bis_angriff = 999.0
		k.unverwundbar = 9.0)
	k.unverwundbar = 0.0
	pruefe(anvisiert[0] >= int(Werte.BOSS_SONDE_MG_ANSAGE * 60.0) - 2 and anvisiert[1] >= Werte.BOSS_SONDE_MG_ZAHL.x and s.lenk.is_empty() and anvisiert[2] <= NemesisBoss.new(h)._bg(Werte.BOSS_SONDE_MG_SEK) + 0.05,
		"MG-Markierung: %d Bilder ANVISIERT, %d Lenkgeschosse, nach 4 s alle verfallen (bei 4,4 s noch %d → %d)" % [anvisiert[0], anvisiert[1], noch, s.lenk.size()])
	# Schrotstoß: zu nah – Pumpen, Rückstoß, dann Sturzfeuer
	_stelle(Vector2i(0, -1), Vector2i(-1, -1))
	s._schrot_in = 0.0
	s.am_boden = false
	_lauf(1.0, func(_i: int) -> void: h._bis_angriff = 0.0 if s._danach_sturz else 999.0)
	pruefe(not _eintraege("schrot").is_empty() and not _eintraege("stoss").is_empty() and str(h._letzte.back()) == "sturz", "Schrotstoß: zu nah → Rückstoß, dann Sturzfeuer (%s)" % str(h._letzte.slice(-2)))
	# Phase 2: Heil-Impuls bricht bei Schaden ab, sonst heilt er 15 %
	_stelle(Vector2i(4, -1), Vector2i(-3, -1))
	h.einheit.leben = h.einheit.max_leben * 0.4
	_lauf(0.1)
	h.angriff = {}
	h.beginne_angriff("heil")
	_lauf(0.5)
	s.vor_treffer(Werte.BOSS_SONDE_HEIL_BRUCH * h.einheit.max_leben + 1.0)
	_lauf(0.2)
	pruefe(s.heil_gebrochen and _eintraege("heil").is_empty(), "Heil-Impuls: 8 % Schaden im Kanal – abgebrochen")
	s.heil_genutzt = false
	_stelle(Vector2i(4, -1), Vector2i(-3, -1))
	var vor := h.einheit.leben
	h.beginne_angriff("heil")
	_lauf(Werte.BOSS_SONDE_HEIL_SEK + 0.2, func(_i: int) -> void: h._bis_angriff = 999.0)
	pruefe(absf(h.einheit.leben - vor - Werte.BOSS_SONDE_HEIL_ANTEIL * h.einheit.max_leben) < 1.0 and not s.gewichte(5.0, []).has("heil"), "Heil-Impuls: +15 %, danach nicht wieder")
	# Verstärkungsruf: als letzter der Reihe, einmal; sie schwebt, schießt nicht, ist beschießbar; Eliten im Platz
	# Scheuchfeld: Sprengungen auf Brakks Weg, jede 0,7 s vorher markiert
	_stelle(Vector2i(4, -1), Vector2i(-3, -1))
	h.beginne_angriff("scheuch")
	_lauf(4.5, func(_i: int) -> void: h._bis_angriff = 999.0)
	var knalle := _eintraege("scheuch_knall")
	pruefe(knalle.size() >= 2 and knalle.all(func(x: Dictionary) -> bool: return float(x["marke"]) >= Werte.BOSS_SONDE_SCHEUCH_MARKE - 0.02), "Scheuchfeld: %d Sprengungen in 4 s, jede %.1f s vorher markiert" % [knalle.size(), Werte.BOSS_SONDE_SCHEUCH_MARKE])
	s._scheuch = {}
	s._danach_sturz = false
	s._p2_angriffe = Werte.BOSS_SONDE_RUF_NACH
	pruefe(h.naechster_angriff(5.0) == "ruf", "Phase 2: nach %d Angriffen der Verstärkungsruf" % Werte.BOSS_SONDE_RUF_NACH)
	_stelle(Vector2i(4, -1), Vector2i(-3, -1))
	h.beginne_angriff("ruf")
	var still := [0, 0]
	_lauf(3.0, func(_i: int) -> void:
		if not h._aktion.is_empty():
			still[0] += 1
		if s.feuer_frei() and float(h.einheit.get_meta("hebt_ab", 0.0)) > 1.0:
			still[1] += 1)
	var drin := s.eliten.filter(func(x: Variant) -> bool: return Nemesis.lebt(x) and kp.innen_px((x as Einheit).position))
	var t_ruf: Variant = null
	for t: Variant in o._ziele.values():
		if t.einheit == h.einheit:
			t_ruf = t
	var leben_vor := h.einheit.leben
	if t_ruf != null:
		o.treffer(t_ruf, 100.0)
	pruefe(drin.size() >= Werte.BOSS_SONDE_RUF_ZAHL.x and still[0] == 0 and still[1] > 60 and o.haelt_feuer(o.brakk_ziel) == false and h.einheit.leben < leben_vor,
		"Verstärkungsruf: %d Eliten im Platz, sie schwebt ohne Ausweichen, ist beschießbar, alle dürfen feuern" % drin.size())
	s._p2_angriffe = 99
	pruefe(not s.gewichte(5.0, []).has("ruf"), "Verstärkungsruf nur einmal je Duell")
	# Ende: geborgen statt gefallen, Ring, Banner, Eliten weg, Bericht
	var eliten := s.eliten.duplicate()
	if t_ruf != null:
		o.treffer(t_ruf, h.einheit.leben * 2.0)
	h.weiter(0.0)
	var titel := (o.tafeln.protokoll + o.tafeln.warten + [o.tafeln.aktuell]).filter(func(t: Dictionary) -> bool: return str(t.get("titel", "")) == "Sonde 7 vertrieben")
	pruefe(h.zustand == "ruhe" and h.sonde_vertrieben and not titel.is_empty() and o.beute_boden.any(func(b: Dictionary) -> bool: return bool(b.get("herausforderer", false))),
		"vertrieben: Ring, Banner „Sonde 7 vertrieben“ – geborgen, nicht gefallen")
	pruefe(eliten.all(func(x: Variant) -> bool: return not Nemesis.lebt(x)), "die Eliten verschwinden mit dem Duell")
	var b := o.bericht(true)
	pruefe(bool(b.get("sonde", false)) and str(((b.get("herausforderer", []) as Array).back() as Array)[0]) == "Sonde 7", "Bericht: „Sonde 7“ vertrieben, Hangar zeigt sie auf dem Podest")
	_ansagen_pruefen()
