class_name EndTafel extends Control
## Gemeinsame Tafel für Sieg, Niederlage, Phantom-Ende, Zwischenwertung und Rückfragen (18.11.).
## Gezeichnet im UI-Raster 640×360 (zweifach skaliert) im Stil von Startmenü und HUD, Schrift VT323 über Stil.
## Inhalt als Wörterbuch (alles optional außer „titel“ und „knoepfe“):
##   kicker, titel, titel_farbe, untertitel, rahmen (Farbe), effekt ("funken" | "asche" | "kupfer" | ""),
##   glitch (Titel flackert), wackeln (Tafel bebt beim Erscheinen),
##   kacheln: [{name, zahl, max, zeit, text, farbe, symbol}]  – zählen beim Erscheinen hoch
##   kaesten: [{titel, farbe, text | text_fn (Callable), tippen (bool), knopf [Text, Callable]}]
##   punkte: [[Symbol, Text]]  – Aufzählung (Symbole aus Stil.SYMBOLE)
##   comic: [[Symbol, Text, Farbe]] (3 Kacheln mit Pfeilen: Bau → Angriff → Bericht, 23.11.)
##   elo: {label, vorher, nachher (-1 = wartet), hinweis} – zählt hoch/runter (scripts/ui/elo_anzeige.gd); elo_setze() füllt nach
##   zeilen: [Text]  – goldene Zusatzzeilen
##   knoepfe: [[Text, Callable, Farbe]]  – der erste ist der wichtigste
##   esc: Callable  – Taste Esc (sonst nichts)
## Maus oder Tasten: ← → wählen, Enter bestätigt.

const Stil := preload("res://scripts/ui/ui_stil.gd")
const MITTE_X := 320.0
const TAFEL_B := 344.0
const INNEN_B := 76.0 * 4.0 + 6.0 * 3.0

var conf: Dictionary = {}
var gesperrt: Callable = Callable()    # true = eine Tafel darüber hat die Eingabe

var _t := 0.0
var _wahl := 0
var _maus := Vector2(-100, -100)
var _rechtecke: Array = []       # Knöpfe
var _kasten_knoepfe: Array = []  # [Rect2, Callable]
var _teilchen: Array = []
var _messen := false
var _a := 1.0                    # Deckkraft der Tafel beim Erscheinen
var _elo_t0 := -1.0              # Sekunde, ab der die Elo-Zahl zählt (-1 = noch nicht)


func _init() -> void:
	size = Vector2(640, 360)
	scale = Vector2(Stil.UI_SKALA, Stil.UI_SKALA)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	var z := RandomNumberGenerator.new()
	z.seed = 20
	for i in 52:
		_teilchen.append([z.randf() * 640.0, z.randf(), 6.0 + z.randf() * 14.0, z.randf() * TAU, z.randf()])


func zeige(neu: Dictionary) -> void:
	conf = neu
	_t = 0.0
	_elo_t0 = -1.0
	_wahl = 0
	visible = true
	queue_redraw()


## 23.11.: Ergebnis der Elo-Anzeige nachtragen (kommt erst, wenn die Datenbank geantwortet hat).
func elo_setze(vorher: int, nachher: int, hinweis: String = "") -> void:
	var d: Dictionary = conf.get("elo", {})
	if d.is_empty():
		return
	d["vorher"] = vorher
	d["nachher"] = nachher
	d["hinweis"] = hinweis
	_elo_t0 = maxf(_t, 1.2) + 0.2   # frühestens, wenn die Tafel steht


func _process(delta: float) -> void:
	if visible:
		_t += delta / maxf(Engine.time_scale, 0.01)   # Echtzeit, auch bei Spieltempo ×2
		queue_redraw()


# ------------------------------------------------------------------ Zeichnen

func _anteil(von: float, dauer: float) -> float:
	return clampf((_t - von) / dauer, 0.0, 1.0)


static func _aus(x: float) -> float:
	return 1.0 - pow(1.0 - x, 3.0)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.03, 0.05, 0.74 * _anteil(0.0, 0.4)))
	_male_teilchen(_anteil(0.3, 0.8))
	_messen = true
	var hoehe := _inhalt(0.0)
	_messen = false
	var ein := _aus(_anteil(0.1, 0.45))
	_a = ein
	var x0 := MITTE_X - TAFEL_B / 2.0
	if conf.get("wackeln", false):
		var k := 1.0 - _anteil(0.1, 0.5)
		x0 += roundf(sin(_t * 70.0) * 4.0 * k)
	var r := Rect2(x0, roundf((360.0 - hoehe) / 2.0 + 8.0 * (1.0 - ein)), TAFEL_B, hoehe)
	var rahmen: Color = conf.get("rahmen", Stil.GOLD)
	Stil.platte(self, r.grow(2.0), 5.0, Color(rahmen, 0.0), Color(rahmen, 0.55 * ein))
	Stil.platte(self, r, 4.0, Color(0.05, 0.06, 0.09, 0.94 * ein), Color(Stil.RAHMEN, ein))
	if ein < 0.05:
		return
	draw_set_transform(Vector2(r.position.x - (MITTE_X - TAFEL_B / 2.0), 0.0))   # Beben verschiebt den Inhalt mit
	_inhalt(r.position.y)
	draw_set_transform(Vector2.ZERO)
	Stil.schreibe_mittig(self, Vector2(r.get_center().x, r.end.y - 9.0), "[←] [→] wählen  ·  [Enter] bestätigen", Stil.KLEIN, Color(Stil.TEXT_BLASS, 0.6 * ein))


## Zeichnet den Inhalt ab `y` (oder misst ihn nur, wenn _messen) und gibt die Höhe der Tafel zurück.
func _inhalt(y0: float) -> float:
	var y := y0 + 16.0
	if not _messen:
		_rechtecke = []
		_kasten_knoepfe = []
	# Kopf
	_mittig(y, str(conf.get("kicker", "")), Stil.KLEIN, Color(Stil.TEXT_BLASS, _a))
	y += 26.0
	_titel(y)
	y += 30.0
	if str(conf.get("untertitel", "")) != "":
		var u := str(conf["untertitel"])
		var g := Stil.absatz_groesse(u, INNEN_B, Stil.NORMAL)
		if not _messen:
			var w := minf(g.x, INNEN_B)
			Stil.absatz(self, Vector2(roundf(MITTE_X - w / 2.0), y - 5.0), u, INNEN_B, Stil.NORMAL, Color(Stil.TEXT, _aus(_anteil(0.35, 0.4))))
		y += maxf(g.y, 10.0) + 6.0
	else:
		y += 2.0
	# Kacheln
	var kacheln: Array = conf.get("kacheln", [])
	if not kacheln.is_empty():
		_kacheln(kacheln, y)
		y += 48.0
	# Aufzählung
	for p: Array in conf.get("punkte", []):
		var g := Stil.absatz_groesse(str(p[1]), INNEN_B - 18.0, Stil.NORMAL)
		if not _messen:
			var x := MITTE_X - INNEN_B / 2.0
			Stil.symbol(self, str(p[0]), Vector2(x + 6.0, y + 5.0), 1.0, Stil.LEUCHT)
			Stil.absatz(self, Vector2(x + 16.0, y), str(p[1]), INNEN_B - 18.0, Stil.NORMAL, Stil.TEXT)
		y += g.y + 6.0
	# Kästen
	for k: Dictionary in conf.get("kaesten", []):
		y += _kasten(k, y) + 8.0
	# Comic (Bau -> Angriff -> Bericht)
	var comic: Array = conf.get("comic", [])
	if not comic.is_empty():
		_comic(comic, y)
		y += 56.0
	# Elo-Anzeige
	if conf.has("elo"):
		if not _messen:
			var d: Dictionary = conf["elo"]
			d["t0"] = _elo_t0
			EloAnzeige.male(self, MITTE_X, y, d, _t, _a)
		y += EloAnzeige.HOEHE + (12.0 if str((conf["elo"] as Dictionary).get("hinweis", "")) != "" else 2.0)
	# Zusatzzeilen
	if not (conf.get("punkte", []) as Array).is_empty() and not (conf.get("zeilen", []) as Array).is_empty():
		y += 4.0
	for z: String in conf.get("zeilen", []):
		_mittig(y + 2.0, z, Stil.KLEIN, Stil.GOLD)
		y += 14.0
	# Knöpfe (erscheinen, wenn die Tafel steht, und rutschen ein Stück hoch)
	if not _messen and _t >= 0.9:
		_male_knoepfe(y + 4.0 + roundf(4.0 * (1.0 - _aus(_anteil(0.9, 0.3)))))
	y += 26.0
	return y + 24.0 - y0


func _mittig(y: float, text: String, groesse: int, farbe: Color) -> void:
	if not _messen and text != "":
		Stil.schreibe_mittig(self, Vector2(MITTE_X, y), text, groesse, farbe)


func _titel(y: float) -> void:
	if _messen:
		return
	var text := str(conf.get("titel", ""))
	var farbe: Color = conf.get("titel_farbe", Stil.GOLD)
	var a := _aus(_anteil(0.35, 0.4))
	var dx := 0.0
	var flackern := 0.0
	if conf.get("glitch", false):
		# Störung: am Anfang kräftig, danach alle paar Sekunden kurz
		var phase := fmod(_t, 3.4)
		flackern = (1.0 - _anteil(0.35, 0.9)) + (1.0 if phase > 3.2 else 0.0)
		if flackern > 0.0:
			dx = roundf(sin(_t * 91.0) * 2.5 * flackern)
			Stil.schreibe_mittig(self, Vector2(MITTE_X - 2.0 + dx, y), text, 28, Color(0.3, 0.9, 1.0, 0.45 * a * minf(flackern, 1.0)))
			Stil.schreibe_mittig(self, Vector2(MITTE_X + 2.0 - dx, y + 1.0), text, 28, Color(1.0, 0.2, 0.3, 0.45 * a * minf(flackern, 1.0)))
	Stil.schreibe_mittig(self, Vector2(MITTE_X + 1.0 + dx, y + 1.0), text, 28, Color(farbe.darkened(0.7), a))
	Stil.schreibe_mittig(self, Vector2(MITTE_X + dx, y), text, 28, Color(farbe, a))
	if flackern > 0.0:
		# zwei verrutschte Streifen quer durch den Titel
		for i in 2:
			var sy := y - 8.0 + fmod(_t * 37.0 + i * 9.0, 16.0)
			draw_rect(Rect2(MITTE_X - 70.0 + dx * 3.0, roundf(sy), 140.0, 1.0), Color(farbe, 0.35 * a))
	var linie := _aus(_anteil(0.55, 0.5)) * 120.0
	var ly := y + 17.0
	draw_rect(Rect2(MITTE_X - linie, ly, linie * 2.0, 1.0), Color(farbe, 0.8 * a))
	draw_rect(Rect2(MITTE_X - linie * 0.45, ly + 1.0, linie * 0.9, 1.0), Color(farbe, 0.3 * a))


func _kacheln(kacheln: Array, y: float) -> void:
	if _messen:
		return
	var zaehl := _aus(_anteil(0.7, 1.1))
	var n := kacheln.size()
	var abstand := 6.0
	var kb := (INNEN_B - abstand * (n - 1)) / n
	var x := MITTE_X - INNEN_B / 2.0
	for k: Dictionary in kacheln:
		var farbe: Color = k.get("farbe", Stil.TEXT)
		var kr := Rect2(roundf(x), y, roundf(kb), 40.0)
		Stil.platte(self, kr, 2.0, Stil.METALL_TIEF, Stil.RAHMEN)
		draw_rect(Rect2(kr.position.x + 3.0, kr.position.y + 2.0, kr.size.x - 6.0, 1.0), Color(farbe, 0.6))
		var wert := _kachel_wert(k, zaehl)
		var gr := Stil.GROSS if Stil.breite(wert, Stil.GROSS) <= kr.size.x - 8.0 else Stil.NORMAL
		var sym := str(k.get("symbol", ""))
		if sym != "":
			var w := Stil.breite(wert, gr)
			Stil.symbol(self, sym, Vector2(kr.get_center().x - w / 2.0 - 6.0, kr.position.y + 16.0), 1.0, farbe)
			Stil.schreibe(self, Vector2(kr.get_center().x - w / 2.0 + 2.0, kr.position.y + 16.0), wert, gr, farbe)
		else:
			Stil.schreibe_mittig(self, Vector2(kr.get_center().x, kr.position.y + 16.0), wert, gr, farbe)
		Stil.schreibe_mittig(self, Vector2(kr.get_center().x, kr.position.y + 31.0), str(k.get("name", "")), Stil.KLEIN, Stil.TEXT_BLASS)
		x += kb + abstand


static func _kachel_wert(k: Dictionary, zaehl: float) -> String:
	if k.has("text"):
		return str(k["text"])
	var z := roundi(float(k.get("zahl", 0)) * zaehl)
	if k.get("zeit", false):
		return "%d:%02d" % [z / 60, z % 60]
	if int(k.get("max", -1)) >= 0:
		return "%d/%d" % [z, int(k["max"])]
	return str(z)


## Kasten mit Überschrift, Text (optional zeichenweise getippt) und Knopf rechts. Gibt die Höhe zurück.
func _kasten(k: Dictionary, y: float) -> float:
	var text := str((k["text_fn"] as Callable).call()) if k.has("text_fn") else str(k.get("text", ""))
	var hat_knopf: bool = k.has("knopf")
	var weite := INNEN_B - 16.0 - (84.0 if hat_knopf else 0.0)
	var h := maxf(36.0, roundf(22.0 + Stil.absatz_groesse(text, weite, Stil.KLEIN).y + 4.0))
	if _messen:
		return h
	var farbe: Color = k.get("farbe", Stil.LEUCHT)
	var pr := Rect2(MITTE_X - INNEN_B / 2.0, y, INNEN_B, h)
	var puls := 0.5 + 0.5 * sin(_t * 2.2)
	Stil.platte(self, pr, 2.0, Color(farbe, 0.07 + 0.03 * puls), Color(farbe, 0.55 + 0.3 * puls))
	Stil.schreibe(self, Vector2(pr.position.x + 8.0, pr.position.y + 10.0), str(k.get("titel", "")), Stil.NORMAL, farbe)
	if k.get("tippen", false):
		var n := clampi(int((_t - 1.0) * 45.0), 0, text.length())
		text = text.left(n) + ("_" if n < text.length() and fmod(_t, 0.5) < 0.25 else "")
	Stil.absatz(self, Vector2(pr.position.x + 8.0, pr.position.y + 18.0), text, weite, Stil.KLEIN, Stil.TEXT_BLASS.lerp(Stil.TEXT, 0.35))
	if hat_knopf:
		var kr := Rect2(pr.end.x - 84.0, roundf(pr.get_center().y - 9.0), 76.0, 18.0)
		_kasten_knoepfe.append([kr, k["knopf"][1]])
		var drueber := kr.has_point(_maus)
		Stil.platte(self, kr, 2.0, Color(farbe, 0.22 if drueber else 0.1), farbe)
		Stil.schreibe_mittig(self, kr.get_center(), str(k["knopf"][0]), Stil.KLEIN, Color.WHITE if drueber else farbe)
	return h


## Drei Kacheln mit Symbol und kurzer Beschriftung, dazwischen Pfeile; sie erscheinen nacheinander.
func _comic(kacheln: Array, y: float) -> void:
	if _messen:
		return
	var n := kacheln.size()
	var pfeil := 14.0
	var kb := (INNEN_B - pfeil * (n - 1)) / n
	var x := MITTE_X - INNEN_B / 2.0
	for i in n:
		var k: Array = kacheln[i]
		var farbe: Color = k[2] if k.size() > 2 else Stil.LEUCHT
		var ein := _aus(_anteil(0.9 + 0.35 * i, 0.35))
		var kr := Rect2(roundf(x), y + 4.0 * (1.0 - ein), roundf(kb), 44.0)
		Stil.platte(self, kr, 2.0, Color(Stil.METALL_TIEF, ein), Color(farbe, 0.6 * ein))
		Stil.symbol(self, str(k[0]), Vector2(kr.get_center().x, kr.position.y + 15.0), 2.0, Color(farbe, ein))
		Stil.schreibe_mittig(self, Vector2(kr.get_center().x, kr.position.y + 34.0), str(k[1]), Stil.KLEIN, Color(Stil.TEXT, ein))
		x += kb
		if i < n - 1:
			var pa := _aus(_anteil(1.05 + 0.35 * i, 0.3))
			var pm := Vector2(x + pfeil / 2.0, kr.get_center().y)
			draw_colored_polygon(PackedVector2Array([pm + Vector2(-3, -4), pm + Vector2(3, 0), pm + Vector2(-3, 4)]), Color(Stil.GOLD, pa))
			x += pfeil


func _male_knoepfe(y: float) -> void:
	var knoepfe: Array = conf.get("knoepfe", [])
	var breiten: Array = []
	var gesamt := 0.0
	for i in knoepfe.size():
		var b := maxf(78.0, Stil.breite(str(knoepfe[i][0]), Stil.NORMAL) + 24.0)
		breiten.append(b)
		gesamt += b + (8.0 if i > 0 else 0.0)
	var x := roundf(MITTE_X - gesamt / 2.0)
	for i in knoepfe.size():
		var kr := Rect2(x, y, breiten[i], 22.0)
		_rechtecke.append(kr)
		var farbe: Color = knoepfe[i][2]
		var an := i == _wahl
		var puls := (0.5 + 0.5 * sin(_t * 3.0)) if i == 0 else 0.0
		var rand := farbe if an else Stil.RAHMEN.lerp(farbe, 0.35 + 0.4 * puls)
		Stil.platte(self, kr, 3.0, Color(farbe, 0.2 if an else 0.06), rand)
		if an:
			draw_rect(Rect2(kr.position.x + 4.0, kr.end.y - 3.0, kr.size.x - 8.0, 1.0), Color(farbe, 0.8))
		Stil.schreibe_mittig(self, kr.get_center(), str(knoepfe[i][0]), Stil.NORMAL, Color.WHITE if an else farbe)
		x += breiten[i] + 8.0


func _male_teilchen(a: float) -> void:
	var art := str(conf.get("effekt", ""))
	if a <= 0.0 or art == "":
		return
	for f: Array in _teilchen:
		var p := fmod(f[1] + _t / f[2], 1.0)
		var hell := sin(p * PI) * a
		match art:
			"asche":
				# Glut und Asche fallen schräg herab
				var pos := Vector2(f[0] + p * 40.0 + sin(_t + f[3]) * 4.0, -10.0 + p * 380.0)
				var farbe := Color(1.0, 0.35 + 0.3 * f[4], 0.2) if f[4] > 0.45 else Color(0.55, 0.55, 0.6)
				draw_rect(Rect2(pos.round(), Vector2.ONE * (2.0 if f[4] > 0.85 else 1.0)), Color(farbe, 0.6 * hell))
			_:
				var farbe := Stil.GOLD if art == "funken" else Stil.KUPFER
				var pos := Vector2(f[0] + sin(_t * 0.8 + f[3]) * 6.0, 360.0 - p * 380.0)
				draw_rect(Rect2(pos.round(), Vector2.ONE), Color(farbe, 0.55 * hell))


# ------------------------------------------------------------------ Eingabe

func _frei() -> bool:
	return visible and _t > 0.5 and not (gesperrt.is_valid() and bool(gesperrt.call()))


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_maus = event.position
		for i in _rechtecke.size():
			if (_rechtecke[i] as Rect2).has_point(_maus):
				_wahl = i
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and _frei():
		for kk: Array in _kasten_knoepfe:
			if (kk[0] as Rect2).has_point(event.position):
				(kk[1] as Callable).call()
				return
		for i in _rechtecke.size():
			if (_rechtecke[i] as Rect2).has_point(event.position):
				(conf["knoepfe"][i][1] as Callable).call()
				return


func _input(event: InputEvent) -> void:
	if not _frei() or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var n: int = (conf.get("knoepfe", []) as Array).size()
	match (event as InputEventKey).keycode:
		KEY_LEFT, KEY_A:
			_wahl = posmod(_wahl - 1, n)
		KEY_RIGHT, KEY_D, KEY_TAB:
			_wahl = posmod(_wahl + 1, n)
		KEY_ENTER, KEY_KP_ENTER:
			(conf["knoepfe"][_wahl][1] as Callable).call()
		KEY_ESCAPE:
			if conf.has("esc"):
				(conf["esc"] as Callable).call()
		_:
			return
	get_viewport().set_input_as_handled()
