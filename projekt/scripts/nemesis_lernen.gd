class_name NemesisLernen
extends Node
## 22.11. (Paul, Nemesis Teil 5): Lernen der Eliten in Befehl 24 (Sutton/Barto 2.4 und 2.6, einfach gehalten).
##  - Vor jeder Begegnung wählt jede Elite eine von vier Taktiken: direkt, Flanke, Hinterhalt (an Med-Kit, Ringterminal
##    oder der nächsten unzerstörten Fabrik warten), Sperrfeuer (Abstand halten, Brakk in Deckung zwingen). Wert je
##    Taktik = Brakk zugefügter Schaden minus eigener Schaden in der Begegnung (beides in Prozent des Lebens), nachgeführt
##    mit fester Schrittweite NEMESIS_ALPHA; Auswahl mit UCB-Aufschlag. Die Werte gehören zur Person (nemesis.json).
##  - Aufenthaltskarte (nur dieser Lauf): je Feld Brakks Zeit und seine Kills. Nach Sichtverlust suchen Eliten zuerst an
##    seinen häufigsten Orten und meiden Felder, von denen aus er oft getötet hat. Einfache Truppen suchen wie bisher.
##  - Antwort auf den Spielstil (Einordnung wie im Siegbild): Saboteur → eine Elite wird Fabrikwache; Geist → breitere
##    Suche, Hinterhalte; Berserker → Sperrfeuer, einer vorn und zwei dahinter.
##  - Lesbarkeit: Sonde 7 kündigt jede Anpassung an, sobald sie greift; jede Taktik hat ein erkennbares Verhalten.

const NAMEN := {"direkt": "direkter Angriff", "flanke": "Flanke", "hinterhalt": "Hinterhalt", "sperrfeuer": "Sperrfeuer"}
## für den Deathscreen
const TEXT := {"direkt": "im direkten Angriff", "flanke": "über die Flanke", "hinterhalt": "aus dem Hinterhalt", "sperrfeuer": "mit Sperrfeuer aus der Distanz"}
const STIL_TAKTIK := {"Geist": "hinterhalt", "Berserker": "sperrfeuer"}

var nem: Nemesis
var aufenthalt := {}                # Zelle -> Sekunden, die Brakk dort war (dieser Lauf)
var kill_orte := {}                 # Zelle -> Kills, die Brakk von dort aus gemacht hat
var stil := ""                      # Antwort auf diesen Spielstil (Saboteur / Geist / Berserker)
var wache_id := -1                  # Einheit-ID der Fabrikwache (Saboteur)
var protokoll: Array = []           # Prüfung: {"was", …}
var _taktik := {}                   # Einheit-ID -> {"t", "seite", "fertig"}
var _such := {}                     # Einheit-ID -> {"z", "bis"}
var _stil_uhr := 0.0
var _ansage_ab := -99.0


func zeit() -> float:
	return nem.o24.zeit


static func name_von(t: String) -> String:
	return str(NAMEN.get(t, t))


## Taktikwerte einer Person (angelegt, wenn sie fehlen): {"q": {Taktik: Wert}, "n": {Taktik: Anzahl}}
static func werte(p: Dictionary) -> Dictionary:
	var tk: Variant = p.get("taktik", {})
	if not (tk is Dictionary):
		tk = {}
		p["taktik"] = tk
	var d := tk as Dictionary
	if not (d.get("q", null) is Dictionary):
		d["q"] = {}
	if not (d.get("n", null) is Dictionary):
		d["n"] = {}
	for t: String in Werte.NEMESIS_TAKTIKEN:
		(d["q"] as Dictionary)[t] = float((d["q"] as Dictionary).get(t, 0.0))
		(d["n"] as Dictionary)[t] = int((d["n"] as Dictionary).get(t, 0))
	return d


## Bevorzugte Taktik (höchster Wert unter den schon versuchten) – "" ohne Erfahrung.
static func beste(p: Dictionary) -> String:
	var d := werte(p)
	var b := ""
	for t: String in Werte.NEMESIS_TAKTIKEN:
		if int((d["n"] as Dictionary)[t]) > 0 and (b == "" or float((d["q"] as Dictionary)[t]) > float((d["q"] as Dictionary)[b])):
			b = t
	return b


## UCB: noch nie versuchte zuerst, sonst Q + c·√(ln t / N) (+ Aufschlag für die Antwort auf den Spielstil).
func waehlen(p: Dictionary) -> String:
	var d := werte(p)
	var q: Dictionary = d["q"]
	var n: Dictionary = d["n"]
	var summe := 1
	for t: String in Werte.NEMESIS_TAKTIKEN:
		summe += int(n[t])
	var wahl := ""
	var wert := -INF
	for t: String in Werte.NEMESIS_TAKTIKEN:
		if int(n[t]) == 0:
			return t
		var v := float(q[t]) + Werte.NEMESIS_UCB_C * sqrt(log(float(summe)) / float(n[t]))
		if str(STIL_TAKTIK.get(stil, "")) == t:
			v += Werte.NEMESIS_STIL_BONUS
		if v > wert:
			wert = v
			wahl = t
	return wahl


## Wert nachführen: Q ← Q + α (R − Q).
func lernen(p: Dictionary, t: String, r: float) -> void:
	var d := werte(p)
	(d["q"] as Dictionary)[t] = float((d["q"] as Dictionary)[t]) + Werte.NEMESIS_ALPHA * (r - float((d["q"] as Dictionary)[t]))
	(d["n"] as Dictionary)[t] = int((d["n"] as Dictionary)[t]) + 1


## Belohnung einer Begegnung: Schaden an Brakk minus eigener Schaden, je in Prozent des (eigenen bzw. Brakks) Lebens.
func belohnung(an_brakk: float, erlitten: float, e: Einheit) -> float:
	var k: Kommandant = nem.spiel.kommandant
	var brakk_max := k.max_leben if k != null else 1000.0
	return 100.0 * an_brakk / maxf(1.0, brakk_max) - 100.0 * erlitten / maxf(1.0, e.max_leben)


func taktik_von(e: Einheit) -> String:
	return str((_taktik.get(e.get_instance_id(), {}) as Dictionary).get("t", ""))


## Neue Taktik für die nächste Begegnung (bei Spawn und nach jeder Begegnung).
func neue_taktik(e: Einheit, p: Dictionary) -> void:
	var vorher := taktik_von(e)
	var t := waehlen(p)
	_taktik[e.get_instance_id()] = {"t": t, "seite": 1.0 if Zufall.f() < 0.5 else -1.0, "fertig": false}
	protokoll.append({"was": "taktik", "t": t, "id": int(p.get("id", -1))})
	# greift die Erfahrung (bewährte Taktik, nicht nur ausprobiert), sagt Sonde 7 es an
	if t != vorher and t == beste(p) and int((werte(p)["n"] as Dictionary)[t]) >= 2 and Nemesis.benannt(p):
		_ansage_taktik(e, p, t)


## Begegnung vorbei: Wert der Taktik nachführen, dann die nächste wählen.
func begegnung_ende(e: Einheit, p: Dictionary, b: Dictionary) -> void:
	var t := str(b.get("taktik", taktik_von(e)))
	if t == "":
		return
	var r := belohnung(float(b.get("an_brakk", 0.0)), float(b.get("erlitten", 0.0)), e)
	lernen(p, t, r)
	protokoll.append({"was": "gelernt", "t": t, "r": r, "id": int(p.get("id", -1))})
	if Nemesis.lebt(e):
		neue_taktik(e, p)


## Brakk hat getötet – von seinem Feld aus (Aufenthaltskarte).
func kill() -> void:
	var k: Kommandant = nem.spiel.kommandant
	if k != null:
		var z := nem.o24.karte.zelle_bei(k.position)
		kill_orte[z] = int(kill_orte.get(z, 0)) + 1


# ------------------------------------------------------------------ Ablauf

func weiter(dt: float) -> void:
	var k: Kommandant = nem.spiel.kommandant
	if k == null:
		return
	var z := nem.o24.karte.zelle_bei(k.position)
	aufenthalt[z] = float(aufenthalt.get(z, 0.0)) + dt
	_stil_uhr -= dt
	if _stil_uhr <= 0.0:
		_stil_uhr = Werte.NEMESIS_STIL_TAKT
		if nem.o24.jagd:
			stil_pruefen()
	if stil == "Saboteur" and not Nemesis.lebt(instance_from_id(wache_id) if wache_id > 0 else null):
		_wache_waehlen()


## Spielstil wie im Siegbild einordnen; bei einem Wechsel antworten (und ansagen).
func stil_pruefen() -> void:
	var neu := str(nem.o24.spielstil()[0])
	if neu == stil:
		return
	stil = neu
	protokoll.append({"was": "stil", "stil": stil})
	match stil:
		"Saboteur":
			_wache_waehlen()
		"Geist":
			_ansage("Analyse: Ziel meidet den Kampf. Suchgebiet erweitert, Hinterhalte an den Med-Kits.", true)
		"Berserker":
			_ansage("Analyse: Ziel sucht den Nahkampf. Ein Mann vorn, zwei dahinter – Sperrfeuer.", true)


## Saboteur: eine Elite übernimmt die gefährdetste Fabrik (Benannte zuerst).
func _wache_waehlen() -> void:
	var beste_e: Einheit = null
	for id: int in nem._person_von:
		var o: Object = instance_from_id(id)
		if Nemesis.lebt(o) and (beste_e == null or (Nemesis.benannt(nem._person_von[id] as Dictionary) and not Nemesis.benannt(nem.person_von(beste_e)))):
			beste_e = o as Einheit
	wache_id = beste_e.get_instance_id() if beste_e != null else -1
	if beste_e == null or nem.gewohnheiten == null:
		return
	var f := nem.gewohnheiten._wache_feld()
	if f == Karte.KEINE:
		return
	var p := nem.person_von(beste_e)
	var wer := Nemesis.voller_name(p) if Nemesis.benannt(p) else "Eine Elite"
	_ansage("Analyse: Ziel sabotiert. %s übernimmt die Fabrik %s." % [wer, _himmel(nem.o24.karte.mitte(f))], true)
	protokoll.append({"was": "wache", "id": wache_id})


## Marschziel nach Taktik (KEINE = wie der Trupp). Fabrikwache und Berserker-Formation gehen vor.
func marschziel(e: Einheit) -> Vector2i:
	var o24 := nem.o24
	var p := nem.person_von(e)
	if p.is_empty():
		return Karte.KEINE
	var id := e.get_instance_id()
	var hier := o24.karte.zelle_bei(e.position)
	if id == wache_id and nem.gewohnheiten != null:
		var f := nem.gewohnheiten._wache_feld()
		if f != Karte.KEINE:
			return o24._erreichbar_nahe(f, hier)
	if not _taktik.has(id):
		neue_taktik(e, p)
	var k: Kommandant = nem.spiel.kommandant
	if k == null or o24.bekannt == Karte.KEINE:
		return Karte.KEINE
	var bp := o24.karte.mitte(o24.bekannt)
	var nr := int(o24.jaeger.get(id, -1))
	if stil == "Berserker" and nr >= 0 and nr < o24.trupps.size():
		var m: Array = ((o24.trupps[nr] as Dictionary)["mitglieder"] as Array).filter(func(x: Variant) -> bool: return Nemesis.lebt(x))
		var i := m.find(e)
		if i > 0:
			var vorn := m[0] as Einheit   # einer vorn, die anderen zwei Felder hinter ihm
			var hinten := vorn.position + (vorn.position - bp).normalized() * 2.0 * Werte.ZELLE + (vorn.position - bp).normalized().orthogonal() * (1.2 if i % 2 == 1 else -1.2) * Werte.ZELLE
			return o24._erreichbar_nahe(o24._freies_feld_bei(hinten, hier), hier)
	var s: Dictionary = _taktik[id]
	var d := e.position.distance_to(k.position)
	match str(s["t"]):
		"flanke":
			if bool(s["fertig"]):
				return Karte.KEINE
			var punkt := bp + (bp - e.position).normalized().orthogonal() * float(s["seite"]) * Werte.NEMESIS_FLANKE * Werte.ZELLE
			if e.position.distance_to(punkt) <= 1.5 * Werte.ZELLE or d <= 3.5 * Werte.ZELLE:
				s["fertig"] = true
				return Karte.KEINE
			return o24._erreichbar_nahe(o24._freies_feld_bei(punkt, hier), hier)
		"hinterhalt":
			if bool(s["fertig"]):
				return Karte.KEINE
			if d <= Werte.NEMESIS_HINTERHALT_LOS * Werte.ZELLE and o24.karte.sicht_frei(e.position, k.position):
				s["fertig"] = true   # er kommt vorbei: los
				return Karte.KEINE
			var ort := hinterhalt_ort(e)
			return o24._erreichbar_nahe(ort, hier) if ort != Karte.KEINE else Karte.KEINE
		"sperrfeuer":
			var r := e.reichweite_jetzt() * Werte.ZELLE
			if d < r - 0.6 * Werte.ZELLE:
				return o24._erreichbar_nahe(o24._freies_feld_bei(e.position + (e.position - k.position).normalized() * 2.0 * Werte.ZELLE, hier), hier)
			if d <= r + 0.4 * Werte.ZELLE:
				return hier   # am Rand der Reichweite stehen bleiben und feuern
	return Karte.KEINE


## Im Gehen schießen statt stehen zu bleiben (Einheit: wie in der letzten Runde) – direkt und Flanke rücken nach,
## Sperrfeuer weicht so zurück.
func drueckt(e: Einheit) -> bool:
	var t := taktik_von(e)
	if t == "direkt" or (t == "flanke" and not bool((_taktik[e.get_instance_id()] as Dictionary)["fertig"])):
		return true
	if t == "sperrfeuer":
		var k: Kommandant = nem.spiel.kommandant
		return k != null and e.position.distance_to(k.position) < e.reichweite_jetzt() * Werte.ZELLE - 0.6 * Werte.ZELLE
	return false


## Wo der Hinterhalt liegt: Med-Kit (liegt eins), Ringterminal, sonst die Rückseite der nächsten unzerstörten Fabrik.
func hinterhalt_ort(e: Einheit) -> Vector2i:
	var o24 := nem.o24
	var beste := Karte.KEINE
	var d := INF
	for m: Dictionary in o24.medkits:
		var z: Vector2i = m["zelle"]
		if bool(m["da"]) and e.position.distance_to(o24.karte.mitte(z)) < d:
			d = e.position.distance_to(o24.karte.mitte(z))
			beste = z
	if beste == Karte.KEINE and o24.terminal != Karte.KEINE and not o24.hq_eingenommen:
		beste = o24._freies_feld_nahe(o24.terminal + Vector2i(-1, 0), 1)
	if beste == Karte.KEINE:
		for f: Vector2i in o24.rueckseite:
			if o24.fabrik_hp.has(f) and e.position.distance_to(o24.karte.mitte(f)) < d:
				d = e.position.distance_to(o24.karte.mitte(f))
				beste = o24.rueckseite[f]
	return beste


## Suche nach Sichtverlust (Order24._trupp_ziel, Modus „suche“): Eliten zuerst an Brakks häufigsten Orten um den
## letzten Punkt (Geist: doppelt so weit), nie auf Feldern, von denen aus er oft getötet hat. KEINE = wie bisher.
func suchziel(e: Einheit, t: Dictionary) -> Vector2i:
	if nem.person_von(e).is_empty():
		return Karte.KEINE
	var id := e.get_instance_id()
	var s: Dictionary = _such.get(id, {})
	var hier := nem.o24.karte.zelle_bei(e.position)
	if not s.is_empty() and zeit() < float(s["bis"]) and hier != (s["z"] as Vector2i):
		return s["z"]
	var mitte: Vector2i = t["zuletzt"]
	var weite := Werte.NEMESIS_SUCH_FELDER * (2.0 if stil == "Geist" else 1.0)
	var orte: Array = []
	for z: Vector2i in aufenthalt:
		if Vector2(z - mitte).length() <= weite and not gefaehrlich(z) and nem.o24.karte.ist_begehbar(z):
			orte.append(z)
	if orte.is_empty():
		return Karte.KEINE
	orte.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return float(aufenthalt[a]) > float(aufenthalt[b]))
	var nr := maxi(0, (t["mitglieder"] as Array).find(e))
	var ziel: Vector2i = orte[mini(nr, mini(2, orte.size() - 1))]   # die ersten drei Orte, je Mitglied einer
	ziel = nem.o24._erreichbar_nahe(ziel, hier)
	_such[id] = {"z": ziel, "bis": zeit() + 6.0}
	protokoll.append({"was": "suche", "z": ziel})
	return ziel


## Feld (oder Nachbar), von dem aus Brakk mindestens NEMESIS_KILL_ORT-mal getötet hat.
func gefaehrlich(z: Vector2i) -> bool:
	for k: Vector2i in kill_orte:
		if int(kill_orte[k]) >= Werte.NEMESIS_KILL_ORT and absi(k.x - z.x) <= 1 and absi(k.y - z.y) <= 1:
			return true
	return false


# ------------------------------------------------------------------ Ansagen

func _ansage_taktik(e: Einheit, p: Dictionary, t: String) -> void:
	var wer := Nemesis.voller_name(p)
	match t:
		"direkt":
			_ansage("Analyse: Ziel weicht kaum aus. %s geht direkt rein." % wer)
		"flanke":
			_ansage("Analyse: Ziel bevorzugt den %s. %s nimmt die Flanke." % [_lieblingsseite(), wer])
		"hinterhalt":
			var ort := hinterhalt_ort(e)
			var was := "am Med-Kit"
			if ort != Karte.KEINE and nem.o24.terminal != Karte.KEINE and Vector2(ort - nem.o24.terminal).length() <= 2.0:
				was = "am Ringterminal"
			elif ort != Karte.KEINE and nem.o24.rueckseite.values().has(ort):
				was = "an der Fabrik %s" % _himmel(nem.o24.karte.mitte(ort))
			_ansage("Analyse: Ziel kommt wieder. %s wartet %s." % [wer, was])
		"sperrfeuer":
			_ansage("Analyse: Ziel sucht den Nahkampf. %s hält Abstand und gibt Sperrfeuer." % wer)


func _ansage(text: String, immer: bool = false) -> void:
	if not immer and zeit() < _ansage_ab:
		return
	_ansage_ab = zeit() + Werte.NEMESIS_ANSAGE_ABSTAND
	protokoll.append({"was": "ansage", "text": text})
	nem.spiel.melde("Sonde 7: „%s“" % text, 5.0)
	print("NEMESIS Sonde 7: %s" % text)


## Wo Brakk sich meist aufhält, als Himmelsrichtung (vom Kartenmittelpunkt aus).
func _lieblingsseite() -> String:
	var summe := Vector2.ZERO
	var t := 0.0
	for z: Vector2i in aufenthalt:
		summe += nem.o24.karte.mitte(z) * float(aufenthalt[z])
		t += float(aufenthalt[z])
	if t <= 0.0:
		return "Süden"
	return _himmel(summe / t, true)


## Himmelsrichtung eines Punkts vom Kartenmittelpunkt aus („Ost“ bzw. „Osten“).
func _himmel(p: Vector2, lang: bool = false) -> String:
	var m := nem.o24.karte.mitte(Vector2i(roundi((Werte.ZONE_SPALTEN + Werte.SPALTEN) * 0.5), roundi(Werte.ZEILEN * 0.5)))
	var d := p - m
	var w := ""
	if absf(d.x) > absf(d.y):
		w = "Ost" if d.x > 0.0 else "West"
	else:
		w = "Süd" if d.y > 0.0 else "Nord"
	return w + "en" if lang else w


# ------------------------------------------------------------------ wie Brakk spielt (26.11., für den Herausforderer)

var treffer_abstaende: Array = []   # Felder, aus denen Brakk getroffen hat (die letzten HERAUSFORDERER_MERKEN)
var bewegungen := {"sprung": 0, "tumble": 0, "links": 0, "rechts": 0, "zurueck": 0, "vor": 0}


## Brakk hat eine Truppe getroffen – aus welcher Entfernung?
func treffer_abstand(e: Einheit) -> void:
	var k: Kommandant = nem.spiel.kommandant
	if k == null:
		return
	treffer_abstaende.append(e.position.distance_to(k.position) / Werte.ZELLE)
	if treffer_abstaende.size() > Werte.HERAUSFORDERER_MERKEN:
		treffer_abstaende.pop_front()


## Sprung oder Tumble; `r` beim Tumble: Richtung zur Blickrichtung (x rechts, y vorwärts).
func bewegung(art: String, r: Vector2 = Vector2.ZERO) -> void:
	bewegungen[art] = int(bewegungen.get(art, 0)) + 1
	if art == "tumble":
		var wohin := "zurueck" if r.y < -0.5 else ("links" if r.x < -0.3 else ("rechts" if r.x > 0.3 else "vor"))
		bewegungen[wohin] = int(bewegungen[wohin]) + 1


## Die Kennwerte: Lieblingsabstand beim Schießen (Median), Sprünge und Tumble je Minute Kampf, Vorzugsrichtung beim
## Ausweichen, die seltener genommene Seite und ob er auf den Wällen kämpft.
func kennwerte() -> Dictionary:
	var abstand := Werte.HERAUSFORDERER_ABSTAND_SONST
	if treffer_abstaende.size() >= 5:
		var s := treffer_abstaende.duplicate()
		s.sort()
		abstand = float(s[s.size() / 2])
	var k: Kommandant = nem.spiel.kommandant
	var zaehler: Dictionary = k.fortschritt.zaehler if k != null and k.fortschritt != null else {}
	var kampf := float(zaehler.get("kampf_sek", 0.0))
	var aktionen := int(bewegungen["sprung"]) + int(bewegungen["tumble"])
	var je_min := 60.0 * aktionen / maxf(60.0, kampf if kampf > 0.0 else nem.o24.zeit)
	var seite := ""
	var meiste := 0
	for w: String in ["links", "rechts", "zurueck"]:
		if int(bewegungen[w]) > meiste:
			meiste = int(bewegungen[w])
			seite = w
	return {"abstand": snappedf(clampf(abstand, 3.0, 11.0), 0.1), "je_min": snappedf(je_min, 0.1),
		"takt": clampf(60.0 / maxf(0.1, je_min), Werte.HERAUSFORDERER_AKTION_TAKT.x, Werte.HERAUSFORDERER_AKTION_TAKT.y),
		"sprung_anteil": float(bewegungen["sprung"]) / maxf(1.0, aktionen) if aktionen > 0 else 0.4,
		"seite": seite, "selten": "rechts" if int(bewegungen["rechts"]) <= int(bewegungen["links"]) else "links",
		"wall": float(zaehler.get("wall_sek", 0.0)) > Werte.HERAUSFORDERER_WALL_ANTEIL * maxf(30.0, kampf)}


## Für die Karte: „hält 7 Felder Abstand · weicht am liebsten nach links aus“
static func duell_text(p: Dictionary) -> String:
	var d: Variant = p.get("duell", {})
	if not (d is Dictionary) or (d as Dictionary).is_empty():
		return ""
	var w := d as Dictionary
	var teile := PackedStringArray(["hält %d Felder Abstand" % roundi(float(w.get("abstand", 0.0)))])
	var seite := str(w.get("seite", ""))
	if seite != "":
		teile.append("weicht am liebsten %s aus" % str({"links": "nach links", "rechts": "nach rechts", "zurueck": "nach hinten"}[seite]))
	if float(w.get("je_min", 0.0)) > 0.0:
		teile.append("%d Sprünge und Tumble je Minute" % roundi(float(w["je_min"])))
	if bool(w.get("wall", false)):
		teile.append("kämpft auf den Wällen")
	return " · ".join(teile)
