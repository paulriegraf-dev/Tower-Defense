class_name EgoSonde
extends EgoKit
## 20.11.: Schritt 6b – Kit von Sonde 7 im Brakk-Mode: Luft und Schützin. Alle Zahlen in Werte.SONDE7, Belegung in
## Werte.ANFUEHRER_EGO (Leertaste halten schweben, loslassen sinken, doppelt fallen lassen · Shift Schub · Q Teleport ·
## E Doppel-Lasergewehr · V Schrotflinte · X Sondengewehr · R Luftschlag · C Ringfeld wie bei Brakk).
## Hand: links Farblaser (Dauerstrahl mit Hitze), rechts Energiebündel. Ring-Signatur: der aktive Ring färbt Hand und
## Erfassungstreffer. Waffen- und Handbilder sind Platzhalter aus Code (unten im Bild).

const Stil := preload("res://scripts/ui/ui_stil.gd")
const SONDE_FARBE := Color("6ee6ff")
const GRANATE_SCHWERE := 9.0

var akku := 5.0
var _fallen_lassen := false      # doppelt Leertaste: frei fallen bis zum Boden
var _tipp_ms := -100000
var _schub := -1.0               # läuft: Sekunden seit Beginn
var _schub_r := Vector2.ZERO
var _schub_rest := 0.0
var _tele_rest := 0.0
var waffe := ""                  # "" = Hand
var magazin := 0
var cd := {}                     # Waffe -> Rest-Cooldown
var _luft_welle := -1
var _luft_bis := 0
var _links := false
var _rechts := false
var _takt_l := 0.0
var _takt_r := 0.0
var _hitze := 0.0
var _sperre := 0.0
var _laden := -1.0               # Sondengewehr lädt (Sekunden)
var _erfasst: Array = []
var _erfasst_bis := 0
var _erfasst_i := 0
var _nachladen := 0.0
var _blick_bis := 0
var _umriss_vorher := true
var _geschosse: Array = []       # {p, v, art, knoten}
var _blitz := 0.0
var _rueck := 0.0
var _strahl: MeshInstance3D = null
var _strahl_bis := Vector3.ZERO
var _strahl_an := false
var _bilder := {}


func _init(p_ego: EgoModus) -> void:
	super(p_ego)
	var d: Dictionary = Werte.SONDE7["schweben"]
	akku = float(d["akku"])


## 20.11. (Paul): Bild der Waffe `w` ("" = Handschuh) mit Leuchtteilen in der Farbe des aktiven Rings.
func _waffenbild(w: String) -> Texture2D:
	var schluessel := w + "|" + ring()
	if not _bilder.has(schluessel):
		var img := _male_waffe(w) if w != "" else _male_handschuh()
		if ring() != "":
			var ziel := ring_farbe()
			for y in img.get_height():
				for x in img.get_width():
					var c := img.get_pixel(x, y)
					if c.a > 0.0 and c.b > 0.85 and c.g > 0.8 and c.r < 0.7:   # die cyanfarbenen Leuchtteile
						img.set_pixel(x, y, ziel.lightened(0.25) if c.r > 0.55 else ziel)
		_bilder[schluessel] = ImageTexture.create_from_image(img)
	return _bilder[schluessel]


func f() -> BrakkFortschritt:
	return ego.brakk.fortschritt


## Aktiver Ring (Mausrad) – färbt Hand und Erfassung.
func ring() -> String:
	return f().aktiv()


func ring_farbe() -> Color:
	return ego._ring_farbe(ring()) if ring() != "" else SONDE_FARBE


func luftschlag_an() -> bool:
	return waffe == "luftschlag" and Time.get_ticks_msec() < _luft_bis


func _w(schluessel: String) -> Dictionary:
	return Werte.SONDE7[schluessel]


# ------------------------------------------------------------------ Aktionen

func aktion(was: String, gedrueckt: bool) -> bool:
	match was:
		"hand_links":
			_links = gedrueckt
			if waffe == "sondengewehr":
				if gedrueckt and _nachladen <= 0.0:
					_laden = 0.0
				elif not gedrueckt:
					if _laden >= _ladezeit():
						_durchschlag()
					_laden = -1.0
			return true
		"hand_rechts":
			_rechts = gedrueckt
			if gedrueckt:
				_rechts_druck()
			return true
		"schweben":
			if gedrueckt:
				var jetzt := Time.get_ticks_msec()
				if jetzt - _tipp_ms <= int(float(_w("schweben")["doppel"]) * 1000.0) and ego.hoehe > ego._boden() + 0.05 and not luftschlag_an():
					_fallen_lassen = true   # doppelt: fallen lassen
				else:
					_fallen_lassen = false
				_tipp_ms = jetzt
			return true
	if not gedrueckt:
		return false
	match was:
		"schub":
			_schub_start()
		"teleport":
			_teleport()
		"doppellaser", "schrot", "sondengewehr", "luftschlag":
			_rufe(was)
		_:
			return false
	return true


func _schub_start() -> void:
	var d := _w("schub")
	if _schub >= 0.0 or _schub_rest > 0.0:
		return
	if akku < float(d["akku"]) * 0.5 and not luftschlag_an():
		ego.spiel.melde("Akku leer – kein Schub.", 1.2)
		return
	if not luftschlag_an():
		akku = maxf(0.0, akku - float(d["akku"]))
	_schub = 0.0
	_schub_rest = float(d["abkling"]) * (1.0 - spell_w("schub", "abkling") / 100.0)   # 20.11. (Nachtrag): Takt-Ring
	_schub_spell()
	# 20.11. (Paul): Schub in die Richtung, in die gerade gelenkt wird (WASD bzw. Stick) – auch zur Seite und nach hinten;
	# ohne Lenkung nach vorn
	var lenk := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_W):
		lenk.y += 1.0
	if Input.is_physical_key_pressed(KEY_S):
		lenk.y -= 1.0
	if Input.is_physical_key_pressed(KEY_D):
		lenk.x += 1.0
	if Input.is_physical_key_pressed(KEY_A):
		lenk.x -= 1.0
	if ego.touch != null:
		lenk += ego.touch.stick()
	var vor := Vector2(ego._vorne().x, ego._vorne().z).normalized()
	var seit := Vector2(ego._rechts().x, ego._rechts().z).normalized()
	_schub_r = vor if lenk.length() < 0.2 else (vor * lenk.y + seit * lenk.x).normalized()
	ego._fov_puls = maxf(ego._fov_puls, 4.0)
	_zaehle("schub")
	Ton.spiele(ego.spiel, "tc-arc", -10.0)


func _teleport() -> void:
	var d := _w("teleport")
	if luftschlag_an():
		ego.spiel.melde("Während des Luftschlags kein Teleport.", 1.5)
		return
	if _tele_rest > 0.0:
		ego.spiel.melde("Teleport wieder in %d s." % ceili(_tele_rest), 1.2)
		return
	var von := ego._fuss2d()
	var p := ego.ziel_welt()
	if p.x < -9000.0:
		p = von + Vector2(ego._vorne().x, ego._vorne().z).normalized() * float(d["weite"]) * Werte.ZELLE
	if p.distance_to(von) > float(d["weite"]) * Werte.ZELLE:
		p = von + (p - von).normalized() * float(d["weite"]) * Werte.ZELLE
	if not ego.spiel.endkampf:
		p.x = maxf(p.x, (float(Werte.ZONE_SPALTEN) + 0.5) * Werte.ZELLE)   # nicht hinter den Schild
	var k := ego.karte
	var z := k.zelle_bei(p)
	# kein Platz? Schritt für Schritt zurück zur Sonde
	var t := 1.0
	while t > 0.0 and not (k.in_karte(z) and (k.ist_begehbar(z) or (ego.hd.ist_hoch(z) and k.inhalt(z) == Karte.WALL))):
		t -= 0.1
		p = von.lerp(p, t / (t + 0.1))
		z = k.zelle_bei(p)
	if t <= 0.0:
		ego.spiel.melde("Dort ist kein Platz.", 1.2)
		return
	ego.spiel.effekte.flaeche(von, Werte.ZELLE * 0.6, ring_farbe())
	var b := ego.brakk
	if ego.hd.ist_hoch(z) and k.inhalt(z) == Karte.WALL:
		b.oben = true
		b.posten_zelle = z
		b.zustand = Einheit.Zustand.AUF_POSTEN
		ego.hoehe = maxf(ego.hoehe, ego.hd.H)
	else:
		b.oben = false
		b.posten_zelle = Karte.KEINE
		b.zustand = Einheit.Zustand.BODEN
	ego._setze_fuss(p)
	ego.spiel.effekte.flaeche(p, Werte.ZELLE * 0.6, ring_farbe())
	_tele_rest = float(d["abkling"]) * (1.0 - spell_w("teleport", "abkling") / 100.0)   # 20.11. (Nachtrag): Takt-Ring
	_teleport_spell(von, p)
	ego._fov_puls = maxf(ego._fov_puls, 8.0)
	ego._trauma = minf(1.0, ego._trauma + 0.15)
	_zaehle("teleport")
	Ton.spiele(ego.spiel, "tc-rail", -10.0)


# ------------------------------------------------------------------ Ring-Wirkung je Spell (20.11., Nachtrag)

var _schub_bremse := 0.0
var _schub_brand := 0.0
var _dauerfeuer := 0.0           # Doppel-Lasergewehr: so lange schon Dauerfeuer (Wirbel-Ring)


## Spells färbt der aktive Ring (Werte.RING_SPELLS).
func spell_ring() -> String:
	return ring()


func schutz() -> float:
	var s := super()
	if luftschlag_an():
		s = maxf(s, spell_w("luftschlag", "schutz") / 100.0)
	return s


func _ladezeit() -> float:
	return float(_w("sondengewehr")["laden"]) / (1.0 + spell_w("sondengewehr", "laden") / 100.0)


func _schub_spell() -> void:
	var w := spell_w("schub", "schutz_nach")
	if w > 0.0:
		schutz_fuer(float(_w("schub")["dauer"]) + 1.0, w / 100.0)
	_schub_bremse = spell_w("schub", "spur_bremse")
	_schub_brand = spell_w("schub", "spur_brand")
	if _schub_brand > 0.0:
		brand_bei(ego._fuss2d(), _schub_brand, float(_w("hand")["buendel_schaden"]) * _sf() * 0.3)


func _teleport_spell(von: Vector2, p: Vector2) -> void:
	var bd := float(_w("hand")["buendel_schaden"]) * _sf()
	var w := spell_w("teleport", "blitz")
	if w > 0.0:
		var erstes: Gegner = ego.spiel.gegner_in_reichweite(p, 2.0 * Werte.ZELLE, true)
		if erstes != null:
			ego._strahl(ego._zu3d(p, 0.6), _mitte3d(erstes), ring_farbe())
			trifft(erstes, bd * 0.5, "ring")
			if is_instance_valid(erstes) and int(w) > 1:
				kette(erstes, int(w) - 1, bd * 0.5)
	w = spell_w("teleport", "bremse_ziel")
	if w > 0.0:
		bremse_umkreis(p, 1.5, w)
	w = spell_w("teleport", "hitzestoss")
	if w > 0.0:
		hitzestoss(von, 1.5, bd * w / 100.0)
	w = spell_w("teleport", "schutz_nach")
	if w > 0.0:
		schutz_fuer(2.0, w / 100.0)
	w = spell_w("teleport", "erfassen")
	if w > 0.0:
		var liste: Array = []
		for g: Gegner in ego.spiel.ego_gegner():
			if is_instance_valid(g) and not g._tot and not ego.spiel._geschuetzt(g) and g.position.distance_to(p) <= 2.0 * Werte.ZELLE:
				liste.append(g)
		liste.sort_custom(func(a: Gegner, b: Gegner) -> bool: return a.position.distance_to(p) < b.position.distance_to(p))
		for g: Gegner in liste.slice(0, int(w)):
			if not _erfasst.has(g):
				_erfasst.append(g)
		if not liste.is_empty():
			_erfasst_bis = Time.get_ticks_msec() + int(float(_w("doppellaser")["erfassen_sek"]) * 1000.0)


## Treffer einer gerufenen Waffe mit der Ring-Wirkung an ihr (Bremse, Glut, Durchschlag).
func _waffen_treffer(g: Gegner, schaden: float, quelle: String, mit_ring: String = "", durch_erlaubt: bool = true) -> void:
	if not is_instance_valid(g) or g._tot:
		return
	var w := waffe if waffe != "" else quelle
	trifft(g, schaden, quelle, mit_ring)
	if not is_instance_valid(g):
		return
	var b := spell_w(w, "bremse_treffer")
	if b > 0.0 and not g._tot:
		g.gebremst = maxf(g.gebremst, b)
	var gl := spell_w(w, "glut")
	if gl > 0.0:
		glut(g, schaden * gl / 100.0, 3.0)
	var du := spell_w(w, "durch")
	if du > 0.0 and durch_erlaubt:
		var h := dahinter(g, ego._fuss2d())
		if h != null:
			ego._strahl(_mitte3d(g), _mitte3d(h), ring_farbe())
			_waffen_treffer(h, schaden * du / 100.0, quelle, mit_ring, false)


## Waffe rufen: volle Ladung; dieselbe Taste nochmal steckt sie weg (Rest verfällt, Cooldown läuft).
func _rufe(w: String) -> void:
	if waffe == w:
		_wegstecken()
		return
	if w == "luftschlag":
		if _luft_welle == int(ego.spiel.welle):
			ego.spiel.melde("Der Luftschlag geht einmal je Runde.", 1.5)
			return
	elif float(cd.get(w, 0.0)) > 0.0:
		ego.spiel.melde("%s wieder in %d s." % [str(Werte.SONDE7_WAFFEN_NAME[w]), ceili(float(cd[w]))], 1.2)
		return
	if waffe != "":
		_wegstecken()
	waffe = w
	magazin = roundi(float(_w(w)["magazin"]) * (1.0 + spell_w(w, "magazin") / 100.0))   # 20.11. (Nachtrag): Takt-Ring
	_laden = -1.0
	_takt_l = 0.0
	_takt_r = 0.0
	_erfasst.clear()
	if w == "luftschlag":
		_luft_welle = int(ego.spiel.welle)
		_luft_bis = Time.get_ticks_msec() + int((float(_w("luftschlag")["sek"]) + spell_w("luftschlag", "dauer")) * 1000.0)   # 20.11. (Nachtrag): Wirbel-Ring
		ego.steig = 0.0
		_fallen_lassen = false
	_zaehle("waffe_" + w)
	Ton.spiele(ego.spiel, "ui-klick", 0.0)
	ego.spiel.melde("%s gerufen – Magazin %d." % [str(Werte.SONDE7_WAFFEN_NAME[w]), magazin], 1.5)


## Waffe weg (leer oder vorzeitig): Hand wieder da, Cooldown läuft (Luftschlag: keiner, einmal je Runde).
func _wegstecken() -> void:
	if waffe == "":
		return
	if waffe != "luftschlag":
		cd[waffe] = float(_w(waffe)["abkling"])
	waffe = ""
	magazin = 0
	_laden = -1.0
	_erfasst.clear()


func _verbrauche(n: int = 1) -> void:
	magazin -= n
	if magazin <= 0:
		_wegstecken()


# ------------------------------------------------------------------ Schweben und Schub

## Leertaste halten: steigen und schweben (Akku), loslassen: sinken, doppelt: fallen lassen. Luftschlag: ohne Akku.
func vor_fallen(echt: float) -> bool:
	var d := _w("schweben")
	var b := ego._boden()
	var halten := ego.taste_gehalten("leertaste") and ego._frei()
	var oben_max := float(d["hoehe"])
	if _fallen_lassen:
		if ego.hoehe <= b + 0.001 and ego.steig <= 0.0:
			_fallen_lassen = false
		return false   # Schwere wie bei Brakk
	if luftschlag_an():
		# steigt von selbst auf Schwebehöhe (Leertaste: höher), schwebt ohne Akku
		var soll := oben_max if halten else maxf(float(_w("luftschlag")["hoehe"]), b)
		ego.hoehe = move_toward(ego.hoehe, soll, float(d["steigen"]) * echt)
		ego.steig = 0.0
		ego.hoehe = maxf(ego.hoehe, b)
		return true
	if halten and akku > 0.0:
		ego.hoehe = minf(maxf(oben_max, b), ego.hoehe + float(d["steigen"]) * echt)
		ego.steig = 0.0
		akku = maxf(0.0, akku - echt)
		return true
	if ego.hoehe > b + 0.001:
		ego.hoehe = maxf(b, ego.hoehe - float(d["sinken"]) * echt)
		ego.steig = 0.0
		return true
	akku = minf(float(d["akku"]), akku + float(d["akku"]) / float(d["laden"]) * echt)
	return false


func _schub_weiter(echt: float) -> void:
	if _schub < 0.0:
		return
	var d := _w("schub")
	_schub += echt
	var s := _schub_r * float(d["felder"]) / float(d["dauer"]) * Werte.ZELLE * echt
	ego._luft_schritt(Vector2(s.x, 0.0))
	ego._luft_schritt(Vector2(0.0, s.y))
	if _schub_bremse > 0.0:
		for g: Gegner in ego.spiel.ego_gegner():
			if is_instance_valid(g) and not g._tot and g.position.distance_to(ego._fuss2d()) <= Werte.ZELLE * 0.7:
				g.gebremst = maxf(g.gebremst, _schub_bremse)   # 20.11. (Nachtrag): Gelspur
	if _schub >= float(d["dauer"]):
		_schub = -1.0
		if _schub_brand > 0.0:
			brand_bei(ego._fuss2d(), _schub_brand, float(_w("hand")["buendel_schaden"]) * _sf() * 0.3)   # 20.11. (Nachtrag): Brandspur am Ziel


# ------------------------------------------------------------------ Ablauf

func weiter(echt: float, frei: bool) -> void:
	_schub_rest = maxf(0.0, _schub_rest - echt)
	_tele_rest = maxf(0.0, _tele_rest - echt)
	_nachladen = maxf(0.0, _nachladen - echt)
	_blitz = maxf(0.0, _blitz - echt)
	_rueck = maxf(0.0, _rueck - echt * 5.0)
	_sperre = maxf(0.0, _sperre - echt)
	for w: String in cd.keys():
		cd[w] = maxf(0.0, float(cd[w]) - echt)
	_schub_weiter(echt)
	ego.brakk.luft = ego.hoehe > ego._boden() + 0.3   # in der Luft: Fernkämpfer sehen sie
	if ego.brakk.luft and int(ego.spiel.phase) == 1:
		f().zaehle_zeit("luft_sek", echt)   # Sieg-Übersicht: Zeit in der Luft
	if waffe == "luftschlag" and not luftschlag_an():
		_wegstecken()
	if _laden >= 0.0:
		_laden += echt
	if Time.get_ticks_msec() > _erfasst_bis:
		_erfasst.clear()
	_erfasst = _erfasst.filter(func(g: Variant) -> bool: return is_instance_valid(g) and not (g as Gegner)._tot)
	_sondenblick_weiter()
	glut_weiter(echt)   # 20.11. (Nachtrag)
	_dauerfeuer = _dauerfeuer + echt if waffe == "doppellaser" and _links and _sperre <= 0.0 else 0.0
	_takt_l -= echt
	_takt_r -= echt
	var feuert_laser := false
	if frei and _nachladen <= 0.0:
		match waffe:
			"":
				if _links and _sperre <= 0.0:
					feuert_laser = true
					_hand_laser(echt)
				if _rechts and _takt_r <= 0.0:
					_buendel()
			"doppellaser":
				if _links and _sperre <= 0.0 and _takt_l <= 0.0:
					_doppellaser()
				feuert_laser = _links and _sperre <= 0.0
			"schrot":
				if _links and _takt_l <= 0.0:
					_schrot(int(_w("schrot")["kugeln"]))
					_verbrauche()
			"luftschlag":
				if (_links or _rechts) and _takt_l <= 0.0:
					_granate()
	if feuert_laser:
		_hitze += echt / _hitze_sek()   # 20.11. (Nachtrag): 6 s Dauerfeuer, ab Stufe 5 8 s
		if _hitze >= 1.0:
			_hitze = 0.0
			_sperre = float(_w("hitze")["pause"])
			Ton.spiele(ego.spiel, "hit-thud", -8.0)
			ego.spiel.melde("Überhitzt – %s s Pause." % BrakkFortschritt._zahl(_w("hitze")["pause"]), 1.0)
	else:
		_hitze = maxf(0.0, _hitze - echt / _hitze_sek() * float(_w("hitze")["kuehl"]))   # kühlt doppelt so schnell
	_strahl_zeigen(waffe == "" and feuert_laser)
	_geschosse_weiter(echt)


func gefallen() -> void:
	ego.brakk.luft = false
	_links = false
	_rechts = false
	_laden = -1.0
	_fallen_lassen = false
	if waffe == "luftschlag":
		_wegstecken()


func beenden() -> void:
	for gs: Dictionary in _geschosse:
		(gs["knoten"] as Node).queue_free()
	_geschosse.clear()
	if _strahl != null:
		_strahl.queue_free()
	if _blick_bis > 0:
		ego.hd.umriss_an = _umriss_vorher
	if is_instance_valid(ego.brakk):
		ego.brakk.luft = false


func _zaehle(was: String) -> void:
	f().zaehler[was] = int(f().zaehler.get(was, 0)) + 1


func _sf() -> float:
	return f().schaden_faktor()


# ------------------------------------------------------------------ Hand

func _hand3d(links: bool) -> Vector3:
	return ego.hd.kamera.global_position + ego._blick() * 0.5 + ego._rechts() * (-0.18 if links else 0.18) - Vector3(0, 0.15, 0)


## Erster Gegner auf der Blicklinie bis `weite` (Mauern halten auf): [Gegner, Abstand] oder [null, Ende].
func _erster(weite: float, r: Vector3 = Vector3.ZERO) -> Array:
	var von := ego.hd.kamera.global_position
	if r == Vector3.ZERO:
		r = ego._schuss_blick()
	var bis := ego._strahl_bis(von, r, weite)
	var bester: Gegner = null
	var beste := bis
	for g: Gegner in ego.spiel.ego_gegner():
		if not is_instance_valid(g) or g._tot:
			continue
		var c := ego._zu3d(g.position, (ego.hd.H if ego.hd.ist_hoch(ego.karte.zelle_bei(g.position)) else 0.0) + 0.42)
		var t := (c - von).dot(r)
		if t <= 0.0 or t >= beste:
			continue
		if (von + r * t).distance_to(c) <= 0.36:
			beste = t
			bester = g
	return [bester, beste]


## Linke Hand: Farblaser in Ringfarbe – Dauerstrahl, trifft im Takt den ersten Gegner auf der Linie.
func _hand_laser(_echt: float) -> void:
	var d := _w("hand")
	var e := _erster(float(d["weite"]))
	_strahl_bis = ego.hd.kamera.global_position + ego._schuss_blick() * float(e[1])
	if _takt_l > 0.0:
		return
	_takt_l = float(d["laser_takt"])
	if e[0] != null:
		trifft(e[0], float(d["laser_schaden"]) * _sf(), "laser_hand")
		if (e[0] as Gegner)._tot:
			ego._treffer_gefuehl(_strahl_bis, true)


## Rechte Hand: Energiebündel – langsam, platzt in kleiner Fläche und trägt den Ring-Effekt.
func _buendel() -> void:
	var d := _w("hand")
	_takt_r = float(d["buendel_takt"])
	_schiesse_geschoss("buendel", _hand3d(false), ego._schuss_blick() * float(d["buendel_tempo"]), 0.11, ring_farbe())
	_rueck = 1.0
	_blitz = 0.08
	Ton.spiele(ego.spiel, "tc-arc", -8.0)


func _schiesse_geschoss(art: String, p: Vector3, v: Vector3, radius: float, farbe: Color) -> void:
	var k := MeshInstance3D.new()
	var kugel := SphereMesh.new()
	kugel.radius = radius
	kugel.height = radius * 2.0
	k.mesh = kugel
	k.material_override = ego._leucht(farbe, 0.95, 3.0)
	ego.hd.add_child(k)
	k.position = p
	_geschosse.append({"p": p, "v": v, "art": art, "knoten": k, "weg": 0.0})


func _geschosse_weiter(dt: float) -> void:
	var noch: Array = []
	for gs: Dictionary in _geschosse:
		var platzt := false
		var schritte := maxi(1, ceili((gs["v"] as Vector3).length() * dt / 0.08))
		for i in schritte:
			var alt: Vector3 = gs["p"]
			if str(gs["art"]) == "granate":
				gs["v"] = (gs["v"] as Vector3) - Vector3(0, GRANATE_SCHWERE * dt / float(schritte), 0)
			var neu: Vector3 = alt + (gs["v"] as Vector3) * dt / float(schritte)
			gs["weg"] = float(gs["weg"]) + alt.distance_to(neu)
			var z := Vector2i(floori(neu.x), floori(neu.z))
			var mauer := ego.hd.ist_hoch(z) and neu.y <= ego.hd.H and not (ego.brakk.oben and z == ego.karte.zelle_bei(ego._fuss2d()))
			var schild: bool = not ego.spiel.endkampf and neu.x < float(Werte.ZONE_SPALTEN)
			if neu.y <= 0.02 or mauer or schild or float(gs["weg"]) > 20.0 or _gegner_bei(neu) != null:
				gs["p"] = alt if mauer else neu
				platzt = true
				break
			gs["p"] = neu
		(gs["knoten"] as Node3D).position = gs["p"]
		if platzt:
			_platzt(gs)
			(gs["knoten"] as Node).queue_free()
		else:
			noch.append(gs)
	_geschosse = noch


func _gegner_bei(p: Vector3) -> Gegner:
	for g: Gegner in ego.spiel.ego_gegner():
		if not is_instance_valid(g) or g._tot:
			continue
		var c := ego._zu3d(g.position, (ego.hd.H if ego.hd.ist_hoch(ego.karte.zelle_bei(g.position)) else 0.0) + 0.42)
		if c.distance_to(p) <= 0.4:
			return g
	return null


func _platzt(gs: Dictionary) -> void:
	var p3: Vector3 = gs["p"]
	var p := ego._zu2d(p3)
	var schaden := 0.0
	var radius := 0.0
	var quelle := str(gs["art"])
	var mit_ring := ""
	if quelle == "buendel":
		var d := _w("hand")
		radius = float(d["buendel_flaeche"]) * Werte.ZELLE
		schaden = float(d["buendel_schaden"]) * _sf() * float(ring_wert(ring(), "schaden", 1.0))
		mit_ring = ring()   # das Bündel trägt den Ring-Effekt
	else:
		var d2 := _w("luftschlag")
		radius = float(d2["radius"]) * Werte.ZELLE
		schaden = float(d2["schaden"]) * _sf()
		quelle = "luftschlag"
		ego._trauma = minf(1.0, ego._trauma + 0.2)
		Ton.spiele(ego.spiel, "hit-boom", -6.0)
	ego.spiel.effekte.flaeche(p, radius, ring_farbe())
	ego._funke(p3, 0.2 if quelle == "luftschlag" else 0.12)
	var kill := false
	var n := 0
	for g: Gegner in ego.spiel.ego_gegner().duplicate():
		if not is_instance_valid(g) or g._tot or ego.spiel._geschuetzt(g) or g.position.distance_to(p) > radius:
			continue
		if quelle == "luftschlag":
			_waffen_treffer(g, schaden, quelle)   # 20.11. (Nachtrag): Ring-Wirkung am Luftschlag
		else:
			trifft(g, schaden, quelle, mit_ring)
		n += 1
		kill = kill or g._tot
	if n > 0:
		ego._treffer_gefuehl(p3, kill)
	if quelle == "luftschlag":
		var br := spell_w("luftschlag", "treffer_brand")   # Brand-Ring
		if br > 0.0:
			brand_bei(p, br, schaden * 0.25)
		var na := spell_w("luftschlag", "nachschlag")   # Sprung-Ring: zweiter Einschlag dahinter
		var v: Vector3 = gs["v"]
		if na > 0.0 and Vector2(v.x, v.z).length() > 0.01:
			var p2 := p + Vector2(v.x, v.z).normalized() * Werte.ZELLE
			ego.spiel.effekte.flaeche(p2, radius * 0.7, ring_farbe())
			for g: Gegner in ego.spiel.ego_gegner().duplicate():
				if is_instance_valid(g) and not g._tot and not ego.spiel._geschuetzt(g) and g.position.distance_to(p2) <= radius * 0.7:
					_waffen_treffer(g, schaden * na / 100.0, quelle)


## Dauerstrahl der Hand (ein Kasten von der linken Hand bis zum Ende, jedes Bild neu).
func _strahl_zeigen(an: bool) -> void:
	if _strahl == null:
		_strahl = MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.03, 0.03, 1.0)
		_strahl.mesh = box
		ego.hd.add_child(_strahl)
	_strahl.visible = an
	if not an:
		_strahl_an = false
		return
	if not _strahl_an or Engine.get_process_frames() % 20 == 0:
		_strahl.material_override = ego._leucht(ring_farbe(), 0.85, 3.0)   # Farbe des aktiven Rings
	_strahl_an = true
	var a := _hand3d(true)
	var b := _strahl_bis
	var lang := maxf(0.05, a.distance_to(b))
	_strahl.position = (a + b) / 2.0
	_strahl.scale = Vector3(1.0 + 0.3 * sin(Time.get_ticks_msec() / 30.0), 1.0, lang)
	_strahl.look_at_from_position(_strahl.position, b, Vector3.UP if absf((b - a).normalized().y) < 0.99 else Vector3.RIGHT)


# ------------------------------------------------------------------ Waffen

func _rechts_druck() -> void:
	if _nachladen > 0.0:
		return
	match waffe:
		"doppellaser":
			_erfasse()
		"schrot":
			_schrot_alles()
		"sondengewehr":
			_sondenblick()
		"luftschlag":
			if _takt_l <= 0.0:
				_granate()


## Doppel-Lasergewehr links: Dauerfeuer. Sind Ziele erfasst, geht jeder Schuss reihum an das nächste (mit Ring-Effekt).
func _doppellaser() -> void:
	var d := _w("doppellaser")
	_takt_l = float(d["takt"]) / (1.0 + spell_w("doppellaser", "anlauf") / 100.0 * clampf(_dauerfeuer / 3.0, 0.0, 1.0))   # 20.11. (Nachtrag): Wirbel-Ring
	_rueck = 0.6
	_blitz = 0.05
	var muendung := _hand3d(false)
	if not _erfasst.is_empty():
		_erfasst_i = (_erfasst_i + 1) % _erfasst.size()
		var g: Gegner = _erfasst[_erfasst_i]
		var c := _mitte3d(g)
		ego._strahl(muendung, c, ring_farbe())
		_waffen_treffer(g, float(d["schaden"]) * float(d["erfassung_mal"]) * _sf(), "erfassung", ring())   # 20.11. (Nachtrag): mit Ring-Wirkung
	else:
		var e := _erster(float(d["weite"]))
		var ende := ego.hd.kamera.global_position + ego._schuss_blick() * float(e[1])
		ego._strahl(muendung, ende, ring_farbe().lightened(0.3))
		if e[0] != null:
			_waffen_treffer(e[0], float(d["schaden"]) * _sf(), "doppellaser")
	Ton.spiele(ego.spiel, "brakk-schuss-a", -8.0)
	_verbrauche()


## Rechts: Zielerfassung – die Gegner nahe dem Fadenkreuz (sichtbar, in Weite), Anzahl nach Stufe.
func _erfasse() -> void:
	var d := _w("doppellaser")
	var n := 0
	for i in (d["erfassen_ab"] as Array).size():
		if f().stufe >= int(d["erfassen_ab"][i]):
			n = int(d["erfassen"][i])
	var von := ego.hd.kamera.global_position
	var blick := ego._blick()
	var liste: Array = []
	for g: Gegner in ego.spiel.ego_gegner():
		if not is_instance_valid(g) or g._tot or ego.spiel._geschuetzt(g):
			continue
		var c := _mitte3d(g)
		var dv := c - von
		var weite := dv.length()
		if weite > float(d["weite"]) or weite < 0.1:
			continue
		var winkel := blick.angle_to(dv)
		if winkel > deg_to_rad(30.0) or ego._strahl_bis(von, dv / weite, weite) < weite - 0.35:
			continue
		liste.append([winkel, g])
	liste.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	n += int(spell_w("doppellaser", "erfassen_plus"))   # 20.11. (Nachtrag): Ziel-Ring
	_erfasst.clear()
	for e: Array in liste.slice(0, n):
		_erfasst.append(e[1])
	_erfasst_bis = Time.get_ticks_msec() + int(float(d["erfassen_sek"]) * 1000.0)
	if _erfasst.is_empty():
		ego.spiel.melde("Kein Ziel zu erfassen.", 1.0)
	else:
		_zaehle("erfassungen")
		Ton.spiele(ego.spiel, "ui-klick", 2.0)


## Schrotflinte: `kugeln` Kugeln im Fächer, kurz und breit.
func _schrot(kugeln: int) -> void:
	var d := _w("schrot")
	_takt_l = float(d["takt"])
	_rueck = 1.0
	_blitz = 0.08
	var blick := ego._schuss_blick()
	var muendung := _hand3d(false)
	var getroffen := 0
	var streu := float(d["streuung"]) * (1.0 - spell_w("schrot", "streuung") / 100.0)   # 20.11. (Nachtrag): Ziel-Ring
	var brand := spell_w("schrot", "treffer_brand")
	for i in kugeln:
		var r := blick.rotated(Vector3.UP, deg_to_rad(randf_range(-1.0, 1.0) * streu)).rotated(ego._rechts(), deg_to_rad(randf_range(-0.4, 0.4) * streu))
		var e := _erster(float(d["weite"]), r)
		ego._strahl(muendung, ego.hd.kamera.global_position + r * float(e[1]), Color("ffd9a0").lerp(ring_farbe(), 0.75) if ring() != "" else Color("ffd9a0"))
		if e[0] != null:
			if brand > 0.0 and getroffen == 0:
				brand_bei((e[0] as Gegner).position, brand, float(d["schaden"]) * _sf())   # 20.11. (Nachtrag): Brand-Ring
			_waffen_treffer(e[0], float(d["schaden"]) * _sf(), "schrot")
			getroffen += 1
	ego._kick += 0.05
	ego._trauma = minf(1.0, ego._trauma + 0.2)
	Ton.spiele(ego.spiel, "hit-pboom", -6.0)


## Rechts: das ganze Magazin auf einmal, Rückstoß nach hinten oben – genau eine Mauerhöhe, ohne Akku. Danach Nachladen.
func _schrot_alles() -> void:
	var d := _w("schrot")
	_schrot(magazin * int(d["kugeln"]))
	ego.steig = sqrt(2.0 * EgoModus.SCHWERE * ego.hd.H)   # genau eine Mauerhöhe
	ego.hoehe = maxf(ego.hoehe, ego._boden() + 0.01)
	ego._flug = -Vector2(ego._vorne().x, ego._vorne().z).normalized() * 4.0
	_fallen_lassen = true   # der Sprung folgt der Schwere, nicht dem Schweben
	ego._trauma = minf(1.0, ego._trauma + 0.5)
	ego._kick += 0.12
	_zaehle("schrot_alles")
	magazin = 0
	_wegstecken()
	_nachladen = float(d["nachladen"])


## Sondengewehr links (nach dem Aufladen losgelassen): Durchschlag durch alle Gegner in einer Linie.
func _durchschlag() -> void:
	var d := _w("sondengewehr")
	var von := ego.hd.kamera.global_position
	var r := ego._schuss_blick()
	var weite := ego._strahl_bis(von, r, float(d["weite"]))
	var muendung := _hand3d(false)
	ego._strahl(muendung, von + r * weite, ring_farbe().lightened(0.5))
	ego._strahl(muendung + Vector3(0, 0.015, 0), von + r * weite, Color.WHITE)
	var kill := false
	var letzter: Gegner = null
	for g: Gegner in ego.spiel.ego_gegner().duplicate():
		if not is_instance_valid(g) or g._tot:
			continue
		var c := ego._zu3d(g.position, (ego.hd.H if ego.hd.ist_hoch(ego.karte.zelle_bei(g.position)) else 0.0) + 0.42)
		var t := (c - von).dot(r)
		if t > 0.0 and t <= weite and (von + r * t).distance_to(c) <= 0.45:
			_waffen_treffer(g, float(d["schaden"]) * _sf(), "sondengewehr", "", false)   # 20.11. (Nachtrag): Ring-Wirkung
			kill = kill or g._tot
			letzter = g
	var bl := spell_w("sondengewehr", "blitz")
	if bl > 0.0 and letzter != null:
		kette(letzter, int(bl), float(d["schaden"]) * _sf() * 0.3)   # Sprung-Ring
	_rueck = 1.0
	_blitz = 0.1
	ego._kick += 0.08
	ego._fov_puls = maxf(ego._fov_puls, 6.0)
	ego._treffer_gefuehl(von + r * weite, kill)
	Ton.spiele(ego.spiel, "tc-rail", -4.0)
	_verbrauche()


## Rechts: Sondenblick – Gegner durch Wände sichtbar (Umrisse), so gesehene nehmen von Truppen mehr Schaden.
func _sondenblick() -> void:
	var d := _w("sondengewehr")
	if _blick_bis <= 0:
		_umriss_vorher = ego.hd.umriss_an
	_blick_bis = Time.get_ticks_msec() + int((float(d["blick_sek"]) + spell_w("sondengewehr", "blick_dauer")) * 1000.0)   # 20.11. (Nachtrag): Ziel-Ring
	ego.hd.umriss_an = true
	ego.spiel.effekte.welle(ego._fuss2d(), float(d["blick_weite"]) * Werte.ZELLE, ring_farbe(), "funk", 0.8)
	_zaehle("sondenblick")
	Ton.spiele(ego.spiel, "alert", -10.0)
	_verbrauche()


func _sondenblick_weiter() -> void:
	if _blick_bis <= 0:
		return
	var jetzt := Time.get_ticks_msec()
	if jetzt >= _blick_bis:
		_blick_bis = 0
		ego.hd.umriss_an = _umriss_vorher
		return
	var weite := float(_w("sondengewehr")["blick_weite"]) * Werte.ZELLE
	for g: Gegner in ego.spiel.ego_gegner():
		if is_instance_valid(g) and not g._tot and g.position.distance_to(ego._fuss2d()) <= weite:
			g.sondenblick_bis = jetzt + 250   # gesehen, solange der Blick läuft (kurz nachwirkend)


## Luftschlag: Granate im Bogen, hoher Flächenschaden in Ringfarbe.
func _granate() -> void:
	var d := _w("luftschlag")
	_takt_l = float(d["takt"])
	_schiesse_geschoss("granate", _hand3d(false), (ego._schuss_blick() + Vector3(0, 0.15, 0)).normalized() * float(d["tempo"]), 0.12, ring_farbe())
	_rueck = 1.0
	_blitz = 0.08
	ego._kick += 0.04
	Ton.spiele(ego.spiel, "hit-thud", -4.0)
	_verbrauche()


# ------------------------------------------------------------------ Oberfläche

func tempo_faktor() -> float:
	return 1.0


func hinweis() -> String:
	if _nachladen > 0.0:
		return "Nachladen %.1f s" % _nachladen
	return ""


func male_waffen(g: Vector2, wpx: float) -> void:
	var bild := ego._bild
	var wipp := Vector2(cos(ego._gang * 0.5) * 3.0, absf(sin(ego._gang * 0.5)) * 4.0) if ego._geht else Vector2.ZERO
	var schwank := (ego._sway + Vector2(0, 7.0 * ego._delle)) * wpx
	if waffe == "":
		# Hand: zwei Handschuhe mit Emitter – links der Farblaser, rechts das Energiebündel (Platzhalter aus Code)
		var tex: Texture2D = _waffenbild("")
		var ts := Vector2(tex.get_size()) * wpx * 1.2
		var farbe := ring_farbe()
		for seite: int in [-1, 1]:
			var x := g.x * (0.22 if seite < 0 else 0.78) - ts.x * 0.5
			var rueck := _rueck if seite > 0 else (0.25 if _links and _sperre <= 0.0 else 0.0)
			var pos := Vector2(x, g.y - ts.y + 8.0 * wpx) + Vector2(wipp.x * seite, wipp.y) + schwank + Vector2(0, rueck * 6.0) * wpx
			bild.draw_set_transform(pos.round() + Vector2(ts.x * 0.5, 0), 0.0, Vector2(float(seite), 1.0))
			bild.draw_texture_rect(tex, Rect2(Vector2(-ts.x * 0.5, 0), ts), false)
			bild.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			var mund := pos + Vector2(ts.x * 0.5, 6.0 * wpx)
			if seite < 0:
				var heiss := _sperre > 0.0
				bild.draw_circle(mund, (3.0 + 2.0 * _hitze) * wpx, Color(1.0, 0.3, 0.2, 0.8) if heiss else Color(farbe, 0.7))
				_hitze_balken(Vector2(pos.x + ts.x * 0.5, pos.y - 5.0 * wpx), ts.x * 0.8, wpx)   # 20.11. (Nachtrag): Hitze an der Waffe
			else:
				var puls := 0.7 + 0.3 * sin(Time.get_ticks_msec() / 90.0)
				var bereit := clampf(1.0 - _takt_r / float(_w("hand")["buendel_takt"]), 0.0, 1.0)
				bild.draw_circle(mund, (2.0 + 4.0 * bereit * puls) * wpx, Color(farbe, 0.35 + 0.4 * bereit))
				bild.draw_circle(mund, 1.5 * wpx, Color.WHITE)
				if _blitz > 0.0:
					ego._muendungsblitz(mund, wpx, farbe)
		return
	var tex2: Texture2D = _waffenbild(waffe)
	var ts2 := Vector2(tex2.get_size()) * wpx * 1.4
	var pos2 := Vector2(g.x * 0.66 - ts2.x * 0.5, g.y - ts2.y + 6.0 * wpx) + wipp + schwank + Vector2(_rueck * 3.0, _rueck * 8.0) * wpx
	if waffe == "sondengewehr" and _laden >= 0.0:
		var zitter := clampf(_laden / _ladezeit(), 0.0, 1.0)
		pos2 += Vector2(sin(Time.get_ticks_msec() / 20.0), cos(Time.get_ticks_msec() / 23.0)) * zitter * 1.5 * wpx
	bild.draw_texture_rect(tex2, Rect2(pos2.round(), ts2), false)
	var mund2 := pos2 + Vector2(ts2.x * 0.5, 3.0 * wpx)
	bild.draw_circle(mund2, 2.0 * wpx, Color(ring_farbe(), 0.6))
	if waffe == "doppellaser":
		_hitze_balken(Vector2(pos2.x + ts2.x * 0.5, pos2.y - 5.0 * wpx), ts2.x * 0.6, wpx)   # 20.11. (Nachtrag)
	if _blitz > 0.0:
		ego._muendungsblitz(mund2, wpx, ring_farbe())


## 20.11. (Nachtrag): Hitzebalken über der Laserwaffe – füllt sich beim Feuern, rot ab 75 % und während der Sperre.
func _hitze_balken(mitte_oben: Vector2, breite: float, wpx: float) -> void:
	if _hitze <= 0.01 and _sperre <= 0.0:
		return
	var bild := ego._bild
	var r := Rect2(mitte_oben.x - breite / 2.0, mitte_oben.y - 2.0 * wpx, breite, 2.0 * wpx).abs()
	bild.draw_rect(r.grow(wpx * 0.5), Color(0.04, 0.05, 0.08, 0.8))
	var anteil := 1.0 if _sperre > 0.0 else _hitze
	var rot := _sperre > 0.0 or _hitze > 0.75
	if _sperre > 0.0 and fmod(Time.get_ticks_msec() / 150.0, 2.0) < 1.0:
		rot = true
	bild.draw_rect(Rect2(r.position, Vector2(r.size.x * anteil, r.size.y)), Color(1.0, 0.3, 0.2) if rot else Color(1.0, 0.8, 0.4))


## 20.11. (Nachtrag): Sekunden Dauerfeuer bis zur Überhitzung (Werte.SONDE7["hitze"], ab Stufe "spaet_ab" länger).
func _hitze_sek() -> float:
	var h := _w("hitze")
	return float(h["sek_spaet"] if f().stufe >= int(h["spaet_ab"]) else h["sek"])


## Über allem: Ladering, Erfassungsmarken, Luftschlag-Zeit, Nachladen (Hitze: Balken an der Waffe, 20.11. Nachtrag).
func male_oben(g: Vector2) -> void:
	if ego._hud_aus() or not ego._frei():
		return
	var bild := ego._bild
	var m := (g / 2.0).round()
	var px := maxf(2.0, floorf(g.y / 150.0))
	if waffe == "sondengewehr" and _laden >= 0.0:
		var a := clampf(_laden / _ladezeit(), 0.0, 1.0)
		var rr := 12.0 * px
		bild.draw_arc(m, rr, 0.0, TAU, 40, Color(1, 1, 1, 0.14), px * 0.6)
		bild.draw_arc(m, rr, -PI / 2.0, -PI / 2.0 + TAU * a, 40, Color.WHITE if a >= 1.0 else ring_farbe(), px)
		if a >= 1.0:
			Stil.schreibe_mittig(bild, m - Vector2(0, rr + 6.0 * px), "loslassen", 16, Color.WHITE)
	var kam := ego.hd.kamera
	for gv: Variant in _erfasst:
		if not is_instance_valid(gv):
			continue   # im selben Bild gefallen und schon gelöscht
		var gg: Gegner = gv
		var c := _mitte3d(gg) + Vector3(0, 0.08, 0)
		if kam.is_position_behind(c):
			continue
		var s := kam.unproject_position(c)
		var k := 7.0 * px
		var farbe := ring_farbe()
		for e: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
			bild.draw_line(s + e * k, s + e * k - Vector2(e.x, 0) * 3.0 * px, farbe, px * 0.6)
			bild.draw_line(s + e * k, s + e * k - Vector2(0, e.y) * 3.0 * px, farbe, px * 0.6)
	if luftschlag_an():
		var rest := float(_luft_bis - Time.get_ticks_msec()) / 1000.0
		Stil.schreibe_mittig(bild, Vector2(g.x / 2.0, g.y * 0.62), "LUFTSCHLAG %d s · %d Granaten" % [ceili(rest), magazin], 20, ring_farbe())
	if _blick_bis > 0:
		Stil.schreibe_mittig(bild, Vector2(g.x / 2.0, g.y * 0.16), "SONDENBLICK %d s" % ceili(float(_blick_bis - Time.get_ticks_msec()) / 1000.0), 18, ring_farbe())


## 20.11. (Nachtrag): Fähigkeiten-Leiste wie bei Brakk (ego_modus._faehigkeiten) – hier nur Rest, Text darüber, läuft.
func leiste_info(was: String) -> Array:
	var welle := int(ego.spiel.welle)
	match was:
		"schub":
			return [_schub_rest / float(_w("schub")["abkling"]), "", false]
		"teleport":
			return [0.0 if not luftschlag_an() and _tele_rest <= 0.0 else (1.0 if luftschlag_an() else _tele_rest / float(_w("teleport")["abkling"])), "", false]
		"hand_rechts":
			return [0.0, "", false]
		"doppellaser", "schrot", "sondengewehr", "luftschlag":
			if waffe == was:
				return [0.0, "%d" % magazin, true]
			if was == "luftschlag":
				return [1.0 if _luft_welle == welle else 0.0, "ab R.%d" % (welle + 1) if _luft_welle == welle else "", false]
			return [float(cd.get(was, 0.0)) / float(_w(was)["abkling"]), "", false]
	return [0.0, "", false]


func leiste_farbe() -> Color:
	return ring_farbe()


## Akku links neben der Fähigkeiten-Leiste, rechts die Ringe wie bei Brakk.
func male_leisten(g: Vector2) -> void:
	var bild := ego._bild
	var s := 46.0
	var breite := 7.0 * s + 6.0 * 10.0
	var y := roundf(g.y * 0.86) - 34.0 - 16.0 - s
	var x := roundf((g.x - breite) / 2.0)
	# Akku unter der Leiste (links neben der Lebensleiste)
	var ab := Rect2(x - 70.0, y + 4.0, 12.0, s - 8.0)
	var voll := akku / float(_w("schweben")["akku"])
	bild.draw_rect(ab.grow(2.0), Color(0.04, 0.05, 0.08, 0.75))
	bild.draw_rect(Rect2(ab.position + Vector2(0, ab.size.y * (1.0 - voll)), Vector2(ab.size.x, ab.size.y * voll)), SONDE_FARBE if not luftschlag_an() else Stil.GOLD)
	Stil.schreibe(bild, Vector2(ab.end.x + 6.0, ab.get_center().y), "Akku", 13, Stil.TEXT_BLASS)
	ego.ringwerk._ringleiste(g)


func werte_zeilen() -> Dictionary:
	var schaden := 0.0
	var pro_sek := 0.0
	match waffe:
		"":
			var d := _w("hand")
			schaden = float(d["laser_schaden"]) * _sf()
			pro_sek = 1.0 / float(d["laser_takt"])
		"doppellaser":
			schaden = float(_w("doppellaser")["schaden"]) * _sf()
			pro_sek = 1.0 / float(_w("doppellaser")["takt"])
		"schrot":
			schaden = float(_w("schrot")["schaden"]) * _sf() * float(_w("schrot")["kugeln"])
			pro_sek = 1.0 / float(_w("schrot")["takt"])
		"sondengewehr":
			schaden = float(_w("sondengewehr")["schaden"]) * _sf()
			pro_sek = 1.0 / _ladezeit()
		"luftschlag":
			schaden = float(_w("luftschlag")["schaden"]) * _sf()
			pro_sek = 1.0 / float(_w("luftschlag")["takt"])
	var zusatz: Array = [
		["Waffe: " + str(Werte.SONDE7_WAFFEN_NAME[waffe]) + ("" if waffe == "" else " · %d" % magazin), ring_farbe() if waffe != "" else Stil.TEXT],
		["Hand: " + (EgoModus.ring_kurz(ring()) if ring() != "" else "ohne Ring"), ring_farbe()],
		["Akku %d %%" % roundi(100.0 * akku / float(_w("schweben")["akku"])), SONDE_FARBE],
	]
	if not _erfasst.is_empty():
		zusatz.append(["Erfasst: %d" % _erfasst.size(), ring_farbe()])
	return {"zeilen": [
		["schaden", "Schaden", "%.0f" % schaden, []],
		["takt", "Schüsse/s", ("%.1f" % pro_sek).replace(".", ","), []],
		["dps", "Schaden/s", "%.0f" % (schaden * pro_sek), []],
	], "zusatz": zusatz}


# ------------------------------------------------------------------ Platzhalter-Grafik aus Code

## Handschuh mit Emitter auf dem Handrücken (Sonde 7: Weiß und Cyan wie im Tutorial-Bild), von hinten gesehen.
static func _male_handschuh() -> Image:
	var img := Image.create(30, 40, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	EgoModus._vieleck(img, [Vector2(4, 28), Vector2(26, 26), Vector2(30, 40), Vector2(0, 40)], Color("2a3240"))   # Ärmel
	EgoModus._vieleck(img, [Vector2(5, 27), Vector2(25, 25), Vector2(26, 29), Vector2(4, 31)], Color("6ee6ff"))
	EgoModus._vieleck(img, [Vector2(6, 8), Vector2(24, 7), Vector2(26, 22), Vector2(22, 28), Vector2(8, 29), Vector2(4, 20)], Color("d8dee8"))
	for i in 4:
		var x := 6.0 + i * 4.8
		EgoModus._vieleck(img, [Vector2(x, 1 + absf(i - 1.5)), Vector2(x + 3.5, 1 + absf(i - 1.5)), Vector2(x + 4, 9), Vector2(x - 0.5, 9)], Color("c4ccd8"))
	EgoModus._vieleck(img, [Vector2(11, 12), Vector2(19, 12), Vector2(19, 19), Vector2(11, 19)], Color("3a4250"))   # Emitter
	EgoModus._vieleck(img, [Vector2(13, 14), Vector2(17, 14), Vector2(17, 17), Vector2(13, 17)], Color("6ee6ff"))
	EgoModus._umranden(img)
	return img


## Je Waffe ein einfaches Gewehrbild von hinten (Lauf nach oben), unterscheidbar an Länge, Breite und Aufsätzen.
static func _male_waffe(art: String) -> Image:
	var img := Image.create(40, 70, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var metall := Color("3a3f4c")
	var hell := Color("d8dee8")
	var cyan := Color("6ee6ff")
	# Hände und Ärmel unten
	EgoModus._vieleck(img, [Vector2(2, 58), Vector2(38, 56), Vector2(40, 70), Vector2(0, 70)], Color("2a3240"))
	EgoModus._vieleck(img, [Vector2(10, 46), Vector2(30, 46), Vector2(30, 58), Vector2(10, 58)], hell)
	match art:
		"doppellaser":
			for x0: float in [11.0, 22.0]:
				EgoModus._vieleck(img, [Vector2(x0, 4), Vector2(x0 + 7, 4), Vector2(x0 + 8, 48), Vector2(x0 - 1, 48)], metall)
				EgoModus._vieleck(img, [Vector2(x0 + 2, 6), Vector2(x0 + 5, 6), Vector2(x0 + 5, 40), Vector2(x0 + 2, 40)], cyan)
			EgoModus._vieleck(img, [Vector2(9, 0), Vector2(31, 0), Vector2(31, 5), Vector2(9, 5)], Color("23262e"))
		"schrot":
			EgoModus._vieleck(img, [Vector2(12, 14), Vector2(28, 14), Vector2(30, 48), Vector2(10, 48)], Color("5b4a3a"))
			EgoModus._vieleck(img, [Vector2(13, 6), Vector2(27, 6), Vector2(27, 16), Vector2(13, 16)], metall)
			EgoModus._vieleck(img, [Vector2(14, 26), Vector2(26, 26), Vector2(26, 32), Vector2(14, 32)], Color("8a7a66"))   # Pumpe
			EgoModus._vieleck(img, [Vector2(15, 7), Vector2(19, 7), Vector2(19, 10), Vector2(15, 10)], Color("23262e"))
			EgoModus._vieleck(img, [Vector2(21, 7), Vector2(25, 7), Vector2(25, 10), Vector2(21, 10)], Color("23262e"))
		"sondengewehr":
			EgoModus._vieleck(img, [Vector2(17, 0), Vector2(23, 0), Vector2(24, 48), Vector2(16, 48)], metall)
			EgoModus._vieleck(img, [Vector2(12, 22), Vector2(28, 22), Vector2(28, 30), Vector2(12, 30)], Color("23262e"))   # Zielfernrohr
			EgoModus._vieleck(img, [Vector2(14, 23), Vector2(18, 23), Vector2(18, 29), Vector2(14, 29)], cyan)
			EgoModus._vieleck(img, [Vector2(18, 2), Vector2(22, 2), Vector2(22, 20), Vector2(18, 20)], Color("9fe8ff"))
		"luftschlag":
			EgoModus._vieleck(img, [Vector2(10, 16), Vector2(30, 16), Vector2(31, 48), Vector2(9, 48)], Color("4a505e"))
			EgoModus._vieleck(img, [Vector2(12, 4), Vector2(28, 4), Vector2(29, 18), Vector2(11, 18)], metall)
			EgoModus._vieleck(img, [Vector2(15, 6), Vector2(25, 6), Vector2(25, 14), Vector2(15, 14)], Color("23262e"))   # dicker Lauf
			EgoModus._vieleck(img, [Vector2(11, 30), Vector2(29, 30), Vector2(29, 38), Vector2(11, 38)], Color("ff8a3d"))   # Trommel
	if art in ["schrot", "luftschlag"]:
		EgoModus._vieleck(img, [Vector2(15, 42), Vector2(25, 42), Vector2(25, 45), Vector2(15, 45)], cyan)   # 20.11. (Paul): Leuchtband – nimmt die Ringfarbe an
	EgoModus._umranden(img)
	return img


## Mitte eines Gegners in 3D (oben auf einer Mauer entsprechend höher).
func _mitte3d(g: Gegner) -> Vector3:
	return ego._zu3d(g.position, (ego.hd.H if ego.hd.ist_hoch(ego.karte.zelle_bei(g.position)) else 0.0) + 0.42)
