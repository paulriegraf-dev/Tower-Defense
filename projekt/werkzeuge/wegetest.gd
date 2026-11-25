extends SceneTree
## 25.11. (N5): angezeigte Gegnerwege – Hauptweg, Nebenwege, alte Wege in der Welle (karte.routen / alte_routen).
##
##   godot --headless --path . --fixed-fps 60 -s werkzeuge/wegetest.gd
##
##   1. Runde 1 (Hauptlinie): ein Weg, der Hauptweg ab der Mitte
##   2. ab Runde 3 (verteilt): Hauptweg Mitte, Nebenwege vom oberen und unteren Rand
##   3. Hauptweg = Startfeld mit den meisten Gegnern (wie bei Ausgängen im Phantom-Modus)
##   4. Welle: Nebenwege sichtbar, solange noch Gegner kommen; Checkpoint eingenommen → neuer Hauptweg ab dem Checkpoint,
##      der alte Weg bleibt gepunktet, solange ein Gegner darauf läuft, und verschwindet, wenn keiner mehr darauf ist
##   5. Bauphase danach: keine alten Wege mehr
##   6. Karte ohne Spiel (Editor, Befehl 24): Weg wie bisher (pfad + neben_pfade)
## Am Ende „TEST WEGE OK“ oder die Fehler.

var spiel: Node
var warte := 20
var schritt := 0
var bilder := 0
var fehler: Array[String] = []
var hund: Gegner
var alter_haupt: Array = []


func _initialize() -> void:
	var main_skript: GDScript = load("res://scripts/main.gd")
	main_skript.set("ohne_spuren", true)
	main_skript.set("naechster_start", "normal")
	Zufall.gewuenscht = 4711   # feste Checkpoints: dieselben Wege in jedem Lauf und jeder Grafik
	spiel = load("res://main.tscn").instantiate()
	root.add_child(spiel)


func pruefe(ok: bool, text: String) -> void:
	print("%s %s" % ["OK  " if ok else "FEHL", text])
	if not ok:
		fehler.append(text)


func _starts() -> Array:
	return spiel.karte.routen.map(func(r: Dictionary) -> Vector2i: return (r["weg"] as Array)[0])


func _process(_delta: float) -> bool:
	if spiel.phase == 1:
		spiel._spawn_in = 1.0e9
	if warte > 0:
		warte -= 1
		return false
	var jetzt := schritt
	schritt += 1
	var k: Karte = spiel.karte
	match jetzt:
		0:
			spiel.protokoll_an = false
			pruefe(k.routen.size() == 1 and bool(k.routen[0]["haupt"]) and _starts()[0] == Werte.START_ZELLE, "Runde 1: nur der Hauptweg ab der Mitte %s" % str(_starts()))
			for i in 9:
				spiel._naechste_bauphase()
			warte = 5
		1:
			pruefe(spiel.welle == 10, "Runde %d" % spiel.welle)
			var s := _starts()
			pruefe(k.routen.size() == 3 and s[0] == Werte.START_ZELLE and s.has(Vector2i(0, 1)) and s.has(Vector2i(0, Werte.ZEILEN - 2)), "Runde 10: Hauptweg Mitte, Nebenwege oben und unten %s" % str(s))
			pruefe(k.routen.slice(1).all(func(r: Dictionary) -> bool: return not r["haupt"] and r["sichtbar"]), "Bauphase: Nebenwege sichtbar")
			print("     Checkpoints %s · Wege ab %s" % [str(k.checkpoints), str(s)])
			_bild("wege_bau_runde10")
			# meiste Gegner oben → Hauptweg oben
			var oben: Vector2i = Werte.AUSGAENGE["oben"]
			k._baue_routen({oben: 12, Werte.START_ZELLE: 3})
			pruefe(_starts()[0] == oben and _starts().size() == 2, "Hauptweg = Startfeld mit den meisten Gegnern %s" % str(_starts()))
			k._baue_routen()
			spiel.budget = 5000
			spiel.baue(_freies_feld(), Karte.FABRIK, true)
			spiel.starte_welle()
			spiel._spawn_in = 1.0e9
			spiel._wurf_schlange = []
			warte = 30
		2:
			pruefe(spiel.phase == 1 and not k.zeige_pfad_kraeftig, "Welle läuft")
			pruefe(k.routen.slice(1).all(func(r: Dictionary) -> bool: return r["sichtbar"]), "Welle: Nebenwege sichtbar, solange noch Gegner kommen")
			alter_haupt = k.routen[0]["weg"]
			# Checkpoint 1 eingenommen: ab jetzt startet der Weg dort
			k.cp_feind[0] = true
			k.aktualisiere_pfad()
			pruefe(_starts()[0] == k.checkpoints[0], "Einnahme: neuer Hauptweg ab Checkpoint 1 %s" % str(_starts()))
			pruefe(k.alte_routen.any(func(r: Dictionary) -> bool: return r["weg"] == alter_haupt), "Einnahme: alter Hauptweg ist jetzt ein alter Weg")
			# ein Hund läuft noch auf dem alten Weg (Feld, das der neue Hauptweg nicht hat)
			var neu: Array = k.routen[0]["weg"]
			var feld: Vector2i = Karte.KEINE
			for z: Vector2i in alter_haupt:
				if not neu.has(z) and z.x >= Werte.ZONE_SPALTEN:
					feld = z
					break
			hund = spiel._neuer_gegner("hund", feld, 0)
			hund.wartet = true   # bleibt stehen
			warte = 30
		3:
			# (liegt sein Feld auch auf einem alten Nebenweg, bleibt der ebenfalls – richtig so)
			pruefe(k.alte_routen.any(func(r: Dictionary) -> bool: return r["weg"] == alter_haupt), "alter Weg bleibt, solange ein Gegner darauf läuft (%d alte)" % k.alte_routen.size())
			_bild("wege_welle_alt")
			spiel.gegner.erase(hund)
			hund.queue_free()
			warte = 30
		4:
			pruefe(k.alte_routen.is_empty(), "kein Gegner mehr darauf: alter Weg weg")
			spiel._schlange = []
			warte = 30
		5:
			pruefe(k.routen.size() == 1, "nach der Einnahme ein Weg (%d)" % k.routen.size())
			spiel._naechste_bauphase()
			warte = 10
		6:
			pruefe(k.zeige_pfad_kraeftig and k.alte_routen.is_empty(), "Bauphase: keine alten Wege")
			var ohne := Karte.new()
			root.add_child(ohne)
			pruefe(ohne.routen.size() == 1 + ohne.neben_pfade.size() and ohne.routen[0]["weg"] == ohne.pfad, "Karte ohne Spiel: Weg wie bisher (%d Wege)" % ohne.routen.size())
			ohne.queue_free()
			print("TEST WEGE OK" if fehler.is_empty() else "TEST WEGE FEHLER: %s" % ", ".join(fehler))
			quit(0 if fehler.is_empty() else 1)
	return false


func _freies_feld() -> Vector2i:
	for x in range(Werte.SPALTEN - 3, Werte.ZONE_SPALTEN + 3, -1):
		for y in range(1, Werte.ZEILEN - 1):
			var z := Vector2i(x, y)
			if spiel.bau_hindernis(z, Karte.FABRIK) == "" and not spiel.karte.pfad.has(z):
				return z
	return Karte.KEINE


func _bild(name: String) -> void:
	var a := OS.get_cmdline_user_args()
	if a.is_empty() or DisplayServer.get_name() == "headless":
		return
	root.get_texture().get_image().save_png(a[0].path_join(name + ".png"))
	print("     Bild: %s.png" % name)
