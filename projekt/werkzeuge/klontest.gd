extends SceneTree
## 25.11. (N2): Klonmaschine mit Abklingzeit (nur außerhalb des Brakk-Modes) und Klone im Truppenlimit.
##
##   godot --headless --path . --fixed-fps 60 -s werkzeuge/klontest.gd
##
##   1. Normalspiel: in Runde 3 gesetzt → Runde 4 und 5 gesperrt mit Restanzeige, Runde 6 frei
##   2. Fortsetzen: die Sperre übersteht das Neuladen
##   3. Welle: Klone zählen zum Truppenlimit ihrer Fabrik, erst darunter kommt Ersatz
##   4. Brakk-Mode: wie bisher (jede Runde frei, Klone zählen nicht mit)
## Am Ende „TEST KLON OK“ oder die Fehler. Schreibt Zwischenstand und Profil (user://) – eigenen Benutzerordner nehmen.

const KOMMANDANT := Karte.KOMMANDANT

var spiel: Node
var warte := 20
var schritt := 0
var bilder := 0
var fehler: Array[String] = []
var fab := Karte.KEINE
var echte: Array = []


func _initialize() -> void:
	BrakkTutorial.erzwingen = false
	_neues_spiel("normal")


func _neues_spiel(start: String) -> void:
	if spiel != null:
		root.remove_child(spiel)
		spiel.queue_free()
	var main_skript: GDScript = load("res://scripts/main.gd")
	main_skript.set("naechster_start", start)
	spiel = load("res://main.tscn").instantiate()
	root.add_child(spiel)
	spiel.protokoll_an = false
	warte = 20


func pruefe(ok: bool, text: String) -> void:
	print("%s %s" % ["OK  " if ok else "FEHL", text])
	if not ok:
		fehler.append(text)


func _ende() -> void:
	print("TEST KLON OK" if fehler.is_empty() else "TEST KLON FEHLER: %s" % ", ".join(fehler))
	quit(0 if fehler.is_empty() else 1)


func _frei(typ: int) -> Vector2i:
	for x in range(Werte.ZONE_SPALTEN + 5, Werte.SPALTEN - 2):
		for y in range(1, Werte.ZEILEN - 1):
			var z := Vector2i(x, y)
			if spiel.bau_hindernis(z, typ) == "" and not spiel.karte.checkpoints.has(z):
				return z
	return Karte.KEINE


func _kachel() -> String:
	spiel._hud._aktualisiere_kacheln()
	return str(spiel._hud.kacheln[KOMMANDANT].preis)


## Truppen der Fabrik, die gerade in ihrer Liste stehen (so zählt die Produktion).
func _liste() -> Array:
	return spiel.fabriken[fab]["einheiten"]


func _process(_delta: float) -> bool:
	if warte > 0:
		warte -= 1
		return false
	var jetzt := schritt
	schritt += 1   # wer noch warten muss, zählt wieder zurück
	match jetzt:
		0: _abklingzeit()
		1: _fortsetzen()
		2: _welle_start()
		3: _warte_auf_truppen()
		4: _geklont()
		5: _nach_zwei_verlusten()
		6: _brakk()
		7: _ende()
	return false


func _abklingzeit() -> void:
	spiel.budget = 5000
	spiel._naechste_bauphase()
	spiel._naechste_bauphase()
	pruefe(spiel.welle == 3 and not spiel.brakk_modus, "Normalspiel, Runde %d" % spiel.welle)
	spiel.budget = 5000
	pruefe(spiel.baue(_frei(KOMMANDANT), KOMMANDANT, true) and spiel.kommandant != null, "Brakk gekauft")
	var k: Kommandant = spiel.kommandant
	pruefe(not k.klon_genutzt and k.klon_anzeige() == "" and _kachel() == "im Feld", "Runde 3: bereit")
	var platz := _frei(Karte.WALL)
	pruefe(str(spiel.stelle_klonmaschine(platz)).begins_with("Klonmaschine steht"), "Runde 3: Klonmaschine gesetzt")
	pruefe(k.klon_rest == Werte.KLON_ABKLINGZEIT_RUNDEN and str(spiel.stelle_klonmaschine(platz)) == "Die Klonmaschine lädt noch: bereit in 3 Runden.", "Runde 3: zweiter Einsatz gesperrt (3 Runden)")
	spiel._naechste_bauphase()
	pruefe(spiel.welle == 4 and spiel.klonmaschine == null, "Runde 4: die Maschine ist abgebaut")
	pruefe(str(spiel.stelle_klonmaschine(platz)) == "Die Klonmaschine lädt noch: bereit in 2 Runden.", "Runde 4: gesperrt, bereit in 2 Runden")
	pruefe(k.klon_anzeige() == "R · in 2 Runden" and _kachel() == "R in 2", "Runde 4: Anzeige „%s“, Kachel „%s“" % [k.klon_anzeige(), _kachel()])
	pruefe(str(spiel._werkzeug_tipp(KOMMANDANT)).contains("Klonmaschine (R · in 2 Runden)"), "Runde 4: Hilfetext nennt den Rest")


func _fortsetzen() -> void:
	if bilder == 0:
		# Runde 4 ist gesichert (Bauphase) – neu laden wie nach „Fortsetzen“ im Startmenü
		bilder = 1
		_neues_spiel("fortsetzen")
		schritt -= 1
		return
	bilder = 0
	var k: Kommandant = spiel.kommandant
	pruefe(k != null and spiel.welle == 4, "Fortgesetzt: Runde %d mit Brakk" % spiel.welle)
	pruefe(k != null and k.klon_rest == 2, "Fortgesetzt: Sperre bleibt (Rest %d)" % (k.klon_rest if k != null else -1))
	spiel._naechste_bauphase()
	pruefe(spiel.welle == 5 and str(spiel.stelle_klonmaschine(_frei(Karte.WALL))) == "Die Klonmaschine lädt noch: bereit in 1 Runde.", "Runde 5: gesperrt, bereit in 1 Runde")
	pruefe(k.klon_anzeige() == "R · in 1 Runde" and _kachel() == "R in 1", "Runde 5: Anzeige „%s“" % k.klon_anzeige())
	spiel._naechste_bauphase()
	pruefe(spiel.welle == 6 and not k.klon_genutzt and k.klon_anzeige() == "" and _kachel() == "im Feld", "Runde 6: wieder frei")
	pruefe(not str(spiel._werkzeug_tipp(KOMMANDANT)).contains("R · in"), "Runde 6: Hilfetext ohne Rest")


func _welle_start() -> void:
	spiel.budget = 5000
	fab = _frei(Karte.FABRIK)
	pruefe(spiel.baue(fab, Karte.FABRIK, true), "Fabrik gebaut")
	spiel.starte_welle()
	spiel._spawn_in = 1.0e9   # keine Gegner: die Welle läuft, solange die Schlange voll ist
	spiel._wurf_schlange = []
	pruefe(spiel.phase == 1, "Welle läuft")
	bilder = 0


func _warte_auf_truppen() -> void:
	spiel._spawn_in = 1.0e9
	bilder += 1
	var limit: int = spiel.truppen_limit(fab)
	if _liste().size() < limit and bilder < 4000:
		schritt -= 1
		return
	echte = _liste().duplicate()
	pruefe(echte.size() == limit and limit >= 2, "Fabrik voll: %d von %d" % [echte.size(), limit])
	# die echte Klonmaschine auf das Feld einer Truppe am Boden; sie klont beim nächsten Schritt alle dort
	spiel.kommandant.klon_genutzt = false
	var ziel: Einheit = null
	for e: Einheit in echte:
		if e.am_boden() and spiel.karte.ist_begehbar(spiel.karte.zelle_bei(e.position)):
			ziel = e
			break
	if ziel == null:
		if bilder < 4000:
			schritt -= 1
		else:
			pruefe(false, "keine Truppe am Boden gefunden")
		return
	if str(spiel.stelle_klonmaschine(spiel.karte.zelle_bei(ziel.position))).begins_with("Klonmaschine steht"):
		warte = 3
	else:
		schritt -= 1
		return
	bilder = 0


func _geklont() -> void:
	spiel._spawn_in = 1.0e9
	var limit: int = spiel.truppen_limit(fab)
	var klone: Array = _liste().filter(func(e: Einheit) -> bool: return e.klon)
	if bilder == 0:
		pruefe(klone.size() >= 1 and _liste().size() == limit + klone.size(), "Klon zählt zur Fabrik: %d Truppen, davon %d Klone, Limit %d" % [_liste().size(), klone.size(), limit])
		spiel.klonmaschine.queue_free()
		spiel.klonmaschine = null
		# eine echte Truppe fällt: die Fabrik bleibt am Limit oder darüber
		(echte[0] as Einheit).nimm_schaden(1.0e9)
		echte.remove_at(0)
	bilder += 1
	if bilder < int(Werte.PRODUKTION_SEK * 3.0 * 60.0):
		schritt -= 1
		return
	pruefe(_liste().filter(func(e: Einheit) -> bool: return is_instance_valid(e) and not e.klon and not echte.has(e)).is_empty(), "solange der Klon lebt und die Fabrik voll ist: kein Ersatz (%d/%d)" % [_liste().size(), limit])
	for e: Einheit in echte:
		if is_instance_valid(e):
			e.nimm_schaden(1.0e9)
	echte = _liste().duplicate()
	bilder = 0


func _nach_zwei_verlusten() -> void:
	spiel._spawn_in = 1.0e9
	var limit: int = spiel.truppen_limit(fab)
	bilder += 1
	if _liste().size() < limit and bilder < 4000:
		schritt -= 1
		return
	var neue: Array = _liste().filter(func(e: Einheit) -> bool: return not echte.has(e))
	pruefe(_liste().size() == limit and not neue.is_empty(), "unter dem Limit baut die Fabrik wieder auf: %d/%d" % [_liste().size(), limit])
	_neues_spiel("brakk")
	bilder = 0


func _brakk() -> void:
	var k: Kommandant = spiel.kommandant
	pruefe(spiel.brakk_modus and k != null, "Brakk-Mode mit Brakk")
	var platz := _frei(Karte.WALL)
	spiel.stelle_klonmaschine(platz)
	pruefe(k.klon_genutzt and str(spiel.stelle_klonmaschine(platz)) == "Die Klonmaschine gibt es nur einmal pro Runde.", "Brakk-Mode: Meldung wie bisher")
	pruefe(k.klon_anzeige() == "", "Brakk-Mode: keine Restanzeige")
	k.klon_genutzt = false   # so macht es das Brakk-Tutorial
	pruefe(k.klon_rest == 0, "klon_genutzt = false gibt sofort frei")
	k.klon_genutzt = true
	spiel._naechste_bauphase()
	pruefe(not k.klon_genutzt, "Brakk-Mode: nach einer Runde wieder frei")
	var z := _frei(Karte.FABRIK)
	spiel.budget = 5000
	if spiel.baue(z, Karte.FABRIK, true):
		var e := Einheit.new()
		spiel.figuren.add_child(e)
		e.start(spiel, spiel.karte, spiel.fabriken[z]["typ"], z)
		spiel.einheiten.append(e)
		(spiel.fabriken[z]["einheiten"] as Array).append(e)
		spiel.klone_einheit(e)
		pruefe((spiel.fabriken[z]["einheiten"] as Array).size() == 1, "Brakk-Mode: Klone zählen nicht mit")
	else:
		pruefe(false, "Brakk-Mode: Fabrik für die Klonprobe gebaut")
