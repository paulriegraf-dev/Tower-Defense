class_name Labor
extends RefCounted
## Schritt 9a, Teil 3: Schalter fürs Balance-Labor.
## sperren() schaltet alles ab, was eine Bot-Partie nach außen tragen könnte – hart, für den ganzen Prozess:
## keine Rangliste, kein Phantom-Upload, keine Duelle (Online.gesperrt), kein Profil/keine Erfolge (Profil.nur_lesen),
## kein Zwischenstand, kein Sitzungs-Merker, nichts in partien/ oder „Phantom Dateien“ (main.ohne_spuren).
## Labor-Material liegt in labor/ (Ausgaben in labor/laeufe/, mit .gdignore).

const ORDNER := "res://labor"
const LAEUFE := "res://labor/laeufe"

static var aktiv := false


static func sperren() -> void:
	aktiv = true
	Online.gesperrt = true
	Profil.nur_lesen = true
	OS.set_environment("TD_OFFLINE", "1")
	OS.set_environment("TD_ONLINE", "")
	(load("res://scripts/main.gd") as GDScript).set("ohne_spuren", true)


## Ausgabeordner anlegen (mit .gdignore, damit Godot die Ergebnisse nicht importiert).
static func ordner_anlegen() -> String:
	var pfad := ProjectSettings.globalize_path(LAEUFE)
	DirAccess.make_dir_recursive_absolute(pfad)
	var ignore := pfad.path_join(".gdignore")
	if not FileAccess.file_exists(ignore):
		var f := FileAccess.open(ignore, FileAccess.WRITE)
		f.store_string("")
		f.close()
	return pfad
