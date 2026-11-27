extends SceneTree
## 20.11. (Paul): Übergang Classic → Befehl 24 headless prüfen. Startet den Brakk-Mode (Classic) auf PaulLand, baut eine
## kleine Verteidigung, gibt Brakk Stufe und einen Ring, löst den Sieg aus und spielt weiter („Weiterspielen …?“).
## Geprüft: Rogue freigeschaltet, Knopf angeboten, eigene Verteidigung bleibt, Order24 läuft, Schock nimmt Erfahrung und Ringe.
##
##   godot --headless --path . --fixed-fps 60 -s werkzeuge/befehl24weitertest.gd
##
## Schreibt ins Profil (rogue_frei) – vorher sichern.

var spiel: Node
var schritt := 0
var warte := 0
var fehler: Array[String] = []
var merk := {}


func _initialize() -> void:
	Nemesis.datei = "user://nemesis_test.json"   # 22.11.: Tests schreiben nie in die echte Liste der Meistgesuchten
	Nemesis.zuruecksetzen()
	OS.set_environment("TD_KARTE_NAME", "paulland")
	var main_skript: GDScript = load("res://scripts/main.gd")
	main_skript.set("naechster_start", "brakk")
	spiel = load("res://main.tscn").instantiate()
	root.add_child(spiel)
	spiel.protokoll_an = false


func pruefe(ok: bool, text: String) -> void:
	print("%s %s" % ["OK  " if ok else "FEHL", text])
	if not ok:
		fehler.append(text)


func _process(_delta: float) -> bool:
	warte += 1
	match schritt:
		0:
			if warte < 30 or spiel.get("ego") == null or spiel.kommandant == null:
				return false
			var tafel: Variant = spiel.ego.get("_briefing")
			if tafel != null:
				(tafel as Control).visible = false
			# kleine Verteidigung: zwei Fabriken mit Wällen davor
			spiel.budget = 5000
			var karte: Karte = spiel.karte
			var gebaut := 0
			for y in range(1, Werte.ZEILEN - 1, 3):
				var z := Vector2i(karte.basis.x - 6, y)
				if gebaut < 2 and spiel.baue(z, Karte.FABRIK, true):
					gebaut += 1
					spiel.baue(z + Vector2i(-2, 0), Karte.WALL, true)
			merk["fabriken"] = spiel.fabriken.size()
			merk["waelle"] = karte.feld.values().count(Karte.WALL)
			var f: BrakkFortschritt = spiel.kommandant.fortschritt
			f.gib(400, spiel.kommandant)
			f.ringe.append("laser")
			f.ring_stufen["laser"] = 2
			merk["stufe"] = f.stufe
			print("INFO Classic: %d Fabriken, %d Erdwälle, Brakk Stufe %d mit %d Ring" % [merk["fabriken"], merk["waelle"], f.stufe, f.ringe.size()])
			spiel._gewonnen()
			schritt = 1
			warte = 0
		1:
			if warte < 10:
				return false
			var b: Dictionary = spiel.ego._sieg_bericht
			pruefe(Profil.rogue_frei(), "Classic gewonnen: Rogue ist freigeschaltet")
			pruefe(bool(b.get("weiter", false)), "Siegtafel bietet „Weiterspielen …?“ an")
			spiel.befehl24_weiterspielen()
			schritt = 2
			warte = 0
		2:
			var o: Order24 = spiel.order24
			pruefe(o != null and o.weiter, "Befehl 24 läuft im selben Spiel weiter")
			pruefe(spiel.fabriken.size() >= int(merk["fabriken"]), "eigene Fabriken bleiben stehen (%d, vorher %d)" % [spiel.fabriken.size(), int(merk["fabriken"])])
			pruefe(spiel.zonenbauten.size() == 1 and spiel.hq != null, "Myriaden-HQ steht als Zuflucht")
			pruefe(spiel.gegner.size() <= 1, "keine Myriaden mehr auf der Karte")
			# 27.11. (Paul): Brakk startet nicht neben der eigenen alten Verteidigung (fiel dort vorher in 4–5 s)
			var naechste := INF
			for z: Vector2i in spiel.fabriken:
				naechste = minf(naechste, spiel.karte.mitte(z).distance_to(spiel.kommandant.position) / Werte.ZELLE)
			pruefe(naechste >= Order24.WEITER_START_ABSTAND, "Brakk startet bei %s, nächste Fabrik %.1f Felder entfernt (mind. %.0f)" % [str(spiel.karte.zelle_bei(spiel.kommandant.position)), naechste, Order24.WEITER_START_ABSTAND])
			schritt = 3
			warte = 0
		3:
			var o: Order24 = spiel.order24
			if o.verrat != null:
				o.verrat.ueberspringen()
			if not o.laeuft:
				if warte > 600:
					pruefe(false, "Order24 startet nicht")
					_ende()
				return false
			var f: BrakkFortschritt = spiel.kommandant.fortschritt
			pruefe(f.ringe.is_empty() and f.stufe < int(merk["stufe"]), "Schockimpuls: Ringe weg, Stufe %d → %d" % [int(merk["stufe"]), f.stufe])
			pruefe(spiel.phase == 1, "Kampf läuft (Uhr gestartet)")
			schritt = 4
			warte = 0
		4:
			if warte < 300:
				return false
			var o: Order24 = spiel.order24
			pruefe(o.zeit > 3.0 and not o.vorbei, "Befehl 24 läuft (%.0f s) mit %d Technoclan-Truppen" % [o.zeit, o._truppen().size()])
			_ende()
	return false


func _ende() -> void:
	print("TEST WEITER OK" if fehler.is_empty() else "TEST WEITER FEHLER %d: %s" % [fehler.size(), str(fehler)])
	quit(0 if fehler.is_empty() else 1)
