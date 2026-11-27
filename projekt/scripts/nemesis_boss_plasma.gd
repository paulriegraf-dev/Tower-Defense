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
## J-1 (27.11., Paul): Höhen – Brakk auf einer Krone
var brakk_oben_t := 0.0                # so lange steht Brakk schon auf einer Krone (s)
var _stoss := {}                      # Wallsprenger: Brakk fliegt herunter {"r", "rest", "tempo"}
var wallsprenger := 0                 # Zählung
var _stoss_hinweis := 0.0             # Paul (27.11.): HUD „Vom Wall gestoßen!“ so lange
var gluten: Array = []                # J-4: nachglühende Mörserkreise {"mitte", "rest", "bild", "stoff"}
var glut_schaden := 0.0              # Prüfung (Anteile eines Treffers)
var gel_zeit := 0.0                   # J-7: so lange klebte Brakk im Gel (s) …
var brakk_krone_zeit := 0.0          # … stand er auf Kronen (s) …
var _gele_summe := 0.0               # … und im Mittel so viele Gele lagen (Summe Gele × Zeit / Zeit)
var _gele_zeit := 0.0


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


## J-5 (27.11., Paul): P1 Mörser · Abpraller · Sturm+Gel · Mörser · Abpraller · [Sturm+Gel | Mörser]; Druck = Mörser → Abpraller
## (0,4 s, danach 2,25 s Belohnung). P2: Brandfächer · Mörser · Sturm+Gel · Abpraller · Mörser · [Brandfächer | Sturm+Gel], Fenster
## × 0,7 (Druck dort wie bisher Brandfächer → Mörser – Setzung). Steht Brakk auf einem Wall, wird jeder Sturm zum Wallsprenger
## (ersatz). Nach dem Sturm mit Gel ist das Fenster kurz (BOSS_PLASMA_GEL_FENSTER), nach dem Mörser BOSS_PLASMA_FENSTER_MOERSER.
func abfolge(phase2: bool) -> Array:
	var mal := Werte.BOSS_ABFOLGE_P2_FENSTER if phase2 else 1.0
	var f := Werte.BOSS_PLASMA_FENSTER * mal   # J-4
	var fm := Werte.BOSS_PLASMA_FENSTER_MOERSER * mal   # J-4: nach dem Mörser
	var b := Werte.BOSS_ABFOLGE_BEWEGUNG
	var fs := f * Werte.BOSS_PLASMA_GEL_FENSTER
	if not phase2:
		return [s("moerser", fm, b, {"druck": true}), s("abpraller", f, b, {"druck": true}), s("sturm", fs, b), s("moerser", fm, b), s("abpraller", f, b),
			s(["sturm", "moerser"], f, b, {"fenster_je": {"sturm": fs, "moerser": fm}})]
	return [s("brandfaecher", f, b, {"druck": true}), s("moerser", fm, b, {"druck": true}), s("sturm", fs, b), s("abpraller", f, b), s("moerser", fm, b),
		s(["brandfaecher", "sturm"], f, b, {"fenster_je": {"sturm": fs}})]


## Ringe an der Kugel (Sprung, Brand) wirken auf seinen Mörser nicht; Durchschlag und Wirbel auf den Abpraller nicht –
## er hat weder Salve noch Kugel. Die übrigen Ringe wirken wie bei allen.
## H-6 (27.11., Paul): Mörser (die Einschlagkreise) und Sturm (Kreis, danach die neue Gelfläche) markieren den Boden.
func boden_sek(art: String) -> float:
	if art == "moerser":
		return Werte.BOSS_PLASMA_MOERSER_ANSAGE + Werte.BOSS_PLASMA_MOERSER_FLUG
	if art == "wallsprenger":
		return Werte.BOSS_PLASMA_WALL_ANSAGE + Werte.BOSS_PLASMA_WALL_FLUG   # J-1: Kreis auf der Krone
	return super(art) if art == "sturm" else -1.0


## H-7 (27.11., Paul): die Lichtsäule der Vergeltung als Wegsperre zwischen Brakk und seiner Fluchtrichtung.
func saeule_ziel(k: Kommandant) -> Vector2:
	return _saeule_wegsperre(k)


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
		"wallsprenger":   # J-1: hoher Bogenwurf auf die Krone – Kreis und Pfeil der Flugbahn
			a["um"] = Werte.BOSS_PLASMA_WALL_ANSAGE
			var ziel := _brakk().position
			a["ziel"] = ziel
			e._sprite.angriff(Werte.BOSS_PLASMA_WALL_ANSAGE + 0.3)
			var hz := h.boden_h(ziel) + 0.06
			bg._ring(bg._zu3d(ziel, hz), Werte.BOSS_PLASMA_WALL_RADIUS, ROT, _bg(Werte.BOSS_PLASMA_WALL_ANSAGE + Werte.BOSS_PLASMA_WALL_FLUG))
			h._treffbereich(ziel, Werte.BOSS_PLASMA_WALL_RADIUS, Werte.BOSS_PLASMA_WALL_ANSAGE + Werte.BOSS_PLASMA_WALL_FLUG)
			var r := (ziel - e.position).normalized()
			bg._balken(bg._zu3d(e.position, 0.9), bg._zu3d(ziel, hz + 0.05), ROT, 0.05, _bg(Werte.BOSS_PLASMA_WALL_ANSAGE))   # Pfeil der Flugbahn
			for seite: float in [-1.0, 1.0]:
				bg._balken(bg._zu3d(ziel, hz + 0.05), bg._zu3d(ziel - r.rotated(seite * 0.55) * 0.9 * Werte.ZELLE, hz + 0.05), ROT, 0.05, _bg(Werte.BOSS_PLASMA_WALL_ANSAGE))
			Ton.am_ort(spiel, "tc-grenade", e.position)
			_protokoll("wallsprenger_ansage", {"ziel": ziel})
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
			var punkte := _moerser_punkte(k, randi_range(Werte.BOSS_PLASMA_MOERSER_ZAHL.x, Werte.BOSS_PLASMA_MOERSER_ZAHL.y))   # J-1: auf der Krone auf Kronen/Wallfuß
			for p: Vector2 in punkte:
				var ph := h.boden_h(p) + 0.05   # J-1: der Kreis liegt auf der Fläche dort (Krone oder Boden)
				bg.wurf(e.position, p, _bg(Werte.BOSS_PLASMA_MOERSER_FLUG), Werte.BOSS_PLASMA_MOERSER_RADIUS * Werte.ZELLE, 0.0, 0.0, h.schaden() * Werte.BOSS_PLASMA_MOERSER_ANTEIL, h.quelle(), true, ph)
				(bg.wuerfe.back() as Dictionary)["typ"] = "herausforderer"
				(bg.wuerfe.back() as Dictionary)["zaehl"] = "moerser"   # J-7
				bg._ring(bg._zu3d(p, ph), Werte.BOSS_PLASMA_MOERSER_RADIUS, ROT, _bg(Werte.BOSS_PLASMA_MOERSER_FLUG))
				h._treffbereich(p, Werte.BOSS_PLASMA_MOERSER_RADIUS, Werte.BOSS_PLASMA_MOERSER_FLUG, ph)
			bg.spaeter(_bg(Werte.BOSS_PLASMA_MOERSER_FLUG), _glut_an.bind(punkte.duplicate()))   # J-4: danach glühen die Kreise nach
			_protokoll("moerser", {"zahl": punkte.size(), "flug": Werte.BOSS_PLASMA_MOERSER_FLUG, "punkte": punkte, "hoehen": punkte.map(func(p: Vector2) -> float: return h.boden_h(p)), "oben": k.oben})
			return true
		"sturm":
			_schild_zerspringt()   # G2-5
			h._sturm_schlag(k)
			_gel_legen(e.position)
			return true
		"wallsprenger":
			var ziel: Vector2 = h.angriff["ziel"]
			bg.wurf(e.position, ziel, _bg(Werte.BOSS_PLASMA_WALL_FLUG), Werte.BOSS_PLASMA_WALL_RADIUS * Werte.ZELLE, 0.0, 0.0, 0.0, h.quelle(), true)   # nur das Bild
			bg.spaeter(_bg(Werte.BOSS_PLASMA_WALL_FLUG), _wallsprenger_platzt.bind(ziel))
			wallsprenger += 1
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


## J-1 (27.11., Paul): Steht Brakk auf einem Wall, wird jeder Sturm-Schritt zum Wallsprenger; nach BOSS_PLASMA_KRONE_SEK s
## auf der Krone wird auch jeder andere Schritt zum Wallsprenger (er holt ihn herunter).
func ersatz(art: String, _abstand: float) -> Array:
	var k := _brakk()
	if k != null and k.oben and h.kampfplatz.aktiv() and (art == "sturm" or brakk_oben_t >= Werte.BOSS_PLASMA_KRONE_SEK) and art not in ["brandfaecher"]:
		return ["wallsprenger", ""]
	return [art, ""]


## J-1: Der Wallsprenger platzt auf der Krone – 60 % eines Treffers und Brakk fliegt BOSS_PLASMA_STOSS Felder herunter,
## immer zur Platzmitte hin (nie Richtung Lichtwand). Wer vorher gesprungen oder 1,5 Felder zur Seite gegangen ist, bleibt heil.
func _wallsprenger_platzt(ziel: Vector2) -> void:
	if not Nemesis.lebt(h.einheit):
		return
	var k := _brakk()
	spiel.effekte.flaeche(ziel, Werte.BOSS_PLASMA_WALL_RADIUS * Werte.ZELLE, Color("ff8ad8"))
	Ton.am_ort(spiel, "hit-boom", ziel)
	var trifft := k.unverwundbar <= 0.0 and _brakk_sprung() <= Werte.BRAKK_SPRUNG_BODEN \
		and k.position.distance_to(ziel) <= (Werte.BOSS_PLASMA_WALL_RADIUS + Werte.BRAKK_RUMPF) * Werte.ZELLE
	_protokoll("wallsprenger", {"ziel": ziel, "trifft": trifft, "oben": k.oben})
	if not trifft:
		return
	h.treffe_als("wallsprenger", h.schaden() * Werte.BOSS_PLASMA_WALL_ANTEIL, ziel)
	if k.oben:
		var mitte := o24.karte.mitte(h.kampfplatz.mitte) if h.kampfplatz.aktiv() else h.einheit.position
		var r := (mitte - k.position).normalized() if mitte.distance_to(k.position) > 1.0 else Vector2.RIGHT
		_stoss = {"r": r, "rest": Werte.BOSS_PLASMA_STOSS_SEK, "tempo": Werte.BOSS_PLASMA_STOSS / Werte.BOSS_PLASMA_STOSS_SEK, "von": k.position}
		if spiel.ego != null:
			spiel.ego.steig = maxf(spiel.ego.steig, Werte.BOSS_PLASMA_STOSS_HOCH)   # er fliegt im Bogen – über die Wallkante (zu Fuß hielte sie ihn)
			spiel.ego._trauma = minf(1.0, spiel.ego._trauma + 0.55)   # Paul (27.11.): der Stoß soll sich anfühlen
		Ton.am_ort(spiel, "hit-thud", k.position)
		spiel.effekte.flaeche(k.position, Werte.ZELLE * 0.9, Color("ff8ad8"))
		_stoss_hinweis = 1.2
		_protokoll("stoss", {"r": r, "von": k.position})


## J-1: Brakk fliegt vom Wall (über die Ego-Sicht; die Lichtwand hält ihn).
func _stoss_weiter(dt: float) -> void:
	if _stoss.is_empty() or spiel.ego == null:
		return
	var s := (_stoss["r"] as Vector2) * float(_stoss["tempo"]) * Werte.ZELLE * dt
	spiel.ego._schritt(Vector2(s.x, 0.0))
	spiel.ego._schritt(Vector2(0.0, s.y))
	_stoss["rest"] = float(_stoss["rest"]) - dt
	if float(_stoss["rest"]) <= 0.0:
		_protokoll("stoss_ende", {"von": _stoss["von"], "nach": _brakk().position, "oben": _brakk().oben})
		spiel.effekte.flaeche(_brakk().position, Werte.ZELLE * 0.6, Color(0.62, 0.52, 0.38))   # Staub, wo er landet
		_stoss = {}


## J-1: Mörserziele – steht Brakk auf einer Krone, liegt ein Kreis auf seinem Feld, die übrigen auf Nachbarkronen oder am
## Wallfuß (Boden neben dem Wall); sonst wie bisher um ihn herum.
func _moerser_punkte(k: Kommandant, n: int) -> Array[Vector2]:
	var punkte: Array[Vector2] = [k.position]   # einer liegt auf Brakk
	var abstand_min := (2.0 * Werte.BOSS_PLASMA_MOERSER_RADIUS + Werte.BOSS_PLASMA_MOERSER_SPALT) * Werte.ZELLE   # J-3: immer ein Spalt
	var kandidaten: Array[Vector2] = []
	if k.oben:
		var karte: Karte = o24.karte
		var hier := karte.zelle_bei(k.position)
		for dy in range(-5, 6):
			for dx in range(-5, 6):
				var z := hier + Vector2i(dx, dy)
				if z == hier or not karte.in_karte(z):
					continue
				var hoch := spiel.hd != null and (spiel.hd as HdAnsicht).ist_hoch(z)
				var fuss := not hoch and h._begehbar(z) and [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN].any(func(d: Vector2i) -> bool: return spiel.hd != null and (spiel.hd as HdAnsicht).ist_hoch(z + d))
				if (hoch and (not h.kampfplatz.aktiv() or h.kampfplatz.innen(z))) or fuss:
					kandidaten.append(karte.mitte(z))
		kandidaten.shuffle()
	var versuche := 0
	while punkte.size() < n and versuche < 60:
		versuche += 1
		var p: Vector2
		if not kandidaten.is_empty():
			p = kandidaten.pop_back()
		elif k.oben:
			break   # oben nur Kronen und Wallfuß – lieber ein Kreis weniger
		else:
			p = k.position + Vector2.RIGHT.rotated(randf() * TAU) * randf_range(2.0, Werte.BOSS_PLASMA_MOERSER_STREU + 1.0) * Werte.ZELLE
		if punkte.all(func(q: Vector2) -> bool: return q.distance_to(p) >= abstand_min):
			punkte.append(p)
	return punkte


## Ein Abpraller auf Brakk (wo er jetzt steht).
func _abpraller() -> void:
	var k := _brakk()
	if not Nemesis.lebt(h.einheit) or k == null:
		return
	var r := (k.position - h.einheit.position).normalized()
	if k.oben and not bool(h.angriff.get("hochpraller", false)):
		h.angriff["hochpraller"] = true
		_hochpraller(r, k)   # J-1: die erste Bahn prallt vom Boden auf Kronenhöhe
		return
	_plasma_schuss(r, Werte.BOSS_PLASMA_PRALL_MAL, {})
	_protokoll("abpraller")


## J-6 (27.11., Paul): Der Klon schießt Abpraller – BOSS_PLASMA_KLON_PRALL Schüsse aus seiner Position (Takt wie beim Boss).
func klon_abpraller(x: Einheit) -> void:
	for i in Werte.BOSS_PLASMA_KLON_PRALL:
		if i == 0:
			_klon_prall_schuss(x)
		else:
			bg.spaeter(_bg(Werte.BOSS_PLASMA_PRALL_TAKT * i), _klon_prall_schuss.bind(x))


func _klon_prall_schuss(x: Einheit) -> void:
	var k := _brakk()
	if not Nemesis.lebt(x) or x.kampfunfaehig or k == null:
		return
	var r := (k.position - x.position).normalized()
	var von := x.position + r * 0.35 * Werte.ZELLE
	bg.schiesse("hf_plasma", von, 0.6, h.schaden() * Werte.BOSS_PLASMA_PRALL_ANTEIL, "herausforderer", h.quelle(), 1.0, von + r * Werte.ZELLE)
	if bg.geschosse.is_empty():
		return
	var g: Dictionary = bg.geschosse.back()
	g["r"] = r
	g["lang"] = bg.abprall_bahn(von, r)
	g["d_ziel"] = maxf(1.0, float(g["lang"]))
	g["h0"] = 0.6
	g["h1"] = 0.6
	g["abprall"] = Werte.BOSS_PLASMA_PRALL_MAL
	g["harmlos"] = false
	g["rest_sek"] = _bg(Werte.BOSS_PLASMA_PRALL_SEK)
	g["zaehl"] = "klon"
	bg.faerben(g, NemesisKlon.BLAU)   # Paul (27.11.): blau wie der Klon
	Ton.am_ort(spiel, "tc-plasma", x.position)
	_protokoll("klon_abpraller")


## J-1 (27.11., Paul): Hochpraller – gegen Brakk auf einer Krone fliegt die erste Bahn flach los, prallt vom Boden ab und steigt
## auf Kronenhöhe; sie endet hinter ihm (kein weiterer Abpraller).
func _hochpraller(r: Vector2, k: Kommandant) -> void:
	var von := h._muendung(r)
	bg.schiesse("hf_plasma", von, 0.3, h.schaden() * Werte.BOSS_PLASMA_PRALL_ANTEIL, "herausforderer", h.quelle(), 1.0, von + r * Werte.ZELLE)
	if bg.geschosse.is_empty():
		return
	var g: Dictionary = bg.geschosse.back()
	var d := von.distance_to(k.position)
	g["r"] = r
	g["lang"] = d + 0.8 * Werte.ZELLE
	g["d_ziel"] = maxf(1.0, d)
	g["h0"] = 0.15
	g["h1"] = h.ziel_h()
	g["abprall"] = 0
	g["harmlos"] = false
	g["zaehl"] = "abpraller"
	spiel.effekte.flaeche(von.lerp(k.position, 0.35), Werte.ZELLE * 0.3, Color("ff8ad8"))   # wo er vom Boden abprallt
	Ton.am_ort(spiel, "tc-plasma", h.einheit.position)
	_protokoll("hochpraller", {"h1": g["h1"]})


## Ein langsames, leuchtendes Geschoss, das bis zum nächsten Hindernis fliegt und `prall`-mal abprallt; `brand` ({} = keins)
## legt am Ende ein Brandfeld.
func _plasma_schuss(r: Vector2, prall: int, brand: Dictionary) -> void:
	var e := h.einheit
	var von := h._muendung(r)
	var anteil := Werte.BOSS_PLASMA_PRALL_ANTEIL if brand.is_empty() else Werte.BOSS_PLASMA_MOERSER_ANTEIL * 0.5
	bg.schiesse("hf_plasma", von, h._hoehe_er() + 0.1, h.schaden() * anteil, "herausforderer", h.quelle(), 1.0, von + r * Werte.ZELLE)
	var g: Dictionary = bg.geschosse.back()
	g["r"] = r
	g["lang"] = bg.abprall_bahn(von, r)
	g["d_ziel"] = maxf(1.0, float(g["lang"]))
	g["h0"] = 0.6
	g["h1"] = 0.6
	g["abprall"] = prall
	g["harmlos"] = false
	if brand.is_empty():
		g["rest_sek"] = _bg(Werte.BOSS_PLASMA_PRALL_SEK)   # J-3: der Abpraller verglüht dann (der Brandfächer nicht – er legt sein Feld)
		g["zaehl"] = "abpraller"   # J-7
	if not brand.is_empty():
		g["brand_ende"] = brand
	Ton.am_ort(spiel, "tc-plasma", e.position)


## Gelfläche am Treffpunkt des Sturms (die älteste verschwindet, wenn schon BOSS_PLASMA_GEL_MAX liegen – Boss und Klon
## zusammen). J-2 (27.11., Paul): nie auf die Aufgänge der Rand-Kronen – der Feldstreifen vor dem Wallring bleibt frei, das
## Gel rückt nach innen.
func _gel_legen(p: Vector2) -> void:
	p = gel_ort(p)
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
		g["stoff"] = scheibe.material_override
		hd.add_child(scheibe)
		scheibe.position = bg._zu3d(p, h.boden_h(p) + 0.05)   # J-1: auf der Fläche, auf der es liegt
		g["bild"] = scheibe
	gele.append(g)
	_protokoll("gel", {"zahl": gele.size()})


func _gel_weg(g: Dictionary) -> void:
	if g["bild"] != null and is_instance_valid(g["bild"]):
		(g["bild"] as Node).queue_free()


## J-4 (27.11., Paul): Greed ehrlich bestrafen – die Mörserkreise glühen nach dem Einschlag BOSS_PLASMA_GLUT_SEK s sichtbar nach
## (BOSS_PLASMA_GLUT_JE_SEK eines Treffers je Sekunde für den, der darin stehen bleibt; im Sprung nichts).
func _glut_an(punkte: Array) -> void:
	if not Nemesis.lebt(h.einheit):
		return
	for p: Vector2 in punkte:
		var gl := {"mitte": p, "rest": Werte.BOSS_PLASMA_GLUT_SEK, "bild": null, "stoff": null}
		var hd: HdAnsicht = spiel.hd
		if hd != null:
			var scheibe := MeshInstance3D.new()
			var form := CylinderMesh.new()
			form.top_radius = Werte.BOSS_PLASMA_MOERSER_RADIUS
			form.bottom_radius = Werte.BOSS_PLASMA_MOERSER_RADIUS
			form.height = 0.02
			scheibe.mesh = form
			var stoff := o24._leucht(Color("ff7a2a"), 0.5)
			scheibe.material_override = stoff
			hd.add_child(scheibe)
			scheibe.position = bg._zu3d(p, h.boden_h(p) + 0.06)
			gl["bild"] = scheibe
			gl["stoff"] = stoff
		gluten.append(gl)
	_protokoll("glut", {"zahl": punkte.size()})


func _glut_weiter(dt: float, k: Kommandant) -> void:
	if gluten.is_empty():
		return
	var ego: EgoModus = spiel.ego
	var flaeche := ego._boden() if ego != null else 0.0
	for gl: Dictionary in gluten.duplicate():
		gl["rest"] = float(gl["rest"]) - dt
		var p: Vector2 = gl["mitte"]
		if gl["stoff"] != null:
			(gl["stoff"] as StandardMaterial3D).albedo_color.a = 0.5 * clampf(float(gl["rest"]) / Werte.BOSS_PLASMA_GLUT_SEK, 0.0, 1.0) * (0.75 + 0.25 * sin(float(gl["rest"]) * 20.0))
		var drin := k.position.distance_to(p) <= (Werte.BOSS_PLASMA_MOERSER_RADIUS + Werte.BRAKK_RUMPF) * Werte.ZELLE and absf(h.boden_h(p) - flaeche) < 0.1
		if drin and k.unverwundbar <= 0.0 and _brakk_sprung() <= Werte.BRAKK_SPRUNG_BODEN:
			glut_schaden += Werte.BOSS_PLASMA_GLUT_JE_SEK * dt
			h.treffe_als("glut", h.schaden() * Werte.BOSS_PLASMA_GLUT_JE_SEK * dt, p, false)
		if float(gl["rest"]) <= 0.0:
			if gl["bild"] != null and is_instance_valid(gl["bild"]):
				(gl["bild"] as Node).queue_free()
			gluten.erase(gl)


## J-2: Wo das Gel liegen darf – im Kampfplatz nicht auf dem Feldstreifen vor dem Wallring (Aufgänge), sonst wie gewollt.
func gel_ort(p: Vector2) -> Vector2:
	var kp := h.kampfplatz
	if not kp.aktiv():
		return p
	var hb := BrakkKampfplatz._halb()
	var rand := Werte.BOSS_PLASMA_GEL_RADIUS + 1.0   # Gelradius + der freie Streifen (Felder)
	var lo := o24.karte.mitte(kp.mitte - hb + Vector2i.ONE) - Vector2.ONE * 0.5 * Werte.ZELLE + Vector2.ONE * rand * Werte.ZELLE
	var hi := o24.karte.mitte(kp.mitte + hb - Vector2i(2, 2)) + Vector2.ONE * 0.5 * Werte.ZELLE - Vector2.ONE * rand * Werte.ZELLE
	return p.clamp(lo, hi)


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
	_glut_weiter(dt, _k)   # J-4
	brakk_oben_t = (brakk_oben_t + dt) if _k.oben else 0.0   # J-1
	if h.zustand == "duell":   # J-7: Zählung
		brakk_krone_zeit += dt if _k.oben else 0.0
		gel_zeit += dt if klebt else 0.0
		_gele_summe += gele.size() * dt
		_gele_zeit += dt
	_stoss_weiter(dt)
	_stoss_hinweis = maxf(0.0, _stoss_hinweis - dt)
	for g: Dictionary in gele.duplicate():
		g["rest"] = float(g["rest"]) - dt
		if g.get("stoff") != null and float(g["rest"]) < Werte.BOSS_PLASMA_GEL_SCHWACH:   # J-2: in den letzten Sekunden schwächer
			(g["stoff"] as StandardMaterial3D).albedo_color.a = 0.35 * clampf(float(g["rest"]) / Werte.BOSS_PLASMA_GEL_SCHWACH, 0.15, 1.0)
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
	if _stoss_hinweis > 0.0:
		return tr("Vom Wall gestoßen!")
	if str(h.angriff.get("art", "")) == "wallsprenger" and str(h.angriff.get("teil", "")) == "ansage":
		return tr("Wallsprenger – runter von der Krone oder zur Seite!")
	return tr("Im Gel – zweimal springen!") if klebt else ""


func wut() -> void:
	phase2 = true


## J-7 (27.11., Paul): Zählung des Plasmawerfers für Tafel und Protokoll.
func zaehlung_extra() -> Dictionary:
	return {"gel_zeit": snappedf(gel_zeit, 0.1), "brakk_krone_zeit": snappedf(brakk_krone_zeit, 0.1), "wallsprenger": wallsprenger,
		"gele_mittel": snappedf(_gele_summe / _gele_zeit, 0.1) if _gele_zeit > 0.0 else 0.0}


func ende() -> void:
	_schild_weg()   # G2-5
	for gl: Dictionary in gluten:   # J-4
		if gl["bild"] != null and is_instance_valid(gl["bild"]):
			(gl["bild"] as Node).queue_free()
	gluten.clear()
	for g: Dictionary in gele:
		_gel_weg(g)
	gele.clear()
	klebt = false
	bg.braende = bg.braende.filter(func(b: Dictionary) -> bool: return not bool(b.get("boss", false)))
