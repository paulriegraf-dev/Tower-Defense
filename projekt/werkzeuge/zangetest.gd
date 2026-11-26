extends SceneTree
## 23.11.: Befehl 24 – Zange der Jagdtrupps (scripts/order24.gd _zange_pflegen, _jagd_ziel).
##
##   godot --headless --path . --fixed-fps 60 -s werkzeuge/zangetest.gd -- [Formation]
##
## Brakk nimmt keinen Schaden, steht still und gilt als gesehen (Markierung). Eine Jagdwelle zu 10 kommt heraus.
## Geprüft: Welle in Trupps zu höchstens 5, Anmarschpunkte auf verschiedenen Seiten, Anmarschwege überlappen wenig,
## die Zange schlägt zu, am Ende stehen die Jäger verteilt (nicht alle auf einem Feld) und kaum einer steht nah ohne Sicht.
## Am Ende „TEST ZANGE OK“ oder die Fehler. Schreibt in user:// (Nemesis-Testdatei).

var spiel: Node
var o: Order24
var warte := 10
var fehler: Array[String] = []
var welle_t := -1.0
var winkel := {}
var ueberlapp := 0.0
var max_trupp := 0
var zange_los := false
var ende := false
var gesetzt := false
var ziel_feld := Vector2i(7, 7)


func _initialize() -> void:
	Nemesis.datei = "user://nemesis_test.json"
	Nemesis.zuruecksetzen()
	var a := OS.get_cmdline_user_args()
	if a.size() > 1:
		ziel_feld = Vector2i(int(a[1]), int(a[2]))
	Werte.lade_karte("szenario_order24")
	var r: Dictionary = (Werte.KARTE_REGELN.get("order24", {}) as Dictionary).duplicate()
	r["karte"] = a[0] if a.size() > 0 else "3-zitadelle"
	r["brakk_schaden"] = 0
	r["ueberleben_sek"] = 2000
	r["geheim_ab"] = 0
	for k: String in {"flucht_sek": 3, "jagd_start": 10, "welle_takt": 12, "welle_takt_min": 12, "welle_groesse": 10, "welle_wachsen_sek": 1000, "elite_jede": 0, "sicht_verlust": 999, "jagd_anteil": 0}:
		r[k] = {"flucht_sek": 3, "jagd_start": 10, "welle_takt": 12, "welle_takt_min": 12, "welle_groesse": 10, "welle_wachsen_sek": 1000, "elite_jede": 0, "sicht_verlust": 999, "jagd_anteil": 0}[k]
	Order24.test_werte = r
	var main_skript: GDScript = load("res://scripts/main.gd")
	main_skript.set("naechster_start", "normal")
	main_skript.set("ohne_spuren", true)   # Protokoll nur im Speicher (nichts nach partien/)
	spiel = load("res://main.tscn").instantiate()
	root.add_child(spiel)


func pruefe(ok: bool, text: String) -> void:
	print("%s %s" % ["OK  " if ok else "FEHL", text])
	if not ok:
		fehler.append(text)


func _process(_delta: float) -> bool:
	if warte > 0:
		warte -= 1
		return false
	o = spiel.order24
	if o == null or ende:
		return false
	if not o.laeuft:
		o.verrat_ueberspringen = true
		var tafel: Variant = spiel.ego.get("_briefing") if spiel.ego != null else null
		if tafel != null and (tafel as Control).visible:
			(tafel as Control).visible = false
		return false
	var k: Kommandant = spiel.kommandant
	k.leben = k.max_leben
	if o.taktik != null:
		o.taktik.erzwingen = "zange"   # 26.11.: seit den Angriffstaktiken ist die Zange eine von vier (sonst zufällig)
	if not gesetzt:
		gesetzt = true
		var karte: Karte = spiel.karte
		var bestes := Vector2i(-1, -1)
		for y in range(0, 20):
			for x in range(Werte.ZONE_SPALTEN, 40):
				var z := Vector2i(x, y)
				if karte.in_karte(z) and karte.ist_begehbar(z) and karte.ist_frei(z) and (bestes.x < 0 or Vector2(z - ziel_feld).length() < Vector2(bestes - ziel_feld).length()):
					bestes = z
		k.position = karte.mitte(bestes)
		print("Brakk nach %s gesetzt" % bestes)
	k.position = spiel.karte.mitte(spiel.karte.zelle_bei(k.position))
	o.markiert_bis = o.zeit + 5.0   # alle Trupps kennen Brakks Ort
	if o.wellen >= 1 and welle_t < 0.0:
		welle_t = o.zeit
		print("Welle bei %.1f s, Brakk auf %s, %d Trupps" % [o.zeit, spiel.karte.zelle_bei(k.position), o.trupps.size()])
	if welle_t < 0.0:
		if o.zeit > 120.0:
			pruefe(false, "keine Jagdwelle")
			_ende()
		return false
	for t: Dictionary in o.trupps:
		max_trupp = maxi(max_trupp, (t["mitglieder"] as Array).size())
		if t.has("anflug"):
			var a: Dictionary = t["anflug"]
			winkel[o.trupps.find(t)] = float(a["winkel"])
	if not o._zange.is_empty() and bool(o._zange["los"]) and not zange_los:
		zange_los = true
		print("Zange los bei %.1f s (%.1f s nach der Welle)" % [o.zeit, o.zeit - welle_t])
		ueberlapp = _ueberlappung()
	if o.zeit - welle_t >= 45.0:
		_auswerten(k)
		_ende()
	return false


## Anteil der Felder, die zwei Anmarschwege in ihrer zweiten Hälfte teilen (ohne die letzten 3 Felder).
func _ueberlappung() -> float:
	var wege: Array = []
	for t: Dictionary in o.trupps:
		if t.has("anflug"):
			var w: Array = (t["anflug"] as Dictionary)["weg"]
			wege.append(w.slice(int(w.size() * 0.4), maxi(0, w.size() - 3)))   # Ausgang aus dem Schild teilen sich alle
	if wege.size() < 2:
		return 0.0
	var geteilt := 0
	var alle := 0
	for i in wege.size():
		for z: Vector2i in wege[i]:
			alle += 1
			for j in wege.size():
				if j != i and (wege[j] as Array).has(z):
					geteilt += 1
					break
	return float(geteilt) / maxf(1.0, float(alle))


func _auswerten(k: Kommandant) -> void:
	var karte: Karte = spiel.karte
	var nah: Array = []
	var felder := {}
	var blind := 0
	for t: Dictionary in o.trupps:
		for e: Variant in t["mitglieder"]:
			if not is_instance_valid(e):
				continue
			var p: Vector2 = (e as Node2D).position
			if p.distance_to(k.position) <= 5.0 * Werte.ZELLE:
				nah.append(e)
				felder[karte.zelle_bei(p)] = true
				if not karte.sicht_frei(p, k.position):
					blind += 1
	var seiten := {}
	for v: float in winkel.values():
		seiten[roundi(wrapf(v, 0.0, TAU) / (TAU / 8.0)) % 8] = true
	print("Trupps max. %d · Seiten %d (%s) · Überlappung der Wege %d %% · nah %d auf %d Feldern · nah ohne Sicht %d" % [max_trupp, seiten.size(), str(seiten.keys()), roundi(ueberlapp * 100.0), nah.size(), felder.size(), blind])
	pruefe(max_trupp <= 5, "Trupps höchstens 5 (%d)" % max_trupp)
	pruefe(seiten.size() >= 2, "mindestens zwei Anmarschseiten (%d)" % seiten.size())
	pruefe(ueberlapp <= 0.6, "Anmarschwege überlappen höchstens 60 %% (%d %%)" % roundi(ueberlapp * 100.0))
	pruefe(zange_los, "Zange hat zugeschlagen")
	pruefe(nah.size() < 3 or felder.size() >= mini(nah.size(), 3), "Jäger verteilt (%d auf %d Feldern)" % [nah.size(), felder.size()])
	var b24: Array = spiel._protokoll.get("befehl24", [])
	var wellen_e := b24.filter(func(x: Dictionary) -> bool: return str(x["a"]) == "welle")
	var lage := 0
	for x: Dictionary in wellen_e:
		lage += ((x.get("brakk", {}) as Dictionary).get("lage", []) as Array).size()
	print("Protokoll befehl24: %d Einträge, %d Wellen, %d Lagepunkte" % [b24.size(), wellen_e.size(), lage])
	pruefe(wellen_e.size() >= 2 and lage > 10, "Befehl-24-Protokoll je Welle mit Brakks Lage")
	pruefe(nah.size() == 0 or float(blind) / float(nah.size()) <= 0.5, "höchstens die Hälfte nah ohne Sicht (%d von %d)" % [blind, nah.size()])


func _ende() -> void:
	ende = true
	print("TEST ZANGE OK" if fehler.is_empty() else "TEST ZANGE FEHLER: %s" % ", ".join(fehler))
	quit(0 if fehler.is_empty() else 1)
