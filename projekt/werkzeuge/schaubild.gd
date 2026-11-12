extends SceneTree
## Baut feste Erdwall-Formationen mit unbegrenztem Budget auf (ohne Gegner) und speichert je ein Bild.
##
## Aufruf (braucht eine Grafikausgabe, z. B. unter xvfb):
##   godot --path . --rendering-driver opengl3 -s werkzeuge/schaubild.gd -- <Zielordner>
##
## Die Pläne stehen in werkzeuge/plaene.gd.

const PLAENE: Dictionary = preload("res://werkzeuge/plaene.gd").PLAENE

var ziel := "."
var namen: Array = []
var index := -1
var spiel: Node
var warte := 0
var schritt := 0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		ziel = args[0]
	namen = PLAENE.keys()
	_naechster()


func _naechster() -> void:
	index += 1
	if spiel != null:
		spiel.queue_free()
		spiel = null
	if index >= namen.size():
		quit(0)
		return
	spiel = load("res://main.tscn").instantiate()
	root.add_child(spiel)
	spiel.protokoll_an = false
	warte = 3
	schritt = 0


func _process(_delta: float) -> bool:
	if spiel == null:
		return false
	if warte > 0:
		warte -= 1
		return false
	if schritt == 0:
		_baue(PLAENE[namen[index]])
		schritt = 1
		warte = 20
		return false
	var bild := root.get_texture().get_image()
	bild.save_png("%s/%s.png" % [ziel, namen[index]])
	_naechster()
	return false


func _baue(plan: Array) -> void:
	var karte: Karte = spiel.karte
	spiel.budget = 100000
	spiel.welle = 7   # Checkpoints sind da, und für diese Runde gibt es keine Ansage, die das Bild verdeckt
	karte.cp_aktiv = true
	var cps: Array = [[6, 4], [13, 5]]
	for y in plan.size():
		for x in (plan[y] as String).length():
			var c: String = plan[y][x]
			if c == "1":
				cps[0] = [x, y]
			elif c == "2":
				cps[1] = [x, y]
	spiel.setze_checkpoints(cps)
	var fehler := 0
	# erst alle Erdwälle, dann die Ausbauten (ein Turm braucht seine Nachbarn)
	for durchgang in 2:
		for y in plan.size():
			for x in (plan[y] as String).length():
				var c: String = plan[y][x]
				var z := Vector2i(x, y)
				var ok := true
				if durchgang == 0:
					if c in ["#", "S", "T", "O"]:
						ok = spiel.baue(z, Karte.WALL, true)
					elif c == "F":
						ok = spiel.baue(z, Karte.FABRIK, true)
					elif c == "B":
						ok = spiel.baue(z, Karte.BATTERIE, true)
				else:
					if c == "S":
						ok = spiel.baue(z, Karte.STELLUNG, true)
					elif c == "T":
						ok = spiel.baue(z, Karte.TURM, true)
					elif c == "O":
						ok = spiel.baue(z, Karte.TOR, true)
				if not ok:
					fehler += 1
					print("  nicht gebaut: ", c, " bei ", z, " – ", spiel.bau_hindernis(z, Karte.WALL if durchgang == 0 else Karte.TURM))
	var waelle := 0
	var turmplaetze := 0
	for z: Vector2i in karte.feld:
		if karte.feld[z] == Karte.WALL:
			waelle += 1
			if karte.wall_nachbarn(z) >= Werte.TURM_NACHBARN:
				turmplaetze += 1
	var stuecke := {}
	for z: Vector2i in karte.feld:
		if karte.feld[z] == Karte.WALL:
			stuecke[karte.stueck_nr(z)] = true
	print("%s: Gegnerweg %d Felder, bricht durch: %s, Erdwälle %d, Wallstücke %d, mögliche Turmplätze %d, Kosten %d, Fehler %d" % [
		namen[index], karte.pfad.size(), karte.weg_bricht_durch(karte.pfad, Karte.KEINE), waelle, stuecke.size(), turmplaetze, 100000 - spiel.budget, fehler])
