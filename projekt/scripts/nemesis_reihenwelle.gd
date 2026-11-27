class_name NemesisReihenwelle
extends RefCounted
## H-1 (27.11., Paul): Befehl 24 – die Reihenwelle (der Anker-Zwang des Scharfschützen und von Sonde 7, jetzt lesbar).
## Vom Boss aus brechen die Bodenreihen quer zur Richtung Boss → Brakk eine nach der anderen auf: alle BOSS_REIHE_TAKT s
## wird die nächste Reihe BOSS_REIHE_WARNUNG s lang rot umrandet (ein Band je Reihe, kein Feldraster), dann explodiert sie
## über die ganze Breite (Staub, Ton; alles am Boden nimmt BOSS_REIHE_SCHADEN eines Treffers), danach ist sie frei.
## Wälle im Platz (Rand-Kronen, Stellungen) bleiben frei. Die Welle läuft bis zur Lichtwand.
## Antworten: über die gerade brechende Reihe springen (rot bei t, Explosion t + 0,9 – ein Sprung ab t + 0,5 ist dann in
## der Luft und landet in einer freien Reihe) oder per Anker/Lichttreppe auf eine Krone.

const ROT := Color("ff3b3b")
const STAUB := Color(0.62, 0.52, 0.38)

var h: NemesisHerausforderer
var reihen: Array = []           # je {"zellen": Array[Vector2i], "ab": rot ab (s), "rect": Rect2 (Bildpunkte), "zustand": "wartet"|"rot"|"frei"}
var t := 0.0
var schritt := Vector2i.RIGHT    # von Reihe zu Reihe (vom Boss weg)
var ohne_bild := false           # Prüfung: nur rechnen
var lage_fn := Callable()        # Prüfung: () -> {"pos": Vector2, "boden": bool} statt Brakks echter Lage
var treffer_fn := Callable()     # Prüfung: (anteil: float, wo: Vector2) statt des echten Treffers
var getroffen := 0
var protokoll: Array = []        # je {"i", "bei", "drin", "getroffen"}
var _knoten: Array = []          # 3D-Bilder (bei abbrechen() weg)


func _init(p_h: NemesisHerausforderer) -> void:
	h = p_h


## Die Reihen vom Boss (`von`) weg in Richtung Brakk (`zu`) bis zur Lichtwand.
func planen(von: Vector2, zu: Vector2) -> void:
	var kp := h.kampfplatz
	var karte: Karte = h.o24.karte
	var hb := BrakkKampfplatz._halb()
	var lo := kp.mitte - hb + Vector2i.ONE              # erstes Feld im Innern
	var hi := kp.mitte + hb - Vector2i(2, 2)            # letztes Feld im Innern
	var d := zu - von
	var quer_x := absf(d.x) >= absf(d.y)                # die Welle läuft in x: die Reihen sind Spalten
	schritt = Vector2i(1 if d.x >= 0.0 else -1, 0) if quer_x else Vector2i(0, 1 if d.y >= 0.0 else -1)
	var start := karte.zelle_bei(von)
	var achse := 0 if quer_x else 1
	var a := (start.x if quer_x else start.y) + (schritt.x if quer_x else schritt.y)
	var a_lo := lo.x if quer_x else lo.y
	var a_hi := hi.x if quer_x else hi.y
	var r_lo := lo.y if quer_x else lo.x
	var r_hi := hi.y if quer_x else hi.x
	var richtung := schritt[achse]
	if richtung > 0 and a < a_lo:
		a = a_lo   # er steht auf dem Rand (Krone): die Welle beginnt an der ersten Reihe im Innern
	elif richtung < 0 and a > a_hi:
		a = a_hi
	reihen.clear()
	var n := 0
	while a >= a_lo and a <= a_hi:
		var zellen: Array[Vector2i] = []
		for b in range(r_lo, r_hi + 1):
			var z := Vector2i(a, b) if quer_x else Vector2i(b, a)
			if karte.inhalt(z) != Karte.WALL:
				zellen.append(z)
		if not zellen.is_empty():
			var p0 := karte.mitte(zellen[0]) - Vector2.ONE * Werte.ZELLE * 0.5
			var p1 := karte.mitte(zellen[zellen.size() - 1]) + Vector2.ONE * Werte.ZELLE * 0.5
			var rect := Rect2(p0, Vector2.ZERO).expand(p1)
			reihen.append({"zellen": zellen, "ab": n * Werte.BOSS_REIHE_TAKT, "rect": rect, "zustand": "wartet"})
			n += 1
		a += richtung


## So lange läuft die Welle (s), bis die letzte Reihe explodiert ist.
func dauer() -> float:
	return (float(reihen.back()["ab"]) + Werte.BOSS_REIHE_WARNUNG) if not reihen.is_empty() else 0.0


func fertig() -> bool:
	return t >= dauer()


## Ein Schritt (`dt` in echten Sekunden).
func weiter(dt: float) -> void:
	t += dt
	for i in reihen.size():
		var r: Dictionary = reihen[i]
		match str(r["zustand"]):
			"wartet":
				if t >= float(r["ab"]):
					r["zustand"] = "rot"
					_band(r)
			"rot":
				if t >= float(r["ab"]) + Werte.BOSS_REIHE_WARNUNG:
					r["zustand"] = "frei"
					_explodiert(i, r)


## Wird gerade eine Reihe gewarnt, in der dieser Punkt liegt?
func warnt(p: Vector2) -> bool:
	for r: Dictionary in reihen:
		if str(r["zustand"]) == "rot" and (r["rect"] as Rect2).has_point(p):
			return true
	return false


func _lage() -> Dictionary:
	if lage_fn.is_valid():
		return lage_fn.call()
	var k: Kommandant = h.spiel.kommandant
	var ego: EgoModus = h.spiel.ego
	var sprung := (ego.hoehe - ego._boden()) if ego != null else 0.0
	return {"pos": k.position, "boden": not k.oben and sprung <= Werte.BRAKK_SPRUNG_BODEN and k.unverwundbar <= 0.0}


func _explodiert(i: int, r: Dictionary) -> void:
	var lage := _lage()
	var rect: Rect2 = r["rect"]
	var drin := rect.has_point(lage["pos"] as Vector2)   # Brakks Mitte – sonst träfe ihn die Nachbarreihe gleich beim Absprung
	var trifft := drin and bool(lage["boden"])
	protokoll.append({"i": i, "bei": t, "drin": drin, "getroffen": trifft})
	if trifft:
		getroffen += 1
		if treffer_fn.is_valid():
			treffer_fn.call(Werte.BOSS_REIHE_SCHADEN, lage["pos"])
		else:
			h.treffe_als("reihe", h.schaden() * Werte.BOSS_REIHE_SCHADEN, rect.get_center())
	if ohne_bild:
		return
	var zellen: Array = r["zellen"]
	for j in range(0, zellen.size(), 2):
		h.spiel.effekte.flaeche(h.o24.karte.mitte(zellen[j]), Werte.ZELLE * 0.55, STAUB)
	Ton.am_ort(h.spiel, "hit-boom", rect.get_center())


## Ein rotes Band um die Reihe (am Boden), die Fläche darin wird bis zur Explosion kräftiger.
func _band(r: Dictionary) -> void:
	if ohne_bild:
		return
	var hd: HdAnsicht = h.spiel.hd
	if hd == null:
		return
	var bg: BrakkGeschosse = h.spiel.brakk_geschosse
	var rect: Rect2 = r["rect"]
	var sek := NemesisHerausforderer._bg(Werte.BOSS_REIHE_WARNUNG)
	var ecken := [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]
	for k in 4:
		bg._balken(bg._zu3d(ecken[k], 0.07), bg._zu3d(ecken[(k + 1) % 4], 0.07), ROT, 0.07, sek)
	var flaeche := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(rect.size.x / Werte.ZELLE, 0.02, rect.size.y / Werte.ZELLE)
	flaeche.mesh = box
	var stoff := h.o24._leucht(Color("ff2a2a"), 0.08)
	flaeche.material_override = stoff
	hd.add_child(flaeche)
	flaeche.position = bg._zu3d(rect.get_center(), 0.04)
	var tw := flaeche.create_tween()
	tw.set_ignore_time_scale(true)   # echte Sekunden, wie die Warnung
	tw.tween_property(stoff, "albedo_color:a", 0.45, Werte.BOSS_REIHE_WARNUNG)
	tw.tween_callback(flaeche.queue_free)
	_knoten.append(flaeche)


## Duell vorbei: alles weg.
func abbrechen() -> void:
	for n: Variant in _knoten:
		if is_instance_valid(n) and n is Node:
			(n as Node).queue_free()
	_knoten.clear()
	reihen.clear()
