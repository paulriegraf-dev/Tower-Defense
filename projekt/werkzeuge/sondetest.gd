extends SceneTree
## 21.11.: Sonde 7 im Brakk-Mode headless prüfen – Schweben über Mauern und Schrotflinte auf kurze Distanz.
##
##   godot --headless --path . --fixed-fps 60 -s werkzeuge/sondetest.gd -- schweben
##   godot --headless --path . --fixed-fps 60 -s werkzeuge/sondetest.gd -- schrot
##
## schweben: Mauerreihe quer vor Sonde 7; Leertaste und W halten → muss auf der Krone landen, dann ohne Leertaste
## von der Krone auf der anderen Seite absteigen; zuletzt wie lange der volle Akku trägt.
## schrot: Gegner 0,3 Felder vor ihr – Einzelschüsse, dann Magazin-Dump (Rechtsklick) mit Rückstoß.
## Am Ende „TEST SONDE OK“ oder die Fehler. Schreibt wie das Spiel in user:// – vorher sichern.

var spiel: Node
var ego: EgoModus
var kit: EgoSonde
var karte: Karte
var art := "schweben"
var warte := 10
var schritt := 0
var t0 := 0                     # ms seit Schrittbeginn
var fehler: Array[String] = []
var start_zelle := Vector2i.ZERO
var wand := Vector2i.ZERO
var g: Gegner = null
var akku_t0 := 0


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0:
		art = a[0]
	Werte.anfuehrer = "sonde7"
	var main_skript: GDScript = load("res://scripts/main.gd")
	main_skript.set("naechster_start", "brakk")
	spiel = load("res://main.tscn").instantiate()
	root.add_child(spiel)
	spiel.protokoll_an = false


func pruefe(ok: bool, text: String) -> void:
	print("%s %s" % ["OK  " if ok else "FEHL", text])
	if not ok:
		fehler.append(text)


func taste(k: Key, an: bool) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = k
	e.keycode = k
	e.pressed = an
	Input.parse_input_event(e)


## Headless gibt es keinen Mausfang (die Ego-Sicht nimmt Klicks nur mit gefangener Maus) – direkt die Belegung.
func maus(rechts: bool, an: bool) -> void:
	ego._aktion("rechts" if rechts else "links", an)


func ms() -> int:
	return Time.get_ticks_msec() - t0


func weiter() -> void:
	schritt += 1
	t0 = Time.get_ticks_msec()


func ende() -> void:
	print("TEST SONDE OK" if fehler.is_empty() else "TEST SONDE FEHLER: %s" % ", ".join(fehler))
	quit(0 if fehler.is_empty() else 1)


func _process(_delta: float) -> bool:
	if warte > 0:
		warte -= 1
		return false
	if ego == null:
		ego = spiel.ego
		if ego == null or not (ego.kit is EgoSonde):
			ego = null
			return false
		kit = ego.kit
		karte = spiel.karte
		if ego._briefing != null:
			ego._briefing.visible = false
		ego.brakk.fortschritt.stufe = 10   # alle Waffen frei
		t0 = Time.get_ticks_msec()
		print("Sonde 7 bereit, Mauerhöhe H=%.2f, Schwebehöhe %.2f" % [ego.hd.H, float(Werte.SONDE7["schweben"]["hoehe"])])
	ego.brakk.leben = ego.brakk.max_leben
	if art == "schweben":
		_schweben()
	else:
		_schrot()
	return false


## Freie Reihe: vier freie Felder nebeneinander nach rechts; das dritte wird Mauer.
func _bahn() -> bool:
	for y in range(2, Werte.ZEILEN - 2):
		for x in range(Werte.ZONE_SPALTEN + 1, Werte.SPALTEN - 6):
			var ok := true
			for dx in 6:
				for dy in [-1, 0, 1]:
					var z := Vector2i(x + dx, y + dy)
					if not karte.ist_frei(z) or karte.ist_basis(z) or karte.checkpoints.has(z):
						ok = false
			if ok:
				start_zelle = Vector2i(x, y)
				wand = Vector2i(x + 2, y)
				return true
	return false


func _stelle(z: Vector2i) -> void:
	ego.brakk.oben = false
	ego.brakk.posten_zelle = Karte.KEINE
	ego.hoehe = 0.0
	ego.steig = 0.0
	ego._setze_fuss(karte.mitte(z))
	ego.gier = -PI / 2.0   # Blick nach rechts (+x)
	ego.nick = 0.0


func _schweben() -> void:
	match schritt:
		0:
			if not _bahn():
				pruefe(false, "keine freie Reihe für die Mauer")
				ende()
				return
			karte.setze(wand, Karte.WALL)
			karte.aktualisiere_pfad()
			_stelle(start_zelle)
			kit.akku = float(Werte.SONDE7["schweben"]["akku"])
			print("Start %s, Mauer %s" % [start_zelle, wand])
			taste(KEY_SPACE, true)
			taste(KEY_W, true)
			weiter()
		1:
			# hinauf: muss auf der Mauerkrone landen
			if ego.brakk.oben:
				pruefe(karte.zelle_bei(ego._fuss2d()) == wand, "landet auf der Mauerkrone (nach %d ms, Höhe %.2f)" % [ms(), ego.hoehe])
				taste(KEY_W, false)
				taste(KEY_SPACE, false)
				weiter()
			elif ms() > 6000:
				pruefe(false, "kommt nicht auf die Mauer: Höhe %.2f, Fuß %s (Mauer %s), oben=%s" % [ego.hoehe, karte.zelle_bei(ego._fuss2d()), wand, ego.brakk.oben])
				taste(KEY_W, false)
				taste(KEY_SPACE, false)
				ende()
		2:
			# Leertaste los: sinkt auf die Krone
			if ms() > 2500:
				pruefe(ego.brakk.oben and absf(ego.hoehe - ego.hd.H) < 0.01, "steht auf der Krone (Höhe %.2f = H %.2f, oben=%s)" % [ego.hoehe, ego.hd.H, ego.brakk.oben])
				taste(KEY_W, true)
				weiter()
		3:
			# ohne Leertaste weiter nach rechts: von der Krone absteigen
			var z := karte.zelle_bei(ego._fuss2d())
			if not ego.brakk.oben and z.x > wand.x and ego.hoehe <= 0.001:
				pruefe(true, "von der Krone abgestiegen, unten auf %s (nach %d ms)" % [z, ms()])
				taste(KEY_W, false)
				weiter()
			elif ms() > 6000:
				pruefe(false, "kommt nicht von der Krone: Fuß %s, Höhe %.2f, oben=%s" % [z, ego.hoehe, ego.brakk.oben])
				taste(KEY_W, false)
				weiter()
		4:
			# zurück über die Mauer nach links (Blick drehen), wieder mit Leertaste – über die Mauer hinweg
			ego.gier = PI / 2.0
			kit.akku = float(Werte.SONDE7["schweben"]["akku"])
			taste(KEY_SPACE, true)
			taste(KEY_W, true)
			weiter()
		5:
			var z := karte.zelle_bei(ego._fuss2d())
			if z.x < wand.x and not ego.brakk.oben:
				pruefe(true, "über die Mauer zurück nach %s (nach %d ms)" % [z, ms()])
				taste(KEY_W, false)
				taste(KEY_SPACE, false)
				weiter()
			elif ms() > 8000:
				pruefe(false, "nicht über die Mauer zurück: Fuß %s, Höhe %.2f, oben=%s" % [z, ego.hoehe, ego.brakk.oben])
				taste(KEY_W, false)
				taste(KEY_SPACE, false)
				weiter()
		6:
			# auf den Boden, dann Akku-Dauer messen
			if ego.hoehe <= 0.001 and ms() > 500:
				_stelle(start_zelle)
				kit.akku = float(Werte.SONDE7["schweben"]["akku"])
				taste(KEY_SPACE, true)
				akku_t0 = Time.get_ticks_msec()
				weiter()
			elif ms() > 6000:
				pruefe(false, "kommt nicht zum Boden: Höhe %.2f" % ego.hoehe)
				ende()
		7:
			if kit.akku <= 0.0:
				var sek := (Time.get_ticks_msec() - akku_t0) / 1000.0
				pruefe(absf(sek - float(Werte.SONDE7["schweben"]["akku"])) < 0.6, "voller Akku trägt %.1f s Schweben (Höhe dabei %.2f)" % [sek, ego.hoehe])
				taste(KEY_SPACE, false)
				ende()
			elif ms() > 9000:
				pruefe(false, "Akku leert sich nicht (%.2f)" % kit.akku)
				taste(KEY_SPACE, false)
				ende()


func _gegner_vor(abstand_felder: float, typ: String = "hund") -> Gegner:
	var n := Gegner.new()
	spiel.figuren.add_child(n)
	n.start(spiel, karte, typ, 1.0, start_zelle, karte.erstes_ziel())
	spiel.gegner.append(n)
	n.position = ego._fuss2d() + Vector2(abstand_felder * Werte.ZELLE, 0.0)
	n.set_process(false)   # steht still vor ihr
	return n


func _schrot() -> void:
	match schritt:
		0:
			if not _bahn():
				pruefe(false, "keine freie Reihe")
				ende()
				return
			spiel.starte_welle(true)   # wie im Spiel: Welle läuft (Zerfall des Schwarmgeists braucht die Wellendaten)
			_stelle(start_zelle)
			ego.nick = -0.3
			g = _gegner_vor(0.3)
			kit._rufe("schrot")
			pruefe(kit.waffe == "schrot", "Schrotflinte gerufen (Magazin %d)" % kit.magazin)
			maus(false, true)
			weiter()
		1:
			# Einzelschüsse links, bis das Magazin halb leer ist
			if kit.magazin <= 4 or kit.waffe != "schrot" or ms() > 6000:
				maus(false, false)
				pruefe(true, "Einzelschüsse aus 0,3 Feldern ohne Absturz (Gegner %s)" % ("tot" if not is_instance_valid(g) or g._tot else "lebt, %d Leben" % roundi(g.leben)))
				weiter()
		2:
			if ms() > 300:
				if kit.waffe != "schrot":
					kit.cd.clear()
					kit._nachladen = 0.0
					kit._rufe("schrot")
				g = _gegner_vor(0.3, "schwarm")
				maus(true, true)   # Magazin-Dump mit Rückstoß
				weiter()
		3:
			if ms() > 100:
				maus(true, false)
			if ms() > 2500:
				pruefe(kit.waffe == "", "Magazin-Dump aus 0,3 Feldern ohne Absturz (Höhe jetzt %.2f, oben=%s)" % [ego.hoehe, ego.brakk.oben])
				weiter()
		4:
			# Dump direkt auf den Gegner im selben Punkt (Abstand 0)
			kit.cd.clear()
			kit._nachladen = 0.0
			_stelle(start_zelle)
			kit._rufe("schrot")
			g = _gegner_vor(0.0)
			ego.nick = -1.4   # senkrecht nach unten
			kit._rechts_druck()
			kit._rufe("schrot")
			kit.cd.clear()
			kit._rufe("schrot")
			kit._schrot(8)
			pruefe(true, "Abstand 0 und Blick senkrecht nach unten ohne Absturz")
			weiter()
		5:
			# 25 s echte Welle: immer zum vordersten Gegner, aus 0,3 Feldern Einzelschüsse und Dumps im Wechsel
			if ms() > 25000:
				pruefe(ego.treffer_zahl > 0, "25 s Welle aus 0,3 Feldern: %d Treffer, %d Dumps, Welle %d" % [ego.treffer_zahl, int(kit.f().zaehler.get("schrot_alles", 0)), spiel.welle])
				ende()
				return
			var ziel: Gegner = null
			for e: Gegner in spiel.gegner:
				if is_instance_valid(e) and not e._tot and karte.ist_begehbar(karte.zelle_bei(e.position)):
					ziel = e
					break
			if ziel == null:
				return
			ego.brakk.oben = false
			ego._setze_fuss(ziel.position - Vector2(0.3 * Werte.ZELLE, 0.0))
			ego.gier = -PI / 2.0
			ego.nick = -0.4
			kit.cd.clear()
			kit._nachladen = 0.0
			if kit.waffe != "schrot":
				kit._rufe("schrot")
			if Engine.get_process_frames() % 20 == 0:
				maus(true, true)
				maus(true, false)
			else:
				maus(false, true)
