class_name Ladebild
extends CanvasLayer
## Ladebild (17.11., Paul): Statt eines eingefrorenen Bildes beim Wechsel ins Hauptmenü oder beim Neustart zeigt
## es das Titelbild; das Logo füllt sich von unten wie eine Ladeleiste. Es hängt an der Wurzel des Baums und
## überlebt so das Neuladen der Szene: erst füllt es sich ein Stück, dann wird neu geladen (das Bild steht, solange
## die neue Szene aufbaut), danach meldet main.gd „fertig“, das Logo läuft voll und das Bild blendet aus.
##
## Benutzung: Ladebild.lade(get_tree()) statt get_tree().reload_current_scene(); main.gd ruft am Ende von _ready
## Ladebild.fertig().

const HINTERGRUND := "res://assets/neu/menue/kaserne.png"
const LOGO := "res://assets/neu/menue/logo.png"
const WELT := Vector2(640, 360)      # gezeichnet wird in der Menü-Auflösung, hochskaliert ohne Glättung
const LOGO_FAKTOR := 2.0             # wie auf dem Titelbild
const VOR_DEM_LADEN := 0.35          # Sekunden: so weit füllt es sich, bevor neu geladen wird ...
const STAND_VOR_DEM_LADEN := 0.6     # ... bis zu diesem Anteil
const NACH_DEM_LADEN := 0.45         # Sekunden: Rest auffüllen
const AUSBLENDEN := 0.3

static var _aktiv: Ladebild = null

var _tree: SceneTree
var _flaeche: Control
var _fuellung := 0.0
var _zeit := 0.0
var _phase := 0                      # 0 = vor dem Laden, 1 = lädt (Szene baut auf), 2 = fertig, läuft voll, 3 = blendet aus
var _alpha := 1.0
var _hg: Texture2D
var _logo: Texture2D


## Zeigt das Ladebild und lädt die aktuelle Szene neu.
static func lade(tree: SceneTree) -> void:
	if _aktiv != null and is_instance_valid(_aktiv):
		return   # lädt schon
	var l := Ladebild.new()
	l._tree = tree
	_aktiv = l
	tree.root.add_child(l)


## Die neue Szene steht: Logo voll laufen lassen und ausblenden.
static func fertig() -> void:
	if _aktiv != null and is_instance_valid(_aktiv) and _aktiv._phase <= 1:
		_aktiv._phase = 2
		_aktiv._zeit = 0.0


func _ready() -> void:
	layer = 128
	process_mode = Node.PROCESS_MODE_ALWAYS
	_hg = load(HINTERGRUND) if ResourceLoader.exists(HINTERGRUND) else null
	_logo = load(LOGO) if ResourceLoader.exists(LOGO) else null
	_flaeche = Control.new()
	_flaeche.mouse_filter = Control.MOUSE_FILTER_STOP   # solange es steht, geht kein Klick ins Spiel
	_flaeche.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_flaeche.draw.connect(_male)
	add_child(_flaeche)
	_passe_an()


func _passe_an() -> void:
	var g := get_viewport().get_visible_rect().size
	_flaeche.size = WELT
	_flaeche.scale = Vector2(g.x / WELT.x, g.y / WELT.y)


func _process(delta: float) -> void:
	var echt := delta / maxf(Engine.time_scale, 0.01)
	_zeit += echt
	match _phase:
		0:
			_fuellung = STAND_VOR_DEM_LADEN * clampf(_zeit / VOR_DEM_LADEN, 0.0, 1.0)
			if _zeit >= VOR_DEM_LADEN:
				_phase = 1
				_zeit = 0.0
				_tree.reload_current_scene.call_deferred()
		1:
			# Szene baut auf: langsam weiter, aber nie voll, bevor sie fertig ist
			_fuellung = lerpf(_fuellung, 0.9, clampf(echt * 0.8, 0.0, 1.0))
			if _zeit > 6.0:
				fertig()   # Sicherheit, falls „fertig“ nie kommt
		2:
			var start := _fuellung
			_fuellung = minf(1.0, start + echt * (1.0 - STAND_VOR_DEM_LADEN) / NACH_DEM_LADEN * 1.6)
			if _fuellung >= 1.0 and _zeit > 0.15:
				_phase = 3
				_zeit = 0.0
		3:
			_alpha = 1.0 - clampf(_zeit / AUSBLENDEN, 0.0, 1.0)
			_flaeche.mouse_filter = Control.MOUSE_FILTER_IGNORE
			if _alpha <= 0.0:
				if _aktiv == self:
					_aktiv = null
				queue_free()
				return
	_flaeche.modulate.a = _alpha
	_passe_an()
	_flaeche.queue_redraw()


func _male() -> void:
	var ci := _flaeche
	if _hg != null:
		ci.draw_texture_rect(_hg, Rect2(Vector2.ZERO, WELT), false)
	else:
		ci.draw_rect(Rect2(Vector2.ZERO, WELT), Color("10141c"))
	ci.draw_rect(Rect2(Vector2.ZERO, WELT), Color(0.03, 0.04, 0.06, 0.55))
	if _logo == null:
		# ohne Logo: schlichte Leiste
		var r := Rect2(WELT.x / 2.0 - 120.0, WELT.y / 2.0, 240.0, 6.0)
		ci.draw_rect(r, Color(0, 0, 0, 0.7))
		ci.draw_rect(Rect2(r.position, Vector2(r.size.x * _fuellung, r.size.y)), Color("7fe0ff"))
		return
	var ts := Vector2(_logo.get_size())
	var lg := (ts * LOGO_FAKTOR).round()
	var pos := ((WELT - lg) / 2.0 + Vector2(0, -12)).round()
	# leeres Logo: dunkel und entsättigt
	ci.draw_texture_rect(_logo, Rect2(pos, lg), false, Color(0.22, 0.24, 0.3, 0.9))
	# gefüllter Teil von unten nach oben, in ganzen Logopixeln
	var zeilen := floorf(ts.y * _fuellung)
	if zeilen > 0.0:
		var quelle := Rect2(0, ts.y - zeilen, ts.x, zeilen)
		var ziel := Rect2(pos.x, pos.y + lg.y - zeilen * LOGO_FAKTOR, lg.x, zeilen * LOGO_FAKTOR)
		ci.draw_texture_rect_region(_logo, ziel, quelle)
		# leuchtende Kante an der Füllhöhe
		if _fuellung < 1.0:
			ci.draw_rect(Rect2(pos.x, ziel.position.y - 1.0, lg.x, 1.0), Color(0.5, 0.9, 1.0, 0.55))
	# kleine Prozentleiste darunter
	var br := Rect2(WELT.x / 2.0 - 60.0, pos.y + lg.y + 14.0, 120.0, 3.0)
	ci.draw_rect(br, Color(0, 0, 0, 0.6))
	ci.draw_rect(Rect2(br.position, Vector2(br.size.x * _fuellung, br.size.y)), Color("7fe0ff"))
