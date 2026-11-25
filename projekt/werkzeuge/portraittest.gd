extends SceneTree
## 25.11.: Band nur in der ersten Phantom-Runde; Portrait des Gegners im HUD (fehlt es, Portrait 0) und im Phantom.
##   godot --headless --path . -s werkzeuge/portraittest.gd
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

func _angriff(erste: int, portrait: Variant) -> String:
	var runden: Array = []
	for nr in range(erste, 21):
		runden.append({"runde": nr, "trupps": [{"weg": "l", "typen": ["hund"]}], "leben_genommen": 0})
	var d := {"art": "angriff", "spieler": "Testgegner", "phantom_version": Phantom.PHANTOM_VERSION, "runden": runden}
	if portrait != null:
		d["portrait"] = portrait
	var pfad := "user://angriff-portrait-%d.json" % erste
	var f := FileAccess.open(pfad, FileAccess.WRITE)
	f.store_string(JSON.stringify(d))
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
	pruefe(Werte.PORTRAITS.size() == 4 and Werte.PORTRAITS.all(func(p: String) -> bool: return load(p) is Texture2D and (load(p) as Texture2D).get_size() == Vector2(32, 32)), "vier Portraits 32×32")
	Profil.setze_einstellung("portrait", 0)
	pruefe(Profil.portrait() == 0, "Standard Portrait 0")
	Profil.setze_portrait(Profil.portrait() - 1)
	pruefe(Profil.portrait() == 3, "Auswahl läuft im Kreis")
	var partie := {"runden": [{"runde": 1, "aktionen": [], "ergebnis": {"ausgang": "geschafft", "leben": 15, "leben_verloren": 0, "checkpoints_verloren": 0, "sekunden": 1, "waelle": 0}}]}
	pruefe(int(Phantom.aus_partie(partie).get("portrait", -1)) == 3, "Verteidigungs-Phantom nimmt das Portrait mit")
	# Verteidiger, altes Phantom ohne Portrait
	await _neues_spiel()
	spiel.starte_phantom_verteidigung(_angriff(1, null))
	pruefe(spiel._phantom_banner(1) != "" and spiel._phantom_banner(2) == "" and spiel._phantom_banner(20) == "", "Band nur in Runde 1")
	pruefe(spiel.gegner_portrait() == {"name": "Testgegner", "portrait": 0}, "ohne Angabe Portrait 0: %s" % str(spiel.gegner_portrait()))
	# Verteidiger, Phantom ab Runde 8 mit Portrait 2
	await _neues_spiel()
	spiel.starte_phantom_verteidigung(_angriff(8, 2))
	pruefe(spiel.gegner_portrait().is_empty(), "vor Runde 8 kein Portrait")
	spiel.welle = 8
	pruefe(int(spiel.gegner_portrait().get("portrait", -1)) == 2, "ab Runde 8 das Portrait des Phantoms")
	pruefe(spiel._phantom_banner(8) != "" and spiel._phantom_banner(9) == "", "Band nur in Runde 8")
	pruefe(Profil.portrait_gueltig(99.0) == 0 and Profil.portrait_gueltig("x") == 0, "ungültige Werte ergeben 0")
	# Angreifer: Portrait des Verteidigers
	await _neues_spiel()
	var bau: Dictionary = Phantom.liste("verteidigung")[0]
	spiel.starte_phantom_angriff(str(bau["pfad"]))
	pruefe(str(spiel.gegner_portrait().get("name", "")) == str(Phantom.lade(bau["pfad"]).get("spieler", "")), "Angreifer sieht den Verteidiger")
	Profil.setze_einstellung("portrait", 0)
	print("TEST PORTRAIT OK" if fehler.is_empty() else "TEST PORTRAIT FEHLER: %s" % ", ".join(fehler))
	quit(0 if fehler.is_empty() else 1)
