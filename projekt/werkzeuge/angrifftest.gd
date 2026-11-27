extends SceneTree
## Phantom-Modus ohne Bild durchspielen: greift ein Verteidigungs-Phantom jede Runde mit der entworfenen Welle an
## (genau das Budget der Runde) und gibt je Runde aus, was sie gebracht hat.
## 25.11.: prüft, dass der Angriff in Runde Phantom.ANGRIFF_AB_RUNDE beginnt und nur die Budgets ab dort zählen.
##
## Aufruf:
##   godot --headless --path . --fixed-fps 60 -s werkzeuge/angrifftest.gd -- "Phantom Dateien/Verteidiger/verteidigung-....json" [bis Runde]

var spiel: Node
var warte := 3
var bis := 20
var gemeldet := 0
var sim := 0.0
var runde_start := 0.0
var start_geprueft := false


## Summe der Budgets der gebuchten Runden gegen die Tabelle ab der Startrunde.
func _budget_pruefen() -> void:
	var ist := 0
	var soll := 0
	for i in spiel.phantom_partie.angriff_log.size():
		ist += int(spiel.phantom_partie.angriff_log[i]["budget"])
		soll += Phantom.budget(Phantom.ANGRIFF_AB_RUNDE + i)
	var erste := int(spiel.phantom_partie.angriff_log[0]["runde"]) if not spiel.phantom_partie.angriff_log.is_empty() else 0
	print("%s Budgetsumme %d (soll %d), erste gebuchte Runde %d" % ["OK  " if ist == soll and erste == Phantom.ANGRIFF_AB_RUNDE else "FEHL", ist, soll, erste])


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		print("Aufruf: ... -s werkzeuge/angrifftest.gd -- <verteidigung.json> [bis Runde]")
		quit(1)
		return
	if args.size() > 1:
		bis = int(args[1])
	OS.set_environment("TD_PHANTOM", args[0])
	spiel = load("res://main.tscn").instantiate()
	root.add_child(spiel)


func _process(delta: float) -> bool:
	sim += delta
	if warte > 0:
		warte -= 1
		return false
	if spiel.phantom_modus != "angriff":
		print("Phantom nicht geladen.")
		return true
	var log: Array = spiel.phantom_partie.angriff_log
	while gemeldet < log.size():
		var e: Dictionary = log[gemeldet]
		print("Runde %2d | Punkte %4d/%4d | Leben genommen %2d | Checkpoints %d | %5.1f s | Verteidigung noch %d" % [e["runde"], e["punkte"], e["budget"], e["leben_genommen"], e["checkpoints_genommen"], e["sekunden"], spiel.leben])
		gemeldet += 1
	if not start_geprueft:
		start_geprueft = true
		print("%s Angriff beginnt in Runde %d" % ["OK  " if spiel.welle == Phantom.ANGRIFF_AB_RUNDE else "FEHL", spiel.welle])
	if spiel.phase == 2:
		_budget_pruefen()
		print("ENDE: ", spiel._ende_text.text.replace("\n", " | "))
		return true
	if spiel.phase == 0:
		if spiel.welle > bis:
			_budget_pruefen()
			print("Abbruch nach Runde %d (gewollt)." % bis)
			return true
		spiel._laufband._vorlage()
		runde_start = sim
		spiel.starte_welle()
	elif sim - runde_start > 400.0:
		print("Abbruch: Runde %d läuft zu lang." % spiel.welle)
		return true
	return false
