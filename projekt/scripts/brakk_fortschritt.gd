class_name BrakkFortschritt
extends RefCounted
## 18.11.: Brakk-Mode – Brakks Fortschritt in einer Partie: Erfahrung und Stufen (1–10), freigeschaltete Fähigkeiten.
## Hängt am Kommandanten (überlebt also einen Fall und das Neuaufbauen der Ego-Sicht).

const STUFE_HOECHST := 10
const ERFAHRUNG_BIS := [0, 12, 30, 55, 90, 135, 190, 255, 330, 420]   # Gesamterfahrung, ab der Stufe 1..10 gilt
const XP_KILL := 1
const XP_WELLE := 10
const XP_KILL_ANTEIL := 0.5          # 18.11. (Paul): Kills geben nur die halbe Erfahrung (dreimal so viele Gegner)
const SCHADEN_START := 1.7             # 18.11. (Paul): Brakk ist die Hauptfigur – etwa 24 je Schuss, ein Hund fällt anfangs mit 2 Schüssen …
const SCHADEN_JE_STUFE := 0.10        # … und je Stufe 10 % stärker (Platz nach oben für Ringe und Stufen)
const LEBEN_JE_STUFE := 30.0          # +30 Leben je Stufe über 1
## Freischaltungen: Fähigkeit -> Stufe
const AB := {"tumble": 2, "anker": 3, "lanze": 4, "saeule": 6, "ulti": 7, "zeitlupe": 8}
const NAMEN := {"saeule": "Lichtsäule [X]", "zeitlupe": "Zeitlupe [V]", "tumble": "Tumble [Shift]", "anker": "Lichtanker [Q]", "lanze": "Doppellanze [Rechtsklick]", "ulti": "Klonmaschine [R]"}
const FREIE_WAELLE := 5               # 18.11. (Paul): so viele Erdwälle bekommt Brakk jede Runde geschenkt
const ULTI_KILLS := 30               # so viele eigene Kills lädt die Ulti (Klonmaschine) auf
## 18.11. (Paul): Ringe für die linke Hand – am Lichtterminal der Basis gekauft und ausgebaut (Budget).
##   Ringfeld ([C] in der Bauphase): Fabriken darin bauen die Truppe des Rings auf seiner Stufe
##   (Stufe 1: spezialisiert, 2: Wertepaket, 3: die Fähigkeit). Im Kampf liegen die Felder fest.
##   Aktiver Ring (Mausrad, jederzeit): gibt Brakks Pistolen seinen Effekt – immer nur einer.
## Farben = Abzeichen der Fähigkeit.
const RINGE := {
	"durchschuss": {"name": "Durchschlagring", "truppe": "scharfschuetze", "brakk": "Schüsse gehen durch bis zu 2 Gegner"},
	"laser": {"name": "Glutstrahlring", "truppe": "scharfschuetze", "brakk": "+30 % Schaden"},
	"feuerteam": {"name": "Taktring", "truppe": "technogunner", "brakk": "feuert 25 % schneller, kühlt schneller"},
	"minigun": {"name": "Wirbelring", "truppe": "technogunner", "brakk": "Dauerfeuer läuft an (bis 1,6×), heizt weniger"},
	"abpraller": {"name": "Sprungring", "truppe": "plasmawerfer", "brakk": "Treffer springen zu weiteren Gegnern"},
	"brandfeld": {"name": "Brandring", "truppe": "plasmawerfer", "brakk": "Treffer setzen den Boden in Brand"},
	"plasmagel": {"name": "Gelring", "truppe": "plasmawerfer", "brakk": "Treffer bremsen 2 Sekunden"},
}
const RING_PREISE := [200, 250, 500]   # Kauf (Stufe 1), Stufe 2, Stufe 3
const RING_ZURUECK := 0.75           # Verkaufen: so viel vom Bezahlten zurück (in derselben Bauphase gekauft: alles)
const FINGER_AB := [1, 3, 5, 7, 9]    # ab diesen Stufen ist je ein Finger mehr frei
const FELD_RADIUS := 2.0               # Ringfeld: Radius in Feldern (ein Haufen aus 4 Fabriken passt hinein)
const WECHSEL_SEK := 0.6               # Ring wechseln: so lange schüttelt Brakk die Hand, erst dann wirkt der neue Ring

var erfahrung := 0
var stufe := 1
var basis_leben := 0.0
var aufstieg_zeit := -1.0             # für das Banner: Sekunden seit dem letzten Aufstieg (-1 = keins)
var neu_frei: Array[String] = []      # was beim letzten Aufstieg freigeschaltet wurde (für das Banner)
var ulti_ladung := 0                  # eigene Kills seit der letzten Ulti
var kill_xp := 0.0                    # gesammelte Bruchteile der Kill-Erfahrung
var ulti_ab_welle := 0                # vorher geht die Ulti nicht (nach einem Einsatz: eine ganze Runde Pause)
var ringe: Array[String] = []          # getragene Ringe (je Finger einer)
var ring_stufen := {}                  # Ring -> Stufe 1..3
var _bezahlt := {}                     # Ring -> insgesamt bezahlt (für das Verkaufen)
var _gekauft_in := {}                  # Ring -> Runde des Kaufs (volle Erstattung in derselben Bauphase)
var felder := {}                       # Ring -> Mitte seines Felds (2D-Welt), in der Bauphase gesetzt
var gewaehlt := 0                      # Index des aktiven Rings (Mausrad)
var wechsel_rest := 0.0                # Ring wird gerade gewechselt: so lange wirkt keiner


func _init(brakk: Kommandant) -> void:
	basis_leben = brakk.max_leben


func frei(was: String) -> bool:
	return stufe >= int(AB.get(was, 1))


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
	erfahrung += xp
	var auf := 0
	while stufe < STUFE_HOECHST and erfahrung >= int(ERFAHRUNG_BIS[stufe]):
		stufe += 1
		auf += 1
	if auf > 0:
		neu_frei.clear()
		for k: String in AB:
			if int(AB[k]) > stufe - auf and int(AB[k]) <= stufe:
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
	var n := 0
	for ab: int in FINGER_AB:
		if stufe >= ab:
			n += 1
	return n


func hat(ring: String) -> bool:
	return ringe.has(ring)


func ring_stufe(ring: String) -> int:
	return int(ring_stufen.get(ring, 0))


## Der aktive Ring (wirkt auf Brakks Pistolen) – "" während des Wechsels oder ohne Ring.
func aktiv() -> String:
	if ringe.is_empty() or wechsel_rest > 0.0:
		return ""
	return ringe[clampi(gewaehlt, 0, ringe.size() - 1)]


## Kaufen (Stufe 1) oder die nächste Stufe: "" = geklappt, sonst der Grund.
func kaufe(ring: String, spiel: Node) -> String:
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
	return ""


func erstattung(ring: String, welle: int) -> int:
	var summe := int(_bezahlt.get(ring, 0))
	return summe if int(_gekauft_in.get(ring, -1)) == welle else int(summe * RING_ZURUECK)


func verkaufe(ring: String, spiel: Node) -> void:
	if not ringe.has(ring):
		return
	spiel.budget += erstattung(ring, int(spiel.welle))
	ringe.erase(ring)
	ring_stufen.erase(ring)
	_bezahlt.erase(ring)
	_gekauft_in.erase(ring)
	felder.erase(ring)
	gewaehlt = clampi(gewaehlt, 0, maxi(0, ringe.size() - 1))


## Ringfeld setzen (nur in der Bauphase); das zuletzt gesetzte gilt, wo sich Felder überlappen.
func setze_feld(ring: String, p: Vector2) -> void:
	felder.erase(ring)
	felder[ring] = p


## Faktoren für Brakks Pistolen aus dem aktiven Ring.
func schuss_schaden() -> float:
	return schaden_faktor() * (1.3 if aktiv() == "laser" else 1.0)


func schuss_takt() -> float:
	return 0.8 if aktiv() == "feuerteam" else 1.0


## Überhitzen (ego_modus.gd): Wirbelring – Schüsse heizen weniger; Taktring – kühlt schneller.
func hitze_faktor() -> float:
	return 0.7 if aktiv() == "minigun" else 1.0


func kuehl_faktor() -> float:
	return 1.5 if aktiv() == "feuerteam" else 1.0


## Jedes Bild (vom Kommandanten): in der Bauphase bauen Fabriken in einem Ringfeld die Truppe des Rings auf seiner Stufe.
## Der eigene Stand der Fabrik wird gemerkt ("ring_vorher") und kommt zurück, sobald kein Feld sie mehr trifft.
## Im Kampf bleibt alles, wie es zu Rundenbeginn war.
func wirke(spiel: Node) -> void:
	if int(spiel.phase) != 0:
		return
	var weite := FELD_RADIUS * Werte.ZELLE
	var k: Karte = spiel.karte
	for z: Vector2i in spiel.fabriken:
		if k.paar.has(z):
			continue   # Pilotenfabrik einer Batterie
		var fab: Dictionary = spiel.fabriken[z]
		var ziel := ""
		for ring: String in felder:
			if k.mitte(z).distance_to(felder[ring] as Vector2) <= weite:
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
