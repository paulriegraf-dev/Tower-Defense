class_name Online
extends RefCounted
## Online-Pool der Phantome (18.11.2026, Supabase): Phantome laden und hochladen, Duelle melden (Elo), Rangliste.
## Alles läuft nebenher: Ist keine Verbindung da, spielt das Spiel mit dem eingebauten Pool weiter wie bisher.
## Der Schlüssel unten ist öffentlich (nur Lesen und die zwei Funktionen phantom_hochladen / duell_melden);
## was hochgeladen werden darf, prüft die Datenbank selbst.

const URL := "https://eobvzyzofesmvjupyvys.supabase.co"
const SCHLUESSEL := "sb_publishable_w-ig0uKSfEwrLXoe0N5kxQ_MJR2wRwm"
const ZEITLIMIT := 12.0
const CACHE := "user://Phantom Online"
const FELDER := "id,art,datei,spieler,profil,version,spalten,wertung,elo,spiele,siege,erstellt,anfuehrer:daten-%3E%3Eanfuehrer"   # 22.11.: Anführer aus den Daten (Rangliste)

## 23.11. (Paul): höchstens so viele Phantome je Spieler und Art im Pool (ein neues verdrängt eins – der Spieler wählt);
## in der Rangliste stehen Phantome erst ab LISTE_AB Duellen, Spieler erst ab LISTE_AB Läufen.
const PLAETZE := 3
const LISTE_AB := 5

## "unbekannt", "laedt", "online", "offline"
static var zustand := "unbekannt"
static var listen := {"angriff": [], "verteidigung": []}
static var spieler_listen := {"angriff": [], "verteidigung": []}   # 23.11.: Spieler-Elo (Profil, Name, Elo, Läufe)
static var pfad_id := {}            # lokaler Pfad eines geladenen oder hochgeladenen Phantoms -> ID online
static var ersatz_pfade: Array = [] # Angriff: online gezogene Ersatz-Phantome für die nächste Partie
static var _abgeglichen := false
static var bericht := {}            # 23.11.: Phantom-Bericht (G): was seit dem letzten Besuch mit den eigenen Phantomen geschah
static var geaendert := 0           # zählt hoch, wenn neue Daten da sind (das Menü zeichnet dann neu)


static func _baum() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


## 9a: Balance-Labor – Online-Teil hart aus (keine Rangliste, kein Phantom-Upload, keine Duelle).
static var gesperrt := false

static func aktiv() -> bool:
	if gesperrt:
		return false
	return OS.get_environment("TD_OFFLINE") == "" and DisplayServer.get_name() != "headless" or OS.get_environment("TD_ONLINE") != ""


## 18.11.: Godot liest beim Laden einer JSON-Datei jede Zahl als Kommazahl, und JSON.stringify schreibt sie dann als
## „6.0“ – die Datenbank lehnt das beim Umwandeln in eine Ganzzahl ab („invalid input syntax for type integer“).
## Deshalb gehen ganze Kommazahlen als Ganzzahlen hinaus (echte Kommazahlen bleiben, wie sie sind).
static func _ganzzahlig(v: Variant) -> Variant:
	if v is float:
		var f: float = v
		return int(f) if f == floorf(f) and absf(f) < 1.0e15 else f
	if v is Dictionary:
		var d := {}
		for k: Variant in (v as Dictionary):
			d[k] = _ganzzahlig(v[k])
		return d
	if v is Array:
		var a: Array = []
		for e: Variant in (v as Array):
			a.append(_ganzzahlig(e))
		return a
	return v


## Eine Anfrage an Supabase. Gibt die gelesene Antwort zurück, bei Fehlern null.
static func _anfrage(methode: HTTPClient.Method, pfad: String, koerper: Variant = null) -> Variant:
	var baum := _baum()
	if baum == null or not aktiv():
		return null
	var h := HTTPRequest.new()
	h.timeout = ZEITLIMIT
	await baum.process_frame
	baum.root.add_child(h)
	var kopf := PackedStringArray(["apikey: " + SCHLUESSEL, "Content-Type: application/json", "Accept: application/json"])
	var text := "" if koerper == null else JSON.stringify(_ganzzahlig(koerper))
	var fehler := h.request(URL + pfad, kopf, methode, text)
	if fehler != OK:
		h.queue_free()
		return null
	var antwort: Array = await h.request_completed
	h.queue_free()
	var code := int(antwort[1])
	if int(antwort[0]) != HTTPRequest.RESULT_SUCCESS or code < 200 or code >= 300:
		if OS.is_debug_build():
			print("Online: %s %s -> %d %s" % [methode, pfad.left(80), code, (antwort[3] as PackedByteArray).get_string_from_utf8().left(200)])
		return null
	var roh := (antwort[3] as PackedByteArray).get_string_from_utf8()
	if roh.strip_edges() == "":
		return {}
	return JSON.parse_string(roh)


## Beide Listen holen (ohne die großen Daten). Beim ersten Mal werden eingebaute Pool-Phantome, die online fehlen,
## nachgereicht – so landet der Pool von selbst in der Datenbank.
static func lade_listen() -> void:
	if zustand == "laedt":
		return
	zustand = "laedt"
	var ok := true
	for art: String in ["angriff", "verteidigung"]:
		var basis := "/rest/v1/phantome?select=%s&art=eq.%s&version=eq.%d&order=elo.desc&limit=300"
		var l: Variant = await _anfrage(HTTPClient.METHOD_GET, (basis + "&archiviert=eq.false") % [FELDER, art, Phantom.PHANTOM_VERSION])   # 23.11.: ohne Archiv
		if not (l is Array):   # 23.11.: Datenbank noch ohne Archiv-Spalte
			l = await _anfrage(HTTPClient.METHOD_GET, basis % [FELDER, art, Phantom.PHANTOM_VERSION])
		if not (l is Array):   # 22.11.: Rückfall ohne das Anführer-Feld, falls die Abfrage damit scheitert
			l = await _anfrage(HTTPClient.METHOD_GET, basis % [FELDER.split(",anfuehrer")[0], art, Phantom.PHANTOM_VERSION])
		if l is Array:
			listen[art] = l
		else:
			ok = false
	# 23.11.: Spieler-Elo (fehlt die Tabelle noch, bleibt die Spieler-Ansicht leer – kein Grund für „offline“)
	var sp: Variant = await _anfrage(HTTPClient.METHOD_GET, "/rest/v1/spieler_elo?select=profil,art,spieler,elo,elo_max,spiele,siege,duelle&order=elo.desc&limit=500")   # 24.11.: beste Elo; 24.11. (72): duelle
	if not (sp is Array):
		sp = await _anfrage(HTTPClient.METHOD_GET, "/rest/v1/spieler_elo?select=profil,art,spieler,elo,spiele,siege&order=elo.desc&limit=500")   # Datenbank noch ohne elo_max
	spieler_listen = {"angriff": [], "verteidigung": []}
	if sp is Array:
		for e: Dictionary in (sp as Array):
			if spieler_listen.has(str(e.get("art", ""))):
				(spieler_listen[str(e["art"])] as Array).append(e)
	zustand = "online" if ok else "offline"
	geaendert += 1
	# 18.11.: Erfolg „Spitze“ – Platz 1 in einer der beiden Ranglisten
	for art: String in ["angriff", "verteidigung"]:
		var l: Array = listen[art]
		if not l.is_empty() and str((l[0] as Dictionary).get("profil", "")) == Profil.id():
			Erfolge.melde("spitze")
	if ok and not _abgeglichen:
		_abgeglichen = true
		if await _pool_abgleich():
			await lade_listen()


static func _pool_abgleich() -> bool:
	var neu := false
	for art: String in ["verteidigung", "angriff"]:
		var da := {}
		for e: Dictionary in listen[art]:
			da[str(e["datei"])] = true
		var o := "res://Phantom Dateien/" + str(Phantom.UNTERORDNER[art])
		var dir := DirAccess.open(o)
		if dir == null:
			continue
		for datei: String in dir.get_files():
			if not datei.ends_with(".json") or da.has(datei):
				continue
			var d := Phantom.lade(o + "/" + datei)
			if d.is_empty() or int(d.get("phantom_version", 1)) < Phantom.PHANTOM_VERSION:
				continue
			if await hochladen(art, datei, d, "pool") != "":
				neu = true
	return neu


## Lädt ein Phantom hoch. Gibt die ID zurück ("" = nicht geklappt).
static func hochladen(art: String, datei: String, daten: Dictionary, profil: String = "") -> String:
	var wertung := int((daten.get("ergebnis", {}) as Dictionary).get("wertung", 0))
	var antwort: Variant = await _anfrage(HTTPClient.METHOD_POST, "/rest/v1/rpc/phantom_hochladen", {
		"p_art": art, "p_datei": datei, "p_spieler": str(daten.get("spieler", Profil.GAST)),
		"p_profil": profil if profil != "" else Profil.id(), "p_version": int(daten.get("phantom_version", 1)),
		"p_spalten": int((daten.get("karte", {}) as Dictionary).get("spalten", 28)), "p_wertung": wertung, "p_daten": daten})
	if antwort is String and str(antwort) != "":
		return str(antwort)
	return ""


## Meldet ein Duell: `ergebnis` ist der Anteil für den Angreifer (1 = geknackt, 0 = nichts genommen).
## 23.11.: `mensch` = auf welcher Seite der Spieler selbst gespielt hat ("angriff" / "verteidigung") – zählt für seine
## Spieler-Elo, und das gegnerische Phantom rechnet gegen seine Spieler-Elo. Kennt die Datenbank das noch nicht, ohne.
static func duell(angriff_id: String, verteidigung_id: String, ergebnis: float, wertung: int, mensch: String = "") -> bool:
	if angriff_id == "" and verteidigung_id == "":
		return false
	var koerper := {
		"p_angriff": null if angriff_id == "" else angriff_id, "p_verteidigung": null if verteidigung_id == "" else verteidigung_id,
		"p_ergebnis": clampf(ergebnis, 0.0, 1.0), "p_wertung": wertung, "p_spieler": Profil.name(), "p_profil": Profil.id()}
	if mensch != "":
		koerper["p_mensch"] = mensch
	var antwort: Variant = await _anfrage(HTTPClient.METHOD_POST, "/rest/v1/rpc/duell_melden", koerper)
	if antwort == null and mensch != "":
		koerper.erase("p_mensch")   # Datenbank noch ohne Spieler-Elo
		antwort = await _anfrage(HTTPClient.METHOD_POST, "/rest/v1/rpc/duell_melden", koerper)
	return antwort != null


## 24.11. (Paul, Version 72): Aus den Runden eines vollständigen Angriffs die Duelle je Verteidigung bilden:
## [{pfad, id, phantom_s (für die Phantom-Elo), s (Spieler-Ergebnis), w (Gewicht = Budget der Runden gegen sie), geknackt}]
## in der Reihenfolge, in der die Verteidigungen auftraten. Verteidigungen ohne Online-ID fehlen.
static func lauf_duelle(daten: Dictionary) -> Array:
	var je: Dictionary = {}   # Pfad -> [genommen, geknackt, Runde des Knackens, Runden gegen sie, Budget gegen sie]
	var folge: Array = []
	for r: Dictionary in daten.get("runden", []):
		var g := str(r.get("gegen_pfad", ""))
		if not je.has(g):
			je[g] = [0, false, 0, 0, 0]
			folge.append(g)
		je[g][0] = int(je[g][0]) + int(r.get("leben_genommen", 0))
		je[g][3] = int(je[g][3]) + 1
		je[g][4] = int(je[g][4]) + Phantom.budget(maxi(int(r.get("runde", 1)), 1))
		if r.get("geknackt", false):
			je[g][1] = true
			je[g][2] = int(r.get("runde", 0))
	var aus: Array = []
	for g: String in folge:
		var vid := id_von(g)
		if vid == "":
			continue
		aus.append({"pfad": g, "id": vid,
			"phantom_s": Phantom.duell_ergebnis(int(je[g][0]), bool(je[g][1]), int(je[g][2]), int(je[g][3])),
			"s": Phantom.spieler_ergebnis(int(je[g][0]), bool(je[g][1]), int(je[g][2])),
			"w": float(maxi(int(je[g][4]), 1)), "geknackt": bool(je[g][1])})
	return aus


## 24.11. (Paul, Version 72): Ein ganzer Angriffslauf = EIN Elo-Update der Spieler-Angriffs-Elo (Erwartung und Ergebnis je
## Verteidigung, nach Budget gewichtet gemittelt, K 64; Datenbank `angriff_lauf_melden`). `duelle` = Einträge von lauf_duelle().
## Die Lauf-Nummer macht die Meldung doppelt-sicher. false = Datenbank kennt es nicht (dann zählt der Lauf nicht für die Spieler-Elo).
static func lauf(duelle: Array) -> bool:
	if duelle.is_empty() or Profil.id() == "" or Profil.id() == "pool":
		return false
	var liste: Array = []
	for d: Dictionary in duelle:
		liste.append({"id": d["id"], "s": clampf(float(d["s"]), 0.0, 1.0), "w": float(d["w"])})
	var koerper := {"p_profil": Profil.id(), "p_spieler": Profil.name(),
		"p_lauf": "%s-%d-%d" % [Profil.id(), int(Time.get_unix_time_from_system() * 1000.0), randi()], "p_duelle": liste}
	var antwort: Variant = await _anfrage(HTTPClient.METHOD_POST, "/rest/v1/rpc/angriff_lauf_melden", koerper)
	return antwort != null


## 24.11.: Angriff aufgegeben: die stehende Verteidigung bekommt den Sieg, der Lauf zählt als Niederlage (ein Update).
static func angriff_abgebrochen(verteidigung_id: String) -> void:
	if verteidigung_id == "":
		return
	await duell("", verteidigung_id, 0.0, 0, "angriff")
	await lauf([{"id": verteidigung_id, "s": 0.0, "w": 1.0}])


## 23.11.: Eigene Phantome einer Art im Pool (nicht archiviert), schwächstes zuerst. null = unbekannt (offline oder
## Datenbank ohne Archiv) – dann gibt es keine Plätze-Regel.
static func eigene(art: String) -> Variant:
	var id := Profil.id()
	if id == "" or id == "pool":
		return null
	var l: Variant = await _anfrage(HTTPClient.METHOD_GET, "/rest/v1/phantome?select=id,elo,spiele,siege,wertung,erstellt,datei&art=eq.%s&profil=eq.%s&version=eq.%d&archiviert=eq.false&order=elo.asc" % [art, id.uri_encode(), Phantom.PHANTOM_VERSION])
	return l if l is Array else null


## 23.11.: Eigenes Phantom ins Archiv (macht einen Platz frei). true = geklappt.
static func archivieren(id: String) -> bool:
	var antwort: Variant = await _anfrage(HTTPClient.METHOD_POST, "/rest/v1/rpc/phantom_archivieren", {"p_id": id, "p_profil": Profil.id()})
	return antwort is bool and bool(antwort)


## Lädt die Daten eines Phantoms und legt sie im Benutzerordner ab. Gibt den Pfad zurück ("" = nicht geklappt).
static func hole(eintrag: Dictionary) -> String:
	var art := str(eintrag["art"])
	var o := CACHE + "/" + art
	var pfad := "%s/%s.json" % [o, str(eintrag["id"])]
	if not FileAccess.file_exists(pfad):
		var l: Variant = await _anfrage(HTTPClient.METHOD_GET, "/rest/v1/phantome?select=daten&id=eq.%s" % str(eintrag["id"]))
		if not (l is Array) or (l as Array).is_empty():
			return ""
		var d: Variant = (l[0] as Dictionary).get("daten")
		if not (d is Dictionary):
			return ""
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(o))
		var f := FileAccess.open(pfad, FileAccess.WRITE)
		if f == null:
			return ""
		f.store_string(JSON.stringify(d))
		f.close()
	pfad_id[pfad] = str(eintrag["id"])
	return pfad


## ID eines Phantoms (lokal geladen oder online), "" wenn unbekannt.
static func id_von(pfad: String) -> String:
	if pfad_id.has(pfad):
		return str(pfad_id[pfad])
	# eingebautes Pool-Phantom: über den Dateinamen
	var datei := pfad.get_file()
	for art: String in listen:
		for e: Dictionary in listen[art]:
			if str(e["datei"]) == datei and str(e.get("profil", "")) == "pool":
				return str(e["id"])
	return ""


## Wahl eines Gegners aus der Online-Liste: "staerkste" zieht zufällig aus den besten fünf (nach Elo).
static func waehle(art: String, wie: String, ohne: Array = []) -> Dictionary:
	var l: Array = []
	for e: Dictionary in listen[art]:
		if not ohne.has(str(e["id"])) and int(e.get("spalten", 28)) in [20, 28]:
			l.append(e)
	if l.is_empty():
		return {}
	if wie == "staerkste":
		l.sort_custom(func(a, b): return float(a["elo"]) > float(b["elo"]))
		return l.slice(0, 5).pick_random()
	# 23.11.: Zufall bevorzugt wenig gespielte Phantome (Gewicht 1 / (1 + Duelle)) – neue erreichen so schneller die Liste
	var summe := 0.0
	for e: Dictionary in l:
		summe += 1.0 / (1.0 + float(e.get("spiele", 0)))
	var zahl := randf() * summe
	for e: Dictionary in l:
		zahl -= 1.0 / (1.0 + float(e.get("spiele", 0)))
		if zahl <= 0.0:
			return e
	return l.back()


static func bereit() -> bool:
	return zustand == "online" and not ((listen["angriff"] as Array).is_empty() and (listen["verteidigung"] as Array).is_empty())


## 23.11.: Aktuelle Spieler-Elo des eigenen Profils für eine Seite ("angriff" | "verteidigung"): {elo, spiele}; {} = unbekannt.
static func meine_elo(art: String) -> Dictionary:
	var id := Profil.id()
	if id == "" or id == "pool":
		return {}
	var l: Variant = await _anfrage(HTTPClient.METHOD_GET, "/rest/v1/spieler_elo?select=elo,spiele&profil=eq.%s&art=eq.%s" % [id.uri_encode(), art])
	if l is Array and not (l as Array).is_empty():
		return (l[0] as Dictionary)
	if l is Array:
		return {"elo": 1000.0, "spiele": 0}   # noch keine Zeile: Startwert
	return {}


## Elo vor einem Duell aus dem Zwischenspeicher der Listen (1000, wenn der Spieler dort noch nicht steht).
static func elo_im_speicher(art: String) -> int:
	var id := Profil.id()
	for e: Dictionary in spieler_listen.get(art, []):
		if str(e.get("profil", "")) == id:
			return roundi(float(e.get("elo", 1000)))
	return 1000


## 23.11. (Phantom-Einführung G): Was ist seit `seit` (ISO-Zeit, "" = je) mit den eigenen Phantomen geschehen?
## {verteidigt, gehalten, angriffe, geknackt, elo_aenderung, von: [Namen]}; leer, wenn nichts war oder offline.
static func lade_bericht(seit: String) -> void:
	bericht = {}
	var id := Profil.id()
	if id == "" or id == "pool" or not aktiv():
		return
	var meine: Variant = await _anfrage(HTTPClient.METHOD_GET, "/rest/v1/phantome?select=id,art,elo&profil=eq.%s&version=eq.%d" % [id.uri_encode(), Phantom.PHANTOM_VERSION])
	if not (meine is Array) or (meine as Array).is_empty():
		return
	var art_von := {}
	var elo_jetzt := {}
	var ids: Array = []
	for e: Dictionary in meine:
		art_von[str(e["id"])] = str(e["art"])
		elo_jetzt[str(e["id"])] = float(e.get("elo", 1000))
		ids.append(str(e["id"]))
	var liste := ",".join(PackedStringArray(ids))
	var filter := "&or=(angriff.in.(%s),verteidigung.in.(%s))&profil=neq.%s" % [liste, liste, id.uri_encode()]
	if seit != "":
		filter += "&erstellt=gt." + seit.uri_encode()
	var d: Variant = await _anfrage(HTTPClient.METHOD_GET, "/rest/v1/duelle?select=angriff,verteidigung,ergebnis,spieler,erstellt,elo_angriff_vorher,elo_verteidigung_vorher&order=erstellt.asc&limit=200" + filter)
	if not (d is Array) or (d as Array).is_empty():
		return
	var b := {"verteidigt": 0, "gehalten": 0, "angriffe": 0, "geknackt": 0, "elo_aenderung": 0, "von": []}
	var erste := {}   # Phantom-ID -> Elo vor dem ersten Duell im Zeitraum
	for e: Dictionary in d:
		var sieg := float(e.get("ergebnis", 0.0)) >= Phantom.DUELL_SIEG_AB   # Angreifer hat geknackt
		var v := str(e.get("verteidigung", ""))
		var a := str(e.get("angriff", ""))
		var wer := str(e.get("spieler", ""))
		if v != "" and art_von.get(v, "") == "verteidigung":
			b["verteidigt"] = int(b["verteidigt"]) + 1
			if not sieg:
				b["gehalten"] = int(b["gehalten"]) + 1
			if not erste.has(v):
				erste[v] = float(e.get("elo_verteidigung_vorher", 1000))
			if wer != "" and not (b["von"] as Array).has(wer):
				(b["von"] as Array).append(wer)
		if a != "" and art_von.get(a, "") == "angriff":
			b["angriffe"] = int(b["angriffe"]) + 1
			if sieg:
				b["geknackt"] = int(b["geknackt"]) + 1
			if not erste.has(a):
				erste[a] = float(e.get("elo_angriff_vorher", 1000))
			if wer != "" and not (b["von"] as Array).has(wer):
				(b["von"] as Array).append(wer)
	var delta := 0.0
	for pid: String in erste:
		delta += float(elo_jetzt.get(pid, 1000.0)) - float(erste[pid])
	b["elo_aenderung"] = roundi(delta)
	if int(b["verteidigt"]) + int(b["angriffe"]) > 0:
		bericht = b
	geaendert += 1


## Der Bericht als kurzer Text ("" = nichts Neues).
static func bericht_text() -> String:
	if bericht.is_empty():
		return ""
	var teile: Array = []
	var v := int(bericht["verteidigt"])
	if v > 0:
		teile.append("Dein Bau wurde %d× angegriffen – %d× gehalten" % [v, int(bericht["gehalten"])])
	var a := int(bericht["angriffe"])
	if a > 0:
		teile.append("Gegen deinen Angriff wurde %d× verteidigt – %d× hat er gesiegt" % [a, int(bericht["geknackt"])])
	var t := " · ".join(PackedStringArray(teile))
	var e := int(bericht["elo_aenderung"])
	if e != 0:
		t += " (Phantom-Elo %+d)" % e
	return t


## 24.11. (Paul): Bilanz eines Spielers aus den geladenen Listen – für die Spielerkarte und die eigene Bilanz.
## {name, angriff: {elo, elo_max, spiele, siege}, verteidigung: {…}, phantome: {angriff: n, verteidigung: n}}
## (leere Wörterbücher, wenn der Spieler noch keine Läufe hat). Angriff: siege = geknackte Verteidigungen,
## Verteidigung: siege = gehaltene Angriffe; „spiele“ zählt seit Version 72 Läufe (ein ganzer Angriff = 1), „duelle“ die
## einzelnen Verteidigungen, gegen die er lief (Quote Angriff = siege / duelle).
static func spieler_daten(profil: String) -> Dictionary:
	var d := {"name": "", "angriff": {}, "verteidigung": {}, "phantome": {"angriff": 0, "verteidigung": 0}}
	if profil == "" or profil == "pool":
		return d
	for art: String in ["angriff", "verteidigung"]:
		for e: Dictionary in (spieler_listen[art] as Array):
			if str(e.get("profil", "")) == profil:
				d[art] = e
				d["name"] = str(e.get("spieler", ""))
		for e: Dictionary in (listen[art] as Array):
			if str(e.get("profil", "")) == profil:
				d["phantome"][art] = int(d["phantome"][art]) + 1
				if str(d["name"]) == "":
					d["name"] = str(e.get("spieler", ""))
	return d


## Platz in der Spieler-Rangliste einer Seite (0 = nicht in der Liste, weil noch zu wenige Läufe).
static func spieler_platz(art: String, profil: String) -> int:
	var n := 0
	for e: Dictionary in (spieler_listen[art] as Array):
		if int(e.get("spiele", 0)) < LISTE_AB:
			continue
		n += 1
		if str(e.get("profil", "")) == profil:
			return n
	return 0
