extends SceneTree
## 23.11.: Bilder der Phantom-Einführung: Funkfenster im Phantom-Menü (C), Siegbild mit Comic (B),
## Endtafel mit Elo-Animation (F) – ohne Verbindung, mit Testdaten.
##   xvfb-run godot --path . -s werkzeuge/einfuehrungsbild.gd -- <Ausgabeordner>
var m: Startmenue
var t: EndTafel
var schritt := 0
var warte := 8
var aus := "user://"
var zeit_ms := 0

func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0:
		aus = a[0]
	Online.gesperrt = true
	Profil.setze_einstellung("pe_menue", false)
	m = Startmenue.new()
	root.add_child(m)

func _bild(name: String) -> void:
	root.get_viewport().get_texture().get_image().save_png(aus.path_join(name))
	print("BILD ", name)

func _tafel(conf: Dictionary) -> void:
	if t != null:
		t.get_parent().queue_free()
	t = EndTafel.new()
	var ebene := CanvasLayer.new()
	root.add_child(ebene)
	ebene.add_child(t)
	t.zeige(conf)

func _process(_d: float) -> bool:
	if warte > 0:
		warte -= 1
		return false
	match schritt:
		0:
			m._titel = false
			m._zeige("phantom")
			Online.zustand = "online"
		30:
			_bild("c_funkfenster.png")
			Input.warp_mouse(Vector2(1030, 142))
		36:
			_bild("c_spaltenhinweis.png")
			m.queue_free()
			for n in root.get_children():
				if n is Funkfenster:
					n.queue_free()
			var G := Color("ffd34d")
			_tafel({"kicker": "RUNDE 20 · GEGENANGRIFF", "titel": "SIEG", "titel_farbe": G, "rahmen": G, "untertitel": "Das HQ der Myriaden ist zerstört.", "effekt": "funken",
				"kacheln": [{"name": "RUNDEN", "zahl": 20, "max": 20, "farbe": Color("7fe0ff")}, {"name": "LEBEN", "zahl": 18, "max": 20, "farbe": Color("ff5a6e"), "symbol": "herz"}, {"name": "BESIEGT", "zahl": 412, "farbe": Color("e08a4f")}, {"name": "KAMPFZEIT", "zahl": 1200, "zeit": true, "farbe": Color("e6edf3")}],
				"comic": [["wall", "Dein Bau", Color("7fe0ff")], ["panzer", "Andere greifen an", Color("ffb070")], ["buch", "Bericht für dich", G]],
				"kaesten": [{"titel": "DEIN BAU IST JETZT EIN PHANTOM", "farbe": Color("7fe0ff"), "text": "Online hochgeladen: dein Bau – andere Spieler treffen jetzt darauf."}],
				"zeilen": ["Phantom-Modus freigeschaltet"], "knoepfe": [["In die Offensive", func(): pass, Color("ffb070")], ["Neustart", func(): pass, Color("7fe0ff")], ["Startmenü", func(): pass, Color("e6edf3")]]})
		100:
			_bild("b_comic.png")
			var K := Color("ffb070")
			_tafel({"kicker": "PHANTOM-ANGRIFF  ·  GEGEN MIRA", "titel": "DURCHBRUCH!", "titel_farbe": K, "rahmen": K, "untertitel": "Die Verteidigung ist in Runde 14 gefallen.", "effekt": "kupfer",
				"kacheln": [{"name": "PUNKTE", "zahl": 8120, "farbe": Color("ffd34d")}, {"name": "LEBEN GENOMMEN", "zahl": 20, "farbe": Color("ff5a6e"), "symbol": "herz"}, {"name": "GEKNACKT", "zahl": 1, "farbe": Color("e08a4f")}, {"name": "BUDGET", "zahl": 3100, "farbe": Color("e6edf3"), "symbol": "muenze"}],
				"elo": {"label": "DEINE ANGRIFFS-ELO", "vorher": 1000, "nachher": -1, "hinweis": ""},
				"knoepfe": [["Nochmal angreifen", func(): pass, K], ["Startmenü", func(): pass, Color("e6edf3")]]})
		160:
			_bild("f_elo_wartet.png")
			t.elo_setze(1000, 1017, "noch 4 Läufe bis zur Rangliste")
		185:
			_bild("f_elo_zaehlt.png")
		230:
			_bild("f_elo_fertig.png")
			t.conf["elo"] = {"label": "DEINE VERTEIDIGUNGS-ELO", "vorher": 1042, "nachher": 1031, "hinweis": "Platz 4 in der Rangliste", "t0": 0.0}
			t.elo_setze(1042, 1031, "Platz 4 in der Rangliste")
		290:
			_bild("f_elo_verlust.png")
			quit()
	schritt += 1
	return false
