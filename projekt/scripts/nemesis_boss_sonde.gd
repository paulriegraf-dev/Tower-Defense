class_name NemesisBossSonde
extends NemesisBoss
## C3 (26.11., Paul): Befehl 24 – Sonde 7 tritt zu Minute 14 selbst an (35 %). Kein Benannter: eigener Datensatz
## („Sonde 7“, Titel „Kommandantin“), sie wird geborgen statt ausgeschaltet. Figur bis zu den Generierungen am 30.11.:
## ihr Porträt als schwebendes Bild (Platzhalter).
##  - Bewegung: schnell (Tempo × 1,25), schwebt mit Akku – 6 s in der Luft, dann 2 s am Boden (ihr Fenster); stößt sich von
##    Wallkronen ab, Seitwärts-Schub und Sprung.
##  - Phase 1: MG-Markierung (0,8 s „ANVISIERT“, dann 3–4 träge Lenkgeschosse; der nächste Angriff darf folgen),
##    Schubeinschlag (rote Fläche 1,2 s, dann Einflug mit Rückstoß), Sturzfeuer (sie steigt, Schatten und Kegel auf Brakk,
##    vier Schüsse – zusammen ein Treffer –, der letzte trägt sie zurück auf eine Krone). Schrotstoß als Reaktion, wenn
##    Brakk näher als 2 Felder kommt (0,5 s Pumpen, Rückstoß, dann gleich das Sturzfeuer).
##  - Phase 2: Heil-Impuls (einmal, 2 s Kanal, bricht bei 8 % Schaden), Scheuchfeld (10 s Sprengungen auf Brakks Weg),
##    Sturzfeuer mit sechs Schüssen und wanderndem Kegel, Verstärkungsruf als letzter der Reihe (einmal: 3–4 Eliten; solange
##    sie stehen, schwebt sie, schießt nicht und weicht nicht aus).

const BILD := "res://assets/sprites/tutorial/sonde7.png"
const ROT := Color("ff3b3b")
const CYAN := Color("6ee6ff")
const GRUEN := Color("7dff6a")

var bild: Sprite2D = null
var _akku := 0.0                 # läuft in der Luft hoch, am Boden zurück
var am_boden := false
var _boden_rest := 0.0
var _hoehe := 0.0                # gerade (zum Steigen und Sinken)
var phase2 := false
var _p2_angriffe := 0
var heil_genutzt := false
var heil_gebrochen := false
var _heil_schaden := 0.0
var ruf_genutzt := false
var eliten: Array = []
var _schrot_in := 0.0
var _danach_sturz := false
var _stoss := {}                 # Rückstoß auf Brakk: {"r", "rest", "tempo"}
var _scheuch := {}               # {"rest", "in", "marke": Vector2 | INF, "marke_t"}
var akku_protokoll: Array = []   # Prüfung: je [Zeit des Wechsels in Sekunden des Duells, "luft" | "boden"]
var _uhr := 0.0
var lenk: Array = []             # Prüfung: die eigenen Lenkgeschosse


func tempo_mal() -> float:
	return Werte.BOSS_SONDE_TEMPO_MAL


func takt(_grund: float) -> float:
	return Werte.HERAUSFORDERER_AKTION_TAKT.x * 1.4


func sprung_anteil(_grund: float) -> float:
	return 0.5


func wall_abkling() -> float:
	return Werte.BOSS_SONDE_KRONE_SEK


func einrichten_figur(e: Einheit) -> void:
	e._sprite.visible = false
	var schild := e.get_node_or_null("Frontschild") as CanvasItem
	if schild != null:
		schild.visible = false
	bild = Sprite2D.new()
	bild.texture = load(BILD)
	bild.scale = Vector2.ONE * 0.95
	e.add_child(bild)


func schwebe() -> float:
	return _hoehe + (0.08 * sin(_uhr * 3.0) if _hoehe > 0.3 else 0.0)


func steht() -> bool:
	return am_boden and not h.greift_an()


func feuer_frei() -> bool:
	return str(h.angriff.get("art", "")) == "ruf" and str(h.angriff.get("teil", "")) == "typ"


## Geborgen statt gefallen: Bei null Leben bleibt sie mit einem Rest liegen (kampfunfähig), der Herausforderer beendet
## das Duell. Im Heil-Impuls zählt der Schaden.
func vor_treffer(menge: float) -> float:
	var e := h.einheit
	if str(h.angriff.get("art", "")) == "heil" and str(h.angriff.get("teil", "")) == "typ":
		_heil_schaden += menge
	if menge >= e.leben:
		e.kampfunfaehig = true
		return maxf(0.0, e.leben - 1.0)
	return menge


func gewichte(abstand_felder: float, _letzte: Array) -> Dictionary:
	if _danach_sturz:
		return {"sturz": 1.0}
	if phase2 and not ruf_genutzt and _p2_angriffe >= Werte.BOSS_SONDE_RUF_NACH:
		return {"ruf": 1.0}   # immer der letzte der Reihe
	var g := {"mg": 1.2, "schub": 1.0 if abstand_felder >= 3.0 else 0.5, "sturz": 1.2}
	if phase2:
		if _scheuch.is_empty():
			g["scheuch"] = 0.9
		if not heil_genutzt:
			g["heil"] = 1.4
	return g


func ring_angriff(_art: String) -> String:
	return ""


func fenster_mal(art: String) -> float:
	if art == "schrot":
		return 0.1   # danach direkt das Sturzfeuer
	return Werte.BOSS_SONDE_MG_FENSTER if art == "mg" else 1.0


# ------------------------------------------------------------------ Angriffe

func beginne(art: String) -> bool:
	var a := h.angriff
	var e := h.einheit
	var k := _brakk()
	if phase2 and art != "ruf":
		_p2_angriffe += 1
	match art:
		"mg":
			a["um"] = Werte.BOSS_SONDE_MG_ANSAGE
			Ton.am_ort(spiel, "tc-arc", e.position)
			return true
		"schub":
			a["um"] = Werte.BOSS_SONDE_SCHUB_ANSAGE
			a["ziel"] = k.position
			_flaeche(k.position, Werte.BOSS_SONDE_SCHUB_FLAECHE * 0.5, Werte.BOSS_SONDE_SCHUB_ANSAGE)
			Ton.am_ort(spiel, "tc-arc", e.position)
			return true
		"sturz":
			_danach_sturz = false
			a["teil"] = "typ"
			a["phase"] = "steigen"
			var mitte := k.position
			a["mitte"] = mitte
			a["lauf"] = bg._brakk_v.normalized() if bg._brakk_v.length() > 5.0 else Vector2.ZERO
			var dauer := Werte.BOSS_SONDE_STURZ_STEIGEN + Werte.BOSS_SONDE_STURZ_TAKT * _sturz_schuesse()
			_ring(mitte, 0.5, Color(0, 0, 0, 0.8), dauer)   # ihr Schatten
			_flaeche(mitte, Werte.BOSS_SONDE_STURZ_KEGEL * 0.5, dauer)
			_protokoll("sturz", {"mitte": mitte, "brakk": k.position, "schuesse": _sturz_schuesse()})
			return true
		"schrot":
			a["um"] = Werte.BOSS_SONDE_SCHROT_PUMPE
			Ton.am_ort(spiel, "tc-heavy", e.position)   # das Pumpen
			Ton.am_ort(spiel, "ui-klick", e.position)
			_flaeche(e.position, Werte.BOSS_SONDE_SCHROT_NAH + 1.0, Werte.BOSS_SONDE_SCHROT_PUMPE)
			return true
		"heil":
			heil_genutzt = true
			_heil_schaden = 0.0
			heil_gebrochen = false
			a["teil"] = "typ"
			a["phase"] = "heil"
			a["angesagt"] = Werte.BOSS_SONDE_HEIL_SEK
			_ring(e.position, 1.2, GRUEN, Werte.BOSS_SONDE_HEIL_SEK)
			_protokoll("heil_start")
			return true
		"scheuch":
			a["um"] = 0.6
			Ton.am_ort(spiel, "alert", e.position)
			return true
		"ruf":
			a["um"] = Werte.BOSS_SONDE_RUF_ANSAGE
			spiel.melde(tr("Sonde 7: „Alle Einheiten – zu mir!“"), 3.0)
			Ton.spiele(spiel, "alert", 0.0)
			return true
	return false


func feuer(art: String, k: Kommandant) -> bool:
	var a := h.angriff
	var e := h.einheit
	match art:
		"mg":
			var n := randi_range(Werte.BOSS_SONDE_MG_ZAHL.x, Werte.BOSS_SONDE_MG_ZAHL.y)
			var r := (k.position - e.position).normalized()
			for i in n:
				var w := deg_to_rad(lerpf(-50.0, 50.0, float(i) / maxf(1.0, float(n - 1))))   # fächern auf, dann drehen sie ein
				var g := bg.lenk(e.position + r.rotated(w) * 0.4 * Werte.ZELLE, r.rotated(w), h.schaden() * Werte.BOSS_SONDE_MG_ANTEIL, h.quelle(),
					Werte.BOSS_SONDE_MG_TEMPO, Werte.BOSS_SONDE_MG_DREH, _bg(Werte.BOSS_SONDE_MG_SEK))
				lenk.append(g)
			Ton.am_ort(spiel, "tc-blaster", e.position)
			_protokoll("mg", {"zahl": n})
			return true
		"schub":
			a["teil"] = "typ"
			a["phase"] = "einflug"
			a["t"] = 0.0
			a["von"] = e.position
			return true
		"schrot":
			if e.position.distance_to(k.position) <= (Werte.BOSS_SONDE_SCHROT_NAH + 1.0) * Werte.ZELLE and k.unverwundbar <= 0.0:
				_treffe(Werte.BOSS_SONDE_SCHROT_ANTEIL, e.position)
				_stossen(e.position, Werte.BOSS_SONDE_STOSS)
			var weg := (e.position - k.position).normalized()
			var nach := e.position + weg * Werte.BOSS_SONDE_SCHROT_ZURUECK * Werte.ZELLE
			if not h._begehbar(o24.karte.zelle_bei(nach)):
				nach = e.position
			h._aktion = {"art": "lauf", "t": 0.0, "sek": 0.2, "von": e.position, "nach": nach}
			Ton.am_ort(spiel, "hit-boom", e.position)
			_danach_sturz = true
			h._bis_angriff = 0.0
			_protokoll("schrot")
			return true
		"scheuch":
			_scheuch = {"rest": Werte.BOSS_SONDE_SCHEUCH_SEK, "in": 0.0, "marke": Vector2.INF, "marke_t": 0.0}
			_protokoll("scheuch")
			return true
		"ruf":
			ruf_genutzt = true
			a["teil"] = "typ"
			a["phase"] = "ruf"
			a["t"] = 0.0
			_eliten_rufen()
			return true
	return false


func _sturz_schuesse() -> int:
	return Werte.BOSS_SONDE_STURZ_SCHUESSE_WUT if phase2 else Werte.BOSS_SONDE_STURZ_SCHUESSE


func weiter_angriff(dt: float, k: Kommandant) -> void:
	var a := h.angriff
	var t := float(a["t"])
	var e := h.einheit
	match str(a.get("phase", "")):
		"steigen":   # Sturzfeuer: sie steigt, der Kegel liegt auf Brakk
			_hoehe = move_toward(_hoehe, Werte.BOSS_SONDE_STURZ_HOEHE, dt * Werte.BOSS_SONDE_STURZ_HOEHE / Werte.BOSS_SONDE_STURZ_STEIGEN)
			_kegel_bild(a["mitte"] as Vector2, dt)
			if t >= Werte.BOSS_SONDE_STURZ_STEIGEN:
				a["phase"] = "sturz"
				a["t"] = 0.0
				a["schuss"] = 0
				a["angesagt"] = Werte.BOSS_SONDE_STURZ_STEIGEN
				h._salven += 1
				a["gruppe"] = h._salven
		"sturz":
			var n := _sturz_schuesse()
			var nr := int(a["schuss"])
			if t >= Werte.BOSS_SONDE_STURZ_TAKT * nr and nr < n:
				var mitte: Vector2 = a["mitte"]
				if phase2:   # der Kegel wandert in Brakks Laufrichtung
					mitte = mitte + (a["lauf"] as Vector2) * Werte.BOSS_SONDE_STURZ_WANDERN * Werte.ZELLE * float(nr) / float(maxi(1, n - 1))
				a["schuss"] = nr + 1
				_sturz_schuss(mitte, k, nr == n - 1)
			_kegel_bild(a["mitte"] as Vector2, dt)
			if int(a["schuss"]) >= n:
				h.fenster()
		"einflug":   # Schubeinschlag
			var f := clampf(t / Werte.BOSS_SONDE_SCHUB_FLUG, 0.0, 1.0)
			var ziel: Vector2 = a["ziel"]
			e.position = (a["von"] as Vector2).lerp(ziel, f)
			if f >= 1.0:
				if not h._begehbar(o24.karte.zelle_bei(ziel)):
					e.position = o24.karte.mitte(h.kampfplatz._frei_innen(o24.karte.zelle_bei(ziel))) if h.kampfplatz.aktiv() else a["von"]
				spiel.effekte.flaeche(ziel, Werte.BOSS_SONDE_SCHUB_FLAECHE * 0.5 * Werte.ZELLE, Color(0.75, 0.68, 0.55))
				Ton.am_ort(spiel, "hit-boom", ziel)
				if k.unverwundbar <= 0.0 and _brakk_sprung() <= Werte.BRAKK_SPRUNG_BODEN and k.position.distance_to(ziel) <= (Werte.BOSS_SONDE_SCHUB_FLAECHE * 0.5 + Werte.BRAKK_RUMPF) * Werte.ZELLE:
					_treffe(Werte.BOSS_SONDE_SCHUB_ANTEIL, ziel)
					_stossen(ziel, Werte.BOSS_SONDE_STOSS)
				_protokoll("schub")
				h.fenster()
		"heil":
			e._sprite.bewegt(false)
			if _heil_schaden >= Werte.BOSS_SONDE_HEIL_BRUCH * e.max_leben:
				heil_gebrochen = true
				_protokoll("heil_gebrochen", {"schaden": _heil_schaden})
				spiel.melde(tr("Heil-Impuls gebrochen!"), 2.0)
				h.fenster()
			elif t >= Werte.BOSS_SONDE_HEIL_SEK:
				e.leben = minf(e.max_leben, e.leben + Werte.BOSS_SONDE_HEIL_ANTEIL * e.max_leben)
				spiel.effekte.flaeche(e.position, Werte.ZELLE * 1.2, GRUEN)
				_protokoll("heil", {"leben": e.leben})
				h.fenster()
		"ruf":   # sie schwebt, schießt nicht, weicht nicht aus
			_hoehe = move_toward(_hoehe, Werte.BOSS_SONDE_SCHWEBE, dt * 2.0)
			eliten = eliten.filter(func(x: Variant) -> bool: return Nemesis.lebt(x))
			if eliten.is_empty() or t >= Werte.BOSS_SONDE_RUF_MAX:
				_protokoll("ruf_ende", {"dauer": t, "eliten": eliten.size()})
				_p2_angriffe = 0
				_akku = 0.0
				h.fenster()


## Ein Schuss des Sturzfeuers senkrecht in den Kegel: Schrotkörner als Fächer, zusammen höchstens ein Treffer.
func _sturz_schuss(mitte: Vector2, k: Kommandant, letzter: bool) -> void:
	var e := h.einheit
	var r := Werte.BOSS_SONDE_STURZ_KEGEL * 0.5 * Werte.ZELLE
	var oben := bg._zu3d(e.position, _hoehe + 0.6)
	for i in 5:
		var p := mitte + Vector2.RIGHT.rotated(randf() * TAU) * randf() * r
		bg._balken(oben, bg._zu3d(p, 0.05), Color("ffd27a"), 0.03, _bg(0.08))
	Ton.am_ort(spiel, "tc-heavy", mitte)
	var a := h.angriff
	var drin := k.position.distance_to(mitte) <= r + Werte.BRAKK_RUMPF * Werte.ZELLE
	var wall := not o24.karte.sicht_frei(e.position, k.position)
	if drin and not wall and k.unverwundbar <= 0.0:
		a["treffer_anteil"] = float(a.get("treffer_anteil", 0.0)) + 1.0 / float(_sturz_schuesse())
		_treffe(1.0 / float(_sturz_schuesse()), e.position, true)
	if letzter:   # der Rückstoß trägt sie zurück, auf die nächste Krone
		var weg := (e.position - mitte).normalized() if e.position.distance_to(mitte) > 1.0 else Vector2.RIGHT
		var nach := e.position + weg * Werte.BOSS_SONDE_STURZ_RUECK * Werte.ZELLE
		var krone := _krone_bei(nach)
		if krone != Karte.KEINE:
			nach = o24.karte.mitte(krone)
			h._wall_rest = randf_range(Werte.HERAUSFORDERER_WALL_SEK.x, Werte.HERAUSFORDERER_WALL_SEK.y)
			e.zustand = Einheit.Zustand.AUF_POSTEN
		elif not h._begehbar(o24.karte.zelle_bei(nach)):
			nach = o24.karte.mitte(h.kampfplatz._frei_innen(o24.karte.zelle_bei(nach))) if h.kampfplatz.aktiv() else e.position
		h._aktion = {"art": "sprung", "t": 0.0, "sek": 0.45, "von": e.position, "nach": nach, "hoch": 0.5}
		_protokoll("sturz_rueck", {"krone": krone != Karte.KEINE})


## Eine Wallkrone innen nahe `p` (2 Felder), keine Stellung.
func _krone_bei(p: Vector2) -> Vector2i:
	var karte: Karte = o24.karte
	var c := karte.zelle_bei(p)
	var beste := Karte.KEINE
	var weit := INF
	for dy in range(-2, 3):
		for dx in range(-2, 3):
			var z := c + Vector2i(dx, dy)
			if karte.inhalt(z) == Karte.WALL and not karte.ausbau.has(z) and (not h.kampfplatz.zu() or h.kampfplatz.innen(z)) and Vector2(dx, dy).length() < weit:
				weit = Vector2(dx, dy).length()
				beste = z
	return beste


func _kegel_bild(mitte: Vector2, _dt: float) -> void:
	if int(_uhr * 8.0) != int((_uhr - 0.016) * 8.0):
		var oben := bg._zu3d(h.einheit.position, _hoehe + 0.6)
		var r := Werte.BOSS_SONDE_STURZ_KEGEL * 0.5
		for i in 6:
			bg._balken(oben, bg._zu3d(mitte + Vector2.RIGHT.rotated(TAU * i / 6.0) * r * Werte.ZELLE, 0.05), ROT, 0.02, _bg(0.14))


## Rote Fläche am Boden (Radius in Feldern) mit Ring, so lange `sek`.
func _flaeche(p: Vector2, radius: float, sek: float) -> void:
	_ring(p, radius, ROT, sek)
	h._treffbereich(p, radius, sek)
	spiel.effekte.warnung(p, _bg(sek) * Werte.BRAKK_TEMPO)


## Brakk fliegt `weit` Felder von `von` weg (über die Ego-Sicht, Mauern und Lichtwand halten ihn).
func _stossen(von: Vector2, weit: float) -> void:
	var k := _brakk()
	var r := (k.position - von).normalized() if k.position.distance_to(von) > 1.0 else Vector2.RIGHT
	_stoss = {"r": r, "rest": Werte.BOSS_SONDE_STOSS_SEK, "tempo": weit / Werte.BOSS_SONDE_STOSS_SEK}
	_protokoll("stoss")


func _eliten_rufen() -> void:
	var kp := h.kampfplatz
	var k := _brakk()
	var n := randi_range(Werte.BOSS_SONDE_RUF_ZAHL.x, Werte.BOSS_SONDE_RUF_ZAHL.y)
	var arten := ["technogunner", "scharfschuetze", "plasmawerfer"]
	for i in n:
		var ziel := kp.mitte + Vector2i(randi_range(-6, 5), randi_range(-4, 3))
		var z := kp._frei_innen(ziel) if kp.aktiv() else o24.karte.zelle_bei(h.einheit.position)
		if o24.karte.mitte(z).distance_to(k.position) < 4.0 * Werte.ZELLE:
			z = kp._frei_innen(kp.mitte + Vector2i(-6 if k.position.x > o24.karte.mitte(kp.mitte).x else 5, -1 + i)) if kp.aktiv() else z
		var art: String = arten[i % arten.size()]
		var e := o24._neue_truppe(art, h._fabrik_fuer(art), 4)
		e.set_meta("kampfplatz_erlaubt", true)
		e.position = o24.karte.mitte(z)
		e._punkte.clear()
		spiel.effekte.flaeche(e.position, Werte.ZELLE * 0.8, Order24.TECHNO_FARBE)
		eliten.append(e)
	Ton.spiele(spiel, "tc-grenade", 0.0)
	_protokoll("ruf", {"eliten": n})


# ------------------------------------------------------------------ jeden Schritt

func immer(dt: float, k: Kommandant) -> void:
	_uhr += dt
	var e := h.einheit
	# Akku: 6 s in der Luft, 2 s am Boden – außer beim Verstärkungsruf (dann dauerhaft oben) und während eines Angriffs
	var ruf := feuer_frei()
	if not ruf:
		if am_boden:
			_boden_rest -= dt
			if _boden_rest <= 0.0:
				am_boden = false
				_akku = 0.0
				akku_protokoll.append([_uhr, "luft"])
		else:
			_akku += dt
			if _akku >= Werte.BOSS_SONDE_LUFT_SEK and not h.greift_an():
				am_boden = true
				_boden_rest = Werte.BOSS_SONDE_BODEN_SEK
				akku_protokoll.append([_uhr, "boden"])
		var sturz := str(h.angriff.get("art", "")) == "sturz" and str(h.angriff.get("teil", "")) == "typ"
		if not sturz:
			_hoehe = move_toward(_hoehe, 0.0 if am_boden else Werte.BOSS_SONDE_SCHWEBE, dt * 3.0)
	if h._aktion.is_empty():
		e.set_meta("hebt_ab", schwebe())
	if bild != null:
		bild.modulate = e._sprite.modulate   # rotes Aufleuchten der Ansage
		bild.flip_h = e._sprite.flip_h
	if str(h.angriff.get("art", "")) == "mg" and str(h.angriff.get("teil", "")) == "ansage":
		h.anvisiert = e.position
	# Rückstoß auf Brakk
	if not _stoss.is_empty() and spiel.ego != null:
		var s := (_stoss["r"] as Vector2) * float(_stoss["tempo"]) * Werte.ZELLE * dt
		spiel.ego._schritt(Vector2(s.x, 0.0))
		spiel.ego._schritt(Vector2(0.0, s.y))
		_stoss["rest"] = float(_stoss["rest"]) - dt
		if float(_stoss["rest"]) <= 0.0:
			_stoss = {}
	# Schrotstoß: Brakk zu nah
	_schrot_in -= dt
	if _schrot_in <= 0.0 and not ruf and e.position.distance_to(k.position) < Werte.BOSS_SONDE_SCHROT_NAH * Werte.ZELLE:
		var art := str(h.angriff.get("art", ""))
		if art not in ["schrot", "sturz", "heil", "ruf"]:
			_schrot_in = Werte.BOSS_SONDE_SCHROT_PAUSE
			h._aktion = {}
			h.beginne_angriff("schrot")
	if _danach_sturz and not h.greift_an():
		h._bis_angriff = 0.0   # nach dem Schrotstoß gleich das Sturzfeuer
	_scheuch_weiter(dt, k)
	lenk = lenk.filter(func(g: Dictionary) -> bool: return bg.geschosse.has(g))


## Scheuchfeld: alle 1,5 s eine rot markierte Sprengung auf Brakks Feld oder dem nächsten auf seinem wahrscheinlichen Weg.
func _scheuch_weiter(dt: float, k: Kommandant) -> void:
	if _scheuch.is_empty():
		return
	_scheuch["rest"] = float(_scheuch["rest"]) - dt
	_scheuch["in"] = float(_scheuch["in"]) - dt
	if _scheuch["marke"] != Vector2.INF:
		_scheuch["marke_t"] = float(_scheuch["marke_t"]) + dt
		if float(_scheuch["marke_t"]) >= Werte.BOSS_SONDE_SCHEUCH_MARKE:
			var p: Vector2 = _scheuch["marke"]
			spiel.effekte.flaeche(p, Werte.BOSS_SONDE_SCHEUCH_RADIUS * Werte.ZELLE, Color("ff9a3d"))
			o24._explosion3d(o24.karte.zelle_bei(p))
			Ton.am_ort(spiel, "hit-boom", p)
			if k.unverwundbar <= 0.0 and _brakk_sprung() <= Werte.BRAKK_SPRUNG_BODEN and k.position.distance_to(p) <= (Werte.BOSS_SONDE_SCHEUCH_RADIUS + Werte.BRAKK_RUMPF) * Werte.ZELLE:
				_treffe(Werte.BOSS_SONDE_SCHEUCH_ANTEIL, p)
			_protokoll("scheuch_knall", {"marke": float(_scheuch["marke_t"])})
			_scheuch["marke"] = Vector2.INF
	if float(_scheuch["in"]) <= 0.0 and float(_scheuch["rest"]) > 0.0:
		_scheuch["in"] = Werte.BOSS_SONDE_SCHEUCH_TAKT
		var p := _scheuch_ziel(k)
		_scheuch["marke"] = p
		_scheuch["marke_t"] = 0.0
		_flaeche(p, Werte.BOSS_SONDE_SCHEUCH_RADIUS, Werte.BOSS_SONDE_SCHEUCH_MARKE)
	if float(_scheuch["rest"]) <= 0.0 and _scheuch["marke"] == Vector2.INF:
		_scheuch = {}


## Brakks Feld; läuft er, das Feld vor ihm; sonst halb so oft das Nachbarfeld, auf dem er sich im Lauf am meisten aufhielt.
func _scheuch_ziel(k: Kommandant) -> Vector2:
	var karte: Karte = o24.karte
	var hier := karte.zelle_bei(k.position)
	if bg._brakk_v.length() > 20.0:
		return karte.mitte(karte.zelle_bei(k.position + bg._brakk_v.normalized() * Werte.ZELLE))
	if randf() < 0.5 and h.nem.lernen != null:
		var beste := hier
		var wert := 0.0
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]:
			var z := hier + d
			var a := float(h.nem.lernen.aufenthalt.get(z, 0.0))
			if a > wert and karte.ist_begehbar(z) and karte.ist_frei(z):
				wert = a
				beste = z
		return karte.mitte(beste)
	return karte.mitte(hier)


func wut() -> void:
	phase2 = true
	var schild := h.einheit.get_node_or_null("Frontschild") as CanvasItem
	if schild != null:
		schild.visible = false


## Duell vorbei: die Eliten des Rufs beamen weg, sie selbst wird geborgen (kein [E]).
func ende() -> void:
	for x: Variant in eliten:
		if Nemesis.lebt(x):
			h.nem._wegbeamen(x as Einheit, true)
	eliten.clear()
	_scheuch = {}
	_stoss = {}
	var e := h.einheit
	if e != null and is_instance_valid(e) and e.kampfunfaehig:
		e.get_tree().create_timer(Werte.HERAUSFORDERER_ENDE_LUPE_SEK + 0.4, true, false, true).timeout.connect(func() -> void:
			if is_instance_valid(e):
				h.nem._wegbeamen(e, true))
