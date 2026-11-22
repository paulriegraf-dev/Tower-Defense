extends SceneTree
## Schritt 9b: Endaufbau aus aufgezeichneten Partien als Rasterbild und Kennzahlen (nur lesen).
##   godot --headless --path . -s werkzeuge/layouts.gd -- [Mindestrunde=18] [Ordner=res://partien]
## Zeichen: B Basis, 1/2 Checkpoint, # Erdwall, T Turm, S Stellung, D Tor, F Fabrik, P Pilotenfabrik, A Batterie,
## G Generator, . frei

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var mindest := int(args[0]) if args.size() > 0 else 18
	var ordner := args[1] if args.size() > 1 else "res://partien"
	var dateien := DirAccess.get_files_at(ordner)
	for name in dateien:
		if not name.ends_with(".json"):
			continue
		var p: Variant = JSON.parse_string(FileAccess.get_file_as_string(ordner.path_join(name)))
		if not (p is Dictionary) or not p.has("runden"):
			continue
		var runden: Array = p["runden"]
		if runden.size() < mindest:
			continue
		var zellen := {}
		var schilde := {}
		var kaeufe := {}
		for r: Dictionary in runden:
			for a: Dictionary in r.get("aktionen", []):
				Phantom._wende_an(zellen, schilde, a)
				var k := str(a["a"]) + ":" + str(a.get("typ", a.get("faehigkeit", "")))
				kaeufe[k] = int(kaeufe.get(k, 0)) + 1
		var letzte: Dictionary = runden[runden.size() - 1]
		var erg: Dictionary = letzte.get("ergebnis", {})
		print("\n=== %s  Anführer %s  Runden %d  Ausgang %s  Leben %s" % [name, p.get("anfuehrer", "brakk"), runden.size(), erg.get("ausgang", "?"), erg.get("leben", "?")])
		var b: Array = p.get("basis", [18, 5])
		var cps: Array = p.get("checkpoints", [])
		var max_x := 0
		var max_y := 0
		for z: Vector2i in zellen:
			max_x = maxi(max_x, z.x)
			max_y = maxi(max_y, z.y)
		max_x = maxi(max_x, int(b[0]) + 1)
		max_y = maxi(max_y, int(b[1]) + 1)
		for c: Array in cps:
			max_x = maxi(max_x, int(c[0]))
			max_y = maxi(max_y, int(c[1]))
		var zahl := {}
		for y in max_y + 1:
			var zeile := ""
			for x in max_x + 1:
				var z := Vector2i(x, y)
				var ch := "."
				if zellen.has(z):
					var c: Dictionary = zellen[z]
					match str(c["typ"]):
						"wall":
							ch = {"": "#", "turm": "T", "stellung": "S", "tor": "D", "spiegel": "M", "magnet": "N"}.get(str(c.get("ausbau", "")), "#")
						"fabrik":
							ch = "P" if str(c.get("einheit", "")) == "pilot" else "F"
						"batterie":
							ch = "A"
						"generator", "generator_teil":
							ch = "G"
					zahl[ch] = int(zahl.get(ch, 0)) + 1
				if x >= int(b[0]) and x <= int(b[0]) + 1 and y >= int(b[1]) and y <= int(b[1]) + 1 and ch == ".":
					ch = "B"
				for i in cps.size():
					if int(cps[i][0]) == x and int(cps[i][1]) == y:
						ch = str(i + 1)
				zeile += ch
			print(zeile)
		print("Bau: ", zahl)
		var stufen := {}
		for z: Vector2i in zellen:
			var c: Dictionary = zellen[z]
			if c.has("stufe") and int(c["stufe"]) > 0:
				var k := "%s %s St%d%s" % [c["typ"], c.get("einheit", c.get("ausbau", "")), int(c["stufe"]), (" " + str(c["faehigkeit"])) if c.has("faehigkeit") else ""]
				stufen[k] = int(stufen.get(k, 0)) + 1
		print("Stufen: ", stufen)
	quit()
