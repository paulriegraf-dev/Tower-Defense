extends SceneTree
## 22.11.: Hunde-Sprung (scripts/gegner.gd, _durchkommen / _sprung_weiter) headless prüfen.
##
##   godot --headless --path . --fixed-fps 60 -s werkzeuge/hundetest.gd
##
## Ein Hund wird im Brakk-Mode von einer Bodentruppe aufgehalten und springt. Geprüft werden die Zeitstempel
## (Anlauf 0,3 s, Flug 0,35 s, Erholung 0,25 s; Toleranz 0,05 s), die Höhe im Bogen (Scheitel ~1), Squash and Stretch,
## der Landepunkt auf freiem Feld, das Abheben des Billboards in der Ego-Sicht und der Abbruch im Anlauf, wenn die
## Truppe davor stirbt. Am Ende „TEST HUND OK“ oder die Fehler. Schreibt ins Profil (user://) – vorher sichern.

const TOL := 0.05

var spiel: Node
var ego: EgoModus
var warte := 20
var t0 := 0
var phase := 0
var fehler: Array[String] = []
var hund: Gegner
var opfer: Einheit
var hoechst := 0.0
var hoechst_3d := -1.0
var squash_flug := false
var squash_landung := false
var squash_duck := false
var takt := 0


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


func _ende() -> void:
	print("TEST HUND OK" if fehler.is_empty() else "TEST HUND FEHLER: %s" % ", ".join(fehler))
	quit(0 if fehler.is_empty() else 1)


func _aufstellen() -> bool:
	var k: Karte = spiel.karte
	# freie Gerade von 6 Feldern
	var start := Karte.KEINE
	for y in range(4, Werte.ZEILEN - 4):
		for x in range(Werte.ZONE_SPALTEN + 2, Werte.SPALTEN - 8):
			var ok := true
			for i in 6:
				if not k.ist_frei(Vector2i(x + i, y)):
					ok = false
					break
			if ok:
				start = Vector2i(x, y)
				break
		if start != Karte.KEINE:
			break
	if start == Karte.KEINE:
		return false
	hund = Gegner.new()
	spiel.figuren.add_child(hund)
	hund.start(spiel, k, "hund", 1.0, start, 0)
	spiel.gegner.append(hund)
	hund.trupp = [hund]
	hund.position = k.mitte(start)
	hund._versatz = Vector2.ZERO
	hund._weg = [start, start + Vector2i(1, 0), start + Vector2i(2, 0), start + Vector2i(3, 0), start + Vector2i(4, 0), start + Vector2i(5, 0)]
	hund._index = 1
	opfer = Einheit.new()
	spiel.figuren.add_child(opfer)
	opfer.start(spiel, k, "technogunner", start + Vector2i(1, 0), 0, "")
	opfer.position = hund.position + Vector2(Werte.ZELLE * 0.6, 0)
	opfer._punkte.clear()
	opfer.max_leben = 1.0e6
	opfer.leben = 1.0e6
	opfer.daten["schaden"] = 0.0   # schießt nicht zurück
	spiel.einheiten.append(opfer)
	hund.leben = 1.0e6
	hund.max_leben = 1.0e6
	return true


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
	takt += 1
	match phase:
		0:
			pruefe(_aufstellen(), "Hund und Bodentruppe aufgestellt")
			if hund == null:
				_ende()
				return false
			pruefe(spiel.brakk_modus, "Brakk-Mode")
			spiel.phase = 1   # Kampfphase: nur dann laufen die Gegner
			phase = 1
			takt = 0
		1:
			_beobachte()
			if hund.sprung_log.has("ende") or takt > 60 * 8:
				_auswerten()
				_abbruch_vorbereiten()
				phase = 2
				takt = 0
		2:
			if takt == 1:
				# jetzt dieselbe Lage, aber die Truppe stirbt im Anlauf
				pass
			_beobachte_abbruch()
	return false


func _beobachte() -> void:
	hoechst = maxf(hoechst, hund.sprung_hoch)
	var sc := hund._sprite.scale / hund._sp_basis if hund.springt() else Vector2.ONE
	match hund._sp_phase:
		1:
			squash_duck = squash_duck or (absf(sc.x - 1.08) < 0.01 and absf(sc.y - 0.9) < 0.01)
		2:
			squash_flug = squash_flug or (absf(sc.x - 0.92) < 0.01 and absf(sc.y - 1.10) < 0.01)
		3:
			squash_landung = squash_landung or (absf(sc.x - 1.12) < 0.01 and absf(sc.y - 0.88) < 0.01)
	var b: Sprite3D = spiel.hd._bilder.get(hund._sprite.get_instance_id()) as Sprite3D if spiel.hd != null else null
	if b != null:
		hoechst_3d = maxf(hoechst_3d, b.position.y)


func _auswerten() -> void:
	var l: Dictionary = hund.sprung_log
	pruefe(l.has("flug") and l.has("landung") and l.has("ende"), "Sprung vollständig durchlaufen (%s)" % str(l))
	if not (l.has("flug") and l.has("landung") and l.has("ende")):
		_ende()
		return
	var anlauf := float(l["flug"]) - float(l["anlauf"])
	var flug := float(l["landung"]) - float(l["flug"])
	var erholung := float(l["ende"]) - float(l["landung"])
	pruefe(absf(anlauf - Werte.BRAKK_SPRUNG_ANLAUF) <= TOL, "Anlauf %.3f s (Soll %.2f)" % [anlauf, Werte.BRAKK_SPRUNG_ANLAUF])
	pruefe(absf(flug - Werte.BRAKK_SPRUNG_FLUG) <= TOL, "Flug %.3f s (Soll %.2f)" % [flug, Werte.BRAKK_SPRUNG_FLUG])
	pruefe(absf(erholung - Werte.BRAKK_SPRUNG_ERHOLUNG) <= TOL, "Erholung %.3f s (Soll %.2f)" % [erholung, Werte.BRAKK_SPRUNG_ERHOLUNG])
	var lp: Vector2 = l["landepunkt"]
	pruefe(spiel.karte.ist_frei(spiel.karte.zelle_bei(lp)), "Landepunkt auf freiem Feld (%s)" % str(spiel.karte.zelle_bei(lp)))
	pruefe(lp.x > opfer.position.x, "Landung hinter der Truppe (in Sprungrichtung)")
	pruefe(hoechst >= 0.95 and hoechst <= 1.0001, "Scheitel der Parabel ≈ 1 (%.3f)" % hoechst)
	pruefe(squash_duck, "Ducken im Anlauf (108 % Breite, 90 % Höhe)")
	pruefe(squash_flug, "Streckung im Flug (92 % Breite, 110 % Höhe)")
	pruefe(squash_landung, "Stauchung bei der Landung (112 % Breite, 88 % Höhe)")
	pruefe(hund.sprung_hoch == 0.0 and absf(hund._sprite.position.y - hund._sp_y0) < 0.001 and hund._sprite.scale.is_equal_approx(hund._sp_basis), "nach dem Sprung wieder Grundzustand")
	if hoechst_3d >= 0.0:
		pruefe(hoechst_3d >= Werte.BRAKK_SPRUNG_HOEHE_FELD * 0.9, "Ego-Sicht: Billboard hebt ab (höchster Punkt %.2f Felder)" % hoechst_3d)
	else:
		print("HINWEIS Ego-Billboard des Hundes nicht gefunden – Höhe nicht geprüft")
	var abk := hund._sprung_abkling
	pruefe(abk > 0.0 and abk <= Werte.BRAKK_SPRUNG_ABKLING, "Abklingzeit läuft (%.2f s von %.1f)" % [abk, Werte.BRAKK_SPRUNG_ABKLING])


## Zweite Probe: der Hund beginnt den Anlauf, die Truppe stirbt davor → der Sprung fällt aus.
func _abbruch_vorbereiten() -> void:
	hund._sprung_abkling = 0.0
	hund._sprung_start(opfer, opfer.position + Vector2(Werte.ZELLE * 0.9, 0), Vector2.RIGHT)
	pruefe(hund.springt(), "Anlauf läuft")


func _beobachte_abbruch() -> void:
	if takt == 6:
		opfer.leben = 0.0   # fällt (kurz nach Beginn des Anlaufs)
	if takt == 20:
		pruefe(not hund.springt() and hund.sprung_hoch == 0.0, "Truppe fällt im Anlauf: Sprung bricht ab")
		pruefe(hund._sprite.scale.is_equal_approx(hund._sp_basis), "Figur nach dem Abbruch nicht mehr geduckt")
		_ende()
