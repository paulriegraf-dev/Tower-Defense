class_name BrakkLicht
extends RefCounted
## Lichtbewegung im Brakk-Mode (18./19.11.; 27.11. Knoten-Umbau 7c – vorher in ego_modus.gd): Lichttreppe [E] auf den
## Wall und hinunter, Lichtbrücke [E] auf dem Wall, Lichtanker [Q] mit Hängen und Schwingen, Doppelsprung mit
## Lichtplattform, Absprung vom Wall mit Druckwelle. Regeln unverändert; Zahlen (TREPPE_*, ANKER_*, BRUECKE_*, DRUCK_*,
## HAKEN_* …) und der Bewegungszustand (_lauf, _flug, _luft_schritt) bleiben in ego_modus.gd. Teil der Ego-Sicht wie
## EgoKit (`ego.lichtwerk`, angelegt in EgoModus._init).

const Stil := preload("res://scripts/ui/ui_stil.gd")

var ego: EgoModus


func _init(e: EgoModus) -> void:
	ego = e


var _treppe_aufbau := -1.0        # läuft: Sekunden seit dem Werfen
var _treppe_fuss2d := Vector2.INF # Fußpunkt der stehenden Treppe in der 2D-Logik (INF = keine)


## Wall unter dem Fadenkreuz in Reichweite und das freie Feld davor, das Brakk am nächsten ist: [Wall, Fuß] oder [].
func _treppe_ziel() -> Array:
	if ego.brakk.oben:
		return []
	var von := ego.hd.kamera.global_position
	var r := ego._blick()
	var t := ego._strahl_bis(von, r, EgoModus.TREPPE_WEITE + 1.5)
	var p := von + r * (t + 0.03)
	var z := Vector2i(floori(p.x), floori(p.z))
	if not ego.hd.ist_hoch(z) or ego.karte.inhalt(z) != Karte.WALL:
		return []
	if Vector2(z).distance_to(Vector2(ego.karte.zelle_bei(ego._fuss2d()))) > EgoModus.TREPPE_WEITE + 0.5:
		return []
	var fuss := Karte.KEINE
	var beste := INF
	for n: Vector2i in Karte.NACHBARN:
		var c: Vector2i = z + n
		if ego.karte.in_karte(c) and ego.karte.ist_begehbar(c) and not ego.hd.ist_hoch(c):
			var d := ego.karte.mitte(c).distance_to(ego._fuss2d())
			if d < beste:
				beste = d
				fuss = c
	if fuss == Karte.KEINE:
		return []
	# 19.11. (Paul): aus der Ferne gesetzt wird die Treppe länger – ihr Fuß rückt (bis TREPPE_LAENGER Felder) auf Brakk zu
	var n2 := fuss - z
	var abstand := Vector2(z).distance_to(Vector2(ego.karte.zelle_bei(ego._fuss2d())))
	for k in range(1, EgoModus.TREPPE_LAENGER + 1):
		var c2: Vector2i = fuss + n2
		if float(k) + 1.0 > abstand - 0.5 or not ego.karte.in_karte(c2) or not ego.karte.ist_begehbar(c2) or ego.hd.ist_hoch(c2):
			break
		fuss = c2
	return [z, fuss]


func _versuche_klettern(melden: bool) -> bool:
	# an einer stehenden Treppe: hinauf
	if ego._treppe != null and _treppe_fuss2d != Vector2.INF and ego._fuss2d().distance_to(_treppe_fuss2d) <= Werte.ZELLE * 1.1:
		_steige_hinauf()
		return true
	if ego.brakk.e_rest > 0.0:
		if melden:
			ego.spiel.melde("Lichttreppe wieder in %.0f s." % ceilf(ego.brakk.e_rest), 2.0)
		return false
	var ziel := _treppe_ziel()
	if ziel.is_empty():
		if melden:
			ego.spiel.melde("Schau auf einen Erdwall (höchstens %d Felder weit)." % int(EgoModus.TREPPE_WEITE), 2.0)
		return false
	ego._kletter_zelle = ziel[0]
	_treppe_fuss2d = ego.karte.mitte(ziel[1])
	ego._treppe_fuss = ego._zu3d(_treppe_fuss2d, 0.0)
	ego._abwaerts = false
	_baue_treppe()
	ego._treppe_rest = EgoModus.TREPPE_HALTEN
	ego.brakk.e_rest = float(ego.brakk.daten["kletter_abklingzeit"])
	ego._trauma = minf(1.0, ego._trauma + 0.12)
	Ton.spiele(ego.spiel, "tc-arc", -5.0)
	if ego._fuss2d().distance_to(_treppe_fuss2d) <= Werte.ZELLE * 0.6:
		_steige_hinauf()
	return true


func _steige_hinauf() -> void:
	ego._kletter_von = ego._fuss3d()
	ego._kletter_nach = ego._zu3d(ego.karte.mitte(ego._kletter_zelle), ego.hd.H)
	ego._abwaerts = false
	# direkt vor der Wand wie bisher (0,75 s); je länger die Treppe, desto länger der Aufstieg – nie schneller als TEMPO
	ego._kletter_dauer = maxf(EgoModus.KLETTER_STEIGEN, ego._kletter_von.distance_to(ego._kletter_nach) / EgoModus.TEMPO)
	ego._klettern = EgoModus.KLETTER_EINSTECKEN   # die Treppe steht schon: gleich steigen
	ego.steig = 0.0


## [E] auf dem Wall – die Lichttreppe führt hinunter auf das freie Feld in Blickrichtung (sonst auf irgendein
## freies Nachbarfeld), genauso sichtbar wie beim Hinaufsteigen.
func _versuche_absteigen(melden: bool) -> bool:
	if ego.brakk.e_rest > 0.0:
		if melden:
			ego.spiel.melde("Lichttreppe wieder in %.0f s." % ceilf(ego.brakk.e_rest), 2.0)
		return false
	var fuss := ego._fuss2d()
	var v := ego._vorne()
	var hier := ego.karte.zelle_bei(fuss)
	var kandidaten: Array[Vector2] = [fuss + Vector2(v.x, v.z) * Werte.ZELLE, fuss + Vector2(v.x, v.z) * 1.3 * Werte.ZELLE]
	for n: Vector2i in Karte.NACHBARN:
		kandidaten.append(ego.karte.mitte(hier + n))
	for p: Vector2 in kandidaten:
		if ego.hd.ist_hoch(ego.karte.zelle_bei(p)) or not ego._passt_unten(p):
			continue
		ego._kletter_zelle = hier
		ego._kletter_von = ego._fuss3d()
		ego._kletter_nach = ego._zu3d(p, 0.0)
		ego._treppe_fuss = ego._kletter_nach
		_treppe_fuss2d = Vector2.INF
		ego._abwaerts = true
		ego._kletter_dauer = EgoModus.KLETTER_STEIGEN
		ego.brakk.oben = false   # ab jetzt zählt er als am Boden (die 2D-Logik), die Kamera steigt die Treppe hinab
		ego.brakk.posten_zelle = Karte.KEINE
		ego.brakk.zustand = Einheit.Zustand.BODEN
		ego._klettern = 0.0
		ego.steig = 0.0
		_baue_treppe()
		ego._treppe_rest = 0.8 + EgoModus.KLETTER_EINSTECKEN + EgoModus.KLETTER_STEIGEN
		Ton.spiele(ego.spiel, "tc-arc", -5.0)
		return true
	if melden:
		ego.spiel.melde("Kein freies Feld zum Hinuntersteigen.", 2.0)
	return false


func _kletter_weiter(dt: float) -> void:
	ego._klettern += dt
	if ego._klettern < EgoModus.KLETTER_EINSTECKEN:
		return
	var f := clampf((ego._klettern - EgoModus.KLETTER_EINSTECKEN) / ego._kletter_dauer, 0.0, 1.0)
	var weich := f * f * (3.0 - 2.0 * f)
	var p := ego._kletter_von.lerp(ego._kletter_nach, weich)
	ego.hoehe = lerpf(ego._kletter_von.y, ego._kletter_nach.y, minf(1.0, weich * 1.15))
	ego._gang += dt * 12.0
	ego._geht = true
	if f >= 1.0 and ego._abwaerts:
		# unten angekommen
		ego._klettern = -1.0
		ego._abwaerts = false
		ego.brakk.e_rest = float(ego.brakk.daten["kletter_abklingzeit"])
		ego._setze_fuss(ego._zu2d(ego._kletter_nach))
		ego.hoehe = 0.0
		ego._rueckstoss[0] = 0.5
		ego._rueckstoss[1] = 0.5
		return
	if f >= 1.0:
		# oben: wie [E] im Spiel
		ego._klettern = -1.0
		ego.brakk.oben = true
		ego.brakk.posten_zelle = ego._kletter_zelle
		ego.brakk.zustand = Einheit.Zustand.AUF_POSTEN
		ego.brakk.position = ego.karte.mitte(ego._kletter_zelle) + Vector2(0, -12)
		ego.brakk.anker = ego.brakk.position
		ego.hoehe = ego.hd.H
		ego._rueckstoss[0] = 0.5
		ego._rueckstoss[1] = 0.5
		ego._trauma = minf(1.0, ego._trauma + 0.1)
		ego.spiel.melde("Oben auf dem Wall: mehr Reichweite. [E] = Lichttreppe hinunter, oder zweimal springen: Absprung mit Druckwelle.", 3.0)
		return
	ego.brakk.position = ego._zu2d(p)


## Stufen vom Fuß bis an die Krone, mit leuchtenden Kanten, zwei Geländern und einem Lichtring am Fuß.
func _baue_treppe() -> void:
	if ego._treppe != null:
		ego._treppe.queue_free()
	ego._treppe = Node3D.new()
	ego.hd.add_child(ego._treppe)
	var lf := ego._licht_farbe()   # 18.11. (Paul): in der Farbe des aktiven Rings
	var flaeche := ego._leucht(lf, 0.55, 1.8)
	var kante := ego._leucht(lf.lightened(0.7), 0.95, 3.0)
	var gelaender := ego._leucht(lf, 0.8, 2.4)
	var von := ego._treppe_fuss
	var nach := ego._zu3d(ego.karte.mitte(ego._kletter_zelle), 0.0)
	var r := Vector3(nach.x - von.x, 0.0, nach.z - von.z)
	var lang := maxf(0.3, r.length() - 0.5)
	r = r.normalized()
	var quer := Vector3(r.z, 0.0, -r.x)
	var stufen: Array = []
	for i in EgoModus.TREPPE_STUFEN:
		var a := float(i + 1) / float(EgoModus.TREPPE_STUFEN)
		var stufe := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.72, 0.07, lang / EgoModus.TREPPE_STUFEN + 0.04)
		stufe.mesh = box
		stufe.material_override = flaeche
		ego._treppe.add_child(stufe)
		stufe.position = Vector3(von.x, 0.0, von.z) + r * (lang * (float(i) + 0.5) / EgoModus.TREPPE_STUFEN) + Vector3(0, ego.hd.H * a, 0)
		stufe.rotation.y = atan2(r.x, r.z)
		var k := MeshInstance3D.new()
		var kb := BoxMesh.new()
		kb.size = Vector3(0.76, 0.02, 0.025)
		k.mesh = kb
		k.material_override = kante
		stufe.add_child(k)
		k.position = Vector3(0, 0.045, -box.size.z / 2.0)
		stufe.scale = Vector3(1, 0.01, 1)
		stufen.append(stufe)
	# Geländer: zwei schräge Lichtstäbe über den Stufen
	var unten := Vector3(von.x, 0.35, von.z)
	var oben := Vector3(von.x, 0.0, von.z) + r * lang + Vector3(0, ego.hd.H + 0.35, 0)
	for seite: float in [-1.0, 1.0]:
		var g := MeshInstance3D.new()
		var gb := BoxMesh.new()
		var a3 := unten + quer * 0.38 * seite
		var b3 := oben + quer * 0.38 * seite
		gb.size = Vector3(0.03, 0.03, a3.distance_to(b3))
		g.mesh = gb
		g.material_override = gelaender
		ego._treppe.add_child(g)
		g.position = (a3 + b3) / 2.0
		g.look_at_from_position(g.position, b3, Vector3.UP)
		g.visible = false
		g.set_meta("gelaender", true)
	# Lichtring am Fuß: hier geht es hinauf
	var ring := MeshInstance3D.new()
	var tor := TorusMesh.new()
	tor.inner_radius = 0.32
	tor.outer_radius = 0.4
	ring.mesh = tor
	ring.material_override = ego._leucht(lf, 0.9, 2.5)
	ego._treppe.add_child(ring)
	ring.position = Vector3(von.x, 0.04, von.z)
	ring.set_meta("fussring", true)
	ego._treppe.set_meta("stufen", stufen)
	ego._treppe.set_meta("mats", [flaeche, kante, gelaender, ring.material_override])
	_treppe_aufbau = 0.0


## Aufbau (Stufen springen nacheinander mit Überschwung auf, Lichtstrahl aus der Hand), Halten (Fußring pulsiert),
## Ausklingen (die letzten 1,5 s blinkt die Treppe, dann verblasst sie).
func _treppe_weiter() -> void:
	if ego._treppe == null:
		return
	var dt := ego.get_process_delta_time()
	if _treppe_aufbau >= 0.0:
		_treppe_aufbau += dt
		var stufen: Array = ego._treppe.get_meta("stufen")
		for i in stufen.size():
			var t0 := EgoModus.TREPPE_AUFBAU * 0.8 * float(i) / float(stufen.size())
			var x := clampf((_treppe_aufbau - t0) / 0.14, 0.0, 1.0)
			var s := 1.0 + 2.70158 * pow(x - 1.0, 3) + 1.70158 * pow(x - 1.0, 2)   # Ease-out-back: kurz über 1, dann 1
			(stufen[i] as Node3D).scale = Vector3(lerpf(0.6, 1.0, x), maxf(0.01, s), lerpf(0.6, 1.0, x))
		if _treppe_aufbau < EgoModus.TREPPE_AUFBAU:
			var oben := ego._zu3d(ego.karte.mitte(ego._kletter_zelle), ego.hd.H)
			var hand := ego.hd.kamera.global_position + ego._blick() * 0.4 - ego._rechts() * 0.2 - Vector3(0, 0.18, 0)
			ego._strahl(hand, oben.lerp(ego._treppe_fuss, 1.0 - _treppe_aufbau / EgoModus.TREPPE_AUFBAU), ego._licht_farbe())
		else:
			_treppe_aufbau = -1.0
			for c: Node in ego._treppe.get_children():
				if c.has_meta("gelaender"):
					(c as Node3D).visible = true
			Ton.spiele(ego.spiel, "ui-klick", -4.0)
	# Fußring pulsiert, solange man hinauf kann
	for c: Node in ego._treppe.get_children():
		if c.has_meta("fussring"):
			var p := 1.0 + 0.15 * sin(Time.get_ticks_msec() / 150.0)
			(c as Node3D).scale = Vector3(p, 1.0, p)
			(c as Node3D).visible = not ego._abwaerts and not ego.brakk.oben
	if ego._klettern >= 0.0:
		return
	if ego._treppe_rest <= 0.0:
		ego._treppe.queue_free()
		ego._treppe = null
		_treppe_fuss2d = Vector2.INF
		return
	var sicht := 1.0
	if ego._treppe_rest < 1.5:
		sicht = (0.35 if int(ego._treppe_rest * 8.0) % 2 == 0 else 1.0) * clampf(ego._treppe_rest / 0.5, 0.0, 1.0)
	var mats: Array = ego._treppe.get_meta("mats")
	var grund := [0.55, 0.95, 0.8, 0.9]
	for i in mats.size():
		(mats[i] as StandardMaterial3D).albedo_color.a = float(grund[i]) * sicht
	# an den Fuß gelaufen: hinauf
	if _treppe_fuss2d != Vector2.INF and not ego.brakk.oben and _absprung < 0.0 and ego._fuss2d().distance_to(_treppe_fuss2d) <= Werte.ZELLE * 0.4:   # 19.11.: nicht mitten im Absprung
		_steige_hinauf()


## 20.11. (Paul): Befehl 24 – Q und E (Anker, Lichtbrücke; die Treppe über kletter_abklingzeit) laden langsamer, man ist eher eingekesselt.
func _mobil() -> float:
	return ego.spiel.order24.wf("mobil_abkling") / 100.0 if ego.spiel.order24 != null else 1.0


var _anker := -1.0               # läuft: Sekunden seit dem Abschuss (-1 = nein)
var _anker_von := Vector3.ZERO
var _anker_nach := Vector3.ZERO
var _anker_dauer := 0.5
var _anker_wall := Karte.KEINE
var _anker_rest := 0.0
var _anker_seil: MeshInstance3D = null
var _anker_haken: MeshInstance3D = null
var _fov_weit := 0.0             # Sichtfeld weiter beim Fliegen (Grad)


## Ziel unter dem Fadenkreuz: [Punkt 3D, Wallzelle oder KEINE] oder [].
func _anker_ziel() -> Array:
	var von := ego.hd.kamera.global_position
	var r := ego._blick()
	var t := ego._strahl_bis(von, r, EgoModus.ANKER_WEITE)
	if t >= EgoModus.ANKER_WEITE - 0.05:
		return []
	var p := von + r * t
	var z := Vector2i(floori(p.x + r.x * 0.03), floori(p.z + r.z * 0.03))
	if ego.hd.ist_hoch(z) and ego.karte.inhalt(z) == Karte.WALL and z != ego.karte.zelle_bei(ego._fuss2d()):
		return [ego._zu3d(ego.karte.mitte(z), ego.hd.H), z]
	if p.y <= 0.02 and ego._passt_unten(ego._zu2d(p)):
		return [Vector3(p.x, 0.0, p.z), Karte.KEINE]
	return []


func _anker_start() -> void:
	if _haken >= 0.0:
		_anker_ziehen()   # 19.11. (Paul): zweites [Q] zieht heran
		return
	if _anker >= 0.0 or ego._klettern >= 0.0 or ego._tumble >= 0.0 or _absprung >= 0.0 or not ego._darf("anker"):
		return
	if _anker_rest > 0.0:
		ego.spiel.melde("Lichtanker wieder in %.0f s." % ceilf(_anker_rest), 1.5)
		return
	var ziel := _anker_ziel()
	if ziel.is_empty():
		ego.spiel.melde("Kein Halt für den Lichtanker – auf eine Mauerkrone oder den Boden zielen (bis %d Felder)." % int(EgoModus.ANKER_WEITE), 2.0)
		return
	# 19.11. (Paul): der Haken bleibt hängen – [Q] noch einmal zieht heran, dazwischen laufen, springen, schwingen
	_haken = 0.0
	ego._zaehle("anker")
	_haken_p = ziel[0]
	_haken_wall = ziel[1]
	_seil_lang = maxf(1.0, ego._fuss3d().distance_to(_haken_p))
	ego._hand_zeigen = maxf(ego._hand_zeigen, 0.5)
	ego._trauma = minf(1.0, ego._trauma + 0.1)
	ego._kick += 0.02
	Ton.spiele(ego.spiel, "tc-arc", -3.0)
	if not _anker_erklaert:
		_anker_erklaert = true
		ego.spiel.melde("Lichtanker hängt: nochmal Anker ([Q]) zieht dich hin · laufen und springen = schwingen · in der Luft nochmal springen = abschnellen.", 4.0)
	if _anker_seil == null:
		_anker_seil = MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.05, 0.05, 1.0)
		_anker_seil.mesh = box
		_anker_seil.material_override = ego._leucht(EgoModus.LICHT, 0.9, 3.0)
		ego.hd.add_child(_anker_seil)
		_anker_haken = MeshInstance3D.new()
		var tor := TorusMesh.new()
		tor.inner_radius = 0.12
		tor.outer_radius = 0.2
		_anker_haken.mesh = tor
		_anker_haken.material_override = ego._leucht(Color("e8fbff"), 1.0, 3.5)
		ego.hd.add_child(_anker_haken)
	var lf := ego._licht_farbe()   # 18.11. (Paul): in der Farbe des aktiven Rings
	for mi: MeshInstance3D in [_anker_seil, _anker_haken]:
		var am := mi.material_override as StandardMaterial3D
		am.albedo_color = Color(lf if mi == _anker_seil else lf.lightened(0.7), am.albedo_color.a)
		am.emission = lf
	_anker_seil.visible = true
	_anker_haken.visible = true


func _anker_weiter(dt: float) -> void:
	_anker += dt
	var f := clampf(_anker / _anker_dauer, 0.0, 1.0)
	var weich := f * f * (3.0 - 2.0 * f)
	var p := _anker_von.lerp(_anker_nach, weich)
	ego.hoehe = lerpf(_anker_von.y, _anker_nach.y, weich) + sin(f * PI) * 0.45
	ego.brakk.position = ego._zu2d(p)
	_fov_weit = 9.0 * sin(f * PI)
	ego._geht = false
	_seil_zeichnen(_anker_nach, _anker + 1.0)   # der Haken sitzt schon
	if f < 1.0:
		return
	# angekommen
	_anker = -1.0
	_fov_weit = 0.0
	_anker_seil.visible = false
	_anker_haken.visible = false
	ego._trauma = minf(1.0, ego._trauma + 0.25)
	ego._rueckstoss[0] = 0.7
	ego._rueckstoss[1] = 0.7
	Ton.spiele(ego.spiel, "hit-thud", -4.0)
	ego._funke(_anker_nach + Vector3(0, 0.05, 0), 0.25)
	if _anker_wall != Karte.KEINE:
		ego.brakk.oben = true
		ego.brakk.posten_zelle = _anker_wall
		ego.brakk.zustand = Einheit.Zustand.AUF_POSTEN
		ego.brakk.position = ego.karte.mitte(_anker_wall) + Vector2(0, -12)
		ego.brakk.anker = ego.brakk.position
		ego.hoehe = ego.hd.H
	else:
		ego.hoehe = 0.0
		ego._setze_fuss(ego._zu2d(_anker_nach))


# ------------------------------------------------------------------ Brakk-Mode: Lichtbrücke [E] auf dem Wall (18.11.)

var _bruecke_cd := 0.0
var _bruecke: Node3D = null
var _bruecke_felder := {}         # Zellen unter der Bahn: dort darf Brakk oben gehen
var _bruecke_rest := 0.0
var _bruecke_aufbau := -1.0


## Zellen zwischen dem eigenen Wallstück und dem nächsten Wall in Blickrichtung: [Lücke (Array), Start, Ende] oder [].
func _bruecke_ziel() -> Array:
	if not ego.brakk.oben:
		return []
	var fuss := ego._fuss2d()
	var v := Vector2(ego._vorne().x, ego._vorne().z).normalized()
	var luecke: Array[Vector2i] = []
	var start := Vector2.INF
	var t := 0.0
	while t <= EgoModus.BRUECKE_WEITE + 1.0:
		var p := fuss + v * t * Werte.ZELLE
		var z := ego.karte.zelle_bei(p)
		if not ego.karte.in_karte(z):
			return []
		if ego.hd.ist_hoch(z):
			if not luecke.is_empty():
				return [luecke, start, p] if luecke.size() <= int(EgoModus.BRUECKE_WEITE) else []
		else:
			if start == Vector2.INF:
				start = p
			if not luecke.has(z):
				luecke.append(z)
		t += 0.1
	return []


func _versuche_bruecke() -> bool:
	var ziel := _bruecke_ziel()
	if ziel.is_empty():
		return false
	if _bruecke_cd > 0.0:
		ego.spiel.melde("Lichtbrücke wieder in %.0f s." % ceilf(_bruecke_cd), 1.5)
		return true   # [E] nicht als „hinunter“ verstehen
	if _bruecke != null:
		_bruecke.queue_free()
	_bruecke_felder.clear()
	for z: Vector2i in ziel[0]:
		_bruecke_felder[z] = true
	var a := ego._zu3d(ziel[1] as Vector2, ego.hd.H)
	var b := ego._zu3d(ziel[2] as Vector2, ego.hd.H)
	_bruecke = Node3D.new()
	ego.hd.add_child(_bruecke)
	var lf := ego._licht_farbe()   # 18.11. (Paul): in der Farbe des aktiven Rings
	var flaeche := ego._leucht(lf, 0.5, 1.8)
	var kante := ego._leucht(lf.lightened(0.7), 0.95, 3.0)
	var r := (b - a)
	var lang := r.length()
	r = r.normalized()
	var quer := Vector3(r.z, 0.0, -r.x)
	var n := maxi(3, ceili(lang / 0.4))
	var planken: Array = []
	for i in n:
		var pl := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.8, 0.05, lang / n - 0.04)
		pl.mesh = box
		pl.material_override = flaeche
		_bruecke.add_child(pl)
		pl.position = a + r * (lang * (float(i) + 0.5) / n) + Vector3(0, 0.01, 0)
		pl.rotation.y = atan2(r.x, r.z)
		pl.scale = Vector3(0.01, 1, 1)
		planken.append(pl)
	for seite: float in [-1.0, 1.0]:
		for hoch: float in [0.04, 0.45]:
			var g := MeshInstance3D.new()
			var gb := BoxMesh.new()
			gb.size = Vector3(0.03, 0.03, lang)
			g.mesh = gb
			g.material_override = kante
			_bruecke.add_child(g)
			g.position = (a + b) / 2.0 + quer * 0.42 * seite + Vector3(0, hoch, 0)
			g.rotation.y = atan2(r.x, r.z)
			g.visible = false
			g.set_meta("gelaender", true)
	_bruecke.set_meta("planken", planken)
	_bruecke.set_meta("mats", [flaeche, kante])
	_bruecke_rest = EgoModus.BRUECKE_HALTEN
	_bruecke_aufbau = 0.0
	_bruecke_cd = EgoModus.BRUECKE_ABKLING * _mobil()
	ego._hand_zeigen = maxf(ego._hand_zeigen, EgoModus.BRUECKE_AUFBAU + 0.2)
	ego._trauma = minf(1.0, ego._trauma + 0.12)
	Ton.spiele(ego.spiel, "tc-arc", -5.0)
	ego.spiel.melde("Lichtbrücke steht %d s – hinüber!" % int(EgoModus.BRUECKE_HALTEN), 2.0)
	return true


func _auf_bruecke(z: Vector2i) -> bool:
	return _bruecke != null and _bruecke_felder.has(z)


func _bruecke_weiter(dt: float) -> void:
	_bruecke_cd = maxf(0.0, _bruecke_cd - dt)
	if _bruecke == null:
		return
	_bruecke_rest -= dt
	if _bruecke_aufbau >= 0.0:
		_bruecke_aufbau += dt
		var planken: Array = _bruecke.get_meta("planken")
		for i in planken.size():
			var t0 := EgoModus.BRUECKE_AUFBAU * 0.8 * float(i) / float(planken.size())
			var x := clampf((_bruecke_aufbau - t0) / 0.12, 0.0, 1.0)
			var s := 1.0 + 2.70158 * pow(x - 1.0, 3) + 1.70158 * pow(x - 1.0, 2)
			(planken[i] as Node3D).scale = Vector3(maxf(0.01, s), 1.0, 1.0)
		if _bruecke_aufbau >= EgoModus.BRUECKE_AUFBAU:
			_bruecke_aufbau = -1.0
			for c: Node in _bruecke.get_children():
				if c.has_meta("gelaender"):
					(c as Node3D).visible = true
			Ton.spiele(ego.spiel, "ui-klick", -4.0)
	var sicht := 1.0
	if _bruecke_rest < 1.5:
		sicht = (0.35 if int(_bruecke_rest * 8.0) % 2 == 0 else 1.0) * clampf(_bruecke_rest / 0.5, 0.0, 1.0)
	var mats: Array = _bruecke.get_meta("mats")
	(mats[0] as StandardMaterial3D).albedo_color.a = 0.5 * sicht
	(mats[1] as StandardMaterial3D).albedo_color.a = 0.95 * sicht
	if _bruecke_rest > 0.0:
		return
	_bruecke.queue_free()
	_bruecke = null
	var hier := ego.karte.zelle_bei(ego._fuss2d())
	var war_drauf := _bruecke_felder.has(hier) and ego.brakk.oben
	_bruecke_felder.clear()
	if war_drauf:
		# die Brücke erlischt unter Brakk: hinunter – oder, wo kein Platz ist, zurück auf den letzten Wall
		var unten := ego._fuss2d()
		if ego._passt_unten(unten):
			ego.brakk.oben = false
			ego.brakk.posten_zelle = Karte.KEINE
			ego.brakk.zustand = Einheit.Zustand.BODEN
			ego._setze_fuss(unten)
		else:
			ego._setze_fuss(ego.karte.mitte(ego.brakk.posten_zelle))


func _doppelsprung() -> void:
	ego._zaehle("spruenge")
	if ego.brakk.oben and _absprung_start():
		return   # 19.11. (Paul): vom Wall hinunter, unten die Druckwelle
	ego._doppelt_genutzt = true
	ego.steig = EgoModus.DOPPEL_SPRUNG
	if _haken >= 0.0:
		ego._flug *= EgoModus.ABSCHNELLEN_MAL   # 19.11.: am Seil – das Seil löst sich, der Schwung bleibt
		_haken_los()
	_lichtplattform()


## Sechseckige Lichtplattform unter Brakks Füßen, in der Farbe des aktiven Rings (springt auf, dreht sich, verblasst).
func _lichtplattform() -> void:
	var farbe := ego._licht_farbe()
	var p := Node3D.new()
	ego.hd.add_child(p)
	p.position = ego._fuss3d() - Vector3(0, 0.04, 0)
	var platte := MeshInstance3D.new()
	var zyl := CylinderMesh.new()
	zyl.top_radius = 0.45
	zyl.bottom_radius = 0.38
	zyl.height = 0.06
	zyl.radial_segments = 6   # sechseckig, wie eine Lichtkachel
	platte.mesh = zyl
	platte.material_override = ego._leucht(farbe, 0.6, 2.2)
	p.add_child(platte)
	var rand := MeshInstance3D.new()
	var tor := TorusMesh.new()
	tor.inner_radius = 0.44
	tor.outer_radius = 0.5
	tor.ring_segments = 6
	tor.rings = 6
	rand.mesh = tor
	rand.material_override = ego._leucht(farbe.lightened(0.6), 0.95, 3.0)
	rand.position.y = 0.03
	p.add_child(rand)
	p.scale = Vector3(0.2, 1.0, 0.2)
	ego._plattformen.append([p, 0.0])
	ego._trauma = minf(1.0, ego._trauma + 0.08)
	ego._rueckstoss[0] = 0.4
	ego._rueckstoss[1] = 0.4
	Ton.spiele(ego.spiel, "tc-arc", -8.0)


func _plattformen_weiter(dt: float) -> void:
	for e: Array in ego._plattformen:
		e[1] = float(e[1]) + dt
		var p: Node3D = e[0]
		var t := float(e[1])
		var x := clampf(t / 0.12, 0.0, 1.0)
		var s := 1.0 + 2.70158 * pow(x - 1.0, 3) + 1.70158 * pow(x - 1.0, 2)   # Ease-out-back
		var weit := maxf(0.2, s) + 0.15 * t
		p.scale = Vector3(weit, 1.0, weit)
		p.rotation.y += dt * 2.0
		var a := clampf(1.0 - (t - EgoModus.PLATTFORM_SEK * 0.5) / (EgoModus.PLATTFORM_SEK * 0.5), 0.0, 1.0)
		for c: Node in p.get_children():
			var m := (c as MeshInstance3D).material_override as StandardMaterial3D
			m.albedo_color.a = a * (0.6 if c == p.get_child(0) else 0.95)
	var weg := ego._plattformen.filter(func(e: Array) -> bool: return float(e[1]) >= EgoModus.PLATTFORM_SEK)
	for e: Array in weg:
		(e[0] as Node).queue_free()
	ego._plattformen = ego._plattformen.filter(func(e: Array) -> bool: return float(e[1]) < EgoModus.PLATTFORM_SEK)


# ------------------------------------------------------------------ Brakk-Mode: Absprung vom Wall mit Druckwelle (19.11.)

var _absprung := -1.0            # läuft: Sekunden seit dem Abstoßen (-1 = nein)
var _ab_von := Vector3.ZERO
var _ab_nach := Vector3.ZERO
var _ab_dauer := 0.5


func _absprung_start() -> bool:
	var r := ego._lauf.normalized() if ego._lauf != Vector2.ZERO else Vector2(ego._vorne().x, ego._vorne().z).normalized()
	var ziel := Vector2.INF
	var w := 1.0
	while w <= EgoModus.ABSPRUNG_WEITE and ziel == Vector2.INF:
		var p := ego._fuss2d() + r * w * Werte.ZELLE
		if ego._passt_unten(p) and not ego.hd.ist_hoch(ego.karte.zelle_bei(p)):
			ziel = p
		w += 0.25
	if ziel == Vector2.INF:
		return false
	ego._doppelt_genutzt = true
	_lichtplattform()
	if _haken >= 0.0:
		_haken_los()
	ego._treppe_rest = minf(ego._treppe_rest, 0.0)   # die Treppe vergeht – sonst führt sie unten gleich wieder hinauf
	_ab_von = ego._fuss3d()
	_ab_nach = ego._zu3d(ziel, 0.0)
	_ab_dauer = clampf(_ab_von.distance_to(_ab_nach) / 6.0, 0.4, 0.7)
	_absprung = 0.0
	ego.steig = 0.0
	ego._flug = Vector2.ZERO
	ego.brakk.oben = false
	ego.brakk.posten_zelle = Karte.KEINE
	ego.brakk.zustand = Einheit.Zustand.BODEN
	return true


func _absprung_weiter(dt: float) -> void:
	_absprung += dt
	var f := clampf(_absprung / _ab_dauer, 0.0, 1.0)
	var p := _ab_von.lerp(_ab_nach, f)
	ego.hoehe = lerpf(_ab_von.y, 0.0, f * f) + sin(f * PI) * 0.6   # erst hoch, dann steil hinunter
	ego.brakk.position = ego._zu2d(p)
	_fov_weit = 6.0 * sin(f * PI)
	ego._geht = false
	if f < 1.0:
		return
	_absprung = -1.0
	_fov_weit = 0.0
	ego.hoehe = 0.0
	ego._setze_fuss(ego._zu2d(_ab_nach))
	ego._doppelt_genutzt = false
	ego._delle = 1.0
	ego._rueckstoss[0] = 0.8
	ego._rueckstoss[1] = 0.8
	_druckwelle(ego._zu2d(_ab_nach))


func _druckwelle(p: Vector2) -> void:
	var r := EgoModus.DRUCK_RADIUS * Werte.ZELLE
	ego.spiel.effekte.flaeche(p, r, ego._licht_farbe())
	ego._einschlag(p, r, EgoModus.DRUCK_SCHADEN, 0.9, "absprung")
	Ton.spiele(ego.spiel, "hit-thud", -2.0)


# ------------------------------------------------------------------ Brakk-Mode: Lichtanker hängt, Schwingen (19.11.)

var _haken := -1.0               # hängt: Sekunden seit dem Wurf (-1 = nein)
var _haken_p := Vector3.ZERO
var _haken_wall := Karte.KEINE
var _seil_lang := 1.0
var _anker_erklaert := false


func _anker_ziehen() -> void:
	_anker_von = ego._fuss3d()
	_anker_nach = _haken_p
	_anker_wall = _haken_wall
	_anker_dauer = maxf(0.25, _anker_von.distance_to(_anker_nach) / EgoModus.ANKER_TEMPO)
	_anker = 0.0
	_haken = -1.0
	_anker_rest = EgoModus.ANKER_ABKLING * _mobil()
	ego.steig = 0.0
	ego._flug = Vector2.ZERO
	if ego.brakk.oben:
		ego.brakk.oben = false
		ego.brakk.posten_zelle = Karte.KEINE
		ego.brakk.zustand = Einheit.Zustand.BODEN
	ego._hand_zeigen = maxf(ego._hand_zeigen, _anker_dauer + 0.2)
	ego._trauma = minf(1.0, ego._trauma + 0.15)
	ego._kick += 0.03
	Ton.spiele(ego.spiel, "tc-rail", -10.0)


func _haken_los() -> void:
	_haken = -1.0
	_anker_rest = EgoModus.ANKER_ABKLING * _mobil()
	if _anker_seil != null:
		_anker_seil.visible = false
		_anker_haken.visible = false


func _haken_weiter(dt: float) -> void:
	_haken += dt
	if _haken >= EgoModus.HAKEN_HALTEN or ego.brakk.gefallen:
		_haken_los()
		return
	ego._hand_zeigen = maxf(ego._hand_zeigen, 0.3)
	var fuss := ego._fuss3d()
	var d := fuss - _haken_p
	var luft := ego.hoehe > ego._boden() + 0.001 or ego.steig > 0.0
	if luft and d.length() > _seil_lang * 0.9:
		ego.steig += EgoModus.SCHWERE * EgoModus.SCHWING_LEICHT * dt   # das straffe Seil trägt mit
	if d.length() > _seil_lang:
		var n := d.normalized()
		if luft:
			var soll := _haken_p + n * _seil_lang
			var s := Vector2(soll.x - fuss.x, soll.z - fuss.z) * Werte.ZELLE
			ego._luft_schritt(Vector2(s.x, 0.0))
			ego._luft_schritt(Vector2(0.0, s.y))
			ego.hoehe = maxf(ego._boden(), soll.y)
			var v := Vector3(ego._flug.x, ego.steig, ego._flug.y)
			var raus := v.dot(n)
			if raus > 0.0:
				v -= n * raus   # nur noch quer zum Seil: Schwingen
			ego._flug = Vector2(v.x, v.z)
			ego.steig = v.y
		else:
			# am Boden: eine Leine – weiter als das Seil geht es nicht
			var dy := fuss.y - _haken_p.y
			var waag := sqrt(maxf(0.0, _seil_lang * _seil_lang - dy * dy))
			var dh := Vector2(d.x, d.z)
			if dh.length() > waag:
				var s := (dh.normalized() * waag - dh) * Werte.ZELLE
				ego._schritt(Vector2(s.x, 0.0))
				ego._schritt(Vector2(0.0, s.y))
	_seil_zeichnen(_haken_p, _haken)


## Schwung in der Luft weitertragen; bei der Landung ist er weg.
func _flug_weiter(dt: float) -> void:
	if ego._flug == Vector2.ZERO:
		return
	if ego.hoehe <= ego._boden() + 0.001 and ego.steig <= 0.0:
		ego._flug = Vector2.ZERO
		return
	var s := ego._flug * dt * Werte.ZELLE
	if not ego._luft_schritt(Vector2(s.x, 0.0)):
		ego._flug.x = 0.0
	if not ego._luft_schritt(Vector2(0.0, s.y)):
		ego._flug.y = 0.0


## Seil von der Ringhand zum Haken; der Haken dreht sich. In den ersten 0,12 s fliegt er erst hinaus.
func _seil_zeichnen(ziel: Vector3, t: float) -> void:
	if _anker_seil == null:
		return
	var hand := ego.hd.kamera.global_position + ego._blick() * 0.35 - ego._rechts() * 0.22 - Vector3(0, 0.2, 0)
	var haken := hand.lerp(ziel + Vector3(0, 0.05, 0), clampf(t / 0.12, 0.0, 1.0))
	var lang := maxf(0.05, hand.distance_to(haken))
	_anker_seil.scale = Vector3(1.0 + 0.4 * sin(t * 40.0), 1.0, lang)
	_anker_seil.position = (hand + haken) / 2.0
	_anker_seil.look_at_from_position(_anker_seil.position, haken, Vector3.UP if absf((haken - hand).normalized().y) < 0.99 else Vector3.RIGHT)
	_anker_haken.position = haken
	_anker_haken.rotation = Vector3(PI / 2.0, t * 8.0, 0.0)
