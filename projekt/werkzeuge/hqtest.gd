extends SceneTree
## 22.11.: Brakk-Mode – Einbruch-Anzeige und HQ-Platz headless prüfen.
##
##   godot --headless --path . --fixed-fps 60 -s werkzeuge/hqtest.gd -- einbruch
##
## einbruch: zwei Gegner erreichen nacheinander die Basis → Leben −2, die Ego-Sicht zählt beide, die Anzeige läuft
## und zählt hoch (×2); nach EINBRUCH_SEK ist sie aus.
##   … -- basis   → 40 Seeds: Brakk-Mode-Basis ganz im letzten Drittel; zum Vergleich die alte Regel (rechte Hälfte)
## Am Ende „TEST HQ OK“ oder die Fehler. Schreibt wie das Spiel in user:// – vorher sichern.

var spiel: Node
var ego: EgoModus
var art := "einbruch"
var warte := 10
var fehler: Array[String] = []
var schritt := 0
var t0 := 0


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0:
		art = a[0]
	Werte.anfuehrer = "brakk"
	var main_skript: GDScript = load("res://scripts/main.gd")
	main_skript.set("naechster_start", "brakk")
	spiel = load("res://main.tscn").instantiate()
	root.add_child(spiel)
	spiel.protokoll_an = false


func pruefe(ok: bool, text: String) -> void:
	print("%s %s" % ["OK  " if ok else "FEHL", text])
	if not ok:
		fehler.append(text)


func ende() -> void:
	print("TEST HQ OK" if fehler.is_empty() else "TEST HQ FEHLER: %s" % ", ".join(fehler))
	quit(0 if fehler.is_empty() else 1)


func _process(_delta: float) -> bool:
	if warte > 0:
		warte -= 1
		return false
	if ego == null:
		ego = spiel.ego
		if ego == null:
			return false
		if ego._briefing != null:
			ego._briefing.visible = false
		t0 = Time.get_ticks_msec()
	match art:
		"einbruch":
			_einbruch()
		"basis":
			_basis()
		_:
			pruefe(false, "unbekannte Art „%s“" % art)
			ende()
	return false


## Gegner direkt an der Basis aufstellen und als angekommen melden (wie Gegner._physics_process am Ziel).
func _ankunft() -> void:
	var g := Gegner.new()
	spiel.figuren.add_child(g)
	g.start(spiel, spiel.karte, "hund", 1.0, spiel.karte.basis, 0)
	spiel.gegner.append(g)
	g.trupp = [g]
	spiel.gegner_am_ziel(g)


func _einbruch() -> void:
	match schritt:
		0:
			var leben: int = spiel.leben
			pruefe(ego.einbrueche == 0 and ego._einbruch_rest() == 0.0, "vor dem Einbruch keine Anzeige")
			_ankunft()
			pruefe(spiel.leben == leben - 1, "Leben −1 (%d → %d)" % [leben, spiel.leben])
			pruefe(ego.einbrueche == 1, "Ego-Sicht zählt den Einbruch")
			pruefe(ego._einbruch_rest() > 0.0 and ego._einbruch_zahl == 1, "Anzeige läuft (×1)")
			pruefe(ego._einbruch_ort.distance_to(spiel.karte.mitte(spiel.karte.basis)) < Werte.ZELLE * 2.0, "Richtung zeigt zur Basis")
			_ankunft()
			pruefe(spiel.leben == leben - 2 and ego.einbrueche == 2 and ego._einbruch_zahl == 2, "zweiter Einbruch zählt hoch (×2)")
			schritt = 1
			t0 = Time.get_ticks_msec()
		1:
			# ein paar Bilder zeichnen lassen (Fehler im Zeichnen kämen als SCRIPT ERROR); mit Fenster und
			# TD_HQ_BILD=<pfad.png> wird die Anzeige nach 0,4 s fotografiert
			if OS.get_environment("TD_HQ_BILD") != "" and Time.get_ticks_msec() - t0 > 400 and not has_meta("foto"):
				set_meta("foto", true)
				root.get_texture().get_image().save_png(OS.get_environment("TD_HQ_BILD"))
			if Time.get_ticks_msec() - t0 > int(EgoModus.EINBRUCH_SEK * 1000.0) + 200:
				pruefe(ego._einbruch_rest() == 0.0, "nach %.1f s ist die Anzeige aus" % EgoModus.EINBRUCH_SEK)
				_ankunft()
				pruefe(ego._einbruch_zahl == 1, "neuer Einbruch beginnt wieder bei ×1")
				ende()


## Basis mehrfach neu würfeln (wie beim Partiestart: Zufall je Partie) und Spalten sowie Gegnerweg messen.
func _messe_basis(brakk: bool) -> Dictionary:
	spiel.brakk_modus = brakk
	var xs: Array[int] = []
	var weg := 0.0
	for samen in range(1, 41):
		Zufall.gewuenscht = samen
		Zufall.neue_partie()
		spiel.stelle_basis("ueberall")
		xs.append(spiel.karte.basis.x)
		weg += float(spiel.karte.pfad.size())
	spiel.brakk_modus = true
	return {"min": xs.min(), "max": xs.max(), "weg": weg / xs.size(), "xs": xs}


func _basis() -> void:
	var ab := ceili(Werte.SPALTEN * Werte.BRAKK_BASIS_AB_ANTEIL) + 1   # Mitte der 3 Felder breiten Basis
	var alt := _messe_basis(false)
	var neu := _messe_basis(true)
	print("Karte %s, %d Spalten. Alte Regel: Mitte %d–%d, Gegnerweg im Schnitt %.1f Felder" % [Werte.karte_name, Werte.SPALTEN, alt["min"], alt["max"], alt["weg"]])
	print("Brakk-Mode neu:   Mitte %d–%d, Gegnerweg im Schnitt %.1f Felder  %s" % [neu["min"], neu["max"], neu["weg"], str(neu["xs"])])
	pruefe(int(neu["min"]) >= ab, "Brakk-Mode: Basis immer ganz im letzten Drittel (Mitte ab Spalte %d)" % ab)
	pruefe(int(neu["max"]) > int(neu["min"]), "Brakk-Mode: der Platz bleibt zufällig")
	pruefe(int(alt["min"]) < ab, "ohne Brakk-Mode gilt weiter die rechte Hälfte (Mitte auch vor Spalte %d)" % ab)
	ende()

