class_name SichererRand
## 19.11.: Sichere Ränder (iPhone im Querformat: Notch seitlich, Home-Balken unten). Die Web-App läuft mit
## viewport-fit=cover bis an den Rand; HUD, Ego-Oberfläche, Touch-Knöpfe und Startmenü werden in die sichere Fläche
## eingepasst (gleichmäßig etwas kleiner, mittig). Am PC sind alle Ränder 0 – dort ändert sich nichts.
## Gerechnet wird in der festen Spielfläche 1280×720 (stretch canvas_items, aspect keep): Was in die schwarzen Balken
## fällt, zählt nicht. Zum Ausprobieren: TD_RAND="links,oben,rechts,unten" in Spielpixeln.

const BREITE := 1280.0
const HOEHE := 720.0

static var _fenster := Vector2i(-1, -1)
static var _raender := Vector4.ZERO   # links, oben, rechts, unten (Spielpixel)
static var _bild := -1


## Ränder in Spielpixeln (je Bild höchstens einmal berechnet; im Browser nur neu, wenn sich die Fenstergröße ändert).
static func raender() -> Vector4:
	var n := Engine.get_process_frames()
	if n == _bild:
		return _raender
	_bild = n
	var sim := OS.get_environment("TD_RAND")
	if sim != "":
		var w := sim.split(",")
		if w.size() == 4:
			_raender = Vector4(float(w[0]), float(w[1]), float(w[2]), float(w[3]))
		return _raender
	var fenster := DisplayServer.window_get_size()
	if fenster == _fenster:
		return _raender
	_fenster = fenster
	_raender = _berechne(Vector2(fenster))
	return _raender


static func _berechne(fenster: Vector2) -> Vector4:
	if fenster.x <= 0.0 or fenster.y <= 0.0:
		return Vector4.ZERO
	var phys := Vector4.ZERO   # Ränder in Fensterpixeln
	if OS.has_feature("web"):
		var js: Variant = JavaScriptBridge.eval("""(function(){var d=document.createElement('div');
d.style.cssText='position:fixed;left:0;top:0;width:0;height:0;visibility:hidden;padding:env(safe-area-inset-top) env(safe-area-inset-right) env(safe-area-inset-bottom) env(safe-area-inset-left)';
document.body.appendChild(d);var c=getComputedStyle(d);
var r=[parseFloat(c.paddingLeft)||0,parseFloat(c.paddingTop)||0,parseFloat(c.paddingRight)||0,parseFloat(c.paddingBottom)||0,window.innerWidth||1];
d.remove();return JSON.stringify(r);})()""", true)
		var r: Variant = JSON.parse_string(str(js)) if js != null else null
		if r is Array and (r as Array).size() == 5:
			var a: Array = r
			var css_zu_fenster := fenster.x / maxf(1.0, float(a[4]))   # Canvas-Pixel je CSS-Pixel
			phys = Vector4(float(a[0]), float(a[1]), float(a[2]), float(a[3])) * css_zu_fenster
	elif OS.has_feature("mobile"):
		# nur Handy/Tablet – am PC meldet Windows die Taskleiste als Rand, dort soll sich nichts ändern
		var sicher := DisplayServer.get_display_safe_area()
		var bild := DisplayServer.screen_get_size()
		if sicher.size.x > 0 and sicher.size != bild:
			phys = Vector4(sicher.position.x, sicher.position.y, bild.x - sicher.end.x, bild.y - sicher.end.y)
	if phys == Vector4.ZERO:
		return Vector4.ZERO
	# Spielfläche im Fenster (aspect keep): Maßstab und schwarze Balken
	var s := minf(fenster.x / BREITE, fenster.y / HOEHE)
	var bx := (fenster.x - BREITE * s) / 2.0
	var by := (fenster.y - HOEHE * s) / 2.0
	return Vector4(maxf(0.0, phys.x - bx) / s, maxf(0.0, phys.y - by) / s, maxf(0.0, phys.z - bx) / s, maxf(0.0, phys.w - by) / s)


## Maßstab (≤ 1), mit dem eine 1280×720-Oberfläche in die sichere Fläche passt.
static func faktor() -> float:
	var r := raender()
	if r == Vector4.ZERO:
		return 1.0
	return minf((BREITE - r.x - r.z) / BREITE, (HOEHE - r.y - r.w) / HOEHE)


## Linke obere Ecke der eingepassten Oberfläche (mittig in der sicheren Fläche).
static func versatz() -> Vector2:
	var r := raender()
	if r == Vector4.ZERO:
		return Vector2.ZERO
	var k := faktor()
	return Vector2(r.x + ((BREITE - r.x - r.z) - BREITE * k) / 2.0, r.y + ((HOEHE - r.y - r.w) - HOEHE * k) / 2.0)


## Control, dessen Inhalt die ganze Spielfläche bei Maßstab `grund` füllt, in die sichere Fläche setzen.
static func einpassen(c: Control, grund: float = 1.0) -> void:
	var k := faktor()
	c.scale = Vector2(grund * k, grund * k)
	c.position = versatz()


## Bildpunkt (Spielfläche) -> Koordinaten der eingepassten Oberfläche, und zurück.
static func nach_innen(p: Vector2) -> Vector2:
	return (p - versatz()) / faktor()


static func nach_aussen(p: Vector2) -> Vector2:
	return p * faktor() + versatz()
