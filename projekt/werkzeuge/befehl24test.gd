extends SceneTree
## 20.11. (Ergänzung Befehl 24): Prüft die neuen Regeln des Brakk-Mode Rogue headless.
##
##   godot --headless --path . --fixed-fps 60 -s werkzeuge/befehl24test.gd -- [Formation]
##
## Brakk nimmt keinen Schaden (brakk_schaden 0) und steht still; der Test ruft die Regeln direkt auf und lässt die Zeit laufen.
## Geprüft: Sichtlinie durch Wälle, Sprengladung (Wall weg, Formturm schweigt), Turmkern (20 s Ausfall), Ersatz aus der
## Fabrik, Sabotage mit Pilot, Zerstörung, Phasenwechsel nach Zeit. Am Ende „TEST BEFEHL24 OK“ oder die Fehler.
## Schreibt wie das Spiel in user:// – vorher sichern.

var spiel: Node
var o: Order24
var warte := 10
var schritt := 0
var uhr := 0.0                  # Order-24-Zeit beim Beginn des Schritts
var fehler: Array[String] = []
var merk := {}
var phasen := false             # Lauf „phasen“: Ablauf mit verkürzten Zeiten
var _sprung := 0.0
var modi_gesehen := {}


func _initialize() -> void:
	Nemesis.datei = "user://nemesis_test.json"   # 22.11.: Tests schreiben nie in die echte Liste der Meistgesuchten
	Nemesis.zuruecksetzen()
	var a := OS.get_cmdline_user_args()
	OS.set_environment("TD_KARTE_NAME", "szenario_order24")
	Werte.lade_karte("szenario_order24")
	var r: Dictionary = (Werte.KARTE_REGELN.get("order24", {}) as Dictionary).duplicate()
	phasen = a.size() > 0 and a[0] == "phasen"
	r["karte"] = a[0] if a.size() > 0 and not phasen else (a[1] if a.size() > 1 else "3-zitadelle")
	r["brakk_schaden"] = 0
	r["ueberleben_sek"] = 2000
	r["geheim_ab"] = 0
	if phasen:
		var kurz := {"flucht_sek": 5, "jagd_start": 20, "vorstoss_start": 40, "vorstoss_sek": 5, "welle_takt": 6, "welle_takt_min": 3, "eskalation_sek": 30,
			"welle_wachsen_sek": 10, "stufe2_ab": 30, "faehigkeit_ab": 45, "lager_neu_ab": 25, "lager_neu_takt": 8, "tore_ab": 30, "tore_takt": 4,
			"elite_jede": 3, "ueberleben_sek": 0, "geheim_ab": 60, "myr_takt": 5, "geheim_cp_sek": 5, "geheim_hq_leben": 300, "sicht_verlust": 3, "such_sek": 4}
		for k: String in kurz:
			r[k] = kurz[k]
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
			(tafel as Control).visible = false   # headless klickt niemand „Los“
		return false
	var k: Kommandant = spiel.kommandant
	k.leben = k.max_leben
	var karte: Karte = spiel.karte
	if phasen:
		_phasen_lauf(k, karte)
		return false
	match schritt:
		0:
			_sicht(karte)
			_weiter()
		1:
			# Besatzung steht nach dem Schnellstart
			if o.zeit - uhr > 3.0:
				var voll := true
				for z: Vector2i in o.fabrik_hp:
					if (spiel.fabriken[z]["einheiten"] as Array).size() < o.truppen_limit(z):
						voll = false
				pruefe(voll and not o._schnellstart, "Besatzung der Fabriken draußen steht nach dem Start (%d Fabriken)" % o.fabrik_hp.size())
				_weiter()
		2:
			_sprengen_start(karte)
			_weiter()
		3:
			if o.zeit - uhr > o.wf("spreng_zuender") + 0.5:
				var s: Vector2i = merk["stuetze"]
				var t: Vector2i = merk["turm"]
				pruefe(karte.inhalt(s) != Karte.WALL, "Sprengladung: Erdwall %s ist weg" % str(s))
				pruefe(not karte.turm_aktiv(t), "Sprengladung: Formturm %s (%s) schweigt ohne Stütze" % [str(t), str(karte.turm_art.get(t, "?"))])
				pruefe(o.ladungen == 0, "Sprengladung: Gepäck wieder leer")
				_weiter()
		4:
			_kern_start(karte)
			_weiter()
		5:
			var t: Vector2i = merk["kern"]
			if o.zeit - uhr > 5.0 and not merk.has("kern_halb"):
				merk["kern_halb"] = true
				pruefe(not karte.turm_aktiv(t), "Turmkern: nach 5 s noch aus")
			if is_instance_valid(o.pilot):
				merk["kern_pilot"] = true
			if karte.turm_aktiv(t) and float(o.kern.get(t, 0.0)) >= o.wf("kern_leben"):
				pruefe(merk.has("kern_pilot") or o._instand_nah(t), "Turmkern: nach %.0f s repariert (Pilot oder Instandsetzung), Kern voll" % (o.zeit - uhr))
				_weiter()
			elif o.zeit - uhr > 90.0:
				pruefe(false, "Turmkern: nach 90 s nicht repariert")
				_weiter()
		6:
			_ersatz_start()
			_weiter()
		7:
			var z: Vector2i = merk["ersatz_fabrik"]
			var n := (spiel.fabriken[z]["einheiten"] as Array).size()
			if n >= int(merk["ersatz_soll"]) and not merk.has("ersatz_da"):
				merk["ersatz_da"] = o.zeit - uhr
			if o.zeit - uhr > o.wf("produktion_sek") * 2.0 + 2.0:
				var da := float(merk.get("ersatz_da", -1.0))
				pruefe(da > o.wf("produktion_sek") * 0.6 and da <= o.wf("produktion_sek") * 2.0 + 1.0, "Ersatz: Fabrik liefert nach %.1f s (Zyklus %d s)" % [da, int(o.w("produktion_sek"))])
				_weiter()
		8:
			_sabotage_start(k, karte)
			_weiter()
		9:
			var z: Vector2i = merk["sabo"]
			if not merk.has("sabo_fertig") and o.lahm.has(z):
				merk["sabo_fertig"] = o.zeit - uhr
				pruefe(karte.ausgefallen.has(z), "Sabotage: Fabrik %s nach %.1f s lahm" % [str(z), o.zeit - uhr])
				print("INFO Sabotage: Alarm für %d Truppen am Boden" % o.alarm.size())
				var st := [0, 0, 0, 0]
				for e in spiel.einheiten:
					if is_instance_valid(e) and e != k:
						st[(e as Einheit).zustand] += 1
				print("INFO Truppen: zum Posten %d · auf Posten %d · Boden %d · Batterie %d" % st)
				uhr = o.zeit
			elif merk.has("sabo_fertig"):
				if is_instance_valid(o.pilot) and not merk.has("pilot_los") and not o.reparaturziel(o.pilot).is_empty():
					merk["pilot_los"] = o.zeit - uhr
					pruefe(absf(o.zeit - uhr - o.wf("pilot_verzug")) < 1.5 and o.eskorte.size() == 2, "Pilot: los nach %.1f s mit %d Begleitern" % [o.zeit - uhr, o.eskorte.size()])
				if not karte.ausgefallen.has(z):
					pruefe(merk.has("pilot_los") and (o.wf("sabotage_lahm") <= 0.0 or o.zeit - uhr < o.wf("sabotage_lahm")), "Pilot: Fabrik nach %.1f s repariert (ohne Pilot erst nach %d s)" % [o.zeit - uhr, int(o.w("sabotage_lahm"))])
					_weiter()
				elif o.zeit - uhr > (o.wf("sabotage_lahm") if o.wf("sabotage_lahm") > 0.0 else 120.0) + 2.0:
					pruefe(false, "Pilot: Fabrik nicht repariert")
					_weiter()
			elif not merk.has("dbg"):
				merk["dbg"] = true
				print("DBG sabo=%s pos=%s rueck=%s ego=%s" % [str(o.sabo), str(k.position), str(karte.mitte(o.rueckseite[merk["sabo"]])), str(spiel.ego != null)])
			elif o.zeit - uhr > 8.0:
				pruefe(false, "Sabotage: nicht fertig geworden (Brakk %s)" % str(karte.zelle_bei(k.position)))
				_weiter()
		10:
			_zerstoeren()
			_weiter()
		11:
			_phasen_pruefen()
			_f4_balance()
			if fehler.is_empty():
				print("TEST BEFEHL24 OK")
			else:
				print("TEST BEFEHL24 FEHLER %d: %s" % [fehler.size(), str(fehler)])
			quit(0 if fehler.is_empty() else 1)
	return false


func _weiter() -> void:
	schritt += 1
	uhr = o.zeit


## Sichtlinie: Stellung A, daneben Wall B (verbunden), Ziel hinter B. Mit Befehl-24-Regel versperrt B, sonst nicht.
func _sicht(karte: Karte) -> void:
	for y in range(1, Werte.ZEILEN - 1):
		for x in range(Werte.ZONE_SPALTEN + 1, Werte.SPALTEN - 5):
			var a := Vector2i(x, y)
			var b := a + Vector2i(1, 0)
			var c := a + Vector2i(3, 0)
			if karte.ist_bebaubar(a) and karte.ist_bebaubar(b) and karte.ist_begehbar(a - Vector2i(1, 0)) and karte.ist_frei(a - Vector2i(1, 0)) and karte.ist_begehbar(a - Vector2i(2, 0)) and karte.ist_frei(a - Vector2i(2, 0)) and karte.ist_begehbar(a + Vector2i(2, 0)) and karte.ist_frei(a + Vector2i(2, 0)) and karte.ist_begehbar(c) and karte.ist_frei(c):
				karte.setze(a, Karte.WALL)
				karte.setze(b, Karte.WALL)
				karte.baue_aus(a, Karte.STELLUNG)
				var von := karte.mitte(a)
				var nach := karte.mitte(c)
				var mit := karte.sicht_von_wall(a, von, nach)
				karte.sicht_eigenes_feld = false
				var ohne := karte.sicht_von_wall(a, von, nach)
				karte.sicht_eigenes_feld = true
				pruefe(not mit and ohne, "Sichtlinie: verbundener Wall %s versperrt der Stellung %s die Sicht (Befehl 24: %s, normal: %s)" % [str(b), str(a), str(mit), str(ohne)])
				var frei := karte.sicht_von_wall(a, von, karte.mitte(a + Vector2i(-2, 0)))
				pruefe(frei, "Sichtlinie: über das eigene Feld hinaus frei")
				karte.entferne(a)
				karte.entferne(b)
				return
	pruefe(false, "Sichtlinie: kein Platz für den Aufbau gefunden")


## Sprengladung auf eine Stütze eines Formturms.
func _sprengen_start(karte: Karte) -> void:
	for t: Vector2i in karte.ausbau:
		if karte.ausbau[t] != Karte.TURM or not karte.turm_aktiv(t) or karte.turm_art.get(t, "") == "heil":
			continue
		var st: Array = karte.stuetzen.get(t, [])
		if st.is_empty():
			continue
		merk["turm"] = t
		merk["stuetze"] = st[0]
		o.ladungen = 1
		var grund := o.ladung_setzen(st[0] as Vector2i)
		pruefe(grund == "", "Sprengladung gesetzt auf %s (Stütze von %s) %s" % [str(st[0]), str(t), grund])
		return
	pruefe(false, "Sprengladung: kein Formturm mit Stütze auf der Karte")
	merk["turm"] = Vector2i.ZERO
	merk["stuetze"] = Vector2i.ZERO


func _kern_start(karte: Karte) -> void:
	for t: Vector2i in o.kern:
		if karte.turm_aktiv(t) and not o._instand_nah(t):
			merk["kern"] = t
			o.kern_treffer(t, o.wf("kern_leben") * 0.5)
			pruefe(karte.turm_aktiv(t), "Turmkern: halb leer läuft der Turm noch")
			o.kern_treffer(t, o.wf("kern_leben"))
			pruefe(not karte.turm_aktiv(t), "Turmkern %s leer geschossen: Turm aus" % str(t))
			return
	for t: Vector2i in o.kern:
		if karte.turm_aktiv(t):
			merk["kern"] = t
			o.kern_treffer(t, o.wf("kern_leben") * 2.0)
			pruefe(not karte.turm_aktiv(t), "Turmkern %s leer geschossen: Turm aus (Heilturm in der Nähe)" % str(t))
			return
	pruefe(false, "Turmkern: kein laufender Turm")
	merk["kern"] = Vector2i.ZERO


## Ersatz: eine Truppe einer Fabrik draußen fällt, die Fabrik liefert im nächsten Zyklus nach.
func _ersatz_start() -> void:
	for z: Vector2i in o.fabrik_hp:
		var liste: Array = spiel.fabriken[z]["einheiten"]
		if liste.size() >= o.truppen_limit(z) and not liste.is_empty():
			merk["ersatz_fabrik"] = z
			merk["ersatz_soll"] = liste.size()
			var e: Einheit = liste[0]
			e.nimm_schaden(99999.0)
			return


## Brakk an die Rückseite einer Fabrik, [E] gedrückt halten (der Test hält die Taste einfach nicht los).
func _sabotage_start(k: Kommandant, karte: Karte) -> void:
	for z: Vector2i in o.rueckseite:
		var r: Vector2i = o.rueckseite[z]
		if r == Karte.KEINE or z == merk.get("ersatz_fabrik", Karte.KEINE) or not o.fabrik_hp.has(z):
			continue
		k.position = karte.mitte(r)
		k.anker = k.position
		merk["sabo"] = z
		pruefe(o.ego_taste(spiel.ego, "F", true) if spiel.ego != null else o.sabotage_start(), "Sabotage: [F] an der Rückseite von %s" % str(z))
		return
	pruefe(false, "Sabotage: keine Fabrik mit Rückseite")
	merk["sabo"] = Vector2i.ZERO


func _zerstoeren() -> void:
	for z: Vector2i in o.fabrik_hp.keys():
		if z == merk.get("sabo", Karte.KEINE):
			continue
		var vorher := int(o.sabotage["fabriken"])
		o.fabrik_treffer(z, o.wf("fabrik_leben") * 0.5)
		pruefe(spiel.fabriken.has(z), "Zerstörung: halbe Leben – Fabrik %s steht noch" % str(z))
		o.fabrik_treffer(z, o.wf("fabrik_leben"))
		pruefe(not spiel.fabriken.has(z) and o.truemmer.has(z) and int(o.sabotage["fabriken"]) == vorher + 1, "Zerstörung: Fabrik %s ist Trümmer" % str(z))
		pruefe(o.truppen_limit(z) == -1, "Zerstörung: kommt nicht wieder")
		return


## F4 (26.11., Paul): Werte und Gold. Erst die Goldsumme dieses Laufs (Sabotage, Zerstörung, Kills), dann eine
## typische Folge von Einnahmen – beides −20 % ± 2.
func _f4_balance() -> void:
	var s := Order24.STANDARD
	pruefe(int(s["welle_takt"]) == 45 and int(s["welle_takt_min"]) == 19 and int(s["fabrik_leben"]) == 1380 and int(s["pilot_verzug"]) == 25 and int(s["pilot_neu"]) == 30 and int(s["pilot_reparatur"]) == 5 and is_equal_approx(float(s["gold_faktor"]), 0.8),
		"F4: Wellentakt 45/19 s, Fabrik 1380 Leben, Pilot 25/30/5 s, Gold × 0,8")
	var lauf := float(o.sabotage["geld"]) / maxf(1.0, float(o.gold_roh))
	pruefe(o.gold_roh > 0 and absf(lauf - 0.8) <= 0.02, "F4: Gold dieses Laufs %d statt %d (%.1f %%)" % [int(o.sabotage["geld"]), o.gold_roh, (lauf - 1.0) * 100.0])
	var roh_vorher := o.gold_roh
	var summe := 0
	var folge: Array[int] = []
	for i in 120:
		folge.append(7)   # Kopfgeld
	for i in 12:
		folge.append(21)   # Elite
	folge.append_array([200, 200, 100, 100, 100, 50])   # Fabriken, Sabotagen, Beute-Gold, Ausschalten
	var roh := 0
	for b: int in folge:
		roh += b
		summe += o.gold(b)
	pruefe(absf(float(summe) / float(roh) - 0.8) <= 0.02 and o.gold_roh - roh_vorher == roh, "F4: typische Folge %d statt %d Gold (%.1f %%)" % [summe, roh, (float(summe) / float(roh) - 1.0) * 100.0])


## Phasen nach Zeit (Stellschrauben): Flucht → Sabotage → Jagd → Vorstoß.
func _phasen_pruefen() -> void:
	if not o.has_method("phase_bei"):
		return
	var flucht: float = o.wf("flucht_sek")
	var jagd: float = o.wf("jagd_start")
	var vorstoss: float = o.wf("vorstoss_start")
	pruefe(o.phase_bei(flucht * 0.5, 0) == "flucht", "Phase: Flucht bei %.0f s" % (flucht * 0.5))
	pruefe(o.phase_bei(flucht + 1.0, 0) == "sabotage", "Phase: Sabotage ab %.0f s" % flucht)
	pruefe(o.phase_bei(flucht + 1.0, int(o.w("sabotage_ende_fabriken"))) == "jagd", "Phase: Jagd schon, wenn %d Fabriken zerstört sind" % int(o.w("sabotage_ende_fabriken")))
	pruefe(o.phase_bei(jagd + 1.0, 0) == "jagd", "Phase: Jagd ab %.0f s" % jagd)
	pruefe(o.phase_bei(vorstoss + 1.0, 0) == "vorstoss", "Phase: Vorstoß ab %.0f s" % vorstoss)


## Ablauf mit verkürzten Zeiten (Flucht 5 s, Jagd 20 s, versteckter Vorstoß 40 s, Überläufer 60 s, Wellen alle 6 → 3 s).
## Brakk springt bis zum Überläufer alle 9 s weit weg (so verlieren ihn die Trupps: suchen, dann Streife). Der Test hält
## das Myriaden-HQ (räumt Technoclan-Truppen dort ab, sobald Brakk den Vorstoß bemerkt hat), damit der geheime Verlauf beginnt.
func _phasen_lauf(k: Kommandant, karte: Karte) -> void:
	var t := o.zeit
	if o.vorbei or spiel.phase == 2:
		pruefe(o.geheim_sieg, "Ende: Technoclan-HQ zerstört – geheimes Ende nach %.0f s" % t)
		var b: Dictionary = spiel.ego._sieg_bericht if spiel.ego != null else o.bericht(true)
		pruefe(str(b.get("kopf", "")).begins_with("ÜBERLÄUFER") and str(b.get("titel", "")) in ["Saboteur", "Geist", "Berserker"], "Siegbild: %s · Spielstil %s" % [str(b.get("kopf", "")), str(b.get("titel", ""))])
		pruefe(modi_gesehen.has("suche") and modi_gesehen.has("streife"), "Jagdtrupps: verlieren Brakk, suchen, gehen wieder Streife (%s)" % str(modi_gesehen.keys()))
		print("TEST BEFEHL24 OK" if fehler.is_empty() else "TEST BEFEHL24 FEHLER %d: %s" % [fehler.size(), str(fehler)])
		quit(0 if fehler.is_empty() else 1)
		return
	if t > 150.0:
		pruefe(false, "Kein Ende nach 150 s (Überläufer %s, Schild aus %s, HQ %.0f)" % [str(o.geheim), str(o.hq_schild_aus), o.tc_hq_leben])
		print("TEST BEFEHL24 FEHLER %d: %s" % [fehler.size(), str(fehler)])
		quit(1)
		return
	for tr: Dictionary in o.trupps:
		modi_gesehen[str(tr["modus"])] = true
	if t > 2.0 and not merk.has("p_flucht"):
		merk["p_flucht"] = true
		pruefe(o.phase() == "flucht" and o.trupps.is_empty(), "Phase bei %.0f s: Flucht, niemand jagt" % t)
	if t > 10.0 and not merk.has("p_sabo"):
		merk["p_sabo"] = true
		pruefe(o.phase() == "sabotage" and not o.jagd, "Phase bei %.0f s: Sabotage, noch keine Jagd" % t)
	if t > 21.5 and not merk.has("p_jagd"):
		merk["p_jagd"] = true
		merk["erste_jaeger"] = o.jaeger.keys()
		var groessen: Array = o.trupps.map(func(x: Dictionary) -> int: return (x["mitglieder"] as Array).size())
		var alle := o._truppen().filter(func(x: Variant) -> bool: return not o._ist_innen(x as Einheit)).size()
		pruefe(o.jagd and o.phase() == "jagd", "Phase bei %.0f s: Jagd (Stufe 2)" % t)
		var passt := true
		for g: int in groessen:
			if g < int(o.w("trupp_min")) or g > int(o.w("trupp_max")):
				passt = false
		pruefe(passt or groessen.size() == 1, "Jagd: Trupps zu %d–%d (%s)" % [int(o.w("trupp_min")), int(o.w("trupp_max")), str(groessen)])
		pruefe(absf(float(o.jaeger.size()) / float(maxi(1, alle)) - o.wf("jagd_anteil") / 100.0) < 0.15, "Jagd: %d von %d Truppen jagen (Soll %d %%)" % [o.jaeger.size(), alle, int(o.w("jagd_anteil"))])
	if t > 34.0 and not merk.has("p_raus"):
		merk["p_raus"] = true
		var unterwegs := 0
		var n := 0
		for id: int in (merk.get("erste_jaeger", []) as Array):
			var e: Variant = instance_from_id(id)
			if is_instance_valid(e):
				n += 1
				var hier := karte.zelle_bei((e as Node2D).position)
				var zz: Vector2i = o.marschziel(e as Einheit)
				if zz != Karte.KEINE and (hier.distance_to(zz) <= 1.5 or not karte.einheiten_weg(hier, zz).is_empty()):
					unterwegs += 1
		pruefe(n > 0 and float(unterwegs) / float(n) >= 0.8, "Jagd: Jäger haben einen Weg zu ihrem Ziel (%d von %d)" % [unterwegs, n])
	if t > 38.0 and not merk.has("p_wellen"):
		merk["p_wellen"] = true
		var elite := false
		for tr: Dictionary in o.trupps:
			var m: Array = (tr["mitglieder"] as Array).filter(func(x: Variant) -> bool: return is_instance_valid(x))
			if m.size() == 3 and m.all(func(x: Variant) -> bool: return bool((x as Einheit).daten.get("elite", false))):
				elite = true
		pruefe(o.wellen >= 3 and elite, "Wellen aus dem Schild: %d nach %.0f s, darunter ein Elitetrupp aus drei" % [o.wellen, t])
		pruefe(o.welle_takt_jetzt() < o.wf("welle_takt"), "Eskalation: Wellentakt %.1f s (Start %d s)" % [o.welle_takt_jetzt(), int(o.w("welle_takt"))])
		pruefe(o.fabrik_hp.size() > int(merk.get("lager_start", 0)), "Eskalation: neues Lager gebaut (%d Lager)" % o.fabrik_hp.size())
		pruefe(o.tore_gesetzt >= 1 or o.tor_versuche >= 1, "Eskalation: Tore in den Wällen – %d gesetzt, %d geprüft" % [o.tore_gesetzt, o.tor_versuche])
	if not merk.has("lager_start"):
		merk["lager_start"] = o.fabrik_hp.size()
	if t > 52.0 and not merk.has("p_faehig"):
		merk["p_faehig"] = true
		var faehig := 0
		for e in o._truppen():
			if str((e as Einheit).faehigkeit) != "":
				faehig += 1
		pruefe(faehig > 0, "Eskalation: Wellen mit Fähigkeiten (%d Truppen)" % faehig)
		pruefe(o.phase_text().find("Vorstoß") < 0, "Versteckter Vorstoß: die Anzeige verrät nichts (%s)" % o.phase_text())
		print("INFO Brakk hat den Vorstoß bemerkt: %s (Einnahme %d %%)" % [str(o._brakk_ahnt), roundi(o.vorstoss_anteil * 100.0)])
	# Brakk hält das Myriaden-HQ: wer dort steht, fällt (sobald Brakk es bemerkt hat)
	if o._brakk_ahnt and not o.geheim:
		var hq := karte.mitte(Werte.ANGRIFFS_ZELLE)
		for e in o._truppen():
			if (e as Node2D).position.distance_to(hq) <= 2.0 * Werte.ZELLE:
				(e as Einheit).nimm_schaden(99999.0)
	if o.geheim and not merk.has("p_geheim"):
		merk["p_geheim"] = true
		pruefe(not o.hq_eingenommen and karte.cp_aktiv, "Überläufer beginnt bei %.0f s (Myriaden-HQ gehalten)" % t)
		spiel.budget = 2000
		var gebaut := 0
		for y in range(1, Werte.ZEILEN - 1):
			for x in Werte.ZONE_SPALTEN:
				if gebaut < 3 and o.myr_bauen(Order24.MYR_TYPEN[gebaut], Vector2i(x, y), karte.mitte(Vector2i(x, y))) == "":
					gebaut += 1
		pruefe(gebaut == 3 and o.myr_fabriken.size() == 3, "Überläufer: 3 Myriaden-Fabriken in der Zone gebaut")
		pruefe(o.myr_bauen("hund", Vector2i(Werte.ZONE_SPALTEN + 2, 3), karte.mitte(Vector2i(Werte.ZONE_SPALTEN + 2, 3))) != "", "Überläufer: außerhalb der Zone wird nicht gebaut")
		merk["geheim_t"] = t
	if o.geheim and merk.has("geheim_t"):
		var seit := t - float(merk["geheim_t"])
		if seit > o.wf("myr_takt") + 1.0 and not merk.has("p_myr"):
			merk["p_myr"] = true
			var myr: int = spiel.gegner.filter(func(g: Variant) -> bool: return not (g is Order24.BrakkZiel)).size()
			pruefe(myr > 0, "Überläufer: Myriaden-Welle läuft (%d Myriaden)" % myr)
			for i in karte.checkpoints.size():
				spiel.checkpoint_erreicht(i)   # Brakk und die Myriaden haben beide Checkpoints
		if merk.has("p_myr") and not merk.has("p_schild"):
			for i in karte.checkpoints.size():
				karte.cp_feind[i] = true   # halten
			if o.hq_schild_aus:
				merk["p_schild"] = true
				pruefe(true, "Überläufer: beide Checkpoints gehalten – Schild des Technoclan-HQ gefallen")
				var ziel: Gegner = null
				for z: Gegner in o.ego_ziele():
					if (z as Order24.TechnoZiel).art == "hq":
						ziel = z
				o._ziele_pflegen()
				for z: Gegner in o.ego_ziele():
					if (z as Order24.TechnoZiel).art == "hq":
						ziel = z
				pruefe(ziel != null, "Überläufer: Technoclan-HQ ist ein Ziel für Brakks Waffen")
				if ziel != null:
					spiel.schadensquelle = "fabrik:-1,-1"
					ziel.nimm_schaden(99999.0)
					spiel.schadensquelle = ""
				else:
					o._tc_hq_treffer(99999.0)
	# Brakk springt weit weg (Brakks Tempo verunsichert die KI)
	if t >= _sprung and t > 22.0 and not o.geheim:
		_sprung = t + 9.0
		var hier := karte.zelle_bei(k.position)
		for versuch in 60:
			var z := Vector2i(randi_range(Werte.ZONE_SPALTEN, Werte.SPALTEN - 2), randi_range(1, Werte.ZEILEN - 2))
			if karte.ist_begehbar(z) and karte.ist_frei(z) and Vector2(z - hier).length() > 12.0 and not o._im_schild(karte.mitte(z)):
				k.position = karte.mitte(z)
				k.anker = k.position
				break
