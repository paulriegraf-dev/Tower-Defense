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
	"geheim_ab": 900,           # hält Brakk das Myriaden-HQ bis hierhin, beginnt der geheime Verlauf „Überläufer“ (0 = aus)
	"myr_takt": 30,             # Überläufer: Wellenzyklus der Myriaden-Fabriken
	"myr_wert": 60,             # Wert der Einheiten je Fabrik und Zyklus (Hund 10 → 6 Hunde, Fahne 75 → 1)
	"myr_bau_mal": 4,           # (alt: Baupreis = Einheitenpreis × so viel – seit dem Ringfeld-Umbau unbenutzt)
	"myr_fabrik_preis": 150,    # 20.11. (Paul): es gibt nur noch EINE Myriaden-Fabrik zu diesem Preis – was sie baut, bestimmt das Ringfeld
	"myr_ohne_ring": 50,        # Prozent des Werts, solange die Fabrik in keinem Ringfeld steht (dann Hunde)
	"myr_ring_stufe": 30,       # Prozent mehr Wert je Ringstufe über 1 (Stufe 3: +60 %)
	"myr_kosten_anteil": 50,    # Prozent des Einheitenpreises kostet die Produktion je Zyklus
	"geheim_einkommen": 30,     # Beute je Zyklus
	"geheim_cp_sek": 30,        # beide Checkpoints so lange halten → Schild des Technoclan-HQ fällt
	"geheim_hq_leben": 3000,    # Leben des Technoclan-HQ
	"myr_rueck_sek": 10,        # so lange am besetzten Myriaden-HQ stehen (ohne Technoclan in der Nähe) = zurückerobert
	"flucht_sek": 45,           # Flucht: niemand jagt, die Truppen gehen in Stellung
	"jagd_start": 150,          # Sabotage bis hier (Verteidiger statisch), dann Jagd …
	"sabotage_ende_fabriken": 2,  # … oder schon, sobald so viele Fabriken zerstört sind
	"jagd_anteil": 80,          # Prozent der Truppen, die Jagdtrupps bilden (der Rest bleibt in den Nestern)
	"trupp_min": 3,             # Jagdtrupps zu 3–5
	"trupp_max": 5,
	"sicht_verlust": 8,         # so lange aus der Sicht, dann sucht der Trupp …
	"such_sek": 20,             # … so lange um den letzten Punkt, dann wieder Streife
	"welle_takt": 90,           # in der Jagd alle so viele Sekunden ein neuer Trupp aus den Schild-Fabriken
	"welle_takt_min": 40,       # 20.11. (Paul): Eskalation – der Takt sinkt bis hierhin …
	"eskalation_sek": 600,      # … über so viele Sekunden ab Jagdbeginn
	"welle_wachsen_sek": 120,   # alle so viele Sekunden ein Mann mehr je Welle
	"stufe2_ab": 420,           # ab hier kommen Wellen auf Fabrik-Stufe 2 …
	"faehigkeit_ab": 720,       # … ab hier auf Stufe 3 mit Fähigkeit (Minigun, Brandfeld …)
	"staerke_je_min": 4,        # Prozent mehr Schaden je Minute für neue Truppen
	"tempo_je_min": 2,          # Prozent schneller je Minute (höchstens +40 %)
	"leben_je_min": 10,         # Prozent mehr Leben je Minute – 20.11. (Paul): vorher 3 (Brakks Schaden wuchs viel schneller)
	"lager_neu_ab": 360,        # ab hier baut der Technoclan neue Lager (außer Brakks Sicht) …
	"lager_neu_takt": 150,      # … so oft …
	"lager_max": 8,             # … bis so viele Lager stehen
	"tore_ab": 480,             # ab hier setzt er Tore in seine Wälle Richtung Myriaden-HQ …
	"tore_takt": 60,            # … so oft …
	"tore_max": 4,              # … höchstens so viele
	"welle_groesse": 5,         # so groß (jede zerstörte Fabrik draußen: einer weniger, dauerhaft)
	"elite_jede": 3,            # jede so vielte Welle ein Elitetrupp aus genau drei
	"vorstoss": true,           # Technoclan darf das Myriaden-HQ einnehmen
	"vorstoss_start": 480,      # ab dann marschiert ein Jagdtrupp darauf
	"vorstoss_sek": 30,         # so lange muss er es halten
	"brakk_schaden": 45,        # Prozent: so viel Schaden der Verteidigung kommt bei Brakk an – 20.11. (Paul): 45 statt 25, Sabotieren war ohne Gefahr
	"sabotage_schaden": 150,    # Prozent: Schaden an Brakk, solange er sabotiert (ungeschützt an der Fabrik)
	"medkit_takt": 60,          # Med-Kit am Myriaden-HQ liegt so oft wieder, nach dessen Fall so oft eins verstreut
	"heilturm_prozent": 2,      # 20.11. (Paul): Heilturm am Myriaden-HQ – so viel Prozent von Brakks Leben je Sekunde …
	"heilturm_radius": 2,       # … in so vielen Feldern Umkreis, solange kein Technoclan in 3 Feldern ist
	"medkit_heilung": 15,       # Prozent von Brakks Leben – 20.11. (Paul): deutlich weniger (vorher 40)
	"fabriken_aussen": 4,       # Lager über die Karte verteilt (Fabrik, Stellungen, Turm)
	"fabriken_innen": 3,        # im Schild, für Brakk nicht erreichbar
	"stufe_innen": 2,           # 20.11. (Paul): Fabriken im Schild ausgebaut wie im normalen Spiel
	"besatzung_innen": 3,       # so viele Truppen hält jede Fabrik im Schild zur Verteidigung
	"praemie_kill": 5,          # 20.11. (Paul): kleines Kopfgeld je Kill …
	"kill_stufe": 2,            # … je so vielen Kills an derselben Stellung (am Boden: derselben Fabrik) sinkt es um 1 …
	"kill_frist": 30,           # … und ist nach so vielen Sekunden ohne Kill dort wieder voll (gegen stumpfes Abfarmen)
	"praemie_fabrik": 80,       # 20.11. (Paul): wenig Geld, dafür Erfahrung
	"praemie_stellung": 0,
	"praemie_wall": 0,
	"xp_fabrik": 20,            # Erfahrung für Brakk: zerstörte Fabrik …
	"xp_sabotage": 10,          # … sabotierte Fabrik
	"truppen_leben": 70,        # Prozent: Technoclan-Truppen in Befehl 24 schwächer (mehr Fabriken)
	"turm_wall_bonus": 2,       # Felder mehr Reichweite der Türme, solange Brakk auf den Erdwällen läuft
	"karte": "",                # "" = Zufall unter den Formationen aus [H], sonst eine Formation oder "phantom" (Verteidigungs-Phantom)
	# 20.11. (Paul, Ergänzung Befehl 24): Regeln nur in diesem Modus
	"stellungen_je_fabrik": 4,  # Stellungen um jede Fabrik außerhalb des Schilds
	"patrouille": 2,            # so viele Truppen je Fabrik außerhalb gehen Streife
	"produktion_sek": 12,       # Produktionszyklus: so oft liefert eine Fabrik Ersatz (normal 5)
	"tuerme": 6,                # Formtürme auf der Formation
	"lager_tuerme": 1,          # dazu je Lager ein Geschützturm
	"heiltuerme": 1,            # dazu Heiltürme mit Instandsetzung
	"fabrik_leben": 1500,       # Fabrik außerhalb: so viel Schaden bis zu Trümmern (Ladestrahl zählt mit 10 % davon)
	"sabotage_halten": 5,       # Sekunden [F] an der Rückseite halten – 20.11. (Paul): 5 statt 3, dafür brechen Treffer nicht mehr ab
	"sabotage_lahm": 60,        # so lange liefert eine sabotierte Fabrik nichts
	"praemie_sabotage": 40,
	"alarm_radius": 6,          # Felder: bei Angriff auf eine Fabrik laufen Truppen im Umkreis hin
	"pilot_verzug": 20,         # Sekunden nach einer Sabotage geht ein Pilot mit zwei Begleitern los
	"pilot_neu": 45,            # fällt der Pilot, dauert der nächste so lange
	"pilot_reparatur": 5,       # Sekunden Reparatur vor Ort
	"kern_leben": 400,          # Turmkern: leer geschossen fällt der Turm aus, bis ein Pilot ihn repariert (20.11., Paul)
	"spreng_drop": 5,           # Prozent: gefallene Truppe lässt eine Sprengladung fallen (Elite immer) – 20.11. (Paul): vorher 12
	"spreng_max": 3,            # höchstens so viele im Gepäck
	"spreng_zuender": 3,        # Sekunden Zünder
	"mobil_abkling": 125,       # 20.11. (Paul): Prozent Abklingzeit von Q und E (Anker, Lichttreppe, Lichtbrücke) – eher eingekesselt
	"geschoss_tempo": 75,       # 20.11. (Paul): Prozent Tempo von Laser und Battlesphären-Schüssen auf Brakk (Plasma bleibt) – reagierbar bei vielen Schützen
}
const SCHILD_RADIUS := 3.2       # Felder um das Technoclan-HQ, in die Brakk nicht hineinkommt
const SICHT_JAEGER := 7.0        # Felder: so weit sieht ein Jäger Brakk (mit freier Sicht)
const BAU_SCHADEN := 0.6         # Brakks Schüsse auf Gebäude wirken mit diesem Anteil
const LANZE_FABRIK := 0.10       # 20.11.: der Ladestrahl nimmt einer Fabrik mindestens 10 % ihres Lebens
const LADUNG_REICHWEITE := 1.8   # 20.11.: Felder – so weit vor Brakk darf der Erdwall für die Sprengladung liegen
const LADUNG_SCHADEN := 120.0    # 20.11.: Truppen dicht an der Sprengung
const ALARM_SEK := 20.0          # 20.11.: so lange bleiben alarmierte Truppen an der Fabrik
const TECHNO_FARBE := Color("b46cff")

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
var gesprengt := {}              # Wallfeld -> {"ausbau": int, "stufe": int, "faehigkeit": String, "rest": float}
var kern := {}                   # Turmfeld -> Leben des Kerns
var kern_aus := {}               # Turmfeld -> Sekunden bis er wieder läuft
var fabrik_hp := {}              # Fabrik außerhalb -> Leben
var rueckseite := {}             # Fabrik außerhalb -> Feld an ihrer Rückseite (Sabotage)
var routen := {}                 # Fabrik außerhalb -> Streifenweg (Felder)
var _streife := {}               # Einheit-ID -> Index im Streifenweg
var lahm := {}                   # sabotierte Fabrik -> Sekunden, bis sie von selbst wieder läuft
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
var weiter := false                # 20.11. (Paul): nach dem Classic-Sieg weitergespielt – die eigene Verteidigung ist der Gegner
static var test_werte := {}       # Tests: überschreiben das Regelpaket (main lädt die Karte beim Start neu)
var verrat: Verrat24 = null       # 20.11.: läuft gerade die Verrat-Sequenz?
var verrat_fertig := false
var _verraeter: Array = []        # die drei Technogunner der Sequenz
var schild_auf := 1.0             # 0..1 Kuppel des Schilds (schließt sich in der Sequenz)


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


func _karte_aufbauen() -> void:
	if weiter:
		_karte_uebernehmen()
		return
	var wahl := str(w("karte"))
	var formationen: Array[String] = Werte.ALARM_FORMATIONEN
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
		stellungen = spiel.formation_aufbauen(wahl, 0, 0, 0)   # 20.11.: Fabriken und Stellungen setzt Order24 (Lager)
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
				if gebaut >= int(w("stellungen_je_fabrik")):
					break
				if karte.inhalt(n) == Karte.WALL and not karte.ausbau.has(n) and not karte.stuetze_von.has(n):
					karte.baue_aus(n, Karte.STELLUNG)
					gebaut += 1
				elif karte.ist_bebaubar(n) and not _im_schild(karte.mitte(n)) and not karte.ist_basis(n):
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


## 20.11. (Paul): `fabriken_aussen` Lager über die Karte verteilt – zwischen Myriaden-Zone und Schild, abwechselnd oben,
## unten und in der Mitte, mindestens 4 Felder auseinander.
func _lager_verteilen() -> void:
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
				if not (karte.ist_bebaubar(c) or (karte.inhalt(c) == Karte.WALL and not karte.ausbau.has(c) and not karte.stuetze_von.has(c))) or _im_schild(karte.mitte(c)) or karte.ist_basis(c):
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
		if karte.feld[z] != Karte.WALL or karte.ausbau.has(z) or karte.stuetze_von.has(z) or _im_schild(karte.mitte(z)):
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
			if karte.turm_art.get(z, "") == "heil":
				heil += 1
			else:
				andere += 1
	for k: Array in kandidaten:
		var z: Vector2i = k[1]
		var form := str(k[2])
		var ist_heil := form == "heil"
		if (ist_heil and heil >= int(w("heiltuerme"))) or (not ist_heil and andere >= int(w("tuerme"))):
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
		if karte.feld.get(z, Karte.FREI) != Karte.WALL or karte.ausbau.has(z) or karte.stuetze_von.has(z) or _im_schild(karte.mitte(z)):
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
	# Heilturm mit Instandsetzung: fehlt eine Treppe, zwei Erdwälle schräg an einen Wall setzen
	for z: Vector2i in karte.feld.keys():
		if heil >= int(w("heiltuerme")):
			break
		if karte.feld.get(z, Karte.FREI) != Karte.WALL or karte.ausbau.has(z) or karte.stuetze_von.has(z) or _im_schild(karte.mitte(z)) or karte.freie_stuetzen(z).size() > 1:
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
		if karte.turm_form(z) == "heil":
			karte.baue_aus(z, Karte.TURM)
			karte.turm_stufe[z] = 3
			karte.turm_faehigkeit[z] = "instand"
			heil += 1
			gesetzt.append(z)
	for z: Vector2i in gesetzt:
		kern[z] = wf("kern_leben")


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
			kandidaten.append([p.distance_to(soll), z])
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
	_tuerme_pflegen(echt)
	_fabriken_pflegen(k, echt)
	_takt -= echt
	if _takt <= 0.0:
		_takt = 1.0
		_ablauf(k)   # 20.11.: Phasen, Jagdtrupps, Wellen, Vorstoß
	if jagd:
		if phase() == "vorstoss" and not hq_eingenommen:
			_vorstoss(echt)
	_medkits_pflegen(k, echt)
	_3d_pflegen()
	if wf("ueberleben_sek") > 0.0 and zeit >= wf("ueberleben_sek") and not geheim:
		_ende(true)
	# 20.11. (Paul): hält Brakk das Myriaden-HQ bis geheim_ab, beginnt der geheime Verlauf
	if not geheim and wf("geheim_ab") > 0.0 and zeit >= wf("geheim_ab") and not hq_eingenommen:
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


func uhr_anteil() -> float:
	if wf("ueberleben_sek") <= 0.0:
		return fmod(zeit, 60.0) / 60.0
	return clampf(zeit / maxf(1.0, wf("ueberleben_sek")), 0.0, 1.0)


# ------------------------------------------------------------------ Truppen der Fabriken (20.11.)

## 20.11.: So viele Truppen hält eine Fabrik am Leben (-1 = wie im normalen Spiel). Draußen Stellungen plus Streife, im Schild
## keine (von dort kommen nur die Jagdtrupps), die Pilotenfabrik der Batterie wie immer.
func truppen_limit(z: Vector2i) -> int:
	if not spiel.fabriken.has(z) or str(spiel.fabriken[z]["typ"]) == "pilot":
		return -1
	if not fabrik_hp.has(z):
		return int(w("besatzung_innen"))   # 20.11. (Paul): Verteidiger im Schild
	return int(w("stellungen_je_fabrik")) + int(w("patrouille"))


## 20.11.: Truppe einer Fabrik im Schild (Verteidiger der Basis, keine Jäger aus der Besatzung).
func _ist_innen(e: Einheit) -> bool:
	return spiel.fabriken.has(e.fabrik_zelle) and not fabrik_hp.has(e.fabrik_zelle) and str(spiel.fabriken[e.fabrik_zelle]["typ"]) != "pilot"


## 20.11. (Paul): Jede neue Technoclan-Truppe in Befehl 24 ist schwächer (truppen_leben), es gibt dafür mehr Fabriken.
func neue_einheit(e: Einheit) -> void:
	var minuten := zeit / 60.0   # 20.11. (Paul): Eskalation – nicht nur Leben, auch Schaden und Tempo wachsen mit der Zeit
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
	if bool(e.daten.get("elite", false)) or randf() * 100.0 < wf("spreng_drop"):
		ladungen_boden.append({"pos": e.position, "knoten": null})


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
		if not is_instance_valid(e) or e == spiel.kommandant or not (e as Einheit).visible or (e as Einheit).in_batterie():
			continue
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
		t.position = karte.mitte(z) + Vector2(0, -8)
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


## Brakk hat einen Stellvertreter getroffen.
func treffer(t: TechnoZiel, menge: float) -> void:
	if t.einheit != null:
		if not is_instance_valid(t.einheit):
			t._tot = true
			return
		var e: Einheit = t.einheit
		var war_stellung := e.in_stellung()
		var kg_ort := ("s:%s" % str(e.posten_zelle)) if war_stellung else ("f:%s" % str(e.fabrik_zelle))
		_alarm_auf_brakk(spiel.kommandant)   # 20.11. (Paul): wer angegriffen wird, ruft Hilfe
		e.nimm_schaden(menge)
		t.leben = e.leben
		if e.leben <= 0.0 or not is_instance_valid(e):
			t._tot = true
			sabotage["truppen"] = int(sabotage["truppen"]) + 1
			kills += 1
			_kopfgeld(kg_ort)
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
	print("ORDER24 Fabrik %s zerstört bei %.0f s" % [str(z), zeit])


var _kopfgeld_merk := {}   # Ort ("s:<Stellung>" / "f:<Fabrik>") -> [Kills in Folge, Zeit des letzten Kills]

## 20.11. (Paul): Kopfgeld je Kill. An derselben Stellung (am Boden: Truppen derselben Fabrik) sinkt es je kill_stufe Kills
## um 1; nach kill_frist Sekunden ohne Kill dort ist es wieder voll.
func _kopfgeld(ort: String) -> void:
	var voll := int(w("praemie_kill"))
	if voll <= 0:
		return
	var m: Array = _kopfgeld_merk.get(ort, [0, -999.0])
	var n := int(m[0]) if zeit - float(m[1]) < wf("kill_frist") else 0
	var betrag := maxi(0, voll - int(n / maxf(1.0, wf("kill_stufe"))))
	_kopfgeld_merk[ort] = [n + 1, zeit]
	if betrag > 0:
		sabotage["geld"] = int(sabotage["geld"]) + betrag
		spiel.budget += betrag   # ohne Meldung: sie würde wichtigere Zeilen verdrängen – das Budget oben zählt mit


func _praemie(was: String, betrag: int, text: String, xp: int = 0) -> void:
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
	for zu: Dictionary in zuender:
		if zu["zelle"] == z:
			return "Hier tickt schon eine Ladung."
	ladungen -= 1
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
		if is_instance_valid(x) and x != spiel.kommandant and (x as Einheit).position.distance_to(p) <= 1.3 * Werte.ZELLE:
			(x as Einheit).nimm_schaden(LADUNG_SCHADEN)
			if not is_instance_valid(x) or (x as Einheit).leben <= 0.0:
				kills += 1
				sabotage["truppen"] = int(sabotage["truppen"]) + 1
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
		if float(lahm[z]) <= 0.0:
			lahm.erase(z)
			spiel.repariere(z, true)
	for id: int in alarm.keys():
		if float((alarm[id] as Dictionary)["bis"]) < zeit or not is_instance_valid(instance_from_id(id)):
			alarm.erase(id)
	_piloten()


## Fabrik sabotiert: sabotage_lahm Sekunden kein Ersatz; pilot_verzug Sekunden später macht sich ein Pilot auf den Weg.
func sabotieren(z: Vector2i) -> void:
	karte.ausgefallen[z] = true
	karte.fortschritt.erase(z)
	lahm[z] = wf("sabotage_lahm")
	pilot_auftraege.append({"z": z, "ab": zeit + wf("pilot_verzug")})
	_praemie("sabotiert", int(w("praemie_sabotage")), "Fabrik sabotiert (%d s lahm)" % int(w("sabotage_lahm")), int(w("xp_sabotage")))
	Ton.spiele(spiel, "tc-arc", -4.0)
	karte.queue_redraw()
	print("ORDER24 Fabrik %s sabotiert bei %.0f s" % [str(z), zeit])


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
	if k == null or zeit < _druck_naechster:
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
	return not jaeger.has(e.get_instance_id()) and e != pilot and not eskorte.has(e) and not _ist_innen(e)


## Marschziel einer Truppe (KEINE = stehen bleiben): Begleiter folgen dem Piloten, Alarm geht vor, dann der Jagdtrupp,
## sonst ab der Sabotage-Phase die Streife um die eigene Fabrik (in der Flucht gehen alle nur in Stellung).
func marschziel(e: Einheit) -> Vector2i:
	if eskorte.has(e):
		return karte.zelle_bei(pilot.position) if is_instance_valid(pilot) else Karte.KEINE
	var id := e.get_instance_id()
	if alarm.has(id):
		return (alarm[id] as Dictionary)["ziel"]
	var nr := int(jaeger.get(id, -1))
	if nr >= 0 and nr < trupps.size():
		return _trupp_ziel(e, trupps[nr] as Dictionary)
	if _ist_innen(e):
		return Karte.KEINE   # 20.11. (Paul): Verteidiger bleiben in der Basis
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


func phase() -> String:
	if not laeuft:
		return "flucht"
	var p := phase_bei(zeit, int(sabotage["fabriken"]))
	if jagd and (p == "flucht" or p == "sabotage"):
		return "jagd"
	return p


func phase_text() -> String:
	match phase():
		"flucht":
			return "Flucht · zum Myriaden-HQ im Westen"
		"sabotage":
			return "Sabotage · Jagd in %s" % _uhr(maxf(0.0, wf("jagd_start") - zeit))
		"flucht", "sabotage":
			pass
	if geheim:
		return "Überläufer · %s" % geheim_text()
	# 20.11. (Paul): der Vorstoß aufs Myriaden-HQ bleibt geheim – angezeigt wird nur die Jagd
	return "Jagd · %d Trupps · Druck ×%.1f%s" % [trupps.size(), druck(), " · Myriaden-HQ gefallen" if hq_eingenommen else ""]


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


## Brakk gesehen: von einer Stellung (nicht in Deckung) oder von einem Jäger in Sichtweite – dann ist sein Ort bekannt.
func _bekannt_pflegen(k: Kommandant) -> void:
	if not in_deckung:
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
	var wachsen := floori(maxf(0.0, zeit - wf("jagd_start")) / maxf(10.0, wf("welle_wachsen_sek")))   # 20.11. (Paul): Eskalation
	var n := 3 if elite else maxi(1, int(w("welle_groesse")) + wachsen - int(sabotage["fabriken"]))
	var stufe := 4 if elite else (3 if zeit >= wf("faehigkeit_ab") else (2 if zeit >= wf("stufe2_ab") else 1))
	var neu: Array = []
	for i in n:
		var z: Vector2i = quellen[i % quellen.size()]
		var typ := str(spiel.fabriken[z]["typ"])
		var faehig := ""
		if stufe == 3:
			var liste: Array = (Werte.STUFE_3.get(typ, {}) as Dictionary).keys()
			if not liste.is_empty():
				faehig = str(liste.pick_random())
		neu.append(_neue_truppe(typ, z, stufe, faehig))
	_neuer_trupp(neu, "jagd")
	spiel.melde("Ein %s verlässt den Schild (%d)." % ["Elitetrupp" if elite else "Jagdtrupp", n], 3.0)
	print("ORDER24 Welle %d bei %.0f s: %d%s · Stufe %d · Takt %.0f s" % [wellen, zeit, n, " Elite" if elite else "", stufe, welle_takt_jetzt()])


## Ein Trupp: sieht er Brakk, jagt er; verliert er ihn sicht_verlust Sekunden, sucht er such_sek um den letzten Punkt,
## dann geht er wieder Streife. Auf Streife hört er auf Meldungen der Stellungen in der Nähe.
func _trupps_lenken(k: Kommandant) -> void:
	var bz := karte.zelle_bei(k.position)
	for t: Dictionary in trupps:
		t["mitglieder"] = (t["mitglieder"] as Array).filter(func(x: Variant) -> bool: return is_instance_valid(x))
		if (t["mitglieder"] as Array).is_empty() or str(t["modus"]) == "vorstoss":
			continue
		var sieht := false
		var schwerpunkt := Vector2.ZERO
		for e: Variant in t["mitglieder"]:
			var p: Vector2 = (e as Node2D).position
			schwerpunkt += p
			if p.distance_to(k.position) <= SICHT_JAEGER * Werte.ZELLE and karte.sicht_frei(p, k.position):
				sieht = true
		schwerpunkt /= float((t["mitglieder"] as Array).size())
		t["mitte"] = schwerpunkt
		if sieht:
			bekannt = bz
			bekannt_zeit = zeit
			t["zuletzt"] = bz
			t["gesehen"] = zeit
			t["modus"] = "jagd"
		elif str(t["modus"]) != "jagd" and zeit - bekannt_zeit < 1.5 and schwerpunkt.distance_to(karte.mitte(bekannt)) <= 10.0 * Werte.ZELLE:
			t["zuletzt"] = bekannt   # eine Stellung hat ihn gemeldet
			t["gesehen"] = zeit
			t["modus"] = "jagd"
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


## Ziel eines Jägers je nach Modus des Trupps: auffächern auf den letzten bekannten Ort (einer direkt, zwei über die Flanken),
## suchen um diesen Ort, Streife oder Vorstoß zum Myriaden-HQ.
func _trupp_ziel(e: Einheit, t: Dictionary) -> Vector2i:
	match str(t["modus"]):
		"vorstoss":
			return Werte.ANGRIFFS_ZELLE
		"streife":
			return _streifenziel(e)
		"suche":
			var id := e.get_instance_id()
			var s: Dictionary = _suchziel.get(id, {})
			if s.is_empty() or zeit >= float(s["bis"]) or karte.zelle_bei(e.position) == (s["z"] as Vector2i):
				s = {"z": _freies_feld_nahe(t["zuletzt"] as Vector2i, 4), "bis": zeit + 5.0}
				_suchziel[id] = s
			return s["z"]
	var ziel: Vector2i = t.get("ziel_ok", t["zuletzt"])
	var nr := (t["mitglieder"] as Array).find(e)
	if nr <= 0 or nr > 2:
		return ziel
	var von: Vector2 = t.get("mitte", e.position)
	var r := (karte.mitte(ziel) - von)
	if r.length() < Werte.ZELLE * 1.5:
		return ziel   # schon da: alle direkt
	var flanke := r.normalized().orthogonal() * (3.0 if nr == 1 else -3.0) * Werte.ZELLE
	var fz := _freies_feld_bei(karte.mitte(ziel) + flanke, ziel)
	return fz if not karte.einheiten_weg(karte.zelle_bei(e.position), fz).is_empty() else ziel


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
	return 1.0 + maxf(0.0, zeit - wf("jagd_start")) / maxf(60.0, wf("eskalation_sek"))


## Abstand der Jagdwellen: von welle_takt zum Jagdbeginn auf welle_takt_min nach eskalation_sek.
func welle_takt_jetzt() -> float:
	var t := clampf(maxf(0.0, zeit - wf("jagd_start")) / maxf(1.0, wf("eskalation_sek")), 0.0, 1.0)
	var takt := lerpf(wf("welle_takt"), wf("welle_takt_min"), t)
	return takt * (1.5 if geheim else 1.0)


## Neue Lager außer Brakks Sicht und Tore in den Wällen Richtung Myriaden-HQ.
func _eskalation() -> void:
	if zeit >= wf("lager_neu_ab") and zeit >= _lager_naechst and fabrik_hp.size() < int(w("lager_max")):
		_lager_naechst = zeit + wf("lager_neu_takt")
		_neues_lager()
	if zeit >= wf("tore_ab") and zeit >= _tore_naechst and tore_gesetzt < int(w("tore_max")):
		_tore_naechst = zeit + wf("tore_takt")
		_tor_setzen()


## Ein neues Lager (Fabrik, Stellungen, Turm) auf einem freien Feld, das Brakk gerade nicht sieht, nicht zu nah an ihm.
func _neues_lager() -> void:
	var k: Kommandant = spiel.kommandant
	var kandidaten: Array[Vector2i] = []
	for y in range(1, Werte.ZEILEN - 1):
		for x in range(Werte.ZONE_SPALTEN + 3, Werte.SPALTEN - 1):
			var z := Vector2i(x, y)
			if not karte.ist_bebaubar(z) or _im_schild(karte.mitte(z)) or karte.ist_basis(z) or _terminal_feld(z):
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
	_setze_fabrik(z, Werte.ALARM_TRUPPEN[randi() % Werte.ALARM_TRUPPEN.size()], 2 if zeit >= wf("stufe2_ab") else 1)
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
		if karte.feld[z] != Karte.WALL or karte.ausbau.has(z) or karte.stuetze_von.has(z) or _im_schild(karte.mitte(z)):
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
		vorstoss_anteil = minf(1.0, vorstoss_anteil + echt / maxf(1.0, wf("vorstoss_sek")))
		if vorstoss_anteil >= 1.0:
			if geheim:
				myr_hq_besetzt = true   # im Überläufer-Verlauf: kein zweiter Schild, Brakk kann es zurückholen
				spiel.melde("Der Technoclan hat das Myriaden-HQ besetzt – die Fabriken stehen still. Stell dich hin und hol es zurück!", 6.0)
			else:
				_zweites_hq()
	else:
		vorstoss_anteil = maxf(0.0, vorstoss_anteil - echt / maxf(1.0, wf("vorstoss_sek")) * 0.5)


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
		ladungen_boden.append({"pos": karte.mitte(frei[1]), "knoten": null})
	if frei.size() > 2:
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
			k.leben = minf(k.max_leben, k.leben + k.max_leben * wf("medkit_heilung") / 100.0)
			spiel.melde("Med-Kit: +%d %% Leben" % int(w("medkit_heilung")), 2.0)
			Ton.spiele(spiel, "ui-klick")
	if not _terminal_erklaert and k.position.distance_to(hq_mitte()) <= 3.5 * Werte.ZELLE:
		_terminal_erklaert = true   # 20.11. (Paul): Ankunft an der Zuflucht
		funken([
			["BRAKK", "Das Lichtterminal im Myriaden-HQ läuft noch – gerade so. Mit Beute hole ich mir hier Ringe: [F] am HQ.", ""],
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
		spiel.budget += int(w("geheim_einkommen"))
		if not myr_hq_besetzt:
			_myr_welle()
	# Brakk nimmt Checkpoints ein (er gehört jetzt zu den Myriaden)
	for i in karte.checkpoints.size():
		var cp: Vector2i = karte.checkpoints[i]
		if karte.cp_feind[i]:
			_cp_brakk[i] = 0.0
			continue
		if karte.zelle_bei(k.position).distance_to(cp) <= 1.0 and not _technoclan_nah(karte.mitte(cp), 2.0):
			_cp_brakk[i] += echt
			if _cp_brakk[i] >= Werte.EINNAHME_SEK:
				_cp_brakk[i] = 0.0
				spiel.checkpoint_erreicht(i)
				spiel.melde("Checkpoint %d eingenommen." % (i + 1), 3.0)
		else:
			_cp_brakk[i] = maxf(0.0, _cp_brakk[i] - echt)
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
## Guthaben hergibt (der Rest bleibt stehen) – so zählt ein Fahnenträger nicht wie ein Hund. Die Produktion kostet Beute.
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
			spiel.melde("Zu wenig Beute für die Myriaden-Fabrik (%s): %d nötig." % [str(Werte.GEGNER[typ]["name"]), kosten], 3.0)
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
		return "Zu wenig Beute: %d nötig." % preis
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
func ego_taste(ego: EgoModus, taste: String, gedrueckt: bool) -> bool:
	if not laeuft or vorbei:
		return false
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
		["CP", "beide Checkpoints %d s halten – dann fällt der Schild des Technoclan-HQ" % int(w("geheim_cp_sek"))],
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
	var hoch: float = hd.H
	for zu: Dictionary in zuender:
		if zu["knoten"] == null:
			var z: Vector2i = zu["zelle"]
			zu["knoten"] = _kasten3d(hd, Vector3(0.35, 0.2, 0.35), Color("ff3030"), Vector3(float(z.x) + 0.5, hoch + 0.1, float(z.y) + 0.5))
		(zu["knoten"] as Node3D).visible = int(float(t_ms) / (120.0 if float(zu["rest"]) < 1.0 else 250.0)) % 2 == 0
	while _truemmer3d.size() < truemmer.size():
		var z: Vector2i = truemmer[_truemmer3d.size()]
		_truemmer3d.append(_kasten3d(hd, Vector3(0.9, 0.25, 0.8), Color("3a3440"), Vector3(float(z.x) + 0.5, 0.12, float(z.y) + 0.5)))
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
	print("ORDER24 Ende: %s nach %.0f s · Sabotage %s · Kills %d · Deckung %d %% · Schaden an Brakk %s" % ["Sieg" if sieg else "Niederlage", zeit, str(sabotage), kills, roundi(100.0 * deckung_sek / maxf(1.0, zeit)), str(schaden_an_brakk)])
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
	b["hoehepunkte"] = [
		["Überlebt", _uhr(zeit) if wf("ueberleben_sek") <= 0.0 else "%s von %s" % [_uhr(zeit), _uhr(wf("ueberleben_sek"))]],
		["Fabriken zerstört / sabotiert", "%d / %d" % [int(sabotage["fabriken"]), int(sabotage["sabotiert"])]],
		["Kills", str(kills)],
		["Ringe", str((b.get("ringe", []) as Array).size())],
		["Erdwälle gesprengt · in Deckung", "%d · %d %%" % [int(sabotage["waelle"]), roundi(100.0 * deckung_sek / maxf(1.0, zeit))]],
	]
	if geheim:
		(b["hoehepunkte"] as Array).append(["Überläufer: Myriaden-Fabriken", str(myr_fabriken.size())])
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
			o24.schaden_an_brakk[quelle] = float(o24.schaden_an_brakk.get(quelle, 0.0)) + menge * anteil
			k.nimm_schaden(menge * anteil)

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
