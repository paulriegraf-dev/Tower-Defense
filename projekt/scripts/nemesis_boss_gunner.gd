class_name NemesisBossGunner
extends NemesisBoss
## C2 (26.11., Paul): Befehl 24 – der Technogunner als Herausforderer. Agil, am Boden, Nahdruck.
##  - Bewegung: Lieblingsabstand × 0,8, viel Seitwärts-Sprung und Tumble (Takt am unteren Ende), nie auf Wälle. Ab Brakks
##    dritter Lichtsäule im Lauf weicht er ihr mit 50 % aus („Den Trick kenne ich.“ – einmal je Duell).
##  - Phase 1: Ringsalve (drei Ringe flacher Schüsse rundum, je mit Ring am Boden 0,6 s vorher – darüber springen oder
##    hindurch tumbeln), Ankerwurf (0,6 s ausholen, Seil sichtbar; trifft er, zieht es Brakk heran und hält ihn 0,4 s;
##    Tumble im Flug reißt das Seil), Minigun-Verfolgung (Ring 6 Felder, er läuft nach und feuert, nach 2 s doppelt so
##    stark, draußen nichts).
##  - Phase 2: Rückzug ins hintere Drittel, dort fallen drei Bunker 2×1; er wechselt zwischen ihnen und schießt 5er-Salven.
##  - G2-4 (27.11., Paul): beweglicher – Sprung/Tumble alle BOSS_GUNNER_AKTION_TAKT s, Sprint-Salve (0,4 s Ducken, dann
##    1,2 s Sprint quer zu Brakk mit Tempo × 1,8 und drei Einzelschüssen), 5er-Salve schneller (0,08 s Takt, 0,4 s Ansage).
##    Im verwundbaren Fenster steht er still.

const ROT := Color("ff3b3b")
const SEIL := Color("7fe0ff")

var phase2 := false
var _drittel := Vector2i.ZERO      # Phase 2: Spalten (relativ zur Mitte) des hinteren Drittels
var _saeule_ziel := Vector2.INF    # Brakks Lichtsäule, über die schon entschieden ist
var _trick_gesagt := false
var _gerissen := false             # Tumble, während der Anker fliegt
var minigun_schaden := 0.0         # Prüfung (Anteile eines Treffers)
var anker_treffer := 0


func abstand(grund: float) -> float:
	return 99.0 if phase2 else grund * Werte.BOSS_GUNNER_ABSTAND_MAL   # Phase 2: so weit weg, wie das Drittel erlaubt


func takt(_grund: float) -> float:
	return Werte.BOSS_GUNNER_AKTION_TAKT   # G2-4: vorher HERAUSFORDERER_AKTION_TAKT.x (1,6 s)


func sprung_anteil(_grund: float) -> float:
	return Werte.BOSS_GUNNER_SPRUNG_ANTEIL


func wall_abkling() -> float:
	return INF


func feld_ok(z: Vector2i) -> bool:
	if not phase2 or not h.kampfplatz.aktiv():
		return true
	var x := z.x - h.kampfplatz.mitte.x
	return x >= _drittel.x and x <= _drittel.y


func gewichte(abstand_felder: float, _letzte: Array) -> Dictionary:
	var g := {"ringsalve": 1.6 if abstand_felder < 5.0 else 1.0, "anker": 1.0 if abstand_felder >= 4.0 else 0.3,
		"minigun": 1.2 if abstand_felder <= Werte.BOSS_GUNNER_MINIGUN_WEITE + 2.0 else 0.6}
	if phase2:
		g["salve5"] = 1.4
	return g


## G2-2 (27.11., Paul): P1 Ringsalve · Ankerwurf → Minigun (gekoppelt: Zug, dann gleich 2 s Minigun) · Sprint-Salve ·
## Ringsalve · [Ankerwurf → Minigun | Sprint-Salve]. P2 (Bunker fallen einmal mit der Wut): 5er-Salve · Ringsalve · 5er-Salve ·
## Ankerwurf (jede vierte Position).
func abfolge(phase2: bool) -> Array:
	var f := Werte.BOSS_ABFOLGE_FENSTER
	var b := Werte.BOSS_ABFOLGE_BEWEGUNG
	if not phase2:
		var anker := {"dann": "minigun", "dann_sek": Werte.BOSS_GUNNER_DANN_MINIGUN_SEK, "dann_fuer": "anker"}
		var druck := anker.duplicate()
		druck["druck"] = true   # G2-3: Druck = Ringsalve, dann Ankerwurf → Minigun
		return [s("ringsalve", f, b, {"druck": true}), s("anker", f, b, druck), s("sprint", f, b), s("ringsalve", f, b), s(["anker", "sprint"], f, b, anker)]
	f *= Werte.BOSS_ABFOLGE_P2_FENSTER
	return [s("salve5", f, b, {"druck": true}), s("ringsalve", f, b, {"druck": true}), s("salve5", f, b), s("anker", f * 0.6, b)]


func kann(art: String, abstand_felder: float) -> bool:
	match art:
		"anker":
			return abstand_felder >= 2.0 and abstand_felder <= anker_weite()
		"salve5":
			return phase2
		"sprint":
			return not phase2   # G2-4: Sprint-Salve nur in Phase 1 (in Phase 2 hält er das hintere Drittel)
	return true


## G2-3: Seilweite – in Phase 2 wirft er aus dem hinteren Drittel weiter (sonst käme der Ankerwurf dort nie).
func anker_weite() -> float:
	return Werte.BOSS_GUNNER_P2_ANKER_WEITE if phase2 else Werte.BOSS_GUNNER_ANKER_WEITE


## Ringe für die Salve wirken auf seine Ringsalve (Durchschlag); eine Kugel hat er nicht.
func ring_angriff(art: String) -> String:
	return "ringsalve" if art == "salve" else ""


func fenster_mal(art: String) -> float:
	return 0.6 if art == "anker" else 1.0   # nach dem Heranziehen kommt der nächste Angriff bald


func beginne(art: String) -> bool:
	var a := h.angriff
	var e := h.einheit
	match art:
		"ringsalve":
			a["um"] = Werte.BOSS_GUNNER_RING_ANSAGE
			e._sprite.angriff(Werte.BOSS_GUNNER_RING_ANSAGE + Werte.BOSS_GUNNER_RING_TAKT * Werte.BOSS_GUNNER_RING_ZAHL)
			_ring(e.position, 1.2, ROT, Werte.BOSS_GUNNER_RING_ANSAGE)
			h._treffbereich(e.position, 1.2, Werte.BOSS_GUNNER_RING_ANSAGE)
			Ton.am_ort(spiel, "tc-arc", e.position)
			return true
		"anker":
			a["um"] = Werte.BOSS_GUNNER_ANKER_ANSAGE
			e._sprite.angriff(Werte.BOSS_GUNNER_ANKER_ANSAGE + 0.3)
			var ziel: Vector2 = a["ziel"]
			var r: Vector2 = a["richtung"]
			var ende := e.position + r * minf(anker_weite() * Werte.ZELLE, e.position.distance_to(ziel) + Werte.ZELLE)
			bg._balken(bg._zu3d(e.position, 0.07), bg._zu3d(ende, 0.07), ROT, 0.05, _bg(Werte.BOSS_GUNNER_ANKER_ANSAGE))   # wo das Seil hinfliegt
			bg._balken(bg._zu3d(h._muendung(r), 0.9), bg._zu3d(h._muendung(r) + r * 0.6 * Werte.ZELLE, 0.9), SEIL, 0.03, _bg(Werte.BOSS_GUNNER_ANKER_ANSAGE))
			Ton.am_ort(spiel, "tc-arc", e.position)
			return true
		"minigun":
			a["teil"] = "typ"
			a["phase"] = "an"
			_ring(e.position, Werte.BOSS_GUNNER_MINIGUN_WEITE, ROT, Werte.BOSS_GUNNER_MINIGUN_ANLAUF)
			e._sprite.angriff(Werte.BOSS_GUNNER_MINIGUN_ANLAUF + Werte.BOSS_GUNNER_MINIGUN_SEK)
			Ton.am_ort(spiel, "tc-heavy", e.position)
			return true
		"sprint":   # G2-4: Anlauf-Ducken, der Weg quer zu Brakk liegt rot am Boden
			a["um"] = Werte.BOSS_GUNNER_SPRINT_ANSAGE
			e._sprite.angriff(Werte.BOSS_GUNNER_SPRINT_ANSAGE + Werte.BOSS_GUNNER_SPRINT_SEK)
			var weit := h.tempo() * Werte.BOSS_GUNNER_SPRINT_TEMPO * Werte.BOSS_GUNNER_SPRINT_SEK
			var nach := h.seitwaerts("links" if randf() < 0.5 else "rechts", weit)
			a["nach"] = nach if nach != Vector2.INF else e.position
			e.set_meta("hebt_ab", -0.12)   # er duckt sich
			bg._balken(bg._zu3d(e.position, 0.07), bg._zu3d(a["nach"] as Vector2, 0.07), ROT, 0.05, _bg(Werte.BOSS_GUNNER_SPRINT_ANSAGE))
			Ton.am_ort(spiel, "tc-arc", e.position)
			return true
		"salve5":
			a["um"] = Werte.BOSS_GUNNER_SALVE5_ANSAGE
			e._sprite.angriff(Werte.BOSS_GUNNER_SALVE5_ANSAGE + Werte.BOSS_GUNNER_SALVE5_TAKT * 5.0)
			bg._balken(bg._zu3d(e.position, 0.07), bg._zu3d(a["ziel"] as Vector2, 0.07), ROT, 0.05, _bg(Werte.BOSS_GUNNER_SALVE5_ANSAGE))
			bg.aufblitzen(h._muendung(a["richtung"] as Vector2), ROT)
			Ton.am_ort(spiel, "tc-arc", e.position)
			return true
	return false


func feuer(art: String, k: Kommandant) -> bool:
	var a := h.angriff
	match art:
		"ringsalve":
			_schussring(0)
			for i in range(1, Werte.BOSS_GUNNER_RING_ZAHL):
				var wann := Werte.BOSS_GUNNER_RING_TAKT * i
				bg.spaeter(_bg(maxf(0.0, wann - Werte.BOSS_GUNNER_RING_ANSAGE)), _bodenring)
				bg.spaeter(_bg(wann), _schussring.bind(i))
			a["teil"] = "typ"
			a["phase"] = "ringe"
			a["t"] = 0.0
			return true
		"anker":
			_gerissen = false
			a["teil"] = "typ"
			a["phase"] = "flug"
			a["t"] = 0.0
			a["kopf"] = h.einheit.position
			a["ziel"] = k.position
			Ton.am_ort(spiel, "tc-rail", h.einheit.position)
			return true
		"salve5":
			for i in 5:
				bg.spaeter(_bg(Werte.BOSS_GUNNER_SALVE5_TAKT * i), _salve5_schuss)
			return true
		"sprint":
			h.einheit.set_meta("hebt_ab", 0.0)
			a["teil"] = "typ"
			a["phase"] = "sprint"
			a["t"] = 0.0
			a["von"] = h.einheit.position
			a["schuss"] = 0
			_protokoll("sprint", {"weit": (a["von"] as Vector2).distance_to(a["nach"] as Vector2) / Werte.ZELLE})
			return true
	return false


func _bodenring() -> void:
	if Nemesis.lebt(h.einheit):
		_ring(h.einheit.position, 1.2, ROT, Werte.BOSS_GUNNER_RING_ANSAGE)
		h._treffbereich(h.einheit.position, 1.2, Werte.BOSS_GUNNER_RING_ANSAGE)


## Ein Ring flacher Schüsse rundum; jeder Ring um einen halben Abstand gedreht, damit die Lücken wandern.
func _schussring(nr: int) -> void:
	if not Nemesis.lebt(h.einheit):
		return
	h._salven += 1
	var n := Werte.BOSS_GUNNER_RING_SCHUESSE
	for i in n:
		var r := Vector2.RIGHT.rotated(TAU * (float(i) + 0.5 * float(nr % 2)) / float(n))
		var punkt := h.einheit.position + r * Werte.BOSS_GUNNER_RING_WEITE * Werte.ZELLE
		bg.schiesse("hf_salve", h.einheit.position + r * 0.3 * Werte.ZELLE, 0.4, h.schaden() * Werte.BOSS_GUNNER_RING_ANTEIL, "herausforderer", h.quelle(), 1.0, punkt)
		var g: Dictionary = bg.geschosse.back()
		g["gruppe"] = h._salven
		g["flach"] = true
		h._an_der_wand_enden(g)
	Ton.am_ort(spiel, "tc-blaster", h.einheit.position)
	_protokoll("schussring", {"nr": nr})


func _salve5_schuss() -> void:
	var k := _brakk()
	if not Nemesis.lebt(h.einheit) or k == null:
		return
	var r := (k.position - h.einheit.position).normalized()
	bg.schiesse("hf_salve", h._muendung(r), h._hoehe_er(), h.schaden() * Werte.BOSS_GUNNER_SALVE5_ANTEIL, "herausforderer", h.quelle(), 1.0, k.position)
	h._an_der_wand_enden(bg.geschosse.back() as Dictionary)
	Ton.am_ort(spiel, "tc-blaster", h.einheit.position)
	_protokoll("salve5_schuss")


func weiter_angriff(dt: float, k: Kommandant) -> void:
	var a := h.angriff
	var t := float(a["t"])
	var e := h.einheit
	match str(a.get("phase", "")):
		"sprint":   # G2-4: quer zu Brakk, dabei drei Einzelschüsse
			var f := clampf(t / Werte.BOSS_GUNNER_SPRINT_SEK, 0.0, 1.0)
			e.position = (a["von"] as Vector2).lerp(a["nach"] as Vector2, f)
			e._sprite.bewegt(true)
			var nr := int(a["schuss"])
			if nr < Werte.BOSS_GUNNER_SPRINT_SCHUESSE and t >= Werte.BOSS_GUNNER_SPRINT_SEK * (float(nr) + 0.5) / float(Werte.BOSS_GUNNER_SPRINT_SCHUESSE):
				a["schuss"] = nr + 1
				var r := (k.position - e.position).normalized()
				bg.schiesse("hf_salve", h._muendung(r), h._hoehe_er(), h.schaden() * Werte.BOSS_GUNNER_SPRINT_ANTEIL, "herausforderer", h.quelle(), 1.0, k.position)
				h._an_der_wand_enden(bg.geschosse.back() as Dictionary)
				Ton.am_ort(spiel, "tc-blaster", e.position)
				_protokoll("sprint_schuss", {"nr": nr})
			if f >= 1.0:
				e._sprite.bewegt(false)
				_protokoll("sprint_ende", {"dauer": t, "schuesse": int(a["schuss"])})
				h.fenster()
		"ringe":
			if t >= Werte.BOSS_GUNNER_RING_TAKT * Werte.BOSS_GUNNER_RING_ZAHL:
				h.fenster()
		"flug":
			var kopf: Vector2 = a["kopf"]
			var ziel: Vector2 = a["ziel"]
			var r := (ziel - e.position).normalized()
			kopf = kopf.move_toward(e.position + r * anker_weite() * Werte.ZELLE, Werte.BOSS_GUNNER_ANKER_TEMPO * Werte.ZELLE * dt)
			a["kopf"] = kopf
			bg._balken(bg._zu3d(h._muendung(r), 0.9), bg._zu3d(kopf, 0.8), SEIL, 0.03, _bg(dt * 1.5))
			if _gerissen:
				_protokoll("anker_gerissen")
				spiel.effekte.flaeche(kopf, Werte.ZELLE * 0.4, SEIL)
				h.fenster(fenster_mal("anker"))
			elif k.unverwundbar <= 0.0 and kopf.distance_to(k.position) <= (0.45 + Werte.BRAKK_RUMPF) * Werte.ZELLE and _brakk_sprung() <= Werte.BRAKK_SPRUNG_BODEN:
				anker_treffer += 1
				a["phase"] = "zug"
				a["t"] = 0.0
				a["von"] = k.position
				h.gebunden_rest = Werte.BOSS_GUNNER_ANKER_ZUG + Werte.BOSS_GUNNER_ANKER_STARR
				_protokoll("anker_treffer")
				Ton.am_ort(spiel, "hit-thud", k.position)
			elif kopf.distance_to(e.position) >= anker_weite() * Werte.ZELLE - 1.0:
				_protokoll("anker_vorbei")
				h.fenster(fenster_mal("anker"))
		"zug":
			var von: Vector2 = a["von"]
			var nach := e.position + (von - e.position).normalized() * Werte.BOSS_GUNNER_ANKER_NAH * Werte.ZELLE
			var f := clampf(t / Werte.BOSS_GUNNER_ANKER_ZUG, 0.0, 1.0)
			var p := von.lerp(nach, f * f * (3.0 - 2.0 * f))
			if spiel.ego != null and o24.karte.ist_begehbar(o24.karte.zelle_bei(p)) and o24.karte.ist_frei(o24.karte.zelle_bei(p)):
				spiel.ego._setze_fuss(p)
			bg._balken(bg._zu3d(h._muendung((p - e.position).normalized()), 0.9), bg._zu3d(p, 0.8), SEIL, 0.03, _bg(dt * 1.5))
			if f >= 1.0:
				h.fenster(fenster_mal("anker"))
		"an":
			e._sprite.bewegt(false)
			if t >= Werte.BOSS_GUNNER_MINIGUN_ANLAUF:
				a["phase"] = "feuer"
				a["t"] = 0.0
				a["angesagt"] = Werte.BOSS_GUNNER_MINIGUN_ANLAUF
				a["ring_in"] = 0.0
		"feuer":
			h._laufe(dt, k, 2.0, h.tempo() * Werte.BOSS_GUNNER_MINIGUN_TEMPO)
			a["ring_in"] = float(a["ring_in"]) - dt
			if float(a["ring_in"]) <= 0.0:   # der Reichweitenring geht mit
				a["ring_in"] = 0.25
				_ring(e.position, Werte.BOSS_GUNNER_MINIGUN_WEITE, ROT, 0.3)
			var d := e.position.distance_to(k.position) / Werte.ZELLE
			var r := (k.position - e.position).normalized()
			var drin := d <= Werte.BOSS_GUNNER_MINIGUN_WEITE and o24.karte.sicht_frei(e.position, k.position)
			if int(t * 10.0) != int((t - dt) * 10.0):   # Leuchtspur alle 0,1 s
				var bis := k.position if drin else e.position + r * Werte.BOSS_GUNNER_MINIGUN_WEITE * Werte.ZELLE
				bg._balken(bg._zu3d(h._muendung(r), h._hoehe_er()), bg._zu3d(bis, 0.6), Color("ffd27a"), 0.025, _bg(0.06))
				Ton.am_ort(spiel, "tc-pistol", e.position)
			if drin and k.unverwundbar <= 0.0:
				var menge := Werte.BOSS_GUNNER_MINIGUN_JE_SEK * (1.0 + clampf(t / Werte.BOSS_GUNNER_MINIGUN_STEIGT, 0.0, 1.0)) * dt
				_treffe(menge, e.position, false)
				minigun_schaden += menge
			if t >= float(a.get("sek", Werte.BOSS_GUNNER_MINIGUN_SEK)):   # G2-2: gekoppelt nach dem Anker kürzer
				_protokoll("minigun_ende", {"schaden": minigun_schaden})
				h.fenster()


## Brakk tumbelt: ein fliegender Anker reißt ab.
func brakk_aktion(art: String) -> void:
	if art == "tumble" and str(h.angriff.get("art", "")) == "anker" and str(h.angriff.get("phase", "")) == "flug":
		_gerissen = true


## Ab der dritten Lichtsäule: mit 50 % aus dem Kreis tumbeln.
func immer(_dt: float, _k: Kommandant) -> void:
	var ego: EgoModus = spiel.ego
	if ego == null or ego._saeule_ziel == Vector2.INF or ego._saeule_ziel == _saeule_ziel or h.saeulen < Werte.BOSS_GUNNER_SAEULE_AB:
		return
	_saeule_ziel = ego._saeule_ziel
	var e := h.einheit
	if e.position.distance_to(_saeule_ziel) > (EgoModus.SAEULE_RADIUS + 1.0) * Werte.ZELLE or randf() >= Werte.BOSS_GUNNER_SAEULE_CHANCE:
		return
	var weg := (e.position - _saeule_ziel).normalized() if e.position.distance_to(_saeule_ziel) > 1.0 else Vector2.RIGHT
	var ziel := Vector2.INF
	for w: float in [0.0, 0.6, -0.6, 1.2, -1.2]:
		var p := e.position + weg.rotated(w) * (EgoModus.SAEULE_RADIUS + 1.2) * Werte.ZELLE
		if h._begehbar(o24.karte.zelle_bei(p)) and p.distance_to(_saeule_ziel) > EgoModus.SAEULE_RADIUS * Werte.ZELLE:
			ziel = p
			break
	if ziel == Vector2.INF:
		return
	if h.greift_an() and str(h.angriff.get("teil", "")) != "typ":
		h.angriff = {}   # er bricht ab und rollt aus dem Kreis
		h._bis_angriff = 0.6
	h._aktion = {"art": "tumble", "t": 0.0, "sek": Werte.HERAUSFORDERER_TUMBLE_SEK * 1.4, "von": e.position, "nach": ziel}
	h._weg.clear()
	h.zaehler["ausweichen"] += 1
	spiel.effekte.flaeche(e.position, Werte.ZELLE * 0.45, Color(0.75, 0.68, 0.55))
	_protokoll("saeule_ausweichen")
	if not _trick_gesagt:
		_trick_gesagt = true
		spiel.melde(tr("%s: „Den Trick kenne ich.“") % str(h.person["name"]), 3.0)


## Phase 2: ins hintere Drittel (von Brakk aus gesehen), dort fallen drei Bunker.
func wut() -> void:
	phase2 = true
	var kp := h.kampfplatz
	if not kp.aktiv():
		return
	var west := _brakk().position.x > o24.karte.mitte(kp.mitte).x
	var d := Werte.BOSS_GUNNER_DRITTEL
	_drittel = d if west else Vector2i(-1 - d.y, -1 - d.x)
	for i in Werte.BOSS_GUNNER_BUNKER.size():
		var r: Vector2i = Werte.BOSS_GUNNER_BUNKER[i]
		if not west:
			r = Vector2i(-1 - r.x, r.y)   # gespiegelt
		kp.abwerfen(kp.mitte + r, Werte.KAMPFPLATZ_SCHATTEN_SEK + Werte.KAMPFPLATZ_FALL_TAKT * float(i / 2), Callable())
	_protokoll("bunker", {"west": west})
