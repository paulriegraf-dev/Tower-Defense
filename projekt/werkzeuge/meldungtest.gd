extends SceneTree
## 25.11.: Prüft die Online-Warteschlange mit einer Attrappe statt des Netzes (nichts geht hinaus): Reihenfolge,
## Ausfall und erneutes Senden ohne Doppel, gleiche Lauf-Nummer, Upload nur in freie Plätze, ID nach Neuladen.
##   godot --headless --path . -s werkzeuge/meldungtest.gd
const VID := "11111111-1111-1111-1111-111111111111"

var fehler: Array[String] = []
var rufe: Array = []          # [Name, Körper]
var ausfall: Array = []       # Namen, die gerade nicht ankommen
var abgelehnt: Array = []     # Namen, die die Datenbank ablehnt (400)
var eigene_anzahl := 0

func pruefe(ok: bool, text: String) -> void:
	print("%s %s" % ["OK  " if ok else "FEHL", text])
	if not ok:
		fehler.append(text)

func _netz(_methode: int, pfad: String, koerper: Variant) -> Array:
	var name := pfad.get_slice("?", 0).get_file()
	if name == "phantome" and pfad.contains("datei="):
		name = "id_suche"
	elif name == "phantome" and pfad.contains("profil="):
		name = "eigene"
	rufe.append([name, koerper])
	if ausfall.has(name):
		return [HTTPRequest.RESULT_CANT_CONNECT, 0, ""]
	if abgelehnt.has(name):
		return [HTTPRequest.RESULT_SUCCESS, 400, "{\"message\":\"nein\"}"]
	match name:
		"spieler_elo":
			return [HTTPRequest.RESULT_SUCCESS, 200, "[{\"elo\":1000,\"spiele\":0}]"]
		"eigene":
			var l: Array = []
			for i in eigene_anzahl:
				l.append({"id": "e%d" % i})
			return [HTTPRequest.RESULT_SUCCESS, 200, JSON.stringify(l)]
		"phantom_hochladen":
			return [HTTPRequest.RESULT_SUCCESS, 200, "\"99999999-9999-9999-9999-999999999999\""]
		"id_suche":
			return [HTTPRequest.RESULT_SUCCESS, 200, "[{\"id\":\"%s\",\"profil\":\"pool\"}]" % VID]
		"duell_melden":
			return [HTTPRequest.RESULT_SUCCESS, 204, ""]
		"angriff_lauf_melden":
			return [HTTPRequest.RESULT_SUCCESS, 200, "null"]   # „kam schon an“ zählt als angekommen
	return [HTTPRequest.RESULT_SUCCESS, 200, "[]"]

func _namen() -> Array:
	return rufe.map(func(r: Array) -> String: return r[0])

func _warte(m: Dictionary) -> void:
	var bilder := 0
	while str(m["status"]) in ["offen", "laeuft"] and bilder < 600:
		await process_frame
		bilder += 1

func _lauf_daten(pfad: String) -> Dictionary:
	var runden: Array = []
	for r in range(1, 21):
		runden.append({"runde": r, "gegen_pfad": pfad, "leben_genommen": 1, "geknackt": false})
	return {"art": "angriff", "spieler": "Test", "runden": runden, "ergebnis": {"wertung": 100}}

func _initialize() -> void:
	_los()

func _los() -> void:
	await process_frame
	Online.attrappe = _netz
	var bau := "res://Phantom Dateien/Verteidiger/verteidigung-20261117-123537.json"

	# 1) alles kommt an; eingebautes Phantom ohne bekannte ID wird nachgeschlagen
	Online.pfad_id = {}
	rufe.clear()
	var m := Online.neue_angriffs_meldung("user://angriff-a.json", _lauf_daten(bau), 100)
	Online.entscheide(m, true)
	await _warte(m)
	pruefe(m["status"] == "fertig" and Online.meldungen.is_empty(), "alles angekommen: fertig, Warteschlange leer")
	pruefe(_namen() == ["spieler_elo", "phantom_hochladen", "id_suche", "duell_melden", "angriff_lauf_melden"], "Reihenfolge: %s" % str(_namen()))
	pruefe(str(rufe[3][1]["p_angriff"]).begins_with("9999") and rufe[3][1]["p_verteidigung"] == VID, "Duell nennt eigenes und gegnerisches Phantom")

	# 2) das Lauf-Update kommt nicht an: erneut senden schickt nur dieses, mit derselben Lauf-Nummer
	rufe.clear()
	ausfall = ["angriff_lauf_melden"]
	m = Online.neue_angriffs_meldung("user://angriff-b.json", _lauf_daten(bau), 100)
	Online.entscheide(m, true)
	await _warte(m)
	pruefe(m["status"] == "fehler" and Online.meldungen.size() == 1, "Ausfall: Status Fehler, Lauf bleibt gespeichert")
	var nummer: String = rufe.back()[1]["p_lauf"]
	rufe.clear()
	ausfall = []
	Online.erneut()
	await _warte(m)
	pruefe(m["status"] == "fertig", "erneut: angekommen")
	pruefe(_namen() == ["angriff_lauf_melden"], "erneut nur das Offene (kein zweites Duell): %s" % str(_namen()))
	pruefe(str(rufe[0][1]["p_lauf"]) == nummer, "Lauf-Nummer bleibt gleich")

	# 3) gar keine Verbindung: nichts geht verloren, später kommt alles
	rufe.clear()
	ausfall = ["spieler_elo", "phantom_hochladen", "duell_melden", "angriff_lauf_melden", "id_suche"]
	m = Online.neue_angriffs_meldung("user://angriff-c.json", _lauf_daten(bau), 100)
	Online.entscheide(m, true)
	await _warte(m)
	pruefe(m["status"] == "fehler" and not m["hochgeladen"], "ohne Netz: Fehler, Upload noch offen")
	rufe.clear()
	ausfall = []
	Online.erneut()
	await _warte(m)
	pruefe(m["status"] == "fertig" and _namen().has("phantom_hochladen") and _namen().count("duell_melden") == 1 and _namen().count("angriff_lauf_melden") == 1, "mit Netz: Upload, Duell und Lauf je einmal: %s" % str(_namen()))

	# 4) Szene verlassen, bevor über den Upload entschieden ist: alle Plätze voll -> nicht hochladen, trotzdem melden
	rufe.clear()
	eigene_anzahl = Online.PLAETZE
	m = Online.neue_angriffs_meldung("user://angriff-d.json", _lauf_daten(bau), 100)
	Online.sende()
	await process_frame
	pruefe(m["status"] == "offen" and rufe.is_empty(), "wartet auf die Entscheidung über den Platz")
	Online.freigeben(m)
	await _warte(m)
	pruefe(m["status"] == "fertig" and not _namen().has("phantom_hochladen") and _namen().has("duell_melden") and _namen().has("angriff_lauf_melden"), "freigegeben bei vollen Plätzen: %s" % str(_namen()))
	pruefe(rufe[rufe.size() - 2][1]["p_angriff"] == null, "Duell ohne eigenes Phantom")
	eigene_anzahl = 0

	# 5) abgelehnt (400): Schritt auslassen, nichts hängt fest
	rufe.clear()
	abgelehnt = ["duell_melden"]
	m = Online.neue_angriffs_meldung("user://angriff-e.json", _lauf_daten(bau), 100)
	Online.entscheide(m, false)
	await _warte(m)
	pruefe(m["status"] == "fertig" and _namen().count("duell_melden") == 1 and _namen().has("angriff_lauf_melden"), "abgelehntes Duell blockiert nicht: %s" % str(_namen()))
	abgelehnt = []

	# 6) Verteidigung, fortgesetzt nach Neuladen: ID steckt im Dateinamen des Zwischenspeichers
	rufe.clear()
	Online.pfad_id = {}
	var cache := Online.CACHE + "/angriff/22222222-2222-2222-2222-222222222222.json"
	m = Online.neue_verteidigungs_meldung("", {}, cache, 0.4, true)
	Online.entscheide(m, false)
	await _warte(m)
	pruefe(m["status"] == "fertig" and _namen() == ["spieler_elo", "duell_melden"], "Verteidigung: nur Duell: %s" % str(_namen()))
	pruefe(rufe[1][1]["p_angriff"] == "22222222-2222-2222-2222-222222222222" and rufe[1][1]["p_mensch"] == "verteidigung", "Gegner-ID aus dem Zwischenspeicher")

	# 7) Abbruch mitten im Angriff läuft über dieselbe Warteschlange
	rufe.clear()
	Online.angriff_abgebrochen(VID)
	for i in 30:
		await process_frame
	pruefe(_namen() == ["duell_melden", "angriff_lauf_melden"] and Online.meldungen.is_empty(), "Abbruch: %s" % str(_namen()))

	Online.attrappe = Callable()
	print("TEST MELDUNG OK" if fehler.is_empty() else "TEST MELDUNG FEHLER: %s" % ", ".join(fehler))
	quit(0 if fehler.is_empty() else 1)
