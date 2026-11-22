extends SceneTree
## 22.11.: Brakk-Tutorial (scripts/brakk_tutorial.gd) headless prüfen.
##
##   godot --headless --path . --fixed-fps 60 -s werkzeuge/brakktutorialtest.gd
##
## Fünf Partien im Brakk-Mode (mit Brakk) nacheinander:
##   1. Profil-Merker leer → die Frage kommt; „Später“ → Merker bleibt leer
##   2. neue Partie → die Frage kommt wieder; „Nein, danke“ → Merker „abgelehnt“
##   3. neue Partie → keine Frage
##   4. Merker geleert, neue Partie → Frage, „Ja“ → alle Schritte per Code erfüllen (Tasten über die Belegung,
##      Bauen über spiel.baue) bis zum Ende; dabei kein Countdown, Basis und Brakk fallen nicht
##   5. neue Partie → keine Frage mehr (Merker „gespielt“)
## Am Ende „TEST BRAKKTUTORIAL OK“ oder die Fehler. Schreibt ins Profil (user://) – vorher sichern.

const SCHRITT_FRIST := 12000     # ms je Tutorialschritt
const WELLE_FRIST := 240000      # ms für die Probewelle

var spiel: Node
var tut: BrakkTutorial
var ego: EgoModus
var partie := 0
var phase := ""                  # Ablauf innerhalb der Partie
var warte := 0
var t0 := 0
var schritt_alt := -1
var schritt_t0 := 0
var takt := 0
var fehler: Array[String] = []
var erfuellt: Array[String] = []
var uebersprungen: Array[String] = []


func _initialize() -> void:
	BrakkTutorial.erzwingen = true
	BrakkTutorial.ohne_neustart = true
	Profil.setze_einstellung(BrakkTutorial.MERKER, "")
	_neue_partie()


func pruefe(ok: bool, text: String) -> void:
	print("%s %s" % ["OK  " if ok else "FEHL", text])
	if not ok:
		fehler.append(text)


func _neue_partie() -> void:
	if spiel != null:
		spiel.queue_free()
		spiel = null
	partie += 1
	tut = null
	ego = null
	Werte.setze_anfuehrer("brakk")
	var main_skript: GDScript = load("res://scripts/main.gd")
	main_skript.set("naechster_start", "brakk")
	spiel = load("res://main.tscn").instantiate()
	root.add_child(spiel)
	spiel.protokoll_an = false
	phase = "start"
	warte = 20
	t0 = Time.get_ticks_msec()
	print("--- Partie %d" % partie)


func ms() -> int:
	return Time.get_ticks_msec() - t0


func merker() -> String:
	return str(Profil.einstellung(BrakkTutorial.MERKER, ""))


func taste(k: Key, an: bool) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = k
	e.keycode = k
	e.pressed = an
	Input.parse_input_event(e)


func ende() -> void:
	print("Erfüllt: %s" % ", ".join(erfuellt))
	if not uebersprungen.is_empty():
		print("Übersprungen (Frist): %s" % ", ".join(uebersprungen))
	print("TEST BRAKKTUTORIAL OK" if fehler.is_empty() else "TEST BRAKKTUTORIAL FEHLER: %s" % ", ".join(fehler))
	quit(0 if fehler.is_empty() else 1)


func _process(_delta: float) -> bool:
	if warte > 0:
		warte -= 1
		return false
	if ego == null:
		ego = spiel.ego
		if ego == null:
			if ms() > 20000:
				pruefe(false, "Partie %d: keine Ego-Sicht" % partie)
				ende()
			return false
		t0 = Time.get_ticks_msec()
		warte = 10   # BrakkTutorial.anbieten läuft gleich nach dem Einschalten der Ego-Sicht
		return false
	match partie:
		1:
			_partie_frage("spaeter")
		2:
			_partie_frage("abgelehnt")
		3, 5:
			_partie_ohne_frage()
		4:
			_partie_tutorial()
	return false


## Frage muss kommen; dann „Später“ bzw. „Nein, danke“.
func _partie_frage(antwort: String) -> void:
	tut = spiel.tutorial as BrakkTutorial
	pruefe(tut != null and tut._frage, "Partie %d: die Frage kommt (Merker \"%s\")" % [partie, merker()])
	if tut == null:
		ende()
		return
	pruefe(not ego._frei(), "Partie %d: solange die Frage steht, ist die Maus frei" % partie)
	if antwort == "spaeter":
		tut._btn_nein.pressed.emit()
		pruefe(merker() == "" and BrakkTutorial.letzter_ausgang == "spaeter", "„Später“: Merker bleibt leer")
	else:
		tut._btn_ablehnen.pressed.emit()
		pruefe(merker() == "abgelehnt", "„Nein, danke“: Merker \"abgelehnt\"")
	pruefe(spiel.tutorial == null, "nach der Antwort läuft kein Tutorial")
	_neue_partie()


func _partie_ohne_frage() -> void:
	pruefe(spiel.tutorial == null, "Partie %d: keine Frage (Merker \"%s\")" % [partie, merker()])
	if partie == 3:
		Profil.setze_einstellung(BrakkTutorial.MERKER, "")
		_neue_partie()
	else:
		ende()


# ------------------------------------------------------------------ Partie 4: das ganze Tutorial

func _partie_tutorial() -> void:
	if phase == "start":
		tut = spiel.tutorial as BrakkTutorial
		pruefe(tut != null and tut._frage, "Partie 4: die Frage kommt wieder nach dem Leeren des Merkers")
		if tut == null:
			ende()
			return
		taste(KEY_ENTER, true)   # Ja ist der Standard
		taste(KEY_ENTER, false)
		phase = "ja"
		return
	if phase == "ja":
		pruefe(not tut._frage and tut._index == 0, "[Enter] startet das Tutorial")
		pruefe(merker() == "gespielt", "Merker \"gespielt\" nach dem Start")
		pruefe(int(spiel.budget) >= BrakkTutorial.UEBUNG_BUDGET / 2, "Übungsbudget")
		pruefe(tut._wall_a.size() == 3 and tut._wall_b.size() == 3, "Parkour gebaut (Wall A %d, Wall B %d Felder)" % [tut._wall_a.size(), tut._wall_b.size()])
		phase = "einflug"
		return
	if phase == "einflug":
		if ego._einflug >= 0.0 or ego._briefing_offen():
			return
		phase = "schritte"
		schritt_alt = -1
		return
	if not is_instance_valid(tut) or spiel.tutorial == null:
		pruefe(BrakkTutorial.letzter_ausgang == "fertig", "Tutorial bis zum Ende durchlaufen (Ausgang \"%s\")" % BrakkTutorial.letzter_ausgang)
		pruefe(merker() == "gespielt", "Merker nach dem Ende \"gespielt\"")
		_neue_partie()
		return
	# Übungsgelände
	if ego._countdown >= 0.0:
		pruefe(false, "kein Countdown im Übungsgelände")
	if int(spiel.leben) <= 0 or int(spiel.phase) == 2:
		pruefe(false, "Übungsgelände geht nicht verloren (Leben %d, Phase %d)" % [int(spiel.leben), int(spiel.phase)])
		ende()
		return
	if tut._index != schritt_alt:
		if schritt_alt >= 0:
			erfuellt.append(str(schritt_alt + 1))
		schritt_alt = tut._index
		schritt_t0 = Time.get_ticks_msec()
		takt = 0
		_tasten_los()
		print("  Schritt %d: %s" % [tut._index + 1, str(tut._schritte[tut._index]["text"]).substr(0, 60)])
	var s: Dictionary = tut._schritte[tut._index]
	if not s.has("fertig"):
		tut._weiter()   # reiner Hinweis
		return
	var frist := WELLE_FRIST if bool(s.get("welle", false)) else SCHRITT_FRIST
	if Time.get_ticks_msec() - schritt_t0 > frist:
		pruefe(false, "Schritt %d in der Frist erfüllt" % (tut._index + 1))
		uebersprungen.append(str(tut._index + 1))
		schritt_alt = -2   # nicht als erfüllt zählen
		tut._weiter()
		return
	takt += 1
	_handle(tut._index)


func _tasten_los() -> void:
	for k: Key in [KEY_W, KEY_A, KEY_S, KEY_D]:
		taste(k, false)
	ego._feuer = false


## Blick auf einen Punkt der 3D-Welt (Felder).
func schau(ziel: Vector3) -> void:
	var auge := ego._fuss3d() + Vector3(0, EgoModus.AUGE, 0)
	var d := ziel - auge
	ego.gier = atan2(-d.x, -d.z)
	ego.nick = atan2(d.y, Vector2(d.x, d.z).length())


func mitte3(z: Vector2i, y: float) -> Vector3:
	var p: Vector2 = spiel.karte.mitte(z)
	return Vector3(p.x / Werte.ZELLE, y, (p.y - Werte.KARTE_OBEN) / Werte.ZELLE)


func g3(g: Gegner) -> Vector3:
	return Vector3(g.position.x / Werte.ZELLE, 0.45, (g.position.y - Werte.KARTE_OBEN) / Werte.ZELLE)


func erstes_ziel() -> Gegner:
	for g: Variant in tut._ziele:
		if is_instance_valid(g) and spiel.gegner.has(g):
			return g as Gegner
	return null


## Freies, bebaubares Feld nahe Brakk (Abstand 2–4), nicht im Parkour.
func freies_feld() -> Vector2i:
	var b: Vector2i = tut._brakk_zelle()
	for r in range(2, 5):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				var z := b + Vector2i(dx, dy)
				if maxi(absi(dx), absi(dy)) == r and spiel.bau_hindernis(z, Karte.WALL) == "" and z.x >= Werte.ZONE_SPALTEN:
					return z
	return Karte.KEINE


func _handle(i: int) -> void:
	var brakk: Kommandant = spiel.kommandant
	var text := str(tut._schritte[i]["text"])
	if text.begins_with("Erst die Beine"):
		brakk.position = spiel.karte.mitte(tut._platz)
	elif text.begins_with("Leertaste springt"):
		if takt % 30 == 1:
			ego._aktion("leertaste", true)
	elif text.begins_with("In der Luft"):
		if takt % 40 == 1:
			ego._aktion("leertaste", true)
		elif takt % 40 == 8:
			ego._aktion("leertaste", true)
	elif text.begins_with("Shift"):
		if takt % 30 == 1:
			ego._aktion("shift", true)
	elif text.begins_with("Vor dir steht"):
		if takt == 1:
			brakk.position = spiel.karte.mitte(tut._platz)
		schau(mitte3(tut._wall_a[1], 0.8))
		if takt % 40 == 5:
			ego._aktion("E", true)
	elif text.begins_with("Dahinter liegt"):
		if not brakk.oben:
			return
		schau(mitte3(tut._wall_b[1], spiel.hd.H + EgoModus.AUGE))   # waagrecht nach Westen
		if takt % 60 == 5 and ego._bruecke == null:
			ego._aktion("E", true)
		if ego._bruecke != null and ego._bruecke_aufbau < 0.0:
			taste(KEY_W, true)
	elif text.begins_with("Hinunter"):
		taste(KEY_W, false)
		# vom Wall B nach Westen hinunter (dort ist frei)
		schau(mitte3(tut._wall_b[1] + Vector2i(-2, 0), 0.0))
		if takt % 60 == 5:
			ego._aktion("E", true)
	elif text.begins_with("Q wirft"):
		schau(mitte3(tut._wall_a[1], spiel.hd.H))
		if takt % 40 == 5:
			ego._aktion("Q", true)
	elif text.begins_with("Schießstand") or text.begins_with("Schieß mit"):
		var g := erstes_ziel()
		if g != null:
			schau(ego._ziel_mitte(g))
			ego._feuer = true
		if takt % 120 == 60:
			print("    Schuss: Brakk %s oben=%s, Ziel %s, Treffer %d, Weite frei %.1f, Hitze %s gesperrt %s" % [tut._brakk_zelle(), brakk.oben,
				spiel.karte.zelle_bei(g.position) if g != null else Karte.KEINE, ego.treffer_zahl,
				ego._strahl_bis(spiel.hd.kamera.global_position, ego._blick(), EgoModus.SCHUSS_WEITE), ego._hitze, ego._gesperrt])
	elif text.begins_with("Rechtsklick halten"):
		var g := erstes_ziel()
		if g != null:
			schau(ego._ziel_mitte(g))
		if ego._lanze < 0.0 and takt % 20 == 5:
			ego._aktion("rechts", true)   # lädt (Echtzeit)
		elif ego._lanze >= EgoModus.LANZE_LADEN + 0.05:
			ego._aktion("rechts", false)   # voll geladen: loslassen
	elif text.begins_with("X zielt"):
		var g := erstes_ziel()
		if g != null:
			schau(Vector3(g3(g).x, 0.0, g3(g).z))
		if takt % 40 == 5 and not ego._saeule_zielt:
			ego._aktion("X", true)
		elif takt % 40 == 15 and ego._saeule_zielt:
			ego._saeule_bestaetigen()
	elif text.begins_with("V ist"):
		if takt % 40 == 5:
			ego._aktion("V", true)
	elif text.begins_with("R ist"):
		var z := freies_feld()
		if z != Karte.KEINE:
			schau(mitte3(z, 0.0))
		if takt % 40 == 5:
			ego._aktion("R", true)
	elif text.begins_with("Drück 2"):
		if takt % 5 == 1:
			var z := freies_feld()
			if z != Karte.KEINE:
				spiel.baue(z, Karte.WALL)
	elif text.begins_with("Erdwälle lenken"):
		if takt == 1:
			for z: Vector2i in spiel.karte.feld:
				if spiel.karte.feld[z] == Karte.WALL and not spiel.karte.ausbau.has(z) and spiel.bau_hindernis(z, Karte.STELLUNG) == "":
					spiel.baue(z, Karte.STELLUNG)
					break
	elif text.begins_with("Jetzt eine Fabrik"):
		if takt % 10 == 1:
			var z := freies_feld()
			if z != Karte.KEINE and spiel.bau_hindernis(z, Karte.FABRIK) == "":
				spiel.baue(z, Karte.FABRIK)
	elif text.begins_with("Deine Ringe kaufst"):
		if takt == 1:
			if ego._haken >= 0.0:
				ego._haken_los()   # der Anker aus dem Parkour hängt noch – das Seil zöge Brakk zurück
			# nächstes begehbares Feld an der Basis (die Basis ist größer als ein Feld)
			var beste := INF
			for dy in range(-3, 4):
				for dx in range(-3, 4):
					var c: Vector2i = spiel.karte.basis + Vector2i(dx, dy)
					var d: float = spiel.karte.mitte(c).distance_to(spiel.karte.mitte(spiel.karte.basis))
					if spiel.karte.ist_begehbar(c) and not spiel.karte.ist_basis(c) and d < beste:
						beste = d
						brakk.position = spiel.karte.mitte(c)
		elif takt % 30 == 5:
			if ego._haken >= 0.0:
				ego._haken_los()   # der Anker aus dem Parkour hängt sonst noch
			if spiel._fabrikmenue.visible:
				spiel._schliesse_fabrikmenue()
			ego.nick = 1.0   # in den Himmel: kein Gebäude im Blick, [F] öffnet das Terminal
			if takt % 60 == 35:
				print("    Terminal: Brakk %s oben=%s Basis %s am_terminal=%s Gebäude im Blick %s" % [tut._brakk_zelle(), brakk.oben, spiel.karte.basis, ego._am_terminal(), ego.gebaeude_im_blick()])
			taste(KEY_F, true)
			taste(KEY_F, false)
	elif text.begins_with("Links deine Finger"):
		if takt == 2:
			ego._kaufe("laser")
		elif takt == 4:
			ego._kaufe("brandfeld")
	elif text.begins_with("Gut. Schließ"):
		if takt == 2:
			taste(KEY_F, true)
			taste(KEY_F, false)
	elif text.begins_with("Alle getragenen"):
		if takt == 2:
			ego._ring_waehlen(1)
	elif text.begins_with("Taste C"):
		var fz: Vector2i = tut._neueste_fabrik()
		if takt == 1 and fz != Karte.KEINE:
			brakk.position = spiel.karte.mitte(fz + Vector2i(2, 0)) if spiel.karte.ist_begehbar(fz + Vector2i(2, 0)) else brakk.position
		if fz != Karte.KEINE:
			schau(mitte3(fz, 0.0))
		if takt % 30 == 5 and not ego._feld_zielt:
			ego._aktion("C", true)
		elif takt % 30 == 15 and ego._feld_zielt:
			ego._feld_bestaetigen()
	elif text.begins_with("Zeit für eine Probewelle"):
		if takt == 2:
			taste(KEY_ENTER, true)
			taste(KEY_ENTER, false)
		elif takt == 30 and spiel.phase == 0:
			pruefe(false, "[Enter] startet die Probewelle")
			spiel.starte_welle()
