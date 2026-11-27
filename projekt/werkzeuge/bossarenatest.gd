extends SceneTree
## G2 (27.11., Paul): Bossarena headless – je Boss ein Lauf:
##
##   godot --headless --path . --fixed-fps 60 -s werkzeuge/bossarenatest.gd -- scharf|gunner|plasma|sonde [gefallen] [lang]
## H (27.11., Paul): „lang“ – 120 s Duell (ab 60 s Phase 2): Abfolge in Tabellenreihenfolge, nie zwei Bodeneffekte, Reihenwelle
## läuft vom Boss weg bis zur Lichtwand, Vergeltung immer Säule auf freiem Boden, die Werte-Tafel wirkt sofort (Scharfschütze).
##
## Startet die Bossarena (große Karte, nur Wälle), wartet auf Ansage, Kampfplatz und Duell, lässt Brakk 25 s lang treffen
## und getroffen werden (er hält durch), schaltet den Boss dann aus („gefallen“: Brakk fällt) und prüft Tafel und Zählung.
## nemesis.json bleibt unberührt (Prüfung über die Änderungszeit).

const ARTEN := {"scharf": "scharfschuetze", "gunner": "technogunner", "plasma": "plasmawerfer", "sonde": "sonde"}
const SOLL := 15

var spiel: Node
var o: Order24
var h: NemesisHerausforderer
var warte := 10
var schritt := 0
var fehler: Array[String] = []
var geprueft := 0
var art := "scharf"
var gefallen := false
var t0 := 0.0
var duell_t := 0.0
var nemesis_zeit := 0
var treffer_im_fenster := 0
var lang := false          # H: 120-s-Duell mit den Prüfungen aus Prompt H
var _reihe_takt_geprueft := ""
var _gele_max := 0                # J: beim Plasmawerfer höchstens 4 Gele zugleich (mit Klon)


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		art = str(args[0])
	gefallen = args.has("gefallen")
	lang = args.has("lang")
	nemesis_zeit = FileAccess.get_modified_time("user://nemesis.json") if FileAccess.file_exists("user://nemesis.json") else -1
	OS.set_environment("TD_KARTE_NAME", Werte.ORDER24_KARTE_NAME)
	Werte.lade_karte(Werte.ORDER24_KARTE_NAME)
	BrakkBossarena.laeuft = true
	BrakkBossarena.wahl = {"boss": str(ARTEN[art]), "stufe": 6, "ringe": "standard", "frei": [["laser", 1], ["markierung", 1], ["feuerteam", 1]],
		"ladungen": 2, "phase2": false}
	if lang:
		BrakkBossarena.wahl["klon"] = true   # I-8: im langen Lauf mit Klon (auch er hält „ein Bodeneffekt“)
	# Menüseite: Einträge, Umschalten (Boss weiter, Ringe „frei“ zeigt sechs Zeilen mehr), danach wie vorher
	var leer := func() -> void: pass
	var n_vorher := BrakkBossarena.menue(leer, leer, leer).size()
	(BrakkBossarena.menue(leer, leer, leer)[1][1] as Callable).call()
	var boss_weiter := str(BrakkBossarena.wahl["boss"])
	BrakkBossarena.wahl["ringe"] = "frei"
	var n_frei := BrakkBossarena.menue(leer, leer, leer).size()
	BrakkBossarena.wahl["boss"] = str(ARTEN[art])
	BrakkBossarena.wahl["ringe"] = "standard"
	pruefe(n_vorher == 8 and n_frei == 14 and boss_weiter != str(ARTEN[art]), "Menü: %d Einträge, mit freien Ringen %d, Boss schaltet auf %s" % [n_vorher, n_frei, boss_weiter])
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
	var soll := SOLL + (6 if lang else 0)
	if geprueft < soll:
		fehler.append("nur %d von %d Prüfungen gelaufen" % [geprueft, soll])
	paused = false
	if fehler.is_empty():
		print("TEST BOSSARENA %s OK (%d Prüfungen)" % [art, geprueft])
	else:
		print("TEST BOSSARENA %s FEHLER (%d): %s" % [art, fehler.size(), "; ".join(PackedStringArray(fehler))])
	quit(0 if fehler.is_empty() else 1)
	return true


## Ein Treffer Brakks auf den Boss über den Weg der Ego-Sicht (Order24.treffer).
func _brakk_trifft(menge: float) -> void:
	for t: Variant in o.ego_ziele():
		if t is Order24.TechnoZiel and (t as Order24.TechnoZiel).einheit == h.einheit:
			spiel.brakk_quelle = "pistole"
			o.treffer(t as Order24.TechnoZiel, menge)
			spiel.brakk_quelle = ""
			return


func _process(_delta: float) -> bool:
	if warte > 0:
		warte -= 1
		return false
	o = spiel.order24
	if o == null:
		return false
	h = o.herausforderer
	var k: Kommandant = spiel.kommandant
	match schritt:
		0:
			if o.laeuft and o.arena != null and o.arena.schritt != "warten":
				var waffen := o.karte.ausbau.values().filter(func(a: int) -> bool: return a == Karte.TURM or a == Karte.STELLUNG).size()
				pruefe(spiel.fabriken.is_empty() and waffen == 0 and o.zuflucht == null, "Arena: keine Fabriken, Türme, Stellungen, Zufluchten (Fabriken %d, Türme/Stellungen %d)" % [spiel.fabriken.size(), waffen])
				var nl := BrakkGebiete.rechteck("niemandsland")
				pruefe(nl.grow(1).has_point(o.karte.zelle_bei(k.position)) and k.fortschritt.stufe == 6 and k.fortschritt.ringe.size() == 3 and o.ladungen == 2,
					"Brakk im Niemandsland %s, Stufe %d, Ringe %s, Ladungen %d" % [str(o.karte.zelle_bei(k.position)), k.fortschritt.stufe, str(k.fortschritt.ringe), o.ladungen])
				pruefe(not o.flucht_sperre() and not o.ego_taste(spiel.ego, "Q", true) and not o.ego_taste(spiel.ego, "E", true) and not o.ego_taste(spiel.ego, "R", true), "keine Fluchtsperre: Q, E und R gehen an Brakk durch")
				t0 = o.zeit
				schritt = 1
			elif o.zeit > 20.0:
				pruefe(false, "Arena startet nicht")
				return _fertig()
		1:
			k.leben = k.max_leben
			if h.zustand == "duell" and h.einzug.is_empty() and h.kampfplatz.zu():
				var ist: String = str(h.zaehlung.get("boss", ""))
				pruefe(ist == str(ARTEN[art]) and o.zeit - t0 <= BrakkBossarena.ANSAGE_SEK + 15.0, "Duell mit %s nach %.1f s (Ansage %.0f s)" % [ist, o.zeit - t0, BrakkBossarena.ANSAGE_SEK])
				duell_t = o.zeit
				schritt = 2
				if lang:
					o.arena.werte_tafel.alles_standard()
					if art == "plasma":
						o.arena.werte_tafel.setzen("BOSS_PLASMA_MOERSER_ANSAGE", 0.6)   # J-7: wirkt sofort auf den nächsten Mörser
					elif art == "gunner":
						o.arena.werte_tafel.setzen("BOSS_GUNNER_SALVE4_ANSAGE", 0.6)   # I-8: wirkt sofort auf die nächste 4er-Salve
					else:
						o.arena.werte_tafel.setzen("BOSS_REIHE_TAKT", 0.5)   # H-10: wirkt sofort auf die nächste Reihenwelle
			elif o.zeit - t0 > 40.0:
				pruefe(false, "kein Duell nach 40 s")
				return _fertig()
		2:
			k.leben = k.max_leben   # er hält durch – auch im Modus „gefallen“ erst nach den 25 s (27.11.: der Technogunner traf ihn vorher um, die Tafel hielt den Test an)
			if lang:
				_lang_beobachten()
				if o.zeit - duell_t >= 60.0 and not h.wut:
					h.einheit.leben = h.einheit.max_leben * 0.45   # Phase 2
				if h.wut and h.einheit.leben < h.einheit.max_leben * 0.3:
					h.einheit.leben = h.einheit.max_leben * 0.45
			if h.einheit != null and is_instance_valid(h.einheit) and h.einheit.leben > h.einheit.max_leben * 0.6 and int(o.zeit * 4.0) != int((o.zeit - 0.017) * 4.0):
				if str(h.angriff.get("teil", "")) == "fenster":
					treffer_im_fenster += 1
				_brakk_trifft(h.einheit.max_leben * 0.01)
			if o.zeit - duell_t >= (120.0 if lang else 25.0):
				var z := h.zaehlung
				if lang:
					_lang_pruefen()
				pruefe(angriffe_summe() >= 2, "Angriffe im Duell: %s" % str(h.angriffe_je_art))
				pruefe(not (z["treffer"] as Dictionary).is_empty(), "Treffer auf Brakk gezählt: %s" % str(z["treffer"]))
				pruefe(float(z["boss_schaden"]) > 0.0 and (treffer_im_fenster == 0 or float(z["fenster_schaden"]) > 0.0), "Schaden am Boss %.0f, davon im Fenster %.0f (%d Treffer im Fenster)" % [float(z["boss_schaden"]), float(z["fenster_schaden"]), treffer_im_fenster])
				if gefallen:
					k.nimm_schaden(k.max_leben * 10.0)
				else:
					_brakk_trifft(h.einheit.max_leben * 10.0)
				t0 = o.zeit
				schritt = 3
		3:
			if o.arena.schritt == "tafel":
				var z := BrakkBossarena.letzte
				var soll := "gesiegt" if gefallen else "vertrieben"
				pruefe(str(z.get("ausgang", "")) == soll, "Ausgang %s (soll %s)" % [str(z.get("ausgang", "")), soll])
				var voll := true
				for f: String in ["boss", "name", "angriffe", "treffer", "boss_schaden", "fenster_schaden", "vergeltungen", "druckphasen", "dauer", "ausgang"]:
					voll = voll and z.has(f)
				pruefe(voll and float(z["dauer"]) >= 24.0, "Zählung vollständig, Dauer %.1f s" % float(z.get("dauer", 0.0)))
				var inhalt := o.arena.tafel_inhalt(z, o.arena.boss)
				pruefe((inhalt["knoepfe"] as Array).size() == 3 and (inhalt["kacheln"] as Array).size() == 4 and paused, "Tafel: drei Knöpfe, vier Kacheln, Spiel angehalten (%s)" % str(inhalt["titel"]))
				pruefe(gefallen or h.kampfplatz.zustand == "aus" or o.zeit - t0 >= BrakkBossarena.BERGUNG_MAX - 1.0, "Tafel erst nach der Bergung (Platz %s)" % h.kampfplatz.zustand)
				var jetzt := FileAccess.get_modified_time("user://nemesis.json") if FileAccess.file_exists("user://nemesis.json") else -1
				pruefe(jetzt == nemesis_zeit, "nemesis.json unberührt")
				# 27.11. (Paul: „nicht den Hangar verdrängen“): beim Verlassen ist laeuft schon aus – auch dann schreibt die Partie nichts
				BrakkBossarena.laeuft = false
				o.nemesis.speichern()
				BrakkBossarena.laeuft = true
				var danach := FileAccess.get_modified_time("user://nemesis.json") if FileAccess.file_exists("user://nemesis.json") else -1
				pruefe(danach == nemesis_zeit, "Verlassen der Arena (laeuft aus, speichern): nemesis.json unberührt – der Hangar bleibt")
				# G2-6: der Eintrag fürs befehl24-Protokoll (im Lauf; die Arena schreibt ihn nicht)
				var dp := h.duell_protokoll()
				var json_ok: Variant = JSON.parse_string(JSON.stringify(dp))
				pruefe(json_ok is Dictionary and str(dp["boss"]) == str(ARTEN[art]) and dp["angriffe"] is Dictionary and dp["treffer_je_art"] is Dictionary and int(dp["fenster_genutzt"]) >= 0 and str(dp["ausgang"]) != "", "Protokoll-Eintrag „duell“: %s" % JSON.stringify(dp).left(220))
				return _fertig()
			elif o.zeit - t0 > 40.0:
				pruefe(false, "keine Tafel 40 s nach dem Ende (Arena %s, Platz %s)" % [o.arena.schritt, h.kampfplatz.zustand])
				return _fertig()
	return false


func angriffe_summe() -> int:
	var s := 0
	for a: String in h.angriffe_je_art:
		s += int(h.angriffe_je_art[a])
	return s


## H-10: Sobald die erste Reihenwelle läuft, prüfen, dass sie den geänderten Takt nutzt.
func _lang_beobachten() -> void:
	if art == "plasma":
		_gele_max = maxi(_gele_max, (h.typ as NemesisBossPlasma).gele.size())
		if _reihe_takt_geprueft == "":
			var lp := h.protokoll.filter(func(e: Dictionary) -> bool: return str(e.get("was", "")) == "angriff" and str(e.get("art", "")) == "moerser")
			if not lp.is_empty():
				_reihe_takt_geprueft = "Mörser mit dem Tafelwert: Ansage %.2f s (Tafel 0,60)" % float(lp[0]["angesagt"])
				pruefe(absf(float(lp[0]["angesagt"]) - 0.6) < 0.03, "Werte-Tafel wirkt sofort: " + _reihe_takt_geprueft)
				o.arena.werte_tafel.alles_standard()
		return
	if art == "gunner":
		if _reihe_takt_geprueft == "":
			var l := h.protokoll.filter(func(e: Dictionary) -> bool: return str(e.get("was", "")) == "angriff" and str(e.get("art", "")) == "salve4")
			if not l.is_empty():
				_reihe_takt_geprueft = "4er-Salve mit dem Tafelwert: Ansage %.2f s (Tafel 0,60)" % float(l[0]["angesagt"])
				pruefe(absf(float(l[0]["angesagt"]) - 0.6) < 0.03, "Werte-Tafel wirkt sofort: " + _reihe_takt_geprueft)
				o.arena.werte_tafel.alles_standard()
		return
	if _reihe_takt_geprueft == "" and h.reihe != null and h.reihe.reihen.size() >= 2:
		var d := float(h.reihe.reihen[1]["ab"]) - float(h.reihe.reihen[0]["ab"])
		_reihe_takt_geprueft = "Reihenwelle mit dem Tafelwert: Takt %.2f s (Tafel 0,50)" % d
		pruefe(absf(d - 0.5) < 0.001, "Werte-Tafel wirkt sofort: " + _reihe_takt_geprueft)
		o.arena.werte_tafel.alles_standard()


## H: die Prüfungen nach 120 s.
func _lang_pruefen() -> void:
	if _reihe_takt_geprueft == "":
		pruefe(false, "Werte-Tafel: keine Reihenwelle gesehen")
	# Abfolge der Phase 1 in Tabellenreihenfolge
	var p1: Array = []
	for e: Dictionary in h.abfolge_log:
		if int(e["i"]) >= 0 and not bool(e.get("dann", false)) and float(e["bei"]) < duell_t + 60.0:
			p1.append(int(e["i"]))
	var n: int = h.typ.abfolge(false).size()
	var spruenge := 0
	for j in range(1, p1.size()):
		if posmod(int(p1[j]) - int(p1[j - 1]), n) != 1:
			spruenge += 1
	pruefe(p1.size() >= 8 and spruenge <= maxi(1, p1.size() / 4), "Abfolge P1 in Tabellenreihenfolge: %s (%d Sprünge)" % [str(p1), spruenge])
	# nie zwei Bodeneffekte zugleich
	var ueber: Array = []
	var l: Array = h.boden_log
	for i in l.size():
		for j in range(i + 1, l.size()):
			var a: Dictionary = l[i]
			var b: Dictionary = l[j]
			var paar := [str(a["wer"]), str(b["wer"])]
			paar.sort()
			if paar[0] == paar[1] or paar == ["kombo", "saeule"]:
				continue
			if minf(float(a["bis"]), float(b["bis"])) - maxf(float(a["von"]), float(b["von"])) > 0.05:
				ueber.append("%s/%s @%.1f" % [a["wer"], b["wer"], maxf(float(a["von"]), float(b["von"]))])
	pruefe(ueber.is_empty(), "nie zwei Bodeneffekte zugleich (%d Einträge, Überlappungen %s)" % [l.size(), str(ueber.slice(0, 4))])
	# Reihenwellen: vom Boss weg bis zur Lichtwand, jede Reihe explodiert einmal
	var wellen := h.protokoll.filter(func(e: Dictionary) -> bool: return str(e.get("was", "")) == "reihenwelle")
	var enden := h.protokoll.filter(func(e: Dictionary) -> bool: return str(e.get("was", "")) == "reihenwelle_ende")
	var voll := enden.all(func(e: Dictionary) -> bool: return (e["explosionen"] as Array).size() >= 2)
	if art == "plasma":   # J: statt der Reihenwellen – Gel-Deckel (Boss und Klon zusammen)
		var klon_gel := h.protokoll.filter(func(e: Dictionary) -> bool: return str(e.get("was", "")) == "gel").size()
		pruefe(_gele_max <= Werte.BOSS_PLASMA_GEL_MAX and _gele_max >= 1, "Gele: höchstens %d zugleich (Deckel %d), %d gelegt" % [_gele_max, Werte.BOSS_PLASMA_GEL_MAX, klon_gel])
	elif art == "gunner":   # I: statt der Reihenwellen – oben höchstens 6 s
		var kronen := h.protokoll.filter(func(e: Dictionary) -> bool: return str(e.get("was", "")) == "krone_ende")
		pruefe(kronen.all(func(e: Dictionary) -> bool: return float(e["oben"]) <= Werte.BOSS_GUNNER_KRONE_MAX + 0.1), "Kronen: %d, oben %s s (höchstens %.0f)" % [kronen.size(), str(kronen.map(func(e: Dictionary) -> float: return snappedf(float(e["oben"]), 0.1))), Werte.BOSS_GUNNER_KRONE_MAX])
	else:
		pruefe(not wellen.is_empty() and enden.size() >= wellen.size() - 1 and voll, "Reihenwellen: %d begonnen, %d bis zum Rand (Reihen %s)" % [wellen.size(), enden.size(), str(wellen.map(func(e: Dictionary) -> int: return int(e["reihen"])))])
	# Vergeltung: immer die Säule, nie auf markiertem Boden
	var verg := h.protokoll.filter(func(e: Dictionary) -> bool: return str(e.get("was", "")) == "vergeltung")
	pruefe(verg.size() >= 3 and verg.all(func(e: Dictionary) -> bool: return str(e["art"]) == "saeule"), "Vergeltung: %d×, immer Lichtsäule" % verg.size())
	var z := h.zaehlung
	print("ZAEHLUNG lang: doppelstuerme %d, boden %d %%, abstand %.1f, fenster genutzt %d %%, treffer %s, angriffe %s" % [int(z.get("doppelstuerme", 0)), h.boden_anteil(),
		BrakkBossarena.abstand_mittel(z), BrakkBossarena.fenster_zeit_prozent(z), str(z["treffer"]), str(h.angriffe_je_art)])
	pruefe((art != "scharf" or int(z.get("doppelstuerme", 0)) >= 2) and float(z.get("abstand_zeit", 0.0)) > 30.0, "Zählung: %d Doppelstürme, Bodenmarkierung %d %%, Abstand Ø %.1f Felder, Fenster genutzt %d %%" % [int(z.get("doppelstuerme", 0)), h.boden_anteil(), BrakkBossarena.abstand_mittel(z), BrakkBossarena.fenster_zeit_prozent(z)])
