class_name Startmenue extends CanvasLayer
## Startmenü (16.11.2026, schlicht wie bei anderen Tower-Defense-Spielen): Titel, darunter eine senkrechte Liste.
##   Spielen        → Los, Karte normal/groß, Tutorial an/aus
##   Sandbox
##   Phantom-Modus  → Angreifen / Verteidigen
##   Einstellungen  → Grafik, Vollbild, Mauern, Übersicht
##   Beenden
## Maus oder Tasten (↑ ↓ wählen, Enter bestätigt, Esc zurück). Hintergrund: die Abendbühne (assets/neu/menue),
## rechts posieren die drei Technoclan-Truppen. Gezeichnet im UI-Raster 640×360 (zweifach skaliert).
## Frühere Fassungen (Knopfliste, Basislager, Basisstraße): _vor_startmenue/.

signal gewaehlt(sandbox: bool)
signal phantom_gewaehlt(art: String, pfad: String)
signal tutorial_gewaehlt
signal uebersicht_gewaehlt

const Stil := preload("res://scripts/ui/ui_stil.gd")
const LICHT := Color("7fe0ff")
const KUPFER_HELL := Color("ffb070")
const LISTE_X := 56.0
const LISTE_Y := 128.0
const ZEILE_H := 24.0
const BREITE := 300.0
const LOGO_SKALA := 4.0 / 3.0     # 1 Logopixel = 4 Bildschirmpixel bei 1080p

var spiel: Node                    # setzt main.gd
var _welt: Flaeche
var _bilder := {}
var _seite := "haupt"              # haupt, spielen, phantom, einstellungen
var _wahl := 0
var _maus := Vector2(-100, -100)
var _zeit := 0.0
var _tutorial := false
var _meldung := ""
var _eintraege: Array = []         # [Text, Aktion, Untertitel, Farbe]
# Titelbild (NES/Mega-Drive-Art): nur beim ersten Öffnen nach Programmstart, eine Taste/ein Klick führt zur Liste
static var _titel_gesehen := false
var _titel := false
var _titel_zeit := 0.0
var _sterne: Array = []


class Flaeche extends Control:
	var malen: Callable
	var eingabe: Callable
	func _draw() -> void:
		if malen.is_valid():
			malen.call(self)
	func _gui_input(event: InputEvent) -> void:
		if eingabe.is_valid():
			eingabe.call(event)


func _init() -> void:
	layer = 100
	_welt = Flaeche.new()
	_welt.size = Vector2(640, 360)
	_welt.scale = Vector2(Stil.UI_SKALA, Stil.UI_SKALA)
	_welt.mouse_filter = Control.MOUSE_FILTER_STOP
	_welt.malen = _male
	_welt.eingabe = _maus_eingabe
	add_child(_welt)
	_zeige("haupt")
	_titel = not _titel_gesehen
	_titel_gesehen = true
	var z := RandomNumberGenerator.new()
	z.seed = 7
	for i in 70:
		_sterne.append([Vector2(z.randf() * 640.0, z.randf() * 200.0), z.randf() * TAU, z.randf()])



func _bild(pfad: String) -> Texture2D:
	if not _bilder.has(pfad):
		_bilder[pfad] = load(pfad) if ResourceLoader.exists(pfad) else null
	return _bilder[pfad]


# ------------------------------------------------------------------ Seiten

func _zeige(seite: String) -> void:
	_seite = seite
	_wahl = 0
	_meldung = ""
	_baue()


func _baue() -> void:
	Werte.lade_einstellungen()
	_eintraege = []
	match _seite:
		"haupt":
			_eintraege = [
				["Spielen", _zeige.bind("spielen"), "", LICHT],
				["Sandbox", _starte.bind(true, "sandbox"), "", Stil.TEXT],
				["Phantom-Modus", _zeige.bind("phantom"), "", Stil.TEXT],
				["Einstellungen", _zeige.bind("einstellungen"), "", Stil.TEXT],
				["Beenden", _beenden, "", Stil.TEXT_BLASS],
			]
		"spielen":
			_eintraege = [
				["Los geht's", _los, "20 Runden gegen die Myriaden" + (" · mit Tutorial" if _tutorial else ""), LICHT],
				["Tutorial: " + ("an" if _tutorial else "aus"), _tutorial_umschalten, "Sonde 7 erklärt Schritt für Schritt", Stil.TEXT],
				["Zurück", _zeige.bind("haupt"), "", Stil.TEXT_BLASS],
			]
		"phantom":
			_eintraege = [
				["Angreifen", _phantom.bind("verteidigung"), "Greife den Bau eines anderen Spielers an · " + _anzahl(Phantom.liste("verteidigung", true).size(), "Phantom", "Phantome", "noch keine Phantome hinterlegt"), KUPFER_HELL],
				["Verteidigen", _phantom.bind("angriff"), "Tritt gegen den Angriff eines anderen Spielers an · " + _anzahl(Phantom.liste("angriff").size(), "Angriff", "Angriffe", "noch keine Angriffe hinterlegt"), LICHT],
				["Zurück", _zeige.bind("haupt"), "", Stil.TEXT_BLASS],
			]
		"einstellungen":
			var namen := {"klassisch": "Klassisch", "neu": "Vogelperspektive", "hd": "HD-2D (empfohlen)"}
			_eintraege = [
				["Grafik: " + str(namen.get(Werte.grafik, "?")), _naechste_grafik, "gilt ab der nächsten Partie", Stil.TEXT],
				["Vollbild: " + ("an" if Werte.vollbild else "aus"), _vollbild, "auch mit [F11]", Stil.TEXT],
			]
			if Werte.grafik_hd:
				var wnamen := {"tech": "Tech-Mauer (empfohlen)", "block": "Blöcke", "energie": "Energiewand"}
				_eintraege.append(["Mauern: " + str(wnamen.get(Werte.wand_stil, "Tech-Mauer")), _naechste_mauer, "auch im Spiel mit [M]", Stil.TEXT])
			_eintraege.append(["Musik: " + _prozent_text(Werte.musik), _naechste_musik.bind(10), "Klick lauter, Rechtsklick leiser · auch ← →", Stil.TEXT, _naechste_musik])
			_eintraege.append(["Geräusche: " + _prozent_text(Werte.toene), _naechste_toene.bind(10), "Schüsse nur nah herangezoomt · ← →", Stil.TEXT, _naechste_toene])
			_eintraege.append(["Übersicht", func(): uebersicht_gewaehlt.emit(), "Gegner, Truppen, Bauten, Regeln", Stil.TEXT])
			_eintraege.append(["Zurück", _zeige.bind("haupt"), "", Stil.TEXT_BLASS])
	_wahl = clampi(_wahl, 0, _eintraege.size() - 1)


static func _anzahl(n: int, eins: String, mehr: String, keins: String) -> String:
	if n <= 0:
		return keins
	return "%d %s hinterlegt" % [n, eins if n == 1 else mehr]


func _los() -> void:
	_starte(true, "tutorial" if _tutorial else "normal")


## Startet einen Modus. Gespielt wird auf der großen Karte (Paul 16.11.); nur aufgezeichnete Bauten (Phantom
## angreifen) bringen ihre eigene Kartengröße mit. Passt die Größe nicht, wird umgestellt und die Szene neu geladen –
## main.gd startet dann über naechster_start gleich in den Modus.
func _starte(gross: bool, art: String) -> void:
	if Werte.karte_gross != gross:
		Werte.setze_karte(gross)
		Werte.speichere_einstellungen()
		spiel.naechster_start = art
		_welt.get_tree().reload_current_scene()
		return
	if art == "normal":
		gewaehlt.emit(false)
	elif art == "sandbox":
		gewaehlt.emit(true)
	elif art == "tutorial":
		tutorial_gewaehlt.emit()
	elif art.begins_with("angriff:"):
		phantom_gewaehlt.emit("verteidigung", art.trim_prefix("angriff:"))
	elif art.begins_with("verteidigt:"):
		phantom_gewaehlt.emit("angriff", art.trim_prefix("verteidigt:"))


func _tutorial_umschalten() -> void:
	_tutorial = not _tutorial
	_baue()


func _beenden() -> void:
	_welt.get_tree().quit()


func _phantom(art: String) -> void:
	var funde := Phantom.liste(art, true)
	if funde.is_empty():
		_meldung = "Noch kein Phantom da: Gewinne eine Partie, dann wird dein Bau zum ersten Phantom." if art == "verteidigung" else "Noch kein Angriff da: Greife zuerst selbst einmal als Angreifer an."
		return
	var f: Dictionary = funde.pick_random()
	if art == "verteidigung":
		_starte(int(f.get("spalten", 20)) == 28, "angriff:" + str(f["pfad"]))   # der Bau bringt seine Kartengröße mit
	else:
		_starte(true, "verteidigt:" + str(f["pfad"]))


## Phantom direkt starten (main.gd: „Nochmal angreifen“).
func zeige_phantome(art: String) -> void:
	_zeige("phantom")
	_phantom(art)


func _naechste_grafik() -> void:
	var folge := {"klassisch": "neu", "neu": "hd", "hd": "klassisch"}
	Werte.setze_grafik(str(folge.get(Werte.grafik, "hd")))
	Werte.speichere_einstellungen()
	_baue()


func _vollbild() -> void:
	Werte.setze_vollbild(not Werte.vollbild)
	Werte.speichere_einstellungen()
	_baue()


static func _prozent_text(p: int) -> String:
	return "aus" if p <= 0 else "%d %%" % p


## Lautstärke in 10er-Schritten; über 100 % geht es wieder bei 0 los (nur mit Klick, mit ← → bleibt es am Rand).
func _naechste_musik(d: int, umlauf: bool = true) -> void:
	Werte.musik = _schritt_prozent(Werte.musik, d, umlauf)
	Werte.speichere_einstellungen()
	Musik.lautstaerke(_welt.get_tree())
	_baue()


static func _schritt_prozent(p: int, d: int, umlauf: bool) -> int:
	var n := p + d
	if umlauf and n > 100:
		return 0
	if umlauf and n < 0:
		return 100
	return clampi(n, 0, 100)


func _naechste_toene(d: int, umlauf: bool = true) -> void:
	Werte.toene = _schritt_prozent(Werte.toene, d, umlauf)
	Werte.speichere_einstellungen()
	_baue()


func _naechste_mauer() -> void:
	var folge := {"tech": "energie", "energie": "block", "block": "tech"}
	Werte.wand_stil = str(folge.get(Werte.wand_stil, "tech"))
	Werte.speichere_einstellungen()
	_baue()


# ------------------------------------------------------------------ Eingabe

func _process(delta: float) -> void:
	_zeit += delta
	_titel_zeit += delta
	_maus = _welt.get_local_mouse_position()
	# Übersicht offen: das Menü wartet unsichtbar
	_welt.visible = not (spiel != null and spiel.get("_lexikon") != null and spiel._lexikon.visible)
	_welt.queue_redraw()


func _zeile(i: int) -> Rect2:
	return Rect2(LISTE_X, LISTE_Y + i * ZEILE_H, BREITE, ZEILE_H - 4.0)


func _input(event: InputEvent) -> void:
	if not _welt.visible or not (event is InputEventKey and event.pressed):
		return
	if _titel:
		if not event.echo:
			_titel_weiter()
		get_viewport().set_input_as_handled()
		return
	var k: int = (event as InputEventKey).keycode
	match k:
		KEY_UP, KEY_W:
			_wahl = posmod(_wahl - 1, _eintraege.size())
		KEY_DOWN, KEY_S:
			_wahl = posmod(_wahl + 1, _eintraege.size())
		KEY_LEFT, KEY_RIGHT, KEY_A, KEY_D:
			var e: Array = _eintraege[_wahl]
			if e.size() > 4 and (e[4] as Callable).is_valid():
				(e[4] as Callable).call(-10 if k in [KEY_LEFT, KEY_A] else 10, false)
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			if not event.echo:
				(_eintraege[_wahl][1] as Callable).call()
		KEY_ESCAPE, KEY_BACKSPACE:
			if _seite != "haupt" and not event.echo:
				_zeige("haupt")
		_:
			return
	get_viewport().set_input_as_handled()


func _maus_eingabe(event: InputEvent) -> void:
	if _titel:
		if event is InputEventMouseButton and event.pressed:
			_titel_weiter()
		return
	if event is InputEventMouseMotion:
		for i in _eintraege.size():
			if _zeile(i).has_point(_maus):
				_wahl = i
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT and _seite != "haupt":
			for i in _eintraege.size():
				var e: Array = _eintraege[i]
				if _zeile(i).has_point((event as InputEventMouseButton).position) and e.size() > 4:
					(e[4] as Callable).call(-10, true)   # Rechtsklick auf eine Lautstärke: leiser
					return
			_zeige("haupt")
		elif event.button_index == MOUSE_BUTTON_LEFT:
			for i in _eintraege.size():
				if _zeile(i).has_point((event as InputEventMouseButton).position):
					_wahl = i
					(_eintraege[i][1] as Callable).call()
					return


# ------------------------------------------------------------------ Zeichnen

func _male(ci: Control) -> void:
	if _titel:
		_male_titel(ci)
		return
	var hg := _bild("res://assets/neu/menue/kaserne.png")
	if hg != null:
		ci.draw_texture_rect(hg, Rect2(0, 0, 640, 360), false)
	else:
		ci.draw_rect(Rect2(0, 0, 640, 360), Color("10141c"))
	# links abdunkeln, damit die Liste gut lesbar ist
	for k in 40:
		ci.draw_rect(Rect2(k * 8.0, 0, 8, 360), Color(0.03, 0.04, 0.06, 0.8 * (1.0 - k / 40.0)))
	# (Truppen im Menü entfernt, Paul 16.11.)
	# Logo (klein, 1 Logopixel = 2 Bildschirmpixel bei 1080p)
	var logo := _bild("res://assets/neu/menue/logo.png")
	if logo != null:
		ci.draw_texture_rect(logo, Rect2(Vector2(LISTE_X - 6.0, 26), Vector2(logo.get_size()) * (2.0 / 3.0)), false)
	else:
		Stil.schreibe(ci, Vector2(LISTE_X, 76), "PAULS TD BATTLER", 22, Stil.TEXT)
	var unter: String = {"haupt": "", "spielen": "Spielen", "phantom": "Phantom-Modus", "einstellungen": "Einstellungen"}[_seite]
	if unter != "":
		Stil.schreibe(ci, Vector2(LISTE_X, 110), unter, Stil.NORMAL, Stil.TEXT_BLASS)
	# Liste
	for i in _eintraege.size():
		var e: Array = _eintraege[i]
		var r := _zeile(i)
		var an := i == _wahl
		var farbe: Color = e[3]
		if an:
			Stil.platte(ci, r, 3.0, Color(LICHT, 0.12), LICHT)
			var m := Vector2(r.position.x - 6.0 - 1.5 * absf(sin(_zeit * 4.0)), r.get_center().y)
			ci.draw_colored_polygon(PackedVector2Array([m + Vector2(-5, -4), m + Vector2(0, 0), m + Vector2(-5, 4)]), LICHT)
			if farbe == Stil.TEXT_BLASS or farbe == Stil.TEXT:
				farbe = Color.WHITE
		var mit_unter := str(e[2]) != ""
		Stil.schreibe(ci, Vector2(r.position.x + 8.0, r.position.y + (6.0 if mit_unter else 10.0)), e[0], Stil.NORMAL, farbe)
		if mit_unter:
			Stil.schreibe(ci, Vector2(r.position.x + 8.0, r.position.y + 15.0), e[2], Stil.KLEIN, Stil.TEXT_BLASS)
	if _meldung != "":
		Stil.absatz(ci, Vector2(LISTE_X, LISTE_Y + _eintraege.size() * ZEILE_H + 4.0), _meldung, BREITE, Stil.KLEIN, Stil.WARN)


## Die drei Technoclan-Truppen posieren rechts auf der Bühne (Standbilder, leicht atmend).
func _male_truppen(ci: Control) -> void:
	var truppen := [["res://assets/sprites/scharfschuetze.png", Vector2(430, 296)], ["res://assets/sprites/technogunner.png", Vector2(486, 304)], ["res://assets/sprites/plasmawerfer.png", Vector2(542, 296)]]
	for k in truppen.size():
		var tex := _bild(truppen[k][0])
		if tex == null:
			continue
		var fuss: Vector2 = truppen[k][1]
		var schatten := PackedVector2Array()
		for i in 16:
			var w := TAU * i / 16.0
			schatten.append(fuss + Vector2(cos(w) * 22.0, sin(w) * 5.0))
		ci.draw_colored_polygon(schatten, Color(0, 0, 0, 0.4))
		var g := Vector2(96, 96)   # 48er-Bild doppelt
		var bild := int(_zeit * 4.0 + k) % 4
		var ziel := Rect2((fuss - Vector2(g.x / 2.0, g.y * 0.92)).round(), g)
		if k == 2:
			ziel = Rect2(ziel.position, Vector2(-g.x, g.y))   # der rechte schaut zur Mitte
		ci.draw_texture_rect_region(tex, ziel, Rect2(bild * 48, 0, 48, 48))


# ------------------------------------------------------------------ Titelbild

const TITEL_EINLAUF := 2.2      # so lange läuft der Auftritt; ein Druck vorher spult ihn nur vor

func _titel_weiter() -> void:
	if _titel_zeit < TITEL_EINLAUF:
		_titel_zeit = TITEL_EINLAUF
		return
	_titel = false


## Weich ab 0, mit kleinem Überschwingen am Ende (für Logo und Truppen).
static func _feder(t: float) -> float:
	t = clampf(t, 0.0, 1.0)
	var c := 1.7
	return 1.0 + (c + 1.0) * pow(t - 1.0, 3.0) + c * pow(t - 1.0, 2.0)


func _male_titel(ci: Control) -> void:
	var t := _titel_zeit
	_male_lageplan(ci, t)
	# Logo fällt von oben und setzt mit einem Ruck auf
	var lf := _feder((t - 0.2) / 0.6)
	var wackel := Vector2.ZERO
	if t > 0.8 and t < 1.05:
		wackel = Vector2(0, 2.0 * sin(t * 80.0))
	var schweben := Vector2(0, 2.0 * sin(t * 1.4)) if t > TITEL_EINLAUF else Vector2.ZERO
	var logo := _bild("res://assets/neu/menue/logo.png")
	var mitte := Vector2(320, 150) + Vector2(0, (1.0 - lf) * -260.0) + wackel + schweben
	if logo != null:
		var lg := Vector2(logo.get_size()) * LOGO_SKALA * 1.5
		ci.draw_texture_rect(logo, Rect2((mitte - lg / 2.0).round(), lg), false)
	else:
		Stil.schreibe_mittig(ci, mitte, "PAULS TD BATTLER", 30, Stil.TEXT)
	if t > TITEL_EINLAUF and fmod(t, 1.0) < 0.65:
		Stil.schreibe_mittig(ci, Vector2(320, 300), "DRÜCKE EINE TASTE", Stil.GROSS, Color.WHITE)


## Abstrakter Lageplan: Nachtblau, feines Gitter, treibende Höhenlinien, Mauerzüge und Checkpoints in Cyan,
## eine kupferne Gegnerroute. Ganz aus dem Code.
func _male_lageplan(ci: Control, t: float) -> void:
	ci.draw_rect(Rect2(0, 0, 640, 360), Color("070b16"))
	var gitter := Color(LICHT, 0.05)
	var ver := fmod(t * 4.0, 20.0)
	for x in range(-20, 660, 20):
		ci.draw_rect(Rect2(x + ver, 0, 1, 360), gitter)
	for y in range(-20, 380, 20):
		ci.draw_rect(Rect2(0, y + ver * 0.5, 640, 1), gitter)
	# Höhenlinien um drei treibende Hügel
	var huegel := [Vector2(150, 110), Vector2(500, 250), Vector2(420, 70)]
	for h in huegel.size():
		var m: Vector2 = huegel[h] + Vector2(sin(t * 0.15 + h) * 20.0, cos(t * 0.12 + h * 2.0) * 12.0)
		for ring in range(1, 7):
			var pts := PackedVector2Array()
			for i in 49:
				var w := TAU * i / 48.0
				var r := ring * 17.0 * (1.0 + 0.18 * sin(w * 3.0 + h + ring * 0.4) + 0.08 * sin(w * 5.0 - t * 0.3))
				pts.append(m + Vector2(cos(w) * r * 1.5, sin(w) * r))
			ci.draw_polyline(pts, Color(LICHT, 0.10 - ring * 0.01), 1.0)
	# kupferne Route mit wanderndem Strich
	var route := PackedVector2Array([Vector2(-10, 200), Vector2(90, 200), Vector2(90, 280), Vector2(260, 280), Vector2(260, 190), Vector2(400, 190), Vector2(400, 300), Vector2(560, 300), Vector2(560, 160), Vector2(650, 160)])
	ci.draw_polyline(route, Color(KUPFER_HELL, 0.10), 3.0)
	var laenge := 0.0
	for i in route.size() - 1:
		laenge += route[i].distance_to(route[i + 1])
	var pos := 0.0
	for i in route.size() - 1:
		var a: Vector2 = route[i]
		var b: Vector2 = route[i + 1]
		var d := a.distance_to(b)
		var s := 0.0
		while s < d:
			var phase := fmod(pos + s - t * 30.0, 14.0)
			if phase < 0.0:
				phase += 14.0
			if phase < 6.0:
				ci.draw_rect(Rect2((a + (b - a) * (s / d)).round() - Vector2.ONE, Vector2(2, 2)), Color(KUPFER_HELL, 0.35))
			s += 2.0
		pos += d
	# Mauerzüge
	for m: Rect2 in [Rect2(40, 150, 120, 6), Rect2(180, 230, 6, 90), Rect2(320, 140, 6, 110), Rect2(460, 250, 70, 6), Rect2(480, 110, 6, 90)]:
		ci.draw_rect(m, Color(LICHT, 0.10))
		ci.draw_rect(m, Color(LICHT, 0.35), false, 1.0)
	# Checkpoints pulsieren
	for k in 3:
		var c: Vector2 = [Vector2(260, 280), Vector2(400, 190), Vector2(560, 300)][k]
		var puls := fmod(t * 0.6 + k * 0.33, 1.0)
		ci.draw_arc(c, 4.0 + puls * 14.0, 0, TAU, 24, Color(LICHT, 0.4 * (1.0 - puls)), 1.0)
		ci.draw_rect(Rect2(c - Vector2(2, 2), Vector2(4, 4)), Color(LICHT, 0.7))
	# Vignette
	for k in 12:
		var a2 := 0.06
		ci.draw_rect(Rect2(0, k * 3.0, 640, 3), Color(0, 0, 0, a2 * (12 - k)))
		ci.draw_rect(Rect2(0, 357.0 - k * 3.0, 640, 3), Color(0, 0, 0, a2 * (12 - k)))
