class_name BrakkProtokoll
extends RefCounted
## 23.11. (Paul): Run-Protokoll für den Brakk-Mode. Hängt je Runde einen Block "brakk" an den Runden-Eintrag des
## normalen Bauprotokolls (partien/partie-*.json): Ringkäufe und Ringfelder der Bauphase, Brakks Schaden je Quelle,
## Kills, Zähler (Rollen, Sprünge, Säulen …) als Differenz zur Vorrunde, Anteile Brakk/Truppen/Türme, Schaden je
## Fabrik, Gegnerweg, niedrigstes Leben, Tode, Ereignisse (Checkpoints, Sprengungen) und jede Sekunde Brakks Lage
## (Zelle, oben auf dem Wall, Leben in %). Damit lässt sich ein Brakk-Run ohne Video auswerten
## (werkzeuge/brakk_auswertung.py).

const TAKT_SEK := 1.0                 # alle so viele Spielsekunden eine Lage

var ring_aktionen: Array = []         # Bauphase: Kauf, Stufe, Verkauf, Ringfeld
var _lage: Array = []                 # [t, x, y, oben 0/1, leben %]
var _ereignisse: Array = []           # {"t", "a", …}
var _naechste := 0.0
var _leben_min := 1.0
var _tode := 0
var _basis: Variant = null            # Zähler zu Beginn der Runde (für die Differenz)
var _basis_quellen := {}              # Brakks Schaden je Quelle zu Beginn des Abschnitts
var _basis_kills := 0


## Spielzeit: in Befehl 24 dessen Uhr (keine Runden), sonst Sekunden seit Rundenbeginn.
static func _zeit(spiel: Node) -> float:
	return float(spiel.order24.zeit) if spiel.order24 != null else float(spiel._kampf_sek)


static func _kills(f: BrakkFortschritt) -> int:
	var n := 0
	for r: String in f.kills_runden:
		n += int(f.kills_runden[r])
	return n


func ring(art: String, ring_name: String, daten: Dictionary = {}) -> void:
	var e := {"a": art, "ring": ring_name}
	e.merge(daten)
	ring_aktionen.append(e)


func ereignis(spiel: Node, art: String, daten: Dictionary = {}) -> void:
	var e := {"t": snappedf(_zeit(spiel), 0.1), "a": art}
	e.merge(daten)
	_ereignisse.append(e)
	if art == "brakk_tod":
		_tode += 1


## Jedes Bild der Ego-Sicht in der Kampfphase.
func tick(spiel: Node, brakk: Node, fortschritt: BrakkFortschritt) -> void:
	if _basis == null:
		_basis = fortschritt.zaehler.duplicate()
		_basis_quellen = fortschritt.schaden_quellen.duplicate()
		_basis_kills = _kills(fortschritt)
	if brakk.gefallen:
		return
	var anteil := clampf(float(brakk.leben) / maxf(1.0, float(brakk.max_leben)), 0.0, 1.0)
	_leben_min = minf(_leben_min, anteil)
	var t := _zeit(spiel)
	if t + 0.001 < _naechste:
		return
	_naechste = t + TAKT_SEK
	var z: Vector2i = spiel.karte.zelle_bei(brakk.position + (Vector2(0, 12) if brakk.oben else Vector2.ZERO))
	_lage.append([snappedf(t, 0.1), z.x, z.y, 1 if brakk.oben else 0, roundi(anteil * 100.0)])


## Am Rundenende: Block für den Runden-Eintrag, danach frisch für die nächste Runde.
func abschluss(spiel: Node, brakk: Node, fortschritt: BrakkFortschritt) -> Dictionary:
	var zaehler := {}
	var basis: Dictionary = _basis if _basis != null else {}
	for k: String in fortschritt.zaehler:
		var d := float(fortschritt.zaehler[k]) - float(basis.get(k, 0.0))
		if absf(d) > 0.001:
			zaehler[k] = snappedf(d, 0.1)
	var quellen := {}   # Differenz seit dem letzten Abschluss (geht auch ohne Runden, Befehl 24)
	for q: String in fortschritt.schaden_quellen:
		var d := float(fortschritt.schaden_quellen[q]) - float(_basis_quellen.get(q, 0.0))
		if d >= 0.5:
			quellen[q] = roundi(d)
	# Anteile und Schaden je Fabrik/Turmart aus der Rundenstatistik
	var brakk_s := 0.0
	var truppen := 0.0
	var tuerme := 0.0
	var je_quelle := {}
	for q: String in spiel.runde_stats:
		var e: Dictionary = spiel.runde_stats[q]
		var s := float(e.get("schaden", 0.0))
		if q == "fabrik:-1,-1":
			brakk_s += s
		elif q.begins_with("fabrik:"):
			truppen += s
		else:
			tuerme += s
		if q != "fabrik:-1,-1":
			je_quelle[q] = [roundi(s), int(e.get("kills", 0)), str(e.get("name", ""))]
	var ringe := []
	for r: String in fortschritt.ringe:
		var f: Variant = fortschritt.felder.get(r)
		ringe.append([r, fortschritt.ring_stufe(r), [f.x, f.y] if f is Vector2i else null])
	var block := {
		"stufe": fortschritt.stufe,
		"leben_max": roundi(float(brakk.max_leben)),
		"leben_min_prozent": roundi(_leben_min * 100.0),
		"tode": _tode,
		"ringe": ringe,
		"ring_aktionen": ring_aktionen.duplicate(),
		"aktiver_ring": fortschritt.aktiv() if not fortschritt.ringe.is_empty() else "",
		"schaden": {"brakk": roundi(brakk_s), "truppen": roundi(truppen), "tuerme": roundi(tuerme)},
		"brakk_quellen": quellen,
		"brakk_kills": _kills(fortschritt) - _basis_kills,
		"je_quelle": je_quelle,
		"zaehler": zaehler,
		"gegnerweg": spiel.weg_info.duplicate(),
		"ereignisse": _ereignisse.duplicate(),
		"lage": _lage.duplicate(),
	}
	ring_aktionen.clear()
	_lage.clear()
	_ereignisse.clear()
	_naechste = _zeit(spiel) if spiel.order24 != null else 0.0
	_leben_min = 1.0
	_tode = 0
	_basis = fortschritt.zaehler.duplicate()
	_basis_quellen = fortschritt.schaden_quellen.duplicate()
	_basis_kills = _kills(fortschritt)
	return block
