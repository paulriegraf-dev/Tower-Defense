class_name Werte
extends RefCounted
## Alle Stellschrauben des Prototyps an einer Stelle.
## Hier Zahlen ändern, speichern, in Godot F5 drücken.

# --- Karte -------------------------------------------------------------
const ZELLE: int = 64              # Kantenlänge eines Felds in Pixeln
# Kartengröße (16.11.): "Normal" 20×10 wie bisher oder "Groß" 28×14 (Startmenü, gespeichert in user://einstellungen.cfg).
# Alle Felder unten, die von der Größe abhängen, sind deshalb static var und werden in setze_karte() umgerechnet.
# Auf der großen Karte schwenkt die Kamera auch in der 2D-Ansicht (kamera_2d.gd). Balance ist auf "Normal" abgestimmt.
static var karte_gross := true   # 16.11.: nur noch die große Karte
static var KARTE_FAKTOR := 1.0         # Verhältnis Breite groß/normal (für Abstände)
static var SPALTEN: int = 20
static var ZEILEN: int = 10
const KARTE_OBEN: int = 40         # Platz für die Leiste oben
static var START_ZELLE := Vector2i(0, 4)    # HQ des Gegners; Mitte seiner Zone

# --- Zone des Gegners und letzte Runde -------------------------------------
# Die linken Spalten gehören dem Gegner: dort kann nicht gebaut werden, Gegner kommen verteilt über die ganze Höhe heraus.
# Bis zur letzten Runde liegt ein Schutzschild darüber: Was in der Zone steht, kann nicht beschossen werden.
const ZONE_SPALTEN: int = 3
const HQ_LEBEN: float = 1500.0   # 15.11.: vorher 2200 (Runde 20 war kaum zu gewinnen)
static var ANGRIFFS_ZELLE := Vector2i(1, 4) # dorthin marschieren die eigenen Truppen in der letzten Runde (Feld vor dem HQ)
const LETZTE_RUNDE: int = 20           # ab dieser Runde: Gegenangriff. Gegner kommen ohne Ende, Sieg = HQ zerstört
const ENDKAMPF_TRUPP_PAUSE: float = 2.0    # 18.11.: vorher 1,0 – weniger gebündelt; Sekunden zwischen zwei Trupps in der letzten Runde (sonst TRUPP_PAUSE)
const ENDKAMPF_PAUSE: float = 6.0     # 15.11.: vorher 3 – Sekunden, bis in der letzten Runde die nächste Reihe Trupps beginnt
const ENDKAMPF_LEBEN: float = 2.2      # 18.11.: vorher 2,6 (15.11.: 3,4) – Leben-Faktor der Gegner in der letzten Runde (sie kommen in Schleife)
const LEBEN_JE_RUNDE: float = 0.20     # so viel zäher werden die Gegner je Runde (Runde 19: ×4,6); Patch 16.11.: vorher 0,23 (×5,1)
const GEGNER_GRUND_LEBEN: float = 10.0  # ab GRUND_LEBEN_AB_RUNDE bekommt jeder Gegner so viel Leben dazu, vor dem Rundenfaktor (gegen zu starken Flächenschaden; hilft vor allem den kleinen). 15.11.: 20 ab R1 war zu hart
const GRUND_LEBEN_AB_RUNDE: int = 6
# Schleudern stehen in der Zone und werfen auf Truppen in Stellungen und auf Fabriken in Reichweite.
# art: "schleuder" wirft Steine auf Stellungen und Fabriken, "wurf" wirft Hunde über die ersten Wälle,
#      "laser" schießt flach auf Bodentruppen (Wälle geben Deckung).
static var ZONENBAUTEN: Array = [
	{"art": "schleuder", "zelle": Vector2i(1, 2), "ab_welle": 5},
	{"art": "schleuder", "zelle": Vector2i(1, 7), "ab_welle": 8},
	{"art": "wurf", "zelle": Vector2i(0, 7), "ab_welle": 10},
	{"art": "wurf", "zelle": Vector2i(0, 2), "ab_welle": 14},
	{"art": "laser", "zelle": Vector2i(2, 2), "ab_welle": 20},   # Laser gibt es nur zur Verteidigung in der letzten Runde
	{"art": "laser", "zelle": Vector2i(2, 5), "ab_welle": 20},
	{"art": "laser", "zelle": Vector2i(2, 7), "ab_welle": 20},
]
# Stein-Schleudern wechseln ihren Platz: vor jeder Runde (sichtbar in der Bauphase) und alle paar Sekunden während der Runde.
static var SCHLEUDER_PLAETZE: Array[Vector2i] = [Vector2i(1, 0), Vector2i(1, 1), Vector2i(1, 2), Vector2i(1, 3), Vector2i(1, 6), Vector2i(1, 7), Vector2i(1, 8), Vector2i(1, 9)]
const SCHLEUDER_UMZUG_SEK: float = 20.0
const SCHLEUDER_TEMPO: float = 0.8     # Felder pro Sekunde beim Umziehen (dabei wirft sie nicht)
const WURF := {
	"reichweite": 6.0,          # so weit (Felder) fliegt ein geworfener Hund höchstens
	"abklingzeit": 7.0,
	"wartet": 10.0,             # so lange (Sekunden nach Rundenbeginn) hält sie sich zurück, bis die eigenen Truppen vorgerückt sind
	"flugzeit": 1.5,
	"rudel": 4,                 # so viele Gegner wirft sie kurz hintereinander an dieselbe Stelle
	"abstand": 0.25,            # Sekunden zwischen zwei Würfen eines Rudels
	"weit": 10.0,               # so weit (Felder) darf ein Angreifer im Phantom-Modus sein Wurfziel wählen
	"tasche_weit": 8.0,         # ohne echte Mauer wirft sie von selbst höchstens so weit – in Taschen zwischen Erdwällen
}
const SCHLEUDER_ABWURF: float = 0.45   # Optik: so lange holt der Arm aus, bevor der Stein fliegt (Landezeit bleibt gleich)
const WURF_FARBE := Color(0.6, 0.85, 1.25)   # Wurf-Schleuder: kühl eingefärbt, damit sie sich von der Stein-Schleuder abhebt
const WURF_MAUER_MIN: float = 8.0      # ab so viel Umweg (Schritte) hinter einer Wallgruppe gilt sie als Mauer, die überworfen wird
const WURF_MAUER_EXTRA: float = 15.0   # ab so viel Umweg wirft die Schleuder zusätzlich ein Rudel Hunde je Welle
const NEBEL_SICHT: float = 2.5          # Phantom-Modus: so weit (Felder) sieht eine Einheit des Angreifers durch den Kriegsnebel
const WURF_TASCHE_MIN_ERSPART: float = 3.0   # ein Taschenwurf muss den Gegnern mindestens so viele Schritte Weg ersparen (sonst landet er vor der Mauer)
const WURF_CP_BONUS: float = 5.0       # Landefelder nahe einem Checkpoint, den der Gegner noch nicht hält, zählen so viel mehr
const WURF_BELAGERUNG_ABSTAND: float = 5.0  # dockt ein Belagerungsturm an, landet der nächste Wurf mindestens so weit (Felder) von ihm weg
const WELLEN_VARIANTEN_AB: int = 99    # Varianten sind abgeschaltet: jede Runde hat jetzt einen festen Plan (WELLEN)

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
const RAUCH_RADIUS: float = 3.0        # Felder (17.11. abends: 2 → 3, die Karte ist größer)
const RAUCH_SEK: float = 5.0           # so lange können Truppen im Rauch nicht schießen (Türme schon)
const ANDOCK_SEK: float = 3.0          # so lange braucht ein Belagerungsturm am Wall, bevor Truppen herausspringen
const ANDOCK_NAH: int = 3            # Belagerungsturm dockt am liebsten dort an, wo eine Stellung/ein Turm höchstens so viele Wallschritte entfernt ist (außerhalb der Zone, am schnellsten erreichbar)
const ENTERER_ABSTAND: float = 4.0     # Sekunden zwischen zwei Myr-Drohnen – sie kommen nach, solange der Turm steht
const ENTERER_GLEICHZEITIG: int = 4    # mehr Myr-Drohnen eines Turms sind nie zugleich unterwegs
const BELAGERUNG_SEK: float = 40.0     # so lange hält ein angedockter Belagerungsturm höchstens durch, dann zerfällt er
const ENTERER_LEERLAUF_SEK: float = 3.0 # findet eine Myr-Drohne so lange kein Ziel auf dem Wall, springt sie ab
const ENDKAMPF_ABSTAND: float = 1.5      # letzte Runde: erst wenn ein Gegner näher ist (Felder), bleiben vorrückende Truppen stehen
const WURF_SPRENGER_AB_WELLE: int = 12 # ab hier wird ein Sprenger der Welle von der Wurf-Schleuder geworfen
const FAHNE_EINNAHME_FAKTOR: float = 2.0   # Fahnenträger nehmen Checkpoints so viel schneller ein
const FAHNE_SPUR_SEK: float = 3.0          # so lange bleibt die Spur eines Fahnenträgers liegen
const FAHNE_SPUR_RADIUS: float = 1.3       # Gegner in diesem Umkreis (Felder) um die Spur bekommen den Fahnen-Bonus
const FAHNE_BONUS: float = 1.3             # Fahnenträger im Trupp oder Fahnenspur: so viel schneller als das eigene Tempo
const SPRENGER_AB_WELLE: int = 8       # ab hier kommen Sprenger (und die Schleudern wechseln den Platz)
const SPRENGER_WEG_GEWICHT: float = 0.3   # so stark zählt der Anmarsch: Abkürzung minus Gewicht x Weglänge. 0 = immer der Wall mit der größten Abkürzung
const SPRENGER_TIEFE: int = 4              # so viele Erdwälle hintereinander reißt eine Sprengung höchstens mit (in gerader Linie; ein Turm stoppt sie)
const SPRENGER_ZUENDZEIT: float = 1.7     # so lange (Sekunden) steht der Sprenger zündend an seinem Ziel; fällt er vorher, gibt es keine Sprengung
const SPRENGER_MIN_WEG: int = 6           # Erdwälle, die der Sprenger in weniger Schritten erreicht, lässt er aus: die vorderste Front bleibt stehen, und die Verteidigung hat Zeit zum Schießen

# Ansage in der Bauphase vor der Runde, in der etwas zum ersten Mal auftritt.
const NEUHEITEN := {
	3: "Neu: Battlesphäre. Fernkämpfer, schießt im Laufen auf Truppen in Stellungen und sichtbare Bodentruppen.",
	5: "Neu: Ab jetzt nehmen die Gegner die Checkpoints (Fahnen) ein, und in der Zone steht eine Schleuder. Die Schleuder wirft auf Stellungen und Fabriken im pinken Kreis.",
	6: "Neu: Fahnenträger. Er macht die anderen in seinem Trupp 30 % schneller (selbst läuft er ohne Bonus), kämpft nicht und nimmt Checkpoints doppelt so schnell ein. Fällt er, wird der Trupp wieder langsam.",
	8: "Neu: Sprenger. Sie kommen als Erste und sprengen nacheinander die Erdwälle, deren Wegfall eine große Abkürzung bringt. Dicke Riegel aus blanken Erdwällen fallen bis zu 4 Felder tief, sonst nur das getroffene Feld; Türme halten stand. Welche Wälle es trifft, siehst du erst in der Welle (Ziel blinkt). Dazu eine zweite Schleuder; beide wechseln ab jetzt ihren Platz.",
	10: "Neu in der Zone: Wurf-Schleuder. Sie wirft ein ganzes Rudel Hunde über die ersten Wälle (oranger Kreis). Ab Runde 13 steht dort eine zweite.",
	11: "Neu: Rauchwerfer. Sein Rauch nimmt Truppen für einige Sekunden die Sicht – am liebsten dort, wo viele Stellungen beieinander liegen. Türme schießen weiter.",
	9: "Neu: Schildträger. Sein Schild hält alles von vorn ab (nur 25 % Schaden) – Fläche und Strahlen auch für die, die direkt hinter ihm gehen. Truppen und Türme nehmen ihn zuerst ins Visier. Von der Seite und von hinten trifft alles voll.",
	14: "Neu: Sanitäter. Er kämpft nicht, heilt aber alle 1,5 Sekunden die Gegner um sich herum. Zuerst ausschalten!",
	12: "Neu: Schwarmgeist. Zäh und langsam – fällt er, zerfällt er in drei Myr-Drohnen.",
	13: "Neu: Belagerungsturm. Er dockt am ersten erreichbaren Erdwall nach der Zone an, an dem Stellungen oder Türme in der Nähe sind. Seine Truppen laufen auf den Wällen und greifen Stellungen im Nahkampf an.",
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
	"schaden_haufen": 22.0,     # Flächentreffer auf einen Haufen Bodentruppen (jede Truppe im Umkreis)
	"schaden_fabrik": 60.0,
}
static var AUSGAENGE := {"": Vector2i(0, 4), "oben": Vector2i(1, 1), "unten": Vector2i(1, 8)}   # Phantom-Modus: hier kommt ein Trupp geschlossen aus der Zone
static var BASIS_ZELLE := Vector2i(18, 5)   # hier wollen sie hin (fester Platz: Tests, alte Partien, Sandbox „fest“)
const BASIS_ZUFALL: bool = true        # normales Spiel: Die Basis steht jede Partie woanders (mindestens 8 Felder vom HQ, 3 von den Checkpoints)
const CP_ROUTE_AB_START: bool = true   # der Gegnerweg führt schon ab Runde 1 durch die Checkpoints (eingenommen werden sie erst ab CHECKPOINTS_AB_WELLE)
const STARTPAKET_WAELLE: int = 8       # so viele Erdwälle gibt es gratis, sobald sie freigeschaltet werden (Runde 2)

# --- Checkpoints ---------------------------------------------------------
# Der Gegnerweg führt der Reihe nach durch alle Checkpoints. Gegner bleiben auf einem Checkpoint stehen, bis sie ihn
# eingenommen haben; danach gehört er dem Gegner, und die nächste Welle startet dort. Eigene Bodentruppen holen ihn zurück, indem sie darauf stehen bleiben –
# das geht nur, solange die Welle läuft.
# Halb zufällig: Jeder Checkpoint liegt in jeder Partie auf einem zufälligen Feld seines Bereichs
# (Rect2i = linke obere Ecke x, y und Breite, Höhe in Feldern). Die Felder stehen ab Runde 1 fest und sind sichtbar.
static var CHECKPOINT_BEREICHE: Array[Rect2i] = [Rect2i(5, 1, 4, 8), Rect2i(11, 1, 5, 8)]
const CP_ABSTAND_ZUEINANDER: float = 3.0   # Felder zwischen den beiden Checkpoints (mindestens)
const CP_ABSTAND_SPAWN: float = 5.0        # Felder vom Gegner-Spawn (mindestens)
const CHECKPOINTS_ZUFAELLIG: bool = true   # false = immer die festen Felder der nächsten Zeile
static var CHECKPOINTS: Array[Vector2i] = [Vector2i(6, 4), Vector2i(13, 5)]
const CHECKPOINTS_AB_WELLE: int = 5    # vorher sind die Felder nur freigehalten (nicht bebaubar)
const EINNAHME_SEK: float = 3.0        # so lange muss der Gegner einen Checkpoint halten
const CHECKPOINT_RUHE: float = 1.5     # die zugeteilte Truppe geht einen Checkpoint zurückholen, solange in diesem Umkreis (Felder) kein Gegner ist
const RUECKEROBERUNG_SEK: float = 4.0  # so lange muss eine Bodentruppe den Checkpoint halten
const NACHSPIEL_MAX: float = 10.0     # so lange läuft die Runde nach dem letzten Gegner höchstens weiter, damit die zugeteilte Truppe den Checkpoint zurückholt
const STELLUNG_BAU_RUHE: float = 2.0   # während der Welle: Stellung nur bauen, wenn in diesem Umkreis (Felder) kein Gegner ist

# --- Tempo -------------------------------------------------------------
const SPIELTEMPO: float = 0.7      # 1.0 = volle Geschwindigkeit; gilt für alles (Laufen, Schießen, Produktion)
const TRUPP_PAUSE: float = 3.0     # Sekunden zwischen zwei Trupps einer Welle

# --- Wirtschaft --------------------------------------------------------
const START_BUDGET: int = 120
const START_LEBEN: int = 15
const KOSTEN_FABRIK: int = 50      # die erste Fabrik
const KOSTEN_FABRIK_PROZENT: float = 25.0  # jede weitere Fabrik kostet so viel Prozent mehr als die vorige (auf 5 gerundet)
const ZONE_ABSTAND: int = 2        # so viele Felder halten eigene Truppen Abstand zur Zone (außer in der letzten Runde), damit die Gegner herauskommen
const HAUFEN_MIN: int = 3          # ab so vielen Bodentruppen dicht beieinander gilt das als Haufen: Ziel für Schleuder, Rauch und Sprenger
const HAUFEN_RADIUS: float = 1.3   # Felder
const SPRENGER_FABRIK_SCHADEN: float = 300.0   # Sprenger ohne lohnenden Erdwall sprengt eine Fabrik (fällt für die Runde aus) ...
const SPRENGER_FABRIK_SEK: float = 25.0        # ... aber nur so lange (Beschuss durch Sphären und Schleudern gilt weiter bis zum Rundenende)
const SPRENGER_TRUPP_SCHADEN: float = 45.0     # ... und trifft Bodentruppen im Umkreis
const SPRENGER_TRUPP_RADIUS: float = 1.6
const ERSTATTUNG: float = 0.75     # Anteil des Preises, den es beim Abreißen zurückgibt
const KOSTEN_WALL: int = 10
const KOSTEN_STELLUNG: int = 25    # Ausbau eines Erdwalls: Platz für eine Einheit
const KOSTEN_TURM: int = 75        # Ausbau eines Erdwalls an einer Kreuzung
const KOSTEN_TOR: int = 40         # Ausbau eines Erdwalls: Durchgang nur für eigene Truppen
const KOSTEN_BATTERIE: int = 290   # Railgun-Batterie samt angehängter Pilotenfabrik (zwei Felder); feuert erst, wenn sie voll bemannt ist
const KOSTEN_BATTERIE_PROZENT: float = 20.0  # 17.11.: jede weitere Batterie kostet so viel Prozent mehr als die vorige (290, 350, 420, 500 …)
const WAELLE_AB_WELLE: int = 2     # Runde 1: nur Fabriken, danach Erdwälle
# Einkommen nach dem Muster von Bloons TD 6: Der feste Bonus am Rundenende ist der größere, planbare Teil,
# Prämien für besiegte Gegner kommen obendrauf.
const BONUS_JE_WELLE: int = 100    # Budget nach jeder überstandenen Welle
const BONUS_JE_CHECKPOINT: int = 20    # zusätzlich je Checkpoint, der am Rundenende dir gehört (0 = aus)
# Zinsen wie in Teamfight Tactics: Für je ZINS_SCHRITT Budget, das am Rundenende noch da ist, gibt es ZINS_JE_SCHRITT dazu.
const ZINS_SCHRITT: int = 100
const ZINS_JE_SCHRITT: int = 10
const ZINS_STUFEN: int = 5         # höchstens so viele Schritte zählen (also höchstens 50 Zinsen)
const BONUS_ZUWACHS: int = 5       # ... plus so viel je Wellennummer
const BONUS_MITTE_AB: int = 6      # ab dieser Runde wächst der Bonus schneller (Geld für Fabriken UND Upgrades)
const BONUS_MITTE_ZUWACHS: int = 0 # ... um so viel je Runde zusätzlich (0 = aus; war 8, am 14.11. gestrichen: zu viel Geld zum Sparen)

# --- Gebäude -----------------------------------------------------------
const LEBEN_WALL: float = 120.0
const LEBEN_FABRIK: float = 300.0
const PRODUKTION_SEK: float = 5.0  # Sekunden je Einheit
const MAX_JE_FABRIK: int = 2       # so viele Einheiten hält eine Fabrik am Leben (Stufe 1 gibt die dritte)
const MAX_JE_FABRIK_ENDKAMPF: int = 5  # ... und so viele in der letzten Runde
const FABRIK_EINHEITEN: Array[String] = ["technogunner", "scharfschuetze", "plasmawerfer"]  # zur Wahl im Fabrikmenü (Piloten kommen aus der Pilotenfabrik der Batterie)

# --- Fabrik-Upgrades -------------------------------------------------------
# Stufe 0: Grundfabrik, Truppe frei umstellbar.
# Stufe 1: spezialisiert – bleibt bei ihrer Truppe und hält eine Truppe mehr.
# Stufe 2: Wertepaket je Truppe (siehe STUFE_2).
# Stufe 3: Sonderfähigkeit zur Wahl (siehe STUFE_3) – ändert, wie die Truppe kämpft.
const KOSTEN_STUFE: Array[int] = [75, 175, 450]   # vorher 50/150/400 (14.11. erhöht)      # Preis für Stufe 1, 2 und 3
const KOSTEN_BATTERIE_STUFE: Array[int] = [125, 175, 450]   # vorher 100/150/400 (14.11. erhöht)   # dasselbe für die Batterie
const HAUPTLINIE_BIS: int = 2        # bis zu dieser Runde kommen alle Gegner über die Hauptlinie, nicht verteilt aus der ganzen Zone
const REPARATUR_SEK: float = 5.0     # so lange braucht ein Reservepilot, um ein ausgefallenes Gebäude oder einen lahmen Turm zu reparieren
const HQ_WEGKOSTEN: float = 60.0              # 17.11.: so teuer ist ein HQ-Feld im Weg – niemand läuft mehr hindurch
const STELLUNG_DECKUNG: float = 0.4          # Patch 16.11.: Truppen oben in einer Stellung nehmen so viel weniger Schaden
# Patch 16.11. (Paul): Fahnenträger 190 → 160, Schildträger 150 → 135, Schwarmgeist 300 → 270 Leben (Werte unten bei den Gegnern)
const AUFRAEUM_STEHT_SEK: float = 3.0         # Aufräumen am Rundenende: Truppen steigen nur für Gegner ab, die so lange feststehen ...
const AUFRAEUM_OHNE_TREFFER_SEK: float = 8.0  # ... oder die so lange niemand mehr getroffen hat (außer Reichweite)
const AUFRAEUM_JAEGER_JE_GEGNER: int = 2      # höchstens so viele Truppen steigen je solchem Gegner ab
const AUFRAEUM_DRAUSSEN_SEK: float = 15.0     # ... und nur für Gegner, die schon so lange außerhalb der Zone unterwegs sind
const AUFRAEUM_HOECHSTENS_GEGNER: int = 3     # 16.11. (Paul): aufgeräumt wird erst, wenn nur noch so wenige Gegner übrig sind –
                                              # vorher verließen alle schlagartig die Stellungen, obwohl noch ein Trupp unterwegs war
const ABFANG_JE_FELD: int = 2        # höchstens so viele Bodentruppen fangen auf demselben Feld ab
const ABFANG_WEIT: int = 14          # so viele Felder voraus auf dem Gegnerweg wird ein Abfangfeld gesucht
const STUFE_1_TRUPPEN: int = 1                  # so viele Truppen hält eine spezialisierte Fabrik zusätzlich
# plus = wird addiert, mal = wird multipliziert
const STUFE_2 := {
	"scharfschuetze": {"text": "Klarsicht (schießt auch im Rauch), +30 % Schaden, feuert 20 % schneller",
		"plus": {}, "mal": {"schaden": 1.3, "abklingzeit": 0.8}, "setze": {"klarsicht": true}},
	"technogunner": {"text": "+50 % Leben, +30 % Schaden, +0,5 Reichweite",
		"plus": {"reichweite": 0.5}, "mal": {"leben": 1.5, "schaden": 1.3}},
	"plasmawerfer": {"text": "+0,2 Fläche, +30 % Schaden, läuft 25 % schneller",
		"plus": {"flaeche": 0.2}, "mal": {"schaden": 1.3, "tempo": 1.25}},
}


# Stufe 3: je Truppe mehrere Fähigkeiten, die Fabrik wählt eine. "stark" / "schwach" stehen im Fabrikmenü.
const STUFE_3 := {
	"scharfschuetze": {
		"durchschuss": {"name": "Durchschuss", "text": "Der Schuss geht in gerader Linie durch alle Gegner.",
			"stark": "Rudel in geraden Gängen", "schwach": "Einzelziele, verwinkelte Wege"},
		"laser": {"name": "Laserstrahl", "text": "Dauerstrahl auf ein Ziel; der Schaden wächst, solange er dranbleibt.",
			"stark": "zähe Einzelziele", "schwach": "viele kleine Gegner"},
		"markierung": {"name": "Zielmarkierung", "text": "Nur aus der Stellung: trifft das stärkste Ziel der ganzen Karte und markiert es – alle anderen richten daran mehr Schaden an und treffen es auch aus dem Rauch heraus.",
			"stark": "Belagerungsturm, Fahnenträger, Sprenger – überall", "schwach": "Rudel; eigener Schaden gering"},
	},
	"technogunner": {
		"bollwerk": {"name": "Bollwerk", "text": "Nahkämpfer mit sehr viel Leben, der Gegner im Gang festhält. Nimmt keine Stellung mehr.",
			"stark": "Engstellen, Checkpoints", "schwach": "Fernkämpfer, Schleuder"},
		"feuerteam": {"name": "Feuerteam", "text": "Feuert schneller, je mehr Feuerteam-Schützen Gegner auf derselben Kachel beschießen – bis dreimal so schnell. Der Bonus baut sich über einige Sekunden Dauerfeuer auf.",
			"stark": "dicht stehende Truppen, Pulks auf einer Kachel", "schwach": "Rauch, verteilte Stellungen, kurze Gefechte"},
		"minigun": {"name": "Minigun", "text": "Nur in der Stellung: feuert immer schneller, solange sie ununterbrochen Ziele hat. Treffer und Rauch unterbrechen sie.",
			"stark": "durchlaufende Rudel", "schwach": "alles, was Stellungen stört"},
	},
	"plasmawerfer": {
		"abpraller": {"name": "Abpraller", "text": "Das Geschoss springt nach dem Einschlag bis zu zweimal zum nächsten Gegner weiter.",
			"stark": "enge Gänge, Trupps in Reihe", "schwach": "weit verteilte Gegner"},
		"brandfeld": {"name": "Brandfeld", "text": "Der Einschlag brennt einige Sekunden nach und schädigt, wer hindurchläuft.",
			"stark": "Checkpoints, Engstellen", "schwach": "schnelle Gegner"},
		"plasmagel": {"name": "Plasmagel", "text": "Nur aus der Stellung: kaum Schaden, aber alle Getroffenen werden einige Sekunden stark verlangsamt.",
			"stark": "Sturm hinter der Fahnenspur", "schwach": "tötet allein nichts"},
	},
}
const DURCHSCHUSS_BREITE: float = 0.3        # so nah (Felder) an der Schusslinie wird ein Gegner mitgetroffen
const LASER_ANSTIEG: float = 0.5             # je Sekunde am selben Ziel so viel mehr Schaden (1.0 = +100 %)
const LASER_HOECHST: float = 3.0             # höchstens das Dreifache
const MARKIERUNG_SEK: float = 5.0
const MARKIERUNG_FAKTOR: float = 1.4         # markierte Gegner nehmen so viel mehr Schaden
const MARKIERUNG_EIGENER_SCHADEN: float = 0.4
const MARKIERUNG_ABKLING: float = 0.45       # Pause mal ...: feuert gut doppelt so schnell wie normal (15.11.; vorher 1,5 = langsamer)
const BOLLWERK_LEBEN: float = 3.5
const BOLLWERK_SCHADEN: float = 1.5
const BOLLWERK_REICHWEITE: float = 0.95      # Felder: Nahkampf
const FEUERTEAM_JE_MITSCHUETZE: float = 0.2  # 15.11.: vorher 0,12 – so viel kürzer wird die Pause je Mitschütze am selben Ziel
const FEUERTEAM_HOECHST: float = 1.0 / 3.0   # 17.11.: höchstens ein Drittel der Pause = dreifaches Tempo (vorher halbe Pause); zählt Mitschützen je Kachel
const FEUERTEAM_ANLAUF_JE_SCHUSS: float = 0.2   # 17.11.: Anlauf je Schuss mit Mitschützen (voll nach 5 Schüssen, etwa 4–5 Sekunden)
const FEUERTEAM_PAUSE_VERFALL: float = 2.5      # so lange ohne Schuss, dann ist der Anlauf weg
const MINIGUN_JE_SCHUSS: float = 0.2         # Anlauf je Schuss (0..1); 15.11.: vorher 0,1 (voller Anlauf nach 5 statt 10 Schüssen)
const MINIGUN_TREFFER_VERLUST: float = 0.5   # ein Treffer kostet nur diesen Anteil des Anlaufs (vorher alles); Rauch stoppt ihn weiter ganz
const MINIGUN_SCHNELLSTE: float = 0.3        # bei vollem Anlauf nur noch dieser Anteil der Pause
const MINIGUN_ABKLING: float = 0.6           # 15.11.: Grundpause der Minigun (die alte Gunner-Pause); der Gunner selbst feuert jetzt alle 1,4 s im Zweierstoß
const MINIGUN_SCHADEN_FAKTOR: float = 0.86   # 15.11.: Minigun-Treffer = Schaden je Treffer × dies (8 / 9,3: wie vorher)
                                             # Übergang: die Minigun zeigt nur den ersten Mündungsblitz, bis sie eine eigene Dauerfeuer-Animation hat
const ABPRALLER_SPRUENGE: int = 2
const ABPRALLER_WEITE: float = 2.5           # Felder bis zum nächsten Ziel
const ABPRALLER_SCHADEN: float = 0.7         # jeder Sprung richtet so viel vom vorigen an
const BRANDFELD_SEK: float = 3.0
const BRANDFELD_SCHADEN: float = 0.25        # 15.11.: vorher 0,35 – Anteil des Schusses je Sekunde im Feuer
const PLASMAGEL_SEK: float = 3.0
const PLASMAGEL_TEMPO: float = 0.45          # Gebremste laufen nur noch so schnell
const PLASMAGEL_SCHADEN: float = 0.25


## Werte einer Truppe aus einer Fabrik der Stufe `stufe` (ab Stufe 2 mit dem Wertepaket, ab Stufe 3 mit Fähigkeit).
static func einheit_daten(typ: String, stufe: int, faehigkeit: String = "") -> Dictionary:
	var d: Dictionary = (EINHEITEN[typ] as Dictionary).duplicate()
	d["faehigkeit"] = faehigkeit if stufe >= 3 else ""
	if stufe >= 2 and STUFE_2.has(typ):
		var paket: Dictionary = STUFE_2[typ]
		for k: String in paket["plus"]:
			d[k] = float(d[k]) + float(paket["plus"][k])
		for k: String in paket["mal"]:
			d[k] = float(d[k]) * float(paket["mal"][k])
		for k: String in paket.get("setze", {}):
			d[k] = paket["setze"][k]
	if d["faehigkeit"] == "bollwerk":
		d["leben"] = float(d["leben"]) * BOLLWERK_LEBEN
		d["schaden"] = float(d["schaden"]) * BOLLWERK_SCHADEN
		d["reichweite"] = BOLLWERK_REICHWEITE
	return d


# Ausbaustufen der Batterie (gekauft über ihre Pilotenfabrik, Preise wie KOSTEN_STUFE).
const BATTERIE_STUFEN := [
	{"name": "Reservepilot", "text": "Die Pilotenfabrik hält einen vierten Piloten in Reserve. Er rückt nach, wenn einer fehlt – und läuft sonst zu ausgefallenen Fabriken, Batterien und lahmgelegten Türmen und repariert sie (5 Sekunden)."},
	{"name": "Schwere Ladung", "text": "Mehr Schaden und Reichweite. Die Druckwelle bläst außerdem Rauchwolken in Reichweite weg."},
	{"name": "Energieschild", "text": "Die bemannte Batterie spannt einen Energiestrahl gerade von einem Erdwall zum nächsten. Gegner müssen ihn erst zerschlagen, eigene Truppen gehen hindurch. Je länger der Strahl, desto weniger hält er aus. Er lädt sich zwischen den Runden wieder auf."},
]
const BATTERIE_ST2_SCHADEN: float = 1.3      # Schaden mal ... ab Stufe 2
const BATTERIE_RAND_FAKTOR: float = 0.5      # Batterie-Einschlag: in der Mitte voller Schaden, zum Rand hin abfallend bis auf diesen Anteil (15.11.)
const BATTERIE_ST2_REICHWEITE: float = 1.5   # Felder mehr Reichweite ab Stufe 2
const BATTERIE_RAUCH_SEK: float = 2.5        # alle so viele Sekunden bläst eine Stufe-2-Batterie eine Rauchwolke weg
const SCHILD_LEBEN: float = 450.0            # so viel hält ein Energieschild über ein Feld aus (Engstelle)
const SCHILD_LAENGE_ABZUG: float = 0.25      # jedes weitere Feld: Schild hält insgesamt weniger aus (450 / (1 + 0,25 · (Felder − 1)))


## Energieschild von Erdwall zu Erdwall (16.11.): je länger, desto weniger hält er insgesamt aus.
static func schild_leben(felder: int) -> float:
	return SCHILD_LEBEN / (1.0 + SCHILD_LAENGE_ABZUG * float(maxi(felder, 1) - 1))
const SCHILD_MIN_SCHADEN: float = 6.0        # auch Gegner ohne Angriff (Fahnenträger ...) drücken mit so viel je Schlag dagegen
const SCHILD_SCHLAG_SEK: float = 1.0         # Schlagtakt gegen den Schild, falls der Gegner keinen eigenen hat

# --- Railgun-Batterie ------------------------------------------------------
# Eigenes Gebäude am Boden (versperrt den Weg wie eine Fabrik). Nur Piloten bemannen sie – immer den nächsten
# freien Platz nach Fußweg. Sie feuert nur, solange alle Plätze besetzt sind.
const BATTERIE := {
	"blatt": "res://assets/sprites/batterie.png",
	"zelle": 48,
	"plaetze": 3,
	"leben": 300.0,
	"reichweite": 8.0,          # weit, über Wälle hinweg
	"flaeche": 1.2,             # Radius des Einschlags in Feldern (15.11.: vorher 1,5)
	"schaden": 65.0,            # vorher 45 (14.11.: Batterie für ihren Preis gestärkt)
	"abklingzeit": 4.1,         # Patch 17.11.: 15 % seltener (vorher 3,5; davor 4)
}

# --- Weg zur Stellung ------------------------------------------------------
## Drang in die Stellung je Truppe (16.11., Paul): Technogunner kämpft bei Gegnern in der Nähe lieber am Boden,
## der Scharfschütze will fast immer hinauf (außer ein Gegner steht direkt vor ihm), der Plasmawerfer liegt dazwischen.
##   nahwehr  = auf dem Weg zur Stellung nur auf Gegner so nah (Felder) stehen bleiben und schießen
##   gefahr   = Felder so nah an Gegnern meidet die Truppe auf dem Weg (0 = geht trotzdem); sonst wartet sie am Boden
const STELLUNG_DRANG := {
	"technogunner": {"nahwehr": 99.0, "gefahr": 2.0},
	"plasmawerfer": {"nahwehr": 2.0, "gefahr": 1.0},
	"scharfschuetze": {"nahwehr": 1.2, "gefahr": 0.0},
}
const STELLUNG_NAHWEHR_FELDER: float = 2.5   # Rückfall für Truppen ohne Eintrag in STELLUNG_DRANG
const STELLUNG_TROTZDEM_FELDER: int = 4      # so nah an der Stellung wird auch durch die Gefahr hindurch gegangen
const STELLUNG_DURCHGEHEN_FELDER: int = 3     # so viele Felder vor der Stellung wird gar nicht mehr angehalten
const GEFAHR_RADIUS: float = 2.0   # Felder: Truppen auf dem Weg zu Stellung/Batterie meiden Felder so nah an Gegnern

# --- Stellungen und Türme ------------------------------------------------
const WACHPOSTEN_BONUS: float = 1.0  # Stellung auf einem einzelnen Erdwall ohne Nachbarwälle (Streubau): zusätzliche Reichweite
const POSTEN_REICHWEITE_BONUS: float = 1.0 # Extra-Reichweite von oben, falls eine Einheit keinen eigenen Wert hat ("stellung_bonus")
const TURM_NACHBARN: int = 3               # so viele angrenzende Erdwälle braucht ein Turm (T-Stück oder Kreuzung)
# Formtürme: Die Form der freien Nachbarwälle bestimmt, welcher Turm entsteht (Stützregel wie bisher).
#   Kreuzung (4) = Funkturm · T-Stück (3) = Geschützturm
#   lange Ecke (Ecke, beide Arme 2 Erdwälle lang) = Frostturm
#   Klammer (gerades Stück, an beiden Enden biegt die Mauer ab: ⊐) = Lanzenturm
#   Treppe (keine Nachbarwälle, nur schräg an zwei gegenüberliegenden Ecken) = Heilturm
const TURMARTEN := {
	"geschuetz": {"name": "Geschützturm", "form": "T-Stück", "nachbarn": 3, "farbe": "7fe0ff",
		"reichweite": 3.5, "schaden": 16.0, "abklingzeit": 0.9,
		"text": "Schießt schnell auf ein Ziel. Der Allrounder."},
	"frost": {"name": "Frostturm", "form": "Lange Ecke", "nachbarn": 4, "farbe": "bfefff",
		"reichweite": 3.0, "schaden": 0.0, "abklingzeit": 1.5, "bremse_sek": 1.6, "bremse_tempo": 0.65,   # 15.11. gebufft (vorher 1,2 s auf 80 %)
		"text": "Frostpuls auf alle Gegner in Reichweite und Sicht: kein Schaden, aber 1,6 Sekunden auf 65 % Tempo verlangsamt – wer im Umkreis bleibt, bleibt langsam."},
	"funk": {"name": "Funkturm", "form": "Kreuzung", "nachbarn": 4, "farbe": "ffd34d",
		"reichweite": 2.5, "schaden": 0.0, "abklingzeit": 0.0, "feuer_faktor": 0.75,
		"text": "Schießt nicht selbst. Truppen in Stellungen im Umkreis feuern 25 % schneller."},
	"heil": {"name": "Heilturm", "form": "Treppe", "nachbarn": 2, "farbe": "7dff9a",
		"reichweite": 2.5, "schaden": 0.0, "abklingzeit": 2.0, "heilung": 8.0,
		"text": "Schießt nicht. Heilt alle 2 Sekunden eigene Truppen im Umkreis um 8 Leben."},
	"lanze": {"name": "Lanzenturm", "form": "Klammer", "nachbarn": 4, "farbe": "ff8a3d",
		"reichweite": 6.0, "schaden": 45.0, "abklingzeit": 4.0, "breite": 0.35,
		"text": "Langsamer, schwerer Strahl in gerader Linie: trifft alles, was in der Linie steht – ideal für lange Gänge."},
}
# Turmupgrades (Klick auf den Turm), wie bei den Fabriken: Stufe 2 fest, auf Stufe 3 eine von zwei Fähigkeiten.
const KOSTEN_TURM_STUFE: Array[int] = [125, 300]   # Patch 17.11.: vorher 175/450 (Upgrades lohnten sich für den Schaden kaum)
const TURM_STUFE_2 := {
	"geschuetz": {"abklingzeit": 0.65, "reichweite": 4.0, "text": "Feuert schneller (alle 0,65 statt 0,9 Sekunden) und reicht 4 statt 3,5 Felder."},   # 17.11.: +0,5 Reichweite
	"frost": {"bremse_sek": 2.4, "text": "Bremst länger: 2,4 statt 1,6 Sekunden."},
	"funk": {"reichweite": 3.5, "text": "Größerer Umkreis: 3,5 statt 2,5 Felder."},
	"lanze": {"schaden": 65.0, "text": "Stärkerer Strahl: 65 statt 45 Schaden."},
	"heil": {"heilung": 12.0, "text": "Heilt mehr: 12 statt 8 Leben."},
}
const TURM_STUFE_3 := {
	"geschuetz": {
		"doppelschuss": {"name": "Doppelschuss", "ziele": 2, "text": "Trifft zwei Gegner zugleich.",
			"stark": "gegen Rudel", "schwach": "nicht stärker gegen einzelne zähe Gegner"},
		"schwer": {"name": "Schwere Munition", "schaden": 35.0, "abklingzeit": 1.1, "text": "35 statt 16 Schaden, dafür alle 1,1 Sekunden.",
			"stark": "gegen Belagerungsturm und Sphären", "schwach": "schwach gegen Hunderudel"},
	},
	"frost": {
		"schockfrost": {"name": "Schockfrost", "schock_sek": 0.5, "schock_alle": 6.0, "text": "Alle 6 Sekunden friert er die Gegner im Umkreis 0,5 Sekunden komplett ein.",
			"stark": "stoppt den Fahnensturm", "schwach": "dazwischen nur der normale Puls"},
		"sproede": {"name": "Sprödes Eis", "sproede": 1.15, "text": "Gegner, die er bremst, nehmen 15 % mehr Schaden von allem.",
			"stark": "stark neben Lanze und Stellungen", "schwach": "nutzlos ohne Schützen in der Nähe"},
	},
	"funk": {
		"verstaerker": {"name": "Verstärker", "feuer_faktor": 0.6, "text": "Stellungen im Umkreis feuern 40 % statt 25 % schneller.",
			"stark": "reiner Schadensbonus", "schwach": "hilft nicht gegen Rauch"},
		"peilsender": {"name": "Peilsender", "peilung": true, "text": "Truppen in Stellungen im Umkreis sehen durch Rauch (Klarsicht).",
			"stark": "gegen Rauchwerfer", "schwach": "kein zusätzliches Tempo"},
	},
	"lanze": {
		"durchschlag": {"name": "Durchschlag", "reichweite": 8.0, "abklingzeit": 5.0, "durch_waelle": true, "text": "Der Strahl geht durch Erdwälle und reicht 8 Felder, dafür alle 5 Sekunden.",
			"stark": "trifft auch den Gang dahinter", "schwach": "feuert seltener"},
		"doppelstrahl": {"name": "Doppelstrahl", "strahlen": 2, "text": "Zwei Strahlen kurz hintereinander.",
			"stark": "mehr Schaden im langen Gang", "schwach": "nicht breiter, nicht weiter"},
	},
	"heil": {
		"lazarett": {"name": "Feldlazarett", "lazarett": true, "text": "Fällt eine Truppe im Umkreis, steht sie mit halbem Leben wieder auf – einmal pro Runde.",
			"stark": "spart teure Truppen", "schwach": "nur einmal pro Runde"},
		"instand": {"name": "Instandsetzung", "instand_sek": 8.0, "text": "Türme im Umkreis, die Myr-Drohnen lahmgelegt haben, laufen nach 8 Sekunden wieder.",
			"stark": "Antwort auf den Belagerungsturm", "schwach": "kein Bonus für Truppen"},
	},
}
const KOSTEN_SPIEGEL: int = 50     # Spiegel auf einem Erdwall: Bodentruppen schießen über ihn um die Ecke
const KOSTEN_MAGNET: int = 60      # Magnet auf einem Erdwall: zieht Gegner in einer Linie zu sich heran (Richtung mit [T])
const MAGNET := {
	"laenge": 4,                 # so viele Felder reicht die Linie vor dem Magneten (endet am ersten Hindernis)
	"abklingzeit": 6.0,          # Sekunden zwischen zwei Zügen
	"zug": 1.5,                  # so weit (Felder) zieht er die Gegner heran – höchstens bis vor den Magneten
}
# Schildgenerator: steht in einem Hof (freie Felder, rundum von Erdwällen eingeschlossen) auf einem Feld.
# Seine Kuppel deckt den ganzen Ring samt Rand: Truppen darunter nehmen weniger Schaden, Steine der Schleuder und Rauch prallen ab.
const KOSTEN_GENERATOR: int = 150
const HOF_MIN: int = 2             # so viele Felder muss ein Hof mindestens haben (der Generator braucht zwei)
const HOF_MAX: int = 12            # größere eingeschlossene Flächen zählen nicht als Hof
const KUPPEL_SCHUTZ: float = 0.4   # Truppen unter der Kuppel nehmen so viel weniger Schaden
const KUPPEL_RAND: float = 1.0     # Felder: so weit reicht die Kuppel über den äußersten Wall des Rings hinaus
const KOSTEN_PANZER: int = 30      # Panzerung eines Erdwalls: Die erste Sprengung nimmt nur die Panzerung
const TURM := {
	"leben": 90.0,               # so viel Schaden durch Myr-Drohnen, dann ist er für den Rest der Runde lahmgelegt
	"reichweite": 3.5,
	"schaden": 16.0,
	"abklingzeit": 0.9,
}

# --- Grafik: Klassisch, Neu (2D) oder HD-2D (Startmenü, 16.11.) -------------------------------
# Neu = Stil der HD-2D-Stilprobe in der 2D-Ansicht: neue Türme mit Upgrade-Stufen, Tech-Mauer, Stellungs-Haltungen,
# Upgrade-Figuren mit Schuss-Animation, Gegner auf Truppen-Pixelgröße umgerechnet, PixelFX-Effekte und Todeseffekte.
# HD-2D = dieselben Bilder in einer 3D-Ansicht wie die Stilprobe (geneigte Kamera, Zoom, Mauerblöcke), siehe hd_ansicht.gd.
# Spielwerte und Regeln bleiben gleich. Die Wahl wird in user://einstellungen.cfg gespeichert.
static var grafik := "hd"   # "klassisch", "neu" (Vogelperspektive) oder "hd" (HD-2D, Standard seit 16.11.)
static var grafik_neu := false     # neue Bilder (bei "neu" und "hd")
static var grafik_hd := false      # 3D-Ansicht
static var vollbild := true        # Vollbild ([F11] oder Startmenü), gespeichert
static var toene := 80              # Kampfgeräusche in Prozent (0 = aus), gespeichert
static var musik := 40              # Musik in Prozent (0 = aus); 16.11.: Grundlautstärke 60 % leiser, gespeichert
static var wand_stil := "tech"     # HD-2D-Mauern: "tech" (Stilprobe), "block" (schlicht) oder "energie" – Taste [M] im Spiel
static var grafik_gefragt := false # 18.11.: Touchgerät – beim ersten Start einmal nach der Grafik gefragt (HD-2D braucht viel WebGL-Speicher)
const EINSTELLUNGEN := "user://einstellungen.cfg"
const NEU := "res://assets/neu/"


static func lade_einstellungen() -> void:
	var c := ConfigFile.new()
	if c.load(EINSTELLUNGEN) == OK:
		grafik = str(c.get_value("grafik", "modus", "hd"))
		wand_stil = str(c.get_value("grafik", "wand", "tech"))
		grafik_gefragt = bool(c.get_value("grafik", "touch_gefragt", false))
		karte_gross = bool(c.get_value("karte", "gross", true))
		vollbild = bool(c.get_value("grafik", "vollbild", true))
		musik = clampi(int(c.get_value("ton", "musik_prozent", 40)), 0, 100)
		toene = clampi(int(c.get_value("ton", "effekte_prozent", 80)), 0, 100)
	if OS.get_environment("TD_KARTE") != "":
		karte_gross = OS.get_environment("TD_KARTE") == "gross"   # für Testläufe: normal oder gross
	setze_karte(karte_gross)
	if OS.get_environment("TD_GRAFIK") != "":
		grafik = OS.get_environment("TD_GRAFIK")   # für Testläufe: klassisch, neu oder hd
	setze_grafik(grafik)


## Vollbild an/aus. Das Bild skaliert mit (stretch canvas_items, Seitenverhältnis bleibt 16:9).
static func setze_vollbild(an: bool) -> void:
	vollbild = an
	if DisplayServer.get_name() == "headless":
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if an else DisplayServer.WINDOW_MODE_WINDOWED)


static func setze_grafik(modus: String) -> void:
	grafik = modus if modus in ["klassisch", "neu", "hd"] else "klassisch"
	grafik_neu = grafik != "klassisch"
	grafik_hd = grafik == "hd"


static func speichere_einstellungen() -> void:
	var c := ConfigFile.new()
	c.load(EINSTELLUNGEN)
	c.set_value("grafik", "modus", grafik)
	c.set_value("grafik", "wand", wand_stil)
	c.set_value("grafik", "touch_gefragt", grafik_gefragt)
	c.set_value("karte", "gross", karte_gross)
	c.set_value("grafik", "vollbild", vollbild)
	c.set_value("ton", "musik_prozent", musik)
	c.set_value("ton", "effekte_prozent", toene)
	c.save(EINSTELLUNGEN)


## Stellt alle größenabhängigen Felder auf die normale (20×10) oder große (28×14) Karte.
## Groß: dieselbe Anordnung, Zeilen ×13/9 gestreckt (HQ in der Mitte der Zone), Bereiche und Basis nach rechts mitgewachsen.
static func setze_karte(gross: bool) -> void:
	karte_gross = gross
	if not gross:
		SPALTEN = 20
		ZEILEN = 10
		KARTE_FAKTOR = 1.0
		START_ZELLE = Vector2i(0, 4)
		ANGRIFFS_ZELLE = Vector2i(1, 4)
		ZONENBAUTEN = _zonenbauten([2, 7, 7, 2, 2, 5, 7])
		SCHLEUDER_PLAETZE = [Vector2i(1, 0), Vector2i(1, 1), Vector2i(1, 2), Vector2i(1, 3), Vector2i(1, 6), Vector2i(1, 7), Vector2i(1, 8), Vector2i(1, 9)]
		AUSGAENGE = {"": Vector2i(0, 4), "oben": Vector2i(1, 1), "unten": Vector2i(1, 8)}
		BASIS_ZELLE = Vector2i(18, 5)   # 16.11.: Basis 3×2 Felder, darum eine Spalte nach innen (vorher 19)
		CHECKPOINT_BEREICHE = [Rect2i(4, 1, 7, 8), Rect2i(8, 1, 8, 8)]
		CHECKPOINTS = [Vector2i(6, 4), Vector2i(13, 5)]
		return
	SPALTEN = 28
	ZEILEN = 14
	KARTE_FAKTOR = 27.0 / 19.0
	START_ZELLE = Vector2i(0, 6)
	ANGRIFFS_ZELLE = Vector2i(1, 6)
	ZONENBAUTEN = _zonenbauten([3, 10, 10, 3, 3, 7, 10])
	SCHLEUDER_PLAETZE = [Vector2i(1, 0), Vector2i(1, 1), Vector2i(1, 2), Vector2i(1, 3), Vector2i(1, 4),
		Vector2i(1, 9), Vector2i(1, 10), Vector2i(1, 11), Vector2i(1, 12), Vector2i(1, 13)]
	AUSGAENGE = {"": Vector2i(0, 6), "oben": Vector2i(1, 1), "unten": Vector2i(1, 12)}
	BASIS_ZELLE = Vector2i(26, 7)
	CHECKPOINT_BEREICHE = [Rect2i(6, 1, 9, 12), Rect2i(12, 1, 11, 12)]   # 17.11.: größer und überlappend
	CHECKPOINTS = [Vector2i(8, 6), Vector2i(18, 7)]


## Zonenbauten mit den Zeilen `zeilen` (Reihenfolge wie in der Liste oben, Spalten und Wellen bleiben).
static func _zonenbauten(zeilen: Array) -> Array:
	var vorlage := [["schleuder", 1, 5], ["schleuder", 1, 8], ["wurf", 0, 10], ["wurf", 0, 14], ["laser", 2, 20], ["laser", 2, 20], ["laser", 2, 20]]
	var liste: Array = []
	for i in vorlage.size():
		liste.append({"art": vorlage[i][0], "zelle": Vector2i(vorlage[i][1], zeilen[i]), "ab_welle": vorlage[i][2]})
	return liste


## Gegner-Blätter der neuen Grafik: auf die Pixelgröße der Truppen umgerechnet, gezeigt mit Maßstab 2 wie die Truppen.
const NEU_BLAETTER := {
	"res://assets/sprites/hund.webp": {"blatt": "res://assets/neu/gegner/hund.png", "zelle": 36},
	"res://assets/sprites/sphaere.webp": {"blatt": "res://assets/neu/gegner/sphaere.png", "zelle": 40},
	"res://assets/sprites/fahnentraeger.webp": {"blatt": "res://assets/neu/gegner/fahne.png", "zelle": 40},
	"res://assets/sprites/sprenger.webp": {"blatt": "res://assets/neu/gegner/sprenger.png", "zelle": 36},
	"res://assets/sprites/rauchwerfer_neu.png": {"blatt": "res://assets/neu/gegner/rauch.png", "zelle": 36},
	"res://assets/sprites/belagerungsturm.webp": {"blatt": "res://assets/neu/gegner/belagerung.png", "zelle": 48},
	"res://assets/sprites/enterer.webp": {"blatt": "res://assets/neu/gegner/enterer.png", "zelle": 30},
	"res://assets/sprites/drohne.webp": {"blatt": "res://assets/neu/gegner/enterer.png", "zelle": 30},
	"res://assets/sprites/schildtraeger.png": {"blatt": "res://assets/neu/gegner/schild.png", "zelle": 36},
	"res://assets/sprites/sanitaeter.png": {"blatt": "res://assets/neu/gegner/sani.png", "zelle": 36},
	"res://assets/sprites/schwarmgeist.webp": {"blatt": "res://assets/neu/gegner/schwarm.png", "zelle": 40},
	"res://assets/sprites/schleuder.webp": {"blatt": "res://assets/neu/gegner/schleuder.png", "zelle": 40},
}
const NEU_TRUPPEN := {"technogunner": "gun", "scharfschuetze": "sni", "plasmawerfer": "pla"}
const NEU_STUFE_3 := {"bollwerk": "gun_bollwerk", "feuerteam": "gun_feuerteam", "minigun": "gun_minigun",
	"durchschuss": "sni_durchschuss", "laser": "sni_laser", "markierung": "sni_markierung",
	"abpraller": "pla_abpraller", "brandfeld": "pla_brandfeld", "plasmagel": "pla_gel"}
const NEU_SCHUSS_BILDER := {"gun": [3, 6], "sni": [3], "pla": [2, 5]}   # Bilder der neuen Angriffsanimation (9 Bilder), in denen ein Treffer fällt
## je Variante aus den hellsten Bildern (Mündungsblitz) der Animation gemessen; Anzahl wie bei Stufe 1 (Gunner/Plasma 2, Scharfschütze 1)
const NEU_SCHUSS_VARIANTE := {"gun_s2": [4, 6], "gun_bollwerk": [2, 6], "gun_feuerteam": [2, 4], "gun_minigun": [2, 6],
	"sni_s2": [3], "sni_durchschuss": [1], "sni_laser": [2], "sni_markierung": [3],
	"pla_s2": [3, 5], "pla_abpraller": [1, 4], "pla_brandfeld": [1, 3], "pla_gel": [4, 6]}
## Stellungs-Haltung (kniend bzw. liegend): Blatt mit Zeile 0/1 Warten und Zeile 2 Schuss; y = Fußpunkt der Figur
const NEU_HALTUNG := {
	"technogunner": {"blatt": "res://assets/neu/truppen/technogunner_stellung.png", "y": 34.0},
	"plasmawerfer": {"blatt": "res://assets/neu/truppen/plasmawerfer_stellung.png", "y": 32.0},
	"scharfschuetze": {"blatt": "res://assets/neu/truppen/scharfschuetze_stellung.png", "y": 32.0},
}


## Blattdaten je nach gewählter Grafik (für Gegner und Zonenbauten; die Truppen siehe grafik_einheit).
static func grafik_daten(d: Dictionary) -> Dictionary:
	if not grafik_neu or not NEU_BLAETTER.has(str(d.get("blatt", ""))):
		return d
	var n := d.duplicate()
	n.merge(NEU_BLAETTER[str(d["blatt"])], true)
	n["massstab"] = 2.0
	return n


## Truppen ab Stufe 2 in der neuen Grafik: eigenes Blatt je Stufe bzw. Fähigkeit
## (Zeile 0 Stand = Upgrade-Bild, Zeile 1 Laufen wie Stufe 1, Zeile 2 die neue Schuss-Animation).
static func grafik_einheit(d: Dictionary, typ: String, stufe: int) -> Dictionary:
	if not grafik_neu or not NEU_TRUPPEN.has(typ) or stufe < 2:
		return d
	var kurz: String = NEU_TRUPPEN[typ]
	var n := d.duplicate()
	var variante := str(NEU_STUFE_3.get(str(d.get("faehigkeit", "")), kurz + "_s2"))
	n["blatt"] = "res://assets/neu/truppen/%s.png" % variante
	n["zelle"] = 48
	n["bilder"] = [1, 8, 9]
	n["schuss_bilder"] = NEU_SCHUSS_VARIANTE.get(variante, NEU_SCHUSS_BILDER[kurz])
	return n


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
		"schuss_bilder": [1, 7],    # 15.11.: Feuerstoß mit zwei Mündungsblitzen – in diesen Bildern fällt je ein Treffer
		"massstab": 2.0,
		"schussfarbe": "7fe0ff",
		"leben": 75.0,   # Patch 16.11.: vorher 60.0
		"tempo": 1.6,
		"reichweite": 3.0,
		"schaden": 9.3,             # je Treffer; 15.11.: vorher 8 alle 0,6 s – jetzt 2 Treffer alle 1,4 s (gleicher Schaden je Sekunde)
		"abklingzeit": 1.4,         # 15.11.: vorher 0,6 – die Animation kam nicht hinterher
	},
	"plasmawerfer": {
		"name": "Plasmawerfer",
		"blatt": "res://assets/sprites/plasmawerfer.png",
		"zelle": 48,
		"bilder": [4, 8, 9],
		"angriff_dauer": 1.4,
		"schuss_bilder": [1, 6],    # 15.11.: zwei Plasmaschüsse je Angriff, wie in der Animation
		"massstab": 2.0,
		"schussfarbe": "ff8ad8",
		"leben": 85.0,   # Patch 16.11.: vorher 70.0
		"tempo": 1.4,
		"reichweite": 2.6,
		"stellung_bonus": 0.0,      # Plasma fliegt von oben nicht weiter: in der Stellung nur der Schuss über Wälle
		"schaden": 6.5,             # je Treffer; 15.11.: vorher einmal 13 – jetzt zwei Treffer im Takt der Animation
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
		"schuss_bilder": [3],       # 15.11.: der Treffer fällt mit dem Strahl, nicht schon beim Anlegen
		"massstab": 2.0,
		"schussfarbe": "9dff8a",
		"leben": 65.0,   # Patch 17.11.: vorher 55 (16.11.: 40)
		"tempo": 1.3,
		"reichweite": 5.0,
		"stellung_bonus": 1.5,      # der Scharfschütze profitiert am meisten von der Höhe
		"schaden": 38.0,            # Patch 17.11.: vorher 30
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
		"leben": 95.0,   # Patch 16.11.: vorher 110.0
		"tempo": 1.0,
		"reichweite": 3.5,
		"schaden": 16.0,            # an Gebäuden; Ziele: erst Stellungen, dann Fabriken und Batterien, dann Bodentruppen
		"schaden_einheit": 15.0,   # Patch 16.11.: vorher 22.0    # an Truppen
		"abklingzeit": 1.2,
		"wall_kosten": 1000.0,
		"fabrik_kosten": 2000.0,
		"praemie": 8,
	},
	# rolle = Sonderregel (siehe gegner.gd). schaden 0 = kämpft nicht selbst.
	"fahne": {
		"name": "Fahnenträger", "kurz": "Fahne", "art": "führt den Trupp", "rolle": "fahne", "fernkampf": false,
		"blatt": "res://assets/sprites/fahnentraeger.webp", "zelle": 64, "bilder": [9, 13, 17], "angriff_dauer": 1.8, "massstab": 1.1,
		"leben": 160.0, "tempo": 2.3, "reichweite": 0.0, "schaden": 0.0, "abklingzeit": 1.0,
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
		"blatt": "res://assets/sprites/rauchwerfer_neu.png", "zelle": 48, "bilder": [9, 13, 17], "angriff_dauer": 2.0, "massstab": 1.4,
		"leben": 80.0, "tempo": 1.0, "reichweite": 5.0, "schaden": 0.0, "abklingzeit": 9.0,
		"wall_kosten": 1000.0, "fabrik_kosten": 2000.0, "praemie": 8,
	},
	"belagerung": {
		"name": "Belagerungsturm", "kurz": "Bel.-Turm", "art": "entert Wälle", "rolle": "belagerung", "fernkampf": false,
		"blatt": "res://assets/sprites/belagerungsturm.webp", "zelle": 64, "bilder": [9, 13, 17], "angriff_dauer": 2.6, "massstab": 1.4,
		"panzerung": 4.0, "leben": 450.0, "tempo": 0.6, "reichweite": 0.0, "schaden": 0.0, "abklingzeit": 1.0,
		"wall_kosten": 1000.0, "fabrik_kosten": 2000.0, "praemie": 15,
	},
	"enterer": {
		"name": "Myr-Drohne", "kurz": "Drohne", "art": "Nahkampf, auf Wällen und am Boden", "rolle": "enterer", "fernkampf": false,
		"blatt": "res://assets/sprites/enterer.webp", "zelle": 48, "bilder": [9, 9, 9], "angriff_dauer": 0.9, "massstab": 1.2,
		"leben": 60.0, "tempo": 1.6, "reichweite": 1.1, "schaden": 10.0, "abklingzeit": 0.8,
		"wall_kosten": 1000.0, "fabrik_kosten": 2000.0, "praemie": 2,
	},
	"schild": {
		"name": "Schildträger", "kurz": "Schild", "art": "Frontschild", "rolle": "schild", "fernkampf": false,
		"blatt": "res://assets/sprites/schildtraeger.png", "zelle": 48, "bilder": [9, 13, 17], "angriff_dauer": 1.6, "massstab": 1.4,
		"panzerung": 3.0, "leben": 135.0, "tempo": 0.9, "reichweite": 1.1, "schaden": 12.0, "abklingzeit": 1.0,
		"wall_kosten": 1000.0, "fabrik_kosten": 2000.0, "praemie": 10,
	},
	"sani": {
		"name": "Sanitäter", "kurz": "Sani", "art": "heilt Gegner", "rolle": "sani", "fernkampf": false,
		"blatt": "res://assets/sprites/sanitaeter.png", "zelle": 48, "bilder": [9, 13, 17], "angriff_dauer": 1.2, "massstab": 1.3,
		"leben": 70.0, "tempo": 1.1, "reichweite": 2.5, "schaden": 0.0, "abklingzeit": 1.5, "heilung": 8.0,
		"wall_kosten": 1000.0, "fabrik_kosten": 2000.0, "praemie": 10,
	},
	"schwarm": {
		"name": "Schwarmgeist", "kurz": "Schwarm", "art": "zerfällt in Drohnen", "rolle": "schwarm", "fernkampf": false,
		"blatt": "res://assets/sprites/schwarmgeist.webp", "zelle": 64, "bilder": [9, 13, 17], "angriff_dauer": 2.0, "massstab": 1.1,
		"panzerung": 3.0, "leben": 270.0, "tempo": 0.8, "reichweite": 1.1, "schaden": 14.0, "abklingzeit": 1.2, "zerfall": 3,   # vorher 200 (14.11.)
		"wall_kosten": 1000.0, "fabrik_kosten": 2000.0, "praemie": 12,
	},
}
# Kommandant Brakk (einmal pro Partie, Taste [8]): WASD, [Q] Sammeln/Losschlagen, [E] Klettern, [R] Klonmaschine
const KOSTEN_KOMMANDANT: int = 500
const KOMMANDANT := {
	"name": "Kommandant Brakk", "blatt": "res://assets/sprites/brakk_klein.png", "zelle": 32, "bilder": [9, 13, 17],
	"angriff_dauer": 1.2, "massstab": 2.0, "schussfarbe": "8ff0ff", "faehigkeit": "",   # halb so fein wie das Original, doppelt gezeigt: Pixelgröße wie die Technoclan-Truppen
	"leben": 500.0, "tempo": 2.2, "reichweite": 3.5, "schaden": 18.0, "abklingzeit": 1.2,
	"schuss_bilder": [10, 14],    # in diesen Bildern der Angriffsanimation blitzt der Laser: dann fällt je ein Schuss
	"muendung": Vector2(28, -20), # Laseraustritt relativ zu den Füßen (Blick nach rechts)
	"wall_bonus": 1.5,            # oben auf dem Erdwall: mehr Reichweite
	"sammel_radius": 4.0, "sammel_abklingzeit": 4.0,
	"sturm_sek": 8.0, "sturm_abklingzeit": 12.0, "sturm_tempo": 1.3, "sturm_feuer": 0.6,
	"kletter_abklingzeit": 3.0,
	"cp_faktor": 4.0,             # holt verlorene Checkpoints so viel schneller zurück
}
const FERNKAMPF_GEFECHT_TEMPO := 0.35   # Battlesphäre: solange sie schießt, läuft sie nur mit diesem Anteil ihres Tempos
# Platz auf dem Feld (15.11.): Felder sind nur das Wegraster. Einheiten stehen frei darin und halten Abstand nach ihrem Radius
# (Anteil einer Feldbreite). 16.11.: enger gepackt, damit in den schmalen Gängen viele Einheiten in ein Feld passen und sich
# darin verteilen (vorher 0,2 / 0,28 / 0,42 / 0,38, Truppen 0,2, Versatz 0,24): etwa 8 kleine, 4 mittlere oder 2 große je Feld.
const RADIUS_KLEIN := 0.13
const GEGNER_RADIUS := {"schild": 0.2, "sphaere": 0.2, "belagerung": 0.32, "schwarm": 0.28}   # alle anderen: RADIUS_KLEIN
const TRUPPE_RADIUS := 0.15              # eigene Bodentruppen
const ABSTAND_HAERTE := 10.0             # wie schnell Überlappungen aufgelöst werden (je Sekunde)
const ANKUNFT := 0.22                    # so nah (Felder) an einem Wegpunkt gilt ein Gegner als angekommen
const VERSATZ := 0.33                    # Zielpunkte je Gegner bis zu so weit (Felder) neben der Feldmitte (vorher 0,24)
const TRUPP_STAFFEL_SEK := 0.3        # ein Trupp aus der Zone geht als Kolonne los: alle so viele Sekunden einer (16.11.)
const LOCKER_STAFFEL_SEK := 0.9       # 17.11.: lockere Formation ("locker": true im Trupp) – mit so viel Abstand gehen sie los (gegen Flächenschaden)
# Panzerung (17.11.): "panzerung" bei einem Gegner = so viel weniger Schaden je Treffer, aber höchstens die Hälfte weg.
# Gilt nicht für Dauerschaden (Laser, Brandfeld). Große Treffer (Scharfschütze, Lanze, Batterie) merken sie kaum.
const PANZERUNG_MIN_ANTEIL := 0.5
const LOCKER_RADIUS := 0.6            # lockere Formation: Abstandsradius in Feldern (zwei Lockere halten gut 1 Feld Abstand)
const SCHILD_VORLAUF_SEK := 1.5         # gestaffelt: Schildträger gehen so viele Sekunden vor dem Rest ihres Trupps los
const SCHILD_FRONT_FAKTOR := 0.25   # Schildträger: Schüsse von vorn (innerhalb SCHILD_FRONT_WINKEL zur Laufrichtung) machen nur so viel Schaden
const SCHILD_FRONT_WINKEL := 60.0
const SCHILD_DECKUNG_BREITE := 0.6   # Schildabfangen: Fläche/Strahl von vorn trifft auch die, die direkt hinter ihm stehen, nur mit SCHILD_FRONT_FAKTOR – so viele Felder seitlich der Schusslinie ...
const SCHILD_DECKUNG_TIEFE := 2.0    # ... und bis zu so vielen Feldern hinter ihm


## Entworfene Runden: Zusammensetzung der Welle Nummer `nr` (ab 1).
## Ein Trupp läuft gemeinsam im Tempo seines langsamsten Mitglieds; ein Fahnenträger macht ihn um FAHNE_BONUS schneller.
# Die 20 Wellen als Pläne: je Runde ein Name und die Trupps in der Reihenfolge, in der sie kommen.
#   weg "l" = läuft, "w" = wird von der Wurf-Schleuder geworfen (immer 4)
#   pause = Sekunden mehr (oder weniger) als TRUPP_PAUSE vor diesem Trupp
#   wenn  = "dock": Wurf, sobald ein Belagerungsturm andockt (weit weg von ihm) · "drohnen": sobald er 2 Myr-Drohnen abgesetzt hat (auf die Verteidiger am Turm)
#   jeder = nur in jedem n-ten Durchgang der letzten Runde
# Quelle: wellen-entwurf-20.xlsx (Blatt Trupps).
const WELLEN := {
	1: {"name": "Erste Rudel", "stufe": "Einführung", "trupps": [
		{"weg": "l", "typen": ["hund", "hund", "hund"]},
		{"weg": "l", "typen": ["hund", "hund", "hund"]},
	]},
	2: {"name": "Rudel", "stufe": "Einführung", "trupps": [
		{"weg": "l", "typen": ["hund", "hund", "hund", "hund"]},
		{"weg": "l", "typen": ["hund", "hund", "hund", "hund"]},
	]},
	3: {"name": "Späher", "stufe": "Einführung", "trupps": [
		{"weg": "l", "typen": ["hund", "hund", "hund", "hund", "hund"]},
		{"weg": "l", "typen": ["hund", "hund", "hund", "hund", "hund"]},
		{"weg": "l", "typen": ["sphaere"]},
	]},
	4: {"name": "Feuerschutz", "stufe": "Kombination", "trupps": [
		{"weg": "l", "typen": ["hund", "hund", "hund", "hund", "hund", "hund"]},
		{"weg": "l", "typen": ["hund", "hund", "sphaere", "sphaere"]},
		{"weg": "l", "typen": ["hund", "hund", "hund", "hund"]},
	]},
	5: {"name": "Vorstoß", "stufe": "Einführung", "trupps": [
		{"weg": "l", "typen": ["hund", "hund", "hund", "hund", "hund"]},
		{"weg": "l", "typen": ["hund", "hund", "hund", "hund", "hund"]},
		{"weg": "l", "typen": ["hund", "hund", "hund", "hund", "sphaere", "sphaere"]},
	]},
	6: {"name": "Die Fahne", "stufe": "Einführung", "trupps": [
		{"weg": "l", "typen": ["hund", "hund", "hund", "hund", "hund"]},
		{"weg": "l", "typen": ["fahne", "hund", "hund", "hund", "hund", "hund"]},
		{"weg": "l", "typen": ["sphaere", "sphaere"]},
		{"weg": "l", "typen": ["hund", "hund", "hund", "hund", "hund", "hund"]},
	]},
	7: {"name": "Kleiner Fahnensturm", "stufe": "Kombination", "trupps": [
		{"weg": "l", "typen": ["fahne", "hund", "hund", "hund", "hund"]},
		{"weg": "l", "typen": ["fahne", "hund", "hund", "hund", "hund"], "pause": -2.0},
		{"weg": "l", "typen": ["sphaere", "sphaere", "sphaere"]},
		{"weg": "l", "typen": ["hund", "hund", "hund", "hund", "hund"]},
		{"weg": "l", "typen": ["hund", "hund", "hund", "hund", "hund"]},
	]},
	8: {"name": "Sprengmeister", "stufe": "Einführung", "trupps": [
		{"weg": "l", "typen": ["hund", "hund", "hund", "hund", "hund"]},
		{"weg": "l", "typen": ["sprenger", "sprenger"]},
		{"weg": "l", "typen": ["fahne", "hund", "hund", "hund", "hund", "hund"]},
		{"weg": "l", "typen": ["sphaere", "sphaere", "sphaere"]},
		{"weg": "l", "typen": ["hund", "hund", "hund", "hund", "hund"]},
	]},
	9: {"name": "Köder", "stufe": "Kombination", "trupps": [
		{"weg": "l", "typen": ["hund", "hund", "hund", "hund", "hund", "hund", "hund", "hund", "hund", "hund"]},
		{"weg": "l", "typen": ["sprenger", "sprenger"], "pause": 17.0},
		{"weg": "l", "typen": ["schild", "schild", "hund", "hund", "hund"]},
		{"weg": "l", "typen": ["fahne", "hund", "hund", "hund", "hund"]},
		{"weg": "l", "typen": ["hund", "hund", "hund", "sphaere", "sphaere", "sphaere", "sphaere"]},
	]},
	10: {"name": "Über die Mauer", "stufe": "Einführung", "trupps": [
		{"weg": "l", "typen": ["hund", "hund", "hund", "hund", "hund"]},
		{"weg": "w", "typen": ["hund", "hund", "hund", "hund"]},
		{"weg": "l", "typen": ["fahne", "hund", "hund", "hund", "hund", "hund"]},
		{"weg": "w", "typen": ["hund", "hund", "hund", "hund"]},
		{"weg": "l", "typen": ["sphaere", "sphaere", "sphaere", "sphaere"]},
		{"weg": "l", "typen": ["sprenger", "sprenger", "hund", "hund"]},
		{"weg": "l", "typen": ["schild", "hund", "hund", "hund"]},
		{"weg": "l", "typen": ["hund", "hund", "hund", "hund"]},
	]},
	11: {"name": "Dunst", "stufe": "Einführung", "trupps": [
		{"weg": "l", "typen": ["hund", "hund", "hund", "hund", "hund"], "locker": true},
		{"weg": "l", "typen": ["rauch", "hund", "hund", "hund", "hund"]},
		{"weg": "l", "typen": ["sphaere", "sphaere", "sphaere", "sphaere"], "locker": true},
		{"weg": "w", "typen": ["hund", "hund", "hund", "hund"]},
		{"weg": "l", "typen": ["fahne", "hund", "hund", "hund", "hund", "hund"]},
		{"weg": "l", "typen": ["rauch", "sprenger", "sprenger"]},
		{"weg": "l", "typen": ["schild", "schild", "hund", "hund", "hund", "hund"]},
	]},
	12: {"name": "Nebelwand", "stufe": "Kombination", "trupps": [
		{"weg": "l", "typen": ["rauch", "rauch", "rauch"]},
		{"weg": "l", "typen": ["sphaere", "sphaere", "sphaere", "sphaere", "sphaere", "sphaere"], "locker": true},
		{"weg": "l", "typen": ["schwarm", "hund", "hund", "hund"]},
		{"weg": "w", "typen": ["hund", "hund", "hund", "hund"]},
		{"weg": "l", "typen": ["schild", "schild", "schild", "hund", "hund"]},
		{"weg": "l", "typen": ["fahne", "hund", "hund", "hund"]},
	]},
	13: {"name": "Der Turm", "stufe": "Einführung", "trupps": [
		{"weg": "l", "typen": ["schwarm", "hund", "hund", "hund"]},
		{"weg": "l", "typen": ["belagerung", "hund", "hund", "hund", "hund"]},
		{"weg": "l", "typen": ["sphaere", "sphaere", "sphaere", "sphaere"], "locker": true},
		{"weg": "w", "typen": ["hund", "hund", "hund", "hund"]},
		{"weg": "l", "typen": ["fahne", "hund", "hund", "hund", "hund", "hund"]},
		{"weg": "l", "typen": ["schild", "sphaere", "sphaere"]},
		{"weg": "l", "typen": ["schild", "schild", "hund", "hund", "hund", "hund"]},
	]},
	14: {"name": "Abrisskommando", "stufe": "Kombination", "trupps": [
		{"weg": "l", "typen": ["rauch", "rauch"]},
		{"weg": "l", "typen": ["sprenger", "sprenger", "sprenger"]},
		{"weg": "w", "typen": ["rauch", "rauch", "sprenger", "sprenger"]},
		{"weg": "l", "typen": ["sani", "sphaere", "sphaere", "sphaere", "sphaere"]},
		{"weg": "l", "typen": ["schild", "sani", "hund", "hund", "hund", "hund"]},
		{"weg": "l", "typen": ["schwarm", "hund", "hund"]},
	]},
	15: {"name": "Fahnensturm", "stufe": "Prüfung", "trupps": [
		{"weg": "l", "typen": ["fahne", "hund", "hund", "hund"]},
		{"weg": "l", "typen": ["fahne", "hund", "hund", "hund"], "pause": -2.0},
		{"weg": "l", "typen": ["fahne", "hund", "hund", "hund"], "pause": -2.0},
		{"weg": "w", "typen": ["fahne", "hund", "hund", "hund"]},
		{"weg": "l", "typen": ["schild", "schild", "sani", "schwarm"]},
		{"weg": "l", "typen": ["sphaere", "sphaere", "sphaere", "sphaere", "sphaere", "sphaere"], "locker": true},
		{"weg": "l", "typen": ["schild", "schild", "hund", "hund", "hund", "hund"]},
	]},
	16: {"name": "Zange", "stufe": "Kombination", "trupps": [
		{"weg": "l", "typen": ["hund", "hund", "hund", "hund", "hund", "hund"], "locker": true},
		{"weg": "l", "typen": ["belagerung", "hund", "hund", "hund", "hund"]},
		{"weg": "w", "typen": ["fahne", "hund", "hund", "hund"], "wenn": "dock"},
		{"weg": "w", "typen": ["hund", "hund", "hund", "hund"], "wenn": "drohnen"},
		{"weg": "l", "typen": ["fahne", "hund", "hund", "hund", "hund"]},
		{"weg": "l", "typen": ["sphaere", "sphaere", "sphaere", "sphaere", "sphaere"], "locker": true},
		{"weg": "l", "typen": ["rauch", "sprenger", "sprenger"]},
		{"weg": "l", "typen": ["schwarm", "schwarm"]},
	]},
	17: {"name": "Köder und Abriss", "stufe": "Prüfung", "trupps": [
		{"weg": "l", "typen": ["hund", "hund", "hund", "hund", "hund", "hund", "hund", "hund", "hund", "hund", "hund", "hund"]},
		{"weg": "l", "typen": ["hund", "hund", "hund", "hund", "hund", "hund"], "locker": true},
		{"weg": "l", "typen": ["rauch", "sprenger", "sprenger", "sprenger"], "pause": 17.0},
		{"weg": "w", "typen": ["sprenger", "sprenger", "hund", "hund"]},
		{"weg": "l", "typen": ["sphaere", "sphaere", "sphaere", "sphaere", "sphaere"], "locker": true},
		{"weg": "l", "typen": ["fahne", "hund", "hund", "hund", "hund", "hund"]},
		{"weg": "w", "typen": ["fahne", "hund", "hund", "hund"]},
		{"weg": "l", "typen": ["schild", "schild", "schild", "sani"]},
	]},
	18: {"name": "Doppelbelagerung", "stufe": "Prüfung", "trupps": [
		{"weg": "l", "typen": ["rauch", "rauch", "hund", "hund", "hund", "hund"]},
		{"weg": "l", "typen": ["belagerung", "hund", "hund", "hund"]},
		{"weg": "l", "typen": ["belagerung", "hund", "hund", "hund"]},
		{"weg": "w", "typen": ["hund", "hund", "hund", "hund"], "wenn": "drohnen"},
		{"weg": "l", "typen": ["sphaere", "sphaere", "sphaere", "sphaere", "sphaere", "sphaere"], "locker": true},
		{"weg": "l", "typen": ["fahne", "hund", "hund", "hund", "hund", "hund"]},
		{"weg": "w", "typen": ["fahne", "hund", "hund", "hund"]},
		{"weg": "l", "typen": ["sprenger", "sprenger"]},
		{"weg": "l", "typen": ["schwarm", "schwarm", "sani"]},
	]},
	19: {"name": "Generalprobe", "stufe": "Prüfung", "trupps": [
		{"weg": "l", "typen": ["hund", "hund", "hund", "hund", "hund", "hund", "hund", "hund"], "locker": true},
		{"weg": "l", "typen": ["fahne", "hund", "hund", "hund", "hund"]},
		{"weg": "l", "typen": ["rauch", "sprenger", "sprenger"], "pause": -2.0},
		{"weg": "w", "typen": ["rauch", "hund", "hund", "hund"]},
		{"weg": "l", "typen": ["belagerung", "hund", "hund", "hund", "hund"]},
		{"weg": "w", "typen": ["fahne", "hund", "hund", "hund"], "wenn": "dock"},
		{"weg": "l", "typen": ["rauch", "rauch", "sphaere", "sphaere", "sphaere", "sphaere", "sphaere", "sphaere"], "locker": true},
		{"weg": "l", "typen": ["fahne", "hund", "hund", "hund", "hund"]},
		{"weg": "w", "typen": ["sprenger", "sprenger", "hund", "hund"]},
		{"weg": "l", "typen": ["belagerung"]},
		{"weg": "l", "typen": ["schild", "schild", "sani", "schwarm", "schwarm"]},
	]},
	20: {"name": "Gegenangriff", "stufe": "Finale", "trupps": [
		{"weg": "l", "typen": ["hund", "hund", "hund", "hund", "hund", "hund"]},
		{"weg": "l", "typen": ["fahne", "hund", "hund", "hund", "hund"]},
		{"weg": "l", "typen": ["rauch", "sprenger", "sprenger"], "pause": -2.0},
		{"weg": "l", "typen": ["sphaere", "sphaere", "sphaere"]},
		{"weg": "w", "typen": ["fahne", "hund", "hund", "hund"]},
		{"weg": "l", "typen": ["fahne", "hund", "hund", "hund"]},
		{"weg": "l", "typen": ["rauch", "rauch", "sphaere", "sphaere", "sphaere"]},
		{"weg": "w", "typen": ["sprenger", "sprenger", "hund", "hund"]},
		{"weg": "l", "typen": ["schild", "sani", "schwarm"]},
		{"weg": "l", "typen": ["belagerung", "belagerung"], "jeder": 3},
	]},
}


## Eine Welle: was kommt, in welcher Reihenfolge, was wird geworfen. `variante` und `wurf_nr` gibt es nur noch der alten Aufrufe wegen.
static func welle(nr: int, _variante: int = 0, _wurf_nr: int = -1) -> Dictionary:
	return welle_aus_plan(WELLEN[clampi(nr, 1, LETZTE_RUNDE)], nr)


## Dasselbe für einen beliebigen Plan im Format von WELLEN (Phantom-Modus: der Plan eines Spielers).
static func welle_aus_plan(plan: Dictionary, nr: int) -> Dictionary:
	var anzahl := {}
	var trupps: Array = []     # zu Fuß: je Trupp die Typen
	var pausen: Array = []     # Sekunden mehr/weniger als TRUPP_PAUSE vor dem Trupp
	var ausgaenge: Array = []  # Phantom-Modus: wo der Trupp aus der Zone kommt
	var jeder: Array = []      # nur in jedem n-ten Durchgang (letzte Runde)
	var wurf: Array = []       # geworfen: je Trupp die Typen
	var locker: Array = []     # 17.11.: lockere Formation je Trupp
	var wurf_info: Array = []  # dazu: nach wie vielen Lauf-Trupps frühestens, und der Auslöser
	var ohne_wurf := OS.get_environment("TD_OHNE_WURF") != ""   # nur für Testläufe
	for t: Dictionary in plan["trupps"]:
		var typen: Array = (t["typen"] as Array).duplicate()
		if typen.is_empty():
			continue
		for typ: String in typen:
			anzahl[typ] = int(anzahl.get(typ, 0)) + 1
		if t["weg"] == "w" and not ohne_wurf:
			wurf.append(typen)
			var info := {"nach": trupps.size(), "wenn": t.get("wenn", "")}
			if t.has("zeit") and str(t.get("wenn", "")) == "":
				# Phantom-Modus: der Angreifer hat den Wurf auf eine feste Sekunde gelegt
				info["nach"] = 0
				info["zeit"] = float(t["zeit"])
			if t.has("ziel"):
				info["ziel"] = t["ziel"]   # Phantom-Modus: der Angreifer hat das Landefeld selbst gewählt
			wurf_info.append(info)
		else:
			trupps.append(typen)
			pausen.append(float(t.get("pause", 0.0)))
			ausgaenge.append(str(t.get("ausgang", "")))
			jeder.append(int(t.get("jeder", 1)))
			locker.append(bool(t.get("locker", false)))
	var gruppen: Array = []
	for typ: String in ["hund", "sphaere", "fahne", "sprenger", "rauch", "belagerung", "schild", "sani", "schwarm"]:
		if anzahl.has(typ):
			gruppen.append({"typ": typ, "anzahl": anzahl[typ]})
	return {
		"name": plan["name"],
		"gruppen": gruppen,
		"trupps": trupps,
		"pausen": pausen,
		"ausgaenge": ausgaenge,   # Phantom-Modus: Ausgang je Trupp ("" = Hauptlinie, "oben", "unten")
		"jeder": jeder,
		"locker": locker,
		"wurf": wurf,
		"wurf_info": wurf_info,
		"wurf_frei": bool(plan.get("wurf_frei", false)),   # Phantom-Modus: die Wurf-Schleuder wartet am Rundenanfang nicht
		"leben_faktor": snappedf(1.0 + LEBEN_JE_RUNDE * (mini(nr, LETZTE_RUNDE - 1) - 1), 0.1),   # 18.11.: Runde 20 erst wie 19; Endkampf setzt main.gd
		"abstand": 0.7,            # Sekunden zwischen zwei Gegnern
	}


## Extra-Reichweite einer Einheit in der Stellung (je Einheit verschieden).
static func stellung_bonus(daten: Dictionary) -> float:
	return daten.get("stellung_bonus", POSTEN_REICHWEITE_BONUS)


static func zinsen(budget: int) -> int:
	return mini(int(budget / float(ZINS_SCHRITT)), ZINS_STUFEN) * ZINS_JE_SCHRITT


static func wellen_bonus(nr: int) -> int:
	return BONUS_JE_WELLE + BONUS_ZUWACHS * nr + BONUS_MITTE_ZUWACHS * maxi(0, nr - BONUS_MITTE_AB + 1)
