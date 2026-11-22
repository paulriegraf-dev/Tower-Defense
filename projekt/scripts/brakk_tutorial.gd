class_name BrakkTutorial
extends Tutorial
## 22.11. (Paul): Tutorial für das erste Mal Brakk-Mode (Classic, mit Brakk). Sonde 7 meldet sich im selben
## Hologramm-Funkfenster wie im normalen Tutorial (tutorial.gd, davon geerbt) und geht die Mechaniken Schritt für
## Schritt durch: Parkour (Laufen, Springen, Doppelsprung, Tumble, Lichttreppe, Lichtbrücke, Lichtanker), Schießstand
## (Pistolen, Ladestrahl, Lichtsäule, Zeitlupe, Klonmaschine), Bauen in der Ego-Sicht (Erdwälle, Stellung, Fabrik),
## Ringe (Lichtterminal [F], Kauf/Aufwertung, Mausrad, Wirkung auf die Schüsse, Ringfeld [C]) und eine Probewelle.
## Jeder Handgriff hat eine kleine Aufgabe; erfüllt = weiter. [Enter] weiter, [Rücktaste] Schritt überspringen,
## [Entf] zweimal = Tutorial beenden (Alt hält die Maus frei für die Knöpfe).
## Übungsgelände: dieselbe Partie, aber viel Budget, Basis und Brakk fallen nicht, kein Countdown, alle Fähigkeiten
## frei, zwei Ringfinger, die Bauphase bleibt, bis die Probewelle gestartet wird. Am Ende (oder beim Abbrechen) startet
## ein frischer, echter Brakk-Mode.
## Abfrage: beim ersten Brakk-Mode je Profil (Merker MERKER in Profil.einstellung): „" = noch offen (Frage kommt
## wieder), „gespielt" = einmal gestartet, „abgelehnt" = ausdrücklich nein. Wiederholen: Brakk-Mode → Tutorial.

const MERKER := "brakk_tutorial"
const UEBUNG_BUDGET := 99999
const ZIEL_HALB := 18.0                 # halbe Größe der Zielmarke auf dem Bildschirm
const ENTF_FRIST := 3.0                 # Sekunden für das zweite [Entf]

static var erzwingen := false           # Test: Abfrage auch ohne Bildschirm (headless)
static var direkt := false              # Startmenü „Tutorial“: ohne Frage gleich los
static var ohne_neustart := false       # Test: am Ende keinen neuen Brakk-Mode laden
static var letzter_ausgang := ""        # Test: "fertig", "abgebrochen", "spaeter", "abgelehnt"

var _btn_ablehnen: Button
var _abdunkeln: ColorRect
var _entf_rest := 0.0
var _platz := Karte.KEINE               # Start des Parkours (Laufmarke); Wall A liegt 3 Felder links, Wall B 6
var _wall_a: Array[Vector2i] = []
var _wall_b: Array[Vector2i] = []
var _ziele: Array = []                  # aufgestellte Zielscheiben (Gegner, die in der Bauphase stillstehen)


## Vom Brakk-Mode-Start (main.gd, nach dem Einschalten der Ego-Sicht): Frage zeigen – oder gleich los (Startmenü).
static func anbieten(p: Node) -> void:
	var gleich := direkt
	direkt = false
	if p.ego == null or p.order24 != null or p.tutorial != null or (p.ego as EgoModus).kit != null:
		return   # nur Classic mit Brakk (Irrtürmer und Sonde 7 haben ein eigenes Kit)
	if not gleich:
		if Labor.aktiv or Profil.nur_lesen or Touch.ohne_maus():
			return
		if str(Profil.einstellung(MERKER, "")) != "":
			return
		if DisplayServer.get_name() == "headless" and not erzwingen:
			return
	var t := BrakkTutorial.new()
	t.spiel = p
	p.tutorial = t
	p.add_child(t)
	if gleich:
		t._weiter()


## Startmenü (Brakk-Mode → Tutorial): Brakk-Mode mit Brakk starten, das Tutorial beginnt ohne Frage.
static func aus_menue(menue: Node) -> void:
	direkt = true
	Werte.setze_anfuehrer("brakk")
	menue._starte(true, "brakk")


func _ready() -> void:
	super()
	_name.text = "SONDE 7 · ÜBUNGSGELÄNDE"
	_btn_nein.text = "Später"
	_btn_ablehnen = _knopf(_btn_nein.get_parent(), "Nein, danke", false)
	_btn_nein.get_parent().move_child(_btn_ablehnen, _btn_nein.get_index())
	_btn_ablehnen.pressed.connect(_ablehnen)
	_abdunkeln = ColorRect.new()
	_abdunkeln.color = Color(0.0, 0.02, 0.05, 0.55)
	_abdunkeln.set_anchors_preset(Control.PRESET_FULL_RECT)
	_abdunkeln.mouse_filter = Control.MOUSE_FILTER_STOP   # Klicks gehen nicht an die Einsatz-Tafel darunter
	_wurzel.add_child(_abdunkeln)
	_wurzel.move_child(_abdunkeln, 0)
	_zeige_frage()


## Braucht das Tutorial gerade die Maus? (ego_modus.gd gibt sie dann frei)
func braucht_maus() -> bool:
	return not _aus and _frage


# ------------------------------------------------------------------ Ablauf

func _zeige_frage() -> void:
	_frage = true
	_setze_text("Brakk, hier Sonde 7. Dein erster Einsatz in der Ego-Sicht. Ich habe ein Übungsgelände vorbereitet: Parkour, Schießstand, Bauen und deine Ringe – ohne Risiko, Schritt für Schritt. Willst du es durchgehen?")
	_fortschritt.text = ""
	_hinweis.text = ""
	_btn_weiter.text = "Tutorial starten ▸ [Enter]"
	_btn_weiter.visible = true
	_btn_nein.visible = true
	_btn_skip.visible = false
	_btn_ende.visible = false
	if _btn_ablehnen != null:
		_btn_ablehnen.visible = true
	if _abdunkeln != null:
		_abdunkeln.visible = true


func _starte() -> void:
	_frage = false
	_btn_weiter.text = "Weiter ▸ [Enter]"
	_btn_skip.text = "Überspringen [Rücktaste]"
	_btn_nein.visible = false
	_btn_ablehnen.visible = false
	_btn_ende.visible = true
	_abdunkeln.visible = false
	Profil.setze_einstellung(MERKER, "gespielt")
	spiel._protokoll["brakk_tutorial"] = true
	spiel.budget = UEBUNG_BUDGET
	var ego: EgoModus = spiel.ego
	if ego != null and ego._briefing_offen():
		ego._briefing_los()   # Einsatz-Tafel weg, Einflug in Brakks Augen
	var f := _f()
	if f != null:
		f.alle_frei = true      # alle Fähigkeiten, unabhängig von der Stufe
		f.stufen_fest = true    # keine Erfahrung im Übungsgelände
		f.stufe = maxi(f.stufe, BrakkFortschritt.FINGER_AB[1])   # zwei Ringfinger
	_baue_parkour()
	_naechster()


func _naechster() -> void:
	_ziele_weg()
	if _index >= _schritte.size() - 1:
		letzter_ausgang = "fertig"
		_schliessen(true)
		return
	_index += 1
	_merk = {}
	var s: Dictionary = _schritte[_index]
	if s.has("start"):
		(s["start"] as Callable).call()
	_setze_text(str(s["text"]))
	_btn_weiter.visible = not s.has("fertig")
	_btn_skip.visible = s.has("fertig")
	_fortschritt.text = "Schritt %d / %d" % [_index + 1, _schritte.size()]


## „Später“ (in der Frage) oder „Tutorial beenden“ (im Ablauf).
func beenden() -> void:
	if _aus:
		return
	if _frage:
		letzter_ausgang = "spaeter"
		spiel.melde("Sonde 7 fragt beim nächsten Brakk-Mode wieder – oder jederzeit unter Brakk-Mode → Tutorial.", 5.0)
		_schliessen(false)
		return
	letzter_ausgang = "abgebrochen"
	_schliessen(true)


func _ablehnen() -> void:
	if _aus or not _frage:
		return
	letzter_ausgang = "abgelehnt"
	Profil.setze_einstellung(MERKER, "abgelehnt")
	spiel.melde("Verstanden. Das Tutorial findest du jederzeit unter Brakk-Mode → Tutorial.", 5.0)
	_schliessen(false)


## Fenster zu. `neu`: Das Übungsgelände ist vorbei – ein frischer Brakk-Mode startet (Budget, Stufen, Countdown echt).
func _schliessen(neu: bool) -> void:
	_aus = true
	_ziele_weg()
	_scheiben_weg()
	if spiel != null:
		spiel.tutorial = null
	queue_free()
	if neu and spiel != null and not ohne_neustart:
		spiel.melde("Übungsgelände beendet – der echte Brakk-Mode beginnt.", 4.0)
		spiel._neustart()


func _input(event: InputEvent) -> void:
	if _aus or not (event is InputEventKey):
		return
	var k := event as InputEventKey
	if not k.pressed or k.echo:
		return
	if _frage:
		match k.keycode:
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
				_weiter()
			KEY_ESCAPE:
				beenden()
			KEY_N:
				_ablehnen()
		get_viewport().set_input_as_handled()   # solange die Frage steht, gehören die Tasten ihr
		return
	if _index < 0:
		return
	var s: Dictionary = _schritte[_index]
	if k.keycode in [KEY_ENTER, KEY_KP_ENTER] and not s.has("fertig"):
		_weiter()
		get_viewport().set_input_as_handled()
	elif k.keycode == KEY_BACKSPACE and s.has("fertig"):
		_weiter()
		get_viewport().set_input_as_handled()
	elif k.keycode == KEY_DELETE and not (spiel.ego != null and spiel.ego.gebaeude_im_blick() != Karte.KEINE):   # 22.11.: Gebäude im Blick = Abbauen, nicht Tutorial beenden
		if _entf_rest > 0.0:
			beenden()
		else:
			_entf_rest = ENTF_FRIST
			spiel.melde("Noch einmal [Entf]: Tutorial beenden.", ENTF_FRIST)
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if _aus:
		return
	var echt := delta / maxf(Engine.time_scale, 0.01)
	_entf_rest = maxf(0.0, _entf_rest - echt)
	_scheiben_weiter(echt)
	if not _frage:
		_uebungsgelaende()
	super(delta)
	if _aus or _frage or _index < 0:
		return
	var s: Dictionary = _schritte[_index]
	_btn_skip.visible = s.has("fertig")
	if s.has("ort") and _ziel_rect().size == Vector2.ZERO and _hinweis.text != "":
		_hinweis.text += "  ·  die Marke liegt hinter dir"


## Auch je Simulationsschritt auffüllen: in der Probewelle erreichen sonst mehrere Gegner zwischen zwei Bildern die Basis.
func _physics_process(_takt: float) -> void:
	if not _aus and not _frage:
		_uebungsgelaende()


## Übungsgelände: nichts kann verloren gehen.
func _uebungsgelaende() -> void:
	spiel.leben = maxi(int(spiel.leben), Werte.START_LEBEN)
	if int(spiel.budget) < UEBUNG_BUDGET / 2:
		spiel.budget = UEBUNG_BUDGET
	var b: Kommandant = spiel.kommandant
	if b != null and not b.gefallen:
		b.leben = b.max_leben


# ------------------------------------------------------------------ Zielmarke auf dem Bildschirm

## Schritte mit "ort" (Punkt in der 3D-Welt, in Feldern) bekommen Ring und Pfeil an dieser Stelle.
func _ziel_rect() -> Rect2:
	if _frage or _index < 0:
		return Rect2()
	var s: Dictionary = _schritte[_index]
	if not s.has("ort") or spiel.hd == null:
		return Rect2()
	var o: Variant = (s["ort"] as Callable).call()
	if not (o is Vector3):
		return Rect2()
	var k: Camera3D = spiel.hd.kamera
	if k.is_position_behind(o as Vector3):
		return Rect2()
	var m := k.unproject_position(o as Vector3)
	return Rect2(m - Vector2(ZIEL_HALB, ZIEL_HALB), Vector2(ZIEL_HALB, ZIEL_HALB) * 2.0)


## Mitte des Felds `z` in der 3D-Welt; `hoch` = auf der Mauerkrone.
func _ort(z: Vector2i, hoch: bool = false) -> Variant:
	if z == Karte.KEINE:
		return null
	var p: Vector2 = spiel.karte.mitte(z)
	return Vector3(p.x / Werte.ZELLE, spiel.hd.H if hoch else 0.0, (p.y - Werte.KARTE_OBEN) / Werte.ZELLE)


# ------------------------------------------------------------------ Hilfen

func _f() -> BrakkFortschritt:
	var b: Kommandant = spiel.kommandant
	return b.fortschritt if b != null else null


func _zaehler(was: String) -> int:
	var f := _f()
	return int(f.zaehler.get(was, 0)) if f != null else 0


func _brakk_zelle() -> Vector2i:
	return spiel.karte.zelle_bei(spiel.kommandant.position)


func _brakk_oben() -> bool:
	return spiel.kommandant.oben


func _anzahl_ausbau(typ: int) -> int:
	var n := 0
	for t: int in spiel.karte.ausbau.values():
		if t == typ:
			n += 1
	return n


## Platz für den Parkour suchen und bauen: zwei Mauerstücke (je 3 Felder quer), dazwischen 2 Felder Lücke.
## Laufmarke = 3 Felder rechts von Wall A. Gesucht wird nah bei Brakk, wo das ganze Rechteck frei ist.
func _baue_parkour() -> void:
	var k: Karte = spiel.karte
	var b := _brakk_zelle()
	var beste := INF
	for dy in range(-6, 7):
		for dx in range(-4, 9):
			var a := b + Vector2i(dx, dy)
			if not _parkour_passt(a):
				continue
			var d := Vector2(dx, dy).length()
			if d < beste:
				beste = d
				_platz = a
	if _platz == Karte.KEINE:
		_platz = b   # kein freies Rechteck: Schritte lassen sich überspringen
		return
	for dy in [-1, 0, 1]:
		for x: int in [_platz.x - 3, _platz.x - 6]:
			var z := Vector2i(x, _platz.y + int(dy))
			k.setze(z, Karte.WALL)
			k.fest[z] = true   # nicht abreißbar
			(_wall_a if x == _platz.x - 3 else _wall_b).append(z)


func _parkour_passt(a: Vector2i) -> bool:
	var k: Karte = spiel.karte
	for dy in range(-1, 2):
		for dx in range(-6, 1):
			var z := a + Vector2i(dx, dy)
			if z.x < Werte.ZONE_SPALTEN + 1 or not k.ist_bebaubar(z) or k.ist_basis(z) or k.checkpoints.has(z):
				return false
	return true


func _auf(liste: Array[Vector2i]) -> bool:
	return _brakk_oben() and liste.has(_brakk_zelle())


## Zielscheiben: `n` Gegner vom Typ `typ` vor Brakk – in Blickrichtung, etwa ZIEL_ABSTAND Felder weit, mit freier
## Sicht (in der Bauphase stehen sie still). `gruppe`: dicht beieinander (für die Lichtsäule).
const ZIEL_ABSTAND := 5.0

func _stelle_ziele(typ: String, n: int, gruppe: bool = false) -> void:
	_ziele_weg()
	var k: Karte = spiel.karte
	var b := _brakk_zelle()
	var blick := Vector2(-1.0, 0.0)   # ohne Ego-Sicht: nach links, dorther kommen die Myriaden
	var ego: EgoModus = spiel.ego
	if ego != null:
		blick = Vector2(ego._vorne().x, ego._vorne().z).normalized()
	var kandidaten: Array[Vector2i] = []
	var wert := {}
	for dy in range(-8, 9):
		for dx in range(-8, 9):
			var z := b + Vector2i(dx, dy)
			var d := Vector2(dx, dy).length()
			if d < 3.0 or d > 8.0 or not _ziel_platz(z) or not _sicht_frei(b, z):
				continue
			kandidaten.append(z)
			wert[z] = absf(d - ZIEL_ABSTAND) + 3.0 * (1.0 - blick.dot(Vector2(dx, dy) / d))
	kandidaten.sort_custom(func(a: Vector2i, c: Vector2i) -> bool: return float(wert[a]) < float(wert[c]))
	if gruppe and not kandidaten.is_empty():
		var mitte := kandidaten[0]   # die anderen dicht um die beste Stelle
		kandidaten.sort_custom(func(a: Vector2i, c: Vector2i) -> bool: return Vector2(a - mitte).length() < Vector2(c - mitte).length())
	var gesetzt := 0
	var winkel: Array[float] = []
	for z: Vector2i in kandidaten:
		if gesetzt >= n:
			break
		var w := Vector2(z - b).angle()
		if not gruppe:
			var verdeckt := false
			for w2: float in winkel:
				verdeckt = verdeckt or absf(angle_difference(w, w2)) < deg_to_rad(10.0)
			if verdeckt:
				continue   # nicht hintereinander: jede Scheibe ist aus Brakks Sicht ein eigenes Ziel
		winkel.append(w)
		var g := Gegner.new()
		spiel.figuren.add_child(g)
		g.start(spiel, k, typ, 1.0, z, 0)
		spiel.gegner.append(g)
		_ziele.append(g)
		gesetzt += 1
		_scheibe_an(g, typ == "schild")
	_ziele_anfang = _ziele.size()


# ------------------------------------------------------------------ Zielscheiben (Bild wie ein Schießstand)
## 22.11. (Paul, Bildvorschlag Schießstand): Statt Myriaden stehen runde Zielscheiben auf einem Ständer da – rot-weiße
## Ringe in Pixeloptik. Der Gegner bleibt als Trefferziel (unsichtbar; die HD-Ansicht spiegelt nur sichtbare Figuren),
## Trefferhöhe und -radius kommen über seine Metadaten (ego_modus.gd _ziel_mitte/_ziel_radius). Treffer lassen die
## Scheibe aufblitzen, eine gefallene klappt weg; die Meldung zählt mit („Treffer 2 / 3“).
const SCHEIBE_PIXEL := 0.022            # Felder je Bildpunkt (Scheibe 32 Bildpunkte ≈ 0,7 Felder)
const SCHEIBE_B := 32
const SCHEIBE_H := 46
const SCHEIBE_MITTE_Y := 15             # Scheibenmitte im Bild (von oben)
static var _scheibe_tex: Texture2D = null
var _scheiben: Dictionary = {}          # Gegner -> [Sprite3D, Leben vorher, Blitz-Rest, Größe]
var _ziele_anfang := 0


static func _scheiben_bild() -> Texture2D:
	if _scheibe_tex != null:
		return _scheibe_tex
	var img := Image.create(SCHEIBE_B, SCHEIBE_H, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var rot := Color("e8443a")
	var weiss := Color("f4efe6")
	var rand := Color("3a2420")
	var metall := Color("6b6f78")
	var metall_hell := Color("9aa0aa")
	# Ständer: Stange und Fuß
	for y in range(SCHEIBE_MITTE_Y + 10, SCHEIBE_H):
		img.set_pixel(15, y, metall)
		img.set_pixel(16, y, metall_hell)
	for x in range(9, 23):
		img.set_pixel(x, SCHEIBE_H - 2, metall)
		img.set_pixel(x, SCHEIBE_H - 1, rand)
	# Scheibe: Ringe von außen nach innen rot, weiß, rot, weiß, rotes Zentrum
	var m := Vector2(15.5, float(SCHEIBE_MITTE_Y) + 0.5)
	for y in SCHEIBE_H:
		for x in SCHEIBE_B:
			var d := Vector2(x + 0.5, y + 0.5).distance_to(m)
			if d > 15.0:
				continue
			var c := rand if d > 14.0 else ([rot, weiss, rot, weiss, rot][clampi(4 - int(d / 2.8), 0, 4)] as Color)
			img.set_pixel(x, y, c)
	_scheibe_tex = ImageTexture.create_from_image(img)
	return _scheibe_tex


func _scheibe_an(g: Gegner, gross: bool) -> void:
	var groesse := 1.4 if gross else 1.0
	g.visible = false   # nur noch Trefferziel – zu sehen ist die Scheibe
	g.set_meta("treffer_hoehe", (SCHEIBE_H - SCHEIBE_MITTE_Y) * SCHEIBE_PIXEL * groesse)
	g.set_meta("treffer_radius", 15.0 * SCHEIBE_PIXEL * groesse)
	if spiel.hd == null:
		return
	var s := Sprite3D.new()
	s.texture = _scheiben_bild()
	s.pixel_size = SCHEIBE_PIXEL * groesse
	s.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y   # dreht sich zu Brakk, bleibt aber aufrecht
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	s.shaded = false
	s.double_sided = true
	(spiel.hd as Node).add_child(s)
	_scheiben[g] = [s, g.leben, 0.0, groesse]
	_scheibe_stellen(g)


func _scheibe_stellen(g: Gegner) -> void:
	var e: Array = _scheiben[g]
	var s: Sprite3D = e[0]
	var p := g.position
	s.position = Vector3(p.x / Werte.ZELLE, SCHEIBE_H * 0.5 * SCHEIBE_PIXEL * float(e[3]), (p.y - Werte.KARTE_OBEN) / Werte.ZELLE)


## Je Bild: Aufblitzen bei Treffer, Wegklappen gefallener Scheiben, Zähler.
func _scheiben_weiter(echt: float) -> void:
	for g: Variant in _scheiben.keys():
		var e: Array = _scheiben[g]
		var s: Sprite3D = e[0]
		var weg: bool = not is_instance_valid(g) or not spiel.gegner.has(g)
		if weg:
			if float(e[2]) > -1.0:
				e[2] = -1.0   # klappt nach hinten weg
				var getroffen := _ziele_anfang - _ziele_uebrig()
				if _ziele_anfang > 1 and getroffen > 0:
					spiel.melde("Treffer! %d / %d" % [getroffen, _ziele_anfang], 1.5)
			s.rotation.x = move_toward(s.rotation.x, -PI / 2.0, echt * 8.0)
			s.modulate.a = move_toward(s.modulate.a, 0.0, echt * 2.5)
			if s.modulate.a <= 0.0:
				s.queue_free()
				_scheiben.erase(g)
			continue
		var gg := g as Gegner
		if gg.leben < float(e[1]):
			e[2] = 0.12   # getroffen: kurz hell
		e[1] = gg.leben
		e[2] = maxf(0.0, float(e[2]) - echt)
		s.modulate = Color(2.2, 2.2, 2.2) if float(e[2]) > 0.0 else Color.WHITE
		_scheibe_stellen(gg)


func _scheiben_weg() -> void:
	for e: Array in _scheiben.values():
		if is_instance_valid(e[0]):
			(e[0] as Node).queue_free()
	_scheiben.clear()


func _ziel_platz(z: Vector2i) -> bool:
	var k: Karte = spiel.karte
	return z.x >= Werte.ZONE_SPALTEN and k.in_karte(z) and k.ist_frei(z) and k.ist_begehbar(z) and not k.ist_basis(z) \
		and not k.checkpoints.has(z) and z != _brakk_zelle()


## Keine Mauer und kein Gebäude zwischen Brakk und dem Feld `nach` – von Brakks echter Position aus, in kleinen
## Schritten abgetastet, mit einem Rand von 0,3 Feldern zu beiden Seiten (die Scheibe ist kein Punkt).
func _sicht_frei(_von: Vector2i, nach: Vector2i) -> bool:
	var k: Karte = spiel.karte
	var a: Vector2 = spiel.kommandant.position
	var b: Vector2 = k.mitte(nach)
	var quer := (b - a).orthogonal().normalized() * 0.3 * Werte.ZELLE
	var eigene := _brakk_zelle()
	var schritte := maxi(1, ceili(a.distance_to(b) / Werte.ZELLE * 10.0))
	for i in range(1, schritte):
		var p := a.lerp(b, float(i) / float(schritte))
		for q: Vector2 in [Vector2.ZERO, quer, -quer]:
			var z := k.zelle_bei(p + q)
			if z == eigene or z == nach:
				continue
			if not k.ist_frei(z) or k.ist_basis(z) or (spiel.hd != null and spiel.hd.ist_hoch(z)):
				return false
	return true


func _ziele_weg() -> void:
	for g: Variant in _ziele:
		if _scheiben.has(g):
			(_scheiben[g] as Array)[2] = -1.0   # klappt weg, ohne als Treffer zu zählen
		if is_instance_valid(g) and spiel.gegner.has(g):
			spiel.gegner_entfernt(g as Gegner)
	_ziele.clear()


func _ziele_uebrig() -> int:
	var n := 0
	for g: Variant in _ziele:
		if is_instance_valid(g) and spiel.gegner.has(g):
			n += 1
	return n


func _ziel_ort() -> Variant:
	for g: Variant in _ziele:
		if is_instance_valid(g) and spiel.gegner.has(g):
			var p: Vector2 = (g as Gegner).position
			return Vector3(p.x / Werte.ZELLE, 0.5, (p.y - Werte.KARTE_OBEN) / Werte.ZELLE)
	return null


func _terminal_offen() -> bool:
	var ego: EgoModus = spiel.ego
	return ego != null and ego._terminal != null and ego._terminal.visible


func _fabrik_im_feld() -> bool:
	var f := _f()
	if f == null:
		return false
	for ring: String in f.felder:
		for z: Vector2i in spiel.fabriken:
			if not spiel.karte.paar.has(z) and BrakkFortschritt.im_feld(z, f.felder[ring] as Vector2i):
				return true
	return false


func _neueste_fabrik() -> Vector2i:
	var z := Karte.KEINE
	for c: Vector2i in spiel.fabriken:
		if not spiel.karte.paar.has(c):
			z = c
	return z


# ------------------------------------------------------------------ Die Schritte

func _baue_schritte() -> Array:
	var p: Node = spiel
	return [
		# --- Einstieg
		{"text": "Willkommen auf dem Übungsgelände. Hier kann nichts schiefgehen: Die Basis hält, du fällst nicht, Budget ist genug da. [Enter] bringt dich weiter, [Rücktaste] überspringt eine Aufgabe, zweimal [Entf] beendet das Tutorial."},
		# --- Parkour
		{"text": "Erst die Beine. W A S D läuft, mit der Maus schaust du dich um. Lauf zur Lichtmarke – dort beginnt der Parkour.",
			"hinweis": "W A S D · Maus",
			"ort": func(): return _ort(_platz),
			"fertig": func(): return _brakk_zelle() == _platz or p.kommandant.position.distance_to(p.karte.mitte(_platz)) < Werte.ZELLE * 0.8},
		{"text": "Leertaste springt. Spring einmal.",
			"hinweis": "Leertaste",
			"fertig": func(): return p.ego != null and p.ego.hoehe > p.ego._boden() + 0.3},
		{"text": "In der Luft trägt dich ein zweites Mal Leertaste weiter – eine Lichtplattform erscheint unter deinen Füßen. Mach einen Doppelsprung.",
			"hinweis": "Leertaste · in der Luft noch einmal",
			"start": func(): _merk["n"] = _zaehler("spruenge"),
			"fertig": func(): return _zaehler("spruenge") > int(_merk.get("n", 0))},
		{"text": "Shift ist der Tumble: eine schnelle Rolle in Laufrichtung. Während der Rolle gehen Schüsse durch dich hindurch, und der erste Schuss danach ist verstärkt. Roll einmal.",
			"hinweis": "Shift · am besten mit A oder D",
			"start": func(): _merk["n"] = _zaehler("rollen"),
			"fertig": func(): return _zaehler("rollen") > int(_merk.get("n", 0))},
		{"text": "Vor dir steht eine Mauer. Schau sie an und drück E: Die Lichttreppe baut sich auf, Brakk steigt hinauf. Oben siehst du über die Wälle.",
			"hinweis": "E · Blick auf die Mauer (bis 5 Felder)",
			"ort": func(): return _ort(_wall_a[1] if _wall_a.size() > 1 else Karte.KEINE, true),
			"fertig": func(): return _auf(_wall_a) or _auf(_wall_b)},
		{"text": "Dahinter liegt eine zweite Mauer. Steh oben, schau zu ihr hinüber und drück wieder E: Eine Lichtbrücke spannt sich über die Lücke.",
			"hinweis": "auf der Mauer: E · Blick zur nächsten Mauer",
			"ort": func(): return _ort(_wall_b[1] if _wall_b.size() > 1 else Karte.KEINE, true),
			"fertig": func(): return _auf(_wall_b)},
		{"text": "Hinunter geht es genauso: auf der Mauer zum Rand schauen, E – die Treppe führt nach unten. (Doppelsprung von der Mauer springt dich hinunter, mit Druckwelle.)",
			"hinweis": "E · oder Leertaste zweimal",
			"fertig": func(): return not _brakk_oben()},
		{"text": "Q wirft den Lichtanker – auf eine Mauerkrone oder den Boden, bis 10 Felder weit. Er bleibt hängen: Ein zweites Q zieht dich heran, Leertaste schwingt dich am Seil. Wirf den Anker.",
			"hinweis": "Q · auf eine Mauerkrone zielen",
			"ort": func(): return _ort(_wall_a[1] if _wall_a.size() > 1 else Karte.KEINE, true),
			"start": func(): _merk["n"] = _zaehler("anker"),
			"fertig": func(): return _zaehler("anker") > int(_merk.get("n", 0))},
		# --- Schießstand
		{"text": "Schießstand. Drei Zielscheiben stehen bereit. Linksklick schießt – zwei Pistolen im Wechsel. Jede wird heiß; überhitzt eine, schießt kurz nur die andere. Kurze Salven halten dich im Feuer.",
			"hinweis": func(): return "Linksklick · Ziele: %d übrig" % _ziele_uebrig(),
			"start": func(): _stelle_ziele("hund", 3),
			"ort": func(): return _ziel_ort(),
			"fertig": func(): return _ziele_uebrig() == 0},
		{"text": "Rechtsklick halten lädt den Ladestrahl, loslassen feuert ihn: ein starker Strahl durch alles in einer Linie. Gut gegen dicke Brocken.",
			"hinweis": "Rechtsklick halten, loslassen",
			"start": func():
				_merk["n"] = _zaehler("lanzen")
				_stelle_ziele("schild", 1),
			"ort": func(): return _ziel_ort(),
			"fertig": func(): return _zaehler("lanzen") > int(_merk.get("n", 0))},
		{"text": "X zielt mit der Lichtsäule – eine Marke folgt dem Fadenkreuz –, Linksklick lässt sie einschlagen. Ideal gegen Gruppen. Triff die Gruppe.",
			"hinweis": "X · zielen · Linksklick",
			"start": func():
				_merk["n"] = _zaehler("saeulen")
				_stelle_ziele("hund", 4, true),
			"ort": func(): return _ziel_ort(),
			"fertig": func(): return _zaehler("saeulen") > int(_merk.get("n", 0))},
		{"text": "V ist die Zeitlupe: Alles um dich wird langsam, nur du nicht. Was sie zusätzlich tut, hängt an deinem aktiven Ring. Probier sie aus.",
			"hinweis": "V",
			"start": func(): _merk["n"] = _zaehler("zeitlupen"),
			"fertig": func(): return _zaehler("zeitlupen") > int(_merk.get("n", 0))},
		{"text": "R ist deine Ulti, die Klonmaschine. Wer hindurchgeht, wird einmal geklont – deine Truppen, aber auch Gegner. Sie lädt sich über eigene Kills auf; hier ist sie schon voll. Stell sie auf.",
			"hinweis": "R · Blick auf ein freies Feld",
			"start": func():
				var f := _f()
				if f != null:
					f.ulti_ladung = BrakkFortschritt.ULTI_KILLS
					f.ulti_ab_welle = 0
				p.kommandant.klon_genutzt = false,
			"fertig": func(): return p.klonmaschine != null},
		# --- Bauen
		{"text": "Bauen geht auch aus Brakks Augen. Links steht die Bauliste mit den Tasten 1 bis 7. Du baust, wohin du schaust – höchstens 5 Felder weit, also geh nah heran. Jede Runde gibt es 5 Erdwälle gratis.",
			},
		{"text": "Drück 2 für den Erdwall und setz 3 Wälle mit Linksklick. Wo es nicht geht – zu weit, in der Zone der Myriaden links, auf Basis oder Checkpoint –, sagt dir eine Meldung warum. Rechtsklick legt das Werkzeug weg.",
			"hinweis": func(): return "2 · Linksklick – Erdwälle: %d / 3" % mini(_anzahl_waelle() - int(_merk.get("w0", 0)), 3),
			"start": func(): _merk["w0"] = _anzahl_waelle(),
			"fertig": func(): return _anzahl_waelle() >= int(_merk.get("w0", 0)) + 3},
		{"text": "Erdwälle lenken den Weg der Myriaden – die gepunktete Linie zeigt ihn. Lange Umwege halten sie länger unter Beschuss. Auf einen Wall setzt du mit 3 eine Stellung; eine Stellung je Runde ist gratis. Bau eine.",
			"hinweis": "3 · Linksklick auf einen Erdwall",
			"start": func(): _merk["n"] = _anzahl_ausbau(Karte.STELLUNG),
			"fertig": func(): return _anzahl_ausbau(Karte.STELLUNG) > int(_merk.get("n", 0))},
		{"text": "Jetzt eine Fabrik: 1, dann auf ein freies Feld. Im Brakk-Mode ist sie anders: Jede weitere kostet nur 10 % mehr (sonst 25 %), und du stellst sie nicht im Menü ein – welche Truppe sie baut, bestimmen gleich deine Ringe.",
			"hinweis": "1 · Linksklick auf ein freies Feld",
			"start": func(): _merk["n"] = _anzahl_fabriken(),
			"fertig": func(): return _anzahl_fabriken() > int(_merk.get("n", 0))},
		{"text": "Falsch gebaut? Mit Z nimmst du das zuletzt gesetzte Bauwerk dieser Bauphase zurück, mit vollem Geld. Bau eine Fabrik (1) und nimm sie mit Z zurück. Älteres baust du ab: Gebäude anschauen, Entf halten (oder F, dann „Abbauen“) – nur in der Bauphase.",
			"hinweis": "1 · Linksklick, dann Z",
			"start": func():
				_merk["n"] = _anzahl_fabriken()
				_merk["hoch"] = false,
			"fertig": func():
				if _anzahl_fabriken() > int(_merk.get("n", 0)):
					_merk["hoch"] = true
				return bool(_merk.get("hoch", false)) and _anzahl_fabriken() <= int(_merk.get("n", 0))},
		{"text": "Türme, Batterien und Schildgeneratoren baust du mit F aus: anschauen, F, das gewohnte Menü öffnet sich. Bei Fabriken zeigt F nur „Abbauen“ – keine Fabrik-Ausbauten im Brakk-Mode, Stufe 1 gibt dort +20 % Leben statt einer dritten Truppe.",
			},
		# --- Ringe
		{"text": "Deine Ringe kaufst du am Lichtterminal der Basis. Geh zur Basis und drück dort F – das geht nur in der Bauphase.",
			"hinweis": "zur Basis laufen · F",
			"ort": func(): return _ort(p.karte.basis),
			"fertig": func(): return _terminal_offen()},
		{"text": "Links deine Finger, rechts alle Ringe. Ein Klick kauft einen Ring; ist er schon angesteckt, baut ein Klick ihn auf Stufe 2 und 3 aus. Kauf zwei Ringe – im echten Spiel kommt ein neuer Finger erst mit Brakks Stufe.",
			"hinweis": func():
				var f := _f()
				return "Klick auf einen Ring · Ringe: %d / 2" % (f.ringe.size() if f != null else 0),
			"fertig": func(): return _f() != null and _f().ringe.size() >= 2},
		{"text": "Gut. Schließ das Terminal mit F.",
			"hinweis": "F",
			"fertig": func(): return not _terminal_offen()},
		{"text": "Alle getragenen Ringe wirken zugleich auf deine Pistolen, jeder auf seiner Stufe. Mit dem Mausrad wählst du den aktiven Ring – er leuchtet an der linken Hand und bestimmt, was Lichtsäule und Zeitlupe tun. Dreh am Mausrad.",
			"hinweis": "Mausrad",
			"start": func(): _merk["n"] = _f().gewaehlt if _f() != null else 0,
			"fertig": func(): return _f() != null and _f().gewaehlt != int(_merk.get("n", 0))},
		{"text": "Schieß mit deinen Ringen auf die Zielscheiben – achte auf die Treffer: Durchschlag, Brand, Sprünge oder Markierung, je nachdem, was du trägst.",
			"hinweis": func(): return "Linksklick · Ziele: %d übrig" % _ziele_uebrig(),
			"start": func(): _stelle_ziele("hund", 3),
			"ort": func(): return _ziel_ort(),
			"fertig": func(): return _ziele_uebrig() == 0},
		{"text": "Taste C wirft das Ringfeld des aktiven Rings: ein 2×2-Feld. Jede Fabrik darin baut die Truppe dieses Rings, auf seiner Stufe. Schau auf deine Fabrik, C zielt, Linksklick oder nochmal C setzt. Nur in der Bauphase.",
			"hinweis": "C · auf die Fabrik zielen · Linksklick",
			"ort": func(): return _ort(_neueste_fabrik()),
			"fertig": func(): return _fabrik_im_feld()},
		{"text": "Die Fabrik baut jetzt die Truppe deines Rings. Ringstufe 1 spezialisiert sie, Stufe 2 bringt ein Wertepaket, Stufe 3 die Fähigkeit des Rings. Im Kampf liegen die Felder fest."},
		# --- Probewelle und Abschluss
		{"text": "Zeit für eine Probewelle. Im echten Brakk-Mode kommt die Welle nach 45 Sekunden von selbst; Enter holt sie früher. Starte sie jetzt mit Enter – hier kann nichts passieren.",
			"hinweis": "Enter · Welle",
			"start": func(): _ziele_weg(),
			"fertig": func(): return p.phase == BAU and p.welle >= 2, "welle": true},
		{"text": "Das war's. Im echten Einsatz wird Brakk mit Erfahrung stärker: Tumble und Doppelsprung ab Stufe 2, Anker ab 3, Ladestrahl ab 4, Lichtsäule ab 6, Klonmaschine ab 7, Zeitlupe ab 8. Fällst du, stehst du nach 10 Sekunden an der Basis wieder auf. Rogue · Befehl 24 hat eigene Regeln – dort bist du allein. Viel Erfolg, Brakk. Sonde 7 Ende."},
	]
