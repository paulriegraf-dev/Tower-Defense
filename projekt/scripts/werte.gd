class_name Werte
extends RefCounted
## Alle Stellschrauben des Prototyps an einer Stelle.
## Hier Zahlen ändern, speichern, in Godot F5 drücken.

# --- Karte -------------------------------------------------------------
const ZELLE: int = 64              # Kantenlänge eines Felds in Pixeln
const SPALTEN: int = 20
const ZEILEN: int = 10
const KARTE_OBEN: int = 40         # Platz für die Leiste oben
const START_ZELLE := Vector2i(0, 4)    # HQ des Gegners; Mitte seiner Zone

# --- Zone des Gegners und letzte Runde -------------------------------------
# Die linken Spalten gehören dem Gegner: dort kann nicht gebaut werden, Gegner kommen verteilt über die ganze Höhe heraus.
# Bis zur letzten Runde liegt ein Schutzschild darüber: Was in der Zone steht, kann nicht beschossen werden.
const ZONE_SPALTEN: int = 3
const HQ_LEBEN: float = 4000.0
const ANGRIFFS_ZELLE := Vector2i(1, 4) # dorthin marschieren die eigenen Truppen in der letzten Runde (Feld vor dem HQ)
const LETZTE_RUNDE: int = 15           # ab dieser Runde: Gegenangriff. Gegner kommen ohne Ende, Sieg = HQ zerstört
const ENDKAMPF_TRUPP_PAUSE: float = 1.0    # Sekunden zwischen zwei Trupps in der letzten Runde (sonst TRUPP_PAUSE)
const ENDKAMPF_PAUSE: float = 3.0     # Sekunden, bis in der letzten Runde die nächste Reihe Trupps beginnt
const ENDKAMPF_WIE_WELLE: int = 9      # Stärke und Zusammensetzung der Trupps in der letzten Runde
# Schleudern stehen in der Zone und werfen auf Truppen in Stellungen und auf Fabriken in Reichweite.
# art: "schleuder" wirft Steine auf Stellungen und Fabriken, "wurf" wirft Hunde über die ersten Wälle,
#      "laser" schießt flach auf Bodentruppen (Wälle geben Deckung).
const ZONENBAUTEN: Array = [
	{"art": "schleuder", "zelle": Vector2i(1, 2), "ab_welle": 5},
	{"art": "schleuder", "zelle": Vector2i(1, 7), "ab_welle": 8},
	{"art": "wurf", "zelle": Vector2i(0, 7), "ab_welle": 10},
	{"art": "wurf", "zelle": Vector2i(0, 2), "ab_welle": 13},
	{"art": "laser", "zelle": Vector2i(2, 2), "ab_welle": 15},   # Laser gibt es nur zur Verteidigung in der letzten Runde
	{"art": "laser", "zelle": Vector2i(2, 5), "ab_welle": 15},
	{"art": "laser", "zelle": Vector2i(2, 7), "ab_welle": 15},
]
# Stein-Schleudern wechseln ihren Platz: vor jeder Runde (sichtbar in der Bauphase) und alle paar Sekunden während der Runde.
const SCHLEUDER_PLAETZE: Array[Vector2i] = [Vector2i(1, 0), Vector2i(1, 1), Vector2i(1, 2), Vector2i(1, 3), Vector2i(1, 6), Vector2i(1, 7), Vector2i(1, 8), Vector2i(1, 9)]
const SCHLEUDER_UMZUG_SEK: float = 20.0
const SCHLEUDER_TEMPO: float = 0.8     # Felder pro Sekunde beim Umziehen (dabei wirft sie nicht)
const WURF := {
	"reichweite": 6.0,          # so weit (Felder) fliegt ein geworfener Hund höchstens
	"abklingzeit": 7.0,
	"wartet": 10.0,             # so lange (Sekunden nach Rundenbeginn) hält sie sich zurück, bis die eigenen Truppen vorgerückt sind
	"flugzeit": 1.5,
	"rudel": 4,                 # so viele Hunde wirft sie kurz hintereinander an dieselbe Stelle
	"abstand": 0.25,            # Sekunden zwischen zwei Würfen eines Rudels
}
const LASER := {
	"blatt": "res://assets/sprites/laser.webp",
	"zelle": 64,
	"bilder": [9, 13, 17],
	"angriff_dauer": 2.4,
	"massstab": 1.0,
	"leben": 250.0,
	"reichweite": 5.0,
	"schaden": 12.0,
	"abklingzeit": 1.0,
}

# --- Sonderregeln der Gegner ----------------------------------------------------
const RAUCH_RADIUS: float = 2.0        # Felder
const RAUCH_SEK: float = 5.0           # so lange können Truppen im Rauch nicht schießen (Türme schon)
const ANDOCK_SEK: float = 3.0          # so lange braucht ein Belagerungsturm am Wall, bevor Truppen herausspringen
const ENTERER_JE_TURM: int = 4
const ENTERER_ABSTAND: float = 2.0     # Sekunden zwischen zwei Turmtruppen
const FAHNE_EINNAHME_FAKTOR: float = 2.0   # Fahnenträger nehmen Checkpoints so viel schneller ein
const SPRENGER_AB_WELLE: int = 8       # ab hier wird die Schwachstelle in der Bauphase markiert
const SPRENGER_WEG_GEWICHT: float = 0.3   # so stark zählt der Anmarsch: Abkürzung minus Gewicht x Weglänge. 0 = immer der Wall mit der größten Abkürzung
const SPRENGER_MIN_WEG: int = 10          # Erdwälle, die der Sprenger in weniger Schritten erreicht, lässt er aus: die vorderste Front bleibt stehen, und die Verteidigung hat Zeit zum Schießen

# Ansage in der Bauphase vor der Runde, in der etwas zum ersten Mal auftritt.
const NEUHEITEN := {
	3: "Neu: Battlesphäre. Fernkämpfer, schießt im Laufen auf Truppen in Stellungen und sichtbare Bodentruppen.",
	5: "Neu: Checkpoints (Fahnen) und eine Schleuder in der Zone. Der Gegnerweg führt durch beide Fahnen. Die Schleuder wirft auf Stellungen und Fabriken im pinken Kreis.",
	6: "Neu: Fahnenträger. Sein Trupp stürmt in seinem Tempo, er kämpft nicht und nimmt Checkpoints doppelt so schnell ein. Fällt er, wird der Trupp langsam.",
	8: "Neu: Sprenger. Sie kommen als Erste und sprengen nacheinander die Erdwälle, deren Wegfall die größte Abkürzung bringt (orange markiert). Erdwälle mit Turm sind sicher. Dazu eine zweite Schleuder; beide wechseln ab jetzt ihren Platz.",
	10: "Neu in der Zone: Wurf-Schleuder. Sie wirft ein ganzes Rudel Hunde über die ersten Wälle (oranger Kreis). Ab Runde 13 steht dort eine zweite.",
	11: "Neu: Rauchwerfer. Sein Rauch nimmt Truppen für einige Sekunden die Sicht – am liebsten dort, wo viele Stellungen beieinander liegen. Türme schießen weiter.",
	12: "Neu: Belagerungsturm. Er fährt zum Wallstück mit den meisten Stellungen und dockt an. Seine Truppen laufen auf den Wällen und greifen Stellungen im Nahkampf an.",
}
const SCHLEUDER := {
	"blatt": "res://assets/sprites/schleuder.webp",
	"zelle": 64,
	"bilder": [9, 13, 17],
	"angriff_dauer": 2.8,
	"massstab": 1.1,
	"leben": 250.0,
	"reichweite": 7.0,
	"abklingzeit": 6.0,
	"flugzeit": 1.3,
	"schaden_einheit": 35.0,
	"schaden_fabrik": 60.0,
}
const BASIS_ZELLE := Vector2i(19, 5)   # hier wollen sie hin

# --- Checkpoints ---------------------------------------------------------
# Der Gegnerweg führt der Reihe nach durch alle Checkpoints. Gegner bleiben auf einem Checkpoint stehen, bis sie ihn
# eingenommen haben; danach gehört er dem Gegner, und die nächste Welle startet dort. Eigene Bodentruppen holen ihn zurück, indem sie darauf stehen bleiben –
# das geht nur, solange die Welle läuft.
# Halb zufällig: Jeder Checkpoint liegt in jeder Partie auf einem zufälligen Feld seines Bereichs
# (Rect2i = linke obere Ecke x, y und Breite, Höhe in Feldern). Die Felder stehen ab Runde 1 fest und sind sichtbar.
const CHECKPOINT_BEREICHE: Array[Rect2i] = [Rect2i(5, 1, 4, 8), Rect2i(11, 1, 5, 8)]
const CHECKPOINTS_ZUFAELLIG: bool = true   # false = immer die festen Felder der nächsten Zeile
const CHECKPOINTS: Array[Vector2i] = [Vector2i(6, 4), Vector2i(13, 5)]
const CHECKPOINTS_AB_WELLE: int = 5    # vorher sind die Felder nur freigehalten (nicht bebaubar)
const EINNAHME_SEK: float = 3.0        # so lange muss der Gegner einen Checkpoint halten
const CHECKPOINT_RUHE: float = 1.5     # die zugeteilte Truppe geht einen Checkpoint zurückholen, solange in diesem Umkreis (Felder) kein Gegner ist
const RUECKEROBERUNG_SEK: float = 4.0  # so lange muss eine Bodentruppe den Checkpoint halten
const NACHSPIEL_MAX: float = 15.0     # so lange läuft die Runde nach dem letzten Gegner höchstens weiter, damit die zugeteilte Truppe den Checkpoint zurückholt
const STELLUNG_BAU_RUHE: float = 2.0   # während der Welle: Stellung nur bauen, wenn in diesem Umkreis (Felder) kein Gegner ist

# --- Tempo -------------------------------------------------------------
const SPIELTEMPO: float = 0.7      # 1.0 = volle Geschwindigkeit; gilt für alles (Laufen, Schießen, Produktion)
const TRUPP_PAUSE: float = 3.0     # Sekunden zwischen zwei Trupps einer Welle

# --- Wirtschaft --------------------------------------------------------
const START_BUDGET: int = 120
const START_LEBEN: int = 15
const KOSTEN_FABRIK: int = 50      # die erste Fabrik
const KOSTEN_FABRIK_ZUWACHS: int = 15  # jede weitere Fabrik kostet so viel mehr als die vorige
const ERSTATTUNG: float = 0.75     # Anteil des Preises, den es beim Abreißen zurückgibt
const KOSTEN_WALL: int = 10
const KOSTEN_STELLUNG: int = 25    # Ausbau eines Erdwalls: Platz für eine Einheit
const KOSTEN_TURM: int = 75        # Ausbau eines Erdwalls an einer Kreuzung
const KOSTEN_BATTERIE: int = 150   # Railgun-Batterie: feuert erst, wenn sie voll bemannt ist
const WAELLE_AB_WELLE: int = 2     # Runde 1: nur Fabriken, danach Erdwälle
# Einkommen nach dem Muster von Bloons TD 6: Der feste Bonus am Rundenende ist der größere, planbare Teil,
# Prämien für besiegte Gegner kommen obendrauf.
const BONUS_JE_WELLE: int = 100    # Budget nach jeder überstandenen Welle
const BONUS_JE_CHECKPOINT: int = 0     # zusätzlich je Checkpoint, der am Rundenende dir gehört (0 = aus)
# Zinsen wie in Teamfight Tactics: Für je ZINS_SCHRITT Budget, das am Rundenende noch da ist, gibt es ZINS_JE_SCHRITT dazu.
const ZINS_SCHRITT: int = 100
const ZINS_JE_SCHRITT: int = 10
const ZINS_STUFEN: int = 5         # höchstens so viele Schritte zählen (also höchstens 50 Zinsen)
const BONUS_ZUWACHS: int = 5       # ... plus so viel je Wellennummer

# --- Gebäude -----------------------------------------------------------
const LEBEN_WALL: float = 120.0
const LEBEN_FABRIK: float = 300.0
const PRODUKTION_SEK: float = 5.0  # Sekunden je Einheit
const MAX_JE_FABRIK: int = 3       # so viele Einheiten hält eine Fabrik am Leben
const MAX_JE_FABRIK_ENDKAMPF: int = 5  # ... und so viele in der letzten Runde
const FABRIK_EINHEITEN: Array[String] = ["technogunner", "scharfschuetze", "plasmawerfer", "pilot"]  # Klick auf die Fabrik wechselt

# --- Railgun-Batterie ------------------------------------------------------
# Eigenes Gebäude am Boden (versperrt den Weg wie eine Fabrik). Nur Piloten bemannen sie – immer den nächsten
# freien Platz nach Fußweg. Sie feuert nur, solange alle Plätze besetzt sind.
const BATTERIE := {
	"blatt": "res://assets/sprites/batterie.png",
	"zelle": 48,
	"plaetze": 3,
	"leben": 300.0,
	"reichweite": 8.0,          # weit, über Wälle hinweg
	"flaeche": 1.5,             # Radius des Einschlags in Feldern
	"schaden": 45.0,
	"abklingzeit": 4.0,
}

# --- Weg zur Stellung ------------------------------------------------------
const GEFAHR_RADIUS: float = 2.0   # Felder: Truppen auf dem Weg zu Stellung/Batterie meiden Felder so nah an Gegnern

# --- Stellungen und Türme ------------------------------------------------
const POSTEN_REICHWEITE_BONUS: float = 1.0 # Extra-Reichweite von oben, falls eine Einheit keinen eigenen Wert hat ("stellung_bonus")
const TURM_NACHBARN: int = 3               # so viele angrenzende Erdwälle braucht ein Turm (T-Stück oder Kreuzung)
const TURM := {
	"reichweite": 3.5,
	"schaden": 16.0,
	"abklingzeit": 0.9,
}

# --- Einheiten (eigene) --------------------------------------------------
# tempo = Felder pro Sekunde, reichweite = Felder
# blatt = Animationsblatt aus Terrain-Conquester: Zeilen Stehen / Laufen / Angriff
const EINHEITEN := {
	"technogunner": {
		"name": "Technogunner",
		"blatt": "res://assets/sprites/technogunner.png",
		"zelle": 48,                # Pixel je Bild im Blatt
		"bilder": [4, 8, 9],        # Bilder je Zeile
		"angriff_dauer": 1.4,       # Sekunden (wird auf die Abklingzeit gekürzt)
		"massstab": 2.0,
		"schussfarbe": "7fe0ff",
		"leben": 60.0,
		"tempo": 1.6,
		"reichweite": 3.0,
		"schaden": 8.0,
		"abklingzeit": 0.6,
	},
	"plasmawerfer": {
		"name": "Plasmawerfer",
		"blatt": "res://assets/sprites/plasmawerfer.png",
		"zelle": 48,
		"bilder": [4, 8, 9],
		"angriff_dauer": 1.4,
		"massstab": 2.0,
		"schussfarbe": "ff8ad8",
		"leben": 70.0,
		"tempo": 1.4,
		"reichweite": 2.6,
		"stellung_bonus": 0.0,      # Plasma fliegt von oben nicht weiter: in der Stellung nur der Schuss über Wälle
		"schaden": 13.0,
		"flaeche": 1.2,             # trifft alle Gegner in diesem Radius (Felder) um das Ziel
		"abklingzeit": 1.4,
	},
	"pilot": {
		"name": "Pilot",
		"pilot": true,              # kämpft nicht, bemannt Batterien
		"info": "Pilot: kämpft nicht. Bemannt die nächste Batterie mit freiem Platz und wartet sonst an der Fabrik.",
		"blatt": "res://assets/sprites/pilot.png",
		"zelle": 48,
		"bilder": [4, 8, 9],
		"angriff_dauer": 1.6,
		"massstab": 2.0,
		"schussfarbe": "7fe0ff",
		"leben": 50.0,
		"tempo": 1.5,
		"reichweite": 0.0,
		"schaden": 0.0,
		"abklingzeit": 1.0,
	},
	"scharfschuetze": {
		"name": "Scharfschütze",
		"blatt": "res://assets/sprites/scharfschuetze.png",
		"zelle": 48,
		"bilder": [4, 8, 9],
		"angriff_dauer": 1.4,
		"massstab": 2.0,
		"schussfarbe": "9dff8a",
		"leben": 40.0,
		"tempo": 1.3,
		"reichweite": 5.0,
		"stellung_bonus": 1.5,      # der Scharfschütze profitiert am meisten von der Höhe
		"schaden": 30.0,
		"abklingzeit": 2.2,
	},
}

# --- Gegner --------------------------------------------------------------
# wall_kosten: Ein Wall "kostet" den Gegner so viel wie so viele Felder Umweg. 1000 = praktisch nie: eingerissen wird nur, wenn es gar keinen Weg mehr gibt.
# Ist der Umweg länger (oder gibt es keinen Weg), reißt er den Wall ein.
# fernkampf: schießt auf Truppen in Stellungen und auf sichtbare Bodentruppen (Türme sind vorerst unangreifbar).
const GEGNER := {
	"hund": {
		"name": "Hund",
		"kurz": "Hund",
		"art": "Nahkampf",
		"rolle": "",
		"fernkampf": false,
		"blatt": "res://assets/sprites/hund.webp",
		"zelle": 48,
		"bilder": [9, 13, 17],
		"angriff_dauer": 2.2,
		"massstab": 1.4,            # feine Figur auf 70 %
		"leben": 40.0,
		"tempo": 1.8,
		"reichweite": 1.1,
		"schaden": 10.0,
		"abklingzeit": 0.8,
		"wall_kosten": 1000.0,
		"fabrik_kosten": 2000.0,
		"praemie": 2,
	},
	"sphaere": {
		"name": "Battlesphäre",
		"kurz": "Sphäre",
		"art": "Fernkampf",
		"rolle": "",
		"fernkampf": true,
		"blatt": "res://assets/sprites/sphaere.webp",
		"zelle": 64,
		"bilder": [9, 13, 17],
		"angriff_dauer": 2.4,
		"massstab": 1.1,
		"leben": 110.0,
		"tempo": 1.0,
		"reichweite": 3.5,
		"schaden": 14.0,
		"abklingzeit": 1.6,
		"wall_kosten": 1000.0,
		"fabrik_kosten": 2000.0,
		"praemie": 8,
	},
	# rolle = Sonderregel (siehe gegner.gd). schaden 0 = kämpft nicht selbst.
	"fahne": {
		"name": "Fahnenträger", "kurz": "Fahne", "art": "führt den Trupp", "rolle": "fahne", "fernkampf": false,
		"blatt": "res://assets/sprites/fahnentraeger.webp", "zelle": 64, "bilder": [9, 13, 17], "angriff_dauer": 1.8, "massstab": 1.1,
		"leben": 135.0, "tempo": 2.3, "reichweite": 0.0, "schaden": 0.0, "abklingzeit": 1.0,
		"wall_kosten": 1000.0, "fabrik_kosten": 2000.0, "praemie": 8,
	},
	"sprenger": {
		"name": "Sprenger", "kurz": "Sprenger", "art": "sprengt Erdwälle", "rolle": "sprenger", "fernkampf": false,
		"blatt": "res://assets/sprites/sprenger.webp", "zelle": 48, "bilder": [9, 13, 17], "angriff_dauer": 2.2, "massstab": 1.3,
		"leben": 45.0, "tempo": 1.5, "reichweite": 0.0, "schaden": 0.0, "abklingzeit": 1.0,
		"wall_kosten": 1000.0, "fabrik_kosten": 2000.0, "praemie": 6,
	},
	"rauch": {
		"name": "Rauchwerfer", "kurz": "Rauch", "art": "nimmt die Sicht", "rolle": "rauch", "fernkampf": false,
		"blatt": "res://assets/sprites/rauchwerfer.webp", "zelle": 64, "bilder": [9, 13, 17], "angriff_dauer": 2.6, "massstab": 1.1,
		"leben": 80.0, "tempo": 1.0, "reichweite": 5.0, "schaden": 0.0, "abklingzeit": 9.0,
		"wall_kosten": 1000.0, "fabrik_kosten": 2000.0, "praemie": 8,
	},
	"belagerung": {
		"name": "Belagerungsturm", "kurz": "Bel.-Turm", "art": "entert Wälle", "rolle": "belagerung", "fernkampf": false,
		"blatt": "res://assets/sprites/belagerungsturm.webp", "zelle": 64, "bilder": [9, 13, 17], "angriff_dauer": 2.6, "massstab": 1.4,
		"leben": 450.0, "tempo": 0.6, "reichweite": 0.0, "schaden": 0.0, "abklingzeit": 1.0,
		"wall_kosten": 1000.0, "fabrik_kosten": 2000.0, "praemie": 15,
	},
	"enterer": {
		"name": "Turmtruppe", "kurz": "Turmtruppe", "art": "Nahkampf auf Wällen", "rolle": "enterer", "fernkampf": false,
		"blatt": "res://assets/sprites/enterer.webp", "zelle": 48, "bilder": [9, 9, 9], "angriff_dauer": 0.9, "massstab": 1.2,
		"leben": 35.0, "tempo": 1.6, "reichweite": 1.1, "schaden": 10.0, "abklingzeit": 0.8,
		"wall_kosten": 1000.0, "fabrik_kosten": 2000.0, "praemie": 2,
	},
}


## Entworfene Runden: Zusammensetzung der Welle Nummer `nr` (ab 1).
## Ein Trupp läuft gemeinsam im Tempo seines langsamsten Mitglieds – außer ein Fahnenträger führt ihn an.
static func welle(nr: int) -> Dictionary:
	var hunde := 4 + 2 * nr
	var sphaeren := int((nr - 1) / 2.0) if nr >= 3 else 0   # Runde 3: 1, Runde 5: 2, Runde 7: 3 ...
	var fahnen := 0 if nr < 6 else (1 if nr < 11 else 2)
	var sprenger := 0 if nr < 8 else (2 if nr < 12 else 3)
	var rauch := 0 if nr < 11 else 1
	var belagerung := 0 if nr < 12 else (1 if nr < 14 else 2)

	var rest := hunde
	var sturm: Array = []      # Fahnenträger + 4 Hunde
	for i in fahnen:
		var trupp: Array = ["fahne"]
		for j in mini(4, rest):
			trupp.append("hund")
		rest -= trupp.size() - 1
		sturm.append(trupp)
	var gemischt: Array = []   # 3 Hunde als Vorhut + Battlesphäre (+ Rauchwerfer)
	for i in sphaeren:
		var trupp: Array = []
		for j in mini(3, rest):
			trupp.append("hund")
		rest -= trupp.size()
		trupp.append("sphaere")
		if i < rauch:
			trupp.append("rauch")
		gemischt.append(trupp)
	var rudel: Array = []      # der Rest: Rudel zu je 5 Hunden
	while rest > 0:
		var trupp: Array = []
		for j in mini(5, rest):
			trupp.append("hund")
		rest -= trupp.size()
		rudel.append(trupp)
	var vorhut: Array = []     # Sprenger kommen gemeinsam als Erste und öffnen den Weg für alle danach
	if sprenger > 0:
		var trupp: Array = []
		for i in sprenger:
			trupp.append("sprenger")
		vorhut.append(trupp)
	var einzeln: Array = []    # Belagerungstürme kommen allein
	for i in belagerung:
		einzeln.append(["belagerung"])

	# Reihenfolge: zuerst die Sprenger, dann reihum Rudel, Sturmtrupp, gemischter Trupp, Einzelgänger ...
	var trupps: Array = []
	var listen: Array = [vorhut, rudel, sturm, gemischt, einzeln]
	var uebrig := true
	while uebrig:
		uebrig = false
		for liste: Array in listen:
			if not liste.is_empty():
				trupps.append(liste.pop_front())
				uebrig = true

	# Zählung je Typ für die Wellenvorschau
	var anzahl := {}
	for trupp: Array in trupps:
		for typ: String in trupp:
			anzahl[typ] = int(anzahl.get(typ, 0)) + 1
	var gruppen: Array = []
	for typ: String in anzahl:
		gruppen.append({"typ": typ, "anzahl": anzahl[typ]})
	return {
		"gruppen": gruppen,
		"trupps": trupps,
		"leben_faktor": 1.0 + 0.3 * (nr - 1),
		"abstand": 0.7,            # Sekunden zwischen zwei Gegnern
	}


## Extra-Reichweite einer Einheit in der Stellung (je Einheit verschieden).
static func stellung_bonus(daten: Dictionary) -> float:
	return daten.get("stellung_bonus", POSTEN_REICHWEITE_BONUS)


static func zinsen(budget: int) -> int:
	return mini(int(budget / float(ZINS_SCHRITT)), ZINS_STUFEN) * ZINS_JE_SCHRITT


static func wellen_bonus(nr: int) -> int:
	return BONUS_JE_WELLE + BONUS_ZUWACHS * nr
