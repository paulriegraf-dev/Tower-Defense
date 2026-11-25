extends SceneTree
## 25.11.: Pool-Abgleich – nachgeladen wird nur, was die Datenbank wirklich nicht kennt. Die Attrappe spielt die
## Tabelle `phantome` nach (Filter, Sortierung, limit); es geht nichts ins Netz.
##   godot --headless --path . -s werkzeuge/pooltest.gd
const SPIELER := "APAAtROXOP"
const ARCHIV_AUS_BEFUND := ["verteidigung-20261119-130859.json", "verteidigung-20261119-155503.json", "verteidigung-20261119-175038.json"]

var fehler: Array[String] = []
var zeilen: Array = []        # die nachgespielte Tabelle
var hochgeladen: Array = []   # "art/datei"
var profile: Array = []       # p_profil der Uploads
var ausfall := ""             # "" | "liste" | "bestand"
var bestand_rufe := 0         # Einzelabfragen „kennt die Datenbank diese Datei?“
var eingebaut := {}           # art -> Dateinamen im eingebauten Pool (aktuelle Version)

func pruefe(ok: bool, text: String) -> void:
	print("%s %s" % ["OK  " if ok else "FEHL", text])
	if not ok:
		fehler.append(text)

func _netz(_methode: int, pfad: String, koerper: Variant) -> Array:
	var name := pfad.get_slice("?", 0).get_file()
	if name == "phantom_hochladen":
		hochgeladen.append("%s/%s" % [koerper["p_art"], koerper["p_datei"]])
		profile.append(str(koerper["p_profil"]))
		_zeile(str(koerper["p_art"]), str(koerper["p_datei"]), str(koerper["p_profil"]), false, 1000.0)
		return [HTTPRequest.RESULT_SUCCESS, 200, "\"%s\"" % str((zeilen.back() as Dictionary)["id"])]
	if name != "phantome":
		return [HTTPRequest.RESULT_SUCCESS, 200, "[]"]
	var filter := {}
	for teil: String in pfad.get_slice("?", 1).split("&"):
		filter[teil.get_slice("=", 0)] = teil.substr(teil.find("=") + 1).uri_decode()
	if filter.has("datei"):
		bestand_rufe += 1
		if ausfall == "bestand":
			return [HTTPRequest.RESULT_CANT_CONNECT, 0, ""]
	elif ausfall == "liste":
		return [HTTPRequest.RESULT_CANT_CONNECT, 0, ""]
	var treffer: Array = zeilen.filter(func(z: Dictionary) -> bool:
		for spalte: String in ["art", "datei", "profil", "archiviert", "version"]:
			if filter.has(spalte) and "eq.%s" % str(z[spalte]) != str(filter[spalte]):
				return false
		return true)
	treffer.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["elo"]) > float(b["elo"]))
	if filter.has("limit"):
		treffer = treffer.slice(0, int(filter["limit"]))
	return [HTTPRequest.RESULT_SUCCESS, 200, JSON.stringify(treffer)]

func _zeile(art: String, datei: String, profil: String, archiviert: bool, elo: float) -> void:
	zeilen.append({"id": "id-%d" % zeilen.size(), "art": art, "datei": datei, "profil": profil, "spieler": profil,
		"archiviert": archiviert, "version": Phantom.PHANTOM_VERSION, "elo": elo})

## Alle eingebauten Phantome stehen aktiv als „pool“ in der Tabelle, außer den genannten.
func _tabelle(ausser: Array = []) -> void:
	zeilen = []
	for art: String in eingebaut:
		for datei: String in eingebaut[art]:
			if not ausser.has(datei):
				_zeile(art, datei, "pool", false, 1000.0)

## Ein Spielstart: Listen holen, dabei läuft der Abgleich.
func _start(mit_ausfall: String = "") -> void:
	ausfall = mit_ausfall
	hochgeladen = []
	profile = []
	bestand_rufe = 0
	Online._abgeglichen = false
	Online.zustand = "unbekannt"
	Online.listen = {"angriff": [], "verteidigung": []}
	await Online.lade_listen()

func _initialize() -> void:
	_los()

func _los() -> void:
	await process_frame
	Online.attrappe = _netz
	for art: String in ["verteidigung", "angriff"]:
		var o := "res://Phantom Dateien/" + str(Phantom.UNTERORDNER[art])
		eingebaut[art] = []
		for datei: String in DirAccess.open(o).get_files():
			if datei.ends_with(".json") and int(Phantom.lade(o + "/" + datei).get("phantom_version", 1)) >= Phantom.PHANTOM_VERSION:
				eingebaut[art].append(datei)
	var v: Array = eingebaut["verteidigung"]
	var a: Array = eingebaut["angriff"]
	print("eingebaut: %d Verteidigungen, %d Angriffe" % [v.size(), a.size()])
	pruefe(ARCHIV_AUS_BEFUND.all(func(d: String) -> bool: return v.has(d)) and a.size() >= 2, "Voraussetzung: die Dateien aus dem Befund liegen im Pool")

	# 1) alles da
	_tabelle()
	await _start()
	pruefe(hochgeladen.is_empty() and bestand_rufe == 0 and Online.zustand == "online", "alles in der Liste: kein Upload, keine Zusatzabfrage (%s, %d)" % [str(hochgeladen), bestand_rufe])

	# 2) archiviert (wie im Befund) oder unter einem Spieler vorhanden
	var weg: Array = ARCHIV_AUS_BEFUND + [a[0], a[1]]
	_tabelle(weg)
	for datei: String in ARCHIV_AUS_BEFUND:
		_zeile("verteidigung", datei, SPIELER, true, 1100.0)
	_zeile("angriff", a[0], SPIELER, true, 900.0)
	_zeile("angriff", a[1], SPIELER, false, 900.0)
	var vorher := zeilen.size()
	await _start()
	pruefe(hochgeladen.is_empty() and zeilen.size() == vorher, "archiviert oder vorhanden: nichts wird neu hochgeladen (%s)" % str(hochgeladen))

	# 3) wirklich fehlende kommen weiterhin nach, neben archivierten
	var neu_v: String = v.back()
	var neu_a: String = a.back()
	_tabelle([ARCHIV_AUS_BEFUND[0], neu_v, neu_a])
	_zeile("verteidigung", ARCHIV_AUS_BEFUND[0], SPIELER, true, 1100.0)
	await _start()
	hochgeladen.sort()
	var soll := ["angriff/" + neu_a, "verteidigung/" + neu_v]
	pruefe(hochgeladen == soll and profile == ["pool", "pool"], "nur die fehlenden, als „pool“: %s" % str(hochgeladen))
	await _start()
	pruefe(hochgeladen.is_empty(), "beim nächsten Start nichts doppelt: %s" % str(hochgeladen))

	# 4) die Datenbank kennt den Namen nur für die andere Art: fehlt also
	_tabelle([neu_a])
	_zeile("verteidigung", neu_a, SPIELER, false, 900.0)
	await _start()
	pruefe(hochgeladen == ["angriff/" + neu_a], "gleicher Name in der anderen Art zählt nicht: %s" % str(hochgeladen))

	# 5) mehr als 300 Einträge: eingebaute fallen aus der Liste, sind aber da
	_tabelle()
	for art: String in eingebaut:
		for i in 300:
			_zeile(art, "fremd-%d.json" % i, "jemand", false, 2000.0 + i)
	await _start()
	pruefe((Online.listen["verteidigung"] as Array).size() == 300 and not Online.listen["verteidigung"].any(func(e: Dictionary) -> bool: return v.has(e["datei"])), "Liste ist voll mit stärkeren Phantomen")
	pruefe(hochgeladen.is_empty(), "über 300: nichts wird neu hochgeladen (%d Uploads)" % hochgeladen.size())

	# 6) die Nachfrage scheitert: lieber nicht nachladen
	_tabelle([neu_v, neu_a])
	await _start("bestand")
	pruefe(hochgeladen.is_empty(), "Nachfrage gescheitert: kein Upload (%s)" % str(hochgeladen))
	pruefe(bestand_rufe == 1 and Online.zustand == "online", "nach dem ersten Fehlschlag ist Schluss, das Spiel bleibt online (%d Nachfragen)" % bestand_rufe)

	# 7) schon die Liste scheitert: gar kein Abgleich
	await _start("liste")
	pruefe(hochgeladen.is_empty() and bestand_rufe == 0 and Online.zustand == "offline", "ohne Liste kein Abgleich")

	Online.attrappe = Callable()
	print("TEST POOL OK" if fehler.is_empty() else "TEST POOL FEHLER: %s" % ", ".join(fehler))
	quit(0 if fehler.is_empty() else 1)
