extends SceneTree
## 23.11.: Brakk-Protokoll (scripts/brakk_protokoll.gd) – Ring kaufen, Ringfeld setzen, Welle laufen lassen, Runde
## schließen: Der Runden-Eintrag muss einen Block "brakk" mit Ringaktionen, Lage, Schaden und Ereignissen tragen.
##
##   godot --headless --path . --fixed-fps 60 -s werkzeuge/brakkprotokolltest.gd
##
## Schreibt nichts nach partien/ (ohne_spuren). Am Ende „TEST BRAKKPROTOKOLL OK“ oder die Fehler.

var spiel: Node
var ego: EgoModus
var warte := 20
var t0 := 0
var schritt := 0
var bilder := 0
var fehler: Array[String] = []


func _initialize() -> void:
	BrakkTutorial.erzwingen = false
	Werte.setze_anfuehrer("brakk")
	var main_skript: GDScript = load("res://scripts/main.gd")
	main_skript.set("naechster_start", "brakk")
	main_skript.set("ohne_spuren", true)
	spiel = load("res://main.tscn").instantiate()
	root.add_child(spiel)
	t0 = Time.get_ticks_msec()


func pruefe(ok: bool, text: String) -> void:
	print("%s %s" % ["OK  " if ok else "FEHL", text])
	if not ok:
		fehler.append(text)


func _process(_delta: float) -> bool:
	if warte > 0:
		warte -= 1
		return false
	if ego == null:
		ego = spiel.ego
		if ego == null:
			if Time.get_ticks_msec() - t0 > 20000:
				pruefe(false, "keine Ego-Sicht")
				_ende()
			return false
		warte = 10
		return false
	var f: BrakkFortschritt = ego.brakk.fortschritt
	match schritt:
		0:
			pruefe(f != null and f.protokoll != null, "Fortschritt mit Protokoll")
			spiel.budget = 2000
			pruefe(f.kaufe("durchschuss", spiel) == "", "Ring gekauft")
			pruefe(f.kaufe("durchschuss", spiel) == "", "Ring Stufe 2")
			f.setze_feld("durchschuss", Vector2i(10, 4))
			pruefe(f.protokoll.ring_aktionen.size() == 3, "3 Ringaktionen gemerkt (%d)" % f.protokoll.ring_aktionen.size())
			spiel.starte_welle(true)
			schritt = 1
		1:
			bilder += 1
			if bilder == 120:
				spiel.brakk_ereignis("cp_verloren", {"cp": 1})
			if bilder >= 600:
				schritt = 2
		2:
			pruefe(spiel.phase == 1 or spiel.phase == 0, "Phase %d" % spiel.phase)
			spiel._schliesse_runde("test")
			var runden: Array = spiel._protokoll.get("runden", [])
			var e: Dictionary = runden[runden.size() - 1] if not runden.is_empty() else {}
			pruefe(e.has("brakk"), "Runden-Eintrag hat Block brakk")
			var b: Dictionary = e.get("brakk", {})
			print(JSON.stringify(b).left(900))
			pruefe((b.get("ring_aktionen", []) as Array).size() == 3, "Ringaktionen im Block")
			pruefe((b.get("lage", []) as Array).size() >= 3, "Lage gesammelt (%d)" % (b.get("lage", []) as Array).size())
			pruefe((b.get("ereignisse", []) as Array).size() >= 1, "Ereignis CP verloren")
			pruefe(b.has("schaden") and b.has("brakk_quellen") and b.has("zaehler") and b.has("gegnerweg"), "Schaden, Quellen, Zähler, Weg")
			pruefe((b.get("ringe", []) as Array).size() == 1 and int(b["ringe"][0][1]) == 2, "Ring mit Stufe 2 im Stand")
			pruefe(f.protokoll.ring_aktionen.is_empty(), "Protokoll für die nächste Runde geleert")
			pruefe(JSON.parse_string(JSON.stringify(spiel._protokoll)) is Dictionary, "Protokoll als JSON lesbar")
			_ende()
	return false


func _ende() -> void:
	print("TEST BRAKKPROTOKOLL OK" if fehler.is_empty() else "TEST BRAKKPROTOKOLL FEHLER: %s" % ", ".join(fehler))
	quit(0 if fehler.is_empty() else 1)
