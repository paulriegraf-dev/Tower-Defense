class_name NemesisGewohnheiten
extends Node
## 22.11. (Paul, Nemesis Teil 4): Abgeschaute Angewohnheiten („Gelernt von dir“) in Befehl 24.
## Das Spiel zählt je Lauf und über die Läufe (nemesis.json), was Brakk oft tut. Wird ein Benannter kampfunfähig
## geschossen oder knapp vertrieben, während Brakk eine Angewohnheit gerade nutzt, kommt er bei der nächsten Elitewelle
## mit genau dieser zurück. Hat er keine und Brakk nutzt eine überdurchschnittlich oft, übernimmt er spätestens zum
## nächsten Lauf die häufigste. Eine je Person, ab Rang NEMESIS_GEWOHNHEIT_ZWEI_AB zwei. Beim ersten Einsatz im Lauf eine
## Zeile; danach steht die Angewohnheit mit ihrem Konter im Lexikon (Reiter Brakk).

const NAMEN := {
	"klettern": "Mauerkletterer", "sprengen": "Fallensteller", "tumble": "Doppelblitz", "klon": "Doppelgänger",
	"sabotage": "Fabrikwache", "medkit": "Med-Kit-Dieb", "fern": "Frontschild",
}
## was Brakk dafür oft tut
const BRAKK := {
	"klettern": "du kletterst oft auf Wälle", "sprengen": "du legst oft Sprengladungen", "tumble": "du tumblest im letzten Moment",
	"klon": "du nutzt die Klonmaschine", "sabotage": "du sabotierst Fabriken von hinten", "medkit": "du heilst an Med-Kits",
	"fern": "du kämpfst aus der Ferne mit dem Ladestrahl",
}
## was er dann tut
const WIRKUNG := {
	"klettern": "steigt selbst auf einen Erdwall (Stellung) und schießt von dort mit +1,5 Reichweite",
	"sprengen": "legt eine piepende Sprengfalle (3 s Zünder) an die Deckung, hinter der du am häufigsten standest",
	"tumble": "täuscht an (zweimaliges Aufblitzen) und schießt 0,35 s später – nach deinem Tumble-Fenster",
	"klon": "kommt mit einem schwachen Doppelgänger (halbes Leben, halber Schaden, flackert, kein Name)",
	"sabotage": "lauert an der Rückseite der gefährdetsten unzerstörten Fabrik",
	"medkit": "schnappt dir das nächste Med-Kit weg",
	"fern": "trägt einen Frontschild: von vorn kommen nur 25 % an",
}
const KONTER := {
	"klettern": "Oben hat er keine Deckung: Sprengladung an seinen Wall – oder von der Seite, wo die Stellung nicht schützt.",
	"sprengen": "Auf das Piepen hören und die alte Lieblingsdeckung meiden – 3 s reichen zum Weglaufen.",
	"tumble": "Den Doppelblitz abwarten und erst danach tumblen (oder seitlich laufen).",
	"klon": "Der Doppelgänger flackert und hat kein Namensschild – den Echten zuerst.",
	"sabotage": "Eine andere Fabrik sabotieren – er wartet an der gefährdetsten.",
	"medkit": "Med-Kits nicht in seiner Sichtlinie nehmen – oder ihn vorher ausschalten.",
	"fern": "Von der Seite oder von hinten treffen – oder nah heran, wo er sich drehen muss.",
}
const ZEILEN := {
	"klettern": ["Von hier oben sieht man alles. Das habe ich von Ihnen, Kommandant.", "Sie klettern gern. Ich jetzt auch."],
	"sprengen": ["Hören Sie das Piepen? Ihr Trick, Kommandant.", "Ladung gesetzt. Gelernt von den Besten."],
	"tumble": ["Rollen Sie ruhig. Ich warte.", "Ihr Purzelbaum ist zu pünktlich, Kommandant.", "Das habe ich von Ihnen, Kommandant – nur eben andersherum."],
	"klon": ["Zwei von mir. Das habe ich von Ihnen, Kommandant.", "Welcher bin wohl ich?"],
	"sabotage": ["Diese Fabrik? Nicht heute.", "Ich kenne Ihren Weg zur Rückseite, Kommandant."],
	"medkit": ["Suchen Sie das hier?", "Das Med-Kit nehme ich. Gelernt von Ihnen."],
	"fern": ["Schießen Sie ruhig von weitem. Ich habe vorgesorgt.", "Ihr Ladestrahl? Das habe ich von Ihnen gelernt – auszuhalten."],
}
const ARTEN: Array[String] = ["klettern", "sprengen", "tumble", "klon", "sabotage", "medkit", "fern"]
## so lange (s) gilt eine Angewohnheit nach dem Tun als „gerade in Gebrauch“ (Wall und Sabotage: solange es dauert)
const FENSTER := {"klettern": 1.0, "sprengen": 4.0, "tumble": 1.5, "klon": 6.0, "sabotage": 1.5, "medkit": 2.5, "fern": 2.5}

var nem: Nemesis
var zaehler_lauf := {}              # Angewohnheit -> wie oft in diesem Lauf
var zaehler := {}                   # Angewohnheit -> wie oft über alle Läufe (nemesis.json)
var gesehen := {}                   # Angewohnheit -> true, sobald Brakk sie einmal erlebt hat (Lexikon)
var deckung := {}                   # Zelle -> Sekunden, die Brakk dort in Deckung stand (dieser Lauf; Sprengfalle)
var log: Array = []                 # Prüfung: {"art", "id", "was"}
var _zuletzt := {}                  # Angewohnheit -> Zeit (o24.zeit) des letzten Tuns
var _oben := false
var _gesagt := {}                   # "<Person-ID>:<Angewohnheit>" -> true (erste Nutzung im Lauf)
var _falle_ab := {}                 # Einheit-ID -> frühester Zeitpunkt für die nächste Falle


func zeit() -> float:
	return nem.o24.zeit


static func name_von(a: String) -> String:
	return str(NAMEN.get(a, a))


## Angewohnheiten einer Person: eine, ab Rang NEMESIS_GEWOHNHEIT_ZWEI_AB zwei.
static func von_person(p: Dictionary) -> Array:
	var aus: Array = []
	if str(p.get("angewohnheit", "")) != "":
		aus.append(str(p["angewohnheit"]))
	if int(p.get("rang", 0)) >= Werte.NEMESIS_GEWOHNHEIT_ZWEI_AB and str(p.get("angewohnheit2", "")) != "":
		aus.append(str(p["angewohnheit2"]))
	return aus


func hat(e: Einheit, a: String) -> bool:
	return von_person(nem.person_von(e)).has(a)


# ------------------------------------------------------------------ Zählen, was Brakk tut

func zaehle(a: String) -> void:
	zaehler_lauf[a] = int(zaehler_lauf.get(a, 0)) + 1
	zaehler[a] = int(zaehler.get(a, 0)) + 1
	_zuletzt[a] = zeit()


## Tumble (ego_modus): zählt nur „im letzten Moment“ – ein Geschoss, Zielstrahl oder Wurf ist gerade nah.
func tumble() -> void:
	var bg: BrakkGeschosse = nem.spiel.brakk_geschosse
	var k: Kommandant = nem.spiel.kommandant
	if bg == null or k == null:
		return
	var nah := not bg.zielstrahlen.is_empty() or not bg.wuerfe.is_empty()
	for g: Dictionary in bg.geschosse:
		var p: Vector2 = (g["von"] as Vector2) + (g["r"] as Vector2) * float(g["s"])
		if p.distance_to(k.position) <= 3.0 * Werte.ZELLE:
			nah = true
	if nah:
		zaehle("tumble")


## Ladestrahl-Treffer aus der Ferne (Order24.treffer) – höchstens einmal je halbe Sekunde.
func fernschuss(e: Einheit) -> void:
	var k: Kommandant = nem.spiel.kommandant
	if k != null and e.position.distance_to(k.position) > Werte.NEMESIS_FERN_LANZE * Werte.ZELLE and zeit() - float(_zuletzt.get("fern", -9.0)) > 0.5:
		zaehle("fern")


## Welche Angewohnheit nutzt Brakk gerade? (oben auf dem Wall, Sabotage läuft, sonst das jüngste Tun im Fenster)
func aktuell() -> String:
	var k: Kommandant = nem.spiel.kommandant
	if k != null and k.oben:
		return "klettern"
	if not nem.o24.sabo.is_empty():
		return "sabotage"
	var beste := ""
	var t_best := -INF
	for a: String in _zuletzt:
		var t := float(_zuletzt[a])
		if zeit() - t <= float(FENSTER.get(a, 2.0)) and t > t_best:
			t_best = t
			beste = a
	return beste


## Kampfunfähig geschossen oder knapp vertrieben: die gerade genutzte Angewohnheit abschauen (gilt ab der nächsten Elitewelle).
func abschauen(p: Dictionary, wie: String) -> void:
	if not Nemesis.benannt(p):
		return
	var a := aktuell()
	if a == "" or von_person(p).has(a):
		return
	if int(p["rang"]) >= Werte.NEMESIS_GEWOHNHEIT_ZWEI_AB and str(p.get("angewohnheit", "")) != "" and str(p.get("angewohnheit2", "")) == "":
		p["angewohnheit2"] = a
	else:
		p["angewohnheit"] = a
	log.append({"art": a, "id": int(p["id"]), "was": "abgeschaut"})
	nem._chronik(p, "hat sich etwas abgeschaut (%s): %s" % [wie, name_von(a)])


## Laufende: Wer noch keine hat, übernimmt Brakks häufigste Angewohnheit – wenn sie überdurchschnittlich oft vorkam.
func lauf_ende() -> void:
	var summe := 0
	var haeufigste := ""
	for a: String in ARTEN:
		summe += int(zaehler.get(a, 0))
		if haeufigste == "" or int(zaehler.get(a, 0)) > int(zaehler.get(haeufigste, 0)):
			haeufigste = a
	var n := int(zaehler.get(haeufigste, 0))
	if n < Werte.NEMESIS_GEWOHNHEIT_MIN or float(n) <= float(summe) / float(ARTEN.size()):
		return
	for p: Dictionary in nem.benannte():
		if str(p.get("angewohnheit", "")) == "":
			p["angewohnheit"] = haeufigste
			nem._chronik(p, "hat sich deine häufigste Angewohnheit abgeschaut: %s" % name_von(haeufigste))


# ------------------------------------------------------------------ Ablauf

func weiter(dt: float) -> void:
	var o24 := nem.o24
	var k: Kommandant = nem.spiel.kommandant
	if k == null:
		return
	if k.oben and not _oben:
		zaehle("klettern")
	_oben = k.oben
	if o24.in_deckung:
		var z := o24.karte.zelle_bei(k.position)
		deckung[z] = float(deckung.get(z, 0.0)) + dt
	for id: int in nem._person_von.keys():
		var o: Object = instance_from_id(id)
		if not Nemesis.lebt(o):
			continue
		var e := o as Einheit
		var p: Dictionary = nem._person_von[id]
		var ag := von_person(p)
		if ag.is_empty():
			continue
		if ag.has("klettern") and e.zustand == Einheit.Zustand.AUF_POSTEN:
			gezeigt(e, "klettern")
		if ag.has("sprengen"):
			_falle_pruefen(e)
		if ag.has("medkit"):
			_medkit_pruefen(e)
		if ag.has("sabotage"):
			var r := _wache_feld()
			if r != Karte.KEINE and e.position.distance_to(o24.karte.mitte(r)) <= 1.2 * Werte.ZELLE:
				gezeigt(e, "sabotage")


## Erster Einsatz im Lauf: seine Zeile – und ab jetzt im Lexikon.
func gezeigt(e: Einheit, a: String) -> void:
	var p := nem.person_von(e)
	var schl := "%d:%s" % [int(p.get("id", -1)), a]
	if _gesagt.has(schl):
		return
	_gesagt[schl] = true
	gesehen[a] = true
	log.append({"art": a, "id": int(p.get("id", -1)), "was": "gezeigt"})
	var zeilen: Array = ZEILEN[a]
	nem.spiel.melde("%s: „%s“" % [Nemesis.voller_name(p), str(zeilen[randi() % zeilen.size()])], 4.0)


## Marschziel für die Angewohnheiten (KEINE = wie sonst).
func marschziel(e: Einheit) -> Vector2i:
	var o24 := nem.o24
	var hier := o24.karte.zelle_bei(e.position)
	if hat(e, "sprengen"):
		var f := _fallen_feld()
		if f != Karte.KEINE and zeit() >= float(_falle_ab.get(e.get_instance_id(), 0.0)):
			return o24._erreichbar_nahe(f, hier)
	if hat(e, "medkit"):
		var m := _naechstes_medkit(e)
		if m != Karte.KEINE:
			return o24._erreichbar_nahe(m, hier)
	if hat(e, "sabotage"):
		var r := _wache_feld()
		if r != Karte.KEINE:
			return o24._erreichbar_nahe(r, hier)
	return Karte.KEINE


## Deathscreen: mit welcher Angewohnheit er Brakk erwischt hat ("" = keiner) – oben auf dem Wall, Doppelblitz,
## Frontschild (er stand Brakk zugewandt), Falle (sie ging gerade hoch).
func womit(e: Einheit) -> String:
	if hat(e, "klettern") and e.zustand == Einheit.Zustand.AUF_POSTEN:
		return "klettern"
	if hat(e, "tumble"):
		return "tumble"
	if hat(e, "sprengen") and zeit() - float(_falle_ab.get(e.get_instance_id(), -99.0)) + Werte.NEMESIS_FALLE_ABSTAND < Werte.NEMESIS_FALLE_ZUENDER + 0.5:
		return "sprengen"
	if hat(e, "fern"):
		return "fern"
	return ""


## Order24.darf_in_stellung: der Mauerkletterer darf auf einen Erdwall – auch als Jäger, auch nah an Brakk.
func darf_auf_wall(e: Einheit) -> bool:
	return hat(e, "klettern")


## Treffer von Brakk: Frontschild – von vorn nur 25 %.
func schild_faktor(e: Einheit) -> float:
	if not hat(e, "fern"):
		return 1.0
	var k: Kommandant = nem.spiel.kommandant
	if k == null:
		return 1.0
	var vorn := (k.position.x < e.position.x) == e._sprite.flip_h   # er blickt zu Brakk: flip_h = nach links
	if not vorn:
		return 1.0
	gezeigt(e, "fern")
	return Werte.NEMESIS_FRONTSCHILD


## Doppelblitz: Schüsse auf Brakk 0,35 s verzögert (statt sofort) – mit zweimaligem Aufblitzen an der Mündung.
func verzoegerung(e: Einheit) -> float:
	if not hat(e, "tumble"):
		return 0.0
	gezeigt(e, "tumble")
	return Werte.NEMESIS_DOPPELBLITZ


## Doppelgänger zum Elitetrupp: halbes Leben, halber Schaden, flackert, kein Name.
func doppelgaenger(e: Einheit, p: Dictionary, quelle: Vector2i) -> Einheit:
	if not von_person(p).has("klon"):
		return null
	var d := nem.o24._neue_truppe(str(p["art"]), quelle, 4)
	d.max_leben = e.max_leben * 0.5
	d.leben = d.max_leben
	d.daten = d.daten.duplicate()
	d.daten["schaden"] = float(e.daten["schaden"]) * 0.5
	d.set_meta("nemesis_doppel", true)
	d.position = e.position + Vector2(Werte.ZELLE * 0.4, 0)
	var tw := d.create_tween().set_loops()   # flackert (die HD-Ansicht übernimmt die Durchsichtigkeit der Figur)
	tw.tween_property(d, "modulate:a", 0.35, 0.18)
	tw.tween_property(d, "modulate:a", 0.85, 0.22)
	gezeigt(e, "klon")
	return d


## Fabrik-Rückseite der gefährdetsten unzerstörten Fabrik draußen (am wenigsten Leben; lahme zuerst).
func _wache_feld() -> Vector2i:
	var o24 := nem.o24
	var beste := Karte.KEINE
	var wert := INF
	for z: Vector2i in o24.fabrik_hp:
		var v := float(o24.fabrik_hp[z]) / maxf(1.0, o24.wf("fabrik_leben")) + (0.0 if o24.lahm.has(z) else 1.0)
		if v < wert and o24.rueckseite.has(z):
			wert = v
			beste = o24.rueckseite[z]
	return beste


func _naechstes_medkit(e: Einheit) -> Vector2i:
	var beste := Karte.KEINE
	var d := INF   # das nächste, egal wie weit (er wartet dort in Sichtlinie)
	for m: Dictionary in nem.o24.medkits:
		var z: Vector2i = m["zelle"]
		if bool(m["da"]) and e.position.distance_to(nem.o24.karte.mitte(z)) < d:
			d = e.position.distance_to(nem.o24.karte.mitte(z))
			beste = z
	return beste


func _medkit_pruefen(e: Einheit) -> void:
	for m: Dictionary in nem.o24.medkits:
		if bool(m["da"]) and e.position.distance_to(nem.o24.karte.mitte(m["zelle"] as Vector2i)) <= 0.8 * Werte.ZELLE:
			m["da"] = false
			if m.get("knoten") != null and is_instance_valid(m["knoten"]):
				(m["knoten"] as Node3D).visible = false
			nem.spiel.melde("%s hat das Med-Kit eingesteckt." % Nemesis.voller_name(nem.person_von(e)), 2.5)
			log.append({"art": "medkit", "id": e.get_instance_id(), "was": "weg"})
			gezeigt(e, "medkit")


## Lieblingsdeckung: das Feld, auf dem Brakk in diesem Lauf am längsten in Deckung stand (mindestens 5 s).
func _fallen_feld() -> Vector2i:
	var beste := Karte.KEINE
	var t := 5.0
	for z: Vector2i in deckung:
		if float(deckung[z]) > t:
			t = float(deckung[z])
			beste = z
	return beste


func _falle_pruefen(e: Einheit) -> void:
	var f := _fallen_feld()
	if f == Karte.KEINE or zeit() < float(_falle_ab.get(e.get_instance_id(), 0.0)):
		return
	if e.position.distance_to(nem.o24.karte.mitte(f)) > 1.3 * Werte.ZELLE:
		return
	_falle_ab[e.get_instance_id()] = zeit() + Werte.NEMESIS_FALLE_ABSTAND
	var bg: BrakkGeschosse = nem.spiel.brakk_geschosse
	bg.falle(nem.o24.karte.mitte(f), Werte.NEMESIS_FALLE_ZUENDER, Werte.NEMESIS_FALLE_RADIUS * Werte.ZELLE, float(e.daten["schaden"]) * Werte.NEMESIS_FALLE_SCHADEN,
		"fabrik:%d,%d#%d" % [e.fabrik_zelle.x, e.fabrik_zelle.y, e.get_instance_id()])
	log.append({"art": "sprengen", "id": e.get_instance_id(), "was": "falle"})
	gezeigt(e, "sprengen")


# ------------------------------------------------------------------ Lexikon (Reiter Brakk)

## Karte fürs Lexikon: gesehene Angewohnheiten mit Wirkung und Konter, die anderen als „???“.
static func lexikon_karte(gesehen_liste: Dictionary) -> Dictionary:
	var abschnitte: Array = []
	var offen := 0
	for a: String in ARTEN:
		if gesehen_liste.has(a):
			abschnitte.append([name_von(a), Color("ffb84d"), ["Wenn %s: er %s." % [str(BRAKK[a]), str(WIRKUNG[a])], "Konter: " + str(KONTER[a])]])
		else:
			offen += 1
	if offen > 0:
		abschnitte.append(["???", Color("8b95a3"), ["%d Angewohnheit%s noch nicht gesehen – die Benannten schauen sich ab, was du oft tust." % [offen, "" if offen == 1 else "en"]]])
	return {"name": "Befehl 24 · Gelernt von dir", "unter": "Angewohnheiten der Benannten", "marke": "%d/%d" % [ARTEN.size() - offen, ARTEN.size()],
		"marke_farbe": Color("ffb84d"), "bild": {"symbol": "buch", "farbe": Color("ffb84d")}, "werte": [], "abschnitte": abschnitte}
