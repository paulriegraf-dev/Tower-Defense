extends SceneTree
## 25.11. (Paul): „Nemesis lesbar machen“ – Daten und Anzeige headless prüfen.
##
##   godot --headless --path . -s werkzeuge/nemesisanzeigetest.gd
##
## Punkt 4: alte nemesis.json laden („der Unbelehrbare“ wird Zusatztitel, der Beiname kommt zurück; alter Einzeltitel
## wird zur Liste). Am Ende „TEST NEMESISANZEIGE OK“ oder die Fehler. Schreibt nur user://nemesis_anzeige_test.json.

const DATEI := "user://nemesis_anzeige_test.json"

var fehler: Array[String] = []


func pruefe(ok: bool, text: String) -> void:
	print("%s %s" % ["OK  " if ok else "FEHL", text])
	if not ok:
		fehler.append(text)


func schreibe(personen: Array, chronik: Array = []) -> void:
	var f := FileAccess.open(DATEI, FileAccess.WRITE)
	f.store_string(JSON.stringify({"version": 1, "appell_vergeben": true, "personen": personen, "chronik": chronik}))
	f.close()


func nach_name(liste: Array, name: String) -> Dictionary:
	for p: Dictionary in liste:
		if str(p["name"]) == name:
			return p
	return {}


func _process(_delta: float) -> bool:
	Nemesis.datei = DATEI
	_alte_dateien()
	_looks()
	Nemesis.zuruecksetzen()
	if fehler.is_empty():
		print("TEST NEMESISANZEIGE OK")
	else:
		print("TEST NEMESISANZEIGE FEHLER (%d): %s" % [fehler.size(), "; ".join(PackedStringArray(fehler))])
	quit(0 if fehler.is_empty() else 1)
	return true


func _alte_dateien() -> void:
	# so sah die Datei bis zum 25.11. aus: titel als Text, „der Unbelehrbare“ als Beiname, kein „tat“, kein „look“
	var chronik := [{"zeit": 10.0, "text": "Feldbeförderung: %s" % str(Nemesis.TAT_TEXT["ladung"]), "datum": "2026-11-23"}]
	schreibe([
		{"id": 1, "art": "technogunner", "rang": 2, "name": "Pell", "beiname": "der Unbelehrbare", "titel": "", "chronik": chronik},
		{"id": 2, "art": "scharfschuetze", "rang": 3, "name": "Vex", "beiname": "der Unbelehrbare", "titel": "Brakks Bezwinger", "appell": true, "chronik": []},
		{"id": 3, "art": "plasmawerfer", "rang": 1, "name": "Zed", "beiname": "der Unbelehrbare", "chronik": []},
		{"id": 4, "art": "technogunner", "rang": 2, "name": "Rho", "beiname": "Brakkbrecher", "titel": "Brakks Bezwinger"},
		{"id": 5, "art": "technogunner", "rang": 1, "name": "Ivo", "beiname": "der Rest"},
	])
	var l := Nemesis.meistgesuchte()
	var pell := nach_name(l, "Pell")
	pruefe(str(pell.get("beiname", "")) == "der Entschärfer" and Nemesis.titel_text(pell) == "Unbelehrbar", "Tat aus der Chronik: %s" % Nemesis.name_mit_titel(pell))
	pruefe(Nemesis.name_mit_titel(pell) == "Hauptgefreiter Pell ‚der Entschärfer‘ · Unbelehrbar", "Anzeige mit Zusatztitel")
	pruefe(str(pell.get("tat", "")) == "ladung", "die Tat wird ab jetzt gemerkt")
	var vex := nach_name(l, "Vex")
	pruefe(str(vex.get("beiname", "")) == "der Pünktliche", "Vom Appell: alter Beiname zurück (%s)" % str(vex.get("beiname", "")))
	pruefe(Nemesis.hat_titel(vex, Nemesis.TITEL_BEZWINGER) and Nemesis.hat_titel(vex, Nemesis.TITEL_UNBELEHRBAR), "zwei Titel nebeneinander: %s" % Nemesis.titel_text(vex))
	var zed := nach_name(l, "Zed")
	pruefe(str(zed.get("beiname", "")) == "der Zähe" and Nemesis.titel_text(zed) == "Unbelehrbar", "Tat unbekannt: %s" % Nemesis.name_mit_titel(zed))
	var rho := nach_name(l, "Rho")
	pruefe(str(rho.get("beiname", "")) == "Brakkbrecher" and Nemesis.titel_text(rho) == "Brakks Bezwinger", "Brakkbrecher bleibt Beiname, der alte Titel bleibt")
	var ivo := nach_name(l, "Ivo")
	pruefe(Nemesis.titel_text(ivo) == "" and str(ivo.get("beiname", "")) == "der Rest", "ohne Titel bleibt alles")
	# zweimal laden ändert nichts mehr, und die Standardwerte werden nicht mitverändert
	schreibe(l)
	var l2 := Nemesis.meistgesuchte()
	pruefe(Nemesis.name_mit_titel(nach_name(l2, "Pell")) == Nemesis.name_mit_titel(pell) and Nemesis.titel_text(nach_name(l2, "Vex")) == Nemesis.titel_text(vex), "erneut geladen: unverändert")
	pruefe((Nemesis.FELDER["titel"] as Array).is_empty(), "Standardwert „titel“ bleibt leer")


## Punkt 5: Looks sind verschieden, bleiben über Laden und Speichern gleich und verändern wirklich das Blatt.
func _looks() -> void:
	var alt: Array = []
	for i in 6:
		alt.append({"id": i + 1, "art": ["technogunner", "scharfschuetze", "plasmawerfer"][i % 3], "rang": 1 + i % 3, "name": "N%d" % i, "beiname": "der Rest"})
	schreibe(alt)
	var a := Nemesis.meistgesuchte()
	var looks := {}
	var je_name := {}
	for p: Dictionary in a:
		looks[int(p["look"])] = true
		je_name[str(p["name"])] = int(p["look"])
	pruefe(looks.size() == 6 and looks.keys().all(func(x: int) -> bool: return x >= 0 and x < 10), "6 Personen, 6 verschiedene Looks %s" % str(looks.keys()))
	var b := Nemesis.meistgesuchte()
	pruefe(b.all(func(p: Dictionary) -> bool: return int(p["look"]) == int(je_name[str(p["name"])])), "zweimal geladen: gleiche Looks")
	a.reverse()
	schreibe(a)   # gespeichert, in anderer Reihenfolge
	pruefe(Nemesis.meistgesuchte().all(func(p: Dictionary) -> bool: return int(p["look"]) == int(je_name[str(p["name"])])), "gespeichert und neu geladen: gleiche Looks")
	var nem := Nemesis.new()
	var namenlos := nem.neue_person("technogunner")
	var neu := nem.neue_person("technogunner", 1, "Ziv", "der Rest")
	pruefe(int(namenlos["look"]) == -1 and int(neu["look"]) >= 0, "namenlos ohne Look, benannt mit Look")
	nem.free()
	var blatt: Texture2D = load("res://assets/neu/truppen/gun_s2.png")
	var original := blatt.get_image()
	var bilder: Array = []
	for look in 10:
		var t := NemesisLook.bild(blatt, 48, look)
		var img := t.get_image()
		var anders := 0
		for y in 48:
			for x in 48:
				if img.get_pixel(x, y) != original.get_pixel(x, y):
					anders += 1
		bilder.append(img.get_data())
		pruefe(t != blatt and t.get_size() == blatt.get_size() and anders >= 6, "Look %d verändert das Blatt (%d Punkte in der ersten Zelle)" % [look, anders])
		pruefe(NemesisLook.bild(blatt, 48, look) == t, "Look %d nur einmal gemalt" % look)
	var gleich := 0
	for i in bilder.size():
		for j in range(i + 1, bilder.size()):
			if bilder[i] == bilder[j]:
				gleich += 1
	pruefe(gleich == 0, "alle 10 Looks sehen verschieden aus")
	pruefe(NemesisLook.bild(blatt, 48, -1) == blatt, "ohne Look bleibt das Blatt")
