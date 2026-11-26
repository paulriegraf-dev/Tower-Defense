class_name BrakkGebiete
extends RefCounted
## E (26.11., Paul): Befehl 24 – die eigene große Karte (ORDER24_KARTE, 36×18) mit Gebieten und Zufluchten. Nur dieser
## Modus: Normalmodus, Sandbox und Phantom bleiben bei 28×14, ebenso Befehl 24 mit Phantom-Verteidigung oder nach Classic
## (die spielen auf der alten Karte szenario_order24).
## Die Karte entsteht im Code aus szenario_order24: Größe aus einer Konstante, Myriaden im Westen, Technoclan-HQ im Osten.

const VORLAGE := "szenario_order24"


## Die Kartendaten (wie aus einer Karten-Datei) für die Befehl-24-Karte in ORDER24_KARTE.
static func karte_daten() -> Dictionary:
	var k: Dictionary = Werte.karten_daten(VORLAGE).duplicate(true)
	if k.is_empty():
		return {}
	var s := Werte.ORDER24_KARTE.x
	var z := Werte.ORDER24_KARTE.y
	var mitte := z / 2 - 1
	k["spalten"] = s
	k["zeilen"] = z
	k["hq"] = [0, mitte]
	k["angriff"] = [1, mitte]
	k["ausgaenge"] = {"mitte": [0, mitte], "oben": [1, 1], "unten": [1, z - 2]}
	k["basis"] = [s - 2, z / 2]
	k["checkpoint_bereiche"] = [[6, 1, 9, z - 2], [12, 1, 11, z - 2]]
	k["checkpoints"] = [[8, mitte], [17, mitte + 1]]
	var schleuder: Array = []
	for y in range(0, 5):
		schleuder.append([1, y])
	for y in range(z - 5, z):
		schleuder.append([1, y])
	k["schleuder_plaetze"] = schleuder
	k["zonenbauten_zeilen"] = (k["zonenbauten_zeilen"] as Array).map(func(y: Variant) -> int: return clampi(roundi(float(y) * float(z) / 14.0), 0, z - 1))
	var regeln: Dictionary = k.get("regeln", {})
	var o24: Dictionary = regeln.get("order24", {})
	o24["gebiete"] = true   # Order24: Gebiete, Zufluchten, Formationen _b24
	regeln["order24"] = o24
	k["regeln"] = regeln
	return k


## Das Rechteck eines Gebiets auf der aktuellen Karte (aus ORDER24_GEBIETE auf 36×18 gestreckt).
static func rechteck(name: String) -> Rect2i:
	var r: Rect2i = Werte.ORDER24_GEBIETE[name]
	var fx := float(Werte.SPALTEN) / 36.0
	var fy := float(Werte.ZEILEN) / 18.0
	var a := Vector2i(roundi(r.position.x * fx), roundi(r.position.y * fy))
	var e := Vector2i(roundi(r.end.x * fx), roundi(r.end.y * fy))
	return Rect2i(a, e - a)


## In welchem Gebiet liegt das Feld? (Außenposten gehen vor; "" außerhalb der Karte)
static func gebiet(z: Vector2i) -> String:
	for name: String in Werte.ORDER24_GEBIETE:
		if rechteck(name).has_point(z):
			return name
	return ""


## Wo die Lager hin sollen: je Eintrag [Gebiet, Wunschfeld]. Im Gürtel oben und unten (je ein Viertel), in den
## Außenposten die Mitte.
static func lager_plaetze() -> Array:
	var aus: Array = []
	for name: String in Werte.ORDER24_LAGER:
		var r := rechteck(name)
		var n := int((Werte.ORDER24_LAGER[name] as Array)[0])
		for i in n:
			var y := r.position.y + (r.size.y * (2 * i + 1)) / (2 * n)
			aus.append([name, Vector2i(r.position.x + r.size.x / 2, y)])
	return aus


## Stellungen und Streife eines Lagers in diesem Gebiet (-1 = wie in den Regeln).
static func stellungen(name: String) -> int:
	return int((Werte.ORDER24_LAGER[name] as Array)[1]) if Werte.ORDER24_LAGER.has(name) else -1


static func streife(name: String) -> int:
	return int((Werte.ORDER24_LAGER[name] as Array)[2]) if Werte.ORDER24_LAGER.has(name) else -1


## E3: die _b24-Fassungen der Formationen (werkzeuge/b24_formationen.gd schreibt sie, Order24 wählt zufällig darunter)
const ORDNER_B24 := "res://karten/b24/"


## Der Plan einer Formation für die große Karte (Zeilen aus „.“ und „#“ / „O“ für Tore), Größe der aktuellen Karte:
##  - Gürtel: die Formation aus [H] an der Ostkante (ihre Lage zum HQ bleibt), mittig in der Höhe; was davon ins
##    Niemandsland fiele, entfällt.
##  - Niemandsland: 3–5 Trümmerwälle (einzeln oder zu zweit) aus einem Hash des Namens, nie im Platz der Höhle.
##  - Außenposten: je ein T-Stück und 2 Wälle (fest, vom Lager aus gesehen).
static func plan_b24(name: String) -> Array[String]:
	var s := Werte.SPALTEN
	var h := Werte.ZEILEN
	var feld: Array = []
	for y in h:
		var zeile: Array = []
		zeile.resize(s)
		zeile.fill(".")
		feld.append(zeile)
	# Gürtel
	var plan: Array = Nachschlag.PLAENE_GROSS[name]
	var dx := s - str(plan[0]).length()
	var dy := (h - plan.size()) / 2
	var guertel := rechteck("guertel")
	for y in plan.size():
		var zeile := str(plan[y])
		for x in zeile.length():
			var c := zeile[x]
			if c in ["#", "S", "T", "O"] and x + dx >= guertel.position.x:
				feld[y + dy][x + dx] = "O" if c == "O" else "#"
	# Außenposten: T-Stück (drei quer, einer zur Kartenmitte hin) und zwei einzelne Wälle, östlich ihres Felsabsatzes
	for name_a: String in ["aussen_oben", "aussen_unten"]:
		var r := rechteck(name_a)
		var innen := 1 if name_a == "aussen_oben" else -1
		var c := Vector2i(r.end.x - 3, r.position.y + r.size.y / 2)
		for p: Vector2i in [c + Vector2i(-1, 0), c, c + Vector2i(1, 0), c + Vector2i(0, innen), Vector2i(r.position.x + 2, c.y + 2 * innen), Vector2i(r.position.x + 3, c.y + 2 * innen)]:
			if p.x >= 0 and p.y >= 0 and p.x < s and p.y < h:
				feld[p.y][p.x] = "#"
	# E4: Zufluchten – Felder „z“, Ring „R“ rundum (G: Erdwälle, nicht über den Kartenrand), Eingang „e“ nach Westen
	for zname: String in Werte.ZUFLUCHTEN:
		var innen_r := zuflucht_rechteck(zname)
		var ring := innen_r.grow(1)
		var eingang := Vector2i(ring.position.x, innen_r.position.y + innen_r.size.y / 2 if zname == "hoehle" else (innen_r.end.y - 1 if zname == "absatz_oben" else innen_r.position.y))
		for y in range(ring.position.y, ring.end.y):
			for x in range(ring.position.x, ring.end.x):
				var q := Vector2i(x, y)
				if x < 0 or y < 0 or x >= s or y >= h:
					continue
				feld[y][x] = "z" if innen_r.has_point(q) else ("e" if q == eingang else "R")
	# Niemandsland: Trümmer aus einem Hash des Namens (immer gleich je Formation), nie an den Zufluchten
	var zufall := RandomNumberGenerator.new()
	zufall.seed = name.hash()
	var nl := rechteck("niemandsland")
	var hoehle := zuflucht_rechteck("hoehle").grow(1)
	var n := zufall.randi_range(3, 5)
	var versuche := 0
	while n > 0 and versuche < 200:
		versuche += 1
		var p := Vector2i(zufall.randi_range(nl.position.x, nl.end.x - 2), zufall.randi_range(1, h - 2))
		var stueck: Array[Vector2i] = [p]
		if zufall.randf() < 0.5:
			stueck.append(p + (Vector2i(1, 0) if zufall.randf() < 0.5 else Vector2i(0, 1)))
		var ok := true
		for q: Vector2i in stueck:
			if not nl.has_point(q) or hoehle.grow(1).has_point(q) or gebiet(q) != "niemandsland" or q.y < 1 or q.y > h - 2 or feld[q.y][q.x] != ".":
				ok = false
		if not ok:
			continue
		for q: Vector2i in stueck:
			feld[q.y][q.x] = "#"
		n -= 1
	var aus: Array[String] = []
	for zeile: Array in feld:
		aus.append("".join(PackedStringArray(zeile)))
	return aus


## E4: die Felder innen einer Zuflucht auf der aktuellen Karte (aus ZUFLUCHTEN auf 36×18 gestreckt; die Absätze bleiben
## am Kartenrand).
static func zuflucht_rechteck(name: String) -> Rect2i:
	var r: Rect2i = Werte.ZUFLUCHTEN[name]
	var x := roundi(r.position.x * float(Werte.SPALTEN) / 36.0)
	var y := roundi(r.position.y * float(Werte.ZEILEN) / 18.0)
	if name == "absatz_unten":
		y = Werte.ZEILEN - r.size.y
	return Rect2i(Vector2i(x, y), r.size)


## Der _b24-Plan einer Formation: aus der Datei, wenn sie zur Kartengröße passt, sonst frisch erzeugt.
static func plan_laden(name: String) -> Array:
	var pfad := ORDNER_B24 + name + "_b24.json"
	if FileAccess.file_exists(pfad):
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(pfad))
		if d is Dictionary and (d.get("plan", []) as Array).size() == Werte.ZEILEN and str((d["plan"] as Array)[0]).length() == Werte.SPALTEN:
			return d["plan"]
	return plan_b24(name)


## Die Formationen, die es als _b24 gibt (ohne Dateien: alle aus [H]).
static func formationen_b24() -> Array[String]:
	var aus: Array[String] = []
	for f: String in Werte.ALARM_FORMATIONEN:
		if FileAccess.file_exists(ORDNER_B24 + f + "_b24.json"):
			aus.append(f)
	return aus if not aus.is_empty() else Werte.ALARM_FORMATIONEN.duplicate()


## Ein _b24-Plan, mal oben, mal unten gespiegelt: {"waelle": im Format von main._setze_stand,
## "zufluchten": je {"name", "felder", "eingang", "rechteck"}}. Der Name der Zuflucht folgt ihrer Lage nach dem Spiegeln.
## G (26.11., Paul): Die Ringe („R“ im Plan) sind normale Erdwälle (vorher Fels) – sie stehen in `waelle`.
static func formation(name: String) -> Dictionary:
	var plan: Array = plan_laden(name).duplicate()
	if Zufall.ganz(2) == 1:
		plan.reverse()
	var waelle: Array = []
	var felder: Array[Vector2i] = []
	var eingaenge: Array[Vector2i] = []
	for y in plan.size():
		var zeile := str(plan[y])
		for x in zeile.length():
			match zeile[x]:
				"#", "O":
					waelle.append([x, y, "tor" if zeile[x] == "O" else ""])
				"R":
					waelle.append([x, y, ""])
				"z":
					felder.append(Vector2i(x, y))
				"e":
					eingaenge.append(Vector2i(x, y))
	# Zufluchten: zusammenhängende z-Felder
	var zufluchten: Array = []
	var offen := felder.duplicate()
	while not offen.is_empty():
		var gruppe: Array[Vector2i] = [offen.pop_back()]
		var i := 0
		while i < gruppe.size():
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var q := gruppe[i] + d
				if offen.has(q):
					offen.erase(q)
					gruppe.append(q)
			i += 1
		var r := Rect2i(gruppe[0], Vector2i.ONE)
		for q: Vector2i in gruppe:
			r = r.expand(q).merge(Rect2i(q, Vector2i.ONE))
		var eingang := Karte.KEINE
		for e: Vector2i in eingaenge:
			if r.grow(1).has_point(e):
				eingang = e
		var zname := "hoehle" if gebiet(gruppe[0]) == "niemandsland" else ("absatz_oben" if r.position.y < Werte.ZEILEN / 2 else "absatz_unten")
		zufluchten.append({"name": zname, "felder": gruppe, "eingang": eingang, "rechteck": r})
	return {"waelle": waelle, "zufluchten": zufluchten}
