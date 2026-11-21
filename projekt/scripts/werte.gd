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
## 18.11.: aus der Karte (Regelpaket „runden“: 10/15/20); ohne Angabe 20. Die letzte Runde ist immer der Gegenangriff.
static var LETZTE_RUNDE: int = 20      # ab dieser Runde: Gegenangriff. Gegner kommen ohne Ende, Sieg = HQ zerstört
const STANDARD_RUNDEN: int = 20
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
	"reichweite": 9.0,    # 19.11.: vorher 7 – noch aus der Zeit der 20 Spalten breiten Karte
	"abklingzeit": 6.0,
	"flugzeit": 1.3,
	"schaden_einheit": 35.0,
	"schaden_haufen": 28.0,     # 19.11.: vorher 22 – Flächentreffer auf einen Haufen Bodentruppen (jede Truppe im Umkreis)
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
const VERSION: int = 61          # 19.11.: Web-Version – je Veröffentlichung um 1 hochzählen (steht unten im Startmenü)
const BRAKK_TEMPO: float = 2.0     # 18.11.: Brakk-Mode läuft fest auf ×2 (nicht umschaltbar)
const TRUPP_PAUSE: float = 3.0     # Sekunden zwischen zwei Trupps einer Welle

# --- Wirtschaft --------------------------------------------------------
## 18.11.: Startbudget und -leben kommen aus der Karte (Regelpaket); ohne Angabe gelten die Standardwerte.
const STANDARD_BUDGET: int = 120
const STANDARD_LEBEN: int = 15
static var START_BUDGET: int = STANDARD_BUDGET
static var START_LEBEN: int = STANDARD_LEBEN
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
const BONUS_EXTRA := {3: 2}       # 18.11.: Feinschliff je Runde – nach Runde 3 zwei mehr, damit Sparen (2 Fabriken, Stufe 1) in Runde 4 genau für Stufe 2 reicht

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
const KOSTEN_STUFE: Array[int] = [125, 200, 450]   # 19.11. (Paul, gegen Fabrik-Spam): vorher 75/175/450 (14.11.: 50/150/400)      # Preis für Stufe 1, 2 und 3
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
	if stufe >= 4:   # 20.11.: Elite (Fabrik-Stufe 4, Sonde 7)
		d["leben"] = float(d["leben"]) * float(ELITE["leben"])
		d["schaden"] = float(d["schaden"]) * float(ELITE["schaden"])
		d["elite"] = true
	# 18.11. (Stufe 1): Werte-Mods einer eigenen Karte
	d["leben"] = float(d["leben"]) * mod_faktor("truppen_leben")
	d["schaden"] = float(d["schaden"]) * mod_faktor("truppen_schaden")
	if float(d["reichweite"]) > 0.0:
		d["reichweite"] = maxf(0.5, float(d["reichweite"]) + mod("truppen_reichweite"))
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
	# 20.11. (Paul, Nachtrag): Truppenturm – nur der Irrtürmer (Werte.truppenturm()), auf einem Erdwall mit genau zwei
	# Nachbarwällen, wenn keine andere Form passt (oder über die eigene Baukachel). 21.11. (Paul): Die Besatzung schießt
	# aus dem Turm; heraus kommt sie nur zu einem bedrohten Checkpoint im Umkreis „ausfall_felder“. Hält bis zu „werkschutz“ Technogunner (Werkschutz), die
	# nachkommen, wenn einer fällt (PRODUKTION_SEK / „nachschub“). Ab Turmstufe 2 kommen sie mit dem Wertepaket.
	"truppen": {"name": "Truppenturm", "form": "Zwei Nachbarwälle", "nachbarn": 2, "farbe": "c9a6ff",
		"reichweite": 3.0, "schaden": 0.0, "abklingzeit": 0.0, "werkschutz": 2, "nachschub": 1.0, "leben_mal": 1.0,
		"ausfall_felder": 4.0, "ausfall_ruhe": 3.0,
		"text": "2 Werkschutz-Truppen (Technogunner) schießen aus dem Turm und sind dort nicht angreifbar. Betritt ein Gegner einen Checkpoint im Umkreis von 4 Feldern, rücken sie dorthin aus und kehren danach zurück. Gefallene kommen nach. Nur Irrtürmer."},
	# 20.11. (Paul): PliPlop 3cK – nur der Irrtürmer (Werte.pliplop()), ohne Formvorschrift auf einem einzelnen Erdwall ohne
	# Nachbarn, mehrere erlaubt. Ab Stufe 2 ein Pfad (Werte.PLIPLOP_TURM).
	"pliplop": {"name": "PliPlop 3cK", "form": "Einzelwall", "nachbarn": 0, "farbe": "7fe0ff",
		"reichweite": 2.0, "schaden": 8.0, "abklingzeit": 0.8,
		"text": "Kleiner Turm ohne Formvorschrift: ein einzelner Erdwall ohne Nachbarwälle reicht, mehrere sind erlaubt. Schwacher Einzelschuss; ab Stufe 2 ein Pfad: Flak, Schockwelle oder Nagler. Nur Irrtürmer."},
}
# Turmupgrades (Klick auf den Turm), wie bei den Fabriken: Stufe 2 fest, auf Stufe 3 eine von zwei Fähigkeiten.
const FORMTUERME_ZAHL := 5   # 20.11. (Nachtrag): Baumeister und Formenlehre zählen die fünf Formtürme (ohne Truppenturm)
const KOSTEN_TURM_STUFE: Array[int] = [125, 300]   # Patch 17.11.: vorher 175/450 (Upgrades lohnten sich für den Schaden kaum)
const TURM_STUFE_2 := {
	"geschuetz": {"abklingzeit": 0.65, "reichweite": 4.0, "schaden": 22.0, "text": "Starke Kanone: 22 statt 16 Schaden, alle 0,65 statt 0,9 Sekunden, 4 statt 3,5 Felder."},   # 19.11.: +6 Schaden (Paul: Stufe 2 zu schwach)
	"frost": {"bremse_sek": 2.4, "bremse_tempo": 0.55, "text": "Bremst länger und stärker: 2,4 statt 1,6 Sekunden, auf 55 statt 65 % Tempo."},   # 19.11.
	"funk": {"reichweite": 3.5, "feuer_faktor": 0.7, "text": "Größerer Umkreis (3,5 statt 2,5 Felder), Stellungen feuern 30 % statt 25 % schneller."},   # 19.11.
	"lanze": {"schaden": 80.0, "text": "Stärkerer Strahl: 80 statt 45 Schaden."},   # 19.11.: vorher 65
	"heil": {"heilung": 14.0, "text": "Heilt mehr: 14 statt 8 Leben."},   # 19.11.: vorher 12
	"truppen": {"werkschutz": 3, "reichweite": 3.5, "text": "3 statt 2 Werkschutz-Truppen mit dem Wertepaket (Stufe 2): mehr Schaden, 3,5 Felder Reichweite."},   # 20.11. (Nachtrag)
	"pliplop": {"text": "Pfad wählen: Flak, Schockwelle oder Nagler."},   # 20.11. (Paul): Werte stehen in PLIPLOP_TURM
}
const TURM_STUFE_3 := {
	"pliplop": {},   # 20.11. (Paul): der PliPlop wählt seinen Pfad schon auf Stufe 2 (PLIPLOP_TURM)
	"truppen": {   # 20.11. (Nachtrag): Truppenturm (Irrtürmer)
		"nachschub": {"name": "Schneller Nachschub", "nachschub": 2.0, "text": "Werkschutz kommt doppelt so schnell nach.",
			"stark": "lange Gefechte, viele Verluste", "schwach": "nicht stärker, solange keiner fällt"},
		"panzer": {"name": "Schwere Rüstung", "leben_mal": 1.6, "text": "Werkschutz hat beim Ausfall 60 % mehr Leben.",
			"stark": "Engstellen, Nahkämpfer", "schwach": "kommt nicht schneller nach"},
	},
	"geschuetz": {
		"doppelschuss": {"name": "Doppelschuss", "ziele": 2, "text": "Trifft zwei Gegner zugleich.",
			"stark": "gegen Rudel", "schwach": "nicht stärker gegen einzelne zähe Gegner"},
		"schwer": {"name": "Schwere Munition", "schaden": 55.0, "abklingzeit": 1.1, "text": "55 statt 22 Schaden, dafür alle 1,1 Sekunden.",   # 19.11.: vorher 35 (sonst schwächer als Stufe 2)
			"stark": "gegen Belagerungsturm und Sphären", "schwach": "schwach gegen Hunderudel"},
	},
	"frost": {
		"schockfrost": {"name": "Schockfrost", "schock_sek": 0.5, "schock_alle": 6.0, "text": "Alle 6 Sekunden friert er die Gegner im Umkreis 0,5 Sekunden komplett ein.",
			"stark": "stoppt den Fahnensturm", "schwach": "dazwischen nur der normale Puls"},
		"sproede": {"name": "Sprödes Eis", "sproede": 1.15, "text": "Gegner, die er bremst, nehmen 15 % mehr Schaden von allem.",
			"stark": "stark neben Lanze und Stellungen", "schwach": "nutzlos ohne Schützen in der Nähe"},
	},
	"funk": {
		"verstaerker": {"name": "Verstärker", "feuer_faktor": 0.6, "text": "Stellungen im Umkreis feuern 40 % statt 30 % schneller.",
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
const HOF_MAX: int = 36            # 19.11.: Zitadelle bis Stufe III (6×6 innen); größere eingeschlossene Flächen zählen nicht (vorher 12)
## Zitadelle (19.11., vorher „Hof“): Stufe nach Innenfläche – I bis 4 Felder (2×2), II bis 16 (4×4), III bis 36 (6×6).
const ZITADELLE_STUFEN: Array[int] = [4, 16, 36]
const ZITADELLE_III_AB_WELLE: int = 10   # Stufe III erst ab dieser Welle (sonst deckt die Kuppel zu früh zu viel Weg)


static func zitadelle_stufe(felder: int) -> int:
	for i in ZITADELLE_STUFEN.size():
		if felder <= ZITADELLE_STUFEN[i]:
			return i + 1
	return 0

const KUPPEL_SCHUTZ: float = 0.4   # Truppen unter der Kuppel nehmen so viel weniger Schaden
const KUPPEL_RAND: float = 1.0     # Felder: so weit reicht die Kuppel über den äußersten Wall des Rings hinaus
const KOSTEN_PANZER: int = 30      # Panzerung eines Erdwalls: Die erste Sprengung nimmt nur die Panzerung
const TURM := {
	"leben": 90.0,               # so viel Schaden durch Myr-Drohnen, dann ist er für den Rest der Runde lahmgelegt
	"reichweite": 3.5,
	"schaden": 16.0,
	"abklingzeit": 0.9,
}

# --- Anführer (19.11.) --------------------------------------------------------------------------
## 19.11.: Schritt 2b – vier Anführer, einer wird vor der Partie gewählt (Liste und Texte: scripts/anfuehrer.gd).
## Der laufende steht in `anfuehrer` (beim Partiestart gesetzt; Zwischenstand, Protokoll und Phantome tragen ihn mit).
## ANFUEHRER_STANDARD sind die Regeln wie bisher (= Brakk). ANFUEHRER_WERTE überschreibt je Anführer einzelne
## Schlüssel; was fehlt, gilt wie Standard. Die Haken im Spiel fragen nur die Funktionen unten ab – für Brakk
## liefern sie genau die alten Zahlen.
static var anfuehrer := "brakk"
const ANFUEHRER_STANDARD := {
	"preis_wall": 1.0,             # Faktor auf KOSTEN_WALL
	"preis_fabrik": 1.0,           # Faktor auf KOSTEN_FABRIK (die erste; jede weitere wie gewohnt teurer)
	"preis_fabrik_stufe": 1.0,     # Faktor auf KOSTEN_STUFE (Fabrik-Stufen, nicht die Batterie)
	"preis_turm_stufe": 1.0,       # Faktor auf KOSTEN_TURM_STUFE
	"max_fabriken": 0,             # höchstens so viele Fabriken (0 = unbegrenzt; Pilotenfabriken zählen nicht)
	"turm_max_stufe": 3,           # höchste Turmstufe (mehr als 3 gibt es nicht)
	"truppen_je_fabrik": 0,        # so viele Truppen je Fabrik mehr (negativ = weniger, mindestens 1)
	"stuetze_legt_still": true,    # fehlt einem Turm eine Stütze, schweigt er
	"zins_stufen": ZINS_STUFEN,    # Zinsdeckel: so viele Schritte zählen (je ZINS_JE_SCHRITT)
	"praemie_faktor": 1.0,         # Faktor auf die Prämie je besiegtem Gegner
	"erstattung": ERSTATTUNG,      # Anteil beim Abriss von Älterem
	"start_leben": 0,              # so viele Leben mehr zu Beginn (auf das Startleben der Karte)
	"startpaket_waelle": STARTPAKET_WAELLE,   # so viele Erdwälle gratis, sobald sie frei sind
	"gesperrt": [],                # Bauwerke, die dieser Anführer nicht hat (Schlüssel wie main.gd BAUTEN, z. B. "generator")
	"figur": "brakk",              # Figur auf Slot [8] ("" = folgt in Schritt 2c, Slot gesperrt)
	"truppen_fest": 0,             # 20.11.: jede Fabrik hält genau so viele Truppen, auch spezialisiert und im Gegenangriff (0 = wie gewohnt)
	"fabrik_max_stufe": 3,         # 20.11.: höchste Fabrikstufe (4 = Elite, siehe ELITE)
	"auftraege": false,            # 20.11.: Pauls Aufträge (scripts/auftraege.gd)
	"mg_stellung": false,          # 20.11. (Nachtrag): Stellungen sind MG-Stellungen (MG_NEST)
	"truppenturm": false,          # 20.11. (Nachtrag): Formturm „Truppenturm“ auf geraden Wällen (TURMARTEN.truppen)
	"pliplop": false,              # 20.11. (Paul): PliPlop 3cK als Turm (Werte.PLIPLOP_TURM)
}
## 20.11. (Paul): Perks der drei neuen Anführer. Brakk bleibt leer = alles wie bisher.
const ANFUEHRER_WERTE := {
	"brakk": {},
	"irrtuermer": {"figur": "", "max_fabriken": 3, "turm_max_stufe": 4, "preis_turm_stufe": 0.75, "stuetze_legt_still": false,
		"startpaket_waelle": 12, "preis_fabrik_stufe": 1.2, "truppenturm": true, "pliplop": true},
	"sonde7": {"figur": "", "preis_fabrik": 0.5, "truppen_fest": 1, "preis_fabrik_stufe": 0.75, "fabrik_max_stufe": 4, "mg_stellung": true,
		"turm_max_stufe": 2, "gesperrt": ["generator"]},
	"paul": {"figur": "", "zins_stufen": 10, "praemie_faktor": 1.5, "erstattung": 1.0, "start_leben": -5, "preis_wall": 1.5,
		"auftraege": true},
}
## 20.11.: Stufe 4 (nur mit passendem Anführer). Preise vor dem Faktor des Anführers.
const KOSTEN_STUFE_4: int = 1065         # Fabrik Stufe 4: Elite-Truppe (Sonde 7) – 20.11. (Paul, Nachtrag): × 0,75 = 800 (vorher 600)
const KOSTEN_TURM_STUFE_4: int = 800     # Turm Stufe 4 (Irrtürmer) – 20.11. (Paul, Nachtrag): × 0,75 = 600 (vorher 450)
const ELITE := {"leben": 1.5, "schaden": 1.4, "groesse": 1.3, "farbe": Color(1.0, 0.86, 0.45)}   # Elite-Truppe: größer, golden – 20.11. (Paul, Nachtrag): +50 % Leben, +40 % Schaden (vorher ×2 / ×2)
const TURM_STUFE_4 := {"schaden": 1.2, "reichweite": 0.5, "leben": 2.0}   # ×Schaden, +Reichweite, ×Leben gegen Drohnen – 20.11. (Paul, Nachtrag): +20 %, +0,5 (vorher ×1,5, +1); dazu beide Stufe-3-Fähigkeiten


## 20.11. (Paul, Nachtrag): MG-Stellung (Sonde 7, Normalmodus) – jede Stellung ist ein MG-Nest. Sonst wie eine normale
## Stellung (die Truppe darf sie verlassen). Werte und Ausbau: MG_NEST, MG_AUSBAU, MG_SONDER (weiter unten).


static func mg_stellung() -> bool:
	return bool(af("mg_stellung"))


static func truppenturm() -> bool:
	return bool(af("truppenturm"))


## 20.11. (Paul): MG-Stellung ausbaubar (Sonde 7). Die Werte hängen am Nest, nicht an der Truppe: Wer darin sitzt, ist nur
## Besatzung – billige, nicht ausgebaute Truppen reichen. Stufe 1 und 2 je eine von zwei Richtungen, Stufe 3 eine
## Sonderform, die aus den beiden vorher gewählten folgt (Vorbild: BTD6-Crosspaths, Kingdom-Rush-Gimmicks, DRG-Overclocks).
const MG_NEST := {"schaden": 9.0, "abklingzeit": 0.55, "reichweite": 3.0, "farbe": "ffd34d"}   # Grund-Nest (Stufe 0)
const KOSTEN_MG_STUFE: Array[int] = [50, 100, 225]
const KOSTEN_MG_STELLUNG: int = 50   # 21.11. (Paul): die MG-Stellung selbst kostet 50 (normale Stellung: KOSTEN_STELLUNG)


static func kosten_stellung() -> int:
	return KOSTEN_MG_STELLUNG if mg_stellung() else KOSTEN_STELLUNG
const MG_AUSBAU := [
	{
		"takt": {"name": "Takt", "takt": 1.5, "text": "Feuert 50 % schneller.", "stark": "viele kleine Gegner", "schwach": "Schildträger, zähe Ziele"},
		"wucht": {"name": "Wucht", "schaden": 1.5, "text": "50 % mehr Schaden je Schuss.", "stark": "zähe Ziele", "schwach": "große Rudel"},
	},
	{
		"streuung": {"name": "Streuung", "splitter": 0.6, "splitter_anteil": 0.4, "text": "Treffer splittern: 40 % Schaden an alle im Umkreis von 0,6 Feldern.", "stark": "Trupps im Gang", "schwach": "einzelne Ziele"},
		"lafette": {"name": "Lafette", "reichweite": 1.5, "text": "+1,5 Felder Reichweite.", "stark": "lange Gänge, frühes Feuer", "schwach": "kein Mehrschaden"},
	},
]
## Stufe 3: je Kombination zwei Sonderformen. Schlüssel = "<Stufe 1>+<Stufe 2>".
const MG_SONDER := {
	"takt+streuung": {
		"sperrfeuer": {"name": "Sperrfeuer", "bremse_tempo": 0.6, "bremse_sek": 1.2, "text": "Jeder Treffer bremst alle im Splitterkreis 1,2 s auf 60 % Tempo.", "stark": "Rudel, Fahnensturm", "schwach": "kein Mehrschaden"},
		"huelsenregen": {"name": "Hülsenregen", "chance": 0.35, "sek": 6.0, "stolpern": 0.6, "hoechst": 8, "text": "Leere Hülsen bleiben 6 s liegen. Wer darüberläuft, rutscht aus und steht 0,6 s.", "stark": "Engstellen vor dem Nest", "schwach": "nur, wo das Nest hintrifft"},
	},
	"takt+lafette": {
		"leuchtspur": {"name": "Leuchtspur", "jeder": 5, "text": "Jeder 5. Schuss markiert sein Ziel: Alle Truppen treffen es härter.", "stark": "zusammen mit Truppen", "schwach": "allein wenig"},
		"kuehlkreislauf": {"name": "Kühlkreislauf", "takt": 1.25, "nachbar": 0.15, "funk": 2.0, "text": "Feuert 25 % schneller, MG-Nester bis 1,5 Felder daneben 15 % schneller (mit Funkturm in Reichweite doppelt).", "stark": "Nester in einer Reihe", "schwach": "einzelnes Nest"},
	},
	"wucht+streuung": {
		"splittergurt": {"name": "Splittergurt", "radius": 1.0, "anteil": 0.6, "text": "Wen das Nest tötet, zerplatzt: 60 % Schaden an alle im Umkreis von 1 Feld.", "stark": "dichte Trupps", "schwach": "zähe Einzelziele"},
		"ladeschuss": {"name": "Ladeschuss", "sek": 6.0, "radius": 1.1, "mal": 4.0, "text": "Alle 6 s ein Plasma-Mörser über die Mauer auf die dichteste Gruppe in Reichweite (vierfacher Schaden).", "stark": "Haufen hinter Wällen", "schwach": "langsam, verstreute Gegner"},
	},
	"wucht+lafette": {
		"railgun": {"name": "Railgun-Lauf", "breite": 0.3, "abpraller": 1, "text": "Schüsse durchschlagen alle in einer Linie und prallen einmal an einem Erdwall ab.", "stark": "lange gerade Gänge", "schwach": "verwinkelte Wege"},
		"ausguck": {"name": "Ausguck", "gross": 1.5, "text": "Sieht durch Rauch und trifft große Gegner (Belagerungsturm, Schwarmgeist …) 50 % härter.", "stark": "Rauchwerfer, große Ziele", "schwach": "Rudel"},
	},
}


## Werte eines MG-Nests auf Stufe `stufe` (0–3) mit den Wahlen `wahl` (Stufe 1, 2, 3).
static func mg_werte(stufe: int, wahl: Array) -> Dictionary:
	var d := {"schaden": float(MG_NEST["schaden"]), "abklingzeit": float(MG_NEST["abklingzeit"]), "reichweite": float(MG_NEST["reichweite"]),
		"splitter": 0.0, "splitter_anteil": 0.0, "sonder": "", "s": {}}
	if stufe >= 1 and wahl.size() >= 1:
		var a: Dictionary = MG_AUSBAU[0].get(str(wahl[0]), {})
		d["abklingzeit"] = float(d["abklingzeit"]) / float(a.get("takt", 1.0))
		d["schaden"] = float(d["schaden"]) * float(a.get("schaden", 1.0))
	if stufe >= 2 and wahl.size() >= 2:
		var b: Dictionary = MG_AUSBAU[1].get(str(wahl[1]), {})
		d["reichweite"] = float(d["reichweite"]) + float(b.get("reichweite", 0.0))
		d["splitter"] = float(b.get("splitter", 0.0))
		d["splitter_anteil"] = float(b.get("splitter_anteil", 0.0))
	if stufe >= 3 and wahl.size() >= 3:
		var s: Dictionary = mg_sonder_wahl(wahl).get(str(wahl[2]), {})
		d["sonder"] = str(wahl[2])
		d["s"] = s
		d["abklingzeit"] = float(d["abklingzeit"]) / float(s.get("takt", 1.0))
	return d


## Die zwei Sonderformen, die nach den Wahlen auf Stufe 1 und 2 offenstehen.
static func mg_sonder_wahl(wahl: Array) -> Dictionary:
	if wahl.size() < 2:
		return {}
	return MG_SONDER.get("%s+%s" % [str(wahl[0]), str(wahl[1])], {})


## 20.11. (Paul): Sonde 7 – die Spezialisierung entfällt, die erste Ausbaustufe führt gleich auf Stufe 2 (etwas teurer).
const SONDE7_DIREKT_FAKTOR := 1.25

static func fabrik_direkt_stufe_2() -> bool:
	return truppen_fest() > 0


static func preis_direkt_stufe_2() -> int:
	return roundi(kosten_stufen()[1] * SONDE7_DIREKT_FAKTOR / 5.0) * 5


## 20.11. (Paul): PliPlop 3cK als Turm im Normalmodus (Irrtürmer): ohne Formvorschrift auf einem einzelnen Erdwall ohne
## Nachbarn, mehrere erlaubt. Stufe 2 = Pfad wählen (Flak, Schockwelle, Nagler), Stufe 3 und 4 verstärken den Pfad.
const KOSTEN_PLIPLOP: int = 100
const KOSTEN_PLIPLOP_STUFE: Array[int] = [80, 160, 320]
## Je Pfad die Werte auf Stufe 2, 3, 4 (überschreiben TURMARTEN.pliplop).
const PLIPLOP_TURM := {
	"flak": {"name": "Flak", "ring": "laser", "text": "Splittergranaten: Schaden an alle im Umkreis des Ziels.", "stark": "Rudel, Trupps", "schwach": "zähe Einzelziele",
		"stufen": [
			{"schaden": 12.0, "abklingzeit": 1.1, "radius": 0.8, "reichweite": 2.5, "text": "Granaten mit 0,8 Feldern Umkreis, 12 Schaden."},
			{"schaden": 18.0, "abklingzeit": 1.0, "radius": 1.0, "reichweite": 2.5, "text": "Größerer Umkreis (1 Feld), 18 Schaden."},
			{"schaden": 26.0, "abklingzeit": 0.9, "radius": 1.2, "reichweite": 3.0, "nachbrand": 0.5, "text": "Umkreis 1,2 Felder, 26 Schaden, Splitter brennen nach (halber Schaden)."}]},
	"schockwelle": {"name": "Schockwelle", "ring": "plasmagel", "text": "Kein Schaden: markiert alle in Reichweite und stößt Nahkämpfer zurück.", "stark": "zusammen mit Truppen, Engstellen", "schwach": "allein kein Schaden",
		"stufen": [
			{"schaden": 0.0, "abklingzeit": 3.0, "reichweite": 2.0, "mark_sek": 2.0, "stoss": 0.6, "text": "Alle 3 s: markiert 2 s, stößt 0,6 Felder zurück."},
			{"schaden": 0.0, "abklingzeit": 2.6, "reichweite": 2.5, "mark_sek": 3.0, "stoss": 0.8, "text": "Alle 2,6 s, Reichweite 2,5: markiert 3 s, stößt 0,8 Felder zurück."},
			{"schaden": 0.0, "abklingzeit": 2.2, "reichweite": 3.0, "mark_sek": 4.0, "stoss": 1.0, "bremse": 1.5, "text": "Alle 2,2 s, Reichweite 3: markiert 4 s, stößt 1 Feld zurück und bremst 1,5 s."}]},
	"nagler": {"name": "Nagler", "ring": "markierung", "text": "Einzelziel: Jeder Treffer am selben Gegner macht 10 % mehr Schaden.", "stark": "Belagerungsturm, Schwarmgeist", "schwach": "Rudel",
		"stufen": [
			{"schaden": 10.0, "abklingzeit": 0.5, "reichweite": 2.5, "je_treffer": 0.10, "hoechst": 1.0, "text": "10 Schaden alle 0,5 s, +10 % je Treffer am selben Ziel (bis doppelt)."},
			{"schaden": 13.0, "abklingzeit": 0.45, "reichweite": 3.0, "je_treffer": 0.12, "hoechst": 1.5, "text": "13 Schaden, +12 % je Treffer (bis 2,5-fach), Reichweite 3."},
			{"schaden": 16.0, "abklingzeit": 0.4, "reichweite": 3.5, "je_treffer": 0.15, "hoechst": 2.0, "text": "16 Schaden, +15 % je Treffer (bis dreifach), Reichweite 3,5."}]},
}


static func pliplop() -> bool:
	return bool(af("pliplop"))


static func kosten_pliplop_stufen() -> Array[int]:
	return _af_preise(KOSTEN_PLIPLOP_STUFE, "preis_turm_stufe")


## 20.11. (Nachtrag): Texte zu Stufe 4 aus den Werten (Fabrikmenü, Meldungen, Anführer-Perks).
static func turm4_text() -> String:
	return "+%d %% Schaden, +%s Reichweite, beide Stufe-3-Fähigkeiten" % [roundi((float(TURM_STUFE_4["schaden"]) - 1.0) * 100.0), str(TURM_STUFE_4["reichweite"]).replace(".", ",")]


static func elite_text() -> String:
	return "+%d %% Leben, +%d %% Schaden" % [roundi((float(ELITE["leben"]) - 1.0) * 100.0), roundi((float(ELITE["schaden"]) - 1.0) * 100.0)]


## Anführer festlegen; unbekannt oder leer (alte Dateien) = Brakk.
static func setze_anfuehrer(id: String) -> void:
	anfuehrer = id if ANFUEHRER_WERTE.has(id) else "brakk"


## Wert des laufenden Anführers (sonst Standard).
static func af(schluessel: String) -> Variant:
	var eigen: Dictionary = ANFUEHRER_WERTE.get(anfuehrer, {})
	return eigen.get(schluessel, ANFUEHRER_STANDARD[schluessel])


static func _af_preis(preis: int, schluessel: String) -> int:
	var f := float(af(schluessel))
	return preis if f == 1.0 else roundi(preis * f)


static func _af_preise(preise: Array[int], schluessel: String) -> Array[int]:
	var f := float(af(schluessel))
	if f == 1.0:
		return preise
	var aus: Array[int] = []
	for p: int in preise:
		aus.append(roundi(p * f / 5.0) * 5)
	return aus


static func kosten_wall() -> int:
	return _af_preis(KOSTEN_WALL, "preis_wall")


static func kosten_fabrik() -> int:
	return _af_preis(KOSTEN_FABRIK, "preis_fabrik")


static func kosten_stufen() -> Array[int]:
	if fabrik_max_stufe() < 4:
		return _af_preise(KOSTEN_STUFE, "preis_fabrik_stufe")
	var mit_4: Array[int] = KOSTEN_STUFE.duplicate()   # 20.11.: Stufe 4 (Elite)
	mit_4.append(KOSTEN_STUFE_4)
	return _af_preise(mit_4, "preis_fabrik_stufe")


static func kosten_turm_stufen() -> Array[int]:
	if turm_max_stufe() < 4:
		return _af_preise(KOSTEN_TURM_STUFE, "preis_turm_stufe")
	var mit_4: Array[int] = KOSTEN_TURM_STUFE.duplicate()   # 20.11.: Stufe 4 (Wertepaket)
	mit_4.append(KOSTEN_TURM_STUFE_4)
	return _af_preise(mit_4, "preis_turm_stufe")


static func turm_max_stufe() -> int:
	return clampi(int(af("turm_max_stufe")), 1, 4)


static func fabrik_max_stufe() -> int:
	return clampi(int(af("fabrik_max_stufe")), 1, 4)


static func truppen_fest() -> int:
	return int(af("truppen_fest"))


static func auftraege_an() -> bool:
	return bool(af("auftraege"))


static func max_fabriken() -> int:
	return int(af("max_fabriken"))


static func truppen_je_fabrik() -> int:
	return int(af("truppen_je_fabrik"))


static func stuetze_legt_still() -> bool:
	return bool(af("stuetze_legt_still"))


static func zins_stufen() -> int:
	return int(af("zins_stufen"))


static func praemie(betrag: int) -> int:
	var f := float(af("praemie_faktor"))
	return betrag if f == 1.0 else roundi(betrag * f)


static func erstattung() -> float:
	return float(af("erstattung"))


static func start_leben() -> int:
	return maxi(1, START_LEBEN + int(af("start_leben")))


static func startpaket_waelle() -> int:
	return int(af("startpaket_waelle"))


static func af_gesperrt(bau: String) -> bool:
	return (af("gesperrt") as Array).has(bau)


static func figur() -> String:
	return str(af("figur"))


# --- Anführer Ego (20.11.) ----------------------------------------------------------------------
## 20.11.: Schritt 6b – Anführer im Brakk-Mode (Ego-Sicht). Gleicher Wert `anfuehrer` wie im Normalmodus, beim Start des
## Brakk-Mode gesetzt. Hier stehen nur die Ego-Daten; Name, Initiale, Farbe und Freischalt-Erfolg kommen aus anfuehrer.gd.
## Die Anführer werden nur ausgetauscht: keine Perks aus dem Normalmodus. Ringe sind für alle das Build-System.
##   tasten: Taste -> Aktion. Tasten: links, rechts (Maus), Q, E, R, V, X, C, shift, leertaste. Die Steuerung liest
##           ego_modus.gd einmal; je Anführer zählt nur diese Belegung (Brakk: genau wie bisher).
##   leben, tempo: Faktor auf Brakks Leben (Werte.KOMMANDANT) bzw. Lauftempo in der Ego-Sicht.
##   ab: 20.11. (Nachtrag) ab welcher Heldenstufe eine Aktion geht (nicht genannt = von Anfang an; Brakk: BrakkFortschritt.AB).
##       Grundangriff ab Stufe 1, [R] zuletzt. Brakks Bewegungen, die ein Anführer nicht in der Belegung hat, fehlen ihm.
##   kit: drei Zeilen für Auswahlbild und Übersicht.
## Alle Zahlen sind Startwerte (Paul spielt es).
const ANFUEHRER_EGO := {
	"brakk": {"leben": 1.0, "tempo": 1.0, "ab": {},
		"tasten": {"links": "pistolen", "rechts": "lanze", "Q": "anker", "E": "treppe", "R": "ulti", "V": "zeitlupe", "X": "saeule",
			"C": "feld", "shift": "tumble", "leertaste": "sprung"},
		"kit": ["Zwei Pistolen, Ladestrahl, Lichtsäule", "Lichttreppe, Anker, Rolle, Doppelsprung", "Ring-Signatur: Zeitlupe je Ring"]},
	"irrtuermer": {"leben": 0.9, "tempo": 1.0,
		"ab": {"tumble": 2, "hierher": 2, "hack": 3, "ueberladen": 4, "ringtausch": 6, "aufsatz": 7},
		"tasten": {"links": "prellbolzen", "rechts": "hack", "Q": "ueberladen", "E": "treppe", "R": "aufsatz", "V": "ringtausch", "X": "hierher",
			"C": "feld", "shift": "tumble", "leertaste": "sprung"},
		"kit": ["Prellbolzen und Hack auf Türme", "Begleitturm PliPlop rollt mit", "Ring-Signatur: zwei Ringsätze (je 4) + Verbund"]},
	"sonde7": {"leben": 0.8, "tempo": 1.05,
		"ab": {"schub": 2, "doppellaser": 3, "teleport": 4, "schrot": 5, "sondengewehr": 6, "luftschlag": 7},
		"tasten": {"links": "hand_links", "rechts": "hand_rechts", "Q": "teleport", "E": "doppellaser", "R": "luftschlag", "V": "schrot", "X": "sondengewehr",
			"C": "feld", "shift": "schub", "leertaste": "schweben"},
		"kit": ["Schwebt mit Düsen, Schub und Teleport", "Ruft vier Waffen mit Magazin", "Ring-Signatur: Hand und Erfassungstreffer"]},
}
## Namen der Aktionen (Übersicht, Reiter „Anführer“).
const EGO_AKTIONEN := {
	"pistolen": "Pistolen", "lanze": "Ladestrahl (halten)", "anker": "Lichtanker", "treppe": "Lichttreppe / -brücke", "ulti": "Klonmaschine",
	"zeitlupe": "Zeitlupe", "saeule": "Lichtsäule", "feld": "Ringfeld (Bauphase)", "tumble": "Rolle", "sprung": "Springen",
	"prellbolzen": "Prellbolzen", "hack": "Hack (halten)", "ueberladen": "Überladen", "aufsatz": "Aufsatz", "ringtausch": "Ringtausch",
	"hierher": "Hierher! / Folgen",
	"hand_links": "Farblaser / linke Waffe", "hand_rechts": "Energiebündel / rechte Waffe", "teleport": "Teleport", "doppellaser": "Doppel-Lasergewehr",
	"luftschlag": "Luftschlag", "schrot": "Schrotflinte", "sondengewehr": "Sondengewehr", "schub": "Schub", "schweben": "Schweben (halten)",
}
## Reihenfolge der Tasten in Übersicht und Auswahl.
const EGO_TASTEN: Array[String] = ["links", "rechts", "Q", "E", "R", "V", "X", "C", "shift", "leertaste"]
const EGO_TASTEN_NAME := {"links": "Linksklick", "rechts": "Rechtsklick", "shift": "Shift", "leertaste": "Leertaste"}


## 20.11.: Irrtürmer – Mauern und Gefährte (scripts/ego_irrtuermer.gd, scripts/pliplop.gd). Felder in Feldern, Zeiten in
## Sekunden (Echtzeit). Schaden des Prellbolzens und des PliPlop wächst mit der Stufe wie Brakks (BrakkFortschritt.schaden_faktor).
const IRRTUERMER := {
	"bolzen": {"schaden": 13.0, "takt": 0.42, "tempo": 15.0, "weite": 14.0, "abpraller": 2, "flaeche": 0.6,   # 20.11. (Paul): Schaden vorher 16 – Irrtürmer war in den Bot-Partien am stärksten
		"stoss_naehe": 1.0, "stoss_radius": 1.6, "stoss": 1.2},   # platzt er so nah am PliPlop, stößt er Nahkämpfer im Umkreis so weit weg
	"hack": {"weite": 4.0, "tempo": 0.6, "mal": 1.0},   # Reichweite, Lauftempo beim Halten, Faktor auf den Schaden des gehackten Schusses
	"ueberladen": {"sek": 6.0, "abkling": 15.0, "mal": 2.0},
	"aufsatz": {"sek": 8.0, "tempo": 0.7, "leer": 10.0},   # einmal je Runde; danach ist der PliPlop so lange leer
	"verbund": {"fenster": 2.0, "bonus": 1.3},             # Effekte beider Ringe innerhalb des Fensters: +30 % Schaden
	"pliplop": {"leben": 0.6, "abstand": 1.5, "tempo": 3.4, "respawn": 10.0, "nah_schaden": 1.0},   # Leben: Anteil vom Irrtürmer
}
## Pfad des PliPlop je getragenem Ring (Stufe des Rings = Stufe des Pfads; je Stufe über 1 „je_stufe“ mehr Schaden).
## art: einzel (ein Ziel), mehr (mehrere Ziele), welle (alle im Umkreis um den PliPlop), flaeche (Einschlag am Ziel),
## linie (durch alle in einer Linie), sprung (springt weiter). Zusätze: bremse (s), brand (Brandfeld), schutz (PliPlop nimmt
## weniger Schaden), ziele, spruenge, radius. Der Ring-Effekt (BrakkFortschritt.RINGE brakk_stufen) kommt bei jedem Treffer dazu.
const PLIPLOP_JE_STUFE := 0.25
const PLIPLOP_PFADE := {
	"": {"name": "Grundschuss", "art": "einzel", "schaden": 12.0, "takt": 1.0, "weite": 4.0},
	"plasmagel": {"name": "Schockwelle", "art": "welle", "schaden": 9.0, "takt": 1.6, "weite": 2.0, "bremse": 1.0},
	"laser": {"name": "Flak", "art": "flaeche", "schaden": 8.0, "takt": 0.35, "weite": 5.0, "radius": 0.6},
	"markierung": {"name": "Nagler", "art": "einzel", "schaden": 38.0, "takt": 1.5, "weite": 6.0},
	"durchschuss": {"name": "Bohrer", "art": "linie", "schaden": 18.0, "takt": 1.2, "weite": 5.0},
	"feuerteam": {"name": "Repetierer", "art": "einzel", "schaden": 5.0, "takt": 0.2, "weite": 4.0},
	"minigun": {"name": "Kreisel", "art": "mehr", "schaden": 8.0, "takt": 0.5, "weite": 3.5, "ziele": 3},
	"bollwerk": {"name": "Prellschild", "art": "einzel", "schaden": 10.0, "takt": 1.0, "weite": 3.5, "schutz": 0.3},
	"abpraller": {"name": "Bogenblitz", "art": "sprung", "schaden": 12.0, "takt": 1.1, "weite": 4.0, "spruenge": 3},
	"brandfeld": {"name": "Brandmörser", "art": "flaeche", "schaden": 12.0, "takt": 2.0, "weite": 5.0, "radius": 1.0, "brand": true},
}


## 20.11.: Sonde 7 – Luft und Schützin (scripts/ego_sonde.gd). Felder in Feldern, Zeiten in Sekunden (Echtzeit).
## Schaden wächst mit der Stufe wie Brakks (BrakkFortschritt.schaden_faktor). Ring-Signatur: der aktive Ring (Mausrad)
## färbt die Hand (Laserfarbe, Effekt des Energiebündels) und die Erfassungstreffer; gerufene Waffen bekommen vom Ring nur
## ihr Geschossbild. Waffen: [Taste] ruft sie mit vollem Magazin, leer löst sie sich auf (dann Cooldown), dieselbe Taste
## steckt sie vorzeitig weg (Rest verfällt, Cooldown läuft).
const SONDE7 := {
	"schweben": {"akku": 5.0, "laden": 4.0, "steigen": 2.6, "sinken": 1.4, "hoehe": 3.2, "doppel": 0.3},   # laden: leer → voll am Boden
	"schub": {"felder": 3.0, "dauer": 0.25, "akku": 1.0, "abkling": 1.2},
	"teleport": {"weite": 6.0, "abkling": 8.0},
	# 20.11. (Paul, Nachtrag): Hand-Laser und Doppel-Lasergewehr – so viele Sekunden Dauerfeuer bis zur Überhitzung (ab Stufe
	# „spaet_ab“ länger), dann „pause“ gesperrt; ohne Feuern kühlt es „kuehl“-mal so schnell ab, wie es sich aufheizt.
	"hitze": {"sek": 6.0, "sek_spaet": 8.0, "spaet_ab": 5, "pause": 1.5, "kuehl": 2.0},
	"hand": {"laser_schaden": 5.0, "laser_takt": 0.1, "weite": 12.0,
		"buendel_schaden": 34.0, "buendel_takt": 0.9, "buendel_tempo": 7.0, "buendel_flaeche": 0.7},
	"doppellaser": {"magazin": 40, "abkling": 10.0, "schaden": 9.0, "takt": 0.12, "weite": 12.0,
		"erfassen": [4, 6, 8], "erfassen_ab": [1, 4, 7], "erfassen_sek": 6.0, "erfassung_mal": 1.4},   # erfassen: Ziele ab Stufe erfassen_ab
	"schrot": {"magazin": 8, "abkling": 12.0, "schaden": 9.0, "kugeln": 8, "streuung": 16.0, "weite": 4.5, "takt": 0.7, "nachladen": 2.0},
	"sondengewehr": {"magazin": 4, "abkling": 12.0, "laden": 0.8, "schaden": 80.0, "weite": 6.0, "blick_sek": 6.0, "blick_bonus": 1.25, "blick_weite": 14.0},
	"luftschlag": {"magazin": 8, "sek": 8.0, "schaden": 70.0, "radius": 1.5, "takt": 0.5, "tempo": 9.0, "hoehe": 2.4},   # hoehe: dorthin steigt sie
}
## Welche Taste ruft welche Waffe (Reihenfolge = Anzeige); Belegung steht in ANFUEHRER_EGO.
const SONDE7_WAFFEN: Array[String] = ["doppellaser", "schrot", "sondengewehr", "luftschlag"]
const SONDE7_WAFFEN_NAME := {"": "Hand", "doppellaser": "Doppel-Lasergewehr", "schrot": "Schrotflinte", "sondengewehr": "Sondengewehr", "luftschlag": "Luftschlag"}


## 20.11. (Paul, Nachtrag): Ring-Wirkung je Fähigkeit („Spell“) – was der Ring an der Fähigkeit ändert. Es zählt der
## aktive Ring beim Auslösen (Irrtürmer: aktiver Ring des Helden, Sonde 7: aktiver Ring). Höchstens eine Wirkung je Ring
## und Spell; fehlt ein Ring, hat er an diesem Spell keine Wirkung (lieber nichts als etwas Erzwungenes). Keine Dopplung
## mit dem Grundschuss: beim Irrtürmer wirken Markierung, Bremse, Brand und Sprung schon auf jeden Hack-Treffer (über
## den Held-Satz) – dort steht deshalb nichts; die Waffen der Sonde 7 tragen sonst keinen Ring-Effekt.
## art: Schlüssel, den der Code abfragt (EgoKit.spell_w); wert: Stärke auf Ringstufe 1, je Stufe darüber +RING_SPELL_JE_STUFE
## (Einheiten im Text, {w} = Wert auf der aktuellen Stufe); vorbild: woran es sich orientiert. Auch die Übersicht [I]
## liest diese Tabelle.
const RING_SPELL_JE_STUFE := 0.25
const RING_SPELLS := {
	"irrtuermer": {
		"hack": {
			"laser": {"art": "turm_takt", "wert": 30.0, "text": "Der gehackte Turm glüht: er selbst feuert {w} % schneller, solange du hackst.", "vorbild": "Deep Rock Galactic (Overclock)"},
			"feuerteam": {"art": "echo", "wert": 40.0, "text": "Echo: jeder gehackte Schuss wiederholt sich kurz danach mit {w} % Schaden.", "vorbild": "Path of Exile (Spell Echo)"},
			"minigun": {"art": "anlauf", "wert": 50.0, "text": "Anlauf: je länger du hältst, desto mehr Schaden – bis +{w} % nach 4 s.", "vorbild": "Deep Rock Galactic (Minigun)"},
			"bollwerk": {"art": "schutz", "wert": 25.0, "text": "Solange du hackst, nimmst du {w} % weniger Schaden.", "vorbild": "Overwatch (Orisa: Festung)"},
			"plasmagel": {"art": "gelstrahl", "wert": 1.5, "text": "Der Hack-Strahl wird zäh: Gegner, die ihn kreuzen, sind {w} s gebremst.", "vorbild": "Overwatch (Symmetra-Strahl)"},
			"durchschuss": {"art": "durch", "wert": 50.0, "text": "Gehackte Schüsse treffen auch den nächsten Gegner dahinter ({w} % Schaden).", "vorbild": "Path of Exile (Pierce)"},
			"markierung": {"art": "zielsuche", "wert": 0.0, "text": "Zielsuche: gehackte Schüsse gehen von selbst an den stärksten Gegner in Reichweite.", "vorbild": "Risk of Rain 2 (ATG-Rakete)"},
		},
		"ueberladen": {
			"laser": {"art": "hitzestoss", "wert": 200.0, "text": "Zum Schluss stößt der Turm eine Hitzewelle aus: {w} % Bolzenschaden im Umkreis von 1,5 Feldern.", "vorbild": "Hades (Gabe am Ende einer Wirkung)"},
			"feuerteam": {"art": "abkling", "wert": 30.0, "text": "Abklingzeit {w} % kürzer.", "vorbild": "Overwatch-Perks"},
			"minigun": {"art": "dauer", "wert": 50.0, "text": "Hält {w} % länger.", "vorbild": "Warframe (Dauer-Mod)"},
			"bollwerk": {"art": "truppenschild", "wert": 20.0, "text": "Truppen im Umkreis von 2 Feldern bekommen einen Schild ({w} % ihres Lebens, 8 s).", "vorbild": "Overwatch (Brigitte)"},
			"plasmagel": {"art": "bremswelle", "wert": 2.0, "text": "Beim Auslösen bremst eine Gelwelle alle Gegner im Umkreis von 2 Feldern {w} s.", "vorbild": "Hades (Demeter)"},
			"markierung": {"art": "markwelle", "wert": 4.0, "text": "Beim Auslösen werden alle Gegner im Umkreis von 2,5 Feldern {w} s markiert.", "vorbild": "Path of Exile (Mark-Fluch)"},
			"abpraller": {"art": "zweiter_turm", "wert": 50.0, "text": "Springt auf den nächsten Turm in 3 Feldern über ({w} % der Dauer).", "vorbild": "Risk of Rain 2 (Ukulele)"},
		},
		"hierher": {
			"abpraller": {"art": "springen", "wert": 0.0, "text": "PliPlop springt sofort zum Punkt, statt hinzurollen.", "vorbild": "Overwatch (Winston: Sprung)"},
			"bollwerk": {"art": "pp_schutz", "wert": 30.0, "text": "Am Haltepunkt gräbt sich PliPlop ein: {w} % weniger Schaden.", "vorbild": "Overwatch (Bastion, Torbjörn)"},
			"feuerteam": {"art": "pp_takt", "wert": 20.0, "text": "Am Haltepunkt feuert PliPlop {w} % schneller.", "vorbild": "Overwatch (Bastion: Geschützmodus)"},
			"markierung": {"art": "pp_weite", "wert": 1.0, "text": "Am Haltepunkt reicht PliPlop {w} Feld weiter.", "vorbild": "Team Fortress 2 (Sentry auf der Anhöhe)"},
			"plasmagel": {"art": "ankunft_bremse", "wert": 2.5, "text": "Bei der Ankunft platzt eine Gelpfütze: Gegner im Umkreis von 1,5 Feldern {w} s gebremst.", "vorbild": "Hades (Dionysos)"},
			"brandfeld": {"art": "ankunft_brand", "wert": 1.0, "text": "Bei der Ankunft brennt der Boden ({w} Feld Umkreis).", "vorbild": "Binding of Isaac (Brandspur)"},
		},
		"ringtausch": {
			"feuerteam": {"art": "tausch_takt", "wert": 25.0, "text": "Nach dem Tausch feuern Irrtürmer und PliPlop 3 s {w} % schneller.", "vorbild": "Warframe (Tactical Reload)"},
			"bollwerk": {"art": "pp_heilen", "wert": 15.0, "text": "Der Tausch heilt PliPlop um {w} % seines Lebens.", "vorbild": "Hades (Gabe beim Wechsel)"},
			"plasmagel": {"art": "tausch_bremse", "wert": 1.5, "text": "Der Tausch bremst Gegner um Irrtürmer und PliPlop (1,5 Felder) {w} s.", "vorbild": "Hades (Demeter)"},
		},
		"aufsatz": {
			"minigun": {"art": "dauer", "wert": 3.0, "text": "Hält {w} s länger.", "vorbild": "Warframe (Dauer-Mod)"},
			"bollwerk": {"art": "schutz", "wert": 30.0, "text": "Während des Aufsatzes {w} % weniger Schaden.", "vorbild": "Overwatch (Bastion)"},
			"feuerteam": {"art": "aufsatz_takt", "wert": 25.0, "text": "Der Aufsatz feuert {w} % schneller.", "vorbild": "Deep Rock Galactic (Overclock)"},
			"laser": {"art": "hitzestoss", "wert": 300.0, "text": "Zum Schluss Hitzestoß um dich: {w} % Bolzenschaden im Umkreis von 2 Feldern.", "vorbild": "Hades (Gabe am Ende einer Wirkung)"},
			"durchschuss": {"art": "durch", "wert": 50.0, "text": "Aufsatz-Schüsse treffen auch den Gegner dahinter ({w} % Schaden).", "vorbild": "Risk of Rain 2 (Durchschlag)"},
		},
	},
	"sonde7": {
		"schub": {
			"bollwerk": {"art": "schutz_nach", "wert": 50.0, "text": "Nach dem Schub 1 s {w} % weniger Schaden.", "vorbild": "Hades (Dash-Gabe)"},
			"plasmagel": {"art": "spur_bremse", "wert": 2.0, "text": "Gelspur: Gegner auf dem Weg sind {w} s gebremst.", "vorbild": "Hades (Dionysos-Dash)"},
			"brandfeld": {"art": "spur_brand", "wert": 0.8, "text": "Start- und Zielpunkt brennen ({w} Feld Umkreis).", "vorbild": "Binding of Isaac (Brandspur)"},
			"feuerteam": {"art": "abkling", "wert": 35.0, "text": "Abklingzeit {w} % kürzer.", "vorbild": "Overwatch-Perks"},
		},
		"teleport": {
			"abpraller": {"art": "blitz", "wert": 3.0, "text": "Am Ziel springt ein Blitz auf bis zu {w} Gegner (halber Bündelschaden).", "vorbild": "Risk of Rain 2 (Ukulele)"},
			"plasmagel": {"art": "bremse_ziel", "wert": 2.0, "text": "Die Ankunft bremst Gegner im Umkreis von 1,5 Feldern {w} s.", "vorbild": "Hades (Demeter)"},
			"laser": {"art": "hitzestoss", "wert": 150.0, "text": "Der Abflugort explodiert: {w} % Bündelschaden im Umkreis von 1,5 Feldern.", "vorbild": "Overwatch (Tracer: Rückblende-Bombe)"},
			"bollwerk": {"art": "schutz_nach", "wert": 40.0, "text": "Nach dem Teleport 2 s {w} % weniger Schaden.", "vorbild": "Hades (Dash-Gabe)"},
			"feuerteam": {"art": "abkling", "wert": 30.0, "text": "Abklingzeit {w} % kürzer.", "vorbild": "Overwatch-Perks"},
			"markierung": {"art": "erfassen", "wert": 3.0, "text": "Bis zu {w} Gegner am Ziel werden erfasst (für das Doppel-Lasergewehr).", "vorbild": "Overwatch (Soldier: Taktisches Visier)"},
		},
		"doppellaser": {
			"markierung": {"art": "erfassen_plus", "wert": 2.0, "text": "Erfasst {w} Ziele mehr.", "vorbild": "Overwatch (Soldier: Taktisches Visier)"},
			"feuerteam": {"art": "magazin", "wert": 25.0, "text": "Magazin {w} % größer.", "vorbild": "Warframe (Magazin-Mod)"},
			"durchschuss": {"art": "durch", "wert": 50.0, "text": "Schüsse treffen auch den Gegner dahinter ({w} % Schaden).", "vorbild": "Binding of Isaac (Kugeln durchdringen)"},
			"minigun": {"art": "anlauf", "wert": 40.0, "text": "Anlauf: Dauerfeuer wird schneller, bis +{w} % nach 3 s.", "vorbild": "Deep Rock Galactic (Minigun)"},
			"plasmagel": {"art": "bremse_treffer", "wert": 0.5, "text": "Treffer bremsen {w} s.", "vorbild": "Hades (Demeter)"},
		},
		"schrot": {
			"markierung": {"art": "streuung", "wert": 40.0, "text": "Engere Streuung: {w} % weniger.", "vorbild": "Deep Rock Galactic (Overclock „Compact Shells“)"},
			"feuerteam": {"art": "magazin", "wert": 40.0, "text": "Magazin {w} % größer.", "vorbild": "Warframe (Magazin-Mod)"},
			"plasmagel": {"art": "bremse_treffer", "wert": 1.0, "text": "Treffer bremsen {w} s.", "vorbild": "Hades (Demeter)"},
			"brandfeld": {"art": "treffer_brand", "wert": 0.8, "text": "Jede Salve setzt den Boden beim ersten Treffer in Brand ({w} Feld Umkreis).", "vorbild": "Binding of Isaac (Brandspur)"},
			"laser": {"art": "glut", "wert": 30.0, "text": "Glühende Schrote: Getroffene brennen nach – {w} % des Schadens über 3 s.", "vorbild": "Binding of Isaac (Fire Mind)"},
			"durchschuss": {"art": "durch", "wert": 50.0, "text": "Kugeln treffen auch den Gegner dahinter ({w} % Schaden).", "vorbild": "Risk of Rain 2 (Durchschlag)"},
		},
		"sondengewehr": {
			"markierung": {"art": "blick_dauer", "wert": 3.0, "text": "Der Sondenblick hält {w} s länger.", "vorbild": "Overwatch (Widowmaker: Infrarotsicht)"},
			"feuerteam": {"art": "laden", "wert": 25.0, "text": "Lädt {w} % schneller.", "vorbild": "Deep Rock Galactic (Overclock)"},
			"laser": {"art": "glut", "wert": 40.0, "text": "Getroffene glühen nach: {w} % des Schadens über 3 s.", "vorbild": "Binding of Isaac (Fire Mind)"},
			"plasmagel": {"art": "bremse_treffer", "wert": 2.0, "text": "Treffer bremsen {w} s.", "vorbild": "Hades (Demeter)"},
			"abpraller": {"art": "blitz", "wert": 2.0, "text": "Vom letzten Getroffenen springt ein Blitz auf {w} Gegner (30 % Schaden).", "vorbild": "Risk of Rain 2 (Ukulele)"},
		},
		"luftschlag": {
			"brandfeld": {"art": "treffer_brand", "wert": 1.0, "text": "Jede Granate hinterlässt ein Brandfeld ({w} Feld Umkreis).", "vorbild": "Worms (Napalm)"},
			"plasmagel": {"art": "bremse_treffer", "wert": 1.5, "text": "Einschläge bremsen {w} s.", "vorbild": "Hades (Demeter)"},
			"feuerteam": {"art": "magazin", "wert": 40.0, "text": "Magazin {w} % größer.", "vorbild": "Warframe (Magazin-Mod)"},
			"minigun": {"art": "dauer", "wert": 3.0, "text": "Hält {w} s länger.", "vorbild": "Warframe (Dauer-Mod)"},
			"bollwerk": {"art": "schutz", "wert": 30.0, "text": "Während des Luftschlags {w} % weniger Schaden.", "vorbild": "Overwatch (Pharah: Schwebeflug)"},
			"abpraller": {"art": "nachschlag", "wert": 50.0, "text": "Jede Granate springt einmal weiter: zweiter Einschlag 1 Feld dahinter mit {w} % Schaden.", "vorbild": "Worms (Clusterbombe)"},
		},
	},
}


## Ring-Wirkung an einem Spell ({} = keine). `stufe` = Ringstufe 1–3.
static func ring_spell(af: String, spell: String, ring: String) -> Dictionary:
	return ((RING_SPELLS.get(af, {}) as Dictionary).get(spell, {}) as Dictionary).get(ring, {})


## Wert auf Ringstufe `stufe` (je Stufe über 1 +RING_SPELL_JE_STUFE).
static func ring_spell_wert(e: Dictionary, stufe: int) -> float:
	return float(e.get("wert", 0.0)) * (1.0 + RING_SPELL_JE_STUFE * float(clampi(stufe, 1, 3) - 1))


## Text mit eingesetztem Wert („{w}“).
static func ring_spell_text(e: Dictionary, stufe: int) -> String:
	var w := ring_spell_wert(e, stufe)
	var s := ("%d" % roundi(w)) if absf(w - roundf(w)) < 0.05 else ("%.1f" % w).replace(".", ",")
	return str(e.get("text", "")).replace("{w}", s)


## Anführer, die es im Brakk-Mode gibt (Brakk, Irrtürmer, Sonde 7).
static func ego_hat(id: String) -> bool:
	return ANFUEHRER_EGO.has(id)


## Ego-Wert des laufenden Anführers (unbekannt = Brakk).
static func ego_af(schluessel: String) -> Variant:
	var d: Dictionary = ANFUEHRER_EGO.get(anfuehrer, ANFUEHRER_EGO["brakk"])
	return d[schluessel]


## Aktion auf einer Taste ("" = nicht belegt).
static func ego_taste(taste: String) -> String:
	return str((ego_af("tasten") as Dictionary).get(taste, ""))

# --- Grafik: Klassisch, Neu (2D) oder HD-2D (Startmenü, 16.11.) -------------------------------
# Neu = Stil der HD-2D-Stilprobe in der 2D-Ansicht: neue Türme mit Upgrade-Stufen, Tech-Mauer, Stellungs-Haltungen,
# Upgrade-Figuren mit Schuss-Animation, Gegner auf Truppen-Pixelgröße umgerechnet, PixelFX-Effekte und Todeseffekte.
# HD-2D = dieselben Bilder in einer 3D-Ansicht wie die Stilprobe (geneigte Kamera, Zoom, Mauerblöcke), siehe hd_ansicht.gd.
# Spielwerte und Regeln bleiben gleich. Die Wahl wird in user://einstellungen.cfg gespeichert.
static var grafik := "hd"   # "klassisch", "neu" (Vogelperspektive) oder "hd" (HD-2D, Standard seit 16.11.)
static var grafik_neu := false     # neue Bilder (bei "neu" und "hd")
static var grafik_hd := false      # 3D-Ansicht
static var vollbild := not OS.has_feature("web")   # Vollbild ([F11] oder Startmenü), gespeichert; 21.11.: im Web aus bis zur Nutzergeste
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
		karte_name = str(c.get_value("karte", "name", "paulland"))
		if not OS.has_feature("web"):   # 21.11.: Web – Vollbild nur per Nutzergeste (Knopf/Taste), nie beim Laden
			vollbild = bool(c.get_value("grafik", "vollbild", true))
		musik = clampi(int(c.get_value("ton", "musik_prozent", 40)), 0, 100)
		toene = clampi(int(c.get_value("ton", "effekte_prozent", 80)), 0, 100)
	if OS.get_environment("TD_KARTE") != "":
		karte_gross = OS.get_environment("TD_KARTE") == "gross"   # für Testläufe: normal oder gross
	if OS.get_environment("TD_KARTE_NAME") != "":
		karte_name = OS.get_environment("TD_KARTE_NAME")   # für Testläufe: paulland, felsenpass …
	setze_karte(karte_gross)
	# 18.11.: Die große Karte kommt aus karten/<name>.json (Hauptkarte PaulLand); fehlt die Datei, gilt PaulLand.
	if karte_gross and not lade_karte(karte_name):
		lade_karte("paulland")
	if OS.get_environment("TD_GRAFIK") != "":
		grafik = OS.get_environment("TD_GRAFIK")   # für Testläufe: klassisch, neu oder hd
	setze_grafik(grafik)


## Vollbild an/aus. Das Bild skaliert mit (stretch canvas_items, Seitenverhältnis bleibt 16:9).
static func setze_vollbild(an: bool) -> void:
	vollbild = an
	if DisplayServer.get_name() == "headless":
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if an else DisplayServer.WINDOW_MODE_WINDOWED)
	# 21.11.: Web – Keyboard Lock (nur Chrome/Edge): ein kurzes Esc geht ans Spiel, erst langes Halten verlässt das Vollbild.
	# Nur nach einer Nutzergeste aufrufen (Knopf, Taste, Klick auf „Klicken zum Fortsetzen“) – nie beim Laden.
	if OS.has_feature("web"):
		JavaScriptBridge.eval("if (navigator.keyboard && navigator.keyboard.lock) { %s }" % \
			("navigator.keyboard.lock(['Escape']).catch(function(){});" if an else "navigator.keyboard.unlock();"))


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
	c.set_value("karte", "name", karte_name)
	c.set_value("grafik", "vollbild", vollbild)
	c.set_value("ton", "musik_prozent", musik)
	c.set_value("ton", "effekte_prozent", toene)
	c.save(EINSTELLUNGEN)


## Stellt alle größenabhängigen Felder auf die normale (20×10) oder große (28×14) Karte.
## Groß: dieselbe Anordnung, Zeilen ×13/9 gestreckt (HQ in der Mitte der Zone), Bereiche und Basis nach rechts mitgewachsen.
static func setze_karte(gross: bool) -> void:
	karte_gross = gross
	GELAENDE = {}   # 18.11.: Gelände und vorgebaute Mauern kommen nur aus einer Karten-Datei (lade_karte)
	BODEN = {}
	MAUERN = []
	MAUERN_FEST = []
	KARTE_BASIS_FEST = false
	KARTE_CP_FEST = false
	_setze_regeln({})   # 18.11.: Standardregeln (Budget, Leben, 20 Runden), keine eigenen Wellen, nichts vorgebaut
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
## 18.11.: Karten als Daten. Eine Karte = karten/<name>.json mit Größe, HQ, Zonenbauten, Schleuderplätzen, Ausgängen
## (Phantom-Modus), Basis, Checkpoint-Bereichen, Gelände (Fels, Wasser) und vorgebauten Erdwällen.
## „paulland“ ist die Hauptkarte (dieselben Werte wie setze_karte(true)); nur auf ihr gibt es Phantome und Rangliste.
const KARTEN: Array[String] = ["paulland", "felsenpass"]
## 20.11. (Schritt 5): mitgelieferte Szenarien (karten/<name>.json) – Spielen → Szenarien, im Editor „Neu aus Vorlage“.
## Zählen nicht für Rangliste und Phantome (wie jede Karte außer PaulLand).
const SZENARIEN: Array[String] = ["szenario_belagert", "szenario_zange", "szenario_alarmstart", "szenario_letzter_posten", "szenario_rueckeroberung"]
static var karte_name := "paulland"
static var KARTE_TITEL := "PaulLand"
static var KARTE_BASIS_FEST := false        # Basis immer auf BASIS_ZELLE statt zufällig
static var KARTE_CP_FEST := false           # Checkpoints immer auf CHECKPOINTS statt zufällig
static var GELAENDE: Dictionary = {}        # Feld -> "fels" (versperrt Weg, Bauen und Sicht) / "wasser" (Weg und Bauen)
static var MAUERN: Array[Vector2i] = []     # vorgebaute Erdwälle: ausbaubar, nicht abreißbar
## 20.11.: Eingänge (Karten-Datei „eingaenge“, 0–2 Randfelder, auch oben/unten/rechts): Gegner kommen nur dort heraus und
## teilen sich auf. Leer = wie bisher verteilt aus der ganzen Zone (PaulLand). Ein eingenommener Checkpoint geht weiter vor.
const EINGAENGE_MAX: int = 2
static var EINGAENGE: Array[Vector2i] = []
## 20.11. (Schritt 5b, Zange): zweite Gegnerzone (Rechteck in Feldern, leer = keine) und ihre Ausgänge. Aus ihr kommt je Trupp
## die zweite Hälfte; sie läuft nur über Checkpoint 2, die Hälfte aus der linken Zone nur über Checkpoint 1.
static var ZONE2 := Rect2i()
static var ZONE2_AUSGAENGE: Array[Vector2i] = []
static var MAUERN_FEST: Array[Vector2i] = []   # fertige Mauer für die Herausforderung „Mauern fest“

## 18.11. (Etappe 2): Gelände mit Wirkung – begehbar, aber mit Regeln (nur auf eigenen Karten aus dem Szenario-Editor).
## In der Karten-Datei je Art eine Liste von Feldern (Schlüssel wie in BODEN_ARTEN). Gilt auch für Brakk (18.11.).
const BODEN_ARTEN: Array[String] = ["anhoehe", "sumpf", "bruecke", "ruine", "wald", "erz", "eis", "minen"]
const BODEN_NAMEN := {"anhoehe": "Anhöhe", "sumpf": "Sumpf", "bruecke": "Brücke", "ruine": "Ruine", "wald": "Wald", "erz": "Erzader", "eis": "Eis", "minen": "Minenfeld"}
const BODEN_UNBEBAUBAR: Array[String] = ["sumpf", "bruecke", "wald", "minen"]   # dort steht nichts; auf der Ruine nur Erdwälle
const ANHOEHE_BONUS: float = 1.0      # Anhöhe: +Reichweite (Felder) für Truppen, Stellungen, Türme und Gegner darauf (nicht Batterien)
const SUMPF_TEMPO: float = 0.7        # Sumpf: Tempo für Gegner und eigene Truppen ...
const SUMPF_MIN_TEMPO: float = 0.45   # ... zusammen mit Frost/Plasmagel nie unter diesen Anteil (schon Langsameres bleibt)
const RUINE_DECKUNG: float = 0.25     # Ruine: so viel weniger Schaden von Fernkämpfern (Battlesphäre, Schleuder, Laser)
const RUINE_KOSTEN_WALL: int = 5      # Ruine: ein Erdwall darauf kostet nur so viel (die Mauer steht schon halb)
const WALD_SICHT: float = 2.0         # Wald: versperrt die Sicht wie Fels; Truppen darin sieht eine Battlesphäre erst so nah (Felder)
const ERZ_BONUS: int = 10             # Erzader: eine Fabrik oder ein Turm darauf bringt so viel Budget je Runde
const EIS_TEMPO: float = 1.25         # Eis: Gegner und eigene Truppen rutschen schneller
const MINE_SCHADEN: float = 40.0      # Minenfeld: der erste Gegner darauf nimmt einmal so viel Schaden; zur nächsten Runde liegt die Mine wieder
static var BODEN: Dictionary = {}     # Feld -> Art aus BODEN_ARTEN


## 18.11.: Herausforderungen (Startmenü → Herausforderungen). Zählen nicht für Rangliste und Phantome.
## [Schlüssel, Name, Beschreibung] – "" = keine. Die gewählte steht in `herausforderung` (nicht gespeichert).
const HERAUSFORDERUNGEN: Array = [
	["", "keine", "normale Regeln"],
	["keine_fabriken", "Keine Fabriken", "Nur Türme, Batterien und Brakk – alles ab Runde 1, die Gratis-Erdwälle sofort."],
	["doppelt", "Doppelte Gegner, doppeltes Geld", "Jeder Trupp kommt zweimal; Prämien und Rundenbonus doppelt."],
	["mauern_fest", "Mauern fest", "Die Karte bringt eine fertige Mauer mit: keine Erdwälle bauen oder abreißen, nur darauf ausbauen."],
]
static var herausforderung := ""


static func herausforderung_name(schluessel: String) -> String:
	for h: Array in HERAUSFORDERUNGEN:
		if h[0] == schluessel:
			return str(h[1])
	return schluessel


static func herausforderung_text(schluessel: String) -> String:
	for h: Array in HERAUSFORDERUNGEN:
		if h[0] == schluessel:
			return str(h[2])
	return ""


## 20.11. (Zange): liegt das Feld in der zweiten Gegnerzone?
static func in_zone2(z: Vector2i) -> bool:
	return ZONE2.size != Vector2i.ZERO and ZONE2.has_point(z)


static func ist_hauptkarte() -> bool:
	return karte_gross and karte_name == "paulland"


## 18.11.: Eigene Karten aus dem Szenario-Editor liegen in user://karten/<name>.json (Name beginnt mit "eigen_",
## damit er nie mit einer mitgelieferten Karte zusammenfällt).
const EIGENE_KARTEN := "user://karten/"
static var KARTE_REGELN: Dictionary = {}    # Regelpaket der Karte (siehe _setze_regeln); leer = Standard
static var KARTE_WELLEN: Dictionary = {}    # eigene Wellen: Runde (int) -> Trupps im Format von WELLEN
## 20.11. (Schritt 5b): Wellen eines Szenarios aus dem Wellenpool: Runde (int) -> {"plan": Nummer in WELLEN, "name", "ansage",
## "leben" (Leben-Faktor)}. Die Gegner kommen dann wie im normalen Spiel (verteilt), nicht geschlossen wie bei eigenen Wellen.
static var KARTE_PLAN_WELLEN: Dictionary = {}
static var KARTE_STAND: Dictionary = {}     # vorgebaute Türme/Fabriken im Format von Phantom._stand (leer = nichts)


static func karten_daten(name: String) -> Dictionary:
	var pfad := "res://karten/%s.json" % name
	if not FileAccess.file_exists(pfad):
		pfad = EIGENE_KARTEN + name + ".json"
	if not FileAccess.file_exists(pfad):
		return {}
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(pfad))
	if d is Dictionary and karte_gueltig(d) == "":
		return d
	return {}


static func ist_eigene_karte(name: String) -> bool:
	return not KARTEN.has(name) and FileAccess.file_exists(EIGENE_KARTEN + name + ".json")


## Namen aller eigenen Karten (ohne Endung), alphabetisch.
static func eigene_karten() -> Array[String]:
	var aus: Array[String] = []
	var d := DirAccess.open(EIGENE_KARTEN)
	if d == null:
		return aus
	for f in d.get_files():
		if f.ends_with(".json"):
			aus.append(f.get_basename())
	aus.sort()
	return aus


## Prüft, ob ein Wörterbuch eine ladbare Karte ist ("" = ja, sonst der Grund). Für Import und eigene Dateien.
static func karte_gueltig(k: Dictionary) -> String:
	for s: String in ["spalten", "zeilen", "hq", "angriff", "zonenbauten_zeilen", "schleuder_plaetze", "ausgaenge", "basis", "checkpoint_bereiche", "checkpoints"]:
		if not k.has(s):
			return "Es fehlt „%s“." % s
	if not (k["spalten"] is float or k["spalten"] is int) or not (k["zeilen"] is float or k["zeilen"] is int):
		return "Größe ist keine Zahl."
	var sp := int(k["spalten"])
	var ze := int(k["zeilen"])
	if sp < 12 or sp > 60 or ze < 6 or ze > 30:
		return "Größe %d×%d geht nicht." % [sp, ze]
	if not (k["zonenbauten_zeilen"] is Array) or (k["zonenbauten_zeilen"] as Array).size() != 7:
		return "Zonenbauten passen nicht."
	if not (k["ausgaenge"] is Dictionary) or not (k["ausgaenge"] as Dictionary).has_all(["mitte", "oben", "unten"]):
		return "Ausgänge passen nicht."
	if not (k["checkpoints"] is Array) or (k["checkpoints"] as Array).size() != 2 or not (k["checkpoint_bereiche"] is Array) or (k["checkpoint_bereiche"] as Array).size() != 2:
		return "Es braucht genau zwei Checkpoints."
	for liste: String in ["schleuder_plaetze", "checkpoints", "fels", "wasser", "mauern", "mauern_fest"] + BODEN_ARTEN:
		if not k.has(liste):
			continue
		if not (k[liste] is Array):
			return "„%s“ ist keine Liste." % liste
		for p: Variant in k[liste]:
			if not (p is Array) or (p as Array).size() < 2:
				return "„%s“ enthält ein ungültiges Feld." % liste
	for r: Variant in k["checkpoint_bereiche"]:
		if not (r is Array) or (r as Array).size() != 4:
			return "Checkpoint-Bereich ungültig."
	var rg: Variant = k.get("regeln", {})
	if not (rg is Dictionary):
		return "Regeln ungültig."
	if (rg as Dictionary).has("mods") and not ((rg as Dictionary)["mods"] is Dictionary):
		return "Werte-Mods ungültig."
	return ""


static func lade_karte(name: String) -> bool:
	var k := karten_daten(name)
	if k.is_empty():
		return false
	uebernimm_karte(name, k)
	return true


## 18.11.: Stellt alle Kartenwerte aus einem Karten-Wörterbuch ein (Datei oder Entwurf im Szenario-Editor).
static func uebernimm_karte(name: String, k: Dictionary) -> void:
	karte_name = name
	KARTE_TITEL = str(k.get("name", name))
	SPALTEN = int(k["spalten"])
	ZEILEN = int(k["zeilen"])
	KARTE_FAKTOR = (SPALTEN - 1) / 19.0
	START_ZELLE = _feld(k["hq"])
	ANGRIFFS_ZELLE = _feld(k["angriff"])
	_setze_regeln(k)   # vor den Zonenbauten: die Laser stehen in der letzten Runde
	ZONENBAUTEN = _zonenbauten(k["zonenbauten_zeilen"])
	SCHLEUDER_PLAETZE = _felder(k["schleuder_plaetze"])
	var a: Dictionary = k["ausgaenge"]
	AUSGAENGE = {"": _feld(a["mitte"]), "oben": _feld(a["oben"]), "unten": _feld(a["unten"])}
	BASIS_ZELLE = _feld(k["basis"])
	KARTE_BASIS_FEST = bool(k.get("basis_fest", false))
	var bereiche: Array[Rect2i] = []
	for r: Array in k["checkpoint_bereiche"]:
		bereiche.append(Rect2i(int(r[0]), int(r[1]), int(r[2]), int(r[3])))
	CHECKPOINT_BEREICHE = bereiche
	CHECKPOINTS = _felder(k["checkpoints"])
	KARTE_CP_FEST = bool(k.get("checkpoints_fest", false))
	GELAENDE = {}
	for art: String in ["fels", "wasser"]:
		for z: Vector2i in _felder(k.get(art, [])):
			GELAENDE[z] = art
	EINGAENGE = _felder(k.get("eingaenge", []))   # 20.11.: Eingänge der Gegner (leer = aus der ganzen Zone wie bisher)
	ZONE2 = Rect2i()
	ZONE2_AUSGAENGE = []
	var z2: Variant = k.get("zone2", {})
	if z2 is Dictionary and ((z2 as Dictionary).get("rechteck", []) as Array).size() == 4:
		var r: Array = (z2 as Dictionary)["rechteck"]
		ZONE2 = Rect2i(int(r[0]), int(r[1]), int(r[2]), int(r[3]))   # 20.11. (Zange): zweite Gegnerzone
		ZONE2_AUSGAENGE = _felder((z2 as Dictionary).get("ausgaenge", []))
		if ZONE2_AUSGAENGE.is_empty():
			ZONE2_AUSGAENGE = [ZONE2.position]
	MAUERN = _felder(k.get("mauern", []))
	MAUERN_FEST = _felder(k.get("mauern_fest", []))
	BODEN = {}
	for art: String in BODEN_ARTEN:
		for z: Vector2i in _felder(k.get(art, [])):
			if not GELAENDE.has(z):
				BODEN[z] = art


## 18.11.: Regelpaket einer Karte (Szenario-Editor). `k` = ganze Karte; fehlt "regeln", gilt alles wie gewohnt.
## regeln: {"start_budget", "start_leben", "runden" (10/15/20), "bauten" {Name: false = gesperrt}, "herausforderung", "einfuehrung"}
## wellen: {"<Runde>": [Trupps wie in WELLEN]}, stand: vorgebaute Türme/Fabriken im Format von Phantom._stand.
static func _setze_regeln(k: Dictionary) -> void:
	var r: Variant = k.get("regeln", {})
	KARTE_REGELN = (r as Dictionary).duplicate(true) if r is Dictionary else {}
	START_BUDGET = clampi(int(KARTE_REGELN.get("start_budget", STANDARD_BUDGET)), 0, 99999)
	START_LEBEN = clampi(int(KARTE_REGELN.get("start_leben", STANDARD_LEBEN)), 1, 999)
	LETZTE_RUNDE = clampi(int(KARTE_REGELN.get("runden", STANDARD_RUNDEN)), 2, STANDARD_RUNDEN)
	if ziel() == "endlos":
		LETZTE_RUNDE = ENDLOS_RUNDEN   # 18.11.: endlos – es gibt keine letzte Runde
	KARTE_WELLEN = {}
	KARTE_PLAN_WELLEN = {}
	var w: Variant = k.get("wellen", {})
	if w is Dictionary:
		for nr: Variant in w:
			if w[nr] is Array and not (w[nr] as Array).is_empty():
				KARTE_WELLEN[int(nr)] = (w[nr] as Array).duplicate(true)
			elif w[nr] is Dictionary and WELLEN.has(int((w[nr] as Dictionary).get("plan", 0))):
				KARTE_PLAN_WELLEN[int(nr)] = (w[nr] as Dictionary).duplicate(true)   # 20.11.: Welle aus dem Pool
	var s: Variant = k.get("stand", {})
	KARTE_STAND = (s as Dictionary).duplicate(true) if s is Dictionary else {}


## Ist dieses Bauwerk auf der Karte erlaubt? `name` wie in BAUTEN_NAMEN (main.gd), z. B. "fabrik".
static func baut_erlaubt(name: String) -> bool:
	var b: Variant = KARTE_REGELN.get("bauten", {})
	return not (b is Dictionary) or bool((b as Dictionary).get(name, true))


## 18.11.: Grundgerüst einer neuen Karte der Größe spalten×zeilen für den Szenario-Editor: Zone (HQ, Zonenbauten,
## Schleuderplätze, Ausgänge), Basis und Checkpoint-Bereiche aus der Größe berechnet. Bei 28×14 genau wie PaulLand.
static func karten_vorlage(spalten: int, zeilen: int) -> Dictionary:
	var mitte := floori(zeilen / 2.0) - 1                    # 14 -> 6, 10 -> 4, 16 -> 7
	var oben := floori((zeilen - 2) / 4.0)                   # Zeile der oberen Zonenbauten: 14 -> 3
	var unten := zeilen - 1 - oben                 # ... und der unteren: 14 -> 10
	var n := floori((zeilen + 6) / 4.0)                      # Schleuderplätze je Seite: 14 -> 5, 10 -> 4
	var plaetze: Array = []
	for y in n:
		plaetze.append([1, y])
	for y in range(zeilen - n, zeilen):
		plaetze.append([1, y])
	var b := float(spalten - 1)
	var x1 := roundi(0.22 * b)
	var b1 := roundi(0.33 * b)
	var x2 := roundi(0.44 * b)
	var b2 := roundi(0.41 * b)
	var halb := floori(zeilen / 2.0)
	var bereiche := [[x1, 1, b1, zeilen - 2], [x2, 1, b2, zeilen - 2]]
	var cp1: Array = [x1 + floori(b1 / 4.0), mitte]
	var cp2: Array = [x2 + floori(b2 / 2.0), halb]
	return {
		"name": "Neues Szenario", "beschreibung": "",
		"spalten": spalten, "zeilen": zeilen,
		"hq": [0, mitte], "angriff": [1, mitte],
		"zonenbauten_zeilen": [oben, unten, unten, oben, oben, halb, unten],
		"schleuder_plaetze": plaetze,
		"ausgaenge": {"mitte": [0, mitte], "oben": [1, 1], "unten": [1, zeilen - 2]},
		"basis": [spalten - 2, halb], "basis_fest": false,
		"checkpoint_bereiche": bereiche, "checkpoints": [cp1, cp2], "checkpoints_fest": false,
		"fels": [], "wasser": [], "mauern": [], "mauern_fest": [],
	}


## Laser verteidigen die Zone nur im Gegenangriff – ohne Gegenangriff (andere Spielziele) kommen sie nie.
static func _laser_ab() -> int:
	return LETZTE_RUNDE if ziel() == "gegenangriff" else ENDLOS_RUNDEN + 1


## 18.11. (Stufe 2): Spielziel eines Szenarios (Regelpaket „ziel“). [Schlüssel, Name, Erklärung]
const ZIELE: Array = [
	["gegenangriff", "Gegenangriff", "Standard: In der letzten Runde fällt der Schild – das HQ des Gegners muss fallen."],
	["ueberleben", "Überleben", "Übersteh alle Runden – nach der letzten ist die Partie gewonnen (kein Gegenangriff)."],
	["endlos", "Endlos", "Runden ohne Ende, die Gegner werden immer zäher. Wie weit kommst du?"],
	["checkpoints", "Checkpoints halten", "Übersteh alle Runden. Gehören am Rundenende beide Checkpoints dem Gegner, ist die Partie verloren."],
]
const ENDLOS_RUNDEN: int = 9999
const BAUZEITEN: Array[int] = [0, 30, 60, 90]   # Sekunden Bauphase, dann startet die Welle von selbst (0 = unbegrenzt)


static func ziel() -> String:
	return str(KARTE_REGELN.get("ziel", "gegenangriff"))


static func ziel_name(schluessel: String) -> String:
	for z: Array in ZIELE:
		if z[0] == schluessel:
			return str(z[1])
	return schluessel


static func ziel_text(schluessel: String) -> String:
	for z: Array in ZIELE:
		if z[0] == schluessel:
			return str(z[2])
	return ""


## 20.11. (Schritt 5): Startlage und Modus aus dem Regelpaket (fehlt ein Schlüssel, gilt das Gewohnte).
## regeln: {"modus": "normal"/"brakk", "einkommen": true/false, "mauer_leben": Prozent der vorgebauten Erdwälle,
##          "cp_feind": beide Checkpoints schon beim Gegner, "sofort": die erste Welle läuft gleich los}
const MODI: Array = [["normal", "Normal"], ["brakk", "Brakk-Ego"]]
## 20.11. (Schritt 5b, Alarmstart): nur die vollen, gut ausgebauten Formationen aus [H] (Nachschlag.PLAENE_GROSS)
const ALARM_FORMATIONEN: Array[String] = ["2-kamm", "3-zitadelle", "7-kamm-mit-kern", "8-riegel-und-schlauch", "9-dicker-schlauch"]
const ALARM_TRUPPEN: Array[String] = ["technogunner", "scharfschuetze", "plasmawerfer"]   # Fabriken reihum spezialisiert
const STELLUNG_ABDECKUNG: float = 3.5   # so weit (Felder) zählt ein Wegfeld zur Abdeckung einer Stellung (Wahl der Felder)
const MAUER_LEBEN_STUFEN: Array[int] = [100, 75, 50, 25]


static func modus() -> String:
	return str(KARTE_REGELN.get("modus", "normal"))


static func einkommen_an() -> bool:
	return bool(KARTE_REGELN.get("einkommen", true))


static func bauzeit() -> int:
	return maxi(0, int(KARTE_REGELN.get("bauzeit", 0)))


## 18.11. (Stufe 1): Werte-Mods einer eigenen Karte (Regelpaket „mods“). Nur diese Schlüssel, je
## [Schlüssel, Name, Art ("%" = Prozent, "+" = dazu), Standard, kleinster, größter, Schritt]. Fehlt einer, gilt der Standard.
const MODS: Array = [
	["gegner_leben", "Gegner: Leben", "%", 100.0, 25.0, 400.0, 10.0],
	["gegner_tempo", "Gegner: Tempo", "%", 100.0, 50.0, 200.0, 10.0],
	["gegner_schaden", "Gegner: Schaden", "%", 100.0, 25.0, 400.0, 10.0],
	["truppen_leben", "Truppen: Leben", "%", 100.0, 25.0, 400.0, 10.0],
	["truppen_schaden", "Truppen: Schaden", "%", 100.0, 25.0, 400.0, 10.0],
	["truppen_reichweite", "Truppen: Reichweite", "+", 0.0, -2.0, 3.0, 0.5],
	["turm_schaden", "Türme: Schaden", "%", 100.0, 25.0, 400.0, 10.0],
	["turm_reichweite", "Türme: Reichweite", "+", 0.0, -2.0, 3.0, 0.5],
	["einkommen", "Einkommen", "%", 100.0, 0.0, 400.0, 10.0],
	["fabrik_truppen", "Truppen je Fabrik", "+", 0.0, -2.0, 5.0, 1.0],
]


static func _mod_eintrag(schluessel: String) -> Array:
	for m: Array in MODS:
		if m[0] == schluessel:
			return m
	return []


## Wert eines Mods (Prozent oder Zuschlag), begrenzt auf seinen Bereich.
static func mod(schluessel: String) -> float:
	var m := _mod_eintrag(schluessel)
	if m.is_empty():
		return 0.0
	var mods: Variant = KARTE_REGELN.get("mods", {})
	var wert: float = float((mods as Dictionary).get(schluessel, m[3])) if mods is Dictionary else float(m[3])
	return clampf(wert, float(m[4]), float(m[5]))


## Prozent-Mod als Faktor (100 % = 1).
static func mod_faktor(schluessel: String) -> float:
	return mod(schluessel) / 100.0


## Gegner-Werte mit den Mods der Karte (ohne Mods: die Werte aus GEGNER selbst, keine Kopie).
static func gegner_daten(typ: String) -> Dictionary:
	var d: Dictionary = GEGNER[typ]
	var l := mod_faktor("gegner_leben")
	var t := mod_faktor("gegner_tempo")
	var s := mod_faktor("gegner_schaden")
	if l == 1.0 and t == 1.0 and s == 1.0:
		return d
	d = d.duplicate()
	d["leben"] = float(d["leben"]) * l
	d["tempo"] = float(d["tempo"]) * t
	for k: String in ["schaden", "schaden_einheit"]:
		if d.has(k):
			d[k] = float(d[k]) * s
	return d


static func _feld(p: Array) -> Vector2i:
	return Vector2i(int(p[0]), int(p[1]))


static func _felder(liste: Array) -> Array[Vector2i]:
	var aus: Array[Vector2i] = []
	for p: Array in liste:
		aus.append(_feld(p))
	return aus


static func _zonenbauten(zeilen: Array) -> Array:
	var vorlage := [["schleuder", 1, 5], ["schleuder", 1, 8], ["wurf", 0, 10], ["wurf", 0, 14], ["laser", 2, _laser_ab()], ["laser", 2, _laser_ab()], ["laser", 2, _laser_ab()]]   # 18.11.: Laser in der letzten Runde der Karte
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
		"name": "Belagerungsturm", "kurz": "Bel.-Turm", "art": "entert Wälle", "rolle": "belagerung", "fernkampf": false, "gross": true,   # 19.11.: großer Gegner (Tumble-Schuss, Doppellanze)
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
		"name": "Schwarmgeist", "kurz": "Schwarm", "art": "zerfällt in Drohnen", "rolle": "schwarm", "fernkampf": false, "gross": true,   # 19.11.: großer Gegner – die Einheit mit der Krone
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
## Brakk-Mode nach dem Playtest (19.11., Paul): Gegner kommen gegen Bodentruppen besser durch.
const BRAKK_BODEN_SCHADEN := 1.5       # Gegner machen gegen Truppen am Boden so viel mehr Schaden (Stellungen, Bauten, Brakk: normal)
const BRAKK_DURCHBRUCH_SEK := 3.0      # so lange von Bodentruppen aufgehalten, dann bricht ein Nahkämpfer durch:
const BRAKK_DURCHBRUCH_SCHUB := 0.5    # ... stößt die Truppe so viele Felder zur Seite ...
const BRAKK_DURCHBRUCH_STARK := 1.5    # ... und macht so lange so viel mehr Schaden
const BRAKK_DURCHBRUCH_DAUER := 4.0
const BRAKK_SPRUNG_SEK := 0.8          # Hunde: so lange aufgehalten, dann springen sie über die Truppe hinweg
const BRAKK_SPRUNG_ABKLING := 4.0
## 20.11. (Paul): Elite-Trupps in genau diesen Runden (vorher „ab Runde 3 jede Runde“ – kam auch in Runde 4). Ein Trupp
## der Welle (nicht der erste) wird zur Elite, in Runde 20 nur im ersten Durchgang.
const BRAKK_ELITE_RUNDEN: Array[int] = [8, 13, 19]
const BRAKK_ELITE_LEBEN := 2.5
const BRAKK_ELITE_SCHADEN := 1.5
const BRAKK_ELITE_FLAECHE := 0.9       # Felder: Elite-Treffer streifen Truppen in diesem Umkreis ...
const BRAKK_ELITE_FLAECHE_ANTEIL := 0.4  # ... mit so viel vom Schaden
const BRAKK_ELITE_PRAEMIE := 2.0
## 20.11.: Schritt 6c – Ausweichen (Classic und Rogue). Schüsse auf Brakk sind echte Geschosse (brakk_geschosse.gd); die
## 2D-Logik für alle anderen Figuren bleibt. Tempo in Feldern je Sekunde Echtzeit (Brakk läuft 3), Radien in Feldern.
const BRAKK_AUSWEICH_SCHADEN := {   # Schaden je Treffer auf Brakk – die Trefferquote sinkt, darum mehr (Paul 20.11.)
	"technogunner": 1.5, "sphaere": 1.5, "plasmawerfer": 2.0, "scharfschuetze": 1.5,
	"geschuetz": 1.5, "lanze": 1.5,
}   # alles andere (Batterie, Nahkampf, Schleudersteine): ×1
const BRAKK_GESCHOSS := {
	"laser": {"tempo": 14.0, "radius": 0.06, "dicke": 9.0},     # Technogunner
	"sph": {"tempo": 11.0, "radius": 0.08, "dicke": 11.0},      # Battlesphäre (Classic)
	"plasma": {"tempo": 4.5, "radius": 0.22, "dicke": 30.0, "einschlag": 0.6, "brand_sek": 2.0, "brand_anteil": 0.2},
}
const BRAKK_RUMPF := 0.18              # Brakks Trefferbereich (Radius in Feldern) – kleiner als sein Bild
const BRAKK_STREUUNG := 0.27           # seitliche Streuung des Zielpunkts (Felder, gleichverteilt ±) – stehend etwa 90 % Treffer
const BRAKK_VORHALT := 0.5             # Anteil, um den fliegende Geschosse Brakks Laufweg vorhalten (0 = auf die Stelle von jetzt); 20.11. (Paul): 50 %, sonst weicht Seitwärtslaufen allem aus
const BRAKK_SCHARF_ZIEL_SEK := 0.6     # Scharfschütze: so lange steht der rote Zielstrahl, dann Hitscan entlang der Linie
const BRAKK_SCHARF_BREITE := 0.12
const BRAKK_TURM_GLUEHEN := 0.3        # Geschütz- und Lanzenturm: Aufglühen, dann Schuss auf Brakks Position von davor
const BRAKK_TURM_BREITE := 0.1         # Geschützturm: halbe Breite des Schusses
const BRAKK_TUMBLE_DURCHLASS := 0.25   # Tumble: so lange (s) gehen Geschosse durch ihn hindurch (und er nimmt keinen Schaden)
const BRAKK_SPRUNG_BODEN := 0.45       # Sprung: Füße höher als das (Felder) – Bodengeschosse (Plasmaball, Brandfeld) verfehlen

## Battlesphäre schießt sich ein (19.11., Paul): Jeder Treffer auf ein Feld lässt Sphären, die auf dieses Feld schießen,
## schneller feuern – bis zu EINSCHUSS_MAX mehr Schüsse je Sekunde (also bis +50 % Schaden). Ohne Treffer kühlt das Feld ab.
const EINSCHUSS_JE_TREFFER := 0.08
const EINSCHUSS_MAX := 0.5
const EINSCHUSS_SEK := 2.0             # so lange ohne Sphärentreffer, dann ist das Feld wieder kalt
## Schildträger im Trupp mit Battlesphären (19.11.): bleibt so weit vor der nächsten Sphäre und läuft nicht davon.
const SCHILD_VORSPRUNG := 0.8          # Felder
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
		{"weg": "l", "typen": ["sphaere", "sphaere"]},   # 18.11. Balance: vorher 3 Sphären (Runde 7 war der häufigste frühe Abbruch), eine wandert nach Runde 8
		{"weg": "l", "typen": ["hund", "hund", "hund", "hund", "hund"]},
		{"weg": "l", "typen": ["hund", "hund", "hund", "hund", "hund"]},
	]},
	8: {"name": "Sprengmeister", "stufe": "Einführung", "trupps": [
		{"weg": "l", "typen": ["hund", "hund", "hund", "hund", "hund"]},
		{"weg": "l", "typen": ["sprenger", "sprenger"]},
		{"weg": "l", "typen": ["fahne", "hund", "hund", "hund", "hund", "hund"]},
		{"weg": "l", "typen": ["sphaere", "sphaere", "sphaere", "sphaere"]},   # 18.11.: vorher 3
		{"weg": "l", "typen": ["hund", "hund", "hund", "hund", "hund"]},
	]},
	9: {"name": "Köder", "stufe": "Kombination", "trupps": [
		{"weg": "l", "typen": ["hund", "hund", "hund", "hund", "hund", "hund", "hund", "hund", "hund", "hund"]},
		{"weg": "l", "typen": ["sprenger", "sprenger"], "pause": 17.0},
		{"weg": "l", "typen": ["schild", "hund", "hund", "hund"]},   # 18.11.: Einführung mit einem Schildträger (vorher 2; Runde 9 war der größte Sprung)
		{"weg": "l", "typen": ["fahne", "hund", "hund", "hund", "hund"]},
		{"weg": "l", "typen": ["hund", "hund", "hund", "sphaere", "sphaere", "sphaere"]},   # 18.11.: vorher 4 Sphären, eine wandert nach Runde 10
	]},
	10: {"name": "Über die Mauer", "stufe": "Einführung", "trupps": [
		{"weg": "l", "typen": ["hund", "hund", "hund", "hund", "hund"]},
		{"weg": "w", "typen": ["hund", "hund", "hund", "hund"]},
		{"weg": "l", "typen": ["fahne", "hund", "hund", "hund", "hund", "hund"]},
		{"weg": "w", "typen": ["hund", "hund", "hund", "hund"]},
		{"weg": "l", "typen": ["sphaere", "sphaere", "sphaere", "sphaere", "sphaere"]},   # 18.11.: vorher 4
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
		{"weg": "l", "typen": ["schild", "schild", "hund", "hund", "hund", "hund"]},
	]},   # 18.11.: Trupp „Schild + 2 Sphären“ nach Runde 14 verschoben (Runde 13 Spitze, Runde 14 Atempause zu tief)
	14: {"name": "Abrisskommando", "stufe": "Kombination", "trupps": [
		{"weg": "l", "typen": ["rauch", "rauch"]},
		{"weg": "l", "typen": ["sprenger", "sprenger", "sprenger"]},
		{"weg": "w", "typen": ["rauch", "rauch", "sprenger", "sprenger"]},
		{"weg": "l", "typen": ["sani", "sphaere", "sphaere", "sphaere", "sphaere"]},
		{"weg": "l", "typen": ["schild", "sani", "hund", "hund", "hund", "hund"]},
		{"weg": "l", "typen": ["schwarm", "hund", "hund"]},
		{"weg": "l", "typen": ["schild", "sphaere", "sphaere"]},   # 18.11.: aus Runde 13
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
	var w := welle_aus_plan(wellen_plan(nr), plan_runde(nr))
	var p: Dictionary = KARTE_PLAN_WELLEN.get(nr, {})
	if p.has("leben"):
		w["leben_faktor"] = clampf(float(p["leben"]), 0.1, 20.0)   # 20.11.: das Szenario setzt die Zähigkeit selbst
	return w


## 20.11. (Schritt 5b): Zu welcher Runde des normalen Spiels gehört Runde `nr`? Bei einer Welle aus dem Pool die Nummer ihres
## Plans – danach richten sich Checkpoints, Schleudern, Wurf-Schleuder, Sprenger und Grund-Leben. Sonst `nr` selbst.
static func plan_runde(nr: int) -> int:
	var p: Dictionary = KARTE_PLAN_WELLEN.get(nr, {})
	return maxi(nr, int(p.get("plan", nr))) if not p.is_empty() else nr


## 20.11. (Schritt 5b): Ansage in der Bauphase vor Runde `nr`: Text der Szenario-Welle, sonst die neuen Gegner des normalen Spiels.
static func ansage(nr: int) -> String:
	if KARTE_PLAN_WELLEN.has(nr):
		return str((KARTE_PLAN_WELLEN[nr] as Dictionary).get("ansage", ""))
	return str(NEUHEITEN.get(nr, ""))


## 18.11.: Entworfener Plan der Runde. Die letzte Runde der Karte ist immer der Gegenangriff (Plan 20), auch bei 10 oder 15 Runden.
static func wellen_plan(nr: int) -> Dictionary:
	if KARTE_PLAN_WELLEN.has(nr):
		var p: Dictionary = KARTE_PLAN_WELLEN[nr]
		var plan: Dictionary = (WELLEN[int(p["plan"])] as Dictionary).duplicate()
		if str(p.get("name", "")) != "":
			plan["name"] = str(p["name"])   # 20.11.: das Szenario gibt der Welle einen eigenen Namen
		return plan
	if ziel() != "gegenangriff":
		# 18.11.: ohne Gegenangriff keine Schleifen-Welle – nach Runde 19 kehren die späten Pläne 10–19 wieder
		if nr <= STANDARD_RUNDEN - 1:
			return WELLEN[clampi(nr, 1, STANDARD_RUNDEN - 1)]
		return WELLEN[10 + (nr - STANDARD_RUNDEN) % 10]
	if nr >= LETZTE_RUNDE:
		return WELLEN[STANDARD_RUNDEN]
	return WELLEN[clampi(nr, 1, STANDARD_RUNDEN)]


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


## 18.11. Balance: Gegenangriff und HQ wachsen mit der Rundenzahl der Karte. Bei 20 Runden genau ENDKAMPF_LEBEN und HQ_LEBEN;
## bei 10/15 Runden im Verhältnis des Leben-Faktors der vorletzten Runde (10 Runden: ×1,2 statt ×2,2 und 850 HQ-Leben).
static func endkampf_anteil() -> float:
	return (1.0 + LEBEN_JE_RUNDE * (LETZTE_RUNDE - 2)) / (1.0 + LEBEN_JE_RUNDE * (STANDARD_RUNDEN - 2))


static func endkampf_leben() -> float:
	if KARTE_REGELN.has("endkampf_leben"):
		return clampf(float(KARTE_REGELN["endkampf_leben"]), 0.1, 20.0)   # 20.11.: vom Szenario vorgegeben
	return snappedf(ENDKAMPF_LEBEN * endkampf_anteil(), 0.1)


static func hq_leben() -> float:
	if KARTE_REGELN.has("hq_leben"):
		return clampf(float(KARTE_REGELN["hq_leben"]), 50.0, 99999.0)   # 20.11.: vom Szenario vorgegeben
	return snappedf(HQ_LEBEN * endkampf_anteil(), 50.0)


## Extra-Reichweite einer Einheit in der Stellung (je Einheit verschieden).
static func stellung_bonus(daten: Dictionary) -> float:
	return daten.get("stellung_bonus", POSTEN_REICHWEITE_BONUS)


static func zinsen(budget: int) -> int:
	return mini(int(budget / float(ZINS_SCHRITT)), zins_stufen()) * ZINS_JE_SCHRITT   # 19.11.: Zinsdeckel je Anführer


static func wellen_bonus(nr: int) -> int:
	return BONUS_JE_WELLE + BONUS_ZUWACHS * nr + BONUS_MITTE_ZUWACHS * maxi(0, nr - BONUS_MITTE_AB + 1) + int(BONUS_EXTRA.get(nr, 0))
