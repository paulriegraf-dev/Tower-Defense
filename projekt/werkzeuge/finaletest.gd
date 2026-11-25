extends SceneTree
## 25.11. (N7): Runde 20 gegen die Generalprobe – Budget und Pausen je Schleife.
##
##   godot --headless --path . --fixed-fps 60 -s werkzeuge/finaletest.gd
##
##   1. Preis (Phantom.trupp_preis) von Runde 19 und von Runde 20 im ersten Durchgang: gleich auf ±5 %
##   2. Budget des Phantom-Angreifers in Runde 20; Brakk-Finale ohne die Aufstockung (alter Preis)
##   3. Pausenfaktor je Durchgang 1,0 · 1,25 · 1,5 · 1,75
##   4. Sandbox Runde 20: in den Schleifen kommen wirklich die längeren Pausen, und es geht weiter bis Durchgang 4
## Gibt die Tabelle Budget 19 / 20 alt / 20 neu und die Pausen aus. Am Ende „TEST FINALE OK“ oder die Fehler.

const ALT_20 := 1295   # Preis von Runde 20, Durchgang 1, vor N7

var spiel: Node
var warte := 20
var schritt := 0
var bilder := 0
var fehler: Array[String] = []
var pausen := {}       # Durchgang -> _spawn_in direkt nach dem Laden


func _initialize() -> void:
	var m: GDScript = load("res://scripts/main.gd")
	m.set("ohne_spuren", true)
	m.set("naechster_start", "sandbox")
	spiel = load("res://main.tscn").instantiate()
	root.add_child(spiel)


func pruefe(ok: bool, text: String) -> void:
	print("%s %s" % ["OK  " if ok else "FEHL", text])
	if not ok:
		fehler.append(text)


func _preis(trupps: Array, nur_erster: bool) -> int:
	var s := 0
	for t: Dictionary in trupps:
		if nur_erster and int(t.get("jeder", 1)) > 1:
			continue
		s += Phantom.trupp_preis(t)
	return s


func _process(_d: float) -> bool:
	if warte > 0:
		warte -= 1
		return false
	match schritt:
		0:
			var w19: int = _preis(Werte.WELLEN[19]["trupps"], true)
			var w20: int = _preis(Werte.WELLEN[20]["trupps"], true)
			var brakk20: int = _preis(Werte.plan_ohne(Werte.WELLEN[20], "nicht_brakk")["trupps"], true)
			print("     Budget  Runde 19: %d · Runde 20 alt: %d · Runde 20 neu: %d (%+.1f %% zu 19) · Phantom-Angreifer Runde 20: %d · Brakk-Finale: %d" % [w19, ALT_20, w20, 100.0 * (w20 - w19) / w19, Phantom.budget(Werte.LETZTE_RUNDE), brakk20])
			pruefe(absf(float(w20 - w19)) <= 0.05 * w19, "Runde 20 (Durchgang 1) im Budget gleich Runde 19 ±5 %")
			pruefe(brakk20 == ALT_20, "Brakk-Finale ohne Aufstockung (%d)" % brakk20)
			pruefe(Phantom.budget(19) == 1895, "Phantom-Budget Runde 19 unverändert: %d (vorher 1895)" % Phantom.budget(19))
			var f: Array = []
			for d in [1, 2, 3, 4]:
				spiel._durchgang = d
				f.append(spiel.endkampf_dehnung())
			spiel._durchgang = 0
			print("     Pausen je Durchgang: Faktor %s → Schleifenpause %s s, Truppabstand %s s" % [str(f), str(f.map(func(x: float) -> float: return Werte.ENDKAMPF_PAUSE * x)), str(f.map(func(x: float) -> float: return Werte.ENDKAMPF_TRUPP_PAUSE * x))])
			pruefe(f == [1.0, 1.25, 1.5, 1.75], "Faktor 1,0 · 1,25 · 1,5 · 1,75")
			spiel.protokoll_an = false
			spiel.sandbox_springe(Werte.LETZTE_RUNDE)
			spiel.leben = 99999
			spiel.starte_welle(true)
			Engine.time_scale = Werte.SPIELTEMPO * 8.0
			schritt = 1
		1:
			bilder += 1
			var d: int = spiel._durchgang
			if spiel.endkampf and not pausen.has(d):
				pausen[d] = spiel._spawn_in
			if (d < 5 and bilder < 50000) and spiel.phase != 2:
				return false
			Engine.time_scale = Werte.SPIELTEMPO
			print("     gemessene Schleifenpausen (Rest direkt nach dem Laden): %s" % str(pausen))
			for k: int in [2, 3, 4]:
				var soll := Werte.ENDKAMPF_PAUSE * (1.0 + Werte.ENDKAMPF_PAUSE_ZUWACHS * (k - 1))
				pruefe(pausen.has(k) and absf(float(pausen[k]) - soll) < 0.5, "Durchgang %d: Pause %.2f s (soll %.2f)" % [k, float(pausen.get(k, -1.0)), soll])
			pruefe(spiel.endkampf and spiel._durchgang >= 5, "Gegenangriff läuft bis Durchgang %d" % spiel._durchgang)
			print("TEST FINALE OK" if fehler.is_empty() else "TEST FINALE FEHLER: %s" % ", ".join(fehler))
			quit(0 if fehler.is_empty() else 1)
	return false
