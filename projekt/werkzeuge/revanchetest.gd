extends SceneTree
## 25.11.: Revanche über die Endtafel – beide Seiten: Der neu geladene Lauf hat dasselbe Phantom (und beim Angriff
## dieselbe Ersatz-Reihenfolge); nach zwei Revanchen ist der Knopf verbraucht.
##   godot --headless --path . -s werkzeuge/revanchetest.gd
var fehler: Array[String] = []
var spiel: Node

func pruefe(ok: bool, text: String) -> void:
	print("%s %s" % ["OK  " if ok else "FEHL", text])
	if not ok:
		fehler.append(text)

func _bilder(n: int) -> void:
	for i in n:
		await process_frame

## Drückt einen Knopf der Endtafel und wartet auf die neu geladene Szene.
func _druecke(i: int) -> void:
	var alt := spiel
	(spiel._tafel.conf["knoepfe"][i][1] as Callable).call()
	var ende := Time.get_ticks_msec() + 20000
	while (current_scene == null or current_scene == alt) and Time.get_ticks_msec() < ende:
		await process_frame
	spiel = current_scene
	await _bilder(10)
	var warten := Time.get_ticks_msec() + 3000   # das Ladebild ausblenden lassen
	while Ladebild._aktiv != null and is_instance_valid(Ladebild._aktiv) and Time.get_ticks_msec() < warten:
		await process_frame

func _knopf_text(i: int) -> String:
	return str(spiel._tafel.conf["knoepfe"][i][0])

func _initialize() -> void:
	_los()

func _los() -> void:
	Online.gesperrt = true
	Profil.setze_einstellung("pe_taktik", true)
	Profil.setze_einstellung("pe_verteidigung", true)
	var main: GDScript = load("res://scripts/main.gd")
	main.ohne_spuren = true
	spiel = load("res://main.tscn").instantiate()
	root.add_child(spiel)
	current_scene = spiel
	await _bilder(10)

	# --- Verteidigung gegen ein Angriffs-Phantom: verlieren -> Revanche
	var angriffe := Phantom.liste("angriff")
	var gegner: String = angriffe[0]["pfad"]
	var name := str(Phantom.lade(gegner).get("spieler", ""))
	pruefe(spiel.starte_phantom_verteidigung(gegner), "Verteidigung gestartet gegen %s" % gegner.get_file())
	for nr in 3:
		spiel.leben = 0
		spiel._zeige_niederlage("", 0, 0)
		if nr == 2:
			break
		pruefe(_knopf_text(0) == "Revanche gegen %s" % name, "Knopf %d: %s" % [nr + 1, _knopf_text(0)])
		await _druecke(0)
		pruefe(spiel.phantom_modus == "verteidigung" and spiel._angriff_pfad == gegner and str(spiel._angriff_phantom.get("begonnen")) == str(Phantom.lade(gegner).get("begonnen")),
			"Revanche %d lädt dasselbe Angriffs-Phantom (%s, Modus '%s')" % [nr + 1, spiel._angriff_pfad.get_file(), spiel.phantom_modus])
	pruefe(_knopf_text(1) == "Revanche verbraucht" and _knopf_text(0) == "Startmenü", "nach 2 Revanchen verbraucht: %s / %s" % [_knopf_text(0), _knopf_text(1)])
	var vorher := spiel
	(spiel._tafel.conf["knoepfe"][1][1] as Callable).call()
	await _bilder(60)
	pruefe(current_scene == vorher, "der graue Knopf tut nichts")
	await _druecke(0)

	# --- Angriff: erste Verteidigung A fällt, B übernimmt, C wartet -> Revanche mit derselben Reihenfolge
	var da: Array = Phantom.liste("verteidigung").filter(func(f: Dictionary) -> bool: return (Phantom.lade(f["pfad"])["runden"] as Array).size() >= 8)
	pruefe(da.size() >= 3, "drei Verteidigungen im Pool (%d)" % da.size())
	var a: String = da[0]["pfad"]
	var b: String = da[1]["pfad"]
	var c: String = da[2]["pfad"]
	var name_a := str(Phantom.lade(a).get("spieler", ""))
	Online.ersatz_pfade = [b, c]
	pruefe(spiel.starte_phantom_angriff(a), "Angriff gestartet gegen %s" % a.get_file())
	spiel.welle = 9
	spiel.leben = 0
	spiel._phantom_gefallen()
	(spiel._tafel.conf["knoepfe"][0][1] as Callable).call()   # weiter gegen das Ersatz-Phantom
	await _bilder(5)
	pruefe(spiel._aktiv_pfad == b, "Ersatz B steht")
	for nr in 2:
		spiel._angriff_ende("beendet")
		pruefe(_knopf_text(0) == "Revanche gegen %s" % name_a, "Angriff, Knopf %d: %s" % [nr + 1, _knopf_text(0)])
		await _druecke(0)
		pruefe(spiel.phantom_modus == "angriff" and spiel._phantom_pfad == a and spiel._aktiv_pfad == a and spiel.welle == Phantom.ANGRIFF_AB_RUNDE, "Revanche %d: dieselbe Verteidigung A" % (nr + 1))
		pruefe(spiel._ersatz == [b, c], "Ersatz-Reihenfolge bleibt: %s" % str(spiel._ersatz.map(func(p: String) -> String: return p.get_file())))
	spiel._angriff_ende("beendet")
	pruefe(_knopf_text(1) == "Revanche verbraucht", "Angriff: nach 2 Revanchen verbraucht")

	print("TEST REVANCHE OK" if fehler.is_empty() else "TEST REVANCHE FEHLER: %s" % ", ".join(fehler))
	quit(0 if fehler.is_empty() else 1)
