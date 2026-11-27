extends SceneTree
## 25.11.: Runde 20 im Phantom-Modus – erst die Welle, dann der Sturm; ohne Fortschritt nach 60 s Echtzeit Patt.
## Geprüft für Angreifer und Verteidiger: Endtafel, gemeldetes Duell- und Spieler-Ergebnis („nicht geknackt“).
## Das Netz ist eine Attrappe, es geht nichts hinaus.
##   godot --headless --path . -s werkzeuge/patttest.gd
const VID := "11111111-1111-1111-1111-111111111111"
const AID := "22222222-2222-2222-2222-222222222222"

var fehler: Array[String] = []
var spiel: Node
var rufe: Array = []

func pruefe(ok: bool, text: String) -> void:
	print("%s %s" % ["OK  " if ok else "FEHL", text])
	if not ok:
		fehler.append(text)

func _netz(_m: int, pfad: String, koerper: Variant) -> Array:
	var name := pfad.get_slice("?", 0).get_file()
	rufe.append([name, koerper])
	if name == "phantome" and pfad.contains("datei="):
		return [HTTPRequest.RESULT_SUCCESS, 200, "[{\"id\":\"%s\",\"profil\":\"pool\"}]" % VID]
	if name == "phantom_hochladen":
		return [HTTPRequest.RESULT_SUCCESS, 200, "\"99999999-9999-9999-9999-999999999999\""]
	return [HTTPRequest.RESULT_SUCCESS, 200, "[]"]

func _ruf(name: String) -> Dictionary:
	for r: Array in rufe:
		if r[0] == name:
			return r[1]
	return {}

func _neues_spiel() -> void:
	if spiel != null:
		spiel.queue_free()
		await process_frame
	spiel = load("res://main.tscn").instantiate()
	root.add_child(spiel)
	for i in 10:
		await process_frame

## Nur der Test dreht an der Uhr: das Spiel selbst steht still.
func _anhalten() -> void:
	spiel.process_mode = Node.PROCESS_MODE_DISABLED

func _welle_abwehren() -> void:
	for g in spiel.gegner:
		g.queue_free()
	spiel.gegner.clear()
	spiel._schlange.clear()
	spiel._welle_geschafft()

func _sekunden(n: int) -> void:
	for i in n:
		spiel._patt_tick(1.0)

func _angreifer_dateien() -> Array:
	var d := DirAccess.open("res://Phantom Dateien/Angreifer")
	return Array(d.get_files()) if d != null else []

func _initialize() -> void:
	_los()

func _los() -> void:
	Online.attrappe = _netz
	Profil.setze_einstellung("pe_taktik", true)
	Profil.setze_einstellung("pe_verteidigung", true)
	var main: GDScript = load("res://scripts/main.gd")
	main.ohne_spuren = true
	var vorher := _angreifer_dateien()

	# ---------------- Angreifer
	await _neues_spiel()
	var bau := ""
	for f: Dictionary in Phantom.liste("verteidigung"):
		if (Phantom.lade(f["pfad"])["runden"] as Array).size() >= 20:
			bau = f["pfad"]
			break
	spiel.phantom_partie.starte_angriff(bau)
	spiel._setze_runde(20)
	spiel.phantom_partie.lade_stand()
	spiel.phantom_partie.zeige_laufband()
	spiel._laufband._vorlage()
	spiel.starte_welle()
	_anhalten()
	pruefe(spiel.phase == 1 and not spiel.endkampf and spiel.karte.schild, "Angreifer: Runde 20 beginnt mit der Welle, Schild steht")
	pruefe(not spiel.patt_aktiv(), "keine Patt-Uhr während der ersten Welle")
	spiel.leben -= 3
	_welle_abwehren()
	pruefe(spiel.endkampf and not spiel.karte.schild and spiel.phase == 1, "erst nach der Welle: Gegenangriff aufs HQ")
	pruefe(spiel.patt_aktiv() and is_equal_approx(spiel.patt_rest(), 60.0), "Patt-Uhr startet bei 60 s")
	_sekunden(44)
	pruefe(spiel.patt_rest() > Phantom.PATT_WARNUNG_SEK, "nach 44 s noch kein Countdown")
	_sekunden(1)
	pruefe(is_equal_approx(spiel.patt_rest(), 15.0), "ab 45 s Countdown (Rest %.0f)" % spiel.patt_rest())
	spiel.hq.leben -= 5.0
	_sekunden(1)
	pruefe(is_equal_approx(spiel.patt_rest(), 60.0), "Treffer am HQ stellt die Uhr zurück")
	_sekunden(30)
	spiel.leben -= 1
	_sekunden(1)
	pruefe(is_equal_approx(spiel.patt_rest(), 60.0), "genommenes Leben stellt die Uhr zurück")
	var tempo := Engine.time_scale
	Engine.time_scale = 3.0
	spiel._process(0.3)   # 0,3 s Spielzeit bei Tempo ×3 = 0,1 s Echtzeit
	pruefe(is_equal_approx(spiel.patt_rest(), 59.9), "Echtzeit, unabhängig vom Tempo (Rest %.2f)" % spiel.patt_rest())
	Engine.time_scale = tempo
	rufe.clear()
	_sekunden(61)
	pruefe(spiel.phase == 2 and spiel.patt, "nach 60 s ohne Fortschritt ist Schluss")
	var conf: Dictionary = spiel._tafel.conf
	pruefe(str(conf.get("titel")) == "RUNDE 20 GEHALTEN" and (conf.get("zeilen", []) as Array).has("Patt – Verteidigung hat gehalten"), "Endtafel: %s / %s" % [conf.get("titel"), str(conf.get("zeilen"))])
	var letzte: Dictionary = spiel.phantom_partie.angriff_log.back()
	pruefe(int(letzte["runde"]) == 20 and not letzte["geknackt"], "Runde 20 gebucht als nicht geknackt")
	var genommen := 0
	for e: Dictionary in spiel.phantom_partie.angriff_log:
		genommen += int(e["leben_genommen"])
	spiel.process_mode = Node.PROCESS_MODE_INHERIT
	for i in 60:
		await process_frame
	var duell := _ruf("duell_melden")
	var lauf := _ruf("angriff_lauf_melden")
	pruefe(genommen == 4 and not duell.is_empty() and is_equal_approx(float(duell["p_ergebnis"]), Phantom.duell_ergebnis(4, false, 0, 1)), "Phantom-Duell: nicht geknackt (%s)" % str(duell.get("p_ergebnis")))
	pruefe(not lauf.is_empty() and is_equal_approx(float(lauf["p_duelle"][0]["s"]), 0.7 * 4.0 / 15.0), "Spieler-Ergebnis 0,7 × 4/15 (%s)" % str(lauf.get("p_duelle")))
	for datei: String in _angreifer_dateien():
		if not vorher.has(datei):
			DirAccess.remove_absolute(ProjectSettings.globalize_path("res://Phantom Dateien/Angreifer/" + datei))

	# ---------------- Verteidiger gegen ein Angriffs-Phantom
	await _neues_spiel()
	var runden: Array = []
	for nr in range(1, 21):
		runden.append({"runde": nr, "trupps": [{"weg": "l", "typen": ["hund", "hund"]}]})
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(Online.CACHE + "/angriff"))
	var pfad := Online.CACHE + "/angriff/" + AID + ".json"
	var f := FileAccess.open(pfad, FileAccess.WRITE)
	f.store_string(JSON.stringify({"art": "angriff", "spieler": "Testgegner", "phantom_version": Phantom.PHANTOM_VERSION, "runden": runden}))
	f.close()
	spiel.phantom_partie.starte_verteidigung(pfad)
	spiel._setze_runde(20)
	spiel.starte_welle(true)
	_anhalten()
	pruefe(spiel.phase == 1 and not spiel.endkampf and spiel.karte.schild, "Verteidiger: Runde 20 beginnt mit der Welle")
	spiel.leben = Werte.START_LEBEN - 3
	_welle_abwehren()
	pruefe(spiel.endkampf and spiel.patt_aktiv(), "Verteidiger: Gegenangriff mit Patt-Uhr")
	rufe.clear()
	_sekunden(61)
	conf = spiel._tafel.conf
	pruefe(spiel.phase == 2 and spiel.ausgang == "sieg", "Verteidiger hat gehalten")
	pruefe(str(conf.get("titel")) == "RUNDE 20 GEHALTEN" and (conf.get("zeilen", []) as Array).has("Patt – Verteidigung hat gehalten"), "Endtafel: %s / %s" % [conf.get("titel"), str(conf.get("zeilen"))])
	var wertung := str((conf.get("zeilen", []) as Array)[1])
	pruefe(wertung.contains("20 Runden gehalten") and not wertung.contains("Sieg:"), "zählt als 20 Runden, ohne Bonus fürs HQ: %s" % wertung)
	spiel.process_mode = Node.PROCESS_MODE_INHERIT
	for i in 60:
		await process_frame
	duell = _ruf("duell_melden")
	pruefe(not duell.is_empty() and duell["p_angriff"] == AID and duell["p_mensch"] == "verteidigung"
		and is_equal_approx(float(duell["p_ergebnis"]), Phantom.duell_ergebnis(3, false, 20)) and float(duell["p_ergebnis"]) < Phantom.DUELL_SIEG_AB,
		"Duell: Angriffs-Phantom nicht geknackt (%s)" % str(duell.get("p_ergebnis")))

	# ---------------- Normalspiel: keine Patt-Regel
	await _neues_spiel()
	spiel._normales_spiel()
	spiel.endkampf = true
	spiel.welle = 20
	spiel.phase = 1
	pruefe(not spiel.patt_aktiv(), "im Normalspiel gibt es kein Patt")

	Online.attrappe = Callable()
	print("TEST PATT OK" if fehler.is_empty() else "TEST PATT FEHLER: %s" % ", ".join(fehler))
	quit(0 if fehler.is_empty() else 1)
