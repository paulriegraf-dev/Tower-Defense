class_name Kamera2D
extends Camera2D
## Kamera der 2D-Ansichten (Klassisch und Neu) für die große Karte (16.11.).
## Linke Maustaste ziehen (ohne Bauwerkzeug), mittlere Maustaste ziehen oder Pfeiltasten schwenken;
## A/D/W/S schwenken, solange Brakk nicht angeklickt ist. Mausrad oder Zoom-Regler rechts: von ganzer Karte bis 1,5-fach; Pos1 = ganze Karte.
## Ganz herausgezoomt passt die Karte ins Bild, dann steht die Kamera still wie bisher.

const BILD := Vector2(1280, 720)
const KARTE_SICHT := Vector2(1280, 640)   # zwischen oberer und unterer Leiste

var spiel: Node
var _ziel_zoom := 1.0
const NAH := 1.5
var _links_start := Vector2.INF
var _links_zieht := false
var _zieht := false


func _ready() -> void:
	anchor_mode = Camera2D.ANCHOR_MODE_DRAG_CENTER
	position = BILD / 2.0
	_ziel_zoom = _ganz()
	zoom = Vector2.ONE * _ziel_zoom
	_begrenzen()
	make_current()


## Zoom, bei dem die ganze Karte zwischen die Leisten passt (höchstens 1).
## Zoom-Regler: 0 = ganze Karte, 1 = NAH.
func zoom_anteil() -> float:
	return clampf((_ziel_zoom - _ganz()) / maxf(0.001, NAH - _ganz()), 0.0, 1.0)


func setze_zoom_anteil(a: float) -> void:
	_ziel_zoom = lerpf(_ganz(), NAH, a)


func _ganz() -> float:
	var w := float(Werte.SPALTEN * Werte.ZELLE)
	var h := float(Werte.ZEILEN * Werte.ZELLE)
	return minf(1.0, minf(KARTE_SICHT.x / w, KARTE_SICHT.y / h))


func _begrenzen() -> void:
	var w := float(Werte.SPALTEN * Werte.ZELLE)
	var h := float(Werte.ZEILEN * Werte.ZELLE)
	var z := zoom.x
	var halb := KARTE_SICHT / 2.0 / z
	# Mitte der Kartensicht liegt in der Bildmitte (beide Leisten sind gleich hoch)
	if w <= KARTE_SICHT.x / z + 0.5:
		position.x = w / 2.0
	else:
		position.x = clampf(position.x, halb.x, w - halb.x)
	var oben := float(Werte.KARTE_OBEN)
	if h <= KARTE_SICHT.y / z + 0.5:
		position.y = oben + h / 2.0
	else:
		position.y = clampf(position.y, oben + halb.y, oben + h - halb.y)


func _process(delta: float) -> void:
	# Erschütterung bei Einschlägen (16.11.)
	var w: float = spiel.effekte.wackeln if spiel != null and is_instance_valid(spiel) else 0.0
	offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * w if w > 0.0 else Vector2.ZERO
	var schwenk := Vector2.ZERO
	if spiel.wasd_kamera():
		if Input.is_physical_key_pressed(KEY_A):
			schwenk.x -= 1.0
		if Input.is_physical_key_pressed(KEY_D):
			schwenk.x += 1.0
		if Input.is_physical_key_pressed(KEY_W):
			schwenk.y -= 1.0
		if Input.is_physical_key_pressed(KEY_S):
			schwenk.y += 1.0
	schwenk = schwenk.limit_length(1.0)
	if Input.is_key_pressed(KEY_LEFT):
		schwenk.x -= 1.0
	if Input.is_key_pressed(KEY_RIGHT):
		schwenk.x += 1.0
	if Input.is_key_pressed(KEY_UP):
		schwenk.y -= 1.0
	if Input.is_key_pressed(KEY_DOWN):
		schwenk.y += 1.0
	position += schwenk * 700.0 * delta / zoom.x
	if absf(zoom.x - _ziel_zoom) > 0.001:
		var z := lerpf(zoom.x, _ziel_zoom, minf(1.0, delta * 10.0))
		if absf(z - _ziel_zoom) < 0.004:
			z = _ziel_zoom
		zoom = Vector2.ONE * z
	_begrenzen()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_links_start = (event as InputEventMouseButton).position
			_links_zieht = false
		else:
			_links_start = Vector2.INF
			if _links_zieht:
				_links_zieht = false
				get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseMotion and (event as InputEventMouseMotion).button_mask & MOUSE_BUTTON_MASK_LEFT and _links_start != Vector2.INF:
		var frei: bool = spiel.werkzeug == Karte.FREI and spiel._zieh_von == Karte.KEINE
		if frei and not _links_zieht and (event as InputEventMouseMotion).position.distance_to(_links_start) > 6.0:
			_links_zieht = true
		if _links_zieht:
			position -= (event as InputEventMouseMotion).relative / zoom.x
			get_viewport().set_input_as_handled()
			return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and (mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN):
			# zur Maus hin zoomen: der Weltpunkt unter der Maus bleibt stehen
			var schritt := (0.12 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else -0.12) * clampf(mb.factor if mb.factor > 0.0 else 1.0, 0.15, 1.0)   # 16.11.: weniger empfindlich
			var vorher := get_global_mouse_position()
			setze_zoom_anteil(clampf(zoom_anteil() + schritt, 0.0, 1.0))
			if schritt > 0.0:
				position = position.lerp(vorher, 0.35)   # etwas zur Maus hin
			get_viewport().set_input_as_handled()
		elif mb.button_index == MOUSE_BUTTON_MIDDLE:
			_zieht = mb.pressed
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _zieht:
		position -= (event as InputEventMouseMotion).relative / zoom.x
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).keycode == KEY_HOME:
		_ziel_zoom = _ganz()
		get_viewport().set_input_as_handled()
