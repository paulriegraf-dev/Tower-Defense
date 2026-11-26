class_name BrakkKampfplatz
extends Node
## C1 (26.11., Paul): Befehl 24 – der Kampfplatz des Herausforderers, als Phase der Karte:
##  1. Kurz nach der Ansage merkt sich das Spiel alles, was im Platz (und ein Feld darum) steht – Erdwälle mit Ausbauten,
##     Fabriken mit ihrem Zustand – und lässt es mit einem Beam verschwinden. Truppen dort werden hinausgebeamt.
##  2. 3 s nach der Ansage fallen die Erdwälle des Platzes vom Himmel (KAMPFPLATZ_*): ein Ring mit vier Lücken, innen
##     zwei 2×1-Blöcke, ein L und eine Krone. Ist der Herausforderer drin, schließt sich eine Lichtwand entlang des Rands
##     (die Lücken zuletzt): nicht durchschreitbar, sie hält Geschosse in beide Richtungen auf.
##  3. Nach dem Duell (und der Bergung des Herausforderers): Lichtwand aus, Brakk steht am Myriaden-HQ, die Wälle des
##     Platzes steigen in den Himmel, und was vorher dort stand, fällt wieder an seinen Platz – im alten Zustand.
## Der Platz liegt nie über dem Schild des Technoclan-HQ, der Myriaden-Zone oder dem Ringterminal. Unabhängig von der
## Kartengröße. Kind von NemesisHerausforderer; Order24.lichtwand_schnitt fragt hierher.

const STAUB := Color(0.62, 0.52, 0.38)
const ERDE := Color(0.55, 0.45, 0.32)
const FABRIK_FARBE := Color(0.42, 0.4, 0.48)
const SEITEN := ["oben", "unten", "links", "rechts"]
## Was die Karte je Feld weiß (gemerkt und zurückgeschrieben; Truppen auf Posten gehören nicht dazu)
const KARTE_SPEICHER := ["feld", "fest", "leben", "ausbau", "turm_art", "werkschutz_zahl", "turm_stufe", "turm_faehigkeit",
	"mg_stufe", "mg_wahl", "batterie_stufe_neu", "batterie_schuss", "batterie_blick", "generator_paar", "magnet_richtung",
	"panzer", "stuetzen", "stuetze_von", "turm_schaden", "fabrik_typ", "fabrik_stufe", "paar", "ausgefallen", "fortschritt"]
## … und Befehl 24 je Feld (Fabriken draußen, Sabotage, Turmkerne, gesprengte Wälle, die nachgebaut werden)
const O24_SPEICHER := ["gesprengt", "kern", "kern_aus", "fabrik_hp", "rueckseite", "routen", "lahm", "_lager_namen", "_alarm_zuletzt"]

var o24: Order24
var spiel: Node
var karte: Karte
var zustand := "aus"             # "aus", "aufbau" (Räumen, Wälle fallen, Duell), "wartet" (Bergung), "rueck" (Wiederaufbau)
var mitte := Karte.KEINE          # Mittelzelle (Feld (0, 0) der Tabelle)
var rechteck := Rect2()           # Bildpunkte: Außenkante des Rands
var gesetzt: Array[Vector2i] = [] # die Wälle des Platzes, in der Reihenfolge des Aufschlags
var gespeichert: Array = []       # was vorher im Bereich stand: je {"z", "karte": {Name: Wert}, "o24": {…}, "fabrik": Dictionary|null}
var licht := 0.0                  # 0..1 Lichtwand schließt sich; 1 = zu, sie hält auf
var protokoll: Array = []         # Prüfung: {"was", "bei", …}
var _plan: Array = []             # fällt: {"z", "start", "eintrag"} – start: Sekunden ab _t, dann wächst der Schatten 0,5 s
var _fallend: Dictionary = {}     # Zelle -> [Kasten, Schatten] (3D)
var _raeumen: Array = []          # noch zu räumende Einträge aus `gespeichert`
var _steigen: Array[Vector2i] = []# Wälle des Platzes, die noch aufsteigen
var _t := 0.0
var _takt := 0.0
var _licht_an := false
var _licht3d: Array = []          # je Wandstück [MeshInstance3D, gehört zu einer Lücke]
var _brakk_gut := {}              # letzte Lage Brakks innerhalb der Lichtwand
var _warte_auf: Einheit = null    # der Herausforderer, solange er auf die Bergung wartet
var _warte_t := 0.0
var _zum_hq := true               # nach dem Duell: Brakk ans Myriaden-HQ


func einrichten(p_o24: Order24) -> void:
	o24 = p_o24
	spiel = o24.spiel
	karte = o24.karte
	process_priority = 100   # nach der Ego-Sicht: erst bewegt sie Brakk, dann hält ihn die Lichtwand


## Steht der Platz (Räumen, fallende Wälle, Duell, Bergung)?
func aktiv() -> bool:
	return zustand == "aufbau" or zustand == "wartet"


## Ist die Lichtwand zu (hält sie Brakk und Geschosse auf)?
func zu() -> bool:
	return aktiv() and licht >= 1.0


## Liegt der Punkt (Bildpunkte) im Platz?
func innen_px(p: Vector2) -> bool:
	return aktiv() and rechteck.has_point(p)


## Liegt das Feld im Platz (Rand eingeschlossen)?
func innen(z: Vector2i) -> bool:
	return aktiv() and innen_px(karte.mitte(z))


## Liegt das Feld innerhalb des Rands (der Rand selbst nicht)?
func im_innern(z: Vector2i) -> bool:
	var h := _halb()
	return aktiv() and z.x > mitte.x - h.x and z.x < mitte.x + h.x - 1 and z.y > mitte.y - h.y and z.y < mitte.y + h.y - 1


## Ist das Feld einer der festen Wälle innen (KAMPFPLATZ_INNEN)?
func ist_krone(z: Vector2i) -> bool:
	return aktiv() and Werte.KAMPFPLATZ_INNEN.has(z - mitte)


# ------------------------------------------------------------------ Form (relativ zur Mitte)

static func _halb() -> Vector2i:
	return Werte.KAMPFPLATZ_GROESSE / 2


## Die Randfelder einer Seite ohne ihre Lücke, entlang der Seite. Oben und unten gehören die Ecken dazu.
static func seite(name: String) -> Array[Vector2i]:
	var h := _halb()
	var aus: Array[Vector2i] = []
	match name:
		"oben", "unten":
			var y := -h.y if name == "oben" else h.y - 1
			for x in range(-h.x, h.x):
				if not ist_luecke(Vector2i(x, y)):
					aus.append(Vector2i(x, y))
		"links", "rechts":
			var x := -h.x if name == "links" else h.x - 1
			for y in range(-h.y + 1, h.y - 1):
				if not ist_luecke(Vector2i(x, y)):
					aus.append(Vector2i(x, y))
	return aus


## Lückenfelder einer Seite (KAMPFPLATZ_LUECKE breit, mittig).
static func luecke(name: String) -> Array[Vector2i]:
	var h := _halb()
	var aus: Array[Vector2i] = []
	for i in Werte.KAMPFPLATZ_LUECKE:
		var q := i - Werte.KAMPFPLATZ_LUECKE / 2
		match name:
			"oben":
				aus.append(Vector2i(q, -h.y))
			"unten":
				aus.append(Vector2i(q, h.y - 1))
			"links":
				aus.append(Vector2i(-h.x, q))
			"rechts":
				aus.append(Vector2i(h.x - 1, q))
	return aus


static func ist_luecke(r: Vector2i) -> bool:
	for s: String in SEITEN:
		if luecke(s).has(r):
			return true
	return false


## Wohin es von dieser Seite nach außen geht.
static func aussen(name: String) -> Vector2i:
	return {"oben": Vector2i(0, -1), "unten": Vector2i(0, 1), "links": Vector2i(-1, 0), "rechts": Vector2i(1, 0)}[name]


## Reihenfolge des Aufschlags: der Rand, je Takt einer von jeder Seite, dann das Muster innen.
static func fallplan() -> Array[Vector2i]:
	var aus: Array[Vector2i] = []
	var seiten: Array = SEITEN.map(func(s: String) -> Array[Vector2i]: return seite(s))
	var laengste := 0
	for s: Array in seiten:
		laengste = maxi(laengste, s.size())
	for i in laengste:
		for s: Array in seiten:
			if i < s.size():
				aus.append(s[i] as Vector2i)
	aus.append_array(Werte.KAMPFPLATZ_INNEN)
	return aus


# ------------------------------------------------------------------ Lage

## Alle Felder des Bereichs um `m`: der Platz und KAMPFPLATZ_ABSTAND Felder darum.
func _bereich(m: Vector2i) -> Rect2i:
	var a := Werte.KAMPFPLATZ_ABSTAND
	return Rect2i(m - _halb() - Vector2i(a, a), Werte.KAMPFPLATZ_GROESSE + Vector2i(2 * a, 2 * a))


## Darf der Platz um `m` liegen? Ganz auf der Karte; im Bereich weder der Schild des Technoclan-HQ noch die Myriaden-Zone
## noch das Ringterminal. Alles andere wird für die Dauer des Duells weggeräumt.
func platz_ok(m: Vector2i) -> bool:
	var h := _halb()
	if not karte.in_karte(m - h) or not karte.in_karte(m + h - Vector2i.ONE):
		return false
	var b := _bereich(m)
	for y in range(b.position.y, b.end.y):
		for x in range(b.position.x, b.end.x):
			var z := Vector2i(x, y)
			if x < Werte.ZONE_SPALTEN or karte.ist_basis(z) or o24._im_schild(karte.mitte(z)) or o24._terminal_feld(z):
				return false
	return true


## Mitte suchen: Brakks Feld, sonst in Spiralen (Ring um Ring, im Ring das nächste zuerst). KEINE = nirgends.
## E7 (26.11., Paul): Auf der großen Karte liegt die Mitte bevorzugt im Niemandsland (dort, so nah an Brakk wie möglich);
## erst wenn dort nichts passt, irgendwo. Zufluchten und Außenposten dürfen im Platz liegen (Paul: „darf überlappen“).
func mitte_suchen(von: Vector2i) -> Vector2i:
	if bool(o24.w("gebiete")):
		var m := _spirale(von, func(z: Vector2i) -> bool: return BrakkGebiete.gebiet(z) == "niemandsland")
		if m != Karte.KEINE:
			return m
	return _spirale(von, func(_z: Vector2i) -> bool: return true)


func _spirale(von: Vector2i, wunsch: Callable) -> Vector2i:
	var weit := maxi(Werte.SPALTEN, Werte.ZEILEN)
	for r in weit + 1:
		var ring: Array[Vector2i] = []
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) == r:
					ring.append(Vector2i(dx, dy))
		ring.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.length_squared() < b.length_squared())
		for d: Vector2i in ring:
			if wunsch.call(von + d) and platz_ok(von + d):
				return von + d
	return Karte.KEINE


# ------------------------------------------------------------------ Aufbau

## Kurz nach der Ansage: Platz bestimmen, merken und räumen; die Wälle fallen ab KAMPFPLATZ_FALL_VERZUG nach der Ansage.
## false = kein Platz (dann kämpft er ohne Kampfplatz).
func aufbauen(brakk_zelle: Vector2i) -> bool:
	var m := mitte_suchen(brakk_zelle)
	protokoll.append({"was": "aufbau", "bei": o24.zeit, "mitte": m, "brakk": brakk_zelle})
	if m == Karte.KEINE:
		return false
	mitte = m
	rechteck = Rect2(karte.position + Vector2(m - _halb()) * Werte.ZELLE, Vector2(Werte.KAMPFPLATZ_GROESSE) * Werte.ZELLE)
	zustand = "aufbau"
	gesetzt.clear()
	_plan.clear()
	_steigen.clear()
	_t = 0.0
	_takt = 0.0
	licht = 0.0
	_licht_an = false
	_brakk_gut = {}
	_merken()
	_raeumen = gespeichert.duplicate()
	var start := Werte.KAMPFPLATZ_FALL_VERZUG - Werte.KAMPFPLATZ_RAEUM_VERZUG
	var i := 0
	for r: Vector2i in fallplan():
		_plan.append({"z": m + r, "start": start + float(i / Werte.KAMPFPLATZ_FALL_JE) * Werte.KAMPFPLATZ_FALL_TAKT})
		i += 1
	_truppen_raus(true)
	protokoll.append({"was": "gemerkt", "bei": o24.zeit, "felder": gespeichert.size()})
	return true


## Merkt sich alles im Bereich, was die Karte und Befehl 24 je Feld wissen.
func _merken() -> void:
	gespeichert.clear()
	var b := _bereich(mitte)
	var felder := {}
	for z: Vector2i in karte.feld.keys() + o24.gesprengt.keys():
		if b.has_point(z):
			felder[z] = true
	for z: Vector2i in felder:
		var e := {"z": z, "karte": {}, "o24": {}, "fabrik": spiel.fabriken.get(z, null)}
		for name: String in KARTE_SPEICHER:
			var d: Dictionary = karte.get(name)
			if d.has(z):
				e["karte"][name] = d[z]
		for name: String in O24_SPEICHER:
			var d: Dictionary = o24.get(name)
			if d.has(z):
				e["o24"][name] = d[z]
		gespeichert.append(e)
	# von West nach Ost, damit das Verschwinden und Zurückfallen als Welle läuft
	gespeichert.sort_custom(func(a: Dictionary, c: Dictionary) -> bool: return (a["z"] as Vector2i).x < (c["z"] as Vector2i).x or ((a["z"] as Vector2i).x == (c["z"] as Vector2i).x and (a["z"] as Vector2i).y < (c["z"] as Vector2i).y))


## Ein Feld verschwindet mit Beam: von der Karte und aus Befehl 24 (der Eintrag bleibt in `gespeichert`).
func _raeume(e: Dictionary, bild: bool) -> void:
	var z: Vector2i = e["z"]
	var k: Kommandant = spiel.kommandant
	var auf: Variant = karte.posten.get(z, null)
	if auf != null and is_instance_valid(auf) and auf != k:
		(auf as Einheit).posten_zelle = Karte.KEINE
		(auf as Einheit).zustand = Einheit.Zustand.BODEN
	if k != null and k.oben and k.posten_zelle == z:
		k.oben = false   # Brakk stand oben: er fällt
		k.posten_zelle = Karte.KEINE
		k.zustand = Einheit.Zustand.BODEN
	for name: String in O24_SPEICHER:
		(o24.get(name) as Dictionary).erase(z)
	spiel.fabriken.erase(z)
	if karte.feld.has(z):
		karte.entferne(z)
	for name: String in KARTE_SPEICHER:
		(karte.get(name) as Dictionary).erase(z)
	if bild:
		_beam_bild(karte.mitte(z), karte.inhalt(z) == Karte.FABRIK or e["fabrik"] != null)


## Ein gemerktes Feld fällt zurück: alles, was die Karte und Befehl 24 dazu wussten, im alten Zustand.
func _zurueck(e: Dictionary) -> void:
	var z: Vector2i = e["z"]
	for x: Variant in spiel.einheiten.duplicate():
		if is_instance_valid(x) and x != spiel.kommandant and karte.zelle_bei((x as Einheit).position) == z:
			(x as Einheit).position = karte.mitte(o24._freies_feld_bei(karte.mitte(z), z))
	var kd: Dictionary = e["karte"]
	for name: String in kd:
		(karte.get(name) as Dictionary)[z] = kd[name]
	for name: String in ["paar", "generator_paar"]:   # Paare in beide Richtungen
		if kd.has(name):
			(karte.get(name) as Dictionary)[kd[name]] = z
	var od: Dictionary = e["o24"]
	for name: String in od:
		(o24.get(name) as Dictionary)[z] = od[name]
	if e["fabrik"] != null:
		var f: Dictionary = e["fabrik"]
		f["einheiten"] = (f.get("einheiten", []) as Array).filter(func(x: Variant) -> bool: return is_instance_valid(x))
		spiel.fabriken[z] = f
	karte._gewichte_fuer(z)
	if kd.has("feld"):
		var p := karte.mitte(z)
		spiel.effekte.flaeche(p, Werte.ZELLE * 0.8, STAUB)
		Ton.am_ort(spiel, "tf-earth", p)
		_ruetteln(p, 0.05)


## Ersatz für einen gesprengten Wall: fällt nach `nach_sek` (Aufschlag).
func ersatz(z: Vector2i, nach_sek: float) -> void:
	if aktiv():
		_plan.append({"z": z, "start": _t + nach_sek - Werte.KAMPFPLATZ_SCHATTEN_SEK})


## C2: Ein Wall fällt nach `nach_sek` vom Himmel (wie die Wälle des Platzes, verschwindet mit ihm); nach dem Aufschlag
## `danach(z)` – dort wird z. B. eine Stellung daraus. Liegt dort schon etwas, fällt er nicht.
func abwerfen(z: Vector2i, nach_sek: float, danach: Callable) -> void:
	if aktiv():
		_plan.append({"z": z, "start": _t + nach_sek - Werte.KAMPFPLATZ_SCHATTEN_SEK, "danach": danach})


## Der Herausforderer sprengt einen Randwall: weg ist er, mit Knall (wie Brakks Ladung, ohne Prämie). Ersatz nach
## KAMPFPLATZ_ERSATZ_SEK.
func sprengen(z: Vector2i) -> void:
	if karte.inhalt(z) == Karte.WALL:
		karte.entferne(z)
	gesetzt.erase(z)
	var p := karte.mitte(z)
	spiel.effekte.flaeche(p, Werte.ZELLE * 1.3, Color("ff9a3d"))
	if Werte.grafik_neu:
		spiel.effekte.fx("g_tod", p + Vector2(0, 16), 1.0)
	Ton.am_ort(spiel, "hit-boom", p)
	Ton.am_ort(spiel, "tf-stone", p)
	o24._explosion3d(z)
	_ruetteln(p, 0.35)
	protokoll.append({"was": "gesprengt", "bei": o24.zeit, "z": z})
	ersatz(z, Werte.KAMPFPLATZ_ERSATZ_SEK)


## Die Lichtwand beginnt sich zu schließen.
func licht_an() -> void:
	if not aktiv() or _licht_an:
		return
	_licht_an = true
	licht = 0.0
	_licht3d_bauen()
	Ton.spiele(spiel, "tc-arc", 2.0)
	protokoll.append({"was": "licht_an", "bei": o24.zeit})


## Duell vorbei. `geborgen_wird`: der Herausforderer liegt – erst nach seiner Bergung (oder [E]) geht es zurück.
## `art`: "hq" (Brakk ans Myriaden-HQ), "bleibt" (Brakk bleibt stehen), "sofort" (ohne Bilder und Wartezeit – Brakk ist
## gefallen, der Lauf ist vorbei).
func aufloesen(geborgen_wird: Einheit = null, art: String = "hq") -> void:
	if not aktiv():
		return
	protokoll.append({"was": "aufloesen", "bei": o24.zeit, "art": art})
	_zum_hq = art == "hq"
	if art == "sofort":
		_rueck_starten(false)
		for z: Vector2i in _steigen:
			if karte.inhalt(z) == Karte.WALL:
				karte.entferne(z)
		_steigen.clear()
		for f: Dictionary in _plan:
			if f.has("eintrag"):
				_zurueck(f["eintrag"] as Dictionary)
		_fertig()
		return
	_warte_auf = geborgen_wird
	_warte_t = 0.0
	zustand = "wartet"


## Zurück zur normalen Karte: Lichtwand aus, Brakk an das Myriaden-HQ (mit dem Ring des Herausforderers), die Wälle des
## Platzes steigen auf, dann fällt, was vorher dort stand.
func _rueck_starten(beam: bool) -> void:
	zustand = "rueck"
	_licht_an = false
	licht = 0.0
	for l: Array in _licht3d:
		if is_instance_valid(l[0]):
			(l[0] as Node).queue_free()
	_licht3d.clear()
	for z: Vector2i in _fallend.keys():
		_fallend_weg(z, false)
	_raeumen.clear()
	_plan.clear()
	_steigen = gesetzt.duplicate()
	_steigen.reverse()
	gesetzt.clear()
	_t = 0.0
	_takt = 0.0
	var steig_dauer := float(_steigen.size()) * Werte.KAMPFPLATZ_STEIG_TAKT
	var i := 0
	for e: Dictionary in gespeichert:
		if (e["karte"] as Dictionary).has("feld") or e["fabrik"] != null:
			_plan.append({"z": e["z"], "start": steig_dauer + float(i / Werte.KAMPFPLATZ_FALL_JE) * Werte.KAMPFPLATZ_FALL_TAKT, "eintrag": e})
			i += 1
		else:
			_zurueck(e)   # nur Daten (z. B. ein gesprengter Wall, der nachgebaut wird)
	var k: Kommandant = spiel.kommandant
	if beam and k != null and not k.gefallen:
		var ziel := o24._freies_feld_bei(o24.hq_mitte() + Vector2(2.0 * Werte.ZELLE, 0.0), karte.zelle_bei(o24.hq_mitte()))
		_brakk_versetzen(karte.mitte(ziel), true)
		spiel.melde(tr("Sonde 7: „Zurück zum HQ. Der Technoclan baut wieder auf.“"), 3.5)
		for b: Dictionary in o24.beute_boden:
			if bool(b.get("herausforderer", false)):
				b["pos"] = karte.mitte(o24._freies_feld_bei(karte.mitte(ziel) + Vector2(Werte.ZELLE, 0.0), ziel))
				o24._beute_bild_weg(b)   # wird am neuen Ort neu gebaut
	protokoll.append({"was": "rueck", "bei": o24.zeit, "steigen": _steigen.size(), "zurueck": _plan.size()})


func _fertig() -> void:
	zustand = "aus"
	gespeichert.clear()
	_plan.clear()
	_warte_auf = null
	karte.pruefe_stuetzen()
	karte.aktualisiere_pfad()
	protokoll.append({"was": "aufgeloest", "bei": o24.zeit})


# ------------------------------------------------------------------ Ablauf

func _physics_process(_takt_sek: float) -> void:
	if zustand == "aus" or o24 == null or not o24.laeuft or spiel.phase != 1:
		return
	schritt(Werte.sim_schritt() / (Werte.SPIELTEMPO * Werte.BRAKK_TEMPO))   # echte Sekunden wie der Herausforderer


## Ein Schritt (`dt` in echten Sekunden; auch für den Test).
func schritt(dt: float) -> void:
	_t += dt
	match zustand:
		"aufbau":
			_takt -= dt
			while not _raeumen.is_empty() and (_takt <= 0.0 or _t >= Werte.KAMPFPLATZ_FALL_VERZUG - Werte.KAMPFPLATZ_RAEUM_VERZUG):
				_takt += Werte.KAMPFPLATZ_RAEUM_TAKT
				_raeume(_raeumen.pop_front() as Dictionary, true)
				if _raeumen.is_empty():
					karte.aktualisiere_pfad()
		"wartet":
			_warte_t += dt
			var liegt := _warte_auf != null and is_instance_valid(_warte_auf) and o24.nemesis.kampfunfaehig.any(func(k: Dictionary) -> bool: return k["einheit"] == _warte_auf)
			if not liegt or _warte_t >= Werte.KAMPFPLATZ_BERGUNG_MAX:
				_rueck_starten(_zum_hq)
			return
		"rueck":
			_takt -= dt
			while not _steigen.is_empty() and _takt <= 0.0:
				_takt += Werte.KAMPFPLATZ_STEIG_TAKT
				_steige(_steigen.pop_front())
	var noch: Array = []
	var zurueck := false
	for f: Dictionary in _plan:
		var z: Vector2i = f["z"]
		var s := _t - float(f["start"])
		if s >= Werte.KAMPFPLATZ_SCHATTEN_SEK:
			_fallend_weg(z, true)
			if f.has("eintrag"):
				_zurueck(f["eintrag"] as Dictionary)
				zurueck = true
			else:
				if _lande(z) and f.has("danach") and (f["danach"] as Callable).is_valid():
					(f["danach"] as Callable).call(z)   # C2: Stellung oder Bunker
		else:
			if s >= 0.0:
				_fallen_bild(z, s / Werte.KAMPFPLATZ_SCHATTEN_SEK, f.has("eintrag") and (f["eintrag"] as Dictionary)["fabrik"] != null)
			noch.append(f)
	_plan = noch
	if zurueck:
		karte.pruefe_stuetzen()
		karte.aktualisiere_pfad()   # die Wege kennen die zurückgefallenen Blöcke sofort
	if zustand == "rueck":
		if _plan.is_empty() and _steigen.is_empty():
			_fertig()
		return
	if _licht_an and licht < 1.0:
		licht = minf(1.0, licht + dt / Werte.KAMPFPLATZ_LICHT_SEK)
		_licht3d_setzen()
		if licht >= 1.0:
			protokoll.append({"was": "licht_zu", "bei": o24.zeit})
			_brakk_hinein()
	if zu():
		_truppen_raus(false)


func _process(_delta: float) -> void:
	if zu():
		_brakk_halten()


## Ein Wall des Platzes schlägt auf. Liegt dort etwas (Fels, Wasser), bleibt es.
func _lande(z: Vector2i) -> bool:
	if not karte.ist_frei(z):
		return false
	var p := karte.mitte(z)
	var k: Kommandant = spiel.kommandant
	if k != null and not k.gefallen and karte.zelle_bei(_fuss()) == z:
		_brakk_versetzen(karte.mitte(_frei_innen(z)), false)
	for x: Variant in spiel.einheiten.duplicate():
		if is_instance_valid(x) and x != k and karte.zelle_bei((x as Einheit).position) == z:
			_raus(x as Einheit, false)
	karte.setze(z, Karte.WALL)
	gesetzt.append(z)
	spiel.effekte.flaeche(p, Werte.ZELLE * 0.8, STAUB)
	Ton.am_ort(spiel, "tf-earth", p)
	_ruetteln(p, 0.08)
	return true


## Ein Wall des Platzes steigt in den Himmel.
func _steige(z: Vector2i) -> void:
	if karte.inhalt(z) != Karte.WALL:
		return
	karte.entferne(z)
	spiel.effekte.flaeche(karte.mitte(z), Werte.ZELLE * 0.6, STAUB)
	var hd: HdAnsicht = spiel.hd
	if hd == null:
		return
	var kasten := _kasten(hd, ERDE)
	kasten.position = _zu3d(karte.mitte(z), hd.H * 0.5)
	var tw := kasten.create_tween()
	tw.tween_property(kasten, "position:y", Werte.KAMPFPLATZ_FALL_HOEHE, 0.5).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tw.tween_callback(kasten.queue_free)


# ------------------------------------------------------------------ Brakk und die Truppen

func _fuss() -> Vector2:
	if spiel.ego != null:
		return spiel.ego._fuss2d()
	return (spiel.kommandant as Kommandant).position


## Die Lichtwand ist zu: Steht Brakk draußen, schiebt sie ihn an der nächsten Lücke hinein.
func _brakk_hinein() -> void:
	var k: Kommandant = spiel.kommandant
	if k == null or k.gefallen or innen_px(_fuss()):
		return
	var beste := Karte.KEINE
	var weit := INF
	for s: String in SEITEN:
		for r: Vector2i in luecke(s):
			var z := mitte + r - aussen(s)   # ein Feld hinter der Lücke
			var d := karte.mitte(z).distance_to(_fuss())
			if d < weit and karte.ist_begehbar(z) and karte.ist_frei(z):
				weit = d
				beste = z
	if beste == Karte.KEINE:
		beste = _frei_innen(mitte)
	_brakk_versetzen(karte.mitte(beste), true)
	spiel.melde(tr("Die Lichtwand schiebt dich hinein."), 2.5)
	protokoll.append({"was": "brakk_hinein", "bei": o24.zeit, "z": beste})


## Brakk auf `p` (Bildpunkte, am Boden) – laufende Sprünge, Seile und Flüge enden.
func _brakk_versetzen(p: Vector2, beam: bool) -> void:
	var k: Kommandant = spiel.kommandant
	var ego: EgoModus = spiel.ego
	if beam:
		spiel.effekte.flaeche(_fuss(), Werte.ZELLE * 0.8, Order24.TECHNO_FARBE)
	k.oben = false
	k.posten_zelle = Karte.KEINE
	k.zustand = Einheit.Zustand.BODEN
	if ego != null:
		ego._tumble = -1.0
		ego._absprung = -1.0
		ego._flug = Vector2.ZERO
		if ego._anker >= 0.0:
			ego._anker = 1000.0   # endet im nächsten Bild
		ego.hoehe = 0.0
		ego.steig = 0.0
		ego._setze_fuss(p)
	else:
		k.position = p
	if beam:
		spiel.effekte.flaeche(p, Werte.ZELLE * 0.8, Order24.TECHNO_FARBE)
		Ton.spiele(spiel, "tc-arc", -2.0)
	_brakk_gut = {}


## Hält Brakk innerhalb: Wer hinaus will (Sprung von der Mauer, Seil, Absprung …), steht wieder dort, wo er zuletzt drin war.
func _brakk_halten() -> void:
	var k: Kommandant = spiel.kommandant
	if k == null or k.gefallen:
		return
	var ego: EgoModus = spiel.ego
	if innen_px(_fuss()):
		_brakk_gut = {"pos": k.position, "oben": k.oben, "posten": k.posten_zelle, "zustand": k.zustand, "hoehe": ego.hoehe if ego != null else 0.0}
		return
	if _brakk_gut.is_empty():
		_brakk_hinein()
		return
	k.position = _brakk_gut["pos"]
	k.oben = bool(_brakk_gut["oben"])
	k.posten_zelle = _brakk_gut["posten"]
	k.zustand = _brakk_gut["zustand"]
	k.anker = k.position
	if ego != null:
		ego.hoehe = float(_brakk_gut["hoehe"])
		ego._flug = Vector2.ZERO
	protokoll.append({"was": "brakk_gehalten", "bei": o24.zeit})


## Ein freies Feld im Platz nahe `z` (nach innen), sonst die Mitte.
func _frei_innen(z: Vector2i) -> Vector2i:
	var beste := mitte
	var weit := INF
	var h := _halb()
	for y in range(mitte.y - h.y + 1, mitte.y + h.y - 1):
		for x in range(mitte.x - h.x + 1, mitte.x + h.x - 1):
			var c := Vector2i(x, y)
			if c != z and karte.ist_begehbar(c) and karte.ist_frei(c) and Vector2(c - z).length() < weit:
				weit = Vector2(c - z).length()
				beste = c
	return beste


## Truppen im Platz an den Rand (draußen). `alle`: beim Aufbau mit Beam – sonst nur, wer sich durch die Lichtwand drängt.
func _truppen_raus(alle: bool) -> void:
	var her: Variant = o24.herausforderer.einheit if o24.herausforderer != null else null
	for x: Variant in spiel.einheiten.duplicate():
		if not is_instance_valid(x) or x == spiel.kommandant or x == her:
			continue
		var e := x as Einheit
		if e.has_meta("kampfplatz_erlaubt") or e.kampfunfaehig:
			continue
		if rechteck.grow(Werte.ZELLE * 0.5).has_point(e.position):
			_raus(e, alle)


## Eine Truppe nach draußen, aufs nächste freie Feld vor dem Rand.
func _raus(e: Einheit, beam: bool) -> void:
	var p := e.position
	var r := rechteck.grow(Werte.ZELLE)
	var ziele := [Vector2(r.position.x, p.y), Vector2(r.end.x, p.y), Vector2(p.x, r.position.y), Vector2(p.x, r.end.y)]
	ziele = ziele.filter(func(q: Vector2) -> bool: return karte.in_karte(karte.zelle_bei(q)))
	if ziele.is_empty():
		return
	ziele.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.distance_to(p) < b.distance_to(p))
	var ziel := karte.zelle_bei(ziele[0] as Vector2)
	var z := o24._freies_feld_bei(karte.mitte(ziel), ziel)
	if rechteck.has_point(karte.mitte(z)):
		z = ziel
	if beam:
		spiel.effekte.flaeche(e.position, Werte.ZELLE * 0.6, Order24.TECHNO_FARBE)
	if e.posten_zelle != Karte.KEINE and karte.posten.get(e.posten_zelle) == e:
		karte.posten.erase(e.posten_zelle)
	e.posten_zelle = Karte.KEINE
	e.zustand = Einheit.Zustand.BODEN
	e._punkte.clear()
	e.position = karte.mitte(z)
	if beam:
		spiel.effekte.flaeche(e.position, Werte.ZELLE * 0.6, Order24.TECHNO_FARBE)


# ------------------------------------------------------------------ Lichtwand: Schnitt

## Trennt die Lichtwand die Strecke a → b (Bildpunkte)? Dann der Punkt an der Wand, sonst INF. Der Punkt liegt ein halbes
## Feld vor der Wand (auf der Seite von a): Wer drüben direkt an der Wand steht, wird von Schuss und Strahl nicht gestreift.
func schnitt(a: Vector2, b: Vector2) -> Vector2:
	if not zu() or (rechteck.has_point(a) and rechteck.has_point(b)):
		return Vector2.INF   # beide drin: die Strecke bleibt drin (beide draußen: sie kann quer hindurch gehen)
	var ecken := [rechteck.position, Vector2(rechteck.end.x, rechteck.position.y), rechteck.end, Vector2(rechteck.position.x, rechteck.end.y)]
	var beste := Vector2.INF
	for i in 4:
		var t: Variant = Geometry2D.segment_intersects_segment(a, b, ecken[i], ecken[(i + 1) % 4])
		if t != null and (beste == Vector2.INF or a.distance_to(t as Vector2) < a.distance_to(beste)):
			beste = t
	if beste == Vector2.INF:
		return beste
	return beste.move_toward(a, minf(0.5 * Werte.ZELLE, a.distance_to(beste)))


# ------------------------------------------------------------------ Bilder

func _zu3d(p: Vector2, h: float) -> Vector3:
	return Vector3(p.x / Werte.ZELLE, h, (p.y - Werte.KARTE_OBEN) / Werte.ZELLE)


func _kasten(hd: HdAnsicht, farbe: Color) -> MeshInstance3D:
	var kasten := o24._kasten3d(hd, Vector3(1.0, hd.H, 1.0), farbe, Vector3.ZERO)
	var stoff := kasten.material_override as StandardMaterial3D
	stoff.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	stoff.emission_enabled = false
	stoff.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
	return kasten


## Ein fallender Block: der Kasten stürzt aus KAMPFPLATZ_FALL_HOEHE, sein Schatten am Boden wächst mit (`anteil` 0..1).
func _fallen_bild(z: Vector2i, anteil: float, fabrik: bool) -> void:
	var hd: HdAnsicht = spiel.hd
	if hd == null:
		return
	if not _fallend.has(z):
		var kasten := _kasten(hd, FABRIK_FARBE if fabrik else ERDE)
		var schatten := MeshInstance3D.new()
		var scheibe := CylinderMesh.new()
		scheibe.top_radius = 0.6
		scheibe.bottom_radius = 0.6
		scheibe.height = 0.02
		schatten.mesh = scheibe
		var stoff := StandardMaterial3D.new()
		stoff.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		stoff.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		stoff.albedo_color = Color(0, 0, 0, 0.55)
		schatten.material_override = stoff
		hd.add_child(schatten)
		schatten.position = _zu3d(karte.mitte(z), 0.03)
		_fallend[z] = [kasten, schatten]
	var b: Array = _fallend[z]
	var fall := anteil * anteil   # er wird schneller
	(b[0] as Node3D).position = _zu3d(karte.mitte(z), hd.H * 0.5 + Werte.KAMPFPLATZ_FALL_HOEHE * (1.0 - fall))
	(b[1] as Node3D).scale = Vector3.ONE * maxf(0.05, anteil)


## `stehen`: der Kasten bleibt noch kurz, bis die HD-Ansicht den echten Block gebaut hat (sie prüft alle 0,2 s).
func _fallend_weg(z: Vector2i, stehen: bool) -> void:
	if not _fallend.has(z):
		return
	var b: Array = _fallend[z]
	_fallend.erase(z)
	if is_instance_valid(b[1]):
		(b[1] as Node).queue_free()
	if is_instance_valid(b[0]):
		if stehen:
			var tw := (b[0] as Node).create_tween()
			tw.tween_interval(0.3)
			tw.tween_callback((b[0] as Node).queue_free)
		else:
			(b[0] as Node).queue_free()


## Beim Räumen: eine lila Lichtsäule über dem Feld, der Block darin wird durchsichtig und hebt ab.
func _beam_bild(p: Vector2, fabrik: bool) -> void:
	spiel.effekte.flaeche(p, Werte.ZELLE * 0.7, Order24.TECHNO_FARBE)
	if int(o24.zeit * 10.0) % 3 == 0:
		Ton.am_ort(spiel, "tc-arc", p)
	var hd: HdAnsicht = spiel.hd
	if hd == null:
		return
	var saeule := o24._kasten3d(hd, Vector3(0.9, 6.0, 0.9), Order24.TECHNO_FARBE, _zu3d(p, 3.0))
	var stoff := saeule.material_override as StandardMaterial3D
	stoff.albedo_color.a = 0.45
	var tw := saeule.create_tween()
	tw.tween_property(stoff, "albedo_color:a", 0.0, 0.6)
	tw.tween_callback(saeule.queue_free)
	var kasten := o24._kasten3d(hd, Vector3(1.0, hd.H, 1.0), FABRIK_FARBE if fabrik else ERDE, _zu3d(p, hd.H * 0.5))
	var ks := kasten.material_override as StandardMaterial3D
	ks.emission = Order24.TECHNO_FARBE
	var tk := kasten.create_tween()
	tk.tween_property(kasten, "position:y", hd.H * 0.5 + 1.5, 0.5)
	tk.parallel().tween_property(ks, "albedo_color:a", 0.0, 0.5)
	tk.tween_callback(kasten.queue_free)


## Je Wandstück ein halbdurchsichtiges Band in Schild-Optik. Die Stücke vor den Lücken wachsen in der zweiten Hälfte.
func _licht3d_bauen() -> void:
	var hd: HdAnsicht = spiel.hd
	if hd == null:
		return
	var h := _halb()
	var a := _zu3d(rechteck.position, 0.0)
	var e := _zu3d(rechteck.end, 0.0)
	for s: String in SEITEN:
		# entlang der Seite in Stücken: bis zur Lücke, die Lücke, danach
		var lu := luecke(s)
		var waagrecht := s == "oben" or s == "unten"
		var von := float(-h.x) if waagrecht else float(-h.y)
		var bis := float(h.x) if waagrecht else float(h.y)
		var l0 := float(lu[0].x if waagrecht else lu[0].y)
		var l1 := l0 + float(Werte.KAMPFPLATZ_LUECKE)
		for stueck: Array in [[von, l0, false], [l0, l1, true], [l1, bis, false]]:
			var lang := float(stueck[1]) - float(stueck[0])
			var mi := float(stueck[0]) + lang * 0.5
			var groesse := Vector3(lang, Werte.KAMPFPLATZ_LICHT_HOEHE, 0.06) if waagrecht else Vector3(0.06, Werte.KAMPFPLATZ_LICHT_HOEHE, lang)
			var pos := Vector3.ZERO
			match s:
				"oben":
					pos = Vector3(float(mitte.x) + mi, 0.0, a.z)
				"unten":
					pos = Vector3(float(mitte.x) + mi, 0.0, e.z)
				"links":
					pos = Vector3(a.x, 0.0, float(mitte.y) + mi)
				"rechts":
					pos = Vector3(e.x, 0.0, float(mitte.y) + mi)
			var band := o24._kasten3d(hd, groesse, Order24.TECHNO_FARBE, pos)
			(band.material_override as StandardMaterial3D).albedo_color.a = Werte.KAMPFPLATZ_LICHT_ALPHA
			band.scale = Vector3(1.0, 0.001, 1.0)
			_licht3d.append([band, bool(stueck[2])])
	_licht3d_setzen()


func _licht3d_setzen() -> void:
	for l: Array in _licht3d:
		var band := l[0] as MeshInstance3D
		if not is_instance_valid(band):
			continue
		var f := clampf((licht - 0.5) * 2.0, 0.0, 1.0) if bool(l[1]) else clampf(licht * 2.0, 0.0, 1.0)
		f = f * f * (3.0 - 2.0 * f)
		band.scale = Vector3(1.0, maxf(0.001, f), 1.0)
		band.position.y = Werte.KAMPFPLATZ_LICHT_HOEHE * 0.5 * f


func _ruetteln(p: Vector2, menge: float) -> void:
	if spiel.ego != null and p.distance_to(_fuss()) < 8.0 * Werte.ZELLE:
		spiel.ego._trauma = minf(1.0, spiel.ego._trauma + menge)


func _exit_tree() -> void:
	for z: Vector2i in _fallend.keys():
		_fallend_weg(z, false)
