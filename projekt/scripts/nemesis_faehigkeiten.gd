class_name NemesisFaehigkeiten
extends Node
## 22.11. (Paul, Nemesis Teil 3): Fähigkeiten der Benannten in Befehl 24 – je Truppenart zwei, bei der Beförderung wird
## eine gezogen (passend zur Tat), ab Rang NEMESIS_BEIDE_AB hat die Person beide. Jede kündigt sich vorher klar an (Bild,
## Ton, Zeile im Namensschild) und lässt sich kontern (Tumble, Sprung, Stellungswechsel, Ladestrahl). Abklingzeit sinkt
## je Rang um NEMESIS_CD_JE_RANG. Werte: Werte.NEMESIS_FAEHIGKEITEN.
##  - Technogunner: Unterdrückungsfeuer (Anlegen, dann 3 s Dauerfeuer im festen Kegel, Brakk darin 30 % langsamer) ·
##    Sturmlauf (Ruf, 2 s doppeltes Tempo auf Brakk zu, Salve aus nächster Nähe mit doppeltem Schaden; der Ladestrahl
##    unterbricht ihn, dann taumelt er).
##  - Scharfschütze: Markierung (oranger Zielstrahl; trifft er, kennen alle Trupps 5 s Brakks Ort, danach wechselt er die
##    Stellung) · Durchschuss (1,2 s heller, dicker Zielstrahl, geht durch genau einen Erdwall).
##  - Plasmawerfer: Sperrbrand (Brandfeld auf Brakks Laufweg, Vorwarnkreis 1 s) · Ausräuchern (hoher Bogen über einen
##    Wall in Brakks Deckung, langsam, mit Schatten, 4 s Brandfeld).
## Zeiten in echten Sekunden (wie die Geschosse auf Brakk).

const NAMEN := {
	"unterdrueckung": "Unterdrückungsfeuer", "sturmlauf": "Sturmlauf", "markierung": "Markierung",
	"durchschuss": "Durchschuss", "sperrbrand": "Sperrbrand", "ausraeuchern": "Ausräuchern",
}
const JE_ART := {
	"technogunner": ["unterdrueckung", "sturmlauf"], "scharfschuetze": ["markierung", "durchschuss"], "plasmawerfer": ["sperrbrand", "ausraeuchern"],
}
## die Variante gegen Deckung (wer Brakk aus der Deckung geholt hat, bekommt eher diese)
const DECKUNGSBRECHER: Array[String] = ["sturmlauf", "durchschuss", "ausraeuchern"]
const KONTER := {
	"unterdrueckung": "raus aus dem Kegel – er schwenkt nicht mit",
	"sturmlauf": "der Ladestrahl stoppt ihn – oder im letzten Moment tumblen",
	"markierung": "dem orangen Zielstrahl ausweichen",
	"durchschuss": "den hellen Strahl verlassen – ein Wall allein schützt nicht",
	"sperrbrand": "Richtung wechseln – der Kreis liegt vor dir",
	"ausraeuchern": "die Deckung wechseln, sobald der Schatten kommt",
}
const FARBE_KEGEL := Color("ff9a3d")
const FARBE_MARKIERUNG := Color("ffa21c")
const FARBE_DURCHSCHUSS := Color("fff4c2")

var nem: Nemesis
var auto := true                    # false: nur auslösen() (Test)
var log: Array = []                 # Prüfung: je {"t", "id", "f", "was"} (an = angekündigt, wirkt, ende, unterbrochen)
var markiert_rest := 0.0            # Brakk ist markiert (Sekunden)
var umstellen := {}                 # Einheit-ID -> {"bis": float, "ziel": Vector2i} (Markierung: Stellungswechsel)
var _zust := {}                     # Einheit-ID -> Zustand {"cd": {}, "akt": "", "t": 0.0, …}
var _sperre := 0.0
var _erklaert := {}
var _bremse := 1.0
var _zeit := 0.0
var _letzte := {}                   # Einheit-ID -> [Fähigkeit, Zeit] (für den Deathscreen)
var _eroeffnet := {}                # 22.11. (Teil 5): Trupp-Nr -> Zeit der letzten Eröffnung (Markierung, Unterdrückungsfeuer)
var _wartet := {}                   # Einheit-ID -> seit wann sie auf eine Eröffnung wartet


static func name_von(f: String) -> String:
	return str(NAMEN.get(f, f))


## Fähigkeiten einer Person: eine, ab Rang NEMESIS_BEIDE_AB beide ihrer Truppenart.
static func von_person(p: Dictionary) -> Array:
	if not Nemesis.benannt(p):
		return []
	if int(p.get("rang", 0)) >= Werte.NEMESIS_BEIDE_AB:
		return (JE_ART.get(str(p.get("art", "")), []) as Array).duplicate()
	return [] if str(p.get("faehigkeit", "")) == "" else [str(p["faehigkeit"])]


## Bei der Beförderung: passend zur Tat (aus der Deckung geholt oder aus dem Hinterhalt → Deckungsbrecher, aus der Ferne
## → die Fernvariante), sonst gezogen.
static func ziehen(art: String, lage: String, deckung: bool) -> String:
	var zwei: Array = JE_ART.get(art, JE_ART["technogunner"])
	if deckung or lage in ["hinterhalt", "wall"]:
		return str(zwei[1])
	if lage in ["fern", "dach"]:
		return str(zwei[0])
	if lage == "nah" and art == "technogunner":
		return "sturmlauf"
	return str(Zufall.waehle(zwei))


func cd_von(f: String, p: Dictionary) -> float:
	return float((Werte.NEMESIS_FAEHIGKEITEN[f] as Dictionary).get("cd", 0.0)) * maxf(0.3, 1.0 - Werte.NEMESIS_CD_JE_RANG * int(p.get("rang", 1)))


func w(f: String, k: String) -> float:
	return float((Werte.NEMESIS_FAEHIGKEITEN[f] as Dictionary)[k])


## Brakks Tempo (Ego-Bewegung): im Kegel eines Unterdrückungsfeuers langsamer.
func tempo_faktor() -> float:
	return _bremse


## Was im Namensschild unter dem Namen steht, solange eine Fähigkeit angekündigt wird oder läuft.
func schild_zeile(e: Einheit) -> String:
	var s: Dictionary = _zust.get(e.get_instance_id(), {})
	if s.is_empty() or str(s["akt"]) == "":
		return ""
	if str(s["akt"]) == "taumel":
		return "~ taumelt ~"
	return "!! %s !!" % name_von(str(s["akt"])).to_upper()


## Fähigkeit, mit der diese Einheit gerade (oder vor höchstens 4 s) gewirkt hat – "" sonst.
func letzte_von(e: Einheit) -> String:
	var l: Array = _letzte.get(e.get_instance_id(), [])
	if l.is_empty() or _zeit - float(l[1]) > 4.0:
		return ""
	return str(l[0])


func _physics_process(_takt: float) -> void:
	if auto and nem != null and nem.o24 != null and nem.o24.laeuft and not nem.o24.vorbei and nem.spiel.phase == 1:
		weiter(Werte.SIM_SCHRITT / Werte.BRAKK_TEMPO)


func weiter(dt: float) -> void:
	_zeit += dt
	_sperre -= dt
	markiert_rest = maxf(0.0, markiert_rest - dt)
	_bremse = 1.0
	var bg: BrakkGeschosse = nem.spiel.brakk_geschosse
	if bg == null:
		return
	var z := bg._ziel()
	for id: int in nem._person_von.keys():
		var o: Object = instance_from_id(id)
		if not Nemesis.lebt(o):
			_zust.erase(id)
			continue
		var e := o as Einheit
		var p: Dictionary = nem._person_von[id]
		var fs := von_person(p)
		if fs.is_empty():
			continue
		if not _zust.has(id):
			_zust[id] = {"cd": {}, "akt": "", "t": 0.0}
		var s: Dictionary = _zust[id]
		var cd: Dictionary = s["cd"]
		for f: String in cd:
			cd[f] = float(cd[f]) - dt
		if str(s["akt"]) != "":
			_ablauf(e, p, s, dt, z)
			continue
		if not auto or z.is_empty() or _sperre > 0.0 or nem.o24.phase() == "flucht":
			continue
		for f: String in fs:
			if f != "markierung" and float(cd.get(f, 0.0)) <= 0.0 and _bereit(e, f, z) and darf_jetzt(e, f, z):   # 22.11. (Teil 5): Zusammenspiel
				ausloesen(e, f)
				break


## Kann die Einheit die Fähigkeit jetzt sinnvoll einsetzen? (Abstand, Sicht, Wälle dazwischen)
func _bereit(e: Einheit, f: String, z: Dictionary) -> bool:
	var bp: Vector2 = z["pos"]
	var d := e.position.distance_to(bp) / Werte.ZELLE
	var karte := nem.o24.karte
	var sicht := karte.sicht_frei(e.position, bp)
	var r := e.reichweite_jetzt()
	match f:
		"unterdrueckung":
			return sicht and d <= r + 1.0
		"sturmlauf":
			return sicht and d > w(f, "nah") + 1.0 and d <= w(f, "weite")
		"durchschuss":
			return d <= r + 1.0 and ((not sicht and waende(e.position, bp) == 1) or (sicht and d >= 4.0))
		"sperrbrand":
			return sicht and d <= r + w(f, "weite_plus")
		"ausraeuchern":
			var bekannt := nem.o24.zeit - nem.o24.bekannt_zeit < 2.0
			return not sicht and bekannt and d <= r + w(f, "weite_plus") and waende(e.position, bp) >= 1
	return false


## 22.11. (Paul, Teil 5): Zusammenspiel im Elitetrupp – erst Markierung oder Unterdrückungsfeuer, dann Sturmlauf bzw.
## Durchschuss (hat im Trupp niemand eine Eröffnung oder wartet er schon 8 s, darf er trotzdem), Sperrbrand nur auf
## Brakks Rückweg (er läuft von ihm weg).
func darf_jetzt(e: Einheit, f: String, z: Dictionary) -> bool:
	var id := e.get_instance_id()
	match f:
		"sturmlauf", "durchschuss":
			var nr := int(nem.o24.jaeger.get(id, -1))
			if _zeit - float(_eroeffnet.get(nr, -99.0)) <= Werte.NEMESIS_EROEFFNUNG:
				_wartet.erase(id)
				return true
			var hat_eroeffner := false
			if nr >= 0 and nr < nem.o24.trupps.size():
				for m: Variant in (nem.o24.trupps[nr] as Dictionary)["mitglieder"]:
					if m != e and Nemesis.lebt(m):
						var fs := von_person(nem.person_von(m as Einheit))
						if fs.has("markierung") or fs.has("unterdrueckung"):
							hat_eroeffner = true
			if not hat_eroeffner:
				return true
			if not _wartet.has(id):
				_wartet[id] = _zeit
			return _zeit - float(_wartet[id]) >= 8.0
		"sperrbrand":
			var v: Vector2 = z.get("v", Vector2.ZERO)
			var weg := ((z["pos"] as Vector2) - e.position).normalized()
			return v.length() > 0.8 * Werte.ZELLE and v.normalized().dot(weg) > 0.3
	return true


## Erdwälle zwischen zwei Punkten (ohne die Felder von Start und Ziel).
func waende(a: Vector2, b: Vector2) -> int:
	var karte := nem.o24.karte
	var za := karte.zelle_bei(a)
	var zb := karte.zelle_bei(b)
	var gesehen := {}
	var schritte := maxi(1, ceili(a.distance_to(b) / (Werte.ZELLE * 0.2)))
	for i in schritte + 1:
		var c := karte.zelle_bei(a.lerp(b, float(i) / schritte))
		if c != za and c != zb and karte.inhalt(c) == Karte.WALL:
			gesehen[c] = true
	return gesehen.size()


func _quelle(e: Einheit) -> String:
	return "fabrik:%d,%d#%d" % [e.fabrik_zelle.x, e.fabrik_zelle.y, e.get_instance_id()]


func _log(e: Einheit, f: String, was: String) -> void:
	log.append({"t": _zeit, "id": e.get_instance_id(), "f": f, "was": was})


## Fähigkeit starten (Ankündigung). Auch für den Test, ohne Abklingzeit zu prüfen.
func ausloesen(e: Einheit, f: String) -> void:
	var id := e.get_instance_id()
	var p := nem.person_von(e)
	if not _zust.has(id):
		_zust[id] = {"cd": {}, "akt": "", "t": 0.0}
	var s: Dictionary = _zust[id]
	(s["cd"] as Dictionary)[f] = cd_von(f, p)
	s["akt"] = f
	s["t"] = 0.0
	s["takt"] = 0.0
	s["salve"] = false
	_sperre = Werte.NEMESIS_FAEHIGKEIT_ABSTAND
	if f == "unterdrueckung":
		_eroeffnet[int(nem.o24.jaeger.get(id, -1))] = _zeit   # 22.11. (Teil 5): Eröffnung – der Trupp darf nachsetzen
	_letzte[id] = [f, _zeit]
	var spiel: Node = nem.spiel
	var bg: BrakkGeschosse = spiel.brakk_geschosse
	var z := bg._ziel()
	if z.is_empty():
		s["akt"] = ""
		return
	var bp: Vector2 = z["pos"]
	e.halt = f in ["unterdrueckung", "sturmlauf", "durchschuss", "sperrbrand", "ausraeuchern"]
	e._punkte.clear()
	e._sprite.bewegt(false)
	e._sprite.flip_h = bp.x < e.position.x
	_log(e, f, "an")
	if auto:
		print("NEMESIS Fähigkeit: %s – %s (%.1f Felder)" % [Nemesis.voller_name(p), name_von(f), e.position.distance_to(bp) / Werte.ZELLE])
	if not _erklaert.has(f):
		_erklaert[f] = true   # erste Nutzung im Lauf: was es ist und wie man kontert
		spiel.melde("%s: %s – %s." % [Nemesis.voller_name(p), name_von(f), str(KONTER[f])], 4.0)
	var schaden := float(e.daten["schaden"])
	match f:
		"unterdrueckung":
			s["richtung"] = (bp - e.position).normalized() if bp.distance_to(e.position) > 1.0 else Vector2.RIGHT
			s["weite"] = (e.reichweite_jetzt() + w(f, "weite_plus")) * Werte.ZELLE
			bg.kegel_bild(e.position, s["richtung"] as Vector2, w(f, "winkel"), float(s["weite"]), Color(FARBE_KEGEL, 0.6), w(f, "anlegen"))
			Ton.am_ort(spiel, "tc-arc", e.position)
		"sturmlauf":
			s["skala"] = e._sprite.scale
			Ton.am_ort(spiel, "alert", e.position)
			spiel.effekte.welle(e.position, Werte.ZELLE * 1.2, Color("ff5a6e"), "funk", 0.5)
		"durchschuss":
			bg.scharf(e, e.position, 0.45, (e.reichweite_jetzt() + 2.0) * Werte.ZELLE, schaden * w(f, "schaden"), _quelle(e), w(f, "laden"), w(f, "breite"), FARBE_DURCHSCHUSS)
			Ton.am_ort(spiel, "tc-rail", e.position)
		"sperrbrand":
			var v: Vector2 = z.get("v", Vector2.ZERO)
			var punkt := bp + v.normalized() * w(f, "vorlauf") * Werte.ZELLE if v.length() > 0.8 * Werte.ZELLE else bp + (bp - e.position).normalized() * 1.5 * Werte.ZELLE
			bg.wurf(e.position, punkt, w(f, "warnung"), w(f, "radius") * Werte.ZELLE, w(f, "brand"), schaden * w(f, "dps"), schaden, _quelle(e), false)
			Ton.am_ort(spiel, "tc-arc", e.position)
		"ausraeuchern":
			bg.wurf(e.position, bp, w(f, "flug"), w(f, "radius") * Werte.ZELLE, w(f, "brand"), schaden * w(f, "dps"), schaden, _quelle(e), true)
			Ton.am_ort(spiel, "tc-arc", e.position)
		"markierung":
			bg.scharf(e, e.position, 0.45, (e.reichweite_jetzt() + 1.0) * Werte.ZELLE, schaden, _quelle(e), Werte.BRAKK_SCHARF_ZIEL_SEK, 1.0, FARBE_MARKIERUNG, _markieren.bind(e))


## Laufende Fähigkeit weiterführen.
func _ablauf(e: Einheit, p: Dictionary, s: Dictionary, dt: float, z: Dictionary) -> void:
	var f := str(s["akt"])
	s["t"] = float(s["t"]) + dt
	var t := float(s["t"])
	var bg: BrakkGeschosse = nem.spiel.brakk_geschosse
	e._abkling = maxf(e._abkling, 0.3)   # keine normalen Schüsse dazwischen
	match f:
		"unterdrueckung":
			if t < w(f, "anlegen"):
				return
			if not bool(s.get("wirkt", false)):
				s["wirkt"] = true
				_log(e, f, "wirkt")
			var r: Vector2 = s["richtung"]
			var weite := float(s["weite"])
			var im_kegel := false
			var zu := Vector2.ZERO
			if not z.is_empty():
				zu = (z["pos"] as Vector2) - e.position
				im_kegel = zu.length() <= weite and absf(rad_to_deg(r.angle_to(zu))) <= w(f, "winkel")
				if im_kegel:
					_bremse = minf(_bremse, w(f, "bremse"))
			s["takt"] = float(s["takt"]) - dt
			while float(s["takt"]) <= 0.0:
				s["takt"] = float(s["takt"]) + w(f, "takt")
				# Brakk im Kegel: das Feuer liegt auf ihm (mit Streuung); außerhalb streut es über den festen Kegel – er schwenkt nicht mit
				var richtung := zu.normalized().rotated(deg_to_rad(Zufall.von_bis(-1.0, 1.0) * w(f, "streuung"))) if im_kegel \
					else r.rotated(deg_to_rad(Zufall.von_bis(-w(f, "winkel"), w(f, "winkel"))))
				bg.schiesse("laser", e.position, 0.45, float(e.daten["schaden"]) * w(f, "schaden"), "technogunner", _quelle(e), 1.0, e.position + richtung * weite)
			if fmod(t, 0.5) < dt:
				bg.kegel_bild(e.position, r, w(f, "winkel"), weite, Color(1.0, 0.35, 0.25, 0.5), 0.5)
			if t >= w(f, "anlegen") + w(f, "dauer"):
				_ende(e, s)
		"sturmlauf":
			if t < w(f, "ruf"):
				return
			if z.is_empty():
				_ende(e, s)
				return
			if not bool(s.get("wirkt", false)):
				s["wirkt"] = true
				_log(e, f, "wirkt")
			var bp: Vector2 = z["pos"]
			var d := e.position.distance_to(bp)
			var lauf := t < w(f, "ruf") + w(f, "dauer") and d > w(f, "nah") * Werte.ZELLE
			if lauf:
				var schritt := minf(d, float(e.daten["tempo"]) * w(f, "tempo") * Werte.ZELLE * dt * Werte.BRAKK_TEMPO)
				var neu := e.position + (bp - e.position).normalized() * schritt
				var karte := nem.o24.karte
				if karte.ist_begehbar(karte.zelle_bei(neu)) and karte.inhalt(karte.zelle_bei(neu)) != Karte.WALL:
					e.position = neu
					e._sprite.bewegt(true)
					e._sprite.flip_h = bp.x < e.position.x
					return
			# Salve aus nächster Nähe: zwei Schüsse mit doppeltem Schaden
			e._sprite.bewegt(false)
			for i in 2:
				bg.schiesse("laser", e.position, 0.45, float(e.daten["schaden"]) * w(f, "schaden"), "technogunner", _quelle(e), 0.3)
			Ton.am_ort(nem.spiel, "tc-heavy", e.position)
			_log(e, f, "salve")
			_ende(e, s)
		"taumel":
			var sk: Vector2 = s.get("skala", e._sprite.scale)
			e._sprite.scale = Vector2(sk.x, sk.y * (0.85 + 0.15 * cos(t * 18.0)))
			if t >= w("sturmlauf", "taumel"):
				e._sprite.scale = sk
				_ende(e, s)
		"durchschuss":
			if t >= w(f, "laden") + 0.05:
				_log(e, f, "wirkt")
				_ende(e, s)
		"sperrbrand":
			if t >= w(f, "warnung") + 0.05:
				_log(e, f, "wirkt")
				_ende(e, s)
		"ausraeuchern":
			if t >= w(f, "flug") + 0.05:
				_log(e, f, "wirkt")
				_ende(e, s)
		"markierung":
			if t >= Werte.BRAKK_SCHARF_ZIEL_SEK + 0.05:
				_ende(e, s)


func _ende(e: Einheit, s: Dictionary) -> void:
	_log(e, str(s["akt"]), "ende")
	s["akt"] = ""
	s["wirkt"] = false
	e.halt = false


## Brakk trifft eine Einheit (Order24.treffer): Der Ladestrahl unterbricht einen Sturmlauf – er taumelt.
func von_brakk(e: Einheit, lanze: bool) -> void:
	var s: Dictionary = _zust.get(e.get_instance_id(), {})
	if s.is_empty() or str(s["akt"]) != "sturmlauf" or not lanze or float(s["t"]) < w("sturmlauf", "ruf"):
		return
	_log(e, "sturmlauf", "unterbrochen")
	s["akt"] = "taumel"
	s["t"] = 0.0
	if not _erklaert.has("taumel"):
		_erklaert["taumel"] = true
		nem.spiel.melde("Sturmlauf gestoppt – %s taumelt." % Nemesis.voller_name(nem.person_von(e)), 2.5)


## Scharfschütze mit Markierung: der normale Schuss bekommt den orangen Strahl und markiert bei einem Treffer.
func scharf_extras(e: Einheit) -> Dictionary:
	if not von_person(nem.person_von(e)).has("markierung"):
		return {}
	return {"farbe": FARBE_MARKIERUNG, "cb": _markieren.bind(e)}


## Getroffen mit Markierung: alle Trupps kennen Brakks Ort für eine Weile; der Schütze wechselt die Stellung.
func _markieren(_punkt: Vector2, e: Einheit) -> void:
	var dauer := w("markierung", "dauer")
	markiert_rest = dauer
	if is_instance_valid(e):
		_eroeffnet[int(nem.o24.jaeger.get(e.get_instance_id(), -1))] = _zeit   # 22.11. (Teil 5): der Trupp darf nachsetzen
	nem.o24.markiert_bis = nem.o24.zeit + dauer
	if is_instance_valid(e):
		_log(e, "markierung", "wirkt")
		_letzte[e.get_instance_id()] = ["markierung", _zeit]
		if not _erklaert.has("markierung"):
			_erklaert["markierung"] = true
			nem.spiel.melde("Markiert! %s hat dich für alle sichtbar gemacht (%d s) – %s." % [Nemesis.voller_name(nem.person_von(e)), roundi(dauer), str(KONTER["markierung"])], 3.5)
		nach_schuss(e)


## Nach jedem Schuss eines Markierungs-Schützen: Stellung wechseln (ein freies Feld 2–3 Felder seitlich).
func nach_schuss(e: Einheit) -> void:
	if not von_person(nem.person_von(e)).has("markierung"):
		return
	var k: Kommandant = nem.spiel.kommandant
	var quer := Vector2.RIGHT
	if k != null and k.position.distance_to(e.position) > 1.0:
		quer = (k.position - e.position).normalized().orthogonal()
	var seite := 1.0 if Zufall.f() < 0.5 else -1.0
	var hier := nem.o24.karte.zelle_bei(e.position)
	var ziel := nem.o24._freies_feld_bei(e.position + quer * seite * 2.5 * Werte.ZELLE, hier)
	umstellen[e.get_instance_id()] = {"bis": nem.o24.zeit + w("markierung", "umstellen"), "ziel": ziel}
