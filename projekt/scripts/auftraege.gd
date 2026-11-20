class_name Auftraege
extends RefCounted
## 20.11. (Paul): Aufträge für Anführer Paul – neu als Pool. Ab Runde AB_RUNDE bekommt er zu jeder Bauphase 1 bis 4
## Aufträge zugleich, halb zufällig gezogen aus vier Stufen: Leicht, Normal, Schwer, Wahnsinn. Alle laufen nebeneinander,
## jeder zahlt für sich. Je höher die Stufe, desto höher die Belohnung – und ab „Schwer“ gibt es auch Sachpreise
## (Gratis-Fabrik, Gratis-Erdwälle, ein Leben).
##
## Maßstab ist das Einkommen der Runde: Die Belohnung ist ein Anteil des Rundenbonus (Werte.wellen_bonus), ebenso die
## Geldziele („gib X aus“). So wachsen Aufträge und Lohn mit den Runden mit:
##   Runde 2: Bonus 110 -> Leicht 30, Normal 55            Runde 10: Bonus 150 -> 40 / 75 / 150 / 300
##   Runde 6: Bonus 130 -> 35 / 65 / 130                   Runde 20: Bonus 200 -> 50 / 100 / 200 / 400
##
## Zwei Arten:  angebot – erfüllt = Belohnung, sonst nichts
##              pflicht – erfüllt = Belohnung, verfehlt = Strafe (Leben oder ein Teil des Budgets); höchstens eine je Runde
## Geprüft wird je Bedingung beim Start der Welle oder am Rundenende (ENDE_ZAEHLER). Gezählt wird in main.gd über zaehle():
## "bau:<typ>", "abriss:<typ>" (typ wie main.BAU_NAMEN, ein Turm zählt als "turm"), "upgrade", "ausgaben".
##
## Felder eines Auftrags: id, name, stufe (0–3), text (mit {0}, {1} für die Ziele), bed = [[zaehler, ziel, "min"|"max"]],
## optional art ("pflicht"), lohn (Faktor auf die Stufen-Belohnung), sach ({"fabrik": n, "waelle": n, "stellungen": n,
## "leben": n}), strafe_leben, strafe_anteil, ab (Runde), braucht (siehe _moeglich), gruppe (nie zwei aus einer Gruppe).
## Ein Ziel ist eine Zahl, {"bonus": f} (f × Rundenbonus, auf 25 gerundet) oder {"basis": n, "je": r} (n + 1 je r Runden).

const AB_RUNDE := 2
const LEBEN_MIN := 1   # eine Strafe nimmt nie das letzte Leben
const ENDE_ZAEHLER := ["leben_verloren", "cp_feind"]

## Stufen: Anteil des Rundenbonus als Belohnung, ab welcher Runde, Gewicht beim Ziehen (wächst ab `mehr_ab` auf `mehr`).
const STUFEN: Array[Dictionary] = [
	{"name": "Leicht", "faktor": 0.25, "ab": 2, "gewicht": 4, "farbe": "9be37b"},
	{"name": "Normal", "faktor": 0.5, "ab": 3, "gewicht": 3, "farbe": "7fe0ff"},
	{"name": "Schwer", "faktor": 1.0, "ab": 6, "gewicht": 2, "mehr_ab": 12, "mehr": 3, "farbe": "ffd34d"},
	{"name": "Wahnsinn", "faktor": 2.0, "ab": 10, "gewicht": 1, "mehr_ab": 15, "mehr": 2, "farbe": "ff8a7a"},
]
## Wie viele Aufträge je Runde: [ab Runde, Gewichte für 1, 2, 3, 4 Aufträge]
const ANZAHL := [[2, [3, 2, 0, 0]], [4, [2, 3, 2, 0]], [6, [1, 3, 3, 1]], [10, [1, 2, 3, 2]]]

const LISTE: Array[Dictionary] = [
	# ---------------- Leicht: nebenbei zu schaffen
	{"id": "mauerbau", "name": "Mauerbau", "stufe": 0, "text": "Bau {0} Erdwälle.", "bed": [["bau:wall", {"basis": 4, "je": 5}, "min"]]},
	{"id": "postenbau", "name": "Wachdienst", "stufe": 0, "text": "Bau 2 Stellungen.", "bed": [["bau:stellung", 2, "min"]]},
	{"id": "kleiner_einkauf", "name": "Kleiner Einkauf", "stufe": 0, "text": "Gib mindestens {0} aus.", "bed": [["ausgaben", {"bonus": 0.75}, "min"]], "gruppe": "geld"},
	{"id": "modernisierung", "name": "Modernisierung", "stufe": 0, "text": "Werte eine Fabrik oder einen Turm auf.", "bed": [["upgrade", 1, "min"]], "ab": 3},
	{"id": "notgroschen", "name": "Notgroschen", "stufe": 0, "text": "Starte die Welle mit mindestens {0} Budget.", "bed": [["budget", {"bonus": 1.0}, "min"]], "gruppe": "geld"},
	# ---------------- Normal: kostet eine Entscheidung
	{"id": "gruenderzeit", "name": "Gründerzeit", "stufe": 1, "text": "Bau eine neue Fabrik.", "bed": [["bau:fabrik", 1, "min"]]},
	{"id": "turmfieber", "name": "Turmfieber", "stufe": 1, "text": "Bau einen neuen Turm.", "bed": [["bau:turm", 1, "min"]]},
	{"id": "panzerpflicht", "name": "Gut gepanzert", "stufe": 1, "text": "Panzere {0} Erdwälle.", "bed": [["bau:panzer", {"basis": 2, "je": 6}, "min"]]},
	{"id": "grosseinkauf", "name": "Großeinkauf", "stufe": 1, "text": "Gib mindestens {0} aus.", "bed": [["ausgaben", {"bonus": 2.0}, "min"]], "gruppe": "geld"},
	{"id": "saubere_arbeit", "name": "Saubere Arbeit", "stufe": 1, "text": "Verlier in dieser Runde kein Leben.", "bed": [["leben_verloren", 0, "max"]], "gruppe": "leben"},
	{"id": "abrissbirne", "name": "Abrissbirne", "stufe": 1, "art": "pflicht", "text": "Reiß {0} Erdwälle ab – sonst 1 Leben weg.", "bed": [["abriss:wall", {"basis": 4, "je": 8}, "min"]], "strafe_leben": 1, "braucht": "waelle", "gruppe": "abriss"},
	{"id": "sparverbot", "name": "Sparverbot", "stufe": 1, "art": "pflicht", "text": "Starte die Welle mit höchstens {0} Budget – sonst ein Viertel weg.", "bed": [["budget", {"bonus": 0.75}, "max"]], "strafe_anteil": 0.25, "braucht": "geld", "gruppe": "geld"},
	# ---------------- Schwer: verlangt Umbau oder eine starke Runde; Lohn = ein ganzer Rundenbonus oder ein Sachpreis
	{"id": "umzug", "name": "Umzug", "stufe": 2, "text": "Reiß eine Fabrik ab und bau eine neue.", "bed": [["abriss:fabrik", 1, "min"], ["bau:fabrik", 1, "min"]], "braucht": "fabrik", "gruppe": "abriss"},
	{"id": "aufruestung", "name": "Aufrüstung", "stufe": 2, "text": "Kauf {0} Ausbaustufen in einer Bauphase.", "bed": [["upgrade", 3, "min"]]},
	{"id": "grundbesitz", "name": "Grundbesitz", "stufe": 2, "text": "Am Rundenende gehören dir beide Checkpoints und du hast kein Leben verloren.", "bed": [["cp_feind", 0, "max"], ["leben_verloren", 0, "max"]], "lohn": 0.5, "sach": {"fabrik": 1}, "gruppe": "leben"},
	{"id": "turmbau", "name": "Turmbau zu Paul", "stufe": 2, "text": "Bau 2 neue Türme.", "bed": [["bau:turm", 2, "min"]], "lohn": 0.75, "sach": {"waelle": 6}},
	{"id": "nullrunde", "name": "Nullrunde", "stufe": 2, "text": "Gib in dieser Bauphase nichts aus und verlier kein Leben.", "bed": [["ausgaben", 0, "max"], ["leben_verloren", 0, "max"]], "gruppe": "geld"},
	{"id": "steuerpruefung", "name": "Steuerprüfung", "stufe": 2, "art": "pflicht", "text": "Gib mindestens die Hälfte deines Budgets aus – sonst ein Drittel weg.", "bed": [["ausgaben_anteil", 0.5, "min"]], "strafe_anteil": 0.33, "braucht": "geld", "gruppe": "geld"},
	{"id": "turmtausch", "name": "Turmtausch", "stufe": 2, "art": "pflicht", "text": "Reiß einen Turm ab und bau einen neuen – sonst 1 Leben weg.", "bed": [["turmtausch", 1, "min"]], "strafe_leben": 1, "braucht": "turm", "gruppe": "abriss"},
	{"id": "fabrikschliessung", "name": "Werksschließung", "stufe": 2, "art": "pflicht", "text": "Reiß eine Fabrik ab – sonst 2 Leben weg.", "bed": [["abriss:fabrik", 1, "min"]], "strafe_leben": 2, "braucht": "zwei_fabriken", "lohn": 0.5, "sach": {"fabrik": 1}, "gruppe": "abriss"},
	# ---------------- Wahnsinn: kaum möglich oder sehr aufwendig; Lohn = zwei Rundenboni plus Sachpreis
	{"id": "kaufrausch", "name": "Kaufrausch", "stufe": 3, "text": "Gib in einer Bauphase mindestens {0} aus.", "bed": [["ausgaben", {"bonus": 5.0}, "min"]], "lohn": 0.5, "sach": {"leben": 1}, "gruppe": "geld"},
	{"id": "eiserne_reserve", "name": "Eiserne Reserve", "stufe": 3, "text": "Starte die Welle mit mindestens {0} Budget und verlier kein Leben.", "bed": [["budget", {"bonus": 6.0}, "min"], ["leben_verloren", 0, "max"]], "gruppe": "geld"},
	{"id": "grossbaustelle", "name": "Großbaustelle", "stufe": 3, "text": "Bau {0} Erdwälle, {1} Stellungen und 2 Türme in einer Bauphase.", "bed": [["bau:wall", {"basis": 14, "je": 2}, "min"], ["bau:stellung", 4, "min"], ["bau:turm", 2, "min"]], "sach": {"fabrik": 1}},
	{"id": "kahlschlag", "name": "Kahlschlag", "stufe": 3, "text": "Reiß 2 Fabriken und {0} Erdwälle ab und verlier trotzdem kein Leben.", "bed": [["abriss:fabrik", 2, "min"], ["abriss:wall", 10, "min"], ["leben_verloren", 0, "max"]], "sach": {"fabrik": 2, "waelle": 10}, "braucht": "drei_fabriken", "gruppe": "abriss"},
	{"id": "mit_leeren_haenden", "name": "Mit leeren Händen", "stufe": 3, "text": "Starte die Welle mit höchstens 25 Budget, halte beide Checkpoints und verlier kein Leben.", "bed": [["budget", 25, "max"], ["cp_feind", 0, "max"], ["leben_verloren", 0, "max"]], "sach": {"leben": 1}, "braucht": "geld", "gruppe": "geld"},
]


static func eintrag(id: String) -> Dictionary:
	for a: Dictionary in LISTE:
		if str(a["id"]) == id:
			return a
	return {}


static func _runde5(v: float) -> int:
	return maxi(5, roundi(v / 5.0) * 5)


## Belohnung in Budget für einen Auftrag in Runde `welle`.
static func lohn(a: Dictionary, welle: int) -> int:
	return _runde5(float(STUFEN[int(a["stufe"])]["faktor"]) * float(a.get("lohn", 1.0)) * Werte.wellen_bonus(welle))


## Ein Ziel in eine Zahl für Runde `welle` auflösen.
static func _ziel(z: Variant, welle: int) -> float:
	if z is Dictionary:
		if (z as Dictionary).has("bonus"):
			return maxf(25.0, roundf(float(z["bonus"]) * Werte.wellen_bonus(welle) / 25.0) * 25.0)
		return float(z["basis"]) + floorf(float(welle) / float(z["je"]))
	return float(z)


static func _gewichtet(gewichte: Array) -> int:
	var summe := 0.0
	for g: Variant in gewichte:
		summe += float(g)
	var r := randf() * summe
	for i in gewichte.size():
		r -= float(gewichte[i])
		if r < 0.0:
			return i
	return gewichte.size() - 1


## Neue Bauphase: 1–4 Aufträge ziehen (nur Paul, nicht in Sandbox/Phantom). {} = keine.
static func neuer(spiel: Node) -> Dictionary:
	if not Werte.auftraege_an() or spiel.sandbox or spiel.phantom_modus != "" or int(spiel.welle) < AB_RUNDE:
		return {}
	var welle := int(spiel.welle)
	var vorher: PackedStringArray = str(spiel.get("auftrag_letzter")).split(",", false)
	var anzahl_gewichte: Array = ANZAHL[0][1]
	for e: Array in ANZAHL:
		if welle >= int(e[0]):
			anzahl_gewichte = e[1]
	var anzahl := _gewichtet(anzahl_gewichte) + 1
	var liste: Array = []
	var gruppen: Array = []
	var hat_pflicht := false
	var hat_wahnsinn := false
	for i in anzahl:
		# Stufe ziehen: der erste Auftrag ist immer leicht oder normal, damit jede Runde etwas Machbares dabei ist
		var gewichte: Array = []
		for s in STUFEN.size():
			var st: Dictionary = STUFEN[s]
			var g := 0.0
			if welle >= int(st["ab"]) and not (i == 0 and s >= 2) and not (s == 3 and hat_wahnsinn):
				g = float(st["mehr"]) if st.has("mehr_ab") and welle >= int(st["mehr_ab"]) else float(st["gewicht"])
			gewichte.append(g)
		var stufe := _gewichtet(gewichte)
		var moeglich: Array[Dictionary] = []
		for a: Dictionary in LISTE:
			if int(a["stufe"]) != stufe or vorher.has(str(a["id"])) or welle < int(a.get("ab", 0)):
				continue
			if a.has("gruppe") and gruppen.has(str(a["gruppe"])):
				continue
			if str(a.get("art", "angebot")) == "pflicht" and (hat_pflicht or i == 0):
				continue
			if liste.any(func(l: Dictionary) -> bool: return str(l["id"]) == str(a["id"])):
				continue
			if not _moeglich(spiel, str(a.get("braucht", ""))):
				continue
			moeglich.append(a)
		if moeglich.is_empty():
			continue
		var a: Dictionary = moeglich.pick_random()
		var ziele: Array = []
		for b: Array in a["bed"]:
			ziele.append(_ziel(b[1], welle))
		liste.append({"id": a["id"], "ziele": ziele, "budget": lohn(a, welle), "welle_ok": false, "fertig": ""})
		if a.has("gruppe"):
			gruppen.append(str(a["gruppe"]))
		hat_pflicht = hat_pflicht or str(a.get("art", "")) == "pflicht"
		hat_wahnsinn = hat_wahnsinn or stufe == 3
	if liste.is_empty():
		return {}
	liste.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return int(eintrag(str(x["id"]))["stufe"]) < int(eintrag(str(y["id"]))["stufe"]))
	return {"liste": liste, "budget_start": int(spiel.budget), "leben_start": int(spiel.leben), "zaehler": {}, "runde": welle}


static func _moeglich(spiel: Node, braucht: String) -> bool:
	match braucht:
		"fabrik":
			return int(spiel._normale_fabriken()) >= 1
		"zwei_fabriken":
			return int(spiel._normale_fabriken()) >= 2
		"drei_fabriken":
			return int(spiel._normale_fabriken()) >= 3
		"turm":
			return not (spiel.karte.turm_art as Dictionary).is_empty()
		"waelle":
			var n := 0
			for z: Vector2i in spiel.karte.feld:
				if spiel.karte.feld[z] == Karte.WALL and not spiel.karte.fest.has(z) and not spiel.karte.ausbau.has(z):
					n += 1
			return n >= 8
		"geld":
			return int(spiel.budget) >= 200
	return true


## Die laufenden Aufträge (leer, wenn keine oder ein alter Spielstand im früheren Format).
static func _liste(auftrag: Dictionary) -> Array:
	var l: Variant = auftrag.get("liste", [])
	return l if l is Array else []


## Zählt eine Handlung für die laufenden Aufträge.
static func zaehle(auftrag: Dictionary, schluessel: String, n: int = 1) -> void:
	if auftrag.is_empty() or not auftrag.has("zaehler"):
		return
	var z: Dictionary = auftrag["zaehler"]
	z[schluessel] = int(z.get(schluessel, 0)) + n


## Stand eines Zählers.
static func _wert(spiel: Node, auftrag: Dictionary, zaehler: String) -> float:
	var z: Dictionary = auftrag.get("zaehler", {})
	match zaehler:
		"budget":
			return float(spiel.budget)
		"ausgaben_anteil":
			return float(z.get("ausgaben", 0)) / maxf(1.0, float(auftrag.get("budget_start", 1)))
		"leben_verloren":
			return float(int(auftrag.get("leben_start", 0)) - int(spiel.leben))
		"cp_feind":
			var n := 0
			for f: bool in spiel.karte.cp_feind:
				if f:
					n += 1
			return float(n)
		"turmtausch":
			return float(mini(int(z.get("abriss:turm", 0)), int(z.get("bau:turm", 0))))
	return float(z.get(zaehler, 0))


static func _erfuellt(spiel: Node, auftrag: Dictionary, lauf: Dictionary, a: Dictionary, am_ende: bool) -> bool:
	var bed: Array = a["bed"]
	for i in bed.size():
		var b: Array = bed[i]
		if ENDE_ZAEHLER.has(str(b[0])) != am_ende:
			continue
		var wert := _wert(spiel, auftrag, str(b[0]))
		var ziel := float((lauf["ziele"] as Array)[i])
		if (wert > ziel + 0.0001) if str(b[2]) == "max" else (wert < ziel - 0.0001):
			return false
	return true


static func _hat_ende(a: Dictionary) -> bool:
	for b: Array in a["bed"]:
		if ENDE_ZAEHLER.has(str(b[0])):
			return true
	return false


static func sach_text(a: Dictionary) -> String:
	var s: Dictionary = a.get("sach", {})
	var teile: Array = []
	if s.has("fabrik"):
		teile.append("Gratis-Fabrik" if int(s["fabrik"]) == 1 else "%d Gratis-Fabriken" % int(s["fabrik"]))
	if s.has("waelle"):
		teile.append("%d Erdwälle" % int(s["waelle"]))
	if s.has("stellungen"):
		teile.append("%d Stellungen" % int(s["stellungen"]))
	if s.has("leben"):
		teile.append("+%d Leben" % int(s["leben"]))
	return " + ".join(PackedStringArray(teile))


static func _zahle(spiel: Node, lauf: Dictionary, a: Dictionary) -> String:
	var b := int(lauf["budget"])
	spiel.budget += b
	var s: Dictionary = a.get("sach", {})
	if s.has("fabrik"):
		spiel.gratis_fabriken += int(s["fabrik"])
	if s.has("waelle"):
		spiel.freie_waelle += int(s["waelle"])
	if s.has("stellungen"):
		spiel.freie_stellungen += int(s["stellungen"])
	if s.has("leben"):
		spiel.leben = mini(Werte.START_LEBEN, int(spiel.leben) + int(s["leben"]))
	var sach := sach_text(a)
	return "%s +%d%s" % [a["name"], b, (" + " + sach) if sach != "" else ""]


static func _strafe(spiel: Node, a: Dictionary) -> String:
	var text := ""
	if a.has("strafe_leben"):
		var weg := mini(int(a["strafe_leben"]), maxi(0, int(spiel.leben) - LEBEN_MIN))
		spiel.leben -= weg
		text = "%d Leben weg" % weg
	if a.has("strafe_anteil"):
		var weg2 := roundi(int(spiel.budget) * float(a["strafe_anteil"]))
		spiel.budget -= weg2
		text = "%d Budget weg" % weg2
	return "%s verfehlt (%s)" % [a["name"], text]


## Prüft alle Aufträge zum Zeitpunkt `wann` ("welle" oder "ende"). Zahlt aus oder straft und meldet es in einer Zeile.
## Gibt true zurück, wenn damit alle erledigt sind (main.gd löscht sie dann).
static func pruefe(spiel: Node, auftrag: Dictionary, wann: String) -> bool:
	var liste := _liste(auftrag)
	if liste.is_empty():
		return true
	var am_ende := wann == "ende"
	var gut: Array = []
	var schlecht: Array = []
	var offen := 0
	for lauf: Dictionary in liste:
		if str(lauf.get("fertig", "")) != "":
			continue
		var a := eintrag(str(lauf["id"]))
		if a.is_empty():
			lauf["fertig"] = "nein"
			continue
		var ok := _erfuellt(spiel, auftrag, lauf, a, am_ende)
		if not am_ende:
			if ok and _hat_ende(a):
				lauf["welle_ok"] = true   # der Rest entscheidet sich am Rundenende
				offen += 1
				continue
		elif not bool(lauf.get("welle_ok", false)) and a["bed"].any(func(b: Array) -> bool: return not ENDE_ZAEHLER.has(str(b[0]))):
			ok = false   # der Teil zum Wellenstart war schon verfehlt (kommt nur bei alten Ständen vor)
		if ok:
			lauf["fertig"] = "ja"
			gut.append(_zahle(spiel, lauf, a))
		else:
			lauf["fertig"] = "nein"
			schlecht.append(_strafe(spiel, a) if str(a.get("art", "")) == "pflicht" else "%s nicht erfüllt" % a["name"])
	if not gut.is_empty() or not schlecht.is_empty():
		spiel.melde("Aufträge: " + " · ".join(PackedStringArray(gut + schlecht)) + ".", 7.0, "geld" if not gut.is_empty() else "")
	return offen == 0 and liste.all(func(l: Dictionary) -> bool: return str(l.get("fertig", "")) != "")


## Kennungen der Aufträge dieser Runde (für „nicht gleich noch einmal“).
static func kennungen(auftrag: Dictionary) -> String:
	var ids: Array = []
	for lauf: Dictionary in _liste(auftrag):
		ids.append(str(lauf["id"]))
	return ",".join(PackedStringArray(ids))


static func text(lauf: Dictionary) -> String:
	var a := eintrag(str(lauf["id"]))
	var t := str(a.get("text", ""))
	var ziele: Array = lauf.get("ziele", [])
	for i in ziele.size():
		t = t.replace("{%d}" % i, str(roundi(float(ziele[i]))))
	return t


## Für die Anzeige im HUD: je Auftrag Stufe, Name, Text, Fortschritt, Lohn, Zustand ("", "ja", "nein", "halb").
static func zeilen(spiel: Node, auftrag: Dictionary) -> Array:
	var aus: Array = []
	for lauf: Dictionary in _liste(auftrag):
		var a := eintrag(str(lauf["id"]))
		if a.is_empty():
			continue
		var stand := ""
		var b0: Array = a["bed"][0]
		if str(b0[2]) == "min" and not ENDE_ZAEHLER.has(str(b0[0])) and str(b0[0]) != "ausgaben_anteil":
			stand = "%d/%d" % [mini(roundi(_wert(spiel, auftrag, str(b0[0]))), roundi(float(lauf["ziele"][0]))), roundi(float(lauf["ziele"][0]))]
		elif str(b0[0]) == "ausgaben_anteil":
			stand = "%d %%" % roundi(_wert(spiel, auftrag, "ausgaben_anteil") * 100.0)
		var sach := sach_text(a)
		var zustand := str(lauf.get("fertig", ""))
		if zustand == "" and bool(lauf.get("welle_ok", false)):
			zustand = "halb"
		elif zustand == "" and spiel.phase == 0 and _erfuellt(spiel, auftrag, lauf, a, false) and not _nur_ende(a):
			zustand = "bereit"
		aus.append({"stufe": int(a["stufe"]), "name": str(a["name"]), "text": text(lauf), "stand": stand, "pflicht": str(a.get("art", "")) == "pflicht",
			"lohn": "+%d" % int(lauf["budget"]) + ((" + " + sach) if sach != "" else ""), "zustand": zustand})
	return aus


static func _nur_ende(a: Dictionary) -> bool:
	return a["bed"].all(func(b: Array) -> bool: return ENDE_ZAEHLER.has(str(b[0])))


## Kurz für die Rundenanzeige.
static func titel(auftrag: Dictionary) -> String:
	var n := _liste(auftrag).size()
	return "" if n == 0 else ("1 Auftrag" if n == 1 else "%d Aufträge" % n)


## Für die Übersicht [I]: je Stufe eine Zeile mit Lohn-Regel und den Aufträgen.
static func uebersicht() -> Array[String]:
	var aus: Array[String] = ["Je Bauphase 1 bis 4 Aufträge zugleich, jeder zahlt für sich. Der Lohn ist ein Anteil des Rundenbonus und wächst mit den Runden."]
	for s in STUFEN.size():
		var st: Dictionary = STUFEN[s]
		var namen: Array = []
		for a: Dictionary in LISTE:
			if int(a["stufe"]) == s:
				var sach := sach_text(a)
				namen.append(str(a["name"]) + (" (Pflicht)" if str(a.get("art", "")) == "pflicht" else "") + ((" [" + sach + "]") if sach != "" else ""))
		aus.append("%s (ab Runde %d, Lohn %d %% des Rundenbonus): %s" % [st["name"], int(st["ab"]), roundi(float(st["faktor"]) * 100.0), ", ".join(PackedStringArray(namen))])
	return aus
