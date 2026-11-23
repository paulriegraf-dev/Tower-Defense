extends SceneTree
## 23.11.: Bilder der Rangliste (Spieler / Phantome) und der Tafel „Plätze voll“ mit Testdaten – ohne Verbindung.
##   xvfb-run godot --path . -s werkzeuge/ranglistebild.gd -- <Ausgabeordner>
var m: Startmenue
var schritt := 0
var warte := 8
var aus := "user://"

func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0:
		aus = a[0]
	Online.gesperrt = true
	m = Startmenue.new()
	root.add_child(m)

func _daten() -> void:
	Online.zustand = "online"
	var mein := Profil.id()
	var namen := ["Paul", "Mira", "Tobi", "Kaan", "Lena", "Jo", "Sam", "Ida", "Ben", "Uwe", "Rike", "Max"]
	for art in ["angriff", "verteidigung"]:
		var l: Array = []
		var s: Array = []
		for i in namen.size():
			l.append({"id": "%s%d" % [art, i], "datei": "x", "spieler": namen[i], "profil": mein if i == 3 else "p%d" % i, "spalten": 28, "wertung": 9000 - i * 500, "elo": 1250 - i * 22, "spiele": [12, 9, 3, 7, 15, 5, 2, 8, 6, 11, 4, 5][i], "siege": 4, "anfuehrer": "brakk"})
			s.append({"profil": mein if i == 5 else "p%d" % i, "art": art, "spieler": namen[i], "elo": 1180 - i * 17, "spiele": [20, 14, 9, 3, 7, 6, 12, 5, 8, 2, 10, 5][i], "siege": 3})
		Online.listen[art] = l
		Online.spieler_listen[art] = s

func _bild(name: String) -> void:
	var img := root.get_viewport().get_texture().get_image()
	img.save_png(aus.path_join(name))
	print("BILD ", name)

func _process(_d: float) -> bool:
	if warte > 0:
		warte -= 1
		return false
	match schritt:
		0:
			m._titel = false
			m._zeige("phantom")
			_daten()
			m._rang_ansicht = "spieler"; m._rang_reiter = "angriff"
		2:
			_bild("rangliste_spieler_angriff.png")
			m._rang_ansicht = "phantome"; m._rang_reiter = "verteidigung"
		4:
			_bild("rangliste_phantome_verteidigung.png")
			m._rang_ansicht = "phantome"; m._rang_reiter = "angriff"
		6:
			_bild("rangliste_phantome_angriff.png")
			m.queue_free()
			var t := EndTafel.new()
			var ebene := CanvasLayer.new()
			root.add_child(ebene)
			ebene.add_child(t)
			var F := Color("e0a060")
			t.zeige({"kicker": "PHANTOM-POOL", "titel": "PLÄTZE VOLL", "titel_farbe": F, "rahmen": F,
				"untertitel": "Du hast schon 3 Verteidigungen im Pool. Welches soll weichen?",
				"punkte": [["wall", "1: Elo 962 · 4 Duelle · vom 19.11.  (schwächstes)"], ["wall", "2: Elo 1034 · 9 Duelle · vom 21.11."], ["wall", "3: Elo 1121 · 6 Duelle · vom 22.11."]],
				"zeilen": ["Dein neues Phantom nimmt den Platz eines alten ein. Das alte kommt ins Archiv.", "Seit dem 23.11. gilt: 3 Plätze. Deine 7 schwächeren älteren Phantome kommen dabei ebenfalls ins Archiv."],
				"knoepfe": [["Ersetze 1", func(): pass, F], ["Ersetze 2", func(): pass, Color("7fd6ff")], ["Ersetze 3", func(): pass, Color("7fd6ff")], ["Behalten", func(): pass, Color("c8ccd4")]]})
		160:
			_bild("plaetze_voll.png")
			quit()
	schritt += 1
	return false
