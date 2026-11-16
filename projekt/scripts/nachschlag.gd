class_name Nachschlag
extends Control
## Formationen [H] (16.11.2026 im Stil der neuen Oberfläche, wie die Übersicht [I]): bekannte Erdwall-Formationen
## als Skizzen mit Stärke und Schwäche. Links neun Kärtchen, rechts die gewählte groß mit Erklärung und Legende.
## Nur zum Ansehen und Ideen holen – gebaut wird weiter von Hand. Gezeichnet im UI-Raster 640×360 (zweifach skaliert).
## Die Pläne sind für die große Karte (28×14, Zone Spalten 0–2, Basis 3×2 um (26, 7)) neu gezeichnet; die alten für die
## normale Karte stehen weiter in werkzeuge/plaene.gd (Probeläufe). Der gestrichelte Weg ist der kürzeste Weg der
## Gegner vom Start über beide Checkpoints in die Basis (Tore und Fabriken sperren, wie im Spiel).
## Alte Fassung: _vor_formationen/nachschlag.gd.

const Stil := preload("res://scripts/ui/ui_stil.gd")
const RAHMEN_R := Rect2(8, 8, 624, 344)
const GITTER := Rect2(14, 36, 312, 310)
const TAFEL_R := Rect2(332, 36, 294, 310)
const SCHLIESSEN := Rect2(604, 13, 20, 17)
const GUT := Color("8dff8a")
const SCHLECHT := Color("ff8a7a")

## Plan -> [Name, wofür gut, wofür anfällig]
const TEXTE := {
	"1-schlauch": ["Langer Schlauch", "Längster Weg, wächst Wand für Wand.", "Sprenger, Checkpoints tief im Gang, keine Türme."],
	"2-kamm": ["Kamm", "Langer Weg, weite Sicht, jeder Zahn stützt einen Turm.", "Teuer, halb gebaut wenig wert."],
	"3-zitadelle": ["Zitadelle", "Ein Wallstück: alle sehen alles. Fabriken im Kern, Tor als Ausgang.", "Kurzer Weg, dünne Arme für Sprenger."],
	"4-inseln": ["Inseln", "Viel Feuerkraft, kurze Fußwege.", "Keine Wegführung, erst mit Türmen stark."],
	"5-doppelriegel": ["Doppelriegel", "Sprengsicher und billig, die dicke Mauer stützt Türme.", "Kürzester Weg, nah an der Schleuder."],
	"6-gestaffelt": ["Gestaffelte Linien", "Billig und schnell gebaut.", "Die Linien verdecken sich die Sicht."],
	"7-kamm-mit-kern": ["Kamm mit Kern", "Langer Weg und geschützte Fabriken mit Tor.", "Dünne Zähne für Sprenger."],
	"8-riegel-und-schlauch": ["Riegel und Schlauch", "Türme vorn, langer Weg dahinter.", "Sprenger, Checkpoints tief im Gang."],
	"9-dicker-schlauch": ["Dicker Schlauch", "Sprengsicher, Stützen für mehrere Türme.", "Teuer, erst fertig stark."],
}

const PLAENE_GROSS := {
	"1-schlauch": [
		".....#...#...#...#...#......",
		".....#.#.#.#.#.#.#.#.#.#.F..",
		".....#.#.#.#.#.#.#.#.#.#....",
		".....#.#.#.#.#.#.#.#.#.#.F..",
		".....S.S.S.S.S.S.S.S.S.S....",
		".....#.#.#.#.#.#.#.#.#.#....",
		".....#.#1#.#.#.#.#.#.#.#....",
		".....#.#.#.#.#.#.#2#.#.#....",
		".....#.#.#.#.#.#.#.#.#.#....",
		".....S.S.S.S.S.S.S.S.S.S....",
		".....#.#.#.#.#.#.#.#.#.#.F..",
		".....#.#.#.#.#.#.#.#.#.#....",
		".....#.#.#.#.#.#.#.#.#.#.F..",
		".......#...#...#...#...#....",
	],
	"2-kamm": [
		"....##T###T###T###T###T###..",
		"......#...#...#...#...#.....",
		"......#...#...#...#...#.....",
		"....F.#...#...#...#...#..F..",
		"......#.#.#.#.#.#.#.#.#.....",
		"......#.#.#.#.#.#.#.#.#.....",
		"......S.#1S.#.S.#.S.#.S.....",
		"......#.#.#.#.#.#.#2#.#.....",
		"......#.S.#.S.#.S.#.S.#.....",
		"......#.#.#.#.#.#.#.#.#.....",
		"....F...#...#...#...#....F..",
		"........#...#...#...#.......",
		"........#...#...#...#...F...",
		"....####T###T###T###T####...",
	],
	"3-zitadelle": [
		"............................",
		"...........S......S.........",
		"...........#......#.....F...",
		"...........#......#.........",
		"......S####T###########S....",
		"...........#......#.........",
		"........1..#.F..F.O.........",
		"...........#.F..F.#..2......",
		"...........#......#.........",
		"......S###########T####S....",
		"...........#......#.........",
		"...........#......#.....F...",
		"...........S......S.........",
		"............................",
	],
	"4-inseln": [
		"............................",
		"......S...........S.........",
		".....#T#.........#T#........",
		"......S...........S.........",
		".........F.....F.....F......",
		"............S...............",
		"...........#T#......2..S....",
		".........1..S.........#T#...",
		".......................S....",
		".........F.....F............",
		"......S...........S.........",
		".....#T#.........#T#........",
		"......S...........S.........",
		"............................",
	],
	"5-doppelriegel": [
		"....##......................",
		"....T#......................",
		"....#S.F....................",
		"....#S....F.................",
		"....##......................",
		"............................",
		".........1..................",
		"..................2.........",
		"............................",
		"....##......................",
		"....#S....F.................",
		"....#S.F....................",
		"....T#......................",
		"....##..F...................",
	],
	"6-gestaffelt": [
		".......#.....#.....#........",
		".......#...........#........",
		".......S..F..S.....S........",
		".......#.....#.....#..F.....",
		".......#.....#..F..#........",
		".......S.....S.....S........",
		"..........1..#..............",
		".............#...2..........",
		".......S.....S.....S........",
		".......#.....#..F..#........",
		".......#.....#.....#........",
		".......S..F..S.....S........",
		".......#...........#........",
		".......#.....#.....#........",
	],
	"7-kamm-mit-kern": [
		"....##T###T###T###########..",
		"......#...#...#....#.....#..",
		"......#...#...#....#.FFF.#..",
		"......#...#...#....S.....S..",
		"......#.#.#.#.#.#..#.....#..",
		"......#.#.#.#.#.#..T##O###..",
		"......S.#1S.#.S.#...........",
		"......#.#.#.#.#.#...........",
		"......#.S.#.S.#.S...........",
		"......#.#.#.#.#.#.2.........",
		"........#...#...#.....F.....",
		"........#...#...#...........",
		"........#...#...#.......F...",
		"....####T###T###T###........",
	],
	"8-riegel-und-schlauch": [
		"....##...#...#...#...#......",
		"....T#...#.#.#.#.#.#.#.#.F..",
		"....#S...#.#.#.#.#.#.#.#....",
		"....#S...#.#.#.#.#.#.#.#.F..",
		"....##...#.#.#.#.#.#.#.#....",
		".........#.#.#.#.#.#.#.#....",
		".......1.S.S.S.S.S.S.S.S....",
		".........#.#.#.#.#2#.#.#....",
		".........#.#.#.#.#.#.#.#....",
		"....##...#.#.#.#.#.#.#.#....",
		"....#S...#.#.#.#.#.#.#.#.F..",
		"....#S...#.#.#.#.#.#.#.#....",
		"....T#...#.#.#.#.#.#.#.#.F..",
		"....##.....#...#...#...#....",
	],
	"9-dicker-schlauch": [
		".....##........##...........",
		".....##........##...........",
		".....##...##...##...##..F...",
		".....T#.F.T#...T#.F.T#......",
		".....##...##...##...##......",
		".....##...##...##...##......",
		".....#S...#S...#S...#S......",
		".....##.1.##...##.2.##......",
		".....##...##...##...##......",
		".....T#...T#...T#...T#......",
		".....##...##.F.##...##.F....",
		".....##...##...##...##......",
		"..........##........##......",
		"..........##........##......",
	],
}
const SP := 28
const ZE := 14
const START := Vector2i(0, 6)
const BASIS := Vector2i(26, 7)

## Farben der Skizze (wie die Tech-Mauer im Spiel: Stahlgrau, Cyan für alles Eigene, Kupfer für die Myriaden)
const BODEN := Color("1e2a24")
const BODEN_RASTER := Color("26342c")
const ZONE := Color("3a2a20")
const WALL := Color("7d8898")
const WALL_KANTE := Color("a9b4c2")
const STELLUNG := Color("7fe0ff")
const TURM := Color("ffd34d")
const TOR := Color("15171c")
const FABRIK := Color("9a7be0")
const CHECKPOINT := Color("e08a4f")
const BASIS_FARBE := Color("7fe0ff")

var _wahl := 0
var _maus := Vector2(-100, -100)
var _zeit := 0.0
var _namen: Array = []
var _wege := {}                # Plan -> Weg der Gegner (einmal berechnet)


func _ready() -> void:
	size = Vector2(640, 360)
	scale = Vector2(Stil.UI_SKALA, Stil.UI_SKALA)
	mouse_filter = Control.MOUSE_FILTER_STOP   # solange die Karte offen ist, wird nicht versehentlich gebaut
	visible = false
	_namen = PLAENE_GROSS.keys()


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
	elif event is InputEventMouseButton and event.pressed:
		var p: Vector2 = event.position
		if event.button_index == MOUSE_BUTTON_RIGHT or (event.button_index == MOUSE_BUTTON_LEFT and SCHLIESSEN.has_point(p)):
			visible = false
			return
		if event.button_index != MOUSE_BUTTON_LEFT:
			return
		for i in _namen.size():
			if _karten_recht(i).has_point(p):
				_wahl = i
				return


func _karten_recht(i: int) -> Rect2:
	var w := (GITTER.size.x - 8.0) / 3.0
	var h := (GITTER.size.y - 8.0) / 3.0
	return Rect2(GITTER.position + Vector2((i % 3) * (w + 4.0), int(i / 3.0) * (h + 4.0)), Vector2(w, h)).abs()


# ------------------------------------------------------------------ Zeichnen

func _draw() -> void:
	draw_rect(Rect2(Vector2(-8, -8), size + Vector2(16, 16)), Color(0.02, 0.03, 0.05, 0.72))
	Stil.platte(self, RAHMEN_R, 4.0, Stil.METALL_TIEF, Stil.RAHMEN)
	Stil.symbol(self, "raster", Vector2(23, 21), 1.5, Stil.LEUCHT)
	Stil.schreibe(self, Vector2(34, 21), "Formationen", Stil.GROSS, Stil.TEXT)
	var tipp := "Ideen zum Nachbauen, keine Vorschrift · Kärtchen anklicken · [H] schließt"
	Stil.schreibe(self, Vector2(SCHLIESSEN.position.x - 8.0 - Stil.breite(tipp, Stil.KLEIN), 21), tipp, Stil.KLEIN, Stil.TEXT_BLASS)
	var zu_an := SCHLIESSEN.has_point(_maus)
	Stil.platte(self, SCHLIESSEN, 2.0, Stil.METALL_DUNKEL, Stil.LEUCHT if zu_an else Stil.RAHMEN)
	var m := SCHLIESSEN.get_center().floor()
	for i in range(-3, 4):
		for d: Vector2 in [Vector2(1, 1), Vector2(1, -1)]:
			draw_rect(Rect2(m + d * float(i) - Vector2(1, 1), Vector2(2, 2)), Stil.LEUCHT if zu_an else Stil.TEXT)
	for i in _namen.size():
		_zeichne_karte(i)
	_zeichne_tafel(_namen[_wahl])


func _zeichne_karte(i: int) -> void:
	var r := _karten_recht(i)
	var gewaehlt := i == _wahl
	var drueber := r.has_point(_maus)
	Stil.platte(self, r, 3.0, Stil.METALL if gewaehlt else Stil.METALL_DUNKEL, Stil.LEUCHT if gewaehlt else (Stil.RAHMEN_HELL if drueber else Stil.RAHMEN))
	var k := floorf((r.size.x - 10.0) / SP)
	var skizze := Vector2(SP, ZE) * k
	var oben := roundf(r.position.y + (r.size.y - skizze.y - 30.0) / 2.0)
	_skizze(_namen[i], Vector2(r.get_center().x - skizze.x / 2.0, oben).round(), k, gewaehlt or drueber)
	var texte: Array = TEXTE.get(_namen[i], [_namen[i], "", ""])
	var unten := oben + skizze.y
	Stil.schreibe_mittig(self, Vector2(r.get_center().x, unten + 11.0), texte[0], Stil.NORMAL, Stil.TEXT if gewaehlt or drueber else Stil.TEXT_BLASS)
	var z := _zaehle(_namen[i])
	var weg := "Weg %d Felder" % z["weg"] if z["weg"] > 0 else "kein Durchgang"
	Stil.schreibe_mittig(self, Vector2(r.get_center().x, unten + 22.0), "%s · %d Türme" % [weg, z["turm"]], Stil.KLEIN, Stil.TEXT_BLASS)


func _zeichne_tafel(plan_name: String) -> void:
	Stil.platte(self, TAFEL_R, 4.0, Stil.METALL_DUNKEL, Stil.RAHMEN)
	var o := TAFEL_R.position
	var texte: Array = TEXTE.get(plan_name, [plan_name, "", ""])
	Stil.schreibe(self, o + Vector2(10, 13), texte[0], Stil.GROSS, Stil.TEXT)
	var nr := "%d / %d" % [_wahl + 1, _namen.size()]
	Stil.schreibe(self, Vector2(TAFEL_R.end.x - 10.0 - Stil.breite(nr, Stil.KLEIN), o.y + 13.0), nr, Stil.KLEIN, Stil.TEXT_BLASS)
	# große Skizze auf einem Sockel
	var k := 10.0
	var sockel := Rect2(o + Vector2(0, 25), Vector2(SP * k + 8.0, ZE * k + 8.0))
	sockel.position.x = roundf(TAFEL_R.get_center().x - sockel.size.x / 2.0)
	Stil.platte(self, sockel, 3.0, Stil.METALL_TIEF, Stil.RAHMEN)
	_skizze(plan_name, sockel.position + Vector2(4, 4), k, true)
	# Stärke und Schwäche
	var y := sockel.end.y + 5.0
	for teil: Array in [["Stark", texte[1], GUT], ["Anfällig", texte[2], SCHLECHT]]:
		var feld := Rect2(Vector2(o.x + 8.0, y), Vector2(TAFEL_R.size.x - 16.0, 30))
		Stil.platte(self, feld, 2.0, Stil.METALL_TIEF, Stil.RAHMEN)
		Stil.schreibe(self, feld.position + Vector2(6, 6), teil[0], Stil.KLEIN, teil[2])
		Stil.absatz(self, feld.position + Vector2(6, 11), teil[1], feld.size.x - 12.0, Stil.NORMAL, Stil.TEXT)
		y += 33.0
	# Zahlen wie in der Übersicht
	var z := _zaehle(plan_name)
	var felder := [["Gegnerweg", "%d Felder" % z["weg"] if z["weg"] > 0 else "zu"], ["Wallfelder", z["wall"]], ["Stellungen", z["stellung"]], ["Türme", z["turm"]]]
	var fw := (TAFEL_R.size.x - 16.0 - 3.0 * 4.0) / 4.0
	for i in felder.size():
		var feld := Rect2(Vector2(o.x + 8.0 + i * (fw + 4.0), y), Vector2(fw, 22))
		Stil.platte(self, feld, 2.0, Stil.METALL_TIEF, Stil.RAHMEN)
		Stil.schreibe(self, feld.position + Vector2(4, 6), str(felder[i][0]), Stil.KLEIN, Stil.TEXT_BLASS)
		Stil.schreibe(self, feld.position + Vector2(4, 15), str(felder[i][1]), Stil.NORMAL, Stil.TEXT)
	_legende(Vector2(o.x + 10.0, TAFEL_R.end.y - 21.0))


## Skizze eines Plans auf der großen Karte: k UI-Pixel je Feld. Mauern mit heller Krone und dunkler Flanke (wie die
## Tech-Mauer), Zone der Myriaden links in Kupfer, Basis rechts, darüber der Weg der Gegner als wandernde Punkte.
func _skizze(plan_name: String, ecke: Vector2, k: float, lebendig: bool) -> void:
	var plan: Array = PLAENE_GROSS[plan_name]
	draw_rect(Rect2(ecke, Vector2(SP, ZE) * k), BODEN)
	if k >= 6.0:
		for x in range(1, SP):
			draw_rect(Rect2(ecke + Vector2(x * k, 0), Vector2(1, ZE * k)), BODEN_RASTER)
		for y in range(1, ZE):
			draw_rect(Rect2(ecke + Vector2(0, y * k), Vector2(SP * k, 1)), BODEN_RASTER)
	draw_rect(Rect2(ecke, Vector2(3 * k, ZE * k)), ZONE)
	draw_rect(Rect2(ecke + Vector2(3 * k - 1.0, 0), Vector2(1, ZE * k)), Color(Stil.KUPFER, 0.5))
	# Basis 3×2
	var basis := Rect2(ecke + Vector2(BASIS.x - 1, BASIS.y - 1) * k, Vector2(3, 2) * k).grow(-maxf(0.5, k / 8.0))
	draw_rect(basis, Color(BASIS_FARBE, 0.22))
	draw_rect(basis, BASIS_FARBE, false, 1.0)
	# Weg der Gegner
	var weg := _weg(plan_name)
	if weg.size() > 1:
		var schritt := 0.5 if k >= 6.0 else 1.0
		var lauf := fmod(_zeit * 4.0, 2.0) if lebendig else 0.0
		for i in weg.size() - 1:
			var a: Vector2 = ecke + (Vector2(weg[i]) + Vector2(0.5, 0.5)) * k
			var b: Vector2 = ecke + (Vector2(weg[i + 1]) + Vector2(0.5, 0.5)) * k
			var t := 0.0
			while t < 1.0:
				if fmod(i + t + 2.0 - lauf, 2.0) < 1.0:
					var p := a.lerp(b, t).round()
					var d := maxf(1.0, floorf(k / 5.0))
					draw_rect(Rect2(p - Vector2(d, d) / 2.0, Vector2(d, d)), Color(Stil.KUPFER, 0.75))
				t += schritt
	var puls := 0.75 + 0.25 * sin(_zeit * 3.0)
	for y in plan.size():
		for x in (plan[y] as String).length():
			var c: String = plan[y][x]
			var feld := Rect2(ecke + Vector2(x, y) * k, Vector2(k, k))
			var rand := maxf(1.0, floorf(k / 4.0))
			var innen := feld.grow(-rand)
			match c:
				"#":
					_mauer(feld, k, plan, x, y)
				"S":
					_mauer(feld, k, plan, x, y)
					draw_rect(innen, Color(STELLUNG, 0.9))
				"T":
					_mauer(feld, k, plan, x, y)
					draw_rect(innen, TURM)
					if k >= 6.0:
						draw_rect(innen.grow(-1.0), TURM.lightened(0.35))
				"O":
					_mauer(feld, k, plan, x, y)
					draw_rect(innen, TOR)
					draw_rect(innen, Color(STELLUNG, 0.7), false, 1.0)
				"F":
					var f := feld.grow(-maxf(0.5, k / 8.0))
					draw_rect(f, FABRIK.darkened(0.3))
					draw_rect(Rect2(f.position, Vector2(f.size.x, f.size.y * 0.6)), FABRIK)
					if k >= 6.0:
						draw_rect(Rect2(f.get_center() - Vector2(1, 1), Vector2(2, 2)), Color(Stil.LEUCHT, 0.9))
				"B":
					draw_rect(feld.grow(-maxf(0.5, k / 8.0)), Stil.GOLD)
				"1", "2":
					var m := feld.get_center()
					var r := maxf(1.5, k * 0.36)
					draw_circle(m, r + 1.0, Color(0, 0, 0, 0.5))
					draw_circle(m, r, Color(CHECKPOINT, puls))
					if k >= 6.0:
						Stil.schreibe_mittig(self, m + Vector2(0, 0.5), c, Stil.KLEIN, Color.BLACK)


## Ein Mauerfeld. Mit `plan` bekommt nur die Oberkante einer Mauer die helle Krone und nur die Unterkante die
## dunkle Flanke – so wirken zusammenhängende Wälle wie ein Stück.
func _mauer(feld: Rect2, k: float, plan: Array = [], x: int = -1, y: int = -1) -> void:
	draw_rect(feld, WALL)
	var oben_frei := plan.is_empty() or y == 0 or not (str(plan[y - 1][x]) in ["#", "S", "T", "O"])
	var unten_frei := plan.is_empty() or y == ZE - 1 or not (str(plan[y + 1][x]) in ["#", "S", "T", "O"])
	var d := 2.0 if k >= 6.0 else 1.0
	if oben_frei:
		draw_rect(Rect2(feld.position, Vector2(feld.size.x, d)), WALL_KANTE)
	if unten_frei and k >= 6.0:
		draw_rect(Rect2(feld.position + Vector2(0, feld.size.y - d), Vector2(feld.size.x, d)), WALL.darkened(0.4))


## Kürzester Weg vom Start über Checkpoint 1 und 2 in die Basis (Breitensuche, vier Richtungen). Leer, wenn zu.
func _weg(plan_name: String) -> Array:
	if _wege.has(plan_name):
		return _wege[plan_name]
	var plan: Array = PLAENE_GROSS[plan_name]
	var ziele: Array = []
	for c in ["1", "2"]:
		for y in plan.size():
			var x := (plan[y] as String).find(c)
			if x >= 0:
				ziele.append(Vector2i(x, y))
	ziele.append(BASIS)
	var weg: Array = [START]
	var von := START
	for ziel: Vector2i in ziele:
		var stueck := _bfs(plan, von, ziel)
		if stueck.is_empty():
			weg = []
			break
		weg.append_array(stueck.slice(1))
		von = ziel
	_wege[plan_name] = weg
	return weg


func _bfs(plan: Array, a: Vector2i, b: Vector2i) -> Array:
	var vor := {a: a}
	var offen: Array = [a]
	while not offen.is_empty():
		var z: Vector2i = offen.pop_front()
		if z == b:
			var pfad: Array = [b]
			while pfad[0] != a:
				pfad.push_front(vor[pfad[0]])
			return pfad
		for d: Vector2i in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(-1, 0)]:
			var n: Vector2i = z + d
			if n.x < 0 or n.y < 0 or n.x >= SP or n.y >= ZE or vor.has(n):
				continue
			if not (str(plan[n.y][n.x]) in [".", "1", "2"]):
				continue
			vor[n] = z
			offen.append(n)
	return []


## Wie viel steckt in einem Plan? Wallfelder zählen alles, was auf einem Wall steht (Stellung, Turm, Tor).
func _zaehle(plan_name: String) -> Dictionary:
	var z := {"wall": 0, "stellung": 0, "turm": 0, "fabrik": 0, "weg": maxi(0, _weg(plan_name).size() - 1)}
	for zeile: String in PLAENE_GROSS[plan_name]:
		for c in zeile:
			if c in ["#", "S", "T", "O"]:
				z["wall"] += 1
			if c == "S":
				z["stellung"] += 1
			elif c == "T":
				z["turm"] += 1
			elif c == "F":
				z["fabrik"] += 1
	return z


func _legende(links: Vector2) -> void:
	var eintraege := [["#", "Erdwall"], ["S", "Stellung"], ["T", "Turm"], ["O", "Tor"], ["F", "Fabrik"], ["1", "Checkpoint"], ["Z", "Zone"], ["H", "Basis"], ["W", "Gegnerweg"]]
	var x := links.x
	var y := links.y
	for e: Array in eintraege:
		var w := 12.0 + Stil.breite(e[1], Stil.KLEIN) + 8.0
		if x + w > TAFEL_R.end.x - 8.0:
			x = links.x
			y += 11.0
		var f := Rect2(Vector2(x, y), Vector2(8, 8))
		match e[0]:
			"#": _mauer(f, 8.0)
			"S":
				_mauer(f, 8.0)
				draw_rect(f.grow(-2.0), STELLUNG)
			"T":
				_mauer(f, 8.0)
				draw_rect(f.grow(-2.0), TURM)
			"O":
				_mauer(f, 8.0)
				draw_rect(f.grow(-2.0), TOR)
			"F": draw_rect(f, FABRIK)
			"1": draw_circle(f.get_center(), 3.5, CHECKPOINT)
			"Z": draw_rect(f, ZONE)
			"W":
				for dx in [0, 4]:
					draw_rect(Rect2(f.position + Vector2(dx, 3), Vector2(2, 2)), Color(Stil.KUPFER, 0.8))
			"H":
				draw_rect(f, Color(BASIS_FARBE, 0.25))
				draw_rect(f, BASIS_FARBE, false, 1.0)
		Stil.schreibe(self, Vector2(x + 11.0, y + 4.0), e[1], Stil.KLEIN, Stil.TEXT_BLASS)
		x += w
