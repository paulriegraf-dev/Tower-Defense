extends SceneTree
## Macht aus einer aufgezeichneten Partie ein Verteidigungs-Phantom (Phantom Dateien/Verteidiger/verteidigung-<Datum>.json).
## Aufruf: godot --headless --path . -s werkzeuge/phantom_aus_partie.gd -- <partien/partie-....json>

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		print("Aufruf: ... -s werkzeuge/phantom_aus_partie.gd -- <partie.json>")
		quit(1)
		return
	var partie: Variant = JSON.parse_string(FileAccess.get_file_as_string(args[0]))
	var daten := Phantom.aus_partie(partie, args[0].get_file()) if partie is Dictionary else {}
	if daten.is_empty():
		print("Keine abgeschlossene Runde in dieser Partie.")
		quit(1)
		return
	var ordner: String = Phantom.ordner("verteidigung")[0]
	var ziel := "%s/verteidigung-%s" % [ordner, args[0].get_file().replace("partie-", "")]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ordner))
	var datei := FileAccess.open(ziel, FileAccess.WRITE)
	datei.store_string(JSON.stringify(daten, "\t"))
	datei.close()
	print("Geschrieben: %s (%d Runden, %s)" % [ziel, (daten["runden"] as Array).size(), daten["ergebnis"]["ausgang"]])
	quit()
