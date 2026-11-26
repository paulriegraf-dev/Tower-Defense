extends SceneTree
## 25.11. (Paul): Hangar mit 0, 3 und 6 Personen aus einer Testdatei bauen, jede Figur anklicken, Pfeiltasten, Esc.
##
##   godot --headless --path . -s werkzeuge/hangartest.gd
##   TD_OFFLINE=1 godot --path . -s werkzeuge/hangartest.gd -- <Ordner für Bilder>      (Fenster: je Fall ein Bild)
##
## Headless zeichnet Godot nichts, darum gibt es Bilder nur im Fensterlauf. Schreibt nur user://nemesis_hangar_test.json.
## Am Ende „TEST HANGAR OK“ oder die Fehler.

const DATEI := "user://nemesis_hangar_test.json"
const FAELLE := [0, 3, 6]

var fehler: Array[String] = []
var fall := 0
var schritt := 0
var warte := 5
var hangar: Hangar = null
var ordner := ""
var _vorher := ""
var _i := 0
var _zu := false
var _getroffen := 0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		ordner = args[0]
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
		DisplayServer.window_set_position(Vector2i(-5000, 100))
		DisplayServer.window_set_size(Vector2i(1280, 720))
		AudioServer.set_bus_mute(0, true)
	Nemesis.datei = DATEI


func pruefe(ok: bool, text: String) -> void:
	print("%s %s" % ["OK  " if ok else "FEHL", text])
	if not ok:
		fehler.append(text)


func _datei_bauen(n: int) -> void:
	var namen := ["Vex", "Pell", "Kord", "Zed", "Taln", "Quill"]
	var arten := ["technogunner", "technogunner", "scharfschuetze", "plasmawerfer", "plasmawerfer", "scharfschuetze"]
	var beinamen := ["der Pünktliche", "der Entschärfer", "Falkenauge", "der Zähe", "Befehl ist Befehl", "Weitblick"]
	var raenge := [1, 2, 1, 3, 1, 4]
	var personen: Array = []
	for i in n:
		var p := {"id": i + 1, "art": arten[i], "rang": raenge[i], "name": namen[i], "beiname": beinamen[i], "look": (i * 3) % 10,
			"faehigkeit": NemesisFaehigkeiten.ziehen(arten[i], "", false), "staerke": "zaeh", "schwaeche": "feuer",
			"staerke_bekannt": i % 2 == 0, "schwaeche_bekannt": false, "bilanz": {"er": i % 3, "brakk": (i + 1) % 3},
			"chronik": [{"zeit": 12.0, "text": "Feldbeförderung: hat Brakks Sprengladung überlebt", "datum": "2026-11-24"}]}
		if i == 1:
			p["titel"] = ["Unbelehrbar"]
			p["taktik"] = {"q": {"flanke": 12.0}, "n": {"flanke": 2}}
		personen.append(p)
	var chronik: Array = []
	if n > 0:
		chronik = [
			{"datum": "2026-11-21", "text": "Gefreiter Ohm ‚der Rest‘ versetzt"},
			{"datum": "2026-11-23", "text": "Korporal Brix ‚Aschefuß‘ versetzt", "person": {"name": "Brix", "beiname": "Aschefuß", "rang": 3, "art": "plasmawerfer", "look": 4, "titel": []}},
			{"datum": "2026-11-24", "text": "Hauptgefreiter Nox ‚Spürnase‘ endgültig ausgeschaltet", "person": {"name": "Nox", "beiname": "Spürnase", "rang": 2, "art": "scharfschuetze", "look": 7, "titel": []}},
		]
	var f := FileAccess.open(DATEI, FileAccess.WRITE)
	f.store_string(JSON.stringify({"version": 1, "appell_vergeben": true, "personen": personen, "chronik": chronik}))
	f.close()
	_vorher = FileAccess.get_file_as_string(DATEI)


func _bild(name: String) -> void:
	if ordner == "":
		return
	var img := root.get_texture().get_image()
	img.save_png("%s/%s.png" % [ordner, name])
	print("BILD %s %dx%d" % [name, img.get_width(), img.get_height()])


func _aktive() -> Array:
	return hangar.figuren.filter(func(f: Dictionary) -> bool: return str(f["was"]) == "aktiv" and not bool((f["p"] as Dictionary).get("sonde", false)))


func _process(_delta: float) -> bool:
	if ordner != "":
		Input.set_deferred("mouse_mode", Input.MOUSE_MODE_VISIBLE)
	if fall == 0 and schritt == 0 and warte == 5:
		_pruefe_plaetze()
	if warte > 0:
		warte -= 1
		return false
	var n: int = FAELLE[fall]
	match schritt:
		0:
			_datei_bauen(n)
			hangar = Hangar.new()
			if n == 6:
				hangar.aufstiege = {4: "befördert", 2: "Rang 1 → 2"}   # C1: wie aus dem Bericht
				hangar.kommandantin = true   # C3: Sonde 7 vertrieben
			_zu = false
			hangar.geschlossen.connect(func() -> void: _zu = true)
			root.add_child(hangar)
			warte = 40 if ordner != "" else 8
			schritt = 1
		1:
			_pruefe_aufbau(n)
			_bild("hangar_%d_uebersicht" % n)
			hangar._sofort = true
			_i = 0
			_getroffen = 0
			warte = 3
			schritt = 2
		2:
			# jede Figur einzeln anklicken (dazwischen abwählen, sonst liegt die Karte darüber)
			if _i < hangar.figuren.size():
				var r := hangar.rechteck(_i)
				var mitte := r.get_center()
				pruefe(r.size != Vector2.ZERO and Rect2(0, 0, 1280, 720).has_point(mitte), "%d: Figur %d (%s) steht im Bild bei %s" % [n, _i, str(hangar.figuren[_i]["p"]["name"]), str(mitte.round())])
				hangar.klick(mitte)
				if hangar.gewaehlt == _i:
					_getroffen += 1
				else:
					pruefe(false, "%d: Klick auf Figur %d wählt %d" % [n, _i, hangar.gewaehlt])
				warte = 3
				schritt = 3
			else:
				pruefe(_getroffen == hangar.figuren.size(), "%d Personen: Klick auf jede der %d Figuren wählt genau sie" % [n, hangar.figuren.size()])
				schritt = 4
		3:
			hangar.waehle(-1)
			_i += 1
			warte = 3
			schritt = 2
		4:
			if n > 0:
				var wahl := -1
				for i in hangar.figuren.size():
					if str(hangar.figuren[i]["p"]["name"]) == "Pell":
						wahl = i
				hangar._sofort = false
				hangar.waehle(wahl)
				warte = 90 if ordner != "" else 40
				schritt = 5
			else:
				schritt = 6
		5:
			var f: Dictionary = hangar.figuren[hangar.gewaehlt]
			pruefe((f["knoten"] as Node3D).position.z > (f["ort"] as Vector3).z + Hangar.SCHRITTE * 0.8, "%d: die gewählte Figur ist vorgetreten" % n)
			pruefe(hangar.kamera.position.distance_to((f["knoten"] as Node3D).position) < 7.0, "%d: die Kamera ist herangefahren" % n)
			_bild("hangar_%d_karte" % n)
			schritt = 6
		6:
			_pruefe_tasten(n)
			hangar = null
			fall += 1
			schritt = 0
			warte = 3
			if fall >= FAELLE.size():
				DirAccess.remove_absolute(ProjectSettings.globalize_path(DATEI))
				if fehler.is_empty():
					print("TEST HANGAR OK")
				else:
					print("TEST HANGAR FEHLER (%d): %s" % [fehler.size(), "; ".join(PackedStringArray(fehler))])
				quit(0 if fehler.is_empty() else 1)
				return true
	return false


## Alle Besetzungen mit höchstens 6 Personen: niemand steht genau hinter einer Figur der vorderen Reihen.
func _pruefe_plaetze() -> void:
	var schlecht := PackedStringArray()
	var zahl := 0
	for a in 7:
		for b in 7 - a:
			for c in 7 - a - b:
				var orte := Hangar.reihen_plaetze({1: a, 2: b, 3: c, 4: 1})
				var davor: Array = []
				var enge := INF
				for r: int in [1, 2, 3]:
					for x: float in orte[r]:
						for v: float in davor:
							enge = minf(enge, absf(x - v))
						if absf(x) > 5.8:
							enge = -1.0
					davor.append_array(orte[r])
				zahl += 1
				if enge < 0.5:
					schlecht.append("%d/%d/%d (%.2f)" % [a, b, c, enge])
	pruefe(schlecht.is_empty(), "Plätze: %d Besetzungen, niemand steht genau hintereinander%s" % [zahl, "" if schlecht.is_empty() else " – eng: " + ", ".join(schlecht)])


func _pruefe_aufbau(n: int) -> void:
	var aktiv := _aktive()
	pruefe(aktiv.size() == n, "%d Personen: %d Figuren im Dienst" % [n, aktiv.size()])
	if n == 0:
		pruefe(hangar.figuren.is_empty(), "0 Personen: leerer Hangar")
		return
	var oben := aktiv.filter(func(f: Dictionary) -> bool: return int(f["reihe"]) == 4)
	var beste := Hangar.herausforderer(Nemesis.meistgesuchte())
	pruefe(oben.any(func(f: Dictionary) -> bool: return str(f["p"]["name"]) == str(beste["name"])), "%d: die beste Bilanz (%s) steht auf dem Podest (%d dort)" % [n, str(beste["name"]), oben.size()])
	pruefe(aktiv.all(func(f: Dictionary) -> bool: return int(f["reihe"]) == 4 or int(f["reihe"]) == int(f["p"]["rang"])), "%d: Reihen nach Rang" % n)
	if n == 6:
		pruefe(oben.any(func(f: Dictionary) -> bool: return int(f["p"]["rang"]) == 4), "6: Rang 4 steht auf dem Podest")
		var sonde := hangar.figuren.filter(func(f: Dictionary) -> bool: return bool((f["p"] as Dictionary).get("sonde", false)))
		pruefe(sonde.size() == 1 and int(sonde[0]["reihe"]) == 4 and Nemesis.name_mit_titel(sonde[0]["p"] as Dictionary) == "Sonde 7 · Kommandantin", "6: Sonde 7 steht als Kommandantin auf dem Podest (C3)")
	var versetzt := hangar.figuren.filter(func(f: Dictionary) -> bool: return str(f["was"]) == "versetzt")
	var leer := hangar.figuren.filter(func(f: Dictionary) -> bool: return str(f["was"]) == "ausgeschaltet")
	pruefe(versetzt.size() == 2 and (versetzt[0]["knoten"] as Node3D).scale.x < 0.9 and (versetzt[0]["sprite"] as Sprite3D).modulate.r < 0.6, "%d: 2 Versetzte grau und kleiner (auch ein alter Eintrag ohne Bild)" % n)
	pruefe(leer.is_empty(), "%d: Ausgeschaltete stehen nicht mehr im Hangar (C1)" % n)
	if n == 6:
		_pruefe_auftritt()
	for f: Dictionary in aktiv:
		var z := {}
		for zeile: Array in Hangar.karten_zeilen(f["p"] as Dictionary):
			z[zeile[0]] = zeile[1]
		if str(f["p"]["name"]) == "Pell":
			pruefe(str(z["Stärke"]) == "?" and str(z["Schwäche"]) == "?" and str(z["Taktik"]).contains("Flanke") and str(z["Titel"]) == "Unbelehrbar", "%d: Karte Pell – Unbekanntes „?“, erlebte Taktik, Titel" % n)
		elif str(f["p"]["name"]) == "Vex":
			pruefe(str(z["Stärke"]).begins_with("zäh") and str(z["Taktik"]) == "?", "%d: Karte Vex – gesehene Stärke steht da, Taktik noch „?“" % n)


## C1: aus dem Bericht geöffnet treten die Beförderten nacheinander vor (Podest zuerst), Winkel leuchtet, Schild mit Text.
func _pruefe_auftritt() -> void:
	pruefe(hangar.auftritte.size() == 2, "6: zwei Beförderte warten auf ihren Auftritt (%d)" % hangar.auftritte.size())
	hangar.auftritt_protokoll.clear()
	hangar._auftritt_t = -Hangar.AUFTRITT_WARTEN
	var vor := {}
	var schild := false
	var leuchtet := false
	for k in 300:   # 5 s
		hangar._auftritt_weiter(1.0 / 60.0)
		for i: int in hangar.auftritte.slice(0, 1):
			var f: Dictionary = hangar.figuren[i]
			if (f["ziel"] as Vector3).z > (f["ort"] as Vector3).z + Hangar.SCHRITTE * 0.9:
				vor[str(f["p"]["name"])] = true
			if f["winkel"] != null and (f["winkel"] as Sprite3D).scale.x > 1.2:
				leuchtet = true
		if hangar._auftritt_schild != null:
			schild = true
	var texte := hangar.auftritt_protokoll.map(func(x: Dictionary) -> String: return "%s: %s" % [str(hangar.figuren[int(x["i"])]["p"]["name"]), str(x["text"])])
	pruefe(vor.size() == 2 and texte.size() == 2 and str(texte[0]).begins_with("Zed") and str(texte[1]).contains("Rang 1 → 2"), "6: nacheinander vorgetreten – %s" % " · ".join(PackedStringArray(texte)))
	pruefe(leuchtet and schild and hangar.auftritte.is_empty() and hangar.figuren.all(func(f: Dictionary) -> bool: return f["ziel"] == f["ort"]), "6: Winkel leuchtet, Schild erscheint, alle wieder in der Reihe")


func _pruefe_tasten(n: int) -> void:
	var zahl := hangar.figuren.size()
	hangar.waehle(-1)
	var besucht := {}
	for i in zahl:
		hangar.taste(KEY_RIGHT)
		besucht[hangar.gewaehlt] = true
	pruefe(besucht.size() == zahl, "%d: Pfeil rechts erreicht alle %d Figuren" % [n, zahl])
	for c: int in [KEY_UP, KEY_UP, KEY_UP, KEY_DOWN, KEY_DOWN, KEY_DOWN, KEY_LEFT]:
		hangar.taste(c)
	pruefe(hangar.gewaehlt < zahl, "%d: Pfeile hoch, runter, links ohne Fehler" % n)
	if hangar.gewaehlt >= 0:
		hangar.taste(KEY_ESCAPE)
		pruefe(hangar.gewaehlt == -1 and not _zu, "%d: Esc wählt zuerst ab" % n)
	pruefe(FileAccess.get_file_as_string(DATEI) == _vorher, "%d: nemesis.json unverändert" % n)
	hangar.taste(KEY_ESCAPE)
	pruefe(_zu, "%d: Esc schließt den Hangar" % n)
