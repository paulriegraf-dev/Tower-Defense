extends SceneTree
## E3 (26.11., Paul): schreibt je Formation aus [H] (Werte.ALARM_FORMATIONEN) die Fassung für die große Befehl-24-Karte
## nach karten/b24/<name>_b24.json (BrakkGebiete.plan_b24: Gürtel, Trümmer im Niemandsland, Außenposten).
##
##   godot --headless --path . -s werkzeuge/b24_formationen.gd
##
## Nach einer Änderung an ORDER24_KARTE oder ORDER24_GEBIETE neu laufen lassen (passt eine Datei nicht zur Kartengröße,
## erzeugt Order24 den Plan beim Start selbst).

func _initialize() -> void:
	Werte.lade_karte(Werte.ORDER24_KARTE_NAME)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(BrakkGebiete.ORDNER_B24))
	for name: String in Werte.ALARM_FORMATIONEN:
		var plan := BrakkGebiete.plan_b24(name)
		var pfad := BrakkGebiete.ORDNER_B24 + name + "_b24.json"
		var f := FileAccess.open(pfad, FileAccess.WRITE)
		f.store_string(JSON.stringify({"name": name + "_b24", "spalten": Werte.SPALTEN, "zeilen": Werte.ZEILEN, "plan": plan}, "\t"))
		f.close()
		print("B24 %s: %d Wälle" % [pfad, "".join(PackedStringArray(plan)).count("#") + "".join(PackedStringArray(plan)).count("O")])
		for zeile: String in plan:
			print("    " + zeile)
	quit(0)
