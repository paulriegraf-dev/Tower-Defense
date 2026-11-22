extends SceneTree
## 22.11. (Paul): Das Tutorial des Normalmodus einmal ganz durchspielen.
##
##   godot --headless --path . --fixed-fps 60 -s werkzeuge/tutorialtest.gd       (headless)
##   godot --path . -s werkzeuge/tutorialtest.gd                                 (im Fenster, zum Zuschauen)
##
## Der Schritt „Übersicht“ wird echt erledigt: öffnen (das Spiel steht dann), schließen mit Esc – danach muss die
## nächste Aufgabe kommen. Alle anderen Schritte gehen über „Weiter“ (Sicherheitsnetz: jeder Schritt hat ihn). Geprüft:
## kein Schritt hängt, jeder Schritt zeigt „Weiter“, der Übersicht-Schritt ist nach auf + zu erledigt, am Ende ist das
## Tutorial weg und der Rundenstart frei. Am Ende „TEST TUTORIAL OK“ oder die Fehler.
## Schreibt wie das Spiel in user:// (Profil: tutorial_fertig) – vorher sichern.

var spiel: Node
var tut: Tutorial
var warte := 20
var fehler: Array[String] = []
var schritt := 0
var lexikon_index := -1
var phase := ""
var uhr := 0
var gestartet := false


func _initialize() -> void:
	var main_skript: GDScript = load("res://scripts/main.gd")
	main_skript.set("naechster_start", "tutorial")
	spiel = load("res://main.tscn").instantiate()
	root.add_child(spiel)


func pruefe(ok: bool, text: String) -> void:
	print("%s %s" % ["OK  " if ok else "FEHL", text])
	if not ok:
		fehler.append(text)


func _process(_delta: float) -> bool:
	if warte > 0:
		warte -= 1
		return false
	if not gestartet:
		gestartet = true
		tut = spiel.get("tutorial")
		if tut == null:
			pruefe(false, "Tutorial startet")
			return _ende()
		for i in tut._schritte.size():
			if str((tut._schritte[i] as Dictionary).get("hinweis", "")).contains("Übersicht") or ((tut._schritte[i] as Dictionary).get("hinweis", "") is Callable and str((tut._schritte[i] as Dictionary).get("text", "")).contains("Übersicht")):
				lexikon_index = i
		print("     Tutorial: %d Schritte, Übersicht-Schritt Nr. %d" % [tut._schritte.size(), lexikon_index + 1])
		pruefe(lexikon_index >= 0, "Übersicht-Schritt gefunden")
		return false
	if not is_instance_valid(tut) or tut._aus:
		pruefe(spiel.get("tutorial") == null, "Ende: Tutorial weg, Rundenstart frei (nichts sperrt die Welle mehr)")
		pruefe(bool(Profil.einstellung("tutorial_fertig", false)), "Ende: als durchgespielt gemerkt")
		return _ende()
	var lx: CanvasItem = spiel.get("_lexikon")
	if tut._index == lexikon_index:
		match phase:
			"":
				pruefe(tut._btn_weiter.visible, "Übersicht-Schritt: „Weiter“ ist da (Sicherheitsnetz)")
				_bild("1_uebersicht_aufgabe")
				lx.visible = true   # wie [I]: die Übersicht hält das Spiel an
				phase = "auf"
				uhr = 0
			"auf":
				uhr += 1
				if uhr > 30:
					pruefe(paused, "Übersicht offen: das Spiel steht")
					pruefe(tut._index == lexikon_index, "Übersicht offen: Schritt wartet noch aufs Schließen")
					var esc := InputEventKey.new()
					esc.keycode = KEY_ESCAPE
					esc.pressed = true
					lx._input(esc)   # wie [Esc] in der Übersicht
					phase = "zu"
					uhr = 0
			"zu":
				uhr += 1
				if uhr > 60:
					pruefe(false, "Übersicht-Schritt: nach Öffnen und Schließen kam keine neue Aufgabe")
					tut._weiter()
		return false
	if phase == "zu":
		phase = "fertig"
		_bild("2_naechste_aufgabe")
		pruefe(not lx.visible and not paused and tut._index == lexikon_index + 1, "Übersicht-Schritt erledigt nach auf + zu (Esc) – nächste Aufgabe: „%s…“" % str((tut._schritte[tut._index] as Dictionary)["text"]).left(40))
	# alle anderen Schritte: „Weiter“ muss da sein und bringt weiter
	if not tut._btn_weiter.visible:
		pruefe(false, "Schritt %d ohne „Weiter“" % (tut._index + 1))
	schritt = tut._index
	tut._btn_weiter.pressed.emit()
	if tut._index == schritt and not tut._aus:
		pruefe(false, "Schritt %d: „Weiter“ bringt nicht weiter" % (schritt + 1))
		return _ende()
	return false


## Im Fenster mit `-- <Ordner>`: Bild der Ansicht dorthin speichern (headless gibt es kein Bild).
func _bild(name: String) -> void:
	var a := OS.get_cmdline_user_args()
	if a.is_empty() or DisplayServer.get_name() == "headless":
		return
	var img := root.get_texture().get_image()
	img.save_png(a[0].path_join("tutorial_%s.png" % name))
	print("     Bild: %s" % a[0].path_join("tutorial_%s.png" % name))


func _ende() -> bool:
	for f: String in fehler:
		print("FEHLER: " + f)
	print("TEST TUTORIAL OK" if fehler.is_empty() else "TEST TUTORIAL FEHLER (%d)" % fehler.size())
	return true
