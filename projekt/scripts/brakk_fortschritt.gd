class_name BrakkFortschritt
extends RefCounted
## 18.11.: Brakk-Mode – Brakks Fortschritt in einer Partie: Erfahrung und Stufen (1–10), freigeschaltete Fähigkeiten.
## Hängt am Kommandanten (überlebt also einen Fall und das Neuaufbauen der Ego-Sicht).

const STUFE_HOECHST := 10
const ERFAHRUNG_BIS := [0, 12, 30, 55, 90, 135, 190, 255, 330, 420]   # Gesamterfahrung, ab der Stufe 1..10 gilt
const XP_KILL := 1
const XP_WELLE := 10
const SCHADEN_JE_STUFE := 0.05        # +5 % Schussschaden je Stufe über 1
const LEBEN_JE_STUFE := 30.0          # +30 Leben je Stufe über 1
## Freischaltungen: Fähigkeit -> Stufe
const AB := {"tumble": 2, "sammeln": 3, "lanze": 5, "ulti": 7}
const NAMEN := {"tumble": "Tumble [Shift]", "sammeln": "Sammeln [Q]", "lanze": "Doppellanze [Rechtsklick]", "ulti": "Klonmaschine [R]"}
const ULTI_KILLS := 30               # so viele eigene Kills lädt die Ulti (Klonmaschine) auf
## 18.11.: Ringe für die linke Hand – am Lichtterminal der Basis gekauft (Budget). Jeder stärkt Brakks Pistolen und
## gibt passenden Truppen in seinem Feld (Ringfeld, [C]) die Stufe 3 mit seiner Fähigkeit. Farben = Abzeichen der Fähigkeit.
const RINGE := {
	"durchschuss": {"name": "Durchschlagring", "truppe": "scharfschuetze", "preis": 140,
		"brakk": "Schüsse gehen durch bis zu 2 Gegner", "feld": "Scharfschützen: Durchschuss"},
	"laser": {"name": "Glutstrahlring", "truppe": "scharfschuetze", "preis": 130,
		"brakk": "+30 % Schaden", "feld": "Scharfschützen: Laserstrahl"},
	"feuerteam": {"name": "Taktring", "truppe": "technogunner", "preis": 110,
		"brakk": "feuert 25 % schneller", "feld": "Technogunner: Feuerteam"},
	"minigun": {"name": "Wirbelring", "truppe": "technogunner", "preis": 120,
		"brakk": "Dauerfeuer wird immer schneller (bis 1,6×)", "feld": "Technogunner: Minigun (in der Stellung)"},
	"abpraller": {"name": "Sprungring", "truppe": "plasmawerfer", "preis": 140,
		"brakk": "Treffer springen zu weiteren Gegnern", "feld": "Plasmawerfer: Abpraller"},
	"brandfeld": {"name": "Brandring", "truppe": "plasmawerfer", "preis": 120,
		"brakk": "Treffer setzen den Boden in Brand", "feld": "Plasmawerfer: Brandfeld"},
	"plasmagel": {"name": "Gelring", "truppe": "plasmawerfer", "preis": 110,
		"brakk": "Treffer bremsen 2 Sekunden", "feld": "Plasmawerfer: Plasmagel (in der Stellung)"},
}
const RING_ZURUECK := 0.75           # Verkaufen: so viel vom Preis zurück (in derselben Bauphase gekauft: alles)
const FINGER_AB := [1, 3, 5, 7, 9]    # ab diesen Stufen ist je ein Finger mehr frei
const FELD_RADIUS := 1.5               # Ringfeld: Radius in Feldern

var erfahrung := 0
var stufe := 1
var basis_leben := 0.0
var aufstieg_zeit := -1.0             # für das Banner: Sekunden seit dem letzten Aufstieg (-1 = keins)
var neu_frei: Array[String] = []      # was beim letzten Aufstieg freigeschaltet wurde (für das Banner)
var ulti_ladung := 0                  # eigene Kills seit der letzten Ulti
var ulti_ab_welle := 0                # vorher geht die Ulti nicht (nach einem Einsatz: eine ganze Runde Pause)
var ringe: Array[String] = []          # getragene Ringe (je Finger einer)
var _gekauft_in := {}                  # Ring -> Runde, in der er gekauft wurde (volle Erstattung in derselben Bauphase)
var felder := {}                        # Ring -> Mitte seines Felds (2D-Welt); bleibt liegen, bis es neu geworfen wird
var gewaehlt := 0                      # Index des gewählten Rings (Mausrad)


func _init(brakk: Kommandant) -> void:
	basis_leben = brakk.max_leben


func frei(was: String) -> bool:
	return stufe >= int(AB.get(was, 1))


func schaden_faktor() -> float:
	return 1.0 + SCHADEN_JE_STUFE * float(stufe - 1)


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


## Freie Finger (Ringplätze) auf der aktuellen Stufe.
func finger() -> int:
	var n := 0
	for ab: int in FINGER_AB:
		if stufe >= ab:
			n += 1
	return n


func hat(ring: String) -> bool:
	return ringe.has(ring)


## Kaufen: "" = geklappt, sonst der Grund.
func kaufe(ring: String, spiel: Node) -> String:
	if ringe.has(ring):
		return "Den Ring trägt Brakk schon."
	if ringe.size() >= finger():
		return "Kein Finger frei – der nächste ab Stufe %d." % int(FINGER_AB[ringe.size()]) if ringe.size() < FINGER_AB.size() else "Alle fünf Finger tragen schon einen Ring."
	var preis := int(RINGE[ring]["preis"])
	if int(spiel.budget) < preis:
		return "Nicht genug Budget."
	spiel.budget -= preis
	ringe.append(ring)
	_gekauft_in[ring] = int(spiel.welle)
	return ""


func erstattung(ring: String, welle: int) -> int:
	var preis := int(RINGE[ring]["preis"])
	return preis if int(_gekauft_in.get(ring, -1)) == welle else int(preis * RING_ZURUECK)


func verkaufe(ring: String, spiel: Node) -> void:
	if not ringe.has(ring):
		return
	spiel.budget += erstattung(ring, int(spiel.welle))
	ringe.erase(ring)
	felder.erase(ring)
	gewaehlt = clampi(gewaehlt, 0, maxi(0, ringe.size() - 1))
	_gekauft_in.erase(ring)


## Faktoren für Brakks Pistolen aus den getragenen Ringen.
func schuss_schaden() -> float:
	return schaden_faktor() * (1.3 if hat("laser") else 1.0)


func schuss_takt() -> float:
	return 0.8 if hat("feuerteam") else 1.0


## Jedes Bild: Truppen in einem Ringfeld bekommen dessen Fähigkeit (wenn der Ring zu ihrem Typ passt und ihre Fabrik
## nicht ohnehin auf Stufe 3 ist), wer das Feld verlässt, verliert sie wieder.
func wirke(spiel: Node) -> void:
	var weite := FELD_RADIUS * Werte.ZELLE
	for e: Variant in spiel.einheiten:
		if not is_instance_valid(e) or not (e is Einheit) or e is Kommandant:
			continue
		var t := e as Einheit
		var passt := ""
		if not t.ist_pilot and (t.ausbaustufe < 3 or t.ring_faehigkeit != ""):
			for ring: String in felder:
				if str(RINGE[ring]["truppe"]) == t.art and t.position.distance_to(felder[ring] as Vector2) <= weite:
					passt = ring
					break
		if passt != "":
			t.ring_an(passt)
		else:
			t.ring_aus()
