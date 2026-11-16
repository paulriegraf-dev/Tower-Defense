class_name Phantom
extends RefCounted
## Phantom-Modus: Dateien, Preise und Budgets.
## Ein Verteidigungs-Phantom ist der aufgezeichnete Bau eines Spielers (je Runde), ein Angriffs-Phantom seine 20 Wellen.
## Die Dateien liegen im Projektordner unter „Phantom Dateien“, getrennt nach Angreifer und Verteidiger.
## Was dort liegt, wird mit dem Spiel ausgeliefert (der Pool für alle Spieler); eigene Läufe im fertigen Spiel
## landen im Benutzerordner unter demselben Namen.

const WURZELN: Array[String] = ["res://Phantom Dateien", "user://Phantom Dateien"]
const UNTERORDNER := {"verteidigung": "Verteidiger", "angriff": "Angreifer"}
## Version der Phantom-Dateien (16.11.): Ändern sich die Regeln so, dass alte Aufzeichnungen nicht mehr passen, wird sie
## hochgezählt – ältere Dateien werden dann weder gezählt noch gezogen, egal ob im Pool oder im Benutzerordner.
## Dateien ohne Eintrag gelten als Version 1.
const PHANTOM_VERSION: int = 2


## Die Ordner einer Art ("verteidigung" oder "angriff"): erst der Pool im Projekt, dann der Benutzerordner.
static func ordner(art: String) -> Array:
	var liste_: Array = []
	for w: String in WURZELN:
		liste_.append(w + "/" + str(UNTERORDNER[art]))
	return liste_
# Startwerte, falls „Phantom Dateien/preise.json“ fehlt. Anker: Hund = 10.
const PREISE := {"hund": 10, "sphaere": 35, "fahne": 60, "sprenger": 55, "rauch": 50, "belagerung": 150, "schild": 45, "sani": 50, "schwarm": 70}
const WURF_AUFSCHLAG: int = 40
const WURF_HOECHSTENS: int = 4          # so viele Einheiten fasst ein Wurf
const NICHT_WERFBAR: Array[String] = ["belagerung"]
const TYPEN: Array[String] = ["hund", "sphaere", "fahne", "sprenger", "rauch", "belagerung", "schild", "sani", "schwarm"]

static var _preise: Dictionary = {}
static var _wurf: int = -1


static func _lade_preise() -> void:
	if _wurf >= 0:
		return
	_preise = PREISE.duplicate()
	_wurf = WURF_AUFSCHLAG
	for wurzel: String in WURZELN:
		var pfad := wurzel + "/preise.json"
		if not FileAccess.file_exists(pfad):
			continue
		var daten: Variant = JSON.parse_string(FileAccess.get_file_as_string(pfad))
		if daten is Dictionary:
			for typ: String in (daten.get("preise", {}) as Dictionary):
				if _preise.has(typ):
					_preise[typ] = int(daten["preise"][typ])
			_wurf = int(daten.get("wurf_aufschlag", _wurf))
		return


static func preis(typ: String) -> int:
	_lade_preise()
	return int(_preise.get(typ, 0))


static func wurf_aufschlag() -> int:
	_lade_preise()
	return _wurf


## Preis eines Trupps im Format von Werte.WELLEN ({"weg", "typen", ...}).
static func trupp_preis(trupp: Dictionary) -> int:
	var summe := 0
	for typ: String in trupp["typen"]:
		summe += preis(typ)
	if trupp.get("weg", "l") == "w" and not (trupp["typen"] as Array).is_empty():
		summe += wurf_aufschlag()
	return summe


static func plan_preis(trupps: Array) -> int:
	var summe := 0
	for t: Dictionary in trupps:
		summe += trupp_preis(t)
	return summe


## Budget des Angreifers in Runde `nr`: so viel kostet die entworfene Welle dieser Runde.
## (Trupps, die in der letzten Runde nur in jedem n-ten Durchgang kommen, zählen nicht mit.)
static func budget(nr: int) -> int:
	var summe := 0
	for t: Dictionary in Werte.WELLEN[clampi(nr, 1, Werte.LETZTE_RUNDE)]["trupps"]:
		# Trupps, die in der letzten Runde nur in jedem n-ten Durchgang kommen, zählen anteilig (ein Drittel je Durchgang)
		summe += roundi(trupp_preis(t) / float(maxi(1, int(t.get("jeder", 1)))))
	return summe


# --- Wertung eines Angriffs (alles Startwerte) ---
const PUNKTE_JE_LEBEN: int = 100        # je genommenes Leben ...
const SPAR_FAKTOR: float = 1.0          # ... mal (1 + Anteil des nicht genutzten Budgets): wer mit halbem Budget trifft, bekommt das 1,5-Fache
const PUNKTE_GEKNACKT: int = 1000       # je Verteidigung, die fällt
const PUNKTE_FRUEH: int = 50            # dazu je Runde, die sie vor Runde 20 fällt
const PUNKTE_JE_SEKUNDE_20: int = 10    # letzte Runde: je Sekunde, die das eigene HQ hält


## Rechnet die Wertung aus dem Rundenprotokoll eines Angriffs: {"gesamt", "leben", "geknackt", "runde20", "zeilen"}.
static func wertung(runden: Array) -> Dictionary:
	var leben := 0
	var geknackt := 0
	var runde20 := 0
	var genommen := 0
	var gefallen := 0
	for r: Dictionary in runden:
		var n := int(r.get("leben_genommen", 0))
		genommen += n
		if n > 0:
			var frei := clampf(1.0 - float(r.get("punkte", 0)) / maxf(1.0, float(r.get("budget", 1))), 0.0, 1.0)
			leben += roundi(n * PUNKTE_JE_LEBEN * (1.0 + SPAR_FAKTOR * frei))
		if r.get("geknackt", false):
			gefallen += 1
			geknackt += PUNKTE_GEKNACKT + PUNKTE_FRUEH * maxi(0, Werte.LETZTE_RUNDE - int(r["runde"]))
		if int(r["runde"]) >= Werte.LETZTE_RUNDE:
			runde20 += roundi(float(r.get("sekunden", 0.0)) * PUNKTE_JE_SEKUNDE_20)
	var zeilen: PackedStringArray = []
	zeilen.append("%d Leben genommen: %d" % [genommen, leben])
	if gefallen > 0:
		zeilen.append("%d Verteidigung%s geknackt: %d" % [gefallen, "en" if gefallen > 1 else "", geknackt])
	if runde20 > 0:
		zeilen.append("Runde 20 gehalten: %d" % runde20)
	return {"gesamt": leben + geknackt + runde20, "leben": leben, "geknackt": geknackt, "runde20": runde20, "zeilen": zeilen}


## Alle Phantome einer Art ("verteidigung" oder "angriff"), neueste zuerst: [{"pfad", "titel"}].
static func liste(art: String, alle_groessen: bool = false) -> Array:
	var funde: Array = []
	var gesehen := {}
	for o: String in ordner(art):
		var dir := DirAccess.open(o)
		if dir == null:
			continue
		for datei: String in dir.get_files():
			if not datei.ends_with(".json") or gesehen.has(datei):
				continue
			var daten := lade(o + "/" + datei)
			if daten.is_empty() or str(daten.get("art", "")) != art:
				continue
			if int(daten.get("phantom_version", 1)) < PHANTOM_VERSION:
				continue   # veraltet
			# Verteidigungs-Phantome sind ein Bau auf einer bestimmten Kartengröße: nur passende ziehen
			var spalten := int((daten.get("karte", {}) as Dictionary).get("spalten", 20))
			if art == "verteidigung" and spalten != Werte.SPALTEN and not alle_groessen:
				continue
			gesehen[datei] = true
			var e: Dictionary = daten.get("ergebnis", {})
			var titel := "%s · %s" % [str(daten.get("spieler", "?")), str(daten.get("begonnen", datei)).replace("T", " ").left(16)]
			if art == "verteidigung":
				titel += " · %s in Runde %d, %d Leben" % [str(e.get("ausgang", "?")), int(e.get("runde", 0)), int(e.get("leben", 0))]
			else:
				titel += " · %d Leben genommen" % int(e.get("leben_genommen", 0))
			funde.append({"pfad": o + "/" + datei, "titel": titel, "datei": datei, "begonnen": str(daten.get("begonnen", "")), "spalten": spalten})
	funde.sort_custom(func(a, b): return str(a["begonnen"]) > str(b["begonnen"]))
	return funde


static func lade(pfad: String) -> Dictionary:
	if not FileAccess.file_exists(pfad):
		return {}
	var daten: Variant = JSON.parse_string(FileAccess.get_file_as_string(pfad))
	if daten is Dictionary and (daten as Dictionary).has("runden"):
		return daten
	return {}


## Speichert ein Phantom und gibt den Pfad zurück ("" = hat nicht geklappt).
static func speichere(art: String, daten: Dictionary) -> String:
	daten["phantom_version"] = PHANTOM_VERSION
	var name := "%s-%s.json" % [art, Time.get_datetime_string_from_system().replace(":", "").replace("-", "").replace("T", "-")]
	for o: String in ordner(art):
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(o))
		var datei := FileAccess.open(o + "/" + name, FileAccess.WRITE)
		if datei != null:
			datei.store_string(JSON.stringify(daten, "\t"))
			datei.close()
			return o + "/" + name
	return ""


## Macht aus einer aufgezeichneten Partie (Bauprotokoll) ein Verteidigungs-Phantom: je Runde der Bau zu Wellenbeginn.
## Dauerschaden steckt nicht drin – der Bau steht jede Runde so, wie er geplant war.
static func aus_partie(partie: Dictionary, quelle: String = "") -> Dictionary:
	var zellen := {}     # Vector2i -> {"typ", ...}
	var schilde := {}    # Batterie -> [Erdwall, Erdwall]
	var runden: Array = []
	for r: Dictionary in partie.get("runden", []):
		if not r.has("ergebnis"):
			continue
		var vorher: Array = []
		var mittendrin: Array = []
		for a: Dictionary in r["aktionen"]:
			if a.has("t"):
				mittendrin.append(a)
			else:
				vorher.append(a)
				_wende_an(zellen, schilde, a)
		var stand := _stand(zellen, schilde)
		for a: Dictionary in mittendrin:
			_wende_an(zellen, schilde, a)
		var e: Dictionary = r["ergebnis"]
		runden.append({"runde": int(r["runde"]), "budget_vorher": int(r.get("budget_vorher", 0)), "aktionen": vorher, "in_runde": mittendrin, "stand": stand,
			"original": {"ausgang": e["ausgang"], "leben": e["leben"], "leben_verloren": e["leben_verloren"], "checkpoints_verloren": e["checkpoints_verloren"], "sekunden": e["sekunden"], "waelle": e["waelle"]}})
	if runden.is_empty():
		return {}
	var letzte: Dictionary = runden[runden.size() - 1]
	return {
		"format": 1, "phantom_version": PHANTOM_VERSION, "art": "verteidigung", "quelle": quelle, "begonnen": str(partie.get("begonnen", "")), "spieler": "Paul",
		"karte": {"spalten": Werte.SPALTEN, "zeilen": Werte.ZEILEN, "checkpoints": partie.get("checkpoints", []), "basis": partie.get("basis", [Werte.BASIS_ZELLE.x, Werte.BASIS_ZELLE.y])},
		"ergebnis": {"ausgang": letzte["original"]["ausgang"], "runde": letzte["runde"], "leben": letzte["original"]["leben"]},
		"runden": runden,
	}


static func _wende_an(zellen: Dictionary, schilde: Dictionary, a: Dictionary) -> void:
	var z := Vector2i(int(a["x"]), int(a["y"]))
	match str(a["a"]):
		"bau":
			var typ := str(a["typ"])
			if typ == "panzer":
				if zellen.has(z) and zellen[z]["typ"] == "wall":
					zellen[z]["panzer"] = true
			elif typ == "stellung" or typ == "turm" or typ == "tor" or typ == "spiegel" or typ == "magnet":
				if not zellen.has(z) or zellen[z]["typ"] != "wall":
					zellen[z] = {"typ": "wall"}
				zellen[z]["ausbau"] = typ
				if typ == "magnet":
					zellen[z]["richtung"] = [int(a.get("rx", 1)), int(a.get("ry", 0))]
			elif typ == "wall":
				zellen[z] = {"typ": "wall"}
			elif typ == "fabrik":
				zellen[z] = {"typ": "fabrik", "einheit": Werte.FABRIK_EINHEITEN[0], "stufe": 0}
			elif typ == "generator":
				var gp := Vector2i(int(a["px"]), int(a["py"])) if a.has("px") else z
				zellen[z] = {"typ": "generator", "partner": gp}
				if gp != z:
					zellen[gp] = {"typ": "generator_teil", "partner": z}
			elif typ == "batterie":
				var pz := Vector2i(int(a["px"]), int(a["py"]))
				zellen[z] = {"typ": "batterie", "partner": pz}
				zellen[pz] = {"typ": "fabrik", "einheit": "pilot", "stufe": 0, "partner": z}
		"abriss":
			if zellen.has(z):
				if zellen[z].has("partner"):
					var p: Vector2i = zellen[z]["partner"]
					zellen.erase(p)
					schilde.erase(p)
				zellen.erase(z)
				schilde.erase(z)
		"einheit":
			if zellen.has(z):
				zellen[z]["einheit"] = str(a["typ"])
		"upgrade":
			if zellen.has(z):
				zellen[z]["stufe"] = int(a["stufe"])
				if str(a.get("faehigkeit", "")) != "":
					zellen[z]["faehigkeit"] = str(a["faehigkeit"])
		"schild":
			if a.has("x2"):   # 16.11.: Schild von Erdwall zu Erdwall
				schilde[Vector2i(int(a["bx"]), int(a["by"]))] = [z, Vector2i(int(a["x2"]), int(a["y2"]))]
		"ziel":
			if zellen.has(z):
				zellen[z]["ziel"] = str(a["modus"])
		"zuweisung":
			if zellen.has(z):
				var liste: Array = zellen[z].get("stellungen", [])
				var s := [int(a["sx"]), int(a["sy"])]
				if liste.has(s):
					liste.erase(s)
				else:
					liste.append(s)
				zellen[z]["stellungen"] = liste


static func _stand(zellen: Dictionary, schilde: Dictionary) -> Dictionary:
	var waelle: Array = []
	var fabriken: Array = []
	var batterien: Array = []
	var generatoren: Array = []
	var felder: Array = zellen.keys()
	felder.sort_custom(func(a: Vector2i, b: Vector2i): return a.x < b.x or (a.x == b.x and a.y < b.y))
	for z: Vector2i in felder:
		var c: Dictionary = zellen[z]
		match str(c["typ"]):
			"wall":
				waelle.append([z.x, z.y, str(c.get("ausbau", "")), bool(c.get("panzer", false)), c.get("richtung", []), int(c.get("stufe", 1)), str(c.get("faehigkeit", ""))])
			"fabrik":
				var f := {"x": z.x, "y": z.y, "einheit": c["einheit"], "stufe": c["stufe"]}
				if c.has("faehigkeit"):
					f["faehigkeit"] = c["faehigkeit"]
				if c.has("ziel"):
					f["ziel"] = c["ziel"]
				if c.has("stellungen"):
					f["stellungen"] = c["stellungen"]
				if c.has("partner"):
					f["batterie"] = [c["partner"].x, c["partner"].y]
				fabriken.append(f)
			"generator":
				var gp: Vector2i = c["partner"]
				generatoren.append([z.x, z.y, gp.x, gp.y])
			"batterie":
				var pz: Vector2i = c["partner"]
				var b := {"x": z.x, "y": z.y, "px": pz.x, "py": pz.y, "stufe": int(zellen[pz]["stufe"]) if zellen.has(pz) else 0}
				if schilde.has(z):
					b["schild"] = [schilde[z][0].x, schilde[z][0].y, schilde[z][1].x, schilde[z][1].y]
				batterien.append(b)
	return {"waelle": waelle, "fabriken": fabriken, "batterien": batterien, "generatoren": generatoren}


## Kurzfassung eines Plans für die Vorschau des Verteidigers: Trupps in Reihenfolge.
static func plan_text(trupps: Array) -> String:
	var teile: PackedStringArray = []
	for t: Dictionary in trupps:
		var anzahl := {}
		var folge: Array = []
		for typ: String in t["typen"]:
			if not anzahl.has(typ):
				folge.append(typ)
			anzahl[typ] = int(anzahl.get(typ, 0)) + 1
		if folge.is_empty():
			continue
		var worte: PackedStringArray = []
		for typ: String in folge:
			worte.append("%d %s" % [anzahl[typ], Werte.GEGNER[typ]["kurz"]])
		var text := " + ".join(worte)
		if t.get("weg", "l") == "w":
			text = "Wurf (%s)" % text
		elif float(t.get("pause", 0.0)) >= 5.0:
			text = "… " + text
		teile.append(text)
	return "  →  ".join(teile)


## Nimmt eine erhaltene Datei in den Pool auf: ein fertiges Phantom (Verteidigung oder Angriff) oder eine Partie,
## aus der ein Verteidigungs-Phantom gemacht wird. Gibt {"ok": bool, "text": Meldung} zurück.
static func importiere(text: String, herkunft: String = "") -> Dictionary:
	var leser := JSON.new()
	var daten: Variant = leser.data if leser.parse(text) == OK else null
	if not (daten is Dictionary) or not (daten as Dictionary).has("runden"):
		return {"ok": false, "text": "Das ist keine Partie- oder Phantom-Datei."}
	var d: Dictionary = daten
	var art := str(d.get("art", ""))
	if art == "":
		# eine aufgezeichnete Partie: daraus wird ein Verteidigungs-Phantom
		d = aus_partie(d, herkunft.get_file())
		art = "verteidigung"
		if d.is_empty():
			return {"ok": false, "text": "In dieser Partie ist keine Runde abgeschlossen."}
	if art != "verteidigung" and art != "angriff":
		return {"ok": false, "text": "Unbekannte Art von Phantom: %s" % art}
	if (d["runden"] as Array).is_empty():
		return {"ok": false, "text": "Dieses Phantom hat keine Runden."}
	if art == "verteidigung" and not (d["runden"][0] as Dictionary).has("stand"):
		return {"ok": false, "text": "Diesem Verteidigungs-Phantom fehlt der Bau je Runde."}
	# Dateiname aus dem Beginn der Partie: dieselbe Datei zweimal hochgeladen ergibt kein Doppel
	var stempel := str(d.get("begonnen", "")).replace(":", "").replace("-", "").replace("T", "-")
	if stempel == "":
		stempel = Time.get_datetime_string_from_system().replace(":", "").replace("-", "").replace("T", "-")
	var name := "%s-%s.json" % [art, stempel]
	for o: String in ordner(art):
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(o))
		var datei := FileAccess.open(o + "/" + name, FileAccess.WRITE)
		if datei != null:
			datei.store_string(JSON.stringify(d, "\t"))
			datei.close()
			return {"ok": true, "art": art, "text": "Aufgenommen: %s von %s, %d Runden. Zu finden unter „Phantom: %s“." % ["Verteidigung" if art == "verteidigung" else "Angriff", str(d.get("spieler", "?")), (d["runden"] as Array).size(), "Angriff [3]" if art == "verteidigung" else "Verteidigung [4]"]}
	return {"ok": false, "text": "Die Datei ließ sich nicht speichern."}
