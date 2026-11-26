extends SceneTree
## 26.11. (Paul): Befehl 24 – Angriffstaktiken der Jagdwellen, headless.
##
##   godot --headless --path . --fixed-fps 60 -s werkzeuge/taktiktest.gd
##
## Brakk steht fest und nimmt keinen Schaden. Geprüft: Wahl (Sturm bevorzugt, nie zweimal dieselbe andere, Mindestgrößen),
## Funkortung (ungenau, alle 15 s neu, Wellen finden ihn ohne Sicht), Sturm schießt im Gehen, Kontakt und Trupp-Ende,
## Zange (getrennte Seiten, gemeinsamer Zugriff), Feuerschutz (Feuergruppe mit Sicht in Reichweite, Sturmgruppe springt,
## stürmt wenn Brakk sie angreift), Hinterhalt (außer Sicht, löst bei 6 Feldern aus, sonst nach 25 s Sturm).
## Am Ende „TEST TAKTIK OK“ oder die Fehler. Schreibt nur user://nemesis_taktik_test.json.

const SOLL := 24

var spiel: Node
var o: Order24
var tk: BrakkJagdtaktik
var warte := 10
var schritt := 0
var fehler: Array[String] = []
var merk := {}
var geprueft := 0


func _initialize() -> void:
	Nemesis.datei = "user://nemesis_taktik_test.json"
	Nemesis.zuruecksetzen()
	OS.set_environment("TD_KARTE_NAME", "szenario_order24")
	Werte.lade_karte("szenario_order24")
	var r: Dictionary = (Werte.KARTE_REGELN.get("order24", {}) as Dictionary).duplicate()
	r["karte"] = "3-zitadelle"
	r["brakk_schaden"] = 0
	r["geheim_ab"] = 0
	r["welle_takt"] = 9999
	r["elite_jede"] = 0
	r["flucht_sek"] = 0
	r["jagd_start"] = 0
	r["vorstoss"] = false
	r["herausforderer"] = false
	Order24.test_werte = r
	var main_skript: GDScript = load("res://scripts/main.gd")
	main_skript.set("naechster_start", "normal")
	spiel = load("res://main.tscn").instantiate()
	root.add_child(spiel)
	spiel.protokoll_an = false


func pruefe(ok: bool, text: String) -> void:
	geprueft += 1
	print("%s %s" % ["OK  " if ok else "FEHL", text])
	if not ok:
		fehler.append(text)


func _weiter() -> void:
	schritt += 1
	merk["t"] = o.zeit


func _seit() -> float:
	return o.zeit - float(merk.get("t", o.zeit))


func _fertig() -> bool:
	Nemesis.zuruecksetzen()
	if geprueft < SOLL:
		fehler.append("nur %d von %d Prüfungen gelaufen" % [geprueft, SOLL])
	if fehler.is_empty():
		print("TEST TAKTIK OK")
	else:
		print("TEST TAKTIK FEHLER (%d): %s" % [fehler.size(), "; ".join(PackedStringArray(fehler))])
	quit(0 if fehler.is_empty() else 1)
	return true


func _process(_delta: float) -> bool:
	if warte > 0:
		warte -= 1
		return false
	o = spiel.order24
	if o == null:
		return false
	if not o.laeuft:
		o.verrat_ueberspringen = true
		var tafel: Variant = spiel.ego.get("_briefing") if spiel.ego != null else null
		if tafel != null and (tafel as Control).visible:
			(tafel as Control).visible = false
		return false
	tk = o.taktik
	var k: Kommandant = spiel.kommandant
	k.leben = k.max_leben
	if merk.has("brakk"):
		k.position = merk["brakk"]
		k.oben = false
	if o.vorbei:
		pruefe(false, "Lauf vorzeitig vorbei (Schritt %d)" % schritt)
		return _fertig()
	return _schritte(k)


## Alle Taktik-Trupps einer Welle.
func _welle(nr: int) -> Array:
	return o.trupps.filter(func(t: Dictionary) -> bool: return int(t.get("welle", -1)) == nr)


func _naechster(trupps: Array, k: Kommandant) -> float:
	var d := INF
	for t: Dictionary in trupps:
		for e: Variant in t["mitglieder"]:
			if Nemesis.lebt(e):
				d = minf(d, (e as Einheit).position.distance_to(k.position) / Werte.ZELLE)
	return d


func _alle_weg(trupps: Array) -> void:
	for t: Dictionary in trupps:
		for e: Variant in (t["mitglieder"] as Array).duplicate():
			if Nemesis.lebt(e):
				(e as Einheit).nimm_schaden(9999999.0)


func _schritte(k: Kommandant) -> bool:
	match schritt:
		0:
			if o.zeit > 2.0:
				merk["brakk"] = o.karte.mitte(_weit_weg())
				print("     Brakk bei %s, Quelle %s" % [str(o.karte.zelle_bei(merk["brakk"])), str(_quelle())])
				_wahl()
				_weiter()
		1:   # Funkortung: eine Sturm-Welle findet ihn
			tk.erzwingen = "sturm"
			o._jagdwelle()
			merk["w1"] = o.wellen
			var t: Dictionary = _welle(o.wellen)[0]
			var bz := o.karte.zelle_bei(k.position)
			var d := Vector2(t["zuletzt"] - bz).length()
			pruefe(str(t["taktik"]) == "sturm" and str(t["modus"]) == "jagd" and d <= 3.0 * sqrt(2.0) + 0.01, "Welle kennt Brakks Ort, %.1f Felder daneben (höchstens 3)" % d)
			merk["min"] = INF
			merk["gehend"] = false
			_weiter()
		2:
			var trupps := _welle(int(merk["w1"]))
			merk["min"] = minf(float(merk["min"]), _naechster(trupps, k))
			for t: Dictionary in trupps:
				for e: Variant in t["mitglieder"]:
					if Nemesis.lebt(e) and o.drueckt(e as Einheit) and not (e as Einheit)._punkte.is_empty():
						merk["gehend"] = true
			if float(merk["min"]) <= 5.0 or _seit() > 90.0:
				pruefe(float(merk["min"]) <= 5.0, "Sturm-Welle erreicht Brakk ohne Sicht vom Start (%.1f Felder nach %.0f s)" % [float(merk["min"]), _seit()])
				pruefe(bool(merk["gehend"]), "Sturm schießt im Gehen (drueckt)")
				_weiter()
		3:
			var trupps_k := _welle(int(merk["w1"]))
			if trupps_k.any(func(t: Dictionary) -> bool: return bool(t["kontakt"])) or _seit() > 15.0:
				var trupps := trupps_k
				pruefe(trupps.any(func(t: Dictionary) -> bool: return bool(t["kontakt"])) and tk.protokoll.any(func(x: Dictionary) -> bool: return str(x["was"]) == "kontakt"), "Kontakt ins Protokoll")
				# Brakk zieht um: die Ortung folgt nach spätestens 15 s
				var neu := _anderer_platz(k)
				merk["brakk"] = o.karte.mitte(neu)
				merk["neu"] = neu
				_weiter()
		4:
			if _seit() > o.wf("ortung_takt") + 1.5:
				var t: Dictionary = _welle(int(merk["w1"]))[0]
				var d := Vector2((t["zuletzt"] as Vector2i) - (merk["neu"] as Vector2i)).length()
				pruefe(d <= 3.0 * sqrt(2.0) + 0.01, "nach dem Umzug: neue Ortung %.1f Felder daneben" % d)
				_alle_weg(_welle(int(merk["w1"])))
				_weiter()
		5:
			if _seit() > 2.0:
				var enden := tk.protokoll.filter(func(x: Dictionary) -> bool: return str(x["was"]) == "trupp_ende" and int(x["welle"]) == int(merk["w1"]))
				pruefe(not enden.is_empty() and enden.all(func(x: Dictionary) -> bool: return int(x["ueberlebende"]) == 0 and int(x["verluste"]) > 0), "Trupp-Ende mit Verlusten und Überlebenden (%s)" % str(enden.map(func(x: Dictionary) -> String: return "%d/%d" % [int(x["verluste"]), int(x["ueberlebende"])])))
				merk["brakk"] = o.karte.mitte(merk["neu"] as Vector2i)
				_zange_start()
				_weiter()
		6:
			var trupps := _welle(int(merk["w2"]))
			var zu := trupps.filter(func(t: Dictionary) -> bool: return bool(t.get("zu", false)))
			if not merk.has("seiten") and trupps.all(func(t: Dictionary) -> bool: return t.has("anflug") or bool(t.get("zu", false))):
				var w: Array = trupps.filter(func(t: Dictionary) -> bool: return t.has("anflug")).map(func(t: Dictionary) -> float: return float((t["anflug"] as Dictionary)["winkel"]))
				merk["seiten"] = w
			if zu.size() == trupps.size() or _seit() > 80.0:
				var w: Array = merk.get("seiten", [])
				if w.size() < 2 and _nochmal("z", k):   # an dieser Stelle der Karte gab es keine zwei Seiten
					_alle_weg(trupps)
					merk.erase("seiten")
					_zange_start()
					merk["t"] = o.zeit
					return false
				var abstand := absf(angle_difference(float(w[0]), float(w[1]))) if w.size() >= 2 else 0.0
				pruefe(trupps.size() == 2 and w.size() == 2 and abstand >= deg_to_rad(80.0), "Zange: 2 Trupps auf getrennten Seiten (%.0f° auseinander)" % rad_to_deg(abstand))
				pruefe(zu.size() == trupps.size() and float(merk.get("zange_zeile", 0.0)) > 0.0, "Zange: gemeinsamer Zugriff nach %.0f s, Zeile „%s“" % [_seit(), str(merk.get("zeile", ""))])
				_alle_weg(trupps)
				_feuerschutz_start(k)
				_weiter()
		7:
			var t: Dictionary = merk["fs"]
			var feuer: Array = tk._gruppe_von(t, "feuer")
			for e: Einheit in feuer:
				if true:   # in Reichweite mit Sicht
					var d := e.position.distance_to(k.position) / Werte.ZELLE
					if d <= e.reichweite_jetzt() + 0.6 and d >= 2.0 and o.karte.sicht_frei(e.position, k.position):
						merk["feuer_ok"] = true
						merk["feuer_d"] = d
			var spruenge := tk.protokoll.filter(func(x: Dictionary) -> bool: return str(x["was"]) == "sprung").size() - int(merk.get("sprung0", 0))
			if not (bool(merk.get("feuer_ok", false)) and spruenge > 0) and (_seit() > 100.0 or feuer.is_empty() or str(t["verhalten"]) != "feuerschutz") and _nochmal("f", k):
				_alle_weg([t])   # ungünstige Stelle (keine Sicht, Feuergruppe gefallen …): woanders noch einmal
				merk.erase("feuer_ok")
				merk["sprung0"] = tk.protokoll.filter(func(x: Dictionary) -> bool: return str(x["was"]) == "sprung").size()
				_feuerschutz_start(k)
				merk["t"] = o.zeit
				return false
			if (bool(merk.get("feuer_ok", false)) and spruenge > 0) or _seit() > 100.0:
				pruefe(bool(merk.get("feuer_ok", false)), "Feuerschutz: Feuergruppe steht %.1f Felder entfernt, mit Sicht, in Reichweite" % float(merk.get("feuer_d", -1.0)))
				pruefe(spruenge > 0 and str(t["verhalten"]) == "feuerschutz", "Feuerschutz: Sturmgruppe rückt in Sprüngen vor (%d Halte)" % spruenge)
				# Brakk geht auf die Feuergruppe los
				if not feuer.is_empty():
					var f0 := feuer[0] as Einheit
					merk["brakk"] = f0.position + (k.position - f0.position).normalized() * 1.0 * Werte.ZELLE   # 1 Feld vor ihm, freie Sicht
				_weiter()
		8:
			if _seit() > 2.5:
				var t: Dictionary = merk["fs"]
				pruefe(str(t["verhalten"]) == "sturm" and tk.drueckt(t["mitglieder"][0] as Einheit), "Feuerschutz: greift Brakk die Feuergruppe an, stürmen alle")
				_alle_weg([t])
				merk["brakk"] = o.karte.mitte(merk["neu"] as Vector2i)
				k.position = merk["brakk"]
				_hinterhalt_start(k)
				_weiter()
		9:
			var t: Dictionary = merk["hh"]
			if str(t["verhalten"]) != "hinterhalt":
				var grund := str(tk.protokoll.filter(func(x: Dictionary) -> bool: return str(x["was"]) == "sturm").back().get("grund", "?")) if tk.protokoll.any(func(x: Dictionary) -> bool: return str(x["was"]) == "sturm") else "?"
				if _nochmal("h", k):
					print("     Hinterhalt an dieser Stelle nicht möglich (%s) – woanders noch einmal" % grund)
					_alle_weg([t])
					_hinterhalt_start(k)
					merk["t"] = o.zeit
					return false
				pruefe(false, "Hinterhalt kam nie ins Versteck (%s)" % grund)
				return _fertig()
			var a: Dictionary = t["hinterhalt"]
			var mitte: Vector2 = t.get("mitte", Vector2.INF)
			if mitte.distance_to(o.karte.mitte(a["punkt"] as Vector2i)) <= 1.5 * Werte.ZELLE or _seit() > 60.0:
				var p := o.karte.mitte(a["punkt"] as Vector2i)
				var d := p.distance_to(k.position) / Werte.ZELLE
				pruefe(not o.karte.sicht_frei(p, o.karte.mitte(t["zuletzt"] as Vector2i)) and d >= 3.0 and d <= 14.0, "Hinterhalt: Versteck außer Sicht, %.1f Felder vor Brakk" % d)
				pruefe(str(t["verhalten"]) == "hinterhalt" and not tk.drueckt(t["mitglieder"][0] as Einheit), "Hinterhalt: wartet, schießt nicht im Gehen")
				merk["warte_mitte"] = mitte
				_weiter()
		10:
			if _seit() > 4.0:
				var t: Dictionary = merk["hh"]
				var mitte: Vector2 = t.get("mitte", Vector2.INF)
				pruefe(mitte.distance_to(merk["warte_mitte"] as Vector2) <= 2.0 * Werte.ZELLE and str(t["verhalten"]) == "hinterhalt", "Hinterhalt: bleibt liegen")
				merk["brakk"] = mitte + Vector2(4.0 * Werte.ZELLE, 0.0)   # Brakk kommt auf 4 Felder heran
				_weiter()
		11:
			if _seit() > 2.0:
				var t: Dictionary = merk["hh"]
				pruefe(str(t["verhalten"]) == "sturm" and tk.zeile == "Hinterhalt!", "Hinterhalt löst aus: Sturm, Zeile „%s“" % tk.zeile)
				_alle_weg([t])
				merk["brakk"] = o.karte.mitte(merk["neu"] as Vector2i)
				k.position = merk["brakk"]
				o.werte["ortung_ungenau"] = 0
				_hinterhalt_start(k, true)
				o.werte["ortung_ungenau"] = 3
				merk["hh_start"] = o.zeit
				_weiter()
		12:
			var t: Dictionary = merk["hh"]
			if str(t["verhalten"]) == "sturm" or _seit() > 40.0:
				var nach := o.zeit - float(merk["hh_start"])
				var letzter: Dictionary = tk.protokoll.filter(func(x: Dictionary) -> bool: return str(x["was"]) == "sturm").back()
				pruefe(str(t["verhalten"]) == "sturm" and (str(letzter["grund"]) == "keine Begegnung" and absf(nach - o.wf("hinterhalt_warten")) < 2.5 or str(letzter["grund"]) == "kein Versteck"), "Hinterhalt ohne Kontakt: nach %.0f s Sturm (%s)" % [nach, str(letzter["grund"])])
				_alle_weg([t])
				_aus_test()
				_weiter()
		13:
			return _fertig()
	return false


# ------------------------------------------------------------------ Bausteine

func _wahl() -> void:
	var zaehl := {}
	var doppelt := 0
	tk.letzte = ""
	for i in 3000:
		var t := tk.waehle(12, 3)
		if t != "sturm" and t == tk.letzte:
			doppelt += 1
		tk.letzte = t
		zaehl[t] = int(zaehl.get(t, 0)) + 1
	pruefe(doppelt == 0, "Zange, Feuerschutz und Hinterhalt nie zweimal hintereinander")
	pruefe(zaehl.size() == 4 and int(zaehl["sturm"]) > int(zaehl["zange"]) and int(zaehl["sturm"]) > int(zaehl["hinterhalt"]) and int(zaehl["sturm"]) > int(zaehl["feuerschutz"]), "alle vier kommen vor, Sturm am häufigsten %s" % str(zaehl))
	var klein := {}
	for i in 500:
		klein[tk.waehle(3, 0)] = true
	pruefe(not klein.has("zange") and not klein.has("feuerschutz"), "3 Mann ohne Fernkämpfer: weder Zange noch Feuerschutz %s" % str(klein.keys()))
	var fs := {}
	tk.letzte = ""
	for i in 500:
		fs[tk.waehle(5, 1)] = true
	pruefe(not fs.has("feuerschutz") and not fs.has("zange"), "5 Mann mit einem Fernkämpfer: kein Feuerschutz, keine Zange")
	tk.letzte = ""
	pruefe(BrakkJagdtaktik.nemesis_name("zange") == "flanke" and BrakkJagdtaktik.nemesis_name("feuerschutz") == "sperrfeuer" and Werte.NEMESIS_TAKTIKEN.has(BrakkJagdtaktik.nemesis_name("hinterhalt")), "Namen wie die Nemesis-Taktiken")


## Ein freies Feld, das von der Quelle der Wellen weit weg (25–40 Felder) und zu Fuß erreichbar ist.
func _weit_weg() -> Vector2i:
	var q := _quelle()
	var start := o.karte.zelle_bei((spiel.kommandant as Kommandant).position)
	var raus := q
	for c: Vector2i in o.karte.ausgang(q):
		raus = c   # das Feld, über das die Truppen die Fabrik verlassen
		break
	var beste := Vector2i(-1, -1)
	var wert := -INF
	for y in range(0, Werte.ZEILEN):
		for x in range(Werte.ZONE_SPALTEN, Werte.SPALTEN):
			var z := Vector2i(x, y)
			if not o.karte.ist_begehbar(z) or not o.karte.ist_frei(z):
				continue
			var d := Vector2(z - q).length()
			if d < 14.0 or x < Werte.ZONE_SPALTEN + 3 or y < 3 or y > Werte.ZEILEN - 4:
				continue   # nicht am Rand und nicht in der Ecke am Myriaden-HQ
			var frei := 0
			for dy in range(-2, 3):
				for dx in range(-2, 3):
					if o.karte.in_karte(z + Vector2i(dx, dy)) and o.karte.ist_frei(z + Vector2i(dx, dy)) and o.karte.ist_begehbar(z + Vector2i(dx, dy)):
						frei += 1
			if frei < 16:
				continue   # offener Platz, keine Tasche
			var w := randf()   # jedes Mal ein anderer Platz
			if w > wert and (z == start or not o.karte.einheiten_weg(start, z).is_empty()) and not o.karte.einheiten_weg(raus, z).is_empty():
				wert = w
				beste = z
	if beste.x < 0:
		pruefe(false, "kein Testplatz für Brakk gefunden")
		return start
	return beste


## Ein Szenario hängt an der Stelle der Karte (Engstelle, keine Sicht, kein Versteck): bis zu 3 Versuche, jeweils mit
## Brakk an einem neuen Platz. Gibt false, wenn die Versuche aufgebraucht sind (dann zählt das Ergebnis).
func _nochmal(art: String, k: Kommandant) -> bool:
	var n := int(merk.get("versuch_" + art, 1))
	if n >= 3:
		return false
	merk["versuch_" + art] = n + 1
	merk["neu"] = _weit_weg()
	merk["brakk"] = o.karte.mitte(merk["neu"] as Vector2i)
	k.position = merk["brakk"]
	print("     %s: neuer Versuch %d, Brakk bei %s" % [art, n + 1, str(merk["neu"])])
	return true


func _quelle() -> Vector2i:
	for z: Vector2i in spiel.fabriken:
		if not o.fabrik_hp.has(z) and str(spiel.fabriken[z]["typ"]) != "pilot":
			return z
	return Vector2i(-1, -1)


func _anderer_platz(k: Kommandant) -> Vector2i:
	var von := o.karte.zelle_bei(k.position)
	for r in range(10, 20):
		for d: Vector2i in [Vector2i(r, 0), Vector2i(0, r), Vector2i(0, -r), Vector2i(r, r)]:
			var z := von + d
			if o.karte.in_karte(z) and z.x >= Werte.ZONE_SPALTEN and o.karte.ist_begehbar(z) and o.karte.ist_frei(z) and not o.karte.einheiten_weg(von, z).is_empty():
				return z
	return von


func _truppen(arten: Array) -> Array:
	var neu: Array = []
	var quelle: Vector2i = Vector2i(-1, -1)
	for z: Vector2i in spiel.fabriken:
		if not o.fabrik_hp.has(z) and str(spiel.fabriken[z]["typ"]) != "pilot":
			quelle = z
	for a: String in arten:
		neu.append(o._neue_truppe(a, quelle, 1))
	return neu


func _zange_start() -> void:
	o.wellen += 1
	merk["w2"] = o.wellen
	tk.welle(_truppen(["technogunner", "technogunner", "technogunner", "technogunner", "technogunner", "technogunner", "technogunner", "technogunner"]), o.wellen, "zange")
	merk["zeile"] = tk.zeile
	merk["zange_zeile"] = 1.0 if tk.zeile.begins_with("Jagdtrupp: Zange von ") and tk.zeile.contains(" und ") else 0.0


func _feuerschutz_start(_k: Kommandant) -> void:
	o.wellen += 1
	tk.welle(_truppen(["scharfschuetze", "scharfschuetze", "technogunner", "technogunner", "technogunner", "technogunner"]), o.wellen, "feuerschutz")
	merk["fs"] = _welle(o.wellen)[0]
	var t: Dictionary = merk["fs"]
	var feuer := (t["rollen"] as Dictionary).values().filter(func(r: String) -> bool: return r == "feuer").size()
	pruefe(feuer == 2 and str(t["verhalten"]) == "feuerschutz" and tk.zeile == "Jagdtrupp: Feuerschutz", "Feuerschutz: 2 Scharfschützen in der Feuergruppe, 4 stürmen")


func _hinterhalt_start(_k: Kommandant, hinbeamen: bool = false) -> void:
	var zeile_vorher := tk.zeile
	for versuch in 6:
		o.wellen += 1
		tk.welle(_truppen(["technogunner", "technogunner", "technogunner", "plasmawerfer"]), o.wellen, "hinterhalt")
		merk["hh"] = _welle(o.wellen)[0]
		if str((merk["hh"] as Dictionary)["verhalten"]) == "hinterhalt":
			break
		_alle_weg([merk["hh"]])   # auf dieser Stelle der Karte kein Versteck – anderswo noch einmal
		merk["neu"] = _weit_weg()
		merk["brakk"] = o.karte.mitte(merk["neu"] as Vector2i)
		(spiel.kommandant as Kommandant).position = merk["brakk"]
	var t: Dictionary = merk["hh"]
	if hinbeamen and t.has("hinterhalt"):
		for e: Variant in t["mitglieder"]:
			(e as Einheit).position = o.karte.mitte((t["hinterhalt"] as Dictionary)["punkt"] as Vector2i)
			(e as Einheit)._punkte.clear()
	if not merk.has("hh_still"):
		merk["hh_still"] = true
		pruefe(tk.zeile == zeile_vorher, "Hinterhalt wird erst beim Auslösen angesagt")


## Regel taktik_an = false: das alte Verhalten (Streife, keine Taktik).
func _aus_test() -> void:
	o.werte["taktik_an"] = false
	var vorher := o.trupps.size()
	o._jagdwelle()
	var neu := o.trupps.slice(vorher)
	pruefe(not tk.an() and not neu.is_empty() and neu.all(func(t: Dictionary) -> bool: return not t.has("taktik")), "taktik_an aus: altes Verhalten ohne Taktik")
	o.werte["taktik_an"] = true
