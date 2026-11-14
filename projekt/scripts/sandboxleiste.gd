extends PanelContainer
## Sandbox-Leiste (nur im Sandbox-Modus, nur in der Bauphase): Runde wählen, Gegner der nächsten Welle und
## Truppen je Fabrik einstellen. Übergangswerkzeug zum Ausprobieren.

const TYPEN := ["hund", "sphaere", "fahne", "sprenger", "rauch", "belagerung", "schild", "sani", "schwarm"]

var spiel: Node
var _inhalt: VBoxContainer
var _kopf: Button
var _zahlen: Dictionary = {}    # Kennung -> Label
var _offen := true
var _basis_knoepfe: Dictionary = {}   # Art -> Button
var _route: CheckButton


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	var kasten := StyleBoxFlat.new()
	kasten.bg_color = Color(0.1, 0.08, 0.14, 0.94)
	kasten.border_color = Color("ffe9a8")
	kasten.set_border_width_all(2)
	kasten.set_content_margin_all(8)
	add_theme_stylebox_override("panel", kasten)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	add_child(box)
	_kopf = Button.new()
	_kopf.focus_mode = Control.FOCUS_NONE
	_kopf.pressed.connect(func():
		_offen = not _offen
		_inhalt.visible = _offen
		reset_size())
	box.add_child(_kopf)
	_inhalt = VBoxContainer.new()
	_inhalt.add_theme_constant_override("separation", 2)
	box.add_child(_inhalt)
	_zeile("runde", "Runde", func(d: int): spiel.sandbox_springe(spiel.welle + d))
	for typ: String in TYPEN:
		_zeile(typ, Werte.GEGNER[typ]["name"], func(d: int): spiel.sandbox_aendere_gegner(typ, d))
	_zeile("truppen", "Truppen je Fabrik", func(d: int): spiel.sandbox_truppen = clampi(spiel.sandbox_truppen + d, -2, 9))
	# Basis versetzen (fester Platz, zufällig oder per Klick) und Checkpoint-Route ab Runde 1
	var basis_text := Label.new()
	basis_text.text = "Basis"
	basis_text.add_theme_font_size_override("font_size", 13)
	_inhalt.add_child(basis_text)
	var basis_reihe := HBoxContainer.new()
	for wahl: Array in [["fest", "fest"], ["rechts", "rechts"], ["ueberall", "überall"], ["klick", "setzen"]]:
		var k := Button.new()
		k.text = wahl[1]
		k.focus_mode = Control.FOCUS_NONE
		k.add_theme_font_size_override("font_size", 12)
		k.tooltip_text = {"fest": "alter Platz rechts in der Mitte", "rechts": "zufällig im rechten Drittel", "ueberall": "zufällig, mindestens 8 Felder vom HQ des Gegners", "klick": "per Klick auf ein freies Feld"}[wahl[0]]
		k.pressed.connect(func(): spiel.sandbox_basis(wahl[0]))
		basis_reihe.add_child(k)
		_basis_knoepfe[wahl[0]] = k
	_inhalt.add_child(basis_reihe)
	_route = CheckButton.new()
	_route.text = "Checkpoint-Route ab Runde 1"
	_route.focus_mode = Control.FOCUS_NONE
	_route.add_theme_font_size_override("font_size", 12)
	_route.button_pressed = true
	_route.toggled.connect(func(an: bool): spiel.sandbox_cp_route(an))
	_inhalt.add_child(_route)
	var b := Button.new()
	b.text = "Welle wie im Spiel"
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(func(): spiel.sandbox_gegner = {})
	_inhalt.add_child(b)


func _zeile(kennung: String, text: String, aendere: Callable) -> void:
	var reihe := HBoxContainer.new()
	var l := Label.new()
	l.text = text
	l.custom_minimum_size.x = 132
	l.add_theme_font_size_override("font_size", 13)
	reihe.add_child(l)
	for d: int in [-1, 1]:
		var b := Button.new()
		b.text = "−" if d < 0 else "+"
		b.custom_minimum_size = Vector2(26, 24)
		b.focus_mode = Control.FOCUS_NONE
		# Umschalt = 5er-Schritte
		b.pressed.connect(func(): aendere.call(d * (5 if Input.is_key_pressed(KEY_SHIFT) else 1)))
		reihe.add_child(b)
		if d < 0:
			var z := Label.new()
			z.custom_minimum_size.x = 30
			z.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			z.add_theme_font_size_override("font_size", 13)
			reihe.add_child(z)
			_zahlen[kennung] = z
	_inhalt.add_child(reihe)


func _process(_delta: float) -> void:
	visible = spiel.sandbox and spiel.phase == 0
	if not visible:
		return
	_kopf.text = "Sandbox %s" % ("▾" if _offen else "▸")
	(_zahlen["runde"] as Label).text = str(spiel.welle)
	var w: Dictionary = spiel.naechste_welle()
	var anzahl := {}
	for g: Dictionary in w["gruppen"]:
		anzahl[g["typ"]] = g["anzahl"]
	for typ: String in TYPEN:
		var l: Label = _zahlen[typ]
		l.text = str(int(anzahl.get(typ, 0)))
		l.modulate = Color("ffe9a8") if spiel.sandbox_gegner.has(typ) else Color.WHITE
	(_zahlen["truppen"] as Label).text = str(spiel.truppen_limit(Karte.KEINE))
	for art: String in _basis_knoepfe:
		(_basis_knoepfe[art] as Button).modulate = Color("ffe9a8") if spiel.basis_art == art else Color.WHITE
	position = Vector2(1272.0 - size.x, Werte.KARTE_OBEN + 6.0)
