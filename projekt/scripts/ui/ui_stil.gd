extends RefCounted
## Gemeinsamer Stil der neuen Oberfläche (16.11.2026): Farben, Schrift (VT323), Metallplatten, Sechsecke und kleine
## Pixelsymbole. Alles im Code gezeichnet – Platzhalter, bis die PixelLab-Bilder kommen. Maße in UI-Pixeln
## (Raster 640×360, siehe hud.gd).

const METALL := Color("2a2f38")
const METALL_DUNKEL := Color("1d2027")
const METALL_TIEF := Color("15171c")
const RAHMEN := Color("4a515e")
const RAHMEN_HELL := Color("6b7380")
const LEUCHT := Color("7fe0ff")          # Technoclan: alles Eigene und Anklickbare leuchtet so
const TEXT := Color("e6edf3")
const TEXT_BLASS := Color("8b95a3")
const GOLD := Color("ffd34d")            # Geld und Zinsen
const ROT := Color("ff5a6e")             # Leben, Warnungen
const WARN := Color("ff8a7a")
const KUPFER := Color("e08a4f")          # alles über die Gegner (Myriaden)
const SCHILD_GRUND := Color("3a3f4a")
const SCHILD_RAND := Color("5d6573")

const GROSS := 14
const NORMAL := 9
const KLEIN := 8

const SCHRIFT_PFAD := "res://assets/fonts/VT323-Regular.ttf"
const RASTER := 25        # VT323 ist auf 25 Schriftpixel je Geviert gezeichnet: nur in Vielfachen davon gestochen scharf
const UI_SKALA := 2.0     # die Wurzel der Oberfläche ist zweifach skaliert (hud.gd)
static var _schrift: Font = null


static func schrift() -> Font:
	if _schrift == null:
		var f: Variant = load(SCHRIFT_PFAD) if ResourceLoader.exists(SCHRIFT_PFAD) else null
		if f is FontFile:
			var ff := f as FontFile
			# Scharf (16.11.): ohne Glättung und ohne Überabtastung gerastert, gezeichnet in echten Bildschirmpixeln
			# (siehe schreibe()). So ist 1 Schriftpixel = 1 (bzw. 2) Bildschirmpixel, unabhängig von der Streckung.
			ff.antialiasing = TextServer.FONT_ANTIALIASING_NONE
			ff.hinting = TextServer.HINTING_NONE
			ff.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
			ff.oversampling = 1.0
			_schrift = ff
		else:
			_schrift = ThemeDB.fallback_font   # Schrift noch nicht importiert: Standardschrift
	return _schrift


## Bildschirmpixel je UI-Pixel (bei 1920×1080: 1,5 vom Fenster mal 2 von der Oberfläche = 3).
static func skala() -> float:
	var st := 1.0
	var baum := Engine.get_main_loop() as SceneTree
	if baum != null and baum.root != null:
		var soll := Vector2(baum.root.content_scale_size)
		if soll.x > 0.0 and soll.y > 0.0:
			st = minf(baum.root.size.x / soll.x, baum.root.size.y / soll.y)
	return UI_SKALA * maxf(st, 0.01)


## Schriftgröße in Bildschirmpixeln: das nächste Vielfache von 25 (mindestens 25).
static func _roh(groesse: int) -> int:
	return RASTER * maxi(1, roundi(groesse * skala() / RASTER))


static func breite(text: String, groesse: int) -> float:
	return schrift().get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, _roh(groesse)).x / skala()


## Text, dessen Großbuchstaben senkrecht um `links_mitte.y` stehen. Gibt die Breite zurück.
static func schreibe(ci: CanvasItem, links_mitte: Vector2, text: String, groesse: int, farbe: Color) -> float:
	var f := schrift()
	var sk := skala()
	var roh := _roh(groesse)
	var basis := Vector2(links_mitte.x, links_mitte.y + (f.get_ascent(roh) - f.get_descent(roh)) / 2.0 / sk)
	basis = (basis * sk).round() / sk   # auf ganze Bildschirmpixel
	ci.draw_set_transform(basis, 0.0, Vector2(1.0 / sk, 1.0 / sk))
	ci.draw_string(f, Vector2.ZERO, text, HORIZONTAL_ALIGNMENT_LEFT, -1, roh, farbe)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	return breite(text, groesse)


static func schreibe_mittig(ci: CanvasItem, mitte: Vector2, text: String, groesse: int, farbe: Color) -> void:
	schreibe(ci, Vector2(mitte.x - breite(text, groesse) / 2.0, mitte.y), text, groesse, farbe)


## Mehrzeiliger Text ab `oben_links` (obere Kante der ersten Zeile).
static func absatz(ci: CanvasItem, oben_links: Vector2, text: String, weite: float, groesse: int, farbe: Color) -> void:
	var f := schrift()
	var sk := skala()
	var roh := _roh(groesse)
	var start := ((oben_links + Vector2(0, f.get_ascent(roh) / sk)) * sk).round() / sk
	ci.draw_set_transform(start, 0.0, Vector2(1.0 / sk, 1.0 / sk))
	ci.draw_multiline_string(f, Vector2.ZERO, text, HORIZONTAL_ALIGNMENT_LEFT, weite * sk, roh, -1, farbe)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


static func absatz_groesse(text: String, weite: float, groesse: int) -> Vector2:
	var sk := skala()
	return schrift().get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, weite * sk, _roh(groesse)) / sk


## Rechteck mit abgeschrägten Ecken (Fase `e`).
static func fase(r: Rect2, e: float) -> PackedVector2Array:
	e = clampf(e, 0.0, minf(r.size.x, r.size.y) / 2.0)
	var a := r.position
	var b := r.end
	return PackedVector2Array([
		Vector2(a.x + e, a.y), Vector2(b.x - e, a.y), Vector2(b.x, a.y + e), Vector2(b.x, b.y - e),
		Vector2(b.x - e, b.y), Vector2(a.x + e, b.y), Vector2(a.x, b.y - e), Vector2(a.x, a.y + e)])


## Metallplatte: Rahmen, Kante, Fläche.
static func platte(ci: CanvasItem, r: Rect2, e: float = 3.0, innen: Color = METALL_DUNKEL, rand: Color = RAHMEN) -> void:
	if r.size.x < 6.0 or r.size.y < 6.0:
		return   # noch nicht ausgemessen (erstes Bild)
	ci.draw_colored_polygon(fase(r, e), rand)
	ci.draw_colored_polygon(fase(r.grow(-1.0), maxf(e - 0.4, 0.0)), METALL)
	ci.draw_colored_polygon(fase(r.grow(-2.0), maxf(e - 0.8, 0.0)), innen)


## Bild (z. B. Bausymbol) mittig um `mitte`, jeder Bildpunkt genau `bildpunkt` Bildschirmpixel groß und auf ganze
## Bildschirmpixel gelegt – so bleibt es scharf, egal wie die Oberfläche skaliert ist.
static func bild(ci: CanvasItem, tex: Texture2D, mitte: Vector2, bildpunkt: int, farbe: Color = Color.WHITE) -> void:
	if tex == null:
		return
	var sk := skala()
	var g := tex.get_size() * float(bildpunkt) / sk
	var o := ((mitte - g / 2.0) * sk).round() / sk
	ci.draw_texture_rect(tex, Rect2(o, g), false, farbe)


## Kleines Preisschild unter einer Kachel.
static func preisschild(ci: CanvasItem, mitte: Vector2, text: String, farbe: Color) -> void:
	var w := breite(text, KLEIN) + 6.0
	var r := Rect2(Vector2(roundf(mitte.x - w / 2.0), roundf(mitte.y - 4.5)), Vector2(roundf(w), 9.0))
	platte(ci, r, 1.0, SCHILD_GRUND, SCHILD_RAND)
	schreibe_mittig(ci, r.get_center(), text, KLEIN, farbe)


## Sechseck mit Spitze oben.
static func sechseck(m: Vector2, w: float, h: float) -> PackedVector2Array:
	return PackedVector2Array([m + Vector2(0, -h / 2.0), m + Vector2(w / 2.0, -h / 4.0), m + Vector2(w / 2.0, h / 4.0),
		m + Vector2(0, h / 2.0), m + Vector2(-w / 2.0, h / 4.0), m + Vector2(-w / 2.0, -h / 4.0)])


## Pixelsymbole als kleine Bitmaps: '#' = Farbe, '+' = dunkler, '*' = heller, '.' = leer.
const SYMBOLE := {
	"herz": [
		".##.##.",
		"#*#####",
		"#######",
		".#####.",
		"..###..",
		"...#...",
	],
	"muenze": [
		"..###..",
		".#*###.",
		"##+#+##",
		"##+#+##",
		"##+#+##",
		".#####.",
		"..###..",
	],
	"fabrik": [
		"...........",
		".##........",
		".##........",
		".##..#..#..",
		".##.##.##.#",
		".##########",
		".####++####",
		".####++####",
	],
	"wall": [
		"...........",
		"####.######",
		"+++++++++++",
		"######.####",
		"+++++++++++",
		"####.######",
		"+++++++++++",
	],
	"stellung": [
		".....#.....",
		"....###....",
		".....#.....",
		"..#######..",
		"###########",
		"+++++++++++",
		"###########",
		"+++++++++++",
	],
	"turm": [
		"...#.#.#...",
		"...#####...",
		"....###....",
		"....#*#....",
		"....###....",
		"....###....",
		"...#####...",
		"..#######..",
	],
	"batterie": [
		"...........",
		"......#####",
		"....####...",
		"..######...",
		".########..",
		".##*#####..",
		"..#....#...",
	],
	"tor": [
		"###########",
		"##+.....+##",
		"##.......##",
		"##.......##",
		"##.......##",
		"##.......##",
	],
	"panzer": [
		".#########.",
		".####+####.",
		".####+####.",
		".####+####.",
		"..###+###..",
		"...##+##...",
		"....###....",
	],
	"brakk": [
		".....#.....",
		"....###....",
		"###########",
		".#########.",
		"..#######..",
		".####.####.",
		".##.....##.",
	],
	"buch": [
		"###.###",
		"#*#.#*#",
		"#*#.#*#",
		"#*#.#*#",
		"###.###",
	],
	"band": [
		"##..###",
		".......",
		"###.##.",
		".......",
		"#######",
	],
	"raster": [
		"#.#.#",
		".....",
		"#.#.#",
		".....",
		"#.#.#",
	],
	"balken": [
		"#....",
		"#.#..",
		"#.#.#",
		"#.#.#",
		"#####",
	],
	"menue": [
		"#####",
		".....",
		"#####",
		".....",
		"#####",
	],
	"play": [
		"#....",
		"###..",
		"#####",
		"###..",
		"#....",
	],
}


static func symbol(ci: CanvasItem, art: String, mitte: Vector2, px: float, farbe: Color) -> void:
	var b: Array = SYMBOLE.get(art, [])
	if b.is_empty():
		return
	var w := (b[0] as String).length()
	var h := b.size()
	var o := (mitte - Vector2(w, h) * px / 2.0).round()
	for y in h:
		var zeile: String = b[y]
		for x in zeile.length():
			var c := zeile[x]
			if c == ".":
				continue
			var f := farbe
			if c == "+":
				f = farbe.darkened(0.45)
			elif c == "*":
				f = farbe.lightened(0.55)
			ci.draw_rect(Rect2(o + Vector2(x, y) * px, Vector2(px, px)), f)


## Knopf ohne eigene Godot-Optik: Er zeichnet sich selbst (Kachel, Emblem), Text und Rahmen von Godot bleiben unsichtbar.
static func leerer_knopf(b: Button) -> void:
	for s in ["normal", "hover", "pressed", "disabled", "focus", "hover_pressed"]:
		b.add_theme_stylebox_override(s, StyleBoxEmpty.new())
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_disabled_color", "font_focus_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(c, Color(0, 0, 0, 0))
	b.focus_mode = Control.FOCUS_NONE   # sonst löst die Leertaste den zuletzt geklickten Knopf aus
