extends SceneTree
## 21.11.: Befehl 24, Fluchtphase headless prüfen – Q/E/R gesperrt bis zur Ankunft am Myriaden-HQ, danach frei.
##
##   godot --headless --path . --fixed-fps 60 -s werkzeuge/fluchttest.gd
##
## Am Ende „TEST FLUCHT OK“ oder die Fehler. Schreibt wie das Spiel in user:// – vorher sichern.

var spiel: Node
var o: Order24
var warte := 10
var schritt := 0
var fehler: Array[String] = []


func _initialize() -> void:
	Nemesis.datei = "user://nemesis_test.json"   # 22.11.: Tests schreiben nie in die echte Liste der Meistgesuchten
	Nemesis.zuruecksetzen()
	OS.set_environment("TD_KARTE_NAME", "szenario_order24")
	Werte.lade_karte("szenario_order24")
	var r: Dictionary = (Werte.KARTE_REGELN.get("order24", {}) as Dictionary).duplicate()
	r["karte"] = "3-zitadelle"
	r["brakk_schaden"] = 0
	Order24.test_werte = r
	var main_skript: GDScript = load("res://scripts/main.gd")
	main_skript.set("naechster_start", "normal")
	spiel = load("res://main.tscn").instantiate()
	root.add_child(spiel)
	spiel.protokoll_an = false


func karte_feld() -> Vector2i:
	return (spiel.karte as Karte).zelle_bei(spiel.kommandant.position)


func pruefe(ok: bool, text: String) -> void:
	print("%s %s" % ["OK  " if ok else "FEHL", text])
	if not ok:
		fehler.append(text)


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
	var ego: EgoModus = spiel.ego
	if ego == null:
		return false
	var k: Kommandant = spiel.kommandant
	match schritt:
		0:
			pruefe(o.flucht_sperre(), "nach dem Verrat: Fluchtsperre an (Phase %s)" % o.phase())
			for t: String in ["Q", "E", "R"]:
				var anker_vorher: float = ego._anker
				pruefe(ego._aktion(t, true) and ego._anker == anker_vorher and ego._klettern < 0.0, "[%s] in der Flucht abgefangen" % t)
				ego._aktion(t, false)
			pruefe(not ego._aktion("shift", true) or ego._tumble >= 0.0 or ego._tumble_rest > 0.0, "Tumble [Shift] geht weiter")
			ego._aktion("shift", false)
			# zum Myriaden-HQ: Ankunft löst den Funkspruch aus
			ego._setze_fuss(o.hq_mitte() + Vector2(Werte.ZELLE * 2.0, 0.0))
			k.position = o.hq_mitte() + Vector2(Werte.ZELLE * 2.0, 0.0)
			schritt += 1
		1, 2, 3:
			schritt += 1
		4:
			pruefe(not o.flucht_sperre(), "am Myriaden-HQ angekommen: Sperre aufgehoben")
			pruefe(not o.ego_taste(ego, "Q", true), "[Q] geht wieder an die Fähigkeit")
			# Elitetrupp: 200 % Leben (Stufe 4 ohne Elite-Aufschlag × ROGUE_ELITE_LEBEN)
			var z: Vector2i = spiel.fabriken.keys()[0] if not spiel.fabriken.is_empty() else karte_feld()
			var e := o._neue_truppe("technogunner", z, 4)
			var roh := Einheit.new()   # dieselbe Truppe ohne Befehl-24-Regel
			spiel.figuren.add_child(roh)
			roh.start(spiel, spiel.karte, "technogunner", z, 4, "")
			var normal := o._neue_truppe("technogunner", z, 1)   # Befehl-24-Faktor (truppen_leben, Eskalation) wie bei allen
			var roh1 := Einheit.new()
			spiel.figuren.add_child(roh1)
			roh1.start(spiel, spiel.karte, "technogunner", z, 1, "")
			var grund := roh.max_leben / float(Werte.ELITE["leben"]) * normal.max_leben / roh1.max_leben
			roh.queue_free()
			roh1.queue_free()
			pruefe(absf(e.max_leben - grund * 2.0) < 0.01 and e.leben == e.max_leben, "Elitetrupp: %.0f Leben = 200 %% von %.0f (vorher %.0f)" % [e.max_leben, grund, grund * float(Werte.ELITE["leben"])])
			print("TEST FLUCHT OK" if fehler.is_empty() else "TEST FLUCHT FEHLER: %s" % ", ".join(fehler))
			quit(0 if fehler.is_empty() else 1)
	return false
