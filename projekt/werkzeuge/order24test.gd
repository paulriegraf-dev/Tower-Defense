extends SceneTree
## 20.11. (Schritt 5b): Order 24 headless mit einem Bot-Brakk.
##
##   godot --headless --path . --fixed-fps 60 -s werkzeuge/order24test.gd -- [Läufe] [Überlebenszeit] [Jagdbeginn]
##
## Der Bot läuft zwischen Feldern im linken Drittel hin und her (meidet Feldern, die eine Truppe sieht), feuert alle 0,4 s
## auf das nächste Technoclan-Ziel in 6 Feldern (wie ein Pistolenschuss) und holt Med-Kits, wenn er unter 60 % Leben hat.
## Ausgabe: Zeilen „ORDER24 …“ und „JAGD …“ aus dem Spiel, dazu alle 15 s ein Stand. Schreibt wie das Spiel in user://.

var spiel: Node
var laeufe := 1
var warte := 0
var sim := 0.0
var ziel_feld := Vector2i(-1, -1)
var schuss := 0.0
var stand_uhr := 0.0
var jagd_gemeldet := false


func _initialize() -> void:
	Nemesis.datei = "user://nemesis_test.json"   # 22.11.: Tests schreiben nie in die echte Liste der Meistgesuchten
	Nemesis.zuruecksetzen()
	var a := OS.get_cmdline_user_args()
	laeufe = int(a[0]) if a.size() > 0 else 1
	OS.set_environment("TD_KARTE_NAME", "szenario_order24")
	if Werte.lade_karte("szenario_order24"):
		print("Karte geladen")
	_neu()


func _neu() -> void:
	if spiel != null:
		spiel.queue_free()
		spiel = null
	if laeufe <= 0:
		quit(0)
		return
	laeufe -= 1
	var main_skript: GDScript = load("res://scripts/main.gd")
	main_skript.set("naechster_start", "normal")
	spiel = load("res://main.tscn").instantiate()
	root.add_child(spiel)
	spiel.protokoll_an = false
	warte = 5
	sim = 0.0
	jagd_gemeldet = false


func _process(delta: float) -> bool:
	if spiel == null:
		return false
	if warte > 0:
		warte -= 1
		return false
	var o: Order24 = spiel.order24
	if o == null:
		return false
	sim += delta
	if o.vorbei or spiel.phase == 2:
		print("TEST Ende nach %.0f s Spielzeit-Sekunden (Order-24-Uhr %.0f s) · Brakk %s" % [sim, o.zeit, "lebt" if not spiel.kommandant.gefallen else "gefallen"])
		_neu()
		return false
	if not o.laeuft:
		var args := OS.get_cmdline_user_args()
		if args.size() > 1:
			o.werte["ueberleben_sek"] = int(args[1])   # Order24 liest das Regelpaket schon beim Aufbau
		if args.size() > 2:
			o.werte["jagd_start"] = int(args[2])
		var tafel: Variant = spiel.ego.anzeige.get("_briefing") if spiel.ego != null else null
		if tafel != null and (tafel as Control).visible:
			(tafel as Control).visible = false   # headless klickt niemand „Los“
		return false
	if o.jagd and not jagd_gemeldet:
		jagd_gemeldet = true
		print("TEST Jagd begann bei %.1f s (eingestellt %d)" % [o.zeit, int(o.w("jagd_start"))])
	var k: Kommandant = spiel.kommandant
	_bewege(k, o, delta)
	schuss -= delta
	if schuss <= 0.0:
		schuss = 0.4
		var bestes: Gegner = null
		var d := 6.0 * Werte.ZELLE
		for t: Gegner in o.ego_ziele():
			var dd := t.position.distance_to(k.position)
			if dd < d and spiel.karte.sicht_frei(k.position, t.position):
				d = dd
				bestes = t
		if bestes != null:
			spiel.brakk_quelle = "pistole"
			spiel.schadensquelle = "fabrik:-1,-1"
			bestes.nimm_schaden(26.0 * (1.0 + 0.1 * float(k.fortschritt.stufe - 1) if k.fortschritt != null else 1.0))
			spiel.brakk_quelle = ""
			spiel.schadensquelle = ""
	stand_uhr += delta
	if stand_uhr >= 15.0:
		stand_uhr = 0.0
		print("STAND %.0f s · Brakk %d/%d bei %s · Truppen %d · Jäger %d · Vorstoß %.0f %% · Sabotage %s" % [o.zeit, k.leben, k.max_leben, spiel.karte.zelle_bei(k.position), spiel.einheiten.size() - 1, o.jaeger.size(), o.vorstoss_anteil * 100.0, str(o.sabotage)])
	return false


## Sieht eine Technoclan-Truppe (oder ein Turm in Reichweite) dieses Feld?
func _gesehen(z: Vector2i) -> bool:
	var p: Vector2 = spiel.karte.mitte(z)
	for e in spiel.einheiten:
		if not is_instance_valid(e) or e == spiel.kommandant:
			continue
		var weite := (float((e as Einheit).daten.get("reichweite", 4.0)) + 1.5) * Werte.ZELLE
		if (e as Node2D).position.distance_to(p) <= weite and spiel.karte.sicht_frei((e as Node2D).position, p):
			return true
	return false


## Zielfeld wechseln, wenn erreicht oder gesehen; dorthin mit Brakks Tempo laufen (über freie Felder).
func _bewege(k: Kommandant, o: Order24, delta: float) -> void:
	var karte: Karte = spiel.karte
	var hier := karte.zelle_bei(k.position)
	if k.leben < k.max_leben * 0.6:
		for m: Dictionary in o.medkits:
			if bool(m["da"]):
				ziel_feld = m["zelle"]
				break
	var flucht := _gesehen(hier)
	if ziel_feld.x < 0 or hier == ziel_feld or flucht or (randi() % 240 == 0):
		for versuch in 40:
			var z := Vector2i(randi_range(Werte.ZONE_SPALTEN, int(Werte.SPALTEN * 0.55)), randi_range(1, Werte.ZEILEN - 2))
			if karte.ist_begehbar(z) and karte.ist_frei(z) and not _gesehen(z):
				ziel_feld = z
				break
	var weg := karte.einheiten_weg(hier, ziel_feld)
	if weg.size() >= 2:
		var p := karte.mitte(weg[1])
		var schritt := 3.0 * Werte.ZELLE * delta
		k.position = k.position.move_toward(p, schritt)
		k.anker = k.position
	else:
		ziel_feld = Vector2i(-1, -1)
