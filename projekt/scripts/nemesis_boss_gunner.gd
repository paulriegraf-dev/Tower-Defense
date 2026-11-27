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
const NAH_ERSATZ := "sturmring"   # I-1: aus der Nähe statt des Jagdankers

var phase2 := false
var bunker_kiting := false          # I-6: Phase-2-Bunker mit Rückzug ins hintere Drittel (G2) – nicht mehr gewählt
var _drittel := Vector2i.ZERO      # Phase 2: Spalten (relativ zur Mitte) des hinteren Drittels
var _saeule_ziel := Vector2.INF    # Brakks Lichtsäule, über die schon entschieden ist
var _trick_gesagt := false
var _gerissen := false             # Tumble, während der Anker fliegt
var minigun_schaden := 0.0         # Prüfung (Anteile eines Treffers)
var anker_treffer := 0
var minigun_drin_zeit := 0.0       # I-8: so lange stand Brakk im Feuer der Minigun (s)
var anker_gerissen := 0             # I-8: Jagdanker – Tumble riss das Seil
var kronen := 0                    # I-5/I-8: Sprünge auf Rand-Kronen …
var krone_zeit := 0.0              # … und die Zeit oben (s)
var _oben := false
var _oben_t := 0.0
var _ohne_sicht_t := 0.0


func abstand(grund: float) -> float:
	return grund * Werte.BOSS_GUNNER_ABSTAND_MAL   # I-6: auch in Phase 2 (kein Rückzug ins Drittel mehr)


func takt(_grund: float) -> float:
	return Werte.BOSS_GUNNER_AKTION_TAKT   # G2-4: vorher HERAUSFORDERER_AKTION_TAKT.x (1,6 s)


func sprung_anteil(_grund: float) -> float:
	return Werte.BOSS_GUNNER_SPRUNG_ANTEIL


## I-5 (27.11., Paul): auf Rand-Kronen höchstens alle BOSS_GUNNER_KRONE_AB s (vorher nie auf Wälle).
func wall_abkling() -> float:
	return Werte.BOSS_GUNNER_KRONE_AB


func feld_ok(z: Vector2i) -> bool:
	if not bunker_kiting or not phase2 or not h.kampfplatz.aktiv():   # I-6: das hintere Drittel gilt nur noch mit Bunker-Kiting (aus)
		return true
	var x := z.x - h.kampfplatz.mitte.x
	return x >= _drittel.x and x <= _drittel.y


func gewichte(abstand_felder: float, _letzte: Array) -> Dictionary:
	var g := {"ringsalve": 1.6 if abstand_felder < 5.0 else 1.0, "anker": 1.0 if abstand_felder >= 4.0 else 0.3,
		"minigun": 1.2 if abstand_felder <= Werte.BOSS_GUNNER_MINIGUN_WEITE + 2.0 else 0.6}
	if phase2:
		g["salve5"] = 1.4
	return g


## I-6 (27.11., Paul): P1 Jagdanker → Minigun (gekoppelt) · Sturmring · 4er-Salve · 4er-Salve · Sturmring ·
## [Jagdanker → Minigun | 4er-Salve]; Druck = Sturmring → 4er-Salve → 4er-Salve (0,4 s, keine Bewegung, danach 2,25 s
## Belohnung); nach Jagdanker → Minigun immer ein volles Fenster. P2 (kein Bunker-Kiting mehr): Eröffnung Krone → Jagdanker
## (22 Felder) → Minigun, dann Sturmring · 4er-Salve · Jagdanker → Minigun · 4er-Salve · 4er-Salve · Sturmring ·
## [Krone-Sprung | 4er-Salve], Fenster × 0,7 (H-Setzung: Druck dort Sturmring → 4er-Salve). I-7: Fenster BOSS_GUNNER_FENSTER,
## Bewegung BOSS_GUNNER_BEWEGUNG.
func abfolge(phase2: bool) -> Array:
	var f := Werte.BOSS_GUNNER_FENSTER * (Werte.BOSS_ABFOLGE_P2_FENSTER if phase2 else 1.0)
	var b := Werte.BOSS_GUNNER_BEWEGUNG
	var anker := {"dann": "minigun", "dann_sek": Werte.BOSS_GUNNER_DANN_MINIGUN_SEK, "dann_fuer": "anker"}
	if not phase2:
		return [s("anker", f, b, anker), s("sturmring", f, b, {"druck": true}), s("salve4", f, b, {"druck": true}), s("salve4", f, b, {"druck": true}),
			s("sturmring", f, b), s(["anker", "salve4"], f, b, anker)]
	return [s("sturmring", f, b, {"druck": true}), s("salve4", f, b, {"druck": true}), s("anker", f, b, anker), s("salve4", f, b), s("salve4", f, b),
		s("sturmring", f, b), s(["kronesprung", "salve4"], f, b)]


## I-6: Phase 2 beginnt mit Sprung auf eine Rand-Krone → Jagdanker (22 Felder) → Minigun.
func eroeffnung(phase2: bool) -> Array:
	if not phase2:
		return []
	var e := s("anker", Werte.BOSS_GUNNER_FENSTER * Werte.BOSS_ABFOLGE_P2_FENSTER, Werte.BOSS_GUNNER_BEWEGUNG,
		{"krone": true, "dann": "minigun", "dann_sek": Werte.BOSS_GUNNER_DANN_MINIGUN_SEK, "dann_fuer": "anker"})
	return [e]


func kann(art: String, abstand_felder: float) -> bool:
	match art:
		"anker":
			return true   # I-1: nie überspringen – aus der Nähe wird er zum Sturmring (ersatz), aus der Ferne läuft er erst an
		"salve5":
			return phase2
		"sprint":
			return not phase2   # G2-4: Sprint-Salve nur in Phase 1 (in Phase 2 hält er das hintere Drittel)
		"kronesprung":
			return h.kampfplatz.zu() and h.einheit.zustand != Einheit.Zustand.AUF_POSTEN   # I-6: nur vom Boden aus
	return true


## G2-3: Seilweite – in Phase 2 wirft er aus dem hinteren Drittel weiter (sonst käme der Ankerwurf dort nie).
func anker_weite() -> float:
	var oben := Werte.BOSS_GUNNER_KRONE_PLUS if h.einheit != null and h.einheit.zustand == Einheit.Zustand.AUF_POSTEN else 0.0   # I-5: von der Krone weiter
	return (Werte.BOSS_GUNNER_P2_ANKER_WEITE if phase2 else Werte.BOSS_GUNNER_ANKER_WEITE) + oben


## Ringe für die Salve wirken auf seine Ringsalve (Durchschlag); eine Kugel hat er nicht.
## H-7 (27.11., Paul): die Lichtsäule der Vergeltung als Wegsperre zwischen Brakk und seiner Fluchtrichtung.
func saeule_ziel(k: Kommandant) -> Vector2:
	return _saeule_wegsperre(k)


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
			if e.position.distance_to(_brakk().position) > anker_weite() * Werte.ZELLE:
				a["teil"] = "typ"   # I-1: zu weit – erst BOSS_GUNNER_ANKER_ANLAUF s auf ihn zu, dann der Wurf
				a["phase"] = "anker_lauf"
				_protokoll("anker_lauf")
			else:
				_anker_ansage()
			return true
		"salve4":   # I-3: 4er-Salve – folgt sie auf eine 4er-Salve, erst ein Seitschritt (neue Linie aus neuem Winkel)
			if h._letzte.size() >= 2 and str(h._letzte[-2]) == "salve4":
				var nach := h.seitwaerts("links" if randf() < 0.5 else "rechts", Werte.BOSS_GUNNER_SALVE4_SEIT)
				if nach != Vector2.INF:
					a["teil"] = "typ"
					a["phase"] = "salve4_seit"
					a["von"] = e.position
					a["nach"] = nach
					_protokoll("salve4_seit")
					return true
			_salve4_ansage()
			return true
		"sturmring":   # I-2: Anlauf (Tempo × BOSS_GUNNER_STURM_TEMPO), dann Kreis und Schlag, danach die Ringsalve
			a["teil"] = "typ"
			a["phase"] = "sturm_lauf"
			a["ring_nr"] = 0
			if e.zustand == Einheit.Zustand.AUF_POSTEN:
				_herab_springen(a)   # I-5: der Sturm beginnt mit dem Absprung von der Krone
			Ton.am_ort(spiel, "tc-arc", e.position)
			return true
		"minigun":
			a["teil"] = "typ"
			a["phase"] = "an"
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


## I-3 (27.11., Paul): 4er-Salve – Ansage BOSS_GUNNER_SALVE4_ANSAGE s (Waffe hoch, Aufleuchten, eine Linie am Boden auf Brakks
## vorausberechnete Position), dann vier Schüsse im Takt entlang der Linie (höchstens zwei Treffer). Ausweichen: Tumble quer.
func _salve4_ansage() -> void:
	var a := h.angriff
	var e := h.einheit
	a["teil"] = "ansage"
	a["t"] = 0.0
	a["um"] = Werte.BOSS_GUNNER_SALVE4_ANSAGE
	a["linie"] = vierer_linie(e, Werte.BOSS_GUNNER_SALVE4_ANSAGE, ROT)
	e._sprite.angriff(Werte.BOSS_GUNNER_SALVE4_ANSAGE + Werte.BOSS_GUNNER_SALVE4_TAKT * 4.0)
	bg.aufblitzen((a["linie"] as Dictionary)["m"] as Vector2, ROT)
	Ton.am_ort(spiel, "tc-arc", e.position)
	_protokoll("salve4_linie", {"dir": ((a["linie"] as Dictionary)["dirs"] as Array)[0], "von": e.position})


## I-3: Eine Linie vom Schützen `x` auf Brakks vorausberechnete Position (Ansage + Flug), am Boden sichtbar `vor` s lang.
func vierer_linie(x: Einheit, vor: float, farbe: Color) -> Dictionary:
	var k := _brakk()
	var zu := (k.position - x.position).normalized() if k.position.distance_to(x.position) > 1.0 else Vector2.RIGHT
	var m := x.position + zu * 0.35 * Werte.ZELLE
	var flug := m.distance_to(k.position) / (salve4_tempo() * Werte.ZELLE)
	var ziel := h.vorhersage(vor + flug + Werte.BOSS_GUNNER_SALVE4_TAKT * 1.5, Werte.BOSS_GUNNER_SALVE4_VORHALT_MAX)
	var r := (ziel - m).normalized() if ziel.distance_to(m) > 1.0 else zu
	var weit := m.distance_to(k.position) + 2.0 * Werte.ZELLE
	var lang := weit if k.oben else h.weite_bis_wand(m, r, weit)
	var hoch := h.markierung_h()
	bg._balken(bg._zu3d(m, hoch), bg._zu3d(m + r * lang, hoch), farbe, 0.04, _bg(vor + Werte.BOSS_GUNNER_SALVE4_TAKT * 4.0))
	return {"m": m, "dirs": [r], "lang": [lang], "e": x}


## I-3: Felder je echter Sekunde (8 Felder in BOSS_GUNNER_SALVE4_FLUG s).
static func salve4_tempo() -> float:
	return 8.0 / maxf(0.05, Werte.BOSS_GUNNER_SALVE4_FLUG)


## I-3: Die vier Schüsse entlang der Linie (`zaehl`: Art für die Zählung, z. B. „klon“).
func vierer_feuern(l: Dictionary, zaehl: String, farbe: Color = Color(0, 0, 0, 0)) -> void:
	h._salven += 1
	var gruppe := h._salven
	var menge := h.schaden() * Werte.BOSS_GUNNER_SALVE4_ANTEIL
	for i in Werte.BOSS_GUNNER_SALVE4_ZAHL:
		if i == 0:
			_vierer_schuss(l, menge, zaehl, gruppe, farbe)
		else:
			bg.spaeter(_bg(Werte.BOSS_GUNNER_SALVE4_TAKT * i), _vierer_schuss.bind(l, menge, zaehl, gruppe, farbe))


func _vierer_schuss(l: Dictionary, menge: float, zaehl: String, gruppe: int, farbe: Color = Color(0, 0, 0, 0)) -> void:
	var x: Variant = l.get("e")
	if not Nemesis.lebt(x) or (x as Einheit).kampfunfaehig:
		return
	h.salve_feuern(l, menge, salve4_tempo(), zaehl, gruppe, Werte.BOSS_GUNNER_SALVE4_MAX, farbe)
	Ton.am_ort(spiel, "tc-blaster", (x as Einheit).position)
	_protokoll("salve4_schuss", {"r": (l["dirs"] as Array)[0]})


## I-1 (27.11., Paul): Jagdanker – Ausholen (BOSS_GUNNER_ANKER_ANSAGE s), das Seil zeigt die Richtung, Ton.
func _anker_ansage() -> void:
	var a := h.angriff
	var e := h.einheit
	var k := _brakk()
	a["teil"] = "ansage"
	a["t"] = 0.0
	a["um"] = Werte.BOSS_GUNNER_ANKER_ANSAGE
	a["ziel"] = k.position
	a["richtung"] = (k.position - e.position).normalized()
	e._sprite.angriff(Werte.BOSS_GUNNER_ANKER_ANSAGE + 0.3)
	var r: Vector2 = a["richtung"]
	var ende := e.position + r * minf(anker_weite() * Werte.ZELLE, e.position.distance_to(k.position) + Werte.ZELLE)
	bg._balken(bg._zu3d(e.position, h.markierung_h() + 0.02), bg._zu3d(ende, h.markierung_h() + 0.02), ROT, 0.09, _bg(Werte.BOSS_GUNNER_ANKER_ANSAGE))   # wo das Seil hinfliegt
	bg._balken(bg._zu3d(h._muendung(r), h._hoehe_er() + 0.4), bg._zu3d(h._muendung(r) + r * 0.6 * Werte.ZELLE, h._hoehe_er() + 0.4), SEIL, 0.08, _bg(Werte.BOSS_GUNNER_ANKER_ANSAGE))
	Ton.am_ort(spiel, "tc-arc", e.position)
	if not h.gesagt.has("jagdanker"):   # erstes Mal je Lauf
		h.gesagt["jagdanker"] = true
		spiel.melde(tr("Jagdanker – Brakks Anker, umgebaut: er holt dich zu ihm."), 4.0)


## I-1: Steht Brakk näher als BOSS_GUNNER_ANKER_MIN, wird der Jagdanker zum Sturmring.
func ersatz(art: String, abstand: float) -> Array:
	if art == "anker" and abstand < Werte.BOSS_GUNNER_ANKER_MIN:
		return [NAH_ERSATZ, ""]
	if art == "sturmring" and abstand > Werte.BOSS_GUNNER_STURM_FERN:
		return ["anker", "sturmring"]   # I-2: zu weit – erst der Jagdanker holt ihn, dann der Sturmring
	return [art, ""]


## I-1: HUD – solange der Jagdanker fliegt: „Tumble!“
func hud_zeile() -> String:
	if str(h.angriff.get("art", "")) == "anker" and str(h.angriff.get("phase", "")) == "flug":
		return tr("Tumble!")
	return ""


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
		"salve4":
			vierer_feuern(a["linie"], "salve4")   # I-3; danach das Fenster (Nachladen sichtbar, immer())
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
		_protokoll("bodenring")
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
		g["zaehl"] = "ring"   # I-8: Treffer der Ringe getrennt zählen
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
		"salve4_seit":   # I-3: 2-Felder-Seitschritt vor der zweiten 4er-Salve
			var f := clampf(t / Werte.BOSS_GUNNER_SALVE4_SEIT_SEK, 0.0, 1.0)
			e.position = (a["von"] as Vector2).lerp(a["nach"] as Vector2, f)
			e._sprite.bewegt(true)
			if f >= 1.0:
				e._sprite.bewegt(false)
				_salve4_ansage()
		"herab":   # I-5: Absprung von der Krone – im Bogen auf den Boden vor ihm, dann der Anlauf
			var f := clampf(t / Werte.HERAUSFORDERER_SPRUNG_SEK, 0.0, 1.0)
			e.position = (a["von"] as Vector2).lerp(a["nach"] as Vector2, f)
			e.set_meta("hebt_ab", 4.0 * f * (1.0 - f) * Werte.BRAKK_SPRUNG_HOEHE_FELD)
			if f >= 1.0:
				e.set_meta("hebt_ab", 0.0)
				a["phase"] = "sturm_lauf"
				a["t"] = 0.0
		"sturm_lauf":   # I-2: Sturmring – Anlauf mit Tempo × BOSS_GUNNER_STURM_TEMPO …
			var d := e.position.distance_to(k.position) / Werte.ZELLE
			if d <= Werte.HERAUSFORDERER_STURM_NAH + 1.0 or t >= Werte.HERAUSFORDERER_STURM_ANLAUF:
				# … Kreis an Brakks vorausberechneter Position, er setzt dorthin nach
				var ziel := h.vorhersage(Werte.BOSS_GUNNER_STURM_ANSAGE, 2.0)
				if h.kampfplatz.aktiv():
					var rand := Vector2.ONE * 1.5 * Werte.ZELLE
					ziel = ziel.clamp(h.kampfplatz.rechteck.position + rand, h.kampfplatz.rechteck.end - rand)
				a["phase"] = "sturm_ansage"
				a["t"] = 0.0
				a["von"] = e.position
				a["nach"] = ziel
				e._sprite.bewegt(false)
				e._sprite.angriff(Werte.BOSS_GUNNER_STURM_ANSAGE + 0.2)
				bg._ring(bg._zu3d(ziel, h.markierung_h()), Werte.HERAUSFORDERER_STURM_RADIUS, ROT, _bg(Werte.BOSS_GUNNER_STURM_ANSAGE))
				h._treffbereich(ziel, Werte.HERAUSFORDERER_STURM_RADIUS, Werte.BOSS_GUNNER_STURM_ANSAGE)
				spiel.effekte.warnung(ziel, _bg(Werte.BOSS_GUNNER_STURM_ANSAGE) * Werte.BRAKK_TEMPO)
				Ton.am_ort(spiel, "tc-arc", e.position)
				_protokoll("sturmring_ansage", {"ziel": ziel})
			else:
				h._laufe(dt, k, 0.8, h.tempo() * Werte.BOSS_GUNNER_STURM_TEMPO)
		"sturm_ansage":
			var rot := 0.55 + 0.45 * sin(t * 26.0)
			e._sprite.modulate = Color(1.0, 1.0 - 0.75 * rot, 1.0 - 0.75 * rot)
			e.position = (a["von"] as Vector2).lerp(a["nach"] as Vector2, clampf(t / Werte.BOSS_GUNNER_STURM_ANSAGE, 0.0, 1.0))
			if t >= Werte.BOSS_GUNNER_STURM_ANSAGE:
				e._sprite.modulate = Color.WHITE
				a["angesagt"] = Werte.BOSS_GUNNER_STURM_ANSAGE
				_sturm_schlag(k)
				a["phase"] = "sturm_ringe"
				a["t"] = 0.0
		"sturm_ringe":   # I-2: BOSS_GUNNER_RING_ERSTER s nach dem Schlag die Ringsalve, 50 % schneller
			var nr := int(a["ring_nr"])
			if nr < Werte.BOSS_GUNNER_RING_ZAHL:
				var bei := Werte.BOSS_GUNNER_RING_ERSTER + Werte.BOSS_GUNNER_RING_TAKT * nr
				if t >= bei - Werte.BOSS_GUNNER_RING_ANSAGE and not bool(a.get("ring_angesagt_%d" % nr, false)):
					a["ring_angesagt_%d" % nr] = true
					_bodenring()
				if t >= bei:
					_schussring(nr)
					a["ring_nr"] = nr + 1
			elif t >= Werte.BOSS_GUNNER_RING_ERSTER + Werte.BOSS_GUNNER_RING_TAKT * (Werte.BOSS_GUNNER_RING_ZAHL - 1) + 0.3:
				h.boden_freigeben("boss")
				h.fenster()
		"anker_lauf":   # I-1: zu weit für den Jagdanker – er läuft an, dann wirft er (kein Überspringen)
			var d := e.position.distance_to(k.position) / Werte.ZELLE
			if d <= anker_weite() - 0.5 or t >= Werte.BOSS_GUNNER_ANKER_ANLAUF:
				e._sprite.bewegt(false)
				_anker_ansage()
			else:
				h._laufe(dt, k, anker_weite() - 2.0, h.tempo())
		"flug":
			var kopf: Vector2 = a["kopf"]
			var ziel: Vector2 = a["ziel"]
			var r := (ziel - e.position).normalized()
			kopf = kopf.move_toward(e.position + r * anker_weite() * Werte.ZELLE, Werte.BOSS_GUNNER_ANKER_TEMPO * Werte.ZELLE * dt)
			a["kopf"] = kopf
			bg._balken(bg._zu3d(h._muendung(r), h._hoehe_er() + 0.4), bg._zu3d(kopf, h.ziel_h()), SEIL, 0.1, _bg(dt * 1.5))   # Paul (27.11.): das Seil dicker …
			if int(t * 12.0) != int((t - dt) * 12.0):
				bg._blitz(bg._zu3d(kopf, h.ziel_h()), SEIL.lightened(0.3), 0.35)   # … und ein leuchtender Ankerkopf
			if _gerissen:
				_protokoll("anker_gerissen")
				anker_gerissen += 1
				spiel.effekte.flaeche(kopf, Werte.ZELLE * 0.4, SEIL)
				h.fenster(fenster_mal("anker"))
			elif k.unverwundbar <= 0.0 and kopf.distance_to(k.position) <= (0.45 + Werte.BRAKK_RUMPF) * Werte.ZELLE and _brakk_sprung() <= Werte.BRAKK_SPRUNG_BODEN:
				anker_treffer += 1
				if not h.zaehlung.is_empty():   # I-8: der Zug zählt als Treffer (ohne Schaden)
					var tz: Dictionary = h.zaehlung["treffer"]
					var ez: Dictionary = tz.get("anker", {"n": 0, "schaden": 0.0})
					ez["n"] = int(ez["n"]) + 1
					tz["anker"] = ez
				a["phase"] = "straff"   # I-1: das Seil strafft sich sichtbar, dann der Zug
				a["t"] = 0.0
				a["von"] = k.position
				h.gebunden_rest = Werte.BOSS_GUNNER_ANKER_STRAFF + 0.05
				_protokoll("anker_treffer", {"abstand": e.position.distance_to(k.position) / Werte.ZELLE})
				Ton.am_ort(spiel, "hit-thud", k.position)
				if spiel.ego != null:
					spiel.ego._trauma = minf(1.0, spiel.ego._trauma + 0.45)   # Kamera-Ruck
			elif kopf.distance_to(e.position) >= anker_weite() * Werte.ZELLE - 1.0:
				_protokoll("anker_vorbei")
				h.fenster(fenster_mal("anker"))
		"straff":
			var von0: Vector2 = a["von"]
			bg._balken(bg._zu3d(h._muendung((von0 - e.position).normalized()), h._hoehe_er() + 0.4), bg._zu3d(von0, h.ziel_h()), SEIL.lightened(0.4), 0.14, _bg(dt * 1.5))
			h.gebunden_rest = maxf(h.gebunden_rest, 0.05)
			if t >= Werte.BOSS_GUNNER_ANKER_STRAFF:
				a["phase"] = "zug"
				a["t"] = 0.0
				a["von"] = k.position
				Ton.am_ort(spiel, "tc-rail", k.position)   # Seilton
		"zug":   # I-1: mit BOSS_GUNNER_ANKER_ZUGTEMPO bis BOSS_GUNNER_ANKER_NAH vor ihn – Brakk zielt und schießt weiter
			var von: Vector2 = a["von"]
			var nach := e.position + (von - e.position).normalized() * Werte.BOSS_GUNNER_ANKER_NAH * Werte.ZELLE
			var zug_sek := maxf(0.05, von.distance_to(nach) / (Werte.BOSS_GUNNER_ANKER_ZUGTEMPO * Werte.ZELLE))
			var f := clampf(t / zug_sek, 0.0, 1.0)
			var p := von.lerp(nach, f)
			h.gebunden_rest = Werte.BOSS_GUNNER_ANKER_STARR if f >= 1.0 else maxf(h.gebunden_rest, 0.05)   # danach kurz starr
			if spiel.ego != null and o24.karte.ist_begehbar(o24.karte.zelle_bei(p)) and o24.karte.ist_frei(o24.karte.zelle_bei(p)):
				spiel.ego._setze_fuss(p)
			bg._balken(bg._zu3d(h._muendung((p - e.position).normalized()), h._hoehe_er() + 0.4), bg._zu3d(p, h.ziel_h()), SEIL.lightened(0.2), 0.12, _bg(dt * 1.5))
			if f >= 1.0:
				h.fenster(fenster_mal("anker"))
		"an":
			e._sprite.bewegt(false)
			if t >= Werte.BOSS_GUNNER_MINIGUN_ANLAUF:
				a["phase"] = "feuer"
				a["t"] = 0.0
				a["angesagt"] = Werte.BOSS_GUNNER_MINIGUN_ANLAUF
		"feuer":
			if e.zustand != Einheit.Zustand.AUF_POSTEN:   # I-5: auf der Krone steht er
				h._laufe(dt, k, 2.0, h.tempo() * Werte.BOSS_GUNNER_MINIGUN_TEMPO)
			var d := e.position.distance_to(k.position) / Werte.ZELLE
			var r := (k.position - e.position).normalized()
			var drin := d <= Werte.BOSS_GUNNER_MINIGUN_WEITE and o24.karte.sicht_frei(e.position, k.position)
			if int(t * 10.0) != int((t - dt) * 10.0):   # Leuchtspur alle 0,1 s
				var bis := k.position if drin else e.position + r * Werte.BOSS_GUNNER_MINIGUN_WEITE * Werte.ZELLE
				bg._balken(bg._zu3d(h._muendung(r), h._hoehe_er()), bg._zu3d(bis, h.ziel_h() if drin else h._hoehe_er()), Color("ffd27a"), 0.025, _bg(0.06))
				Ton.am_ort(spiel, "tc-pistol", e.position)
			if drin and k.unverwundbar <= 0.0:
				var menge := Werte.BOSS_GUNNER_MINIGUN_JE_SEK * (1.0 + clampf(t / Werte.BOSS_GUNNER_MINIGUN_STEIGT, 0.0, 1.0)) * dt
				_treffe(menge, e.position, false)
				minigun_schaden += menge
			var feuer_sek := (float(a["sek"]) - Werte.BOSS_GUNNER_MINIGUN_ANLAUF) if a.has("sek") else Werte.BOSS_GUNNER_MINIGUN_SEK   # I-1: gekoppelt inklusive Anlauf
			if t >= feuer_sek:   # G2-2: gekoppelt nach dem Anker kürzer
				_protokoll("minigun_ende", {"schaden": minigun_schaden})
				h.fenster()


## I-2: Der Schlag des Sturmrings (wie der Sturm: rückwärts tumbeln oder springen).
func _sturm_schlag(k: Kommandant) -> void:
	var e := h.einheit
	var radius := Werte.HERAUSFORDERER_STURM_RADIUS * Werte.ZELLE
	spiel.effekte.flaeche(e.position, radius, Color("ff5a4a"))
	Ton.am_ort(spiel, "hit-boom", e.position)
	_protokoll("sturmring_schlag")
	if k.unverwundbar > 0.0 or _brakk_sprung() > Werte.HERAUSFORDERER_STURM_SPRUNG or k.position.distance_to(e.position) > radius + Werte.BRAKK_RUMPF * Werte.ZELLE:
		return
	h.treffe_als("sturm", h.schaden(), e.position)


## I-2/H-6: Bodenmarkierungen – Sturmring (Kreis, dann die Ringe am Boden), 4er-Salve (die Linie).
func boden_sek(art: String) -> float:
	match art:
		"sturmring":
			return Werte.HERAUSFORDERER_STURM_ANLAUF + Werte.BOSS_GUNNER_STURM_ANSAGE + Werte.BOSS_GUNNER_RING_ERSTER + Werte.BOSS_GUNNER_RING_TAKT * (Werte.BOSS_GUNNER_RING_ZAHL - 1) + 0.3
		"salve4":
			return Werte.BOSS_GUNNER_SALVE4_SEIT_SEK + Werte.BOSS_GUNNER_SALVE4_ANSAGE + Werte.BOSS_GUNNER_SALVE4_TAKT * (Werte.BOSS_GUNNER_SALVE4_ZAHL - 1) + 0.1
		"ringsalve":
			return Werte.BOSS_GUNNER_RING_ANSAGE + Werte.BOSS_GUNNER_RING_TAKT * Werte.BOSS_GUNNER_RING_ZAHL
	return super(art)


## Brakk tumbelt: ein fliegender Anker reißt ab.
func brakk_aktion(art: String) -> void:
	if art == "tumble" and str(h.angriff.get("art", "")) == "anker" and str(h.angriff.get("phase", "")) == "flug":
		_gerissen = true


## I-5 (27.11., Paul): Auf der Krone – höchstens zwei Angriffe oder BOSS_GUNNER_KRONE_MAX s, dann Sturmring herunter; hat er
## BOSS_GUNNER_KRONE_SICHT s keine Sicht auf Brakk, sofort. Herunter nie anders (die normale Kronenzeit gilt für ihn nicht).
func _krone_pflegen(dt: float, k: Kommandant) -> void:
	var e := h.einheit
	if e.zustand != Einheit.Zustand.AUF_POSTEN:
		if _oben:
			_oben = false
			krone_zeit += _oben_t
			_protokoll("krone_ende", {"oben": _oben_t})
		return
	if not _oben:
		_oben = true
		_oben_t = 0.0
		_ohne_sicht_t = 0.0
		kronen += 1
		_protokoll("krone", {"z": o24.karte.zelle_bei(e.position)})
	h._wall_rest = 999.0   # herunter nur mit dem Sturmring
	if not h._aktion.is_empty():
		return   # noch im Sprung hinauf
	_oben_t += dt
	_ohne_sicht_t = 0.0 if h.sieht(e.position, k.position) else _ohne_sicht_t + dt
	var genug := _oben_t >= Werte.BOSS_GUNNER_KRONE_MAX or h._krone_angriffe >= Werte.BOSS_GUNNER_KRONE_ANGRIFFE or _ohne_sicht_t >= Werte.BOSS_GUNNER_KRONE_SICHT
	if not genug or not h._aktion.is_empty():
		return
	if h.greift_an():
		if str(h.angriff.get("teil", "")) != "fenster":
			return   # ein Angriff läuft noch (bereit() lässt oben nur Angriffe zu, die vor dem Deckel fertig sind)
		h.angriff = {}   # am Deckel endet sein Fenster
	h.schritt_jetzt = {}
	h._wartend = ""
	if h.boden_frei(["boss"]):
		_protokoll("krone_herab", {"oben": _oben_t, "angriffe": h._krone_angriffe, "ohne_sicht": _ohne_sicht_t})
		h.beginne_angriff("sturmring")
	else:
		_protokoll("krone_herab", {"oben": _oben_t, "angriffe": h._krone_angriffe, "ohne_sicht": _ohne_sicht_t, "ohne_sturm": true})
		h._vom_wall()   # der Boden ist markiert (Säule, Klon): nur herunterspringen


## I-5: Auf der Krone beginnt er nur Angriffe, die vor dem Deckel (BOSS_GUNNER_KRONE_MAX, zwei Angriffe) fertig sind.
func bereit(art: String, _abstand: float, _wartet: float) -> bool:
	if h.einheit.zustand != Einheit.Zustand.AUF_POSTEN or art == "sturmring":
		return true
	if h._krone_angriffe >= Werte.BOSS_GUNNER_KRONE_ANGRIFFE:
		return false
	return _oben_t + _dauer(art) <= Werte.BOSS_GUNNER_KRONE_MAX


## I-5: grobe Dauer eines Angriffs von der Krone (s, mit Fenster).
func _dauer(art: String) -> float:
	match art:
		"anker":
			return Werte.BOSS_GUNNER_ANKER_ANSAGE + anker_weite() / Werte.BOSS_GUNNER_ANKER_TEMPO + Werte.BOSS_GUNNER_ANKER_STRAFF + 0.8 + Werte.BOSS_GUNNER_DANN_MINIGUN_SEK
		"salve4":
			return Werte.BOSS_GUNNER_SALVE4_ANSAGE + Werte.BOSS_GUNNER_SALVE4_TAKT * Werte.BOSS_GUNNER_SALVE4_ZAHL
		"minigun":
			return Werte.BOSS_GUNNER_MINIGUN_ANLAUF + Werte.BOSS_GUNNER_MINIGUN_SEK
	return 1.5


## I-5: Die Vergeltung (Säule) wartet, bis er wieder unten ist – sonst hielte sie ihn über den Deckel oben.
func vergeltung_ok() -> bool:
	return h.einheit.zustand != Einheit.Zustand.AUF_POSTEN


## I-5: Der Sturmring beginnt mit dem Absprung von der Krone auf den Boden Richtung Brakk.
func _herab_springen(a: Dictionary) -> void:
	var e := h.einheit
	var karte: Karte = o24.karte
	var unten := karte.mitte(o24._freies_feld_bei(e.position, karte.zelle_bei(_brakk().position)))
	if h.kampfplatz.zu() and not h.kampfplatz.im_innern(karte.zelle_bei(unten)):
		unten = karte.mitte(h.kampfplatz._frei_innen(karte.zelle_bei(e.position)))
	e.zustand = Einheit.Zustand.BODEN
	h._wall_rest = 0.0
	_protokoll("krone_absprung", {"oben": _oben_t})
	a["phase"] = "herab"
	a["von"] = e.position
	a["nach"] = unten
	Ton.am_ort(spiel, "tc-arc", e.position)


## I-4 (27.11., Paul): Reichweitenring der Minigun (BOSS_GUNNER_MINIGUN_WEITE): gestrichelt, sobald sie (oder der Jagdanker mit
## gekoppelter Minigun) der nächste Schritt ist; beim Anlaufen breit und pulsierend; beim Feuern mit Brakk darin rot gefüllt.
func _minigun_ring(k: Kommandant, dt: float) -> void:
	var a := h.angriff
	var art := str(a.get("art", ""))
	var teil := str(a.get("teil", ""))
	var phase := str(a.get("phase", ""))
	var laeuft := art == "minigun" and teil != "fenster"
	var vorher := (art == "anker" and str(h.schritt_jetzt.get("dann", "")) == "minigun") or h.naechste_arten().has("minigun") or h.naechste_arten().has("anker")
	var drin := h.einheit.position.distance_to(k.position) <= Werte.BOSS_GUNNER_MINIGUN_WEITE * Werte.ZELLE
	reichweite_ring(h.zustand == "duell" and (laeuft or vorher), Werte.BOSS_GUNNER_MINIGUN_WEITE, laeuft and (phase == "an" or drin), laeuft and phase == "feuer" and drin)
	if laeuft and phase == "feuer" and drin:
		minigun_drin_zeit += dt   # I-8: Zählung


## I-3: Nach der 4er-Salve BOSS_GUNNER_SALVE4_NACHLADEN s sichtbar nachladen (bläuliches Flackern; das Fenster läuft schon).
func _nachladen_zeigen() -> void:
	var a := h.angriff
	if str(a.get("art", "")) != "salve4" or str(a.get("teil", "")) != "fenster":
		return
	var t := float(a.get("t", 0.0))
	if t < Werte.BOSS_GUNNER_SALVE4_NACHLADEN:
		h.einheit._sprite.modulate = Color(0.7, 0.85, 1.0) if int(t * 16.0) % 2 == 0 else Color.WHITE
	elif not bool(a.get("geladen", false)):
		a["geladen"] = true
		h.einheit._sprite.modulate = Color.WHITE


## Ab der dritten Lichtsäule: mit 50 % aus dem Kreis tumbeln.
func immer(_dt: float, _k: Kommandant) -> void:
	_nachladen_zeigen()
	_krone_pflegen(_dt, _k)   # I-5
	var ego: EgoModus = spiel.ego
	_minigun_ring(_k, _dt)   # I-4
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
## I-6 (27.11., Paul): Phase 2 ohne Bunker-Kiting (die Eröffnung bringt ihn auf eine Krone); der alte Bunker-Abwurf
## bleibt im Code (_bunker_abwerfen), wird aber nicht gewählt.
func wut() -> void:
	phase2 = true
	if bunker_kiting:
		_bunker_abwerfen()


func _bunker_abwerfen() -> void:
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


## I-8 (27.11., Paul): Zählung des Technogunners für Tafel und Protokoll.
func zaehlung_extra() -> Dictionary:
	return {"anker_treffer": anker_treffer, "anker_gerissen": anker_gerissen, "minigun_drin": snappedf(minigun_drin_zeit, 0.1),
		"kronen": kronen, "krone_zeit": snappedf(krone_zeit + (_oben_t if _oben else 0.0), 0.1)}


## Duell vorbei: der Reichweitenring verschwindet.
func ende() -> void:
	reichweite_weg()
