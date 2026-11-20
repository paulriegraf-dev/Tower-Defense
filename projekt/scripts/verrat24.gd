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
## 20.11. (Paul): Brakk ist kein Verräter – er wird nur als einer behandelt. Sein Ruf gilt zuerst der Repaulblik.
const ZEILEN := [
	["SONDE 7 · FUNK", "Kommandant Brakk, hier spricht Sonde 7. Der Rat der Repaulblik hat eine Akte über Sie angelegt.", ""],
	["SONDE 7 · FUNK", "Abgefangene Funksprüche, offene Tore, verschonte Myriaden. Die Beweislage gilt als eindeutig.", ""],
	["BRAKK", "Gefälscht! Ich habe jede Mauer dieser Verteidigung selbst hochgezogen. Wozu die Ehrengarde?", ""],
	["SONDE 7 · FUNK", "Ob gefälscht oder nicht – der Rat braucht einen Schuldigen. Und Sie stehen ihm am nächsten.", ""],
	["SONDE 7 · FUNK", "Befehl 24 bestätigt.", ""],
	["SONDE 7 · FUNK", "Kommandant Brakk … Sie werden ab sofort als Verräter geführt. Sie sind entlassen.", "anlegen"],
	["BRAKK", "Damit werdet ihr nicht durchkommen! Mein Leben für die Repaulblik!", "verrat"],
	["SONDE 7 · FUNK", "Schild geschlossen. Zielperson ist bewaffnet. Feuer frei.", "schuss"],
	["", "Überlebe – und beweise, wer hier wirklich die Repaulblik verrät.", "los"],
]
## 20.11. (Paul): nach dem Classic-Sieg („Weiterspielen …?“) – Sonde 7 hintergeht Brakk, ein Schockimpuls nimmt ihm
## Erfahrung und Ringe.
const ZEILEN_WEITER := [
	["SONDE 7 · FUNK", "Das HQ der Myriaden ist gefallen. Glückwunsch, Kommandant Brakk.", ""],
	["BRAKK", "Es ist vorbei. Die Repaulblik ist sicher – dank dieser Verteidigung.", ""],
	["SONDE 7 · FUNK", "Der Rat sieht das anders. Wer allein eine Armee schlägt, kann auch die Repaulblik schlagen.", ""],
	["SONDE 7 · FUNK", "In Ihrer Akte steht jetzt „Verräter“. Wer es hineingeschrieben hat, spielt keine Rolle mehr.", ""],
	["SONDE 7 · FUNK", "Befehl 24 bestätigt. Kommandant Brakk … Sie sind entlassen.", "anlegen"],
	["BRAKK", "Damit werdet ihr nicht durchkommen! Mein Leben für die Repaulblik!", "verrat"],
	["SONDE 7 · FUNK", "Schockimpuls auf den Kommandanten. Ringe und Gefechtsdaten löschen.", "schock"],
	["BRAKK", "Meine Ringe … alles weg. Den Rang könnt ihr mir nehmen – die Treue nicht.", ""],
	["SONDE 7 · FUNK", "Schild geschlossen. Alle Einheiten: Feuer frei.", "schuss"],
	["", "Überlebe. Die Ruine des Myriaden-HQ im Westen ist deine einzige Zuflucht.", "los"],
]

var zeilen: Array = ZEILEN          # 20.11.: auch für kurze Funksprüche (Order24.funk)
var sperrt := true                # false: Funkspruch im Spiel – Steuerung frei, Fenster oben, kein Esc/Enter
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
	wurzel.mouse_filter = Control.MOUSE_FILTER_STOP if sperrt else Control.MOUSE_FILTER_IGNORE
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
	_hinweis.text = "[Enter] weiter · [Esc] überspringen" if sperrt else ""
	_hinweis.visible = sperrt
	rechts.add_child(_hinweis)
	_naechste()


## 20.11. (Paul): Porträt des Myriaden-Schwarms – erstes Bild des Schwarmgeists (keine neue Grafik).
func _schwarm_bild() -> Texture2D:
	var d: Dictionary = Werte.grafik_daten(Werte.GEGNER["schwarm"])
	if not d.has("blatt") or not d.has("zelle"):
		return load(SONDE)
	var bild := AtlasTexture.new()
	bild.atlas = load(str(d["blatt"]))
	bild.region = Rect2(0, 0, float(d["zelle"]), float(d["zelle"]))
	return bild


func _schrift(c: Control, einheiten: int) -> void:
	c.add_theme_font_override("font", Stil.schrift_fuer(1))   # geglättete Fassung wie im Tutorial
	c.add_theme_font_size_override("font_size", einheiten)


func _naechste() -> void:
	_index += 1
	if _index >= zeilen.size():
		fertig.emit()
		return
	_zeichen = 0.0
	_warte = 0.0
	_gemeldet = false
	var z: Array = zeilen[_index]
	var wer := str(z[0])
	_name.text = wer
	_name.visible = wer != ""
	_bild.visible = wer != ""
	_bild.texture = _schwarm_bild() if wer.begins_with("MYRIADEN") else load(BRAKK if wer == "BRAKK" else SONDE)   # 20.11. (Paul): der Schwarm meldet sich
	var brakk := wer == "BRAKK"
	_name.add_theme_color_override("font_color", Color("ffd08a") if brakk else Color("9be9ff"))
	_stil.border_color = ROT if str(z[2]) in ["verrat", "schock"] or wer == "" else HOLO
	_text.add_theme_color_override("font_color", Color("ffe0e4") if wer == "" else HOLO_TEXT)
	_text.text = ""
	Ton.spiele(get_parent(), "ui-klick", -10.0)


func _process(delta: float) -> void:
	var echt := minf(delta / maxf(Engine.time_scale, 0.01), 0.1)
	rot = maxf(0.0, rot - echt * 0.25) if rot > 0.0 else 0.0
	_rand.queue_redraw()
	_lege_box()
	if _index < 0 or _index >= zeilen.size():
		return
	var voll := str(zeilen[_index][1])
	if _zeichen < voll.length():
		_zeichen = minf(float(voll.length()), _zeichen + echt * TIPP_TEMPO)
		_text.text = voll.left(int(_zeichen))
		return
	if not _gemeldet:
		_gemeldet = true
		var was := str(zeilen[_index][2])
		if was != "":
			if was == "verrat":
				rot = 1.0
			ereignis.emit(was)
	_warte += echt
	if _warte >= (PAUSE + PAUSE_JE * float(voll.length())) * (0.7 if _index == zeilen.size() - 1 else 1.0):
		_naechste()


## Fenster unten in der Mitte, Breite nach dem Bildschirm (auch 844×390).
func _lege_box() -> void:
	var g := get_viewport().get_visible_rect().size
	var breite := minf(g.x - 32.0, 680.0)
	_text.custom_minimum_size.x = maxf(200.0, breite - 140.0)
	_box.size = Vector2(breite, 0)
	_box.reset_size()
	_box.position = Vector2((g.x - _box.size.x) / 2.0, g.y - _box.size.y - maxf(16.0, g.y * 0.06) if sperrt else g.y * 0.25)


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
	if _index < 0 or _index >= zeilen.size():
		return
	var voll := str(zeilen[_index][1])
	if _zeichen < voll.length():
		_zeichen = float(voll.length())
		_text.text = voll
		return
	if not _gemeldet:
		return
	_naechste()


func ueberspringen() -> void:
	ereignis.emit("ueberspringen")
	_index = zeilen.size()
	fertig.emit()


func _klick(event: InputEvent) -> void:
	if not sperrt:
		return
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		weiter()


func _input(event: InputEvent) -> void:
	if not sperrt:
		return
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	match (event as InputEventKey).keycode:
		KEY_ESCAPE:
			ueberspringen()
			get_viewport().set_input_as_handled()
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			weiter()
			get_viewport().set_input_as_handled()
