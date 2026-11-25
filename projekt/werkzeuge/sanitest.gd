extends SceneTree
## 25.11.: Sanitäter-Heilung stapelt abnehmend (Werte.SANITAETER_STAPEL): 1, 4, 5, 7 Sanitäter auf einem Ziel heilen je
## Takt das 1,0- / 4,0- / 4,5- / 4,75-Fache des Grundwerts; sich selbst heilt keiner.
##   godot --headless --path . -s werkzeuge/sanitest.gd
var fehler: Array[String] = []
var spiel: Node

func pruefe(ok: bool, text: String) -> void:
	print("%s %s" % ["OK  " if ok else "FEHL", text])
	if not ok:
		fehler.append(text)

func _initialize() -> void:
	_los()

func _los() -> void:
	Online.gesperrt = true
	var main: GDScript = load("res://scripts/main.gd")
	main.ohne_spuren = true
	spiel = load("res://main.tscn").instantiate()
	root.add_child(spiel)
	for i in 10:
		await process_frame
	spiel._normales_spiel()
	spiel._welle = {"leben_faktor": 1.0}
	var zelle := Vector2i(14, 6)
	var mitte: Vector2 = spiel.karte.mitte(zelle)
	var grund := float(Werte.GEGNER["sani"]["heilung"])
	for fall: Array in [[1, 1.0], [4, 4.0], [5, 4.5], [7, 4.75], [10, 4.75]]:
		for g in spiel.gegner:
			g.queue_free()
		spiel.gegner.clear()
		var ziel: Gegner = spiel._neuer_gegner("hund", zelle, 0)
		ziel.position = mitte
		ziel.max_leben = 1000.0
		ziel.leben = 100.0
		var sanis: Array = []
		for i in int(fall[0]):
			var s: Gegner = spiel._neuer_gegner("sani", zelle, 0)
			s.position = mitte + Vector2(2.0 + i, 0.0)   # verschieden weit weg
			sanis.append(s)
		for s: Gegner in sanis:
			s._abkling = 0.0
			s._heile(s.reichweite_px())
		var geheilt: float = ziel.leben - 100.0
		pruefe(is_equal_approx(geheilt, float(fall[1]) * grund * sanis[0].leben_faktor),
			"%d Sanitäter: %.2f × Grundwert (soll %.2f)" % [fall[0], geheilt / (grund * sanis[0].leben_faktor), fall[1]])
	# der nächste zählt voll, der fernste von sieben gar nicht
	var s_nah: Gegner = spiel.gegner[1]
	var s_fern: Gegner = spiel.gegner[7]
	var z: Gegner = spiel.gegner[0]
	var helfer: Array = spiel.gegner.slice(1, 8)
	pruefe(is_equal_approx(s_nah._stapel_anteil(z, helfer), 1.0) and is_equal_approx(s_fern._stapel_anteil(z, helfer), 0.0), "Reihenfolge nach Abstand")
	# sich selbst heilt er nicht
	for g in spiel.gegner:
		g.queue_free()
	spiel.gegner.clear()
	var allein: Gegner = spiel._neuer_gegner("sani", zelle, 0)
	allein.position = mitte
	allein.leben = 10.0
	allein._abkling = 0.0
	allein._heile(allein.reichweite_px())
	pruefe(is_equal_approx(allein.leben, 10.0), "heilt sich nicht selbst")
	print("TEST SANI OK" if fehler.is_empty() else "TEST SANI FEHLER: %s" % ", ".join(fehler))
	quit(0 if fehler.is_empty() else 1)
