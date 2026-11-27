extends SceneTree
## 25.11.: Angriff ab Runde 8. Angreifer startet in 8 mit dem Bau von Runde 8; als Verteidiger laufen gegen ein
## Angriffs-Phantom ab 8 die Runden 1–7 als Standardwellen, gegen ein altes (ab 1) kommt es von Anfang an.
##   godot --headless --path . -s werkzeuge/startrundetest.gd
var fehler: Array[String] = []
var spiel: Node

func pruefe(ok: bool, text: String) -> void:
	print("%s %s" % ["OK  " if ok else "FEHL", text])
	if not ok:
		fehler.append(text)

func _neues_spiel() -> void:
	if spiel != null:
		spiel.queue_free()
		await process_frame
	spiel = load("res://main.tscn").instantiate()
	root.add_child(spiel)
	for i in 10:
		await process_frame

func _angriff_ab(erste: int) -> String:
	var runden: Array = []
	for nr in range(erste, 21):
		runden.append({"runde": nr, "trupps": [{"weg": "l", "typen": ["hund", "hund"]}], "leben_genommen": 0})
	var pfad := "user://angriff-test-ab%d.json" % erste
	var f := FileAccess.open(pfad, FileAccess.WRITE)
	f.store_string(JSON.stringify({"art": "angriff", "spieler": "Testgegner", "phantom_version": Phantom.PHANTOM_VERSION, "runden": runden}))
	f.close()
	return pfad

func _initialize() -> void:
	_los()

func _los() -> void:
	Online.gesperrt = true
	Profil.setze_einstellung("pe_taktik", true)
	Profil.setze_einstellung("pe_verteidigung", true)
	var main: GDScript = load("res://scripts/main.gd")
	main.ohne_spuren = true
	# Angreifer
	await _neues_spiel()
	var bau := ""
	for f: Dictionary in Phantom.liste("verteidigung"):
		if (Phantom.lade(f["pfad"])["runden"] as Array).size() >= 20:
			bau = f["pfad"]
			break
	pruefe(spiel.phantom_partie.starte_angriff(bau), "Angriff gestartet")
	pruefe(spiel.welle == 8, "Angriff beginnt in Runde 8 (%d)" % spiel.welle)
	var stand: Dictionary = Phantom.lade(bau)["runden"][7]["stand"]
	pruefe(spiel.fabriken.size() == (stand["fabriken"] as Array).size(), "Bau von Runde 8 steht: %d Fabriken (Aufzeichnung %d)" % [spiel.fabriken.size(), (stand["fabriken"] as Array).size()])
	pruefe(spiel.karte.cp_aktiv == (Werte.plan_runde(8) >= Werte.CHECKPOINTS_AB_WELLE), "Checkpoints wie in Runde 8")
	spiel.leben = spiel.leben - 3
	spiel.phantom_partie.angriff_ende("beendet")
	pruefe(int(spiel.phantom_partie.angriff_log[0]["runde"]) == 8 and int(spiel.phantom_partie.angriff_log[0]["budget"]) == Phantom.budget(8), "erste gebuchte Runde 8 mit dem Budget von 8")
	var summe := 0
	for nr in range(8, 21):
		summe += Phantom.budget(nr)
	print("Budget Runde 8–20 zusammen: %d" % summe)
	# Verteidiger gegen ein Phantom ab 8
	await _neues_spiel()
	pruefe(spiel.phantom_partie.starte_verteidigung(_angriff_ab(8)), "Verteidigung gegen Phantom ab 8")
	pruefe(spiel.welle == 1, "Verteidiger beginnt in Runde 1")
	pruefe(spiel.phantom_partie.trupps(7).is_empty() and spiel.phantom_partie.banner(7) == "", "Runde 7: Standardwelle ohne Banner")
	spiel.welle = 7
	pruefe(not str(spiel.naechste_welle()["name"]).begins_with("Angriff von"), "Runde 7 ist die entworfene Welle")
	spiel.welle = 8
	pruefe(str(spiel.naechste_welle()["name"]) == "Angriff von Testgegner", "Runde 8 kommt vom Phantom")
	pruefe(spiel.phantom_partie.banner(8) == "AB JETZT: ANGRIFF VON TESTGEGNER", "Banner Runde 8: %s" % spiel.phantom_partie.banner(8))
	# Verteidiger gegen ein altes Phantom ab 1
	await _neues_spiel()
	pruefe(spiel.phantom_partie.starte_verteidigung(_angriff_ab(1)), "Verteidigung gegen altes Phantom")
	pruefe(str(spiel.naechste_welle()["name"]) == "Angriff von Testgegner", "altes Phantom ab Runde 1")
	pruefe(not spiel.phantom_partie.banner(1).begins_with("AB JETZT"), "kein „Ab jetzt“ bei altem Phantom")
	print("TEST STARTRUNDE OK" if fehler.is_empty() else "TEST STARTRUNDE FEHLER: %s" % ", ".join(fehler))
	quit(0 if fehler.is_empty() else 1)
