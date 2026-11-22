extends SceneTree
## Lässt die Formationen aus werkzeuge/plaene.gd gegen die 20 Runden laufen und schreibt je Lauf eine JSON-Zeile.
##
##   godot --headless --path . --fixed-fps 60 -s werkzeuge/formtest.gd -- <Ausgabedatei> <frei|budget> <Läufe> [Plan ...]
##
## frei   = ab Runde 2 steht die ganze Formation (unbegrenztes Budget)
## budget = es wird jede Runde so viel vom Plan gebaut, wie das echte Budget hergibt (Teilausbau)

const PLAENE: Dictionary = preload("res://werkzeuge/plaene.gd").PLAENE
const EINHEITEN := ["scharfschuetze", "technogunner", "plasmawerfer", "technogunner", "scharfschuetze"]

var datei := ""
var modus := "frei"
var laeufe := 1
var namen: Array = []
var auftraege: Array = []    # [Name, Lauf]
var spiel: Node
var warte := 0
var eingerichtet := false
var sim_zeit := 0.0
var runde_start := 0.0
var runden: Array = []
var vorher := {}
var offen := {}              # was vom Plan noch fehlt
var name_jetzt := ""
var _gesehen := {}           # Gegner-Kennung -> [Kurzname, Position] im letzten Bild
var _leben_bild := 0
var _leck := {}              # Kurzname -> so viele kamen in dieser Runde bis zur Basis durch
var _truppen_ids := {}
var _gefallen := 0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	datei = args[0]
	modus = args[1]
	laeufe = int(args[2])
	namen = args.slice(3) if args.size() > 3 else PLAENE.keys()
	for n in namen:
		for l in laeufe:
			auftraege.append(n)
	_neuer_lauf()


func _neuer_lauf() -> void:
	if spiel != null:
		spiel.queue_free()
		spiel = null
	if auftraege.is_empty():
		quit(0)
		return
	name_jetzt = auftraege.pop_front()
	spiel = load("res://main.tscn").instantiate()
	root.add_child(spiel)
	spiel.protokoll_an = false
	eingerichtet = false
	runden = []
	warte = 2


func _lies_plan() -> void:
	var plan: Array = PLAENE[name_jetzt]
	offen = {"fabrik": [], "wall": [], "stellung": [], "turm": [], "tor": []}
	var cps: Array = [[6, 4], [13, 5]]
	for y in plan.size():
		for x in (plan[y] as String).length():
			var c: String = plan[y][x]
			var z := Vector2i(x, y)
			match c:
				"1": cps[0] = [x, y]
				"2": cps[1] = [x, y]
				"F": offen["fabrik"].append(z)
				"#": offen["wall"].append(z)
				"S":
					offen["wall"].append(z)
					offen["stellung"].append(z)
				"T":
					offen["wall"].append(z)
					offen["turm"].append(z)
				"O":
					offen["wall"].append(z)
					offen["tor"].append(z)
	spiel.setze_checkpoints(cps)
	# Teilausbau: Erdwälle von der Zone aus nach hinten; bei der Zitadelle vom Kern nach außen
	var mitte := Vector2.ZERO
	for f: Vector2i in offen["fabrik"]:
		mitte += Vector2(f)
	mitte /= maxf(1.0, (offen["fabrik"] as Array).size())
	var kern := name_jetzt.contains("zitadelle")
	(offen["wall"] as Array).sort_custom(func(a: Vector2i, b: Vector2i):
		if kern:
			return Vector2(a).distance_to(Vector2(10.5, 4.5)) < Vector2(b).distance_to(Vector2(10.5, 4.5))
		return a.x < b.x if a.x != b.x else a.y < b.y)


func _baue_fabriken(hoechstens: int) -> void:
	for z: Vector2i in offen["fabrik"]:
		if spiel.fabriken.size() >= hoechstens:
			return
		if spiel.fabriken.has(z) or not spiel.baue(z, Karte.FABRIK, true):
			continue
		var typ: String = EINHEITEN[(offen["fabrik"] as Array).find(z) % EINHEITEN.size()]
		spiel.fabriken[z]["typ"] = typ
		spiel.karte.fabrik_typ[z] = typ
		# Umgebungsvariable FORM_UPGRADES="scharfschuetze:laser,technogunner:minigun,...": Fabriken gleich auf Stufe 3 setzen
		for paar in OS.get_environment("FORM_UPGRADES").split(",", false):
			var teile := paar.split(":")
			if teile.size() == 2 and teile[0] == typ:
				spiel.fabriken[z]["stufe"] = 3
				spiel.fabriken[z]["faehigkeit"] = teile[1]
				spiel.karte.fabrik_stufe[z] = 3


## Baut fehlende Ausbauten dieser Art nach (auch solche, die mit ihrem Wall verloren gingen).
func _baue_ausbauten(art: String, typ: int, hoechstens: int) -> void:
	for z: Vector2i in offen[art]:
		if hoechstens <= 0:
			return
		if spiel.karte.inhalt(z) == Karte.WALL and not spiel.karte.ausbau.has(z) and spiel.baue(z, typ, true):
			hoechstens -= 1


## Jede Bauphase: alles nachbauen, was vom Plan fehlt (auch Gesprengtes) – soweit das Budget reicht.
func _bauphase() -> void:
	var frei := modus == "frei"
	if frei:
		spiel.budget = 100000
	_baue_fabriken(5 if frei else mini(5, 2 + int((spiel.welle - 1) / 2.0)))
	if spiel.welle >= Werte.WAELLE_AB_WELLE:
		var gebaut := 0
		for z: Vector2i in offen["wall"]:
			if spiel.karte.inhalt(z) == Karte.WALL:
				continue
			if not spiel.baue(z, Karte.WALL, true):
				if spiel.budget < Werte.KOSTEN_WALL:
					break
				continue
			gebaut += 1
			_baue_ausbauten("tor", Karte.TOR, 99)
			if not frei and gebaut % 5 == 0:
				_baue_ausbauten("stellung", Karte.STELLUNG, 1)   # Teilausbau: Stellungen wachsen mit
		_baue_ausbauten("tor", Karte.TOR, 99)
		_baue_ausbauten("stellung", Karte.STELLUNG, 99)
		_baue_ausbauten("turm", Karte.TURM, 99)
	_baue_fabriken(5)
	if frei:
		spiel.budget = 100000
	elif modus == "echt":
		_werte_auf()


## Modus "echt": wie budget, dazu fließt das Restbudget in Fabrik-Upgrades (Umgebungsvariable FORM_SATZ = A|B|C|N).
const SAETZE := {
	"A": {"scharfschuetze": "durchschuss", "technogunner": "bollwerk", "plasmawerfer": "abpraller"},
	"B": {"scharfschuetze": "laser", "technogunner": "feuerteam", "plasmawerfer": "brandfeld"},
	"C": {"scharfschuetze": "markierung", "technogunner": "minigun", "plasmawerfer": "plasmagel"},
}


func _werte_auf() -> void:
	var satz: Dictionary = SAETZE.get(OS.get_environment("FORM_SATZ"), {})
	if satz.is_empty():
		return
	var weiter := true
	while weiter:
		weiter = false
		var zs: Array = spiel.fabriken.keys()
		zs.sort_custom(func(a: Vector2i, b: Vector2i): return int(spiel.fabriken[a].get("stufe", 0)) < int(spiel.fabriken[b].get("stufe", 0)))
		for z: Vector2i in zs:
			var typ: String = spiel.fabriken[z]["typ"]
			if satz.has(typ) and spiel.werte_auf(z, satz[typ]):
				weiter = true
				break


func _zaehle() -> Dictionary:
	var k: Karte = spiel.karte
	var w := 0
	var st := 0
	var tu := 0
	for z: Vector2i in k.feld:
		if k.feld[z] == Karte.WALL:
			w += 1
	for z: Vector2i in k.ausbau:
		if k.ausbau[z] == Karte.STELLUNG:
			st += 1
		elif k.ausbau[z] == Karte.TURM:
			tu += 1
	return {"waelle": w, "stellungen": st, "tuerme": tu, "fabriken": spiel.fabriken.size()}


func _process(delta: float) -> bool:
	if spiel == null:
		return false
	sim_zeit += delta
	if warte > 0:
		warte -= 1
		return false
	if not eingerichtet:
		eingerichtet = true
		_lies_plan()
	if spiel.phase == 0:
		if not vorher.is_empty():
			_halte_fest("geschafft")
		_bauphase()
		vorher = _zaehle()
		vorher["leben"] = spiel.leben
		vorher["runde"] = spiel.welle
		vorher["weg"] = spiel.karte.pfad.size()
		vorher["budget"] = spiel.budget
		runde_start = sim_zeit
		_gesehen = {}
		_leck = {}
		_truppen_ids = {}
		_gefallen = 0
		_leben_bild = spiel.leben
		spiel.starte_welle()
	if spiel.phase == 1:
		_beobachte()
	if spiel.phase == 2:
		_beobachte()
		_halte_fest(spiel.ausgang if spiel.ausgang != "" else "niederlage")
		return _fertig()
	elif sim_zeit - runde_start > 600.0 * Werte.SPIELTEMPO:
		_halte_fest("abgebrochen")
		return _fertig()
	return false


## Wer kommt durch, und wie viele eigene Truppen fallen? (verglichen wird Bild für Bild)
func _beobachte() -> void:
	var basis: Vector2 = spiel.karte.mitte(Werte.BASIS_ZELLE)
	var jetzt := {}
	for g in spiel.gegner:
		jetzt[g.get_instance_id()] = [g.daten["kurz"], g.position]
	if spiel.leben < _leben_bild:
		for id in _gesehen:
			if not jetzt.has(id) and (_gesehen[id][1] as Vector2).distance_to(basis) < 2.0 * Werte.ZELLE:
				_leck[_gesehen[id][0]] = int(_leck.get(_gesehen[id][0], 0)) + 1
	_leben_bild = spiel.leben
	_gesehen = jetzt
	var truppen := {}
	for e in spiel.einheiten:
		truppen[e.get_instance_id()] = true
	if not spiel.einheiten.is_empty() or spiel.phase == 1:
		for id in _truppen_ids:
			if not truppen.has(id) and spiel.phase == 1 and not spiel.gegner.is_empty():
				_gefallen += 1
	_truppen_ids = truppen


func _halte_fest(ausgang: String) -> void:
	var jetzt := _zaehle()
	var rest: Array = []
	if ausgang == "abgebrochen":
		for g in spiel.gegner:
			rest.append([g.daten["kurz"], spiel.karte.zelle_bei(g.position).x, spiel.karte.zelle_bei(g.position).y])
	runden.append({
		"runde": vorher["runde"], "ausgang": ausgang,
		"verloren": vorher["leben"] - spiel.leben, "leben": spiel.leben,
		"cp_gegner": spiel.karte.cp_feind.count(true),
		"waelle": vorher["waelle"], "waelle_weg": vorher["waelle"] - jetzt["waelle"],
		"fabriken": vorher["fabriken"], "fabriken_weg": vorher["fabriken"] - jetzt["fabriken"],
		"stellungen": vorher["stellungen"], "tuerme": vorher["tuerme"],
		"weg": vorher["weg"], "budget": vorher["budget"],
		"sek": snappedf(sim_zeit - runde_start, 0.1),
		"leck": _leck.duplicate(), "gefallen": _gefallen, "rest": rest, "schlange": spiel._schlange.size(),
		"hq": (snappedf(spiel.hq.leben, 1.0) if is_instance_valid(spiel.hq) else 0.0),
	})
	vorher = {}


func _fertig() -> bool:
	var f := FileAccess.open(datei, FileAccess.READ_WRITE if FileAccess.file_exists(datei) else FileAccess.WRITE)
	f.seek_end()
	f.store_line(JSON.stringify({"plan": name_jetzt, "modus": modus, "runden": runden}))
	f.close()
	vorher = {}
	_neuer_lauf()
	return false
