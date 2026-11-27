class_name NemesisBossScharf
extends NemesisBoss
## C2 (26.11., Paul): Befehl 24 – der Scharfschütze als Herausforderer. Distanz und Wälle.
##  - Bewegung: größerer Abstand (Lieblingsabstand × 1,3, mindestens 8 Felder), wechselt oft die Wallkrone und zieht sich
##    mit Brakks Anker hinauf (0,5 s steht das Seil, dann der Zug).
##  - Phase 1: Salve in vier Wellen (H-2: je drei Schüsse exakt entlang angekündigter Linien, die mittlere vorausberechnet), Sturm wie bisher,
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
var _salve_nr := 0                # H-2: Nummer der Salve …
var _wellen := {}                # … je Salve: {Welle: Linien} (salve_linien)


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


## H-3 (27.11., Paul): Sturm öfter und doppelt – der Stil bleibt Distanz.
## P1: Salve · Sturm · Sturm · Laser · Salve · Reihenwelle · Salve · [Sturm | Laser].
## P2: einmal die Zielmarkierung, dann Salve · Sturm · Sturm · Laser · Reihenwelle · Salve · Laser · [Sturm | Salve].
## Doppelsturm: zwischen den Stürmen BOSS_SNIPER_DOPPEL_FENSTER (er dreht und setzt nach, kein Rückzug); danach läuft er
## sofort auf Abstand, das Laservisier beginnt erst ab BOSS_SNIPER_LASER_MIN Feldern (bereit()). H-4: Druck = Sturm → Sturm
## → Laser (Fenster BOSS_DRUCK_FENSTER, keine Bewegung, danach die Belohnung).
func abfolge(phase2: bool) -> Array:
	var f := Werte.BOSS_SNIPER_FENSTER * (Werte.BOSS_ABFOLGE_P2_FENSTER if phase2 else 1.0)
	var b := Werte.BOSS_SNIPER_BEWEGUNG
	var doppel := s("sturm", Werte.BOSS_SNIPER_DOPPEL_FENSTER, 0.0, {"druck": true})
	var sturm2 := s("sturm", f, b, {"druck": true})
	var laser_d := s("laser", f, b, {"druck": true})
	if not phase2:
		return [s("salve", f, b), doppel, sturm2, laser_d, s("salve", f, b), s("reihe", f, b), s("salve", f, b), s(["sturm", "laser"], f, b)]
	return [s("salve", f, b), doppel, sturm2, laser_d, s("reihe", f, b), s("salve", f, b), s("laser", f, b), s(["sturm", "salve"], f, b)]


## H-3: Nach einem Sturm erst wieder auf Abstand: das Laservisier ab BOSS_SNIPER_LASER_MIN Feldern, alles andere (außer dem
## zweiten Sturm) ab BOSS_SNIPER_ABSTAND_MIN – höchstens BOSS_SNIPER_RUECKZUG_MAX s lang wartet der Schritt darauf.
func bereit(art: String, abstand: float, wartet: float) -> bool:
	if h._letzte.is_empty() or str(h._letzte.back()) != "sturm" or art == "sturm" or wartet >= Werte.BOSS_SNIPER_RUECKZUG_MAX:
		return true
	return abstand >= (Werte.BOSS_SNIPER_LASER_MIN if art == "laser" else Werte.BOSS_SNIPER_ABSTAND_MIN)


## H-4: In der Druckphase hält er seinen Abstand (sonst Lieblingsabstand × BOSS_DRUCK_ABSTAND_MAL) – der Stil bleibt Distanz.
func druck_abstand_mal() -> float:
	return 1.0


## H-1 (27.11., Paul): kein Bodenfeuer mehr in der Druckphase – die Reihenwelle ist ein eigener Schritt der Abfolge.
func anker_zwang() -> bool:
	return false


func eroeffnung(phase2: bool) -> Array:
	return [s("zielmarkierung", Werte.BOSS_SNIPER_FENSTER * Werte.BOSS_ABFOLGE_P2_FENSTER, Werte.BOSS_SNIPER_BEWEGUNG)] if phase2 else []


func kann(art: String, _abstand: float) -> bool:
	if art == "reihe":
		return h.kampfplatz.aktiv() and h.reihe == null   # H-1: nur im Kampfplatz, nie zwei Wellen
	return art != "zielmarkierung" or not marke_gesetzt


## Ringe für Salve (Durchschlag, Wirbel) wirken auf seine Salve in Wellen; eine Kugel hat er nicht.
func ring_angriff(art: String) -> String:
	return art if art == "salve" else ""


func beginne(art: String) -> bool:
	var a := h.angriff
	match art:
		"salve":
			# H-2 (27.11., Paul): drei dünne rote Linien am Boden = die Flugbahnen der ersten Welle (mittlere durch Brakks
			# vorausberechnete Position, äußere ±14° um seine aktuelle) – kein Kegel, kein Drehen.
			a["um"] = Werte.BOSS_SNIPER_SALVE_ANSAGE
			h.einheit._sprite.angriff(Werte.BOSS_SNIPER_SALVE_ANSAGE + Werte.BOSS_SNIPER_SALVE_TAKT * Werte.BOSS_SNIPER_SALVE_WELLEN)
			_salve_nr += 1
			_wellen[_salve_nr] = {0: _linien(Werte.BOSS_SNIPER_SALVE_ANSAGE)}
			bg.aufblitzen(h._muendung(a["richtung"] as Vector2), ROT)
			Ton.am_ort(spiel, "tc-arc", h.einheit.position)
			return true
		"laser":
			a["teil"] = "typ"
			a["phase"] = "anlauf"
			return true
		"reihe":
			# H-1 (27.11., Paul): Ansage – er rammt den Gewehrkolben in den Boden (Ton, HUD „Boden bricht – hoch oder drüber!“)
			a["um"] = Werte.BOSS_REIHE_ANSAGE
			h.einheit._sprite.angriff(Werte.BOSS_REIHE_ANSAGE)
			Ton.am_ort(spiel, "tc-arc", h.einheit.position)
			_protokoll("reihe_ansage")
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
			# H-2: jede weitere Welle kündigt ihre eigenen Linien BOSS_SNIPER_SALVE_LINIEN_VOR s vorher an (neu berechnet)
			var nr := _salve_nr
			_welle_feuern(nr, 0)
			for i in range(1, Werte.BOSS_SNIPER_SALVE_WELLEN):
				var bei := Werte.BOSS_SNIPER_SALVE_TAKT * i
				bg.spaeter(_bg(maxf(0.0, bei - Werte.BOSS_SNIPER_SALVE_LINIEN_VOR)), _welle_ansagen.bind(nr, i))
				bg.spaeter(_bg(bei), _welle_feuern.bind(nr, i))
			return true
		"reihe":
			spiel.effekte.flaeche(h.einheit.position, Werte.ZELLE * 0.8, NemesisReihenwelle.STAUB)   # H-1: der Kolben schlägt auf
			Ton.am_ort(spiel, "hit-boom", h.einheit.position)
			h.reihenwelle_an(h.einheit.position)
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


## H-2: Die Linien einer Welle (vom Scharfschützen aus, `vor` s vor dem Schuss) – sie zeigt die Flugbahnen.
func _linien(vor: float) -> Dictionary:
	return h.salve_linien(h.einheit, vor, Werte.BOSS_SNIPER_SALVE_WINKEL, Werte.BOSS_SNIPER_SALVE_VORHALT_MAX, _salve_tempo(), ROT)


## H-2: Felder je echter Sekunde der Salve (8 Felder in BOSS_SNIPER_SALVE_FLUG s).
func _salve_tempo() -> float:
	return 8.0 / maxf(0.05, Werte.BOSS_SNIPER_SALVE_FLUG)


func _welle_ansagen(nr: int, welle: int) -> void:
	if h.einheit == null or not is_instance_valid(h.einheit) or h.einheit.kampfunfaehig or not _wellen.has(nr):
		return
	(_wellen[nr] as Dictionary)[welle] = _linien(minf(Werte.BOSS_SNIPER_SALVE_LINIEN_VOR, Werte.BOSS_SNIPER_SALVE_TAKT * welle))


## Eine Welle zu drei Schüssen exakt entlang ihrer Linien; trifft höchstens einmal. Ohne Sicht fällt sie aus (H-5).
func _welle_feuern(nr: int, welle: int) -> void:
	if h.einheit == null or not is_instance_valid(h.einheit) or h.einheit.kampfunfaehig or not _wellen.has(nr):
		return
	var l: Dictionary = (_wellen[nr] as Dictionary).get(welle, {})
	if welle == Werte.BOSS_SNIPER_SALVE_WELLEN - 1:
		_wellen.erase(nr)
	if l.is_empty():
		return
	if not h.sieht(h.einheit.position, _brakk().position):
		_protokoll("welle_ohne_sicht", {"welle": welle})
		return
	h.salve_feuern(l, h.schaden() * Werte.BOSS_SNIPER_SALVE_ANTEIL, _salve_tempo())
	Ton.am_ort(spiel, "tc-blaster", h.einheit.position)
	_protokoll("faecher", {"welle": welle, "dirs": l["dirs"]})


## Laservisier: in Reichweite laufen, zielen (rote Linie, HUD), dann der Strahl.
func weiter_angriff(dt: float, k: Kommandant) -> void:
	var a := h.angriff
	var t := float(a["t"])
	var e := h.einheit
	var d := e.position.distance_to(k.position) / Werte.ZELLE
	var sicht := h.sieht(e.position, k.position)   # F5: von der Krone über das eigene Wallstück
	match str(a.get("phase", "anlauf")):
		"anlauf":
			var passt := d <= Werte.BOSS_SNIPER_LASER_WEITE - 0.5 and d >= Werte.BOSS_SNIPER_LASER_MIN and sicht   # H-3: nicht aus der Nähe
			var anlauf_max := Werte.BOSS_SAEULE_SEK if bool(a.get("kombo", false)) else Werte.BOSS_SNIPER_LASER_ANLAUF   # H-7: Kombo – die Standzeit der Säule
			if passt or t >= anlauf_max:
				if d > Werte.BOSS_SNIPER_LASER_WEITE or d < Werte.BOSS_SNIPER_LASER_MIN or not sicht:
					a["angesagt"] = 0.5
					h.boden_freigeben("boss")
					h.fenster()   # nicht hingekommen: kein Strahl
					return
				a["phase"] = "ziel"
				a["t"] = 0.0
				Ton.am_ort(spiel, "tc-rail", e.position)   # H-6: Aufladeton
				_protokoll("laser_ziel")
			else:
				h._laufe(dt, k, Werte.BOSS_SNIPER_LASER_WEITE - 2.0, h.tempo())   # zu weit: heran; zu nah: weg (Lauf auf den Abstand)
		"ziel":
			# H-6 (27.11., Paul): dicke rote Linie Mündung → Brakks Oberkörper, von blass zu satt; HUD „ANVISIERT“ mit
			# Balken, roter Bildrand. Wall oder außer Reichweite: sofort aus, „Ziel verloren“.
			if d > Werte.BOSS_SNIPER_LASER_WEITE or not sicht:
				e._sprite.modulate = Color.WHITE
				_ziel_verloren(t, "ziel")
				return
			e._sprite.bewegt(false)
			h.anvisiert = e.position
			var anteil := clampf(t / Werte.BOSS_SNIPER_LASER_ZIELEN, 0.0, 1.0)
			h.anvisiert_balken = anteil
			var rot := 0.55 + 0.45 * sin(t * 26.0)
			e._sprite.modulate = Color(1.0, 1.0 - 0.75 * rot, 1.0 - 0.75 * rot)
			bg._balken(bg._zu3d(h._muendung((k.position - e.position).normalized()), h._hoehe_er()), bg._zu3d(k.position, h.ziel_h()),
				Color(1.0, 0.8, 0.8).lerp(ROT, anteil), lerpf(0.07, 0.14, anteil), _bg(dt * 1.5))   # Paul (27.11.): dicker und erkennbarer
			if int(t * 8.0) != int((t - dt) * 8.0):
				bg.aufblitzen(h._muendung((k.position - e.position).normalized()), ROT)   # das Visier blinkt an der Mündung
			if t >= Werte.BOSS_SNIPER_LASER_ZIELEN:
				e._sprite.modulate = Color.WHITE
				a["phase"] = "strahl"
				a["t"] = 0.0
				a["angesagt"] = Werte.BOSS_SNIPER_LASER_ZIELEN
		"strahl":
			if d > Werte.BOSS_SNIPER_LASER_WEITE or not sicht or t >= Werte.BOSS_SNIPER_LASER_SEK:
				_protokoll("laser_ende", {"dauer": t, "schaden": laser_schaden})
				if t < Werte.BOSS_SNIPER_LASER_SEK:
					_ziel_verloren(t, "strahl")
				else:
					h.boden_freigeben("boss")
					h.fenster()   # vorbei
				return
			h.anvisiert = e.position
			h.anvisiert_balken = 1.0 - clampf(t / Werte.BOSS_SNIPER_LASER_SEK, 0.0, 1.0)   # H-6: Restdauer
			h.anvisiert_text = tr("STRAHL")
			var ende := k.position
			var von3 := bg._zu3d(h._muendung((ende - e.position).normalized()), h._hoehe_er())
			bg._balken(von3, bg._zu3d(ende, h.ziel_h()), ROT, 0.2, _bg(dt * 1.5))   # Paul (27.11.): breiter Strahl …
			bg._balken(von3, bg._zu3d(ende, h.ziel_h()), Color(1.0, 0.85, 0.85), 0.07, _bg(dt * 1.5))   # … mit hellem Kern
			if k.unverwundbar <= 0.0:
				_treffe(Werte.BOSS_SNIPER_LASER_JE_SEK * dt, e.position, false)
				laser_schaden += Werte.BOSS_SNIPER_LASER_JE_SEK * dt


## H-7 (27.11., Paul): Kombo – die Säule steht, das Laservisier folgt direkt (Brakk muss aus dem Kreis und aus der Linie);
## steht Brakk weiter als 10 Felder, läuft er während ihrer Standzeit in Reichweite (ab 4 Feldern).
func nach_saeule(_k: Kommandant) -> bool:
	h.angriff = {}
	h.beginne_angriff("laser")
	h.angriff["kombo"] = true
	h.boden_freigeben("boss")
	h.boden_belegen("kombo", Werte.BOSS_SAEULE_SEK)   # der Reichweitenring gehört zur Säule (gewollte Kombo)
	_protokoll("kombo")
	return true


## H-6: Brakk ist aus der Reichweite oder hinter einem Wall – das Visier geht sofort aus.
func _ziel_verloren(t: float, phase: String) -> void:
	_protokoll("ziel_verloren", {"phase": phase, "nach": t})
	spiel.melde(tr("Ziel verloren"), 1.2)
	h.boden_freigeben("boss")
	h.fenster()


## H-6: Bodeneffekte – die Salve-Linien, beim Laservisier der Reichweitenring (nie zugleich mit einer Reihenwelle oder Säule).
func boden_sek(art: String) -> float:
	match art:
		"salve":
			return Werte.BOSS_SNIPER_SALVE_ANSAGE + Werte.BOSS_SNIPER_SALVE_TAKT * Werte.BOSS_SNIPER_SALVE_WELLEN
		"reihe":
			return Werte.BOSS_REIHE_ANSAGE   # die Welle selbst belegt den Boden als „reihe“
		"laser":
			return Werte.BOSS_SNIPER_LASER_ANLAUF + Werte.BOSS_SNIPER_LASER_ZIELEN + Werte.BOSS_SNIPER_LASER_SEK   # am Ende freigegeben
	return super(art)


## H-6: Reichweitenring 10 Felder um ihn, sobald das Laservisier der nächste Schritt ist (oder läuft): dünn gestrichelt,
## breit und pulsierend, wenn Brakk drin ist.
func _reichweite_pflegen(k: Kommandant) -> void:
	var laeuft := str(h.angriff.get("art", "")) == "laser" and str(h.angriff.get("teil", "")) != "fenster"
	var drin := h.einheit.position.distance_to(k.position) <= Werte.BOSS_SNIPER_LASER_WEITE * Werte.ZELLE
	reichweite_ring(h.zustand == "duell" and (laeuft or h.naechste_arten().has("laser")), Werte.BOSS_SNIPER_LASER_WEITE, drin, false)


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
	# H-9 (27.11., Paul): gestaffelt – je Stellung BOSS_SNIPER_STELLUNG_VERSATZ s später, dann alle BOSS_SNIPER_STELLUNG_TAKT s
	schuetzen.append({"e": e, "z": z, "in": 1.0 + Werte.BOSS_SNIPER_STELLUNG_VERSATZ * schuetzen.size(), "leuchtet": false})
	_protokoll("stellung", {"z": z})


## Die Schützen der Zielmarkierung: Aufleuchten, dann ein sichtbarer Schuss auf Brakk. Gefallene kommen nicht wieder.
func immer(dt: float, k: Kommandant) -> void:
	_reichweite_pflegen(k)   # H-6
	for s: Dictionary in schuetzen:
		var e: Variant = s["e"]
		if not Nemesis.lebt(e) or (e as Einheit).kampfunfaehig:
			continue
		var u := e as Einheit
		u.halt = true
		if str(h.angriff.get("art", "")) == "sturm" and str(h.angriff.get("teil", "")) != "fenster" and not bool(s["leuchtet"]):
			continue   # H-9: nicht, solange der Boss stürmt
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
				if not bg.geschosse.is_empty():
					(bg.geschosse.back() as Dictionary)["zaehl"] = "stellung"   # H-11
				Ton.am_ort(spiel, "tc-blaster", u.position)
				_protokoll("stellung_schuss", {"angesagt": float(s.get("leucht_t", 0.0))})


func ende() -> void:
	reichweite_weg()
	for s: Dictionary in schuetzen:
		if Nemesis.lebt(s["e"]):
			h.nem._wegbeamen(s["e"] as Einheit, true)
	schuetzen.clear()
