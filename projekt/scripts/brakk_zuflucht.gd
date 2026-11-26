class_name BrakkZuflucht
extends RefCounted
## E4 (26.11., Paul): Befehl 24, große Karte – drei Zufluchtsorte (Höhle im Niemandsland, Felsabsatz hinter jedem
## Außenposten). Ein Ring aus Erdwällen rundum (G, 26.11., Paul: vorher Fels), ein Eingang, kein Versteck: Türme und
## Stellungen nehmen Brakk dort nicht als Ziel, Bodentruppen schon.
## Je Ort ein Medkit-Depot (medkit_takt) und ein Sprengstoffkasten (ZUFLUCHT_LADUNG_SEK).
## Gegen Camping: Eine Uhr läuft, solange Brakk drin steht (draußen halb so schnell zurück). Bei ZUFLUCHT_WARNUNG_SEK
## warnt Sonde 7, bei ZUFLUCHT_VERLUST_SEK formen die Verteidiger den Ort um – Fabrik, Geschützturm und zwei Stellungen
## fallen vom Himmel, der Ort ist danach ein Lager.

const KREUZ := Color("7fe0ff")
const LAGER := Color("e08a4f")

var o24: Order24
var spiel: Node
var karte: Karte
var orte: Array = []        # je {"name", "felder", "eingang", "rechteck", "uhr", "gewarnt", "verloren", "medkit_uhr", "kasten_uhr"}
var protokoll: Array = []   # Prüfung: {"was", "bei", "ort", …}
var _erstmals := false
var _fall: Array = []       # Umformen: {"z", "art", "start", "ort", "teile"}
var _t := 0.0


func _init(p_o24: Order24, zufluchten: Array) -> void:
	o24 = p_o24
	spiel = o24.spiel
	karte = o24.karte
	for z: Dictionary in zufluchten:
		var ort := z.duplicate()
		ort.merge({"uhr": 0.0, "gewarnt": false, "verloren": false, "medkit_uhr": 0.0, "kasten_uhr": 0.0})
		orte.append(ort)


## Nach dem Aufbau der Karte: in jedem Ort ein Medkit und eine Sprengladung.
func einrichten() -> void:
	for ort: Dictionary in orte:
		var felder: Array = (ort["felder"] as Array).duplicate()
		felder.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.distance_squared_to(ort["eingang"]) > b.distance_squared_to(ort["eingang"]))
		o24.medkits.append({"zelle": felder[0], "da": true, "knoten": null, "zuflucht": ort["name"]})
		o24.ladungen_boden.append({"pos": karte.mitte(felder[mini(1, felder.size() - 1)]), "knoten": null, "bleibt": true, "zuflucht": ort["name"]})
	protokoll.append({"was": "eingerichtet", "bei": o24.zeit, "orte": orte.size()})


## Der (noch nicht verlorene, nicht ruhende) Ort, zu dem das Feld gehört; {} = keiner.
func ort_bei(z: Vector2i) -> Dictionary:
	for ort: Dictionary in orte:
		if not bool(ort["verloren"]) and not ruht(ort) and (ort["felder"] as Array).has(z):
			return ort
	return {}


## E7: Liegt der Ort im Kampfplatz eines Duells, ruht er (kein Schutz, keine Uhr, kein Depot) – die Felsen bleiben stehen.
func ruht(ort: Dictionary) -> bool:
	var kp: BrakkKampfplatz = o24.herausforderer.kampfplatz if o24.herausforderer != null else null
	return kp != null and kp.aktiv() and (ort["felder"] as Array).any(func(z: Vector2i) -> bool: return kp.innen(z))


func _fuss() -> Vector2:
	return spiel.ego._fuss2d() if spiel.ego != null else (spiel.kommandant as Kommandant).position


## Steht Brakk in einer Zuflucht? (dann zielen Türme und Stellungen nicht auf ihn)
func brakk_drin() -> bool:
	var k: Kommandant = spiel.kommandant
	return k != null and not k.gefallen and not ort_bei(karte.zelle_bei(_fuss())).is_empty()


## Gehört das Feld zu einem Ort samt Ring und Vorplatz? (Dort baut der Aufbau nichts hin.)
func bereich(z: Vector2i) -> bool:
	for ort: Dictionary in orte:
		if (ort["rechteck"] as Rect2i).grow(2).has_point(z):
			return true
	return false


## G: Gehört das Feld zum Erdwall-Ring einer Zuflucht (ohne den Eingang)? Den öffnet der Aufbau nicht.
func im_ring(z: Vector2i) -> bool:
	for ort: Dictionary in orte:
		var r: Rect2i = ort["rechteck"]
		if r.grow(1).has_point(z) and not r.has_point(z) and z != (ort["eingang"] as Vector2i):
			return true
	return false


## Je Sekunde (echte Sekunden).
func weiter(dt: float, k: Kommandant) -> void:
	_t += dt
	var hier := karte.zelle_bei(_fuss())
	for ort: Dictionary in orte:
		if bool(ort["verloren"]) or ruht(ort):
			continue
		var drin: bool = not k.gefallen and (ort["felder"] as Array).has(hier)
		if drin:
			ort["uhr"] = float(ort["uhr"]) + dt
			if not _erstmals:
				_erstmals = true
				spiel.melde(tr("Sonde 7: „Hier sehen dich die Türme nicht. Die Trupps schon.“"), 4.0)
				protokoll.append({"was": "betreten", "bei": o24.zeit, "ort": ort["name"]})
		else:
			ort["uhr"] = maxf(0.0, float(ort["uhr"]) - dt * Werte.ZUFLUCHT_RUECKLAUF)
			if float(ort["uhr"]) <= 0.0:
				ort["gewarnt"] = false
		if float(ort["uhr"]) >= Werte.ZUFLUCHT_WARNUNG_SEK and not bool(ort["gewarnt"]):
			ort["gewarnt"] = true
			spiel.melde(tr("Sonde 7: „Sie haben deine Stellung. Weg hier.“"), 4.0)
			Ton.spiele(spiel, "alert", -2.0)
			protokoll.append({"was": "warnung", "bei": o24.zeit, "ort": ort["name"], "uhr": float(ort["uhr"])})
		if float(ort["uhr"]) >= Werte.ZUFLUCHT_VERLUST_SEK:
			_verlieren(ort)
			continue
		_depot(ort, dt)
	_fall_weiter(dt)


## Medkit-Depot (liegt nach dem Aufheben medkit_takt Sekunden später wieder) und Sprengstoffkasten.
func _depot(ort: Dictionary, dt: float) -> void:
	for m: Dictionary in o24.medkits:
		if str(m.get("zuflucht", "")) == str(ort["name"]) and not bool(m["da"]):
			ort["medkit_uhr"] = float(ort["medkit_uhr"]) + dt
			if float(ort["medkit_uhr"]) >= o24.wf("medkit_takt"):
				ort["medkit_uhr"] = 0.0
				m["da"] = true
	var liegt := o24.ladungen_boden.any(func(l: Dictionary) -> bool: return str(l.get("zuflucht", "")) == str(ort["name"]))
	if liegt:
		ort["kasten_uhr"] = 0.0
		return
	ort["kasten_uhr"] = float(ort["kasten_uhr"]) + dt
	if float(ort["kasten_uhr"]) >= Werte.ZUFLUCHT_LADUNG_SEK:
		ort["kasten_uhr"] = 0.0
		var felder: Array = ort["felder"]
		o24.ladungen_boden.append({"pos": karte.mitte(felder[felder.size() / 2]), "knoten": null, "bleibt": true, "zuflucht": ort["name"]})
		protokoll.append({"was": "ladung", "bei": o24.zeit, "ort": ort["name"]})


# ------------------------------------------------------------------ Verlust: der Ort wird ein Lager

## Was fällt, je Ort: Fabrik innen, Geschützturm auf einem T-Stück am Rand (Turmfeld, zwei Stützen im Ring, eine
## innen), zwei Stellungen im Ring (G: auf den Erdwällen, die dort schon stehen). Felder, auf denen Brakk
## steht, bleiben aus.
func umbau(ort: Dictionary) -> Array:
	var r: Rect2i = ort["rechteck"]
	if str(ort["name"]) == "hoehle":
		var m := Vector2i(r.position.x + r.size.x / 2, r.position.y + r.size.y / 2)
		var turm := Vector2i(r.end.x, m.y)
		return [["fabrik", [m]], ["turm", [turm, turm + Vector2i(0, -1), turm + Vector2i(0, 1), turm + Vector2i(-1, 0)]],
			["stellung", [Vector2i(m.x, r.position.y - 1)]], ["stellung", [Vector2i(m.x, r.end.y)]]]
	# Felsabsatz: der Rand der Karte liegt oben (absatz_oben) bzw. unten
	var oben := r.position.y == 0
	var rand_zeile := r.position.y if oben else r.end.y - 1
	var innen_zeile := r.end.y - 1 if oben else r.position.y
	var ring_zeile := r.end.y if oben else r.position.y - 1
	var mx := r.position.x + r.size.x / 2
	return [["fabrik", [Vector2i(mx, rand_zeile)]], ["turm", [Vector2i(mx, ring_zeile), Vector2i(mx - 1, ring_zeile), Vector2i(mx + 1, ring_zeile), Vector2i(mx, innen_zeile)]],
		["stellung", [Vector2i(r.end.x, rand_zeile)]], ["stellung", [Vector2i(r.position.x - 1, rand_zeile)]]]


func _verlieren(ort: Dictionary) -> void:
	ort["verloren"] = true
	ort["uhr"] = 0.0
	spiel.melde(tr("Sonde 7: „Zu spät – sie bauen dort eine Basis.“"), 3.5)
	# Depot und Kasten verschwinden
	for m: Dictionary in o24.medkits.duplicate():
		if str(m.get("zuflucht", "")) == str(ort["name"]):
			if m["knoten"] != null and is_instance_valid(m["knoten"]):
				(m["knoten"] as Node).queue_free()
			o24.medkits.erase(m)
	for l: Dictionary in o24.ladungen_boden.duplicate():
		if str(l.get("zuflucht", "")) == str(ort["name"]):
			o24._ladung_weg(l)
	# Brakk wird zum Eingang geschoben
	var k: Kommandant = spiel.kommandant
	if (ort["felder"] as Array).has(karte.zelle_bei(_fuss())) or (ort["rechteck"] as Rect2i).has_point(karte.zelle_bei(_fuss())):
		var e: Vector2i = ort["eingang"]
		var r := (karte.mitte(e) - _fuss()).normalized()
		var ziel := _fuss() + r * minf(Werte.ZUFLUCHT_SCHIEBEN * Werte.ZELLE, _fuss().distance_to(karte.mitte(e)) + 0.6 * Werte.ZELLE)
		if spiel.ego != null and karte.ist_begehbar(karte.zelle_bei(ziel)) and karte.ist_frei(karte.zelle_bei(ziel)):
			spiel.ego._setze_fuss(ziel)
		elif k != null:
			k.position = ziel
	var i := 0
	for teil: Array in umbau(ort):
		_fall.append({"art": teil[0], "zellen": teil[1], "start": _t + Werte.ZUFLUCHT_FALL_TAKT * i, "ort": ort})
		i += 1
	protokoll.append({"was": "zuflucht_verloren", "bei": o24.zeit, "ort": ort["name"]})
	var f: BrakkFortschritt = k.fortschritt if k != null else null
	if f != null:
		f.protokoll.ereignis(spiel, "zuflucht_verloren", {"ort": ort["name"]})


func _fall_weiter(_dt: float) -> void:
	if _fall.is_empty():
		return
	var kp: BrakkKampfplatz = o24.herausforderer.kampfplatz if o24.herausforderer != null else null
	for f: Dictionary in _fall.duplicate():
		var s := _t - float(f["start"])
		var haupt: Vector2i = (f["zellen"] as Array)[0]
		if s < Werte.KAMPFPLATZ_SCHATTEN_SEK:
			if kp != null:
				kp._fallen_bild(haupt, clampf(s / Werte.KAMPFPLATZ_SCHATTEN_SEK, 0.0, 1.0), str(f["art"]) == "fabrik")
			continue
		if kp != null:
			kp._fallend_weg(haupt, true)
		_fall.erase(f)
		_aufschlag(str(f["art"]), f["zellen"] as Array, f["ort"] as Dictionary)
		if _fall.filter(func(x: Dictionary) -> bool: return x["ort"] == f["ort"]).is_empty():
			karte.pruefe_stuetzen()
			karte.aktualisiere_pfad()


## Ein Teil der neuen Basis schlägt auf (G: Ring-Felder sind schon Erdwälle). Steht Brakk auf dem Hauptfeld, bleibt es aus.
func _aufschlag(art: String, zellen: Array, ort: Dictionary) -> void:
	var brakk := karte.zelle_bei(_fuss())
	var haupt: Vector2i = zellen[0]
	if haupt == brakk:
		protokoll.append({"was": "ausgelassen", "bei": o24.zeit, "art": art})
		return
	match art:
		"fabrik":
			if karte.ist_frei(haupt) and o24._setze_fabrik(haupt, str(Werte.ALARM_TRUPPEN.pick_random()), 1):
				o24.fabrik_hp[haupt] = o24.wf("fabrik_leben")
				o24.rueckseite[haupt] = o24._rueck_feld(haupt)
				o24.routen[haupt] = o24._streifenweg(haupt)
				ort["fabrik"] = haupt
		"turm":
			for z: Vector2i in zellen:
				if z != brakk and karte.ist_frei(z):
					karte.setze(z, Karte.WALL)
			if karte.inhalt(haupt) == Karte.WALL and karte.freie_stuetzen(haupt).size() >= 3:
				karte.baue_aus(haupt, Karte.TURM, "geschuetz")
				o24.kern[haupt] = o24.wf("kern_leben")
		"stellung":
			if karte.ist_frei(haupt):
				karte.setze(haupt, Karte.WALL)
			if karte.inhalt(haupt) == Karte.WALL:
				karte.baue_aus(haupt, Karte.STELLUNG)
	for z: Vector2i in zellen:
		karte.fest[z] = true
	var p := karte.mitte(haupt)
	spiel.effekte.flaeche(p, Werte.ZELLE * 0.8, Color(0.62, 0.52, 0.38))
	Ton.am_ort(spiel, "tf-earth", p)
	protokoll.append({"was": "aufschlag", "bei": o24.zeit, "art": art, "z": haupt})


# ------------------------------------------------------------------ Anzeige

func hud_zeile() -> String:
	var ort := ort_bei(karte.zelle_bei(_fuss()))
	if ort.is_empty():
		return ""
	if bool(ort["gewarnt"]):
		return tr("Zuflucht – sie kommen (%d s)") % ceili(Werte.ZUFLUCHT_VERLUST_SEK - float(ort["uhr"]))
	return tr("Zuflucht")


## Minikarte der Ego-Sicht: Kreuz je Zuflucht (blinkt nach der Warnung), verlorene als Lager-Symbol.
func minikarte(ci: CanvasItem, o: Vector2, zelle: float) -> void:
	for ort: Dictionary in orte:
		var r: Rect2i = ort["rechteck"]
		var m := o + (Vector2(r.position) + Vector2(r.size) * 0.5) * zelle
		var a := maxf(3.0, zelle * 1.2)
		if bool(ort["verloren"]):
			ci.draw_rect(Rect2(m - Vector2(a, a), Vector2(a, a) * 2.0), LAGER, false, 1.5)
			continue
		if bool(ort["gewarnt"]) and int(Time.get_ticks_msec() / 250) % 2 == 0:
			continue
		ci.draw_line(m - Vector2(a, 0), m + Vector2(a, 0), KREUZ, 2.0)
		ci.draw_line(m - Vector2(0, a), m + Vector2(0, a), KREUZ, 2.0)
