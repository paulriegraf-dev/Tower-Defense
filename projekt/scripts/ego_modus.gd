class_name EgoModus
extends Node
## Ego-Sicht mit Brakk (Brakk-Mode, 18.11.2026; Kopf 19.11. erneuert). Die Kamera sitzt in Brakks Kopf, die Spiellogik
## bleibt die 2D-Logik – diese Datei steuert Brakk nur anders. Tasten (Maus und Tastatur; am Handy: ego_touch.gd):
##   WASD gehen, Maus schauen, Linksklick schießen (zwei Pistolen im Wechsel, jede überhitzt), Rechtsklick halten:
##   Ladestrahl, [Leertaste] springen, [Shift] Tumble, [E] Lichttreppe (auf dem Wall: Lichtbrücke), [Q] Lichtanker,
##   [X] Lichtsäule (zielen, Linksklick setzt), [R] Klonmaschine (Ulti), [V] Zeitlupe, Mausrad aktiver Ring,
##   [C] Ringfeld (Bauphase), [F] ausbauen bzw. an der Basis das Lichtterminal, [1]–[7] bauen (BAU_REICHWEITE Felder),
##   [Enter] Welle jetzt. Fähigkeiten werden über Brakks Stufe frei (brakk_fortschritt.gd).
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
const LASER_LINKS := Color("c9a6ff")   # 18.11. (Paul): linke Pistole – violetter Laser (Technoclan), rechts Cyan

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
var _kletter_dauer := KLETTER_STEIGEN   # 19.11. (Paul): eine lange Treppe geht Brakk im Lauftempo hinauf (wie auf der Lichtbrücke), nicht im Sprint
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
var _tex_pistole: Texture2D
var _tex_pistole_links: Texture2D   # 18.11.: die linke Pistole sieht anders aus als die rechte
var _tex_ring: Texture2D
var _strahlen: Array = []       # [MeshInstance3D, Rest]
var _strahl_mat: StandardMaterial3D
var _bau_strahl: MeshInstance3D
# 18.11.: Brakk-Mode – Tumble und Ladestrahl
const TUMBLE_FELDER := 3.0
const TUMBLE_DAUER := 0.3
const TUMBLE_ABKLING := 4.0
const LANZE_LADEN := 0.8
const LANZE_ABKLING := 6.0
const LANZE_SCHADEN := 60.0
const LANZE_WEITE := 14.0
var _tumble := -1.0             # läuft: Sekunden seit Beginn (-1 = nein)
var _tumble_r := Vector2.ZERO   # Richtung in der 2D-Logik (Einheitsvektor)
var _tumble_seite := 0.0        # -1 links, 1 rechts: dorthin kippt die Sicht
var _tumble_rest := 0.0
var _tumble_schuss_bis := 0      # 19.11.: bis dahin (ms) ist der nächste Schuss der Tumble-Schuss
# 19.11. (Paul): Bewegungsgefühl – Nachschwung nach der Rolle, Waffen-Sway, Seitneigung, Landungsdelle, Doppelsprung
const SCHWUNG_SEK := 1.0         # so lange läuft Brakk nach dem Tumble schneller …
const SCHWUNG_MAL := 1.4         # … um so viel
const SWAY_STAERKE := 0.06       # Bildpunkte der Waffe je Bildpunkt Mausbewegung
const SWAY_MAX := 9.0            # höchstens so viele Waffen-Bildpunkte
const NEIGUNG_SEITE := 0.025     # Bogenmaß Kippen beim Seitwärtslaufen
var _schwung := 0.0              # Restzeit des Nachschwungs
var _sway := Vector2.ZERO        # Waffen hängen der Maus nach (Waffen-Bildpunkte)
var _seit := 0.0                 # geglättete Seitwärtsbewegung -1..1 (für die Neigung)
var _delle := 0.0                # Landungsdelle 0..1
var _doppelt_genutzt := false    # Doppelsprung schon verbraucht (bis zur Landung)
var _plattformen: Array = []     # Lichtplattformen des Doppelsprungs: [Node3D, Alter]
var _lanze := -1.0              # lädt: Sekunden seit Beginn (-1 = nein)
var _lade_voll_ms := -100000       # 19.11.: wann der Ladestrahl voll geladen war (Aufblitzen am Fadenkreuz)
var _lanze_rest := 0.0
var _wirbel := 0.0               # 18.11.: Wirbelring – Anlauf des Dauerfeuers 0..1
var _brand_ab := 0                # ab dieser Zeit (ms) darf das nächste Brandfeld
var _terminal: Control = null    # 18.11.: Lichtterminal (Ringe kaufen)
var _knoepfe: Array = []         # [Rect2, Callable] – Schaltflächen im Terminal
var _hand_zeigen := 0.0           # 18.11.: so lange (s) hebt Brakk die Ringhand (Mausrad, [C])
var _ring_blitz := 0.0            # 18.11.: kurzes Aufblitzen des neu gewählten Rings
# 18.11.: Touchpad – ein Wisch mit zwei Fingern schickt viele kleine Mausrad-Meldungen; erst eine volle Raste
# (Summe der Anteile) wechselt den Ring, und höchstens alle RAD_PAUSE Sekunden.
const RAD_PAUSE := 0.25
var _rad_summe := 0.0
var _rad_zuletzt := -10.0
const COUNTDOWN := 45.0            # 18.11. (Paul): Brakk-Mode – so lange (echte Sekunden, 19.11.: vorher 30 Spielsekunden) dauert die Bauphase, dann kommt die Welle von selbst
const COUNTDOWN_ERSTE := 45.0      # in Runde 1 etwas mehr Zeit
var _countdown := -1.0           # läuft: Restzeit (-1 = keine Bauphase)
# 18.11. (Paul): Überhitzen wie in Battlefront 2 – je Pistole eine Hitze 0..1; voll = kurz gesperrt
const HITZE_JE_SCHUSS := 0.15
const HITZE_KUEHLEN := 0.3        # je Sekunde, sobald die Pistole HITZE_PAUSE lang nicht geschossen hat
const HITZE_PAUSE := 0.45
const HITZE_SPERRE := 1.5         # Sekunden gesperrt nach dem Überhitzen
var _hitze := [0.0, 0.0]
var _gesperrt := [0.0, 0.0]       # Restzeit der Sperre je Pistole
var _seit_schuss := [9.0, 9.0]
var _feld_knoten := {}           # Ring -> Node3D seines Ringfelds
var _vorschau: Node3D = null     # Vorschau des Ringfelds unter dem Fadenkreuz
const FELD_WEITE := 12.0         # so weit (Felder) wirft der Ring sein Feld
# 18.11.: Handy – Touch-Steuerung (ego_touch.gd). Liegt das Fadenkreuz auf einem Gegner, drückt Brakk selbst ab (Paul: zielen musst du), ohne Hitze.
var touch: EgoTouch = null
var kit: EgoKit = null              # 20.11.: Schritt 6b – Kit eines anderen Anführers (Irrtürmer, Sonde 7); Brakk: null
var _auto_ziel: Gegner = null
var _auto_r := Vector3.ZERO
const AUTO_RADIUS := 0.45        # so nah (Felder) muss die Blicklinie an der Gegnermitte vorbeigehen – etwas großzügiger als ein Schuss (0,34)
const LANZE_TOUCH := 1.5         # am Handy ohne Hitze: feste Verstärkung des Ladestrahls


func starten(p_spiel: Node) -> void:
	spiel = p_spiel
	hd = spiel.hd
	karte = spiel.karte
	brakk = spiel.kommandant
	process_priority = 50          # nach der HD-Ansicht: die Kamera setzen wir zuletzt
	process_mode = Node.PROCESS_MODE_ALWAYS   # 18.11.: auch in der Pause – dort gibt sie die Maus frei
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
	if spiel.brakk_modus and spiel.brakk_geschosse == null:
		spiel.brakk_geschosse = BrakkGeschosse.new()   # 20.11.: Schritt 6c – Ausweichen
		spiel.brakk_geschosse.einrichten(spiel)
		spiel.add_child(spiel.brakk_geschosse)
	if spiel.brakk_modus and brakk.fortschritt == null:
		brakk.fortschritt = BrakkFortschritt.new(brakk)   # 18.11.: Stufen und Ringe für diese Partie
		spiel.freie_waelle += BrakkFortschritt.FREIE_WAELLE
		spiel.freie_stellungen += BrakkFortschritt.FREIE_STELLUNGEN
	if brakk.fortschritt != null:
		match brakk.fortschritt.anfuehrer:   # 20.11.: Schritt 6b – andere Anführer bringen ihr Kit mit (Brakk: keins)
			"irrtuermer":
				kit = EgoIrrtuermer.new(self)
			"sonde7":
				kit = EgoSonde.new(self)
	_baue_oberflaeche()
	_baue_berge_ringsum()   # 18.11.: Kulisse auch links, rechts und vorn
	for n: String in ["_sandbox_leiste", "_zoom_grund"]:
		var c: Variant = spiel.get(n)
		if c is CanvasItem and is_instance_valid(c) and (c as CanvasItem).visible:
			_versteckt.append(c)
	_verstecke()
	# Die Bauleiste unten verdeckt die Sicht (Paul 18.11.): einklappen, links steht stattdessen eine schmale Liste
	_hud_klapp = spiel._hud.eingeklappt
	spiel._hud.eingeklappt = true
	if spiel.brakk_modus:
		_briefing_zeigen()   # 18.11. (Paul): erst die Einsatz-Tafel, nicht abrupt hinein
	if Touch.ohne_maus():
		touch = EgoTouch.new(self)   # 18.11.: Handy – Stick, Wischen, Knöpfe
		add_child(touch)
		spiel.melde("Brakk-Mode: links laufen · rechts wischen zum Zielen · Fadenkreuz auf dem Gegner: Brakk schießt · Fähigkeit tippen oder halten und ziehen", 10.0)
		return
	if kit != null:
		spiel.melde("Brakk-Mode mit %s: WASD + Maus · [F] ausbauen, an der Basis Ringe · [I] Übersicht → Brakk-Mode · Enter: Welle" % Anfuehrer.name(brakk.fortschritt.anfuehrer), 10.0)
		return
	spiel.melde("Brakk-Mode: WASD + Maus · Klick schießt · Leertaste springt · [E] Lichttreppe · [F] ausbauen, an der Basis Ringe · Enter: Welle" + ("" if spiel.brakk_modus else " · [G] zurück"), 10.0)


func beenden() -> void:
	if kit != null:
		kit.beenden()   # 20.11.
	if _zeitlupe > 0.0:
		_zeitlupe_aus()   # 18.11.: das Spieltempo nicht in der Zeitlupe hängen lassen
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
	if _bruecke != null:
		_bruecke.queue_free()
	for s: Array in _saeulen:
		(s[0] as Node).queue_free()
	for k: Node in [_saeule_marke]:
		if k != null:
			k.queue_free()
	if _anker_seil != null:
		_anker_seil.queue_free()
		_anker_haken.queue_free()
	_berge_zurueck()
	for k: Node3D in _feld_knoten.values():
		k.queue_free()
	if _vorschau != null:
		_vorschau.queue_free()
	for m: Node in _feld_marken:
		m.queue_free()
	for p: Array in _plattformen:
		(p[0] as Node).queue_free()
	if _ebene != null:
		_ebene.queue_free()
	if is_instance_valid(spiel):
		spiel.ego = null
		if spiel.brakk_geschosse != null:
			spiel.brakk_geschosse.queue_free()   # 20.11.: Schritt 6c
			spiel.brakk_geschosse = null
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
	if _briefing_offen():
		return false
	if _terminal != null and _terminal.visible:
		return false
	if spiel.order24 != null and spiel.order24.sperrt_steuerung():
		return false   # 20.11.: Befehl 24 – Verrat-Sequenz läuft
	return not Input.is_key_pressed(KEY_ALT)


func _input(event: InputEvent) -> void:
	if _briefing_offen():
		if event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
			_briefing_los()
			get_viewport().set_input_as_handled()
		return
	if _terminal != null and _terminal.visible:
		if event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).keycode in [KEY_ESCAPE, KEY_F]:
			_terminal.visible = false   # 18.11.: Lichtterminal schließen
			get_viewport().set_input_as_handled()
		return
	if not _frei():
		return
	if touch != null and (event is InputEventMouseMotion or event is InputEventMouseButton):
		return   # 18.11.: am Handy steuert ego_touch.gd – die nachgemachte Maus der Finger zählt hier nicht
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var m := event as InputEventMouseMotion
		gier -= m.relative.x * BLICK
		nick = clampf(nick - m.relative.y * BLICK, -1.25, 1.25)
		_sway = (_sway - m.relative * SWAY_STAERKE).limit_length(SWAY_MAX)   # 19.11.: Waffen hängen nach
		return
	if event is InputEventMouseButton:
		var b := event as InputEventMouseButton
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			return
		if _feld_zielt and b.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
			if b.pressed:
				if b.button_index == MOUSE_BUTTON_LEFT:
					_feld_bestaetigen()   # 19.11.: Ringfeld setzen
				else:
					_feld_abbrechen()
			get_viewport().set_input_as_handled()
			return
		if b.button_index == MOUSE_BUTTON_LEFT:
			if _saeule_zielt:
				if b.pressed:
					_saeule_bestaetigen()   # 18.11.: Lichtsäule setzen
				get_viewport().set_input_as_handled()
				return
			if spiel.werkzeug != Karte.FREI:
				# Bauen: nur in Reichweite – sonst geht der Klick nicht ans Spiel
				if b.pressed and not _in_reichweite(karte.zelle_bei(ziel_welt())):
					spiel.melde("Zu weit weg – geh näher heran (höchstens %d Felder)." % int(BAU_REICHWEITE), 2.5)
					get_viewport().set_input_as_handled()
				return
			_aktion("links", b.pressed)   # 20.11.: Belegung je Anführer (Brakk: Pistolen)
			get_viewport().set_input_as_handled()
		elif b.pressed and (b.button_index == MOUSE_BUTTON_WHEEL_UP or b.button_index == MOUSE_BUTTON_WHEEL_DOWN):
			_rad(-1 if b.button_index == MOUSE_BUTTON_WHEEL_UP else 1, b.factor if b.factor > 0.0 else 1.0)   # 18.11.
			get_viewport().set_input_as_handled()
		elif b.button_index == MOUSE_BUTTON_RIGHT:
			if _saeule_zielt:
				if b.pressed:
					_saeule_abbrechen()
				get_viewport().set_input_as_handled()
				return
			if spiel.werkzeug != Karte.FREI:
				if b.pressed:
					spiel.werkzeug = Karte.FREI   # Werkzeug weglegen (kein Abriss in der Ego-Sicht)
			else:
				_aktion("rechts", b.pressed)   # 18.11.: Ladestrahl laden / abfeuern; 20.11.: Belegung je Anführer
			get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and not event.echo:
		var kc := (event as InputEventKey).keycode
		if event.pressed and _feld_zielt and kc == KEY_ESCAPE:
			_feld_abbrechen()   # 19.11.: Ringfeld nicht setzen
			get_viewport().set_input_as_handled()
			return
		if kc == KEY_F and spiel.order24 != null and spiel.order24.ego_taste(self, "F", event.pressed):
			get_viewport().set_input_as_handled()   # 20.11. (Paul): Befehl 24 – [F] gehalten an der Rückseite sabotiert die Fabrik
			return
		if event.pressed and spiel.order24 != null and spiel.order24.ego_zahl(self, kc):
			get_viewport().set_input_as_handled()   # 20.11.: Befehl 24, Überläufer – [1]–[7] Myriaden-Fabrik
			return
		# 20.11.: Schritt 6b – Fähigkeiten und Bewegung über die Tastenbelegung des Anführers (Werte.ANFUEHRER_EGO)
		var taste := str(TASTEN.get(kc, ""))
		if taste != "":
			if _aktion(taste, event.pressed):
				get_viewport().set_input_as_handled()
			return
		if not event.pressed:
			return
		match kc:
			KEY_B:
				if spiel.brakk_modus:
					get_viewport().set_input_as_handled()   # 18.11. (Paul): keine Bauleiste im Brakk-Mode
			KEY_ENTER, KEY_KP_ENTER:
				spiel.starte_welle()
				get_viewport().set_input_as_handled()
			KEY_F:
				# 18.11. (Paul): Gebäude im Blick ausbauen – öffnet dasselbe Menü wie ein Klick in der Übersicht
				var z := gebaeude_im_blick()
				if z != Karte.KEINE and spiel.werkzeug == Karte.FREI and spiel.order24 == null:   # 20.11.: in Befehl 24 gehören die Bauten dem Feind
					spiel._oeffne_fabrikmenue(z)
					get_viewport().set_input_as_handled()
				elif (z == Karte.KEINE or spiel.order24 != null) and _am_terminal():
					_terminal_auf()   # 18.11.: Lichtterminal an der Basis
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
	if spiel.fabriken.has(z) and spiel.brakk_modus and not karte.paar.has(z):
		return false   # 19.11. (Paul): Brakk-Mode – Fabriken nicht bearbeitbar (Pilotenfabrik der Batterie schon)
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


## 20.11.: Schritt 6b – die Tasten des gemeinsamen Sockels; was sie tun, sagt die Belegung des Anführers.
const TASTEN := {KEY_Q: "Q", KEY_E: "E", KEY_R: "R", KEY_V: "V", KEY_X: "X", KEY_C: "C", KEY_SHIFT: "shift", KEY_SPACE: "leertaste"}


## Taste (oder Maustaste) gedrückt / losgelassen: Aktion laut Belegung. Erst darf das Kit des Anführers, dann die
## gemeinsamen Aktionen (Brakks Fähigkeiten, Bewegung, Ringfeld). true = erledigt.
func _aktion(taste: String, gedrueckt: bool) -> bool:
	if spiel.order24 != null and spiel.order24.ego_taste(self, taste, gedrueckt):
		return true   # 20.11.: Befehl 24 – [C] Sprengladung, [E] Sabotage an der Fabrik-Rückseite (order24.gd)
	var was := str((Werte.ANFUEHRER_EGO[anfuehrer()]["tasten"] as Dictionary).get(taste, ""))
	if was == "":
		return false
	if kit != null and brakk.fortschritt != null and not brakk.fortschritt.frei(was):
		if gedrueckt:
			_darf(was)   # 20.11. (Nachtrag): gesperrt bis zur Heldenstufe
		return true
	if kit != null and kit.aktion(was, gedrueckt):
		return true
	return _brakk_aktion(was, gedrueckt)


## Brakks Aktionen (und die gemeinsamen Bewegungen) – genau wie vor dem 20.11. auf den festen Tasten.
func _brakk_aktion(was: String, gedrueckt: bool) -> bool:
	match was:
		"pistolen":
			_feuer = gedrueckt
			return true
		"lanze":
			_lanze_taste(gedrueckt)   # 18.11.: Ladestrahl laden / abfeuern
			return true
	if not gedrueckt:
		return false
	match was:
		"saeule":
			if not spiel.brakk_modus:
				return false
			_saeule_x()   # 18.11.: Lichtsäule zielen / abbrechen
		"zeitlupe":
			if not spiel.brakk_modus:
				return false
			_zeitlupe_start()   # 18.11.: Zeitlupe
		"feld":
			_wirf_feld()   # 18.11.: Ringfeld werfen
		"tumble":
			_tumble_start()   # 18.11.
		"ulti":
			if brakk.fortschritt == null:
				return false
			_ulti()   # 18.11.: im Brakk-Mode die Ulti
		"anker":
			if not spiel.brakk_modus:
				return false
			_anker_start()   # 18.11. (Paul): Lichtanker statt Sammeln – Brakk spielt allein
		"sprung":
			_leertaste()
		"treppe":
			# 18.11. (Paul): [E] wirft die Lichttreppe – hinauf auf den Wall vor Brakk bzw. hinunter (statt 2× Leertaste)
			if _klettern < 0.0:
				if brakk.oben:
					if not _versuche_bruecke():   # 18.11.: Blick auf einen anderen Wall – Lichtbrücke
						_versuche_absteigen(true)
				else:
					_versuche_klettern(true)
		_:
			return false
	return true


## 20.11.: Wer gerade spielt (ohne Brakk-Mode-Fortschritt immer Brakk).
func anfuehrer() -> String:
	return brakk.fortschritt.anfuehrer if brakk.fortschritt != null else "brakk"


## 20.11.: Hat der Anführer diese Aktion auf irgendeiner Taste?
func hat_aktion(was: String) -> bool:
	return (Werte.ANFUEHRER_EGO[anfuehrer()]["tasten"] as Dictionary).values().has(was)


## Ist die Taste mit dieser Belegung gerade gedrückt? (für Aktionen, die man hält)
func taste_gehalten(taste: String) -> bool:
	match taste:
		"links":
			return Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
		"rechts":
			return Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
	for k: int in TASTEN:
		if str(TASTEN[k]) == taste:
			return Input.is_physical_key_pressed(k as Key)
	return false


## Leertaste springt nur noch (18.11.: Klettern liegt auf [E]).
func _leertaste() -> void:
	if _klettern >= 0.0:
		return
	if hoehe <= _boden() + 0.001:
		steig = SPRUNG
		_doppelt_genutzt = false
		if _haken >= 0.0:
			_flug = _lauf * SCHWING_MAL   # 19.11. (Paul): am Lichtanker schwingen
	elif not _doppelt_genutzt and (brakk.fortschritt == null or brakk.fortschritt.frei("doppelsprung")):   # 19.11. (Paul): ab Stufe 2
		_doppelsprung()   # 19.11. (Paul): in der Luft – Lichtplattform unter den Füßen


# ------------------------------------------------------------------ Ablauf

func _process(delta: float) -> void:
	if get_tree().paused:
		# 18.11. (Paul): Pause-Menü – die Maus muss frei sein, das Fadenkreuz weg (_frei() ist in der Pause falsch).
		# Die Ego-Sicht läuft dafür auch in der Pause weiter (process_mode ALWAYS in starten()).
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_uhr_vorher = 0
		_bild.queue_redraw()
		_karte_klein.queue_redraw()   # 19.11.: Übersicht / Pause – Minikarte ausblenden
		return
	if _sieg_t >= 0.0:
		_sieg_weiter()   # 19.11.: Sieg – Kameraflug und Übersicht
		return
	if is_instance_valid(brakk) and brakk.gefallen and spiel.brakk_modus:
		# 18.11. (Paul): Im Brakk-Mode bleibt die Ego-Sicht – die Kamera liegt am Boden, bis Brakk zur nächsten Runde aufsteht
		if not _liegt:
			_liegt = true
			_feuer = false
			_respawn = BrakkFortschritt.RESPAWN_SEK   # 19.11. (Paul): kleiner Respawn-Timer, dann an der Basis
			if kit != null:
				kit.gefallen()   # 20.11.: z. B. der PliPlop fällt mit
			if _haken >= 0.0:
				_haken_los()
			if _zeitlupe > 0.0:
				_zeitlupe_aus()
		var uhr_r := Time.get_ticks_usec()
		var echt_r := clampf((uhr_r - _uhr_vorher) / 1000000.0, 0.0, 0.1) if _uhr_vorher > 0 else delta
		_uhr_vorher = uhr_r
		_respawn -= echt_r
		if _respawn <= 0.0 and spiel.phase == 1:
			_wieder_da()
			return
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
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if frei and touch == null else Input.MOUSE_MODE_VISIBLE
	if touch != null:
		_auto_zielen()   # 18.11.: Handy – Brakk schießt selbst
		_feuer = frei and _auto_ziel != null and spiel.werkzeug == Karte.FREI and not _saeule_zielt
	_takt -= echt
	# 18.11.: Schussgefühl abklingen lassen (Echtzeit)
	_trauma = maxf(0.0, _trauma - TRAUMA_ABBAU * echt)
	_wackel_t += echt * 30.0
	_kick = lerpf(_kick, 0.0, 1.0 - exp(-12.0 * echt))
	_fov_puls = move_toward(_fov_puls, 0.0, echt * 30.0)
	_kreuz = maxf(0.0, _kreuz - echt)
	_einflug_weiter(echt)   # 18.11.
	if _briefing != null and _briefing.visible:
		_briefing.queue_redraw()
	_fliessende_runden(echt)   # 18.11.; 19.11.: in Echtzeit (das Spiel läuft fest auf ×2)
	_kuehlen(echt)
	_treppe_rest -= echt
	if brakk.fortschritt != null:
		brakk.fortschritt.weiter(echt)
		if spiel.phase == 1:
			brakk.fortschritt.zaehle_zeit("kampf_sek", echt)   # 19.11.: Sieg-Übersicht
			if brakk.oben:
				brakk.fortschritt.zaehle_zeit("wall_sek", echt)
	for i in 2:
		_rueckstoss[i] = maxf(0.0, float(_rueckstoss[i]) - echt * 6.0)
		_blitz[i] = maxf(0.0, float(_blitz[i]) - echt)
	# Ring vor, wenn gebaut wird oder die Treppe läuft
	_hand_zeigen -= echt
	_ring_blitz = maxf(0.0, _ring_blitz - echt)
	var ring_soll := 1.0 if (spiel.werkzeug != Karte.FREI or _klettern >= 0.0 or _hand_zeigen > 0.0 or _treppe_aufbau >= 0.0) else 0.0
	_ring = move_toward(_ring, ring_soll, echt * 6.0)
	_tumble_rest -= echt
	_schwung = maxf(0.0, _schwung - echt)
	_sway = _sway.lerp(Vector2.ZERO, 1.0 - exp(-9.0 * echt))
	_delle = move_toward(_delle, 0.0, echt * 4.0)
	_plattformen_weiter(echt)
	_lanze_rest -= echt
	_anker_rest -= echt
	if not _feuer:
		_wirbel = maxf(0.0, _wirbel - echt * 1.5)
	if _lanze >= 0.0:
		# 19.11. (Paul): Aufladen spürbarer – das Bild zieht sich zusammen, zittert leicht, die Pistolen ziehen zurück;
		# voll geladen: Klick und Aufblitzen (der Ladering am Fadenkreuz steht in _fadenkreuz)
		var war_voll := _lanze >= LANZE_LADEN
		_lanze += echt
		var ladung := _glut()
		_fov_puls = maxf(_fov_puls, 5.0 * ladung)
		_trauma = maxf(_trauma, 0.12 * ladung)
		_rueckstoss[0] = maxf(float(_rueckstoss[0]), 0.3 * ladung)
		_rueckstoss[1] = maxf(float(_rueckstoss[1]), 0.3 * ladung)
		if not war_voll and _lanze >= LANZE_LADEN:
			_lade_voll_ms = Time.get_ticks_msec()
			Ton.spiele(spiel, "ui-klick", 3.0)
		if not frei:
			_lanze = -1.0   # Menü auf: Laden abbrechen
	if _klettern >= 0.0:
		_kletter_weiter(echt)
	elif _anker >= 0.0:
		_anker_weiter(echt)   # 18.11.
	elif _absprung >= 0.0:
		_absprung_weiter(echt)   # 19.11.
	elif _tumble >= 0.0:
		_tumble_weiter(echt)
	else:
		_gehen(echt if frei else 0.0)
		if kit == null or not kit.vor_fallen(echt):   # 20.11.: z. B. Schweben (Sonde 7)
			_fallen(echt)
		_flug_weiter(echt)   # 19.11.: Schwung aus Seil und Absprung
	if _haken >= 0.0 and _anker < 0.0 and _klettern < 0.0:
		_haken_weiter(echt)   # 19.11.: Lichtanker hängt
	if _feuer and frei and _takt <= 0.0 and _klettern < 0.0 and _lanze < 0.0 and not _saeule_zielt and not _feld_zielt:
		if kit != null:
			kit.schuss()   # 20.11.: Grundschuss des Anführers
		else:
			_schiess()
	if kit != null:
		kit.weiter(echt, frei)   # 20.11.: Kit des Anführers
	_kamera()
	_brakk_verstecken()
	_verstecke()
	_strahlen_weiter(echt)
	_treppe_weiter()
	_bau_strahl_weiter()
	_felder_weiter(echt)   # 18.11.: Ringfelder in 3D
	_bruecke_weiter(echt)
	_treffer_merken(echt)   # 18.11.
	_saeule_weiter(echt)
	_zeitlupe_weiter(echt)
	SichererRand.einpassen(_karte_klein)   # 19.11.: Minikarte nicht unter der Notch
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
	if touch != null:
		r += touch.stick()   # 18.11.: Handy-Stick (stufenlos)
	_geht = r != Vector2.ZERO and dt > 0.0
	_lauf = Vector2.ZERO
	_seit = lerpf(_seit, clampf(r.x, -1.0, 1.0) if _geht else 0.0, 1.0 - exp(-8.0 * dt)) if dt > 0.0 else _seit
	brakk._sprite.bewegt(_geht)
	if not _geht:
		return
	r = r.limit_length(1.0) if touch != null else r.normalized()
	var schwung := lerpf(1.0, SCHWUNG_MAL, clampf(_schwung / 0.3, 0.0, 1.0)) if _schwung > 0.0 else 1.0   # 19.11.: Nachschwung, klingt zum Ende aus
	var v := (_vorne() * r.y + _rechts() * r.x) * TEMPO * float(Werte.ANFUEHRER_EGO[anfuehrer()]["tempo"]) * (kit.tempo_faktor() if kit != null else 1.0) * schwung * dt   # 20.11.: Tempo je Anführer
	_lauf = Vector2(v.x, v.z) / dt   # 19.11.: für Absprung und Schwingen
	var schritt := Vector2(v.x, v.z) * Werte.ZELLE
	_luft_schritt(Vector2(schritt.x, 0.0))   # 19.11.: hoch genug in der Luft landet Brakk auf einem Wall
	_luft_schritt(Vector2(0.0, schritt.y))
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
		if _auf_bruecke(z):
			_setze_fuss(neu)   # 18.11.: auf der Lichtbrücke (der Posten bleibt das letzte Wallstück)
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
				_delle = clampf(-steig / 9.0, 0.3, 1.0)   # 19.11.: die Sicht federt kurz ein
			_doppelt_genutzt = false
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
	var tw := sin(clampf(_tumble / TUMBLE_DAUER, 0.0, 1.0) * PI) if _tumble >= 0.0 else 0.0   # 18.11.: Tumble – tief und gekippt
	k.position.y -= 0.38 * tw
	k.position.y -= 0.12 * sin(_delle * PI * 0.5)   # 19.11.: Landungsdelle
	# 18.11.: Rückstoß hebt die Sicht kurz an, Wackeln aus Trauma² mit überlagerten Sinuswellen (kein Zittern)
	var w2 := _trauma * _trauma
	k.rotation = Vector3(nick + _kick - 0.35 * tw + WACKEL_WINKEL * w2 * sin(_wackel_t * 1.7), gier + WACKEL_WINKEL * w2 * sin(_wackel_t * 2.3),
		WACKEL_WINKEL * 0.6 * w2 * sin(_wackel_t * 1.1) - 0.5 * tw * _tumble_seite - NEIGUNG_SEITE * _seit)
	k.fov = SICHTWINKEL - _fov_puls + _fov_weit
	_einflug_kamera(k)   # 18.11.: Einflug nach der Einsatz-Tafel
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
		if not spiel.endkampf and spiel.order24 == null and p.x < float(Werte.ZONE_SPALTEN):   # 20.11. (Paul): in Befehl 24 kein Schild am Myriaden-HQ
			return t   # 18.11. (Paul): der Schild vor der Gegnerzone fängt den Schuss ab
		var z := Vector2i(floori(p.x), floori(p.z))
		if z != eigene:
			if hd.ist_hoch(z) and p.y <= hd.H:
				return t
			if karte.inhalt(z) == Karte.FABRIK and p.y <= 1.1:
				return t
		t += 0.04
	return weite


## Punkt unter dem Fadenkreuz in der 2D-Logik (für Bauen, Q, R): Mauerkrone oder Boden.
## 19.11. (Paul): Mit Stellung (und den anderen Ausbauten) in der Hand rastet das Ziel auf das nächste passende Feld ein.
func ziel_welt(nur_boden: bool = false) -> Vector2:
	var p := _ziel_roh(nur_boden)
	if nur_boden or p.x < -9000.0 or not spiel._ist_ausbau(spiel.werkzeug):
		return p
	return _ausbau_einrasten(p)


const EINRASTEN := 1.6           # Felder: so weit neben dem Fadenkreuz darf das eingerastete Feld liegen
var _einrast_bild := -1
var _einrast_roh := Vector2.INF
var _einrast_ziel := Vector2.ZERO


func _ausbau_einrasten(p: Vector2) -> Vector2:
	var bild := Engine.get_process_frames()
	if bild == _einrast_bild and p == _einrast_roh:
		return _einrast_ziel   # je Bild nur einmal suchen (Vorschau, Strahl und Klick fragen dasselbe)
	var z := karte.zelle_bei(p)
	var ziel := p
	if spiel.bau_hindernis(z, spiel.werkzeug) != "" or not _in_reichweite(z):
		var beste := EINRASTEN * Werte.ZELLE
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				var c := z + Vector2i(dx, dy)
				if c == z or not karte.in_karte(c) or not _in_reichweite(c):
					continue
				var d := karte.mitte(c).distance_to(p)
				if d < beste and spiel.bau_hindernis(c, spiel.werkzeug) == "":
					beste = d
					ziel = karte.mitte(c)
	_einrast_bild = bild
	_einrast_roh = p
	_einrast_ziel = ziel
	return ziel


func _ziel_roh(nur_boden: bool) -> Vector2:
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

## 18.11.: Handy – der vorderste sichtbare Gegner in Schussweite, auf dem das Fadenkreuz liegt (Blicklinie höchstens AUTO_RADIUS neben seiner Mitte).
func _auto_zielen() -> void:
	_auto_ziel = null
	if _liegt or not _frei():
		return
	var von := hd.kamera.global_position
	var blick := _blick()
	var bester := INF
	for g: Gegner in spiel.ego_gegner():
		if not is_instance_valid(g) or g._tot:
			continue
		var c := _ziel_mitte(g)   # 20.11.: Befehl 24 – Ziele können Höhe und Größe vorgeben
		var d := c - von
		var weite := d.length()
		if weite > SCHUSS_WEITE or weite < 0.1:
			continue
		var t := d.dot(blick)
		if t <= 0.0 or (von + blick * t).distance_to(c) > AUTO_RADIUS or t >= bester:
			continue   # nicht unter dem Fadenkreuz (oder ein näherer liegt davor)
		var r := d / weite
		if _strahl_bis(von, r, weite) < weite - 0.35:
			continue   # Mauer oder Schild dazwischen
		bester = t
		_auto_ziel = g
		_auto_r = r


## 20.11. (Paul): Trefferpunkt eines Ziels in 3D. Befehl-24-Ziele (Turmkern, Fabrik, HQ) geben über Metadaten Höhe und
## Größe vor – der Turmkern sitzt oben im Turm und ist größer als eine Figur.
func _ziel_mitte(g: Gegner) -> Vector3:
	return _zu3d(g.position, (hd.H if hd.ist_hoch(karte.zelle_bei(g.position)) else 0.0) + float(g.get_meta("treffer_hoehe", 0.42)))


func _ziel_radius(g: Gegner, standard: float) -> float:
	return maxf(standard, float(g.get_meta("treffer_radius", 0.0)))


## Richtung der Schüsse: am Handy auf das selbst gewählte Ziel, sonst durchs Fadenkreuz.
func _schuss_blick() -> Vector3:
	if touch != null and _auto_ziel != null and is_instance_valid(_auto_ziel):
		return _auto_r
	return _blick()


func _schiess() -> void:
	if _klinge_aktiv():
		_klinge_schlag()   # 19.11.: Zeitlupe mit Durchschlagring – Nahkampf statt Schuss
		return
	_takt = SCHUSS_TAKT * _takt_faktor()
	_wirbel = minf(1.0, _wirbel + 0.08)   # 18.11.: Wirbelring – Dauerfeuer läuft an
	var seite := 0 if _links_dran else 1
	if _ring > 0.5:
		seite = 1   # linke Hand trägt den Ring: nur rechts
	if float(_gesperrt[seite]) > 0.0:
		seite = 1 - seite   # 18.11.: überhitzt – die andere Pistole schießt
		if float(_gesperrt[seite]) > 0.0 or (_ring > 0.5 and seite == 0):
			_takt = 0.15
			return   # beide heiß: nichts
	_links_dran = seite == 1
	_heize(seite)
	_rueckstoss[seite] = 1.0
	_blitz[seite] = 0.06
	var von := hd.kamera.global_position
	var r := _schuss_blick()
	var bis := _strahl_bis(von, r, SCHUSS_WEITE)
	# 18.11.: alle Gegner auf der Linie, nach Abstand – der Durchschlagring trifft bis zu drei davon
	var linie: Array = []
	for g: Gegner in spiel.ego_gegner():
		if not is_instance_valid(g) or g._tot:
			continue
		var c := _ziel_mitte(g)
		var t := (c - von).dot(r)
		if t <= 0.0 or t >= bis:
			continue
		if (von + r * t).distance_to(c) <= _ziel_radius(g, 0.34):
			linie.append([t, g])
	linie.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	var f := brakk.fortschritt
	var weitere: Array = f.brakk_wert("weitere", []) if f != null else []   # 19.11.: je Ringstufe (RINGE.brakk_stufen)
	var durch := not weitere.is_empty()
	var getroffen: Array = linie.slice(0, 1 + weitere.size())
	var ende := von + r * (bis if durch or getroffen.is_empty() else float(getroffen[0][0]))
	var muendung := von + _blick() * 0.5 + _rechts() * (0.16 if seite == 1 else -0.16) - Vector3(0, 0.14, 0)
	_strahl(muendung, ende, LASER_LINKS if seite == 0 else SCHUSS)
	var tumble := Time.get_ticks_msec() < _tumble_schuss_bis   # 19.11.: erster Schuss nach der Rolle
	if tumble:
		_tumble_schuss_bis = 0
		_tumble_schuss_bild(muendung, ende)
	# 18.11.: Schuss – eigener PixelLab-Klang je Pistole (links A, rechts B), dazu Rückstoß und Sichtfeld-Puls
	Ton.spiele(spiel, "brakk-schuss-a" if seite == 0 else "brakk-schuss-b")   # 18.11.: eigene Schussklänge je Pistole (PixelLab)
	_kick += 0.022
	_fov_puls = maxf(_fov_puls, 1.6)
	_trauma = minf(1.0, _trauma + 0.08)
	if getroffen.is_empty():
		return
	spiel.schadensquelle = "fabrik:-1,-1"
	spiel.schuss_herkunft = brakk.position
	var kill := false
	var nr := 0
	for e: Array in getroffen:
		var g: Gegner = e[1]
		var durch_anteil := 1.0 if nr == 0 else float(weitere[nr - 1])   # 19.11.: Anteil je weiterem Gegner aus der Tabelle
		nr += 1
		if not is_instance_valid(g) or g._tot:
			continue
		spiel.brakk_quelle = "pistole" if nr == 1 else "ring"   # 19.11.: Schaden nach Quelle
		var schaden := SCHUSS_SCHADEN * _schaden_faktor() * _gel_bonus(g) * durch_anteil
		var tumble_ziel := tumble and nr == 1
		if tumble_ziel:
			spiel.brakk_quelle = "tumble"
			schaden *= float(BrakkFortschritt.TUMBLE_SCHUSS["mal_gross" if BrakkFortschritt.gross(g) else "mal"])
		g.nimm_schaden(schaden)
		treffer_zahl += 1
		_ring_treffer(g, schaden)
		if g._tot:
			kill = true
			_kill(g)
			if tumble_ziel and BrakkFortschritt.gross(g):
				_tumble_rest = 0.0   # 19.11.: großer Gegner gefallen – Rolle sofort wieder bereit
				spiel.melde("Großer Gegner gefallen – Rolle wieder bereit!", 2.0)
				Ton.spiele(spiel, "alert", -4.0)
		if tumble_ziel:
			_tumble_treffer_bild(g)
	spiel.schadensquelle = ""
	spiel.brakk_quelle = ""
	spiel.schuss_herkunft = Vector2.INF
	_treffer_gefuehl(von + r * float(getroffen[0][0]), kill)


## 18.11.: Treffer (mittel) und Kill (groß) fühlbar machen.
func _treffer_gefuehl(wo: Vector3, kill: bool) -> void:
	_kreuz = 0.28 if kill else 0.14
	_kreuz_kill = kill
	_funke(wo, 0.16 if kill else 0.1)
	if kill:
		Ton.spiele(spiel, "brakk-kill")
		Ton.spiele(spiel, "hit-pboom", -12.0)   # tiefer Knall darunter (18.11.: leiser)
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


func _strahl(a: Vector3, b: Vector3, farbe: Color = SCHUSS) -> void:
	var mat := _strahl_mat.duplicate() as StandardMaterial3D
	mat.albedo_color = Color(farbe, 0.9)
	mat.emission = farbe
	var m := MeshInstance3D.new()
	var box := BoxMesh.new()
	var lang := maxf(0.01, a.distance_to(b))
	box.size = Vector3(0.025, 0.025, lang)
	m.mesh = box
	m.material_override = mat.duplicate()
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
	f.material_override = mat.duplicate()
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

## 18.11. (Paul): [E] wirft die Lichttreppe aus Abstand an den Erdwall im Blick (bis TREPPE_WEITE Felder). Sie steht
## TREPPE_HALTEN Sekunden; wer an ihren Fuß läuft, steigt hinauf. Steht Brakk schon davor, geht es gleich los.
const TREPPE_WEITE := 5.0
const TREPPE_HALTEN := 8.0
const TREPPE_LAENGER := 2         # 19.11.: so viele Felder darf die Treppe aus der Ferne länger werden
const TREPPE_AUFBAU := 0.45       # so lange springen die Stufen nacheinander auf
var _treppe_aufbau := -1.0        # läuft: Sekunden seit dem Werfen
var _treppe_fuss2d := Vector2.INF # Fußpunkt der stehenden Treppe in der 2D-Logik (INF = keine)


## Wall unter dem Fadenkreuz in Reichweite und das freie Feld davor, das Brakk am nächsten ist: [Wall, Fuß] oder [].
func _treppe_ziel() -> Array:
	if brakk.oben:
		return []
	var von := hd.kamera.global_position
	var r := _blick()
	var t := _strahl_bis(von, r, TREPPE_WEITE + 1.5)
	var p := von + r * (t + 0.03)
	var z := Vector2i(floori(p.x), floori(p.z))
	if not hd.ist_hoch(z) or karte.inhalt(z) != Karte.WALL:
		return []
	if Vector2(z).distance_to(Vector2(karte.zelle_bei(_fuss2d()))) > TREPPE_WEITE + 0.5:
		return []
	var fuss := Karte.KEINE
	var beste := INF
	for n: Vector2i in Karte.NACHBARN:
		var c: Vector2i = z + n
		if karte.in_karte(c) and karte.ist_begehbar(c) and not hd.ist_hoch(c):
			var d := karte.mitte(c).distance_to(_fuss2d())
			if d < beste:
				beste = d
				fuss = c
	if fuss == Karte.KEINE:
		return []
	# 19.11. (Paul): aus der Ferne gesetzt wird die Treppe länger – ihr Fuß rückt (bis TREPPE_LAENGER Felder) auf Brakk zu
	var n2 := fuss - z
	var abstand := Vector2(z).distance_to(Vector2(karte.zelle_bei(_fuss2d())))
	for k in range(1, TREPPE_LAENGER + 1):
		var c2: Vector2i = fuss + n2
		if float(k) + 1.0 > abstand - 0.5 or not karte.in_karte(c2) or not karte.ist_begehbar(c2) or hd.ist_hoch(c2):
			break
		fuss = c2
	return [z, fuss]


func _versuche_klettern(melden: bool) -> bool:
	# an einer stehenden Treppe: hinauf
	if _treppe != null and _treppe_fuss2d != Vector2.INF and _fuss2d().distance_to(_treppe_fuss2d) <= Werte.ZELLE * 1.1:
		_steige_hinauf()
		return true
	if brakk.e_rest > 0.0:
		if melden:
			spiel.melde("Lichttreppe wieder in %.0f s." % ceilf(brakk.e_rest), 2.0)
		return false
	var ziel := _treppe_ziel()
	if ziel.is_empty():
		if melden:
			spiel.melde("Schau auf einen Erdwall (höchstens %d Felder weit)." % int(TREPPE_WEITE), 2.0)
		return false
	_kletter_zelle = ziel[0]
	_treppe_fuss2d = karte.mitte(ziel[1])
	_treppe_fuss = _zu3d(_treppe_fuss2d, 0.0)
	_abwaerts = false
	_baue_treppe()
	_treppe_rest = TREPPE_HALTEN
	brakk.e_rest = float(brakk.daten["kletter_abklingzeit"])
	_trauma = minf(1.0, _trauma + 0.12)
	Ton.spiele(spiel, "tc-arc", -5.0)
	if _fuss2d().distance_to(_treppe_fuss2d) <= Werte.ZELLE * 0.6:
		_steige_hinauf()
	return true


func _steige_hinauf() -> void:
	_kletter_von = _fuss3d()
	_kletter_nach = _zu3d(karte.mitte(_kletter_zelle), hd.H)
	_abwaerts = false
	# direkt vor der Wand wie bisher (0,75 s); je länger die Treppe, desto länger der Aufstieg – nie schneller als TEMPO
	_kletter_dauer = maxf(KLETTER_STEIGEN, _kletter_von.distance_to(_kletter_nach) / TEMPO)
	_klettern = KLETTER_EINSTECKEN   # die Treppe steht schon: gleich steigen
	steig = 0.0


## [E] auf dem Wall – die Lichttreppe führt hinunter auf das freie Feld in Blickrichtung (sonst auf irgendein
## freies Nachbarfeld), genauso sichtbar wie beim Hinaufsteigen.
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
		_treppe_fuss2d = Vector2.INF
		_abwaerts = true
		_kletter_dauer = KLETTER_STEIGEN
		brakk.oben = false   # ab jetzt zählt er als am Boden (die 2D-Logik), die Kamera steigt die Treppe hinab
		brakk.posten_zelle = Karte.KEINE
		brakk.zustand = Einheit.Zustand.BODEN
		_klettern = 0.0
		steig = 0.0
		_baue_treppe()
		_treppe_rest = 0.8 + KLETTER_EINSTECKEN + KLETTER_STEIGEN
		Ton.spiele(spiel, "tc-arc", -5.0)
		return true
	if melden:
		spiel.melde("Kein freies Feld zum Hinuntersteigen.", 2.0)
	return false


func _kletter_weiter(dt: float) -> void:
	_klettern += dt
	if _klettern < KLETTER_EINSTECKEN:
		return
	var f := clampf((_klettern - KLETTER_EINSTECKEN) / _kletter_dauer, 0.0, 1.0)
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
		_rueckstoss[0] = 0.5
		_rueckstoss[1] = 0.5
		return
	if f >= 1.0:
		# oben: wie [E] im Spiel
		_klettern = -1.0
		brakk.oben = true
		brakk.posten_zelle = _kletter_zelle
		brakk.zustand = Einheit.Zustand.AUF_POSTEN
		brakk.position = karte.mitte(_kletter_zelle) + Vector2(0, -12)
		brakk.anker = brakk.position
		hoehe = hd.H
		_rueckstoss[0] = 0.5
		_rueckstoss[1] = 0.5
		_trauma = minf(1.0, _trauma + 0.1)
		spiel.melde("Oben auf dem Wall: mehr Reichweite. [E] = Lichttreppe hinunter, oder zweimal springen: Absprung mit Druckwelle.", 3.0)
		return
	brakk.position = _zu2d(p)


func _leucht(farbe: Color, alpha: float, energie: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(farbe, alpha)
	m.emission_enabled = true
	m.emission = farbe
	m.emission_energy_multiplier = energie
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


## Stufen vom Fuß bis an die Krone, mit leuchtenden Kanten, zwei Geländern und einem Lichtring am Fuß.
func _baue_treppe() -> void:
	if _treppe != null:
		_treppe.queue_free()
	_treppe = Node3D.new()
	hd.add_child(_treppe)
	var lf := _licht_farbe()   # 18.11. (Paul): in der Farbe des aktiven Rings
	var flaeche := _leucht(lf, 0.55, 1.8)
	var kante := _leucht(lf.lightened(0.7), 0.95, 3.0)
	var gelaender := _leucht(lf, 0.8, 2.4)
	var von := _treppe_fuss
	var nach := _zu3d(karte.mitte(_kletter_zelle), 0.0)
	var r := Vector3(nach.x - von.x, 0.0, nach.z - von.z)
	var lang := maxf(0.3, r.length() - 0.5)
	r = r.normalized()
	var quer := Vector3(r.z, 0.0, -r.x)
	var stufen: Array = []
	for i in TREPPE_STUFEN:
		var a := float(i + 1) / float(TREPPE_STUFEN)
		var stufe := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.72, 0.07, lang / TREPPE_STUFEN + 0.04)
		stufe.mesh = box
		stufe.material_override = flaeche
		_treppe.add_child(stufe)
		stufe.position = Vector3(von.x, 0.0, von.z) + r * (lang * (float(i) + 0.5) / TREPPE_STUFEN) + Vector3(0, hd.H * a, 0)
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
	var oben := Vector3(von.x, 0.0, von.z) + r * lang + Vector3(0, hd.H + 0.35, 0)
	for seite: float in [-1.0, 1.0]:
		var g := MeshInstance3D.new()
		var gb := BoxMesh.new()
		var a3 := unten + quer * 0.38 * seite
		var b3 := oben + quer * 0.38 * seite
		gb.size = Vector3(0.03, 0.03, a3.distance_to(b3))
		g.mesh = gb
		g.material_override = gelaender
		_treppe.add_child(g)
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
	ring.material_override = _leucht(lf, 0.9, 2.5)
	_treppe.add_child(ring)
	ring.position = Vector3(von.x, 0.04, von.z)
	ring.set_meta("fussring", true)
	_treppe.set_meta("stufen", stufen)
	_treppe.set_meta("mats", [flaeche, kante, gelaender, ring.material_override])
	_treppe_aufbau = 0.0


## Aufbau (Stufen springen nacheinander mit Überschwung auf, Lichtstrahl aus der Hand), Halten (Fußring pulsiert),
## Ausklingen (die letzten 1,5 s blinkt die Treppe, dann verblasst sie).
func _treppe_weiter() -> void:
	if _treppe == null:
		return
	var dt := get_process_delta_time()
	if _treppe_aufbau >= 0.0:
		_treppe_aufbau += dt
		var stufen: Array = _treppe.get_meta("stufen")
		for i in stufen.size():
			var t0 := TREPPE_AUFBAU * 0.8 * float(i) / float(stufen.size())
			var x := clampf((_treppe_aufbau - t0) / 0.14, 0.0, 1.0)
			var s := 1.0 + 2.70158 * pow(x - 1.0, 3) + 1.70158 * pow(x - 1.0, 2)   # Ease-out-back: kurz über 1, dann 1
			(stufen[i] as Node3D).scale = Vector3(lerpf(0.6, 1.0, x), maxf(0.01, s), lerpf(0.6, 1.0, x))
		if _treppe_aufbau < TREPPE_AUFBAU:
			var oben := _zu3d(karte.mitte(_kletter_zelle), hd.H)
			var hand := hd.kamera.global_position + _blick() * 0.4 - _rechts() * 0.2 - Vector3(0, 0.18, 0)
			_strahl(hand, oben.lerp(_treppe_fuss, 1.0 - _treppe_aufbau / TREPPE_AUFBAU), _licht_farbe())
		else:
			_treppe_aufbau = -1.0
			for c: Node in _treppe.get_children():
				if c.has_meta("gelaender"):
					(c as Node3D).visible = true
			Ton.spiele(spiel, "ui-klick", -4.0)
	# Fußring pulsiert, solange man hinauf kann
	for c: Node in _treppe.get_children():
		if c.has_meta("fussring"):
			var p := 1.0 + 0.15 * sin(Time.get_ticks_msec() / 150.0)
			(c as Node3D).scale = Vector3(p, 1.0, p)
			(c as Node3D).visible = not _abwaerts and not brakk.oben
	if _klettern >= 0.0:
		return
	if _treppe_rest <= 0.0:
		_treppe.queue_free()
		_treppe = null
		_treppe_fuss2d = Vector2.INF
		return
	var sicht := 1.0
	if _treppe_rest < 1.5:
		sicht = (0.35 if int(_treppe_rest * 8.0) % 2 == 0 else 1.0) * clampf(_treppe_rest / 0.5, 0.0, 1.0)
	var mats: Array = _treppe.get_meta("mats")
	var grund := [0.55, 0.95, 0.8, 0.9]
	for i in mats.size():
		(mats[i] as StandardMaterial3D).albedo_color.a = float(grund[i]) * sicht
	# an den Fuß gelaufen: hinauf
	if _treppe_fuss2d != Vector2.INF and not brakk.oben and _absprung < 0.0 and _fuss2d().distance_to(_treppe_fuss2d) <= Werte.ZELLE * 0.4:   # 19.11.: nicht mitten im Absprung
		_steige_hinauf()


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

## 18.11.: Waffen und Hand aus PixelLab (assets/neu/ego); fehlen die Bilder, die gezeichneten Platzhalter.
const PISTOLE_BILD := "res://assets/neu/ego/pistole.png"
const PISTOLE_RECHTS_BILD := "res://assets/neu/ego/pistole_rechts.png"   # 18.11. (Paul): rechte Pistole – Handkanone mit Augen-Linse (PixelLab, in Technoclan-Farben umgefärbt)
const RINGHAND_BILD := "res://assets/neu/ego/ringhand.png"
var _muendung := Vector2(-1, -1)    # Laufmündung im Pistolenbild (Bildpunkte); -1 = Platzhalter (oben Mitte)
var _muendung_rechts := Vector2(-1, -1)   # 18.11.: Mündung der rechten Pistole, falls anders (-1 = wie links)
var _ring_licht := Vector2(15.5, 15.0)   # Leuchtpunkt des Rings im Handbild
var _waffen_teiler := 150.0         # Bildhöhe / Teiler = Bildschirmpunkte je Waffen-Bildpunkt
var _neigung := NEIGUNG

func _baue_oberflaeche() -> void:
	if ResourceLoader.exists(PISTOLE_BILD):
		_tex_pistole = load(PISTOLE_BILD)
		_tex_pistole_links = _tex_pistole   # 18.11. (Paul): links das Original in Technoclan-Farben
		_muendung = Vector2(11, 11)   # leuchtender Emitter oben links
		if ResourceLoader.exists(PISTOLE_RECHTS_BILD):
			_tex_pistole = load(PISTOLE_RECHTS_BILD)
			_muendung_rechts = Vector2(44, 43)   # Augen-Linse der Handkanone
		_waffen_teiler = 200.0        # das Bild ist größer (64×96) als der Platzhalter
		_neigung = 0.0                # schon schräg zur Bildmitte gezeichnet
	else:
		_tex_pistole = ImageTexture.create_from_image(_male_pistole())
		_tex_pistole_links = _tex_pistole   # 18.11. (Paul): links das Original in Technoclan-Farben
	if ResourceLoader.exists(RINGHAND_BILD):
		_tex_ring = load(RINGHAND_BILD)
		_ring_licht = Vector2(22, 5)  # Holoscheibe über den Knöcheln
	else:
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
	if _sieg_t >= 0.0:
		_sieg_bild(_bild.get_viewport_rect().size)   # 19.11.
		return
	if _hud_aus():
		return   # 18.11. (Paul): Übersicht, Pause, Menüs – nur die Tafel, keine Waffen und Leisten davor
	var g := _bild.get_viewport_rect().size
	var px := maxf(2.0, floorf(g.y / 150.0))          # Bildpunkt für Fadenkreuz und Anzeigen
	var wpx := maxf(2.0, floorf(g.y / _waffen_teiler))   # 18.11.: ein Bildpunkt der Waffe in Bildschirmpunkten
	var ts := Vector2(_tex_pistole.get_size()) * wpx
	var wipp := Vector2(cos(_gang * 0.5) * 3.0, absf(sin(_gang * 0.5)) * 4.0) if _geht else Vector2.ZERO
	if kit != null:
		kit.male_waffen(g, wpx)   # 20.11.: Waffen des Anführers statt Brakks Pistolen
	else:
		# rechte Pistole
		var r_rueck := float(_rueckstoss[1])
		var r_pos := Vector2(g.x * 0.80 - ts.x * 0.5, g.y - ts.y + 12.0 * wpx) + wipp + Vector2(r_rueck * 2.0, r_rueck * 6.0) * wpx + (_sway + Vector2(0, 7.0 * _delle)) * wpx   # 19.11.: Sway und Landungsdelle
		r_pos.y += ts.y * 1.1 * _klinge_auf   # 19.11.: Ringklinge – die rechte Pistole steckt weg
		_waffe(_tex_pistole, r_pos, ts, -_neigung, float(_blitz[1]) > 0.0, wpx, false, _glut(), float(_gesperrt[1]) > 0.0)
		# linke Hand: Pistole (gespiegelt) oder Ring – beim Wechsel taucht die eine ab und die andere auf
		var l_rueck := float(_rueckstoss[0])
		var ab := clampf(_ring * 2.0, 0.0, 1.0)              # Pistole sinkt
		var auf := clampf(_ring * 2.0 - 1.0, 0.0, 1.0)       # Ring kommt
		var l_basis := Vector2(g.x * 0.20 - ts.x * 0.5, g.y - ts.y + 12.0 * wpx) + Vector2(-wipp.x, wipp.y) + (_sway * 0.8 + Vector2(0, 7.0 * _delle)) * wpx
		if ab < 1.0:
			var lp := l_basis + Vector2(-l_rueck * 2.0, l_rueck * 6.0) * wpx + Vector2(0, ab * ts.y)
			_waffe(_tex_pistole_links, lp, ts, _neigung, float(_blitz[0]) > 0.0, wpx, true, _glut(), float(_gesperrt[0]) > 0.0)
		if auf > 0.0:
			var rs := Vector2(_tex_ring.get_size()) * wpx
			var rp := Vector2(g.x * 0.22 - rs.x * 0.5, g.y - rs.y + 4.0 * wpx) + Vector2(-wipp.x, wipp.y) + Vector2(0, (1.0 - auf) * rs.y)
			if _saeule_ziel != Vector2.INF or _saeule_zielt:
				var tw := Time.get_ticks_msec() / 1000.0 * 9.0
				rp += Vector2(cos(tw), sin(tw)) * 2.0 * wpx   # die Hand kreist mit
			if brakk.fortschritt != null and brakk.fortschritt.wechsel_rest > 0.0:
				# 18.11. (Paul): Ringwechsel – die Hand rüttelt kurz (abklingend), solange schießt nur rechts
				var w := brakk.fortschritt.wechsel_rest / BrakkFortschritt.WECHSEL_SEK
				var tt := Time.get_ticks_msec() / 1000.0
				rp += Vector2(sin(tt * 47.0) * 3.0, cos(tt * 39.0) * 2.0 - 4.0 * w) * wpx * w
			_bild.draw_texture_rect(_tex_ring, Rect2(rp.round(), rs), false)
			# Ring leuchtet (pulsiert)
			var puls := 0.6 + 0.4 * sin(Time.get_ticks_msec() / 120.0)
			var mitte := rp + _ring_licht * wpx
			_bild.draw_circle(mitte, 5.0 * wpx, Color(LICHT, 0.18 * puls * auf))
			_bild.draw_circle(mitte, 2.5 * wpx, Color(LICHT, 0.35 * puls * auf))
			_ringe_auf_hand(rp, wpx, auf)   # 18.11.
			_finger_wirbel(rp, wpx, auf)   # 18.11.: Lichtsäule
	if _frei():   # 18.11.: bei offenem Menü kein Fadenkreuz und kein Hinweis darüber
		_fadenkreuz(g, px)
	_rand_an()   # 19.11.: Leisten in die sichere Fläche (iPhone: Notch, Home-Balken) – Fadenkreuz und Waffen nicht
	# 19.11.: Die [Tab]-Liste ist im Brakk-Mode klein und darf offen bleiben – am PC rückt die Bauliste darunter,
	# am Handy (wenig Platz) bleibt sie solange weg.
	var liste_offen: bool = spiel._hud != null and spiel._hud.schadensliste != null and spiel._hud.schadensliste.visible
	if touch == null or (touch.bau_offen and not liste_offen):
		_bauliste(g, liste_offen)
	# Zustandszeile unten in der Mitte
	if _klettern >= 0.0:
		Stil.schreibe_mittig(_bild, Vector2(g.x / 2.0, g.y * 0.62), "Lichttreppe", 18, LICHT)
	_brakk_leiste(g)   # 18.11.: Leben, Stufe, Erfahrung
	_werte_fenster(g)   # 19.11.
	_countdown_anzeige(g)   # 18.11.: nächste Welle
	_rand_aus()
	_klinge_bild(g, wpx)   # 19.11.: Ringklinge über den Leisten (nur während der Zeitlupe mit Durchschlagring)
	_respawn_bild(g)   # 19.11.: Countdown, solange Brakk liegt
	_zeitlupe_bild(g)
	if kit != null:
		kit.male_oben(g)   # 20.11.
	if brakk.fortschritt != null:
		_wurf_warnung()   # 18.11.: Steine auf Brakk
		_gefahr_bild(g)
	if touch != null:
		touch.male(_bild)   # 18.11.: Handy – Stick und Knöpfe statt Leisten
		return
	_rand_an()
	_faehigkeiten(g)   # 18.11.: Symbole mit Abklingzeit (20.11., Nachtrag: für jeden Anführer dieselbe Leiste)
	if kit != null:
		kit.male_leisten(g)   # 20.11.: Ringe und Zustand des Anführers
	else:
		_ringleiste(g)   # 18.11.: getragene Ringe
	_rand_aus()


## 19.11.: Zeichnen in der sicheren Fläche an/aus (am PC Identität). Texte über Stil.ebene mit.
func _rand_an() -> void:
	var t := Transform2D(0.0, Vector2.ONE * SichererRand.faktor(), 0.0, SichererRand.versatz())
	Stil.ebene = t
	_bild.draw_set_transform_matrix(t)


func _rand_aus() -> void:
	Stil.ebene = Transform2D.IDENTITY
	_bild.draw_set_transform_matrix(Transform2D.IDENTITY)


const NEIGUNG := 0.2   # die Pistolen zeigen leicht nach innen, zum Fadenkreuz


## Eine Pistole zeichnen: um ihre untere Mitte geneigt, links gespiegelt; Mündungsblitz an der Spitze.
func _waffe(tex: Texture2D, pos: Vector2, ts: Vector2, winkel: float, blitz: bool, px: float, spiegeln: bool, glut: float = 0.0, heiss: bool = false) -> void:
	var mund := _muendung if spiegeln or _muendung_rechts.x < 0.0 else _muendung_rechts   # 18.11.: die rechte Handkanone hat ihre Linse woanders
	var dreh := pos.round() + Vector2(ts.x / 2.0, ts.y)
	_bild.draw_set_transform(dreh, winkel, Vector2(-1.0 if spiegeln else 1.0, 1.0))
	_bild.draw_texture_rect(tex, Rect2(Vector2(-ts.x / 2.0, -ts.y), ts), false)
	if blitz:
		# 18.11.: an der echten Laufmündung des Bilds (Platzhalter: oben Mitte)
		var m := mund if mund.x >= 0.0 else Vector2(ts.x / 2.0 / px - 1.0, 1.0)
		_muendungsblitz(Vector2(-ts.x / 2.0, -ts.y) + m * px, px, LASER_LINKS if spiegeln else SCHUSS)
	if heiss:
		# 18.11.: überhitzt – Mündung glüht rot, Dampf steigt auf
		var mh := mund if mund.x >= 0.0 else Vector2(ts.x / 2.0 / px - 1.0, 1.0)
		var ph := Vector2(-ts.x / 2.0, -ts.y) + mh * px
		var puls := 0.6 + 0.4 * sin(Time.get_ticks_msec() / 70.0)
		_bild.draw_circle(ph, 7.0 * px, Color(1.0, 0.2, 0.1, 0.3 * puls))
		_bild.draw_circle(ph, 3.0 * px, Color(1.0, 0.45, 0.2, 0.8))
		var t := Time.get_ticks_msec() / 1000.0
		for k in 4:
			var a := fmod(t * 1.3 + k * 0.25, 1.0)
			_bild.draw_rect(Rect2(ph + Vector2(sin(t * 3.0 + k) * 3.0, -a * 18.0) * px, Vector2(2, 2) * px), Color(0.85, 0.85, 0.9, 0.5 * (1.0 - a)))
	if glut > 0.0:
		# 18.11.: Ladestrahl lädt – die Mündung glüht an, voll geladen flackert sie weiß
		var mg := mund if mund.x >= 0.0 else Vector2(ts.x / 2.0 / px - 1.0, 1.0)
		var p := Vector2(-ts.x / 2.0, -ts.y) + mg * px
		var voll := glut >= 1.0
		_bild.draw_circle(p, (3.0 + 6.0 * glut) * px, Color(SCHUSS, 0.25 * glut))
		_bild.draw_circle(p, (1.5 + 3.0 * glut) * px, Color.WHITE if voll and Time.get_ticks_msec() % 160 < 80 else Color(SCHUSS, 0.8))
		# 19.11.: Lichtfunken strömen zur Mündung, je voller, desto dichter
		var tt := Time.get_ticks_msec() / 1000.0
		for k in 6:
			var a := fmod(tt * 2.2 + k / 6.0, 1.0)
			var w := k * TAU / 6.0 + tt * 1.5
			var q := p + Vector2(cos(w), sin(w)) * (1.0 - a) * 16.0 * px * (0.4 + 0.6 * glut)
			_bild.draw_rect(Rect2(q - Vector2(px, px) * 0.5, Vector2(px, px)), Color(SCHUSS.lightened(0.4), 0.9 * a))
	_bild.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Schmale Bauliste am linken Rand (statt der Leiste unten): Taste, Name, Preis; das gewählte Werkzeug leuchtet.
func _bauliste(g: Vector2, unter_liste: bool = false) -> void:
	if spiel.order24 != null:
		return   # 20.11.: Befehl 24 – Brakk baut nicht
	if spiel.phase != 0 and spiel.werkzeug == Karte.FREI:
		return   # im Kampf freie Sicht
	var zeile := 34.0
	var breite := 210.0
	var eintraege: Array = []
	for k: Array in spiel._hud.KACHELN:
		if int(k[0]) != Karte.KOMMANDANT:
			eintraege.append(k)
	var oben := (g.y - zeile * eintraege.size()) / 2.0
	if unter_liste:
		oben = maxf(oben, 282.0)   # unter der [Tab]-Liste (links oben)
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
		if typ == Karte.STELLUNG and spiel.freie_stellungen > 0:
			p = "×%d" % spiel.freie_stellungen   # 19.11.: gratis Stellung
		var pf := Stil.GOLD if spiel.budget >= preis else Stil.WARN
		Stil.schreibe(_bild, Vector2(r.end.x - 8.0 - Stil.breite(p, 18), m), p, 18, pf if geht else Stil.TEXT_BLASS)
	Stil.schreibe(_bild, Vector2(x, hinter.end.y + 14.0), "Rechtsklick: weglegen" if touch == null else "nochmal tippen: weglegen", 16, Stil.TEXT_BLASS)


func _muendungsblitz(p: Vector2, px: float, farbe: Color = SCHUSS) -> void:
	var s := px * 3.0
	_bild.draw_rect(Rect2(p - Vector2(s, s * 0.35), Vector2(s * 2.0, s * 0.7)), Color(farbe, 0.9))
	_bild.draw_rect(Rect2(p - Vector2(s * 0.35, s), Vector2(s * 0.7, s * 2.0)), Color(farbe, 0.9))
	_bild.draw_rect(Rect2(p - Vector2(s * 0.5, s * 0.5), Vector2(s, s)), Color.WHITE)


func _fadenkreuz(g: Vector2, px: float) -> void:
	var m := (g / 2.0).round()
	# 19.11. (Paul): Ladering um das Fadenkreuz – füllt sich beim Aufladen, voll geladen blitzt er auf und pulsiert weiß
	var ladung := _glut()
	if ladung > 0.0:
		var rr := 13.0 * px
		var seit := Time.get_ticks_msec() - _lade_voll_ms
		var voll := ladung >= 1.0
		_bild.draw_arc(m, rr, 0.0, TAU, 48, Color(1, 1, 1, 0.14), px)
		_bild.draw_arc(m, rr, -PI / 2.0, -PI / 2.0 + TAU * ladung, 48, Color.WHITE if voll and Time.get_ticks_msec() % 240 < 120 else SCHUSS, 1.5 * px)
		if voll and seit < 300:
			_bild.draw_arc(m, rr + seit / 300.0 * 12.0 * px, 0.0, TAU, 48, Color(1, 1, 1, 1.0 - seit / 300.0), px)
		if voll:
			Stil.schreibe_mittig(_bild, m - Vector2(0, rr + 6.0 * px), "loslassen", 16, Color.WHITE)
	if _feld_zielt and brakk.fortschritt != null and not brakk.fortschritt.ringe.is_empty():
		var fr := brakk.fortschritt.ringe[clampi(brakk.fortschritt.gewaehlt, 0, brakk.fortschritt.ringe.size() - 1)]
		Stil.schreibe_mittig(_bild, m + Vector2(0, 26.0 * px), ("%s-Feld: %d/4 Fabriken · „Setzen“ tippen · „Abbruch“" if touch != null else "%s-Feld: %d/4 Fabriken · [C] / Linksklick setzen · Rechtsklick / Esc abbrechen") % [str(BrakkFortschritt.RINGE[fr]["name"]), _feld_fabriken(_feld_ecke).size()], 18, _ring_farbe(fr))   # 19.11.
	if _saeule_zielt:
		Stil.schreibe_mittig(_bild, m + Vector2(0, 26.0 * px), "Linksklick: Lichtsäule setzen · [X] / Rechtsklick: abbrechen", 18, _saeule_farbe)   # 18.11.
	if spiel.werkzeug != Karte.FREI:
		var ziel := ziel_welt()
		var nah := ziel.x > -9000.0 and _in_reichweite(karte.zelle_bei(ziel))
		var f := LICHT if nah else Color("ff5a6e")
		var s := 6.0 * px
		_bild.draw_rect(Rect2(m - Vector2(s, s), Vector2(s * 2.0, s * 2.0)), f, false, px * 0.5)
		if not nah:
			Stil.schreibe_mittig(_bild, m + Vector2(0, s + 10.0 * px), "zu weit", 18, f)
		return
	if kit == null:
		_hitze_anzeige(m, px)   # 18.11.; 20.11.: andere Anführer zeigen ihre eigene Hitze
	var treppe_an := hat_aktion("treppe")   # 20.11.: nur wer die Lichttreppe hat
	var gb := gebaeude_im_blick()   # 18.11.: Hinweis zum Ausbauen
	if gb != Karte.KEINE:
		Stil.schreibe_mittig(_bild, m + Vector2(0, 12.0 * px), _t("[F] %s ausbauen" % _gebaeude_name(gb)), 18, LICHT)
	elif treppe_an and not brakk.oben and _klettern < 0.0 and brakk.e_rest <= 0.0 and not _treppe_ziel().is_empty():
		Stil.schreibe_mittig(_bild, m + Vector2(0, 12.0 * px), _t("[E] Lichttreppe"), 18, LICHT)   # 18.11.
	elif treppe_an and brakk.oben and _klettern < 0.0 and _bruecke == null and not _bruecke_ziel().is_empty():
		var bt := "[E] Lichtbrücke" if _bruecke_cd <= 0.0 else "Lichtbrücke in %.0f s" % ceilf(_bruecke_cd)
		Stil.schreibe_mittig(_bild, m + Vector2(0, 12.0 * px), _t(bt), 18, LICHT if _bruecke_cd <= 0.0 else Stil.TEXT_BLASS)   # 18.11.
	elif treppe_an and brakk.oben and _klettern < 0.0 and _bruecke == null and brakk.e_rest <= 0.0:
		Stil.schreibe_mittig(_bild, m + Vector2(0, 12.0 * px), _t("[E] Lichttreppe hinunter"), 18, LICHT)   # 19.11.: statt der Vorschau-Bahn nur der Hinweis
	elif kit != null and kit.hinweis() != "":
		Stil.schreibe_mittig(_bild, m + Vector2(0, 12.0 * px), kit.hinweis(), 18, LICHT)   # 20.11.
	elif _am_terminal():
		Stil.schreibe_mittig(_bild, m + Vector2(0, 12.0 * px), _t("[F] Lichtterminal – Ringe kaufen"), 18, LICHT)
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
	if _hud_aus() or _sieg_t >= 0.0:
		return
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
	for gg: Gegner in spiel.ego_gegner():
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


# ------------------------------------------------------------------ Brakk-Mode: Stufen (18.11.)

func _schaden_faktor() -> float:
	return brakk.fortschritt.schuss_schaden() if brakk.fortschritt != null else 1.0


## 19.11. (Paul): Fähigkeiten (Lichtsäule, Ladestrahl) – nur der aktive Ring zählt, die Ringe stapeln sich nur für die Schüsse.
func _faehigkeit_faktor() -> float:
	return brakk.fortschritt.faehigkeit_schaden() if brakk.fortschritt != null else 1.0


## Pause zwischen zwei Schüssen (Anteil): Taktring 0,8, Wirbelring läuft im Dauerfeuer bis 1/1,6 an.
func _takt_faktor() -> float:
	var f := brakk.fortschritt
	if f == null:
		return 1.0
	var zl := 1.0 / float(BrakkFortschritt.ZEITLUPE_RING["laser"]["touch_takt"]) if touch != null and _zl_aktiv("laser") else 1.0   # 19.11.: am Handy ohne Hitze – schneller
	return f.schuss_takt() * lerpf(1.0, 1.0 / float(f.brakk_wert("anlauf", 1.0)), _wirbel) * zl


## Wirkung der Ringe auf einen Treffer von Brakk (Abpraller, Brand, Gel).
func _ring_treffer(g: Gegner, schaden: float) -> void:
	var f := brakk.fortschritt
	if f == null or not is_instance_valid(g):
		return
	var mark_sek := float(f.brakk_wert("mark_sek", 0.0))
	if mark_sek > 0.0 and not g._tot and (g.markiert <= 0.0 or g.markiert_brakk):
		# 19.11. (Paul): Zielring – Treffer markieren, alle anderen Quellen richten mehr Schaden an
		g.markiert = maxf(g.markiert, mark_sek)
		g.markier_faktor = float(f.brakk_wert("mark_bonus", 1.0))
		g.markiert_brakk = true
	var bremse := float(f.brakk_wert("bremse", 0.0))
	if bremse > 0.0 and not g._tot:
		g.gebremst = maxf(g.gebremst, bremse)
	var vorher_q: String = spiel.brakk_quelle
	spiel.brakk_quelle = "ring"   # 19.11.: Brand und Abpraller zählen als Ringeffekt
	var brand_takt := float(f.brakk_wert("brand_takt", 0.0))
	if brand_takt > 0.0 and Time.get_ticks_msec() >= _brand_ab:
		# 18.11. (Paul, Schießstand): höchstens ein neues Brandfeld je brand_takt – sonst stapeln sie sich
		_brand_ab = Time.get_ticks_msec() + int(brand_takt * 1000.0)
		spiel.lege_brand(g.position, Werte.ZELLE * 0.5, schaden * 0.3)
	var spruenge := int(f.brakk_wert("spruenge", 0))
	if spruenge > 0:
		_brakk_sprung(g, spruenge, schaden * float(f.brakk_wert("sprung_anteil", 0.6)))
	spiel.brakk_quelle = vorher_q


## Ein Gegner fällt durch Brakks Schuss: Erfahrung (große Gegner mehr).
func _kill(g: Gegner) -> void:
	var f := brakk.fortschritt
	if f == null:
		return
	if f.frei("ulti") and spiel.welle >= f.ulti_ab_welle:
		f.ulti_ladung = mini(f.ulti_ladung + 1, BrakkFortschritt.ULTI_KILLS)   # Kills vor der Freischaltung zählen nicht
	# 18.11. (Paul): bei dreifacher Gegnerzahl nur die halbe Erfahrung je Kill (Bruchteile werden gesammelt)
	f.kill_xp += float(BrakkFortschritt.XP_KILL + int(g.daten.get("praemie", 0)) / 5) * BrakkFortschritt.XP_KILL_ANTEIL * (spiel.order24.wf("kill_xp_prozent") / 100.0 if spiel.order24 != null else 1.0)   # 20.11. (Paul): Befehl 24 – Stufen nicht zu schnell
	var xp := floori(f.kill_xp)
	f.kill_xp -= float(xp)
	if xp > 0 and f.gib(xp, brakk) > 0:
		Ton.spiele(spiel, "ui-klick", 4.0)
		Ton.spiele(spiel, "alert", -6.0)


## Unten in der Mitte zwischen den Pistolen: Stufe, Leben, Erfahrung – und nach einem Aufstieg ein Banner.
func _brakk_leiste(g: Vector2) -> void:
	var f := brakk.fortschritt
	if f == null:
		return
	var breite := clampf(g.x * 0.26, 260.0, 460.0)
	var x := (g.x - breite) / 2.0
	var y := roundf(g.y * 0.86) - 34.0   # über dem Meldungsfeld und der Bauleisten-Lasche
	# Stufe als Abzeichen links
	var abz := Rect2(x - 58.0, y - 6.0, 50.0, 40.0)
	_bild.draw_rect(abz, Color(0.04, 0.05, 0.08, 0.75))
	_bild.draw_rect(abz, Stil.GOLD, false, 2.0)
	Stil.schreibe_mittig(_bild, abz.get_center() + Vector2(0, -8), "St.", 16, Stil.TEXT_BLASS)
	Stil.schreibe_mittig(_bild, abz.get_center() + Vector2(0, 8), str(f.stufe), 22, Stil.GOLD)
	# Leben
	var anteil := clampf(brakk.leben / maxf(1.0, brakk.max_leben), 0.0, 1.0)
	var lb := Rect2(x, y - 6.0, breite, 22.0)   # 18.11. (Paul): kräftiger, mit heller Spur des Verlusts
	_bild.draw_rect(lb.grow(3.0), Color(0.04, 0.05, 0.08, 0.85))
	if _leben_spur > brakk.leben:
		_bild.draw_rect(Rect2(lb.position, Vector2(lb.size.x * clampf(_leben_spur / maxf(1.0, brakk.max_leben), 0.0, 1.0), lb.size.y)), Color(1.0, 0.9, 0.75, 0.85))
	_bild.draw_rect(Rect2(lb.position, Vector2(lb.size.x * anteil, lb.size.y)), Color("8fe39a") if anteil > 0.35 else Stil.ROT)
	Stil.schreibe_mittig(_bild, lb.get_center(), "%d / %d" % [ceili(maxf(brakk.leben, 0.0)), roundi(brakk.max_leben)], 18, Color.WHITE)
	_bild.draw_rect(lb.grow(3.0), Color(1.0, 0.35, 0.35, _treffer_rot) if _treffer_rot > 0.05 else Color(1, 1, 1, 0.25), false, 2.0)
	# Erfahrung
	var xb := Rect2(x, y + 24.0, breite, 6.0)
	_bild.draw_rect(xb.grow(1.0), Color(0.04, 0.05, 0.08, 0.75))
	_bild.draw_rect(Rect2(xb.position, Vector2(xb.size.x * f.anteil(), xb.size.y)), Stil.GOLD)
	# Banner nach dem Aufstieg
	if f.aufstieg_zeit >= 0.0:
		var a := clampf(minf(f.aufstieg_zeit * 4.0, (3.5 - f.aufstieg_zeit) * 2.0), 0.0, 1.0)
		var m := Vector2(g.x / 2.0, g.y * 0.26)
		_bild.draw_rect(Rect2(m.x - 230.0, m.y - 32.0, 460.0, 80.0 + 22.0 * f.neu_frei.size()), Color(0.04, 0.05, 0.08, 0.6 * a))
		Stil.schreibe_mittig(_bild, m, "STUFE %d" % f.stufe, 40, Color(Stil.GOLD, a))
		var zeile := "+%d %% Schaden · +%d Leben" % [roundi(BrakkFortschritt.SCHADEN_JE_STUFE * 100.0), roundi(BrakkFortschritt.LEBEN_JE_STUFE)]
		Stil.schreibe_mittig(_bild, m + Vector2(0, 34), zeile, 18, Color(Stil.TEXT, a))
		for i in f.neu_frei.size():
			Stil.schreibe_mittig(_bild, m + Vector2(0, 58 + 22 * i), _t("Neu: " + BrakkFortschritt.faehigkeit_name(f.anfuehrer, f.neu_frei[i])), 20, Color(LICHT, a))


# ------------------------------------------------------------------ Brakk-Mode: Tumble und Ladestrahl (18.11.)

## Darf Brakk das schon? Außerhalb des Brakk-Mode gibt es keine Stufen: alles frei. Sonst Hinweis, ab welcher Stufe.
func _darf(was: String) -> bool:
	var f := brakk.fortschritt
	if f == null or f.frei(was):
		return true
	spiel.melde(_t("%s gibt es ab Stufe %d." % [BrakkFortschritt.faehigkeit_name(f.anfuehrer, was), int(BrakkFortschritt.ab_tabelle(f.anfuehrer)[was])]), 2.5)
	return false


## [Shift]: Hechtrolle in Laufrichtung (ohne Taste nach vorn), kurz unverwundbar.
func _tumble_start() -> void:
	if _tumble >= 0.0 or _klettern >= 0.0 or _anker >= 0.0 or not _darf("tumble"):
		return
	if _tumble_rest > 0.0:
		return
	var r := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_W):
		r.y += 1.0
	if Input.is_physical_key_pressed(KEY_S):
		r.y -= 1.0
	if Input.is_physical_key_pressed(KEY_D):
		r.x += 1.0
	if Input.is_physical_key_pressed(KEY_A):
		r.x -= 1.0
	if touch != null:
		r += touch.stick()
	if r.length() < 0.2:
		r = Vector2(0, 1)
	r = r.normalized()
	_tumble_seite = r.x
	var v := _vorne() * r.y + _rechts() * r.x
	_tumble_r = Vector2(v.x, v.z).normalized()
	_tumble = 0.0
	_zaehle("rollen")   # 19.11.: Sieg-Übersicht
	_tumble_rest = TUMBLE_ABKLING
	brakk.unverwundbar = Werte.BRAKK_TUMBLE_DURCHLASS   # 20.11.: Schritt 6c – 0,25 s (vorher 0,4), Geschosse gehen hindurch
	_trauma = minf(1.0, _trauma + 0.15)
	Ton.spiele(spiel, "hit-thud", -6.0)


func _tumble_weiter(dt: float) -> void:
	_tumble += dt
	var schritt := _tumble_r * TUMBLE_FELDER / TUMBLE_DAUER * Werte.ZELLE * dt
	_schritt(Vector2(schritt.x, 0.0))
	_schritt(Vector2(0.0, schritt.y))
	_fallen(dt)
	if _tumble >= TUMBLE_DAUER:
		_tumble = -1.0
		_schwung = SCHWUNG_SEK   # 19.11. (Paul): nach der Rolle kurz schneller
		_tumble_schuss_bis = Time.get_ticks_msec() + int(float(BrakkFortschritt.TUMBLE_SCHUSS["fenster"]) * 1000.0)   # 19.11.: der nächste Schuss ist verstärkt
		_rueckstoss[0] = 0.6
		_rueckstoss[1] = 0.6


func _glut() -> float:
	return clampf(_lanze / LANZE_LADEN, 0.0, 1.0) if _lanze >= 0.0 else 0.0


## Rechtsklick ohne Werkzeug: gedrückt halten lädt den Ladestrahl, Loslassen feuert (nur voll geladen).
func _lanze_taste(gedrueckt: bool) -> void:
	if gedrueckt:
		if _lanze >= 0.0 or _klettern >= 0.0 or not _darf("lanze"):
			return
		if _lanze_rest > 0.0:
			spiel.melde("Ladestrahl wieder in %.0f s." % ceilf(_lanze_rest), 1.5)
			return
		if float(_gesperrt[0]) > 0.0 or float(_gesperrt[1]) > 0.0:
			spiel.melde("Überhitzt – der Ladestrahl braucht beide Pistolen.", 1.5)
			return
		_lanze = 0.0
		Ton.spiele(spiel, "tc-arc", -8.0)
		return
	if _lanze < 0.0:
		return
	var voll := _lanze >= LANZE_LADEN
	_lanze = -1.0
	if voll:
		_lanze_feuer()


## Beide Pistolen zugleich: ein Strahl durch alle Gegner in der Linie bis zur nächsten Mauer.
func _lanze_feuer() -> void:
	_lanze_rest = LANZE_ABKLING
	_zaehle("lanzen")
	# 18.11.: die Lanze lässt die angestaute Hitze ab – je heißer, desto stärker (bis doppelt), danach sind beide kalt
	var lanze_hitze := 1.0 + (float(_hitze[0]) + float(_hitze[1])) / 2.0
	if touch != null:
		lanze_hitze = LANZE_TOUCH   # 18.11.: am Handy gibt es keine Hitze
	_hitze = [0.0, 0.0]
	var von := hd.kamera.global_position
	var r := _schuss_blick()
	var weite := _strahl_bis(von, r, LANZE_WEITE)
	var ende := von + r * weite
	var kills := 0
	var treffer := 0
	spiel.schadensquelle = "fabrik:-1,-1"
	spiel.brakk_quelle = "lanze"   # 19.11.
	spiel.schuss_herkunft = brakk.position
	for g: Gegner in spiel.ego_gegner().duplicate():
		if not is_instance_valid(g) or g._tot:
			continue
		var c := _ziel_mitte(g)
		var t := (c - von).dot(r)
		if t <= 0.0 or t >= weite or (von + r * t).distance_to(c) > _ziel_radius(g, 0.45):
			continue
		# 19.11. (Paul): dazu ein Anteil des maximalen Lebens (große Gegner weniger) – trägt die Lanze ins späte Spiel
		var anteil := float(BrakkFortschritt.LANZE_ANTEIL["gross" if BrakkFortschritt.gross(g) else "normal"])
		g.nimm_schaden(LANZE_SCHADEN * _faehigkeit_faktor() * lanze_hitze * _gel_bonus(g, true) + g.max_leben * anteil)
		treffer += 1
		if g._tot:
			kills += 1
			_kill(g)
	spiel.schadensquelle = ""
	spiel.brakk_quelle = ""
	spiel.schuss_herkunft = Vector2.INF
	for seite: float in [-1.0, 1.0]:
		var m := von + r * 0.5 + _rechts() * 0.16 * seite - Vector3(0, 0.14, 0)
		var lf := LASER_LINKS if seite < 0.0 else SCHUSS
		_strahl(m, ende, lf)
		_strahl(m + Vector3(0, 0.02, 0), ende, lf)
	_funke(ende, 0.3)
	_rueckstoss[0] = 1.0
	_rueckstoss[1] = 1.0
	_blitz[0] = 0.1
	_blitz[1] = 0.1
	_kick += 0.08
	_fov_puls = maxf(_fov_puls, 6.0)
	_trauma = minf(1.0, _trauma + 0.5)
	Ton.spiele(spiel, "tc-rail", -8.0)
	if treffer > 0:
		_treffer_gefuehl(ende, kills > 0)


# ------------------------------------------------------------------ Brakk-Mode: Fähigkeiten-Leiste (18.11.)

## Kleine Pixelsymbole (Platzhalter bis zu den PixelLab-Bildern): # voll, + dunkler.
## 20.11. (Nachtrag): auch für Irrtürmer und Sonde 7 – gleiche Leiste, gleiche Anordnung wie bei Brakk.
const GLYPHEN := {
	"tumble": ["..##....", ".#..#.#.", "#....###", "#.....#.", ".#..#...", "..##....", "........"],
	"anker": ["....###", ".....##", "....#.#", "...#...", "..#....", "##.....", "##....."],
	"lanze": ["#......", ".##....", "..###..", "...####", "..###..", ".##....", "#......"],
	"saeule": ["..###..", "..#.#..", "..###..", "..###..", "..###..", ".#####.", "#######"],
	"zeitlupe": ["#######", ".#...#.", "..#.#..", "...#...", "..#.#..", ".#.#.#.", "#######"],
	"ulti": ["###.+++", "#.#.+.+", "###.+++", "...#...", "+++.###", "+.+.#.#", "+++.###"],
	"treppe": [".....##", "....##.", "...##..", "..##...", ".##....", "##.....", "#######"],
	"hack": [".#...#.", "..#.#..", "#######", "#.+.+.#", "#######", "..#.#..", ".#...#."],
	"ueberladen": ["....##.", "...##..", "..##...", ".######", "...##..", "..##...", ".##...."],
	"hierher": ["...#...", "...#...", "...#...", "#.###.#", ".#####.", "..###..", "+++#+++"],
	"ringtausch": ["..#....", ".######", "..#....", ".......", "....#..", "######.", "....#.."],
	"aufsatz": ["..###..", ".##+##.", "..###..", "...#...", "..###..", ".#####.", "#######"],
	"hand_rechts": [".......", "..###..", ".#####.", ".##+##.", ".#####.", "..###..", "......."],
	"schub": ["#..#...", ".#..#..", "..#..#.", "...#..#", "..#..#.", ".#..#..", "#..#..."],
	"teleport": [".#.#.#.", "#.....#", "...#...", "#.###.#", "...#...", "#.....#", ".#.#.#."],
	"doppellaser": ["##.....", "#######", "##.....", ".......", "##.....", "#######", "##....."],
	"schrot": ["....#..", "...#..#", "##.#...", "####..#", "##.#...", "...#..#", "....#.."],
	"sondengewehr": ["..###..", ".#...#.", "#..#..#", "#.###.#", "#..#..#", ".#...#.", "..###.."],
	"luftschlag": ["#..#..#", "#..#..#", ".......", ".#..#..", ".#..#..", ".......", "#######"],
}
## Reihenfolge der Leiste (wie bei Brakk): Taste der Belegung und Beschriftung.
const LEISTE_TASTEN: Array[String] = ["shift", "Q", "rechts", "R", "X", "V", "E"]
const LEISTE_NAME := {"shift": "Shift", "rechts": "RMB"}


func _glyphe(art: String, mitte: Vector2, px: float, farbe: Color) -> void:
	if not GLYPHEN.has(art):
		return
	var b: Array = GLYPHEN[art]
	var o := (mitte - Vector2((b[0] as String).length(), b.size()) * px / 2.0).round()
	for y in b.size():
		var z: String = b[y]
		for x in z.length():
			if z[x] != ".":
				_bild.draw_rect(Rect2(o + Vector2(x, y) * px, Vector2(px, px)), farbe if z[x] == "#" else farbe.darkened(0.4))


## Über der Lebensleiste: je Fähigkeit ein Kästchen mit Taste; Abklingzeit als dunkle Füllung, gesperrt grau mit Stufe.
## 20.11. (Nachtrag): bei Irrtürmer und Sonde 7 liefert das Kit je Aktion [Rest 0..1, Text darüber, läuft gerade].
func _faehigkeiten(g: Vector2) -> void:
	var f := brakk.fortschritt
	if f == null:
		return
	var liste: Array = []
	if kit == null:
		liste = [
			["tumble", "Shift", _tumble_rest / TUMBLE_ABKLING, "", false],
			["anker", "Q", _anker_rest / (ANKER_ABKLING * _mobil()), "", false],
			["lanze", "RMB", _lanze_rest / LANZE_ABKLING, "", false],
			["ulti", "R", _ulti_rest(), "", false],
			["saeule", "X", _saeule_rest / SAEULE_ABKLING, "", false],
			["zeitlupe", "V", _zeitlupe_rest / ZEITLUPE_ABKLING, "", false],
			["treppe", "E", brakk.e_rest / maxf(1.0, float(brakk.daten["kletter_abklingzeit"])), "", false],
		]
	else:
		var tasten: Dictionary = Werte.ANFUEHRER_EGO[anfuehrer()]["tasten"]
		for t: String in LEISTE_TASTEN:
			var was := str(tasten.get(t, ""))
			if was == "":
				continue
			var info := kit.leiste_info(was) if was != "treppe" else [brakk.e_rest / maxf(1.0, float(brakk.daten["kletter_abklingzeit"])), "", false]
			if was == "tumble":
				info = [_tumble_rest / TUMBLE_ABKLING, "", false]
			liste.append([was, str(LEISTE_NAME.get(t, t)), info[0], info[1], info[2]])
	var s := 46.0
	var abst := 10.0
	var breite := liste.size() * s + (liste.size() - 1) * abst
	var y := roundf(g.y * 0.86) - 34.0 - 16.0 - s
	var x := roundf((g.x - breite) / 2.0)
	var an_farbe := kit.leiste_farbe() if kit != null else LICHT
	for i in liste.size():
		var e: Array = liste[i]
		var art: String = e[0]
		var r := Rect2(x + i * (s + abst), y, s, s)
		var offen := art == "treppe" or f.frei(art)
		var rest := clampf(float(e[2]), 0.0, 1.0)
		var an := bool(e[4]) and offen
		_bild.draw_rect(r, Color(0.04, 0.05, 0.08, 0.75))
		var farbe := LICHT if offen and rest <= 0.0 else (Stil.TEXT_BLASS if offen else Color(0.35, 0.37, 0.42))
		if art == "ulti" and offen and rest <= 0.0:
			farbe = Color("c9a6ff")
		if an:
			farbe = an_farbe
			_bild.draw_rect(r, Color(an_farbe, 0.18))
		_glyphe(art, r.get_center() - Vector2(0, 4), 4.0, farbe)
		if offen and rest > 0.0:
			_bild.draw_rect(Rect2(r.position + Vector2(0, s * (1.0 - rest)), Vector2(s, s * rest)), Color(0, 0, 0, 0.55))
		_bild.draw_rect(r, farbe if offen else Color(0.3, 0.32, 0.36), false, 2.0)
		if art == "ulti" and offen and rest > 0.0:
			var txt := "%d/%d" % [f.ulti_ladung, BrakkFortschritt.ULTI_KILLS] if spiel.welle >= f.ulti_ab_welle else "ab R.%d" % f.ulti_ab_welle
			Stil.schreibe_mittig(_bild, Vector2(r.get_center().x, r.position.y - 9.0), txt, 14, Color("c9a6ff"))
		elif offen and str(e[3]) != "":
			Stil.schreibe_mittig(_bild, Vector2(r.get_center().x, r.position.y - 9.0), str(e[3]), 14, an_farbe if an else Stil.TEXT_BLASS)
		if offen:
			Stil.schreibe_mittig(_bild, Vector2(r.get_center().x, r.end.y - 7.0), str(e[1]), 14, Color.WHITE)
		else:
			Stil.schreibe_mittig(_bild, Vector2(r.get_center().x, r.end.y - 7.0), "St.%d" % int(BrakkFortschritt.ab_tabelle(f.anfuehrer)[art]), 14, Stil.TEXT_BLASS)


## Ulti [R]: Anteil, der noch fehlt (0 = bereit).
func _ulti_rest() -> float:
	if brakk.fortschritt == null:
		return 0.0 if not brakk.klon_genutzt else 1.0
	return brakk.fortschritt.ulti_rest(spiel.welle)


## [R] im Brakk-Mode: die Klonmaschine ist die Ulti – ab Stufe 7, geladen durch eigene Kills, danach eine Runde Pause.
func _ulti() -> void:
	var f := brakk.fortschritt
	var grund := f.ulti_grund(spiel.welle)
	if grund != "":
		spiel.melde(grund, 2.5)
		return
	var text: String = spiel.stelle_klonmaschine(karte.zelle_bei(ziel_welt(true)))
	spiel._kommandant_meldung(text)
	if spiel.klonmaschine != null and brakk.klon_genutzt:
		f.ulti_benutzt(spiel.welle)
		_trauma = minf(1.0, _trauma + 0.3)
		Ton.spiele(spiel, "alert")


# ------------------------------------------------------------------ Brakk-Mode: Ringe und Lichtterminal (18.11.)

## Ring zeichnen: sein Pixelbild (ring_bilder.gd, nach Pauls Entwürfen) mit Schein in der Ringfarbe.
func _male_ring(ci: CanvasItem, m: Vector2, r: float, ring: String, hell: float = 1.0) -> void:
	var farbe := _ring_farbe(ring)
	ci.draw_circle(m, r * 1.5, Color(farbe, 0.2 * hell))
	var gr := roundf(r * 2.4 / 16.0) * 16.0 if r * 2.4 >= 16.0 else r * 2.4
	ci.draw_texture_rect(RingBilder.bild(ring, farbe), Rect2((m - Vector2(gr, gr) / 2.0).round(), Vector2(gr, gr)), false, Color(1, 1, 1, hell))


func _ring_farbe(ring: String) -> Color:
	return Einheit.ABZEICHEN.get(ring, LICHT)


## Rechter Rand, unter der Minikarte: je Finger ein Platz – Ring mit Namen, frei oder gesperrt (ab Stufe).
func _ringleiste(g: Vector2) -> void:
	var f := brakk.fortschritt
	if f == null:
		return
	var zeile := 40.0
	var breite := 220.0
	var x := g.x - breite - 14.0
	var y := roundf(g.y * 0.36)
	var hinter := Rect2(x - 6.0, y - 30.0, breite + 12.0, zeile * 5.0 + 36.0)
	_bild.draw_rect(hinter, Color(0.04, 0.05, 0.08, 0.6))
	Stil.schreibe(_bild, Vector2(x, y - 14.0), "RINGE", 18, Stil.GOLD)
	for i in 5:
		var r := Rect2(x, y + i * zeile, breite, zeile - 4.0)
		var mi := Vector2(r.position.x + 20.0, r.get_center().y)
		if i < f.ringe.size():
			var ring := f.ringe[i]
			var farbe := _ring_farbe(ring)
			_bild.draw_rect(r, Color(farbe, 0.12))
			if i == f.gewaehlt:
				_bild.draw_rect(r, farbe, false, 2.0)   # aktiv: wirkt auf Brakks Pistolen, [C] setzt sein Feld
			var zusatz := "St.%d" % f.ring_stufe(ring) + (" · Feld" if f.felder.has(ring) else "")
			Stil.schreibe(_bild, Vector2(r.end.x - 8.0 - Stil.breite(zusatz, 14), r.get_center().y), zusatz, 14, farbe)
			_male_ring(_bild, mi, 13.0, ring)
			Stil.schreibe(_bild, Vector2(r.position.x + 40.0, r.get_center().y), str(BrakkFortschritt.RINGE[ring]["name"]), 18, farbe)
		elif i < f.finger():
			_bild.draw_arc(mi, 9.0, 0.0, TAU, 20, Stil.TEXT_BLASS, 1.5)
			Stil.schreibe(_bild, Vector2(r.position.x + 40.0, r.get_center().y), "frei – Terminal", 16, Stil.TEXT_BLASS)
		else:
			_bild.draw_arc(mi, 9.0, 0.0, TAU, 20, Color(0.3, 0.32, 0.36), 1.5)
			Stil.schreibe(_bild, Vector2(r.position.x + 40.0, r.get_center().y), "ab Stufe %d" % int(BrakkFortschritt.FINGER_AB[i]), 16, Color(0.4, 0.42, 0.47))
	if not f.ringe.is_empty():
		Stil.schreibe(_bild, Vector2(x, hinter.end.y + 12.0), "Mausrad: aktiver Ring" if spiel.order24 != null else "Mausrad: aktiver Ring · [C] Feld (Bauphase)", 14, Stil.TEXT_BLASS)


## Steht Brakk in der Bauphase an der Basis? Dann öffnet [F] das Lichtterminal.
func _am_terminal() -> bool:
	if spiel.order24 != null:
		return brakk.fortschritt != null and not brakk.oben and spiel.order24.am_terminal(_fuss2d())   # 20.11.: Ringterminal in Order 24, auch im Kampf
	if brakk.fortschritt == null or spiel.phase != 0 or karte.basis == Karte.KEINE or brakk.oben:
		return false
	return _fuss2d().distance_to(karte.mitte(karte.basis)) <= 2.5 * Werte.ZELLE


func _terminal_auf() -> void:
	if _terminal == null:
		_terminal = Control.new()
		_terminal.set_anchors_preset(Control.PRESET_FULL_RECT)
		_terminal.mouse_filter = Control.MOUSE_FILTER_STOP
		_terminal.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_terminal.draw.connect(_male_terminal)
		_terminal.gui_input.connect(_terminal_klick)
		_ebene.add_child(_terminal)
	_terminal.visible = true
	_terminal.queue_redraw()
	_feuer = false
	_lanze = -1.0
	Ton.spiele(spiel, "ui-klick")


func _terminal_klick(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var b := event as InputEventMouseButton
	if not b.pressed or b.button_index != MOUSE_BUTTON_LEFT:
		return
	for k: Array in _knoepfe:
		if (k[0] as Rect2).has_point(b.position):
			(k[1] as Callable).call()
			Ton.spiele(spiel, "ui-klick")
			_terminal.queue_redraw()
			return


func _kaufe(ring: String) -> void:
	var grund := brakk.fortschritt.kaufe(ring, spiel)
	if grund != "":
		spiel.melde(grund, 2.5)
	else:
		var st := brakk.fortschritt.ring_stufe(ring)
		spiel.melde(("%s angesteckt." if st == 1 else "%s auf Stufe " + str(st) + ".") % str(BrakkFortschritt.RINGE[ring]["name"]), 2.5)

## 20.11. (Nachtrag): Irrtürmer – Kauf in den gewählten Satz (Held oder PliPlop), Ausbau und Verkauf je Stelle.
var _kauf_satz := "held"


func _kaufe_satz(ring: String) -> void:
	var grund := brakk.fortschritt.kaufe_in(_kauf_satz, ring, spiel)
	spiel.melde(grund if grund != "" else "%s für %s." % [str(BrakkFortschritt.RINGE[ring]["name"]), "den Irrtürmer" if _kauf_satz == "held" else "PliPlop"], 2.5)


func _baue_satz_aus(satz: String, i: int) -> void:
	var grund := brakk.fortschritt.baue_aus(satz, i, spiel)
	if grund != "":
		spiel.melde(grund, 2.5)


func _verkaufe_satz(satz: String, i: int) -> void:
	brakk.fortschritt.verkaufe_in(satz, i, spiel)


func _waehle_satz(satz: String, i: int) -> void:
	if satz == "pp":
		brakk.fortschritt.waehle_pp(i)
	else:
		brakk.fortschritt.gewaehlt = i
		brakk.fortschritt.wechsel_rest = BrakkFortschritt.WECHSEL_SEK


func _verkaufe(ring: String) -> void:
	brakk.fortschritt.verkaufe(ring, spiel)


func _terminal_zu() -> void:
	_terminal.visible = false


## Tafel in der Mitte: links Brakks Finger (Verkaufen), rechts alle Ringe (Kaufen).
func _male_terminal() -> void:
	var f := brakk.fortschritt
	var ci := _terminal
	var g := ci.get_viewport_rect().size
	_knoepfe.clear()
	var w := minf(980.0, g.x - 60.0)
	var h := minf(560.0, g.y - 90.0)
	var o := ((g - Vector2(w, h)) / 2.0).round()
	ci.draw_rect(Rect2(Vector2.ZERO, g), Color(0, 0, 0, 0.45))
	ci.draw_rect(Rect2(o, Vector2(w, h)), Color(0.05, 0.06, 0.1, 0.96))
	ci.draw_rect(Rect2(o, Vector2(w, h)), LICHT, false, 2.0)
	Stil.schreibe(ci, o + Vector2(18, 24), "LICHTTERMINAL", 26, LICHT)
	var irr := f.anfuehrer == "irrtuermer"   # 20.11.
	Stil.schreibe(ci, o + Vector2(230, 24), "Ringe für Hand und PliPlop" if irr else ("Ringe für die Hand von " + Anfuehrer.name(f.anfuehrer) if f.anfuehrer != "brakk" else "Ringe für Brakks linke Hand"), 18, Stil.TEXT_BLASS)
	var bud := "Budget %d" % int(spiel.budget)
	Stil.schreibe(ci, o + Vector2(w - 18.0 - Stil.breite(bud, 22), 24), bud, 22, Stil.GOLD)
	var zu := Rect2(o + Vector2(w - 150.0, h - 44.0), Vector2(132, 30))
	ci.draw_rect(zu, LICHT, false, 1.5)
	Stil.schreibe_mittig(ci, zu.get_center(), "Schließen [F]", 16, LICHT)
	_knoepfe.append([zu, _terminal_zu])
	# links: Finger
	var lx := o.x + 18.0
	var ly := o.y + 58.0
	if irr:
		_terminal_saetze(ci, lx, ly)   # 20.11. (Nachtrag): zwei Sätze zu je vier Ringen
	else:
		Stil.schreibe(ci, Vector2(lx, ly), "Brakks Finger (Stufe %d)" % f.stufe, 18, Stil.GOLD)
	for i in (0 if irr else 5):
		var r := Rect2(lx, ly + 18.0 + i * 62.0, 270.0, 56.0)
		ci.draw_rect(r, Color(1, 1, 1, 0.04))
		var mi := Vector2(r.position.x + 28.0, r.get_center().y)
		if i < f.ringe.size():
			var ring := f.ringe[i]
			var farbe := _ring_farbe(ring)
			ci.draw_rect(r, Color(farbe, 0.6), false, 1.5)
			_male_ring(ci, mi, 20.0, ring)
			Stil.schreibe(ci, Vector2(r.position.x + 56.0, r.position.y + 16.0), str(BrakkFortschritt.RINGE[ring]["name"]), 18, farbe)
			var vk := Rect2(r.position.x + 56.0, r.position.y + 30.0, 150.0, 22.0)
			ci.draw_rect(vk, Stil.TEXT_BLASS, false, 1.0)
			Stil.schreibe_mittig(ci, vk.get_center(), "Verkaufen +%d" % f.erstattung(ring, int(spiel.welle)), 14, Stil.TEXT)
			_knoepfe.append([vk, _verkaufe.bind(ring)])
		elif i < f.finger():
			Stil.schreibe(ci, Vector2(r.position.x + 56.0, r.get_center().y), "frei", 18, Stil.TEXT_BLASS)
		else:
			Stil.schreibe(ci, Vector2(r.position.x + 56.0, r.get_center().y), "ab Stufe %d" % int(BrakkFortschritt.FINGER_AB[i]), 18, Color(0.4, 0.42, 0.47))
	var erklaerung := "Alle getragenen Ringe stärken Brakks Pistolen. Der aktive Ring (Mausrad) bestimmt die Fähigkeiten; [C] setzt in der Bauphase sein Feld (2×2) – Fabriken darin bauen seine Truppe."
	if irr:
		erklaerung = "Je 4 Ringe für Irrtürmer und PliPlop, derselbe Ring auch mehrfach (wirkt mehrfach). Alle Ringe eines Satzes wirken; der aktive des PliPlop wählt seinen Pfad. Klick auf einen Ring: aktiv. [V] tauscht die aktiven, [C] setzt das Feld des Helden."   # 20.11. (Nachtrag)
	elif f.anfuehrer == "sonde7":
		erklaerung = "Der aktive Ring (Mausrad) färbt Farblaser und Energiebündel und die Treffer der Zielerfassung; gerufene Waffen bekommen nur sein Geschossbild. [C] setzt in der Bauphase sein Feld (2×2)."   # 20.11.
	Stil.absatz(ci, Vector2(lx, ly + (392.0 if irr else 340.0)), erklaerung, 270.0, 14, Stil.TEXT_BLASS)
	if irr:
		# 20.11. (Nachtrag): Kauf für welchen Satz?
		for k in 2:
			var satz := "held" if k == 0 else "pp"
			var kr := Rect2(o.x + w - 470.0 + k * 128.0, o.y + 10.0, 120.0, 28.0)
			var an := _kauf_satz == satz
			ci.draw_rect(kr, Color(Stil.GOLD, 0.2) if an else Color(0, 0, 0, 0.2))
			ci.draw_rect(kr, Stil.GOLD if an else Stil.TEXT_BLASS, false, 2.0 if an else 1.0)
			Stil.schreibe_mittig(ci, kr.get_center(), ("für Irrtürmer" if k == 0 else "für PliPlop"), 15, Stil.GOLD if an else Stil.TEXT_BLASS)
			_knoepfe.append([kr, func() -> void: _kauf_satz = satz])
	# rechts: alle Ringe
	var rx := o.x + 310.0
	var rw := w - 330.0
	var zh := minf(62.0, (h - 120.0) / float(BrakkFortschritt.RINGE.size()))
	var i2 := 0
	for ring: String in BrakkFortschritt.RINGE:
		var d: Dictionary = BrakkFortschritt.RINGE[ring]
		var farbe := _ring_farbe(ring)
		var r := Rect2(rx, ly + i2 * zh, rw, zh - 6.0)
		ci.draw_rect(r, Color(farbe, 0.07))
		_male_ring(ci, Vector2(r.position.x + 26.0, r.get_center().y), minf(20.0, zh * 0.34), ring)
		Stil.schreibe(ci, Vector2(r.position.x + 52.0, r.position.y + zh * 0.22), str(d["name"]), 18, farbe)
		var st := f.ring_stufe(ring)
		# 19.11. (Paul): zeigt die Stufe, die man als Nächstes bekommt (gekauft: die nächste, auf Stufe 3 diese) – Brakk UND Feld
		var zeig := 1 if irr else mini(3, st + 1)   # 20.11. (Nachtrag): Irrtürmer kauft immer Stufe 1
		var vorsatz := ("St. %d – " % zeig) if st < 3 or irr else ""
		Stil.schreibe(ci, Vector2(r.position.x + 200.0, r.position.y + zh * 0.22), vorsatz + ("Held: " if irr else "Brakk: ") + BrakkFortschritt.brakk_text(ring, zeig), 14, Stil.TEXT)
		if spiel.order24 == null:   # 20.11. (Paul): in Befehl 24 gibt es kein Ringfeld (Brakk baut nichts)
			Stil.schreibe(ci, Vector2(r.position.x + 200.0, r.position.y + zh * 0.58), "Feld: " + _ring_fabrik_text(ring, zeig), 14, Stil.TEXT_BLASS)
		elif _myr_feld():   # … außer im Überläufer-Verlauf: dort bestimmt der Ring die Myriaden-Einheit
			var o24: Order24 = spiel.order24
			Stil.schreibe(ci, Vector2(r.position.x + 200.0, r.position.y + zh * 0.58), "Feld: " + o24.myr_takt_text(str(Order24.MYR_RING.get(ring, "hund")),
				o24.wf("myr_wert") * (1.0 + o24.wf("myr_ring_stufe") / 100.0 * float(zeig - 1))), 14, Stil.TEXT_BLASS)
		var kb := Rect2(r.end.x - 130.0, r.get_center().y - 13.0, 122.0, 26.0)
		if irr:
			# 20.11. (Nachtrag): jeder Kauf ist ein neuer Ring (Stufe 1) im gewählten Satz; ausgebaut wird links
			var preis1 := int(BrakkFortschritt.RING_PREISE[0])
			var geht1 := int(spiel.budget) >= preis1 and f.satz_ringe(_kauf_satz).size() < BrakkFortschritt.SATZ_MAX
			ci.draw_rect(kb, Color(Stil.GOLD, 0.15) if geht1 else Color(0, 0, 0, 0.2))
			ci.draw_rect(kb, Stil.GOLD if geht1 else Stil.TEXT_BLASS, false, 1.5)
			Stil.schreibe_mittig(ci, kb.get_center(), "Kaufen %d" % preis1, 16, Stil.GOLD if geht1 else Stil.TEXT_BLASS)
			_knoepfe.append([kb, _kaufe_satz.bind(ring)])
		elif st >= BrakkFortschritt.RING_PREISE.size():
			Stil.schreibe_mittig(ci, kb.get_center(), "Stufe 3", 16, farbe)
		else:
			var preis := int(BrakkFortschritt.RING_PREISE[st])
			var geht := int(spiel.budget) >= preis and (st > 0 or f.ringe.size() < f.finger())
			ci.draw_rect(kb, Color(Stil.GOLD, 0.15) if geht else Color(0, 0, 0, 0.2))
			ci.draw_rect(kb, Stil.GOLD if geht else Stil.TEXT_BLASS, false, 1.5)
			var knopf := "Kaufen %d" % preis if st == 0 else "Stufe %d: %d" % [st + 1, preis]
			Stil.schreibe_mittig(ci, kb.get_center(), knopf, 16, Stil.GOLD if geht else Stil.TEXT_BLASS)
			_knoepfe.append([kb, _kaufe.bind(ring)])
		if st > 0 and not irr:
			Stil.schreibe(ci, Vector2(r.position.x + 52.0, r.position.y + zh * 0.6), "St. %d" % st, 14, farbe)
		i2 += 1


## 20.11. (Nachtrag): linke Spalte des Terminals beim Irrtürmer – zwei Sätze zu je vier Ringen. Je Ring: Ausbau, Verkaufen,
## Klick auf den Namen macht ihn aktiv.
func _terminal_saetze(ci: Control, lx: float, ly: float) -> void:
	var f := brakk.fortschritt
	var zh := 40.0
	for si in 2:
		var satz := "held" if si == 0 else "pp"
		var y0 := ly + si * (zh * float(BrakkFortschritt.SATZ_MAX) + 30.0)
		var liste := f.satz_ringe(satz)
		Stil.schreibe(ci, Vector2(lx, y0), ("Irrtürmer (%d/%d)" if si == 0 else "PliPlop (%d/%d)") % [liste.size(), BrakkFortschritt.SATZ_MAX], 18, Stil.GOLD)
		for i in BrakkFortschritt.SATZ_MAX:
			var r := Rect2(lx, y0 + 12.0 + i * zh, 270.0, zh - 4.0)
			ci.draw_rect(r, Color(1, 1, 1, 0.04))
			if i >= liste.size():
				Stil.schreibe(ci, Vector2(r.position.x + 40.0, r.get_center().y), "frei", 15, Stil.TEXT_BLASS)
				continue
			var ring := liste[i]
			var farbe := _ring_farbe(ring)
			var st := f.satz_stufe(satz, i)
			if i == f.satz_gewaehlt(satz):
				ci.draw_rect(r, farbe, false, 2.0)
			_male_ring(ci, Vector2(r.position.x + 18.0, r.get_center().y), 12.0, ring)
			var nr := Rect2(r.position.x + 34.0, r.position.y, 100.0, r.size.y)
			Stil.schreibe(ci, Vector2(nr.position.x, r.get_center().y - 6.0), EgoModus.ring_kurz(ring), 15, farbe)
			Stil.schreibe(ci, Vector2(nr.position.x, r.get_center().y + 8.0), "St. %d" % st + (" · aktiv" if i == f.satz_gewaehlt(satz) else ""), 13, Stil.TEXT_BLASS)
			_knoepfe.append([nr, _waehle_satz.bind(satz, i)])
			var ab := Rect2(r.position.x + 136.0, r.position.y + 6.0, 62.0, r.size.y - 12.0)
			if st < BrakkFortschritt.RING_PREISE.size():
				var preis := int(BrakkFortschritt.RING_PREISE[st])
				var geht := int(spiel.budget) >= preis
				ci.draw_rect(ab, Stil.GOLD if geht else Stil.TEXT_BLASS, false, 1.0)
				Stil.schreibe_mittig(ci, ab.get_center(), "St%d %d" % [st + 1, preis], 13, Stil.GOLD if geht else Stil.TEXT_BLASS)
				_knoepfe.append([ab, _baue_satz_aus.bind(satz, i)])
			var vk := Rect2(r.position.x + 202.0, r.position.y + 6.0, 64.0, r.size.y - 12.0)
			ci.draw_rect(vk, Stil.TEXT_BLASS, false, 1.0)
			Stil.schreibe_mittig(ci, vk.get_center(), "Verk. %d" % f.satz_erstattung(satz, i, int(spiel.welle)), 13, Stil.TEXT)
			_knoepfe.append([vk, _verkaufe_satz.bind(satz, i)])


# ------------------------------------------------------------------ Brakk-Mode: Ringfelder (18.11.)



## Mausrad: nächster / vorheriger Ring; die Hand hebt sich und zeigt ihn.
## 18.11.: Mausrad und Touchpad – Anteile sammeln, eine volle Raste wechselt den Ring (Maus: jede Raste).
func _rad(richtung: int, anteil: float) -> void:
	var jetzt := Time.get_ticks_msec() / 1000.0
	if jetzt - _rad_zuletzt < RAD_PAUSE:
		_rad_summe = 0.0
		return
	if signf(_rad_summe) != float(richtung):
		_rad_summe = 0.0
	_rad_summe += anteil * richtung
	if absf(_rad_summe) >= 1.0:
		_rad_summe = 0.0
		_rad_zuletzt = jetzt
		_ring_waehlen(richtung)


func _ring_waehlen(schritt: int) -> void:
	var f := brakk.fortschritt
	if f == null or f.ringe.is_empty():
		if f != null:
			spiel.melde("Noch kein Ring – am Lichtterminal der Basis kaufen ([F] an der Basis in der Bauphase).", 2.5)
		return
	f.gewaehlt = posmod(f.gewaehlt + schritt, f.ringe.size())
	f.wechsel_rest = BrakkFortschritt.WECHSEL_SEK   # 18.11. (Paul): kurz schütteln, erst dann wirkt der neue Ring
	_hand_zeigen = 1.6
	_ring_blitz = 0.3
	Ton.spiele(spiel, "ui-klick", -6.0)


## 19.11. (Paul): [C] in der Bauphase – das Ringfeld ist ein festes 2×2-Felder-Rechteck (höchstens 4 Fabriken).
## Erstes [C]: Vorschau rastet auf das Feldraster ein, betroffene Fabriken leuchten, Anzeige „3/4 Fabriken“.
## Zweites [C] oder Linksklick bestätigt, Rechtsklick oder Esc bricht ab. Solange wird nicht geschossen.
var _feld_zielt := false
var _feld_ecke := Vector2i.ZERO
var _feld_marken: Array = []     # leuchtende Kästen über den betroffenen Fabriken (Vorschau)


func _wirf_feld() -> void:
	if _feld_zielt:
		_feld_bestaetigen()
		return
	var f := brakk.fortschritt
	if f == null:
		return
	if f.ringe.is_empty():
		spiel.melde("Noch kein Ring – am Lichtterminal der Basis kaufen ([F] an der Basis in der Bauphase).", 2.5)
		return
	if spiel.phase != 0 and not _myr_feld():
		spiel.melde("Ringfelder setzt du in der Bauphase – in der Welle liegen sie fest.", 2.0)
		return
	f.gewaehlt = clampi(f.gewaehlt, 0, f.ringe.size() - 1)
	_feld_zielt = true
	_feuer = false
	Ton.spiele(spiel, "ui-klick", -4.0)


## 20.11. (Paul): Befehl 24, Überläufer – das Ringfeld gilt den Myriaden-Fabriken und lässt sich jederzeit werfen.
func _myr_feld() -> bool:
	return spiel.order24 != null and spiel.order24.geheim


func _feld_abbrechen() -> void:
	_feld_zielt = false
	if _vorschau != null:
		_vorschau.visible = false
	for m: Node3D in _feld_marken:
		m.visible = false


## Linke obere Zelle des 2×2-Rechtecks, dessen Mitte (eine Rasterecke) dem Fadenkreuz am nächsten liegt.
func _feld_ecke_im_blick() -> Vector2i:
	var p := ziel_welt(true)
	if p.x < -9000.0:
		return Vector2i(-99, -99)
	var gx := p.x / Werte.ZELLE
	var gy := (p.y - Werte.KARTE_OBEN) / Werte.ZELLE
	var halb := float(BrakkFortschritt.FELD_GROESSE) / 2.0
	return Vector2i(roundi(gx - halb), roundi(gy - halb))


func _feld_mitte(ecke: Vector2i) -> Vector2:
	var halb := float(BrakkFortschritt.FELD_GROESSE) / 2.0
	return Vector2((float(ecke.x) + halb) * Werte.ZELLE, (float(ecke.y) + halb) * Werte.ZELLE + Werte.KARTE_OBEN)


func _feld_fabriken(ecke: Vector2i) -> Array:
	var liste: Array = []
	if _myr_feld():
		for z: Vector2i in spiel.order24.myr_fabriken:
			if BrakkFortschritt.im_feld(z, ecke):
				liste.append(z)
		return liste
	for z: Vector2i in spiel.fabriken:
		if not karte.paar.has(z) and BrakkFortschritt.im_feld(z, ecke):
			liste.append(z)
	return liste


func _feld_bestaetigen() -> void:
	var f := brakk.fortschritt
	if f == null or f.ringe.is_empty() or (spiel.phase != 0 and not _myr_feld()):
		_feld_abbrechen()
		return
	var ecke := _feld_ecke_im_blick()
	if ecke.x < -90 or _feld_mitte(ecke).distance_to(_fuss2d()) > FELD_WEITE * Werte.ZELLE:
		spiel.melde("Zu weit – das Ringfeld reicht höchstens %d Felder weit." % int(FELD_WEITE), 2.0)
		return
	var ring := f.ringe[clampi(f.gewaehlt, 0, f.ringe.size() - 1)]
	f.setze_feld(ring, ecke)
	_feld_abbrechen()
	_hand_zeigen = 1.0
	_trauma = minf(1.0, _trauma + 0.12)
	spiel.effekte.flaeche(_feld_mitte(ecke), Werte.ZELLE * 1.1, _ring_farbe(ring))
	Ton.spiele(spiel, "tc-arc", -4.0)
	if _myr_feld():
		var o: Order24 = spiel.order24
		var typ := str(Order24.MYR_RING.get(ring, "hund"))
		var wert: float = o.wf("myr_wert") * (1.0 + o.wf("myr_ring_stufe") / 100.0 * float(maxi(0, f.ring_stufe(ring) - 1)))
		spiel.melde("%s: %d/4 Myriaden-Fabriken im Feld – jede baut %s." % [str(BrakkFortschritt.RINGE[ring]["name"]), _feld_fabriken(ecke).size(), o.myr_takt_text(typ, wert)], 4.0)
		return
	spiel.melde("%s: %d/4 Fabriken im Feld bauen %s." % [str(BrakkFortschritt.RINGE[ring]["name"]), _feld_fabriken(ecke).size(), _ring_fabrik_text(ring, f.ring_stufe(ring))], 3.0)


func _leucht_mat(farbe: Color, alpha: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(farbe, alpha)
	m.emission_enabled = true
	m.emission = farbe
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


func _kasten(groesse: Vector3, mat: StandardMaterial3D, pos: Vector3, eltern: Node3D) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = groesse
	m.mesh = box
	m.material_override = mat
	m.position = pos
	eltern.add_child(m)
	return m


## Ringfeld in 3D: leuchtender Rand eines 2×2-Rechtecks, zarte Fläche, dunkler Plattformrand; darüber (gesetzt)
## der Holo-Bogen mit dem Ring.
func _baue_feld(ring: String, farbe: Color, vorschau: bool) -> Node3D:
	var k := Node3D.new()
	var s := float(BrakkFortschritt.FELD_GROESSE)
	var rand := _leucht_mat(farbe, 0.45 if vorschau else 0.9)
	var h := s / 2.0
	for seite: Array in [[Vector3(s, 0.04, 0.07), Vector3(0, 0.04, -h)], [Vector3(s, 0.04, 0.07), Vector3(0, 0.04, h)],
			[Vector3(0.07, 0.04, s), Vector3(-h, 0.04, 0)], [Vector3(0.07, 0.04, s), Vector3(h, 0.04, 0)]]:
		_kasten(seite[0], rand, seite[1], k)
	_kasten(Vector3(s, 0.01, s), _leucht_mat(farbe, 0.08 if vorschau else 0.16), Vector3(0, 0.03, 0), k)
	if not vorschau:
		var pm := StandardMaterial3D.new()
		pm.albedo_color = Color("23262e")
		for seite: Array in [[Vector3(s + 0.24, 0.05, 0.12), Vector3(0, 0.025, -h - 0.1)], [Vector3(s + 0.24, 0.05, 0.12), Vector3(0, 0.025, h + 0.1)],
				[Vector3(0.12, 0.05, s), Vector3(-h - 0.1, 0.025, 0)], [Vector3(0.12, 0.05, s), Vector3(h + 0.1, 0.025, 0)]]:
			_kasten(seite[0], pm, seite[1], k)
		var schwebe := Node3D.new()
		schwebe.name = "Ring"
		schwebe.position.y = 0.2
		k.add_child(schwebe)
		var bogen := 0.95
		var segmente := 16
		for i in segmente:
			if i % 4 == 3:
				continue   # Lücken im Bogen
			var w := PI * 1.25 * (float(i) + 0.5) / float(segmente) - PI * 0.125
			var seg := _kasten(Vector3(0.16, 0.05, 0.07), _leucht_mat(farbe, 0.85), Vector3(cos(w) * bogen, 0.9 + sin(w) * bogen, 0.0), schwebe)
			seg.rotation.z = w + PI / 2.0
		var bild := Sprite3D.new()
		bild.texture = RingBilder.bild(ring, farbe)
		bild.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		bild.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		bild.pixel_size = 0.045
		bild.shaded = false
		bild.position.y = 0.95
		schwebe.add_child(bild)
	hd.add_child(k)
	return k


## Jedes Bild: 3D-Felder mit den gesetzten Feldern abgleichen, Ringe drehen; beim Zielen die Vorschau mit leuchtenden Fabriken.
func _felder_weiter(dt: float) -> void:
	var f := brakk.fortschritt
	if f == null:
		return
	for ring: String in _feld_knoten.keys():
		if not f.felder.has(ring):
			(_feld_knoten[ring] as Node3D).queue_free()
			_feld_knoten.erase(ring)
	for ring: String in f.felder:
		var k: Node3D = _feld_knoten.get(ring)
		if k == null:
			k = _baue_feld(ring, _ring_farbe(ring), false)
			_feld_knoten[ring] = k
		k.position = _zu3d(_feld_mitte(f.felder[ring] as Vector2i), 0.0)
		var s := k.get_node_or_null("Ring") as Node3D
		if s != null:
			s.rotation.y += dt * 0.8
			s.position.y = 0.2 + 0.06 * sin(Time.get_ticks_msec() / 400.0)
	if _feld_zielt and ((spiel.phase != 0 and not _myr_feld()) or f.ringe.is_empty()):
		_feld_abbrechen()
	if not _feld_zielt or not _frei():
		if _vorschau != null:
			_vorschau.visible = false
		for m: Node3D in _feld_marken:
			m.visible = false
		return
	_hand_zeigen = maxf(_hand_zeigen, 0.3)
	var ring := f.ringe[clampi(f.gewaehlt, 0, f.ringe.size() - 1)]
	var farbe := _ring_farbe(ring)
	if _vorschau == null or _vorschau.get_meta("ring", "") != ring:
		if _vorschau != null:
			_vorschau.queue_free()
		_vorschau = _baue_feld(ring, farbe, true)
		_vorschau.set_meta("ring", ring)
	_feld_ecke = _feld_ecke_im_blick()
	_vorschau.visible = _feld_ecke.x > -90
	if not _vorschau.visible:
		return
	_vorschau.position = _zu3d(_feld_mitte(_feld_ecke), 0.0)
	var fabriken := _feld_fabriken(_feld_ecke)
	while _feld_marken.size() < 4:
		var m := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.96, 1.3, 0.96)
		m.mesh = box
		m.material_override = _leucht_mat(farbe, 0.22)
		hd.add_child(m)
		_feld_marken.append(m)
	var puls := 0.15 + 0.12 * sin(Time.get_ticks_msec() / 160.0)
	for i in 4:
		var m: MeshInstance3D = _feld_marken[i]
		m.visible = i < fabriken.size()
		if m.visible:
			m.position = _zu3d(karte.mitte(fabriken[i] as Vector2i), 0.65)
			var mm := m.material_override as StandardMaterial3D
			mm.albedo_color = Color(farbe, puls)
			mm.emission = farbe


## 18.11. (Paul): Ringplätze auf der Ringhand (ringhand.png, 48×72, Faust mit erhobenem Zeigefinger), in Bildpunkten:
## [links, rechts, oben] eines 3 Bildpunkte hohen Bands quer über das Fingerglied – in der Reihenfolge, in der die
## Finger frei werden: Mittelfinger, Ringfinger, Zeigefinger (über dem Projektorring), kleiner Finger, Daumen.
const FINGER_BAENDER := [[18, 24, 23], [11, 17, 25], [32, 38, 15], [4, 9, 28], [39, 45, 41]]
## Material des Bands je Ring (wie in ring_bilder.gd): Silber, Schwarz, Gold, dunkles Metall.
const BAND_FARBE := {"durchschuss": "8a93a6", "laser": "2b2830", "feuerteam": "c4ccd8", "minigun": "4a505e", "markierung": "8a93a6", "bollwerk": "4a505e",
	"abpraller": "4a505e", "brandfeld": "c9952e", "plasmagel": "8a93a6"}


## 18.11.: Ist eine Tafel offen (Übersicht, Pause, Terminal, Fabrikmenü)? Dann zeichnet die Ego-Sicht nichts darüber.
func _hud_aus() -> bool:
	if spiel.phase == 2:
		return true   # 18.11. (Paul): Endtafel (Sieg/Niederlage) – keine Waffen und Leisten darüber
	if _briefing_offen():
		return true
	if spiel._lexikon != null and spiel._lexikon.visible:
		return true
	if spiel._hud != null and spiel._hud.pausiert():
		return true
	if spiel._fabrikmenue != null and spiel._fabrikmenue.visible:
		return true
	return _terminal != null and _terminal.visible


## Die getragenen Ringe sitzen als Bänder auf ihren Fingern, mit dem Stein in der Ringfarbe; der gewählte leuchtet.
func _ringe_auf_hand(rp: Vector2, wpx: float, auf: float) -> void:
	var f := brakk.fortschritt
	if f == null:
		return
	var o := rp.round()
	var umriss := Color(UMRISS, auf)
	for i in mini(f.ringe.size(), FINGER_BAENDER.size()):
		var ring := f.ringe[i]
		var farbe := _ring_farbe(ring)
		var b: Array = FINGER_BAENDER[i]
		var x0 := float(b[0])
		var x1 := float(b[1])
		var y := float(b[2])
		var breite := x1 - x0 + 1.0
		var metall := Color(str(BAND_FARBE.get(ring, "8a93a6")))
		var gew := i == f.gewaehlt and _hand_zeigen > 0.0
		var px := func(x: float, yy: float, w: float, h: float, c: Color) -> void:
			_bild.draw_rect(Rect2(o + Vector2(x, yy) * wpx, Vector2(w, h) * wpx), c)
		if gew:
			# 18.11. (Paul): der gewählte Ring leuchtet kräftig – Schein in drei Stufen, beim Wechsel ein weißer Blitz
			var puls := 0.7 + 0.3 * sin(Time.get_ticks_msec() / 90.0)
			var mitte := o + Vector2((x0 + x1 + 1.0) / 2.0, y + 1.5) * wpx
			_bild.draw_circle(mitte, 12.0 * wpx, Color(farbe, 0.12 * puls * auf))
			_bild.draw_circle(mitte, 7.0 * wpx, Color(farbe, 0.28 * puls * auf))
			_bild.draw_circle(mitte, 4.0 * wpx, Color(farbe.lightened(0.4), 0.45 * puls * auf))
			if _ring_blitz > 0.0:
				_bild.draw_circle(mitte, (4.0 + 10.0 * (0.3 - _ring_blitz)) * wpx, Color(1, 1, 1, _ring_blitz * 2.0 * auf))
		# Band: Umriss oben und unten, drei Zeilen Metall (hell, mittel, dunkel)
		px.call(x0, y - 1.0, breite, 1.0, umriss)
		px.call(x0, y + 3.0, breite, 1.0, umriss)
		px.call(x0, y, breite, 1.0, Color(metall.lightened(0.35), auf))
		px.call(x0, y + 1.0, breite, 1.0, Color(metall, auf))
		px.call(x0, y + 2.0, breite, 1.0, Color(metall.darkened(0.35), auf))
		# Stein in der Mitte (2×3), beim gewählten heller
		var mx := floorf((x0 + x1) / 2.0)
		px.call(mx - 1.0, y - 1.0, 4.0, 5.0, umriss)
		var stein := farbe.lightened(0.25) if gew else farbe
		if ring == "durchschuss":
			px.call(mx, y, 2.0, 3.0, Color(Color("f2f2f2"), auf))   # Auge: weiß mit farbiger Mitte
			px.call(mx, y + 1.0, 2.0, 1.0, Color(stein, auf))
		else:
			px.call(mx, y, 2.0, 3.0, Color(stein, auf))
			px.call(mx, y, 1.0, 1.0, Color(stein.lightened(0.6), auf))



# ------------------------------------------------------------------ Brakk-Mode: Kulisse ringsum (18.11.)

## 18.11. (Paul): In der Ego-Sicht ein durchgehendes Bergpanorama ringsum – ein offener Zylinder mit der Bergtextur
## (wiederholt, auf einer Grundhöhe), statt einzelner Bergbilder auf verschiedenen Höhen (das sah blockartig aus).
## Die Bergbilder der Übersicht werden solange ausgeblendet.
const PANORAMA_RADIUS := 42.0
const PANORAMA_HOCH := 24.0
const PANORAMA_WIEDERHOLT := 7.0
var _berge_ringsum: Array = []       # [Panorama] und die ausgeblendeten Bergbilder der Übersicht
var _berge_versteckt: Array = []


func _baue_berge_ringsum() -> void:
	var berge: Texture2D = karte.neu_bild("kulisse/berge.png")
	if berge == null:
		return
	# die Bergbilder der Übersicht ausblenden
	for c: Node in hd.get_children():
		if c is Sprite3D and (c as Sprite3D).texture == berge and (c as Sprite3D).visible:
			(c as Sprite3D).visible = false
			_berge_versteckt.append(c)
	var zyl := CylinderMesh.new()
	zyl.top_radius = PANORAMA_RADIUS
	zyl.bottom_radius = PANORAMA_RADIUS
	zyl.height = PANORAMA_HOCH
	zyl.radial_segments = 96
	zyl.rings = 1
	zyl.cap_top = false
	zyl.cap_bottom = false
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_texture = berge
	mat.albedo_color = Color(0.82, 0.86, 0.92)
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.texture_repeat = true
	mat.uv1_scale = Vector3(PANORAMA_WIEDERHOLT, 1.0, 1.0)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	mat.alpha_scissor_threshold = 0.5
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.disable_fog = true
	var m := MeshInstance3D.new()
	m.mesh = zyl
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	hd.add_child(m)
	m.position = Vector3(float(Werte.SPALTEN) / 2.0, PANORAMA_HOCH / 2.0 + 0.5, float(Werte.ZEILEN) / 2.0)
	_berge_ringsum.append(m)


func _berge_zurueck() -> void:
	for b: Node in _berge_ringsum:
		if is_instance_valid(b):
			b.queue_free()
	for c: Node in _berge_versteckt:
		if is_instance_valid(c):
			(c as Sprite3D).visible = true


# ------------------------------------------------------------------ Brakk-Mode: fließende Runden (18.11.)

## Bauphase mit Countdown: läuft er ab, startet die Welle von selbst ([Enter] startet früher). Die Zeit läuft auch,
## solange das Lichtterminal offen ist – Einkaufen gehört zum Zeitdruck.
func _fliessende_runden(dt: float) -> void:
	if spiel.order24 != null:
		_countdown = -1.0
		return   # 20.11.: Befehl 24 – keine Wellen, die Uhr von Order24 zählt
	if _briefing != null and _briefing.visible:
		return   # 18.11.: die Einsatz-Tafel ist noch offen – der Countdown wartet
	if not spiel.brakk_modus or spiel.phase != 0:
		_countdown = -1.0
		return
	if _countdown < 0.0:
		_countdown = COUNTDOWN_ERSTE if int(spiel.welle) <= 1 else COUNTDOWN
	var vorher := ceili(_countdown)
	_countdown -= dt
	if ceili(_countdown) != vorher and ceili(_countdown) <= 5 and _countdown > 0.0:
		Ton.spiele(spiel, "ui-klick")   # die letzten Sekunden ticken
	if _countdown <= 0.0:
		_countdown = -1.0
		spiel.starte_welle()


func _countdown_anzeige(g: Vector2) -> void:
	if spiel.order24 != null and spiel.phase == 1:
		_order24_anzeige(g)
		return
	if _countdown < 0.0:
		return
	var rest := ceili(_countdown)
	var farbe := Stil.WARN if rest <= 5 else Stil.GOLD
	var m := Vector2(g.x / 2.0, 116.0)
	var r := Rect2(m.x - 150.0, m.y - 18.0, 300.0, 36.0)
	_bild.draw_rect(r, Color(0.04, 0.05, 0.08, 0.75))
	_bild.draw_rect(r, farbe, false, 2.0)
	Stil.schreibe_mittig(_bild, m + Vector2(0, -2), "Nächste Welle in %d s" % rest, 20, farbe)
	var anteil := clampf(_countdown / (COUNTDOWN_ERSTE if int(spiel.welle) <= 1 else COUNTDOWN), 0.0, 1.0)
	_bild.draw_rect(Rect2(r.position + Vector2(4, r.size.y - 6), Vector2((r.size.x - 8.0) * anteil, 3)), farbe)
	Stil.schreibe_mittig(_bild, m + Vector2(0, 30), "[Enter] jetzt" if touch == null else "antippen: jetzt", 14, Stil.TEXT_BLASS)


## 20.11. (Schritt 5b): Order 24 – Restzeit, Phase und Gold oben in der Mitte.
func _order24_anzeige(g: Vector2) -> void:
	var o: Order24 = spiel.order24
	var rest := ceili(o.uhr_sek())   # 20.11.: endlos – die Uhr zählt hoch
	var farbe := Stil.WARN if o.jagd else Stil.GOLD
	var m := Vector2(g.x / 2.0, 116.0)
	var r := Rect2(m.x - 170.0, m.y - 18.0, 340.0, 36.0)
	_bild.draw_rect(r, Color(0.04, 0.05, 0.08, 0.75))
	_bild.draw_rect(r, farbe, false, 2.0)
	Stil.schreibe_mittig(_bild, m + Vector2(0, -2), "Befehl 24 · %d:%02d" % [rest / 60, rest % 60], 20, farbe)
	_bild.draw_rect(Rect2(r.position + Vector2(4, r.size.y - 6), Vector2((r.size.x - 8.0) * o.uhr_anteil(), 3)), farbe)
	Stil.schreibe_mittig(_bild, m + Vector2(0, 30), "%s · Budget %d" % [o.phase_text(), int(spiel.budget)], 14, Stil.TEXT_BLASS)
	if o.am_terminal(_fuss2d()) and (_terminal == null or not _terminal.visible):
		Stil.schreibe_mittig(_bild, m + Vector2(0, 52), "[F] Lichtterminal", 16, Stil.GOLD)
	o.hud(_bild, g, self)   # 20.11.: Befehl 24 – Sprengladungen, In Deckung, Sabotage (order24.gd)


# ------------------------------------------------------------------ Brakk-Mode: Überhitzen (18.11.)

func _heize(seite: int) -> void:
	if touch != null:
		return   # 18.11. (Paul): am Handy schießt Brakk selbst – kein Überhitzen
	if _zl_aktiv("laser"):
		return   # 19.11.: Zeitlupe mit Glutstrahlring – keine Überhitzung
	var f := brakk.fortschritt
	var mal := f.hitze_faktor() if f != null else 1.0
	_hitze[seite] = float(_hitze[seite]) + HITZE_JE_SCHUSS * mal
	_seit_schuss[seite] = 0.0
	if float(_hitze[seite]) >= 1.0:
		_hitze[seite] = 1.0
		_gesperrt[seite] = HITZE_SPERRE
		_trauma = minf(1.0, _trauma + 0.12)
		Ton.spiele(spiel, "tc-arc", -2.0)   # Zischen
		spiel.melde("Überhitzt! %s Pistole kühlt ab." % ("Linke" if seite == 0 else "Rechte"), 1.2)


func _kuehlen(dt: float) -> void:
	var f := brakk.fortschritt
	var mal := f.kuehl_faktor() if f != null else 1.0
	for i in 2:
		_seit_schuss[i] = float(_seit_schuss[i]) + dt
		if float(_gesperrt[i]) > 0.0:
			_gesperrt[i] = maxf(0.0, float(_gesperrt[i]) - dt)
			_hitze[i] = float(_gesperrt[i]) / HITZE_SPERRE   # während der Sperre läuft die Hitze leer
		elif float(_seit_schuss[i]) >= HITZE_PAUSE:
			_hitze[i] = maxf(0.0, float(_hitze[i]) - HITZE_KUEHLEN * mal * dt)


## Zwei Bögen links und rechts vom Fadenkreuz: Hitze der linken (Glut) und rechten Pistole; gesperrt blinkt rot.
func _hitze_anzeige(m: Vector2, px: float) -> void:
	if brakk.fortschritt == null:
		return
	var radius := 13.0 * px
	for i in 2:
		var h := float(_hitze[i])
		if h <= 0.01:
			continue
		var gesperrt := float(_gesperrt[i]) > 0.0
		var grund := LASER_LINKS if i == 0 else SCHUSS
		var farbe := Color("ff3b3b") if gesperrt or h > 0.8 else grund
		if gesperrt and Time.get_ticks_msec() % 240 < 120:
			farbe = Color.WHITE
		var mitte_w := PI if i == 0 else 0.0
		var halb := 0.55
		_bild.draw_arc(m, radius, mitte_w - halb, mitte_w + halb, 16, Color(0, 0, 0, 0.45), px * 1.2)
		var von := mitte_w - halb if i == 0 else mitte_w + halb   # füllt von unten nach oben
		var bis := von + (2.0 * halb * h if i == 0 else -2.0 * halb * h)
		_bild.draw_arc(m, radius, minf(von, bis), maxf(von, bis), 16, Color(farbe, 0.9), px * 1.2)


## Was Fabriken im Feld eines Rings auf Stufe `st` bauen, kurz (für Terminal und Meldung).
func _ring_fabrik_text(ring: String, st: int) -> String:
	var truppe := str(BrakkFortschritt.RINGE[ring]["truppe"])
	var name := str(Werte.EINHEITEN[truppe]["name"]) + (" −25 % Schaden" if ring == "plasmagel" else "")   # 19.11. (Paul): Gel-Feld gedämpft
	match st:
		1:
			return "%s (St. 1: +20 %% Leben)" % name
		2:
			return "%s (St. 2: stärker)" % name
		_:
			return "%s (St. 3: %s)" % [name, str(Werte.STUFE_3[truppe][ring]["name"])]


# ------------------------------------------------------------------ Brakk-Mode: Lichtanker [Q] (18.11.)

## Der Ring schießt ein Lichtseil an die Mauerkrone oder den Boden unter dem Fadenkreuz und zieht Brakk im Bogen hin –
## an einer Mauer landet er oben. Wie ein Greifhaken (Titanfall/Apex), nur aus Licht.
const ANKER_WEITE := 10.0
const ANKER_TEMPO := 14.0        # Felder je Sekunde
const ANKER_ABKLING := 6.0


## 20.11. (Paul): Befehl 24 – Q und E (Anker, Lichtbrücke; die Treppe über kletter_abklingzeit) laden langsamer, man ist eher eingekesselt.
func _mobil() -> float:
	return spiel.order24.wf("mobil_abkling") / 100.0 if spiel.order24 != null else 1.0


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
	var von := hd.kamera.global_position
	var r := _blick()
	var t := _strahl_bis(von, r, ANKER_WEITE)
	if t >= ANKER_WEITE - 0.05:
		return []
	var p := von + r * t
	var z := Vector2i(floori(p.x + r.x * 0.03), floori(p.z + r.z * 0.03))
	if hd.ist_hoch(z) and karte.inhalt(z) == Karte.WALL and z != karte.zelle_bei(_fuss2d()):
		return [_zu3d(karte.mitte(z), hd.H), z]
	if p.y <= 0.02 and _passt_unten(_zu2d(p)):
		return [Vector3(p.x, 0.0, p.z), Karte.KEINE]
	return []


func _anker_start() -> void:
	if _haken >= 0.0:
		_anker_ziehen()   # 19.11. (Paul): zweites [Q] zieht heran
		return
	if _anker >= 0.0 or _klettern >= 0.0 or _tumble >= 0.0 or _absprung >= 0.0 or not _darf("anker"):
		return
	if _anker_rest > 0.0:
		spiel.melde("Lichtanker wieder in %.0f s." % ceilf(_anker_rest), 1.5)
		return
	var ziel := _anker_ziel()
	if ziel.is_empty():
		spiel.melde("Kein Halt für den Lichtanker – auf eine Mauerkrone oder den Boden zielen (bis %d Felder)." % int(ANKER_WEITE), 2.0)
		return
	# 19.11. (Paul): der Haken bleibt hängen – [Q] noch einmal zieht heran, dazwischen laufen, springen, schwingen
	_haken = 0.0
	_zaehle("anker")
	_haken_p = ziel[0]
	_haken_wall = ziel[1]
	_seil_lang = maxf(1.0, _fuss3d().distance_to(_haken_p))
	_hand_zeigen = maxf(_hand_zeigen, 0.5)
	_trauma = minf(1.0, _trauma + 0.1)
	_kick += 0.02
	Ton.spiele(spiel, "tc-arc", -3.0)
	if not _anker_erklaert:
		_anker_erklaert = true
		spiel.melde("Lichtanker hängt: nochmal Anker ([Q]) zieht dich hin · laufen und springen = schwingen · in der Luft nochmal springen = abschnellen.", 4.0)
	if _anker_seil == null:
		_anker_seil = MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.05, 0.05, 1.0)
		_anker_seil.mesh = box
		_anker_seil.material_override = _leucht(LICHT, 0.9, 3.0)
		hd.add_child(_anker_seil)
		_anker_haken = MeshInstance3D.new()
		var tor := TorusMesh.new()
		tor.inner_radius = 0.12
		tor.outer_radius = 0.2
		_anker_haken.mesh = tor
		_anker_haken.material_override = _leucht(Color("e8fbff"), 1.0, 3.5)
		hd.add_child(_anker_haken)
	var lf := _licht_farbe()   # 18.11. (Paul): in der Farbe des aktiven Rings
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
	hoehe = lerpf(_anker_von.y, _anker_nach.y, weich) + sin(f * PI) * 0.45
	brakk.position = _zu2d(p)
	_fov_weit = 9.0 * sin(f * PI)
	_geht = false
	_seil_zeichnen(_anker_nach, _anker + 1.0)   # der Haken sitzt schon
	if f < 1.0:
		return
	# angekommen
	_anker = -1.0
	_fov_weit = 0.0
	_anker_seil.visible = false
	_anker_haken.visible = false
	_trauma = minf(1.0, _trauma + 0.25)
	_rueckstoss[0] = 0.7
	_rueckstoss[1] = 0.7
	Ton.spiele(spiel, "hit-thud", -4.0)
	_funke(_anker_nach + Vector3(0, 0.05, 0), 0.25)
	if _anker_wall != Karte.KEINE:
		brakk.oben = true
		brakk.posten_zelle = _anker_wall
		brakk.zustand = Einheit.Zustand.AUF_POSTEN
		brakk.position = karte.mitte(_anker_wall) + Vector2(0, -12)
		brakk.anker = brakk.position
		hoehe = hd.H
	else:
		hoehe = 0.0
		_setze_fuss(_zu2d(_anker_nach))


# ------------------------------------------------------------------ Brakk-Mode: Lichtbrücke [E] auf dem Wall (18.11.)

## Oben auf einem Wall, Blick auf einen anderen Wall (bis BRUECKE_WEITE Felder): [E] wirft eine feste Lichtbahn
## hinüber, auf der Brakk geht (wie die harte Lichtbrücke in Portal 2). Sie steht BRUECKE_HALTEN Sekunden.
const BRUECKE_WEITE := 5.0
const BRUECKE_HALTEN := 10.0
const BRUECKE_AUFBAU := 0.5
const BRUECKE_ABKLING := 12.0     # 18.11. (Paul): eigene, längere Abklingzeit (die Treppe bleibt kurz)
var _bruecke_cd := 0.0
var _bruecke: Node3D = null
var _bruecke_felder := {}         # Zellen unter der Bahn: dort darf Brakk oben gehen
var _bruecke_rest := 0.0
var _bruecke_aufbau := -1.0


## Zellen zwischen dem eigenen Wallstück und dem nächsten Wall in Blickrichtung: [Lücke (Array), Start, Ende] oder [].
func _bruecke_ziel() -> Array:
	if not brakk.oben:
		return []
	var fuss := _fuss2d()
	var v := Vector2(_vorne().x, _vorne().z).normalized()
	var luecke: Array[Vector2i] = []
	var start := Vector2.INF
	var t := 0.0
	while t <= BRUECKE_WEITE + 1.0:
		var p := fuss + v * t * Werte.ZELLE
		var z := karte.zelle_bei(p)
		if not karte.in_karte(z):
			return []
		if hd.ist_hoch(z):
			if not luecke.is_empty():
				return [luecke, start, p] if luecke.size() <= int(BRUECKE_WEITE) else []
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
		spiel.melde("Lichtbrücke wieder in %.0f s." % ceilf(_bruecke_cd), 1.5)
		return true   # [E] nicht als „hinunter“ verstehen
	if _bruecke != null:
		_bruecke.queue_free()
	_bruecke_felder.clear()
	for z: Vector2i in ziel[0]:
		_bruecke_felder[z] = true
	var a := _zu3d(ziel[1] as Vector2, hd.H)
	var b := _zu3d(ziel[2] as Vector2, hd.H)
	_bruecke = Node3D.new()
	hd.add_child(_bruecke)
	var lf := _licht_farbe()   # 18.11. (Paul): in der Farbe des aktiven Rings
	var flaeche := _leucht(lf, 0.5, 1.8)
	var kante := _leucht(lf.lightened(0.7), 0.95, 3.0)
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
	_bruecke_rest = BRUECKE_HALTEN
	_bruecke_aufbau = 0.0
	_bruecke_cd = BRUECKE_ABKLING * _mobil()
	_hand_zeigen = maxf(_hand_zeigen, BRUECKE_AUFBAU + 0.2)
	_trauma = minf(1.0, _trauma + 0.12)
	Ton.spiele(spiel, "tc-arc", -5.0)
	spiel.melde("Lichtbrücke steht %d s – hinüber!" % int(BRUECKE_HALTEN), 2.0)
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
			var t0 := BRUECKE_AUFBAU * 0.8 * float(i) / float(planken.size())
			var x := clampf((_bruecke_aufbau - t0) / 0.12, 0.0, 1.0)
			var s := 1.0 + 2.70158 * pow(x - 1.0, 3) + 1.70158 * pow(x - 1.0, 2)
			(planken[i] as Node3D).scale = Vector3(maxf(0.01, s), 1.0, 1.0)
		if _bruecke_aufbau >= BRUECKE_AUFBAU:
			_bruecke_aufbau = -1.0
			for c: Node in _bruecke.get_children():
				if c.has_meta("gelaender"):
					(c as Node3D).visible = true
			Ton.spiele(spiel, "ui-klick", -4.0)
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
	var hier := karte.zelle_bei(_fuss2d())
	var war_drauf := _bruecke_felder.has(hier) and brakk.oben
	_bruecke_felder.clear()
	if war_drauf:
		# die Brücke erlischt unter Brakk: hinunter – oder, wo kein Platz ist, zurück auf den letzten Wall
		var unten := _fuss2d()
		if _passt_unten(unten):
			brakk.oben = false
			brakk.posten_zelle = Karte.KEINE
			brakk.zustand = Einheit.Zustand.BODEN
			_setze_fuss(unten)
		else:
			_setze_fuss(karte.mitte(brakk.posten_zelle))


# ------------------------------------------------------------------ Brakk-Mode: Lichtsäule [X] und Zeitlupe [V] (18.11.)

## 18.11. (Paul): [X] zielt (Marke folgt dem Fadenkreuz, solange schießt Brakk nicht), Linksklick bestätigt, [X] oder
## Rechtsklick bricht ab. Brakk wirbelt mit dem Finger, nach dem Vorlauf schlägt die Säule ein – Farbe und Art je
## aktivem Ring (ohne Ring: ein Einschlag mit Flächenschaden).
const SAEULE_WEITE := 14.0
const SAEULE_RADIUS := 1.5       # Felder
const SAEULE_SCHADEN := 150.0
const SAEULE_VORLAUF := 1.5      # Sekunden zwischen Bestätigen und Einschlag
const SAEULE_ABKLING := 25.0
const ZEITLUPE_SEK := 4.0        # in Echtzeit
const ZEITLUPE_TEMPO := 0.5
const ZEITLUPE_ABKLING := 60.0
var _saeule_rest := 0.0
var _saeule_zielt := false       # [X] gedrückt: Marke folgt dem Fadenkreuz
var _saeule_ziel := Vector2.INF  # bestätigter Punkt (2D), INF = keiner
var _saeule_t := 0.0             # Sekunden seit dem Bestätigen
var _saeule_marke: Node3D = null
var _saeule_farbe := Color("fff3a0")
var _saeule_ring := ""
var _saeule_blick := Vector2.UP  # Blickrichtung beim Bestätigen (für die Linie des Durchschlagrings)
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
	if not _darf("saeule") or _saeule_ziel != Vector2.INF:
		return
	if _saeule_rest > 0.0:
		spiel.melde("Lichtsäule wieder in %.0f s." % ceilf(_saeule_rest), 1.5)
		return
	_saeule_zielt = true
	_feuer = false
	_saeule_ring = brakk.fortschritt.aktiv() if brakk.fortschritt != null else ""
	_saeule_farbe = _ring_farbe(_saeule_ring) if _saeule_ring != "" else Color("fff3a0")
	_baue_saeule_marke()
	Ton.spiele(spiel, "ui-klick", -4.0)


func _saeule_abbrechen() -> void:
	_saeule_zielt = false
	if _saeule_marke != null:
		_saeule_marke.visible = false


## Linksklick beim Zielen: hier soll sie einschlagen.
func _saeule_bestaetigen() -> void:
	var p := ziel_welt()
	if p.x < -9000.0 or p.distance_to(_fuss2d()) > SAEULE_WEITE * Werte.ZELLE:
		spiel.melde("Zu weit für die Lichtsäule (höchstens %d Felder)." % int(SAEULE_WEITE), 1.5)
		return
	_saeule_zielt = false
	_saeule_ziel = p
	_saeule_t = 0.0
	_zaehle("saeulen")
	_saeule_rest = SAEULE_ABKLING
	_saeule_blick = Vector2(_vorne().x, _vorne().z).normalized()
	_hand_zeigen = maxf(_hand_zeigen, SAEULE_VORLAUF + 0.3)   # Brakk wirbelt mit dem Finger, bis die Säule einschlägt
	Ton.spiele(spiel, "alert", -6.0)


func _baue_saeule_marke() -> void:
	if _saeule_marke == null:
		_saeule_marke = Node3D.new()
		hd.add_child(_saeule_marke)
		for i in 2:
			var m := MeshInstance3D.new()
			var tor := TorusMesh.new()
			tor.inner_radius = SAEULE_RADIUS * (1.0 if i == 0 else 0.35) - 0.06
			tor.outer_radius = SAEULE_RADIUS * (1.0 if i == 0 else 0.35)
			tor.rings = 48
			m.mesh = tor
			m.material_override = _leucht(Color("fff3a0"), 0.9, 3.0)
			_saeule_marke.add_child(m)
	var gross := 0.6 if _saeule_ring == "laser" else 1.0
	_saeule_marke.scale = Vector3(gross, 1.0, gross)
	for m: MeshInstance3D in _saeule_marke.get_children():
		var mm := m.material_override as StandardMaterial3D
		mm.albedo_color = Color(_saeule_farbe.lightened(0.3), 0.9)
		mm.emission = _saeule_farbe
	_saeule_marke.visible = true


func _saeule_weiter(dt: float) -> void:
	_saeule_rest -= dt
	_saeulen_weiter(dt)
	_einschlaege_weiter(dt)
	if _saeule_zielt:
		# Marke folgt dem Fadenkreuz (halb durchsichtig, solange nicht bestätigt)
		_hand_zeigen = maxf(_hand_zeigen, 0.3)
		var p := ziel_welt()
		_saeule_marke.visible = p.x > -9000.0
		if _saeule_marke.visible:
			var h0 := hd.H if hd.ist_hoch(karte.zelle_bei(p)) else 0.0
			_saeule_marke.position = _zu3d(p, h0 + 0.05)
			_saeule_marke.rotation.y += dt * 1.5
		return
	if _saeule_ziel == Vector2.INF:
		return
	_saeule_t += dt
	var f := clampf(_saeule_t / SAEULE_VORLAUF, 0.0, 1.0)
	var ringe := _saeule_marke.get_children()
	(ringe[1] as Node3D).scale = Vector3.ONE * lerpf(2.8, 1.0, f)
	_saeule_marke.rotation.y += dt * (2.0 + 8.0 * f)
	var h := hd.H if hd.ist_hoch(karte.zelle_bei(_saeule_ziel)) else 0.0
	_saeule_marke.position = _zu3d(_saeule_ziel, h + 0.05)
	_saeule_marke.visible = int(_saeule_t * (4.0 + 12.0 * f)) % 2 == 0 or f > 0.9
	if _saeule_t < SAEULE_VORLAUF:
		return
	var p2 := _saeule_ziel
	_saeule_ziel = Vector2.INF
	_saeule_marke.visible = false
	_saeule_ausloesen(p2)


## Die Art des Einschlags je aktivem Ring.
func _saeule_ausloesen(p: Vector2) -> void:
	var r := SAEULE_RADIUS * Werte.ZELLE
	match _saeule_ring:
		"durchschuss":   # schmale Säulen in einer Linie durch 5 Felder
			for i in 5:
				_einschlaege.append([0.06 * i, p + _saeule_blick * (float(i) - 2.0) * Werte.ZELLE, Werte.ZELLE * 0.65, SAEULE_SCHADEN])
		"laser":   # klein, aber doppelter Schaden
			_einschlag(p, r * 0.6, SAEULE_SCHADEN * 2.0, 1.0)
		"feuerteam":   # drei kleinere Einschläge kurz nacheinander rund um die Marke
			for i in 3:
				var a := TAU * float(i) / 3.0 + randf() * 0.5
				_einschlaege.append([0.22 * i, p + Vector2(cos(a), sin(a)) * Werte.ZELLE * 0.8, r * 0.7, SAEULE_SCHADEN * 0.55])
		"minigun":   # die Säule bleibt 3 s stehen, dreht und schadet laufend
			_wirbel_saeule = [p, 3.0, 0.0]
			_neue_saeule(p, r * 0.8, 3.0)
		"abpraller":   # Einschlag, dann springt ein Blitz auf bis zu 3 Gegner in der Nähe
			var getroffen := _einschlag(p, r, SAEULE_SCHADEN, 1.0)
			_saeule_sprung(p, getroffen)
		"brandfeld":   # Einschlag und ein großes Brandfeld
			_einschlag(p, r, SAEULE_SCHADEN * 0.7, 1.0)
			spiel.lege_brand(p, r * 1.3, SAEULE_SCHADEN * 0.25)
		"plasmagel":   # wenig Schaden, aber alle im Feld 4 s stark gebremst (und mit dem Gelring verwundbar)
			for g: Gegner in _einschlag(p, r * 1.2, SAEULE_SCHADEN * 0.4, 1.0):
				if is_instance_valid(g) and not g._tot:
					g.gebremst = maxf(g.gebremst, 4.0)
			spiel.effekte.gel(p, r * 1.2, 4.0)
		_:
			_einschlag(p, r, SAEULE_SCHADEN, 1.0)


## Ein Einschlag: Schaden im Kreis (Kills geben Erfahrung), Lichtsäule, Funke, Wackeln. Gibt die getroffenen Gegner zurück.
func _einschlag(p: Vector2, radius: float, schaden: float, wucht: float, quelle: String = "saeule") -> Array:
	var getroffen: Array = []
	for g: Gegner in spiel.ego_gegner():
		if is_instance_valid(g) and not g._tot and g.position.distance_to(p) <= radius and not spiel._geschuetzt(g):
			getroffen.append(g)
	spiel.schadensquelle = "fabrik:-1,-1"
	spiel.brakk_quelle = quelle   # 19.11.
	spiel.schuss_herkunft = Vector2.INF
	for g: Gegner in getroffen:
		if is_instance_valid(g) and not g._tot:
			g.nimm_schaden(schaden * _faehigkeit_faktor() * _gel_bonus(g, true))
	spiel.schadensquelle = ""
	spiel.brakk_quelle = ""
	for g: Gegner in getroffen:
		if is_instance_valid(g) and g._tot:
			_kill(g)
	_neue_saeule(p, radius * 0.55, 0.45)
	_funke(_zu3d(p, 0.3), radius / Werte.ZELLE * 0.4)
	var nah := clampf(1.0 - p.distance_to(_fuss2d()) / (SAEULE_WEITE * Werte.ZELLE), 0.2, 1.0)
	_trauma = minf(1.0, _trauma + 0.45 * nah * wucht)
	_fov_puls = maxf(_fov_puls, 4.0 * wucht)
	Ton.spiele(spiel, "hit-boom", -6.0)
	return getroffen


func _einschlaege_weiter(dt: float) -> void:
	for e: Array in _einschlaege:
		e[0] = float(e[0]) - dt
	var faellig := _einschlaege.filter(func(e: Array) -> bool: return float(e[0]) <= 0.0)
	_einschlaege = _einschlaege.filter(func(e: Array) -> bool: return float(e[0]) > 0.0)
	for e: Array in faellig:
		_einschlag(e[1], e[2], e[3], 0.6)
	if _wirbel_saeule.is_empty():
		return
	_wirbel_saeule[1] = float(_wirbel_saeule[1]) - dt
	_wirbel_saeule[2] = float(_wirbel_saeule[2]) - dt
	if float(_wirbel_saeule[2]) <= 0.0:
		_wirbel_saeule[2] = 0.25
		var p: Vector2 = _wirbel_saeule[0]
		spiel.schadensquelle = "fabrik:-1,-1"
		spiel.brakk_quelle = "saeule"
		for g: Gegner in spiel.ego_gegner().duplicate():
			if is_instance_valid(g) and not g._tot and g.position.distance_to(p) <= SAEULE_RADIUS * Werte.ZELLE * 0.8 and not spiel._geschuetzt(g):
				g.nimm_schaden(SAEULE_SCHADEN * 0.12 * _faehigkeit_faktor() * _gel_bonus(g, true))
				if g._tot:
					_kill(g)
		spiel.schadensquelle = ""
		spiel.brakk_quelle = ""
	if float(_wirbel_saeule[1]) <= 0.0:
		_wirbel_saeule = []


## Sprungring: vom Einschlag aus springt ein Blitz nacheinander auf bis zu drei weitere Gegner.
func _saeule_sprung(p: Vector2, schon: Array) -> void:
	var von := p
	var getroffen := schon.duplicate()
	for i in 3:
		var bester: Gegner = null
		var beste := 4.0 * Werte.ZELLE
		for g: Gegner in spiel.ego_gegner():
			if is_instance_valid(g) and not g._tot and not getroffen.has(g) and g.position.distance_to(von) < beste and not spiel._geschuetzt(g):
				beste = g.position.distance_to(von)
				bester = g
		if bester == null:
			return
		_strahl(_zu3d(von, 0.5), _zu3d(bester.position, 0.5), _saeule_farbe)
		spiel.schadensquelle = "fabrik:-1,-1"
		spiel.brakk_quelle = "saeule"
		bester.nimm_schaden(SAEULE_SCHADEN * 0.5 * _faehigkeit_faktor() * _gel_bonus(bester, true))
		spiel.schadensquelle = ""
		spiel.brakk_quelle = ""
		if bester._tot:
			_kill(bester)
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
	m.material_override = _leucht(_saeule_farbe.lightened(0.25), 0.85, 4.0)
	hd.add_child(m)
	m.position = _zu3d(p, 7.0)
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
func _brakk_sprung(erstes: Gegner, spruenge: int, schaden: float) -> void:
	var getroffen: Array = [erstes]
	var punkt := erstes.position
	for i in spruenge:
		var bester: Gegner = null
		var beste := Werte.ABPRALLER_WEITE * Werte.ZELLE
		for g: Gegner in spiel.ego_gegner():
			if is_instance_valid(g) and not g._tot and not getroffen.has(g) and not spiel._geschuetzt(g) and punkt.distance_to(g.position) < beste:
				beste = punkt.distance_to(g.position)
				bester = g
		if bester == null:
			return
		spiel.effekte.strahl(punkt, bester.position, Einheit.ABZEICHEN["abpraller"], 2.0)
		spiel.flaechenschaden(bester.position, Werte.ZELLE * 0.4, schaden, Einheit.ABZEICHEN["abpraller"])
		if bester._tot:
			_kill(bester)
		getroffen.append(bester)
		punkt = bester.position


## Gelring aktiv: gebremste Gegner (von Brakk, Gel-Fabriken oder der Gel-Säule) nehmen mehr Schaden von Brakk.
func _gel_bonus(g: Gegner, faehigkeit: bool = false) -> float:
	var f := brakk.fortschritt
	if f == null or g.gebremst <= 0.0:
		return 1.0
	return float(f.brakk_wert_aktiv("gel_bonus", 1.0) if faehigkeit else f.brakk_wert("gel_bonus", 1.0))


## [V]: Zeitlupe – die Welt läuft halb so schnell, Brakk (Echtzeit) nicht. Lange Abklingzeit.
func _zeitlupe_start() -> void:
	if not _darf("zeitlupe") or _zeitlupe > 0.0:
		return
	if _zeitlupe_rest > 0.0:
		spiel.melde("Zeitlupe wieder in %.0f s." % ceilf(_zeitlupe_rest), 1.5)
		return
	_zeitlupe = ZEITLUPE_SEK
	_zeitlupe_rest = ZEITLUPE_ABKLING
	_zaehle("zeitlupen")
	_zl_beginn()   # 19.11.: Zusatz je aktivem Ring
	if _stop_vorher >= 0.0:
		_zl_vorher = _stop_vorher
		_stop_vorher = _stop_vorher * ZEITLUPE_TEMPO
	else:
		_zl_vorher = Engine.time_scale
		Engine.time_scale = _zl_vorher * ZEITLUPE_TEMPO
	_fov_puls = maxf(_fov_puls, 6.0)
	Ton.spiele(spiel, "alert", -2.0)


func _zeitlupe_weiter(echt: float) -> void:
	_zl_weiter(echt)   # 19.11.
	_zeitlupe_rest -= echt
	if _zeitlupe <= 0.0:
		return
	_zeitlupe -= echt
	if _zeitlupe <= 0.0:
		_zeitlupe_aus()


func _zeitlupe_aus() -> void:
	_zl_ende()   # 19.11.
	_zeitlupe = 0.0
	if _stop_vorher >= 0.0:
		_stop_vorher = _zl_vorher   # ein laufender Hit-Stop stellt danach das normale Tempo her
	else:
		Engine.time_scale = _zl_vorher


## Blauer Schleier am Bildrand, solange die Zeitlupe läuft.
func _zeitlupe_bild(g: Vector2) -> void:
	if _zeitlupe <= 0.0:
		return
	var a := clampf(minf(_zeitlupe, ZEITLUPE_SEK - _zeitlupe) * 4.0, 0.0, 1.0)
	_bild.draw_rect(Rect2(Vector2.ZERO, g), Color(0.3, 0.5, 1.0, 0.08 * a))
	for i in 6:
		var d := float(i) * 10.0
		_bild.draw_rect(Rect2(Vector2(d, d), g - Vector2(d, d) * 2.0), Color(0.45, 0.7, 1.0, 0.07 * a), false, 10.0)
	Stil.schreibe_mittig(_bild, Vector2(g.x / 2.0, 172.0), "ZEITLUPE %.1f s" % maxf(0.0, _zeitlupe), 18, Color(0.7, 0.85, 1.0, a))


## 18.11. (Paul): Lichtsäule – Brakk wirbelt mit dem Zeigefinger: eine Lichtspur kreist um die Fingerspitze, immer schneller.
const FINGERSPITZE := Vector2(36, 8)   # im Handbild (ringhand.png)


func _finger_wirbel(rp: Vector2, wpx: float, auf: float) -> void:
	if _saeule_ziel == Vector2.INF and not _saeule_zielt:
		return
	var f := 0.0 if _saeule_zielt else clampf(_saeule_t / SAEULE_VORLAUF, 0.0, 1.0)
	var mitte := rp.round() + FINGERSPITZE * wpx
	var w := Time.get_ticks_msec() / 1000.0 * (10.0 + 18.0 * f)
	var r := (5.0 + 3.0 * f) * wpx
	for i in 14:
		var a := w - float(i) * 0.32
		var p := mitte + Vector2(cos(a), sin(a) * 0.55) * r
		var alpha := (1.0 - float(i) / 14.0) * auf
		_bild.draw_rect(Rect2((p - Vector2(1, 1) * wpx).round(), Vector2(2, 2) * wpx), Color(_saeule_farbe.lightened(0.4 * (1.0 - float(i) / 14.0)), alpha))
	_bild.draw_circle(mitte, (2.0 + 2.0 * f) * wpx, Color(_saeule_farbe, 0.5 * auf))




## 18.11. (Paul): Lichtbauten (Treppe, Brücke, Anker) leuchten in der Farbe des aktiven Rings, ohne Ring cyan.
func _licht_farbe() -> Color:
	var f := brakk.fortschritt
	if f == null or f.aktiv() == "":
		return LICHT
	return _ring_farbe(f.aktiv())


# ------------------------------------------------------------------ Brakk-Mode: Treffer, Leben, Warnungen (18.11.)

var _leben_vorher := -1.0
var _leben_spur := -1.0          # helle Spur in der Lebensleiste: fällt verzögert dem Leben nach
var _treffer_von: Array = []     # [Winkel (Welt), Restzeit]
var _treffer_rot := 0.0          # roter Rand nach einem Treffer


## Jedes Bild: Lebensverlust erkennen – Richtung zum wahrscheinlichen Schützen (nächster Gegner oder Schleuder).
func _treffer_merken(dt: float) -> void:
	if _leben_vorher < 0.0:
		_leben_vorher = brakk.leben
		_leben_spur = brakk.leben
	_treffer_rot = maxf(0.0, _treffer_rot - dt * 1.8)
	for t: Array in _treffer_von:
		t[1] = float(t[1]) - dt
	_treffer_von = _treffer_von.filter(func(t: Array) -> bool: return float(t[1]) > 0.0)
	if brakk.leben < _leben_vorher - 0.5:
		var verlust := (_leben_vorher - brakk.leben) / maxf(1.0, brakk.max_leben)
		_treffer_rot = minf(1.0, _treffer_rot + 0.35 + verlust * 3.0)
		_trauma = minf(1.0, _trauma + 0.1 + verlust)
		var quelle := Vector2.INF
		var beste := INF
		var bg: BrakkGeschosse = spiel.brakk_geschosse
		if bg != null and Time.get_ticks_msec() - bg.treffer_ms < 250:
			quelle = bg.treffer_von   # 20.11.: Schritt 6c – Randblitz in Richtung des echten Schützen
			beste = -1.0
		for g: Gegner in (spiel.ego_gegner() if quelle == Vector2.INF else []):
			if is_instance_valid(g) and not g._tot:
				var d := g.position.distance_to(brakk.position)
				if d < beste and d < 5.0 * Werte.ZELLE:
					beste = d
					quelle = g.position
		if quelle == Vector2.INF:
			for zb: Variant in spiel.zonenbauten:
				if is_instance_valid(zb):
					var d2 := (zb as Node2D).position.distance_to(brakk.position)
					if d2 < beste:
						beste = d2
						quelle = (zb as Node2D).position
		if quelle != Vector2.INF:
			_treffer_von.append([(quelle - brakk.position).angle(), 1.2])
	if brakk.leben > _leben_vorher:
		_leben_spur = brakk.leben
	_leben_vorher = brakk.leben
	_leben_spur = move_toward(_leben_spur, brakk.leben, brakk.max_leben * 0.35 * dt) if _leben_spur > brakk.leben else brakk.leben


## Roter Rand (Treffer, wenig Leben) und Bögen am Rand des Bilds in Richtung der Treffer.
func _gefahr_bild(g: Vector2) -> void:
	var anteil := clampf(brakk.leben / maxf(1.0, brakk.max_leben), 0.0, 1.0)
	var rot := _treffer_rot
	if anteil < 0.35 and not brakk.gefallen:
		rot = maxf(rot, (0.35 - anteil) * 2.0 * (0.6 + 0.4 * sin(Time.get_ticks_msec() / 160.0)))
	if rot > 0.01:
		for i in 8:
			var d := float(i) * 9.0
			_bild.draw_rect(Rect2(Vector2(d, d), g - Vector2(d, d) * 2.0), Color(1.0, 0.1, 0.12, 0.09 * rot * (1.0 - float(i) / 8.0)), false, 9.0)
	var m := g / 2.0
	var r := g.y * 0.34
	var blick := atan2(_vorne().z, _vorne().x)   # Blickrichtung in der 2D-Welt (x, y = z)
	for t: Array in _treffer_von:
		var rel := float(t[0]) - blick - PI / 2.0   # 0 = oben auf dem Bild (vorn)
		var a := clampf(float(t[1]) / 1.2, 0.0, 1.0)
		_bild.draw_arc(m, r, rel - 0.32, rel + 0.32, 18, Color(1.0, 0.2, 0.2, 0.85 * a), 10.0)
		_bild.draw_arc(m, r - 10.0, rel - 0.18, rel + 0.18, 12, Color(1.0, 0.55, 0.5, 0.6 * a), 4.0)


## Steine, die auf Brakk zufliegen: roter Kreis am Landepunkt und ein Warnzeichen am Stein – mit [Shift] ausweichen.
func _wurf_warnung() -> void:
	var k := hd.kamera
	for w: Array in spiel.effekte.wuerfe():
		var ziel: Vector2 = w[1]
		if ziel.distance_to(brakk.position) > Werte.ZELLE * 2.0:
			continue
		var lage: Array = spiel.effekte.wurf_lage(w)
		if not bool(lage[3]):
			continue
		var puls := 0.6 + 0.4 * sin(Time.get_ticks_msec() / 70.0)
		# Landekreis auf dem Boden
		var h := hd.H if hd.ist_hoch(karte.zelle_bei(ziel)) else 0.0
		var punkte := PackedVector2Array()
		var sichtbar := true
		for i in 21:
			var a := TAU * float(i) / 20.0
			var p3 := _zu3d(ziel + Vector2(cos(a), sin(a)) * Werte.ZELLE * 0.7, h + 0.03)
			if k.is_position_behind(p3):
				sichtbar = false
				break
			punkte.append(k.unproject_position(p3))
		if sichtbar:
			_bild.draw_polyline(punkte, Color(1.0, 0.2, 0.15, 0.9 * puls), 3.0)
		# Warnzeichen am Stein
		var s3 := _zu3d(lage[0] as Vector2, float(lage[1]) / Werte.ZELLE)
		if k.is_position_behind(s3):
			continue
		var s := k.unproject_position(s3)
		_bild.draw_circle(s, 16.0, Color(1.0, 0.15, 0.1, 0.25 * puls))
		_bild.draw_arc(s, 16.0, 0.0, TAU, 20, Color(1.0, 0.25, 0.2, 0.95), 2.5)
		Stil.schreibe_mittig(_bild, s + Vector2(0, -28), "!", 26, Color(1.0, 0.3, 0.25, puls))


## 18.11.: Am Handy keine Tastennamen in Hinweisen – „[F] Lichtterminal“ wird „Lichtterminal“.
func _t(s: String) -> String:
	if touch == null:
		return s
	return RegEx.create_from_string("\\s*\\[[^\\]]*\\]\\s*").sub(s, " ", true).strip_edges()


# ------------------------------------------------------------------ Brakk-Mode: Einsatz-Tafel und Einflug (18.11.)

## 18.11. (Paul): nicht abrupt in die Ego-Sicht – erst eine Einsatz-Tafel (Tasten, Ablauf), der Countdown wartet.
## „Los“ (Klick, Enter, Leertaste): das Bild blendet aus dem Schwarzen auf, die Kamera senkt sich von oben in Brakks Augen.
const EINFLUG_SEK := 1.8
var _briefing: Control = null
var _einflug := -1.0             # läuft: Sekunden seit „Los“ (-1 = nein)
var _los_knopf := Rect2()


func _briefing_zeigen() -> void:
	_briefing = Control.new()
	_briefing.set_anchors_preset(Control.PRESET_FULL_RECT)
	_briefing.mouse_filter = Control.MOUSE_FILTER_STOP
	_briefing.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_briefing.draw.connect(_male_briefing)
	_briefing.gui_input.connect(_briefing_klick)
	_ebene.add_child(_briefing)


func _briefing_offen() -> bool:
	return _briefing != null and _briefing.visible and _einflug < 0.0


func _briefing_klick(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		if _los_knopf.has_point((event as InputEventMouseButton).position):
			_briefing_los()


func _briefing_los() -> void:
	if not _briefing_offen():
		return
	_einflug = 0.0
	_briefing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	Ton.spiele(spiel, "ui-klick")
	Ton.spiele(spiel, "tc-arc", -8.0)


## Läuft jedes Bild (Echtzeit): Einflug weiterzählen, am Ende die Tafel weg.
func _einflug_weiter(echt: float) -> void:
	if _einflug < 0.0:
		return
	_einflug += echt
	_briefing.queue_redraw()
	if _einflug >= EINFLUG_SEK:
		_einflug = -1.0
		_briefing.visible = false
		_trauma = minf(1.0, _trauma + 0.2)   # Brakk landet
		_rueckstoss[0] = 0.8
		_rueckstoss[1] = 0.8


## Kamera während des Einflugs: von oben hinten herab, mit Blick nach unten, weich in Brakks Augen.
func _einflug_kamera(k: Camera3D) -> void:
	var t := 1.0 if _einflug < 0.0 else clampf(_einflug / EINFLUG_SEK, 0.0, 1.0)
	if _briefing_offen():
		t = 0.0
	if t >= 1.0:
		return
	var e := 1.0 - pow(1.0 - t, 3.0)   # Ease-out
	var rest := 1.0 - e
	k.position += Vector3(0, 9.0 * rest, 0) - _vorne() * 7.0 * rest
	k.rotation.x -= 0.75 * rest


## 18.11. (Paul: „nicht so blockartig“): Einsatz-Tafel in drei Teilen – Kopf mit Warnstreifen, Tasten als
## Tastenkappen (statt Fließtext), unten meldet sich Sonde 7 im Funkfenster und tippt den Ablauf.
const BRIEFING_SONDE := "res://assets/sprites/tutorial/sonde7.png"
const BRIEFING_HOLO := Color("6ee6ff")
const BRIEFING_HOLO_TEXT := Color("c8f4ff")
const BRIEFING_TIPPEN := 55.0   # Zeichen je Sekunde
const BRIEFING_FUNK := "Kommandant, Sonde 7 hier. Heute gehst du selbst raus. Die Welle rollt nach dem Countdown an – [Enter] holt sie früher. Es werden viele, und Steine mit rotem Kreis fliegen auf dich: ausweichen! Fabriken bauen hier nicht aus, deine Ringe machen sie stark. Viel Glück. Sonde 7 Ende."
const BRIEFING_FUNK_TOUCH := "Kommandant, Sonde 7 hier. Heute gehst du selbst raus. Die Welle rollt nach dem Countdown an. Es werden viele, und Steine mit rotem Kreis fliegen auf dich: ausweichen! Fabriken bauen hier nicht aus, deine Ringe machen sie stark. Viel Glück. Sonde 7 Ende."
const BRIEFING_LICHTER := [[35, 40, 6, Color("6cecfe")], [49, 50, 6, Color("ff4a5e")], [18, 43, 4, Color("ff4a5e")]]
var _briefing_t0 := -1
var _sonde_bild: Texture2D = null


func _male_briefing() -> void:
	var ci := _briefing
	var g := ci.get_viewport_rect().size
	if _einflug >= 0.0:
		# Aufblenden aus dem Schwarzen
		var a := clampf(1.0 - _einflug / (EINFLUG_SEK * 0.6), 0.0, 1.0)
		ci.draw_rect(Rect2(Vector2.ZERO, g), Color(0, 0, 0, a))
		return
	if _briefing_t0 < 0:
		_briefing_t0 = Time.get_ticks_msec()
	var zeit := (Time.get_ticks_msec() - _briefing_t0) / 1000.0
	ci.draw_rect(Rect2(Vector2.ZERO, g), Color(0.02, 0.03, 0.05, 0.97))
	for sy in range(0, int(g.y), 4):   # feine Bildzeilen
		ci.draw_rect(Rect2(0, sy, g.x, 1), Color(LICHT, 0.025))
	var w := minf(1040.0, g.x - 40.0)
	var h := minf(580.0, g.y - 40.0)
	var o := ((g - Vector2(w, h)) / 2.0).round()
	var ein := 1.0 - pow(1.0 - clampf(zeit / 0.35, 0.0, 1.0), 3.0)
	o.y += roundf(14.0 * (1.0 - ein))
	Stil.platte(ci, Rect2(o, Vector2(w, h)), 12.0, Color(0.04, 0.05, 0.08, 0.98), LICHT.darkened(0.35))
	# Kopf: Titel, Unterzeile, Warnstreifen rechts, Trennlinie mit hellem Anfang
	Stil.schreibe(ci, o + Vector2(32, 42), "BRAKK-MODE", 40, LICHT)
	Stil.schreibe(ci, o + Vector2(32, 76), "Kommandant Brakk hält die Front – diesmal bist du Brakk.", 18, Stil.TEXT_BLASS)
	for i in 7:
		var sx := o.x + w - 60.0 - i * 18.0
		ci.draw_colored_polygon(PackedVector2Array([Vector2(sx, o.y + 26), Vector2(sx + 9, o.y + 26), Vector2(sx + 1, o.y + 50), Vector2(sx - 8, o.y + 50)]),
			Color(Stil.GOLD, 0.55 - i * 0.07))
	Stil.schreibe(ci, Vector2(o.x + w - 186.0 - Stil.breite("EINSATZ", 16), o.y + 38), "EINSATZ", 16, Color(Stil.GOLD, 0.8))
	ci.draw_rect(Rect2(o.x + 32, o.y + 100, w - 64, 1), Color(LICHT, 0.3))
	ci.draw_rect(Rect2(o.x + 32, o.y + 99, 120, 3), LICHT)
	# Steuerung als Tastenkappen in zwei Spalten
	var touch_an := Touch.ohne_maus()
	var tasten: Array = [
		[["W", "A", "S", "D"], "laufen"],
		[["Maus", "Klick"], "zielen, schießen – Pistolen im Wechsel"],
		[["Shift", "Leer"], "Rolle · Sprung"],
		[["E"], "Lichttreppe, oben Lichtbrücke"],
		[["1–7"], "bauen (5 Felder Reichweite)"],
		[["F"], "ausbauen · an der Basis: Lichtterminal"],
		[["Rad"], "aktiver Ring"],
		[["C"], "Ringfeld: Fabriken bauen seine Truppe"],
	]
	if touch_an:
		tasten = [
			[["links"], "laufen"],
			[["rechts"], "wischen zum Zielen – Brakk schießt selbst"],
			[["tippen"], "Fähigkeiten auslösen"],
			[["halten"], "und ziehen: Fähigkeit zielen"],
			[["Rand"], "bauen, ausbauen, Ringe"],
		]
	Stil.schreibe(ci, o + Vector2(32, 126), "STEUERUNG", 18, Stil.GOLD)
	var spalte := (w - 64.0) / 2.0
	for i in tasten.size():
		var reihe: Array = tasten[i]
		var p := o + Vector2(32.0 + (i % 2) * spalte, 162.0 + (i / 2) * 44.0)
		var sichtbar := clampf((zeit - 0.15 - i * 0.05) / 0.25, 0.0, 1.0)
		if sichtbar <= 0.0:
			continue
		var x := p.x
		for t: String in reihe[0]:
			x += _briefing_taste(ci, Vector2(x, p.y), t, true, sichtbar) + 4.0
		Stil.schreibe(ci, Vector2(x + 8.0, p.y), str(reihe[1]), 18, Color(Stil.TEXT, sichtbar))
	# Freischaltbar mit den Stufen: gedimmte Kappen mit Namen
	if not touch_an:
		var y := o.y + 162.0 + 4 * 44.0 + 4.0
		Stil.schreibe(ci, Vector2(o.x + 32, y), "MIT DEN STUFEN", 16, Stil.TEXT_BLASS)
		var x := o.x + 32.0 + Stil.breite("MIT DEN STUFEN", 16) + 16.0
		for f: Array in [["Q", "Anker"], ["RK", "Ladestrahl"], ["X", "Lichtsäule"], ["R", "Klon"], ["V", "Zeitlupe"]]:
			x += _briefing_taste(ci, Vector2(x, y), str(f[0]), false, 1.0) + 6.0
			Stil.schreibe(ci, Vector2(x, y), str(f[1]), 16, Stil.TEXT_BLASS)
			x += Stil.breite(str(f[1]), 16) + 18.0
	# Funkfenster: Sonde 7 tippt den Ablauf
	var funk := Rect2(o.x + 32, o.y + 386, w - 64, 112)
	Stil.platte(ci, funk, 6.0, Color(0.03, 0.10, 0.16, 0.92), BRIEFING_HOLO.darkened(0.25))
	if _sonde_bild == null:
		_sonde_bild = load(BRIEFING_SONDE)
	var bild := Rect2(funk.position + Vector2(8, 8), Vector2(96, 96))
	ci.draw_rect(bild, Color(0.01, 0.04, 0.07))
	if _sonde_bild != null:
		ci.draw_texture_rect(_sonde_bild, bild, false)
	var text := BRIEFING_FUNK_TOUCH if touch_an else BRIEFING_FUNK
	var gezeigt := int(maxf(zeit - 0.5, 0.0) * BRIEFING_TIPPEN)
	var spricht := gezeigt < text.length()
	for l: Array in BRIEFING_LICHTER:
		var staerke := (0.35 + 0.65 * absf(sin(zeit * 11.0 + float(l[0])))) if spricht else 0.25
		var lp := bild.position + Vector2(float(l[0]), float(l[1]))
		ci.draw_circle(lp, float(l[2]) * 1.6, Color(l[3], 0.22 * staerke))
		ci.draw_circle(lp, float(l[2]) * 0.8, Color(l[3], 0.55 * staerke))
	ci.draw_rect(bild, BRIEFING_HOLO.darkened(0.3), false, 1.0)
	var tx := bild.end.x + 16.0
	Stil.schreibe(ci, Vector2(tx, funk.position.y + 18.0), "SONDE 7 · LEITSTELLE", 16, BRIEFING_HOLO)
	if spricht and fmod(zeit, 0.5) < 0.25:
		ci.draw_circle(Vector2(tx + Stil.breite("SONDE 7 · LEITSTELLE", 16) + 10.0, funk.position.y + 18.0), 3.0, Stil.ROT)
	Stil.absatz(ci, Vector2(tx, funk.position.y + 30.0), text.left(gezeigt), funk.end.x - tx - 14.0, 18, BRIEFING_HOLO_TEXT)
	# Los-Knopf mit abgeschrägten Ecken
	_los_knopf = Rect2(Vector2(o.x + w / 2.0 - 140.0, o.y + h - 66.0), Vector2(280, 44))
	var puls := 0.75 + 0.25 * sin(Time.get_ticks_msec() / 220.0)
	Stil.platte(ci, _los_knopf, 8.0, Color(LICHT.darkened(0.6), 0.6 + 0.3 * puls), LICHT)
	Stil.schreibe_mittig(ci, _los_knopf.get_center(), "Los geht's" + ("" if touch_an else "  [Enter]"), 22, Color.WHITE)


## Eine Tastenkappe mit linker Mitte `p`; gibt ihre Breite zurück. `aktiv = false`: gedimmt (noch gesperrt).
func _briefing_taste(ci: CanvasItem, p: Vector2, t: String, aktiv: bool, a: float) -> float:
	var groesse := 18 if aktiv else 16
	var bw := maxf(28.0 if aktiv else 24.0, Stil.breite(t, groesse) + 14.0)
	var hh := 28.0 if aktiv else 22.0
	var r := Rect2(p.x, p.y - hh / 2.0, bw, hh)
	ci.draw_rect(Rect2(r.position + Vector2(0, 3), r.size), Color(0, 0, 0, 0.5 * a))   # Kappe steht etwas hoch
	Stil.platte(ci, r, 3.0, Color(Stil.METALL_TIEF, a), Color(LICHT if aktiv else Stil.RAHMEN, a))
	Stil.schreibe_mittig(ci, r.get_center(), t, groesse, Color(Color.WHITE if aktiv else Stil.TEXT_BLASS, a))
	return bw


# ------------------------------------------------------------------ Brakk-Mode: Doppelsprung mit Lichtplattform (19.11.)

## 19.11. (Paul): Leertaste in der Luft – der Ring wirft eine Lichtplattform unter Brakks Füße, er stößt sich ab.
## Einmal je Sprung, wieder nach der Landung. Die Plattform springt auf (Überschwung), pulsiert kurz und verblasst.
const DOPPEL_SPRUNG := 4.0       # Startgeschwindigkeit nach oben (der erste Sprung: SPRUNG)
const PLATTFORM_SEK := 0.7


func _doppelsprung() -> void:
	_zaehle("spruenge")
	if brakk.oben and _absprung_start():
		return   # 19.11. (Paul): vom Wall hinunter, unten die Druckwelle
	_doppelt_genutzt = true
	steig = DOPPEL_SPRUNG
	if _haken >= 0.0:
		_flug *= ABSCHNELLEN_MAL   # 19.11.: am Seil – das Seil löst sich, der Schwung bleibt
		_haken_los()
	_lichtplattform()


## Sechseckige Lichtplattform unter Brakks Füßen, in der Farbe des aktiven Rings (springt auf, dreht sich, verblasst).
func _lichtplattform() -> void:
	var farbe := _licht_farbe()
	var p := Node3D.new()
	hd.add_child(p)
	p.position = _fuss3d() - Vector3(0, 0.04, 0)
	var platte := MeshInstance3D.new()
	var zyl := CylinderMesh.new()
	zyl.top_radius = 0.45
	zyl.bottom_radius = 0.38
	zyl.height = 0.06
	zyl.radial_segments = 6   # sechseckig, wie eine Lichtkachel
	platte.mesh = zyl
	platte.material_override = _leucht(farbe, 0.6, 2.2)
	p.add_child(platte)
	var rand := MeshInstance3D.new()
	var tor := TorusMesh.new()
	tor.inner_radius = 0.44
	tor.outer_radius = 0.5
	tor.ring_segments = 6
	tor.rings = 6
	rand.mesh = tor
	rand.material_override = _leucht(farbe.lightened(0.6), 0.95, 3.0)
	rand.position.y = 0.03
	p.add_child(rand)
	p.scale = Vector3(0.2, 1.0, 0.2)
	_plattformen.append([p, 0.0])
	_trauma = minf(1.0, _trauma + 0.08)
	_rueckstoss[0] = 0.4
	_rueckstoss[1] = 0.4
	Ton.spiele(spiel, "tc-arc", -8.0)


func _plattformen_weiter(dt: float) -> void:
	for e: Array in _plattformen:
		e[1] = float(e[1]) + dt
		var p: Node3D = e[0]
		var t := float(e[1])
		var x := clampf(t / 0.12, 0.0, 1.0)
		var s := 1.0 + 2.70158 * pow(x - 1.0, 3) + 1.70158 * pow(x - 1.0, 2)   # Ease-out-back
		var weit := maxf(0.2, s) + 0.15 * t
		p.scale = Vector3(weit, 1.0, weit)
		p.rotation.y += dt * 2.0
		var a := clampf(1.0 - (t - PLATTFORM_SEK * 0.5) / (PLATTFORM_SEK * 0.5), 0.0, 1.0)
		for c: Node in p.get_children():
			var m := (c as MeshInstance3D).material_override as StandardMaterial3D
			m.albedo_color.a = a * (0.6 if c == p.get_child(0) else 0.95)
	var weg := _plattformen.filter(func(e: Array) -> bool: return float(e[1]) >= PLATTFORM_SEK)
	for e: Array in weg:
		(e[0] as Node).queue_free()
	_plattformen = _plattformen.filter(func(e: Array) -> bool: return float(e[1]) < PLATTFORM_SEK)


# ------------------------------------------------------------------ Brakk-Mode: Absprung vom Wall mit Druckwelle (19.11.)

## 19.11. (Paul): Oben auf dem Wall springen, in der Luft noch einmal springen – Brakk stößt sich von der Lichtplattform ab,
## fliegt in Laufrichtung (ohne Taste: Blickrichtung) hinunter und schlägt unten mit einer Druckwelle ein.
const ABSPRUNG_WEITE := 4.0      # höchstens so viele Felder weit sucht er einen Landeplatz
const DRUCK_RADIUS := 1.3        # Felder
const DRUCK_SCHADEN := 30.0      # 19.11. (Paul): genervt (war 80) – wie die Säule mal Fähigkeitsschaden
var _absprung := -1.0            # läuft: Sekunden seit dem Abstoßen (-1 = nein)
var _ab_von := Vector3.ZERO
var _ab_nach := Vector3.ZERO
var _ab_dauer := 0.5
var _lauf := Vector2.ZERO        # Laufgeschwindigkeit (Felder/s, x und z) aus _gehen
var _flug := Vector2.ZERO        # Schwung in der Luft (Felder/s), aus Seil oder Abschnellen – weg bei der Landung


func _absprung_start() -> bool:
	var r := _lauf.normalized() if _lauf != Vector2.ZERO else Vector2(_vorne().x, _vorne().z).normalized()
	var ziel := Vector2.INF
	var w := 1.0
	while w <= ABSPRUNG_WEITE and ziel == Vector2.INF:
		var p := _fuss2d() + r * w * Werte.ZELLE
		if _passt_unten(p) and not hd.ist_hoch(karte.zelle_bei(p)):
			ziel = p
		w += 0.25
	if ziel == Vector2.INF:
		return false
	_doppelt_genutzt = true
	_lichtplattform()
	if _haken >= 0.0:
		_haken_los()
	_treppe_rest = minf(_treppe_rest, 0.0)   # die Treppe vergeht – sonst führt sie unten gleich wieder hinauf
	_ab_von = _fuss3d()
	_ab_nach = _zu3d(ziel, 0.0)
	_ab_dauer = clampf(_ab_von.distance_to(_ab_nach) / 6.0, 0.4, 0.7)
	_absprung = 0.0
	steig = 0.0
	_flug = Vector2.ZERO
	brakk.oben = false
	brakk.posten_zelle = Karte.KEINE
	brakk.zustand = Einheit.Zustand.BODEN
	return true


func _absprung_weiter(dt: float) -> void:
	_absprung += dt
	var f := clampf(_absprung / _ab_dauer, 0.0, 1.0)
	var p := _ab_von.lerp(_ab_nach, f)
	hoehe = lerpf(_ab_von.y, 0.0, f * f) + sin(f * PI) * 0.6   # erst hoch, dann steil hinunter
	brakk.position = _zu2d(p)
	_fov_weit = 6.0 * sin(f * PI)
	_geht = false
	if f < 1.0:
		return
	_absprung = -1.0
	_fov_weit = 0.0
	hoehe = 0.0
	_setze_fuss(_zu2d(_ab_nach))
	_doppelt_genutzt = false
	_delle = 1.0
	_rueckstoss[0] = 0.8
	_rueckstoss[1] = 0.8
	_druckwelle(_zu2d(_ab_nach))


func _druckwelle(p: Vector2) -> void:
	var r := DRUCK_RADIUS * Werte.ZELLE
	spiel.effekte.flaeche(p, r, _licht_farbe())
	_einschlag(p, r, DRUCK_SCHADEN, 0.9, "absprung")
	Ton.spiele(spiel, "hit-thud", -2.0)


# ------------------------------------------------------------------ Brakk-Mode: Lichtanker hängt, Schwingen (19.11.)

## 19.11. (Paul): Erstes [Q] wirft den Haken – er bleibt bis HAKEN_HALTEN hängen. Das Seil hält Brakk wie eine Leine
## (weiter als das Seil kommt er nicht). In der Luft am straffen Seil wird er leichter und schwingt um den Haken:
## springt er im Laufen, nimmt er den Lauf als Schwung mit. Zweites [Q] zieht heran, nochmal springen schnellt ab.
const HAKEN_HALTEN := 5.0
const SCHWING_MAL := 1.3         # Laufgeschwindigkeit -> Schwung beim Sprung am Seil
const SCHWING_LEICHT := 0.45     # so viel der Schwere hebt das Seil in der Luft auf
const ABSCHNELLEN_MAL := 1.3     # Schwung beim Lösen mit dem Doppelsprung
var _haken := -1.0               # hängt: Sekunden seit dem Wurf (-1 = nein)
var _haken_p := Vector3.ZERO
var _haken_wall := Karte.KEINE
var _seil_lang := 1.0
var _anker_erklaert := false


func _anker_ziehen() -> void:
	_anker_von = _fuss3d()
	_anker_nach = _haken_p
	_anker_wall = _haken_wall
	_anker_dauer = maxf(0.25, _anker_von.distance_to(_anker_nach) / ANKER_TEMPO)
	_anker = 0.0
	_haken = -1.0
	_anker_rest = ANKER_ABKLING * _mobil()
	steig = 0.0
	_flug = Vector2.ZERO
	if brakk.oben:
		brakk.oben = false
		brakk.posten_zelle = Karte.KEINE
		brakk.zustand = Einheit.Zustand.BODEN
	_hand_zeigen = maxf(_hand_zeigen, _anker_dauer + 0.2)
	_trauma = minf(1.0, _trauma + 0.15)
	_kick += 0.03
	Ton.spiele(spiel, "tc-rail", -10.0)


func _haken_los() -> void:
	_haken = -1.0
	_anker_rest = ANKER_ABKLING * _mobil()
	if _anker_seil != null:
		_anker_seil.visible = false
		_anker_haken.visible = false


func _haken_weiter(dt: float) -> void:
	_haken += dt
	if _haken >= HAKEN_HALTEN or brakk.gefallen:
		_haken_los()
		return
	_hand_zeigen = maxf(_hand_zeigen, 0.3)
	var fuss := _fuss3d()
	var d := fuss - _haken_p
	var luft := hoehe > _boden() + 0.001 or steig > 0.0
	if luft and d.length() > _seil_lang * 0.9:
		steig += SCHWERE * SCHWING_LEICHT * dt   # das straffe Seil trägt mit
	if d.length() > _seil_lang:
		var n := d.normalized()
		if luft:
			var soll := _haken_p + n * _seil_lang
			var s := Vector2(soll.x - fuss.x, soll.z - fuss.z) * Werte.ZELLE
			_luft_schritt(Vector2(s.x, 0.0))
			_luft_schritt(Vector2(0.0, s.y))
			hoehe = maxf(_boden(), soll.y)
			var v := Vector3(_flug.x, steig, _flug.y)
			var raus := v.dot(n)
			if raus > 0.0:
				v -= n * raus   # nur noch quer zum Seil: Schwingen
			_flug = Vector2(v.x, v.z)
			steig = v.y
		else:
			# am Boden: eine Leine – weiter als das Seil geht es nicht
			var dy := fuss.y - _haken_p.y
			var waag := sqrt(maxf(0.0, _seil_lang * _seil_lang - dy * dy))
			var dh := Vector2(d.x, d.z)
			if dh.length() > waag:
				var s := (dh.normalized() * waag - dh) * Werte.ZELLE
				_schritt(Vector2(s.x, 0.0))
				_schritt(Vector2(0.0, s.y))
	_seil_zeichnen(_haken_p, _haken)


## Schwung in der Luft weitertragen; bei der Landung ist er weg.
func _flug_weiter(dt: float) -> void:
	if _flug == Vector2.ZERO:
		return
	if hoehe <= _boden() + 0.001 and steig <= 0.0:
		_flug = Vector2.ZERO
		return
	var s := _flug * dt * Werte.ZELLE
	if not _luft_schritt(Vector2(s.x, 0.0)):
		_flug.x = 0.0
	if not _luft_schritt(Vector2(0.0, s.y)):
		_flug.y = 0.0


## Ein Stück gehen oder fliegen. Wer höher als die Mauerkrone ist, landet beim Hinüberfliegen oben auf dem Wall.
func _luft_schritt(s: Vector2) -> bool:
	var vorher := _fuss2d()
	var neu := vorher + s
	if not brakk.oben and hoehe >= hd.H - 0.05 and not _passt_unten(neu):
		var z := karte.zelle_bei(neu)
		if hd.ist_hoch(z) and karte.inhalt(z) == Karte.WALL:
			brakk.oben = true
			brakk.posten_zelle = z
			brakk.zustand = Einheit.Zustand.AUF_POSTEN
			hoehe = maxf(hoehe, hd.H)
			_setze_fuss(neu)
			return true
	_schritt(s)
	return _fuss2d() != vorher


## Seil von der Ringhand zum Haken; der Haken dreht sich. In den ersten 0,12 s fliegt er erst hinaus.
func _seil_zeichnen(ziel: Vector3, t: float) -> void:
	if _anker_seil == null:
		return
	var hand := hd.kamera.global_position + _blick() * 0.35 - _rechts() * 0.22 - Vector3(0, 0.2, 0)
	var haken := hand.lerp(ziel + Vector3(0, 0.05, 0), clampf(t / 0.12, 0.0, 1.0))
	var lang := maxf(0.05, hand.distance_to(haken))
	_anker_seil.scale = Vector3(1.0 + 0.4 * sin(t * 40.0), 1.0, lang)
	_anker_seil.position = (hand + haken) / 2.0
	_anker_seil.look_at_from_position(_anker_seil.position, haken, Vector3.UP if absf((haken - hand).normalized().y) < 0.99 else Vector3.RIGHT)
	_anker_haken.position = haken
	_anker_haken.rotation = Vector3(PI / 2.0, t * 8.0, 0.0)


# ------------------------------------------------------------------ Brakk-Mode: Werte-Fenster (19.11.)

## 19.11. (Paul): Klein und immer sichtbar unten links, als Werteliste wie in anderen Spielen (Name links, Zahl rechts):
## Schaden, Schüsse/s, Schaden/s. Darunter klein in der Ringfarbe, was die Ringe dazugeben. Schmal genug, dass es links
## neben Brakks linker Waffe bleibt.
## Ändert sich ein Wert (Ringwechsel, Aufstieg), blinkt er kurz grün. Am Handy (unten links liegt der Stick) eine
## kurze Zeile über der Lebensleiste.
const WERTE_BLINK_MS := 700
var _werte_alt := {}
var _werte_blink := {}


## Kurzname eines Rings ohne „ring“ (Glutstrahl, Gel, Takt …).
static func ring_kurz(ring: String) -> String:
	return str(BrakkFortschritt.RINGE[ring]["name"]).trim_suffix("ring")


func _prozent(faktor: float) -> String:
	return "%+d %%" % roundi((faktor - 1.0) * 100.0)


## {"zeilen": [[Schlüssel, Name, Zahl, [[Bonus, Farbe], …]], …], "zusatz": [[Text, Farbe], …]}
func _werte_zeilen() -> Dictionary:
	if kit != null:
		return kit.werte_zeilen()   # 20.11.: Werte-Fenster des Anführers
	var f := brakk.fortschritt
	var schuss := SCHUSS_SCHADEN * f.schuss_schaden()
	var her: Array = []
	var takt_her: Array = []
	var zusatz: Array = []
	for r: String in f.ringe:
		var d: Dictionary = BrakkFortschritt.RINGE[r]["brakk_stufen"][clampi(f.ring_stufe(r), 1, 3) - 1]
		var farbe := _ring_farbe(r)
		if d.has("schaden"):
			zusatz.append(["Schaden " + _prozent(float(d["schaden"])), farbe])
		if d.has("takt"):
			zusatz.append(["Tempo " + _prozent(1.0 / float(d["takt"])), farbe])
		if d.has("anlauf"):
			zusatz.append(["Anlauf bis " + _prozent(float(d["anlauf"])), farbe])
		if d.has("weitere"):
			zusatz.append(["Durchschlag %d" % (d["weitere"] as Array).size(), farbe])
		if d.has("mark_bonus"):
			zusatz.append(["Ziel %s" % _prozent(float(d["mark_bonus"])), farbe])
		if d.has("gel_bonus"):
			zusatz.append(["Gebremste " + _prozent(float(d["gel_bonus"])), farbe])
		if d.has("brand_takt"):
			zusatz.append(["Brand je %s s" % str(d["brand_takt"]).replace(".", ","), farbe])
		if d.has("spruenge"):
			zusatz.append(["Sprung %d× %d %%" % [int(d["spruenge"]), roundi(float(d["sprung_anteil"]) * 100.0)], farbe])
		if d.has("schutz"):
			zusatz.append(["Schutz %d %%" % roundi(float(d["schutz"]) * 100.0), farbe])
	var pro_sek := 1.0 / maxf(0.01, SCHUSS_TAKT * _takt_faktor())
	return {"zeilen": [
		["schaden", "Schaden", "%.0f" % schuss, her],
		["takt", "Schüsse/s", ("%.1f" % pro_sek).replace(".", ","), takt_her],
		["dps", "Schaden/s", "%.0f" % (schuss * pro_sek), []],
	], "zusatz": zusatz}


func _werte_fenster(g: Vector2) -> void:
	var f := brakk.fortschritt
	if f == null:
		return
	var werte := _werte_zeilen()
	var zeilen: Array = werte["zeilen"]
	var zusatz: Array = werte["zusatz"]
	var jetzt := Time.get_ticks_msec()
	for z: Array in zeilen:
		var k: String = z[0]
		if _werte_alt.has(k) and _werte_alt[k] != z[2]:
			_werte_blink[k] = jetzt + WERTE_BLINK_MS
		_werte_alt[k] = z[2]
	var gruen := Color("7dffa0")
	if touch != null:
		# Handy: eine Zeile über der Lebensleiste (unten links liegt der Stick)
		var breite := clampf(g.x * 0.26, 260.0, 460.0)
		var bx := (g.x - breite) / 2.0
		var by := roundf(g.y * 0.86) - 34.0
		var text := "Schaden %s · %s/s · %s Schaden/s" % [zeilen[0][2], zeilen[1][2], zeilen[2][2]]
		var tw := Stil.breite(text, 16) + 16.0
		var o2 := Vector2(bx, by - 12.0 - 24.0)
		_bild.draw_rect(Rect2(o2, Vector2(tw, 24.0)), Color(0.04, 0.05, 0.08, 0.62))
		var blinkt := false
		for z: Array in zeilen:
			blinkt = blinkt or int(_werte_blink.get(z[0], 0)) > jetzt
		Stil.schreibe(_bild, o2 + Vector2(8.0, 12.0), text, 16, gruen if blinkt else Stil.TEXT)
		return
	var w := 146.0   # die linke Waffe beginnt bei etwa 160
	var zh := 23.0
	var kh := 16.0
	var n := mini(zusatz.size(), 5)
	var h := 6.0 + zh * zeilen.size() + (5.0 + kh * n if n > 0 else 0.0) + 4.0
	var o := Vector2(10.0, g.y - 10.0 - h)
	_bild.draw_rect(Rect2(o, Vector2(w, h)), Color(0.04, 0.05, 0.08, 0.72))
	_bild.draw_rect(Rect2(o, Vector2(w, h)), Color(1, 1, 1, 0.14), false, 1.0)
	_bild.draw_rect(Rect2(o, Vector2(2.0, h)), Color(Stil.GOLD, 0.8))
	for i in zeilen.size():
		var z: Array = zeilen[i]
		var my := o.y + 6.0 + zh * (i + 0.5)
		if i > 0:
			_bild.draw_rect(Rect2(o.x + 8.0, o.y + 6.0 + zh * i, w - 16.0, 1.0), Color(1, 1, 1, 0.07))
		var x := o.x + 11.0
		x += Stil.schreibe(_bild, Vector2(x, my), str(z[1]), 16, Stil.TEXT_BLASS) + 7.0
		for b: Array in (z[3] as Array):
			x += Stil.schreibe(_bild, Vector2(x, my), str(b[0]), 13, b[1]) + 5.0
		var blink := int(_werte_blink.get(z[0], 0)) > jetzt
		var zahl := str(z[2])
		Stil.schreibe(_bild, Vector2(o.x + w - 9.0 - Stil.breite(zahl, 20), my), zahl, 20, gruen if blink else Stil.GOLD)
	if n > 0:
		var y0 := o.y + 6.0 + zh * zeilen.size() + 3.0
		_bild.draw_rect(Rect2(o.x + 8.0, y0 - 2.0, w - 16.0, 1.0), Color(1, 1, 1, 0.14))
		for i in n:
			var e: Array = zusatz[i]
			var my2 := y0 + 2.0 + kh * (i + 0.5)
			_bild.draw_rect(Rect2(o.x + 11.0, my2 - 3.0, 6.0, 6.0), e[1])
			var t := str(e[0]) if i < 4 or zusatz.size() <= 5 else "+ %d weitere" % (zusatz.size() - 4)
			Stil.schreibe(_bild, Vector2(o.x + 23.0, my2), t, 14, Stil.TEXT)


# ------------------------------------------------------------------ Brakk-Mode: Tumble-Schuss (19.11.)

## 19.11. (Paul): Eigener Mündungs- und Treffereffekt für den verstärkten ersten Schuss nach der Rolle: ein zweiter, goldener
## Strahl, ein großer Funke an der Mündung, Wackeln und ein tiefer Klang; am Ziel ein goldener Ring.
const TUMBLE_FARBE := Color("ffd166")

func _tumble_schuss_bild(muendung: Vector3, ende: Vector3) -> void:
	_strahl(muendung + Vector3(0, 0.015, 0), ende, TUMBLE_FARBE)
	_strahl(muendung - Vector3(0, 0.015, 0), ende, TUMBLE_FARBE.lightened(0.4))
	_funke(muendung, 0.2)
	_trauma = minf(1.0, _trauma + 0.25)
	_kick += 0.05
	_fov_puls = maxf(_fov_puls, 5.0)
	Ton.spiele(spiel, "tc-rail", -6.0)


func _tumble_treffer_bild(g: Gegner) -> void:
	if not is_instance_valid(g):
		return
	spiel.effekte.flaeche(g.position, Werte.ZELLE * 0.7, TUMBLE_FARBE)
	_funke(_zu3d(g.position, 0.45), 0.35)
	_einfrieren(STOP_KILL)


# ------------------------------------------------------------------ Brakk-Mode: Zeitlupe je Ring (19.11.)

## 19.11. (Paul): Die Zeitlupe [V] bekommt je aktivem Ring einen Zusatz, beim Auslösen festgelegt. Die Lichtsäule deckt
## Schaden und Bremsen ab – die Zeitlupe stützt Truppen, macht Brakk beweglich oder kontert Gegner-Tricks.
## Werte in BrakkFortschritt.ZEITLUPE_RING.
var _zl_ring := ""               # Ring, mit dem die laufende (oder letzte) Zeitlupe ausgelöst wurde
var _zl_nach_bis := 0            # Zielring: Bonus noch bis dahin (ms)
var _zl_heil_takt := 0.0


func _zl_wert(ring: String, schluessel: String) -> float:
	return float((BrakkFortschritt.ZEITLUPE_RING.get(ring, {}) as Dictionary).get(schluessel, 0.0))


func _zl_aktiv(ring: String) -> bool:
	return _zeitlupe > 0.0 and _zl_ring == ring


func _truppen_um(p: Vector2, radius_felder: float) -> Array:
	var liste: Array = []
	for e: Variant in spiel.einheiten:
		if is_instance_valid(e) and e is Einheit and not (e is Kommandant) and not (e as Einheit).ist_pilot and (e as Einheit).leben > 0.0 \
				and (e as Einheit).position.distance_to(p) <= radius_felder * Werte.ZELLE:
			liste.append(e)
	return liste


func _zl_beginn() -> void:
	_zl_ring = brakk.fortschritt.aktiv() if brakk.fortschritt != null else ""
	var farbe := _licht_farbe()
	match _zl_ring:
		"abpraller":
			_zl_bereit()
			spiel.melde("Zeitlupe · Sprungring: Anker, Rolle und Treppe ohne Cooldown.", 2.5)
		"brandfeld":
			# Rauch im Umkreis löst sich auf, Gegner darin können eine Weile nicht geheilt werden
			var r := _zl_wert("brandfeld", "radius") * Werte.ZELLE
			var weg := 0
			while spiel.effekte.blase_rauch_weg(_fuss2d(), r) != null and weg < 20:
				weg += 1
			var bis := Time.get_ticks_msec() + int(_zl_wert("brandfeld", "sperre") * 1000.0)
			for g: Gegner in spiel.ego_gegner():
				if is_instance_valid(g) and not g._tot and g.position.distance_to(_fuss2d()) <= r:
					g.heilsperre_bis = bis
			spiel.effekte.welle(_fuss2d(), r, farbe, "funk", 0.9)
			spiel.melde("Zeitlupe · Brandring: Rauch weg, Gegner %s s nicht heilbar." % BrakkFortschritt._zahl(_zl_wert("brandfeld", "sperre")), 2.5)
		"feuerteam":
			spiel.melde("Zeitlupe · Taktring: Fabriken im Feld ersetzen sofort ihre Truppen.", 2.5)
		"laser":
			spiel.melde("Zeitlupe · Glutstrahlring: keine Überhitzung." if touch == null else "Zeitlupe · Glutstrahlring: schnellere Schüsse.", 2.5)
		"durchschuss":
			_klinge_schlag_t = -1.0
			Ton.spiele(spiel, "tc-arc", -2.0)
			spiel.melde("Zeitlupe · Durchschlagring: Ringklinge – Nahkampf!", 2.5)


func _zl_weiter(dt: float) -> void:
	spiel.brakk_mark_selbst = _zl_aktiv("markierung") or Time.get_ticks_msec() < _zl_nach_bis
	# Klinge auf- und abbauen
	_klinge_auf = move_toward(_klinge_auf, 1.0 if _klinge_aktiv() else 0.0, dt * (3.5 if _klinge_aktiv() else 5.0))
	if _klinge_schlag_t >= 0.0:
		_klinge_schlag_t += dt
		if _klinge_schlag_t > KLINGE_SCHLAG_SEK:
			_klinge_schlag_t = -1.0
	if _zeitlupe <= 0.0:
		return
	match _zl_ring:
		"abpraller":
			_zl_bereit()
		"plasmagel":
			_zl_heil_takt += dt
			if _zl_heil_takt >= 0.25:
				var anteil := _zl_wert("plasmagel", "heilung") * _zl_heil_takt
				_zl_heil_takt = 0.0
				for e: Einheit in _truppen_um(_fuss2d(), _zl_wert("plasmagel", "radius")):
					if e.leben < e.max_leben:
						e.leben = minf(e.max_leben, e.leben + e.max_leben * anteil)
						spiel.effekte.plus(e.position + Vector2(0, -18), Color("7dff9a"))
		"feuerteam":
			var f := brakk.fortschritt
			if f != null and f.felder.has("feuerteam"):
				for z: Vector2i in spiel.fabriken:
					if BrakkFortschritt.im_feld(z, f.felder["feuerteam"] as Vector2i):
						spiel.fabriken[z]["timer"] = Werte.PRODUKTION_SEK   # fehlt eine Truppe, kommt sie im nächsten Bild
		"durchschuss":
			if touch != null and _takt <= 0.0 and _frei() and not _klinge_ziele().is_empty():
				_klinge_schlag()   # am Handy schlägt Brakk von selbst zu


func _zl_ende() -> void:
	match _zl_ring:
		"bollwerk":
			var bis := Time.get_ticks_msec() + int(_zl_wert("bollwerk", "sek") * 1000.0)
			var n := 0
			for e: Einheit in _truppen_um(_fuss2d(), _zl_wert("bollwerk", "radius")):
				e.ring_schild = e.max_leben * _zl_wert("bollwerk", "schild")
				e.ring_schild_bis = bis
				spiel.effekte.welle(e.position, Werte.ZELLE * 0.55, _licht_farbe(), "heil", 0.8)
				n += 1
			if n > 0:
				spiel.melde("Wallring: %d Truppen mit Schild." % n, 2.0)
		"minigun":
			_zl_sog()
		"markierung":
			_zl_nach_bis = Time.get_ticks_msec() + int(_zl_wert("markierung", "nach") * 1000.0)


## Sprungring: Anker, Rolle und Treppe (und Brücke) bereit.
func _zl_bereit() -> void:
	_anker_rest = 0.0
	_tumble_rest = 0.0
	brakk.e_rest = 0.0
	_bruecke_cd = 0.0


## Wirbelring am Ende: Gegner um den Punkt unter dem Fadenkreuz zusammenziehen – Schritt für Schritt, nur über begehbare
## Felder (nicht durch Mauern), große Gegner nicht.
func _zl_sog() -> void:
	var p := ziel_welt(true)
	if p.x < -9000.0:
		return
	var r := _zl_wert("minigun", "radius") * Werte.ZELLE
	var zug := _zl_wert("minigun", "zug") * Werte.ZELLE
	for g: Gegner in spiel.ego_gegner():
		if not is_instance_valid(g) or g._tot or BrakkFortschritt.gross(g) or g.position.distance_to(p) > r:
			continue
		if hd.ist_hoch(karte.zelle_bei(g.position)):
			continue   # oben auf einem Wall bleibt er
		var weg := minf(zug, g.position.distance_to(p))
		var richtung := (p - g.position).normalized()
		var bisher := g.position
		var s := 0.0
		while s < weg:
			s = minf(weg, s + 4.0)
			var neu := g.position + richtung * s
			if not karte.ist_begehbar(karte.zelle_bei(neu)):
				break
			bisher = neu
		if bisher != g.position:
			spiel.effekte.strahl(g.position, bisher, _licht_farbe(), 2.0)
			g.position = bisher
			g.plane_neu()
	spiel.effekte.welle(p, r, _licht_farbe(), "funk", 0.8)
	_trauma = minf(1.0, _trauma + 0.3)
	Ton.spiele(spiel, "hit-boom", -6.0)


# ------------------------------------------------------------------ Ringklinge (Zeitlupe mit Durchschlagring)

## 19.11. (Paul): Nahkampf – eine Lichtklinge an der rechten Hand aus denselben sechseckigen Lichtplatten wie Lichttreppe
## und Lichtplattform, in der Farbe des aktiven Rings (wechselt mit). Aufbau (Platten springen nacheinander auf), zwei
## Schlagbilder (links, rechts) mit Leuchtspur. Aus Code gezeichnet; ein PixelLab-Bild kann sie später ersetzen.
const KLINGE_SCHLAG_SEK := 0.22
const KLINGE_PLATTEN := 7
var _klinge_auf := 0.0           # 0 = weggesteckt, 1 = ganz aufgebaut
var _klinge_schlag_t := -1.0     # Sekunden seit dem Schlag (-1 = keiner)
var _klinge_seite := 1           # 1 = von rechts nach links, -1 = umgekehrt


func _klinge_aktiv() -> bool:
	return _zl_aktiv("durchschuss")


## Gegner im Bogen vor Brakk in Reichweite.
func _klinge_ziele() -> Array:
	var liste: Array = []
	var weite := _zl_wert("durchschuss", "weite") * Werte.ZELLE
	var halb := deg_to_rad(_zl_wert("durchschuss", "bogen") / 2.0)
	var vorne := Vector2(_vorne().x, _vorne().z)
	for g: Gegner in spiel.ego_gegner():
		if not is_instance_valid(g) or g._tot or spiel._geschuetzt(g):
			continue
		var d := g.position - _fuss2d()
		if d.length() <= weite and (d.length() < 8.0 or absf(vorne.angle_to(d)) <= halb):
			liste.append(g)
	return liste


func _klinge_schlag() -> void:
	if _takt > 0.0 or _klinge_auf < 0.6:
		return
	_takt = _zl_wert("durchschuss", "takt")
	_klinge_schlag_t = 0.0
	_klinge_seite = -_klinge_seite
	var ziele := _klinge_ziele()
	Ton.spiele(spiel, "tc-arc", -4.0)
	_kick += 0.02
	if ziele.is_empty():
		return
	var schaden := SCHUSS_SCHADEN * _schaden_faktor() * _zl_wert("durchschuss", "mal")
	var summe := 0.0
	var kill := false
	spiel.schadensquelle = "fabrik:-1,-1"
	spiel.brakk_quelle = "klinge"
	spiel.schuss_herkunft = brakk.position
	for g: Gegner in ziele:
		if not is_instance_valid(g) or g._tot:
			continue
		var vorher := g.leben
		g.nimm_schaden(schaden * _gel_bonus(g))
		summe += maxf(0.0, vorher - maxf(g.leben, 0.0))
		if g._tot:
			kill = true
			_kill(g)
	spiel.schadensquelle = ""
	spiel.brakk_quelle = ""
	spiel.schuss_herkunft = Vector2.INF
	brakk.leben = minf(brakk.max_leben, brakk.leben + summe * _zl_wert("durchschuss", "heilung"))   # Schaden heilt Brakk
	_treffer_gefuehl(_zu3d(_fuss2d() + Vector2(_vorne().x, _vorne().z) * Werte.ZELLE, 0.5), kill)


## Sechseck (Lichtplatte) in 2D.
func _sechseck(mitte: Vector2, r: float, winkel: float) -> PackedVector2Array:
	var p := PackedVector2Array()
	for i in 6:
		var w := winkel + TAU * float(i) / 6.0
		p.append(mitte + Vector2(cos(w), sin(w)) * r)
	return p


func _klinge_bild(g: Vector2, wpx: float) -> void:
	if _klinge_auf <= 0.01:
		return
	var farbe := _licht_farbe()
	var hand := Vector2(g.x * 0.8, g.y * 1.02)
	# Grundwinkel: die Klinge zeigt schräg nach oben links zum Fadenkreuz; beim Schlag schwingt sie durch
	var w0 := -PI * 0.64
	var schwung := 0.0
	if _klinge_schlag_t >= 0.0:
		var x := clampf(_klinge_schlag_t / KLINGE_SCHLAG_SEK, 0.0, 1.0)
		schwung = (1.0 - pow(1.0 - x, 3.0)) * 1.3 - 0.65   # schnell, dann aus
		schwung *= float(_klinge_seite)
	var winkel := w0 + schwung
	var laenge := g.y * 0.6
	# Leuchtspur beim Schlag: blasse Platten auf den vorigen Winkeln
	if _klinge_schlag_t >= 0.0:
		for s in 5:
			var ws := winkel - float(_klinge_seite) * 0.12 * float(s + 1)
			var a := 0.22 * (1.0 - float(s) / 5.0) * (1.0 - _klinge_schlag_t / KLINGE_SCHLAG_SEK)
			for i in KLINGE_PLATTEN:
				var t := float(i + 1) / float(KLINGE_PLATTEN)
				var m := hand + Vector2(cos(ws), sin(ws)) * laenge * t
				_bild.draw_colored_polygon(_sechseck(m, wpx * (10.0 - 5.0 * t), ws), Color(farbe, a))
	# Platten vom Griff zur Spitze, beim Aufbau springen sie nacheinander mit Überschwung auf
	for i in KLINGE_PLATTEN:
		var t := float(i + 1) / float(KLINGE_PLATTEN)
		var auf := clampf(_klinge_auf * float(KLINGE_PLATTEN) - float(i), 0.0, 1.0)
		if auf <= 0.0:
			continue
		var pop := 1.0 + 2.70158 * pow(auf - 1.0, 3) + 1.70158 * pow(auf - 1.0, 2)   # Ease-out-back
		var m := hand + Vector2(cos(winkel), sin(winkel)) * laenge * t
		var r := wpx * (11.0 - 6.0 * t) * pop
		_bild.draw_colored_polygon(_sechseck(m, r * 1.35, winkel), Color(farbe, 0.25))
		_bild.draw_colored_polygon(_sechseck(m, r, winkel), Color(farbe, 0.85))
		_bild.draw_polyline(_sechseck(m, r, winkel) + PackedVector2Array([_sechseck(m, r, winkel)[0]]), farbe.lightened(0.6), maxf(1.0, wpx * 0.5))
	# Griff: ein Ring um die Hand
	_bild.draw_arc(hand, wpx * 7.0, 0.0, TAU, 24, Color(farbe.lightened(0.4), 0.9 * _klinge_auf), wpx * 1.5)


func _zaehle(was: String) -> void:
	if brakk.fortschritt != null:
		brakk.fortschritt.zaehler[was] = int(brakk.fortschritt.zaehler.get(was, 0)) + 1


# ------------------------------------------------------------------ Brakk-Mode: Sieg (19.11.)

## 19.11. (Paul): Fällt das gegnerische HQ: kurz Zeitlupe, dann fährt die Kamera aus Brakks Augen nach oben über die
## Verteidigung (Umkehrung des Einflugs), darüber „SIEG“, danach die Übersicht (BrakkSieg).
const SIEG_LUPE := 1.2           # Sekunden Zeitlupe nach dem Fall
const SIEG_FLUG := 3.0           # Sekunden Kameraflug
var _sieg_t := -1.0
var _sieg_tafel: BrakkSieg = null
var _sieg_bericht := {}


## 20.11. (Paul): Classic gewonnen → „Weiterspielen …?“ – zurück aus Kameraflug und Übersicht in die Ego-Sicht (Befehl 24).
func sieg_aufheben() -> void:
	_sieg_t = -1.0
	if _sieg_tafel != null:
		_sieg_tafel.queue_free()
		_sieg_tafel = null
	_sieg_bericht = {}
	_uhr_vorher = 0
	_trauma = 0.0


func sieg(sekunden: float) -> void:
	if _sieg_t >= 0.0:
		return
	_sieg_t = 0.0
	_feuer = false
	if _zeitlupe > 0.0:
		_zeitlupe_aus()
	if brakk.fortschritt != null:
		_sieg_bericht = brakk.fortschritt.sieg_bericht(spiel, sekunden)
		Profil.brakk_sieg(_sieg_bericht)
	Engine.time_scale = 0.15
	_trauma = 0.6
	Ton.spiele(spiel, "alert", 0.0)


func _sieg_weiter() -> void:
	var uhr := Time.get_ticks_usec()
	var echt := clampf((uhr - _uhr_vorher) / 1000000.0, 0.0, 0.1) if _uhr_vorher > 0 else 0.016
	_uhr_vorher = uhr
	_sieg_t += echt
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if _sieg_t >= SIEG_LUPE and Engine.time_scale < 0.5:
		Engine.time_scale = Werte.SPIELTEMPO   # nach der kurzen Zeitlupe wieder normal
	_trauma = maxf(0.0, _trauma - TRAUMA_ABBAU * echt)
	_wackel_t += echt * 30.0
	_kamera()
	# Umkehrung des Einflugs: aus den Augen nach oben hinten, Blick hinunter auf die Verteidigung
	var t := clampf((_sieg_t - SIEG_LUPE * 0.5) / SIEG_FLUG, 0.0, 1.0)
	var e := t * t * (3.0 - 2.0 * t)
	var k := hd.kamera
	k.position += Vector3(0, 12.0 * e, 0) - _vorne() * 9.0 * e
	k.rotation.x = lerpf(k.rotation.x, -1.05, e)
	_bild.queue_redraw()
	_karte_klein.queue_redraw()
	if _sieg_t >= SIEG_LUPE * 0.5 + SIEG_FLUG + 0.4 and _sieg_tafel == null:
		_sieg_tafel = BrakkSieg.new()
		_sieg_tafel.spiel = spiel
		_sieg_tafel.bericht = _sieg_bericht
		_ebene.add_child(_sieg_tafel)


func _sieg_bild(g: Vector2) -> void:
	if _sieg_tafel != null:
		return
	var x := clampf((_sieg_t - SIEG_LUPE * 0.5) / 0.5, 0.0, 1.0)
	if x <= 0.0:
		return
	var pop := 1.0 + 2.70158 * pow(x - 1.0, 3) + 1.70158 * pow(x - 1.0, 2)   # Ease-out-back
	var m := Vector2(g.x / 2.0, g.y * 0.32)
	Stil.ebene = Transform2D(0.0, Vector2.ONE * pop, 0.0, m)   # Texte wandern mit der Skalierung mit
	_bild.draw_set_transform_matrix(Stil.ebene)
	Stil.schreibe_mittig(_bild, Vector2(3, 4), "SIEG", 96, Color(0, 0, 0, 0.6))
	Stil.schreibe_mittig(_bild, Vector2.ZERO, "SIEG", 96, Stil.GOLD)
	Stil.ebene = Transform2D.IDENTITY
	_bild.draw_set_transform_matrix(Transform2D.IDENTITY)
	Stil.schreibe_mittig(_bild, m + Vector2(0, 78), str(_sieg_bericht.get("unterzeile", "Das HQ der Myriaden ist gefallen.")), 24, Color(Stil.TEXT, x))   # 20.11.: Befehl 24 mit eigener Zeile


# ------------------------------------------------------------------ Brakk-Mode: Respawn (19.11.)

## 19.11. (Paul): Fällt Brakk, läuft ein kleiner Respawn-Timer (BrakkFortschritt.RESPAWN_SEK, Echtzeit), danach steht er an
## der Basis wieder auf – voll geheilt, mit einer Lichtplattform unter den Füßen. Endet die Welle vorher, steht er wie
## bisher zur nächsten Runde auf.
var _respawn := 0.0


func _wieder_da() -> void:
	var z: Vector2i = spiel._feld_vor_basis()
	if z == Karte.KEINE:
		z = brakk.aufstellung
	brakk.aufstehen(z)
	_liegt = false
	hoehe = 0.0
	steig = 0.0
	nick = 0.0
	_doppelt_genutzt = false
	_lichtplattform()
	_trauma = minf(1.0, _trauma + 0.3)
	Ton.spiele(spiel, "alert", -4.0)
	spiel.melde("%s ist zurück – an der Basis." % Anfuehrer.name(anfuehrer()), 2.5)
	if kit != null:
		kit.wieder_da()   # 20.11.


## Großer Hinweis mit Countdown, solange Brakk liegt.
func _respawn_bild(g: Vector2) -> void:
	if not _liegt:
		return
	var m := Vector2(g.x / 2.0, g.y * 0.42)
	var text := "Gefallen – zurück an der Basis in %d s" % ceili(maxf(_respawn, 0.0)) if spiel.phase == 1 else "Gefallen – zur nächsten Runde wieder da"
	_bild.draw_rect(Rect2(m.x - 260.0, m.y - 30.0, 520.0, 64.0), Color(0.04, 0.05, 0.08, 0.7))
	Stil.schreibe_mittig(_bild, m - Vector2(0, 8), text, 24, Stil.ROT)
	var anteil := clampf(1.0 - _respawn / BrakkFortschritt.RESPAWN_SEK, 0.0, 1.0)
	_bild.draw_rect(Rect2(m.x - 220.0, m.y + 16.0, 440.0, 6.0), Color(1, 1, 1, 0.12))
	_bild.draw_rect(Rect2(m.x - 220.0, m.y + 16.0, 440.0 * anteil, 6.0), LICHT)
