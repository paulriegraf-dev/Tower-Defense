class_name Profil
extends RefCounted
## Spielerprofil (18.11.2026): Spitzname und Statistiken. Gespeichert im Benutzerordner – im Browser bleibt es im
## Speicher des Browsers (IndexedDB), bis jemand die Websitedaten löscht. Die zufällige ID verknüpft eigene Phantome
## und Duelle in der Online-Rangliste mit dem Profil; der Name ist nur zum Anzeigen da.

const DATEI := "user://profil.json"
const NAME_MAX := 16
const GAST := "Gast"

static var _d: Dictionary = {}
static var _geladen := false


static func _lade() -> void:
	if _geladen:
		return
	_geladen = true
	_d = {}
	if FileAccess.file_exists(DATEI):
		var v: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATEI))
		if v is Dictionary:
			_d = v
	if str(_d.get("id", "")) == "":
		var z := RandomNumberGenerator.new()
		z.randomize()
		_d["id"] = "%08x%08x" % [z.randi(), z.randi()]
		_d["angelegt"] = Time.get_datetime_string_from_system()
	if not (_d.get("stat") is Dictionary):
		_d["stat"] = {}
	if not (_d.get("kills") is Dictionary):
		_d["kills"] = {}
	_speichere()


static func _speichere() -> void:
	var f := FileAccess.open(DATEI, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(_d, "\t"))
		f.close()


static func id() -> String:
	_lade()
	return str(_d["id"])


static func hat_namen() -> bool:
	_lade()
	return str(_d.get("name", "")) != ""


static func name() -> String:
	_lade()
	var n := str(_d.get("name", ""))
	return n if n != "" else GAST


## Schon einmal nach dem Namen gefragt (auch wenn „Später“ gewählt wurde)?
static func gefragt() -> bool:
	_lade()
	return bool(_d.get("gefragt", false)) or hat_namen()


static func setze_gefragt() -> void:
	_lade()
	_d["gefragt"] = true
	_speichere()


## Nur Buchstaben, Ziffern, Leerzeichen, - und _; höchstens 16 Zeichen.
static func bereinige(text: String) -> String:
	var aus := ""
	for c in text.strip_edges():
		var u := c.unicode_at(0)
		var ok := (c >= "a" and c <= "z") or (c >= "A" and c <= "Z") or (c >= "0" and c <= "9") or c in [" ", "-", "_", "ä", "ö", "ü", "Ä", "Ö", "Ü", "ß"] or (u >= 0xC0 and u <= 0x24F)
		if ok:
			aus += c
	while aus.contains("  "):
		aus = aus.replace("  ", " ")
	return aus.left(NAME_MAX).strip_edges()


static func setze_name(text: String) -> bool:
	_lade()
	var n := bereinige(text)
	if n == "":
		return false
	_d["name"] = n
	_d["gefragt"] = true
	_speichere()
	return true


static func stat(schluessel: String) -> int:
	_lade()
	return int((_d["stat"] as Dictionary).get(schluessel, 0))


static func _plus(schluessel: String, n: int = 1) -> void:
	_d["stat"][schluessel] = stat(schluessel) + n


static func _max(schluessel: String, wert: int) -> void:
	_d["stat"][schluessel] = maxi(stat(schluessel), wert)


static func einstellung(schluessel: String, standard: Variant) -> Variant:
	_lade()
	return _d.get("e_" + schluessel, standard)


static func setze_einstellung(schluessel: String, wert: Variant) -> void:
	_lade()
	_d["e_" + schluessel] = wert
	_speichere()


## Eine Partie als Verteidiger ist zu Ende (normales Spiel, Tutorial oder gegen einen Angriff).
## `kills`: "einheit:<typ>" / "turm:<art>" / "batterie" / "brakk" -> Anzahl.
static func partie_ende(sieg: bool, runde: int, kills: Dictionary, verteidigungswertung: int = -1) -> void:
	_lade()
	_plus("partien")
	if sieg:
		_plus("siege")
	_max("beste_runde", runde)
	if verteidigungswertung >= 0:
		_plus("verteidigt")
		_max("beste_verteidigung", verteidigungswertung)
	var alle: Dictionary = _d["kills"]
	for k: String in kills:
		alle[k] = int(alle.get(k, 0)) + int(kills[k])
		_plus("kills", int(kills[k]))
	_speichere()


## Ein Phantom-Angriff ist zu Ende.
static func angriff_ende(wertung: int, geknackt: int) -> void:
	_lade()
	_plus("angriffe")
	_plus("geknackt", geknackt)
	_max("beste_angriffswertung", wertung)
	_speichere()


## Aus einem Sieg wurde ein eigenes Verteidigungs-Phantom.
static func phantom_erstellt() -> void:
	_lade()
	_plus("phantome")
	_speichere()


## Der meistgenutzte Eintrag mit diesem Vorsatz ("einheit:" / "turm:"): [Schlüssel ohne Vorsatz, Kills] oder [].
static func liebling(vorsatz: String) -> Array:
	_lade()
	var bester := ""
	var meiste := 0
	for k: String in (_d["kills"] as Dictionary):
		if k.begins_with(vorsatz) and int(_d["kills"][k]) > meiste:
			meiste = int(_d["kills"][k])
			bester = k.trim_prefix(vorsatz)
	return [] if bester == "" else [bester, meiste]


static func kills(schluessel: String) -> int:
	_lade()
	return int((_d["kills"] as Dictionary).get(schluessel, 0))


## 18.11.: Erfolge (siehe erfolge.gd): id -> Zeitpunkt der Freischaltung.
static func hat_erfolg(id: String) -> bool:
	_lade()
	return (_d.get("erfolge", {}) as Dictionary).has(id)


## true, wenn der Erfolg gerade neu freigeschaltet wurde.
static func setze_erfolg(id: String) -> bool:
	_lade()
	if not (_d.get("erfolge") is Dictionary):
		_d["erfolge"] = {}
	if (_d["erfolge"] as Dictionary).has(id):
		return false
	_d["erfolge"][id] = Time.get_datetime_string_from_system()
	_speichere()
	return true


## 18.11.: Formenlehre – merkt sich, welche Turmarten schon einmal gebaut wurden. Gibt die Anzahl zurück.
static func merke_form(art: String) -> int:
	_lade()
	if not (_d.get("formen") is Array):
		_d["formen"] = []
	var formen: Array = _d["formen"]
	if not formen.has(art):
		formen.append(art)
		_speichere()
	return formen.size()


## Zeilen für die Profilseite: [Bezeichnung, Wert].
static func zeilen() -> Array:
	_lade()
	var z: Array = []
	var partien := stat("partien")
	z.append(["Partien", str(partien)])
	z.append(["Siege", "%d" % stat("siege") + (" (%d %%)" % roundi(100.0 * stat("siege") / partien) if partien > 0 else "")])
	z.append(["Beste Runde", str(stat("beste_runde")) if stat("beste_runde") > 0 else "–"])
	z.append(["Gegner besiegt", str(stat("kills"))])
	var e := liebling("einheit:")
	z.append(["Lieblingseinheit", "%s · %d" % [str(Werte.EINHEITEN.get(e[0], {}).get("name", e[0])), e[1]] if not e.is_empty() else "–"])
	var t := liebling("turm:")
	z.append(["Lieblingsturm", "%s · %d" % [str(Werte.TURMARTEN.get(t[0], {}).get("name", t[0])), t[1]] if not t.is_empty() else "–"])
	z.append(["Brakk", "%d Gegner" % kills("brakk")])
	z.append(["Phantom-Angriffe", "%d · %d geknackt" % [stat("angriffe"), stat("geknackt")]])
	z.append(["Beste Angriffswertung", str(stat("beste_angriffswertung")) if stat("beste_angriffswertung") > 0 else "–"])
	z.append(["Beste Verteidigung", str(stat("beste_verteidigung")) if stat("beste_verteidigung") > 0 else "–"])
	z.append(["Eigene Phantome", str(stat("phantome"))])
	return z
