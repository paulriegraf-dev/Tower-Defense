extends SceneTree
## 25.11. (N3): Spawnschutz für frisch produzierte Truppen.
##
##   godot --headless --path . --fixed-fps 60 -s werkzeuge/spawnschutztest.gd
##
##   1. Frisch aus der Fabrik: Nah- und Fernschaden verfallen, die Truppe schimmert; nach Ablauf wirkt Schaden wieder
##   2. Feldlazarett: wer aufsteht, ist wieder kurz geschützt
##   3. Klone und Brakk haben keinen Schutz, im Brakk-Mode niemand
##   4. Überrannte Fabrik: neben der ersten Truppe zerfällt ein Schwarmgeist in 3 Myr-Drohnen. Mit Schutz sitzt bei jedem
##      Truppentyp ein eigener Treffer, bevor er fallen kann; der Schutz endet mit diesem Treffer. Zum Vergleich ohne.
## Am Ende „TEST SPAWNSCHUTZ OK“ oder die Fehler. Eigenen Benutzerordner nehmen.

const TYPEN := ["technogunner", "scharfschuetze", "plasmawerfer"]
const DAUER := 480                  # höchstens so viele Bilder je Gefecht

var spiel: Node
var warte := 20
var schritt := 0
var bilder := 0
var fehler: Array[String] = []
var fab := Karte.KEINE
var truppe: Einheit
var drohnen: Array = []
var lauf := 0                       # Gefecht: Truppentyp lauf / 2, gerade = mit Schutz
var schutz_ende := {}               # {"bild", "schaden"} beim Ende des Schutzes
var ergebnis: Array = []


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
	truppe = null
	warte = 20


func pruefe(ok: bool, text: String) -> void:
	print("%s %s" % ["OK  " if ok else "FEHL", text])
	if not ok:
		fehler.append(text)


## Fabrik nah an der Zone bauen, auf `typ` stellen und die Welle ohne eigene Gegner starten.
func _welle_mit_fabrik(typ: String) -> void:
	spiel.budget = 999999
	fab = Karte.KEINE
	for x in range(Werte.ZONE_SPALTEN + 2, Werte.SPALTEN - 3):
		for y in range(2, Werte.ZEILEN - 2):
			var z := Vector2i(x, y)
			if fab == Karte.KEINE and spiel.bau_hindernis(z, Karte.FABRIK) == "" and not spiel.karte.checkpoints.has(z):
				fab = z
	spiel.baue(fab, Karte.FABRIK, true)
	spiel.stelle_um(fab, typ)
	spiel.starte_welle()
	spiel._spawn_in = 1.0e9
	spiel._wurf_schlange = []


func _erste_truppe() -> Einheit:
	var liste: Array = spiel.fabriken[fab]["einheiten"]
	return liste[0] if not liste.is_empty() else null


func _schaden() -> float:
	return float((spiel.gesamt_stats.get("fabrik:%d,%d" % [fab.x, fab.y], {}) as Dictionary).get("schaden", 0.0))


func _process(_delta: float) -> bool:
	if spiel.phase == 1:
		spiel._spawn_in = 1.0e9
	if warte > 0:
		warte -= 1
		return false
	var jetzt := schritt
	schritt += 1   # wer noch warten muss, zählt wieder zurück
	match jetzt:
		0: _welle_mit_fabrik("technogunner")
		1: _frisch()
		2: _abgelaufen()
		3: _lazarett_klon_brakk()
		4: _brakk_mode()
		5: _gefecht_start()
		6: _gefecht_truppe()
		7: _gefecht_laeuft()
		8: _auswertung()
	return false


func _frisch() -> void:
	truppe = _erste_truppe()
	if truppe == null:
		schritt -= 1
		return
	var vorher := truppe.leben
	pruefe(truppe._schutz_rest > Werte.SPAWNSCHUTZ_SEK - 0.2, "frisch produziert: geschützt (%.2f s)" % truppe._schutz_rest)
	truppe.nimm_schaden(1.0e9)
	truppe.nimm_fernschaden(1.0e9)
	pruefe(is_instance_valid(truppe) and truppe.leben == vorher, "Nah- und Fernschaden verfallen")
	warte = 3
	bilder = 0


func _abgelaufen() -> void:
	if bilder == 0:
		pruefe(Werte.SPAWNSCHUTZ_FARBEN.has(truppe._sprite.modulate), "geschützte Truppe schimmert blau")
	bilder += 1
	if truppe._schutz_rest > 0.0 and bilder < 600:
		schritt -= 1
		return
	var sek := float(bilder) * Werte.sim_schritt()
	pruefe(truppe._schutz_rest <= 0.0 and absf(sek - Werte.SPAWNSCHUTZ_SEK) < 0.25, "ohne Gegner läuft der Schutz nach %.2f s ab" % sek)
	warte = 3


func _lazarett_klon_brakk() -> void:
	pruefe(truppe._sprite.modulate == Color.WHITE, "danach wieder normale Farbe")
	var vorher := truppe.leben
	truppe.nimm_schaden(1.0)
	pruefe(truppe.leben < vorher, "danach wirkt Schaden wieder")
	# Feldlazarett: ein Heilturm Stufe 3 direkt bei der Truppe
	var k: Karte = spiel.karte
	var mitte := k.zelle_bei(truppe.position)
	var turm := Karte.KEINE
	for dy in range(-2, 3):
		for dx in range(-2, 3):
			var t := mitte + Vector2i(dx, dy)
			var felder: Array[Vector2i] = [t, t + Vector2i(1, 1), t - Vector2i(1, 1)]
			if turm == Karte.KEINE and felder.all(func(z: Vector2i) -> bool: return k.ist_bebaubar(z) and z != mitte):
				turm = t
				for z in felder:
					k.setze(z, Karte.WALL)
				k.baue_aus(t, Karte.TURM, "heil")
				k.turm_stufe[t] = 3
				k.turm_faehigkeit[t] = "lazarett"
	truppe.nimm_schaden(1.0e9)
	pruefe(is_instance_valid(truppe) and truppe.leben > 0.0 and truppe._schutz_rest > Werte.SPAWNSCHUTZ_SEK - 0.05, "Feldlazarett: steht auf und ist wieder geschützt")
	var halb := truppe.leben
	truppe.nimm_schaden(1.0e9)
	pruefe(truppe.leben == halb, "Feldlazarett: der nächste Treffer verfällt")
	# Klon
	var vorher_zahl: int = spiel.einheiten.size()
	spiel.klone_einheit(truppe)
	var klon: Einheit = spiel.einheiten[spiel.einheiten.size() - 1]
	pruefe(spiel.einheiten.size() == vorher_zahl + 1 and klon.klon and klon._schutz_rest <= 0.0, "Klon ohne Spawnschutz")
	var brakk := Kommandant.new()
	spiel.figuren.add_child(brakk)
	brakk.einrichten_kommandant(spiel, k, mitte)
	var bl := brakk.leben
	brakk.nimm_schaden(10.0)
	pruefe(brakk._schutz_rest <= 0.0 and brakk.leben < bl, "Brakk ohne Spawnschutz")
	brakk.queue_free()
	_neues_spiel("brakk")


func _brakk_mode() -> void:
	spiel.budget = 999999
	var z := Karte.KEINE
	var b: Vector2i = spiel.karte.zelle_bei(spiel.kommandant.position)
	for r in range(2, 10):
		for dx in range(-r, r + 1):
			if z == Karte.KEINE and spiel.bau_hindernis(b + Vector2i(dx, r), Karte.FABRIK) == "":
				z = b + Vector2i(dx, r)
	var e := Einheit.new()
	spiel.figuren.add_child(e)
	e.start(spiel, spiel.karte, "technogunner", z if z != Karte.KEINE else b)
	pruefe(spiel.brakk_modus and e._schutz_rest <= 0.0, "Brakk-Mode: kein Spawnschutz")
	e.queue_free()
	lauf = 0
	_neues_spiel("sandbox")


func _gefecht_start() -> void:
	_welle_mit_fabrik(TYPEN[lauf / 2])


func _gefecht_truppe() -> void:
	truppe = _erste_truppe()
	if truppe == null:
		schritt -= 1
		return
	if lauf % 2 == 1:
		truppe._schutz_rest = 0.0   # Vergleich: wie vor N3
	# neben der Fabrik zerfällt ein Schwarmgeist in seine Myr-Drohnen
	var daneben: Vector2i = spiel.karte.freier_nachbar(fab)
	var geist: Gegner = spiel._neuer_gegner("schwarm", daneben, spiel._erstes_ziel)
	var vorher: int = spiel.gegner.size()
	spiel.zerfall(geist)
	drohnen = spiel.gegner.slice(vorher)
	spiel.gegner.erase(geist)
	geist.queue_free()
	schutz_ende = {}
	bilder = 0


func _gefecht_laeuft() -> void:
	bilder += 1
	var lebt: bool = is_instance_valid(truppe) and not truppe.is_queued_for_deletion() and truppe.leben > 0.0
	if lebt and schutz_ende.is_empty() and truppe._schutz_rest <= 0.0:
		schutz_ende = {"bild": bilder, "schaden": _schaden()}
	var offen := drohnen.filter(func(g: Variant) -> bool: return is_instance_valid(g) and not g._tot).size()
	if lebt and offen > 0 and bilder < DAUER:
		schritt -= 1
		return
	var r := {"typ": TYPEN[lauf / 2], "schutz": lauf % 2 == 0, "schaden": _schaden(), "lebt": lebt, "drohnen": drohnen.size(), "offen": offen,
		"sek": float(bilder) * Werte.sim_schritt(), "ende": schutz_ende}
	ergebnis.append(r)
	print("INFO %-14s %s Schutz: %3.0f Schaden an %d Drohnen, %d übrig, Truppe %s nach %.1f s" % [r["typ"], "mit " if r["schutz"] else "ohne", r["schaden"], r["drohnen"], offen, "lebt" if lebt else "gefallen", r["sek"]])
	lauf += 1
	if lauf < TYPEN.size() * 2:
		_neues_spiel("sandbox")
		schritt = 5


func _auswertung() -> void:
	for r: Dictionary in ergebnis:
		if not r["schutz"]:
			continue
		pruefe(int(r["drohnen"]) == 3 and float(r["schaden"]) > 0.0, "%s mit Schutz: Schaden in der Schadensliste (%.0f)" % [r["typ"], r["schaden"]])
		var ende: Dictionary = r["ende"]
		pruefe(not ende.is_empty() and (float(ende["schaden"]) > 0.0 or int(ende["bild"]) * Werte.sim_schritt() >= Werte.SPAWNSCHUTZ_SEK - 0.1), "%s: Schutz endet erst mit einem sitzenden Treffer oder nach Ablauf (%s)" % [r["typ"], str(ende)])
	print("TEST SPAWNSCHUTZ OK" if fehler.is_empty() else "TEST SPAWNSCHUTZ FEHLER: %s" % ", ".join(fehler))
	quit(0 if fehler.is_empty() else 1)
