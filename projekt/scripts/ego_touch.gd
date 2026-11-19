class_name EgoTouch
extends Node
## Brakk-Mode am Handy (18.11.): Steuerung wie in Mobil-Shootern und MOBAs – ohne Maus und Tastatur.
##   Links: schwebender Stick (erscheint, wo der Daumen aufsetzt) – laufen.
##   Rechts: Wischen auf freier Fläche dreht den Blick.
##   Brakk schießt selbst, sobald das Fadenkreuz auf einem Gegner liegt (EgoModus._auto_zielen) – zielen musst du; kein Überhitzen.
##   Knöpfe im Bogen rechts unten: Doppellanze (halten = laden, loslassen = feuern), Rolle, Treppe/Brücke,
##   Anker, Lichtsäule, Zeitlupe, Klonmaschine, Ring wechseln, Ringfeld.
##   Fähigkeiten mit Ziel: kurz tippen = dort auslösen, wohin das Fadenkreuz zeigt;
##   halten und ziehen = zielen mit Vorschau am Ziel, loslassen = auslösen, auf „✕“ ziehen = abbrechen. (Paul: kein Sprung am Handy.)
## Gezeichnet wird im Bild der Ego-Sicht (EgoModus._bild, 1280×720), Eingaben kommen hier in _input an.

const Stil := preload("res://scripts/ui/ui_stil.gd")
const LICHT := Color("7fe0ff")
const ROT := Color("ff5a6e")
const BLICK := 0.0055          # Bogenmaß je Bildpunkt Wischen
const BLICK_FEIN := 0.6        # beim Zielen mit einem Knopf etwas feiner
const ZIELBREMSE := 0.55       # Fadenkreuz auf einem Gegner: so viel langsamer dreht der Blick
const STICK_ZONE_X := 520.0    # links davon (und unterhalb STICK_ZONE_Y) setzt der Daumen den Stick
const STICK_ZONE_Y := 180.0
const STICK_R := 90.0
const STICK_RUHE := Vector2(170, 560)
const ZIEH_AB := 14.0          # ab so viel Bewegung wird aus Tippen Zielen
const ABBRUCH := Vector2(880, 170)
const ABBRUCH_R := 46.0

## Knöpfe: id, Mitte, Radius, Glyphe (aus EgoModus.GLYPHEN, "" = eigenes Zeichen), Beschriftung
const KNOEPFE := [
	["lanze", Vector2(1150, 480), 62.0, "lanze", "Lanze"],
	["tumble", Vector2(1010, 560), 42.0, "tumble", "Rolle"],
	["treppe", Vector2(1052, 330), 42.0, "treppe", "Treppe"],
	["anker", Vector2(1165, 318), 42.0, "anker", "Anker"],
	["saeule", Vector2(1232, 392), 36.0, "saeule", "Säule"],
	["zeitlupe", Vector2(942, 322), 36.0, "zeitlupe", "Zeitlupe"],
	["ulti", Vector2(1238, 248), 36.0, "ulti", "Klon"],
	["ring", Vector2(1092, 222), 32.0, "", "Ring"],
	["feld", Vector2(990, 222), 30.0, "", "Feld"],
	["aktion", Vector2(820, 560), 46.0, "", ""],
	["sprung", Vector2(905, 455), 40.0, "", "Sprung"],   # 19.11. (Paul): Sprung, zweimal = Doppelsprung, vom Wall = Absprung
	["weg", Vector2(688, 524), 36.0, "", "Weglegen"],   # 19.11. (Paul): Bauwerk weglegen / Ringfeld abbrechen
	["bauliste", Vector2(54, 140), 30.0, "", "Bauen"],
]

var ego: EgoModus
var spiel: Node
var bau_offen := false

var _stick_finger := -1
var _stick_mitte := STICK_RUHE
var _stick_aus := Vector2.ZERO        # -1..1, y nach oben = vorwärts
var _blick_finger := -1
var _letzte := {}                      # 18.11. (Paul): Finger -> letzte Position; die Bewegung je Finger selbst ausrechnen
const SPRUNG_MAX := 90.0               # größere Sprünge in einem Bild sind Messfehler (anderer Finger) – verwerfen
var _knopf: Dictionary = {}           # Finger -> {id, start, pos, gezogen}
var _maus_meins := false              # nachgemachte Maus eines eigenen Fingers: nicht ans Spiel


func _init(p_ego: EgoModus) -> void:
	ego = p_ego
	spiel = p_ego.spiel
	process_mode = Node.PROCESS_MODE_ALWAYS
	if OS.get_environment("TD_TOUCH") != "":
		Input.emulate_touch_from_mouse = true   # am PC mit der Maus als Finger ausprobieren


## Laufrichtung für EgoModus._gehen: x rechts, y vorwärts.
func stick() -> Vector2:
	return _stick_aus


func zielt() -> String:
	for f: int in _knopf:
		var k: Dictionary = _knopf[f]
		if bool(k["gezogen"]):
			return str(k["id"])
	return ""


# ------------------------------------------------------------------ Eingabe

func _frei() -> bool:
	return ego._frei() and not ego._liegt


## Gehört ein Fingerdruck an dieser Stelle der Touch-Steuerung? Nein über Knöpfen der Oberfläche (Menü, Start, Tempo)
## und wenn ein Menü offen ist – dann bekommt das Spiel den Tipp wie gewohnt.
func _gehoert_mir(p: Vector2) -> bool:
	if not _frei():
		return false
	var g := SichererRand.nach_aussen(p)   # 19.11.: p liegt in der sicheren Fläche, die HUD-Knöpfe im Bild
	for b: Node in spiel._hud.find_children("*", "BaseButton", true, false):
		var c := b as Control
		if c.is_visible_in_tree() and c.get_global_rect().has_point(g):
			return false
	return true


func _input(event: InputEvent) -> void:
	# 19.11. (Paul): Fabrikmenü am Handy – ein Tipp neben die Tafel schließt sie (vorher öffnete das Spiel sie unter dem
	# Fadenkreuz sofort wieder, Blick und Stick hingen). Der Tipp zählt danach gleich für Stick und Blick.
	if (event is InputEventMouseButton or event is InputEventScreenTouch) and event.is_pressed():
		var wo: Vector2 = (event as InputEventMouseButton).position if event is InputEventMouseButton else (event as InputEventScreenTouch).position
		if _menue_zu(wo) and event is InputEventMouseButton:
			_maus_meins = true
			get_viewport().set_input_as_handled()
			return
	# Die Maus, die Godot aus dem ersten Finger macht (oder am PC die echte Maus mit TD_TOUCH), darf nicht zusätzlich
	# klicken oder schwenken, wenn der Finger der Steuerung gehört.
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed:
			_maus_meins = _gehoert_mir(SichererRand.nach_innen(mb.position))
		if _maus_meins:
			if not mb.pressed:
				_maus_meins = false
			get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseMotion:
		if _maus_meins:
			get_viewport().set_input_as_handled()
		return
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		var tp := SichererRand.nach_innen(t.position)   # 19.11.: Knöpfe liegen in der sicheren Fläche
		if t.pressed:
			_letzte[t.index] = tp
			if _druck(t.index, tp):
				get_viewport().set_input_as_handled()
		else:
			_letzte.erase(t.index)
			if _los(t.index, tp):
				get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		# 18.11. (Paul): Nicht `d.relative` nehmen – im Browser bezieht es sich mit zwei Fingern teils auf den anderen
		# Finger, dann springt der Blick. Jeder Finger rechnet seine Bewegung aus seiner eigenen letzten Position.
		var dp := SichererRand.nach_innen(d.position)
		var vorher: Vector2 = _letzte.get(d.index, dp)
		_letzte[d.index] = dp
		var rel := dp - vorher
		if rel.length() > SPRUNG_MAX:
			rel = Vector2.ZERO
		if _ziehen(d.index, dp, rel):
			get_viewport().set_input_as_handled()



func _menue_zu(p: Vector2) -> bool:
	var m: Control = spiel._fabrikmenue
	if m == null or not m.visible or m.get_global_rect().has_point(p):
		return false
	spiel._schliesse_fabrikmenue()
	return true

func _druck(f: int, p: Vector2) -> bool:
	if not _gehoert_mir(p):
		return false
	if ego._countdown >= 0.0 and Rect2(490, 98, 300, 50).has_point(p):
		spiel.starte_welle()   # Countdown antippen: Welle jetzt
		return true
	var id := _knopf_bei(p)
	if id != "":
		if id == "bauliste":
			bau_offen = not bau_offen
			if not bau_offen:
				spiel.werkzeug = Karte.FREI
			return true
		if id == "sprung":
			ego._leertaste()   # 19.11.: sofort beim Antippen
			return true
		_knopf[f] = {"id": id, "start": p, "pos": p, "gezogen": false}
		if id == "lanze":
			ego._lanze_taste(true)
		return true
	if bau_offen:
		var typ := _bau_eintrag_bei(p)
		if typ != -1:
			if spiel.werkzeug == typ:
				spiel.werkzeug = Karte.FREI
			else:
				spiel.waehle(typ)
			return true
	if _stick_finger < 0 and p.x < STICK_ZONE_X and p.y > STICK_ZONE_Y:
		_stick_finger = f
		_stick_mitte = p
		_stick_aus = Vector2.ZERO
		return true
	if _blick_finger < 0 and p.x >= STICK_ZONE_X:
		_blick_finger = f   # 18.11. (Paul): links laufen, rechts schauen – getrennte Hälften
		return true
	return true


func _ziehen(f: int, p: Vector2, rel: Vector2) -> bool:
	if f == _stick_finger:
		var v := (p - _stick_mitte) / STICK_R
		if v.length() > 1.0:
			_stick_mitte += (p - _stick_mitte) - v.normalized() * STICK_R   # der Stick wandert mit dem Daumen
			v = v.normalized()
		_stick_aus = Vector2(v.x, -v.y)
		return true
	if f == _blick_finger:
		_drehe(rel, 1.0)
		return true
	if _knopf.has(f):
		var k: Dictionary = _knopf[f]
		k["pos"] = p
		if not bool(k["gezogen"]) and p.distance_to(k["start"]) > ZIEH_AB:
			k["gezogen"] = true
			if str(k["id"]) == "saeule":
				ego._saeule_x()   # Marke folgt dem Fadenkreuz
		if bool(k["gezogen"]):
			_drehe(rel, BLICK_FEIN)
		return true
	return false


func _los(f: int, p: Vector2) -> bool:
	if f == _stick_finger:
		_stick_finger = -1
		_stick_aus = Vector2.ZERO
		_stick_mitte = STICK_RUHE
		return true
	if f == _blick_finger:
		_blick_finger = -1
		return true
	if not _knopf.has(f):
		return false
	var k: Dictionary = _knopf[f]
	_knopf.erase(f)
	var id := str(k["id"])
	var abbruch := bool(k["gezogen"]) and p.distance_to(ABBRUCH) <= ABBRUCH_R
	if id == "lanze":
		if abbruch:
			ego._lanze = -1.0
		else:
			ego._lanze_taste(false)
		return true
	if bool(k["gezogen"]):
		if abbruch:
			if id == "saeule":
				ego._saeule_abbrechen()
			Ton.spiele(spiel, "ui-klick", -8.0)
		else:
			_ausloesen(id)
	elif _knopf_bei(p) == id:
		_tippen(id)
	return true


## Blick drehen. Zielbremse (wie in Mobil-Shootern): liegt das Fadenkreuz auf einem Gegner, dreht es langsamer –
## so bleibt man leichter drauf.
func _drehe(rel: Vector2, mal: float) -> void:
	if ego._auto_ziel != null:
		mal *= ZIELBREMSE
	ego.gier -= rel.x * BLICK * mal
	ego.nick = clampf(ego.nick - rel.y * BLICK * mal, -1.25, 1.25)


# ------------------------------------------------------------------ Knöpfe

func _sichtbar(id: String) -> bool:
	var f := ego.brakk.fortschritt
	match id:
		"ring":
			return f != null and not f.ringe.is_empty()
		"feld":
			return f != null and not f.ringe.is_empty() and spiel.phase == 0
		"aktion":
			return _aktion_text() != ""
		"weg":
			return spiel.werkzeug != Karte.FREI or ego._feld_zielt
		"bauliste":
			return spiel.phase == 0 or spiel.werkzeug != Karte.FREI or bau_offen
	return true


func _knopf_bei(p: Vector2) -> String:
	for k: Array in KNOEPFE:
		var id: String = k[0]
		if _sichtbar(id) and p.distance_to(k[1]) <= float(k[2]) + 8.0:
			return id
	return ""


func _aktion_text() -> String:
	if ego._feld_zielt:
		return "Setzen"   # 19.11.: Ringfeld bestätigen
	if spiel.werkzeug != Karte.FREI:
		return "Bauen"
	if ego.gebaeude_im_blick() != Karte.KEINE:
		return "Truppe" if spiel.brakk_modus else "Ausbauen"   # 19.11.: im Brakk-Mode gibt es nur die Truppenwahl
	if ego._am_terminal():
		return "Ringe"
	return ""


## Rechtecke der Bauliste wie in EgoModus._bauliste (eine Zeile je Bauwerk außer Brakk).
func _bau_eintraege() -> Array:
	var liste: Array = []
	for k: Array in spiel._hud.KACHELN:
		if int(k[0]) != Karte.KOMMANDANT:
			liste.append(int(k[0]))
	return liste


func _bau_eintrag_bei(p: Vector2) -> int:
	var liste := _bau_eintraege()
	var oben := (720.0 - 34.0 * liste.size()) / 2.0
	for i in liste.size():
		if Rect2(8, oben + i * 34.0 - 2.0, 222, 34).has_point(p):
			return int(liste[i])
	return -1


## Kurz getippt.
func _tippen(id: String) -> void:
	match id:
		"tumble":
			ego._tumble_start()
		"zeitlupe":
			if spiel.brakk_modus:
				ego._zeitlupe_start()
		"ulti":
			if ego.brakk.fortschritt != null:
				ego._ulti()
		"ring":
			ego._ring_waehlen(1)
		"feld":
			ego._wirf_feld()
		"aktion":
			_aktion()
		"weg":
			if ego._feld_zielt:
				ego._feld_abbrechen()
			else:
				spiel.werkzeug = Karte.FREI
		"treppe":
			_e_ausloesen()
		"anker":
			ego._anker_start()
		"saeule":
			_saeule_tippen()


## Nach dem Ziehen losgelassen: dort auslösen, wohin jetzt das Fadenkreuz zeigt.
func _ausloesen(id: String) -> void:
	match id:
		"treppe":
			_e_ausloesen()
		"anker":
			ego._anker_start()
		"saeule":
			if ego._saeule_zielt:
				ego._saeule_bestaetigen()
		_:
			_tippen(id)


func _aktion() -> void:
	if ego._feld_zielt:
		ego._feld_bestaetigen()
		return
	if spiel.werkzeug != Karte.FREI:
		var z: Vector2i = spiel.karte.zelle_bei(ego.ziel_welt())
		if not ego._in_reichweite(z):
			spiel.melde("Zu weit weg – geh näher heran (höchstens %d Felder)." % int(EgoModus.BAU_REICHWEITE), 2.5)
			return
		spiel.baue(z, spiel.werkzeug)
		return
	var g := ego.gebaeude_im_blick()
	if g != Karte.KEINE:
		spiel._oeffne_fabrikmenue(g)
	elif ego._am_terminal():
		ego._terminal_auf()


## [E] wie am PC: unten Treppe hinauf, oben Brücke (Blick auf einen anderen Wall) oder hinunter.
func _e_ausloesen() -> void:
	if ego._klettern >= 0.0:
		return
	if ego.brakk.oben:
		if not ego._versuche_bruecke():
			ego._versuche_absteigen(true)
	else:
		ego._versuche_klettern(true)


## Lichtsäule antippen: dort, wo das Fadenkreuz den Boden trifft (zu weit: Meldung, kein Hängenbleiben im Zielen).
func _saeule_tippen() -> void:
	if not ego._darf("saeule") or ego._saeule_ziel != Vector2.INF:
		return
	ego._saeule_x()
	if ego._saeule_zielt:
		ego._saeule_bestaetigen()
		if ego._saeule_zielt:
			ego._saeule_abbrechen()


func _process(delta: float) -> void:
	if not _frei():
		# Menü offen, Pause, Brakk liegt: alles loslassen
		_stick_finger = -1
		_stick_aus = Vector2.ZERO
		_stick_mitte = STICK_RUHE
		_blick_finger = -1
		if not _knopf.is_empty() and ego._saeule_zielt:
			ego._saeule_abbrechen()
		_knopf.clear()
		return
	if spiel.phase != 0 and spiel.werkzeug == Karte.FREI:
		bau_offen = false


# ------------------------------------------------------------------ Zeichnen

func male(ci: Control) -> void:
	if not _frei():
		return
	_male_auto_ziel(ci)
	var zid := zielt()
	if zid != "":
		_male_vorschau(ci, zid)
	_male_bau_hinweis(ci)   # 19.11.
	# 19.11.: ab hier in der sicheren Fläche (iPhone: Notch, Home-Balken); Eingaben rechnet _input mit nach_innen um
	var t := Transform2D(0.0, Vector2.ONE * SichererRand.faktor(), 0.0, SichererRand.versatz())
	Stil.ebene = t
	ci.draw_set_transform_matrix(t)
	_male_stick(ci)
	for k: Array in KNOEPFE:
		if _sichtbar(str(k[0])):
			_male_knopf(ci, k)
	if zid != "":
		var nah := false
		for f: int in _knopf:
			nah = nah or (_knopf[f]["pos"] as Vector2).distance_to(ABBRUCH) <= ABBRUCH_R
		ci.draw_circle(ABBRUCH, ABBRUCH_R, Color(ROT, 0.45 if nah else 0.18))
		ci.draw_arc(ABBRUCH, ABBRUCH_R, 0.0, TAU, 40, ROT, 3.0)
		var s := 14.0
		ci.draw_line(ABBRUCH - Vector2(s, s), ABBRUCH + Vector2(s, s), Color.WHITE, 4.0)
		ci.draw_line(ABBRUCH + Vector2(-s, s), ABBRUCH + Vector2(s, -s), Color.WHITE, 4.0)
		_text(ci, ABBRUCH + Vector2(0, ABBRUCH_R + 16.0), "Abbrechen", 18, ROT)
		_text(ci, Vector2(640, 214), "Ziehen zum Zielen · loslassen: auslösen", 20, Color.WHITE)
	Stil.ebene = Transform2D.IDENTITY
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)


## 19.11. (Paul): Bauen am Handy deutlicher – unter dem Fadenkreuz steht, was der Knopf „Bauen“ jetzt tut: grün „Erdwall
## hier bauen“ oder rot, warum nicht (Stellungen rasten dabei auf den nächsten passenden Wall ein).
func _male_bau_hinweis(ci: Control) -> void:
	if spiel.werkzeug == Karte.FREI or ego._feld_zielt:
		return
	var p := ego.ziel_welt()
	var text := ""
	var ok := false
	if p.x < -9000.0:
		text = "Auf den Boden oder einen Wall schauen"
	else:
		var z: Vector2i = spiel.karte.zelle_bei(p)
		var grund: String = spiel.bau_hindernis(z, spiel.werkzeug)
		if not ego._in_reichweite(z):
			grund = "Zu weit – höchstens %d Felder" % int(EgoModus.BAU_REICHWEITE)
		ok = grund == ""
		var name: String = str(spiel.BAUTEN[spiel.werkzeug][1]) if spiel.BAUTEN.has(spiel.werkzeug) else "Bauwerk"
		text = "%s hier bauen – „Bauen“ tippen" % name if ok else grund
	_text(ci, Vector2(640, 410), text, 20, Color("7dffa0") if ok else ROT)

func _male_stick(ci: Control) -> void:
	var aktiv := _stick_finger >= 0
	ci.draw_circle(_stick_mitte, STICK_R, Color(0.03, 0.04, 0.07, 0.5 if aktiv else 0.32))
	ci.draw_arc(_stick_mitte, STICK_R, 0.0, TAU, 56, Color(LICHT, 0.9 if aktiv else 0.55), 4.0)
	var knopf := _stick_mitte + Vector2(_stick_aus.x, -_stick_aus.y) * STICK_R
	ci.draw_circle(knopf + Vector2(0, 3), 38.0, Color(0, 0, 0, 0.35))
	ci.draw_circle(knopf, 38.0, Color(LICHT, 0.6 if aktiv else 0.32))
	ci.draw_arc(knopf, 38.0, 0.0, TAU, 40, Color(Color.WHITE, 0.95 if aktiv else 0.6), 3.0)


## Klammern um den Gegner, auf den Brakk gerade selbst schießt.
func _male_auto_ziel(ci: Control) -> void:
	var g := ego._auto_ziel
	if g == null or not is_instance_valid(g):
		return
	var kam := ego.hd.kamera
	var c := ego._zu3d(g.position, (ego.hd.H if ego.hd.ist_hoch(spiel.karte.zelle_bei(g.position)) else 0.0) + 0.42)
	if kam.is_position_behind(c):
		return
	var m := kam.unproject_position(c)
	var r := clampf(260.0 / maxf(1.0, kam.global_position.distance_to(c)), 16.0, 48.0)
	var farbe := Color("ffb347")
	for ecke: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		var p := m + ecke * r
		ci.draw_line(p, p - Vector2(ecke.x * r * 0.45, 0), farbe, 3.0)
		ci.draw_line(p, p - Vector2(0, ecke.y * r * 0.45), farbe, 3.0)


## Vorschau beim Zielen: Ziel am Ort (leuchtende Raute) oder rotes Kreuz mit Grund in der Mitte.
func _male_vorschau(ci: Control, id: String) -> void:
	var kam := ego.hd.kamera
	var ziel := Vector3.INF
	var name := ""
	var fehlt := ""
	var f := ego.brakk.fortschritt
	var farbe := ego._ring_farbe(f.aktiv()) if f != null and f.aktiv() != "" else LICHT
	match id:
		"treppe":
			if ego.brakk.oben:
				var b := ego._bruecke_ziel()
				if not b.is_empty():
					ziel = ego._zu3d(b[2], ego.hd.H)
					name = "Lichtbrücke"
				else:
					name = "Hinunter"
			else:
				var t := ego._treppe_ziel()
				if not t.is_empty():
					ziel = ego._zu3d(spiel.karte.mitte(t[0]), ego.hd.H)
					name = "Lichttreppe"
				else:
					fehlt = "Auf einen Erdwall zielen (bis %d Felder)" % int(EgoModus.TREPPE_WEITE)
		"anker":
			var a := [ego._haken_p, Karte.KEINE] if ego._haken >= 0.0 else ego._anker_ziel()   # 19.11.: hängt er, zeigt der Knopf zum Haken
			if not a.is_empty():
				ziel = a[0]
				name = "Lichtanker"
			else:
				fehlt = "Mauerkrone oder Boden (bis %d Felder)" % int(EgoModus.ANKER_WEITE)
		"saeule":
			var p := ego.ziel_welt()
			if p.x < -9000.0 or p.distance_to(ego._fuss2d()) > EgoModus.SAEULE_WEITE * Werte.ZELLE:
				fehlt = "Zu weit (bis %d Felder)" % int(EgoModus.SAEULE_WEITE)
			else:
				name = "Lichtsäule"
	var mitte := Vector2(640, 360)
	if ziel != Vector3.INF and not kam.is_position_behind(ziel):
		var m := kam.unproject_position(ziel)
		var t := Time.get_ticks_msec() / 1000.0
		var r := 22.0 + 4.0 * sin(t * 8.0)
		var raute := PackedVector2Array([m + Vector2(0, -r), m + Vector2(r, 0), m + Vector2(0, r), m + Vector2(-r, 0), m + Vector2(0, -r)])
		ci.draw_polyline(raute, farbe, 4.0)
		ci.draw_circle(m, 6.0, Color(farbe, 0.8))
		_gestrichelt(ci, Vector2(640, 700), m, Color(farbe, 0.55))
		_text(ci, m + Vector2(0, -r - 16.0), name, 20, Color.WHITE)
	elif fehlt != "":
		ci.draw_line(mitte + Vector2(-14, -14), mitte + Vector2(14, 14), ROT, 4.0)
		ci.draw_line(mitte + Vector2(-14, 14), mitte + Vector2(14, -14), ROT, 4.0)
		_text(ci, mitte + Vector2(0, 44), fehlt, 20, ROT)
	elif name != "":
		_text(ci, mitte + Vector2(0, 44), name, 20, Color.WHITE)


func _gestrichelt(ci: Control, a: Vector2, b: Vector2, farbe: Color) -> void:
	var lang := a.distance_to(b)
	var schritt := 18.0
	var i := 0.0
	var phase := fmod(Time.get_ticks_msec() / 1000.0 * 60.0, schritt)
	while i + phase < lang:
		var von := a.lerp(b, (i + phase) / lang)
		var bis := a.lerp(b, minf(i + phase + schritt * 0.5, lang) / lang)
		ci.draw_line(von, bis, farbe, 3.0)
		i += schritt


## Abklingen (0 = bereit) und ob die Fähigkeit schon frei ist.
func _zustand(id: String) -> Array:
	var f := ego.brakk.fortschritt
	match id:
		"lanze":
			return [ego._lanze_rest / EgoModus.LANZE_ABKLING, f == null or f.frei("lanze")]
		"tumble":
			return [ego._tumble_rest / EgoModus.TUMBLE_ABKLING, f == null or f.frei("tumble")]
		"anker":
			return [ego._anker_rest / EgoModus.ANKER_ABKLING, f == null or f.frei("anker")]
		"saeule":
			return [ego._saeule_rest / EgoModus.SAEULE_ABKLING, f == null or f.frei("saeule")]
		"zeitlupe":
			return [ego._zeitlupe_rest / EgoModus.ZEITLUPE_ABKLING, f == null or f.frei("zeitlupe")]
		"ulti":
			return [ego._ulti_rest(), f == null or f.frei("ulti")]
		"treppe":
			var cd := ego._bruecke_cd / EgoModus.BRUECKE_ABKLING if ego.brakk.oben else ego.brakk.e_rest / maxf(1.0, float(ego.brakk.daten["kletter_abklingzeit"]))
			return [cd, true]
	return [0.0, true]


## Knopf zeichnen – am Handy kräftig (18.11., Paul): dunkler Grund, Leuchtrand, große Glyphe mit Schatten, Beschriftung
## mit Schatten. Bereit leuchtet, Abklingen läuft als dunkler Kreisbogen mit Sekunden, gesperrt grau mit Stufe.
func _male_knopf(ci: Control, k: Array) -> void:
	var id: String = k[0]
	var m: Vector2 = k[1]
	var r: float = k[2]
	var z := _zustand(id)
	var rest := clampf(float(z[0]), 0.0, 1.0)
	var offen := bool(z[1])
	var bereit := offen and rest <= 0.0
	var gedrueckt := false
	for f: int in _knopf:
		gedrueckt = gedrueckt or str(_knopf[f]["id"]) == id
	var farbe := LICHT if bereit else (Color(0.78, 0.82, 0.88) if offen else Color(0.52, 0.55, 0.6))
	if id == "ulti" and bereit:
		farbe = Color("c9a6ff")
	if id == "aktion" or id == "bauliste":
		farbe = Stil.GOLD
	if id == "lanze" and ego._lanze >= 0.0:
		farbe = Color("ffb347")
	if gedrueckt:
		m += Vector2(0, 2)
	# Schatten, Grund, Innenschein
	ci.draw_circle(m + Vector2(0, 4), r, Color(0, 0, 0, 0.45))
	ci.draw_circle(m, r, Color(0.03, 0.04, 0.07, 0.86 if gedrueckt else 0.78))
	if bereit:
		ci.draw_circle(m, r * 0.86, Color(farbe, 0.16 if not gedrueckt else 0.3))
		var puls := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 260.0)
		ci.draw_arc(m, r + 4.0, 0.0, TAU, 56, Color(farbe, 0.22 + 0.18 * puls), 6.0)   # Leuchten: bereit
	if offen and rest > 0.0:
		ci.draw_arc(m, r - 6.0, -PI / 2.0, -PI / 2.0 + TAU * rest, 48, Color(0, 0, 0, 0.7), 10.0)
	if id == "lanze" and ego._lanze >= 0.0:
		ci.draw_arc(m, r + 7.0, -PI / 2.0, -PI / 2.0 + TAU * ego._glut(), 56, Color("ffb347"), 8.0)   # lädt
	ci.draw_arc(m, r, 0.0, TAU, 56, Color(farbe, 1.0 if offen else 0.7), 6.0 if gedrueckt else 4.0)
	# Symbol
	var glyphe: String = k[3]
	var px := 8.0 if r >= 55.0 else (6.0 if r >= 40.0 else 5.0)
	var sym := m - Vector2(0, 2)
	if glyphe != "":
		ego._glyphe(glyphe, sym + Vector2(2, 3), px, Color(0, 0, 0, 0.75))
		ego._glyphe(glyphe, sym, px, farbe.lightened(0.15) if bereit else farbe)
	elif id == "ring":
		var f := ego.brakk.fortschritt
		ego._male_ring(ci, m, 17.0, f.ringe[clampi(f.gewaehlt, 0, f.ringe.size() - 1)])
	if offen and rest > 0.0 and _sek_rest(id) > 0.0:
		_text(ci, m + Vector2(0, r * 0.5), "%d" % ceili(_sek_rest(id)), 20, Color.WHITE)
	# Beschriftung
	if id == "aktion":
		_text(ci, m, _aktion_text(), 20, Color.WHITE)
	elif id == "weg":
		_text(ci, m, "Abbruch" if ego._feld_zielt else "Weglegen", 16, Color.WHITE)
	elif id == "feld" or id == "bauliste" or id == "sprung":
		_text(ci, m, str(k[4]), 18, Color.WHITE)
	elif not offen:
		_text(ci, m + Vector2(0, r + 14.0), "ab St.%d" % int(BrakkFortschritt.AB[id]), 16, Color(0.75, 0.78, 0.84))
	else:
		_text(ci, m + Vector2(0, r + 14.0), ("Ziehen" if id == "anker" and ego._haken >= 0.0 else str(k[4])) if not (id == "treppe" and ego.brakk.oben) else "Brücke", 16, Color.WHITE)


## Text mit dunklem Schatten – auf hellem Gras und Himmel lesbar.
func _text(ci: Control, mitte: Vector2, text: String, groesse: int, farbe: Color) -> void:
	Stil.schreibe_mittig(ci, mitte + Vector2(2, 2), text, groesse, Color(0, 0, 0, 0.85))
	Stil.schreibe_mittig(ci, mitte, text, groesse, farbe)


func _sek_rest(id: String) -> float:
	match id:
		"lanze":
			return ego._lanze_rest
		"tumble":
			return ego._tumble_rest
		"anker":
			return ego._anker_rest
		"saeule":
			return ego._saeule_rest
		"zeitlupe":
			return ego._zeitlupe_rest
		"treppe":
			return ego._bruecke_cd if ego.brakk.oben else ego.brakk.e_rest
	return 0.0
