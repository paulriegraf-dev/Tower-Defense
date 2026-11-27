class_name Energieschild
extends Node
## Energieschild der Batterie (16.11.; 27.11. Knoten-Umbau Paket B – vorher in main.gd): gerade von Erdwall zu Erdwall
## gezogen, je länger, desto schwächer; fängt Gegnerschüsse ab, lädt sich jede Bauphase wieder auf. Regeln unverändert.
## Kindknoten von main.gd (`spiel.energieschild`). Die Schilde selbst (`schilde`, `_schild_fuer`, `_schild_start`) bleiben
## in main (Zwischenstand, Bauprotokoll, Eingabe); main leitet waehle_schildfeld, setze_schild, schild_bei und
## schade_schild hierher weiter (rufen Fabrikmenü, Bot-API, Replay und Gegner auf).

const BAU := 0     # wie main.gd Phase.BAU
const KAMPF := 1   # wie main.gd Phase.KAMPF

var spiel: Node
var karte: Karte
var effekte: Effekte


func richte_ein(s: Node) -> void:
	spiel = s
	karte = s.karte
	effekte = s.effekte


## Energieschild (16.11. neu): ein Strahl, gerade von einem Erdwall zum nächsten gezogen. Je länger, desto weniger hält er aus.
## Danach ziehen (oder zwei Erdwälle nacheinander anklicken) setzt den Schild der Batterie, zu der die Pilotenfabrik `pz` gehört.
func waehle_schildfeld(pz: Vector2i) -> void:
	if spiel.phase != BAU or not karte.paar.has(pz) or int(spiel.fabriken[pz].get("stufe", 0)) < 3:
		return
	spiel._schild_fuer = karte.paar[pz]
	spiel._schild_start = Karte.KEINE
	spiel.werkzeug = Karte.FREI
	spiel._schliesse_fabrikmenue()
	spiel.melde("Energieschild: Von einem Erdwall gerade zum nächsten ziehen. Je länger, desto schwächer. [Esc] bricht ab.", 6.0)


## Felder zwischen zwei Erdwällen in einer Reihe oder Spalte (ohne die Wälle selbst).
func schild_felder(a: Vector2i, e: Vector2i) -> Array:
	var felder: Array = []
	if a == e or (a.x != e.x and a.y != e.y):
		return felder
	var schritt := Vector2i(signi(e.x - a.x), signi(e.y - a.y))
	var z := a + schritt
	while z != e:
		felder.append(z)
		z += schritt
	return felder


## Prüft einen Schild von `a` nach `e`. Gibt "" zurück, wenn er so stehen darf, sonst den Grund.
func schild_grund(a: Vector2i, e: Vector2i) -> String:
	if not ist_erdwall(a) or not ist_erdwall(e):
		return "Der Schild spannt sich von Erdwall zu Erdwall."
	if a.x != e.x and a.y != e.y:
		return "Nur gerade: in einer Reihe oder Spalte."
	var felder := schild_felder(a, e)
	if felder.is_empty():
		return "Zwischen den Erdwällen muss mindestens ein Feld frei sein."
	for z: Vector2i in felder:
		if karte.inhalt(z) == Karte.WALL:
			return "Nur bis zum nächsten Erdwall."
		if karte.inhalt(z) != Karte.FREI or not karte.ist_frei(z):
			return "Dazwischen muss alles frei sein."
		if z.x < Werte.ZONE_SPALTEN:
			return "Nicht in der gegnerischen Zone."
	return ""


func ist_erdwall(z: Vector2i) -> bool:
	return karte.inhalt(z) == Karte.WALL


## Setzt den Schild der Batterie `b` von Erdwall `a` nach Erdwall `e`. Gibt "" zurück, wenn es geklappt hat, sonst den Grund.
func setze(b: Vector2i, a: Vector2i, e: Vector2i) -> String:
	if spiel.batterie_stufe(b) < 3:
		return "Diese Batterie hat keinen Energieschild."
	var grund := schild_grund(a, e)
	if grund != "":
		return grund
	var felder := schild_felder(a, e)
	for anderer: Vector2i in spiel.schilde:
		if anderer != b:
			for z: Vector2i in felder:
				if (spiel.schilde[anderer]["felder"] as Array).has(z):
					return "Dort steht schon ein Schild."
	lege_schild(b, a, e)
	spiel._notiere({"a": "schild", "x": a.x, "y": a.y, "x2": e.x, "y2": e.y, "bx": b.x, "by": b.y})
	return ""


func lege_schild(b: Vector2i, a: Vector2i, e: Vector2i) -> void:
	var felder := schild_felder(a, e)
	var voll := Werte.schild_leben(felder.size())
	spiel.schilde[b] = {"a": a, "e": e, "felder": felder, "leben": voll, "max": voll}


func _aktiv(b: Vector2i) -> bool:
	if not spiel.schilde.has(b) or karte.inhalt(b) != Karte.BATTERIE:
		return false
	var s: Dictionary = spiel.schilde[b]
	return s["leben"] > 0.0 and not karte.ausgefallen.has(b) and _steht(s) \
		and spiel.batterie_stufe(b) >= 3 and karte.besatzung_drin(b) >= int(Werte.BATTERIE["plaetze"])


## Stehen beide Erdwälle noch und ist dazwischen alles frei?
func _steht(s: Dictionary) -> bool:
	if not ist_erdwall(s["a"]) or not ist_erdwall(s["e"]):
		return false
	for z: Vector2i in s["felder"]:
		if karte.inhalt(z) != Karte.FREI:
			return false
	return true


## Steht ein Gegner an dieser Stelle vor einem aktiven Schild? Gibt die Batterie zurück (oder Karte.KEINE).
func bei(punkt: Vector2) -> Vector2i:
	for b: Vector2i in spiel.schilde:
		if _aktiv(b):
			for z: Vector2i in spiel.schilde[b]["felder"]:
				if karte.mitte(z).distance_to(punkt) <= Werte.ZELLE * 0.62:
					return b
	return Karte.KEINE


func schade(b: Vector2i, menge: float) -> void:
	if not spiel.schilde.has(b):
		return
	spiel.objekt_zaehle(b, "abgefangen", minf(menge, maxf(float(spiel.schilde[b]["leben"]), 0.0)))
	spiel.schilde[b]["leben"] = float(spiel.schilde[b]["leben"]) - menge
	if spiel.schilde[b]["leben"] <= 0.0:
		spiel.melde("Ein Energieschild ist zusammengebrochen – er lädt sich bis zur nächsten Runde wieder auf.", 4.0)


func pflege() -> void:
	var liste: Array = []
	for b: Vector2i in spiel.schilde.keys():
		if karte.inhalt(b) != Karte.BATTERIE:
			spiel.schilde.erase(b)
			continue
		if spiel.phase == BAU:
			spiel.schilde[b]["leben"] = spiel.schilde[b]["max"]
		var s: Dictionary = spiel.schilde[b]
		# In der Bauphase als Vorschau zeigen, in der Welle nur, solange er wirklich steht
		var aktiv := _aktiv(b) if spiel.phase == KAMPF else _steht(s)
		liste.append([karte.mitte(s["a"]), karte.mitte(s["e"]), clampf(float(s["leben"]) / float(s["max"]), 0.0, 1.0), aktiv, float(s["max"])])
	effekte.schilde = liste
	# Vorschau beim Ziehen: vom ersten Erdwall bis zum Feld unter der Maus
	effekte.schild_vorschau = []
	if spiel._schild_fuer != Karte.KEINE:
		var unter := karte.zelle_bei(spiel.maus_welt())
		if spiel._schild_start != Karte.KEINE:
			var ok := schild_grund(spiel._schild_start, unter) == ""
			var n := schild_felder(spiel._schild_start, unter).size()
			effekte.schild_vorschau = [karte.mitte(spiel._schild_start), karte.mitte(unter), ok, Werte.schild_leben(n) if ok else 0.0]
		elif ist_erdwall(unter):
			effekte.schild_vorschau = [karte.mitte(unter), karte.mitte(unter), true, 0.0]


## Energieschild ziehen: erster Klick (oder Drücken) wählt den Start-Erdwall, Loslassen oder zweiter Klick das Ende.
func klick(z: Vector2i) -> void:
	if spiel._schild_start == Karte.KEINE or z == spiel._schild_start:
		if ist_erdwall(z):
			spiel._schild_start = z
		else:
			spiel.melde("Der Schild beginnt an einem Erdwall.")
		return
	var grund := setze(spiel._schild_fuer, spiel._schild_start, z)
	if grund == "":
		var leben: float = spiel.schilde[spiel._schild_fuer]["max"]
		spiel._schild_fuer = Karte.KEINE
		spiel._schild_start = Karte.KEINE
		spiel.melde("Energieschild gespannt: hält %d Schaden aus." % roundi(leben), 4.0)
	else:
		spiel.melde(grund)
		spiel._schild_start = z if ist_erdwall(z) else Karte.KEINE
