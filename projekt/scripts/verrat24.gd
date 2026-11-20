class_name Verrat24
extends CanvasLayer
## 20.11. (Paul, Ergänzung Befehl 24): Verrat-Sequenz vor dem Start – Hologramm-Fenster wie im Tutorial (tippender Text,
## Porträt), Steuerung gesperrt, [Esc] überspringt, [Enter]/[Leertaste]/Klick blättert weiter. Was in der Welt passiert
## (Drehen, Anziel-Pose, roter Rand, Schild, Schuss), macht Order24 über das Signal `ereignis`.
## Keine neuen Sprites: Sonde 7 aus dem Tutorial, Brakk als Kachel aus der Bauleiste (assets/neu/ui/bau_brakk.png).

signal ereignis(was: String)
signal fertig

const Stil := preload("res://scripts/ui/ui_stil.gd")
const HOLO := Color("6ee6ff")
const HOLO_TEXT := Color("c8f4ff")
const ROT := Color("ff4a5e")
const GRUND := Color(0.03, 0.10, 0.16, 0.9)
const TIPP_TEMPO := 30.0          # Zeichen je Sekunde
const PAUSE := 2.6                # Sekunden nach dem letzten Zeichen (dazu je Zeichen PAUSE_JE), dann die nächste Zeile
const PAUSE_JE := 0.03            # 20.11. (Paul): Zeit zum Lesen – lange Zeilen bleiben länger stehen
const SONDE := "res://assets/sprites/tutorial/sonde7.png"
const BRAKK := "res://assets/neu/ui/bau_brakk.png"
## Sprecher, Text, Ereignis (wenn die Zeile fertig getippt ist)
const ZEILEN := [
	["SONDE 7 · FUNK", "Kommandant Brakk, der Rat der Repaulblik hat Ihre letzten Einsätze geprüft.", ""],
	["SONDE 7 · FUNK", "Sie haben Befehle verweigert und Truppen des Technoclans für Ihre eigenen Pläne geopfert.", ""],
	["BRAKK", "Ich habe diesen Krieg für euch geführt. Wozu die Ehrengarde vor dem HQ?", ""],
	["SONDE 7 · FUNK", "Der Rat nennt Sie eine Gefahr für den Technoclan. Das Urteil ist gefallen.", ""],
	["SONDE 7 · FUNK", "Befehl 24 bestätigt.", ""],
	["SONDE 7 · FUNK", "Kommandant Brakk …", ""],
	["SONDE 7 · FUNK", "Sie sind entlassen.", "anlegen"],
	["BRAKK", "Ihr Verräter! Für die Repaulblik!!", "verrat"],
	["SONDE 7 · FUNK", "Schild geschlossen. Alle Einheiten: Feuer frei.", "schuss"],
	["", "Überlebe.", "los"],
]

var _index := -1
var _zeichen := 0.0
var _warte := 0.0
var _gemeldet := false
var rot := 0.0                    # 0..1 roter Rand (die Zone leuchtet rot)
var _box: PanelContainer
var _bild: TextureRect
var _name: Label
var _text: Label
var _hinweis: Label
var _rand: Control
var _stil: StyleBoxFlat


func _ready() -> void:
	layer = 31
	process_mode = Node.PROCESS_MODE_ALWAYS
	var wurzel := Control.new()
	wurzel.set_anchors_preset(Control.PRESET_FULL_RECT)
	wurzel.mouse_filter = Control.MOUSE_FILTER_STOP
	wurzel.gui_input.connect(_klick)
	add_child(wurzel)
	_rand = Control.new()
	_rand.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rand.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rand.draw.connect(_male_rand)
	wurzel.add_child(_rand)
	_box = PanelContainer.new()
	_stil = StyleBoxFlat.new()
	_stil.bg_color = GRUND
	_stil.border_color = HOLO
	_stil.set_border_width_all(2)
	_stil.set_corner_radius_all(6)
	_stil.set_content_margin_all(10)
	_stil.shadow_color = Color(0.43, 0.9, 1.0, 0.35)
	_stil.shadow_size = 8
	_box.add_theme_stylebox_override("panel", _stil)
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wurzel.add_child(_box)
	var reihe := HBoxContainer.new()
	reihe.add_theme_constant_override("separation", 12)
	_box.add_child(reihe)
	_bild = TextureRect.new()
	_bild.custom_minimum_size = Vector2(88, 88)
	_bild.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_bild.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_bild.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_bild.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_bild.mouse_filter = Control.MOUSE_FILTER_IGNORE
	reihe.add_child(_bild)
	var rechts := VBoxContainer.new()
	rechts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rechts.add_theme_constant_override("separation", 4)
	reihe.add_child(rechts)
	_name = Label.new()
	_schrift(_name, 17)
	rechts.add_child(_name)
	_text = Label.new()
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size = Vector2(440, 58)
	_schrift(_text, 22)
	_text.add_theme_color_override("font_color", HOLO_TEXT)
	_text.add_theme_color_override("font_shadow_color", Color(0.43, 0.9, 1.0, 0.45))
	_text.add_theme_constant_override("shadow_outline_size", 4)
	rechts.add_child(_text)
	_hinweis = Label.new()
	_schrift(_hinweis, 15)
	_hinweis.add_theme_color_override("font_color", Color("7f98a6"))
	_hinweis.text = "[Enter] weiter · [Esc] überspringen"
	rechts.add_child(_hinweis)
	_naechste()


func _schrift(c: Control, einheiten: int) -> void:
	c.add_theme_font_override("font", Stil.schrift_fuer(1))   # geglättete Fassung wie im Tutorial
	c.add_theme_font_size_override("font_size", einheiten)


func _naechste() -> void:
	_index += 1
	if _index >= ZEILEN.size():
		fertig.emit()
		return
	_zeichen = 0.0
	_warte = 0.0
	_gemeldet = false
	var z: Array = ZEILEN[_index]
	var wer := str(z[0])
	_name.text = wer
	_name.visible = wer != ""
	_bild.visible = wer != ""
	_bild.texture = load(BRAKK if wer == "BRAKK" else SONDE)
	var brakk := wer == "BRAKK"
	_name.add_theme_color_override("font_color", Color("ffd08a") if brakk else Color("9be9ff"))
	_stil.border_color = ROT if (brakk and str(z[1]).begins_with("Ihr Verräter")) or wer == "" else HOLO
	_text.add_theme_color_override("font_color", Color("ffe0e4") if wer == "" else HOLO_TEXT)
	_text.text = ""
	Ton.spiele(get_parent(), "ui-klick", -10.0)


func _process(delta: float) -> void:
	var echt := minf(delta / maxf(Engine.time_scale, 0.01), 0.1)
	rot = maxf(0.0, rot - echt * 0.25) if rot > 0.0 else 0.0
	_rand.queue_redraw()
	_lege_box()
	if _index < 0 or _index >= ZEILEN.size():
		return
	var voll := str(ZEILEN[_index][1])
	if _zeichen < voll.length():
		_zeichen = minf(float(voll.length()), _zeichen + echt * TIPP_TEMPO)
		_text.text = voll.left(int(_zeichen))
		return
	if not _gemeldet:
		_gemeldet = true
		var was := str(ZEILEN[_index][2])
		if was != "":
			if was == "verrat":
				rot = 1.0
			ereignis.emit(was)
	_warte += echt
	if _warte >= (PAUSE + PAUSE_JE * float(voll.length())) * (0.7 if _index == ZEILEN.size() - 1 else 1.0):
		_naechste()


## Fenster unten in der Mitte, Breite nach dem Bildschirm (auch 844×390).
func _lege_box() -> void:
	var g := get_viewport().get_visible_rect().size
	var breite := minf(g.x - 32.0, 680.0)
	_text.custom_minimum_size.x = maxf(200.0, breite - 140.0)
	_box.size = Vector2(breite, 0)
	_box.reset_size()
	_box.position = Vector2((g.x - _box.size.x) / 2.0, g.y - _box.size.y - maxf(16.0, g.y * 0.06))


func _male_rand() -> void:
	if rot <= 0.0:
		return
	var g := _rand.size
	var puls := 0.6 + 0.4 * sin(float(Time.get_ticks_msec()) / 120.0)
	for i in 8:
		var d := float(i) * 8.0
		_rand.draw_rect(Rect2(Vector2(d, d), g - Vector2(d, d) * 2.0), Color(ROT, 0.5 * rot * puls * (1.0 - float(i) / 8.0)), false, 8.0)


## Weiterblättern: erst die Zeile fertig zeigen, dann die nächste.
func weiter() -> void:
	if _index < 0 or _index >= ZEILEN.size():
		return
	var voll := str(ZEILEN[_index][1])
	if _zeichen < voll.length():
		_zeichen = float(voll.length())
		_text.text = voll
		return
	if not _gemeldet:
		return
	_naechste()


func ueberspringen() -> void:
	ereignis.emit("ueberspringen")
	_index = ZEILEN.size()
	fertig.emit()


func _klick(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		weiter()


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	match (event as InputEventKey).keycode:
		KEY_ESCAPE:
			ueberspringen()
			get_viewport().set_input_as_handled()
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			weiter()
			get_viewport().set_input_as_handled()
