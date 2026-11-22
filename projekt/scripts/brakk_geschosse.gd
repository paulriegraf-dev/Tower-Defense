class_name BrakkGeschosse
extends Node
## 20.11.: Schritt 6c – Ausweichen im Brakk-Mode (Classic und Rogue).
## Schüsse auf Brakk fliegen hier als echte Geschosse mit Tempo, Richtung und Trefferbereich; Brakks Trefferbereich ist
## der Rumpf (Werte.BRAKK_RUMPF). Verfehlt ein Geschoss, fliegt es weiter und schlägt in der nächsten Mauer oder am Ende
## seiner Bahn sichtbar ein. Ohne Flugzeit wird telegrafiert: Scharfschütze mit rotem Zielstrahl, Geschütz- und
## Lanzenturm mit Aufglühen, dann Schuss auf die Stelle, an der Brakk beim Aufglühen stand.
## Nur Schüsse auf Brakk laufen hierüber – die 2D-Logik aller anderen Figuren bleibt, wie sie ist.
## Zeit: Echtzeit-Sekunden (Spiel-delta / BRAKK_TEMPO), in der Zeitlupe entsprechend langsamer.

var spiel: Node = null
var karte: Karte = null
## Für den headless-Test (werkzeuge/ausweichtest.gd): ohne Spiel liefert ziel_fn Brakks Lage
## ({"pos": Vector2, "sprung": Felder über dem Boden, "durchlass": bool}) und treffer_fn nimmt (Schaden, Art) entgegen.
var ziel_fn: Callable
var treffer_fn: Callable
var zufall := RandomNumberGenerator.new()
var vorhalt := Werte.BRAKK_VORHALT
var _brakk_v := Vector2.ZERO   # Brakks Laufgeschwindigkeit (Bildpunkte je Echtzeit-Sekunde, geglättet) für den Vorhalt
var _brakk_alt := Vector2.INF

var geschosse: Array = []      # fliegende Geschosse (Dictionary)
var zielstrahlen: Array = []   # Scharfschützen, die gerade zielen
var gluehen: Array = []        # Türme, die gerade aufglühen
var braende: Array = []        # Brandflächen des Plasmas: {"mitte", "r", "rest", "dps", "quelle"}
var wuerfe: Array = []         # 22.11. (Nemesis Teil 3): Würfe auf eine Stelle (Sperrbrand, Ausräuchern)
var spaeter_liste: Array = []  # 22.11. (Nemesis Teil 4): {"t", "was": Callable} – verzögerte Schüsse (Doppelblitz)
var treffer_von := Vector2.INF # woher der letzte Treffer kam (für den Randblitz der Ego-Sicht) …
var treffer_ms := -100000      # … und wann (ms)
var abgefeuert := 0            # Zähler für den Test
var getroffen := 0

var _knoten: Array = []        # 3D-Bilder: [Node3D, Restzeit, Dauer, Art]
var _mat: StandardMaterial3D = null


func einrichten(p_spiel: Node) -> void:
	spiel = p_spiel
	karte = spiel.karte
	zufall.randomize()


## Ist dieses Ziel Brakk im Brakk-Mode? (Classic: Brakk selbst; Rogue: sein Stellvertreter in der Gegnerliste)
func ist_brakk(ziel: Variant) -> bool:
	if spiel == null or ziel == null or not is_instance_valid(ziel):
		return false
	if spiel.order24 != null and ziel == spiel.order24.brakk_ziel:
		return true
	return ziel == spiel.kommandant and (ziel as Kommandant).ego


# ------------------------------------------------------------------ Abfeuern

## 20.11. (Paul): In Befehl 24 fliegen Laser und Battlesphären-Schüsse langsamer (Regelpaket geschoss_tempo), damit man
## gegen viele Schützen zugleich noch reagieren kann. Plasma bleibt (ist schon gut lesbar). Classic unverändert.
func _tempo_mal(art: String) -> float:
	if spiel == null or spiel.order24 == null or art == "plasma":
		return 1.0
	return spiel.order24.wf("geschoss_tempo") / 100.0


## Fliegendes Geschoss (`art`: laser, sph, plasma) von `von` (Mündungshöhe `von_h` in Feldern) auf Brakk.
## `typ` bestimmt den Schadensfaktor (Werte.BRAKK_AUSWEICH_SCHADEN), `quelle` die Schadensquelle (Statistik).
## 22.11.: `genau` – Anteil der Streuung (Nemesis: Eliten treffen sicherer), sonst 1.
## 22.11. (Nemesis Teil 3): `punkt` – auf diese Stelle statt auf Brakk (Unterdrückungsfeuer im Kegel; ohne Vorhalt und Streuung).
func schiesse(art: String, von: Vector2, von_h: float, schaden: float, typ: String, quelle: String, genau: float = 1.0, punkt: Vector2 = Vector2.INF) -> void:
	var z := _ziel()
	if z.is_empty():
		return
	var w: Dictionary = Werte.BRAKK_GESCHOSS[art]
	var ziel: Vector2 = z["pos"] if punkt == Vector2.INF else punkt
	if vorhalt > 0.0 and punkt == Vector2.INF:
		var flug := von.distance_to(ziel) / (float(w["tempo"]) * _tempo_mal(art) * Werte.ZELLE)
		ziel += (z.get("v", Vector2.ZERO) as Vector2) * flug * vorhalt
	var r :=(ziel - von).normalized() if ziel.distance_to(von) > 1.0 else Vector2.RIGHT
	if punkt == Vector2.INF:
		ziel += Vector2(-r.y, r.x) * zufall.randf_range(-1.0, 1.0) * Werte.BRAKK_STREUUNG * genau * Werte.ZELLE   # Streuung quer zur Bahn
	r = (ziel - von).normalized() if ziel.distance_to(von) > 1.0 else r
	var d_ziel := maxf(von.distance_to(ziel), 1.0)
	var boden := art == "plasma"
	var lang := d_ziel if boden else _bahn_ende(von, r, d_ziel)
	var rumpf_h := float(z.get("fuss", 0.0)) + 0.5
	var g := {"art": art, "von": von, "r": r, "s": 0.0, "lang": lang, "d_ziel": d_ziel,
		"tempo": float(w["tempo"]) * _tempo_mal(art) * Werte.ZELLE, "radius": float(w["radius"]) * Werte.ZELLE,
		"h0": von_h, "h1": (float(z.get("fuss", 0.0)) if boden else rumpf_h), "boden": boden,
		"schaden": schaden, "typ": typ, "quelle": quelle, "leucht": null}
	abgefeuert += 1
	if spiel != null:
		var flug := lang / float(g["tempo"])
		if boden:
			spiel.effekte.warnung(ziel, flug * Werte.BRAKK_TEMPO)   # Vorwarnkreis am Landepunkt (Draufsicht, Minikarte)
			_ring(_zu3d(ziel, 0.04), float(w["einschlag"]), _farbe(art), flug)   # … und in der Ego-Sicht
		g["bild"] = _geschoss_bild(art, float(w["dicke"]))
		_geschoss_bild_setzen(g)
	geschosse.append(g)


## Scharfschütze: 0,6 s roter Zielstrahl in fester Richtung, dann Hitscan entlang der Linie.
## 22.11. (Nemesis Teil 3): eigene Ladezeit `sek`, Breite (`breite_mal`), Farbe (Durchschuss hell und dick, Markierung
## orange) und `bei_treffer` (wird mit dem Trefferpunkt gerufen).
func scharf(wer: Node2D, von: Vector2, von_h: float, weite: float, schaden: float, quelle: String, sek: float = Werte.BRAKK_SCHARF_ZIEL_SEK,
		breite_mal: float = 1.0, farbe: Color = Color(1.0, 0.12, 0.1), bei_treffer: Callable = Callable()) -> void:
	var z := _ziel()
	if z.is_empty():
		return
	var r := ((z["pos"] as Vector2) - von).normalized()
	abgefeuert += 1
	zielstrahlen.append({"wer": wer, "von": von, "h": von_h, "ende": von + r * weite, "t": 0.0, "schaden": schaden,
		"quelle": quelle, "ziel_h": float(z.get("fuss", 0.0)) + 0.5, "bild": null, "sek": sek, "breite_mal": breite_mal, "farbe": farbe, "bei_treffer": bei_treffer})


## 22.11. (Nemesis Teil 3): Wurf auf eine Stelle – Sperrbrand (flach, kurz) und Ausräuchern (hoher Bogen über einen Wall,
## langsam, mit Schatten am Boden). Vorwarnkreis für die ganze Flugzeit; beim Aufschlag Schaden im Umkreis (nicht im
## Sprung, nicht im Tumble) und ein Brandfeld für `brand_sek`.
func wurf(von: Vector2, punkt: Vector2, flug: float, radius: float, brand_sek: float, dps: float, schaden: float, quelle: String, hoch: bool) -> void:
	abgefeuert += 1
	var w := {"von": von, "nach": punkt, "t": 0.0, "flug": maxf(0.1, flug), "r": radius, "brand": brand_sek, "dps": dps, "schaden": schaden,
		"quelle": quelle, "hoch": hoch, "bild": null, "schatten": null}
	if spiel != null:
		spiel.effekte.warnung(punkt, flug * Werte.BRAKK_TEMPO)
		_ring(_zu3d(punkt, 0.04), radius / Werte.ZELLE, _farbe("plasma"), flug)
		w["bild"] = _geschoss_bild("plasma", float((Werte.BRAKK_GESCHOSS["plasma"] as Dictionary)["dicke"]) * (1.4 if hoch else 1.0))
		if hoch:
			w["schatten"] = _schatten_bild()
	wuerfe.append(w)


## 22.11. (Nemesis Teil 4): Sprengfalle des Fallenstellers – liegt still, blinkt und piept `zuender` Sekunden, dann Knall.
func falle(punkt: Vector2, zuender: float, radius: float, schaden: float, quelle: String) -> void:
	abgefeuert += 1
	var w := {"von": punkt, "nach": punkt, "t": 0.0, "flug": zuender, "r": radius, "brand": 0.0, "dps": 0.0, "schaden": schaden,
		"quelle": quelle, "hoch": false, "falle": true, "bild": null, "schatten": null, "piep": 0.0}
	if spiel != null:
		spiel.effekte.warnung(punkt, zuender * Werte.BRAKK_TEMPO)
		_ring(_zu3d(punkt, 0.04), radius / Werte.ZELLE, Color("ff9a3d"), zuender)
		var hd := _hd()
		if hd != null:
			var m := MeshInstance3D.new()
			var box := BoxMesh.new()
			box.size = Vector3(0.22, 0.12, 0.22)
			m.mesh = box
			m.material_override = _leucht_mat(Color("ff9a3d"), 0.95)
			hd.add_child(m)
			m.position = _zu3d(punkt, 0.07)
			w["schatten"] = m
	wuerfe.append(w)


## 22.11. (Nemesis Teil 4): etwas nach `sek` echten Sekunden ausführen (Doppelblitz: Schuss nach dem Tumble-Fenster).
func spaeter(sek: float, was: Callable) -> void:
	spaeter_liste.append({"t": sek, "was": was})


## Mündungsblitz (Doppelblitz-Ankündigung).
func aufblitzen(wo: Vector2, farbe: Color) -> void:
	_blitz(_zu3d(wo, 0.5), farbe, 0.35)


## Kegel am Boden (Unterdrückungsfeuer): zwei Randlinien und die Mitte, verblassen über `dauer`.
func kegel_bild(von: Vector2, richtung: Vector2, winkel_grad: float, weite: float, farbe: Color, dauer: float) -> void:
	if _hd() == null:
		return
	for g: float in [-winkel_grad, 0.0, winkel_grad]:
		var ende := von + richtung.rotated(deg_to_rad(g)) * weite
		_balken(_zu3d(von, 0.06), _zu3d(ende, 0.06), farbe, 0.05 if g == 0.0 else 0.035, dauer)


## Geschütz- oder Lanzenturm auf Brakk: Aufglühen, dann Schuss auf die Stelle von jetzt. `breite` in Bildpunkten.
func turm(z: Vector2i, von: Vector2, art: String, schaden: float, weite: float, breite: float, strahlen: int, quelle: String) -> void:
	var ziel := _ziel()
	if ziel.is_empty():
		return
	var r := ((ziel["pos"] as Vector2) - von).normalized()
	for i in strahlen:
		abgefeuert += 1
		gluehen.append({"z": z, "von": von, "ende": von + r * weite, "t": -0.35 * i, "art": art, "schaden": schaden,
			"breite": breite, "quelle": quelle, "ziel_h": float(ziel.get("fuss", 0.0)) + 0.5, "bild": null, "zweiter": i > 0})


# ------------------------------------------------------------------ Ablauf

func _physics_process(_takt: float) -> void:
	var delta := Werte.sim_schritt()   # 9a: feste Schrittweite, unabhaengig von Tempo und Bildrate
	if spiel == null:
		return
	if spiel.phase != 1:
		leeren()
		return
	weiter(delta / Werte.BRAKK_TEMPO)


func weiter(dt: float) -> void:
	var z := _ziel()
	if not z.is_empty() and dt > 0.0:
		var p: Vector2 = z["pos"]
		if _brakk_alt != Vector2.INF and p.distance_to(_brakk_alt) < Werte.ZELLE:
			_brakk_v = _brakk_v.lerp((p - _brakk_alt) / dt, 0.25)
		_brakk_alt = p
	var noch: Array = []
	for g: Dictionary in geschosse:
		if _geschoss_weiter(g, dt, z):
			noch.append(g)
	geschosse = noch
	noch = []
	for s: Dictionary in zielstrahlen:
		s["t"] = float(s["t"]) + dt
		if s["wer"] != null and (not is_instance_valid(s["wer"]) or (s["wer"] is Einheit and (s["wer"] as Einheit).leben <= 0.0)):
			_bild_weg(s)
			continue   # der Schütze ist gefallen
		if float(s["t"]) >= float(s.get("sek", Werte.BRAKK_SCHARF_ZIEL_SEK)):
			_bild_weg(s)
			var bm := float(s.get("breite_mal", 1.0))
			var tp := _hitscan(s["von"], s["ende"], Werte.BRAKK_SCHARF_BREITE * bm * Werte.ZELLE, float(s["schaden"]), "scharfschuetze", str(s["quelle"]), z)
			_balken(_zu3d(s["von"], float(s["h"])), _zu3d(s["ende"], float(s["ziel_h"])), Color("9dff8a") if bm <= 1.0 else Color("fff4c2"), 0.05 * bm, 0.14 * bm)
			var cb: Variant = s.get("bei_treffer", Callable())
			if tp != Vector2.INF and cb is Callable and (cb as Callable).is_valid():
				(cb as Callable).call(tp)   # 22.11.: Nemesis – Markierung nach einem Treffer
			continue
		_zielstrahl_bild(s)
		noch.append(s)
	zielstrahlen = noch
	noch = []
	for t: Dictionary in gluehen:
		t["t"] = float(t["t"]) + dt
		if karte != null and spiel != null and not karte.turm_aktiv(t["z"]):
			_bild_weg(t)
			continue   # Turm gefallen oder lahmgelegt
		if float(t["t"]) >= Werte.BRAKK_TURM_GLUEHEN:
			_bild_weg(t)
			_turm_feuer(t, z)
			continue
		if float(t["t"]) >= 0.0:
			_glueh_bild(t)
		noch.append(t)
	gluehen = noch
	for b: Dictionary in braende:
		b["rest"] = float(b["rest"]) - dt
		if not z.is_empty() and not bool(z["durchlass"]) and float(z["sprung"]) <= Werte.BRAKK_SPRUNG_BODEN \
				and (z["pos"] as Vector2).distance_to(b["mitte"]) <= float(b["r"]) + Werte.BRAKK_RUMPF * Werte.ZELLE:
			_treffe_brakk(float(b["dps"]) * dt, "plasmawerfer", str(b["quelle"]), b["mitte"], false)
	braende = braende.filter(func(b: Dictionary) -> bool: return float(b["rest"]) > 0.0)
	noch = []
	for w: Dictionary in wuerfe:
		w["t"] = float(w["t"]) + dt
		if float(w["t"]) >= float(w["flug"]):
			_wurf_landet(w, z)
			continue
		_wurf_bild(w)
		noch.append(w)
	wuerfe = noch
	var faellig: Array = []
	for s: Dictionary in spaeter_liste:
		s["t"] = float(s["t"]) - dt
		if float(s["t"]) <= 0.0:
			faellig.append(s)
	for s: Dictionary in faellig:
		spaeter_liste.erase(s)
		if (s["was"] as Callable).is_valid():
			(s["was"] as Callable).call()
	_bilder_weiter(dt)


## 22.11. (Nemesis Teil 3): Wurf schlägt auf – Schaden im Umkreis, dann Brandfeld.
func _wurf_landet(w: Dictionary, z: Dictionary) -> void:
	_bild_weg(w)
	if w.get("schatten") != null and is_instance_valid(w["schatten"]):
		(w["schatten"] as Node).queue_free()
	var wo: Vector2 = w["nach"]
	var r := float(w["r"])
	if not z.is_empty() and not bool(z["durchlass"]) and float(z["sprung"]) <= Werte.BRAKK_SPRUNG_BODEN \
			and (z["pos"] as Vector2).distance_to(wo) <= r + Werte.BRAKK_RUMPF * Werte.ZELLE:
		getroffen += 1
		_treffe_brakk(float(w["schaden"]), "plasmawerfer", str(w["quelle"]), w["von"], true)
	if float(w["brand"]) > 0.0:
		braende.append({"mitte": wo, "r": r, "rest": float(w["brand"]), "dps": float(w["dps"]), "quelle": w["quelle"]})
	if spiel != null:
		if float(w["brand"]) > 0.0:
			spiel.effekte.brand(wo, r, float(w["brand"]) * Werte.BRAKK_TEMPO)
		spiel.effekte.flaeche(wo, r, _farbe("plasma"))
		_blitz(_zu3d(wo, 0.2), _farbe("plasma"), 0.8)
		Ton.am_ort(spiel, "hit-boom", wo)


## Ball auf der Wurfbahn (Bogen: hoch beim Ausräuchern) und sein Schatten am Boden. Falle: blinkt und piept, schneller zum Ende.
func _wurf_bild(w: Dictionary) -> void:
	if bool(w.get("falle", false)):
		var rest := float(w["flug"]) - float(w["t"])
		w["piep"] = float(w["piep"]) - 1.0 / 60.0
		if float(w["piep"]) <= 0.0:
			w["piep"] = clampf(rest / 6.0, 0.12, 0.5)
			if spiel != null:
				Ton.am_ort(spiel, "ui-klick", w["nach"] as Vector2)
		if w.get("schatten") != null and is_instance_valid(w["schatten"]):
			(w["schatten"] as Node3D).visible = fmod(float(w["t"]), clampf(rest / 3.0, 0.15, 0.6)) < 0.08 + clampf(rest / 6.0, 0.0, 0.25)
		return
	var a := float(w["t"]) / float(w["flug"])
	var p := (w["von"] as Vector2).lerp(w["nach"] as Vector2, a)
	var h := lerpf(0.5, 0.05, a) + (3.5 if bool(w["hoch"]) else 1.0) * 4.0 * a * (1.0 - a)
	if w.get("bild") != null and is_instance_valid(w["bild"]):
		var kopf := (w["bild"] as Node3D).get_child(0) as Node3D
		kopf.position = _zu3d(p, h)
		((w["bild"] as Node3D).get_child(1) as Node3D).visible = false
	if w.get("schatten") != null and is_instance_valid(w["schatten"]):
		(w["schatten"] as Node3D).position = _zu3d(p, 0.03)
		(w["schatten"] as Node3D).scale = Vector3.ONE * lerpf(0.6, 1.2, a)


func _schatten_bild() -> Node3D:
	var hd := _hd()
	if hd == null:
		return null
	var m := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = 0.3
	c.bottom_radius = 0.3
	c.height = 0.01
	m.mesh = c
	var mat := _leucht_mat(Color(0, 0, 0), 0.45)
	m.material_override = mat
	hd.add_child(m)
	return m


## Ein Geschoss ein Stück weiter. false = es ist weg (Treffer oder Einschlag).
func _geschoss_weiter(g: Dictionary, dt: float, z: Dictionary) -> bool:
	var von: Vector2 = g["von"]
	var r: Vector2 = g["r"]
	var s_alt := float(g["s"])
	var s_neu := minf(s_alt + float(g["tempo"]) * dt, float(g["lang"]))
	g["s"] = s_neu
	if not z.is_empty() and not bool(z["durchlass"]) and not (bool(g["boden"]) and float(z["sprung"]) > Werte.BRAKK_SPRUNG_BODEN):
		var p := Geometry2D.get_closest_point_to_segment(z["pos"], von + r * s_alt, von + r * s_neu)
		if p.distance_to(z["pos"]) <= float(g["radius"]) + Werte.BRAKK_RUMPF * Werte.ZELLE:
			getroffen += 1
			_treffe_brakk(float(g["schaden"]), str(g["typ"]), str(g["quelle"]), von, true)
			_einschlag_bild(p, _hoehe(g, von.distance_to(p)), g, true)
			if bool(g["boden"]):
				_plasma_landet(g, p, z, false)
			return false
	if s_neu >= float(g["lang"]):
		var ende := von + r * s_neu
		_einschlag_bild(ende, _hoehe(g, s_neu), g, false)
		if bool(g["boden"]):
			_plasma_landet(g, ende, z, true)
		return false
	_geschoss_bild_setzen(g)
	return true


## Plasmaball am Boden: Einschlag mit kleiner Fläche (nur wenn er Brakk nicht schon direkt getroffen hat) und Brandfläche.
func _plasma_landet(g: Dictionary, wo: Vector2, z: Dictionary, flaeche: bool) -> void:
	var w: Dictionary = Werte.BRAKK_GESCHOSS["plasma"]
	var radius := float(w["einschlag"]) * Werte.ZELLE
	if flaeche and not z.is_empty() and not bool(z["durchlass"]) and float(z["sprung"]) <= Werte.BRAKK_SPRUNG_BODEN \
			and (z["pos"] as Vector2).distance_to(wo) <= radius + Werte.BRAKK_RUMPF * Werte.ZELLE:
		getroffen += 1
		_treffe_brakk(float(g["schaden"]), str(g["typ"]), str(g["quelle"]), g["von"], true)
	braende.append({"mitte": wo, "r": radius, "rest": float(w["brand_sek"]), "dps": float(g["schaden"]) * float(w["brand_anteil"]), "quelle": g["quelle"]})
	if spiel != null:
		spiel.effekte.brand(wo, radius, float(w["brand_sek"]) * Werte.BRAKK_TEMPO)
		spiel.effekte.flaeche(wo, radius, _farbe("plasma"))


func _turm_feuer(t: Dictionary, z: Dictionary) -> void:
	var von: Vector2 = t["von"]
	var ende: Vector2 = t["ende"]
	var lanze := str(t["art"]) == "lanze"
	var farbe := Color("ff8a3d") if lanze else Color("7fe0ff")
	var p := _hitscan(von, ende, float(t["breite"]), float(t["schaden"]), str(t["art"]), str(t["quelle"]), z)
	if spiel == null:
		return
	if lanze:
		Ton.am_ort(spiel, "tc-arc", von)
		spiel.effekte.strahl(von, ende, farbe, 6.0)
		_balken(_zu3d(von, 0.9), _zu3d(ende, float(t["ziel_h"])), farbe, 0.09, 0.18)
	else:
		Ton.am_ort(spiel, "tc-heavy", von)
		var bis: Vector2 = p if p != Vector2.INF else ende
		spiel.effekte.leuchtschuss(von, 40.0, bis, float(t["ziel_h"]) * Werte.ZELLE, farbe, 0.08, 14.0)
		_balken(_zu3d(von, 0.9), _zu3d(bis, float(t["ziel_h"])), farbe, 0.035, 0.1)
		if p == Vector2.INF:
			spiel.effekte.fx("treffer_c", ende, 0.5)
			_blitz(_zu3d(ende, 0.1), farbe, 0.25)


## Treffer ohne Flugzeit entlang einer Linie. Ergebnis: Trefferpunkt (INF = verfehlt).
func _hitscan(von: Vector2, ende: Vector2, breite: float, schaden: float, typ: String, quelle: String, z: Dictionary) -> Vector2:
	if z.is_empty() or bool(z["durchlass"]):
		return Vector2.INF
	var p := Geometry2D.get_closest_point_to_segment(z["pos"], von, ende)
	if p.distance_to(z["pos"]) > breite + Werte.BRAKK_RUMPF * Werte.ZELLE:
		return Vector2.INF
	getroffen += 1
	_treffe_brakk(schaden, typ, quelle, von, true)
	return p


## Schaden an Brakk – Rogue über den Stellvertreter (dort gelten brakk_schaden und die Statistik je Quelle).
func _treffe_brakk(menge: float, typ: String, quelle: String, von: Vector2, blitz: bool) -> void:
	menge *= float(Werte.BRAKK_AUSWEICH_SCHADEN.get(typ, 1.0))
	if blitz:
		treffer_von = von
		treffer_ms = Time.get_ticks_msec()
	if treffer_fn.is_valid():
		treffer_fn.call(menge, typ)
		return
	var k: Kommandant = spiel.kommandant
	if k == null or k.gefallen:
		return
	if spiel.order24 != null:
		var alt_q: String = spiel.schadensquelle
		var alt_b: String = spiel.brakk_quelle
		spiel.schadensquelle = quelle
		spiel.brakk_quelle = ""
		spiel.order24.brakk_ziel.nimm_schaden(menge)
		spiel.schadensquelle = alt_q
		spiel.brakk_quelle = alt_b
	else:
		k.nimm_fernschaden(menge)   # Ruine deckt wie bisher


## Brakks Lage: Bodenpunkt, Füße über dem Boden (Sprung), absolute Fußhöhe, ob Geschosse durchgehen. {} = kein Ziel.
func _ziel() -> Dictionary:
	if ziel_fn.is_valid():
		var t: Dictionary = ziel_fn.call()
		return t
	var k: Kommandant = spiel.kommandant
	if k == null or k.gefallen:
		return {}
	var e: EgoModus = spiel.ego
	var fuss := e.hoehe if e != null else 0.0
	return {"pos": k.position, "sprung": (fuss - e._boden()) if e != null else 0.0, "fuss": fuss, "durchlass": k.unverwundbar > 0.0, "v": _brakk_v}


## Bahn hinter dem Zielpunkt: weiter bis zur ersten Mauer (oder einem Gebäude), höchstens 4 Felder.
func _bahn_ende(von: Vector2, r: Vector2, d_ziel: float) -> float:
	var hoechstens := d_ziel + 4.0 * Werte.ZELLE
	if karte == null:
		return hoechstens
	var schritt := Werte.ZELLE * 0.2
	var s := d_ziel
	var start_frei := karte.ist_frei(karte.zelle_bei(von + r * s))   # steht Brakk auf dem Wall, zählt erst die nächste Mauer
	while s < hoechstens:
		s += schritt
		var c := karte.zelle_bei(von + r * s)
		if not karte.in_karte(c):
			return s
		var frei := karte.ist_frei(c)
		if frei:
			start_frei = true
		elif start_frei:
			return s
	return hoechstens


func _hoehe(g: Dictionary, s: float) -> float:
	return maxf(0.05, lerpf(float(g["h0"]), float(g["h1"]), s / float(g["d_ziel"])))


func _farbe(art: String) -> Color:
	match art:
		"plasma":
			return Color("ff8ad8")
		"sph":
			return Color("ff4fd8")
	return Color("ff5a4a")   # Laser auf Brakk: rot, gut vom eigenen Cyan zu unterscheiden


func leeren() -> void:
	geschosse.clear()
	for s: Dictionary in zielstrahlen:
		_bild_weg(s)
	for t: Dictionary in gluehen:
		_bild_weg(t)
	zielstrahlen.clear()
	gluehen.clear()
	braende.clear()
	for w: Dictionary in wuerfe:
		_bild_weg(w)
		if w.get("schatten") != null and is_instance_valid(w["schatten"]):
			(w["schatten"] as Node).queue_free()
	wuerfe.clear()
	spaeter_liste.clear()


func _exit_tree() -> void:
	leeren()
	for k: Array in _knoten:
		if is_instance_valid(k[0]):
			(k[0] as Node).queue_free()
	_knoten.clear()


# ------------------------------------------------------------------ 3D-Bilder (Ego-Sicht)

func _hd() -> Node3D:
	if spiel == null or spiel.hd == null or not is_instance_valid(spiel.hd):
		return null
	return spiel.hd


func _zu3d(p: Vector2, h: float) -> Vector3:
	return Vector3(p.x / Werte.ZELLE, h, (p.y - Werte.KARTE_OBEN) / Werte.ZELLE)


func _leucht_mat(farbe: Color, alpha: float) -> StandardMaterial3D:
	if _mat == null:
		_mat = StandardMaterial3D.new()
		_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var m := _mat.duplicate() as StandardMaterial3D
	m.albedo_color = Color(farbe, alpha)   # gemischt statt addiert: sonst überstrahlt alles weiß und die Farbe der Waffe geht verloren
	return m


## Leuchtender Balken von a nach b, verblasst über `dauer` (dauer 0 = bleibt, bis man ihn wegnimmt).
func _balken(a: Vector3, b: Vector3, farbe: Color, dicke: float, dauer: float) -> MeshInstance3D:
	var hd := _hd()
	if hd == null:
		return null
	# Strahlen auf Brakk enden kurz vor seinem Auge (sonst füllt der Balken das halbe Bild)
	var auge: Vector3 = (hd as HdAnsicht).kamera.global_position
	var nah := Geometry3D.get_closest_point_to_segment(auge, a, b)
	if nah.distance_to(auge) < 0.6:
		b = a + (b - a).normalized() * maxf(0.05, a.distance_to(nah) - 1.5)
	var m := MeshInstance3D.new()
	var box := BoxMesh.new()
	var lang := maxf(0.01, a.distance_to(b))
	box.size = Vector3(dicke, dicke, lang)
	m.mesh = box
	m.material_override = _leucht_mat(farbe, 0.9)
	hd.add_child(m)
	m.position = (a + b) / 2.0
	if lang > 0.02:
		m.look_at_from_position(m.position, b, Vector3.UP if absf((b - a).normalized().y) < 0.99 else Vector3.RIGHT)
	if dauer > 0.0:
		_knoten.append([m, dauer, dauer, "weg"])
	return m


## Kurzer Lichtball, der aufgeht und verblasst (Einschlag).
func _blitz(wo: Vector3, farbe: Color, groesse: float) -> void:
	var hd := _hd()
	if hd == null:
		return
	var m := MeshInstance3D.new()
	var kugel := SphereMesh.new()
	kugel.radius = groesse * 0.5
	kugel.height = groesse
	m.mesh = kugel
	m.material_override = _leucht_mat(farbe, 0.9)
	hd.add_child(m)
	m.position = wo
	_knoten.append([m, 0.22, 0.22, "blitz"])


func _bilder_weiter(dt: float) -> void:
	var noch: Array = []
	for k: Array in _knoten:
		var n: Node3D = k[0]
		k[1] = float(k[1]) - dt
		if not is_instance_valid(n):
			continue
		if float(k[1]) <= 0.0:
			n.queue_free()
			continue
		var a := float(k[1]) / float(k[2])
		var mat := (n as MeshInstance3D).material_override as StandardMaterial3D
		mat.albedo_color.a = 0.9 * a
		if str(k[3]) == "blitz":
			n.scale = Vector3.ONE * (1.0 + 1.5 * (1.0 - a))
		noch.append(k)
	_knoten = noch


func _bild_weg(e: Dictionary) -> void:
	if e.get("bild") != null and is_instance_valid(e["bild"]):
		(e["bild"] as Node).queue_free()
	e["bild"] = null


## Fliegendes Geschoss in 3D: farbiger Leuchtkopf und ein Schweif, der hinter ihm herzieht.
func _geschoss_bild(art: String, dicke: float) -> Node3D:
	var hd := _hd()
	if hd == null:
		return null
	var farbe := _farbe(art)
	var n := Node3D.new()
	var kopf := MeshInstance3D.new()
	var kugel := SphereMesh.new()
	kugel.radius = dicke / Werte.ZELLE * 0.5
	kugel.height = kugel.radius * 2.0
	kopf.mesh = kugel
	kopf.material_override = _leucht_mat(farbe, 0.7)
	var kern := MeshInstance3D.new()   # heller Kern, durch die Hülle sichtbar
	var k2 := SphereMesh.new()
	k2.radius = kugel.radius * 0.5
	k2.height = k2.radius * 2.0
	kern.mesh = k2
	kern.material_override = _leucht_mat(farbe.lightened(0.7), 1.0)
	kopf.add_child(kern)
	n.add_child(kopf)
	var schweif := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(kugel.radius * 0.9, kugel.radius * 0.9, 1.0)
	schweif.mesh = box
	schweif.material_override = _leucht_mat(farbe, 0.55)
	n.add_child(schweif)
	hd.add_child(n)
	return n


func _geschoss_bild_setzen(g: Dictionary) -> void:
	var n: Variant = g.get("bild")
	if n == null or not is_instance_valid(n):
		return
	var von: Vector2 = g["von"]
	var r: Vector2 = g["r"]
	var s := float(g["s"])
	var lang := Werte.ZELLE * (0.6 if str(g["art"]) == "plasma" else 0.9)
	var a := _zu3d(von + r * maxf(0.0, s - lang), _hoehe(g, maxf(0.0, s - lang)))
	var b := _zu3d(von + r * s, _hoehe(g, s))
	var kopf := (n as Node3D).get_child(0) as Node3D
	var schweif := (n as Node3D).get_child(1) as Node3D
	kopf.position = b
	var l := a.distance_to(b)
	schweif.visible = l > 0.02
	if l > 0.02:
		schweif.scale = Vector3(1.0, 1.0, l)
		schweif.look_at_from_position((a + b) / 2.0, b, Vector3.UP if absf((b - a).normalized().y) < 0.99 else Vector3.RIGHT)


## Vorwarnkreis des Plasmas am Boden (Ring, pulsiert bis zum Einschlag).
func _ring(wo: Vector3, radius: float, farbe: Color, dauer: float) -> void:
	var hd := _hd()
	if hd == null:
		return
	var m := MeshInstance3D.new()
	var t := TorusMesh.new()
	t.inner_radius = radius - 0.05
	t.outer_radius = radius
	m.mesh = t
	m.scale = Vector3(1.0, 0.15, 1.0)
	m.material_override = _leucht_mat(Color(1.0, 0.25, 0.3).lerp(farbe, 0.3), 0.9)
	hd.add_child(m)
	m.position = wo
	_knoten.append([m, dauer, dauer, "ring"])


## Roter Zielstrahl des Scharfschützen: dünn, wird zum Schuss hin heller und pulsiert schneller.
func _zielstrahl_bild(s: Dictionary) -> void:
	if _hd() == null:
		return
	if s["bild"] == null:
		s["bild"] = _balken(_zu3d(s["von"], float(s["h"])), _zu3d(s["ende"], float(s["ziel_h"])), s.get("farbe", Color(1.0, 0.12, 0.1)) as Color, 0.035 * float(s.get("breite_mal", 1.0)), 0.0)
	var m: MeshInstance3D = s["bild"]
	if m == null:
		return
	var anteil := clampf(float(s["t"]) / float(s.get("sek", Werte.BRAKK_SCHARF_ZIEL_SEK)), 0.0, 1.0)
	var puls := 0.5 + 0.5 * sin(float(s["t"]) * lerpf(20.0, 60.0, anteil))
	(m.material_override as StandardMaterial3D).albedo_color.a = lerpf(0.5, 1.0, anteil) * (0.6 + 0.4 * puls)
	m.scale = Vector3(1.0 + anteil, 1.0 + anteil, 1.0)


## Aufglühen eines Turms vor dem Schuss: wachsender Lichtball an der Mündung.
func _glueh_bild(t: Dictionary) -> void:
	var hd := _hd()
	if hd == null or bool(t["zweiter"]):
		return
	var farbe := Color("ff8a3d") if str(t["art"]) == "lanze" else Color("7fe0ff")
	if t["bild"] == null:
		var m := MeshInstance3D.new()
		var kugel := SphereMesh.new()
		kugel.radius = 0.12
		kugel.height = 0.24
		m.mesh = kugel
		m.material_override = _leucht_mat(farbe, 0.9)
		hd.add_child(m)
		m.position = _zu3d(t["von"], 0.95)
		t["bild"] = m
	var anteil := clampf(float(t["t"]) / Werte.BRAKK_TURM_GLUEHEN, 0.0, 1.0)
	(t["bild"] as Node3D).scale = Vector3.ONE * (0.4 + 1.6 * anteil)


## Einschlag: Treffer an Brakk oder verfehlt in Mauer/Boden – Lichtball und Treffer-Bild am Boden.
func _einschlag_bild(wo: Vector2, h: float, g: Dictionary, an_brakk: bool) -> void:
	_bild_weg(g)
	if spiel == null:
		return
	var art := str(g["art"])
	var farbe := _farbe(art)
	_blitz(_zu3d(wo, h), farbe, 0.5 if art == "plasma" else (0.22 if an_brakk else 0.3))
	if not an_brakk:
		spiel.effekte.fx("treffer_p" if art != "laser" else "treffer_g", wo, 0.55 if art == "plasma" else 0.4)
