class_name Anfuehrer
extends RefCounted
## 19.11.: Anführer (Schritt 2b). Vor jeder Partie wird einer gewählt (Startmenü → Spielen → Los, auch Herausforderungen);
## seine Perks gelten ab Runde 1. Hier stehen nur Liste und Texte – alle Zahlen liegen in werte.gd, Block „Anführer“
## (ANFUEHRER_STANDARD = Regeln wie bisher = Brakk, ANFUEHRER_WERTE je Anführer). Der laufende steht in Werte.anfuehrer.
## Freischalten: über den Erfolg in „erfolg“ (leer = immer frei). „rangliste“ false: keine Rangliste, keine Phantome.
## Figuren (Slot [8]) kommen in Schritt 2c – bis dahin hat nur Brakk eine (Werte.af("figur")).
## Felder: id, name, initiale (Porträt-Platzhalter), farbe, kurz, perks (drei Zeilen), nachteile, erfolg, rangliste.

const LISTE: Array[Dictionary] = [
	{"id": "brakk", "name": "Brakk", "initiale": "B", "farbe": Color("7fe0ff"),
		"kurz": "Kommandant des Technoclans. Alles wie gewohnt.",
		"perks": ["Figur Brakk [8]: 500, einmal je Partie", "Alle Bauwerke ohne Grenzen", "Bewährte Regeln, ohne Überraschungen"],
		"nachteile": ["Keine – aber auch keine Extras"],
		"erfolg": "", "rangliste": true},
	{"id": "irrtuermer", "name": "Irrtürmer", "initiale": "I", "farbe": Color("ffd34d"),
		"kurz": "Ingenieur, der auf Türme setzt.",
		"perks": ["Türme bis Stufe 4 (+20 % Schaden, +0,5 Reichweite, beide Fähigkeiten)", "Truppenturm: hält Werkschutz-Truppen", "Turm-Stufen 25 % billiger, Türme ohne Stütze, 12 Gratis-Erdwälle"],
		"nachteile": ["Höchstens 3 Fabriken", "Fabrik-Stufen 20 % teurer"],
		"erfolg": "baumeister", "rangliste": true},
	{"id": "sonde7", "name": "Sonde 7", "initiale": "7", "farbe": Color("6ee6ff"),
		"kurz": "Die Leitstelle setzt auf Infanterie und MG-Nester.",
		"perks": ["Fabriken 50 %, Fabrik-Stufen 25 % billiger", "MG-Stellungen: +50 % Schussrate, +0,5 Reichweite", "Stufe 4: Elite-Truppe (+50 % Leben, +40 % Schaden)"],
		"nachteile": ["Je Fabrik nur 1 Truppe (auch spezialisiert)", "Türme nur bis Stufe 2", "Kein Schildgenerator"],
		"erfolg": "ausbilder", "rangliste": true},
	{"id": "paul", "name": "Paul", "initiale": "P", "farbe": Color("ffb070"),
		"kurz": "Zum Spaß: Wirtschaft und Aufträge.",
		"perks": ["Aufträge: Bonus für erfüllte Aufgaben", "Zinsen bis 100, Prämien ×1,5", "Abriss gibt immer 100 % zurück"],
		"nachteile": ["10 statt 15 Leben, Erdwälle kosten 15", "Manche Aufträge tun weh", "Zählt nicht für Rangliste und Phantome"],
		"erfolg": "deutscher_sparer", "rangliste": false},
]


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
