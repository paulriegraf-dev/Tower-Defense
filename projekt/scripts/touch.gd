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
const PINCH_SCHRITT := 1.07    # so viel Abstandsänderung ergibt einen Zoomschritt

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
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed:
			_finger[t.index] = t.position
		else:
			_finger.erase(t.index)
		if _finger.size() == 1 and t.pressed:
			_lang_zeit = 0.0
			_lang_pos = t.position
		else:
			_lang_zeit = -1.0
		if _finger.size() == 2:
			var p: Array = _finger.values()
			_pinch_abstand = (p[0] as Vector2).distance_to(p[1])
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		_finger[d.index] = d.position
		if _lang_zeit >= 0.0 and d.position.distance_to(_lang_pos) > ZITTERN:
			_lang_zeit = -1.0
		if _finger.size() == 2 and _pinch_abstand > 1.0:
			var p: Array = _finger.values()
			var jetzt := (p[0] as Vector2).distance_to(p[1])
			var mitte := ((p[0] as Vector2) + (p[1] as Vector2)) / 2.0
			while jetzt > _pinch_abstand * PINCH_SCHRITT:
				_rad(MOUSE_BUTTON_WHEEL_UP, mitte)
				_pinch_abstand *= PINCH_SCHRITT
			while jetzt < _pinch_abstand / PINCH_SCHRITT:
				_rad(MOUSE_BUTTON_WHEEL_DOWN, mitte)
				_pinch_abstand /= PINCH_SCHRITT


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


func _rad(knopf: MouseButton, pos: Vector2) -> void:
	for gedrueckt in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = knopf
		e.pressed = gedrueckt
		e.position = pos
		e.global_position = pos
		e.factor = 1.0
		Input.parse_input_event(e)


func _klick(knopf: MouseButton, pos: Vector2) -> void:
	for gedrueckt in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = knopf
		e.pressed = gedrueckt
		e.position = pos
		e.global_position = pos
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
