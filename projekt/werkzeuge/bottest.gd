extends SceneTree
## Prüft die Bot-Schnittstelle (Schritt 9a, Teil 2): Aktionen mit Rückmeldung, Formturm-Erkennung, erlaubte_aktionen,
## und sichern() → Welle → laden() → dieselbe Welle: Stand Feld für Feld gleich, Ergebnis gleich.
##
## Aufruf:
##   godot --headless --path . --fixed-fps 60 -s werkzeuge/bottest.gd -- [Runden] [Anführer] [Samen]
## Schreibt nichts in den Benutzerordner und nichts nach partien/.

var runden := 8
var anfuehrer := "brakk"
var samen := 4242
var bot: BotApi
var fehler := 0
var zustand := "warten"
var stand: Dictionary = {}
var ergebnis_a: Dictionary = {}
var welle_nr := 0
var t_start := 0
var t_mitte := Karte.KEINE   # Mitte des T-Stücks, auf die der Formturm kommt


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		runden = int(args[0])
	if args.size() > 1:
		anfuehrer = args[1]
	if args.size() > 2:
		samen = int(args[2])
	t_start = Time.get_ticks_msec()
	bot = BotApi.neue_partie(root, anfuehrer, samen)


func _pruefe(ok: bool, text: String) -> void:
	print(("OK   " if ok else "FEHL ") + text)
	if not ok:
		fehler += 1


func _process(_delta: float) -> bool:
	match zustand:
		"warten":
			if bot.bereit():
				zustand = "bauen"
		"bauen":
			if bot.spiel.phase == 2:
				return _ende()
			welle_nr = bot.spiel.welle
			if welle_nr > runden:
				return _ende()
			_baue_runde()
			if welle_nr >= 3:
				stand = bot.sichern()   # vor dem Start: Bauphase mit fertigem Einkauf
			var r := bot.welle_starten()
			_pruefe(r["ok"], "Runde %d gestartet %s" % [welle_nr, r["grund"]])
			if not r["ok"]:
				return _ende()
			zustand = "welle_a"
		"welle_a", "welle_b":
			if bot.spiel.phase == 1:
				return false
			var e := _ergebnis()
			if zustand == "welle_a" and welle_nr >= 3:
				ergebnis_a = e
				bot.laden(stand)
				var nach := bot.sichern()
				var diff := BotApi.unterschiede(stand, nach)
				_pruefe(diff.is_empty(), "Runde %d: Stand nach laden() gleich dem gesicherten%s" % [welle_nr, "" if diff.is_empty() else " – abweichend: " + ", ".join(PackedStringArray(diff.slice(0, 12)))])
				var r := bot.welle_starten()
				if not r["ok"]:
					_pruefe(false, "Neustart der Welle nach laden(): " + r["grund"])
					return _ende()
				zustand = "welle_b"
				return false
			if zustand == "welle_b":
				var gleich := var_to_str(e) == var_to_str(ergebnis_a)
				_pruefe(gleich, "Runde %d zweimal gespielt: %s%s" % [welle_nr, _kurz(e), "" if gleich else " statt " + _kurz(ergebnis_a)])
			else:
				print("     Runde %d: %s" % [welle_nr, _kurz(e)])
			zustand = "bauen"
	return false


func _ergebnis() -> Dictionary:
	var z := bot.zustand()
	var cps: Array = []
	for c: Dictionary in z["checkpoints"]:
		cps.append(c["beim_gegner"])
	return {"phase": z["phase"], "runde": z["runde"], "leben": z["leben"], "geld": z["geld"], "cp": cps}


func _kurz(e: Dictionary) -> String:
	return "Leben %d, Geld %d, CP beim Gegner %s" % [e["leben"], e["geld"], str(e["cp"])]


## Einfacher, fester Einkauf: Fabriken nah an der Basis, ab den Erdwällen ein T-Stück mit Formturm, dann Ausbauten.
func _baue_runde() -> void:
	var s: Node = bot.spiel
	var basis: Vector2i = s.karte.basis
	if welle_nr == 1:
		# Prüfungen der Rückmeldungen
		var r := bot.baue(Vector2i(0, 0), "fabrik")
		_pruefe(not r["ok"] and r["grund"] != "", "Fabrik in der Gegnerzone abgelehnt: „%s“" % r["grund"])
		r = bot.baue(basis, "wall")
		_pruefe(not r["ok"] and r["grund"] != "", "Erdwall vor Welle %d abgelehnt: „%s“" % [Werte.WAELLE_AB_WELLE, r["grund"]])
		r = bot.aufwerten(basis)
		_pruefe(not r["ok"], "Ausbau ohne Bauwerk abgelehnt: „%s“" % r["grund"])
		var t := Time.get_ticks_usec()
		var alle := bot.erlaubte_aktionen()
		print("     erlaubte_aktionen(): %d Einträge in %.0f ms" % [alle.size(), (Time.get_ticks_usec() - t) / 1000.0])
	# Fabriken: bis vier, die nächsten zur Basis
	while s.fabriken.size() < 4:
		var feld := _naechstes(bot.erlaubte_aktionen(["fabrik"]), basis)
		if feld == Karte.KEINE:
			break
		var r := bot.baue(feld, "fabrik")
		if not r["ok"]:
			break
		if s.fabriken.size() == 2:
			bot.fabrik_einheit(feld, "scharfschuetze")
	# T-Stück mit Formturm, sobald Erdwälle gehen
	if t_mitte != Karte.KEINE and s.karte.turm_art.is_empty():
		var r := bot.baue(t_mitte, "turm")
		if r["ok"]:
			var form: String = Werte.TURMARTEN[r["form"]]["form"] if Werte.TURMARTEN.has(r["form"]) else "?"
			_pruefe(form == "T-Stück", "Runde %d: Turm auf dem T-Stück erkannt als %s (%s)" % [welle_nr, r["form"], form])
		else:
			print("     Runde %d: Turm noch nicht gebaut: %s" % [welle_nr, r["grund"]])
	if welle_nr >= Werte.WAELLE_AB_WELLE and t_mitte == Karte.KEINE:
		var waelle := {}
		for a: Dictionary in bot.erlaubte_aktionen(["wall"]):
			if a["a"] != "bau":
				continue
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
			var gebaut := 0
			for o: Vector2i in [Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2), Vector2i(-1, 1)]:
				if bot.baue(ziel + o, "wall")["ok"]:
					gebaut += 1
			_pruefe(gebaut == 4, "Runde %d: T-Stück aus %d Erdwällen gebaut" % [welle_nr, gebaut])
			t_mitte = ziel + Vector2i(0, 1)   # der Turm kommt, sobald das Geld reicht
	# Rest: Ausbauten der Reihe nach, Stufe-3-Wahl jeweils die erste
	for i in 6:
		var wahl: Array = bot.ausbau_wahlen().filter(func(a: Dictionary) -> bool: return a["a"] == "aufwerten")
		if wahl.is_empty():
			break
		bot.fuehre_aus(wahl[0])


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


func _ende() -> bool:
	print("Dauer: %.1f s, Ergebnis: %s" % [(Time.get_ticks_msec() - t_start) / 1000.0, _kurz(_ergebnis())])
	print("TEST BOT %s (%d Fehler)" % ["OK" if fehler == 0 else "FEHLGESCHLAGEN", fehler])
	return true
