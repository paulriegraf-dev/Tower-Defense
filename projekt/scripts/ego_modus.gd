class_name EgoModus
extends Node
## Ego-Sicht mit Brakk (18.11.2026, Prototyp) – [G] an/aus, nur in HD-2D.
## Die Kamera sitzt in Brakks Kopf; die Spiellogik bleibt die alte 2D-Logik, diese Datei steuert Brakk nur anders:
##   WASD gehen, Maus schauen, Linksklick schießen (zwei Pistolen im Wechsel), [Leertaste] springen,
##   zweimal [Leertaste] vor einem Erdwall: der Ring an der linken Hand wirft eine Lichttreppe, Brakk steigt hinauf.
##   Vom Wall herunter: über die Kante gehen oder zweimal [Leertaste] (18.11.). [Enter] startet die Welle.
##   Bauen wie immer über [1]–[8]: dann projiziert der Ring die Vorschau auf das Feld unter dem Fadenkreuz –
##   gebaut wird nur in Reichweite (BAU_REICHWEITE Felder um Brakk). Rechtsklick legt das Werkzeug weg.
##   [Alt] gedrückt halten gibt die Maus frei (für die Bauleiste).
## Die Mauern werden in diesem Modus höher (WAND_HOCH), damit man nicht über sie hinwegschaut.

const WAND_HOCH := 1.6          # Wandhöhe in Feldern während der Ego-Sicht (sonst 0,8)
const AUGE := 0.82              # Augenhöhe über den Füßen (Felder); Brakk selbst ist ein Feld groß
const TEMPO := 3.0              # Felder je Sekunde (Brakk läuft sonst 2,2 – zu Fuß fühlt sich das zäh an)
const KOERPER := 0.2            # halbe Breite für Zusammenstöße (Felder)
const BLICK := 0.0025           # Maus: Bogenmaß je Bildpunkt
const SPRUNG := 4.2             # Startgeschwindigkeit nach oben (Felder/s)
const SCHWERE := 13.0
const SCHUSS_TAKT := 0.28       # Sekunden zwischen zwei Schüssen (die Pistolen wechseln sich ab)
const SCHUSS_SCHADEN := 14.0
const SCHUSS_WEITE := 12.0      # Felder
const BAU_REICHWEITE := 5.0     # Felder
const SICHTWINKEL := 78.0
const Stil := preload("res://scripts/ui/ui_stil.gd")
const LICHT := Color("7fe0ff")
const SCHUSS := Color("8ff0ff")

var spiel: Node
var hd: HdAnsicht
var karte: Karte
var brakk: Kommandant

var gier := 0.0                 # Blick nach links/rechts (Bogenmaß, 0 = Blick nach Norden, also -z)
var nick := -0.05               # Blick nach oben/unten
var hoehe := 0.0                # Höhe der Füße über dem Boden (Felder)
var steig := 0.0                # senkrechte Geschwindigkeit
var _liegt := false             # 18.11.: Brakk-Mode – Brakk ist gefallen, die Kamera liegt am Boden
var _feuer := false
var _takt := 0.0
var _links_dran := false        # welche Pistole als Nächstes schießt
var _rueckstoss := [0.0, 0.0]   # je Pistole 0..1
var _blitz := [0.0, 0.0]
var _gang := 0.0                # Wippen beim Gehen
var _geht := false
var _alt_wh := 0.8
var _alt_fov := 50.0
var _hud_klapp := false         # war die Bauleiste vorher eingeklappt?
var treffer_zahl := 0           # für Tests: so oft getroffen
var _versteckt: Array = []      # Teile der Oberfläche, die in der Ego-Sicht im Weg sind (Sandbox-Tafel, Zoomregler)

# Lichttreppe
var _treppe: Node3D = null
var _klettern := -1.0           # läuft: Sekunden seit Beginn (-1 = nein)
var _kletter_von := Vector3.ZERO
var _kletter_nach := Vector3.ZERO
var _kletter_zelle := Karte.KEINE
var _treppe_fuss := Vector3.ZERO  # 18.11.: Fußpunkt der Treppe am Boden
var _abwaerts := false           # 18.11.: die Treppe führt gerade hinunter
var _treppe_rest := 0.0
const KLETTER_EINSTECKEN := 0.35   # 18.11.: länger – die Stufen bauen sich nacheinander auf, damit man die Treppe sieht
const KLETTER_STEIGEN := 0.75
const TREPPE_STUFEN := 6

# Ring (linke Hand): 0 = Pistole, 1 = Ring vorne
var _ring := 0.0
# 18.11.: Schussgefühl (game-feel): Wackeln aus abklingendem „Trauma“, Rückstoß der Sicht, Sichtfeld-Puls, Trefferkreuz,
# kurzes Einfrieren beim Kill. Alles in Echtzeit, damit es mit dem Spieltempo (0,7 … ×3) gleich wirkt.
const TRAUMA_ABBAU := 1.6       # je Sekunde
const WACKEL_WINKEL := 0.035    # Bogenmaß bei vollem Trauma
const STOP_KILL := 0.07         # Sekunden Einfrieren beim Kill
var _trauma := 0.0
var _wackel_t := 0.0
var _kick := 0.0                # Rückstoß der Sicht nach oben (Bogenmaß), federt zurück
var _fov_puls := 0.0            # Grad, die das Sichtfeld kurz enger wird
var _kreuz := 0.0               # Trefferkreuz: Restzeit
var _kreuz_kill := false
var _stop_id := 0
var _stop_vorher := -1.0        # Spieltempo vor dem Einfrieren (-1 = gerade kein Einfrieren)
var _uhr_vorher := 0             # Zeitpunkt des letzten Bilds (µs) für die Echtzeit

var _ebene: CanvasLayer
var _bild: Control
var _karte_klein: Control
var _tex_pistole: ImageTexture
var _tex_ring: ImageTexture
var _strahlen: Array = []       # [MeshInstance3D, Rest]
var _strahl_mat: StandardMaterial3D
var _bau_strahl: MeshInstance3D


func starten(p_spiel: Node) -> void:
	spiel = p_spiel
	hd = spiel.hd
	karte = spiel.karte
	brakk = spiel.kommandant
	process_priority = 50          # nach der HD-Ansicht: die Kamera setzen wir zuletzt
	hd.ego = self
	brakk.ego = true
	_alt_wh = hd.H
	_alt_fov = hd.kamera.fov
	hd.H = WAND_HOCH
	hd._wand_sig = ""             # Mauern neu bauen
	if hd._decke_mat != null:
		hd._decke_mat.no_depth_test = false   # Ringe und Effekte am Boden nicht mehr durch die Mauern
	hoehe = hd.H if brakk.oben else 0.0
	# Blick zum Gegner hin (nach links, die Gegner kommen von links)
	gier = PI / 2.0
	_strahl_mat = StandardMaterial3D.new()
	_strahl_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_strahl_mat.albedo_color = Color(SCHUSS, 0.9)
	_strahl_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_strahl_mat.emission_enabled = true
	_strahl_mat.emission = SCHUSS
	_strahl_mat.emission_energy_multiplier = 2.0
	_baue_oberflaeche()
	for n: String in ["_sandbox_leiste", "_zoom_grund"]:
		var c: Variant = spiel.get(n)
		if c is CanvasItem and is_instance_valid(c) and (c as CanvasItem).visible:
			_versteckt.append(c)
	_verstecke()
	# Die Bauleiste unten verdeckt die Sicht (Paul 18.11.): einklappen, links steht stattdessen eine schmale Liste
	_hud_klapp = spiel._hud.eingeklappt
	spiel._hud.eingeklappt = true
	spiel.melde("Brakk-Mode: WASD + Maus · Klick schießt · Leertaste springt · [E] Lichttreppe hinauf/hinunter · [F] Gebäude im Blick ausbauen · Enter startet die Welle" + ("" if spiel.brakk_modus else " · [G] zurück"), 10.0)


func beenden() -> void:
	if _stop_vorher >= 0.0:
		Engine.time_scale = _stop_vorher   # 18.11.: ein laufendes Einfrieren nicht hängen lassen
		_stop_vorher = -1.0
		_stop_id += 1
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if is_instance_valid(hd):
		hd.ego = null
		hd.H = _alt_wh
		hd._wand_sig = ""
		hd.kamera.fov = _alt_fov
		if hd._decke_mat != null:
			hd._decke_mat.no_depth_test = true
		# die Übersicht schaut dorthin, wo Brakk steht
		var p := _fuss3d()
		hd._tcx = p.x
		hd._tcz = p.z
		hd._cx = p.x
		hd._cz = p.z
	if is_instance_valid(spiel) and spiel._hud != null:
		spiel._hud.eingeklappt = _hud_klapp
	for c: Variant in _versteckt:
		if is_instance_valid(c):
			(c as CanvasItem).visible = true
	if is_instance_valid(brakk):
		brakk.ego = false
		brakk._sprite.bewegt(false)
	if _treppe != null:
		_treppe.queue_free()
	for s: Array in _strahlen:
		(s[0] as Node).queue_free()
	if _bau_strahl != null:
		_bau_strahl.queue_free()
	if _ebene != null:
		_ebene.queue_free()
	if is_instance_valid(spiel):
		spiel.ego = null
	queue_free()


# ------------------------------------------------------------------ Umrechnen

func _zu3d(p: Vector2, y: float) -> Vector3:
	return Vector3(p.x / Werte.ZELLE, y, (p.y - Werte.KARTE_OBEN) / Werte.ZELLE)


func _zu2d(v: Vector3) -> Vector2:
	return Vector2(v.x * Werte.ZELLE, v.z * Werte.ZELLE + Werte.KARTE_OBEN)


## Fußpunkt in 2D: oben auf dem Wall steht Brakk (wie im Spiel) 12 Bildpunkte über der Feldmitte.
func _fuss2d() -> Vector2:
	return brakk.position + (Vector2(0, 12) if brakk.oben else Vector2.ZERO)


func _fuss3d() -> Vector3:
	return _zu3d(_fuss2d(), hoehe)


func _vorne() -> Vector3:
	return Vector3(-sin(gier), 0.0, -cos(gier))


func _rechts() -> Vector3:
	return Vector3(cos(gier), 0.0, -sin(gier))


func _blick() -> Vector3:
	return -hd.kamera.global_transform.basis.z


func _boden() -> float:
	return hd.H if brakk.oben else 0.0


# ------------------------------------------------------------------ Eingabe

func _frei() -> bool:
	## Darf die Ego-Sicht gerade Maus und Tasten haben? (Pause, Menüs, Alt gedrückt: nein)
	if spiel.phase == 2:
		return false
	if spiel._hud != null and spiel._hud.pausiert():
		return false
	if spiel._fabrikmenue != null and spiel._fabrikmenue.visible:
		return false
	if spiel._lexikon != null and spiel._lexikon.visible:
		return false
	return not Input.is_key_pressed(KEY_ALT)


func _input(event: InputEvent) -> void:
	if not _frei():
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var m := event as InputEventMouseMotion
		gier -= m.relative.x * BLICK
		nick = clampf(nick - m.relative.y * BLICK, -1.25, 1.25)
		return
	if event is InputEventMouseButton:
		var b := event as InputEventMouseButton
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			return
		if b.button_index == MOUSE_BUTTON_LEFT:
			if spiel.werkzeug != Karte.FREI:
				# Bauen: nur in Reichweite – sonst geht der Klick nicht ans Spiel
				if b.pressed and not _in_reichweite(karte.zelle_bei(ziel_welt())):
					spiel.melde("Zu weit weg – geh näher heran (höchstens %d Felder)." % int(BAU_REICHWEITE), 2.5)
					get_viewport().set_input_as_handled()
				return
			_feuer = b.pressed
			get_viewport().set_input_as_handled()
		elif b.button_index == MOUSE_BUTTON_RIGHT and b.pressed:
			spiel.werkzeug = Karte.FREI   # Werkzeug weglegen (kein Abriss in der Ego-Sicht)
			get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match (event as InputEventKey).keycode:
			KEY_SPACE:
				_leertaste()
				get_viewport().set_input_as_handled()
			KEY_ENTER, KEY_KP_ENTER:
				spiel.starte_welle()
				get_viewport().set_input_as_handled()
			KEY_E:
				# 18.11. (Paul): [E] wirft die Lichttreppe – hinauf auf den Wall vor Brakk bzw. hinunter (statt 2× Leertaste)
				if _klettern < 0.0:
					if brakk.oben:
						_versuche_absteigen(true)
					else:
						_versuche_klettern(true)
				get_viewport().set_input_as_handled()
			KEY_F:
				# 18.11. (Paul): Gebäude im Blick ausbauen – öffnet dasselbe Menü wie ein Klick in der Übersicht
				var z := gebaeude_im_blick()
				if z != Karte.KEINE and spiel.werkzeug == Karte.FREI:
					spiel._oeffne_fabrikmenue(z)
					get_viewport().set_input_as_handled()


## 18.11.: Eigenes Gebäude unter dem Fadenkreuz in Bau-Reichweite (Fabrik, Batterie, Turm, Schildgenerator), sonst KEINE.
## Der Blick wird in kleinen Schritten abgetastet: das erste Feld mit einem Gebäude zählt.
func gebaeude_im_blick() -> Vector2i:
	var von := hd.kamera.global_position
	var r := _blick()
	var t := 0.3
	while t <= BAU_REICHWEITE + 1.0:
		var p := von + r * t
		if p.y < -0.05:
			break
		var z := karte.zelle_bei(_zu2d(p))
		if _ist_ausbaubar(z) and _in_reichweite(z):
			return z
		if hd.ist_hoch(z) and p.y <= hd.H and karte.ausbau.get(z, Karte.FREI) != Karte.TURM:
			break   # eine Mauer verdeckt alles dahinter
		t += 0.1
	return Karte.KEINE


func _ist_ausbaubar(z: Vector2i) -> bool:
	var was: int = karte.inhalt(z)
	return spiel.fabriken.has(z) or was == Karte.BATTERIE or was == Karte.GENERATOR or karte.ausbau.get(z, Karte.FREI) == Karte.TURM


func _gebaeude_name(z: Vector2i) -> String:
	if karte.ausbau.get(z, Karte.FREI) == Karte.TURM:
		return str(Werte.TURMARTEN.get(karte.turm_art.get(z, "geschuetz"), {}).get("name", "Turm"))
	match karte.inhalt(z):
		Karte.BATTERIE:
			return "Batterie"
		Karte.GENERATOR:
			return "Schildgenerator"
	if spiel.fabriken.has(z) and str(spiel.fabriken[z]["typ"]) == "pilot":
		return "Batterie"
	return "Fabrik"


## Leertaste springt nur noch (18.11.: Klettern liegt auf [E]).
func _leertaste() -> void:
	if _klettern >= 0.0:
		return
	if hoehe <= _boden() + 0.001:
		steig = SPRUNG


# ------------------------------------------------------------------ Ablauf

func _process(delta: float) -> void:
	if is_instance_valid(brakk) and brakk.gefallen and spiel.brakk_modus:
		# 18.11. (Paul): Im Brakk-Mode bleibt die Ego-Sicht – die Kamera liegt am Boden, bis Brakk zur nächsten Runde aufsteht
		if not _liegt:
			_liegt = true
			_feuer = false
			spiel.melde("Brakk ist gefallen – zur nächsten Runde steht er wieder auf.", 6.0)
		hoehe = move_toward(hoehe, -AUGE + 0.12, delta * 2.0)
		nick = move_toward(nick, 0.35, delta)
		_kamera()
		_bild.queue_redraw()
		return
	_liegt = false
	if not is_instance_valid(brakk) or brakk.gefallen:
		if is_instance_valid(spiel):
			spiel.melde("Brakk ist gefallen – zurück in der Übersicht. Zur nächsten Runde steht er wieder.", 5.0)
		beenden()
		return
	# 18.11.: Echtzeit direkt von der Uhr (das skalierte delta ist beim Einfrieren nicht verlässlich), höchstens 0,1 s je Bild
	var uhr := Time.get_ticks_usec()
	var echt := clampf((uhr - _uhr_vorher) / 1000000.0, 0.0, 0.1) if _uhr_vorher > 0 else delta
	_uhr_vorher = uhr
	var frei := _frei()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if frei else Input.MOUSE_MODE_VISIBLE
	_takt -= echt
	# 18.11.: Schussgefühl abklingen lassen (Echtzeit)
	_trauma = maxf(0.0, _trauma - TRAUMA_ABBAU * echt)
	_wackel_t += echt * 30.0
	_kick = lerpf(_kick, 0.0, 1.0 - exp(-12.0 * echt))
	_fov_puls = move_toward(_fov_puls, 0.0, echt * 30.0)
	_kreuz = maxf(0.0, _kreuz - echt)
	_treppe_rest -= echt
	for i in 2:
		_rueckstoss[i] = maxf(0.0, float(_rueckstoss[i]) - echt * 6.0)
		_blitz[i] = maxf(0.0, float(_blitz[i]) - echt)
	# Ring vor, wenn gebaut wird oder die Treppe läuft
	var ring_soll := 1.0 if (spiel.werkzeug != Karte.FREI or _klettern >= 0.0) else 0.0
	_ring = move_toward(_ring, ring_soll, echt * 6.0)
	if _klettern >= 0.0:
		_kletter_weiter(echt)
	else:
		_gehen(echt if frei else 0.0)
		_fallen(echt)
	if _feuer and frei and _takt <= 0.0 and _klettern < 0.0:
		_schiess()
	_kamera()
	_brakk_verstecken()
	_verstecke()
	_strahlen_weiter(echt)
	_treppe_weiter()
	_bau_strahl_weiter()
	_bild.queue_redraw()
	_karte_klein.queue_redraw()


func _gehen(dt: float) -> void:
	var r := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_W):
		r.y += 1.0
	if Input.is_physical_key_pressed(KEY_S):
		r.y -= 1.0
	if Input.is_physical_key_pressed(KEY_D):
		r.x += 1.0
	if Input.is_physical_key_pressed(KEY_A):
		r.x -= 1.0
	_geht = r != Vector2.ZERO and dt > 0.0
	brakk._sprite.bewegt(_geht)
	if not _geht:
		return
	r = r.normalized()
	var v := (_vorne() * r.y + _rechts() * r.x) * TEMPO * dt
	var schritt := Vector2(v.x, v.z) * Werte.ZELLE
	_schritt(Vector2(schritt.x, 0.0))
	_schritt(Vector2(0.0, schritt.y))
	if hoehe <= _boden() + 0.001:
		_gang += dt * 9.0


## Ein Stück gehen. Unten: alle vier Ecken auf begehbaren Feldern. Oben auf dem Wall: auf Wall-Feldern – wer über die
## Kante geht, springt hinunter (wenn unten Platz ist).
func _schritt(s: Vector2) -> void:
	if s == Vector2.ZERO:
		return
	var neu := _fuss2d() + s
	if brakk.oben:
		var z := karte.zelle_bei(neu)
		if hd.ist_hoch(z):
			_setze_fuss(neu)
			brakk.posten_zelle = z
			return
		# über die Kante: runter, wenn dort Platz ist
		if _passt_unten(neu):
			brakk.oben = false
			brakk.posten_zelle = Karte.KEINE
			brakk.zustand = Einheit.Zustand.BODEN
			brakk.e_rest = 0.5
			_setze_fuss(neu)   # die Höhe bleibt: Brakk fällt
		return
	if _passt_unten(neu):
		_setze_fuss(neu)


func _passt_unten(p: Vector2) -> bool:
	var k := KOERPER * Werte.ZELLE
	for e: Vector2 in [Vector2(-k, -k), Vector2(k, -k), Vector2(-k, k), Vector2(k, k)]:
		var z := karte.zelle_bei(p + e)
		if not karte.in_karte(z) or not karte.ist_begehbar(z):
			return false
	return true


func _setze_fuss(p: Vector2) -> void:
	brakk.position = p - (Vector2(0, 12) if brakk.oben else Vector2.ZERO)
	brakk.anker = brakk.position
	if absf(_rechts().x) > 0.01:
		brakk._sprite.flip_h = _vorne().x < 0.0


func _fallen(dt: float) -> void:
	var b := _boden()
	if hoehe > b or steig > 0.0:
		steig -= SCHWERE * dt
		hoehe += steig * dt
		if hoehe <= b:
			if steig < -3.0:
				_rueckstoss[0] = 0.5   # kleines Nachfedern beim Landen
				_rueckstoss[1] = 0.5
			hoehe = b
			steig = 0.0
	else:
		hoehe = b


func _kamera() -> void:
	var k := hd.kamera
	k.fov = SICHTWINKEL
	k.near = 0.05
	var wippen := sin(_gang) * 0.025 if _geht and hoehe <= _boden() + 0.001 else 0.0
	k.position = _fuss3d() + Vector3(0, AUGE + wippen, 0)
	# 18.11.: Rückstoß hebt die Sicht kurz an, Wackeln aus Trauma² mit überlagerten Sinuswellen (kein Zittern)
	var w2 := _trauma * _trauma
	k.rotation = Vector3(nick + _kick + WACKEL_WINKEL * w2 * sin(_wackel_t * 1.7), gier + WACKEL_WINKEL * w2 * sin(_wackel_t * 2.3),
		WACKEL_WINKEL * 0.6 * w2 * sin(_wackel_t * 1.1))
	k.fov = SICHTWINKEL - _fov_puls
	var w: float = spiel.effekte.wackeln
	if w > 0.0:
		k.position += Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), 0.0) * w / Werte.ZELLE * 0.4


## Brakks eigenes Bild (und sein Lebensbalken) wäre direkt vor der Kamera: ausblenden.
func _brakk_verstecken() -> void:
	for n: Node in brakk.find_children("*", "Sprite2D", true, false):
		var id := n.get_instance_id()
		var b: Node3D = hd._bilder.get(id)
		if b != null:
			b.visible = false
		var u: Node3D = hd._umrisse.get(id)
		if u != null:
			u.visible = false
		if hd._balken.has(id):
			for m: Node3D in hd._balken[id]:
				m.visible = false
	var s: Node3D = hd._bilder.get(brakk._sprite.get_instance_id())
	if s != null:
		s.visible = false


## Sandbox-Tafel und Zoomregler: das Spiel blendet sie laufend wieder ein – in der Ego-Sicht jedes Bild aus.
func _verstecke() -> void:
	for c: Variant in _versteckt:
		if is_instance_valid(c):
			(c as CanvasItem).visible = false


# ------------------------------------------------------------------ Zielen

## Strahl durch das Fadenkreuz: Abstand bis zur ersten Mauer, Fabrik oder zum Boden (Felder), höchstens `weite`.
func _strahl_bis(von: Vector3, r: Vector3, weite: float) -> float:
	var eigene := karte.zelle_bei(_fuss2d()) if brakk.oben else Karte.KEINE
	var t := 0.0
	while t < weite:
		var p := von + r * t
		if p.y <= 0.0:
			return t
		var z := Vector2i(floori(p.x), floori(p.z))
		if z != eigene:
			if hd.ist_hoch(z) and p.y <= hd.H:
				return t
			if karte.inhalt(z) == Karte.FABRIK and p.y <= 1.1:
				return t
		t += 0.04
	return weite


## Punkt unter dem Fadenkreuz in der 2D-Logik (für Bauen, Q, R): Mauerkrone oder Boden.
func ziel_welt(nur_boden: bool = false) -> Vector2:
	var von := hd.kamera.global_position
	var r := _blick()
	if r.y >= -0.01:
		return Vector2(-9999, -9999)
	if not nur_boden:
		var t := _strahl_bis(von, r, 30.0)
		var p := von + r * t
		var z := Vector2i(floori(p.x), floori(p.z))
		if hd.ist_hoch(z):
			return _zu2d(p)
	var tb := (0.0 - von.y) / r.y
	return _zu2d(von + r * tb)


func _in_reichweite(z: Vector2i) -> bool:
	return Vector2(z).distance_to(Vector2(karte.zelle_bei(_fuss2d()))) <= BAU_REICHWEITE


# ------------------------------------------------------------------ Schießen

func _schiess() -> void:
	_takt = SCHUSS_TAKT
	var seite := 0 if _links_dran else 1
	if _ring > 0.5:
		seite = 1   # linke Hand trägt den Ring: nur rechts
	_links_dran = not _links_dran
	_rueckstoss[seite] = 1.0
	_blitz[seite] = 0.06
	var von := hd.kamera.global_position
	var r := _blick()
	var bis := _strahl_bis(von, r, SCHUSS_WEITE)
	var bester: Gegner = null
	var beste := bis
	for g: Gegner in spiel.gegner:
		if not is_instance_valid(g) or g._tot:
			continue
		var c := _zu3d(g.position, (hd.H if hd.ist_hoch(karte.zelle_bei(g.position)) else 0.0) + 0.42)
		var t := (c - von).dot(r)
		if t <= 0.0 or t >= beste:
			continue
		if (von + r * t).distance_to(c) <= 0.34:
			beste = t
			bester = g
	var ende := von + r * beste
	var muendung := von + _blick() * 0.5 + _rechts() * (0.16 if seite == 1 else -0.16) - Vector3(0, 0.14, 0)
	_strahl(muendung, ende)
	# 18.11.: Schuss – eigener PixelLab-Klang je Pistole (links A, rechts B), dazu Rückstoß und Sichtfeld-Puls
	Ton.spiele(spiel, "brakk-schuss-a" if seite == 0 else "brakk-schuss-b")   # 18.11.: eigene Schussklänge je Pistole (PixelLab)
	_kick += 0.022
	_fov_puls = maxf(_fov_puls, 1.6)
	_trauma = minf(1.0, _trauma + 0.08)
	if bester != null:
		spiel.schadensquelle = "fabrik:-1,-1"
		spiel.schuss_herkunft = brakk.position
		bester.nimm_schaden(SCHUSS_SCHADEN)
		treffer_zahl += 1
		spiel.schadensquelle = ""
		spiel.schuss_herkunft = Vector2.INF
		_treffer_gefuehl(ende, bester._tot)


## 18.11.: Treffer (mittel) und Kill (groß) fühlbar machen.
func _treffer_gefuehl(wo: Vector3, kill: bool) -> void:
	_kreuz = 0.28 if kill else 0.14
	_kreuz_kill = kill
	_funke(wo, 0.16 if kill else 0.1)
	if kill:
		Ton.spiele(spiel, "brakk-kill")
		Ton.spiele(spiel, "hit-pboom", -4.0)   # tiefer Knall darunter
		_trauma = minf(1.0, _trauma + 0.4)
		_fov_puls = maxf(_fov_puls, 4.0)
		_einfrieren(STOP_KILL)
	else:
		Ton.spiele(spiel, "brakk-treffer")
		_trauma = minf(1.0, _trauma + 0.16)


func _funke(wo: Vector3, radius: float) -> void:
	var f := MeshInstance3D.new()
	var kugel := SphereMesh.new()
	kugel.radius = radius
	kugel.height = radius * 2.0
	f.mesh = kugel
	f.material_override = _strahl_mat.duplicate()
	hd.add_child(f)
	f.position = wo
	_strahlen.append([f, 0.14])


## Kurzes Einfrieren (Hit-Stop) in Echtzeit; nur der jüngste Aufruf stellt das Spieltempo wieder her.
func _einfrieren(dauer: float) -> void:
	_stop_id += 1
	var meins := _stop_id
	if _stop_vorher < 0.0:
		_stop_vorher = Engine.time_scale
	Engine.time_scale = _stop_vorher * 0.05
	await get_tree().create_timer(dauer, true, false, true).timeout
	if meins == _stop_id:
		Engine.time_scale = _stop_vorher
		_stop_vorher = -1.0


func _strahl(a: Vector3, b: Vector3) -> void:
	var m := MeshInstance3D.new()
	var box := BoxMesh.new()
	var lang := maxf(0.01, a.distance_to(b))
	box.size = Vector3(0.025, 0.025, lang)
	m.mesh = box
	m.material_override = _strahl_mat.duplicate()
	hd.add_child(m)
	m.position = (a + b) / 2.0
	if lang > 0.02:
		m.look_at_from_position(m.position, b, Vector3.UP if absf((b - a).normalized().y) < 0.99 else Vector3.RIGHT)
	_strahlen.append([m, 0.09])
	# Funke am Ende
	var f := MeshInstance3D.new()
	var kugel := SphereMesh.new()
	kugel.radius = 0.06
	kugel.height = 0.12
	f.mesh = kugel
	f.material_override = _strahl_mat.duplicate()
	hd.add_child(f)
	f.position = b
	_strahlen.append([f, 0.12])


func _strahlen_weiter(dt: float) -> void:
	var noch: Array = []
	for s: Array in _strahlen:
		s[1] = float(s[1]) - dt
		var m: MeshInstance3D = s[0]
		if float(s[1]) <= 0.0:
			m.queue_free()
			continue
		var mat := m.material_override as StandardMaterial3D
		mat.albedo_color.a = clampf(float(s[1]) / 0.1, 0.0, 1.0)
		noch.append(s)
	_strahlen = noch


# ------------------------------------------------------------------ Klettern mit der Lichttreppe

## Steht vor Brakk (in Blickrichtung, bis 1 Feld) ein Erdwall? Dann wirft der Ring eine Treppe und er steigt hinauf.
func _versuche_klettern(melden: bool) -> bool:
	if brakk.e_rest > 0.0:
		if melden:
			spiel.melde("Lichttreppe wieder in %.0f s." % ceilf(brakk.e_rest), 2.0)
		return false
	var fuss := _fuss2d()
	var v := _vorne()
	var ziel := Karte.KEINE
	for d: float in [0.45, 0.75, 1.05]:
		var z := karte.zelle_bei(fuss + Vector2(v.x, v.z) * d * Werte.ZELLE)
		if hd.ist_hoch(z):
			ziel = z
			break
	if ziel == Karte.KEINE:
		if melden:
			spiel.melde("Kein Erdwall direkt vor Brakk.", 2.0)
		return false
	_kletter_zelle = ziel
	_kletter_von = _fuss3d()
	_kletter_nach = _zu3d(karte.mitte(ziel), hd.H)
	_treppe_fuss = _kletter_von
	_abwaerts = false
	_klettern = 0.0
	steig = 0.0
	_baue_treppe()
	Ton.spiele(spiel, "ui-klick", -6.0)
	return true


## 18.11. (Paul): [E] auf dem Wall – die Lichttreppe führt hinunter auf das freie Feld in Blickrichtung (sonst auf
## irgendein freies Nachbarfeld), genauso sichtbar wie beim Hinaufsteigen.
func _versuche_absteigen(melden: bool) -> bool:
	if brakk.e_rest > 0.0:
		if melden:
			spiel.melde("Lichttreppe wieder in %.0f s." % ceilf(brakk.e_rest), 2.0)
		return false
	var fuss := _fuss2d()
	var v := _vorne()
	var hier := karte.zelle_bei(fuss)
	var kandidaten: Array[Vector2] = [fuss + Vector2(v.x, v.z) * Werte.ZELLE, fuss + Vector2(v.x, v.z) * 1.3 * Werte.ZELLE]
	for n: Vector2i in Karte.NACHBARN:
		kandidaten.append(karte.mitte(hier + n))
	for p: Vector2 in kandidaten:
		if hd.ist_hoch(karte.zelle_bei(p)) or not _passt_unten(p):
			continue
		_kletter_zelle = hier
		_kletter_von = _fuss3d()
		_kletter_nach = _zu3d(p, 0.0)
		_treppe_fuss = _kletter_nach
		_abwaerts = true
		brakk.oben = false   # ab jetzt zählt er als am Boden (die 2D-Logik), die Kamera steigt die Treppe hinab
		brakk.posten_zelle = Karte.KEINE
		brakk.zustand = Einheit.Zustand.BODEN
		_klettern = 0.0
		steig = 0.0
		_baue_treppe()
		Ton.spiele(spiel, "ui-klick", -6.0)
		return true
	if melden:
		spiel.melde("Kein freies Feld zum Hinuntersteigen.", 2.0)
	return false


func _kletter_weiter(dt: float) -> void:
	_klettern += dt
	# 18.11.: die Stufen erscheinen nacheinander, vom Boden zur Krone – so sieht man die Treppe entstehen
	if _treppe != null:
		var stufen := _treppe.get_children()
		for i in stufen.size():
			(stufen[i] as Node3D).visible = _klettern >= KLETTER_EINSTECKEN * float(i) / float(stufen.size())
	if _klettern < KLETTER_EINSTECKEN:
		return
	var f := clampf((_klettern - KLETTER_EINSTECKEN) / KLETTER_STEIGEN, 0.0, 1.0)
	var weich := f * f * (3.0 - 2.0 * f)
	var p := _kletter_von.lerp(_kletter_nach, weich)
	hoehe = lerpf(_kletter_von.y, _kletter_nach.y, minf(1.0, weich * 1.15))
	_gang += dt * 12.0
	_geht = true
	if f >= 1.0 and _abwaerts:
		# unten angekommen
		_klettern = -1.0
		_abwaerts = false
		brakk.e_rest = float(brakk.daten["kletter_abklingzeit"])
		_setze_fuss(_zu2d(_kletter_nach))
		hoehe = 0.0
		_treppe_rest = 0.8
		return
	if f >= 1.0:
		# oben: wie [E] im Spiel
		_klettern = -1.0
		brakk.oben = true
		brakk.posten_zelle = _kletter_zelle
		brakk.zustand = Einheit.Zustand.AUF_POSTEN
		brakk.e_rest = float(brakk.daten["kletter_abklingzeit"])
		brakk.position = karte.mitte(_kletter_zelle) + Vector2(0, -12)
		brakk.anker = brakk.position
		hoehe = hd.H
		_treppe_rest = 0.8
		spiel.melde("Brakk steht auf dem Wall: mehr Reichweite. [E] = Lichttreppe hinunter, oder über die Kante springen.", 3.0)
		return
	var p2 := _zu2d(p)
	brakk.position = p2


func _baue_treppe() -> void:
	if _treppe != null:
		_treppe.queue_free()
	_treppe = Node3D.new()
	hd.add_child(_treppe)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(LICHT, 0.5)
	mat.emission_enabled = true
	mat.emission = LICHT
	mat.emission_energy_multiplier = 1.4
	var rand := mat.duplicate() as StandardMaterial3D
	rand.albedo_color = Color(LICHT, 0.95)
	var von := _treppe_fuss   # 18.11.: Fußpunkt der Treppe am Boden (hinauf: wo Brakk steht, hinunter: wo er landet)
	var nach := _zu3d(karte.mitte(_kletter_zelle), 0.0)
	# Stufen von Brakk bis an die Wand, die oberste reicht an die Krone
	var r := Vector3(nach.x - von.x, 0.0, nach.z - von.z)
	var lang := maxf(0.3, r.length() - 0.5)
	r = r.normalized()
	for i in TREPPE_STUFEN:
		var a := float(i + 1) / float(TREPPE_STUFEN)
		var stufe := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.55, 0.05, lang / TREPPE_STUFEN + 0.04)
		stufe.mesh = box
		stufe.material_override = mat
		_treppe.add_child(stufe)
		stufe.position = Vector3(von.x, 0.0, von.z) + r * (lang * (float(i) + 0.5) / TREPPE_STUFEN) + Vector3(0, hd.H * a, 0)
		stufe.rotation.y = atan2(r.x, r.z)
		var kante := MeshInstance3D.new()
		var kb := BoxMesh.new()
		kb.size = Vector3(0.58, 0.012, 0.012)
		kante.mesh = kb
		kante.material_override = rand
		stufe.add_child(kante)
		kante.position = Vector3(0, 0.03, -box.size.z / 2.0)
	_treppe.set_meta("mats", [mat, rand])
	_treppe_rest = 99.0


func _treppe_weiter() -> void:
	if _treppe == null or _klettern >= 0.0:
		return
	if _treppe_rest <= 0.0:
		_treppe.queue_free()
		_treppe = null
		return
	if _treppe_rest < 0.8:
		for m: StandardMaterial3D in (_treppe.get_meta("mats") as Array):
			m.albedo_color.a = clampf(_treppe_rest / 0.8, 0.0, 1.0) * (0.5 if m.albedo_color.a < 0.9 else 0.95)


# ------------------------------------------------------------------ Bauen: Ring projiziert

func _bau_strahl_weiter() -> void:
	var an: bool = spiel.werkzeug != Karte.FREI and _ring > 0.9
	if not an:
		if _bau_strahl != null:
			_bau_strahl.visible = false
		return
	var ziel := ziel_welt()
	if ziel.x < -9000.0:
		if _bau_strahl != null:
			_bau_strahl.visible = false
		return
	var z := karte.zelle_bei(ziel)
	var nah := _in_reichweite(z)
	if _bau_strahl == null:
		_bau_strahl = MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.012, 0.012, 1.0)
		_bau_strahl.mesh = box
		var mat := _strahl_mat.duplicate() as StandardMaterial3D
		_bau_strahl.material_override = mat
		hd.add_child(_bau_strahl)
	_bau_strahl.visible = true
	var mat2 := _bau_strahl.material_override as StandardMaterial3D
	mat2.albedo_color = Color(LICHT if nah else Color("ff5a6e"), 0.35)
	var hand := hd.kamera.global_position + _blick() * 0.45 - _rechts() * 0.2 - Vector3(0, 0.16, 0)
	var dort := _zu3d(karte.mitte(z), (hd.H if hd.ist_hoch(z) else 0.0) + 0.02)
	var lang := hand.distance_to(dort)
	_bau_strahl.scale = Vector3(1, 1, lang)
	_bau_strahl.position = (hand + dort) / 2.0
	_bau_strahl.look_at_from_position(_bau_strahl.position, dort, Vector3.UP)


# ------------------------------------------------------------------ Oberfläche: Waffen, Fadenkreuz, Minikarte

func _baue_oberflaeche() -> void:
	_tex_pistole = ImageTexture.create_from_image(_male_pistole())
	_tex_ring = ImageTexture.create_from_image(_male_ringhand())
	_ebene = CanvasLayer.new()
	_ebene.layer = 2
	add_child(_ebene)
	_bild = Control.new()
	_bild.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bild.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bild.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_bild.draw.connect(_male_bild)
	_ebene.add_child(_bild)
	_karte_klein = Control.new()
	_karte_klein.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_karte_klein.set_anchors_preset(Control.PRESET_FULL_RECT)
	_karte_klein.draw.connect(_male_minikarte)
	_ebene.add_child(_karte_klein)


func _male_bild() -> void:
	var g := _bild.get_viewport_rect().size
	var px := maxf(2.0, floorf(g.y / 150.0))          # ein Bildpunkt der Waffe in Bildschirmpunkten
	var ts := Vector2(_tex_pistole.get_size()) * px
	var wipp := Vector2(cos(_gang * 0.5) * 3.0, absf(sin(_gang * 0.5)) * 4.0) if _geht else Vector2.ZERO
	# rechte Pistole
	var r_rueck := float(_rueckstoss[1])
	var r_pos := Vector2(g.x * 0.80 - ts.x * 0.5, g.y - ts.y + 12.0 * px) + wipp + Vector2(r_rueck * 2.0, r_rueck * 6.0) * px
	_waffe(_tex_pistole, r_pos, ts, -NEIGUNG, float(_blitz[1]) > 0.0, px, false)
	# linke Hand: Pistole (gespiegelt) oder Ring – beim Wechsel taucht die eine ab und die andere auf
	var l_rueck := float(_rueckstoss[0])
	var ab := clampf(_ring * 2.0, 0.0, 1.0)              # Pistole sinkt
	var auf := clampf(_ring * 2.0 - 1.0, 0.0, 1.0)       # Ring kommt
	var l_basis := Vector2(g.x * 0.20 - ts.x * 0.5, g.y - ts.y + 12.0 * px) + Vector2(-wipp.x, wipp.y)
	if ab < 1.0:
		var lp := l_basis + Vector2(-l_rueck * 2.0, l_rueck * 6.0) * px + Vector2(0, ab * ts.y)
		_waffe(_tex_pistole, lp, ts, NEIGUNG, float(_blitz[0]) > 0.0, px, true)
	if auf > 0.0:
		var rs := Vector2(_tex_ring.get_size()) * px
		var rp := Vector2(g.x * 0.22 - rs.x * 0.5, g.y - rs.y + 4.0 * px) + Vector2(-wipp.x, wipp.y) + Vector2(0, (1.0 - auf) * rs.y)
		_bild.draw_texture_rect(_tex_ring, Rect2(rp.round(), rs), false)
		# Ring leuchtet (pulsiert)
		var puls := 0.6 + 0.4 * sin(Time.get_ticks_msec() / 120.0)
		var mitte := rp + Vector2(15.5, 15.0) * px
		_bild.draw_circle(mitte, 5.0 * px, Color(LICHT, 0.18 * puls * auf))
		_bild.draw_circle(mitte, 2.5 * px, Color(LICHT, 0.35 * puls * auf))
	if _frei():   # 18.11.: bei offenem Menü kein Fadenkreuz und kein Hinweis darüber
		_fadenkreuz(g, px)
	_bauliste(g)
	# Zustandszeile unten in der Mitte
	if _klettern >= 0.0:
		Stil.schreibe_mittig(_bild, Vector2(g.x / 2.0, g.y * 0.62), "Lichttreppe", 18, LICHT)


const NEIGUNG := 0.2   # die Pistolen zeigen leicht nach innen, zum Fadenkreuz


## Eine Pistole zeichnen: um ihre untere Mitte geneigt, links gespiegelt; Mündungsblitz an der Spitze.
func _waffe(tex: Texture2D, pos: Vector2, ts: Vector2, winkel: float, blitz: bool, px: float, spiegeln: bool) -> void:
	var dreh := pos.round() + Vector2(ts.x / 2.0, ts.y)
	_bild.draw_set_transform(dreh, winkel, Vector2(-1.0 if spiegeln else 1.0, 1.0))
	_bild.draw_texture_rect(tex, Rect2(Vector2(-ts.x / 2.0, -ts.y), ts), false)
	if blitz:
		_muendungsblitz(Vector2(-1.0 * px, -ts.y + 1.0 * px), px)
	_bild.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Schmale Bauliste am linken Rand (statt der Leiste unten): Taste, Name, Preis; das gewählte Werkzeug leuchtet.
func _bauliste(g: Vector2) -> void:
	if spiel.phase != 0 and spiel.werkzeug == Karte.FREI:
		return   # im Kampf freie Sicht
	var zeile := 34.0
	var breite := 210.0
	var eintraege: Array = []
	for k: Array in spiel._hud.KACHELN:
		if int(k[0]) != Karte.KOMMANDANT:
			eintraege.append(k)
	var oben := (g.y - zeile * eintraege.size()) / 2.0
	var x := 14.0
	var hinter := Rect2(x - 6.0, oben - 8.0, breite + 12.0, zeile * eintraege.size() + 16.0)
	_bild.draw_rect(hinter, Color(0.04, 0.05, 0.08, 0.55))
	var bau: bool = spiel.phase == 0 or spiel.endkampf
	for i in eintraege.size():
		var k: Array = eintraege[i]
		var typ := int(k[0])
		var preis: int = spiel.kosten(typ)
		var geht: bool = (bau or spiel.darf_in_welle(typ)) and (typ == Karte.FABRIK or spiel.alles_frei()) and spiel.herausforderung_sperrt(typ) == ""
		var r := Rect2(x, oben + i * zeile, breite, zeile - 4.0)
		var gewaehlt: bool = spiel.werkzeug == typ
		if gewaehlt:
			_bild.draw_rect(r, Color(LICHT, 0.18))
			_bild.draw_rect(r, LICHT, false, 2.0)
		var farbe := Color.WHITE if gewaehlt else (Stil.TEXT if geht else Stil.TEXT_BLASS)
		var m := r.get_center().y
		Stil.schreibe(_bild, Vector2(r.position.x + 8.0, m), str(k[2]), 18, LICHT if geht else Stil.TEXT_BLASS)
		Stil.schreibe(_bild, Vector2(r.position.x + 32.0, m), str(k[3]), 18, farbe)
		var p := "" if typ == Karte.TURM else str(preis)
		if typ == Karte.WALL and spiel.freie_waelle > 0:
			p = "×%d" % spiel.freie_waelle
		var pf := Stil.GOLD if spiel.budget >= preis else Stil.WARN
		Stil.schreibe(_bild, Vector2(r.end.x - 8.0 - Stil.breite(p, 18), m), p, 18, pf if geht else Stil.TEXT_BLASS)
	Stil.schreibe(_bild, Vector2(x, hinter.end.y + 14.0), "Rechtsklick: weglegen", 16, Stil.TEXT_BLASS)


func _muendungsblitz(p: Vector2, px: float) -> void:
	var s := px * 3.0
	_bild.draw_rect(Rect2(p - Vector2(s, s * 0.35), Vector2(s * 2.0, s * 0.7)), Color(SCHUSS, 0.9))
	_bild.draw_rect(Rect2(p - Vector2(s * 0.35, s), Vector2(s * 0.7, s * 2.0)), Color(SCHUSS, 0.9))
	_bild.draw_rect(Rect2(p - Vector2(s * 0.5, s * 0.5), Vector2(s, s)), Color.WHITE)


func _fadenkreuz(g: Vector2, px: float) -> void:
	var m := (g / 2.0).round()
	if spiel.werkzeug != Karte.FREI:
		var ziel := ziel_welt()
		var nah := ziel.x > -9000.0 and _in_reichweite(karte.zelle_bei(ziel))
		var f := LICHT if nah else Color("ff5a6e")
		var s := 6.0 * px
		_bild.draw_rect(Rect2(m - Vector2(s, s), Vector2(s * 2.0, s * 2.0)), f, false, px * 0.5)
		if not nah:
			Stil.schreibe_mittig(_bild, m + Vector2(0, s + 10.0 * px), "zu weit", 18, f)
		return
	var gb := gebaeude_im_blick()   # 18.11.: Hinweis zum Ausbauen
	if gb != Karte.KEINE:
		Stil.schreibe_mittig(_bild, m + Vector2(0, 12.0 * px), "[F] %s ausbauen" % _gebaeude_name(gb), 18, LICHT)
	var l := 3.0 * px
	var lucke := 2.0 * px
	var d := px * 0.6
	var farbe := Color(LICHT, 0.9)
	_bild.draw_rect(Rect2(m.x - lucke - l, m.y - d / 2.0, l, d), farbe)
	_bild.draw_rect(Rect2(m.x + lucke, m.y - d / 2.0, l, d), farbe)
	_bild.draw_rect(Rect2(m.x - d / 2.0, m.y - lucke - l, d, l), farbe)
	_bild.draw_rect(Rect2(m.x - d / 2.0, m.y + lucke, d, l), farbe)
	# 18.11.: Trefferkreuz – weiß bei Treffer, rot und größer beim Kill
	if _kreuz > 0.0:
		var kf := Color("ff4a5a") if _kreuz_kill else Color.WHITE
		kf.a = clampf(_kreuz / 0.12, 0.0, 1.0)
		var a := (4.0 if _kreuz_kill else 3.0) * px
		var b := a + (4.0 if _kreuz_kill else 3.0) * px
		for s: Vector2 in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
			_bild.draw_line(m + s * a, m + s * b, kf, px * (0.9 if _kreuz_kill else 0.7))


func _male_minikarte() -> void:
	var g := _karte_klein.get_viewport_rect().size
	var zelle := floorf(minf(g.x * 0.16 / Werte.SPALTEN, 7.0))
	zelle = maxf(zelle, 3.0)
	var gross := Vector2(Werte.SPALTEN, Werte.ZEILEN) * zelle
	var o := Vector2(g.x - gross.x - 16.0, 64.0).round()
	var ci := _karte_klein
	ci.draw_rect(Rect2(o - Vector2(4, 4), gross + Vector2(8, 8)), Color(0.04, 0.05, 0.08, 0.95))
	ci.draw_rect(Rect2(o - Vector2(4, 4), gross + Vector2(8, 8)), Color(LICHT, 0.35), false, 1.0)
	for z: Vector2i in karte.feld:
		var typ: int = karte.feld[z]
		var f := Color("8b95a3")
		if typ == Karte.FABRIK:
			f = Color("e08a4f")
		elif typ != Karte.WALL:
			f = Color("5d6573")
		if karte.ausbau.get(z, Karte.FREI) == Karte.TURM:
			f = Color("c9a6ff")
		ci.draw_rect(Rect2(o + Vector2(z) * zelle, Vector2(zelle, zelle)), f)
	if karte.basis != Karte.KEINE:
		ci.draw_rect(Rect2(o + Vector2(karte.basis) * zelle, Vector2(zelle, zelle)), LICHT)
	var k := zelle / float(Werte.ZELLE)
	for gg: Gegner in spiel.gegner:
		if is_instance_valid(gg) and not gg._tot:
			var p := o + Vector2(gg.position.x, gg.position.y - Werte.KARTE_OBEN) * k
			ci.draw_rect(Rect2(p - Vector2(1.5, 1.5), Vector2(3, 3)), Color("ff5a6e"))
	# Brakk: Pfeil in Blickrichtung, beim Bauen der Reichweitenkreis
	var b := o + Vector2(_fuss2d().x, _fuss2d().y - Werte.KARTE_OBEN) * k
	if spiel.werkzeug != Karte.FREI:
		ci.draw_arc(b, BAU_REICHWEITE * zelle, 0.0, TAU, 40, Color(LICHT, 0.5), 1.0)
	var v := Vector2(_vorne().x, _vorne().z)
	var q := Vector2(-v.y, v.x)
	ci.draw_colored_polygon(PackedVector2Array([b + v * 6.0, b - v * 3.0 + q * 3.5, b - v * 3.0 - q * 3.5]), LICHT)
	# Brakks Leben unter der Karte
	var anteil := clampf(brakk.leben / maxf(1.0, brakk.max_leben), 0.0, 1.0)
	var bal := Rect2(o + Vector2(0, gross.y + 10.0), Vector2(gross.x, 5.0))
	ci.draw_rect(bal, Color(0, 0, 0, 0.6))
	ci.draw_rect(Rect2(bal.position, Vector2(bal.size.x * anteil, bal.size.y)), Color("8fe39a") if anteil > 0.35 else Color("ff5a6e"))
	if brakk.e_rest > 0.0:
		var t := "Treppe %.0f s" % ceilf(brakk.e_rest)
		ci.draw_string(ThemeDB.fallback_font, o + Vector2(0, gross.y + 30.0), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(LICHT, 0.8))


# ------------------------------------------------------------------ Platzhalter-Grafik aus Code

const UMRISS := Color("15121b")


## Pixelbild füllen: Vieleck in einer Farbe.
static func _vieleck(img: Image, punkte: Array, farbe: Color) -> void:
	var pv := PackedVector2Array()
	for p: Vector2 in punkte:
		pv.append(p)
	var r := Rect2(pv[0], Vector2.ZERO)
	for p in pv:
		r = r.expand(p)
	for y in range(maxi(0, floori(r.position.y)), mini(img.get_height(), ceili(r.end.y) + 1)):
		for x in range(maxi(0, floori(r.position.x)), mini(img.get_width(), ceili(r.end.x) + 1)):
			if Geometry2D.is_point_in_polygon(Vector2(x + 0.5, y + 0.5), pv):
				img.set_pixel(x, y, farbe)


## Dunkler Rand um alles Gefüllte (wie gezeichnete Pixelkunst).
static func _umranden(img: Image) -> void:
	var kopie := img.duplicate() as Image
	for y in img.get_height():
		for x in img.get_width():
			if kopie.get_pixel(x, y).a > 0.0:
				continue
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var n := Vector2i(x, y) + d
				if n.x >= 0 and n.y >= 0 and n.x < img.get_width() and n.y < img.get_height() and kopie.get_pixel(n.x, n.y).a > 0.0 and kopie.get_pixel(n.x, n.y) != UMRISS:
					img.set_pixel(x, y, UMRISS)
					break


## Rechte Pistole, Hand und Ärmel – von hinten gesehen, der Lauf zeigt nach vorn oben. Farben wie Brakk:
## dunkles Metall, Lila wie sein Mantel, Cyan wie sein Laser.
static func _male_pistole() -> Image:
	var img := Image.create(48, 66, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var metall := Color("3a3f4c")
	var hell := Color("5f6676")
	var dunkel := Color("23262e")
	var lila := Color("5b3d7a")
	# Ärmel (Mantel) von unten
	_vieleck(img, [Vector2(4, 56), Vector2(40, 52), Vector2(47, 66), Vector2(0, 66)], Color("3d2650"))
	_vieleck(img, [Vector2(5, 55), Vector2(39, 51), Vector2(41, 55), Vector2(4, 59)], Color("6a4a9a"))
	# Griff und Hand (Handschuh)
	_vieleck(img, [Vector2(15, 40), Vector2(31, 40), Vector2(30, 54), Vector2(16, 54)], dunkel)
	_vieleck(img, [Vector2(9, 38), Vector2(35, 37), Vector2(38, 48), Vector2(33, 56), Vector2(12, 57), Vector2(7, 48)], Color("2f2a36"))
	for i in 3:
		_vieleck(img, [Vector2(10, 42 + i * 4), Vector2(34, 41 + i * 4), Vector2(34, 42 + i * 4), Vector2(10, 43 + i * 4)], Color("4a4352"))
	# Rahmen und Schlitten: unten breit, nach oben (vorn) schmaler
	_vieleck(img, [Vector2(11, 28), Vector2(35, 28), Vector2(36, 38), Vector2(10, 38)], dunkel)
	_vieleck(img, [Vector2(16, 3), Vector2(30, 3), Vector2(35, 30), Vector2(11, 30)], metall)
	_vieleck(img, [Vector2(17, 3), Vector2(29, 3), Vector2(30, 7), Vector2(16, 7)], hell)
	_vieleck(img, [Vector2(21, 7), Vector2(25, 7), Vector2(27, 29), Vector2(19, 29)], Color("2d313b"))
	# Leuchtadern an den Seiten (Cyan) und lila Platten
	_vieleck(img, [Vector2(29, 8), Vector2(31, 8), Vector2(34, 27), Vector2(32, 27)], Color("7fe0ff"))
	_vieleck(img, [Vector2(15, 8), Vector2(17, 8), Vector2(14, 27), Vector2(12, 27)], Color("7fe0ff"))
	_vieleck(img, [Vector2(12, 30), Vector2(18, 30), Vector2(18, 36), Vector2(11, 36)], lila)
	_vieleck(img, [Vector2(28, 30), Vector2(34, 30), Vector2(35, 36), Vector2(28, 36)], lila)
	# Mündung mit Laserkern
	_vieleck(img, [Vector2(17, 0), Vector2(29, 0), Vector2(29, 4), Vector2(17, 4)], dunkel)
	_vieleck(img, [Vector2(21, 1), Vector2(25, 1), Vector2(25, 3), Vector2(21, 3)], Color("8ff0ff"))
	_umranden(img)
	return img


## Linke Hand mit dem Projektorring: Handrücken, Finger leicht gespreizt, Ring am Mittelfinger.
static func _male_ringhand() -> Image:
	var img := Image.create(34, 50, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var hand := Color("2f2a36")
	# Ärmel
	_vieleck(img, [Vector2(3, 38), Vector2(30, 36), Vector2(34, 50), Vector2(0, 50)], Color("3d2650"))
	_vieleck(img, [Vector2(4, 37), Vector2(29, 35), Vector2(30, 39), Vector2(3, 41)], Color("6a4a9a"))
	# Handrücken und Finger
	_vieleck(img, [Vector2(6, 18), Vector2(28, 17), Vector2(30, 32), Vector2(26, 38), Vector2(8, 39), Vector2(4, 30)], hand)
	for i in 4:
		var x := 7.0 + i * 5.5
		_vieleck(img, [Vector2(x, 4 + absf(i - 1.5) * 2.0), Vector2(x + 4, 4 + absf(i - 1.5) * 2.0), Vector2(x + 4.5, 19), Vector2(x - 0.5, 19)], hand)
		_vieleck(img, [Vector2(x + 0.5, 11), Vector2(x + 3.5, 11), Vector2(x + 3.5, 12), Vector2(x + 0.5, 12)], Color("4a4352"))
	_vieleck(img, [Vector2(27, 22), Vector2(33, 18), Vector2(33, 22), Vector2(29, 28)], hand)   # Daumen
	# Ring (Mittelfinger) mit Leuchtstein
	_vieleck(img, [Vector2(12, 13), Vector2(19, 13), Vector2(19, 17), Vector2(12, 17)], Color("9aa3b5"))
	_vieleck(img, [Vector2(14, 14), Vector2(17, 14), Vector2(17, 16), Vector2(14, 16)], Color("8ff0ff"))
	_umranden(img)
	return img
