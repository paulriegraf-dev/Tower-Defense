class_name Kaufplan
extends RefCounted
## Einfache Kaufpläne für den Schnelllauf (Schritt 9a). Die eigentlichen Bauweisen (Wallformen, Kaufregeln je
## Anführer) kommen in 9b als labor/bauweisen/*.json dazu.
##   "einfach": bis vier Fabriken nah an der Basis, ab den Erdwällen ein T-Stück mit Formturm, dann Ausbauten.
##   "zufall":  kauft zufällig aus erlaubte_aktionen() (Untergrenze). Eigener Zufall, nie der der Simulation.

var name := "einfach"
var _rng := RandomNumberGenerator.new()
var _t_mitte := Karte.KEINE


func _init(p_name: String, samen: int) -> void:
	name = p_name
	_rng.seed = hash(["kaufplan", p_name, samen])


## Einkauf einer Bauphase. Gibt die Zahl der ausgeführten Aktionen zurück.
func kaufe(bot: BotApi) -> int:
	match name:
		"zufall":
			return _zufall(bot)
		_:
			return _einfach(bot)


func _zufall(bot: BotApi) -> int:
	var n := 0
	for i in 12:
		var liste: Array = bot.erlaubte_aktionen().filter(func(a: Dictionary) -> bool: return a["a"] != "welle_starten" and a["a"] != "abreissen")
		if liste.is_empty() or _rng.randf() < 0.15:
			break
		if bot.fuehre_aus(liste[_rng.randi() % liste.size()])["ok"]:
			n += 1
	return n


func _einfach(bot: BotApi) -> int:
	var s: Node = bot.spiel
	var basis: Vector2i = s.karte.basis
	var n := 0
	while s.fabriken.size() < 4:
		var feld := _naechstes(bot.erlaubte_aktionen(["fabrik"]), basis)
		if feld == Karte.KEINE or not bot.baue(feld, "fabrik")["ok"]:
			break
		n += 1
		if s.fabriken.size() == 2:
			bot.fabrik_einheit(feld, "scharfschuetze")
	if _t_mitte != Karte.KEINE and s.karte.turm_art.is_empty():
		if bot.baue(_t_mitte, "turm")["ok"]:
			n += 1
	if s.welle >= Werte.WAELLE_AB_WELLE and _t_mitte == Karte.KEINE:
		var waelle := {}
		for a: Dictionary in bot.erlaubte_aktionen(["wall"]):
			if a["a"] == "bau":
				waelle[Vector2i(a["x"], a["y"])] = true
		var ziel := Karte.KEINE
		var bester := INF
		for c: Vector2i in waelle:
			if waelle.has(c + Vector2i(0, 1)) and waelle.has(c + Vector2i(0, 2)) and waelle.has(c + Vector2i(-1, 1)):
				var d := Vector2(c - basis).length()
				if d < bester:
					bester = d
					ziel = c
		if ziel != Karte.KEINE:
			for o: Vector2i in [Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2), Vector2i(-1, 1)]:
				if bot.baue(ziel + o, "wall")["ok"]:
					n += 1
			_t_mitte = ziel + Vector2i(0, 1)
	for i in 6:
		var wahl: Array = bot.ausbau_wahlen().filter(func(a: Dictionary) -> bool: return a["a"] == "aufwerten")
		if wahl.is_empty() or not bot.fuehre_aus(wahl[0])["ok"]:
			break
		n += 1
	return n


func _naechstes(liste: Array, zu: Vector2i) -> Vector2i:
	var bestes := Karte.KEINE
	var d_best := INF
	for a: Dictionary in liste:
		if a["a"] != "bau":
			continue
		var z := Vector2i(a["x"], a["y"])
		var d := Vector2(z - zu).length()
		if d < d_best:
			d_best = d
			bestes = z
	return bestes
