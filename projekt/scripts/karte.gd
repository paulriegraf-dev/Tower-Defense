class_name Karte
extends Node2D
## Das Raster: was wo steht, wie es aussieht und wer welchen Weg nimmt.

signal zerstoert(zelle: Vector2i, typ: int)
signal ausgefallen_ist(zelle: Vector2i, typ: int)

## FREI/WALL/FABRIK stehen im Raster; STELLUNG und TURM sind Ausbauten eines Erdwalls.
enum { FREI, WALL, FABRIK, STELLUNG, TURM, BATTERIE, TOR, PANZER, SPIEGEL, MAGNET, GENERATOR, KOMMANDANT }   # PANZER ist nur Bauwerkzeug; SPIEGEL und MAGNET sind Ausbauten

const NACHBARN: Array[Vector2i] = [Vector2i.LEFT, Vector2i.UP, Vector2i.DOWN, Vector2i.RIGHT]
const KEINE := Vector2i(-1, -1)

var feld: Dictionary = {}          # Zelle -> WALL / FABRIK
var gelaende: Dictionary = {}      # 18.11.: Zelle -> "fels" / "wasser" (aus der Karten-Datei; weder begehbar noch bebaubar)
var fest: Dictionary = {}          # 18.11.: vorgebaute Erdwälle der Karte -> true (ausbaubar, nicht abreißbar)
var boden: Dictionary = {}         # 18.11. (Etappe 2): Zelle -> Gelände mit Wirkung (Werte.BODEN_ARTEN), begehbar
var leben: Dictionary = {}         # Zelle -> Lebenspunkte des Gebäudes
var ausbau: Dictionary = {}        # Wall-Zelle -> STELLUNG / TURM / TOR
var turm_art: Dictionary = {}      # Turm-Zelle -> Schlüssel in Werte.TURMARTEN (aus der Form der Nachbarwälle)
var turm_stufe: Dictionary = {}    # Turm-Zelle -> Stufe 2 oder 3 (fehlt = Stufe 1)
var turm_faehigkeit: Dictionary = {}   # Turm-Zelle -> gewählte Stufe-3-Fähigkeit (Schlüssel in Werte.TURM_STUFE_3)
# Neue Grafik (16.11.): Stufe, letzter Schuss und Blickrichtung je Batterie (vom Spiel gesetzt)
var batterie_stufe_neu: Dictionary = {}
var batterie_schuss: Dictionary = {}   # Batterie-Zelle -> Sekunden seit dem Schuss (fehlt = Ruhe)
var batterie_blick: Dictionary = {}    # Batterie-Zelle -> true = nach links
var _neu_bilder: Dictionary = {}
var generator_paar: Dictionary = {}   # Schildgenerator: Feld -> sein zweites Feld (beide Richtungen)
var kuppeln: Array = []              # aktive Schildkuppeln: [Mitte, Radius in Pixeln, Generatorfeld]
var _hoefe: Array = []               # Höfe: je eine Liste der Felder (frei oder mit Gebäude), rundum von Erdwällen eingeschlossen
var magnet_richtung: Dictionary = {}   # Magnet-Zelle -> Richtung seiner Zuglinie
var vorschau_richtung := Vector2i.RIGHT   # Bauvorschau des Magneten
var panzer: Dictionary = {}        # gepanzerte Erdwälle -> true (die erste Sprengung nimmt nur die Panzerung)
var stuetzen: Dictionary = {}      # Turm-Zelle -> die Erdwälle, die ihn stützen (Array[Vector2i])
var stuetze_von: Dictionary = {}   # Erdwall -> Zelle des Turms, den er stützt (jeder Wall stützt höchstens einen)
var turm_schaden: Dictionary = {}  # Turm-Zelle -> Schaden durch Myr-Drohnen in dieser Runde
var posten: Dictionary = {}        # Stellungs-Zelle -> Einheit, die darauf steht
var besatzung: Dictionary = {}     # Batterie-Zelle -> Einheiten, die dorthin gehören (unterwegs oder schon drin)
var fabrik_typ: Dictionary = {}    # Fabrik-Zelle -> Einheitentyp, den sie baut
var fabrik_stufe: Dictionary = {}  # Fabrik-Zelle -> Ausbaustufe (0 = Grundfabrik)
var paar: Dictionary = {}          # Batterie <-> ihre Pilotenfabrik (beide Richtungen)
var ausgefallen: Dictionary = {}   # zerschossene Fabriken und Batterien: stehen noch, arbeiten aber erst nächste Runde wieder
var vorschau_partner := KEINE      # Bauvorschau der Batterie: das Feld ihrer Pilotenfabrik
var fortschritt: Dictionary = {}   # Fabrik-Zelle -> 0..1 (Produktionsbalken)

var checkpoints: Array[Vector2i] = []
var basis := Werte.BASIS_ZELLE:     # eigene Basis: dorthin wollen die Gegner (Sandbox: frei wählbar)
	set(neu):
		var alt := basis
		basis = neu
		if _astar_einheiten != null:
			for z in basis_felder(alt) + basis_felder(neu):
				if in_karte(z):
					_gewichte_fuer(z)
var cp_route := Werte.CP_ROUTE_AB_START   # Der Gegnerweg führt schon vor CHECKPOINTS_AB_WELLE durch die Checkpoints (ohne Einnahme)
var cp_aktiv := false              # Checkpoints sind erst ab Werte.CHECKPOINTS_AB_WELLE im Spiel
var cp_feind: Array[bool] = []     # je Checkpoint: vom Gegner eingenommen?
var cp_fortschritt: Array[float] = []   # je Checkpoint: Sekunden der laufenden Rückeroberung
var cp_einnahme: Array[float] = []      # je Checkpoint: Sekunden der laufenden Einnahme durch den Gegner
var cp_tempo: Array[float] = []    # je Checkpoint: hält ihn gerade ein Gegner? (0 = nein, 1 = normal, 2 = Fahnenträger)

var pfad: Array[Vector2i] = []     # Weg der nächsten Welle: Start -> Checkpoints -> Basis (ab Mitte der Zone)
var neben_pfade: Array = []        # dasselbe vom oberen und unteren Rand der Zone
var schild := true                 # Schutzschild über der Zone des Gegners (fällt in der letzten Runde)
var zeige_schwachstelle := false   # (nicht mehr benutzt: Sprengziele werden in der Bauphase nicht mehr verraten)
var _ersparnis: Dictionary = {}    # Wall-Zelle -> so viel kürzer wird der Gegnerweg ohne diesen Wall
var _ersparnis_gueltig := false
var _ersparnis_seite: Dictionary = {}   # [Wall, Feld davor] -> Abkürzung, wenn von dort gesprengt wird
var _sprengvorschau: Array = []
var _sprengvorschau_gueltig := false
var _sprengvorschau_von := KEINE
var sprengziele_aktiv: Array[Vector2i] = []   # Kampf: Erdwälle, auf die gerade ein Sprenger zuläuft (blinken)
var _stueck_von: Dictionary = {}   # Wall-Zelle -> Nummer ihres Wallstücks
var _stuecke_gueltig := false
var _sicht_an := false             # Anzeige der nicht treffbaren Felder für die Auswahl
var _sicht_von := Vector2.ZERO
var _sicht_wall := KEINE
var _sicht_weite := 0.0
var _sicht_in := 0.0
var _sicht_blind: Array[Vector2i] = []
var zeige_angriff := false         # letzte Runde: Fußweg der eigenen Truppen zum HQ zeigen
var angriffs_pfad: Array[Vector2i] = []
var zeige_pfad_kraeftig := true    # Bauphase: deutlich, Kampf: blass

var auswahl := KEINE               # angeklickter Turm oder angeklickte Batterie: Reichweite anzeigen
var vorschau_zelle := KEINE
var vorschau_typ := FREI
var vorschau_ok := false
var vorschau_pfad: Array[Vector2i] = []

var _astar_gegner: Dictionary = {}  # Gegnertyp -> AStarGrid2D (Wälle = teuer)
var _astar_einheiten: AStarGrid2D   # eigene Truppen (Wälle = gesperrt)
var _zeit := 0.0
var _blaetter: Dictionary = {}      # Einheitentyp -> Textur (für das Bild an der Fabrik)


func _ready() -> void:
	position = Vector2(0, Werte.KARTE_OBEN)
	gelaende = Werte.GELAENDE.duplicate()
	boden = Werte.BODEN.duplicate()
	_astar_einheiten = _neues_astar()
	for typ: String in Werte.GEGNER:
		_astar_gegner[typ] = _neues_astar()
	# 18.11.: Fels und Wasser sind für niemanden begehbar (auch nicht einzureißen)
	for z: Vector2i in gelaende:
		_astar_einheiten.set_point_solid(z, true)
		for typ: String in _astar_gegner:
			(_astar_gegner[typ] as AStarGrid2D).set_point_solid(z, true)
	for z in basis_felder(basis):
		if in_karte(z):
			_gewichte_fuer(z)
	var lagen := _zufalls_checkpoints() if Werte.CHECKPOINTS_ZUFAELLIG and not Werte.KARTE_CP_FEST else Werte.CHECKPOINTS.duplicate()
	for i in Werte.CHECKPOINTS.size():
		checkpoints.append(lagen[i])
		cp_feind.append(false)
		cp_fortschritt.append(0.0)
		cp_einnahme.append(0.0)
		cp_tempo.append(0.0)
	aktualisiere_pfad()


func _process(delta: float) -> void:
	_zeit += delta
	for b: Vector2i in batterie_schuss.keys():
		batterie_schuss[b] = float(batterie_schuss[b]) + delta
		if float(batterie_schuss[b]) > 0.8:
			batterie_schuss.erase(b)
	if _sicht_an:
		_sicht_in -= delta
		if _sicht_in <= 0.0:
			_sicht_in = 0.25
			_berechne_blinde_felder()
	queue_redraw()


## Für die angeklickte Truppe / den angeklickten Turm zeigen, welche Felder in Reichweite sie NICHT treffen kann.
## `von` = Standpunkt in Weltkoordinaten, `wall` = Erdwall, auf dem sie steht (KEINE = am Boden), `weite` in Feldern.
func zeige_sicht(an: bool, von: Vector2 = Vector2.ZERO, wall: Vector2i = KEINE, weite: float = 0.0) -> void:
	if an and (not _sicht_an or wall != _sicht_wall or not is_equal_approx(weite, _sicht_weite)):
		_sicht_in = 0.0   # neue Auswahl: sofort rechnen
	_sicht_an = an
	_sicht_von = von
	_sicht_wall = wall
	_sicht_weite = weite
	if not an:
		_sicht_blind.clear()


func _berechne_blinde_felder() -> void:
	_sicht_blind.clear()
	var mitte_zelle := zelle_bei(_sicht_von)
	var r := int(ceil(_sicht_weite)) + 1
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var z := mitte_zelle + Vector2i(dx, dy)
			if not ist_frei(z):
				continue   # nur Felder, auf denen ein Gegner stehen kann
			var punkt := mitte(z)
			if _sicht_von.distance_to(punkt) > _sicht_weite * Werte.ZELLE:
				continue
			var sichtbar := sicht_von_wall(_sicht_wall, _sicht_von, punkt) if _sicht_wall != KEINE else sicht_frei(_sicht_von, punkt)
			if not sichtbar:
				_sicht_blind.append(z)


# ---------------------------------------------------------------- Raster

func in_karte(z: Vector2i) -> bool:
	return z.x >= 0 and z.y >= 0 and z.x < Werte.SPALTEN and z.y < Werte.ZEILEN


func inhalt(z: Vector2i) -> int:
	return feld.get(z, FREI)


func ist_frei(z: Vector2i) -> bool:
	return in_karte(z) and not feld.has(z) and not gelaende.has(z)


## 18.11.: Weglänge auf der leeren Karte (nur Gelände) – Grundlage der Weganzeige „+N durch deine Bauten“.
## Ohne Gelände wie bisher die Luftlinie in Feldern (Manhattan).
var _astar_gelaende: AStarGrid2D = null
var _gelaende_stand := -1

func grund_abstand(von: Vector2i, nach: Vector2i) -> int:
	var luft := absi(nach.x - von.x) + absi(nach.y - von.y)
	if gelaende.is_empty() and fest.is_empty():
		return luft
	# Gelände und die Mauer der Karte zählen nicht als „deine Bauten“ (neu aufbauen, wenn sich die Mauer geändert hat)
	if _astar_gelaende == null or _gelaende_stand != fest.size():
		_gelaende_stand = fest.size()
		_astar_gelaende = _neues_astar()
		for z: Vector2i in gelaende:
			_astar_gelaende.set_point_solid(z, true)
		for z: Vector2i in fest:
			_astar_gelaende.set_point_solid(z, true)
	var weg := _astar_gelaende.get_id_path(von, nach)
	return weg.size() - 1 if not weg.is_empty() else luft


## 18.11.: Szenario-Editor – Gelände eines Felds setzen ("fels", "wasser" oder "" = weg) und die Wegsuche nachziehen.
func setze_gelaende(z: Vector2i, art: String) -> void:
	if not in_karte(z):
		return
	if art == "":
		gelaende.erase(z)
	else:
		gelaende[z] = art
	for typ: String in _astar_gegner:
		(_astar_gegner[typ] as AStarGrid2D).set_point_solid(z, art != "")
	_astar_einheiten.set_point_solid(z, art != "")
	_gewichte_fuer(z)
	if art != "":
		_astar_einheiten.set_point_solid(z, true)
	_astar_gelaende = null
	aktualisiere_pfad()


## 18.11.: Fels versperrt die Sicht wie ein fremder Erdwall, Wasser nicht.
func ist_fels(z: Vector2i) -> bool:
	return gelaende.get(z, "") == "fels"


func ist_bebaubar(z: Vector2i) -> bool:
	return ist_frei(z) and z.x >= Werte.ZONE_SPALTEN and not ist_basis(z) and not checkpoints.has(z) 		and not Werte.BODEN_UNBEBAUBAR.has(str(boden.get(z, "")))   # 18.11.: Sumpf, Brücke, Wald


## 18.11. (Etappe 2): Gelände mit Wirkung an einem Punkt (Weltkoordinaten) bzw. Feld; "" = keins.
func boden_bei(punkt: Vector2) -> String:
	return str(boden.get(zelle_bei(punkt), ""))


## Anhöhe: so viel mehr Reichweite (Felder) für alles, was auf dem Feld steht.
func anhoehe_bonus(z: Vector2i) -> float:
	return Werte.ANHOEHE_BONUS if boden.get(z, "") == "anhoehe" else 0.0


## Sumpf: Tempo-Faktor an einem Punkt (1 = normal).
func sumpf_faktor(punkt: Vector2) -> float:
	return Werte.SUMPF_TEMPO if boden_bei(punkt) == "sumpf" else 1.0


## Versperrt dieses Feld die Sicht? Fels immer, Wald auch (18.11.).
func sperrt_sicht(z: Vector2i) -> bool:
	return gelaende.get(z, "") == "fels" or boden.get(z, "") == "wald"


## Szenario-Editor: Gelände mit Wirkung setzen ("" = weg). Begehbar bleibt es; Wege ändern sich nicht.
func setze_boden(z: Vector2i, art: String) -> void:
	if art == "":
		boden.erase(z)
	else:
		boden[z] = art
	queue_redraw()


## Die eigene Basis belegt 3×2 Felder (16.11.): `basis` ist das untere mittlere Feld (Ziel der Gegner), dazu je eins links
## und rechts sowie die drei Felder dahinter. Begehbar bleiben sie (die Gegner laufen hinein), bebaubar sind sie nicht.
func ist_basis(z: Vector2i) -> bool:
	return absi(z.x - basis.x) <= 1 and z.y <= basis.y and z.y >= basis.y - 1


static func basis_felder(b: Vector2i) -> Array[Vector2i]:
	var liste: Array[Vector2i] = []
	for dy in [-1, 0]:
		for dx in [-1, 0, 1]:
			liste.append(b + Vector2i(dx, dy))
	return liste


## Mittelpunkt einer Zelle in Weltkoordinaten.
func mitte(z: Vector2i) -> Vector2:
	return position + (Vector2(z) + Vector2(0.5, 0.5)) * Werte.ZELLE


func zelle_bei(welt: Vector2) -> Vector2i:
	var p := (welt - position) / Werte.ZELLE
	return Vector2i(floori(p.x), floori(p.y))


func max_leben(typ: int) -> float:
	match typ:
		WALL:
			return Werte.LEBEN_WALL
		BATTERIE:
			return Werte.BATTERIE["leben"]
	return Werte.LEBEN_FABRIK


## Wie viele Truppen sitzen schon in der Batterie auf `z` (ohne die, die noch unterwegs sind)?
func besatzung_drin(z: Vector2i) -> int:
	var n := 0
	for e: Einheit in besatzung.get(z, []):
		if e.in_batterie():
			n += 1
	return n


func setze(z: Vector2i, typ: int) -> void:
	feld[z] = typ
	leben[z] = max_leben(typ)
	if typ == WALL:
		pruefe_stuetzen()   # ein neuer Wall kann einem Turm die fehlende Stütze geben
	_gewichte_fuer(z)
	aktualisiere_pfad()


func entferne(z: Vector2i) -> void:
	feld.erase(z)
	leben.erase(z)
	ausbau.erase(z)
	turm_art.erase(z)
	turm_stufe.erase(z)
	turm_faehigkeit.erase(z)
	magnet_richtung.erase(z)
	if generator_paar.has(z):
		generator_paar.erase(generator_paar[z])
		generator_paar.erase(z)
	panzer.erase(z)
	fest.erase(z)   # 18.11.: eine vorgebaute Mauer, die fällt, ist weg wie jede andere
	besatzung.erase(z)
	fabrik_typ.erase(z)
	posten.erase(z)
	fortschritt.erase(z)
	fabrik_stufe.erase(z)
	ausgefallen.erase(z)
	if paar.has(z):
		paar.erase(paar[z])
		paar.erase(z)
	stuetze_von.erase(z)
	pruefe_stuetzen()
	_gewichte_fuer(z)
	aktualisiere_pfad()


## Ein Gegner beschädigt ein Gebäude. Gibt true zurück, wenn es dabei fällt.
func schade(z: Vector2i, menge: float) -> bool:
	if not feld.has(z):
		return true
	leben[z] -= menge
	if leben[z] > 0.0:
		return false
	var typ: int = feld[z]
	var partner: Vector2i = paar.get(z, KEINE)   # Batterie und Pilotenfabrik fallen gemeinsam
	entferne(z)
	zerstoert.emit(z, typ)
	if partner != KEINE and feld.has(partner):
		var typ2: int = feld[partner]
		entferne(partner)
		zerstoert.emit(partner, typ2)
	return true


## Beschuss durch Schleudern und Fernkämpfer: Fabriken und Batterien werden nicht zerstört, sondern fallen
## für den Rest der Runde aus (samt Partner bei Batterie und Pilotenfabrik). Gibt true zurück, wenn sie gerade ausfällt.
func beschiesse(z: Vector2i, menge: float) -> bool:
	if not feld.has(z) or (feld[z] != FABRIK and feld[z] != BATTERIE) or ausgefallen.has(z):
		return false
	leben[z] = maxf(0.0, leben[z] - menge)
	if leben[z] > 0.0:
		return false
	for betroffen: Vector2i in [z, paar.get(z, KEINE)]:
		if betroffen != KEINE and feld.has(betroffen):
			ausgefallen[betroffen] = true
			leben[betroffen] = 0.0
			fortschritt.erase(betroffen)
			ausgefallen_ist.emit(betroffen, feld[betroffen])
	return true


## Das nächste arbeitende Gebäude (Fabrik oder Batterie) in Schussweite, auf das freie Sicht besteht.
func gebaeude_in_reichweite(von: Vector2, weite: float) -> Vector2i:
	var bestes := KEINE
	var beste := weite * weite
	for z: Vector2i in feld:
		if (feld[z] != FABRIK and feld[z] != BATTERIE) or ausgefallen.has(z):
			continue
		var m := mitte(z)
		var d := von.distance_squared_to(m)
		if d > beste:
			continue
		# Sicht bis kurz vor das Gebäude (das Gebäude selbst steht ja im Raster)
		var davor := m + (von - m).normalized() * (Werte.ZELLE * 0.62)
		if zelle_bei(davor) == z or sicht_frei(von, davor):
			beste = d
			bestes = z
	return bestes


func repariere_alles() -> void:
	ausgefallen.clear()
	for z: Vector2i in feld:
		leben[z] = max_leben(feld[z])
	turm_schaden.clear()   # lahmgelegte Türme laufen wieder
	pruefe_stuetzen()


# --------------------------------------------------------- Checkpoints

## Ziel Nummer `i` auf dem Gegnerweg: erst die Checkpoints, danach die Basis.
func ziel_zelle(i: int) -> Vector2i:
	return checkpoints[i] if i < checkpoints.size() else basis


## Der am weitesten vorn liegende eingenommene Checkpoint (-1 = keiner, Start ist die Grube).
func start_index() -> int:
	for i in range(checkpoints.size() - 1, -1, -1):
		if cp_feind[i]:
			return i
	return -1


## Erstes Routenziel der nächsten Welle (Nummer des Checkpoints; ohne Checkpoints direkt die Basis).
func erstes_ziel() -> int:
	return start_index() + 1 if cp_aktiv or cp_route else checkpoints.size()


func start_zelle() -> Vector2i:
	var i := start_index()
	return Werte.START_ZELLE if i < 0 else checkpoints[i]


## Nächster eingenommener Checkpoint, den eine Bodentruppe von `von` aus zu Fuß erreicht (sonst KEINE).
func naechster_feind_checkpoint(von: Vector2i) -> Vector2i:
	var bester := KEINE
	var beste_laenge := 1 << 30
	for i in checkpoints.size():
		if not cp_feind[i]:
			continue
		var laenge := 1 if von == checkpoints[i] else einheiten_weg(von, checkpoints[i]).size()
		if laenge > 0 and laenge < beste_laenge:
			beste_laenge = laenge
			bester = checkpoints[i]
	return bester


# -------------------------------------------------------------- Ausbau

## Anzahl der direkt angrenzenden Erdwälle (oben, unten, links, rechts).
func wall_nachbarn(z: Vector2i) -> int:
	var n := 0
	for r in NACHBARN:
		if inhalt(z + r) == WALL:
			n += 1
	return n


## Leerer Text = Ausbau möglich, sonst der Grund, warum nicht.
func ausbau_hindernis(z: Vector2i, typ: int) -> String:
	if inhalt(z) != WALL:
		return "Ausbauen geht nur auf einem Erdwall."
	if ausbau.has(z):
		return "Dieser Erdwall ist schon ausgebaut."
	if typ == SPIEGEL and wall_nachbarn(z) != 1:
		return "Ein Spiegel geht nur an ein Wallende (genau ein Nachbarwall) – dort, wo der Gang um die Mauer biegt."
	if typ == TURM:
		if stuetze_von.has(z):
			return "Dieser Erdwall stützt schon einen anderen Turm."
		if turm_form(z) == "":
			return "Hier passt keine Turmform (T-Stück, Kreuzung, lange Ecke, Klammer oder Treppe). Die Formen zeigt [I] unter Bauten."
	return ""


## Wachposten: einzelner Erdwall ohne Nachbarwälle – eine Stellung darauf reicht weiter (Werte.WACHPOSTEN_BONUS).
func ist_wachposten(z: Vector2i) -> bool:
	return inhalt(z) == WALL and wall_nachbarn(z) == 0


## Reichweiten-Bonus einer Stellung auf `z` für eine Einheit mit `daten`.
func posten_bonus(z: Vector2i, daten: Dictionary) -> float:
	return Werte.stellung_bonus(daten) + (Werte.WACHPOSTEN_BONUS if ist_wachposten(z) else 0.0) + anhoehe_bonus(z)   # 18.11.: Anhöhe


## Welcher Turm entstünde auf `z`? Bestimmt durch die freien Nachbarwälle (siehe Werte.TURMARTEN). "" = keiner.
func turm_form(z: Vector2i) -> String:
	var form := _gerade_form(z)
	if form == "" and _diagonal_paar(z).size() == 2:
		# Treppe: Erdwälle schräg an zwei gegenüberliegenden Ecken -> Heilturm (wenn keine andere Form passt)
		return "heil"
	return form


## Form aus den geraden Nachbarwällen (Kreuzung, T-Stück, Klammer, lange Ecke) – "" = keine.
func _gerade_form(z: Vector2i) -> String:
	match freie_stuetzen(z).size():
		4:
			return "funk"
		3:
			return "geschuetz"
		2:
			if not _form_waelle(z, "lanze").is_empty():
				return "lanze"
			if not _form_waelle(z, "frost").is_empty():
				return "frost"
	return ""


## Erdwall `n` kann den Turm auf `z` stützen: steht, trägt keinen Turm, stützt keinen anderen.
func _stuetzbar(n: Vector2i, z: Vector2i) -> bool:
	return inhalt(n) == WALL and ausbau.get(n, FREI) != TURM and (not stuetze_von.has(n) or stuetze_von[n] == z)


## Alle Erdwälle der Form, die der Turm auf `z` belegt (leer = Form passt nicht):
##   Klammer: die zwei Nachbarn in einer Linie + die beiden Enden, die zur selben Seite abbiegen (⊐)
##   lange Ecke: die zwei Nachbarn über Eck + je ein weiterer Erdwall in Verlängerung der Arme
func _form_waelle(z: Vector2i, art: String) -> Array[Vector2i]:
	var frei := freie_stuetzen(z)
	var waelle: Array[Vector2i] = []
	for i in frei.size():
		for j in range(i + 1, frei.size()):
			var a := frei[i]
			var b := frei[j]
			var gerade := a + b == z * 2
			if art == "lanze" and gerade:
				var d := a - z
				for s: Vector2i in [Vector2i(d.y, d.x), -Vector2i(d.y, d.x)]:
					if _stuetzbar(a + s, z) and _stuetzbar(b + s, z):
						waelle = [a, b, a + s, b + s]
						return waelle
			elif art == "frost" and not gerade:
				if _stuetzbar(a * 2 - z, z) and _stuetzbar(b * 2 - z, z):
					waelle = [a, b, a * 2 - z, b * 2 - z]
					return waelle
	return waelle


## Zwei schräg gegenüberliegende Erdwälle von `z` (Treppe), frei für einen Turm – sonst leer.
func _diagonal_paar(z: Vector2i) -> Array[Vector2i]:
	var paar: Array[Vector2i] = []
	for d: Vector2i in [Vector2i(1, 1), Vector2i(1, -1)]:
		if _stuetzbar(z + d, z) and _stuetzbar(z - d, z):
			paar = [z + d, z - d]
			return paar
	return paar


## Ein Wert des Turms auf `z` mit seiner Stufe: Stufe 2 und die Stufe-3-Fähigkeit überschreiben Werte.TURMARTEN.
## `vorgabe`, wenn der Turm den Wert gar nicht hat (z. B. Fähigkeiten wie "ziele").
func turm_wert(z: Vector2i, schluessel: String, vorgabe: Variant = null) -> Variant:
	var art: String = turm_art.get(z, "geschuetz")
	var wert: Variant = Werte.TURMARTEN[art].get(schluessel, vorgabe)
	var stufe := int(turm_stufe.get(z, 1))
	if stufe >= 2 and (Werte.TURM_STUFE_2[art] as Dictionary).has(schluessel):
		wert = Werte.TURM_STUFE_2[art][schluessel]
	if stufe >= 3:
		var f: Dictionary = (Werte.TURM_STUFE_3[art] as Dictionary).get(str(turm_faehigkeit.get(z, "")), {})
		if f.has(schluessel):
			wert = f[schluessel]
	if schluessel == "reichweite" and wert != null:
		wert = float(wert) + anhoehe_bonus(z)   # 18.11.: Turm auf der Anhöhe
	return wert


## So viele Stützen braucht der Turm auf `z`.
func turm_noetig(z: Vector2i) -> int:
	return int(Werte.TURMARTEN[turm_art.get(z, "geschuetz")]["nachbarn"])


## Die Stützen, die ein Turm der Art `art` auf `z` belegt – bei Formtürmen alle Erdwälle der Form.
func _waehle_stuetzen(z: Vector2i, art: String) -> Array[Vector2i]:
	if art == "heil":
		return _diagonal_paar(z)
	if art in ["lanze", "frost"]:
		return _form_waelle(z, art)
	return freie_stuetzen(z).slice(0, int(Werte.TURMARTEN[art]["nachbarn"]))


## Nachbarwälle von `z`, die einen Turm auf `z` stützen könnten: kein Turm darauf und noch keinem anderen Turm zugeteilt.
## Sortiert: zuerst die, die sonst am wenigsten taugen (wenige eigene Nachbarwälle) – so bleibt Platz für weitere Türme.
func freie_stuetzen(z: Vector2i) -> Array[Vector2i]:
	var frei: Array[Vector2i] = []
	for r in NACHBARN:
		var n := z + r
		if inhalt(n) != WALL or ausbau.get(n, FREI) == TURM:
			continue
		if stuetze_von.has(n) and stuetze_von[n] != z:
			continue
		frei.append(n)
	frei.sort_custom(func(a: Vector2i, b: Vector2i): return wall_nachbarn(a) < wall_nachbarn(b))
	return frei


## Teilt einem Turm seine Stützen zu (oder neu zu, wenn eine verloren ging). Gibt zurück, ob er genug hat.
func _stuetze_turm(z: Vector2i) -> bool:
	for alt: Vector2i in stuetzen.get(z, []):
		if stuetze_von.get(alt) == z:
			stuetze_von.erase(alt)
	var neu: Array[Vector2i] = _waehle_stuetzen(z, turm_art.get(z, "geschuetz"))
	stuetzen[z] = neu
	for n in neu:
		stuetze_von[n] = z
	return neu.size() >= turm_noetig(z)


## Nach jeder Änderung an Erdwällen: Türme, denen eine Stütze fehlt, suchen sich neue.
func pruefe_stuetzen() -> void:
	for z: Vector2i in stuetzen.keys():
		if ausbau.get(z, FREI) != TURM:
			for alt: Vector2i in stuetzen[z]:
				if stuetze_von.get(alt) == z:
					stuetze_von.erase(alt)
			stuetzen.erase(z)
			turm_schaden.erase(z)
			turm_art.erase(z)
			turm_stufe.erase(z)
			turm_faehigkeit.erase(z)
	for z: Vector2i in ausbau:
		if ausbau[z] != TURM:
			continue
		var ganz := stuetzen.has(z) and (stuetzen[z] as Array).size() >= turm_noetig(z)
		if ganz:
			for n: Vector2i in stuetzen[z]:
				if inhalt(n) != WALL or stuetze_von.get(n) != z:
					ganz = false
		if not ganz:
			_stuetze_turm(z)


## Schießt dieser Turm? Nicht, wenn ihm eine Stütze fehlt oder Myr-Drohnen ihn in dieser Runde lahmgelegt haben.
func turm_aktiv(z: Vector2i) -> bool:
	if ausbau.get(z, FREI) != TURM or turm_lahm(z):
		return false
	return (stuetzen.get(z, []) as Array).size() >= turm_noetig(z)


func turm_lahm(z: Vector2i) -> bool:
	return float(turm_schaden.get(z, 0.0)) >= float(Werte.TURM["leben"])


## Myr-Drohnen beschädigen einen Turm; ist er lahmgelegt, schweigt er bis zum Ende der Runde.
func schade_turm(z: Vector2i, menge: float) -> void:
	turm_schaden[z] = float(turm_schaden.get(z, 0.0)) + menge


func baue_aus(z: Vector2i, typ: int) -> void:
	ausbau[z] = typ
	if typ == TURM:
		var form := turm_form(z)
		turm_art[z] = form if form != "" else "geschuetz"
		_stuetze_turm(z)
	if typ == TOR:
		_gewichte_fuer(z)
		aktualisiere_pfad()


## Ein Erdwall mit Tor: Gegner müssen außen herum, eigene Truppen gehen hindurch.
func ist_tor(z: Vector2i) -> bool:
	return ausbau.get(z, FREI) == TOR


## Kann eine eigene Truppe auf diesem Feld stehen und kämpfen (freies Feld oder Tor)?
func ist_begehbar(z: Vector2i) -> bool:
	return ist_frei(z) or ist_tor(z)


## Freie Sicht zwischen zwei Punkten am Boden? Wälle und Gebäude versperren sie.
## Geprüft wird ein Streifen von der Breite eines Geschosses, nicht nur eine dünne Linie: An Wallkanten vorbei
## und durch die Lücke zwischen zwei Wällen, die sich nur an den Ecken berühren, kann nicht geschossen werden.
func sicht_frei(von: Vector2, nach: Vector2) -> bool:
	var quer := (nach - von).orthogonal().normalized() * 6.0
	return _strahl_frei(von, nach) and _strahl_frei(von + quer, nach + quer) and _strahl_frei(von - quer, nach - quer)


func _strahl_frei(von: Vector2, nach: Vector2) -> bool:
	var start := zelle_bei(von)
	var ende := zelle_bei(nach)
	var vorher := start
	var schritte := int(von.distance_to(nach) / 2.0) + 1
	for i in range(1, schritte + 1):
		var z := zelle_bei(von.lerp(nach, float(i) / schritte))
		if z == vorher:
			continue
		if z != start and (feld.has(z) or ist_fels(z) or (z != ende and boden.get(z, "") == "wald")):   # 18.11.: durch Wald nicht, hinein schon
			return false
		# schräg von Feld zu Feld = genau über eine Ecke: gesperrt, sobald dort ein Wall (oder Fels) anliegt
		if z.x != vorher.x and z.y != vorher.y:
			var e1 := Vector2i(z.x, vorher.y)
			var e2 := Vector2i(vorher.x, z.y)
			if feld.has(e1) or feld.has(e2) or sperrt_sicht(e1) or sperrt_sicht(e2):
				return false
		vorher = z
	return true


# ------------------------------------------------------------ Wegsuche

## 17.11.: Checkpoints zufällig in überlappenden Bereichen, mit Regeln:
## CP1 liegt näher am Gegner (und weiter links) als CP2, beide mit Mindestabstand zueinander und zum Gegner-Spawn.
func _zufalls_checkpoints() -> Array[Vector2i]:
	var b := Werte.CHECKPOINT_BEREICHE
	var spawn := Vector2(Werte.START_ZELLE)
	for versuch in 200:
		var lagen: Array[Vector2i] = []
		for r in b:
			lagen.append(r.position + Vector2i(randi() % r.size.x, randi() % r.size.y))
		if lagen.size() < 2:
			return lagen
		var a := lagen[0]
		var c := lagen[1]
		if a.x >= c.x or spawn.distance_to(Vector2(a)) >= spawn.distance_to(Vector2(c)):
			continue
		if Vector2(a - c).length() < Werte.CP_ABSTAND_ZUEINANDER:
			continue
		if spawn.distance_to(Vector2(a)) < Werte.CP_ABSTAND_SPAWN:
			continue
		if gelaende.has(a) or gelaende.has(c) or feld.has(a) or feld.has(c):   # 18.11.: nicht auf Fels, Wasser oder einer fertigen Mauer
			continue
		return lagen
	return Werte.CHECKPOINTS.duplicate()


func _neues_astar() -> AStarGrid2D:
	var a := AStarGrid2D.new()
	a.region = Rect2i(0, 0, Werte.SPALTEN, Werte.ZEILEN)
	a.cell_size = Vector2.ONE
	a.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	a.default_compute_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	a.default_estimate_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	a.update()
	return a


func _gewicht(gegner_typ: String, was: int) -> float:
	match was:
		WALL:
			return Werte.GEGNER[gegner_typ]["wall_kosten"]
		FABRIK, BATTERIE:
			return Werte.GEGNER[gegner_typ]["fabrik_kosten"]
	return 1.0


func _gewichte_fuer(z: Vector2i) -> void:
	var was := inhalt(z)
	# Ein Tor ist für den Gegner ein Erdwall, eigene Truppen gehen hindurch
	_astar_einheiten.set_point_solid(z, was != FREI and not ist_tor(z))
	# 17.11. (Paul): durch das HQ läuft niemand hindurch. Die Felder bleiben erreichbar (die Gegner wollen ja hinein,
	# Brakk steht dort wieder auf), kosten aber so viel, dass jeder Weg außen herum führt.
	var hq := ist_basis(z) and was == FREI
	_astar_einheiten.set_point_weight_scale(z, Werte.HQ_WEGKOSTEN if hq else 1.0)
	for typ: String in _astar_gegner:
		(_astar_gegner[typ] as AStarGrid2D).set_point_weight_scale(z, Werte.HQ_WEGKOSTEN if hq else _gewicht(typ, was))


## Weg eines Gegners: der billigste – Wälle sind teuer, aber nicht verboten.
func gegner_weg(gegner_typ: String, von: Vector2i, nach: Vector2i = KEINE) -> Array[Vector2i]:
	if nach == KEINE:
		nach = basis
	if not in_karte(von):
		return []
	return (_astar_gegner[gegner_typ] as AStarGrid2D).get_id_path(von, nach)


## Ganzer Weg der nächsten Welle: vom Start durch alle folgenden Checkpoints bis zur Basis.
func _route(gegner_typ: String) -> Array[Vector2i]:
	return _route_ab(gegner_typ, start_zelle())


func _route_ab(gegner_typ: String, von: Vector2i) -> Array[Vector2i]:
	var a := _astar_gegner[gegner_typ] as AStarGrid2D
	var weg: Array[Vector2i] = [von]
	for i in range(erstes_ziel(), checkpoints.size() + 1):
		var teil := a.get_id_path(von, ziel_zelle(i))
		for j in range(1, teil.size()):
			weg.append(teil[j])
		von = ziel_zelle(i)
	return weg


## Wie würde der Weg aussehen, wenn auf `z` zusätzlich `typ` stünde?
func gegner_weg_mit(gegner_typ: String, z: Vector2i, typ: int) -> Array[Vector2i]:
	var a := _astar_gegner[gegner_typ] as AStarGrid2D
	a.set_point_weight_scale(z, _gewicht(gegner_typ, typ))
	var weg := _route(gegner_typ)
	a.set_point_weight_scale(z, _gewicht(gegner_typ, inhalt(z)))
	return weg


func aktualisiere_pfad() -> void:
	pfad = _route("hund")
	_finde_hoefe()
	aktualisiere_kuppeln()
	_ersparnis_gueltig = false
	_stuecke_gueltig = false
	# Gegner kommen über die ganze Höhe der Zone: zusätzlich den Weg vom oberen und unteren Rand zeigen
	neben_pfade.clear()
	if start_index() < 0:
		neben_pfade.append(_route_ab("hund", Vector2i(0, 1)))
		neben_pfade.append(_route_ab("hund", Vector2i(0, Werte.ZEILEN - 2)))
	# Fußweg der eigenen Truppen zum HQ: der kürzeste ab irgendeiner Fabrik
	angriffs_pfad = []
	if zeige_angriff:
		for z: Vector2i in feld:
			if feld[z] != FABRIK:
				continue
			var weg := einheiten_weg(z, Werte.ANGRIFFS_ZELLE)
			if not weg.is_empty() and (angriffs_pfad.is_empty() or weg.size() < angriffs_pfad.size()):
				angriffs_pfad = weg
	var z := vorschau_zelle
	vorschau_zelle = KEINE
	setze_vorschau(z, vorschau_typ, vorschau_ok)


## Muss der Gegner auf diesem Weg etwas einreißen?
func weg_bricht_durch(weg: Array[Vector2i], zusatz: Vector2i = KEINE) -> bool:
	for z in weg:
		if feld.has(z) or z == zusatz:
			return true
	return false


## Weg eigener Truppen über freie Felder. Leer, wenn es keinen gibt.
func einheiten_weg(von: Vector2i, nach: Vector2i) -> Array[Vector2i]:
	if not in_karte(von) or not ist_frei(nach):
		return []
	if ist_begehbar(von):
		return _astar_einheiten.get_id_path(von, nach)
	# Start liegt in einem Gebäude (frisch aus der Fabrik): über einen freien Nachbarn – oder durch ein Tor direkt an der Fabrik.
	var bester: Array[Vector2i] = []
	for n in NACHBARN:
		var s := von + n
		if not ist_begehbar(s):
			continue
		var weg := _astar_einheiten.get_id_path(s, nach)
		if not weg.is_empty() and (bester.is_empty() or weg.size() < bester.size()):
			bester = weg
	return bester


## Erste Schritte aus einem Gebäude heraus: ein freies Nachbarfeld – oder, wenn es keins gibt,
## durch ein Tor direkt am Gebäude auf das freie Feld dahinter. Leer = kein Ausgang.
func ausgang(z: Vector2i) -> Array[Vector2i]:
	var frei := freier_nachbar(z)
	if frei != KEINE:
		return [frei]
	for n in NACHBARN:
		var tor := z + n
		if not ist_tor(tor):
			continue
		for m: Vector2i in [n, Vector2i(n.y, n.x), Vector2i(-n.y, -n.x)]:
			if ist_frei(tor + m):
				return [tor, tor + m]
	return []


## Hat dieses Gebäude einen Ausgang für seine Truppen (freies Nachbarfeld oder Tor)?
func hat_ausgang(z: Vector2i) -> bool:
	return not ausgang(z).is_empty()


func freier_nachbar(z: Vector2i) -> Vector2i:
	for n in NACHBARN:
		if ist_frei(z + n):
			return z + n
	return KEINE


## Sucht die nächste Stellung (ausgebauter Erdwall), gemessen am Fußweg ab `von`.
## Wer schon oben steht, bleibt. Wer noch dorthin unterwegs ist, gibt sie an eine nähere Einheit ab.
## Ergebnis: {"wall": Zelle, "weg": Felder bis dorthin} oder {} (dann kämpft die Einheit am Boden).
func finde_posten(von: Vector2i, sucher: Einheit) -> Dictionary:
	var bester := {}
	var beste_laenge := 1 << 30
	if sucher.daten.get("faehigkeit", "") == "bollwerk":
		return {}   # Bollwerk kämpft am Boden und lässt die Stellungen den anderen
	# Kampftruppen gehen nur in Stellungen, Piloten nur in Batterien.
	var pilot: bool = sucher.daten.get("pilot", false)
	var erlaubt: Array = sucher.spiel.zugewiesen(sucher.fabrik_zelle) if not pilot else []   # per Pfeil zugewiesene Stellungen
	for w: Vector2i in ausbau:
		if pilot or ausbau[w] != STELLUNG:
			continue
		if not erlaubt.is_empty() and not erlaubt.has(w):
			continue
		var res: Vector2i = sucher.spiel.reserviert_fuer(w)
		if res != KEINE and res != sucher.fabrik_zelle:
			continue   # per Pfeil einer anderen Fabrik vorbehalten
		var weg := _weg_auf_wall(von, w)
		if weg.is_empty() or weg.size() >= beste_laenge:
			continue
		if posten.has(w) and not is_instance_valid(posten[w]):
			# Sicherheitsnetz: Eintrag einer Truppe, die es nicht mehr gibt
			posten.erase(w)
		if posten.has(w):
			var inhaber: Einheit = posten[w]
			if inhaber == sucher or not inhaber.unterwegs_weiter_als(weg.size()):
				continue
		beste_laenge = weg.size()
		bester = {"wall": w, "weg": weg}
	# Batterien zählen wie Stellungen mit mehreren Plätzen
	for b: Vector2i in feld:
		if not pilot or feld[b] != BATTERIE:
			continue
		var mannschaft: Array = besatzung.get(b, [])
		if mannschaft.has(sucher):
			continue
		var weg := _weg_auf_wall(von, b)
		if weg.is_empty() or weg.size() >= beste_laenge:
			continue
		if mannschaft.size() < int(Werte.BATTERIE["plaetze"]):
			beste_laenge = weg.size()
			bester = {"wall": b, "weg": weg}
			continue
		# Alle Plätze vergeben: Wer näher dran ist, übernimmt den Platz dessen, der noch am weitesten unterwegs ist.
		var fernster: Einheit = null
		for e: Einheit in mannschaft:
			if e.unterwegs_weiter_als(weg.size()) and (fernster == null or e.rest_punkte() > fernster.rest_punkte()):
				fernster = e
		if fernster != null:
			beste_laenge = weg.size()
			bester = {"wall": b, "weg": weg, "statt": fernster}
	return bester


## Wie _weg_auf_wall, aber ohne die Felder in `gefahr` zu betreten (Felder nahe an Gegnern).
## Leer, wenn es gerade keinen sicheren Weg gibt.
func sicherer_weg_auf_wall(von: Vector2i, w: Vector2i, gefahr: Dictionary) -> Array[Vector2i]:
	var gesperrt: Array[Vector2i] = []
	for z: Vector2i in gefahr:
		if z != von and ist_frei(z):
			_astar_einheiten.set_point_solid(z, true)
			gesperrt.append(z)
	var weg := _weg_auf_wall(von, w)
	for z in gesperrt:
		_astar_einheiten.set_point_solid(z, false)
	return weg


func _weg_auf_wall(fabrik: Vector2i, w: Vector2i) -> Array[Vector2i]:
	if absi(w.x - fabrik.x) + absi(w.y - fabrik.y) == 1:
		var direkt: Array[Vector2i] = [w]
		return direkt
	var bester: Array[Vector2i] = []
	for n in NACHBARN:
		var zugang := w + n
		if not ist_frei(zugang):
			continue
		var weg := einheiten_weg(fabrik, zugang)
		if not weg.is_empty() and (bester.is_empty() or weg.size() < bester.size()):
			bester = weg
	if not bester.is_empty():
		bester = bester.duplicate()
		bester.append(w)
	return bester


# -------------------------------------------------- Sonderregeln der Gegner

func _weg_kosten(gegner_typ: String, weg: Array[Vector2i]) -> float:
	var a := _astar_gegner[gegner_typ] as AStarGrid2D
	var summe := 0.0
	for i in range(1, weg.size()):
		summe += a.get_point_weight_scale(weg[i])
	return summe


## Für jeden Erdwall ohne Turm: Wie viel kürzer wäre der Gegnerweg ohne ihn? (nur Wälle mit Ersparnis)
func ersparnisse() -> Dictionary:
	if _ersparnis_gueltig:
		return _ersparnis
	_ersparnis_gueltig = true
	_sprengvorschau_gueltig = false
	_ersparnis = {}
	_ersparnis_seite = {}
	var a := _astar_gegner["hund"] as AStarGrid2D
	var basis := _weg_kosten("hund", _route("hund"))
	for w: Vector2i in feld:
		if feld[w] != WALL or ausbau.get(w, FREI) == TURM:
			continue
		for n in NACHBARN:
			var zugang := w + n
			if not ist_frei(zugang):
				continue
			# Die Sprengung geht in die Tiefe: der Wall und die Erdwälle direkt dahinter (vom Sprenger aus gesehen), siehe sprengt_reihe
			var reihe := sprengt_reihe(w, zugang)
			a.set_point_weight_scale(w, 1.0)
			for h: Vector2i in reihe:
				a.set_point_weight_scale(h, 1.0)
			var gewinn := basis - _weg_kosten("hund", _route("hund"))
			a.set_point_weight_scale(w, _gewicht("hund", WALL))
			for h: Vector2i in reihe:
				a.set_point_weight_scale(h, _gewicht("hund", WALL))
			if gewinn > 0.5:
				_ersparnis_seite[[w, zugang]] = gewinn
				_ersparnis[w] = maxf(gewinn, float(_ersparnis.get(w, 0.0)))
	return _ersparnis


## Die Erdwälle, die eine Sprengung von `zugang` aus an `w` mitreißt: alle, die in gerader Linie direkt dahinter stehen,
## bis die Sprengung insgesamt SPRENGER_TIEFE Erdwälle tief ist. Ein Turm hält stand und schützt, was hinter ihm liegt.
## Mitgerissen werden nur blanke Erdwälle (keine Stellung, kein Tor, kein Turm), die zu einer Mauerlage quer zur
## Sprengrichtung gehören (quer daneben steht ein weiterer Erdwall). So trifft es nur stumpfe Riegel; eine Linie, die in
## Sprengrichtung verläuft, oder eine Reihe Stellungen verliert nur das getroffene Feld.
func sprengt_reihe(w: Vector2i, zugang: Vector2i) -> Array[Vector2i]:
	var reihe: Array[Vector2i] = []
	var richtung := w - zugang
	if richtung.length_squared() != 1:
		return reihe
	var quer := Vector2i(richtung.y, richtung.x)
	var hinter := w + richtung
	while reihe.size() < Werte.SPRENGER_TIEFE - 1 and inhalt(hinter) == WALL and ausbau.get(hinter, FREI) == FREI and not panzer.has(hinter) \
			and (inhalt(hinter + quer) == WALL or inhalt(hinter - quer) == WALL):
		reihe.append(hinter)
		hinter += richtung
	return reihe


## Die Erdwälle mit der größten Ersparnis, die lohnendste zuerst (höchstens `anzahl`).
func schwachstellen(anzahl: int) -> Array:
	var alle := ersparnisse()
	var waelle: Array = alle.keys()
	waelle.sort_custom(func(x, y): return alle[x] > alle[y])
	return waelle.slice(0, anzahl)


## Der Erdwall mit der größten Ersparnis (KEINE, wenn kein Wall eine Abkürzung öffnet).
func schwachstelle() -> Vector2i:
	var beste := schwachstellen(1)
	return KEINE if beste.is_empty() else beste[0]


## Nummer des Wallstücks, zu dem der Erdwall `z` gehört (-1 = kein Erdwall).
func stueck_nr(z: Vector2i) -> int:
	if not _stuecke_gueltig:
		_stuecke_gueltig = true
		_stueck_von = {}
		var nr := 0
		for w: Vector2i in feld:
			if feld[w] == WALL and not _stueck_von.has(w):
				for teil in wallstueck(w):
					_stueck_von[teil] = nr
				nr += 1
	return _stueck_von.get(z, -1)


## Sicht aus einer Stellung oder von einem Turm auf dem Erdwall `wall`:
## Über das eigene Wallstück wird hinweggeschossen, jeder fremde Erdwall versperrt die Sicht.
## Fabriken und Batterien stehen am Boden und verdecken nichts.
func sicht_von_wall(wall: Vector2i, von: Vector2, nach: Vector2) -> bool:
	var eigen := stueck_nr(wall)
	var ziel := zelle_bei(nach)
	var vorher := KEINE
	var schritte := int(von.distance_to(nach) / 4.0) + 1
	for i in range(1, schritte):
		var z := zelle_bei(von.lerp(nach, float(i) / schritte))
		if z == vorher:
			continue
		vorher = z
		if z != ziel and ((feld.get(z, FREI) == WALL and stueck_nr(z) != eigen) or sperrt_sicht(z)):
			return false
	return true


## Kosten des Restwegs ab `z`, wenn als Nächstes Ziel Nummer `i` angesteuert wird (danach alle weiteren bis zur Basis).
func _rest_kosten(z: Vector2i, i: int) -> float:
	var summe := 0.0
	var von := z
	for k in range(i, checkpoints.size() + 1):
		summe += _weg_kosten("hund", gegner_weg("hund", von, ziel_zelle(k)))
		von = ziel_zelle(k)
	return summe


## Welches Ziel steuert ein Gegner an, der auf `z` landet? Das, von dem aus der Restweg am kürzesten ist –
## so läuft niemand zu einem Checkpoint zurück, der schon hinter ihm liegt.
func bestes_ziel_ab(z: Vector2i, ab: int) -> int:
	var bestes := ab
	var beste_kosten := INF
	for i in range(ab, checkpoints.size() + 1):
		var kosten := _rest_kosten(z, i)
		if kosten < beste_kosten:
			beste_kosten = kosten
			bestes = i
	return bestes


## Geworfene Gegner stürmen Checkpoints: der nächste Checkpoint ab `z`, der noch nicht dem Gegner gehört
## (auch wenn er auf der Route schon hinter ihnen liegt). Gibt es keinen, geht es über den letzten Checkpoint zur Basis.
func sturmziel_ab(z: Vector2i) -> int:
	var bestes := checkpoints.size() - 1 if cp_aktiv and checkpoints.size() > 0 else checkpoints.size()
	var beste_laenge := 1 << 30
	if not cp_aktiv:
		return bestes
	for i in checkpoints.size():
		if cp_feind[i]:
			continue
		var laenge := 1 if z == checkpoints[i] else gegner_weg("hund", z, checkpoints[i]).size()
		if laenge > 0 and laenge < beste_laenge:
			beste_laenge = laenge
			bestes = i
	return bestes


## Ziel eines Sprengers ab `von`: der erreichbare Erdwall mit der größten Ersparnis.
## Ergebnis: {"wall": Zelle, "weg": Felder bis zum Nachbarfeld des Walls} oder {}.
func sprengziel(von: Vector2i, belegt: Array = [], min_weg: int = Werte.SPRENGER_MIN_WEG) -> Dictionary:
	ersparnisse()
	var bester := {}
	var beste_wertung := -INF
	var fern := {}          # Notlösung: der am weitesten entfernte Wall, falls alle zu nah am Start liegen
	# Zweiter Durchgang ohne die Sperre, falls nur noch Wallstücke übrig sind, die schon ein anderer Sprenger anpeilt
	for durchgang in 2:
		for paar: Array in _ersparnis_seite:
			var w: Vector2i = paar[0]
			var zugang: Vector2i = paar[1]
			if durchgang == 0 and belegt.has(stueck_nr(w)):
				continue
			var weg: Array[Vector2i] = [von]
			if zugang != von:
				weg = _weg_ohne_tor(von, zugang)
			if weg.is_empty():
				continue
			if fern.is_empty() or weg.size() > (fern["weg"] as Array).size():
				fern = {"wall": w, "weg": weg}
			# Die vorderste Front lässt er stehen: erst Wälle ab einem Mindestanmarsch kommen in Frage
			if weg.size() < min_weg:
				continue
			# Abkürzung zählt, ein langer Anmarsch kostet
			var wertung: float = float(_ersparnis_seite[paar]) - Werte.SPRENGER_WEG_GEWICHT * weg.size()
			if wertung > beste_wertung:
				beste_wertung = wertung
				bester = {"wall": w, "weg": weg}
		if not bester.is_empty():
			break
	return bester if not bester.is_empty() else fern


## Fußweg für Gegner zu einem freien Feld: wie der Weg eigener Truppen, aber Tore sind für sie zu
## (vorher wurde ein Weg durch ein Tor nur verworfen – oder, beim Belagerungsturm, gar nicht geprüft).
func _weg_ohne_tor(von: Vector2i, nach: Vector2i) -> Array[Vector2i]:
	var tore: Array[Vector2i] = []
	for z: Vector2i in ausbau:
		if ausbau[z] == TOR:
			tore.append(z)
	for z in tore:
		_astar_einheiten.set_point_solid(z, true)
	var weg := einheiten_weg(von, nach)
	for z in tore:
		_astar_einheiten.set_point_solid(z, false)
	return weg


## Bauphase: die Erdwälle, die die nächsten Sprenger vom Start aus anpeilen würden (jeder ein anderes Wallstück).
func sprengvorschau(anzahl: int) -> Array:
	ersparnisse()
	var von := start_zelle()
	if _sprengvorschau_gueltig and _sprengvorschau_von == von:
		return _sprengvorschau
	_sprengvorschau_gueltig = true
	_sprengvorschau_von = von
	_sprengvorschau = []
	var belegt: Array = []
	for i in anzahl:
		var fund := sprengziel(von, belegt)
		if fund.is_empty() or _sprengvorschau.has(fund["wall"]):
			break
		_sprengvorschau.append(fund["wall"])
		belegt.append(stueck_nr(fund["wall"]))
	return _sprengvorschau


## Kürzester Fußweg von `von` auf ein freies Nachbarfeld des Walls `w` (leer = unerreichbar).
func _weg_an_wall(von: Vector2i, w: Vector2i) -> Array[Vector2i]:
	var bester: Array[Vector2i] = []
	for n in NACHBARN:
		var zugang := w + n
		if not ist_frei(zugang):
			continue
		var weg: Array[Vector2i] = [von]
		if zugang != von:
			weg = _weg_ohne_tor(von, zugang)   # Gegner (Belagerungsturm): nicht durch Tore
		if not weg.is_empty() and (bester.is_empty() or weg.size() < bester.size()):
			bester = weg
	return bester


## Alle Erdwälle, die mit `w` zusammenhängen (über Kanten, nicht über Ecken).
func wallstueck(w: Vector2i) -> Array[Vector2i]:
	var stueck: Array[Vector2i] = [w]
	var i := 0
	while i < stueck.size():
		for n in NACHBARN:
			var z := stueck[i] + n
			if inhalt(z) == WALL and not stueck.has(z):
				stueck.append(z)
		i += 1
	return stueck


## Andockstelle eines Belagerungsturms ab `von` (14.11. neu): immer außerhalb des Gegner-Schildes (der Zone).
## 1. Wahl: die am schnellsten erreichbare Wallstelle, von der eine Stellung oder ein Turm höchstens ANDOCK_NAH Wallschritte entfernt ist.
## 2. Wahl: die nächste Wallstelle, von der überhaupt ein Ziel über Wälle erreichbar ist. 3. Wahl: der nächste Erdwall.
## Ergebnis: {"wall": Zelle, "weg": Felder bis zum Nachbarfeld} oder {} (kein Erdwall erreichbar).
func andockziel(von: Vector2i) -> Dictionary:
	var beste: Array = [{}, {}, {}]
	for w: Vector2i in feld:
		if inhalt(w) != WALL or w.x < Werte.ZONE_SPALTEN:
			continue
		var stufe := 2
		if enterziel(w):
			stufe = 0
		else:
			var zu_ziel := wall_weg_zur_stellung(w)
			if not zu_ziel.is_empty():
				stufe = 0 if zu_ziel.size() - 1 <= Werte.ANDOCK_NAH else 1
		if not (beste[stufe] as Dictionary).is_empty() and (beste[stufe]["weg"] as Array).size() <= absi(w.x - von.x) + absi(w.y - von.y):
			continue   # kann nicht kürzer werden
		var weg := _weg_an_wall(von, w)
		if weg.is_empty():
			continue
		if (beste[stufe] as Dictionary).is_empty() or weg.size() < (beste[stufe]["weg"] as Array).size():
			beste[stufe] = {"wall": w, "weg": weg}
	for b: Dictionary in beste:
		if not b.is_empty():
			return b
	return {}


## Weg einer Myr-Drohne über zusammenhängende Wälle zur nächsten besetzten Stellung (leer = keine erreichbar).
func wall_weg_zur_stellung(von: Vector2i) -> Array[Vector2i]:
	var vorgaenger: Dictionary = {von: von}
	var offen: Array[Vector2i] = [von]
	var i := 0
	while i < offen.size():
		var z := offen[i]
		i += 1
		if z != von and enterziel(z):
			var weg: Array[Vector2i] = [z]
			while weg[0] != von:
				weg.push_front(vorgaenger[weg[0]])
			return weg
		for n in NACHBARN:
			var nz := z + n
			if inhalt(nz) == WALL and not vorgaenger.has(nz):
				vorgaenger[nz] = z
				offen.append(nz)
	return []


## Lohnt dieses Wallfeld für eine Myr-Drohne? Eine Stellung, in der wirklich jemand steht, oder ein laufender Turm.
func enterziel(z: Vector2i) -> bool:
	if turm_aktiv(z):
		return true
	var e: Variant = posten.get(z)
	return is_instance_valid(e) and (e as Einheit).in_stellung()


## Nächstes freies Feld neben dem Wallstück, auf dem `von` liegt (zum Abspringen).
func absprung(von: Vector2i) -> Vector2i:
	var zellen: Array[Vector2i] = [von]
	if inhalt(von) == WALL:
		zellen = wallstueck(von)
	for z in zellen:
		var frei := freier_nachbar(z)
		if frei != KEINE:
			return frei
	return KEINE


## Landefeld für einen geworfenen Hund: das freie Feld in Wurfweite, von dem der Restweg am kürzesten ist.
func landefeld(von: Vector2i, weite: float) -> Vector2i:
	var bestes := KEINE
	var beste_kosten := INF
	var ab := erstes_ziel()
	for y in Werte.ZEILEN:
		for x in range(Werte.ZONE_SPALTEN, Werte.SPALTEN):
			var z := Vector2i(x, y)
			if not ist_frei(z) or Vector2(z - von).length() > weite:
				continue
			var kosten := _rest_kosten(z, bestes_ziel_ab(z, ab))
			if kosten < beste_kosten:
				beste_kosten = kosten
				bestes = z
	return bestes


## Wohin wirft die Wurf-Schleuder auf `von`? Hinter die Wallgruppe, die den Gegnern den größten Umweg abverlangt.
## Gibt es keine echte Mauer, wirft sie weiter – in Taschen zwischen Erdwällen.
## Ergebnis: {"z": Landefeld, "mauer": Umweg in Schritten} oder {} (dann wirft sie gar nicht).
func wurf_landefeld(von: Vector2i, meiden: Vector2 = Vector2.INF, meiden_r: float = 0.0) -> Dictionary:
	# Gemessen wird immer von der Zone aus, in der die Schleuder steht – nicht von einem eingenommenen Checkpoint.
	# (Sonst gilt nach einer Einnahme das Feld VOR der Mauer als "weit weg" und der Wurf landet davor.)
	var start := Werte.START_ZELLE
	var bestes := KEINE
	var beste := -INF
	var groesste_mauer := 0.0
	var tasche_bestes := KEINE
	var tasche_beste := -INF
	var ab := erstes_ziel()
	var rest_start := minf(_rest_kosten(start_zelle(), ab), 200.0)
	for y in Werte.ZEILEN:
		for x in range(Werte.ZONE_SPALTEN, Werte.SPALTEN):
			var z := Vector2i(x, y)
			var luft := Vector2(z - von).length()
			if not ist_frei(z) or ist_basis(z) or luft > Werte.WURF["tasche_weit"]:
				continue
			# Rundum eingeschlossen (von hier kommt niemand zu Fuß zur Basis, ohne etwas einzureißen)? Kein Landeziel:
			# Geworfen wird hinter eine Mauer, nicht in einen geschlossenen Kern.
			if _weg_kosten("hund", gegner_weg("hund", z, basis)) >= 1000.0:
				continue
			if meiden != Vector2.INF and mitte(z).distance_to(meiden) < meiden_r * Werte.ZELLE:
				continue
			var cp_nah := 0.0
			for i in checkpoints.size():
				if cp_aktiv and not cp_feind[i] and Vector2(z - checkpoints[i]).length() <= 2.5:
					cp_nah = Werte.WURF_CP_BONUS
			# Tasche: wie viele Erdwälle und Bauwerke liegen rundherum?
			var tasche := 0
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					var n := z + Vector2i(dx, dy)
					if n != z and in_karte(n) and inhalt(n) != FREI:
						tasche += 1
			# Umweg: so viel länger ist der Fußweg vom Start hierher als die Luftlinie (Erdwälle im Weg zählen voll)
			var kosten := minf(_weg_kosten("hund", gegner_weg("hund", start, z)), 60.0)
			var umweg := kosten - Vector2(z - start).length()
			# Der normale Wurf hinter die Mauer reicht nur bis zur Wurfweite; weiter fliegen nur Taschenwürfe (siehe unten)
			var in_wurfweite := luft <= float(Werte.WURF["reichweite"])
			if in_wurfweite:
				groesste_mauer = maxf(groesste_mauer, umweg)
			var wert := umweg + cp_nah + 0.5 * tasche
			if in_wurfweite and wert > beste:
				beste = wert
				bestes = z
			if tasche >= 3 and x > Werte.ZONE_SPALTEN:
				# Taschenwurf: nur, wenn er den Gegnern Weg erspart – eine Nische VOR der Mauer ist keine Tasche
				var erspart := rest_start - minf(_rest_kosten(z, bestes_ziel_ab(z, ab)), 200.0)
				if erspart < Werte.WURF_TASCHE_MIN_ERSPART:
					continue
				var t_wert := 2.0 * tasche + 0.5 * erspart + cp_nah - 0.3 * luft
				if t_wert > tasche_beste:
					tasche_beste = t_wert
					tasche_bestes = z
	if groesste_mauer >= Werte.WURF_MAUER_MIN and bestes != KEINE:
		return {"z": bestes, "mauer": groesste_mauer}
	if tasche_bestes != KEINE:
		return {"z": tasche_bestes, "mauer": groesste_mauer}
	if bestes != KEINE:
		return {"z": bestes, "mauer": groesste_mauer}
	return {}


## Die nächste arbeitende Fabrik, die ein Gegner von `von` aus zu Fuß erreicht: {"wall": Fabrikfeld, "weg": Weg bis daneben} oder {}.
func fabrikziel(von: Vector2i) -> Dictionary:
	var bestes := {}
	for z: Vector2i in feld:
		if feld[z] != FABRIK or ausgefallen.has(z) or paar.has(z):
			continue
		for n in NACHBARN:
			var neben: Vector2i = z + n
			if not ist_frei(neben):
				continue
			var weg := gegner_weg("hund", von, neben)
			if (weg.is_empty() and von != neben) or weg.size() > 40:
				continue
			if bestes.is_empty() or weg.size() < (bestes["weg"] as Array).size():
				bestes = {"wall": z, "weg": weg}
	return bestes


## Das freie Feld (außerhalb der Zone), das einer Stelle am nächsten liegt.
func freies_feld_nahe(punkt: Vector2) -> Vector2i:
	var bestes := KEINE
	var beste := INF
	for y in Werte.ZEILEN:
		for x in range(Werte.ZONE_SPALTEN, Werte.SPALTEN):
			var z := Vector2i(x, y)
			if not ist_frei(z) or ist_basis(z):
				continue
			var d := mitte(z).distance_to(punkt)
			if d < beste:
				beste = d
				bestes = z
	return bestes


## Wie stark ist die Mauer, die die Wurf-Schleuder auf `von` sieht? (größter Umweg in Wurfweite)
func wurf_mauer(von: Vector2i) -> float:
	var ziel := wurf_landefeld(von)
	return float(ziel.get("mauer", 0.0))


# ------------------------------------------------------------ Vorschau

func setze_vorschau(z: Vector2i, typ: int, ok: bool) -> void:
	if z == vorschau_zelle and typ == vorschau_typ and ok == vorschau_ok:
		return
	vorschau_zelle = z
	vorschau_typ = typ
	vorschau_ok = ok
	vorschau_pfad = []
	if (typ == WALL or typ == FABRIK or typ == BATTERIE) and ok and ist_bebaubar(z):
		vorschau_pfad = gegner_weg_mit("hund", z, typ)


# ------------------------------------------------------------- Zeichnen

const GRAS_A := Color("4f7d45")
const GRAS_B := Color("4a7641")
const GRAS_HELL := Color("5f9152")
const GRAS_DUNKEL := Color("40683a")
const ERDE_OBEN := Color("a87b4a")
const ERDE_KANTE := Color("c49b63")
const ERDE_FRONT := Color("7a5433")
const ERDE_DUNKEL := Color("553822")
const KRONE := Color("6c9a4f")
const TECH := Color("4b3a66")
const TECH_HELL := Color("6a5391")
const TECH_DUNKEL := Color("2a2038")
const TECH_LICHT := Color("7fe0ff")
const MESSING := Color("c9963f")
const GRUBE := Color("1d1512")
const WEG := Color("ffd34d")
const WEG_NEU := Color("ffffff")
const WARNUNG := Color("ff5a4d")
const STEIN := Color("8d8a96")
const STEIN_HELL := Color("b4b1bd")
const STEIN_DUNKEL := Color("5c5966")


func _r(z: Vector2i, x: float, y: float, w: float, h: float, farbe: Color) -> void:
	draw_rect(Rect2(Vector2(z) * Werte.ZELLE + Vector2(x, y), Vector2(w, h)), farbe)


func _draw() -> void:
	var zg := float(Werte.ZELLE)
	# Boden
	if Werte.grafik_neu:
		_zeichne_boden_neu()
	for y in (Werte.ZEILEN if not Werte.grafik_neu else 0):
		for x in Werte.SPALTEN:
			var z := Vector2i(x, y)
			_r(z, 0, 0, zg, zg, GRAS_A if (x + y) % 2 == 0 else GRAS_B)
			var h := hash(z)
			_r(z, 8 + (h % 5) * 8, 8 + ((h >> 4) % 5) * 8, 4, 4, GRAS_HELL)
			_r(z, 12 + ((h >> 8) % 5) * 8, 20 + ((h >> 12) % 4) * 8, 4, 4, GRAS_DUNKEL)

	_zeichne_gelaende()
	_zeichne_boden_wirkung()
	_zeichne_start()
	_zeichne_basis()
	for i in checkpoints.size():
		_zeichne_checkpoint(i)

	# Weglinie unter den Gebäuden beginnen, Durchbrüche später darüber markieren
	var zeige_neu := not vorschau_pfad.is_empty()
	if zeige_pfad_kraeftig:
		for neben: Array[Vector2i] in neben_pfade:
			_zeichne_weg(neben, Color(WEG, 0.3), false)
	if zeige_neu:
		_zeichne_weg(pfad, Color(WEG, 0.25), false)
	else:
		_zeichne_weg(pfad, Color(WEG, 0.85 if zeige_pfad_kraeftig else 0.3), zeige_pfad_kraeftig)
	if zeige_angriff and zeige_pfad_kraeftig:
		_zeichne_weg(angriffs_pfad, Color(TECH_LICHT, 0.9), false)

	for z: Vector2i in feld:
		if feld[z] == WALL:
			_zeichne_wall(z, 1.0)
			if panzer.has(z):
				_zeichne_panzer(z, 1.0)
			if stuetze_von.has(z):
				_zeichne_stuetze(z, Color(Werte.TURMARTEN[turm_art.get(stuetze_von[z], "geschuetz")]["farbe"]).darkened(0.25), 0.5)
			if ausbau.has(z) and not (Werte.grafik_neu and ausbau[z] == TURM):   # neue Grafik: Türme zeichnet TurmBild
				_zeichne_ausbau(z, ausbau[z], 1.0)
				if ausbau[z] == TURM and not turm_aktiv(z):
					_zeichne_turm_aus(z)
		elif feld[z] == BATTERIE:
			_zeichne_batterie(z, 1.0)
		elif feld[z] == GENERATOR:
			_zeichne_generator(z, 1.0)
		else:
			_zeichne_fabrik(z, 1.0)
		if ausgefallen.has(z):
			# ausgefallen bis zum Ende der Runde: abgedunkelt, rotes Kreuz
			_r(z, 2, 2, 60, 60, Color(0, 0, 0, 0.55))
			var oa := Vector2(z) * zg
			draw_line(oa + Vector2(14, 14), oa + Vector2(50, 50), WARNUNG, 5.0)
			draw_line(oa + Vector2(50, 14), oa + Vector2(14, 50), WARNUNG, 5.0)
		_zeichne_leben(z)

	_zeichne_kuppeln()
	_zeichne_zuweisung()
	_markiere_durchbrueche(pfad if not zeige_neu else vorschau_pfad, KEINE if not zeige_neu else vorschau_zelle)

	# Kampf: das Ziel eines Sprengers blinkt
	for ziel: Vector2i in sprengziele_aktiv:
		if fmod(_zeit, 0.6) < 0.4:
			var oz := Vector2(ziel) * zg
			draw_rect(Rect2(oz + Vector2(2, 2), Vector2(zg - 4, zg - 4)), Color(1.0, 0.45, 0.1, 0.95), false, 5.0)
			draw_rect(Rect2(oz + Vector2(28, 12), Vector2(8, 24)), Color(1.0, 0.5, 0.12))
			draw_rect(Rect2(oz + Vector2(28, 42), Vector2(8, 8)), Color(1.0, 0.5, 0.12))

	# Felder in Reichweite, die die Auswahl nicht treffen kann: rot schraffiert
	for z in _sicht_blind:
		var o := Vector2(z) * zg
		draw_rect(Rect2(o, Vector2(zg, zg)), Color(0.85, 0.1, 0.15, 0.3))
		for k in 4:
			draw_line(o + Vector2(k * 16.0, 0), o + Vector2(0, k * 16.0), Color(0.95, 0.2, 0.2, 0.55), 2.0)
			draw_line(o + Vector2(zg, k * 16.0 + 16.0), o + Vector2(k * 16.0 + 16.0, zg), Color(0.95, 0.2, 0.2, 0.55), 2.0)

	# Reichweite des angeklickten Turms, der angeklickten Batterie oder Stellung
	if auswahl != KEINE:
		var kreise: Array[float] = []
		if ausbau.get(auswahl, FREI) == TURM:
			kreise = [float(turm_wert(auswahl, "reichweite"))]
		elif ausbau.get(auswahl, FREI) == STELLUNG:
			# leere Stellung in der Bauphase: innen Technogunner, außen Scharfschütze
			for typ: String in ["technogunner", "scharfschuetze"]:
				kreise.append(Werte.EINHEITEN[typ]["reichweite"] + posten_bonus(auswahl, Werte.EINHEITEN[typ]))
		elif inhalt(auswahl) == BATTERIE:
			kreise = [Werte.BATTERIE["reichweite"]]
		elif ausbau.get(auswahl, FREI) == MAGNET:
			_zeichne_magnetlinie(auswahl, magnet_richtung.get(auswahl, Vector2i.RIGHT), 0.8)
		var m := (Vector2(auswahl) + Vector2(0.5, 0.5)) * zg
		for weite in kreise:
			draw_circle(m, weite * zg, Color(0.5, 0.88, 1.0, 0.06))
			draw_arc(m, weite * zg, 0.0, TAU, 96, Color(0.5, 0.88, 1.0, 0.8), 2.0)

	# Bauvorschau unter dem Mauszeiger
	if vorschau_typ == TURM:
		# mögliche Turmplätze hervorheben
		for z: Vector2i in feld:
			if ausbau_hindernis(z, TURM) == "":
				_r(z, 26, 16, 12, 12, Color(Color(Werte.TURMARTEN[turm_form(z)]["farbe"]), 0.5 + 0.3 * sin(_zeit * 5.0)))
	if vorschau_typ == GENERATOR or vorschau_typ == TURM:
		# Höfe hervorheben: dort passt ein Schildgenerator hinein
		for h: Array in _hoefe:
			for c: Vector2i in h:
				if ist_frei(c):
					draw_rect(Rect2(Vector2(c) * zg + Vector2(3, 3), Vector2(zg - 6, zg - 6)), Color(0.42, 0.72, 1.0, 0.12 + 0.06 * sin(_zeit * 4.0)))
	if vorschau_typ == GENERATOR and vorschau_ok:
		_zeichne_generator(vorschau_zelle, 0.7)
		if vorschau_partner != KEINE:
			_zeichne_generator(vorschau_partner, 0.7)
	if vorschau_typ == SPIEGEL:
		# mögliche Spiegelplätze: Wallenden
		for z: Vector2i in feld:
			if ausbau_hindernis(z, SPIEGEL) == "":
				_r(z, 26, 16, 12, 12, Color(Color("cfe8f5"), 0.5 + 0.3 * sin(_zeit * 5.0)))
	if vorschau_typ != FREI and in_karte(vorschau_zelle):
		var rahmen := Rect2(Vector2(vorschau_zelle) * zg + Vector2(2, 2), Vector2(zg - 4, zg - 4))
		if not vorschau_ok:
			draw_rect(rahmen, WARNUNG, false, 4.0)
		elif vorschau_typ == TOR:
			_zeichne_ausbau(vorschau_zelle, TOR, 0.7)
		elif vorschau_typ == PANZER:
			_zeichne_panzer(vorschau_zelle, 0.7)
		elif vorschau_typ == SPIEGEL:
			_zeichne_ausbau(vorschau_zelle, SPIEGEL, 0.7)
			for c in spiegel_felder(vorschau_zelle):
				draw_rect(Rect2(Vector2(c) * zg + Vector2(4, 4), Vector2(zg - 8, zg - 8)), Color(0.75, 0.92, 1.0, 0.22))
		elif vorschau_typ == MAGNET:
			_zeichne_ausbau(vorschau_zelle, MAGNET, 0.7)
			_zeichne_magnetlinie(vorschau_zelle, vorschau_richtung, 0.8)
		elif vorschau_typ == GENERATOR:
			pass   # oben gezeichnet
		elif vorschau_typ == KOMMANDANT:
			var mk := (Vector2(vorschau_zelle) + Vector2(0.5, 0.5)) * zg
			draw_arc(mk + Vector2(0, 14), 17.0, 0.0, TAU, 24, Color("ffd34d"), 3.0)
			draw_arc(mk, float(Werte.KOMMANDANT["reichweite"]) * zg, 0.0, TAU, 64, Color(TECH_LICHT, 0.6), 2.0)
			draw_string(ThemeDB.fallback_font, Vector2(vorschau_zelle) * zg + Vector2(-20, -6), "Brakk", HORIZONTAL_ALIGNMENT_CENTER, zg + 40, 14, Color("ffd34d"))
		elif vorschau_typ == STELLUNG or vorschau_typ == TURM:
			if vorschau_typ == TURM:
				# die Stützen, die dieser Turm belegen würde
				for n in _waehle_stuetzen(vorschau_zelle, turm_form(vorschau_zelle)):
					_zeichne_stuetze(n, Color(Werte.TURMARTEN[turm_form(vorschau_zelle)]["farbe"]), 0.5)
			_zeichne_ausbau(vorschau_zelle, vorschau_typ, 0.7)
			var radius: float = float(Werte.TURMARTEN[turm_form(vorschau_zelle)]["reichweite"]) if vorschau_typ == TURM else 3.0 + Werte.POSTEN_REICHWEITE_BONUS
			if vorschau_typ == TURM:
				var vart: Dictionary = Werte.TURMARTEN[turm_form(vorschau_zelle)]
				draw_string(ThemeDB.fallback_font, Vector2(vorschau_zelle) * zg + Vector2(-20, -6), vart["name"], HORIZONTAL_ALIGNMENT_CENTER, zg + 40, 14, Color(vart["farbe"]))
			draw_arc((Vector2(vorschau_zelle) + Vector2(0.5, 0.5)) * zg, radius * zg, 0.0, TAU, 64, Color(TECH_LICHT, 0.6), 2.0)
		else:
			if vorschau_typ == WALL:
				if not Werte.grafik_hd:   # HD-2D: durchsichtiger Mauerblock (hd_ansicht._bauvorschau)
					_zeichne_wall(vorschau_zelle, 0.6)
			elif vorschau_typ == BATTERIE:
				_zeichne_batterie(vorschau_zelle, 0.6)
				if vorschau_partner != KEINE:
					_zeichne_fabrik(vorschau_partner, 0.6)
				draw_arc((Vector2(vorschau_zelle) + Vector2(0.5, 0.5)) * zg, Werte.BATTERIE["reichweite"] * zg, 0.0, TAU, 96, Color(TECH_LICHT, 0.6), 2.0)
			else:
				_zeichne_fabrik(vorschau_zelle, 0.6)
			var bricht := weg_bricht_durch(vorschau_pfad, vorschau_zelle)
			_zeichne_weg(vorschau_pfad, WARNUNG if bricht else WEG_NEU, true)
			_markiere_durchbrueche(vorschau_pfad, vorschau_zelle)


## Ein Erdwall, der einen Turm stützt: die Krone in der Farbe des Turms, mit einer Klammer zum Turm hin –
## so liest sich Turm plus Stützen als ein Bauwerk.
func _zeichne_stuetze(z: Vector2i, farbe: Color, staerke: float) -> void:
	var zg := float(Werte.ZELLE)
	var o := Vector2(z) * zg
	draw_rect(Rect2(o + Vector2(6, 6), Vector2(zg - 12, zg - 12)), Color(farbe, staerke))
	draw_rect(Rect2(o + Vector2(5, 5), Vector2(zg - 10, zg - 10)), Color(farbe, minf(1.0, staerke + 0.4)), false, 3.0)
	if stuetze_von.has(z):
		var r: Vector2i = stuetze_von[z] - z   # Richtung zum Turm
		var mitte := o + Vector2(zg, zg) * 0.5
		draw_rect(Rect2(mitte + Vector2(r) * zg * 0.5 - Vector2(7, 7), Vector2(14, 14)), Color(farbe, 0.95))


## Turm außer Betrieb (lahmgelegt oder ohne Stützen): abgedunkelt mit rotem Kreuz
func _zeichne_turm_aus(z: Vector2i) -> void:
	_r(z, 12, 2, 40, 42, Color(0, 0, 0, 0.55))
	var o := Vector2(z) * Werte.ZELLE
	draw_line(o + Vector2(18, 8), o + Vector2(46, 38), WARNUNG, 4.0)
	draw_line(o + Vector2(46, 8), o + Vector2(18, 38), WARNUNG, 4.0)


## Stellung = Steinplattform mit Brüstung, Turm = Geschütz des Technoclans.
func _zeichne_ausbau(z: Vector2i, typ: int, alpha: float) -> void:
	var a := Color(1, 1, 1, alpha)
	if Werte.grafik_neu and typ == STELLUNG:
		# Plattform mit Brüstung; die Truppe darin zeichnet die Brüstung noch einmal vor sich
		var o := Vector2(z) * Werte.ZELLE
		draw_texture_rect(neu_bild("wand/stellung.png"), Rect2(o + Vector2(2, -2), Vector2(60, 48)), false, a)
		draw_texture(neu_bild("wand/bruestung.png"), o + Vector2(6, 26), a)
		return
	if Werte.grafik_neu and typ == TURM:
		if Werte.grafik_hd:
			return   # HD-2D: Turm der Bauvorschau steht als Sprite3D auf dem Wall
		TurmBild.zeichne(self, self, z, (Vector2(z) + Vector2(0.5, 0.5)) * Werte.ZELLE + Vector2(0, 24), 0, -1.0, alpha)
		return
	if typ == STELLUNG:
		_r(z, 6, 4, 52, 38, STEIN_DUNKEL * a)
		_r(z, 8, 6, 48, 34, STEIN * a)
		_r(z, 14, 12, 36, 22, STEIN_HELL * a)
		_r(z, 8, 6, 12, 6, STEIN_DUNKEL * a)
		_r(z, 26, 6, 12, 6, STEIN_DUNKEL * a)
		_r(z, 44, 6, 12, 6, STEIN_DUNKEL * a)
	elif typ == TOR:
		# Durchgang im Wall: zwei Pfosten, dunkle Öffnung, heller Sturz
		_r(z, 6, 2, 52, 60, STEIN_DUNKEL * a)
		_r(z, 16, 12, 32, 50, Color("1b1722") * a)
		_r(z, 6, 2, 52, 10, STEIN * a)
		_r(z, 6, 12, 10, 50, STEIN * a)
		_r(z, 48, 12, 10, 50, STEIN * a)
		_r(z, 26, 4, 12, 6, TECH_LICHT * a)
		_r(z, 20, 52, 24, 4, TECH_LICHT * Color(1, 1, 1, 0.6 * alpha))
	elif typ == SPIEGEL:
		# Sockel mit schräger Spiegelscheibe
		_r(z, 10, 26, 44, 18, STEIN_DUNKEL * a)
		var o := Vector2(z) * Werte.ZELLE
		draw_colored_polygon(PackedVector2Array([o + Vector2(14, 30), o + Vector2(26, 4), o + Vector2(50, 4), o + Vector2(38, 30)]), Color("cfe8f5") * a)
		draw_line(o + Vector2(24, 24), o + Vector2(34, 8), Color(1, 1, 1, 0.9 * alpha), 3.0)
		draw_polyline(PackedVector2Array([o + Vector2(14, 30), o + Vector2(26, 4), o + Vector2(50, 4), o + Vector2(38, 30), o + Vector2(14, 30)]), Color("6a7d8c") * a, 2.0)
	elif typ == MAGNET:
		# Hufeisen, die offene Seite zeigt in Zugrichtung
		var r: Vector2i = magnet_richtung.get(z, vorschau_richtung)
		var m := (Vector2(z) + Vector2(0.5, 0.4)) * Werte.ZELLE
		var vor := Vector2(r)
		var quer := Vector2(-vor.y, vor.x)
		_r(z, 14, 8, 36, 34, TECH_DUNKEL * a)
		draw_arc(m - vor * 4.0, 13.0, quer.angle(), quer.angle() + PI, 16, Color("8c96a8") * a, 7.0)
		draw_line(m + quer * 13.0 - vor * 4.0, m + quer * 13.0 + vor * 10.0, Color("e0453a") * a, 7.0)
		draw_line(m - quer * 13.0 - vor * 4.0, m - quer * 13.0 + vor * 10.0, Color("3a7be0") * a, 7.0)
	else:
		var art: String = turm_art.get(z, turm_form(z))
		if art == "":
			art = "geschuetz"
		var licht := Color(Werte.TURMARTEN[art]["farbe"])
		_r(z, 12, 2, 40, 42, TECH_DUNKEL * a)
		_r(z, 14, 4, 36, 38, TECH * a)
		_r(z, 18, 8, 28, 20, TECH_HELL * a)
		match art:
			"frost":
				# Kristall statt Rohr
				_r(z, 28, 6, 8, 24, licht * a)
				_r(z, 22, 12, 20, 8, licht * a)
				_r(z, 30, 2, 4, 4, Color.WHITE * a)
			"schild":
				# Kuppel
				var mk := (Vector2(z) + Vector2(0.5, 0.0)) * Werte.ZELLE + Vector2(0, 20)
				draw_circle(mk, 13.0, Color(licht, 0.55 * alpha))
				draw_arc(mk, 13.0, PI, TAU, 16, licht * a, 3.0)
				_r(z, 24, 20, 16, 6, TECH_LICHT * a)
			"heil":
				# grünes Kreuz
				_r(z, 28, 6, 8, 24, licht * a)
				_r(z, 20, 14, 24, 8, licht * a)
			"funk":
				# Antenne mit Querstreben
				_r(z, 30, -10, 4, 30, MESSING * a)
				_r(z, 22, -6, 20, 3, licht * a)
				_r(z, 25, 2, 14, 3, licht * a)
				_r(z, 26, 14, 12, 8, licht * a)
			"lanze":
				# langes Rohr nach beiden Seiten
				_r(z, 26, 12, 12, 12, licht * a)
				_r(z, 0, 15, 26, 6, TECH_DUNKEL * a)
				_r(z, 38, 15, 26, 6, TECH_DUNKEL * a)
				_r(z, 0, 16, 6, 4, licht * a)
				_r(z, 58, 16, 6, 4, licht * a)
			_:
				_r(z, 26, 12, 12, 12, licht * a)
				_r(z, 2, 14, 12, 8, TECH_DUNKEL * a)    # Rohre links/rechts
				_r(z, 50, 14, 12, 8, TECH_DUNKEL * a)
		# Stufe: goldene Punkte unten am Sockel
		for i in int(turm_stufe.get(z, 1)) - 1:
			_r(z, 22 + i * 12, 34, 8, 6, Color("ffd34d") * a)


## Felder, die ein Spiegel auf `z` sieht (Umkreis 3 Felder): dorthin können Bodentruppen über ihn schießen.
func spiegel_felder(z: Vector2i) -> Array[Vector2i]:
	var felder: Array[Vector2i] = []
	var m := mitte(z)
	for y in range(z.y - 3, z.y + 4):
		for x in range(z.x - 3, z.x + 4):
			var c := Vector2i(x, y)
			if c != z and in_karte(c) and ist_frei(c) and Vector2(c - z).length() <= 3.2 and sicht_frei(m, mitte(c)):
				felder.append(c)
	return felder


## Die Zuglinie eines Magneten: die Felder vor ihm bis zum ersten Hindernis (höchstens MAGNET.laenge).
func magnet_linie(z: Vector2i, r: Vector2i) -> Array[Vector2i]:
	var linie: Array[Vector2i] = []
	var c := z + r
	for i in int(Werte.MAGNET["laenge"]):
		if not in_karte(c) or not ist_frei(c):
			break
		linie.append(c)
		c += r
	return linie


func _zeichne_magnetlinie(z: Vector2i, r: Vector2i, staerke: float) -> void:
	for c in magnet_linie(z, r):
		var o := Vector2(c) * Werte.ZELLE
		draw_rect(Rect2(o + Vector2(6, 6), Vector2(52, 52)), Color(0.9, 0.3, 0.3, 0.12 * staerke))
		draw_rect(Rect2(o + Vector2(6, 6), Vector2(52, 52)), Color(0.95, 0.4, 0.35, 0.6 * staerke), false, 2.0)
		var mitte := o + Vector2(32, 32)
		draw_line(mitte, mitte - Vector2(r) * 14.0, Color(1, 0.8, 0.8, 0.8 * staerke), 3.0)


# ---------------------------------------------------------- Höfe und Schildkuppeln

## Höfe suchen: zusammenhängende Flächen ohne Erdwall (frei oder mit Gebäude), die keinen Kartenrand, keine Zone, keine Basis
## und keinen Checkpoint berühren und HOF_MIN bis HOF_MAX Felder groß sind. Ein Tor zählt als Erdwall (für Gegner zu).
func _finde_hoefe() -> void:
	_hoefe = []
	var gesehen := {}
	for y in Werte.ZEILEN:
		for x in Werte.SPALTEN:
			var start := Vector2i(x, y)
			if gesehen.has(start) or inhalt(start) == WALL:
				continue
			var flaeche: Array[Vector2i] = [start]
			gesehen[start] = true
			var i := 0
			while i < flaeche.size():
				var c := flaeche[i]
				i += 1
				for n in NACHBARN:
					var d := c + n
					if in_karte(d) and not gesehen.has(d) and inhalt(d) != WALL:
						gesehen[d] = true
						flaeche.append(d)
			var beruehrt := false
			for c in flaeche:
				if c.x < Werte.ZONE_SPALTEN or c.x == 0 or c.y == 0 or c.x == Werte.SPALTEN - 1 or c.y == Werte.ZEILEN - 1 or ist_basis(c) or checkpoints.has(c):
					beruehrt = true
					break
			if not beruehrt and flaeche.size() >= Werte.HOF_MIN and flaeche.size() <= Werte.HOF_MAX:
				_hoefe.append(flaeche)


## Der Hof, zu dem `z` gehört (leer = kein Hof).
func hof_von(z: Vector2i) -> Array:
	for h: Array in _hoefe:
		if h.has(z):
			return h
	return []


## Kuppeln neu berechnen: Jeder Generator, dessen beide Felder noch in einem Hof liegen, spannt eine Kuppel
## über den ganzen Ring (alle Erdwälle am Hof) plus KUPPEL_RAND. Bricht der Ring auf, erlischt sie.
func aktualisiere_kuppeln() -> void:
	kuppeln = []
	for z: Vector2i in generator_paar:
		var p: Vector2i = generator_paar[z]
		if z.x * 100 + z.y > p.x * 100 + p.y:
			continue   # jedes Paar nur einmal
		var hof := hof_von(z)
		if hof.is_empty() or not hof.has(p):
			continue
		var m := (mitte(z) + mitte(p)) / 2.0
		var weite := 0.0
		for c: Vector2i in hof:
			for n in NACHBARN:
				if inhalt(c + n) == WALL:
					weite = maxf(weite, m.distance_to(mitte(c + n)))
		kuppeln.append([m, weite + Werte.KUPPEL_RAND * Werte.ZELLE, z])


func in_kuppel(punkt: Vector2) -> bool:
	for k: Array in kuppeln:
		if punkt.distance_to(k[0]) <= float(k[1]):
			return true
	return false


## Schildgenerator: Sockel mit leuchtendem Kern; die Kuppel selbst zeichnet _zeichne_kuppeln.
func _zeichne_generator(z: Vector2i, alpha: float) -> void:
	var a := Color(1, 1, 1, alpha)
	if Werte.grafik_neu:
		if Werte.grafik_hd and alpha >= 1.0:
			return   # HD-2D: Sprite3D (hd_ansicht.gd)
		var og := Vector2(z) * Werte.ZELLE
		draw_texture_rect(neu_bild("tuerme/schild.png"), Rect2(og + Vector2(32 - 62, 58 - 122), Vector2(128, 128)), false, a)
		return
	_r(z, 6, 20, 52, 38, TECH_DUNKEL * a)
	_r(z, 10, 24, 44, 30, TECH * a)
	var m := (Vector2(z) + Vector2(0.5, 0.45)) * Werte.ZELLE
	draw_circle(m, 13.0, Color(0.42, 0.72, 1.0, 0.8 * alpha))
	draw_circle(m, 6.0, Color(0.85, 0.95, 1.0, alpha))


## Pfeile der angeklickten Fabrik zu ihren zugewiesenen Stellungen (und der Pfeil, der gerade gezogen wird).
var zuweis_fabrik := KEINE
var zuweis_ziele: Array = []
var zuweis_zug := Vector2.INF   # Mausposition, solange ein Pfeil gezogen wird
var zuweis_einrast := KEINE     # Stellung, über der die Maus beim Ziehen gerade steht: der Pfeil rastet dort ein

func _zeichne_zuweisung() -> void:
	if zuweis_fabrik == KEINE or Werte.grafik_hd:
		return   # HD-2D: zeichnet die Oberfläche (hud.gd), oben auf den Mauern statt am Boden
	var zg := float(Werte.ZELLE)
	var von := (Vector2(zuweis_fabrik) + Vector2(0.5, 0.5)) * zg
	for w in zuweis_ziele:
		_einrastrahmen(w, Color("ffd34d"))
		_pfeil(von, (Vector2(w) + Vector2(0.5, 0.5)) * zg, Color("ffd34d"))
	if zuweis_einrast != KEINE:
		_einrastrahmen(zuweis_einrast, Color(1, 1, 1, 0.9))
		_pfeil(von, (Vector2(zuweis_einrast) + Vector2(0.5, 0.5)) * zg, Color(1, 0.95, 0.7, 0.9))
	elif zuweis_zug != Vector2.INF:
		_pfeil(von, zuweis_zug - position, Color(1, 0.83, 0.3, 0.5))


## Fest zugewiesene Stellung: Rahmen mit Ecken ("eingerastet").
func _einrastrahmen(w: Vector2i, farbe: Color) -> void:
	var o := Vector2(w) * float(Werte.ZELLE)
	draw_rect(Rect2(o + Vector2(3, 3), Vector2(58, 58)), farbe, false, 2.0)
	for e: Vector2 in [Vector2(3, 3), Vector2(51, 3), Vector2(3, 51), Vector2(51, 51)]:
		draw_rect(Rect2(o + e, Vector2(10, 10)), farbe)


func _pfeil(von: Vector2, nach: Vector2, farbe: Color) -> void:
	var r := (nach - von)
	if r.length() < 8.0:
		return
	var n := r.normalized()
	var spitze := nach - n * 14.0
	draw_line(von + n * 18.0, spitze, farbe, 3.0)
	var q := Vector2(-n.y, n.x)
	draw_colored_polygon(PackedVector2Array([nach - n * 4.0, spitze - n * 6.0 + q * 7.0, spitze - n * 6.0 - q * 7.0]), farbe)


func _zeichne_kuppeln() -> void:
	for k: Array in kuppeln:
		var puls := 0.5 + 0.5 * sin(_zeit * 2.0)
		draw_circle(k[0], float(k[1]), Color(0.42, 0.72, 1.0, 0.07 + 0.03 * puls))
		draw_arc(k[0], float(k[1]), 0.0, TAU, 96, Color(0.55, 0.82, 1.0, 0.55), 2.0)


## Gepanzerter Erdwall: Stahlbeschlag an den Kanten mit Nieten.
## Wallpanzer: Stahlrahmen mit Nieten und in der Mitte das Schild aus der Bauleiste (16.11. deutlicher).
## In HD-2D liegt das auf der Mauerkrone, dazu Stahlplatten an den Seiten (hd_ansicht._wallpanzer).
const PANZER_SCHILD := [
	".AAAAAAAAA.",
	"ALLLLLLLLLA",
	"ALcBBBBBcBA",
	"ABBBBBBBBBA",
	"ABDDDDDDDBA",
	"ABBBBBBBBBA",
	"ABcBBBBBcBA",
	".ABBBBBBBA.",
	".ABBBBBBBA.",
	"..ABBBBBA..",
	"...ABBBA...",
	"....ABA....",
	".....A.....",
]

func _zeichne_panzer(z: Vector2i, alpha: float) -> void:
	var a := Color(1, 1, 1, alpha)
	var stahl := Color("8c96a8")
	var dunkel := Color("4a5160")
	_r(z, 0, 0, 64, 6, stahl * a)
	_r(z, 0, 0, 6, 46, stahl * a)
	_r(z, 58, 0, 6, 46, stahl * a)
	_r(z, 0, 40, 64, 6, dunkel * a)
	for x: int in [2, 30, 58]:
		_r(z, x, 1, 4, 4, Color("d8dee9") * a)
	var farben := {"A": Color("10141a"), "B": Color("7e8a98"), "L": Color("c9d2de"), "D": Color("545e6b"), "c": Color("7fe0ff")}
	var o := Vector2(32 - 11, 21 - 13)   # Schild mittig, 2 Pixel je Bildpunkt
	for y in PANZER_SCHILD.size():
		var zeile: String = PANZER_SCHILD[y]
		for x in zeile.length():
			if zeile[x] != ".":
				_r(z, o.x + x * 2, o.y + y * 2, 2, 2, Color(farben[zeile[x]]) * a)


## Neue Grafik: Bild aus assets/neu (zwischengespeichert).
func neu_bild(pfad: String) -> Texture2D:
	if not _neu_bilder.has(pfad):
		_neu_bilder[pfad] = load(Werte.NEU + pfad)
	return _neu_bilder[pfad]


## Neue Grafik: Tech-Mauer im Stil der TC-Erdwälle – Metallplatte mit Fugen, helle Kante an offenen Seiten,
## sichtbare Vorderseite mit cyanem Lichtband, wenn darunter kein Wall anschließt.
func _zeichne_wall_neu(z: Vector2i, alpha: float) -> void:
	var a := Color(1, 1, 1, alpha)
	var o := Vector2(z) * Werte.ZELLE
	var unten := inhalt(z + Vector2i.DOWN) == WALL
	var v := 0 if (z.x * 7 + z.y * 3) % 5 != 0 else 1 + (z.x + z.y) % 4
	if Werte.grafik_hd:
		unten = true   # HD-2D: die Seiten macht der 3D-Mauerblock, hier nur die Oberseite
	var hoehe := 64.0 if unten else 46.0
	draw_texture_rect_region(neu_bild("wand/top_%d.png" % v), Rect2(o, Vector2(64, hoehe)), Rect2(0, 0, 64, hoehe), a)
	if inhalt(z + Vector2i.UP) != WALL:
		draw_rect(Rect2(o, Vector2(64, 3)), Color("b8c2cc") * a)
	if inhalt(z + Vector2i.LEFT) != WALL:
		draw_rect(Rect2(o, Vector2(3, hoehe)), Color("a9b3bd") * a)
	if inhalt(z + Vector2i.RIGHT) != WALL:
		draw_rect(Rect2(o + Vector2(61, 0), Vector2(3, hoehe)), Color("5b636c") * a)
	if not unten:
		draw_texture(neu_bild("wand/front.png"), o + Vector2(0, 46), a)
		draw_rect(Rect2(o + Vector2(0, 64), Vector2(64, 4)), Color(0, 0, 0, 0.28 * alpha))


## 18.11.: Gelände aus der Karten-Datei. Wasser: blaue Fläche mit hellem Ufer und Wellen. Fels: Brocken mit Licht oben
## links und Schatten unten. In HD-2D liegt das als Boden unter den Felsklötzen (hd_ansicht.gd).
const WASSER := Color("2b5d8a")
const WASSER_HELL := Color("5f9cc9")
const FELS := Color("4a423b")
const FELS_HELL := Color("7a7064")
const FELS_LICHT := Color("9a8f80")

func _zeichne_gelaende() -> void:
	for z: Vector2i in gelaende:
		var h := hash(z)
		if gelaende[z] == "wasser":
			_r(z, 0, 0, 64, 64, WASSER)
			for n: Vector2i in NACHBARN:
				if gelaende.get(z + n, "") != "wasser":
					var r := Rect2(0, 0, 64, 4) if n == Vector2i.UP else (Rect2(0, 60, 64, 4) if n == Vector2i.DOWN \
						else (Rect2(0, 0, 4, 64) if n == Vector2i.LEFT else Rect2(60, 0, 4, 64)))
					_r(z, r.position.x, r.position.y, r.size.x, r.size.y, WASSER_HELL)
			for i in 3:
				var wx := 8 + ((h >> (i * 5)) % 6) * 7
				var wy := 12 + i * 16
				_r(z, wx, wy, 12, 2, Color(WASSER_HELL, 0.7))
		else:
			_r(z, 0, 0, 64, 64, FELS)
			for i in 3:
				var bx := 4 + ((h >> (i * 4)) % 4) * 10
				var by := 4 + i * 18
				var bw := 22 + ((h >> (i * 3 + 9)) % 3) * 6
				_r(z, bx, by + 14, bw, 4, Color(0, 0, 0, 0.3))
				_r(z, bx, by, bw, 14, FELS_HELL)
				_r(z, bx, by, bw, 3, FELS_LICHT)
				_r(z, bx, by, 3, 14, FELS_LICHT)


## 18.11. (Etappe 2): Gelände mit Wirkung, schlicht gezeichnet (gleich in Klassisch und Neu).
const ANHOEHE := Color("a39a5c")
const SUMPF := Color("3d4a2c")
const HOLZ := Color("8a6239")
const HOLZ_HELL := Color("b58550")
const WALD := Color("244a26")
const WALD_HELL := Color("3f7a3a")
const ERZ := Color("c98a3d")

func _zeichne_boden_wirkung() -> void:
	for z: Vector2i in boden:
		var h := hash(z)
		match str(boden[z]):
			"anhoehe":
				# erhöhte Fläche: hellere Kuppe, Schattenkante unten und rechts
				_r(z, 0, 0, 64, 64, Color(ANHOEHE, 0.55))
				_r(z, 4, 4, 56, 52, Color(ANHOEHE.lightened(0.25), 0.45))
				for n: Vector2i in [Vector2i.DOWN, Vector2i.RIGHT]:
					if boden.get(z + n, "") != "anhoehe":
						_r(z, 0 if n == Vector2i.DOWN else 58, 58 if n == Vector2i.DOWN else 0, 64 if n == Vector2i.DOWN else 6, 6 if n == Vector2i.DOWN else 64, Color(0, 0, 0, 0.3))
				for i in 3:
					_r(z, 12 + i * 14, 30 - i * 6, 10, 2, Color(1, 1, 1, 0.35))
			"sumpf":
				_r(z, 0, 0, 64, 64, Color(SUMPF, 0.8))
				for i in 4:
					var px := 6 + ((h >> (i * 4)) % 6) * 9
					var py := 6 + i * 14
					_r(z, px, py, 14, 6, Color(WASSER, 0.7))
					_r(z, px + 2, py - 6, 2, 6, Color("6f8a3c"))
			"bruecke":
				_r(z, 0, 0, 64, 64, WASSER)
				_r(z, 4, 0, 56, 64, HOLZ)
				for i in 8:
					_r(z, 4, i * 8 + 1, 56, 2, HOLZ_HELL)
				_r(z, 4, 0, 4, 64, Color(0, 0, 0, 0.35))
				_r(z, 56, 0, 4, 64, Color(0, 0, 0, 0.35))
			"ruine":
				_r(z, 0, 0, 64, 64, Color(STEIN_DUNKEL, 0.35))
				for i in 4:
					var bx := 4 + ((h >> (i * 3)) % 5) * 10
					var by := 6 + i * 14
					_r(z, bx, by, 16, 9, STEIN)
					_r(z, bx, by, 16, 3, STEIN_HELL)
			"wald":
				_r(z, 0, 0, 64, 64, Color(WALD, 0.6))
				var o := Vector2(z) * Werte.ZELLE
				for i in 4:
					var m := o + Vector2(18 + (i % 2) * 28 + ((h >> (i * 5)) % 3) * 2, 18 + int(i / 2.0) * 28)
					draw_circle(m + Vector2(2, 3), 15.0, Color(0, 0, 0, 0.3))
					draw_circle(m, 15.0, WALD)
					draw_circle(m + Vector2(-4, -4), 8.0, WALD_HELL)
			"erz":
				for i in 3:
					var ex := 6 + ((h >> (i * 4)) % 3) * 16
					var ey := 6 + i * 18
					var spitze := PackedVector2Array([Vector2(ex, ey + 18), Vector2(ex + 8, ey), Vector2(ex + 16, ey + 18)])
					for k in spitze.size():
						spitze[k] += Vector2(z) * Werte.ZELLE
					draw_colored_polygon(spitze, ERZ)
					_r(z, ex + 7, ey + 5, 3, 9, Color(1, 0.9, 0.6, 0.85))


## Neue Grafik: Boden wie in Terrain-Conquester und der Stilprobe – Grasfliesen aus dem TC-Blatt (zufällig gedreht),
## in der Zone dunkler Fels, dazu Bewuchs (Grasbüschel, Blumen, Steine) auf freien Feldern. Das Raster zeigt sich nur beim Bauen.
const BODEN_GRAS := [0, 0, 0, 1]   # nahtlose Grasfliesen, ungedreht (gedreht zeigten sie Kanten an jedem Feld)   # ähnliche Grüntöne, damit der Boden nicht wie ein Schachbrett wirkt
const BODEN_DEKO := [0, 0, 0, 0, 1, 1, 1, 6, 6, 2, 3, 35, 61, 4, 20]

func _zeichne_boden_neu() -> void:
	var zg := float(Werte.ZELLE)
	var blatt := neu_bild("terrain/SHEET2.png")
	var fels := neu_bild("terrain/SHEET3.png")
	for y in Werte.ZEILEN:
		for x in Werte.SPALTEN:
			var z := Vector2i(x, y)
			var h := hash(z * 7 + Vector2i(3, 11))
			var mitte := (Vector2(z) + Vector2(0.5, 0.5)) * zg
			if x < Werte.ZONE_SPALTEN:
				draw_set_transform(mitte, (h % 4) * PI / 2.0, Vector2.ONE)
				draw_texture_rect_region(fels, Rect2(-zg / 2, -zg / 2, zg, zg), Rect2(MYR_KACHELN[(h >> 3) % 2] * 32, 0, 32, 32))
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			else:
				draw_texture_rect_region(blatt, Rect2(Vector2(z) * zg, Vector2(zg, zg)), Rect2(BODEN_GRAS[(h >> 3) % BODEN_GRAS.size()] * 32, 0, 32, 32))
	# große, weiche Flecken (helleres und dunkleres Gras über mehrere Felder) – so liest sich der Boden als Fläche, nicht als Kacheln
	var links := float(Werte.ZONE_SPALTEN) * zg
	var f := _flecken()
	draw_texture_rect_region(f, Rect2(links, 0, Werte.SPALTEN * zg - links, Werte.ZEILEN * zg),
		Rect2(Werte.ZONE_SPALTEN * 16, 0, (Werte.SPALTEN - Werte.ZONE_SPALTEN) * 16, Werte.ZEILEN * 16))
	# Brut-Boden um Checkpoints, die zu Rundenbeginn dem Gegner gehören
	for c: Vector2i in brut_cps:
		var bb := _brut_bild(c)
		draw_texture_rect(bb, Rect2((Vector2(c) + Vector2(0.5, 0.5)) * zg - bb.get_size(), bb.get_size() * 2.0), false)
	# Bewuchs: höchstens einer je freiem Feld, nicht auf dem Gegnerweg
	var auf_weg := {}
	for p: Vector2i in pfad:
		auf_weg[p] = true
	for y in Werte.ZEILEN:
		for x in range(Werte.ZONE_SPALTEN, Werte.SPALTEN):
			var z := Vector2i(x, y)
			var h := hash(z * 13 + Vector2i(5, 1))
			if h % 10 == 0 or auf_weg.has(z) or feld.has(z) or ist_basis(z) or checkpoints.has(z):
				continue
			var i: int = BODEN_DEKO[(h >> 4) % BODEN_DEKO.size()]
			var q := Rect2((i % 32) * 32, 96 + (i / 32) * 32, 32, 32)
			var o := Vector2(z) * zg + Vector2(6 + (h >> 8) % 20, 4 + (h >> 13) % 22)
			draw_texture_rect_region(blatt, Rect2(o, Vector2(32, 32)), q)
	if vorschau_typ != FREI:
		var linie := Color(0.04, 0.1, 0.04, 0.28)
		for x in Werte.SPALTEN + 1:
			draw_line(Vector2(x * zg, 0), Vector2(x * zg, Werte.ZEILEN * zg), linie, 1.0)
		for y in Werte.ZEILEN + 1:
			draw_line(Vector2(0, y * zg), Vector2(Werte.SPALTEN * zg, y * zg), linie, 1.0)


var _flecken_bild: ImageTexture

## Brut-Boden (16.11.): Um Checkpoints, die zu Beginn der Runde (Wellenstart oder Bauphase) dem Gegner gehören, breitet sich
## Myr-Boden aus – so sieht man das Gebiet des Gegners. Während der Welle ändert er sich nicht.
var brut_cps: Array[Vector2i] = []
## Myr-Boden der neuen Grafik (16.11.): rissige Erde und Fels aus SHEET3, kupfern überzogen – die Myriaden sind kupfern,
## Lila gehört dem Technoclan (Farben nicht vermischen).
const MYR_KACHELN := [6, 7]
const MYR_SCHLEIER := Color(0.5, 0.24, 0.06, 0.3)

## Farbe des Gegners für Markierungen: neue Grafik kupfern, klassisch pink.
static func feind_farbe() -> Color:
	return Color("e8893a") if Werte.grafik_neu else Color("ff5ad0")
var _brut_bilder := {}   # Checkpoint-Feld -> ImageTexture (128 Bildpunkte = 4 Felder, gezeigt mit Maßstab 2)

func brut_aktualisieren() -> void:
	var neu: Array[Vector2i] = []
	if cp_aktiv:
		for i in checkpoints.size():
			if cp_feind[i]:
				neu.append(checkpoints[i])
	if neu != brut_cps:
		brut_cps = neu
		queue_redraw()


func _brut_bild(c: Vector2i) -> ImageTexture:
	if _brut_bilder.has(c):
		return _brut_bilder[c]
	var fels: Image = neu_bild("terrain/SHEET3.png").get_image()
	fels.convert(Image.FORMAT_RGBA8)
	var grund := Image.create(128, 128, false, Image.FORMAT_RGBA8)
	for i in 16:
		var h := hash(c * 31 + Vector2i(i, 7))
		grund.blit_rect(fels, Rect2i(MYR_KACHELN[h % 2] * 32, 0, 32, 32), Vector2i((i % 4) * 32, (i / 4) * 32))
	var maske := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	var r := FastNoiseLite.new()
	r.seed = hash(c)
	r.frequency = 0.18
	for y in 32:
		for x in 32:
			var d := Vector2(x + 0.5 - 16.0, y + 0.5 - 16.0).length() / 8.0   # in Feldern
			var t: float = (int(BAYER[(y % 4) * 4 + x % 4]) / 16.0 - 0.47) * 0.25
			if d + r.get_noise_2d(x, y) * 0.45 + t < 1.55:
				maske.set_pixel(x, y, Color(1, 1, 1, 1))
	maske.resize(128, 128, Image.INTERPOLATE_NEAREST)
	var bild := Image.create(128, 128, false, Image.FORMAT_RGBA8)
	bild.blit_rect_mask(grund, maske, Rect2i(0, 0, 128, 128), Vector2i.ZERO)
	var schleier := Image.create(128, 128, false, Image.FORMAT_RGBA8)
	schleier.fill(MYR_SCHLEIER)
	bild.blend_rect_mask(schleier, maske, Rect2i(0, 0, 128, 128), Vector2i.ZERO)
	var t := ImageTexture.create_from_image(bild)
	_brut_bilder[c] = t
	return t
var _rauschen: FastNoiseLite
var _feucht: FastNoiseLite
const BAYER := [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]
const FLECK_HELL := Color(0.93, 0.9, 0.45, 0.16)
const FLECK_HELL2 := Color(0.96, 0.92, 0.5, 0.26)
const FLECK_DUNKEL := Color(0.02, 0.1, 0.03, 0.2)
const FLECK_DUNKEL2 := Color(0.02, 0.08, 0.03, 0.32)

## Farbe des Fleckenbilds an (x, y) in Fleckenpunkten (16 je Feld, auch außerhalb der Karte – für das HD-Umland).
func flecken_farbe(x: int, y: int) -> Color:
	if _rauschen == null:
		_rauschen = FastNoiseLite.new()
		_rauschen.seed = 4711
		_rauschen.frequency = 0.022
		_rauschen.fractal_octaves = 3
		_feucht = FastNoiseLite.new()
		_feucht.seed = 815
		_feucht.frequency = 0.05
	var t: float = (int(BAYER[posmod(y, 4) * 4 + posmod(x, 4)]) / 16.0 - 0.47) * 0.16
	var v: float = _rauschen.get_noise_2d(x, y) + _feucht.get_noise_2d(x, y) * 0.25 + t
	if v > 0.36:
		return FLECK_HELL2
	if v > 0.18:
		return FLECK_HELL
	if v < -0.36:
		return FLECK_DUNKEL2
	if v < -0.18:
		return FLECK_DUNKEL
	return Color(0, 0, 0, 0)

## Fleckenbild der ganzen Karte: 1 Bildpunkt = 4 Kartenpixel (2 Pixel der Grasfliese), geordnet gerastert wie Pixelkunst.
func _flecken() -> ImageTexture:
	if _flecken_bild != null:
		return _flecken_bild
	var w := Werte.SPALTEN * 16
	var h := Werte.ZEILEN * 16
	var bild := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			bild.set_pixel(x, y, flecken_farbe(x, y))
	_flecken_bild = ImageTexture.create_from_image(bild)
	return _flecken_bild


## Neue Grafik: der Gegnerweg als ausgetretener Pfad (dunkles Band) mit orangen Pfeilen Richtung Basis wie in der Stilprobe.
func _zeichne_weg_neu(weg: Array[Vector2i], farbe: Color, laufend: bool) -> void:
	var staerke := farbe.a
	var band := Color(0.1, 0.06, 0.02, 0.42 * staerke)
	var pfeil := Color(Color("ffb340"), staerke)
	var punkte: PackedVector2Array = []
	for z in weg:
		punkte.append((Vector2(z) + Vector2(0.5, 0.5)) * Werte.ZELLE)
	draw_polyline(punkte, band, 27.0)
	for p in punkte:
		draw_circle(p, 13.5, band)
	var abstand := 32.0
	var rest := fmod(_zeit * 20.0, abstand) if laufend else 0.0
	for i in punkte.size() - 1:
		var a := punkte[i]
		var b := punkte[i + 1]
		var laenge := a.distance_to(b)
		var richtung := (b - a) / laenge
		var d := rest
		while d < laenge:
			_chevron(a + richtung * d, richtung.angle(), pfeil)
			d += abstand
		rest = d - laenge


func _chevron(p: Vector2, winkel: float, farbe: Color) -> void:
	# das 16er-Pfeilmuster der Stilprobe, je Pixel 1,5 Bildpunkte
	draw_set_transform(p.round(), winkel, Vector2(1.5, 1.5))
	for i in 5:
		draw_rect(Rect2(-4 + i, -5 + i, 3, 1), farbe)
		draw_rect(Rect2(-4 + i, 4 - i, 3, 1), farbe)
	draw_rect(Rect2(1, -1, 3, 2), farbe)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _zeichne_wall(z: Vector2i, alpha: float) -> void:
	if Werte.grafik_neu:
		_zeichne_wall_neu(z, alpha)
		return
	var unten_wall := inhalt(z + Vector2i.DOWN) == WALL
	var a := Color(1, 1, 1, alpha)
	_r(z, 0, 0, 64, 64, ERDE_OBEN * a)
	_r(z, 0, 0, 64, 4, ERDE_KANTE * a)
	_r(z, 8, 8, 48, 32 if not unten_wall else 48, KRONE * a)
	_r(z, 16, 16, 8, 4, GRAS_HELL * a)
	_r(z, 40, 28, 8, 4, GRAS_HELL * a)
	if not unten_wall:
		_r(z, 0, 46, 64, 18, ERDE_FRONT * a)
		_r(z, 0, 60, 64, 4, ERDE_DUNKEL * a)
		_r(z, 12, 50, 4, 6, ERDE_DUNKEL * a)
		_r(z, 36, 52, 4, 6, ERDE_DUNKEL * a)


## Railgun-Batterie: Sockel, Geschütz aus dem Terrain-Conquester-Blatt und ein Zähler der Besatzung.
func _zeichne_batterie(z: Vector2i, alpha: float) -> void:
	var a := Color(1, 1, 1, alpha)
	if Werte.grafik_neu:
		# Batterie im Stil der Truppen (Pixel ×2): Bild je Ausbaustufe, beim Schuss die Schuss-Animation
		var bild := neu_bild("batterie/bat_%d.png" % clampi(int(batterie_stufe_neu.get(z, 0)), 0, 3))
		var t: float = batterie_schuss.get(z, -1.0)
		var quelle := Rect2(0, 0, 48, 48) if t < 0.0 else Rect2(mini(8, int(t / 0.7 * 9.0)) * 48, 48, 48, 48)
		var links: bool = batterie_blick.get(z, false)
		var o := Vector2(z) * Werte.ZELLE
		draw_rect(Rect2(o + Vector2(6, 44), Vector2(52, 14)), Color(0, 0, 0, 0.25 * alpha))
		if not Werte.grafik_hd:   # HD-2D: das Geschütz steht als Sprite3D (hd_ansicht.gd)
			draw_set_transform(o + Vector2(32, 0), 0.0, Vector2(-1.0 if links else 1.0, 1.0))
			draw_texture_rect_region(bild, Rect2(-48, -32, 96, 96), quelle, a)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		var plaetze_n: int = Werte.BATTERIE["plaetze"]
		var drin_n := besatzung_drin(z)
		for i in plaetze_n:
			_r(z, 8 + i * 18, 56, 14, 6, TECH_DUNKEL * a)
			_r(z, 10 + i * 18, 58, 10, 2, (TECH_LICHT if i < drin_n else STEIN_DUNKEL) * a)
		return
	_r(z, 4, 34, 56, 26, TECH_DUNKEL * a)
	_r(z, 6, 36, 52, 22, TECH * a)
	if not _blaetter.has("batterie"):
		_blaetter["batterie"] = load(Werte.BATTERIE["blatt"])
	var kante: int = Werte.BATTERIE["zelle"]
	draw_texture_rect_region(_blaetter["batterie"], Rect2(Vector2(z) * Werte.ZELLE + Vector2(-8, -24), Vector2(80, 80)), Rect2(0, 0, kante, kante), a)
	# Zähler: ein Kästchen je Platz, hell = besetzt
	var plaetze: int = Werte.BATTERIE["plaetze"]
	var drin := besatzung_drin(z)
	for i in plaetze:
		_r(z, 8 + i * 18, 50, 14, 8, TECH_DUNKEL * a)
		_r(z, 10 + i * 18, 52, 10, 4, (TECH_LICHT if i < drin else STEIN_DUNKEL) * a)


## Neue Grafik: Bild der Fabrik. Grundfabrik (Stufe 0) = Grundbau; spezialisiert = Grundbau mit Flügeln ihrer Truppe;
## Pilotenfabrik = eigener Kasernenbau. Die Bilder sind 64 px und füllen ihr Feld (Fußpunkt unten Mitte, Zeile 56).
const FABRIK_BILDER := {"technogunner": "gun", "scharfschuetze": "sni", "plasmawerfer": "pla"}

func fabrik_bild(z: Vector2i) -> String:
	var typ: String = fabrik_typ.get(z, "")
	if paar.has(z) or typ == "pilot":
		return "gebaeude/fabrik_pilot.png"
	if int(fabrik_stufe.get(z, 0)) >= 1 and FABRIK_BILDER.has(typ):
		return "gebaeude/fabrik_%s.png" % FABRIK_BILDER[typ]
	return "gebaeude/fabrik_grund.png"


func _zeichne_fabrik(z: Vector2i, alpha: float) -> void:
	var a := Color(1, 1, 1, alpha)
	if Werte.grafik_neu:
		# Bild statt Truppensymbol; in HD-2D steht es als Sprite3D (hd_ansicht.gd), die Karte zeigt nur die Vorschau
		if not Werte.grafik_hd:   # HD-2D: Bild und Bauvorschau stehen als Sprite3D (hd_ansicht.gd)
			var ecke := Vector2(z) * Werte.ZELLE + Vector2(0, Werte.ZELLE - 59)
			draw_rect(Rect2(Vector2(z) * Werte.ZELLE + Vector2(6, 54), Vector2(52, 8)), Color(0, 0, 0, 0.25 * alpha))
			draw_texture_rect(neu_bild(fabrik_bild(z)), Rect2(ecke, Vector2(64, 64)), false, a)
		_fabrik_beiwerk(z, alpha)
		return
	_r(z, 4, 12, 56, 48, TECH_DUNKEL * a)
	_r(z, 6, 14, 52, 26, TECH_HELL * a)
	_r(z, 6, 40, 52, 18, TECH * a)
	_r(z, 44, 2, 10, 14, TECH_DUNKEL * a)   # Schornstein
	_r(z, 46, 4, 6, 10, TECH * a)
	_r(z, 24, 44, 16, 16, TECH_DUNKEL * a)  # Tor
	_r(z, 12, 22, 8, 8, TECH_LICHT * a)
	_r(z, 26, 22, 8, 8, TECH_LICHT * a)
	# Welche Einheit baut diese Fabrik? Erstes Bild aus ihrem Animationsblatt.
	if fabrik_typ.has(z):
		var typ: String = fabrik_typ[z]
		if not _blaetter.has(typ):
			_blaetter[typ] = load(Werte.EINHEITEN[typ]["blatt"])
		var kante: int = Werte.EINHEITEN[typ]["zelle"]
		draw_texture_rect_region(_blaetter[typ], Rect2(Vector2(z) * Werte.ZELLE + Vector2(8, 10), Vector2(48, 48)), Rect2(0, 0, kante, kante))
	var stufe: int = fabrik_stufe.get(z, 0)
	if stufe > 0:
		draw_rect(Rect2(Vector2(z) * Werte.ZELLE + Vector2(3, 11), Vector2(58, 50)), Color(TECH_LICHT, 0.9 * alpha), false, 2.0)
	_fabrik_beiwerk(z, alpha)


## Stufenpunkte, fehlender Ausgang, Klammer zur Batterie und Baufortschritt (beide Grafiken)
func _fabrik_beiwerk(z: Vector2i, alpha: float) -> void:
	var a := Color(1, 1, 1, alpha)
	# Ausbaustufe: ein Punkt je Stufe oben links
	var stufe: int = fabrik_stufe.get(z, 0)
	if stufe > 0:
		for i in stufe:
			_r(z, 6 + i * 9, 3, 7, 7, TECH_DUNKEL * a)
			_r(z, 7 + i * 9, 4, 5, 5, Color("ffe9a8") * a)
	if not hat_ausgang(z):
		# Kein Ausgang (weder freies Feld noch Tor): Truppen besetzen nur direkt anliegende Stellungen
		_r(z, 5, 43, 14, 14, TECH_DUNKEL * a)
		var ecke := Vector2(z) * Werte.ZELLE + Vector2(8, 46)
		draw_line(ecke, ecke + Vector2(8, 8), WARNUNG * a, 2.0)
		draw_line(ecke + Vector2(8, 0), ecke + Vector2(0, 8), WARNUNG * a, 2.0)
	if paar.has(z):
		# Pilotenfabrik: Klammer zur Batterie hin
		var r: Vector2i = paar[z] - z
		var mitte := (Vector2(z) + Vector2(0.5, 0.5)) * Werte.ZELLE
		draw_rect(Rect2(mitte + Vector2(r) * Werte.ZELLE * 0.5 - Vector2(8, 8), Vector2(16, 16)), TECH_LICHT * a)
	if fortschritt.has(z):
		_r(z, 6, 58, 52, 4, TECH_DUNKEL)
		_r(z, 6, 58, 52.0 * clampf(fortschritt[z], 0.0, 1.0), 4, TECH_LICHT)


## Zone des Gegners: abgedunkelter Streifen links mit Grenzlinie. Das HQ selbst zeichnet sich als Zonenbau.
func _zeichne_start() -> void:
	var breite := float(Werte.ZONE_SPALTEN * Werte.ZELLE)
	var hoehe := float(Werte.ZEILEN * Werte.ZELLE)
	draw_rect(Rect2(0, 0, breite, hoehe), MYR_SCHLEIER if Werte.grafik_neu else Color(0.25, 0.05, 0.2, 0.35))
	if schild:
		# Schutzschild: durchgehende, pulsierende Wand
		var puls := 0.5 + 0.5 * sin(_zeit * 2.0)
		var sf := Color(1.0, 0.55, 0.2) if Werte.grafik_neu else Color(1.0, 0.35, 0.82)
		draw_rect(Rect2(0, 0, breite, hoehe), Color(sf, 0.05 + 0.05 * puls))
		draw_rect(Rect2(breite - 6, 0, 6, hoehe), Color(sf, 0.55 + 0.35 * puls))
		return
	var y := 0.0
	while y < hoehe:
		draw_rect(Rect2(breite - 4, y, 4, 16), Color(feind_farbe(), 0.7))
		y += 32.0


## Steinplatte mit Fahne: blau = deiner, pink = vom Gegner eingenommen (dort startet die nächste Welle).
func _zeichne_checkpoint(i: int) -> void:
	var z := checkpoints[i]
	var farbe := feind_farbe() if cp_feind[i] else TECH_LICHT
	if not cp_aktiv:
		# noch nicht im Spiel: nur der freigehaltene Platz
		draw_rect(Rect2(Vector2(z) * Werte.ZELLE + Vector2(10, 10), Vector2(44, 44)), Color(STEIN_HELL, 0.45), false, 4.0)
		_cp_nummer(i, farbe)
		return
	if Werte.grafik_neu:
		# Neue Grafik: schlichte Fahne, cyan = deiner, pink = vom Gegner (in HD-2D als Sprite3D)
		if not Werte.grafik_hd:
			var fuss := (Vector2(z) + Vector2(0.5, 0.5)) * Werte.ZELLE + Vector2(0, 22)
			draw_texture_rect(neu_bild("gebaeude/checkpoint_feind.png" if cp_feind[i] else "gebaeude/checkpoint.png"), Rect2(fuss - Vector2(25, 44) * 2.0, Vector2(96, 96)), false)
	else:
		_r(z, 8, 8, 48, 48, STEIN_DUNKEL)
		_r(z, 12, 12, 40, 40, STEIN)
		_r(z, 20, 20, 24, 24, STEIN_HELL)
		_r(z, 30, 4, 4, 36, TECH_DUNKEL)          # Mast
		_r(z, 34, 4, 18, 12, farbe)               # Fahne
	if not cp_feind[i] and cp_einnahme[i] > 0.0:
		_r(z, 8, 54, 48, 6, Color(0, 0, 0, 0.7))
		_r(z, 10, 56, 44.0 * clampf(cp_einnahme[i] / Werte.EINNAHME_SEK, 0.0, 1.0), 2, feind_farbe())
	if cp_feind[i]:
		if i == start_index():
			var puls := 0.5 + 0.5 * sin(_zeit * 4.0)
			draw_rect(Rect2(Vector2(z) * Werte.ZELLE + Vector2(2, 2), Vector2(60, 60)), Color(farbe, 0.4 + 0.5 * puls), false, 4.0)
		if cp_fortschritt[i] > 0.0:
			_r(z, 8, 54, 48, 6, Color(0, 0, 0, 0.7))
			_r(z, 10, 56, 44.0 * clampf(cp_fortschritt[i] / Werte.RUECKEROBERUNG_SEK, 0.0, 1.0), 2, TECH_LICHT)
	_cp_nummer(i, farbe)


## Nummer des Checkpoints (1 = der erste auf dem Weg der Gegner) als Plakette oben links.
func _cp_nummer(i: int, farbe: Color) -> void:
	var m := Vector2(checkpoints[i]) * Werte.ZELLE + Vector2(13, 14)
	draw_circle(m, 10.0, Color(0.05, 0.05, 0.08, 0.9))
	draw_arc(m, 10.0, 0.0, TAU, 20, farbe, 2.0)
	draw_string(ThemeDB.fallback_font, m + Vector2(-10, 5), str(i + 1), HORIZONTAL_ALIGNMENT_CENTER, 20, 14, Color.WHITE)


func _zeichne_basis() -> void:
	var z := basis
	if Werte.grafik_neu:
		# Neue Grafik: Technoclan-Hauptquartier (in HD-2D als Sprite3D, siehe hd_ansicht.gd)
		if not Werte.grafik_hd:
			var fuss := (Vector2(z) + Vector2(0.5, 0.5)) * Werte.ZELLE + Vector2(0, 26)
			draw_texture_rect(neu_bild("gebaeude/basis_gross.png"), Rect2(fuss - Vector2(57, 110), Vector2(128, 128)), false)
		return
	_r(z, 2, 6, 60, 56, TECH_DUNKEL)
	_r(z, 6, 10, 52, 48, TECH)
	_r(z, 14, 18, 36, 32, TECH_HELL)
	_r(z, 24, 26, 16, 16, TECH_LICHT)
	_r(z, 2, 2, 8, 12, TECH_DUNKEL)
	_r(z, 54, 2, 8, 12, TECH_DUNKEL)


func _zeichne_leben(z: Vector2i) -> void:
	var maximal := max_leben(feld[z])
	var anteil: float = leben[z] / maximal
	if anteil >= 0.999:
		return
	_r(z, 8, 2, 48, 6, Color(0, 0, 0, 0.7))
	_r(z, 10, 4, 44.0 * clampf(anteil, 0.0, 1.0), 2, WARNUNG)


## Gepunktete Linie durch die Feldmitten; `laufend` lässt die Punkte Richtung Basis wandern.
func _zeichne_weg(weg: Array[Vector2i], farbe: Color, laufend: bool) -> void:
	if weg.size() < 2:
		return
	if Werte.grafik_neu:
		_zeichne_weg_neu(weg, farbe, laufend)
		return
	var abstand := 16.0
	var versatz := fmod(_zeit * 24.0, abstand) if laufend else 0.0
	var rest := versatz
	for i in weg.size() - 1:
		var a := (Vector2(weg[i]) + Vector2(0.5, 0.5)) * Werte.ZELLE
		var b := (Vector2(weg[i + 1]) + Vector2(0.5, 0.5)) * Werte.ZELLE
		var laenge := a.distance_to(b)
		var richtung := (b - a) / laenge
		var d := rest
		while d < laenge:
			var p := (a + richtung * d).round()
			draw_rect(Rect2(p - Vector2(3, 3), Vector2(6, 6)), farbe)
			d += abstand
		rest = d - laenge


## Rote Rahmen um alles, was der Gegner auf diesem Weg einreißen würde.
func _markiere_durchbrueche(weg: Array[Vector2i], zusatz: Vector2i) -> void:
	var zg := float(Werte.ZELLE)
	for z in weg:
		if feld.has(z) or z == zusatz:
			var o := Vector2(z) * zg
			draw_rect(Rect2(o + Vector2(2, 2), Vector2(zg - 4, zg - 4)), WARNUNG, false, 4.0)
			draw_line(o + Vector2(18, 18), o + Vector2(46, 46), WARNUNG, 4.0)
			draw_line(o + Vector2(46, 18), o + Vector2(18, 46), WARNUNG, 4.0)
