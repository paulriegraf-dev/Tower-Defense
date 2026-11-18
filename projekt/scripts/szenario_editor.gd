class_name SzenarioEditor
extends Node
## 18.11.: Szenario-Editor (Startmenü → Sandbox → Szenario bauen). Läuft in main.gd als eigener Modus in der Draufsicht,
## ohne Wellen. Links das Mod-HUD (ModLeiste) mit vier Reitern:
##   Karte   – malen per Klick und Ziehen (Rechtsklick radiert): Fels, Wasser, Erdwall (vorgebaut), Mauer für
##             „Mauern fest“, Turm/Fabrik (vorgebaut), Basis, Checkpoint 1/2 (fest oder Bereich), Kartengröße.
##   Regeln  – Name, Beschreibung, Einführung, Startbudget, Startleben, Runden, erlaubte Bauten, Herausforderung.
##   Wellen  – eigene Welle je Runde im Taktikplaner (laufband.gd); Runden ohne Plan laufen mit der entworfenen Welle.
##   Datei   – prüfen, speichern (user://karten/), testen, laden, neu, exportieren; Import: Datei ins Fenster ziehen.
## Der Entwurf ist ein Karten-Wörterbuch wie karten/<name>.json (plus regeln, wellen, stand) und überlebt den
## Neuaufbau der Szene (Größenwechsel, Laden, „Szenario testen“ und zurück).

const Stil := preload("res://scripts/ui/ui_stil.gd")
const GROESSEN := [[20, 10], [28, 14], [36, 16]]
const RUNDEN := [10, 15, 20]
const WERKZEUGE := [["fels", "Fels"], ["wasser", "Wasser"], ["wall", "Erdwall"], ["fest", "Mauer fest"],
	["turm", "Turm"], ["fabrik", "Fabrik"], ["basis", "Basis"], ["cp0", "Checkpoint 1"], ["cp1", "Checkpoint 2"]]
## 18.11. (Etappe 2): Gelände mit Wirkung – begehbar, mit Regeln (Werte, Abschnitt „Gelände mit Wirkung“)
const BODEN_WERKZEUGE := [["anhoehe", "Anhöhe"], ["sumpf", "Sumpf"], ["bruecke", "Brücke"], ["ruine", "Ruine"], ["wald", "Wald"], ["erz", "Erzader"], ["eis", "Eis"], ["minen", "Minenfeld"]]
const ZIEHEN := ["fels", "wasser", "wall", "fest", "anhoehe", "sumpf", "bruecke", "ruine", "wald", "erz", "eis", "minen"]   # diese Werkzeuge malen beim Ziehen weiter
const RUECKGAENGIG_MAX := 60
const TIPPS := {
	"fels": "Fels: für niemanden begehbar, nicht bebaubar, versperrt die Sicht.",
	"wasser": "Wasser: nicht begehbar, nicht bebaubar, Sicht frei.",
	"wall": "Erdwall der Karte: steht ab Runde 1, ausbaubar, nicht abreißbar.",
	"fest": "Mauer für die Herausforderung „Mauern fest“ (lila). Gilt nur, wenn diese Herausforderung läuft.",
	"turm": "Klick auf einen Erdwall der Karte: vorgebauter Turm (die Form der Wälle bestimmt die Art).",
	"fabrik": "Vorgebaute Fabrik. Nochmal klicken wechselt die Truppe.",
	"basis": "Klick setzt die Basis (3×2 Felder). Fest oder zufällig siehe unten.",
	"cp0": "Checkpoint 1 (näher am Gegner). Fest: Klick. Bereich: Rechteck ziehen.",
	"cp1": "Checkpoint 2. Fest: Klick. Bereich: Rechteck ziehen.",
	"anhoehe": "Anhöhe: +1 Reichweite für Truppen, Stellungen und Türme darauf – auch für Gegner. Bebaubar.",
	"sumpf": "Sumpf: Gegner und Truppen laufen mit 70 % Tempo (mit Frost nie unter 45 %). Nicht bebaubar.",
	"bruecke": "Brücke: nur auf Wasser. Begehbar, nicht bebaubar – ein Durchgang, den niemand zumauert.",
	"ruine": "Ruine: Truppen darauf nehmen 25 % weniger Fernschaden. Nur Erdwälle, die kosten dort 5.",
	"wald": "Wald: versperrt die Sicht wie Fels (hinein geht). Truppen darin sieht eine Sphäre erst aus 2 Feldern. Nicht bebaubar.",
	"erz": "Erzader: Fabrik oder Turm darauf bringt +10 Budget je Runde.",
	"eis": "Eis: Gegner und Truppen laufen mit 125 % Tempo. Bebaubar.",
	"minen": "Minenfeld: Der erste Gegner darauf nimmt einmal 40 Schaden; zur nächsten Runde liegt die Mine wieder. Nicht bebaubar.",
}
const FABRIK_TRUPPEN := ["technogunner", "scharfschuetze", "plasmawerfer"]
const FEHLER_FARBE := Color("ff3b3b")
const FEST_FARBE := Color("b07cff")

static var entwurf: Dictionary = {}     # die Karte, an der gerade gebaut wird
static var datei := ""                   # Name unter user://karten/ (ohne .json); "" = noch nie gespeichert
static var testet := false               # läuft gerade „Szenario testen“? Dann führt „Hauptmenü“ zurück in den Editor

var spiel: Node
var _leiste: ModLeiste
var _ebene: CanvasLayer
var _marken: Marken
var _reiter := "karte"
var _werkzeug := "fels"
var _strich := 0                         # 1 = malt, -1 = radiert, 0 = nichts
var _letzte := Karte.KEINE
var _bereich_von := Karte.KEINE          # Checkpoint-Bereich: Ecke, an der das Ziehen begann
var _bereich_bis := Karte.KEINE
var _mauern_fest: Dictionary = {}        # Feld -> true
var _fehler: Dictionary = {}             # Feld -> true (rot auf der Karte)
var _meldungen: PackedStringArray = []
var _geprueft := false
var _ok := false
var _runde := 1
var _plaene: Dictionary = {}             # Runde -> Trupps (der Taktikplaner bearbeitet diese Listen direkt)
var _text_ebene: CanvasLayer = null
var _symmetrie := false                  # 18.11.: Symmetrie-Pinsel – malt gespiegelt an der Mittelzeile mit
var _rueckgaengig: Array[String] = []    # 18.11.: frühere Stände des Entwurfs (JSON), der letzte = vor dem letzten Schritt


# ------------------------------------------------------------ Entwurf (statisch, überlebt den Szenenwechsel)

static func neuer_entwurf(spalten: int = 28, zeilen: int = 14) -> Dictionary:
	var d := Werte.karten_vorlage(spalten, zeilen)
	d["regeln"] = {"start_budget": Werte.STANDARD_BUDGET, "start_leben": Werte.STANDARD_LEBEN, "runden": Werte.STANDARD_RUNDEN,
		"bauten": {}, "herausforderung": "", "einfuehrung": ""}
	d["wellen"] = {}
	d["stand"] = {}
	return d


## Vor dem Aufbau der Karte (main._ready): den Entwurf als aktuelle Karte einstellen.
static func uebernimm() -> void:
	if entwurf.is_empty():
		entwurf = neuer_entwurf()
	Werte.karte_gross = true
	Werte.uebernimm_karte("editor", entwurf)
	Werte.KARTE_STAND = {}   # vorgebaute Türme/Fabriken stellt der Editor selbst hin (_setze_stand)
	Werte.KARTE_BASIS_FEST = true
	Werte.KARTE_CP_FEST = true
	# 18.11.: der Editor arbeitet in der Draufsicht. Nur die Schalter umstellen, nicht Werte.grafik – sonst würde
	# die nächste gespeicherte Einstellung (z. B. bei „Szenario testen“) HD-2D dauerhaft abschalten.
	if Werte.grafik_hd:
		Werte.grafik_hd = false
		Werte.grafik_neu = true


## Name für eine neue Datei: eigen_<name>, bei Gleichstand mit Zahl.
static func freier_name(titel: String) -> String:
	var kurz := ""
	for c in titel.to_lower():
		if (c >= "a" and c <= "z") or (c >= "0" and c <= "9"):
			kurz += c
		elif c in ["ä", "ö", "ü", "ß"]:
			kurz += {"ä": "ae", "ö": "oe", "ü": "ue", "ß": "ss"}[c]
		elif not kurz.ends_with("_"):
			kurz += "_"
	kurz = kurz.strip_edges().trim_suffix("_").trim_prefix("_").left(24)
	if kurz == "":
		kurz = "szenario"
	var kname := "eigen_" + kurz
	var n := 2
	while FileAccess.file_exists(Werte.EIGENE_KARTEN + kname + ".json"):
		kname = "eigen_%s_%d" % [kurz, n]
		n += 1
	return kname


static func speichere_datei(kname: String, d: Dictionary) -> bool:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(Werte.EIGENE_KARTEN))
	var f := FileAccess.open(Werte.EIGENE_KARTEN + kname + ".json", FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(d, "\t"))
	f.close()
	return true


## Import (Datei ins Fenster gezogen, auch im Browser): prüfen und als eigene Karte ablegen. Gibt den Namen zurück
## (leer = ging nicht; `grund` bekommt dann den Grund).
static func importiere(pfad: String, grund: Array) -> String:
	if not pfad.to_lower().ends_with(".json"):
		grund.append("Nur .json-Dateien (Export aus dem Szenario-Editor).")
		return ""
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(pfad))
	if not (d is Dictionary):
		grund.append("Die Datei ist keine Karte.")
		return ""
	var fehler := Werte.karte_gueltig(d)
	if fehler != "":
		grund.append("Die Karte lässt sich nicht laden: " + fehler)
		return ""
	var kname := freier_name(str((d as Dictionary).get("name", "import")))
	if not speichere_datei(kname, d):
		grund.append("Speichern ging nicht.")
		return ""
	return kname


# ------------------------------------------------------------ Aufbau

func einrichten(s: Node) -> void:
	spiel = s
	_mauern_fest = {}
	for z: Vector2i in Werte.MAUERN_FEST:
		_mauern_fest[z] = true
	_plaene = {}
	for nr: int in Werte.KARTE_WELLEN:
		_plaene[nr] = (Werte.KARTE_WELLEN[nr] as Array).duplicate(true)
	var karte: Karte = spiel.karte
	karte.cp_aktiv = false
	karte.cp_route = true
	spiel.setze_checkpoints(entwurf["checkpoints"])
	karte.basis = Werte.BASIS_ZELLE
	var st: Variant = entwurf.get("stand", {})
	if st is Dictionary and not (st as Dictionary).is_empty():
		spiel._setze_stand(st)
	spiel.setze_kartenmauern()
	karte.aktualisiere_pfad()
	spiel._hud.visible = false
	spiel.budget = 0
	_ebene = CanvasLayer.new()
	_ebene.layer = 20
	add_child(_ebene)
	_leiste = ModLeiste.new()
	_leiste.inhalt = _baue_leiste
	_leiste.vor_klick = _merke_stand   # 18.11.: jeder Klick in der Leiste ist ein Schritt für „Rückgängig“
	_leiste.breite = 156.0
	_leiste.oben = 6.0
	_ebene.add_child(_leiste)
	var streifen := Meldung.new()
	streifen.spiel = spiel
	_ebene.add_child(streifen)
	_marken = Marken.new()
	_marken.ed = self
	_marken.z_index = 50
	spiel.add_child(_marken)
	var lb: Laufband = spiel._laufband
	lb.ohne_budget = true
	lb.visible = false
	spiel.get_window().files_dropped.connect(_dateien_fallen)
	spiel.melde("Szenario-Editor: links Werkzeug wählen, auf der Karte malen (Rechtsklick radiert). Mausrad/Pfeiltasten: Karte schwenken.", 8.0)


func _exit_tree() -> void:
	if spiel != null and spiel.get_window().files_dropped.is_connected(_dateien_fallen):
		spiel.get_window().files_dropped.disconnect(_dateien_fallen)


func _process(_delta: float) -> void:
	var kam: Kamera2D = spiel.kamera_2d
	if kam != null and kam.sicht_links == 0.0:
		# Die Leiste links verdeckt einen Streifen: die Karte daneben einpassen (ganze Karte)
		kam.sicht_links = (_leiste.breite + 10.0) * Stil.UI_SKALA
		kam.sicht = Vector2(1280.0 - kam.sicht_links - 56.0, 700.0)   # rechts bleibt der Zoom-Regler frei
		kam._ziel_zoom = kam._ganz()
		kam.zoom = Vector2.ONE * kam._ziel_zoom
	var lb: Laufband = spiel._laufband
	if _reiter != "wellen" and lb.visible:
		lb.visible = false
	_leiste.visible = _text_ebene == null


# ------------------------------------------------------------ Leiste

func _baue_leiste(l: ModLeiste) -> void:
	l.kopf("Szenario: " + str(entwurf.get("name", "")).left(18))
	l.reiter([["karte", "Karte"], ["regeln", "Regeln"], ["wellen", "Wellen"], ["datei", "Datei"]], _reiter, _zeige_reiter)
	match _reiter:
		"karte":
			_leiste_karte(l)
		"regeln":
			_leiste_regeln(l)
		"wellen":
			_leiste_wellen(l)
		"datei":
			_leiste_datei(l)


func _zeige_reiter(r: String) -> void:
	_reiter = r
	if r == "wellen":
		_zeige_plan()


func _leiste_karte(l: ModLeiste) -> void:
	l.abschnitt("Werkzeug (Rechtsklick radiert)")
	l.chips(WERKZEUGE, _werkzeug, func(w: String) -> void: _werkzeug = w)
	l.abschnitt("Gelände mit Wirkung")
	l.chips(BODEN_WERKZEUGE, _werkzeug, func(w: String) -> void: _werkzeug = w)
	l.text(str(TIPPS.get(_werkzeug, "")))
	l.schalter("Symmetrie-Pinsel (oben = unten)", _symmetrie, func() -> void: _symmetrie = not _symmetrie)
	l.knopf("Rückgängig [Strg+Z]" + ("" if not _rueckgaengig.is_empty() else " – nichts da"), _zuruck, Stil.TEXT if not _rueckgaengig.is_empty() else Stil.TEXT_BLASS)
	l.trenner()
	l.abschnitt("Basis")
	l.chips([[true, "fest"], [false, "zufällig"]], bool(entwurf.get("basis_fest", false)), func(f: bool) -> void:
		entwurf["basis_fest"] = f
		_geaendert())
	l.abschnitt("Checkpoints")
	l.chips([[true, "fest"], [false, "Bereich"]], bool(entwurf.get("checkpoints_fest", false)), func(f: bool) -> void:
		entwurf["checkpoints_fest"] = f
		_geaendert())
	l.trenner()
	l.abschnitt("Kartengröße")
	var liste: Array = []
	for g: Array in GROESSEN:
		liste.append(["%dx%d" % g, "%d×%d" % g])
	l.chips(liste, "%dx%d" % [Werte.SPALTEN, Werte.ZEILEN], _frage_groesse)
	_zeige_pruefung(l)


func _leiste_regeln(l: ModLeiste) -> void:
	var r: Dictionary = entwurf["regeln"]
	l.knopf("Name: " + str(entwurf.get("name", "")).left(22), _bearbeite_text.bind("name", "Name des Szenarios", false))
	l.knopf("Beschreibung …", _bearbeite_text.bind("beschreibung", "Beschreibung (steht in der Kartenwahl)", true))
	l.knopf("Einführung …", _bearbeite_text.bind("einfuehrung", "Einführung (erscheint zu Spielbeginn)", true))
	l.trenner()
	l.zeile("Startbudget", str(int(r.get("start_budget", Werte.STANDARD_BUDGET))), func(d: int) -> void:
		r["start_budget"] = clampi(int(r.get("start_budget", Werte.STANDARD_BUDGET)) + ModLeiste.schritt(d) * 10, 0, 99990)
		_geaendert(), int(r.get("start_budget", Werte.STANDARD_BUDGET)) != Werte.STANDARD_BUDGET)
	l.zeile("Startleben", str(int(r.get("start_leben", Werte.STANDARD_LEBEN))), func(d: int) -> void:
		r["start_leben"] = clampi(int(r.get("start_leben", Werte.STANDARD_LEBEN)) + ModLeiste.schritt(d), 1, 999)
		_geaendert(), int(r.get("start_leben", Werte.STANDARD_LEBEN)) != Werte.STANDARD_LEBEN)
	l.abschnitt("Runden (die letzte = Gegenangriff)")
	var runden: Array = []
	for n: int in RUNDEN:
		runden.append([n, str(n)])
	l.chips(runden, int(r.get("runden", Werte.STANDARD_RUNDEN)), func(n: int) -> void:
		r["runden"] = n
		_geaendert())
	l.abschnitt("Erlaubte Bauten (Klick schaltet)")
	var bauten: Array = []
	var an: Array = []
	var gesperrt: Dictionary = r.get("bauten", {})
	for typ: int in spiel.BAUTEN:
		var e: Array = spiel.BAUTEN[typ]
		bauten.append([e[0], e[1]])
		if bool(gesperrt.get(e[0], true)):
			an.append(e[0])
	l.chips(bauten, an, func(schl: String) -> void:
		var b: Dictionary = r.get("bauten", {})
		if bool(b.get(schl, true)):
			b[schl] = false
		else:
			b.erase(schl)
		r["bauten"] = b
		_geaendert())
	l.abschnitt("Herausforderung (voreingestellt)")
	var hf: Array = []
	for h: Array in Werte.HERAUSFORDERUNGEN:
		hf.append([h[0], h[1]])
	l.chips(hf, str(r.get("herausforderung", "")), func(h: String) -> void:
		r["herausforderung"] = h
		_geaendert())


func _leiste_wellen(l: ModLeiste) -> void:
	var letzte := int(entwurf["regeln"].get("runden", Werte.STANDARD_RUNDEN))
	_runde = clampi(_runde, 1, letzte)
	l.zeile("Runde", "%d/%d" % [_runde, letzte], func(d: int) -> void:
		_runde = clampi(_runde + ModLeiste.schritt(d), 1, letzte)
		_zeige_plan(), _plaene.has(_runde) and not (_plaene[_runde] as Array).is_empty())
	var eigen: bool = _plaene.has(_runde) and not (_plaene[_runde] as Array).is_empty()
	if eigen:
		l.text("Eigene Welle: " + Phantom.plan_text(_plaene[_runde]), Stil.TEXT)
	else:
		l.text("Ohne eigenen Plan: entworfene Welle „%s“." % str(Werte.wellen_plan(_runde)["name"]))
	if _runde == letzte:
		l.text("Letzte Runde: Nach der Welle fällt der Schild – Gegenangriff, die Welle läuft in Schleife.", Stil.KUPFER)
	l.knoepfe([["Planer zeigen", _zeige_plan], ["Plan löschen", _loesche_plan, Stil.WARN]])
	var mit: Array = []
	for nr: int in _plaene:
		if not (_plaene[nr] as Array).is_empty():
			mit.append(nr)
	mit.sort()
	var mit_text := PackedStringArray()
	for nr: int in mit:
		mit_text.append(str(nr))
	l.text("Runden mit eigenem Plan: " + (", ".join(mit_text) if not mit.is_empty() else "keine"))
	l.text("Im Planer: Einheit unten anklicken = in den Trupp, Kärtchen ziehen = Pause, „Vorlage“ = entworfene Welle. Würfe zielen selbst.")


func _leiste_datei(l: ModLeiste) -> void:
	l.knoepfe([["Prüfen", _pruefe_knopf], ["Speichern", _speichern]])
	l.knoepfe([["Szenario testen", _testen, Stil.GOLD]])
	l.text(("Datei: " + datei) if datei != "" else "Noch nicht gespeichert.")
	l.knoepfe([["Exportieren", _exportieren], ["Neu", _frage_neu, Stil.WARN]])
	l.text("Import: eine exportierte .json-Datei ins Fenster ziehen.")
	var eigene := Werte.eigene_karten()
	if not eigene.is_empty():
		l.abschnitt("Laden (Rechtsklick löscht)")
		var liste: Array = []
		for kn: String in eigene:
			liste.append([kn, str(Werte.karten_daten(kn).get("name", kn)).left(16)])
		l.chips(liste, datei, _frage_laden, _frage_loeschen)
	l.trenner()
	l.knopf("Hauptmenü", _hauptmenue, Stil.TEXT_BLASS)
	_zeige_pruefung(l)


func _zeige_pruefung(l: ModLeiste) -> void:
	if not _geprueft:
		return
	l.trenner()
	if _ok:
		l.text("Prüfung bestanden: Alle Wege führen durch die Checkpoints zur Basis.", Color("8fe08f"))
	else:
		for m: String in _meldungen:
			l.text(m, FEHLER_FARBE)


# ------------------------------------------------------------ Malen

func _unhandled_input(event: InputEvent) -> void:
	if _text_ebene != null:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_LEFT and mb.button_index != MOUSE_BUTTON_RIGHT:
			return
		var z: Vector2i = spiel.karte.zelle_bei(spiel.maus_welt(true))
		if mb.pressed:
			if not spiel.karte.in_karte(z):
				return
			_merke_stand()
			_strich = 1 if mb.button_index == MOUSE_BUTTON_LEFT else -1
			_letzte = Karte.KEINE
			if _strich == 1 and _werkzeug.begins_with("cp") and not bool(entwurf.get("checkpoints_fest", false)):
				_bereich_von = z
				_bereich_bis = z
			else:
				_male(z)
		else:
			if _bereich_von != Karte.KEINE:
				_setze_bereich(int(_werkzeug.right(1)), _bereich_von, _bereich_bis)
			_bereich_von = Karte.KEINE
			_strich = 0
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _strich != 0:
		var z: Vector2i = spiel.karte.zelle_bei(spiel.maus_welt(true))
		if _bereich_von != Karte.KEINE:
			if spiel.karte.in_karte(z):
				_bereich_bis = z
		elif _strich == -1 or ZIEHEN.has(_werkzeug):
			_male_linie(z)
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and (event as InputEventKey).keycode == KEY_Z and (event as InputEventKey).is_command_or_control_pressed():
		_zuruck()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).keycode == KEY_ESCAPE:
		if spiel._laufband.visible:
			spiel._laufband.visible = false
			get_viewport().set_input_as_handled()


## 18.11.: Beim schnellen Ziehen liegen zwischen zwei Mausmeldungen mehrere Felder – alle dazwischen mitmalen.
func _male_linie(bis: Vector2i) -> void:
	if _letzte == Karte.KEINE or _letzte == bis:
		_male(bis)
		return
	var von := _letzte
	var n := maxi(absi(bis.x - von.x), absi(bis.y - von.y))
	for i in range(1, n + 1):
		_male(Vector2i((Vector2(von).lerp(Vector2(bis), float(i) / n)).round()))


## 18.11.: Ein Feld malen – mit Symmetrie-Pinsel auch das gespiegelte (nur die Malwerkzeuge, nicht Basis/Checkpoints).
func _male(z: Vector2i) -> void:
	if z == _letzte or not spiel.karte.in_karte(z):
		return
	_letzte = z
	_male_feld(z)
	if _symmetrie and (_strich == -1 or ZIEHEN.has(_werkzeug) or _werkzeug in ["turm", "fabrik"]):
		var s := Vector2i(z.x, Werte.ZEILEN - 1 - z.y)
		if s != z:
			_male_feld(s)


func _male_feld(z: Vector2i) -> void:
	var karte: Karte = spiel.karte
	if z.x < Werte.ZONE_SPALTEN:
		spiel.melde("In der Zone des Gegners (links) liegt nichts – dort stehen HQ und Schleudern.", 3.0)
		return
	if _strich == -1:
		_radiere(z)
		_geaendert()
		return
	var frei_von_basis_und_cp: bool = not karte.ist_basis(z) and not karte.checkpoints.has(z)
	match _werkzeug:
		"fels", "wasser":
			if not frei_von_basis_und_cp:
				spiel.melde("Basis und Checkpoints bleiben frei.", 2.5)
				return
			if karte.feld.has(z):
				spiel.fabriken.erase(z)
				karte.fest.erase(z)
				karte.entferne(z)
				karte.pruefe_stuetzen()
			_mauern_fest.erase(z)
			karte.setze_boden(z, "")
			karte.setze_gelaende(z, _werkzeug)
		"anhoehe", "sumpf", "ruine", "wald", "erz", "eis", "minen":
			if karte.ist_basis(z):
				spiel.melde("Die Basis steht auf normalem Boden.", 2.5)
				return
			if karte.gelaende.has(z):
				karte.setze_gelaende(z, "")
			# was auf dem neuen Boden nicht stehen darf, verschwindet
			var bleibt_wall: bool = not Werte.BODEN_UNBEBAUBAR.has(_werkzeug)
			if karte.feld.has(z) and (not bleibt_wall or karte.inhalt(z) != Karte.WALL or (_werkzeug == "ruine" and karte.ausbau.has(z))):
				spiel.fabriken.erase(z)
				karte.fest.erase(z)
				karte.entferne(z)
				karte.pruefe_stuetzen()
			if not bleibt_wall:
				_mauern_fest.erase(z)
			karte.setze_boden(z, _werkzeug)
		"bruecke":
			if karte.gelaende.get(z, "") != "wasser":
				if karte.boden.get(z, "") != "bruecke":
					spiel.melde("Eine Brücke liegt auf Wasser – erst Wasser malen.", 2.5)
				return
			karte.setze_gelaende(z, "")
			karte.setze_boden(z, "bruecke")
		"wall":
			if not frei_von_basis_und_cp or karte.feld.has(z):
				return
			if Werte.BODEN_UNBEBAUBAR.has(str(karte.boden.get(z, ""))):
				spiel.melde("Auf %s steht kein Erdwall." % str(Werte.BODEN_NAMEN[karte.boden[z]]), 2.5)
				return
			if karte.gelaende.has(z):
				karte.setze_gelaende(z, "")
			karte.setze(z, Karte.WALL)
			karte.fest[z] = true
		"fest":
			if not frei_von_basis_und_cp or Werte.BODEN_UNBEBAUBAR.has(str(karte.boden.get(z, ""))):
				return
			if karte.gelaende.has(z):
				karte.setze_gelaende(z, "")
			_mauern_fest[z] = true
		"turm":
			if karte.inhalt(z) != Karte.WALL:
				spiel.melde("Ein Turm steht auf einem Erdwall der Karte – erst Erdwälle malen.", 3.0)
				return
			if karte.ausbau.get(z, Karte.FREI) == Karte.TURM:
				return
			var grund := karte.ausbau_hindernis(z, Karte.TURM)
			if grund != "":
				spiel.melde(grund, 4.0)
				return
			karte.baue_aus(z, Karte.TURM)
		"fabrik":
			if spiel.fabriken.has(z):
				var f: Dictionary = spiel.fabriken[z]
				var neu: String = FABRIK_TRUPPEN[(FABRIK_TRUPPEN.find(str(f["typ"])) + 1) % FABRIK_TRUPPEN.size()]
				f["typ"] = neu
				karte.fabrik_typ[z] = neu
			elif karte.ist_bebaubar(z) and karte.boden.get(z, "") != "ruine":
				karte.setze(z, Karte.FABRIK)
				spiel.fabriken[z] = {"timer": 0.0, "einheiten": [], "typ": FABRIK_TRUPPEN[0], "stufe": 0}
				karte.fabrik_typ[z] = FABRIK_TRUPPEN[0]
			else:
				spiel.melde("Hier ist kein Platz für eine Fabrik.", 2.5)
				return
		"basis":
			if not spiel.setze_basis(z):
				spiel.melde("Die Basis (3×2 Felder) passt hier nicht: Alle Felder müssen frei sein.", 3.0)
				return
		"cp0", "cp1":
			var i := int(_werkzeug.right(1))
			if karte.feld.has(z) or karte.gelaende.has(z) or karte.ist_basis(z) or karte.checkpoints.has(z) or _mauern_fest.has(z):
				spiel.melde("Der Checkpoint braucht ein freies Feld.", 2.5)
				return
			karte.checkpoints[i] = z
			karte.aktualisiere_pfad()
	_geaendert()


func _radiere(z: Vector2i) -> void:
	var karte: Karte = spiel.karte
	if karte.gelaende.has(z):
		karte.setze_gelaende(z, "")
	if karte.boden.has(z):
		karte.setze_boden(z, "")
	_mauern_fest.erase(z)
	if karte.feld.has(z):
		if karte.ausbau.get(z, Karte.FREI) == Karte.TURM:
			karte.entferne(z)   # erst der Turm: der Erdwall bleibt stehen
			karte.setze(z, Karte.WALL)
			karte.fest[z] = true
		else:
			spiel.fabriken.erase(z)
			karte.fest.erase(z)
			karte.entferne(z)
		karte.pruefe_stuetzen()


## Checkpoint-Bereich aus zwei Ecken. Der feste Ersatz-Checkpoint (falls das Würfeln nichts findet) rückt hinein.
func _setze_bereich(i: int, a: Vector2i, b: Vector2i) -> void:
	var von := Vector2i(maxi(mini(a.x, b.x), Werte.ZONE_SPALTEN), mini(a.y, b.y))
	var bis := Vector2i(maxi(a.x, b.x), maxi(a.y, b.y))
	if bis.x < von.x:
		return
	var bereiche: Array = entwurf["checkpoint_bereiche"]
	bereiche[i] = [von.x, von.y, bis.x - von.x + 1, bis.y - von.y + 1]
	var karte: Karte = spiel.karte
	var r := Rect2i(von, bis - von + Vector2i.ONE)
	if not r.has_point(karte.checkpoints[i]):
		var m := r.position + r.size / 2
		for d in maxi(r.size.x, r.size.y):
			var gefunden := false
			for y in range(m.y - d, m.y + d + 1):
				for x in range(m.x - d, m.x + d + 1):
					var z := Vector2i(x, y)
					if r.has_point(z) and karte.ist_bebaubar(z) and not _mauern_fest.has(z):
						karte.checkpoints[i] = z
						gefunden = true
						break
				if gefunden:
					break
			if gefunden:
				break
		karte.aktualisiere_pfad()
	_geaendert()


func _geaendert() -> void:
	_geprueft = false
	_fehler.clear()


# ------------------------------------------------------------ Rückgängig (18.11.)

## Stand vor einem Schritt merken (Strich auf der Karte, Klick in der Leiste). Gleiche Stände zählen nicht doppelt.
func _merke_stand() -> void:
	_sammle()
	var jetzt := JSON.stringify(entwurf)
	if not _rueckgaengig.is_empty() and _rueckgaengig[-1] == jetzt:
		return
	_rueckgaengig.append(jetzt)
	if _rueckgaengig.size() > RUECKGAENGIG_MAX:
		_rueckgaengig.remove_at(0)


func _zuruck() -> void:
	_sammle()
	var jetzt := JSON.stringify(entwurf)
	while not _rueckgaengig.is_empty() and _rueckgaengig[-1] == jetzt:
		_rueckgaengig.pop_back()   # der Klick auf „Rückgängig“ selbst hat den aktuellen Stand gemerkt
	if _rueckgaengig.is_empty():
		spiel.melde("Nichts mehr rückgängig zu machen.", 2.0)
		return
	var d: Variant = JSON.parse_string(_rueckgaengig.pop_back())
	if d is Dictionary:
		_stelle_her(d)
		spiel.melde("Rückgängig.", 1.5)


## Die Karte auf einen gemerkten Stand zurücksetzen – ohne die Szene neu aufzubauen (gleiche Größe).
func _stelle_her(d: Dictionary) -> void:
	var karte: Karte = spiel.karte
	entwurf = d
	for z: Vector2i in karte.gelaende.keys():
		karte.setze_gelaende(z, "")
	for z: Vector2i in karte.boden.keys():
		karte.setze_boden(z, "")
	for z: Vector2i in karte.feld.keys():
		karte.entferne(z)
	spiel.fabriken.clear()
	karte.fest.clear()
	for art: String in ["fels", "wasser"]:
		for p: Array in d.get(art, []):
			karte.setze_gelaende(Vector2i(int(p[0]), int(p[1])), art)
	for art: String in Werte.BODEN_ARTEN:
		for p: Array in d.get(art, []):
			karte.setze_boden(Vector2i(int(p[0]), int(p[1])), art)
	var st: Variant = d.get("stand", {})
	if st is Dictionary and not (st as Dictionary).is_empty():
		spiel._setze_stand(st)
	var mauern: Array[Vector2i] = []
	for p: Array in d.get("mauern", []):
		mauern.append(Vector2i(int(p[0]), int(p[1])))
	spiel.setze_kartenmauern(mauern)
	for z: Vector2i in karte.feld:
		karte.fest[z] = true
	_mauern_fest = {}
	for p: Array in d.get("mauern_fest", []):
		_mauern_fest[Vector2i(int(p[0]), int(p[1]))] = true
	var b: Array = d["basis"]
	karte.basis = Vector2i(int(b[0]), int(b[1]))
	spiel.setze_checkpoints(d["checkpoints"])
	_plaene = {}
	var w: Variant = d.get("wellen", {})
	if w is Dictionary:
		for nr: Variant in w:
			_plaene[int(nr)] = (w[nr] as Array).duplicate(true)
	karte.aktualisiere_pfad()
	_geaendert()
	if _reiter == "wellen" and spiel._laufband.visible:
		_zeige_plan()


# ------------------------------------------------------------ Entwurf zusammenstellen

## Aktuellen Stand der Karte in den Entwurf schreiben.
func _sammle() -> void:
	var karte: Karte = spiel.karte
	var fels: Array = []
	var wasser: Array = []
	for z: Vector2i in _sortiert(karte.gelaende.keys()):
		(fels if karte.gelaende[z] == "fels" else wasser).append([z.x, z.y])
	var mauern: Array = []
	var bauten := false
	for z: Vector2i in _sortiert(karte.feld.keys()):
		if karte.feld[z] == Karte.WALL:
			mauern.append([z.x, z.y])
			if karte.ausbau.has(z):
				bauten = true
		elif karte.feld[z] == Karte.FABRIK:
			bauten = true
	var fest: Array = []
	for z: Vector2i in _sortiert(_mauern_fest.keys()):
		fest.append([z.x, z.y])
	entwurf["fels"] = fels
	entwurf["wasser"] = wasser
	for art: String in Werte.BODEN_ARTEN:
		var liste: Array = []
		for z: Vector2i in _sortiert(karte.boden.keys()):
			if karte.boden[z] == art:
				liste.append([z.x, z.y])
		entwurf[art] = liste
	entwurf["mauern"] = mauern
	entwurf["mauern_fest"] = fest
	entwurf["basis"] = [karte.basis.x, karte.basis.y]
	entwurf["checkpoints"] = [[karte.checkpoints[0].x, karte.checkpoints[0].y], [karte.checkpoints[1].x, karte.checkpoints[1].y]]
	# vorgebaute Türme/Fabriken: der ganze Bau (die Erdwälle sind die Stützen der Türme)
	entwurf["stand"] = Phantom._stand(spiel._zellen_jetzt(), {}) if bauten else {}
	var wellen := {}
	for nr: int in _plaene:
		if not (_plaene[nr] as Array).is_empty() and nr <= int(entwurf["regeln"].get("runden", Werte.STANDARD_RUNDEN)):
			wellen[str(nr)] = (_plaene[nr] as Array).duplicate(true)
	entwurf["wellen"] = wellen


static func _sortiert(felder: Array) -> Array:
	felder.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.x < b.x or (a.x == b.x and a.y < b.y))
	return felder


# ------------------------------------------------------------ Prüfung

## Weg von oberem Rand, Mitte und unterem Rand der Zone durch die Checkpoints zur Basis – nur über Gelände, ohne
## Wälle einzureißen (Fels, Wasser, Erdwälle und Fabriken der Karte sperren). Auf einem Raster mit Wegen in vier
## Richtungen heißt das: Start, Checkpoints und Basis liegen im selben zusammenhängenden Stück. Mit Mauer für
## „Mauern fest“ wird zusätzlich auch mit dieser Mauer geprüft. Fehlerfelder werden rot.
func pruefe() -> bool:
	_sammle()
	_fehler.clear()
	_meldungen = []
	var karte: Karte = spiel.karte
	var sperre := {}
	for z: Vector2i in karte.gelaende:
		sperre[z] = true
	for z: Vector2i in karte.feld:
		sperre[z] = true
	# Basis
	var basis_ok := true
	for c: Vector2i in Karte.basis_felder(karte.basis):
		if not karte.in_karte(c) or c.x < Werte.ZONE_SPALTEN or sperre.has(c) or karte.checkpoints.has(c) or _mauern_fest.has(c):
			basis_ok = false
			if karte.in_karte(c):
				_fehler[c] = true
	if not basis_ok:
		_meldungen.append("Die Basis (3×2 Felder) passt nicht: Ihre Felder müssen frei sein und außerhalb der Zone liegen.")
	# Checkpoints
	var fest_cp: bool = bool(entwurf.get("checkpoints_fest", false))
	for i in 2:
		var cp := karte.checkpoints[i]
		if sperre.has(cp) or _mauern_fest.has(cp) or karte.ist_basis(cp) or cp.x < Werte.ZONE_SPALTEN:
			_fehler[cp] = true
			_meldungen.append("Checkpoint %d liegt auf Fels, Wasser, einer Mauer oder der Basis." % (i + 1))
	if not fest_cp:
		for i in 2:
			var b: Array = entwurf["checkpoint_bereiche"][i]
			var r := Rect2i(int(b[0]), int(b[1]), int(b[2]), int(b[3]))
			if r.position.x < Werte.ZONE_SPALTEN or r.end.x > Werte.SPALTEN or r.end.y > Werte.ZEILEN or r.position.y < 0:
				_meldungen.append("Checkpoint-Bereich %d ragt aus der Karte oder in die Zone." % (i + 1))
	for mit_fest: bool in ([false, true] if not _mauern_fest.is_empty() else [false]):
		var s := sperre.duplicate()
		if mit_fest:
			s.merge(_mauern_fest)
		var stueck := _erreichbar(s)
		var wo := " (mit „Mauern fest“)" if mit_fest else ""
		var vorher := _meldungen.size()
		if basis_ok and not stueck.has(karte.basis):
			_fehler[karte.basis] = true
			_meldungen.append("Kein Weg zur Basis%s." % wo)
		for i in 2:
			var cp := karte.checkpoints[i]
			if not s.has(cp) and not stueck.has(cp):
				_fehler[cp] = true
				_meldungen.append("Kein Weg zu Checkpoint %d%s." % [i + 1, wo])
		if not fest_cp:
			for i in 2:
				var b: Array = entwurf["checkpoint_bereiche"][i]
				var frei := 0
				var taschen := 0
				for y in range(int(b[1]), int(b[1]) + int(b[3])):
					for x in range(int(b[0]), int(b[0]) + int(b[2])):
						var z := Vector2i(x, y)
						if not karte.in_karte(z) or s.has(z) or karte.ist_basis(z):
							continue
						frei += 1
						if not stueck.has(z):
							taschen += 1
							_fehler[z] = true
				if frei == 0:
					_meldungen.append("Checkpoint-Bereich %d hat kein freies Feld%s." % [i + 1, wo])
				elif taschen > 0:
					_meldungen.append("Checkpoint-Bereich %d: %d Felder ohne Weg (rot) – dort könnte der Checkpoint landen%s." % [i + 1, taschen, wo])
		if not bool(entwurf.get("basis_fest", false)) and not mit_fest:
			var taschen := 0
			for y in Werte.ZEILEN:
				for x in range(Werte.ZONE_SPALTEN, Werte.SPALTEN):
					var z := Vector2i(x, y)
					if not s.has(z) and not stueck.has(z):
						taschen += 1
						_fehler[z] = true
			if taschen > 0:
				_meldungen.append("%d abgeschlossene Felder (rot): Die zufällige Basis könnte dort landen – Basis fest machen oder öffnen." % taschen)
		if mit_fest:
			# dieselben Fehler wie ohne Mauer nicht doppelt melden
			var neu: PackedStringArray = []
			for i in range(vorher, _meldungen.size()):
				if not _meldungen.has(_meldungen[i].replace(wo, "")):
					neu.append(_meldungen[i])
			_meldungen = _meldungen.slice(0, vorher)
			_meldungen.append_array(neu)
	if _meldungen.is_empty() and str(entwurf.get("name", "")).strip_edges() == "":
		_meldungen.append("Das Szenario braucht einen Namen (Reiter Regeln).")
	_geprueft = true
	_ok = _meldungen.is_empty()
	return _ok


## Alle Felder, die von einem der drei Startpunkte am Zonenrand erreichbar sind (vier Richtungen, `sperre` gesperrt).
func _erreichbar(sperre: Dictionary) -> Dictionary:
	var stueck := {}
	var offen: Array[Vector2i] = [Vector2i(0, 1), Werte.START_ZELLE, Vector2i(0, Werte.ZEILEN - 2)]
	for z: Vector2i in offen:
		stueck[z] = true
	while not offen.is_empty():
		var z: Vector2i = offen.pop_back()
		for n: Vector2i in Karte.NACHBARN:
			var c := z + n
			if c.x < 0 or c.y < 0 or c.x >= Werte.SPALTEN or c.y >= Werte.ZEILEN or stueck.has(c) or sperre.has(c):
				continue
			stueck[c] = true
			offen.append(c)
	return stueck


func _pruefe_knopf() -> void:
	if pruefe():
		spiel.melde("Prüfung bestanden.", 3.0)
	else:
		spiel.melde(_meldungen[0], 6.0)


# ------------------------------------------------------------ Datei

func _speichern(still: bool = false) -> bool:
	if not pruefe():
		spiel.melde("Nicht gespeichert: " + _meldungen[0], 6.0)
		_reiter = "datei"
		return false
	if datei == "":
		datei = freier_name(str(entwurf["name"]))
	if not speichere_datei(datei, entwurf):
		spiel.melde("Speichern ging nicht.", 5.0)
		return false
	if not still:
		spiel.melde("Gespeichert: %s – steht jetzt unter „Herausforderungen“ in der Kartenwahl." % str(entwurf["name"]), 5.0)
	return true


func _testen() -> void:
	if not _speichern(true):
		return
	testet = true
	Werte.karte_gross = true
	Werte.karte_name = datei
	Werte.speichere_einstellungen()
	Werte.herausforderung = str(entwurf["regeln"].get("herausforderung", ""))
	spiel.naechster_start = "normal"
	Ladebild.lade(spiel.get_tree())


func _exportieren() -> void:
	_sammle()
	var dname := (datei if datei != "" else freier_name(str(entwurf.get("name", "szenario")))) + ".json"
	var text := JSON.stringify(entwurf, "\t")
	if OS.has_feature("web"):
		JavaScriptBridge.download_buffer(text.to_utf8_buffer(), dname, "application/json")
		spiel.melde("Heruntergeladen: %s" % dname, 5.0)
		return
	var ordner := OS.get_system_dir(OS.SYSTEM_DIR_DOWNLOADS)
	if ordner == "":
		ordner = ProjectSettings.globalize_path("user://")
	var pfad := ordner.path_join(dname)
	var f := FileAccess.open(pfad, FileAccess.WRITE)
	if f == null:
		spiel.melde("Export ging nicht: %s" % pfad, 5.0)
		return
	f.store_string(text)
	f.close()
	spiel.melde("Exportiert: %s" % pfad, 8.0)


func _dateien_fallen(pfade: PackedStringArray) -> void:
	for p: String in pfade:
		var grund: Array = []
		var kname := importiere(p, grund)
		if kname == "":
			spiel.melde(str(grund[0]), 6.0)
			continue
		_oeffne(kname)
		return


func _oeffne(kname: String) -> void:
	var d := Werte.karten_daten(kname)
	if d.is_empty():
		spiel.melde("Diese Karte lässt sich nicht laden.", 4.0)
		return
	entwurf = _ergaenzt(d)
	datei = kname
	_neu_aufbauen()


## Fehlende Teile (ältere oder fremde Dateien) mit Standardwerten auffüllen.
static func _ergaenzt(d: Dictionary) -> Dictionary:
	var n := neuer_entwurf(int(d["spalten"]), int(d["zeilen"]))
	for k: Variant in d:
		n[k] = d[k]
	if not (n["regeln"] is Dictionary):
		n["regeln"] = neuer_entwurf()["regeln"]
	for k: String in ["wellen", "stand"]:
		if not (n[k] is Dictionary):
			n[k] = {}
	return n


func _frage_laden(kname: String) -> void:
	spiel.add_child(ModLeiste.Tafel.new("Laden", "„%s“ laden? Nicht gespeicherte Änderungen gehen verloren." % str(Werte.karten_daten(kname).get("name", kname)),
		[["Laden", _oeffne.bind(kname)], ["Abbrechen", Callable()]]))


func _frage_loeschen(kname: String) -> void:
	spiel.add_child(ModLeiste.Tafel.new("Löschen", "„%s“ endgültig löschen? Das lässt sich nicht rückgängig machen." % str(Werte.karten_daten(kname).get("name", kname)),
		[["Löschen", _loesche.bind(kname)], ["Abbrechen", Callable()]]))


func _loesche(kname: String) -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Werte.EIGENE_KARTEN + kname + ".json"))
	if datei == kname:
		datei = ""
	spiel.melde("Gelöscht.", 3.0)


func _frage_neu() -> void:
	spiel.add_child(ModLeiste.Tafel.new("Neues Szenario", "Leere Karte 28×14 anfangen? Nicht gespeicherte Änderungen gehen verloren.",
		[["Neu", func() -> void:
			entwurf = neuer_entwurf()
			datei = ""
			_neu_aufbauen()], ["Abbrechen", Callable()]]))


func _frage_groesse(schluessel: String) -> void:
	var teile := schluessel.split("x")
	var sp := int(teile[0])
	var ze := int(teile[1])
	if sp == Werte.SPALTEN and ze == Werte.ZEILEN:
		return
	spiel.add_child(ModLeiste.Tafel.new("Kartengröße %d×%d" % [sp, ze],
		"Zone, Schleuderplätze, Basis und Checkpoints werden neu berechnet. Gelände und Erdwälle bleiben, soweit sie hineinpassen; vorgebaute Türme und Fabriken fallen weg.",
		[["Ändern", _groesse.bind(sp, ze)], ["Abbrechen", Callable()]]))


func _groesse(sp: int, ze: int) -> void:
	_sammle()
	var n := neuer_entwurf(sp, ze)
	for k: String in ["name", "beschreibung", "regeln", "wellen"]:
		n[k] = entwurf[k]
	for k: String in ["fels", "wasser", "mauern", "mauern_fest"] + Werte.BODEN_ARTEN:
		var liste: Array = []
		for p: Array in entwurf.get(k, []):
			if int(p[0]) >= Werte.ZONE_SPALTEN and int(p[0]) < sp and int(p[1]) < ze:
				liste.append(p)
		n[k] = liste
	n["basis_fest"] = entwurf.get("basis_fest", false)
	n["checkpoints_fest"] = entwurf.get("checkpoints_fest", false)
	# Basis und Checkpoints der Vorlage dürfen nicht auf Gelände liegen: dort räumen
	var weg := {}
	var b: Array = n["basis"]
	for c: Vector2i in Karte.basis_felder(Vector2i(int(b[0]), int(b[1]))):
		weg[c] = true
	for p: Array in n["checkpoints"]:
		weg[Vector2i(int(p[0]), int(p[1]))] = true
	for k: String in ["fels", "wasser", "mauern", "mauern_fest"] + Werte.BODEN_ARTEN:
		n[k] = (n[k] as Array).filter(func(p: Array) -> bool: return not weg.has(Vector2i(int(p[0]), int(p[1]))))
	entwurf = n
	_neu_aufbauen()


func _neu_aufbauen() -> void:
	spiel.naechster_start = "editor"
	Ladebild.lade(spiel.get_tree())


func _hauptmenue() -> void:
	_sammle()
	spiel.add_child(ModLeiste.Tafel.new("Hauptmenü", "Den Editor verlassen? Der Entwurf bleibt bis zum Beenden des Spiels erhalten – zum Aufheben vorher speichern.",
		[["Zum Menü", func() -> void:
			spiel.naechster_start = ""
			Ladebild.lade(spiel.get_tree())], ["Abbrechen", Callable()]]))


# ------------------------------------------------------------ Wellen

func _zeige_plan() -> void:
	if not _plaene.has(_runde):
		_plaene[_runde] = []
	spiel.welle = _runde
	var lb: Laufband = spiel._laufband
	lb.visible = true
	lb.zeige(_plaene[_runde])


func _loesche_plan() -> void:
	_plaene.erase(_runde)
	_zeige_plan()


# ------------------------------------------------------------ Texte

func _bearbeite_text(schluessel: String, titel: String, mehrzeilig: bool) -> void:
	var quelle: Dictionary = entwurf if schluessel in ["name", "beschreibung"] else entwurf["regeln"]
	_text_ebene = CanvasLayer.new()
	_text_ebene.layer = 95
	add_child(_text_ebene)
	var grund := ColorRect.new()
	grund.color = Color(0, 0, 0, 0.6)
	grund.set_anchors_preset(Control.PRESET_FULL_RECT)
	_text_ebene.add_child(grund)
	var tafel := PanelContainer.new()
	var kasten := StyleBoxFlat.new()
	kasten.bg_color = Stil.METALL_DUNKEL
	kasten.border_color = Stil.LEUCHT.darkened(0.2)
	kasten.set_border_width_all(3)
	kasten.set_content_margin_all(18)
	tafel.add_theme_stylebox_override("panel", kasten)
	tafel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	tafel.position = Vector2(140, 40)
	tafel.size = Vector2(1000, 0)
	grund.add_child(tafel)
	var spalte := VBoxContainer.new()
	spalte.add_theme_constant_override("separation", 10)
	tafel.add_child(spalte)
	var kopf := Label.new()
	kopf.text = titel
	kopf.add_theme_font_override("font", Stil.schrift())
	kopf.add_theme_font_size_override("font_size", 34)
	kopf.add_theme_color_override("font_color", Stil.LEUCHT)
	spalte.add_child(kopf)
	var feld: Control
	if mehrzeilig:
		var te := TextEdit.new()
		te.text = str(quelle.get(schluessel, ""))
		te.custom_minimum_size = Vector2(960, 300)
		te.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
		feld = te
	else:
		var le := LineEdit.new()
		le.text = str(quelle.get(schluessel, ""))
		le.max_length = 40
		le.custom_minimum_size = Vector2(960, 0)
		le.text_submitted.connect(func(_t: String) -> void: _text_fertig(quelle, schluessel, le.text))
		feld = le
	feld.add_theme_font_override("font", Stil.schrift())
	feld.add_theme_font_size_override("font_size", 30)
	spalte.add_child(feld)
	var reihe := HBoxContainer.new()
	reihe.alignment = BoxContainer.ALIGNMENT_END
	spalte.add_child(reihe)
	for k: Array in [["Abbrechen", false], ["Fertig", true]]:
		var b := Button.new()
		b.text = k[0]
		b.add_theme_font_override("font", Stil.schrift())
		b.add_theme_font_size_override("font_size", 28)
		var uebernehmen: bool = k[1]
		b.pressed.connect(func() -> void:
			if uebernehmen:
				_text_fertig(quelle, schluessel, (feld as TextEdit).text if feld is TextEdit else (feld as LineEdit).text)
			else:
				_schliesse_text())
		reihe.add_child(b)
	feld.grab_focus.call_deferred()


func _text_fertig(quelle: Dictionary, schluessel: String, wert: String) -> void:
	quelle[schluessel] = wert.strip_edges() if schluessel == "name" else wert
	if schluessel == "name" and quelle[schluessel] == "":
		quelle[schluessel] = "Neues Szenario"
	_geaendert()
	_schliesse_text()


func _schliesse_text() -> void:
	if _text_ebene != null:
		_text_ebene.queue_free()
		_text_ebene = null


# ------------------------------------------------------------ Meldung (das Spiel-HUD ist im Editor aus)

## Streifen oben in der Mitte: die letzte Meldung des Spiels (spiel.melde), solange sie gilt.
class Meldung extends Control:
	var spiel: Node

	func _ready() -> void:
		scale = Vector2(Stil.UI_SKALA, Stil.UI_SKALA)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(_delta: float) -> void:
		visible = float(spiel._meldung_zeit) > 0.0 and str(spiel._meldung) != ""
		queue_redraw()

	func _draw() -> void:
		var w := 300.0
		var text := str(spiel._meldung)
		var g := Stil.absatz_groesse(text, w - 12.0, Stil.KLEIN)
		var r := Rect2(640.0 - 6.0 - w, 6.0, w, g.y + 8.0)
		Stil.platte(self, r, 3.0, Stil.METALL_DUNKEL, Stil.LEUCHT.darkened(0.3))
		Stil.absatz(self, r.position + Vector2(6, 4), text, w - 12.0, Stil.KLEIN, Stil.TEXT)


# ------------------------------------------------------------ Marken auf der Karte

## Zeichnet über der Karte: Mauer für „Mauern fest“, Checkpoint-Bereiche, Basis fest/zufällig, Fehlerfelder, Zeiger.
class Marken extends Node2D:
	var ed: SzenarioEditor

	func _process(_delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var karte: Karte = ed.spiel.karte
		var zz := float(Werte.ZELLE)
		var schrift := ThemeDB.fallback_font
		for z: Vector2i in ed._mauern_fest:
			var r := Rect2(karte.mitte(z) - Vector2(zz, zz) / 2.0, Vector2(zz, zz)).grow(-6.0)
			draw_rect(r, Color(FEST_FARBE, 0.45))
			draw_rect(r, FEST_FARBE, false, 3.0)
		# Checkpoint-Bereiche (nur wenn die Checkpoints gewürfelt werden)
		if not bool(ed.entwurf.get("checkpoints_fest", false)):
			for i in 2:
				var b: Array = ed.entwurf["checkpoint_bereiche"][i]
				var farbe := Color("ffd34d") if i == 0 else Color("7fe0ff")
				var r := Rect2(karte.mitte(Vector2i(int(b[0]), int(b[1]))) - Vector2(zz, zz) / 2.0, Vector2(int(b[2]), int(b[3])) * zz)
				draw_rect(r.grow(-2.0 - i * 4.0), Color(farbe, 0.9), false, 3.0)
				draw_string(schrift, r.position + Vector2(8 + i * 4, 22 + i * 4), "Bereich CP %d" % (i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, farbe)
		if ed._bereich_von != Karte.KEINE:
			var a := Vector2i(mini(ed._bereich_von.x, ed._bereich_bis.x), mini(ed._bereich_von.y, ed._bereich_bis.y))
			var e := Vector2i(maxi(ed._bereich_von.x, ed._bereich_bis.x), maxi(ed._bereich_von.y, ed._bereich_bis.y))
			draw_rect(Rect2(karte.mitte(a) - Vector2(zz, zz) / 2.0, Vector2(e - a + Vector2i.ONE) * zz), Color(1, 1, 1, 0.25))
		# Basis: fest oder zufällig
		var bm := karte.mitte(karte.basis) + Vector2(0, -zz * 1.25)
		var b_text := "Basis fest" if bool(ed.entwurf.get("basis_fest", false)) else "Basis zufällig"
		draw_string(schrift, bm - Vector2(80, 0), b_text, HORIZONTAL_ALIGNMENT_CENTER, 160, 18, Color.WHITE)
		# Fehler
		var puls := 0.45 + 0.25 * sin(Time.get_ticks_msec() / 150.0)
		for z: Vector2i in ed._fehler:
			var r := Rect2(karte.mitte(z) - Vector2(zz, zz) / 2.0, Vector2(zz, zz))
			draw_rect(r, Color(FEHLER_FARBE, puls * 0.6))
			draw_rect(r.grow(-2.0), FEHLER_FARBE, false, 3.0)
		# Zeiger
		var mz: Vector2i = karte.zelle_bei(ed.spiel.maus_welt(true))
		if karte.in_karte(mz) and ed._text_ebene == null:
			draw_rect(Rect2(karte.mitte(mz) - Vector2(zz, zz) / 2.0, Vector2(zz, zz)), Color(1, 1, 1, 0.8), false, 2.0)
