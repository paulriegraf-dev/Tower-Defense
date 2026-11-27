class_name NemesisBossPlasma
extends NemesisBoss
## C2 (26.11., Paul): Befehl 24 – der Plasmawerfer als Herausforderer. Sperrig, zäh, Zonen.
##  - Werte: Leben × 1,3, Tempo × 0,85, Sprung selten (Takt am oberen Ende), kein Tumble – nur ein Seitschritt.
##  - Phase 1: Mörser (steil nach oben, 3–4 rote Kreise, Einschlag nach 1,4 s), Sturm mit Gel (wie der Sturm, am Treffpunkt
##    eine Gelfläche 8 s: darin halbes Tempo, bis Brakk zweimal gesprungen ist; höchstens drei; danach ein kurzes
##    Fenster), Abpraller (vier langsame, leuchtende Schüsse, prallen bis zu dreimal von Erdwällen und Lichtwand ab).
##  - G2-5 (27.11., Paul): Im Ansturm (vom Start bis zum Aufprall) trägt er vorn einen Schild – 25 % Schaden von vorn,
##    von der Seite und hinten normal; beim Aufprall zerspringt er.
##  - Phase 2: dazu der Brandfächer (3–4 Geschosse, 1,0 s Ansage, prallen einmal ab, legen je ein Brandfeld 6 s; höchstens
##    vier zugleich).

const ROT := Color("ff3b3b")
const GEL := Color("7dff6a")

var phase2 := false
var gele: Array = []           # je {"mitte": Vector2, "rest": Sekunden, "bild": Node3D}
var klebt := false             # Brakk steckt im Gel …
var _spruenge := 0             # … und ist seitdem so oft gesprungen …
var _befreit := false          # … zweimal: frei, bis er das Gel verlässt
## G2-5 (27.11., Paul): Sturmschild – vom Start des Ansturms bis zum Aufprall eine Platte vorn (25 % Schaden), dann zerspringt sie
var _schild: Node3D = null
var schild_richtung := Vector2.ZERO   # seine Laufrichtung im Ansturm (vorn)
var _schild_letzte := Vector2.INF
var schild_zersprungen := 0           # Prüfung


func leben_mal() -> float:
	return Werte.BOSS_PLASMA_LEBEN_MAL


func tempo_mal() -> float:
	return Werte.BOSS_PLASMA_TEMPO_MAL


func takt(_grund: float) -> float:
	return Werte.HERAUSFORDERER_AKTION_TAKT.y


func sprung_anteil(_grund: float) -> float:
	return Werte.BOSS_PLASMA_SPRUNG_ANTEIL


func tumble_ok() -> bool:
	return false


func gewichte(abstand_felder: float, _letzte: Array) -> Dictionary:
	var g := {"moerser": 1.2 if abstand_felder >= 4.0 else 0.6, "sturm": 1.6 if abstand_felder < 5.0 else 0.8, "abpraller": 1.0}
	if phase2:
		g["brandfaecher"] = 1.3
	return g


## G2-2 (27.11., Paul): P1 Mörser · Sturm mit Gel · Abpraller · Mörser · [Sturm | Abpraller]. P2: Brandfächer · Mörser · Sturm ·
## Abpraller im Kreis. Nach dem Sturm mit Gel ist das Fenster kurz (wie bisher BOSS_PLASMA_GEL_FENSTER).
func abfolge(phase2: bool) -> Array:
	var f := Werte.BOSS_ABFOLGE_FENSTER * (Werte.BOSS_ABFOLGE_P2_FENSTER if phase2 else 1.0)
	var b := Werte.BOSS_ABFOLGE_BEWEGUNG
	var fs := f * Werte.BOSS_PLASMA_GEL_FENSTER
	# G2-3: Druck = Mörser, dann Sturm mit Gel (P2: Brandfächer, dann Mörser) – die Kreise und das Gel schneiden den Weg
	if not phase2:
		return [s("moerser", f, b, {"druck": true}), s("sturm", fs, b, {"druck": true}), s("abpraller", f, b), s("moerser", f, b), s(["sturm", "abpraller"], f, b, {"fenster_je": {"sturm": fs}})]
	return [s("brandfaecher", f, b, {"druck": true}), s("moerser", f, b, {"druck": true}), s("sturm", fs, b), s("abpraller", f, b)]


## Ringe an der Kugel (Sprung, Brand) wirken auf seinen Mörser nicht; Durchschlag und Wirbel auf den Abpraller nicht –
## er hat weder Salve noch Kugel. Die übrigen Ringe wirken wie bei allen.
func ring_angriff(_art: String) -> String:
	return ""


func fenster_mal(art: String) -> float:
	return Werte.BOSS_PLASMA_GEL_FENSTER if art == "sturm" else 1.0   # nach dem Sturm mit Gel darf der nächste gleich folgen


func beginne(art: String) -> bool:
	var a := h.angriff
	var e := h.einheit
	match art:
		"moerser":
			a["um"] = Werte.BOSS_PLASMA_MOERSER_ANSAGE
			e._sprite.angriff(Werte.BOSS_PLASMA_MOERSER_ANSAGE + 0.3)
			bg._balken(bg._zu3d(e.position, 0.9), bg._zu3d(e.position, 4.0), ROT, 0.05, _bg(Werte.BOSS_PLASMA_MOERSER_ANSAGE))   # das Rohr zeigt nach oben
			Ton.am_ort(spiel, "tc-grenade", e.position)
			return true
		"abpraller":
			a["um"] = Werte.BOSS_PLASMA_PRALL_ANSAGE
			e._sprite.angriff(Werte.BOSS_PLASMA_PRALL_ANSAGE + Werte.BOSS_PLASMA_PRALL_TAKT * Werte.BOSS_PLASMA_PRALL_ZAHL)
			var r: Vector2 = a["richtung"]
			var weit := bg.abprall_bahn(e.position, r)
			bg._balken(bg._zu3d(e.position, 0.07), bg._zu3d(e.position + r * weit, 0.07), ROT, 0.05, _bg(Werte.BOSS_PLASMA_PRALL_ANSAGE))   # die erste Bahn
			bg.aufblitzen(h._muendung(r), Color("ff8ad8"))
			Ton.am_ort(spiel, "tc-plasma", e.position)
			return true
		"brandfaecher":
			a["um"] = Werte.BOSS_PLASMA_BRAND_ANSAGE
			e._sprite.angriff(Werte.BOSS_PLASMA_BRAND_ANSAGE + 0.3)
			var zahl := randi_range(Werte.BOSS_PLASMA_BRAND_ZAHL.x, Werte.BOSS_PLASMA_BRAND_ZAHL.y)
			a["zahl"] = zahl
			var halb := Werte.BOSS_PLASMA_BRAND_FAECHER * (zahl - 1) * 0.5
			bg.kegel_bild(e.position, a["richtung"] as Vector2, halb, 6.0 * Werte.ZELLE, Color("ff8a3d"), _bg(Werte.BOSS_PLASMA_BRAND_ANSAGE))
			Ton.am_ort(spiel, "tc-plasma", e.position)
			return true
	return false


func feuer(art: String, k: Kommandant) -> bool:
	var e := h.einheit
	match art:
		"moerser":
			var punkte: Array[Vector2] = [k.position]   # einer liegt auf Brakk
			var n := randi_range(Werte.BOSS_PLASMA_MOERSER_ZAHL.x, Werte.BOSS_PLASMA_MOERSER_ZAHL.y)
			var versuche := 0
			while punkte.size() < n and versuche < 40:
				versuche += 1
				var p := k.position + Vector2.RIGHT.rotated(randf() * TAU) * randf_range(2.0, Werte.BOSS_PLASMA_MOERSER_STREU) * Werte.ZELLE
				if punkte.all(func(q: Vector2) -> bool: return q.distance_to(p) >= 2.0 * Werte.BOSS_PLASMA_MOERSER_RADIUS * Werte.ZELLE):
					punkte.append(p)
			for p: Vector2 in punkte:
				bg.wurf(e.position, p, _bg(Werte.BOSS_PLASMA_MOERSER_FLUG), Werte.BOSS_PLASMA_MOERSER_RADIUS * Werte.ZELLE, 0.0, 0.0, h.schaden() * Werte.BOSS_PLASMA_MOERSER_ANTEIL, h.quelle(), true)
				(bg.wuerfe.back() as Dictionary)["typ"] = "herausforderer"
				_ring(p, Werte.BOSS_PLASMA_MOERSER_RADIUS, ROT, Werte.BOSS_PLASMA_MOERSER_FLUG)
				h._treffbereich(p, Werte.BOSS_PLASMA_MOERSER_RADIUS, Werte.BOSS_PLASMA_MOERSER_FLUG)
			_protokoll("moerser", {"zahl": punkte.size(), "flug": Werte.BOSS_PLASMA_MOERSER_FLUG})
			return true
		"sturm":
			_schild_zerspringt()   # G2-5
			h._sturm_schlag(k)
			_gel_legen(e.position)
			return true
		"abpraller":
			for i in Werte.BOSS_PLASMA_PRALL_ZAHL:
				if i == 0:
					_abpraller()
				else:
					bg.spaeter(_bg(Werte.BOSS_PLASMA_PRALL_TAKT * i), _abpraller)
			return true
		"brandfaecher":
			var zahl := int(h.angriff.get("zahl", 3))
			var r: Vector2 = h.angriff["richtung"]
			for i in zahl:
				var grad := Werte.BOSS_PLASMA_BRAND_FAECHER * (float(i) - (zahl - 1) * 0.5)
				_plasma_schuss(r.rotated(deg_to_rad(grad)), 1, {"r": Werte.BOSS_PLASMA_BRAND_RADIUS * Werte.ZELLE, "sek": _bg(Werte.BOSS_PLASMA_BRAND_SEK),
					"dps": h.schaden() * Werte.BOSS_PLASMA_BRAND_JE_SEK / Werte.SPIELTEMPO, "max": Werte.BOSS_PLASMA_BRAND_MAX})
			_protokoll("brandfaecher", {"zahl": zahl})
			return true
	return false


## Ein Abpraller auf Brakk (wo er jetzt steht).
func _abpraller() -> void:
	var k := _brakk()
	if not Nemesis.lebt(h.einheit) or k == null:
		return
	_plasma_schuss((k.position - h.einheit.position).normalized(), Werte.BOSS_PLASMA_PRALL_MAL, {})
	_protokoll("abpraller")


## Ein langsames, leuchtendes Geschoss, das bis zum nächsten Hindernis fliegt und `prall`-mal abprallt; `brand` ({} = keins)
## legt am Ende ein Brandfeld.
func _plasma_schuss(r: Vector2, prall: int, brand: Dictionary) -> void:
	var e := h.einheit
	var von := h._muendung(r)
	var anteil := Werte.BOSS_PLASMA_PRALL_ANTEIL if brand.is_empty() else Werte.BOSS_PLASMA_MOERSER_ANTEIL * 0.5
	bg.schiesse("hf_plasma", von, 0.6, h.schaden() * anteil, "herausforderer", h.quelle(), 1.0, von + r * Werte.ZELLE)
	var g: Dictionary = bg.geschosse.back()
	g["r"] = r
	g["lang"] = bg.abprall_bahn(von, r)
	g["d_ziel"] = maxf(1.0, float(g["lang"]))
	g["h0"] = 0.6
	g["h1"] = 0.6
	g["abprall"] = prall
	g["harmlos"] = false
	if not brand.is_empty():
		g["brand_ende"] = brand
	Ton.am_ort(spiel, "tc-plasma", e.position)


## Gelfläche am Treffpunkt des Sturms (die älteste verschwindet, wenn schon drei liegen).
func _gel_legen(p: Vector2) -> void:
	while gele.size() >= Werte.BOSS_PLASMA_GEL_MAX:
		_gel_weg(gele.pop_front() as Dictionary)
	var g := {"mitte": p, "rest": Werte.BOSS_PLASMA_GEL_SEK, "bild": null}
	spiel.effekte.gel(p, Werte.BOSS_PLASMA_GEL_RADIUS * Werte.ZELLE, Werte.BOSS_PLASMA_GEL_SEK * Werte.BRAKK_TEMPO * Werte.SPIELTEMPO)
	var hd: HdAnsicht = spiel.hd
	if hd != null:
		var scheibe := MeshInstance3D.new()
		var form := CylinderMesh.new()
		form.top_radius = Werte.BOSS_PLASMA_GEL_RADIUS
		form.bottom_radius = Werte.BOSS_PLASMA_GEL_RADIUS
		form.height = 0.03
		scheibe.mesh = form
		scheibe.material_override = o24._leucht(GEL, 0.35)
		hd.add_child(scheibe)
		scheibe.position = bg._zu3d(p, 0.05)
		g["bild"] = scheibe
	gele.append(g)
	_protokoll("gel", {"zahl": gele.size()})


func _gel_weg(g: Dictionary) -> void:
	if g["bild"] != null and is_instance_valid(g["bild"]):
		(g["bild"] as Node).queue_free()


## G2-5: Steht der Sturmschild gerade (Ansturm und Ansage, bis zum Aufprall)?
func schild_an() -> bool:
	return str(h.angriff.get("art", "")) == "sturm" and str(h.angriff.get("teil", "")) in ["anlauf", "ansage"]


## G2-5: Kommt Brakks Treffer von vorn (bis BOSS_PLASMA_SCHILD_WINKEL neben der Laufrichtung)?
func von_vorn() -> bool:
	var k := _brakk()
	if k == null or schild_richtung == Vector2.ZERO:
		return false
	return absf(schild_richtung.angle_to(k.position - h.einheit.position)) <= deg_to_rad(Werte.BOSS_PLASMA_SCHILD_WINKEL)


## G2-5: Im Ansturm fängt der Schild von vorn ab; von der Seite und von hinten kommt alles an.
func vor_treffer(menge: float) -> float:
	if schild_an() and von_vorn():
		return menge * Werte.BOSS_PLASMA_SCHILD_ANTEIL
	return menge


func _schild_pflegen(k: Kommandant) -> void:
	var e := h.einheit
	if not schild_an():
		_schild_weg()
		schild_richtung = Vector2.ZERO
		_schild_letzte = Vector2.INF
		return
	if _schild_letzte != Vector2.INF and e.position.distance_to(_schild_letzte) > 0.5:
		schild_richtung = (e.position - _schild_letzte).normalized()   # vorn ist, wohin er läuft
	elif schild_richtung == Vector2.ZERO:
		schild_richtung = (k.position - e.position).normalized()
	_schild_letzte = e.position
	var hd: HdAnsicht = spiel.hd
	if hd == null:
		return
	if _schild == null or not is_instance_valid(_schild):
		_schild = o24._kasten3d(hd, Vector3(1.0, 1.1, 0.08), Color(0.5, 0.9, 1.0, 0.55), Vector3.ZERO)
	var p := e.position + schild_richtung * 0.45 * Werte.ZELLE
	_schild.position = Vector3(p.x / Werte.ZELLE, 0.65, (p.y - Werte.KARTE_OBEN) / Werte.ZELLE)
	_schild.rotation.y = atan2(schild_richtung.x, schild_richtung.y)


func _schild_zerspringt() -> void:
	if _schild == null or not is_instance_valid(_schild):
		return
	schild_zersprungen += 1
	var p := h.einheit.position + schild_richtung * 0.45 * Werte.ZELLE
	spiel.effekte.flaeche(p, Werte.ZELLE * 0.6, Color("7fe0ff"))
	Ton.am_ort(spiel, "hit-thud", p)
	_protokoll("schild_zerspringt")
	_schild_weg()


func _schild_weg() -> void:
	if _schild != null and is_instance_valid(_schild):
		_schild.queue_free()
	_schild = null


## Gelflächen altern; steht Brakk am Boden darin, klebt er, bis er zweimal gesprungen ist.
func immer(dt: float, _k: Kommandant) -> void:
	_schild_pflegen(_k)   # G2-5
	for g: Dictionary in gele.duplicate():
		g["rest"] = float(g["rest"]) - dt
		if float(g["rest"]) <= 0.0:
			_gel_weg(g)
			gele.erase(g)
	var fuss: Vector2 = spiel.ego._fuss2d() if spiel.ego != null else _brakk().position
	var drin := _brakk_sprung() <= Werte.BRAKK_SPRUNG_BODEN and gele.any(func(g: Dictionary) -> bool: return (g["mitte"] as Vector2).distance_to(fuss) <= Werte.BOSS_PLASMA_GEL_RADIUS * Werte.ZELLE)
	var im_gel := gele.any(func(g: Dictionary) -> bool: return (g["mitte"] as Vector2).distance_to(fuss) <= (Werte.BOSS_PLASMA_GEL_RADIUS + 0.2) * Werte.ZELLE)
	if not im_gel:
		klebt = false
		_befreit = false
		_spruenge = 0
	elif drin and not _befreit and not klebt:
		klebt = true
		_spruenge = 0
		_protokoll("gel_klebt")


func brakk_aktion(art: String) -> void:
	if art == "sprung" and klebt:
		_spruenge += 1
		if _spruenge >= Werte.BOSS_PLASMA_GEL_SPRUENGE:
			klebt = false
			_befreit = true
			_protokoll("gel_frei")


func bremse() -> float:
	return Werte.BOSS_PLASMA_GEL_TEMPO if klebt else 1.0


func hud_zeile() -> String:
	return tr("Im Gel – zweimal springen!") if klebt else ""


func wut() -> void:
	phase2 = true


func ende() -> void:
	_schild_weg()   # G2-5
	for g: Dictionary in gele:
		_gel_weg(g)
	gele.clear()
	klebt = false
	bg.braende = bg.braende.filter(func(b: Dictionary) -> bool: return not bool(b.get("boss", false)))
