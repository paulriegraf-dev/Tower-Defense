extends CanvasLayer
## Neue Oberfläche im Spiel (16.11.2026, Platzhalter): Inseln an den Bildrändern statt Leisten.
##   oben links   Leben, Budget, Zins (Zins nur in der Bauphase)
##   oben Mitte   Runde und nächste Welle als Gegnerbilder mit Anzahl, „Neu“-Abzeichen
##   oben rechts  Übersicht [I], Formationen [H], Schadensliste [Tab], abgesetzt das Hauptmenü
##   unten Mitte  Konsole mit Sechseck-Kacheln (Bauwerk, Preisschild, Taste in der Ecke)
##   unten rechts Start-Emblem und Tempo, darüber die Weganzeige (Bauphase)
## Tipps erscheinen nur noch über der Konsole: zur Kachel unter der Maus bzw. zum gewählten Werkzeug, dazu Meldungen
## und Warnungen. Gezeichnet wird im Raster 640×360: Die Wurzel ist zweifach skaliert (Spielfenster 1280×720), bei
## 1920×1080 ist ein UI-Pixel also 3 Bildschirmpixel.

const Stil := preload("res://scripts/ui/ui_stil.gd")
const BREITE := 640.0
const HOEHE := 360.0
const RAND := 6.0
const BAU := 0      # wie main.gd Phase.BAU / KAMPF / ENDE
const KAMPF := 1

## Kacheln der Konsole: [Werkzeug, Symbol, Taste, Name]
const KACHELN := [
	[Karte.FABRIK, "fabrik", "1", "Fabrik"],
	[Karte.WALL, "wall", "2", "Erdwall"],
	[Karte.STELLUNG, "stellung", "3", "Stellung"],
	[Karte.TURM, "turm", "4", "Turm"],
	[Karte.BATTERIE, "batterie", "5", "Batterie"],
	[Karte.TOR, "tor", "6", "Tor"],
	[Karte.PANZER, "panzer", "7", "Wallpanzer"],
	[Karte.KOMMANDANT, "brakk", "8", "Brakk"],
]
## 21.11. (Paul): Zusatzkacheln je Anführer – Turm-Werkzeug mit festem Ziel: [Turmart, Symbol, Taste, Name, Tipp]
const WUNSCH_KACHELN := [
	["pliplop", "pliplop", "9", "PliPlop 3cK", "Klick auf ein freies Feld: Einzelwall und PliPlop in einem. Steht allein, mehrere erlaubt."],
	["truppen", "truppenturm", "0", "Truppenturm", "Auf einen Erdwall mit zwei freien Nachbarwällen (in einer Mauer oder an einer Ecke)."],
]
const KACHEL_B := 28.0
const KACHEL_H := 40.0
const KACHEL_ABSTAND := 3.0
## 18.11.: Auf Touchgeräten sind die Kacheln so groß gezeichnet (28 UI-Pixel ≈ 5 mm am Handy, Ziel ≥ 9 mm).
const KACHEL_TOUCH := 1.75
var _kachel_faktor := 1.0
## 18.11.: Touch – langes Drücken zeigt den Tipp des Knopfs unter dem Finger (es gibt kein Überfahren mit der Maus).
var _touch_tipp: Control = null
var _touch_tipp_bis := 0.0

var spiel: Node
var schadensliste: Control         # setzt main.gd (Knopf oben rechts zeigt sie wie [Tab])
var wurzel: Control
var kacheln: Dictionary = {}       # Werkzeug -> Kachel
var wunsch_kacheln: Array = []     # 21.11. (Paul): Zusatzkacheln (Kachel, art = Turmart)
var start: Emblem
var tempo: Emblem
var menue: Emblem
var weg_grund: Control             # Weganzeige (main.gd setzt Text und Sichtbarkeit)
var weg_text: Label

var _status: Malflaeche
var _gegenueber: Malflaeche        # 25.11.: Portrait und Name des Phantom-Gegners
var _gegenueber_info: Dictionary = {}
var _welle: Malflaeche
var _auftraege: Malflaeche          # 20.11. (Paul): Liste der laufenden Aufträge
var _auftrag_zeilen: Array = []
const AUFTRAG_BREITE := 172.0
var _konsole: Malflaeche
var _tipp: Malflaeche
var _formen: Malflaeche          # Turm [4] gewählt: welche Wallform welchen Turm ergibt (16.11.)
var formvorlage := ""            # angeklickte Turmart: ihre Wallform liegt als Vorlage an der Maus
## Die fünf Turmformen als Raster 3×3 (Turm = T, Erdwall = #), Reihenfolge wie in der Übersicht.
const TURM_FORMEN := [
	["geschuetz", [".#.", "#T#", "..."]],
	["funk", [".#.", "#T#", ".#."]],
	["frost", ["T##", "#..", "#.."]],
	["lanze", ["#T#", "#.#", "..."]],
	["heil", ["#..", ".T.", "..#"]],
	["schild", [".##.", "#T.#", "#..#", ".##."]],   # Zitadelle (19.11., vorher Hof): Ring aus Erdwällen (Ecken egal), Stufe I–III, siehe ZITADELLE
]
## Zitadelle in drei Stufen (19.11.): Klick auf die Karte schaltet die Vorlage I → II → III → aus.
const ZITADELLE := {
	"schild": [".##.", "#T.#", "#..#", ".##."],
	"schild2": [".####.", "#T...#", "#....#", "#....#", "#....#", ".####."],
	"schild3": [".######.", "#T.....#", "#......#", "#......#", "#......#", "#......#", "#......#", ".######."],
}
const SCHILD_FARBE := Color("b48cff")


## 21.11. (Paul): Kärtchen der Turmformen – beim Irrtürmer zusätzlich PliPlop und Truppenturm (Klick = dieser Turm
## wird gebaut, wie die Kacheln [9] und [0]).
static func formen_liste() -> Array:
	var l: Array = TURM_FORMEN.duplicate()
	if Werte.pliplop():
		l.append(["pliplop", ["...", ".T.", "..."]])
	if Werte.truppenturm():
		l.append(["truppen", ["...", "#T#", "..."]])
	return l


## Name, Formname und Farbe eines Kärtchens.
static func _form_info(art: String) -> Array:
	if art.begins_with("schild"):
		var st: String = {"schild": "I", "schild2": "II", "schild3": "III"}.get(art, "I")
		return ["Zitadelle", "Stufe " + st if art != "schild" else "I · II · III", SCHILD_FARBE, "Zitadelle " + st]
	var d: Dictionary = Werte.TURMARTEN[art]
	var kurz: String = {"geschuetz": "Geschütz", "funk": "Funk", "frost": "Frost", "lanze": "Lanze", "heil": "Heil", "pliplop": "PliPlop", "truppen": "Truppen"}.get(art, art)
	var form: String = {"pliplop": "Freies Feld", "truppen": "In der Mauer"}.get(art, str(d["form"]))
	return [kurz, form, Color(str(d["farbe"])), str(d["name"])]
var _tipp_oben: Malflaeche
var _neu: Emblem
var _oben_rechts: Array[Emblem] = []
var _planer: Emblem
var _konsole_tief := 0.0           # im Kampf sinkt die Konsole ein Stück ab
var eingeklappt := false           # Bauleiste eingeklappt (16.11.: in der Vogelperspektive liegt sie über den unteren Feldern) – [B]
var _klapp_anteil := 0.0
var _klapp: Emblem
## Das Besondere an der Konsole (16.11.): Paul hat "a" gewählt = Monitor auf der linken Schulter. "b" (Lauflicht und
## Kabel zum Start-Emblem) bleibt nur über die Umgebungsvariable TD_KONSOLE=b erreichbar.
var entwurf := "a"
const SCHULTER := 44.0             # Breite der Schultern links und rechts (Platz für Monitor bzw. Kabelanschluss)
var _kampf_seit := -100.0          # Zeitpunkt des letzten Wellenstarts (Entwurf b: Puls zum Start)
var _war_kampf := false

# Was gerade angezeigt wird (in aktualisiere() gesammelt, in den _male_*-Funktionen gezeichnet)
var _leben := 0
var _budget_text := ""
var _zins := 0
var _angreifer := false
var _bauphase := true
var _runde_text := ""
var _welle_zeile := ""             # Text statt Gegnerbildern (Endkampf, laufende Welle)
var _gruppen: Array = []           # [Typ, Anzahl]
var _welle_zusatz := ""            # Leben-Faktor, Wurf
var _neu_text := ""
var _tipp_titel := ""
var _tipp_text := ""
var _tipp_warnung := false
var _tipp_oben_text := ""
var _tipp_oben_x := 0.0
var _blaetter := {}
var _zuweis: Control
var _start_bild: Texture2D
var _start_laeuft: Texture2D


# ------------------------------------------------------------------ Bausteine

## Fläche, die sich über einen Aufruf zeichnet (Inseln, Konsole, Tafeln).
class Malflaeche extends Control:
	var malen: Callable
	func _draw() -> void:
		if malen.is_valid():
			malen.call(self)


## Sechseck-Kachel der Konsole.
class Kachel extends Button:
	const Stil := preload("res://scripts/ui/ui_stil.gd")
	var typ := 0
	var art := ""
	var taste := ""
	var name_text := ""
	var preis := ""
	var preis_farbe := Color.WHITE
	var gewaehlt := false
	var bild: Texture2D        # Bausymbol (assets/neu/ui/bau_*.png, PixelLab 16.11.); ohne Bild das gezeichnete Symbol

	func _draw() -> void:
		var drueber := is_hovered() and not disabled
		var hoch := -3.0 if gewaehlt else (-1.0 if drueber else 0.0)
		var m := Vector2(size.x / 2.0, 16.0 + hoch)
		var rand := Stil.LEUCHT if gewaehlt else (Stil.RAHMEN_HELL if drueber else Stil.RAHMEN)
		draw_colored_polygon(Stil.sechseck(m, 28.0, 32.0), rand)
		draw_colored_polygon(Stil.sechseck(m, 25.0, 29.0), Stil.METALL)
		draw_colored_polygon(Stil.sechseck(m, 23.0, 27.0), Stil.METALL_DUNKEL if not disabled else Stil.METALL_TIEF)
		var farbe := Stil.TEXT
		if gewaehlt:
			farbe = Stil.LEUCHT
		elif disabled:
			farbe = Stil.TEXT_BLASS.darkened(0.35)
		if bild != null:
			var ton := Color.WHITE
			if disabled:
				ton = Color(0.42, 0.44, 0.5)
			elif gewaehlt:
				ton = Color(1.1, 1.15, 1.2)
			Stil.bild(self, bild, m, 2, ton)
		else:
			Stil.symbol(self, art, m + Vector2(0, 1), 2.0, farbe)
		Stil.schreibe(self, Vector2(1.0, 5.0 + hoch), taste, Stil.KLEIN, Stil.LEUCHT if not disabled else Stil.TEXT_BLASS.darkened(0.3))
		if preis != "":
			Stil.preisschild(self, Vector2(size.x / 2.0, 34.0 + hoch), preis, preis_farbe)


## Achteckiges Emblem (Start, Tempo, Knöpfe oben rechts).
class Emblem extends Button:
	const Stil := preload("res://scripts/ui/ui_stil.gd")
	var malen: Callable      # zeichnet den Inhalt
	var leuchtet := false    # Rand dauerhaft hell (z. B. Start bereit)
	var warnt := false       # Rand rot (z. B. „Abbrechen?“)
	var nur_bild := false    # zeichnet nur malen (Start-Emblem als Pixelbild), keinen eigenen Rahmen

	func _draw() -> void:
		if size.x < 6.0 or size.y < 6.0:
			return
		if nur_bild:
			if malen.is_valid():
				malen.call(self)
			return
		var r := Rect2(Vector2.ZERO, size)
		var e := floorf(minf(size.x, size.y) * 0.28)
		var rand := Stil.RAHMEN
		if warnt:
			rand = Stil.ROT
		elif is_hovered() and not disabled:
			rand = Stil.LEUCHT
		elif leuchtet and not disabled:
			rand = Stil.LEUCHT.darkened(0.25)
		draw_colored_polygon(Stil.fase(r, e), rand)
		draw_colored_polygon(Stil.fase(r.grow(-1.0), e - 0.4), Stil.METALL)
		draw_colored_polygon(Stil.fase(r.grow(-2.0), e - 0.8), Stil.METALL_DUNKEL if not disabled else Stil.METALL_TIEF)
		if malen.is_valid():
			malen.call(self)


# ------------------------------------------------------------------ Aufbau

func _ready() -> void:
	if OS.get_environment("TD_KONSOLE") in ["a", "b"]:
		entwurf = OS.get_environment("TD_KONSOLE")
	if Touch.noetig() or OS.get_environment("TD_TOUCH") != "":   # TD_TOUCH: Touch-Leiste am PC ansehen
		_kachel_faktor = KACHEL_TOUCH
	# Zuweisungspfeil Fabrik -> Stellung (HD-2D): im Bild gezeichnet, unter den Inseln (16.11.)
	_zuweis = Control.new()
	_zuweis.size = Vector2(1280, 720)
	_zuweis.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_zuweis.draw.connect(_male_zuweisung)
	add_child(_zuweis)
	# „!“ über einer Stein-Schleuder, die in der Bauphase etwas von dir in Reichweite hat (16.11.)
	_warnung = Control.new()
	_warnung.size = Vector2(1280, 720)
	_warnung.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_warnung.draw.connect(_male_schleuder_warnung)
	add_child(_warnung)
	wurzel = Control.new()
	wurzel.size = Vector2(BREITE, HOEHE)
	wurzel.scale = Vector2(2, 2)
	wurzel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(wurzel)

	_status = _flaeche(_male_status)
	_gegenueber = _flaeche(_male_gegenueber)   # 25.11.: Phantom-Modus
	_gegenueber.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_welle = _flaeche(_male_welle)
	_auftraege = _flaeche(_male_auftraege)   # 20.11. (Paul): Pauls Aufträge, oben links unter Leben und Budget
	_tipp_oben = _flaeche(_male_tipp_oben)
	_konsole = _flaeche(_male_konsole)
	_tipp = _flaeche(_male_tipp)
	_formen = _flaeche(_male_formen)
	_formen.mouse_filter = Control.MOUSE_FILTER_STOP
	_formen.gui_input.connect(_formen_klick)

	for eintrag: Array in KACHELN:
		var k := Kachel.new()
		Stil.leerer_knopf(k)
		k.typ = eintrag[0]
		k.art = eintrag[1]
		k.taste = eintrag[2]
		k.name_text = eintrag[3]
		var pfad := "res://assets/neu/ui/bau_%s.png" % k.art
		if ResourceLoader.exists(pfad):
			k.bild = load(pfad)
		k.size = Vector2(KACHEL_B, KACHEL_H)
		k.scale = Vector2(_kachel_faktor, _kachel_faktor)
		k.pressed.connect(spiel.waehle.bind(k.typ))
		_konsole.add_child(k)
		kacheln[k.typ] = k
	# 21.11. (Paul): Sonde 7 – die Stellung ist ein MG-Nest (eigenes Symbol und Name)
	if Werte.mg_stellung() and kacheln.has(Karte.STELLUNG):
		var ks: Kachel = kacheln[Karte.STELLUNG]
		ks.name_text = "MG-Nest"
		if ResourceLoader.exists("res://assets/neu/ui/bau_mg_nest.png"):
			ks.bild = load("res://assets/neu/ui/bau_mg_nest.png")
	# 21.11. (Paul): Irrtürmer – eigene Kacheln für PliPlop und Truppenturm
	for eintrag: Array in WUNSCH_KACHELN:
		if (eintrag[0] == "pliplop" and not Werte.pliplop()) or (eintrag[0] == "truppen" and not Werte.truppenturm()):
			continue
		var k := Kachel.new()
		Stil.leerer_knopf(k)
		k.typ = Karte.TURM
		k.art = eintrag[0]
		k.taste = eintrag[2]
		k.name_text = eintrag[3]
		k.set_meta("tipp", eintrag[4])
		var pfad := "res://assets/neu/ui/bau_%s.png" % eintrag[1]
		if ResourceLoader.exists(pfad):
			k.bild = load(pfad)
		k.size = Vector2(KACHEL_B, KACHEL_H)
		k.scale = Vector2(_kachel_faktor, _kachel_faktor)
		k.pressed.connect(spiel.waehle_turm.bind(eintrag[0]))
		_konsole.add_child(k)
		wunsch_kacheln.append(k)

	# Klappe über der Konsole: Bauleiste ein- und ausklappen [B]
	_klapp = _emblem(Vector2(18, 8), klappe, _male_klappe)
	_klapp.set_meta("tipp", "Bauleiste ein/aus [B]")

	# Start-Emblem als Pixelbild (PixelLab 16.11.; „läuft“ = gedimmte Fassung), 48×48 Bildpunkte = 48 UI-Pixel
	if ResourceLoader.exists("res://assets/neu/ui/start.png"):
		_start_bild = load("res://assets/neu/ui/start.png")
		_start_laeuft = load("res://assets/neu/ui/start_laeuft.png") if ResourceLoader.exists("res://assets/neu/ui/start_laeuft.png") else null
	var sg := 48.0 if _start_bild != null else 44.0
	start = _emblem(Vector2(sg, sg), spiel.starte_welle, _male_start)
	start.nur_bild = _start_bild != null
	start.position = Vector2(BREITE - RAND - sg, HOEHE - RAND - sg)
	tempo = _emblem(Vector2(24, 24), spiel._tempo_umschalten, _male_tempo)
	tempo.position = Vector2(start.position.x - 28.0, HOEHE - RAND - 24.0)
	tempo.set_meta("tipp", "Tempo [F]")

	# oben rechts: Übersicht, Formationen, Schadensliste – abgesetzt das Hauptmenü
	var x := BREITE - RAND - 20.0
	menue = _emblem(Vector2(20, 20), pause_an, _male_menue)
	menue.position = Vector2(x, RAND)
	x -= 10.0
	for eintrag: Array in [["balken", "Schadensliste [Tab]: an/aus", _schadensliste_klick], ["raster", "Formationen [H]", _formationen_klick], ["buch", "Übersicht [I]", _lexikon_klick]]:
		x -= 20.0
		var art: String = eintrag[0]
		var b := _emblem(Vector2(18, 18), eintrag[2], func(ci: Control): Stil.symbol(ci, art, ci.size / 2.0, 2.0, Stil.TEXT if not (ci as Emblem).leuchtet else Stil.LEUCHT))
		b.position = Vector2(x, RAND + 1.0)
		b.set_meta("tipp", eintrag[1])
		_oben_rechts.append(b)
		x -= 3.0
	menue.set_meta("tipp", "Pause und Menü [P] / [Esc]" if OS.has_feature("web") else "Pause und Menü [Esc]")
	# nur im Phantom-Angriff: Taktikplaner ein/aus (16.11.)
	x -= 20.0
	_planer = _emblem(Vector2(18, 18), _planer_klick, func(ci: Control): Stil.symbol(ci, "band", ci.size / 2.0, 2.0, Stil.TEXT if not (ci as Emblem).leuchtet else Color("ffb070")))
	_planer.position = Vector2(x, RAND + 1.0)
	_planer.set_meta("tipp", "Taktikplaner [L]")
	_oben_rechts.append(_planer)

	_neu = _emblem(Vector2(22, 12), _lexikon_klick, _male_neu)
	_neu.visible = false

	# Weganzeige über Start und Tempo (Text und Sichtbarkeit setzt main.gd)
	weg_grund = _flaeche(func(ci: Control):
		Stil.platte(ci, Rect2(Vector2.ZERO, ci.size), 2.0)
		Stil.schreibe(ci, Vector2(5, ci.size.y / 2.0), weg_text.text, Stil.KLEIN, Stil.GOLD))
	weg_text = Label.new()   # trägt nur den Text (main.gd schreibt hinein), gezeichnet wird oben
	weg_text.visible = false
	weg_grund.add_child(weg_text)
	weg_grund.visible = false

	_baue_pause()
	_baue_wiedereinstieg()   # 21.11.


func _flaeche(malen: Callable) -> Malflaeche:
	var f := Malflaeche.new()
	f.malen = malen
	f.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wurzel.add_child(f)
	return f


func _emblem(groesse: Vector2, aktion: Callable, malen: Callable) -> Emblem:
	var b := Emblem.new()
	Stil.leerer_knopf(b)
	b.size = groesse
	b.malen = malen
	b.pressed.connect(aktion)
	wurzel.add_child(b)
	return b


# ------------------------------------------------------------------ jedes Bild

func aktualisiere(_delta: float) -> void:
	var s := spiel
	var phase: int = s.phase
	_angreifer = s.phantom_modus == "angriff"
	_bauphase = phase == BAU
	_leben = s.leben
	_budget_text = "∞" if s.sandbox else str(s.budget)
	_zins = Werte.zinsen(s.budget)
	_gegenueber_info = s.phantom_partie.gegner_portrait()   # 25.11.
	_gegenueber.visible = not _gegenueber_info.is_empty()

	# --- Welle
	_runde_text = ("Runde %d · endlos" % s.welle) if Werte.ziel() == "endlos" else ("Runde %d/%d" % [s.welle, Werte.LETZTE_RUNDE])   # 18.11.
	if phase == BAU and float(s.bauzeit_rest) >= 0.0:
		_runde_text += "  ·  Bauzeit %d s" % ceili(float(s.bauzeit_rest))   # 18.11.: Bauzeit-Limit
	if s.herausforderung != "":
		_runde_text += "  ·  " + Werte.herausforderung_name(s.herausforderung)   # 18.11.
	_auftrag_zeilen = Auftraege.zeilen(s, s.auftrag) if not (s.auftrag as Dictionary).is_empty() else []   # 20.11.: Pauls Aufträge
	_bei_aenderung(_auftraege, [_auftrag_zeilen])
	_welle_zeile = ""
	_welle_zusatz = ""
	_gruppen = []
	var w: Dictionary = {}
	if s.endkampf:
		var hq_leben: int = ceili(s.hq.leben) if is_instance_valid(s.hq) else 0
		if _angreifer:
			_welle_zeile = "Dein HQ hält %d/%d · Durchgang %d" % [hq_leben, int(Werte.hq_leben()), s._durchgang]
		else:
			_welle_zeile = "Zerstöre das HQ: %d/%d" % [hq_leben, int(Werte.hq_leben())]
		var rest: float = s.patt_rest()
		if rest >= 0.0 and rest <= Phantom.PATT_WARNUNG_SEK:
			_welle_zusatz = tr("Patt in %d s") % ceili(rest)   # 25.11.
	elif phase == KAMPF:
		w = s._welle
		_runde_text += "  ·  noch %d" % (s._noch_offen() + s.gegner.size())
	else:
		w = s.naechste_welle()
		_runde_text += "  ·  " + str(w.get("name", "Nächste"))
	if not w.is_empty():
		for g: Dictionary in w.get("gruppen", []):
			_gruppen.append([str(g["typ"]), int(g["anzahl"])])
		if not is_equal_approx(float(w.get("leben_faktor", 1.0)), 1.0):
			_welle_zusatz = "Leben ×%.1f" % float(w["leben_faktor"])
		if not (w.get("wurf", []) as Array).is_empty():
			_welle_zusatz += ("  ·  " if _welle_zusatz != "" else "") + "Wurf"

	# Ansage: neue Gegner (normales Spiel) bzw. der Plan des Angreifers (Phantom-Verteidigung)
	_neu_text = ""
	if _bauphase and s.phantom_modus == "":
		_neu_text = Werte.ansage(s.welle)   # 20.11.: Szenario-Wellen bringen ihre eigene Ansage
	elif _bauphase and s.phantom_modus == "verteidigung" and not s.phantom_partie.trupps(s.welle).is_empty():
		_neu_text = "Plan des Angreifers: " + Phantom.plan_text(s.phantom_partie.trupps(s.welle))

	_aktualisiere_kacheln()
	_aktualisiere_oben_rechts()
	_aktualisiere_tipps()
	_ordne_an()
	SichererRand.einpassen(wurzel, 2.0)   # 19.11.: iPhone – nicht unter Notch und Home-Balken (am PC unverändert)
	# 18.11.: Leistung – neu gezeichnet wird nur, was sich geändert hat (vorher alles in jedem Bild, ~1 ms am PC).
	# Überfahren mit der Maus und Größenwechsel zeichnen die Flächen selbst neu. In jedem Bild bleiben: die Konsole
	# (Monitor flimmert, Radar läuft), das Start-Emblem, solange es pulsiert, und die Zeichnungen im Spielfeld (Kamera).
	_bei_aenderung(_status, [_leben, _budget_text, _zins, _angreifer, _bauphase])
	_bei_aenderung(_gegenueber, [_gegenueber_info])
	_bei_aenderung(_welle, [_runde_text, _welle_zeile, _gruppen, _welle_zusatz])
	_bei_aenderung(_tipp, [_tipp_titel, _tipp_text, _tipp_warnung, s._meldung_art, s._meldung_zeit > 0.0, s._meldung])
	_bei_aenderung(_tipp_oben, [_tipp_oben_text, _tipp_oben_x])
	_bei_aenderung(weg_grund, [weg_text.text])
	if s.order24 != null:
		_welle.visible = false   # 20.11. (Paul): Befehl 24 – Runde und Gegnerweg gibt es hier nicht
		weg_grund.visible = false
	for f: Control in [_konsole, _zuweis, _warnung, _formen]:
		f.queue_redraw()
	if not start.disabled and _start_bild != null:
		start.queue_redraw()
	else:
		_bei_aenderung(start, [start.disabled, start.leuchtet, start.warnt, _angreifer])
	_bei_aenderung(tempo, [tempo.disabled, tempo.leuchtet, tempo.warnt, s._tempo_faktor])
	for b: Emblem in [menue, _neu] + _oben_rechts:
		_bei_aenderung(b, [b.disabled, b.leuchtet, b.warnt])


## 18.11.: Leistung – Fläche nur neu zeichnen, wenn sich geändert hat, was sie zeigt (`stand`).
func _bei_aenderung(c: CanvasItem, stand: Array) -> void:
	if not c.has_meta("stand") or c.get_meta("stand") != stand:
		c.set_meta("stand", stand)
		c.queue_redraw()


func _aktualisiere_kacheln() -> void:
	var s := spiel
	var phase: int = s.phase
	var ab_welle_2: bool = s.alles_frei()   # 18.11.: in manchen Herausforderungen alles ab Runde 1
	for typ: int in kacheln:
		var k: Kachel = kacheln[typ]
		k.visible = not _angreifer
		var aus: bool = (phase != BAU and not (phase == KAMPF and s.darf_in_welle(typ))) or (typ != Karte.FABRIK and not ab_welle_2) or _angreifer or s.herausforderung_sperrt(typ) != ""   # 18.11.: von der Herausforderung gesperrt
		var preis: int = s.kosten(typ)
		k.preis = str(preis)
		k.preis_farbe = Stil.GOLD if s.budget >= preis else Stil.WARN
		if typ == Karte.WALL and s.freie_waelle > 0:
			k.preis = "×%d" % s.freie_waelle
			k.preis_farbe = Stil.LEUCHT
		if typ == Karte.TURM:
			k.preis = ""   # 17.11.: Türme und Generator kosten verschieden – kein Preis an der Kachel
		if typ == Karte.KOMMANDANT and Werte.figur() != "brakk":
			k.preis = "folgt"   # 19.11.: Figur des Anführers kommt in Schritt 2c – Slot [8] bis dahin gesperrt
			k.preis_farbe = Stil.TEXT_BLASS
			aus = true
		elif typ == Karte.KOMMANDANT and s.kommandant != null:
			k.preis = "im Feld" if s.kommandant.klon_anzeige() == "" else tr("R in %d") % s.kommandant.klon_rest   # 25.11. (N2): Klonmaschine lädt
			k.preis_farbe = Stil.TEXT_BLASS
			aus = true
		if typ != Karte.FABRIK and not ab_welle_2:
			k.preis_farbe = Stil.TEXT_BLASS   # noch nicht freigeschaltet
		if s.tutorial != null and s.tutorial.sperrt_bau(typ) != "":
			aus = true   # 25.11. (N4): das Tutorial braucht gerade ein anderes Werkzeug
		k.disabled = aus
		k.gewaehlt = s.werkzeug == typ and (typ != Karte.TURM or not str(s.turm_wunsch) in ["pliplop", "truppen"])   # 25.11. (N1): Formtürme haben keine eigene Kachel
		_bei_aenderung(k, [k.preis, k.preis_farbe, k.disabled, k.gewaehlt])   # 18.11.: nur bei Änderung
	for k: Kachel in wunsch_kacheln:   # 21.11. (Paul): PliPlop / Truppenturm
		var preis: int = Werte.KOSTEN_PLIPLOP if k.art == "pliplop" else Werte.KOSTEN_TURM
		k.visible = not _angreifer
		k.preis = str(preis)
		k.preis_farbe = (Stil.GOLD if s.budget >= preis else Stil.WARN) if ab_welle_2 else Stil.TEXT_BLASS
		k.disabled = (phase != BAU and not (phase == KAMPF and s.darf_in_welle(Karte.TURM))) or not ab_welle_2 or _angreifer or s.herausforderung_sperrt(Karte.TURM) != "" or (s.tutorial != null and s.tutorial.sperrt_bau(Karte.TURM) != "")
		k.gewaehlt = s.werkzeug == Karte.TURM and str(s.turm_wunsch) == k.art
		_bei_aenderung(k, [k.preis, k.preis_farbe, k.disabled, k.gewaehlt])
	start.disabled = phase != BAU or (s.tutorial != null and s.tutorial.sperrt_start())   # 25.11. (N4): Start nur im Schritt „Welle starten“
	start.leuchtet = phase == BAU
	start.visible = true
	tempo.visible = not bool(s.get("brakk_modus"))   # 19.11. (Paul): der Brakk-Mode läuft fest auf ×2 – der Knopf bringt dort nichts
	_konsole_tief = move_toward(_konsole_tief, 3.0 if phase == KAMPF and not s.endkampf else 0.0, 1.0)
	_klapp_anteil = move_toward(_klapp_anteil, 1.0 if eingeklappt else 0.0, 0.12)
	if phase == KAMPF and not _war_kampf:
		_kampf_seit = _jetzt()
	_war_kampf = phase == KAMPF


func _planer_klick() -> void:
	var s := spiel
	if s.phantom_modus == "angriff" and s.phase == BAU and s._wurfziel_fuer.is_empty():
		s._laufband.visible = not s._laufband.visible


func _aktualisiere_oben_rechts() -> void:
	var s := spiel
	(_oben_rechts[2] as Emblem).leuchtet = s._lexikon.visible
	(_oben_rechts[1] as Emblem).leuchtet = s._nachschlag.visible
	(_oben_rechts[0] as Emblem).leuchtet = is_instance_valid(schadensliste) and schadensliste.get("per_knopf") == true
	_neu.visible = _neu_text != "" and not _angreifer
	_planer.visible = _angreifer
	_planer.disabled = not (_bauphase and s._wurfziel_fuer.is_empty())
	_planer.leuchtet = s._laufband.visible


func _aktualisiere_tipps() -> void:
	# Tafel oben: Name des Knopfs unter der Maus bzw. die Ansage hinter dem „Neu“-Abzeichen
	_tipp_oben_text = ""
	if _touch_tipp != null and _jetzt() > _touch_tipp_bis:
		_touch_tipp = null
	for b: Emblem in _oben_rechts + [menue]:
		if _drueber(b):
			_tipp_oben_text = str(b.get_meta("tipp", ""))
			_tipp_oben_x = b.position.x + b.size.x
	if _neu.visible and _drueber(_neu):
		_tipp_oben_text = _neu_text
		_tipp_oben_x = -1.0   # mittig unter der Welleninsel
	# Tafel unten: Kachel unter der Maus, sonst gewähltes Werkzeug, Meldung oder Warnung
	var unter := Karte.FREI
	for typ: int in kacheln:
		if _drueber(kacheln[typ]):
			unter = typ
	_monitor_typ = unter if unter != Karte.FREI else int(spiel.werkzeug)
	if _drueber(tempo) and spiel._meldung_zeit <= 0.0:
		_tipp_titel = "Tempo  [F]"
		_tipp_text = "Im Brakk-Modus fest auf ×2." if spiel.brakk_modus else "Spielgeschwindigkeit: ×1 › ×2 › ×3 › ×1."
		_tipp_warnung = false
		return
	var h: Array = spiel.hinweis_text(unter)
	if _drueber(start) and not start.disabled and spiel._meldung_zeit <= 0.0:
		h = ["Startet deinen Angriff." if _angreifer else "Startet die nächste Welle.", false]
	_tipp_text = h[0]
	_tipp_warnung = h[1]
	_tipp_titel = ""
	var titel_typ: int = unter if unter != Karte.FREI else spiel.werkzeug
	if _drueber(start) and not start.disabled and spiel._meldung_zeit <= 0.0:
		_tipp_titel = "Start  [Leertaste]"
	elif kacheln.has(titel_typ) and _tipp_text != "" and spiel._meldung_zeit <= 0.0:
		var k: Kachel = kacheln[titel_typ]
		_tipp_titel = "%s  [%s]" % [k.name_text, k.taste]
	# 21.11. (Paul): Zusatzkacheln – unter der Maus oder gewählt: eigener Titel, unter der Maus auch der eigene Tipp
	for k: Kachel in wunsch_kacheln:
		if _drueber(k) and spiel._meldung_zeit <= 0.0:
			_tipp_titel = "%s  [%s]" % [k.name_text, k.taste]
			_tipp_text = str(k.get_meta("tipp", ""))
			_tipp_warnung = false
			return
		if k.gewaehlt and unter == Karte.FREI and spiel._meldung_zeit <= 0.0 and _tipp_text != "":
			_tipp_titel = "%s  [%s]" % [k.name_text, k.taste]


## Maus darüber – oder am Handy gerade lange gedrückt (18.11.).
func _drueber(b: BaseButton) -> bool:
	return b.is_hovered() or b == _touch_tipp


## 18.11.: Von touch.gd beim langen Drücken (Position im Bild). Liegt dort eine Kachel oder ein Emblem, zeigt sie
## 4 s ihren Tipp, und touch.gd macht keinen Rechtsklick daraus. true = Tipp gezeigt.
func touch_tipp(bei: Vector2) -> bool:
	var knoepfe: Array[Control] = [start, tempo, menue, _neu]
	for k: Kachel in kacheln.values():
		knoepfe.append(k)
	for k: Kachel in wunsch_kacheln:
		knoepfe.append(k)
	for b: Emblem in _oben_rechts:
		knoepfe.append(b)
	for c: Control in knoepfe:
		if not c.is_visible_in_tree():
			continue
		var lokal: Vector2 = c.get_global_transform().affine_inverse() * bei
		if Rect2(Vector2.ZERO, c.size).has_point(lokal):
			_touch_tipp = c
			_touch_tipp_bis = _jetzt() + 4.0
			return true
	return false


func _ordne_an() -> void:
	# oben links: Leben · Budget · Zins
	var w := RAND + 2.0
	w += 14.0 + Stil.breite(str(_leben), Stil.GROSS) + 8.0
	if not _angreifer:
		w += 14.0 + Stil.breite(_budget_text, Stil.GROSS) + 8.0
		if _bauphase:
			w += Werte.zins_stufen() * 6.0 + 4.0 + Stil.breite("+%d" % _zins, Stil.NORMAL) + 4.0   # 19.11.: Zinsdeckel je Anführer
	else:
		w += Stil.breite("Verteidigung", Stil.NORMAL) + 6.0
	_status.position = Vector2(RAND, RAND)
	_status.size = Vector2(ceilf(w), 22.0)
	# 20.11. (Paul): Pauls Aufträge darunter – je Auftrag Kopfzeile (Stufe, Name, Stand) und Text mit Lohn
	_auftraege.visible = not _auftrag_zeilen.is_empty()
	if _auftraege.visible:
		var ah := 4.0
		for z: Dictionary in _auftrag_zeilen:
			ah += 11.0 + ceilf(Stil.absatz_groesse(_auftrag_text(z), AUFTRAG_BREITE - 10.0, Stil.KLEIN).y) + 4.0
		_auftraege.position = Vector2(RAND, RAND + 22.0 + 3.0 + 12.0 + 3.0)   # unter der Zeile „Gegnerweg …“
		_auftraege.size = Vector2(AUFTRAG_BREITE, ah)

	# oben Mitte: Runde, darunter die Gegner
	var zeile2 := 0.0
	if _welle_zeile != "":
		zeile2 = Stil.breite(_welle_zeile, Stil.NORMAL) + (Stil.breite(_welle_zusatz, Stil.KLEIN) + 8.0 if _welle_zusatz != "" else 0.0)
	else:
		for g: Array in _gruppen:
			zeile2 += 16.0 + Stil.breite("×%d" % g[1], Stil.NORMAL) + 6.0
		if _welle_zusatz != "":
			zeile2 += Stil.breite(_welle_zusatz, Stil.KLEIN) + 4.0
	var ww := ceilf(maxf(Stil.breite(_runde_text, Stil.NORMAL), zeile2) + 16.0)
	_welle.size = Vector2(ww, 34.0 if (_welle_zeile != "" or not _gruppen.is_empty()) else 18.0)
	_welle.position = Vector2(roundf((BREITE - ww) / 2.0), RAND)
	_neu.position = Vector2(_welle.position.x + ww + 3.0, RAND + 2.0)
	# 25.11.: Phantom-Gegner rechts neben Leben/Budget; wird es dort eng, unter die Zeile „Gegnerweg“
	if _gegenueber.visible:
		var gb := ceilf(maxf(38.0, Stil.breite(str(_gegenueber_info["name"]), Stil.KLEIN) + 8.0))
		_gegenueber.size = Vector2(gb, 48.0)
		_gegenueber.position = Vector2(_status.position.x + _status.size.x + 4.0, RAND)
		if _gegenueber.position.x + gb > _welle.position.x - 3.0:
			_gegenueber.position = Vector2(RAND, _status.position.y + _status.size.y + 18.0)

	# Tafel oben (unter dem Knopf bzw. unter der Welle)
	if _tipp_oben_text != "":
		var weite := 200.0 if _tipp_oben_x < 0.0 else 110.0
		var g := Stil.absatz_groesse(_tipp_oben_text, weite, Stil.KLEIN)
		_tipp_oben.size = Vector2(ceilf(g.x) + 10.0, ceilf(g.y) + 6.0)
		if _tipp_oben_x < 0.0:
			_tipp_oben.position = Vector2(roundf((BREITE - _tipp_oben.size.x) / 2.0), _welle.position.y + _welle.size.y + 3.0)
		else:
			_tipp_oben.position = Vector2(minf(_tipp_oben_x - _tipp_oben.size.x, BREITE - RAND - _tipp_oben.size.x), RAND + 24.0)
	_tipp_oben.visible = _tipp_oben_text != ""

	# unten Mitte: Konsole
	var n := kacheln.size() + wunsch_kacheln.size()
	var f := _kachel_faktor
	var reihe := n * KACHEL_B * f + (n - 1) * KACHEL_ABSTAND
	var kw := reihe + 2.0 * SCHULTER
	var kh := 50.0 + roundf(KACHEL_H * (f - 1.0))
	var kx := roundf((BREITE - kw) / 2.0)
	if f > 1.0:
		kx = minf(kx, tempo.position.x - 4.0 - kw)   # 18.11.: breite Touch-Leiste rückt links neben Tempo und Start
	_konsole.size = Vector2(kw, kh)
	_konsole.position = Vector2(kx, HOEHE - kh + roundf(_konsole_tief + _klapp_anteil * (kh - 6.0)))
	var klapp_w := 18.0 if not eingeklappt else Stil.breite("Bauleiste [B]", Stil.KLEIN) + 18.0
	_klapp.size = Vector2(roundf(klapp_w), 9)
	_klapp.position = Vector2(roundf(kx + (kw - klapp_w) / 2.0), _konsole.position.y - 6.0)
	_klapp.visible = _konsole.visible
	_konsole.visible = not _angreifer and not spiel.brakk_modus   # 18.11. (Paul): im Brakk-Mode keine Bauleiste (links steht die Ego-Liste)
	var i := 0
	for eintrag: Array in KACHELN:
		var k: Kachel = kacheln[eintrag[0]]
		k.position = Vector2(SCHULTER + i * (KACHEL_B * f + KACHEL_ABSTAND), 8.0)
		i += 1
	for k: Kachel in wunsch_kacheln:
		k.position = Vector2(SCHULTER + i * (KACHEL_B * f + KACHEL_ABSTAND), 8.0)
		i += 1

	# Tafel über der Konsole
	if _tipp_text != "":
		var weite := 220.0
		var g := Stil.absatz_groesse(_tipp_text, weite, Stil.KLEIN)
		var th := ceilf(g.y) + 8.0 + (11.0 if _tipp_titel != "" else 0.0)
		_tipp.size = Vector2(ceilf(maxf(g.x, Stil.breite(_tipp_titel, Stil.NORMAL))) + 12.0, th)
		var unten := _konsole.position.y - 3.0 if _konsole.visible else (HOEHE - RAND if spiel.brakk_modus else HOEHE - RAND - 50.0)   # 18.11.: Brakk-Mode – ganz unten, unter Brakks Leisten
		_tipp.position = Vector2(roundf((BREITE - _tipp.size.x) / 2.0), unten - th)
	_tipp.visible = _tipp_text != ""

	# Turmformen über der Tafel, solange das Turm-Werkzeug gewählt ist
	# 17.11. (Paul): Ist eine Turmart gewählt, verschwinden die Kärtchen, damit man das Feld sieht. Nochmal [4] = neu wählen.
	_formen.visible = _bauphase and _konsole.visible and not eingeklappt and spiel.werkzeug == Karte.TURM and formvorlage == ""
	if spiel.werkzeug != Karte.TURM:
		formvorlage = ""   # 17.11.: Vorlage nur, solange man gerade einen Turm ausgesucht hat
	if _formen.visible:
		_formen.size = Vector2(formen_liste().size() * 59.0 - 3.0 + 10.0, 74.0)
		var oben := (_tipp.position.y if _tipp.visible else _konsole.position.y) - 3.0
		_formen.position = Vector2(roundf((BREITE - _formen.size.x) / 2.0), oben - _formen.size.y)

	# Weganzeige rechts über Start
	weg_grund.size = Vector2(ceilf(Stil.breite(weg_text.text, Stil.KLEIN)) + 10.0, 12.0)
	weg_grund.position = Vector2(RAND, _status.position.y + _status.size.y + 3.0)   # unter Leben und Budget


# ------------------------------------------------------------------ Zeichnen

## Turmformen (16.11., Paul: „wieder anzeigen, wie man die überhaupt baut“): fünf Kärtchen mit der Wallform als
## kleines Raster, Turmname und Formname. Passt die Form unter der Maus, leuchtet ihr Kärtchen auf.
## Vorlage an der Maus: Turmfeld in der Turmfarbe, die nötigen Erdwälle als Rahmen – grün, wo schon einer steht,
## in Turmfarbe gestrichelt, wo noch einer fehlt.
func _male_formvorlage() -> void:
	if formvorlage == "" or spiel.werkzeug != Karte.TURM or not _bauphase or eingeklappt:
		return
	var k: Karte = spiel.karte
	var z: Vector2i = k.zelle_bei(spiel.maus_welt())
	if not k.in_karte(z):
		return
	var wunsch_hier: bool = str(spiel.turm_wunsch) == formvorlage and k.inhalt(z) == Karte.WALL   # 25.11. (N1)
	if wunsch_hier and k.ausbau_hindernis(z, Karte.TURM) == "":
		return   # die gewählte Turmart passt hier: die Stützen-Vorschau zeigt die belegten Erdwälle
	var info := _form_info(formvorlage)
	var farbe: Color = info[2]
	var mitte: Vector2 = spiel.welt_zu_bild(k.mitte(z))
	var nachbar: Vector2 = spiel.welt_zu_bild(k.mitte(z) + Vector2(Werte.ZELLE, 0))
	var halb := maxf(8.0, absf(nachbar.x - mitte.x) * 0.42)
	if formvorlage.begins_with("schild") and k.ist_frei(z) and not k.hof_von(z).is_empty():
		# 19.11.: Die Maus steht schon in einer fertigen Zitadelle – deren Innenfeld zeigen statt einer Vorlage
		var hof: Array = k.hof_von(z)
		for c: Vector2i in hof:
			var pc: Vector2 = spiel.welt_zu_bild(k.mitte(c))
			_warnung.draw_rect(Rect2(pc - Vector2(halb, halb * 0.7), Vector2(halb * 2.0, halb * 1.4)), Color(farbe, 0.22))
		var st := Werte.zitadelle_stufe(hof.size())
		var txt := "Zitadelle %s (%d Felder): Generator passt" % [["", "I", "II", "III"][st], hof.size()]
		if st >= 3 and spiel.welle < Werte.ZITADELLE_III_AB_WELLE and not spiel.sandbox:
			txt = "Zitadelle III erst ab Welle %d" % Werte.ZITADELLE_III_AB_WELLE
		Stil.schreibe_mittig(_warnung, mitte + Vector2(0, -halb - 14.0), txt, Stil.NORMAL, Color.WHITE)
		return
	var fehlt := 0
	for e: Array in formvorlage_felder(formvorlage, z):
		var p: Vector2 = spiel.welt_zu_bild(k.mitte(e[0]))
		var r := Rect2(p - Vector2(halb, halb * 0.7), Vector2(halb * 2.0, halb * 1.4))
		if e[1]:
			_warnung.draw_rect(r, Color(0.55, 1.0, 0.55, 0.25))
			_warnung.draw_rect(r, Color(0.55, 1.0, 0.55, 0.95), false, 3.0)
		else:
			fehlt += 1
			_warnung.draw_rect(r, Color(farbe, 0.18))
			_warnung.draw_rect(r, Color(0.05, 0.05, 0.08, 0.7), false, 5.0)
			_warnung.draw_rect(r, farbe, false, 2.0)
	if not formvorlage.begins_with("schild") and not (k.inhalt(z) == Karte.WALL):
		fehlt += 1   # der Turm selbst steht auch auf einem Erdwall (der Generator dagegen auf einem freien Feld)
	var rt := Rect2(mitte - Vector2(halb, halb * 0.7), Vector2(halb * 2.0, halb * 1.4))
	_warnung.draw_rect(rt, Color(farbe, 0.45))
	_warnung.draw_rect(rt, Color.WHITE, false, 2.0)
	var name: String = info[3]
	var text := "%s: Form passt" % name if fehlt == 0 else "%s: noch %d Erdwall%s" % [name, fehlt, "" if fehlt == 1 else "e"]
	if wunsch_hier and fehlt == 0:
		text = spiel.wunsch_hindernis(z)   # alle Wälle stehen, aber der Turm geht trotzdem nicht (z. B. Stützen vergeben)
	Stil.schreibe_mittig(_warnung, mitte + Vector2(0, -halb - 14.0), text, Stil.NORMAL, Color.WHITE)


## 19.11. (Paul: „klarer machen, dass die Felder nach dem Bau nicht mehr für andere Türme gelten“): Mit dem
## Turm-Werkzeug [4] bekommen vergebene Erdwälle die Farbe ihres Turms, eine Schraffur und eine Linie zum Turm.
## Über einem freien Erdwall zeigt die Vorschau genau die Wälle, die der neue Turm belegen würde.
func _male_turm_stuetzen() -> void:
	if spiel.werkzeug != Karte.TURM or not _bauphase:
		return
	var k: Karte = spiel.karte
	var a: Vector2 = spiel.welt_zu_bild(k.mitte(Vector2i.ZERO))
	var b: Vector2 = spiel.welt_zu_bild(k.mitte(Vector2i(1, 0)))
	var halb := maxf(8.0, absf(b.x - a.x) * 0.42)
	for n: Vector2i in k.stuetze_von:
		var t: Vector2i = k.stuetze_von[n]
		if k.ausbau.get(t, Karte.FREI) != Karte.TURM or k.inhalt(n) != Karte.WALL:
			continue
		var farbe := Color(str(Werte.TURMARTEN[k.turm_art.get(t, "geschuetz")]["farbe"]))
		var p: Vector2 = spiel.welt_zu_bild(k.mitte(n))
		_warnung.draw_line(p, spiel.welt_zu_bild(k.mitte(t)), Color(farbe, 0.5), 2.0)
		var r := Rect2(p - Vector2(halb, halb * 0.7), Vector2(halb * 2.0, halb * 1.4))
		_warnung.draw_rect(r, Color(farbe, 0.16))
		_schraffur(r, Color(farbe, 0.55))
		_warnung.draw_rect(r, Color(farbe, 0.9), false, 2.0)
	var z: Vector2i = k.zelle_bei(spiel.maus_welt())
	# Mit Vorlage nur dort, wo die gewählte Turmart passt (25.11., N1) – sonst spricht die Vorlage (_male_formvorlage)
	if formvorlage != "" and not (str(spiel.turm_wunsch) == formvorlage and k.in_karte(z) and k.ausbau_hindernis(z, Karte.TURM) == ""):
		return
	if not k.in_karte(z) or k.inhalt(z) != Karte.WALL or k.ausbau.get(z, Karte.FREI) == Karte.TURM:
		return
	var oben: Vector2 = spiel.welt_zu_bild(k.mitte(z)) + Vector2(0, -halb - 14.0)
	if k.stuetze_von.has(z) and k.ausbau.get(k.stuetze_von[z], Karte.FREI) == Karte.TURM:
		Stil.schreibe_mittig(_warnung, oben, "Gehört schon einem Turm", Stil.NORMAL, Stil.WARN)
		return
	var art := k.turm_form(z)
	if art == "":
		if str(spiel.turm_wunsch) != "":   # 25.11. (N1): sagen, was der gewählten Turmart fehlt
			Stil.schreibe_mittig(_warnung, oben, spiel.wunsch_hindernis(z), Stil.NORMAL, Stil.WARN)
			return
		Stil.schreibe_mittig(_warnung, oben, "Keine Turmform – [4]-Leiste zeigt die Formen", Stil.NORMAL, Stil.TEXT_BLASS)
		return
	var farbe := Color(str(Werte.TURMARTEN[art]["farbe"]))
	for w: Vector2i in k._waehle_stuetzen(z, art):
		var p: Vector2 = spiel.welt_zu_bild(k.mitte(w))
		var r := Rect2(p - Vector2(halb, halb * 0.7), Vector2(halb * 2.0, halb * 1.4))
		_warnung.draw_rect(r, Color(farbe, 0.25))
		_warnung.draw_rect(r, Color(0.05, 0.05, 0.08, 0.7), false, 5.0)
		_warnung.draw_rect(r, farbe, false, 2.5)
	var pz: Vector2 = spiel.welt_zu_bild(k.mitte(z))
	_warnung.draw_rect(Rect2(pz - Vector2(halb, halb * 0.7), Vector2(halb * 2.0, halb * 1.4)), Color.WHITE, false, 2.0)
	Stil.schreibe_mittig(_warnung, oben, "%s – belegt diese Erdwälle" % str(Werte.TURMARTEN[art]["name"]), Stil.NORMAL, farbe)


## Schräge Striche in einem Rechteck (45°), auf das Rechteck beschnitten.
func _schraffur(r: Rect2, farbe: Color, abstand: float = 6.0) -> void:
	var w := r.size.x
	var h := r.size.y
	var c := -h
	while c < w:
		var s0 := Vector2(c, h)
		var s1 := Vector2(c + h, 0)
		if s0.x < 0.0:
			s0 = Vector2(0.0, h + s0.x)
		if s1.x > w:
			s1 = Vector2(w, s1.x - w)
		_warnung.draw_line(r.position + s0, r.position + s1, farbe, 1.0)
		c += abstand


func _formen_klick(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var i := int(floorf(((event as InputEventMouseButton).position.x - 5.0) / 59.0))
		var liste := formen_liste()
		if i >= 0 and i < liste.size():
			var art: String = liste[i][0]
			if art in ["pliplop", "truppen"]:
				# 21.11. (Paul): eigener Turm des Irrtürmers – ein Klick wählt ihn zum Bauen (nochmal = abwählen)
				formvorlage = ""
				spiel.turm_wunsch = "" if spiel.turm_wunsch == art else art
				_formen.accept_event()
				return
			spiel.turm_wunsch = ""
			if art == "schild":
				# 19.11.: Zitadelle – I → II → III → aus
				var folge := {"": "schild", "schild": "schild2", "schild2": "schild3", "schild3": ""}
				formvorlage = str(folge.get(formvorlage, "schild")) if formvorlage == "" or formvorlage.begins_with("schild") else "schild"
			else:
				formvorlage = "" if formvorlage == art else art
				spiel.turm_wunsch = formvorlage   # 25.11. (Paul, N1): die angeklickte Turmart wird auch gebaut
		_formen.accept_event()


## Die Felder der Wallform von `art`, wenn der Turm auf `z` stünde – in der Lage (gedreht/gespiegelt), in der schon die
## meisten Erdwälle stehen. Ergebnis: Liste von [Feld, steht schon].
func formvorlage_felder(art: String, z: Vector2i) -> Array:
	var raster: Array = ZITADELLE.get(art, [])
	for f: Array in TURM_FORMEN:
		if f[0] == art:
			raster = f[1]
	var turm := Vector2i.ZERO
	var waelle: Array[Vector2i] = []
	for y in raster.size():
		for x in (raster[y] as String).length():
			var c: String = (raster[y] as String)[x]
			if c == "T":
				turm = Vector2i(x, y)
			elif c == "#":
				waelle.append(Vector2i(x, y))
	var k: Karte = spiel.karte
	var beste: Array = []
	var bestes := -1
	for spiegel in [false, true]:
		for dreh in 4:
			var liste: Array = []
			var stehen := 0
			for w: Vector2i in waelle:
				var d := w - turm
				if spiegel:
					d.x = -d.x
				for _i in dreh:
					d = Vector2i(-d.y, d.x)
				var feld := z + d
				var steht: bool = k.in_karte(feld) and k.inhalt(feld) == Karte.WALL
				if steht:
					stehen += 1
				liste.append([feld, steht])
			if stehen > bestes:
				bestes = stehen
				beste = liste
	return beste


func _male_formen(ci: Control) -> void:
	Stil.platte(ci, Rect2(Vector2.ZERO, ci.size), 4.0)
	Stil.schreibe(ci, Vector2(6, 6), "Klick = Vorlage an der Maus · schraffierte Erdwälle gehören schon einem Turm und zählen für keinen anderen", Stil.KLEIN, Stil.TEXT_BLASS)
	var unter := ""
	var k: Karte = spiel.karte
	var mz: Vector2i = k.zelle_bei(spiel.maus_welt())
	if k.in_karte(mz) and k.inhalt(mz) == Karte.WALL:
		unter = k.turm_form(mz)
	elif k.in_karte(mz) and k.ist_frei(mz) and not k.hof_von(mz).is_empty():
		unter = "schild"
	var liste := formen_liste()
	for i in liste.size():
		var art: String = liste[i][0]
		var raster: Array = liste[i][1]
		if art == "schild" and formvorlage.begins_with("schild"):
			art = formvorlage   # Zitadelle: die gewählte Stufe zeigen
			raster = ZITADELLE[art]
		var info := _form_info(art)
		var farbe: Color = info[2]
		var r := Rect2(Vector2(5.0 + i * 59.0, 13.0), Vector2(56, 57))
		var an := art == unter or art == formvorlage or (unter == "schild" and art.begins_with("schild"))
		if art in ["pliplop", "truppen"] or spiel.turm_wunsch != "":
			an = art == spiel.turm_wunsch   # 21.11.: gewählter Irrtürmer-Turm
		Stil.platte(ci, r, 3.0, Stil.METALL if an else Stil.METALL_TIEF, farbe if an else Stil.RAHMEN)
		var spalten := (raster[0] as String).length()
		var feld := 8.0 if raster.size() <= 3 else (6.0 if raster.size() <= 4 else 24.0 / raster.size())
		var ecke := Vector2(r.get_center().x - feld * spalten / 2.0, r.position.y + 4.0 + (3.0 * 8.0 - raster.size() * feld) / 2.0).round()
		for y in raster.size():
			for x in spalten:
				var c: String = (raster[y] as String)[x]
				var f := Rect2(ecke + Vector2(x, y) * feld, Vector2(feld - 1.0, feld - 1.0))
				if c == "#":
					ci.draw_rect(f, Stil.RAHMEN_HELL)
					ci.draw_rect(Rect2(f.position, Vector2(f.size.x, 1)), Stil.TEXT_BLASS)
				elif c == "T":
					ci.draw_rect(f, Stil.RAHMEN_HELL)
					ci.draw_rect(f.grow(-1.5), farbe)
				else:
					ci.draw_rect(f, Color(0, 0, 0, 0.25))
		Stil.schreibe_mittig(ci, Vector2(r.get_center().x, r.end.y - 16.0), info[0], Stil.KLEIN, farbe if an else Stil.TEXT)
		Stil.schreibe_mittig(ci, Vector2(r.get_center().x, r.end.y - 7.0), info[1], Stil.KLEIN, Stil.TEXT_BLASS)


## 25.11.: Portrait 32×32 mit Spielername darunter.
func _male_gegenueber(ci: Control) -> void:
	if _gegenueber_info.is_empty():
		return
	Stil.platte(ci, Rect2(Vector2.ZERO, ci.size), 4.0)
	var x := roundf((ci.size.x - 32.0) / 2.0)
	ci.draw_texture_rect(Profil.portrait_bild(int(_gegenueber_info["portrait"])), Rect2(x, 3.0, 32.0, 32.0), false)
	ci.draw_rect(Rect2(x - 1.0, 2.0, 34.0, 34.0), Stil.KUPFER, false, 1.0)
	Stil.schreibe_mittig(ci, Vector2(ci.size.x / 2.0, 42.0), str(_gegenueber_info["name"]), Stil.KLEIN, Stil.TEXT)


func _male_status(ci: Control) -> void:
	Stil.platte(ci, Rect2(Vector2.ZERO, ci.size), 4.0)
	var y := ci.size.y / 2.0
	var x := RAND + 2.0
	if _angreifer:
		x += Stil.schreibe(ci, Vector2(x, y), "Verteidigung", Stil.NORMAL, Stil.TEXT_BLASS) + 6.0
	Stil.symbol(ci, "herz", Vector2(x + 5.0, y), 1.5, Stil.ROT)
	x += 14.0
	x += Stil.schreibe(ci, Vector2(x, y), str(_leben), Stil.GROSS, Stil.TEXT) + 8.0
	if _angreifer:
		return
	Stil.symbol(ci, "muenze", Vector2(x + 5.0, y), 1.5, Stil.GOLD)
	x += 14.0
	x += Stil.schreibe(ci, Vector2(x, y), _budget_text, Stil.GROSS, Stil.GOLD) + 8.0
	if not _bauphase:
		return
	for i in Werte.zins_stufen():
		var r := Rect2(Vector2(x + i * 6.0, y - 2.5), Vector2(5, 5))
		ci.draw_rect(r, Stil.RAHMEN)
		if (i + 1) * Werte.ZINS_JE_SCHRITT <= _zins:
			ci.draw_rect(r.grow(-1.0), Stil.GOLD)
		else:
			ci.draw_rect(r.grow(-1.0), Stil.METALL_TIEF)
	x += Werte.zins_stufen() * 6.0 + 4.0
	Stil.schreibe(ci, Vector2(x, y), "+%d" % _zins, Stil.NORMAL, Stil.GOLD)


func _auftrag_text(z: Dictionary) -> String:
	return "%s  →  %s" % [z["text"], z["lohn"]]


## 20.11. (Paul): Pauls Aufträge. Farbe der Marke = Stufe, Haken/Kreuz = Ergebnis, „bereit“ = Bedingung zum Wellenstart steht.
func _male_auftraege(ci: Control) -> void:
	Stil.platte(ci, Rect2(Vector2.ZERO, ci.size), 4.0)
	var y := 4.0
	for z: Dictionary in _auftrag_zeilen:
		var st: Dictionary = Auftraege.STUFEN[int(z["stufe"])]
		var farbe := Color(str(st["farbe"]))
		var zustand := str(z["zustand"])
		var blass := zustand == "nein"
		var marke := str(st["name"]) + (" · Pflicht" if bool(z["pflicht"]) else "")
		var mw := ceilf(Stil.breite(marke, Stil.KLEIN)) + 6.0
		Stil.platte(ci, Rect2(Vector2(4, y), Vector2(mw, 10)), 2.0, Stil.METALL_DUNKEL, farbe.darkened(0.5 if blass else 0.15))
		Stil.schreibe_mittig(ci, Vector2(4 + mw / 2.0, y + 5.0), marke, Stil.KLEIN, farbe.darkened(0.4) if blass else farbe)
		Stil.schreibe(ci, Vector2(4 + mw + 4.0, y + 5.0), str(z["name"]), Stil.KLEIN, Stil.TEXT_BLASS if blass else Stil.TEXT)
		var rechts := str(z["stand"])
		var rf := Stil.TEXT_BLASS
		match zustand:
			"ja":
				rechts = "erfüllt"
				rf = Color("9be37b")
			"nein":
				rechts = "verfehlt"
				rf = Stil.WARN
			"halb":
				rechts = "läuft"
				rf = Stil.LEUCHT
			"bereit":
				rechts = (rechts + " ✓").strip_edges()
				rf = Color("9be37b")
		if rechts != "":
			Stil.schreibe(ci, Vector2(ci.size.x - 5.0 - Stil.breite(rechts, Stil.KLEIN), y + 5.0), rechts, Stil.KLEIN, rf)
		y += 11.0
		var t := _auftrag_text(z)
		Stil.absatz(ci, Vector2(5, y), t, ci.size.x - 10.0, Stil.KLEIN, Stil.TEXT_BLASS.darkened(0.25) if blass else Stil.TEXT_BLASS)
		y += ceilf(Stil.absatz_groesse(t, ci.size.x - 10.0, Stil.KLEIN).y) + 4.0


func _male_welle(ci: Control) -> void:
	Stil.platte(ci, Rect2(Vector2.ZERO, ci.size), 4.0)
	# kupferne Kante oben: hier geht es um die Gegner
	ci.draw_rect(Rect2(Vector2(5, 2), Vector2(ci.size.x - 10.0, 1)), Stil.KUPFER.darkened(0.2))
	Stil.schreibe_mittig(ci, Vector2(ci.size.x / 2.0, 9.0), _runde_text, Stil.NORMAL, Stil.TEXT)
	var y := 24.0
	if _welle_zeile != "":
		var zb := Stil.breite(_welle_zusatz, Stil.KLEIN) + 8.0 if _welle_zusatz != "" else 0.0   # 25.11.: Patt-Countdown
		Stil.schreibe_mittig(ci, Vector2((ci.size.x - zb) / 2.0, y), _welle_zeile, Stil.NORMAL, Stil.KUPFER)
		if zb > 0.0:
			Stil.schreibe(ci, Vector2((ci.size.x - zb) / 2.0 + Stil.breite(_welle_zeile, Stil.NORMAL) / 2.0 + 8.0, y + 1.0), _welle_zusatz, Stil.KLEIN, Stil.GOLD)
		return
	var gesamt := 0.0
	for g: Array in _gruppen:
		gesamt += 16.0 + Stil.breite("×%d" % g[1], Stil.NORMAL) + 6.0
	if _welle_zusatz != "":
		gesamt += Stil.breite(_welle_zusatz, Stil.KLEIN) + 4.0
	var x := roundf((ci.size.x - gesamt) / 2.0)
	for g: Array in _gruppen:
		_gegner_bild(ci, str(g[0]), Rect2(Vector2(x, y - 8.0), Vector2(16, 16)))
		x += 16.0
		x += Stil.schreibe(ci, Vector2(x, y + 2.0), "×%d" % g[1], Stil.NORMAL, Stil.TEXT) + 6.0
	if _welle_zusatz != "":
		Stil.schreibe(ci, Vector2(x, y + 2.0), _welle_zusatz, Stil.KLEIN, Stil.KUPFER)


## Erstes Standbild eines Gegners (Blick nach rechts), eingepasst in `r`.
func _gegner_bild(ci: Control, typ: String, r: Rect2) -> void:
	if not Werte.GEGNER.has(typ):
		return
	var d := Werte.grafik_daten(Werte.GEGNER[typ])
	var pfad := str(d.get("blatt", ""))
	if pfad == "":
		return
	if not _blaetter.has(pfad):
		_blaetter[pfad] = load(pfad) if ResourceLoader.exists(pfad) else null
	var tex: Texture2D = _blaetter[pfad]
	if tex == null:
		return
	var kante := float(d.get("zelle", 48))
	ci.draw_texture_rect_region(tex, r, Rect2(0, 0, kante, kante))


func _male_neu(ci: Control) -> void:
	Stil.schreibe_mittig(ci, ci.size / 2.0, "NEU", Stil.KLEIN, Stil.LEUCHT)


func _male_tipp_oben(ci: Control) -> void:
	Stil.platte(ci, Rect2(Vector2.ZERO, ci.size), 2.0)
	var weite := 200.0 if _tipp_oben_x < 0.0 else 110.0
	Stil.absatz(ci, Vector2(5, 3), _tipp_oben_text, weite, Stil.KLEIN, Stil.TEXT)


func _jetzt() -> float:
	return Time.get_ticks_msec() / 1000.0


## Bauleiste ein- oder ausklappen (Klappe über der Konsole oder [B]).
func klappe() -> void:
	eingeklappt = not eingeklappt
	if eingeklappt:
		spiel.werkzeug = Karte.FREI   # mit eingeklappter Leiste ist kein Werkzeug mehr sichtbar gewählt


func _male_klappe(ci: Control) -> void:
	var m := Vector2(9.0, ci.size.y / 2.0)
	var farbe := Stil.LEUCHT if (ci as Emblem).is_hovered() else Stil.TEXT
	var pfeil := PackedVector2Array([m + Vector2(-3, 1.5), m + Vector2(3, 1.5), m + Vector2(0, -2)]) if eingeklappt \
		else PackedVector2Array([m + Vector2(-3, -1.5), m + Vector2(3, -1.5), m + Vector2(0, 2)])
	ci.draw_colored_polygon(pfeil, farbe)
	if eingeklappt:
		Stil.schreibe(ci, Vector2(16, ci.size.y / 2.0), "Bauleiste [B]", Stil.KLEIN, farbe)


func _male_konsole(ci: Control) -> void:
	if ci.size.x < 60.0:
		return   # noch nicht ausgemessen (erstes Bild)
	var w := ci.size.x
	var h := ci.size.y
	var t := _jetzt()
	# Sockel mit schrägen Schultern, der aus dem unteren Bildrand wächst
	var aussen := PackedVector2Array([Vector2(0, h), Vector2(14, 16), Vector2(36, 4), Vector2(w - 36, 4), Vector2(w - 14, 16), Vector2(w, h)])
	var innen := PackedVector2Array([Vector2(3, h), Vector2(16, 17), Vector2(37, 6), Vector2(w - 37, 6), Vector2(w - 16, 17), Vector2(w - 3, h)])
	ci.draw_colored_polygon(aussen, Stil.RAHMEN)
	ci.draw_colored_polygon(innen, Stil.METALL_DUNKEL)
	# Leuchtlinie oben (im Kampf gedimmt)
	var licht := Stil.LEUCHT if _bauphase else Stil.LEUCHT.darkened(0.6)
	if entwurf == "b":
		_male_lauflicht(ci, w, t)
	else:
		ci.draw_rect(Rect2(Vector2(40, 6), Vector2(w - 80, 1)), licht)
	# Nieten an den Schultern
	for p: Vector2 in [Vector2(9, h - 6), Vector2(w - 10, h - 6)]:
		ci.draw_rect(Rect2(p, Vector2(1, 1)), Stil.RAHMEN_HELL)
	if entwurf == "a":
		_male_monitor(ci, Rect2(Vector2(13, 15), Vector2(28, 26)), t)
	else:
		_male_kabel(ci, w, h, t)


## Entwurf a: kleiner Bildschirm auf der linken Schulter – zeigt das Bauwerk unter der Maus bzw. das gewählte, sonst Radar.
var _monitor_typ := Karte.FREI

func _male_monitor(ci: Control, r: Rect2, t: float) -> void:
	ci.draw_rect(r, Stil.RAHMEN)
	var schirm := r.grow(-2.0)
	ci.draw_rect(schirm, Color("0b1a20"))
	var m := schirm.get_center()
	if kacheln.has(_monitor_typ) and (kacheln[_monitor_typ] as Kachel).bild != null:
		var flimmern := 0.92 + 0.08 * sin(t * 23.0)
		Stil.bild(ci, (kacheln[_monitor_typ] as Kachel).bild, m, 2, Color(0.8 * flimmern, 1.05 * flimmern, 1.1 * flimmern))
	else:
		# Radar: Kreis, umlaufender Strahl, ein paar Punkte (im Kampf schneller)
		var rad := 9.0
		ci.draw_arc(m, rad, 0.0, TAU, 24, Stil.LEUCHT.darkened(0.55), 1.0)
		ci.draw_arc(m, rad * 0.5, 0.0, TAU, 16, Stil.LEUCHT.darkened(0.7), 1.0)
		var winkel := t * (2.0 if _bauphase else 4.5)
		ci.draw_line(m, m + Vector2(cos(winkel), sin(winkel)) * rad, Stil.LEUCHT, 1.0)
		for i in 3:
			var a := float(i) * 2.1 + 0.6
			var hell := clampf(1.0 - fposmod(winkel - a, TAU) / 2.5, 0.0, 1.0)
			ci.draw_rect(Rect2(m + Vector2(cos(a), sin(a)) * rad * (0.4 + i * 0.2) - Vector2(0.5, 0.5), Vector2(1, 1)), Color(Stil.KUPFER, hell))
	# Abtastlinien
	var y := schirm.position.y
	while y < schirm.end.y:
		ci.draw_rect(Rect2(Vector2(schirm.position.x, y), Vector2(schirm.size.x, 0.5)), Color(0, 0, 0, 0.35))
		y += 1.5


## Entwurf b: Lichtpuls läuft über die Leuchtleiste; beim Wellenstart rasen drei Pulse zum Start-Emblem.
func _male_lauflicht(ci: Control, w: float, t: float) -> void:
	var x0 := 40.0
	var lang := w - 80.0
	ci.draw_rect(Rect2(Vector2(x0, 6), Vector2(lang, 1)), Stil.LEUCHT.darkened(0.55 if _bauphase else 0.75))
	var start_puls := t - _kampf_seit < 1.6
	var pulse: Array = []
	if start_puls:
		for i in 3:
			pulse.append(fmod((t - _kampf_seit) * 1.8 + i * 0.18, 1.0))
	elif _bauphase:
		pulse.append(fmod(t / 2.6, 1.0))
	for f: float in pulse:
		var x := x0 + f * lang
		for k in 6:
			var hell := 1.0 - k / 6.0
			ci.draw_rect(Rect2(Vector2(x - k * 2.0, 6), Vector2(2, 1)), Color(Stil.LEUCHT.lightened(0.3), hell))


## Entwurf b: zwei Kabel von der rechten Schulter am Boden entlang zum Start-Emblem, mit wanderndem Lichtpunkt.
func _male_kabel(ci: Control, w: float, h: float, t: float) -> void:
	var ziel := start.position - _konsole.position + Vector2(8.0, start.size.y - 4.0)
	# Anschlusskasten an der rechten Schulter
	ci.draw_rect(Rect2(Vector2(w - 26, h - 16), Vector2(12, 8)), Stil.RAHMEN)
	ci.draw_rect(Rect2(Vector2(w - 25, h - 15), Vector2(10, 6)), Stil.METALL)
	ci.draw_rect(Rect2(Vector2(w - 22, h - 13), Vector2(4, 2)), Stil.LEUCHT if _bauphase else Stil.LEUCHT.darkened(0.5))
	for n in 2:
		var y := h - 4.0 + n * 2.0
		var punkte := PackedVector2Array([Vector2(w - 20, h - 8), Vector2(w - 20 + n * 2, y), Vector2(ziel.x - 6 + n * 2, y), Vector2(ziel.x - 6 + n * 2, ziel.y)])
		ci.draw_polyline(punkte, Stil.METALL_TIEF, 2.0)
		ci.draw_polyline(punkte, Stil.RAHMEN, 1.0)
	# wandernder Punkt (beim Wellenstart schnell)
	var tempo_f := 1.6 if t - _kampf_seit < 1.6 else 0.35
	var f := fmod(t * tempo_f, 1.0)
	var x := lerpf(w - 20.0, ziel.x - 6.0, f)
	ci.draw_rect(Rect2(Vector2(x - 1.0, h - 4.5), Vector2(2, 1)), Stil.LEUCHT if (_bauphase or t - _kampf_seit < 1.6) else Stil.LEUCHT.darkened(0.6))


func _male_tipp(ci: Control) -> void:
	var rand := Stil.ROT if _tipp_warnung else Stil.RAHMEN
	# 18.11.: Meldungen nach Art gefärbt – Geld gold, Ereignisse kupfern (Rand, leichter Schimmer, Leiste links)
	var art := str(spiel._meldung_art) if spiel._meldung_zeit > 0.0 and _tipp_text == spiel._meldung and not _tipp_warnung else ""
	var farbe := Stil.GOLD if art == "geld" else Stil.KUPFER
	if art != "":
		rand = farbe
	Stil.platte(ci, Rect2(Vector2.ZERO, ci.size), 3.0, Stil.METALL_DUNKEL.lerp(farbe, 0.1) if art != "" else Stil.METALL_DUNKEL, rand)
	if art != "":
		ci.draw_rect(Rect2(2, 3, 1, ci.size.y - 6.0), farbe)
	var y := 4.0
	if _tipp_titel != "":
		Stil.schreibe(ci, Vector2(6, y + 4.0), _tipp_titel, Stil.NORMAL, Stil.LEUCHT)
		y += 11.0
	Stil.absatz(ci, Vector2(6, y), _tipp_text, 220.0, Stil.KLEIN, Stil.WARN if _tipp_warnung else (Stil.TEXT.lerp(farbe, 0.35) if art != "" else Stil.TEXT))


func _male_start(ci: Control) -> void:
	var m := ci.size / 2.0
	var bereit: bool = not (ci as Emblem).disabled
	if _start_bild != null:
		if bereit:
			# bereit: pulsiert sanft, unter der Maus heller
			var puls := 0.92 + 0.08 * sin(_jetzt() * 3.0)
			if (ci as Emblem).is_hovered():
				puls = 1.15
			Stil.bild(ci, _start_bild, m, 3, Color(puls, puls, puls))
		else:
			Stil.bild(ci, _start_laeuft if _start_laeuft != null else _start_bild, m, 3, Color(1, 1, 1) if _start_laeuft != null else Color(0.45, 0.45, 0.5))
		return
	var farbe := Stil.LEUCHT if bereit else Stil.TEXT_BLASS
	if bereit:
		Stil.symbol(ci, "play", m + Vector2(1, -7), 2.0, farbe)
		Stil.schreibe_mittig(ci, m + Vector2(0, 7), "Angriff" if _angreifer else "Start", Stil.NORMAL, farbe)
		Stil.schreibe_mittig(ci, m + Vector2(0, 15), "Leer", Stil.KLEIN, Stil.TEXT_BLASS)
	else:
		Stil.schreibe_mittig(ci, m, "läuft", Stil.NORMAL, farbe)


func _male_tempo(ci: Control) -> void:
	# Vorspul-Pfeile (einer je Stufe leuchtet) und darunter die Stufe: man sieht, dass hier das Tempo sitzt
	var stufe := roundi(spiel._tempo_faktor)
	var m := ci.size / 2.0
	for i in 3:
		var farbe := Stil.LEUCHT if i < stufe else Stil.RAHMEN_HELL
		var x := m.x - 7.0 + i * 5.0
		for k in 4:
			ci.draw_rect(Rect2(Vector2(x + k * 0.5, m.y - 6.0 + k), Vector2(1, 1)), farbe)
			ci.draw_rect(Rect2(Vector2(x + k * 0.5, m.y - 1.0 - k), Vector2(1, 1)), farbe)
	Stil.schreibe_mittig(ci, m + Vector2(0, 6), "×%d" % stufe, Stil.KLEIN, Stil.LEUCHT if stufe > 1 else Stil.TEXT)


func _male_menue(ci: Control) -> void:
	Stil.symbol(ci, "menue", ci.size / 2.0, 2.0, Stil.ROT if (ci as Emblem).warnt else Stil.TEXT)


# ------------------------------------------------------------------ Knöpfe oben rechts

func _lexikon_klick() -> void:
	spiel._nachschlag.visible = false
	spiel._lexikon.umschalten()


func _formationen_klick() -> void:
	spiel._lexikon.visible = false
	spiel._nachschlag.umschalten()


func _schadensliste_klick() -> void:
	if is_instance_valid(schadensliste) and schadensliste.get("per_knopf") != null:
		schadensliste.set("per_knopf", not bool(schadensliste.get("per_knopf")))


# ------------------------------------------------------------------ Pausenmenü (16.11.)
## Knopf oben rechts oder [Esc]: Das Spiel hält an, in der Mitte erscheint das Menü – Weiter, Neustart, Einstellungen,
## Hauptmenü. Die Oberfläche läuft weiter (process_mode ALWAYS), das Spiel steht (get_tree().paused).

## Schlichter Knopf auf einer Metallplatte (Pausenmenü).
class Tafelknopf extends Button:
	const Stil := preload("res://scripts/ui/ui_stil.gd")
	var beschriftung := ""
	func _draw() -> void:
		var drueber := is_hovered() and not disabled
		var rand := Stil.LEUCHT if drueber else Stil.RAHMEN
		Stil.platte(self, Rect2(Vector2.ZERO, size), 3.0, Stil.METALL if drueber else Stil.METALL_DUNKEL, rand)
		var farbe := Stil.TEXT_BLASS.darkened(0.3) if disabled else (Stil.LEUCHT if drueber else Stil.TEXT)
		Stil.schreibe_mittig(self, size / 2.0, beschriftung, Stil.NORMAL, farbe)


var _pause: Control
var _pause_tafel: Malflaeche
var _pause_titel := "Pause"
var _pause_knoepfe: Array[Tafelknopf] = []
var _einstellungen := false
var _code_feld: LineEdit   # 20.11.: unsichtbares Eingabefeld für Entwicklercodes (Einstellungen), gezeichnet wird der Knopf
# 19.11. (Paul, Handy: Run mitten in der Runde verloren): Das Pause-Menü geht im Kampf von selbst auf, wenn die Seite den
# Fokus verliert – ein Tipp, der gerade unterwegs war, traf dann „Hauptmenü“ oder „Neustart“. Deshalb: kurze Sperre nach
# dem Aufgehen, und beide Knöpfe fragen nach (zweiter Tipp innerhalb weniger Sekunden).
const PAUSE_SPERRE_MS := 700
const SICHER_FRIST_MS := 4000
var _pause_seit_ms := 0
var _sicher_was := ""
var _sicher_ms := 0


func _baue_pause() -> void:
	_pause = ColorRect.new()
	(_pause as ColorRect).color = Color(0, 0, 0, 0.55)
	_pause.size = Vector2(BREITE, HOEHE)
	_pause.mouse_filter = Control.MOUSE_FILTER_STOP   # nichts dahinter anklicken
	_pause.visible = false
	wurzel.add_child(_pause)
	_pause_tafel = Malflaeche.new()
	_pause_tafel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pause_tafel.malen = func(ci: Control):
		Stil.platte(ci, Rect2(Vector2.ZERO, ci.size), 6.0)
		ci.draw_rect(Rect2(Vector2(10, 3), Vector2(ci.size.x - 20.0, 1)), Stil.LEUCHT)
		Stil.schreibe_mittig(ci, Vector2(ci.size.x / 2.0, 16.0), _pause_titel, Stil.GROSS, Stil.TEXT)
	_pause.add_child(_pause_tafel)
	_code_feld = LineEdit.new()   # 20.11.
	_code_feld.max_length = 32
	_code_feld.modulate = Color(1, 1, 1, 0)
	_code_feld.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_code_feld.position = Vector2(-400, -400)
	_code_feld.size = Vector2(200, 30)
	_code_feld.context_menu_enabled = false
	_code_feld.text_changed.connect(func(_t: String) -> void: _einstellungsseite())
	_code_feld.text_submitted.connect(func(_t: String) -> void: _loese_code())
	_pause.add_child(_code_feld)
	process_mode = Node.PROCESS_MODE_ALWAYS   # Oberfläche bedienbar, während das Spiel pausiert


func _pause_zeige(eintraege: Array) -> void:
	for k in _pause_knoepfe:
		k.queue_free()
	_pause_knoepfe.clear()
	var bw := 130.0
	var bh := 18.0
	var y := 34.0
	for e: Array in eintraege:
		if e.size() >= 3:
			# Regler (16.11.): [Text, lauter, leiser] – links −, in der Mitte der Wert, rechts +
			var teile := [["−", e[2], Vector2(15.0, y), Vector2(bh, bh)], [e[0], null, Vector2(15.0 + bh + 3.0, y), Vector2(bw - 2.0 * (bh + 3.0), bh)], ["+", e[1], Vector2(15.0 + bw - bh, y), Vector2(bh, bh)]]
			for t: Array in teile:
				var r := Tafelknopf.new()
				Stil.leerer_knopf(r)
				r.beschriftung = t[0]
				r.position = t[2]
				r.size = t[3]
				if t[1] == null:
					r.mouse_filter = Control.MOUSE_FILTER_IGNORE   # nur Anzeige, nicht ausgegraut
				else:
					r.pressed.connect(t[1])
				_pause_tafel.add_child(r)
				_pause_knoepfe.append(r)
			y += bh + 5.0
			continue
		var k := Tafelknopf.new()
		Stil.leerer_knopf(k)
		k.beschriftung = e[0]
		k.size = Vector2(bw, bh)
		k.position = Vector2(15.0, y)
		if e[1] == null:
			k.disabled = true
		else:
			k.pressed.connect(e[1])
		_pause_tafel.add_child(k)
		_pause_knoepfe.append(k)
		y += bh + 5.0
	_pause_tafel.size = Vector2(bw + 30.0, y + 9.0)
	_pause_tafel.position = ((Vector2(BREITE, HOEHE) - _pause_tafel.size) / 2.0).round()
	_pause_tafel.queue_redraw()


func pause_an() -> void:
	if _pause.visible:
		return
	if wiedereinstieg_offen():
		_wieder.visible = false   # 21.11.: das Pausenmenü übernimmt („Weiter“ per Klick fängt Maus und Vollbild)
		get_tree().paused = _wieder_war_pausiert
	_pause.visible = true
	_pause_seit_ms = Time.get_ticks_msec()
	_sicher_was = ""
	get_tree().paused = true
	if spiel.get("_zoom_grund") != null:
		spiel._zoom_grund.visible = false   # das Spiel steht: main blendet ihn erst danach wieder ein
	if spiel.get("_laufband") != null and spiel._laufband.visible:
		spiel._laufband.visible = false   # 18.11.: Taktikplaner nicht über dem Pause-Menü; main holt ihn danach zurück
		spiel._laufband_vor_pause = true
	_hauptseite()


## 18.11.: Fenster verliert den Fokus (Alt+Tab, anderer Browser-Tab, Handy: App im Hintergrund) → im Kampf pausieren.
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		if _pause != null and spiel != null and spiel.phase == KAMPF:
			pause_an()


func pause_aus() -> void:
	_code_feld.release_focus()   # 20.11.
	_pause.visible = false
	get_tree().paused = false
	if _voll_zurueck:
		wiedereinstieg_zeigen()   # 21.11.: Vollbild ging in der Pause verloren – erst ein Klick holt es zurück


## 21.11.: „Weiter“ per Klick ist eine Nutzergeste – ein im Web verlorenes Vollbild kommt gleich mit zurück.
func _weiter() -> void:
	if _voll_zurueck:
		_voll_zurueck = false
		Werte.setze_vollbild(true)
	pause_aus()


func pausiert() -> bool:
	return _pause != null and _pause.visible


# ------------------------------------------------------------------ Wiedereinstieg im Web (21.11.)
## Der Browser beendet bei Esc Vollbild und Mausfang (Pointer Lock). Neu fangen darf nur eine Nutzergeste – deshalb
## steht das Spiel dann, und die Tafel „Klicken zum Fortsetzen“ wartet auf den Klick. Der Klick holt Vollbild und Maus
## zurück. Den Mausfang meldet die Ego-Sicht (ego_modus.gd), das Vollbild prüft _process hier.
var _wieder: Control
var _wieder_war_pausiert := false
var _voll_gesehen := false   # war das Vollbild seit dem letzten Einschalten wirklich an?
var _voll_zurueck := false   # beim Klick wieder ins Vollbild


func _baue_wiedereinstieg() -> void:
	var ebene := CanvasLayer.new()
	ebene.layer = 100   # über der Ego-Sicht (Ebene 2) und ihrem Ringterminal
	add_child(ebene)
	_wieder = ColorRect.new()
	(_wieder as ColorRect).color = Color(0, 0, 0, 0.55)
	_wieder.size = Vector2(BREITE, HOEHE)
	_wieder.scale = Vector2(2, 2)
	_wieder.mouse_filter = Control.MOUSE_FILTER_STOP
	_wieder.visible = false
	_wieder.gui_input.connect(_wiedereinstieg_klick)
	ebene.add_child(_wieder)
	var tafel := Malflaeche.new()
	tafel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var titel := "Klicken zum Fortsetzen"
	var zeile := "Maus und Vollbild werden wieder eingefangen"
	tafel.size = Vector2(maxf(Stil.breite(titel, Stil.GROSS), Stil.breite(zeile, Stil.KLEIN)) + 30.0, 52.0).round()
	tafel.position = ((Vector2(BREITE, HOEHE) - tafel.size) / 2.0).round()
	tafel.malen = func(ci: Control):
		Stil.platte(ci, Rect2(Vector2.ZERO, ci.size), 6.0)
		ci.draw_rect(Rect2(Vector2(10, 3), Vector2(ci.size.x - 20.0, 1)), Stil.LEUCHT)
		Stil.schreibe_mittig(ci, Vector2(ci.size.x / 2.0, 19.0), titel, Stil.GROSS, Stil.TEXT)
		Stil.schreibe_mittig(ci, Vector2(ci.size.x / 2.0, 37.0), zeile, Stil.KLEIN, Stil.TEXT_BLASS)
	_wieder.add_child(tafel)


func wiedereinstieg_offen() -> bool:
	return _wieder != null and _wieder.visible


## Spiel anhalten und auf den Klick warten. Steht das Pausenmenü offen, übernimmt das (sein Klick auf „Weiter“ fängt).
func wiedereinstieg_zeigen() -> void:
	if _wieder == null or _wieder.visible or pausiert():
		return
	_wieder_war_pausiert = get_tree().paused
	_wieder.visible = true
	get_tree().paused = true


func _wiedereinstieg_klick(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and (event as InputEventMouseButton).pressed):
		return
	_wieder.accept_event()
	_wieder.visible = false
	get_tree().paused = _wieder_war_pausiert
	# Jetzt ist eine Nutzergeste da: Vollbild und Mausfang dürfen angefordert werden
	if _voll_zurueck:
		_voll_zurueck = false
		Werte.setze_vollbild(true)
	if spiel != null and is_instance_valid(spiel.ego):
		spiel.ego.fange_maus()


func _process(_delta: float) -> void:
	if not OS.has_feature("web") or _wieder == null:
		return
	if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN:
		_voll_gesehen = true
		return
	if not (_voll_gesehen and Werte.vollbild):
		_voll_gesehen = false
		return
	# Vollbild verloren (Esc oder langes Esc im Browser), ohne dass das Spiel es ausgeschaltet hat
	_voll_gesehen = false
	Werte.vollbild = false   # Anzeige = echter Zustand, bis der Klick es zurückholt
	_voll_zurueck = true
	if pausiert():
		if _einstellungen:
			_einstellungsseite()
	else:
		wiedereinstieg_zeigen()


func _hauptseite() -> void:
	if _code_feld != null:
		_code_feld.release_focus()   # 20.11.
	_einstellungen = false
	_pause_titel = "Pause"
	var neu := "Nochmal angreifen" if spiel.phantom_modus == "angriff" else "Neustart"
	var fragt := Time.get_ticks_msec() - _sicher_ms <= SICHER_FRIST_MS
	_pause_zeige([
		["Weiter", _weiter],
		["Sicher? Nochmal tippen" if fragt and _sicher_was == "neustart" else neu, _nachfragen.bind("neustart")],
		["Einstellungen", _einstellungsseite],
		["Sicher? Nochmal tippen" if fragt and _sicher_was == "menue" else ("Zurück in den Editor" if SzenarioEditor.testet else "Hauptmenü"), _nachfragen.bind("menue")],   # 20.11.: beim Szenario-Test ausdrücklich
	])


## Neustart und Hauptmenü beenden die laufende Partie: erster Tipp fragt nach, der zweite (innerhalb der Frist) führt aus.
func _nachfragen(was: String) -> void:
	var jetzt := Time.get_ticks_msec()
	if jetzt - _pause_seit_ms < PAUSE_SPERRE_MS:
		return   # Tipp, der schon unterwegs war, als das Menü aufging
	if _sicher_was == was and jetzt - _sicher_ms <= SICHER_FRIST_MS:
		_sicher_was = ""
		get_tree().paused = false
		if was == "neustart":
			spiel._neustart()
		else:
			spiel._zum_menue()
		return
	_sicher_was = was
	_sicher_ms = jetzt
	_hauptseite()


func _einstellungsseite() -> void:
	_einstellungen = true
	_pause_titel = "Einstellungen"
	_pause_zeige([
		["Vollbild: %s" % ("an" if Werte.vollbild else "aus"), func():
			Werte.setze_vollbild(not Werte.vollbild)
			Werte.speichere_einstellungen()
			_einstellungsseite()],
		["Ansicht: %s [V]" % ("Draufsicht" if spiel.hd != null and spiel.hd.ist_draufsicht() else "schräg"), (func():
			spiel.hd.draufsicht_umschalten()
			_einstellungsseite()) if spiel.hd != null else null],
		["Musik: %s" % _prozent(Werte.musik), func(): _lautstaerke("musik", 10), func(): _lautstaerke("musik", -10)],
		["Geräusche: %s" % _prozent(Werte.toene), func(): _lautstaerke("toene", 10), func(): _lautstaerke("toene", -10)],
		["Code: " + (_code_feld.text + "_" if _code_feld.has_focus() else (_code_feld.text if _code_feld.text != "" else "–")), _code_tippen],   # 20.11.: Entwicklercodes
		["Einlösen", _loese_code],
		["Zurück", _hauptseite],
	])


## 20.11.: Entwicklercode – Knopf „Code“ aktiviert das Eingabefeld (am Handy das Eingabefenster des Browsers).
func _code_tippen() -> void:
	if OS.has_feature("web") and DisplayServer.is_touchscreen_available():
		var antwort: Variant = JavaScriptBridge.eval("window.prompt(%s, %s)" % [JSON.stringify("Code:"), JSON.stringify(_code_feld.text)], true)
		if antwort is String:
			_code_feld.text = (antwort as String).strip_edges()
	else:
		_code_feld.grab_focus()
		_code_feld.caret_column = _code_feld.text.length()
	_einstellungsseite()


func _loese_code() -> void:
	_code_feld.release_focus()
	if Profil.code_einloesen(_code_feld.text):
		_code_feld.text = ""
	_einstellungsseite()


static func _prozent(p: int) -> String:
	return "aus" if p <= 0 else "%d %%" % p


func _lautstaerke(was: String, d: int) -> void:
	if was == "musik":
		Werte.musik = clampi(Werte.musik + d, 0, 100)
		Musik.lautstaerke(get_tree())
	else:
		Werte.toene = clampi(Werte.toene + d, 0, 100)
	Werte.speichere_einstellungen()
	_einstellungsseite()


func _unhandled_input(event: InputEvent) -> void:
	if not pausiert():
		return
	if event is InputEventKey and event.pressed and not event.echo and ((event as InputEventKey).keycode == KEY_ESCAPE \
			or ((event as InputEventKey).keycode == KEY_P and OS.has_feature("web"))):
		if _einstellungen:
			_hauptseite()
		else:
			pause_aus()
		get_viewport().set_input_as_handled()


# ------------------------------------------------------------------ Zuweisungspfeil (HD-2D)
## Wie früher in 2D: kräftiger Pfeil mit Spitze, Einrastrahmen auf der Stellung. In HD-2D lag er auf dem Boden und
## verschwand unter den Mauern – jetzt im Bild, oben auf der Mauerkrone. Dazu laufen Lichtpunkte zum Ziel.
var _warnung: Control

func _male_schleuder_warnung() -> void:
	if spiel == null or spiel.im_kampf():
		return
	_male_turm_stuetzen()
	_male_formvorlage()
	var t := _jetzt()
	for b: Zonenbau in spiel.zonenbauten:
		if not is_instance_valid(b) or b.art != "schleuder" or (b.bedroht.is_empty() and not b.bedroht_vorschau):
			continue
		var warn: bool = b.bedroht_vorschau
		var hoch := 74.0 if spiel.hd != null else 64.0
		var m: Vector2 = spiel.welt_zu_bild(b.position) + Vector2(0, -hoch - 4.0 * absf(sin(t * (8.0 if warn else 3.0))))
		var gr := 15.0 if warn else 12.0
		var farbe := Color(1.0, 0.42, 0.2) if warn else Stil.KUPFER
		# Warnschild: Raute mit dunklem Rand, darin ein „!“
		var raute := PackedVector2Array([m + Vector2(0, -gr), m + Vector2(gr, 0), m + Vector2(0, gr), m + Vector2(-gr, 0)])
		var rand := PackedVector2Array([m + Vector2(0, -gr - 3), m + Vector2(gr + 3, 0), m + Vector2(0, gr + 3), m + Vector2(-gr - 3, 0)])
		_warnung.draw_colored_polygon(rand, Color(0.06, 0.05, 0.08, 0.85))
		_warnung.draw_colored_polygon(raute, farbe)
		_warnung.draw_rect(Rect2(m + Vector2(-2, -gr * 0.55), Vector2(4, gr * 0.7)), Color(0.08, 0.05, 0.04))
		_warnung.draw_rect(Rect2(m + Vector2(-2, gr * 0.3), Vector2(4, 4)), Color(0.08, 0.05, 0.04))
		if warn:
			var txt := "Schleuder trifft hier!"
			Stil.schreibe_mittig(_warnung, m + Vector2(0, -gr - 14.0), txt, Stil.NORMAL, Color.WHITE)


func _male_zuweisung() -> void:
	if spiel.hd == null:
		return
	var k: Karte = spiel.karte
	if k.zuweis_fabrik == Karte.KEINE:
		return
	var von: Vector2 = spiel.welt_zu_bild(k.mitte(k.zuweis_fabrik))
	for w: Vector2i in k.zuweis_ziele:
		var nach: Vector2 = spiel.welt_zu_bild(k.mitte(w))
		_pfeil_bild(von, nach, Stil.GOLD, 1.0)
		_einrasten_bild(nach, Stil.GOLD)
	if k.zuweis_einrast != Karte.KEINE:
		var nach: Vector2 = spiel.welt_zu_bild(k.mitte(k.zuweis_einrast))
		_pfeil_bild(von, nach, Color(1, 0.95, 0.75), 1.0)
		_einrasten_bild(nach, Color.WHITE)
	elif k.zuweis_zug != Vector2.INF:
		_pfeil_bild(von, _zuweis.get_local_mouse_position(), Color(1, 0.83, 0.3), 0.75)


func _pfeil_bild(von: Vector2, nach: Vector2, farbe: Color, deckung: float) -> void:
	var r := nach - von
	if r.length() < 20.0:
		return
	var n := r.normalized()
	var q := Vector2(-n.y, n.x)
	var anfang := von + n * 16.0
	var spitze := nach - n * 18.0
	var dunkel := Color(0.06, 0.05, 0.08, 0.75 * deckung)
	_zuweis.draw_line(anfang, spitze, dunkel, 9.0)
	_zuweis.draw_line(anfang, spitze, Color(farbe, deckung), 5.0)
	var kopf := PackedVector2Array([nach - n * 4.0, spitze - n * 8.0 + q * 11.0, spitze - n * 8.0 - q * 11.0])
	var kopf_rand := PackedVector2Array([nach + n * 0.0, spitze - n * 11.0 + q * 14.0, spitze - n * 11.0 - q * 14.0])
	_zuweis.draw_colored_polygon(kopf_rand, dunkel)
	_zuweis.draw_colored_polygon(kopf, Color(farbe, deckung))
	# Lichtpunkte, die zum Ziel wandern
	var lang := (spitze - anfang).length()
	var t := fmod(_jetzt() * 90.0, 26.0)
	var d := t
	while d < lang - 6.0:
		_zuweis.draw_circle(anfang + n * d, 2.0, Color(1, 1, 1, 0.8 * deckung))
		d += 26.0


func _einrasten_bild(m: Vector2, farbe: Color) -> void:
	var h := 22.0
	var dunkel := Color(0.06, 0.05, 0.08, 0.7)
	for e: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		var ecke := m + e * h
		for f: Array in [[dunkel, 6.0], [farbe, 3.0]]:
			_zuweis.draw_line(ecke, ecke - Vector2(e.x * 10.0, 0), f[0], f[1])
			_zuweis.draw_line(ecke, ecke - Vector2(0, e.y * 10.0), f[0], f[1])
