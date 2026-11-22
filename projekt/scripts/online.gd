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
const FELDER := "id,art,datei,spieler,profil,version,spalten,wertung,elo,spiele,siege,erstellt"

## "unbekannt", "laedt", "online", "offline"
static var zustand := "unbekannt"
static var listen := {"angriff": [], "verteidigung": []}
static var pfad_id := {}            # lokaler Pfad eines geladenen oder hochgeladenen Phantoms -> ID online
static var ersatz_pfade: Array = [] # Angriff: online gezogene Ersatz-Phantome für die nächste Partie
static var _abgeglichen := false
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
		var l: Variant = await _anfrage(HTTPClient.METHOD_GET, "/rest/v1/phantome?select=%s&art=eq.%s&version=eq.%d&order=elo.desc&limit=300" % [FELDER, art, Phantom.PHANTOM_VERSION])
		if l is Array:
			listen[art] = l
		else:
			ok = false
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
static func duell(angriff_id: String, verteidigung_id: String, ergebnis: float, wertung: int) -> bool:
	if angriff_id == "" and verteidigung_id == "":
		return false
	var antwort: Variant = await _anfrage(HTTPClient.METHOD_POST, "/rest/v1/rpc/duell_melden", {
		"p_angriff": null if angriff_id == "" else angriff_id, "p_verteidigung": null if verteidigung_id == "" else verteidigung_id,
		"p_ergebnis": clampf(ergebnis, 0.0, 1.0), "p_wertung": wertung, "p_spieler": Profil.name(), "p_profil": Profil.id()})
	return antwort != null


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
	return l.pick_random()


static func bereit() -> bool:
	return zustand == "online" and not ((listen["angriff"] as Array).is_empty() and (listen["verteidigung"] as Array).is_empty())
