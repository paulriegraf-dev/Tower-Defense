class_name BrakkBosswerte
extends CanvasLayer
## H-10 (27.11., Paul): Werte-Tafel der Bossarena. [F2] im Duell öffnet rechts eine Liste (das Spiel läuft weiter) mit
## allen Werten aus Werte.BOSS_TAFEL (BOSS_SNIPER_*, BOSS_GUNNER_* (I-8), BOSS_PLASMA_* (J-7), BOSS_REIHE_*, BOSS_SAEULE_*, BOSS_KLON_*, BOSS_DRUCK_*, BOSS_ABFOLGE_*,
## HERAUSFORDERER_LEBEN_MAL / _TREFFER_ANTEIL / _TEMPO_MAL): Wert, −/+ in sinnvollen Schritten (Zeiten und Anteile 0,05,
## Felder 0,5, Winkel 1°, Zahlen 1) und „Std“. Änderungen gelten sofort im laufenden Duell und landen in
## user://bossarena.cfg (beim nächsten Arena-Start wieder geladen; im echten Lauf gelten immer die Standardwerte).
## „Werte kopieren“ legt alle abweichenden Werte als GDScript-Konstantenblock in die Zwischenablage, „Alles Standard“.

const DATEI := "user://bossarena.cfg"
const FELDER := ["WEITE", "ABSTAND_MIN", "LASER_MIN", "VORHALT_MAX", "SPERRE", "ANKER_MIN", "STURM_FERN", "KRONE_PLUS", "ANKER_NAH", "ANKER_TEMPO", "ZUGTEMPO"]   # I-8: auch die Felder des Technogunners

var arena: BrakkBossarena
var offen := false
var _box: PanelContainer = null
var _werte := {}                 # Name -> Label (Wert)


func _init(p_arena: BrakkBossarena) -> void:
	arena = p_arena
	layer = 85


## Schrittweite für −/+.
static func schritt(n: String) -> float:
	if typeof(Werte.boss_standard()[n]) == TYPE_INT:
		return 1.0
	if n.contains("WINKEL"):
		return 1.0
	for w: String in FELDER:
		if n.contains(w):
			return 0.5
	if n.ends_with("_SEIT") or n.ends_with("_STOSS") or n.ends_with("_RADIUS") or n.ends_with("_STREU"):
		return 0.5   # I-8/J-7: Seitschritt, Stoß, Radien, Streuung (Felder)
	return 0.05


## Gespeicherte Änderungen laden (nach Werte.boss_zuruecksetzen in Order24.einrichten).
static func laden() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(DATEI) != OK:
		return
	for n: String in Werte.BOSS_TAFEL:
		if cfg.has_section_key("werte", n):
			Werte.boss_setzen(n, cfg.get_value("werte", n))


static func speichern() -> void:
	var cfg := ConfigFile.new()
	var ab := abweichende()
	for n: String in ab:
		cfg.set_value("werte", n, ab[n])
	if ab.is_empty():
		cfg.set_value("info", "leer", true)
	cfg.save(DATEI)


## Name -> Wert aller Werte, die vom Standard abweichen.
static func abweichende() -> Dictionary:
	var aus := {}
	var std := Werte.boss_standard()
	for n: String in Werte.BOSS_TAFEL:
		var w: Variant = Werte.boss_wert(n)
		if absf(float(w) - float(std[n])) > 0.0001:
			aus[n] = w
	return aus


## Die abweichenden Werte als GDScript-Block (zum Weitergeben an Claude Code).
static func kopiertext() -> String:
	var ab := abweichende()
	var zeilen := PackedStringArray(["## Bossarena-Werte (Werte-Tafel, %s)" % Time.get_date_string_from_system()])
	for n: String in ab:
		zeilen.append("static var %s := %s   # Standard %s" % [n, _zahl(ab[n]), _zahl(Werte.boss_standard()[n])])
	if ab.is_empty():
		zeilen.append("## (alles Standard)")
	return "\n".join(zeilen)


static func _zahl(w: Variant) -> String:
	if typeof(w) == TYPE_INT:
		return str(w)
	return str(snappedf(float(w), 0.001))


## Einen Wert um `schritte` Schritte ändern (auch für den Test). Sofort wirksam; HERAUSFORDERER_LEBEN_MAL passt das Leben
## des laufenden Bosses im selben Verhältnis an.
func aendern(n: String, schritte: int) -> void:
	var alt := float(Werte.boss_wert(n))
	setzen(n, maxf(0.0, alt + schritte * schritt(n)))


func setzen(n: String, wert: float) -> void:
	var alt := float(Werte.boss_wert(n))
	Werte.boss_setzen(n, wert)
	if n == "HERAUSFORDERER_LEBEN_MAL" and alt > 0.0 and arena != null and arena.h != null and arena.h.einheit != null and is_instance_valid(arena.h.einheit):
		var e := arena.h.einheit
		var mal := float(Werte.boss_wert(n)) / alt
		e.max_leben *= mal
		e.leben *= mal
	speichern()
	_zeile_neu(n)


func alles_standard() -> void:
	for n: String in Werte.BOSS_TAFEL:
		setzen(n, float(Werte.boss_standard()[n]))


func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo or k.physical_keycode != KEY_F2:
		return
	if arena == null or not (arena.schritt in ["angesagt", "duell", "bergung"]):
		return
	umschalten()
	get_viewport().set_input_as_handled()


func umschalten() -> void:
	offen = not offen
	if offen and _box == null:
		_bauen()
	if _box != null:
		_box.visible = offen
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if offen else Input.MOUSE_MODE_CAPTURED
	if offen:
		for n: String in Werte.BOSS_TAFEL:
			_zeile_neu(n)


func _bauen() -> void:
	_box = PanelContainer.new()
	_box.anchor_left = 1.0
	_box.anchor_right = 1.0
	_box.anchor_top = 0.0
	_box.anchor_bottom = 1.0
	_box.offset_left = -560.0
	_box.offset_right = -12.0
	_box.offset_top = 12.0
	_box.offset_bottom = -12.0
	var grund := StyleBoxFlat.new()
	grund.bg_color = Color(0.04, 0.03, 0.07, 0.88)
	grund.border_color = Color("7fe0ff")
	grund.set_border_width_all(2)
	grund.set_content_margin_all(10)
	_box.add_theme_stylebox_override("panel", grund)
	add_child(_box)
	var spalte := VBoxContainer.new()
	_box.add_child(spalte)
	var kopf := HBoxContainer.new()
	spalte.add_child(kopf)
	var titel := Label.new()
	titel.text = tr("Bosswerte [F2]")
	titel.add_theme_color_override("font_color", Color("7fe0ff"))
	titel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	kopf.add_child(titel)
	for b: Array in [[tr("Werte kopieren"), _kopieren], [tr("Alles Standard"), alles_standard], [tr("Schließen"), umschalten]]:
		var knopf := Button.new()
		knopf.text = str(b[0])
		knopf.focus_mode = Control.FOCUS_NONE
		knopf.pressed.connect(b[1] as Callable)
		kopf.add_child(knopf)
	var hinweis := Label.new()
	hinweis.text = tr("Gilt sofort, nur in der Bossarena (gespeichert in bossarena.cfg).")
	hinweis.add_theme_font_size_override("font_size", 12)
	hinweis.add_theme_color_override("font_color", Color("8d8698"))
	spalte.add_child(hinweis)
	var rollen := ScrollContainer.new()
	rollen.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rollen.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	spalte.add_child(rollen)
	var liste := VBoxContainer.new()
	liste.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rollen.add_child(liste)
	for n: String in Werte.BOSS_TAFEL:
		var reihe := HBoxContainer.new()
		liste.add_child(reihe)
		var name_l := Label.new()
		name_l.text = n
		name_l.add_theme_font_size_override("font_size", 12)
		name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_l.clip_text = true
		reihe.add_child(name_l)
		var wert_l := Label.new()
		wert_l.custom_minimum_size = Vector2(64, 0)
		wert_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		wert_l.add_theme_font_size_override("font_size", 12)
		reihe.add_child(wert_l)
		_werte[n] = wert_l
		for b: Array in [["−", aendern.bind(n, -1)], ["+", aendern.bind(n, 1)], [tr("Std"), func() -> void: setzen(n, float(Werte.boss_standard()[n]))]]:
			var knopf := Button.new()
			knopf.text = str(b[0])
			knopf.focus_mode = Control.FOCUS_NONE
			knopf.custom_minimum_size = Vector2(30, 0)
			knopf.add_theme_font_size_override("font_size", 12)
			knopf.pressed.connect(b[1] as Callable)
			reihe.add_child(knopf)


func _zeile_neu(n: String) -> void:
	var l: Label = _werte.get(n, null)
	if l == null:
		return
	var w: Variant = Werte.boss_wert(n)
	var std: Variant = Werte.boss_standard()[n]
	l.text = _zahl(w)
	l.add_theme_color_override("font_color", Color("ffd27a") if absf(float(w) - float(std)) > 0.0001 else Color("e6e0d2"))


func _kopieren() -> void:
	DisplayServer.clipboard_set(kopiertext())
	if arena != null and arena.spiel != null:
		arena.spiel.melde(tr("Bosswerte in der Zwischenablage (%d abweichend)") % abweichende().size(), 2.5)
