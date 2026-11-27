class_name Order24
extends Node
## 20.11. (Schritt 5b): Order 24 – Brakk-Mode „Rogue“. Der Technoclan hat sich gegen Brakk gewandt: Brakk ist allein auf der
## Karte, die Technoclan-Verteidigung (Truppen, Stellungen, Türme, Batterien) ist der Gegner. Ziel: eine Zeit lang überstehen.
##
## So funktioniert es, ohne die Verteidigung neu zu schreiben:
##  - Brakk steht für die Verteidigung als unsichtbarer Gegner in spiel.gegner (BrakkZiel). Zielwahl, Sichtregel und das
##    Schießen über Wälle laufen dadurch genau wie in Runde 20 gegen die Myriaden; der Schaden geht an Brakk.
##  - Für Brakks Waffen gibt es Stellvertreter der Technoclan-Truppen, Fabriken und Turmkerne (TechnoZiel). Die Ego-Sicht
##    schießt über spiel.ego_gegner() auf sie; Treffer gehen an die Truppe bzw. das Gebäude.
##  - Phase 1 „Streifzug“: Truppen bleiben in Stellungen und an ihren Fabriken, geschossen wird nur auf Sicht.
##  - Phase 2 „Jagd“ (ab jagd_start): ein Anteil jagt Brakk in Gruppen über verschiedene Wege, der Vorstoß läuft zum
##    Myriaden-HQ. Nach der Einnahme steht dort ein zweites Technoclan-HQ mit Schild und zwei Fabriken.
## Alle Zahlen kommen aus dem Regelpaket der Karte (Schlüssel siehe STANDARD), der Editor stellt sie ein.
##
## 20.11. (Paul, Ergänzung „Befehl 24“) – Regeln nur in diesem Modus:
##  - Sichtlinie: Eine Stellung sieht nur über ihr eigenes Feld hinaus (karte.sicht_eigenes_feld). „In Deckung“, solange
##    keine Stellung Brakk sieht.
##  - Erdwälle nehmen von Schüssen keinen Schaden; nur Sprengladungen ([C], 3 s Zünder) räumen sie weg. Ladungen lassen
##    gefallene Truppen fallen. Der Technoclan baut gesprengte Wälle ab der Jagd nach, wenn Brakk nicht in der Nähe ist.
##  - Türme: Stütze sprengen (schweigt bis zum Nachbau) oder Kern leer schießen (20 s Ausfall).
##  - Stellungen bleiben, nur die Truppe darauf fällt; die Fabrik liefert Ersatz (Produktionszyklus produktion_sek).
##  - Fabriken außerhalb des Schilds: Sabotage ([F] an der Rückseite halten), Zerstörung über fabrik_leben, Alarm im Umkreis,
##    Pilot aus der Batterie repariert Sabotagen.

const STANDARD := {
	# 20.11. (Paul, Ergänzung Befehl 24): Ablauf Flucht → Sabotage → Jagd → Vorstoß, alle Zeiten in echten Sekunden
	"ueberleben_sek": 0,        # 0 = endlos (Paul, 20.11.: kein Sieg nach Zeit – die Wertung ist, wie lange Brakk durchhält); sonst Sieg nach so vielen Sekunden
	"geheim_ab": 900,           # hält Brakk das Myriaden-HQ bis hierhin, beginnt der geheime Verlauf „Überläufer“ (0 = aus)   # 20.11. (Paul): doch wieder ab 15:00
	"myr_takt": 30,             # Überläufer: Wellenzyklus der Myriaden-Fabriken
	"myr_wert": 60,             # Wert der Einheiten je Fabrik und Zyklus (Hund 10 → 6 Hunde, Fahne 75 → 1)
	"myr_bau_mal": 4,           # (alt: Baupreis = Einheitenpreis × so viel – seit dem Ringfeld-Umbau unbenutzt)
	"myr_fabrik_preis": 100,    # 20.11. (Paul): es gibt nur noch EINE Myriaden-Fabrik zu diesem Preis – was sie baut, bestimmt das Ringfeld
	"myr_ohne_ring": 50,        # Prozent des Werts, solange die Fabrik in keinem Ringfeld steht (dann Hunde)
	"myr_ring_stufe": 30,       # Prozent mehr Wert je Ringstufe über 1 (Stufe 3: +60 %)
	"myr_kosten_anteil": 40,    # Prozent des Einheitenpreises kostet die Produktion je Zyklus
	"geheim_einkommen": 60,     # Gold je Zyklus
	"geheim_cp_sek": 30,        # beide Checkpoints so lange halten → Schild des Technoclan-HQ fällt
	"geheim_hq_leben": 3000,    # Leben des Technoclan-HQ
	"myr_rueck_sek": 10,        # so lange am besetzten Myriaden-HQ stehen (ohne Technoclan in der Nähe) = zurückerobert
	"flucht_sek": 45,           # Flucht: niemand jagt, die Truppen gehen in Stellung
	"jagd_start": 60,           # Sabotage bis hier (Verteidiger statisch), dann Jagd … – 22.11. (Paul): 90 statt 150, die Haufen standen zu lange; 26.11. (Paul): 60
	"sabotage_ende_fabriken": 2,  # … oder schon, sobald so viele Fabriken zerstört sind
	"jagd_anteil": 80,          # Prozent der Truppen, die Jagdtrupps bilden (der Rest bleibt in den Nestern)
	"trupp_min": 3,             # Jagdtrupps zu 3–5
	"trupp_max": 5,
	"sicht_verlust": 8,         # so lange aus der Sicht, dann sucht der Trupp …
	"such_sek": 20,             # … so lange um den letzten Punkt, dann wieder Streife
	"welle_takt": 45,           # in der Jagd alle so viele Sekunden ein neuer Trupp aus den Schild-Fabriken – F4 (26.11., Paul): 45 statt 60 (Gegnerfrequenz +25 %)
	"welle_takt_min": 19,       # 20.11. (Paul): 25 statt 40 s; F4 (26.11.): 19 statt 25 – Eskalation – der Takt sinkt bis hierhin …
	"eskalation_sek": 600,      # … über so viele Sekunden ab Jagdbeginn
	"welle_wachsen_sek": 120,   # alle so viele Sekunden ein Mann mehr je Welle
	"stufe2_ab": 300,           # ab hier kommen Wellen auf Fabrik-Stufe 2 …
	"faehigkeit_ab": 750,       # … ab hier auf Stufe 3 mit Fähigkeit (Minigun, Brandfeld …) – 25.11. (Paul): ab 12:30 (vorher 9:00)
	"staerke_je_min": 4,        # Prozent mehr Schaden je Minute für neue Truppen
	"tempo_je_min": 2,          # Prozent schneller je Minute (höchstens +40 %)
	"leben_je_min": 10,         # Prozent mehr Leben je Minute – 20.11. (Paul): vorher 3 (Brakks Schaden wuchs viel schneller)
	"lager_neu_ab": 360,        # ab hier baut der Technoclan neue Lager (außer Brakks Sicht) …
	"lager_neu_takt": 150,      # … so oft …
	"lager_max": 8,             # … bis so viele Lager stehen
	"tore_ab": 480,             # ab hier setzt er Tore in seine Wälle Richtung Myriaden-HQ …
	"tore_takt": 60,            # … so oft …
	"tore_max": 4,              # … höchstens so viele
	"welle_groesse": 8,         # so groß (dazu +1 je welle_wachsen_sek)   # 20.11. (Paul): +2
	"welle_minus_je_fabrik": 0, # so viele Mann weniger je zerstörter Fabrik draußen, dauerhaft – 26.11. (Paul): 0 (vorher 1); die Fabriken geben dafür Ringe als Beute, die Wellen bleiben planbar
	"elite_jede": 2,            # jede so vielte Welle ein Elitetrupp aus genau drei
	# 26.11. (Paul): Angriffstaktiken der Jagdwellen (brakk_jagdtaktik.gd)
	"taktik_an": true,          # false = altes Verhalten (jagen nur bei Sicht oder Meldung), für Vergleiche
	"ortung_takt": 15,          # Funkortung: so oft kennt eine Welle Brakks Ort neu …
	"ortung_ungenau": 3,        # … bis zu so viele Felder daneben
	"taktik_gewicht_sturm": 2.0,   # Wahl gewichtet zufällig – Paul: Sturm bevorzugt
	"taktik_gewicht_zange": 1.0,
	"taktik_gewicht_feuerschutz": 1.0,
	"taktik_gewicht_hinterhalt": 1.0,
	"zange_min": 6,             # Mindestgrößen, sonst Sturm
	"feuerschutz_min": 4,       # (dazu zwei Fernkämpfer)
	"sturm_streuung": 130,      # Prozent Streuung beim Schießen im Gehen
	"feuerschutz_abstand_min": 7,  # Feuergruppe: so weit weg von Brakk – gekappt auf die eigene Reichweite
	"feuerschutz_abstand_max": 9,
	"feuerschutz_sprung": 3.5,  # Sturmgruppe: so viele Felder je Sprung …
	"feuerschutz_halten": 2.0,  # … dann so lange halten und schießen
	"feuerschutz_nah": 4,       # geht Brakk so nah an die Feuergruppe, stürmen alle
	"hinterhalt_warten": 25,    # Hinterhalt: so lange wartet er höchstens …
	"hinterhalt_abstand": 6,    # … und eröffnet, sobald Brakk so nah ist
	"vorstoss": true,           # Technoclan darf das Myriaden-HQ einnehmen
	"vorstoss_start": 480,      # ab dann marschiert ein Jagdtrupp darauf
	"vorstoss_sek": 20,         # so lange muss er es halten – 26.11. (Paul): 20 statt 30, dafür sichtbarer Einnahme-Ring
	"vorstoss_rueckgang": 0.35, # 26.11. (Paul): ohne Truppen am HQ sinkt der Ring mit so viel × Fülltempo
	"brakk_schaden": 45,        # Prozent: so viel Schaden der Verteidigung kommt bei Brakk an – 20.11. (Paul): 45 statt 25, Sabotieren war ohne Gefahr
	"sabotage_schaden": 150,    # Prozent: Schaden an Brakk, solange er sabotiert (ungeschützt an der Fabrik)
	"hq_aggro_radius": 10,      # 20.11. (Paul): Felder um den Schild des Technoclan-HQ, in denen die KI aggressiver wird …
	"hq_aggro_schaden": 50,     # … bis zu so viel Prozent mehr Schaden an Brakk direkt am Schild; ab halber Nähe rücken auch die Verteidiger aus
	"medkit_takt": 60,          # Med-Kit am Myriaden-HQ liegt so oft wieder, nach dessen Fall so oft eins verstreut
	"heilturm_prozent": 1,      # 20.11. (Paul): Heilturm am Myriaden-HQ – so viel Prozent von Brakks Leben je Sekunde (E5, 26.11.: 1 statt 2, das HQ ist nicht mehr der einzige Ort zum Heilen) …
	"heilturm_radius": 2,       # … in so vielen Feldern Umkreis, solange kein Technoclan in 3 Feldern ist
	"medkit_heilung": 15,       # Prozent von Brakks Leben – 20.11. (Paul): deutlich weniger (vorher 40)
	"fabriken_aussen": 4,       # Lager über die Karte verteilt (Fabrik, Stellungen, Turm)
	"fabriken_innen": 3,        # im Schild, für Brakk nicht erreichbar
	"stufe_innen": 2,           # 20.11. (Paul): Fabriken im Schild ausgebaut wie im normalen Spiel
	"besatzung_innen": 3,       # so viele Truppen hält jede Fabrik im Schild zur Verteidigung
	"ausfall_sicht": 8,         # 26.11. (Paul): sieht die Schildbesatzung (Streife zu zweit) Brakk so nah, macht ein Paar einen Ausfall …
	"ausfall_sek": 15,          # … höchstens so lange, dann zurück in den Schild …
	"ausfall_pause": 20,        # … und erst danach der nächste (je Schild höchstens einer zugleich)
	"abstand_min": 0.6,         # 26.11. (Paul): Felder – so weit halten Technoclan-Truppen am Boden mindestens auseinander
	"praemie_kill": 7,          # 20.11. (Paul): Kopfgeld je Kill (Elite ×3) – 7 statt 12, sonst kommen die Ringe zu schnell
	"kill_stufe": 2,            # … je so vielen Kills an derselben Stellung (am Boden: derselben Fabrik) sinkt es um 1 …
	"kill_frist": 30,           # … und ist nach so vielen Sekunden ohne Kill dort wieder voll (gegen stumpfes Abfarmen)
	"praemie_fabrik": 200,      # 20.11. (Paul): wenig Geld, dafür Erfahrung
	"gold_faktor": 0.8,         # F4 (26.11., Paul): jedes Gold-Einkommen × so viel (Kills, Fabriken, Sabotage, Beute-Gold, Kopfgeld beim Ausschalten, geheimes Einkommen; vorher 1,0); Erfahrung bleibt
	"praemie_stellung": 0,
	"praemie_wall": 0,
	"xp_fabrik": 25,            # Erfahrung für Brakk: zerstörte Fabrik …
	"xp_sabotage": 12,          # … sabotierte Fabrik
	"xp_kill": 0,               # 20.11. (Paul): zusätzliche Erfahrung je Kill (Elite ×3) – 0: Stufe 8 nach 3:32 war viel zu schnell
	"kill_xp_prozent": 88,      # Prozent der normalen Kill-Erfahrung – 25.11. (Paul): +10 % (vorher 80)
	"truppen_leben": 90,        # Prozent: Leben der Technoclan-Truppen – 20.11. (Paul): 90 statt 70, Brakk wird mit mehr Ringen stärker
	"turm_wall_bonus": 2,       # Felder mehr Reichweite der Türme, solange Brakk auf den Erdwällen läuft
	"karte": "",                # "" = Zufall unter den Formationen aus [H], sonst eine Formation oder "phantom" (Verteidigungs-Phantom)
	"gebiete": false,           # E (26.11.): große Karte mit Gebieten und Zufluchten (setzt die Karte befehl24_gross)
	# 20.11. (Paul, Ergänzung Befehl 24): Regeln nur in diesem Modus
	"stellungen_je_fabrik": 4,  # Stellungen um jede Fabrik außerhalb des Schilds
	"patrouille": 2,            # so viele Truppen je Fabrik außerhalb gehen Streife
	"produktion_sek": 12,       # Produktionszyklus: so oft liefert eine Fabrik Ersatz (normal 5)
	"tuerme": 6,                # Formtürme auf der Formation
	"lager_tuerme": 1,          # dazu je Lager ein Geschützturm
	"heiltuerme": 1,            # dazu Heiltürme mit Instandsetzung
	"fabrik_leben": 1380,       # Fabrik außerhalb: so viel Schaden bis zu Trümmern (Ladestrahl zählt mit 10 % davon) – 25.11. (Paul): rund 15 s Dauerfeuer auf der Startstufe (vorher 1500); F4 (26.11., Paul): × 1,5 – vorher 920
	"sabotage_halten": 5,       # Sekunden [F] an der Rückseite halten – 20.11. (Paul): 5 statt 3, dafür brechen Treffer nicht mehr ab
	"sabotage_lahm": 0,         # so lange liefert eine sabotierte Fabrik nichts – 0 = bis der Pilot sie repariert (20.11., Paul)
	"praemie_sabotage": 100,
	"alarm_radius": 6,          # Felder: bei Angriff auf eine Fabrik laufen Truppen im Umkreis hin
	"pilot_verzug": 25,         # F4 (26.11., Paul): 25 statt 40 – Sekunden nach einer Sabotage geht ein Pilot mit zwei Begleitern los
	"pilot_neu": 30,            # F4: 30 statt 45 – fällt der Pilot, dauert der nächste so lange
	"pilot_reparatur": 5,       # Sekunden Reparatur vor Ort
	"kern_leben": 400,          # Turmkern: leer geschossen fällt der Turm aus, bis ein Pilot ihn repariert (20.11., Paul)
	"spreng_drop": 5,           # Prozent: gefallene Truppe lässt eine Sprengladung fallen – 20.11. (Paul): vorher 12
	"spreng_drop_elite": 50,    # Prozent: gefallene Elite lässt eine Sprengladung fallen – 26.11. (Paul): 50 statt immer
	"spreng_max": 3,            # höchstens so viele im Gepäck
	"spreng_zuender": 3,        # Sekunden Zünder
	"ladung_liegt_sek": 20,     # 26.11. (Paul): eine gefallene Sprengladung liegt so lange, dann blendet sie aus …
	"ladung_liegt_max": 4,      # … und höchstens so viele liegen zugleich (die älteste verschwindet)
	"mobil_abkling": 125,       # 20.11. (Paul): Prozent Abklingzeit von Q und E (Anker, Lichttreppe, Lichtbrücke) – eher eingekesselt
	"geschoss_tempo": 75,       # 20.11. (Paul): Prozent Tempo von Laser und Battlesphären-Schüssen auf Brakk (Plasma bleibt) – reagierbar bei vielen Schützen
	"herausforderer": true,     # 26.11. (Paul): zu Minute 9 und 14 tritt ein Benannter allein an (nemesis_herausforderer.gd)
}
const SCHILD_RADIUS := 3.2       # Felder um das Technoclan-HQ, in die Brakk nicht hineinkommt
const WEITER_START_ABSTAND := 7.0   # 27.11. (Paul): Felder – nach dem Classic-Sieg startet Brakk möglichst so weit von jeder Fabrik
const SICHT_JAEGER := 7.0        # Felder: so weit sieht ein Jäger Brakk (mit freier Sicht)
# 23.11. (Paul): Zange – Jagdtrupps kommen über eigene Seiten und schlagen gleichzeitig zu; im Angriff fächern sie auf,
# und wer am Ziel keine Sicht hat, sucht sich ein Schussfeld.
const ZANGE_AB := 7.0            # Felder: ist ein Trupp weiter weg, marschiert er erst zu einem eigenen Anmarschpunkt
const ZANGE_ABSTAND := 5         # Felder: so weit von Brakks letztem Ort liegt der Anmarschpunkt
const ZANGE_WARTE := 8.0         # Sekunden: so lange warten die Bereiten höchstens auf die anderen Trupps
const ZANGE_NAH := 4.0           # Felder: sieht ein Trupp Brakk so nah, schlägt er sofort zu
const ZANGE_NEU := 4.0           # Felder: so weit muss Brakk sich bewegen, damit die Zange neu angesetzt wird
const ZANGE_MAX_SEK := 25.0      # nach so viel Anmarsch schlägt ein Trupp auf jeden Fall zu
const ZANGE_UMWEG := 2.5         # Anmarschweg höchstens so viel länger als der direkte Weg (sonst andere Seite)
const WEG_STRAFE := 6.0          # Wegkosten auf Feldern, die schon ein anderer Trupp nimmt (getrennte Anmarschwege)
const FAECHER_RADIUS := 1.6      # Felder: so weit vor Brakk verteilen sich die Mitglieder im Halbkreis
const SCHUSSFELD_SEK := 2.0      # so lange ohne Sicht am Ziel, dann sucht ein Jäger ein Feld mit Sicht
const SCHUSSFELD_WEITE := 5      # Felder: so weit sucht er
const OHNE_FAEHIGKEIT := "laser"          # 25.11. (Paul): kein Laserstrahl-Scharfschütze in Befehl 24 – nicht ausweichbar
const FAEHIGKEIT_ERSATZ := "durchschuss"  # … geladene Laser-Fabriken und -Truppen bekommen stattdessen diese
const BAU_SCHADEN := 0.6         # Brakks Schüsse auf Gebäude wirken mit diesem Anteil
const LANZE_FABRIK := 0.10       # 20.11.: der Ladestrahl nimmt einer Fabrik mindestens 10 % ihres Lebens
const ELITE_TON := "tc-grenade"  # 25.11. (Paul): Platzhalter, bis es eigene Elite-Klänge gibt
const ELITE_TON_DB := 2.0
const LAGER_RADIUS := 3         # 25.11.: Felder – so weit liegen die Stellungen eines Lagers höchstens von seiner Fabrik
const FABRIK_BALKEN_SEK := 4.0  # 25.11. (Paul): Lebensbalken über einer angeschossenen Fabrik – so lange nach dem letzten Treffer
const BEUTE_NAH := 0.7           # 25.11.: Felder – so nah muss Brakk an der Beute einer Fabrik sein
const BEUTE_GOLD_ANTEIL := 0.5   # 25.11. (Paul): trägt Brakk alle Ringarten, liegt Gold: dieser Anteil von praemie_fabrik
const BEUTE_GOLD_FARBE := Color("ffd66b")
const LADUNG_REICHWEITE := 1.8   # 20.11.: Felder – so weit vor Brakk darf der Erdwall für die Sprengladung liegen
const LADUNG_SCHADEN := 120.0    # 20.11.: Truppen dicht an der Sprengung
const LADUNG_AUSBLENDEN := 0.8   # 26.11.: Sekunden – so lange blendet eine liegende Sprengladung vor dem Verschwinden aus
const ALARM_SEK := 20.0          # 20.11.: so lange bleiben alarmierte Truppen an der Fabrik
const BRAKK_NAH := 5.0            # 20.11. (Paul): Felder – so nah an Brakk geht keine Truppe in eine Stellung
const TECHNO_FARBE := Color("b46cff")
const ABSTAND_SCHUB := 2.0        # 26.11.: Felder je Sekunde – so schnell schiebt der Mindestabstand höchstens
const VORSTOSS_BRAKK_NAH := 3.0   # 26.11. (Paul): Felder – steht Brakk so nah am Myriaden-HQ, füllt sich der Einnahme-Ring …
const VORSTOSS_BRAKK_TEMPO := 0.5 # … nur mit diesem Anteil des Tempos
const VORSTOSS_RING_HOEHE := 3.0  # 3D-Höhe des Einnahme-Rings über dem HQ

var spiel: Node
var karte: Karte
var werte := {}
var zeit := 0.0                  # echte Sekunden seit dem Start
var jagd := false
var laeuft := false
var vorbei := false
var brakk_ziel: BrakkZiel = null
var _ziele := {}                 # Schlüssel (Einheit-ID oder "z:x,y") -> TechnoZiel
var _ziel_takt := 0.0
var trupps: Array = []           # 20.11.: Jagdtrupps {"mitglieder", "modus" (jagd/suche/streife/vorstoss), "zuletzt", "gesehen", "suche_bis", "mitte"}
var jaeger := {}                 # Einheit-ID -> Nummer des Trupps
var bekannt := Karte.KEINE       # Brakks letzter bekannter Ort …
var bekannt_zeit := -99.0        # … und wann
var wellen := 0
var _naechste_welle := 0.0
var taktik: BrakkJagdtaktik = null   # 26.11.: Angriffstaktiken der Jagdwellen
var schildwache: BrakkSchildwache = null   # 26.11. (Paul): Streife und Ausfall der Schildbesatzung
var zuflucht: BrakkZuflucht = null    # E4 (26.11., Paul): Zufluchtsorte der großen Karte (nur mit Regel gebiete)
var tafeln := NemesisTafeln.new()   # 25.11.: Hologramm-Tafeln (Elite-Auftritt, Beförderung, Vertreibung, Wiedersehen)
var _elite_zeile_bis := -1.0     # so lange steht „Elitetrupp“ in der Phasenzeile
var _vorstoss_wahl := 0.0
var _suchziel := {}              # Einheit-ID -> {"z", "bis"} beim Suchen
var _flucht_gemeldet := false
var _phase_vorher := ""
var _terminal_erklaert := false
var heilturm := Karte.KEINE       # 20.11. (Paul): Heilturm am Myriaden-HQ (Platzhalter am Boden)
var heilt := false               # heilt gerade
var _heil3d: Node3D = null
var _lichtmenue_bis := -1.0       # Überläufer: kleines Lichtmenü mit dem Neuen (bis zu dieser Zeit)
var _takt := 0.0
var _druck_naechster := 0.0
var geheim := false              # 20.11. (Paul): geheimer Verlauf „Überläufer“ läuft
var _lager_naechst := 0.0
var _tore_naechst := 0.0
var tore_gesetzt := 0
var tor_versuche := 0             # Prüfung: so oft wurde nach einem Tor gesucht
var _brakk_ahnt := false
var _sonde_hq_gemeldet := false   # 26.11.: Sonde 7 bei 50 % Einnahme
var _ring3d: Sprite3D = null      # 26.11.: Einnahme-Ring über dem Myriaden-HQ
var _ring_prozent := -1
var funk: Verrat24 = null         # Funkspruch im Spiel (Steuerung frei)
var vorstoss_anteil := 0.0       # 0..1 Einnahme des Myriaden-HQ
var hq_eingenommen := false
var schild_mitten: Array[Vector2] = []
var terminal := Karte.KEINE      # linke obere Zelle des 2×2-Ringterminals
var medkits: Array = []          # je {"zelle": Vector2i, "da": bool, "knoten": Node3D}
var _medkit_uhr := 0.0
var sabotage := {"fabriken": 0, "stellungen": 0, "waelle": 0, "truppen": 0, "geld": 0, "sabotiert": 0}
var log_wege: Array = []         # für die Prüfung: je Gruppe die Felder ihres Wegs
var schaden_an_brakk := {}       # Quelle (spiel.schadensquelle, gekürzt auf die Art) -> Schaden an Brakk (Balance)
var _knoten3d: Array = []
var _terminal_ring: MeshInstance3D = null   # 20.11. (Nachtrag): Ring über dem Ringterminal
var _terminal_mat: StandardMaterial3D = null
var _schild3d: Array = []
# 20.11. (Ergänzung Befehl 24)
var in_deckung := true           # keine Stellung sieht Brakk
var deckung_sek := 0.0           # Zeit in Deckung (Spielstil)
var ladungen := 0                # Sprengladungen im Gepäck
var ladungen_boden: Array = []   # je {"pos": Vector2, "knoten": Node3D}
var zuender: Array = []          # je {"zelle": Vector2i, "rest": float, "knoten": Node3D}
var beute_boden: Array = []      # 25.11.: aus zerstörten Fabriken, je {"pos": Vector2, "ring": String ("" = Gold), "knoten": Node3D, "hinweis": float}
var gesprengt := {}              # Wallfeld -> {"ausbau": int, "stufe": int, "faehigkeit": String, "rest": float}
var kern := {}                   # Turmfeld -> Leben des Kerns
var kern_aus := {}               # Turmfeld -> Sekunden bis er wieder läuft
var fabrik_hp := {}              # Fabrik außerhalb -> Leben
var rueckseite := {}             # Fabrik außerhalb -> Feld an ihrer Rückseite (Sabotage)
var routen := {}                 # Fabrik außerhalb -> Streifenweg (Felder)
var _streife := {}               # Einheit-ID -> Index im Streifenweg
var lahm := {}                   # sabotierte Fabrik -> Sekunden, bis sie von selbst wieder läuft
var _lager_namen := {}           # 25.11.: Fabrik draußen -> „Lager A“ …
var _rauch3d := {}               # 25.11.: sabotierte Fabrik -> Rauchsäule und dunkle Leuchtleiste
var truemmer: Array[Vector2i] = []
var alarm := {}                  # Einheit-ID -> {"ziel": Vector2i, "bis": float}
var _alarm_zuletzt := {}         # Fabrik -> Zeitpunkt des letzten Alarms
var sabo := {}                   # laufende Sabotage {"zelle", "t", "leben"} oder leer
var pilot: Einheit = null        # Pilot, der gerade eine Sabotage repariert
var eskorte: Array = []
var pilot_auftraege: Array = []  # je {"z": Vector2i, "ab": float}
var _pilot_ab := 0.0             # frühester Zeitpunkt für einen neuen Piloten (nach einem gefallenen)
var _hatte_pilot := false
var _schnellstart := false       # Besatzung der Fabriken steht gleich zu Beginn
var kills := 0
var verrat_ueberspringen := false   # Test: ohne Verrat-Sequenz
var arena: BrakkBossarena = null   # G2 (27.11., Paul): Bossarena – nur der Kampfplatz, kein Lauf
var weiter := false                # 20.11. (Paul): nach dem Classic-Sieg weitergespielt – die eigene Verteidigung ist der Gegner
static var test_werte := {}       # Tests: überschreiben das Regelpaket (main lädt die Karte beim Start neu)
var verrat: Verrat24 = null       # 20.11.: läuft gerade die Verrat-Sequenz?
var verrat_fertig := false
var _verraeter: Array = []        # die drei Technogunner der Sequenz
var schild_auf := 1.0             # 0..1 Kuppel des Schilds (schließt sich in der Sequenz)
var nemesis: Nemesis = null       # 22.11. (Paul): Nemesis-System – Eliten sind Personen (scripts/nemesis.gd)
var herausforderer: NemesisHerausforderer = null   # 26.11.: der Boss zu Minute 9 und 14
var plan_pause := 0.0             # so lange ruhte der Fahrplan schon (Herausforderung)
var _war_gesperrt := false        # F1: ruhte der Fahrplan im letzten Bild (danach die Schonfrist)
var sichter: Einheit = null       # 22.11.: Stellung, die Brakk zuletzt gesehen hat (Nemesis: Sichtung)
var markiert_bis := -1.0          # 22.11. (Nemesis Teil 3): bis hier kennen alle Trupps Brakks Ort (Markierung)
var _zange := {}                 # 23.11.: {"ziel": Vector2i, "erst_bereit": float, "los": bool}
var _ohne_sicht := {}            # 23.11.: Einheit-ID -> Zeit, seit der sie am Ziel nichts sieht
var _schussfeld := {}            # 23.11.: Einheit-ID -> {"z", "bis"}


## 22.11. (Nemesis Teil 4): Brakk tut etwas, das sich die Benannten abschauen können (Tumble, Klonmaschine …).
func brakk_gewohnheit(a: String) -> void:
	if nemesis == null or nemesis.gewohnheiten == null or not laeuft:
		return
	if a == "tumble":
		nemesis.gewohnheiten.tumble()
	else:
		nemesis.gewohnheiten.zaehle(a)


## 22.11. (Nemesis Teil 5): Elite im Gehen schießen lassen (direkt und Flanke rücken nach, Sperrfeuer weicht zurück).
func drueckt(e: Einheit) -> bool:
	return (nemesis != null and nemesis.lernen != null and nemesis.lernen.drueckt(e)) or (taktik != null and taktik.drueckt(e)) or (schildwache != null and schildwache.drueckt(e))   # 26.11.: Sturm schießt im Gehen; Rückweg nach dem Ausfall


## 22.11. (Nemesis Teil 3): Brakks Lauftempo (Ego-Sicht) – im Kegel eines Unterdrückungsfeuers langsamer.
func brakk_tempo_faktor() -> float:
	var mal := nemesis.faehigkeiten.tempo_faktor() if nemesis != null and nemesis.faehigkeiten != null else 1.0
	return mal * (herausforderer.brakk_bremse() if herausforderer != null else 1.0)   # 26.11.: Vergeltung mit dem Gelring


func w(schluessel: String) -> Variant:
	return werte.get(schluessel, STANDARD[schluessel])


func wf(schluessel: String) -> float:
	return float(w(schluessel))


# ------------------------------------------------------------------ Aufbau

func einrichten(p_spiel: Node) -> void:
	spiel = p_spiel
	karte = spiel.karte
	werte = STANDARD.duplicate()
	var o: Variant = Werte.KARTE_REGELN.get("order24", {})
	if o is Dictionary:
		for k: String in (o as Dictionary):
			werte[k] = (o as Dictionary)[k]
	for k: String in test_werte:
		werte[k] = test_werte[k]
	if BrakkBossarena.aktiv():
		for k: String in BrakkBossarena.REGELN:
			werte[k] = BrakkBossarena.REGELN[k]   # G2: Bossarena – nichts läuft von selbst
		verrat_ueberspringen = true
	# keine Myriaden-Bauten außer dem HQ (Schleudern und Laser zielen sonst auf den Technoclan)
	for b: Zonenbau in spiel.zonenbauten.duplicate():
		if b.art != "hq":
			spiel.zonenbauten.erase(b)
			b.queue_free()
	for nr in Werte.ZONENBAUTEN.size():
		spiel._zone_gebaut[nr] = true
	var sperren: Variant = Werte.KARTE_REGELN.get("bauten", {})
	Werte.KARTE_REGELN["bauten"] = {}   # der Aufbau darf alles; Brakk selbst baut danach nichts (Sperren der Karte)
	_karte_aufbauen()
	_ohne_laser()
	_lager_benennen()
	Werte.KARTE_REGELN["bauten"] = sperren
	karte.sicht_eigenes_feld = true   # 20.11.: Stellungen sehen nur über ihr eigenes Feld hinaus
	karte.ziel_wall_sichtbar = true   # 20.11. (Paul): Bodentruppen sehen (und treffen) Brakk auch oben auf einem Erdwall
	brakk_ziel = BrakkZiel.new()
	brakk_ziel.o24 = self
	brakk_ziel.spiel = spiel
	brakk_ziel.karte = karte
	brakk_ziel.typ = "hund"
	brakk_ziel.daten = Werte.GEGNER["hund"]
	brakk_ziel.rolle = "hund"
	brakk_ziel.visible = false
	_zuflucht_legen()
	if zuflucht != null:
		zuflucht.einrichten()   # E4: Medkit-Depot und Sprengstoffkasten in jedem Zufluchtsort
	nemesis = Nemesis.new()
	add_child(nemesis)
	nemesis.einrichten(self)
	taktik = BrakkJagdtaktik.new(self)
	schildwache = BrakkSchildwache.new(self)
	herausforderer = NemesisHerausforderer.new()
	add_child(herausforderer)
	herausforderer.einrichten(nemesis)
	if BrakkBossarena.aktiv():
		arena = BrakkBossarena.new()   # G2
		add_child(arena)
		arena.einrichten(self)


func _karte_aufbauen() -> void:
	if weiter:
		_karte_uebernehmen()
		return
	var wahl := str(w("karte"))
	var formationen: Array[String] = BrakkGebiete.formationen_b24() if bool(w("gebiete")) else Werte.ALARM_FORMATIONEN   # E3: die _b24-Fassungen
	var phantome: Array = Phantom.liste("verteidigung") if Werte.SPALTEN == 28 else []
	if wahl == "":
		wahl = formationen.pick_random()   # 20.11. (Paul): eine Formation aus [H] wie in Runde 20 (Phantom nur, wenn gewählt)
	var stellungen: Array[Vector2i] = []
	var phantom_ok := false
	if wahl.begins_with("phantom") and not phantome.is_empty():
		var p: Dictionary = phantome.pick_random()
		var d := Phantom.lade(str(p["pfad"]))
		var runden: Array = d.get("runden", [])
		if not runden.is_empty():
			var k: Dictionary = d.get("karte", {})
			var b: Variant = k.get("basis", [])
			if b is Array and (b as Array).size() == 2:
				spiel.setze_basis(Vector2i(int(b[0]), int(b[1])))
			var cps: Variant = k.get("checkpoints", [])
			if cps is Array and (cps as Array).size() == 2:
				spiel.setze_checkpoints(cps)
			spiel._setze_stand((runden[runden.size() - 1] as Dictionary)["stand"])
			wahl = "Phantom %s" % str(p.get("spieler", "?"))
			phantom_ok = true
	if not phantom_ok:
		if not Nachschlag.PLAENE_GROSS.has(wahl):
			wahl = formationen.pick_random()
		if bool(w("gebiete")):
			var form := BrakkGebiete.formation(wahl)   # E3/E4: _b24-Plan mit Zufluchten
			spiel._setze_stand({"waelle": form["waelle"], "fabriken": [], "batterien": []})   # G: samt den Erdwall-Ringen der Zufluchten
			if BrakkBossarena.aktiv():
				_arena_karte()   # G2: nur die Wälle
				return
			zuflucht = BrakkZuflucht.new(self, form["zufluchten"])
		else:
			stellungen = spiel.partie_start.formation_aufbauen(wahl, 0, 0, 0)   # 20.11.: Fabriken und Stellungen setzt Order24 (Lager)
	print("ORDER24 Karte: %s" % wahl)
	# Schild um das HQ, darin Fabriken (20.11., Paul: mindestens drei, ausgebaut wie im normalen Spiel)
	var basis_mitte: Vector2 = karte.mitte(karte.basis) + Vector2(0, -Werte.ZELLE * 0.5)
	schild_mitten = [basis_mitte]
	var innen := 0
	var innen_felder: Array[Vector2i] = []
	for dy in range(-3, 4):
		for dx in range(-3, 4):
			var z := karte.basis + Vector2i(dx, dy)
			if karte.ist_bebaubar(z) and karte.mitte(z).distance_to(basis_mitte) < (SCHILD_RADIUS - 0.5) * Werte.ZELLE:
				innen_felder.append(z)
	innen_felder.shuffle()
	for z: Vector2i in innen_felder:
		if innen >= int(w("fabriken_innen")):
			break
		var nah := false
		for n: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			if karte.inhalt(z + n) == Karte.FABRIK:
				nah = true
		if not nah and _setze_fabrik(z, Werte.ALARM_TRUPPEN[innen % Werte.ALARM_TRUPPEN.size()], int(w("stufe_innen"))):
			innen += 1
	# eine Batterie mit Pilotenfabrik im Schild (20.11., Paul): reicht über die Fabriken draußen, von hier kommt der Pilot
	var b_feld := karte.basis + Vector2i(-2, 0)
	for versuch: Vector2i in [Vector2i(-2, 0), Vector2i(-2, 1), Vector2i(-2, -1), Vector2i(-1, 1), Vector2i(-1, -1), Vector2i(1, 1), Vector2i(1, -1), Vector2i(-3, 0), Vector2i(-3, 2), Vector2i(-3, -2)]:
		b_feld = karte.basis + versuch
		if karte.ist_bebaubar(b_feld) and karte.ist_bebaubar(spiel.partner_feld(b_feld)) and spiel.baue(b_feld, Karte.BATTERIE, true):
			break
	# 20.11. (Paul): Lager auf der Karte verteilt – je eine Fabrik mit Stellungen und Türmen als Abwehr
	if not phantom_ok:
		_lager_verteilen()
	# Stellungen ringsum jede Fabrik außerhalb (2 Felder entfernt, reicht der Platz nicht, 3); Leben, Rückseite, Streifenweg
	var richtungen: Array[Vector2i] = [Vector2i(-1, 0), Vector2i(0, -1), Vector2i(0, 1), Vector2i(1, 0), Vector2i(-1, -1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(1, 1)]
	for z: Vector2i in spiel.fabriken.keys():
		if _im_schild(karte.mitte(z)) or str(spiel.fabriken[z]["typ"]) == "pilot":
			continue
		var gebaut := 0
		for weite: int in [2, 3]:
			for d: Vector2i in richtungen:
				var n := z + d * weite
				if gebaut >= _lager_stellungen(z):   # E: je Gebiet
					break
				if karte.inhalt(n) == Karte.WALL and not karte.ausbau.has(n) and not karte.stuetze_von.has(n):
					karte.baue_aus(n, Karte.STELLUNG)
					gebaut += 1
				elif karte.ist_bebaubar(n) and not _im_schild(karte.mitte(n)) and not karte.ist_basis(n) and not (zuflucht != null and zuflucht.bereich(n)):
					karte.setze(n, Karte.WALL)
					karte.baue_aus(n, Karte.STELLUNG)
					gebaut += 1
		fabrik_hp[z] = wf("fabrik_leben")
		for i in int(w("lager_tuerme")):
			_lager_turm(z)
	_tuerme_setzen()
	_wege_freimachen()
	for z: Vector2i in karte.feld:
		karte.fest[z] = true
	karte.cp_aktiv = false
	karte.cp_route = false
	karte.aktualisiere_pfad()
	for z: Vector2i in fabrik_hp:
		rueckseite[z] = _rueck_feld(z)
		routen[z] = _streifenweg(z)
	print("ORDER24 Fabriken %d (im Schild %d) · Stellungen %d · Türme %d (Heiltürme %d) · Batterie %s" % [spiel.fabriken.size(), innen, _zaehle_ausbau(Karte.STELLUNG), _zaehle_ausbau(Karte.TURM), karte.turm_art.values().count("heil"), str(b_feld)])


## G2 (27.11., Paul): Bossarena – die Wälle der großen Karte stehen, sonst nichts (keine Fabriken, Batterie, Lager, Türme,
## Zufluchten). Der Schild ums HQ bleibt als Kulisse.
func _arena_karte() -> void:
	schild_mitten = [karte.mitte(karte.basis) + Vector2(0, -Werte.ZELLE * 0.5)]
	for z: Vector2i in karte.feld:
		karte.fest[z] = true
	karte.cp_aktiv = false
	karte.cp_route = false
	karte.aktualisiere_pfad()
	print("ORDER24 Bossarena: nur Wälle (%d)" % karte.feld.size())


## 25.11. (Paul): Welche Stufe-3-Fähigkeiten eine Truppenart in Befehl 24 haben darf (ohne OHNE_FAEHIGKEIT).
static func faehigkeiten_stufe3(typ: String) -> Array:
	return (Werte.STUFE_3.get(typ, {}) as Dictionary).keys().filter(func(f: String) -> bool: return f != OHNE_FAEHIGKEIT)


## 25.11. (Paul): Geladene Karten (Verteidigungs-Phantom, Weiterspielen nach Classic) bringen eigene Fähigkeiten mit –
## Fabriken und schon stehende Truppen mit OHNE_FAEHIGKEIT bekommen FAEHIGKEIT_ERSATZ.
func _ohne_laser() -> void:
	for z: Vector2i in spiel.fabriken:
		if str(spiel.fabriken[z].get("faehigkeit", "")) == OHNE_FAEHIGKEIT:
			spiel.fabriken[z]["faehigkeit"] = FAEHIGKEIT_ERSATZ
	for x: Variant in spiel.einheiten:
		if is_instance_valid(x) and x != spiel.kommandant and str((x as Einheit).faehigkeit) == OHNE_FAEHIGKEIT:
			var e := x as Einheit
			e.daten = e.daten.duplicate()
			e.daten["faehigkeit"] = FAEHIGKEIT_ERSATZ
			e.faehigkeit = FAEHIGKEIT_ERSATZ


## 20.11. (Paul): Weiterspielen nach dem Classic-Sieg – nichts neu bauen: die Verteidigung des Spielers ist die Karte.
## Schild ums HQ; fehlen Fabriken darin, kommen welche dazu (von dort kommen die Jagdwellen). Alle Fabriken draußen sind
## Lager (Leben, Sabotage, Streife), alle Türme haben einen Kern. Wege aus Taschen werden geöffnet, die Zuflucht liegt am
## Myriaden-HQ.
func _karte_uebernehmen() -> void:
	var basis_mitte: Vector2 = karte.mitte(karte.basis) + Vector2(0, -Werte.ZELLE * 0.5)
	schild_mitten = [basis_mitte]
	var innen := 0
	for z: Vector2i in spiel.fabriken:
		if _im_schild(karte.mitte(z)) and str(spiel.fabriken[z]["typ"]) != "pilot":
			innen += 1
	var innen_felder: Array[Vector2i] = []
	for dy in range(-3, 4):
		for dx in range(-3, 4):
			var z := karte.basis + Vector2i(dx, dy)
			if karte.ist_bebaubar(z) and karte.mitte(z).distance_to(basis_mitte) < (SCHILD_RADIUS - 0.5) * Werte.ZELLE:
				innen_felder.append(z)
	innen_felder.shuffle()
	for z: Vector2i in innen_felder:
		if innen >= int(w("fabriken_innen")):
			break
		if _setze_fabrik(z, Werte.ALARM_TRUPPEN[innen % Werte.ALARM_TRUPPEN.size()], int(w("stufe_innen"))):
			innen += 1
	for z: Vector2i in spiel.fabriken:
		if not _im_schild(karte.mitte(z)) and str(spiel.fabriken[z]["typ"]) != "pilot":
			fabrik_hp[z] = wf("fabrik_leben")
	for z: Vector2i in karte.ausbau:
		if karte.ausbau[z] == Karte.TURM:
			kern[z] = wf("kern_leben")
	karte.turm_schaden.clear()
	karte.ausgefallen.clear()
	_wege_freimachen()
	for z: Vector2i in karte.feld:
		karte.fest[z] = true
	karte.cp_aktiv = false
	karte.cp_route = false
	karte.aktualisiere_pfad()
	for z: Vector2i in fabrik_hp:
		rueckseite[z] = _rueck_feld(z)
		routen[z] = _streifenweg(z)
	print("ORDER24 Übernahme der eigenen Verteidigung: Fabriken %d (im Schild %d) · Stellungen %d · Türme %d" % [spiel.fabriken.size(), innen, _zaehle_ausbau(Karte.STELLUNG), kern.size()])


## 20.11. (Paul): Schockimpuls in der Verrat-Sequenz nach dem Classic-Sieg – Brakk verliert Erfahrung und Ringe und
## fängt auf der Startstufe von Befehl 24 neu an (Regelpaket brakk_stufe, sonst 4). Ringfelder der Fabriken erlöschen.
func _schock() -> void:
	var k: Kommandant = spiel.kommandant
	if k == null:
		return
	for z: Vector2i in spiel.fabriken:
		(spiel.fabriken[z] as Dictionary).erase("ring")
	var vorher := k.fortschritt.stufe if k.fortschritt != null else 1
	var ringe := k.fortschritt.ringe.size() if k.fortschritt != null else 0
	k.max_leben = float(k.daten["leben"])
	k.leben = k.max_leben
	k.fortschritt = BrakkFortschritt.new(k)
	spiel.budget = 300
	if spiel.ego != null:
		spiel.ego.set("_trauma", 1.0)
	Ton.spiele(spiel, "tc-arc", 0.0)
	Ton.spiele(spiel, "alert", -2.0)
	spiel.melde("Schockimpuls: %d Ringe und alle Erfahrung verloren – zurück von Stufe %d auf Stufe %d." % [ringe, vorher, k.fortschritt.stufe], 6.0)
	print("ORDER24 Schock: Stufe %d → %d, %d Ringe weg" % [vorher, k.fortschritt.stufe, ringe])


## 20.11.: Fabrik direkt auf die Karte (ohne Bauregeln und Wegprüfung – im Aufbau gilt der Gegnerweg nicht).
func _setze_fabrik(z: Vector2i, typ: String, stufe: int) -> bool:
	if not karte.ist_bebaubar(z) or karte.ist_basis(z):
		return false
	karte.setze(z, Karte.FABRIK)
	spiel.fabriken[z] = {"timer": 0.0, "einheiten": [], "typ": typ, "stufe": stufe}
	karte.fabrik_typ[z] = typ
	karte.fabrik_stufe[z] = stufe
	return true


## E (26.11., Paul): große Karte – die Lager kommen in ihre Gebiete (ORDER24_LAGER: zwei im Gürtel, je eins in den
## Außenposten), auf das bebaubare Feld nahe dem Wunschfeld, mindestens 4 Felder von anderen Fabriken.
func _lager_nach_gebieten() -> void:
	var i := 0
	for platz: Array in BrakkGebiete.lager_plaetze():
		var r := BrakkGebiete.rechteck(str(platz[0]))
		var soll: Vector2i = platz[1]
		var bestes := Karte.KEINE
		var beste := INF
		for y in range(maxi(1, r.position.y), mini(Werte.ZEILEN - 1, r.end.y)):
			for x in range(r.position.x, r.end.x):
				var z := Vector2i(x, y)
				if not karte.ist_bebaubar(z) or _im_schild(karte.mitte(z)) or karte.ist_basis(z) or BrakkGebiete.gebiet(z) != str(platz[0]) or (zuflucht != null and zuflucht.bereich(z)):
					continue
				if spiel.fabriken.keys().any(func(f: Vector2i) -> bool: return Vector2(f - z).length() < 4.0):
					continue
				var d := Vector2(z - soll).length()
				if d < beste:
					beste = d
					bestes = z
		if bestes != Karte.KEINE:
			_setze_fabrik(bestes, Werte.ALARM_TRUPPEN[i % Werte.ALARM_TRUPPEN.size()], 1)
			i += 1


## Stellungen und Streife eines Lagers: auf der großen Karte je Gebiet, sonst die Regeln.
func _lager_stellungen(z: Vector2i) -> int:
	var n := BrakkGebiete.stellungen(BrakkGebiete.gebiet(z)) if bool(w("gebiete")) else -1
	return n if n >= 0 else int(w("stellungen_je_fabrik"))


func _lager_streife(z: Vector2i) -> int:
	var n := BrakkGebiete.streife(BrakkGebiete.gebiet(z)) if bool(w("gebiete")) else -1
	return n if n >= 0 else int(w("patrouille"))


## E: Kills und Schaden an Brakk je Gebiet (wo Brakk stand) – für den Bericht und das Protokoll.
var gebiet_zahlen := {}

func gebiet_zaehlen(art: String, menge: float) -> void:
	if not bool(w("gebiete")) or spiel.kommandant == null:
		return
	var g := BrakkGebiete.gebiet(karte.zelle_bei((spiel.kommandant as Kommandant).position))
	var z: Dictionary = gebiet_zahlen.get(g, {"kills": 0.0, "schaden": 0.0, "treffer": 0.0})
	z[art] = float(z.get(art, 0.0)) + menge
	if art == "schaden":
		z["treffer"] = float(z["treffer"]) + 1.0
	gebiet_zahlen[g] = z
	var f: BrakkFortschritt = (spiel.kommandant as Kommandant).fortschritt
	if f != null:
		f.protokoll.ereignis(spiel, "kill" if art == "kills" else "treffer", {"gebiet": g})


## 20.11. (Paul): `fabriken_aussen` Lager über die Karte verteilt – zwischen Myriaden-Zone und Schild, abwechselnd oben,
## unten und in der Mitte, mindestens 4 Felder auseinander.
func _lager_verteilen() -> void:
	if bool(w("gebiete")):
		_lager_nach_gebieten()
		return
	var n := int(w("fabriken_aussen"))
	var x0 := float(Werte.ZONE_SPALTEN + 5)
	var x1 := float(karte.basis.x - 5)
	var reihen: Array[float] = [0.25, 0.75, 0.5]
	for i in n:
		var soll := Vector2(lerpf(x0, x1, (float(i) + 0.5) / float(n)), float(Werte.ZEILEN - 1) * reihen[i % reihen.size()])
		var bestes := Karte.KEINE
		var beste := INF
		for y in range(1, Werte.ZEILEN - 1):
			for x in range(Werte.ZONE_SPALTEN + 3, Werte.SPALTEN - 1):
				var z := Vector2i(x, y)
				if not karte.ist_bebaubar(z) or _im_schild(karte.mitte(z)) or karte.ist_basis(z):
					continue
				var frei := true
				for f: Vector2i in spiel.fabriken:
					if Vector2(f - z).length() < 4.0:
						frei = false
				if not frei:
					continue
				var d := Vector2(z).distance_to(soll)
				if d < beste:
					beste = d
					bestes = z
		if bestes != Karte.KEINE:
			_setze_fabrik(bestes, Werte.ALARM_TRUPPEN[i % Werte.ALARM_TRUPPEN.size()], 1)


## 20.11. (Paul): Turm am Lager – ein T-Stück aus vier Erdwällen 2–3 Felder neben der Fabrik, darauf ein Geschützturm.
func _lager_turm(f: Vector2i) -> void:
	var arme: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	for r: int in [2, 3]:
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var c := f + Vector2i(dx, dy)
				if not (karte.ist_bebaubar(c) or (karte.inhalt(c) == Karte.WALL and not karte.ausbau.has(c) and not karte.stuetze_von.has(c))) or _im_schild(karte.mitte(c)) or karte.ist_basis(c) or (bool(w("gebiete")) and (BrakkGebiete.gebiet(c) != BrakkGebiete.gebiet(f) or (zuflucht != null and zuflucht.bereich(c)))):   # E: im Gebiet des Lagers, nicht an den Zufluchten
					continue
				var nah := false
				for t: Vector2i in karte.ausbau:
					if karte.ausbau[t] == Karte.TURM and Vector2(t - c).length() < 3.0:
						nah = true
				if nah:
					continue
				var dazu: Array[Vector2i] = []
				for a: Vector2i in arme:
					var n := c + a
					if karte.inhalt(n) == Karte.WALL and not karte.ausbau.has(n) and not karte.stuetze_von.has(n):
						dazu.append(n)
					elif karte.ist_bebaubar(n) and not karte.ist_basis(n) and n.distance_squared_to(f) > 1:
						dazu.append(n)
				if dazu.size() < 3:
					continue
				var felder: Array[Vector2i] = [c]
				felder.append_array(dazu.slice(0, 3))
				for n: Vector2i in felder:
					if karte.inhalt(n) != Karte.WALL:
						karte.setze(n, Karte.WALL)
				if karte.freie_stuetzen(c).size() >= 3:
					karte.baue_aus(c, Karte.TURM)
					kern[c] = wf("kern_leben")
				return


## 20.11. (Paul): Die KI darf sich nicht selbst einmauern – vom Schild führen mindestens drei Wege hinaus (nach oben, zur
## Mitte und nach unten Richtung Myriaden-Zone). Blanke Erdwälle auf dem günstigsten Weg werden entfernt; schon benutzte
## Felder kosten mehr, damit die Wege verschieden laufen. Ein kleines Labyrinth bleibt.
func _wege_freimachen() -> void:
	var m: Vector2 = schild_mitten[0]
	var extra := {}
	var geoeffnet := 0
	var schild: Array[Vector2i] = []
	for y in Werte.ZEILEN:
		for x in Werte.SPALTEN:
			var z := Vector2i(x, y)
			if karte.mitte(z).distance_to(m) < (SCHILD_RADIUS - 0.3) * Werte.ZELLE and karte.ist_begehbar(z) and karte.ist_frei(z):
				schild.append(z)
	for ziel_y: float in [0.15, 0.5, 0.85]:
		var ziel := Vector2i(Werte.ZONE_SPALTEN + 1, clampi(roundi(float(Werte.ZEILEN - 1) * ziel_y), 1, Werte.ZEILEN - 2))
		geoeffnet += _oeffne_weg(schild, ziel, extra)
	# 20.11. (Paul): auch jedes Lager hat einen Weg zum Schild (sonst stehen seine Truppen in einer Tasche fest)
	if not schild.is_empty():
		for f: Vector2i in fabrik_hp:
			var raus: Array[Vector2i] = []
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				if karte.ist_begehbar(f + d) and karte.ist_frei(f + d):
					raus.append(f + d)
			if raus.is_empty():
				continue
			if not karte.einheiten_weg(raus[0], schild[0]).is_empty():
				continue
			geoeffnet += _oeffne_weg(raus, schild[0], extra)
		# jede abgeschlossene Fläche (Tasche in der Formation) bekommt einen Durchbruch
		for runde in 12:
			var tasche := _tasche(schild[0])
			if tasche.is_empty():
				break
			var n := _oeffne_weg(tasche, schild[0], extra)
			if n == 0:
				break
			geoeffnet += n
			karte.aktualisiere_pfad()
	karte.pruefe_stuetzen()
	karte.aktualisiere_pfad()
	print("ORDER24 Wege aus dem Schild: %d Erdwälle geöffnet" % geoeffnet)


## Eine begehbare Fläche, von der aus `ziel` nicht erreichbar ist (leer = keine). Nachbarschaft wie die Truppen: 4 Richtungen.
func _tasche(ziel: Vector2i) -> Array[Vector2i]:
	var gesehen := {}
	for y in Werte.ZEILEN:
		for x in range(Werte.ZONE_SPALTEN, Werte.SPALTEN):
			var s := Vector2i(x, y)
			if gesehen.has(s) or not karte.ist_begehbar(s) or not karte.ist_frei(s):
				continue
			var flaeche: Array[Vector2i] = [s]
			gesehen[s] = true
			var i := 0
			while i < flaeche.size():
				for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var n := flaeche[i] + d
					if karte.in_karte(n) and not gesehen.has(n) and karte.ist_begehbar(n) and karte.ist_frei(n):
						gesehen[n] = true
						flaeche.append(n)
				i += 1
			if not flaeche.has(ziel) and karte.einheiten_weg(s, ziel).is_empty():
				return flaeche
	return []


## Günstigster Weg von einem der Felder `von` nach `ziel` (frei 1, blanker Erdwall 6, schon benutzte Felder teurer);
## Erdwälle darauf werden entfernt. Gibt zurück, wie viele.
func _oeffne_weg(von: Array[Vector2i], ziel: Vector2i, extra: Dictionary) -> int:
	var kosten := {}
	var vorher := {}
	var offen: Array[Vector2i] = []
	for z: Vector2i in von:
		kosten[z] = 0.0
		offen.append(z)
	while not offen.is_empty():
		var bi := 0
		for i in offen.size():
			if float(kosten[offen[i]]) < float(kosten[offen[bi]]):
				bi = i
		var z: Vector2i = offen[bi]
		offen.remove_at(bi)
		if z == ziel:
			break
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n := z + d
			var k := _durchgang_kosten(n)
			if k >= INF:
				continue
			var neu := float(kosten[z]) + k + float(extra.get(n, 0.0))
			if neu < float(kosten.get(n, INF)):
				if not kosten.has(n):
					offen.append(n)
				kosten[n] = neu
				vorher[n] = z
	if not vorher.has(ziel):
		return 0
	var geoeffnet := 0
	var z2: Vector2i = ziel
	while vorher.has(z2):
		extra[z2] = 3.0
		if karte.inhalt(z2) == Karte.WALL:
			karte.entferne(z2)
			geoeffnet += 1
		z2 = vorher[z2]
	return geoeffnet


## Kosten eines Felds für _wege_freimachen: frei 1, blanker Erdwall 6 (wird geöffnet), sonst unpassierbar.
func _durchgang_kosten(z: Vector2i) -> float:
	if not karte.in_karte(z):
		return INF
	if zuflucht != null and zuflucht.im_ring(z):
		return INF   # G: der Erdwall-Ring einer Zuflucht bleibt zu (sie hat ihren Eingang)
	if karte.inhalt(z) == Karte.WALL:
		return 6.0 if not karte.ausbau.has(z) and not karte.stuetze_von.has(z) else INF
	if karte.ist_begehbar(z) and karte.ist_frei(z):
		return 1.0
	return INF


func _zaehle_ausbau(typ: int) -> int:
	var n := 0
	for z: Vector2i in karte.ausbau:
		if karte.ausbau[z] == typ:
			n += 1
	return n


## 20.11.: Formtürme auf Erdwällen der Formation, die schon eine Form bilden (Geschütz, Lanze, Frost), dazu Heiltürme mit
## Instandsetzung – bis insgesamt `tuerme` bzw. `heiltuerme` stehen (eine Phantom-Verteidigung bringt eigene mit). Außerhalb des
## Schilds, mindestens 4 Felder auseinander, bevorzugt nahe den Fabriken draußen. Alle Türme bekommen einen Kern.
func _tuerme_setzen() -> void:
	var kandidaten: Array = []
	for z: Vector2i in karte.feld:
		if karte.feld[z] != Karte.WALL or karte.ausbau.has(z) or karte.stuetze_von.has(z) or _im_schild(karte.mitte(z)) or (bool(w("gebiete")) and BrakkGebiete.gebiet(z) != "guertel"):   # E: Formtürme nur im Gürtel
			continue
		var form := karte.turm_form(z)
		if form == "" or form == "funk":
			continue
		var naehe := 99.0
		for f: Vector2i in fabrik_hp:
			naehe = minf(naehe, Vector2(f - z).length())
		kandidaten.append([naehe + randf() * 2.0, z, form])
	kandidaten.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	var gesetzt: Array[Vector2i] = []
	var heil := 0
	var andere := 0
	for z: Vector2i in karte.ausbau:
		if karte.ausbau[z] == Karte.TURM:   # schon da (Phantom-Verteidigung): zählen mit
			gesetzt.append(z)
			if bool(w("gebiete")):
				continue   # E: auf der großen Karte sind das Lagertürme – die Formtürme kommen dazu
			if karte.turm_art.get(z, "") == "heil":
				heil += 1
			else:
				andere += 1
	# E (26.11., Paul): auf der großen Karte kommt der Heilturm zuerst (erst eine fertige Treppe, sonst eine angebaute),
	# sonst ist im engen Gürtel nach den Formtürmen oft kein Wallende mit 4 Feldern Abstand mehr frei
	var nur_heil := bool(w("gebiete"))
	var reihe: Array = (kandidaten + [[]] + kandidaten) if nur_heil else kandidaten   # zwei Durchgänge, dazwischen die Treppe
	for k: Array in reihe:
		if k.is_empty():
			heil = _heil_treppe(gesetzt, heil)
			nur_heil = false
			continue
		var z: Vector2i = k[1]
		var form := str(k[2])
		var ist_heil := form == "heil"
		if (ist_heil and heil >= int(w("heiltuerme"))) or (not ist_heil and andere >= int(w("tuerme"))) or (nur_heil and not ist_heil):
			continue
		if karte.turm_form(z) != form or karte.stuetze_von.has(z):
			continue   # ein schon gesetzter Turm hat die Stützen genommen
		var zu_nah := false
		for g: Vector2i in gesetzt:
			if Vector2(g - z).length() < 4.0:
				zu_nah = true
		if zu_nah:
			continue
		karte.baue_aus(z, Karte.TURM)
		if ist_heil:
			karte.turm_stufe[z] = 3
			karte.turm_faehigkeit[z] = "instand"
			heil += 1
		else:
			andere += 1
		gesetzt.append(z)
	# zu wenige Formen auf der Formation: an gerade Wallstücke einen Erdwall quer anbauen (T-Stück = Geschützturm)
	for z: Vector2i in karte.feld.keys():
		if andere >= int(w("tuerme")):
			break
		if karte.feld.get(z, Karte.FREI) != Karte.WALL or karte.ausbau.has(z) or karte.stuetze_von.has(z) or _im_schild(karte.mitte(z)) or (bool(w("gebiete")) and BrakkGebiete.gebiet(z) != "guertel"):
			continue
		var zu_nah := false
		for g: Vector2i in gesetzt:
			if Vector2(g - z).length() < 4.0:
				zu_nah = true
		if zu_nah or karte.freie_stuetzen(z).size() != 2:
			continue
		var a: Vector2i = karte.freie_stuetzen(z)[0]
		var quer := Vector2i((a - z).y, (a - z).x)
		for n: Vector2i in [z + quer, z - quer]:
			if karte.freie_stuetzen(z).size() == 2 and karte.ist_bebaubar(n) and not karte.ist_basis(n):
				karte.setze(n, Karte.WALL)
				break
		if karte.turm_form(z) == "geschuetz":
			karte.baue_aus(z, Karte.TURM)
			andere += 1
			gesetzt.append(z)
	heil = _heil_treppe(gesetzt, heil)
	for z: Vector2i in gesetzt:
		kern[z] = wf("kern_leben")


## Heilturm mit Instandsetzung: fehlt eine Treppe, zwei Erdwälle schräg an einen Wall setzen (bis `heiltuerme` stehen).
## Hängt die neuen Türme an `gesetzt` an und gibt die neue Zahl der Heiltürme zurück.
## E (26.11., Paul): auf der großen Karte jeder Wall im Gürtel, nicht nur Wallenden – dicke Formationen haben vor den
## Formtürmen gar keine; der Turm wird dort ausdrücklich ein Heilturm (Stützen = das schräge Paar).
func _heil_treppe(gesetzt: Array[Vector2i], heil: int) -> int:
	var gebiete := bool(w("gebiete"))
	for z: Vector2i in karte.feld.keys():
		if heil >= int(w("heiltuerme")):
			break
		if karte.feld.get(z, Karte.FREI) != Karte.WALL or karte.ausbau.has(z) or karte.stuetze_von.has(z) or _im_schild(karte.mitte(z)) or (karte.freie_stuetzen(z).size() > 1 and not gebiete) or (gebiete and BrakkGebiete.gebiet(z) != "guertel"):
			continue
		var zu_nah := false
		for g: Vector2i in gesetzt:
			if Vector2(g - z).length() < 4.0:
				zu_nah = true
		if zu_nah:
			continue
		for d: Vector2i in [Vector2i(1, 1), Vector2i(1, -1)]:
			var ok := true
			for n: Vector2i in [z + d, z - d]:
				if not (karte.ist_bebaubar(n) and not karte.ist_basis(n)) and not (karte.inhalt(n) == Karte.WALL and not karte.ausbau.has(n) and not karte.stuetze_von.has(n)):
					ok = false
			if ok:
				for n: Vector2i in [z + d, z - d]:
					if karte.inhalt(n) != Karte.WALL:
						karte.setze(n, Karte.WALL)
				break
		if karte.turm_form(z) == "heil" or (gebiete and karte._diagonal_paar(z).size() == 2):
			karte.baue_aus(z, Karte.TURM, "heil")
			karte.turm_stufe[z] = 3
			karte.turm_faehigkeit[z] = "instand"
			heil += 1
			gesetzt.append(z)
	return heil


## 20.11.: Rückseite einer Fabrik = freies Nachbarfeld, möglichst zum Technoclan-HQ hin (dort wird sabotiert).
func _rueck_feld(z: Vector2i) -> Vector2i:
	var zum_hq := Vector2(karte.basis - z).normalized()
	var bestes := Karte.KEINE
	var wert := -INF
	for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var n := z + d
		if not karte.in_karte(n) or not karte.ist_begehbar(n) or not karte.ist_frei(n):
			continue
		var v := Vector2(d).dot(zum_hq)
		if v > wert:
			wert = v
			bestes = n
	return bestes


## 20.11.: Streifenweg um eine Fabrik: vier erreichbare Felder etwa 3 Felder entfernt (Ecken eines Quadrats).
func _streifenweg(z: Vector2i) -> Array[Vector2i]:
	var weg: Array[Vector2i] = []
	for ecke: Vector2i in [Vector2i(-3, -3), Vector2i(3, -3), Vector2i(3, 3), Vector2i(-3, 3)]:
		var bestes := Karte.KEINE
		var beste := INF
		for dy in range(-2, 3):
			for dx in range(-2, 3):
				var n := z + ecke + Vector2i(dx, dy)
				if not karte.in_karte(n) or n.x < Werte.ZONE_SPALTEN or not karte.ist_begehbar(n) or not karte.ist_frei(n) or _im_schild(karte.mitte(n)):
					continue
				var d := Vector2(dx, dy).length()
				if d < beste and not karte.einheiten_weg(z, n).is_empty():
					beste = d
					bestes = n
		if bestes != Karte.KEINE:
			weg.append(bestes)
	return weg


func _frei_2x2(e: Vector2i) -> bool:
	for d: Vector2i in [Vector2i.ZERO, Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
		if not karte.ist_bebaubar(e + d):
			return false
	return true


func _im_schild(p: Vector2) -> bool:
	for m: Vector2 in schild_mitten:
		if p.distance_to(m) < SCHILD_RADIUS * Werte.ZELLE:
			return true
	return false


## 20.11. (Verrat): Brakk startet am Technoclan-HQ – vor dem Schild auf der Seite zum Myriaden-HQ, mit Platz für die drei
## Technogunner zwischen ihm und dem Schild. Findet sich nichts, gilt das freie Feld vor dem Myriaden-HQ.
## 27.11. (Paul): Nach dem Classic-Sieg (weiter) steht dort die eigene Verteidigung – dann zuerst Plätze mit möglichst
## wenigen Fabriken im Umkreis von WEITER_START_ABSTAND (sonst fiel Brakk neben seiner alten Frontreihe in Sekunden).
func brakk_start() -> Vector2i:
	var m := schild_mitten[0] if not schild_mitten.is_empty() else karte.mitte(karte.basis)
	var zum_myr := (karte.mitte(Werte.ANGRIFFS_ZELLE) - m).normalized()
	var soll := m + zum_myr * (SCHILD_RADIUS + 2.8) * Werte.ZELLE
	var kandidaten: Array = []
	for y in Werte.ZEILEN:
		for x in range(Werte.ZONE_SPALTEN, Werte.SPALTEN):
			var z := Vector2i(x, y)
			var p := karte.mitte(z)
			var d := p.distance_to(m)
			if not karte.ist_begehbar(z) or not karte.ist_frei(z) or d < (SCHILD_RADIUS + 1.8) * Werte.ZELLE or d > (SCHILD_RADIUS + 7.0) * Werte.ZELLE:
				continue
			var nah := 0
			if weiter:
				for f: Vector2i in spiel.fabriken:
					if karte.mitte(f).distance_to(p) < WEITER_START_ABSTAND * Werte.ZELLE:
						nah += 1
			kandidaten.append([p.distance_to(soll) + nah * 1000.0 * Werte.ZELLE, z])
	kandidaten.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	for k: Array in kandidaten:
		if _klare_sicht(karte.mitte(k[1] as Vector2i)):
			return k[1]
	return kandidaten[0][1] if not kandidaten.is_empty() else _start_vor_myriaden()


## 20.11. (Paul): Wo die drei Technogunner der Verrat-Sequenz stehen – in Reihe zwischen Brakk (`p`) und dem Schild.
func _verraeter_pos(p: Vector2) -> Array[Vector2]:
	var m := schild_mitten[0] if not schild_mitten.is_empty() else karte.mitte(karte.basis)
	var zum_hq := (m - p).normalized()
	var quer := zum_hq.orthogonal()
	var aus: Array[Vector2] = []
	for i in 3:
		aus.append(p + zum_hq * 2.1 * Werte.ZELLE + quer * (float(i) - 1.0) * 0.6 * Werte.ZELLE)
	return aus


## 20.11. (Paul): Klare Sicht am Start – die drei Technogunner stehen frei, kein Erdwall zwischen Brakk, ihnen und dem HQ.
func _klare_sicht(p: Vector2) -> bool:
	var m := schild_mitten[0] if not schild_mitten.is_empty() else karte.mitte(karte.basis)
	for q: Vector2 in _verraeter_pos(p):
		var z := karte.zelle_bei(q)
		if not karte.ist_begehbar(z) or not karte.ist_frei(z) or not karte.sicht_frei(p, q):
			return false
	var rand := m + (p - m).normalized() * (SCHILD_RADIUS - 0.5) * Werte.ZELLE
	if not karte.sicht_frei(p, rand):
		return false
	# auch seitlich nicht an einem Wall kleben (der verdeckt die halbe Sicht)
	var hier := karte.zelle_bei(p)
	for n: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if karte.inhalt(hier + n) == Karte.WALL:
			return false
	return true


## Freies Feld in den ersten Spalten mit dem größten Abstand zu Stellungen und Türmen (nicht gleich unter Beschuss).
func _start_vor_myriaden() -> Vector2i:
	var bestes := Werte.START_ZELLE + Vector2i(Werte.ZONE_SPALTEN, 0)
	var weiteste := -1.0
	for x in range(Werte.ZONE_SPALTEN, Werte.ZONE_SPALTEN + 4):
		for y in range(1, Werte.ZEILEN - 1):
			var z := Vector2i(x, y)
			if not karte.ist_begehbar(z) or not karte.ist_frei(z):
				continue
			var naechste := 99.0
			for a: Vector2i in karte.ausbau:
				if karte.ausbau[a] == Karte.STELLUNG or karte.ausbau[a] == Karte.TURM:
					naechste = minf(naechste, Vector2(a - z).length())
			if naechste > weiteste:
				weiteste = naechste
				bestes = z
	return bestes


var _warte := 0.0

## Los geht es, sobald Brakk steht und die Einsatz-Tafel der Ego-Sicht zu ist (ohne Ego-Sicht nach einer Sekunde).
func _bereit(echt: float) -> bool:
	if spiel.kommandant == null:
		return false
	_warte += echt
	if spiel.ego == null:
		return _warte >= 1.0
	var tafel: Variant = spiel.ego.get("_briefing")
	return _warte >= 0.5 and (tafel == null or not (tafel as Control).visible)


func starten() -> void:
	laeuft = true
	var k: Kommandant = spiel.kommandant
	if k != null:
		k.daten = k.daten.duplicate()
		k.daten["kletter_abklingzeit"] = float(k.daten["kletter_abklingzeit"]) * wf("mobil_abkling") / 100.0   # 20.11. (Paul): Lichttreppe langsamer
	_schnellstart = true
	if not spiel.gegner.has(brakk_ziel):
		spiel.gegner.append(brakk_ziel)
	nemesis.appell([])   # 22.11.: die Drei vom Appell gibt es auch ohne Sequenz (übersprungen, Test)
	spiel.melde("Befehl 24: Der Technoclan hat sich gegen dich gewandt. Übersteh %d Minuten." % roundi(wf("ueberleben_sek") / 60.0), 10.0)


# ------------------------------------------------------------------ Verrat-Sequenz (20.11.)

## Brakk am Technoclan-HQ, drei Technogunner in Reihe zwischen ihm und dem (noch offenen) Schild, Blick zum HQ.
## Verrat24 tippt die Zeilen; die Ereignisse hier: anlegen (drehen, Anziel-Pose), verrat (roter Rand, Schild schließt sich),
## schuss (Einschlag neben Brakk), ueberspringen ([Esc]: alles auf einmal).
func _verrat_beginnen() -> void:
	var k: Kommandant = spiel.kommandant
	var m := schild_mitten[0] if not schild_mitten.is_empty() else karte.mitte(karte.basis)
	var zum_hq := (m - k.position).normalized()
	var von := karte.basis
	for z: Vector2i in spiel.fabriken:
		if not fabrik_hp.has(z) and str(spiel.fabriken[z]["typ"]) != "pilot":
			von = z
	_verraeter.clear()
	for q: Vector2 in _verraeter_pos(k.position):
		var e := _neue_truppe("technogunner", von, 0)
		e.position = q
		e._sprite.flip_h = m.x < e.position.x   # Blick zum HQ, Rücken zu Brakk
		_verraeter.append(e)
	nemesis.appell(_verraeter)   # 22.11. (Paul): die Drei vom Appell sind von Anfang an Personen mit Namen
	schild_auf = 0.0
	var ego: EgoModus = spiel.ego
	ego.gier = atan2(-zum_hq.x, -zum_hq.y)   # Blick zum HQ (gier 0 = Norden)
	ego.nick = -0.08
	verrat = Verrat24.new()
	if weiter:
		verrat.zeilen = Verrat24.ZEILEN_WEITER   # 20.11. (Paul): nach dem Sieg – mit Schockimpuls
	add_child(verrat)
	verrat.ereignis.connect(_verrat_ereignis)
	verrat.fertig.connect(_verrat_ende)
	print("ORDER24 Verrat: Brakk bei %s, drei Technogunner vor dem Schild" % str(karte.zelle_bei(k.position)))


## Steuerung gesperrt, solange die Sequenz läuft (ego_modus._frei).
func sperrt_steuerung() -> bool:
	return verrat != null


func _verrat_ereignis(was: String) -> void:
	var k: Kommandant = spiel.kommandant
	match was:
		"anlegen", "ueberspringen":
			for e: Einheit in _verraeter:
				if is_instance_valid(e):
					e._sprite.flip_h = k.position.x < e.position.x
					e.zustand = Einheit.Zustand.AUF_POSTEN   # nur für die Anziel-Pose (die Haltung aus der Stellung)
			if was == "ueberspringen":
				schild_auf = 1.0
				if weiter:
					_schock()   # auch übersprungen: Erfahrung und Ringe sind weg
			else:
				Ton.spiele(spiel, "tc-arc", -6.0)
		"schock":
			_schock()
		"verrat":
			Ton.spiele(spiel, "alert", -2.0)
			var tw := create_tween()
			tw.tween_property(self, "schild_auf", 1.0, 1.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		"schuss":
			var schuetze: Einheit = _verraeter[1] if _verraeter.size() > 1 and is_instance_valid(_verraeter[1]) else null
			var neben := k.position + (k.position - (schuetze.position if schuetze != null else k.position)).orthogonal().normalized() * 0.55 * Werte.ZELLE
			_schuss3d(schuetze.position if schuetze != null else neben, neben)
			Ton.spiele(spiel, "tc-rail", -2.0)
			if spiel.ego != null:
				spiel.ego.set("_trauma", minf(1.0, float(spiel.ego.get("_trauma")) + 0.55))


func _verrat_ende() -> void:
	for e: Einheit in _verraeter:
		if is_instance_valid(e):
			e.zustand = Einheit.Zustand.BODEN
	nemesis.appell_abtreten(_verraeter)   # 22.11. (Paul): Beam in den Schild – sie rüsten um und kommen mit dem ersten Elitetrupp
	_verraeter.clear()
	schild_auf = 1.0
	verrat_fertig = true
	spiel.erfolg("befehl24")   # 20.11. (Paul): Erfolg – die Flucht beginnt
	if verrat != null:
		verrat.queue_free()
	verrat = null
	print("ORDER24 Verrat vorbei – die Uhr läuft")


## Laserstrahl vom Verräter auf den Boden neben Brakk, mit Einschlag (Platzhalter aus Kästen).
func _schuss3d(von: Vector2, nach: Vector2) -> void:
	var hd: HdAnsicht = spiel.hd
	if hd == null:
		return
	var a := Vector3(von.x / Werte.ZELLE, 0.55, (von.y - Werte.KARTE_OBEN) / Werte.ZELLE)
	var b := Vector3(nach.x / Werte.ZELLE, 0.05, (nach.y - Werte.KARTE_OBEN) / Werte.ZELLE)
	var strahl := _kasten3d(hd, Vector3(0.05, 0.05, a.distance_to(b)), Color("9dff8a"), (a + b) / 2.0)
	strahl.look_at_from_position((a + b) / 2.0, b, Vector3.UP)
	var blitz := _kasten3d(hd, Vector3(0.5, 0.08, 0.5), Color("ffe14d"), b)
	for kn: MeshInstance3D in [strahl, blitz]:
		var tw := kn.create_tween()
		tw.tween_property(kn, "transparency", 1.0, 0.45)
		tw.tween_callback(kn.queue_free)


# ------------------------------------------------------------------ Ablauf

func _process(delta: float) -> void:
	var echt := delta / maxf(Engine.time_scale, 0.01)
	if not laeuft and not vorbei and spiel.phase == 0 and _bereit(echt):
		if verrat_fertig or verrat_ueberspringen or spiel.ego == null:
			starten()
			spiel.starte_welle(true)   # Kampf ohne Myriaden-Welle: die Fabriken produzieren, die Uhr läuft
		elif verrat == null:
			_verrat_beginnen()   # 20.11.: erst die Verrat-Sequenz, die Uhr startet danach
	if verrat != null:
		_3d_pflegen()
	if not laeuft or vorbei or spiel.phase != 1:
		return
	zeit += echt
	var k: Kommandant = spiel.kommandant
	if k == null:
		return
	if k.gefallen:
		_ende(false)
		return
	brakk_ziel.position = k.position
	brakk_ziel.leben = k.leben
	brakk_ziel.max_leben = k.max_leben
	_schild_halten(k)
	if _schnellstart:
		_schnellstart_pruefen()
	_ziel_takt -= delta
	if _ziel_takt <= 0.0:
		_ziel_takt = 0.25
		_ziele_pflegen()
		_deckung_pruefen(k)
	if in_deckung:
		deckung_sek += echt
	_ladungen_pflegen(k, echt)
	_beute_pflegen(k)
	tafeln.weiter(echt)
	herausforderer.weiter(echt)
	var gesperrt := herausforderer.sperrt()
	if gesperrt:
		_fahrplan_ruht(echt)
	elif _war_gesperrt:
		_naechste_welle = maxf(_naechste_welle, zeit + Werte.HERAUSFORDERER_SCHONFRIST)   # F1 (26.11., Paul): Schonfrist nach dem Duell
	_war_gesperrt = gesperrt
	_tuerme_pflegen(echt)
	_fabriken_pflegen(k, echt)
	_abstand_halten(echt)
	_takt -= echt
	if _takt <= 0.0:
		_takt = 1.0
		_ablauf(k)   # 20.11.: Phasen, Jagdtrupps, Wellen, Vorstoß
	if jagd:
		if phase() == "vorstoss" and not hq_eingenommen and not herausforderer.sperrt():
			_vorstoss(echt)
	_medkits_pflegen(k, echt)
	if zuflucht != null and not gesperrt:
		zuflucht.weiter(echt, k)   # E4: Aufenthaltsuhr, Depot, Kasten, Umformen (F1: ruht im Duell)
	_3d_pflegen()
	if wf("ueberleben_sek") > 0.0 and zeit >= wf("ueberleben_sek") and not geheim:
		_ende(true)
	# 20.11. (Paul): hält Brakk das Myriaden-HQ bis geheim_ab, beginnt der geheime Verlauf
	if not geheim and wf("geheim_ab") > 0.0 and plan_zeit() >= wf("geheim_ab") and not hq_eingenommen and not herausforderer.laeuft():
		_geheim_starten()
	if geheim:
		_geheim_pflegen(k, echt)


## Brakk kommt nicht in den Schild des HQ (am Rand wird er hinausgeschoben).
func _schild_halten(k: Kommandant) -> void:
	for i in schild_mitten.size():
		if i == 0 and hq_schild_aus:
			continue   # 20.11.: Überläufer – Schild des Technoclan-HQ gefallen
		var m: Vector2 = schild_mitten[i]
		var r := SCHILD_RADIUS * Werte.ZELLE
		var d := k.position - m
		if d.length() < r:
			k.position = m + (d.normalized() if d.length() > 0.1 else Vector2.LEFT) * r
			k.anker = k.position


func restzeit() -> float:
	return maxf(0.0, wf("ueberleben_sek") - zeit)


## 20.11.: Uhr oben – endlos (ueberleben_sek 0) zählt sie die überstandene Zeit hoch, sonst herunter.
func uhr_sek() -> float:
	return zeit if wf("ueberleben_sek") <= 0.0 else restzeit()



# ------------------------------------------------------------------ Truppen der Fabriken (20.11.)

## 20.11.: So viele Truppen hält eine Fabrik am Leben (-1 = wie im normalen Spiel). Draußen Stellungen plus Streife, im Schild
## keine (von dort kommen nur die Jagdtrupps), die Pilotenfabrik der Batterie wie immer.
func truppen_limit(z: Vector2i) -> int:
	if not spiel.fabriken.has(z) or str(spiel.fabriken[z]["typ"]) == "pilot":
		return -1
	if not fabrik_hp.has(z):
		return int(w("besatzung_innen"))   # 20.11. (Paul): Verteidiger im Schild
	return _lager_stellungen(z) + _lager_streife(z)   # E: auf der großen Karte je Gebiet


## 26.11. (Paul): Mindestabstand – Technoclan-Truppen am Boden halten in jedem Zustand abstand_min Felder zueinander
## (Trennkraft wie bei Boids, ohne den Weg zu ändern; Stellungen ausgenommen). Nachbarn über Feld-Eimer statt aller Paare.
## Ursache der Stapel: Streife und Ersatz eines Lagers laufen dieselben vier Eckfelder ab und stehen auf der Feldmitte, nur
## ±10 px Zufallsversatz auseinander; Alarm-Ziele (_freies_feld_nahe) fallen oft auf dasselbe Feld.
func _abstand_halten(echt: float) -> void:
	var min_abstand := wf("abstand_min") * Werte.ZELLE
	if min_abstand <= 0.0 or echt <= 0.0:
		return
	var eimer := {}
	var alle: Array = []
	for x in _truppen():
		var u := x as Einheit
		if u.zustand != Einheit.Zustand.BODEN or u.leben <= 0.0:
			continue
		alle.append(u)
		var z := karte.zelle_bei(u.position)
		if not eimer.has(z):
			eimer[z] = []
		(eimer[z] as Array).append(u)
	var max_schub := ABSTAND_SCHUB * Werte.ZELLE * echt
	for u: Einheit in alle:
		var z := karte.zelle_bei(u.position)
		var schub := Vector2.ZERO
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				for v: Einheit in eimer.get(z + Vector2i(dx, dy), []):
					if v == u:
						continue
					var d := u.position - v.position
					var l := d.length()
					if l >= min_abstand:
						continue
					if l < 0.01:   # genau aufeinander: feste Richtung je Paar
						d = Vector2.RIGHT.rotated(float(u.get_instance_id() % 628) / 100.0)
						l = 0.01
					schub += d / l * (min_abstand - l) * 0.5
		if schub == Vector2.ZERO:
			continue
		var neu := u.position + schub.limit_length(max_schub)
		if not karte.ist_begehbar(karte.zelle_bei(neu)):
			continue
		u.position = neu
		# am letzten Wegpunkt weggeschoben: gilt als angekommen (sonst tritt er dort auf der Stelle)
		if u._punkte.size() == 1 and u.position.distance_to(u._punkte[0]) <= min_abstand:
			u._punkte.clear()


## 20.11.: Truppe einer Fabrik im Schild (Verteidiger der Basis, keine Jäger aus der Besatzung).
func _ist_innen(e: Einheit) -> bool:
	return spiel.fabriken.has(e.fabrik_zelle) and not fabrik_hp.has(e.fabrik_zelle) and str(spiel.fabriken[e.fabrik_zelle]["typ"]) != "pilot"


## 20.11. (Paul): Jede neue Technoclan-Truppe in Befehl 24 ist schwächer (truppen_leben), es gibt dafür mehr Fabriken.
func neue_einheit(e: Einheit) -> void:
	var minuten := plan_zeit() / 60.0   # 20.11. (Paul): Eskalation – nicht nur Leben, auch Schaden und Tempo wachsen mit der Zeit
	e.max_leben *= wf("truppen_leben") / 100.0 * (1.0 + wf("leben_je_min") / 100.0 * minuten)
	e.leben = e.max_leben
	e.daten = e.daten.duplicate()
	e.daten["schaden"] = float(e.daten["schaden"]) * (1.0 + wf("staerke_je_min") / 100.0 * minuten)
	e.daten["tempo"] = float(e.daten["tempo"]) * minf(1.4, 1.0 + wf("tempo_je_min") / 100.0 * minuten)


## 20.11. (Paul): Läuft Brakk auf den Erdwällen, reichen die Türme weiter (und er ist ihr einziges Ziel).
func turm_bonus() -> float:
	var k: Kommandant = spiel.kommandant
	return wf("turm_wall_bonus") if laeuft and k != null and k.oben else 0.0


## 20.11.: Produktionszyklus – zu Beginn steht die Besatzung sofort (Schnellstart), danach Ersatz alle produktion_sek.
func produktion_sek() -> float:
	return 0.01 if _schnellstart else maxf(0.5, wf("produktion_sek"))


func _schnellstart_pruefen() -> void:
	for z: Vector2i in spiel.fabriken:
		if truppen_limit(z) >= 0 and (spiel.fabriken[z]["einheiten"] as Array).size() < truppen_limit(z):
			return
	_schnellstart = false


## 20.11.: Eine Technoclan-Truppe ist gefallen (main.einheit_gefallen): vielleicht bleibt eine Sprengladung liegen.
func gefallen(e: Einheit) -> void:
	if e.ist_pilot or not laeuft:
		return
	var chance := wf("spreng_drop_elite") if bool(e.daten.get("elite", false)) else wf("spreng_drop")   # 26.11. (Paul): Elite 50 % statt immer
	if randf() * 100.0 < chance:
		ladung_fallen_lassen(e.position)


## 26.11. (Paul): Sprengladung fällt zu Boden. Sie liegt ladung_liegt_sek; liegen schon ladung_liegt_max gefallene,
## verschwindet die älteste sofort. Die Ladung am Myriaden-HQ („bleibt“) zählt nicht mit und verschwindet nicht.
func ladung_fallen_lassen(p: Vector2) -> void:
	var gefallen := ladungen_boden.filter(func(l: Dictionary) -> bool: return not bool(l.get("bleibt", false)))
	while gefallen.size() >= int(w("ladung_liegt_max")):
		var alt: Dictionary = gefallen.pop_front()
		_ladung_weg(alt)
	ladungen_boden.append({"pos": p, "knoten": null, "bis": zeit + wf("ladung_liegt_sek")})


func _ladung_weg(l: Dictionary) -> void:
	ladungen_boden.erase(l)
	if l["knoten"] != null and is_instance_valid(l["knoten"]):
		(l["knoten"] as Node3D).queue_free()


# ------------------------------------------------------------------ Sicht und Deckung (20.11.)

## Keine Stellung sieht Brakk (in ihrer Reichweite und mit der Sichtregel von oben) = in Deckung.
func _deckung_pruefen(k: Kommandant) -> void:
	in_deckung = true
	for x in spiel.einheiten:
		if not is_instance_valid(x) or x == k:
			continue
		var e := x as Einheit
		if e.zustand != Einheit.Zustand.AUF_POSTEN or karte.inhalt(e.posten_zelle) != Karte.WALL:
			continue
		if e.position.distance_to(k.position) <= e.reichweite_jetzt() * Werte.ZELLE and karte.sicht_von_wall(e.posten_zelle, e.position, k.position):
			in_deckung = false
			sichter = e   # 22.11.: Nemesis – wer ihn gesichtet hat
			return


# ------------------------------------------------------------------ Ziele für Brakk (Stellvertreter)

func ego_ziele() -> Array:
	var aus: Array = []
	for t: TechnoZiel in _ziele.values():
		if not t._tot:
			aus.append(t)
	return aus


func _ziele_pflegen() -> void:
	var noch := {}
	var bp: Vector2 = spiel.kommandant.position
	for e in spiel.einheiten:
		if not is_instance_valid(e) or e == spiel.kommandant or not (e as Einheit).visible or (e as Einheit).in_batterie() or (e as Einheit).kampfunfaehig:
			continue   # 22.11.: kampfunfähige Personen sind kein Ziel mehr
		var schl := "e%d" % e.get_instance_id()
		noch[schl] = true
		var t: TechnoZiel = _ziele.get(schl, null)
		if t == null:
			t = _neues_ziel(schl)
			t.einheit = e
			t.art = "stellung" if (e as Einheit).in_stellung() else "truppe"
		t.position = (e as Einheit).position
		t.leben = (e as Einheit).leben
		t.max_leben = (e as Einheit).max_leben
		if herausforderer != null and herausforderer.ist_er(e):
			t.set_meta("treffer_hoehe", 0.42 + float((e as Einheit).get_meta("hebt_ab", 0.0)))   # C3: Sonde 7 schwebt – Brakk trifft sie dort
		t.art = "stellung" if (e as Einheit).in_stellung() else "truppe"
	# 20.11.: Fabriken außerhalb (Leben fabrik_leben) und Turmkerne; Erdwälle sind kein Ziel mehr (nur Sprengladungen)
	for z: Vector2i in fabrik_hp:
		var p := karte.mitte(z)
		if karte.inhalt(z) != Karte.FABRIK or p.distance_to(bp) > 14.0 * Werte.ZELLE:
			continue
		var schl := "f%d,%d" % [z.x, z.y]
		noch[schl] = true
		var t: TechnoZiel = _ziele.get(schl, null)
		if t == null:
			t = _neues_ziel(schl)
			t.zelle = z
			t.art = "fabrik"
			t.set_meta("treffer_hoehe", 0.5)
			t.set_meta("treffer_radius", 0.7)
		t.position = p
		t.leben = float(fabrik_hp[z])
		t.max_leben = wf("fabrik_leben")
	for z: Vector2i in kern:
		if karte.ausbau.get(z, Karte.FREI) != Karte.TURM or karte.turm_lahm(z) or karte.mitte(z).distance_to(bp) > 14.0 * Werte.ZELLE:
			continue
		var schl := "k%d,%d" % [z.x, z.y]
		noch[schl] = true
		var t: TechnoZiel = _ziele.get(schl, null)
		if t == null:
			t = _neues_ziel(schl)
			t.zelle = z
			t.art = "kern"
		t.position = karte.mitte(z)
		t.set_meta("treffer_hoehe", 0.9)   # 20.11. (Paul): der Kern sitzt oben im Turm und ist gut zu treffen
		t.set_meta("treffer_radius", 0.6)
		t.leben = float(kern[z])
		t.max_leben = wf("kern_leben")
	# 20.11.: Überläufer – ohne Schild ist das Technoclan-HQ ein Ziel für Brakks Waffen
	if geheim and hq_schild_aus and tc_hq_leben > 0.0:
		noch["hq"] = true
		var th: TechnoZiel = _ziele.get("hq", null)
		if th == null:
			th = _neues_ziel("hq")
			th.zelle = karte.basis
			th.art = "hq"
			th.set_meta("treffer_hoehe", 0.8)
			th.set_meta("treffer_radius", 1.0)
		th.position = karte.mitte(karte.basis) + Vector2(0, -Werte.ZELLE * 0.5)
		th.leben = tc_hq_leben
		th.max_leben = wf("geheim_hq_leben")
	for schl: String in _ziele.keys():
		if not noch.has(schl):
			var t: TechnoZiel = _ziele[schl]
			t._tot = true
			_ziele.erase(schl)
			t.free()


func _neues_ziel(schl: String) -> TechnoZiel:
	var t := TechnoZiel.new()
	t.o24 = self
	t.spiel = spiel
	t.karte = karte
	t.typ = "hund"
	t.daten = Werte.GEGNER["hund"]
	t.rolle = "hund"
	t.visible = false
	_ziele[schl] = t
	return t


## 26.11.: Ego-Sicht – Brakk springt oder tumbelt (der Herausforderer schaut es sich ab).
func brakk_bewegung(art: String, r: Vector2 = Vector2.ZERO) -> void:
	if laeuft and not vorbei and nemesis != null and nemesis.lernen != null:
		nemesis.lernen.bewegung(art, r)
	brakk_aktion(art)


## C2 (26.11.): Brakk springt, tumbelt oder setzt eine Lichtsäule – der Bosstyp reagiert (Ankerwurf reißen, Gel lösen,
## Lichtsäulen zählen).
func brakk_aktion(art: String) -> void:
	if not laeuft or vorbei or herausforderer == null:
		return
	if art == "saeule":
		herausforderer.saeulen += 1
	if herausforderer.zustand == "duell" and herausforderer.typ != null:
		herausforderer.typ.brakk_aktion(art)


## E4 (26.11., Paul): Steht Brakk in einer Zuflucht? Dann zielen Türme und Stellungen nicht auf ihn (Bodentruppen schon).
func brakk_in_zuflucht() -> bool:
	return zuflucht != null and zuflucht.brakk_drin()


## E4: Minikarte der Ego-Sicht – Felsen, Zufluchten (Kreuz) und verlorene Zufluchten (Lager).
func minikarte(ci: CanvasItem, o: Vector2, zelle: float) -> void:
	if zuflucht != null:
		zuflucht.minikarte(ci, o, zelle)


## C1 (26.11., Paul): Trennt die Lichtwand des Kampfplatzes die Strecke a → b (Bildpunkte)? Dann der Punkt an der Wand,
## sonst Vector2.INF. Für Schüsse von draußen hinein und von drinnen hinaus.
func lichtwand_schnitt(a: Vector2, b: Vector2) -> Vector2:
	return herausforderer.kampfplatz.schnitt(a, b) if herausforderer != null else Vector2.INF


## 26.11.: Ist dieses Ziel der Herausforderer? (Der Ladestrahl nimmt ihm so viel wie einem großen Gegner.)
func ist_herausforderer_ziel(g: Gegner) -> bool:
	return g is TechnoZiel and herausforderer != null and herausforderer.ist_er((g as TechnoZiel).einheit)


## Brakk hat einen Stellvertreter getroffen.
func treffer(t: TechnoZiel, menge: float) -> void:
	if t.einheit != null:
		if not is_instance_valid(t.einheit):
			t._tot = true
			return
		var e: Einheit = t.einheit
		if e.kampfunfaehig:
			t._tot = true   # 22.11.: Nemesis – liegt schon am Boden (zählt nicht noch einmal als Kill)
			return
		nemesis.von_brakk(e)   # 22.11.: Begegnung läuft
		nemesis.faehigkeiten.von_brakk(e, str(spiel.brakk_quelle) == "lanze")   # 22.11. (Teil 3): Ladestrahl stoppt den Sturmlauf
		if str(spiel.brakk_quelle) == "lanze":
			nemesis.gewohnheiten.fernschuss(e)   # 22.11. (Teil 4): Kampf aus der Ferne zählt
		menge *= nemesis.gewohnheiten.schild_faktor(e)   # 22.11. (Teil 4): Frontschild – von vorn nur 25 %
		if herausforderer.ist_er(e):
			menge *= herausforderer.schutz_faktor()   # 26.11.: Vergeltung mit dem Wallring
			if herausforderer.typ != null:
				menge = herausforderer.typ.vor_treffer(menge)   # C3: Sonde 7 – Heil-Impuls brechen, geborgen statt gefallen
			herausforderer.zaehle_boss_schaden(menge)   # G2: Zählung (Fenster genutzt)
		var war_stellung := e.in_stellung()
		var kg_ort := ("s:%s" % str(e.posten_zelle)) if war_stellung else ("f:%s" % str(e.fabrik_zelle))
		var elite := bool(e.daten.get("elite", false))
		_alarm_auf_brakk(spiel.kommandant)   # 20.11. (Paul): wer angegriffen wird, ruft Hilfe
		var vor := e.leben
		e.nimm_schaden(menge)
		nemesis.erlitten(e, vor - maxf(e.leben, 0.0))   # 22.11. (Teil 5): eigener Schaden in der Begegnung
		t.leben = e.leben
		if e.leben <= 0.0 or not is_instance_valid(e):
			nemesis.lernen.kill()   # 22.11. (Teil 5): Aufenthaltskarte – von hier aus hat Brakk getötet
			t._tot = true
			sabotage["truppen"] = int(sabotage["truppen"]) + 1
			kills += 1
			gebiet_zaehlen("kills", 1.0)   # E: wo Brakk stand
			_kopfgeld(kg_ort, 3 if elite else 1)   # 20.11. (Paul): Elite bringt dreifaches Kopfgeld
			var kk: Kommandant = spiel.kommandant
			if kk != null and kk.fortschritt != null and int(w("xp_kill")) > 0:
				kk.fortschritt.gib(int(w("xp_kill")) * (3 if elite else 1), kk)   # 20.11. (Paul): mehr Erfahrung je Kill
			if war_stellung and int(w("praemie_stellung")) > 0:
				_praemie("stellungen", int(w("praemie_stellung")), "Stellung geleert")
			elif war_stellung:
				sabotage["stellungen"] = int(sabotage["stellungen"]) + 1
		return
	if t.art == "hq":
		_tc_hq_treffer(menge * BAU_SCHADEN)
		t.leben = tc_hq_leben
		return
	var z := t.zelle
	if t.art == "kern":
		kern_treffer(z, menge)
		t.leben = float(kern.get(z, 0.0))
		if karte.turm_lahm(z):
			t._tot = true
		return
	if t.art == "fabrik":
		var schaden := menge * BAU_SCHADEN
		if str(spiel.brakk_quelle) == "lanze":
			schaden = maxf(schaden, wf("fabrik_leben") * LANZE_FABRIK)   # 20.11.: der Ladestrahl zählt mit 10 % Max-Leben
		fabrik_treffer(z, schaden)
		t.leben = float(fabrik_hp.get(z, 0.0))
		if not fabrik_hp.has(z):
			t._tot = true


## 20.11.: Schaden an einer Fabrik außerhalb; leer = Trümmer (kommt nicht wieder).
func fabrik_treffer(z: Vector2i, schaden: float) -> void:
	if not fabrik_hp.has(z) or karte.inhalt(z) != Karte.FABRIK:
		return
	_alarm(z)
	_fabrik_getroffen[z] = zeit
	fabrik_hp[z] = float(fabrik_hp[z]) - schaden
	if float(fabrik_hp[z]) > 0.0:
		return
	fabrik_hp.erase(z)
	lahm.erase(z)
	if spiel.fabriken.has(z):
		for e: Variant in (spiel.fabriken[z]["einheiten"] as Array):
			if is_instance_valid(e):
				(e as Einheit).fabrik_zelle = Karte.KEINE
		spiel.fabriken.erase(z)
	karte.fest.erase(z)
	karte.entferne(z)
	karte.aktualisiere_pfad()
	truemmer.append(z)
	if Werte.grafik_neu:
		spiel.effekte.fx("g_tod", karte.mitte(z) + Vector2(0, 16), 1.0)
	_praemie("fabriken", int(w("praemie_fabrik")), "Fabrik zerstört", int(w("xp_fabrik")))
	beute_legen(z)
	print("ORDER24 Fabrik %s zerstört bei %.0f s" % [str(z), zeit])


# ------------------------------------------------------------------ Beute aus zerstörten Fabriken (25.11., Paul)

## Ringarten, die als Beute infrage kommen: Brakk trägt sie nicht, und sie liegt noch nirgends.
func beute_arten() -> Array:
	var k: Kommandant = spiel.kommandant
	if k == null or k.fortschritt == null:
		return []
	var liegt: Array = beute_boden.map(func(b: Dictionary) -> String: return str(b["ring"]))
	return BrakkFortschritt.RINGE.keys().filter(func(r: String) -> bool: return k.fortschritt.ring_stufe(r) == 0 and not liegt.has(r))


## Auf dem Trümmerfeld liegt ein Ring einer neuen Art – nie eine Stufe auf einen vorhandenen. Hat Brakk alle Arten,
## liegt stattdessen Gold (BEUTE_GOLD_ANTEIL der Fabrik-Prämie). Sie bleibt liegen, bis Brakk sie aufhebt.
func beute_legen(z: Vector2i) -> void:
	var arten := beute_arten()
	beute_boden.append({"pos": karte.mitte(z), "ring": str(arten.pick_random()) if not arten.is_empty() else "", "knoten": null, "hinweis": -99.0})
	Ton.spiele(spiel, "alert", -4.0)


## 26.11. (Paul): Der Herausforderer lässt sofort einen Ring fallen – eine neue Art. Trägt Brakk schon so viele Ringe,
## wie er je tragen kann, ist es eine Stufe für einen davon (das gibt es nur hier). Sind alle auf der höchsten: Gold.
func beute_legen_herausforderer(pos: Vector2) -> void:
	var ort := pos
	if not karte.ist_frei(karte.zelle_bei(pos)):
		ort = karte.mitte(_freies_feld_bei(pos, karte.zelle_bei(spiel.kommandant.position)))
	var b := {"pos": ort, "ring": "", "knoten": null, "hinweis": -99.0, "herausforderer": true, "stufe": false}
	_beute_waehlen(b)
	beute_boden.append(b)
	Ton.spiele(spiel, "alert", -4.0)


func _beute_waehlen(b: Dictionary) -> void:
	var f: BrakkFortschritt = spiel.kommandant.fortschritt if spiel.kommandant != null else null
	b["stufe"] = false
	b["ring"] = ""
	if f == null:
		return
	var arten := beute_arten()
	if f.ringe.size() >= BrakkFortschritt.FINGER_AB.size() or arten.is_empty():
		var hoeher: Array = f.ringe.filter(func(r: String) -> bool: return f.ring_stufe(r) < BrakkFortschritt.RING_PREISE.size())
		if not hoeher.is_empty():
			b["ring"] = str(hoeher.pick_random())
			b["stufe"] = true
		return
	b["ring"] = str(arten.pick_random())


## Aufheben durch Drüberlaufen. Ohne freien Finger bleibt der Ring liegen.
func _beute_pflegen(k: Kommandant) -> void:
	var f := k.fortschritt
	for b: Dictionary in beute_boden.duplicate():
		var ring := str(b["ring"])
		if bool(b.get("herausforderer", false)) and f != null and ((bool(b["stufe"]) and (ring == "" or f.ring_stufe(ring) == 0 or f.ring_stufe(ring) >= BrakkFortschritt.RING_PREISE.size())) or (not bool(b["stufe"]) and ring != "" and (f.ring_stufe(ring) > 0 or f.ringe.size() >= BrakkFortschritt.FINGER_AB.size()))):
			_beute_waehlen(b)   # am Terminal verändert: neu bestimmen
			ring = str(b["ring"])
			_beute_bild_weg(b)
		elif not bool(b.get("herausforderer", false)) and ring != "" and f != null and f.ring_stufe(ring) > 0:
			# inzwischen am Terminal gekauft: eine andere neue Art (sonst gäbe das Aufheben eine Stufe)
			b["ring"] = ""
			var arten := beute_arten()
			ring = str(arten.pick_random()) if not arten.is_empty() else ""
			b["ring"] = ring
			_beute_bild_weg(b)
		if k.gefallen or k.position.distance_to(b["pos"] as Vector2) > BEUTE_NAH * Werte.ZELLE:
			continue
		if ring == "":
			var geborgen := gold(int(wf("praemie_fabrik") * BEUTE_GOLD_ANTEIL))   # F4: gold_faktor
			spiel.budget += geborgen
			sabotage["geld"] = int(sabotage["geld"]) + geborgen
			spiel.melde("Gold geborgen: +%d" % geborgen, 3.0)
		elif bool(b.get("stufe", false)):
			if f == null or f.schenke_stufe(ring, spiel) != "":
				continue
			spiel.melde("Ring geborgen: %s – jetzt Stufe %d" % [str((BrakkFortschritt.RINGE[ring] as Dictionary).get("name", ring)), f.ring_stufe(ring)], 4.0)
		else:
			if f == null:
				continue
			if f.ringe.size() >= f.finger():
				if zeit - float(b["hinweis"]) > 4.0:
					b["hinweis"] = zeit
					spiel.melde("Kein Finger frei – der Ring bleibt liegen.", 2.5)
				continue
			if f.schenke(ring, spiel) != "":
				continue
			spiel.melde("Ring geborgen: %s" % str((BrakkFortschritt.RINGE[ring] as Dictionary).get("name", ring)), 4.0)
		Ton.spiele(spiel, "tc-arc", -2.0)
		_beute_bild_weg(b)
		beute_boden.erase(b)


func _beute_bild_weg(b: Dictionary) -> void:
	if b["knoten"] != null and is_instance_valid(b["knoten"]):
		(b["knoten"] as Node).queue_free()
	b["knoten"] = null


## 25.11. (Paul): Eine sabotierte Fabrik sieht man an: Rauchsäule aus dem Dach, die Leuchtleiste am Sockel ist aus
## (abgedunkelt ist ihr Bild schon durch HdAnsicht, ein laufendes Förderband hat es nicht) – bis zur Reparatur.
func _sabotage_3d(hd: HdAnsicht) -> void:
	var t := float(Time.get_ticks_msec()) / 1000.0
	for z: Vector2i in _rauch3d.keys():
		if not lahm.has(z) or not fabrik_hp.has(z):
			(_rauch3d[z] as Node).queue_free()
			_rauch3d.erase(z)
	for z: Vector2i in lahm:
		if not fabrik_hp.has(z):
			continue
		if not _rauch3d.has(z):
			var kn := Node3D.new()
			hd.add_child(kn)
			kn.position = Vector3(float(z.x) + 0.5, 0.0, float(z.y) + 0.5)
			_kasten3d(kn, Vector3(0.6, 0.036, 0.018), Color("14161b"), Vector3(0, 0.065, 0.468))   # über der Leuchtleiste (_fabrik_block)
			for i in 9:
				var m := MeshInstance3D.new()
				var kugel := SphereMesh.new()
				kugel.radius = 0.24
				kugel.height = 0.48
				kugel.radial_segments = 10
				kugel.rings = 5
				m.mesh = kugel
				m.material_override = _leucht(Color("7a7a86"), 0.9)
				m.name = "Qualm%d" % i
				kn.add_child(m)
			_rauch3d[z] = kn
		for i in 9:
			var q := (_rauch3d[z] as Node3D).get_node("Qualm%d" % i) as MeshInstance3D
			var a := fmod(t * 0.3 + float(i) / 9.0, 1.0)
			q.position = Vector3(0.12 + 0.35 * a + 0.07 * sin(t * 1.7 + float(i) * 2.1), 1.15 + 2.1 * a, 0.0)
			q.scale = Vector3.ONE * (0.45 + 0.9 * a)
			(q.material_override as StandardMaterial3D).albedo_color.a = 0.9 * (1.0 - 0.8 * a)


## 26.11. (Paul): Einnahme-Ring über dem Myriaden-HQ – Billboard in Technoclan-Lila, füllt sich im Uhrzeigersinn
## (von oben). Das Bild wird nur neu gemalt, wenn sich der Prozentwert ändert.
func _einnahme_3d(hd: HdAnsicht) -> void:
	var zeigen := einnahme_sichtbar()
	if _ring3d == null:
		if not zeigen:
			return
		_ring3d = Sprite3D.new()
		_ring3d.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_ring3d.shaded = false
		_ring3d.no_depth_test = true   # auch hinter dem HQ-Dach sichtbar
		_ring3d.pixel_size = 0.9 / float(RING_BILD)   # knapp ein Feld groß (1,6 verdeckte von nah die Phasenzeile)
		var p := karte.mitte(Werte.ANGRIFFS_ZELLE)
		_ring3d.position = Vector3(p.x / Werte.ZELLE, VORSTOSS_RING_HOEHE, (p.y - Werte.KARTE_OBEN) / Werte.ZELLE)
		hd.add_child(_ring3d)
	_ring3d.visible = zeigen
	var pz := floori(100.0 * vorstoss_anteil)
	if zeigen and pz != _ring_prozent:
		_ring_prozent = pz
		_ring3d.texture = ImageTexture.create_from_image(ring_bild(vorstoss_anteil))


const RING_BILD := 64   # Kantenlänge des Ringbilds in Pixeln


## Ringbild: dunkler Grundring, darauf der gefüllte Teil in Technoclan-Lila ab 12 Uhr im Uhrzeigersinn.
static func ring_bild(anteil: float) -> Image:
	var img := Image.create(RING_BILD, RING_BILD, false, Image.FORMAT_RGBA8)
	var m := RING_BILD / 2.0
	for y in RING_BILD:
		for x in RING_BILD:
			var d := Vector2(x + 0.5 - m, y + 0.5 - m)
			var r := d.length()
			if r < m * 0.62 or r > m * 0.98:
				continue
			var winkel := fposmod(atan2(d.x, -d.y), TAU)   # 0 oben, wächst im Uhrzeigersinn
			var voll := winkel <= anteil * TAU
			img.set_pixel(x, y, TECHNO_FARBE if voll else Color(0.1, 0.06, 0.16, 0.7))
	return img


## Darstellung: Lichtsäule und Bodenscheibe in der Ringfarbe, darüber schwebt der Ring (Gold: ein goldener Würfel).
func _beute_3d(hd: HdAnsicht) -> void:
	var t := float(Time.get_ticks_msec()) / 1000.0
	for b: Dictionary in beute_boden:
		var ring := str(b["ring"])
		var farbe: Color = BEUTE_GOLD_FARBE if ring == "" else Einheit.ABZEICHEN.get(ring, BEUTE_GOLD_FARBE)
		if b["knoten"] == null:
			var kn := Node3D.new()
			hd.add_child(kn)
			var p: Vector2 = b["pos"]
			kn.position = Vector3(p.x / Werte.ZELLE, 0.0, (p.y - Werte.KARTE_OBEN) / Werte.ZELLE)
			for teil: Array in [[0.12, 3.0, 0.4, 1.5], [0.28, 3.0, 0.16, 1.5], [0.45, 0.03, 0.55, 0.3]]:
				var m := MeshInstance3D.new()
				var zyl := CylinderMesh.new()
				zyl.top_radius = float(teil[0])
				zyl.bottom_radius = float(teil[0])
				zyl.height = float(teil[1])
				m.mesh = zyl
				m.material_override = _leucht(farbe, float(teil[2]))
				m.position = Vector3(0, float(teil[3]), 0)
				kn.add_child(m)
			var oben: Node3D
			if ring == "":
				oben = _kasten3d(kn, Vector3(0.28, 0.28, 0.28), farbe, Vector3(0, 0.75, 0))
			else:
				var s := Sprite3D.new()
				s.texture = RingBilder.bild(ring, farbe)
				s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
				s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
				s.shaded = false
				s.pixel_size = 0.55 / 16.0
				kn.add_child(s)
				oben = s
			oben.name = "Oben"
			b["knoten"] = kn
		var schwebt := (b["knoten"] as Node3D).get_node("Oben") as Node3D
		schwebt.position.y = 0.75 + 0.09 * sin(t * 3.0)
		if ring == "":
			schwebt.rotation.y = t * 1.8


var _kopfgeld_merk := {}   # Ort ("s:<Stellung>" / "f:<Fabrik>") -> [Kills in Folge, Zeit des letzten Kills]

## 20.11. (Paul): Kopfgeld je Kill. An derselben Stellung (am Boden: Truppen derselben Fabrik) sinkt es je kill_stufe Kills
## um 1; nach kill_frist Sekunden ohne Kill dort ist es wieder voll.
func _kopfgeld(ort: String, mal: int = 1) -> void:
	var voll := int(w("praemie_kill"))
	if voll <= 0:
		return
	var m: Array = _kopfgeld_merk.get(ort, [0, -999.0])
	var n := int(m[0]) if zeit - float(m[1]) < wf("kill_frist") else 0
	if ort.begins_with("f:"):
		n = 0   # 20.11. (Paul): Truppen am Boden bringen immer das volle Kopfgeld – nur Stellungen nutzen sich ab
	var betrag := gold(maxi(0, voll - int(n / maxf(1.0, wf("kill_stufe")))) * mal)   # F4: gold_faktor
	_kopfgeld_merk[ort] = [n + 1, zeit]
	if betrag > 0:
		sabotage["geld"] = int(sabotage["geld"]) + betrag
		spiel.budget += betrag   # ohne Meldung: sie würde wichtigere Zeilen verdrängen – das Budget oben zählt mit


## F4 (26.11., Paul): Gold-Einkommen × gold_faktor. Der Rest hinter dem Komma wird mitgeführt – so stimmt auch die
## Summe vieler kleiner Kopfgelder (7 × 0,8 gibt abwechselnd 5 und 6). `gold_roh`: was es ohne Faktor gewesen wäre.
var gold_roh := 0
var _gold_rest := 0.0

func gold(betrag: int) -> int:
	if betrag <= 0:
		return betrag
	gold_roh += betrag
	var g := float(betrag) * wf("gold_faktor") + _gold_rest
	var ganz := floori(g + 0.0001)
	_gold_rest = g - float(ganz)
	return ganz


func _praemie(was: String, betrag: int, text: String, xp: int = 0) -> void:
	betrag = gold(betrag)   # F4 (26.11., Paul): gold_faktor
	sabotage[was] = int(sabotage[was]) + 1
	sabotage["geld"] = int(sabotage["geld"]) + betrag
	spiel.budget += betrag
	var k: Kommandant = spiel.kommandant
	if xp > 0 and k != null and k.fortschritt != null:
		k.fortschritt.gib(xp, k)   # 20.11. (Paul): eher Erfahrung als Geld
	var teile: PackedStringArray = []
	if betrag > 0:
		teile.append("+%d" % betrag)
	if xp > 0:
		teile.append("+%d Erfahrung" % xp)
	spiel.melde(text + (": " + " · ".join(teile) if not teile.is_empty() else ""), 2.0)


## Flächenschaden von Brakk (Druckwelle, Lichtsäule …) trifft auch die Stellvertreter.
func flaeche(mitte: Vector2, radius: float, schaden: float) -> void:
	for t: TechnoZiel in ego_ziele():
		if mitte.distance_to(t.position) <= radius:
			treffer(t, schaden)


# ------------------------------------------------------------------ Türme: Kern und Stütze (20.11.)

## Kern getroffen: leer geschossen fällt der Turm aus (lahm wie nach Myr-Drohnen), bis der Pilot kommt.
func kern_treffer(z: Vector2i, menge: float) -> void:
	if not kern.has(z) or karte.turm_lahm(z):
		return
	kern[z] = float(kern[z]) - menge
	if float(kern[z]) > 0.0:
		return
	kern[z] = 0.0
	karte.turm_schaden[z] = 1.0e9
	kern_aus[z] = 0.0
	pilot_auftraege.append({"z": z, "ab": zeit + wf("pilot_verzug")})   # 20.11. (Paul): der Pilot repariert ihn, er kommt nicht von selbst wieder
	karte.queue_redraw()
	spiel.melde("Turmkern zerschossen – der Turm schweigt, bis ein Pilot ihn repariert.", 2.5)
	print("ORDER24 Turmkern %s leer bei %.0f s" % [str(z), zeit])


## Ein ausgefallener Turm läuft wieder, sobald der Pilot (oder ein Heilturm mit Instandsetzung) ihn repariert hat –
## dann ist der Kern wieder voll.
func _tuerme_pflegen(_echt: float) -> void:
	for z: Vector2i in kern_aus.keys():
		if not karte.turm_schaden.has(z) or karte.ausbau.get(z, Karte.FREI) != Karte.TURM:
			kern_aus.erase(z)
			kern[z] = wf("kern_leben")
			karte.queue_redraw()


## Steht ein Heilturm mit Instandsetzung in Reichweite? (Nachbau und Kern laufen dann schneller)
func _instand_nah(z: Vector2i) -> bool:
	for t: Vector2i in karte.ausbau:
		if karte.ausbau[t] == Karte.TURM and karte.turm_art.get(t, "") == "heil" and karte.turm_aktiv(t) and float(karte.turm_wert(t, "instand_sek", 0.0)) > 0.0:
			if Vector2(t - z).length() <= float(karte.turm_wert(t, "reichweite")):
				return true
	return false


# ------------------------------------------------------------------ Sprengladungen (20.11.)

## Aufheben (Gepäck höchstens spreng_max), Zünder herunterzählen.
func _ladungen_pflegen(k: Kommandant, echt: float) -> void:
	for l: Dictionary in ladungen_boden.duplicate():
		if l.has("bis") and zeit >= float(l["bis"]):
			_ladung_weg(l)   # 26.11. (Paul): liegt nach ladung_liegt_sek nicht mehr
			continue
		if ladungen < int(w("spreng_max")) and k.position.distance_to(l["pos"] as Vector2) <= 0.7 * Werte.ZELLE:
			ladungen += 1
			ladungen_boden.erase(l)
			if l["knoten"] != null:
				(l["knoten"] as Node3D).queue_free()
			spiel.melde("Sprengladung aufgenommen (%d/%d) – [C] auf einen Erdwall." % [ladungen, int(w("spreng_max"))], 2.5)
			Ton.spiele(spiel, "ui-klick")
	for zu: Dictionary in zuender.duplicate():
		zu["rest"] = float(zu["rest"]) - echt
		if float(zu["rest"]) <= 0.0:
			zuender.erase(zu)
			if zu["knoten"] != null:
				(zu["knoten"] as Node3D).queue_free()
			sprengen(zu["zelle"] as Vector2i)


## [C]: Sprengladung auf den Erdwall vor Brakk setzen. Gibt einen Grund zurück, wenn es nicht geht ("" = gesetzt).
func ladung_setzen(z: Vector2i) -> String:
	if ladungen <= 0:
		return "Keine Sprengladung – gefallene Truppen lassen manchmal eine fallen."
	if z == Karte.KEINE or karte.inhalt(z) != Karte.WALL:
		return "Kein Erdwall vor dir – stell dich direkt davor."
	if _im_schild(karte.mitte(z)):
		return "Der Schild schützt diesen Erdwall."
	if herausforderer != null and herausforderer.kampfplatz.ist_rand(z):
		return tr("Die Lichtwand hält diesen Wall – im Kampfplatz wird nicht gesprengt.")   # F2 (26.11., Paul)
	for zu: Dictionary in zuender:
		if zu["zelle"] == z:
			return "Hier tickt schon eine Ladung."
	ladungen -= 1
	nemesis.ladung()   # 22.11.: Treffer gleich danach = „unterbrochen“
	zuender.append({"zelle": z, "rest": wf("spreng_zuender"), "knoten": null})
	spiel.melde("Sprengladung gesetzt – %d s!" % int(w("spreng_zuender")), 2.0)
	Ton.spiele(spiel, "ui-klick")
	return ""


## Welcher Erdwall bekommt die Ladung? Der unter dem Fadenkreuz (nah genug), sonst der Nachbarwall in Blickrichtung.
func wall_fuer_ladung(fuss: Vector2, ziel: Vector2, blick: Vector2) -> Vector2i:
	var zz := karte.zelle_bei(ziel)
	if karte.inhalt(zz) == Karte.WALL and karte.mitte(zz).distance_to(fuss) <= LADUNG_REICHWEITE * Werte.ZELLE:
		return zz
	var hier := karte.zelle_bei(fuss)
	var bestes := Karte.KEINE
	var wert := -INF
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var n := hier + Vector2i(dx, dy)
			if karte.inhalt(n) != Karte.WALL:
				continue
			var d := karte.mitte(n) - fuss
			var v := 1.0 if d.length() < 1.0 else d.normalized().dot(blick.normalized())
			if v > wert:
				wert = v
				bestes = n
	return bestes if wert > -0.2 else Karte.KEINE


## Der Wall ist weg (seine Stellung bzw. sein Turm mit ihm), Türme ohne Stütze schweigen, Truppen dicht daneben nehmen Schaden.
func sprengen(z: Vector2i) -> void:
	if karte.inhalt(z) != Karte.WALL:
		return
	gesprengt[z] = {"ausbau": int(karte.ausbau.get(z, Karte.FREI)), "stufe": int(karte.turm_stufe.get(z, 1)), "faehigkeit": str(karte.turm_faehigkeit.get(z, ""))}
	kern.erase(z)
	kern_aus.erase(z)
	karte.turm_schaden.erase(z)
	karte.fest.erase(z)
	karte.entferne(z)
	karte.zerstoert.emit(z, Karte.WALL)   # main: Stellung räumen, „Turm hat eine Stütze verloren“
	var p := karte.mitte(z)
	spiel.schadensquelle = "fabrik:-1,-1"
	for x in spiel.einheiten.duplicate():
		if is_instance_valid(x) and x != spiel.kommandant and (x as Einheit).position.distance_to(p) <= 1.3 * Werte.ZELLE and not (x as Einheit).kampfunfaehig:
			(x as Einheit).nimm_schaden(LADUNG_SCHADEN * nemesis.spreng_faktor(x as Einheit))   # 22.11.: Nemesis – sprengfest
			if not is_instance_valid(x) or (x as Einheit).leben <= 0.0:
				kills += 1
				gebiet_zaehlen("kills", 1.0)   # E: wo Brakk stand
				sabotage["truppen"] = int(sabotage["truppen"]) + 1
			else:
				nemesis.sprengung_ueberlebt(x as Einheit)   # 22.11.: Feldbeförderung „Taubes Ohr“
	spiel.schadensquelle = ""
	spiel.effekte.flaeche(p, Werte.ZELLE * 1.3, Color("ff9a3d"))
	if Werte.grafik_neu:
		spiel.effekte.fx("g_tod", p + Vector2(0, 16), 1.0)
	Ton.spiele(spiel, "hit-boom", 9.0)   # 20.11. (Paul): Sprengung mit Knall …
	Ton.spiele(spiel, "tf-stone", 4.0)   # … und Geröll
	_explosion3d(z)
	if spiel.ego != null:
		spiel.ego.set("_trauma", minf(1.0, float(spiel.ego.get("_trauma")) + 0.35))
	_praemie("waelle", int(w("praemie_wall")), "Erdwall gesprengt")
	print("ORDER24 Erdwall %s gesprengt bei %.0f s" % [str(z), zeit])


# ------------------------------------------------------------------ Fabriken: Sabotage, Alarm, Pilot (20.11.)

## Steht Brakk an der Rückseite einer Fabrik draußen (die läuft)? Dann deren Feld, sonst KEINE.
func fabrik_an_rueckseite(fuss: Vector2) -> Vector2i:
	for z: Vector2i in rueckseite:
		var r: Vector2i = rueckseite[z]
		if r != Karte.KEINE and fabrik_hp.has(z) and not lahm.has(z) and fuss.distance_to(karte.mitte(r)) <= 1.0 * Werte.ZELLE:
			return z
	return Karte.KEINE


## [F] gedrückt: Sabotage beginnen. false = keine Fabrik-Rückseite hier (dann gilt [F] wie sonst: Ringterminal).
func sabotage_start() -> bool:
	var k: Kommandant = spiel.kommandant
	var z := fabrik_an_rueckseite(k.position)
	if z == Karte.KEINE:
		return false
	sabo = {"zelle": z, "t": 0.0, "leben": k.leben}
	_alarm(z)
	return true


func sabotage_abbruch(grund: String) -> void:
	if sabo.is_empty():
		return
	sabo = {}
	if grund != "":
		spiel.melde("Sabotage abgebrochen – %s." % grund, 2.0)


func _fabriken_pflegen(k: Kommandant, echt: float) -> void:
	if not sabo.is_empty():
		var z: Vector2i = sabo["zelle"]
		# 20.11. (Paul): Treffer brechen die Sabotage nicht mehr ab – riskant, aber möglich. Solange Brakk dran ist,
		# stockt die Produktion dieser Fabrik (kein Ersatz rückt nach).
		if spiel.fabriken.has(z):
			spiel.fabriken[z]["timer"] = 0.0
		if fabrik_an_rueckseite(k.position) != z:
			sabotage_abbruch("zu weit weg")
		else:
			sabo["t"] = float(sabo["t"]) + echt
			if float(sabo["t"]) >= wf("sabotage_halten"):
				sabo = {}
				sabotieren(z)
	for z: Vector2i in lahm.keys():
		if not karte.ausgefallen.has(z):
			lahm.erase(z)   # der Pilot hat repariert
			continue
		lahm[z] = float(lahm[z]) - echt
		if float(lahm[z]) <= 0.0 and wf("sabotage_lahm") > 0.0:   # 0 = nur der Pilot repariert
			lahm.erase(z)
			spiel.repariere(z, true)
	for id: int in alarm.keys():
		if float((alarm[id] as Dictionary)["bis"]) < zeit or not is_instance_valid(instance_from_id(id)):
			alarm.erase(id)
	_piloten()


## Fabrik sabotiert: sabotage_lahm Sekunden kein Ersatz; pilot_verzug Sekunden später macht sich ein Pilot auf den Weg.
func sabotieren(z: Vector2i) -> void:
	brakk_gewohnheit("sabotage")   # 22.11. (Nemesis Teil 4)
	karte.ausgefallen[z] = true
	karte.fortschritt.erase(z)
	lahm[z] = wf("sabotage_lahm")
	pilot_auftraege.append({"z": z, "ab": zeit + wf("pilot_verzug")})
	_praemie("sabotiert", int(w("praemie_sabotage")), ("Fabrik sabotiert (%d s lahm)" % int(w("sabotage_lahm")) if wf("sabotage_lahm") > 0.0 else "Fabrik sabotiert – lahm, bis ein Pilot sie repariert"), int(w("xp_sabotage")))
	if spiel.get("_einblendung") != null:
		spiel._einblendung.banner("FABRIK LAHMGELEGT", "%s: kein Nachschub" % lager_name(z), Color("ffb03a"))   # 25.11. (Paul)
	Ton.spiele(spiel, "tc-arc", -4.0)
	karte.queue_redraw()
	print("ORDER24 Fabrik %s sabotiert bei %.0f s" % [str(z), zeit])


## 25.11. (Paul): Name eines Lagers (Fabrik außerhalb): „Lager A“, „Lager B“ … in der Reihenfolge der Vergabe.
func lager_name(z: Vector2i) -> String:
	if not _lager_namen.has(z):
		_lager_namen[z] = "Lager %s" % char(65 + _lager_namen.size() % 26)
	return _lager_namen[z]


## Die Namen zum Start von West (nahe am Myriaden-HQ) nach Ost vergeben; neue Lager bekommen den nächsten Buchstaben.
func _lager_benennen() -> void:
	var liste: Array = fabrik_hp.keys()
	liste.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.x < b.x or (a.x == b.x and a.y < b.y))
	for z: Vector2i in liste:
		lager_name(z)


## Zu welchem Lager gehört die Stellung `s`? Die nächste Fabrik draußen im Umkreis von LAGER_RADIUS Feldern, sonst KEINE.
func lager_von(s: Vector2i) -> Vector2i:
	var beste := Karte.KEINE
	var d := INF
	for z: Vector2i in fabrik_hp:
		if maxi(absi(s.x - z.x), absi(s.y - z.y)) <= LAGER_RADIUS and Vector2(s - z).length() < d:
			d = Vector2(s - z).length()
			beste = z
	return beste


## karte.finde_posten: In die Stellungen eines sabotierten Lagers rückt niemand nach, bis der Pilot repariert hat.
## Wer schon oben steht, bleibt.
func stellung_gesperrt(s: Vector2i) -> bool:
	if lahm.is_empty():
		return false
	var z := lager_von(s)
	return z != Karte.KEINE and lahm.has(z)


## Angriff auf eine Fabrik: Truppen am Boden im Umkreis laufen hin (Stellungen bleiben besetzt).
func _alarm(z: Vector2i) -> void:
	if float(_alarm_zuletzt.get(z, -99.0)) > zeit - 5.0:
		return
	_alarm_zuletzt[z] = zeit
	var p := karte.mitte(z)
	var ziel: Vector2i = rueckseite.get(z, Karte.KEINE)
	if ziel == Karte.KEINE:
		ziel = _freies_feld_nahe(z, 1)
	var n := 0
	for e in _truppen():
		var u := e as Einheit
		if u.zustand != Einheit.Zustand.BODEN or u == pilot or eskorte.has(u):
			continue
		if u.position.distance_to(p) <= wf("alarm_radius") * Werte.ZELLE:
			alarm[u.get_instance_id()] = {"ziel": _freies_feld_nahe(ziel, 1), "bis": zeit + ALARM_SEK}
			n += 1
	if n > 0:
		print("ORDER24 Alarm an %s: %d Truppen" % [str(z), n])


## 20.11. (Paul): Druck – Truppen am Boden im Umkreis (alarm_radius × 1,5) laufen zu Brakks Ort (höchstens alle 5 s).
## Jäger, Pilot, Begleiter und die Verteidiger im Schild bleiben bei ihrer Aufgabe.
func _alarm_auf_brakk(k: Kommandant) -> void:
	if k == null or zeit < _druck_naechster or herausforderer.sperrt():
		return
	_druck_naechster = zeit + 5.0
	var ziel := karte.zelle_bei(k.position)
	for x in _truppen():
		var u := x as Einheit
		if u.zustand != Einheit.Zustand.BODEN or u == pilot or eskorte.has(u) or jaeger.has(u.get_instance_id()) or _ist_innen(u):
			continue
		if u.position.distance_to(k.position) <= wf("alarm_radius") * 1.5 * Werte.ZELLE:
			alarm[u.get_instance_id()] = {"ziel": _freies_feld_nahe(ziel, 1), "bis": zeit + 10.0}


## Pilot mit zwei Begleitern aus der Batterie (im Schild) zur nächsten sabotierten Fabrik. Fällt er, kommt der nächste erst
## nach pilot_neu Sekunden. Zerstörte Fabriken repariert er nicht.
func _piloten() -> void:
	pilot_auftraege = pilot_auftraege.filter(func(a: Dictionary) -> bool: return lahm.has(a["z"] as Vector2i) or karte.turm_lahm(a["z"] as Vector2i))
	if _hatte_pilot and not is_instance_valid(pilot):
		pilot = null
		_hatte_pilot = false
		_pilot_ab = zeit + wf("pilot_neu")
		eskorte.clear()
		print("ORDER24 Pilot gefallen bei %.0f s – der nächste in %d s" % [zeit, int(w("pilot_neu"))])
	if pilot != null or pilot_auftraege.is_empty():
		return
	var a: Dictionary = pilot_auftraege[0]
	if zeit < maxf(float(a["ab"]), _pilot_ab):
		return
	var von := karte.basis
	for z: Vector2i in spiel.fabriken:
		if str(spiel.fabriken[z]["typ"]) == "pilot":
			von = z
	pilot = _neue_truppe("pilot", von, 0)
	_hatte_pilot = true
	eskorte.clear()
	for i in 2:
		eskorte.append(_neue_truppe(Werte.ALARM_TRUPPEN[0], von, 1))
	spiel.melde("Ein Pilot des Technoclans ist auf dem Weg zur sabotierten Fabrik.", 3.0)
	print("ORDER24 Pilot los bei %.0f s zu %s" % [zeit, str(a["z"])])


## Truppe ohne Fabrik-Kontingent (Pilot, Begleiter, Jagdtrupp, Verräter in der Sequenz).
func _neue_truppe(typ: String, von: Vector2i, stufe: int, faehigkeit: String = "") -> Einheit:
	var e := Einheit.new()
	spiel.figuren.add_child(e)
	e.start(spiel, karte, typ, von, stufe, faehigkeit)
	if stufe >= 4:   # 21.11. (Paul): Elitetrupp – 200 % Leben statt des Elite-Aufschlags der Fabrik-Stufe 4
		e.max_leben *= Werte.ROGUE_ELITE_LEBEN / float(Werte.ELITE["leben"])
		e.leben = e.max_leben
	neue_einheit(e)
	spiel.einheiten.append(e)
	return e


## main.reparaturziel: In Befehl 24 repariert nur der eigene Pilot, und nur sabotierte Fabriken.
func reparaturziel(p: Einheit) -> Dictionary:
	if p != pilot or pilot_auftraege.is_empty():
		return {}
	if zeit < float((pilot_auftraege[0] as Dictionary)["ab"]):
		return {}   # 20.11.: auch ein Pilot, der schon draußen ist, wartet pilot_verzug ab
	var z: Vector2i = (pilot_auftraege[0] as Dictionary)["z"]
	var neben: Vector2i = rueckseite.get(z, Karte.KEINE)
	if neben == Karte.KEINE:
		# 20.11.: Turm – das nächste freie Feld daneben, das der Pilot zu Fuß erreicht
		var hier := karte.zelle_bei(p.position)
		var beste := 1 << 20
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]:
			var n := z + d
			if not karte.ist_begehbar(n) or not karte.ist_frei(n):
				continue
			var weg := karte.einheiten_weg(hier, n)
			if (not weg.is_empty() or hier == n) and weg.size() < beste:
				beste = weg.size()
				neben = n
	if neben == Karte.KEINE:
		return {}
	return {"z": z, "neben": neben}


# ------------------------------------------------------------------ Truppen

## Darf diese Truppe in eine Stellung? Jäger, Pilot und Begleiter nie.
func darf_in_stellung(e: Einheit) -> bool:
	if nemesis != null and nemesis.gewohnheiten != null and nemesis.gewohnheiten.darf_auf_wall(e):
		return true   # 22.11. (Nemesis Teil 4): der Mauerkletterer steigt auf einen Erdwall – auch als Jäger, auch nah an Brakk
	var k: Kommandant = spiel.kommandant
	if laeuft and k != null and not k.gefallen and e.position.distance_to(k.position) <= BRAKK_NAH * Werte.ZELLE:
		return false   # 20.11. (Paul): ist Brakk nah, bleibt die Truppe unten und kämpft (wie sonst auch) statt in die Stellung zu laufen
	return not jaeger.has(e.get_instance_id()) and e != pilot and not eskorte.has(e) and not _ist_innen(e)


## Marschziel einer Truppe (KEINE = stehen bleiben): Begleiter folgen dem Piloten, Alarm geht vor, dann der Jagdtrupp,
## sonst ab der Sabotage-Phase die Streife um die eigene Fabrik (in der Flucht gehen alle nur in Stellung).
func marschziel(e: Einheit) -> Vector2i:
	if eskorte.has(e):
		return karte.zelle_bei(pilot.position) if is_instance_valid(pilot) else Karte.KEINE
	var id := e.get_instance_id()
	var nz := nemesis.marschziel(e)   # 22.11.: Nemesis – Schwächen und Rückzug gehen vor
	if nz != Karte.KEINE:
		return nz
	if herausforderer.sperrt() and (jaeger.has(id) or alarm.has(id)):
		return _erreichbar_nahe(e.fabrik_zelle, karte.zelle_bei(e.position))   # 26.11.: die Jagdtrupps ziehen sich zurück
	var tnr := int(jaeger.get(id, -1))
	if tnr >= 0 and tnr < trupps.size() and (trupps[tnr] as Dictionary).has("taktik") and taktik.an():
		return _trupp_ziel(e, trupps[tnr] as Dictionary)   # 26.11.: Taktik geht vor dem Alarm (der Hinterhalt bleibt liegen)
	if alarm.has(id):
		return (alarm[id] as Dictionary)["ziel"]
	var nr := int(jaeger.get(id, -1))
	if nr >= 0 and nr < trupps.size():
		return _trupp_ziel(e, trupps[nr] as Dictionary)
	if _ist_innen(e):
		return schildwache.ziel(e) if schildwache != null else Karte.KEINE   # 26.11. (Paul): Streife zu zweit im Schild, Ausfall bei Sicht
	if phase() == "flucht":
		return Karte.KEINE
	return _streifenziel(e)


## 20.11.: Streife – reihum die Felder des Streifenwegs der eigenen Fabrik (ohne eigene: der nächsten Fabrik draußen).
func _streifenziel(e: Einheit) -> Vector2i:
	var weg: Array = routen.get(e.fabrik_zelle, [])
	if weg.is_empty():
		var beste := INF
		for f: Vector2i in routen:
			var d := e.position.distance_to(karte.mitte(f))
			if d < beste and not (routen[f] as Array).is_empty():
				beste = d
				weg = routen[f]
	if weg.is_empty():
		return Karte.KEINE
	var id := e.get_instance_id()
	var i := int(_streife.get(id, randi() % weg.size()))
	if karte.zelle_bei(e.position).distance_to(weg[i % weg.size()] as Vector2i) <= 1.0:
		i += 1
	_streife[id] = i % weg.size()
	return weg[i % weg.size()]


# ------------------------------------------------------------------ Ablauf-Phasen (20.11.)

## Phase zur Zeit `t` (Sekunden) mit `zerstoert` zerstörten Fabriken: flucht → sabotage → jagd → vorstoss.
## Die Sabotage endet nach jagd_start oder sobald sabotage_ende_fabriken Fabriken zerstört sind.
func phase_bei(t: float, zerstoert: int) -> String:
	if t < wf("flucht_sek"):
		return "flucht"
	if bool(w("vorstoss")) and t >= wf("vorstoss_start"):
		return "vorstoss"
	if t >= wf("jagd_start") or zerstoert >= int(w("sabotage_ende_fabriken")):
		return "jagd"
	return "sabotage"


## 26.11. (Paul): die Uhr des Technoclan. Sie steht, solange ein Herausforderer allein kämpft – die Überlebens-Uhr (zeit)
## läuft weiter. Alles, was mit der Zeit kommt oder stärker wird, richtet sich nach dieser.
func plan_zeit() -> float:
	return zeit - plan_pause


## Der Fahrplan ruht: seine Uhr und alle schon gesetzten Termine rücken mit.
func _fahrplan_ruht(dt: float) -> void:
	plan_pause += dt
	_naechste_welle += dt
	_vorstoss_wahl += dt
	_lager_naechst += dt
	_tore_naechst += dt
	_pilot_ab += dt   # F1 (26.11., Paul): auch der Pilot wartet
	for a: Dictionary in pilot_auftraege:
		a["ab"] = float(a["ab"]) + dt


## einheit.gd: Hält eine Truppe am Boden das Feuer auf Brakk zurück? (Herausforderung – nur er, Türme und Stellungen)
func haelt_feuer(ziel: Node2D) -> bool:
	return herausforderer != null and herausforderer.sperrt() and ziel == brakk_ziel and not (herausforderer.typ != null and herausforderer.typ.feuer_frei())   # C3: beim Verstärkungsruf schießen alle


func phase() -> String:
	if not laeuft:
		return "flucht"
	var p := phase_bei(plan_zeit(), int(sabotage["fabriken"]))
	if jagd and (p == "flucht" or p == "sabotage"):
		return "jagd"
	return p


## 22.11. (Paul): unter der Uhr nur noch die Phase – wann es weitergeht, zeigt der Balken (balken_anteil).
## 25.11. (Paul): kommt ein Elitetrupp, steht kurz „Elitetrupp“ dabei.
func phase_text() -> String:
	if herausforderer != null and herausforderer.laeuft():
		return tr("Herausforderung")
	var hq := " · " + tr("HQ %d %%") % floori(100.0 * vorstoss_anteil) if einnahme_sichtbar() else ""   # 26.11. (Paul): Einnahme-Ring
	if zeit < _elite_zeile_bis:
		return _phase_name() + hq + " · " + tr("Elitetrupp")
	if taktik != null and zeit < taktik.zeile_bis:
		return _phase_name() + hq + " · " + taktik.zeile   # 26.11.: Taktik der Jagdwelle
	return _phase_name() + hq


## 26.11. (Paul): Einnahme des Myriaden-HQ läuft (Ring über dem HQ und „HQ 45 %“ in der Phasenzeile) – bis voll oder 0.
func einnahme_sichtbar() -> bool:
	return vorstoss_anteil > 0.0 and vorstoss_anteil < 1.0 and not hq_eingenommen and not myr_hq_besetzt


func _phase_name() -> String:
	match phase():
		"flucht":
			return "Flucht · zum Myriaden-HQ im Westen"
		"sabotage":
			return "Sabotage"
	if geheim:
		return "Überläufer"
	# 20.11. (Paul): der Vorstoß aufs Myriaden-HQ bleibt geheim – angezeigt wird nur die Jagd
	return "Jagd · Myriaden-HQ gefallen" if hq_eingenommen else "Jagd"


## 22.11. (Paul): Balken unter der Uhr – läuft bis zum nächsten Ereignis: in Flucht und Sabotage bis zum Jagdbeginn,
## in der Jagd bis zur nächsten Welle aus dem Schild, im Überläufer-Verlauf bis zur nächsten Myriaden-Welle.
func balken_anteil() -> float:
	if geheim:
		return clampf(_myr_uhr / maxf(1.0, wf("myr_takt")), 0.0, 1.0)
	if not jagd:
		return clampf(plan_zeit() / maxf(1.0, wf("jagd_start")), 0.0, 1.0)
	var takt := maxf(1.0, welle_takt_jetzt())
	return clampf(1.0 - (_naechste_welle - zeit) / takt, 0.0, 1.0)


static func _uhr(sek: float) -> String:
	var s := maxi(0, ceili(sek))
	return "%d:%02d" % [s / 60, s % 60]


## Jede Sekunde: Phasenwechsel, Trupps lenken, Wellen aus dem Schild, Vorstoß wählen.
func _ablauf(k: Kommandant) -> void:
	if not _flucht_gemeldet:
		_flucht_gemeldet = true
		spiel.melde("Flucht: Lauf zum Myriaden-HQ im Westen – dort warten Ringterminal, Med-Kit und eine Sprengladung.", 8.0)
	var p := phase()
	if p != _phase_vorher:
		_phase_vorher = p
		if p == "sabotage":
			spiel._einblendung.banner("BEFEHL 24", "Die Verteidigung steht – sabotiere Fabriken", Color("ffb84d"))
			spiel.melde("Sabotage: [F] an der Rückseite einer Fabrik halten (roter Streifen am Boden), Erdwälle mit [C] sprengen, Turmkerne zerschießen.", 7.0)
		elif p == "jagd" and not jagd:
			_jagd_eroeffnen(k)
		elif p == "vorstoss" and not jagd:
			_jagd_eroeffnen(k)   # der Vorstoß selbst wird nicht angesagt
	if herausforderer.sperrt():
		return   # 26.11. (Paul): Herausforderung – keine Wellen, keine Trupps zu Brakk, kein Vorstoß
	_hq_aggro(k)
	if schildwache != null:
		schildwache.weiter(k)   # 26.11. (Paul): Schildbesatzung – Paare, Ausfall
	if not jagd and not in_deckung:
		_alarm_auf_brakk(k)   # 20.11. (Paul): schon vor der Jagd Druck – wer ihn sieht, ruft die Truppen in der Nähe
	if not jagd:
		return
	_bekannt_pflegen(k)
	_trupps_lenken(k)
	if zeit >= _naechste_welle:
		_naechste_welle += welle_takt_jetzt()
		_jagdwelle()
	_eskalation()
	if phase() == "vorstoss" and not hq_eingenommen and zeit >= _vorstoss_wahl:
		_vorstoss_waehlen()


## 20.11. (Paul): 0..1 – wie nah Brakk am Schild des Technoclan-HQ ist (1 = direkt am Schild, 0 = weiter als hq_aggro_radius).
func hq_naehe() -> float:
	var k: Kommandant = spiel.kommandant
	if k == null or schild_mitten.is_empty():
		return 0.0
	var d := k.position.distance_to(schild_mitten[0]) / Werte.ZELLE - SCHILD_RADIUS
	return clampf(1.0 - d / maxf(1.0, wf("hq_aggro_radius")), 0.0, 1.0)


## 20.11. (Paul): Kommt Brakk dem Technoclan-HQ nahe, weiß die ganze Basis, wo er ist: alle Trupps in der Nähe jagen ihn,
## ab halber Nähe rücken auch die Verteidiger aus dem Schild aus.
func _hq_aggro(k: Kommandant) -> void:
	var n := hq_naehe()
	if n <= 0.0:
		return
	bekannt = karte.zelle_bei(k.position)
	bekannt_zeit = zeit
	for t: Dictionary in trupps:
		if str(t["modus"]) != "vorstoss":
			t["modus"] = "jagd"
			t["zuletzt"] = bekannt
			t["gesehen"] = zeit
	if n >= 0.5:
		for x in _truppen():
			var u := x as Einheit
			if _ist_innen(u) and u.zustand == Einheit.Zustand.BODEN:
				alarm[u.get_instance_id()] = {"ziel": _freies_feld_nahe(bekannt, 1), "bis": zeit + 6.0}


## Brakk gesehen: von einer Stellung (nicht in Deckung) oder von einem Jäger in Sichtweite – dann ist sein Ort bekannt.
func _bekannt_pflegen(k: Kommandant) -> void:
	if not in_deckung or zeit < markiert_bis:   # 22.11.: Markierung – Ort bekannt, auch hinter Wällen
		bekannt = karte.zelle_bei(k.position)
		bekannt_zeit = zeit


## Stufe 2: Zwei Drittel der Truppen bilden Jagdtrupps zu trupp_min–trupp_max, der Rest bleibt in den Nestern.
func _jagd_eroeffnen(k: Kommandant) -> void:
	jagd = true
	_naechste_welle = zeit + wf("welle_takt")
	spiel._einblendung.banner("BEFEHL 24 · STUFE 2", "„Findet ihn.“", Color("ff5a6e"))
	spiel.melde("Sonde 7: „Befehl 24, Stufe 2. Findet ihn.“", 6.0)
	Ton.spiele(spiel, "alert")
	if bekannt == Karte.KEINE:
		bekannt = karte.zelle_bei(k.position)   # Sonde 7 weiß, wo er zuletzt war
		bekannt_zeit = zeit
	var alle := _truppen().filter(func(x: Variant) -> bool: return x != pilot and not eskorte.has(x) and not jaeger.has((x as Node).get_instance_id()) and not _ist_innen(x as Einheit))
	var bp := karte.mitte(bekannt)
	alle.sort_custom(func(a: Node2D, b: Node2D) -> bool: return a.position.distance_squared_to(bp) < b.position.distance_squared_to(bp))
	var soll := roundi(float(alle.size()) * wf("jagd_anteil") / 100.0)
	var gewaehlt: Array = alle.slice(0, soll)
	# zu Trupps zusammenfassen: nach Lage sortiert (wer nah beieinander steht, jagt zusammen)
	var mitte := karte.mitte(karte.basis)
	gewaehlt.sort_custom(func(a: Node2D, b: Node2D) -> bool: return (a.position - mitte).angle() < (b.position - mitte).angle())
	var groesse := clampi(roundi((wf("trupp_min") + wf("trupp_max")) / 2.0), 1, 12)
	var i := 0
	while i < gewaehlt.size():
		var n := groesse
		if gewaehlt.size() - (i + n) < int(w("trupp_min")) and gewaehlt.size() - i <= int(w("trupp_max")):
			n = gewaehlt.size() - i   # Rest passt noch in diesen Trupp
		_neuer_trupp(gewaehlt.slice(i, i + n), "jagd")
		i += n
	print("ORDER24 Jagd bei %.0f s: %d Jäger in %d Trupps, %d bleiben in den Nestern" % [zeit, gewaehlt.size(), trupps.size(), alle.size() - gewaehlt.size()])
	_wege_loggen()


## 23.11.: In Trupps zu trupp_min..trupp_max teilen (der Rest geht im letzten Trupp mit, wenn er sonst zu klein wäre).
func _aufteilen(liste: Array) -> Array:
	var aus: Array = []
	var groesse := clampi(roundi((wf("trupp_min") + wf("trupp_max")) / 2.0), 1, 12)
	var i := 0
	while i < liste.size():
		var n := groesse
		if liste.size() - (i + n) < int(w("trupp_min")) and liste.size() - i <= int(w("trupp_max")):
			n = liste.size() - i
		aus.append(liste.slice(i, i + n))
		i += n
	return aus


func _neuer_trupp(mitglieder: Array, modus: String) -> Dictionary:
	var t := {"mitglieder": mitglieder, "modus": modus, "zuletzt": bekannt, "gesehen": zeit, "suche_bis": 0.0}
	trupps.append(t)
	for e: Variant in mitglieder:
		jaeger[(e as Node).get_instance_id()] = trupps.size() - 1
		_losschicken(e as Einheit)
	return t


## Neuer Jagdtrupp aus den Fabriken im Schild: welle_groesse (minus zerstörte Fabriken draußen, dauerhaft), jede elite_jede-te
## Welle ein Elitetrupp aus genau drei.
func _jagdwelle() -> void:
	var quellen: Array[Vector2i] = []
	for z: Vector2i in spiel.fabriken:
		if not fabrik_hp.has(z) and str(spiel.fabriken[z]["typ"]) != "pilot":
			quellen.append(z)
	if quellen.is_empty():
		return
	wellen += 1
	var elite := int(w("elite_jede")) > 0 and wellen % int(w("elite_jede")) == 0
	var wachsen := floori(maxf(0.0, plan_zeit() - wf("jagd_start")) / maxf(10.0, wf("welle_wachsen_sek")))   # 20.11. (Paul): Eskalation
	var n := 3 if elite else maxi(1, int(w("welle_groesse")) + wachsen - floori(float(sabotage["fabriken"]) * wf("welle_minus_je_fabrik")))
	var stufe := 4 if elite else (3 if plan_zeit() >= wf("faehigkeit_ab") else (2 if plan_zeit() >= wf("stufe2_ab") else 1))
	var neu: Array = []
	if elite:
		neu = nemesis.elitetrupp(quellen)   # 22.11. (Paul): der Elitetrupp sind Personen (Benannte zuerst, bis zu fünf)
		n = 0
		_elite_ton()
		_elite_zeile_bis = zeit + Werte.NEMESIS_ELITE_ZEILE_SEK
	for i in n:
		var z: Vector2i = quellen[i % quellen.size()]
		var typ := str(spiel.fabriken[z]["typ"])
		var faehig := ""
		if stufe == 3:
			var liste: Array = faehigkeiten_stufe3(typ)
			if not liste.is_empty():
				faehig = str(liste.pick_random())
		neu.append(_neue_truppe(typ, z, stufe, faehig))
	n = neu.size()
	var anzahl := 1
	if elite:
		_neuer_trupp(neu, "jagd")
	elif taktik != null and taktik.an() and spiel.kommandant != null:
		anzahl = taktik.welle(neu, wellen)   # 26.11. (Paul): Funkortung und Angriffstaktik
	else:
		anzahl = 0
		for teil: Array in _aufteilen(neu):   # 23.11. (Paul): mehrere kleine Trupps statt eines großen Pulks
			_neuer_trupp(teil, "jagd")
			anzahl += 1
	spiel.melde(("Ein Elitetrupp verlässt den Schild (%d)." % n) if elite else ("Jagdtrupps verlassen den Schild (%d in %d Trupps)." % [n, anzahl] if anzahl > 1 else "Ein Jagdtrupp verlässt den Schild (%d)." % n), 3.0)
	if spiel.has_method("befehl24_protokoll"):
		spiel.befehl24_protokoll("welle", {"welle": wellen, "n": n, "elite": elite, "trupps": anzahl, "stufe": stufe, "taktik": taktik.letzte if not elite and taktik != null and taktik.an() else ""})   # 23.11.; 26.11.: Taktik
	print("ORDER24 Welle %d bei %.0f s: %d%s · Stufe %d · Takt %.0f s" % [wellen, zeit, n, " Elite" if elite else "", stufe, welle_takt_jetzt()])


## 25.11. (Paul): Der Elitetrupp meldet sich beim Erscheinen mit genau einem eigenen Ton. Er soll nicht in der
## Stimmengrenze (Ton.STIMMEN) des Gefechts untergehen – dafür macht er sich einen Platz frei.
func _elite_ton() -> void:
	while Ton._stimmen.size() >= Ton.STIMMEN:
		Ton._stimmen.pop_front()
	Ton.spiele(spiel, ELITE_TON, ELITE_TON_DB)


## Ein Trupp: sieht er Brakk, jagt er; verliert er ihn sicht_verlust Sekunden, sucht er such_sek um den letzten Punkt,
## dann geht er wieder Streife. Auf Streife hört er auf Meldungen der Stellungen in der Nähe.
func _trupps_lenken(k: Kommandant) -> void:
	var bz := karte.zelle_bei(k.position)
	for t: Dictionary in trupps:
		t["mitglieder"] = (t["mitglieder"] as Array).filter(func(x: Variant) -> bool: return is_instance_valid(x))
		if (t["mitglieder"] as Array).is_empty() and t.has("taktik"):
			taktik.ende(t)   # 26.11.: Bilanz des Trupps ins Protokoll
		if (t["mitglieder"] as Array).is_empty() or str(t["modus"]) == "vorstoss":
			continue
		var sieht := false
		var erster: Einheit = null   # 22.11.: Nemesis – wer ihn für den Trupp aufdeckt
		var schwerpunkt := Vector2.ZERO
		for e: Variant in t["mitglieder"]:
			var p: Vector2 = (e as Node2D).position
			schwerpunkt += p
			if p.distance_to(k.position) <= SICHT_JAEGER * Werte.ZELLE and karte.sicht_frei(p, k.position):
				sieht = true
				if erster == null:
					erster = e as Einheit
		schwerpunkt /= float((t["mitglieder"] as Array).size())
		t["mitte"] = schwerpunkt
		if zeit < markiert_bis and str(t["modus"]) != "jagd":
			sieht = true   # 22.11. (Nemesis Teil 3): markiert – alle Trupps kennen Brakks Ort
		if sieht:
			if str(t["modus"]) != "jagd":
				nemesis.sichtung(erster, trupps.find(t))
			bekannt = bz
			bekannt_zeit = zeit
			t["zuletzt"] = bz
			t["gesehen"] = zeit
			t["modus"] = "jagd"
		elif str(t["modus"]) != "jagd" and zeit - bekannt_zeit < 1.5 and schwerpunkt.distance_to(karte.mitte(bekannt)) <= 10.0 * Werte.ZELLE:
			if not in_deckung and is_instance_valid(sichter):
				nemesis.sichtung(sichter, trupps.find(t))
			t["zuletzt"] = bekannt   # eine Stellung hat ihn gemeldet
			t["gesehen"] = zeit
			t["modus"] = "jagd"
		if t.has("taktik") and taktik.an():
			taktik.lenken(t, sieht, k)   # 26.11.: Funkortung, Auslöser, Übergänge
			t["ziel_ok"] = _erreichbar_nahe(t["zuletzt"] as Vector2i, karte.zelle_bei(((t["mitglieder"] as Array)[0] as Node2D).position))
			continue
		# 20.11.: Ziel, das die Truppen zu Fuß erreichen (Brakk oben auf einem Wall oder in einer Tasche: das nächste Feld daneben)
		t["ziel_ok"] = _erreichbar_nahe(t["zuletzt"] as Vector2i, karte.zelle_bei(((t["mitglieder"] as Array)[0] as Node2D).position))
		match str(t["modus"]):
			"jagd":
				if zeit - float(t["gesehen"]) > wf("sicht_verlust"):
					t["modus"] = "suche"
					t["suche_bis"] = zeit + wf("such_sek")
			"suche":
				if zeit > float(t["suche_bis"]):
					t["modus"] = "streife"
		if str(t["modus"]) != "jagd":
			t.erase("anflug")
			t.erase("zu")
		elif sieht and erster != null and erster.position.distance_to(k.position) <= ZANGE_NAH * Werte.ZELLE:
			t["zu"] = true   # 23.11.: so nah dran – nicht mehr auf die anderen warten
	_zange_pflegen(k)


## Ziel eines Jägers je nach Modus des Trupps: auffächern auf den letzten bekannten Ort (einer direkt, zwei über die Flanken),
## suchen um diesen Ort, Streife oder Vorstoß zum Myriaden-HQ.
func _trupp_ziel(e: Einheit, t: Dictionary) -> Vector2i:
	match str(t["modus"]):
		"vorstoss":
			return Werte.ANGRIFFS_ZELLE
		"streife":
			return _streifenziel(e)
		"suche":
			var nz := nemesis.lernen.suchziel(e, t) if nemesis != null and nemesis.lernen != null else Karte.KEINE
			if nz != Karte.KEINE:
				return nz   # 22.11. (Nemesis Teil 5): Eliten suchen an Brakks häufigsten Orten
			var id := e.get_instance_id()
			var s: Dictionary = _suchziel.get(id, {})
			if s.is_empty() or zeit >= float(s["bis"]) or karte.zelle_bei(e.position) == (s["z"] as Vector2i):
				s = {"z": _freies_feld_nahe(t["zuletzt"] as Vector2i, 4), "bis": zeit + 5.0}
				_suchziel[id] = s
			return s["z"]
	if t.has("taktik") and taktik.an():
		var tz := taktik.ziel(e, t)   # 26.11.: Feuerschutz, Hinterhalt
		if tz != Karte.KEINE:
			return tz
	return _jagd_ziel(e, t)


# ------------------------------------------------------------------ Zange (23.11.)

## Jäger im Modus „jagd“: erst über den eigenen Anmarschweg zum Anmarschpunkt, dort warten, bis die Zange zuschlägt;
## dann aufgefächert auf Brakks letzten Ort – und wer dort nichts sieht, sucht sich ein Schussfeld.
func _jagd_ziel(e: Einheit, t: Dictionary) -> Vector2i:
	var ziel: Vector2i = t.get("ziel_ok", t["zuletzt"])
	var id := e.get_instance_id()
	var hier := karte.zelle_bei(e.position)
	var a: Dictionary = t.get("anflug", {})
	if not a.is_empty() and not bool(t.get("zu", false)):
		_ohne_sicht.erase(id)
		_schussfeld.erase(id)
		if not bool(a.get("zw_ok", false)):
			var zw: Vector2i = a["zwischen"]
			if zw == Karte.KEINE or (t.get("mitte", e.position) as Vector2).distance_to(karte.mitte(zw)) <= 1.5 * Werte.ZELLE:
				a["zw_ok"] = true
			else:
				return zw
		return _faecher_feld(e, t, a["punkt"], (karte.mitte(a["punkt"]) - karte.mitte(ziel)).normalized(), 0.8)
	# Zuschlagen: Schussfeld (D) geht vor, sonst der eigene Platz im Halbkreis (C)
	var sf: Dictionary = _schussfeld.get(id, {})
	if not sf.is_empty():
		if zeit < float(sf["bis"]) and hier != (sf["z"] as Vector2i):
			return sf["z"]
		_schussfeld.erase(id)
	var richtung := ((t.get("mitte", e.position) as Vector2) - karte.mitte(ziel))
	var platz := _faecher_feld(e, t, ziel, richtung.normalized() if richtung.length() > 1.0 else Vector2.RIGHT, FAECHER_RADIUS)
	var punkt := karte.mitte(t["zuletzt"] as Vector2i)
	if e.position.distance_to(karte.mitte(platz)) <= 1.2 * Werte.ZELLE and not karte.sicht_frei(e.position, punkt):
		var seit := float(_ohne_sicht.get(id, zeit))
		_ohne_sicht[id] = seit
		if zeit - seit >= SCHUSSFELD_SEK:
			_ohne_sicht.erase(id)
			var sz := _schussfeld_suchen(hier, punkt, float(e.daten["reichweite"]))
			if sz != Karte.KEINE:
				_schussfeld[id] = {"z": sz, "bis": zeit + 6.0}
				return sz
	else:
		_ohne_sicht.erase(id)
	return platz


## Platz des Mitglieds im Halbkreis um `mitte` (zur Seite `richtung`), `radius` Felder weit; erreichbar, sonst `mitte`.
func _faecher_feld(e: Einheit, t: Dictionary, mitte: Vector2i, richtung: Vector2, radius: float) -> Vector2i:
	var glieder: Array = t["mitglieder"]
	var n := glieder.size()
	var nr := maxi(0, glieder.find(e))
	if n <= 1:
		return mitte
	var winkel := lerpf(-1.2, 1.2, float(nr) / float(n - 1))   # gut ±70°
	var p := karte.mitte(mitte) + richtung.rotated(winkel) * radius * Werte.ZELLE
	var z := _freies_feld_bei(p, mitte)
	if z == mitte or karte.einheiten_weg(karte.zelle_bei(e.position), z).is_empty():
		return mitte
	return z


## Nächstes erreichbare Feld (bis SCHUSSFELD_WEITE) mit freier Sicht auf `punkt` und in Reichweite.
func _schussfeld_suchen(von: Vector2i, punkt: Vector2, reichweite: float) -> Vector2i:
	var bestes := Karte.KEINE
	var beste := INF
	for dy in range(-SCHUSSFELD_WEITE, SCHUSSFELD_WEITE + 1):
		for dx in range(-SCHUSSFELD_WEITE, SCHUSSFELD_WEITE + 1):
			var z := von + Vector2i(dx, dy)
			if not karte.in_karte(z) or z.x < Werte.ZONE_SPALTEN or not karte.ist_begehbar(z) or not karte.ist_frei(z):
				continue
			var m := karte.mitte(z)
			if m.distance_to(punkt) > maxf(2.0, reichweite) * Werte.ZELLE or not karte.sicht_frei(m, punkt):
				continue
			var d := float(absi(dx) + absi(dy))
			if d < beste and not karte.einheiten_weg(von, z).is_empty():
				beste = d
				bestes = z
	return bestes


## Einmal je Bild: Anmarschpunkte verteilen, Bereitschaft prüfen, gemeinsam zuschlagen.
func _zange_pflegen(k: Kommandant) -> void:
	var jagende: Array = trupps.filter(func(x: Dictionary) -> bool: return str(x["modus"]) == "jagd" and not (x["mitglieder"] as Array).is_empty() and str(x.get("taktik", "")) in ["", "zange"])   # 26.11.: Sturm, Feuerschutz, Hinterhalt gehen eigene Wege
	if jagende.is_empty():
		_zange = {}
		return
	var ziel: Vector2i = bekannt
	if ziel == Karte.KEINE or zeit - bekannt_zeit > wf("ortung_takt"):
		for t: Dictionary in jagende:
			if str(t.get("taktik", "")) == "zange":
				ziel = t["zuletzt"]   # 26.11.: niemand sieht ihn – die Zange zielt auf die Funkortung
				break
	if ziel == Karte.KEINE:
		return
	if _zange.is_empty() or Vector2(ziel - (_zange["ziel"] as Vector2i)).length() > ZANGE_NEU:
		_zange = {"ziel": ziel, "erst_bereit": -1.0, "los": false}
		for t: Dictionary in jagende:
			t.erase("anflug")
	if bool(_zange["los"]) and zeit - float(_zange.get("los_t", zeit)) > 10.0:
		_zange["los"] = false   # Nachschub: die nächsten Trupps setzen wieder eine eigene Zange an
		_zange["erst_bereit"] = -1.0
	var ziel_p := karte.mitte(ziel)
	var belegt: Array[Vector2i] = []   # Felder der schon geplanten Anmarschwege
	var seiten: Array[float] = []
	for t: Dictionary in jagende:
		if t.has("anflug"):
			seiten.append(float((t["anflug"] as Dictionary)["winkel"]))
			belegt.append_array((t["anflug"] as Dictionary).get("weg", []) as Array)
	for t: Dictionary in jagende:
		if bool(t.get("zu", false)) or t.has("anflug"):
			continue
		var mitte: Vector2 = t.get("mitte", ziel_p)
		if bool(_zange["los"]) or mitte.distance_to(ziel_p) <= ZANGE_AB * Werte.ZELLE:
			t["zu"] = true   # schon nah dran oder die Zange läuft schon: direkt angreifen
			continue
		var start := startfeld(((t["mitglieder"] as Array)[0] as Node2D).position)   # 26.11.: frisch aus der Fabrik: ab ihrem Ausgang
		var a := _anflug_planen(start, ziel, (mitte - ziel_p).angle(), seiten, belegt)
		if a.is_empty():
			t["zu"] = true
			continue
		t["anflug"] = a
		seiten.append(float(a["winkel"]))
		belegt.append_array(a["weg"] as Array)
	# Bereit, wer an seinem Anmarschpunkt steht. Alle bereit – oder die ersten warten schon ZANGE_WARTE – dann los.
	var alle := true
	var irgendwer := false
	for t: Dictionary in jagende:
		if not t.has("anflug") or bool(t.get("zu", false)):
			continue
		var a: Dictionary = t["anflug"]
		if zeit - float(a.get("seit", zeit)) >= ZANGE_MAX_SEK:
			t["zu"] = true   # zu lange unterwegs: nicht mehr warten
			continue
		var bereit := (t.get("mitte", Vector2.INF) as Vector2).distance_to(karte.mitte(a["punkt"])) <= 1.8 * Werte.ZELLE
		if bereit:
			irgendwer = true
		else:
			alle = false
	if irgendwer and float(_zange["erst_bereit"]) < 0.0:
		_zange["erst_bereit"] = zeit
	if irgendwer and (alle or zeit - float(_zange["erst_bereit"]) >= ZANGE_WARTE) and not bool(_zange["los"]):
		_zange["los"] = true
		_zange["los_t"] = zeit
		var n := 0
		for t: Dictionary in jagende:
			if t.has("anflug") and not bool(t.get("zu", false)):
				t["zu"] = true
				n += 1
		if n >= 2:
			spiel.melde("Sonde 7: „Zange steht. Zugriff!“", 3.0)
		if spiel.has_method("befehl24_protokoll"):
			spiel.befehl24_protokoll("zange", {"trupps": n, "warten": snappedf(zeit - float(_zange["erst_bereit"]), 0.1)})


## Anmarschpunkt auf einer eigenen Seite (möglichst weit weg von den Seiten der anderen Trupps) und ein Zwischenpunkt auf
## einem Weg, der die Felder der anderen meidet. {} = kein erreichbarer Punkt.
func _anflug_planen(start: Vector2i, ziel: Vector2i, grund: float, seiten: Array[float], belegt: Array[Vector2i]) -> Dictionary:
	var kandidaten: Array = []
	for i in 8:
		var wkl := grund + TAU * float(i) / 8.0
		var abstand := PI
		for s: float in seiten:
			abstand = minf(abstand, absf(angle_difference(wkl, s)))
		# Wertung: weit weg von den anderen Seiten zählt viel, nahe der eigenen Herkunft ein wenig (kurzer Anmarsch)
		kandidaten.append([abstand * 2.0 - absf(angle_difference(wkl, grund)) * 0.4 if not seiten.is_empty() else -absf(angle_difference(wkl, grund)), wkl])
	kandidaten.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) > float(b[0]))
	var direkt := karte.einheiten_weg(start, _erreichbar_nahe(ziel, start)).size()
	var grenze := maxf(float(direkt) * ZANGE_UMWEG, float(direkt + 12)) if direkt > 0 else INF
	var ersatz := {}
	for k: Array in kandidaten:
		var wkl: float = k[1]
		var p := karte.mitte(ziel) + Vector2.from_angle(wkl) * float(ZANGE_ABSTAND) * Werte.ZELLE
		var punkt := _freies_feld_bei(p, Karte.KEINE)
		if punkt == Karte.KEINE:
			continue
		var weg := _weg_mit_strafe(start, punkt, belegt)
		if weg.is_empty():
			continue
		var zw: Vector2i = weg[int(weg.size() * 0.55)] if weg.size() >= 6 else Karte.KEINE
		var plan := {"punkt": punkt, "winkel": wkl, "zwischen": zw, "zw_ok": false, "weg": weg, "seit": zeit}
		if float(weg.size()) <= grenze:
			return plan
		if ersatz.is_empty():
			ersatz = plan   # zu weiter Umweg: nur, wenn keine Seite näher liegt
	return ersatz


## Weg für Truppen, auf dem schon geplante Felder anderer Trupps teurer sind (danach wieder zurückgesetzt).
func _weg_mit_strafe(von: Vector2i, nach: Vector2i, belegt: Array[Vector2i]) -> Array[Vector2i]:
	var astar: AStarGrid2D = karte._astar_einheiten
	var gesetzt: Array[Vector2i] = []
	for z: Vector2i in belegt:
		if astar.is_in_boundsv(z) and not astar.is_point_solid(z) and astar.get_point_weight_scale(z) == 1.0:
			astar.set_point_weight_scale(z, WEG_STRAFE)
			gesetzt.append(z)
	var weg := karte.einheiten_weg(von, nach)
	for z: Vector2i in gesetzt:
		astar.set_point_weight_scale(z, 1.0)
	return weg


## 26.11.: Feld, von dem aus eine Truppe ihren Weg sucht – steht sie noch in der Fabrik (nicht begehbar), deren Ausgang.
func startfeld(p: Vector2) -> Vector2i:
	var z := karte.zelle_bei(p)
	if karte.ist_begehbar(z):
		return z
	for c: Vector2i in karte.ausgang(z):
		return c
	return z


## 20.11.: `ziel` selbst, wenn es von `von` zu Fuß erreichbar ist – sonst das nächste erreichbare Feld bis 4 Felder daneben.
func _erreichbar_nahe(ziel: Vector2i, von: Vector2i) -> Vector2i:
	if von == ziel or not karte.einheiten_weg(von, ziel).is_empty():
		return ziel
	for r in range(1, 5):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var z := ziel + Vector2i(dx, dy)
				if karte.in_karte(z) and karte.ist_begehbar(z) and karte.ist_frei(z) and not karte.einheiten_weg(von, z).is_empty():
					return z
	return ziel


## Nächstes freie, begehbare Feld bei einem Punkt (sonst `sonst`).
func _freies_feld_bei(p: Vector2, sonst: Vector2i) -> Vector2i:
	var mitte := karte.zelle_bei(p)
	var bestes := sonst
	var beste := INF
	for dy in range(-2, 3):
		for dx in range(-2, 3):
			var z := mitte + Vector2i(dx, dy)
			if not karte.in_karte(z) or z.x < Werte.ZONE_SPALTEN or not karte.ist_begehbar(z) or not karte.ist_frei(z):
				continue
			var d := karte.mitte(z).distance_to(p)
			if d < beste:
				beste = d
				bestes = z
	return bestes


func _truppen() -> Array:
	var aus: Array = []
	for e in spiel.einheiten:
		if is_instance_valid(e) and e != spiel.kommandant and not (e as Einheit).ist_pilot and not (e as Einheit).in_batterie() and not bool((e as Einheit).daten.get("pilot", false)):
			aus.append(e)
	return aus


func _losschicken(e: Einheit) -> void:
	if e.posten_zelle != Karte.KEINE:
		if karte.posten.get(e.posten_zelle) == e:
			karte.posten.erase(e.posten_zelle)
		e.posten_zelle = Karte.KEINE
	e.zustand = Einheit.Zustand.BODEN
	e._punkte.clear()
	e._plan_in = 0.0


func _freies_feld_nahe(um: Vector2i, r: int) -> Vector2i:
	for versuch in 12:
		var z := um + Vector2i(randi_range(-r, r), randi_range(-r, r))
		if karte.in_karte(z) and z.x >= Werte.ZONE_SPALTEN and karte.ist_begehbar(z) and karte.ist_frei(z):
			return z
	return um


## Prüfung: Weg jedes Trupps zum letzten bekannten Ort und die Tore/Lücken darauf ins Protokoll.
func _wege_loggen() -> void:
	log_wege.clear()
	for i in trupps.size():
		var t: Dictionary = trupps[i]
		var m: Array = t["mitglieder"]
		if m.is_empty() or not is_instance_valid(m[0]):
			log_wege.append([])
			continue
		var weg := karte.einheiten_weg(karte.zelle_bei((m[0] as Node2D).position), t["zuletzt"] as Vector2i)
		log_wege.append(weg)
		var luecken: Array[Vector2i] = []
		for z: Vector2i in weg:
			var quer := (karte.inhalt(z + Vector2i(1, 0)) == Karte.WALL and karte.inhalt(z - Vector2i(1, 0)) == Karte.WALL) or (karte.inhalt(z + Vector2i(0, 1)) == Karte.WALL and karte.inhalt(z - Vector2i(0, 1)) == Karte.WALL)
			if karte.ist_tor(z) or quer:
				luecken.append(z)
		print("JAGD Trupp %d: %d Jäger · Ziel %s · Weg %d Felder · Tore/Lücken %s" % [i + 1, m.size(), str(t["zuletzt"]), weg.size(), str(luecken)])




# ------------------------------------------------------------------ Eskalation (20.11., Paul)

## Wie stark der Druck gerade ist (1 = Jagdbeginn) – für die Anzeige.
func druck() -> float:
	return 1.0 + maxf(0.0, plan_zeit() - wf("jagd_start")) / maxf(60.0, wf("eskalation_sek"))


## Abstand der Jagdwellen: von welle_takt zum Jagdbeginn auf welle_takt_min nach eskalation_sek.
func welle_takt_jetzt() -> float:
	var t := clampf(maxf(0.0, plan_zeit() - wf("jagd_start")) / maxf(1.0, wf("eskalation_sek")), 0.0, 1.0)
	var takt := lerpf(wf("welle_takt"), wf("welle_takt_min"), t)
	return takt * (1.5 if geheim else 1.0)


## Neue Lager außer Brakks Sicht und Tore in den Wällen Richtung Myriaden-HQ.
func _eskalation() -> void:
	if plan_zeit() >= wf("lager_neu_ab") and zeit >= _lager_naechst and fabrik_hp.size() < int(w("lager_max")):
		_lager_naechst = zeit + wf("lager_neu_takt")
		_neues_lager()
	if plan_zeit() >= wf("tore_ab") and zeit >= _tore_naechst and tore_gesetzt < int(w("tore_max")):
		_tore_naechst = zeit + wf("tore_takt")
		_tor_setzen()


## Ein neues Lager (Fabrik, Stellungen, Turm) auf einem freien Feld, das Brakk gerade nicht sieht, nicht zu nah an ihm.
func _neues_lager() -> void:
	var k: Kommandant = spiel.kommandant
	var kandidaten: Array[Vector2i] = []
	for y in range(1, Werte.ZEILEN - 1):
		for x in range(Werte.ZONE_SPALTEN + 3, Werte.SPALTEN - 1):
			var z := Vector2i(x, y)
			if not karte.ist_bebaubar(z) or _im_schild(karte.mitte(z)) or karte.ist_basis(z) or _terminal_feld(z) or (zuflucht != null and zuflucht.bereich(z)):
				continue
			if karte.mitte(z).distance_to(k.position) < 7.0 * Werte.ZELLE or karte.sicht_frei(k.position, karte.mitte(z)):
				continue
			var frei := true
			for f: Vector2i in spiel.fabriken:
				if Vector2(f - z).length() < 4.0:
					frei = false
			for e in spiel.einheiten:
				if is_instance_valid(e) and karte.zelle_bei((e as Node2D).position) == z:
					frei = false
			if frei:
				kandidaten.append(z)
	if kandidaten.is_empty():
		return
	var z: Vector2i = kandidaten.pick_random()
	_setze_fabrik(z, Werte.ALARM_TRUPPEN[randi() % Werte.ALARM_TRUPPEN.size()], 2 if plan_zeit() >= wf("stufe2_ab") else 1)
	var gebaut := 0
	for d: Vector2i in [Vector2i(-2, 0), Vector2i(0, -2), Vector2i(0, 2), Vector2i(2, 0), Vector2i(-2, -2), Vector2i(-2, 2), Vector2i(2, -2), Vector2i(2, 2)]:
		var n := z + d
		if gebaut >= int(w("stellungen_je_fabrik")):
			break
		if karte.ist_bebaubar(n) and not _im_schild(karte.mitte(n)) and not karte.ist_basis(n) and not _terminal_feld(n) and karte.zelle_bei(k.position) != n:
			karte.setze(n, Karte.WALL)
			karte.baue_aus(n, Karte.STELLUNG)
			karte.fest[n] = true
			gebaut += 1
	fabrik_hp[z] = wf("fabrik_leben")
	karte.fest[z] = true
	_lager_turm(z)
	_wege_freimachen()
	rueckseite[z] = _rueck_feld(z)
	routen[z] = _streifenweg(z)
	karte.aktualisiere_pfad()
	spiel.melde("Der Technoclan hat ein neues Lager errichtet.", 3.0)
	print("ORDER24 Neues Lager %s bei %.0f s (%d Stellungen)" % [str(z), zeit, gebaut])


## Ein Tor in den Wall, der auf dem Weg vom Schild zum Myriaden-HQ am meisten Umweg kostet (die Truppen gehen hindurch).
func _tor_setzen() -> void:
	tor_versuche += 1
	var start := _freies_feld_bei(karte.mitte(karte.basis) + Vector2(-(SCHILD_RADIUS + 1.0) * Werte.ZELLE, 0), karte.basis)
	var ziel := _freies_feld_bei(karte.mitte(Werte.ANGRIFFS_ZELLE + Vector2i(Werte.ZONE_SPALTEN + 1, 0)), Werte.ANGRIFFS_ZELLE)
	var bestes := Karte.KEINE
	var gewinn := 0
	var vorher := karte.einheiten_weg(start, ziel).size()
	if vorher == 0:
		vorher = 999
	for z: Vector2i in karte.feld.keys():
		if karte.feld[z] != Karte.WALL or karte.ausbau.has(z) or karte.stuetze_von.has(z) or _im_schild(karte.mitte(z)) or (zuflucht != null and zuflucht.im_ring(z)):   # G: kein Tor in den Ring einer Zuflucht
			continue
		var quer := (karte.inhalt(z + Vector2i(0, 1)) == Karte.WALL and karte.inhalt(z - Vector2i(0, 1)) == Karte.WALL) or (karte.inhalt(z + Vector2i(1, 0)) == Karte.WALL and karte.inhalt(z - Vector2i(1, 0)) == Karte.WALL)
		if not quer:
			continue
		karte._astar_einheiten.set_point_solid(z, false)   # zur Probe: wäre hier ein Tor
		var nach := karte.einheiten_weg(start, ziel).size()
		karte._astar_einheiten.set_point_solid(z, true)
		if nach > 0 and vorher - nach > gewinn:
			gewinn = vorher - nach
			bestes = z
	if bestes == Karte.KEINE:
		print("ORDER24 Kein Tor nötig bei %.0f s (Weg %d Felder)" % [zeit, vorher])
		return
	karte.baue_aus(bestes, Karte.TOR)
	karte.aktualisiere_pfad()
	tore_gesetzt += 1
	print("ORDER24 Tor %s bei %.0f s (Weg %d Felder kürzer)" % [str(bestes), zeit, gewinn])


# ------------------------------------------------------------------ Vorstoß

## Ab vorstoss_start bekommt ein Jagdtrupp das Myriaden-HQ als Ziel (fällt er, nach 20 s der nächste).
func _vorstoss_waehlen() -> void:
	for t: Dictionary in trupps:
		if str(t["modus"]) == "vorstoss" and not (t["mitglieder"] as Array).is_empty():
			return
	var hq := karte.mitte(Werte.ANGRIFFS_ZELLE)
	var bester: Dictionary = {}
	var beste := INF
	for t: Dictionary in trupps:
		if (t["mitglieder"] as Array).is_empty():
			continue
		var d: float = (t.get("mitte", (t["mitglieder"][0] as Node2D).position) as Vector2).distance_to(hq)
		if d < beste:
			beste = d
			bester = t
	if bester.is_empty():
		return
	bester["modus"] = "vorstoss"
	_vorstoss_wahl = zeit + 20.0
	print("ORDER24 Vorstoß bei %.0f s: %d Truppen zum Myriaden-HQ" % [zeit, (bester["mitglieder"] as Array).size()])


func _vorstoss(echt: float) -> void:
	if myr_hq_besetzt:
		return
	var hq: Vector2 = karte.mitte(Werte.ANGRIFFS_ZELLE)
	var da := 0
	for t: Dictionary in trupps:
		if str(t["modus"]) != "vorstoss":
			continue
		for e: Variant in t["mitglieder"]:
			if is_instance_valid(e) and (e as Node2D).position.distance_to(hq) <= 1.6 * Werte.ZELLE:
				da += 1
	if da > 0:
		if not _brakk_ahnt:
			_brakk_ahnt = true   # 20.11. (Paul): Brakk merkt, dass am Myriaden-HQ etwas vorgeht
			funken([["BRAKK", "Moment … was treiben die da am Myriaden-HQ?", ""], ["BRAKK", "Nehmen die es ein, ist meine letzte Zuflucht weg. Das lasse ich nicht zu.", ""]])
			print("ORDER24 Brakk ahnt den Vorstoß bei %.0f s" % zeit)
		var tempo := 1.0 / maxf(1.0, wf("vorstoss_sek"))
		var k: Kommandant = spiel.kommandant
		if k != null and not k.gefallen and k.position.distance_to(hq) <= VORSTOSS_BRAKK_NAH * Werte.ZELLE:
			tempo *= VORSTOSS_BRAKK_TEMPO   # 26.11. (Paul): Brakk am HQ drosselt die Einnahme
		vorstoss_anteil = minf(1.0, vorstoss_anteil + echt * tempo)
		if vorstoss_anteil >= 0.5 and not _sonde_hq_gemeldet:
			_sonde_hq_gemeldet = true
			spiel.melde(tr("Sonde 7: „Sie nehmen dein HQ. Beweg dich.“"), 4.0)
		if vorstoss_anteil >= 1.0:
			if geheim:
				myr_hq_besetzt = true   # im Überläufer-Verlauf: kein zweiter Schild, Brakk kann es zurückholen
				spiel.melde("Der Technoclan hat das Myriaden-HQ besetzt – die Fabriken stehen still. Stell dich hin und hol es zurück!", 6.0)
			else:
				_zweites_hq()
	else:
		vorstoss_anteil = maxf(0.0, vorstoss_anteil - echt / maxf(1.0, wf("vorstoss_sek")) * wf("vorstoss_rueckgang"))


## Das Myriaden-HQ fällt: zweiter Schild (Ringterminal darin unerreichbar), Med-Kits dort weg, zwei Fabriken.
func _zweites_hq() -> void:
	hq_eingenommen = true
	vorstoss_anteil = 1.0
	var mitte: Vector2 = karte.mitte(Werte.START_ZELLE) + Vector2(Werte.ZELLE * 1.0, 0)
	schild_mitten.append(mitte)
	if is_instance_valid(spiel.hq):
		spiel.hq.modulate = TECHNO_FARBE   # Platzhalter: das Myriaden-HQ in Technoclan-Farbe
	var gebaut := 0
	for d: Vector2i in [Vector2i(1, -2), Vector2i(1, 2), Vector2i(2, -1), Vector2i(2, 1), Vector2i(0, -2), Vector2i(0, 2)]:
		if gebaut >= 2:
			break
		var z := Werte.START_ZELLE + d
		if karte.in_karte(z) and karte.ist_frei(z) and not karte.ist_basis(z) and not _terminal_feld(z):
			karte.setze(z, Karte.FABRIK)
			var typ: String = Werte.ALARM_TRUPPEN[gebaut % Werte.ALARM_TRUPPEN.size()]
			spiel.fabriken[z] = {"timer": 0.0, "einheiten": [], "typ": typ, "stufe": 1}
			karte.fabrik_typ[z] = typ
			karte.fabrik_stufe[z] = 1
			karte.fest[z] = true
			gebaut += 1
	karte.aktualisiere_pfad()
	for m: Dictionary in medkits.duplicate():
		if _im_schild(karte.mitte(m["zelle"] as Vector2i)) or bool(m.get("hq", false)):
			if m["knoten"] != null:
				(m["knoten"] as Node3D).queue_free()
			medkits.erase(m)
	for t: Dictionary in trupps:
		if str(t["modus"]) == "vorstoss":
			t["modus"] = "jagd"
			t["gesehen"] = zeit
	_medkit_uhr = 0.0
	spiel._einblendung.banner("MYRIADEN-HQ GEFALLEN", "Zweiter Schild – Ringterminal und Med-Kits verloren", TECHNO_FARBE)
	spiel.melde("Das Myriaden-HQ ist gefallen: zweiter Schild, das Ringterminal ist unerreichbar. Med-Kits gibt es nur noch verstreut.", 8.0)
	print("ORDER24 Vorstoß: Myriaden-HQ eingenommen bei %.0f s · zweites HQ mit %d Fabriken" % [zeit, gebaut])


# ------------------------------------------------------------------ Zuflucht: Ringterminal, Med-Kits (20.11.)

func _terminal_feld(z: Vector2i) -> bool:
	return terminal != Karte.KEINE and z.x >= terminal.x and z.x <= terminal.x + 1 and z.y >= terminal.y and z.y <= terminal.y + 1


## Am Myriaden-HQ: Ringterminal (2×2) möglichst nah am HQ, ein Med-Kit und eine Sprengladung daneben.
func _zuflucht_legen() -> void:
	var hq := karte.mitte(Werte.ANGRIFFS_ZELLE) + Vector2(Werte.ZELLE * 1.0, 0)
	# 20.11. (Paul): das Lichtterminal steckt im Myriaden-HQ selbst (wie früher am Technoclan-HQ) – keine eigene Plattform
	terminal = Karte.KEINE
	var frei: Array[Vector2i] = []
	for y in range(1, Werte.ZEILEN - 1):
		for x in range(Werte.ZONE_SPALTEN, int(Werte.SPALTEN / 2.0)):
			var z := Vector2i(x, y)
			if karte.ist_begehbar(z) and karte.ist_frei(z) and not _terminal_feld(z):
				frei.append(z)
	frei.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return karte.mitte(a).distance_to(hq) < karte.mitte(b).distance_to(hq))
	if frei.size() > 0:
		medkits.append({"zelle": frei[0], "da": true, "knoten": null, "hq": true})
	if frei.size() > 1:
		ladungen_boden.append({"pos": karte.mitte(frei[1]), "knoten": null, "bleibt": true})   # 26.11.: wartet auf Brakk, verfällt nicht
	# 20.11. (Paul): der Heilturm steht in der Myriaden-Zone (innerhalb ihres Schilds), nah am HQ – nicht am Rand
	var zone_beste := INF
	for y in range(1, Werte.ZEILEN - 1):
		for x in Werte.ZONE_SPALTEN:
			var z := Vector2i(x, y)
			var d := karte.mitte(z).distance_to(hq_mitte())
			if d < 1.5 * Werte.ZELLE or not karte.in_karte(z) or karte.feld.has(z):
				continue
			if d < zone_beste:
				zone_beste = d
				heilturm = z
	if heilturm == Karte.KEINE and frei.size() > 2:
		heilturm = frei[2]
	print("ORDER24 Zuflucht am Myriaden-HQ: Lichtterminal im HQ · Med-Kit %s · Heilturm %s" % [str(frei[0] if frei.size() > 0 else Karte.KEINE), str(heilturm)])


## Versteckte Felder für zufällige Med-Kits: in Winkeln zwischen Erdwällen, außerhalb der Schilde.
func _medkit_feld() -> Vector2i:
	var kandidaten: Array[Vector2i] = []
	for y in range(1, Werte.ZEILEN - 1):
		for x in range(Werte.ZONE_SPALTEN + 1, Werte.SPALTEN - 1):
			var z := Vector2i(x, y)
			if karte.ist_begehbar(z) and karte.ist_frei(z) and karte.wall_nachbarn(z) >= 2 and not _im_schild(karte.mitte(z)):
				kandidaten.append(z)
	for m: Dictionary in medkits:
		kandidaten.erase(m["zelle"] as Vector2i)
	return kandidaten.pick_random() if not kandidaten.is_empty() else Karte.KEINE


## Vor dem Fall liegt das Med-Kit am HQ alle medkit_takt Sekunden wieder; danach erscheint so oft eins verstreut (höchstens 2).
func _medkits_pflegen(k: Kommandant, echt: float) -> void:
	_medkit_uhr += echt
	if _medkit_uhr >= wf("medkit_takt"):
		_medkit_uhr = 0.0
		if not hq_eingenommen:
			for m: Dictionary in medkits:
				m["da"] = true
		else:
			var liegen := 0
			for m: Dictionary in medkits:
				if bool(m["da"]):
					liegen += 1
			var z := _medkit_feld()
			if liegen < 2 and z != Karte.KEINE:
				medkits.append({"zelle": z, "da": true, "knoten": null})
				spiel.melde("Irgendwo hinter den Wällen liegt ein Med-Kit.", 2.5)
	for m: Dictionary in medkits:
		if bool(m["da"]) and k.leben < k.max_leben and k.position.distance_to(karte.mitte(m["zelle"] as Vector2i)) <= 0.7 * Werte.ZELLE:
			m["da"] = false
			nemesis.medkit()   # 22.11.: Treffer gleich danach = „am Med-Kit erwischt“
			k.leben = minf(k.max_leben, k.leben + k.max_leben * wf("medkit_heilung") / 100.0)
			spiel.melde("Med-Kit: +%d %% Leben" % int(w("medkit_heilung")), 2.0)
			Ton.spiele(spiel, "ui-klick")
	if not _terminal_erklaert and k.position.distance_to(hq_mitte()) <= 3.5 * Werte.ZELLE:
		_terminal_erklaert = true   # 20.11. (Paul): Ankunft an der Zuflucht
		funken([
			["BRAKK", "Das Lichtterminal im Myriaden-HQ läuft noch – gerade so. Mit Gold hole ich mir hier Ringe: [F] am HQ.", ""],
			["BRAKK", "Und der Heilturm daneben hat auch noch nicht den Geist aufgegeben. Hier kann ich kurz durchatmen.", ""],
		])
	# 20.11. (Paul): Heilturm – heilt Brakk im Umkreis, solange kein Technoclan in der Nähe ist
	heilt = false
	if heilturm != Karte.KEINE and not hq_eingenommen and not myr_hq_besetzt and k.leben < k.max_leben:
		if k.position.distance_to(karte.mitte(heilturm)) <= wf("heilturm_radius") * Werte.ZELLE and not _technoclan_nah(k.position, 3.0):
			k.leben = minf(k.max_leben, k.leben + k.max_leben * wf("heilturm_prozent") / 100.0 * echt)
			heilt = true


## Ringterminal: steht Brakk darauf, öffnet [F] das Lichtterminal (Ringe kaufen und aufwerten) – auch im Kampf.
## Nach dem Fall des Myriaden-HQ liegt es im zweiten Schild.
func am_terminal(fuss: Vector2) -> bool:
	if hq_eingenommen or myr_hq_besetzt:
		return false
	return fuss.distance_to(hq_mitte()) <= 2.5 * Werte.ZELLE   # 20.11. (Paul): am Myriaden-HQ selbst


## Mitte des Myriaden-HQ (Lichtterminal, Ankunft).
func hq_mitte() -> Vector2:
	if is_instance_valid(spiel.hq):
		return (spiel.hq as Node2D).position
	return karte.mitte(Werte.ANGRIFFS_ZELLE)




# ------------------------------------------------------------------ Überläufer – geheimer Verlauf (20.11., Paul)
## Hält Brakk das Myriaden-HQ bis geheim_ab (der Vorstoß darauf ist nicht angesagt – Brakk ahnt es nur), meldet Sonde 7,
## dass er übergelaufen ist. Dann baut er mit [1] Myriaden-Fabriken in der Zone des HQ (eine Sorte, myr_fabrik_preis) und
## wirft mit [C] Ringfelder darüber: Der Ring bestimmt die Einheit (MYR_RING), ihr Preis die Zahl je Zyklus. Je
## Wellenzyklus kostet die Produktion myr_kosten_anteil % der Einheiten. Alle myr_takt Sekunden
## laufen die Myriaden los – über die Checkpoints zur Technoclan-Basis. Hält Brakk beide Checkpoints geheim_cp_sek lang,
## fällt der Schild des Technoclan-HQ; Brakks Waffen und Myriaden an der Basis zerstören es → geheimes Ende.
## Das Myriaden-HQ kann weiter fallen (die Fabriken stehen dann still) und von Brakk zurückerobert werden.

const MYR_TYPEN: Array[String] = ["hund", "sphaere", "schild", "sprenger", "rauch", "sani", "fahne"]
## 20.11. (Paul): Welche Myriaden-Einheit eine Fabrik im Feld des Rings baut. Wie viele je Zyklus, folgt aus dem Preis der
## Einheit (Phantom.PREISE): myr_wert 60 → 6 Hunde, aber nur alle drei Zyklen ein Belagerungsturm.
const MYR_RING := {
	"feuerteam": "hund",         # Taktring: viele, schnell
	"minigun": "sphaere",        # Wirbelring: Battlesphären
	"bollwerk": "schild",        # Wallring: Schildträger
	"durchschuss": "sprenger",   # Durchschlagring: bricht Erdwälle
	"brandfeld": "rauch",        # Brandring: Rauchwerfer
	"plasmagel": "sani",         # Gelring: Sanitäter
	"markierung": "fahne",       # Zielring: Fahnenträger führt den Trupp
	"abpraller": "schwarm",      # Sprungring: Schwarmgeist
	"laser": "belagerung",       # Glutstrahlring: Belagerungsturm
}
const MYR_FARBE := Color("ff7ad9")
const LICHT_MENUE := Color("6ee6ff")
var myr_fabriken := {}            # Zonenfeld -> {"typ": String, "knoten": Node3D}
var myr_hq_besetzt := false
var _myr_rueck := 0.0
var _myr_uhr := 0.0
var cp_gehalten := 0.0
var hq_schild_aus := false
var tc_hq_leben := 0.0
var geheim_sieg := false
var _cp_brakk: Array[float] = [0.0, 0.0]
var _cp_f := false                # 26.11. (Paul): [F] am Checkpoint gehalten
const CP_HALTEN_SEK := 3.0        # 26.11. (Paul): so lange [F] am Checkpoint halten
const CP_FARBE := Color("ff9a3d") # Orange wie die Myriaden-Flagge am Checkpoint
var _cp_takt := 0.0


func geheim_text() -> String:
	if myr_hq_besetzt:
		return "Myriaden-HQ besetzt – zurückerobern!"
	if hq_schild_aus:
		return "Technoclan-HQ %d %%" % roundi(100.0 * tc_hq_leben / maxf(1.0, wf("geheim_hq_leben")))
	var n := karte.cp_feind.count(true)
	return "Checkpoints %d/%d%s" % [n, karte.cp_feind.size(), " · Schild fällt in %d s" % ceili(wf("geheim_cp_sek") - cp_gehalten) if n == karte.cp_feind.size() and n > 0 else ""]


## Funkspruch im Spiel (Steuerung bleibt frei): Zeilen wie in der Verrat-Sequenz.
func funken(zeilen: Array, danach: Callable = Callable()) -> void:
	if spiel.ego == null:
		if danach.is_valid():
			danach.call()
		return
	if funk != null:
		funk.queue_free()
	funk = Verrat24.new()
	funk.zeilen = zeilen
	funk.sperrt = false
	add_child(funk)
	funk.fertig.connect(func() -> void:
		if funk != null:
			funk.queue_free()
		funk = null
		if danach.is_valid():
			danach.call())


func _geheim_starten() -> void:
	geheim = true
	karte.cp_aktiv = true
	karte.cp_route = true
	for i in karte.cp_feind.size():
		karte.cp_feind[i] = false
	karte.aktualisiere_pfad()
	tc_hq_leben = wf("geheim_hq_leben")
	_myr_uhr = 0.0
	spiel._einblendung.banner("ÜBERLÄUFER", "Brakk führt jetzt die Myriaden", MYR_FARBE)
	Ton.spiele(spiel, "alert")
	# 20.11. (Paul): Der Schwarm meldet sich – Brakk versteht, was möglich ist; danach das Lichtmenü mit dem Neuen
	funken([
		["MYRIADEN-SCHWARM", "1110000 100 010010 1000 1011101010110 01 001", ""],
		["MYRIADEN-SCHWARM", "0110 1 0011100 10 111 · 1000110 0 1101", ""],
		["BRAKK", "Ich verstehe kein Wort – und doch alles. Der Feind meines Feindes …", ""],
		["BRAKK", "Gut. Ihr habt mich zum Verräter erklärt, Rat. Dann kämpfe ich eben mit denen, die ihr fürchtet.", ""],
		["SONDE 7 · FUNK", "An alle Einheiten: Kommandant Brakk hat sich mit dem Schwarm verbündet. Vernichten.", ""],
	], func() -> void: _lichtmenue_bis = zeit + 25.0)
	print("ORDER24 Überläufer bei %.0f s" % zeit)


func _geheim_pflegen(k: Kommandant, echt: float) -> void:
	# Wellenzyklus der Myriaden
	_myr_uhr += echt
	if _myr_uhr >= wf("myr_takt"):
		_myr_uhr = 0.0
		spiel.budget += gold(int(w("geheim_einkommen")))   # F4: gold_faktor
		if not myr_hq_besetzt:
			_myr_welle()
	# Brakk nimmt Checkpoints ein (er gehört jetzt zu den Myriaden) – 26.11. (Paul): [F] am Checkpoint CP_HALTEN_SEK halten
	if _cp_f and cp_vor_brakk(k) < 0:
		_cp_f = false   # weggegangen
	for i in karte.checkpoints.size():
		var cp: Vector2i = karte.checkpoints[i]
		if karte.cp_feind[i]:
			_cp_brakk[i] = 0.0
			continue
		if _cp_f and karte.zelle_bei(k.position).distance_to(cp) <= 1.0 and not _technoclan_nah(karte.mitte(cp), 2.0):
			_cp_brakk[i] += echt
			if _cp_brakk[i] >= CP_HALTEN_SEK:
				_cp_brakk[i] = 0.0
				_cp_f = false
				spiel.checkpoint_erreicht(i)   # wird orange und wirkt wie ein Myriaden-Checkpoint im Normalspiel
				spiel._einblendung.banner(tr("CHECKPOINT %d") % (i + 1), tr("Checkpoint für die Myriaden"), CP_FARBE)
		else:
			_cp_brakk[i] = 0.0 if not _cp_f else maxf(0.0, _cp_brakk[i] - echt)
	# Der Technoclan holt verlorene Checkpoints zurück: die nächsten Truppen am Boden laufen hin
	_cp_takt -= echt
	if _cp_takt <= 0.0:
		_cp_takt = 3.0
		for i in karte.checkpoints.size():
			if karte.cp_feind[i]:
				_rueckholer(karte.checkpoints[i])
	# Beide gehalten → Schild fällt; verliert Brakk beide wieder, kommt er zurück
	var n := karte.cp_feind.count(true)
	if n == karte.cp_feind.size() and n > 0:
		cp_gehalten += echt
		if cp_gehalten >= wf("geheim_cp_sek") and not hq_schild_aus:
			hq_schild_aus = true
			spiel._einblendung.banner("SCHILD GEFALLEN", "Das Technoclan-HQ ist verwundbar", MYR_FARBE)
			Ton.spiele(spiel, "alert")
			print("ORDER24 Schild des Technoclan-HQ gefallen bei %.0f s" % zeit)
	else:
		cp_gehalten = maxf(0.0, cp_gehalten - echt)
		if n == 0 and hq_schild_aus:
			hq_schild_aus = false
			spiel.melde("Der Technoclan hat beide Checkpoints zurück – der Schild steht wieder.", 4.0)
	# Besetztes Myriaden-HQ zurückerobern
	if myr_hq_besetzt:
		var hq := karte.mitte(Werte.ANGRIFFS_ZELLE)
		if k.position.distance_to(hq) <= 2.0 * Werte.ZELLE and not _technoclan_nah(hq, 3.0):
			_myr_rueck += echt
			if _myr_rueck >= wf("myr_rueck_sek"):
				myr_hq_besetzt = false
				_myr_rueck = 0.0
				vorstoss_anteil = 0.0
				spiel.melde("Myriaden-HQ zurückerobert – die Fabriken laufen wieder.", 4.0)
		else:
			_myr_rueck = maxf(0.0, _myr_rueck - echt)


## 26.11. (Paul): Checkpoint, den Brakk im Überläufer-Verlauf gerade mit [F] einnehmen kann (-1 = keiner in 1 Feld).
func cp_vor_brakk(k: Kommandant) -> int:
	if not geheim or k == null or k.gefallen:
		return -1
	var hier := karte.zelle_bei(k.position)
	for i in karte.checkpoints.size():
		if not karte.cp_feind[i] and hier.distance_to(karte.checkpoints[i]) <= 1.0:
			return i
	return -1


## main.fernziel / naechste_bodeneinheit: im Überläufer-Verlauf ist Brakk kein Ziel der Myriaden.
func kein_gegner_ziel(e: Einheit) -> bool:
	return geheim and e == spiel.kommandant


func _technoclan_nah(p: Vector2, felder: float) -> bool:
	for e in _truppen():
		if (e as Node2D).position.distance_to(p) <= felder * Werte.ZELLE:
			return true
	return false


## Bis zu drei Truppen am Boden (keine Verteidiger der Basis) laufen zu einem verlorenen Checkpoint.
func _rueckholer(cp: Vector2i) -> void:
	var p := karte.mitte(cp)
	var liste: Array = _truppen().filter(func(x: Variant) -> bool: return (x as Einheit).zustand == Einheit.Zustand.BODEN and not _ist_innen(x as Einheit) and x != pilot and not eskorte.has(x))
	liste.sort_custom(func(a: Node2D, b: Node2D) -> bool: return a.position.distance_squared_to(p) < b.position.distance_squared_to(p))
	for e: Variant in liste.slice(0, 3):
		alarm[(e as Node).get_instance_id()] = {"ziel": cp, "bis": zeit + 15.0}


## 20.11. (Paul): Ring, in dessen Feld die Myriaden-Fabrik `z` steht ("" = keins; das zuletzt gesetzte Feld gewinnt).
func myr_ring(z: Vector2i) -> String:
	var k: Kommandant = spiel.kommandant
	if k == null or k.fortschritt == null:
		return ""
	var ring := ""
	for r: String in k.fortschritt.felder:
		if BrakkFortschritt.im_feld(z, k.fortschritt.felder[r] as Vector2i):
			ring = r
	return ring


## Was die Fabrik `z` gerade baut: die Einheit des Rings, ohne Feld Hunde.
func myr_typ(z: Vector2i) -> String:
	return str(MYR_RING.get(myr_ring(z), "hund"))


## Wert, den die Fabrik `z` je Zyklus verbaut: myr_wert, ohne Ringfeld nur ein Teil, je Ringstufe mehr.
func myr_wert_von(z: Vector2i) -> float:
	var ring := myr_ring(z)
	if ring == "":
		return wf("myr_wert") * wf("myr_ohne_ring") / 100.0
	var st: int = spiel.kommandant.fortschritt.ring_stufe(ring)
	return wf("myr_wert") * (1.0 + wf("myr_ring_stufe") / 100.0 * float(maxi(0, st - 1)))


## Kurz für Anzeigen: „6 Hunde je Zyklus“ bzw. „1 Belagerungsturm alle 3 Zyklen“.
func myr_takt_text(typ: String, wert: float) -> String:
	var preis := float(maxi(1, Phantom.preis(typ)))
	var name := str(Werte.GEGNER[typ]["name"])
	var je := wert / preis
	if je >= 0.95:
		return "%s × %s je Zyklus" % [str(snappedf(je, 0.1)).trim_suffix(".0").replace(".", ","), name]
	return "1 %s alle %s Zyklen" % [name, str(snappedf(1.0 / je, 0.1)).trim_suffix(".0").replace(".", ",")]


## Ein Wellenzyklus: jede Myriaden-Fabrik bekommt ihren Wert gutgeschrieben und schickt so viele Einheiten los, wie das
## Guthaben hergibt (der Rest bleibt stehen) – so zählt ein Fahnenträger nicht wie ein Hund. Die Produktion kostet Gold.
func _myr_welle() -> void:
	var los := 0
	for z: Vector2i in myr_fabriken:
		var fab: Dictionary = myr_fabriken[z]
		var typ := myr_typ(z)
		if str(fab.get("typ", "")) != typ:
			fab["typ"] = typ
			fab["guthaben"] = 0.0   # umgestellt: von vorn
		var preis := maxi(1, Phantom.preis(typ))
		fab["guthaben"] = float(fab.get("guthaben", 0.0)) + myr_wert_von(z)
		var n := int(floorf(float(fab["guthaben"]) / float(preis) + 0.001))
		if n <= 0:
			continue
		var kosten := roundi(float(n * preis) * wf("myr_kosten_anteil") / 100.0)
		if spiel.budget < kosten:
			spiel.melde("Zu wenig Gold für die Myriaden-Fabrik (%s): %d nötig." % [str(Werte.GEGNER[typ]["name"]), kosten], 3.0)
			fab["guthaben"] = minf(float(fab["guthaben"]), float(preis))   # nicht endlos ansparen
			continue
		spiel.budget -= kosten
		fab["guthaben"] = float(fab["guthaben"]) - float(n * preis)
		for i in n:
			var g: Gegner = spiel._neuer_gegner(typ, z, 0)
			g.position += Vector2(randf_range(-8, 8), randf_range(-8, 8))
		los += n
	if los > 0:
		print("ORDER24 Myriaden-Welle bei %.0f s: %d Einheiten" % [zeit, los])


## [1] im Überläufer-Verlauf: Myriaden-Fabrik auf dem Feld unter dem Fadenkreuz bauen (nur in der Zone am HQ).
func ego_zahl(ego: EgoModus, taste: int) -> bool:
	if not geheim or vorbei:
		return false
	if taste != KEY_1:
		return false
	var grund := myr_bauen("", karte.zelle_bei(ego.ziel_welt()), ego._fuss2d())
	if grund != "":
		spiel.melde(grund, 2.5)
	return true


func myr_preis(_typ: String = "") -> int:
	return int(w("myr_fabrik_preis"))   # 20.11. (Paul): eine Fabrik, ein Preis


## Baut eine Myriaden-Fabrik; gibt den Grund zurück, wenn es nicht geht ("" = gebaut).
func myr_bauen(typ: String, z: Vector2i, fuss: Vector2) -> String:
	if myr_hq_besetzt:
		return "Das Myriaden-HQ ist besetzt – erst zurückerobern."
	if not karte.in_karte(z) or z.x >= Werte.ZONE_SPALTEN:
		return "Myriaden-Fabriken nur in der Zone am Myriaden-HQ (ganz links)."
	if myr_fabriken.has(z) or z == Werte.START_ZELLE or z == Werte.ANGRIFFS_ZELLE or _terminal_feld(z) or not karte.ist_frei(z):
		return "Hier ist kein Platz."
	if karte.mitte(z).distance_to(fuss) > 7.0 * Werte.ZELLE:
		return "Zu weit weg – geh näher heran."
	var preis := myr_preis(typ)
	if spiel.budget < preis:
		return "Zu wenig Gold: %d nötig." % preis
	spiel.budget -= preis
	typ = myr_typ(z)
	myr_fabriken[z] = {"typ": typ, "knoten": null, "guthaben": 0.0, "gezeigt": ""}
	Ton.spiele(spiel, "ui-klick")
	spiel.melde("Myriaden-Fabrik gebaut (−%d): %s.%s" % [preis, myr_takt_text(typ, myr_wert_von(z)), "" if myr_ring(z) != "" else " Mit [C] ein Ringfeld darüber werfen, dann baut sie die Einheit des Rings."], 4.0)
	print("ORDER24 Myriaden-Fabrik %s bei %s" % [typ, str(z)])
	return ""


## Myriaden an der Technoclan-Basis (main.gegner_am_ziel): ohne Schild treffen sie das HQ, mit Schild verpuffen sie.
func gegner_am_ziel(g: Gegner) -> bool:
	if not geheim:
		return false
	g.trupp.erase(g)
	spiel.gegner.erase(g)
	g.queue_free()
	if hq_schild_aus:
		_tc_hq_treffer(float(maxi(20, Phantom.preis(g.typ))) * 3.0)
	return true


func _tc_hq_treffer(menge: float) -> void:
	if not hq_schild_aus or vorbei:
		return
	tc_hq_leben -= menge
	if tc_hq_leben <= 0.0:
		tc_hq_leben = 0.0
		geheim_sieg = true
		spiel.erfolg("ueberlaeufer")   # 20.11. (Paul): Erfolg – geheimes Ende
		print("ORDER24 Technoclan-HQ zerstört bei %.0f s – geheimes Ende" % zeit)
		_ende(true)


## Kasten in Myriaden-Farbe mit dem Bild der Einheit darüber (Platzhalter).
func _myr_3d(hd: HdAnsicht) -> void:
	for z: Vector2i in myr_fabriken:
		var f: Dictionary = myr_fabriken[z]
		var typ_jetzt := myr_typ(z)
		if f["knoten"] != null and str(f.get("gezeigt", typ_jetzt)) == typ_jetzt:
			continue
		if f["knoten"] != null:
			# 20.11. (Paul): das Ringfeld hat die Fabrik umgestellt – Platzhalter mit der neuen Einheit
			_knoten3d.erase(f["knoten"])
			(f["knoten"] as Node3D).queue_free()
		f["gezeigt"] = typ_jetzt
		var ring_jetzt := myr_ring(z)
		var kn := Node3D.new()
		hd.add_child(kn)
		kn.position = Vector3(float(z.x) + 0.5, 0.0, float(z.y) + 0.5)
		_kasten3d(kn, Vector3(0.85, 0.6, 0.85), Color("5a2350"), Vector3(0, 0.3, 0))
		_kasten3d(kn, Vector3(0.6, 0.12, 0.6), Einheit.ABZEICHEN.get(ring_jetzt, MYR_FARBE) if ring_jetzt != "" else MYR_FARBE, Vector3(0, 0.66, 0))   # Deckel in Ringfarbe
		var d: Dictionary = Werte.grafik_daten(Werte.GEGNER[typ_jetzt])
		if d.has("blatt") and d.has("zelle"):
			var bild := AtlasTexture.new()
			bild.atlas = load(str(d["blatt"]))
			bild.region = Rect2(0, 0, float(d["zelle"]), float(d["zelle"]))
			var s := Sprite3D.new()
			s.texture = bild
			s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
			s.pixel_size = 0.7 / float(d["zelle"])
			s.position = Vector3(0, 1.25, 0)
			kn.add_child(s)
		f["knoten"] = kn
		_knoten3d.append(kn)


# ------------------------------------------------------------------ Ego-Sicht: Tasten und Anzeige (20.11.)

## Aus ego_modus._aktion: [C] ist in Befehl 24 nur die Sprengladung (Brakk baut nicht), [F] an der Rückseite einer Fabrik
## sabotiert (gehalten; 20.11., Paul: vorher [E] – das war zugleich die Lichttreppe). true = erledigt.
## 21.11. (Paul): Fluchtphase – vom Ende der Verrat-Sequenz bis zur Ankunft am Myriaden-HQ (Funkspruch dort) sind
## Q, E und R gesperrt; nur Laufen, Springen und Tumble. Verfolgung und Beschuss bleiben dabei unverändert.
const FLUCHT_GESPERRT: Array[String] = ["Q", "E", "R"]


func flucht_sperre() -> bool:
	return laeuft and not vorbei and not _terminal_erklaert


func ego_taste(ego: EgoModus, taste: String, gedrueckt: bool) -> bool:
	if not laeuft or vorbei:
		return false
	if taste in FLUCHT_GESPERRT and flucht_sperre():
		if gedrueckt:
			spiel.melde("Weg hier! Erst zum Myriaden-HQ im Westen.", 1.5)
		return true
	if taste == "E" and nemesis != null and nemesis.ausschalten_taste(gedrueckt):
		return true   # 22.11. (Nemesis Teil 6): [E] halten am kampfunfähigen Benannten – endgültig ausschalten
	match taste:
		"C":
			if geheim:
				return false   # 20.11. (Paul): Überläufer – [C] wirft wieder das Ringfeld (ego_modus), die Sprengladung entfällt
			if gedrueckt:
				var v: Vector3 = ego._vorne()
				var grund := ladung_setzen(wall_fuer_ladung(ego._fuss2d(), ego.ziel_welt(), Vector2(v.x, v.z)))
				if grund != "":
					spiel.melde(grund, 2.0)
			return true
		"F":
			if geheim and gedrueckt and cp_vor_brakk(spiel.kommandant) >= 0:
				_cp_f = true   # 26.11. (Paul): Checkpoint für die Myriaden einnehmen
				return true
			if not gedrueckt and _cp_f:
				_cp_f = false
				_cp_brakk.fill(0.0)   # losgelassen: von vorn
				return true
			if gedrueckt:
				return sabotage_start()
			if not sabo.is_empty():
				sabotage_abbruch("[F] losgelassen")
				return true
	return false


## 20.11. (Paul): Überläufer – kleines Lichtmenü, das nach dem Schwarm-Funk zeigt, was jetzt neu geht (25 s).
func _male_lichtmenue(bild: Control, g: Vector2, Stil: GDScript) -> void:
	var zeilen: Array = [
		["[1]", "Myriaden-Fabrik bauen (%d) – nur in der Zone am Myriaden-HQ" % myr_preis()],
		["[C]", "Ringfeld werfen – der Ring bestimmt, welche Myriaden die Fabrik schickt"],
		["W", "alle %d s zieht eine Welle über die Checkpoints zur Technoclan-Basis" % int(w("myr_takt"))],
		["CP", "[F] am Checkpoint halten, dann beide %d s halten – der Schild des Technoclan-HQ fällt" % int(w("geheim_cp_sek"))],
	]
	var breite := minf(g.x - 32.0, 620.0)
	var r := Rect2((g.x - breite) / 2.0, g.y * 0.22, breite, 34.0 + zeilen.size() * 24.0)
	var a := clampf((_lichtmenue_bis - zeit) / 2.0, 0.0, 1.0)
	bild.draw_rect(r, Color(0.04, 0.08, 0.12, 0.88 * a))
	bild.draw_rect(r, Color(LICHT_MENUE, a), false, 2.0)
	Stil.schreibe(bild, r.position + Vector2(14, 20), "LICHTMENÜ · NEU FÜR DEN ÜBERLÄUFER", 16, Color(LICHT_MENUE, a))
	for i in zeilen.size():
		var y := r.position.y + 44.0 + i * 24.0
		Stil.schreibe(bild, Vector2(r.position.x + 14, y), str(zeilen[i][0]), 16, Color(Stil.GOLD, a))
		Stil.schreibe(bild, Vector2(r.position.x + 58, y), str(zeilen[i][1]), 15, Color(Stil.TEXT, a))


## Anzeige unter der Uhr: Sprengladungen, „In Deckung“, Sabotage-Fortschritt und Hinweise.
## 25.11. (Paul): Wird ein Benannter geborgen und steht Brakk noch nicht bei ihm, steht der Ausschalten-Hinweis groß
## neben der Figur – mit der Zeit, die noch bleibt. (Steht er bei ihm, gilt der Hinweis mit Ring in der Bildmitte.)
func _male_bergungen(bild: Control, g: Vector2, ego: EgoModus, Stil: GDScript) -> void:
	if nemesis == null or spiel.hd == null or spiel.hd.kamera == null or spiel.kommandant == null:
		return
	for h: Dictionary in nemesis.bergung_hinweise():
		var e := h["einheit"] as Einheit
		if e.position.distance_to(spiel.kommandant.position) > Werte.NEMESIS_HINWEIS_WEIT * Werte.ZELLE or not ego.im_blick(e):
			continue
		var s: Vector2 = spiel.hd.kamera.unproject_position(ego._zu3d(e.position, 0.9 + float(e.get_meta("hebt_ab", 0.0))))
		var farbe: Color = (h["farbe"] as Color).lightened(0.2)
		var oben := tr("[E] halten – endgültig ausschalten")
		var unten := tr("%s · Bergung in %s s – heran!") % [str(h["name"]), ("%.1f" % float(h["rest"])).replace(".", ",")]
		var breit := maxf(Stil.breite(oben, 20), Stil.breite(unten, 14)) + 24.0
		var links := s.x + 46.0
		if links + breit > g.x * 0.8:
			links = s.x - 46.0 - breit   # rechts läge es auf der Ring-Anzeige: links neben die Figur
		var r := Rect2(clampf(links, 12.0, maxf(12.0, g.x - breit - 12.0)), clampf(s.y - 28.0, 12.0, g.y - 68.0), breit, 56.0)
		bild.draw_line(s, Vector2(r.position.x if r.position.x > s.x else r.end.x, r.get_center().y), Color(farbe, 0.8), 2.0)
		bild.draw_rect(r, Color(0.03, 0.03, 0.07, 0.88))
		bild.draw_rect(r, farbe, false, 2.0)
		Stil.schreibe(bild, r.position + Vector2(12.0, 19.0), oben, 20, farbe)
		Stil.schreibe(bild, r.position + Vector2(12.0, 42.0), unten, 14, Color(0.86, 0.93, 1.0))


func hud(bild: Control, g: Vector2, ego: EgoModus) -> void:
	var Stil := preload("res://scripts/ui/ui_stil.gd")
	if geheim:
		# 20.11.: Überläufer – Bauliste der Myriaden-Fabriken links
		var by := roundf(g.y * 0.3)
		Stil.schreibe(bild, Vector2(24, by), "MYRIADEN · Zone links", 14, MYR_FARBE)
		Stil.schreibe(bild, Vector2(24, by + 18.0), "[1] Fabrik  %d   (%d stehen)" % [myr_preis(), myr_fabriken.size()], 14, Stil.TEXT if spiel.budget >= myr_preis() else Stil.TEXT_BLASS)
		Stil.schreibe(bild, Vector2(24, by + 35.0), "[C] Ringfeld: der Ring bestimmt die Einheit", 14, Stil.TEXT_BLASS)
		var zeile := 0
		var kf: BrakkFortschritt = spiel.kommandant.fortschritt if spiel.kommandant != null else null
		if kf != null:
			for ring: String in kf.ringe:
				var typ := str(MYR_RING.get(ring, "hund"))
				var wert := wf("myr_wert") * (1.0 + wf("myr_ring_stufe") / 100.0 * float(maxi(0, kf.ring_stufe(ring) - 1)))
				Stil.schreibe(bild, Vector2(24, by + 54.0 + zeile * 17.0), "%s → %s" % [str(BrakkFortschritt.RINGE[ring]["name"]), myr_takt_text(typ, wert)],
					13, Einheit.ABZEICHEN.get(ring, Stil.TEXT) if kf.felder.has(ring) else Stil.TEXT_BLASS)
				zeile += 1
		Stil.schreibe(bild, Vector2(24, by + 54.0 + zeile * 17.0), "ohne Feld → %s" % myr_takt_text("hund", wf("myr_wert") * wf("myr_ohne_ring") / 100.0), 13, Stil.TEXT_BLASS)
	if geheim and zeit < _lichtmenue_bis:
		_male_lichtmenue(bild, g, Stil)
	var y := 116.0 + 52.0
	var m := Vector2(g.x / 2.0, y)
	if am_terminal(ego._fuss2d()):
		y += 22.0
	# Sprengladungen: Kästchen links unten über der Lebensanzeige
	var lx := 24.0
	var ly := g.y - 128.0
	if not geheim:   # 20.11. (Paul): im Überläufer-Verlauf liegt [C] wieder auf dem Ringfeld
		Stil.schreibe(bild, Vector2(lx, ly - 10.0), "SPRENGLADUNGEN [C]", 13, Stil.TEXT_BLASS)
	for i in (int(w("spreng_max")) if not geheim else 0):
		var r := Rect2(lx + i * 26.0, ly, 20.0, 14.0)
		bild.draw_rect(r, Color(0.04, 0.05, 0.08, 0.75))
		if i < ladungen:
			bild.draw_rect(r.grow(-2.0), Color("ff9a3d"))
			bild.draw_rect(Rect2(r.position + Vector2(8, -4), Vector2(4, 4)), Color("ffe14d"))
		bild.draw_rect(r, Stil.GOLD if i < ladungen else Stil.RAHMEN, false, 1.5)
	# In Deckung: Schild-Symbol
	if in_deckung:
		var s := Vector2(lx + 10.0, ly - 40.0)
		var pts := PackedVector2Array([s + Vector2(-9, -10), s + Vector2(9, -10), s + Vector2(9, 0), s + Vector2(0, 11), s + Vector2(-9, 0)])
		bild.draw_colored_polygon(pts, Color("6ee6ff", 0.35))
		pts.append(pts[0])
		bild.draw_polyline(pts, Color("6ee6ff"), 2.0)
		Stil.schreibe(bild, s + Vector2(16, 0), "In Deckung", 16, Color("6ee6ff"))
	# 22.11. (Nemesis Teil 3): markiert (alle Trupps kennen deinen Ort) bzw. im Feuerkegel (langsamer)
	if zeit < markiert_bis:
		var blink := 0.6 + 0.4 * sin(zeit * 10.0)
		Stil.schreibe_mittig(bild, Vector2(m.x, y), "MARKIERT – alle Trupps wissen, wo du bist (%d s)" % ceili(markiert_bis - zeit), 16, Color(Color("ffa21c"), blink))
		y += 20.0
	if nemesis != null and nemesis.faehigkeiten != null and nemesis.faehigkeiten.tempo_faktor() < 1.0:
		Stil.schreibe_mittig(bild, Vector2(m.x, y), "Unterdrückungsfeuer – raus aus dem Kegel!", 16, Color("ff9a3d"))
		y += 20.0
	# 22.11. (Nemesis Teil 6): [E] halten am Kampfunfähigen – Hinweis bzw. Fortschritt
	var aus: Dictionary = nemesis.ausschalten_hinweis() if nemesis != null else {}
	if not aus.is_empty():
		# 25.11. (Paul): groß unter dem Fadenkreuz, Fortschrittsring darum, in der Farbe der Benannten
		var farbe: Color = (aus["farbe"] as Color).lightened(0.2)
		var mitte := g / 2.0
		var anteil := clampf(float(aus["anteil"]), 0.0, 1.0)
		bild.draw_arc(mitte, 44.0, 0.0, TAU, 48, Color(0.02, 0.02, 0.05, 0.65), 9.0, true)
		bild.draw_arc(mitte, 44.0, 0.0, TAU, 48, Color(farbe, 0.35), 3.0, true)
		if anteil > 0.0:
			bild.draw_arc(mitte, 44.0, -PI / 2.0, -PI / 2.0 + TAU * anteil, 48, farbe, 7.0, true)
		var tafel_breit := Stil.breite(str(aus["text"]), 24) + 32.0
		var tafel := Rect2(mitte.x - tafel_breit / 2.0, mitte.y + 64.0, tafel_breit, 68.0)
		bild.draw_rect(tafel, Color(0.03, 0.03, 0.07, 0.9))   # dunkler Grund: der Umriss des Benannten liegt oft genau dahinter
		bild.draw_rect(tafel, farbe, false, 2.0)
		for zeile: Array in [[str(aus["text"]), 84.0, 24], [str(aus["name"]), 114.0, 18]]:
			var ort := mitte + Vector2(0, float(zeile[1]))
			Stil.schreibe_mittig(bild, ort + Vector2(2, 2), str(zeile[0]), int(zeile[2]), Color(0, 0, 0, 0.85))
			Stil.schreibe_mittig(bild, ort, str(zeile[0]), int(zeile[2]), farbe)
	# 25.11. (Paul): Hologramm-Tafeln – Elite-Auftritt, Feldbeförderung, Vertreibung, Wiedersehen (das Spiel läuft weiter)
	y += tafeln.male(bild, m.x, y)
	_male_bergungen(bild, g, ego, Stil)
	if herausforderer != null and herausforderer.anvisiert != Vector2.INF and ego != null:
		# C2: er zielt auf Brakk – Warnung mit Pfeil, der in seine Richtung zeigt (oben = vor Brakk)
		var zu := herausforderer.anvisiert - ego._fuss2d()
		var w := Vector2(-sin(ego.gier), -cos(ego.gier)).angle_to(zu)
		var puls := Color(Color("ff3b3b"), 0.75 + 0.25 * sin(float(Time.get_ticks_msec()) / 60.0))
		Stil.schreibe_mittig(bild, Vector2(m.x, y + 4.0), tr("ANVISIERT"), 26, puls)
		var p := Vector2(m.x, y + 40.0)
		var spitze := Vector2(0, -16).rotated(w)
		bild.draw_colored_polygon(PackedVector2Array([p + spitze, p + spitze.rotated(2.5) * 0.7, p + spitze.rotated(-2.5) * 0.7]), puls)
		y += 62.0
	if herausforderer != null and herausforderer.saeule_ueber_brakk():
		Stil.schreibe_mittig(bild, Vector2(m.x, y + 4.0), "Lichtsäule über dir – raus aus dem Kreis!", 22, Color(Color("d6b3ff"), 0.7 + 0.3 * sin(float(Time.get_ticks_msec()) / 70.0)))
		y += 28.0
	if zuflucht != null and zuflucht.hud_zeile() != "":
		Stil.schreibe_mittig(bild, Vector2(m.x, y), zuflucht.hud_zeile(), 18, BrakkZuflucht.KREUZ)   # E4
		y += 22.0
	if herausforderer != null and herausforderer.typ != null and herausforderer.zustand == "duell" and herausforderer.hud_zeile() != "":
		Stil.schreibe_mittig(bild, Vector2(m.x, y), herausforderer.hud_zeile(), 18, NemesisHerausforderer.DRUCK_UMRISS if herausforderer.druck else Color("9dff8a"))   # C2: z. B. im Gel; G2-3: DRUCK, Boden brennt
		y += 22.0
	if herausforderer != null and herausforderer.gel_rest > 0.0:
		Stil.schreibe_mittig(bild, Vector2(m.x, y), "Gebremst – Vergeltung mit dem Gelring", 16, Color("c9a2ff"))
		y += 20.0
	if herausforderer != null and herausforderer.marke_rest > 0.0:
		Stil.schreibe_mittig(bild, Vector2(m.x, y), "Markiert – sein nächster Treffer sitzt härter", 16, Color("c9a2ff"))
		y += 20.0
	# Zünder
	for zu: Dictionary in zuender:
		Stil.schreibe_mittig(bild, Vector2(m.x, y), "Sprengladung: %d s" % ceili(float(zu["rest"])), 16, Color("ff9a3d"))
		y += 20.0
	# Sabotage
	var k: Kommandant = spiel.kommandant
	if not sabo.is_empty():
		var anteil := clampf(float(sabo["t"]) / maxf(0.1, wf("sabotage_halten")), 0.0, 1.0)
		var r := Rect2(m.x - 120.0, y - 8.0, 240.0, 16.0)
		bild.draw_rect(r, Color(0.04, 0.05, 0.08, 0.8))
		bild.draw_rect(Rect2(r.position, Vector2(r.size.x * anteil, r.size.y)), Color("ff5a6e", 0.8))
		bild.draw_rect(r, Color("ff5a6e"), false, 1.5)
		Stil.schreibe_mittig(bild, r.get_center() + Vector2(0, -1), "Sabotage – [F] halten", 14, Color.WHITE)
		y += 24.0
	elif cp_vor_brakk(k) >= 0:   # 26.11. (Paul): Überläufer – Checkpoint mit [F] einnehmen
		var i := cp_vor_brakk(k)
		if _technoclan_nah(karte.mitte(karte.checkpoints[i]), 2.0):
			Stil.schreibe_mittig(bild, Vector2(m.x, y), tr("Technoclan am Checkpoint – erst freikämpfen"), 16, Color("ff9a3d"))
			y += 20.0
		elif _cp_f:
			var r := Rect2(m.x - 120.0, y - 8.0, 240.0, 16.0)
			bild.draw_rect(r, Color(0.04, 0.05, 0.08, 0.8))
			bild.draw_rect(Rect2(r.position, Vector2(r.size.x * clampf(float(_cp_brakk[i]) / CP_HALTEN_SEK, 0.0, 1.0), r.size.y)), Color(CP_FARBE, 0.85))
			bild.draw_rect(r, CP_FARBE, false, 1.5)
			Stil.schreibe_mittig(bild, r.get_center() + Vector2(0, -1), tr("Checkpoint – [F] halten"), 14, Color.WHITE)
			y += 24.0
		else:
			Stil.schreibe_mittig(bild, Vector2(m.x, y), tr("[F] halten: Checkpoint für die Myriaden"), 16, CP_FARBE)
			y += 20.0
	elif k != null and fabrik_an_rueckseite(k.position) != Karte.KEINE:
		Stil.schreibe_mittig(bild, Vector2(m.x, y), "[F] halten: Fabrik sabotieren", 16, Stil.GOLD)
		y += 20.0
	elif ladungen > 0 and k != null:
		var v: Vector3 = ego._vorne()
		if wall_fuer_ladung(ego._fuss2d(), ego.ziel_welt(), Vector2(v.x, v.z)) != Karte.KEINE:
			Stil.schreibe_mittig(bild, Vector2(m.x, y), "[C] Sprengladung setzen", 16, Stil.GOLD)


# ------------------------------------------------------------------ Darstellung (HD, Platzhalter)

func _3d_pflegen() -> void:
	var hd: HdAnsicht = spiel.hd
	if hd == null:
		return
	if _knoten3d.is_empty():
		if terminal != Karte.KEINE:
			# 20.11. (Paul, Nachtrag): Ringterminal – 2×2-Sockel in Magenta, darüber ein stehender goldener Ring, der sich dreht
			# und heller leuchtet, je näher der Anführer kommt
			var mitte := Vector3(float(terminal.x) + 1.0, 0.0, float(terminal.y) + 1.0)
			_knoten3d.append(_kasten3d(hd, Vector3(1.9, 0.3, 1.9), Color("ff3df2"), mitte + Vector3(0, 0.15, 0)))
			_knoten3d.append(_kasten3d(hd, Vector3(1.5, 0.12, 1.5), Color("2a1640"), mitte + Vector3(0, 0.36, 0)))
			for ecke: Vector2 in [Vector2(-0.8, -0.8), Vector2(0.8, -0.8), Vector2(-0.8, 0.8), Vector2(0.8, 0.8)]:
				_knoten3d.append(_kasten3d(hd, Vector3(0.18, 0.7, 0.18), Color("ff3df2"), mitte + Vector3(ecke.x, 0.35, ecke.y)))
			_terminal_ring = MeshInstance3D.new()
			var t := TorusMesh.new()
			t.inner_radius = 0.42
			t.outer_radius = 0.6
			_terminal_ring.mesh = t
			_terminal_mat = _leucht(Color("ffe14d"), 0.95)
			_terminal_ring.material_override = _terminal_mat
			_terminal_ring.position = mitte + Vector3(0, 1.25, 0)
			_terminal_ring.rotation = Vector3(PI / 2.0, 0, 0)   # steht aufrecht
			hd.add_child(_terminal_ring)
			_knoten3d.append(_terminal_ring)
			var stein := MeshInstance3D.new()
			var kugel := SphereMesh.new()
			kugel.radius = 0.16
			kugel.height = 0.32
			stein.mesh = kugel
			stein.material_override = _leucht(Color("7fe0ff"), 0.95)
			stein.position = mitte + Vector3(0, 1.25, 0)
			hd.add_child(stein)
			_knoten3d.append(stein)
	for m: Dictionary in medkits:
		if m["knoten"] == null:   # 20.11.: auch später verstreute Med-Kits; Med-Kit – weißes Paket mit rotem Kreuz, Schatten, pulsiert
			var z: Vector2i = m["zelle"]
			var kn := Node3D.new()
			hd.add_child(kn)
			kn.position = Vector3(float(z.x) + 0.5, 0.0, float(z.y) + 0.5)
			var schatten := MeshInstance3D.new()
			var scheibe := CylinderMesh.new()
			scheibe.top_radius = 0.34
			scheibe.bottom_radius = 0.34
			scheibe.height = 0.01
			schatten.mesh = scheibe
			var sm := StandardMaterial3D.new()
			sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			sm.albedo_color = Color(0, 0, 0, 0.35)
			schatten.material_override = sm
			schatten.position = Vector3(0, 0.01, 0)
			kn.add_child(schatten)
			var paket := Node3D.new()
			paket.name = "Paket"
			kn.add_child(paket)
			_kasten3d(paket, Vector3(0.42, 0.28, 0.42), Color("f2f2f2"), Vector3(0, 0.14, 0))
			_kasten3d(paket, Vector3(0.32, 0.03, 0.09), Color("ff3030"), Vector3(0, 0.295, 0))
			_kasten3d(paket, Vector3(0.09, 0.03, 0.32), Color("ff3030"), Vector3(0, 0.295, 0))
			_kasten3d(paket, Vector3(0.24, 0.07, 0.02), Color("ff3030"), Vector3(0, 0.14, 0.215))
			_kasten3d(paket, Vector3(0.07, 0.2, 0.02), Color("ff3030"), Vector3(0, 0.14, 0.215))
			m["knoten"] = kn
			_knoten3d.append(kn)
	var t_ms := Time.get_ticks_msec()
	for m: Dictionary in medkits:
		if m["knoten"] != null:
			var kn: Node3D = m["knoten"]
			kn.visible = bool(m["da"])
			var paket := kn.get_node_or_null("Paket") as Node3D
			if paket != null:
				var puls := 1.0 + 0.12 * sin(float(t_ms) / 180.0)
				paket.scale = Vector3(puls, puls, puls)
				paket.position.y = 0.06 + 0.04 * sin(float(t_ms) / 180.0)
	if _terminal_ring != null:
		_terminal_ring.rotation.y = float(t_ms) / 900.0
		var nah := 1.0
		if spiel.ego != null:
			var mitte2 := karte.mitte(terminal) + Vector2(Werte.ZELLE, Werte.ZELLE) * 0.5
			nah = clampf(1.0 - (spiel.ego._fuss2d().distance_to(mitte2) / Werte.ZELLE - 1.0) / 5.0, 0.0, 1.0)
		_terminal_mat.emission_energy_multiplier = 0.6 + 3.4 * nah + 0.4 * sin(float(t_ms) / 250.0) * nah
	while _schild3d.size() < schild_mitten.size():
		var p: Vector2 = schild_mitten[_schild3d.size()]
		var mi := MeshInstance3D.new()
		var kugel := SphereMesh.new()
		kugel.radius = SCHILD_RADIUS
		kugel.height = SCHILD_RADIUS * 1.2
		mi.mesh = kugel
		mi.material_override = _leucht(TECHNO_FARBE, 0.16)
		mi.position = Vector3(p.x / Werte.ZELLE, 0.0, (p.y - Werte.KARTE_OBEN) / Werte.ZELLE)
		hd.add_child(mi)
		_schild3d.append(mi)
	if not _schild3d.is_empty():
		(_schild3d[0] as Node3D).scale = Vector3.ONE * maxf(0.001, schild_auf)   # 20.11.: Verrat – der Schild schließt sich
		(_schild3d[0] as Node3D).visible = not hq_schild_aus
	_myr_3d(hd)
	# 20.11. (Paul): Heilturm am Myriaden-HQ – der echte Heilturm am Boden, pulsiert beim Heilen
	if heilturm != Karte.KEINE:
		if _heil3d == null:
			_heil3d = Node3D.new()
			hd.add_child(_heil3d)
			_heil3d.position = Vector3(float(heilturm.x) + 0.5, 0.0, float(heilturm.y) + 0.5)
			# 20.11. (Paul): der echte Heilturm (Bild aus TurmBild), am Boden aufgestellt
			var s := Sprite3D.new()
			s.texture = load(Werte.NEU + "tuerme/heil.png")
			s.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
			s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
			s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
			s.pixel_size = 1.4 / 64.0
			s.position = Vector3(0, (64.0 - 61.0 + 32.0 - 3.0) * s.pixel_size, 0)   # Fußpunkt (Pixel 61) auf den Boden
			_heil3d.add_child(s)
			_knoten3d.append(_heil3d)
		_heil3d.visible = not hq_eingenommen and not myr_hq_besetzt
		var sp := _heil3d.get_child(0) as Sprite3D
		if sp != null:
			sp.modulate = Color(0.75, 1.0, 0.8).lerp(Color.WHITE, 0.5 + 0.5 * sin(float(Time.get_ticks_msec()) / 120.0)) if heilt else Color.WHITE   # pulsiert beim Heilen
	# 20.11. (Paul): Rückseiten der Fabriken draußen sichtbar machen – dort sabotiert [F]
	for z: Vector2i in rueckseite:
		var r: Vector2i = rueckseite[z]
		if r == Karte.KEINE:
			continue
		if not _rueck3d.has(z):
			_rueck3d[z] = _kasten3d(hd, Vector3(0.8, 0.03, 0.8), Color("ff5a6e"), Vector3(float(r.x) + 0.5, 0.02, float(r.y) + 0.5))
		var rm: MeshInstance3D = _rueck3d[z]
		rm.visible = fabrik_hp.has(z) and not lahm.has(z)
		rm.transparency = 0.45 + 0.35 * sin(float(Time.get_ticks_msec()) / 300.0)
	# 20.11.: Sprengladungen am Boden (rot-gelbe Kästen), tickende Ladungen auf dem Wall (blinken), Trümmer, qualmende Türme
	# t_ms von oben
	for l: Dictionary in ladungen_boden:
		if l["knoten"] == null:
			var kn := Node3D.new()
			hd.add_child(kn)
			var p: Vector2 = l["pos"]
			kn.position = Vector3(p.x / Werte.ZELLE, 0.0, (p.y - Werte.KARTE_OBEN) / Werte.ZELLE)
			_kasten3d(kn, Vector3(0.3, 0.18, 0.22), Color("c8322a"), Vector3(0, 0.09, 0))
			_kasten3d(kn, Vector3(0.32, 0.04, 0.06), Color("ffe14d"), Vector3(0, 0.19, 0))
			l["knoten"] = kn
		(l["knoten"] as Node3D).rotation.y = float(t_ms % 4000) / 4000.0 * TAU
		if l.has("bis"):   # 26.11. (Paul): in der letzten LADUNG_AUSBLENDEN-Sekunde ausblenden
			var a := clampf((float(l["bis"]) - zeit) / LADUNG_AUSBLENDEN, 0.0, 1.0)
			for m: Node in (l["knoten"] as Node3D).get_children():
				if m is GeometryInstance3D:
					(m as GeometryInstance3D).transparency = 1.0 - a
	var hoch: float = hd.H
	for zu: Dictionary in zuender:
		if zu["knoten"] == null:
			var z: Vector2i = zu["zelle"]
			zu["knoten"] = _kasten3d(hd, Vector3(0.35, 0.2, 0.35), Color("ff3030"), Vector3(float(z.x) + 0.5, hoch + 0.1, float(z.y) + 0.5))
		(zu["knoten"] as Node3D).visible = int(float(t_ms) / (120.0 if float(zu["rest"]) < 1.0 else 250.0)) % 2 == 0
	while _truemmer3d.size() < truemmer.size():
		var z: Vector2i = truemmer[_truemmer3d.size()]
		_truemmer3d.append(_kasten3d(hd, Vector3(0.9, 0.25, 0.8), Color("3a3440"), Vector3(float(z.x) + 0.5, 0.12, float(z.y) + 0.5)))
	_fabrik_balken_pflegen(hd)
	_beute_3d(hd)
	_sabotage_3d(hd)
	_einnahme_3d(hd)
	for z: Vector2i in kern_aus:
		if not _qualm3d.has(z):
			_qualm3d[z] = _kasten3d(hd, Vector3(0.5, 0.5, 0.5), Color("50505a"), Vector3(float(z.x) + 0.5, hoch + 1.0, float(z.y) + 0.5))
		var q: Node3D = _qualm3d[z]
		q.position.y = hoch + 0.9 + 0.4 * sin(float(t_ms) / 300.0)
		q.rotation.y = float(t_ms % 2000) / 2000.0 * TAU
	for z: Vector2i in _qualm3d.keys():
		if not kern_aus.has(z):
			(_qualm3d[z] as Node3D).queue_free()
			_qualm3d.erase(z)


var _truemmer3d: Array = []
var _fabrik_getroffen := {}      # 25.11.: Fabrik -> Zeit des letzten Treffers
var _fabrik_balken := {}         # 25.11.: Fabrik -> [Grund, Füllung]
var _balken_bild: ImageTexture = null


## 25.11. (Paul): Lebensbalken über einer beschädigten Fabrik, im Stil der Truppenbalken (HdAnsicht._lebensbalken);
## FABRIK_BALKEN_SEK nach dem letzten Treffer blendet er aus.
func _fabrik_balken_pflegen(hd: HdAnsicht) -> void:
	for z: Vector2i in _fabrik_getroffen.keys():
		var zeigen := fabrik_hp.has(z) and zeit - float(_fabrik_getroffen[z]) < FABRIK_BALKEN_SEK
		if not _fabrik_balken.has(z):
			if not zeigen:
				continue
			if _balken_bild == null:
				var img := Image.create(48, 4, false, Image.FORMAT_RGBA8)
				img.fill(Color.WHITE)
				_balken_bild = ImageTexture.create_from_image(img)
			var neu: Array = []
			for i in 2:
				var s := Sprite3D.new()
				s.texture = _balken_bild
				s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
				s.shaded = false
				s.no_depth_test = true
				s.centered = false
				s.region_enabled = true
				s.pixel_size = 1.0 / 40.0
				s.render_priority = 20 + i
				s.modulate = Color(0, 0, 0, 0.7) if i == 0 else Color("7fe0ff")
				hd.add_child(s)
				neu.append(s)
			_fabrik_balken[z] = neu
		var paar: Array = _fabrik_balken[z]
		if not zeigen:
			for s: Node in paar:
				s.queue_free()
			_fabrik_balken.erase(z)
			_fabrik_getroffen.erase(z)
			continue
		var anteil := clampf(float(fabrik_hp[z]) / maxf(1.0, wf("fabrik_leben")), 0.0, 1.0)
		var oben: float = spiel.ego.fabrik_flaeche(z).end.y if spiel.ego != null else 1.45
		var ort := Vector3(float(z.x) + 0.5, oben + 0.08, float(z.y) + 0.5)
		var grund: Sprite3D = paar[0]
		var fuell: Sprite3D = paar[1]
		grund.position = ort
		fuell.position = ort
		grund.region_rect = Rect2(0, 0, 40, 4)
		grund.offset = Vector2(-20, 0)
		fuell.region_rect = Rect2(0, 0, maxf(1.0, 38.0 * anteil), 2)
		fuell.offset = Vector2(-19, 1)

var _rueck3d := {}               # 20.11. (Paul): Fabrik -> roter Streifen an ihrer Rückseite (hier [F] halten)
var _qualm3d := {}


func _explosion3d(z: Vector2i) -> void:
	var hd: HdAnsicht = spiel.hd
	if hd == null:
		return
	var mi := MeshInstance3D.new()
	var kugel := SphereMesh.new()
	kugel.radius = 0.6
	kugel.height = 1.2
	mi.mesh = kugel
	mi.material_override = _leucht(Color("ff9a3d"), 0.8)
	mi.position = Vector3(float(z.x) + 0.5, 0.6, float(z.y) + 0.5)
	hd.add_child(mi)
	var tw := mi.create_tween()
	tw.tween_property(mi, "scale", Vector3.ONE * 2.4, 0.35)
	tw.parallel().tween_property(mi, "transparency", 1.0, 0.35)
	tw.tween_callback(mi.queue_free)


func _leucht(farbe: Color, alpha: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(farbe, alpha)
	m.emission_enabled = true
	m.emission = farbe
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


func _kasten3d(eltern: Node3D, groesse: Vector3, farbe: Color, pos: Vector3) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = groesse
	m.mesh = box
	m.material_override = _leucht(farbe, 0.95)
	m.position = pos
	eltern.add_child(m)
	return m


# ------------------------------------------------------------------ Ende

## 20.11. (Paul): 15 Minuten überlebt → Sieg (Kameraflug der Ego-Sicht, dann die Übersicht); Brakk fällt → dieselbe Übersicht
## als Wertung. Darin Minuten, zerstörte Fabriken, Kills, Ringe und der Spielstil-Titel (Saboteur / Geist / Berserker).
func _ende(sieg: bool) -> void:
	if vorbei:
		return
	vorbei = true
	sabo = {}
	herausforderer.brakk_faellt()   # 26.11.: stand er noch, hat er das Duell gewonnen
	if arena != null:
		arena.brakk_gefallen()   # G2: Bossarena – keine Wertung, kein Bericht, nichts gespeichert
		return
	for t: Dictionary in trupps:
		taktik.ende(t)   # 26.11.: Bilanz der Trupps, die noch stehen
	nemesis.lauf_ende()   # 22.11.: Rang +1 für die, die Brakk hart zugesetzt oder ohne Bergung überstanden haben
	print("ORDER24 Ende: %s nach %.0f s · Sabotage %s · Kills %d · Deckung %d %% · Schaden an Brakk %s" % ["Sieg" if sieg else "Niederlage", zeit, str(sabotage), kills, roundi(100.0 * deckung_sek / maxf(1.0, zeit)), str(schaden_an_brakk)])
	spiel.befehl24_protokoll("ende", {"sieg": sieg, "sabotage": sabotage.duplicate(), "kills": kills, "wellen": wellen, "deckung_prozent": roundi(100.0 * deckung_sek / maxf(1.0, zeit))})   # 23.11.
	spiel.phase = 2
	spiel.loesche_sitzung()
	if sieg and spiel.ego != null:
		spiel.ego.sieg(zeit)
		var b: Dictionary = spiel.ego._sieg_bericht
		b.merge(bericht(true), true)
		return
	if not sieg:
		spiel.loesche_zwischenstand()
	var ebene := CanvasLayer.new()
	ebene.layer = 40
	add_child(ebene)
	var tafel := BrakkSieg.new()
	tafel.spiel = spiel
	tafel.bericht = bericht(sieg)
	ebene.add_child(tafel)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Ton.spiele(spiel, "alert", -4.0)


## Spielstil nach der Partie: viel Sabotage → Saboteur, viel in Deckung und wenig Kills → Geist, sonst Berserker.
func spielstil() -> Array:
	var fabriken := int(sabotage["fabriken"]) + int(sabotage["sabotiert"])
	var deckung := deckung_sek / maxf(1.0, zeit)
	if fabriken + int(int(sabotage["waelle"]) / 2.0) >= 3:
		return ["Saboteur", "%d Fabriken zerstört oder sabotiert, %d Erdwälle gesprengt" % [fabriken, int(sabotage["waelle"])]]
	if deckung >= 0.6 and kills < 25:
		return ["Geist", "%d %% der Zeit in Deckung, nur %d Kills" % [roundi(deckung * 100.0), kills]]
	return ["Berserker", "%d Technoclan-Truppen ausgeschaltet" % kills]


## Bericht für BrakkSieg (gleiches Format wie BrakkFortschritt.sieg_bericht, Kopf und Höhepunkte für Befehl 24).
func bericht(sieg: bool) -> Dictionary:
	var k: Kommandant = spiel.kommandant
	var b: Dictionary = {"anfuehrer": "brakk", "stufe": 1, "ringe": [], "anteile": {}, "quellen": {}, "datum": Time.get_date_string_from_system()}
	if k != null and k.fortschritt != null:
		b = k.fortschritt.sieg_bericht(spiel, zeit)
	var stil := spielstil()
	b["kopf"] = ("ÜBERLÄUFER · BEFEHL 24 GEBROCHEN" if geheim_sieg else "BEFEHL 24 ÜBERSTANDEN") if sieg else "GEFALLEN · %s ÜBERLEBT" % _uhr(zeit)
	b["unterzeile"] = "Das Technoclan-HQ ist gefallen – nach %s." % _uhr(zeit) if geheim_sieg else "%s gegen den Technoclan überstanden." % _uhr(zeit)
	b["titel"] = stil[0]
	b["titel_grund"] = stil[1]
	b["sekunden"] = zeit
	b["leben"] = int(k.leben) if k != null else 0
	b["max_leben"] = int(k.max_leben) if k != null else 0
	var an: Dictionary = b.get("anteile", {})
	b["anteile"] = {"brakk": float(an.get("brakk", 0.0)), "truppen": 0.0, "tuerme": 0.0}   # Truppen und Türme sind hier der Gegner
	b["ohne_anteile"] = true   # 20.11. (Paul): die Anteile-Balken braucht es hier nicht
	b["hoehepunkte"] = [
		["Überlebt", _uhr(zeit) if wf("ueberleben_sek") <= 0.0 else "%s von %s" % [_uhr(zeit), _uhr(wf("ueberleben_sek"))]],
		["Fabriken zerstört / sabotiert", "%d / %d" % [int(sabotage["fabriken"]), int(sabotage["sabotiert"])]],
		["Kills", str(kills)],
		["Ringe", str((b.get("ringe", []) as Array).size())],
		["Erdwälle gesprengt · in Deckung", "%d · %d %%" % [int(sabotage["waelle"]), roundi(100.0 * deckung_sek / maxf(1.0, zeit))]],
	]
	if geheim:
		(b["hoehepunkte"] as Array).append(["Überläufer: Myriaden-Fabriken", str(myr_fabriken.size())])
	if herausforderer != null and (not herausforderer.zeiten.is_empty() or not herausforderer.ergebnisse.is_empty()):
		b["herausforderer"] = herausforderer.ergebnisse.duplicate()   # 26.11.: je Duell [Name, Ausgang]; leer = nicht gestellt
		b["sonde"] = herausforderer.sonde_vertrieben   # C3: Sonde 7 steht im Hangar auf dem Podest
	if nemesis != null:
		b["nemesis"] = nemesis.lauf_liste()   # 22.11. (Teil 7): Feldbeförderungen, Vertriebene, Ausgeschaltete
		b["aufstiege"] = nemesis.aufstiege()   # C1: im Hangar treten sie vor
		if not sieg:
			b["nemesis_tod"] = nemesis.tod_bericht()   # Deathscreen „Erledigt von …“ (leer: kein Soldat – bisheriger Schluss)
	if bool(w("gebiete")):
		b["gebiete"] = gebiet_zahlen.duplicate(true)   # E: Kills und Schaden je Gebiet
	return b


func _exit_tree() -> void:
	for t: TechnoZiel in _ziele.values():
		t.free()
	_ziele.clear()
	if is_instance_valid(karte):
		karte.sicht_eigenes_feld = false
		karte.ziel_wall_sichtbar = false
	if brakk_ziel != null:
		spiel.gegner.erase(brakk_ziel)
		brakk_ziel.free()
		brakk_ziel = null


# ------------------------------------------------------------------ Stellvertreter

## Brakk aus Sicht der Verteidigung: steht in spiel.gegner, läuft nicht selbst, Schaden geht an Brakk.
class BrakkZiel extends Gegner:
	var o24: Order24

	func nimm_schaden(menge: float, _dauer: bool = false) -> void:
		if spiel.schadensquelle == "fabrik:-1,-1" or str(spiel.brakk_quelle) != "":
			return   # Brakks eigene Treffer (Druckwelle, Säule …)
		var k: Kommandant = spiel.kommandant
		if k != null and not k.gefallen:
			var quelle := str(spiel.schadensquelle).get_slice(":", 0)
			var anteil := o24.wf("brakk_schaden") / 100.0 * (o24.wf("sabotage_schaden") / 100.0 if not o24.sabo.is_empty() else 1.0)   # 20.11. (Paul): beim Sabotieren verwundbarer
			anteil *= 1.0 + o24.wf("hq_aggro_schaden") / 100.0 * o24.hq_naehe()   # 20.11. (Paul): je näher am Technoclan-HQ, desto gefährlicher
			if quelle.begins_with("herausforderer"):
				anteil = 1.0   # 26.11. (Paul): seine Treffer sind fest – keine Regeln der Verteidigung
				if o24.herausforderer != null:
					anteil *= o24.herausforderer.treffer_mal(menge)   # Vergeltung mit einem Ring
			o24.schaden_an_brakk[quelle] = float(o24.schaden_an_brakk.get(quelle, 0.0)) + menge * anteil
			if quelle.begins_with("herausforderer"):
				o24.herausforderer.zaehle_treffer(menge * anteil)   # G2: Zählung je Angriffsart
			o24.gebiet_zaehlen("schaden", menge * anteil)   # E: je Gebiet
			var vor := k.leben
			k.nimm_schaden(menge * anteil)
			# 22.11. (Paul): Nemesis – der Schütze steht hinter „#“ in der Quelle (Einheit._auf_brakk)
			var q := str(spiel.schadensquelle)
			if o24.nemesis != null and q.contains("#"):
				var id := int(q.get_slice("#", 1))
				o24.nemesis.brakk_getroffen(id, maxf(0.0, vor - maxf(k.leben, 0.0)))
				if k.gefallen or k.leben <= 0.0:
					o24.nemesis.brakk_erledigt(id)

	func kommender_weg(_hoechstens: int) -> Array[Vector2i]:
		return []

	func rest_weg() -> int:
		return 1 << 20

	func plane_neu() -> void:
		pass


## Technoclan-Truppe, Fabrik oder Turmkern aus Sicht von Brakks Waffen.
class TechnoZiel extends Gegner:
	var o24: Order24
	var einheit: Einheit = null
	var zelle := Karte.KEINE
	var art := ""

	func nimm_schaden(menge: float, _dauer: bool = false) -> void:
		if not _tot:
			o24.treffer(self, menge)

	func kommender_weg(_hoechstens: int) -> Array[Vector2i]:
		return []

	func plane_neu() -> void:
		pass
