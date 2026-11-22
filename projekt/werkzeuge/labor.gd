extends SceneTree
## Balance-Labor, Schnelllauf (Schritt 9a, Teil 3). Bot-Partien headless, so schnell wie möglich, mit fester
## Schrittweite – das Ergebnis ist dasselbe wie im normalen Lauf (gleiche Samen, gleiche Züge).
##
## Partien in diesem Prozess spielen, Ergebnis als JSON-Zeilen anhängen:
##   godot --headless --path . --fixed-fps 60 --audio-driver Dummy -s werkzeuge/labor.gd -- spiele <ausgabe.jsonl> <erster Samen> <Anzahl> <Anführer> <Kaufplan> [tempo=8] [grafik=neu] [runden=20]
## N Partien auf K Prozesse verteilen, Ergebnis nach labor/laeufe/<datum>-<name>.jsonl:
##   godot --headless --path . -s werkzeuge/labor.gd -- verteile <name> <Anzahl> <Prozesse> <Anführer|alle> <Kaufplan> [erster Samen] [tempo=8]
## UCB-Messung über alle Bauweisen (Schritt 9b), abbrechbar und fortsetzbar (gleicher Name):
##   godot --headless --path . -s werkzeuge/labor.gd -- ucb <name> <gesamt> [Prozesse=14] [n_start=5] [n_min=30] [c=0.5] [anfuehrer=alle]
## Anführer: brakk, irrtuermer, sonde7, paul (oder "alle" beim Verteilen). Kaufplan: einfach, zufall.
## tempo = Simulationsschritte je Bild (Ergebnis unabhängig davon), grafik = neu (Standard, rechnet wie HD, ohne 3D) oder hd; klassisch rechnet anders (Trefferzeiten ab Stufe 2 hängen an den Bildern).
##
## Je Partie: Samen, Anführer, Kaufplan, je Runde Leben vorher/nachher, verlorene Checkpoints, Geld zu Beginn der
## Bauphase / beim Start / nach der Welle, Ausgaben nach Art, Schaden und Kills je Bauwerksart, Rundendauer (Spielzeit);
## am Ende Sieg/Niederlage und Runde. Online, Profil, Zwischenstand und partien/ sind dabei hart aus (Labor.sperren()).

const ANFUEHRER: Array[String] = ["brakk", "irrtuermer", "sonde7", "paul"]
const WELLE_MAX_SEK := 900.0   # Spielzeit; länger = Abbruch (hängt fest)

var modus := ""
var args: PackedStringArray
var optionen := {}

# --- spiele
var ausgabe := ""
var samen := 0
var anzahl := 1
var anfuehrer := "brakk"
var kaufplan_name := "einfach"
var tempo := 8.0
var runden_max := 20
var nr := 0
var bot: BotApi
var plan: Variant   # Kaufplan (einfach/zufall) oder Bauweise ("W1:K3")
var schritt := "neu"
var partie: Dictionary
var runde: Dictionary
var t_partie := 0
var _naechster_kauf := 0
var t_alle := 0
var zeiten := {"physik": 0.0, "bild": 0.0, "kauf": 0.0, "bilder": 0}   # Option messen=1: wohin geht die Rechenzeit?

# --- verteile
var kinder: Array = []   # [{"pid", "datei"}]
var ziel_datei := ""
var t_verteilen := 0


func _initialize() -> void:
	args = OS.get_cmdline_user_args()
	var rest: PackedStringArray = []
	for a in args:
		if "=" in a:
			optionen[a.get_slice("=", 0)] = a.get_slice("=", 1)
		else:
			rest.append(a)
	args = rest
	if args.is_empty():
		print("Aufruf: siehe Kopf von werkzeuge/labor.gd")
		quit(1)
		return
	modus = args[0]
	tempo = float(optionen.get("tempo", "8"))
	runden_max = int(optionen.get("runden", "20"))
	Labor.sperren()
	if modus == "spiele":
		ausgabe = args[1]
		samen = int(args[2])
		anzahl = int(args[3])
		anfuehrer = args[4]
		kaufplan_name = args[5]
		OS.set_environment("TD_GRAFIK", str(optionen.get("grafik", "neu")))   # "neu" rechnet wie HD (klassisch nicht: andere Trefferzeiten ab Stufe 2)
		Engine.max_physics_steps_per_frame = maxi(8, ceili(tempo) + 2)
		t_alle = Time.get_ticks_msec()
	elif modus == "verteile":
		_verteile()
	elif modus == "ucb":
		_ucb_start()
	else:
		print("Unbekannter Modus: ", modus)
		quit(1)


func _process(_delta: float) -> bool:
	if optionen.has("messen"):
		zeiten["physik"] += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)
		zeiten["bild"] += Performance.get_monitor(Performance.TIME_PROCESS)
		zeiten["bilder"] += 1
	if modus == "verteile":
		return _warte_auf_kinder()
	if modus == "ucb":
		return _ucb_schritt()
	return _spiele_schritt()


# ------------------------------------------------------------------ spiele

func _spiele_schritt() -> bool:
	match schritt:
		"neu":
			if nr >= anzahl:
				print("LABOR: %d Partien in %.1f s (%.2f s je Partie)" % [anzahl, (Time.get_ticks_msec() - t_alle) / 1000.0, (Time.get_ticks_msec() - t_alle) / 1000.0 / maxf(anzahl, 1)])
				if optionen.has("messen"):
					print("MESSUNG: Simulation (Physik) %.1f s, Bild-Verarbeitung (_process) %.1f s, Einkauf %.1f s, %d Bilder" % [zeiten["physik"], zeiten["bild"], zeiten["kauf"], zeiten["bilder"]])
				return true
			if bot != null:
				bot.spiel.queue_free()
			var s := samen + nr
			bot = BotApi.neue_partie(root, anfuehrer, s)
			partie = {"samen": s, "anfuehrer": anfuehrer, "kaufplan": kaufplan_name, "karte": Werte.karte_name if Werte.karte_name != "" else "paulland", "runden": []}
			if ":" in kaufplan_name:
				plan = _bauweise(kaufplan_name, s)
				partie["wallform"] = kaufplan_name.get_slice(":", 0)
				partie["kaufplan"] = kaufplan_name.get_slice(":", 1)
				partie["variante"] = plan.variante
				partie["wahl"] = ["A", "B"][plan.wahl]
				partie["figur"] = plan.mit_figur
			else:
				plan = Kaufplan.new(kaufplan_name, s)
			t_partie = Time.get_ticks_msec()
			schritt = "warten"
		"warten":
			if bot.bereit():
				bot.spiel._tempo_faktor = tempo
				Engine.time_scale = Werte.SPIELTEMPO * tempo
				schritt = "bauen"
		"bauen":
			var s: Node = bot.spiel
			if s.phase == 2 or s.welle > runden_max:
				return _partie_fertig()
			runde = {"runde": s.welle, "leben_vorher": s.leben, "geld_bauphase": s.budget}
			bot.ausgaben_abholen()
			var t_kauf := Time.get_ticks_usec()
			plan.kaufe(bot)
			zeiten["kauf"] += (Time.get_ticks_usec() - t_kauf) / 1000000.0
			runde["ausgaben"] = bot.ausgaben_abholen()
			runde["geld_start"] = s.budget
			runde["bau"] = _bau_kurz()
			var r := bot.welle_starten()
			if not r["ok"]:
				runde["fehler"] = "Welle startet nicht: " + str(r["grund"])
				partie["runden"].append(runde)
				partie["ergebnis"] = "kein_start"
				return _partie_fertig()
			schritt = "welle"
		"welle":
			var s: Node = bot.spiel
			if s.phase == 1:
				# Gegenangriff (Runde 20): keine Bauphase, aber alles außer Erdwällen darf gebaut werden – nachkaufen
				if s.endkampf:
					if not runde.has("angriffsweg"):
						runde["angriffsweg"] = s.karte.angriffs_pfad.size()   # 0 = die Truppen haben keinen Fußweg zum HQ
						runde["geld_gegenangriff"] = s.budget
						_naechster_kauf = s._kampf_tick
					if s._kampf_tick >= _naechster_kauf and plan is Bauweise:
						_naechster_kauf = s._kampf_tick + roundi(10.0 / Werte.SIM_SCHRITT)
						plan.kaufe(bot)
				if s._kampf_tick * Werte.SIM_SCHRITT > WELLE_MAX_SEK * (3.0 if s.endkampf else 1.0):
					runde["fehler"] = "Welle zu lang"
					partie["ergebnis"] = "abbruch"
					_runde_schliessen()
					return _partie_fertig()
				return false
			_runde_schliessen()
			schritt = "bauen"
	return false


func _runde_schliessen() -> void:
	var s: Node = bot.spiel
	var cps: Array = []
	for f: bool in s.karte.cp_feind:
		cps.append(f)
	runde["leben_nachher"] = s.leben
	runde["checkpoints_verloren"] = int(s._cp_verloren)
	runde["checkpoints_beim_gegner"] = cps
	runde["geld_ende"] = s.budget
	runde["quellen"] = bot.quellen_der_welle()
	runde["sek"] = snappedf(s._kampf_tick * Werte.SIM_SCHRITT, 0.1)
	partie["runden"].append(runde)


func _bau_kurz() -> Dictionary:
	var s: Node = bot.spiel
	var zahl := {}
	for z: Vector2i in s.karte.feld:
		var art := bot._bauwerksart(z)
		zahl[art] = int(zahl.get(art, 0)) + 1
	return {"anzahl": zahl, "weglaenge": s.karte.pfad.size()}


func _partie_fertig() -> bool:
	var s: Node = bot.spiel
	if not partie.has("ergebnis"):
		if s.phase == 2:
			partie["ergebnis"] = s.ausgang if s.ausgang != "" else "niederlage"
		else:
			partie["ergebnis"] = "bis_runde_%d" % runden_max
	partie["runde"] = s.welle
	partie["leben_start"] = Werte.start_leben()
	if plan is Bauweise:
		partie["plan"] = plan.zaehler
	partie["leben"] = s.leben
	partie["sek_echt"] = snappedf((Time.get_ticks_msec() - t_partie) / 1000.0, 0.1)
	var f := FileAccess.open(ausgabe, FileAccess.READ_WRITE if FileAccess.file_exists(ausgabe) else FileAccess.WRITE)
	f.seek_end()
	f.store_line(JSON.stringify(partie))
	f.close()
	print("Partie Samen %d: %s in Runde %d, Leben %d, %.1f s" % [partie["samen"], partie["ergebnis"], partie["runde"], partie["leben"], partie["sek_echt"]])
	nr += 1
	schritt = "neu"
	return false


## Bauweise "W1:K3" für eine Partie: Abwandlung (0–3) und Stufe-3-Wahl (A/B) aus dem Samen gewürfelt (Zuschnitt B),
## mit variante=/wahl= fest einstellbar. figur=1: Brakk wird gekauft.
func _bauweise(name: String, s: int) -> Bauweise:
	var wf: Dictionary = Bauweise.lade_json("wallformen.json")
	var kp: Dictionary = Bauweise.lade_json("kaufplaene.json")
	var w := name.get_slice(":", 0)
	var k := name.get_slice(":", 1)
	var plan_k: Dictionary = (kp[k] as Dictionary).duplicate(true)
	plan_k["anfuehrer"] = kp.get("_anfuehrer", {})
	plan_k["anfuehrer_reserve"] = kp.get("_anfuehrer_reserve", {})
	var variante := int(optionen.get("variante", str(absi(hash([s, "variante"])) % 4)))
	var wahl := int(optionen.get("wahl", str(absi(hash([s, "wahl"])) % 2)))
	return Bauweise.new(wf.get(w, {"art": "keine"}), plan_k, variante, wahl, anfuehrer, str(optionen.get("figur", "0")) == "1", s)


# ------------------------------------------------------------------ verteile

func _verteile() -> void:
	var name := args[1]
	var n := int(args[2])
	var k := maxi(1, int(args[3]))
	var wer := args[4]
	var kp := args[5]
	var erster := int(args[6]) if args.size() > 6 else 1
	var ordner := Labor.ordner_anlegen()
	var datum := Time.get_datetime_string_from_system().replace(":", "").replace("-", "").replace("T", "-")
	ziel_datei = ordner.path_join("%s-%s.jsonl" % [datum, name])
	var liste: Array[String] = ANFUEHRER if wer == "alle" else ([wer] as Array[String])
	# Aufträge: je Anführer n Partien, in Blöcke für die Prozesse geschnitten
	var auftraege: Array = []
	for a: String in liste:
		var je := ceili(float(n) / k)
		var start := erster
		var rest := n
		while rest > 0:
			var m := mini(je, rest)
			auftraege.append([a, start, m])
			start += m
			rest -= m
	var exe := OS.get_executable_path()
	var projekt := ProjectSettings.globalize_path("res://")
	var i := 0
	for auf: Array in auftraege:
		var datei := ordner.path_join(".teil-%s-%d.jsonl" % [datum, i])
		var p := ["--headless", "--path", projekt, "--fixed-fps", "60", "--audio-driver", "Dummy", "-s", "werkzeuge/labor.gd", "--",
				"spiele", datei, str(auf[1]), str(auf[2]), auf[0], kp, "tempo=" + str(optionen.get("tempo", "8")), "runden=" + str(runden_max)]
		var pid := OS.create_process(exe, p)
		kinder.append({"pid": pid, "datei": datei, "auftrag": auf})
		i += 1
	t_verteilen = Time.get_ticks_msec()
	print("LABOR: %d Prozesse für %d Partien gestartet (%s), Ziel %s" % [kinder.size(), n * liste.size(), ", ".join(PackedStringArray(liste)), ziel_datei])
	print("Hinweis: %d Kerne. Mehr Prozesse als Kerne bringen nichts." % OS.get_processor_count())


func _warte_auf_kinder() -> bool:
	for kind: Dictionary in kinder:
		if OS.is_process_running(int(kind["pid"])):
			return false
	var aus := FileAccess.open(ziel_datei, FileAccess.WRITE)
	var zahl := 0
	var siege := 0
	for kind: Dictionary in kinder:
		if not FileAccess.file_exists(kind["datei"]):
			print("FEHLT: Ergebnis von ", kind["auftrag"])
			continue
		for zeile in FileAccess.get_file_as_string(kind["datei"]).split("\n", false):
			aus.store_line(zeile)
			zahl += 1
			var p: Variant = JSON.parse_string(zeile)
			if p is Dictionary and str(p.get("ergebnis", "")) == "sieg":
				siege += 1
		DirAccess.remove_absolute(kind["datei"])
	aus.close()
	var sek := (Time.get_ticks_msec() - t_verteilen) / 1000.0
	print("LABOR: %d Partien in %.1f s gesammelt (%.2f s je Partie über alle Prozesse), %d Siege → %s" % [zahl, sek, sek / maxf(zahl, 1), siege, ziel_datei])
	return true



# ------------------------------------------------------------------ ucb (Schritt 9b)
## Arme = Anführer × Wallform × Kaufplan (Zuschnitt B: Abwandlung und Stufe-3-Wahl je Partie gewürfelt), dazu je
## Anführer der Zufalls-Käufer. Erst n_start Partien je Arm, dann UCB (Mittelwert + c * sqrt(ln t / n)) bis gesamt
## vergeben ist, zuletzt jeder Arm auf mindestens n_min. Wert einer Partie = erreichte Runde / 20, bei Sieg dazu
## Restleben / Startleben. Jede fertige Partie wird sofort angehängt (labor/laeufe/ucb-<name>.jsonl); ein Neustart
## mit demselben Namen liest die Datei, sammelt liegengebliebene Teilergebnisse ein und macht weiter.

const UCB_ANFUEHRER: Array[String] = ["brakk", "brakk+figur", "irrtuermer", "sonde7", "paul"]
var ucb_datei := ""
var ucb_tmp := ""
var ucb_arme: Array[String] = []
var ucb_stat := {}          # Arm -> {"n", "summe", "laufend"}
var ucb_kinder: Array = []  # [{"pid", "datei", "arm", "samen"}]
var ucb_samen := 100000
var ucb_gesamt := 0
var ucb_vergeben := 0
var ucb_fertig_neu := 0
var ucb_n_start := 5
var ucb_n_min := 30
var ucb_c := 0.5
var ucb_prozesse := 14
var ucb_t0 := 0
var ucb_bekannt := {}       # Samen, die schon in der Datei stehen


func _ucb_start() -> void:
	var name := args[1]
	ucb_gesamt = int(args[2])
	ucb_prozesse = int(args[3]) if args.size() > 3 else 14
	ucb_n_start = int(optionen.get("n_start", "5"))
	ucb_n_min = int(optionen.get("n_min", "30"))
	ucb_c = float(optionen.get("c", "0.5"))
	var nur := str(optionen.get("anfuehrer", "alle"))
	var ordner := Labor.ordner_anlegen()
	ucb_datei = ordner.path_join("ucb-%s.jsonl" % name)
	ucb_tmp = ordner.path_join(".tmp-" + name)
	DirAccess.make_dir_recursive_absolute(ucb_tmp)
	var wallformen: Array = (Bauweise.lade_json("wallformen.json") as Dictionary).keys()
	var kaufplaene: Array = (Bauweise.lade_json("kaufplaene.json") as Dictionary).keys().filter(func(k: String) -> bool: return not k.begins_with("_") and k != "Z")
	wallformen.sort()
	kaufplaene.sort()
	for a: String in UCB_ANFUEHRER:
		if nur != "alle" and not a.begins_with(nur):
			continue
		for w: String in wallformen:
			for k: String in kaufplaene:
				ucb_arme.append("%s|%s|%s" % [a, w, k])
		ucb_arme.append("%s|-|Z" % a)
	if optionen.has("filter"):
		ucb_arme = ucb_arme.filter(func(arm: String) -> bool: return str(optionen["filter"]) in arm)   # zum Testen: nur Arme mit diesem Text
	for arm in ucb_arme:
		ucb_stat[arm] = {"n": 0, "summe": 0.0, "laufend": 0}
	# Fortsetzen: vorhandene Ergebnisse und liegengebliebene Teilergebnisse
	if FileAccess.file_exists(ucb_datei):
		for zeile in FileAccess.get_file_as_string(ucb_datei).split("\n", false):
			_ucb_zaehle(JSON.parse_string(zeile), false)
	for f in DirAccess.get_files_at(ucb_tmp):
		var pfad := ucb_tmp.path_join(f)
		for zeile in FileAccess.get_file_as_string(pfad).split("\n", false):
			_ucb_zaehle(JSON.parse_string(zeile), true)
		DirAccess.remove_absolute(pfad)
	var n := 0
	for arm in ucb_stat:
		n += int(ucb_stat[arm]["n"])
	ucb_vergeben = n
	ucb_t0 = Time.get_ticks_msec()
	print("UCB: %d Arme, %d Partien schon da, zu Beginn %d je Arm, UCB bis %d vergeben, dann jeder Arm mindestens %d; %d Prozesse -> %s" % [ucb_arme.size(), n, ucb_n_start, ucb_gesamt, ucb_n_min, ucb_prozesse, ucb_datei])


static func _arm_von(p: Dictionary) -> String:
	var a := str(p.get("anfuehrer", "brakk")) + ("+figur" if bool(p.get("figur", false)) else "")
	return "%s|%s|%s" % [a, str(p.get("wallform", "-")), str(p.get("kaufplan", "?"))]


static func wert(p: Dictionary) -> float:
	var w := float(mini(int(p.get("runde", 0)), 20)) / 20.0
	if str(p.get("ergebnis", "")) == "sieg":
		w += float(p.get("leben", 0)) / maxf(float(p.get("leben_start", 15)), 1.0)
	return w


func _ucb_zaehle(p: Variant, neu: bool) -> void:
	if not (p is Dictionary):
		return
	var s := int(p.get("samen", 0))
	ucb_samen = maxi(ucb_samen, s + 1)
	if ucb_bekannt.has(s):
		return
	ucb_bekannt[s] = true
	var arm := _arm_von(p)
	if not ucb_stat.has(arm):
		ucb_stat[arm] = {"n": 0, "summe": 0.0, "laufend": 0}
	ucb_stat[arm]["n"] = int(ucb_stat[arm]["n"]) + 1
	ucb_stat[arm]["summe"] = float(ucb_stat[arm]["summe"]) + wert(p)
	if neu:
		p["arm"] = arm
		p["wert"] = snappedf(wert(p), 0.001)
		var f := FileAccess.open(ucb_datei, FileAccess.READ_WRITE if FileAccess.file_exists(ucb_datei) else FileAccess.WRITE)
		f.seek_end()
		f.store_line(JSON.stringify(p))
		f.close()


func _ucb_naechster_arm() -> String:
	var bester := ""
	var beste := -INF
	# 1) jeder Arm n_start Partien
	for arm in ucb_arme:
		var n := int(ucb_stat[arm]["n"]) + int(ucb_stat[arm]["laufend"])
		if n < ucb_n_start and -n > beste:
			beste = -n
			bester = arm
	if bester != "":
		return bester
	# 2) UCB, bis gesamt vergeben ist
	if ucb_vergeben < ucb_gesamt:
		var t := 0
		for arm in ucb_arme:
			t += int(ucb_stat[arm]["n"])
		for arm in ucb_arme:
			var st: Dictionary = ucb_stat[arm]
			var n := maxi(int(st["n"]), 1)
			var n_eff := int(st["n"]) + int(st["laufend"])
			var mittel := float(st["summe"]) / n
			var u := mittel + ucb_c * sqrt(log(maxf(t, 2.0)) / maxf(n_eff, 1.0))
			if u > beste:
				beste = u
				bester = arm
		return bester
	# 3) jeder Arm mindestens n_min
	for arm in ucb_arme:
		var n := int(ucb_stat[arm]["n"]) + int(ucb_stat[arm]["laufend"])
		if n < ucb_n_min and -n > beste:
			beste = -n
			bester = arm
	return bester


func _ucb_schritt() -> bool:
	# fertige Kinder einsammeln
	for i in range(ucb_kinder.size() - 1, -1, -1):
		var kind: Dictionary = ucb_kinder[i]
		if OS.is_process_running(int(kind["pid"])):
			continue
		ucb_kinder.remove_at(i)
		ucb_stat[kind["arm"]]["laufend"] = int(ucb_stat[kind["arm"]]["laufend"]) - 1
		if FileAccess.file_exists(kind["datei"]):
			for zeile in FileAccess.get_file_as_string(kind["datei"]).split("\n", false):
				_ucb_zaehle(JSON.parse_string(zeile), true)
			DirAccess.remove_absolute(kind["datei"])
			ucb_fertig_neu += 1
			if ucb_fertig_neu % 25 == 0:
				_ucb_stand()
		else:
			print("UCB: keine Ausgabe von Samen %d (%s) - Partie zählt nicht" % [kind["samen"], kind["arm"]])
	# neue starten
	while ucb_kinder.size() < ucb_prozesse:
		var arm := _ucb_naechster_arm()
		if arm == "":
			break
		var teile := arm.split("|")
		var a := teile[0].get_slice("+", 0)
		var figur := "1" if teile[0].ends_with("+figur") else "0"
		var samen_jetzt := ucb_samen
		ucb_samen += 1
		var datei := ucb_tmp.path_join("%d.jsonl" % samen_jetzt)
		var p := ["--headless", "--path", ProjectSettings.globalize_path("res://"), "--fixed-fps", "60", "--audio-driver", "Dummy", "-s", "werkzeuge/labor.gd", "--",
				"spiele", datei, str(samen_jetzt), "1", a, "%s:%s" % [teile[1], teile[2]], "figur=" + figur, "tempo=8", "runden=20"]
		var pid := OS.create_process(OS.get_executable_path(), p)
		ucb_kinder.append({"pid": pid, "datei": datei, "arm": arm, "samen": samen_jetzt})
		ucb_stat[arm]["laufend"] = int(ucb_stat[arm]["laufend"]) + 1
		ucb_vergeben += 1
	if ucb_kinder.is_empty():
		_ucb_stand()
		print("UCB: fertig.")
		return true
	return false


func _ucb_stand() -> void:
	var n := 0
	var fehlend := 0
	for arm in ucb_arme:
		n += int(ucb_stat[arm]["n"])
		fehlend += maxi(0, ucb_n_min - int(ucb_stat[arm]["n"]))
	var sek := (Time.get_ticks_msec() - ucb_t0) / 1000.0
	var je := sek / maxf(ucb_fertig_neu, 1)
	var rest := maxi(ucb_gesamt - ucb_vergeben, 0) + fehlend
	print("UCB: %d Partien (%d neu in %.0f min, %.1f s je Partie), noch etwa %d -> %.1f h" % [n, ucb_fertig_neu, sek / 60.0, je, rest, rest * je / 3600.0])
