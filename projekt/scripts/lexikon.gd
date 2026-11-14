class_name Lexikon
extends Control
## Übersicht [I]: Karten für Gegner, eigene Truppen und Bauten – was sie tun und was dagegen hilft.
## Aufbau nach dem Muster von Bloons TD: Kartenraster, Reiter unten, Einzelheiten zur gewählten Karte rechts.
## Zahlen kommen aus werte.gd und stimmen deshalb immer; die Texte stehen hier unten in _baue_daten().

const REITER := ["Gegner", "Truppen", "Bauten"]

const DUNKEL := Color(0.04, 0.09, 0.16, 0.93)
const KARTE_BLAU := Color("3d97dd")
const KARTE_HELL := Color("58b2f2")
const KARTE_KOPF := Color("2a78c2")
const RAND := Color("17467e")
const GOLD := Color("ffd34d")
const UMRISS := Color("0f2e52")
const TAFEL := Color("15395f")
const TAFEL_RAND := Color("7cc8f5")
const FELD := Color("0f2a47")
const TEXT := Color("eef6ff")
const TEXT_BLASS := Color("a9d4f7")
const GUT := Color("b8ff7a")
const SCHLECHT := Color("ffb09c")
const TITEL := Color("ffe9a8")

const RASTER := Vector2(40, 76)
const KARTE := Vector2(140, 168)
const SCHRITT := Vector2(150, 178)
const SPALTEN := 4
const TAFEL_RECHT := Rect2(652, 76, 588, 628)
const ZURUECK := Rect2(40, 14, 46, 46)

var _reiter := 0
var _wahl: Array[int] = [0, 0, 0]
var _maus := Vector2(-100, -100)
var _zeit := 0.0
var _daten: Array = []            # je Reiter eine Liste von Einträgen
var _blaetter := {}
var _schrift: Font
var _y := 0.0                     # Schreibmarke in der Tafel


func _ready() -> void:
	size = Vector2(1280, 720)
	mouse_filter = Control.MOUSE_FILTER_STOP   # solange die Übersicht offen ist, wird nicht versehentlich gebaut
	visible = false
	_schrift = ThemeDB.fallback_font
	_baue_daten()


func umschalten() -> void:
	visible = not visible
	queue_redraw()


func _process(delta: float) -> void:
	if visible:
		_zeit += delta
		queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_maus = event.position
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var p: Vector2 = event.position
		if ZURUECK.has_point(p):
			visible = false
			return
		for i in REITER.size():
			if _reiter_recht(i).has_point(p):
				_reiter = i
				return
		for i in (_daten[_reiter] as Array).size():
			if _karten_recht(i).has_point(p):
				_wahl[_reiter] = i
				return


func _karten_recht(i: int) -> Rect2:
	return Rect2(RASTER + Vector2(i % SPALTEN, int(i / float(SPALTEN))) * SCHRITT, KARTE)


func _reiter_recht(i: int) -> Rect2:
	return Rect2(335 - REITER.size() * 80 + i * 160 + 10, 610, 140, 104)


# ------------------------------------------------------------------ Zeichnen

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), DUNKEL)
	# Zurück-Knopf
	_kasten(ZURUECK, KARTE_HELL if ZURUECK.has_point(_maus) else KARTE_BLAU, RAND, 10, 3)
	var m := ZURUECK.get_center()
	draw_colored_polygon(PackedVector2Array([m + Vector2(-13, 0), m + Vector2(1, -12), m + Vector2(1, -5), m + Vector2(13, -5),
		m + Vector2(13, 5), m + Vector2(1, 5), m + Vector2(1, 12)]), Color.WHITE)
	_schreibe(Vector2(104, 48), "Übersicht", 28, TITEL, 6)
	draw_string(_schrift, Vector2(270, 45), "Karte anklicken für Einzelheiten.   [I] oder Pfeil schließt", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, TEXT_BLASS)

	var liste: Array = _daten[_reiter]
	for i in liste.size():
		_zeichne_karte(_karten_recht(i), liste[i], i == _wahl[_reiter])
	_zeichne_tafel(liste[_wahl[_reiter]])
	for i in REITER.size():
		_zeichne_reiter(i)


func _zeichne_karte(r: Rect2, e: Dictionary, gewaehlt: bool) -> void:
	var drueber := r.has_point(_maus)
	if gewaehlt:
		_kasten(r.grow(4), GOLD, GOLD, 13, 0)
	_kasten(r, KARTE_HELL if drueber or gewaehlt else KARTE_BLAU, RAND, 10, 3)
	_kasten(Rect2(r.position + Vector2(3, 3), Vector2(r.size.x - 6, 30)), KARTE_KOPF, KARTE_KOPF, 7, 0)
	_schreibe_mittig(r.position + Vector2(0, 24), r.size.x, e["name"], 15, Color.WHITE, 5)
	_zeichne_bild(e, Vector2(r.get_center().x, r.position.y + 136), 2.0 if e.get("gross", false) else 1.5, 2.0, false)
	_schreibe_mittig(r.position + Vector2(0, r.size.y - 9), r.size.x, e["marke"], 13, GUT, 4)


func _zeichne_reiter(i: int) -> void:
	var r := _reiter_recht(i)
	var mitte := Vector2(r.get_center().x, r.position.y + 40)
	var an := i == _reiter
	if an:
		draw_circle(mitte, 39, GOLD)
	draw_circle(mitte, 35, RAND)
	draw_circle(mitte, 32, KARTE_HELL if an or r.has_point(_maus) else KARTE_BLAU)
	var e: Dictionary = _daten[i][0]
	_zeichne_bild(e, mitte + Vector2(0, 28), 1.25, 1.0, false)
	_schreibe_mittig(Vector2(r.position.x, r.position.y + 100), r.size.x, REITER[i], 17, Color.WHITE if an else TEXT_BLASS, 5)


func _zeichne_tafel(e: Dictionary) -> void:
	var r := TAFEL_RECHT
	_kasten(r, TAFEL, TAFEL_RAND, 12, 3)
	# Bild auf einem Sockel
	var fuss := r.position + Vector2(92, 150)
	_ellipse(fuss + Vector2(0, -2), Vector2(70, 18), Color(0, 0, 0, 0.35))
	_ellipse(fuss + Vector2(0, -6), Vector2(66, 16), Color("4f7d45"))
	_zeichne_bild(e, fuss + Vector2(0, -8), 2.5, 2.5, true)
	_schreibe(r.position + Vector2(190, 40), e["name"], 26, TITEL, 6)
	draw_string(_schrift, r.position + Vector2(190, 62), e["unter"], HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 200, 15, TEXT_BLASS)
	# Werte als kleine Felder
	var werte: Array = e["werte"]
	for i in werte.size():
		var feld := Rect2(r.position + Vector2(190 + (i % 4) * 98, 74 + int(i / 4.0) * 46), Vector2(92, 40))
		_kasten(feld, FELD, FELD, 6, 0)
		draw_string(_schrift, feld.position + Vector2(8, 14), werte[i][0], HORIZONTAL_ALIGNMENT_LEFT, 80, 11, TEXT_BLASS)
		draw_string(_schrift, feld.position + Vector2(8, 33), werte[i][1], HORIZONTAL_ALIGNMENT_LEFT, 80, 16, Color.WHITE)
	# Abschnitte
	_y = r.position.y + 178
	for a: Array in e["abschnitte"]:
		draw_string(_schrift, Vector2(r.position.x + 20, _y + 15), a[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, a[1])
		_y += 22
		for zeile: String in a[2]:
			var farbe := TEXT
			var marke := "•"
			if zeile.begins_with("+ "):
				farbe = GUT
				marke = "+"
				zeile = zeile.substr(2)
			elif zeile.begins_with("– "):
				farbe = SCHLECHT
				marke = "–"
				zeile = zeile.substr(2)
			draw_string(_schrift, Vector2(r.position.x + 24, _y + 13), marke, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, farbe)
			var breite := r.size.x - 60
			draw_multiline_string(_schrift, Vector2(r.position.x + 38, _y + 13), zeile, HORIZONTAL_ALIGNMENT_LEFT, breite, 13, -1, farbe)
			_y += _schrift.get_multiline_string_size(zeile, HORIZONTAL_ALIGNMENT_LEFT, breite, 13).y + 2
		_y += 7


## Bild eines Eintrags mit den Füßen auf `fuss`: Figur aus einem Animationsblatt oder eine gezeichnete Skizze.
func _zeichne_bild(e: Dictionary, fuss: Vector2, f48: float, f_skizze: float, bewegt: bool) -> void:
	if e.has("skizze"):
		var s := 0.5 * f_skizze
		_skizze(e["skizze"], fuss - Vector2(32, 64) * s, s)
		return
	var b: Dictionary = e["bild"]
	var kante: int = b["zelle"]
	var faktor := f48 * (0.75 if kante == 64 else 1.0) * float(b.get("faktor", 1.0))
	var reihe: int = b.get("reihe", 1) if bewegt else 0
	var n: int = (b["bilder"] as Array)[reihe]
	var bild := int(_zeit / (0.8 if reihe == 1 else 1.0) * n) % n if bewegt else 0
	var g := Vector2(kante, kante) * faktor
	if not _blaetter.has(b["blatt"]):
		_blaetter[b["blatt"]] = load(b["blatt"])
	if e.has("kreis"):
		_ellipse(fuss + Vector2(0, -4 * faktor), Vector2(kante * 0.42, kante * 0.14) * faktor, Color(e["kreis"], 0.55))
	draw_texture_rect_region(_blaetter[b["blatt"]], Rect2(fuss - Vector2(g.x / 2.0, g.y), g), Rect2(bild * kante, reihe * kante, kante, kante), e.get("farbe", Color.WHITE))


## Kleine Skizzen der Bauten im 64er-Raster (Farben wie auf der Karte), `o` = linke obere Ecke, `s` = Maßstab.
func _skizze(art: String, o: Vector2, s: float) -> void:
	var erde := Color("a87b4a")
	var front := Color("7a5433")
	var krone := Color("6c9a4f")
	var tech := Color("4b3a66")
	var tech_hell := Color("6a5391")
	var tech_dunkel := Color("2a2038")
	var licht := Color("7fe0ff")
	var stein := Color("8d8a96")
	var stein_hell := Color("b4b1bd")
	var stein_dunkel := Color("5c5966")
	if art.begins_with("form:"):
		_skizze_form(art.trim_prefix("form:"), o, s)
		return
	if art in ["wall", "stellung", "turm", "tor", "panzer", "spiegel", "magnet"]:
		_q(o, s, 0, 0, 64, 64, erde)
		_q(o, s, 0, 0, 64, 4, Color("c49b63"))
		_q(o, s, 8, 8, 48, 32, krone)
		_q(o, s, 0, 46, 64, 18, front)
		_q(o, s, 0, 60, 64, 4, Color("553822"))
	match art:
		"stellung":
			_q(o, s, 6, 4, 52, 38, stein_dunkel)
			_q(o, s, 8, 6, 48, 34, stein)
			_q(o, s, 14, 12, 36, 22, stein_hell)
			for x: int in [8, 26, 44]:
				_q(o, s, x, 6, 12, 6, stein_dunkel)
		"turm":
			_q(o, s, 12, 2, 40, 42, tech_dunkel)
			_q(o, s, 14, 4, 36, 38, tech)
			_q(o, s, 18, 8, 28, 20, tech_hell)
			_q(o, s, 26, 12, 12, 12, licht)
			_q(o, s, 2, 14, 12, 8, tech_dunkel)
			_q(o, s, 50, 14, 12, 8, tech_dunkel)
		"tor":
			_q(o, s, 6, 2, 52, 60, stein_dunkel)
			_q(o, s, 16, 12, 32, 50, Color("1b1722"))
			_q(o, s, 6, 2, 52, 10, stein)
			_q(o, s, 6, 12, 10, 50, stein)
			_q(o, s, 48, 12, 10, 50, stein)
			_q(o, s, 26, 4, 12, 6, licht)
		"fabrik":
			_q(o, s, 4, 12, 56, 48, tech_dunkel)
			_q(o, s, 6, 14, 52, 26, tech_hell)
			_q(o, s, 6, 40, 52, 18, tech)
			_q(o, s, 44, 2, 10, 14, tech_dunkel)
			_q(o, s, 46, 4, 6, 10, tech)
			_q(o, s, 24, 44, 16, 16, tech_dunkel)
			_q(o, s, 12, 22, 8, 8, licht)
			_q(o, s, 26, 22, 8, 8, licht)
		"batterie":
			_q(o, s, 4, 34, 56, 26, tech_dunkel)
			_q(o, s, 6, 36, 52, 22, tech)
			var blatt: String = Werte.BATTERIE["blatt"]
			if not _blaetter.has(blatt):
				_blaetter[blatt] = load(blatt)
			var kante: int = Werte.BATTERIE["zelle"]
			draw_texture_rect_region(_blaetter[blatt], Rect2(o + Vector2(-8, -24) * s, Vector2(80, 80) * s), Rect2(0, 0, kante, kante))
			for i in 3:
				_q(o, s, 8 + i * 18, 50, 14, 8, tech_dunkel)
				_q(o, s, 10 + i * 18, 52, 10, 4, licht)
		"spiegel":
			_q(o, s, 10, 26, 44, 18, stein_dunkel)
			draw_colored_polygon(PackedVector2Array([o + Vector2(14, 30) * s, o + Vector2(26, 4) * s, o + Vector2(50, 4) * s, o + Vector2(38, 30) * s]), Color("cfe8f5"))
			draw_line(o + Vector2(24, 24) * s, o + Vector2(34, 8) * s, Color.WHITE, maxf(1.0, 3.0 * s))
		"magnet":
			_q(o, s, 14, 8, 36, 34, tech_dunkel)
			draw_arc(o + Vector2(28, 26) * s, 13.0 * s, PI / 2.0, PI * 1.5, 16, Color("8c96a8"), maxf(2.0, 7.0 * s))
			_q(o, s, 24, 10, 14, 7, Color("e0453a"))
			_q(o, s, 24, 35, 14, 7, Color("3a7be0"))
		"panzer":
			var stahl := Color("8c96a8")
			_q(o, s, 0, 0, 64, 6, stahl)
			_q(o, s, 0, 0, 6, 46, stahl)
			_q(o, s, 58, 0, 6, 46, stahl)
			_q(o, s, 0, 40, 64, 6, Color("4a5160"))
			for x: int in [2, 30, 58]:
				_q(o, s, x, 1, 4, 4, Color("d8dee9"))
		"checkpoint":
			_q(o, s, 10, 52, 44, 8, Color(0, 0, 0, 0.3))
			_q(o, s, 28, 6, 5, 52, stein_hell)
			_q(o, s, 33, 8, 24, 18, Color("ff5ad0"))
			_q(o, s, 33, 22, 16, 4, Color("c93fa3"))
		"zone":
			_q(o, s, 0, 0, 64, 64, Color("6b6258"))
			_q(o, s, 14, 20, 36, 36, tech_dunkel)
			_q(o, s, 18, 24, 28, 28, Color("7a2f3f"))
			_q(o, s, 26, 32, 12, 12, Color("ff5a4d"))
			draw_arc(o + Vector2(32, 38) * s, 30 * s, PI, TAU, 24, Color(licht, 0.9), maxf(2.0, 3 * s))
		"geld":
			draw_circle(o + Vector2(32, 36) * s, 24 * s, Color("b3811f"))
			draw_circle(o + Vector2(32, 34) * s, 24 * s, GOLD)
			draw_circle(o + Vector2(32, 34) * s, 17 * s, Color("f0b92e"))
			_q(o, s, 29, 22, 6, 24, Color("fff2b8"))


## Formturm als 3×3-Skizze: in der Mitte der Turm in seiner Farbe, drumherum die Erdwälle, die seine Form ergeben.
const FORMEN := {
	"geschuetz": [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, 1)],
	"frost": [Vector2i(1, 0), Vector2i(0, 1)],
	"funk": [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)],
	"lanze": [Vector2i(-1, 0), Vector2i(1, 0)],
}

func _skizze_form(art: String, o: Vector2, s: float) -> void:
	var k := 64.0 / 3.0
	var farbe := Color(Werte.TURMARTEN[art]["farbe"])
	_q(o, s, 0, 0, 64, 64, Color(0.31, 0.49, 0.27, 0.5))
	for n: Vector2i in FORMEN[art]:
		var x := (n.x + 1) * k
		var y := (n.y + 1) * k
		_q(o, s, x + 1, y + 1, k - 2, k - 2, Color("a87b4a"))
		_q(o, s, x + 4, y + 4, k - 8, k - 8, farbe.darkened(0.45))
	_q(o, s, k + 1, k + 1, k - 2, k - 2, Color("2a2038"))
	_q(o, s, k + 4, k + 4, k - 8, k - 8, farbe)


func _q(o: Vector2, s: float, x: float, y: float, w: float, h: float, farbe: Color) -> void:
	draw_rect(Rect2(o + Vector2(x, y) * s, Vector2(w, h) * s), farbe)


func _ellipse(mitte: Vector2, halb: Vector2, farbe: Color) -> void:
	var punkte := PackedVector2Array()
	for i in 28:
		var w := TAU * i / 28.0
		punkte.append(mitte + Vector2(cos(w), sin(w)) * halb)
	draw_colored_polygon(punkte, farbe)


var _kaesten := {}

func _kasten(r: Rect2, farbe: Color, rand: Color, ecke: int, breite: int) -> void:
	var schluessel := [farbe, rand, ecke, breite]
	if not _kaesten.has(schluessel):
		var sb := StyleBoxFlat.new()
		sb.bg_color = farbe
		sb.border_color = rand
		sb.set_border_width_all(breite)
		sb.set_corner_radius_all(ecke)
		sb.anti_aliasing = true
		_kaesten[schluessel] = sb
	draw_style_box(_kaesten[schluessel], r)


## Schrift mit dunklem Umriss, wie auf den Karten von Bloons TD.
func _schreibe(pos: Vector2, text: String, groesse: int, farbe: Color, umriss: int) -> void:
	draw_string_outline(_schrift, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, groesse, umriss, UMRISS)
	draw_string(_schrift, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, groesse, farbe)


func _schreibe_mittig(pos: Vector2, breite: float, text: String, groesse: int, farbe: Color, umriss: int) -> void:
	draw_string_outline(_schrift, pos, text, HORIZONTAL_ALIGNMENT_CENTER, breite, groesse, umriss, UMRISS)
	draw_string(_schrift, pos, text, HORIZONTAL_ALIGNMENT_CENTER, breite, groesse, farbe)


# ------------------------------------------------------------------ Inhalt

static func _z(v: float) -> String:
	if is_equal_approx(v, roundf(v)):
		return str(int(roundf(v)))
	return ("%.1f" % v).replace(".", ",")


func _bild(d: Dictionary, reihe: int = 1, faktor: float = 1.0) -> Dictionary:
	return {"blatt": d["blatt"], "zelle": d["zelle"], "bilder": d["bilder"], "reihe": reihe, "faktor": faktor}


func _gegner(id: String, ab: String, tut: Array, hilft: Array) -> Dictionary:
	var d: Dictionary = Werte.GEGNER[id]
	var w: Array = [["Leben", _z(d["leben"])], ["Tempo", _z(d["tempo"])]]
	if d["reichweite"] > 0.0:
		w.append(["Reichweite", _z(d["reichweite"])])
	if d["schaden"] > 0.0:
		w.append(["Schaden", _z(d["schaden"])])
	if d["schaden"] > 0.0 or id == "rauch":
		w.append(["Wurf alle" if id == "rauch" else "Angriff alle", _z(d["abklingzeit"]) + " s"])
	w.append(["Prämie", str(d["praemie"])])
	return {"name": d["name"], "unter": d["art"], "marke": ab, "bild": _bild(d),
		"werte": w, "abschnitte": [["Was er macht", TITEL, tut], ["Dagegen hilft", GUT, hilft]]}


func _truppe(id: String, unter: String, tut: Array, stellung: Array) -> Dictionary:
	var d: Dictionary = Werte.EINHEITEN[id]
	var w: Array = [["Leben", _z(d["leben"])], ["Tempo", _z(d["tempo"])], ["Reichweite", _z(d["reichweite"])],
		["Schaden", _z(d["schaden"])], ["Angriff alle", _z(d["abklingzeit"]) + " s"]]
	if d.has("flaeche"):
		w.append(["Fläche", _z(d["flaeche"])])
	var abschnitte: Array = [["Was sie macht", TITEL, tut], ["In der Stellung", TEXT_BLASS, stellung]]
	if Werte.STUFE_2.has(id):
		abschnitte.append(["Stufe 2 (%d)" % Werte.KOSTEN_STUFE[1], TITEL, [Werte.STUFE_2[id]["text"]]])
		var wahl: Array = []
		for f: Dictionary in (Werte.STUFE_3[id] as Dictionary).values():
			wahl.append("%s: %s" % [f["name"], f["text"]])
			wahl.append("+ " + f["stark"])
			wahl.append("– " + f["schwach"])
		abschnitte.append(["Stufe 3 (%d) – eine von drei" % Werte.KOSTEN_STUFE[2], TITEL, wahl])
	return {"name": d["name"], "unter": unter, "marke": "Fabrik", "bild": _bild(d), "gross": true, "werte": w, "abschnitte": abschnitte}


## Karte eines Formturms: Form als Skizze, Werte aus Werte.TURMARTEN, gemeinsame Regeln für alle Türme.
func _turmkarte(art: String, extra: Array) -> Dictionary:
	var W := Werte
	var d: Dictionary = W.TURMARTEN[art]
	var w: Array = [["Preis", str(W.KOSTEN_TURM)], ["Form", d["form"]], ["Stützen", str(d["nachbarn"])], ["Reichweite", _z(d["reichweite"])]]
	if float(d["schaden"]) > 0.0:
		w.append(["Schaden", _z(d["schaden"])])
		w.append(["Angriff alle", _z(d["abklingzeit"]) + " s"])
	var regeln: Array = [d["text"]]
	regeln.append_array(extra)
	return {"name": d["name"], "unter": "Turm auf " + {"Ecke": "einer Ecke", "Kreuzung": "einer Kreuzung", "T-Stück": "einem T-Stück", "gerades Stück": "einem geraden Stück"}.get(d["form"], d["form"]),
		"marke": "%d  [4]" % W.KOSTEN_TURM, "skizze": "form:" + art, "werte": w,
		"abschnitte": [["Was er macht", TITEL, regeln], ["Für alle Türme", TEXT_BLASS, [
			"Welcher Turm entsteht, entscheidet die Form der freien Nachbarwälle: Ecke = Frost, gerade = Lanze, T-Stück = Geschütz, Kreuzung = Funk.",
			"Stützregel: Diese Erdwälle dürfen keinen anderen Turm stützen. Stellungen darauf sind erlaubt.",
			"Schießt ohne Truppe und auch im Rauch. Sicht wie aus einer Stellung. Sein Erdwall hält Sprengern stand.",
			"Turmtruppen können ihn lahmlegen – dann schweigt er bis zum Rundenende."]]]}


func _baue_daten() -> void:
	var W := Werte
	var schleuder: Dictionary = W.SCHLEUDER
	var laser: Dictionary = W.LASER
	var gegner: Array = [
		_gegner("hund", "ab Runde 1", [
			"Schneller Nahkämpfer, kommt im Rudel.",
			"Beißt Bodentruppen in Reichweite. An Truppen in Stellungen kommt er nicht heran."], [
			"Stellungen am Weg, Bodentruppen zum Abfangen dahinter.",
			"Plasmawerfer gegen dichte Rudel."]),
		_gegner("sphaere", "ab Runde 3", [
			"Fernkämpfer, schießt im Laufen.",
			"Ziele der Reihe nach: Truppen in Stellungen, dann Fabriken und Batterien, dann Bodentruppen.",
			"Zerschossene Fabriken und Batterien fallen bis zum Rundenende aus."], [
			"Scharfschützen: mehr Reichweite als die Sphäre.",
			"Fabriken nicht direkt an den Weg stellen.",
			"Der Reservepilot der Batterie repariert Ausgefallenes."]),
		_gegner("fahne", "ab Runde 6", [
			"Macht die anderen in seinem Trupp 30 % schneller – er selbst läuft ohne Bonus und fällt dadurch zurück.",
			"Hinterlässt für %s Sekunden eine Spur: Gegner darauf sind ebenfalls 30 %% schneller." % _z(W.FAHNE_SPUR_SEK),
			"Kämpft nicht, nimmt Checkpoints aber doppelt so schnell ein."], [
			"Ihn zuerst ausschalten: Der Trupp fällt auf sein normales Tempo zurück.",
			"Plasmagel bremst den Sturm, Zielmarkierung trifft ihn überall."]),
		_gegner("sprenger", "ab Runde 8", [
			"Sprengt den Erdwall, dessen Wegfall eine große Abkürzung bringt – frühestens nach %d Schritten Anmarsch." % W.SPRENGER_MIN_WEG,
			"Dicke Riegel aus blanken Erdwällen fallen bis zu 4 Felder tief. Linien in Sprengrichtung, Stellungen und Tore verlieren nur das getroffene Feld.",
			"Ohne lohnenden Erdwall sprengt er eine Fabrik (%s s Ausfall) und trifft Bodentruppen daneben." % _z(W.SPRENGER_FABRIK_SEK),
			"Am Ziel zündet er %s Sekunden lang und steht dabei still (Ring über dem Warnzeichen). Fällt er vorher, gibt es keine Sprengung." % _z(W.SPRENGER_ZUENDZEIT),
			"Das Ziel blinkt erst in der Welle. Der Sprenger trägt ein Warnzeichen."], [
			"Vor dem Ziel abfangen – er hält wenig aus. Spätestens beim Zünden ist er ein stehendes Ziel.",
			"Erdwälle mit Turm halten stand, gepanzerte überstehen eine Sprengung."]),
		_gegner("rauch", "ab Runde 11", [
			"Wirft Rauch auf die dichteste Gruppe von Stellungen; ohne Stellungen auf einen Truppenhaufen.",
			"Truppen im Rauch schießen %s Sekunden nicht. Türme schießen weiter." % _z(W.RAUCH_SEK),
			"In den Rauch hinein kann geschossen werden – blind ist nur, wer selbst darin steht."], [
			"Türme, verteilte Stellungen, vorrückende Bodentruppen.",
			"Scharfschützen ab Stufe 2 (Klarsicht) schießen auch im Rauch; ein markiertes Ziel treffen alle.",
			"Batterie mit Schwerer Ladung bläst den Rauch weg."]),
		_gegner("belagerung", "ab Runde 13", [
			"Fährt zum Wallstück mit den meisten Stellungen und dockt an.",
			"Dann springt alle %s Sekunden eine Turmtruppe auf den Wall – bis zu %d zugleich, höchstens %s Sekunden lang." % [_z(W.ENTERER_ABSTAND), W.ENTERER_GLEICHZEITIG, _z(W.BELAGERUNG_SEK)],
			"Dockt er an, wirft die Wurf-Schleuder sofort auf die andere Seite."], [
			"Unterwegs zerstören: langsam, aber sehr zäh.",
			"Laserstrahl und Zielmarkierung gegen zähe Einzelziele."]),
		_gegner("enterer", "ab Runde 13", [
			"Kommt aus dem Belagerungsturm und läuft oben auf zusammenhängenden Erdwällen.",
			"Greift Truppen in Stellungen im Nahkampf an und legt Türme bis zum Rundenende lahm.",
			"Findet sie kein Ziel, springt sie ab und läuft zur Basis."], [
			"Getrennte Wallstücke: Sie kommt nur über verbundene Erdwälle.",
			"Der Reservepilot macht lahme Türme wieder flott."]),
		{"name": "Stein-Schleuder", "unter": "steht in der Zone", "marke": "ab Runde 5", "bild": _bild(schleuder, 0), "kreis": Color("ff5ad0"),
			"werte": [["Reichweite", _z(schleuder["reichweite"])], ["auf Truppe", _z(schleuder["schaden_einheit"])], ["auf Fabrik", _z(schleuder["schaden_fabrik"])], ["Wurf alle", _z(schleuder["abklingzeit"]) + " s"]],
			"abschnitte": [["Was sie macht", TITEL, [
				"Steht unter dem Schild der Zone und wirft Steine auf Truppen in Stellungen und auf Fabriken im pinken Kreis.",
				"Ohne solche Ziele trifft sie Haufen ab %d Bodentruppen." % W.HAUFEN_MIN,
				"Ab Runde %d gibt es eine zweite, und beide wechseln den Platz: vor jeder Runde und alle %s Sekunden." % [W.SPRENGER_AB_WELLE, _z(W.SCHLEUDER_UMZUG_SEK)],
				"Zerschossene Fabriken und Batterien fallen bis zum Rundenende aus."]],
				["Dagegen hilft", GUT, ["Wichtiges außerhalb des Kreises bauen.", "Truppen nicht auf einem Haufen stehen lassen."]]]},
		{"name": "Wurf-Schleuder", "unter": "steht in der Zone", "marke": "ab Runde 10", "bild": _bild(schleuder, 0), "kreis": Color("ff9a3d"), "farbe": W.WURF_FARBE,
			"werte": [["Wurfweite", _z(W.WURF["reichweite"])], ["je Wurf", "%d Gegner" % W.WURF["rudel"]], ["Wurf alle", _z(W.WURF["abklingzeit"]) + " s"]],
			"abschnitte": [["Was sie macht", TITEL, [
				"Wirft Trupps zu vier über die Erdwälle – je nach Runde Hunde, Fahnenträger, Sprenger oder Rauchwerfer.",
				"Landepunkt: hinter der Wallgruppe mit dem größten Umweg, gern nahe an einem Checkpoint.",
				"Die Vorschau nennt nur, was geworfen wird. Der Landekreis erscheint erst in der Welle.",
				"Ohne echte Mauer wirft sie weiter (%s Felder). Sehr dicke Mauern bekommen ein Rudel Hunde zusätzlich." % _z(W.WURF["tasche_weit"]),
				"In einen rundum geschlossenen Kern wirft sie nicht.",
				"Ab Runde 14 gibt es eine zweite."]],
				["Dagegen hilft", GUT, ["Bodentruppen auch hinter der Mauer haben.", "Checkpoints hinter Erdwällen nicht ungeschützt lassen."]]]},
		{"name": "Laser", "unter": "verteidigt die Zone", "marke": "Runde %d" % W.LETZTE_RUNDE, "bild": _bild(laser, 0),
			"werte": [["Leben", _z(laser["leben"])], ["Reichweite", _z(laser["reichweite"])], ["Schaden", _z(laser["schaden"])], ["Angriff alle", _z(laser["abklingzeit"]) + " s"]],
			"abschnitte": [["Was er macht", TITEL, [
				"Drei Laser verteidigen die Zone in der letzten Runde.",
				"Sie schießen flach und nur auf Bodentruppen. Erdwälle geben Deckung."]],
				["Dagegen hilft", GUT, ["Im Schutz der eigenen Erdwälle anmarschieren."]]]},
		{"name": "Checkpoints", "unter": "zwei Fahnen auf dem Gegnerweg", "marke": "ab Runde %d" % W.CHECKPOINTS_AB_WELLE, "skizze": "checkpoint",
			"werte": [["Einnahme", _z(W.EINNAHME_SEK) + " s"], ["Zurück", _z(W.RUECKEROBERUNG_SEK) + " s"], ["Bonus", str(W.BONUS_JE_CHECKPOINT)]],
			"abschnitte": [["Regeln", TITEL, [
				"Sie liegen in jeder Partie etwas anders – deine Basis auch. Der Gegnerweg führt schon ab Runde 1 der Reihe nach durch beide; einnehmen können die Gegner sie erst ab Runde %d." % W.CHECKPOINTS_AB_WELLE,
				"Gegner bleiben darauf stehen, bis sie ihn eingenommen haben. Danach gehört er dem Gegner, und die nächste Welle startet dort.",
				"Zurückholen: Je verlorenem Checkpoint geht eine Bodentruppe hin und hält ihn – nur solange die Welle läuft und kurz danach.",
				"Jeder Checkpoint, der am Rundenende dir gehört, bringt Budget."]]]},
		{"name": "Zone und HQ", "unter": "die drei linken Spalten", "marke": "Runde %d" % W.LETZTE_RUNDE, "skizze": "zone",
			"werte": [["HQ-Leben", _z(W.HQ_LEBEN)], ["Abstand", "%d Felder" % W.ZONE_ABSTAND]],
			"abschnitte": [["Regeln", TITEL, [
				"In der Zone kann nicht gebaut werden. Ein Schild schützt alles darin bis zur letzten Runde.",
				"Eigene Truppen halten Abstand zur Zone, damit die Gegner herauskommen.",
				"Runde %d ist der Gegenangriff: Das HQ muss fallen. Gegner kommen ohne Ende, niemand geht mehr in Stellungen, und jede Fabrik hat bis zu %d aktive Truppen." % [W.LETZTE_RUNDE, W.MAX_JE_FABRIK_ENDKAMPF],
				"Ausgefallene Gebäude laufen dort nach einiger Zeit wieder an.",
				"Während des Gegenangriffs darfst du weiterbauen und ausbauen – nur keine neuen Erdwälle."]]]},
	]

	var truppen: Array = [
		_truppe("technogunner", "Allrounder", [
			"Schnelle Schussfolge, mittlere Reichweite.",
			"Gut am Boden zum Abfangen und in Stellungen."],
			["+%s Reichweite. Schießt über die Erdwälle des eigenen Wallstücks." % _z(W.stellung_bonus(W.EINHEITEN["technogunner"]))]),
		_truppe("scharfschuetze", "weit und genau", [
			"Größte Reichweite und hoher Schaden auf ein Ziel, aber langsame Schussfolge.",
			"Hält wenig aus – gehört in eine Stellung."],
			["+%s Reichweite. Schießt nur über Erdwälle, die mit seinem verbunden sind; fremde Wallstücke versperren die Sicht." % _z(W.stellung_bonus(W.EINHEITEN["scharfschuetze"]))]),
		_truppe("plasmawerfer", "Flächenschaden", [
			"Trifft alle Gegner im Umkreis des Ziels.",
			"Stark gegen Rudel, langsam gegen einzelne zähe Gegner."],
			["Kein Reichweitenbonus – von oben nur der Schuss über die eigenen Erdwälle."]),
	]
	var pilot: Dictionary = W.EINHEITEN["pilot"]
	truppen.append({"name": "Pilot", "unter": "bemannt Batterien", "marke": "Pilotenfabrik", "bild": _bild(pilot), "gross": true,
		"werte": [["Leben", _z(pilot["leben"])], ["Tempo", _z(pilot["tempo"])]],
		"abschnitte": [["Was er macht", TITEL, [
			"Kämpft nicht. Kommt aus der Pilotenfabrik, die an jeder Batterie hängt.",
			"Bemannt die nächste Batterie mit freiem Platz und wartet sonst an der Fabrik.",
			"Reservepilot (Batterie Stufe 1): rückt nach, wenn einer fehlt, und repariert sonst ausgefallene Fabriken, Batterien und lahme Türme in %s Sekunden." % _z(W.REPARATUR_SEK)]]]})
	truppen.append({"name": "Verhalten", "unter": "so entscheiden deine Truppen selbst", "marke": "Regeln", "bild": _bild(W.EINHEITEN["technogunner"]), "gross": true,
		"werte": [["je Fabrik", "max. %d" % W.MAX_JE_FABRIK], ["Nachbau", _z(W.PRODUKTION_SEK) + " s"], ["Kosten", "keine"]],
		"abschnitte": [["Regeln", TITEL, [
			"Maximal %d aktive Truppen pro Fabrik (im Grundfall). Fällt eine, baut die Fabrik sie nach." % W.MAX_JE_FABRIK,
			"Stellungen werden stets aufgefüllt. Das passiert nicht, wenn der Weg nicht frei ist.",
			"Am Boden kämpfen sie gegen Gegner auf dem Boden.",
			"Wer durchgebrochen ist, wird nicht verfolgt – um den kümmern sich deine Stellungen und Türme weiter hinten.",
			"Ausnahme am Rundenende: Kommt nichts mehr nach, steigen Truppen ohne Ziel aus ihren Stellungen und gehen den letzten Gegnern hinterher.",
			"Geschossen wird nur aus der Stellung oder am Boden auf Gegner, die sie sehen – immer nur in Reichweite.",
			"Je verlorenem Checkpoint geht eine Truppe ihn zurückholen.",
			"Klick auf eine Truppe zeigt ihre Reichweite und was sie darin nicht treffen kann."]]]})

	var bauten: Array = [
		{"name": "Fabrik", "unter": "baut Truppen", "marke": "%d  [1]" % W.KOSTEN_FABRIK, "skizze": "fabrik",
			"werte": [["Preis", str(W.KOSTEN_FABRIK)], ["jede weitere", "+%s %%" % _z(W.KOSTEN_FABRIK_PROZENT)], ["Truppen", str(W.MAX_JE_FABRIK)], ["Leben", _z(W.LEBEN_FABRIK)]],
			"abschnitte": [["Was sie macht", TITEL, [
				"Maximal %d aktive Truppen (im Grundfall). Welche Truppe, wählst du im Fabrikmenü; ein Wechsel gilt für die nächste Truppe." % W.MAX_JE_FABRIK,
				"Steht am Boden und versperrt den Weg wie ein Erdwall, aber nicht die Sicht.",
				"Truppen brauchen einen Ausgang: ein freies Feld oder ein Tor direkt an der Fabrik. Ohne Ausgang (rotes Kreuz) besetzen sie nur Stellungen, die direkt anliegen – nicht über Eck.",
				"Sphären, Schleudern und Sprenger können sie ausfallen lassen. Nahkämpfer greifen sie nicht an."]],
				["Ausbau", TITEL, [
				"Stufe 1 (%d): legt sich auf ihre Truppe fest und bekommt dafür eine Truppe mehr." % W.KOSTEN_STUFE[0],
				"Stufe 2 (%d): bessere Werte für diese Truppe." % W.KOSTEN_STUFE[1],
				"Stufe 3 (%d): eine von drei Fähigkeiten – siehe Reiter Truppen." % W.KOSTEN_STUFE[2]]]]},
		{"name": "Erdwall", "unter": "lenkt den Gegnerweg", "marke": "%d  [2]" % W.KOSTEN_WALL, "skizze": "wall",
			"werte": [["Preis", str(W.KOSTEN_WALL)], ["Leben", _z(W.LEBEN_WALL)], ["ab Runde", str(W.WAELLE_AB_WELLE)]],
			"abschnitte": [["Was er macht", TITEL, [
				"Gegner nehmen den kürzesten freien Weg zur Basis – Erdwälle machen ihn länger.",
				"Nur wenn gar kein Weg mehr frei ist, reißen sie Erdwälle ein.",
				"Während der Welle kann kein Erdwall nachgebaut werden.",
				"Grundlage für Stellung, Turm und Tor."]]]},
		{"name": "Stellung", "unter": "Ausbau eines Erdwalls", "marke": "%d  [3]" % W.KOSTEN_STELLUNG, "skizze": "stellung",
			"werte": [["Preis", str(W.KOSTEN_STELLUNG)], ["Platz", "1 Truppe"]],
			"abschnitte": [["Was sie macht", TITEL, [
				"Eine Truppe steht oben und schießt über die Erdwälle ihres Wallstücks. Fremde Wallstücke versperren die Sicht.",
				"Mehr Reichweite von oben: Technogunner +%s, Scharfschütze +%s, Plasmawerfer +%s." % [_z(W.stellung_bonus(W.EINHEITEN["technogunner"])), _z(W.stellung_bonus(W.EINHEITEN["scharfschuetze"])), _z(W.stellung_bonus(W.EINHEITEN["plasmawerfer"]))],
				"Kein Schuss durch die Lücke zwischen Erdwällen, die sich nur an den Ecken berühren.",
				"Nahkämpfer am Boden kommen nicht heran. Gefährlich sind Sphären, Schleudern, Rauch und Turmtruppen.",
				"Darf auch in der Welle gebaut werden, solange kein Gegner in der Nähe ist."]]]},
		_turmkarte("geschuetz", ["Das ist der bisherige Turm."]),
		_turmkarte("frost", ["Bremst ganze Trupps – gut gegen Fahnensturm und schnelle Rudel."]),
		_turmkarte("funk", ["Zählt alle Stellungen im Umkreis, nicht nur eine – je mehr Stellungen drumherum, desto mehr lohnt er."]),
		_turmkarte("lanze", ["Am stärksten an langen, geraden Gängen, in denen die Gegner hintereinander laufen."]),
		{"name": "Spiegel", "unter": "Ausbau eines Erdwalls", "marke": "%d  [8]" % W.KOSTEN_SPIEGEL, "skizze": "spiegel",
			"werte": [["Preis", str(W.KOSTEN_SPIEGEL)], ["für", "Bodentruppen"]],
			"abschnitte": [["Was er macht", TITEL, [
				"Bodentruppen, die den Spiegel sehen, schießen über ihn um die Ecke auf Gegner, die sie selbst nicht sehen.",
				"Truppe → Spiegel und Spiegel → Gegner brauchen freie Sicht; beide Strecken zusammen müssen in ihrer Reichweite liegen.",
				"Truppen in Stellungen nutzen ihn nicht.",
				"Am besten an Ecken und Gangbiegungen, hinter denen die Gegner verschwinden."]]]},
		{"name": "Magnet", "unter": "Ausbau eines Erdwalls", "marke": "%d  [9]" % W.KOSTEN_MAGNET, "skizze": "magnet",
			"werte": [["Preis", str(W.KOSTEN_MAGNET)], ["Linie", "%d Felder" % int(W.MAGNET["laenge"])], ["Zug", _z(W.MAGNET["zug"]) + " Felder"], ["Zug alle", _z(W.MAGNET["abklingzeit"]) + " s"]],
			"abschnitte": [["Was er macht", TITEL, [
				"Zieht die Gegner in seiner Linie zu sich heran – nur in der Linie, in die er zeigt. Die Richtung stellst du beim Bauen mit [T] ein.",
				"Die Linie endet am ersten Erdwall oder Gebäude; durch Wälle zieht er nicht. Gezogene Gegner suchen sich danach einen neuen Weg.",
				"Der Belagerungsturm ist zu schwer für ihn.",
				"So holst du Trupps aus dem Gang vor deine Stellungen oder ziehst sie auf langen Wegen zurück."]]]},
		{"name": "Panzerung", "unter": "Ausbau eines Erdwalls", "marke": "%d  [7]" % W.KOSTEN_PANZER, "skizze": "panzer",
			"werte": [["Preis", str(W.KOSTEN_PANZER)]],
			"abschnitte": [["Was sie macht", TITEL, [
				"Die erste Sprengung reißt nur die Panzerung weg, erst ein zweiter Sprenger bringt den Erdwall zu Fall.",
				"Eine Sprengung in die Tiefe hört an einem gepanzerten Erdwall auf.",
				"Lässt sich mit Stellung, Turm und Tor kombinieren."]]]},
		{"name": "Tor", "unter": "Ausbau eines Erdwalls", "marke": "%d  [6]" % W.KOSTEN_TOR, "skizze": "tor",
			"werte": [["Preis", str(W.KOSTEN_TOR)]],
			"abschnitte": [["Was es macht", TITEL, [
				"Durchgang nur für eigene Truppen. Für Gegner bleibt es ein Erdwall.",
				"Direkt an einer Fabrik ist es ihr Ausgang.",
				"Deine Truppen kommen so schneller zum Abfangen und zu den Checkpoints.",
				"Zusammen mit Erdwällen lassen sich Fabriken einschließen (Zitadelle)."]]]},
		{"name": "Batterie", "unter": "Railgun mit Pilotenfabrik", "marke": "%d  [5]" % W.KOSTEN_BATTERIE, "skizze": "batterie",
			"werte": [["Preis", str(W.KOSTEN_BATTERIE)], ["Reichweite", _z(W.BATTERIE["reichweite"])], ["Schaden", _z(W.BATTERIE["schaden"])], ["Angriff alle", _z(W.BATTERIE["abklingzeit"]) + " s"],
				["Fläche", _z(W.BATTERIE["flaeche"])], ["Plätze", "%d Piloten" % W.BATTERIE["plaetze"]]],
			"abschnitte": [["Was sie macht", TITEL, [
				"Zwei Felder: Batterie und angebaute Pilotenfabrik ([T] dreht sie beim Bauen).",
				"Feuert nur, solange alle Plätze mit Piloten besetzt sind – weit, über Erdwälle hinweg und mit Flächenschaden."]],
				["Ausbau", TITEL, [
				"Stufe 1 (%d) %s: %s" % [W.KOSTEN_BATTERIE_STUFE[0], W.BATTERIE_STUFEN[0]["name"], "Ein vierter Pilot rückt nach und repariert Ausgefallenes."],
				"Stufe 2 (%d) %s: %s" % [W.KOSTEN_BATTERIE_STUFE[1], W.BATTERIE_STUFEN[1]["name"], W.BATTERIE_STUFEN[1]["text"]],
				"Stufe 3 (%d) %s: %s" % [W.KOSTEN_BATTERIE_STUFE[2], W.BATTERIE_STUFEN[2]["name"], "Schild auf einem Wegfeld in Reichweite. Gegner müssen ihn erst zerschlagen, eigene Truppen gehen hindurch."]]]]},
	]
	truppen.append({"name": "Budget", "unter": "woher das Geld kommt", "marke": "Regeln", "skizze": "geld",
			"werte": [["Start", str(W.START_BUDGET)], ["Leben", str(W.START_LEBEN)], ["Abriss", "%d %% zurück" % int(W.ERSTATTUNG * 100)]],
			"abschnitte": [["Einkommen", TITEL, [
				"Nach jeder Runde: %d + %d je Rundennummer." % [W.BONUS_JE_WELLE, W.BONUS_ZUWACHS],
				"Je Checkpoint, der am Rundenende dir gehört: %d." % W.BONUS_JE_CHECKPOINT,
				"Zinsen: für je %d Budget, das am Rundenende übrig ist, %d dazu – höchstens %d." % [W.ZINS_SCHRITT, W.ZINS_JE_SCHRITT, W.ZINS_STUFEN * W.ZINS_JE_SCHRITT],
				"Dazu eine kleine Prämie je besiegtem Gegner.",
				"Runde 1: nur Fabriken. Erdwälle gibt es ab Runde %d – die ersten %d davon gratis." % [W.WAELLE_AB_WELLE, W.STARTPAKET_WAELLE]]]]})
	_daten = [gegner, truppen, bauten]
