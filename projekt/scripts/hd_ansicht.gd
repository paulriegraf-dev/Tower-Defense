class_name HdAnsicht
extends Node3D
## HD-2D-Ansicht (Grafik „HD-2D“, 16.11.): dasselbe Spiel, aber in 3D wie die Stilprobe –
## geneigte Kamera (Formeln aus Terrain-Conquester), Zoom mit Einrasten auf saubere Pixelstufen, Mauern als Blöcke.
##
## Die Spiellogik bleibt komplett in 2D. Diese Ansicht zeigt sie nur anders:
## - Zwei SubViewports teilen sich die 2D-Welt des Hauptfensters und zeigen je eine Schicht (visibility_layer):
##   den Boden (Karte) und eine Deckschicht (Effekte, Lebensbalken, Ringe, Nebel). Beide liegen als Flächen in 3D.
## - Jedes Sprite2D unter den Figuren (Truppen, Gegner, Türme, Zonenbauten) bekommt ein Sprite3D, das zur Kamera schaut.
## - Erdwälle werden zu Mauerblöcken; ihre Oberseite zeigt den Boden-Viewport (Stützenfarben, Stellung, Panzer ...).
## - Das Hauptfenster zeigt selbst nur noch die Oberfläche (HUD, Menüs) über der 3D-Ansicht.
## Bedienung: Mausrad zoomt (rastet ein), mittlere Maustaste ziehen oder Pfeiltasten schwenken, Pos1 = ganze Karte.

var H := 0.8                   # Wandhöhe in Feldern (18.11.: veränderlich – die Ego-Sicht zieht die Mauern hoch)
const SCHICHT_OBERFLAECHE := 1
const SCHICHT_KARTE := 2
const SCHICHT_DECKE := 4
const SCHICHT_FIGUR := 8        # Sprites der Figuren: nur als Sprite3D zu sehen

var spiel: Node
var karte: Karte
var kamera: Camera3D
var _boden_vp: SubViewport
var _decke_vp: SubViewport
var _waende: MeshInstance3D
var _wand_sig := ""
var _wand_in := 0.0
var _bilder := {}               # instance_id eines Sprite2D -> Sprite3D
var _umrisse := {}              # instance_id -> Sprite3D: Umriss, der durch Wände scheint (wie in der Stilprobe)
var _umriss_shader: Shader
var _umriss_mat := {}           # Farbe (html) -> ShaderMaterial je Textur
var umriss_an := true
var _balken := {}               # instance_id -> [Hintergrund, Füllung] (Lebensbalken über der Figur)
var _weiss: ImageTexture
var ego: Node = null           # 18.11.: Ego-Sicht (ego_modus.gd) aktiv – sie führt dann die Kamera
var _decke_mat: StandardMaterial3D

# Kamera: z = Zoom 0 (weit) .. 1 (nah); cx, cz = Blickpunkt in Feldern
var _z := 0.5
var _tz := 0.5
var _cx := Werte.SPALTEN / 2.0
var _cz := Werte.ZEILEN / 2.0
var _tcx := _cx
var _tcz := _cz
var _z_min := 0.0
var _einrast_in := -1.0
var _zieht := false
var _rad_bild := -1             # Mausrad: Bildnummer und schon gezählter Zoom in diesem Bild
var _rad_summe := 0.0


func einrichten(p_spiel: Node) -> void:
	spiel = p_spiel
	karte = spiel.karte
	var w: int = Werte.SPALTEN * Werte.ZELLE
	var h: int = Werte.ZEILEN * Werte.ZELLE
	_boden_vp = _neuer_viewport(w, h, SCHICHT_KARTE, false)
	_decke_vp = _neuer_viewport(w, h, SCHICHT_DECKE, true)
	get_viewport().canvas_cull_mask = SCHICHT_OBERFLAECHE
	# Eltern werden mit ihren Kindern ausgeblendet: das Spiel selbst (zeichnet nichts) in allen Schichten, die Figurengruppe in der Deckschicht
	(spiel as CanvasItem).visibility_layer = SCHICHT_OBERFLAECHE | SCHICHT_KARTE | SCHICHT_DECKE | SCHICHT_FIGUR
	spiel.figuren.visibility_layer = SCHICHT_DECKE
	for k in spiel.get_children():
		if k == karte:
			_setze_schicht(k, SCHICHT_KARTE)
		elif k == spiel.figuren:
			_setze_schicht_figuren(k)
		elif k is Node2D:
			_setze_schicht(k, SCHICHT_DECKE)   # Effekte, Marken, Nebel
	get_tree().node_added.connect(_bei_neuem_knoten)

	# Boden: dunkle Umgebung, die Karte, darüber die Deckschicht
	_kulisse()
	var boden_mat := _farbmaterial(Color.WHITE)
	boden_mat.albedo_texture = _boden_vp.get_texture()
	boden_mat.texture_repeat = false   # sonst greift die unterste Bildzeile auf die oberste über (heller Strich am Rand)
	var boden := _flaeche(Vector2(Werte.SPALTEN, Werte.ZEILEN), boden_mat)
	boden.position = Vector3(Werte.SPALTEN / 2.0, 0.0, Werte.ZEILEN / 2.0)
	var decke_mat := _farbmaterial(Color.WHITE)
	decke_mat.albedo_texture = _decke_vp.get_texture()
	decke_mat.texture_repeat = false
	decke_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	decke_mat.no_depth_test = true
	_decke_mat = decke_mat
	decke_mat.render_priority = 10
	var decke := _flaeche(Vector2(Werte.SPALTEN, Werte.ZEILEN), decke_mat)
	decke.position = Vector3(Werte.SPALTEN / 2.0, 0.02, Werte.ZEILEN / 2.0)

	_waende = MeshInstance3D.new()
	add_child(_waende)
	# Licht wie in der Stilprobe: Umgebungslicht plus ein Richtungslicht von vorn links oben (nur Mauern und Blöcke sind beleuchtet)
	var sonne := DirectionalLight3D.new()
	sonne.light_energy = 0.75
	add_child(sonne)
	sonne.look_at_from_position(Vector3(-6, 14, 9), Vector3.ZERO, Vector3.UP)
	var umwelt := WorldEnvironment.new()
	var env := Environment.new()
	# Himmel: dunkles Blau oben, dunstiger Horizont hinter den Bergen
	var himmel := ProceduralSkyMaterial.new()
	himmel.sky_top_color = Color("0c1420")
	himmel.sky_horizon_color = Color("34445a")
	himmel.ground_horizon_color = Color("34445a")
	himmel.ground_bottom_color = Color("0b0f14")
	himmel.sun_angle_max = 0.0
	var sky := Sky.new()
	sky.sky_material = himmel
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.WHITE
	env.ambient_light_energy = 0.62
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	# Dunst in der Ferne (wie die Stilprobe): Kulisse verblasst nach hinten
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = Color("0e1418")
	env.fog_depth_begin = 40.0
	env.fog_depth_end = 110.0
	env.fog_depth_curve = 1.0
	env.fog_density = 1.0
	# leichtes Glühen der hellen Lichter
	env.glow_enabled = true
	env.glow_intensity = 0.5
	env.glow_bloom = 0.04
	env.glow_hdr_threshold = 0.85
	umwelt.environment = env
	add_child(umwelt)
	_vignette()

	kamera = Camera3D.new()
	kamera.near = 0.5
	kamera.far = 400.0
	add_child(kamera)
	kamera.make_current()
	var passend := _passend_z()
	_z_min = passend   # weiter heraus als „ganze Karte“ nicht: sonst sieht man das Ende der Landschaft
	if OS.get_environment("TD_ZOOM") != "":
		passend = float(OS.get_environment("TD_ZOOM"))   # für Testbilder
	if OS.get_environment("TD_DRAUF") != "":
		_drauf = 1.0
		_tdrauf = 1.0
	_z = passend
	_tz = passend
	_kamera_setzen()
	_vorwaermen.call_deferred()


func _exit_tree() -> void:
	if is_instance_valid(_vignette_ebene):
		_vignette_ebene.queue_free()
	# zurück auf die normale 2D-Ansicht (das Hauptfenster bleibt beim Szenenwechsel bestehen)
	get_viewport().canvas_cull_mask = 0xFFFFFFFF
	if get_tree().node_added.is_connected(_bei_neuem_knoten):
		get_tree().node_added.disconnect(_bei_neuem_knoten)
	if is_instance_valid(spiel):
		(spiel as CanvasItem).visibility_layer = SCHICHT_OBERFLAECHE
		for k in spiel.get_children():
			if k is Node2D:
				_setze_schicht(k, SCHICHT_OBERFLAECHE)


func _neuer_viewport(w: int, h: int, maske: int, durchsichtig: bool) -> SubViewport:
	var vp := SubViewport.new()
	vp.size = Vector2i(w, h)
	vp.world_2d = get_viewport().world_2d
	vp.canvas_cull_mask = maske
	vp.transparent_bg = durchsichtig
	vp.disable_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	add_child(vp)
	vp.canvas_transform = Transform2D(0.0, Vector2(0, -Werte.KARTE_OBEN))
	return vp


func _farbmaterial(farbe: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = farbe
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


func _flaeche(groesse: Vector2, mat: Material) -> MeshInstance3D:
	var pm := PlaneMesh.new()
	pm.size = groesse
	var mi := MeshInstance3D.new()
	mi.mesh = pm
	mi.material_override = mat
	add_child(mi)
	return mi


func _setze_schicht(n: Node, schicht: int) -> void:
	if n is CanvasItem:
		(n as CanvasItem).visibility_layer = schicht
	for k in n.get_children():
		_setze_schicht(k, schicht)


func _setze_schicht_figuren(n: Node) -> void:
	for k in n.get_children():
		if k is CanvasItem:
			(k as CanvasItem).visibility_layer = SCHICHT_FIGUR if k is Sprite2D else SCHICHT_DECKE
		_setze_schicht_figuren(k)


func _bei_neuem_knoten(n: Node) -> void:
	if not (n is CanvasItem) or not is_instance_valid(spiel):
		return
	if spiel.figuren.is_ancestor_of(n):
		(n as CanvasItem).visibility_layer = SCHICHT_FIGUR if n is Sprite2D else SCHICHT_DECKE
	elif karte.is_ancestor_of(n):
		(n as CanvasItem).visibility_layer = SCHICHT_KARTE
	elif n.get_parent() == spiel and n is Node2D:
		(n as CanvasItem).visibility_layer = SCHICHT_DECKE


# ------------------------------------------------------------------ jedes Bild

func _process(delta: float) -> void:
	var echt := delta / maxf(Engine.time_scale, 0.01)   # Kamera unabhängig vom Spieltempo
	if ego == null:
		_kamera_weiter(echt)
	_wand_in -= echt
	if _wand_in <= 0.0:
		_wand_in = 0.2
		var sig := str(karte.feld) + str(karte.ausbau) + str(karte.stuetze_von.size()) + str(karte.panzer.size()) + Werte.wand_stil
		if sig != _wand_sig:
			_wand_sig = sig
			_baue_waende()
	_spiegle_figuren()
	_bauten_bilder()
	_klon_weiter()
	_schilde_weiter()
	_wuerfe_weiter()
	_leucht_weiter()
	_bauvorschau()
	_zuschauer_weiter(echt)


## Steht auf diesem Feld ein Mauerblock (Erdwall ohne Tor)?
func ist_hoch(z: Vector2i) -> bool:
	return karte.feld.get(z, -1) == Karte.WALL and karte.ausbau.get(z, Karte.FREI) != Karte.TOR


## 18.11.: Leere (ganz durchsichtige) Zeilen am unteren Rand eines Bildausschnitts – zwischengespeichert je Bild und Ausschnitt.
var _leer_cache := {}

func _leer_unten(tex: Texture2D, r: Rect2) -> int:
	var schluessel := "%d|%s" % [tex.get_instance_id(), r]
	if _leer_cache.has(schluessel):
		return int(_leer_cache[schluessel])
	var bild := tex.get_image()
	var leer := 0
	if bild != null:
		if bild.is_compressed():
			bild.decompress()
		var ri := Rect2i(r)
		for y in range(ri.end.y - 1, ri.position.y - 1, -1):
			var voll := false
			for x in range(ri.position.x, ri.end.x):
				if bild.get_pixel(x, y).a > 0.05:
					voll = true
					break
			if voll:
				break
			leer += 1
		if leer >= ri.size.y:
			leer = 0
	_leer_cache[schluessel] = leer
	return leer


func _welt_3d(p: Vector2, hoehe: float) -> Vector3:
	return Vector3(p.x / Werte.ZELLE, hoehe, (p.y - Werte.KARTE_OBEN) / Werte.ZELLE)


# ------------------------------------------------------------------ Figuren als Sprite3D

func _spiegle_figuren() -> void:
	var gesehen := {}
	_sammle(spiel.figuren, gesehen)
	for id in _bilder.keys():
		if not gesehen.has(id):
			(_bilder[id] as Node).queue_free()
			_bilder.erase(id)
	for id in _umrisse.keys():
		if not gesehen.has(id):
			(_umrisse[id] as Node).queue_free()
			_umrisse.erase(id)
	for id in _balken.keys():
		if not gesehen.has(id):
			for n: Node in _balken[id]:
				n.queue_free()
			_balken.erase(id)
	_tuerme_durchsichtig()


func _sammle(n: Node, gesehen: Dictionary) -> void:
	for k in n.get_children():
		if k is Sprite2D:
			_spiegle(k as Sprite2D, gesehen)
		if k.get_child_count() > 0:
			_sammle(k, gesehen)


func _spiegle(s: Sprite2D, gesehen: Dictionary) -> void:
	var id := s.get_instance_id()
	gesehen[id] = true
	var b: Sprite3D = _bilder.get(id)
	if b == null:
		b = Sprite3D.new()
		b.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		b.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		b.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		b.shaded = false
		b.double_sided = true
		b.centered = false
		add_child(b)
		_bilder[id] = b
	var sichtbar := s.is_visible_in_tree() and s.texture != null
	b.visible = sichtbar
	if not sichtbar:
		return
	b.texture = s.texture
	b.region_enabled = s.region_enabled
	b.region_rect = s.region_rect
	b.flip_h = s.flip_h
	var faerbung := s.modulate * s.self_modulate
	var eltern := s.get_parent()
	if eltern is CanvasItem:
		faerbung *= (eltern as CanvasItem).modulate
	b.modulate = faerbung
	b.pixel_size = absf(s.global_scale.x) / float(Werte.ZELLE)
	b.scale = Vector3(1.0, absf(s.global_scale.y / s.global_scale.x) if s.global_scale.x != 0.0 else 1.0, 1.0)   # Stauchen (Landung, Ruck)
	if eltern is Gegner and (eltern as Gegner).typ not in ["belagerung", "schwarm"]:
		b.pixel_size *= 0.85   # Gegner etwas kleiner: in den engen Gängen stehen viele dicht beieinander
	var groesse: Vector2 = s.region_rect.size if s.region_enabled else s.texture.get_size()
	var o := s.offset - (groesse / 2.0 if s.centered else Vector2.ZERO)
	# 2D: das Bild reicht von o bis o + groesse (y nach unten). 3D: y nach oben, die Unterkante liegt am Fußpunkt.
	b.offset = Vector2(o.x, -(o.y + groesse.y))
	var traeger: Node2D = eltern as Node2D if eltern is Node2D else s
	var hoehe := H if ist_hoch(karte.zelle_bei(traeger.global_position)) else 0.0
	b.position = _welt_3d(s.global_position, hoehe + 0.002)
	# 18.11.: Ego-Sicht – aus Augenhöhe schwebten die Figuren: Das Bild drehte sich ganz zur Kamera, sein Fuß lag 22 px
	# südlich (für die Schrägsicht) und unten sind oft leere Zeilen. Hier stehen sie aufrecht auf ihrem echten Fußpunkt
	# (dort liegt auch der Schatten), ohne leere Zeilen. Die Draufsicht bleibt wie sie ist.
	if ego != null:
		b.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		if traeger is Gegner or traeger is Einheit:
			b.position = _welt_3d(traeger.global_position, hoehe + 0.002)
		b.offset.y -= _leer_unten(s.texture, s.region_rect if s.region_enabled else Rect2(Vector2.ZERO, s.texture.get_size()))
	else:
		b.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	b.set_meta("turm", traeger is TurmBild)
	_lebensbalken(id, traeger, b, groesse)
	# Umriss durch Wände: Gegner rot, eigene Bodentruppen violett (nicht für Türme und Truppen oben auf dem Wall)
	var farbe := Color(0, 0, 0, 0)
	if umriss_an and hoehe == 0.0 and _hinter_wall(traeger.global_position):
		# nur hinter einem Erdwall (16.11.: sonst lenkt das Rot ab – Bäume, Kulisse und Bauten lösen keinen Umriss aus)
		if traeger is Gegner:
			farbe = Color(1.0, 0.35, 0.4, 0.12)   # Alpha = Füllung innen; der Rand ist immer kräftig
		elif traeger is Einheit:
			farbe = Color(0.75, 0.55, 1.0, 0.12)
	var u: Sprite3D = _umrisse.get(id)
	if farbe.a <= 0.0:
		if u != null:
			u.visible = false
		return
	if u == null:
		u = Sprite3D.new()
		u.centered = false
		add_child(u)
		_umrisse[id] = u
	u.visible = true
	u.texture = b.texture
	u.region_enabled = b.region_enabled
	u.region_rect = b.region_rect
	u.flip_h = b.flip_h
	u.pixel_size = b.pixel_size
	u.offset = b.offset
	u.position = b.position
	u.material_override = _umriss_material(b.texture, farbe)


## Steht direkt vor diesem Punkt (zur Kamera hin, ein oder zwei Felder) ein Mauerblock, der ihn verdecken kann?
func _hinter_wall(p: Vector2) -> bool:
	var z := karte.zelle_bei(p)
	for d in [Vector2i(0, 1), Vector2i(0, 2), Vector2i(-1, 1), Vector2i(1, 1)]:
		if ist_hoch(z + d):
			return true
	return false


## Lebensbalken als kleines 3D-Bild über dem Kopf (nur wenn die Figur Schaden hat).
func _lebensbalken(id: int, traeger: Node, b: Sprite3D, groesse: Vector2) -> void:
	var zeigen := (traeger is Gegner or traeger is Einheit) and float(traeger.get("leben")) < float(traeger.get("max_leben"))
	var paar: Array = _balken.get(id, [])
	if not zeigen:
		for n: Node3D in paar:
			n.visible = false
		return
	if paar.is_empty():
		if _weiss == null:
			var img := Image.create(32, 4, false, Image.FORMAT_RGBA8)
			img.fill(Color.WHITE)
			_weiss = ImageTexture.create_from_image(img)
		for i in 2:
			var s := Sprite3D.new()
			s.texture = _weiss
			s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			s.shaded = false
			s.no_depth_test = true
			s.centered = false
			s.region_enabled = true
			s.pixel_size = 1.0 / 40.0
			s.render_priority = 20 + i
			add_child(s)
			paar.append(s)
		_balken[id] = paar
	var anteil := clampf(float(traeger.get("leben")) / maxf(float(traeger.get("max_leben")), 0.001), 0.0, 1.0)
	var hoehe_px := (groesse.y * b.pixel_size) * 40.0 + 2.0   # über dem Bild, in Balken-Pixeln
	var grund: Sprite3D = paar[0]
	var fuell: Sprite3D = paar[1]
	grund.visible = true
	fuell.visible = true
	# Lesbarkeit (16.11.): kurze Balken – kleine Einheiten 16, große 26 Pixel breit (vorher 32: im Pulk ein Balkenteppich)
	var gross: bool = traeger is Gegner and (traeger as Gegner).typ in ["belagerung", "schwarm", "schild", "sphaere"]
	var breite := 26.0 if gross else 16.0
	grund.region_rect = Rect2(0, 0, breite + 2.0, 4)
	grund.modulate = Color(0, 0, 0, 0.7)
	grund.offset = Vector2(-(breite + 2.0) / 2.0, hoehe_px)
	grund.position = b.position
	fuell.region_rect = Rect2(0, 0, maxf(1.0, breite * anteil), 2)
	fuell.modulate = Color("ff5a4d") if traeger is Gegner else Color("7fe0ff")
	fuell.offset = Vector2(-breite / 2.0, hoehe_px + 1.0)
	fuell.position = b.position


## Material für den Umriss: zeichnet nur dort, wo etwas davor steht (umgekehrter Tiefentest), einfarbig und halb durchsichtig.
func _umriss_material(tex: Texture2D, farbe: Color) -> ShaderMaterial:
	var schluessel := str(tex.get_instance_id()) + farbe.to_html()
	if _umriss_mat.has(schluessel):
		return _umriss_mat[schluessel]
	if _umriss_shader == null:
		_umriss_shader = Shader.new()
		_umriss_shader.code = """shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, depth_test_inverted, blend_mix;
uniform sampler2D bild : filter_nearest, source_color;
uniform vec4 farbe : source_color;
void vertex() {
	// Billboard wie bei den Sprite3D
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * length(MODEL_MATRIX[0].xyz), INV_VIEW_MATRIX[1] * length(MODEL_MATRIX[1].xyz), INV_VIEW_MATRIX[2] * length(MODEL_MATRIX[2].xyz), MODEL_MATRIX[3]);
	// ein Stück zur Kamera hin: sonst „verdeckt“ die Figur sich selbst und der Umriss liegt immer lila über ihr (16.11.)
	MODELVIEW_MATRIX[3].z += 0.12;
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}
void fragment() {
	// nur der Rand der Figur (1 Bildpunkt) kräftig, innen ein Hauch – eine volle rote Fläche war zu viel (16.11.)
	vec4 c = texture(bild, UV);
	if (c.a < 0.5) { discard; }
	vec2 px = 1.0 / vec2(textureSize(bild, 0));
	float rand = 0.0;
	if (texture(bild, UV + vec2(px.x, 0.0)).a < 0.5) { rand = 1.0; }
	if (texture(bild, UV - vec2(px.x, 0.0)).a < 0.5) { rand = 1.0; }
	if (texture(bild, UV + vec2(0.0, px.y)).a < 0.5) { rand = 1.0; }
	if (texture(bild, UV - vec2(0.0, px.y)).a < 0.5) { rand = 1.0; }
	ALBEDO = farbe.rgb;
	ALPHA = rand > 0.5 ? 0.9 : farbe.a;
}
"""
	var m := ShaderMaterial.new()
	m.shader = _umriss_shader
	m.set_shader_parameter("bild", tex)
	m.set_shader_parameter("farbe", farbe)
	m.render_priority = 5
	_umriss_mat[schluessel] = m
	return m


## Steht eine Figur dicht hinter einem Turm, wird der Turm halb durchsichtig (wie das Pixelraster in der Stilprobe).
func _tuerme_durchsichtig() -> void:
	var figuren: Array[Vector3] = []
	for id in _bilder:
		var b: Sprite3D = _bilder[id]
		if b.visible and not b.get_meta("turm", false):
			figuren.append(b.position)
	for id in _bilder:
		var b: Sprite3D = _bilder[id]
		if not b.visible or not b.get_meta("turm", false):
			continue
		var hinten := false
		for p in figuren:
			if absf(p.x - b.position.x) < 0.7 and b.position.z - p.z > 0.1 and b.position.z - p.z < 1.6:
				hinten = true
				break
		b.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED if hinten else SpriteBase3D.ALPHA_CUT_DISCARD
		b.modulate.a = 0.55 if hinten else 1.0


## Batterien und Schildgeneratoren stehen als Sprite3D auf ihrem Feld (die Karte zeichnet in HD-2D nur Sockel und Zähler).
var _bauten := {}   # Zelle -> Sprite3D
const FABRIK_MASSSTAB := 1.5   # Fabrikbild etwas größer als ein Mauerblock (16.11.: 1.4 → 1.5, wirkt massiver)

func _bauten_bilder() -> void:
	var gesehen := {}
	for z: Vector2i in karte.feld:
		var typ: int = karte.feld[z]
		if typ != Karte.BATTERIE and typ != Karte.GENERATOR and typ != Karte.FABRIK:
			continue
		gesehen[z] = true
		var b: Sprite3D = _bauten.get(z)
		if b == null:
			b = _neues_bild()
			_bauten[z] = b
			if typ == Karte.FABRIK and not _bauten_erstes:
				_fabrik_seit[z] = Time.get_ticks_msec() / 1000.0
		var m := karte.mitte(z)
		if typ == Karte.FABRIK:
			# 64-px-Bild füllt das Feld (1 Bildpixel = 1 Kartenpixel), Fuß in Zeile 56
			b.texture = karte.neu_bild(karte.fabrik_bild(z))
			b.region_rect = Rect2(0, 0, 64, 64)
			b.flip_h = false
			b.pixel_size = FABRIK_MASSSTAB / Werte.ZELLE
			b.offset = Vector2(-32, -(64 - 57))
			# 18.11.: in der Ego-Sicht mittig und aufrecht auf dem Sockel (von schräg oben passt der Südrand besser)
			b.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y if ego != null else BaseMaterial3D.BILLBOARD_ENABLED
			_fabrik_einsetzen(z, b, _welt_3d(m + (Vector2(0, 4) if ego != null else Vector2(0, 26)), FABRIK_SOCKEL + 0.01))
		elif typ == Karte.BATTERIE:
			b.texture = karte.neu_bild("batterie/bat_%d.png" % clampi(int(karte.batterie_stufe_neu.get(z, 0)), 0, 3))
			var t: float = karte.batterie_schuss.get(z, -1.0)
			b.region_rect = Rect2(0, 0, 48, 48) if t < 0.0 else Rect2(mini(8, int(t / 0.7 * 9.0)) * 48, 48, 48, 48)
			b.flip_h = karte.batterie_blick.get(z, false)
			b.pixel_size = 2.0 / Werte.ZELLE
			b.offset = Vector2(-24, -2)
			b.position = _welt_3d(m + Vector2(0, 16), 0.002)
		else:
			b.texture = karte.neu_bild("tuerme/schild.png")
			b.region_rect = Rect2(0, 0, 64, 64)
			b.pixel_size = 2.0 / Werte.ZELLE
			b.offset = Vector2(-31, -2)
			b.position = _welt_3d(m + Vector2(0, 24), 0.002)
		b.modulate = Color(0.5, 0.5, 0.55) if karte.ausgefallen.has(z) else Color.WHITE
	# Hauptquartier und Checkpoint-Fahnen
	var extra := {karte.basis: "basis"}
	if karte.cp_aktiv:
		for i in karte.checkpoints.size():
			extra[karte.checkpoints[i]] = "cp_feind" if karte.cp_feind[i] else "cp"
	for z: Vector2i in extra:
		gesehen[z] = true
		var b: Sprite3D = _bauten.get(z)
		if b == null:
			b = _neues_bild()
			_bauten[z] = b
		var m := karte.mitte(z)
		b.pixel_size = 2.0 / Werte.ZELLE
		b.modulate = Color.WHITE
		b.flip_h = false
		if extra[z] == "basis":
			# 16.11.: große Technoclan-Festung (128 px), Gegenstück zur Maschinen-Kuppel der Myriaden
			b.texture = karte.neu_bild("gebaeude/basis_gross.png")
			b.region_rect = Rect2(0, 0, 128, 128)
			b.pixel_size = 1.7 / Werte.ZELLE
			b.offset = Vector2(-57, -(128 - 111))
			b.position = _welt_3d(m + Vector2(0, 26), 0.002)
		else:
			b.texture = karte.neu_bild("gebaeude/checkpoint_feind.png" if extra[z] == "cp_feind" else "gebaeude/checkpoint.png")
			b.region_rect = Rect2(0, 0, 48, 48)
			b.offset = Vector2(-25, -(48 - 45))
			b.position = _welt_3d(m + Vector2(0, 22), 0.002)
	for z in _bauten.keys():
		if not gesehen.has(z):
			(_bauten[z] as Node).queue_free()
			_bauten.erase(z)
			_fabrik_seit.erase(z)
	_bauten_erstes = false


## Bauvorschau als richtige Form (16.11.): Mauer als durchsichtiger Block, Fabrik, Turm, Batterie (mit Pilotenfabrik)
## und Schildgenerator als halb durchsichtiges Bild an ihrem Platz. Rot = geht hier nicht.
var _geist_block: MeshInstance3D
var _geist_mat: StandardMaterial3D
var _geister: Array[Sprite3D] = []

var _brustwehr_geist: MeshInstance3D

func _bauvorschau() -> void:
	if _geist_block == null:
		_geist_block = MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.9, H, 0.9)
		_geist_block.mesh = box
		_geist_mat = StandardMaterial3D.new()
		_geist_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_geist_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_geist_block.material_override = _geist_mat
		add_child(_geist_block)
		for i in 2:
			var g := _neues_bild()
			g.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED   # halb durchsichtig
			g.render_priority = 5
			_geister.append(g)
	_geist_block.visible = false
	for g in _geister:
		g.visible = false
	var z := karte.vorschau_zelle
	var typ := karte.vorschau_typ
	if typ == Karte.FREI or not karte.in_karte(z):
		return
	var ok := karte.vorschau_ok
	var puls := 0.55 + 0.1 * sin(Time.get_ticks_msec() / 160.0)
	var farbe := Color(1, 1, 1, puls) if ok else Color(1.0, 0.35, 0.35, puls)
	if typ == Karte.WALL or not ok:
		_geist_block.visible = true
		var hoch := H if typ == Karte.WALL else 0.12
		(_geist_block.mesh as BoxMesh).size = Vector3(0.9, hoch, 0.9)
		_geist_block.position = Vector3(z.x + 0.5, hoch / 2.0, z.y + 0.5)
		_geist_mat.albedo_color = Color(0.45, 0.85, 1.0, 0.38) if ok else Color(1.0, 0.3, 0.3, 0.38)
		if typ == Karte.WALL or not ok:
			return
	# Energiewand (16.11.): ein Ausbau macht aus dem flachen Feld einen vollen Tech-Mauerblock. Damit man sieht, wie es
	# danach aussieht, steht der ganze Block als Geist da – bei der Stellung mit Brüstung.
	if _brustwehr_geist == null:
		_brustwehr_geist = MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.92, 0.34, 0.12)
		_brustwehr_geist.mesh = bm
		var bwm := StandardMaterial3D.new()
		bwm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		bwm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		bwm.albedo_color = Color(0.5, 0.95, 1.0, 0.6)
		bwm.render_priority = 6
		_brustwehr_geist.material_override = bwm
		add_child(_brustwehr_geist)
	_brustwehr_geist.visible = false
	if Werte.wand_stil == "energie" and typ in [Karte.STELLUNG, Karte.TOR, Karte.PANZER, Karte.TURM] and karte.inhalt(z) == Karte.WALL \
			and karte.ausbau.get(z, Karte.FREI) == Karte.FREI and not karte.stuetze_von.has(z):
		_geist_block.visible = true
		(_geist_block.mesh as BoxMesh).size = Vector3(1.0, H, 1.0)
		_geist_block.position = Vector3(z.x + 0.5, H / 2.0, z.y + 0.5)
		_geist_mat.albedo_color = Color(0.55, 0.78, 0.95, 0.42)
		if typ == Karte.STELLUNG:
			_brustwehr_geist.visible = true
			_brustwehr_geist.position = Vector3(z.x + 0.5, H + 0.17, z.y + 0.9)
	var m := karte.mitte(z)
	var g := _geister[0]
	g.modulate = farbe
	g.flip_h = false
	match typ:
		Karte.FABRIK:
			_geist_fabrik(g, z, "gebaeude/fabrik_grund.png")
		Karte.BATTERIE:
			g.visible = true
			g.texture = karte.neu_bild("batterie/bat_0.png")
			g.region_rect = Rect2(0, 0, 48, 48)
			g.pixel_size = 2.0 / Werte.ZELLE
			g.offset = Vector2(-24, -2)
			g.position = _welt_3d(m + Vector2(0, 16), 0.01)
			if karte.vorschau_partner != Karte.KEINE:
				_geister[1].modulate = farbe
				_geist_fabrik(_geister[1], karte.vorschau_partner, "gebaeude/fabrik_pilot.png")
		Karte.GENERATOR:
			g.visible = true
			g.texture = karte.neu_bild("tuerme/schild.png")
			g.region_rect = Rect2(0, 0, 64, 64)
			g.pixel_size = 2.0 / Werte.ZELLE
			g.offset = Vector2(-31, -2)
			g.position = _welt_3d(m + Vector2(0, 24), 0.01)
		Karte.TURM:
			var b := TurmBild.bild_info(karte, z, 0, -1.0, 1.0)
			var q: Rect2 = b["quelle"]
			var anker: Vector2 = b["anker"]
			g.visible = true
			g.texture = b["bild"]
			g.region_rect = q
			g.pixel_size = 2.0 / Werte.ZELLE
			g.offset = Vector2(-anker.x, anker.y - q.size.y)
			g.position = _welt_3d(m + Vector2(0, 24), (H if ist_hoch(z) else 0.0) + 0.01)


func _geist_fabrik(g: Sprite3D, z: Vector2i, bild: String) -> void:
	g.visible = true
	g.texture = karte.neu_bild(bild)
	g.region_rect = Rect2(0, 0, 64, 64)
	g.pixel_size = FABRIK_MASSSTAB / Werte.ZELLE
	g.offset = Vector2(-32, -(64 - 57))
	g.position = _welt_3d(karte.mitte(z) + Vector2(0, 26), 0.05)


func _neues_bild() -> Sprite3D:
	var b := Sprite3D.new()
	b.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	b.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	b.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	b.shaded = false
	b.double_sided = true
	b.centered = false
	b.region_enabled = true
	add_child(b)
	return b


# ------------------------------------------------------------------ Mauerblöcke

## Mauerstil in HD-2D (Werte.wand_stil): "tech" = Tech-Mauer wie in der Stilprobe (abgeschrägte Kanten, Licht,
## Kontaktschatten), "block" = schlichte Blöcke, "energie" = Energiewand (Sockel, Pfeiler, Abtastfeld).
## Stellungen und Turm-Stützen sind immer Tech-Mauer. Tore sind ein Durchgang mit zwei Pfeilern und Energiebalken.
const FASE := 0.08
var _flaechen := {}   # Materialname -> SurfaceTool (beim Bauen)
var _mats := {}       # Materialname -> Material


func _wand_materialien() -> void:
	var licht := func(m: StandardMaterial3D) -> StandardMaterial3D:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
		m.roughness = 1.0
		return m
	_mats["oben"] = licht.call(_farbmaterial(Color.WHITE))
	(_mats["oben"] as StandardMaterial3D).albedo_texture = _boden_vp.get_texture()
	(_mats["oben"] as StandardMaterial3D).albedo_color = Color(0.66, 0.72, 0.84)   # Schieferblau wie in der Stilprobe
	_mats["seite"] = licht.call(_farbmaterial(Color.WHITE))
	(_mats["seite"] as StandardMaterial3D).albedo_texture = karte.neu_bild("wand/seite3d.png")
	(_mats["seite"] as StandardMaterial3D).albedo_color = Color(0.78, 0.84, 0.96)
	_mats["front"] = licht.call(_farbmaterial(Color.WHITE))
	(_mats["front"] as StandardMaterial3D).albedo_texture = karte.neu_bild("wand/front3d.png")
	(_mats["front"] as StandardMaterial3D).albedo_color = Color(0.78, 0.84, 0.96)
	_mats["fase"] = licht.call(_farbmaterial(Color("8d9cb0")))
	_mats["farbe"] = licht.call(_farbmaterial(Color.WHITE))
	(_mats["farbe"] as StandardMaterial3D).vertex_color_use_as_albedo = true
	_mats["leucht"] = _farbmaterial(Color.WHITE)
	(_mats["leucht"] as StandardMaterial3D).vertex_color_use_as_albedo = true
	var kontakt := _farbmaterial(Color(0, 0, 0, 0.28))
	kontakt.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	kontakt.render_priority = -1
	_mats["kontakt"] = kontakt
	var feld := _farbmaterial(Color(1, 1, 1, 0.75))
	feld.albedo_texture = karte.neu_bild("wand/scan.png")
	feld.uv1_scale = Vector3(1, 3, 1)
	feld.texture_repeat = true
	feld.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mats["feld"] = feld


## 17.11. (Paul: das erste Platzieren hing 4–5 s): Der Kompatibilitäts-Renderer übersetzt Shader erst, wenn etwas
## zum ersten Mal gezeichnet wird – bei der ersten Mauer, Fabrik oder Vorschau. Deshalb wird gleich beim Start einmal
## alles gezeichnet, was später auftaucht (Mauerteile in allen Stilen, Fabrikblock, Vorschau, Gebäudebilder,
## Leuchtgeschosse), ein paar Bilder lang mitten auf der Karte, und danach wieder entfernt. Im Startmenü liegt das
## Menü darüber, sonst blitzt es kurz auf.
var _warm: Array = []
var _warm_bilder := 0

func _vorwaermen() -> void:
	if _mats.is_empty():
		_wand_materialien()
	var z := Vector2i(Werte.SPALTEN / 2, Werte.ZEILEN / 2)
	var alt := _flaechen.duplicate()
	_flaechen.clear()
	_mauer(z, false)
	_mauer(z + Vector2i(1, 0), true)
	_bruestung(z)
	_wallpanzer(z)
	_energiewand(z + Vector2i(-1, 0))
	_tor(z + Vector2i(0, 1))
	_fabrik_block(z + Vector2i(1, 1))
	var mesh := ArrayMesh.new()
	var i := 0
	for name: String in _flaechen:
		var st: SurfaceTool = _flaechen[name]
		st.generate_normals()
		st.commit(mesh)
		mesh.surface_set_material(i, _mats[name])
		i += 1
	_flaechen = alt
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	add_child(mi)
	_warm.append(mi)
	# Vorschau-Geist und Gebäudebilder
	_bauvorschau()
	_geist_block.position = _welt_3d(karte.mitte(z), 0.0) + Vector3(0, H / 2.0, 0)
	_geist_block.visible = true
	var pfade := ["gebaeude/fabrik_grund.png", "gebaeude/fabrik_pilot.png", "gebaeude/basis_gross.png", "gebaeude/checkpoint.png",
		"gebaeude/checkpoint_feind.png", "tuerme/schild.png", "batterie/bat_0.png"]
	for typ: String in karte.FABRIK_BILDER:
		pfade.append("gebaeude/fabrik_%s.png" % karte.FABRIK_BILDER[typ])
	var n := 0
	for pfad: String in pfade:
		if not ResourceLoader.exists("res://assets/neu/" + pfad):
			continue
		var b := _neues_bild()
		b.texture = karte.neu_bild(pfad)
		b.region_rect = Rect2(Vector2.ZERO, b.texture.get_size())
		b.position = _welt_3d(karte.mitte(z + Vector2i(n % 3 - 1, n / 3 - 1)), 0.0)
		_warm.append(b)
		n += 1
	for g: Sprite3D in _geister:
		g.texture = karte.neu_bild("gebaeude/fabrik_grund.png")
		g.region_rect = Rect2(Vector2.ZERO, g.texture.get_size())
		g.position = _welt_3d(karte.mitte(z), 0.0)
		g.visible = true
	# ein Leuchtgeschoss (eigenes Material mit additiver Mischung)
	spiel.effekte.leuchtschuss(karte.mitte(z), 40.0, karte.mitte(z + Vector2i(2, 0)), 10.0, Color("7fe0ff"), 0.3, 12.0)
	_warm_bilder = 4
	set_process_internal(true)


func _notification(what: int) -> void:
	if what == NOTIFICATION_INTERNAL_PROCESS and _warm_bilder > 0:
		_warm_bilder -= 1
		if _warm_bilder == 0:
			for n: Node in _warm:
				if is_instance_valid(n):
					n.queue_free()
			_warm.clear()
			_geist_block.visible = false
			for g: Sprite3D in _geister:
				g.visible = false
			set_process_internal(false)


func _st(name: String) -> SurfaceTool:
	if not _flaechen.has(name):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		_flaechen[name] = st
	return _flaechen[name]


func _ist_wand(z: Vector2i) -> bool:
	return karte.feld.get(z, -1) == Karte.WALL


func _baue_waende() -> void:
	if _mats.is_empty():
		_wand_materialien()
	_flaechen.clear()
	var stil := Werte.wand_stil
	for z: Vector2i in karte.feld:
		var typ: int = karte.feld[z]
		if typ == Karte.FABRIK:
			_fabrik_block(z)
			continue
		if typ != Karte.WALL:
			continue
		var aus: int = karte.ausbau.get(z, Karte.FREI)
		if aus == Karte.TOR:
			_tor(z)
			continue
		var massiv := aus == Karte.STELLUNG or aus == Karte.TURM or karte.stuetze_von.has(z)
		if stil == "energie" and not massiv:
			_energiewand(z)
		else:
			_mauer(z, stil == "block")
		if aus == Karte.STELLUNG:
			_bruestung(z)
		if karte.panzer.has(z):
			_wallpanzer(z)
	# 18.11.: Felsen aus der Karten-Datei als unregelmäßige Steinklötze (Wasser liegt nur als Boden)
	for z: Vector2i in karte.gelaende:
		if karte.gelaende[z] == "fels":
			_fels(z)
	var mesh := ArrayMesh.new()
	var i := 0
	for name: String in _flaechen:
		var st: SurfaceTool = _flaechen[name]
		st.generate_normals()
		st.commit(mesh)
		mesh.surface_set_material(i, _mats[name])
		i += 1
	_waende.mesh = mesh
	_flaechen.clear()


func _viereck(st: SurfaceTool, ecken: Array, uvs: Array = [], farbe: Color = Color.WHITE) -> void:
	# Dreiecke so, dass die Vorderseite nach außen zeigt (Normalen für das Licht); beide Seiten werden gezeichnet
	for i: int in [0, 2, 1, 0, 3, 2]:
		st.set_color(farbe)
		if not uvs.is_empty():
			st.set_uv(uvs[i])
		st.add_vertex(ecken[i])


func _uv_boden(x: float, z: float) -> Vector2:
	return Vector2(x / float(Werte.SPALTEN), z / float(Werte.ZEILEN))


func _oben_viereck(x0: float, x1: float, z0: float, z1: float, y: float) -> void:
	_viereck(_st("oben"), [Vector3(x0, y, z0), Vector3(x1, y, z0), Vector3(x1, y, z1), Vector3(x0, y, z1)],
		[_uv_boden(x0, z0), _uv_boden(x1, z0), _uv_boden(x1, z1), _uv_boden(x0, z1)])


## Tech-Mauer (bzw. schlichter Block): Körper, Oberseite mit der Karte, abgeschrägte Kanten an offenen Seiten.
func _mauer(z: Vector2i, schlicht: bool) -> void:
	var x0 := float(z.x)
	var x1 := x0 + 1.0
	var z0 := float(z.y)
	var z1 := z0 + 1.0
	var n := _ist_wand(z + Vector2i.UP)
	var s := _ist_wand(z + Vector2i.DOWN)
	var w := _ist_wand(z + Vector2i.LEFT)
	var o := _ist_wand(z + Vector2i.RIGHT)
	var f := 0.0 if schlicht else FASE
	var hk := H - f   # Höhe des Körpers bis zur Fase
	# Oberseite (eingerückt an offenen Seiten)
	var ix0 := x0 + (0.0 if w else f)
	var ix1 := x1 - (0.0 if o else f)
	var iz0 := z0 + (0.0 if n else f)
	var iz1 := z1 - (0.0 if s else f)
	_oben_viereck(ix0, ix1, iz0, iz1, H)
	var seite := _st("seite")
	var uv4 := [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
	if not s:
		_viereck(_st("front"), [Vector3(x0, hk, z1), Vector3(x1, hk, z1), Vector3(x1, 0, z1), Vector3(x0, 0, z1)], uv4)
		if f > 0.0:
			_viereck(_st("fase"), [Vector3(ix0, H, iz1), Vector3(ix1, H, iz1), Vector3(x1 if o else ix1, hk, z1), Vector3(x0 if w else ix0, hk, z1)])
	if not n:
		_viereck(seite, [Vector3(x1, hk, z0), Vector3(x0, hk, z0), Vector3(x0, 0, z0), Vector3(x1, 0, z0)], uv4)
		if f > 0.0:
			_viereck(_st("fase"), [Vector3(ix1, H, iz0), Vector3(ix0, H, iz0), Vector3(x0 if w else ix0, hk, z0), Vector3(x1 if o else ix1, hk, z0)])
	if not w:
		_viereck(seite, [Vector3(x0, hk, z0), Vector3(x0, hk, z1), Vector3(x0, 0, z1), Vector3(x0, 0, z0)], uv4)
		if f > 0.0:
			_viereck(_st("fase"), [Vector3(ix0, H, iz0), Vector3(ix0, H, iz1), Vector3(x0, hk, z1 if s else iz1), Vector3(x0, hk, z0 if n else iz0)])
	if not o:
		_viereck(seite, [Vector3(x1, hk, z1), Vector3(x1, hk, z0), Vector3(x1, 0, z0), Vector3(x1, 0, z1)], uv4)
		if f > 0.0:
			_viereck(_st("fase"), [Vector3(ix1, H, iz1), Vector3(ix1, H, iz0), Vector3(x1, hk, z0 if n else iz0), Vector3(x1, hk, z1 if s else iz1)])
	if not schlicht:
		# weicher Kontaktschatten am Fuß, leicht nach hinten rechts versetzt wie das Licht
		var k := 0.08
		_viereck(_st("kontakt"), [Vector3(x0 - k + 0.06, 0.006, z0 - k + 0.1), Vector3(x1 + k + 0.06, 0.006, z0 - k + 0.1),
			Vector3(x1 + k + 0.06, 0.006, z1 + k + 0.1), Vector3(x0 - k + 0.06, 0.006, z1 + k + 0.1)])


## 18.11.: Felsbrocken – ein breiter Sockel und ein kleinerer, versetzter Stein darauf (je Feld anders, aus dem Hash).
func _fels(z: Vector2i) -> void:
	var h := hash(z)
	var x0 := float(z.x)
	var z0 := float(z.y)
	var hoch := H * (0.75 + float(h % 5) * 0.08)
	var stein := Color("7a7064")
	_klotz("farbe", x0 + 0.03, x0 + 0.97, 0.0, hoch, z0 + 0.03, z0 + 0.97, stein)
	var dx := float((h >> 4) % 3) * 0.1
	var dz := float((h >> 7) % 3) * 0.1
	_klotz("farbe", x0 + 0.15 + dx, x0 + 0.65 + dx, hoch, hoch + H * 0.35, z0 + 0.15 + dz, z0 + 0.65 + dz, stein.lightened(0.12))


## Quader mit einer Farbe (Licht über die Normalen).
func _klotz(name: String, x0: float, x1: float, y0: float, y1: float, z0: float, z1: float, farbe: Color) -> void:
	var st := _st(name)
	_viereck(st, [Vector3(x0, y1, z0), Vector3(x1, y1, z0), Vector3(x1, y1, z1), Vector3(x0, y1, z1)], [], farbe)
	_viereck(st, [Vector3(x0, y1, z1), Vector3(x1, y1, z1), Vector3(x1, y0, z1), Vector3(x0, y0, z1)], [], farbe)
	_viereck(st, [Vector3(x1, y1, z0), Vector3(x0, y1, z0), Vector3(x0, y0, z0), Vector3(x1, y0, z0)], [], farbe)
	_viereck(st, [Vector3(x0, y1, z0), Vector3(x0, y1, z1), Vector3(x0, y0, z1), Vector3(x0, y0, z0)], [], farbe)
	_viereck(st, [Vector3(x1, y1, z1), Vector3(x1, y1, z0), Vector3(x1, y0, z0), Vector3(x1, y0, z1)], [], farbe)


## Brüstung der Stellung: zwei Pfeiler und ein niedriges Mittelstück vorn, cyane Kante, dazu niedrige Seitenwangen.
func _bruestung(z: Vector2i) -> void:
	var x0 := float(z.x)
	var x1 := x0 + 1.0
	var z1 := float(z.y) + 1.0
	var d := Color("3a414b")
	_klotz("farbe", x0 + 0.04, x0 + 0.36, H, H + 0.36, z1 - 0.16, z1 - 0.04, d)
	_klotz("farbe", x1 - 0.36, x1 - 0.04, H, H + 0.36, z1 - 0.16, z1 - 0.04, d)
	_klotz("farbe", x0 + 0.36, x1 - 0.36, H, H + 0.24, z1 - 0.16, z1 - 0.04, d.darkened(0.1))
	_klotz("leucht", x0 + 0.04, x1 - 0.04, H + 0.36, H + 0.38, z1 - 0.16, z1 - 0.04, Color("6fe6ff"))
	_klotz("farbe", x0 + 0.02, x0 + 0.12, H, H + 0.28, z1 - 0.7, z1 - 0.16, d)
	_klotz("farbe", x1 - 0.12, x1 - 0.02, H, H + 0.28, z1 - 0.7, z1 - 0.16, d)


## Wallpanzer (16.11.): dicke Stahlplatten mit Nieten auf jeder offenen Seite der Mauer, oben eine helle Kante –
## so sieht man gepanzerte Wälle auf einen Blick (passend zum Symbol in der Bauleiste).
func _wallpanzer(z: Vector2i) -> void:
	var x0 := float(z.x)
	var x1 := x0 + 1.0
	var z0 := float(z.y)
	var z1 := z0 + 1.0
	var stahl := Color("6e7888")
	var kante := Color("aeb8c6")
	var niet := Color("dfe6ee")
	var d := 0.05     # so weit stehen die Platten vor
	var y0 := 0.06
	var y1 := H - FASE - 0.03
	var r := 0.07     # Rand zu den Ecken
	if not _ist_wand(z + Vector2i.DOWN):
		_klotz("farbe", x0 + r, x1 - r, y0, y1, z1, z1 + d, stahl)
		_klotz("farbe", x0 + r, x1 - r, y1 - 0.05, y1, z1, z1 + d + 0.01, kante)
		_klotz("farbe", x0 + 0.48, x0 + 0.52, y0, y1 - 0.05, z1 + d, z1 + d + 0.01, stahl.darkened(0.35))
		for nx: float in [x0 + r + 0.06, x1 - r - 0.06]:
			for ny: float in [y0 + 0.07, y1 - 0.12]:
				_klotz("farbe", nx - 0.03, nx + 0.03, ny - 0.03, ny + 0.03, z1 + d, z1 + d + 0.02, niet)
	if not _ist_wand(z + Vector2i.UP):
		_klotz("farbe", x0 + r, x1 - r, y0, y1, z0 - d, z0, stahl)
	if not _ist_wand(z + Vector2i.LEFT):
		_klotz("farbe", x0 - d, x0, y0, y1, z0 + r, z1 - r, stahl)
		_klotz("farbe", x0 - d - 0.01, x0, y1 - 0.05, y1, z0 + r, z1 - r, kante)
		for nz: float in [z0 + r + 0.06, z1 - r - 0.06]:
			_klotz("farbe", x0 - d - 0.02, x0 - d, y1 - 0.15, y1 - 0.09, nz - 0.03, nz + 0.03, niet)
	if not _ist_wand(z + Vector2i.RIGHT):
		_klotz("farbe", x1, x1 + d, y0, y1, z0 + r, z1 - r, stahl)
		_klotz("farbe", x1, x1 + d + 0.01, y1 - 0.05, y1, z0 + r, z1 - r, kante)
		for nz: float in [z0 + r + 0.06, z1 - r - 0.06]:
			_klotz("farbe", x1 + d, x1 + d + 0.02, y1 - 0.15, y1 - 0.09, nz - 0.03, nz + 0.03, niet)


## Energiewand: Sockel, Pfeiler an Enden und jedem zweiten Feld, durchscheinendes Abtastfeld, Strahlschiene oben.
func _energiewand(z: Vector2i) -> void:
	var cx := float(z.x) + 0.5
	var cz := float(z.y) + 0.5
	var n := _ist_wand(z + Vector2i.UP)
	var s := _ist_wand(z + Vector2i.DOWN)
	var w := _ist_wand(z + Vector2i.LEFT)
	var o := _ist_wand(z + Vector2i.RIGHT)
	var dunkel := Color("3a414b")
	_klotz("farbe", cx - 0.45, cx + 0.45, 0.0, 0.24, cz - 0.45, cz + 0.45, dunkel)
	if n:
		_klotz("farbe", cx - 0.45, cx + 0.45, 0.0, 0.24, cz - 0.55, cz - 0.45, dunkel)
	if w:
		_klotz("farbe", cx - 0.55, cx - 0.45, 0.0, 0.24, cz - 0.45, cz + 0.45, dunkel)
	var ende := int(n) + int(s) + int(w) + int(o) <= 1
	var waagrecht := (w or o) and not (n or s)
	if ende or (z.x if waagrecht else z.y) % 2 == 0:
		_klotz("farbe", cx - 0.11, cx + 0.11, 0.0, H + 0.1, cz - 0.11, cz + 0.11, Color("59626d"))
		_klotz("leucht", cx - 0.07, cx + 0.07, H + 0.1, H + 0.14, cz - 0.07, cz + 0.07, Color("6fe6ff"))
	# Feld und Schiene: entlang der Wandrichtung, je zur Hälfte zu jedem Nachbarn hin
	var y0 := 0.24
	var y1 := H - 0.06
	if waagrecht:
		var a := cx - (0.5 if w else 0.0)
		var b := cx + (0.5 if o else 0.0)
		_viereck(_st("feld"), [Vector3(a, y1, cz), Vector3(b, y1, cz), Vector3(b, y0, cz), Vector3(a, y0, cz)], [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)])
		_klotz("leucht", a, b, H - 0.06, H - 0.02, cz - 0.03, cz + 0.03, Color("6fe6ff"))
	else:
		var a := cz - (0.5 if n else 0.0)
		var b := cz + (0.5 if s else 0.0)
		if a == b:
			a -= 0.3
			b += 0.3
		_viereck(_st("feld"), [Vector3(cx, y1, a), Vector3(cx, y1, b), Vector3(cx, y0, b), Vector3(cx, y0, a)], [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)])
		_klotz("leucht", cx - 0.03, cx + 0.03, H - 0.06, H - 0.02, a, b, Color("6fe6ff"))


## Tor: zwei Pfeiler und ein Sturz mit Energiebalken; der Durchgang bleibt frei (Einheiten sieht man hindurchgehen).
func _tor(z: Vector2i) -> void:
	var x0 := float(z.x)
	var x1 := x0 + 1.0
	var z0 := float(z.y)
	var z1 := z0 + 1.0
	var quer := _ist_wand(z + Vector2i.LEFT) or _ist_wand(z + Vector2i.RIGHT)   # Wand läuft waagrecht: Durchgang nach Norden/Süden
	var stein := Color("6f7884")
	var cyan := Color("6fe6ff")
	if quer:
		_klotz("farbe", x0, x0 + 0.22, 0.0, H, z0 + 0.08, z1 - 0.08, stein)
		_klotz("farbe", x1 - 0.22, x1, 0.0, H, z0 + 0.08, z1 - 0.08, stein)
		_klotz("farbe", x0, x1, H - 0.16, H, z0 + 0.14, z1 - 0.14, stein.lightened(0.1))
		_klotz("leucht", x0 + 0.22, x1 - 0.22, H - 0.2, H - 0.16, z0 + 0.4, z0 + 0.6, cyan)
	else:
		_klotz("farbe", x0 + 0.08, x1 - 0.08, 0.0, H, z0, z0 + 0.22, stein)
		_klotz("farbe", x0 + 0.08, x1 - 0.08, 0.0, H, z1 - 0.22, z1, stein)
		_klotz("farbe", x0 + 0.14, x1 - 0.14, H - 0.16, H, z0, z1, stein.lightened(0.1))
		_klotz("leucht", x0 + 0.4, x0 + 0.6, H - 0.2, H - 0.16, z0 + 0.22, z1 - 0.22, cyan)


## Fabrik (16.11. massiver): Metallsockel mit Fase, Eckbolzen und Leuchtstreifen vorn, darunter ein Kontaktschatten.
## Die Oberseite zeigt weiter die Karte (Stufe, Fortschritt); das Gebäude selbst steht als Sprite3D auf dem Sockel.
const FABRIK_SOCKEL := 0.15

func _fabrik_block(z: Vector2i) -> void:
	var fh := FABRIK_SOCKEL
	var x0 := float(z.x) + 0.04
	var x1 := float(z.x) + 0.96
	var z0 := float(z.y) + 0.06
	var z1 := float(z.y) + 0.96
	var stahl := Color("3a414b")
	var dunkel := Color("252a32")
	# Schatten nach hinten rechts wie beim Licht der Mauern
	var k := 0.1
	_viereck(_st("kontakt"), [Vector3(x0 - k + 0.08, 0.006, z0 - k + 0.12), Vector3(x1 + k + 0.08, 0.006, z0 - k + 0.12),
		Vector3(x1 + k + 0.08, 0.006, z1 + k + 0.12), Vector3(x0 - k + 0.08, 0.006, z1 + k + 0.12)])
	# Fuß (breiter, dunkel) und Sockel mit abgeschrägter Oberkante
	_klotz("farbe", x0 - 0.02, x1 + 0.02, 0.0, 0.04, z0 - 0.02, z1 + 0.02, dunkel)
	_klotz("farbe", x0, x1, 0.04, fh - 0.03, z0, z1, stahl)
	_klotz("farbe", x0 + 0.03, x1 - 0.03, fh - 0.03, fh - 0.001, z0 + 0.03, z1 - 0.03, stahl.lightened(0.18))
	_oben_viereck(x0 + 0.06, x1 - 0.06, z0 + 0.06, z1 - 0.06, fh)
	# Eckbolzen und Leuchtstreifen vorn
	for bx: float in [x0 + 0.03, x1 - 0.11]:
		for bz: float in [z0 + 0.03, z1 - 0.11]:
			_klotz("farbe", bx, bx + 0.08, fh - 0.001, fh + 0.025, bz, bz + 0.08, Color("8d9cb0"))
	_klotz("leucht", x0 + 0.18, x1 - 0.18, 0.055, 0.075, z1, z1 + 0.006, Color("6fe6ff"))


## Geworfene Steine, Einheiten und Granaten (16.11.): fliegen als Sprite3D in echter Höhe und überschlagen sich;
## Schatten, Staub und Splitter zeichnet effekte.gd am Boden.
var _wurf_bilder: Array = []

## Leuchtgeschosse (Gefechtsturm, Batterie, 16.11.): ein heller Kopf und ein Schweif aus kleiner werdenden Glühpunkten,
## in echter Höhe zwischen Mündung und Ziel; Sprites werden wiederverwendet.
var _leucht_bilder: Array = []
var _glut: ImageTexture
const LEUCHT_SCHWEIF := 9
var _glut_mat: StandardMaterial3D

func _leucht_weiter() -> void:
	var liste: Array = spiel.effekte.leucht
	if _glut == null:
		var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
		for y in 16:
			for x in 16:
				var d := Vector2(x - 7.5, y - 7.5).length() / 7.5
				var a := clampf(1.0 - d, 0.0, 1.0)
				var kern := clampf(1.0 - d * 2.2, 0.0, 1.0)
				img.set_pixel(x, y, Color(lerpf(1.0, 1.0, kern), 1.0, 1.0, a * a))
		_glut = ImageTexture.create_from_image(img)
		_glut_mat = StandardMaterial3D.new()
		_glut_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_glut_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_glut_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_glut_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		_glut_mat.vertex_color_use_as_albedo = true
		_glut_mat.albedo_texture = _glut
		_glut_mat.no_depth_test = true
		_glut_mat.render_priority = 10
	var noetig := liste.size() * (LEUCHT_SCHWEIF + 1)
	while _leucht_bilder.size() < noetig:
		var b := Sprite3D.new()
		b.texture = _glut
		b.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
		b.shaded = false
		b.double_sided = true
		b.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		b.no_depth_test = false
		b.render_priority = 10
		b.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
		b.transparent = true
		b.material_override = _glut_mat
		add_child(b)
		_leucht_bilder.append(b)
	for b: Sprite3D in _leucht_bilder:
		b.visible = false
	var i := 0
	for l: Array in liste:
		var t: float = float(l[5]) / float(l[6])
		var farbe: Color = l[4]
		var dicke: float = l[7]
		for s in LEUCHT_SCHWEIF + 1:
			var b: Sprite3D = _leucht_bilder[i]
			i += 1
			var tt := t - s * 0.045
			if tt < 0.0:
				continue
			var lage: Array = Effekte.leucht_lage(l, tt)
			b.visible = true
			b.position = _welt_3d(lage[0], float(lage[1]) / Werte.ZELLE)
			var groesse := dicke / Werte.ZELLE * (1.0 - s * 0.07) * 1.8
			b.pixel_size = groesse / 16.0 * (1.5 if s == 0 else 1.0)
			b.modulate = Color(1.0, 1.0, 1.0, 1.0) if s == 0 else Color(farbe, 1.0 - s * 0.09)


func _wuerfe_weiter() -> void:
	var liste: Array = spiel.effekte.wuerfe()
	while _wurf_bilder.size() < liste.size():
		var b := Sprite3D.new()
		b.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		b.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		b.shaded = false
		b.double_sided = true
		b.centered = true
		b.region_enabled = true
		add_child(b)
		_wurf_bilder.append(b)
	for i in _wurf_bilder.size():
		var b: Sprite3D = _wurf_bilder[i]
		b.visible = false
		if i >= liste.size():
			continue
		var w: Array = liste[i]
		var bild: Dictionary = w[6]
		var lage: Array = spiel.effekte.wurf_lage(w)
		if bild.is_empty() or not lage[3]:
			continue
		b.visible = true
		b.texture = bild["tex"]
		b.region_rect = bild["quelle"]
		b.pixel_size = float(bild["massstab"]) / Werte.ZELLE
		var q: Rect2 = bild["quelle"]
		b.position = _welt_3d(lage[0], float(lage[1]) / Werte.ZELLE + q.size.y * b.pixel_size * 0.5)
		b.global_transform.basis = kamera.global_transform.basis * Basis(Vector3(0, 0, 1), -float(lage[2]))


## Energieschild der Batterie (16.11.): senkrechte Energiewand zwischen den Innenseiten zweier Erdwälle,
## so hoch wie die Mauer. Waagrechte Lichtlinien wandern, oben blendet sie aus; je weniger Leben, desto schwächer und flackernder.
var _schild_waende: Array = []   # MeshInstance3D je Schild
var _schild_shader: Shader

func _schilde_weiter() -> void:
	var liste: Array = spiel.effekte.schilde
	while _schild_waende.size() > liste.size():
		(_schild_waende.pop_back() as Node).queue_free()
	if _schild_shader == null:
		_schild_shader = Shader.new()
		_schild_shader.code = """
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;
uniform float laenge = 1.0;
uniform float anteil = 1.0;
uniform float aktiv = 1.0;
void fragment() {
	float x = floor(UV.x * laenge * 24.0) / (laenge * 24.0);
	float y = 1.0 - floor(UV.y * 20.0) / 20.0;            // 0 unten, 1 oben, in Pixelstufen
	float linien = step(0.6, fract(y * 6.0 - TIME * 1.2));
	float kante = step(y, 0.06) + step(0.94, y) * 0.6;
	float flacker = anteil < 0.35 ? step(0.25, fract(sin(floor(TIME * 14.0) * 12.9898) * 43758.5)) : 1.0;
	float fuell = (0.18 + 0.22 * linien) * (1.0 - y * 0.55) + kante * 0.55;
	float a = fuell * (0.45 + 0.55 * anteil) * flacker;
	a = mix(kante * 0.25, a, aktiv);
	vec3 farbe = mix(vec3(0.3, 0.85, 1.0), vec3(0.9, 1.0, 1.0), kante + linien * 0.25);
	ALBEDO = farbe;
	ALPHA = clamp(a, 0.0, 0.85);
}
"""
	for i in liste.size():
		var e: Array = liste[i]
		if i >= _schild_waende.size():
			var mi := MeshInstance3D.new()
			mi.mesh = QuadMesh.new()
			var mat := ShaderMaterial.new()
			mat.shader = _schild_shader
			mi.material_override = mat
			add_child(mi)
			# leuchtende Oberkante als flaches Band: so sieht man auch Strahlen, die zur Kamera hin laufen
			var kappe := MeshInstance3D.new()
			kappe.mesh = QuadMesh.new()
			var km := StandardMaterial3D.new()
			km.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			km.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			km.albedo_color = Color(0.75, 0.97, 1.0, 0.8)
			kappe.material_override = km
			kappe.rotation = Vector3(-PI / 2.0, 0, 0)
			kappe.name = "kappe"
			mi.add_child(kappe)
			_schild_waende.append(mi)
		var w: MeshInstance3D = _schild_waende[i]
		var a := karte.zelle_bei(e[0])
		var b := karte.zelle_bei(e[1])
		var felder := maxi(absi(b.x - a.x), absi(b.y - a.y)) - 1
		var mitte := (Vector2(a) + Vector2(b)) / 2.0 + Vector2(0.5, 0.5)
		(w.mesh as QuadMesh).size = Vector2(float(felder), H * 0.92)
		w.position = Vector3(mitte.x, H * 0.46, mitte.y)
		w.rotation = Vector3(0, PI / 2.0 if a.x == b.x else 0.0, 0)
		var kappe: MeshInstance3D = w.get_node("kappe")
		(kappe.mesh as QuadMesh).size = Vector2(float(felder), 0.1)
		kappe.position = Vector3(0, H * 0.46, 0)
		(kappe.material_override as StandardMaterial3D).albedo_color.a = (0.35 + 0.5 * float(e[2])) if e[3] else 0.15
		var m: ShaderMaterial = w.material_override
		m.set_shader_parameter("laenge", float(felder))
		m.set_shader_parameter("anteil", float(e[2]))
		m.set_shader_parameter("aktiv", 1.0 if e[3] else 0.0)


## Klonmaschine [R] (16.11.): flache Bodenplatte mit lila Rand, aus der ein Laserfeld nach oben steigt
## (Zylinder mit Streifen, nach oben ausblendend, ein heller Ring wandert hoch). Die 2D-Zeichnung ist in HD-2D aus.
var _klon: Node3D = null
var _klon_zelle := Karte.KEINE
const KLON_HOEHE := 1.6

func _klon_weiter() -> void:
	var km: Node = spiel.klonmaschine
	var da := km != null and is_instance_valid(km)
	if not da or (_klon != null and _klon_zelle != km.zelle):
		if _klon != null:
			_klon.queue_free()
			_klon = null
		if not da:
			return
	if _klon != null:
		return
	_klon_zelle = km.zelle
	_klon = Node3D.new()
	_klon.position = Vector3(float(_klon_zelle.x) + 0.5, 0.0, float(_klon_zelle.y) + 0.5)
	add_child(_klon)
	var platte := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.82, 0.06, 0.82)
	platte.mesh = bm
	var pm := StandardMaterial3D.new()
	pm.albedo_color = Color("2a2038")
	pm.roughness = 1.0
	platte.material_override = pm
	platte.position.y = 0.03
	_klon.add_child(platte)
	var leucht := StandardMaterial3D.new()
	leucht.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	leucht.albedo_color = Color("c9a6ff")
	for seite in 4:
		var rand := MeshInstance3D.new()
		var rm := BoxMesh.new()
		rm.size = Vector3(0.7, 0.025, 0.04) if seite < 2 else Vector3(0.04, 0.025, 0.7)
		rand.mesh = rm
		rand.material_override = leucht
		rand.position = Vector3(0.0 if seite >= 2 else 0.0, 0.07, (-0.33 if seite == 0 else 0.33) if seite < 2 else 0.0)
		if seite >= 2:
			rand.position.x = -0.33 if seite == 2 else 0.33
		_klon.add_child(rand)
	var feld := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.33
	cm.bottom_radius = 0.33
	cm.height = KLON_HOEHE
	cm.cap_top = false
	cm.cap_bottom = false
	cm.radial_segments = 24
	feld.mesh = cm
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec3 farbe = vec3(0.78, 0.5, 1.0);
uniform float hoehe = 1.15;
varying float h;
void vertex() { h = VERTEX.y / hoehe + 0.5; }
void fragment() {
	float hq = floor(h * 28.0) / 28.0;                 // Pixelstufen statt weichem Verlauf
	float ux = floor(UV.x * 48.0) / 48.0;
	float fade = pow(1.0 - hq, 1.2);
	float streifen = step(0.55, fract(ux * 12.0 + TIME * 0.35));
	float band = step(abs(hq - fract(TIME * 0.6)), 0.03);
	float a = fade * (0.3 + 0.45 * streifen) + band * 0.8 * (1.0 - hq);
	ALBEDO = mix(farbe, vec3(1.0, 0.92, 1.0), band * 0.7 + streifen * fade * 0.35);
	ALPHA = clamp(a, 0.0, 0.9);
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = sh
	mat.set_shader_parameter("hoehe", KLON_HOEHE)
	feld.material_override = mat
	feld.position.y = 0.06 + KLON_HOEHE / 2.0
	_klon.add_child(feld)


## Einsetz-Animation: neue Fabriken fallen von oben auf ihren Sockel, federn kurz nach und wirbeln Staub auf.
const FABRIK_FALL_SEK := 0.32
const FABRIK_FEDER_SEK := 0.22
var _fabrik_seit := {}   # Zelle -> Zeitpunkt (Sekunden) des Einsetzens
var _bauten_erstes := true

func _fabrik_einsetzen(z: Vector2i, b: Sprite3D, fuss: Vector3) -> void:
	var t0: float = _fabrik_seit.get(z, -1.0)
	b.scale = Vector3.ONE
	b.position = fuss
	if t0 < 0.0:
		return
	var t := Time.get_ticks_msec() / 1000.0 - t0
	if t < FABRIK_FALL_SEK:
		var f := t / FABRIK_FALL_SEK
		b.position = fuss + Vector3(0, (1.0 - f * f) * 2.2, 0)
		b.scale = Vector3(0.94, 1.08, 1.0)
	elif t < FABRIK_FALL_SEK + FABRIK_FEDER_SEK:
		if not b.get_meta("gelandet", false):
			b.set_meta("gelandet", true)
			spiel.effekte.fx("rauch", karte.mitte(z) + Vector2(0, 22), 0.22)
		var f := (t - FABRIK_FALL_SEK) / FABRIK_FEDER_SEK
		var d := sin(f * PI) * (1.0 - f) * 0.35
		b.scale = Vector3(1.0 + d * 0.5, 1.0 - d, 1.0)
	else:
		_fabrik_seit.erase(z)


# ------------------------------------------------------------------ Kulisse (Rand wie Wandering Sword / Terrain-Conquester)

## Vignette und Farbstimmung (16.11.): Ränder leicht abgedunkelt und kühler, die Mitte minimal wärmer – bindet Spielfeld
## und Umland zu einem Bild. Liegt unter der Spielleiste (gleiche Ebene, aber vor ihr im Baum).
var _vignette_ebene: CanvasLayer

func _vignette() -> void:
	_vignette_ebene = CanvasLayer.new()
	_vignette_ebene.layer = 1
	var flaeche := ColorRect.new()
	flaeche.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flaeche.size = Vector2(1280, 720)
	var sh := Shader.new()
	sh.code = """
shader_type canvas_item;
uniform sampler2D bild : hint_screen_texture, filter_linear;
void fragment() {
	// Tilt-Shift: oben (Ferne) und ganz unten leicht unscharf wie eine Miniatur – die Mitte (Spielfeld) bleibt scharf
	float unschaerfe = smoothstep(0.34, 0.06, SCREEN_UV.y) * 2.6 + smoothstep(0.86, 1.0, SCREEN_UV.y) * 1.4;
	vec3 c = texture(bild, SCREEN_UV).rgb;
	if (unschaerfe > 0.05) {
		vec3 summe = c;
		for (int i = 0; i < 8; i++) {
			float w = float(i) * 0.785398;
			vec2 o = vec2(cos(w), sin(w)) * SCREEN_PIXEL_SIZE * unschaerfe;
			summe += texture(bild, SCREEN_UV + o).rgb + texture(bild, SCREEN_UV + o * 2.0).rgb;
		}
		c = summe / 17.0;
		// Ferne etwas entsättigt und kühler
		float grau = dot(c, vec3(0.3, 0.59, 0.11));
		c = mix(c, vec3(grau) * vec3(0.92, 0.98, 1.04), clamp(unschaerfe * 0.12, 0.0, 0.3));
	}
	vec2 p = UV - vec2(0.5, 0.52);
	p.x *= 1.35;
	float rand = smoothstep(0.32, 0.78, length(p));
	c = mix(c * vec3(1.02, 1.0, 0.97), vec3(0.02, 0.05, 0.08), rand * rand * 0.62);
	COLOR = vec4(c, 1.0);
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = sh
	flaeche.material = mat
	_vignette_ebene.add_child(flaeche)
	spiel.add_child(_vignette_ebene)
	spiel.move_child(_vignette_ebene, 0)   # vor der Spielleiste im Baum: wird unter ihr gezeichnet


## Das Spielfeld liegt auf Bodenhöhe in einer Landschaft (16.11. nachmittags, statt Plateau mit Kante):
## ringsum dasselbe Gras mit denselben Flecken, nach außen mehr Erde und Fels, links setzt sich die Brut-Zone fort,
## nach außen wird es dunkler. Dahinter Wald. Alles fest gesetzt (eigener Zufall, der Spielzufall bleibt unberührt).
const UMLAND := 14   # Rand in Feldern, der als Landschaftsbild gemalt wird

func _kulisse() -> void:
	var sw := float(Werte.SPALTEN)
	var zh := float(Werte.ZEILEN)
	var r := RandomNumberGenerator.new()
	r.seed = 4711
	var t0 := Time.get_ticks_msec()
	# Ferne: großer, dunkler Boden bis zum Horizont (verschwindet im Dunst)
	var gras_bild: Image = karte.neu_bild("terrain/SHEET2.png").get_image()
	gras_bild.convert(Image.FORMAT_RGBA8)
	var fern := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	fern.blit_rect(gras_bild, Rect2i(0, 0, 32, 32), Vector2i.ZERO)
	var fern_mat := _farbmaterial(Color(0.36, 0.4, 0.36))
	fern_mat.albedo_texture = ImageTexture.create_from_image(fern)
	fern_mat.texture_repeat = true
	fern_mat.uv1_scale = Vector3(sw + 200.0, zh + 200.0, 1)
	var aussen := _flaeche(Vector2(sw + 200.0, zh + 200.0), fern_mat)
	aussen.position = Vector3(sw / 2.0, -1.8, zh / 2.0)   # tief genug für die Wiese unterhalb der vorderen Böschung
	# Nah: das gemalte Umland als Gelände mit Höhen (hinten ein Hang, an den Seiten Hügel, vorn eine flache Böschung)
	var umland_mat := _farbmaterial(Color.WHITE)
	umland_mat.albedo_texture = ImageTexture.create_from_image(_umland_bild())
	umland_mat.vertex_color_use_as_albedo = true
	var gelaende := MeshInstance3D.new()
	_plan = _plane_stuecke(r)   # vorher: große Stücke bekommen ebenen Grund (gelaende_hoehe)
	gelaende.mesh = _gelaende_netz()
	gelaende.material_override = umland_mat
	add_child(gelaende)
	# Kulissenstücke: links das Myr-Brutgebiet, rechts der Technoclan-Außenposten, Felsen markieren vorn und hinten den Rand
	var stuecke := _kulissenstuecke(r)
	stuecke.append_array(_zuschauer_aufstellen(r))
	# Wald: Bäume aus dem TC-Blatt, hinten dicht, an den Seiten locker, vorn nur vereinzelt
	var baeume: Texture2D = karte.neu_bild("terrain/SHEET2.png")
	var arten := [0, 1, 2, 3, 4, 5, 7, 14]
	for i in 260:
		var p := Vector3(r.randf_range(-16.0, sw + 16.0), 0.0, r.randf_range(-13.0, zh + 6.0))
		if p.x > -1.3 and p.x < sw + 1.3 and p.z > -1.6 and p.z < zh + 1.4:
			continue
		if p.x < float(Werte.ZONE_SPALTEN) and p.z > -3.0 and p.z < zh + 2.0:
			continue   # links liegt die Brut-Zone: kahl
		if p.z > zh + 1.4 and r.randf() < 0.7:
			continue   # vorn lichter, damit der Rand das Spielfeld nicht verdeckt
		var frei := true
		for st: Vector3 in stuecke:
			if Vector2(p.x - st.x, p.z - st.z).length() < st.y:
				frei = false
		if not frei:
			continue   # nicht in die Kulissenstücke hinein
		var b := _neues_bild()
		b.texture = baeume
		var art: int = arten[r.randi() % arten.size()]
		b.region_rect = Rect2(art * 64, 32, 64, 64)
		b.pixel_size = r.randf_range(1.6, 2.3) / Werte.ZELLE
		b.offset = Vector2(-32, -4)
		var dunkel := clampf(1.0 - _abseits(p.x, p.z) * 0.035, 0.6, 1.0)
		b.modulate = Color(0.86, 0.92, 0.86) * dunkel
		p.y = gelaende_hoehe(p.x, p.z)
		b.position = p
	# Vordergrund: große Baumkronen unten auf der Wiese vor der Böschung – rahmen das Bild (unten leicht unscharf)
	var vx := -3.0
	while vx < sw + 3.0:
		var p := Vector3(vx + r.randf_range(-1.0, 1.0), 0.0, zh + r.randf_range(3.1, 4.0))
		vx += r.randf_range(3.5, 6.0)
		if p.x > sw * 0.3 and p.x < sw * 0.7 and r.randf() < 0.6:
			continue   # in der Mitte lichter
		var verdeckt := false
		for zs: Dictionary in _zuschauer:
			if absf((zs["ort"] as Vector3).x - p.x) < 1.3 and (zs["ort"] as Vector3).z > zh:
				verdeckt = true
		if verdeckt:
			continue   # nicht vor die Zuschauer
		p.y = gelaende_hoehe(p.x, p.z)
		var b := _neues_bild()
		b.texture = baeume
		b.region_rect = Rect2(([0, 1, 3, 4] as Array)[r.randi() % 4] * 64, 32, 64, 64)
		b.pixel_size = r.randf_range(2.4, 3.0) / Werte.ZELLE
		b.offset = Vector2(-32, -4)
		b.flip_h = r.randf() < 0.5
		b.modulate = Color(0.62, 0.68, 0.64)   # im Schatten, etwas dunkler als das Spielfeld
		b.position = p
	print("HD-Kulisse: %d ms" % (Time.get_ticks_msec() - t0))


var _hoehen_rauschen: FastNoiseLite

# ------------------------------------------------------------------ Zuschauer (Helden aus Pauls RPG „Pauls Mini-Adventure“)
## Bilder: Neue Grafik des RPG (PixelLab, Figuren 28×32, Angriff 44×44), je Held ein Blatt: Zeile 0 vorne/Süd/Ost/West, 1 Laufen Süd (4), 2 Angriff (7),
## 3 Laufen Ost (4); Zellen 44×44, Füße unten in der Mitte. Sie stehen vorn auf der Böschung und hinten am Hang. Klick = Tanzen (Tanzschritte wie im RPG,
## dancePose69), Klick beim Tanzen = Angriffs-Pose. Sonst schauen sie sich um und jubeln ab und zu.
## Alle 71 Helden aus dem RPG (16.11.); je Partie stehen 5–10 davon. 24 haben dort nur Standbilder: Bei ihnen zeigen
## Lauf- und Angriffszeile das Standbild von vorn.
const ZUSCHAUER := ["glenys", "ouzo", "gerold", "wicht", "adela", "aldric", "birte", "bodo", "bolle", "bram", "brann", "cord",
	"dagny", "deicen", "dorte", "eckhart", "elske", "enno", "fenja", "fenn", "fips", "gerda", "greta", "gunther",
	"gustav", "hanne", "hedda", "hex", "hinnerk", "ilva", "immo", "jarek", "joris", "jost", "juno", "kage",
	"kasimir", "konrad", "ley", "linail", "lioba", "liska", "lorenz", "lotte", "marlo", "minna", "mira", "morla",
	"nyx", "oda", "olek", "oratio", "ottilie", "pim", "prime", "quirin", "rieke", "ronja", "runa", "selma",
	"sunna", "tamino", "tilda", "tobin", "ulrich", "veit", "wenzel", "wilma", "wyvera", "yara", "zwambo"]
const TANZSCHRITTE := ["wippen", "wiegen", "drehen", "huepfen", "schieben", "ducken", "strecken", "roboter", "moonwalk",
	"pirouette", "pogo", "headbang", "shimmy", "zeigen", "abtauchen"]
const TAKT := 0.5   # Sekunden je Schlag beim Tanzen
## Holztribüne (kulisse/tribuene.png, 192×160, PixelLab 16.11.): Lage am Hang und die Stehplätze der Helden in Bildpunkten
## des Tribünenbilds (Füße auf den Bankreihen). Die Helden stehen in der Bildebene der Tribüne, ein Stück davor.
const TRIB_X := 0.66          # Anteil der Spielfeldbreite
const TRIB_Z := -1.9          # Felder hinter der Hinterkante
const TRIB_FUSS := 149        # unterste Bildzeile der Tribüne (steht auf dem Boden)
const TRIB_BREITE := 192
const TRIB_MASSSTAB := 1.4    # Bildpunkt-Größe von Tribüne und Helden darauf (Helden sonst 2.0): wirkt weiter weg, drängt sich nicht vor
const TRIB_PLAETZE := [Vector2(72, 40), Vector2(124, 62), Vector2(52, 52), Vector2(100, 73), Vector2(80, 86)]
var _tribuene_ort := Vector3.INF
const Z_ZELLE := 44  # Zellen im Zuschauer-Blatt (Angriffsbilder sind 44×44, Füße jeweils unten in der Mitte)
var _zuschauer: Array[Dictionary] = []
var _zrng := RandomNumberGenerator.new()   # eigener Zufall: der globale gehört dem Spiel


func _zuschauer_aufstellen(r: RandomNumberGenerator) -> Array:
	var sw := float(Werte.SPALTEN)
	var zh := float(Werte.ZEILEN)
	var ids := ZUSCHAUER.duplicate()
	for i in range(ids.size() - 1, 0, -1):   # gemischt, aber fest (Zufall der Kulisse)
		var j := r.randi_range(0, i)
		var t: String = ids[i]
		ids[i] = ids[j]
		ids[j] = t
	var orte: Array = []
	# vorn auf der Böschung, einzeln oder zu zweit
	var x := 2.6
	while x < sw - 0.5:
		orte.append(Vector2(x + r.randf_range(-0.4, 0.4), zh + r.randf_range(1.25, 1.6)))
		if r.randf() < 0.35:
			orte.append(Vector2(x + 0.6, zh + r.randf_range(1.3, 1.6)))
		x += r.randf_range(2.4, 4.2)
	# hinten am Hang und weiter oben
	x = 2.0
	while x < sw - 1.0:
		orte.append(Vector2(x + r.randf_range(-0.5, 0.5), -r.randf_range(1.6, 3.6)))
		x += r.randf_range(3.5, 6.0)
	# Je Partie andere Helden (16.11.): 5 bis 10 aus allen, an zufällig gewählten Plätzen. Eigener Zufall, damit die
	# feste Kulisse (Bäume, Felsen) gleich bleibt.
	_zrng.randomize()
	var wahl: Array = ids.duplicate()
	for i in range(wahl.size() - 1, 0, -1):
		var j := _zrng.randi_range(0, i)
		var t: String = wahl[i]
		wahl[i] = wahl[j]
		wahl[j] = t
	var ort_nr: Array = range(orte.size())
	for i in range(ort_nr.size() - 1, 0, -1):
		var j := _zrng.randi_range(0, i)
		var t: int = ort_nr[i]
		ort_nr[i] = ort_nr[j]
		ort_nr[j] = t
	var frei: Array = []
	for n: int in ort_nr:
		var o0: Vector2 = orte[n]
		if _tribuene_ort == Vector3.INF or Vector2(o0.x - _tribuene_ort.x, o0.y - _tribuene_ort.z).length() > 2.8:
			frei.append(o0)
	var auf_tribuene := TRIB_PLAETZE.size() if _tribuene_ort != Vector3.INF else 0
	# Nur noch die Helden auf der Tribüne (Paul 16.11.); ohne Tribüne (alte Kulisse) wie früher 5 bis 10 verteilt
	var anzahl := auf_tribuene if auf_tribuene > 0 else mini(_zrng.randi_range(5, 10), mini(frei.size(), wahl.size()))
	var plaetze: Array = []
	for i in anzahl:
		var id: String = wahl[i]
		var sitz: Variant = TRIB_PLAETZE[i] if i < auf_tribuene else null
		var o: Vector2 = Vector2(_tribuene_ort.x, _tribuene_ort.z) if sitz != null else frei[i - auf_tribuene]
		var b := _neues_bild()
		b.texture = karte.neu_bild("zuschauer/%s.png" % id)
		b.region_rect = Rect2(Z_ZELLE, 0, Z_ZELLE, Z_ZELLE)
		b.pixel_size = 2.0 / Werte.ZELLE
		b.offset = Vector2(-Z_ZELLE / 2.0, -1)
		var ort := Vector3(o.x, gelaende_hoehe(o.x, o.y), o.y)
		b.position = ort
		var name := id.capitalize()
		_zuschauer.append({"b": b, "id": id, "name": name, "ort": ort, "schritte": _eigene_schritte(name),
			"tanz": -1.0, "angriff": -1.0, "jubel": -1.0, "blick": 1, "blick_t": 0.0, "naechstes": _zrng.randf_range(1.0, 6.0)})
		if sitz != null:
			_zuschauer[-1]["sitz"] = sitz
			b.pixel_size = TRIB_MASSSTAB / Werte.ZELLE
		else:
			plaetze.append(Vector3(o.x, 0.8, o.y))
	return plaetze


## Wie moveOf69 im RPG: drei eigene Schritte aus dem Namen (Hash h*31+Zeichen, 32 Bit).
func _eigene_schritte(name: String) -> Array:
	var h := 0
	for c in name:
		h = (h * 31 + c.unicode_at(0)) & 0xFFFFFFFF
	var liste: Array = []
	for k in [TANZSCHRITTE[h % 15], TANZSCHRITTE[(h >> 4) % 15], TANZSCHRITTE[(h >> 8) % 15]]:
		if not liste.has(k):
			liste.append(k)
	return liste


## dancePose69 aus dem RPG: Versatz (dx, dy in Bildpunkten, y nach unten), Streckung (sx, sy), Spiegeln. Drehung entfällt (Billboard).
func _tanzpose(m: String, f: float, bi: int) -> Dictionary:
	var s := sin(f * PI)
	var b4 := posmod(bi, 4)
	match m:
		"wippen": return {"dy": -roundf(s * 2.0), "sy": 1.0 + 0.06 * s}
		"wiegen": return {"dx": roundf(sin((bi + f) * PI) * 3.0), "dy": -roundf(s)}
		"drehen": return {"flip": bi % 2 == 1, "dy": -roundf(s * 2.0)}
		"huepfen": return {"dy": -roundf(maxf(0.0, sin(f * PI)) * 6.0), "sy": 0.9 if f > 0.85 else 1.0}
		"schieben": return {"dx": roundf((posmod(bi, 4) + f) / 4.0 * 8.0 - 4.0), "flip": posmod(bi, 8) >= 4}
		"ducken": return {"sy": 1.0 - 0.14 * s}
		"strecken": return {"sy": 1.0 + 0.1 * s, "sx": 1.0 - 0.04 * s, "dy": -roundf(s * 2.0)}
		"roboter":
			var hh := bi * 2 + (0 if f < 0.5 else 1)
			var P := [[0, 0], [2, 0], [2, -1], [0, 0], [-2, 0], [-2, -1], [0, -2], [0, 0]][hh % 8] as Array
			return {"dx": P[0], "dy": P[1], "flip": hh % 4 >= 2}
		"moonwalk":
			var t := (posmod(bi, 8) + f) / 8.0
			var dir := 1.0 if (bi / 8) % 2 == 1 else -1.0
			return {"dx": roundf(dir * (t * 16.0 - 8.0)), "dy": -roundf(absf(sin(f * PI))), "flip": dir > 0.0}
		"pirouette":
			if b4 < 2:
				var c := cos(((b4 + f) / 2.0) * TAU)
				return {"sx": maxf(0.18, absf(c)), "flip": c < 0.0, "dy": -roundf(sin((b4 + f) / 2.0 * PI) * 3.0), "sy": 1.04}
			return {"sy": 1.0 + 0.05 * s}
		"pogo": return {"dy": -roundf(sin(f * PI) * 9.0), "sy": 0.88 if (f < 0.12 or f > 0.9) else 1.04}
		"headbang":
			var q := sin(fmod(f * 2.0, 1.0) * PI)
			return {"dy": roundf(q), "sy": 1.0 - 0.04 * q}
		"shimmy": return {"dx": roundf(sin(f * PI * 8.0) * 1.6), "sy": 1.0 + 0.03 * sin(f * PI * 4.0), "dy": -roundf(s)}
		"zeigen": return {"sy": 1.0 + (-0.04 if b4 % 2 == 1 else 0.08), "dy": -(0 if b4 % 2 == 1 else 2), "flip": b4 >= 2}
		"abtauchen":
			if b4 == 3:
				return {"sy": 0.72 + 0.2 * (1.0 - f), "sx": 1.15}
			if b4 == 0 and f < 0.4:
				return {"sy": 1.12, "dy": -roundf((1.0 - f / 0.4) * 5.0)}
			return {"dy": -roundf(s)}
	return {}


func _zuschauer_weiter(dt: float) -> void:
	var jetzt := Time.get_ticks_msec() / 1000.0
	var achsen := kamera.global_transform.basis
	var ps := TRIB_MASSSTAB / Werte.ZELLE
	for z: Dictionary in _zuschauer:
		var b: Sprite3D = z["b"]
		if z.has("sitz"):
			# Platz auf der Tribüne: Bildpunkt der Tribüne -> Weltpunkt in ihrer Billboard-Ebene; weiter vorn = näher zur Kamera
			var sitz: Vector2 = z["sitz"]
			var p := _tribuene_ort + achsen.x * ((sitz.x - TRIB_BREITE / 2.0) * ps) + achsen.y * ((TRIB_FUSS - sitz.y) * ps) \
				+ achsen.z * (0.05 + sitz.y * 0.0015)
			b.position = p
			z["ort"] = p
		var bild := Vector2i(1, 0)   # Spalte, Zeile: von vorn
		var flip := false
		var dx := 0.0
		var dy := 0.0
		var sx := 1.0
		var sy := 1.0
		if z["angriff"] >= 0.0:
			z["angriff"] += dt
			var n := int(z["angriff"] * 12.0)
			if n >= 7:
				z["angriff"] = -1.0
			else:
				bild = Vector2i(n, 2)
		if z["angriff"] < 0.0 and z["tanz"] >= 0.0:
			z["tanz"] += dt
			if z["tanz"] > 12.0:
				z["tanz"] = -1.0
			else:
				var schlag: float = z["tanz"] / TAKT
				var bi := int(schlag)
				var f := schlag - bi
				var schritte: Array = z["schritte"]
				var pose := _tanzpose(schritte[(bi / 8) % schritte.size()], f, bi)
				bild = Vector2i((bi * 2 + (1 if f >= 0.5 else 0)) % 4, 1)   # Füße im Takt
				flip = pose.get("flip", false)
				dx = pose.get("dx", 0.0)
				dy = pose.get("dy", 0.0)
				sx = pose.get("sx", 1.0)
				sy = pose.get("sy", 1.0)
		if z["angriff"] < 0.0 and z["tanz"] < 0.0:
			# Ruhe: umschauen und ab und zu jubeln (auf der Stelle trippeln und hüpfen)
			z["naechstes"] -= dt
			if z["naechstes"] <= 0.0:
				z["naechstes"] = _zrng.randf_range(3.0, 9.0)
				if _zrng.randf() < 0.45:
					z["jubel"] = 0.0
				# (kein Umschauen zur Seite mehr: Paul will die Helden immer von vorn sehen)
			if z["jubel"] >= 0.0:
				z["jubel"] += dt
				if z["jubel"] > 1.6:
					z["jubel"] = -1.0
				else:
					bild = Vector2i(int(z["jubel"] * 8.0) % 4, 1)
					dy = -roundf(absf(sin(z["jubel"] * TAU * 1.5)) * 3.0)
			else:
				bild = Vector2i(z["blick"], 0)
		b.region_rect = Rect2(bild.x * Z_ZELLE, bild.y * Z_ZELLE, Z_ZELLE, Z_ZELLE)
		b.flip_h = flip
		b.offset = Vector2(-Z_ZELLE / 2.0 + dx, -1 - dy)
		b.scale = Vector3(sx, sy, 1.0)


## Linksklick auf einen Zuschauer: tanzen (beim Tanzen: Angriffs-Pose). true, wenn einer getroffen wurde.
func _zuschauer_klick(p: Vector2) -> bool:
	var bester: Dictionary = {}
	var abst := 30.0
	for z: Dictionary in _zuschauer:
		var mitte: Vector3 = (z["ort"] as Vector3) + Vector3(0, 0.45, 0)
		if kamera.is_position_behind(mitte):
			continue
		var d := kamera.unproject_position(mitte).distance_to(p)
		if d < abst:
			abst = d
			bester = z
	if bester.is_empty():
		return false
	if bester["tanz"] >= 0.0:
		bester["angriff"] = 0.0
	else:
		bester["tanz"] = 0.0
		bester["jubel"] = -1.0
		spiel.melde("%s tanzt!" % bester["name"], 2.0)
	return true

## Setzt die Kulissenstücke (Bilder aus assets/neu/kulisse) und gibt ihre Plätze zurück: Vector3(x, freier Radius, z).
## Lotman-Grenze: links Chaos (Brut), rechts Ordnung (Technoclan), dazwischen das umkämpfte Spielfeld.
var _plan: Array = []     # geplante Kulissenstücke (siehe _plane_stuecke)
var _ebenen: Array = []   # [x, z, Radius, Höhe]: ebener Grund unter großen Stücken

## Plant die Kulissenstücke: [Bild, x, z, Maßstab, Fußzeile im Bild, freier Radius]. Große Bauten bekommen ebenen Grund.
func _plane_stuecke(r: RandomNumberGenerator) -> Array:
	var sw := float(Werte.SPALTEN)
	var zh := float(Werte.ZEILEN)
	var liste := [
		# Myriaden sind Maschinen: kupferne Schwarmbauten und Drohnenkapseln statt organischer Brut
		["schwarmbau", -2.6, zh * 0.22, 2.0, 114, 1.6], ["schwarmbau", 0.2, zh * 0.74 + 4.0, 2.3, 114, 1.8],
		["schwarmbau", 0.6, -2.6, 1.8, 114, 1.5], ["schwarmbau", -1.8, zh + 2.2, 1.6, 114, 1.4],
		["kapseln", -1.4, zh * 0.48, 1.5, 62, 1.0], ["kapseln", -2.2, zh + 0.9, 1.3, 62, 1.0], ["kapseln", -1.0, -1.3, 1.3, 62, 1.0],
		["kapseln", -3.0, zh * 0.4, 1.5, 62, 1.0],
		["depot_kaputt", sw + 2.6, zh * 0.3, 2.0, 111, 2.2], ["depot_kaputt", sw - 2.5, -2.4, 1.8, 111, 2.0],   # zerstört: spielt keine Rolle
		["mast", sw + 1.9, zh * 0.78, 2.0, 98, 1.0], ["mast", sw + 4.4, zh * 0.08, 2.2, 98, 1.0],
		["wrack", sw * 0.46, -2.4, 2.0, 114, 1.8], ["wrack", sw + 2.4, zh + 2.2, 1.6, 114, 1.4],
	]
	# Felsen an der Vorder- und Hinterkante: so sieht man den Rand des Spielfelds
	var x := 4.0
	while x < sw - 1.0:
		liste.append(["felsen", x + r.randf_range(-0.8, 0.8), zh + r.randf_range(0.35, 0.6), r.randf_range(1.1, 1.5), 59, 0.9])
		x += r.randf_range(3.0, 4.5)
	x = 4.5
	while x < sw - 1.0:
		liste.append(["felsen", x + r.randf_range(-0.8, 0.8), -r.randf_range(0.7, 1.1), r.randf_range(1.2, 1.6), 59, 0.9])
		x += r.randf_range(3.5, 5.0)
	# Holztribüne für die Helden (16.11.): oben am Hang, auf eingeebnetem Grund
	liste.append(["tribuene", sw * TRIB_X, TRIB_Z, TRIB_MASSSTAB, TRIB_FUSS, 2.4])
	_ebenen.clear()
	for e: Array in liste:
		if e[0] in ["schwarmbau", "depot_kaputt", "wrack", "tribuene"]:
			_ebenen.append([e[1], e[2], float(e[5]) * 0.75, _gelaende_roh(e[1], e[2])])
	return liste


func _kulissenstuecke(r: RandomNumberGenerator) -> Array:
	var plaetze: Array = []
	var sw := float(Werte.SPALTEN)
	for e: Array in _plan:
		var tex: Texture2D = karte.neu_bild("kulisse/%s.png" % e[0])
		var b := _neues_bild()
		b.texture = tex
		var g := tex.get_size()
		b.region_rect = Rect2(Vector2.ZERO, g)
		b.pixel_size = float(e[3]) / Werte.ZELLE
		b.offset = Vector2(-g.x / 2.0, -(g.y - float(e[4])))
		b.flip_h = e[0] != "tribuene" and r.randf() < 0.5 and e[0] != "depot_kaputt" and e[0] != "mast"
		var dunkel := clampf(1.0 - _abseits(e[1], e[2]) * 0.03, 0.75, 1.0)
		b.modulate = Color(dunkel, dunkel, dunkel)
		b.position = Vector3(e[1], gelaende_hoehe(e[1], e[2]), e[2])
		if e[0] == "tribuene":
			_tribuene_ort = b.position
		plaetze.append(Vector3(e[1], e[5], e[2]))
	# Gebirge ganz hinten: breites Bild, mehrfach nebeneinander, steht auf dem Hang (immer aufrecht zur Kamera)
	var berge: Texture2D = karte.neu_bild("kulisse/berge.png")
	var bx := -14.0
	var i := 0
	while bx < sw + 14.0:
		var b := _neues_bild()
		b.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		b.texture = berge
		b.region_rect = Rect2(0, 0, 256, 128)
		b.pixel_size = 0.075
		b.offset = Vector2(-128, -(128 - 116))
		b.flip_h = i % 2 == 1
		b.modulate = Color(0.82, 0.86, 0.92)
		b.position = Vector3(bx + 9.0, gelaende_hoehe(bx + 9.0, -13.5) - 0.6, -13.5 - (i % 2) * 1.5)
		bx += 15.5
		i += 1
	return plaetze

## Höhe des Geländes (in Feldern) an x, z: auf dem Spielfeld 0. Hinten steigt ein Hang an, an den Seiten Hügel,
## vorn direkt am Rand eine niedrige Böschung – so sieht man, wo das Spielfeld endet, ohne Plattform-Kante.
func gelaende_hoehe(x: float, z: float) -> float:
	var roh := _gelaende_roh(x, z)
	for e: Array in _ebenen:
		var a := Vector2(x - e[0], z - e[1]).length()
		if a < e[2] * 1.6:
			roh = lerpf(e[3], roh, smoothstep(e[2], e[2] * 1.6, a))
	return roh


func _gelaende_roh(x: float, z: float) -> float:
	var d := _abseits(x, z)
	if d <= 0.0:
		return -0.004
	if _hoehen_rauschen == null:
		_hoehen_rauschen = FastNoiseLite.new()
		_hoehen_rauschen.seed = 321
		_hoehen_rauschen.frequency = 0.09
		_hoehen_rauschen.fractal_octaves = 3
	var sw := float(Werte.SPALTEN)
	var zh := float(Werte.ZEILEN)
	var n := _hoehen_rauschen.get_noise_2d(x, z)
	var h := 0.0
	if z < 0.0:
		h += smoothstep(0.5, 7.5, -z) * (3.4 + n * 1.8)
	var dx := maxf(-x, x - sw)
	if dx > 0.0:
		h += smoothstep(0.8, 9.0, dx) * (2.0 + n * 1.2)
	if z > zh:
		# vorn: das Spielfeld endet an einer kleinen Kante, dahinter fällt eine Erdböschung zu einer tieferen Wiese ab
		var v := z - zh
		h += 0.1 * exp(-pow((v - 0.4) / 0.25, 2.0))
		h -= smoothstep(0.5, 2.3 + n * 0.4, v) * (1.1 + n * 0.3)
	h += n * 0.2 * smoothstep(1.0, 4.0, d)
	if z <= zh:
		h = maxf(h, 0.0)
	return h * smoothstep(0.05, 0.6, d) - 0.004


## Geländenetz über das gemalte Umland: Raster aus halben Feldern, Licht als Eckenfarbe (eben = 1, damit es nahtlos
## an das unbeleuchtete Spielfeld anschließt).
func _gelaende_netz() -> ArrayMesh:
	var m := float(UMLAND)
	var sw := float(Werte.SPALTEN)
	var zh := float(Werte.ZEILEN)
	var schritt := 0.5
	var nx := int((sw + 2.0 * m) / schritt)
	var nz := int((zh + 2.0 * m) / schritt)
	var licht := Vector3(-6, 14, -3).normalized()   # Hänge zur Kamera hin liegen etwas im Schatten: die Böschung vorn hebt sich ab
	var eben := Vector3.UP.dot(licht)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var punkte := []
	for j in nz + 1:
		var reihe := []
		for i in nx + 1:
			var x := -m + i * schritt
			var z := -m + j * schritt
			var y := gelaende_hoehe(x, z)
			var nrm := Vector3(gelaende_hoehe(x - 0.25, z) - gelaende_hoehe(x + 0.25, z), 0.5,
				gelaende_hoehe(x, z - 0.25) - gelaende_hoehe(x, z + 0.25)).normalized()
			var k := clampf(1.0 + 0.6 * (nrm.dot(licht) - eben), 0.55, 1.2)
			reihe.append([Vector3(x, y, z), Vector2(i / float(nx), j / float(nz)), Color(k, k, k)])
		punkte.append(reihe)
	for j in nz:
		for i in nx:
			for e: Array in [punkte[j][i], punkte[j][i + 1], punkte[j + 1][i + 1], punkte[j][i], punkte[j + 1][i + 1], punkte[j + 1][i]]:
				st.set_color(e[2])
				st.set_uv(e[1])
				st.add_vertex(e[0])
	return st.commit()


## Abstand (in Feldern) eines Punkts vom Spielfeldrand; 0 innerhalb.
func _abseits(x: float, z: float) -> float:
	var dx := maxf(0.0, maxf(-x, x - Werte.SPALTEN))
	var dz := maxf(0.0, maxf(-z, z - Werte.ZEILEN))
	return sqrt(dx * dx + dz * dz)


## Malt das Umland als ein Bild (32 Bildpunkte je Feld wie die Grasfliesen): Gras, Erde- und Felsflecken, Brut-Gelände links,
## Bewuchs und zum Rand hin abgedunkelt. Die Flecken auf dem Gras laufen nahtlos aus der Karte weiter (gleiches Rauschen).
func _umland_bild() -> Image:
	var m := UMLAND
	var zw := Werte.SPALTEN + 2 * m
	var zh := Werte.ZEILEN + 2 * m
	var bw := zw * 32
	var bh := zh * 32
	var blatt: Image = karte.neu_bild("terrain/SHEET2.png").get_image()
	blatt.convert(Image.FORMAT_RGBA8)
	var fels: Image = karte.neu_bild("terrain/SHEET3.png").get_image()
	fels.convert(Image.FORMAT_RGBA8)
	var gras := Image.create(bw, bh, false, Image.FORMAT_RGBA8)
	var erde := Image.create(bw, bh, false, Image.FORMAT_RGBA8)
	var trocken := Image.create(bw, bh, false, Image.FORMAT_RGBA8)
	var brut := Image.create(bw, bh, false, Image.FORMAT_RGBA8)
	for cy in zh:
		for cx in zw:
			var h := hash(Vector2i(cx, cy) * 7 + Vector2i(1, 5))
			var o := Vector2i(cx * 32, cy * 32)
			gras.blit_rect(blatt, Rect2i([0, 0, 0, 1][h % 4] * 32, 0, 32, 32), o)
			erde.blit_rect(blatt, Rect2i([9, 9, 10][(h >> 3) % 3] * 32, 0, 32, 32), o)
			trocken.blit_rect(blatt, Rect2i([2, 2, 3][(h >> 6) % 3] * 32, 0, 32, 32), o)
			brut.blit_rect(fels, Rect2i(Karte.MYR_KACHELN[(h >> 5) % 2] * 32, 0, 32, 32), o)
	# Masken in Blöcken zu 4 Bildpunkten, geordnet gerastert
	const BAYER := [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]
	var mw := bw / 4
	var mh := bh / 4
	var m_erde := Image.create(mw, mh, false, Image.FORMAT_RGBA8)
	var m_trocken := Image.create(mw, mh, false, Image.FORMAT_RGBA8)
	var m_brut := Image.create(mw, mh, false, Image.FORMAT_RGBA8)
	var schatten := Image.create(mw, mh, false, Image.FORMAT_RGBA8)
	var n1 := FastNoiseLite.new()
	n1.seed = 99
	n1.frequency = 0.035
	n1.fractal_octaves = 3
	var n2 := FastNoiseLite.new()
	n2.seed = 7
	n2.frequency = 0.06
	var voll := Color(1, 1, 1, 1)
	for by in mh:
		for bx in mw:
			var fx := (bx + 0.5) / 8.0 - m   # Blockmitte in Feldern
			var fy := (by + 0.5) / 8.0 - m
			var d := _abseits(fx, fy)
			if d <= 0.0:
				continue
			var t: float = int(BAYER[(by % 4) * 4 + bx % 4]) / 16.0 - 0.47
			var v: float = n1.get_noise_2d(bx, by) * 0.5 + 0.5 + t * 0.12
			var w := v + minf(d, 12.0) * 0.022
			if d > 1.0 and w > 0.58:
				m_trocken.set_pixel(bx, by, voll)   # trockenes Gras als Übergang zur Erde
			if d > 1.6 and w > 0.7:
				m_erde.set_pixel(bx, by, voll)
			# Brut-Gelände: links von der Zonengrenze, mit ausgefranster Kante
			# Myr-Boden: links von der Zonengrenze, läuft nach etwa 4 Feldern aus
			var rn := n2.get_noise_2d(bx, by) * 1.6 + t * 0.4
			if fx + rn < float(Werte.ZONE_SPALTEN) and fx - rn * 0.8 > -4.5 and fy > -3.0 + rn and fy < Werte.ZEILEN + 3.0 + rn:
				m_brut.set_pixel(bx, by, voll)
			# vorn: Erdböschung, wo das Gelände abfällt
			if fy > Werte.ZEILEN + 0.45 + t * 0.3 and fy < Werte.ZEILEN + 2.4 + n2.get_noise_2d(bx, by) * 0.5:
				m_erde.set_pixel(bx, by, voll)
			# nach außen dunkler (in Stufen, gerastert)
			var a := clampf((d - 1.5) / 11.0, 0.0, 1.0) * 0.6 + t * 0.06
			if a > 0.0:
				schatten.set_pixel(bx, by, Color(0.02, 0.04, 0.05, snappedf(a, 0.06)))
	m_erde.resize(bw, bh, Image.INTERPOLATE_NEAREST)
	m_trocken.resize(bw, bh, Image.INTERPOLATE_NEAREST)
	m_brut.resize(bw, bh, Image.INTERPOLATE_NEAREST)
	var bild := gras
	var ganz := Rect2i(0, 0, bw, bh)
	bild.blit_rect_mask(trocken, m_trocken, ganz, Vector2i.ZERO)
	bild.blit_rect_mask(erde, m_erde, ganz, Vector2i.ZERO)
	# Flecken wie auf der Karte (gleiches Rauschen, Karten-Koordinaten): nah fein, weiter draußen gröber
	var fein := Image.create(bw / 2, bh / 2, false, Image.FORMAT_RGBA8)
	for py in bh / 2:
		for px in bw / 2:
			var fx := (px + 0.5) / 16.0 - m
			var fy := (py + 0.5) / 16.0 - m
			var d := _abseits(fx, fy)
			if d <= 0.0 or d > 3.0:
				continue
			fein.set_pixel(px, py, karte.flecken_farbe(px - m * 16, py - m * 16))
	var grob := Image.create(mw, mh, false, Image.FORMAT_RGBA8)
	for by in mh:
		for bx in mw:
			if _abseits((bx + 0.5) / 8.0 - m, (by + 0.5) / 8.0 - m) <= 3.0:
				continue
			grob.set_pixel(bx, by, karte.flecken_farbe(bx * 2 - m * 16, by * 2 - m * 16))
	fein.resize(bw, bh, Image.INTERPOLATE_NEAREST)
	grob.resize(bw, bh, Image.INTERPOLATE_NEAREST)
	bild.blend_rect(fein, ganz, Vector2i.ZERO)
	bild.blend_rect(grob, ganz, Vector2i.ZERO)
	# Brut-Gelände drüber, mit demselben Lila-Schleier wie die Zone auf der Karte
	var schleier := Image.create(bw, bh, false, Image.FORMAT_RGBA8)
	schleier.fill(Karte.MYR_SCHLEIER)
	bild.blit_rect_mask(brut, m_brut, ganz, Vector2i.ZERO)
	bild.blend_rect_mask(schleier, m_brut, ganz, Vector2i.ZERO)
	# Bewuchs: Gräser, Blumen, Steine und Büsche aus dem TC-Blatt, nur auf Gras
	var r := RandomNumberGenerator.new()
	r.seed = 1234
	var deko := [0, 1, 6, 2, 3, 35, 61, 4, 20, 0, 1, 6]
	for i in zw * zh / 2:
		var cx := r.randi_range(0, zw - 1)
		var cy := r.randi_range(0, zh - 1)
		var d := _abseits(cx + 0.5 - m, cy + 0.5 - m)
		if d < 0.7:
			continue
		var px := cx * 32 + r.randi_range(0, 16)
		var py := cy * 32 + r.randi_range(0, 16)
		if m_erde.get_pixel(px + 8, py + 8).a > 0.0 or m_brut.get_pixel(px + 8, py + 8).a > 0.0:
			continue
		var k: int = deko[r.randi() % deko.size()]
		bild.blend_rect(blatt, Rect2i((k % 32) * 32, 96 + (k / 32) * 32, 32, 32), Vector2i(px, py))
	schatten.resize(bw, bh, Image.INTERPOLATE_NEAREST)
	bild.blend_rect(schatten, ganz, Vector2i.ZERO)
	return bild


# ------------------------------------------------------------------ Kamera (wie Terrain-Conquester)

func _abstand(z: float) -> float:
	return lerpf(78.0, 9.0, z * z * 0.35 + z * 0.65)


func _neigung(z: float) -> float:
	return deg_to_rad(lerpf(64.0, 34.0, z))


## Draufsicht [V] (16.11.): die Kamera kippt fast senkrecht nach unten; Zoom und Schwenken bleiben.
## Auch über den Knopf am Zoomregler und Esc → Einstellungen (Oberfläche, 16.11.).
func draufsicht_umschalten() -> void:
	_tdrauf = 1.0 - _tdrauf
	spiel.melde("Draufsicht" if _tdrauf > 0.5 else "Schräge Ansicht", 1.5)


func ist_draufsicht() -> bool:
	return _tdrauf > 0.5

var _drauf := 0.0
var _tdrauf := 0.0

func _neigung_jetzt() -> float:
	return lerpf(_neigung(_z), deg_to_rad(88.0), _drauf)


func _sichtwinkel(z: float) -> float:
	return lerpf(34.0, 46.0, z)


## Zoom, bei dem die ganze Karte gerade ins Bild passt.
func _passend_z() -> float:
	var groesse := get_viewport().get_visible_rect().size
	var z := 0.0
	while z <= 1.0:
		var vh := 2.0 * tan(deg_to_rad(_sichtwinkel(z)) / 2.0) * _abstand(z)
		var vw := vh * groesse.x / groesse.y
		if vw < Werte.SPALTEN + 1.5 or vh * 0.8 < Werte.ZEILEN + 2.0:
			return maxf(0.0, z - 0.01)
		z += 0.01
	return 0.0


## Bildpunkte je Sprite-Pixel beim Zoom z.
func _pixelstufe(z: float) -> float:
	var hoehe := get_viewport().get_visible_rect().size.y
	return hoehe / (2.0 * tan(deg_to_rad(_sichtwinkel(z)) / 2.0) * _abstand(z)) / 32.0


## Einrasten: der nächste Zoom, bei dem ein Sprite-Pixel ganzzahlig viele Bildpunkte groß ist.
func _eingerastet(z: float) -> float:
	var bester := z
	var abst := INF
	for k in range(1, 13):
		var a := 0.0
		var b := 1.0
		if _pixelstufe(a) > k or _pixelstufe(b) < k:
			continue
		for i in 30:
			var m := (a + b) / 2.0
			if _pixelstufe(m) < k:
				a = m
			else:
				b = m
		var zk := (a + b) / 2.0
		if zk >= _z_min and absf(zk - z) < abst:
			abst = absf(zk - z)
			bester = zk
	return bester if abst < 0.12 else z


## Zoom-Regler: 0 = ganze Karte, 1 = ganz nah.
func zoom_anteil() -> float:
	return clampf((_tz - _z_min) / maxf(0.001, 1.0 - _z_min), 0.0, 1.0)


func setze_zoom_anteil(a: float) -> void:
	_tz = lerpf(_z_min, 1.0, a)   # kein Einrasten: der Zoom bleibt, wo der Regler steht


func _kamera_weiter(dt: float) -> void:
	var schwenk := Vector2.ZERO
	if spiel.wasd_kamera():
		# A/D/W/S schwenken, solange Brakk nicht angeklickt ist (dann steuern sie ihn)
		if Input.is_physical_key_pressed(KEY_A):
			schwenk.x -= 1.0
		if Input.is_physical_key_pressed(KEY_D):
			schwenk.x += 1.0
		if Input.is_physical_key_pressed(KEY_W):
			schwenk.y -= 1.0
		if Input.is_physical_key_pressed(KEY_S):
			schwenk.y += 1.0
	if Input.is_key_pressed(KEY_LEFT):
		schwenk.x -= 1.0
	if Input.is_key_pressed(KEY_RIGHT):
		schwenk.x += 1.0
	if Input.is_key_pressed(KEY_UP):
		schwenk.y -= 1.0
	if Input.is_key_pressed(KEY_DOWN):
		schwenk.y += 1.0
	if schwenk != Vector2.ZERO:
		schwenk = schwenk.limit_length(1.0)
		var tempo := _abstand(_z) * 0.6
		_tcx += schwenk.x * tempo * dt
		_tcz += schwenk.y * tempo * dt
	if _einrast_in > 0.0:
		_einrast_in -= dt
		if _einrast_in <= 0.0:
			_tz = _eingerastet(_tz)
	_tcx = clampf(_tcx, 0.0, float(Werte.SPALTEN))   # Blick bleibt über dem Spielfeld: ringsum ist immer Landschaft im Bild
	_tcz = clampf(_tcz, 0.0, Werte.ZEILEN + 1.0)
	var k := minf(1.0, dt * 6.0)
	_z += (_tz - _z) * k
	_cx += (_tcx - _cx) * k
	_cz += (_tcz - _cz) * k
	_drauf += (_tdrauf - _drauf) * k
	_kamera_setzen()


func _kamera_setzen() -> void:
	var neigung := _neigung_jetzt()
	var abstand := _abstand(_z)
	kamera.fov = _sichtwinkel(_z)
	kamera.position = Vector3(_cx, sin(neigung) * abstand, _cz + cos(neigung) * abstand)
	kamera.look_at(Vector3(_cx, 0.0, _cz), Vector3.UP)
	# Erschütterung bei Einschlägen (effekte.wackeln, in Bildpunkten der Karte)
	var w: float = spiel.effekte.wackeln if is_instance_valid(spiel) else 0.0
	if w > 0.0:
		kamera.position += Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0) * 0.5, 0.0) * w / Werte.ZELLE


var _links_start := Vector2.INF   # Linksklick: Startpunkt, um Ziehen (Schwenken) von einem Klick zu unterscheiden
var _links_zieht := false


func _schwenke(relativ: Vector2) -> void:
	var hoehe := get_viewport().get_visible_rect().size.y
	var pro_punkt := 2.0 * tan(deg_to_rad(_sichtwinkel(_z)) / 2.0) * _abstand(_z) / hoehe
	_tcx -= relativ.x * pro_punkt
	_tcz -= relativ.y * pro_punkt / sin(_neigung_jetzt())


func _unhandled_input(event: InputEvent) -> void:
	if ego != null:
		return   # Ego-Sicht: Maus und Tasten gehören ihr
	# Linke Maustaste ziehen schwenkt wie in der Stilprobe – aber nur ohne Bauwerkzeug und ohne Zuweisungspfeil
	# (Wälle malen und Stellungen zuweisen bleiben so wie bisher). Ein Klick ohne Ziehen geht ganz normal ans Spiel.
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and _zuschauer_klick((event as InputEventMouseButton).position):
			get_viewport().set_input_as_handled()
			return
		if event.pressed:
			_links_start = (event as InputEventMouseButton).position
			_links_zieht = false
		else:
			_links_start = Vector2.INF
			if _links_zieht:
				_links_zieht = false
				get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseMotion and (event as InputEventMouseMotion).button_mask & MOUSE_BUTTON_MASK_LEFT and _links_start != Vector2.INF:
		var frei: bool = spiel.werkzeug == Karte.FREI and spiel._zieh_von == Karte.KEINE
		if frei and not _links_zieht and (event as InputEventMouseMotion).position.distance_to(_links_start) > 6.0:
			_links_zieht = true
		if _links_zieht:
			_schwenke((event as InputEventMouseMotion).relative)
			get_viewport().set_input_as_handled()
			return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and (mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN):
			var richtung := 1.0 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else -1.0
			# 16.11. (Paul): weniger empfindlich – feine Räder/Touchpads schicken viele kleine Schritte (factor < 1),
			# und je Bild zählt höchstens ein Rastschritt, damit ein leichtes Drehen nicht gleich ganz hineinzoomt.
			var schritt := 0.035 * clampf(mb.factor if mb.factor > 0.0 else 1.0, 0.15, 1.0)
			var frame := Engine.get_process_frames()
			if frame != _rad_bild:
				_rad_bild = frame
				_rad_summe = 0.0
			schritt = minf(schritt, 0.035 - _rad_summe)
			if schritt > 0.0:
				_rad_summe += schritt
				_tz = clampf(_tz + richtung * schritt, _z_min, 1.0)
			pass   # kein Einrasten auf Pixelstufen mehr (wirkte wie ein Autozoom)
			get_viewport().set_input_as_handled()
		elif mb.button_index == MOUSE_BUTTON_MIDDLE:
			_zieht = mb.pressed
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _zieht:
		_schwenke((event as InputEventMouseMotion).relative)
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).keycode == KEY_M:
		var folge := {"tech": "energie", "energie": "block", "block": "tech"}
		Werte.wand_stil = str(folge.get(Werte.wand_stil, "tech"))
		Werte.speichere_einstellungen()
		spiel.melde("Mauern: " + {"tech": "Tech-Mauer", "energie": "Energiewand", "block": "Blöcke"}[Werte.wand_stil], 2.0)
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).keycode == KEY_U:
		umriss_an = not umriss_an
		spiel.melde("Umrisse hinter Wällen: " + ("an" if umriss_an else "aus"), 1.5)
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).keycode == KEY_V:
		draufsicht_umschalten()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).keycode == KEY_HOME:
		_tz = _passend_z()
		_tcx = Werte.SPALTEN / 2.0
		_tcz = Werte.ZEILEN / 2.0
		get_viewport().set_input_as_handled()


# ------------------------------------------------------------------ Maus und Bildschirm

## Mausposition als Weltpunkt der 2D-Logik. Zuerst die Höhe der Mauerkronen (Klick auf einen Wall trifft ihn),
## sonst der Boden.
func maus_welt(nur_boden: bool = false) -> Vector2:
	if ego != null:
		return ego.ziel_welt(nur_boden)   # Ego-Sicht: der Punkt unter dem Fadenkreuz
	var mp := get_viewport().get_mouse_position()
	var von := kamera.project_ray_origin(mp)
	var r := kamera.project_ray_normal(mp)
	if absf(r.y) < 0.0001:
		return Vector2(-9999, -9999)
	var p := von + r * ((H - von.y) / r.y)
	if not nur_boden and ist_hoch(Vector2i(floori(p.x), floori(p.z))):
		return Vector2(p.x * Werte.ZELLE, p.z * Werte.ZELLE + Werte.KARTE_OBEN)
	p = von + r * ((0.0 - von.y) / r.y)
	return Vector2(p.x * Werte.ZELLE, p.z * Werte.ZELLE + Werte.KARTE_OBEN)


## Fabrik, Batterie oder Generator, deren Bild unter der Maus liegt – auch wenn eine Mauer davor steht (16.11.).
## Liefert Karte.KEINE, wenn keins getroffen ist; bei mehreren das, dessen Fuß der Maus am nächsten ist.
func bau_unter_maus() -> Vector2i:
	if ego != null:
		return Karte.KEINE
	var mp := get_viewport().get_mouse_position()
	var bester := Karte.KEINE
	var naechst := INF
	for z: Vector2i in _bauten:
		if not karte.feld.has(z):
			continue
		var m := karte.mitte(z)
		var fuss := kamera.unproject_position(_welt_3d(m + Vector2(0, 26), 0.0))
		var kopf := kamera.unproject_position(_welt_3d(m + Vector2(0, 26), 1.3))
		var links := kamera.unproject_position(_welt_3d(m + Vector2(-Werte.ZELLE * 0.5, 26), 0.0))
		var halb := absf(fuss.x - links.x)
		var r := Rect2(Vector2(fuss.x - halb, minf(kopf.y, fuss.y)), Vector2(halb * 2.0, absf(fuss.y - kopf.y)))
		if r.has_point(mp):
			var d := mp.distance_to(fuss)
			if d < naechst:
				naechst = d
				bester = z
	return bester


## Weltpunkt der 2D-Logik -> Bildschirmpunkt (für Menüs und Hinweise an Feldern).
func welt_zu_bild(p: Vector2) -> Vector2:
	var z := karte.zelle_bei(p)
	return kamera.unproject_position(_welt_3d(p, H if ist_hoch(z) else 0.0))
