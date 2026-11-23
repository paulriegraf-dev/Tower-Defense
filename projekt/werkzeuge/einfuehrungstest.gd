extends SceneTree
## 23.11.: Phantom-Einführung im Spiel – D (geführter erster Taktikplaner) und E (Banner „geplant von“).
##   xvfb-run godot --path . --resolution 1280x720 -s werkzeuge/einfuehrungstest.gd -- <Ausgabeordner> <verteidigung.json> <angriff.json>
var spiel: Node
var aus := "user://"
var schritt := 0
var warte := 10
var args: Array

func _initialize() -> void:
	args = OS.get_cmdline_user_args()
	aus = args[0]
	Online.gesperrt = true
	Profil.setze_einstellung("pe_taktik", false)
	Profil.setze_einstellung("pe_verteidigung", false)
	OS.set_environment("TD_PHANTOM", args[1])
	spiel = load("res://main.tscn").instantiate()
	root.add_child(spiel)

func _bild(name: String) -> void:
	root.get_viewport().get_texture().get_image().save_png(aus.path_join(name))
	print("BILD ", name)

func _f() -> Funkfenster:
	return spiel._funk

func _process(_d: float) -> bool:
	if warte > 0:
		warte -= 1
		return false
	match schritt:
		0:
			print("D schritt0 funk=", is_instance_valid(_f()), " ziel=", _f()._ziel_rect() if is_instance_valid(_f()) else "-")
			_bild("d1_vorlage.png")
			spiel._laufband._vorlage()
		10:
			print("D schritt1 index=", _f()._index, " ziel=", _f()._ziel_rect())
			_bild("d2_kaertchen.png")
			_f()._naechster()
		20:
			print("D schritt2 index=", _f()._index, " ziel=", _f()._ziel_rect())
			_bild("d3_budget.png")
			_f()._naechster()
		30:
			print("D schritt3 index=", _f()._index, " ziel=", _f()._ziel_rect())
			_bild("d4_start.png")
			spiel.starte_welle()
		45:
			print("D fertig: funk gueltig=", is_instance_valid(_f()) and not _f()._aus)
			spiel.queue_free()
		50:
			# E: Verteidigung gegen ein Angriffs-Phantom
			spiel = load("res://main.tscn").instantiate()
			root.add_child(spiel)
		70:
			spiel.phantom_modus = "verteidigung"
			spiel._angriff_phantom = {"spieler": "Mira", "runden": [{"runde": 1, "trupps": Werte.wellen_plan(1)["trupps"]}]}
		85:
			spiel.starte_welle(true)
		100:
			print("E phase=", spiel.phase, " trupps=", spiel._phantom_trupps(spiel.welle).size())
			_bild("e_banner.png")
			quit()
	schritt += 1
	return false
