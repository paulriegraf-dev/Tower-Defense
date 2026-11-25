extends SceneTree
## 25.11. (N6): Belagerungsturm, Phase 2 „Vorstoß“.
##
##   godot --headless --path . --fixed-fps 60 -s werkzeuge/belagerungtest.gd
##
##   1. dockt an einem Erdwall an; nach BELAGERUNG_SEK rückt er vor: Leben Rest + 25 % (höchstens 125 %), Nahkampfwerte,
##      keine Drohnen mehr; die gemeinsamen Gegnerwerte bleiben unberührt; Würfe und Aufräumen warten nicht auf ihn
##   2. er läuft, schlägt eine Truppe im Nahkampf und kostet an der Basis ein Leben
##   3. fällt sein Wall und gibt es kein neues Dock, rückt er ebenfalls vor
##   4. Brakk-Mode: zerfällt wie bisher
##   5. Runde 20: der Gegenangriff läuft über Durchgang 3 (zwei Belagerungstürme) hinaus weiter
## Am Ende „TEST BELAGERUNG OK“ oder die Fehler. Eigenen Benutzerordner nehmen.

var spiel: Node
var warte := 20
var schritt := 0
var bilder := 0
var fehler: Array[String] = []
var turm: Gegner
var truppe: Einheit
var merk := {}
var tuerme_r20 := {}


func _initialize() -> void:
	BrakkTutorial.erzwingen = false
	_neues_spiel("sandbox")


func _neues_spiel(start: String) -> void:
	if spiel != null:
		root.remove_child(spiel)
		spiel.queue_free()
	Zufall.gewuenscht = 4711
	var main_skript: GDScript = load("res://scripts/main.gd")
	main_skript.set("ohne_spuren", true)
	main_skript.set("naechster_start", start)
	spiel = load("res://main.tscn").instantiate()
	root.add_child(spiel)
	spiel.protokoll_an = false
	warte = 20
	bilder = 0


func pruefe(ok: bool, text: String) -> void:
	print("%s %s" % ["OK  " if ok else "FEHL", text])
	if not ok:
		fehler.append(text)


func _process(_delta: float) -> bool:
	if spiel.phase == 1 and schritt < 12:
		spiel._spawn_in = 1.0e9
		spiel._wurf_schlange = []
	if warte > 0:
		warte -= 1
		return false
	bilder += 1
	var jetzt := schritt
	schritt += 1   # wer noch warten muss, zählt zurück
	match jetzt:
		0: _aufbau()
		1: _warte_dock()
		2: _ausgebrannt()
		3: _vorstoss_pruefen()
		4: _nahkampf()
		5: _zur_basis()
		6: _zweiter_turm()
		7: _warte_dock()
		8: _wall_weg()
		9: _brakk()
		10: _brakk_pruefen()
		11: _runde20()
		12: _runde20_laeuft()
		13: _ende()
	return false


## Erdwall nahe der Zone (nicht auf dem Weg), Welle ohne Nachschub, Turm an den Start.
func _aufbau() -> void:
	var k: Karte = spiel.karte
	k.setze(_wallfeld(), Karte.WALL)
	k.aktualisiere_pfad()
	spiel.starte_welle(true)
	spiel._spawn_in = 1.0e9
	spiel._wurf_schlange = []
	turm = spiel._neuer_gegner("belagerung", Werte.START_ZELLE, k.erstes_ziel())
	bilder = 0


func _wallfeld() -> Vector2i:
	var k: Karte = spiel.karte
	for x in range(Werte.ZONE_SPALTEN + 1, Werte.ZONE_SPALTEN + 6):
		for y in range(1, Werte.ZEILEN - 1):
			var z := Vector2i(x, y)
			if k.ist_bebaubar(z) and not k.pfad.has(z) and not k.checkpoints.has(z) and absi(y - Werte.START_ZELLE.y) >= 2:
				return z
	return Karte.KEINE


func _warte_dock() -> void:
	if turm._angedockt < 0.0 and bilder < 6000:
		schritt -= 1
		return
	pruefe(turm._angedockt >= 0.0 and turm._war_angedockt and not turm.vorstoss, "Turm hat angedockt (nach %d Bildern)" % bilder)
	bilder = 0


func _ausgebrannt() -> void:
	turm.max_leben = 400.0
	turm.leben = 100.0
	merk["abgesetzt"] = turm._abgesetzt
	turm._angedockt = Werte.BELAGERUNG_SEK - 0.05
	bilder = 0


func _vorstoss_pruefen() -> void:
	if not turm.vorstoss and bilder < 30:
		schritt -= 1
		return
	pruefe(turm.vorstoss, "nach %s s angedockt: Vorstoß" % Werte.BELAGERUNG_SEK)
	pruefe(is_equal_approx(turm.max_leben, 500.0) and is_equal_approx(turm.leben, 200.0), "Leben: 100 + 25 %% von 400 = %.0f, Maximum %.0f" % [turm.leben, turm.max_leben])
	var bonus := Werte.BELAGERUNG_VORSTOSS_BONUS
	pruefe(is_equal_approx(minf(380.0 + 400.0 * bonus, 400.0 * (1.0 + bonus)), 480.0), "Deckel: höchstens 125 % (Rechnung)")
	merk["drohnen"] = _drohnen()
	pruefe(float(turm.daten["schaden"]) == 18.0 and float(turm.daten["abklingzeit"]) == 1.4 and float(turm.daten["reichweite"]) > 0.0, "Nahkampfwerte 18 / 1,4 s")
	pruefe(float(Werte.GEGNER["belagerung"]["schaden"]) == 0.0, "gemeinsame Gegnerwerte unberührt")
	pruefe(float(turm.daten["panzerung"]) == 4.0 and float(turm.daten["tempo"]) == 0.6 and turm.daten.get("gross", false), "Panzerung 4, Tempo 0,6, groß")
	spiel._schlange = []
	pruefe(spiel.aufraeumen() or spiel.gegner.size() > Werte.AUFRAEUM_HOECHSTENS_GEGNER, "Aufräumen wartet nicht auf den vorrückenden Turm")
	turm.max_leben = 1.0e6   # für den Rest des Tests nicht sterben
	turm.leben = 1.0e6
	merk["pos"] = turm.position
	bilder = 0


## Myr-Drohnen, die gerade leben (alle stammen hier vom Turm).
func _drohnen() -> int:
	return spiel.gegner.filter(func(g) -> bool: return is_instance_valid(g) and g.typ == "enterer" and not g._tot).size()


func _nahkampf() -> void:
	if bilder < 180:
		schritt -= 1
		return
	if truppe == null:
		pruefe(_drohnen() <= int(merk["drohnen"]), "keine neuen Drohnen im Vorstoß (%d → %d)" % [merk["drohnen"], _drohnen()])
		pruefe(turm.position.distance_to(merk["pos"]) > Werte.ZELLE * 0.5, "er läuft (%.0f px)" % turm.position.distance_to(merk["pos"]))
		for g in spiel.gegner.duplicate():   # Drohnen von vorher weg: an der Basis zählt nur der Turm
			if is_instance_valid(g) and g.typ == "enterer":
				spiel.gegner.erase(g)
				g.queue_free()
		truppe = Einheit.new()
		spiel.figuren.add_child(truppe)
		truppe.start(spiel, spiel.karte, "technogunner", spiel.karte.zelle_bei(turm.position))
		truppe._schutz_rest = 0.0
		truppe.max_leben = 1.0e4
		truppe.leben = 1.0e4
		truppe.position = turm.position + Vector2(Werte.ZELLE * 0.5, 0)
		spiel.einheiten.append(truppe)
		merk["truppe"] = truppe.leben
		bilder = 0
		schritt -= 1
		return


func _zur_basis() -> void:
	if not merk.has("geprueft_nah"):
		if bilder < 240:
			schritt -= 1
			return
		merk["geprueft_nah"] = true
		pruefe(is_instance_valid(truppe) and truppe.leben < float(merk["truppe"]), "Nahkampf: Truppe verliert %.0f Leben" % (float(merk["truppe"]) - truppe.leben))
		spiel.einheiten.erase(truppe)
		truppe.queue_free()
		merk["leben"] = spiel.leben
		merk["durch"] = int(spiel._durch_typen.get("belagerung", 0))
		Engine.time_scale = Werte.SPIELTEMPO * 6.0
		bilder = 0
	if is_instance_valid(turm) and not turm._tot and bilder < 9000:
		schritt -= 1
		return
	Engine.time_scale = Werte.SPIELTEMPO
	pruefe(int(spiel._durch_typen.get("belagerung", 0)) == int(merk["durch"]) + 1 and spiel.leben < int(merk["leben"]), "an der Basis angekommen: Leben %d → %d" % [merk["leben"], spiel.leben])


func _zweiter_turm() -> void:
	if spiel.phase != 1:
		spiel.starte_welle(true)   # die erste Welle ist mit dem Turm zu Ende gegangen
	spiel._spawn_in = 1.0e9
	turm = spiel._neuer_gegner("belagerung", Werte.START_ZELLE, spiel.karte.erstes_ziel())
	bilder = 0


func _wall_weg() -> void:
	var k: Karte = spiel.karte
	for z: Vector2i in k.feld.keys():
		if k.feld[z] == Karte.WALL:
			k.entferne(z)
	k.aktualisiere_pfad()
	if not turm.vorstoss and bilder < 300:
		schritt -= 1
		return
	pruefe(turm.vorstoss, "Wall gefallen, kein Dock mehr: Vorstoß (nach %d Bildern)" % bilder)


func _brakk() -> void:
	spiel.gegner.erase(turm)
	turm.queue_free()
	_neues_spiel("brakk")


func _brakk_pruefen() -> void:
	if not merk.has("brakk_turm"):
		var k: Karte = spiel.karte
		var w := _wallfeld()
		k.setze(w, Karte.WALL)
		spiel.starte_welle(true)
		spiel._spawn_in = 1.0e9
		turm = spiel._neuer_gegner("belagerung", Werte.START_ZELLE, k.erstes_ziel())
		turm._sonderziel = w
		turm._angedockt = Werte.BELAGERUNG_SEK - 0.05
		merk["brakk_turm"] = true
		bilder = 0
		schritt -= 1
		return
	if is_instance_valid(turm):
		merk["brakk_vorstoss"] = turm.vorstoss
		if not turm._tot and bilder < 60:
			schritt -= 1
			return
	var weg: bool = not is_instance_valid(turm) or turm._tot
	pruefe(spiel.brakk_modus and weg and not bool(merk.get("brakk_vorstoss", false)), "Brakk-Mode: ausgebrannt zerfällt er wie bisher")


func _runde20() -> void:
	_neues_spiel("sandbox")


func _runde20_laeuft() -> void:
	if not merk.has("r20"):
		merk["r20"] = true
		spiel.sandbox_springe(Werte.LETZTE_RUNDE)
		spiel.karte.setze(_wallfeld(), Karte.WALL)   # damit die Türme andocken können
		spiel.karte.aktualisiere_pfad()
		spiel.leben = 99999
		spiel.starte_welle(true)
		Engine.time_scale = Werte.SPIELTEMPO * 8.0
		bilder = 0
		schritt -= 1
		return
	for g in spiel.gegner:
		if is_instance_valid(g) and g.typ == "belagerung" and spiel.endkampf:
			tuerme_r20[g.get_instance_id()] = g.vorstoss or tuerme_r20.get(g.get_instance_id(), false)
	if spiel._durchgang < 4 and bilder < 40000 and spiel.phase != 2:
		schritt -= 1
		return
	Engine.time_scale = Werte.SPIELTEMPO
	pruefe(spiel.endkampf and spiel._durchgang >= 4, "Runde 20: Gegenangriff läuft weiter – Durchgang %d (nach %d Bildern)" % [spiel._durchgang, bilder])
	pruefe(tuerme_r20.size() >= 2, "Runde 20: Belagerungstürme im Gegenangriff: %d (davon im Vorstoß: %d)" % [tuerme_r20.size(), tuerme_r20.values().count(true)])


func _ende() -> void:
	print("TEST BELAGERUNG OK" if fehler.is_empty() else "TEST BELAGERUNG FEHLER: %s" % ", ".join(fehler))
	quit(0 if fehler.is_empty() else 1)
