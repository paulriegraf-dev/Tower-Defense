extends SceneTree
## Das Tutorial des Normalmodus einmal ganz durchspielen (22.11.; 25.11. N4: echte Handgriffe statt „Weiter“).
##
##   godot --headless --path . --fixed-fps 60 -s werkzeuge/tutorialtest.gd             (headless)
##   godot --path . -s werkzeuge/tutorialtest.gd -- <Bildordner>                       (im Fenster, mit Bildern)
##
## Jeder Schritt wird so erledigt, wie ein Spieler es täte (Fabrik setzen, Welle starten und abwarten, Erdwälle,
## Turm, Stufe 1 …); Erklärungen gehen über „Weiter“. Geprüft:
##   - „Weiter“ nur bei Erklärungen, nie bei Aktionen und beim Warten auf das Wellenende
##   - Budget-Schritte stellen genau den Preis der Übung hin, und der Handgriff klappt damit
##   - gesperrt: fremde Werkzeuge (Kachel grau, Text „Später im Tutorial.“), Aufwerten, die Welle außerhalb ihres Schritts
##   - absichtlich falsch: vor der ersten Welle die zweite Fabrik abreißen, nach dem Ausbau die ausgebaute Fabrik
##     abreißen → Rücksprung mit kurzem Satz, danach geht es beim selben Schritt weiter
##   - der Übersicht-Schritt (22.11., Prompts-Fixes Punkt 4): öffnen (Spiel steht), Esc – dann die nächste Aufgabe
##   - kein Schritt hängt; am Ende ist das Tutorial weg, das Budget mindestens das Startbudget, die Welle frei
## Am Ende „TEST TUTORIAL OK“ oder die Fehler. Schreibt ins Profil (user://) – eigenen Benutzerordner nehmen.

const GRENZE_AKTION := 900          # Bilder, die ein Handgriff höchstens braucht
const GRENZE_WARTEN := 30000        # Bilder bis zum Ende einer Welle

var spiel: Node
var tut: Tutorial
var warte := 20
var fehler: Array[String] = []
var gestartet := false
var index := -2
var besuch := 0
var bilder := 0                     # seit dem Betreten des Schritts
var erledigt := false               # Handgriff dieses Besuchs schon ausgeführt
var falsch := {}                    # einmalige Fehlklicks
var phase_lx := ""
var uhr := 0
var turmfeld := Karte.KEINE
var rueck_gesehen: Array[String] = []
var bild_spaeter: Array = []        # [Name, Bilder bis zur Aufnahme] – erst wenn Text und Hinweis nachgezogen sind


func _initialize() -> void:
	var main_skript: GDScript = load("res://scripts/main.gd")
	main_skript.set("ohne_spuren", true)
	main_skript.set("naechster_start", "tutorial")
	spiel = load("res://main.tscn").instantiate()
	root.add_child(spiel)


func pruefe(ok: bool, text: String) -> void:
	print("%s %s" % ["OK  " if ok else "FEHL", text])
	if not ok:
		fehler.append(text)


func _id() -> String:
	return str((tut._schritte[tut._index] as Dictionary).get("id", "?"))


func _schritt() -> Dictionary:
	return tut._schritte[tut._index]


func _process(_delta: float) -> bool:
	if warte > 0:
		warte -= 1
		return false
	if not gestartet:
		gestartet = true
		spiel.protokoll_an = false
		tut = spiel.get("tutorial")
		if tut == null:
			pruefe(false, "Tutorial startet")
			return _ende()
		print("     Tutorial: %d Schritte" % tut._schritte.size())
		return false
	if phase_lx != "" and is_instance_valid(tut) and _uebersicht_weiter():
		return false
	if not is_instance_valid(tut) or tut._aus:
		return _schluss()
	if spiel.phase == 1:
		Engine.time_scale = Werte.SPIELTEMPO * 3.0   # Wellen schneller abspielen
	if tut._index != index or (tut._zurueck >= 0 and not erledigt and bilder == 0):
		_neuer_besuch()
	bilder += 1
	if not bild_spaeter.is_empty():
		tut._gezeigt = INF   # Text ganz zeigen
		bild_spaeter[1] = int(bild_spaeter[1]) - 1
		if int(bild_spaeter[1]) <= 0:
			_bild(str(bild_spaeter[0]))
			bild_spaeter = []
		return false
	var s := _schritt()
	var grenze := GRENZE_WARTEN if (s.has("fertig") and not s.has("werkzeuge") and not s.has("budget") and _id() in ["tempo", "sicht"]) else GRENZE_AKTION
	if bilder > grenze:
		pruefe(false, "Schritt „%s“ hängt (%d Bilder)" % [_id(), bilder])
		return _ende()
	if bilder < 4 or erledigt:
		return false
	erledigt = true
	_handgriff()
	return false


func _neuer_besuch() -> void:
	var zurueck := index >= 0 and tut._index < index
	index = tut._index
	besuch += 1
	bilder = 0
	erledigt = false
	var s := _schritt()
	var erklaerung := not s.has("fertig")
	if tut._btn_weiter.visible != erklaerung:
		pruefe(false, "Schritt „%s“: „Weiter“ %s" % [_id(), "fehlt" if erklaerung else "ist da, obwohl es eine Aufgabe ist"])
	if s.has("budget"):
		var soll := int((s["budget"] as Callable).call())
		if spiel.budget != soll:
			pruefe(false, "Schritt „%s“: Budget %d statt %d" % [_id(), spiel.budget, soll])
	if zurueck:
		var satz := tr(str(s.get("rueck", "")))
		pruefe(s.has("haelt") and str(tut._text.text).begins_with(satz) and not tut._btn_weiter.visible, "Rücksprung auf „%s“: „%s“" % [_id(), satz])
		rueck_gesehen.append(_id())
		bild_spaeter = ["ruecksprung_" + _id(), 30]


## Was ein Spieler in diesem Schritt tut.
func _handgriff() -> void:
	var k: Karte = spiel.karte
	match _id():
		"prinzip":
			_bild("prinzip")
			spiel.waehle(Karte.FABRIK)
			pruefe(spiel.werkzeug == Karte.FREI, "Erklärung: Fabrik lässt sich nicht wählen")
			pruefe(spiel.bau_hindernis(tut._fabrikplatz(), Karte.FABRIK) == "Später im Tutorial.", "Erklärung: Bauen gesperrt („Später im Tutorial.“)")
			spiel._hud._aktualisiere_kacheln()
			pruefe(spiel._hud.kacheln[Karte.FABRIK].disabled and spiel._hud.start.disabled, "Erklärung: Fabrik-Kachel und Start grau")
			pruefe(spiel._werkzeug_tipp(Karte.FABRIK) == "Später im Tutorial.", "Erklärung: Tipp an der grauen Kachel")
			spiel.starte_welle()
			pruefe(spiel.phase == 0, "Erklärung: Welle startet nicht")
			_weiter()
		"fabrik_waehlen":
			spiel._hud._aktualisiere_kacheln()
			pruefe(not spiel._hud.kacheln[Karte.FABRIK].disabled and spiel._hud.kacheln[Karte.KOMMANDANT].disabled, "Fabrik-Schritt: nur die Fabrik-Kachel frei")
			spiel.waehle(Karte.FABRIK)
		"fabrik_setzen", "fabrik2":
			spiel.waehle(Karte.TURM)
			pruefe(spiel.werkzeug != Karte.TURM, "%s: Turm gesperrt" % _id())
			if spiel.werkzeug != Karte.FABRIK:
				spiel.waehle(Karte.FABRIK)
			tut._merk.erase("fabrik")
			var z: Vector2i = tut._fabrikplatz()
			pruefe(spiel.baue(z, Karte.FABRIK), "%s: Fabrik mit dem hingestellten Budget gebaut" % _id())
		"fabrik_menue":
			spiel._oeffne_fabrikmenue(tut._erste_fabrik())
			pruefe(not spiel.werte_auf(tut._erste_fabrik()), "Fabrikmenü: Aufwerten noch gesperrt")
		"scharf":
			var z: Vector2i = tut._zweite_fabrik()
			if str(spiel.fabriken[tut._erste_fabrik()]["typ"]) != "technogunner" or z == Karte.KEINE:
				z = tut._erste_fabrik()
			spiel.stelle_um(z, "scharfschuetze")
		"welle1":
			if not falsch.has("fabrik_weg"):
				falsch["fabrik_weg"] = true
				spiel._schliesse_fabrikmenue()
				pruefe(spiel.reisse_ab(tut._zweite_fabrik()), "Fehlklick: zweite Fabrik abgerissen")
				return   # das Tutorial springt zurück
			_bild("welle_starten")
			spiel.starte_welle()
		"waelle":
			spiel.waehle(Karte.STELLUNG)
			pruefe(spiel.werkzeug != Karte.STELLUNG, "Erdwall-Schritt: Stellung gesperrt")
			spiel.waehle(Karte.WALL)
			var n := 0
			for z: Vector2i in _felder_um(tut._wegfeld(), 3):
				if n < 3 and spiel.bau_hindernis(z, Karte.WALL) == "" and spiel.baue(z, Karte.WALL, true):
					n += 1
			pruefe(n == 3, "3 Erdwälle gebaut (%d)" % n)
		"stellung":
			spiel.waehle(Karte.STELLUNG)
			pruefe(spiel.baue(tut._blanker_wall(), Karte.STELLUNG), "Stellung gebaut")
		"welle2":
			spiel.starte_welle()
		"turm_waehlen":
			spiel.waehle(Karte.TURM)
		"formen":
			spiel.werkzeug = Karte.FREI   # wie Rechtsklick
		"h_auf", "h_zu":
			spiel._nachschlag.umschalten()
		"turm":
			turmfeld = _t_platz()
			spiel.waehle(Karte.WALL)
			for v: Vector2i in [Vector2i.ZERO, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.DOWN]:
				if k.inhalt(turmfeld + v) != Karte.WALL:
					spiel.baue(turmfeld + v, Karte.WALL, true)
			spiel.waehle(Karte.TURM)
			pruefe(turmfeld != Karte.KEINE and spiel.baue(turmfeld, Karte.TURM), "Turm gebaut (%s)" % spiel._meldung)
		"turm_menue":
			spiel._oeffne_fabrikmenue(turmfeld)
		"stufe1":
			pruefe(spiel.werte_auf(tut._erste_fabrik()), "Stufe 1 mit dem hingestellten Budget gekauft")
		"tor":
			if not falsch.has("ausgebaut_weg"):
				falsch["ausgebaut_weg"] = true
				spiel._schliesse_fabrikmenue()
				for z: Vector2i in spiel.fabriken.keys():
					if int(spiel.fabriken[z].get("stufe", 0)) >= 1:
						pruefe(spiel.reisse_ab(z), "Fehlklick: ausgebaute Fabrik abgerissen")
						return
			_weiter()
		"uebersicht":
			_uebersicht()
		"tempo", "sicht":
			pass   # Warten: die Welle läuft von selbst zu Ende
		_:
			_weiter()


func _weiter() -> void:
	tut._btn_weiter.pressed.emit()


## Übersicht öffnen (das Spiel steht), mit Esc schließen – danach muss die nächste Aufgabe kommen (Bild für Bild in
## _uebersicht_weiter, damit nichts davon nach dem Ende des Tests läuft).
func _uebersicht() -> void:
	(spiel.get("_lexikon") as CanvasItem).visible = true
	phase_lx = "auf"
	uhr = 0


## true = dieser Bild-Schritt gehört der Übersicht.
func _uebersicht_weiter() -> bool:
	var lx: CanvasItem = spiel.get("_lexikon")
	uhr += 1
	if phase_lx == "auf" and uhr > 30:
		pruefe(paused, "Übersicht offen: das Spiel steht")
		pruefe(_id() == "uebersicht", "Übersicht offen: Schritt wartet noch aufs Schließen")
		var esc := InputEventKey.new()
		esc.keycode = KEY_ESCAPE
		esc.pressed = true
		lx._input(esc)
		phase_lx = "zu"
		uhr = 0
	elif phase_lx == "zu" and uhr > 30:
		pruefe(not lx.visible and not paused and _id() != "uebersicht", "Übersicht auf + zu (Esc) – nächste Aufgabe: „%s“" % _id())
		phase_lx = ""
	return true


## Freie Felder ringförmig um `mitte` (für die Erdwälle).
func _felder_um(mitte: Vector2i, r: int) -> Array[Vector2i]:
	var liste: Array[Vector2i] = []
	for d in range(1, r + 1):
		for dy in range(-d, d + 1):
			for dx in range(-d, d + 1):
				if maxi(absi(dx), absi(dy)) == d:
					liste.append(mitte + Vector2i(dx, dy))
	return liste


## Ein Feld für ein T (Mitte, links, rechts, unten), wo alles frei ist – möglichst weit weg vom Gegnerweg.
func _t_platz() -> Vector2i:
	var k: Karte = spiel.karte
	for x in range(Werte.SPALTEN - 3, Werte.ZONE_SPALTEN + 2, -1):
		for y in range(1, Werte.ZEILEN - 2):
			var c := Vector2i(x, y)
			var gut := true
			for v: Vector2i in [Vector2i.ZERO, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.UP]:
				var z := c + v
				if not k.ist_bebaubar(z) or k.checkpoints.has(z) or z == k.basis or k.pfad.has(z):
					gut = false
			if gut:
				return c
	return Karte.KEINE


func _schluss() -> bool:
	pruefe(spiel.get("tutorial") == null, "Ende: Tutorial weg")
	pruefe(bool(Profil.einstellung("tutorial_fertig", false)), "Ende: als durchgespielt gemerkt")
	pruefe(spiel.budget >= Werte.START_BUDGET, "Ende: Budget %d (mindestens Startbudget %d)" % [spiel.budget, Werte.START_BUDGET])
	pruefe(rueck_gesehen.has("fabrik2") and rueck_gesehen.has("stufe1"), "Rücksprünge gesehen: %s" % str(rueck_gesehen))
	spiel.starte_welle()
	pruefe(spiel.phase == 1, "Ende: die nächste Welle startet")
	return _ende()


## Im Fenster mit `-- <Ordner>`: Bild der Ansicht dorthin speichern (headless gibt es kein Bild).
func _bild(name: String) -> void:
	var a := OS.get_cmdline_user_args()
	if a.is_empty() or DisplayServer.get_name() == "headless":
		return
	root.get_texture().get_image().save_png(a[0].path_join("tutorial_%s.png" % name))
	print("     Bild: tutorial_%s.png" % name)


func _ende() -> bool:
	for f: String in fehler:
		print("FEHLER: " + f)
	print("TEST TUTORIAL OK" if fehler.is_empty() else "TEST TUTORIAL FEHLER (%d)" % fehler.size())
	return true
