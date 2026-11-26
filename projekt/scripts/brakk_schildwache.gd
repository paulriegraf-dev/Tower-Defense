class_name BrakkSchildwache
extends RefCounted
## 26.11. (Paul, Prompt D2): Befehl 24 – die Besatzung der Fabriken im Schild steht nicht mehr nur herum.
##
##  - Streife: zu zweit auf einem Ring aus begehbaren Feldern am Schildrand (innen bis knapp außen) (der Vordermann läuft vor,
##    der zweite ein Feld dahinter). Wer Brakk in Reichweite sieht, bleibt stehen und schießt (einheit.gd) – auch durch
##    die Schildkante hinaus, sie hält keine Schüsse auf.
##  - Ausfall: sieht einer Brakk näher als ausfall_sicht, läuft sein Paar aus dem Schild auf ihn zu, höchstens
##    ausfall_sek lang, dann zurück auf den Ring. Je Schild höchstens ein Ausfall zugleich, danach ausfall_pause.
##  - hq_aggro (order24) und Alarm gehen vor.

const RING_INNEN := 1.7   # Felder unter dem Schildradius: so weit innen liegt der Ring höchstens …
const RING_AUSSEN := -0.8 # … und höchstens so weit darüber (Paul: „am Schildrand“ – innen ist die Zitadelle oft verbaut)

var o24: Order24
var _ring := {}       # Schild-Nummer -> Array[Vector2i], im Uhrzeigersinn
var _idx := {}        # Vordermann (instance id) -> Ring-Index
var _richtung := {}   # Vordermann -> +1 / -1
var _paar := {}       # instance id -> Array (das Paar, Vordermann zuerst)
var ausfall := {}     # Schild-Nummer -> {"paar": Array, "bis": float, "ziel": Vector2i}
var _pause_bis := {}  # Schild-Nummer -> Zeit
var ausfaelle := 0    # gezählt, für Tests und Auswertung
var _mitglied := {}   # instance id -> true: hat sich im Schild aufgehalten (nur die gehören zur Besatzung)
var _rueckweg := {}   # instance id -> true: nach dem Ausfall auf dem Weg zurück (schießt im Gehen)

const MITGLIED_RAND := 1.0   # Felder über den Schildradius hinaus, in denen eine Truppe noch als „im Schild“ zählt
const RING_FESTSTECKEN := 6.0   # Sekunden: so lange ohne das Ringfeld zu erreichen, dann das nächste
var _idx_zeit := {}   # Vordermann -> seit wann er zum aktuellen Ringfeld unterwegs ist
var _stueck := {}     # Schild-Nummer -> {Feld: true}: das zusammenhängende Stück, auf dem der Ring liegt
var _weg_cache := {}  # instance id -> {"ziel", "von", "ok"}
const UMWEG_MAX := 12 # Felder: längerer Weg zum Ringfeld = vor einer Mauer, dort auf Posten


func _init(p: Order24) -> void:
	o24 = p


## Schild, zu dem die Fabrik einer Truppe gehört (der nächste Mittelpunkt).
func schild_von(e: Einheit) -> int:
	var p := o24.karte.mitte(e.fabrik_zelle)
	var beste := INF
	var nr := 0
	for i in o24.schild_mitten.size():
		var d := p.distance_to(o24.schild_mitten[i])
		if d < beste:
			beste = d
			nr = i
	return nr


## Jede Sekunde (order24._ablauf): Paare bilden, Ausfälle beginnen und beenden.
func weiter(k: Kommandant) -> void:
	var je_schild := {}
	for x in o24._truppen():
		var u := x as Einheit
		if not o24._ist_innen(u) or o24.jaeger.has(u.get_instance_id()) or u == o24.pilot or o24.eskorte.has(u):
			continue
		var s := schild_von(u)
		var drin := u.position.distance_to(o24.schild_mitten[s]) <= (Order24.SCHILD_RADIUS + MITGLIED_RAND) * Werte.ZELLE
		if drin:
			_mitglied[u.get_instance_id()] = true
			_rueckweg.erase(u.get_instance_id())
		if besatzung(u) and u.zustand == Einheit.Zustand.BODEN:
			if not je_schild.has(s):
				je_schild[s] = []
			(je_schild[s] as Array).append(u)
	# Ausfälle beenden
	for s: int in ausfall.keys():
		var a: Dictionary = ausfall[s]
		var lebend := (a["paar"] as Array).filter(func(u: Variant) -> bool: return is_instance_valid(u))
		if o24.zeit >= float(a["bis"]) or lebend.is_empty() or k == null or k.gefallen:
			ausfall.erase(s)
			for u: Einheit in lebend:
				_rueckweg[u.get_instance_id()] = true
			_pause_bis[s] = o24.zeit + o24.wf("ausfall_pause")
			print("ORDER24 Ausfall aus Schild %d zu Ende bei %.0f s" % [s, o24.zeit])
		else:
			a["paar"] = lebend
			a["ziel"] = o24._freies_feld_nahe(o24.karte.zelle_bei(k.position), 1)
	# Paare bilden (ohne die im Ausfall)
	_paar.clear()
	for s: int in je_schild:
		var drin: Array = []
		for u: Einheit in je_schild[s]:
			if not ausfall.has(s) or not (ausfall[s]["paar"] as Array).has(u):
				drin.append(u)
		drin.sort_custom(func(a: Einheit, b: Einheit) -> bool: return a.get_instance_id() < b.get_instance_id())
		for i in range(0, drin.size(), 2):
			var p: Array = drin.slice(i, i + 2)
			for u: Einheit in p:
				_paar[u.get_instance_id()] = p
	# Ausfall beginnen
	if k == null or k.gefallen or o24.phase() == "flucht":
		return
	for s: int in je_schild:
		if ausfall.has(s) or o24.zeit < float(_pause_bis.get(s, 0.0)):
			continue
		for u: Einheit in je_schild[s]:
			if not _sieht(u, k) or u.position.distance_to(o24.schild_mitten[s]) > (Order24.SCHILD_RADIUS + MITGLIED_RAND) * Werte.ZELLE:
				continue   # nur wer im Schild steht, macht einen Ausfall (nicht, wer gerade alarmiert draußen ist)
			var p: Array = _paar.get(u.get_instance_id(), [u])
			ausfall[s] = {"paar": p.duplicate(), "bis": o24.zeit + o24.wf("ausfall_sek"), "ziel": o24._freies_feld_nahe(o24.karte.zelle_bei(k.position), 1)}
			ausfaelle += 1
			for v: Einheit in p:
				_paar.erase(v.get_instance_id())
			print("ORDER24 Ausfall aus Schild %d bei %.0f s: %d Mann (gesehen auf %.1f Felder)" % [s, o24.zeit, p.size(), u.position.distance_to(k.position) / Werte.ZELLE])
			break


## Besatzung im Schild: Truppe einer Fabrik im Schild, die sich dort aufgehalten hat und nicht als Jäger, Pilot oder
## Begleiter unterwegs ist. Andere Truppen dieser Fabriken (irgendwo draußen abgesetzt) bleiben stehen wie bisher.
func besatzung(u: Einheit) -> bool:
	return _mitglied.has(u.get_instance_id()) and o24._ist_innen(u) and not o24.jaeger.has(u.get_instance_id()) and u != o24.pilot and not o24.eskorte.has(u)


## order24.drueckt: nach dem Ausfall gehen sie zurück und schießen dabei im Gehen (sonst blieben sie draußen stehen,
## solange Brakk in Reichweite ist).
func drueckt(e: Einheit) -> bool:
	return _rueckweg.has(e.get_instance_id())


func _sieht(u: Einheit, k: Kommandant) -> bool:
	return u.position.distance_to(k.position) <= o24.wf("ausfall_sicht") * Werte.ZELLE and o24.karte.sicht_frei(u.position, k.position)


func im_ausfall(e: Einheit) -> bool:
	for a: Dictionary in ausfall.values():
		if (a["paar"] as Array).has(e):
			return true
	return false


## Marschziel einer Truppe im Schild (order24.marschziel): im Ausfall zu Brakk, sonst der Ring.
func ziel(e: Einheit) -> Vector2i:
	if not besatzung(e):
		return Karte.KEINE
	var s := schild_von(e)
	if ausfall.has(s) and (ausfall[s]["paar"] as Array).has(e) and not o24.herausforderer.sperrt():
		return ausfall[s]["ziel"]
	var ring := _ring_von(s, e)
	if ring.is_empty():
		return Karte.KEINE
	var hier := o24.karte.zelle_bei(e.position)
	if e.position.distance_to(o24.schild_mitten[s]) <= (Order24.SCHILD_RADIUS - RING_AUSSEN) * Werte.ZELLE and not _am_stueck(s, hier):
		return Karte.KEINE   # in einer abgetrennten Tasche des Schilds: dort auf Posten (der Weg führte hinaus)
	var p: Array = _paar.get(e.get_instance_id(), [e])
	var vorn: Einheit = p[0] if is_instance_valid(p[0]) else e
	var id := vorn.get_instance_id()
	if not _idx.has(id):
		_idx[id] = _naechster_index(ring, vorn.position)
		_richtung[id] = 1 if (_idx.size() % 2) == 1 else -1   # Paare laufen abwechselnd links- und rechtsherum
	var i := int(_idx[id])
	var r := int(_richtung[id])
	if vorn == e and (o24.karte.zelle_bei(e.position).distance_to(ring[i]) <= 1.0 or o24.zeit - float(_idx_zeit.get(id, o24.zeit)) > RING_FESTSTECKEN):
		i = posmod(i + r, ring.size())   # erreicht – oder seit RING_FESTSTECKEN nicht hingekommen: das nächste Feld
		_idx[id] = i
		_idx_zeit[id] = o24.zeit
	elif not _idx_zeit.has(id):
		_idx_zeit[id] = o24.zeit
	var z: Vector2i = ring[i] if vorn == e else ring[posmod(i - r, ring.size())]   # der zweite ein Feld dahinter
	return z if _weg_kurz(e, z) else Karte.KEINE


## Kein Umweg um die halbe Karte: liegt der Weg zum Ringfeld über UMWEG_MAX Feldern (die Truppe steht vor einer Mauer
## des Schilds), bleibt sie, wo sie ist. Je Truppe und Ziel einmal gerechnet.
func _weg_kurz(e: Einheit, z: Vector2i) -> bool:
	var id := e.get_instance_id()
	var hier := o24.karte.zelle_bei(e.position)
	var c: Dictionary = _weg_cache.get(id, {})
	if c.get("ziel", Karte.KEINE) != z or c.get("von", Karte.KEINE) != hier:
		var weg := o24.karte.einheiten_weg(hier, z)
		c = {"ziel": z, "von": hier, "ok": hier == z or (not weg.is_empty() and weg.size() <= UMWEG_MAX)}
		_weg_cache[id] = c
	return bool(c["ok"])


## Steht die Truppe auf dem Stück des Rings – oder (noch in der Fabrik) direkt daneben?
func _am_stueck(s: int, hier: Vector2i) -> bool:
	var st: Dictionary = _stueck[s]
	if st.has(hier):
		return true
	if o24.karte.ist_begehbar(hier):
		return false
	for n: Vector2i in Karte.NACHBARN:
		if st.has(hier + n):
			return true
	return false


func _naechster_index(ring: Array, p: Vector2) -> int:
	var beste := INF
	var nr := 0
	for i in ring.size():
		var d := p.distance_to(o24.karte.mitte(ring[i]))
		if d < beste:
			beste = d
			nr = i
	return nr


## Ring knapp innerhalb des Schilds, nach Winkel geordnet. Das Innere ist oft durch Mauern und Fabriken in Taschen geteilt:
## genommen wird nur das größte Stück freier Felder, das INNERHALB des Schilds zusammenhängt – sonst führt der Weg zwischen
## zwei Ringfeldern außen herum und die Streife verlässt den Schild.
func _ring_von(s: int, _e: Einheit) -> Array:
	if _ring.has(s):
		return _ring[s]
	var karte := o24.karte
	var m: Vector2 = o24.schild_mitten[s]
	var mz := karte.zelle_bei(m)
	var r := ceili(Order24.SCHILD_RADIUS) + 1
	var frei := {}
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var z := mz + Vector2i(dx, dy)
			if karte.in_karte(z) and karte.ist_begehbar(z) and karte.ist_frei(z) and karte.mitte(z).distance_to(m) <= (Order24.SCHILD_RADIUS - RING_AUSSEN) * Werte.ZELLE:
				frei[z] = true
	# größtes zusammenhängendes Stück (Nachbarn wie die Wegesuche)
	var gross: Array = []
	var gesehen := {}
	for start: Vector2i in frei:
		if gesehen.has(start):
			continue
		var stueck: Array = [start]
		gesehen[start] = true
		var i := 0
		while i < stueck.size():
			for n: Vector2i in Karte.NACHBARN:
				var z: Vector2i = stueck[i] + n
				if frei.has(z) and not gesehen.has(z):
					gesehen[z] = true
					stueck.append(z)
			i += 1
		if stueck.size() > gross.size():
			gross = stueck
	_stueck[s] = {}
	for z: Vector2i in gross:
		_stueck[s][z] = true
	var felder: Array = gross.filter(func(z: Vector2i) -> bool:
		var d := karte.mitte(z).distance_to(m) / Werte.ZELLE
		return d >= Order24.SCHILD_RADIUS - RING_INNEN and d <= Order24.SCHILD_RADIUS - RING_AUSSEN)
	if felder.size() < 3:
		felder = gross   # sehr enger Schild: alle Felder des Stücks
	felder.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		var wa := (karte.mitte(a) - m).angle()
		var wb := (karte.mitte(b) - m).angle()
		return wa < wb)
	_ring[s] = felder
	print("ORDER24 Streifenring im Schild %d: %d Felder" % [s, felder.size()])
	return felder
