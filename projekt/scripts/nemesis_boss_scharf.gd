class_name NemesisBossScharf
extends NemesisBoss
## C2 (26.11., Paul): Befehl 24 – der Scharfschütze als Herausforderer. Distanz und Wälle.
##  - Bewegung: größerer Abstand (Lieblingsabstand × 1,3, mindestens 8 Felder), wechselt oft die Wallkrone und zieht sich
##    mit Brakks Anker hinauf (0,5 s steht das Seil, dann der Zug).
##  - Phase 1: Salve in vier Wellen (Fächer zu drei Schüssen, je 6° weiter – Stehenbleiben reicht nie), Sturm wie bisher,
##    das Laservisier (F5: regulär, nach einem Sturm bevorzugt) (Ring 10 Felder; 1,5 s rote Linie und „ANVISIERT“, dann Strahl je Sekunde, solange
##    Brakk in Reichweite und Sicht ist, höchstens 2,5 s).
##  - Phase 2: einmal die Zielmarkierung – sechs Erdwälle mit Stellung fallen an den Rand des Kampfplatzes, je mit einem
##    Scharfschützen Stufe 1 (sichtbare Geschosse mit Aufleuchten, nichts wird ersetzt; der Boss geht nicht hinein).

const ROT := Color("ff3b3b")
const SEIL := Color("7fe0ff")

var _marke_offen := false        # Phase 2: die Zielmarkierung steht noch aus …
var marke_gesetzt := false       # … und kommt nur einmal
var schuetzen: Array = []        # je {"e": Einheit, "z": Vector2i, "in": Sekunden bis zum Schuss, "leuchtet": bool}
var laser_schaden := 0.0         # Prüfung: Schaden des Strahls (Anteile eines Treffers)


func abstand(grund: float) -> float:
	return maxf(Werte.BOSS_SNIPER_ABSTAND_MIN, grund * Werte.BOSS_SNIPER_ABSTAND_MAL)


func wall_abkling() -> float:
	return Werte.BOSS_SNIPER_KRONE_SEK


func krone_mit_angriff() -> bool:
	return true   # F5: kein Hüpfen von Krone zu Krone ohne Schuss


## Mit Brakks Anker auf die Krone: das Seil steht 0,5 s, dann zieht es ihn hinauf.
func weg_auf_krone(von: Vector2, nach: Vector2) -> Dictionary:
	var hoch: float = spiel.hd.H if spiel.hd != null else 1.0
	bg._balken(bg._zu3d(von, 0.9), bg._zu3d(nach, hoch + 0.1), SEIL, 0.03, _bg(Werte.BOSS_SNIPER_ANKER_ANSAGE + Werte.BOSS_SNIPER_ANKER_ZUG))
	Ton.am_ort(spiel, "tc-arc", von)
	_protokoll("anker", {"nach": nach})
	return {"art": "sprung", "t": 0.0, "sek": Werte.BOSS_SNIPER_ANKER_ANSAGE + Werte.BOSS_SNIPER_ANKER_ZUG, "vorlauf": Werte.BOSS_SNIPER_ANKER_ANSAGE,
		"von": von, "nach": nach, "hoch": 0.6}


func gewichte(abstand_felder: float, letzte: Array) -> Dictionary:
	if _marke_offen and not marke_gesetzt:
		return {"zielmarkierung": 1.0}
	# F5 (26.11., Paul): das Laservisier ist ein regulärer Angriff (vorher nur nach einem Sturm, dann erzwungen)
	var g := {"salve": 1.0, "laser": 1.0 if abstand_felder >= 6.0 else 0.3, "sturm": 1.2 if abstand_felder < 6.0 else 0.5}
	if not letzte.is_empty() and str(letzte[-1]) == "sturm":
		g["laser"] = 1.8   # nach einem Sturm läuft er gern in Reichweite und zielt
	return g


## G2-2 (27.11., Paul): P1 Salve (4 Wellen) · Laservisier · Kronenwechsel + Salve · Sturm · Laservisier · [Salve | Sturm].
## P2: einmal die Zielmarkierung, dann dieselbe Folge mit Fenstern × 0,7 – das Laservisier darf zweimal hintereinander.
func abfolge(phase2: bool) -> Array:
	var f := Werte.BOSS_ABFOLGE_FENSTER * (Werte.BOSS_ABFOLGE_P2_FENSTER if phase2 else 1.0)
	var b := Werte.BOSS_ABFOLGE_BEWEGUNG
	# G2-3: Druck = Laservisier und Kronenwechsel + Salve (der Boden brennt, Brakk muss auf eine Krone)
	if not phase2:
		return [s("salve", f, b), s("laser", f, b, {"druck": true}), s("salve", f, b, {"krone": true, "druck": true}), s("sturm", f, b), s("laser", f, b), s(["salve", "sturm"], f, b)]
	return [s("salve", f, b), s("laser", f, b), s("laser", f, b, {"druck": true}), s("salve", f, b, {"krone": true, "druck": true}), s("sturm", f, b), s(["salve", "sturm"], f, b)]


func anker_zwang() -> bool:
	return true


func eroeffnung(phase2: bool) -> Array:
	return [s("zielmarkierung", Werte.BOSS_ABFOLGE_FENSTER * Werte.BOSS_ABFOLGE_P2_FENSTER, Werte.BOSS_ABFOLGE_BEWEGUNG)] if phase2 else []


func kann(art: String, _abstand: float) -> bool:
	return art != "zielmarkierung" or not marke_gesetzt


## Ringe für Salve (Durchschlag, Wirbel) wirken auf seine Salve in Wellen; eine Kugel hat er nicht.
func ring_angriff(art: String) -> String:
	return art if art == "salve" else ""


func beginne(art: String) -> bool:
	var a := h.angriff
	match art:
		"salve":
			a["um"] = Werte.BOSS_SNIPER_SALVE_ANSAGE
			h.einheit._sprite.angriff(Werte.BOSS_SNIPER_SALVE_ANSAGE + Werte.BOSS_SNIPER_SALVE_TAKT * Werte.BOSS_SNIPER_SALVE_WELLEN)
			var r: Vector2 = a["richtung"]
			var dreh := Werte.BOSS_SNIPER_SALVE_DREH * (Werte.BOSS_SNIPER_SALVE_WELLEN - 1)
			var weite := maxf(6.0 * Werte.ZELLE, h.einheit.position.distance_to(a["ziel"] as Vector2) + 2.0 * Werte.ZELLE)
			# alle vier Fächer zusammen am Boden: wo man nicht stehen darf
			bg.kegel_bild(h.einheit.position, r.rotated(deg_to_rad(dreh * 0.5)), Werte.HERAUSFORDERER_SALVE_FAECHER + dreh * 0.5, weite, ROT, _bg(Werte.BOSS_SNIPER_SALVE_ANSAGE + Werte.BOSS_SNIPER_SALVE_TAKT * Werte.BOSS_SNIPER_SALVE_WELLEN))
			bg.aufblitzen(h._muendung(r), ROT)
			Ton.am_ort(spiel, "tc-arc", h.einheit.position)
			return true
		"laser":
			a["teil"] = "typ"
			a["phase"] = "anlauf"
			return true
		"zielmarkierung":
			a["um"] = Werte.BOSS_SNIPER_MARKE_ANSAGE
			h.einheit._sprite.angriff(Werte.BOSS_SNIPER_MARKE_ANSAGE)
			Ton.spiele(spiel, "tc-arc", 0.0)   # Funkton
			spiel.melde(tr("%s funkt: „Zielmarkierung – Stellungen!“") % str(h.person["name"]), 3.0)
			return true
	return false


func feuer(art: String, _k: Kommandant) -> bool:
	match art:
		"salve":
			var r: Vector2 = h.angriff["richtung"]
			var weit := h.einheit.position.distance_to(h.angriff["ziel"] as Vector2)
			for i in Werte.BOSS_SNIPER_SALVE_WELLEN:
				if i == 0:
					_faecher(r, weit, 0)
				else:
					bg.spaeter(_bg(Werte.BOSS_SNIPER_SALVE_TAKT * i), _faecher.bind(r, weit, i))
			return true
		"zielmarkierung":
			marke_gesetzt = true
			var kp := h.kampfplatz
			_protokoll("zielmarkierung", {"platz": kp.aktiv()})
			if kp.aktiv():
				for i in Werte.BOSS_SNIPER_STELLUNGEN.size():
					kp.abwerfen(kp.mitte + Werte.BOSS_SNIPER_STELLUNGEN[i], Werte.KAMPFPLATZ_SCHATTEN_SEK + Werte.BOSS_SNIPER_STELLUNG_FALL * i, _stellung_da)
			return true
	return false


## Ein Fächer zu drei Schüssen, um `welle` × 6° weiter gedreht; trifft höchstens einmal.
func _faecher(r: Vector2, weit: float, welle: int) -> void:
	if h.einheit == null or not is_instance_valid(h.einheit) or h.einheit.kampfunfaehig:
		return
	h._salven += 1
	var dreh := Werte.BOSS_SNIPER_SALVE_DREH * welle
	for grad: float in [-Werte.HERAUSFORDERER_SALVE_FAECHER, 0.0, Werte.HERAUSFORDERER_SALVE_FAECHER]:
		var punkt := h.einheit.position + r.rotated(deg_to_rad(grad + dreh)) * maxf(weit, 2.0 * Werte.ZELLE)
		bg.schiesse("hf_salve", h._muendung(r), h._hoehe_er(), h.schaden() * Werte.BOSS_SNIPER_SALVE_ANTEIL, "herausforderer", h.quelle(), 1.0, punkt)
		(bg.geschosse.back() as Dictionary)["gruppe"] = h._salven
		h._an_der_wand_enden(bg.geschosse.back() as Dictionary)
	Ton.am_ort(spiel, "tc-blaster", h.einheit.position)
	_protokoll("faecher", {"welle": welle})


## Laservisier: in Reichweite laufen, zielen (rote Linie, HUD), dann der Strahl.
func weiter_angriff(dt: float, k: Kommandant) -> void:
	var a := h.angriff
	var t := float(a["t"])
	var e := h.einheit
	var d := e.position.distance_to(k.position) / Werte.ZELLE
	var sicht := h.sieht(e.position, k.position)   # F5: von der Krone über das eigene Wallstück
	match str(a.get("phase", "anlauf")):
		"anlauf":
			if (d <= Werte.BOSS_SNIPER_LASER_WEITE - 0.5 and sicht) or t >= Werte.BOSS_SNIPER_LASER_ANLAUF:
				if d > Werte.BOSS_SNIPER_LASER_WEITE or not sicht:
					a["angesagt"] = 0.5
					h.fenster()   # nicht hingekommen: kein Strahl
					return
				a["phase"] = "ziel"
				a["t"] = 0.0
				_ring(e.position, Werte.BOSS_SNIPER_LASER_WEITE, ROT, Werte.BOSS_SNIPER_LASER_ZIELEN + Werte.BOSS_SNIPER_LASER_SEK)
				Ton.am_ort(spiel, "tc-rail", e.position)
				_protokoll("laser_ziel")
			else:
				h._laufe(dt, k, Werte.BOSS_SNIPER_LASER_WEITE - 2.0, h.tempo())
		"ziel":
			e._sprite.bewegt(false)
			h.anvisiert = e.position
			var rot := 0.55 + 0.45 * sin(t * 26.0)
			e._sprite.modulate = Color(1.0, 1.0 - 0.75 * rot, 1.0 - 0.75 * rot)
			bg._balken(bg._zu3d(h._muendung((k.position - e.position).normalized()), h._hoehe_er()), bg._zu3d(k.position, 0.6), ROT, 0.02, _bg(dt * 1.5))
			if t >= Werte.BOSS_SNIPER_LASER_ZIELEN:
				e._sprite.modulate = Color.WHITE
				a["phase"] = "strahl"
				a["t"] = 0.0
				a["angesagt"] = Werte.BOSS_SNIPER_LASER_ZIELEN
		"strahl":
			h.anvisiert = e.position
			if d > Werte.BOSS_SNIPER_LASER_WEITE or not sicht or t >= Werte.BOSS_SNIPER_LASER_SEK:
				_protokoll("laser_ende", {"dauer": t, "schaden": laser_schaden})
				h.fenster()   # aus der Reichweite, hinter einem Wall oder vorbei
				return
			var ende := k.position
			bg._balken(bg._zu3d(h._muendung((ende - e.position).normalized()), h._hoehe_er()), bg._zu3d(ende, 0.6), ROT.lightened(0.3), 0.08, _bg(dt * 1.5))
			if k.unverwundbar <= 0.0:
				_treffe(Werte.BOSS_SNIPER_LASER_JE_SEK * dt, e.position, false)
				laser_schaden += Werte.BOSS_SNIPER_LASER_JE_SEK * dt


func wut() -> void:
	_marke_offen = true


## Ein Erdwall der Zielmarkierung ist gelandet: daraus wird eine Stellung, ein Scharfschütze Stufe 1 beamt hinauf.
func _stellung_da(z: Vector2i) -> void:
	var karte: Karte = o24.karte
	karte.baue_aus(z, Karte.STELLUNG)
	var e := o24._neue_truppe("scharfschuetze", h._fabrik_fuer("scharfschuetze"), 1)
	e.set_meta("kampfplatz_erlaubt", true)   # die Lichtwand schiebt ihn nicht hinaus
	e.halt = true                            # schießt nur hier (sichtbar, mit Aufleuchten)
	e._punkte.clear()
	e.zustand = Einheit.Zustand.AUF_POSTEN
	e.posten_zelle = z
	karte.posten[z] = e
	e.position = karte.mitte(z)
	spiel.effekte.flaeche(e.position, Werte.ZELLE * 0.6, Order24.TECHNO_FARBE)
	schuetzen.append({"e": e, "z": z, "in": Werte.BOSS_SNIPER_STELLUNG_TAKT * randf_range(0.6, 1.0), "leuchtet": false})
	_protokoll("stellung", {"z": z})


## Die Schützen der Zielmarkierung: Aufleuchten, dann ein sichtbarer Schuss auf Brakk. Gefallene kommen nicht wieder.
func immer(dt: float, k: Kommandant) -> void:
	for s: Dictionary in schuetzen:
		var e: Variant = s["e"]
		if not Nemesis.lebt(e) or (e as Einheit).kampfunfaehig:
			continue
		var u := e as Einheit
		u.halt = true
		s["in"] = float(s["in"]) - dt
		var sicht := o24.karte.sicht_frei(u.position, k.position)
		if float(s["in"]) <= Werte.BOSS_SNIPER_STELLUNG_ANSAGE and not bool(s["leuchtet"]):
			if not sicht:
				s["in"] = Werte.BOSS_SNIPER_STELLUNG_ANSAGE + 0.3   # erst, wenn er Brakk sieht
				continue
			s["leuchtet"] = true
			s["leucht_t"] = 0.0
			bg.aufblitzen(u.position, ROT)
		if bool(s["leuchtet"]):
			s["leucht_t"] = float(s["leucht_t"]) + dt
			var rot := 0.55 + 0.45 * sin(float(s["in"]) * 26.0)
			u._sprite.modulate = Color(1.0, 1.0 - 0.75 * rot, 1.0 - 0.75 * rot)
		if float(s["in"]) <= 0.0:
			s["leuchtet"] = false
			s["in"] = Werte.BOSS_SNIPER_STELLUNG_TAKT
			u._sprite.modulate = Color.WHITE
			if sicht:
				bg.schiesse("hf_salve", u.position, 1.0 + (spiel.hd.H if spiel.hd != null else 1.0), h.schaden() * Werte.BOSS_SNIPER_STELLUNG_ANTEIL, "herausforderer", h.quelle(), 1.0, k.position)
				Ton.am_ort(spiel, "tc-blaster", u.position)
				_protokoll("stellung_schuss", {"angesagt": float(s.get("leucht_t", 0.0))})


func ende() -> void:
	for s: Dictionary in schuetzen:
		if Nemesis.lebt(s["e"]):
			h.nem._wegbeamen(s["e"] as Einheit, true)
	schuetzen.clear()
