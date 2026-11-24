extends SceneTree
## 24.11. (Version 72): Prüft Lauf-Duelle (Ergebnis, Gewicht) und das Spieler-Ergebnis ohne Verbindung.
##   xvfb-run godot --path . -s werkzeuge/laufmeldung_test.gd
func _initialize() -> void:
	var fehler := 0
	# Spieler-Ergebnis ohne weiche Faktoren
	fehler += _gleich("geknackt R3", Phantom.spieler_ergebnis(15, true, 3), 1.0)
	fehler += _gleich("geknackt R19", Phantom.spieler_ergebnis(15, true, 19), 1.0)
	fehler += _gleich("gefallen in R20", Phantom.spieler_ergebnis(15, true, 20), 0.75)
	fehler += _gleich("nicht geknackt 15", Phantom.spieler_ergebnis(15, false, 0), 0.7)
	fehler += _gleich("nicht geknackt 0", Phantom.spieler_ergebnis(0, false, 0), 0.0)
	fehler += _gleich("nicht geknackt 6", Phantom.spieler_ergebnis(6, false, 0), 0.28)
	# Lauf: Verteidigung A bis Runde 12 geknackt, Ersatz B ab Runde 13 in Runde 20 gefallen
	Online.pfad_id = {"a.json": "11111111-1111-1111-1111-111111111111", "b.json": "22222222-2222-2222-2222-222222222222"}
	var runden: Array = []
	for r in range(1, 13):
		runden.append({"runde": r, "gegen_pfad": "a.json", "leben_genommen": 1 if r < 12 else 4, "geknackt": r == 12})
	for r in range(13, 21):
		runden.append({"runde": r, "gegen_pfad": "b.json", "leben_genommen": 2 if r < 20 else 13, "geknackt": r == 20})
	var l := Online.lauf_duelle({"runden": runden})
	fehler += _gleich("zwei Verteidigungen", float(l.size()), 2.0)
	fehler += _gleich("A s", float(l[0]["s"]), 1.0)
	fehler += _gleich("B s (R20)", float(l[1]["s"]), 0.75)
	var wa := 0.0
	for r in range(1, 13):
		wa += Phantom.budget(r)
	var wb := 0.0
	for r in range(13, 21):
		wb += Phantom.budget(r)
	fehler += _gleich("A Gewicht", float(l[0]["w"]), wa)
	fehler += _gleich("B Gewicht", float(l[1]["w"]), wb)
	print("Budget-Anteil A %.0f%% / B %.0f%%" % [100.0 * wa / (wa + wb), 100.0 * wb / (wa + wb)])
	print("Phantom-Ergebnis A %.3f, B %.3f (mit weichen Faktoren)" % [float(l[0]["phantom_s"]), float(l[1]["phantom_s"])])
	# Verteidigung ohne Online-ID fällt weg
	Online.pfad_id = {"a.json": "11111111-1111-1111-1111-111111111111"}
	fehler += _gleich("nur A mit ID", float(Online.lauf_duelle({"runden": runden}).size()), 1.0)
	print("FEHLER: %d" % fehler if fehler > 0 else "ALLES OK")
	quit(1 if fehler > 0 else 0)

func _gleich(name: String, ist: float, soll: float) -> int:
	if absf(ist - soll) > 0.0001:
		print("FALSCH %s: %f statt %f" % [name, ist, soll])
		return 1
	return 0
