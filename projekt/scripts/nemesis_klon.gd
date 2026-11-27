class_name NemesisKlon
extends RefCounted
## H-8 (27.11., Paul): Befehl 24 – die Klonmaschine des Herausforderers (Scharfschütze, Technogunner, Plasmawerfer; nicht
## Sonde 7). Mit BOSS_KLON_CHANCE je Duell, einmal, frühestens BOSS_KLON_AB s nach der Ankunft, nicht während der
## Phase-2-Eröffnung und nicht, solange Zielmarkierungs-Stellungen stehen:
##   Ansage BOSS_KLON_ANSAGE s („Klonmaschine!“, Funkton) → die Klonmaschine fällt an eine feste Stelle am Platzrand →
##   BOSS_KLON_MASCHINE s später tritt eine Kopie heraus: gleiche Art, BOSS_KLON_LEBEN seines Lebens, blauer Umriss,
##   Namensschild „Klon“. Sie kann nur Salve (blaue Linien, eine Welle; beim Technogunner die 4er-Salve, I-8) und Sturm (ohne
##   Ringe; beim Plasmawerfer Sturm mit Gel und zwei Abpraller, J-6), pausiert, solange der Boss eine
##   Reihenwelle oder Säule laufen hat, und hält sich an „ein Bodeneffekt zugleich“ (Besitzer „klon“).
##   Nach BOSS_KLON_SEK s oder bei 0 Leben beamt sie weg, die Maschine zerfällt.
## Kein Benannter: die Kopie steht in keiner Liste des Nemesis-Systems.

const BLAU := Color("4aa8ff")   # Paul (27.11.): der Klon und seine Effekte blau (vorher grau)
const LILA := Color("c9a6ff")
const STELLEN: Array[Vector2i] = [Vector2i(-6, -4), Vector2i(5, -4), Vector2i(-6, 3), Vector2i(5, 3)]   # relativ zur Platzmitte

var h: NemesisHerausforderer
var o24: Order24
var spiel: Node
var zustand := "aus"             # "aus", "ansage", "maschine", "kampf", "fertig"
var gezogen := false             # kommt in diesem Duell eine Klonmaschine?
var t := 0.0
var e: Einheit = null
var ort := Vector2.ZERO          # wo die Maschine steht (Bildpunkte)
var angriff := {}                # {"art": "salve"|"sturm", "teil": "ansage"|"anlauf"|"fenster", "t", "linien"}
var protokoll: Array = []        # Prüfung: {"was", "bei"}
var _bis := 1.5                  # bis zum nächsten Angriff (s)
var _letzter := "sturm"
var _weg_t := 0.0
var _ziel_p := Vector2.INF
var _maschine: Node3D = null
var _schild: Label3D = null
var _aktion := {}                 # Paul (27.11.): Sprung oder Tumble wie der Boss {"art", "t", "sek", "von", "nach"}
var _aktion_in := 1.5


func _init(p_h: NemesisHerausforderer) -> void:
	h = p_h
	o24 = h.o24
	spiel = h.spiel


## Zieht dieses Duell eine Klonmaschine? (`zahl` in 0..1; Prüfung: Quote über viele Ziehungen)
static func zieht(zahl: float) -> bool:
	return zahl < Werte.BOSS_KLON_CHANCE


## Zu Beginn des Duells: ziehen (Bossarena: „Klon erzwingen“).
func duell_beginnt(erzwingen: bool) -> void:
	gezogen = not h.ist_sonde() and (erzwingen or zieht(randf()))
	zustand = "aus"
	protokoll.append({"was": "gezogen" if gezogen else "nicht_gezogen", "bei": h.uhr})


func laeuft() -> bool:
	return zustand == "kampf" and e != null and is_instance_valid(e)


## Ein Schritt (`dt` echte Sekunden), aus NemesisHerausforderer.schritt.
func weiter(dt: float, k: Kommandant) -> void:
	t += dt
	match zustand:
		"aus":
			if gezogen and h.uhr >= Werte.BOSS_KLON_AB and _darf_kommen():
				_ansage()
		"ansage":
			if t >= Werte.BOSS_KLON_ANSAGE:
				_maschine_faellt()
		"maschine":
			if t >= Werte.BOSS_KLON_MASCHINE:
				_kopie_tritt_heraus()
		"kampf":
			if e == null or not is_instance_valid(e) or e.kampfunfaehig or e.leben <= 0.0 or t >= Werte.BOSS_KLON_SEK:
				_weg("gefallen" if e != null and is_instance_valid(e) and t < Werte.BOSS_KLON_SEK else "zeit")
				return
			e.halt = true
			_kaempfen(dt, k)
			_schild_pflegen()


func _darf_kommen() -> bool:
	if not h.kampfplatz.zu() or h.typ == null:
		return false
	if h.typ is NemesisBossScharf and (h.typ as NemesisBossScharf).schuetzen.any(func(s: Dictionary) -> bool: return Nemesis.lebt(s["e"])):
		return false   # nicht, solange Zielmarkierungs-Stellungen stehen
	if not h._abf_vorn.is_empty() or (int(h.schritt_jetzt.get("i", 0)) == -1 and h.greift_an()):
		return false   # nicht während der Phase-2-Eröffnung
	return true


func _ansage() -> void:
	zustand = "ansage"
	t = 0.0
	Ton.spiele(spiel, "tc-arc", 0.0)   # Funkton
	spiel.melde(tr("%s: „Klonmaschine!“") % str(h.person.get("name", "")), 2.5)
	var beste := h.kampfplatz.mitte + STELLEN[0]
	var weit := -1.0
	for r: Vector2i in STELLEN:
		var z := h.kampfplatz.mitte + r
		var d := o24.karte.mitte(z).distance_to((spiel.kommandant as Kommandant).position)
		if d > weit and o24.karte.inhalt(z) != Karte.WALL:
			weit = d
			beste = z
	ort = o24.karte.mitte(beste)
	spiel.effekte.warnung(ort, NemesisHerausforderer._bg(Werte.BOSS_KLON_ANSAGE) * Werte.BRAKK_TEMPO)
	protokoll.append({"was": "ansage", "bei": h.uhr, "ort": ort})


## Die Klonmaschine fällt vom Himmel (Bodenplatte mit lila Rand, Laserfeld – wie klonmaschine.gd in der HD-Ansicht).
func _maschine_faellt() -> void:
	zustand = "maschine"
	t = 0.0
	var hd: HdAnsicht = spiel.hd
	if hd != null:
		_maschine = Node3D.new()
		var platte := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.9, 0.12, 0.9)
		platte.mesh = box
		platte.material_override = o24._leucht(Color("2a2038"), 1.0)
		_maschine.add_child(platte)
		var rand := MeshInstance3D.new()
		var rbox := BoxMesh.new()
		rbox.size = Vector3(0.96, 0.05, 0.96)
		rand.mesh = rbox
		rand.material_override = o24._leucht(LILA, 0.9)
		rand.position.y = 0.07
		_maschine.add_child(rand)
		for i in 6:
			var strahl := MeshInstance3D.new()
			var sb := BoxMesh.new()
			sb.size = Vector3(0.05, 1.1, 0.05)
			strahl.mesh = sb
			strahl.material_override = o24._leucht(LILA, 0.4)
			strahl.position = Vector3(-0.32 + i * 0.128, 0.6, 0.0)
			_maschine.add_child(strahl)
		hd.add_child(_maschine)
		var ziel := Vector3(ort.x / Werte.ZELLE, 0.0, (ort.y - Werte.KARTE_OBEN) / Werte.ZELLE)
		_maschine.position = ziel + Vector3(0, 9.0, 0)
		var tw := _maschine.create_tween()
		tw.tween_property(_maschine, "position", ziel, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	spiel.effekte.flaeche(ort, Werte.ZELLE * 0.8, LILA)
	Ton.am_ort(spiel, "hit-boom", ort)
	protokoll.append({"was": "maschine", "bei": h.uhr})


func _kopie_tritt_heraus() -> void:
	var b := h.einheit
	if b == null or not is_instance_valid(b):
		zustand = "fertig"
		return
	var art := str(h.person.get("art", "scharfschuetze"))
	e = o24._neue_truppe(art, h._fabrik_fuer(art), 1)
	e.max_leben = b.max_leben * Werte.BOSS_KLON_LEBEN
	e.leben = e.max_leben
	e.halt = true
	e.zustand = Einheit.Zustand.BODEN
	e._punkte.clear()
	e._ausstehend.clear()
	e.posten_zelle = Karte.KEINE
	e.position = ort
	e.set_meta("kampfplatz_erlaubt", true)   # die Lichtwand schiebt ihn nicht hinaus
	e.set_meta("herausforderer_klon", true)
	e.set_meta("nemesis_umriss", BLAU)
	# Paul (27.11.): er sieht aus wie der Boss – dasselbe Aussehen (Look) und Rangabzeichen, nur blau umrandet
	if not h.person.is_empty() and h.person.has("look"):
		NemesisLook.anziehen(e, int(h.person["look"]))
	if not h.person.is_empty():
		h.nem._rang_bild(e, int(h.person.get("rang", 1)))
	zustand = "kampf"
	t = 0.0
	_bis = 1.0
	spiel.effekte.flaeche(ort, Werte.ZELLE * 0.9, BLAU)
	(spiel.brakk_geschosse as BrakkGeschosse)._blitz(Vector3(ort.x / Werte.ZELLE, 0.8, (ort.y - Werte.KARTE_OBEN) / Werte.ZELLE), BLAU, 0.9)
	Ton.am_ort(spiel, "tc-arc", ort)
	protokoll.append({"was": "klon", "bei": h.uhr, "leben": e.max_leben, "art": art})


## Er beamt weg, die Maschine zerfällt.
func _weg(wie: String) -> void:
	if e != null and is_instance_valid(e):
		spiel.effekte.flaeche(e.position, Werte.ZELLE * 0.8, BLAU)
		h.nem._wegbeamen(e, true)
	e = null
	angriff = {}
	h.boden_freigeben("klon")
	if _maschine != null and is_instance_valid(_maschine):
		var tw := _maschine.create_tween()
		tw.tween_property(_maschine, "scale", Vector3(1.4, 0.01, 1.4), 0.5)
		tw.tween_callback(_maschine.queue_free)
		spiel.effekte.flaeche(ort, Werte.ZELLE * 0.7, Color(0.62, 0.52, 0.38))
	_maschine = null
	if _schild != null and is_instance_valid(_schild):
		_schild.queue_free()
	_schild = null
	zustand = "fertig"
	protokoll.append({"was": "weg", "bei": h.uhr, "wie": wie, "nach": t})


## Duell vorbei.
func ende() -> void:
	if zustand in ["ansage", "maschine", "kampf"]:
		_weg("ende")
	elif _maschine != null and is_instance_valid(_maschine):
		_maschine.queue_free()


func _schild_pflegen() -> void:
	var hd: HdAnsicht = spiel.hd
	if hd == null or e == null:
		return
	if _schild == null or not is_instance_valid(_schild):
		_schild = Label3D.new()
		_schild.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_schild.font_size = 30
		_schild.outline_size = 8
		_schild.fixed_size = true
		_schild.pixel_size = 0.0012
		_schild.modulate = BLAU
		_schild.outline_modulate = Color(0.05, 0.03, 0.08, 0.9)
		_schild.text = tr("Klon")
		hd.add_child(_schild)
	_schild.position = Vector3(e.position.x / Werte.ZELLE, 1.9 + float(e.get_meta("hebt_ab", 0.0)), (e.position.y - Werte.KARTE_OBEN) / Werte.ZELLE)


# ------------------------------------------------------------------ Salve und Sturm

## Pausiert, solange der Boss eine Reihenwelle oder Säule laufen hat.
func pausiert() -> bool:
	return not h.boden_frei(["boss", "klon", "kombo"])


func _kaempfen(dt: float, k: Kommandant) -> void:
	e._sprite.flip_h = k.position.x < e.position.x
	if not _aktion.is_empty():
		_aktion_weiter(dt)
		return
	if not angriff.is_empty():
		_angriff_weiter(dt, k)
		return
	_laufen(dt, k, h.typ.abstand(float(h.kennwerte.get("abstand", Werte.HERAUSFORDERER_ABSTAND_SONST))) * 0.8, h.tempo())
	_aktion_in -= dt
	if _aktion_in <= 0.0:
		_aktion_in = randf_range(1.6, 2.6)
		_ausweichen(k)   # Paul (27.11.): er springt und tumbelt wie der Boss
		return
	if pausiert():
		return
	_bis -= dt
	if _bis > 0.0 or not h.boden_frei(["klon"]) or not h.sieht_von(e, k.position):
		return
	_letzter = "salve" if _letzter == "sturm" else "sturm"
	angriff = {"art": _letzter, "teil": "anlauf" if _letzter == "sturm" else "ansage", "t": 0.0}
	if _letzter == "salve":
		if h.typ is NemesisBossGunner:   # I-8: beim Technogunner die 4er-Salve (eine blaue Linie)
			angriff["linien"] = (h.typ as NemesisBossGunner).vierer_linie(e, Werte.BOSS_KLON_SALVE_ANSAGE, BLAU)
		elif h.typ is NemesisBossPlasma:   # J-6: beim Plasmawerfer Abpraller – die erste Bahn blau am Boden
			var r := (k.position - e.position).normalized()
			var bgx: BrakkGeschosse = spiel.brakk_geschosse
			bgx._balken(bgx._zu3d(e.position, h.markierung_h()), bgx._zu3d(e.position + r * bgx.abprall_bahn(e.position, r), h.markierung_h()), BLAU, 0.05, NemesisHerausforderer._bg(Werte.BOSS_KLON_SALVE_ANSAGE))
			angriff["linien"] = {}
		else:
			angriff["linien"] = h.salve_linien(e, Werte.BOSS_KLON_SALVE_ANSAGE, Werte.BOSS_SNIPER_SALVE_WINKEL, Werte.BOSS_SNIPER_SALVE_VORHALT_MAX, _salve_tempo(), BLAU)
		h.boden_belegen("klon", Werte.BOSS_KLON_SALVE_ANSAGE + 0.1)
		e._sprite.angriff(Werte.BOSS_KLON_SALVE_ANSAGE + 0.2)
		Ton.am_ort(spiel, "tc-arc", e.position)
	else:
		h.boden_belegen("klon", Werte.HERAUSFORDERER_STURM_ANLAUF + Werte.HERAUSFORDERER_STURM_ANSAGE)
	protokoll.append({"was": "angriff", "bei": h.uhr, "art": _letzter})


func _salve_tempo() -> float:
	return 8.0 / maxf(0.05, Werte.BOSS_SNIPER_SALVE_FLUG)


func _angriff_weiter(dt: float, k: Kommandant) -> void:
	angriff["t"] = float(angriff["t"]) + dt
	var at := float(angriff["t"])
	match str(angriff["teil"]):
		"anlauf":
			var d := e.position.distance_to(k.position) / Werte.ZELLE
			if d <= Werte.HERAUSFORDERER_STURM_NAH or at >= Werte.HERAUSFORDERER_STURM_ANLAUF:
				angriff["teil"] = "ansage"
				angriff["t"] = 0.0
				var bg: BrakkGeschosse = spiel.brakk_geschosse
				bg._ring(bg._zu3d(e.position, h.markierung_h()), Werte.HERAUSFORDERER_STURM_RADIUS, BLAU, NemesisHerausforderer._bg(Werte.HERAUSFORDERER_STURM_ANSAGE))
				h.boden_belegen("klon", Werte.HERAUSFORDERER_STURM_ANSAGE)
				e._sprite.angriff(Werte.HERAUSFORDERER_STURM_ANSAGE + 0.2)
				Ton.am_ort(spiel, "tc-arc", e.position)
			else:
				e._sprite.bewegt(true)
				e.position = e.position.move_toward(k.position, h.tempo() * Werte.HERAUSFORDERER_STURM_TEMPO * Werte.ZELLE * dt)
				_ziel_p = Vector2.INF
		"ansage":
			e._sprite.bewegt(false)
			var glimm := 0.5 + 0.5 * sin(at * 26.0)
			e._sprite.modulate = Color(1.0 - 0.6 * glimm, 1.0 - 0.3 * glimm, 1.0)   # blaues Aufleuchten der Ansage (der Boss leuchtet rot)
			var um := Werte.BOSS_KLON_SALVE_ANSAGE if str(angriff["art"]) == "salve" else Werte.HERAUSFORDERER_STURM_ANSAGE
			if at >= um:
				if str(angriff["art"]) == "salve":
					if h.typ is NemesisBossPlasma:
						(h.typ as NemesisBossPlasma).klon_abpraller(e)   # J-6: zwei Abpraller (prallen – Sicht unnötig)
					elif h.sieht_von(e, k.position) and h.typ is NemesisBossGunner:
						(h.typ as NemesisBossGunner).vierer_feuern(angriff["linien"], "klon", BLAU)   # I-8; blaue Geschosse
					elif h.sieht_von(e, k.position):
						h.salve_feuern(angriff["linien"], h.schaden() * Werte.BOSS_KLON_SALVE_ANTEIL, _salve_tempo(), "klon", -1, 1, BLAU)
						Ton.am_ort(spiel, "tc-blaster", e.position)
				else:
					_sturm_schlag(k)
				e._sprite.modulate = Color.WHITE
				angriff["teil"] = "fenster"
				angriff["t"] = 0.0
		"fenster":
			e._sprite.bewegt(false)
			if at >= Werte.BOSS_KLON_FENSTER:
				angriff = {}
				_bis = Werte.BOSS_KLON_BEWEGUNG


func _sturm_schlag(k: Kommandant) -> void:
	var radius := Werte.HERAUSFORDERER_STURM_RADIUS * Werte.ZELLE
	spiel.effekte.flaeche(e.position, radius, BLAU)
	Ton.am_ort(spiel, "hit-boom", e.position)
	var ego: EgoModus = spiel.ego
	var sprung := (ego.hoehe - ego._boden()) if ego != null else 0.0
	if h.typ is NemesisBossPlasma:
		(h.typ as NemesisBossPlasma)._gel_legen(e.position)   # J-6: Sturm mit Gel – zählt gegen den gemeinsamen Deckel
	if k.unverwundbar > 0.0 or sprung > Werte.HERAUSFORDERER_STURM_SPRUNG or k.position.distance_to(e.position) > radius + Werte.BRAKK_RUMPF * Werte.ZELLE:
		return
	h.treffe_als("klon", h.schaden() * Werte.BOSS_KLON_STURM_ANTEIL, e.position)


## Auf Abstand `soll` (Felder) mit Sicht gehen – alle 0,4 s ein Feld in der Nähe wählen.
func _laufen(dt: float, k: Kommandant, soll: float, v: float) -> void:
	var karte: Karte = o24.karte
	_weg_t -= dt
	if _weg_t <= 0.0 or _ziel_p == Vector2.INF:
		_weg_t = 0.4
		var hier := karte.zelle_bei(e.position)
		var beste := hier
		var wert := -INF
		for dy in range(-2, 3):
			for dx in range(-2, 3):
				var z := hier + Vector2i(dx, dy)
				if not h._begehbar(z):
					continue
				var p := karte.mitte(z)
				var w := -absf(p.distance_to(k.position) / Werte.ZELLE - soll) * 2.0 + (4.0 if karte.sicht_frei(p, k.position) else 0.0) + randf() * 1.0 - 0.15 * Vector2(dx, dy).length()
				if w > wert:
					wert = w
					beste = z
		_ziel_p = karte.mitte(beste)
	var rest := v * Werte.ZELLE * dt
	e._sprite.bewegt(e.position.distance_to(_ziel_p) > 1.0)
	e.position = e.position.move_toward(_ziel_p, rest)


## Paul (27.11.): Sprung oder Tumble zur Seite (wie der Boss), mit Staub.
func _ausweichen(k: Kommandant) -> void:
	var zu := (k.position - e.position).normalized() if k.position.distance_to(e.position) > 1.0 else Vector2.RIGHT
	var seite := Vector2(-zu.y, zu.x) * (1.0 if randf() < 0.5 else -1.0)
	var springt := randf() < 0.4
	var weit := (1.2 if springt else Werte.HERAUSFORDERER_TUMBLE_WEIT) * Werte.ZELLE
	for s: Vector2 in [seite, -seite]:
		var nach := e.position + s * weit
		if h._begehbar(o24.karte.zelle_bei(nach)) and h._begehbar(o24.karte.zelle_bei(e.position.lerp(nach, 0.5))):
			_aktion = {"art": "sprung" if springt else "tumble", "t": 0.0, "sek": Werte.HERAUSFORDERER_SPRUNG_SEK if springt else Werte.HERAUSFORDERER_TUMBLE_SEK,
				"von": e.position, "nach": nach}
			spiel.effekte.flaeche(e.position, Werte.ZELLE * 0.4, Color(0.75, 0.68, 0.55))
			return


func _aktion_weiter(dt: float) -> void:
	_aktion["t"] = float(_aktion["t"]) + dt
	var a := clampf(float(_aktion["t"]) / float(_aktion["sek"]), 0.0, 1.0)
	e.position = (_aktion["von"] as Vector2).lerp(_aktion["nach"] as Vector2, a)
	e.set_meta("hebt_ab", 4.0 * a * (1.0 - a) * Werte.BRAKK_SPRUNG_HOEHE_FELD if str(_aktion["art"]) == "sprung" else 0.0)
	e._sprite.bewegt(false)
	if a >= 1.0:
		e.set_meta("hebt_ab", 0.0)
		if str(_aktion["art"]) == "tumble":
			spiel.effekte.flaeche(e.position, Werte.ZELLE * 0.35, Color(0.75, 0.68, 0.55))
		_aktion = {}
		_ziel_p = Vector2.INF
