extends SceneTree
## 25.11.: Drei Plätze je Art im Pool – außer für Pauls Profil (nach ID, nicht nach Namen). Das Netz ist eine
## Attrappe, es geht nichts hinaus; das Profil wird nicht geschrieben.
##   godot --headless --path . -s werkzeuge/platztest.gd
const PAUL := "c11363a30947257b"
const FREMD := "0123456789abcdef"

var fehler: Array[String] = []
var spiel: Node
var rufe: Array = []          # Namen in Reihenfolge
var archiviert: Array = []    # IDs, die ins Archiv sollten
var eigene_anzahl := 0

func pruefe(ok: bool, text: String) -> void:
	print("%s %s" % ["OK  " if ok else "FEHL", text])
	if not ok:
		fehler.append(text)

func _netz(_m: int, pfad: String, koerper: Variant) -> Array:
	var name := pfad.get_slice("?", 0).get_file()
	if name == "phantome" and pfad.contains("profil="):
		name = "eigene"
	rufe.append(name)
	match name:
		"eigene":
			var l: Array = []
			for i in eigene_anzahl:
				l.append({"id": "e%d" % i, "elo": 900 + i, "spiele": i, "erstellt": "2026-11-24T10:00:00"})
			return [HTTPRequest.RESULT_SUCCESS, 200, JSON.stringify(l)]
		"phantom_hochladen":
			return [HTTPRequest.RESULT_SUCCESS, 200, "\"99999999-9999-9999-9999-999999999999\""]
		"phantom_archivieren":
			archiviert.append(str(koerper["p_id"]))
			return [HTTPRequest.RESULT_SUCCESS, 200, "true"]
	return [HTTPRequest.RESULT_SUCCESS, 200, "[]"]

## Wer spielt, und wie viele Phantome je Art stehen schon im Pool?
func _als(id: String, anzahl: int) -> void:
	Profil._lade()
	Profil._d["id"] = id
	Profil._d["name"] = "APAAtROXOP"   # alle heißen gleich – nur die ID darf zählen
	eigene_anzahl = anzahl
	rufe = []
	archiviert = []

func _daten() -> Dictionary:
	return {"art": "angriff", "spieler": "APAAtROXOP", "runden": [], "ergebnis": {"wertung": 100}}

func _warte(m: Dictionary) -> void:
	var bilder := 0
	while str(m["status"]) in ["offen", "laeuft"] and bilder < 600:
		await process_frame
		bilder += 1

## Ende einer Partie wie im Spiel: Angriff bzw. Bau über main.gd melden.
func _partie_ende(art: String) -> Dictionary:
	spiel._meld_job = {}
	if art == "angriff":
		spiel._angriff_online("user://angriff-platz.json", _daten(), 100)
	else:
		spiel._verteidigung_online("user://verteidigung-platz.json", {"art": "verteidigung", "spieler": "APAAtROXOP"})
	return spiel._meld_job

func _bilder(n: int) -> void:
	for i in n:
		await process_frame

func _initialize() -> void:
	_los()

func _los() -> void:
	Profil.nur_lesen = true
	Online.attrappe = _netz
	var main: GDScript = load("res://scripts/main.gd")
	main.ohne_spuren = true
	spiel = load("res://main.tscn").instantiate()
	root.add_child(spiel)
	await _bilder(10)
	spiel._normales_spiel()

	# 1) Pauls Profil mit vollen und übervollen Plätzen: hochladen ohne Tafel, nichts ins Archiv
	for art: String in ["angriff", "verteidigung"]:
		for anzahl: int in [3, 11]:
			_als(PAUL, anzahl)
			var job := _partie_ende(art)
			await _bilder(5)
			var tafel: bool = spiel._bestaetigung.visible
			await _warte(job)
			pruefe(not tafel and rufe.count("phantom_hochladen") == 1 and archiviert.is_empty() and not rufe.has("phantom_archivieren"),
				"Paul, %s, %d im Pool: hochgeladen, keine Tafel, nichts archiviert (%s)" % [art, anzahl, str(rufe)])

	# 2) Pauls Profil, Szene vor der Entscheidung verlassen („auto“)
	_als(PAUL, 5)
	var m := Online.neue_angriffs_meldung("user://angriff-auto.json", _daten(), 100)
	Online.freigeben(m)
	await _warte(m)
	pruefe(m["status"] == "fertig" and rufe.count("phantom_hochladen") == 1 and archiviert.is_empty(), "Paul, Szene verlassen: trotzdem hochgeladen (%s)" % str(rufe))

	# 3) gleicher Name, andere ID: die Grenze gilt – Tafel, „Behalten“ lädt nicht hoch
	_als(FREMD, 3)
	pruefe(not Online.ohne_platzgrenze(), "gleicher Name reicht nicht")
	var job2 := _partie_ende("angriff")
	await _bilder(5)
	pruefe(spiel._bestaetigung.visible and not rufe.has("phantom_hochladen"), "andere ID, 3 im Pool: Tafel „Plätze voll“, noch kein Upload")
	spiel._platz_wahl = ""
	spiel._bestaetigung.visible = false
	await _warte(job2)
	pruefe(not rufe.has("phantom_hochladen") and archiviert.is_empty(), "Behalten: kein Upload, nichts archiviert (%s)" % str(rufe))

	# 4) andere ID, „Ersetze“: das gewählte weicht, dann der Upload
	_als(FREMD, 3)
	var job3 := _partie_ende("verteidigung")
	await _bilder(5)
	spiel._platz_wahl = "e0"
	spiel._bestaetigung.visible = false
	await _warte(job3)
	pruefe(archiviert == ["e0"] and rufe.find("phantom_archivieren") < rufe.find("phantom_hochladen"), "Ersetzen: erst archivieren, dann hochladen (%s)" % str(rufe))

	# 5) andere ID, Szene verlassen bei vollen Plätzen / mit freiem Platz
	_als(FREMD, 3)
	m = Online.neue_angriffs_meldung("user://angriff-voll.json", _daten(), 100)
	Online.freigeben(m)
	await _warte(m)
	pruefe(not rufe.has("phantom_hochladen"), "andere ID, auto, voll: kein Upload (%s)" % str(rufe))
	_als(FREMD, 2)
	var job4 := _partie_ende("angriff")
	await _warte(job4)
	pruefe(rufe.count("phantom_hochladen") == 1 and archiviert.is_empty() and not spiel._bestaetigung.visible, "andere ID mit freiem Platz: wie bisher (%s)" % str(rufe))

	Online.attrappe = Callable()
	print("TEST PLATZ OK" if fehler.is_empty() else "TEST PLATZ FEHLER: %s" % ", ".join(fehler))
	quit(0 if fehler.is_empty() else 1)
