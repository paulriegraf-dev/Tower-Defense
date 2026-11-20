class_name Auftraege
extends RefCounted
## 20.11. (Paul): Aufträge für Anführer Paul. Ab Runde AB_RUNDE bekommt er zu jeder Bauphase einen zufälligen Auftrag
## (nie zweimal derselbe hintereinander). Er steht oben in der Rundenanzeige. Zwei Arten:
##   angebot – erfüllt = Belohnung, sonst nichts
##   pflicht – erfüllt = kleine Belohnung, verfehlt = Strafe (Leben oder ein Teil des Budgets) – die unangenehmen, die
##             zum Ausgeben und Umbauen zwingen
## Geprüft wird beim Start der Welle ("welle") oder am Rundenende ("ende"). Gezählt wird in main.gd über zaehle():
## "bau:<typ>", "abriss:<typ>" (typ wie main.BAU_NAMEN, ein Turm zählt als "turm"), "upgrade", "ausgaben".
## Felder: id, name, text, art, pruefung, zaehler, ziel, belohnung, optional hoechstens (Ziel ist eine Obergrenze),
## strafe_leben, strafe_anteil (Anteil des Budgets), ab (erst ab dieser Runde), braucht (main-Bedingung, siehe _moeglich).

const AB_RUNDE := 2
const LEBEN_MIN := 1   # eine Strafe nimmt nie das letzte Leben

const LISTE: Array[Dictionary] = [
	{"id": "grosseinkauf", "name": "Großeinkauf", "text": "Gib in dieser Bauphase mindestens 250 aus.", "art": "angebot", "pruefung": "welle", "zaehler": "ausgaben", "ziel": 250, "belohnung": 100},
	{"id": "turmfieber", "name": "Turmfieber", "text": "Bau einen neuen Turm.", "art": "angebot", "pruefung": "welle", "zaehler": "bau:turm", "ziel": 1, "belohnung": 80},
	{"id": "gruenderzeit", "name": "Gründerzeit", "text": "Bau eine neue Fabrik.", "art": "angebot", "pruefung": "welle", "zaehler": "bau:fabrik", "ziel": 1, "belohnung": 60},
	{"id": "modernisierung", "name": "Modernisierung", "text": "Werte eine Fabrik oder einen Turm auf.", "art": "angebot", "pruefung": "welle", "zaehler": "upgrade", "ziel": 1, "belohnung": 70},
	{"id": "mauerbau", "name": "Mauerbau", "text": "Bau 6 Erdwälle.", "art": "angebot", "pruefung": "welle", "zaehler": "bau:wall", "ziel": 6, "belohnung": 50},
	{"id": "panzerpflicht", "name": "Gut gepanzert", "text": "Panzere 2 Erdwälle.", "art": "angebot", "pruefung": "welle", "zaehler": "bau:panzer", "ziel": 2, "belohnung": 60, "ab": 3},
	{"id": "umzug", "name": "Umzug", "text": "Reiß eine Fabrik ab (und bau sie woanders neu).", "art": "angebot", "pruefung": "welle", "zaehler": "abriss:fabrik", "ziel": 1, "belohnung": 150, "braucht": "fabrik"},
	{"id": "saubere_arbeit", "name": "Saubere Arbeit", "text": "Verlier in dieser Runde kein Leben.", "art": "angebot", "pruefung": "ende", "zaehler": "leben_verloren", "ziel": 0, "hoechstens": true, "belohnung": 100},
	{"id": "grundbesitz", "name": "Grundbesitz", "text": "Am Rundenende gehören dir beide Checkpoints.", "art": "angebot", "pruefung": "ende", "zaehler": "cp_feind", "ziel": 0, "hoechstens": true, "belohnung": 80, "ab": 5},
	{"id": "abrissbirne", "name": "Abrissbirne", "text": "Pflicht: Reiß 4 Erdwälle ab – sonst 1 Leben weg.", "art": "pflicht", "pruefung": "welle", "zaehler": "abriss:wall", "ziel": 4, "belohnung": 30, "strafe_leben": 1, "braucht": "waelle"},
	{"id": "sparverbot", "name": "Sparverbot", "text": "Pflicht: Starte die Welle mit höchstens 100 Budget – sonst ein Viertel weg.", "art": "pflicht", "pruefung": "welle", "zaehler": "budget", "ziel": 100, "hoechstens": true, "belohnung": 60, "strafe_anteil": 0.25, "braucht": "geld"},
	{"id": "steuerpruefung", "name": "Steuerprüfung", "text": "Pflicht: Gib mindestens die Hälfte deines Budgets aus – sonst ein Viertel weg.", "art": "pflicht", "pruefung": "welle", "zaehler": "ausgaben_anteil", "ziel": 0.5, "belohnung": 0, "strafe_anteil": 0.25, "braucht": "geld"},
	{"id": "turmtausch", "name": "Turmtausch", "text": "Pflicht: Reiß einen Turm ab und bau einen neuen – sonst 1 Leben weg.", "art": "pflicht", "pruefung": "welle", "zaehler": "turmtausch", "ziel": 1, "belohnung": 50, "strafe_leben": 1, "braucht": "turm"},
	{"id": "fabrikschliessung", "name": "Werksschließung", "text": "Pflicht: Reiß eine Fabrik ab – sonst 2 Leben weg.", "art": "pflicht", "pruefung": "welle", "zaehler": "abriss:fabrik", "ziel": 1, "belohnung": 120, "strafe_leben": 2, "braucht": "zwei_fabriken", "ab": 4},
]


## Neue Bauphase: einen Auftrag ziehen (nur Paul, nicht in Sandbox/Phantom). Gibt den Auftrag zurück ({} = keiner).
static func neuer(spiel: Node) -> Dictionary:
	if not Werte.auftraege_an() or spiel.sandbox or spiel.phantom_modus != "" or int(spiel.welle) < AB_RUNDE:
		return {}
	var vorher := str(spiel.get("auftrag_letzter"))
	var moeglich: Array[Dictionary] = []
	for a: Dictionary in LISTE:
		if str(a["id"]) != vorher and int(spiel.welle) >= int(a.get("ab", 0)) and _moeglich(spiel, str(a.get("braucht", ""))):
			moeglich.append(a)
	if moeglich.is_empty():
		return {}
	var a: Dictionary = moeglich.pick_random()
	return {"id": a["id"], "budget_start": int(spiel.budget), "leben_start": int(spiel.leben), "zaehler": {}}


static func eintrag(id: String) -> Dictionary:
	for a: Dictionary in LISTE:
		if str(a["id"]) == id:
			return a
	return {}


static func _moeglich(spiel: Node, braucht: String) -> bool:
	match braucht:
		"fabrik":
			return int(spiel._normale_fabriken()) >= 1
		"zwei_fabriken":
			return int(spiel._normale_fabriken()) >= 2
		"turm":
			return not (spiel.karte.turm_art as Dictionary).is_empty()
		"waelle":
			var n := 0
			for z: Vector2i in spiel.karte.feld:
				if spiel.karte.feld[z] == Karte.WALL and not spiel.karte.fest.has(z) and not spiel.karte.ausbau.has(z):
					n += 1
			return n >= 6
		"geld":
			return int(spiel.budget) >= 200
	return true


## Zählt eine Handlung für den laufenden Auftrag.
static func zaehle(auftrag: Dictionary, schluessel: String, n: int = 1) -> void:
	if auftrag.is_empty():
		return
	var z: Dictionary = auftrag["zaehler"]
	z[schluessel] = int(z.get(schluessel, 0)) + n


## Stand des Zählers für die Prüfung.
static func _wert(spiel: Node, auftrag: Dictionary, zaehler: String) -> float:
	var z: Dictionary = auftrag["zaehler"]
	match zaehler:
		"budget":
			return float(spiel.budget)
		"ausgaben_anteil":
			return float(z.get("ausgaben", 0)) / maxf(1.0, float(auftrag["budget_start"]))
		"leben_verloren":
			return float(int(auftrag["leben_start"]) - int(spiel.leben))
		"cp_feind":
			var n := 0
			for f: bool in spiel.karte.cp_feind:
				if f:
					n += 1
			return float(n)
		"turmtausch":
			return float(mini(int(z.get("abriss:turm", 0)), int(z.get("bau:turm", 0))))
	return float(z.get(zaehler, 0))


## Prüft den Auftrag zum Zeitpunkt `wann` ("welle" oder "ende"). Zahlt aus oder straft und meldet es.
## Gibt true zurück, wenn der Auftrag damit erledigt ist (main.gd löscht ihn dann).
static func pruefe(spiel: Node, auftrag: Dictionary, wann: String) -> bool:
	var a := eintrag(str(auftrag.get("id", "")))
	if a.is_empty() or str(a["pruefung"]) != wann:
		return false
	var wert :=_wert(spiel, auftrag, str(a["zaehler"]))
	var ziel := float(a["ziel"])
	var erfuellt := wert <= ziel if bool(a.get("hoechstens", false)) else wert >= ziel
	if erfuellt:
		var b := int(a.get("belohnung", 0))
		spiel.budget += b
		spiel.melde("Auftrag „%s“ erfüllt%s" % [a["name"], (": +%d Budget." % b) if b > 0 else "."], 5.0)
	elif str(a["art"]) == "pflicht":
		var text := ""
		if a.has("strafe_leben"):
			var weg := mini(int(a["strafe_leben"]), maxi(0, int(spiel.leben) - LEBEN_MIN))
			spiel.leben -= weg
			text = "%d Leben weg" % weg
		if a.has("strafe_anteil"):
			var weg2 := roundi(int(spiel.budget) * float(a["strafe_anteil"]))
			spiel.budget -= weg2
			text = "%d Budget weg" % weg2
		spiel.melde("Auftrag „%s“ verfehlt: %s." % [a["name"], text], 6.0)
	else:
		spiel.melde("Auftrag „%s“ nicht erfüllt." % a["name"], 4.0)
	return true


## Kurz für die Rundenanzeige und die Übersicht.
static func titel(auftrag: Dictionary) -> String:
	var a := eintrag(str(auftrag.get("id", "")))
	return "" if a.is_empty() else ("Pflicht: " if str(a["art"]) == "pflicht" else "Auftrag: ") + str(a["name"])


static func uebersicht() -> Array[String]:
	var aus: Array[String] = []
	for a: Dictionary in LISTE:
		aus.append("%s – %s" % [a["name"], str(a["text"]).trim_prefix("Pflicht: ")] + (" (+%d)" % int(a["belohnung"]) if int(a["belohnung"]) > 0 else ""))
	return aus
