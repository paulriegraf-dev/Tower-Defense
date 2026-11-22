extends SceneTree
## 21.11.: Freischaltung von Phantom- und Brakk-Mode prüfen. Sichert user://profil.json vorher und stellt es am Ende wieder her.
##
##   godot --headless --path . -s werkzeuge/freischalttest.gd            (nur Profil-Regeln)
##   godot --path . -s werkzeuge/freischalttest.gd -- <Bildordner>       (dazu Bilder: Hauptmenü gesperrt, beide Tafeln)
##
## Am Ende „TEST FREISCHALTUNG OK“ oder die Fehler.

const SICHERUNG := "user://profil_vor_freischalttest.json"

var fehler: Array[String] = []
var sicherung := ""
var hatte_datei := false
var bilder := ""
var spiel: Node
var menue: Node
var schritt := 0
var warte := 0


func pruefe(ok: bool, text: String) -> void:
	print("%s %s" % ["OK  " if ok else "FEHL", text])
	if not ok:
		fehler.append(text)


func _profil(d: Dictionary) -> void:
	var f := FileAccess.open(Profil.DATEI, FileAccess.WRITE)
	f.store_string(JSON.stringify(d))
	f.close()
	Profil._geladen = false


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	bilder = a[0] if a.size() > 0 else ""
	# Sicherung als Datei: bricht ein Lauf ab (Absturz, Zeitlimit), stellt der nächste zuerst das echte Profil wieder her
	if FileAccess.file_exists(SICHERUNG):
		DirAccess.copy_absolute(ProjectSettings.globalize_path(SICHERUNG), ProjectSettings.globalize_path(Profil.DATEI))
		print("Sicherung eines abgebrochenen Laufs zurückgeschrieben")
	hatte_datei = FileAccess.file_exists(Profil.DATEI)
	if hatte_datei:
		sicherung = FileAccess.get_file_as_string(Profil.DATEI)
		DirAccess.copy_absolute(ProjectSettings.globalize_path(Profil.DATEI), ProjectSettings.globalize_path(SICHERUNG))
	# alte Profile: Sieg bzw. Brakk in der Statistik → beim ersten Start frei
	_profil({"id": "test", "name": "Test", "stat": {"siege": 2}, "kills": {}})
	pruefe(Profil.phantom_frei() and not Profil.brakk_modus_frei(), "altes Profil mit Sieg: Phantom frei, Brakk gesperrt")
	_profil({"id": "test", "name": "Test", "stat": {}, "kills": {"brakk": 4}})
	pruefe(Profil.brakk_modus_frei() and not Profil.phantom_frei(), "altes Profil mit Brakk-Kills: Brakk frei, Phantom gesperrt")
	_profil({"id": "test", "name": "Test", "stat": {"brakk_siege_sonde7": 1}, "kills": {}})
	pruefe(Profil.brakk_modus_frei(), "altes Profil mit Brakk-Mode-Sieg: Brakk frei")
	# neues Profil: alles gesperrt; die Übernahme läuft nur einmal (spätere Siege schalten über den Erfolg frei)
	_profil({"id": "test", "name": "Test", "stat": {}, "kills": {}})
	pruefe(not Profil.phantom_frei() and not Profil.brakk_modus_frei(), "neues Profil: beide gesperrt")
	Profil.setze_erfolg("aufgestellt")
	pruefe(Profil.brakk_modus_frei(), "Erfolg „aufgestellt“ schaltet Brakk frei")
	Profil.setze_erfolg("gegenangriff")
	pruefe(Profil.phantom_frei(), "Erfolg „gegenangriff“ schaltet Phantom frei")
	_profil({"id": "test", "name": "Test", "stat": {}, "kills": {}})
	Profil.loese_code("allesfrei")
	pruefe(Profil.phantom_frei() and Profil.brakk_modus_frei(), "Code allesfrei: beide frei")
	if bilder == "":
		_ende()
		return
	_profil({"id": "test", "name": "Test", "stat": {}, "kills": {}, "freischaltung_geprueft": true, "e_grafik_gefragt": true})
	spiel = load("res://main.tscn").instantiate()
	root.add_child(spiel)


func _ende() -> void:
	if hatte_datei:
		var f := FileAccess.open(Profil.DATEI, FileAccess.WRITE)
		f.store_string(sicherung)
		f.close()
	elif FileAccess.file_exists(Profil.DATEI):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Profil.DATEI))
	if FileAccess.file_exists(SICHERUNG):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SICHERUNG))
	Profil._geladen = false
	print("TEST FREISCHALTUNG OK" if fehler.is_empty() else "TEST FREISCHALTUNG FEHLER: %s" % ", ".join(fehler))
	quit(0 if fehler.is_empty() else 1)


func _bild(name: String) -> void:
	var img := root.get_texture().get_image()
	img.save_png(bilder.path_join(name))
	print("Bild: " + bilder.path_join(name))


func _process(_delta: float) -> bool:
	if bilder == "" or spiel == null:
		return false
	warte -= 1
	if warte > 0:
		return false
	menue = spiel.get("_menue")
	if menue == null:
		warte = 10
		return false
	match schritt:
		0:
			menue.set("_titel", false)
			menue.set("_auto", 0)
			menue.call("_zeige", "haupt")
			warte = 30
		1:
			_bild("menue_gesperrt.png")
			menue.call("_tafel_auf", "brakk")
			warte = 4
		2:
			_bild("tafel_brakk_ruettelt.png")
			warte = 40
		3:
			_bild("tafel_brakk.png")
			menue.call("_tafel_zu")
			menue.call("_tafel_auf", "phantom")
			warte = 40
		4:
			_bild("tafel_phantom.png")
			_ende()
	schritt += 1
	return false
