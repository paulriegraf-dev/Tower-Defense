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
var _kills_seit_gefuehl := 0     # 22.11.: Kills seit dem letzten Treffergefühl (Mehrfach-Kill?)
var _kill_gross := false         # … und ob ein großer Gegner dabei war
var _letzter_stop_ms := -100000
var _trauma := 0.0
var _wackel_t := 0.0
var _kick := 0.0                # Rückstoß der Sicht nach oben (Bogenmaß), federt zurück
var _fov_puls := 0.0            # Grad, die das Sichtfeld kurz enger wird
var _kreuz := 0.0               # Trefferkreuz: Restzeit
var _kreuz_kill := false
var _stop_id := 0
var _stop_vorher := -1.0        # Spieltempo vor dem Einfrieren (-1 = gerade kein Einfrieren)
var _lupe_bis_ms := 0           # 25.11.: so lange läuft die Beförderungs-Zeitlupe
var _lupe_zoom_bis_ms := 0      # … und so lange steht ihr Zoom
var _uhr_vorher := 0             # Zeitpunkt des letzten Bilds (µs) für die Echtzeit
var _fang_soll := false          # 21.11.: Web – Mausfang ist angefordert (nur beim Übergang, nie jedes Bild neu)
var _fang_warte := 0.0           # 21.11.: Web – so lange (Echtzeit) fehlt der angeforderte Mausfang schon
const FANG_FRIST := 0.4          # 21.11.: Web – fehlt er länger, wartet die Tafel „Klicken zum Fortsetzen“

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
var ringwerk: BrakkRinge   # 27.11. (Knoten-Umbau 7b): Ringe, Lichtterminal, Ringfelder, Zeitlupe je Ring, Ringklinge (scripts/brakk_ringe.gd)
var lichtwerk: BrakkLicht   # 27.11. (Knoten-Umbau 7c): Lichttreppe, Lichtbrücke, Lichtanker, Schwingen, Doppelsprung, Absprung (scripts/brakk_licht.gd)
var anzeige: BrakkAnzeige   # 27.11. (Knoten-Umbau 7d): Oberfläche, Fähigkeiten-Leiste, Einsatz-Tafel und Einflug, Werte-Fenster (scripts/brakk_anzeige.gd)
var saeule: BrakkSaeule   # 27.11. (Knoten-Umbau 7a): Lichtsäule [X] und Zeitlupe [V] (scripts/brakk_saeule.gd)
var touch: EgoTouch = null
var kit: EgoKit = null              # 20.11.: Schritt 6b – Kit eines anderen Anführers (Irrtürmer, Sonde 7); Brakk: null
var _auto_ziel: Gegner = null
var _auto_r := Vector3.ZERO
const AUTO_RADIUS := 0.45        # so nah (Felder) muss die Blicklinie an der Gegnermitte vorbeigehen – etwas großzügiger als ein Schuss (0,34)
const LANZE_TOUCH := 1.5         # am Handy ohne Hitze: feste Verstärkung des Ladestrahls


func _init() -> void:
	ringwerk = BrakkRinge.new(self)
	lichtwerk = BrakkLicht.new(self)
	anzeige = BrakkAnzeige.new(self)
	saeule = BrakkSaeule.new(self)   # 27.11.: vor allem anderen da, auch für Tests ohne starten()


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
	anzeige._baue_oberflaeche()
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
		anzeige._briefing_zeigen()   # 18.11. (Paul): erst die Einsatz-Tafel, nicht abrupt hinein
	if Touch.ohne_maus():
		touch = EgoTouch.new(self)   # 18.11.: Handy – Stick, Wischen, Knöpfe
		add_child(touch)
		spiel.melde("Brakk-Modus: links laufen · rechts wischen zum Zielen · Fadenkreuz auf dem Gegner: Brakk schießt · Fähigkeit tippen oder halten und ziehen", 10.0)
		return
	if kit != null:
		spiel.melde("Brakk-Modus mit %s: WASD + Maus · [F] ausbauen, [Entf] abbauen, [Z] zurück, an der Basis Ringe · [I] Übersicht → Brakk-Modus · Enter: Welle" % Anfuehrer.name(brakk.fortschritt.anfuehrer), 10.0)
		return
	spiel.melde("Brakk-Modus: WASD + Maus · Klick schießt · Leertaste springt · [E] Lichttreppe · [F] ausbauen, an der Basis Ringe · Enter: Welle" + ("" if spiel.brakk_modus else " · [G] zurück"), 10.0)


func beenden() -> void:
	if kit != null:
		kit.beenden()   # 20.11.
	if saeule._zeitlupe > 0.0:
		saeule._zeitlupe_aus()   # 18.11.: das Spieltempo nicht in der Zeitlupe hängen lassen
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
	if lichtwerk._bruecke != null:
		lichtwerk._bruecke.queue_free()
	for s: Array in saeule._saeulen:
		(s[0] as Node).queue_free()
	for k: Node in [saeule._saeule_marke]:
		if k != null:
			k.queue_free()
	if lichtwerk._anker_seil != null:
		lichtwerk._anker_seil.queue_free()
		lichtwerk._anker_haken.queue_free()
	_berge_zurueck()
	for k: Node3D in _feld_knoten.values():
		k.queue_free()
	if _vorschau != null:
		_vorschau.queue_free()
	for m: Node in ringwerk._feld_marken:
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
	if spiel._hud != null and (spiel._hud.pausiert() or spiel._hud.wiedereinstieg_offen()):   # 21.11.: Tafel im Web
		return false
	if spiel._fabrikmenue != null and spiel._fabrikmenue.visible:
		return false
	if spiel._lexikon != null and spiel._lexikon.visible:
		return false
	if anzeige._briefing_offen():
		return false
	if _terminal != null and _terminal.visible:
		return false
	if spiel.order24 != null and spiel.order24.sperrt_steuerung():
		return false   # 20.11.: Befehl 24 – Verrat-Sequenz läuft
	if spiel.tutorial is BrakkTutorial and (spiel.tutorial as BrakkTutorial).braucht_maus():
		return false   # 22.11.: Brakk-Tutorial – die Frage braucht die Maus
	return not Input.is_key_pressed(KEY_ALT)


func _input(event: InputEvent) -> void:
	if anzeige._briefing_offen():
		if event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
			anzeige._briefing_los()
			get_viewport().set_input_as_handled()
		return
	if _terminal != null and _terminal.visible:
		# 21.11.: im Web nur mit [F] (dieselbe Taste wie zum Öffnen) – Esc zählt im Browser nicht als Nutzergeste,
		# danach ließe sich die Maus nicht wieder fangen
		var zu_tasten := [KEY_F] if OS.has_feature("web") else [KEY_ESCAPE, KEY_F]
		if event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).keycode in zu_tasten:
			_terminal.visible = false   # 18.11.: Lichtterminal schließen
			get_viewport().set_input_as_handled()
		elif OS.has_feature("web") and event is InputEventKey and event.pressed and (event as InputEventKey).keycode in [KEY_ESCAPE, KEY_P]:
			spiel.melde("Lichtterminal schließen mit [F].", 2.5)   # 21.11.: das Pausenmenü läge unter dem Terminal
			get_viewport().set_input_as_handled()
		return
	if not _frei():
		return
	if touch != null and (event is InputEventMouseMotion or event is InputEventMouseButton):
		return   # 18.11.: am Handy steuert ego_touch.gd – die nachgemachte Maus der Finger zählt hier nicht
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var m := event as InputEventMouseMotion
		if saeule._saeule_dreht:
			# 22.11.: Durchschlagring – bei gehaltenem Linksklick dreht die Maus die Linie, der Blick bleibt stehen
			saeule._saeule_dir = saeule._saeule_dir.rotated(m.relative.x * BLICK * 2.0)
			saeule._saeule_pix += absf(m.relative.x) + absf(m.relative.y)
			return
		gier -= m.relative.x * BLICK
		nick = clampf(nick - m.relative.y * BLICK, -1.25, 1.25)
		_sway = (_sway - m.relative * SWAY_STAERKE).limit_length(SWAY_MAX)   # 19.11.: Waffen hängen nach
		return
	if event is InputEventMouseButton:
		var b := event as InputEventMouseButton
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			return
		if ringwerk._feld_zielt and b.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
			if b.pressed:
				if b.button_index == MOUSE_BUTTON_LEFT:
					ringwerk._feld_bestaetigen()   # 19.11.: Ringfeld setzen
				else:
					ringwerk._feld_abbrechen()
			get_viewport().set_input_as_handled()
			return
		if b.button_index == MOUSE_BUTTON_LEFT:
			if saeule._saeule_zielt:
				if saeule._saeule_ring == "durchschuss":
					if b.pressed:
						saeule._saeule_dreh_start()   # 22.11.: Marke festhalten, Maus dreht die Linie
					else:
						saeule._saeule_dreh_ende()
				elif b.pressed:
					saeule._saeule_bestaetigen()   # 18.11.: Lichtsäule setzen
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
			ringwerk._rad(-1 if b.button_index == MOUSE_BUTTON_WHEEL_UP else 1, b.factor if b.factor > 0.0 else 1.0)   # 18.11.
			get_viewport().set_input_as_handled()
		elif b.button_index == MOUSE_BUTTON_RIGHT:
			if saeule._saeule_zielt:
				if b.pressed:
					saeule._saeule_abbrechen()
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
		if event.pressed and ringwerk._feld_zielt and kc == KEY_ESCAPE:
			ringwerk._feld_abbrechen()   # 19.11.: Ringfeld nicht setzen
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
			KEY_Z:
				if spiel.brakk_modus and spiel.order24 == null:
					spiel.nimm_bau_zurueck()   # 22.11. (Paul): letztes Bauwerk der Bauphase zurücknehmen
					get_viewport().set_input_as_handled()
			KEY_DELETE:
				if spiel.brakk_modus and spiel.order24 == null and gebaeude_im_blick() != Karte.KEINE:
					var grund: String = spiel.brakk_abbau_grund()
					if grund != "":
						spiel.melde(grund, 2.0)   # in der Welle gesperrt
					get_viewport().set_input_as_handled()
			KEY_F:
				# 18.11. (Paul): Gebäude im Blick ausbauen – öffnet dasselbe Menü wie ein Klick in der Übersicht
				var z := gebaeude_im_blick()
				if z != Karte.KEINE and spiel.werkzeug == Karte.FREI and spiel.order24 == null:   # 20.11.: in Befehl 24 gehören die Bauten dem Feind
					spiel._oeffne_fabrikmenue(z)
					get_viewport().set_input_as_handled()
				elif (z == Karte.KEINE or spiel.order24 != null) and ringwerk._am_terminal():
					ringwerk._terminal_auf()   # 18.11.: Lichtterminal an der Basis
					get_viewport().set_input_as_handled()


## 22.11. (Paul): Brakk-Mode – [Entf] auf das Gebäude im Blick halten (ABBAU_HALTEN s, Fortschrittsring), Loslassen bricht ab.
const ABBAU_HALTEN := 0.6
var _abbau_t := 0.0
var _abbau_z := Karte.KEINE
var _abbau_fertig := false   # nach dem Abbau erst loslassen


func _abbau_weiter(dt: float) -> void:
	var z := Karte.KEINE
	if spiel.brakk_modus and spiel.order24 == null and Input.is_key_pressed(KEY_DELETE) and not saeule._saeule_zielt and not ringwerk._feld_zielt:
		z = gebaeude_im_blick()
	elif not Input.is_key_pressed(KEY_DELETE):
		_abbau_fertig = false
	if z == Karte.KEINE or z != _abbau_z or _abbau_fertig or spiel.brakk_abbau_grund() != "":
		_abbau_t = 0.0
	_abbau_z = z
	if z == Karte.KEINE or _abbau_fertig or spiel.brakk_abbau_grund() != "":
		return
	_abbau_t += dt
	if _abbau_t >= ABBAU_HALTEN:
		_abbau_t = 0.0
		_abbau_fertig = true
		spiel.brakk_abbauen(z)


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
	if spiel.order24 != null and spiel.fabriken.has(z) and not karte.paar.has(z):
		return false   # 22.11.: Befehl 24 – die Fabriken gehören dem Feind (Brakk-Mode: sonst öffnet [F] das Menü mit „Abbauen“)
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
			saeule._saeule_x()   # 18.11.: Lichtsäule zielen / abbrechen
		"zeitlupe":
			if not spiel.brakk_modus:
				return false
			saeule._zeitlupe_start()   # 18.11.: Zeitlupe
		"feld":
			ringwerk._wirf_feld()   # 18.11.: Ringfeld werfen
		"tumble":
			_tumble_start()   # 18.11.
		"ulti":
			if brakk.fortschritt == null:
				return false
			anzeige._ulti()   # 18.11.: im Brakk-Mode die Ulti
		"anker":
			if not spiel.brakk_modus:
				return false
			lichtwerk._anker_start()   # 18.11. (Paul): Lichtanker statt Sammeln – Brakk spielt allein
		"sprung":
			_leertaste()
		"treppe":
			# 18.11. (Paul): [E] wirft die Lichttreppe – hinauf auf den Wall vor Brakk bzw. hinunter (statt 2× Leertaste)
			if _klettern < 0.0:
				if brakk.oben:
					if not lichtwerk._versuche_bruecke():   # 18.11.: Blick auf einen anderen Wall – Lichtbrücke
						lichtwerk._versuche_absteigen(true)
				else:
					lichtwerk._versuche_klettern(true)
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
		if spiel.order24 != null:
			spiel.order24.brakk_bewegung("sprung")   # 26.11.: der Herausforderer schaut es sich ab
		if lichtwerk._haken >= 0.0:
			_flug = _lauf * SCHWING_MAL   # 19.11. (Paul): am Lichtanker schwingen
	elif not _doppelt_genutzt and (brakk.fortschritt == null or brakk.fortschritt.frei("doppelsprung")):   # 19.11. (Paul): ab Stufe 2
		lichtwerk._doppelsprung()   # 19.11. (Paul): in der Luft – Lichtplattform unter den Füßen


# ------------------------------------------------------------------ Ablauf

## 21.11.: Mausfang im Web. Der Browser erlaubt Pointer Lock nur direkt nach einer Nutzergeste (Klick, Taste – nicht Esc)
## und nimmt ihn bei Esc selbst weg. Deshalb nur beim Übergang „frei“ anfordern (Folge einer Eingabe), nie jedes Bild neu.
## Kommt er nicht oder geht er verloren, hält das Spiel an und die Tafel „Klicken zum Fortsetzen“ wartet (hud.gd).
func _mausfang_web(frei: bool, echt: float) -> void:
	if not frei:
		_fang_soll = false
		_fang_warte = 0.0
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		return
	if not _fang_soll:
		fange_maus()
		return
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_fang_warte = 0.0
		return
	_fang_warte += echt
	if _fang_warte >= FANG_FRIST:
		_fang_warte = 0.0
		spiel._hud.wiedereinstieg_zeigen()


## 21.11.: Maus fangen – nur aus einer Nutzergeste heraus (Übergang nach Taste/Klick, Klick auf die Tafel).
func fange_maus() -> void:
	_fang_soll = true
	_fang_warte = 0.0
	if touch == null:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _process(delta: float) -> void:
	if get_tree().paused:
		# 18.11. (Paul): Pause-Menü – die Maus muss frei sein, das Fadenkreuz weg (_frei() ist in der Pause falsch).
		# Die Ego-Sicht läuft dafür auch in der Pause weiter (process_mode ALWAYS in starten()).
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_fang_soll = false   # 21.11.: nach der Pause neu anfordern (Klick auf „Weiter“ oder die Tafel)
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
			if lichtwerk._haken >= 0.0:
				lichtwerk._haken_los()
			if saeule._zeitlupe > 0.0:
				saeule._zeitlupe_aus()
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
	if OS.has_feature("web") and touch == null:
		_mausfang_web(frei, echt)   # 21.11.
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if frei and touch == null else Input.MOUSE_MODE_VISIBLE
	if touch != null:
		_auto_zielen()   # 18.11.: Handy – Brakk schießt selbst
		_feuer = frei and _auto_ziel != null and spiel.werkzeug == Karte.FREI and not saeule._saeule_zielt
	_takt -= echt
	# 18.11.: Schussgefühl abklingen lassen (Echtzeit)
	_trauma = maxf(0.0, _trauma - TRAUMA_ABBAU * echt)
	_wackel_t += echt * 30.0
	_kick = lerpf(_kick, 0.0, 1.0 - exp(-12.0 * echt))
	_fov_puls = move_toward(_fov_puls, 0.0, echt * 30.0)
	if Time.get_ticks_msec() < _lupe_zoom_bis_ms:
		_fov_puls = maxf(_fov_puls, Werte.NEMESIS_LUPE_ZOOM)   # 25.11.: Beförderung – der Zoom steht, solange die Zeitlupe läuft
	_kreuz = maxf(0.0, _kreuz - echt)
	anzeige._einflug_weiter(echt)   # 18.11.
	if anzeige._briefing != null and anzeige._briefing.visible:
		anzeige._briefing.queue_redraw()
	_fliessende_runden(echt)   # 18.11.; 19.11.: in Echtzeit (das Spiel läuft fest auf ×2)
	_kuehlen(echt)
	_treppe_rest -= echt
	if brakk.fortschritt != null:
		brakk.fortschritt.weiter(echt)
		if spiel.phase == 1:
			brakk.fortschritt.zaehle_zeit("kampf_sek", echt)   # 19.11.: Sieg-Übersicht
			if brakk.oben:
				brakk.fortschritt.zaehle_zeit("wall_sek", echt)
			if brakk.fortschritt.aktiv() != "":
				brakk.fortschritt.zaehle_zeit("aktiv_" + brakk.fortschritt.aktiv(), echt)   # 26.11.: welcher Ring wie lange aktiv war
			brakk.fortschritt.protokoll.tick(spiel, brakk, brakk.fortschritt)   # 23.11.: Run-Protokoll
	for i in 2:
		_rueckstoss[i] = maxf(0.0, float(_rueckstoss[i]) - echt * 6.0)
		_blitz[i] = maxf(0.0, float(_blitz[i]) - echt)
	# Ring vor, wenn gebaut wird oder die Treppe läuft
	_hand_zeigen -= echt
	_ring_blitz = maxf(0.0, _ring_blitz - echt)
	var ring_soll := 1.0 if (spiel.werkzeug != Karte.FREI or _klettern >= 0.0 or _hand_zeigen > 0.0 or lichtwerk._treppe_aufbau >= 0.0) else 0.0
	_ring = move_toward(_ring, ring_soll, echt * 6.0)
	_tumble_rest -= echt
	_schwung = maxf(0.0, _schwung - echt)
	_sway = _sway.lerp(Vector2.ZERO, 1.0 - exp(-9.0 * echt))
	_delle = move_toward(_delle, 0.0, echt * 4.0)
	lichtwerk._plattformen_weiter(echt)
	_lanze_rest -= echt
	lichtwerk._anker_rest -= echt
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
		lichtwerk._kletter_weiter(echt)
	elif lichtwerk._anker >= 0.0:
		lichtwerk._anker_weiter(echt)   # 18.11.
	elif lichtwerk._absprung >= 0.0:
		lichtwerk._absprung_weiter(echt)   # 19.11.
	elif _tumble >= 0.0:
		_tumble_weiter(echt)
	else:
		_gehen(echt if frei else 0.0)
		if kit == null or not kit.vor_fallen(echt):   # 20.11.: z. B. Schweben (Sonde 7)
			_fallen(echt)
		lichtwerk._flug_weiter(echt)   # 19.11.: Schwung aus Seil und Absprung
	if lichtwerk._haken >= 0.0 and lichtwerk._anker < 0.0 and _klettern < 0.0:
		lichtwerk._haken_weiter(echt)   # 19.11.: Lichtanker hängt
	if _feuer and frei and _takt <= 0.0 and _klettern < 0.0 and _lanze < 0.0 and not saeule._saeule_zielt and not ringwerk._feld_zielt:
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
	lichtwerk._treppe_weiter()
	_bau_strahl_weiter()
	ringwerk._felder_weiter(echt)   # 18.11.: Ringfelder in 3D
	lichtwerk._bruecke_weiter(echt)
	_treffer_merken(echt)   # 18.11.
	saeule._saeule_weiter(echt)
	_abbau_weiter(echt)
	saeule._zeitlupe_weiter(echt)
	SichererRand.einpassen(_karte_klein)   # 19.11.: Minikarte nicht unter der Notch
	_bild.queue_redraw()
	_karte_klein.queue_redraw()


func _gehen(dt: float) -> void:
	if spiel.order24 != null and spiel.order24.herausforderer != null and spiel.order24.herausforderer.gebunden_rest > 0.0:
		_geht = false   # C2 (26.11.): vom Anker des Technogunners herangezogen – kurz bewegungsunfähig
		brakk._sprite.bewegt(false)
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
	if spiel.order24 != null:
		v *= spiel.order24.brakk_tempo_faktor()   # 22.11. (Nemesis Teil 3): im Kegel eines Unterdrückungsfeuers langsamer
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
	if spiel.order24 != null and spiel.order24.lichtwand_schnitt(_fuss2d(), neu) != Vector2.INF:
		return   # C1 (26.11.): die Lichtwand des Kampfplatzes ist nicht durchschreitbar
	if brakk.oben:
		var z := karte.zelle_bei(neu)
		if hd.ist_hoch(z):
			_setze_fuss(neu)
			brakk.posten_zelle = z
			return
		if lichtwerk._auf_bruecke(z):
			_setze_fuss(neu)   # 18.11.: auf der Lichtbrücke (der Posten bleibt das letzte Wallstück)
			return
		# 22.11. (Paul): Zu Fuß hält die Wallkante – herunter nur mit [E], [Q] oder einem Sprung (Leertaste). Sonde 7
		# (Schweben) ist ausgenommen.
		if hoehe <= _boden() + 0.001 and steig <= 0.0 and not kit is EgoSonde:
			return
		# über die Kante: runter, wenn dort Platz ist. 21.11.: Die Mitte ist gerade erst über der Kante, die hintere
		# Körperhälfte noch über der Mauer – dann um die halbe Körperbreite weiter nach vorn (sonst kommt man nicht herunter)
		if not _passt_unten(neu):
			var vorn := neu + s.normalized() * KOERPER * Werte.ZELLE * 1.05
			if not hd.ist_hoch(karte.zelle_bei(vorn)) and _passt_unten(vorn):
				neu = vorn
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
	k.fov = SICHTWINKEL - _fov_puls + lichtwerk._fov_weit
	anzeige._einflug_kamera(k)   # 18.11.: Einflug nach der Einsatz-Tafel
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
## `ohne`: dieses Feld hält nicht auf (die Fabrik, auf die gerade geprüft wird).
func _strahl_bis(von: Vector3, r: Vector3, weite: float, ohne: Vector2i = Karte.KEINE) -> float:
	var eigene := karte.zelle_bei(_fuss2d()) if brakk.oben else Karte.KEINE
	if spiel.order24 != null:   # C1 (26.11.): die Lichtwand des Kampfplatzes fängt Schüsse, Fadenkreuz, Treppe und Anker
		var wand: Vector2 = spiel.order24.lichtwand_schnitt(_zu2d(von), _zu2d(von + r * weite))
		var flach := Vector2(r.x, r.z).length()
		if wand != Vector2.INF and flach > 0.001:
			weite = minf(weite, wand.distance_to(_zu2d(von)) / Werte.ZELLE / flach)
	var t := 0.0
	while t < weite:
		var p := von + r * t
		if p.y <= 0.0:
			return t
		if not spiel.endkampf and spiel.order24 == null and p.x < float(Werte.ZONE_SPALTEN):   # 20.11. (Paul): in Befehl 24 kein Schild am Myriaden-HQ
			return t   # 18.11. (Paul): der Schild vor der Gegnerzone fängt den Schuss ab
		var z := Vector2i(floori(p.x), floori(p.z))
		if z != eigene and z != ohne:
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
		if _ist_fabrik_ziel(g):
			var tf := _fabrik_weite((g as Order24.TechnoZiel).zelle, von, blick, SCHUSS_WEITE)   # 25.11.: ganze Fläche
			if tf > 0.0 and tf < bester:
				bester = tf
				_auto_ziel = g
				_auto_r = blick
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


## 25.11. (Paul): Wo trifft der Strahl dieses Ziel? Abstand entlang des Strahls, -1 = vorbei. Figuren: Kugel um die
## Zielmitte, vor `bis` (erste Mauer). Befehl-24-Fabriken: ihre ganze sichtbare Fläche (vorher hielt ihr eigenes Feld
## den Strahl vor dem Trefferpunkt auf, man traf sie fast nie).
func _treffer_weite(g: Gegner, von: Vector3, r: Vector3, bis: float, weite: float, radius: float) -> float:
	if _ist_fabrik_ziel(g):
		return _fabrik_weite((g as Order24.TechnoZiel).zelle, von, r, weite)
	var c := _ziel_mitte(g)
	var t := (c - von).dot(r)
	if t <= 0.0 or t >= bis or (von + r * t).distance_to(c) > _ziel_radius(g, radius):
		return -1.0
	return t


func _ist_fabrik_ziel(g: Gegner) -> bool:
	return g is Order24.TechnoZiel and (g as Order24.TechnoZiel).art == "fabrik"


## Das Fabrikbild steht aufrecht und dreht sich mit der Kamera (BILLBOARD_FIXED_Y): Der Strahl muss diese Fläche treffen,
## davor darf keine andere Mauer oder Fabrik liegen.
func _fabrik_weite(z: Vector2i, von: Vector3, r: Vector3, weite: float) -> float:
	var vorn := -hd.kamera.global_transform.basis.z
	vorn.y = 0.0
	vorn = vorn.normalized()
	var nenner := r.dot(vorn)
	if nenner <= 0.01:
		return -1.0
	var fuss := _zu3d(karte.mitte(z) + Vector2(0, 4), 0.0)   # wie in hd_ansicht._bauten_bilder
	var t := (fuss - von).dot(vorn) / nenner
	if t <= 0.0 or t >= weite:
		return -1.0
	var q := von + r * t - fuss
	if not fabrik_flaeche(z).has_point(Vector2(q.dot(vorn.cross(Vector3.UP)), q.y)):
		return -1.0
	return t if _strahl_bis(von, r, t, z) >= t else -1.0


var _flaeche_je_bild := {}   # Bildpfad der Fabrik -> sichtbare Fläche in Feldern

## Sichtbare Fläche des Fabrikbilds in Feldern: x seitlich von der Mitte, y vom Boden (Sockel) bis zur Oberkante.
func fabrik_flaeche(z: Vector2i) -> Rect2:
	var pfad: String = karte.fabrik_bild(z)
	if not _flaeche_je_bild.has(pfad):
		var bild: Image = karte.neu_bild(pfad).get_image()
		if bild.is_compressed():
			bild.decompress()
		var u := bild.get_region(Rect2i(0, 0, 64, 64)).get_used_rect()
		var je := HdAnsicht.FABRIK_MASSSTAB / float(Werte.ZELLE)   # Felder je Bildpunkt; Anker: x = 32, Zeile 57 auf dem Sockel
		var oben := HdAnsicht.FABRIK_SOCKEL + 0.01 + float(57 - u.position.y) * je
		_flaeche_je_bild[pfad] = Rect2(float(u.position.x - 32) * je, 0.0, float(u.size.x) * je, oben)
	return _flaeche_je_bild[pfad]


## Richtung der Schüsse: am Handy auf das selbst gewählte Ziel, sonst durchs Fadenkreuz.
func _schuss_blick() -> Vector3:
	if touch != null and _auto_ziel != null and is_instance_valid(_auto_ziel):
		return _auto_r
	return _blick()


func _schiess() -> void:
	if ringwerk._klinge_aktiv():
		ringwerk._klinge_schlag()   # 19.11.: Zeitlupe mit Durchschlagring – Nahkampf statt Schuss
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
		var t := _treffer_weite(g, von, r, bis, SCHUSS_WEITE, 0.34)
		if t > 0.0:
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
		if _ist_fabrik_ziel(g):
			_funke(von + r * (float(e[0]) - 0.08), 0.18)   # 25.11.: Trefferfunken knapp vor der Wand
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
		# 22.11. (Paul: „ab Runde 11 clunky“): nur große Gegner oder Mehrfach-Kills, höchstens alle HITSTOP.abstand Sekunden
		var stark := _kill_gross or _kills_seit_gefuehl >= int(BrakkFortschritt.HITSTOP["mehrfach"])
		var jetzt := Time.get_ticks_msec()
		if stark and jetzt - _letzter_stop_ms >= int(float(BrakkFortschritt.HITSTOP["abstand"]) * 1000.0):
			_letzter_stop_ms = jetzt
			_einfrieren(STOP_KILL)
	else:
		Ton.spiele(spiel, "brakk-treffer")
		_trauma = minf(1.0, _trauma + 0.16)
	_kills_seit_gefuehl = 0
	_kill_gross = false


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


## 25.11. (Paul): Befehl 24 – Feldbeförderung: kurze Zeitlupe (nicht Brakks Fähigkeit, ohne Abklingzeit) und, wenn die
## Einheit im Blick ist, ein Zoom-Ruck. Die Zielrichtung bleibt. Gibt zurück, ob sie im Blick war.
func befoerderungs_lupe(e: Node2D) -> bool:
	_einfrieren(Werte.NEMESIS_LUPE_SEK, Werte.NEMESIS_LUPE_TEMPO)
	_lupe_bis_ms = Time.get_ticks_msec() + int(Werte.NEMESIS_LUPE_SEK * 1000.0)
	if not im_blick(e):
		return false
	_lupe_zoom_bis_ms = _lupe_bis_ms
	_fov_puls = maxf(_fov_puls, Werte.NEMESIS_LUPE_ZOOM)
	return true


## 26.11. (Paul): Befehl 24 – der Herausforderer geht zu Boden.
func kurze_lupe(sek: float) -> void:
	_einfrieren(sek, Werte.NEMESIS_LUPE_TEMPO)
	_lupe_bis_ms = Time.get_ticks_msec() + int(sek * 1000.0)


## Steht die Figur im Bild und ist nichts davor?
func im_blick(e: Node2D) -> bool:
	var hd: HdAnsicht = spiel.hd
	if hd == null or hd.kamera == null or e == null or not is_instance_valid(e) or brakk == null:
		return false
	var p := _zu3d(e.position, 0.8)
	if hd.kamera.is_position_behind(p):
		return false
	var feld := hd.kamera.get_viewport().get_visible_rect()
	return feld.has_point(hd.kamera.unproject_position(p)) and spiel.karte.sicht_frei(brakk.position, e.position)


## Kurzes Einfrieren (Hit-Stop) in Echtzeit; nur der jüngste Aufruf stellt das Spieltempo wieder her.
## 25.11.: `faktor` – Anteil des Spieltempos. Während der Beförderungs-Zeitlupe schneidet ein Hit-Stop sie nicht ab.
func _einfrieren(dauer: float, faktor: float = 0.05) -> void:
	if faktor < Werte.NEMESIS_LUPE_TEMPO and Time.get_ticks_msec() < _lupe_bis_ms:
		return
	_stop_id += 1
	var meins := _stop_id
	if _stop_vorher < 0.0:
		_stop_vorher = Engine.time_scale
	Engine.time_scale = _stop_vorher * faktor
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
# 27.11. (Knoten-Umbau 7c): wohnt in scripts/brakk_licht.gd (`lichtwerk`).
# Hier bleiben, weil Kits, Touch, Lexikon oder Tests sie direkt nutzen:

## 18.11. (Paul): [E] wirft die Lichttreppe aus Abstand an den Erdwall im Blick (bis TREPPE_WEITE Felder). Sie steht
## TREPPE_HALTEN Sekunden; wer an ihren Fuß läuft, steigt hinauf. Steht Brakk schon davor, geht es gleich los.
const TREPPE_WEITE := 5.0


const TREPPE_HALTEN := 8.0


const TREPPE_LAENGER := 2         # 19.11.: so viele Felder darf die Treppe aus der Ferne länger werden


const TREPPE_AUFBAU := 0.45       # so lange springen die Stufen nacheinander auf


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


## Der Ring schießt ein Lichtseil an die Mauerkrone oder den Boden unter dem Fadenkreuz und zieht Brakk im Bogen hin –
## an einer Mauer landet er oben. Wie ein Greifhaken (Titanfall/Apex), nur aus Licht.
const ANKER_WEITE := 10.0


const ANKER_TEMPO := 14.0        # Felder je Sekunde


const ANKER_ABKLING := 6.0


## Oben auf einem Wall, Blick auf einen anderen Wall (bis BRUECKE_WEITE Felder): [E] wirft eine feste Lichtbahn
## hinüber, auf der Brakk geht (wie die harte Lichtbrücke in Portal 2). Sie steht BRUECKE_HALTEN Sekunden.
const BRUECKE_WEITE := 5.0


const BRUECKE_HALTEN := 10.0


const BRUECKE_AUFBAU := 0.5


const BRUECKE_ABKLING := 12.0     # 18.11. (Paul): eigene, längere Abklingzeit (die Treppe bleibt kurz)


## 19.11. (Paul): Leertaste in der Luft – der Ring wirft eine Lichtplattform unter Brakks Füße, er stößt sich ab.
## Einmal je Sprung, wieder nach der Landung. Die Plattform springt auf (Überschwung), pulsiert kurz und verblasst.
const DOPPEL_SPRUNG := 4.0       # Startgeschwindigkeit nach oben (der erste Sprung: SPRUNG)


const PLATTFORM_SEK := 0.7


## 19.11. (Paul): Oben auf dem Wall springen, in der Luft noch einmal springen – Brakk stößt sich von der Lichtplattform ab,
## fliegt in Laufrichtung (ohne Taste: Blickrichtung) hinunter und schlägt unten mit einer Druckwelle ein.
const ABSPRUNG_WEITE := 4.0      # höchstens so viele Felder weit sucht er einen Landeplatz


const DRUCK_RADIUS := 1.3        # Felder


const DRUCK_SCHADEN := 30.0      # 19.11. (Paul): genervt (war 80) – wie die Säule mal Fähigkeitsschaden


var _lauf := Vector2.ZERO        # Laufgeschwindigkeit (Felder/s, x und z) aus _gehen


var _flug := Vector2.ZERO        # Schwung in der Luft (Felder/s), aus Seil oder Abschnellen – weg bei der Landung


## 19.11. (Paul): Erstes [Q] wirft den Haken – er bleibt bis HAKEN_HALTEN hängen. Das Seil hält Brakk wie eine Leine
## (weiter als das Seil kommt er nicht). In der Luft am straffen Seil wird er leichter und schwingt um den Haken:
## springt er im Laufen, nimmt er den Lauf als Schwung mit. Zweites [Q] zieht heran, nochmal springen schnellt ab.
const HAKEN_HALTEN := 5.0


const SCHWING_MAL := 1.3         # Laufgeschwindigkeit -> Schwung beim Sprung am Seil


const SCHWING_LEICHT := 0.45     # so viel der Schwere hebt das Seil in der Luft auf


const ABSCHNELLEN_MAL := 1.3     # Schwung beim Lösen mit dem Doppelsprung


## Ein Stück gehen oder fliegen. Wer höher als die Mauerkrone ist, landet beim Hinüberfliegen oben auf dem Wall.
func _luft_schritt(s: Vector2) -> bool:
	var vorher := _fuss2d()
	var neu := vorher + s
	if not brakk.oben and hoehe >= hd.H - 0.05 and not _passt_unten(neu):
		# 21.11.: Die Körperkante stößt an, bevor die Mitte im Mauerfeld ist – die Kante vorn entscheidet, und die
		# Mitte rückt aufs Mauerfeld (sonst bleibt man in der Luft an der Mauerfläche hängen)
		var vorn := neu + s.normalized() * KOERPER * Werte.ZELLE * 1.05
		var z := karte.zelle_bei(vorn)
		if hd.ist_hoch(z) and karte.inhalt(z) == Karte.WALL:
			brakk.oben = true
			brakk.posten_zelle = z
			brakk.zustand = Einheit.Zustand.AUF_POSTEN
			hoehe = maxf(hoehe, hd.H)
			_setze_fuss(vorn)
			return true
	_schritt(s)
	return _fuss2d() != vorher


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
# 27.11. (Knoten-Umbau 7d): wohnt in scripts/brakk_anzeige.gd (`anzeige`).
# Hier bleiben, weil Kits, Touch, Lexikon oder Tests sie direkt nutzen:

## 18.11.: Waffen und Hand aus PixelLab (assets/neu/ego); fehlen die Bilder, die gezeichneten Platzhalter.
const PISTOLE_BILD := "res://assets/neu/ego/pistole.png"


const PISTOLE_RECHTS_BILD := "res://assets/neu/ego/pistole_rechts.png"   # 18.11. (Paul): rechte Pistole – Handkanone mit Augen-Linse (PixelLab, in Technoclan-Farben umgefärbt)


const RINGHAND_BILD := "res://assets/neu/ego/ringhand.png"


var _muendung := Vector2(-1, -1)    # Laufmündung im Pistolenbild (Bildpunkte); -1 = Platzhalter (oben Mitte)


var _ring_licht := Vector2(15.5, 15.0)   # Leuchtpunkt des Rings im Handbild


const NEIGUNG := 0.2   # die Pistolen zeigen leicht nach innen, zum Fadenkreuz


func _muendungsblitz(p: Vector2, px: float, farbe: Color = SCHUSS) -> void:
	var s := px * 3.0
	_bild.draw_rect(Rect2(p - Vector2(s, s * 0.35), Vector2(s * 2.0, s * 0.7)), Color(farbe, 0.9))
	_bild.draw_rect(Rect2(p - Vector2(s * 0.35, s), Vector2(s * 0.7, s * 2.0)), Color(farbe, 0.9))
	_bild.draw_rect(Rect2(p - Vector2(s * 0.5, s * 0.5), Vector2(s, s)), Color.WHITE)


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


## 18.11. (Paul): nicht abrupt in die Ego-Sicht – erst eine Einsatz-Tafel (Tasten, Ablauf), der Countdown wartet.
## „Los“ (Klick, Enter, Leertaste): das Bild blendet aus dem Schwarzen auf, die Kamera senkt sich von oben in Brakks Augen.
const EINFLUG_SEK := 1.8


## 18.11. (Paul: „nicht so blockartig“): Einsatz-Tafel in drei Teilen – Kopf mit Warnstreifen, Tasten als
## Tastenkappen (statt Fließtext), unten meldet sich Sonde 7 im Funkfenster und tippt den Ablauf.
const BRIEFING_SONDE := "res://assets/sprites/tutorial/sonde7.png"


const BRIEFING_HOLO := Color("6ee6ff")


const BRIEFING_HOLO_TEXT := Color("c8f4ff")


const BRIEFING_TIPPEN := 55.0   # Zeichen je Sekunde


const BRIEFING_FUNK := "Kommandant, Sonde 7 hier. Heute gehst du selbst raus. Die Welle rollt nach dem Countdown an – [Enter] holt sie früher. Es werden viele, und Steine mit rotem Kreis fliegen auf dich: ausweichen! Fabriken bauen hier nicht aus, deine Ringe machen sie stark. Viel Glück. Sonde 7 Ende."


const BRIEFING_FUNK_TOUCH := "Kommandant, Sonde 7 hier. Heute gehst du selbst raus. Die Welle rollt nach dem Countdown an. Es werden viele, und Steine mit rotem Kreis fliegen auf dich: ausweichen! Fabriken bauen hier nicht aus, deine Ringe machen sie stark. Viel Glück. Sonde 7 Ende."


const BRIEFING_LICHTER := [[35, 40, 6, Color("6cecfe")], [49, 50, 6, Color("ff4a5e")], [18, 43, 4, Color("ff4a5e")]]


## 19.11. (Paul): Klein und immer sichtbar unten links, als Werteliste wie in anderen Spielen (Name links, Zahl rechts):
## Schaden, Schüsse/s, Schaden/s. Darunter klein in der Ringfarbe, was die Ringe dazugeben. Schmal genug, dass es links
## neben Brakks linker Waffe bleibt.
## Ändert sich ein Wert (Ringwechsel, Aufstieg), blinkt er kurz grün. Am Handy (unten links liegt der Stick) eine
## kurze Zeile über der Lebensleiste.
const WERTE_BLINK_MS := 700


## Kurzname eines Rings ohne „ring“ (Glutstrahl, Gel, Takt …).
static func ring_kurz(ring: String) -> String:
	return str(BrakkFortschritt.RINGE[ring]["name"]).trim_suffix("ring")


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
	var zl := 1.0 / float(BrakkFortschritt.ZEITLUPE_RING["laser"]["touch_takt"]) if touch != null and ringwerk._zl_aktiv("laser") else 1.0   # 19.11.: am Handy ohne Hitze – schneller
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
	_kills_seit_gefuehl += 1   # 22.11.: für den gedrosselten Hit-Stop
	if BrakkFortschritt.gross(g):
		_kill_gross = true
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
	if _tumble >= 0.0 or _klettern >= 0.0 or lichtwerk._anker >= 0.0 or not _darf("tumble"):
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
	if spiel.order24 != null:
		spiel.order24.brakk_bewegung("tumble", r)   # 26.11.
	var v := _vorne() * r.y + _rechts() * r.x
	_tumble_r = Vector2(v.x, v.z).normalized()
	_tumble = 0.0
	_zaehle("rollen")   # 19.11.: Sieg-Übersicht
	_tumble_rest = TUMBLE_ABKLING
	brakk.unverwundbar = Werte.BRAKK_TUMBLE_DURCHLASS   # 20.11.: Schritt 6c – 0,25 s (vorher 0,4), Geschosse gehen hindurch
	if spiel.order24 != null:
		spiel.order24.brakk_gewohnheit("tumble")   # 22.11. (Nemesis Teil 4): zählt, wenn gerade etwas angeflogen kommt
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
		var t := _treffer_weite(g, von, r, weite, LANZE_WEITE, 0.45)
		if t <= 0.0:
			continue
		if _ist_fabrik_ziel(g):
			_funke(von + r * (t - 0.08), 0.35)
		# 19.11. (Paul): dazu ein Anteil des maximalen Lebens (große Gegner weniger) – trägt die Lanze ins späte Spiel
		var grosser: bool = BrakkFortschritt.gross(g) or (spiel.order24 != null and spiel.order24.ist_herausforderer_ziel(g))   # 26.11.: der Herausforderer zählt als groß
		var anteil := float(BrakkFortschritt.LANZE_ANTEIL["gross" if grosser else "normal"])
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
# ------------------------------------------------------------------ Brakk-Mode: Ringe und Lichtterminal (18.11.)
# 27.11. (Knoten-Umbau 7b): wohnt in scripts/brakk_ringe.gd (`ringwerk`).
# Hier bleiben, weil Kits, Touch, Lexikon oder Tests sie direkt nutzen:

## Ring zeichnen: sein Pixelbild (ring_bilder.gd, nach Pauls Entwürfen) mit Schein in der Ringfarbe.
func _male_ring(ci: CanvasItem, m: Vector2, r: float, ring: String, hell: float = 1.0) -> void:
	var farbe := _ring_farbe(ring)
	ci.draw_circle(m, r * 1.5, Color(farbe, 0.2 * hell))
	var gr := roundf(r * 2.4 / 16.0) * 16.0 if r * 2.4 >= 16.0 else r * 2.4
	ci.draw_texture_rect(RingBilder.bild(ring, farbe), Rect2((m - Vector2(gr, gr) / 2.0).round(), Vector2(gr, gr)), false, Color(1, 1, 1, hell))


func _ring_farbe(ring: String) -> Color:
	return Einheit.ABZEICHEN.get(ring, LICHT)


## 18.11.: Ist eine Tafel offen (Übersicht, Pause, Terminal, Fabrikmenü)? Dann zeichnet die Ego-Sicht nichts darüber.
func _hud_aus() -> bool:
	if spiel.phase == 2:
		return true   # 18.11. (Paul): Endtafel (Sieg/Niederlage) – keine Waffen und Leisten darüber
	if anzeige._briefing_offen():
		return true
	if spiel._lexikon != null and spiel._lexikon.visible:
		return true
	if spiel._hud != null and spiel._hud.pausiert():
		return true
	if spiel._fabrikmenue != null and spiel._fabrikmenue.visible:
		return true
	return _terminal != null and _terminal.visible


func _zaehle(was: String) -> void:
	if brakk.fortschritt != null:
		brakk.fortschritt.zaehler[was] = int(brakk.fortschritt.zaehler.get(was, 0)) + 1


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
	if anzeige._briefing != null and anzeige._briefing.visible:
		return   # 18.11.: die Einsatz-Tafel ist noch offen – der Countdown wartet
	if spiel.tutorial is BrakkTutorial:
		_countdown = -1.0
		return   # 22.11.: Übungsgelände – die Welle startet erst die Probewelle des Tutorials
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
	_bild.draw_rect(Rect2(r.position + Vector2(4, r.size.y - 6), Vector2((r.size.x - 8.0) * o.balken_anteil(), 3)), farbe)   # 22.11. (Paul): bis zum nächsten Ereignis
	Stil.schreibe_mittig(_bild, m + Vector2(0, 30), o.phase_text(), 14, Stil.TEXT_BLASS)   # 22.11. (Paul): nur die Phase (Budget steht im HUD)
	if o.am_terminal(_fuss2d()) and (_terminal == null or not _terminal.visible):
		Stil.schreibe_mittig(_bild, m + Vector2(0, 52), "[F] Lichtterminal", 16, Stil.GOLD)
	o.hud(_bild, g, self)   # 20.11.: Befehl 24 – Sprengladungen, In Deckung, Sabotage (order24.gd)


# ------------------------------------------------------------------ Brakk-Mode: Überhitzen (18.11.)

func _heize(seite: int) -> void:
	if touch != null:
		return   # 18.11. (Paul): am Handy schießt Brakk selbst – kein Überhitzen
	if ringwerk._zl_aktiv("laser"):
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
		_zaehle("ueberhitzt")   # 23.11.: Run-Protokoll


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
# ------------------------------------------------------------------ Brakk-Mode: Lichtsäule [X] und Zeitlupe [V] (18.11.)
# 27.11. (Knoten-Umbau 7a): Ablauf und Zustand in scripts/brakk_saeule.gd (`saeule`); hier bleiben die Zahlen (SAEULE_*,
# ZEITLUPE_*) und die allgemeinen Helfer _einschlag, _brakk_sprung, _gel_bonus, _finger_wirbel, _licht_farbe.

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
	saeule._neue_saeule(p, radius * 0.55, 0.45)
	_funke(_zu3d(p, 0.3), radius / Werte.ZELLE * 0.4)
	var nah := clampf(1.0 - p.distance_to(_fuss2d()) / (SAEULE_WEITE * Werte.ZELLE), 0.2, 1.0)
	_trauma = minf(1.0, _trauma + 0.45 * nah * wucht)
	_fov_puls = maxf(_fov_puls, 4.0 * wucht)
	Ton.spiele(spiel, "hit-boom", -6.0)
	return getroffen


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
const FINGERSPITZE := Vector2(36, 8)   # im Handbild (ringhand.png)


func _finger_wirbel(rp: Vector2, wpx: float, auf: float) -> void:
	if saeule._saeule_ziel == Vector2.INF and not saeule._saeule_zielt:
		return
	var f := 0.0 if saeule._saeule_zielt else clampf(saeule._saeule_t / SAEULE_VORLAUF, 0.0, 1.0)
	var mitte := rp.round() + FINGERSPITZE * wpx
	var w := Time.get_ticks_msec() / 1000.0 * (10.0 + 18.0 * f)
	var r := (5.0 + 3.0 * f) * wpx
	for i in 14:
		var a := w - float(i) * 0.32
		var p := mitte + Vector2(cos(a), sin(a) * 0.55) * r
		var alpha := (1.0 - float(i) / 14.0) * auf
		_bild.draw_rect(Rect2((p - Vector2(1, 1) * wpx).round(), Vector2(2, 2) * wpx), Color(saeule._saeule_farbe.lightened(0.4 * (1.0 - float(i) / 14.0)), alpha))
	_bild.draw_circle(mitte, (2.0 + 2.0 * f) * wpx, Color(saeule._saeule_farbe, 0.5 * auf))


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


## 22.11. (Paul): Ein Gegner ist in die eigene Basis eingedrungen – deutlich anzeigen, nicht nur die Lebenszahl:
## orangener Rand, Banner oben, Alarmton und ein Pfeil am Bildrand in Richtung der Basis. Mehrere kurz
## hintereinander zählen im Banner hoch. Über Echtzeit (Zeitlupe und Tempo ändern die Anzeigedauer nicht).
const EINBRUCH_SEK := 2.5
const EINBRUCH_FARBE := Color(1.0, 0.55, 0.1)
var einbrueche := 0               # alle Einbrüche dieser Partie (Tests)
var _einbruch_ms := -100000       # Zeitpunkt des letzten Einbruchs
var _einbruch_zahl := 0           # Einbrüche in der laufenden Anzeige
var _einbruch_ort := Vector2.ZERO


## Aufgerufen von main.gd (gegner_am_ziel).
func einbruch(wo: Vector2) -> void:
	einbrueche += 1
	_einbruch_zahl = _einbruch_zahl + 1 if _einbruch_rest() > 0.0 else 1
	_einbruch_ms = Time.get_ticks_msec()
	_einbruch_ort = wo
	_trauma = minf(1.0, _trauma + 0.15)
	Ton.spiele(spiel, "alert", 3.0)


## Restliche Anzeigedauer in Sekunden (0 = aus).
func _einbruch_rest() -> float:
	return maxf(0.0, EINBRUCH_SEK - float(Time.get_ticks_msec() - _einbruch_ms) / 1000.0)


func _einbruch_bild(g: Vector2) -> void:
	var rest := _einbruch_rest()
	if rest <= 0.0:
		return
	var a := clampf(rest / 0.6, 0.0, 1.0)   # die letzten 0,6 s ausblenden
	var puls := 0.65 + 0.35 * sin(Time.get_ticks_msec() / 90.0)
	for i in 6:
		var d := float(i) * 12.0
		_bild.draw_rect(Rect2(Vector2(d, d), g - Vector2(d, d) * 2.0), Color(EINBRUCH_FARBE, 0.22 * a * puls * (1.0 - float(i) / 6.0)), false, 12.0)
	# Banner oben
	var bh := g.y * 0.11
	var oben := g.y * 0.25   # unter dem Wellen-Countdown
	_bild.draw_rect(Rect2(Vector2(g.x * 0.2, oben), Vector2(g.x * 0.6, bh)), Color(0.15, 0.03, 0.0, 0.88 * a))
	_bild.draw_rect(Rect2(Vector2(g.x * 0.2, oben), Vector2(g.x * 0.6, bh)), Color(EINBRUCH_FARBE, 0.9 * a), false, 3.0)
	var titel := "EINBRUCH IN DEINE BASIS!" + (" ×%d" % _einbruch_zahl if _einbruch_zahl > 1 else "")
	Stil.schreibe_mittig(_bild, Vector2(g.x / 2.0, oben + bh * 0.38), titel, 30, Color(1.0, 0.75, 0.3, a * puls))
	Stil.schreibe_mittig(_bild, Vector2(g.x / 2.0, oben + bh * 0.78), "−%d Leben · noch %d" % [_einbruch_zahl, int(spiel.leben)], 18, Color(1, 1, 1, 0.9 * a))
	# Pfeil am Bildrand Richtung Basis (wie die Trefferbögen in _gefahr_bild)
	if not is_instance_valid(brakk):
		return
	var blick := atan2(_vorne().z, _vorne().x)
	var rel := (_einbruch_ort - brakk.position).angle() - blick - PI / 2.0
	var m := g / 2.0
	var r := g.y * 0.36
	var dir := Vector2(cos(rel), sin(rel))   # gleiche Winkel wie _gefahr_bild: rel ist der Bildwinkel
	var spitze := m + dir * r
	var quer := Vector2(-dir.y, dir.x)
	var s := g.y * 0.035
	_bild.draw_colored_polygon(PackedVector2Array([spitze + dir * s, spitze - dir * s + quer * s, spitze - dir * s - quer * s]), Color(EINBRUCH_FARBE, 0.95 * a * puls))
	_bild.draw_arc(m, r - s * 1.6, rel - 0.25, rel + 0.25, 16, Color(EINBRUCH_FARBE, 0.8 * a), 6.0)


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
# ------------------------------------------------------------------ Brakk-Mode: Doppelsprung mit Lichtplattform (19.11.)
# ------------------------------------------------------------------ Brakk-Mode: Werte-Fenster (19.11.)
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
	if saeule._zeitlupe > 0.0:
		saeule._zeitlupe_aus()
	if brakk.fortschritt != null:
		_sieg_bericht = brakk.fortschritt.sieg_bericht(spiel, sekunden)
		Profil.brakk_sieg(_sieg_bericht)
		spiel.brakk_bericht_merken(_sieg_bericht)   # 23.11.: Run-Protokoll
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
	lichtwerk._lichtplattform()
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
