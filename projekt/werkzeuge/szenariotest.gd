extends SceneTree
## 20.11. (Schritt 5b): Spielt Szenarien headless mit einem einfachen Bot bis zum Ende und schreibt je Runde eine Zeile.
##
##   godot --headless --path . --fixed-fps 60 -s werkzeuge/szenariotest.gd -- <Karte> [<Karte> ...]
##
## Karte = Name in karten/ (z. B. szenario_belagert) oder "paulland". Der Bot baut, was die Karte erlaubt: Fabriken nah an der Basis, dazu
## den Kamm aus [H] (Erdwälle, Stellungen, Türme), soweit das Budget reicht. Ausgang: „ENDE <Karte> sieg|niederlage …“.
## Achtung: schreibt wie das Spiel in user:// (Profil, Zwischenstand) – vorher sichern.

const FORM := "2-kamm"
const TRUPPEN := ["technogunner", "scharfschuetze", "plasmawerfer"]

var karten: Array = []
var spiel: Node
var warte := 0
var sim := 0.0
var runde_start := 0.0
var name_jetzt := ""
var leben_vorher := 0
var herkunft := {}   # Gegner-Kennung -> "links" / "zone2" (Zange: wo er zuerst gesehen wurde)


func _initialize() -> void:
	karten = Array(OS.get_cmdline_user_args())
	_naechste()


func _naechste() -> void:
	if spiel != null:
		spiel.queue_free()
		spiel = null
	if karten.is_empty():
		quit(0)
		return
	name_jetzt = str(karten.pop_front())
	if not Werte.lade_karte(name_jetzt):
		print("FEHLER Karte %s nicht ladbar" % name_jetzt)
		_naechste()
		return
	OS.set_environment("TD_KARTE_NAME", name_jetzt)   # main.gd lädt die Karte beim Start selbst (Werte.lade_einstellungen)
	Werte.setze_anfuehrer(str(Werte.KARTE_REGELN.get("anfuehrer", "brakk")) if str(Werte.KARTE_REGELN.get("anfuehrer", "")) != "" else "brakk")
	Werte.herausforderung = str(Werte.KARTE_REGELN.get("herausforderung", ""))
	var main_skript: GDScript = load("res://scripts/main.gd")
	main_skript.set("naechster_start", "normal")
	spiel = load("res://main.tscn").instantiate()
	root.add_child(spiel)
	spiel.protokoll_an = false
	warte = 3
	sim = 0.0
	runde_start = 0.0
	print("START %s · Budget %d · Runden %d · Modus %s" % [name_jetzt, spiel.budget, Werte.LETZTE_RUNDE, Werte.modus()])


func _baue() -> void:
	var k: Karte = spiel.karte
	var plan: Array = Nachschlag.PLAENE_GROSS[FORM]
	# Fabriken: bis zu 2 + Runde/2, je höchstens 6, auf freien Feldern nah an der Basis
	var soll := mini(6, 2 + int(spiel.welle / 2.0))
	if spiel.herausforderung_sperrt(Karte.FABRIK) == "" and spiel.anfuehrer_sperrt(Karte.FABRIK) == "":
		var felder: Array[Vector2i] = []
		for y in Werte.ZEILEN:
			for x in range(Werte.ZONE_SPALTEN + 3, Werte.SPALTEN):
				var z := Vector2i(x, y)
				if k.ist_bebaubar(z) and Vector2(z - k.basis).length() < 6.0:
					felder.append(z)
		felder.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.distance_squared_to(k.basis) < b.distance_squared_to(k.basis))
		for z: Vector2i in felder:
			if spiel.fabriken.size() >= soll or spiel.budget < spiel.kosten(Karte.FABRIK):
				break
			if (z.x + z.y) % 2 == 0 and spiel.baue(z, Karte.FABRIK, true):
				var typ: String = TRUPPEN[spiel.fabriken.size() % TRUPPEN.size()]
				spiel.fabriken[z]["typ"] = typ
				k.fabrik_typ[z] = typ
	# Kamm: Erdwälle, dann Stellungen und Türme auf den Feldern des Plans
	for y in plan.size():
		for x in (plan[y] as String).length():
			var c := str(plan[y][x])
			var z := Vector2i(x, y)
			if c in ["#", "S", "T"] and spiel.budget > 60 and k.inhalt(z) == Karte.FREI:
				spiel.baue(z, Karte.WALL, true)
	for y in plan.size():
		for x in (plan[y] as String).length():
			var c := str(plan[y][x])
			var z := Vector2i(x, y)
			if k.inhalt(z) == Karte.WALL and not k.ausbau.has(z):
				if c == "S" and spiel.budget > 40:
					spiel.baue(z, Karte.STELLUNG, true)
				elif c == "T" and spiel.budget > 120:
					spiel.baue(z, Karte.TURM, true)
	# vorhandene Erdwälle der Karte (Alarmstart): Stellungen dazu, wenn Geld übrig ist
	if spiel.budget > 200:
		for z: Vector2i in k.feld.keys():
			if spiel.budget < 150:
				break
			if k.feld[z] == Karte.WALL and not k.ausbau.has(z) and k.wall_nachbarn(z) <= 1:
				spiel.baue(z, Karte.STELLUNG, true)


func _process(delta: float) -> bool:
	if spiel == null:
		return false
	sim += delta
	if warte > 0:
		warte -= 1
		return false
	if spiel.phase == 0:
		if runde_start > 0.0:
			print("RUNDE %d geschafft · Leben %d (−%d) · Budget %d · %.0f s" % [spiel.welle - 1, spiel.leben, leben_vorher - spiel.leben, spiel.budget, sim - runde_start])
			if Werte.ZONE2.size != Vector2i.ZERO:
				var n2 := 0
				for h: Variant in herkunft.values():
					n2 += 1 if str(h) == "zone2" else 0
				print("  Zange: %d von links, %d aus Zone 2" % [herkunft.size() - n2, n2])
			herkunft.clear()
		_baue()
		leben_vorher = spiel.leben
		runde_start = sim
		var w: Dictionary = spiel.naechste_welle()
		print("WELLE %d „%s“ · %s · Leben×%.1f" % [spiel.welle, str(w.get("name", "")), spiel._wellen_text(w), float(w.get("leben_faktor", 1.0))])
		spiel.starte_welle(true)
		return false
	if spiel.phase == 1 and Werte.ZONE2.size != Vector2i.ZERO:
		for g: Node in spiel.gegner:
			if is_instance_valid(g) and not herkunft.has(g.get_instance_id()):
				herkunft[g.get_instance_id()] = "zone2" if Werte.in_zone2(spiel.karte.zelle_bei((g as Node2D).position)) else "links"
	if spiel.phase == 2:
		print("ENDE %s %s · Runde %d · Leben %d · %.0f s" % [name_jetzt, "sieg" if spiel.leben > 0 else "niederlage", spiel.welle, spiel.leben, sim])
		_naechste()
	elif sim - runde_start > 900.0:
		print("ENDE %s abgebrochen · Runde %d hängt" % [name_jetzt, spiel.welle])
		_naechste()
	return false
