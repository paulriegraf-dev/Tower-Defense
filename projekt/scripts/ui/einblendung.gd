class_name Einblendung extends Control
## Einblendungen über dem Spielfeld (18.11.), im UI-Raster 640×360 (zweifach skaliert), klickt nichts weg:
##   abrechnung(): Karte „Runde N überstanden“ unter der Rundenanzeige – Posten zählen hoch, die Summe leuchtet.
##   banner(): breites Band quer über die Mitte für große Ereignisse (Gegenangriff, Ersatz-Phantom).

const Stil := preload("res://scripts/ui/ui_stil.gd")
const KARTE_B := 168.0
const KARTE_Y := 44.0
const KARTE_SEK := 5.0
const BANNER_SEK := 3.2

var _posten: Array = []      # [Name, Betrag]
var _titel := ""
var _karte_t := -1.0
var _banner := ""
var _banner_unter := ""
var _banner_farbe := Stil.KUPFER
var _banner_t := -1.0


func _init() -> void:
	size = Vector2(640, 360)
	scale = Vector2(Stil.UI_SKALA, Stil.UI_SKALA)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Rundenabrechnung: `posten` = [[Name, Betrag], …]; Posten mit 0 entfallen.
func abrechnung(titel: String, posten: Array) -> void:
	_titel = titel
	_posten = posten.filter(func(p: Array) -> bool: return int(p[1]) != 0)
	_karte_t = 0.0


func banner(titel: String, unter: String, farbe: Color) -> void:
	_banner = titel
	_banner_unter = unter
	_banner_farbe = farbe
	_banner_t = 0.0


func _process(delta: float) -> void:
	var echt := delta / maxf(Engine.time_scale, 0.01)   # Echtzeit, auch bei Tempo ×2
	if _karte_t >= 0.0:
		_karte_t += echt
		if _karte_t > KARTE_SEK:
			_karte_t = -1.0
	if _banner_t >= 0.0:
		_banner_t += echt
		if _banner_t > BANNER_SEK:
			_banner_t = -1.0
	visible = _karte_t >= 0.0 or _banner_t >= 0.0
	if visible:
		queue_redraw()


static func _aus(x: float) -> float:
	return 1.0 - pow(1.0 - clampf(x, 0.0, 1.0), 3.0)


func _draw() -> void:
	if _karte_t >= 0.0:
		_male_karte()
	if _banner_t >= 0.0:
		_male_banner()


func _male_karte() -> void:
	var t := _karte_t
	var ein := _aus(t / 0.3)
	var aus := 1.0 - clampf((t - (KARTE_SEK - 0.5)) / 0.5, 0.0, 1.0)
	var a := ein * aus
	var h := 22.0 + _posten.size() * 11.0 + 16.0
	var r := Rect2(roundf(320.0 - KARTE_B / 2.0), roundf(KARTE_Y - 10.0 * (1.0 - ein)), KARTE_B, h)
	Stil.platte(self, r, 3.0, Color(0.05, 0.06, 0.09, 0.92 * a), Color(Stil.GOLD, 0.7 * a))
	Stil.schreibe_mittig(self, Vector2(r.get_center().x, r.position.y + 10.0), _titel, Stil.NORMAL, Color(Stil.LEUCHT, a))
	var y := r.position.y + 23.0
	var summe := 0
	for i in _posten.size():
		var p: Array = _posten[i]
		var zaehl := _aus((t - 0.25 - i * 0.18) / 0.45)
		var betrag := roundi(int(p[1]) * zaehl)
		summe += betrag
		Stil.schreibe(self, Vector2(r.position.x + 8.0, y), str(p[0]), Stil.KLEIN, Color(Stil.TEXT_BLASS, a * minf(zaehl * 3.0, 1.0)))
		var w := "+%d" % betrag
		Stil.schreibe(self, Vector2(r.end.x - 8.0 - Stil.breite(w, Stil.KLEIN), y), w, Stil.KLEIN, Color(Stil.TEXT, a * minf(zaehl * 3.0, 1.0)))
		y += 11.0
	draw_rect(Rect2(r.position.x + 6.0, y - 4.0, r.size.x - 12.0, 1.0), Color(Stil.RAHMEN, a))
	var fertig := t > 0.25 + _posten.size() * 0.18 + 0.45
	var glanz := 1.0 + (0.5 * (1.0 - clampf((t - 0.25 - _posten.size() * 0.18 - 0.45) / 0.5, 0.0, 1.0)) if fertig else 0.0)
	var text := "+%d" % summe
	var tw := Stil.breite(text, Stil.NORMAL)
	Stil.symbol(self, "muenze", Vector2(r.end.x - 14.0 - tw, y + 5.0), 1.0, Color(Stil.GOLD, a))
	Stil.schreibe(self, Vector2(r.position.x + 8.0, y + 5.0), "Budget", Stil.NORMAL, Color(Stil.TEXT, a))
	Stil.schreibe(self, Vector2(r.end.x - 8.0 - tw, y + 5.0), text, Stil.NORMAL, Color(Stil.GOLD * glanz, a))


func _male_banner() -> void:
	var t := _banner_t
	var ein := _aus(t / 0.35)
	var aus := 1.0 - clampf((t - (BANNER_SEK - 0.5)) / 0.5, 0.0, 1.0)
	var a := ein * aus
	var hoehe := 30.0 + (12.0 if _banner_unter != "" else 0.0)
	var y := 128.0
	var breite := 640.0 * ein
	draw_rect(Rect2(320.0 - breite / 2.0, y, breite, hoehe), Color(0.04, 0.03, 0.03, 0.82 * aus))
	draw_rect(Rect2(320.0 - breite / 2.0, y, breite, 1.0), Color(_banner_farbe, 0.9 * aus))
	draw_rect(Rect2(320.0 - breite / 2.0, y + hoehe - 1.0, breite, 1.0), Color(_banner_farbe, 0.9 * aus))
	# Warnstreifen links und rechts, laufen nach außen
	for seite: float in [-1.0, 1.0]:
		for i in 6:
			var x := 320.0 + seite * (150.0 + fmod(t * 30.0 + i * 14.0, 84.0))
			draw_rect(Rect2(roundf(x), y + 4.0, 6.0, hoehe - 8.0), Color(_banner_farbe, 0.18 * a))
	var dx := roundf(sin(t * 80.0) * 2.0 * (1.0 - clampf(t / 0.4, 0.0, 1.0)))
	Stil.schreibe_mittig(self, Vector2(320.0 + dx + 1.0, y + 15.0 + 1.0), _banner, 22, Color(_banner_farbe.darkened(0.7), a))
	Stil.schreibe_mittig(self, Vector2(320.0 + dx, y + 15.0), _banner, 22, Color(_banner_farbe, a))
	if _banner_unter != "":
		Stil.schreibe_mittig(self, Vector2(320.0, y + 33.0), _banner_unter, Stil.KLEIN, Color(Stil.TEXT, a))
