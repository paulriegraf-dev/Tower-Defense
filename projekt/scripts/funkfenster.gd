class_name Funkfenster
extends CanvasLayer
## Phantom-Einführung (23.11.): Sonde 7 meldet sich im Hologramm-Funkfenster mit kurzen Anstößen (höchstens zwei Sätze),
## optional mit Ring auf einem Ziel (Bildschirmkoordinaten 1280×720) und Warten auf einen Handgriff.
## Schritte: [{text, ziel (Callable -> Rect2), fertig (Callable -> bool), hinweis, start (Callable)}].
## Ein Schritt mit "fertig" geht von allein weiter, „Weiter“ geht immer. „Später“ schließt alles (Aufrufer merkt sich das).
## Optik wie das Tutorial (scripts/tutorial.gd), aber ohne Bindung ans Spiel – läuft im Startmenü wie in der Partie.

const HOLO := Color("6ee6ff")
const HOLO_TEXT := Color("c8f4ff")
const GRUND := Color(0.03, 0.10, 0.16, 0.92)
const SONDE := "res://assets/sprites/tutorial/sonde7.png"
const Stil := preload("res://scripts/ui/ui_stil.gd")
const TIPP_TEMPO := 60.0
const LICHTER := [[35, 40, 6, Color("6cecfe")], [49, 50, 6, Color("ff4a5e")], [18, 43, 4, Color("ff4a5e")]]

signal fertig_alle
signal geschlossen

var schritte: Array = []
var unten := 604.0                   # Unterkante des Fensters (über der Konsole)
var _index := -1
var _zeit := 0.0
var _gezeigt := 0.0
var _aus := false

var _wurzel: Control
var _zeichner: Control
var _box: PanelContainer
var _bild: TextureRect
var _lichter: Control
var _text: Label
var _hinweis: Label
var _thema: Label
var _btn_weiter: Button
var _btn_spaeter: Button


static func zeige(eltern: Node, neue_schritte: Array, thema: String = "PHANTOM-MODUS") -> Funkfenster:
	var f := Funkfenster.new()
	f.schritte = neue_schritte
	eltern.add_child(f)
	f._thema.text = thema
	f._naechster()
	return f


func _ready() -> void:
	layer = 31
	_wurzel = Control.new()
	_wurzel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_wurzel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_wurzel)
	_zeichner = Control.new()
	_zeichner.set_anchors_preset(Control.PRESET_FULL_RECT)
	_zeichner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_zeichner.draw.connect(_zeichne_ziel)
	_wurzel.add_child(_zeichner)
	_hinweis = Label.new()
	_schrift(_hinweis, 18)
	_hinweis.add_theme_color_override("font_color", Color("ffe9a8"))
	_hinweis.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_hinweis.add_theme_constant_override("outline_size", 4)
	_wurzel.add_child(_hinweis)

	_box = PanelContainer.new()
	var stil := StyleBoxFlat.new()
	stil.bg_color = GRUND
	stil.border_color = HOLO
	stil.set_border_width_all(2)
	stil.set_corner_radius_all(6)
	stil.set_content_margin_all(10)
	stil.shadow_color = Color(0.43, 0.9, 1.0, 0.35)
	stil.shadow_size = 8
	_box.add_theme_stylebox_override("panel", stil)
	_box.custom_minimum_size = Vector2(620, 0)
	_box.mouse_filter = Control.MOUSE_FILTER_STOP
	_box.gui_input.connect(_box_klick)
	_wurzel.add_child(_box)
	var reihe := HBoxContainer.new()
	reihe.add_theme_constant_override("separation", 12)
	_box.add_child(reihe)
	_bild = TextureRect.new()
	_bild.texture = load(SONDE)
	_bild.custom_minimum_size = Vector2(80, 80)
	_bild.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_bild.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_bild.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_bild.mouse_filter = Control.MOUSE_FILTER_IGNORE
	reihe.add_child(_bild)
	_lichter = Control.new()
	_lichter.set_anchors_preset(Control.PRESET_FULL_RECT)
	_lichter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lichter.draw.connect(_zeichne_lichter)
	_bild.add_child(_lichter)
	var rechts := VBoxContainer.new()
	rechts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rechts.add_theme_constant_override("separation", 4)
	reihe.add_child(rechts)
	_thema = Label.new()
	_schrift(_thema, 16)
	_thema.add_theme_color_override("font_color", Color("9be9ff"))
	rechts.add_child(_thema)
	_text = Label.new()
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size = Vector2(480, 54)
	_schrift(_text, 20)
	_text.add_theme_color_override("font_color", HOLO_TEXT)
	rechts.add_child(_text)
	var knoepfe := HBoxContainer.new()
	knoepfe.add_theme_constant_override("separation", 8)
	rechts.add_child(knoepfe)
	var luft := Control.new()
	luft.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	knoepfe.add_child(luft)
	_btn_spaeter = _knopf(knoepfe, "Später", false)
	_btn_spaeter.pressed.connect(schliessen)
	_btn_weiter = _knopf(knoepfe, "Weiter ▸", true)
	_btn_weiter.pressed.connect(_naechster)


func _schrift(c: Control, groesse: int) -> void:
	c.add_theme_font_override("font", Stil.schrift_fuer(1))
	c.add_theme_font_size_override("font_size", groesse)


func _knopf(eltern: Control, text: String, hell: bool) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	_schrift(b, 18)
	var s := StyleBoxFlat.new()
	s.bg_color = HOLO if hell else Color(0.43, 0.9, 1.0, 0.08)
	s.border_color = HOLO
	s.set_border_width_all(1)
	s.set_corner_radius_all(4)
	s.set_content_margin_all(5)
	s.content_margin_left = 10
	s.content_margin_right = 10
	b.add_theme_stylebox_override("normal", s)
	var h := s.duplicate() as StyleBoxFlat
	h.bg_color = HOLO.lightened(0.2) if hell else Color(0.43, 0.9, 1.0, 0.22)
	b.add_theme_stylebox_override("hover", h)
	b.add_theme_stylebox_override("pressed", h)
	b.add_theme_color_override("font_color", Color("08130f") if hell else HOLO_TEXT)
	b.add_theme_color_override("font_hover_color", Color("08130f") if hell else Color.WHITE)
	eltern.add_child(b)
	return b


func _naechster() -> void:
	if _aus:
		return
	if _index >= schritte.size() - 1:
		fertig_alle.emit()
		schliessen()
		return
	_index += 1
	var s: Dictionary = schritte[_index]
	if s.has("start"):
		(s["start"] as Callable).call()
	_text.text = str(s["text"])
	_text.visible_characters = 0
	_gezeigt = 0.0
	var letzter := _index >= schritte.size() - 1
	_btn_weiter.text = "Verstanden ✓" if letzter else "Weiter ▸"
	_btn_spaeter.visible = not letzter
	_thema.text = _thema.text.get_slice("  ·  ", 0) + ("  ·  %d/%d" % [_index + 1, schritte.size()] if schritte.size() > 1 else "")


func schliessen() -> void:
	if _aus:
		return
	_aus = true
	geschlossen.emit()
	queue_free()


func _box_klick(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		_gezeigt = INF


func _process(delta: float) -> void:
	if _aus:
		return
	var echt := delta / maxf(Engine.time_scale, 0.01)
	_zeit += echt
	if _gezeigt < INF:
		_gezeigt += TIPP_TEMPO * echt
	_text.visible_characters = -1 if _gezeigt >= _text.text.length() else int(_gezeigt)
	var s: Dictionary = schritte[_index]
	if s.has("fertig") and (s["fertig"] as Callable).call():
		_naechster()
		return
	var h: Variant = s.get("hinweis", "")
	_hinweis.text = (h as Callable).call() if h is Callable else str(h)
	_lege_box()
	_zeichner.queue_redraw()
	_lichter.queue_redraw()
	_bild.modulate = Color(0.75, 0.95, 1.15, 0.82 if fmod(_zeit, 3.2) < 3.05 else 0.6)


func _ziel_rect() -> Rect2:
	var s: Dictionary = schritte[_index]
	if not s.has("ziel"):
		return Rect2()
	var r: Variant = (s["ziel"] as Callable).call()
	return r if r is Rect2 else Rect2()


func _lege_box() -> void:
	_box.reset_size()
	var g := _box.size
	var y := unten - g.y
	var ziel := _ziel_rect()
	if ziel.size != Vector2.ZERO and ziel.end.y > y - 30.0 and ziel.position.y > 200.0:
		y = 92.0   # Ziel liegt unten: Fenster nach oben
	_box.position = Vector2((1280.0 - g.x) / 2.0, y)
	_hinweis.position = _box.position + (Vector2(12, g.y + 4) if y < 100.0 else Vector2(12, -24))
	_hinweis.visible = _hinweis.text != ""


func _zeichne_ziel() -> void:
	var r := _ziel_rect()
	if r.size == Vector2.ZERO:
		return
	var puls := 0.5 + 0.5 * sin(_zeit * 5.0)
	_zeichner.draw_rect(r.grow(4.0 + 4.0 * puls), Color(HOLO, 0.25 + 0.35 * puls), false, 3.0)
	# Pfeil über dem Ziel
	var m := Vector2(r.get_center().x, r.position.y - 10.0 - 6.0 * puls)
	_zeichner.draw_colored_polygon(PackedVector2Array([m, m + Vector2(-9, -12), m + Vector2(9, -12)]), Color(HOLO, 0.9))


func _zeichne_lichter() -> void:
	var k := _bild.size.x / 96.0
	for l: Array in LICHTER:
		var an := 0.55 + 0.45 * sin(_zeit * 6.0 + float(l[0]))
		_lichter.draw_circle(Vector2(float(l[0]), float(l[1])) * k, float(l[2]) * k * 0.5, Color(l[3], 0.55 * an))
