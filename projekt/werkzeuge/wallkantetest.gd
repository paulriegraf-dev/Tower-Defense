extends SceneTree
## 22.11.: Brakk-Mode headless – zu Fuß hält die Wallkante; herunter nur mit Sprung (Leertaste), [E] oder [Q].
##
##   godot --headless --path . --fixed-fps 60 -s werkzeuge/wallkantetest.gd
##
## Reihe nach rechts (+x): Wall A auf x+1 und x+2, Lücke x+3, Wall B auf x+4 und x+5, dahinter frei.
## 1) Brakk auf A, W halten → bleibt oben (an der Kante von A).
## 2) Leertaste + W → landet auf Wall B (W los, sobald Brakk über B ist – sonst trägt ihn der Sprung weiter).
## 3) [E] auf B → Lichttreppe hinunter, unten angekommen.
## 4) wieder auf B, Leertaste + W → unten angekommen.
## Am Ende „TEST WALLKANTE OK“ oder die Fehler. Schreibt wie das Spiel in user:// – vorher sichern.

var spiel: Node
var ego: EgoModus
var karte: Karte
var warte := 10
var schritt := 0
var t0 := 0                     # ms seit Schrittbeginn (die Ego-Sicht rechnet in Echtzeit)
var bilder := 0                 # Bilder seit Schrittbeginn
var fehler: Array[String] = []
var x0 := 0
var y0 := 0


func _initialize() -> void:
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


func taste(k: Key, an: bool) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = k
	e.keycode = k
	e.pressed = an
	Input.parse_input_event(e)


func weiter() -> void:
	schritt += 1
	bilder = 0
	t0 = Time.get_ticks_msec()


func ende() -> void:
	taste(KEY_W, false)
	print("TEST WALLKANTE OK" if fehler.is_empty() else "TEST WALLKANTE FEHLER: %s" % ", ".join(fehler))
	quit(0 if fehler.is_empty() else 1)


func zelle() -> Vector2i:
	return karte.zelle_bei(ego._fuss2d())


func lage() -> String:
	return "Fuß %s, Höhe %.2f, oben=%s" % [zelle(), ego.hoehe, ego.brakk.oben]


func _process(_delta: float) -> bool:
	if warte > 0:
		warte -= 1
		return false
	if ego == null:
		ego = spiel.ego
		if ego == null:
			return false
		karte = spiel.karte
		if ego._briefing != null:
			ego._briefing.visible = false
		ego.brakk.fortschritt.stufe = 10
		print("Brakk bereit, Mauerhöhe H=%.2f" % ego.hd.H)
	ego.brakk.leben = ego.brakk.max_leben
	bilder += 1
	_ablauf()
	return false


## Acht freie Felder nebeneinander nach rechts (mit den Reihen darüber und darunter).
func _bahn() -> bool:
	for y in range(2, Werte.ZEILEN - 2):
		for x in range(Werte.ZONE_SPALTEN + 1, Werte.SPALTEN - 9):
			var ok := true
			for dx in 8:
				for dy: int in [-1, 0, 1]:
					var z := Vector2i(x + dx, y + dy)
					if not karte.ist_frei(z) or karte.ist_basis(z) or karte.checkpoints.has(z):
						ok = false
			if ok:
				x0 = x
				y0 = y
				return true
	return false


func _auf_wall(x: int) -> void:
	var z := Vector2i(x, y0)
	ego.brakk.oben = true
	ego.brakk.posten_zelle = z
	ego.brakk.zustand = Einheit.Zustand.AUF_POSTEN
	ego.hoehe = ego.hd.H
	ego.steig = 0.0
	ego._setze_fuss(karte.mitte(z))
	ego.gier = -PI / 2.0   # Blick nach rechts (+x)
	ego.nick = 0.0


func _ablauf() -> void:
	match schritt:
		0:
			if not _bahn():
				pruefe(false, "keine freie Reihe")
				ende()
				return
			for x: int in [x0 + 1, x0 + 2, x0 + 4, x0 + 5]:
				karte.setze(Vector2i(x, y0), Karte.WALL)
			karte.aktualisiere_pfad()
			_auf_wall(x0 + 1)
			print("Wall A %d..%d, Wall B %d..%d, Zeile %d" % [x0 + 1, x0 + 2, x0 + 4, x0 + 5, y0])
			taste(KEY_W, true)
			weiter()
		1:
			# 1) W halten: bleibt oben
			if not ego.brakk.oben or ego.hoehe < ego.hd.H - 0.01:
				pruefe(false, "läuft vom Wall herunter: %s" % lage())
				ende()
			elif ms() >= 1500:
				pruefe(zelle().x == x0 + 2, "W 1,5 s: bleibt oben an der Kante von Wall A (%s)" % lage())
				ego._aktion("leertaste", true)
				ego._aktion("leertaste", false)
				weiter()
		2:
			# 2) Sprung mit W: hinüber auf Wall B
			if ego.brakk.oben and zelle().x >= x0 + 4:
				taste(KEY_W, false)
			if ego.brakk.oben and ego.hoehe <= ego.hd.H + 0.001 and ego.steig <= 0.0 and zelle().x >= x0 + 4:
				pruefe(true, "Leertaste + W: auf Wall B gelandet nach %d ms (%s)" % [ms(), lage()])
				taste(KEY_W, false)
				weiter()
			elif ms() >= 3000 or (not ego.brakk.oben and ego.hoehe <= 0.001):
				pruefe(false, "Sprung erreicht Wall B nicht: %s" % lage())
				ende()
		3:
			# 3) [E] auf B: Lichttreppe hinunter
			if bilder == 10:
				ego.brakk.e_rest = 0.0
				ego._aktion("E", true)
				ego._aktion("E", false)
			elif bilder > 10:
				if not ego.brakk.oben and ego.hoehe <= 0.001 and ego._klettern < 0.0:
					pruefe(not ego.hd.ist_hoch(zelle()), "[E] auf Wall B: Lichttreppe hinunter, unten auf %s" % zelle())
					weiter()
				elif ms() >= 5000:
					pruefe(false, "[E] steigt nicht ab: %s, klettern=%.2f" % [lage(), ego._klettern])
					ende()
		4:
			# 4) wieder auf B, Sprung mit W: hinunter
			if bilder == 30:
				_auf_wall(x0 + 5)
				taste(KEY_W, true)
				ego._aktion("leertaste", true)
				ego._aktion("leertaste", false)
			elif bilder > 30:
				if not ego.brakk.oben and ego.hoehe <= 0.001:
					pruefe(zelle().x > x0 + 5, "Leertaste + W von Wall B: unten angekommen auf %s" % zelle())
					ende()
				elif ms() >= 4000:
					pruefe(false, "Sprung von Wall B kommt nicht hinunter: %s" % lage())
					ende()


func ms() -> int:
	return Time.get_ticks_msec() - t0
