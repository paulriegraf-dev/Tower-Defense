class_name Bauweise
extends RefCounted
## Schritt 9b: eine Bauweise = Wallform (labor/bauweisen/wallformen.json) + Kaufplan (labor/bauweisen/kaufplaene.json),
## gespielt über die Bot-Schnittstelle. Die Karte ist zufällig („überall“): Wallformen werden relativ zu Gegnerweg,
## Checkpoints und Basis berechnet. Was auf einer Karte nicht baubar ist, wird gezählt (nicht_baubar), nicht abgebrochen.
##
## Ein Kaufplan ist eine Regelliste. Je Bauphase wird sie von oben nach unten durchlaufen; die erste Regel, die
## greift und etwas kauft, startet den Durchlauf neu – bis keine Regel mehr etwas kauft.
## Regel-Felder: "tu" (Aktion), "ab"/"bis" (Runden), "max" (Anzahl), "reserve" (so viel Geld bleibt übrig).
## Aktionen: fabrik, waelle, stellung, turm (arten), stufe (art, zu = Zielstufe), batterie, form (shape, arten), pliplop,
## truppenturm, mg_stufe, brakk.
##
## Abwandlung (0–3) und Stufe-3-Wahl (A/B) würfelt der Labor-Lauf je Partie aus (Zuschnitt B) und speichert sie mit.

const PFAD := "res://labor/bauweisen/"
const EINHEITEN: Array[String] = ["technogunner", "scharfschuetze", "plasmawerfer"]
const N4: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
## Formturm-Bausteine (Erdwälle relativ zur Mitte; Turm auf (0,0)), Ausrichtung nach rechts/unten
const FORMEN := {
	"t": [Vector2i(0, 0), Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, 1)],
	"kreuz": [Vector2i(0, 0), Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(0, -1)],
	"lange_ecke": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(0, 1), Vector2i(0, 2)],
	"klammer": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(1, 1), Vector2i(-1, 1)],
	"treppe": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(-1, 0), Vector2i(-1, -1)],
}

var wallform: Dictionary
var kaufplan: Dictionary
var variante := 0
var wahl := 0          # 0 = erste Stufe-3-Fähigkeit (A), 1 = zweite (B)
var anfuehrer := "brakk"
var mit_figur := false

# Zustand der Partie
var _plan_waelle: Array = []      # [{"z", "aus": ""|"stellung"|"turm"|"generator"}] in Bau-Reihenfolge
var _geplant := false
var _naechste_einheit := 0
var _pliplop_zahl := 0
var _waelle_diese_phase := 0   # je_runde gilt für die ganze Bauphase
var zaehler := {"nicht_baubar": 0, "plan_felder": 0, "gekauft": 0}
var _rng := RandomNumberGenerator.new()


static func lade_json(datei: String) -> Variant:
	return JSON.parse_string(FileAccess.get_file_as_string(PFAD + datei))


func _init(p_wallform: Dictionary, p_kaufplan: Dictionary, p_variante: int, p_wahl: int, p_anfuehrer: String, p_mit_figur: bool, samen: int) -> void:
	wallform = p_wallform
	kaufplan = p_kaufplan
	variante = p_variante
	wahl = p_wahl
	anfuehrer = p_anfuehrer
	mit_figur = p_mit_figur
	_rng.seed = hash(["bauweise", samen])


# ------------------------------------------------------------------ Einkauf einer Bauphase

func kaufe(bot: BotApi) -> void:
	var s: Node = bot.spiel
	if not _geplant and s.welle >= Werte.WAELLE_AB_WELLE:
		_plane_waelle(bot)
		_geplant = true
	if str(kaufplan.get("art", "")) == "zufall":
		_zufall(bot)
		return
	var regeln: Array = (kaufplan.get("regeln", []) as Array).duplicate()
	for r in (kaufplan.get("anfuehrer", {}) as Dictionary).get(anfuehrer, []):
		regeln.append(r)
	# Auffang: was die Regeln übrig lassen, geht in Ausbau und Breite (sonst liegt Geld ungenutzt herum)
	if bool(kaufplan.get("rest", true)):
		for r: Dictionary in [{"tu": "stufe", "art": "fabrik", "zu": 3, "reserve": 150}, {"tu": "fabrik", "max": 14, "reserve": 150}, {"tu": "stellung", "max": 30, "reserve": 150}]:
			regeln.append(r)
	if anfuehrer == "brakk" and mit_figur:
		regeln.push_front({"tu": "brakk", "ab": int(kaufplan.get("brakk_ab", 6))})
	_waelle_diese_phase = 0
	var sparen_bis := int(kaufplan.get("sparen_bis", 0))
	_extra = int((kaufplan.get("anfuehrer_reserve", {}) as Dictionary).get(anfuehrer, 0))
	if anfuehrer == "brakk" and mit_figur and s.kommandant == null and s.welle >= int(kaufplan.get("brakk_ab", 6)):
		_extra += Werte.KOSTEN_KOMMANDANT
	for runde_durchlauf in 60:
		var gekauft := false
		for r: Dictionary in regeln:
			if s.welle < int(r.get("ab", 1)) or s.welle > int(r.get("bis", 99)):
				continue
			if s.welle < sparen_bis and not bool(r.get("immer", false)):
				continue
			var _ok := _regel(bot, r)
			if OS.get_environment("TD_BW_DEBUG") != "" and s.welle >= int(OS.get_environment("TD_BW_DEBUG")):
				print("R%d %s -> %s (Geld %d)" % [s.welle, JSON.stringify(r), _ok, s.budget])
			if _ok:
				zaehler["gekauft"] += 1
				gekauft = true
				break
		if not gekauft:
			break


## Rücklage, die alle Regeln außer den ersten Fabriken stehen lassen: für Brakk (wenn er gekauft werden soll) und
## für Pauls Zinsen (anfuehrer_reserve im Kaufplan).
var _extra := 0

func _frei_geld(s: Node, r: Dictionary) -> int:
	var extra := _extra
	if str(r["tu"]) == "brakk" or (str(r["tu"]) == "fabrik" and _normale_fabriken(s) < 2):
		extra = 0
	return int(s.budget) - int(r.get("reserve", 0)) - extra


func _regel(bot: BotApi, r: Dictionary) -> bool:
	var s: Node = bot.spiel
	var k: Karte = s.karte
	match str(r["tu"]):
		"fabrik":
			if _normale_fabriken(s) >= int(r.get("max", 99)) or _frei_geld(s, r) < s.kosten(Karte.FABRIK):
				return false
			var z := _fabrik_feld(bot)
			if z == Karte.KEINE or not bot.baue(z, "fabrik")["ok"]:
				return false
			var gewichte: Array = kaufplan.get("einheiten", [1, 1, 1])
			var e := _gewichtet(gewichte)
			if EINHEITEN[e] != "technogunner":
				bot.fabrik_einheit(z, EINHEITEN[e])
			return true
		"waelle":
			# Der ganze Plan bleibt stehen: gesprengte Wälle werden in späteren Runden wieder aufgebaut.
			# Felder, die einmal nicht baubar waren (Weg zu, Gelände), werden nicht wieder versucht.
			var gebaut := 0
			for p: Dictionary in _plan_waelle:
				if _waelle_diese_phase >= int(r.get("je_runde", 99)):
					break
				var z: Vector2i = p["z"]
				if bool(p.get("nie", false)):
					continue
				if str(p["aus"]) == "generator":
					if not p.has("gemerkt"):
						p["gemerkt"] = true
						_merke_ausbau(p)   # Hof-Feld: bleibt frei für den Generator
					continue
				if k.inhalt(z) != Karte.FREI:
					if k.inhalt(z) == Karte.WALL and str(p["aus"]) != "" and not p.has("gemerkt"):
						p["gemerkt"] = true
						_merke_ausbau(p)
					continue
				var preis: int = s.kosten_bei(z, Karte.WALL)
				if _frei_geld(s, r) - preis < 0:
					break
				if bot.baue(z, "wall")["ok"]:
					gebaut += 1
					_waelle_diese_phase += 1
					if str(p["aus"]) != "" and not p.has("gemerkt"):
						p["gemerkt"] = true
						_merke_ausbau(p)
				elif not p.has("gebaut_einmal"):
					p["nie"] = true
					zaehler["nicht_baubar"] += 1
				if k.inhalt(z) == Karte.WALL:
					p["gebaut_einmal"] = true
			return gebaut > 0
		"stellung":
			if _zahl_ausbau(k, Karte.STELLUNG) >= int(r.get("max", 99)) or _frei_geld(s, r) < s.kosten(Karte.STELLUNG):
				return false
			var z := _stellung_feld(bot)
			return z != Karte.KEINE and bot.baue(z, "stellung")["ok"]
		"turm":
			if _zahl_ausbau(k, Karte.TURM) >= int(r.get("max", 99)) or _frei_geld(s, r) < Werte.KOSTEN_TURM:
				return false
			var z := _turm_feld(bot, r.get("arten", []))
			return z != Karte.KEINE and bot.baue(z, "turm")["ok"]
		"form":
			# eigener Formturm-Baustein am Weg (z. B. Lange Ecke für Frost): Wälle und Turm in einem Zug
			if _zahl_turmart(k, r.get("arten", [])) >= int(r.get("max", 1)) or _frei_geld(s, r) < Werte.KOSTEN_TURM + 6 * s.kosten(Karte.WALL):
				return false
			return _baue_form(bot, str(r.get("shape", "t")))
		"stufe":
			return _stufe(bot, r)
		"mg_stufe":
			return _stufe(bot, {"art": "mg", "zu": int(r.get("zu", 3)), "reserve": r.get("reserve", 0)})
		"batterie":
			if _batterien(s) >= int(r.get("max", 1)) or _frei_geld(s, r) < s.kosten(Karte.BATTERIE):
				return false
			for z: Vector2i in _felder_nach_wegabstand(bot, 2, 3):
				for richtung: String in ["rechts", "unten", "links", "oben"]:
					if bot.baue(z, "batterie", richtung)["ok"]:
						return true
			return false
		"generator":
			if _zahl_inhalt(k, Karte.GENERATOR) >= 1 or _frei_geld(s, r) < Werte.KOSTEN_GENERATOR:
				return false
			for p: Dictionary in _generator_ziele:
				if bot.baue(p["z"], "turm")["ok"]:
					return true
			return false
		"pliplop":
			if _pliplop_zahl >= int(r.get("max", 2)) or _frei_geld(s, r) < Werte.KOSTEN_PLIPLOP + s.kosten(Karte.WALL):
				return false
			for z: Vector2i in _felder_nach_wegabstand(bot, 2, 2):
				if bot.baue(z, "pliplop")["ok"]:
					_pliplop_zahl += 1
					return true
			return false
		"truppenturm":
			if _zahl_turmart(k, ["truppen"]) >= int(r.get("max", 1)) or _frei_geld(s, r) < Werte.KOSTEN_TURM:
				return false
			for z: Vector2i in _wall_felder_nach_weg(bot):
				if bot.baue(z, "truppen")["ok"]:
					return true
			return false
		"brakk":
			if s.kommandant != null or _frei_geld(s, r) < Werte.KOSTEN_KOMMANDANT:
				return false
			var ziel := _ziel_punkt(k, 0.35)
			for z: Vector2i in _felder_um(ziel, 3):
				if bot.baue(z, "kommandant")["ok"]:
					return true
			return false
	return false


func _stufe(bot: BotApi, r: Dictionary) -> bool:
	var s: Node = bot.spiel
	var k: Karte = s.karte
	var art := str(r.get("art", "fabrik"))
	var bis := int(r.get("zu", 3))   # Zielstufe ("bis" ist die letzte Runde der Regel)
	var reserve := int(r.get("reserve", 0)) + _extra
	if int(s.budget) <= reserve:
		return false
	var kandidaten: Array = []
	match art:
		"fabrik":
			for z: Vector2i in s.fabriken:
				if not k.paar.has(z) and int(s.fabriken[z].get("stufe", 0)) < bis:
					kandidaten.append([int(s.fabriken[z].get("stufe", 0)), z])
		"batterie":
			for z: Vector2i in s.fabriken:
				if k.paar.has(z) and int(s.fabriken[z].get("stufe", 0)) < bis:
					kandidaten.append([int(s.fabriken[z].get("stufe", 0)), z])
		"turm":
			for z: Vector2i in k.turm_art:
				if str(k.turm_art[z]) != "pliplop" and int(k.turm_stufe.get(z, 1)) < bis:
					kandidaten.append([int(k.turm_stufe.get(z, 1)), z])
		"pliplop":
			for z: Vector2i in k.turm_art:
				if str(k.turm_art[z]) == "pliplop" and int(k.turm_stufe.get(z, 1)) < bis:
					kandidaten.append([int(k.turm_stufe.get(z, 1)), z])
		"mg":
			for z: Vector2i in k.ausbau:
				if k.ausbau[z] == Karte.STELLUNG and int(k.mg_stufe.get(z, 0)) < bis:
					kandidaten.append([int(k.mg_stufe.get(z, 0)), z])
	# Wer am weitesten ist, wird zuerst fertig (wenige voll ausgebaute statt viele halbe), sonst der niedrigste zuerst
	var zuerst_hoch := bool(r.get("zuerst_hoch", true))
	kandidaten.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0] if zuerst_hoch else a[0] < b[0])
	for kd: Array in kandidaten:
		var z: Vector2i = kd[1]
		for w: String in _wahlen(bot, z):
			if bot.aufwerten(z, w)["ok"]:
				return true
	return false


## Mögliche Wahlen für die nächste Stufe an z, die gewürfelte (A/B) zuerst.
func _wahlen(bot: BotApi, z: Vector2i) -> Array:
	var liste: Array = []
	for a: Dictionary in bot.ausbau_wahlen():
		if a["a"] == "aufwerten" and Vector2i(a["x"], a["y"]) == z:
			liste.append(str(a["wahl"]))
	if liste.size() > 1:
		var i := mini(wahl, liste.size() - 1)
		var erste: String = liste[i]
		liste.remove_at(i)
		liste.push_front(erste)
	return liste


# ------------------------------------------------------------------ Wallformen

var _generator_ziele: Array = []
var _ausbau_ziele: Array = []   # [{"z", "aus"}] – Wälle, die einen Ausbau bekommen sollen (bevorzugt)


func _merke_ausbau(p: Dictionary) -> void:
	if str(p["aus"]) == "generator":
		_generator_ziele.append(p)
	else:
		_ausbau_ziele.append(p)


func _plane_waelle(bot: BotApi) -> void:
	var k: Karte = bot.spiel.karte
	var plan: Array = []
	var art := str(wallform.get("art", "keine"))
	var spiegel := variante % 2 == 1
	var versatz := 2 if variante >= 2 else 0
	match art:
		"schlange":
			plan = _schlange(k, int(wallform.get("reihen", 4)) + (1 if variante == 3 else 0), versatz, spiegel)
		"riegel":
			plan = _riegel(k, 1 if variante >= 2 else 0, spiegel, int(wallform.get("stellung_alle", 2)))
		"kanal":
			plan = _kanal(k, 0.25 + 0.1 * float(variante), int(wallform.get("laenge", 8)))
		"formturm":
			var formen: Array = wallform.get("formen", ["t", "kreuz", "lange_ecke", "klammer", "treppe"]).duplicate()
			for i in variante:
				formen.push_back(formen.pop_front())   # Abwandlung: andere Form zuerst
			plan = _formturm_nest(k, formen, spiegel)
		"zitadelle":
			plan = _zitadelle(k, [0.3, 0.55, 0.3, 0.8][variante], Vector2i(2, 2) if variante != 2 else Vector2i(3, 2))
		"wachposten":
			plan = _wachposten(k, 3 + (variante % 2), spiegel)
		_:
			plan = []
	_plan_waelle = plan
	zaehler["plan_felder"] = plan.size()


func _route(k: Karte) -> Array[Vector2i]:
	return k.pfad.filter(func(z: Vector2i) -> bool: return z.x >= Werte.ZONE_SPALTEN)


## Punkt auf dem Gegnerweg bei Anteil t (0 = Start, 1 = Basis).
func _ziel_punkt(k: Karte, t: float) -> Vector2i:
	var r := _route(k)
	if r.is_empty():
		return k.basis
	return r[clampi(int(t * (r.size() - 1)), 0, r.size() - 1)]


## Querreihen über die ganze Höhe, abwechselnd von oben und unten gebaut: die letzte Lücke bleibt dort, wo der Weg
## sonst zu wäre – so entsteht von selbst eine Serpentine.
func _schlange(k: Karte, reihen: int, versatz: int, spiegel: bool) -> Array:
	var aus: Array = []
	var cp: Vector2i = k.checkpoints[0] if not k.checkpoints.is_empty() else k.basis
	var x0 := Werte.ZONE_SPALTEN + 2 + versatz
	var x1 := maxi(x0 + 2, cp.x - 1)
	var abstand := maxi(2, (x1 - x0) / maxi(reihen, 1))
	for i in reihen:
		var x := x0 + i * abstand
		var von_oben := (i % 2 == 0) != spiegel
		for j in Werte.ZEILEN:
			var y := j if von_oben else Werte.ZEILEN - 1 - j
			aus.append({"z": Vector2i(x, y), "aus": "stellung" if j % 4 == 2 else ""})
	return aus


## Wallzeile quer vor einem Checkpoint, darauf Stellungen.
func _riegel(k: Karte, cp_index: int, spiegel: bool, stellung_alle: int) -> Array:
	var aus: Array = []
	var i := mini(cp_index, k.checkpoints.size() - 1)
	var cp: Vector2i = k.checkpoints[i] if i >= 0 else k.basis
	var x := cp.x + (2 if not spiegel else -2)
	for d in Werte.ZEILEN:
		var y := cp.y + (d / 2 if d % 2 == 0 else -(d / 2 + 1))
		if y < 0 or y >= Werte.ZEILEN:
			continue
		aus.append({"z": Vector2i(x, y), "aus": "stellung" if d % stellung_alle == 0 else ""})
	return aus


## Wälle beidseits eines Wegabschnitts (Abstand 1), mit Lücken alle 4 Felder für die eigenen Truppen.
func _kanal(k: Karte, ab: float, laenge: int) -> Array:
	var aus: Array = []
	var r := _route(k)
	if r.size() < 4:
		return aus
	var start := int(ab * r.size())
	var weg := {}
	for z in r:
		weg[z] = true
	for i in range(start, mini(start + laenge, r.size() - 1)):
		var z: Vector2i = r[i]
		var dir: Vector2i = r[i + 1] - z
		var quer := Vector2i(dir.y, dir.x)
		for seite in [quer, -quer]:
			var w: Vector2i = z + seite
			if not weg.has(w) and (i - start) % 4 != 3:
				aus.append({"z": w, "aus": "stellung" if (i - start) % 4 == 1 else ""})
	return aus


## Formturm-Bausteine neben dem Weg, je Baustein ein Turm auf die Mitte.
func _formturm_nest(k: Karte, formen: Array, spiegel: bool) -> Array:
	var aus: Array = []
	var r := _route(k)
	var weg := {}
	for z in r:
		weg[z] = true
	var belegt := {}
	var n := 0
	var i := int(r.size() * 0.2)
	while i < r.size() - 2 and n < formen.size():
		var z: Vector2i = r[i]
		var dir: Vector2i = r[mini(i + 1, r.size() - 1)] - z
		var quer := Vector2i(dir.y, dir.x) * (-1 if spiegel else 1)
		var mitte: Vector2i = z + quer * 2
		var form: Array = FORMEN[formen[n]]
		var felder: Array = []
		var ok := true
		for o: Vector2i in form:
			var f := mitte + o
			if weg.has(f) or belegt.has(f) or not k.in_karte(f):
				ok = false
				break
			felder.append(f)
		if ok:
			for f: Vector2i in felder:
				belegt[f] = true
				aus.append({"z": f, "aus": "turm" if f == mitte else ""})
			n += 1
			i += 5
		else:
			i += 1
	return aus


## Wallring um einen kleinen Hof neben dem Weg, Generator innen, Stellungen auf dem Ring.
func _zitadelle(k: Karte, t: float, innen: Vector2i) -> Array:
	var aus: Array = []
	var z := _ziel_punkt(k, t)
	var r := _route(k)
	var i := r.find(z)
	var dir: Vector2i = (r[mini(i + 1, r.size() - 1)] - z) if i >= 0 and r.size() > 1 else Vector2i(1, 0)
	var quer := Vector2i(dir.y, dir.x)
	if quer == Vector2i.ZERO:
		quer = Vector2i(0, 1)
	var ecke: Vector2i = z + quer * 2
	if quer.x < 0 or quer.y < 0:
		ecke -= Vector2i(innen.x + 1, innen.y + 1) * Vector2i(absi(quer.x), absi(quer.y))
	var ring: Array = []
	for y in range(-1, innen.y + 1):
		for x in range(-1, innen.x + 1):
			var f := ecke + Vector2i(x, y)
			var drin := x >= 0 and x < innen.x and y >= 0 and y < innen.y
			if drin:
				if aus.is_empty() or ring.size() > 0:
					pass
			else:
				ring.append(f)
	for j in ring.size():
		aus.append({"z": ring[j], "aus": "stellung" if j % 3 == 0 else ""})
	aus.append({"z": ecke, "aus": "generator"})
	return aus


## Einzelne Wälle im Abstand 2 zum Weg, je mit Stellung.
func _wachposten(k: Karte, abstand: int, spiegel: bool) -> Array:
	var aus: Array = []
	var r := _route(k)
	var weg := {}
	for z in r:
		weg[z] = true
	var i := int(r.size() * 0.1)
	var seite := 1 if not spiegel else -1
	while i < r.size() - 1:
		var z: Vector2i = r[i]
		var dir: Vector2i = r[i + 1] - z
		var w: Vector2i = z + Vector2i(dir.y, dir.x) * 2 * seite
		if not weg.has(w):
			aus.append({"z": w, "aus": "stellung"})
		seite = -seite
		i += abstand
	return aus


# ------------------------------------------------------------------ Feldwahl

func _wegabstand(k: Karte) -> Dictionary:
	var d := {}
	var offen: Array[Vector2i] = []
	for z in _route(k):
		d[z] = 0
		offen.append(z)
	var kopf := 0
	while kopf < offen.size():
		var z := offen[kopf]
		kopf += 1
		for n: Vector2i in N4:
			var w := z + n
			if k.in_karte(w) and not d.has(w):
				d[w] = int(d[z]) + 1
				offen.append(w)
	return d


## Freie Felder im Wegabstand von..bis, geordnet nach Nähe zum vorderen Wegdrittel (dort kämpfen die Truppen zuerst).
func _felder_nach_wegabstand(bot: BotApi, von: int, bis: int) -> Array:
	var k: Karte = bot.spiel.karte
	var d := _wegabstand(k)
	var ziel := _ziel_punkt(k, float(kaufplan.get("schwerpunkt", 0.45)))
	var liste: Array = []
	for z: Vector2i in d:
		if int(d[z]) >= von and int(d[z]) <= bis and k.ist_bebaubar(z):
			liste.append(z)
	liste.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		var da := Vector2(a - ziel).length()
		var db := Vector2(b - ziel).length()
		return da < db or (da == db and (a.x < b.x or (a.x == b.x and a.y < b.y))))
	return liste


func _fabrik_feld(bot: BotApi) -> Vector2i:
	for z: Vector2i in _felder_nach_wegabstand(bot, 1, 3):
		if bot.spiel.bau_hindernis(z, Karte.FABRIK) == "":
			return z
	return Karte.KEINE


func _wall_felder_nach_weg(bot: BotApi) -> Array:
	var k: Karte = bot.spiel.karte
	var d := _wegabstand(k)
	var liste: Array = []
	for z: Vector2i in k.feld:
		if k.feld[z] == Karte.WALL and not k.ausbau.has(z):
			liste.append(z)
	liste.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		var da := int(d.get(a, 99))
		var db := int(d.get(b, 99))
		return da < db or (da == db and (a.x < b.x or (a.x == b.x and a.y < b.y))))
	return liste


func _stellung_feld(bot: BotApi) -> Vector2i:
	var k: Karte = bot.spiel.karte
	for p: Dictionary in _ausbau_ziele:
		if str(p["aus"]) == "stellung" and k.inhalt(p["z"]) == Karte.WALL and not k.ausbau.has(p["z"]) and bot.spiel.bau_hindernis(p["z"], Karte.STELLUNG) == "":
			return p["z"]
	if bool(kaufplan.get("stellung_nur_geplant", false)):
		return Karte.KEINE
	for z: Vector2i in _wall_felder_nach_weg(bot):
		if _reserviert_fuer_turm(z):
			continue
		if bot.spiel.bau_hindernis(z, Karte.STELLUNG) == "":
			return z
	return Karte.KEINE


func _reserviert_fuer_turm(z: Vector2i) -> bool:
	for p: Dictionary in _ausbau_ziele:
		if p["z"] == z and str(p["aus"]) == "turm":
			return true
	return false


func _turm_feld(bot: BotApi, arten: Array) -> Vector2i:
	var k: Karte = bot.spiel.karte
	var kandidaten: Array = []
	for p: Dictionary in _ausbau_ziele:
		if str(p["aus"]) == "turm":
			kandidaten.append(p["z"])
	for z in _wall_felder_nach_weg(bot):
		if not kandidaten.has(z):
			kandidaten.append(z)
	for z: Vector2i in kandidaten:
		if k.inhalt(z) != Karte.WALL or k.ausbau.has(z):
			continue
		var form := k.turm_form(z)
		if form == "" or form == "pliplop" or form == "truppen":
			continue
		if not arten.is_empty() and not arten.has(form):
			continue
		if bot.spiel.bau_hindernis(z, Karte.TURM) == "":
			return z
	return Karte.KEINE


func _baue_form(bot: BotApi, shape: String) -> bool:
	var k: Karte = bot.spiel.karte
	var form: Array = FORMEN.get(shape, FORMEN["t"])
	for mitte: Vector2i in _felder_nach_wegabstand(bot, 2, 3):
		var ok := true
		for o: Vector2i in form:
			if not k.ist_bebaubar(mitte + o) and k.inhalt(mitte + o) != Karte.WALL:
				ok = false
				break
		if not ok:
			continue
		var gebaut: Array = []
		for o: Vector2i in form:
			if k.inhalt(mitte + o) == Karte.WALL or bot.baue(mitte + o, "wall")["ok"]:
				gebaut.append(mitte + o)
		if gebaut.size() == form.size() and bot.baue(mitte, "turm")["ok"]:
			return true
		# nicht geglückt: stehen lassen (die Wälle nutzen später Stellungen), nächster Versuch woanders
		zaehler["nicht_baubar"] += 1
		return false
	return false


func _felder_um(ziel: Vector2i, r: int) -> Array:
	var aus: Array = []
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			aus.append(ziel + Vector2i(dx, dy))
	aus.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return Vector2(a - ziel).length() < Vector2(b - ziel).length())
	return aus


# ------------------------------------------------------------------ Zählen

func _normale_fabriken(s: Node) -> int:
	var n := 0
	for z: Vector2i in s.fabriken:
		if not s.karte.paar.has(z):
			n += 1
	return n


func _batterien(s: Node) -> int:
	var n := 0
	for z: Vector2i in s.fabriken:
		if s.karte.paar.has(z):
			n += 1
	return n


func _zahl_ausbau(k: Karte, typ: int) -> int:
	var n := 0
	for z in k.ausbau:
		if k.ausbau[z] == typ:
			n += 1
	return n


func _zahl_turmart(k: Karte, arten: Array) -> int:
	var n := 0
	for z in k.turm_art:
		if arten.is_empty() or arten.has(k.turm_art[z]):
			n += 1
	return n


func _zahl_inhalt(k: Karte, typ: int) -> int:
	var n := 0
	for z in k.feld:
		if k.feld[z] == typ:
			n += 1
	return n


func _gewichtet(gewichte: Array) -> int:
	var summe := 0.0
	for g in gewichte:
		summe += float(g)
	var x := _rng.randf() * summe
	for i in gewichte.size():
		x -= float(gewichte[i])
		if x <= 0.0:
			return i
	return 0


func _zufall(bot: BotApi) -> void:
	for i in 12:
		var liste: Array = bot.erlaubte_aktionen().filter(func(a: Dictionary) -> bool: return a["a"] != "welle_starten" and a["a"] != "abreissen")
		if liste.is_empty() or _rng.randf() < 0.15:
			break
		if bot.fuehre_aus(liste[_rng.randi() % liste.size()])["ok"]:
			zaehler["gekauft"] += 1
