extends SceneTree
## H/I/J (27.11., Paul): Fenstertest der Bossarena – Sichtprüfung mit Bildern (kein headless):
##
##   TD_OFFLINE=1 godot --path . -s werkzeuge/bossfenster_test.gd -- scharf|gunner|plasma <Bildordner>
##
## Rechter Bildschirm, 30 fps, ohne Fokus, Maus bleibt frei. Brakk Stufe 8 mit Standardringen, Klon erzwungen. Der Test
## richtet Brakks Blick auf den Boss, löst die neuen Angriffe nacheinander aus und speichert Bilder; danach läuft das Duell
## frei weiter (Bilder alle 6 s). Brakk hält durch (Leben aufgefüllt).

const ARTEN := {"scharf": "scharfschuetze", "gunner": "technogunner", "plasma": "plasmawerfer"}

var spiel: Node
var o: Order24
var h: NemesisHerausforderer
var art := "scharf"
var ordner := "user://fenster"
var warte := 10
var duell_t := -1.0
var plan: Array = []          # je [Sekunde nach Duellbeginn, Callable]
var _i := 0
var _frei_bild := 0.0
var _bilder := 0
var _auf_klon := false


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() >= 1:
		art = str(args[0])
	if args.size() >= 2:
		ordner = str(args[1])
	DirAccess.make_dir_recursive_absolute(ordner)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	DisplayServer.window_set_position(Vector2i(1920 + 100, 100))
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
	Engine.max_fps = 30
	OS.set_environment("TD_KARTE_NAME", Werte.ORDER24_KARTE_NAME)
	Werte.lade_karte(Werte.ORDER24_KARTE_NAME)
	BrakkBossarena.laeuft = true
	BrakkBossarena.wahl = {"boss": str(ARTEN[art]), "stufe": 8, "ringe": "standard", "frei": [["laser", 1], ["markierung", 1], ["feuerteam", 1]],
		"ladungen": 1, "phase2": false, "klon": true}
	var main_skript: GDScript = load("res://scripts/main.gd")
	main_skript.set("naechster_start", "normal")
	spiel = load("res://main.tscn").instantiate()
	root.add_child(spiel)


func _bild(name: String) -> void:
	var img := root.get_texture().get_image()
	img.save_png("%s/%s_%02d_%s.png" % [ordner, art, _bilder, name])
	_bilder += 1
	print("BILD %s %s" % [art, name])


func _process(_delta: float) -> bool:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE   # Paul arbeitet nebenbei – die Maus bleibt frei
	if paused:
		var hud: Variant = spiel.get("_hud") if spiel != null else null
		if hud != null:
			hud.pause_aus()
			if hud.wiedereinstieg_offen():
				hud._wieder.visible = false
		paused = false
	if warte > 0:
		warte -= 1
		return false
	o = spiel.order24
	if o == null:
		return false
	h = o.herausforderer
	var k: Kommandant = spiel.kommandant
	if k != null:
		k.leben = k.max_leben
	if duell_t < 0.0:
		if h.zustand == "duell" and h.einzug.is_empty() and h.kampfplatz.zu():
			duell_t = o.zeit
			h._vergeltung_in = 25.0
			plan = _plan()
			print("FENSTER Duell mit %s" % art)
		elif o.zeit > 60.0:
			print("FENSTER kein Duell")
			quit(1)
		return false
	_blick()
	var t := o.zeit - duell_t
	while _i < plan.size() and t >= float(plan[_i][0]):
		(plan[_i][1] as Callable).call()
		_i += 1
	if _i >= plan.size():
		_frei_bild += _delta
		if _frei_bild >= 6.0:
			_frei_bild = 0.0
			_bild("frei_%d" % int(t))
		if t >= 75.0 or h.zustand != "duell":
			print("FENSTER fertig %s: %d Bilder, Zählung %s" % [art, _bilder, str(h.zaehlung)])
			quit(0)
	return false


## Brakk schaut zum Boss.
func _blick() -> void:
	var ego: EgoModus = spiel.ego
	if ego == null or h.einheit == null or not is_instance_valid(h.einheit):
		return
	var ziel := h.einheit.position
	if _auf_klon and h.klon != null and h.klon.laeuft():
		ziel = h.klon.e.position   # Blick auf den Klon
	var d := ziel - ego._fuss2d()
	if d.length() > 1.0:
		ego.gier = atan2(-d.x, -d.y)
		ego.nick = -0.12


func _stelle(boss: Vector2i, brakk: Vector2i) -> void:
	var kp := h.kampfplatz
	h.angriff = {}
	h._aktion = {}
	h._weg.clear()
	h.einheit.position = o.karte.mitte(kp.mitte + boss)
	h.einheit.zustand = Einheit.Zustand.BODEN
	var k: Kommandant = spiel.kommandant
	k.oben = false
	spiel.ego._setze_fuss(o.karte.mitte(kp.mitte + brakk))
	spiel.ego.hoehe = 0.0


func _angriff(a: String) -> void:
	h.angriff = {}
	h._bis_angriff = 999.0
	h.beginne_angriff(a)


func _frei() -> void:
	h._bis_angriff = 0.5   # ab hier frei


func _plan() -> Array:
	match art:
		"scharf":
			return [
				[1.0, _stelle.bind(Vector2i(-6, 0), Vector2i(2, 0))], [1.1, _angriff.bind("reihe")], [1.7, _bild.bind("reihe_ansage")],
				[2.6, _bild.bind("reihe_rot")], [3.6, _bild.bind("reihe_explosion")],
				[8.0, _stelle.bind(Vector2i(-6, -2), Vector2i(2, 1))], [8.1, _angriff.bind("salve")], [8.3, _bild.bind("salve_linien")], [8.9, _bild.bind("salve_flug")],
				[12.0, _stelle.bind(Vector2i(-5, 0), Vector2i(2, 0))], [12.1, _angriff.bind("laser")], [12.6, _bild.bind("laser_ring_zielen")],
				[13.4, _bild.bind("laser_anvisiert")], [14.3, _bild.bind("laser_strahl")],
				[18.0, _frei],
				[25.0, _klon_an], [25.6, _bild.bind("klon")], [28.0, _bild.bind("klon_2")], [29.0, _klon_aus],
			]
		"gunner":
			return [
				[1.0, _stelle.bind(Vector2i(-6, 0), Vector2i(6, 0))], [1.1, _angriff.bind("anker")], [1.5, _bild.bind("anker_ansage")],
				[1.85, _bild.bind("anker_flug")], [2.3, _bild.bind("anker_zug")],
				[7.0, _stelle.bind(Vector2i(-6, 0), Vector2i(0, 0))], [7.1, _angriff.bind("sturmring")], [7.9, _bild.bind("sturm_kreis")],
				[9.0, _bild.bind("sturm_schlag")], [9.6, _bild.bind("ring_1")], [10.6, _bild.bind("ring_2")],
				[14.0, _stelle.bind(Vector2i(-6, 0), Vector2i(-1, 0))], [14.1, _angriff.bind("minigun")], [14.4, _bild.bind("minigun_anlauf")],
				[15.5, _bild.bind("minigun_feuer")],
				[19.0, _stelle.bind(Vector2i(-5, -2), Vector2i(2, 1))], [19.1, _angriff.bind("salve4")], [19.35, _bild.bind("salve4_linie")],
				[23.0, _frei],
				[25.0, _klon_an], [25.6, _bild.bind("klon")], [28.0, _bild.bind("klon_2")], [29.0, _klon_aus],
			]
		"plasma":
			return [
				[1.0, _stelle.bind(Vector2i(-6, 0), Vector2i(2, 0))], [1.1, _angriff.bind("moerser")], [1.35, _bild.bind("moerser_kreise")],
				[2.5, _bild.bind("moerser_einschlag_glut")],
				[6.0, _krone], [6.2, _angriff.bind("wallsprenger")], [6.8, _bild.bind("wallsprenger_ansage")], [8.0, _bild.bind("wallsprenger_stoss")], [8.5, _bild.bind("wallsprenger_gelandet")],
				[11.0, _stelle.bind(Vector2i(-6, 0), Vector2i(-2, 0))], [11.1, _angriff.bind("sturm")], [13.5, _bild.bind("gel")],
				[16.0, _stelle.bind(Vector2i(-6, -1), Vector2i(3, 1))], [16.1, _angriff.bind("abpraller")], [16.3, _bild.bind("abpraller_bahn")],
				[20.0, _frei],
				[25.0, _klon_an], [25.6, _bild.bind("klon")], [28.0, _bild.bind("klon_2")], [29.0, _klon_aus],
			]
	return []


## Plasmawerfer: Brakk auf eine Rand-Krone (links oben).
func _krone() -> void:
	var kp := h.kampfplatz
	var z := kp.mitte + Vector2i(-BrakkKampfplatz._halb().x, -3)
	h.angriff = {}
	h.einheit.position = o.karte.mitte(kp.mitte + Vector2i(-1, -1))
	var k: Kommandant = spiel.kommandant
	k.oben = true
	k.posten_zelle = z
	spiel.ego._setze_fuss(o.karte.mitte(z))
	spiel.ego.hoehe = spiel.hd.H


func _klon_an() -> void:
	_auf_klon = true


func _klon_aus() -> void:
	_auf_klon = false
