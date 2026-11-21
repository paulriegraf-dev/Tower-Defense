class_name Anfuehrer
extends RefCounted
## 19.11.: Anführer (Schritt 2b). Vor jeder Partie wird einer gewählt (Startmenü → Spielen → Los, auch Herausforderungen);
## seine Perks gelten ab Runde 1. Hier stehen nur Liste und Texte – alle Zahlen liegen in werte.gd, Block „Anführer“
## (ANFUEHRER_STANDARD = Regeln wie bisher = Brakk, ANFUEHRER_WERTE je Anführer). Der laufende steht in Werte.anfuehrer.
## Freischalten: über den Erfolg in „erfolg“ (leer = immer frei). „rangliste“ false: keine Rangliste, keine Phantome.
## Figuren (Slot [8]) kommen in Schritt 2c – bis dahin hat nur Brakk eine (Werte.af("figur")).
## Felder: id, name, initiale (Porträt-Platzhalter), farbe, kurz, perks (drei Zeilen), nachteile, erfolg, rangliste.

const LISTE: Array[Dictionary] = [
	{"id": "brakk", "name": "Brakk", "initiale": "B", "farbe": Color("7fe0ff"), "portraet": "res://assets/neu/ui/bau_brakk.png",   # 20.11. (Paul): echtes Porträt; die anderen folgen zum 30.11.
		"kurz": "Kommandant des Technoclans. Alles wie gewohnt.",
		"perks": ["Figur Brakk [8]: 500, einmal je Partie", "Alle Bauwerke ohne Grenzen", "Bewährte Regeln, ohne Überraschungen"],
		"nachteile": ["Keine – Allrounder – balancierte Spielerfahrung"],
		"erfolg": "", "rangliste": true},
	{"id": "irrtuermer", "name": "Irrtürmer", "initiale": "I", "farbe": Color("ffd34d"), "portraet": "res://assets/neu/ui/portraet_irrtuermer.png",   # 21.11. (Paul): PixelLab
		"kurz": "Ingenieur, der auf Türme setzt.",
		"perks": ["Türme bis Stufe 4 (600: +20 % Schaden, +0,5 Reichweite, beide Fähigkeiten)", "Truppenturm und PliPlop 3cK (100, auf einem Einzelwall, drei Pfade)", "Turm-Stufen 25 % billiger, Türme ohne Stütze, 12 Gratis-Erdwälle"],
		"nachteile": ["Höchstens 3 Fabriken", "Fabrik-Stufen 20 % teurer"],
		"erfolg": "baumeister", "rangliste": true},
	{"id": "sonde7", "name": "Sonde 7", "initiale": "7", "farbe": Color("6ee6ff"), "portraet": "res://assets/neu/ui/portraet_sonde7.png",   # 21.11. (Paul): das Tutorial-Porträt, verkleinert auf 32
		"kurz": "Die Leitstelle setzt auf Infanterie und MG-Nester.",
		"perks": ["Fabriken halber Preis, gleich auf Stufe 2 (190), Stufen 25 % billiger", "MG-Stellung (50) mit eigenem Ausbau: 50 / 100 / 225 – die Truppe darin ist nur Besatzung", "Stufe 4 (800): Elite-Truppe (+50 % Leben, +40 % Schaden)"],
		"nachteile": ["Je Fabrik nur 1 Truppe (auch spezialisiert)", "Türme nur bis Stufe 2", "Kein Schildgenerator"],
		"erfolg": "ausbilder", "rangliste": true},
	{"id": "paul", "name": "Paul", "initiale": "P", "farbe": Color("ffb070"),
		"kurz": "Zum Spaß: Wirtschaft und Aufträge.",
		"perks": ["Je Runde 1–4 Aufträge, Leicht bis Wahnsinn: Lohn bis 2 Rundenboni, dazu Gratis-Fabriken und Leben", "Zinsen bis 100, Prämien ×1,5", "Abriss gibt immer 100 % zurück"],
		"nachteile": ["10 statt 15 Leben, Erdwälle kosten 15", "Pflicht-Aufträge strafen (Leben oder Budget)", "Zählt nicht für Rangliste und Phantome"],
		"erfolg": "deutscher_sparer", "rangliste": false},
]


static var _portraets := {}

## 21.11. (Paul): Porträt eines Anführers (null = noch keins, dann zeigt die Kachel die Initiale). Einmal geladen und
## gemerkt – das Startmenü lädt alle beim Aufbau vor, damit das Bild beim ersten Zeichnen schon da ist.
static func portraet(id: String) -> Texture2D:
	if not _portraets.has(id):
		var pfad := str(eintrag(id).get("portraet", ""))
		_portraets[id] = load(pfad) if pfad != "" and ResourceLoader.exists(pfad) else null
	return _portraets[id]


static func eintrag(id: String) -> Dictionary:
	for a: Dictionary in LISTE:
		if str(a["id"]) == id:
			return a
	return LISTE[0]


## Unbekannt oder leer (alte Phantome, alte Zwischenstände) = Brakk.
static func gueltig(id: String) -> String:
	for a: Dictionary in LISTE:
		if str(a["id"]) == id:
			return id
	return "brakk"


static func name(id: String) -> String:
	return str(eintrag(id)["name"])


## Freigeschaltet? Brakk immer; sonst über seinen Erfolg.
static func frei(id: String) -> bool:
	var e := str(eintrag(id)["erfolg"])
	return e == "" or Profil.hat_erfolg(e) or Profil.hat_code("allesfrei")   # 20.11.: Entwicklercode


## 20.11.: Nur per Code frei (Code „allesfrei“ oder Erfolg aus dem Code „erfolge“) – dann keine Rangliste, keine Phantome.
static func per_code(id: String) -> bool:
	var e := str(eintrag(id)["erfolg"])
	return e != "" and not Profil.erfolg_verdient(e)


static func ranglistenfaehig(id: String) -> bool:
	return bool(eintrag(id)["rangliste"])


## Wie der gesperrte Anführer freigeschaltet wird: Name des Erfolgs, beim versteckten nur als Tipp.
static func freischalt_text(id: String) -> String:
	var e := Erfolge.eintrag(str(eintrag(id)["erfolg"]))
	if e.is_empty():
		return ""
	return ("Tipp: " if bool(e["versteckt"]) else "Erfolg: ") + str(e["name"])
