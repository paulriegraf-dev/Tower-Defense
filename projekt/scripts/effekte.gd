class_name Effekte
extends Node2D
## Kurzlebige Schusslinien und geworfene Geschosse.

var _linien: Array = []   # [von, nach, farbe, restzeit]
var _wuerfe: Array = []   # [von, nach, vergangen, dauer, bei_einschlag, art, bild, verzoegerung, drehung]
var _wolken: Array = []   # [mitte, radius, restzeit, dauer]
var _spuren: Array = []   # [punkt, restzeit, dauer] – Spur eines Fahnenträgers
var _strahlen: Array = []  # [von, nach, farbe, restzeit, breite]
var _braende: Array = []   # [mitte, radius, restzeit] – Brandfeld eines Plasmawerfers
var _gele: Array = []      # [mitte, radius, restzeit] – Plasmagel
var _warnungen: Array = []  # [mitte, restzeit] – hier landet gleich ein Wurf
var _bolzen: Array = []     # [von, nach, vergangen, radius] – Railgun-Schuss der Batterie (16.11.)
## Leuchtgeschoss mit Höhe (16.11.): [von, von_hoehe, nach, nach_hoehe, farbe, vergangen, dauer, dicke] – Höhen in
## Weltpixeln über dem Boden. In HD-2D zeichnet hd_ansicht.gd sie als leuchtende Sprites in 3D, sonst _draw hier.
var leucht: Array = []
const BOLZEN_FLUG := 0.16   # Sekunden vom Abschuss bis zum Einschlag
const BOLZEN_ZIEL := 0.5    # so lange steht das Zielkreuz am Einschlagort (vor und nach dem Einschlag)
const BATTERIE_FARBE := Color("7fe0ff")


func linie(von: Vector2, nach: Vector2, farbe: Color) -> void:
	_linien.append([von, nach, farbe, 0.08])


## Geschoss im Bogen; `bei_einschlag` wird aufgerufen, wenn es landet (immer nach `dauer` Sekunden).
## art: "stein" (Brocken, zerplatzt in Splitter), "einheit" (die geworfene Figur `typ` überschlägt sich, landet im Staub),
## "granate" (kleine Kugel des Rauchwerfers). `verzoegerung`: so lange bleibt das Geschoss noch im Schleuderarm
## (es fliegt dann schneller, die Landezeit bleibt gleich).
func wurf(von: Vector2, nach: Vector2, dauer: float, bei_einschlag: Callable, art: String = "stein", typ: String = "", verzoegerung: float = 0.0) -> void:
	var bild := {}
	if art == "einheit" and Werte.GEGNER.has(typ):
		var d := Werte.grafik_daten(Werte.GEGNER[typ])
		var zelle := float(d["zelle"])
		bild = {"tex": load(str(d["blatt"])), "quelle": Rect2(0, zelle, zelle, zelle), "massstab": float(d["massstab"]) * (0.85 if Werte.grafik_hd else 1.0)}
	elif art == "stein":
		bild = {"tex": stein_bild(), "quelle": Rect2(0, 0, 12, 12), "massstab": 2.0}
	elif art == "granate":
		bild = {"tex": granate_bild(), "quelle": Rect2(0, 0, 8, 8), "massstab": 2.0}
	var drehung := (1.0 if randf() < 0.5 else -1.0) * (7.0 if art == "einheit" else 9.0)
	_wuerfe.append([von, nach, 0.0, dauer, bei_einschlag, art, bild, minf(verzoegerung, dauer * 0.5), drehung])


## Lage eines Wurfs: [Boden unter dem Geschoss, Höhe in Bildpunkten, Drehwinkel, sichtbar]
func wurf_lage(w: Array) -> Array:
	var verz: float = w[7]
	var t: float = clampf((float(w[2]) - verz) / maxf(0.01, float(w[3]) - verz), 0.0, 1.0)
	var boden: Vector2 = (w[0] as Vector2).lerp(w[1], t)
	var weite: float = (w[0] as Vector2).distance_to(w[1])
	var hoehe := sin(t * PI) * clampf(weite * 0.35, 60.0, 150.0)
	return [boden, hoehe, float(w[2]) * float(w[8]), float(w[2]) >= verz]


func wuerfe() -> Array:
	return _wuerfe


static var _stein: ImageTexture
static var _granate: ImageTexture

## Gesteinsbrocken 12×12 (Pixel ×2), im Code gemalt – kein eigenes Bild nötig.
static func stein_bild() -> ImageTexture:
	if _stein == null:
		var muster := [
			"....aaaa....",
			"..aabbbbaa..",
			".abbccbbbba.",
			".abccccbbba.",
			"abbcccbbbbba",
			"abbbbbbbbdba",
			"abbbbbbbddba",
			"abbbdbbbddba",
			".abbddbbdda.",
			".aabbbbbdaa.",
			"..aaabbaaa..",
			"....aaaa....",
		]
		_stein = ImageTexture.create_from_image(_male(muster, {"a": Color("2a1d14"), "b": Color("7a5a3a"), "c": Color("b08a5a"), "d": Color("4e3a26")}))
	return _stein


static func granate_bild() -> ImageTexture:
	if _granate == null:
		var muster := ["..aaaa..", ".abbbba.", "abccbbba", "abcbbbba", "abbbbbba", "abbbbbda", ".abbdda.", "..aaaa.."]
		_granate = ImageTexture.create_from_image(_male(muster, {"a": Color("16191e"), "b": Color("4a525e"), "c": Color("9aa4b2"), "d": Color("2c323a")}))
	return _granate


static func _male(muster: Array, farben: Dictionary) -> Image:
	var bild := Image.create(muster[0].length(), muster.size(), false, Image.FORMAT_RGBA8)
	for y in muster.size():
		for x in (muster[y] as String).length():
			var c: String = muster[y][x]
			bild.set_pixel(x, y, farben.get(c, Color(0, 0, 0, 0)))
	return bild


## Einschlag: Staubring und Splitter (Stein) bzw. Staubwolke (Einheit); dazu ein kurzes Wackeln der Kamera.
var _splitter: Array = []   # [punkt, geschwindigkeit, vergangen, groesse]
var wackeln := 0.0          # Stärke der Erschütterung (Bildpunkte), klingt schnell ab – die Kameras lesen das
const SPLITTER_SEK := 0.5

func _einschlag(w: Array) -> void:
	var punkt: Vector2 = w[1]
	match str(w[5]):
		"stein":
			welle(punkt, Werte.ZELLE * 0.7, Color("c9a26b"), "staub", 0.45)
			for i in 9:
				var r := Vector2.RIGHT.rotated(TAU * i / 9.0 + randf() * 0.5) * randf_range(90.0, 170.0)
				_splitter.append([punkt, r + Vector2(0, -80), 0.0, randf_range(4.0, 8.0)])
			wackeln = maxf(wackeln, 3.0)
		"einheit":
			welle(punkt, Werte.ZELLE * 0.85, Color("d8bf94"), "staub", 0.55)
			if Werte.grafik_neu:
				fx("rauch", punkt + Vector2(0, 14), 0.16)
			wackeln = maxf(wackeln, 4.0)
		_:
			pass


## Kurzer Kreis für einen Flächentreffer.


## Rauchwolke: Truppen darin können nicht schießen.
func rauch(mitte: Vector2, radius: float, dauer: float) -> void:
	_wolken.append([mitte, radius, dauer, dauer])
	if Werte.grafik_neu:
		fx("rauch", mitte + Vector2(0, radius * 0.45), radius / 170.0)


## Löst die nächste Rauchwolke im Umkreis auf. Gibt ihre Mitte zurück (oder null).
func blase_rauch_weg(von: Vector2, weite: float) -> Variant:
	var beste := -1
	for i in _wolken.size():
		var d: float = (_wolken[i][0] as Vector2).distance_to(von)
		if d <= weite and (beste < 0 or d < (_wolken[beste][0] as Vector2).distance_to(von)):
			beste = i
	if beste < 0:
		return null
	var mitte: Vector2 = _wolken[beste][0]
	_wolken.remove_at(beste)
	_fx = _fx.filter(func(e): return not (e["n"] == "rauch" and (e["pos"] as Vector2).distance_to(mitte) < 160.0))
	return mitte


var schilde: Array = []    # [von, nach, anteil 0..1, aktiv, max. Leben] – Strahl zwischen zwei Erdwällen, vom Spiel jedes Bild gesetzt
var schild_vorschau: Array = []   # [von, nach, geht, Leben] beim Ziehen eines Schilds


## Energieschild als Strahl von Erdwall zu Erdwall (16.11.). In HD-2D steht er als 3D-Wand (hd_ansicht.gd);
## hier zeichnet die Karte ihn flach, dazu die Vorschau beim Ziehen.
func _zeichne_schilde() -> void:
	var t := Time.get_ticks_msec() / 1000.0
	if true:   # in HD-2D liegt das als Leuchtspur am Boden unter der 3D-Wand
		for s in schilde:
			# von Innenseite zu Innenseite der Erdwälle (sonst läge die Leuchtspur in HD-2D über den Blöcken)
			var richtung: Vector2 = ((s[1] as Vector2) - (s[0] as Vector2)).normalized() * Werte.ZELLE * 0.5
			var von: Vector2 = s[0] + richtung
			var nach: Vector2 = s[1] - richtung
			if not s[3]:
				draw_line(von, nach, Color(0.5, 0.9, 1.0, 0.25), 2.0)
				continue
			var puls := 0.75 + 0.25 * sin(t * 4.0)
			draw_line(von, nach, Color(0.35, 0.85, 1.0, 0.25 * puls), 18.0)
			draw_line(von, nach, Color(0.6, 0.95, 1.0, 0.9), 4.0)
			draw_line(von, von.lerp(nach, float(s[2])), Color(1, 1, 1, 0.85), 2.0)
	if schild_vorschau.is_empty():
		return
	var a: Vector2 = schild_vorschau[0]
	var b: Vector2 = schild_vorschau[1]
	var farbe := Color(0.45, 0.9, 1.0) if schild_vorschau[2] else Color(1.0, 0.4, 0.45)
	var h := Werte.ZELLE * 0.5
	draw_rect(Rect2(a - Vector2(h, h), Vector2(h, h) * 2.0), farbe, false, 3.0)
	if a != b:
		draw_line(a, b, Color(farbe, 0.35 + 0.15 * sin(t * 6.0)), 14.0)
		draw_line(a, b, farbe, 3.0)
		draw_rect(Rect2(b - Vector2(h, h), Vector2(h, h) * 2.0), farbe, false, 3.0)


func im_rauch(punkt: Vector2) -> bool:
	for w in _wolken:
		if (w[0] as Vector2).distance_to(punkt) <= w[1]:
			return true
	return false


## Supporttürme (16.11.): sich ausbreitende Wellen am Boden. art: "heil" (grüner Ring mit Schein), "funk" (dünne
## Funkwelle, läuft ständig), "frost" (Eisring mit Nebelflocken). Dazu kleine Plus-Zeichen über geheilten Truppen.
var _ringe: Array = []   # [mitte, radius, farbe, vergangen, dauer, art]
var _pluse: Array = []   # [punkt, vergangen, farbe]
const PLUS_SEK := 0.9

func welle(mitte: Vector2, radius: float, farbe: Color, art: String, dauer: float = 0.8) -> void:
	_ringe.append([mitte, radius, farbe, 0.0, dauer, art])


func plus(punkt: Vector2, farbe: Color) -> void:
	_pluse.append([punkt, 0.0, farbe])


func _zeichne_ringe() -> void:
	for r in _ringe:
		var k: float = r[3] / r[4]
		var e := 1.0 - (1.0 - k) * (1.0 - k)
		var m: Vector2 = r[0]
		var weite: float = r[1] * e
		var f: Color = r[2]
		match str(r[5]):
			"heil":
				draw_circle(m, weite, Color(f, 0.16 * (1.0 - k)))
				draw_arc(m, weite, 0.0, TAU, 48, Color(f, 0.95 * (1.0 - k)), 8.0)
				draw_arc(m, weite * 0.8, 0.0, TAU, 40, Color(f, 0.45 * (1.0 - k)), 4.0)
			"funk":
				var a := 0.85 * (1.0 - k) * minf(1.0, k * 6.0)
				draw_arc(m, weite, 0.0, TAU, 48, Color(f, a), 4.0)
				for i in 16:   # gestrichelt wie ein Funksignal
					var w := TAU * i / 16.0 + k * 0.6
					draw_arc(m, weite + 9.0, w, w + 0.18, 3, Color(f, a * 0.8), 4.0)
			"frost":
				# 17.11.: klarer Frostpuls – eine scharfe Eiskante läuft bis an die Reichweite, darauf acht Eiskristalle,
				# innen nur ein Hauch (statt vieler Nebelflocken)
				var a := 1.0 - k
				draw_circle(m, weite, Color(0.7, 0.9, 1.0, 0.16 * a))
				draw_arc(m, weite, 0.0, TAU, 64, Color(0.05, 0.12, 0.2, 0.55 * a), 10.0)
				draw_arc(m, weite, 0.0, TAU, 64, Color(f.lerp(Color("bfefff"), 0.5), 0.95 * a), 5.0)
				for i in 8:
					var w := TAU * float(i) / 8.0 + k * 0.5
					var p := (m + Vector2.RIGHT.rotated(w) * weite).round()
					var g := 8.0 + 4.0 * (1.0 - k)
					var c := Color(0.92, 0.99, 1.0, a)
					draw_rect(Rect2(p - Vector2(2, g), Vector2(4, g * 2.0)), c)
					draw_rect(Rect2(p - Vector2(g, 2), Vector2(g * 2.0, 4)), c)
					draw_rect(Rect2(p - Vector2(3, 3), Vector2(6, 6)), Color(0.6, 0.9, 1.0, a))
			"staub":
				draw_arc(m, weite, 0.0, TAU, 32, Color(f, 0.7 * (1.0 - k)), 6.0)
				for i in 12:
					var w := TAU * i / 12.0
					var p := m + Vector2(cos(w), sin(w) * 0.6) * weite * 1.1
					var g := 10.0 * (1.0 - k) + 4.0
					draw_rect(Rect2(p - Vector2(g, g) / 2.0, Vector2(g, g)), Color(f, 0.5 * (1.0 - k)))
			"batterie":
				# Lichtscheibe und Druckring genau in Trefferweite, dazu nach außen fliegende Funken
				draw_circle(m, weite, Color(f, 0.28 * (1.0 - k)))
				draw_arc(m, weite, 0.0, TAU, 48, Color(f, 1.0 - k), 7.0)
				draw_arc(m, weite * 0.7, 0.0, TAU, 40, Color(Color.WHITE, 0.6 * (1.0 - k)), 3.0)
				for i in 14:
					var zufall := fposmod(sin(float(i) * 12.9898 + m.x * 0.013) * 43758.5, 1.0)
					var w := TAU * (float(i) + zufall * 0.6) / 14.0
					var p: Vector2 = m + Vector2.RIGHT.rotated(w) * float(r[1]) * (0.3 + 0.9 * e) * (0.8 + 0.3 * zufall)
					var g := 7.0 * (1.0 - k) + 2.0
					draw_rect(Rect2(p - Vector2(g, g) / 2.0, Vector2(g, g)), Color(Color.WHITE if i % 3 == 0 else f, 0.9 * (1.0 - k)))
			_:
				draw_arc(m, weite, 0.0, TAU, 48, Color(f, 1.0 - k), 3.0)
	for p in _pluse:
		var k: float = p[1] / PLUS_SEK
		var o: Vector2 = (p[0] as Vector2) + Vector2(0, -30 - 26.0 * k)
		var c := Color(p[2], 1.0 - k * k)
		draw_rect(Rect2(o + Vector2(-3, -10), Vector2(6, 20)), c)
		draw_rect(Rect2(o + Vector2(-10, -3), Vector2(20, 6)), c)


## Kurzer Kreis für einen Flächentreffer.
func flaeche(mitte: Vector2, radius: float, farbe: Color) -> void:
	for i in 12:
		linie(mitte + Vector2.RIGHT.rotated(TAU * i / 12.0) * radius, mitte + Vector2.RIGHT.rotated(TAU * (i + 1) / 12.0) * radius, farbe)


## Warnkreis am Landepunkt eines Wurfs.
func warnung(mitte: Vector2, dauer: float) -> void:
	_warnungen.append([mitte, dauer])


func leeren() -> void:
	_splitter.clear()
	wackeln = 0.0
	_ringe.clear()
	_pluse.clear()
	_warnungen.clear()
	_linien.clear()
	_wuerfe.clear()
	_wolken.clear()
	_spuren.clear()
	_strahlen.clear()
	_bolzen.clear()
	leucht.clear()
	_braende.clear()
	_gele.clear()
	_fx.clear()
	_geschosse.clear()


func _physics_process(_takt: float) -> void:
	var delta := Werte.sim_schritt()   # 9a: feste Schrittweite, unabhaengig von Tempo und Bildrate
	for l in leucht:
		l[5] += delta
	leucht = leucht.filter(func(l): return l[5] < l[6])
	for b in _bolzen:
		var vorher: float = b[2]
		b[2] += delta
		if vorher < BOLZEN_FLUG and b[2] >= BOLZEN_FLUG:
			_bolzen_einschlag(b)
	_bolzen = _bolzen.filter(func(b): return b[2] < BOLZEN_FLUG + BOLZEN_ZIEL)
	for r in _ringe:
		r[3] += delta
	_ringe = _ringe.filter(func(r): return r[3] < r[4])
	for p in _pluse:
		p[1] += delta
	_pluse = _pluse.filter(func(p): return p[1] < PLUS_SEK)
	for w in _warnungen:
		w[1] -= delta
	_warnungen = _warnungen.filter(func(w): return w[1] > 0.0)
	for l in _linien:
		l[3] -= delta
	_linien = _linien.filter(func(l): return l[3] > 0.0)
	for s in _spuren:
		s[1] -= delta
	_spuren = _spuren.filter(func(s): return s[1] > 0.0)
	for s in _strahlen:
		s[3] -= delta
	_strahlen = _strahlen.filter(func(s): return s[3] > 0.0)
	for b in _braende:
		b[2] -= delta
	_braende = _braende.filter(func(b): return b[2] > 0.0)
	for b in _gele:
		b[2] -= delta
	_gele = _gele.filter(func(b): return b[2] > 0.0)
	for w in _wolken:
		w[2] -= delta
	_wolken = _wolken.filter(func(w): return w[2] > 0.0)
	var gelandet: Array = []
	for w in _wuerfe:
		w[2] += delta
		if w[2] >= w[3]:
			gelandet.append(w)
	if not _fx.is_empty() or not _geschosse.is_empty():
		_fx_weiter(delta)
	for w in gelandet:
		_wuerfe.erase(w)
		_einschlag(w)
		(w[4] as Callable).call()
	for sp in _splitter:
		sp[2] += delta
		sp[1] += Vector2(0, 520.0) * delta
		sp[0] += (sp[1] as Vector2) * delta
	_splitter = _splitter.filter(func(sp): return sp[2] < SPLITTER_SEK)
	wackeln = maxf(0.0, wackeln - delta * 14.0)
	queue_redraw()


## Ein Stück Spur hinter einem Fahnenträger (verblasst über `dauer` Sekunden).
func spur(punkt: Vector2, dauer: float) -> void:
	_spuren.append([punkt, dauer, dauer])


## Railgun-Batterie (16.11.): Mündungsblitz, ein heller Bolzen mit Schweif fliegt zum Ziel, dort steht ein Zielkreuz
## mit dem echten Wirkungsradius; beim Einschlag Lichtscheibe, Druckring in Trefferweite, Funken und ein kurzes Beben.
func batterie_schuss(von: Vector2, nach: Vector2, radius: float) -> void:
	_bolzen.append([von, nach, 0.0, radius])
	leuchtschuss(von, 46.0, nach, 8.0, BATTERIE_FARBE, BOLZEN_FLUG, 22.0)


## Leuchtgeschoss von `von` (Höhe `von_h` über dem Boden) nach `nach` (Höhe `nach_h`) in `dauer` Sekunden.
func leuchtschuss(von: Vector2, von_h: float, nach: Vector2, nach_h: float, farbe: Color, dauer: float, dicke: float) -> void:
	leucht.append([von, von_h, nach, nach_h, farbe, 0.0, maxf(dauer, 0.01), dicke])


## Lage eines Leuchtgeschosses im Anteil `t` (0..1) seines Flugs: [Bodenpunkt, Höhe].
static func leucht_lage(l: Array, t: float) -> Array:
	t = clampf(t, 0.0, 1.0)
	return [(l[0] as Vector2).lerp(l[2], t), lerpf(l[1], l[3], t)]


func _bolzen_einschlag(b: Array) -> void:
	var m: Vector2 = b[1]
	welle(m, b[3], BATTERIE_FARBE, "batterie", 0.55)
	welle(m, b[3] * 0.55, Color.WHITE, "", 0.25)
	wackeln = maxf(wackeln, 3.0)


func _zeichne_bolzen() -> void:
	for b in _bolzen:
		var von: Vector2 = b[0]
		var nach: Vector2 = b[1]
		var t: float = b[2]
		var r: float = b[3]
		var flug := clampf(t / BOLZEN_FLUG, 0.0, 1.0)
		# Zielkreuz mit Wirkungsradius: zieht sich bis zum Einschlag zusammen, steht dann kurz und verblasst
		var nach_t := maxf(0.0, t - BOLZEN_FLUG)
		var a := 1.0 - nach_t / BOLZEN_ZIEL
		var rr := r * (1.25 - 0.25 * flug)
		draw_arc(nach, rr, 0.0, TAU, 40, Color(BATTERIE_FARBE, 0.75 * a), 3.0)
		for i in 4:
			var w := TAU * i / 4.0 + PI / 4.0
			var d := Vector2.RIGHT.rotated(w)
			draw_line(nach + d * rr * 0.55, nach + d * rr * 0.95, Color(BATTERIE_FARBE, 0.9 * a), 4.0)
		draw_rect(Rect2(nach - Vector2(3, 3), Vector2(6, 6)), Color(Color.WHITE, 0.9 * a))
		if t < BOLZEN_FLUG + 0.12 and not Werte.grafik_hd:
			# Mündungsblitz
			if t < 0.08:
				draw_circle(von, 14.0 * (1.0 - t / 0.08) + 4.0, Color(Color.WHITE, 0.8))
				draw_circle(von, 22.0 * (1.0 - t / 0.08) + 6.0, Color(BATTERIE_FARBE, 0.45))
			# Bahn: dünne Spur über die ganze Strecke, die schnell verglimmt
			var spur_a := clampf(1.0 - (t - BOLZEN_FLUG) / 0.12, 0.0, 1.0) if t > BOLZEN_FLUG else 1.0
			draw_line(von, von.lerp(nach, flug), Color(BATTERIE_FARBE, 0.35 * spur_a), 6.0)
			draw_line(von, von.lerp(nach, flug), Color(Color.WHITE, 0.5 * spur_a), 2.0)


func strahl(von: Vector2, nach: Vector2, farbe: Color, breite: float) -> void:
	_strahlen.append([von, nach, farbe, 0.09, breite])


# ------------------------------------------------------------ Bodeneffekte (17.11. abends)
## Brandfeld, Plasmagel und der Bodenrand der Rauchwolke liegen auf dem Boden: Sie werden in eine eigene Ebene gezeichnet,
## die in HD-2D zur Karte gehört (also unter Mauern und Figuren liegt, statt in der Luft über allem). Felder mit Erdwall
## oder Bau spart die Fläche aus – liegt eine Lache neben einer Mauer, sieht man sie nur auf den freien Feldern.
class BodenEbene extends Node2D:
	var malen: Callable
	func _draw() -> void:
		if malen.is_valid():
			malen.call()

var _boden: BodenEbene


func _ready() -> void:
	_boden = BodenEbene.new()
	_boden.name = "Bodeneffekte"
	_boden.malen = _male_boden
	_haenge_boden.call_deferred()


func _haenge_boden() -> void:
	var spiel := get_parent()
	if spiel == null or _boden.is_inside_tree():
		return
	spiel.add_child(_boden)
	var k = spiel.get("karte")
	if k != null and (k as Node).get_parent() == spiel:
		spiel.move_child(_boden, (k as Node).get_index() + 1)   # gleich über der Karte, unter Figuren und Effekten


func _boden_pflegen() -> void:
	if _boden == null or not _boden.is_inside_tree():
		return
	var hd = get_parent().get("hd")
	_boden.visibility_layer = HdAnsicht.SCHICHT_KARTE if hd != null else visibility_layer
	_boden.queue_redraw()


func _male_boden() -> void:
	var jetzt := Time.get_ticks_msec() / 1000.0
	for w in _wolken:
		_zeichne_rauch_boden(w[0], w[1], w[2], w[3], jetzt)
	for b in _braende:
		_zeichne_brand(b[0], b[1], b[2], jetzt)
	for b in _gele:
		_zeichne_gel(b[0], b[1], b[2], jetzt)
	var sp := get_parent()
	if sp != null and sp.has_method("mg_huelsen_punkte"):
		# 20.11. (Paul): MG-Stellung, Hülsenregen – liegende Hülsen als kleine goldene Stäbchen
		for p: Vector2 in sp.mg_huelsen_punkte():
			var q := p.round()
			_boden.draw_rect(Rect2(q + Vector2(-3, -1), Vector2(6, 3)), Color("6b4a12"))
			_boden.draw_rect(Rect2(q + Vector2(-2, -1), Vector2(4, 2)), Color("ffd34d"))


func _karte() -> Karte:
	return get_parent().get("karte") as Karte if get_parent() != null else null


## Liegt der Punkt auf einem Feld, das die Bodenfläche aussparen soll (Erdwall oder Bau)?
func _verdeckt(p: Vector2) -> bool:
	var k := _karte()
	return k != null and k.feld.has(k.zelle_bei(p))


## Fläche nur auf freien Feldern zeichnen: das Vieleck wird mit jedem freien Feld im Umkreis geschnitten.
func _flaeche_frei(punkte: PackedVector2Array, farbe: Color) -> void:
	var k := _karte()
	if k == null:
		_boden.draw_colored_polygon(punkte, farbe)
		return
	var box := Rect2(punkte[0], Vector2.ZERO)
	for p in punkte:
		box = box.expand(p)
	var a := k.zelle_bei(box.position)
	var b := k.zelle_bei(box.end)
	var frei := true
	for x in range(a.x, b.x + 1):
		for y in range(a.y, b.y + 1):
			if k.feld.has(Vector2i(x, y)):
				frei = false
	if frei:
		_boden.draw_colored_polygon(punkte, farbe)
		return
	var z := float(Werte.ZELLE)
	for x in range(a.x, b.x + 1):
		for y in range(a.y, b.y + 1):
			if k.feld.has(Vector2i(x, y)):
				continue
			var o := k.mitte(Vector2i(x, y)) - Vector2(z, z) * 0.5
			var feld := PackedVector2Array([o, o + Vector2(z, 0), o + Vector2(z, z), o + Vector2(0, z)])
			for teil in Geometry2D.intersect_polygons(punkte, feld):
				if (teil as PackedVector2Array).size() >= 3 \
						and not Geometry2D.triangulate_polygon(teil).is_empty():
					_boden.draw_colored_polygon(teil, farbe)


## Randlinie in Stücken, Stücke über Mauerfeldern fallen weg.
func _rand_frei(punkte: PackedVector2Array, farbe: Color, breite: float) -> void:
	for i in punkte.size():
		var p := punkte[i]
		var q := punkte[(i + 1) % punkte.size()]
		if not _verdeckt((p + q) * 0.5):
			_boden.draw_line(p, q, farbe, breite)


func _kreis(m: Vector2, r: float, n: int = 28) -> PackedVector2Array:
	var punkte := PackedVector2Array()
	for i in n:
		var w := TAU * float(i) / float(n)
		punkte.append(m + Vector2(cos(w), sin(w)) * r)
	return punkte


## Brandfeld – klar umrissene Glutfläche mit gestricheltem Rand, darauf Flammenzungen an festen Plätzen.
func _zeichne_brand(m: Vector2, r: float, rest: float, t: float) -> void:
	var alter := Werte.BRANDFELD_SEK - rest
	var a := clampf(alter / 0.15, 0.0, 1.0) * clampf(rest / 0.6, 0.0, 1.0)
	_flaeche_frei(_kreis(m, r), Color(0.9, 0.25, 0.04, 0.38 * a))
	_flaeche_frei(_kreis(m, r * 0.55, 20), Color(1.0, 0.5, 0.1, 0.28 * a))
	for i in 16:
		var w0 := TAU * float(i) / 16.0 + t * 0.5
		var mitte_w := w0 + TAU / 64.0
		if _verdeckt(m + Vector2(cos(mitte_w), sin(mitte_w)) * r):
			continue
		_boden.draw_arc(m, r, w0, w0 + TAU / 32.0, 3, Color(1.0, 0.55, 0.15, 0.9 * a), 5.0)
	for i in 7:
		var z := fposmod(sin(float(i) * 12.9898 + m.x * 0.071 + m.y * 0.013) * 43758.5453, 1.0)
		var w := TAU * (float(i) + z) / 7.0
		var p := (m + Vector2(cos(w), sin(w) * 0.8) * r * (0.2 + 0.6 * z)).round()
		if _verdeckt(p):
			continue
		var h := roundf((20.0 + 12.0 * z) * (0.7 + 0.3 * sin(t * 13.0 + float(i) * 1.7)) * a)
		if h < 3.0:
			continue
		_boden.draw_rect(Rect2(p + Vector2(-8, -roundf(h * 0.45)), Vector2(16, roundf(h * 0.45))), Color(0.95, 0.3, 0.05, 0.9 * a))
		_boden.draw_rect(Rect2(p + Vector2(-5, -roundf(h * 0.8)), Vector2(10, roundf(h * 0.4))), Color(1.0, 0.62, 0.12, 0.95 * a))
		_boden.draw_rect(Rect2(p + Vector2(-2, -h), Vector2(4, roundf(h * 0.25))), Color(1.0, 0.92, 0.55, a))


## Plasmagel – grüne Lache mit weich wabernder Kante und deutlichem Rand, darin platzende Blasen.
func _zeichne_gel(m: Vector2, r: float, rest: float, t: float) -> void:
	var alter := Werte.PLASMAGEL_SEK - rest
	var aus := clampf(rest / 0.6, 0.0, 1.0)
	var r_jetzt := r * lerpf(0.6, 1.0, clampf(alter / 0.2, 0.0, 1.0)) * lerpf(0.85, 1.0, aus)
	var saat := m.x * 0.053 + m.y * 0.031
	var punkte := PackedVector2Array()
	for i in 24:
		var w := TAU * float(i) / 24.0
		var rr := r_jetzt * (0.93 + 0.07 * sin(w * 3.0 + saat + t * 2.2))
		punkte.append(m + Vector2(cos(w), sin(w)) * rr)
	_flaeche_frei(punkte, Color(0.25, 0.9, 0.45, 0.42 * aus))
	_rand_frei(punkte, Color(0.05, 0.25, 0.1, 0.65 * aus), 8.0)
	_rand_frei(punkte, Color(0.55, 1.0, 0.65, 0.95 * aus), 4.0)
	for i in 5:
		var z := fposmod(sin(float(i) * 78.233 + saat * 10.0) * 43758.5453, 1.0)
		var w := TAU * (float(i) + z) / 5.0
		var p := (m + Vector2(cos(w), sin(w)) * r_jetzt * (0.2 + 0.55 * z)).round()
		if _verdeckt(p):
			continue
		var phase := fposmod(t * 0.9 + z, 1.0)
		var g := 4.0 + 7.0 * phase
		_boden.draw_arc(p, g, 0.0, TAU, 12, Color(0.75, 1.0, 0.8, (1.0 - phase) * 0.95 * aus), 3.0)


## Rauchwolke am Boden (17.11. abends): Wirkungsbereich als grau-violette Fläche mit gestricheltem Rand, dazu ein
## Ring, der abläuft, solange der Rauch noch wirkt. Gilt auch auf Mauerfeldern (die Truppen dort sind ja betroffen),
## deshalb wird hier nichts ausgespart.
func _zeichne_rauch_boden(m: Vector2, r: float, rest: float, dauer: float, t: float) -> void:
	var a := clampf((dauer - rest) / 0.25, 0.0, 1.0) * clampf(rest / 0.5, 0.0, 1.0)
	_boden.draw_colored_polygon(_kreis(m, r, 36), Color(0.55, 0.52, 0.62, 0.3 * a))
	for i in 20:
		var w0 := TAU * float(i) / 20.0 - t * 0.35
		_boden.draw_arc(m, r, w0, w0 + TAU / 40.0, 3, Color(0.85, 0.82, 0.95, 0.85 * a), 4.0)
	# Restzeit als Ring nach innen versetzt
	var anteil := clampf(rest / maxf(dauer, 0.01), 0.0, 1.0)
	_boden.draw_arc(m, r - 10.0, -PI / 2.0, -PI / 2.0 + TAU * anteil, 48, Color(0.95, 0.92, 1.0, 0.6 * a), 3.0)
	# in der Mitte: durchgestrichenes Fadenkreuz = hier kann keine Truppe schießen
	var f := Color(1.0, 0.85, 0.9, 0.8 * a)
	_boden.draw_circle(m, 22.0, Color(0.12, 0.08, 0.16, 0.55 * a))
	_boden.draw_arc(m, 16.0, 0.0, TAU, 24, f, 3.0)
	for d in [Vector2(1, 0), Vector2(0, 1)]:
		_boden.draw_line(m + d * 9.0, m + d * 21.0, f, 3.0)
		_boden.draw_line(m - d * 9.0, m - d * 21.0, f, 3.0)
	_boden.draw_line(m + Vector2(-17, -17), m + Vector2(17, 17), Color(1.0, 0.35, 0.4, 0.95 * a), 4.0)


## Rauch in der Luft (Deckschicht): dicke, langsam quellende Schwaden über dem ganzen Bereich – durchscheinend genug,
## dass man die Truppen darunter noch erkennt.
func _zeichne_rauch_schwaden(m: Vector2, r: float, rest: float, dauer: float, t: float) -> void:
	var a := clampf((dauer - rest) / 0.35, 0.0, 1.0) * clampf(rest / 0.8, 0.0, 1.0)
	var alter := dauer - rest
	var auf := lerpf(0.55, 1.0, clampf(alter / 0.5, 0.0, 1.0))
	var saat := m.x * 0.041 + m.y * 0.067
	for i in 14:
		var z := fposmod(sin(float(i) * 45.164 + saat) * 43758.5453, 1.0)
		var z2 := fposmod(sin(float(i) * 91.711 + saat * 3.0) * 24634.6345, 1.0)
		var w := TAU * (float(i) + z) / 14.0 + t * (0.08 + 0.05 * z)
		var abst := r * auf * (0.15 + 0.62 * z2)
		var p := m + Vector2(cos(w), sin(w) * 0.85) * abst + Vector2(0, -6.0 * sin(t * 0.9 + z * 6.0))
		var g := r * (0.26 + 0.12 * z) * auf * (1.0 + 0.06 * sin(t * 1.3 + float(i)))
		var hell := 0.62 + 0.18 * z2
		draw_circle(p, g, Color(hell, hell * 0.97, hell + 0.06, 0.2 * a))
		draw_circle(p + Vector2(-g * 0.2, -g * 0.25), g * 0.62, Color(hell + 0.12, hell + 0.1, hell + 0.16, 0.16 * a))


func brand(mitte: Vector2, radius: float, dauer: float) -> void:
	_braende.append([mitte, radius, dauer])


func gel(mitte: Vector2, radius: float, dauer: float) -> void:
	_gele.append([mitte, radius, dauer])


func _draw() -> void:
	_zeichne_schilde()
	_zeichne_ringe()
	_zeichne_bolzen()
	if not Werte.grafik_hd:
		for l in leucht:
			var t: float = l[5] / l[6]
			var kopf: Array = leucht_lage(l, t)
			var schweif: Array = leucht_lage(l, t - 0.35)
			var a: Vector2 = schweif[0] + Vector2(0, -float(schweif[1]))
			var b: Vector2 = kopf[0] + Vector2(0, -float(kopf[1]))
			draw_line(a, b, Color(l[4], 0.5), float(l[7]) * 0.6)
			draw_line(a.lerp(b, 0.5), b, Color.WHITE, float(l[7]) * 0.25)
			draw_circle(b, float(l[7]) * 0.3, Color.WHITE)
	for w in _warnungen:
		var m: Vector2 = w[0]
		var puls := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 90.0)
		draw_arc(m, Werte.ZELLE * 0.55, 0.0, TAU, 28, Color(1.0, 0.25, 0.3, 0.55 + 0.4 * puls), 3.0)
		draw_arc(m, Werte.ZELLE * 0.3, 0.0, TAU, 20, Color(1.0, 0.25, 0.3, 0.35 + 0.3 * puls), 2.0)
		draw_line(m + Vector2(-8, -8), m + Vector2(8, 8), Color(1.0, 0.3, 0.3, 0.9), 3.0)
		draw_line(m + Vector2(8, -8), m + Vector2(-8, 8), Color(1.0, 0.3, 0.3, 0.9), 3.0)
	var jetzt := Time.get_ticks_msec() / 1000.0
	_boden_pflegen()   # Brandfeld, Plasmagel, Rauch-Bodenrand: eigene Bodenebene (siehe oben)
	if Werte.grafik_neu:
		for w in _wolken:
			_zeichne_rauch_schwaden(w[0], w[1], w[2], w[3], jetzt)
	for s in _strahlen:
		draw_line(s[0], s[1], Color(s[2], 0.35), s[4] + 4.0)
		draw_line(s[0], s[1], s[2], s[4])
	for s in _spuren:
		var anteil := clampf(s[1] / s[2], 0.0, 1.0)
		draw_rect(Rect2(s[0] + Vector2(-10, 6), Vector2(20, 8)), Color(1.0, 0.35, 0.82, 0.38 * anteil))
		draw_rect(Rect2(s[0] + Vector2(-4, 8), Vector2(8, 4)), Color(1.0, 0.8, 0.95, 0.5 * anteil))
	for w in (_wolken if not Werte.grafik_neu else []):
		# grob gerasterte Wolke, die zum Ende hin ausdünnt
		var staerke := clampf(w[2] / 1.0, 0.0, 1.0) * 0.55
		var r: float = w[1]
		var schritt := 16.0
		var y := -r
		while y < r:
			var x := -r
			while x < r:
				if Vector2(x + 8, y + 8).length() <= r:
					var hell := 0.75 + 0.15 * sin((x * 0.13) + (y * 0.21))
					draw_rect(Rect2((w[0] as Vector2) + Vector2(x, y), Vector2(schritt, schritt)), Color(hell, hell, hell + 0.03, staerke))
				x += schritt
			y += schritt
	for l in _linien:
		draw_line(l[0], l[1], l[2], 2.0)
		draw_rect(Rect2(l[1] - Vector2(3, 3), Vector2(6, 6)), l[2])
	for w in _wuerfe:
		var lage := wurf_lage(w)
		if not lage[3]:
			continue
		var boden: Vector2 = lage[0]
		var hoehe: float = lage[1]
		var schatten := lerpf(1.0, 0.45, hoehe / 150.0)
		draw_set_transform(boden, 0.0, Vector2(1.0, 0.45))
		draw_circle(Vector2.ZERO, 20.0 * schatten, Color(0, 0, 0, 0.4 * schatten))   # Schatten wird kleiner, je höher
		draw_set_transform(Vector2.ZERO)
		if Werte.grafik_hd or (w[6] as Dictionary).is_empty():
			continue   # HD-2D: das Geschoss selbst fliegt als Sprite3D in echter Höhe (hd_ansicht.gd)
		var b: Dictionary = w[6]
		var q: Rect2 = b["quelle"]
		var gr: Vector2 = q.size * float(b["massstab"])
		draw_set_transform(boden + Vector2(0, -hoehe - gr.y * 0.4), float(lage[2]), Vector2.ONE)
		draw_texture_rect_region(b["tex"], Rect2(-gr / 2.0, gr), q)
		draw_set_transform(Vector2.ZERO)
	for sp in _splitter:
		var k: float = sp[2] / SPLITTER_SEK
		var g: float = sp[3]
		draw_rect(Rect2((sp[0] as Vector2) - Vector2(g, g) / 2.0, Vector2(g, g)), Color(Color("7a5a3a"), 1.0 - k * k))
	_zeichne_fx()


# --- Neue Grafik: PixelFX-Effekte als Bildfolgen (16.11.) -------------------------------------
# Name -> [Datei, Bildbreite, Bildhöhe, Bilder, Spalten, Anker x, Anker y, Bilder je Sekunde, Schleife, höchstens Bilder]
# Ein Pixel im Blatt = 2 Bildpunkte im Spiel (wie die Truppen); `groesse` skaliert zusätzlich.
# 19.11.: Optional [10] = Teiler – das Blatt liegt in 1/Teiler Auflösung vor und wird so viel größer gezeichnet (Maße und
# Anker in Blattpixeln). Rauch, Sprengung und Gegner-Tod sind halbiert: zusammen ~23 MB weniger Grafikspeicher (Handy).
const FX := {
	"muendung": ["muendung", 96, 72, 55, 7, 44, 40, 30, false, 18],
	"treffer_c": ["treffer_c", 136, 80, 16, 4, 44, 44, 30, false, 0],
	"treffer_g": ["treffer_g", 136, 80, 16, 4, 44, 44, 30, false, 0],
	"treffer_p": ["treffer_p", 136, 80, 16, 4, 44, 44, 30, false, 0],
	"laser": ["laser", 128, 32, 15, 2, 108, 16, 30, true, 0],
	"plasma": ["plasma", 144, 60, 24, 4, 108, 30, 30, true, 0],
	"sph": ["sph", 128, 32, 15, 2, 108, 16, 30, true, 0],
	"g_tod": ["g_tod", 112, 92, 33, 6, 56, 80, 20, false, 0],
	"v_tod": ["v_tod", 112, 100, 35, 6, 56, 50, 20, false, 0, 2],
	"spreng": ["spreng", 130, 120, 55, 8, 65, 103, 15, false, 0, 2],
	"heil": ["heil", 256, 136, 45, 5, 128, 104, 15, false, 0],
	"rauch": ["rauch", 130, 88, 61, 7, 65, 78, 12, false, 0, 2],
}
var _fx_blaetter := {}
var _fx: Array = []        # {"n", "pos", "t", "gr", "flip", "rot"} – einmalige Effekte
var _geschosse: Array = []  # {"n", "von", "nach", "t", "dauer", "gr", "bei"} – fliegende Effekte


func _fx_blatt(n: String) -> Texture2D:
	if not _fx_blaetter.has(n):
		_fx_blaetter[n] = load(Werte.NEU + "fx/%s.png" % str(FX[n][0]))
	return _fx_blaetter[n]


## Einmaliger Effekt an `pos` (Ankerpunkt laut Blatt, meist der Boden).
func fx(n: String, pos: Vector2, groesse: float = 1.0, spiegeln: bool = false) -> void:
	_fx.append({"n": n, "pos": pos, "t": 0.0, "gr": groesse, "flip": spiegeln, "rot": 0.0})


## Fliegender Effekt von `von` nach `nach` (Tempo in Bildpunkten je Sekunde); `bei_einschlag` beim Ankommen.
func geschoss(n: String, von: Vector2, nach: Vector2, tempo: float, groesse: float, bei_einschlag: Callable = Callable()) -> void:
	_geschosse.append({"n": n, "von": von, "nach": nach, "t": 0.0, "dauer": maxf(0.02, von.distance_to(nach) / tempo), "gr": groesse, "bei": bei_einschlag})


## Schuss in der neuen Grafik, je nach Schussfarbe: Laser (Scharfschütze), Plasma, Laser der Battlesphäre oder Feuerstoß.
func neu_schuss(von: Vector2, nach: Vector2, farbe: Color) -> void:
	var links := nach.x < von.x
	match farbe.to_html(false):
		"9dff8a":
			geschoss("laser", von, nach, 1100.0, 0.5, fx.bind("treffer_g", nach, 0.5, links))
		"ff8ad8":
			geschoss("plasma", von, nach, 520.0, 0.5, fx.bind("treffer_p", nach, 0.55, links))
		"ff7ad9", "ff3ad0":
			strahl(von, nach, Color("ff4fd8"), 2.0)
			geschoss("sph", von, nach, 1300.0, 0.5, fx.bind("treffer_p", nach, 0.45, links))
		_:
			linie(von, nach, farbe)
			fx("muendung", von, 0.4, links)
			fx("treffer_c", nach, 0.45, links)


func _fx_weiter(delta: float) -> void:
	for e: Dictionary in _fx:
		e["t"] = float(e["t"]) + delta
	_fx = _fx.filter(func(e): return int(float(e["t"]) * float(FX[e["n"]][7])) < _fx_ende(e["n"]))
	var angekommen: Array = []
	for g: Dictionary in _geschosse:
		g["t"] = float(g["t"]) + delta
		if float(g["t"]) >= float(g["dauer"]):
			angekommen.append(g)
	for g: Dictionary in angekommen:
		_geschosse.erase(g)
		if (g["bei"] as Callable).is_valid():
			(g["bei"] as Callable).call()


func _fx_ende(n: String) -> int:
	var d: Array = FX[n]
	return int(d[9]) if int(d[9]) > 0 else int(d[3])


func _fx_bild(n: String, bild: int, pos: Vector2, gr: float, spiegeln: bool, winkel: float) -> void:
	var d: Array = FX[n]
	var b := bild % int(d[3])
	var w := float(d[1])
	var h := float(d[2])
	var quelle := Rect2((b % int(d[4])) * w, (b / int(d[4])) * h, w, h)
	var s := 2.0 * gr * (float(d[10]) if d.size() > 10 else 1.0)
	draw_set_transform(pos, winkel, Vector2(s * (-1.0 if spiegeln else 1.0), s))
	draw_texture_rect_region(_fx_blatt(n), Rect2(-float(d[5]), -float(d[6]), w, h), quelle)


func _zeichne_fx() -> void:
	for e: Dictionary in _fx:
		_fx_bild(e["n"], int(float(e["t"]) * float(FX[e["n"]][7])), e["pos"], e["gr"], e["flip"], 0.0)
	for g: Dictionary in _geschosse:
		var p: Vector2 = (g["von"] as Vector2).lerp(g["nach"], clampf(float(g["t"]) / float(g["dauer"]), 0.0, 1.0))
		_fx_bild(g["n"], int(float(g["t"]) * 30.0), p, g["gr"], false, ((g["nach"] as Vector2) - (g["von"] as Vector2)).angle())
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
