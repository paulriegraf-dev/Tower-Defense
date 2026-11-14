extends SceneTree
## Spielt aufgezeichnete Partien (partien/partie-*.json) Zug für Zug nach und gibt je Runde das Ergebnis aus.
##
## Aufruf (ohne Bild, so schnell wie möglich):
##   godot --headless --path . --fixed-fps 60 -s werkzeuge/replay.gd -- <partie.json> [Anzahl Läufe] [frei]
## "frei" = unbegrenztes Budget (jeder aufgezeichnete Zug klappt, auch wenn das Geld diesmal nicht gereicht hätte).

const TYPEN := {"wall": Karte.WALL, "fabrik": Karte.FABRIK, "stellung": Karte.STELLUNG, "turm": Karte.TURM, "batterie": Karte.BATTERIE, "tor": Karte.TOR}

var partie: Dictionary
var laeufe := 5
var frei := false
var lauf := 0
var spiel: Node
var runden_index := 0
var gescheitert := 0
var warte := 0
var eingerichtet := false
var tabelle: Array = []      # je Lauf: Liste der Runden-Ergebnisse
var zeile: Array = []
var leben_vorher := 0
var start_ticks := 0
var sim_zeit := 0.0
var runde_start := 0.0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		print("Aufruf: ... -s werkzeuge/replay.gd -- <partie.json> [Läufe] [frei]")
		quit(1)
		return
	var text := FileAccess.get_file_as_string(args[0])
	partie = JSON.parse_string(text)
	if args.size() > 1:
		laeufe = int(args[1])
	frei = args.has("frei")
	_neuer_lauf()


func _neuer_lauf() -> void:
	if spiel != null:
		spiel.queue_free()
	spiel = load("res://main.tscn").instantiate()
	root.add_child(spiel)
	spiel.protokoll_an = false
	eingerichtet = false
	runden_index = 0
	gescheitert = 0
	zeile = []
	warte = 2


func _process(delta: float) -> bool:
	sim_zeit += delta
	if warte > 0:
		warte -= 1
		return false
	if not eingerichtet:
		# erst jetzt ist das Spiel fertig aufgebaut
		eingerichtet = true
		spiel.setze_checkpoints(partie["checkpoints"])
		if partie.has("basis"):
			spiel.setze_basis(Vector2i(int(partie["basis"][0]), int(partie["basis"][1])))
	if spiel.phase == 0:      # Bauphase: Ergebnis der letzten Runde festhalten, Züge der nächsten ausführen
		if runden_index > 0 and zeile.size() < runden_index:
			_halte_fest("geschafft")
		var runden: Array = partie["runden"]
		if runden_index >= runden.size():
			return _lauf_fertig()
		var runde: Dictionary = runden[runden_index]
		if frei:
			spiel.budget = 100000
		for a: Dictionary in runde["aktionen"]:
			var z := Vector2i(int(a["x"]), int(a["y"]))
			match a["a"]:
				"bau":
					if a.has("px"):
						# Batterie: die aufgezeichnete Lage der Pilotenfabrik einstellen
						spiel._paar_richtung = maxi(0, spiel.PAAR_RICHTUNGEN.find(Vector2i(int(a["px"]), int(a["py"])) - z))
					if not spiel.baue(z, TYPEN[a["typ"]], true):
						gescheitert += 1
				"abriss":
					spiel.reisse_ab(z)
				"einheit":
					spiel.stelle_um(z, a["typ"])
				"schild":
					if spiel.setze_schild(Vector2i(int(a["bx"]), int(a["by"])), z) != "":
						gescheitert += 1
				"upgrade":
					if not spiel.werte_auf(z, str(a.get("faehigkeit", ""))):
						gescheitert += 1
		spiel.variante = int(runde.get("variante", spiel.variante))
		runden_index += 1
		leben_vorher = spiel.leben
		runde_start = sim_zeit
		spiel.starte_welle()
		if spiel.phase == 0:    # keine Fabrik: Runde kann nicht starten
			zeile.append({"runde": spiel.welle, "ausgang": "kein Start"})
			return _lauf_fertig()
	elif spiel.phase == 2:    # Ende
		_halte_fest("sieg" if "Sieg" in spiel._ende_text.text else "niederlage")
		return _lauf_fertig()
	elif sim_zeit - runde_start > 600.0 * Werte.SPIELTEMPO:
		_halte_fest("abgebrochen (zu lang)")
		return _lauf_fertig()
	return false


func _halte_fest(ausgang: String) -> void:
	zeile.append({
		"runde": spiel.welle - (1 if ausgang == "geschafft" else 0),
		"ausgang": ausgang,
		"leben": spiel.leben,
		"verloren": leben_vorher - spiel.leben,
		"budget": spiel.budget,
		"cp_gegner": spiel.karte.cp_feind.count(true),
		"fabriken": spiel.fabriken.size(),
		"sek": snappedf((sim_zeit - runde_start), 0.1),
		"zuege_gescheitert": gescheitert,
	})


func _lauf_fertig() -> bool:
	tabelle.append(zeile)
	lauf += 1
	if lauf < laeufe:
		_neuer_lauf()
		return false
	_bericht()
	return true


func _bericht() -> void:
	print("\n=== Nachgespielt: %d Läufe, %d aufgezeichnete Runden%s ===" % [laeufe, (partie["runden"] as Array).size(), ", freies Budget" if frei else ""])
	var max_runden := 0
	for z: Array in tabelle:
		max_runden = maxi(max_runden, z.size())
	print("Runde | Läufe | Ø Leben | Ø verloren | max verloren | Ø Checkpoints beim Gegner | Ø Budget | Ø Sek. | gescheiterte Züge")
	for i in max_runden:
		var n := 0
		var leben := 0.0
		var verloren := 0.0
		var max_v := 0
		var cp := 0.0
		var budget := 0.0
		var sek := 0.0
		var fehl := 0
		var runde := 0
		for z: Array in tabelle:
			if i >= z.size() or not (z[i] as Dictionary).has("leben"):
				continue
			var e: Dictionary = z[i]
			n += 1
			runde = e["runde"]
			leben += e["leben"]
			verloren += e["verloren"]
			max_v = maxi(max_v, e["verloren"])
			cp += e["cp_gegner"]
			budget += e["budget"]
			sek += e["sek"]
			fehl = maxi(fehl, e["zuege_gescheitert"])
		if n > 0:
			print("%5d | %5d | %7.1f | %10.1f | %12d | %25.1f | %8.0f | %6.1f | %d" % [runde, n, leben / n, verloren / n, max_v, cp / n, budget / n, sek / n, fehl])
	var ausgaenge := {}
	for z: Array in tabelle:
		var letzter: Dictionary = z[z.size() - 1] if not z.is_empty() else {"ausgang": "leer", "runde": 0}
		var schluessel := "%s in Runde %d" % [letzter["ausgang"], letzter["runde"]] if letzter["ausgang"] != "geschafft" else "alle aufgezeichneten Runden geschafft"
		ausgaenge[schluessel] = int(ausgaenge.get(schluessel, 0)) + 1
	print("Ausgang: ", ausgaenge)
