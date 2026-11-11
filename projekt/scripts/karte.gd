class_name Karte
extends Node2D
## Das Raster: was wo steht, wie es aussieht und wer welchen Weg nimmt.

signal zerstoert(zelle: Vector2i, typ: int)

## FREI/WALL/FABRIK stehen im Raster; STELLUNG und TURM sind Ausbauten eines Erdwalls.
enum { FREI, WALL, FABRIK, STELLUNG, TURM, BATTERIE }

const NACHBARN: Array[Vector2i] = [Vector2i.LEFT, Vector2i.UP, Vector2i.DOWN, Vector2i.RIGHT]
const KEINE := Vector2i(-1, -1)

var feld: Dictionary = {}          # Zelle -> WALL / FABRIK
var leben: Dictionary = {}         # Zelle -> Lebenspunkte des Gebäudes
var ausbau: Dictionary = {}        # Wall-Zelle -> STELLUNG / TURM
var posten: Dictionary = {}        # Stellungs-Zelle -> Einheit, die darauf steht
var besatzung: Dictionary = {}     # Batterie-Zelle -> Einheiten, die dorthin gehören (unterwegs oder schon drin)
var fabrik_typ: Dictionary = {}    # Fabrik-Zelle -> Einheitentyp, den sie baut
var fortschritt: Dictionary = {}   # Fabrik-Zelle -> 0..1 (Produktionsbalken)

var checkpoints: Array[Vector2i] = []
var cp_aktiv := false              # Checkpoints sind erst ab Werte.CHECKPOINTS_AB_WELLE im Spiel
var cp_feind: Array[bool] = []     # je Checkpoint: vom Gegner eingenommen?
var cp_fortschritt: Array[float] = []   # je Checkpoint: Sekunden der laufenden Rückeroberung
var cp_einnahme: Array[float] = []      # je Checkpoint: Sekunden der laufenden Einnahme durch den Gegner
var cp_tempo: Array[float] = []    # je Checkpoint: hält ihn gerade ein Gegner? (0 = nein, 1 = normal, 2 = Fahnenträger)

var pfad: Array[Vector2i] = []     # Weg der nächsten Welle: Start -> Checkpoints -> Basis (ab Mitte der Zone)
var neben_pfade: Array = []        # dasselbe vom oberen und unteren Rand der Zone
var schild := true                 # Schutzschild über der Zone des Gegners (fällt in der letzten Runde)
var zeige_schwachstelle := false   # Bauphase: den Erdwall markieren, den ein Sprenger anpeilen würde
var _ersparnis: Dictionary = {}    # Wall-Zelle -> so viel kürzer wird der Gegnerweg ohne diesen Wall
var _ersparnis_gueltig := false
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
	_astar_einheiten = _neues_astar()
	for typ: String in Werte.GEGNER:
		_astar_gegner[typ] = _neues_astar()
	for z in Werte.CHECKPOINTS:
		checkpoints.append(z)
		cp_feind.append(false)
		cp_fortschritt.append(0.0)
		cp_einnahme.append(0.0)
		cp_tempo.append(0.0)
	aktualisiere_pfad()


func _process(delta: float) -> void:
	_zeit += delta
	queue_redraw()


# ---------------------------------------------------------------- Raster

func in_karte(z: Vector2i) -> bool:
	return z.x >= 0 and z.y >= 0 and z.x < Werte.SPALTEN and z.y < Werte.ZEILEN


func inhalt(z: Vector2i) -> int:
	return feld.get(z, FREI)


func ist_frei(z: Vector2i) -> bool:
	return in_karte(z) and not feld.has(z)


func ist_bebaubar(z: Vector2i) -> bool:
	return ist_frei(z) and z.x >= Werte.ZONE_SPALTEN and z != Werte.BASIS_ZELLE and not checkpoints.has(z)


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
	_gewichte_fuer(z)
	aktualisiere_pfad()


func entferne(z: Vector2i) -> void:
	feld.erase(z)
	leben.erase(z)
	ausbau.erase(z)
	besatzung.erase(z)
	fabrik_typ.erase(z)
	posten.erase(z)
	fortschritt.erase(z)
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
	entferne(z)
	zerstoert.emit(z, typ)
	return true


func repariere_alles() -> void:
	for z: Vector2i in feld:
		leben[z] = max_leben(feld[z])


# --------------------------------------------------------- Checkpoints

## Ziel Nummer `i` auf dem Gegnerweg: erst die Checkpoints, danach die Basis.
func ziel_zelle(i: int) -> Vector2i:
	return checkpoints[i] if i < checkpoints.size() else Werte.BASIS_ZELLE


## Der am weitesten vorn liegende eingenommene Checkpoint (-1 = keiner, Start ist die Grube).
func start_index() -> int:
	for i in range(checkpoints.size() - 1, -1, -1):
		if cp_feind[i]:
			return i
	return -1


## Erstes Routenziel der nächsten Welle (Nummer des Checkpoints; ohne Checkpoints direkt die Basis).
func erstes_ziel() -> int:
	return start_index() + 1 if cp_aktiv else checkpoints.size()


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
	if typ == TURM and wall_nachbarn(z) < Werte.TURM_NACHBARN:
		return "Ein Turm braucht %d angrenzende Erdwälle (T-Stück oder Kreuzung)." % Werte.TURM_NACHBARN
	return ""


func baue_aus(z: Vector2i, typ: int) -> void:
	ausbau[z] = typ


## Freie Sicht zwischen zwei Punkten am Boden? Wälle und Gebäude versperren sie.
## Geprüft wird ein Streifen von der Breite eines Geschosses, nicht nur eine dünne Linie: An Wallkanten vorbei
## und durch die Lücke zwischen zwei Wällen, die sich nur an den Ecken berühren, kann nicht geschossen werden.
func sicht_frei(von: Vector2, nach: Vector2) -> bool:
	var quer := (nach - von).orthogonal().normalized() * 6.0
	return _strahl_frei(von, nach) and _strahl_frei(von + quer, nach + quer) and _strahl_frei(von - quer, nach - quer)


func _strahl_frei(von: Vector2, nach: Vector2) -> bool:
	var start := zelle_bei(von)
	var vorher := start
	var schritte := int(von.distance_to(nach) / 2.0) + 1
	for i in range(1, schritte + 1):
		var z := zelle_bei(von.lerp(nach, float(i) / schritte))
		if z == vorher:
			continue
		if z != start and feld.has(z):
			return false
		# schräg von Feld zu Feld = genau über eine Ecke: gesperrt, sobald dort ein Wall anliegt
		if z.x != vorher.x and z.y != vorher.y:
			if feld.has(Vector2i(z.x, vorher.y)) or feld.has(Vector2i(vorher.x, z.y)):
				return false
		vorher = z
	return true


# ------------------------------------------------------------ Wegsuche

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
	_astar_einheiten.set_point_solid(z, was != FREI)
	for typ: String in _astar_gegner:
		(_astar_gegner[typ] as AStarGrid2D).set_point_weight_scale(z, _gewicht(typ, was))


## Weg eines Gegners: der billigste – Wälle sind teuer, aber nicht verboten.
func gegner_weg(gegner_typ: String, von: Vector2i, nach: Vector2i = Werte.BASIS_ZELLE) -> Array[Vector2i]:
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
	_ersparnis_gueltig = false
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
	if ist_frei(von):
		return _astar_einheiten.get_id_path(von, nach)
	# Start liegt in einem Gebäude (frisch aus der Fabrik): über einen freien Nachbarn.
	var bester: Array[Vector2i] = []
	for n in NACHBARN:
		var s := von + n
		if not ist_frei(s):
			continue
		var weg := _astar_einheiten.get_id_path(s, nach)
		if not weg.is_empty() and (bester.is_empty() or weg.size() < bester.size()):
			bester = weg
	return bester


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
	for w: Vector2i in ausbau:
		if ausbau[w] != STELLUNG:
			continue
		var weg := _weg_auf_wall(von, w)
		if weg.is_empty() or weg.size() >= beste_laenge:
			continue
		if posten.has(w):
			var inhaber: Einheit = posten[w]
			if inhaber == sucher or not inhaber.unterwegs_weiter_als(weg.size()):
				continue
		beste_laenge = weg.size()
		bester = {"wall": w, "weg": weg}
	# Batterien zählen wie Stellungen mit mehreren Plätzen
	for b: Vector2i in feld:
		if feld[b] != BATTERIE:
			continue
		var mannschaft: Array = besatzung.get(b, [])
		if mannschaft.size() >= int(Werte.BATTERIE["plaetze"]) or mannschaft.has(sucher):
			continue
		var weg := _weg_auf_wall(von, b)
		if not weg.is_empty() and weg.size() < beste_laenge:
			beste_laenge = weg.size()
			bester = {"wall": b, "weg": weg}
	return bester


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
	_ersparnis = {}
	var a := _astar_gegner["hund"] as AStarGrid2D
	var basis := _weg_kosten("hund", _route("hund"))
	for w: Vector2i in feld:
		if feld[w] != WALL or ausbau.get(w, FREI) == TURM:
			continue
		a.set_point_weight_scale(w, 1.0)
		var gewinn := basis - _weg_kosten("hund", _route("hund"))
		a.set_point_weight_scale(w, _gewicht("hund", WALL))
		if gewinn > 0.5:
			_ersparnis[w] = gewinn
	return _ersparnis


## Der Erdwall mit der größten Ersparnis (KEINE, wenn kein Wall eine Abkürzung öffnet).
func schwachstelle() -> Vector2i:
	var beste := KEINE
	var bester_gewinn := 0.0
	var alle := ersparnisse()
	for w: Vector2i in alle:
		if alle[w] > bester_gewinn:
			bester_gewinn = alle[w]
			beste = w
	return beste


## Ziel eines Sprengers ab `von`: der erreichbare Erdwall mit der größten Ersparnis.
## Ergebnis: {"wall": Zelle, "weg": Felder bis zum Nachbarfeld des Walls} oder {}.
func sprengziel(von: Vector2i) -> Dictionary:
	var alle := ersparnisse()
	var waelle: Array = alle.keys()
	waelle.sort_custom(func(x, y): return alle[x] > alle[y])
	for w: Vector2i in waelle:
		var weg := _weg_an_wall(von, w)
		if not weg.is_empty():
			return {"wall": w, "weg": weg}
	return {}


## Kürzester Fußweg von `von` auf ein freies Nachbarfeld des Walls `w` (leer = unerreichbar).
func _weg_an_wall(von: Vector2i, w: Vector2i) -> Array[Vector2i]:
	var bester: Array[Vector2i] = []
	for n in NACHBARN:
		var zugang := w + n
		if not ist_frei(zugang):
			continue
		var weg: Array[Vector2i] = [von]
		if zugang != von:
			weg = einheiten_weg(von, zugang)
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


## Andockstelle eines Belagerungsturms ab `von`: das erreichbare Wallstück mit den meisten Stellungen.
## Ergebnis: {"wall": Zelle, "weg": Felder bis zum Nachbarfeld} oder {} (keine Stellung erreichbar).
func andockziel(von: Vector2i) -> Dictionary:
	var gesehen: Dictionary = {}
	var stuecke: Array = []      # [Anzahl Stellungen, Zellen]
	for w: Vector2i in ausbau:
		if ausbau[w] != STELLUNG or gesehen.has(w):
			continue
		var stueck := wallstueck(w)
		var stellungen := 0
		for z in stueck:
			gesehen[z] = true
			if ausbau.get(z, FREI) == STELLUNG:
				stellungen += 1
		stuecke.append([stellungen, stueck])
	stuecke.sort_custom(func(x, y): return x[0] > y[0])
	for eintrag: Array in stuecke:
		var bestes := {}
		for w: Vector2i in eintrag[1]:
			var weg := _weg_an_wall(von, w)
			if not weg.is_empty() and (bestes.is_empty() or weg.size() < (bestes["weg"] as Array).size()):
				bestes = {"wall": w, "weg": weg}
		if not bestes.is_empty():
			return bestes
	return {}


## Weg einer Turmtruppe über zusammenhängende Wälle zur nächsten besetzten Stellung (leer = keine erreichbar).
func wall_weg_zur_stellung(von: Vector2i) -> Array[Vector2i]:
	var vorgaenger: Dictionary = {von: von}
	var offen: Array[Vector2i] = [von]
	var i := 0
	while i < offen.size():
		var z := offen[i]
		i += 1
		if z != von and posten.has(z):
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
	var ziel := ziel_zelle(erstes_ziel())
	for y in Werte.ZEILEN:
		for x in range(Werte.ZONE_SPALTEN, Werte.SPALTEN):
			var z := Vector2i(x, y)
			if not ist_frei(z) or Vector2(z - von).length() > weite:
				continue
			var kosten := _weg_kosten("hund", gegner_weg("hund", z, ziel))
			if kosten < beste_kosten:
				beste_kosten = kosten
				bestes = z
	return bestes


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
	for y in Werte.ZEILEN:
		for x in Werte.SPALTEN:
			var z := Vector2i(x, y)
			_r(z, 0, 0, zg, zg, GRAS_A if (x + y) % 2 == 0 else GRAS_B)
			var h := hash(z)
			_r(z, 8 + (h % 5) * 8, 8 + ((h >> 4) % 5) * 8, 4, 4, GRAS_HELL)
			_r(z, 12 + ((h >> 8) % 5) * 8, 20 + ((h >> 12) % 4) * 8, 4, 4, GRAS_DUNKEL)

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
			if ausbau.has(z):
				_zeichne_ausbau(z, ausbau[z], 1.0)
		elif feld[z] == BATTERIE:
			_zeichne_batterie(z, 1.0)
		else:
			_zeichne_fabrik(z, 1.0)
		_zeichne_leben(z)

	_markiere_durchbrueche(pfad if not zeige_neu else vorschau_pfad, KEINE if not zeige_neu else vorschau_zelle)

	# Schwachstelle: der Erdwall, den ein Sprenger anpeilen würde
	if zeige_schwachstelle and zeige_pfad_kraeftig:
		var schwach := schwachstelle()
		if schwach != KEINE:
			var puls := 0.5 + 0.5 * sin(_zeit * 5.0)
			var o := Vector2(schwach) * zg
			draw_rect(Rect2(o + Vector2(2, 2), Vector2(zg - 4, zg - 4)), Color(1.0, 0.6, 0.1, 0.5 + 0.5 * puls), false, 4.0)
			draw_rect(Rect2(o + Vector2(28, 14), Vector2(8, 22)), Color("ff9a1f"))
			draw_rect(Rect2(o + Vector2(28, 40), Vector2(8, 8)), Color("ff9a1f"))

	# Reichweite des angeklickten Turms bzw. der angeklickten Batterie
	if auswahl != KEINE:
		var weite := 0.0
		if ausbau.get(auswahl, FREI) == TURM:
			weite = Werte.TURM["reichweite"]
		elif inhalt(auswahl) == BATTERIE:
			weite = Werte.BATTERIE["reichweite"]
		if weite > 0.0:
			var m := (Vector2(auswahl) + Vector2(0.5, 0.5)) * zg
			draw_circle(m, weite * zg, Color(0.5, 0.88, 1.0, 0.08))
			draw_arc(m, weite * zg, 0.0, TAU, 96, Color(0.5, 0.88, 1.0, 0.8), 2.0)

	# Bauvorschau unter dem Mauszeiger
	if vorschau_typ == TURM:
		# mögliche Turmplätze hervorheben
		for z: Vector2i in feld:
			if ausbau_hindernis(z, TURM) == "":
				_r(z, 26, 16, 12, 12, Color(TECH_LICHT, 0.5 + 0.3 * sin(_zeit * 5.0)))
	if vorschau_typ != FREI and in_karte(vorschau_zelle):
		var rahmen := Rect2(Vector2(vorschau_zelle) * zg + Vector2(2, 2), Vector2(zg - 4, zg - 4))
		if not vorschau_ok:
			draw_rect(rahmen, WARNUNG, false, 4.0)
		elif vorschau_typ == STELLUNG or vorschau_typ == TURM:
			_zeichne_ausbau(vorschau_zelle, vorschau_typ, 0.7)
			var radius: float = Werte.TURM["reichweite"] if vorschau_typ == TURM else 3.0 + Werte.POSTEN_REICHWEITE_BONUS
			draw_arc((Vector2(vorschau_zelle) + Vector2(0.5, 0.5)) * zg, radius * zg, 0.0, TAU, 64, Color(TECH_LICHT, 0.6), 2.0)
		else:
			if vorschau_typ == WALL:
				_zeichne_wall(vorschau_zelle, 0.6)
			elif vorschau_typ == BATTERIE:
				_zeichne_batterie(vorschau_zelle, 0.6)
				draw_arc((Vector2(vorschau_zelle) + Vector2(0.5, 0.5)) * zg, Werte.BATTERIE["reichweite"] * zg, 0.0, TAU, 96, Color(TECH_LICHT, 0.6), 2.0)
			else:
				_zeichne_fabrik(vorschau_zelle, 0.6)
			var bricht := weg_bricht_durch(vorschau_pfad, vorschau_zelle)
			_zeichne_weg(vorschau_pfad, WARNUNG if bricht else WEG_NEU, true)
			_markiere_durchbrueche(vorschau_pfad, vorschau_zelle)


## Stellung = Steinplattform mit Brüstung, Turm = Geschütz des Technoclans.
func _zeichne_ausbau(z: Vector2i, typ: int, alpha: float) -> void:
	var a := Color(1, 1, 1, alpha)
	if typ == STELLUNG:
		_r(z, 6, 4, 52, 38, STEIN_DUNKEL * a)
		_r(z, 8, 6, 48, 34, STEIN * a)
		_r(z, 14, 12, 36, 22, STEIN_HELL * a)
		_r(z, 8, 6, 12, 6, STEIN_DUNKEL * a)
		_r(z, 26, 6, 12, 6, STEIN_DUNKEL * a)
		_r(z, 44, 6, 12, 6, STEIN_DUNKEL * a)
	else:
		_r(z, 12, 2, 40, 42, TECH_DUNKEL * a)
		_r(z, 14, 4, 36, 38, TECH * a)
		_r(z, 18, 8, 28, 20, TECH_HELL * a)
		_r(z, 26, 12, 12, 12, TECH_LICHT * a)
		_r(z, 2, 14, 12, 8, TECH_DUNKEL * a)    # Rohre links/rechts
		_r(z, 50, 14, 12, 8, TECH_DUNKEL * a)


func _zeichne_wall(z: Vector2i, alpha: float) -> void:
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


func _zeichne_fabrik(z: Vector2i, alpha: float) -> void:
	var a := Color(1, 1, 1, alpha)
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
	if fortschritt.has(z):
		_r(z, 6, 58, 52, 4, TECH_DUNKEL)
		_r(z, 6, 58, 52.0 * clampf(fortschritt[z], 0.0, 1.0), 4, TECH_LICHT)


## Zone des Gegners: abgedunkelter Streifen links mit Grenzlinie. Das HQ selbst zeichnet sich als Zonenbau.
func _zeichne_start() -> void:
	var breite := float(Werte.ZONE_SPALTEN * Werte.ZELLE)
	var hoehe := float(Werte.ZEILEN * Werte.ZELLE)
	draw_rect(Rect2(0, 0, breite, hoehe), Color(0.25, 0.05, 0.2, 0.35))
	if schild:
		# Schutzschild: durchgehende, pulsierende Wand
		var puls := 0.5 + 0.5 * sin(_zeit * 2.0)
		draw_rect(Rect2(0, 0, breite, hoehe), Color(1.0, 0.35, 0.82, 0.05 + 0.05 * puls))
		draw_rect(Rect2(breite - 6, 0, 6, hoehe), Color(1.0, 0.35, 0.82, 0.55 + 0.35 * puls))
		return
	var y := 0.0
	while y < hoehe:
		draw_rect(Rect2(breite - 4, y, 4, 16), Color("ff5ad0", 0.7))
		y += 32.0


## Steinplatte mit Fahne: blau = deiner, pink = vom Gegner eingenommen (dort startet die nächste Welle).
func _zeichne_checkpoint(i: int) -> void:
	var z := checkpoints[i]
	var farbe := Color("ff5ad0") if cp_feind[i] else TECH_LICHT
	if not cp_aktiv:
		# noch nicht im Spiel: nur der freigehaltene Platz
		draw_rect(Rect2(Vector2(z) * Werte.ZELLE + Vector2(10, 10), Vector2(44, 44)), Color(STEIN_HELL, 0.45), false, 4.0)
		return
	_r(z, 8, 8, 48, 48, STEIN_DUNKEL)
	_r(z, 12, 12, 40, 40, STEIN)
	_r(z, 20, 20, 24, 24, STEIN_HELL)
	_r(z, 30, 4, 4, 36, TECH_DUNKEL)          # Mast
	_r(z, 34, 4, 18, 12, farbe)               # Fahne
	if not cp_feind[i] and cp_einnahme[i] > 0.0:
		_r(z, 8, 54, 48, 6, Color(0, 0, 0, 0.7))
		_r(z, 10, 56, 44.0 * clampf(cp_einnahme[i] / Werte.EINNAHME_SEK, 0.0, 1.0), 2, Color("ff5ad0"))
	if cp_feind[i]:
		if i == start_index():
			var puls := 0.5 + 0.5 * sin(_zeit * 4.0)
			draw_rect(Rect2(Vector2(z) * Werte.ZELLE + Vector2(2, 2), Vector2(60, 60)), Color(farbe, 0.4 + 0.5 * puls), false, 4.0)
		if cp_fortschritt[i] > 0.0:
			_r(z, 8, 54, 48, 6, Color(0, 0, 0, 0.7))
			_r(z, 10, 56, 44.0 * clampf(cp_fortschritt[i] / Werte.RUECKEROBERUNG_SEK, 0.0, 1.0), 2, TECH_LICHT)


func _zeichne_basis() -> void:
	var z := Werte.BASIS_ZELLE
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
