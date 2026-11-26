class_name Hangar
extends CanvasLayer
## 25.11. (Paul): Hangar des Technoclan – die Benannten aus nemesis.json als Figuren in Reihen nach Rang, wie die
## Armee-Ansicht aus „Mordors Schatten“. Vorn Rang 1, dahinter Rang 2 und 3; Rang 4 und der Herausforderer (hat noch
## keiner den Titel: der mit der besten Bilanz) stehen auf dem Podest. Versetzte stehen grau am Rand, Ausgeschaltete sind ein leerer
## Platz mit Namensschild. Klick oder Pfeiltasten wählen: Die Figur tritt vor, die Kamera fährt heran, rechts die Karte.
## Erreichbar aus dem Startmenü und aus dem Bericht. Liest nur – kein Spielzustand wird verändert.

signal geschlossen

const Stil := preload("res://scripts/ui/ui_stil.gd")
const LILA := Color("a86bff")
const KARTE := Rect2(372, 34, 256, 300)     # UI-Raster 640×360
const ZURUECK := Rect2(14, 330, 78, 18)
## Reihen: Tiefe (z), Höhe (Stufe), seitlicher Versatz. 4 = Podest.
const REIHEN := {1: [1.7, 0.0, 0.0], 2: [-0.9, 0.35, -1.15], 3: [-3.4, 0.7, 1.15], 4: [-6.3, 2.35, 0.0]}
const PODEST_GROESSE := 1.25                 # wer oben steht, ist etwas größer und gut zu sehen
const ABSTAND := 2.25                        # zwischen zwei Figuren einer Reihe
const PIXEL := 0.056                         # 3D-Einheiten je Bildpunkt der Figur
const SCHRITTE := 1.2                        # so weit tritt die gewählte Figur vor
const KAMERA := Vector3(0.0, 6.3, 11.2)
const BLICK := Vector3(0.0, 1.75, -2.0)
const VERSETZT_MAX := 6
const LEER_MAX := 4

var figuren: Array = []        # je {"p", "was": "aktiv"|"versetzt"|"ausgeschaltet", "datum", "reihe", "ort", "ziel", "knoten", "sprite", "hoehe", "phase", "dreh"}
var gewaehlt := -1
var kamera: Camera3D = null
var _blick := BLICK
var _welt: Node3D = null
var _viewport: SubViewport = null
var _halter: SubViewportContainer = null
var _fang: Control = null
var _ui: Control = null
var _maus := Vector2(-100, -100)
var _t := 0.0
var _sofort := false           # Prüfung: Fahrten ohne Übergang


func _init() -> void:
	layer = 110   # über dem Startmenü (100) und dem Bericht
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	_halter = SubViewportContainer.new()
	_halter.stretch = true
	_halter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_halter)
	_viewport = SubViewport.new()
	_viewport.own_world_3d = true   # eigene Welt: nichts aus dem Spielfeld scheint hinein
	_viewport.msaa_3d = Viewport.MSAA_2X
	_halter.add_child(_viewport)
	_welt = Node3D.new()
	_viewport.add_child(_welt)
	kamera = Camera3D.new()
	kamera.fov = 40.0
	var umgebung := Environment.new()
	umgebung.background_mode = Environment.BG_COLOR
	umgebung.background_color = Color("0b0913")
	kamera.environment = umgebung
	_welt.add_child(kamera)
	kamera.current = true
	_fang = Control.new()
	_fang.mouse_filter = Control.MOUSE_FILTER_STOP
	_fang.gui_input.connect(_eingabe)
	add_child(_fang)
	_ui = Control.new()
	_ui.size = Vector2(640, 360)
	_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.draw.connect(_male)
	add_child(_ui)
	_groesse()
	_raum()
	_besetzen(Nemesis.meistgesuchte(), Nemesis.ehemalige())
	_kamera_stellen(1.0)


func _groesse() -> void:
	var g := get_viewport().get_visible_rect().size
	if _halter.size != g:
		_halter.size = g
		_fang.size = g
	SichererRand.einpassen(_ui, Stil.UI_SKALA)


# ------------------------------------------------------------------ Raum

func _stoff(farbe: Color, durchsichtig: bool = false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED   # gleich in jedem Renderer (auch im Browser)
	m.albedo_color = farbe
	if durchsichtig or farbe.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


func _kasten(groesse: Vector3, farbe: Color, pos: Vector3) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = groesse
	m.mesh = box
	m.material_override = _stoff(farbe)
	m.position = pos
	_welt.add_child(m)
	return m


func _raum() -> void:
	_kasten(Vector3(30.0, 0.2, 24.0), Color("171221"), Vector3(0, -0.1, -3.0))   # Boden
	for x in range(-12, 13, 3):   # Fugen
		_kasten(Vector3(0.04, 0.02, 24.0), Color("241c33"), Vector3(x, 0.01, -3.0))
	for z in range(-12, 7, 3):
		_kasten(Vector3(30.0, 0.02, 0.04), Color("241c33"), Vector3(0, 0.011, z))
	# Markierungen: lila Leitlinien zum Podest und eine gestrichelte Haltelinie vorn
	for seite: float in [-1.0, 1.0]:
		_kasten(Vector3(0.12, 0.02, 12.0), Color(LILA, 1.0).darkened(0.35), Vector3(5.7 * seite, 0.025, -1.0))
	for i in 17:
		_kasten(Vector3(0.5, 0.02, 0.14), Color("c9a23a") if i % 2 == 0 else Color("2a2236"), Vector3(-4.0 + i * 0.5, 0.025, 4.0))
	# Stufen für die hinteren Reihen
	_kasten(Vector3(12.6, 0.3, 2.2), Color("1f182d"), Vector3(0, 0.15, -1.0))
	_kasten(Vector3(12.6, 0.04, 0.06), Color(LILA, 1.0).darkened(0.25), Vector3(0, 0.3, 0.1))
	_kasten(Vector3(12.0, 0.6, 2.2), Color("221a31"), Vector3(0, 0.3, -3.5))
	_kasten(Vector3(12.0, 0.04, 0.06), Color(LILA, 1.0).darkened(0.25), Vector3(0, 0.6, -2.4))
	# Podest
	_kasten(Vector3(8.4, 2.35, 2.4), Color("2a2040"), Vector3(0, 1.175, -6.4))
	_kasten(Vector3(8.4, 0.08, 0.08), LILA, Vector3(0, 2.35, -5.2))
	for seite: float in [-1.0, 1.0]:
		_kasten(Vector3(0.08, 2.35, 0.08), LILA.darkened(0.2), Vector3(4.2 * seite, 1.175, -5.2))
		_kasten(Vector3(0.5, 1.2, 0.04), LILA.darkened(0.55), Vector3(2.6 * seite, 1.3, -5.18))   # Banner am Podest
	# Rückwand mit drei Toren
	_kasten(Vector3(30.0, 9.0, 0.3), Color("120e1c"), Vector3(0, 4.5, -10.0))
	for x: float in [-7.0, 0.0, 7.0]:
		_kasten(Vector3(5.2, 5.2, 0.1), Color("1d1630"), Vector3(x, 2.6, -9.8))
		for i in 6:
			_kasten(Vector3(5.0, 0.05, 0.05), Color("2c2247"), Vector3(x, 0.7 + i * 0.8, -9.72))
		_kasten(Vector3(5.4, 0.12, 0.1), LILA.darkened(0.15), Vector3(x, 5.3, -9.72))
		for seite: float in [-1.0, 1.0]:
			_kasten(Vector3(0.12, 5.3, 0.1), LILA.darkened(0.45), Vector3(x + 2.65 * seite, 2.65, -9.72))
	# Stützen an den Seiten
	for z: float in [-7.5, -4.0, -0.5]:
		for seite: float in [-1.0, 1.0]:
			_kasten(Vector3(0.6, 8.0, 0.6), Color("241b36"), Vector3(8.6 * seite, 4.0, z))
			_kasten(Vector3(0.08, 3.2, 0.08), LILA.darkened(0.3), Vector3(8.25 * seite, 2.6, z + 0.32))
	# Scheinwerfer: Kegel aus Licht auf Podest und Reihen
	for o: Array in [[-3.0, -6.4, 2.35], [3.0, -6.4, 2.35], [0.0, -3.4, 0.6], [-4.0, 1.7, 0.0], [4.0, 1.7, 0.0]]:
		var kegel := MeshInstance3D.new()
		var z := CylinderMesh.new()
		z.top_radius = 0.12
		z.bottom_radius = 1.35
		z.height = 7.0
		z.cap_top = false
		z.cap_bottom = false
		kegel.mesh = z
		var stoff := _stoff(Color(0.72, 0.6, 1.0, 0.045), true)
		stoff.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		kegel.material_override = stoff
		kegel.position = Vector3(float(o[0]), float(o[2]) + 3.5, float(o[1]))
		_welt.add_child(kegel)
		_kasten(Vector3(0.34, 0.16, 0.34), Color("e6dcff"), Vector3(float(o[0]), float(o[2]) + 7.05, float(o[1])))


# ------------------------------------------------------------------ Besetzung

## Wer oben steht: Rang NEMESIS_RANG_MAX und der Herausforderer (hat noch keiner den Titel: die beste Bilanz).
static func herausforderer(personen: Array) -> Dictionary:
	for p: Dictionary in personen:
		if Nemesis.hat_titel(p, Nemesis.TITEL_HERAUSFORDERER):
			return p
	var bester: Dictionary = {}
	for p: Dictionary in personen:
		if bester.is_empty() or Nemesis._guete(p) > Nemesis._guete(bester):
			bester = p
	return bester


func _besetzen(personen: Array, ehemalige: Array) -> void:
	var oben := herausforderer(personen)
	var reihen := {1: [], 2: [], 3: [], 4: []}
	for p: Dictionary in personen:
		var r := 4 if int(p["rang"]) >= Werte.NEMESIS_RANG_MAX or p == oben else clampi(int(p["rang"]), 1, 3)
		(reihen[r] as Array).append(p)
	var orte := reihen_plaetze({1: (reihen[1] as Array).size(), 2: (reihen[2] as Array).size(), 3: (reihen[3] as Array).size(), 4: (reihen[4] as Array).size()})
	for r: int in [4, 3, 2, 1]:   # Reihenfolge der Pfeiltasten: Podest zuerst, dann nach vorn
		var liste: Array = reihen[r]
		var lage: Array = REIHEN[r]
		for i in liste.size():
			_figur(liste[i] as Dictionary, "aktiv", "", r, Vector3(float((orte[r] as Array)[i]), float(lage[1]), float(lage[0])))
	var v := 0
	var l := 0
	for e: Dictionary in ehemalige:
		if str(e["was"]) == "versetzt" and v < VERSETZT_MAX:
			var seite := -1.0 if v % 2 == 0 else 1.0
			_figur(e["person"] as Dictionary, "versetzt", str(e["datum"]), 0, Vector3(seite * (6.5 + 0.2 * float(v / 2)), 0.0, -1.2 - 2.1 * float(v / 2)))
			v += 1
		elif str(e["was"]) == "ausgeschaltet" and l < LEER_MAX:
			var x: float = [-1.15, 1.15, -3.45, 3.45][l]
			_figur(e["person"] as Dictionary, "ausgeschaltet", str(e["datum"]), 0, Vector3(x, 0.0, 3.1))
			l += 1


## Plätze je Reihe (x) bei den Besetzungszahlen `je` (Reihe -> Anzahl). Von vorn nach hinten: Stünde jemand genau hinter
## einer Figur davor (ihr Schild würde ihn verdecken), rückt die ganze Reihe in die Lücke. Das Podest steht hoch genug.
static func reihen_plaetze(je: Dictionary) -> Dictionary:
	var aus := {}
	var davor: Array = []
	for r: int in [1, 2, 3, 4]:
		var n := int(je.get(r, 0))
		var weit := minf(ABSTAND, 10.5 / maxf(1.0, float(n)))
		var beste: Array = []
		var bester_abstand := -1.0
		for schub: float in [0.0, 1.1, -1.1, 0.55, -0.55, 1.65, -1.65]:
			var xs: Array = []
			var enge := INF
			for i in n:
				var x := (float(i) - (n - 1) / 2.0) * weit + float((REIHEN[r] as Array)[2]) + schub
				xs.append(x)
				for v: float in davor:
					enge = minf(enge, absf(x - v))
				if absf(x) > 5.7:
					enge = -0.5   # zu weit außen
			if enge > bester_abstand:
				bester_abstand = enge
				beste = xs
			if r == 4 or enge >= 0.95:
				break
		aus[r] = beste
		if r < 4:
			davor.append_array(beste)
	return aus


## Das Truppenblatt einer Person im Look (Elite-Aussehen wie im Feld).
static func blatt_von(p: Dictionary) -> Dictionary:
	var art := str(p.get("art", "technogunner"))
	var d: Dictionary = Werte.grafik_daten(Werte.grafik_einheit(Werte.einheit_daten(art, 4, ""), art, 4))
	var zelle := int(d.get("zelle", 48))
	return {"tex": NemesisLook.bild(load(str(d["blatt"])) as Texture2D, zelle, int(p.get("look", -1))), "zelle": zelle}


func _figur(p: Dictionary, was: String, datum: String, reihe: int, ort: Vector3) -> void:
	var knoten := Node3D.new()
	knoten.position = ort
	_welt.add_child(knoten)
	var f := {"p": p, "was": was, "datum": datum, "reihe": reihe, "ort": ort, "ziel": ort, "knoten": knoten, "sprite": null,
		"hoehe": 0.6, "ton": Color.WHITE, "phase": randf() * TAU, "dreh": 3.0 + randf() * 6.0}
	if was == "ausgeschaltet":
		var platte := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(1.5, 0.05, 0.8)
		platte.mesh = box
		platte.material_override = _stoff(Color("2b1620"))
		platte.position = Vector3(0, 0.03, 0)
		knoten.add_child(platte)
		for z: float in [-0.4, 0.4]:
			var rand := MeshInstance3D.new()
			var b2 := BoxMesh.new()
			b2.size = Vector3(1.5, 0.06, 0.04)
			rand.mesh = b2
			rand.material_override = _stoff(Color("ff5a6e"))
			rand.position = Vector3(0, 0.05, z)
			knoten.add_child(rand)
		_schild(knoten, "%s\n%s" % [str(p.get("name", "?")), tr("ausgeschaltet")], 0.42, Color("ff8a97"), 24)
		figuren.append(f)
		return
	var bild := blatt_von(p)
	var zelle := int(bild["zelle"])
	var tex: Texture2D = bild["tex"]
	var benutzt := tex.get_image().get_region(Rect2i(0, 0, zelle, zelle)).get_used_rect()
	var s := Sprite3D.new()
	s.texture = tex
	s.region_enabled = true
	s.region_rect = Rect2(0, 0, zelle, zelle)
	s.pixel_size = PIXEL
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	s.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	s.offset = Vector2(0, benutzt.end.y - zelle / 2.0)   # die Füße stehen auf dem Boden
	s.flip_h = ort.x > 0.1   # die Blätter schauen nach rechts: rechts im Raum zur Mitte drehen
	knoten.add_child(s)
	f["sprite"] = s
	f["blickt"] = s.flip_h
	var hoch := float(benutzt.size.y) * PIXEL
	f["hoehe"] = hoch
	var farbe := Nemesis.umriss_farbe(p)
	if was == "versetzt":
		s.modulate = Color(0.42, 0.42, 0.48)
		f["ton"] = s.modulate
		knoten.scale = Vector3.ONE * 0.74
		_schild(knoten, "%s\n%s" % [str(p.get("name", "?")), tr("versetzt")], hoch + 0.45, Color("9aa0b0"), 22)
		var schatten := _scheibe(0.6, Color(0, 0, 0, 0.45))
		knoten.add_child(schatten)
	else:
		knoten.add_child(_scheibe(0.75, Color(0, 0, 0, 0.5)))
		var winkel := Sprite3D.new()
		winkel.texture = Nemesis.rangwinkel(int(p.get("rang", 1)))
		winkel.pixel_size = 0.03
		winkel.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		winkel.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		winkel.position = Vector3(0, hoch + 0.12 + winkel.texture.get_height() * 0.015, 0)
		knoten.add_child(winkel)
		var text := "%s %s" % [Nemesis.dienstgrad(p), str(p["name"])]
		if str(p.get("beiname", "")) != "":
			text += "\n‚%s‘" % str(p["beiname"])
		_schild(knoten, text, hoch + 0.35 + winkel.texture.get_height() * 0.03 + 0.18, farbe.lightened(0.3), 21)
	if reihe == 4:
		knoten.scale = Vector3.ONE * PODEST_GROESSE
	figuren.append(f)


func _scheibe(radius: float, farbe: Color) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var z := CylinderMesh.new()
	z.top_radius = radius
	z.bottom_radius = radius
	z.height = 0.01
	m.mesh = z
	m.material_override = _stoff(farbe)
	m.position = Vector3(0, 0.02, 0)
	m.scale = Vector3(1.0, 1.0, 0.45)
	return m


func _schild(an: Node3D, text: String, hoehe: float, farbe: Color, schrift: int) -> void:
	var l := Label3D.new()
	l.text = text
	l.font_size = schrift
	l.outline_size = 8
	l.outline_modulate = Color(0.05, 0.03, 0.08, 0.95)
	l.modulate = farbe
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.render_priority = 2
	l.outline_render_priority = 1
	l.pixel_size = 0.0078
	l.position = Vector3(0, hoehe, 0)
	an.add_child(l)


# ------------------------------------------------------------------ Wahl und Bewegung

func waehle(i: int) -> void:
	if i < -1 or i >= figuren.size() or i == gewaehlt:
		return
	if gewaehlt >= 0:
		(figuren[gewaehlt] as Dictionary)["ziel"] = (figuren[gewaehlt] as Dictionary)["ort"]
	gewaehlt = i
	if i >= 0:
		var f: Dictionary = figuren[i]
		var vor := SCHRITTE if str(f["was"]) != "ausgeschaltet" else 0.0
		f["ziel"] = (f["ort"] as Vector3) + Vector3(0, 0, vor)
		Ton.spiele(self, "ui-klick", -6.0)
	_sicht()
	if _sofort:
		_kamera_stellen(1.0)
	_ui.queue_redraw()


## Nahaufnahme: Was vor der gewählten Figur steht, verschwindet, der Rest tritt zurück; die Schilder machen der Karte Platz.
func _sicht() -> void:
	for i in figuren.size():
		var f: Dictionary = figuren[i]
		var knoten: Node3D = f["knoten"]
		var vorn := gewaehlt >= 0 and i != gewaehlt and (f["ort"] as Vector3).z > (figuren[gewaehlt]["ziel"] as Vector3).z - 1.0
		knoten.visible = not vorn
		for kind: Node in knoten.get_children():
			if kind is Label3D:
				(kind as Label3D).visible = gewaehlt < 0
		var s: Sprite3D = f["sprite"]
		if s != null:
			var grund: Color = f["ton"]
			s.modulate = grund if gewaehlt < 0 or i == gewaehlt else grund.darkened(0.55)


## Kamera: Übersicht oder nah an der gewählten Figur (sie steht links, rechts ist Platz für die Karte).
func _kamera_stellen(anteil: float) -> void:
	var ort := KAMERA
	var blick := BLICK
	if gewaehlt >= 0:
		var f: Dictionary = figuren[gewaehlt]
		var z: Vector3 = f["ziel"]
		blick = z + Vector3(1.45, 1.1, 0.0)
		ort = z + Vector3(1.45, 1.95, 4.7)
	kamera.position = kamera.position.lerp(ort, anteil)
	_blick = _blick.lerp(blick, anteil)
	kamera.look_at(_blick, Vector3.UP)


func _process(delta: float) -> void:
	var echt := minf(delta / maxf(Engine.time_scale, 0.01), 0.1)
	_t += echt
	_groesse()
	var w := 1.0 - exp(-echt * 9.0)
	for i in figuren.size():
		var f: Dictionary = figuren[i]
		var knoten: Node3D = f["knoten"]
		knoten.position = knoten.position.lerp(f["ziel"] as Vector3, 1.0 if _sofort else w)
		var s: Sprite3D = f["sprite"]
		if s == null or str(f["was"]) != "aktiv":
			continue
		s.scale = Vector3(1.0, 1.0 + 0.022 * sin(_t * 1.9 + float(f["phase"])), 1.0)   # atmen
		f["dreh"] = float(f["dreh"]) - echt   # gelegentlich den Kopf zur anderen Seite drehen
		if float(f["dreh"]) <= 0.0:
			s.flip_h = not bool(f["blickt"]) if s.flip_h == bool(f["blickt"]) else bool(f["blickt"])
			f["dreh"] = 1.3 if s.flip_h != bool(f["blickt"]) else 4.0 + randf() * 6.0
		if i == gewaehlt:
			s.flip_h = bool(f["blickt"])
	_kamera_stellen(1.0 if _sofort else w)
	_ui.queue_redraw()


## Rechteck einer Figur auf dem Bildschirm (Spielfläche 1280×720); leer, wenn sie hinter der Kamera steht.
func rechteck(i: int) -> Rect2:
	var f: Dictionary = figuren[i]
	var knoten: Node3D = f["knoten"]
	var groesse := knoten.scale.x
	var fuss := knoten.position
	var kopf := fuss + Vector3(0, float(f["hoehe"]) * groesse + (0.35 if str(f["was"]) == "aktiv" else 0.2), 0)
	if kamera.is_position_behind(fuss) or kamera.is_position_behind(kopf):
		return Rect2()
	var a := kamera.unproject_position(kopf)
	var b := kamera.unproject_position(fuss)
	var h := maxf(24.0, b.y - a.y)
	var breit := h * (1.5 if str(f["was"]) == "ausgeschaltet" else 0.8)
	return Rect2(b.x - breit / 2.0, b.y - h, breit, h + 8.0)


## Welche Figur liegt unter diesem Punkt? Bei Überdeckung die vordere. -1 = keine.
func figur_bei(punkt: Vector2) -> int:
	var treffer := -1
	var naechste := INF
	for i in figuren.size():
		var r := rechteck(i)
		if (figuren[i]["knoten"] as Node3D).visible and r.size != Vector2.ZERO and r.has_point(punkt):
			var d := kamera.position.distance_to((figuren[i]["knoten"] as Node3D).position)
			if d < naechste:
				naechste = d
				treffer = i
	return treffer


func _ui_punkt(punkt: Vector2) -> Vector2:
	return _ui.get_transform().affine_inverse() * punkt


func klick(punkt: Vector2) -> void:
	var u := _ui_punkt(punkt)
	if ZURUECK.has_point(u):
		zu()
		return
	if gewaehlt >= 0 and KARTE.has_point(u):
		return
	waehle(figur_bei(punkt))


func _eingabe(ereignis: InputEvent) -> void:
	if ereignis is InputEventMouseMotion:
		_maus = _ui_punkt((ereignis as InputEventMouseMotion).position)
	elif ereignis is InputEventMouseButton and ereignis.pressed:
		var m := ereignis as InputEventMouseButton
		if m.button_index == MOUSE_BUTTON_LEFT:
			klick(m.position)
		elif m.button_index == MOUSE_BUTTON_RIGHT:
			taste(KEY_ESCAPE)


## Pfeile: links/rechts die nächste Figur, hoch/runter die Reihe dahinter bzw. davor. Esc: erst abwählen, dann zurück.
func taste(code: int) -> void:
	match code:
		KEY_ESCAPE, KEY_BACKSPACE:
			if gewaehlt >= 0:
				waehle(-1)
			else:
				zu()
		KEY_LEFT, KEY_RIGHT:
			if not figuren.is_empty():
				var schritt := 1 if code == KEY_RIGHT else -1
				waehle(posmod(gewaehlt + schritt, figuren.size()) if gewaehlt >= 0 else (0 if schritt > 0 else figuren.size() - 1))
		KEY_UP, KEY_DOWN:
			var ziel := _nachbarreihe(code == KEY_UP)
			if ziel >= 0:
				waehle(ziel)


func _nachbarreihe(hoch: bool) -> int:
	if figuren.is_empty():
		return -1
	if gewaehlt < 0:
		return 0
	var von: Vector3 = figuren[gewaehlt]["ort"]
	var beste := -1
	var wert := INF
	for i in figuren.size():
		var o: Vector3 = figuren[i]["ort"]
		var tiefer := o.z - von.z
		if (hoch and tiefer > -0.9) or (not hoch and tiefer < 0.9):
			continue
		var d := absf(tiefer) * 10.0 + absf(o.x - von.x)
		if d < wert:
			wert = d
			beste = i
	return beste


func _input(ereignis: InputEvent) -> void:
	if ereignis is InputEventKey and ereignis.pressed:
		var code := (ereignis as InputEventKey).keycode
		if not ereignis.echo or code in [KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN]:
			taste(code)
		get_viewport().set_input_as_handled()


func zu() -> void:
	geschlossen.emit()
	queue_free()


# ------------------------------------------------------------------ Karte und Beschriftung

func _male() -> void:
	var ci := _ui
	Stil.schreibe(ci, Vector2(14, 16), tr("HANGAR DES TECHNOCLAN"), Stil.GROSS, LILA.lightened(0.35))
	var aktiv := figuren.filter(func(f: Dictionary) -> bool: return str(f["was"]) == "aktiv").size()
	Stil.schreibe(ci, Vector2(14, 28), tr("%d Benannte jagen dich") % aktiv if aktiv != 1 else tr("1 Benannter jagt dich"), Stil.KLEIN, Stil.TEXT_BLASS)
	if figuren.is_empty():
		Stil.platte(ci, Rect2(170, 150, 300, 40), 3.0, Color(0.05, 0.04, 0.09, 0.9), LILA)
		Stil.schreibe_mittig(ci, Vector2(320, 163), tr("Noch niemand."), Stil.NORMAL, Stil.TEXT)
		Stil.schreibe_mittig(ci, Vector2(320, 177), tr("Wer dich in Befehl 24 ärgert, verdient sich hier einen Namen."), Stil.KLEIN, Stil.TEXT_BLASS)
	var an := ZURUECK.has_point(_maus)
	Stil.platte(ci, ZURUECK, 2.0, Stil.METALL if an else Stil.METALL_DUNKEL, Stil.LEUCHT if an else Stil.RAHMEN)
	Stil.schreibe_mittig(ci, ZURUECK.get_center(), tr("Zurück"), Stil.NORMAL, Stil.LEUCHT if an else Stil.TEXT)
	if not figuren.is_empty():
		var hilfe := tr("Figur anklicken oder mit den Pfeiltasten wählen · Esc zurück")
		Stil.schreibe(ci, Vector2(626.0 - Stil.breite(hilfe, Stil.KLEIN), 16), hilfe, Stil.KLEIN, Stil.TEXT_BLASS)
	if gewaehlt >= 0:
		_male_karte(figuren[gewaehlt] as Dictionary)


## Die Zeilen der Karte: [Überschrift, Wert]. Taktik, Stärke und Schwäche nur, wenn Brakk sie erlebt hat, sonst „?“.
static func karten_zeilen(p: Dictionary) -> Array:
	var faehig := NemesisFaehigkeiten.von_person(p)
	var gelernt := NemesisGewohnheiten.von_person(p)
	var taktik := NemesisLernen.beste(p)   # eine Taktik hat erst Werte, wenn er mit ihr gegen Brakk gekämpft hat
	return [
		["Truppe", "%s · Rang %d" % [str(Nemesis.ART_TEXT.get(str(p.get("art", "")), "?")), int(p.get("rang", 1))]],
		["Bilanz", Nemesis.bilanz_text(p)],
		["Fähigkeit", " · ".join(PackedStringArray(faehig.map(func(f: Variant) -> String: return NemesisFaehigkeiten.name_von(str(f))))) if not faehig.is_empty() else "—"],
		["Gelernt von dir", " · ".join(PackedStringArray(gelernt.map(func(a: Variant) -> String: return NemesisGewohnheiten.name_von(str(a))))) if not gelernt.is_empty() else "—"],
		["Spielt wie du", NemesisLernen.duell_text(p) if NemesisLernen.duell_text(p) != "" else "—"],   # 26.11.: der Herausforderer
		["Taktik", "bevorzugt " + NemesisLernen.name_von(taktik) if taktik != "" else "?"],
		["Stärke", str(Nemesis.STAERKEN.get(str(p.get("staerke", "")), "?")) if bool(p.get("staerke_bekannt", false)) else "?"],
		["Schwäche", str(Nemesis.SCHWAECHEN.get(str(p.get("schwaeche", "")), "?")) if bool(p.get("schwaeche_bekannt", false)) else "?"],
		["Titel", Nemesis.titel_text(p) if Nemesis.titel_text(p) != "" else "—"],
	]


## 26.11.: die Zeilen der Karte, dazu „Vergeltung“, sobald er sie einmal gezeigt hat.
static func karten_zeilen_alle(p: Dictionary) -> Array:
	var aus := karten_zeilen(p)
	if str(p.get("vergeltung", "")) != "":
		aus.append(["Vergeltung", "kopiert %s" % str(p["vergeltung"])])
	return aus


func _male_karte(f: Dictionary) -> void:
	var ci := _ui
	var p: Dictionary = f["p"]
	var was := str(f["was"])
	var rand := Nemesis.umriss_farbe(p) if was == "aktiv" else (Color("9aa0b0") if was == "versetzt" else Color("ff5a6e"))
	Stil.platte(ci, KARTE, 4.0, Color(0.05, 0.04, 0.09, 0.95), rand)
	var x := KARTE.position.x + 12.0
	var weite := KARTE.size.x - 24.0
	var y := KARTE.position.y + 12.0
	Stil.schreibe(ci, Vector2(x, y), tr("GESUCHT") if was == "aktiv" else (tr("VERSETZT") if was == "versetzt" else tr("AUSGESCHALTET")), Stil.KLEIN, Color("ff8a97") if was != "versetzt" else Color("9aa0b0"))
	if str(f["datum"]) != "":
		Stil.schreibe(ci, Vector2(KARTE.end.x - 12.0 - Stil.breite(str(f["datum"]), Stil.KLEIN), y), str(f["datum"]), Stil.KLEIN, Stil.TEXT_BLASS)
	y += 6.0
	var name_text := Nemesis.voller_name(p) if Nemesis.voller_name(p) != "" else str(p.get("name", "?"))
	Stil.absatz(ci, Vector2(x, y), name_text, weite, Stil.GROSS, Stil.GOLD)
	y += Stil.absatz_groesse(name_text, weite, Stil.GROSS).y + 4.0
	if was != "aktiv":
		var kurz := tr("Ein Neuer hat seinen Platz in der Liste.") if was == "versetzt" else tr("Von Brakk endgültig ausgeschaltet.")
		if bool(p.get("bekannt", false)):
			kurz = "%s · Rang %d\n%s" % [str(Nemesis.ART_TEXT.get(str(p.get("art", "")), "")), int(p.get("rang", 1)), kurz]
		if Nemesis.titel_text(p) != "":
			kurz += "\n" + Nemesis.titel_text(p)
		Stil.absatz(ci, Vector2(x, y), kurz, weite, Stil.NORMAL, Stil.TEXT)
		return
	for z: Array in karten_zeilen_alle(p):
		Stil.schreibe(ci, Vector2(x, y + 4.0), str(z[0]), Stil.KLEIN, Stil.TEXT_BLASS)
		var wert := str(z[1])
		Stil.absatz(ci, Vector2(x + 66.0, y), wert, weite - 66.0, Stil.KLEIN, Stil.TEXT_BLASS if wert in ["?", "—"] else Stil.TEXT)
		y += Stil.absatz_groesse(wert, weite - 66.0, Stil.KLEIN).y + 2.0
	y += 4.0
	Stil.schreibe(ci, Vector2(x, y + 4.0), tr("Chronik"), Stil.KLEIN, Stil.LEUCHT)
	y += 10.0
	var chronik: Array = p.get("chronik", [])
	for i in range(chronik.size() - 1, maxi(-1, chronik.size() - 5), -1):
		var c: Variant = chronik[i]
		var text := str((c as Dictionary).get("text", "")) if c is Dictionary else str(c)
		var datum := str((c as Dictionary).get("datum", "")) if c is Dictionary else ""
		var zeile := ("%s · %s" % [datum, text]) if datum != "" else text
		var hoch := Stil.absatz_groesse(zeile, weite, Stil.KLEIN).y
		if y + hoch > KARTE.end.y - 6.0:
			break
		Stil.absatz(ci, Vector2(x, y), zeile, weite, Stil.KLEIN, Stil.TEXT)
		y += hoch + 2.0
