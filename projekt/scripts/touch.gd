class_name Touch
extends CanvasLayer
## Handy und Tablet (17.11.): Ein Tipp ist ein Linksklick (Godot macht das selbst), Ziehen mit einem Finger schwenkt
## die Karte (hd_ansicht.gd). Hier kommt dazu:
##  - Lange drücken (0,5 s, ohne zu ziehen) = Rechtsklick: Abreißen, Werkzeug abbrechen, Menüs zurück.
##  - Zwei Finger auseinander/zusammen = Zoomen (wie das Mausrad).
##  - Hochkant gehalten: Hinweis, das Gerät quer zu drehen (das Spiel ist für Querformat gebaut).
## Nur aktiv, wenn das Gerät einen Touchscreen hat.

const LANG_SEK := 0.5
const ZITTERN := 14.0          # so weit darf der Finger beim langen Drücken wandern (Bildpunkte)
const PINCH_SCHRITT := 1.07    # so viel Abstandsänderung ergibt einen Zoomschritt (2D-Ansicht)
const PINCH_STAERKE := 0.3     # HD-Ansicht: Zoomänderung je Verdopplung des Fingerabstands (× ln 2)
const WISCH := 14.0            # ab so viel Bewegung (Bildpunkte) ist ein Tippen ein Wischen
var _zwei_finger := false      # während zwei Finger liegen: nichts bauen, nichts wählen
# Bauen am Handy (17.11.): Mit Werkzeug baut ein Tipp nicht sofort, sondern merkt das Feld vor (Rahmen);
# ein zweiter Tipp auf dasselbe Feld baut. Wischen schwenkt die Karte und baut nie.
var _druck := Vector2.INF
var _gewischt := false
var _vormerk := Vector2i(-999, -999)
var _vormerk_werkzeug := -1
var _durchlassen := false

var _finger := {}              # Index -> Position
var _lang_zeit := -1.0
var _lang_pos := Vector2.ZERO
var _pinch_abstand := 0.0
var _hochkant: Control
# Brakk am Handy (17.11.): Ist er angetippt, erscheinen links ein Steuerkreuz-Joystick und rechts drei Knöpfe (Q, E, R).
const STICK := Vector2(150, 560)
const STICK_R := 90.0
const KNOPF_R := 46.0
const KNOEPFE := [["Q", "Sammeln", Vector2(1150, 290)], ["E", "Klettern", Vector2(1150, 395)], ["R", "Klonen", Vector2(1150, 500)]]
var spiel: Node
var _brakk: Control
var _stick_finger := -1
var _stick_aus := Vector2.ZERO        # Auslenkung -1..1
var _blick := Vector2.RIGHT           # letzte Richtung (Ziel für Losschlagen, Klettern, Klonmaschine)


static func noetig() -> bool:
	return DisplayServer.is_touchscreen_available() or OS.has_feature("web_ios") or OS.has_feature("web_android")


func _ready() -> void:
	layer = 120
	process_mode = Node.PROCESS_MODE_ALWAYS
	spiel = get_parent()
	_vollbild_hinweis.call_deferred()
	_brakk = Control.new()
	_brakk.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_brakk.size = Vector2(1280, 720)
	_brakk.draw.connect(_male_brakk)
	add_child(_brakk)
	_hochkant = Control.new()
	_hochkant.mouse_filter = Control.MOUSE_FILTER_STOP
	_hochkant.visible = false
	_hochkant.draw.connect(_male_hochkant)
	add_child(_hochkant)


func _brakk_an() -> bool:
	return spiel != null and spiel.has_method("kommandant_gewaehlt") and spiel.kommandant_gewaehlt() and spiel.phase != 2


func _knopf_bei(p: Vector2) -> int:
	for i in KNOEPFE.size():
		if p.distance_to(KNOEPFE[i][2]) <= KNOPF_R + 10.0:
			return i
	return -1


func _in_steuerung(p: Vector2) -> bool:
	return p.distance_to(STICK) <= STICK_R + 40.0 or _knopf_bei(p) >= 0


func _input(event: InputEvent) -> void:
	# Brakk-Steuerung: Berührungen auf Joystick und Knöpfen gehen nicht ans Spiel (auch nicht als Klick)
	if _brakk_an():
		if event is InputEventScreenTouch:
			var t := event as InputEventScreenTouch
			if t.pressed and t.position.distance_to(STICK) <= STICK_R + 40.0:
				_stick_finger = t.index
				_setze_stick(t.position)
				get_viewport().set_input_as_handled()
				return
			if not t.pressed and t.index == _stick_finger:
				_stick_finger = -1
				_setze_stick(STICK)
				get_viewport().set_input_as_handled()
				return
			if t.pressed and _knopf_bei(t.position) >= 0:
				_druecke(_knopf_bei(t.position))
				get_viewport().set_input_as_handled()
				return
		elif event is InputEventScreenDrag and (event as InputEventScreenDrag).index == _stick_finger:
			_setze_stick((event as InputEventScreenDrag).position)
			get_viewport().set_input_as_handled()
			return
		elif (event is InputEventMouseButton or event is InputEventMouseMotion) and event.device == InputEvent.DEVICE_ID_EMULATION:
			if _stick_finger >= 0 or _in_steuerung(event.position):
				get_viewport().set_input_as_handled()   # der nachgemachte Mausklick würde Brakk sonst abwählen
				return
	elif _stick_finger >= 0:
		_stick_finger = -1
		_setze_stick(STICK)
	if _zwei_finger and (event is InputEventMouseButton or event is InputEventMouseMotion) and event.device == InputEvent.DEVICE_ID_EMULATION:
		get_viewport().set_input_as_handled()   # beim Zoomen mit zwei Fingern nicht zugleich schwenken oder klicken
		return
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed:
			_finger[t.index] = t.position
		else:
			_finger.erase(t.index)
			if _finger.is_empty():
				_zwei_finger = false
		if _finger.size() == 1 and t.pressed:
			_lang_zeit = 0.0
			_lang_pos = t.position
		else:
			_lang_zeit = -1.0
		if _finger.size() == 2:
			var p: Array = _finger.values()
			_pinch_abstand = (p[0] as Vector2).distance_to(p[1])
			_zwei_finger = true
			_druck = Vector2.INF   # der erste Finger war kein Tipp
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		_finger[d.index] = d.position
		if _lang_zeit >= 0.0 and d.position.distance_to(_lang_pos) > ZITTERN:
			_lang_zeit = -1.0
		if _finger.size() == 2 and _pinch_abstand > 1.0:
			var p: Array = _finger.values()
			var jetzt := (p[0] as Vector2).distance_to(p[1])
			var hd = spiel.get("hd") if spiel != null else null
			if hd != null:
				# 17.11.: zoomt mittig (die Kamera bleibt, wo sie ist) und gleichmäßig mit dem Fingerabstand
				hd._tz = clampf(hd._tz + log(jetzt / _pinch_abstand) * PINCH_STAERKE, hd._z_min, 1.0)
				_pinch_abstand = jetzt
			else:
				var mitte := get_viewport().get_visible_rect().size / 2.0
				while jetzt > _pinch_abstand * PINCH_SCHRITT:
					_rad(MOUSE_BUTTON_WHEEL_UP, mitte)
					_pinch_abstand *= PINCH_SCHRITT
				while jetzt < _pinch_abstand / PINCH_SCHRITT:
					_rad(MOUSE_BUTTON_WHEEL_DOWN, mitte)
					_pinch_abstand /= PINCH_SCHRITT
			_zwei_finger = true


func _process(delta: float) -> void:
	var echt := delta / maxf(Engine.time_scale, 0.01)
	if _lang_zeit >= 0.0:
		_lang_zeit += echt
		if _lang_zeit >= LANG_SEK:
			_lang_zeit = -1.0
			_klick(MOUSE_BUTTON_RIGHT, _lang_pos)
	_brakk.queue_redraw()
	var g := get_viewport().get_visible_rect().size
	var fenster := DisplayServer.window_get_size()
	_hochkant.visible = fenster.y > fenster.x
	_hochkant.size = g
	if _hochkant.visible:
		_hochkant.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if spiel == null or not (event is InputEventMouseButton or event is InputEventMouseMotion):
		return
	if event.device != InputEvent.DEVICE_ID_EMULATION:
		return   # echte Maus oder unser eigener Klick (siehe unten): normal weiter
	if _zwei_finger:
		get_viewport().set_input_as_handled()
		return
	var werkzeug: int = spiel.werkzeug
	if werkzeug == Karte.FREI or spiel.phase == 2:
		_vormerk = Vector2i(-999, -999)
		return
	if werkzeug != _vormerk_werkzeug:
		_vormerk_werkzeug = werkzeug
		_vormerk = Vector2i(-999, -999)
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		get_viewport().set_input_as_handled()
		if mb.pressed:
			_druck = mb.position
			_gewischt = false
			return
		if _druck == Vector2.INF:
			return
		_druck = Vector2.INF
		if _gewischt:
			return
		var z: Vector2i = spiel.karte.zelle_bei(spiel.maus_welt())
		if z == _vormerk:
			_vormerk = Vector2i(-999, -999)
			for gedrueckt in [true, false]:   # zweiter Tipp: jetzt wirklich bauen
				var e := InputEventMouseButton.new()
				e.button_index = MOUSE_BUTTON_LEFT
				e.pressed = gedrueckt
				e.position = _ins_fenster(mb.position)
				e.global_position = e.position
				e.device = 0
				Input.parse_input_event(e)
		else:
			_vormerk = z
	elif event is InputEventMouseMotion:
		get_viewport().set_input_as_handled()   # mit Werkzeug wird am Handy nie über Felder gemalt
		var mm := event as InputEventMouseMotion
		if _druck != Vector2.INF and mm.button_mask & MOUSE_BUTTON_MASK_LEFT:
			if not _gewischt and mm.position.distance_to(_druck) > WISCH:
				_gewischt = true
			if _gewischt and spiel.get("hd") != null:
				spiel.hd._schwenke(mm.relative)


func _male_vormerk() -> void:
	if spiel == null or _vormerk.x < -100 or spiel.werkzeug == Karte.FREI:
		return
	var k = spiel.karte
	var m: Vector2 = spiel.welt_zu_bild(k.mitte(_vormerk))
	var n: Vector2 = spiel.welt_zu_bild(k.mitte(_vormerk) + Vector2(Werte.ZELLE, 0))
	var h := maxf(10.0, absf(n.x - m.x) * 0.5)
	var puls := 0.6 + 0.4 * sin(Time.get_ticks_msec() / 150.0)
	_brakk.draw_rect(Rect2(m - Vector2(h, h * 0.7), Vector2(h * 2.0, h * 1.4)), Color(1.0, 0.9, 0.4, 0.25 * puls))
	_brakk.draw_rect(Rect2(m - Vector2(h, h * 0.7), Vector2(h * 2.0, h * 1.4)), Color(1.0, 0.9, 0.4, puls), false, 3.0)
	_brakk.draw_string(ThemeDB.fallback_font, m + Vector2(-120, -h - 10), "Nochmal tippen = bauen", HORIZONTAL_ALIGNMENT_CENTER, 240, 20, Color.WHITE)


func _setze_stick(p: Vector2) -> void:
	var d := (p - STICK) / STICK_R
	if d.length() > 1.0:
		d = d.normalized()
	_stick_aus = d if d.length() > 0.2 else Vector2.ZERO
	if _stick_aus != Vector2.ZERO:
		_blick = _stick_aus.normalized()
	var k = spiel.get("kommandant") if spiel != null else null
	if k != null and is_instance_valid(k):
		k.touch_richtung = _stick_aus


func _druecke(i: int) -> void:
	var k = spiel.kommandant
	if k == null or not is_instance_valid(k):
		return
	var ziel: Vector2 = k.position + _blick * Werte.ZELLE * 3.0
	match KNOEPFE[i][0]:
		"Q":
			spiel._kommandant_meldung(k.taste_q(ziel))
		"E":
			spiel._kommandant_meldung(k.taste_e(k.position + _blick * Werte.ZELLE))
		"R":
			spiel._kommandant_meldung(spiel.stelle_klonmaschine(spiel.karte.zelle_bei(k.position + _blick * Werte.ZELLE)))


func _male_brakk() -> void:
	_male_vormerk()
	if not _brakk_an():
		return
	var c := _brakk
	c.draw_circle(STICK, STICK_R, Color(0.03, 0.05, 0.08, 0.45))
	c.draw_arc(STICK, STICK_R, 0.0, TAU, 48, Color("7fe0ff"), 3.0)
	c.draw_circle(STICK + _stick_aus * STICK_R * 0.7, 34.0, Color(0.5, 0.88, 1.0, 0.8))
	var schrift := ThemeDB.fallback_font
	c.draw_string(schrift, STICK + Vector2(-STICK_R, -STICK_R - 14), "Brakk", HORIZONTAL_ALIGNMENT_CENTER, STICK_R * 2.0, 22, Color("ffe9a8"))
	for k: Array in KNOEPFE:
		var m: Vector2 = k[2]
		c.draw_circle(m, KNOPF_R, Color(0.03, 0.05, 0.08, 0.6))
		c.draw_arc(m, KNOPF_R, 0.0, TAU, 40, Color("ffd34d"), 3.0)
		c.draw_string(schrift, m + Vector2(-KNOPF_R, 10), k[0], HORIZONTAL_ALIGNMENT_CENTER, KNOPF_R * 2.0, 34, Color.WHITE)
		c.draw_string(schrift, m + Vector2(-KNOPF_R - 30, KNOPF_R + 18), k[1], HORIZONTAL_ALIGNMENT_CENTER, KNOPF_R * 2.0 + 60, 16, Color("d8cfe6"))


## Nachgemachte Klicks gehen über Input.parse_input_event und damit durchs Fenster: Ihre Position muss in
## Fensterpunkten stehen, nicht in Spielpunkten (1280×720). Am Handy ist das Fenster viel größer (echte Bildpunkte),
## sonst landet der Klick weit links oben (Fehler 17.11. abends: Fabrik baute an falscher Stelle).
func _ins_fenster(p: Vector2) -> Vector2:
	return get_viewport().get_final_transform() * p


func _rad(knopf: MouseButton, pos: Vector2) -> void:
	for gedrueckt in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = knopf
		e.pressed = gedrueckt
		e.position = _ins_fenster(pos)
		e.global_position = e.position
		e.factor = 1.0
		Input.parse_input_event(e)


func _klick(knopf: MouseButton, pos: Vector2) -> void:
	for gedrueckt in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = knopf
		e.pressed = gedrueckt
		e.position = _ins_fenster(pos)
		e.global_position = e.position
		Input.parse_input_event(e)


func _male_hochkant() -> void:
	var g := _hochkant.size
	_hochkant.draw_rect(Rect2(Vector2.ZERO, g), Color(0.03, 0.04, 0.06, 0.96))
	var m := g / 2.0
	# Handy-Symbol, das sich ins Querformat dreht
	var t := fmod(Time.get_ticks_msec() / 1000.0, 2.4)
	var winkel := clampf((t - 0.6) / 0.6, 0.0, 1.0) * PI / 2.0
	_hochkant.draw_set_transform(m + Vector2(0, -60), -winkel, Vector2.ONE)
	_hochkant.draw_rect(Rect2(-40, -70, 80, 140), Color("7fe0ff"), false, 6.0)
	_hochkant.draw_rect(Rect2(-12, 52, 24, 6), Color("7fe0ff"))
	_hochkant.draw_set_transform(Vector2.ZERO)
	var schrift := ThemeDB.fallback_font
	_hochkant.draw_string(schrift, Vector2(0, m.y + 70), "Bitte das Gerät quer halten", HORIZONTAL_ALIGNMENT_CENTER, g.x, 64, Color("ffe9a8"))
	_hochkant.draw_string(schrift, Vector2(0, m.y + 150), "Pauls TD Battler ist fürs Querformat gebaut.", HORIZONTAL_ALIGNMENT_CENTER, g.x, 40, Color("a79fb3"))


## 17.11.: Vollbild. Android und iPad gehen beim ersten Tippen von selbst ins Vollbild (Skript in index.html).
## Das iPhone erlaubt das Webseiten nicht – dort geht es nur als Web-App vom Home-Bildschirm; darauf einmal hinweisen.
func _vollbild_hinweis() -> void:
	if not OS.has_feature("web_ios") or spiel == null or not spiel.has_method("melde"):
		return
	var eigenstaendig = JavaScriptBridge.eval("window.navigator.standalone === true || window.matchMedia('(display-mode: standalone)').matches", true)
	if eigenstaendig:
		return
	spiel.melde("Vollbild am iPhone: im Browser auf „Teilen“ → „Zum Home-Bildschirm“, dann von dort starten.", 9.0)
