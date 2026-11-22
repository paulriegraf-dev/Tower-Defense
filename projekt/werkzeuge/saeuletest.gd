extends SceneTree
## 22.11.: Lichtsäule – Form der Vorschau gegen die tatsächlichen Einschlagpunkte prüfen (scripts/ego_modus.gd).
##
##   godot --headless --path . --fixed-fps 60 -s werkzeuge/saeuletest.gd
##
## Je Ring wird die Vorschau-Form (Node3D _saeule_form) gebaut und an einen Punkt mit einer Richtung gesetzt, dann
## schlägt die Säule ein. Durchschlagring und Feuerteam: die Ringe der Form (in Weltkoordinaten) müssen auf den
## Einschlagpunkten liegen (Toleranz 0,05 Felder). Brandfeld / Gel / Abpraller: Radien der Form gegen die Rechnung.
## Außerdem: Richtung beim Bestätigen wird übernommen, Feuerteam startet bei 0° ab Richtung (kein Zufall).
## Am Ende „TEST SAEULE OK“ oder die Fehler. Schreibt ins Profil (user://) – vorher sichern.

const TOL := 0.05   # Felder

var spiel: Node
var ego: EgoModus
var warte := 20
var t0 := 0
var fehler: Array[String] = []


func _initialize() -> void:
	BrakkTutorial.erzwingen = false
	Werte.setze_anfuehrer("brakk")
	if Werte.karte_name != "paulland" or not Werte.karte_gross:
		Werte.karte_name = "paulland"
		Werte.setze_karte(true)
		Werte.speichere_einstellungen()
	var main_skript: GDScript = load("res://scripts/main.gd")
	main_skript.set("naechster_start", "brakk")
	spiel = load("res://main.tscn").instantiate()
	root.add_child(spiel)
	spiel.protokoll_an = false
	t0 = Time.get_ticks_msec()


func pruefe(ok: bool, text: String) -> void:
	print("%s %s" % ["OK  " if ok else "FEHL", text])
	if not ok:
		fehler.append(text)


func _process(_delta: float) -> bool:
	if warte > 0:
		warte -= 1
		return false
	if ego == null:
		ego = spiel.ego
		if ego == null:
			if Time.get_ticks_msec() - t0 > 20000:
				pruefe(false, "keine Ego-Sicht")
				_ende()
			return false
		warte = 10
		return false
	_pruefe_alles()
	_ende()
	return false


func _ende() -> void:
	print("TEST SAEULE OK" if fehler.is_empty() else "TEST SAEULE FEHLER: %s" % ", ".join(fehler))
	quit(0 if fehler.is_empty() else 1)


## Welt-Mittelpunkt der Ringe (Torus) der Form als 2D-Punkte.
func _form_punkte() -> Array[Vector2]:
	var aus: Array[Vector2] = []
	for k in ego._saeule_form.get_children():
		if k is MeshInstance3D and (k as MeshInstance3D).mesh is TorusMesh:
			aus.append(ego._zu2d(ego._saeule_form.transform * (k as Node3D).position))
	return aus


func _passt(erwartet: Array, form: Array[Vector2], name: String) -> void:
	pruefe(erwartet.size() == form.size(), "%s: %d Einschläge, %d Formringe" % [name, erwartet.size(), form.size()])
	if erwartet.size() != form.size():
		return
	var rest := form.duplicate()
	var worst := 0.0
	for e: Array in erwartet:
		var best := INF
		var bi := -1
		for i in rest.size():
			var d := (e[1] as Vector2).distance_to(rest[i]) / Werte.ZELLE
			if d < best:
				best = d
				bi = i
		worst = maxf(worst, best)
		if bi >= 0:
			rest.remove_at(bi)
	pruefe(worst <= TOL, "%s: Vorschau = Einschlagpunkte (größte Abweichung %.3f Felder)" % [name, worst])


func _pruefe_alles() -> void:
	var p := Vector2(600.0, 700.0)
	for richtung: Vector2 in [Vector2.RIGHT, Vector2.UP, Vector2.from_angle(0.7), Vector2.from_angle(-2.3)]:
		for ring in ["durchschuss", "feuerteam"]:
			ego._saeule_ring = ring
			ego._saeule_farbe = Color.WHITE
			ego._baue_saeule_form()
			ego._saeule_form_setze(p, richtung, 1.0)
			ego._einschlaege.clear()
			ego._saeule_blick = richtung
			ego._saeule_ausloesen(p)
			_passt(ego._einschlaege.duplicate(), _form_punkte(), "%s, Richtung %.0f°" % [ring, rad_to_deg(richtung.angle())])
	# Feuerteam: erster Einschlag liegt in Blickrichtung (0°), die anderen 120° / 240° daneben
	var pk: Array = ego.saeule_punkte("feuerteam", Vector2.ZERO, Vector2.RIGHT)
	for i in 3:
		var soll := Vector2.RIGHT.rotated(TAU * float(i) / 3.0) * Werte.ZELLE * 0.8
		pruefe((pk[i][1] as Vector2).distance_to(soll) < 0.01, "Feuerteam %d: %d°" % [i, 120 * i])
	pruefe(ego.saeule_punkte("feuerteam", p, Vector2.UP) == ego.saeule_punkte("feuerteam", p, Vector2.UP), "Feuerteam: ohne Zufall")
	# Durchschlagring: Pfeil zeigt in Wirkrichtung (Spitze vor dem letzten Einschlag)
	ego._saeule_ring = "durchschuss"
	ego._baue_saeule_form()
	var richtung := Vector2.from_angle(1.1)
	ego._saeule_form_setze(p, richtung, 1.0)
	var pfeil: MeshInstance3D = null
	for k in ego._saeule_form.get_children():
		if k is MeshInstance3D and (k as MeshInstance3D).mesh is CylinderMesh:
			pfeil = k
	pruefe(pfeil != null, "Durchschlagring: Pfeil vorhanden")
	if pfeil != null:
		var w := ego._zu2d(ego._saeule_form.transform * pfeil.position)
		pruefe(((w - p) / Werte.ZELLE).distance_to(richtung * 3.25) < TOL, "Durchschlagring: Pfeil in Wirkrichtung")
	# Radien der übrigen Formen
	for t: Array in [["brandfeld", 1.3, true], ["plasmagel", 1.2, false], ["abpraller", 0.0, false]]:
		ego._saeule_ring = t[0]
		ego._baue_saeule_form()
		var n := ego._saeule_form.get_child_count()
		pruefe(n > 0, "%s: Form vorhanden (%d Teile)" % [t[0], n])
		if t[0] == "brandfeld":
			var ok := true
			for k in ego._saeule_form.get_children():
				var d := Vector2((k as Node3D).position.x, (k as Node3D).position.z).length()
				ok = ok and absf(d - EgoModus.SAEULE_RADIUS * float(t[1])) < TOL
			pruefe(ok, "brandfeld: Strichring in Brandfeldgröße (r × 1,3)")
		elif t[0] == "plasmagel":
			var tor := (ego._saeule_form.get_child(0) as MeshInstance3D).mesh as TorusMesh
			pruefe(absf(tor.outer_radius - EgoModus.SAEULE_RADIUS * 1.2) < TOL, "plasmagel: Ring in Gelgröße (r × 1,2)")
		else:
			var tor2 := (ego._saeule_form.get_child(0) as MeshInstance3D).mesh as TorusMesh
			pruefe(absf(tor2.outer_radius - 4.0) < TOL, "abpraller: Ring mit 4 Feldern Umkreis")
	# Richtung beim Bestätigen wird übernommen
	ego._saeule_ring = "durchschuss"
	ego._saeule_zielt = true
	ego._saeule_ziel = Vector2.INF
	ego._saeule_bestaetigen(ego._fuss2d() + Vector2(Werte.ZELLE * 2.0, 0.0), Vector2.from_angle(2.0))
	pruefe(ego._saeule_ziel != Vector2.INF and ego._saeule_blick.distance_to(Vector2.from_angle(2.0)) < 0.001, "Bestätigen übernimmt die gedrehte Richtung")
	ego._saeule_ziel = Vector2.INF
