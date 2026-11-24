extends SceneTree
## 24.11.: Bilder der Spielerkarte, der Bilanz im Phantom-Menü und der Profilseite mit Testdaten – ohne Verbindung.
##   xvfb-run godot --path . --resolution 1280x720 -s werkzeuge/bilanzbild.gd -- <Ausgabeordner>
var m: Startmenue
var schritt := 0
var warte := 8
var aus := "user://"

func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0:
		aus = a[0]
	Online.gesperrt = true
	Profil.setze_einstellung("pe_menue", true)
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
			l.append({"id": "%s%d" % [art, i], "datei": "x", "spieler": namen[i], "profil": mein if i == 3 else "p%d" % i, "spalten": 28, "wertung": 9000 - i * 500, "elo": 1250 - i * 22, "spiele": 8, "siege": 4, "anfuehrer": "brakk"})
			s.append({"profil": mein if i == 5 else "p%d" % i, "art": art, "spieler": namen[i], "elo": 1180 - i * 17, "elo_max": 1210 - i * 12, "spiele": [20, 14, 9, 3, 7, 6, 12, 5, 8, 7, 10, 5][i], "siege": [9, 7, 5, 1, 4, 3, 6, 2, 3, 2, 4, 2][i]})
		Online.listen[art] = l
		Online.spieler_listen[art] = s

func _bild(name: String) -> void:
	root.get_viewport().get_texture().get_image().save_png(aus.path_join(name))
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
		10:
			_bild("bilanz_menue.png")
			m._karte_profil = "p1"
		20:
			_bild("karte_mira.png")
			m._karte_profil = Profil.id()
		30:
			_bild("karte_eigen.png")
			m._karte_profil = ""
			m._zeige("profil")
		40:
			_bild("profil.png")
			quit()
	schritt += 1
	return false
