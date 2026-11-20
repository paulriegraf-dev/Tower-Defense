class_name Platzhalter
extends RefCounted
## 20.11. (Paul, Nachtrag): Platzhalter-Bilder aus Code, bis es PixelLab-Bilder gibt – klar unterscheidbare Silhouetten in
## Technoclan-Lila/Cyan, jede mit eigener Form. Alle als Textur für ein Sprite2D unter den Figuren: die HD-2D-Ansicht
## spiegelt jedes solche Sprite als Sprite3D (hd_ansicht.gd), also sind sie dort genauso zu sehen.
##   PliPlop 3cK: Kugel auf Rad mit kurzem Lauf, je Pfad eigener Aufsatz (8 Blickrichtungen untereinander).
##   Krone: Stufe 4 (Formtürme des Irrtürmers, Elitefabrik und Elitetruppen der Sonde 7).
##   Turm-Zusatz: Stufe-4-Formturm – eine goldene Zusatzform je Turmart.

const UMRISS := Color("15121b")
const LILA := Color("5b3a8c")
const LILA_HELL := Color("8a5fd0")
const LILA_DUNKEL := Color("33204f")
const CYAN := Color("7fe0ff")
const CYAN_HELL := Color("d8f8ff")
const GOLD := Color("ffd34d")
const GOLD_DUNKEL := Color("b8862a")
const METALL := Color("4a515e")
const METALL_HELL := Color("8a93a6")

const PP_ZELLE := 40                     # PliPlop: Kantenlänge eines Bilds (Pixel)
const PP_ANKER := Vector2(20, 35)        # Fußpunkt im Bild
const PP_ZEILE := {"S": 0, "E": 1, "N": 2, "W": 3, "SE": 4, "NE": 5, "NW": 6, "SW": 7}   # wie beim Gefechtsturm

static var _cache := {}


# ------------------------------------------------------------------ Malwerkzeug

static func _kreis(img: Image, m: Vector2, r: float, farbe: Color) -> void:
	for y in range(floori(m.y - r), ceili(m.y + r) + 1):
		for x in range(floori(m.x - r), ceili(m.x + r) + 1):
			if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height() and Vector2(x + 0.5, y + 0.5).distance_to(m) <= r:
				img.set_pixel(x, y, farbe)


static func _ellipse(img: Image, m: Vector2, rx: float, ry: float, farbe: Color) -> void:
	for y in range(floori(m.y - ry), ceili(m.y + ry) + 1):
		for x in range(floori(m.x - rx), ceili(m.x + rx) + 1):
			var d := Vector2((x + 0.5 - m.x) / rx, (y + 0.5 - m.y) / ry)
			if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height() and d.length() <= 1.0:
				img.set_pixel(x, y, farbe)


static func _rechteck(img: Image, r: Rect2i, farbe: Color) -> void:
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
				img.set_pixel(x, y, farbe)


static func _linie(img: Image, a: Vector2, b: Vector2, dicke: float, farbe: Color) -> void:
	var n := maxi(1, ceili(a.distance_to(b) * 2.0))
	for i in n + 1:
		_kreis(img, a.lerp(b, float(i) / float(n)), dicke / 2.0, farbe)


## Dunkler Umriss um alles Gemalte (1 Pixel), wie bei den Truppenbildern.
static func _umriss(img: Image) -> void:
	var kopie := img.duplicate() as Image
	for y in img.get_height():
		for x in img.get_width():
			if kopie.get_pixel(x, y).a > 0.0:
				continue
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var n := Vector2i(x, y) + d
				if n.x >= 0 and n.y >= 0 and n.x < img.get_width() and n.y < img.get_height() and kopie.get_pixel(n.x, n.y).a > 0.0:
					img.set_pixel(x, y, UMRISS)
					break


# ------------------------------------------------------------------ PliPlop 3cK

## Blatt mit 8 Blickrichtungen (Zeilen wie PP_ZEILE) für den Pfad des Rings `ring` ("" = Grundschuss).
static func pliplop(ring: String) -> Texture2D:
	var schluessel := "pp:" + ring
	if not _cache.has(schluessel):
		var img := Image.create(PP_ZELLE, PP_ZELLE * 8, false, Image.FORMAT_RGBA8)
		for name: String in PP_ZEILE:
			_pliplop_bild(img, int(PP_ZEILE[name]) * PP_ZELLE, name, ring)
		_umriss(img)
		_cache[schluessel] = ImageTexture.create_from_image(img)
	return _cache[schluessel]


## Ein Bild: Rad unten, Kugel darauf, kurzer Lauf in Blickrichtung, oben der Aufsatz des Pfads.
static func _pliplop_bild(img: Image, oy: int, richtung: String, ring: String) -> void:
	var o := Vector2(0, oy)
	var r := {"S": Vector2(0, 1), "N": Vector2(0, -1), "E": Vector2(1, 0), "W": Vector2(-1, 0),
		"SE": Vector2(0.7, 0.7), "NE": Vector2(0.7, -0.7), "NW": Vector2(-0.7, -0.7), "SW": Vector2(-0.7, 0.7)}[richtung] as Vector2
	var mitte := o + Vector2(20, 22)
	# Rad: dunkle Scheibe mit Nabe (von vorn rund, von der Seite schmal)
	var seitlich := absf(r.x) > 0.5
	_ellipse(img, o + Vector2(20, 33), 4.0 if not seitlich else 7.0, 3.5, METALL)
	_ellipse(img, o + Vector2(20, 33), 1.5 if not seitlich else 3.0, 1.5, METALL_HELL)
	# Lauf hinter der Kugel, wenn er vom Betrachter weg zeigt
	var lauf_ende := mitte + Vector2(r.x * 13.0, r.y * 6.0 + 2.0)
	if r.y < 0.0:
		_linie(img, mitte + Vector2(0, 2), lauf_ende, 3.0, METALL)
	# Kugel
	_kreis(img, mitte, 10.0, LILA_DUNKEL)
	_kreis(img, mitte + Vector2(-1, -1), 9.0, LILA)
	_kreis(img, mitte + Vector2(-3, -4), 4.0, LILA_HELL)
	# Leuchtband um die Kugel
	_rechteck(img, Rect2i(int(mitte.x) - 9, int(mitte.y) + 3, 18, 2), CYAN)
	# Linse in Blickrichtung (vorn sichtbar)
	if r.y >= 0.0:
		_kreis(img, mitte + Vector2(r.x * 5.0, 1.0 + r.y * 3.0), 2.5, CYAN_HELL)
	# Lauf vor der Kugel
	if r.y >= 0.0:
		_linie(img, mitte + Vector2(r.x * 6.0, 3.0), lauf_ende, 3.0, METALL_HELL)
		_kreis(img, lauf_ende, 1.5, CYAN)
	_aufsatz(img, mitte + Vector2(0, -9), ring)


## Aufsatz oben auf der Kugel – je Pfad eine eigene Form.
static func _aufsatz(img: Image, oben: Vector2, ring: String) -> void:
	var p := oben
	match ring:
		"plasmagel":   # Schockwelle: flache Ringschüssel
			_ellipse(img, p + Vector2(0, -2), 9.0, 3.0, CYAN)
			_ellipse(img, p + Vector2(0, -2), 6.0, 1.5, LILA_DUNKEL)
		"laser":   # Flak: zwei kurze Rohre schräg nach oben
			_linie(img, p + Vector2(-3, 0), p + Vector2(-5, -9), 2.5, METALL_HELL)
			_linie(img, p + Vector2(3, 0), p + Vector2(5, -9), 2.5, METALL_HELL)
			_kreis(img, p + Vector2(-5, -9), 1.2, CYAN)
			_kreis(img, p + Vector2(5, -9), 1.2, CYAN)
		"markierung":   # Nagler: lange dünne Schiene mit Zielfernrohr
			_rechteck(img, Rect2i(int(p.x) - 11, int(p.y) - 4, 22, 2), METALL_HELL)
			_rechteck(img, Rect2i(int(p.x) - 3, int(p.y) - 7, 6, 3), LILA_HELL)
			_kreis(img, p + Vector2(2, -6), 1.0, CYAN_HELL)
		"durchschuss":   # Bohrer: Kegel
			for i in 9:
				_rechteck(img, Rect2i(int(p.x) - 4 + i / 2, int(p.y) - i - 1, 8 - i, 1), METALL_HELL if i % 2 == 0 else METALL)
		"feuerteam":   # Repetierer: Trommel
			_kreis(img, p + Vector2(0, -4), 5.0, METALL)
			_kreis(img, p + Vector2(0, -4), 2.0, CYAN)
		"minigun":   # Kreisel: Rotor mit Flügeln
			_rechteck(img, Rect2i(int(p.x) - 1, int(p.y) - 6, 2, 6), METALL)
			_rechteck(img, Rect2i(int(p.x) - 12, int(p.y) - 8, 24, 2), METALL_HELL)
			_kreis(img, p + Vector2(0, -7), 1.5, CYAN)
		"bollwerk":   # Prellschild: Schildplatte
			_rechteck(img, Rect2i(int(p.x) - 8, int(p.y) - 9, 16, 9), METALL)
			_rechteck(img, Rect2i(int(p.x) - 7, int(p.y) - 8, 14, 7), LILA_HELL)
			_rechteck(img, Rect2i(int(p.x) - 1, int(p.y) - 8, 2, 7), CYAN)
		"abpraller":   # Bogenblitz: Teslaspule
			for i in 3:
				_rechteck(img, Rect2i(int(p.x) - 3 + i, int(p.y) - 3 - i * 3, 6 - i * 2, 2), METALL_HELL)
			_kreis(img, p + Vector2(0, -11), 2.5, CYAN_HELL)
			_linie(img, p + Vector2(0, -11), p + Vector2(4, -12), 1.0, CYAN)
		"brandfeld":   # Brandmörser: breites kurzes Rohr, schräg
			_linie(img, p + Vector2(-2, 0), p + Vector2(4, -7), 5.0, METALL)
			_kreis(img, p + Vector2(4, -7), 2.0, Color("ff8a3d"))
		_:   # Grundschuss: kleiner Antennenknopf
			_rechteck(img, Rect2i(int(p.x), int(p.y) - 5, 1, 5), METALL_HELL)
			_kreis(img, p + Vector2(0.5, -6), 1.5, CYAN)


# ------------------------------------------------------------------ Stufe 4

## Goldene Krone (Stufe 4).
static func krone() -> Texture2D:
	if not _cache.has("krone"):
		var img := Image.create(16, 11, false, Image.FORMAT_RGBA8)
		_rechteck(img, Rect2i(2, 6, 12, 4), GOLD)
		for x: int in [2, 7, 12]:
			_rechteck(img, Rect2i(x, 2 if x == 7 else 3, 2, 4), GOLD)
			_kreis(img, Vector2(x + 1, 2 if x == 7 else 3), 1.2, GOLD)
		_rechteck(img, Rect2i(2, 9, 12, 1), GOLD_DUNKEL)
		_kreis(img, Vector2(8, 7.5), 1.2, CYAN)
		_umriss(img)
		_cache["krone"] = ImageTexture.create_from_image(img)
	return _cache["krone"]


## Zusatzform eines Stufe-4-Formturms je Turmart (golden).
static func turm4_zusatz(art: String) -> Texture2D:
	var schluessel := "t4:" + art
	if not _cache.has(schluessel):
		var img := Image.create(14, 14, false, Image.FORMAT_RGBA8)
		match art:
			"frost":   # Eisstern
				_linie(img, Vector2(7, 1), Vector2(7, 13), 2.0, GOLD)
				_linie(img, Vector2(2, 4), Vector2(12, 10), 2.0, GOLD)
				_linie(img, Vector2(2, 10), Vector2(12, 4), 2.0, GOLD)
				_kreis(img, Vector2(7, 7), 1.5, CYAN_HELL)
			"lanze":   # zweite Schiene
				_rechteck(img, Rect2i(1, 5, 12, 2), GOLD)
				_rechteck(img, Rect2i(1, 8, 12, 2), GOLD_DUNKEL)
				_kreis(img, Vector2(12, 6.5), 1.5, CYAN)
			"heil":   # Kreuz
				_rechteck(img, Rect2i(5, 1, 4, 12), GOLD)
				_rechteck(img, Rect2i(1, 5, 12, 4), GOLD)
			"funk":   # Antenne mit Wellen
				_rechteck(img, Rect2i(6, 4, 2, 10), GOLD)
				_kreis(img, Vector2(7, 3), 2.0, CYAN)
				_linie(img, Vector2(2, 2), Vector2(2, 6), 1.0, GOLD)
				_linie(img, Vector2(12, 2), Vector2(12, 6), 1.0, GOLD)
			_:   # Gefechtsturm: drittes Rohr
				_rechteck(img, Rect2i(1, 6, 10, 3), GOLD)
				_kreis(img, Vector2(11, 7.5), 2.0, GOLD_DUNKEL)
				_kreis(img, Vector2(12, 7.5), 1.0, CYAN)
		_umriss(img)
		_cache[schluessel] = ImageTexture.create_from_image(img)
	return _cache[schluessel]


## Sprite2D für eine Krone (ein Kind einer Figur): unten mittig `hoehe` Pixel über dem Fußpunkt.
static func kronen_sprite(hoehe: float, massstab: float = 1.0) -> Sprite2D:
	var s := Sprite2D.new()
	s.name = "Krone"
	s.texture = krone()
	s.centered = false
	s.scale = Vector2(massstab, massstab)
	s.offset = Vector2(-8, -11 - hoehe / massstab)
	return s


# ------------------------------------------------------------------ Truppenturm (Irrtürmer) und MG-Stellung (Sonde 7)

const TT_GROESSE := Vector2i(32, 44)     # Truppenturm: Bildgröße (Pixel, im Spiel zweifach)
const TT_ANKER := Vector2(16, 41)        # Fußpunkt im Bild


## Truppenturm: Kasten mit Tor und Antenne; ab Stufe 2 ein Leuchtband, ab Stufe 3 eine zweite Antenne.
static func truppenturm(stufe: int) -> Texture2D:
	var schluessel := "tt:%d" % clampi(stufe, 1, 4)
	if not _cache.has(schluessel):
		var img := Image.create(TT_GROESSE.x, TT_GROESSE.y, false, Image.FORMAT_RGBA8)
		_rechteck(img, Rect2i(4, 18, 24, 23), LILA_DUNKEL)          # Kasten
		_rechteck(img, Rect2i(5, 19, 22, 21), LILA)
		_rechteck(img, Rect2i(5, 19, 22, 3), LILA_HELL)             # Dachkante
		_rechteck(img, Rect2i(10, 27, 12, 14), UMRISS)              # Tor
		_rechteck(img, Rect2i(11, 28, 10, 13), METALL)
		for y in range(29, 41, 3):
			_rechteck(img, Rect2i(11, y, 10, 1), METALL_HELL)       # Torlamellen
		_rechteck(img, Rect2i(12, 24, 8, 2), CYAN)                  # Licht über dem Tor
		_rechteck(img, Rect2i(15, 6, 2, 13), METALL_HELL)          # Antenne
		_kreis(img, Vector2(16, 5), 2.0, CYAN)
		if stufe >= 2:
			_rechteck(img, Rect2i(5, 22, 22, 1), CYAN)              # Leuchtband
		if stufe >= 3:
			_rechteck(img, Rect2i(7, 10, 1, 9), METALL_HELL)        # zweite Antenne
			_kreis(img, Vector2(7.5, 9.5), 1.5, CYAN_HELL)
		_umriss(img)
		_cache[schluessel] = ImageTexture.create_from_image(img)
	return _cache[schluessel]


## Werkschutz-Punkte über dem Tor: `n` von `max` (volle Punkte cyan, leere dunkel).
static func punkte(n: int, max_n: int) -> Texture2D:
	var schluessel := "pk:%d/%d" % [n, max_n]
	if not _cache.has(schluessel):
		var img := Image.create(maxi(1, max_n) * 5 + 1, 6, false, Image.FORMAT_RGBA8)
		for i in max_n:
			_rechteck(img, Rect2i(1 + i * 5, 1, 4, 4), CYAN if i < n else LILA_DUNKEL)
		_umriss(img)
		_cache[schluessel] = ImageTexture.create_from_image(img)
	return _cache[schluessel]


## MG-Stellung: Brüstung mit Lauf (nach vorn) und Munitionsgurt.
static func mg_aufsatz() -> Texture2D:
	if not _cache.has("mg"):
		var img := Image.create(28, 16, false, Image.FORMAT_RGBA8)
		_rechteck(img, Rect2i(1, 8, 26, 7), METALL)                 # Brüstung
		_rechteck(img, Rect2i(1, 8, 26, 2), METALL_HELL)
		_rechteck(img, Rect2i(9, 4, 10, 5), LILA)                   # Gehäuse
		_rechteck(img, Rect2i(9, 4, 10, 1), LILA_HELL)
		_rechteck(img, Rect2i(18, 5, 9, 2), METALL_HELL)            # Lauf
		_rechteck(img, Rect2i(25, 4, 2, 4), METALL)                 # Mündung
		_kreis(img, Vector2(26.5, 5.5), 1.0, CYAN)
		for i in 5:                                                 # Munitionsgurt
			_rechteck(img, Rect2i(3 + i * 2, 6 + (i % 2), 2, 3), GOLD if i % 2 == 0 else GOLD_DUNKEL)
		_umriss(img)
		_cache["mg"] = ImageTexture.create_from_image(img)
	return _cache["mg"]
