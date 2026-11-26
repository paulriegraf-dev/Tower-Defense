class_name BrakkFortschritt
extends RefCounted
## 18.11.: Brakk-Mode – Brakks Fortschritt in einer Partie: Erfahrung und Stufen (1–10), freigeschaltete Fähigkeiten.
## Hängt am Kommandanten (überlebt also einen Fall und das Neuaufbauen der Ego-Sicht).

const STUFE_HOECHST := 10
const ERFAHRUNG_BIS := [0, 12, 30, 55, 90, 135, 190, 255, 330, 420]   # Gesamterfahrung, ab der Stufe 1..10 gilt
const XP_KILL := 1
const XP_WELLE := 10
const XP_KILL_ANTEIL := 0.5          # 18.11. (Paul): Kills geben nur die halbe Erfahrung (dreimal so viele Gegner)
const XP_MAL := 1.15                  # 19.11. (Paul): Brakk bekommt 15 % mehr Erfahrung (Kills und Wellen)
const SCHADEN_START := 1.85            # 19.11. (Paul, Bot-Partien): Brakk ist die Hauptfigur – etwa 26 je Schuss, ein Hund fällt anfangs mit 2 Schüssen (vorher 1,7) …
const SCHADEN_JE_STUFE := 0.10        # … und je Stufe 10 % stärker (Platz nach oben für Ringe und Stufen)
const LEBEN_JE_STUFE := 30.0          # +30 Leben je Stufe über 1
## Freischaltungen: Fähigkeit -> Stufe
const AB := {"tumble": 2, "doppelsprung": 2, "anker": 3, "lanze": 4, "saeule": 6, "ulti": 7, "zeitlupe": 8}
const NAMEN := {"doppelsprung": "Doppelsprung [2× Leertaste]", "saeule": "Lichtsäule [X]", "zeitlupe": "Zeitlupe [V]", "tumble": "Tumble [Shift]", "anker": "Lichtanker [Q]", "lanze": "Ladestrahl [Rechtsklick]", "ulti": "Klonmaschine [R]"}
const FREIE_WAELLE := 5               # 18.11. (Paul): so viele Erdwälle bekommt Brakk jede Runde geschenkt
const FREIE_STELLUNGEN := 1           # 19.11. (Paul): … und so viele Stellungen
const ULTI_KILLS := 30               # so viele eigene Kills lädt die Ulti (Klonmaschine) auf
## 19.11. (Paul): Brakks Schaden nach Quelle (Werte-Fenster, [Tab], Sieg-Übersicht). Reihenfolge = Anzeige.
const QUELLEN := {"pistole": "Pistolen", "tumble": "Tumble-Schuss", "lanze": "Ladestrahl", "saeule": "Lichtsäule", "ring": "Ringeffekte",
	"zeitlupe": "Zeitlupe", "klinge": "Ringklinge", "absprung": "Absprung", "sonst": "Sonstiges",
	## 20.11.: Schritt 6b – Quellen der neuen Anführer (Irrtürmer, Sonde 7 je Waffe)
	"prellbolzen": "Prellbolzen", "pliplop": "PliPlop", "hack": "Hack", "aufsatz": "Aufsatz", "verbund": "Verbund",
	"laser_hand": "Farblaser", "buendel": "Energiebündel", "doppellaser": "Doppel-Lasergewehr", "erfassung": "Zielerfassung",
	"schrot": "Schrotflinte", "sondengewehr": "Sondengewehr", "luftschlag": "Luftschlag"}
## 20.11.: welche Quellen je Anführer gezeigt werden (Reihenfolge = Anzeige; Brakk wie bisher)
const QUELLEN_JE := {
	"brakk": ["pistole", "tumble", "lanze", "saeule", "ring", "zeitlupe", "klinge", "absprung", "sonst"],
	"irrtuermer": ["prellbolzen", "pliplop", "hack", "aufsatz", "verbund", "ring", "sonst"],
	"sonde7": ["laser_hand", "buendel", "doppellaser", "erfassung", "schrot", "sondengewehr", "luftschlag", "ring", "sonst"],
}
const GEMESSEN_SEK := 5.0             # „Schaden der letzten 5 Sekunden“ im Werte-Fenster
## 19.11. (Paul): Der erste Schuss nach der Rolle (innerhalb „fenster“ Sekunden) ist verstärkt; tötet er einen großen
## Gegner (Werte.GEGNER "gross"), ist die Rolle sofort wieder bereit.
## 19.11. (Paul): Fällt Brakk, steht er nach so vielen Sekunden (Echtzeit) an der Basis wieder auf – nicht erst zur nächsten Runde.
const RESPAWN_SEK := 10.0
const TUMBLE_SCHUSS := {"fenster": 2.0, "mal": 2.0, "mal_gross": 3.0}
## 22.11. (Paul: „ab Runde 11 clunky“): Hit-Stop beim Kill nur bei großen Gegnern oder Mehrfach-Kills (ab „mehrfach“ Kills mit
## einem Treffer) und höchstens alle „abstand“ Sekunden – vorher fror jeder Kill das Spiel 70 ms ein, bei 50+ Gegnern ständig.
const HITSTOP := {"abstand": 0.5, "mehrfach": 2}
## 19.11. (Paul): Ladestrahl fürs späte Spiel – zusätzlich zum Schaden nimmt sie jedem Getroffenen diesen Anteil seines
## maximalen Lebens (große Gegner weniger). Ohne Ringeffekte.
const LANZE_ANTEIL := {"normal": 0.10, "gross": 0.05}
## 19.11. (Paul): Zeitlupe [V] – Zusatz je aktivem Ring (beim Auslösen festgelegt). Felder in Feldern, Zeiten in Sekunden.
const ZEITLUPE_RING := {
	"bollwerk": {"radius": 6.0, "schild": 0.30, "sek": 10.0},          # danach: Schild für Truppen im Umkreis (Anteil ihres Lebens)
	"plasmagel": {"radius": 8.0, "heilung": 0.08},                     # währenddessen: Truppen heilen je Sekunde (Anteil des Lebens)
	"feuerteam": {},                                                   # Fabriken im Taktring-Feld ersetzen sofort gefallene Truppen
	"laser": {"touch_takt": 1.3},                                      # keine Überhitzung; am Handy (ohne Hitze) schneller
	"abpraller": {},                                                   # Anker, Rolle, Treppe sofort bereit, währenddessen ohne Abklingzeit
	"minigun": {"radius": 4.0, "zug": 2.0},                            # am Ende: Sog am Punkt unter dem Fadenkreuz
	"brandfeld": {"radius": 6.0, "sperre": 8.0},                       # Rauch im Umkreis weg, Gegner darin nicht heilbar
	"markierung": {"nach": 3.0},                                       # Markierungs-Bonus auch für Brakks Schüsse, bis „nach“ danach
	"durchschuss": {"weite": 2.0, "bogen": 120.0, "takt": 0.5, "mal": 3.0, "heilung": 0.15},   # Ringklinge (Nahkampf)
}


static func gross(g: Gegner) -> bool:
	return bool(g.daten.get("gross", false))
## 18.11. (Paul): Ringe für die linke Hand – am Lichtterminal der Basis gekauft und ausgebaut (Budget).
##   Ringfeld ([C] in der Bauphase): Fabriken darin bauen die Truppe des Rings auf seiner Stufe
##   (Stufe 1: spezialisiert, 2: Wertepaket, 3: die Fähigkeit). Im Kampf liegen die Felder fest.
##   Aktiver Ring (Mausrad, jederzeit): gibt Brakks Pistolen seinen Effekt – immer nur einer.
## Farben = Abzeichen der Fähigkeit.
## 19.11. (Paul): `brakk_stufen` – was der Ring Brakk auf Ringstufe 1 / 2 / 3 gibt (Stufe 3 = früherer Vollwert).
## Ring und Feld passen zusammen: der Ring gibt Brakk dieselbe Wirkung, die das Feld als Truppe baut.
const RINGE := {
	"durchschuss": {"saeule_kurz": "5er-Linie", "name": "Durchschlagring", "truppe": "scharfschuetze", "saeule": "Linie über 5 Felder in Blickrichtung (Linksklick halten und Maus bewegen dreht sie)", "brakk_stufen": [
		{"weitere": [0.5], "text": "durch 1 weiteren Gegner (halber Schaden)"},
		{"weitere": [0.5, 0.5], "text": "durch 2 weitere Gegner (halber Schaden)"},
		{"weitere": [1.0, 0.5], "text": "durch 2 weitere (der erste voll, dann halb)"}]},
	"laser": {"saeule_kurz": "2× Schaden", "name": "Glutstrahlring", "truppe": "scharfschuetze", "saeule": "ein kleiner Einschlag mit doppeltem Schaden", "brakk_stufen": [
		{"schaden": 1.2, "text": "+20 % Schaden"},
		{"schaden": 1.3, "text": "+30 % Schaden"},
		{"schaden": 1.4, "text": "+40 % Schaden"}]},
	"markierung": {"saeule_kurz": "normal", "name": "Zielring", "truppe": "scharfschuetze", "saeule": "normaler Einschlag", "brakk_stufen": [   # 19.11. (Paul): neu
		{"mark_bonus": 1.15, "mark_sek": 3.0, "text": "Treffer markieren 3 s: andere +15 % Schaden"},
		{"mark_bonus": 1.25, "mark_sek": 3.0, "text": "Treffer markieren 3 s: andere +25 % Schaden"},
		{"mark_bonus": 1.35, "mark_sek": 3.0, "text": "Treffer markieren 3 s: andere +35 % Schaden"}]},
	"feuerteam": {"saeule_kurz": "3 Einschläge", "name": "Taktring", "truppe": "technogunner", "saeule": "3 Einschläge im Dreieck rund um die Marke (0°/120°/240° ab Blickrichtung)", "brakk_stufen": [
		{"takt": 1.0 / 1.15, "text": "15 % schneller, heizt weniger"},
		{"takt": 1.0 / 1.2, "text": "20 % schneller, heizt weniger"},
		{"takt": 1.0 / 1.25, "text": "25 % schneller, heizt weniger"}]},
	"minigun": {"saeule_kurz": "steht 3 s", "name": "Wirbelring", "truppe": "technogunner", "saeule": "ein Einschlag, die Säule bleibt 3 s stehen, dreht sich und schadet laufend", "brakk_stufen": [
		{"anlauf": 1.3, "text": "Dauerfeuer läuft an bis 1,3×"},
		{"anlauf": 1.45, "text": "Dauerfeuer läuft an bis 1,45×"},
		{"anlauf": 1.6, "text": "Dauerfeuer läuft an bis 1,6×"}]},
	"bollwerk": {"saeule_kurz": "normal", "name": "Wallring", "truppe": "technogunner", "saeule": "normaler Einschlag", "brakk_stufen": [   # 19.11. (Paul): neu
		{"schutz": 0.10, "text": "Brakk nimmt 10 % weniger Schaden"},
		{"schutz": 0.15, "text": "Brakk nimmt 15 % weniger Schaden"},
		{"schutz": 0.20, "text": "Brakk nimmt 20 % weniger Schaden"}]},
	"abpraller": {"saeule_kurz": "springt auf 3", "name": "Sprungring", "truppe": "plasmawerfer", "saeule": "Einschlag, dann springt ein Blitz auf bis zu 3 Gegner im Umkreis von 4 Feldern", "brakk_stufen": [
		{"spruenge": 1, "sprung_anteil": 0.4, "text": "1 Sprung mit 40 % Schaden"},
		{"spruenge": 1, "sprung_anteil": 0.6, "text": "1 Sprung mit 60 % Schaden"},
		{"spruenge": 2, "sprung_anteil": 0.6, "text": "2 Sprünge mit 60 % Schaden"}]},
	"brandfeld": {"saeule_kurz": "+ Brandfeld", "name": "Brandring", "truppe": "plasmawerfer", "saeule": "Einschlag und ein Brandfeld (30 % größer als der Einschlag)", "brakk_stufen": [
		{"brand_takt": 2.5, "text": "Treffer setzen alle 2,5 s den Boden in Brand"},
		{"brand_takt": 2.0, "text": "Treffer setzen alle 2 s den Boden in Brand"},
		{"brand_takt": 1.5, "text": "Treffer setzen alle 1,5 s den Boden in Brand"}]},
	"plasmagel": {"saeule_kurz": "bremst 4 s", "name": "Gelring", "truppe": "plasmawerfer", "saeule": "Gelfeld (20 % größer als der Einschlag): wenig Schaden, aber alle im Feld 4 s stark gebremst", "brakk_stufen": [
		{"bremse": 1.0, "gel_bonus": 1.2, "text": "bremst 1 s, Gebremste nehmen +20 %"},
		{"bremse": 1.5, "gel_bonus": 1.3, "text": "bremst 1,5 s, Gebremste nehmen +30 %"},
		{"bremse": 2.0, "gel_bonus": 1.4, "text": "bremst 2 s, Gebremste nehmen +40 %"}]},
}
const RING_PREISE := [175, 300, 450]   # Kauf (Stufe 1), Stufe 2, Stufe 3 – 19.11. (Paul): vorher 200 / 250 / 500
const RING_ZURUECK := 0.75           # Verkaufen: so viel vom Bezahlten zurück (in derselben Bauphase gekauft: alles)
const FINGER_AB := [1, 3, 5, 7, 9]    # ab diesen Stufen ist je ein Finger mehr frei
const FELD_GROESSE := 2               # 19.11. (Paul): Ringfeld = festes 2×2-Felder-Rechteck (höchstens 4 Fabriken), für alle Ringe gleich
const WECHSEL_SEK := 0.6               # Ring wechseln: so lange schüttelt Brakk die Hand, erst dann wirkt der neue Ring

var erfahrung := 0
var stufe := 1
var basis_leben := 0.0
var aufstieg_zeit := -1.0             # für das Banner: Sekunden seit dem letzten Aufstieg (-1 = keins)
var neu_frei: Array[String] = []      # was beim letzten Aufstieg freigeschaltet wurde (für das Banner)
var ulti_ladung := 0                  # eigene Kills seit der letzten Ulti
var kill_xp := 0.0                    # gesammelte Bruchteile der Kill-Erfahrung
var _xp_rest := 0.0                    # Bruchteile aus XP_MAL
var ulti_ab_welle := 0                # vorher geht die Ulti nicht (nach einem Einsatz: eine ganze Runde Pause)
var ringe: Array[String] = []          # getragene Ringe (je Finger einer)
var ring_stufen := {}                  # Ring -> Stufe 1..3
var _bezahlt := {}                     # Ring -> insgesamt bezahlt (für das Verkaufen)
var _gekauft_in := {}                  # Ring -> Runde des Kaufs (volle Erstattung in derselben Bauphase)
var felder := {}                       # Ring -> linke obere Zelle seines 2×2-Felds (Vector2i), in der Bauphase gesetzt
var gewaehlt := 0                      # Index des aktiven Rings (Mausrad)
var wechsel_rest := 0.0                # Ring wird gerade gewechselt: so lange wirkt keiner
var schaden_quellen := {}               # 19.11.: Quelle -> Schaden über die Partie
var schaden_runden := {}               # 19.11.: "Runde" -> {Quelle -> Schaden}
var kills_runden := {}                 # 19.11.: "Runde" -> eigene Kills
var _gemessen: Array = []              # [Zeit ms, Schaden] der letzten GEMESSEN_SEK
var anfuehrer := "brakk"               # 20.11.: wer im Brakk-Mode spielt (Werte.ANFUEHRER_EGO)


var alle_frei := false                # 20.11. (Schritt 5b): Szenario gibt alle Fähigkeiten frei (unabhängig von der Stufe)
var stufen_fest := false              # 20.11. (Schritt 5b): Szenario ohne Stufenaufstieg (keine Erfahrung)


func _init(brakk: Kommandant) -> void:
	anfuehrer = Werte.anfuehrer if Werte.ego_hat(Werte.anfuehrer) else "brakk"
	basis_leben = brakk.max_leben * float(Werte.ego_af("leben"))   # 20.11.: Leben je Anführer (Brakk 1,0)
	brakk.max_leben = basis_leben
	brakk.leben = minf(brakk.leben, basis_leben)
	# 20.11. (Schritt 5b): Startstufe und Stufenregel aus dem Regelpaket der Karte (Belagert: Stufe 5, alles frei, keine Stufen)
	var r: Dictionary = Werte.KARTE_REGELN
	alle_frei = bool(r.get("brakk_alle_faehigkeiten", false))
	stufen_fest = not bool(r.get("brakk_stufen", true))
	var st := clampi(int(r.get("brakk_stufe", 1)), 1, STUFE_HOECHST)
	if st > 1:
		stufe = st
		erfahrung = int(ERFAHRUNG_BIS[st - 1])
		brakk.max_leben = basis_leben + LEBEN_JE_STUFE * float(st - 1)
		brakk.leben = brakk.max_leben


## Ab der Stufe in ab_tabelle (nicht genannt = von Anfang an).
func frei(was: String) -> bool:
	if alle_frei:
		return true   # 20.11. (Schritt 5b): Szenario gibt alle Fähigkeiten frei (Nachtrag: für jeden Anführer)
	return stufe >= int(ab_tabelle(anfuehrer).get(was, 1))   # 20.11. (Nachtrag): jeder Anführer über seine Stufen


## 20.11. (Nachtrag): Freischaltstufen je Anführer – Brakk AB, sonst Werte.ANFUEHRER_EGO[…]["ab"].
static func ab_tabelle(af: String) -> Dictionary:
	if af == "brakk" or not Werte.ANFUEHRER_EGO.has(af):
		return AB
	return Werte.ANFUEHRER_EGO[af]["ab"]


## Name einer Fähigkeit mit Taste (Aufstiegs-Banner, Übersicht).
static func faehigkeit_name(af: String, was: String) -> String:
	if af == "brakk" and NAMEN.has(was):
		return str(NAMEN[was])
	var taste := ""
	for t: String in (Werte.ANFUEHRER_EGO[af]["tasten"] as Dictionary):
		if str(Werte.ANFUEHRER_EGO[af]["tasten"][t]) == was:
			taste = str(Werte.EGO_TASTEN_NAME.get(t, t))
	return str(Werte.EGO_AKTIONEN.get(was, was)) + (" [%s]" % taste if taste != "" else "")


## 20.11.: Quellen, die für diesen Anführer gezeigt werden.
static func quellen(af: String) -> Array:
	return QUELLEN_JE.get(af, QUELLEN_JE["brakk"])


func schaden_faktor() -> float:
	return SCHADEN_START * (1.0 + SCHADEN_JE_STUFE * float(stufe - 1))


## Anteil 0..1 bis zur nächsten Stufe (1 auf der höchsten).
func anteil() -> float:
	if stufe >= STUFE_HOECHST:
		return 1.0
	var von: int = ERFAHRUNG_BIS[stufe - 1]
	var bis: int = ERFAHRUNG_BIS[stufe]
	return clampf(float(erfahrung - von) / float(bis - von), 0.0, 1.0)


## Erfahrung dazu; steigt Brakk auf, wächst sein Leben (und er wird um den Zuwachs geheilt). Gibt die Zahl der Aufstiege zurück.
func gib(xp: int, brakk: Kommandant) -> int:
	if stufen_fest:
		return 0   # 20.11.: Szenario ohne Stufen
	# 19.11. (Paul): +15 % Erfahrung (Bruchteile werden gesammelt)
	var roh := float(xp) * XP_MAL + _xp_rest
	var ganz := floori(roh)
	_xp_rest = roh - float(ganz)
	erfahrung += ganz
	var auf := 0
	while stufe < STUFE_HOECHST and erfahrung >= int(ERFAHRUNG_BIS[stufe]):
		stufe += 1
		auf += 1
	if auf > 0:
		neu_frei.clear()
		var ab := ab_tabelle(anfuehrer)   # 20.11. (Nachtrag): Freischaltungen für jeden Anführer
		for k: String in ab:
			if int(ab[k]) > stufe - auf and int(ab[k]) <= stufe:
				neu_frei.append(k)
		var neu := basis_leben + LEBEN_JE_STUFE * float(stufe - 1)
		if not brakk.gefallen:
			brakk.leben += neu - brakk.max_leben
		brakk.max_leben = neu
		aufstieg_zeit = 0.0
	return auf


## Vergangene Zeit (Echtzeit) für das Banner.
func weiter(dt: float) -> void:
	wechsel_rest = maxf(0.0, wechsel_rest - dt)
	if aufstieg_zeit >= 0.0:
		aufstieg_zeit += dt
		if aufstieg_zeit > 3.5:
			aufstieg_zeit = -1.0


## Ulti: fehlt noch etwas? "" = bereit, sonst der Grund.
func ulti_grund(welle: int) -> String:
	if not frei("ulti"):
		return "Die Klonmaschine gibt es ab Stufe %d." % int(AB["ulti"])
	if welle < ulti_ab_welle:
		return "Die Klonmaschine lädt sich erst ab Runde %d wieder auf." % ulti_ab_welle
	if ulti_ladung < ULTI_KILLS:
		return "Klonmaschine lädt: %d / %d eigene Kills." % [ulti_ladung, ULTI_KILLS]
	return ""


func ulti_benutzt(welle: int) -> void:
	ulti_ladung = 0
	ulti_ab_welle = welle + 2


## 0 = bereit, 1 = leer (für die Anzeige).
func ulti_rest(welle: int) -> float:
	if not frei("ulti") or welle < ulti_ab_welle:
		return 1.0
	return 1.0 - clampf(float(ulti_ladung) / float(ULTI_KILLS), 0.0, 1.0)


# ------------------------------------------------------------------ Ringe

## Freie Finger (Ringplätze) auf der aktuellen Stufe.
func finger() -> int:
	if anfuehrer == "irrtuermer":
		return SATZ_MAX   # 20.11. (Nachtrag): Satz des Helden
	var n := 0
	for ab: int in FINGER_AB:
		if stufe >= ab:
			n += 1
	return n


func hat(ring: String) -> bool:
	return ringe.has(ring)


func ring_stufe(ring: String) -> int:
	if irr():   # 20.11. (Nachtrag): höchste Stufe dieses Rings im Held-Satz (für das Feld)
		var best := 0
		for i in ringe.size():
			if ringe[i] == ring:
				best = maxi(best, satz_stufe("held", i))
		return best
	return int(ring_stufen.get(ring, 0))


## Der aktive Ring (wirkt auf Brakks Pistolen) – "" während des Wechsels oder ohne Ring.
func aktiv() -> String:
	if ringe.is_empty() or wechsel_rest > 0.0:
		return ""
	return ringe[clampi(gewaehlt, 0, ringe.size() - 1)]


## Kaufen (Stufe 1) oder die nächste Stufe: "" = geklappt, sonst der Grund.
func kaufe(ring: String, spiel: Node) -> String:
	if irr():
		return kaufe_in("held", ring, spiel)   # 20.11. (Nachtrag): Irrtürmer – neuer Ring in den Held-Satz
	var st := ring_stufe(ring)
	if st >= RING_PREISE.size():
		return "Der Ring ist schon auf Stufe 3."
	if st == 0 and ringe.size() >= finger():
		return "Kein Finger frei – der nächste ab Stufe %d." % int(FINGER_AB[ringe.size()]) if ringe.size() < FINGER_AB.size() else "Alle fünf Finger tragen schon einen Ring."
	var preis := int(RING_PREISE[st])
	if int(spiel.budget) < preis:
		return "Nicht genug Budget."
	spiel.budget -= preis
	if st == 0:
		ringe.append(ring)
		_gekauft_in[ring] = int(spiel.welle)
	ring_stufen[ring] = st + 1
	_bezahlt[ring] = int(_bezahlt.get(ring, 0)) + preis
	protokoll.ring("kauf" if st == 0 else "stufe", ring, {"stufe": st + 1, "preis": preis})   # 23.11.
	return ""


## 26.11. (Paul): Geschenkte Stufe vom Herausforderer – auch sie bringt beim Verkaufen kein Gold (zurück kommt nur
## selbst Bezahltes).
func schenke_stufe(ring: String, spiel: Node) -> String:
	if ring_stufe(ring) <= 0:
		return "Den Ring trägt Brakk nicht."
	if ring_stufe(ring) >= RING_PREISE.size():
		return "Schon die höchste Stufe."
	ring_stufen[ring] = ring_stufe(ring) + 1
	protokoll.ring("beute", ring, {"stufe": ring_stufe(ring), "preis": 0})
	return ""


## 25.11. (Paul): Geschenkter neuer Ring (Befehl 24: Beute aus einer Fabrik). Er kostet nichts und bringt beim Verkaufen
## kein Gold; wer ihn aufwertet, bekommt nur die selbst bezahlten Stufen zurück. "" = geklappt, sonst der Grund.
func schenke(ring: String, spiel: Node) -> String:
	if ring_stufe(ring) > 0:
		return "Den Ring trägt Brakk schon."
	if ringe.size() >= finger():
		return "Kein Finger frei."
	ringe.append(ring)
	ring_stufen[ring] = 1
	_gekauft_in[ring] = int(spiel.welle)
	_bezahlt[ring] = 0
	protokoll.ring("beute", ring, {"stufe": 1, "preis": 0})
	return ""


func erstattung(ring: String, welle: int) -> int:
	var summe := int(_bezahlt.get(ring, 0))
	return summe if int(_gekauft_in.get(ring, -1)) == welle else int(summe * RING_ZURUECK)


func verkaufe(ring: String, spiel: Node) -> void:
	if not ringe.has(ring):
		return
	var zurueck := erstattung(ring, int(spiel.welle))
	spiel.budget += zurueck
	protokoll.ring("verkauf", ring, {"stufe": ring_stufe(ring), "erstattung": zurueck})   # 23.11.
	while ringe.has(ring):   # 20.11.: der Irrtürmer verkauft je Satz und Stelle (verkaufe_in)
		ringe.erase(ring)
	ring_stufen.erase(ring)
	_bezahlt.erase(ring)
	_gekauft_in.erase(ring)
	felder.erase(ring)
	gewaehlt = clampi(gewaehlt, 0, maxi(0, ringe.size() - 1))


## Ringfeld setzen (nur in der Bauphase); das zuletzt gesetzte gilt, wo sich Felder überlappen.
func setze_feld(ring: String, ecke: Vector2i) -> void:
	felder.erase(ring)
	felder[ring] = ecke
	protokoll.ring("feld", ring, {"x": ecke.x, "y": ecke.y})   # 23.11.


## Liegt die Zelle `z` im 2×2-Feld mit der linken oberen Zelle `ecke`?
static func im_feld(z: Vector2i, ecke: Vector2i) -> bool:
	return z.x >= ecke.x and z.x < ecke.x + FELD_GROESSE and z.y >= ecke.y and z.y < ecke.y + FELD_GROESSE


## 19.11. (Paul): Ringe stapeln – für Brakks Schüsse (Autoattacke) wirken ALLE getragenen Ringe zugleich, jeder auf seiner
## Stufe (Tabelle `brakk_stufen` in RINGE). Jeder Wert gehört genau einem Ring; `std`, wenn keiner ihn hat.
func brakk_wert(schluessel: String, std: Variant) -> Variant:
	if irr():
		return satz_wert("held", schluessel, std)   # 20.11. (Nachtrag): alle Ringe des Held-Satzes, mehrfache addiert
	for r: String in ringe:
		var st := clampi(ring_stufe(r), 1, 3)
		var d: Dictionary = RINGE[r]["brakk_stufen"][st - 1]
		if d.has(schluessel):
			return d[schluessel]
	return std


## Nur der aktive Ring (für Fähigkeiten wie Lichtsäule und Ladestrahl) – "" während des Ringwechsels.
func brakk_wert_aktiv(schluessel: String, std: Variant) -> Variant:
	var r := aktiv()
	if r == "":
		return std
	var st := clampi(satz_aktiv_stufe("held") if irr() else ring_stufe(r), 1, 3)   # 20.11. (Nachtrag): Irrtürmer – Stufe dieser Kopie
	return (RINGE[r]["brakk_stufen"][st - 1] as Dictionary).get(schluessel, std)


## Was der Ring Brakk auf Stufe `st` gibt (für das Terminal).
static func brakk_text(ring: String, st: int) -> String:
	return str(RINGE[ring]["brakk_stufen"][clampi(st, 1, 3) - 1]["text"])


## Faktoren für Brakks Pistolen aus dem aktiven Ring.
func schuss_schaden() -> float:
	return schaden_faktor() * float(brakk_wert("schaden", 1.0))


## Fähigkeiten (Lichtsäule, Ladestrahl): Stufenschaden mal nur dem Schadensbonus des aktiven Rings.
func faehigkeit_schaden() -> float:
	return schaden_faktor() * float(brakk_wert_aktiv("schaden", 1.0))


func schuss_takt() -> float:
	return float(brakk_wert("takt", 1.0))


## Überhitzen (ego_modus.gd): Wirbelring – Schüsse heizen weniger; Taktring – kühlt schneller.
func hitze_faktor() -> float:
	# 18.11. (Schießstand): Taktring 0,6, Wirbelring 0,7 – 19.11.: getragen genügt, beide zusammen stapeln
	return (0.6 if hat("feuerteam") else 1.0) * (0.7 if hat("minigun") else 1.0)


func kuehl_faktor() -> float:
	return 1.8 if hat("feuerteam") else 1.0   # 18.11. (Schießstand): vorher 1,5; 19.11.: getragen genügt


## Jedes Bild (vom Kommandanten): in der Bauphase bauen Fabriken in einem Ringfeld die Truppe des Rings auf seiner Stufe.
## Der eigene Stand der Fabrik wird gemerkt ("ring_vorher") und kommt zurück, sobald kein Feld sie mehr trifft.
## Im Kampf bleibt alles, wie es zu Rundenbeginn war.
func wirke(spiel: Node) -> void:
	if int(spiel.phase) != 0:
		return
	var k: Karte = spiel.karte
	for z: Vector2i in spiel.fabriken:
		if k.paar.has(z):
			continue   # Pilotenfabrik einer Batterie
		var fab: Dictionary = spiel.fabriken[z]
		var ziel := ""
		for ring: String in felder:
			if im_feld(z, felder[ring] as Vector2i):
				ziel = ring   # das zuletzt gesetzte Feld gewinnt
		var jetzt := str(fab.get("ring", ""))
		var st := ring_stufe(ziel)
		if ziel == jetzt and (ziel == "" or int(fab.get("ring_st", 0)) == st):
			continue
		if fab.has("ring_vorher"):
			var v: Dictionary = fab["ring_vorher"]
			fab["typ"] = v["typ"]
			fab["stufe"] = v["stufe"]
			fab["faehigkeit"] = v["faehigkeit"]
			fab.erase("ring_vorher")
			fab.erase("ring")
			fab.erase("ring_st")
		if ziel != "":
			fab["ring_vorher"] = {"typ": fab["typ"], "stufe": int(fab.get("stufe", 0)), "faehigkeit": str(fab.get("faehigkeit", ""))}
			fab["typ"] = str(RINGE[ziel]["truppe"])
			fab["stufe"] = st
			fab["faehigkeit"] = ziel if st >= 3 else ""
			fab["ring"] = ziel
			fab["ring_st"] = st
		k.fabrik_typ[z] = fab["typ"]
		k.fabrik_stufe[z] = int(fab["stufe"])


## 19.11.: Zwischenstand im Brakk-Mode (Seite am Handy neu geladen) – Stufe, Erfahrung, Ringe mit Stufen und Feldern.
func speichern() -> Dictionary:
	var f := {}
	for ring: String in felder:
		var e: Vector2i = felder[ring]
		f[ring] = [e.x, e.y]
	return {"erfahrung": erfahrung, "stufe": stufe, "xp_rest": _xp_rest, "kill_xp": kill_xp, "ulti_ladung": ulti_ladung,
		"ulti_ab_welle": ulti_ab_welle, "ringe": Array(ringe), "ring_stufen": ring_stufen, "bezahlt": _bezahlt,
		"gekauft_in": _gekauft_in, "felder": f, "gewaehlt": gewaehlt, "schaden_quellen": schaden_quellen, "schaden_runden": schaden_runden, "kills_runden": kills_runden, "zaehler": zaehler, "saetze": saetze_speichern()}   # 20.11. (Nachtrag): Irrtürmer-Sätze


func lade(d: Dictionary, brakk: Kommandant) -> void:
	erfahrung = int(d.get("erfahrung", 0))
	stufe = clampi(int(d.get("stufe", 1)), 1, STUFE_HOECHST)
	_xp_rest = float(d.get("xp_rest", 0.0))
	kill_xp = float(d.get("kill_xp", 0.0))
	ulti_ladung = int(d.get("ulti_ladung", 0))
	ulti_ab_welle = int(d.get("ulti_ab_welle", 0))
	ringe.clear()
	for r: Variant in d.get("ringe", []):
		if RINGE.has(str(r)):
			ringe.append(str(r))
	ring_stufen.clear()
	_bezahlt.clear()
	_gekauft_in.clear()
	var st: Dictionary = d.get("ring_stufen", {})
	var bz: Dictionary = d.get("bezahlt", {})
	var gk: Dictionary = d.get("gekauft_in", {})
	var fe: Dictionary = d.get("felder", {})
	for r: String in ringe:
		ring_stufen[r] = int(st.get(r, 1))
		_bezahlt[r] = int(bz.get(r, 0))
		if gk.has(r):
			_gekauft_in[r] = int(gk[r])
		if fe.has(r):
			var e: Array = fe[r]
			felder[r] = Vector2i(int(e[0]), int(e[1]))
	gewaehlt = clampi(int(d.get("gewaehlt", 0)), 0, maxi(0, ringe.size() - 1))
	saetze_laden(d.get("saetze", {}))   # 20.11. (Nachtrag): Irrtürmer – Stufen je Kopie und PliPlop-Satz
	schaden_quellen = d.get("schaden_quellen", {})   # 19.11.
	schaden_runden = d.get("schaden_runden", {})
	kills_runden = d.get("kills_runden", {})
	zaehler = d.get("zaehler", {})
	brakk.max_leben = basis_leben + LEBEN_JE_STUFE * float(stufe - 1)
	brakk.leben = brakk.max_leben


## 19.11.: Ein Treffer Brakks (vom Spiel mit dem tatsächlich abgezogenen Schaden gemeldet).
func zaehle_quelle(quelle: String, menge: float, getoetet: bool, welle: int) -> void:
	var q := quelle if QUELLEN.has(quelle) else "sonst"
	schaden_quellen[q] = float(schaden_quellen.get(q, 0.0)) + menge
	var r := str(welle)
	if not schaden_runden.has(r):
		schaden_runden[r] = {}
	var d: Dictionary = schaden_runden[r]
	d[q] = float(d.get(q, 0.0)) + menge
	if getoetet:
		kills_runden[r] = int(kills_runden.get(r, 0)) + 1
	var jetzt := Time.get_ticks_msec()
	_gemessen.append([jetzt, menge])


## Schaden je Sekunde, gemessen über die letzten GEMESSEN_SEK (Echtzeit).
func dps_gemessen() -> float:
	var grenze := Time.get_ticks_msec() - int(GEMESSEN_SEK * 1000.0)
	while not _gemessen.is_empty() and int(_gemessen[0][0]) < grenze:
		_gemessen.pop_front()
	var summe := 0.0
	for e: Array in _gemessen:
		summe += float(e[1])
	return summe / GEMESSEN_SEK


func schaden_gesamt() -> float:
	var s := 0.0
	for q: String in schaden_quellen:
		s += float(schaden_quellen[q])
	return s


## 19.11.: Was die Zeitlupe mit diesem Ring als aktivem zusätzlich tut – aus ZEITLUPE_RING erzeugt (Übersicht, Terminal).
static func zeitlupe_text(ring: String) -> String:
	var z: Dictionary = ZEITLUPE_RING.get(ring, {})
	match ring:
		"bollwerk":
			return "Danach bekommen Truppen im Umkreis von %s Feldern für %s s einen Schild (%d %% ihres Lebens)." % [_zahl(z["radius"]), _zahl(z["sek"]), roundi(float(z["schild"]) * 100.0)]
		"plasmagel":
			return "Währenddessen heilen sich Truppen im Umkreis von %s Feldern um %d %% je Sekunde." % [_zahl(z["radius"]), roundi(float(z["heilung"]) * 100.0)]
		"feuerteam":
			return "Fabriken im Feld des Taktrings ersetzen sofort ihre gefallenen Truppen."
		"laser":
			return "Brakks Waffen überhitzen währenddessen nicht (am Handy, ohne Hitze: %d %% schnellere Schüsse)." % roundi((float(z["touch_takt"]) - 1.0) * 100.0)
		"abpraller":
			return "Anker, Rolle und Treppe sind sofort bereit und währenddessen ohne Cooldown."
		"minigun":
			return "Am Ende zieht ein Sog Gegner im Umkreis von %s Feldern um den Punkt unter dem Fadenkreuz bis zu %s Felder zusammen (nicht durch Mauern, große Gegner nicht)." % [_zahl(z["radius"]), _zahl(z["zug"])]
		"brandfeld":
			return "Rauch im Umkreis von %s Feldern löst sich auf, Gegner darin können %s s nicht geheilt werden." % [_zahl(z["radius"]), _zahl(z["sperre"])]
		"markierung":
			return "Währenddessen und %s s danach gilt der Markierungs-Bonus auch für Brakks eigene Schüsse." % _zahl(z["nach"])
		"durchschuss":
			return "Nahkampf: Brakk steckt die rechte Pistole weg und führt eine Ringklinge – Schläge treffen alle Gegner im Bogen vor ihm bis %s Felder weit, alle %s s, mit %s-fachem Schussschaden; %d %% des Schadens heilen Brakk. Am Handy schlägt er von selbst zu." % [_zahl(z["weite"]), _zahl(z["takt"]), _zahl(z["mal"]), roundi(float(z["heilung"]) * 100.0)]
	return "kein Zusatz"


static func _zahl(v: Variant) -> String:
	var f := float(v)
	return str(int(f)) if is_equal_approx(f, roundf(f)) else ("%.1f" % f).replace(".", ",")


# ------------------------------------------------------------------ Sieg-Übersicht (19.11.)

## 19.11. (Paul): Titel für den Spielstil – der erste zutreffende gilt. [Titel, Kennzahl, Schwelle, Erklärung].
## Kennzahlen: faehigkeit_anteil (Lanze, Säule, Zeitlupe, Klinge, Absprung an Brakks Schaden), bewegung_je_runde (Rollen,
## Anker, Doppelsprünge je Runde), wall_anteil (Kampfzeit oben auf Wällen), bau_anteil (Truppen und Türme am
## Gesamtschaden), brakk_anteil (Brakk am Gesamtschaden).
const TITEL := [
	["Lichtmagier", "faehigkeit_anteil", 0.35, "mehr als ein Drittel von Brakks Schaden aus Fähigkeiten"],
	["Akrobat", "bewegung_je_runde", 4.0, "viele Rollen, Anker und Doppelsprünge je Runde"],
	["Scharfschütze", "wall_anteil", 0.40, "einen großen Teil der Kämpfe oben von den Wällen"],
	["Baumeister", "bau_anteil", 0.60, "Truppen und Türme machten den meisten Schaden"],
	["Frontkämpfer", "brakk_anteil", 0.60, "Brakk selbst machte den meisten Schaden"],
	["Allrounder", "", 0.0, "von allem etwas"],
]
## 20.11.: Titel-Regeln je Anführer (gleicher Aufbau wie TITEL; die Kennzahlen stehen in sieg_bericht).
## Zusätzliche Kennzahlen: anteil_<Quelle> (Anteil am eigenen Schaden, Quellen wie QUELLEN), verbund_je_runde,
## luft_anteil (Kampfzeit in der Luft).
const TITEL_JE := {
	"brakk": TITEL,
	"irrtuermer": [
		["Tüftler", "anteil_pliplop", 0.35, "der PliPlop machte mehr als ein Drittel deines Schadens"],
		["Hacker", "anteil_hack", 0.20, "ein Fünftel deines Schadens aus gehackten Schüssen"],
		["Verbundmeister", "verbund_je_runde", 3.0, "viele Verbund-Treffer je Runde"],
		["Prellmeister", "anteil_prellbolzen", 0.55, "die Prellbolzen trugen die Partie"],
		["Baumeister", "bau_anteil", 0.60, "Truppen und Türme machten den meisten Schaden"],
		["Allrounder", "", 0.0, "von allem etwas"],
	],
	"sonde7": [
		["Scharfschützin", "anteil_sondengewehr", 0.25, "ein Viertel deines Schadens mit dem Sondengewehr"],
		["Luftschlägerin", "anteil_luftschlag", 0.25, "ein Viertel deines Schadens aus Luftschlägen"],
		["Kommandantin", "bau_anteil", 0.60, "Truppen und Türme machten den meisten Schaden"],
		["Himmelsläuferin", "luft_anteil", 0.35, "mehr als ein Drittel der Kämpfe in der Luft"],
		["Allrounderin", "", 0.0, "von allem etwas"],
	],
}
var protokoll := BrakkProtokoll.new()  # 23.11.: Run-Protokoll je Runde (brakk_protokoll.gd)
var zaehler := {}                      # 19.11.: rollen, anker, spruenge, saeulen, lanzen, zeitlupen, wall_sek, kampf_sek


func zaehle_zeit(was: String, sek: float) -> void:
	zaehler[was] = float(zaehler.get(was, 0.0)) + sek


## Bericht für die Sieg-Übersicht und das Profil (nur Zahlen und Texte – lässt sich als JSON speichern).
func sieg_bericht(spiel: Node, sekunden: float) -> Dictionary:
	var brakk := 0.0
	var truppen := 0.0
	var tuerme := 0.0
	for q: String in spiel.gesamt_stats:
		var s := float((spiel.gesamt_stats[q] as Dictionary).get("schaden", 0.0))
		if q == "fabrik:-1,-1":
			brakk += s
		elif q.begins_with("fabrik:"):
			truppen += s
		else:
			tuerme += s
	var gesamt := maxf(1.0, brakk + truppen + tuerme)
	var faehig := 0.0
	for q: String in ["lanze", "saeule", "zeitlupe", "klinge", "absprung"]:
		faehig += float(schaden_quellen.get(q, 0.0))
	var runden := maxi(1, int(spiel.welle))
	var kennzahlen := {
		"faehigkeit_anteil": faehig / maxf(1.0, brakk),
		"bewegung_je_runde": float(int(zaehler.get("rollen", 0)) + int(zaehler.get("anker", 0)) + int(zaehler.get("spruenge", 0))) / float(runden),
		"wall_anteil": float(zaehler.get("wall_sek", 0.0)) / maxf(1.0, float(zaehler.get("kampf_sek", 0.0))),
		"bau_anteil": (truppen + tuerme) / gesamt,
		"brakk_anteil": brakk / gesamt,
	}
	# 20.11.: Kennzahlen der anderen Anführer – Anteil je Quelle am eigenen Schaden, Verbund je Runde, Zeit in der Luft
	var eigen := maxf(1.0, schaden_gesamt())
	for q: String in QUELLEN:
		kennzahlen["anteil_" + q] = float(schaden_quellen.get(q, 0.0)) / eigen
	kennzahlen["verbund_je_runde"] = float(int(zaehler.get("verbund", 0))) / float(runden)
	kennzahlen["luft_anteil"] = float(zaehler.get("luft_sek", 0.0)) / maxf(1.0, float(zaehler.get("kampf_sek", 0.0)))
	var regeln: Array = TITEL_JE.get(anfuehrer, TITEL)   # 20.11.: Titel je Anführer
	var titel: Array = regeln[regeln.size() - 1]
	for t: Array in regeln:
		if str(t[1]) == "" or float(kennzahlen.get(t[1], 0.0)) >= float(t[2]):
			titel = t
			break
	var beste_runde := 0
	var beste_kills := 0
	for r: String in kills_runden:
		if int(kills_runden[r]) > beste_kills:
			beste_kills = int(kills_runden[r])
			beste_runde = int(r)
	# 20.11.: Höhepunkte je Anführer (Brakk wie bisher)
	var hoehepunkte: Array = [["Meiste Kills in einer Runde", "%d (Runde %d)" % [beste_kills, beste_runde] if beste_kills > 0 else "–"]]
	match anfuehrer:
		"irrtuermer":
			hoehepunkte.append(["Verbund-Treffer", str(int(zaehler.get("verbund", 0)))])
			hoehepunkte.append(["Aufsätze", str(int(zaehler.get("aufsatz", 0)))])
		"sonde7":
			hoehepunkte.append(["Teleports", str(int(zaehler.get("teleport", 0)))])
			hoehepunkte.append(["Zeit in der Luft", "%d s" % roundi(float(zaehler.get("luft_sek", 0.0)))])
		_:
			hoehepunkte.append(["Rollen", str(int(zaehler.get("rollen", 0)))])
			hoehepunkte.append(["Zeit auf den Wällen", "%d s" % roundi(float(zaehler.get("wall_sek", 0.0)))])
	var ringliste: Array = []
	for r: String in ringe:
		ringliste.append([r, ring_stufe(r)])
	return {
		"anfuehrer": anfuehrer, "stufe": stufe, "sekunden": sekunden, "runden": runden, "leben": int(spiel.leben), "max_leben": Werte.START_LEBEN,
		"titel": titel[0], "titel_grund": titel[3], "ringe": ringliste,
		"anteile": {"brakk": brakk, "truppen": truppen, "tuerme": tuerme},
		"quellen": schaden_quellen.duplicate(),
		"hoehepunkte": hoehepunkte,
		"datum": Time.get_date_string_from_system(),
	}


# ------------------------------------------------------------------ Irrtürmer: zwei Ringsätze (20.11., Nachtrag)

## 20.11. (Paul, Nachtrag): Irrtürmer und PliPlop tragen je bis zu SATZ_MAX Ringe – zwei getrennte Sätze. Jeder Ring wird
## einzeln gekauft und ausgebaut (Preise wie bei Brakk, RING_PREISE); derselbe Ring darf mehrfach im Satz stecken, jede
## Kopie hat ihre eigene Stufe. Der Held-Satz ist `ringe` (Mausrad wählt den aktiven, [C] setzt dessen Feld wie bei Brakk),
## der PliPlop-Satz `pp_ringe` (aktiver Ring = Pfad). Alle Ringe eines Satzes wirken zugleich; mehrfach getragene Werte
## werden nach RING_STAPEL zusammengezählt. [V] tauscht den aktiven Ring des Helden mit dem aktiven des PliPlop.
const SATZ_MAX := 4
## Wie gleiche Werte mehrerer Ringe zusammenkommen:
##   plus: Zuschläge addieren (1,2 und 1,3 → 1,5), tempo: Schussrate addieren (Takt 1/1,15 zweimal → 1/1,3),
##   summe: einfach addieren, max: der größte zählt, teilen: Brand-Takt – der kürzeste geteilt durch die Zahl der Ringe,
##   anhaengen: Durchschlag – die Listen der weiteren Gegner hintereinander.
## Nicht addierbar (Vorschlag): Markierungsdauer und Sprungschaden (der größte Wert), Brand-Takt (häufiger statt stärker),
## Schutz höchstens SCHUTZ_MAX.
const RING_STAPEL := {"schaden": "plus", "takt": "tempo", "mark_bonus": "plus", "mark_sek": "max", "bremse": "summe",
	"gel_bonus": "plus", "brand_takt": "teilen", "spruenge": "summe", "sprung_anteil": "max", "weitere": "anhaengen",
	"anlauf": "plus", "schutz": "summe"}
const SCHUTZ_MAX := 0.6
var held_st: Array[int] = []           # Stufe je Ring im Held-Satz (gleiche Reihenfolge wie `ringe`)
var held_bez: Array[int] = []          # bezahlt je Ring
var held_runde: Array[int] = []        # gekauft in Runde
var pp_ringe: Array[String] = []       # PliPlop-Satz
var pp_st: Array[int] = []
var pp_bez: Array[int] = []
var pp_runde: Array[int] = []
var pp_gewaehlt := 0                   # aktiver Ring des PliPlop (bestimmt den Pfad)


func irr() -> bool:
	return anfuehrer == "irrtuermer"


## [Ringe, Stufen, Bezahlt, Runde] des Satzes "held" oder "pp".
func _satz(name: String) -> Array:
	return [ringe, held_st, held_bez, held_runde] if name == "held" else [pp_ringe, pp_st, pp_bez, pp_runde]


func satz_ringe(name: String) -> Array[String]:
	return ringe if name == "held" else pp_ringe


func satz_stufe(name: String, i: int) -> int:
	var st: Array = _satz(name)[1]
	return int(st[i]) if i >= 0 and i < st.size() else 0


func satz_gewaehlt(name: String) -> int:
	return gewaehlt if name == "held" else pp_gewaehlt


## Aktiver Ring des Satzes ("" = keiner; beim Helden auch während des Wechsels).
func satz_aktiv(name: String) -> String:
	if name == "held":
		return aktiv()
	return pp_ringe[clampi(pp_gewaehlt, 0, pp_ringe.size() - 1)] if not pp_ringe.is_empty() else ""


func satz_aktiv_stufe(name: String) -> int:
	var l := satz_ringe(name)
	return satz_stufe(name, clampi(satz_gewaehlt(name), 0, l.size() - 1)) if not l.is_empty() else 0


## Kauft einen Ring (Stufe 1) in den Satz: "" = geklappt, sonst der Grund.
func kaufe_in(name: String, ring: String, spiel: Node) -> String:
	var s := _satz(name)
	if (s[0] as Array).size() >= SATZ_MAX:
		return "%s trägt schon %d Ringe." % ["Der Irrtürmer" if name == "held" else "PliPlop", SATZ_MAX]
	var preis := int(RING_PREISE[0])
	if int(spiel.budget) < preis:
		return "Nicht genug Budget."
	spiel.budget -= preis
	(s[0] as Array).append(ring)
	(s[1] as Array).append(1)
	(s[2] as Array).append(preis)
	(s[3] as Array).append(int(spiel.welle))
	protokoll.ring("kauf", ring, {"stufe": 1, "preis": preis, "satz": name})   # 23.11.
	return ""


## Nächste Stufe für den Ring an Stelle i des Satzes.
func baue_aus(name: String, i: int, spiel: Node) -> String:
	var s := _satz(name)
	var st := satz_stufe(name, i)
	if st <= 0:
		return "Kein Ring."
	if st >= RING_PREISE.size():
		return "Der Ring ist schon auf Stufe 3."
	var preis := int(RING_PREISE[st])
	if int(spiel.budget) < preis:
		return "Nicht genug Budget."
	spiel.budget -= preis
	(s[1] as Array)[i] = st + 1
	(s[2] as Array)[i] = int((s[2] as Array)[i]) + preis
	protokoll.ring("stufe", str((s[0] as Array)[i]), {"stufe": st + 1, "preis": preis, "satz": name})   # 23.11.
	return ""


func satz_erstattung(name: String, i: int, welle: int) -> int:
	var s := _satz(name)
	var summe := int((s[2] as Array)[i])
	return summe if int((s[3] as Array)[i]) == welle else int(summe * RING_ZURUECK)


func verkaufe_in(name: String, i: int, spiel: Node) -> void:
	var s := _satz(name)
	if i < 0 or i >= (s[0] as Array).size():
		return
	var zurueck := satz_erstattung(name, i, int(spiel.welle))
	spiel.budget += zurueck
	var ring := str((s[0] as Array)[i])
	protokoll.ring("verkauf", ring, {"stufe": int((s[1] as Array)[i]), "erstattung": zurueck, "satz": name})   # 23.11.
	for a: Array in s:
		a.remove_at(i)
	if name == "held":
		if not ringe.has(ring):
			felder.erase(ring)   # das Feld gehört zum Ring des Helden
		gewaehlt = clampi(gewaehlt, 0, maxi(0, ringe.size() - 1))
	else:
		pp_gewaehlt = clampi(pp_gewaehlt, 0, maxi(0, pp_ringe.size() - 1))


## PliPlop: aktiven Ring wählen (Terminal).
func waehle_pp(i: int) -> void:
	pp_gewaehlt = clampi(i, 0, maxi(0, pp_ringe.size() - 1))


## [V]: aktiver Ring des Helden ↔ aktiver Ring des PliPlop (mit Stufe und Bezahltem). Ist ein Satz leer, wandert der
## Ring nur hinüber (wenn dort Platz ist). false = nichts getauscht.
func tausche() -> bool:
	var h := _satz("held")
	var p := _satz("pp")
	var hi := clampi(gewaehlt, 0, maxi(0, ringe.size() - 1))
	var pi := clampi(pp_gewaehlt, 0, maxi(0, pp_ringe.size() - 1))
	if not ringe.is_empty() and not pp_ringe.is_empty():
		for k in 4:
			var t: Variant = (h[k] as Array)[hi]
			(h[k] as Array)[hi] = (p[k] as Array)[pi]
			(p[k] as Array)[pi] = t
	elif not ringe.is_empty() and pp_ringe.size() < SATZ_MAX:
		for k in 4:
			(p[k] as Array).append((h[k] as Array)[hi])
			(h[k] as Array).remove_at(hi)
		pp_gewaehlt = pp_ringe.size() - 1
	elif not pp_ringe.is_empty() and ringe.size() < SATZ_MAX:
		for k in 4:
			(h[k] as Array).append((p[k] as Array)[pi])
			(p[k] as Array).remove_at(pi)
		gewaehlt = ringe.size() - 1
	else:
		return false
	gewaehlt = clampi(gewaehlt, 0, maxi(0, ringe.size() - 1))
	pp_gewaehlt = clampi(pp_gewaehlt, 0, maxi(0, pp_ringe.size() - 1))
	for r: Variant in felder.keys():
		if not ringe.has(str(r)):
			felder.erase(r)
	return true


## Wert aller Ringe eines Satzes zusammen (RING_STAPEL), `std` ohne passenden Ring.
func satz_wert(name: String, schluessel: String, std: Variant) -> Variant:
	var s := _satz(name)
	var werte: Array = []
	for i in (s[0] as Array).size():
		var d: Dictionary = RINGE[str((s[0] as Array)[i])]["brakk_stufen"][clampi(int((s[1] as Array)[i]), 1, 3) - 1]
		if d.has(schluessel):
			werte.append(d[schluessel])
	return stapeln(schluessel, werte, std)


## Mehrere Werte desselben Schlüssels nach RING_STAPEL zusammenzählen.
static func stapeln(schluessel: String, werte: Array, std: Variant) -> Variant:
	if werte.is_empty():
		return std
	match str(RING_STAPEL.get(schluessel, "max")):
		"plus":
			var v := 1.0
			for w: Variant in werte:
				v += float(w) - 1.0
			return v
		"tempo":
			var t := 1.0
			for w: Variant in werte:
				t += 1.0 / float(w) - 1.0
			return 1.0 / t
		"summe":
			var su := 0.0
			for w: Variant in werte:
				su += float(w)
			if schluessel == "schutz":
				return minf(su, SCHUTZ_MAX)
			return int(su) if werte[0] is int else su
		"teilen":
			var m := INF
			for w: Variant in werte:
				m = minf(m, float(w))
			return m / float(werte.size())
		"anhaengen":
			var l: Array = []
			for w: Variant in werte:
				l.append_array(w as Array)
			return l
	var mx: Variant = werte[0]
	for w: Variant in werte:
		if float(w) > float(mx):
			mx = w
	return mx


## Gespeicherter Stand der Sätze (Zwischenstand).
func saetze_speichern() -> Dictionary:
	return {"held_st": Array(held_st), "held_bez": Array(held_bez), "held_runde": Array(held_runde), "pp_ringe": Array(pp_ringe),
		"pp_st": Array(pp_st), "pp_bez": Array(pp_bez), "pp_runde": Array(pp_runde), "pp_gewaehlt": pp_gewaehlt}


func saetze_laden(d: Dictionary) -> void:
	held_st.clear()
	held_bez.clear()
	held_runde.clear()
	pp_ringe.clear()
	pp_st.clear()
	pp_bez.clear()
	pp_runde.clear()
	var hs: Array = d.get("held_st", [])
	var hb: Array = d.get("held_bez", [])
	var hr: Array = d.get("held_runde", [])
	for i in ringe.size():
		held_st.append(int(hs[i]) if i < hs.size() else 1)
		held_bez.append(int(hb[i]) if i < hb.size() else int(RING_PREISE[0]))
		held_runde.append(int(hr[i]) if i < hr.size() else -1)
	var pr: Array = d.get("pp_ringe", [])
	var ps: Array = d.get("pp_st", [])
	var pb: Array = d.get("pp_bez", [])
	var pu: Array = d.get("pp_runde", [])
	for i in pr.size():
		if not RINGE.has(str(pr[i])):
			continue
		pp_ringe.append(str(pr[i]))
		pp_st.append(int(ps[i]) if i < ps.size() else 1)
		pp_bez.append(int(pb[i]) if i < pb.size() else int(RING_PREISE[0]))
		pp_runde.append(int(pu[i]) if i < pu.size() else -1)
	pp_gewaehlt = clampi(int(d.get("pp_gewaehlt", 0)), 0, maxi(0, pp_ringe.size() - 1))
