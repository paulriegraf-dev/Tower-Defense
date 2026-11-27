extends SceneTree
## G2 (27.11., Paul): Bossarena headless – je Boss ein Lauf:
##
##   godot --headless --path . --fixed-fps 60 -s werkzeuge/bossarenatest.gd -- scharf|gunner|plasma|sonde [gefallen]
##
## Startet die Bossarena (große Karte, nur Wälle), wartet auf Ansage, Kampfplatz und Duell, lässt Brakk 25 s lang treffen
## und getroffen werden (er hält durch), schaltet den Boss dann aus („gefallen“: Brakk fällt) und prüft Tafel und Zählung.
## nemesis.json bleibt unberührt (Prüfung über die Änderungszeit).

const ARTEN := {"scharf": "scharfschuetze", "gunner": "technogunner", "plasma": "plasmawerfer", "sonde": "sonde"}
const SOLL := 13

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


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		art = str(args[0])
	gefallen = args.has("gefallen")
	nemesis_zeit = FileAccess.get_modified_time("user://nemesis.json") if FileAccess.file_exists("user://nemesis.json") else -1
	OS.set_environment("TD_KARTE_NAME", Werte.ORDER24_KARTE_NAME)
	Werte.lade_karte(Werte.ORDER24_KARTE_NAME)
	BrakkBossarena.laeuft = true
	BrakkBossarena.wahl = {"boss": str(ARTEN[art]), "stufe": 6, "ringe": "standard", "frei": [["laser", 1], ["markierung", 1], ["feuerteam", 1]],
		"ladungen": 2, "phase2": false}
	# Menüseite: Einträge, Umschalten (Boss weiter, Ringe „frei“ zeigt sechs Zeilen mehr), danach wie vorher
	var leer := func() -> void: pass
	var n_vorher := BrakkBossarena.menue(leer, leer, leer).size()
	(BrakkBossarena.menue(leer, leer, leer)[1][1] as Callable).call()
	var boss_weiter := str(BrakkBossarena.wahl["boss"])
	BrakkBossarena.wahl["ringe"] = "frei"
	var n_frei := BrakkBossarena.menue(leer, leer, leer).size()
	BrakkBossarena.wahl["boss"] = str(ARTEN[art])
	BrakkBossarena.wahl["ringe"] = "standard"
	pruefe(n_vorher == 7 and n_frei == 13 and boss_weiter != str(ARTEN[art]), "Menü: %d Einträge, mit freien Ringen %d, Boss schaltet auf %s" % [n_vorher, n_frei, boss_weiter])
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
	if geprueft < SOLL:
		fehler.append("nur %d von %d Prüfungen gelaufen" % [geprueft, SOLL])
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
			elif o.zeit - t0 > 40.0:
				pruefe(false, "kein Duell nach 40 s")
				return _fertig()
		2:
			if not gefallen:
				k.leben = k.max_leben
			if h.einheit != null and is_instance_valid(h.einheit) and h.einheit.leben > h.einheit.max_leben * 0.6 and int(o.zeit * 4.0) != int((o.zeit - 0.017) * 4.0):
				if str(h.angriff.get("teil", "")) == "fenster":
					treffer_im_fenster += 1
				_brakk_trifft(h.einheit.max_leben * 0.01)
			if o.zeit - duell_t >= 25.0:
				var z := h.zaehlung
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
