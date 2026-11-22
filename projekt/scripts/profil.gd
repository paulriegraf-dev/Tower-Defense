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
	_wende_codes_an()   # 20.11.: Entwicklercodes
	_uebernimm_freischaltung()   # 21.11.
	_speichere()


## 9a: Balance-Labor – das Profil wird nie geschrieben (keine Erfolge, Kills, Freischaltungen aus Bot-Partien).
static var nur_lesen := false

static func _speichere() -> void:
	if nur_lesen:
		return
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


## 20.11.: Entwicklercodes (Einstellungen → Code). Code → Wirkung (Text der Einblendung); verglichen ohne Groß/Klein.
## Eingelöste Codes stehen im Profil (Feld „codes“) und wirken bei jedem Start wieder.
## allesfrei: alle Anführer frei, ohne ihre Erfolge zu vergeben (Partien damit: keine Rangliste, keine Phantome).
## erfolge: alle Erfolge (nur zum Testen der Anzeige) – als Zeitpunkt steht „Code“, damit sie nicht als verdient gelten.
const CODES := {
	"allesfrei": "alle Anführer frei",
	"erfolge": "alle Erfolge",
	"befehl24": "Brakk-Mode Rogue (Befehl 24) frei",   # 20.11.
}
const PER_CODE := "Code"


static func hat_code(code: String) -> bool:
	_lade()
	return (_d.get("codes", []) as Array).has(code)


## 20.11. (Paul): Rogue (Befehl 24) ist frei, wenn Classic einmal gewonnen wurde (oder per Code „befehl24“/„allesfrei“).
static func rogue_frei() -> bool:
	return bool(einstellung("rogue_frei", false)) or hat_code("befehl24") or hat_code("allesfrei")


## 21.11. (Paul): Freischaltung im Startmenü – Brakk-Mode (Classic und Rogue) nach dem ersten Aufstellen von Brakk
## (Erfolg „aufgestellt“), Phantom-Modus nach einem Sieg in Runde 20 (Erfolg „gegenangriff“); „allesfrei“ schaltet beide frei.
static func brakk_modus_frei() -> bool:
	return hat_erfolg("aufgestellt") or hat_code("allesfrei")


static func phantom_frei() -> bool:
	return hat_erfolg("gegenangriff") or hat_code("allesfrei")


## Profile von vor der Freischaltung: wer schon gewonnen oder Brakk aufgestellt hat (Statistik), bekommt sie beim ersten Start.
static func _uebernimm_freischaltung() -> void:
	if bool(_d.get("freischaltung_geprueft", false)):
		return
	_d["freischaltung_geprueft"] = true
	if not (_d.get("erfolge") is Dictionary):
		_d["erfolge"] = {}
	var erf: Dictionary = _d["erfolge"]
	var st: Dictionary = _d["stat"]
	var jetzt := Time.get_datetime_string_from_system()
	if int(st.get("siege", 0)) > 0 and not erf.has("gegenangriff"):
		erf["gegenangriff"] = jetzt
	var brakk := int((_d["kills"] as Dictionary).get("brakk", 0)) > 0 or erf.has("kommandant") or erf.has("doppelgaenger")
	for k: String in st:
		if k.begins_with("brakk_") and int(st[k]) > 0:
			brakk = true   # im Brakk-Mode gespielt
	if brakk and not erf.has("aufgestellt"):
		erf["aufgestellt"] = jetzt


## Erfolg wirklich verdient (nicht über den Code „erfolge“)?
static func erfolg_verdient(id: String) -> bool:
	_lade()
	var e: Dictionary = _d.get("erfolge", {})
	return e.has(id) and str(e[id]) != PER_CODE


## Löst einen Code ein und gibt den Text für die Einblendung zurück ("" = unbekannter Code).
static func loese_code(text: String) -> String:
	_lade()
	# 20.11. (Paul: „Unbekannter Code“): nur Buchstaben und Ziffern zählen – Anführungszeichen beim Kopieren,
	# Leerzeichen oder Punkt von der Handy-Autokorrektur („Alles frei.“) stören nicht
	var code := ""
	for c in text.to_lower():
		if (c >= "a" and c <= "z") or (c >= "0" and c <= "9"):
			code += c
	if not CODES.has(code):
		return ""
	if not (_d.get("codes") is Array):
		_d["codes"] = []
	if not (_d["codes"] as Array).has(code):
		(_d["codes"] as Array).append(code)
	_wende_codes_an()
	_speichere()
	return str(CODES[code])


## Einstellungen → „Einlösen“ (Startmenü und Pausenmenü): einlösen und als Einblendung zurückmelden.
static func code_einloesen(text: String) -> bool:
	var wirkung := loese_code(text)
	if wirkung == "":
		Erfolge.einblendung("Unbekannter Code", "", "buch")
		return false
	Erfolge.einblendung("Code eingelöst: " + wirkung, "", "brakk")
	return true


## Wirkungen, die im Profil stehen müssen (allesfrei wird bei Anfuehrer.frei() abgefragt). Auch neue Erfolge späterer
## Versionen kommen so beim Start dazu.
static func _wende_codes_an() -> void:
	if not hat_code("erfolge"):
		return
	if not (_d.get("erfolge") is Dictionary):
		_d["erfolge"] = {}
	for e: Dictionary in Erfolge.LISTE:
		if not (_d["erfolge"] as Dictionary).has(str(e["id"])):
			_d["erfolge"][str(e["id"])] = PER_CODE


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


## 20.11.: Schlüssel-Zusatz je Anführer im Brakk-Mode – Brakk behält die alten Schlüssel ("brakk_siege" …), die anderen
## bekommen „_<id>“ angehängt („brakk_siege_sonde7“ …).
static func ego_s(anfuehrer: String) -> String:
	return "" if anfuehrer == "brakk" or anfuehrer == "" else "_" + anfuehrer


## 19.11. (Paul): Sieg im Brakk-Mode – Siege, höchste Stufe, Ringe und Titel zählen, die Übersicht des letzten Siegs merken.
## 20.11.: je Anführer getrennt (bericht["anfuehrer"]).
static func brakk_sieg(bericht: Dictionary) -> void:
	_lade()
	var s := ego_s(str(bericht.get("anfuehrer", "brakk")))
	_plus("brakk_siege" + s)
	_max("brakk_stufe" + s, int(bericht.get("stufe", 1)))
	var ringe: Dictionary = _d.get("e_brakk_ringe" + s, {})
	for e: Array in bericht.get("ringe", []):
		ringe[str(e[0])] = int(ringe.get(str(e[0]), 0)) + 1
	_d["e_brakk_ringe" + s] = ringe
	var titel: Dictionary = _d.get("e_brakk_titel" + s, {})
	var t := str(bericht.get("titel", ""))
	titel[t] = int(titel.get(t, 0)) + 1
	_d["e_brakk_titel" + s] = titel
	_d["e_brakk_letzter_sieg" + s] = bericht
	_speichere()


## Häufigster Eintrag einer Zählung (Lieblingsring, häufigster Titel): [Schlüssel, Anzahl] oder [].
static func brakk_meist(schluessel: String) -> Array:
	var d: Dictionary = einstellung(schluessel, {})
	var beste := ""
	var n := 0
	for k: String in d:
		if int(d[k]) > n:
			n = int(d[k])
			beste = k
	return [beste, n] if beste != "" else []
