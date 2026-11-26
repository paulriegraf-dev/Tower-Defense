class_name MenueBuehne
extends Node3D
## Bühne des Startmenüs (26.11., Paul). Zwei Szenen, umschaltbar (`szene`, vor add_child setzen; startmenue.gd: F3):
## „ausblick“: Vorn links ragt der Erdwall als Plattform ins Bild, darauf Brakk und die drei Technoclan-Truppen mit Blick
## ins Tal. Im Tal spielt sich eine kleine Partie selbst, winzig und ruhig: Weit hinten das Myriaden-HQ (Kupferlichter,
## Rauch), von dort ein gewundener Pfad zu einer kleinen Verteidigung (Erdwälle mit Stellungen, ein Formturm). Alle 8–15 s
## läuft eine einzelne Myriade los und fällt an der Verteidigung. Dahinter Berge, darüber Himmel mit zwei Wolkenschichten.
## „klippe“ (Bildaufbau nach Pauls Vorlage, eigene Bilder): Unten links eine hohe Felsklippe mit Erdwall-Krone, darauf
## Brakk und die Truppen; ein Baum ragt ins Bild, Blätter wehen. Die Klippe fällt steil ins dunstige Tal ab (Lichtstrahlen).
## Oben rechts, weit weg auf einer Anhöhe, eine größere Verteidigung (fünf Wälle, zwei Formtürme) gegen Myriaden-Trupps.
## Bild: Tiefenschärfe – die Klippe scharf, das Tal weich, die Verteidigung nur leicht weich.
## Partikel: Blätter, Funken, Rauch. Alle 6–10 s eine kleine Bewegung auf der Plattform (Brakk blickt herüber, eine Truppe
## wechselt den Stand).
## Zustände: `nacht_ziel` 0 = Abend, 1 = Nacht (Phantom-Menü: dunkelblau, Leuchtstreifen, Mündungsfeuer, Sterne);
## `unter_ziel` 1 = eine Unterseite ist offen (Tusche-Ton, Kamera rückt vor, weicher); `arm_ziel` 1 = Brakk hebt den
## linken Arm (Hologramm-Tafeln, startmenue.gd), `hand_leuchten` 0..1 = sein Handschuh leuchtet, `hand_bildpunkt()` sagt,
## wo die Handfläche im Bild ist; `blick()` = er dreht kurz den Kopf zur Liste (Markieren eines Punkts).
## Der Hintergrund ist eine gemalte Szene, kein Spielfeld: Boden ohne Kachelraster, frei gesetzte Hügel, Wälle als
## Silhouetten, Figuren als kleine Sprites.
## ALLE BILDER aus assets/neu/menue/szene/ (feste Namen, siehe LIESMICH.txt dort) – am 30.11. austauschbar. Größen in der
## Szene hängen nicht an den Pixeln der Bilder.
## Gezeigt wird die Bühne von startmenue.gd in einem eigenen SubViewport; `post` ist das Material für dieses Bild
## (Tilt-Shift bzw. Tiefenschärfe, Tusche, Abdunkeln, Vignette). `einfach` (Handy/Tablet): weniger Partikel, ohne
## Weichzeichnen.

const S := "res://assets/neu/menue/szene/"
const KAM_POS := Vector3(-2.6, 4.4, 15.5)
const KAM_BLICK := Vector3(9.0, 0.6, -6.0)
const KAM_FOV := 52.0
const VORRUECKEN := 1.2          # so weit fährt die Kamera bei einer Unterseite vor
const BODEN_Y := -2.4            # Talboden
## Hintergrundspiel: Orte als Bildanteile (x, y des 16:9-Bilds) – im freien Band links unter dem Logo, zwischen den
## Bergen und der Plattform; die Figuren (Bildmitte) und die Liste (ab x ≈ 0,64) bleiben frei.
const HQ_SCHIRM := Vector2(0.15, 0.392)
const PFAD_SCHIRM := [Vector2(0.15, 0.398), Vector2(0.29, 0.405), Vector2(0.1, 0.418), Vector2(0.3, 0.432)]
const VT_SCHIRM := Vector2(0.36, 0.44)
const BERGE_SCHIRM := Vector2(0.5, 0.378)
const GEGNER := [["gegner_hund", 1.3], ["gegner_schild", 1.45], ["gegner_fahne", 1.6]]   # [Bild, Höhe]
const GEGNER_TEMPO := 1.1        # Felder je Sekunde (weit weg – auf dem Schirm langsam)
const SCHUSS_WEITE := 9.0
const VT_GROESSE := 1.8          # Maßstab der kleinen Verteidigung (sie steht weit hinten)
## Brakk (brakk.png): Bilder 0–8 Ruhe, 9–10 Arm heben, 11 Arm oben (Handfläche, Handschuh), 12 Kopf zur Liste.
const BRAKK_HEBEN := [9, 10, 11]
const BRAKK_BLICK := 12
const ARM_SEK := 0.15            # so lange hebt bzw. senkt Brakk den Arm
const HUEGEL := [[0.04, 0.392, 9.0, 3.0], [0.22, 0.388, 12.0, 4.0], [0.4, 0.398, 7.0, 2.2], [0.55, 0.39, 11.0, 3.2],
	[0.47, 0.42, 5.0, 1.4], [0.0, 0.452, 6.0, 1.8], [0.62, 0.405, 8.0, 2.4]]   # [Bild-x, Bild-y, Radius, Höhe]
## Szene „klippe“: Kamera höher und steiler, Talboden tief unten, die Verteidigung auf einer Anhöhe (Höhe KL_SPIEL_Y).
const KL_KAM_POS := Vector3(0.0, 8.0, 16.0)
const KL_KAM_BLICK := Vector3(7.0, 2.6, -4.0)
const KL_BODEN_Y := -16.0
const KL_OBEN := 2.4             # Krone der Klippe (Füße der Figuren)
const KL_SPIEL_Y := 4.5          # Anhöhe der Verteidigung
const KL_BRAKK := Vector2(0.24, 0.63)
const KL_VT := Vector2(0.68, 0.293)
## HQ und Pfad relativ zur Verteidigung (Welt x, z); die Höhe kommt von der Anhöhe (das HQ steht oben, der Pfad führt
## hinab zur Verteidigung).
const KL_HQ := Vector2(46.0, -22.0)    # rechts hinter der Verteidigung
const KL_PFAD := [Vector2(43.0, -20.0), Vector2(32.0, -27.0), Vector2(20.0, -18.0), Vector2(10.0, -22.0), Vector2(6.0, -14.0),
	Vector2(2.6, -7.5)]
## Anhöhe: Tafelberge mit flacher Kuppe und steilen Hängen [Mitte x, z relativ zur Verteidigung, Radius x, Radius z der
## Kuppe, Höhe der Kuppe]; der erste trägt die Verteidigung (Höhe KL_SPIEL_Y), der zweite steht höher dahinter.
const KL_ANHOEHE := [[14.0, -22.0, 40.0, 30.0, KL_SPIEL_Y], [66.0, -52.0, 42.0, 30.0, 10.0]]
const KL_HANG := 1.3             # Fußradius ÷ Kuppenradius
const KL_VT_GROESSE := 2.9
## Felsblöcke relativ zu Brakks Fuß: [x0, x1, z0, z1, y0, y1] (y absolut); Fels wird zerklüftet (FELS_SHADER)
const KL_FELS := [[-16.0, 1.4, -6.0, 2.0, -20.0, 1.6], [-16.0, -2.5, -9.0, -2.5, -20.0, 4.6],
	[1.4, 3.0, -3.5, 0.6, -20.0, 0.2], [-1.0, 2.2, 2.0, 3.6, -20.0, -2.2], [-6.0, -2.0, 2.0, 4.2, -20.0, -4.5]]
const KL_HUEGEL := [[0.36, 0.42, 14.0, 5.0], [0.5, 0.4, 18.0, 6.0], [0.3, 0.5, 10.0, 3.0], [0.62, 0.45, 16.0, 5.0],
	[0.45, 0.55, 9.0, 2.5], [0.75, 0.6, 14.0, 4.0]]

var szene := "ausblick"
var nacht_ziel := 0.0
var unter_ziel := 0.0
var arm_ziel := 0.0
var hand_leuchten := 0.0
var einfach := false
var post: ShaderMaterial

var kamera: Camera3D
var _kam_pos := KAM_POS
var _kam_blick := KAM_BLICK
var _boden_y := BODEN_Y
var _spiel_y := BODEN_Y      # Höhe, auf der das Hintergrundspiel steht
var _mass := 1.0             # Maßstab des Hintergrundspiels (Verteidigung, Myriaden)
var _trupp := Vector2i(1, 1)  # Myriaden je Trupp (von, bis)
var _takt := Vector2(8.0, 15.0)
var _nacht := 0.0
var _unter := 0.0
var _zeit := 0.0
var _env: Environment
var _sonne: DirectionalLight3D
var _himmel: ShaderMaterial
var _st := {}
var _figuren: Array = []    # {b, bilder, fuss, phase, flip, regung, art}
var _lichter: Array = []    # [Material, Phase] blinkende Kupferlichter
var _lampen: Array = []     # OmniLight3D, die nachts angehen
var _front_mat: StandardMaterial3D
var _fels_mat: ShaderMaterial
var _strahlen: Array = []   # StandardMaterial3D der Lichtstrahlen (nur Klippe)
var _anh: Array = []        # Kuppen der Anhöhe (nur Klippe): [Mitte, Radien]
var _bilder := {}
var _regung_in := 3.0
var _hand: Vector3
var _hand_licht: OmniLight3D
var _hand_mat: StandardMaterial3D
var _hand_kugel: MeshInstance3D
var _brakk: Dictionary = {}
var _arm := 0.0
var _blick_t := 0.0
var _boden_mat: ShaderMaterial
# Hintergrundspiel
var _pfad: Array = []       # Vector3-Punkte vom HQ zur Verteidigung
var _vt: Vector3
var _stellungen: Array = []  # {b, bilder, ort, flip, pause, schuss}
var _gegner: Array = []      # {b, bilder, weg, hp, tot, flip}
var _effekte: Array = []     # {knoten, t, dauer, art}
var _gegner_in := 2.0
var _vt_licht: OmniLight3D


func _init() -> void:
	var sh := Shader.new()
	sh.code = POST_SHADER
	post = ShaderMaterial.new()
	post.shader = sh


func _ready() -> void:
	if szene == "klippe":
		_kam_pos = KL_KAM_POS
		_kam_blick = KL_KAM_BLICK
		_boden_y = KL_BODEN_Y
		_spiel_y = KL_SPIEL_Y
		_mass = KL_VT_GROESSE / VT_GROESSE
		_trupp = Vector2i(2, 4)
		_takt = Vector2(6.0, 10.0)
		post.set_shader_parameter("tiefe", 2.4)
		post.set_shader_parameter("fokus", Vector2(0.2, 0.66))
		post.set_shader_parameter("fokus_r", Vector2(0.24, 0.3))
		post.set_shader_parameter("klar", Vector2(0.74, 0.25))
		post.set_shader_parameter("klar_r", Vector2(0.2, 0.09))
	kamera = Camera3D.new()
	kamera.near = 0.2
	kamera.far = 300.0
	add_child(kamera)
	kamera.make_current()
	var umwelt := WorldEnvironment.new()
	_env = Environment.new()
	_env.background_mode = Environment.BG_COLOR
	_env.background_color = Color("0b0e14")
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	_env.fog_enabled = true
	_env.fog_mode = Environment.FOG_MODE_DEPTH
	_env.fog_depth_curve = 1.4
	_env.fog_density = 1.0
	_env.fog_depth_begin = 80.0
	_env.fog_depth_end = 420.0
	if szene == "klippe":   # dunstiger: das Tal verschwimmt, die Anhöhe bleibt erkennbar
		_env.fog_depth_curve = 1.0
		_env.fog_density = 0.82
		_env.fog_depth_begin = 18.0
		_env.fog_depth_end = 260.0
	_env.glow_enabled = not einfach
	_env.glow_intensity = 0.6
	_env.glow_bloom = 0.05
	_env.glow_hdr_threshold = 0.9
	umwelt.environment = _env
	add_child(umwelt)
	_sonne = DirectionalLight3D.new()
	_sonne.rotation_degrees = Vector3(-24.0, -125.0, 0.0)
	add_child(_sonne)
	if einfach:
		post.set_shader_parameter("weich", 0.0)
	if szene == "klippe":
		_baue_klippe()
	else:
		_baue()
	var l := _pfad_laenge()
	_neuer_gegner(maxf(0.0, l - SCHUSS_WEITE * _mass - 2.5 * _mass))   # gleich etwas zu sehen: eine kurz vor der Verteidigung …
	_neuer_gegner(l * 0.45)                                             # … eine auf halbem Weg
	_weiter(0.0)


func _tex(name: String) -> Texture2D:
	if not _bilder.has(name):
		_bilder[name] = load(S + name) if ResourceLoader.exists(S + name) else null
	return _bilder[name]


## Punkt auf der Höhe `y` (Standard: Talboden) unter einer Stelle des Bilds (Anteile 0..1 des 16:9-Bilds), für die feste
## Grundstellung der Kamera.
func am_schirm(s: Vector2, y: float = INF) -> Vector3:
	if is_inf(y):
		y = _boden_y
	var f := (_kam_blick - _kam_pos).normalized()
	var r := f.cross(Vector3.UP).normalized()
	var u := r.cross(f).normalized()
	var th := tan(deg_to_rad(KAM_FOV) / 2.0)
	var d := (f + r * ((s.x * 2.0 - 1.0) * th * 16.0 / 9.0) + u * ((1.0 - s.y * 2.0) * th)).normalized()
	return _kam_pos + d * ((y - _kam_pos.y) / d.y)


## Markieren eines Menüpunkts: Brakk dreht kurz den Kopf zur Liste.
func blick() -> void:
	_blick_t = 0.6


## Wo Brakks Handfläche gerade im Bild ist (Anteile 0..1).
func hand_bildpunkt() -> Vector2:
	var g := Vector2(get_viewport().size)
	if g.x <= 0.0 or kamera.is_position_behind(_hand):
		return Vector2(0.4, 0.55)
	return kamera.unproject_position(_hand) / g


# ------------------------------------------------------------------ Aufbau

func _baue() -> void:
	_himmel_und_berge()
	_boden(-200.0, 260.0, -420.0, 30.0, BODEN_Y)
	# Plattform: Wallblöcke, die vorn links ins Bild ragen und zur Spitze hin flacher werden
	for s: Array in [[-4.0, 0.0, 7.0, 12.0, 2.4], [0.0, 2.0, 7.4, 11.6, 2.4], [2.0, 3.4, 8.0, 11.2, 1.6], [-4.0, -1.0, 4.0, 7.0, 3.2]]:
		_klotz(s[0], s[1], s[2], s[3], BODEN_Y, s[4])
	# Figuren: Füße auf der Wallkrone; der Plasmawerfer rechts schaut nach links, keiner steht vor der Liste
	_brakk = _figur("brakk.png", Vector3(1.3, 2.4, 9.2), 1.2, true, "brakk")
	_figur("truppe_gun.png", Vector3(0.1, 2.4, 9.9), 1.8, false, "truppe")
	_figur("truppe_sni.png", Vector3(-0.9, 2.4, 8.6), 1.8, false, "truppe")
	_figur("truppe_pla.png", Vector3(1.75, 2.4, 9.9), 1.8, true, "truppe")
	_hand_bauen()
	_huegel(HUEGEL)
	_lampe(Vector3(1.0, 3.6, 8.6), Color("ffb070"), 4.0, 0.7)   # Laterne bei der Truppe: nur ein warmer Schein
	_hintergrundspiel()
	_waende_fertig()   # nach der Verteidigung: deren Wälle gehören ins selbe Netz
	_baeume(80, Rect2(4.0, -60.0, 42.0, 68.0), Vector2(1.5, 2.2))
	_blaetter(Vector3(8.0, 3.0, 6.0), Vector3(12.0, 3.0, 8.0), false)
	var f := _partikel(Vector3(-2.5, 3.4, 6.8), Vector3(0.2, 0.1, 0.2), Color(1.6, 0.9, 0.4), 6 if einfach else 14, 1.1, Vector3(0.3, 1.6, 0), 0.05)
	f.gravity = Vector3(0, -2.2, 0)


## Szene „klippe“: Fels unten links mit Erdwall-Krone, Tal tief unten, Verteidigung oben rechts auf einer Anhöhe.
func _baue_klippe() -> void:
	_himmel_und_berge()
	_boden(-200.0, 260.0, -420.0, 30.0, KL_BODEN_Y)
	var fuss := am_schirm(KL_BRAKK, KL_OBEN)
	for s: Array in KL_FELS:
		_fels(fuss.x + s[0], fuss.x + s[1], fuss.z + s[2], fuss.z + s[3], s[4], s[5])
	_klotz(fuss.x - 16.0, fuss.x + 1.4, fuss.z - 6.0, fuss.z + 2.0, 1.6, KL_OBEN)   # Erdwall-Krone (nachts Leuchtstreifen)
	_brakk = _figur("brakk.png", fuss, 1.2, true, "brakk")
	_figur("truppe_gun.png", fuss + Vector3(-1.2, 0, 0.7), 1.8, false, "truppe")
	_figur("truppe_sni.png", fuss + Vector3(-2.2, 0, -0.6), 1.8, false, "truppe")
	_figur("truppe_pla.png", fuss + Vector3(0.45, 0, 0.7), 1.8, true, "truppe")
	_hand_bauen()
	_huegel(KL_HUEGEL)
	_lampe(fuss + Vector3(-0.3, 1.2, -0.6), Color("ffb070"), 4.0, 0.7)
	_anhoehe_bauen(am_schirm(KL_VT, KL_SPIEL_Y))
	_hintergrundspiel()
	_waende_fertig()
	_baeume(170, Rect2(-40.0, -170.0, 150.0, 160.0), Vector2(3.0, 5.0))
	_baum_vorn(fuss + Vector3(-4.0, 4.6 - KL_OBEN, -5.0))
	_strahlen_bauen()
	_blaetter(fuss + Vector3(3.0, 4.0, -1.0), Vector3(8.0, 3.0, 3.0), true)
	var f := _partikel(fuss + Vector3(-3.2, 1.0, -1.0), Vector3(0.2, 0.1, 0.2), Color(1.6, 0.9, 0.4), 6 if einfach else 14, 1.1, Vector3(0.3, 1.6, 0), 0.05)
	f.gravity = Vector3(0, -2.2, 0)


## Klippe: die Anhöhe der Verteidigung aus Tafelbergen (gemalter Boden, flache Kuppe, steile Hänge).
func _anhoehe_bauen(vt: Vector3) -> void:
	var unten := KL_BODEN_Y - 2.0
	for a: Array in KL_ANHOEHE:
		var oben := float(a[4])
		var m := Vector3(vt.x + float(a[0]), unten, vt.z + float(a[1]))
		_anh.append([m, Vector3(float(a[2]), oben, float(a[3]))])
		var k := MeshInstance3D.new()
		var berg := CylinderMesh.new()
		berg.top_radius = 1.0
		berg.bottom_radius = KL_HANG
		berg.height = 1.0
		berg.radial_segments = 48
		berg.rings = 3
		k.mesh = berg
		k.material_override = _boden_mat
		k.position = Vector3(m.x, (unten + oben) / 2.0, m.z)
		k.scale = Vector3(float(a[2]), oben - unten, float(a[3]))
		add_child(k)


## Höhe der Anhöhe unter einem Punkt (Klippe: Kuppe flach, Hang linear); in „Ausblick“ bleibt der Punkt, wie er ist.
func _auf_boden(p: Vector3) -> Vector3:
	if _anh.is_empty():
		return p
	var y := _boden_y
	for a: Array in _anh:
		var m: Vector3 = a[0]
		var r: Vector3 = a[1]
		var d := Vector2((p.x - m.x) / r.x, (p.z - m.z) / r.z).length()
		if d <= KL_HANG:
			y = maxf(y, lerpf(r.y, m.y, clampf((d - 1.0) / (KL_HANG - 1.0), 0.0, 1.0)))
	return Vector3(p.x, y, p.z)


## Zerklüfteter Fels: Quader mit unterteilten Flächen; FELS_SHADER schiebt die Punkte nach einem Rauschen (gleiche Punkte
## an den Kanten bewegen sich gleich – keine Risse).
func _fels(x0: float, x1: float, z0: float, z1: float, y0: float, y1: float) -> void:
	var dx := Vector3(x1 - x0, 0, 0)
	var dy := Vector3(0, y1 - y0, 0)
	var dz := Vector3(0, 0, z1 - z0)
	_fels_flaeche(Vector3(x0, y1, z0), dx, dz, Vector3.UP)
	_fels_flaeche(Vector3(x0, y0, z1), dx, dy, Vector3.BACK)
	_fels_flaeche(Vector3(x0, y0, z0), dx, dy, Vector3.FORWARD)
	_fels_flaeche(Vector3(x0, y0, z0), dz, dy, Vector3.LEFT)
	_fels_flaeche(Vector3(x1, y0, z0), dz, dy, Vector3.RIGHT)


func _fels_flaeche(o: Vector3, a: Vector3, b: Vector3, n: Vector3) -> void:
	if not _st.has("fels"):
		var neu := SurfaceTool.new()
		neu.begin(Mesh.PRIMITIVE_TRIANGLES)
		_st["fels"] = neu
	var st: SurfaceTool = _st["fels"]
	var na := maxi(1, ceili(a.length() / 1.1))
	var nb := maxi(1, ceili(b.length() / 1.1))
	for i in na:
		for k in nb:
			var e := [o + a * (float(i) / na) + b * (float(k) / nb), o + a * (float(i + 1) / na) + b * (float(k) / nb),
				o + a * (float(i + 1) / na) + b * (float(k + 1) / nb), o + a * (float(i) / na) + b * (float(k + 1) / nb)]
			for j: int in [0, 1, 2, 0, 2, 3]:
				st.set_normal(n)
				st.set_uv(Vector2.ZERO)
				st.add_vertex(e[j])


## Handschuh: Licht und kleine Leuchtkugel an Brakks Handfläche (Hologramm-Tafeln).
func _hand_bauen() -> void:
	_hand = _hand_ort()
	_hand_licht = OmniLight3D.new()
	_hand_licht.light_color = Color("b07cff")
	_hand_licht.omni_range = 2.5
	_hand_licht.light_energy = 0.0
	_hand_licht.position = _hand
	add_child(_hand_licht)
	var hm := MeshInstance3D.new()
	var hk := SphereMesh.new()
	hk.radius = 0.06
	hk.height = 0.12
	hm.mesh = hk
	_hand_mat = StandardMaterial3D.new()
	_hand_mat.albedo_color = Color("c9a2ff")
	_hand_mat.emission_enabled = true
	_hand_mat.emission = Color("b07cff")
	_hand_mat.emission_energy_multiplier = 0.0
	_hand_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_hand_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	hm.material_override = _hand_mat
	hm.position = _hand
	add_child(hm)
	_hand_kugel = hm


## Blätter (Klippe: dazu orange Herbstblätter vom Baum), die quer durchs Bild wehen.
func _blaetter(ort: Vector3, kasten: Vector3, herbst: bool) -> void:
	var p := _partikel(ort, kasten, Color.WHITE, 20 if einfach else 46, 7.0, Vector3(0.9, -0.15, 0.1), 0.066)
	p.gravity = Vector3(0, -0.04, 0)
	p.angular_velocity_min = -180.0
	p.angular_velocity_max = 180.0
	var g := Gradient.new()
	if herbst:
		g.colors = PackedColorArray([Color("d0702a"), Color("e8a040"), Color("9a7a3a"), Color("c04a2a")])
	else:
		g.colors = PackedColorArray([Color("6d8f3a"), Color("9a7a3a"), Color("5b6f2e"), Color("b08a4a")])
	g.offsets = PackedFloat32Array([0.0, 0.35, 0.7, 1.0])
	p.color_initial_ramp = g


## HQ, Pfad, Verteidigung (ohne Gegner – die kommen in _gegner_weiter).
func _hintergrundspiel() -> void:
	var klippe := szene == "klippe"
	_pfad.clear()
	if klippe:   # Verteidigung am Bildpunkt, HQ und Pfad relativ dazu auf der Anhöhe
		_vt = _auf_boden(am_schirm(KL_VT, KL_SPIEL_Y))
		for s: Vector2 in KL_PFAD:
			_pfad.append(_auf_boden(_vt + Vector3(s.x, 0, s.y)))
	else:
		_vt = am_schirm(VT_SCHIRM, _spiel_y)
		for s: Vector2 in PFAD_SCHIRM:
			_pfad.append(am_schirm(s, _spiel_y))
	var hq_ort := _auf_boden(_vt + Vector3(KL_HQ.x, 0, KL_HQ.y)) if klippe else am_schirm(HQ_SCHIRM, _spiel_y)
	var hq := _bild_breit("hq.png", hq_ort, 7.0 * _mass)
	_kupferlichter(hq.position + Vector3(0, 3.6, 0.5) * _mass, 3.6 * _mass)
	_lampe(hq.position + Vector3(0.0, 3.0, 3.0) * _mass, Color("ff9a4a"), 12.0 * _mass)
	var rauch := _partikel(hq.position + Vector3(0, 6.0, 0) * _mass, Vector3(1.0, 0.2, 0.5) * _mass, Color(0.45, 0.42, 0.42, 0.7), 8 if einfach else 16, 5.0, Vector3(0.3, 1.1, 0) * _mass, 0.9 * _mass)
	rauch.gravity = Vector3(0.05, 0.05, 0)
	rauch.scale_amount_min = 0.6
	rauch.scale_amount_max = 1.6
	((rauch.mesh as QuadMesh).material as StandardMaterial3D).transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	# Pfad als Erdstreifen
	var weg := StandardMaterial3D.new()
	weg.albedo_color = Color("7a6040")
	weg.roughness = 1.0
	weg.cull_mode = BaseMaterial3D.CULL_DISABLED
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var punkte := _pfad.duplicate()
	punkte.append(_vt)
	for i in punkte.size() - 1:
		var a: Vector3 = punkte[i]
		var b: Vector3 = punkte[i + 1]
		var q := (b - a).cross(Vector3.UP).normalized() * 0.8 * _mass
		var e := [a - q, a + q, b + q, b - q]
		for k: int in [0, 1, 2, 0, 2, 3]:
			st.set_normal(Vector3.UP)
			st.add_vertex(e[k] + Vector3(0, 0.06, 0))
	var wm := MeshInstance3D.new()
	wm.mesh = st.commit()
	wm.material_override = weg
	add_child(wm)
	# Verteidigung: Erdwälle quer zum Weg (Ausblick 3, Klippe 5), dahinter Formtürme; auf den Wällen die Stellungen
	var von: Vector3 = _pfad[_pfad.size() - 1]
	var richtung := Vector3(von.x - _vt.x, 0, von.z - _vt.z).normalized()   # zum Feind hin
	var quer := richtung.cross(Vector3.UP).normalized()
	var g := VT_GROESSE * _mass
	var mitte := _vt - richtung * 0.6 * g
	var n := 2 if klippe else 1
	for k in range(-n, n + 1):   # Wälle quer zum Weg, leicht versetzt (frei gesetzt, kein Raster)
		var c: Vector3 = _auf_boden(mitte + quer * (k * 1.05 * g) + richtung * (0.25 * g * float(k * k)) * (-1.0 if k < 0 else 1.0) * (0.5 if n > 1 else 1.0))
		_silhouette(c, 0.95 * g, 0.7 * g, 0.55 * g)
		var art: String = ["vt_stellung_gun.png", "vt_stellung_sni.png", "vt_stellung_pla.png"][posmod(k + 1, 3)]
		var s := _figur(art, c + Vector3(0, 0.55 * g, 0), 0.8 * g, richtung.x < 0.0, "stellung")
		_stellungen.append({"f": s, "pause": randf_range(0.2, 0.9), "schuss": 0.0})
	for seite: float in ([1.0, -1.0] if klippe else [1.0]):   # Formtürme: hoher Wall, oben der Turm
		var turm := _auf_boden(mitte - richtung * 1.3 * g + quer * (1.6 + float(n - 1) * 1.1) * g * seite)
		_silhouette(turm, 0.9 * g, 0.9 * g, 1.1 * g)
		_bild_breit("vt_turm.png", turm + Vector3(0, 1.1 * g, 0), 1.1 * g)
	_vt_licht = OmniLight3D.new()
	_vt_licht.light_color = Color("ffd890")
	_vt_licht.omni_range = 4.0 * g
	_vt_licht.light_energy = 0.0
	_vt_licht.position = mitte + Vector3(0, 1.0, 0)
	add_child(_vt_licht)


func _himmel_und_berge() -> void:
	var q := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(520, 190)
	q.mesh = qm
	var sh := Shader.new()
	sh.code = HIMMEL_SHADER
	_himmel = ShaderMaterial.new()
	_himmel.shader = sh
	var rauschen := NoiseTexture2D.new()
	rauschen.width = 256
	rauschen.height = 128
	rauschen.seamless = true
	var fn := FastNoiseLite.new()
	fn.frequency = 0.012
	fn.fractal_octaves = 4
	rauschen.noise = fn
	_himmel.set_shader_parameter("rauschen", rauschen)
	_himmel.set_shader_parameter("abend", _tex("himmel_abend.png"))
	_himmel.set_shader_parameter("nacht_bild", _tex("himmel_nacht.png"))
	q.material_override = _himmel
	# Himmel: große Fläche quer zur Blickrichtung, weit hinter den Bergen (deckt auch die Bildränder)
	var vorn := Vector3(_kam_blick.x - _kam_pos.x, 0.0, _kam_blick.z - _kam_pos.z).normalized()
	var fuss := am_schirm(BERGE_SCHIRM)
	if szene == "klippe":   # Berge weit hinter der Anhöhe, Fuß auf dem Talboden
		fuss = Vector3(_kam_pos.x, _boden_y, _kam_pos.z) + vorn * 200.0
	qm.size = Vector2(1100, 420)
	q.position = _kam_pos + vorn * 280.0 + Vector3(0, 40.0, 0)
	add_child(q)
	q.look_at(_kam_pos + Vector3(0, 40.0, 0), Vector3.UP)
	q.rotate_object_local(Vector3.UP, PI)
	# Berge: zwei Lagen zu je fünf Bildern, die hintere blasser; Fuß auf der Linie BERGE_SCHIRM, über die ganze Breite
	var tex := _tex("berge.png")
	for i in 2:
		for k in range(-2, 3):
			var b := Sprite3D.new()
			b.texture = tex
			b.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
			b.shaded = false
			b.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
			b.centered = false
			var breite := 80.0 if i == 0 else 110.0
			b.pixel_size = breite / float(tex.get_width())
			b.offset = Vector2(-tex.get_width() / 2.0, -_leer_unten(tex, Rect2(Vector2.ZERO, tex.get_size())) - 3.0)
			b.position = fuss + vorn.cross(Vector3.UP).normalized() * (k * breite * 0.9 + i * 25.0) + vorn * (2.0 + 28.0 * i)
			b.modulate = Color(0.78, 0.8, 0.9) if i == 0 else Color(0.6, 0.64, 0.78)
			b.flip_h = (k + i) % 2 == 1
			b.render_priority = -2 + i
			add_child(b)


## Boden als gemalte Fläche: das Bodenbild groß gezogen und mit weichen Farbflecken überlagert – kein Kachelraster.
func _boden(x0: float, x1: float, z0: float, z1: float, y: float) -> void:
	if _boden_mat == null:
		var sh := Shader.new()
		sh.code = BODEN_SHADER
		_boden_mat = ShaderMaterial.new()
		_boden_mat.shader = sh
		_boden_mat.set_shader_parameter("boden", _tex("boden.png"))
		_boden_mat.set_shader_parameter("flecken", _flecken())
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var e := [Vector3(x0, y, z0), Vector3(x1, y, z0), Vector3(x1, y, z1), Vector3(x0, y, z1)]
	for i: int in [0, 1, 2, 0, 2, 3]:
		st.set_normal(Vector3.UP)
		st.set_uv(Vector2(e[i].x, e[i].z))
		st.add_vertex(e[i])
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = _boden_mat
	add_child(mi)


func _flecken() -> NoiseTexture2D:
	var flecken := NoiseTexture2D.new()
	flecken.width = 256
	flecken.height = 256
	flecken.seamless = true
	var fn := FastNoiseLite.new()
	fn.frequency = 0.01
	fn.fractal_octaves = 3
	flecken.noise = fn
	return flecken


## Frei gesetzte Hügel im Tal (flache Kuppen mit demselben gemalten Boden).
func _huegel(liste: Array) -> void:
	for h: Array in liste:
		var m := MeshInstance3D.new()
		var k := SphereMesh.new()
		k.radius = 1.0
		k.height = 2.0
		k.radial_segments = 24
		k.rings = 12
		m.mesh = k
		m.material_override = _boden_mat
		var ort := am_schirm(Vector2(h[0], h[1]))
		m.position = ort
		m.scale = Vector3(float(h[2]), float(h[3]), float(h[2]) * 0.7)
		add_child(m)


## Wall der Hintergrund-Verteidigung als Silhouette: dunkler Block mit schmaler Leuchtkante (nachts heller).
var _kanten: Array = []

func _silhouette(c: Vector3, breite: float, tiefe: float, hoehe: float) -> void:
	var m := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = Vector3(breite, hoehe, tiefe)
	m.mesh = b
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.17, 0.19, 0.25)
	mat.roughness = 1.0
	m.material_override = mat
	m.position = c + Vector3(0, hoehe / 2.0, 0)
	add_child(m)
	var k := MeshInstance3D.new()
	var kb := BoxMesh.new()
	kb.size = Vector3(breite * 1.01, hoehe * 0.12, tiefe * 1.01)
	k.mesh = kb
	var km := StandardMaterial3D.new()
	km.albedo_color = Color("3fb8d8")
	km.emission_enabled = true
	km.emission = Color("7fe0ff")
	km.emission_energy_multiplier = 0.2
	k.material_override = km
	k.position = c + Vector3(0, hoehe * 0.8, 0)
	add_child(k)
	_kanten.append(km)


func _hand_ort() -> Vector3:
	var fuss: Vector3 = _brakk.get("fuss", Vector3.ZERO)
	var rechts := (_kam_blick - _kam_pos).cross(Vector3.UP).normalized()
	return fuss + rechts * lerpf(0.28, 0.42, _arm) + Vector3(0, lerpf(0.5, 0.78, _arm) * 1.2, 0.05)


func _vier(name: String, e: Array, uv: Array) -> void:
	if not _st.has(name):
		var neu := SurfaceTool.new()
		neu.begin(Mesh.PRIMITIVE_TRIANGLES)
		_st[name] = neu
	var st: SurfaceTool = _st[name]
	for i: int in [0, 2, 1, 0, 3, 2]:
		st.set_uv(uv[i])
		st.add_vertex(e[i])


## Wallblock: Front, Seiten und Oberseite (je Feld bzw. 0,8 Höhe ein Bild).
func _klotz(x0: float, x1: float, z0: float, z1: float, y0: float, y1: float) -> void:
	var h0 := y0 / 0.8
	var h1 := y1 / 0.8
	_vier("oben", [Vector3(x0, y1, z0), Vector3(x1, y1, z0), Vector3(x1, y1, z1), Vector3(x0, y1, z1)],
		[Vector2(x0, z0), Vector2(x1, z0), Vector2(x1, z1), Vector2(x0, z1)])
	_vier("front", [Vector3(x0, y1, z1), Vector3(x1, y1, z1), Vector3(x1, y0, z1), Vector3(x0, y0, z1)],
		[Vector2(x0, -h1), Vector2(x1, -h1), Vector2(x1, -h0), Vector2(x0, -h0)])
	_vier("seite", [Vector3(x1, y1, z0), Vector3(x0, y1, z0), Vector3(x0, y0, z0), Vector3(x1, y0, z0)],
		[Vector2(x1, -h1), Vector2(x0, -h1), Vector2(x0, -h0), Vector2(x1, -h0)])
	_vier("seite", [Vector3(x0, y1, z0), Vector3(x0, y1, z1), Vector3(x0, y0, z1), Vector3(x0, y0, z0)],
		[Vector2(z0, -h1), Vector2(z1, -h1), Vector2(z1, -h0), Vector2(z0, -h0)])
	_vier("seite", [Vector3(x1, y1, z1), Vector3(x1, y1, z0), Vector3(x1, y0, z0), Vector3(x1, y0, z1)],
		[Vector2(z1, -h1), Vector2(z0, -h1), Vector2(z0, -h0), Vector2(z1, -h0)])


func _waende_fertig() -> void:
	_front_mat = _wandstoff("wall_front.png", Color(0.78, 0.84, 0.96))
	_front_mat.emission_enabled = true
	_front_mat.emission_texture = _tex("wall_leucht.png")
	_front_mat.emission = Color.WHITE
	_front_mat.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY   # nur die Streifen der Maske leuchten (nicht die ganze Front)
	_front_mat.emission_energy_multiplier = 0.0
	var mats := {"oben": _wandstoff("wall_oben.png", Color(0.66, 0.72, 0.84)), "front": _front_mat,
		"seite": _wandstoff("wall_seite.png", Color(0.78, 0.84, 0.96))}
	if _st.has("fels"):
		var sh := Shader.new()
		sh.code = FELS_SHADER
		_fels_mat = ShaderMaterial.new()
		_fels_mat.shader = sh
		_fels_mat.set_shader_parameter("fels", _tex("wall_seite.png"))
		_fels_mat.set_shader_parameter("gras", _tex("boden.png"))
		_fels_mat.set_shader_parameter("flecken", _flecken())
		_fels_mat.set_shader_parameter("unten", _boden_y)
		mats["fels"] = _fels_mat
	var mesh := ArrayMesh.new()
	var i := 0
	for name: String in _st:
		var st: SurfaceTool = _st[name]
		if name != "fels":   # Fels: Normalen je Fläche gesetzt, das Licht rechnet der Shader
			st.generate_normals()
		st.commit(mesh)
		mesh.surface_set_material(i, mats[name])
		i += 1
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	add_child(mi)
	_st.clear()


func _wandstoff(name: String, farbe: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = _tex(name)
	m.albedo_color = farbe
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.texture_repeat = true
	m.roughness = 1.0
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


func _sprite(tex: Texture2D, region: Rect2, fuss: Vector3, pixel: float) -> Sprite3D:
	var b := Sprite3D.new()
	b.texture = tex
	b.region_enabled = true
	b.region_rect = region
	b.pixel_size = pixel
	b.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	b.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	b.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	b.shaded = false
	b.double_sided = true
	b.centered = false
	b.offset = Vector2(-region.size.x / 2.0, -_leer_unten(tex, region))
	b.position = fuss
	add_child(b)
	return b


## Ein ganzes Bild mit fester Breite in der Szene (HQ, Turm) – Fuß unten in der Mitte.
func _bild_breit(name: String, fuss: Vector3, breite: float) -> Sprite3D:
	var tex := _tex(name)
	return _sprite(tex, Rect2(Vector2.ZERO, tex.get_size()), fuss, breite / float(tex.get_width()))


## Leere Zeilen unter den Füßen eines Bilds (damit Fuß und Schatten auf der Wallkrone sitzen).
func _leer_unten(tex: Texture2D, r: Rect2) -> int:
	var b := tex.get_image()
	if b == null:
		return 0
	if b.is_compressed():
		b.decompress()
	for y in range(int(r.end.y) - 1, int(r.position.y) - 1, -1):
		for x in range(int(r.position.x), int(r.end.x)):
			if b.get_pixel(x, y).a > 0.1:
				return int(r.end.y) - 1 - y
	return 0


## Figur aus einem Streifen quadratischer Bilder; `hoehe` in der Szene, unabhängig von der Auflösung.
func _figur(name: String, fuss: Vector3, hoehe: float, flip: bool, art: String) -> Dictionary:
	var tex := _tex(name)
	var z := tex.get_height()
	var b := _sprite(tex, Rect2(0, 0, z, z), fuss, hoehe / float(z))
	b.flip_h = flip
	var f := {"b": b, "bilder": maxi(1, tex.get_width() / z), "zelle": z, "fuss": fuss, "phase": randf() * TAU, "flip": flip, "regung": 0.0, "art": art}
	if art != "stellung":
		_figuren.append(f)
		_schatten(fuss, hoehe * 0.32)
	return f


func _bild_setzen(f: Dictionary, i: int) -> void:
	var z: int = f["zelle"]
	(f["b"] as Sprite3D).region_rect = Rect2(posmod(i, int(f["bilder"])) * z, 0, z, z)


func _schatten(fuss: Vector3, r: float) -> void:
	var m := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = r
	c.bottom_radius = r
	c.height = 0.01
	m.mesh = c
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0, 0, 0, 0.38)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.material_override = mat
	m.scale = Vector3(1.0, 1.0, 0.45)
	m.position = fuss + Vector3(0, 0.012, 0)
	add_child(m)


## Bäume im Tal: `feld` = Bereich (x, z, Breite, Tiefe) auf dem Talboden, `groesse` = Höhe von/bis.
func _baeume(anzahl: int, feld: Rect2, groesse: Vector2) -> void:
	var zufall := RandomNumberGenerator.new()
	zufall.seed = 79
	var tex: Texture2D = load("res://assets/neu/terrain/SHEET2.png")   # Bäume: wie im Spiel (Kulisse, kein Menü-Bild)
	var arten := [0, 1, 2, 4, 5, 7, 13, 14]
	var frei := _pfad.duplicate()
	frei.append(_vt)
	var n := 0
	while n < anzahl:
		var p := _auf_boden(Vector3(zufall.randf_range(feld.position.x, feld.end.x), _boden_y, zufall.randf_range(feld.position.y, feld.end.y)))   # Klippe: auch auf der Anhöhe
		n += 1
		var nah := false
		for q: Vector3 in frei:
			if Vector2(p.x - q.x, p.z - q.z).length() < 3.5 * (1.0 if _anh.is_empty() else 2.5 * _mass):
				nah = true
		if nah:
			continue   # Pfad und Verteidigung bleiben frei
		var b := _sprite(tex, Rect2(int(arten[zufall.randi() % arten.size()]) * 64, 32, 64, 64), p, zufall.randf_range(groesse.x, groesse.y) / 64.0)
		b.offset = Vector2(-32, -4)
		b.modulate = Color(0.86, 0.9, 0.84)
		b.flip_h = zufall.randf() < 0.5


## Klippe: der große Baum auf dem hinteren Fels, der von links oben ins Bild ragt (baum_vorn.png).
func _baum_vorn(fuss: Vector3) -> void:
	var tex := _tex("baum_vorn.png")
	if tex == null:
		return
	var b := _bild_breit("baum_vorn.png", fuss, 9.0)
	b.modulate = Color(0.92, 0.88, 0.86)
	_schatten(fuss, 1.6)


## Klippe: weiche Lichtstrahlen von links oben ins Tal (nur abends; nachts ausgeblendet).
func _strahlen_bauen() -> void:
	var verlauf := Gradient.new()
	verlauf.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	verlauf.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
	var tex := GradientTexture2D.new()
	tex.gradient = verlauf
	tex.fill_from = Vector2(0, 0)
	tex.fill_to = Vector2(1, 0)
	tex.width = 32
	tex.height = 4
	for s: Array in [[0.34, 7.0], [0.43, 4.5], [0.52, 9.0], [0.61, 5.5]]:
		var m := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(float(s[1]), 140.0)
		m.mesh = q
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mat.albedo_texture = tex
		mat.albedo_color = Color(1.0, 0.82, 0.6, 0.1)
		m.material_override = mat
		var ort := am_schirm(Vector2(float(s[0]), 0.5))
		m.position = ort + Vector3(0, 40.0, 0)
		add_child(m)
		m.look_at(_kam_pos, Vector3.UP)
		m.rotate_object_local(Vector3.FORWARD, -0.42)
		_strahlen.append(mat)


func _kupferlichter(mitte: Vector3, weite: float) -> void:
	for i in 5:
		var m := MeshInstance3D.new()
		var s := SphereMesh.new()
		s.radius = 0.05 * weite
		s.height = 0.1 * weite
		m.mesh = s
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color("ff9a4a")
		mat.emission_enabled = true
		mat.emission = Color("ff9a4a")
		m.material_override = mat
		m.position = mitte + Vector3((i - 2) * 0.28 * weite, sin(i * 1.7) * 0.25 * weite, 0.05)
		add_child(m)
		_lichter.append([mat, i * 1.3])


func _lampe(ort: Vector3, farbe: Color, weite: float, staerke: float = 2.4) -> void:
	var l := OmniLight3D.new()
	l.light_color = farbe
	l.omni_range = weite
	l.light_energy = 0.0
	l.position = ort
	l.set_meta("staerke", staerke)
	add_child(l)
	_lampen.append(l)


func _partikel(ort: Vector3, kasten: Vector3, farbe: Color, anzahl: int, leben: float, richtung: Vector3, groesse: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = anzahl
	p.lifetime = leben
	p.preprocess = leben
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = kasten
	p.direction = richtung.normalized()
	p.spread = 25.0
	p.initial_velocity_min = richtung.length() * 0.6
	p.initial_velocity_max = richtung.length()
	var q := QuadMesh.new()
	q.size = Vector2(groesse, groesse)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	q.material = m
	p.mesh = q
	p.color = farbe
	p.position = ort
	add_child(p)
	return p


# ------------------------------------------------------------------ Ablauf

func _process(delta: float) -> void:
	_weiter(delta / maxf(Engine.time_scale, 0.01))   # Echtzeit – das Spiel dahinter läuft mit Engine.time_scale


func _weiter(delta: float) -> void:
	_zeit += delta
	_nacht = UiBewegung.naeher(_nacht, nacht_ziel, delta, UiBewegung.NACHT)
	_unter = UiBewegung.naeher(_unter, unter_ziel, delta, UiBewegung.UEBERBLENDUNG)
	var e := UiBewegung.weich(_unter)
	_figuren_weiter(delta)
	_gegner_weiter(delta)
	_effekte_weiter(delta)
	# Licht und Himmel: Abend ↔ Nacht (dunkelblau, die Szene bleibt sichtbar)
	var horizont := Color("e89a6a").lerp(Color("2a3d6b"), _nacht)
	_himmel.set_shader_parameter("wolke", Color("f0bfa0").lerp(Color("34446e"), _nacht))
	_himmel.set_shader_parameter("nacht", _nacht)
	if szene == "klippe":   # heller Dunst über dem Tal
		_env.fog_light_color = horizont.lerp(Color("f2d6b8"), 0.35 * (1.0 - _nacht)).darkened(0.08 + 0.15 * _nacht)
	else:
		_env.fog_light_color = horizont.darkened(0.25 + 0.1 * _nacht)
	for m: StandardMaterial3D in _strahlen:
		m.albedo_color.a = 0.1 * (1.0 - _nacht)
	_env.ambient_light_color = Color(1.0, 0.84, 0.74).lerp(Color(0.48, 0.6, 0.95), _nacht)
	_env.ambient_light_energy = lerpf(0.72, 0.48, _nacht)
	_sonne.light_color = Color("ffb27a").lerp(Color("6f88cc"), _nacht)
	_sonne.light_energy = lerpf(0.85, 0.22, _nacht)
	_front_mat.emission_energy_multiplier = 1.8 * _nacht
	for l: OmniLight3D in _lampen:
		l.light_energy = lerpf(0.0, float(l.get_meta("staerke")), _nacht) * (0.9 + 0.1 * sin(_zeit * 11.0))
	for li: Array in _lichter:
		var an := 0.5 + 0.5 * sin(_zeit * 2.6 + float(li[1]))
		(li[0] as StandardMaterial3D).emission_energy_multiplier = lerpf(0.4, 3.5, an * an) * lerpf(1.0, 2.0, _nacht)
	_hand = _hand_ort()
	_hand_licht.position = _hand
	_hand_kugel.position = _hand
	_hand_licht.light_energy = hand_leuchten * 4.0
	_hand_mat.emission_energy_multiplier = hand_leuchten * 6.0
	_hand_mat.albedo_color.a = clampf(hand_leuchten * 3.0, 0.0, 1.0)   # aus = unsichtbar
	for km: StandardMaterial3D in _kanten:
		km.emission_energy_multiplier = lerpf(0.2, 2.2, _nacht)
	# Kamera: wiegt leicht; bei einer Unterseite rückt sie etwas vor
	var pos := _kam_pos + Vector3(sin(_zeit * 0.13) * 0.18, sin(_zeit * 0.21) * 0.06, 0.0)
	pos = pos.lerp(pos + (_kam_blick - pos).normalized() * VORRUECKEN, e)
	kamera.position = pos
	kamera.fov = KAM_FOV
	kamera.look_at(_kam_blick, Vector3.UP)
	# Bild: Tilt-Shift oben/unten, Unterseite = Tusche, dunkler, weicher (nachts bleibt es blau und heller)
	post.set_shader_parameter("alles", 2.0 * e)
	post.set_shader_parameter("dunkel", 0.3 * e * (1.0 - 0.6 * _nacht))
	post.set_shader_parameter("tusche", e * (1.0 - 0.85 * _nacht))


func _figuren_weiter(delta: float) -> void:
	_regung_in -= delta
	if _regung_in <= 0.0 and not _figuren.is_empty():
		_regung_in = randf_range(6.0, 10.0)
		var wer: Dictionary = _figuren[randi() % _figuren.size()]
		if wer["art"] == "brakk":
			blick()   # Brakk blickt kurz herüber
		else:
			wer["regung"] = 1.4
	_arm = UiBewegung.naeher(_arm, arm_ziel, delta, ARM_SEK)
	_blick_t = maxf(0.0, _blick_t - delta)
	for f: Dictionary in _figuren:
		var b: Sprite3D = f["b"]
		var r: float = f["regung"]
		f["regung"] = maxf(0.0, r - delta)
		b.scale = Vector3(1.0, 1.0 + 0.018 * sin(_zeit * 2.2 + float(f["phase"])), 1.0)
		if f["art"] == "brakk":
			# Ruhe: halb zum Horizont, Arm unten. Tafel offen: Arm hoch (Handfläche oben). Markieren: Kopf zur Liste.
			var n := int(f["bilder"])
			if _arm > 0.01 and n > BRAKK_HEBEN[2]:
				_bild_setzen(f, BRAKK_HEBEN[mini(2, int(_arm * 2.999))])
			elif _blick_t > 0.0 and n > BRAKK_BLICK:
				_bild_setzen(f, BRAKK_BLICK)
			else:
				_bild_setzen(f, int(_zeit * 6.0) % mini(9, n))
		else:
			var hop := 0.0
			if r > 0.0 and int(f["bilder"]) > 1:
				hop = sin((1.4 - r) / 1.4 * PI) * 0.12
				_bild_setzen(f, 1 + int(_zeit * 10.0) % (int(f["bilder"]) - 1))
			else:
				_bild_setzen(f, 0)
			b.position = (f["fuss"] as Vector3) + Vector3(0.0, hop, 0.0)


## Hintergrundspiel: Myriaden (Ausblick einzeln, Klippe in Trupps) laufen den Pfad entlang; an der Verteidigung schießen
## die Stellungen.
func _gegner_weiter(delta: float) -> void:
	_gegner_in -= delta
	if _gegner_in <= 0.0:
		_gegner_in = randf_range(_takt.x, _takt.y)
		for i in randi_range(_trupp.x, _trupp.y):
			_neuer_gegner(-1.1 * _mass * i)   # Trupp: einer hinter dem anderen (noch im HQ, bis weg ≥ 0)
	var naechster: Dictionary = {}
	var nah := INF
	for gg: Dictionary in _gegner.duplicate():
		var f: Dictionary = gg["f"]
		var b: Sprite3D = f["b"]
		if float(gg["tot"]) >= 0.0:
			# fällt: sackt zusammen und verblasst
			gg["tot"] = float(gg["tot"]) + delta
			var t := float(gg["tot"])
			b.scale = Vector3(1.0, lerpf(1.0, 0.25, minf(1.0, t / 0.35)), 1.0)
			b.modulate.a = clampf(1.4 - t, 0.0, 1.0)
			if t > 1.4:
				b.queue_free()
				_gegner.erase(gg)
			continue
		gg["weg"] = float(gg["weg"]) + GEGNER_TEMPO * _mass * delta
		b.visible = float(gg["weg"]) >= 0.0
		var lage := _auf_pfad(maxf(0.0, float(gg["weg"])))
		b.position = lage[0]
		b.flip_h = (lage[1] as Vector3).x < 0.0
		_bild_setzen(f, int(_zeit * 8.0 + float(f["phase"])))
		var d := Vector2(b.position.x - _vt.x, b.position.z - _vt.z).length()
		if bool(lage[2]) or int(gg["hp"]) <= 0:
			_faellt(gg)
		elif b.visible and d < SCHUSS_WEITE * _mass and d < nah:
			nah = d
			naechster = gg
	# Stellungen: Schuss auf den nächsten Gegner, Treffer kurz danach
	var blitz := 0.0
	for s: Dictionary in _stellungen:
		var f: Dictionary = s["f"]
		s["pause"] = float(s["pause"]) - delta
		s["schuss"] = maxf(0.0, float(s["schuss"]) - delta)
		_bild_setzen(f, 1 + int((0.3 - float(s["schuss"])) * 30.0) if float(s["schuss"]) > 0.0 else 0)
		blitz = maxf(blitz, float(s["schuss"]))
		if not naechster.is_empty() and float(s["pause"]) <= 0.0:
			s["pause"] = randf_range(0.7, 1.2)
			s["schuss"] = 0.3
			_effekt("muendung", (f["b"] as Sprite3D).position + Vector3(0, 0.45, 0) * _mass, 0.09)
			var ziel: Dictionary = naechster
			get_tree().create_timer(0.14, true, false, true).timeout.connect(func() -> void:
				if is_instance_valid((ziel["f"] as Dictionary)["b"]) and float(ziel["tot"]) < 0.0:
					ziel["hp"] = int(ziel["hp"]) - 1
					_effekt("treffer", ((ziel["f"] as Dictionary)["b"] as Sprite3D).position + Vector3(0, 0.4, 0) * _mass, 0.32))
	_vt_licht.light_energy = blitz * 6.0 * (0.25 + 0.75 * _nacht)


## Eine Myriade aus dem HQ (bzw. schon `weg` Felder unterwegs – beim Öffnen ist der Pfad nicht leer).
func _neuer_gegner(weg: float) -> void:
	var g: Array = GEGNER[randi() % GEGNER.size()]
	var f := _figur(str(g[0]) + ".png", _auf_pfad(maxf(0.0, weg))[0], float(g[1]) * _mass, false, "stellung")   # nicht in _figuren (eigener Ablauf)
	(f["b"] as Sprite3D).visible = weg >= 0.0
	_gegner.append({"f": f, "weg": weg, "hp": 3, "tot": -1.0})


func _pfad_laenge() -> float:
	var l := 0.0
	var punkte := _pfad.duplicate()
	punkte.append(_vt)
	for i in punkte.size() - 1:
		l += (punkte[i] as Vector3).distance_to(punkte[i + 1])
	return l


func _faellt(gg: Dictionary) -> void:
	gg["tot"] = 0.0
	var b: Sprite3D = (gg["f"] as Dictionary)["b"]
	b.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
	b.transparent = true


## [Ort, Richtung, am Ende] nach `weg` Feldern auf dem Pfad (HQ → Verteidigung).
func _auf_pfad(weg: float) -> Array:
	var punkte := _pfad.duplicate()
	punkte.append(_vt)
	for i in punkte.size() - 1:
		var a: Vector3 = punkte[i]
		var b: Vector3 = punkte[i + 1]
		var l := a.distance_to(b)
		if weg <= l:
			return [a.lerp(b, weg / l), b - a, false]
		weg -= l
	return [punkte[punkte.size() - 1], Vector3.RIGHT, true]


func _effekt(art: String, ort: Vector3, dauer: float) -> void:
	var k: Node3D
	if art == "treffer":
		var tex := _tex("treffer.png")
		var z := tex.get_height()
		var b := _sprite(tex, Rect2(0, 0, z, z), ort, 0.35 * _mass / float(z))
		b.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		b.centered = true
		b.offset = Vector2.ZERO
		k = b
	else:
		var m := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(0.22, 0.22) * _mass
		m.mesh = q
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		mat.albedo_color = Color(2.2, 1.7, 0.9)
		m.material_override = mat
		m.position = ort
		add_child(m)
		k = m
	_effekte.append({"k": k, "t": 0.0, "dauer": dauer, "art": art})


func _effekte_weiter(delta: float) -> void:
	for e: Dictionary in _effekte.duplicate():
		e["t"] = float(e["t"]) + delta
		var k: Node3D = e["k"]
		if float(e["t"]) >= float(e["dauer"]):
			k.queue_free()
			_effekte.erase(e)
		elif e["art"] == "treffer":
			var b := k as Sprite3D
			var z := b.texture.get_height()
			b.region_rect = Rect2(mini(3, int(float(e["t"]) / float(e["dauer"]) * 4.0)) * z, 0, z, z)


# ------------------------------------------------------------------ Shader

## Liest das Bild des SubViewports (TEXTURE), nicht den ganzen Bildschirm.
## `tiefe` > 0 (Klippe): Tiefenschärfe statt Tilt-Shift – scharf um `fokus` (Radien `fokus_r`), sonst weich; um `klar`
## (Radien `klar_r`, die ferne Verteidigung) nur leicht weich.
const POST_SHADER := """
shader_type canvas_item;
uniform float weich = 1.0;          // 0 = ohne Weichzeichnen (Handy/Tablet)
uniform float oben = 1.6;
uniform float unten = 1.4;
uniform float scharf_oben = 0.24;
uniform float scharf_unten = 0.9;
uniform float alles = 0.0;
uniform float dunkel = 0.0;
uniform float tusche = 0.0;
uniform float tiefe = 0.0;
uniform vec2 fokus = vec2(0.2, 0.66);
uniform vec2 fokus_r = vec2(0.24, 0.3);
uniform vec2 klar = vec2(0.8, 0.27);
uniform vec2 klar_r = vec2(0.22, 0.07);
void fragment() {
	float u;
	if (tiefe > 0.0) {
		float t = smoothstep(0.75, 1.6, length((UV - fokus) / fokus_r)) * tiefe;
		t *= mix(0.3, 1.0, smoothstep(0.6, 1.3, length((UV - klar) / klar_r)));
		u = (t + alles) * weich;
	} else {
		u = (smoothstep(scharf_oben, scharf_oben - 0.2, UV.y) * oben + smoothstep(scharf_unten, 1.0, UV.y) * unten + alles) * weich;
	}
	vec3 c = texture(TEXTURE, UV).rgb;
	if (u > 0.05) {
		vec3 s = c;
		float n = 17.0;
		for (int i = 0; i < 8; i++) {
			float w = float(i) * 0.785398 + 0.39;
			vec2 o = vec2(cos(w), sin(w)) * TEXTURE_PIXEL_SIZE * u;
			s += texture(TEXTURE, UV + o).rgb + texture(TEXTURE, UV + o * 2.0).rgb;
			if (tiefe > 0.0) {
				s += texture(TEXTURE, UV + o * 3.2 + o.yx * 0.6).rgb;
			}
		}
		if (tiefe > 0.0) {
			n = 25.0;
		}
		c = s / n;
		float g0 = dot(c, vec3(0.3, 0.59, 0.11));
		c = mix(c, vec3(g0) * vec3(0.92, 0.98, 1.04), clamp(u * 0.06, 0.0, 0.3));
	}
	float g = dot(c, vec3(0.3, 0.59, 0.11));
	c = mix(c, vec3(g) * vec3(1.08, 0.97, 0.80), tusche * 0.85);
	c = mix(c, c * c * 1.4, tusche * 0.3);
	c *= 1.0 - dunkel;
	vec2 p = UV - vec2(0.5, 0.52);
	p.x *= 1.35;
	float r = smoothstep(0.32, 0.78, length(p));
	c = mix(c * vec3(1.02, 1.0, 0.97), vec3(0.02, 0.05, 0.08), r * r * 0.62);
	COLOR = vec4(c, 1.0);
}
"""

## Boden: boden.png groß gezogen (4 Felder je Bild), weiche Farbflecken darüber – wirkt gemalt, kein Kachelraster.
const BODEN_SHADER := """
shader_type spatial;
render_mode cull_disabled;
uniform sampler2D boden : filter_nearest, repeat_enable;
uniform sampler2D flecken : filter_linear, repeat_enable;
varying vec3 welt;
void vertex() {
	welt = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	vec3 b = texture(boden, welt.xz * 0.25).rgb;
	float f1 = texture(flecken, welt.xz * 0.011).r;
	float f2 = texture(flecken, welt.xz * 0.047 + vec2(0.3, 0.7)).r;
	vec3 c = b * vec3(0.82, 0.86, 0.78) * mix(0.68, 1.2, f1) * mix(0.9, 1.08, f2);
	c = mix(c, c * vec3(1.06, 1.0, 0.82), smoothstep(0.55, 0.8, f1) * 0.5);   // trockene Flecken
	ALBEDO = c;
	ROUGHNESS = 1.0;
}
"""

## Fels (Klippe, Anhöhe): Seiten aus wall_seite.png grob gezogen und gefleckt, oben Moos an der Kante, nach unten dunkler;
## Oberseiten aus boden.png. Weltkoordinaten – kein Kachelraster an den Blockgrenzen.
const FELS_SHADER := """
shader_type spatial;
render_mode cull_disabled;
uniform sampler2D fels : filter_nearest, repeat_enable;
uniform sampler2D gras : filter_nearest, repeat_enable;
uniform sampler2D flecken : filter_linear, repeat_enable;
uniform float unten = -16.0;
varying vec3 welt;
void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	// zerklüften: Verschiebung nur nach dem Ort – an gemeinsamen Kanten gleich, also ohne Risse
	vec3 d = vec3(textureLod(flecken, w.zy * 0.05 + vec2(0.1, 0.3), 0.0).r - 0.5,
		textureLod(flecken, w.xz * 0.06 + vec2(0.7, 0.4), 0.0).r - 0.5,
		textureLod(flecken, w.xy * 0.05 + vec2(0.6, 0.2), 0.0).r - 0.5);
	vec3 d2 = vec3(textureLod(flecken, w.zy * 0.16 + vec2(0.5, 0.9), 0.0).r - 0.5, 0.0,
		textureLod(flecken, w.xy * 0.16 + vec2(0.2, 0.8), 0.0).r - 0.5);
	VERTEX += d * vec3(3.2, 1.0, 3.2) + d2 * 1.2;
	welt = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	vec3 wn = normalize(cross(dFdx(welt), dFdy(welt)));   // Facetten wie gehauener Stein
	vec3 nv = normalize((VIEW_MATRIX * vec4(wn, 0.0)).xyz);
	NORMAL = dot(nv, VIEW) < 0.0 ? -nv : nv;
	vec3 c;
	if (abs(wn.y) > 0.7) {
		float f1 = texture(flecken, welt.xz * 0.02).r;
		c = texture(gras, welt.xz * 0.25).rgb * vec3(0.8, 0.88, 0.72) * mix(0.72, 1.15, f1);
	} else {
		vec2 uv = abs(wn.x) > abs(wn.z) ? welt.zy : welt.xy;
		vec3 r = texture(fels, uv * vec2(0.3, 0.45)).rgb;
		float f = texture(flecken, uv * 0.035).r;
		float f2 = texture(flecken, uv * vec2(0.02, 0.16) + vec2(0.4, 0.1)).r;   // senkrechte Rinnen
		c = r * vec3(0.78, 0.68, 0.58) * mix(0.55, 1.15, f) * mix(0.8, 1.1, f2);
		float moos = smoothstep(0.45, 0.7, texture(flecken, uv * 0.11).r) * smoothstep(-4.0, 1.5, welt.y);
		c = mix(c, vec3(0.3, 0.4, 0.2), moos * 0.55);
		c *= mix(0.4, 1.0, smoothstep(unten, unten + 18.0, welt.y));   // nach unten dunkler
	}
	ALBEDO = c;
	ROUGHNESS = 1.0;
}
"""

## Himmel: Verlauf aus den Bildern himmel_abend.png / himmel_nacht.png, Wolken und Sterne im Code.
const HIMMEL_SHADER := """
shader_type spatial;
render_mode unshaded, fog_disabled, cull_disabled;
uniform sampler2D abend : filter_linear;
uniform sampler2D nacht_bild : filter_linear;
uniform vec4 wolke : source_color = vec4(0.94, 0.75, 0.63, 1.0);
uniform float nacht = 0.0;
uniform sampler2D rauschen : repeat_enable, filter_linear;
void fragment() {
	vec2 uv = floor(UV * vec2(560.0, 200.0)) / vec2(560.0, 200.0);   // grob gepixelt wie die Sprites
	float v = uv.y;
	vec3 c = mix(texture(abend, vec2(0.5, v)).rgb, texture(nacht_bild, vec2(0.5, v)).rgb, nacht);
	float w1 = texture(rauschen, uv * vec2(1.6, 1.0) + vec2(TIME * 0.0035, 0.0)).r;
	float w2 = texture(rauschen, uv * vec2(3.2, 2.0) + vec2(TIME * 0.008, 0.37)).r;
	float m1 = smoothstep(0.52, 0.66, w1) * smoothstep(0.78, 0.3, v);
	float m2 = smoothstep(0.58, 0.7, w2) * smoothstep(0.85, 0.45, v);
	c = mix(c, wolke.rgb * 0.92, m1 * 0.6);
	c = mix(c, wolke.rgb * 1.08, m2 * 0.5);
	vec2 zelle = floor(UV * vec2(700.0, 250.0));
	float stern = step(0.996, fract(sin(dot(zelle, vec2(12.9898, 78.233))) * 43758.5453));
	c += vec3(stern) * nacht * smoothstep(0.75, 0.1, v) * (0.6 + 0.4 * sin(TIME * 3.0 + zelle.x));
	ALBEDO = c;
}
"""
