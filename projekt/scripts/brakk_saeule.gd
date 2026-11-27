class_name BrakkSaeule
extends RefCounted
## Lichtsäule [X] und Zeitlupe [V] im Brakk-Mode (18.11.; 27.11. Knoten-Umbau Schritt 7a – vorher in ego_modus.gd):
## Zielen, Drehen (Durchschlagring), Bestätigen, Vorlauf mit Fingerwirbel, Einschlag je aktivem Ring (Wirbel, Feuerteam,
## Sprünge …), sichtbare Säulen, Zeitlupe. Regeln unverändert; die Zahlen stehen weiter in ego_modus.gd
## (EgoModus.SAEULE_*, ZEITLUPE_*). Teil der Ego-Sicht wie EgoKit (`ego.saeule`, angelegt in EgoModus._init); Zugriff auf Brakk über `ego`.

const Stil := preload("res://scripts/ui/ui_stil.gd")

var ego: EgoModus


func _init(e: EgoModus) -> void:
	ego = e


var _saeule_rest := 0.0
var _saeule_zielt := false       # [X] gedrückt: Marke folgt dem Fadenkreuz
var _saeule_ziel := Vector2.INF  # bestätigter Punkt (2D), INF = keiner
var _saeule_t := 0.0             # Sekunden seit dem Bestätigen
var _saeule_marke: Node3D = null
var _saeule_farbe := Color("fff3a0")
var _saeule_ring := ""
var _saeule_blick := Vector2.UP  # Richtung beim Bestätigen (Linie des Durchschlagrings, Dreieck des Feuerteams)
const SAEULE_DREH_MIN := 14.0    # Bildpunkte Mausweg, ab dem ein gehaltener Klick als Drehen zählt
var _saeule_dreht := false       # Durchschlagring: Linksklick gehalten, Maus dreht die Linie
var _saeule_dir := Vector2.UP    # gedrehte Richtung
var _saeule_fix := Vector2.INF   # festgehaltene Marke beim Drehen
var _saeule_pix := 0.0
var _saeule_form: Node3D = null  # Form des Einschlags (Vorschau und Vorlauf)
var _saeule_form_ring := "?"
var _einschlaege: Array = []     # noch ausstehende Einschläge: [Restzeit, Punkt, Radius, Schaden]
var _wirbel_saeule: Array = []   # Wirbelring: [Punkt, Restzeit, Takt]
var _saeulen: Array = []         # sichtbare Lichtsäulen: [MeshInstance3D, Alter, Dauer]
var _zeitlupe := 0.0             # Restzeit (Echtzeit)
var _zeitlupe_rest := 0.0
var _zl_vorher := 1.0


## [X]: zielen bzw. abbrechen.
func _saeule_x() -> void:
	if _saeule_zielt:
		_saeule_abbrechen()
		return
	if not ego._darf("saeule") or _saeule_ziel != Vector2.INF:
		return
	if _saeule_rest > 0.0:
		ego.spiel.melde("Lichtsäule wieder in %.0f s." % ceilf(_saeule_rest), 1.5)
		return
	_saeule_zielt = true
	ego._feuer = false
	_saeule_ring = ego.brakk.fortschritt.aktiv() if ego.brakk.fortschritt != null else ""
	_saeule_farbe = ego._ring_farbe(_saeule_ring) if _saeule_ring != "" else Color("fff3a0")
	_baue_saeule_marke()
	Ton.spiele(ego.spiel, "ui-klick", -4.0)


func _saeule_abbrechen() -> void:
	_saeule_zielt = false
	_saeule_dreht = false
	if _saeule_marke != null:
		_saeule_marke.visible = false
	if _saeule_form != null:
		_saeule_form.visible = false


func _blick2d() -> Vector2:
	return Vector2(ego._vorne().x, ego._vorne().z).normalized()


## 22.11.: Durchschlagring – Linksklick gehalten fixiert die Marke, die Maus dreht die Linie, Loslassen setzt.
func _saeule_dreh_start() -> void:
	var p := ego.ziel_welt()
	if p.x < -9000.0 or p.distance_to(ego._fuss2d()) > EgoModus.SAEULE_WEITE * Werte.ZELLE:
		ego.spiel.melde("Zu weit für die Lichtsäule (höchstens %d Felder)." % int(EgoModus.SAEULE_WEITE), 1.5)
		return
	_saeule_dreht = true
	_saeule_fix = p
	_saeule_dir = _blick2d()
	_saeule_pix = 0.0


func _saeule_dreh_ende() -> void:
	if not _saeule_dreht:
		return
	_saeule_dreht = false
	# kurzer Klick (Maus kaum bewegt) = Blickrichtung wie bisher
	_saeule_bestaetigen(_saeule_fix, _saeule_dir if _saeule_pix >= SAEULE_DREH_MIN else _blick2d())


## Richtung der Form: beim Drehen die gedrehte, sonst live die Blickrichtung (Vorschau = Einschlag).
func _saeule_richtung() -> Vector2:
	return _saeule_dir if _saeule_dreht else _blick2d()


## Linksklick beim Zielen: hier soll sie einschlagen. Ohne Angabe: Punkt unter dem Fadenkreuz, Blickrichtung.
func _saeule_bestaetigen(punkt: Vector2 = Vector2.INF, richtung: Vector2 = Vector2.ZERO) -> void:
	var p := ego.ziel_welt() if punkt == Vector2.INF else punkt
	if p.x < -9000.0 or p.distance_to(ego._fuss2d()) > EgoModus.SAEULE_WEITE * Werte.ZELLE:
		ego.spiel.melde("Zu weit für die Lichtsäule (höchstens %d Felder)." % int(EgoModus.SAEULE_WEITE), 1.5)
		return
	_saeule_zielt = false
	_saeule_dreht = false
	_saeule_ziel = p
	_saeule_t = 0.0
	ego._zaehle("saeulen")
	if ego.spiel.order24 != null:
		ego.spiel.order24.brakk_aktion("saeule")   # C2 (26.11.): der Technogunner kennt den Trick ab der dritten
	_saeule_rest = EgoModus.SAEULE_ABKLING
	_saeule_blick = richtung if richtung != Vector2.ZERO else _blick2d()
	ego._hand_zeigen = maxf(ego._hand_zeigen, EgoModus.SAEULE_VORLAUF + 0.3)   # Brakk wirbelt mit dem Finger, bis die Säule einschlägt
	Ton.spiele(ego.spiel, "alert", -6.0)


func _baue_saeule_marke() -> void:
	if _saeule_marke == null:
		_saeule_marke = Node3D.new()
		ego.hd.add_child(_saeule_marke)
		for i in 2:
			var m := MeshInstance3D.new()
			var tor := TorusMesh.new()
			tor.inner_radius = EgoModus.SAEULE_RADIUS * (1.0 if i == 0 else 0.35) - 0.06
			tor.outer_radius = EgoModus.SAEULE_RADIUS * (1.0 if i == 0 else 0.35)
			tor.rings = 48
			m.mesh = tor
			m.material_override = ego._leucht(Color("fff3a0"), 0.9, 3.0)
			_saeule_marke.add_child(m)
	var gross := 0.6 if _saeule_ring == "laser" else 1.0
	_saeule_marke.scale = Vector3(gross, 1.0, gross)
	for m: MeshInstance3D in _saeule_marke.get_children():
		var mm := m.material_override as StandardMaterial3D
		mm.albedo_color = Color(_saeule_farbe.lightened(0.3), 0.9)
		mm.emission = _saeule_farbe
	_saeule_marke.visible = true
	_baue_saeule_form()


## 22.11.: Einschlagpunkte je Ring [[Verzögerung, Punkt, Radius, Schaden]] – Vorschau und Einschlag rechnen hier gleich.
func saeule_punkte(ring: String, p: Vector2, dir: Vector2) -> Array:
	var r := EgoModus.SAEULE_RADIUS * Werte.ZELLE
	var aus: Array = []
	match ring:
		"durchschuss":   # schmale Säulen in einer Linie durch 5 Felder
			for i in 5:
				aus.append([0.06 * i, p + dir * (float(i) - 2.0) * Werte.ZELLE, Werte.ZELLE * 0.65, EgoModus.SAEULE_SCHADEN])
		"feuerteam":   # drei kleinere Einschläge im Dreieck: 0°/120°/240° ab Blickrichtung
			for i in 3:
				aus.append([0.22 * i, p + dir.rotated(TAU * float(i) / 3.0) * Werte.ZELLE * 0.8, r * 0.7, EgoModus.SAEULE_SCHADEN * 0.55])
	return aus


func _form_ring(radius: float, alpha: float, dick: float = 0.07) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var tor := TorusMesh.new()
	tor.inner_radius = maxf(0.01, radius - dick)
	tor.outer_radius = radius
	tor.rings = 40
	m.mesh = tor
	m.material_override = ego._leucht(_saeule_farbe.lightened(0.3), alpha, 2.0)
	return m


func _form_klotz(groesse: Vector3, pos: Vector3, alpha: float) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = groesse
	m.mesh = b
	m.position = pos
	m.material_override = ego._leucht(_saeule_farbe.lightened(0.3), alpha, 2.0)
	return m


## Form des Einschlags (halbtransparent in der Ringfarbe). Lokal zeigt +X in Wirkrichtung.
func _baue_saeule_form() -> void:
	if _saeule_form == null:
		_saeule_form = Node3D.new()
		ego.hd.add_child(_saeule_form)
	for k in _saeule_form.get_children():
		_saeule_form.remove_child(k)
		k.queue_free()
	_saeule_form_ring = _saeule_ring
	var z := Werte.ZELLE
	match _saeule_ring:
		"durchschuss":
			for e: Array in saeule_punkte("durchschuss", Vector2.ZERO, Vector2.RIGHT):
				var pt := (e[1] as Vector2) / z
				var ring := _form_ring(float(e[2]) / z, 0.6)
				ring.position = Vector3(pt.x, 0.0, pt.y)
				_saeule_form.add_child(ring)
			_saeule_form.add_child(_form_klotz(Vector3(5.0, 0.03, 0.12), Vector3.ZERO, 0.5))
			var pfeil := MeshInstance3D.new()
			var kegel := CylinderMesh.new()
			kegel.top_radius = 0.0
			kegel.bottom_radius = 0.5
			kegel.height = 0.9
			pfeil.mesh = kegel
			pfeil.material_override = ego._leucht(_saeule_farbe.lightened(0.3), 0.7, 2.5)
			pfeil.rotation.z = -PI / 2.0   # Spitze nach +X
			pfeil.position = Vector3(3.25, 0.05, 0.0)
			_saeule_form.add_child(pfeil)
		"feuerteam":
			for e: Array in saeule_punkte("feuerteam", Vector2.ZERO, Vector2.RIGHT):
				var pt := (e[1] as Vector2) / z
				var ring := _form_ring(float(e[2]) / z, 0.6)
				ring.position = Vector3(pt.x, 0.0, pt.y)
				_saeule_form.add_child(ring)
		"brandfeld":   # gestrichelter Außenring in Brandfeldgröße
			var rb := EgoModus.SAEULE_RADIUS * 1.3
			for i in 24:
				var a := TAU * float(i) / 24.0
				var s := _form_klotz(Vector3(0.45, 0.04, 0.1), Vector3(cos(a) * rb, 0.0, sin(a) * rb), 0.65)
				s.rotation.y = -(a + PI / 2.0)   # Längsachse tangential
				_saeule_form.add_child(s)
		"plasmagel":
			_saeule_form.add_child(_form_ring(EgoModus.SAEULE_RADIUS * 1.2, 0.5))
		"abpraller":   # blasser Ring: Reichweite der Sprünge
			_saeule_form.add_child(_form_ring(4.0, 0.25, 0.05))
		"minigun":
			var l := Label3D.new()
			l.text = "bleibt 3 s"
			l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			l.pixel_size = 0.012
			l.font_size = 48
			l.modulate = _saeule_farbe.lightened(0.4)
			l.no_depth_test = true
			l.position = Vector3(0.0, 1.0, 0.0)
			_saeule_form.add_child(l)


## Form an den Punkt setzen (Richtung als 2D-Vektor, Maßstab für das Zusammenziehen im Vorlauf).
func _saeule_form_setze(p: Vector2, dir: Vector2, massstab: float) -> void:
	if _saeule_form == null:
		return
	var h0 := ego.hd.H if ego.hd.ist_hoch(ego.karte.zelle_bei(p)) else 0.0
	_saeule_form.position = ego._zu3d(p, h0 + 0.06)
	_saeule_form.rotation.y = -dir.angle()
	_saeule_form.scale = Vector3(massstab, 1.0, massstab)
	_saeule_form.visible = true


func _saeule_weiter(dt: float) -> void:
	_saeule_rest -= dt
	_saeulen_weiter(dt)
	_einschlaege_weiter(dt)
	if _saeule_zielt:
		# Marke folgt dem Fadenkreuz (halb durchsichtig, solange nicht bestätigt)
		ego._hand_zeigen = maxf(ego._hand_zeigen, 0.3)
		var p := _saeule_fix if _saeule_dreht else ego.ziel_welt()
		_saeule_marke.visible = p.x > -9000.0
		if _saeule_marke.visible:
			var h0 := ego.hd.H if ego.hd.ist_hoch(ego.karte.zelle_bei(p)) else 0.0
			_saeule_marke.position = ego._zu3d(p, h0 + 0.05)
			_saeule_marke.rotation.y += dt * 1.5
			_saeule_form_setze(p, _saeule_richtung(), 1.0)
		elif _saeule_form != null:
			_saeule_form.visible = false
		return
	if _saeule_ziel == Vector2.INF:
		return
	_saeule_t += dt
	var f := clampf(_saeule_t / EgoModus.SAEULE_VORLAUF, 0.0, 1.0)
	var ringe := _saeule_marke.get_children()
	(ringe[1] as Node3D).scale = Vector3.ONE * lerpf(2.8, 1.0, f)
	_saeule_marke.rotation.y += dt * (2.0 + 8.0 * f)
	var h := ego.hd.H if ego.hd.ist_hoch(ego.karte.zelle_bei(_saeule_ziel)) else 0.0
	_saeule_marke.position = ego._zu3d(_saeule_ziel, h + 0.05)
	_saeule_marke.visible = int(_saeule_t * (4.0 + 12.0 * f)) % 2 == 0 or f > 0.9
	_saeule_form_setze(_saeule_ziel, _saeule_blick, lerpf(1.5, 1.0, f))   # zieht sich zusammen
	if _saeule_form != null:
		_saeule_form.visible = _saeule_marke.visible
	if _saeule_t < EgoModus.SAEULE_VORLAUF:
		return
	var p2 := _saeule_ziel
	_saeule_ziel = Vector2.INF
	_saeule_marke.visible = false
	if _saeule_form != null:
		_saeule_form.visible = false
	_saeule_ausloesen(p2)


## Die Art des Einschlags je aktivem Ring.
func _saeule_ausloesen(p: Vector2) -> void:
	var r := EgoModus.SAEULE_RADIUS * Werte.ZELLE
	match _saeule_ring:
		"durchschuss", "feuerteam":   # Linie über 5 Felder bzw. drei kleinere Einschläge im Dreieck
			_einschlaege.append_array(saeule_punkte(_saeule_ring, p, _saeule_blick))
		"laser":   # klein, aber doppelter Schaden
			ego._einschlag(p, r * 0.6, EgoModus.SAEULE_SCHADEN * 2.0, 1.0)
		"minigun":   # die Säule bleibt 3 s stehen, dreht und schadet laufend
			_wirbel_saeule = [p, 3.0, 0.0]
			_neue_saeule(p, r * 0.8, 3.0)
		"abpraller":   # Einschlag, dann springt ein Blitz auf bis zu 3 Gegner in der Nähe
			var getroffen := ego._einschlag(p, r, EgoModus.SAEULE_SCHADEN, 1.0)
			_saeule_sprung(p, getroffen)
		"brandfeld":   # Einschlag und ein großes Brandfeld
			ego._einschlag(p, r, EgoModus.SAEULE_SCHADEN * 0.7, 1.0)
			ego.spiel.lege_brand(p, r * 1.3, EgoModus.SAEULE_SCHADEN * 0.25)
		"plasmagel":   # wenig Schaden, aber alle im Feld 4 s stark gebremst (und mit dem Gelring verwundbar)
			for g: Gegner in ego._einschlag(p, r * 1.2, EgoModus.SAEULE_SCHADEN * 0.4, 1.0):
				if is_instance_valid(g) and not g._tot:
					g.gebremst = maxf(g.gebremst, 4.0)
			ego.spiel.effekte.gel(p, r * 1.2, 4.0)
		_:
			ego._einschlag(p, r, EgoModus.SAEULE_SCHADEN, 1.0)


## Ein Einschlag: Schaden im Kreis (Kills geben Erfahrung), Lichtsäule, Funke, Wackeln. Gibt die getroffenen Gegner zurück.

func _einschlaege_weiter(dt: float) -> void:
	for e: Array in _einschlaege:
		e[0] = float(e[0]) - dt
	var faellig := _einschlaege.filter(func(e: Array) -> bool: return float(e[0]) <= 0.0)
	_einschlaege = _einschlaege.filter(func(e: Array) -> bool: return float(e[0]) > 0.0)
	for e: Array in faellig:
		ego._einschlag(e[1], e[2], e[3], 0.6)
	if _wirbel_saeule.is_empty():
		return
	_wirbel_saeule[1] = float(_wirbel_saeule[1]) - dt
	_wirbel_saeule[2] = float(_wirbel_saeule[2]) - dt
	if float(_wirbel_saeule[2]) <= 0.0:
		_wirbel_saeule[2] = 0.25
		var p: Vector2 = _wirbel_saeule[0]
		ego.spiel.schadensquelle = "fabrik:-1,-1"
		ego.spiel.brakk_quelle = "saeule"
		for g: Gegner in ego.spiel.ego_gegner().duplicate():
			if is_instance_valid(g) and not g._tot and g.position.distance_to(p) <= EgoModus.SAEULE_RADIUS * Werte.ZELLE * 0.8 and not ego.spiel._geschuetzt(g):
				g.nimm_schaden(EgoModus.SAEULE_SCHADEN * 0.12 * ego._faehigkeit_faktor() * ego._gel_bonus(g, true))
				if g._tot:
					ego._kill(g)
		ego.spiel.schadensquelle = ""
		ego.spiel.brakk_quelle = ""
	if float(_wirbel_saeule[1]) <= 0.0:
		_wirbel_saeule = []


## Sprungring: vom Einschlag aus springt ein Blitz nacheinander auf bis zu drei weitere Gegner.
func _saeule_sprung(p: Vector2, schon: Array) -> void:
	var von := p
	var getroffen := schon.duplicate()
	for i in 3:
		var bester: Gegner = null
		var beste := 4.0 * Werte.ZELLE
		for g: Gegner in ego.spiel.ego_gegner():
			if is_instance_valid(g) and not g._tot and not getroffen.has(g) and g.position.distance_to(von) < beste and not ego.spiel._geschuetzt(g):
				beste = g.position.distance_to(von)
				bester = g
		if bester == null:
			return
		ego._strahl(ego._zu3d(von, 0.5), ego._zu3d(bester.position, 0.5), _saeule_farbe)
		ego.spiel.schadensquelle = "fabrik:-1,-1"
		ego.spiel.brakk_quelle = "saeule"
		bester.nimm_schaden(EgoModus.SAEULE_SCHADEN * 0.5 * ego._faehigkeit_faktor() * ego._gel_bonus(bester, true))
		ego.spiel.schadensquelle = ""
		ego.spiel.brakk_quelle = ""
		if bester._tot:
			ego._kill(bester)
		getroffen.append(bester)
		von = bester.position


func _neue_saeule(p: Vector2, radius: float, dauer: float) -> void:
	var m := MeshInstance3D.new()
	var zyl := CylinderMesh.new()
	zyl.top_radius = radius / Werte.ZELLE * 0.7
	zyl.bottom_radius = radius / Werte.ZELLE
	zyl.height = 14.0
	zyl.radial_segments = 24
	m.mesh = zyl
	m.material_override = ego._leucht(_saeule_farbe.lightened(0.25), 0.85, 4.0)
	ego.hd.add_child(m)
	m.position = ego._zu3d(p, 7.0)
	_saeulen.append([m, 0.0, dauer])


func _saeulen_weiter(dt: float) -> void:
	for s: Array in _saeulen:
		s[1] = float(s[1]) + dt
		var m: MeshInstance3D = s[0]
		var alter := float(s[1])
		var dauer := float(s[2])
		var a := 1.0 - clampf((alter - (dauer - 0.45)) / 0.45, 0.0, 1.0) if dauer > 0.5 else 1.0 - alter / dauer
		(m.material_override as StandardMaterial3D).albedo_color.a = maxf(0.0, a) * 0.85
		var weit := 1.0 + (alter * 1.5 if dauer <= 0.5 else 0.08 * sin(alter * 12.0))
		m.scale = Vector3(weit, 1.0, weit)
		m.rotation.y += dt * 6.0
	var weg := _saeulen.filter(func(s: Array) -> bool: return float(s[1]) >= float(s[2]))
	for s: Array in weg:
		(s[0] as Node).queue_free()
	_saeulen = _saeulen.filter(func(s: Array) -> bool: return float(s[1]) < float(s[2]))


## 19.11.: Sprungring – vom Treffer aus springt ein Blitz auf die nächsten Gegner (Anzahl und Anteil aus der Tabelle).

func _zeitlupe_start() -> void:
	if not ego._darf("zeitlupe") or _zeitlupe > 0.0:
		return
	if _zeitlupe_rest > 0.0:
		ego.spiel.melde("Zeitlupe wieder in %.0f s." % ceilf(_zeitlupe_rest), 1.5)
		return
	_zeitlupe = EgoModus.ZEITLUPE_SEK
	_zeitlupe_rest = EgoModus.ZEITLUPE_ABKLING
	ego._zaehle("zeitlupen")
	ego.ringwerk._zl_beginn()   # 19.11.: Zusatz je aktivem Ring
	if ego._stop_vorher >= 0.0:
		_zl_vorher = ego._stop_vorher
		ego._stop_vorher = ego._stop_vorher * EgoModus.ZEITLUPE_TEMPO
	else:
		_zl_vorher = Engine.time_scale
		Engine.time_scale = _zl_vorher * EgoModus.ZEITLUPE_TEMPO
	ego._fov_puls = maxf(ego._fov_puls, 6.0)
	Ton.spiele(ego.spiel, "alert", -2.0)


func _zeitlupe_weiter(echt: float) -> void:
	ego.ringwerk._zl_weiter(echt)   # 19.11.
	_zeitlupe_rest -= echt
	if _zeitlupe <= 0.0:
		return
	_zeitlupe -= echt
	if _zeitlupe <= 0.0:
		_zeitlupe_aus()


func _zeitlupe_aus() -> void:
	ego.ringwerk._zl_ende()   # 19.11.
	_zeitlupe = 0.0
	if ego._stop_vorher >= 0.0:
		ego._stop_vorher = _zl_vorher   # ein laufender Hit-Stop stellt danach das normale Tempo her
	else:
		Engine.time_scale = _zl_vorher


## Blauer Schleier am Bildrand, solange die Zeitlupe läuft.
func _zeitlupe_bild(g: Vector2) -> void:
	if _zeitlupe <= 0.0:
		return
	var a := clampf(minf(_zeitlupe, EgoModus.ZEITLUPE_SEK - _zeitlupe) * 4.0, 0.0, 1.0)
	ego._bild.draw_rect(Rect2(Vector2.ZERO, g), Color(0.3, 0.5, 1.0, 0.08 * a))
	for i in 6:
		var d := float(i) * 10.0
		ego._bild.draw_rect(Rect2(Vector2(d, d), g - Vector2(d, d) * 2.0), Color(0.45, 0.7, 1.0, 0.07 * a), false, 10.0)
	Stil.schreibe_mittig(ego._bild, Vector2(g.x / 2.0, 172.0), "ZEITLUPE %.1f s" % maxf(0.0, _zeitlupe), 18, Color(0.7, 0.85, 1.0, a))


## 18.11. (Paul): Lichtsäule – Brakk wirbelt mit dem Zeigefinger: eine Lichtspur kreist um die Fingerspitze, immer schneller.
