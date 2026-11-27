extends SceneTree
## 26.11. (Paul, Prompt D): Befehl 24 – Spielfluss-Fixes, headless.
##
##   godot --headless --path . --fixed-fps 60 -s werkzeuge/spielflusstest.gd
##
## Brakk nimmt keinen Schaden. Ohne Argument: Sabotage endet bei 1:00, Sprengladungen am Boden (20 s, höchstens 4), Einnahme-Ring.
##   -- ueberlaeufer: Checkpoint mit [F] 3 s, Myriaden zielen nicht auf Brakk.
##   -- schild: Schildbesatzung – Streife zu zweit am Schildrand, schießt hinaus, Ausfall, Pause.
## Am Ende „TEST SPIELFLUSS OK“ oder die Fehler. Schreibt nur user://nemesis_spielfluss_test.json.

var spiel: Node
var o: Order24
var warte := 10
var schritt := 0
var fehler: Array[String] = []
var merk := {}


func _initialize() -> void:
	Nemesis.datei = "user://nemesis_spielfluss_test.json"
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
	r["jagd_start"] = 9999
	r["vorstoss"] = false
	r["herausforderer"] = false
	if OS.get_cmdline_user_args().has("ueberlaeufer"):
		r["geheim_ab"] = 3   # Überläufer-Verlauf gleich zu Beginn
		schritt = 20
	if OS.get_cmdline_user_args().has("schild"):
		r["hq_aggro_radius"] = 1   # sonst rücken alle Verteidiger aus, sobald Brakk am Schild steht (hq_aggro, bleibt)
		schritt = 30
	Order24.test_werte = r
	var main_skript: GDScript = load("res://scripts/main.gd")
	main_skript.set("naechster_start", "normal")
	spiel = load("res://main.tscn").instantiate()
	root.add_child(spiel)
	spiel.protokoll_an = false


func pruefe(ok: bool, text: String) -> void:
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
	print("TEST SPIELFLUSS OK" if fehler.is_empty() else "TEST SPIELFLUSS FEHLER (%d): %s" % [fehler.size(), "; ".join(PackedStringArray(fehler))])
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
		var tafel: Variant = spiel.ego.anzeige.get("_briefing") if spiel.ego != null else null
		if tafel != null and (tafel as Control).visible:
			(tafel as Control).visible = false
		return false
	var k: Kommandant = spiel.kommandant
	k.leben = k.max_leben
	if merk.has("brakk"):
		k.position = merk["brakk"]
		k.oben = false
	if o.vorbei:
		pruefe(false, "Lauf vorzeitig vorbei (Schritt %d)" % schritt)
		return _fertig()
	if _seit() > 120.0:
		pruefe(false, "Schritt %d hängt" % schritt)
		return _fertig()
	return _schritte(k)


func _gefallene() -> Array:
	return o.ladungen_boden.filter(func(l: Dictionary) -> bool: return not bool(l.get("bleibt", false)))


func _schritte(k: Kommandant) -> bool:
	match schritt:
		0:
			pruefe(int(Order24.STANDARD["jagd_start"]) == 60, "Sabotage endet bei 1:00 (jagd_start %d)" % int(Order24.STANDARD["jagd_start"]))
			merk["brakk"] = k.position
			merk["bleibt"] = o.ladungen_boden.filter(func(l: Dictionary) -> bool: return bool(l.get("bleibt", false))).size()
			# fünf Ladungen weit weg von Brakk fallen lassen, je 1 s versetzt
			merk["n"] = 0
			_weiter()
		1:
			if _seit() >= float(merk["n"]) and int(merk["n"]) < 5:
				o.ladung_fallen_lassen(k.position + Vector2(8.0 + float(merk["n"]), 0.0) * Werte.ZELLE)
				merk["n"] = int(merk["n"]) + 1
				if int(merk["n"]) == 1:
					merk["erste"] = _gefallene()[0]
			if int(merk["n"]) >= 5:
				var g := _gefallene()
				pruefe(g.size() == 4, "höchstens 4 liegen (%d)" % g.size())
				pruefe(not g.has(merk["erste"]), "die älteste ist bei der fünften verschwunden")
				_weiter()
		2:
			if _seit() >= 20.5:   # die letzte fiel kurz vor diesem Schritt: nach 20 s Liegezeit liegt keine mehr
				var g := _gefallene()
				pruefe(g.size() == 0, "nach 20 s liegt keine mehr (%d)" % g.size())
				var b := o.ladungen_boden.size() - g.size()
				pruefe(b == int(merk["bleibt"]), "die Ladung am Myriaden-HQ bleibt (%d von %d)" % [b, int(merk["bleibt"])])
				_weiter()
		3:
			# Einnahme-Ring: eine Truppe steht am Myriaden-HQ (als Vorstoß-Trupp), Brakk weit weg
			var hq: Vector2 = spiel.karte.mitte(Werte.ANGRIFFS_ZELLE)
			merk["hq"] = hq
			merk["e"] = o._truppen()[0]
			merk["trupp"] = {"modus": "vorstoss", "mitglieder": [merk["e"]]}
			o.trupps.append(merk["trupp"])
			merk["brakk"] = hq + Vector2(10.0, 0.0) * Werte.ZELLE
			o.vorstoss_anteil = 0.0
			merk["mess"] = 0.0
			_weiter()
		4, 5, 6:
			_ring_schritt(k)
		7:
			o.trupps.erase(merk["trupp"])
			merk["paare"] = 0
			merk["dicht"] = 0
			_weiter()
		8:
			# Mindestabstand: Bodentruppen stehen nicht aufeinander (unter 0,45 Feldern zählt als dicht)
			var boden := o._truppen().filter(func(e: Variant) -> bool: return (e as Einheit).zustand == Einheit.Zustand.BODEN)
			for i in boden.size():
				for j in range(i + 1, boden.size()):
					var d: float = (boden[i] as Node2D).position.distance_to((boden[j] as Node2D).position)
					if d < 1.5 * Werte.ZELLE:
						merk["paare"] = int(merk["paare"]) + 1
						if d < 0.45 * Werte.ZELLE:
							merk["dicht"] = int(merk["dicht"]) + 1
			if _seit() >= 10.0:
				var anteil := float(merk["dicht"]) / maxf(1.0, float(merk["paare"]))
				print("     Abstand: %d Nachbarpaare-Messungen, davon dicht %d (%.1f %%)" % [int(merk["paare"]), int(merk["dicht"]), 100.0 * anteil])
				pruefe(anteil < 0.05, "Mindestabstand: höchstens 5 %% der Nachbarn dichter als 0,45 Felder (%.1f %%)" % (100.0 * anteil))
				return _fertig()
		20, 21, 22, 23, 24:
			_cp_schritt(k)
		25:
			return _fertig()
		30, 31, 32, 33, 34:
			_schild_schritt(k)
		35:
			return _fertig()
	return false


func _innen() -> Array:
	return o._truppen().filter(func(e: Variant) -> bool: return o.schildwache.besatzung(e as Einheit))


## 26.11.: Schildbesatzung – Streife zu zweit im Schild, schießt durch die Kante, Ausfall bei Sicht, Pause danach.
func _schild_schritt(k: Kommandant) -> void:
	var karte: Karte = spiel.karte
	var sw: BrakkSchildwache = o.schildwache
	var m: Vector2 = o.schild_mitten[0]
	var rad := Order24.SCHILD_RADIUS * Werte.ZELLE
	match schritt:
		30:
			merk["brakk"] = karte.mitte(Werte.ANGRIFFS_ZELLE) + Vector2(2.0, 0.0) * Werte.ZELLE
			merk["weg"] = {}
			merk["pos"] = {}
			merk["raus"] = 0.0
			merk["warin"] = {}
			_weiter()
		31:
			for e: Einheit in _innen():
				var id := e.get_instance_id()
				if (merk["pos"] as Dictionary).has(id):
					merk["weg"][id] = float(merk["weg"].get(id, 0.0)) + e.position.distance_to(merk["pos"][id])
				merk["pos"][id] = e.position
				if e.position.distance_to(m) <= rad:
					merk["warin"][id] = true
				# nur wer schon im Schild war und gerade Streife geht (Alarm und Nemesis gehen vor; wer von draußen zurückkommt, zählt erst drinnen)
				if (merk["warin"] as Dictionary).has(id) and (sw._ring.get(0, []) as Array).has(o.marschziel(e)):
					merk["raus"] = maxf(float(merk["raus"]), e.position.distance_to(m) / Werte.ZELLE)
			if _seit() >= 25.0:
				var n: int = (merk["warin"] as Dictionary).size()
				var laufen := (merk["warin"] as Dictionary).keys().filter(func(id: int) -> bool: return float(merk["weg"].get(id, 0.0)) >= 3.0 * Werte.ZELLE).size()
				print("     Besatzung %d · laufen %d · weiteste vom Schildmittelpunkt %.1f Felder · Paare %s" % [n, laufen, float(merk["raus"]), str(sw._paar.values().map(func(p: Array) -> int: return p.size()))])
				pruefe(n >= 5 and laufen * 2 >= n, "die Besatzung geht Streife (%d von %d laufen ≥ 3 Felder; wer in einer abgetrennten Tasche steht, bleibt auf Posten)" % [laufen, n])
				pruefe(float(merk["raus"]) < Order24.SCHILD_RADIUS + 1.3, "Streife bleibt am Schildrand (höchstens %.1f Felder von der Mitte)" % float(merk["raus"]))
				pruefe(sw._paar.values().all(func(p: Array) -> bool: return p.size() == 2) or sw._paar.values().filter(func(p: Array) -> bool: return p.size() == 1).size() <= 1, "zu zweit (höchstens einer allein)")
				pruefe(sw.ausfaelle == 0, "ohne Brakk kein Ausfall")
				# Brakk knapp vor den Schild, dorthin, wo er die meisten Ringfelder sieht
				var beste := Vector2i(-1, -1)
				var bd := INF
				var bn := 0
				for y in range(0, Werte.ZEILEN):
					for x in range(Werte.ZONE_SPALTEN, Werte.SPALTEN):
						var z := Vector2i(x, y)
						var d := karte.mitte(z).distance_to(m) / Werte.ZELLE
						if not karte.ist_begehbar(z) or not karte.ist_frei(z) or d <= Order24.SCHILD_RADIUS + 0.6 or d > Order24.SCHILD_RADIUS + 3.0:
							continue
						var sicht := (sw._ring.get(0, []) as Array).filter(func(r: Vector2i) -> bool: return karte.sicht_frei(karte.mitte(z), karte.mitte(r))).size()
						if sicht > bn or (sicht == bn and d < bd):
							bn = sicht
							bd = d
							beste = z
				merk["brakk"] = karte.mitte(beste)
				print("     Brakk vor den Schild: %s (%.1f Felder von der Mitte, sieht %d Ringfelder)" % [str(beste), bd, bn])
				_weiter()
		32:
			_durch(m, rad)
			if sw.ausfaelle >= 1 and not merk.has("start") and not sw.ausfall.is_empty():
				merk["start"] = o.zeit
			if merk.has("start"):
				pruefe(sw.ausfall.size() == 1 and (sw.ausfall[0]["paar"] as Array).size() <= 2, "Ausfall zu zweit")
				merk["paar"] = (sw.ausfall[0]["paar"] as Array).duplicate()
				_weiter()
			elif _seit() > 20.0:
				pruefe(false, "kein Ausfall, obwohl Brakk vor dem Schild steht")
				schritt = 35
		33:
			_durch(m, rad)
			for e: Variant in merk["paar"]:
				if is_instance_valid(e) and ((e as Node2D).position.distance_to(m) > rad or (e as Node2D).position.distance_to(k.position) <= 2.0 * Werte.ZELLE):
					merk["draussen"] = true   # aus dem Schild – oder bis an Brakk heran, der an der Kante steht
			pruefe(sw.ausfall.size() <= 1, "höchstens ein Ausfall je Schild") if sw.ausfall.size() > 1 else null
			if sw.ausfall.is_empty():
				var dauer: float = o.zeit - float(merk["start"])
				pruefe(merk.has("draussen"), "das Paar läuft auf Brakk zu (aus dem Schild oder bis auf 2 Felder)")
				pruefe(dauer <= o.wf("ausfall_sek") + 1.5, "Ausfall endet nach höchstens 15 s (%.1f s)" % dauer)
				merk["ende"] = o.zeit
				_weiter()
			elif o.zeit - float(merk["start"]) > 20.0:
				pruefe(false, "Ausfall endet nicht")
				schritt = 35
		34:
			_durch(m, rad)
			if sw.ausfaelle >= 2:
				pruefe(merk.has("durch"), "die Besatzung schießt aus dem Schild heraus auf Brakk")
				var pause: float = o.zeit - float(merk["ende"])
				pruefe(pause >= o.wf("ausfall_pause") - 1.0, "nächster Ausfall erst nach der Pause (%.1f s)" % pause)
				_weiter()
			elif o.zeit - float(merk["ende"]) > 35.0:
				pruefe(false, "nach der Pause kein neuer Ausfall")
				schritt = 35
			elif o.zeit - float(merk["ende"]) > 12.0 and not merk.has("zurueck"):
				merk["zurueck"] = true
				var drin := 0
				for e: Variant in merk["paar"]:
					if is_instance_valid(e) and (e as Node2D).position.distance_to(m) <= rad + 1.5 * Werte.ZELLE:   # steht Brakk an der Kante, kämpfen sie dort
						drin += 1
				pruefe(drin >= 1, "das Paar ist nach 12 s zurück am Schild (%d)" % drin)


## 26.11.: Überläufer – Checkpoint nur mit [F] 3 s, Loslassen setzt zurück, Myriaden zielen nicht auf Brakk.
func _cp_schritt(k: Kommandant) -> void:
	var karte: Karte = spiel.karte
	if schritt == 20:
		if not o.geheim:
			if _seit() > 30.0:
				pruefe(false, "Überläufer-Verlauf beginnt nicht")
				schritt = 25
			return
		pruefe(spiel.naechste_bodeneinheit(k.position, 0.3 * Werte.ZELLE) != k, "Nahkampf der Myriaden wählt Brakk nicht")
		pruefe(spiel.fernziel(k.position + Vector2(Werte.ZELLE, 0.0), 1.5 * Werte.ZELLE, 2) != k, "Fernkampf der Myriaden wählt Brakk nicht")
		var cp: Vector2i = karte.checkpoints[0]
		var stand := cp
		if not karte.ist_begehbar(stand):
			for n: Vector2i in Karte.NACHBARN:
				if karte.ist_begehbar(cp + n):
					stand = cp + n
					break
		merk["brakk"] = karte.mitte(stand)
		merk["cp"] = karte.mitte(cp)
		_weiter()
		return
	# Technoclan vom Checkpoint fernhalten (sonst sperrt er die Einnahme)
	for e in o._truppen():
		if (e as Node2D).position.distance_to(merk["cp"]) <= 3.0 * Werte.ZELLE:
			(e as Node2D).position = merk["cp"] + Vector2(0.0, 8.0) * Werte.ZELLE
	match schritt:
		21:
			if _seit() >= 4.0:
				pruefe(o.cp_vor_brakk(k) == 0, "Brakk steht am Checkpoint 1")
				pruefe(not karte.cp_feind[0], "ohne [F] kein Wechsel (4 s danebengestanden)")
				o.ego_taste(spiel.ego, "F", true)
				_weiter()
		22:
			if _seit() >= 1.5:
				o.ego_taste(spiel.ego, "F", false)
				pruefe(not karte.cp_feind[0] and float(o.ueberlaeufer._cp_brakk[0]) == 0.0, "[F] nach 1,5 s losgelassen: zurück auf 0")
				o.ego_taste(spiel.ego, "F", true)
				_weiter()
		23:
			if _seit() >= 2.8 and not merk.has("knapp"):
				merk["knapp"] = true
				pruefe(not karte.cp_feind[0], "nach 2,8 s noch nicht eingenommen")
			if _seit() >= 3.3:
				pruefe(karte.cp_feind[0], "nach 3 s [F] Checkpoint für die Myriaden (orange)")
				pruefe(not o.ueberlaeufer._cp_f, "[F] gilt danach als losgelassen")
				o.ego_taste(spiel.ego, "F", false)
				_weiter()
		24:
			pruefe(spiel.naechste_bodeneinheit(k.position, 0.3 * Werte.ZELLE) != k, "auch danach kein Ziel der Myriaden")
			_weiter()


## 26.11.: Einnahme-Ring – Fülltempo ohne Brakk (20 s), mit Brakk in 3 Feldern halb, ohne Truppen Rückgang × 0,35.
func _ring_schritt(k: Kommandant) -> void:
	var dt := 1.0 / 60.0
	var e: Einheit = merk["e"]
	var hq: Vector2 = merk["hq"]
	if not is_instance_valid(e):
		pruefe(false, "Truppe am HQ gefallen")
		schritt = 7
		return
	e.position = hq + Vector2(0.5, 0.0) * Werte.ZELLE if schritt != 6 else hq + Vector2(12.0, 6.0) * Werte.ZELLE
	o._vorstoss(dt)
	if _seit() >= float(merk["mess"]):
		merk["mess"] = float(merk["mess"]) + 2.0
		print("     Ring %s bei %.0f s: %d %% · Zeile „%s“" % [["ohne Brakk", "Brakk am HQ", "ohne Truppen"][schritt - 4], _seit(), roundi(100.0 * o.vorstoss_anteil), o.phase_text()])
	match schritt:
		4:
			if _seit() >= 10.0:
				pruefe(absf(o.vorstoss_anteil - 0.5) < 0.04, "nach 10 s halb voll (%d %%)" % roundi(100.0 * o.vorstoss_anteil))
				pruefe(o._sonde_hq_gemeldet, "Sonde 7 meldet sich bei 50 %")
				pruefe(o.phase_text().contains("HQ %d %%" % floori(100.0 * o.vorstoss_anteil)), "Phasenzeile zeigt „HQ … %%“ („%s“)" % o.phase_text())
				if spiel.hd != null:
					o._3d_pflegen()
					pruefe(o._ring3d != null and o._ring3d.visible, "Ring über dem HQ sichtbar")
				merk["a"] = o.vorstoss_anteil
				merk["brakk"] = hq + Vector2(2.0, 0.0) * Werte.ZELLE
				merk["mess"] = 0.0
				_weiter()
		5:
			if _seit() >= 4.0:
				var plus: float = o.vorstoss_anteil - float(merk["a"])
				pruefe(absf(plus - 0.1) < 0.02, "Brakk in 3 Feldern: halbes Tempo (+%d %% in 4 s, soll 10)" % roundi(100.0 * plus))
				merk["a"] = o.vorstoss_anteil
				merk["brakk"] = hq + Vector2(10.0, 0.0) * Werte.ZELLE
				merk["mess"] = 0.0
				_weiter()
		6:
			if _seit() >= 4.0:
				var minus: float = float(merk["a"]) - o.vorstoss_anteil
				pruefe(absf(minus - 0.07) < 0.015, "ohne Truppen sinkt er mit 0,35 × Fülltempo (−%.1f %% in 4 s, soll 7)" % (100.0 * minus))
				o.vorstoss_anteil = 0.0
				pruefe(not o.einnahme_sichtbar() and not o.phase_text().contains("HQ"), "bei 0 % kein Ring und keine Zeile")
				_weiter()


## Hat eine Truppe aus dem Schild heraus auf Brakk geschossen (Begegnung im Nemesis-Protokoll)?
func _durch(m: Vector2, rad: float) -> void:
	for e: Einheit in _innen():
		if e.position.distance_to(m) < rad + 0.8 * Werte.ZELLE and o.nemesis._begegnung.has(e.get_instance_id()):   # vom Streifenband am Schildrand
			merk["durch"] = true
