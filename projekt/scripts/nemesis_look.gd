class_name NemesisLook
extends RefCounted
## 25.11. (Paul): Look-Platzhalter der Benannten, bis die Sprite-Varianten da sind. Jede Person hat „look“ 0–9
## (gespeichert): eine Akzentfarbe an Visier und Schulter (Werte.NEMESIS_LOOK_FARBEN) und dazu ein Detail aus Code
## (Werte.NEMESIS_LOOK_DETAILS: Narbe, Antenne, Schulterplatte). Gemalt wird direkt in eine Kopie des Truppenblatts –
## so gilt es in der Draufsicht, in der Ego-Sicht (mit Umriss) und im Hangar gleich. Namenlose haben keinen Look.

static var _cache := {}   # [Blatt, Zelle, Look] -> Texture2D


## Das Blatt `blatt` (quadratische Zellen der Größe `zelle`) im Look `look`. Ohne Look oder ohne Bild: unverändert.
static func bild(blatt: Texture2D, zelle: int, look: int) -> Texture2D:
	if blatt == null or look < 0 or look >= Werte.NEMESIS_LOOK_FARBEN.size() or zelle <= 0:
		return blatt
	var k := [blatt.get_rid().get_id(), zelle, look]
	if _cache.has(k):
		return _cache[k]
	var img := blatt.get_image()
	if img == null:
		return blatt
	img = img.duplicate()
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	for y in range(0, img.get_height() - zelle + 1, zelle):
		for x in range(0, img.get_width() - zelle + 1, zelle):
			_male_zelle(img, Rect2i(x, y, zelle, zelle), Werte.NEMESIS_LOOK_FARBEN[look], str(Werte.NEMESIS_LOOK_DETAILS[look]))
	var aus := ImageTexture.create_from_image(img)
	_cache[k] = aus
	return aus


## Die Figur einer Einheit einkleiden – Stand, Lauf und die Haltung in der Stellung.
static func anziehen(e: Einheit, look: int) -> void:
	if e == null or not is_instance_valid(e) or e._sprite == null or look < 0 or e._sprite.has_meta("nemesis_look"):
		return
	var s: Figur = e._sprite
	s.set_meta("nemesis_look", look)
	var jetzt := s.texture
	for d: Dictionary in [s._normal, s._haltung]:
		if d.has("tex"):
			var alt: Texture2D = d["tex"]
			var neu := bild(alt, int(d["zelle"]), look)
			d["tex"] = neu
			if jetzt == alt:
				s.texture = neu


## Helle grüne und türkise Punkte der oberen Figurhälfte: das Visier (bei allen drei Truppenarten).
static func _ist_visier(c: Color) -> bool:
	return c.a > 0.5 and c.s > 0.3 and c.v > 0.55 and c.h > 0.22 and c.h < 0.56


static func _male_zelle(img: Image, z: Rect2i, farbe: Color, detail: String) -> void:
	var teil := img.get_region(z)
	var u := teil.get_used_rect()
	if u.size.x < 6 or u.size.y < 6:
		return   # leere Zelle oder nur ein Funke
	u.position += z.position
	var visier := Rect2i()
	var gefunden := false
	for y in range(u.position.y, u.position.y + int(u.size.y * 0.55)):
		for x in range(u.position.x, u.end.x):
			var c := img.get_pixel(x, y)
			if _ist_visier(c):
				img.set_pixel(x, y, Color(farbe.r, farbe.g, farbe.b, c.a).lerp(Color(1, 1, 1, c.a), maxf(0.0, c.v - 0.85) * 2.0).darkened(maxf(0.0, 0.85 - c.v)))
				var punkt := Rect2i(x, y, 1, 1)
				visier = visier.merge(punkt) if gefunden else punkt
				gefunden = true
	# Schulter: ein Streifen am linken (hinteren) Rand auf Schulterhöhe
	var sy := u.position.y + int(u.size.y * 0.4)
	var links := -1
	for x in range(u.position.x, u.end.x):
		if img.get_pixel(x, sy).a > 0.5:
			links = x
			break
	if links >= 0:
		for dy in 2:
			for dx in range(1, 5):
				_ueber(img, z, links + dx, sy + dy, farbe if dy == 0 else farbe.darkened(0.35), true)
		if detail == "platte":   # überstehende Schulterplatte mit dunklem Rand
			for dy in range(-3, 3):
				for dx in range(-1, 6):
					var seite: bool = dx == -1 or dx == 5
					if (seite and (dy == -3 or dy == 2)) or (dy == -3 and (dx == 0 or dx == 4)):
						continue   # abgeschrägte Ecken, oben gerundet
					var rand: bool = dy == -3 or dy == 2 or seite or (dy == -2 and (dx == 0 or dx == 4))
					var ton := farbe.lightened(0.35) if dy == -2 else (farbe if dy < 1 else farbe.darkened(0.35))
					_ueber(img, z, links + dx, sy + dy, Color("180f22") if rand else ton, false)
	if detail == "antenne":
		for x in range(u.position.x, u.end.x):
			if img.get_pixel(x, u.position.y).a > 0.5:
				for i in range(1, 6):
					_ueber(img, z, x - int(i / 3.0), u.position.y - i, Color("2a2236"), false)
				_ueber(img, z, x - 2, u.position.y - 6, farbe.lightened(0.3), false)
				_ueber(img, z, x - 1, u.position.y - 6, farbe.lightened(0.3), false)
				break
	elif detail == "narbe" and gefunden:   # heller Riss schräg über das Visier
		var n := clampi(maxi(visier.size.x, visier.size.y), 4, 6)
		var start := visier.position + visier.size / 2 - Vector2i(n / 2, n / 2)
		for i in n:
			_ueber(img, z, start.x + i, start.y + i, Color("ffd9c4"), true)
			_ueber(img, z, start.x + i - 1, start.y + i, Color("5a1f28"), true)


## Punkt setzen, nie über die Zelle hinaus; `nur_figur`: nur wo schon etwas ist.
static func _ueber(img: Image, z: Rect2i, x: int, y: int, farbe: Color, nur_figur: bool) -> void:
	if not z.has_point(Vector2i(x, y)) or (nur_figur and img.get_pixel(x, y).a <= 0.5):
		return
	img.set_pixel(x, y, farbe)
